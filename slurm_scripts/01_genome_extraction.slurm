#!/usr/bin/env bash

#SBATCH --job-name=genome_extraction
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=00:10:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G

set -euo pipefail

# Taxa to extract based on user input
if [[ "$#" -lt 1 ]]; then
    echo "Error: Invalid number of arguments"
    echo "Required: At least one taxon according to GTDB taxonomy"
    echo "Usage: $0 <taxon_string(s)>"
    echo "Example: $0 'g__Enterocloster'"
    echo "Example: $0 'g__Enterocloster' 's__Hungatella hathewayi'"
    exit 1
fi

# Start from the directory where sbatch was submitted
search_dir="${SLURM_SUBMIT_DIR}"

# Search upward for the project root
while [[ "${search_dir}" != "/" ]]; do
    if [[ -d "${search_dir}/download_scripts" ]] && [[ -d "${search_dir}/analysis_scripts" ]]; then
        project_dir="${search_dir}"
        break
    fi
    search_dir="$(dirname "${search_dir}")"
done

# Stop if the project directory could not be found
if [[ -z "${project_dir:-}" ]]; then
    echo "Error: Could not locate the bacteria_genome_mining project directory."
    echo "The job must be submitted from somewhere inside the project."
    exit 1
fi

echo "SLURM submission directory: ${SLURM_SUBMIT_DIR}"
echo "Project directory: ${project_dir}"

# Load required software
module load python scipy-stack

echo "Running genome extraction"

# Run the portable genome extraction script
bash "${project_dir}/download_scripts/01_genome_extraction.sh" "$@"

echo "Genome extraction complete"
