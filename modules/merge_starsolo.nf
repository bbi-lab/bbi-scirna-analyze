def merge_starsolo_function(item) {
  def sample_name = item['sample_name']
  def out_file = sample_name + '.starsolo.cell_reads.stats'
  def in_dir_list = []
  for( in_dir in item['in_dir_list']) {
    def dir_base_name = in_dir.toString().tokenize('/').last()
    file_path = params.object_map.merge_align_bam_map[dir_base_name] + '/Solo.out/GeneFull_Ex50pAS/CellReads.stats'
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
  return([sample_name, out_file, in_dir_list])
}


def analyze_out = params.output_dir + '/analyze_out' 

process merge_starsolo {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.starsolo.cell_reads.stats", mode: 'copy'

  input:
  tuple val('sample_name'), val('out_file'), path('file')

  output:
  tuple val(sample_name), path("*.starsolo.cell_reads.stats")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  cat_starsolo_stats.py -i ${file} -o ${out_file}
  """
}

