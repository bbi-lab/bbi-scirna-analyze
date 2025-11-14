#!/bin/bash

if [ -z "${1}" ]
then
  echo -n "Enter name of samplesheet json file: "
  read samplesheet_json
else
  samplesheet_json="${1}"
fi

echo "Make sample_maps.json"
../bin/make_sample_map_json.py -s ${samplesheet_json} -g ../bin/genomes_data.json

echo "Make merge_demux.json file using a dummy BAM file path called '.'."
../bin/make_merge_demux_json.py -i ${samplesheet_json} -p .

echo "Make merge_align.json file."
../bin/make_merge_align_json.py -i ${samplesheet_json}

echo "Make star_align.json file."
../bin/make_star_align_json.py -i ${samplesheet_json}
