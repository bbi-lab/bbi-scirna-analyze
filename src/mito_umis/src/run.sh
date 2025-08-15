#!/bin/bash

root_dir='/net/bbi/vol2/home/bge/bbi/tests/nobackup/RNA3-074-a.bbi_scirna.barnyard_plot.20250811/analyze_out/24.027-001'
matrix="${root_dir}/24.027-001_counts.raw.matrix.mtx"
features="${root_dir}/24.027-001_counts.raw.features.tsv"
barcodes="${root_dir}/24.027-001_counts.raw.cells.tsv"
annotations="/net/bbi/vol1/data/genomes_stage/human/human_rna/tmp.genes.bed"


# cargo run -- --matrix_file ${matrix} --feature_file ${features} --barcode_file ${barcodes} --annotations_file ${annotations} --out_file foo.tsv

/net/gs/vol1/home/bge/git/bbi-scirna-analyze/src/mito_umis/target/release/mito_umis --matrix_file ${matrix} --feature_file ${features} --barcode_file ${barcodes} --annotations_file ${annotations} --out_file foo.tsv
