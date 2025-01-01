#!/usr/bin/env python3

#
# Concatenate sparse matrix files by column; that is,
# stack up cells given that the features are the same
# and in the same order in each of the files of
# triplets. Give the names of the files to concatenate
# on the command line. The names must end with
# 'matrix.mtx'.
#
# %%MatrixMarket matrix coordinate integer general
# %
# 60676 766 118308
# 8283 1 1
# 8912 1 1
#
# Notes:
#   o  reading the files appears to require the most
#      time.
#   o  for the files in a Nextseq run, processing files
#      appears to require only seconds once the input
#      files are in the cache. However, I may be wrong.
#

import sys
import hashlib
import re
import argparse


#
# Calculate the md5 checksum of a file.
#
def calculate_md5(file_path):
  hasher = hashlib.md5()
  with open(file_path, 'rb') as f:
    for chunk in iter(lambda: f.read(4096), b''):
        hasher.update(chunk)
  return hasher.hexdigest()


#
# Check that the files of row names (features)
# all have the same md5 checksum. We need the
# rows to be the same for all input matrices.
#
def check_rownames(matrix_name_list):
  md5_list = []
  num_file = 0
  for matrix_name in matrix_name_list:
    num_file += 1
    file_name = '%sfeatures.tsv' % (matrix_name)
    md5_file = calculate_md5(file_name)
    md5_list.append(md5_file)
  md5_1 = md5_list[0]
  result = md5_list and all(md5_list[0] == elem for elem in md5_list)
  if(result == False):
    print('Error: features.tsv files differ.')
    sys.exit(-1)
#  print('Checked %d features files.' % (num_file))


#
# Get the matrix dimensions of all matrix files.
# The dimensions follow immediately the header comments.
# We use the dimensions to form the dimensions line of
# the output file, and to shift the column coordinates
# of the triplets.
#
def gather_matrix_dimensions(matrix_name_list):
  matrix_dimension_list = []
  num_file = 0
  for matrix_name in matrix_name_list:
    num_file += 1
    file_name = '%smatrix.mtx' % (matrix_name)
    num_line = 0
    with open(file_name, 'r') as fh:
      for line in fh:
        num_line += 1
        if(num_line == 1):
          if(not re.match(r'%%MatrixMarket matrix coordinate integer', line)):
            print('Error: file %s has unexpected header line.' % (file_name), file=sys.stderr)
            print('  header line: %s' % (line))
            sys.exit(-1)
        elif(re.match(r'%', line)):
          continue
        else:
          toks = line.split()
#          print('%d %d %d' % (int(toks[0]), int(toks[1]), int(toks[2])))
          matrix_dimension_list.append([int(toks[0]), int(toks[1]), int(toks[2])])
          break
  return(matrix_dimension_list)          


#
# Concatenate the input matrices by adding columns to
# the output matrix file. The column values of the
# input matrix triplets are increased by the sum of
# the number of columns of all preceding input
# matrices. Each triplet is written to the output file
# immediately after shifting the column value.
#
# The cell name files are simply concatenated to form
# the output cell name file.
#
# The first feature name file is copied to the output
# feature name file.
#
def matrix_concatenation(matrix_name_list, matrix_dimension_list, out_rootname):

  out_matrix_name = '%s.matrix.mtx' % (out_rootname)
  try:
    ofh = open(out_matrix_name, 'w')
  except:
    print('Error: unable to open output file \'%s\'' % (out_matrix_name), sys.stderr)
    sys.exit(-1)

  sum_col = 0
  sum_elem = 0
  for matrix_dim in matrix_dimension_list:
    sum_col += matrix_dim[1]
    sum_elem += matrix_dim[2]

  print('%%MatrixMarket matrix coordinate integer general', file=ofh)
#  print('%', file=ofh)
  print('%d %d %d' % (matrix_dimension_list[0][0], sum_col, sum_elem), file=ofh)

  cum_barcode_count = 0
  for ifile, matrix_name in enumerate(matrix_name_list):
    in_matrix_name = '%smatrix.mtx' % (matrix_name)
#    print('==== %s' % (in_matrix_name), file=ofh)
    with open(in_matrix_name, 'r') as ifh:
      num_data = 0
      for line in ifh:
        if(re.match(r'%', line)):
          continue
        num_data += 1
        if(num_data == 1):
          continue
        toks = line.split()
        print('%s %d %s' % (toks[0], int(toks[1]) + cum_barcode_count, toks[2]), file=ofh)
    cum_barcode_count += matrix_dimension_list[ifile][1]

  out_barcodes_name = '%s.cells.tsv' % (out_rootname)
  try:
    ofh = open(out_barcodes_name, 'w')
  except:
    print('Error: unable to open output file \'%s\'' % (out_barcodes_name), sys.stderr)
    sys.exit(-1)

  for ifile, matrix_name in enumerate(matrix_name_list):
    in_barcodes_name = '%sbarcodes.tsv' % (matrix_name)
    with open(in_barcodes_name, 'r') as ifh:
      for line in ifh:
        print('%s' % (line.strip()), file=ofh)

  out_features_name = '%s.features.tsv' % (out_rootname)
  try:
    ofh = open(out_features_name, 'w')
  except:
    print('Error: unable to open output file \'%s\'' % (out_features_name), sys.stderr)
    sys.exit(-1)

  in_features_name = '%sfeatures.tsv' % (matrix_name)
  with open(in_features_name, 'r') as ifh:
    for line in ifh:
      print('%s' % (line.strip()), file=ofh)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program to concatenate sparse matrix files, in triplet format, by column.')
  parser.add_argument('-i', '--input', required=True, default=None, nargs='+', help='Input sparse matrix filenames (required strings).')
  parser.add_argument('-o', '--output_root', required=False, default=None, help='Output files root name (required string).')
  parser.add_argument('-v', '--version', required=False, default=None, help='Write version string to stdout.')
  args = parser.parse_args()

  matrix_name_list = []
  for i in range(len(args.input)):
    matrix_file_name = args.input[i]
    #
    # We expect that the input values have the form
    # .../Solo.out/GeneFull_Ex50pAS/(raw|filtered)/matrix.mtx
    #
    # We want the files
    #
    #  .../Solo.out/GeneFull_Ex50pAS/(raw|filtered)/matrix.mtx
    #  .../Solo.out/GeneFull_Ex50pAS/(raw|filtered)/features.tsv
    #  .../Solo.out/GeneFull_Ex50pAS/(raw|filtered)/barcodes.tsv
    #
    # so trim off the matrix.mtx and pass list of the resulting
    # paths to the following functions.
    #
    matrix_name = matrix_file_name.replace('matrix.mtx', '')
    matrix_name_list.append(matrix_name)
#    print('matrix_name: %s' % (matrix_name))

  check_rownames(matrix_name_list)
  matrix_dimension_list = gather_matrix_dimensions(matrix_name_list)

  #
  # The output files have the names
  #   <out_rootname>.(raw|filtered).matrix.mtx
  #   <out_rootname>.(raw|filtered).features.tsv
  #   <out_rootname>.(raw|filtered).cells.tsv
  #
  out_rootname = args.output_root
  matrix_concatenation(matrix_name_list, matrix_dimension_list, out_rootname)

