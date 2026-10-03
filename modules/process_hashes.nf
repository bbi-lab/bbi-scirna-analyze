def process_hashes_function(item) {
  def sample_name = item['sample_name']
  def in_file = item['in_file']
  def hash_file = item['hash_file']
  def out_root = item['out_root']
  def in_file_path = params.object_map.process_hashes_map[in_file]

  return([sample_name, hash_file, in_file_path, out_root])
}


process process_hashes {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: { "${params.raw_log_dir}/${task.process}/${task.index}" }, mode: 'copy', pattern: 'version.json'

  input:
  tuple val(sample_name), val(hash_file), path(file_in), val(out_root)

  output:
  tuple val(sample_name), path("*.hashumis.mtx"), emit: 'hash_matrix'
  tuple val(sample_name), path("*.hashumis_cells.txt"), emit: 'hash_cells'
  tuple val(sample_name), path("*.hashumis_hashes.txt"), emit: 'hash_hashes'
  tuple val(sample_name), path("*_hash_umis_per_cell.txt"), emit: 'hash_umis_per_cell'
  tuple val(sample_name), path("*_hash_dup_per_cell.txt"), emit: 'hash_dup_per_cell'
  tuple val(sample_name), path("*_hash_reads_per_cell.txt"), emit: 'hash_reads_per_cell'
  tuple val(sample_name), path("*_hash_assigned_table.txt"), emit: 'hash_assigned_table'
  tuple val(sample_name), path("*_hash.log"), emit: 'hash_log'
  path("version.json"), emit: 'version'

  /*
  ** Notes:
  **   o  2 threads appears to be optimal
  */

  script:
  if("$params.sequencing_platform" == 'Illumina') {
    """
    # bash watch for errors
    set -ueo pipefail
  
    ${LogUtil.emit([
       [ tool: 'process_hashes_illumina',
         cmdVer: 'process_hashes_illumina --version | head -n 1',
         command: "process_hashes_illumina -n ${sample_name} -k ${out_root} -s ${hash_file} -b ${file_in} -t 2"
       ]
     ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}
  
    process_hashes_illumina -n ${sample_name} -k ${out_root} -s ${hash_file} -b ${file_in} -t 2
    """
  } else if("$params.sequencing_platform" == 'Ultima') {
    """
    # bash watch for errors
    set -ueo pipefail
 
    ${LogUtil.emit([
       [ tool: 'process_hashes_ultima',
         cmdVer: 'process_hashes_ultima --version | head -n 1',
         command: "process_hashes_ultima -n ${sample_name} -k ${out_root} -s ${hash_file} -t ${file_in}"
       ]
     ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}

    process_hashes_ultima -n ${sample_name} -k ${out_root} -s ${hash_file} -t ${file_in} 
    """
  } else {
    error "Unknown sequencing_platform: $params.sequencing_platform"
  }
}


process cat_hashes {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*.hashumis.mtx", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*.hashumis_hashes.txt", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*.hashumis_cells.txt", mode: 'copy'

  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_hash_assigned_table.txt", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_hash_dup_per_cell.txt", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_hash_reads_per_cell.txt", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_hash_umis_per_cell.txt", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_hash.log", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_hash_read_rate.txt", mode: 'copy'
  publishDir path: { "${params.raw_log_dir}/${task.process}/${task.index}" }, mode: 'copy', pattern: 'version.json'


  input:
  tuple val(sample_name), path("*_hashumis.mtx"), path("*_hashumis_cells.txt"), path("*_hashumis_hashes.txt"), path("*_hash_umis_per_cell_txt"), path("*_hash_dup_per_cell_txt"), path("*_hash_reads_per_cell_txt"), path("*_hash_assigned_table_txt"), path("*_hash_log")

  output:
  tuple val(sample_name), path("*.hashumis.mtx"), path("*.hashumis_cells.txt"), path("*.hashumis_hashes.txt"), emit: hash_matrix

  tuple val(sample_name), path("*_hash_umis_per_cell.txt"), emit: hash_umis_per_cell
  tuple val(sample_name), path("*_hash_dup_per_cell.txt"), emit: hash_dup_per_cell
  tuple val(sample_name), path("*_hash_read_rate.txt"), emit: hash_read_rate
  path("version.json"), emit: 'version'
  path("*_hash.log")
  path("*_hash_assigned_table.txt")
  path("*_hash_reads_per_cell.txt")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'cat_sparse_matrix.py',
       cmdVer: 'cat_sparse_matrix.py --version | head -n 1',
       command: "cat_sparse_matrix.py -i *_hashumis.mtx -m hashumis.mtx -f hashumis_hashes.txt -c hashumis_cells.txt -o ${sample_name}"
     ]
   ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}

  #
  # Check that groupTuple grouped files correctly by
  # ensuring that the last hash directory is consistent
  # for each file set.
  #
  lprefix=`ls *_hashumis_hashes.txt | awk 'BEGIN{FS="_"}{print\$1}'`

  for prefix in \$lprefix
  do
    nhash=`readlink \${prefix}_* | awk 'BEGIN{FS="/"}{print \$(NF-1)}' | uniq | wc -l`
    if [ "\$nhash" !=  "1" ]
    then
      echo "Error: inconsistent work directories in input grouped files (symbolic links)."
      exit -1
    fi
  done

  #
  # Concatenate matrices etc.
  #
  cat_sparse_matrix.py -i *_hashumis.mtx -m hashumis.mtx -f hashumis_hashes.txt -c hashumis_cells.txt -o "${sample_name}"
  mv ${sample_name}.matrix.mtx ${sample_name}.hashumis.mtx
  mv ${sample_name}.cells.tsv ${sample_name}.hashumis_cells.txt
  mv ${sample_name}.features.tsv ${sample_name}.hashumis_hashes.txt

  cat *_hash_assigned_table_txt > ${sample_name}_hash_assigned_table.txt
  cat *_hash_dup_per_cell_txt > ${sample_name}_hash_dup_per_cell.txt
  cat *_hash_reads_per_cell_txt > ${sample_name}_hash_reads_per_cell.txt
  cat *_umis_per_cell_txt > ${sample_name}_hash_umis_per_cell.txt
  cat *_hash_log > ${sample_name}_hash.log

  #
  # Calculate hash read rate.
  #
  grep '^Read_counts' ${sample_name}_hash.log | awk 'BEGIN{sum_reads=0; sum_hashes=0}{sum_reads+=\$2; sum_hashes+=\$3}END{printf(\"Total reads: %d\\nHash reads: %d\\nHash rate: %.4f\\n\", sum_reads, sum_hashes, sum_hashes/sum_reads);}' > ${sample_name}_hash_read_rate.txt

  """
}


process hash_umi_knee_plot {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_hash_knee_plot.png", mode: 'copy'
  publishDir path: { "${params.raw_log_dir}/${task.process}/${task.index}" }, mode: 'copy', pattern: 'version.json'

  input:
  tuple val(sample_name), path(hash_umis_per_cell)

  output:
  path("*_hash_knee_plot.png"), emit: 'plot'
  path("version.json"), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'make_hash_knee_plot.R',
       cmdVer: 'make_hash_knee_plot.R --version | head -n 1',
       command: "make_hash_knee_plot.R ${hash_umis_per_cell} ${sample_name}"
     ]
   ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}

  make_hash_knee_plot.R ${hash_umis_per_cell} ${sample_name}
  """
}


process calc_tot_hash_dup {
  errorStrategy 'retry'
  maxRetries 2

  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_total_hash_dup_rate.csv", mode: 'copy'
  publishDir path: { "${params.raw_log_dir}/${task.process}/${task.index}" }, mode: 'copy', pattern: 'version.json'

  input:
  tuple val(sample_name), path(hash_dup_per_cell)

  output:
  path("*_total_hash_dup_rate.csv"), optional: true
  path('version.json'), emit: 'version'

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'calc_tot_hash_dup.R',
       cmdVer: 'calc_tot_hash_dup.R --version 2>&1 | grep "^calc_tot_hash_dup"',
       command: "calc_tot_hash_dup.R ${sample_name} ${hash_dup_per_cell} ${params.hash_dup}"
     ]
  ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}

  if [ ${params.hash_dup} != 'false' ]
  then
    calc_tot_hash_dup.R ${sample_name} ${hash_dup_per_cell} ${params.hash_dup} 
  fi
  """
}


process assign_hash_raw {
  errorStrategy 'retry'
  maxRetries 1

  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*hash_table.raw.csv", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*hash_cds.raw.mobs", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*_hash_cds.raw.col_data.tsv", mode: 'copy'
  publishDir path: { "${params.raw_log_dir}/analyze_out/${task.process}/${task.index}" }, mode: 'copy', pattern: 'version.json'

  input:
  tuple val(sample_name), path(hashumis_mtx), path(hashumis_cells_txt), path(hashumis_hashes_txt), path(counts_per_cell), path(mobs), path(umi_counts)

  output:
  path("*hash_table.raw.csv"), emit: hash_table
  tuple val(sample_name), path("*hash_cds.raw.mobs"), path(umi_counts), emit: mobs
  tuple val(sample_name), path("*_hash_cds.raw.col_data.tsv"), emit: col_data
  path('version.json'), emit: 'version'
  
  script:
  """
  # bash watch for errors
  set -ueo pipefail

  ${LogUtil.emit([
     [ tool: 'assign_hash.R',
       cmdVer: 'assign_hash.R --version | head -n 1',
       command: "assign_hash.R \
    ${sample_name} \
    'raw' \
    ${hashumis_mtx} \
    hashumis_cells.tmp2 \
    ${hashumis_hashes_txt} \
    tmp_dir/${mobs} \
    ${counts_per_cell} \
    ${params.hash_umi_cutoff} \
    ${params.hash_ratio}"
     ]
  ], task.process, "${task.index}", "${task.container}", "${nextflow.version}", "${params.version}", sample_name)}

  mkdir tmp_dir
  mv ${mobs} tmp_dir

  #
  # Convert the well-based cell names to encoded barcode-based names,
  # and pass the converted cell names to assign_hash.R.
  #
  well_to_barcode.py -i ${hashumis_cells_txt} -o hashumis_cells.tmp1

  #
  # Sanity test.
  #
  awk '{print \$1}' hashumis_cells.tmp1 > hashumis_cells.tmp3
  diff ${hashumis_cells_txt} hashumis_cells.tmp3
  exit_value=\$?
  if [ \$exit_value -eq 1 ]
  then
    echo 'Error: inconsistent cell names in well_to_barcode.py output file.'
    exit -1
  fi
  rm hashumis_cells.tmp3

  awk '{print \$2}' hashumis_cells.tmp1 > hashumis_cells.tmp2

  assign_hash.R \
    ${sample_name} \
    'raw' \
    ${hashumis_mtx} \
    hashumis_cells.tmp2 \
    ${hashumis_hashes_txt} \
    tmp_dir/${mobs} \
    ${counts_per_cell} \
    ${params.hash_umi_cutoff} \
    ${params.hash_ratio}

  write_col_data.R ${sample_name}_hash_cds.raw.mobs ${sample_name}_hash_cds.raw.col_data.tsv

  rm hashumis_cells.tmp1 hashumis_cells.tmp2
  rm -r tmp_dir
  """
}


process assign_hash_filtered {
  errorStrategy 'retry'
  maxRetries 1

  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*hash_table.filtered.csv", mode: 'copy'
  publishDir path: { "${params.output_dir }/analyze_out/${sample_name}" }, pattern: "*hash_cds.filtered.mobs", mode: 'copy'

  input:
  tuple val(sample_name), path(hashumis_mtx), path(hashumis_cells_txt), path(hashumis_hashes_txt), path(counts_per_cell), val(genome), path(mobs), path(umi_counts), val(hash_file)

  output:
  path("*hash_table.filtered.csv")
  tuple val(sample_name), path("*hash_cds.filtered.mobs")

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  mkdir tmp_dir
  mv ${mobs} tmp_dir

  #
  # Convert the well-based cell names to encoded barcode-based names,
  # and pass the converted cell names to assign_hash.R.
  #
  well_to_barcode.py -i ${hashumis_cells_txt} -o hashumis_cells.tmp1
  awk '{print \$2}' hashumis_cells.tmp1 > hashumis_cells.tmp2

  assign_hash.R \
    ${sample_name} \
    'filtered' \
    ${hashumis_mtx} \
    hashumis_cells.tmp2 \
    ${hashumis_hashes_txt} \
    tmp_dir/${mobs} \
    ${counts_per_cell} \
    ${params.hash_umi_cutoff} \
    ${params.hash_ratio}

  rm hashumis_cells.tmp1 hashumis_cells.tmp2
  rm -r tmp_dir
  """
}

