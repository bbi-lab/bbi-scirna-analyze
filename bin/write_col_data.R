#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(argparse)
    library(Matrix)
    library(monocle3)
})

parser = argparse::ArgumentParser(description='Script to make a colData(cds) TSV file')
parser$add_argument('monocle_objects', help='Input Monocle objects directory.')
parser$add_argument('col_data_filename', help='Output colData TSV filename.')
args = parser$parse_args()

cds <- load_monocle_objects(args$monocle_objects)
write.table(data.frame(colData(cds)), file=args$col_data_filename, quote=FALSE, sep='\t', col.names = TRUE, row.names=FALSE)
