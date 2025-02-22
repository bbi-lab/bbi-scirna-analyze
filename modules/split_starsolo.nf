analyze_out = params.output_dir + '/analyze_out' 

process split_starsolo {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}", pattern: "umis_per_cell_barcode.txt", mode: 'copy'

  input:
  tuple val(sample_name), path(file)

  output:
  tuple val(sample_name), path("umis_per_cell_barcode.txt"), emit: umis_per_cell_barcode

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  split_starsolo_stats.py -i ${file} -s ${sample_name}
  """
}

