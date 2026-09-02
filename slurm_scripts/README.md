# SLURM Scripts
The scripts in this directory are meant for use in SLURM schedulers via the ```sbatch``` command. <br>
## Genome FASTA Preparation
Scripts ```01_genome_extraction.slurm``` and ```03_genome_preparation.slurm``` **do not require internet access**. <br>
They can be executed as follows:
```
# Must provide the taxon of interest to the script (according to GTDB taxonomy)
sbatch 01_genome_extraction.slurm 'g_Enterocloster'

# Notice there is no 02_genome_download.slurm script
# 02_genome_download.sh must be run on a cluster with internet access!

# No need to provide arguments to this script
sbatch 03_genome_preparation.slurm 
```

## Protein Prediction and Searching
