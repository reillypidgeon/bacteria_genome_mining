#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Error: Invalid number of arguments"
    echo "Required: A directory containing the FASTA files to unzip and annotate"
    echo "Usage: $0 <fasta_directory>"
    echo "Example: $0 'genomes/'"
    exit 1
fi

# Get the path to the script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"
genomes_dir="$1"

# Check that the genomes_dir exists
if [[ ! -d "${genomes_dir}" ]]; then
    echo "Error: The genomes directory was not found"
    exit 1
fi

# Unzip the files
echo "Unzipping genome files"
bash "${script_dir}/unzip_genomes.sh" "${genomes_dir}"

# Add the genome accessions to each fasta file
echo "Adding accessions to fasta headers"
bash "${script_dir}/add_accessions.sh" "${genomes_dir}"

echo "Finished adding genome accessions to fasta files"
