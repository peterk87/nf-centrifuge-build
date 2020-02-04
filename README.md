# Basic [Nextflow] workflow for building a [Centrifuge] index

## Usage

- Install [Nextflow][] (with [Conda][] install from the [Bioconda][] channel: `$ conda install -c bioconda nextflow`)
- Ensure that at least Nextflow 19.10.0 is installed (`$ nextflow -version`)
- [Optional] Install [Singularity][] (nice for HPC and reproducibility)
- Download/create NCBI Taxonomy `nodes.dmp` and `names.dmp` files (e.g. `$ centrifuge-download -o taxonomy taxonomy`)
- Concatenate all your FASTA sequences into one FASTA file
- Create a mapping file of FASTA sequence IDs to NCBI Taxonomy IDs with one entry per line, i.e. `{seq_id}\t{taxid}`


Basic example usage for local execution with a FASTA file `seqs.fa`, sequence IDs to taxids in `acc2taxid.map`, using [Singularity] by specifying the `singularity` profile and outputting results to `centrifuge-build-results`:

```bash
nextflow run peterk87/nf-centrifuge-build \
  -profile singularity \
  --fasta seqs.fa \
  --taxonomy_nodes taxonomy/nodes.dmp \
  --taxonomy_names taxonomy/names.dmp \
  --acc2taxid acc2taxid.map \
  --outdir centrifuge-build-results \
  --cpus 32
  --memory '64 GB'
```


### [Slurm] execution


Create a [sbatch] Bash script (e.g. `nf-centrifuge-build.sh`). Edit the `{{PARTITION_NAME}}` to match the partition or queue you'd like to submit your jobs to:

```bash
#!/usr/bin/env bash

nextflow run peterk87/nf-centrifuge-build \
  -profile slurm,singularity \
  --queue {{PARTITION_NAME}} \
  --fasta nt.fa \
  --taxonomy_nodes taxonomy/nodes.dmp \
  --taxonomy_names taxonomy/names.dmp \
  --acc2taxid acc2taxid.map \
  --outdir centrifuge-build-results \
  --memory '512 GB'
```


```bash
sbatch -p {{PARTITION_NAME}} \
  -c 4 \
  --mem=4G \
  nf-centrifuge-build.sh
```

## Building NCBI nt [Centrifuge] DB

The instructions on the [Centrifuge Manual] are slightly out-of-date and have you create a map of GI to taxid when new versions of the nt DB use accession numbers.

**BEWARE:** The nt DB is very large at 263GB as of 2020-01-30 with 55,346,425 sequences. 

```bash
# download the current NBCI nt BLAST DB sequences FASTA
wget ftp://ftp.ncbi.nih.gov/blast/db/FASTA/nt.gz
pigz -d -c nt.gz > nt.fa
# get the sequence headers
rg -N -o '^>\S+' nt.fa > nt-header
# or you could use grep, but it's much slower than ripgrep (417s vs 50s)
# $ grep -o -P '^>\S+' nt.fa > nt-header
# dowload accession to taxid file
wget https://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz
gunzip nucl_gb.accession2taxid
```

Using a Python script to get accessions from `nt.fa` and taxids from `nucl_gb.accession2taxid`, writing to a file `accver2taxid.map`:

```python
#!/usr/bin/env python

with open('nt-headers') as f:
    accs = {}
    for l in f:
        orig_accver = l[1:l.find(' ')]
        dot_idx = orig_accver.find('.')
        acc = orig_accver if dot_idx == -1 else orig_accver[:dot_idx]
        accs[acc] = orig_accver

with open('nucl_gb.accession2taxid') as f:
    acc_taxid = {}
    for l in f:
        acc, accver, taxid, gi = l.split('\t')
        if acc in accs:
            acc_taxid[accs[acc]] = taxid

with open('accver2taxid.map', 'w') as fout:
    for acc, taxid in acc_taxid.items():
        fout.write(f'{acc}\t{taxid}\n')
```

Downloaded taxonomy information with:

```bash
$ centrifuge-download -o taxonomy taxonomy
```

Executed workflow with:

```bash
nextflow run peterk87/nf-centrifuge-build \
  -profile slurm,singularity \
  --queue {{PARTITION_NAME}} \
  --fasta nt.fa \
  --taxonomy_nodes taxonomy/nodes.dmp \
  --taxonomy_names taxonomy/names.dmp \
  --acc2taxid acc2taxid.map \
  --outdir centrifuge-build-results \
  --cpus 32 \
  --memory '512 GB'
```


[Nextflow]: https://www.nextflow.io/
[Centrifuge]: https://ccb.jhu.edu/software/centrifuge/manual.shtml
[Conda]: https://conda.io/en/latest/
[Bioconda]: https://bioconda.github.io/
[Singularity]: https://sylabs.io/guides/3.5/user-guide/
[Slurm]: https://slurm.schedmd.com/
[sbatch]: https://slurm.schedmd.com/sbatch.html