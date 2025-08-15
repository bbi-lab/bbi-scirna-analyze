#![allow(unused_parens)]

pub mod utils {
  use std::fs::File;
  use std::error::Error;
  use csv::{ReaderBuilder, Reader, Trim};

  pub fn read_tsv(file_path: &str) -> Result<Reader<File>, Box<dyn Error>> {

  let reader = std::fs::File::open(file_path).unwrap();
  let tsv_reader = ReaderBuilder::new()
                      .has_headers(false)
                      .trim(Trim::Fields)
                      .delimiter(b'\t')
                      .comment(Some(b'#'))
                      .from_reader(reader);

    Ok(tsv_reader)
  }

}

