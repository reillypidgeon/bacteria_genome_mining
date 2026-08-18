#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script extracts accession and assembly codes from the GTDB release 232 metadata table according to user input"

if [ "$#" -lt 1 ]; then
    echo "Error: Invalid number of arguments"
    echo "Required: A taxon according to GTDB taxonomy and an optional flag (-d) to download"
    echo "Usage: $0 -t <taxon_string> [-d]"
    echo "Example: $0 -t 'g__Enterocloster'"
    echo "Example: $0 -t 's__Enterocloster asparagiformis' -d"
    exit 1
fi

# Initialize variables
taxon=""
download_boolean=false

# Define flags
while getopts ":t:d" opt; do
  case ${opt} in
    t )
      taxon="$OPTARG"
      if [[ $taxon =~ ^[kpcofgs]__[A-Z] ]]; then 
          echo "The taxon is valid: ${taxon}"
      else
          echo "The taxon name is not valid"
          echo "Please provide a taxon starting with either of the following:"
          echo "k__ p__ c__ o__ f__ g__ s__"
          echo "Followed by the Uppercase taxon name"
          echo "See https://gtdb.ecogenomic.org/tree?r=d__Bacteria "
          echo "Example: -t g__Enterocloster"
          exit 1
      fi
      ;;
    d )
      download_boolean=true
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    : )
      echo "Invalid option: -$OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))

echo "Taxon of interest to download: $taxon"
echo "Download after producing the accessions table: $download_boolean"

module load python/3.14.2 scipy-stack/2026a

# Define a function that will extract the accession, ncbi_assembly_name, and gtdb_taxonomy columns from the GTDB metadata table
# This table can be reused for other analyses, so it's a good idea to save it
gtdb_accessions_assemblies() {
python3 << 'EOF'
import pandas as pd
# Read the table and keep the desired columns
df = pd.read_csv("bac120_metadata_r232.tsv", sep='\t')
df_acc = df[['accession', 'ncbi_assembly_name', 'gtdb_taxonomy', 'ncbi_isolate']]
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

# Now extract the accessions and assemblies that match a partial string (user input)
export taxon

python3 << 'EOF'
import pandas as pd
import os

taxon_string = os.environ.get('taxon')
print(f"Searching the metadata table for: {taxon_string}")
df = pd.read_csv("bac120_metadata_r232_acc.tsv", sep='\t')
df_taxon = df[df['gtdb_taxonomy'].str.contains(taxon_string, case=False, na=False)]

# Now remove the taxonomy and ncbi_isolate columns and export without headers
df_genomes = df_taxon[['accession', 'ncbi_assembly_name']]
# Replace spaces with underscores to avoid errors in later steps
df_genomes['ncbi_assembly_name'] = df_genomes['ncbi_assembly_name'].str.replace(' ', '_')
file_name = f"genomes_{taxon_string}_r232.tsv".replace(" ", "_")
df_genomes.to_csv(file_name, sep='\t', header=False, index=False)

EOF

# Check if the download flag is true and call the download script
if [[ $download_boolean == true ]]; then
    echo "Genomes will be downloaded using the ncbi_genome_download.sh script"
    # In case a species was given, this would replace the space with an underscore
    taxon=$(echo $taxon | tr ' ' '_')
    echo " Downloading genomes for $taxon based on genomes_${taxon}_r232.tsv"
    bash ncbi_genome_download.sh "genomes_${taxon}_r232.tsv"
else
    echo "The genomes file containing accessions and assemblies can now be separately passed to the ncbi_genome_download.sh script"
fi
