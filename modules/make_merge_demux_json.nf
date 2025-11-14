def json_files_out = params.output_dir + '/json_files'

process make_merge_demux_json {
  publishDir path: "${json_files_out}", pattern: "merge_demux.json", mode: 'copy'

  input:
  path(samplesheet_file)
  val(bam_path)

  output:
  path("merge_demux.json")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_merge_demux_json.py -i $samplesheet_file -p $bam_path
  """
}
