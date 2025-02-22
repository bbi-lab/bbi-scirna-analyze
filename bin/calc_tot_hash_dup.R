#!/usr/bin/env Rscript

library(data.table)
library(tidyverse)

parser = argparse::ArgumentParser(description='Script to calculate the total hash read duplication rate.')
parser$add_argument('sample_name', help='Sample name.')
parser$add_argument('hash_dup_per_cell', help='hash_dup_per_cell input file.')
parser$add_argument('hash_dup', help='hash_dup value.')

args = parser$parse_args()

dup = fread(args$hash_dup_per_cell, header = FALSE,
            data.table = F,
            col.names = c("Expt", "Cell", "V4", "V5", "V6"))

dup_rate = NULL

if (dim(dup)[1] != 0) {
    dup = dup %>%
        separate(Cell, into = c("p5", "p7", "rt_plate_well", "lig_well"), sep = "_") %>%
        mutate(pcr_plate = paste(str_sub(p7, start = 1, end = 1), str_sub(p5, start = 2, end = 3), sep = ""))

    if (args$hash_dup == 'pcr_plate') {
        dup = dup %>% group_by(pcr_plate)
    } else if(args$hash_dup == 'p5') {
        dup = dup %>% group_by(p5)
    } else {
        stop("hash_dup must be either 'pcr_plate' or 'p5'.")
    }

    dup_rate = dup %>% summarize(dup_rate = 1-(sum(V4)/sum(V5))) %>% data.frame()
}

out <- file(paste0(args$sample_name, "_total_hash_dup_rate.csv"))
write.csv(dup_rate, file = out, row.names = FALSE, quote = FALSE)

