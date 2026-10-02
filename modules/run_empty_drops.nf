def analyze_out = params.output_dir + '/analyze_out'

process run_empty_drops {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_emptyDrops.RDS", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_emptyDrops.log", mode: 'copy'
  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells)

  output:
  tuple val(sample_name), path("*_emptyDrops.RDS"), emit: empty_drops_rds
  tuple val(sample_name), path("*_empty_drops_fdr.tsv"), emit: empty_drops_fdr
  path("*_emptyDrops.log"), emit: empty_drops_log
  path("version.json"), emit: 'version'

  /*
  ** Don't exit on error. Continue so that
  ** the merge_align is not aborted.
  */
  shell '/bin/bash', '-u'

  script:
  """

  ${LogUtil.emit([
     [ tool: 'run_emptyDrops.R',
       cmdVer: 'run_emptyDrops.R --version | head -n 1',
       command: "run_emptyDrops.R ${count_matrix} ${cell_tsv} ${feature_tsv} ${sample_name} <output_file>"
     ]
   ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}

  output_file="${sample_name}_emptyDrops.RDS"

  if [ "$params.run_empty_drops" == 'true' ]
  then
    run_emptyDrops.R ${count_matrix} ${cell_tsv} ${feature_tsv} ${sample_name} \${output_file}
    retVal=\$?
    if [ "\$retVal" -eq 0 ]
    then
      echo "emptyDrops ran successfully" >> ${sample_name}_run_emptyDrops.log
    else
      # make an empty emptyDrops.RDS file
      Rscript -e 'note <- "emptyDrops failed"; saveRDS(note, file="${sample_name}_emptyDrops.RDS")'
      printf 'cell\tFDR' > ${sample_name}_empty_drops_fdr.tsv
      echo "emptyDrops failed with error code \$retVal" >> ${sample_name}_run_emptyDrops.log
    fi
  else
    # make an empty emptyDrops.RDS file
    Rscript -e 'note <- "emptyDrops was skipped"; saveRDS(note, file="${sample_name}_emptyDrops.RDS")'
    printf 'cell\tFDR' > ${sample_name}_empty_drops_fdr.tsv
    echo "emptyDrops skipped by request" >> ${sample_name}_run_emptyDrops.log
  fi
  """
}

