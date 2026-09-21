#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script searches a user-defined FASTA file against genomes from bacteria, based on user-defined taxonomic levels or species"
echo "By default, the user-defined query FASTA file will be searched against a predicted protein database for genomes matching the taxon input string(s) and output hits with sequence identity and coverage values of 0.5"
echo "These default values can be changed by providing flags with the input"

# Get the path to the current script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"

# Set the paths to scripts and results
analysis_scripts_dir="${project_dir}/analysis_scripts"
download_scripts_dir="${project_dir}/download_scripts"
metadata_dir="${download_scripts_dir}/metadata"
genomes_dir="${project_dir}/genomes"
results_dir="${project_dir}/results"
accessions_dir="${results_dir}/accessions_out"

# Set default parameters
min_seq_id=0.5
min_coverage=0.5
subject_fastas_dir="${results_dir}/pyrodigal_out"
search_type=0
search_against="protein"

# Set a usage function
usage() {
	cat << 'EOF'
Usage:
    bgm.sh [options] <query_fasta> <taxon_string(s)>
    IMPORTANT: Options must come first (if used), followed by a single query FASTA file, then by one or more taxa

Required arguments:
    <query_fasta>            Query FASTA file (nucleotide or protein)
    <taxon_string(s)>        One or more partial strings according to GTDB taxonomy

Options:
    Options:
    -i, --min-seq-id     FLOAT          Minimum sequence identity
                                        Default: ${min_seq_id}

    -c, --min-coverage   FLOAT          Minimum sequence coverage
                                        Default: ${min_coverage}

    --search-type        INT            Search type used by mmseqs2
                                        Options: 0 (automatic), 1 (amino acid), 2 (translated), 3 (nucleotide), 4 (translated nucleotide alignment)
                                        Default: 0 (automatic)

    -s, --search-against STRING         Search query FASTA against 'gene' or 'protein' FASTA files
                                        Useful when providing a subject_fasta(s) directory
                                        Options: gene or protein
                                        Default: protein

    -h, --help                          Display this help message

Examples:
    bgm.sh ../queries.faa "g__Enterocloster"

    bgm.sh --min-seq-id 0.7 ../queries.faa "g__Enterocloster" "s__Hungatella hathewayi"

    bgm.sh --min-seq-id 0.7 --min-coverage 0.8 ../queries.fna "g__Enterocloster" "s__Hungatella hathewayi" "g__Ventricola"

    bgm.sh --min-seq-id 0.7 --min-coverage 0.8 --search-type 3 --search-against gene ../queries.fna "g__Enterocloster" "s__Hungatella hathewayi" "g__Ventricola"
EOF
}

# Parse the command line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -i|--min-seq-id)
            min_seq_id="$2"
            shift 2
            ;;
        -c|--min-coverage)
            min_coverage="$2"
            shift 2
            ;;
        --search-type)
			search_type="$2"
			shift 2
			;;
		-s|--search-against)
			if [[ "$2" =~ "gene" ]]; then
				search_against="gene"
			elif [[ "$2" =~ "protein" ]]; then
				search_against="protein" # Already default
			else
				echo "Error: If using this flag, specify whether you want to search against 'gene' or 'protein' FASTA files"
				echo
				usage
				exit 1
			fi
			shift 2
			;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Error: Unknown option: $1"
            echo
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -lt 2 ]; then
    echo "Error: A query FASTA file and at least one taxon of interest are required"
    echo
    usage
    exit 1
fi

# Assign command line positional argument for the query FASTA (after all options have been assigned)
query_fasta="$1"
shift

# Assign all remaining positional arguments as the taxa
taxa=("$@")

# In the project directory (bacteria_genome_mining), create a virtual environment called bgm_env
python3 -m venv ${project_dir}/bgm_env
source ${project_dir}/bgm_env/bin/activate

# Then install all required packages based on the requirements.txt file in the project directory
pip install -r ${project_dir}/requirements.txt

# Call the download and analysis scripts
bash ${download_scripts_dir}/01_genome_extraction.sh "${taxa[@]}"

bash ${download_scripts_dir}/02_genome_download.sh "${accessions_dir}/"genomes_*_r232.tsv

bash ${download_scripts_dir}/03_genome_preparation.sh "${genomes_dir}"

bash ${analysis_scripts_dir}/04_pyrodigal_annotations.sh "${genomes_dir}"

# Based on the taxa, subset the subject FASTAs for the final mmseqs2 step
accessions_tables="${accessions_dir}/genomes_${taxa[@]}_r232.tsv" #ADD HERE
echo ${accessions_tables}

# 
for taxon in "${taxa[@]}"; do
	echo "$taxon"
	#taxon_underscore=
	#accessions_tables="${accessions_dir}/genomes_${taxon_underscore}_r232.tsv"
done

bash ${analysis_scripts_dir}/05_mmseqs2_search.sh --min-seq-id "${min_seq_id}" \
	--min-coverage "${min_coverage}" \
	--search-type ${search_type} \
	--search-against ${search_against} \
	"${query_fasta}" \
	"${subject_fastas_dir}"
