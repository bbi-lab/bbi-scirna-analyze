def json_files_out = params.output_dir + '/json_files'

process make_umi_counts_json {
  publishDir path: "${json_files_out}", pattern: "umi_counts.json", mode: 'copy'
  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("umi_counts.json"), emit: umi_counts
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'make_umi_counts_json.py',
       cmdVer: 'make_umi_counts_json.py --version | head -n 1',
       command: "make_umi_counts_json.py -i $samplesheet_file"
     ]
   ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", 'NA')}

  $workflow.projectDir/bin/make_umi_counts_json.py -i $samplesheet_file
  """
}
