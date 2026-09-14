process merge_demux {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "logging/", pattern: "*.version.json", mode: 'copy'

  input:
  tuple val(sample_name), val(out_file), path('files')

  output:
  path("*.merged.bam"), emit: 'bam'
  path("*.version.json"), emit: 'version'
  path("command_provenance.txt"), emit: 'provenance'

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
       command: "samtools merge -@ 4 <out_file> *.sorted"
     ]
   ], nextflow, task, params)}

  mv version.json ${sample_name}.version.json

  file_list=`ls files*`
  for file in \$file_list
  do
    samtools sort -@ 4 -m 8G \${file} -o \${file}.sorted
  done
  samtools merge -@ 4 ${out_file} *.sorted
  rm -r *.sorted
  """
}

