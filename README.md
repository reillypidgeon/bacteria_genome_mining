# Bacteria Genome Mining

## Purpose
To find homologous sequences (or lack thereof) in genomes for a given taxonomic level, based on GTDB taxonomy (release 232). <br>
<br>
Useful for looking at the taxonomic distribution of genes (or proteins) and strain-level variation within species.

> [!IMPORTANT]
> - Many of the scripts in this repository are formatted to run as SLURM (scheduled) jobs and are found in the ```slurm_scripts``` directory
> - Some scripts (```download_scripts/02_genome_download.sh```) will require internet access to work, so cannot be run in an interactive or scheduled job <br>
> - This repository is a work in progress - there may be bugs!

## Approach
- Download genome fasta files (.fna) from the NCBI using GTDB (release 232) taxonomy based on user input
- Annotate fasta files and predict protein-coding sequences using [pyrodigal](https://github.com/althonos/pyrodigal)
- Search for homologous sequences in the newly-created protein catalogues using [mmseqs2](https://github.com/soedinglab/MMseqs2)
- Output tab-separated tables of all hits and best-hits for a given protein within a genome

## Usage
### Genome FASTA Preparation and Downloading
The first step is to extract the genomes relating to a user-defined taxonomic level from the GTDB release 232 metadata table. The extracted genome accession and assembly codes can then be downloaded from the NCBI. To ensure that contigs from each genome (.fna) can easily be tracked back to a single accession, the accession for each genome is added to fasta headers. <br>
<br>
The following are usage examples:
```
# To create the table of accessions and assemblies for genomes belonging to a user-defined taxonomic level
# Optional SLURM script
bash 01_genome_extraction.sh "g__Enterocloster"
sbatch 01_genome_extraction.slurm "g__Enterocloster"

# To download the genomes from the created table
# IMPORTANT: Requires internet access
bash 02_genome_download.sh "metadata/genomes_g__Enterocloster_r232.tsv"

# To unzip genomes and add accessions to fasta headers
# Optional SLURM script
bash 03_genome_preparation.sh
sbatch 03_genome_preparation.slurm
```
> [!NOTE]
> - Scripts in the ```slurm_scripts``` directory may need to be modified based on the number of genomes
> - The most important modifications will likely be the time and memory, which are found near the top of the script

### Protein Prediction and Searching
Since not all accessions and assemblies will have available protein fasta files (.faa), it is preferable to generate a catalogue of protein sequences from each genome. The protein catalogue for each genome can then be searched against user-provided protein sequences (for each genome). <br>
```
# To annotate genomes and predict protein-coding sequences
# The *acc.fna used here represents FASTA files that have modified headers (added accessions)
bash 04_pyrodigal_annotations.sh ../genomes/*acc.fna
sbatch 04_pyrodigal_annotations.slurm ../genomes/*acc.fna

# To search a user-defined fasta file of queries against proteins predicted from genomes
bash 05_mmseqs2_search.sh ../results/queries.faa
sbatch 05_mmseqs2_search.slurm ../results/queries.faa
```
> [!NOTE]
> - Scripts in the ```slurm_scripts``` directory may need to be modified based on the number of genomes
> - The most important modifications will likely be the time and memory, which are found near the top of the script
