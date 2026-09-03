#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script extracts accession and assembly codes from the GTDB release 232 metadata table according to user input"

if [[ "$#" -lt 1 ]]; then
    echo "Error: Invalid number of arguments"
    echo "Required: A taxon according to GTDB taxonomy"
    echo "Usage: $0 <taxon_string(s)>"
    echo "Example: $0 'g__Enterocloster'"
    echo "Example: $0 'g__Enterocloster' 's__Hungatella hathewayi'"
    exit 1
fi

# Allow the Python executable to be overridden
python_cmd="${PYTHON:-python3}"

# Check that Python is available
if ! command -v "$python_cmd" >/dev/null 2>&1; then
    echo "Error: Python executable not found: $python_cmd"
    echo "Set the PYTHON environment variable or activate a suitable environment"
    exit 1
fi

# Check required pandas dependency
if ! "$python_cmd" -c "import pandas" >/dev/null 2>&1; then
    echo "Error: Python package 'pandas' is not available"
    echo "Please activate an environment containing pandas"
    echo "This dependency may be part of the scipy-stack module in your cluster"
    exit 1
fi

echo "Using Python: $("$python_cmd" --version)"

# Define a function that will merge chunked accession tables
merge_chunked_tables() {
table_dir="$1"
export table_dir

"$python_cmd" << 'EOF'
import pandas as pd
import glob
import os

table_dir = os.environ.get('table_dir')
files = sorted(glob.glob(f"{table_dir}/bac120_metadata_r232_acc_*.tsv"))

# Check if files can be found
if not files:
    raise FileNotFoundError(f"No chunked metadata files found in {table_dir}")

# Read the tables
dfs = []
for file in files:
    df = pd.read_csv(file, sep='\t')
    dfs.append(df)

df_acc = pd.concat(dfs, ignore_index=True)
df_acc = df_acc.sort_values(by = 'accession', ignore_index = True)

# Write the output to a TSV file
df_acc.to_csv(f"{table_dir}/bac120_metadata_r232_acc.tsv", sep='\t', index=False)

EOF
}

# Get the path to the script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"
metadata_dir="${script_dir}/metadata"
metadata_file="${metadata_dir}/bac120_metadata_r232_acc.tsv"

# Check if the filtered metadata file already exists or prepare it
if [[ -f "${metadata_file}" ]]; then
    echo "Filtered metadata already exists. No need for downloads or further processing."
else
    # Merge the chunked tables (1-6)
    merge_chunked_tables "${metadata_dir}"
fi

# Check that the final metadata file exists
if [[ ! -f "${metadata_file}" ]]; then
    echo "Error: Failed to create ${metadata_file}"
    exit 1
fi

# Check that the string(s) provided are valid according to the GTDB formatting
for taxon in "$@"; do
    if [[ "$taxon" =~ ^[kpcofgs]__ ]]; then 
        echo "The taxon format is valid: ${taxon}"
    else
        echo "The taxon name is not valid"
        echo "Please provide a taxon starting with either of the following:"
        echo "k__ p__ c__ o__ f__ g__ s__"
        echo "See https://gtdb.ecogenomic.org/tree?r=d__Bacteria"
        echo "Example: 'g__Enterocloster'"
        echo "Example: 's__Enterocloster bolteae'"
        exit 1
    fi
done
echo "Taxa are valid... Continuing with the workflow"

export metadata_dir

# Loop through the user-defined taxa and create genome accession and assembly tables in the metadata directory
for taxon in "$@"; do
    export taxon
    
    "$python_cmd" << 'EOF'
import pandas as pd
import os
taxon_string = os.environ.get('taxon')
metadata_dir = os.environ.get('metadata_dir')

print(f"Searching the metadata table for: {taxon_string}")
df = pd.read_csv(f"{metadata_dir}/bac120_metadata_r232_acc.tsv", sep='\t')
df_taxon = df[df['gtdb_taxonomy'].str.contains(taxon_string, case=False, na=False, regex=False)]
# Now select accession and ncbi_assembly_name columns and export without headers
df_genomes = df_taxon[['accession', 'ncbi_assembly_name']].copy()
# Replace spaces with underscores to avoid errors in later steps
df_genomes['ncbi_assembly_name'] = df_genomes['ncbi_assembly_name'].str.replace(' ', '_', regex=False)
file_name = f"genomes_{taxon_string}_r232.tsv".replace(" ", "_")
df_genomes.to_csv(f"{metadata_dir}/{file_name}", sep='\t', header=False, index=False)
EOF
done

echo "Finished extracting genome accessions and assemblies"
echo "Can now download genomes relating to $taxon using the 02_genome_download.sh script"
