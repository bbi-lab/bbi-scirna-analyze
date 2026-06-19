#!/usr/bin/env python3

import sys
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


def make_barnyard_dict(json_data):
  pobj = re.compile(r'([Bb])')
  barnyard_dict = dict()
  for sample_index_dict in json_data['sample_index_list']:
    sample_flags = sample_index_dict['sample_flags']
    mobj = pobj.search(sample_flags)
    if(mobj == None):
      continue
    # Gather relevant values.
    barnyard_flag = mobj.group(1)
    sample_name = sample_index_dict['sample_id']
    process_group = sample_index_dict['process_group']
    key = '%s-%03d' % (sample_name, int(process_group))
    if(not key in barnyard_dict):
      genome = sample_index_dict['genome']
      tmp_dict = dict()
      tmp_dict['sample_name'] = key
      tmp_dict['genome'] = genome
      tmp_dict['barnyard_flag'] = barnyard_flag
      tmp_dict['in_mobs'] = '%s_cds.raw.mobs' % key
      tmp_dict['out_file'] = '%s_barnyard_plot.png' % key
      barnyard_dict[key] = tmp_dict
  return(barnyard_dict)


#
# Make JSON file for barnyard plot process.
#
def make_barnyard_file_json(barnyard_dict):
  barnyard_plot_list = []
  for sample_name in barnyard_dict:
    barnyard_plot_list.append(barnyard_dict[sample_name])

  print(barnyard_plot_list)

  try:
    filename_json = 'make_barnyard.json'
    fh = open(filename_json, 'w+')
    json.dump(barnyard_plot_list, fh, indent=2)
  except:
    print('Error: unable to write output file \"%s\"' % (filename_json), file=sys.stderr)
    sys.exit(1)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program to make JSON file for barnyard plots.')
  parser.add_argument('-i', '--input', required=True, default=None, help='Input JSON samplesheet filename (required string).')
#  parser.add_argument('-o', '--output', required=False, default=None, help='Output JSON filename (required string).')
  parser.add_argument('-v', '--version', action='version', version=program_version)
  args = parser.parse_args()

  #
  # Read input samplesheet file.
  #
  json_data = read_json(args.input)
#  print(json.dumps(json_data['sample_index_list'], indent=2))
  barnyard_dict = make_barnyard_dict(json_data)
#  print(barnyard_dict)
  make_barnyard_file_json(barnyard_dict)

