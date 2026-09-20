#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — CENTRAL ANALYSIS PARAMETERS
# =============================================================================
# Every scientific parameter that should remain consistent across runs is kept
# here instead of being scattered through several scripts.
#
# REFERENCE_NAME / REFERENCE_ACCESSION
#   identify Fol4287 and the exact versioned reference assembly.
#
# CIRCOS_QUERY
#   chooses Fo47 for the detailed ribbon-level circular figure. All four query
#   genomes are still included in the quantitative multi-genome analysis.
#
# MINIMAP2_PRESET="asm10"
#   applies the same assembly-to-assembly preset to every query.
#
# MINIMAP2_THREADS=1
#   intentionally sacrifices some speed for a simpler deterministic runtime.
#
# MINIMAP2_SEED=11
#   fixes Minimap2's seed used when choosing among equally scoring alternatives.
#
# MINIMAP2_MINIBATCH / MINIMAP2_INDEX_BATCH
#   make batching explicit rather than relying on a changing/default setting.
#
# PLOT_MIN_ALIGNMENT_LENGTH / PLOT_MIN_IDENTITY
#   are display-only thresholds for the Fo47 Circos figure; they do not filter
#   the chromosome-coverage calculations.
# =============================================================================
REFERENCE_NAME="Fol4287"
REFERENCE_ACCESSION="GCF_000149955.1"
CIRCOS_QUERY="Fo47"

MINIMAP2_PRESET="asm10"
MINIMAP2_THREADS=1
MINIMAP2_SEED=11
MINIMAP2_MINIBATCH="500M"
MINIMAP2_INDEX_BATCH="8G"

PLOT_MIN_ALIGNMENT_LENGTH=50000
PLOT_MIN_IDENTITY=90
