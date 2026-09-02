#!/usr/bin/env bash

#SBATCH --job-name=genome_extraction
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=00:15:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G

set -euo pipefail

# Taxon to extract based on user input
if [[ "$#" -ne 1 ]]; then
    echo "Error: Taxon argument is required."
    echo "Usage: sbatch 01_genome_extraction.slurm <taxon_string>"
    echo "Example: sbatch 01_genome_extraction.slurm 'g__Enterocloster'"
    exit 1
fi

# Set the taxon variable
taxon="$1"

# Return to the directory from which sbatch was submitted
cd "${SLURM_SUBMIT_DIR}"

# Get the absolute path to the project
project_dir="$(pwd)"

# Define the script directory
script_dir="${project_dir}/download_scripts"

echo "SLURM submit directory: ${SLURM_SUBMIT_DIR}"
echo "Project directory: ${project_dir}"
echo "Script directory: ${script_dir}"

# Load required software
module load python scipy-stack

echo "Running genome extraction"
echo "Taxon: $taxon"

# Run the portable genome extraction script
bash "${script_dir}/01_genome_extraction.sh" "$taxon"

echo "Genome extraction complete"
