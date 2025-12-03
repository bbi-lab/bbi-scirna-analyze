def analyze_out = params.output_dir + '/analyze_out'
def exp_dash_out = params.output_dir + '/exp_dash'


process make_experiment_dashboard {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${exp_dash_out}", pattern: "js", mode: 'copy'
  publishDir path: "${exp_dash_out}", pattern: "img", mode: 'copy'

  input:
    path("*") // merge_starsolo_reports.out.cell_reads_stats
    path("*") // make_umi_counts.out.umi_counts_tsv
    path("*") // run_empty_drops.out.empty_drops_fdr
    path("*") // make_experiment_dashboard_png_channel_in
    path(sample_maps_json)
    val(umi_cutoff)
    val(fdr_cutoff)

  output:
    tuple path(js), path(img)


  script:
  """
  # bash watch for errors
  set -ueo pipefail

  #
  # Get sample names from sample_map.json file.
  #
  cat sample_map.json | grep 'sample_name' | sed 's/"sample_name"://' | sed 's/[",]//g' | sed 's/\s*//' > sample_names.txt

  #
  # Extract statistics into sample JSON files.
  #
  for sample_name in `cat sample_names.txt`
  do
    cellread_statistics_tsv="\${sample_name}.starsolo.cell_reads.stats"
    output_cellreads_statistics_json="\${sample_name}_cellreads_statistics.json"
    make_cellread_statistics.py -s \${sample_name} -c ${umi_cutoff} -i \${cellread_statistics_tsv} -o \${output_cellreads_statistics_json}

    umi_counts_tsv="\${sample_name}_umi_counts.tsv"
    empty_drops_fdr_tsv="\${sample_name}_empty_drops_fdr.tsv"
    output_umi_cell_json="\${sample_name}_umi_cell.json"
    make_umi_cell_counts_statistics.py -s \${sample_name} -c ${umi_cutoff} -f ${fdr_cutoff} -u \${umi_counts_tsv} -e \${empty_drops_fdr_tsv} -o \${output_umi_cell_json}
  done

  #
  # Make data.js file for dashboard.
  #
  project_directory=`basename ${workflow.launchDir}`
  make_exp_dash_data_js.py -s sample_names.txt -p \${project_directory}

  mkdir -p js
  cp data.js js

  mkdir -p img
  cp *.png img

  #
  # Make dashboard
  #
  """
}

