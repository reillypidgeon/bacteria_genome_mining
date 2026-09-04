#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script searches a query FASTA file against subject FASTA file(s)."

# Set default mmseqs2 parameters for minimum sequence identity and coverage
min_seq_id=0.5
min_coverage=0.5

# Set a usage function
usage() {
	cat << 'EOF'
Usage:
    $0 [options] <query_fasta> <subject_fasta(s)>
    IMPORTANT: Options must come first if used
    
Required arguments:
    <query_fasta>            Query FASTA file
    <subject_fasta(s)>       One or more subject FASTA files

Options:
    -s, --min-seq-id FLOAT   Minimum sequence identity
                             Default: ${min_seq_id}

    -c, --min-coverage FLOAT     Minimum sequence coverage
                             Default: ${coverage}

    -h, --help               Display this help message

Examples:
    $0 ../results/queries.faa ../genomes/*.faa

    $0 --min-seq-id 0.7 ../results/queries.faa ../genomes/*.faa

    $0 --min-seq-id 0.7 --min-coverage 0.8 ../results/queries.faa ../genomes/*.faa
EOF
}

# Parse the command line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -s|--min-seq-id)
            min_seq_id="$2"
            shift 2
            ;;
        -c|--coverage)
            min_coverage="$2"
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

# Assign all remaining positional arguments as the subject(s)
subject_fastas=("$@")

# Check if the query file exists
if [[ ! -f "${query_fasta}" ]]; then
    echo "Error: Query FASTA file not found"
    exit 1
fi

# Check that the optional parameters make sense (between 0-1)
if ! [[ "${min_seq_id}" =~ ^([01](\.[0-9]+)?|\.[0-9]+)$ ]]; then
    echo "Error: --min-seq-id must be a number between 0 and 1."
    exit 1
fi

if ! [[ "${min_coverage}" =~ ^([01](\.[0-9]+)?|\.[0-9]+)$ ]]; then
    echo "Error: --coverage must be a number between 0 and 1."
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
echo "Minimum sequence identity: ${min_seq_id}"
echo "Minimum sequence coverage: ${min_coverage}"
echo "Output directory: ${out_dir}"
echo "Temporary directory: ${tmp_dir}"
echo "Threads: ${threads}"
echo "mmseqs2: $(command -v mmseqs)"
echo "==============================="

# Assign the output format
out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq,tseq"

# Loop through the subject FASTA files (starting at position 2 all the way to the end of the positional arguments)
for subject_fasta in "${subject_fastas[@]}"; do
    # Check that the subject file exists
    if [[ ! -f "${subject_fasta}" ]]; then
        echo "Error: ${subject_fasta} file not found"
        exit 1
    fi
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
        --min-seq-id "${min_seq_id}" \
        -c "${min_coverage}"
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
