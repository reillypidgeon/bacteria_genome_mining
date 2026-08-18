#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script downloads genome fasta files from the NCBI based on a user-defined table containing accessions and assemblies."
echo "These are used to build a URL that can access the NCBI FTP site."
echo
echo "Important: This script requires internet access to fetch the genomes"

if [ "$#" -ne 1 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: A tab-separated file containing a column with NCBI accession and a column with the NCBI assembly."
    echo "Example line: GB_GCA_048366555.1  ASM4836655v1"
    echo "Usage: $0 <accessions_filename>"
    exit 1
fi

# Define the accessions variable based on the user input file
accessions="$1"
echo "Looking into $accessions"

# Create an empty text file that will be populated with links to the FTP download site of the NCBI
touch urls.txt

# Go line-by-line and build up URLs for each genome of interest
while IFS= read -r line
do
  base_url="https://ftp.ncbi.nlm.nih.gov/genomes/all"
  gb_rs=$(echo $line | grep -o "GC[A,F]")
  accession=$(echo $line | grep -Eo "GC[A,F]_[[:digit:]]{9}\.1")
  accession_numbers=$(echo $accession | grep -Eo "[[:digit:]]{9}")
  first_three=$(echo $accession_numbers | grep -Eo "^[0-9]{3}")
  second_three=$(echo $accession_numbers | grep -oP "(?<=^[0-9]{3})[0-9]{3}(?=[0-9]{3}$)")
  third_three=$(echo $accession_numbers | grep -Eo "[0-9]{3}$")
  assembly=$(echo $line | awk '{print $2}') # Extracts the second column
  full_url="${base_url}/${gb_rs}/${first_three}/${second_three}/${third_three}/${accession}_${assembly}/${accession}_${assembly}_genomic.fna.gz"
  echo "$accession_numbers | $first_three | $second_three | $third_three | $accession | $assembly"
  echo $full_url >> urls.txt
done < $accessions

# Create a new directory for the genomes that will be downloaded
mkdir -p genomes
cd genomes

# Download the genomes into the newly-created directory
cat ../urls.txt | parallel -j 8 wget -nc

# Unzip the files
gunzip *.fna.gz
