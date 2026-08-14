#!/usr/bin/env bash

echo "Running $0"
echo "This script adds genome accessions to the fasta header for use in downstream analyses that require this information."

if [ "$#" -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: A directory containing one or more fasta files"
    echo "Usage: $0 <fasta_directory>"
    exit 1
fi

# Define the accessions variable based on the user input file
fasta_dir="$1"


