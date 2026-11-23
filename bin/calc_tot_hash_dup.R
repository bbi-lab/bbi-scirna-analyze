#!/usr/bin/env Rscript

library(data.table)
library(tidyverse)

parser = argparse::ArgumentParser(description='Script to calculate the total hash read duplication rate.')
parser$add_argument('sample_name', help='Sample name.')
parser$add_argument('hash_dup_per_cell', help='hash_dup_per_cell input file.')
parser$add_argument('hash_dup', help='hash_dup value.')
parser$add_argument('--version', action = 'version', version = paste('calc_tot_hash_dup', '0.1.0'))

args = parser$parse_args()

dup = fread(args$hash_dup_per_cell, header = FALSE,
            data.table = F,
            col.names = c("Expt", "Cell", "V4", "V5", "V6"))

dup_rate = NULL

if(dim(dup)[1] != 0) {
    # Cell names are 'p5_p7_rt_lig'. P5 and P7 wells are 'P<plate>-<row><col>',
    # e.g., 'P01-B03', or 'none' when that index is not used.
    n_parts <- str_count(dup$Cell, "_") + 1
    if (any(n_parts != 4)) {
        stop("unexpected cell name format in ", args$hash_dup_per_cell)
    }

    dup = dup %>%
        separate(Cell, into = c("p5", "p7", "rt_plate_well", "lig_well"), sep = "_")

    well_re <- "^P[0-9]+-[A-H][0-9]+$"
    if (any(!(dup$p7 == "none" | str_detect(dup$p7, well_re))) ||
        any(!(dup$p5 == "none" | str_detect(dup$p5, well_re)))) {
        stop("unexpected P5/P7 well name format in ", args$hash_dup_per_cell)
    }

    # A PCR plate is identified by its P7 row and P5 column; 'none' passes through.
    dup = dup %>%
        mutate(p7_row = str_replace(p7, "^(P[0-9]+)-([A-H])[0-9]+$", "\\1-\\2"),
               p5_col = str_replace(p5, "^(P[0-9]+)-[A-H]([0-9]+)$", "\\1-\\2"),
               pcr_plate = paste(p7_row, p5_col, sep = "_"))

    if (args$hash_dup == 'pcr_plate') {
        dup = dup %>% group_by(pcr_plate)
    } else if(args$hash_dup == 'p5') {
        if (all(dup$p5 == "none")) {
            warning("hash_dup is 'p5' but no cell has a P5 index; all cells form one group.")
        }
        dup = dup %>% group_by(p5)
    } else {
        stop("hash_dup must be either 'pcr_plate' or 'p5'.")
    }

    dup_rate = dup %>% summarize(dup_rate = 1-(sum(V4)/sum(V5))) %>% data.frame()

#    dup = dup %>%
#        separate(Cell, into = c("p5", "p7", "rt_plate_well", "lig_well"), sep = "_") %>%
#        mutate(pcr_plate = paste(str_sub(p7, start = 1, end = 1), str_sub(p5, start = 2, end = 3), sep = ""))
# 
#     if (args$hash_dup == 'pcr_plate') {
#         dup = dup %>% group_by(pcr_plate)
#     } else if(args$hash_dup == 'p5') {
#         dup = dup %>% group_by(p5)
#     } else {
#         stop("hash_dup must be either 'pcr_plate' or 'p5'.")
#     }
# 
#     dup_rate = dup %>% summarize(dup_rate = 1-(sum(V4)/sum(V5))) %>% data.frame()

}

out <- file(paste0(args$sample_name, "_total_hash_dup_rate.csv"))
write.csv(dup_rate, file = out, row.names = FALSE, quote = FALSE)

