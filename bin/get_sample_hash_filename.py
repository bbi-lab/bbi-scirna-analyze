#!/usr/bin/env python3

import sys
import argparse
import json
import csv


#
# Program version string.
#
program_version = '0.1.0'


#
# Read samplesheet json file.
#
def read_json(input_file, output_file):
  try:
    with open(input_file, 'r') as fh:
      json_data = json.load(fh)
  except FileNotFoundError as err:
    print('Error: %s' % (err), file=sys.stderr)
    sys.exit(1)
  except json.JSONDecodeError as err:
    print('Error: %s' % (err), file=sys.stderr)
    sys.exit(1)
  return(json_data)


if __name__ == '__main__':

  parser = argparse.ArgumentParser(description='A program to get a hash filename from the sample map file.')
  parser.add_argument('-s', '--sample_name', required=True, help='Sample name.')
  parser.add_argument('-i', '--input_file', required=True, help='Input sample maep filename.')
  parser.add_argument('-o', '--output_file', required=True, help='Output hash filename TSV filename.')
  parser.add_argument('-v', '--version', action='version', version=program_version)
  args = parser.parse_args()

  sample_name = args.sample_name
  input_file = args.input_file
  output_file = args.output_file

  json_data = read_json(input_file, output_file)

  hash_file = None
  for sample_dict in json_data:
    if(sample_dict['sample_name'] == sample_name):
      hash_file = sample_dict['hash_file']
      break

  if(not hash_file or hash_file == ''):
    print('Error: hash_file not set', file=sys.stderr)
    sys.exit(1)

  try: 
    with open(output_file, 'w', newline='', encoding='utf-8') as fh:
      fwriter = csv.writer(fh, delimiter = '\t')
      fheader = ['file_type', 'file_path']
      fwriter.writerow(fheader)
      frow = ['hash_map', hash_file]
      fwriter.writerow(frow)
  except:
    print('Error: unable to write output file \'%s\'' % (output_file), file=sys.stderr)
    sys.exit(1)
    

