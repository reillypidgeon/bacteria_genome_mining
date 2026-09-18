### Examples

This directory contains the queries.faa input and the output (results directory) after running the `full_analysis/bgm.sh` script with the following input:
```
bash bgm.sh ../examples/queries.faa "s__Enterocloster asparagiformis"
```
The analysis was run with default parameters (`--min-seq-id 0.5 --min-coverage 0.5 --search-type 0 --search-against protein`), which could be changed by adding flags before the query FASTA file. For example:
```
bash bgm.sh --min-seq-id 0.9 --min-coverage 0.8 --search-type 0 --search-against protein ../examples/queries.faa "s__Enterocloster asparagiformis"
```
>[!NOTE]
> The `results/pyrodigal_out` was omitted from this directory due to file size constraints.
