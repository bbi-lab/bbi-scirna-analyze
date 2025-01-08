#!/usr/bin/env Rscript

library(monocle3)
library(ggplot2)

parser = argparse::ArgumentParser(description='Script to make final cds per sample.')
parser$add_argument('sample_dir', help='Sample dir')
parser$add_argument('matrix', help='File of umi count matrix.')
parser$add_argument('gene_data', help='File of gene data.')
parser$add_argument('cell_data', help='File of cell data.')
parser$add_argument('umi_cutoff', help='UMI cutoff to count as a cell.')
# parser$add_argument('gene_bed', help='Bed file of gene info.')
# parser$add_argument('empty_drops', help='RDS file from emptyDrops.')
# parser$add_argument('intron_fraction_file', help='Intron fraction of barcode UMIs file.')
# parser$add_argument('key', help='The sample name prefix.')

args = parser$parse_args()

sample_name <- args$key

umi_cutoff = strtoi(args$umi_cutoff, 10L)

cds <- load_mm_data(mat_path=args$matrix,
                    feature_anno_path=args$gene_data,
                    cell_anno_path=args$cell_data,
                    umi_cutoff=umi_cutoff,
                    sep="")
#                    feature_metadata_column_names=c('gene_short_name'), sep="")

cds <- cds[,Matrix::colSums(counts(cds)) != 0]
cds <- estimate_size_factors(cds)

if(ncol(counts(cds)) >= 51) {
  cds <- preprocess_cds(cds)
  cds <- reduce_dimension(cds)
  cds <- cluster_cells(cds)
  saveRDS(cds, file=paste0(args$sample_dir, '_cds.rds'))
  file_name <- paste0('umap.png')
  ggp_obj <- suppressMessages(plot_cells(cds))
  ggsave(filename=file_name, ggp_obj, device='png', width=5, height=5, dpi=600, units='in')
#  save_monocle_objects(cds, directory_path=paste0(args$sample_dir))
}
