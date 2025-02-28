process make_trim_bam_json {
  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("trim_bam.json")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_trim_bam_json.py -i $samplesheet_file
  """
}
