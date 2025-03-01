# bbi-scirna-analyze

## Intro

This *bbi-scirna-analyze* pipeline reads the unaligned BAM files from the *bbi-scirna-demux* pipeline, runs trimming, alignment, and makes a CDS file.

## Installation

Install the following software

- Nextflow
- STAR aligner
- bbduk.sh
- process_hashes

### Install Nextflow

See the Nextflow installation instructions at

https://www.nextflow.io/docs/latest/install.html

### Install Rust

See the Rust installation instructions at

https://www.rust-lang.org/tools/install

### Build and install *process_hashes*

Run the following commands

```
cd bbi-scirna-analyze/src/process_hashes
cargo build --release
cp target/release/process_hashes ../../bin
```

I recommend that you build *process_hashes* on a newer cluster node, for exampl
e, s020 on the Shendure cluster.


### Load the STAR aligner on the Genome Sciences cluster

The STAR aligner is loaded by Nextflow. The module load command is in the file *bbi-scirna-analyze/nextflow.config*.

I found that the most recent STAR aligned, STAR 2.7.11b, can fail with a segmentation fault when run on input files with only a few reads. You can fix this problem by cloning the STAR git repository and editing the source-code file called *STAR-2.7.11b/source/serviceFuns.cpp* to add the lines

```
    if (N==0)
        return -1;
```

at line 300 of *serviceFuns.cpp*, so that the start of the edited function looks like

```
template <class argType>
inline int64 binarySearchExact(argType x, argType *X, uint64 N) {
    //binary search in the sorted list
    //check the boundaries first
    //returns -1 if no match found
    //if X are not all distinct, no guarantee which element is returned
    
    if (N==0)
        return -1;
    
    if (x>X[N-1] || x<X[0])
        return -1;
```

Then build the STAR executable using the command

```
make
```

in the *STAR-2.7.11b/source* directory. Copy the resulting STAR executable file to the *bbi-scirna-analyze/bin* directory.

You may need to edit the *bbi-scirna-analyze/nextflow.config* file by setting the value *ext.star_path* to the STAR executable that you installed. In this case, I suggest that you also remove the STAR/2.7.11b module load in the *nextflow.config* file.

### Install bbduk.sh

See the BBMap installation instructions at

https://github.com/BioInfoTools/BBMap

You will need to edit the *bbi-scirna-analyze/nextflow.config* file by setting the value *ext.bbduk_path* to the *bbduk.sh* program that you installed.

## Run bbi-scirna-analyze

Use the *run.analyze.sh* bash script to start the pipeline run.

The output files are in the directory analyze_out. They are organized by sample and *process_group*.
