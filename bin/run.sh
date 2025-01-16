#!/bin/bash

samplesheet_json='/net/bbi/vol1/data/bge/bbi/tests/bclconvert/RNA3-065-a/samplesheet.json'

make_merge_demux_json.py -i $samplesheet_json -p hoo
# make_trim_bam_json.py -i $samplesheet_json -o foo.json

