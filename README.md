# Bacteria Genome Mining (BGM)

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
module load python scipy-stack mmseqs2

# In the slurm_scripts directory, the 04_pyrodigal_annotations.slurm script creates a virtual environment and installs pyrodigal using requirements in slurm_scripts/pyrodigal_requirements.txt
module load python

virtualenv --no-download "${SLURM_TMPDIR}/pyrodigal_env"
source "${SLURM_TMPDIR}/pyrodigal_env/bin/activate"

pip install --no-index --upgrade pip
pip install --no-index -r "${project_dir}/slurm_scripts/pyrodigal_requirements.txt"
```

## Usage
### Full Analysis
This tool can be run by calling a single script or by calling individual scripts (see Genome FASTA Preparation & Downloading and Protein Prediction & Searching sections below for individual steps). <br>
To run the tool on a local machine or in an interactive SLURM job (with internet access), you can call the following script (located in the full_analysis directory): <br>
```
bash bgm.sh ../queries.fna "g__Enterocloster" "s__Hungatella hathewayi"

# Optional flags can be added to change default parameters for the mmseqs2 search (flags must come before the query FASTA file and taxa of interest)
bash bgm.sh --min-seq-id 0.7 --min-coverage 0.8 --gene ../queries.fna "g__Enterocloster" "s__Hungatella hathewayi"
```

### Genome FASTA Preparation & Downloading
The first step is to extract the genomes of one or more user-defined taxonomic levels from the GTDB release 232 metadata table. The extracted genome accession and assembly codes can then be used to create URLs to download genome FASTA files from the NCBI. To ensure that contigs from each genome can easily be traced back to a single accession, the accession for each genome is added to FASTA headers. <br>
<br>
The following are usage examples: <br>

**01_genome_extraction**
```
# Create table(s) of accessions and assemblies for genomes belonging to one or more user-defined taxa
bash 01_genome_extraction.sh "g__Enterocloster"
bash 01_genome_extraction.sh "g__Enterocloster" "s__Hungatella hathewayi"

# Optional SLURM script
sbatch 01_genome_extraction.slurm "g__Enterocloster"
sbatch 01_genome_extraction.slurm "g__Enterocloster" "s__Hungatella hathewayi"
```
**02_genome_download**
```
# Download the genomes from the created table(s)
# IMPORTANT: Requires internet access
bash 02_genome_download.sh "../results/accessions_out/genomes_g__Enterocloster_r232.tsv"
bash 02_genome_download.sh "../results/accessions_out/genomes_*_r232.tsv"
```
**03_genome_preparation**
```
# Unzip genomes and add accessions to FASTA headers for all FASTA files (.fna) in the genomes directory
bash 03_genome_preparation.sh "../genomes/"

# Optional SLURM script
sbatch 03_genome_preparation.slurm "../genomes/"
```
> [!NOTE]
> - Scripts in the ```slurm_scripts``` directory may need to be modified based on the number of genomes
> - The most important modifications will likely be the time and memory, which are found near the top of the script

### Protein Prediction & Searching
Since not all accessions and assemblies will have available protein FASTA files (.faa), it is preferable to generate a catalogue of protein sequences from each genome. The protein catalogue for each genome can then be searched against user-provided protein sequences (for each genome). <br>
**04_pyrodigal_annotations**
```
# Annotate genomes and predict protein-coding sequences
bash 04_pyrodigal_annotations.sh ../genomes/*.fna

# Optional SLURM script
sbatch 04_pyrodigal_annotations.slurm ../genomes/*.fna
```
**05_mmseqs2_search***
```
# Search a user-defined FASTA file of queries against proteins predicted from genomes
bash 05_mmseqs2_search.sh ../queries.faa ../results/pyrodigal_out/*.faa
bash 05_mmseqs2_search.sh --min-seq-id 0.7 --min-coverage 0.8 ../queries.faa ../results/pyrodigal_out/*.faa

# Optional SLURM script
sbatch 05_mmseqs2_search.slurm ../queries.faa ../results/pyrodigal_out/*.faa
sbatch 05_mmseqs2_search.slurm --min-seq-id 0.7 --min-coverage 0.8 ../queries.faa ../results/pyrodigal_out/*.faa
```
> [!NOTE]
> - Scripts in the ```slurm_scripts``` directory may need to be modified based on the number of genomes
> - The most important modifications will likely be the time and memory, which are found near the top of the script
