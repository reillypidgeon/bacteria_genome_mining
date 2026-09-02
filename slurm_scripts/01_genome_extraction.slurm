#!/usr/bin/env bash

#SBATCH --job-name=genome_extraction
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=00:15:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G

set -euo pipefail

# Get the project directory from the location of this SLURM script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"

# Load required software
module load python/3.14.2 scipy-stack/2026a

# Taxon to extract based on user input
if [[ "$#" -ne 1 ]]; then
    echo "Error: Taxon argument is required."
    echo "Usage: sbatch 01_genome_extraction.slurm <taxon_string>"
    echo "Example: sbatch 01_genome_extraction.slurm 'g__Enterocloster'"
    exit 1
fi

taxon="$1"

echo "Running genome extraction"
echo "Project directory: ${project_dir}"
echo "Taxon: $taxon"
echo

# Run the portable genome extraction script
bash "${project_dir}/download_scripts/01_genome_extraction.sh" "$taxon"

echo
echo "Genome extraction complete"
