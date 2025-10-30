def json_files_out = params.output_dir + '/json_files'

process make_process_hashes_json {
  publishDir path: "${json_files_out}", pattern: "process_hashes.json", mode: 'copy'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("process_hashes.json")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_process_hashes_json.py -i $samplesheet_file
  """
}
