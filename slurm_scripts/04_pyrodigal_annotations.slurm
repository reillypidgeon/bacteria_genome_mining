#!/usr/bin/env bash

#SBATCH --job-name=pyrodigal
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
module load python

# Create a temporary virtual environment
virtualenv --no-download "${SLURM_TMPDIR}/pyrodigal_env"

# Activate the environment
source "${SLURM_TMPDIR}/pyrodigal_env/bin/activate"

# Install pyrodigal from locally available packages
pip install --no-index --upgrade pip
pip install --no-index -r "${project_dir}/analysis_scripts/pyrodigal_requirements.txt"

# Check installation
echo "Python: $(which python)"
echo "Pyrodigal: $(which pyrodigal)"
pyrodigal --version

# Run pyrodigal
bash "${project_dir}/analysis_scripts/04_pyrodigal_annotations.sh" "${project_dir}"/genomes/*acc.fna

echo "Finished predicting proteins for all given genomes"
