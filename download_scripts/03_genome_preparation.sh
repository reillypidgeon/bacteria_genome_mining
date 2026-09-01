#!/usr/bin/env bash

set -euo pipefail

# Get the path to the script directory and the project directory (bacteria_genome_mining)
current_dir=$(pwd)
script_dir=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
project_dir=$(dirname ${script_dir})
genomes_dir=${project_dir}/genomes

# Unzip the files
echo "Unzipping using the unzip_genomes.sh script"
bash ${script_dir}/unzip_genomes.sh ${genomes_dir}

# Add the genome accessions to each fasta file
echo "Adding accessions to fasta headers using the add_accessions.sh script"
bash ${script_dir}/add_accessions.sh ${genomes_dir}

echo "Finished adding genome accessions to fasta files"
