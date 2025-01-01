#!/bin/bash

samplesheet_json='/net/bbi/vol1/data/bge/bbi/tests/bclconvert/RNA3-065-a/samplesheet.json'

make_star_align_json.py -i $samplesheet_json -g /net/gs/vol1/home/bge/git/bbi-scirna-analyze/bin/star_genomes.txt -o foo.json
