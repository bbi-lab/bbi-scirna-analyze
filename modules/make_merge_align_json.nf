def json_files_out = params.output_dir + '/json_files'

process make_merge_align_json {
  publishDir path: "${json_files_out}", pattern: "merge_align.json", mode: 'copy'
  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("merge_align.json"), emit: 'json'
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'make_merge_align_json.py',
       cmdVer: 'make_merge_align_json.py --version | head -n 1',
       command: "make_merge_align_json.py -i $samplesheet_file"
     ]
   ], nextflow, task, params, 'NA')}

  $workflow.projectDir/bin/make_merge_align_json.py -i $samplesheet_file
  """
}
