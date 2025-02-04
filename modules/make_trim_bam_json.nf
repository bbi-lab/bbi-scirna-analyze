process make_trim_bam_json {
  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("trim_bam.json")

  script:
  """
  $workflow.projectDir/bin/make_trim_bam_json.py -i $samplesheet_file
  """
}
