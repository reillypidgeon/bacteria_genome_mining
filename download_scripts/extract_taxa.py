#!/usr/bin/env python3

import pandas as pd
import os

taxon_string = os.environ.get('taxon')
metadata_dir = os.environ.get('metadata_dir')

print(f"Searching the metadata table for: {taxon_string}")
df = pd.read_csv(f"{metadata_dir}/bac120_metadata_r232_acc.tsv", sep='\t')
df_taxon = df[df['gtdb_taxonomy'].str.contains(taxon_string, case=False, na=False, regex=False)]
# Now select accession and ncbi_assembly_name columns and export without headers
df_genomes = df_taxon[['accession', 'ncbi_assembly_name']].copy()
# Replace spaces with underscores to avoid errors in later steps
df_genomes['ncbi_assembly_name'] = df_genomes['ncbi_assembly_name'].str.replace(' ', '_', regex=False)
file_name = f"genomes_{taxon_string}_r232.tsv".replace(" ", "_")
df_genomes.to_csv(f"{metadata_dir}/{file_name}", sep='\t', header=False, index=False)
