def analyze_out = params.output_dir + '/analyze_out'

process make_knee_plot {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_knee_plot.png", mode: 'copy'

  input:
  tuple val(sample_name), path(umi_per_cell)

  output:
  tuple val(sample_name), path("*_knee_plot.png"), emit: knee_plot

  """
  # bash watch for errors
  set -ueo pipefail

  make_knee_plot.R ${sample_name} ${umi_per_cell}
  """
}

