#![allow(unused_parens)]

#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

extern crate clap;
use clap::{Arg, Command};

use std::io::Write;

/*
** Define command line arguments.
*/
fn set_cl_options() -> Result<clap::Command, Box<dyn std::error::Error>> {
  let cl_options = Command::new("umis_per_barcode")
        .version(env!("CARGO_PKG_VERSION"))
        .about("Calculate UMIs per barcode.")
        .arg(Arg::new("matrix_file")  // required=true, no default
                  .required(true)
                  .short('m')
                  .long("matrix_file")
                  .help("Matrix market file path."))
        .arg(Arg::new("out_file")  // required=true, no default
                  .required(true)
                  .short('o')
                  .long("out_file")
                  .help("Output filename."));
    Ok(cl_options)
}


fn main() {
  /*
  ** Process command line options.
  */
  let cl_options = set_cl_options().unwrap();
  let cl_arg = cl_options.get_matches();

  let matrix_path: String = cl_arg.get_one::<String>("matrix_file").unwrap().to_string();
  let out_path: String = cl_arg.get_one::<String>("out_file").unwrap().to_string();

  let mat: sprs::TriMatI<f64, usize> = sprs::io::read_matrix_market::<f64, usize, String>(matrix_path).expect("unable to read matrix file");

  let num_col = mat.cols();

  let mut barcode_umi_counter: Vec<f64> = vec![0.0; num_col];

  let icols = mat.col_inds();
  let fvals = mat.data();

  for ielem in 0..fvals.len() {
    let icol = icols[ielem];
    let fval = fvals[ielem];
    barcode_umi_counter[icol] += fval;
  }

  /*
  ** i64 counts for sorting and output.
  */
  let mut umi_counts: Vec<i64> = vec![0; num_col];
  for i in 0..barcode_umi_counter.len() {
    umi_counts[i] = libm::round(barcode_umi_counter[i]) as i64;
  }

  /*
  ** Reverse sort for use with knee plot.
  */
  umi_counts.sort();
  umi_counts.reverse();
 
  {
    let file = std::fs::File::create(out_path).expect("unable to open output file");
    let mut writer = std::io::BufWriter::new(file);

    for i in 0..umi_counts.len() {
      if(umi_counts[i] > 0) {
        writeln!(writer, "{}", umi_counts[i]).expect("unable to write to output file");
      }
    }

    writer.flush().expect("unable to flush output buffer");
  }
}

