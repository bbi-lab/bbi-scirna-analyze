import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import groovy.json.JsonOutput
import groovy.json.JsonSlurper

params.bin_dir = workflow.projectDir + '/bin'
params.align_cpus = 4
params.umi_cutoff = 100

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
params.object_map.trim_bam_map = [:]
params.object_map.merge_align_bam_map = [:]


/*
** Import modules after defining params.* so that
** the parameters are accessible in the modules.
*/
include { make_merge_demux_json } from './modules/make_merge_demux_json.nf'
include { merge_demux } from './modules/merge_demux.nf'
include { make_trim_bam_json; trim_bam_function } from './modules/make_trim_bam_json.nf'
include { trim_bams } from './modules/trim_bams.nf'
include { make_star_align_json; align_bam_function } from './modules/make_star_align_json.nf'
include { align_bams } from './modules/align_bams.nf'
include { make_merge_align_json; merge_align_function } from './modules/make_merge_align_json.nf'
include { merge_align } from './modules/merge_align.nf'
// include { make_copy_matrices_json; copy_matrices_function } from './modules/make_copy_matrices_json.nf'
include { cat_matrices } from './modules/cat_matrices.nf'
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
          def out_name = item['out_file']
          def in_file_list = []
          for(in_file in item['in_file_list']) {
            in_file_list.add(file(in_file))
          }
          [out_name, in_file_list]
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
  ** the paths of merged bam files to the align
  ** bams process. The merged bam files are in the
  ** work directory so the paths are not known
  ** until Nextflow runs the merge_demux process.
  **
  ** Notes:
  **   o  the following .subscribe() operator makes
  **      a Java associative array (map) that maps a
  **      merged bam filename to its path in the work
  **      directory. This runs after the merge_demux
  **      process finishes. The associative array is
  **      stored in the global variable called
  **      params.object_map.merge_bam_map.
  **   o  the function align_bam_function(item) uses
  **      the associative array to make a channel that
  **      has an output for each element in the list
  **      of merged bam files that is in the JSON file
  **      made by make_star_align_json. The .splitJson()
  **      operator takes the JSON file contents and
  **      populates this channel. The following .map()
  **      operator calles align_bam_function() and
  **      sets up the channel used by the align_bams
  **      process.
  **   o  the make_star_align_json process takes the
  **      merge_demux.out.collect() value channel in
  **      order to stall the run of the
  **      make_star_align_json process until the
  **      merge_demux process finishes AND, subsequently,
  **      the required associative array is assembled
  **      from the output channel of the
  **      make_star_align_json process.
  **   o  I would like to use a 'cleaner' way to do this
  **      but I cannot think of one at this time.
  */      
  merge_demux.out.subscribe onNext: {
    path -> {
      def file_base_name = path.toString().tokenize('/').last()
      params.object_map.merge_bam_map[file_base_name] = path
    }
  }

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
//  make_star_align_json(samplesheet_file, "${star_genomes_file}", merge_demux.out.collect())
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
  ** Concatenate MM counts matrices.
  **
  */
  cat_matrices(merge_align_channel_in)

  /*
  ** Make CDS objects.
  **   Inputs:
  **    path(count_matrix) 
  **    path(feature_tsv) 
  **    path(cell_tsv) 
  **    val(sample_dir) 
  **    val(out_file)
  */
  make_cds(cat_matrices.out.matrix,
           cat_matrices.out.features,
           cat_matrices.out.cells,
           cat_matrices.out.sample_dir,
           'counts_raw')
}


