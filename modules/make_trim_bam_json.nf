def json_files_out = params.output_dir + '/json_files'

process make_trim_bam_json {
  publishDir path: "${json_files_out}", pattern: "trim_bam.json", mode: 'copy'
  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("trim_bam.json"), emit: json
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'make_trim_bam_json.py',
       cmdVer: 'make_trim_bam_json.py --version | head -n 1',
       command: "make_trim_bam_json.py -i $samplesheet_file"
     ]
   ], nextflow, task, params, 'NA')}

  $workflow.projectDir/bin/make_trim_bam_json.py -i $samplesheet_file
  """
}
