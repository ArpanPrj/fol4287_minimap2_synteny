# Methods

## Study design

The chromosome-level RefSeq assembly of *Fusarium oxysporum* f. sp. *lycopersici* Fol4287 (`GCF_000149955.1`) is the reference. Four query assemblies are analyzed: Fo47 (`GCF_013085055.1`), FoCL57 (`GCA_000260155.3`), FoCotton (`GCA_000260175.2`), and FolD11 (`GCA_003977725.1`).

Fol4287 chromosomes 3, 6, 14, and 15 are classified as whole lineage-specific chromosomes. Remaining chromosomes are treated as core at the whole-chromosome level.

## Software environment

The workflow uses Minimap2 2.31, NCBI Datasets, SeqKit, Python, R, and `circlize`. `setup.sh` installs a pinned Miniforge bootstrap when needed. The author's first run solves `environment.yml` and exports a platform-specific explicit Conda lock containing exact package artifacts and SHA256 package hashes. Later runs use the committed explicit lock.

## Genome acquisition and preprocessing

Exact versioned accessions are defined in `config/genomes.tsv`. NCBI Datasets downloads each genomic FASTA. Fol4287 `NC_` records with chromosome labels are extracted; exactly 15 are required. Fo47 is required to contain 12 chromosome records for the detailed circular visualization. Derived chromosome FASTAs are written with fixed 60-base wrapping and LF line endings.

## Minimap2 whole-genome alignment

The 15-chromosome Fol4287 FASTA is the Minimap2 target/reference and each full query assembly is aligned separately. The fixed settings are `-x asm10 -c --secondary=no --seed 11 -t 1 -K 500M -I 8G`.

Raw PAF is stored only as a temporary intermediate under `tmp/minimap2/`.

## Canonical alignment representation

`scripts/02_canonicalize_paf.py` reads only the 12 mandatory PAF fields and ignores optional tags. The script writes a deterministic TSV containing query/reference identifiers, 0-based half-open coordinates, orientation, matching bases, alignment-block length, reference span, percent identity, and mapping quality. Rows are deterministically sorted and written with LF line endings. Percent identity uses Python `Decimal` arithmetic and explicit four-decimal rounding.

Because PAF coordinates are half-open, reference span is calculated as `ref_end - ref_start`.

## Chromosome coverage

For each query and Fol4287 chromosome, overlapping reference intervals are merged before counting covered bases. Percent aligned is `100 × unique aligned Fol4287 bp / Fol4287 chromosome length`.

Same- and opposite-orientation coverage are calculated separately. Weighted identity is calculated from total matching bases divided by total alignment-block length rather than averaging rounded block identities.

## Core versus lineage-specific summary

For every query, total reference length, unique aligned bases, percent aligned, median chromosome percent aligned, alignment-block count, and weighted mean identity are summarized separately for core and lineage-specific chromosome classes.

A second table summarizes mean, median, minimum, and maximum percent aligned for each Fol4287 chromosome across the four query genomes.

## Visualization

The primary multi-genome figure is a chromosome-by-query heatmap. A grouped bar plot compares core and lineage-specific coverage. A detailed Fol4287-versus-Fo47 circular plot is generated from canonical Minimap2 alignments. Only blocks with at least 50 kb Fol4287 reference span and at least 90% identity are displayed; these are visualization-only filters.

Fo47 chromosome VII is displayed as an accessory chromosome. Opposite alignment orientation is not automatically interpreted as a biological inversion.

## Reproducibility

`CHECKSUMS.txt` contains SHA256 hashes for every file under `data/` and `results/`. Raw PAF files, runtime logs, download archives, and other temporary files are excluded. After validation, the author copies the final manifest to `CHECKSUMS.reference.txt`. A reproducer regenerates the analysis and compares the new checksum manifest to that fixed reference.
