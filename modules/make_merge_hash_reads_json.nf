
process make_merge_hash_reads_json {
  publishDir path: "${params.output_dir}/json_files", pattern: "merge_hash_reads.json", mode: 'copy'
  publishDir path: { "${params.raw_log_dir}/${task.process}/${task.index}" }, mode: 'copy', pattern: 'version.json'

  input:
  path(samplesheet_file)
  val(tsv_path)

  output:
  path("merge_hash_reads.json")
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
    [ tool: 'make_merge_hash_reads_json.py',
      cmdVer: 'make_merge_hash_reads_json.py --version | head -n 2',
      command: "make_merge_hash_reads_json.py -i $samplesheet_file -p $tsv_path"
    ]
  ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}

  $workflow.projectDir/bin/make_merge_hash_reads_json.py -i $samplesheet_file -p $tsv_path
  """
}
