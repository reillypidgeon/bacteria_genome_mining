# Bacteria Genome Mining

## Purpose
To find homologous sequences (or lack thereof) in genomes for a given taxonomic level, based on GTDB taxonomy (release 232). <br>
<br>
Useful for looking at taxonomic distribution of genes (or proteins) and strain-level variation within species.

> [!WARNING]
> This repository is a work in progress - there may be bugs!

## Approach
- Download genome fasta files (.fna) from the NCBI using GTDB (release 232) taxonomy based on user input
- Annotate fasta files and predict protein-coding sequences using [pyrodigal](https://github.com/althonos/pyrodigal)
- Search for homologous sequences in the newly-created protein catalogues using [mmseqs2](https://github.com/soedinglab/MMseqs2)
- Output tab-separated tables of all hits and best-hits for a given protein within a genome

## Usage
The first step is to extract the genomes relating to a user-defined taxonomic level from the GTDB release 232 metadata table
```
# To create the url list for genomes belonging to a user-defined taxonomic level
bash gtdb_r232_genome_extraction.sh -t g__Enterocloster

# To download all the genomes
bash gtdb_r232_genome_extraction.sh -t g__Enterocloster -d
```

The goal is to have a single command that can download all genomes based on a string match to a GTDB phylogenetic level (e.g., "g__Enterocloster").
The tool would then search different queries (either protein or nucleotide FASTA files) against the downloaded genomes. I may integrate Prodigal at some point to make protein-protein searches possible.
