def trim_bam_function(item) {
  def in_file = item['in_file']
  def file_path = params.object_map.merge_bam_map[in_file]
  def out_file = item['out_file']

  return([file_path, out_file])
}


process trim_bams {
  errorStrategy 'retry'
  maxRetries 2

  input:
  tuple path(bam_in), val(out_file)

  output:
  path("*.trimmed.bam")


  """
  # bash watch for errors
  set -ueo pipefail

  BBDUK=${task.ext.bbduk_path}

  \${BBDUK} -Xmx16g in=${bam_in} out=stdout.bam \
  ref='/net/gs/vol1/home/bge/git/bbi-scirna-analyze/bin/illumina_adapters.fa' \
  ktrim=r \
  k=16 \
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
}

