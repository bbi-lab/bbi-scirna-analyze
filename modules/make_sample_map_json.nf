def json_files_out = params.output_dir + '/json_files'

process make_sample_map_json {
  publishDir path: "${json_files_out}", pattern: "sample_map.json", mode: 'copy'

  input:
  path(samplesheet_file)
  path(genomes_data_file)

  output:
  path("sample_map.json"), emit: sample_maps

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_sample_map_json.py -s ${samplesheet_file} -g ${genomes_data_file}
  """
}
