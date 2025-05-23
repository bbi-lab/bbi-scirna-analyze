def analyze_out = params.output_dir + '/analyze_out'

process make_cds_raw {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.raw.mobs", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'

  input:
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells), path(counts_per_cell), path(empty_drops)
  val(out_file)

  output:
  tuple val(sample_name), path("*.raw.mobs"), emit: cds
  tuple val(sample_name), path("*.png"), emit: png

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  make_cds.R \
  ${sample_name} \
  'raw' \
  ${count_matrix} \
  ${feature_tsv} \
  ${cell_tsv} \
  ${barcode_to_wells} \
  ${params.umi_cutoff} \
  ${counts_per_cell} \
  ${empty_drops}
  """
}


process make_cds_filtered {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.filtered.mobs", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'

  input:
//  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells)
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells), path(counts_per_cell)
  val(out_file)

  output:
  tuple val(sample_name), path("*.filtered.mobs"), emit: cds
  tuple val(sample_name), path("*.png"), emit: png

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  make_cds.R \
  ${sample_name} \
  'filtered' \
  ${count_matrix} \
  ${feature_tsv} \
  ${cell_tsv} \
  ${barcode_to_wells} \
  ${params.umi_cutoff} \
  ${counts_per_cell}
  """
}

