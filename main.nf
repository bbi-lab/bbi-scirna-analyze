import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import groovy.json.JsonOutput
import groovy.json.JsonSlurper


params.bin_dir = workflow.projectDir + '/bin'
params.align_cpus = 8
params.umi_cutoff = 100
params.hash_umi_cutoff = 5
params.hash_ratio = false
params.hash_dup = false //Default is false. Other options are "p5" or "pcr_plate".
params.run_empty_drops = true


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
params.object_map.make_cds_raw_cds_map = [:]
params.object_map.cat_matrices_raw_map = [:]


/*
** Import modules after defining params.* so that
** the parameters are accessible in the modules.
*/
include { make_genome_files_json } from './modules/make_genome_files_json.nf'
include { make_merge_demux_json } from './modules/make_merge_demux_json.nf'
include { merge_demux } from './modules/merge_demux.nf'
include { make_process_hashes_json } from './modules/make_process_hashes_json.nf'
include { process_hashes; cat_hashes; process_hashes_function; hash_umi_knee_plot; calc_tot_hash_dup; assign_hash_raw } from './modules/process_hashes.nf'
include { make_trim_bam_json } from './modules/make_trim_bam_json.nf'
include { trim_bams; trim_bam_function } from './modules/trim_bams.nf'
include { make_star_align_json } from './modules/make_star_align_json.nf'
include { align_bams; align_bam_function } from './modules/align_bams.nf'
include { make_merge_align_json } from './modules/make_merge_align_json.nf'
include { merge_align; merge_align_function } from './modules/merge_align.nf'
include { merge_starsolo_reports; merge_starsolo_reports_function } from './modules/merge_starsolo_reports.nf'
include { make_knee_plot } from './modules/make_knee_plot.nf'
include { split_starsolo_stats } from './modules/split_starsolo_stats.nf'
include { cat_matrices_raw; cat_matrices_raw_function } from './modules/cat_matrices.nf'
include { make_mito_umis_json } from './modules/make_mito_umis_json.nf'
include { make_mito_umis; make_mito_umis_function} from './modules/make_mito_umis.nf'
include { make_cds_raw; make_cds_raw_genomes_function } from './modules/make_cds.nf'
include { run_empty_drops } from './modules/run_empty_drops.nf'
include { make_barnyard_json } from './modules/make_barnyard_json.nf'
include { make_barnyard_plot; make_barnyard_plot_function } from './modules/make_barnyard_plot.nf'


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
  ** Make a JSON file with genome file paths by sample.
  */
  make_genome_files_json(samplesheet_file, star_genomes_file, make_merge_demux_json.out.collect())

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
  **   o  in short, the following .subscribe() operator
  **      makes a Java associative array (map) that
  **      maps a bam filename to its path in the work
  **      directory. This runs after the merge_demux
  **      process finishes. The associative array is
  **      stored in the global variable called
  **      params.object_map.merge_bam_map.
  **   o  python scripts make json files that define
  **      the contents of channels used in downstream
  **      processes, including paths for input to the
  **      downstream processes. The script knows the
  **      input file names but not the paths in the
  **      Nextflow work directory. The main list in
  **      the JSON file is split into 'items' that
  **      are processed by a groovy function to
  **      define queue channel contents. The input
  **      filenames are given in the JSON file but
  **      not their paths within the Nextflow work
  **      directory tree.
  **   o  the maps in params.object_map.* are used to
  **      substitute the file path for the file name
  **      within a groovy function that sets up the
  **      channel.
  **   o  when the channel objects are tuples, one
  **      must subscript 'path' to get the necessary
  **      element.
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
             process_hashes.out.hash_log.groupTuple())

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
  trim_bams.out.trimmed_bams.subscribe onNext: {
    path -> {
      def file_base_name = path.toString().tokenize('/').last()
      params.object_map.trim_bam_map[file_base_name] = path
    }
  }

  make_star_align_json(samplesheet_file, "${star_genomes_file}", trim_bams.out.trimmed_bams.collect())
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
  make_merge_align_json.out.splitJson().map{merge_starsolo_reports_function(it)}.set{merge_starsolo_reports_channel_in}
  merge_starsolo_reports(merge_starsolo_reports_channel_in)

  /*
  ** Split out selected columns from CellReads.stats.
  */
  split_starsolo_stats(merge_starsolo_reports.out.cell_reads_stats)

  /*
  ** Concatenate MM counts matrices.
  **
  */
  make_merge_align_json.out.splitJson().map{cat_matrices_raw_function(it)}.set{cat_matrices_raw_channel_in}
  cat_matrices_raw(cat_matrices_raw_channel_in)

  /*
  ** Make cat_matrices_raw_map map with matrix file paths.
  */
  cat_matrices_raw.out.raw_matrix.subscribe onNext: {
    def tup -> {
      def cells_path = tup[1]
      def cells_base_name = cells_path.toString().tokenize('/').last()
      params.object_map.cat_matrices_raw_map[cells_base_name] = cells_path

      def features_path = tup[2]
      def features_base_name = features_path.toString().tokenize('/').last()
      params.object_map.cat_matrices_raw_map[features_base_name] = features_path

      def matrix_path = tup[3]
      def matrix_base_name = matrix_path.toString().tokenize('/').last()
      params.object_map.cat_matrices_raw_map[matrix_base_name] = matrix_path
    }
  }

  /*
  ** Make knee plot.
  */
  make_knee_plot(cat_matrices_raw.out.raw_matrix)

  /*
  ** Calculate mitochondrial UMIs per cell.
  ** Need
  **   o  concatenated matrix
  **   o  genome info
  */
  make_mito_umis_json(samplesheet_file, "${star_genomes_file}", cat_matrices_raw.out.raw_matrix.collect())
  make_mito_umis_json.out.splitJson().map{make_mito_umis_function(it)}.set{make_mito_umis_in}
  make_mito_umis(make_mito_umis_in)

  /*
  ** Run emptyDrops function.
  */
  run_empty_drops(cat_matrices_raw.out.raw_matrix)

  /*
  ** Make CDS objects.
  **   Inputs:
  **    tuple val(sample_name), path(cells), path(features), path(matrix)
  **    val(out_file)
  */
  make_genome_files_json.out.genome_files.splitJson().map{make_cds_raw_genomes_function(it)}.set{make_cds_genomes_in}
/*
  make_cds_raw_in = cat_matrices_raw.out.raw_matrix.join(split_starsolo_stats.out.counts_per_cell).join(run_empty_drops.out).join(make_mito_umis.out).join(make_cds_genomes_in)
  make_cds_raw(make_cds_raw_in, 'counts_raw')
  make_cds_raw(cat_matrices_raw.out.raw_matrix.join(split_starsolo_stats.out.counts_per_cell).join(run_empty_drops.out).join(make_mito_umis.out).join(make_cds_genomes_in), 'counts_raw')
println "make_cds_raw: " + make_cds_raw.out.cds
*/

  cat_matrices_raw.out.raw_matrix.join(split_starsolo_stats.out.counts_per_cell).join(run_empty_drops.out).join(make_mito_umis.out).join(make_cds_genomes_in).set{make_cds_raw_in}
  make_cds_raw(make_cds_raw_in, 'counts_raw')

  /*
  ** Note:
  **   o  the make_cds_raw.out.cds channel is a tuple
  **      so it's necessary to select the path element.
  **
  **   o  make_cds_raw.out.cds channel is
  **
  **        tuple val(sample_name), path("*.raw.mobs"), emit: cds
  */
  make_cds_raw.out.cds.subscribe onNext: {
    def tup -> {
      def path = tup[1]
      def file_base_name = path.toString().tokenize('/').last()
//      println "file base name: " + file_base_name
//      println "path: " + path
      params.object_map.make_cds_raw_cds_map[file_base_name] = path
    }
  }

  /*
  ** Assign hashes to cells and update cds.
  assign_hash_raw_channel_in = cat_hashes.out.hash_matrix.join(split_starsolo_stats.out.counts_per_cell).join(make_cds_raw.out.cds)
  println "assign_hashes_in" + cat_hashes.out.hash_matrix.join(split_starsolo_stats.out.counts_per_cell).join(make_cds_raw.out.cds)
  assign_hash_raw(cat_hashes.out.hash_matrix.join(split_starsolo_stats.out.counts_per_cell).join(make_cds_raw.out.cds))
  */

  cat_hashes.out.hash_matrix.join(split_starsolo_stats.out.counts_per_cell).join(make_cds_raw.out.cds).set{assign_hash_raw_channel_in}
  assign_hash_raw(assign_hash_raw_channel_in)

  /*
  ** Make barnyard plots.
  */
  make_barnyard_json(samplesheet_file, make_cds_raw.out.png.collect())
  make_barnyard_json.out.splitJson().map{make_barnyard_plot_function(it)}.set{make_barnyard_plot_in}
  make_barnyard_plot(make_barnyard_plot_in)
}


