#!/usr/bin/env bash

#SBATCH --job-name=mmseqs2
#SBATCH --output=%x.out
#SBATCH --error=%x.err
#SBATCH --time=08:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4

set -euo pipefail

echo "Running $0"
echo "This script adds genome accessions to the fasta header for use in downstream analyses that require this information."

if [ "$#" -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: FASTA files of the query and subject (target)"
    echo "Usage: $0 <query_fasta> <subject_fasta>"
    exit 1
fi

module load StdEnv/2023 mmseqs2/17-b804f cudacore/.12.6.3

# Assign command line arguments
query_fasta="$1"
subject_fasta="$2" 

if [ $subject_fasta == "*.faa" ]; then
    echo "Protein subject/database"
    out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq,tseq"
else
    out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq"
fi

# Run the search (auto-detects the input fasta formats)
mmseqs easy-search \
    $query_fasta \
    $subject_fasta \
    mmseqs_results.tsv \
    tmp \
    --threads $SLURM_CPUS_PER_TASK \
    --format-output $out_format

date
echo "mmseqs search finished"

# Add column headers based on the output format immediately
