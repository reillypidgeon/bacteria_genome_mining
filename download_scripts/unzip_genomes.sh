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
