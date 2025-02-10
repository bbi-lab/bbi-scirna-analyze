def merge_align_function(item) {
  def sample_dir = item['sample_dir']
  def out_file = item['out_file']
  def in_dir_list = []
  for( in_dir in item['in_dir_list']) {
    def dir_base_name = in_dir.toString().tokenize('/').last()
    file_path = params.object_map.merge_align_bam_map[dir_base_name] + '/Aligned.sortedByCoord.out.bam'
    /*
    ** If the file/value does not exist in
    ** params.object_map.merge_bam_map,
    ** skip this pipeline entry.
    */
    if(file_path == null) {
      continue
    }
    in_dir_list.add(file_path)
  }
  return([sample_dir, out_file, in_dir_list])
}


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
