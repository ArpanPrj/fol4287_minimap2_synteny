#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — REPRODUCTION VERDICT
# =============================================================================
# This is deliberately simple: both checksum manifests must exist, then diff is
# used to compare them byte-for-byte.
#
# Empty diff => every recorded path and SHA256 digest is identical => PASS.
# Any manifest difference => FAIL and a non-zero exit status.
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "${ROOT}"
[[ -s CHECKSUMS.reference.txt ]] || { echo "ERROR: CHECKSUMS.reference.txt is missing."; exit 1; }
[[ -s CHECKSUMS.txt ]] || { echo "ERROR: CHECKSUMS.txt is missing. Run bash run_all.sh first."; exit 1; }
echo "============================================================"
echo "COMPARING REPRODUCTION TO PUBLISHED REFERENCE"
echo "============================================================"
if diff -u CHECKSUMS.reference.txt CHECKSUMS.txt; then
  echo; echo "PASS: all checksummed data and outputs are byte-identical to the reference run."
else
  echo; echo "FAIL: one or more checksummed files differ from the reference run."; exit 1
fi
