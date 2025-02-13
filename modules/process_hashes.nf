

process process_hashes {
  errorStrategy 'retry'
  maxRetries 2

  input:
  tuple path(bam_in), val(hash_file), val(base_name)

/*
  output:
  path("*.trimmed.bam")
*/

  /*
  ** Notes:
  **   o  2 threads appears to be optimal
  */

  """
  process_hashes -n ${base_name} -k ${base_name} -s ${hash_file} -b ${bam_in} -t 2
  """
}

