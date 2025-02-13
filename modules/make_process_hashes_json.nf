def process_hashes_function(item) {
  def base_name = item['base_name']
  def hash_file = item['hash_file']
  def out_file = item['out_file']

  def in_path_list = []
  for(in_file in item['in_file_list']) {
    def file_path = params.object_map.process_hashes_map[in_file]
    if(file_path == null) {
      continue
    }
    in_path_list.add(file_path)
  }
  return([in_path_list, hash_file, base_name])
}


process make_process_hashes_json {
  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("process_hashes.json")

  script:
  """
  $workflow.projectDir/bin/make_process_hashes_json.py -i $samplesheet_file
  """
}
