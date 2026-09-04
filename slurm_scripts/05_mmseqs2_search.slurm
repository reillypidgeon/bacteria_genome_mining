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

    -c, --min-coverage FLOAT Minimum sequence coverage
                             Default: ${min_coverage}

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
bash "${project_dir}/analysis_scripts/05_mmseqs2_search.sh" --min-seq-id ${min_seq_id} --min-coverage ${min_coverage} "${query_fasta}" "${subject_fastas}"

echo "Finished predicting proteins for all given genomes"
