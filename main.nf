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
params.run_scrublet = true


demux_out = "${params.output_dir}/demux_out"
genomes_data_file = "${params.bin_dir}/genomes_data.json"


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
include { make_sample_map_json } from './modules/make_sample_map_json.nf'
include { make_merge_demux_json } from './modules/make_merge_demux_json.nf'
include { merge_demux } from './modules/merge_demux.nf'
include { make_process_hashes_json } from './modules/make_process_hashes_json.nf'
include { process_hashes; cat_hashes; process_hashes_function; hash_umi_knee_plot; calc_tot_hash_dup; assign_hash_raw } from './modules/process_hashes.nf'
include { make_trim_bam_json } from './modules/make_trim_bam_json.nf'
include { trim_bams; trim_bam_function; aggregate_trimmer_logs } from './modules/trim_bams.nf'
include { make_star_align_json } from './modules/make_star_align_json.nf'
include { align_bams; align_bam_function } from './modules/align_bams.nf'
include { make_merge_align_json } from './modules/make_merge_align_json.nf'
include { merge_align; merge_align_function } from './modules/merge_align.nf'
include { merge_starsolo_reports; merge_starsolo_reports_function } from './modules/merge_starsolo_reports.nf'
include { make_knee_plot } from './modules/make_knee_plot.nf'
include { split_starsolo_stats } from './modules/split_starsolo_stats.nf'
include { cat_matrices_raw; cat_matrices_raw_function } from './modules/cat_matrices.nf'
include { make_umi_counts_json } from './modules/make_umi_counts_json.nf'
include { make_umi_counts; make_umi_counts_function} from './modules/make_umi_counts.nf'
include { make_cds_raw } from './modules/make_cds.nf'
include { run_scrublet } from './modules/run_scrublet.nf'
include { run_empty_drops } from './modules/run_empty_drops.nf'
include { make_barnyard_json } from './modules/make_barnyard_json.nf'
include { make_barnyard_plot; make_barnyard_plot_function } from './modules/make_barnyard_plot.nf'
include { make_generate_qc_hash; make_generate_qc_no_hash } from './modules/make_generate_qc.nf'

/*
** Set up channels.
*/
samplesheet_file = channel.fromPath(params.samplesheet_json)


/*
** Functions and closures.
*/

/*
** Set up channel from JSON map contents.
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
** Read JSON file into the corresponding lists + maps.
*/
def read_json(filename) {
  def file_json = new File(filename.toString())
  def json_text = file_json.getText()
  def json_slurper = new groovy.json.JsonSlurper()
  json_object = json_slurper.parseText(json_text) 
  return(json_object)
}

/*
** Convert a list of maps to a map of maps.
*/
def maps_list_to_maps_map(maps_list) {
    def maps_map = [:]
    maps_list.each{ inner_map ->
      def sample_name = inner_map['sample_name']
      maps_map[sample_name] = inner_map
    }
  return(maps_map)
}

/*
** Convert a list of maps into a Nextflow channel.
*/
def sample_maps_split_closure = {
  item ->
         def sample_name = item['sample_name']
         [sample_name, item]
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
  ** Make a JSON file with sample-specific values.
  */
  make_sample_map_json(samplesheet_file, genomes_data_file)
  make_sample_map_json.out.sample_maps.map{maps_list_to_maps_map(read_json(it))}.set{sample_maps_map}
  make_sample_map_json.out.sample_maps.splitJson().map{sample_maps_split_closure(it)}.set{sample_maps_split}

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
  **      must subscript the tuple variable to get the
  **      necessary element.
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
  ** Notes:
  **   o  use merge_demux.out.collect() so that this process
  **      waits for completion of merge_demux. This is necessary
  **      for finding the required paths in the work
  **      directory.
  */
  make_process_hashes_json(samplesheet_file, merge_demux.out.collect())
  make_process_hashes_json.out.splitJson().filter{it.size() > 0}.map{process_hashes_function(it)}.set{process_hashes_channel_in}
  process_hashes(process_hashes_channel_in)

  process_hashes.out.hash_matrix.groupTuple().join(process_hashes.out.hash_cells.groupTuple()).join(process_hashes.out.hash_hashes.groupTuple()).join(process_hashes.out.hash_umis_per_cell.groupTuple()).join(process_hashes.out.hash_dup_per_cell.groupTuple()).join(process_hashes.out.hash_reads_per_cell.groupTuple()).join(process_hashes.out.hash_assigned_table.groupTuple()).join(process_hashes.out.hash_log.groupTuple()).set{cat_hashes_in}
  cat_hashes(cat_hashes_in)

  hash_umi_knee_plot(cat_hashes.out.hash_umis_per_cell)
  calc_tot_hash_dup(cat_hashes.out.hash_dup_per_cell)

  /*
  ** Set up and run (cutadapt) read trimming.
  */
  make_trim_bam_json(samplesheet_file, merge_demux.out.collect())
  make_trim_bam_json.out.splitJson().map{trim_bam_function(it)}.set{trim_bam_channel_in}
  trim_bams(trim_bam_channel_in)

  /*
  ** Aggregate trimmer logs.
  */
  trim_bams.out.trimmer_logs.groupTuple().set { aggregate_trimmer_logs_channel_in }
  aggregate_trimmer_logs(aggregate_trimmer_logs_channel_in)

  /*
  ** Set up and run STAR aligner in STARsolo mode.
  */
  trim_bams.out.trimmed_bams.subscribe onNext: {
    path -> {
      def file_base_name = path.toString().tokenize('/').last()
      params.object_map.trim_bam_map[file_base_name] = path
    }
  }

  make_star_align_json(samplesheet_file, trim_bams.out.trimmed_bams.collect())
  make_star_align_json.out.splitJson().map{align_bam_function(it)}.combine(sample_maps_split, by: 0).set{align_bam_channel_in}
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
  make_knee_plot(cat_matrices_raw.out.raw_matrix)
  */

  /*
  ** Calculate UMIs per cell.
  ** Need
  **   o  concatenated matrix
  **   o  genome info
  */
  make_umi_counts_json(samplesheet_file, cat_matrices_raw.out.raw_matrix.collect())
  make_umi_counts_json.out.splitJson().map{make_umi_counts_function(it)}.join(sample_maps_split).set{make_umi_counts_in}
  make_umi_counts(make_umi_counts_in)

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
  cat_matrices_raw.out.raw_matrix.join(split_starsolo_stats.out.counts_per_cell).join(run_empty_drops.out.empty_drops_rds).join(make_umi_counts.out).join(sample_maps_split).set{make_cds_raw_in}
  make_cds_raw(make_cds_raw_in, 'counts_raw')

  /*
  ** Run scrublet.
  */
  run_scrublet(make_cds_raw.out.cds)

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
  */
  cat_hashes.out.hash_matrix.join(split_starsolo_stats.out.counts_per_cell).join(make_cds_raw.out.cds).set{assign_hash_raw_channel_in}
  assign_hash_raw(assign_hash_raw_channel_in)

  /*
  ** Make barnyard plots.
  make_barnyard_json(samplesheet_file, make_cds_raw.out.png.collect())
  make_barnyard_json.out.splitJson().map{make_barnyard_plot_function(it)}.set{make_barnyard_plot_in}
  make_barnyard_plot(make_barnyard_plot_in)
  */

  /*
  ** Run generate_qc.R.
  */
  assign_hash_raw.out.mobs.join(run_empty_drops.out.empty_drops_rds).join(sample_maps_split).set{make_generate_qc_hash_in}
  make_generate_qc_hash(make_generate_qc_hash_in, params.umi_cutoff)
  make_cds_raw.out.cds.join(run_empty_drops.out.empty_drops_rds).join(sample_maps_split).set{make_generate_qc_no_hash_in}
  make_generate_qc_no_hash(make_generate_qc_no_hash_in, params.umi_cutoff)
}


