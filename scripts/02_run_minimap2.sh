#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — STEP 2 EXTERNAL WHOLE-GENOME ALIGNMENT
# =============================================================================
# This is the main external-program computation in the project.
#
# For every row in config/genomes.tsv marked role=query:
#   • Fol4287 chromosome-only FASTA is the Minimap2 target/reference.
#   • The complete downloaded genome is the query.
#   • One fixed Minimap2 parameter set is used for every comparison.
#   • Raw PAF is written to tmp/minimap2/ and treated as an intermediate.
#   • Raw PAF is immediately passed to 02_canonicalize_paf.py.
#   • The canonical TSV under results/pairwise_alignments/ becomes the stable
#     scientific alignment product used by all later calculations.
#
# The pairwise_outputs.tsv index contains stable paths to those canonical tables.
# Runtime measurements are logged for information only and are not used in any
# scientific calculation.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${ROOT}/config/parameters.sh"

mkdir -p tmp/minimap2 results/pairwise_alignments logs
LOG="${ROOT}/logs/02_run_minimap2.log"
exec > >(tee "${LOG}") 2>&1

REFERENCE="data/analysis/${REFERENCE_NAME}.chromosomes.fna"
[[ -s "${REFERENCE}" ]] || { echo "ERROR: missing reference FASTA: ${REFERENCE}"; exit 1; }

rm -rf tmp/minimap2 results/pairwise_alignments
mkdir -p tmp/minimap2 results/pairwise_alignments
printf 'query\taccession\thost_context\talignment_tsv\n' > results/pairwise_outputs.tsv

echo "============================================================"
echo "STEP 2: MINIMAP2 WHOLE-GENOME ALIGNMENTS"
echo "============================================================"
echo "Preset: ${MINIMAP2_PRESET}"
echo "Threads: ${MINIMAP2_THREADS}"
echo "Seed: ${MINIMAP2_SEED}"
echo "Mini-batch: ${MINIMAP2_MINIBATCH}"
echo "Index batch: ${MINIMAP2_INDEX_BATCH}"
echo "Secondary alignments: disabled"

while IFS=$'\t' read -r name accession role host_context circos; do
  [[ "${name}" == "name" ]] && continue
  [[ "${role}" != "query" ]] && continue

  query="data/raw/${name}.fna"
  raw_paf="tmp/minimap2/${REFERENCE_NAME}_vs_${name}.raw.paf"
  canonical="results/pairwise_alignments/${REFERENCE_NAME}_vs_${name}.tsv"
  [[ -s "${query}" ]] || { echo "ERROR: missing query FASTA: ${query}"; exit 1; }

  echo
  echo "------------------------------------------------------------"
  echo "Aligning ${REFERENCE_NAME} vs ${name} (${accession})"
  echo "------------------------------------------------------------"
  start="$(date +%s)"

  minimap2 \
    -x "${MINIMAP2_PRESET}" \
    -c \
    --secondary=no \
    --seed "${MINIMAP2_SEED}" \
    -t "${MINIMAP2_THREADS}" \
    -K "${MINIMAP2_MINIBATCH}" \
    -I "${MINIMAP2_INDEX_BATCH}" \
    "${REFERENCE}" \
    "${query}" \
    > "${raw_paf}"

  [[ -s "${raw_paf}" ]] || { echo "ERROR: Minimap2 produced no alignments for ${name}"; exit 1; }

  python "${SCRIPT_DIR}/02_canonicalize_paf.py" \
    --paf "${raw_paf}" \
    --query-name "${name}" \
    --output "${canonical}"

  [[ -s "${canonical}" ]] || { echo "ERROR: canonical alignment table missing: ${canonical}"; exit 1; }

  printf '%s\t%s\t%s\t%s\n' "${name}" "${accession}" "${host_context}" "${canonical}" \
    >> results/pairwise_outputs.tsv

  end="$(date +%s)"
  echo "Completed ${name} in $((end-start)) seconds."
done < config/genomes.tsv

echo
echo "STEP 2 COMPLETE"
