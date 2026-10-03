process make_merge_demux_json {
  cache 'lenient'

  publishDir path: "${params.output_dir}/json_files", pattern: "merge_demux.json", mode: 'copy'
  publishDir path: { "${params.raw_log_dir}/${task.process}/${task.index}" }, mode: 'copy', pattern: 'version.json'

  input:
  path(samplesheet_file)
  val(bam_path)

  output:
  path("merge_demux.json"), emit: 'json'
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
    [ tool: 'make_merge_demux_json.py',
      cmdVer: 'make_merge_demux_json.py --version | head -n 1',
      command: "make_merge_demux_json.py -i $samplesheet_file -p $bam_path"
    ]
  ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", 'NA')}

  $workflow.projectDir/bin/make_merge_demux_json.py -i $samplesheet_file -p $bam_path
  """
}


