def analyze_out = params.output_dir + '/analyze_out'

process make_knee_plot {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_knee_plot.png", mode: 'copy'

  input:
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells)

  output:
  tuple val(sample_name), path("*_knee_plot.png"), emit: knee_plot

  """
  # bash watch for errors
  set -ueo pipefail

  umis_per_barcode -m ${count_matrix} -o umi_counts.out

  make_knee_plot.R ${sample_name} umi_counts.out
  """
}

