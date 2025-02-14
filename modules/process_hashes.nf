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
  return([in_path_list, hash_file, sample_name])
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
  tuple path(bam_in), val(hash_file), val(sample_name)

  output:
  tuple val(sample_name), path("*_hash_umis_per_cell.txt"), emit: hash_umis_per_cell
  tuple val(sample_name), path("*_hash_dup_per_cell.txt"), emit: hash_dup_per_cell
  path("*.hashumis.mtx")
  path("*.hashumis_hashes.txt")
  path("*.hashumis_cells.txt")
  path("*_hash_reads_per_cell.txt")
  path("*_hash_assigned_table.txt")
  path("*_hash.log")

  /*
  ** Notes:
  **   o  2 threads appears to be optimal
  */

  """
  process_hashes -n ${sample_name} -k ${sample_name} -s ${hash_file} -b ${bam_in} -t 2
  """
}


process hash_umi_knee_plot {


}
