def make_cds_raw_genomes_function(item) {
  def sample_name = item['sample_name']
  def genome_name = item['genome']
  def tmp_genes_bed = item['tmp_genes_bed']
  def latest_genes_bed = item['latest_genes_bed']
  def hash_file = item['hash_file']
  return([sample_name, genome_name, latest_genes_bed, hash_file])
}

def analyze_out = params.output_dir + '/analyze_out'

process make_cds_raw {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.raw.mobs", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'

  input:
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells), path(counts_per_cell), path(empty_drops), path(umi_counts), val(genome), path(latest_genes_bed), val(hash_file), val(sample_map)
  val(out_file)

  output:
  tuple val(sample_name), val(genome), path("*.raw.mobs"), path(umi_counts), val(hash_file), emit: cds
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
  ${umi_counts} \
  ${params.umi_cutoff} \
  ${counts_per_cell} \
  ${sample_map['genes_bed']} \
  ${empty_drops}
  """
}


process make_cds_filtered {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.filtered.mobs", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'

  input:
//  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells)
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells), path(counts_per_cell), path(umi_counts), val(genome), path(latest_genes_bed), val(hash_file), val(sample_map)
  val(out_file)

  output:
  tuple val(sample_name), val(genome), path("*.filtered.mobs"), path(umi_counts), val(hash_file), emit: cds
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
  ${umi_counts} \
  ${params.umi_cutoff} \
  ${counts_per_cell} \
  ${sample_map['genes_bed']} \
  ${empty_drops}
  """
}

