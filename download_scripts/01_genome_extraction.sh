#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script extracts accession and assembly codes from the GTDB release 232 metadata table according to user input"

if [ "$#" -lt 2 ]; then
    echo "Error: Invalid number of arguments"
    echo "Required: A taxon according to GTDB taxonomy"
    echo "Usage: $0 -t <taxon_string>"
    echo "Example: $0 -t 'g__Enterocloster'"
    exit 1
fi

# Initialize variables
taxon=""

# Define flags
while getopts ":t" opt; do
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

module load python/3.14.2 scipy-stack/2026a

# Define a function that will merge chunked accession tables
merge_chunked_tables() {
file_path=$1
export file_path

python3 << 'EOF'
import pandas as pd
import glob
import os

file_path = os.environ.get('file_path')

# Read the tables
dfs = []
for df in glob.glob(f"{file_path}/bac120_metadata_r232_acc_*.tsv"):
    df = pd.read_csv(df, sep='\t')
    df
    dfs.append(df)

df_acc = pd.concat(dfs, ignore_index=True)
df_acc = df_acc.sort_values(by = 'accession', ignore_index = True)

# Write the output to a TSV file
df_acc.to_csv(f"{file_path}/bac120_metadata_r232_acc.tsv", sep='\t')

EOF
}

# Get the path to the script directory and the project directory (bacteria_genome_mining)
current_dir=$(pwd)
script_dir=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
project_dir=$(dirname ${script_dir})
metadata_dir="${script_dir}/metadata"

# Check if the filtered metadata file already exists or prepare it
if [ -f "${script_dir}/metadata/bac120_metadata_r232_acc.tsv" ]; then
    echo "Filtered metadata already exists. No need for downloads or further processing."
else
    # Merge the chunked tables (1-6)
    merge_chunked_tables "${metadata_dir}"
fi

# Now extract the accessions and assemblies that match a partial string (user input)
export taxon
export metadata_dir

python3 << 'EOF'
import pandas as pd
import os

taxon_string = os.environ.get('taxon')
metadata_dir = os.environ.get('metadata_dir')

print(f"Searching the metadata table for: {taxon_string}")
df = pd.read_csv(f"{metadata_dir}/bac120_metadata_r232_acc.tsv", sep='\t')
df_taxon = df[df['gtdb_taxonomy'].str.contains(taxon_string, case=False, na=False)]

# Now remove the taxonomy and ncbi_isolate columns and export without headers
df_genomes = df_taxon[['accession', 'ncbi_assembly_name']]
# Replace spaces with underscores to avoid errors in later steps
df_genomes['ncbi_assembly_name'] = df_genomes['ncbi_assembly_name'].str.replace(' ', '_')
file_name = f"genomes_{taxon_string}_r232.tsv".replace(" ", "_")
df_genomes.to_csv(f"{metadata_dir}/{file_name}", sep='\t', header=False, index=False)

EOF

echo "Finished extracting genomes"
echo "Can now download using the genome_download.sh script"
