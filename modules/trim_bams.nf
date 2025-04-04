def trim_bam_function(item) {
  def sample_name = item['sample_name']
  def in_file = item['in_file']
  def file_path = params.object_map.merge_bam_map[in_file]
  def out_file = item['out_file']

  return([sample_name, file_path, out_file])
}


process trim_bams {
  errorStrategy 'retry'
  maxRetries 2

  input:
  tuple val(sample_name), path(bam_in), val(out_file)

  output:
  path("*.trimmed.bam")


  """
  # bash watch for errors
  set -ueo pipefail


  #
  # Skip empty BAM files.
  #
  # Using head sets the pipefail error: 141 so
  # remove the shell test for pipefail.
  #
  nread=`samtools head -h 0 -n 10 ${bam_in} | wc -l`
  if [ "\${nread}" == "0" ]
  then
    cp ${bam_in} ${out_file}
    exit 0
  fi

  samtools fastq -T '*' -@ 3 ${bam_in} > tmp.fq

  if [ " ${task.ext.extra_adapters_trim_galore}" != "null" ]
  then
    EXTRA_ADAPTERS="${task.ext.extra_adapters_trim_galore}"
  else
    EXTRA_ADAPTERS=""
  fi

  trim_galore \${EXTRA_ADAPTERS} -a AAAAAAAA -j 3 tmp.fq
  rm -f tmp.fq

  nread=`wc -l tmp_trimmed.fq | awk '{print\$1}'`
  if [ "\${nread}" == "0" ]
  then
    cp ${bam_in} ${out_file}
    exit 0
  fi

  samtools import -T '*' -@ 3 tmp_trimmed.fq -o ${out_file}
  rm tmp_trimmed.fq
  """
}

/*
** Atrops trimming
**
  # bash watch for errors
  set -ueo pipefail


  #
  # Skip empty BAM files.
  #
  # Using head sets the pipefail error: 141 so
  # remove the shell test for pipefail.
  #
  nread=`samtools head -h 0 -n 10 ${bam_in} | wc -l`
  if [ "\${nread}" == "0" ]
  then
    cp ${bam_in} ${out_file}
    exit 0
  fi

  #
  # Detect primers.
  #
  atropos detect \
    -F ${task.ext.adapters_fasta} \
    --max-reads 25000 \
    -se ${bam_in} \
    -o atropos.detect_adapters.fasta

  #
  # Trim reads.
  # Notes:
  #   o save to a temp. file in case atropos outputs no
  #     reads. samtools chokes if the input file is
  #     empty, apparently.
  #
  samtools fastq -T '*' -@ 2 ${bam_in} \
  | atropos trim \
     -se - \
     -a file:atropos.detect_adapters.0.fasta \
     -a AAAAAAAA \
     -m 20 \
     --threads 2 \
     --report-file ${sample_name}_log.txt \
     -o tmp.fastq

  nread=`wc -l tmp.fastq | awk '{print\$1}'`
  if [ "\${nread}" == "0" ]
  then
    cp ${bam_in} ${out_file}
    exit 0
  fi

  samtools import -T '*' -@ 2 tmp.fastq -o ${out_file}
  rm tmp.fastq
  """
*/


/*
** BBDUK.sh trimming script.
**
  # bash watch for errors
  set -ueo pipefail

  BBDUK=${task.ext.bbduk_path}
  ADAPTERS_FA=${task.ext.adapters_fasta}


  \${BBDUK} -Xmx16g in=${bam_in} out=stdout.bam \
  ref=\${ADAPTERS_FA} \
  ktrim=r \
  k=34 \
  mink=11 \
  rcomp=f \
  trimclip=t \
  | \${BBDUK} -Xmx16g in=stdin.bam out=${out_file} \
  literal="AAAAAAAA" \
  ktrim=r \
  k=8 \
  rcomp=f \
  maskmiddle=f \
  trimclip=t \
  minlength=20
  """
*/
