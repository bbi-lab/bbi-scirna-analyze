process merge_demux {
  errorStrategy 'retry'
  maxRetries 3
  
  input:
  tuple val('out_file'), path('files')

  output:
  path("*.merged.bam")

  script:
  """
  file_list=`ls file*`
  for file in \$file_list
  do
    samtools sort -@ 4 -m 8G \${file} -o \${file}.sorted
  done
  samtools merge -@ 4 ${out_file} *.sorted
  rm -r *.sorted
  """
}



