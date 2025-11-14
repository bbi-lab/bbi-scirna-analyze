def json_files_out = params.output_dir + '/json_files'

process make_star_align_json {
  publishDir path: "${json_files_out}", pattern: "star_align.json", mode: 'copy'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("star_align.json")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_star_align_json.py -i $samplesheet_file
  """
}
