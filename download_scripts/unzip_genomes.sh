#!/usr/bin/env bash

#SBATCH --job-name=unzip_genomes
#SBATCH --output=%x_%j.out
#SBATCH --time=01:00:00
#SBATCH --mem=32G

echo "Unzipping files"
date
gunzip *.fna.gz
sleep 5
echo "Unzipping finished"

cat unzip_genomes*
# Remove the output file from the previous job to avoid errors when going through the genomes in later steps
rm unzip_genomes*

# Add the genome accessions to each fasta file
if [ -f "../download_scripts/add_accessions.sh" ]; then
    echo "add_accessions.sh script found"
    bash ../download_scripts/add_accessions.sh .
else
    echo "add_accessions.sh script not found"
    echo "Exiting script without any fasta modifications"
    exit 1
fi

echo "Finished adding genome accessions to fasta files"
