#!/usr/bin/env bash

#SBATCH --job-name=pyrodigal
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G

set -euo pipefail

# Get the project directory
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"

# Load Python
module load python/3.14.2

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
bash "${project_dir}/annotation_scripts/pyrodigal.sh" "${project_dir}"/genomes/*.fna

echo "Finished predicting proteins for all given genomes"
