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
    echo "Usage: $0 <accessions_filename.tsv>"
    exit 1
fi

# Define the accessions variable based on the user input file
accessions="$1"
echo "Looking into $accessions"

# Check if found
if [[ ! -f "$accessions" ]]; then
    echo "Error: $accessions file not found"
    exit 1
fi

# Get the path to the script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"
metadata_dir="${script_dir}/metadata"

# Create the metadata directory in case it was deleted from the repository clone
mkdir -p "${metadata_dir}"

# Create an empty text file that will be populated with links to the FTP download site of the NCBI
urls_file="${metadata_dir}/urls.txt"
> "${urls_file}"

# Go line-by-line and build up URLs for each genome of interest
while IFS= read -r line
do
  base_url="https://ftp.ncbi.nlm.nih.gov/genomes/all"
  gb_rs=$(echo $line | grep -o "GC[AF]")
  accession=$(echo $line | grep -Eo "GC[AF]_[[:digit:]]{9}\.[[:digit:]]+")
  accession_numbers=$(echo $accession | grep -Eo "[[:digit:]]{9}")
  first_three=$(echo $accession_numbers | grep -Eo "^[0-9]{3}")
  second_three=$(echo $accession_numbers | grep -oP "(?<=^[0-9]{3})[0-9]{3}(?=[0-9]{3}$)")
  third_three=$(echo $accession_numbers | grep -Eo "[0-9]{3}$")
  assembly=$(echo "$line" | awk '{print $2}') # Extracts the second column
  full_url="${base_url}/${gb_rs}/${first_three}/${second_three}/${third_three}/${accession}_${assembly}/${accession}_${assembly}_genomic.fna.gz"
  echo "$accession_numbers | $first_three | $second_three | $third_three | $accession | $assembly"
  echo "$full_url" >> "${urls_file}"
done < "$accessions"

# Create a new directory for the genomes that will be downloaded
genomes_dir="${project_dir}/genomes"
mkdir -p "${genomes_dir}"
cd "${genomes_dir}"

# Download the genomes into the newly-created directory
# Requires internet access!
echo "Attempting to download the genomes"

if ! parallel -j 8 \
    --joblog "${metadata_dir}/wget.log" \
    wget -nc :::: "${urls_file}"
then
    echo "Warning: One or more downloads failed."
    echo "See ${metadata_dir}/wget.log for details."
fi

echo "Finished downloading genomes"
