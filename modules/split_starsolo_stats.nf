def analyze_out = params.output_dir + '/analyze_out' 

process split_starsolo_stats {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*counts_per_cell.txt", mode: 'copy'

  input:
  tuple val(sample_name), path(file)

  output:
  tuple val(sample_name), path("*counts_per_cell.txt"), emit: counts_per_cell

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  split_starsolo_stats.py -i ${file} -s ${sample_name}
  """
}

