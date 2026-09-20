#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — STEP 6 SHA256 SCIENTIFIC MANIFEST
# =============================================================================
# This stage defines what byte-level reproducibility means operationally.
#
# It includes every regular file under:
#   data/
#   results/
#
# It intentionally excludes:
#   tmp/   raw PAF, download archives, other temporary/intermediate files
#   logs/  runtime logs whose timestamps/timing are not scientific results
#
# Paths are sorted in the C locale before hashing so manifest row order is fixed.
# After writing CHECKSUMS.txt, the script immediately verifies every hash against
# the files currently on disk. A mismatch makes the stage fail.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
mkdir -p tmp logs
LOG="${ROOT}/logs/06_checksums.log"
exec > >(tee "${LOG}") 2>&1
CHECKSUM_FILE="${ROOT}/CHECKSUMS.txt"
FILE_LIST="${ROOT}/tmp/checksum_file_list.txt"
rm -f "${CHECKSUM_FILE}"
{
  find data -type f -print
  find results -type f -print
} | LC_ALL=C sort > "${FILE_LIST}"
[[ -s "${FILE_LIST}" ]] || { echo "ERROR: no data/results files found."; exit 1; }
while IFS= read -r file; do sha256_files "${file}"; done < "${FILE_LIST}" > "${CHECKSUM_FILE}"
if command -v sha256sum >/dev/null 2>&1; then sha256sum --check "${CHECKSUM_FILE}"; else shasum -a 256 --check "${CHECKSUM_FILE}"; fi
echo "Files checksummed: $(wc -l < "${CHECKSUM_FILE}" | tr -d ' ')"
echo "Wrote CHECKSUMS.txt"
