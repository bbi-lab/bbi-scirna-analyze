def cat_matrices_function(item) {
  def sample_name = item['sample_name']
  def out_file = 'counts.raw'
  def in_dir_list = []
  for( in_dir in item['in_dir_list']) {
    def dir_base_name = in_dir.toString().tokenize('/').last()
    file_path = params.object_map.merge_align_bam_map[dir_base_name] + '/Solo.out/GeneFull_Ex50pAS/raw/matrix.mtx'
    /*
    ** If the file/value does not exist in
    ** params.object_map.merge_bam_map,
    ** skip this pipeline entry.
    */
    if(file_path == null) {
      continue
    }
    in_dir_list.add(file_path)
  }
  return([sample_name, out_file, in_dir_list])
}



def analyze_out = params.output_dir + '/analyze_out' 

process cat_matrices {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_file}", pattern: "*.raw.cells.tsv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_file}", pattern: "*.raw.features.tsv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_file}", pattern: "*.raw.matrix.mtx", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_file}", pattern: "*.raw.cells.barcode_to_wells.tsv", mode: 'copy'
/*
  publishDir path: "${analyze_out}/${sample_file}", pattern: "*.filtered.cells.tsv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_file}", pattern: "*.filtered.features.tsv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_file}", pattern: "*.filtered.matrix.mtx", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_file}", pattern: "*.filtered.cells.barcode_to_wells.tsv", mode: 'copy'
*/

  input:
  tuple val('sample_file'), val('out_file'), path('file')

  output:
  tuple val(sample_file), path("*.raw.cells.tsv"), path("*.raw.features.tsv"), path("*.raw.matrix.mtx"), path("*.raw.cells.barcode_to_wells.tsv"), emit: raw_matrix
/*
  tuple val(sample_file), path("*.filtered.cells.tsv"), path("*.filtered.features.tsv"), path("*.filtered.matrix.mtx"), emit: filtered_matrix
*/

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  #
  # Use the symbolic link referent because we use the path
  # to find the feature files in cat_sparse_matrix.py.
  #
  file_list=`ls file*`

  in_file_list=''
  for file in \${file_list}
  do
    file_path=`readlink \$file`
    in_file_list="\${in_file_list} \${file_path}"
  done

  cat_sparse_matrix.py -o ${out_file} -i \${in_file_list}

  barcode_to_well.py -i ${out_file}.cells.tsv -o ${out_file}.cells.barcode_to_wells.tsv

# Note: when the STAR input BAM file has few or no reads (after trimming)
#       the filtered directory does not exist.
#
  """
}


