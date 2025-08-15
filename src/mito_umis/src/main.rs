#![allow(unused_parens)]

#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

extern crate clap;
use clap::{Arg, Command};
use csv::WriterBuilder;
use std::collections::{HashMap, HashSet};


/*
** Define command line arguments.
*/
fn set_cl_options() -> Result<clap::Command, Box<dyn std::error::Error>> {
  let cl_options = Command::new("mito_umis")
        .version(env!("CARGO_PKG_VERSION"))
        .about("Creates a file with UMI counts.")
        .arg(Arg::new("matrix_file")  // required=true, no default
                  .required(true)
                  .short('m')
                  .long("matrix_file")
                  .help("Matrix market file path."))
        .arg(Arg::new("feature_file")  // required=true, no default
                  .required(true)
                  .short('f')
                  .long("feature_file")
                  .help("Feature names file path."))
        .arg(Arg::new("barcode_file")  // required=true, no default
                  .required(true)
                  .short('b')
                  .long("barcode_file")
                  .help("Barcode names file path."))
        .arg(Arg::new("annotations_file")  // required=true, no default
                  .required(true)
                  .short('a')
                  .long("annotations_file")
                  .help("Annotations bed file path."))
        .arg(Arg::new("out_file")  // required=true, no default
                  .required(true)
                  .short('o')
                  .long("out_file")
                  .help("Output filename."));
    Ok(cl_options)
}


/*
** Mitochondrial genome names
*/
fn make_mito_set() -> Result<HashSet<String>, Box<dyn std::error::Error>> {

  let mito_names: Vec<String> = vec!["MT", "MtDNA", "Mt", "HUMAN_MT", "MOUSE_MT",
                                     "HUMAN_chrM", "MOUSE_chrM", "chrM",
                                     "mitochondrion_genome", "GRCh38_chrM",
                                     "mm10___chrM"]
                                     .iter().map(|s| s.to_string()).collect();
  let mito_set: HashSet<String> = HashSet::from_iter(mito_names);

  Ok(mito_set)
}


fn main() {
  /*
  ** Process command line options.
  */
  let cl_options = set_cl_options().unwrap();
  let cl_arg = cl_options.get_matches();

  let matrix_path: String     = cl_arg.get_one::<String>("matrix_file").unwrap().to_string();
  let feature_path: String    = cl_arg.get_one::<String>("feature_file").unwrap().to_string();
  let barcode_path: String    = cl_arg.get_one::<String>("barcode_file").unwrap().to_string();
  let annotation_path: String = cl_arg.get_one::<String>("annotations_file").unwrap().to_string();
  let out_path: String = cl_arg.get_one::<String>("out_file").unwrap().to_string();

  /*
  ** Read sparse matrix file and store in triplet format.
  */
  let mat: sprs::TriMatI<f64, usize> = sprs::io::read_matrix_market::<f64, usize, String>(matrix_path).expect("unable to read matrix file");

  let num_row = mat.rows();
  let num_col = mat.cols();

  /*
  ** Read feature names.
  */
  let mut reader_tsv = mito_umis::utils::read_tsv(&feature_path).expect(&format!("Unable to read file \'{}\'.\n", feature_path));
  let mut feature_names: Vec<String> = Vec::with_capacity(num_row);

  for result in reader_tsv.records() {
    let record = result.unwrap();
    feature_names.push(record.get(0).unwrap().to_string());
  }

  /*
  ** Read barcodes.
  */
  let mut reader_tsv = mito_umis::utils::read_tsv(&barcode_path).expect(&format!("Unable to read file \'{}\'.\n", barcode_path));
  let mut barcode_names: Vec<String> = Vec::with_capacity(num_col);

  for result in reader_tsv.records() {
    let record = result.unwrap();
    barcode_names.push(record.get(0).unwrap().to_string());
  }

  /*
  ** Read annotations .bed file into a HashMap keyed by gene name.
  ** TSV fields:
  **   1       17369   17436   ENSG00000278267 255     -       MIR6859-1
  **   1       29554   31109   ENSG00000243485 255     +       MIR1302-2HG
  **   1       30366   30503   ENSG00000284332 255     +       MIR1302-2
  */
  let mut reader_tsv = mito_umis::utils::read_tsv(&annotation_path).expect(&format!("Unable to read file \'{}\'.\n", annotation_path));
  let mut gene_chr_map: HashMap<String, String> = HashMap::with_capacity(num_row);
  for result in reader_tsv.records() {
    let record = result.unwrap();
    let chromosome_name = record.get(0).unwrap().to_string();
    let gene_name       = record.get(3).unwrap().to_string();
    gene_chr_map.insert(gene_name, chromosome_name);
  }

  /*
  ** HashSet of mitochondrial chromosome names.
  */
  let mito_set = make_mito_set().unwrap();

  /*
  ** Make umi counts.
  */
  let mut nonmito_umi_counter: Vec<f64> = vec![0.0; num_col];
  let mut mito_umi_counter:    Vec<f64> = vec![0.0; num_col];

  let irows = mat.row_inds();
  let icols = mat.col_inds();
  let fvals = mat.data();

  for ielem in 0..fvals.len() {
    let irow = irows[ielem];
    let icol = icols[ielem];
    let fval = fvals[ielem];
    let gene_name = &feature_names[irow];
    let gene_chr  = &gene_chr_map[gene_name];
    let mito_flag = mito_set.contains(gene_chr);
    if(!mito_flag) {
      nonmito_umi_counter[icol] += fval;
    }
    else {
     mito_umi_counter[icol] += fval;
    }
  }

  /*
  ** Write umi counts to tsv file.
  */
  let mut writer_tsv = WriterBuilder::new()
                                    .delimiter(b'\t')
                                    .from_path(&out_path).unwrap();
  for icol in 0..num_col {
/*
    let nonmito_count = format!("{}", f64::trunc(100.0*nonmito_umi_counter[icol]) / 100.0);
    let mito_count    = format!("{}", f64::trunc(100.0*mito_umi_counter[icol]) / 100.0);
*/
    let nonmito_count = format!("{}", (100.0*nonmito_umi_counter[icol]).round() / 100.0);
    let mito_count    = format!("{}", (100.0*mito_umi_counter[icol]).round() / 100.0);
    writer_tsv.write_record(&[barcode_names[icol].clone(), nonmito_count, mito_count]).unwrap();
  }
}

