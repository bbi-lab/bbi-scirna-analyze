def json_files_out = params.output_dir + '/json_files'

process make_process_hashes_json {
  publishDir path: "${json_files_out}", pattern: "process_hashes.json", mode: 'copy'
  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("process_hashes.json"), emit: json
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'make_process_hashes_json.py',
       cmdVer: 'make_process_hashes_json.py --version | head -n 1',
       command: "make_process_hashes_json.py -i $samplesheet_file"
     ]
   ], nextflow, task, params, 'NA')}

  $workflow.projectDir/bin/make_process_hashes_json.py -i $samplesheet_file
  """
}
