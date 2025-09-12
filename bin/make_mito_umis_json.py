#!/usr/bin/env python3

import sys
import os
import json
import argparse
import re

#
# Program version string.
#
program_version = '0.1.0'

# struct SampleMap {
#   sample_id: String,
#   ranges: String,
#   lanes: String,
#   tissue: String,
#   genome: String,
#   hash_file: String,
#   sample_flags: String,
#   external_sample_name: String,
#   wrap_group: String,
#   rt_file: String,
#   ligation_file: String,
#   p7_file: String,
#   p5_file: String,
#   library: String,
#   process_group: String
# }


#
# Read samplesheet json file.
#
def read_json(filename):
  with open(filename, 'r') as fh:
    json_data = json.load(fh)
  return(json_data)


def read_star_genomes_file(file_path):
  star_genomes_dict = {}
  with open(file_path, 'r') as fp:
    for line in fp:
      line = line.strip()
      parts = line.split()
      genome_name = parts[0]
      genome_path = parts[1]
      genome_mem  = parts[2]
      if(not genome_name in star_genomes_dict):
        star_genomes_dict[genome_name] = {}
      star_genomes_dict[genome_name]['genome_path'] = genome_path
      star_genomes_dict[genome_name]['genome_mem']   = genome_mem
  return(star_genomes_dict)


def make_mito_umi_dict(json_data, star_genomes_dict):
  mito_umi_dict = dict()
  for sample_index_dict in json_data['sample_index_list']:
    sample_name = sample_index_dict['sample_id']
    process_group = sample_index_dict['process_group']
    key = '%s-%03d' % (sample_name, int(process_group))
    if(not key in mito_umi_dict):
      genome_name = sample_index_dict['genome']
      genome_path = star_genomes_dict[genome_name]['genome_path']
      genome_root = os.path.dirname(genome_path)
      genome_species = os.path.basename(genome_root)
      genes_bed = os.path.join(genome_root, '%s_rna' % genome_species, 'tmp.genes.bed')
      tmp_dict = dict()
      tmp_dict['sample_name'] = key
      tmp_dict['genome'] = genome_name
      tmp_dict['in_matrix'] = '%s_counts.raw.matrix.mtx' % key
      tmp_dict['in_features'] = '%s_counts.raw.features.tsv' % key
      tmp_dict['in_barcodes'] = '%s_counts.raw.cells.tsv' % key
      tmp_dict['in_genes_bed'] = genes_bed
      tmp_dict['out_file'] = '%s_mito_umis.tsv' % key
      mito_umi_dict[key] = tmp_dict
  return(mito_umi_dict)


#
# Make JSON file for running mito_umis process.
#
def make_mito_umi_file_json(mito_umi_dict):
  mito_umis_file_list = []
  for sample_name in mito_umi_dict:
    mito_umis_file_list.append(mito_umi_dict[sample_name])

  print(mito_umis_file_list)

  try:
    filename_json = 'mito_umi.json'
    fh = open(filename_json, 'w+')
    json.dump(mito_umis_file_list, fh, indent=2)
  except:
    print('Error: unable to write output file \"%s\"' % (filename_json), file=sys.stderr)
    sys.exit(-1)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program to make JSON file for running mito_umis process.')
  parser.add_argument('-i', '--input', required=True, default=None, help='Input JSON samplesheet filename (required string).')
  parser.add_argument('-g', '--genomes_file', required=True, default=None, help='Path to file of STAR aligner genomes data. (required string).')
#  parser.add_argument('-o', '--output', required=False, default=None, help='Output JSON filename (required string).')
  parser.add_argument('-v', '--version', action='version', version=program_version)
  args = parser.parse_args()

  #
  # Read input samplesheet file.
  #
  json_data = read_json(args.input)
  star_genomes_dict = read_star_genomes_file(args.genomes_file)
#  print(json.dumps(json_data['sample_index_list'], indent=2))
  mito_umi_dict = make_mito_umi_dict(json_data, star_genomes_dict)
#  print(mito_umi_dict)
  make_mito_umi_file_json(mito_umi_dict)

