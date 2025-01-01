# bbi-scirna-analyze

## Intro

This *bbi-scirna-analyze* pipeline reads the *.bam* files from the *bbi-scirna-demux* pipeline, runs trimming, alignment, and several *.bam* file merges as required.

## Installation

Install the following software

- Nextflow
- STAR aligner
- bbduk.sh

### Install Nextflow

See the Nextflow installation instructions at

https://www.nextflow.io/docs/latest/install.html

### Load the STAR aligner on the Genome Sciences cluster

The STAR aligner is loaded by Nextflow. The module load command is in the file *bbi-scirna-analyze/nextflow.config*.

### Load bbduk.sh

See the BBMap installation instructions at

https://github.com/BioInfoTools/BBMap

## Run bbi-scirna-analyze

Use the *run.analyze.sh* bash script to start the pipeline run.

The output files are in the directory analyze_out. They are organized by sample and *process_group*.