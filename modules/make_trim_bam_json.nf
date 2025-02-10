def trim_bam_function(item) {
  def in_file = item['in_file']
  def file_path = params.object_map.merge_bam_map[in_file]
  def out_file = item['out_file']

  return([file_path, out_file])
}


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
