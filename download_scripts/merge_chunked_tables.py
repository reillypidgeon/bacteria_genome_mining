#!/usr/bin/env python3

import pandas as pd
import glob
import os

table_dir = os.environ.get('table_dir')
files = sorted(glob.glob(f"{table_dir}/bac120_metadata_r232_acc_*.tsv"))

# Check if files can be found
if not files:
    raise FileNotFoundError(f"No chunked metadata files found in {table_dir}")

# Read the tables
dfs = []
for file in files:
    df = pd.read_csv(file, sep='\t')
    dfs.append(df)

df_acc = pd.concat(dfs, ignore_index=True)
df_acc = df_acc.sort_values(by = 'accession', ignore_index = True)

# Write the output to a TSV file
df_acc.to_csv(f"{table_dir}/bac120_metadata_r232_acc.tsv", sep='\t', index=False)
