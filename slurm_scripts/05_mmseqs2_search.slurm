#!/usr/bin/env bash

#SBATCH --job-name=mmseqs2
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G

set -euo pipefail

# Set default mmseqs2 parameters for minimum sequence identity and coverage
min_seq_id=0.5
min_coverage=0.5

# Set default search type (protein)
search_against="protein"

# Set a usage function
usage() {
	cat << 'EOF'
Usage:
    05_mmseqs2_search.sh [options] <query_fasta> <subject_fasta(s)>
    IMPORTANT: Options must come first if used!
    
Required arguments:
    <query_fasta>                   Query FASTA file
    <subject_fasta(s) or directory> One or more subject FASTA files or a directory containing FASTA files

Options:
    -i, --min-seq-id FLOAT   		Minimum sequence identity
                             		Default: ${min_seq_id}

    -c, --min-coverage FLOAT 		Minimum sequence coverage
                             		Default: ${min_coverage}

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
		-s|--search-against)
			if [[ "$2" =~ "gene" ]]; then
				search_against="gene"
			elif [[ "$2" =~ "protein" ]]; then
				search_against="protein" # Already default
			else
				echo "Error: If using this flag, specify whether you want to search against 'gene' or 'protein' FASTA files
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

# Assign all remaining positional arguments as the subject(s)
# Detect the type of argument provided and assign to the subject_fastas variable
if [ "$#" -eq 1 ]; then
	echo "Single subject_fasta(s) argument detected."
	if [ -d "$@" ]; then
		echo "The argument is a directory"
		clean_dir="${@%/}" #Removes any forward slashes
		if [ "$search_against" = "gene" ]; then
			subject_fastas="${clean_dir}/*.fna"
			echo "Will loop through ${clean_dir}/*.fna"
		elif [ "$search_against" = "protein" ]; then
			subject_fastas="${clean_dir}/*.faa"
			echo "Will loop through ${clean_dir}/*.faa"
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
module load python mmseqs2 scipy-stack

# Check installation
echo "Python: $(which python)"

# Run mmseqs2
bash "${project_dir}/analysis_scripts/05_mmseqs2_search.sh" --min-seq-id ${min_seq_id} --min-coverage ${min_coverage} --search-against ${search_against} ${query_fasta} ${subject_fastas}

echo "Finished predicting proteins for all given genomes"
