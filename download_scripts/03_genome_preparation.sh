#!/usr/bin/env bash

set -euo pipefail

# Get the path to the script directory and the project directory (bacteria_genome_mining)
current_dir=$(pwd)
script_dir=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
project_dir=$(dirname ${script_dir})
metadata_dir=${script_dir}/metadata

echo "Running unzip_genomes.sh"
# Unzip the files
bash ${scripts_dir}/unzip_genomes.sh ${genomes_dir}

# Add the genome accessions to each fasta file
if [ -f "${scripts_dir}/add_accessions.sh" ]; then
    echo "add_accessions.sh script found"
    bash ${scripts_dir}/add_accessions.sh ${genomes_dir}
    echo "Finished adding genome accessions to fasta files"
else
    echo "${scripts_dir}/add_accessions.sh script not found"
    echo "Exiting script without any fasta modifications"
    exit 1
fi

echo "Finished downloading and modifying the desired genomes"
