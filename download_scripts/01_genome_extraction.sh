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

# Get the path to the script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"
metadata_dir="${script_dir}/metadata"
metadata_file="${metadata_dir}/bac120_metadata_r232_acc.tsv"

# Create the output directory for the tables filtered according to user-defined taxa
out_dir="${project_dir}/results/pyrodigal_out"
mkdir -p "${out_dir}"

# Define a function that will merge chunked accession tables
merge_chunked_tables() {
table_dir="$1"
export table_dir
"$python_cmd" "${script_dir}/merge_chunked_tables.py"
}

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
export out_dir

# Loop through the user-defined taxa and create genome accession and assembly tables in the results directory
for taxon in "$@"; do
    export taxon
    "$python_cmd" "${script_dir}/extract_taxa.py"
done

echo "Finished extracting genome accessions and assemblies"
echo "Can now download genomes relating to $taxon using the 02_genome_download.sh script"
