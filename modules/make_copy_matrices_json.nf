process make_copy_matrices_json {

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("copy_matrices.json")

  script:
  """
  $workflow.projectDir/bin/make_copy_matrices_json.py -i $samplesheet_file
  """
}
