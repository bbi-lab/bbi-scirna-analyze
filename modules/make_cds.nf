def analyze_out = params.output_dir + '/analyze_out'

process make_cds {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.rds", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'

  input:
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells)
  val(out_file)

  output:
  tuple val(sample_name), path("*.rds"), emit: cds
  tuple val(sample_name), path("*.png"), emit: png

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  make_cds.R \
  ${sample_name} \
  ${count_matrix} \
  ${feature_tsv} \
  ${cell_tsv} \
  ${barcode_to_wells} \
  ${params.umi_cutoff}
  """
}

