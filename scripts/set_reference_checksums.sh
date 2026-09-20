#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — FREEZE THE VALIDATED REFERENCE MANIFEST
# =============================================================================
# Use this only after the final reference run has been inspected and accepted.
# It copies the current generated CHECKSUMS.txt to CHECKSUMS.reference.txt.
#
# CHECKSUMS.reference.txt is then committed to Git and remains fixed. Later
# reproductions regenerate CHECKSUMS.txt and compare against this frozen file.
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "${ROOT}"
[[ -s CHECKSUMS.txt ]] || { echo "ERROR: CHECKSUMS.txt is missing. Run bash run_all.sh first."; exit 1; }
cp CHECKSUMS.txt CHECKSUMS.reference.txt
echo "Created CHECKSUMS.reference.txt. Commit it only after validating the final reference run."
