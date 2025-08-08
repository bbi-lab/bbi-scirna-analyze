#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
  library(argparse)
  library(monocle3)
})


parser = argparse::ArgumentParser(description='Script to make a barnyard plot.')
parser$add_argument('plot_type', help='Plot type: \'barnyard\' or \'fishbowl\'')
parser$add_argument('sample_name', help='Sample name.')
parser$add_argument('cds_path', help='File with cds.')
args = parser$parse_args()


cds_path <- args$cds_path
sample_name <- args$sample_name
plot_type <- args$plot_type

make_plot <- function(cds_path, sample_name, plot_type) {
  plot_type_dict = list('barnyard' = list('organism_1_tag' = 'Mouse',     'gene_1_tag' = 'ENSMUSG', 'organism_2_tag' = 'Human', 'gene_2_tag' = 'ENSG' ),
                        'fishbowl' = list('organism_1_tag' = 'Zebrafish', 'gene_1_tag' = 'ZEBRAFISH_',    'organism_2_tag' = 'Mouse',  'gene_2_tag' = 'MOUSE_' ))

  organism_1_tag <- plot_type_dict[[plot_type]][['organism_1_tag']]
  organism_2_tag <- plot_type_dict[[plot_type]][['organism_2_tag']]
  gene_1_tag <- plot_type_dict[[plot_type]][['gene_1_tag']]
  gene_2_tag <- plot_type_dict[[plot_type]][['gene_2_tag']]

  cds <- readRDS(cds_path)

  fData(cds)[organism_1_tag] <- grepl(gene_1_tag, rownames(fData(cds)))
  fData(cds)[organism_2_tag] <- grepl(gene_2_tag, rownames(fData(cds)))

  pData(cds)[['organism_1_umi']] <- Matrix::colSums(exprs(cds)[fData(cds)[[organism_1_tag]],])
  pData(cds)[['organism_2_umi']] <- Matrix::colSums(exprs(cds)[fData(cds)[[organism_2_tag]],])
  pData(cds)$total_umi <- pData(cds)[['organism_1_umi']] + pData(cds)[['organism_2_umi']]
  pData(cds)$organism_1_perc <- pData(cds)[['organism_1_umi']] / pData(cds)$total_umi
  pData(cds)$organism_2_perc <- pData(cds)[['organism_2_umi']] / pData(cds)$total_umi
  pData(cds)$collision <- ifelse(pData(cds)$organism_1_perc >= .9 | pData(cds)$organism_2_perc >= .9, FALSE, TRUE)

  plot = ggplot(as.data.frame(pData(cds)), aes(organism_1_umi, organism_2_umi, color = collision)) +
    geom_point(size = .8) +
    theme_bw() +
    scale_color_manual(values = c("black", "red")) +
    theme(legend.position = "none") +
    xlab("Mouse UMIs") +
    ylab("Human UMIs")

  ggsave(paste0(sample_name, '.barnyard_plot.png'), plot = plot, units = "in", width = 3.5*1.3, height = 3.5)

  collision_rate <- round(sum(pData(cds)$collision/nrow(pData(cds))) * 200, 1)
  fileConn<-file(paste0(sample_name, '.barnyard_collision.txt'))
  writeLines(paste0(args$sample_name, "\t", collision_rate, "%"), fileConn)
  close(fileConn)
}

make_plot(cds_path, sample_name, plot_type)


