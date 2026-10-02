process merge_demux {
  cache 'lenient'
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${params.raw_log_dir}/${task.process}/${task.index}", mode: 'copy', pattern: 'version.json'

  input:
  tuple val(sample_name), val(out_file), path('files')

  output:
  path("*.merged.bam"), emit: 'bam'
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'samtools',
       cmdVer: 'samtools --version | head -n 2',
       command: "samtools sort -@ 4 -m 8G <file_in> -o <file_out.sorted>" 
     ],
     [ tool: 'samtools',
       cmdVer: 'samtools --version | head -n 2',
       command: "samtools merge -@ 4 ${out_file} *.sorted"
     ]
   ], nextflow, task, params, sample_name)}

  file_list=`ls files*`
  for file in \$file_list
  do
    samtools sort -@ 4 -m 8G \${file} -o \${file}.sorted
  done
  samtools merge -@ 4 ${out_file} *.sorted
  rm -r *.sorted
  """
}

