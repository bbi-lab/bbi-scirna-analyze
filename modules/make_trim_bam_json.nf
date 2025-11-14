def json_files_out = params.output_dir + '/json_files'

process make_trim_bam_json {
  publishDir path: "${json_files_out}", pattern: "trim_bam.json", mode: 'copy'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("trim_bam.json")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_trim_bam_json.py -i $samplesheet_file
  """
}
