process make_merge_demux_json {
  input:
  path(samplesheet_file)
  val(bam_path)

  output:
  path("merge_demux.json")

  script:
  """
  $workflow.projectDir/bin/make_merge_demux_json.py -i $samplesheet_file -p $bam_path
  """
}
