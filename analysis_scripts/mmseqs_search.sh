#!/usr/bin/env bash

#SBATCH --job-name=mmseqs2
#SBATCH --output=%x.out
#SBATCH --error=%x.err
#SBATCH --time=08:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4

module load StdEnv/2023 mmseqs2/17-b804f cudacore/.12.6.3

query_fasta="$1"
subject_fasta="$2" 

out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq,tseq"
out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq"

mmseqs easy-search \
    $query_fasta \
    $subject_fasta \
    mmseqs_results.tsv \
    tmp \
    --threads $SLURM_CPUS_PER_TASK \
    --format-output "query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq,tseq"

date
echo "mmseqs search finished"
