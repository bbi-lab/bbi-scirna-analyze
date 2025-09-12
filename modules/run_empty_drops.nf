def analyze_out = params.output_dir + '/analyze_out'

process run_empty_drops {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_emptyDrops.RDS", mode: 'copy'

  input:
  tuple val(sample_name), path(cell_tsv), path(feature_tsv), path(count_matrix), path(barcode_to_wells)

  output:
  tuple val(sample_name), path("*_emptyDrops.RDS")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  output_file="${sample_name}_emptyDrops.RDS"

  if [ "$params.run_empty_drops" == 'true' ]
  then
    run_emptyDrops.R ${count_matrix} ${cell_tsv} ${feature_tsv} ${sample_name} \${output_file}
  else
      # make an empty emptyDrops.RDS file
      Rscript -e 'note <- "emptyDrops was skipped"; saveRDS(note, file="${sample_name}_emptyDrops.RDS")'
      printf "    emptyDrops skipped by request\n\n" >> run_emptyDrops.log
  fi

  """
}

