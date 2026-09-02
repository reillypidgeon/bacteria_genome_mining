#!/usr/bin/env bash

#SBATCH --job-name=mmseqs2
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G

set -euo pipefail

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

# Load Python
module load python mmseqs2

# Check installation
echo "Python: $(which python)"
echo "mmseqs2: $(which mmseqs2)"

# Run mmseqs2
bash "${project_dir}/analysis_scripts/05_mmseqs2_search.sh" "${project_dir}/results/queries.faa" "${project_dir}/results/pyrodigal_out/*.faa"

echo "Finished predicting proteins for all given genomes"
