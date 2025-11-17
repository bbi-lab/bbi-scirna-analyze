#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(argparse)
    library(Matrix)
    library(monocle3)
})

parser = argparse::ArgumentParser(description='Script to run emptyDrops.')
parser$add_argument('sample_name', help='Sample name.')
parser$add_argument('monocle_objects', help='File of umi count matrix.')
parser$add_argument('matrix_filename', 'Output matrix filename.')
args = parser$parse_args()

cds <- load_monocle_objects(args$mobs)
writeMM(as(as.matrix(exprs(cds)), 'dgCMatrix'), args$matrix_filename)

