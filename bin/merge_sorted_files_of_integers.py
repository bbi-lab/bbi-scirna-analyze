#!/usr/bin/env python3

#
# Program version string.
#
program_version = '0.1.0'

#
# Notes:
#  Rust: https://dev.to/creativcoder/merge-k-sorted-arrays-in-rust-1b2f
#

import argparse
from heapq import merge

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program to merge N text files of sorted integers in reverse order.')
  parser.add_argument('-i', '--input', required=True, default=None, nargs='+', help='Input text files of sorted integers (required string).')
  parser.add_argument('-o', '--output', required=True, default=None, help='Output filename (required string).')
  parser.add_argument('-v', '--version', action='version', version=program_version)
  args = parser.parse_args()

  # Write versions.
  if( args.version ):
    print( 'Program version: %s' % ( program_version ) )
    sys.exit( 0 )

  ofh = open(args.output, 'w')
  for val in merge(*map(open, args.input), key=int, reverse=True):
    print('%d' % (int(val.strip())), file=ofh)

