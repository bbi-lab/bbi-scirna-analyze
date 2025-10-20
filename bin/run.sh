#!/bin/bash

# samplesheet_json='/net/bbi/vol2/home/bge/bbi/tests/nobackup/RNA3-074-a.bbi_scirna.barnyard_plot.20250812/samplesheet.json'
samplesheet_json='/net/bbi/vol2/home/bge/bbi/tests/nobackup/RNA3-72-a.bbi_scirna.20251017.hash_656c82f8551/samplesheet.json'
genomes_data_json='/net/gs/vol1/home/bge/git/bbi-scirna-analyze/bin/genomes_data.json'

#   parser = argparse.ArgumentParser(description='A program to make JSON file for running mito_umis process.')
#   parser.add_argument('-i', '--input', required=True, default=None, help='Input JSON samplesheet filename (required string).')
#   parser.add_argument('-g', '--genomes_file', required=True, default=None, help='Path to file of STAR aligner genomes data. (required string).')
#   parser.add_argument('-v', '--version', action='version', version=program_version)
#   args = parser.parse_args()

# make_genome_files.py -i ${samplesheet_json} -g /net/gs/vol1/home/bge/git/bbi-scirna-analyze/bin/star_genomes.txt
# make_mito_umis_json.py -i ${samplesheet_json} -g /net/gs/vol1/home/bge/git/bbi-scirna-analyze/bin/star_genomes.txt
echo "make_sample_map_json.py -s ${samplesheet_json} -g ${genomes_data_json}"
make_sample_map_json.py -s ${samplesheet_json} -g ${genomes_data_json}
