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

for file in *; do
    # Skip files that have already been processed
    [[ "$file" == *_acc.fna ]] && continue

    if [[ "$file" == *.fna.gz ]]; then
        echo "Unzipping $file"
        gunzip *.fna.gz
    fi
done

echo "Unzipping finished"
