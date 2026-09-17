# Bacteria Genome Mining (BGM)

## Purpose
Find homologous sequences (or lack thereof) in genomes for a given taxonomic level, based on GTDB taxonomy (release 232). <br>
<br>
Useful for looking at the taxonomic distribution of genes or proteins and strain-level variation within species.

> [!IMPORTANT]
> - Many of the scripts in this repository are formatted to run as SLURM (scheduled) jobs and are found in the ```slurm_scripts``` directory
> - Some scripts (```download_scripts/02_genome_download.sh```) will require internet access to work, so they cannot be run in an interactive or scheduled job that has restricted internet access (e.g. in Digital Research Alliance of Canada clusters like Narval)<br>

## Approach
- Download genome FASTA files (.fna) from the NCBI using GTDB (release 232) taxonomy based on user input
- Annotate FASTA files and predict protein-coding sequences using [pyrodigal](https://github.com/althonos/pyrodigal)
- Search for homologous sequences in the newly-created protein catalogues using [mmseqs2](https://github.com/soedinglab/MMseqs2)
- Output tab-separated tables of all hits and best hits for a given protein within a genome

## Dependencies
The following tools and packages need to be installed for the scripts in this repository to work
- Python3
- [GNU parallel](https://doi.org/10.5281/zenodo.7958356)
- [pandas](https://github.com/pandas-dev/pandas): Install by running `pip install pandas` (unless it's available via the scipy-stack in your cluster)
- [scipy](https://github.com/scipy/scipy): Install by running `pip install scipy` (unless it's available via the scipy-stack in your cluster)
- [pyrodigal](https://github.com/althonos/pyrodigal): Install by running `pip install pyrodigal`
- [mmseqs2](https://github.com/soedinglab/MMseqs2): Install by following instructions on the mmseqs2 GitHub page (multiple options)

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
On a HPC cluster like those from the Digital Research Alliance of Canada, you must first load the modules. <br>
These steps are already included in the slurm-ready scripts in the slurm_scripts directory; however, modules will need to be loaded in interactive jobs beforehand. <br>

```
# Loading modules
module load python scipy-stack mmseqs2

# In the slurm_scripts directory, the 04_pyrodigal_annotations.slurm script creates a virtual environment
# Then installs pyrodigal using requirements in slurm_scripts/pyrodigal_requirements.txt
module load python

virtualenv --no-download "${SLURM_TMPDIR}/pyrodigal_env"
source "${SLURM_TMPDIR}/pyrodigal_env/bin/activate"

pip install --no-index --upgrade pip
pip install --no-index -r "${project_dir}/slurm_scripts/pyrodigal_requirements.txt"
```

## Usage
### User-Defined Input
Most of the analysis requires minimal user input (unless you're running scripts separately). The user absolutely needs to provide 2 inputs:
- A FASTA file of sequences of interest, e.g. `my_favourite_proteins.faa` or `my_favourite_genes.fna`
- At least one GTDB-formatted taxon of interest, e.g. `"f__Lachnospiraceae"` or `"s__Enterocloster bolteae"` (make sure to quote the taxon for species due to the space)

Optional inputs relate to the mmseqs2 search, which include the following flags:
- `--min-seq-id`: Minimum sequence identity cutoff (FLOAT between 0-1 | Default: `0.5`)
- `--min-coverage`: Minimum sequence coverage cutoff (FLOAT between 0-1 | Default: `0.5`)
- `--search-type`: mmseqs2 search type (INT between 0-4 | Default: `0` (automatic) for protein queries and `3` for nucleotide queries). 
- `--search-against`: The type of pyrodigal output to search against when using directories as inputs for mmseqs2 (STRING equal to either `protein` or `gene` | Default: `protein`)
>[!IMPORTANT]
> These optional flags must be placed **before** the query FASTA file in the `full_analysis/bgm.sh`, `analysis_scripts/05_mmseqs2_search.sh`, and `slurm_scripts/05_mmseqs2_search.slurm`

### Full Analysis
This analysis can be run by calling a single script or by calling individual scripts (see Genome FASTA Preparation & Downloading and Protein Prediction & Searching sections below for individual steps). <br>
To run the analysis on a local machine or in an interactive SLURM job (with internet access), you can call the following script (located in the full_analysis directory): <br>
```
bash bgm.sh ../queries.faa "g__Enterocloster" "s__Hungatella hathewayi"
```
Optional flags can be added to change default parameters for the mmseqs easy-search
```
# Flags must come before the query FASTA file and taxa of interest!
bash bgm.sh --min-seq-id 0.7 --min-coverage 0.8 --search-type 3 --search-against gene ../queries.fna "g__Enterocloster" "s__Hungatella hathewayi"
```
>[!NOTE]
> The default parameters for the `mmseqs easy-search` are `--min-seq-id 0.5 --min-coverage 0.5 --search-type 0`<br>
> Search types (for mmseqs2) are defined as follows: `0` (automatic), `1` (amino acid), `2` (translated), `3` (nucleotide), `4` (translated nucleotide alignment)
> In both analysis scripts (pyrodigal and mmseqs2), directories containing FASTA files can be specified instead of actual files
> When specifying a directory, the `mmseqs easy-search` search is performed against pyrodigal protein annotations (`--search-against protein` flag); however, this could be changed by using the `--search-against gene` flag <br>

### Examples
The ```examples``` directory contains a queries.faa file and a [short tutorial](examples/README.md) on how to run the full analysis using the script in the ```full_analysis``` directory. <br>
There is also example output in ```examples/results``` that can be used as a reference for your own tests.

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
# Provide either the FASTA files as input or the directory that contains these FASTA (.fna) files
bash 04_pyrodigal_annotations.sh ../genomes/*.fna
bash 04_pyrodigal_annotations.sh ../genomes/

# Optional SLURM script
sbatch 04_pyrodigal_annotations.slurm ../genomes/*.fna
sbatch 04_pyrodigal_annotations.slurm ../genomes/
```
**05_mmseqs2_search**
```
# Search a user-defined FASTA file of queries against proteins predicted from genomes
bash 05_mmseqs2_search.sh ../queries.faa ../results/pyrodigal_out/*.faa
bash 05_mmseqs2_search.sh --min-seq-id 0.7 --min-coverage 0.8 ../queries.faa ../results/pyrodigal_out

# Optional SLURM script
sbatch 05_mmseqs2_search.slurm ../queries.faa ../results/pyrodigal_out/*.faa
sbatch 05_mmseqs2_search.slurm --min-seq-id 0.7 --min-coverage 0.8 ../queries.faa ../results/pyrodigal_out
```
> [!NOTE]
> - Scripts in the ```slurm_scripts``` directory may need to be modified based on the number of genomes
> - The most important modifications will likely be the time and memory, which are found near the top of the script
