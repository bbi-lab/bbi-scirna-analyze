def analyze_out = params.output_dir + '/analyze_out'

process make_cds {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.rds", mode: 'copy'

  input:
  path(count_matrix)
  path(feature_tsv)
  path(cell_tsv)
  val(sample_dir)
  val(out_file)

  output:
  path("*.rds")

  script:
  """
  make_cds.R \
  ${sample_dir} \
  ${count_matrix} \
  ${feature_tsv} \
  ${cell_tsv} \
  ${params.umi_cutoff}
  """
}

