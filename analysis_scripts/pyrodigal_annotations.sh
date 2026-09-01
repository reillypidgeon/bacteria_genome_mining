#!/usr/bin/env bash

#SBATCH --job-name=pyrodigal
#SBATCH --time=12:00:00
#SBATCH --mem=100G
#SBATCH --cpus-per-task=8
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

date
set -euo pipefail

# Load required modules
module load StdEnv/2023 python/3.11.5
echo "Modules loaded"

echo "Running $0"
echo "This script predicts proteins from one or more nucleotide fasta files using pyrodigal."

if [ "$#" -lt 1 ]; then
	echo "Error: Invalid number of arguments."
	echo "Required: Nucleic acid fasta file(s)"
	echo "Usage: $0 <fasta_fna file(s)>"
	echo "Example: bash $0 genomes/*.fna"
	exit 1
fi

# Create a virtual environment to load pyrodigal for parallel predictions
virtualenv --no-download $SLURM_TMPDIR/env
source $SLURM_TMPDIR/env/bin/activate
pip install --no-index --upgrade pip

pip install --no-index -r pyrodigal_requirements.txt

current_dir=$(basename $PWD)

if [ $current_dir == "analysis_scripts" ]; then
    echo "Currently in ${current_dir}"
	out_dir="../pyrodigal_out"
	mkdir -p "${out_dir}"
elif [ $current_dir == "bacteria_genome_mining" ]; then
    echo "Currently in ${current_dir}"
    out_dir="pyrodigal_out"
	mkdir -p "${out_dir}"
elif [ -d "bacteria_genome_mining" ]; then
    echo "Currently in ${current_dir}"
    out_dir="bacteria_genome_mining/pyrodigal_out"
	mkdir -p "${out_dir}"
else
    echo "Could not resolve the path to bacteria_genome_mining"
    exit 1
fi

# Loop through the file(s)
for fasta_file in "$@"; do
	echo "Annotating ${fasta_file}"
	
	# Remove the trailing file extension and extract the fasta identity
	if [[ "${fasta_file}" == *.fasta ]]; then
		fasta_id=$(basename "${fasta_file}" .fasta)
	elif [[ "${fasta_file}" == *.fna ]]; then
		fasta_id=$(basename "${fasta_file}" .fna)
	else
		fasta_id=$(basename "${fasta_file}")
	fi
	
	# Check if annotation already exists
	if [ -f "${out_dir}/${fasta_id}_pyrodigal_prot.faa" ]; then
		echo "Annotations already exist. Skipping..."
		continue
	fi
	
	pyrodigal -i "${fasta_file}" \
	-p meta \
	-g 11 \
	-a "${out_dir}/${fasta_id}_pyrodigal_prot.faa" \
	-d "${out_dir}/${fasta_id}_pyrodigal_gene.fna" \
	-j $SLURM_CPUS_PER_TASK

	echo "Finished running pyrodigal on ${fasta_id}"
done

date
echo "Finished pyrodigal annotations on genomes"
