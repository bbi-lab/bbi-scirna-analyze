#!/usr/bin/env python3

import sys
import json
import argparse
import re

#
# Program version string.
#
program_version = '0.1.1'

#
# Merge the lane-specific BAM files that belong to a combination
# of sample+process_group+pcr_pair. As a result, the output file
# contains the reads for sample_name, process_group, and pcr_pair.
#

#
# Read samplesheet json file.
#
def read_json(filename):
  with open(filename, 'r') as fh:
    json_data = json.load(fh)
  return(json_data)


#
# Expand index list.
# Example: 1-4,8-12
# Return a list of distinct indices.
regex_pattern = r'([0-9]+)([-]([0-9]+))?$'
def expand_index_list(index_string):
  index_list = []
  for index_spec in index_string.split(','):
    mobj = re.match(regex_pattern, index_spec)
    if(mobj == None):
      print('Error: expand_index_list: bad index specification: %s' % (index_spec))
      sys.exit(-1)
    index1 = int(mobj.group(1))
    index2 = index1
    if(mobj.group(2) != None):
      index2 = int(mobj.group(3))
    for one_index in range(index1, index2+1):
      index_list.append(one_index)
  return(list(set(index_list)))


#
# Get PCR data from samplesheet JSON file contents.
#
# json_data['sample_index_list']['lanes']
# json_data['sample_index_list']['ranges']
# json_data['sample_index_list']['p7_file']
# json_data['sample_index_list']['p5_file']
#
# A sample in a process group can be spread across
# multiple lanes and PCR pairs and so can be in more
# than one entry in the sample_index_list. Therefore
# the entries for the sample+process group must be
# collected into a single entry in the output JSON
# file. The lanes and pcr pairs are gathered together
# for the sample+process group, regardless of whether
# the lane and pcr pairs appear together in any of
# the sample_index_list entries. This seems reasonable
# because we want to be able to restrict processing to
# specific pcr pairs (within a sample+process group)
# while giving p7 and p5 indices as ranges or lists.
#
def get_data_file_dict(json_data):
  data_file_dict = {}
  for sample_index_dict in json_data['sample_index_list']:
    index_ranges = sample_index_dict['ranges'].split(':')
    process_group = sample_index_dict['process_group']
    sample_name = sample_index_dict['sample_id']
    p7_index_list = expand_index_list(index_ranges[1])
    p5_index_list = expand_index_list(index_ranges[2])
    lane_index_list = expand_index_list(sample_index_dict['lanes'])
    if(not process_group in data_file_dict):
      data_file_dict[process_group] = {}
    if(not sample_name in data_file_dict[process_group]):
       data_file_dict[process_group][sample_name] = {}
       data_file_dict[process_group][sample_name]['pcr_pair_dict'] = {}
       data_file_dict[process_group][sample_name]['lane_dict'] = {}
    for p7_index in p7_index_list:
      for p5_index in p5_index_list:
        pcr_pair = '%03d_%03d' % (int(p7_index), int(p5_index))
        data_file_dict[process_group][sample_name]['pcr_pair_dict'][pcr_pair] = 1
    for lane_index in lane_index_list:
      data_file_dict[process_group][sample_name]['lane_dict'][int(lane_index)] = 1
  return(data_file_dict)


#
# Merge the lane-specific BAM files that belong to a combination
# of sample+process_group+pcr_pair. As a result, the output file
# contains the reads for sample_name, process_group, and pcr_pair.
#
def make_data_file_json(data_file_dict, bam_path):
  bam_merge_list = []
  for process_group in data_file_dict.keys():
    for sample_name in data_file_dict[process_group].keys():
      for pcr_pair in data_file_dict[process_group][sample_name]['pcr_pair_dict'].keys():
        merge_dict = {}
        out_filename = '%s-%03d_%s.merged.bam' % (sample_name, int(process_group), pcr_pair)
        merge_dict['sample_name'] = '%s-%03d' % (sample_name, int(process_group))
        merge_dict['out_file'] = out_filename
        in_file_list = []
        merge_dict['in_file_list'] = in_file_list
        for lane_index in data_file_dict[process_group][sample_name]['lane_dict'].keys():
          in_file = '%s/%s-%03d_%s-L%03d.bam' % (bam_path, sample_name, lane_index, pcr_pair, lane_index)
          merge_dict['in_file_list'].append(in_file)
        bam_merge_list.append(merge_dict)

  try:
    filename_json = 'merge_demux.json'
    fh = open(filename_json, 'w')
    json.dump(bam_merge_list, fh, indent=2)
  except:
    print('Error: unable to write output file \"%s\"' % (filename_json), file=sys.stderr)
    sys.exit(-1)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program to make JSON file for merging demux bam files.')
  parser.add_argument('-i', '--input', required=True, default=None, help='Input JSON samplesheet filename (required string).')
  parser.add_argument('-p', '--bam_path', required=True, default=None, help='Input BAM file path (required string).')
#  parser.add_argument('-o', '--output', required=False, default=None, help='Output JSON output filename (required string).')
  parser.add_argument('-v', '--version', action='version', version=program_version)
  args = parser.parse_args()

  #
  # Read input samplesheet file.
  #
  json_data = read_json(args.input)
#  print(json.dumps(json_data['sample_index_list'], indent=2))
  data_file_dict = get_data_file_dict(json_data)

#  print(json.dumps(data_file_dict, indent=2))

  make_data_file_json(data_file_dict, args.bam_path)



