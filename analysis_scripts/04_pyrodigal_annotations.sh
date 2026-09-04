#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script predicts proteins from one or more nucleotide FASTA files using pyrodigal."

if [ "$#" -lt 1 ]; then
	echo "Error: Invalid number of arguments."
	echo "Required: Nucleic acid FASTA file(s)"
	echo "Usage: $0 <fasta_fna file(s)>"
	echo "Example: bash $0 ../genomes/*.fna"
	exit 1
fi

# Get the path to the script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"

# Create the output directory
out_dir="${project_dir}/results/pyrodigal_out"
mkdir -p "${out_dir}"

# Check that all input files exist
for fasta_file in "$@"; do
    if [[ ! -f "${fasta_file}" ]]; then
        echo "Error: Input FASTA file(s) not found"
        exit 1
    fi
done

# Set the number of CPUs, either based on the SLURM parameters or as a default of 1
threads="${SLURM_CPUS_PER_TASK:-1}"

# Check that pyrodigal is available
if ! command -v pyrodigal >/dev/null 2>&1; then
    echo "Error: pyrodigal was not found."
    echo "Please activate an environment containing pyrodigal."
	echo "Installation instructions can be found here: https://github.com/althonos/pyrodigal"
    exit 1
fi

echo "Using pyrodigal: $(command -v pyrodigal)"
echo "Threads: ${threads}"
echo "Output directory: ${out_dir}"

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
	
	protein_out="${out_dir}/${fasta_id}_pyrodigal_prot.faa"
	gene_out="${out_dir}/${fasta_id}_pyrodigal_gene.fna"
	
	# Check if protein annotation already exists
	if [ -f "${protein_out}" ]; then
		echo "Annotations already exist. Skipping..."
		continue
	fi
	
	pyrodigal -i "${fasta_file}" \
	-p meta \
	-g 11 \
	-a "${protein_out}" \
	-d "${gene_out}" \
	-j "$threads"
	
	echo "Finished running pyrodigal on ${fasta_id}"
done

date
echo "Finished pyrodigal annotations on genomes"
