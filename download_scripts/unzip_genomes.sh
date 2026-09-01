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
