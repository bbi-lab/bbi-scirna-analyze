#!/bin/bash

root_dir="/net/bbi/vol2/home/bge/bbi/tests/nobackup/RNA3-72-a.bbi_scirna.process_hashes.split.trim_galore/analyze_out/SeahubZ01-001"
sample_name="SeahubZ01-001"

# root_dir="/net/seahub_zfish/vol1/data/home/bge/trapnell.megasci.20250430b/analyze_out/REF3-001"
# sample_name="REF3-001"

# cargo run -- -m ${root_dir}/${sample_name}_counts.raw.matrix.mtx -r ${root_dir}/${sample_name}_counts.raw.features.tsv -c ${root_dir}/${sample_name}_counts.raw.cells.tsv -o foo.out

cargo build --release
# time ../target/release/umis_per_barcode -m ${root_dir}/${sample_name}_counts.raw.matrix.mtx -r ${root_dir}/${sample_name}_counts.raw.features.tsv -c ${root_dir}/${sample_name}_counts.raw.cells.tsv -o foo.out
time ../target/release/umis_per_barcode -m ${root_dir}/${sample_name}_counts.raw.matrix.mtx -o foo.out
