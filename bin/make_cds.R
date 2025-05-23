#!/usr/bin/env Rscript

library(monocle3)
library(ggplot2)
library(data.table)


parser = argparse::ArgumentParser(description='Script to make final cds per sample.')
parser$add_argument('sample_name', help='Sample name.')
parser$add_argument('matrix_key', help='Is this \'raw\' or \'filtered\'?')
parser$add_argument('matrix', help='File of umi count matrix.')
parser$add_argument('gene_data', help='File of gene data.')
parser$add_argument('cell_data', help='File of cell data.')
parser$add_argument('barcodes_to_wells', help='File of encoded barcode indices and wells.')
parser$add_argument('umi_cutoff', help='UMI cutoff to count as a cell.')
parser$add_argument('counts_per_cell', help='Counts per cell from STARsolo CellReads.stats.')
# parser$add_argument('gene_bed', help='Bed file of gene info.')
parser$add_argument('empty_drops', help='RDS file from emptyDrops.')
# parser$add_argument('intron_fraction_file', help='Intron fraction of barcode UMIs file.')
# parser$add_argument('key', help='The sample name prefix.')

args = parser$parse_args()

# sample_name <- args$key

umi_cutoff = strtoi(args$umi_cutoff, 10L)

cds <- load_mm_data(mat_path=args$matrix,
                    feature_anno_path=args$gene_data,
                    cell_anno_path=args$cell_data,
                    umi_cutoff=umi_cutoff,
                    sep="",
                    matrix_control=list(matrix_class='BPCells'))
#                    feature_metadata_column_names=c('gene_short_name'), sep="")

#
# Assign percent mitochondrial reads to the cds.
#
counts_per_cell <- fread(args$counts_per_cell,
                         header = TRUE, data.table = F,
                         col.names = c("cell",
                                       "read_total_count",
                                       "umi_count_unique",
                                       "umi_count_multi",
                                       "umi_count_total",
                                       "exonic_read_count",
                                       "intronic_read_count",
                                       "mito_read_count"))

percent_mito_reads <- counts_per_cell[,c('cell')]
percent_mito_reads <- cbind(percent_mito_reads, 100.0 * counts_per_cell[['mito_read_count']] / counts_per_cell[['read_total_count']])
colnames(percent_mito_reads) <- c('cell', 'percent_mito_reads')
rownames(percent_mito_reads) <- percent_mito_reads[,1]
colData(cds)['percent_mito_reads'] <- percent_mito_reads[colData(cds)[['cell']],2]

#
# Add emptyDrops information.
#
emptydrops_data <- readRDS(args$empty_drops)

if(is(emptydrops_data, 'DFrame')) {
  pData(cds)[['emptyDrops_FDR']]         <- emptydrops_data[pData(cds)[,'cell'],]@listData[['FDR']]
  pData(cds)[['emptyDrops_Limited']]     <- emptydrops_data[pData(cds)[,'cell'],]@listData[['Limited']]
  metadata(pData(cds))$emptyDrops_lower  <- metadata(emptydrops_data)[['lower']]
  metadata(pData(cds))$emptyDrops_niters <- metadata(emptydrops_data)[['niters']]
  metadata(pData(cds))$emptyDrops_alpha  <- metadata(emptydrops_data)[['alpha']]
  metadata(pData(cds))$emptyDrops_retain <- metadata(emptydrops_data)[['retain']]
  metadata(pData(cds))$emptyDrops_ignore <- metadata(emptydrops_data)[['ignore']]
  metadata(pData(cds))$emptyDrops_round  <- metadata(emptydrops_data)[['round']]
  ed <- as.data.frame(pData(cds))[,c('cell', 'n.umi', 'emptyDrops_FDR')]
} else {
  ed <- as.data.frame(pData(cds))[,c('cell', 'n.umi')]
}

#
# Add barcode well string to colData(cds).
#
wells <- read.table(args$barcodes_to_wells, sep='\t', row.names=1)
colData(cds)['wells'] <- wells[row.names(colData(cds)),1]

cds <- cds[,Matrix::colSums(counts(cds)) != 0]
cds <- estimate_size_factors(cds)

if(ncol(counts(cds)) >= 51) {
  cds <- preprocess_cds(cds)
  cds <- reduce_dimension(cds)
  cds <- cluster_cells(cds)
  file_name <- paste0(args$sample_name, '_umap.', args$matrix_key, '.png')
  ggp_obj <- suppressMessages(plot_cells(cds))
  ggsave(filename=file_name, ggp_obj, device='png', width=5, height=5, dpi=600, units='in')
#  saveRDS(cds, file=paste0(args$sample_name, '_cds.', args$matrix_key, '.rds'))
  save_monocle_objects(cds, directory_path=paste0(args$sample_name, '_cds.', args$matrix_key, '.mobs'), archive_control=list(archive_type='none', archive_compression='none'))
}
