#!/usr/bin/env python3

#
# Program: distill.align_demux_json.py
# Purpose: read a json file made by make_merge_align_json.py and
#          check for inconsistent and duplicated filenames, and
#          write a summary of the pcr pair information
#          inferred from the filenames to stdout. This summary is meant to
#          be compared to the output of the distill.samplesheet_json.py
#          (enable the correct print statement in distill.samplesheet_json.py).
#          The outputs of this program and distill.samplesheet_json.py
#          must be sorted, for example,
#
#            distill.merge_align_json.py -i merge_align.json | sort -k 1,1 > distill.merge_align_json.py.sorted.out
#


import sys
import json
import argparse
import re
import os.path


pobj = re.compile(r'L([0-9])+')


#
# Read json file.
#
def read_json(filename):
  with open(filename, 'r') as fh:
    json_data = json.load(fh)
  return(json_data)


def pad_well_col(well_col, zero_pad, id_length):
  if zero_pad:
      template = '%%0%sd' % id_length
  else:
      template = '%s'
  col_id = template % (well_col)
  return col_id


# OK
# Note: the first true well_index value is '0'. The
#       well_index value < 0 represents no well.
def index_to_well( well_index, across_row_first ):
  if( well_index < 0 ):
    return( (0, 'none'))
  nrow = 8
  ncol = 12
  ipl = int( well_index / 96 )
  i96 = well_index - ipl * 96
  if across_row_first:
      well_row = chr(65 + int(i96 / ncol))
      well_col = (i96 % ncol) + 1
  else:
      well_row = chr(65 + (i96 % nrow))
      well_col = int(i96 / nrow) + 1

#    well_id = 'P%d-%s%s' % (ipl + 1, well_row, pad_well_col(well_col, zero_pad_col, id_length))
  well_id = '%s%s' % ( well_row, pad_well_col( well_col, True, 2 ) )

  return( (ipl, well_id ) )


def make_index_string( index_list ):
  """
  Convert a list of (integer) barcode well indexes to an index string where
    o  repeated indexes are dropped; that is, keep only distinct indexes
    o  sequences of counting numbers are expressed as ranges, for example, 5 6 7 8 9 => 5-9
    o  indexes and index ranges are separated by commas
  """
  index_string = ''
  if( len( index_list ) == 0 ):
    return( index_string )
  index_list.sort()
  index_prev = None
  index1 = None
  for i in index_list:
    if( index_prev ):
      if( i == index_prev ):
        continue
      elif( i > index_prev + 1 ):
        if( len( index_string ) > 0 ):
          index_string += ','
        if( index_prev > index1 ):
          index_string += '%d-%d' % ( index1, index_prev )
        else:
          index_string += '%d' % ( index_prev )
        index1 = i
    else:
      index1 = i
    index_prev = i
  # last index in list
  if( len( index_string ) > 0 ):
    index_string += ','
  if( index_prev > index1 ):
    index_string += '%d-%d' % ( index1, index_prev )
  else:
    index_string += '%d' % ( index_prev )
  return( index_string )


def index_string_to_well_string( index_string, across_row_first, show_plate ):
  well_string = ''
  for item in index_string.split(','):
    mobj = re.match( r'^([0-9]+)([-]([0-9]+))?$', item.strip() )
    if( mobj == None):
      print('Error: index_string_to_well_string: unable to parse index string', file=sys.stderr)
      sys.exit(-1)
    ipl, well = index_to_well(int( mobj.group( 1 ) ) - 1, across_row_first)
    if( ipl == 0 and not show_plate ):
      if( len( well_string ) > 0 ):
        well_string += ','
      well_string += well
    else:
      if( len( well_string ) > 0 ):
        well_string += ','
      well_string += 'P%02d-%s' % ( ipl + 1, well )
    if( mobj.group( 3 ) != None ):
      ipl, well = index_to_well(int( mobj.group( 3 ) ) - 1, across_row_first)
      if( ipl == 0 and not show_plate ):
        well_string += ':%s' % ( well )
      else:
        well_string += ':P%02d-%s' % ( ipl + 1, well )

  return(well_string)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program to summarize merge_align pcr indices by sample and process_group.')
  parser.add_argument('-i', '--input', required=True, default=None, help='Input JSON merge_align filename (required string).')
  args = parser.parse_args()


# [
#   {
#     "sample_name": "NSM1323-001",
#     "out_file": "NSM1323-001.aligned.bam",
#     "in_dir_list": [
#       "NSM1323-001_001_024.trimmed",
#       "NSM1323-001_002_024.trimmed",
#       "NSM1323-001_003_024.trimmed",
#       "NSM1323-001_004_024.trimmed",
#       "NSM1323-001_005_024.trimmed",
#       "NSM1323-001_006_024.trimmed",
# ...
#       "NSM1323-001_095_024.trimmed",
#       "NSM1323-001_096_024.trimmed"
#     ]
#   },
# ...
# ]

  sample_name_full_dict = {}
  in_dir_count_dict = {}
  out_file_count_dict = {}

  json_data = read_json(args.input)
  for json_item in json_data:

    sample_name_j = json_item['sample_name']
    out_file = json_item['out_file']
    in_dir_list = json_item['in_dir_list']

    out_file_count_dict[out_file]  = out_file_count_dict.setdefault(out_file, 0)
    out_file_count_dict[out_file] += 1

    sample_name_o = out_file.replace('.aligned.bam', '')
    if(sample_name_o != sample_name_j):
      print('Error: distill.merge_align_json.py: inconsistent sample names \'%s\' != \'%s\'' % (sample_name_o, sample_name_j))

    for in_dir in in_dir_list:
      in_dir_count_dict[in_dir] = in_dir_count_dict.setdefault(in_dir, 0)
      in_dir_count_dict[in_dir] += 1

      in_dir_parts = in_dir.split('_')
      sample_name_i = in_dir_parts[0]
      p7_i = in_dir_parts[1]
      p5_i = in_dir_parts[2].split('.')[0]

      if(sample_name_i != sample_name_j):
        print('Error: distill.merge_align_json.py: inconsistent sample names \'%s\' != \'%s\'' % (sample_name_i, sample_name_j))

      if(not sample_name_j in sample_name_full_dict):
        p7_index_set = set()
        p5_index_set = set()
        sample_name_full_dict[sample_name_j] = [p7_index_set, p5_index_set]

      sample_name_full_dict[sample_name_j][0].add(int(p7_i))
      sample_name_full_dict[sample_name_j][1].add(int(p5_i))


  #
  # Check for input/output filenames that occur more than once.
  #
  for dir_name in in_dir_count_dict:
    if(in_dir_count_dict[dir_name] != 1):
      print('More than one occurrence (%d) of input dirname \'%s\'' % (in_dir_count_dict[dir_name], dir_name), file=sys.stderr)

  for file_name in out_file_count_dict:
    if(out_file_count_dict[file_name] != 1):
      print('More than one occurrence (%d) of output filename \'%s\'' % (out_file_count_dict[file_name], file_name), file=sys.stderr)

  #
  # Write distilled index/well information by sample_name+process_group
  #

  for sample_name in sample_name_full_dict.keys():
    sample_name_full_item = sample_name_full_dict[sample_name]
    p7_string = make_index_string(list(sample_name_full_item[0]))
    p5_string = make_index_string(list(sample_name_full_item[1]))

    print('%s  %s  %s  |  %s  %s' % (sample_name, p7_string, p5_string, index_string_to_well_string(p7_string, True, False), index_string_to_well_string(p5_string, False, False)))

