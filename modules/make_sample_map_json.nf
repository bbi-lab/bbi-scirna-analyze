def json_files_out = params.output_dir + '/json_files'

process make_sample_map_json {
  cache 'lenient'

  publishDir path: "${json_files_out}", pattern: "sample_map.json", mode: 'copy'
  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  path(samplesheet_file)
  path(genomes_data_file)

  output:
  path("sample_map.json"), emit: sample_maps
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'make_sample_map_json.py',
       cmdVer: 'make_sample_map_json.py --version | head -n 1',
       command: "make_sample_map_json.py -s $samplesheet_file -g ${genomes_data_file}"
     ]
   ], nextflow, task, params, 'NA')}

  $workflow.projectDir/bin/make_sample_map_json.py -s ${samplesheet_file} -g ${genomes_data_file}
  """
}
