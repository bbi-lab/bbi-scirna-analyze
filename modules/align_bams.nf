align_cpus = params.align_cpus < 8 ? params.align_cpus : 8

process align_bams {

  clusterOptions { '-l m_mem_free=' + mem.toInteger() / align_cpus + 'G -pe serial ' + align_cpus + ' -l cpuid_level=22' }

  input:
  tuple path(bam_in), val(genome_dir), val(mem), val(out_dir)
  
  output:
  path(out_dir)

/*
**  notes:
**    o  need genome information
**    o  need memory information
**    o  need input bam files
**    o  need output bam files
*/

  script:
  """
  STAR \
      --runThreadN ${align_cpus} \
      --genomeDir ${genome_dir} \
      --soloCBmatchWLtype Exact \
      --soloType CB_UMI_Simple \
      --soloBarcodeMate 0 \
      --soloCBstart 1 \
      --soloCBlen   28 \
      --soloUMIstart 29 \
      --soloUMIlen 8 \
      --soloCBwhitelist None \
      --outSAMtype BAM SortedByCoordinate \
      --outSAMattributes NH HI nM AS CR UR CB UB GX GN sS sQ sM \
      --outSJtype None \
      --outSAMmultNmax 1 \
      --outSAMstrandField intronMotif \
      --soloUMIdedup Exact \
      --soloCellReadStats Standard \
      --soloStrand Forward \
      --soloFeatures GeneFull_Ex50pAS \
      --soloMultiMappers PropUnique \
      --soloInputSAMattrBarcodeSeq sS \
      --soloInputSAMattrBarcodeQual sQ \
      --readFilesType SAM SE \
      --readFilesIn \
        ${bam_in} \
      --readFilesCommand samtools view \
      --outFileNamePrefix "${out_dir}/"
  """
}


/*
** The following runs but gives too many entries and alignments.
**
  STAR \
      --runThreadN 8 \
      --genomeDir ${genome_dir} \
      --soloCBmatchWLtype Exact \
      --soloType CB_UMI_Simple \
      --soloBarcodeMate 0 \
      --soloCBstart 1 \
      --soloCBlen   28 \
      --soloUMIstart 29 \
      --soloUMIlen 8 \
      --soloCBwhitelist None \
      --outSAMtype BAM SortedByCoordinate \
      --outSAMattributes NH HI nM AS CR UR CB UB GX GN sS sQ sM \
      --outSAMunmapped Within \
      --outSJtype None \
      --soloCellReadStats Standard \
      --soloStrand Forward \
      --soloFeatures GeneFull_Ex50pAS \
      --soloMultiMappers PropUnique \
      --soloInputSAMattrBarcodeSeq sS \
      --soloInputSAMattrBarcodeQual sQ \
      --readFilesType SAM SE \
      --readFilesIn \
        ${bam_in} \
      --readFilesCommand samtools view \
      --outFileNamePrefix "${out_dir}/"


** added bbduk and removed STAR option
      --clip3pAdapterSeq polyA \
*/
