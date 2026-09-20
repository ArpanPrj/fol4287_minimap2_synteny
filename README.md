# Fol4287 five-genome synteny — Minimap2 version

This is a reproducible, laptop-scale comparative-genomics workflow for asking a simple biological question: **are the whole lineage-specific chromosomes of *Fusarium oxysporum* f. sp. *lycopersici* Fol4287 less conserved than its core chromosomes across a small panel of other *F. oxysporum* genomes?**

This version uses **Minimap2**, not MUMmer/`dnadiff`. The workflow downloads the genomes, prepares the chromosome-level reference, runs the alignments, converts the raw PAF output into deterministic tab-separated tables, summarizes chromosome conservation, makes the figures, and generates SHA256 checksums.

## Just want to run it?

No problem. Clone the repository and enter the project folder:

```bash
git clone https://github.com/ArpanPrj/fol4287_minimap2_synteny.git
cd fol4287_minimap2_synteny
```

Then run the whole workflow with one command:

```bash
bash run_all.sh
```

That is it. You do **not** need to install Conda first. `setup.sh`, which is called automatically by `run_all.sh`, bootstraps the software environment for you.

On Windows, run the project inside **WSL Ubuntu**, not PowerShell. For better performance, keep the repository somewhere under your Linux home directory, such as `~/Coursework/`, rather than under `/mnt/c/` or `/mnt/d/`.

## Okay, it ran. How do I check whether it is reproducible?

First, confirm that the files produced in the current run actually match the hashes written in `CHECKSUMS.txt`:

```bash
sha256sum -c CHECKSUMS.txt
```

Every line should end in:

```text
OK
```

That tells you the checksum manifest matches the files currently on disk.

To test whether the workflow reproduces the **published reference run**, run:

```bash
bash scripts/verify_reference_checksums.sh
```

If everything is byte-identical, you should see:

```text
PASS: all checksummed data and outputs are byte-identical to the reference run.
```

That is the strongest simple answer to the question, “Did I reproduce the submitted result?”

You can also test repeatability by running the complete workflow twice on the same machine:

```bash
bash run_all.sh
cp CHECKSUMS.txt /tmp/CHECKSUMS.run1.txt

bash run_all.sh
diff -u /tmp/CHECKSUMS.run1.txt CHECKSUMS.txt
```

If `diff` prints **nothing**, the two runs produced byte-identical checksummed data and results.

So, in short:

- `sha256sum -c CHECKSUMS.txt` → checks whether the current files match the current manifest.
- `bash scripts/verify_reference_checksums.sh` → checks whether the current run matches the fixed published reference manifest.
- two-run `diff` → checks whether the workflow repeats byte-for-byte on the same setup.

If the verification script prints `PASS`, then for the files included in the checksum manifest, the run is byte-reproducible relative to the published reference.

## Want to know more? Let’s dive deep.

The rest of this README explains exactly what the project does, where the data come from, what every script is responsible for, how the Minimap2 output is made deterministic, how chromosome coverage is calculated, and what every major output means.

---

## Biological question

The project asks:

> **Are Fol4287 lineage-specific chromosomes consistently less conserved than core chromosomes across a small, diverse panel of *Fusarium oxysporum* genomes?**

At the whole-chromosome level, Fol4287 chromosomes **3, 6, 14, and 15** are classified here as lineage-specific. Chromosomes **1, 2, 4, 5, and 7–13** are classified as core.

This is deliberately a **whole-chromosome classification**. It does not mean every base of a chromosome classified as core is necessarily core sequence. In particular, chromosomes 1 and 2 can contain lineage-specific regions even though they are not classified here as wholly lineage-specific chromosomes.

## Genome panel

The exact versioned assembly accessions are stored in `config/genomes.tsv`.

| Short name | Versioned assembly | Biological context | Role |
|---|---|---|---|
| Fol4287 | `GCF_000149955.1` | tomato wilt | reference |
| Fo47 | `GCF_013085055.1` | endophyte/biocontrol | query; detailed Circos comparison |
| FoCL57 | `GCA_000260155.3` | tomato crown/root rot | query |
| FoCotton | `GCA_000260175.2` | cotton wilt | query |
| FolD11 | `GCA_003977725.1` | tomato wilt | query |

The workflow downloads these exact assembly versions instead of using unversioned accessions.

## Big-picture workflow

The analysis follows this path:

```text
exact NCBI assembly accessions
          ↓
NCBI Datasets downloads genomic FASTA
          ↓
Fol4287 chromosome-only reference FASTA
          ↓
Minimap2 whole-genome alignment
          ↓
raw PAF files in tmp/
          ↓
canonical deterministic pairwise TSV files
          ↓
unique Fol4287 chromosome coverage calculations
          ↓
core vs lineage-specific summaries
          ↓
heatmap + grouped bar plot + Fo47 Circos plot
          ↓
SHA256 checksum manifest
```

The raw Minimap2 PAF files are treated as temporary external-program output. The stable pairwise alignment products used by the scientific analysis are the canonical TSV files written by `scripts/02_canonicalize_paf.py`.

## Why Minimap2?

Minimap2 provides genome-scale assembly-to-assembly alignment and emits PAF, a compact tabular alignment format. This project fixes the alignment settings across all four query genomes and then immediately converts the raw PAF into a project-controlled deterministic representation.

The fixed alignment settings are stored in `config/parameters.sh`:

```text
preset:          asm10
base alignment:  -c
secondary hits:  disabled
seed:            11
threads:         1
mini-batch:      500M
index batch:     8G
```

The effective command for each query is:

```bash
minimap2 \
    -x asm10 \
    -c \
    --secondary=no \
    --seed 11 \
    -t 1 \
    -K 500M \
    -I 8G \
    data/analysis/Fol4287.chromosomes.fna \
    data/raw/QUERY.fna
```

The same command structure and the same parameter values are used for every query genome.

## Why canonicalize the PAF output?

The raw PAF is useful as an external-program intermediate, but the project does not rely on its incidental line order or optional tags for checksumming.

Instead, `scripts/02_canonicalize_paf.py` reads the **12 mandatory PAF columns**, ignores optional tags, derives the small number of fields needed for this project, sorts all alignments using a fixed key, formats percent identity consistently, and writes LF-terminated TSV output.

The resulting files are:

```text
results/pairwise_alignments/Fol4287_vs_Fo47.tsv
results/pairwise_alignments/Fol4287_vs_FoCL57.tsv
results/pairwise_alignments/Fol4287_vs_FoCotton.tsv
results/pairwise_alignments/Fol4287_vs_FolD11.tsv
```

Each canonical row contains:

```text
query_genome
query_id
query_length_bp
query_start_0based
query_end_0based
ref_id
ref_length_bp
ref_start_0based
ref_end_0based
orientation
matching_bases
alignment_block_length_bp
ref_span_bp
percent_identity
mapping_quality
```

These canonical TSV files, rather than the raw PAF files, are the alignment inputs used by the downstream summary code.

## A note about coordinates

PAF coordinates are **0-based and half-open**.

For an interval from 100 to 200:

```text
length = 200 - 100 = 100 bp
```

There is no `+1` in the interval-length calculation.

That convention is respected throughout the Minimap2 summary code.

## Data organization

The repository itself does not store the large public genomic FASTAs. They are generated automatically when the pipeline runs.

### `data/raw/`

Contains the complete genomic FASTA downloaded for each assembly:

```text
data/raw/Fol4287.fna
data/raw/Fo47.fna
data/raw/FoCL57.fna
data/raw/FoCotton.fna
data/raw/FolD11.fna
```

These are the complete query inputs used for alignment.

### `data/analysis/`

Contains the chromosome-only FASTAs generated from the downloaded data:

```text
data/analysis/Fol4287.chromosomes.fna
data/analysis/Fo47.chromosomes.fna
```

`Fol4287.chromosomes.fna` contains the 15 Fol4287 chromosome records and is the Minimap2 target/reference sequence set.

`Fo47.chromosomes.fna` contains the 12 Fo47 chromosome records and is used to connect Fo47 sequence IDs with chromosome labels for the detailed circular visualization.

## How chromosome coverage is calculated

For a given query genome, all canonical alignment intervals that fall on one Fol4287 chromosome are collected.

Because different alignment blocks may overlap on the Fol4287 coordinate system, the pipeline **merges overlapping intervals before counting aligned bases**. This prevents a reference base from being counted more than once.

The main chromosome-level measure is:

```text
percent aligned =
100 × unique aligned Fol4287 reference bp / Fol4287 chromosome length
```

For each Fol4287 chromosome and each query genome, the workflow records:

- chromosome length;
- unique aligned Fol4287 bases;
- percent of the Fol4287 chromosome aligned;
- number of canonical alignment blocks;
- weighted mean nucleotide identity;
- largest individual reference span;
- unique aligned bases in the same orientation;
- unique aligned bases in the opposite orientation.

## How identity is calculated

For an individual canonical alignment block:

```text
percent identity =
100 × matching bases / alignment block length
```

For chromosome-level or class-level summaries, identity is calculated from the summed matching-base counts divided by the summed alignment-block lengths. This avoids averaging already-rounded percentages.

## Alignment orientation

PAF strand `+` is recorded as:

```text
same
```

PAF strand `-` is recorded as:

```text
opposite
```

`opposite` describes the coordinate orientation of the alignment. It is **not automatically interpreted as a biological inversion**, because assemblies or individual contigs/scaffolds can themselves be stored in different orientations.

## Core versus lineage-specific summaries

The tracked classification table is:

```text
config/fol4287_chromosome_classes.tsv
```

The lineage-specific chromosomes are:

```text
3
6
14
15
```

For each query genome, the pipeline separately summarizes the Fol4287 core and lineage-specific compartments, reporting:

- number of chromosomes;
- total Fol4287 sequence length;
- unique aligned bases;
- total percent aligned;
- median chromosome percent aligned;
- number of alignment blocks;
- weighted mean identity.

The resulting table is:

```text
results/core_vs_lineage_specific_by_query.tsv
```

## Across-query chromosome summary

The workflow also asks how consistently each individual Fol4287 chromosome is represented across the four query genomes.

For every Fol4287 chromosome it reports:

- mean percent aligned across queries;
- median percent aligned across queries;
- minimum percent aligned;
- maximum percent aligned.

The output is:

```text
results/chromosome_across_query_summary.tsv
```

## Detailed Fo47 Circos-style figure

The multi-genome comparison is summarized with a heatmap and grouped bar plot. A ribbon-level circular figure is retained only for Fol4287 versus Fo47 so the visualization remains readable.

The detailed plot uses:

```text
results/fo47_circos_links.tsv
```

Only blocks satisfying both display thresholds are drawn:

```text
reference span ≥ 50,000 bp
percent identity ≥ 90%
```

These are **visualization thresholds only**. They do not determine the chromosome percentages in the main quantitative analysis.

Fo47 chromosome VII is displayed as an accessory chromosome. Accessory status is not treated as equivalent to pathogenicity.

## Main scientific outputs

The most important generated files are:

```text
results/pairwise_alignments/
results/pairwise_summary.tsv
results/multigenome_chromosome_synteny.tsv
results/percent_aligned_matrix.tsv
results/core_vs_lineage_specific_by_query.tsv
results/chromosome_across_query_summary.tsv
results/fo47_circos_links.tsv
results/fo47_circos_filter_summary.tsv
results/Fol4287_multigenome_heatmap.svg
results/core_vs_lineage_specific_by_query.svg
results/Fol4287_vs_Fo47_circos.svg
results/software_versions.tsv
CHECKSUMS.txt
```

### `results/pairwise_alignments/`

Canonical Minimap2 alignment tables for all four query genomes.

### `results/pairwise_summary.tsv`

A compact whole-reference summary for each query genome.

### `results/multigenome_chromosome_synteny.tsv`

The detailed long-form table with one row for every query × Fol4287 chromosome combination.

### `results/percent_aligned_matrix.tsv`

A compact chromosome × query matrix used directly for the heatmap.

### `results/core_vs_lineage_specific_by_query.tsv`

The direct core-versus-lineage-specific comparison for each query genome.

### `results/chromosome_across_query_summary.tsv`

Each Fol4287 chromosome summarized across all four queries.

### `results/Fol4287_multigenome_heatmap.svg`

The main chromosome-by-query visualization.

### `results/core_vs_lineage_specific_by_query.svg`

The grouped comparison of core versus lineage-specific Fol4287 sequence conservation.

### `results/Fol4287_vs_Fo47_circos.svg`

The detailed chromosome-scale Fol4287-versus-Fo47 alignment visualization.

## Reproducible software environment

`environment.yml` describes the requested software stack, including:

```text
Python
Minimap2
NCBI Datasets
SeqKit
R
circlize
Ubuntu font package
```

On the author's first validated run, `setup.sh` creates a platform-specific **explicit Conda lock**, for example:

```text
environment-linux-64.lock.txt
environment-linux-64.source.sha256
```

The explicit lock is important because it records the exact package artifacts used for the validated reference environment rather than asking a later user to solve the environment again from broad version requirements.

`results/software_versions.tsv` is copied into the result set and therefore included in the checksum manifest.

## Why is Minimap2 run with one thread?

The project is optimized for reproducibility rather than maximum speed. The alignment worker count is explicitly fixed to:

```text
-t 1
```

The seed and batch parameters are also explicit rather than left to implicit run-time choices.

## Why is the font pinned?

The R figures are written as SVG files. Font substitution can change SVG bytes even when the underlying data are identical.

The environment therefore includes the Ubuntu font package, and the R scripts explicitly use:

```text
family = "Ubuntu"
```

This reduces one source of graphics-level variability when reproducing the workflow on the intended Linux/WSL platform.

## Checksums

`scripts/06_checksums.sh` finds every regular file under:

```text
data/
results/
```

sorts the file paths using the C locale, computes SHA256 for each one, writes:

```text
CHECKSUMS.txt
```

and immediately verifies the new manifest.

Files under these locations are deliberately not part of the scientific checksum set:

```text
tmp/
logs/
```

That means temporary raw PAF files, download packages, and runtime logs do not determine whether the scientific result reproduced.

## `CHECKSUMS.txt` versus `CHECKSUMS.reference.txt`

These two files have different purposes.

### `CHECKSUMS.txt`

Generated fresh by the current run.

### `CHECKSUMS.reference.txt`

A fixed copy of the checksum manifest from the final validated reference run.

After the author completes the final run and confirms it is correct:

```bash
bash scripts/set_reference_checksums.sh
```

creates the fixed reference file.

A reproducer later runs:

```bash
bash scripts/verify_reference_checksums.sh
```

which compares the current `CHECKSUMS.txt` to the fixed `CHECKSUMS.reference.txt`.

## Scripts — what each one does

The code itself is heavily annotated, but here is the map of the workflow.

### `setup.sh`

Bootstraps the software stack. It detects the operating system and architecture, installs the pinned Miniforge release when needed, creates the analysis environment, creates or consumes the platform-specific explicit Conda lock, and writes software-version provenance.

### `run_all.sh`

The master entry point. It runs setup, deletes previously generated scientific data/results so the run starts cleanly, recreates the required directories, runs Steps 1–6 in order, verifies required outputs, and reports the elapsed wall-clock runtime.

### `scripts/common.sh`

Shared deterministic runtime initialization. It sets the project root, C locale, UTC timezone, deterministic Python settings, controlled R startup behavior, single-threaded numerical-library settings, activates the project environment, and defines a cross-platform SHA256 helper.

### `scripts/01_download_genomes.sh`

Reads `config/genomes.tsv`, downloads each exact assembly with NCBI Datasets, extracts the genomic FASTA, writes stable short-name FASTA paths, calculates SeqKit statistics, and calls the FASTA parser.

### `scripts/01_parse_genomes.py`

Parses the downloaded FASTAs, records assembly structure, identifies the Fol4287 and Fo47 chromosome records, writes deterministic chromosome-only FASTAs, and generates chromosome metadata tables.

### `scripts/02_run_minimap2.sh`

Runs the fixed Minimap2 alignment command once for every query genome. Raw PAF files are placed under `tmp/minimap2/`, then each PAF is passed immediately to the canonicalization script.

### `scripts/02_canonicalize_paf.py`

Turns external Minimap2 PAF output into the stable scientific alignment representation. It validates the mandatory fields, converts coordinates to integers, derives orientation/reference span/identity, deterministically sorts rows, and writes the canonical TSV.

### `scripts/03_summarize_multigenome.sh`

Loads the shared environment and analysis parameters, exports the visualization thresholds to Python, calls the quantitative summary script, and confirms that all expected summary tables were produced.

### `scripts/03_summarize_multigenome.py`

The main quantitative analysis. It parses the canonical alignment tables, merges overlapping Fol4287 intervals, calculates chromosome coverage and identity summaries, creates the chromosome × query matrix, summarizes core versus lineage-specific chromosomes, creates the across-query summary, and prepares the filtered Fo47 Circos link table.

### `scripts/04_plot_summary.sh`

Runs the main summary plotting script and confirms both SVGs were created.

### `scripts/04_plot_summary.R`

Creates the Fol4287 chromosome conservation heatmap and the grouped core-versus-lineage-specific conservation plot.

### `scripts/05_plot_circos.sh`

Loads the plotting thresholds and runs the detailed Fol4287-versus-Fo47 circular visualization.

### `scripts/05_plot_circos.R`

Reads the chromosome metadata and filtered link table, orders the chromosomes explicitly, assigns biological colors, draws the chromosome sectors and alignment ribbons, and writes the final Circos-style SVG.

### `scripts/06_checksums.sh`

Builds and verifies the SHA256 manifest for every file under `data/` and `results/`.

### `scripts/set_reference_checksums.sh`

Copies the validated current `CHECKSUMS.txt` to `CHECKSUMS.reference.txt`. Run this only when establishing the final reference run.

### `scripts/verify_reference_checksums.sh`

Compares a newly generated checksum manifest against the fixed reference manifest. A successful byte-identical reproduction prints `PASS`.

## Configuration files

### `config/genomes.tsv`

Defines the exact genome panel, accessions, roles, biological context labels, and Circos selection.

### `config/fol4287_chromosome_classes.tsv`

Defines the whole-chromosome Fol4287 core/lineage-specific classification used by the analysis.

### `config/parameters.sh`

Contains the reference name, Circos query, all fixed Minimap2 settings, and the visualization thresholds.

### `config/bootstrap.sh`

Defines the pinned Miniforge version and the external software-cache locations.

### `environment.yml`

Declares the software required to establish the exact locked environment.

## Project layout

```text
CBC_2026_Week5_Minimap2/
├── README.md
├── METHODS.md
├── environment.yml
├── setup.sh
├── run_all.sh
├── CHECKSUMS.txt                    # generated after a run
├── CHECKSUMS.reference.txt          # fixed after final validation
├── environment-linux-64.lock.txt    # generated first time, then committed
├── environment-linux-64.source.sha256
├── config/
│   ├── bootstrap.sh
│   ├── genomes.tsv
│   ├── parameters.sh
│   └── fol4287_chromosome_classes.tsv
├── scripts/
│   ├── common.sh
│   ├── 01_download_genomes.sh
│   ├── 01_parse_genomes.py
│   ├── 02_run_minimap2.sh
│   ├── 02_canonicalize_paf.py
│   ├── 03_summarize_multigenome.sh
│   ├── 03_summarize_multigenome.py
│   ├── 04_plot_summary.sh
│   ├── 04_plot_summary.R
│   ├── 05_plot_circos.sh
│   ├── 05_plot_circos.R
│   ├── 06_checksums.sh
│   ├── set_reference_checksums.sh
│   └── verify_reference_checksums.sh
├── data/                             # generated; ignored by Git
├── tmp/                              # generated; ignored by Git
├── logs/                             # generated; ignored by Git
└── results/                          # generated scientific outputs
```

## Running individual stages

Normally you only need:

```bash
bash run_all.sh
```

For debugging or inspection, the stages can also be run separately:

```bash
bash setup.sh
bash scripts/01_download_genomes.sh
bash scripts/02_run_minimap2.sh
bash scripts/03_summarize_multigenome.sh
bash scripts/04_plot_summary.sh
bash scripts/05_plot_circos.sh
bash scripts/06_checksums.sh
```

Each stage expects the outputs of the preceding stage to exist.

## What does “reproducible” mean here?

For this repository, a byte-identical reproduction means that, on the intended locked platform and environment, the regenerated files included in `CHECKSUMS.txt` have exactly the same SHA256 values as the fixed `CHECKSUMS.reference.txt`.

A passing verification therefore tests the actual downloaded data and generated scientific result files included in the manifest, not merely whether the scripts finished without errors.

Raw runtime logs and temporary alignment files are intentionally excluded because they are operational intermediates rather than final scientific results.

## Important interpretation note

This is a **Minimap2-based** implementation. If you compare it with a previous MUMmer/`dnadiff` implementation, the exact alignment blocks, coverage values, and figures should not be expected to be numerically identical. Different whole-genome aligners use different anchoring, chaining, filtering, and reporting algorithms.

The biological question and downstream summary concept are the same; the alignment method is different.

## Repository

GitHub repository:

```text
https://github.com/ArpanPrj/CBC_2026_Week5_Minimap2
```
