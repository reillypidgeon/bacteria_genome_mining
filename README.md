# bacteria_genome_mining
Repository for code snippets useful for genome mining of bacteria using known gene or protein sequences.

The goal is to have a single command that can download all genomes based on a string match to a GTDB phylogenetic level (e.g., "g__Enterocloster").
The tool would then search different queries (either protein or nucleotide FASTA files) against the downloaded genomes. I may integrate Prodigal at some point to make protein-protein searches possible.
