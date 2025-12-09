def analyze_out = params.output_dir + '/analyze_out'

/*
** Run generate_qc.R.
*/

/*
**  -rw-r--r-- 1 bge bbi  446060 Oct 13 11:52 SeahubZ01-001_umi.png
**  -rw-r--r-- 1 bge bbi 1420808 Oct 13 11:52 SeahubZ01-001_genes_by_umi.png
**  -rw-r--r-- 1 bge bbi 4583384 Oct 13 11:53 SeahubZ01-001_RT_barcode_pseudobulk_correlations.txt
**  -rw-r--r-- 1 bge bbi     406 Oct 13 11:53 SeahubZ01-001_Ligation_plate_pseudobulk_correlations.txt
**  -rw-r--r-- 1 bge bbi      64 Oct 13 11:53 SeahubZ01-001_P5_barcode_pseudobulk_correlations.txt
**  -rw-r--r-- 1 bge bbi  726504 Oct 13 11:53 SeahubZ01-001_pseudobulk_heatmap.png
**  -rw-r--r-- 1 bge bbi  421581 Oct 13 11:53 SeahubZ01-001_pseudobulk_histogram.png
**  -rw-r--r-- 1 bge bbi   46560 Oct 13 11:53 SeahubZ01-001_hash_plots.png
**  -rw-r--r-- 1 bge bbi   80498 Oct 13 11:53 SeahubZ01-001_knee_plot.png
**  -rw-r--r-- 1 bge bbi       4 Oct 13 11:53 SeahubZ01-001_umi_cutoff.txt
**  -rw-r--r-- 1 bge bbi      17 Oct 13 11:53 SeahubZ01-001_no_collision.txt
*/


process make_generate_qc_hash {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.txt", mode: 'copy'

  input:
  tuple val(sample_name), path(cds_raw_hash_mobs), path(umi_counts), path(empty_drops_rds), val(sample_map)
  val(umi_cutoff)

  output:
  tuple val(sample_name), path("*.txt"), optional: true, emit: qc_txt
  tuple val(sample_name), path("*.png"), optional: true, emit: qc_png

  script:
  if(sample_map['hash_file'] == '')
    """
    # bash watch for errors
    set -ueo pipefail

    echo 'Not hash sample: skip make_generate_qc_hash'
    """
  else
    """
    # bash watch for errors
    set -ueo pipefail

    generate_qc.R ${cds_raw_hash_mobs} ${umi_counts} ${sample_name} ${empty_drops_rds} ${sample_map['hash_file']} ${sample_map['genome']} 'bbi-scirna-analyze' --specify_cutoff ${umi_cutoff}
    """
}


process make_generate_qc_no_hash {
  errorStrategy 'ignore'

  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.png", mode: 'copy'
  publishDir path: "${analyze_out}/${sample_name}", pattern: "*.txt", mode: 'copy'

  input:
  tuple val(sample_name), path(cds_raw_mobs), path(umi_counts), path(empty_drops_rds), val(sample_map)
  val(umi_cutoff)

  output:
  tuple val(sample_name), path("*.txt"), optional: true, emit: qc_txt
  tuple val(sample_name), path("*.png"), optional: true, emit: qc_png

  script:
  if(sample_map['hash_file'] == '')
    """
    # bash watch for errors
    set -ueo pipefail

    generate_qc.R ${cds_raw_mobs} ${umi_counts} ${sample_name} ${empty_drops_rds} 'false' ${sample_map['genome']} 'bbi-scirna-analyze' --specify_cutoff ${umi_cutoff}
    """
  else
    """
    # bash watch for errors
    set -ueo pipefail

    echo 'Hash sample: skip make_generate_qc_no_hash'
    """
}


