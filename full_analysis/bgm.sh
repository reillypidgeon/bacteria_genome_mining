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
time_code=$(date +%Y%m%d%H%M)
out_dir="${project_dir}/results/mmseqs2_out/mmseqs2_search_${time_code}"

# Set a usage function
usage() {
	cat << 'EOF'
Usage:
    bgm.sh [options] <query_fasta> <taxon_string(s)>
    IMPORTANT: Options must come first (if used), followed by a single query FASTA file, then by one or more taxa

Required arguments:
    <query_fasta>                        Query FASTA file (nucleotide or protein)
    <taxon_string(s)>                    One or more partial strings according to GTDB taxonomy

Options:
    -o, --out-dir           STRING       Output directory path
                                         Default: ${out_dir}
    -i, --min-seq-id        FLOAT        Minimum sequence identity
                                         Default: ${min_seq_id}
    -c, --min-coverage      FLOAT        Minimum sequence coverage
                                         Default: ${min_coverage}
    --search-type           INT          Search type used by mmseqs2
                                         Options: 0 (automatic), 1 (amino acid), 2 (translated), 3 (nucleotide), 4 (translated nucleotide alignment)
                                         Default: 0 (automatic)
    -s, --search-against    STRING       Search query FASTA against 'gene' or 'protein' FASTA files
                                         Useful when providing a subject_fasta(s) directory
                                         Options: gene or protein
                                         Default: protein
    -h, --help                           Display this help message

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
        -o|--out-dir)
            out_dir="$2"
            mkdir -p "${out_dir}"
            shift 2
            ;;
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

# Trim spaces from taxa names (in case of species) and replace with underscores
taxa_underscore=()
for taxon in "${taxa[@]}"; do
    taxon_underscore=$(echo $taxon | tr ' ' '_')
    taxa_underscore+=( "${taxon_underscore}" )
done

# In the project directory (bacteria_genome_mining), create a virtual environment called bgm_env
python3 -m venv ${project_dir}/bgm_env
source ${project_dir}/bgm_env/bin/activate

# Then install all required packages based on the requirements.txt file in the project directory
pip install -r ${project_dir}/requirements.txt

# Call the download and analysis scripts
# Step 01
bash ${download_scripts_dir}/01_genome_extraction.sh "${taxa[@]}"

# Step 02
# Create a single urls_file specific to the taxa specified in the command line arguments
urls_merged="${accessions_dir}/urls_"$(echo "${taxa[@]}" | tr ' ' '_')".txt" > "${urls_merged}"

# Download the genomes and append the urls.txt for each iteration of the loop to the $urls_merged file
for taxon in "${taxa_underscore}"; do
    bash ${download_scripts_dir}/02_genome_download.sh "${accessions_dir}/genomes_${taxon}_r232.tsv"
    cat ${accessions_dir}/urls.txt >> "${urls_merged}"
done

# Step 03
bash ${download_scripts_dir}/03_genome_preparation.sh "${genomes_dir}"

# Step 04
bash ${analysis_scripts_dir}/04_pyrodigal_annotations.sh "${genomes_dir}"

# Step 05
# Loop through the individual gene or protein annotations based on the $urls_merged file
while IFS= read -r line; do
    file_base=$(basename $line .fna.gz)
    # Build the annotation file name based on the url basename and the search-against flag
    if [ ${search_against} = "gene" ]; then
        annotation_file="${subject_fastas_dir}/${file_base}_acc_pyrodigal_gene.fna"
    else
        annotation_file="${subject_fastas_dir}/${file_base}_acc_pyrodigal_prot.faa"
    fi
    # Check if the annotation file exists and skip if it does not exist
    if [ -f "${annotation_file}" ]; then
        echo "Searching ${query_fasta} against ${annotation_file}"
    else
        echo "Annotation file not found: ${annotation_file}. Skipping..."
        continue
    fi
    # Run the search if all checks are successful
    bash ${analysis_scripts_dir}/05_mmseqs2_search.sh --out-dir "${out_dir}" --min-seq-id "${min_seq_id}" --out-dir "${out_dir}" --min-coverage "${min_coverage}" --search-type ${search_type} --search-against "${search_against}" "${query_fasta}" "${annotation_file}"
done < "${urls_merged}"
