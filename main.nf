import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import groovy.json.JsonOutput
import groovy.json.JsonSlurper

params.bin_dir = workflow.projectDir + '/bin'
params.align_cpus = 4
params.umi_cutoff = 100
params.hash_umi_cutoff = 5
params.hash_ratio = false
params.hash_dup = false //Default is false. Other options are "p5" or "pcr_plate".


demux_out = "${params.output_dir}/demux_out"
star_genomes_file = "${params.bin_dir}/star_genomes.txt"


/*
** A naive effort to store global values.
*/
params.object_map = [:]

/*
** For the maps below, the keys are filenames
** and the values are absolute paths to the
** files given by the key.
*/
params.object_map.merge_bam_map = [:]
params.object_map.process_hashes_map = [:]
params.object_map.trim_bam_map = [:]
params.object_map.merge_align_bam_map = [:]


/*
** Import modules after defining params.* so that
** the parameters are accessible in the modules.
*/
include { make_merge_demux_json } from './modules/make_merge_demux_json.nf'
include { merge_demux } from './modules/merge_demux.nf'
include { make_process_hashes_json } from './modules/make_process_hashes_json.nf'
include { process_hashes; cat_hashes; process_hashes_function; hash_umi_knee_plot; calc_tot_hash_dup; assign_hash } from './modules/process_hashes.nf'
include { make_trim_bam_json } from './modules/make_trim_bam_json.nf'
include { trim_bams; trim_bam_function } from './modules/trim_bams.nf'
include { make_star_align_json } from './modules/make_star_align_json.nf'
include { align_bams; align_bam_function } from './modules/align_bams.nf'
include { make_merge_align_json } from './modules/make_merge_align_json.nf'
include { merge_align; merge_align_function } from './modules/merge_align.nf'
include { merge_starsolo; merge_starsolo_function } from './modules/merge_starsolo.nf'
include { split_starsolo } from './modules/split_starsolo.nf'
include { cat_matrices; cat_matrices_function } from './modules/cat_matrices.nf'
include { make_cds } from './modules/make_cds.nf'


/*
** Set up channels.
*/
samplesheet_file = channel.fromPath(params.samplesheet_json)


/*
** Functions and closures.
*/
def merge_demux_closure = {
  item -> 
          def sample_name = item['sample_name']
          def out_name = item['out_file']
          def in_file_list = []
          for(in_file in item['in_file_list']) {
            in_file_list.add(file(in_file))
          }
          [sample_name, out_name, in_file_list]
}


/*
** Run pipeline.
*/
workflow {
  /*
  ** Set up and run samtools to merge (unaligned) input BAM files.
  */
  make_merge_demux_json(samplesheet_file, "$demux_out")
  make_merge_demux_json.out.splitJson().map{merge_demux_closure(it)}.set{merge_demux_channel_in}
  merge_demux(merge_demux_channel_in)

  /*
  ** Here are some convolutions in order to pass
  ** the paths of merged bam files to the trim
  ** bams process. The merged bam files are in the
  ** work directory so the paths are not known
  ** until Nextflow runs the merge_demux process.
  **
  ** Notes:
  **   o  in summary, there are three 'actors' in this
  **      story: (a) the .subscribe() operator below,
  **      (b) the trim_bam_function(), and (c) the
  **      .collect() operator. In
  **      addition, the global variable
  **      params.object_map.merge_bam_map transfers
  **      values from the .subscribe() operator to the
  **      trim_bam_function().
  **   o  the following .subscribe() operator makes
  **      a Java associative array (map) that maps a
  **      bam filename to its path in the work
  **      directory. This runs after the merge_demux
  **      process finishes. The associative array is
  **      stored in the global variable called
  **      params.object_map.merge_bam_map.
  **   o  the function trim_bam_function(item) uses
  **      the associative array to make a channel that
  **      has an output for each element in the list
  **      of merged bam files that is in the JSON file
  **      made by make_trim_bam_json. The .splitJson()
  **      operator takes the JSON file contents and
  **      populates this channel. The following .map()
  **      operator calls trim_bam_function() and
  **      sets up the channel used by the trim_bams
  **      process.
  **   o  the make_trim_bam_json process takes the
  **      merge_demux.out.collect() value channel in
  **      order to stall the run of the
  **      make_trim_bam_json process until the
  **      merge_demux process finishes AND, subsequently,
  **      the required associative array is assembled
  **      from the output channel of the
  **      make_trim_bam_json process.
  **   o  I would like to use a 'cleaner' way to do this
  **      but I cannot think of one at this time.
  */      
  merge_demux.out.subscribe onNext: {
    path -> {
      def file_base_name = path.toString().tokenize('/').last()
      params.object_map.merge_bam_map[file_base_name] = path
    }
  }

  merge_demux.out.subscribe onNext: {
    path -> {
      def file_base_name = path.toString().tokenize('/').last()
      params.object_map.process_hashes_map[file_base_name] = path
    }
  }

  /*
  ** Check for hash read runs: set up JSON file, process reads, and make make output.
  */
  make_process_hashes_json(samplesheet_file, merge_demux.out.collect())
  make_process_hashes_json.out.splitJson().filter{it.size() > 0}.map{process_hashes_function(it)}.set{process_hashes_channel_in}
  process_hashes(process_hashes_channel_in)

  cat_hashes(process_hashes.out.hash_matrix.groupTuple(),
             process_hashes.out.hash_cells.groupTuple(),
             process_hashes.out.hash_hashes.groupTuple(),
             process_hashes.out.hash_umis_per_cell.groupTuple(),
             process_hashes.out.hash_dup_per_cell.groupTuple(),
             process_hashes.out.hash_reads_per_cell.groupTuple(),
             process_hashes.out.hash_assigned_table.groupTuple(),
             process_hashes.out.hash_log.groupTuple(),

)
  hash_umi_knee_plot(process_hashes.out.hash_umis_per_cell)
  calc_tot_hash_dup(process_hashes.out.hash_dup_per_cell)

  /*
  ** Set up and run bbduk.sh read trimming.
  */
  make_trim_bam_json(samplesheet_file, merge_demux.out.collect())
  make_trim_bam_json.out.splitJson().map{trim_bam_function(it)}.set{trim_bam_channel_in}
  trim_bams(trim_bam_channel_in)

  /*
  ** Set up and run STAR aligner as STARsolo.
  */
  trim_bams.out.subscribe onNext: {
    path -> {
      def file_base_name = path.toString().tokenize('/').last()
      params.object_map.trim_bam_map[file_base_name] = path
    }
  }

  make_star_align_json(samplesheet_file, "${star_genomes_file}", trim_bams.out.collect())
  make_star_align_json.out.splitJson().map{align_bam_function(it)}.set{align_bam_channel_in}
  align_bams(align_bam_channel_in)

  /*
  ** Set up and merge aligned BAM files.
  ** Use the same strategy as above for finding
  ** the STAR BAM file paths.
  */
  align_bams.out.subscribe onNext: {
    path -> {
      def dir_base_name = path.toString().tokenize('/').last()
      params.object_map.merge_align_bam_map[dir_base_name] = path
    }
  }

  make_merge_align_json(samplesheet_file, align_bams.out.collect())
  make_merge_align_json.out.splitJson().map{merge_align_function(it)}.set{merge_align_channel_in}
  merge_align(merge_align_channel_in)

  /*
  ** Set up and merge STARsolo results.
  ** Notes:
  **   o  reuse the make_merge_align_json JSON file because
  **      the JSON file refers to the STARsolo output directory
  **      where all of the STARsolo results are stored.
  */
  make_merge_align_json.out.splitJson().map{merge_starsolo_function(it)}.set{merge_starsolo_channel_in}
  merge_starsolo(merge_starsolo_channel_in)

  /*
  ** Split out selected columns from CellReads.stats.
  */
  split_starsolo(merge_starsolo.out)

  /*
  ** Concatenate MM counts matrices.
  **
  */
  make_merge_align_json.out.splitJson().map{cat_matrices_function(it)}.set{cat_matrices_channel_in}
  cat_matrices(cat_matrices_channel_in)

  /*
  ** Make CDS objects.
  **   Inputs:
  **    tuple val(sample_name), path(cells), path(features), path(matrix)
  **    val(out_file)
  */
  make_cds( cat_matrices.out.raw_matrix, 'counts_raw')

  /*
  ** Assign hashes to cells and update cds.
  */
  assign_hash_channel_in = cat_hashes.out.hash_matrix.join(split_starsolo.out.counts_per_cell).join( make_cds.out.cds)
  assign_hash(assign_hash_channel_in)

}


