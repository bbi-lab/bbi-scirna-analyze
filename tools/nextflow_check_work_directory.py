#!/usr/bin/env python3

import io
import sys
import os
import re
import argparse


def get_work_dir_list(work_dir, pattern):
  work_dir_list = []
  with open(args.input, 'r') as fh:
    for line in fh:
      line = line.strip()
      toks = line.split('\t')
      toks2 = toks[3].split(' ')
      if(re.fullmatch(pattern, toks2[0]) == None):
        continue
#      print('toks3: [%s]' % (toks2[0]))
      hash_tok = toks[1]
      toks = hash_tok.split('/')
      hash_dir = toks[0]
      hash_tok = toks[1]
      try:
        dir_path = '%s/%s' % (work_dir, hash_dir)
        with os.scandir(dir_path) as entries:
          for entry in entries:
            if(entry.is_dir() and re.match(hash_tok, entry.name) != None):
#              print('%s/%s' % (hash_dir, entry.name))
              work_dir_list.append('%s/%s' % (dir_path, entry.name))
      except:
        print('Unable to open directory \'%s\'' % (dir_path), file=sys.stderr)
        sys.exit(-1)
  return(work_dir_list)


# try:
#     with os.scandir(directory_path) as entries:
#         for entry in entries:
#             print(f"Name: {entry.name}, Is file: {entry.is_file()}, Is directory: {entry.is_dir()}")
# except FileNotFoundError:
#     print(f"Directory not found: {directory_path}")

def show_files(work_dir_list):
  for work_dir in work_dir_list:
    work_dir = '/net/bbi/vol1/data/bge/bbi/tests/bbi-scirna-tests/rna3-065-a.multi_pcr/%s' % (work_dir)

    symlink_list = []
    not_symlink_list = []

    entries = os.scandir(work_dir)
    flag = False
    for entry in entries:
      if(re.match(r'[.]', entry.name)):
        continue
      if(entry.is_symlink()):
        symlink_ref = os.readlink(entry.path)
        toks = symlink_ref.split('/')
        symlink_list.append(toks[-2])
      else:
        if(re.search(r'[.]bam', entry.name) == None):
          continue
        if(re.match(r'Barnyard', entry.name) == None):
          continue
        not_symlink_list.append(entry.name)
        flag = True
    entries.close()

    if(flag):
      print()
      print('%s:' % (work_dir))
      symlink_list.sort()
      for symlink in symlink_list:
        print('  %s' % (symlink))
      not_symlink_list.sort()
      for not_symlink in not_symlink_list:
        print('  %s' % (not_symlink))


#       for entry in entry_list:
#         print(entry)
#         flag = False
#         flag = True
#         print('entry: %s' % (entry.name))

#         symlink_list = []
#         not_symlink_list = []
#         for entry in entries:
#           if(re.match(r'[.]', entry.name)):
#             continue
#           if(entry.is_symlink()):
#             symlink_ref = os.readlink(entry.path)
#             toks = symlink_ref.split('/')
#             symlink_list.append(toks[-2])
#             print('symlink: %s' % (toks[-2]))
#           else:
# #             if(re.match(r'Barnyard', entry.name) == None):
# #               break
# #             flag = True
#             not_symlink_list.append(entry.name)
#             print('not symlink: %s' % (toks[-2]))
# 
# #         print('xx')
# #         if(flag):
# #           print()
# #           print('%s:' % (work_dir))
# #           for symlink in symlink_list:
# #             print('  %s' % (symlink))
# #           for not_symlink in not_symlink_list:
# #             print('  %s' % (not_symlink))

#     except:
#       print('Unable to open directory \'%s\'' % (work_dir), file=sys.stderr)
#       sys.exit(-1)    


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='A program to concatenate sparse matrix files, in triplet format, by column.')
  parser.add_argument('-i', '--input', required=True, default=None, help='Input Nextflow tracefile name.')
  parser.add_argument('-x', '--regex', required=True, default=None, help='Input search token.')
  args = parser.parse_args()

  pattern = args.regex
  work_dir = 'work_analyze'

  work_dir_list = get_work_dir_list(work_dir, pattern)
  show_files(work_dir_list)

