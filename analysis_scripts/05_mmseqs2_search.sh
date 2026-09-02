#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script searches a query FASTA file against subject FASTA file(s)."

if [ "$#" -lt 2 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: FASTA files of the query and subject(s)"
    echo "Usage: $0 <query_fasta> <subject_fasta(s)>"
    echo
    echo "Example: $0 queries.fna proteins/*.fna"
    echo "Example: $0 queries.faa genomes/*.faa"
    exit 1
fi

# Assign command line argument for the query
query_fasta="$1"

current_dir=$(basename $PWD)

if [ $current_dir == "analysis_scripts" ]; then
    echo "Currently in ${current_dir}"
	out_dir="../mmseqs2_out"
	mkdir -p "${out_dir}"
elif [ $current_dir == "bacteria_genome_mining" ]; then
    echo "Currently in ${current_dir}"
    out_dir="mmseqs2_out"
	mkdir -p "${out_dir}"
elif [ -d "bacteria_genome_mining" ]; then
    echo "Currently in ${current_dir}"
    out_dir="bacteria_genome_mining/mmseqs2_out"
	mkdir -p "${out_dir}"
else
    echo "Could not resolve the path to bacteria_genome_mining"
    exit 1
fi

# Assign the output format
out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq,tseq"

# Loop through the subject FASTA files (starting at position 2 all the way to the end of the positional arguments)
for subject_fasta in "${@:2}"; do
	
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
	
    # Check if results file already exists
	if [ -f "${out_dir}/${fasta_id}_mmseqs2.tsv" ]; then
		echo "Results file for ${fasta_id} already exists. Skipping..."
		continue
	fi
	
	echo "Searching ${fasta_id} using mmseqs2"
	
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
import os, glob, re, fnmatch
from pathlib import Path

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
    pattern = r"^[Gg][Cc][AaFf]_[0-9]{9}\.[0-9]"
    accession = re.search(pattern, file_name).group(0)
    accession = accession.upper()
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

# Now combine the merged dfs with the metadata table used to get the accessions and assemblies
metadata_path = Path("bac120_metadata_r232.tsv")
if metadata_path.is_file():
    print("Merging with metadata")
    metadata_df = pd.read_csv(metadata_path, sep='\t')
    metadata_df = metadata_df[['accession', 'ncbi_assembly_name', 'gtdb_taxonomy', 'gtdb_representative', 'ncbi_isolate', 'ncbi_strain_identifiers', 'ncbi_isolation_source']]
    metadata_df['accession'] = metadata_df['accession'].str.replace(r'[RG][SB]_', '', regex=True)
    merged_metadata_df = pd.merge(merged_df, metadata_df, left_on='accession', right_on='accession')
else:
    print("Cannot find metadata table... exporting to TSV without metadata")

# Filter by best hit (for each target protein)
merged_metadata_df_bh = merged_metadata_df.loc[merged_metadata_df.groupby('target')['pident'].idxmax()]
merged_metadata_df_bh = merged_metadata_df_bh.reset_index(drop=True)

# Export the resulting files to TSV
merged_metadata_df.to_csv(f"{output_directory}/merged_mmseqs2.tsv", sep="\t", index=False)
merged_metadata_df_bh.to_csv(f"{output_directory}/merged_best_hits_mmseqs2.tsv", sep="\t", index=False)


EOF

echo "Finished mmseqs pipeline with annotations"
date
