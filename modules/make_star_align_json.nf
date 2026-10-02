def json_files_out = params.output_dir + '/json_files'

process make_star_align_json {
  publishDir path: "${json_files_out}", pattern: "star_align.json", mode: 'copy'
  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("star_align.json"), emit: 'json'
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'make_star_align_json.py',
       cmdVer: 'make_star_align_json.py --version | head -n 1',
       command: "make_star_align_json.py -i $samplesheet_file"
     ]
   ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", 'NA')}

  $workflow.projectDir/bin/make_star_align_json.py -i $samplesheet_file -p ${params.sequencing_platform}
  """
}
