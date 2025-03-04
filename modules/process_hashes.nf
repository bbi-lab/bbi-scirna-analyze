def process_hashes_function(item) {
  def sample_name = item['sample_name']
  def hash_file = item['hash_file']
  def out_file = item['out_file']

  def in_path_list = []
  for(in_file in item['in_file_list']) {
    def file_path = params.object_map.process_hashes_map[in_file]
    if(file_path == null) {
      continue
    }
    in_path_list.add(file_path)
  }
  return([sample_name, in_path_list, hash_file])
}


def analyze_out = params.output_dir + '/analyze_out'

process process_hashes {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.hashumis.mtx", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.hashumis_hashes.txt", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.hashumis_cells.txt", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_hash_reads_per_cell.txt", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_hash_umis_per_cell.txt", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_hash_dup_per_cell.txt", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_hash_assigned_table.txt", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_hash.log", mode: 'copy'

  input:
  tuple val(sample_name), path(bam_in), val(hash_file)

  output:
  tuple val(sample_name), path("*_hash_umis_per_cell.txt"), emit: hash_umis_per_cell
  tuple val(sample_name), path("*_hash_dup_per_cell.txt"), emit: hash_dup_per_cell
  tuple val(sample_name), path("*.hashumis.mtx"), path("*.hashumis_cells.txt"), path("*.hashumis_hashes.txt"), emit: hash_matrix
  path("*_hash_reads_per_cell.txt")
  path("*_hash_assigned_table.txt")
  path("*_hash.log")

  /*
  ** Notes:
  **   o  2 threads appears to be optimal
  */

  """
  # bash watch for errors
  set -ueo pipefail

  process_hashes -n ${sample_name} -k ${sample_name} -s ${hash_file} -b ${bam_in} -t 2
  """
}


process hash_umi_knee_plot {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_hash_knee_plot.png", mode: 'copy'

  input:
  tuple val(sample_name), path(hash_umis_per_cell)

  output:
  path("*_hash_knee_plot.png")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  knee_plot.R ${hash_umis_per_cell} ${sample_name}
  """
}


process calc_tot_hash_dup {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*_total_hash_dup_rate.csv", mode: 'copy'

  input:
  tuple val(sample_name), path(hash_dup_per_cell)

  output:
  path("*_total_hash_dup_rate.csv"), optional: true

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  if [ ${params.hash_dup} != 'false' ]
  then
    calc_tot_hash_dup.R ${sample_name} ${hash_dup_per_cell} ${params.hash_dup} 
  fi
  """
}


process assign_hash {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*hash_table.csv", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*hash_cds.RDS", mode: 'copy'

  input:
  tuple val(sample_name), path(hashumis_mtx), path(hashumis_cells_txt), path(hashumis_hashes_txt), path(counts_per_cell), path(rds)

  output:
  path("*hash_table.csv")
  tuple val(sample_name), path("*hash_cds.RDS")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  mkdir tmp_dir
  mv ${rds} tmp_dir

  #
  # Convert the well-based cell names to encoded barcode-based names,
  # and pass the converted cell names to assign_hash.R.
  #
  well_to_barcode.py -i ${hashumis_cells_txt} -o hashumis_cells.tmp1
  awk '{print \$2}' hashumis_cells.tmp1 > hashumis_cells.tmp2

  assign_hash.R \
    ${sample_name} \
    ${hashumis_mtx} \
    hashumis_cells.tmp2 \
    ${hashumis_hashes_txt} \
    tmp_dir/${rds} \
    ${counts_per_cell} \
    ${params.hash_umi_cutoff} \
    ${params.hash_ratio}

  rm hashumis_cells.tmp1 hashumis_cells.tmp2
  """
}

