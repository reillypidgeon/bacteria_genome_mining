#!/usr/bin/env python3

import pandas as pd
import os, glob, re, fnmatch
from pathlib import Path

# Generate a list for the headers
output_format = os.environ.get('out_format').split(",")

# Set the output directory and project directory
output_directory = os.environ.get('out_dir')
project_directory = os.environ.get('project_dir')

print("Annotating output tables")

# Find mmseqs2 result files
output_path = Path(output_directory)
result_files = sorted(output_path.glob("*_mmseqs2.tsv"))

# Skip merged results from previous executions
result_files = [
    file for file in result_files
    if file.name not in {
        "merged_mmseqs2.tsv",
        "merged_best_hits_mmseqs2.tsv",
    }
]

if not result_files:
    raise FileNotFoundError(
        f"No mmseqs2 result files found in {output_directory}"
    )

# Generate an empty list to populate
dfs = []

# Loop through the results tables
for file in result_files:
    file_name = file.name
    print(f"Processing {file_name}")
    
    # Handle empty result files
    if file.stat().st_size == 0:
        print(f"Dataframe for {file_name} is empty")
        df = pd.DataFrame(columns=output_format)
    else:
        df = pd.read_csv(file, sep="\t", header=None, names=output_format, low_memory=False)
    
    # Extract the accession from the filename
    pattern = r"^[Gg][Cc][AaFf]_[0-9]{9}\.[0-9]+"
    match = re.search(pattern, file_name)
    
    if match is None:
        raise ValueError(
            f"Could not extract NCBI accession from filename: {file_name}"
        )
    accession = match.group(0).upper()
    print(f"Accession: {accession}")
    
    # Add a placeholder row if there are no hits
    if df.empty:
        print("No hits found. Adding placeholder row.")
        df.loc[0, "pident"] = 0.0
        df.loc[0, "target"] = f"NA for {accession}"
    else:
        print(f"Found {len(df)} hits")
    
    # Add file and accession information
    df["accession"] = accession
    df["file_name"] = file_name
    dfs.append(df)

# Merge the dataframes in dfs
merged_df = pd.concat(dfs, ignore_index=True)

# Now (optionally) combine the merged dfs with the metadata table
metadata_path = Path(f"{project_directory}/download_scripts/metadata/bac120_metadata_r232_acc.tsv")

if metadata_path.is_file():
    print("Merging with metadata")
    metadata_df = pd.read_csv(metadata_path, sep='\t')
    metadata_df = metadata_df[['accession', 'ncbi_assembly_name', 'gtdb_taxonomy', 'gtdb_representative', 'ncbi_isolate', 'ncbi_strain_identifiers', 'ncbi_isolation_source']]
    metadata_df['accession'] = metadata_df['accession'].str.replace(r'[RG][SB]_', '', regex=True)
    merged_metadata_df = pd.merge(merged_df, metadata_df, on='accession', how='left')
else:
    print("Cannot find metadata table... exporting to TSV without metadata")
    merged_metadata_df = merged_df.copy()

# Filter by best hit (for each target protein)
merged_metadata_df_bh = merged_metadata_df.loc[merged_metadata_df.groupby('target')['pident'].idxmax()]
merged_metadata_df_bh = merged_metadata_df_bh.reset_index(drop=True)

# Export the resulting files to TSV
merged_metadata_df.to_csv(f"{output_directory}/merged_mmseqs2.tsv", sep="\t", index=False)
merged_metadata_df_bh.to_csv(f"{output_directory}/merged_best_hits_mmseqs2.tsv", sep="\t", index=False)
