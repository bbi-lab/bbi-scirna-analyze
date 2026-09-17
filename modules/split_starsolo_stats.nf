def analyze_out = params.output_dir + '/analyze_out' 

process split_starsolo_stats {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*counts_per_cell.txt", mode: 'copy'
  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  tuple val(sample_name), path(file)

  output:
  tuple val(sample_name), path("*counts_per_cell.txt"), emit: counts_per_cell
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'split_starsolo_stats.py',
       cmdVer: 'split_starsolo_stats.py --version | head -n 1',
       command: "split_starsolo_stats.py -i ${file} -s ${sample_name}"
     ]
   ], nextflow, task, params, sample_name)}

  split_starsolo_stats.py -i ${file} -s ${sample_name}
  """
}

