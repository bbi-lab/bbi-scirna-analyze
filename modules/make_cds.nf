def make_cds_raw_genomes_function(item) {
  def sample_name = item['sample_name']
  def genome_name = item['genome']
  def tmp_genes_bed = item['tmp_genes_bed']
  def latest_genes_bed = item['latest_genes_bed']
  return([sample_name, genome_name, latest_genes_bed])
}

def analyze_out = params.output_dir + '/analyze_out'

process make_cds_raw {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.raw.mobs", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'

  input:
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells), path(counts_per_cell), path(empty_drops), path(mito_umis), val(genome), path(latest_genes_bed)
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
  ${mito_umis} \
  ${params.umi_cutoff} \
  ${counts_per_cell} \
  ${latest_genes_bed} \
  ${empty_drops}
  """
}


process make_cds_filtered {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.filtered.mobs", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'

  input:
//  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells)
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells), path(counts_per_cell), path(mito_umis), val(genome), path(latest_genes_bed)
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
  ${mito_umis} \
  ${params.umi_cutoff} \
  ${counts_per_cell} \
  ${latest_genes_bed}
  """
}

