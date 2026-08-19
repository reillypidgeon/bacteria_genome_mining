#!/usr/bin/env bash

#SBATCH --job-name=mmseqs2
#SBATCH --output=%x.out
#SBATCH --error=%x.err
#SBATCH --time=08:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4

set -euo pipefail

echo "Running $0"
echo "This script searches a query FASTA file against subject FASTA file(s)."

if [ "$#" -lt 2 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: FASTA files of the query and subject(s)"
    echo "Usage: $0 <query_fasta> <subject_fasta(s)>"
    echo
    echo "Example: $0 queries.fna genomes/*.fna"
    echo "Example: $0 queries.faa genomes/proteins/*.faa"
    exit 1
fi

module load StdEnv/2023 mmseqs2/17-b804f cudacore/.12.6.3

# Assign command line argument for the query
query_fasta="$1"

# Create an output directory
out_dir="mmseqs2_out"
mkdir -p "${out_dir}"

# Assign the output format
out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq,tseq"

# Loop through the subject FASTA files (starting at position 2 all the way to the end of the positional arguments)
for subject_fasta in "${@:2}"; do
    
    # Convert name to lowercase
    subject_fasta=$(echo "${subject_fasta}" | tr '[:upper:]' '[:lower:]')

    # Extract the fasta identity
    if [[ "${subject_fasta}" == *.fasta ]]; then
        fasta_id=$(basename "${subject_fasta}" .fasta)
    elif [[ "${subject_fasta}" == *.faa ]]; then
        fasta_id=$(basename "${subject_fasta}" .faa)
    elif [[ "${subject_fasta}" == *.fna ]]; then
        fasta_id=$(basename "${subject_fasta}" .fna)
    else
        fasta_id=$(basename "${subject_fasta}")
    fi
    
    # Run the search (auto-detects the input fasta formats)
    mmseqs easy-search \
        $query_fasta \
        $subject_fasta \
        "${out_dir}/${fasta_id}_mmseqs2.tsv" \
        tmp \
        --threads $SLURM_CPUS_PER_TASK \
        --format-output $out_format \
        --min-seq-id 0.5 \
        -c 0.5
done

date
echo "mmseqs2 search finished"

# Add column headers based on the output format
module load python/3.14.2 scipy-stack/2026a

export out_format
export out_dir

python3 << 'EOF'
import pandas as pd
import os
import glob
import re
import fnmatch

# Generate a list for the headers
output_format = os.environ.get('out_format')
output_format = output_format.split(",")

# Set the ouptout directory
output_directory = os.environ.get('out_dir')

print("Annotating output tables")

# Generate an empty list to populate
dfs = []

# Loop through the results tables
for file in glob.glob(f"{output_directory}/*_mmseqs2.tsv"):
    df = pd.read_csv(file, sep="\t", header=None, names = output_format, low_memory=False)
    file_name = os.path.basename(file)
    
    # Skip merged results if present from a previous execution of this script
    if fnmatch.fnmatch(file_name, "merged*mmseqs2.tsv"):
        print("Skipping merged results")
        continue
    
    # Extract the accession from the file_name and add to the dataframes
    print(f"Extracting the accession for {file_name}")
    pattern = r"^[Gg][Cc][AaFf]_[0-9]{9}\.1"
    accession = re.search(pattern, file_name).group(0)
    print(accession)
    
    # Check if the dataframe is empty
    if df.empty:
        print(f"Dataframe for {file_name} is empty")
        print("Adding a row")
        df["file_name"] = None
        df["accession"] = None
        # Add in the file_name in a single row
        df.loc[0] = {
            "file_name": file_name,
            "pident": 0.0,
            "target": f"NA for {accession}"
        }
    else:
        print(f"Dataframe for {file_name} contains hits")
        df["file_name"] = file_name
    
    df["accession"] = accession
    
    # Append the df to the list of dfs and go through the loop again
    print("Appending to the list of dfs")
    dfs.append(df)

# Merge the dataframes in dfs
merged_df = pd.concat(dfs, ignore_index=True)
merged_df = merged_df.reindex(sorted(merged_df.columns), axis=1)

# Reorder the columns according to an extended output_format list
output_format.extend(["accession", "file_name"])
merged_df = merged_df[output_format]

# Export the resulting file to a TSV
merged_df.to_csv(f"{output_directory}/merged_mmseqs2.tsv", sep="\t", index=False)

# Filter by best hit (for each target protein) and export to a TSV
merged_df_bh = merged_df.loc[merged_df.groupby('target')['pident'].idxmax()]
merged_df_bh = merged_df_bh.reset_index(drop=True)
merged_df_bh.to_csv(f"{output_directory}/merged_best_hits_mmseqs2.tsv", sep="\t", index=False)

EOF

echo "Finished mmseqs pipeline with annotations"
date
