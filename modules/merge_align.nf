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


def analyze_out = params.output_dir + '/analyze_out' 

process merge_align {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.aligned.bam", mode: 'copy'

  input:
  tuple val('sample_dir'), val('out_file'), path('file')

  output:
  path("*.aligned.bam")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  file_list=`ls file*`
  for file in \$file_list
  do
    samtools sort -@ 4 -m 8G \${file} -o \${file}.sorted
  done
  samtools merge -@ 4 ${out_file} *.sorted
  rm -r *.sorted
  """
}

