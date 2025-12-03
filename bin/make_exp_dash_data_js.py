#!/usr/bin/env python3

import sys
import re
import argparse
import json
import math


#
# Program version string.
#
program_version = '0.1.0'


def read_sample_name_file(filename):

  with open(filename, 'r') as fp:
    sample_name_list = []
    for line in fp:
      sample_name = line.strip()
      sample_name_list.append(sample_name)
  return(sample_name_list)


#
# Read samplesheet json file.
#
def read_json(filename):
  with open(filename, 'r') as fh:
    json_data = json.load(fh)
  return(json_data)


def read_cellread_statistics(sample_name_list):
  cellread_statistics_dict = dict()
  for sample_name in sample_name_list:
    filename = '%s_cellreads_statistics.json' % sample_name
    stats_json = read_json(filename)
    cellread_statistics_dict[sample_name] = stats_json
  return(cellread_statistics_dict)


def read_umi_cell_statistics(sample_name_list):
  umi_cell_statistics_dict = dict()
  for sample_name in sample_name_list:
    filename = '%s_umi_cell.json' % sample_name
    stats_json = read_json(filename)
    umi_cell_statistics_dict[sample_name] = stats_json
  return(umi_cell_statistics_dict)


#
# const run_data =
# {
#   "run_name": "RNA3-72-a.canonical_sci_rna.20251117",
#   "cell_counts": ["64882", "-"],
#   "sample_list": [
#     "Sentinel",
#     "24.024",
#     "Fishbowl",
#     "Keyhole",
#     "SeahubZ01"
#   ],
#   "barn_collision": null,
#   "sample_stats": {
#     "Keyhole": {
#       "Sample": "Keyhole",
#       "Total_reads": "    7146",
#       "Total_UMIs": "    4754",
#       "Duplication_rate": "33.5",
#       "Median_UMIs": null,
#       "Median_Mitochondrial_UMIs_Percent": null,
#       "Cells_100_UMIs": "0",
#       "Cells_FDR_p01": "-"
#     },
# 
def make_sample_stats_dict(sample_name_list, cellread_statistics_dict, umi_cell_statistics_dict):
  sample_stats_dict = dict()
  for sample_name in sample_name_list:
    total_reads              = cellread_statistics_dict[sample_name]['sum_counted_reads_unique'] + cellread_statistics_dict[sample_name]['sum_counted_reads_multi']
    total_umis               = cellread_statistics_dict[sample_name]['total_umi']
    duplication_rate         = (1.0 - (float(total_umis) / float(total_reads))) * 100.0
    median_umis              = umi_cell_statistics_dict[sample_name]['umis_median']
    median_mitochondial_umis = umi_cell_statistics_dict[sample_name]['umis_mito_median']
    cells_100_umis           = umi_cell_statistics_dict[sample_name]['cell_counts_umi']
    cells_fdr_p01            = umi_cell_statistics_dict[sample_name]['cell_counts_fdr']

    stats_dict = dict()
    stats_dict['Sample']                            = sample_name
    stats_dict['Total_reads']                       = '%8d' % total_reads
    stats_dict['Total_UMIs']                        = '%8d' % total_umis
    stats_dict['Duplication_rate']                  = '%.1f' % duplication_rate
    stats_dict['Median_UMIs']                       = '%8d' % median_umis
    stats_dict['Median_Mitochondrial_UMIs_Percent'] = '%.1f' % ((float(median_mitochondial_umis) / float(total_umis)) * 100.0)
    stats_dict['Cells_100_UMIs']                    = '%d' % cells_100_umis
    stats_dict['Cells_FDR_p01']                     = '%d' % cells_fdr_p01

    sample_stats_dict[sample_name] = stats_dict

  return(sample_stats_dict)


def make_run_data_dict(processing_directory, sample_name_list, sample_stats_dict):
  #
  # Calculate cell_counts.
  #
  cell_counts = [0] * 2
  for sample_name in sample_name_list:
    cells_100_umis  = int(sample_stats_dict[sample_name]['Cells_100_UMIs'])
    cells_fdr_p01   = int(sample_stats_dict[sample_name]['Cells_FDR_p01'])
    cell_counts[0] += cells_100_umis if(not math.isnan(cells_100_umis)) else 0
    cell_counts[1] += cells_fdr_p01  if((not math.isnan(cells_fdr_p01)) and (cells_fdr_p01 >= 0))  else 0

  cell_counts_str = [''] * 2
  cell_counts_str[0] = '%d' % (cell_counts[0])
  cell_counts_str[1] = '%d' % (cell_counts[1])

  #
  # Set up run_data_dict, which becomes the data.js file.
  #
  run_data_dict = dict()
  run_data_dict['run_name'] = processing_directory
  run_data_dict['cell_counts'] = cell_counts_str
  run_data_dict['sample_list'] = sample_name_list
  run_data_dict['barn_collision'] = None

  #
  # Edit stats_dict['Cells_FDR_p01'] there's no emptyDrops data:
  #   o  umi_cell_statistics_dict[sample_name]['cell_counts_fdr'] is
  #      set to -1 for missing emptyDrops data. Set stats_dict['Cells_FDR_p01']
  #      to '-' in these cases.
  #
  for sample_name in sample_name_list:
    if(int(sample_stats_dict[sample_name]['Cells_FDR_p01']) < 0):
      sample_stats_dict[sample_name]['Cells_FDR_p01'] = '-'

  run_data_dict['sample_stats'] = sample_stats_dict

  return(run_data_dict)


def write_data_js(run_data_dict):
  try:
    filename = 'data.js'
    fp = open('data.js', 'w+')
    fp.write('const run_data =\n')
    fp.write(json.dumps(run_data_dict, indent=2))
  except:
    print('Error: unable to write \"data.js\" file.', file=sys.stderr)
    sys.exit(-1)
  return(0)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program .')
  parser.add_argument('-s', '--sample_name_file', required=True, default=None, help='Input sample name file (required string(s)).')
  parser.add_argument('-p', '--processing_directory', required=True, default=None, help='Input processing directory name (required string(s)).')
  parser.add_argument('-v', '--version', action='version', version=program_version)
  args = parser.parse_args()

  sample_name_list = read_sample_name_file(args.sample_name_file)

  #
  # Read sample cellreads statistics.
  #
  cellread_statistics_dict = read_cellread_statistics(sample_name_list)
  # print(json.dumps(cellread_statistics, indent=2))

  # print()

  #
  # Read sample UMI and cell statistics.
  #
  umi_cell_statistics_dict = read_umi_cell_statistics(sample_name_list)
  # print(json.dumps(umi_cell_statistics, indent=2))


  #
  # Make sample data.
  #
  sample_stats_dict = make_sample_stats_dict(sample_name_list, cellread_statistics_dict, umi_cell_statistics_dict)

  #
  # Make run data.
  #
  run_data_dict = make_run_data_dict(args.processing_directory, sample_name_list, sample_stats_dict)

  #
  # Write data.js file.
  #
  write_data_js(run_data_dict)


