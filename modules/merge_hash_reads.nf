process merge_hash_reads {
  cache 'lenient'
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  tuple val('sample_name'), val('out_file'), path('files')

  output:
  path("*.hash_reads.merged.tsv")
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
    [ tool: 'merge_hash_reads.py',
      cmdVer: 'merge_hash_reads.py --version | head -n 1',
      command: "merge_hash_reads.py -i \${file_list} -o ${out_file}"
    ]
  ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", 'NA')}

  file_list=`ls files*`
  $workflow.projectDir/bin/merge_hash_reads.py -i \${file_list} -o ${out_file}
  """
}

