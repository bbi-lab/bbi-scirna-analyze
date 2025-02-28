process make_process_hashes_json {
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
