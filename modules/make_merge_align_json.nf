process make_merge_align_json {
  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("merge_align.json")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_merge_align_json.py -i $samplesheet_file
  """
}
