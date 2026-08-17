#!/usr/bin/env bash

echo "Running $0"
echo "This script extracts accession and assembly codes from the GTDB release 232 metadata table according to user input."

if [ "$#" -ne 1 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: A taxon according to GTDB taxonomy"
    echo "Usage: $0 <taxon_string>"
    echo "Example: 'g__Enterocloster'"
    exit 1
fi

module load python/3.14.2 scipy-stack/2026a

# Define a function that will extract the accession, ncbi_assembly_name, and gtdb_taxonomy columns from the GTDB metadata table
gtdb_accessions_assemblies() {
  python3 << 'EOF'
  import pandas as pd
  # Read the table and keep the desired columns
  df = pd.read_csv("bac120_metadata_r232.tsv", sep='\t')
  df_acc = df[['accession', 'ncbi_assembly_name', 'gtdb_taxonomy']]
  # Write the output to a TSV file
  df_acc.to_csv("bac120_metadata_r232_acc.tsv", sep='\t')
  print("Extracted columns of interest from metadata table")
  EOF
}

# Check if the filtered metadata file already exists or prepare it
if [ -f "bac120_metadata_r232_acc.tsv" ]; then
  echo "Filtered metadata already exists. No need for downloads or further processing."
elif [ -f "bac120_metadata_r232.tsv" ]; then
  echo "Filtering the unzipped metadata table to extract the accession and ncbi_assembly_name columns"
  # Produce the filtered metadata file
  gtdb_accessions_assemblies
elif [ -f "bac120_metadata_r232.tsv.gz" ]; then
  echo "Zipped file exists. Unzipping and filtering columns"
  gunzip bac120_metadata_r232.tsv.gz
  # Produce the filtered metadata file
  gtdb_accessions_assemblies
else
  echo "Downloading the metadata, unzipping, and filtering data"
  wget https://data.gtdb.ecogenomic.org/releases/release232/232.0/bac120_metadata_r232.tsv.gz
  gunzip bac120_metadata_r232.tsv.gz
  # Produce the filtered metadata file
  gtdb_accessions_assemblies  
fi

# Now extract the accessions and assemblies that match to a partial string (user input)
