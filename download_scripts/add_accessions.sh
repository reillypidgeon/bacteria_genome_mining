#!/usr/bin/env bash

echo "Running $0"
echo "This script adds genome accessions to the fasta header for use in downstream analyses that require this information."

if [ "$#" -ne 1 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: A directory containing one or more fasta files"
    echo "Usage: $0 <fasta_directory>"
    exit 1
fi

# Define the accessions variable based on the user input file
genomes_dir=$(basename "$1")
cd "$genomes_dir"

# Loop through fasta files, which all end with .fna
# Add the accession after the > and write a new file for each genome
for file in *.fna; do
    name="${file%.fna}"
    accession=$(echo $name | grep -Eo "^GC[A,F]_[[:digit:]]{9}\.[1-9]")
    sed "s/^>/>${accession}-/" "$file" > "${name}_acc.fna"
done
