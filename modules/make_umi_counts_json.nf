def json_files_out = params.output_dir + '/json_files'

process make_umi_counts_json {
  publishDir path: "${json_files_out}", pattern: "umi_counts.json", mode: 'copy'

  input:
  path(samplesheet_file)
  val(dummy)

  output:
  path("umi_counts.json"), emit: umi_counts

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_umi_counts_json.py -i $samplesheet_file
  """
}
