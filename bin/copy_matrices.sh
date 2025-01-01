#!/bin/bash

  file_list=`ls file*`
  for file in ${file_list}
  do
    sample_name=`echo $file | awk 'BEGIN{FS="/"}{print $(NF-4)}'`
    base_dir = `echo $file | sed 's/\/Solo.out\/GeneFull_Ex50pAS\/raw\/matrix.mtx//'`
echo "$sample_name  $base_dir" > foo.out
#sample_name=${base_dir}
#echo    "cp ${base_dir}/Solo.out/GeneFull_Ex50pAS/raw/barcodes.tsv ${sample_name}.raw.barcodes.tsv" >> foo.out
#echo    "cp ${base_dir}/Solo.out/GeneFull_Ex50pAS/raw/features.tsv ${sample_name}.raw.features.tsv" >> foo.out
#echo    "cp ${base_dir}/Solo.out/GeneFull_Ex50pAS/raw/matrix.mtx ${sample_name}.raw.matrix.mtx" >> foo.out
#    cp ${base_dir}/Solo.out/GeneFull_Ex50pAS/filtered/barcodes.tsv ${sample_name}.filtered.barcodes.tsv
#    cp ${base_dir}/Solo.out/GeneFull_Ex50pAS/filtered/features.tsv ${sample_name}.filtered.features.tsv
#    cp ${base_dir}/Solo.out/GeneFull_Ex50pAS/filtered/matrix.mtx ${sample_name}.filtered.matrix.mtx
  done

