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

## Dependencies
The following tools and packages need to be installed for the scripts in this repository to work
- Python
- GNU parallel
- [pandas](https://github.com/pandas-dev/pandas)
- [scipy](https://github.com/scipy/scipy)
- [pyrodigal](https://github.com/althonos/pyrodigal)
- [mmseqs2](https://github.com/soedinglab/MMseqs2)

<br>
On a local machine, it is best to create a Python virtual environment that has all these dependencies installed and available.

```
# In the project directory (bacteria_genome_mining), create a virtual environment called bgm_env (or whatever you want)
python3 -m venv bgm_env
source bgm_env/bin/activate

# Then install all required packages based on the requirements.txt file in the project directory
pip install -r requirements.txt

# Then run the scripts as shown in the Usage section below
```
<br>
On a HPC cluster like those from the Digital Research Alliance of Canada, modules need to first be loaded. These steps are already included in the slurm-ready scripts in the slurm_scripts directory. <br>

```
# Loading modules
module load python
module load scipy-stack
module load mmseqs2

# In the slurm_scripts directory, the 04_pyrodigal_annotations.slurm script creates a virtual environment and installs pyrodigal using requirements in analysis_scripts/pyrodigal_requirements.txt
module load python

virtualenv --no-download "${SLURM_TMPDIR}/pyrodigal_env"
source "${SLURM_TMPDIR}/pyrodigal_env/bin/activate"

pip install --no-index --upgrade pip
pip install --no-index -r "${project_dir}/analysis_scripts/pyrodigal_requirements.txt"
```

## Usage
### Genome FASTA Preparation and Downloading
The first step is to extract the genomes of one or more user-defined taxonomic levels from the GTDB release 232 metadata table. The extracted genome accession and assembly codes can then be downloaded from the NCBI. To ensure that contigs from each genome (.fna) can easily be traced back to a single accession, the accession for each genome is added to FASTA headers. <br>
<br>
The following are usage examples:
```
# To create the table of accessions and assemblies for genomes belonging to a user-defined taxonomic level
# Optional SLURM script

bash 01_genome_extraction.sh "g__Enterocloster"
bash 01_genome_extraction.sh "g__Enterocloster" "s__Hungatella hathewayi"
sbatch 01_genome_extraction.slurm "g__Enterocloster"

# To download the genomes from the created table
# IMPORTANT: Requires internet access

bash 02_genome_download.sh "metadata/genomes_g__Enterocloster_r232.tsv"
bash 02_genome_download.sh "metadata/genomes_*_r232.tsv"

# To unzip genomes and add accessions to FASTA headers
# Optional SLURM script

bash 03_genome_preparation.sh "../genomes"
sbatch 03_genome_preparation.slurm "../genomes"
```
> [!NOTE]
> - Scripts in the ```slurm_scripts``` directory may need to be modified based on the number of genomes
> - The most important modifications will likely be the time and memory, which are found near the top of the script

### Protein Prediction and Searching
Since not all accessions and assemblies will have available protein FASTA files (.faa), it is preferable to generate a catalogue of protein sequences from each genome. The protein catalogue for each genome can then be searched against user-provided protein sequences (for each genome). <br>
```
# To annotate genomes and predict protein-coding sequences
# The *acc.fna used here represents FASTA files that have modified headers (added accessions)

bash 04_pyrodigal_annotations.sh ../genomes/*acc.fna
sbatch 04_pyrodigal_annotations.slurm ../genomes/*acc.fna

# To search a user-defined FASTA file of queries against proteins predicted from genomes

bash 05_mmseqs2_search.sh ../results/queries.faa ../results/pyrodigal_out/*.faa
sbatch 05_mmseqs2_search.slurm ../results/queries.faa ../results/pyrodigal_out/*.faa
```
> [!NOTE]
> - Scripts in the ```slurm_scripts``` directory may need to be modified based on the number of genomes
> - The most important modifications will likely be the time and memory, which are found near the top of the script
