#!/usr/bin/env python3

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
  parser = argparse.ArgumentParser(description='A program to summarize merge_demux pcr indices by sample, lane, and process_group.')
  parser.add_argument('-i', '--input', required=True, default=None, help='Input JSON merge_demux filename (required string).')
  args = parser.parse_args()

# {'out_file': 'NSM1323-001_001_024.merged.bam', 'in_file_list': ['/net/bbi/vol2/home/bge/bbi/tests/nobackup/RNA3-062_061_059_057-nova/demux_out/NSM1323-001_001_024-L001.bam']}

  sample_name_full_dict = {}

  i = 0
  json_data = read_json(args.input)
  for json_item in json_data:
    i = i + 1
#    if(i > 500):
 #     break

#    print(json_item)

    out_file = json_item['out_file']
    in_file_list = json_item['in_file_list']

    out_file_parts = out_file.split('_')
    sample_parts_o = out_file_parts[0].split('-')
    sample_name_o = sample_parts_o[0]
    process_group_o = sample_parts_o[1]
    p7_o = out_file_parts[1]
    p5_o = out_file_parts[2].split('.')[0]

#    print('%s  %s  %s  %s' % (sample_name_o, process_group_o, p7_o, p5_o))    

    for in_file in in_file_list:
      in_basename = os.path.basename(in_file)
      in_basename_parts = in_basename.split('_')
      sample_parts_i = in_basename_parts[0].split('-')
      sample_name_i = sample_parts_i[0]
      sample_lane_i = sample_parts_i[1]

      p7_i = in_basename_parts[1]
      p5_i = in_basename_parts[2].split('-')[0]
      lane_i = in_basename_parts[2].split('-')[1].split('.')[0]

      mobj = pobj.match(lane_i)
      lane_n = int(mobj.group(1))

# Notes:
#   p7_i and p7_o should be the same
#   p5_i and p5_o should be the same
#   lane_n and int(sample_lane_i) should be the same
#   gather a write all pcr primer pairs for each sample_name+process_group
#   gather and write all lanes for each sample_name+process_group
#   report for each sample_name+process_group

      if(int(sample_lane_i) != lane_n):
        print('Inconsistent lane number: %s' % (in_file))      

      if(p7_o != p7_i):
        print('Inconsistent p7 primer index: %s' % (in_file))

      if(p5_o != p5_i):
        print('Inconsistent p5 primer index: %s' % (in_file))

      # sample_name_full_dict = {}
      sample_name_full = out_file_parts[0]
      if(not sample_name_full in sample_name_full_dict):
        p7_index_set = set()
        p5_index_set = set()
        lane_index_set = set()
        sample_name_full_dict[sample_name_full] = [p7_index_set, p5_index_set, lane_index_set]

      sample_name_full_dict[sample_name_full][0].update(int(p7_i))
      sample_name_full_dict[sample_name_full][1].update(int(p5_i))
      sample_name_full_dict[sample_name_full][2].update(lane_n)
 
  for sample_name_full in sample_name_full_dict.keys():
    sample_name_full_item = sample_name_full_dict[sample_name_full]
    p7_string = make_index_string(list(sample_name_full_item[0]))
    p5_string = make_index_string(list(sample_name_full_item[1]))
    lane_string = make_index_string(list(sample_name_full_item[2]))
    print('%s  %s  %s  %s  |  %s  %s' % (sample_name_full, p7_string, p5_string, lane_string, index_string_to_well_string(p7_string, True, False), index_string_to_well_string(p5_string, False, False)))



