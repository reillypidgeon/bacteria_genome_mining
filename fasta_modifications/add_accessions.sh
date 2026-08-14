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
fasta_dir=$(basename "$1")

# Loop through fasta files, which all end with .fna
for file in ${fasta_dir}/*.fna; do
    name="${file%.fna}"
    echo $name
    #sed "s/^>/>${name}_/" "$file" > "${name}_modified.fasta"
done
