process make_merge_align_json {
  input:
  path(samplesheet_file)
  path(dummy)

  output:
  path("merge_align.json")

  script:
  """
  $workflow.projectDir/bin/make_merge_align_json.py -i $samplesheet_file
  """
}
