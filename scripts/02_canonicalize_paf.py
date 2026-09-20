#!/usr/bin/env python3
# =============================================================================
# ANNOTATION GUIDE — MAKE RAW PAF A STABLE SCIENTIFIC TABLE
# =============================================================================
# Minimap2 can emit optional tags and its raw output is an external-program
# intermediate. This script defines exactly which alignment information the
# project considers scientifically relevant and serializes it deterministically.
#
# It reads only the 12 mandatory PAF columns and then:
#   • validates coordinate ranges and strand values;
#   • converts numeric text into explicit Python integer values;
#   • derives same/opposite orientation from + / - strand;
#   • derives reference span using PAF's 0-based half-open coordinate convention;
#   • calculates percent identity from matching bases / alignment block length;
#   • uses Decimal arithmetic and explicit 4-decimal ROUND_HALF_UP formatting;
#   • sorts every row by a fixed multi-column key;
#   • writes one LF-terminated TSV with a fixed column order.
#
# Optional PAF tags are deliberately not propagated into the checksummed result.
# =============================================================================
from __future__ import annotations
import argparse
import csv
from decimal import Decimal, ROUND_HALF_UP, getcontext
from pathlib import Path

getcontext().prec = 40
FOUR_DP = Decimal("0.0001")

def q4(value: Decimal) -> str:
    return format(value.quantize(FOUR_DP, rounding=ROUND_HALF_UP), "f")

def parse_args():
    p = argparse.ArgumentParser(description="Canonicalize Minimap2 PAF into deterministic TSV")
    p.add_argument("--paf", required=True, type=Path)
    p.add_argument("--query-name", required=True)
    p.add_argument("--output", required=True, type=Path)
    return p.parse_args()

def main():
    args = parse_args()
    rows = []
    with args.paf.open(encoding="utf-8") as handle:
        for line_no, raw in enumerate(handle, start=1):
            line = raw.rstrip("\n\r")
            if not line:
                continue
            f = line.split("\t")
            if len(f) < 12:
                raise ValueError(f"PAF line {line_no} has fewer than 12 fields")
            query_id = f[0]
            query_length = int(f[1]); query_start = int(f[2]); query_end = int(f[3])
            strand = f[4]
            ref_id = f[5]
            ref_length = int(f[6]); ref_start = int(f[7]); ref_end = int(f[8])
            matching_bases = int(f[9]); alignment_block_length = int(f[10]); mapq = int(f[11])
            if strand not in {"+", "-"}:
                raise ValueError(f"Unexpected strand at PAF line {line_no}: {strand}")
            if not (0 <= query_start <= query_end <= query_length):
                raise ValueError(f"Invalid query coordinates at PAF line {line_no}")
            if not (0 <= ref_start <= ref_end <= ref_length):
                raise ValueError(f"Invalid reference coordinates at PAF line {line_no}")
            if alignment_block_length <= 0:
                raise ValueError(f"Non-positive alignment block length at PAF line {line_no}")
            identity = Decimal(100) * Decimal(matching_bases) / Decimal(alignment_block_length)
            rows.append({
                "query_genome": args.query_name,
                "query_id": query_id,
                "query_length_bp": query_length,
                "query_start_0based": query_start,
                "query_end_0based": query_end,
                "ref_id": ref_id,
                "ref_length_bp": ref_length,
                "ref_start_0based": ref_start,
                "ref_end_0based": ref_end,
                "orientation": "same" if strand == "+" else "opposite",
                "matching_bases": matching_bases,
                "alignment_block_length_bp": alignment_block_length,
                "ref_span_bp": ref_end - ref_start,
                "percent_identity": q4(identity),
                "mapping_quality": mapq,
            })

    rows.sort(key=lambda r: (
        r["ref_id"], r["ref_start_0based"], r["ref_end_0based"],
        r["query_id"], r["query_start_0based"], r["query_end_0based"],
        r["orientation"], r["matching_bases"], r["alignment_block_length_bp"],
        r["mapping_quality"]
    ))

    fields = [
        "query_genome","query_id","query_length_bp","query_start_0based","query_end_0based",
        "ref_id","ref_length_bp","ref_start_0based","ref_end_0based","orientation",
        "matching_bases","alignment_block_length_bp","ref_span_bp","percent_identity","mapping_quality"
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as out:
        writer = csv.DictWriter(out, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    print(f"Wrote {len(rows)} canonical alignments to {args.output}")

if __name__ == "__main__":
    main()
