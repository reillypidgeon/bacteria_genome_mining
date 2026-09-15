#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script searches a query FASTA file against subject FASTA file(s)."

# Set default mmseqs2 parameters for minimum sequence identity and coverage
min_seq_id=0.5
min_coverage=0.5

# Set default mmseqs2 search_type variable
search_type=0

# Set default search_against variable (in case a directory is provided)
search_against="protein"

# Set a usage function
usage() {
	cat << 'EOF'
Usage:
    05_mmseqs2_search.sh [options] <query_fasta> <subject_fasta(s)>
    IMPORTANT: Options must come first if used!
    
Required arguments:
    <query_fasta>                   Query FASTA file
    <subject_fasta(s) or directory> One or more subject FASTA files or a single directory containing FASTA files

Options:
    -i, --min-seq-id 	 FLOAT   	Minimum sequence identity
                             		Default: ${min_seq_id}

    -c, --min-coverage 	 FLOAT 		Minimum sequence coverage
                             		Default: ${min_coverage}

	--search-type		 INT		Search type used by mmseqs2
									Options: 0 (automatic), 1 (amino acid), 2 (translated), 3 (nucleotide), 4 (translated nucleotide alignment)
									Default: 0 (automatic)
									
	
	-s, --search-against STRING     Search query FASTA against 'gene' or 'protein' FASTA files
							 		Useful when providing a subject_fasta(s) directory
									Options: gene or protein
							 		Default: protein

	-h, --help               		Display this help message

Examples:
    05_mmseqs2_search.sh ../results/queries.faa ../results/pyrodigal_out/*.faa
    05_mmseqs2_search.sh --min-seq-id 0.7 ../results/queries.faa ../results/pyrodigal_out/*.faa
    05_mmseqs2_search.sh --min-seq-id 0.7 --min-coverage 0.8 ../results/queries.faa ../results/pyrodigal_out/*.faa
	05_mmseqs2_search.sh ../results/queries.faa ../results/pyrodigal_out/
	05_mmseqs2_search.sh --search-against gene ../results/queries.faa ../results/pyrodigal_out/
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
    echo "Error: A query FASTA file and at least one subject FASTA file(s) are required"
    echo
    usage
    exit 1
fi

# Assign command line positional argument for the query (after all options have been assigned)
query_fasta="$1"
shift

# Check if the query file exists
if [[ ! -f "${query_fasta}" ]]; then
    echo "Error: Query FASTA file not found"
    exit 1
fi

# Check that the optional parameters make sense
# Search type
if ! [[ "${search_type}" =~ ^([04])$ ]]; then
    echo "Error: --search-type must be an integer between 0 and 4"
	echo "Value entered: ${search_type}"
	echo "From mmseqs2 documentation: 0: auto 1: amino acid, 2: translated, 3: nucleotide, 4: translated nucleotide alignment"
    exit 1
fi
# Sequence identity
if ! [[ "${min_seq_id}" =~ ^([01](\.[0-9]+)?|\.[0-9]+)$ ]]; then
    echo "Error: --min-seq-id must be a number between 0 and 1"
	echo "Value entered: ${min_seq_id}"
    exit 1
fi
# Sequence coverage
if ! [[ "${min_coverage}" =~ ^([01](\.[0-9]+)?|\.[0-9]+)$ ]]; then
    echo "Error: --coverage must be a number between 0 and 1"
	echo "Value entered: ${min_coverage}"
    exit 1
fi

# Check if the query fasta is a nucleotide or protein file and assign a default search type if not specified by the user

# Extract sequence lines, remove whitespace, and convert to uppercase.
query_sequences=$(awk '!/^>/ { gsub(/[[:space:]]/, ""); print }' "${query_fasta}" | tr '[:lower:]' '[:upper:]')
if [[ -z "${query_sequences}" ]]; then
    echo "ERROR: No sequences found in ${query_fasta}"
    exit 1
fi

# Check for characters outside the nucleotide alphabet
if echo "${query_sequences}" | grep -q '[^ACGTURYSWKMBDHVN-]'; then
    echo "Protein query FASTA detected"
else
    echo "Nucleotide query FASTA detected"
	# Set the search type if not already defined by the user (default value: 0)
	if [[ ${search_type} -eq 0 ]]; then
		echo "Setting the search type to 3 (nucleotide)" # This prevents errors when searching nt vs. nt
		search_type=3
	fi
fi

# Assign all remaining positional arguments as the subject(s)
# Detect the type of argument provided and assign to the subject_fastas variable
if [ "$#" -eq 1 ]; then
	echo "Single subject_fasta(s) argument detected."
	if [ -d "$@" ]; then
		echo "The argument is a directory"
		clean_dir="${@%/}" #Removes any forward slashes
		if [ "$search_against" = "gene" ]; then
			subject_fastas="${clean_dir}/*.fna"
			echo "Will loop through ${clean_dir}/"*.fna
		elif [ "$search_against" = "protein" ]; then
			subject_fastas="${clean_dir}/*.faa"
			echo "Will loop through ${clean_dir}/"*.faa
			echo "This is the default option"
		fi
	elif [ -f "$@" ]; then
		echo "The argument is a file"
		subject_fastas="$@"
		echo "Will run on the single file: ${subject_fastas}"
	else
		echo "Error: Argument is invalid"
		exit 1
	fi
elif [ "$#" -gt 1 ]; then
	echo "More than one argument detected"
	subject_fastas="$@"
else
	echo "Error with input"
	echo
	usage
	exit 1
fi

# Get the path to the script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"

# Create the output directory
out_dir="${project_dir}/results/mmseqs2_out"
mkdir -p "${out_dir}"

# Define the temporary directory for mmseqs2
tmp_dir="${project_dir}/tmp"
mkdir -p "${tmp_dir}"

# Set the number of CPUs, either based on the SLURM parameters or as a default of 1
threads="${SLURM_CPUS_PER_TASK:-1}"

# Check that mmseqs2 is available
if ! command -v mmseqs >/dev/null 2>&1; then
    echo "Error: MMseqs2 was not found."
    echo "Please activate an environment containing mmseqs2."
    exit 1
fi

# Print the parameters for this job
echo "==============================="
echo "Query FASTA: ${query_fasta}"
echo "Subject FASTA(s): ${subject_fastas}"
echo "Search type: ${search_type}"
echo "Search against: ${search_against}"
echo "Minimum sequence identity: ${min_seq_id}"
echo "Minimum sequence coverage: ${min_coverage}"
echo "Output directory: ${out_dir}"
echo "Temporary directory: ${tmp_dir}"
echo "Threads: ${threads}"
echo "mmseqs2: $(command -v mmseqs)"
echo "==============================="

# Assign the output format
out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq,tseq"

# Loop through the subject FASTA files
for subject_fasta in "${subject_fastas[@]}"; do
    # Check that the subject file exists
    if [[ ! -f "${subject_fasta}" ]]; then
        echo "Error: ${subject_fasta} file not found"
        exit 1
    fi
	# Check that the subject file is not empty
	
	# Extract the FASTA identity
    if [[ "${subject_fasta}" == *.fasta ]]; then
        fasta_id=$(basename "${subject_fasta}" .fasta)
    elif [[ "${subject_fasta}" == *.faa ]]; then
        fasta_id=$(basename "${subject_fasta}" .faa)
    elif [[ "${subject_fasta}" == *.fna ]]; then
        fasta_id=$(basename "${subject_fasta}" .fna)
    else
        fasta_id=$(basename "${subject_fasta}")
    fi
    # Define the output file naming format
    output_file="${out_dir}/${fasta_id}_mmseqs2.tsv"
    
    # Check if results file already exists
    if [ -f "${output_file}" ]; then
        echo "Results file for ${fasta_id} already exists. Skipping..."
        continue
    fi
    
    echo "Searching ${fasta_id} using mmseqs2"
    
    # Run the search (auto-detects the input FASTA formats)
    mmseqs easy-search \
        "${query_fasta}" \
        "${subject_fasta}" \
        "${output_file}" \
        "${tmp_dir}" \
        --threads "$threads" \
        --format-output "${out_format}" \
        --search-type ${search_type} \
		--min-seq-id ${min_seq_id} \
        -c ${min_coverage}
done

date
echo "mmseqs2 search finished"

#========================================================================
# Annotate the results tables and merge into a table of all and best hits
#========================================================================

# Check that Python is available
python_cmd="${PYTHON:-python3}"

if ! command -v "${python_cmd}" >/dev/null 2>&1; then
    echo "Error: Python executable not found: ${python_cmd}"
    exit 1
fi

# Check that pandas is available
if ! "${python_cmd}" -c "import pandas" >/dev/null 2>&1; then
    echo "Error: Python package 'pandas' is not available."
    echo "Please activate an environment containing pandas."
    exit 1
fi

# Add column headers based on the output format and merge results

export out_format
export out_dir
export project_dir

"${python_cmd}" "${script_dir}/merge_mmseqs2_tables.py"

echo "Finished mmseqs pipeline with annotations"
date
