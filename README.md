# Bacteria Genome Mining

## Purpose
To find homologous sequences (or lack thereof) in genomes for a given taxonomic level, based on GTDB taxonomy (release 232). <br>
<br>
Useful for looking at taxonomic distribution of genes (or proteins) and strain-level variation within species.

> [!IMPORTANT]
> - The code in this repository is meant to run on a SLURM scheduler (Digital Research Alliance of Canada) <br>
> - Some scripts will require internet access to work, so cannot be run in an interactive or scheduled job <br>
> - This repository is a work in progress - there may be bugs!

## Approach
- Download genome fasta files (.fna) from the NCBI using GTDB (release 232) taxonomy based on user input
- Annotate fasta files and predict protein-coding sequences using [pyrodigal](https://github.com/althonos/pyrodigal)
- Search for homologous sequences in the newly-created protein catalogues using [mmseqs2](https://github.com/soedinglab/MMseqs2)
- Output tab-separated tables of all hits and best-hits for a given protein within a genome

## Usage
The first step is to extract the genomes relating to a user-defined taxonomic level from the GTDB release 232 metadata table. The extracted genome accession and assembly codes can then be downloaded from the NCBI. To ensure that contigs from each genome can easily be tracked back to a single accession, the accession for each genome is added to fasta headers. <br>
```
# To create the table of accessions and assemblies for genomes belonging to a user-defined taxonomic level
bash genome_extraction.sh -t "g__Enterocloster"
# To download the genomes from the created table
bash genome_download.sh "genomes_g__Enterocloster_r232.tsv"

# To do both in one line, add the -d flag to genome_extraction.sh, which will automatically call the genome_download.sh script
bash genome_extraction.sh -t "g__Enterocloster" -d
```
<br>
