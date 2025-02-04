def analyze_out = params.output_dir + '/analyze_out' 

process merge_align {
//  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_dir}", pattern: "*.aligned.bam", mode: 'copy'

  input:
  tuple val('sample_dir'), val('out_file'), path('file')

  output:
  path("*.aligned.bam")

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

