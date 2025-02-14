process make_star_align_json {
  input:
  path(samplesheet_file)
  val(star_genomes_file)
  val(dummy)

  output:
  path("star_align.json")

  script:
  """
  $workflow.projectDir/bin/make_star_align_json.py -i $samplesheet_file -g $star_genomes_file
  """
}
