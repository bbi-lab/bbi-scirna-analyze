#!/usr/bin/env python3

import sys
import argparse
import summary
import csv
import re

#
# Program version string.
#
program_version = '0.1.0'


def read_features_file(filename):
  with open(filename, 'r') as ifh:
    features_dict = dict()
    for line in ifh:
      parts = line.split()
      features_dict[parts[0].strip()] = int(parts[1].strip())
  print(features_dict)
  return(features_dict)


# from https://stackoverflow.com/questions/46647744/checking-to-see-if-a-string-is-an-integer-or-float: Rafe
re_int = re.compile(r"(^[1-9]+\d*$|^0$)")
re_float = re.compile(r"(^\d+\.\d+$|^\.\d+$)")

def read_summary_file(filename):
  with open(filename, 'r', newline='') as ifh:
    summary_dict = dict()
    csv_reader = csv.reader(ifh, dialect='excel')
    for row in csv_reader:
      if(re_int.match(row[1])):
        summary_dict[row[0]] = int(row[1])
      elif(re_float.match(row[1]):
        summary_dict[row[0]] = float(row[1])
      else:
        summary_dict[row[0]] = row[1]
  return(summary_dict)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program to gather STARsolo Features.stats files.')
  parser.add_argument('-i', '--input', required=True, default=None, nargs='+', help='STARsolo output paths (required string).')
  parser.add_argument('-o', '--output', required=True, default=None, help='Output JSON filename (required string).')
  parser.add_argument('-v', '--version', required=False, default=None, help='Write version string to stdout.')
  args = parser.parse_args()

  #
  # path: analyze_out/REF3-001/REF3-001_085_049.trimmed/Solo.out/GeneFull_Ex50pAS/(Features.stats|Summary.csv)
  #
  features_list = []
  for i in range(len(args.input)):
    starsolo_path = args.input[i]
    features_filename = starsolo_path + 'Solo.out/GeneFull_Ex50pAS/Features.stats'
    features = read_features_file(features_filename)
    summary_filename = starsolo_path + 'Solo.out/GeneFull_Ex50pAS/Summary.csv'
    summary = read_summary_file(summary_filename)

