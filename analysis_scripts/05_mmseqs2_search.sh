#!/usr/bin/env bash

set -euo pipefail

echo "Running $0"
echo "This script searches a query FASTA file against subject FASTA file(s)."

if [ "$#" -lt 2 ]; then
    echo "Error: Invalid number of arguments."
    echo "Required: FASTA files of the query and subject(s)"
    echo "Usage: $0 <query_fasta> <subject_fasta(s)>"
    echo "Example: $0 queries.faa proteins/*.faa"
    exit 1
fi

# Assign command line argument for the query
query_fasta="$1"

# Check if the query file exists
if [[ ! -f "${query_fasta}" ]]; then
    echo "Error: Query FASTA file not found"
    exit 1
fi

# Get the path to the script directory and the project directory (bacteria_genome_mining)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(dirname "${script_dir}")"

# Create the output directory
out_dir="${project_dir}/results/mmseqs2_out"
mkdir -p "${out_dir}"

# Define the temporary directory for mmseqs2
tmp_dir="${project_dir}/tmp"
mkdir -p "${tmp_dir}"

# Set the number of CPUs, either based on the SLURM parameters or as a default of 1
threads="${SLURM_CPUS_PER_TASK:-1}"

# Check that mmseqs2 is available
if ! command -v mmseqs >/dev/null 2>&1; then
    echo "Error: MMseqs2 was not found."
    echo "Please activate an environment containing mmseqs2."
    exit 1
fi

# Print the parameters for this job
echo "==============================="
echo "Query FASTA: ${query_fasta}"
echo "Output directory: ${out_dir}"
echo "Temporary directory: ${tmp_dir}"
echo "Threads: ${threads}"
echo "mmseqs2: $(command -v mmseqs)"
echo "==============================="

# Assign the output format
out_format="query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qseq,tseq"

# Loop through the subject FASTA files (starting at position 2 all the way to the end of the positional arguments)
for subject_fasta in "${@:2}"; do
    # Check that the subject file exists
    if [[ ! -f "${subject_fasta}" ]]; then
        echo "Error: ${subject_fasta} file not found"
        exit 1
    fi
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
    # Define the output file naming format
    output_file="${out_dir}/${fasta_id}_mmseqs2.tsv"
    
    # Check if results file already exists
    if [ -f "${output_file}" ]; then
        echo "Results file for ${fasta_id} already exists. Skipping..."
        continue
    fi
    
    echo "Searching ${fasta_id} using mmseqs2"
    
    # Run the search (auto-detects the input fasta formats)
    mmseqs easy-search \
        "${query_fasta}" \
        "${subject_fasta}" \
        "${output_file}" \
        "${tmp_dir}" \
        --threads "$threads" \
        --format-output "${out_format}" \
        --min-seq-id 0.5 \
        -c 0.5
done

date
echo "mmseqs2 search finished"

#========================================================================
# Annotate the results tables and merge into a table of all and best hits
#========================================================================

# Check that Python is available
python_cmd="${PYTHON:-python3}"

if ! command -v "${python_cmd}" >/dev/null 2>&1; then
    echo "Error: Python executable not found: ${python_cmd}"
    exit 1
fi

# Check that pandas is available
if ! "${python_cmd}" -c "import pandas" >/dev/null 2>&1; then
    echo "Error: Python package 'pandas' is not available."
    echo "Please activate an environment containing pandas."
    exit 1
fi

# Add column headers based on the output format

export out_format
export out_dir
export project_dir

"${python_cmd}" << 'EOF'
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
metadata_path = (
    project_directory
    / "download_scripts"
    / "metadata"
    / "bac120_metadata_r232_acc.tsv"
)

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

EOF

echo "Finished mmseqs pipeline with annotations"
date
