#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — STEP 3 WRAPPER
# =============================================================================
# This shell wrapper does not perform the biological calculations itself.
# Its jobs are to:
#   • activate the common deterministic environment;
#   • load the configured visualization thresholds;
#   • export those values so Python can read them from os.environ;
#   • run 03_summarize_multigenome.py;
#   • fail immediately if any required quantitative output is missing.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${ROOT}/config/parameters.sh"
export PLOT_MIN_ALIGNMENT_LENGTH PLOT_MIN_IDENTITY CIRCOS_QUERY
mkdir -p results logs
LOG="${ROOT}/logs/03_summarize_multigenome.log"
exec > >(tee "${LOG}") 2>&1

echo "============================================================"
echo "STEP 3: MULTI-GENOME CHROMOSOME SYNTENY SUMMARY"
echo "============================================================"
python "${SCRIPT_DIR}/03_summarize_multigenome.py"
for file in \
  results/multigenome_chromosome_synteny.tsv \
  results/percent_aligned_matrix.tsv \
  results/core_vs_lineage_specific_by_query.tsv \
  results/chromosome_across_query_summary.tsv \
  results/pairwise_summary.tsv \
  results/fo47_circos_links.tsv \
  results/fo47_circos_filter_summary.tsv; do
  [[ -s "${file}" ]] || { echo "ERROR: missing output ${file}"; exit 1; }
done
echo "STEP 3 COMPLETE"
