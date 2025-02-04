def analyze_out = params.output_dir + '/analyze_out' 

process cat_matrices {
//  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.raw.cells.tsv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.raw.features.tsv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.raw.matrix.mtx", mode: 'copy'
/*
  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.filtered.cells.tsv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.filtered.features.tsv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.filtered.matrix.mtx", mode: 'copy'
*/

  input:
  tuple val('sample_dir'), val('out_file'), path('file')

  output:
  path("*.raw.cells.tsv"),          emit: cells
  path("*.raw.features.tsv"),       emit: features
  path("*.raw.matrix.mtx"),         emit: matrix
/*
  path("*.filtered.cells.tsv"),     emit: cells_filtered
  path("*.filtered.features.tsv"),  emit: features_filtered
  path("*.filtered.matrix.mtx"),    emit: matrix_filtered
*/
  val(sample_dir),                  emit: sample_dir

  script:
  """
  file_list=`ls file*`

  in_file_list=''
  for file in \${file_list}
  do
    base_dir=`readlink \$file | sed 's/\\/Aligned.sortedByCoord.out.bam//'`
    in_file_list="\${in_file_list} \${base_dir}/Solo.out/GeneFull_Ex50pAS/raw/matrix.mtx"
  done
  sparse_matrix_cat.py -o counts.raw -i \${in_file_list}

# Note: when the STAR input BAM file has few or no reads (after trimming)
#       the filtered directory does not exist.
#
#   in_file_list=''
#   for file in \${file_list}
#   do
#     base_dir=`readlink \$file | sed 's/\\/Aligned.sortedByCoord.out.bam//'`
#     in_file_list="\${in_file_list} \${base_dir}/Solo.out/GeneFull_Ex50pAS/filtered/matrix.mtx"
#   done
#   sparse_matrix_cat.py -o counts.filtered -i \${in_file_list}
  """
}


