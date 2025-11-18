def analyze_out = params.output_dir + '/analyze_out'

process run_scrublet {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_scrublet_out.csv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "run_scrublet.lot", mode: 'copy'

  input:
  tuple val(sample_name), path(mobs), path(umi_counts)

  output:
  tuple val(sample_name), path("*scrublet_out.csv"), path("*.png"), path('run_scrublet.log')

  /*
  ** Don't exit on error. Continue so that
  ** the merge_align is not aborted.
  */
  shell '/bin/bash', '-u'

  script:
  """
  matrix_filename='scrublet_expression_matrix.mtx'
  if [ "$params.run_scrublet" == "true" ]
  then
    run_scrublet='--run_scrublet'
  else
    run_scrublet=''
  fi

  write_expression_matrix.R $sample_name $mobs \$matrix_filename
  run_scrublet.py --sample_name $sample_name --mat \$matrix_filename \${run_scrublet} > run_scrublet.log
  rm \$matrix_filename
  """
}

