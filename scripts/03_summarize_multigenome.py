#!/usr/bin/env python3
# =============================================================================
# ANNOTATION GUIDE — QUANTITATIVE CORE OF THE MINIMAP2 WORKFLOW
# =============================================================================
# This script consumes only the canonical alignment TSVs, not raw PAF.
#
# Main analytical steps:
#   1. Parse fixed canonical alignment columns into typed Python values.
#   2. Merge overlapping 0-based half-open Fol4287 intervals so aligned bases are
#      never double-counted.
#   3. Calculate chromosome-level unique aligned bp and percent aligned.
#   4. Calculate same- and opposite-orientation unique coverage separately.
#   5. Calculate identity from summed matching bases / summed alignment-block
#      length, avoiding averages of rounded percentages.
#   6. Build the long chromosome × query table.
#   7. Reshape the long table into the heatmap matrix.
#   8. Aggregate chromosomes into core and lineage-specific compartments.
#   9. Summarize each chromosome across the four query genomes.
#  10. Build a whole-reference pairwise summary.
#  11. Create the Fo47 Circos link table using display-only size/identity filters.
#
# Decimal arithmetic and explicit 4-decimal formatting are used for tabular
# decimal outputs so the serializer has one defined rounding behavior.
# =============================================================================
from __future__ import annotations
import csv
import os
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP, getcontext
from pathlib import Path

getcontext().prec = 40
FOUR_DP = Decimal("0.0001")
ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "results"
REF_META = RESULTS / "reference_chromosome_metadata.tsv"
FO47_META = RESULTS / "Fo47_chromosome_metadata.tsv"
GENOMES = ROOT / "config" / "genomes.tsv"
PLOT_MIN_LENGTH = int(os.environ.get("PLOT_MIN_ALIGNMENT_LENGTH", "50000"))
PLOT_MIN_IDENTITY = Decimal(os.environ.get("PLOT_MIN_IDENTITY", "90"))
CIRCOS_QUERY = os.environ.get("CIRCOS_QUERY", "Fo47")

def q4(v: Decimal) -> str:
    return format(v.quantize(FOUR_DP, rounding=ROUND_HALF_UP), "f")

def read_tsv(path: Path):
    with path.open(newline="", encoding="utf-8") as h:
        return list(csv.DictReader(h, delimiter="\t"))

def write_tsv(path: Path, rows, fields):
    with path.open("w", newline="", encoding="utf-8") as out:
        w = csv.DictWriter(out, fieldnames=fields, delimiter="\t", lineterminator="\n")
        w.writeheader(); w.writerows(rows)

def parse_alignment_table(path: Path):
    out = []
    for r in read_tsv(path):
        out.append({
            "query_genome": r["query_genome"], "query_id": r["query_id"],
            "query_length_bp": int(r["query_length_bp"]),
            "query_start": int(r["query_start_0based"]), "query_end": int(r["query_end_0based"]),
            "ref_id": r["ref_id"], "ref_length_bp": int(r["ref_length_bp"]),
            "ref_start": int(r["ref_start_0based"]), "ref_end": int(r["ref_end_0based"]),
            "orientation": r["orientation"], "matching_bases": int(r["matching_bases"]),
            "alignment_block_length_bp": int(r["alignment_block_length_bp"]),
            "ref_span_bp": int(r["ref_span_bp"]),
            "percent_identity": Decimal(r["percent_identity"]),
            "mapping_quality": int(r["mapping_quality"]),
        })
    return out

def union_length(intervals):
    ints = sorted((int(a), int(b)) for a, b in intervals if int(b) > int(a))
    if not ints:
        return 0
    s, e = ints[0]; total = 0
    for a, b in ints[1:]:
        if a <= e:
            e = max(e, b)
        else:
            total += e - s
            s, e = a, b
    return total + (e - s)

def identity_from_blocks(blocks):
    matches = sum(b["matching_bases"] for b in blocks)
    denom = sum(b["alignment_block_length_bp"] for b in blocks)
    return None if denom == 0 else Decimal(100) * Decimal(matches) / Decimal(denom)

genomes = read_tsv(GENOMES)
queries = [r for r in genomes if r["role"] == "query"]
ref_meta = read_tsv(REF_META)
ref_meta.sort(key=lambda r: int(r["chromosome"]))
ref_by_id = {r["sequence_id"]: r for r in ref_meta}
fo47_meta = read_tsv(FO47_META)
fo47_by_id = {r["sequence_id"]: r for r in fo47_meta}
if len(ref_meta) != 15:
    raise RuntimeError(f"Expected 15 Fol4287 chromosomes; found {len(ref_meta)}")

all_blocks = {}
for q in queries:
    path = RESULTS / "pairwise_alignments" / f"Fol4287_vs_{q['name']}.tsv"
    if not path.exists():
        raise FileNotFoundError(path)
    all_blocks[q["name"]] = parse_alignment_table(path)

# Long chromosome x query table.
long_rows = []
for q in queries:
    blocks = all_blocks[q["name"]]
    by_ref = defaultdict(list)
    for b in blocks:
        by_ref[b["ref_id"]].append(b)
    for m in ref_meta:
        chr_blocks = by_ref.get(m["sequence_id"], [])
        chr_len = int(m["length_bp"])
        aligned = union_length((b["ref_start"], b["ref_end"]) for b in chr_blocks)
        same = union_length((b["ref_start"], b["ref_end"]) for b in chr_blocks if b["orientation"] == "same")
        opposite = union_length((b["ref_start"], b["ref_end"]) for b in chr_blocks if b["orientation"] == "opposite")
        ident = identity_from_blocks(chr_blocks)
        largest = max((b["ref_span_bp"] for b in chr_blocks), default=0)
        pct = Decimal(100) * Decimal(aligned) / Decimal(chr_len)
        long_rows.append({
            "query": q["name"], "accession": q["accession"], "host_context": q["host_context"],
            "chromosome": m["chromosome"], "ref_id": m["sequence_id"],
            "chromosome_class": m["chromosome_class"], "chromosome_length_bp": chr_len,
            "aligned_bp": aligned, "percent_aligned": q4(pct), "alignment_blocks": len(chr_blocks),
            "weighted_mean_identity": "NA" if ident is None else q4(ident),
            "largest_block_bp": largest, "same_orientation_aligned_bp": same,
            "opposite_orientation_aligned_bp": opposite,
        })

long_fields = ["query","accession","host_context","chromosome","ref_id","chromosome_class",
               "chromosome_length_bp","aligned_bp","percent_aligned","alignment_blocks",
               "weighted_mean_identity","largest_block_bp","same_orientation_aligned_bp",
               "opposite_orientation_aligned_bp"]
write_tsv(RESULTS / "multigenome_chromosome_synteny.tsv", long_rows, long_fields)

# Heatmap matrix.
lookup = {(r["query"], r["chromosome"]): r for r in long_rows}
matrix_rows = []
for m in ref_meta:
    row = {"chromosome": m["chromosome"], "chromosome_class": m["chromosome_class"]}
    for q in queries:
        row[q["name"]] = lookup[(q["name"], m["chromosome"])]["percent_aligned"]
    matrix_rows.append(row)
write_tsv(RESULTS / "percent_aligned_matrix.tsv", matrix_rows,
          ["chromosome","chromosome_class"] + [q["name"] for q in queries])

# Core vs lineage-specific.
class_rows = []
for q in queries:
    qrows = [r for r in long_rows if r["query"] == q["name"]]
    for cls in ["core", "lineage_specific"]:
        subset = [r for r in qrows if r["chromosome_class"] == cls]
        total_len = sum(int(r["chromosome_length_bp"]) for r in subset)
        total_aligned = sum(int(r["aligned_bp"]) for r in subset)
        vals = sorted(Decimal(r["percent_aligned"]) for r in subset)
        n = len(vals); median = vals[n//2] if n % 2 else (vals[n//2-1] + vals[n//2]) / Decimal(2)
        cls_blocks = [b for b in all_blocks[q["name"]]
                      if ref_by_id.get(b["ref_id"], {}).get("chromosome_class") == cls]
        ident = identity_from_blocks(cls_blocks)
        class_rows.append({
            "query": q["name"], "accession": q["accession"], "host_context": q["host_context"],
            "chromosome_class": cls, "chromosome_count": len(subset), "total_length_bp": total_len,
            "aligned_bp": total_aligned,
            "percent_aligned": q4(Decimal(100)*Decimal(total_aligned)/Decimal(total_len)),
            "median_chromosome_percent_aligned": q4(median), "alignment_blocks": len(cls_blocks),
            "weighted_mean_identity": "NA" if ident is None else q4(ident),
        })
class_fields = ["query","accession","host_context","chromosome_class","chromosome_count",
                "total_length_bp","aligned_bp","percent_aligned","median_chromosome_percent_aligned",
                "alignment_blocks","weighted_mean_identity"]
write_tsv(RESULTS / "core_vs_lineage_specific_by_query.tsv", class_rows, class_fields)

# Across-query per chromosome.
across_rows = []
for m in ref_meta:
    vals = sorted(Decimal(lookup[(q["name"], m["chromosome"])]["percent_aligned"]) for q in queries)
    n = len(vals); median = vals[n//2] if n % 2 else (vals[n//2-1] + vals[n//2]) / Decimal(2)
    mean = sum(vals, Decimal(0)) / Decimal(len(vals))
    across_rows.append({"chromosome": m["chromosome"], "chromosome_class": m["chromosome_class"],
                        "mean_percent_aligned_across_queries": q4(mean),
                        "median_percent_aligned_across_queries": q4(median),
                        "min_percent_aligned": q4(min(vals)), "max_percent_aligned": q4(max(vals))})
write_tsv(RESULTS / "chromosome_across_query_summary.tsv", across_rows,
          ["chromosome","chromosome_class","mean_percent_aligned_across_queries",
           "median_percent_aligned_across_queries","min_percent_aligned","max_percent_aligned"])

# Whole-reference pairwise summary.
pairwise_rows = []
for q in queries:
    qrows = [r for r in long_rows if r["query"] == q["name"]]
    ref_len = sum(int(r["chromosome_length_bp"]) for r in qrows)
    aligned = sum(int(r["aligned_bp"]) for r in qrows)
    ident = identity_from_blocks(all_blocks[q["name"]])
    pairwise_rows.append({"query": q["name"], "accession": q["accession"], "host_context": q["host_context"],
                          "reference_length_bp": ref_len, "aligned_reference_bp": aligned,
                          "percent_reference_aligned": q4(Decimal(100)*Decimal(aligned)/Decimal(ref_len)),
                          "alignment_blocks": len(all_blocks[q["name"]]),
                          "weighted_mean_identity": "NA" if ident is None else q4(ident)})
write_tsv(RESULTS / "pairwise_summary.tsv", pairwise_rows,
          ["query","accession","host_context","reference_length_bp","aligned_reference_bp",
           "percent_reference_aligned","alignment_blocks","weighted_mean_identity"])

# Detailed Fo47 plot links.
if CIRCOS_QUERY not in all_blocks:
    raise RuntimeError(f"Circos query {CIRCOS_QUERY} is not configured")
circos_rows = []
for b in all_blocks[CIRCOS_QUERY]:
    if b["ref_span_bp"] < PLOT_MIN_LENGTH or b["percent_identity"] < PLOT_MIN_IDENTITY:
        continue
    ref = ref_by_id.get(b["ref_id"]); qry = fo47_by_id.get(b["query_id"])
    if ref is None or qry is None:
        continue
    circos_rows.append({
        "fol_id": b["ref_id"], "fol_chromosome": ref["chromosome"],
        "fol_chromosome_class": ref["chromosome_class"], "fol_start": b["ref_start"], "fol_end": b["ref_end"],
        "fo47_id": b["query_id"], "fo47_chromosome": qry["chromosome"],
        "fo47_chromosome_class": qry["chromosome_class"], "fo47_start": b["query_start"], "fo47_end": b["query_end"],
        "alignment_length_bp": b["ref_span_bp"], "percent_identity": q4(b["percent_identity"]),
        "orientation": b["orientation"],
    })
circos_rows.sort(key=lambda r: (int(r["fol_chromosome"]), int(r["fol_start"]),
                                r["fo47_id"], int(r["fo47_start"]), int(r["fo47_end"])))
circos_fields = ["fol_id","fol_chromosome","fol_chromosome_class","fol_start","fol_end",
                 "fo47_id","fo47_chromosome","fo47_chromosome_class","fo47_start","fo47_end",
                 "alignment_length_bp","percent_identity","orientation"]
write_tsv(RESULTS / "fo47_circos_links.tsv", circos_rows, circos_fields)

with (RESULTS / "fo47_circos_filter_summary.tsv").open("w", newline="", encoding="utf-8") as out:
    w = csv.writer(out, delimiter="\t", lineterminator="\n")
    w.writerow(["metric","value"])
    w.writerow(["all_primary_and_supplementary_blocks", len(all_blocks[CIRCOS_QUERY])])
    w.writerow(["plot_min_reference_span_bp", PLOT_MIN_LENGTH])
    w.writerow(["plot_min_identity_percent", q4(PLOT_MIN_IDENTITY)])
    w.writerow(["blocks_retained_for_plot", len(circos_rows)])
    w.writerow(["same_orientation_blocks_for_plot", sum(r["orientation"] == "same" for r in circos_rows)])
    w.writerow(["opposite_orientation_blocks_for_plot", sum(r["orientation"] == "opposite" for r in circos_rows)])

print(f"Summarized {len(queries)} query genomes across {len(ref_meta)} Fol4287 chromosomes")
print(f"Circos links retained for {CIRCOS_QUERY}: {len(circos_rows)}")
