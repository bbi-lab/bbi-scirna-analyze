#!/usr/bin/env python3

# Program: distill.samplesheet_json.py
# Purpose: read a samplesheet.json file and write a summary
#          of rt, pcr pair, and lane information to stdout.
# Notes:
#   o  the output is used to check the samplesheet.json file
#      and to check the output of the programs
#        o  distill.merge_demux_json.py
#        o  distill.merge_align_json.py
#   o  in order to check the output of the two programs, you
#      must sort the output of distill.samplesheet_json.py,
#      for example,
#
#        distill.samplesheet_json.py -i samplesheet.json | sort -k 1,1 > distill.samplesheet_json.py.sorted.out
#


import sys
import argparse
import json
import re
import os.path


#
# Read samplesheet json file.
#
def read_json(filename):
  with open(filename, 'r') as fh:
    json_data = json.load(fh)
  return(json_data)


# def get_pcr_data(json_data):
#   pcr_data_list= []
#   for sample_index_dict in json_data['sample_index_list']:
#     index_ranges = sample_index_dict['ranges'].split(':')
#     p7_index_list = expand_index_list(index_ranges[1])
#     p5_index_list = expand_index_list(index_ranges[2])
#     lane_index_list = expand_index_list(sample_index_dict['lanes'])
#     p7_file = sample_index_dict['p7_file']
#     p5_file = sample_index_dict['p5_file']
#     pcr_data_list.append( {'lane_index_list' : lane_index_list, 'p7_index_list' : p7_index_list, 'p5_index_list' : p5_index_list, 'p7_file' : p7_file, 'p5_file' : p5_file})
#   return(pcr_data_list)


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
  parser = argparse.ArgumentParser(description='A program to summarize samplesheet.json pcr indices by sample, lane, and process_group.')
  parser.add_argument('-i', '--input', required=True, default=None, help='Input JSON samplesheet filename (required string).')
  parser.add_argument('-f', '--format', required=True, default=None, help='Output \'format\'. (required string: \'full\', \'demux\', or \'align\').')
  args = parser.parse_args()

  json_data = read_json(args.input)

  sample_name_full_dict = {}

  sample_index_list = json_data['sample_index_list']
  
  for sample_index_item in sample_index_list:

    index_ranges = sample_index_item['ranges'].split(':')
    sample_name = sample_index_item['sample_id']
    process_group = sample_index_item['process_group']
    rt_index_string = index_ranges[0]
    p7_index_string = index_ranges[1]
    p5_index_string = index_ranges[2]
    lane_index_string = sample_index_item['lanes']

    rt_index_list   = expand_index_list(rt_index_string)
    p7_index_list   = expand_index_list(p7_index_string)
    p5_index_list   = expand_index_list(p5_index_string)
    lane_index_list = expand_index_list(lane_index_string)

    sample_name_full = '%s-%03d' % (sample_name, int(process_group))
    if(not sample_name_full in sample_name_full_dict):
      rt_index_set = set()
      p7_index_set = set()
      p5_index_set = set()
      lane_index_set = set()
      sample_name_full_dict[sample_name_full] = [rt_index_set, p7_index_set, p5_index_set, lane_index_set]

    sample_name_full_dict[sample_name_full][0].update(rt_index_list)
    sample_name_full_dict[sample_name_full][1].update(p7_index_list)
    sample_name_full_dict[sample_name_full][2].update(p5_index_list)
    sample_name_full_dict[sample_name_full][3].update(lane_index_list)

  for sample_name_full in sample_name_full_dict.keys():
    sample_name_full_item = sample_name_full_dict[sample_name_full]
    rt_string = make_index_string(list(sample_name_full_item[0]))
    p7_string = make_index_string(list(sample_name_full_item[1]))
    p5_string = make_index_string(list(sample_name_full_item[2]))
    lane_string = make_index_string(list(sample_name_full_item[3]))

    if(args.format == 'full'):
      # Includes rt well information.
      print('%s  %s  %s  %s  %s  |  %s  %s  %s' % (sample_name_full, rt_string, p7_string, p5_string, lane_string, index_string_to_well_string(rt_string, True, True), index_string_to_well_string(p7_string, True, False), index_string_to_well_string(p5_string, False, False)))

    elif(args.format == 'demux'):
      # Includes p7, p5, and lane information for comparing to the output of the distill.merge_demux_json.py script. The output must be sorted by the first field.
      print('%s  %s  %s  %s  |  %s  %s' % (sample_name_full, p7_string, p5_string, lane_string, index_string_to_well_string(p7_string, True, False), index_string_to_well_string(p5_string, False, False)))

    elif(args.format == 'align'):
      # Includes p7 and p5 information for comparing to the output of the distill.merge_align_json.py. The output must be sorted by the first field.
      print('%s  %s  %s  |  %s  %s' % (sample_name_full, p7_string, p5_string, index_string_to_well_string(p7_string, True, False), index_string_to_well_string(p5_string, False, False)))

    else:
      print('Error: unrecognized format command line parameter.', file=sys.stderr)
      sys.exit(-1)
