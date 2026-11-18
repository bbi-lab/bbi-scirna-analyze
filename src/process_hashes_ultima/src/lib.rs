/*
** Turn off warnings about unused parentheses.
*/
#![allow(unused_parens)]


//! Reproduce Andrew Hill's barcode_utils.py in Rust, a bit at a time.
pub mod barcode_utils {

  use std::io;
  use std::collections::HashMap;
  use regex::Regex;
  use itertools::Itertools;
  use csv::{ReaderBuilder, Trim};
  use serde::Deserialize;
  use polars::prelude::*;
  use anyhow::{Context, Result, bail, anyhow};


  /// Checks if a Series contains any duplicate values.
  ///
  /// Returns `true` if all elements are unique (no duplicates),
  /// and `false` if at least one duplicate is found.
  pub fn check_for_duplicates(s: &Series) -> Result<bool> {
      // Ensure the series is of a type that supports equality comparison,
      // typically Utf8/String for this specific use case.
      // We cast to ChunkedArray to access the .is_unique() method if available,
      // or we use the .is_unique() on Series directly via Polars' internal logic.

      // In modern Polars (0.37+), is_unique() returns a Boolean chunked array
      // indicating which elements are unique. To check for global uniqueness,
      // we compare the length of the unique values count with the original series length.

      let len = s.len();

      // .unique() returns a Series containing only the unique elements of the input.
      // This operation is highly optimized in Polars (using hash sets internally).
      let unique_series = s.unique()?;
      let unique_len = unique_series.len();

      if(len == unique_len) {
          Ok(false) // No duplicates found: original length equals unique length
      } else {
          Ok(true) // Duplicates exist: unique length is shorter than original length
      }
  }


  /// Represents the structure of a single row in the TSV.
  /// column_3 is Option<String> to handle files with only two columns.
  #[derive(Debug, Deserialize)]
  struct TsvRow {
      hash_name: String,
      oligo_sequence: String,
      column_3: Option<String>,
  }


  /// Reads a TSV file, parses it into a DataFrame, and adds an edited hash name column.
  ///
  /// # Arguments
  /// * `filename` - A String representing the path to the TSV file.
  ///
  /// # Returns
  /// * `PolarsResult<DataFrame>` - The resulting DataFrame containing processed data.
  pub fn read_hashseq_file(filename: &str) -> Result<DataFrame> {
      let path = std::path::Path::new(filename);
      let file = std::fs::File::open(path).with_context(|| format!("Failed to open file: {}", filename))?;

      // Configure the CSV reader for TSV (tab delimiter) and no headers.
      let mut rdr = ReaderBuilder::new()
          .delimiter(b'\t')
          .has_headers(false)
          .from_reader(file);

      // Pre-compile the regex for character replacement.
      // The hyphen is placed at the end of the character class to avoid being interpreted as a range.
      let re = Regex::new(r"[ )(=_/-]")?;

      // Buffers to hold column data for Polars Series construction.
      let mut hash_names: Vec<String> = Vec::new();
      let mut oligo_sequences: Vec<String> = Vec::new();
      let mut col3_values: Vec<Option<String>> = Vec::new();
      let mut hash_name_edited: Vec<String> = Vec::new();

      // Iterate through the records and deserialize using Serde.
      for result in rdr.deserialize::<TsvRow>() {
          let record = result.with_context(|| "Failed to deserialize TSV row")?;
  
          // 1. Store original hash name
          hash_names.push(record.hash_name.clone());
  
          // 2. Store oligo sequence (converted to upper case)
          oligo_sequences.push(record.oligo_sequence.to_ascii_uppercase());
  
          // 3. Store column 3 (handles missing values automatically via Option)
          col3_values.push(record.column_3);
  
          // 4. Perform Regex replacement for the new column
          let edited = re.replace_all(&record.hash_name, ".").into_owned();
          hash_name_edited.push(edited);
      }

      // Construct Polars Series from the collected vectors.
      // Note: Series::new handles Vec<String> and Vec<Option<String>> (mapping None to nulls).
      let s1 = Series::new("hash_name", hash_names);
      let s2 = Series::new("oligo_sequence", oligo_sequences);
      let s3 = Series::new("column_3", col3_values);
      let s4 = Series::new("hash_name_edited", hash_name_edited);

      // Check for duplicate hash_name, hash_name_edited, and
      // oligo_sequence values.
      if(check_for_duplicates(&s1)?) {
        bail!("duplicate hash_name values in file '{}'", filename);
      }

      if(check_for_duplicates(&s2)?) {
        bail!("duplicate oligo_sequence values in file '{}'", filename);
      }

      if(check_for_duplicates(&s4)?) {
        bail!("duplicate hash_name_edited values in file '{}'", filename);
      }

      // Assemble the DataFrame.
      let df = DataFrame::new(vec![s1, s2, s3, s4])
          .with_context(|| "Failed to construct DataFrame from series")?;

      Ok(df)
  }


  /// Writes a subset of columns from a Polars DataFrame to a TSV file.
  ///
  /// # Arguments
  /// * `df` - The source DataFrame containing the required columns.
  /// * `output_path` - A string slice representing the destination file path.
  ///
  /// # Errors
  /// Returns an error if column selection fails, if the file cannot be created,
  /// or if the writing process encounters an I/O error.
  pub fn write_hashseq_map_file(df: &DataFrame, output_path: &str) -> Result<()> {
      // 1. Define the required columns for the subset.
      let target_columns = ["hash_name", "hash_name_edited", "oligo_sequence"];

      // 2. Select only the requested columns.
      // Using select() creates a new DataFrame containing only these columns.
      let mut subset_df = df
          .select(target_columns)
          .context("Failed to select specified columns from DataFrame. Ensure column names match exactly.")?;

      // 3. Create the file for writing.
      let file = std::fs::File::create(output_path)
          .with_context(|| format!("Failed to create output file at: {}", output_path))?;

      // 4. Use Polars' CsvWriter configured with a tab delimiter (\t).
      // This is highly optimized and leverages Polars' internal memory layout.
      CsvWriter::new(file)
          .with_separator(b'\t')
          .include_header(true)
          .finish(&mut subset_df)
          .context("Failed to write TSV data to file.")?;

      Ok(())
  }


  /// Converts a DataFrame into a HashMap using "hash_name" as keys
  /// and "hash_name_edited" as values.
  pub fn make_hashnames_hashmap(df: &DataFrame) -> Result<HashMap<String, String>> {
      // 1. Extract columns and cast them to StringChunked
      // We use .str() to treat the Series as string data
      let keys_col = df
          .column("hash_name")
          .context("Column 'hash_name' not found")?
          .str()
          .context("Column 'hash_name' is not of type String")?;

      let values_col = df
          .column("hash_name_edited")
          .context("Column 'hash_name_edited' not found")?
          .str()
          .context("Column 'hash_name_edited' is not of type String")?;

      // 2. Zip the iterators together.
      // .iter() on StringChunked returns Option<&str>
      let map: HashMap<String, String> = keys_col
          .into_iter()
          .zip(values_col.into_iter())
          .filter_map(|(k, v)| {
              // Only include the pair if both key and value are Some (not null)
              match (k, v) {
                  (Some(k_val), Some(v_val)) => Some((k_val.to_string(), v_val.to_string())),
                  _ => None,
              }
          })
          .collect();

      Ok(map)
  }


  /// Converts a DataFrame into a HashMap using "hash_seq" as keys
  /// and "hash_name" as values.
  pub fn make_hashseq_hashmap(df: &DataFrame) -> Result<HashMap<String, String>> {
      // 1. Extract columns and cast them to StringChunked
      // We use .str() to treat the Series as string data
      let keys_col = df
          .column("oligo_sequence")
          .context("Column 'oligo_sequence' not found")?
          .str()
          .context("Column 'oligo_sequence' is not of type String")?;

      let values_col = df
          .column("hash_name")
          .context("Column 'hash_name' not found")?
          .str()
          .context("Column 'hash_name' is not of type String")?;

      // 2. Zip the iterators together.
      // .iter() on StringChunked returns Option<&str>
      let map: HashMap<String, String> = keys_col
          .into_iter()
          .zip(values_col.into_iter())
          .filter_map(|(k, v)| {
              // Only include the pair if both key and value are Some (not null)
              match (k, v) {
                  (Some(k_val), Some(v_val)) => Some((k_val.to_string(), v_val.to_string())),
                  _ => None,
              }
          })
          .collect();

      Ok(map)
  }


  /// Read a barcode TSV file that has the format
  ///
  /// barcode name\tbarcode sequence
  ///
  /// Arguments:
  ///- file_path: a reference to the input file path
  ///
  /// Return:
  ///
  /// A hash map: the key is the barcode sequence and the value is
  /// the barcode name.
  ///
  /// Based on URL: https://stackoverflow.com/questions/78639668/fast-reading-from-a-tsv-file-in-rust
  #[derive(Deserialize)]
  struct Record {
    hash_name: String,
    hash_barcode: String,
  }

  pub fn read_barcode_file(file_path: &str) -> Result<HashMap<String, String>> {
  let fp = std::fs::File::open(file_path)?;
  let buf_reader = io::BufReader::new(fp);
  let mut tsv_reader = ReaderBuilder::new()
                         .has_headers(false)
                         .trim(Trim::Fields)
                         .delimiter(b'\t')
                         .comment(Some(b'#'))
                         .from_reader(buf_reader);

  let mut hash_map: HashMap<String, String> = HashMap::new();

  /*
  ** Read the file and store the names and sequences.
  */
  for result in tsv_reader.deserialize() {
    let record: Record = result?;
//    if(hash_map.contains_key(&record.hash_barcode)) {
    let hash_barcode = record.hash_barcode.to_ascii_uppercase();
    if(hash_map.contains_key(&hash_barcode)) {
      bail!("Error: read_barcode_file: duplicate barcode string in file {:#?}", file_path);
    }
//    hash_map.entry(record.hash_barcode.to_owned()).or_insert(record.hash_name.to_string());
    hash_map.entry(hash_barcode).or_insert(record.hash_name.to_string());
  }

  Ok(hash_map)
}


  /// Generate a vector of mismatched sequences to a given sequence. Must contain only ACGT.
  /// This is based heavily on a Biostars answer.
  /// Curiously, it returns the input sequence when num_mismatches is zero; otherwise, it does not.
  ///
  /// Arguments:
  ///- sequence: a reference to the input string.
  ///- num_mismatches: the number of mismatches in each output sequence.
  ///- allow_n: include Ns in the output sequences.
  ///
  /// Return:
  ///
  /// A Result enum containing a vector of mismatched sequence Strings.
  ///
  pub fn generate_mismatches(sequence: &str, num_mismatches: usize, allow_n: bool) -> Result<Vec<String>> {

    let sequence_upper: String = sequence.to_uppercase();

    if(num_mismatches == 0) {
      return(Ok(vec!(sequence_upper)));
    }

    let mut letters = String::from("ACGT");
    if(allow_n == true) {
      letters.push('N');
    }

    /*
    ** Return a Result of vector of strings.
    */
    let mut mismatches: Vec<String> = Vec::new();

    let seq_len = sequence_upper.len();

    /*
    ** Make iterators of vectors of indices where mismatches
    ** may show up in the input sequence, and iterator through
    ** these vectors.
    */
    let combination_iter = (0..seq_len).combinations(num_mismatches);
    for locs in combination_iter {
      /*
      ** sequence_vector begins with a vector of vectors where each base
      ** in the sequence is an inner vector. That is, for sequence ATGCTA,
      ** each loop iteration gives the save vector of vectors, at this point.
      **   sequence_vector: [['A'], ['T'], ['G'], ['C'], ['T'], ['A']]
      **   ...
      */
      let mut sequence_vector: Vec<Vec<char>> = sequence_upper.chars().map(|c| vec!(c)).collect();

      /*
      ** Here inner vectors are replaced with the three bases that are not
      ** in the original sequence. For example,
      **   [['A'], ['T'], ['G'], ['C'], ['T'], ['A']]
      ** becomes
      **   [['A'], ['A','C','G'], ['G'], ['C'], ['T'], ['A']]
      ** at mismatch index 1, which is the second inner
      ** vector.
      */
      for loc in locs {
        let orig_char = sequence_upper.chars().nth(loc as usize).ok_or_else(|| anyhow!("Index {} is out of bounds for sequence length {}", loc, sequence_upper.len()))?;
        sequence_vector[loc] = letters.chars().filter(|c| *c != orig_char).collect();
      }

      /*
      ** And the cartesian product of the set of inner vectors expands
      ** to the desired mismatch sequences when the product vectors are
      ** converted to strings.
      */
      for vector_set in sequence_vector.iter().multi_cartesian_product() {
        let primer_string: String = vector_set.into_iter().collect();
        mismatches.push(primer_string);
      }
    }

    Ok(mismatches)
  }


  /// Construct a precomputed set  of all mismatches within a specified
  /// edit distance and the barcode whitelist.
  ///
  /// Arguments:
  ///- whitelist: sequences to expand as a vector of strings.
  ///- edit_distance: maximum number of substitutions per sequence.
  ///- allow_n: include Ns as substitutions.
  ///
  /// Return:
  ///
  /// A result enum containing a vector of maps of mismatched sequences to
  /// their whitelist sequences.
  ///
  pub fn construct_mismatch_to_whitelist_map(whitelist: Vec<String>, edit_distance: usize, allow_n: bool) -> Result<Vec<HashMap<String, String>>> {

    /*
    ** Set whitelist sequences to upper-case.
    */
    let whitelist_upper = whitelist.iter().map(|s| s.to_uppercase()).collect::<Vec<String>>();

    /*
    ** mismatch_to_whitelist_map is a vector of hash maps where the vector
    ** index is the number of substitutions in the mismatch sequence, and
    ** the hash maps are keyed by the sequences with substitutions and the
    ** values are the original whitelist sequences (no mismatches).
    */
    let mut mismatch_to_whitelist_map: Vec<HashMap<String, String>> = Vec::with_capacity(edit_distance+1);
    for _i in (0..edit_distance+1) {
      mismatch_to_whitelist_map.push(HashMap::new());
    }

    /*
    ** Set the zero mismatch sequence maps where the key and
    ** value are the same.
    */
    mismatch_to_whitelist_map[0] = whitelist_upper.iter().map(|s| (s.to_owned(), s.to_owned())).collect::<HashMap<String, String>>();


    /*
    ** Track  conflicts where mismatches map to different sequences.
    */
    let mut conflicting_mismatches: Vec<String> = Vec::new();

    /*
    ** Doesn't really matter as correction function will never see it,
    ** but exclude any perfect matches to actual seqs by mismatches.
    */
    conflicting_mismatches.extend(whitelist_upper.clone());


    for mismatch_count in (1..edit_distance+1) {

      for sequence in &whitelist_upper {
        /*
        ** Generate all possible mismatches in range.
        */
        let mismatches = generate_mismatches(&sequence, mismatch_count, allow_n)?;

        for mismatch in mismatches.iter() {
          if(mismatch_to_whitelist_map[mismatch_count].contains_key::<str>(&mismatch) == true) {
            conflicting_mismatches.push(mismatch.to_string());
          }
          mismatch_to_whitelist_map[mismatch_count].insert(mismatch.to_string(), sequence.clone());
        }
      }

      /*
      ** Go back and remove any conflicting mismatches.
      */
      for mismatch in conflicting_mismatches.clone().into_iter().unique() {
        if(mismatch_to_whitelist_map[mismatch_count].contains_key::<str>(&mismatch) == true) {
          mismatch_to_whitelist_map[mismatch_count].remove(&mismatch);
        }
      }
    }

    Ok(mismatch_to_whitelist_map)
  }

  /// Convert the output sequences of construct_mismatch_to_whitelist_map()
  /// from String to Vec<u8> in order to avoid UTF-8 checking. My tests
  /// suggest that using Vec<u8> rather than String may reduce the run
  /// time by about 8% to 9% where the run time includes reading the fastq
  /// input time and building the hashdict. My impression is that there is
  /// no compelling reason to use references because Vecs and Strings are
  /// stored as fat pointers with the strings/sequences being stored on the
  /// heap.
  ///
  /// Argument:
  ///- whitelist_map_string: the map list using Strings for sequences. This is returned by construct_mismatch_to_whitelist_map(), above.
  ///
  /// Return:
  ///
  /// A map list using Vec<u8> for sequences.
  /// 
  pub fn mismatch_to_whitelist_map_as_u8(whitelist_map_string: Vec<HashMap<String, String>>) -> Result<Vec<HashMap<Vec<u8>, Vec<u8>>>> {
    let vec_len: usize = whitelist_map_string.len();
    let mut whitelist_map_u8: Vec<HashMap<Vec<u8>, Vec<u8>>> = Vec::with_capacity(vec_len);
    for i in 0..vec_len {
      whitelist_map_u8.push(HashMap::new());
      for key in whitelist_map_string[i].keys() {
        whitelist_map_u8[i].insert(key.as_bytes().to_vec(), whitelist_map_string[i][key].as_bytes().to_vec());
      }
    } 
  
    Ok(whitelist_map_u8)
  }

}

