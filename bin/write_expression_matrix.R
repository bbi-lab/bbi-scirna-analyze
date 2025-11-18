#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(argparse)
    library(Matrix)
    library(monocle3)
})

parser = argparse::ArgumentParser(description='Script to make a MatrixMarket expression matrix.')
parser$add_argument('sample_name', help='Sample name.')
parser$add_argument('monocle_objects', help='File of umi count matrix.')
parser$add_argument('matrix_filename', help='Output matrix filename.')
args = parser$parse_args()

cds <- load_monocle_objects(args$monocle_objects)
writeMM(as(as.matrix(exprs(cds)), 'dgCMatrix'), args$matrix_filename)

