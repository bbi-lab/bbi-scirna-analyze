process make_sample_map_json {
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
