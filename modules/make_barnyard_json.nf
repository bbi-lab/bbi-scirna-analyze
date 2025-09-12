process make_barnyard_json {
  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("make_barnyard.json")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_barnyard_json.py -i $samplesheet_file
  """
}
