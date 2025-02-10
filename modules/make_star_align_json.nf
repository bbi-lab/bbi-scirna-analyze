def align_bam_function(item) {
  def in_file = item['in_file']
  def file_path = params.object_map.trim_bam_map[in_file]
  def genome  = item['genome']
  def mem     = item['mem']
  def out_dir = in_file.take(in_file.lastIndexOf('.'))

  return([file_path, genome, mem, out_dir])
}


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
