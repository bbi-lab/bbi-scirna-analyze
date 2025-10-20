#!/bin/bash

#
# This script is lifted from bbi-genome-data/scripts/rna.03.make_bed_files.sh
#
# It makes a bed file from a filtered gtf file. The bed file is used by the
# make_cds.R script in the bbi-lab/bbi-scirna-analyze pipeline.
#

GTF_IN="${1}"
BED_OUT="${2}"

# Ensembl GTFs have a 'gene_biotype' tag. The Gencode GTFs
# appear to have a 'gene_type' tag.
#
GENE_BIOTYPE="gene_biotype"

cat "${GTF_IN}" | grep -v "^#" \
  | awk 'BEGIN {FS = "\t";} {if($3 == "gene") {
      gene_id = "";
      '${GENE_BIOTYPE}' = "";
      n = split($9, arr, ";"); 
      for (i = 1; i <= n; i++) {
          split(arr[i], arr2, " "); 
          if (arr2[1] == "gene_id") {
              gene_id = arr2[2];
          } else if (arr2[1] == "'${GENE_BIOTYPE}'") {
              '${GENE_BIOTYPE}' = arr2[2];
          }
      }

      gsub(/"/, "", gene_id);
      gsub(/"/, "", '${GENE_BIOTYPE}');

      printf "%s\t%s\t%s\t%s\t%d\t%s\n",
          $1, $4, $5, gene_id, 255, $7;
  }}' | sort -k1,1 -k2,2n -S 4G \
> "${BED_OUT}"


