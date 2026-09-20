#!/usr/bin/env python3
# =============================================================================
# ANNOTATION GUIDE — FASTA PARSING AND CHROMOSOME METADATA
# =============================================================================
# This Python helper deliberately avoids fragile AWK/grep parsing of complex NCBI
# FASTA headers.
#
# Major jobs:
#   1. Read tracked genome/class configuration tables.
#   2. Stream through each downloaded FASTA and count records/bases.
#   3. Separate NC_, NW_, and other sequence-record types for descriptive
#      assembly metadata.
#   4. Identify chromosome-labelled NC_ records for Fol4287 and Fo47.
#   5. Require exactly 15 Fol4287 and 12 Fo47 chromosome records as sanity checks.
#   6. Write chromosome-only FASTAs with a fixed 60-base line width and LF
#      line endings.
#   7. Write deterministic chromosome metadata tables connecting accession IDs,
#      human-readable chromosome labels, lengths, and biological classes.
#
# The complete query assemblies remain unchanged under data/raw/ and are what
# Minimap2 sees as query FASTAs.
# =============================================================================
from __future__ import annotations
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GENOMES_TSV = ROOT / "config" / "genomes.tsv"
CLASS_TSV = ROOT / "config" / "fol4287_chromosome_classes.tsv"
RAW_DIR = ROOT / "data" / "raw"
ANALYSIS_DIR = ROOT / "data" / "analysis"
RESULTS_DIR = ROOT / "results"
ANALYSIS_DIR.mkdir(parents=True, exist_ok=True)
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

def read_tsv(path: Path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))

def fasta_records(path: Path):
    header = None
    seq_chunks = []
    with path.open(encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n\r")
            if not line:
                continue
            if line.startswith(">"):
                if header is not None:
                    yield header, "".join(seq_chunks)
                header = line[1:]
                seq_chunks = []
            else:
                if header is None:
                    raise ValueError(f"Sequence encountered before FASTA header in {path}")
                seq_chunks.append("".join(line.split()))
    if header is not None:
        yield header, "".join(seq_chunks)

def split_header(header: str):
    parts = header.split(maxsplit=1)
    return parts[0], parts[1] if len(parts) == 2 else ""

def chromosome_label(description: str):
    match = re.search(r"\bchromosome\s+([^,]+)", description, flags=re.IGNORECASE)
    return match.group(1).strip() if match else ""

def write_fasta(records, path: Path, width: int = 60):
    with path.open("w", encoding="utf-8", newline="\n") as out:
        for header, seq in records:
            out.write(f">{header}\n")
            for i in range(0, len(seq), width):
                out.write(seq[i:i+width] + "\n")

genomes = read_tsv(GENOMES_TSV)
classes = {row["chromosome"]: row["chromosome_class"] for row in read_tsv(CLASS_TSV)}
summary_rows = []
for genome in genomes:
    path = RAW_DIR / f"{genome['name']}.fna"
    if not path.exists():
        raise FileNotFoundError(path)
    nseq = total = nc = nw = other = 0
    for header, seq in fasta_records(path):
        seq_id, _ = split_header(header)
        nseq += 1
        total += len(seq)
        if seq_id.startswith("NC_"):
            nc += 1
        elif seq_id.startswith("NW_"):
            nw += 1
        else:
            other += 1
    summary_rows.append({**genome, "num_sequences": nseq, "total_bp": total,
                         "NC_records": nc, "NW_records": nw, "other_records": other})

with (RESULTS_DIR / "genome_metadata.tsv").open("w", newline="", encoding="utf-8") as out:
    fields = ["name","accession","role","host_context","circos","num_sequences",
              "total_bp","NC_records","NW_records","other_records"]
    writer = csv.DictWriter(out, fieldnames=fields, delimiter="\t", lineterminator="\n")
    writer.writeheader(); writer.writerows(summary_rows)

def prepare_chromosome_genome(name: str, expected_count: int, classify=None):
    raw = RAW_DIR / f"{name}.fna"
    selected, metadata = [], []
    for header, seq in fasta_records(raw):
        seq_id, desc = split_header(header)
        chrom = chromosome_label(desc)
        if seq_id.startswith("NC_") and chrom:
            selected.append((header, seq))
            metadata.append({"genome": name, "sequence_id": seq_id, "chromosome": chrom,
                             "length_bp": len(seq),
                             "chromosome_class": classify(chrom) if classify else "",
                             "description": desc})
    if len(selected) != expected_count:
        raise RuntimeError(f"Expected {expected_count} chromosome records for {name}, found {len(selected)}")
    write_fasta(selected, ANALYSIS_DIR / f"{name}.chromosomes.fna")
    return metadata

fol_meta = prepare_chromosome_genome("Fol4287", 15, classify=lambda c: classes.get(c, "unclassified"))
fol_meta.sort(key=lambda row: int(row["chromosome"]))
fo47_meta = prepare_chromosome_genome("Fo47", 12,
    classify=lambda c: "accessory" if c.upper() == "VII" else "core")
roman = ["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII"]
order = {r:i for i,r in enumerate(roman, start=1)}
fo47_meta.sort(key=lambda row: order.get(row["chromosome"].upper(), 999))

for filename, rows in [("reference_chromosome_metadata.tsv", fol_meta),
                       ("Fo47_chromosome_metadata.tsv", fo47_meta)]:
    with (RESULTS_DIR / filename).open("w", newline="", encoding="utf-8") as out:
        fields = ["genome","sequence_id","chromosome","length_bp","chromosome_class","description"]
        writer = csv.DictWriter(out, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)

print(f"Prepared {len(fol_meta)} Fol4287 chromosome records")
print(f"Prepared {len(fo47_meta)} Fo47 chromosome records")
