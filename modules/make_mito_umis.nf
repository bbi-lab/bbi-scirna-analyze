def make_mito_umis_function(item) {
  def sample_name = item['sample_name']
  def genome = item['genome']
  def in_matrix = params.object_map.cat_matrices_raw_map[item['in_matrix']]
  def in_features = params.object_map.cat_matrices_raw_map[item['in_features']]
  def in_barcodes = params.object_map.cat_matrices_raw_map[item['in_barcodes']]
  def in_genes_bed = item['in_genes_bed']
  def out_file = item['out_file']
  return([sample_name, out_file, in_matrix, in_features, in_barcodes, in_genes_bed])
}


def analyze_out = params.output_dir + '/analyze_out'

process make_mito_umis {
  errorStrategy 'retry'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_mito_umis.tsv", mode: 'copy'

  input:
  tuple val(sample_name), val(out_file), path(in_matrix), path(in_features), path(in_barcodes), path(in_genes_bed)

  output:
  tuple val(sample_name), path("*_mito_umis.tsv")

  """
  # bash watch for errors
  set -ueo pipefail

  mito_umis -m ${in_matrix} -f ${in_features} -b ${in_barcodes} -a ${in_genes_bed} -o ${out_file}
  """
}

