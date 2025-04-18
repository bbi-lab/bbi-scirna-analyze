def trim_bam_function(item) {
  def sample_name = item['sample_name']
  def root_file = item['root_file']
  def in_file = item['in_file']
  def file_path = params.object_map.merge_bam_map[in_file]
  def out_file = item['out_file']

  return([sample_name, root_file, file_path, out_file])
}


def analyze_out = params.output_dir + '/analyze_out'

process trim_bams {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}/cutadapt", pattern: "*.trimmed.bam", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}/cutadapt", pattern: "*.cutadapt_report.txt", mode: 'copy'

  input:
  tuple val(sample_name), val(root_file), path(bam_in), val(out_file)

  output:
  path("*.trimmed.bam"), emit: trimmed_bams
  path("*.cutadapt_report.txt"), emit: trim_log


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
    touch ${root_file}.cutadapt_report.txt
    exit 0
  fi

  #
  # Atropos is a fork of cutadapt, it has the addition
  # of the 'detect' adapter mode. I do not use it because
  # I don't have much information about atropos but I
  # include this commented out code in case it becomes
  # more useful in the future.
  #
  # The output file has the name 'atropos.detect_adapters.0.fasta'.
  #
  # atropos detect \
  #   -F ${projectDir}/data/atropos.sequencing_adapters.fasta \
  #   --max-reads 25000 \
  #   -se ${bam_in} \
  #   -o atropos.detect_adapters.fasta
  #

  #
  # Use samtools -T '*' to preserve BAM tag information.
  #
  samtools fastq -T '*' -@ 3 ${bam_in} > tmp.fq

  ADAPTOR_FASTA=${projectDir}/data/illumina_adapters.fasta

  #
  # Notes:
  #   o  polyA sequence is not in the default adapter sequence
  #      file. Add it if you need it.
  #
  cutadapt -a file:\${ADAPTOR_FASTA} --report=full -o ${root_file}_trimmed.fq tmp.fq 1> ${root_file}.cutadapt_report.txt

  rm -f tmp.fq

  nread=`wc -l ${root_file}_trimmed.fq | awk '{print\$1}'`
  if [ "\${nread}" == "0" ]
  then
    cp ${bam_in} ${out_file}
    touch ${root_file}_trimming_report.txt
    exit 0
  fi

  samtools import -T '*' -@ 3 ${root_file}_trimmed.fq -o ${out_file}
  rm ${root_file}_trimmed.fq
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
