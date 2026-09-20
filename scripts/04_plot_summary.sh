#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — STEP 4 PLOTTING WRAPPER
# =============================================================================
# Activates the shared environment, runs the R summary-plot script, and treats a
# missing/empty SVG as a failed pipeline stage. The actual plot construction is
# in 04_plot_summary.R.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
mkdir -p results logs
LOG="${ROOT}/logs/04_plot_summary.log"
exec > >(tee "${LOG}") 2>&1
Rscript "${SCRIPT_DIR}/04_plot_summary.R"
for file in results/Fol4287_multigenome_heatmap.svg results/core_vs_lineage_specific_by_query.svg; do
  [[ -s "${file}" ]] || { echo "ERROR: missing figure ${file}"; exit 1; }
done
echo "STEP 4 COMPLETE"
