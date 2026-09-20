#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — SHARED DETERMINISTIC RUNTIME SETTINGS
# =============================================================================
# Every numbered shell step sources this file.
#
# It guarantees that all stages:
#   • operate from the repository root;
#   • use the C locale and UTC timezone;
#   • use a fixed Python hash seed and ignore user-level Python site packages;
#   • ignore user-specific R startup configuration;
#   • constrain common numerical libraries to one thread;
#   • activate the exact project environment created by setup.sh;
#   • share the same SHA256 helper on Linux or macOS.
#
# These settings reduce accidental machine/user-specific behavior that can make
# byte-level outputs differ even when the scientific logic is identical.
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
cd "${ROOT}"

export LC_ALL=C
export LANG=C
export TZ=UTC
export PYTHONHASHSEED=0
export PYTHONNOUSERSITE=1
export R_PROFILE_USER=/dev/null
export R_ENVIRON_USER=/dev/null
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1

source "${ROOT}/config/bootstrap.sh"
if [[ ! -x "${MINIFORGE_PREFIX}/bin/conda" ]] || [[ ! -d "${ENV_PREFIX}" ]]; then
  echo "ERROR: project environment not found. Run: bash setup.sh"
  exit 1
fi
source "${MINIFORGE_PREFIX}/etc/profile.d/conda.sh"
conda activate "${ENV_PREFIX}"

sha256_files() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$@"
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$@"
  else
    echo "ERROR: no SHA256 utility found."
    exit 1
  fi
}
