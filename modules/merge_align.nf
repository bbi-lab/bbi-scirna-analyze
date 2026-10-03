def merge_align_function(item) {
  def sample_name = item['sample_name']
  def out_file = item['out_file']
  def in_dir_list = []
  item['in_dir_list'].each { in_dir ->
    def dir_base_name = in_dir.toString().tokenize('/').last()
    def file_path = params.object_map.merge_align_bam_map[dir_base_name] + '/Aligned.sortedByCoord.out.bam'
    /*
    ** If the file/value does not exist in
    ** params.object_map.merge_bam_map,
    ** skip this pipeline entry.
    */
    if(file_path == null) {
      return
    }
    in_dir_list.add(file_path)
  }
  return([sample_name, out_file, in_dir_list])
}



process merge_align {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: { "${params.output_dir}/analyze_out/${sample_name}" }, pattern: "*aligned.bam", mode: 'copy'
  publishDir path: { "${params.raw_log_dir}/${task.process}/${task.index}" }, mode: 'copy', pattern: 'version.json'

  input:
  tuple val(sample_name), val(out_file), path("files")

  output:
  path("*aligned.bam"), emit: 'bam'
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
    [ tool: 'sambamba',
      cmdVer: 'sambamba --version 2>&1 | grep "sambamba" | head -n 1',
      command: "sambamba sambamba merge -t 8 ${out_file} files*"
    ]
  ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}

  nfil=`ls files* | wc -l`

  if [ "\${nfil}" -gt 1 ]
  then
    sambamba merge -t 8 ${out_file} files*
  else
    cp files* ${out_file}
  fi
  """
}

