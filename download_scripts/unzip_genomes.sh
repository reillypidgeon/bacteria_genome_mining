#!/usr/bin/env bash

echo "Running $0"
echo "This script unzips fasta files downloaded from the NCBI."

if [ "$#" -ne 1 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: A directory containing one or more fasta files"
    echo "Usage: $0 <fasta_directory>"
    exit 1
fi

# Define the accessions variable based on the user input file
genomes_dir=$(basename "$1")
cd "$genomes_dir"

echo "Unzipping files"
gunzip *.fna.gz
echo "Unzipping finished"
