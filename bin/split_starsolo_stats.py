#!/usr/bin/env python3

#
# Read CellRead.stats file and split out columns required
# by downstream processes.
#


import sys
import argparse
import csv
import os.path
import re


def process_file(in_filename, sample_name):

  pobj = re.compile(r'^CBnotInPasslist')

  out_filename = 'umis_per_cell_barcode.txt'
  ofh_umi_unique = open(file=out_filename, mode='w')
  csv_writer = csv.writer(ofh_umi_unique, delimiter='\t')

  with open(file=in_filename, mode='r', newline='') as ifh:
    csv_reader = csv.reader(ifh, delimiter='\t')

    header_row = next(csv_reader)

    # Find desired columns.
    nUMIuniqueIndex = None
    exonicIndex = None
    intronicIndex = None
    mitoIndex = None
    for i, item in enumerate(header_row):
      if(item == 'nUMIunique'):
        nUMIuniqueIndex = i
      elif(item == 'exonic'):
        exonicIndex = i
      elif(item == 'intronic'):
        intronicIndex = i
      elif(item == 'mito'):
        mitoIndex = i

    for row in csv_reader:
      if(pobj.match(row[0]) != None):
        continue
      csv_writer.writerow([row[0], row[nUMIuniqueIndex]])

  ofh_umi_unique.close()


if __name__ == '__main__':

  parser = argparse.ArgumentParser(description='A program to split columns out of STARsolo CellReads.stats file.')
  parser.add_argument('-i', '--input_file', required=True, help='CellReads.stats file to processs.')
  parser.add_argument('-s', '--sample_name', required=True, help='Name of sample.')
  args = parser.parse_args()

  process_file(args.input_file, args.sample_name)

