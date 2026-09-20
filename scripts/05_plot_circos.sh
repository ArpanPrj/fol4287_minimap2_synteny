#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — STEP 5 CIRCOS WRAPPER
# =============================================================================
# Loads the same display thresholds used when the Fo47 link table was created,
# exports them to R for figure annotation, runs the Circos plotting script, and
# fails if the expected SVG was not produced.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${ROOT}/config/parameters.sh"
export PLOT_MIN_ALIGNMENT_LENGTH PLOT_MIN_IDENTITY
mkdir -p results logs
LOG="${ROOT}/logs/05_plot_circos.log"
exec > >(tee "${LOG}") 2>&1
Rscript "${SCRIPT_DIR}/05_plot_circos.R"
[[ -s results/Fol4287_vs_Fo47_circos.svg ]] || { echo "ERROR: Circos SVG missing"; exit 1; }
echo "STEP 5 COMPLETE"
