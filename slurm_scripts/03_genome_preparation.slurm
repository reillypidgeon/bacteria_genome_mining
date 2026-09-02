#!/usr/bin/env bash

#SBATCH --job-name=genome_preparation
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G

set -euo pipefail

# Get the project directory from the location of this SLURM script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"

echo "Running genome preparation"
echo "Project directory: ${project_dir}"
echo

# Run the portable genome preparation script
bash "${project_dir}/download_scripts/03_genome_preparation.sh"

echo
echo "Genome preparation complete"
