#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(argparse)
    library(monocle3)
})

parser = argparse::ArgumentParser(description='Script to run emptyDrops.')
parser$add_argument('sample_name', help='Sample name.')
parser$add_argument('mobs', help='Input monocle objects directory.')
parser$add_argument('scrublet_csv', help='Input scrublet CSV file.')
args = parser$parse_args()

sample_name  <- args$sample_name
mobs_dir     <- args$mobs
scrublet_csv <- args$scrublet_csv

cds <- load_monocle_objects(mobs_dir)
scrublet_table <- read.csv(scrublet_csv, header=FALSE)
pData(cds)$scrublet_score <- scrublet_table$V1
directory_out <- paste0(sample_name, '_cds.raw.mobs')
archive_control <- list(archive_type='none')
save_monocle_objects(cds, directory_path=directory_out, archive_control=archive_control)
