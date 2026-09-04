#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script searches a user-defined FASTA file against genomes from bacteria, based on user-defined taxonomic levels or species"

# Get the path to the current script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"

# Set the paths to scripts and results
analysis_scripts_dir="${project_dir}/analysis_scripts"
download_scripts_dir="${project_dir}/download_scripts"
metadata_dir="${download_scripts_dir}/metadata"
genomes_dir="${project_dir}/genomes"
results_dir="${project_dir}/results"

# Set default parameters
min_seq_id=0.5
min_coverage=0.5
subject_fastas="${results_dir}/pyrodigal_out"/*.faa

# Set a usage function
usage() {
	cat << 'EOF'
Usage:
    $0 [options] <query_fasta> <taxon_string(s)>
    IMPORTANT: Options must come first (if used), followed by a single query FASTA file, then by as many taxa as you want
    
Required arguments:
    <query_fasta>            Query FASTA file
    <taxon_string(s)>        One or more partial strings according to GTDB taxonomy

Options:
    -s, --min-seq-id FLOAT   Minimum sequence identity for mmseqs2
                             Default: ${min_seq_id}

    -c, --min-coverage FLOAT Minimum sequence coverage for mmseqs2
                             Default: ${min_coverage}
    
    -g, --gene               Search FASTA against genes (.fna)
    
    -p, --protein            Search FASTA against proteins (.faa)
                             Default
    
    -h, --help               Display this help message

Examples:
    $0 queries.faa "g__Enterocloster"

    $0 --min-seq-id 0.7 queries.faa "g__Enterocloster" "s__Hungatella hathewayi"

    $0 --min-seq-id 0.7 --min-coverage 0.8 queries.fna --gene "g__Enterocloster" "s__Hungatella hathewayi" "g__Ventricola"
EOF
}

# Parse the command line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -s|--min-seq-id)
            min_seq_id="$2"
            shift 2
            ;;
        -c|--min-coverage)
            min_coverage="$2"
            shift 2
            ;;
        -g|--gene)
            subject_fastas="${results_dir}/pyrodigal_out/*.fna"
            shift
            ;;
        -p|--protein)
            # Noting changes for the subject_fasta variable
            subject_fastas="${results_dir}/pyrodigal_out/*.faa"
            shift
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

bash ${download_scripts_dir}/02_genome_download.sh "${results_dir}/accessions_out"/genomes_*_r232.tsv

bash ${download_scripts_dir}/03_genome_preparation.sh "${genomes_dir}"

bash ${analysis_scripts_dir}/04_pyrodigal_annotations.sh "${genomes_dir}"/*.fna

bash ${analysis_scripts_dir}/05_mmseqs2_search.sh --min-seq-id "${min_seq_id}" --min-coverage "${min_coverage}" "${query_fasta}" "${subject_fastas}"
