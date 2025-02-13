#!/bin/bash

samplesheet_json="samplesheet${1}.json"
out_dir='reference_jsons/'

$HOME/git/bbi-scirna-analyze/bin/make_merge_demux_json.py -i ${out_dir}${samplesheet_json} -p '.'
mv merge_demux.json ${out_dir}merge_demux${1}.json

$HOME/git/bbi-scirna-analyze/bin/make_process_hashes_json.py -i ${out_dir}${samplesheet_json}
mv process_hashes.json ${out_dir}process_hashes${1}.json

$HOME/git/bbi-scirna-analyze/bin/make_trim_bam_json.py -i ${out_dir}${samplesheet_json}
mv trim_bam.json ${out_dir}trim_bam${1}.json

$HOME/git/bbi-scirna-analyze/bin/make_star_align_json.py -i ${out_dir}${samplesheet_json} -g /home/brent/git/bbi-scirna-analyze/bin/star_genomes.txt
mv star_align.json ${out_dir}star_align${1}.json

$HOME/git/bbi-scirna-analyze/bin/make_merge_align_json.py -i ${out_dir}${samplesheet_json}
mv merge_align.json ${out_dir}merge_align${1}.json

