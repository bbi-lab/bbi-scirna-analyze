def make_barnyard_plot_function(item) {
  def sample_name = item['sample_name']
  def out_file = item['out_file']
  def mobs_path = params.object_map.run_scrublet_cds_map[item['in_mobs']]
  def genome = item['genome']
  def barnyard_flag = item['barnyard_flag']
  return([sample_name, out_file, mobs_path, genome, barnyard_flag])
}


def analyze_out = params.output_dir + '/analyze_out'

process make_barnyard_plot {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_barnyard_plot.png", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_barnyard_collision.txt.png", mode: 'copy'

  input:
  tuple val(sample_name), val(out_file), path(in_mobs), val(genome), val(barnyard_flag)

  output:
  tuple val(sample_name), path("*_barnyard_plot.png"), path("*_barnyard_collision.txt"), emit: barnyard_plot

  """
  # bash watch for errors
  set -ueo pipefail

  make_barnyard_plot.R ${sample_name} ${genome} ${in_mobs}
  """
}

