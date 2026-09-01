#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script unzips fasta files downloaded from the NCBI."

if [ "$#" -ne 1 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: A directory containing one or more fasta files"
    echo "Usage: $0 <fasta_directory>"
    exit 1
fi

# Go to the user-defined directory
cd "$1"

echo "Unzipping files"
gunzip *.fna.gz
echo "Unzipping finished"
