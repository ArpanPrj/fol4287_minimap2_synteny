#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — SOFTWARE BOOTSTRAP AND EXPLICIT ENVIRONMENT LOCKING
# =============================================================================
# This script is intentionally more elaborate than a normal "conda env create"
# command because the project is testing byte-level reproducibility.
#
# Main ideas:
#   • A specific Miniforge release is pinned in config/bootstrap.sh.
#   • The operating system and CPU architecture are converted to a Conda subdir
#     such as linux-64.
#   • The first validated author run solves environment.yml once.
#   • That exact solved environment is exported as an explicit lock file using
#     package URLs and SHA256 hashes.
#   • Future runs create the environment from that explicit lock instead of
#     solving dependencies again.
#   • A separate source-hash file records which environment.yml produced the
#     lock. If environment.yml later changes, setup stops rather than silently
#     reusing an outdated lock.
#   • software_versions.tsv records the active runtime versions for provenance.
#
# Nothing in this annotation changes the executable statements below.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"
source "${ROOT}/config/bootstrap.sh"

mkdir -p logs tmp/bootstrap
LOG="${ROOT}/logs/setup.log"
exec > >(tee "${LOG}") 2>&1

sha256_one() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
  else
    echo "ERROR: no SHA256 utility found." >&2
    exit 1
  fi
}

download_file() {
  local url="$1"
  local output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --retry 3 --output "${output}" "${url}"
  elif command -v wget >/dev/null 2>&1; then
    wget --tries=3 --output-document="${output}" "${url}"
  else
    echo "ERROR: neither curl nor wget is installed."
    exit 1
  fi
}

SYSTEM="$(uname -s)"
ARCH="$(uname -m)"
case "${SYSTEM}" in
  Linux)
    MF_OS="Linux"
    case "${ARCH}" in
      x86_64|amd64) MF_ARCH="x86_64"; CONDA_SUBDIR="linux-64" ;;
      aarch64) MF_ARCH="aarch64"; CONDA_SUBDIR="linux-aarch64" ;;
      *) echo "ERROR: unsupported Linux architecture: ${ARCH}"; exit 1 ;;
    esac
    ;;
  Darwin)
    MF_OS="MacOSX"
    case "${ARCH}" in
      x86_64|amd64) MF_ARCH="x86_64"; CONDA_SUBDIR="osx-64" ;;
      arm64|aarch64) MF_ARCH="arm64"; CONDA_SUBDIR="osx-arm64" ;;
      *) echo "ERROR: unsupported macOS architecture: ${ARCH}"; exit 1 ;;
    esac
    ;;
  *)
    echo "ERROR: unsupported OS: ${SYSTEM}"
    echo "Windows users should use WSL Ubuntu."
    exit 1
    ;;
esac

LOCK_FILE="${ROOT}/environment-${CONDA_SUBDIR}.lock.txt"
LOCK_SOURCE_HASH="${ROOT}/environment-${CONDA_SUBDIR}.source.sha256"
ENV_LOCK_HASH_FILE="${ENV_PREFIX}/.explicit_lock_sha256"
ENV_YML_HASH="$(sha256_one "${ROOT}/environment.yml")"

if [[ -f "${LOCK_FILE}" || -f "${LOCK_SOURCE_HASH}" ]]; then
  if [[ ! -f "${LOCK_FILE}" || ! -f "${LOCK_SOURCE_HASH}" ]]; then
    echo "ERROR: lock file and source-hash file must either both exist or both be absent."
    exit 1
  fi
  RECORDED_SOURCE_HASH="$(tr -d '[:space:]' < "${LOCK_SOURCE_HASH}")"
  if [[ "${RECORDED_SOURCE_HASH}" != "${ENV_YML_HASH}" ]]; then
    echo "ERROR: environment.yml changed after the explicit lock was created."
    echo "Current environment.yml SHA256: ${ENV_YML_HASH}"
    echo "Recorded source SHA256:        ${RECORDED_SOURCE_HASH}"
    echo "To intentionally make a new baseline, delete the lock/source-hash and cached environment, then rerun setup.sh."
    exit 1
  fi
fi

INSTALLER="Miniforge3-${MINIFORGE_VERSION}-${MF_OS}-${MF_ARCH}.sh"
BASE_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}"
INSTALLER_URL="${BASE_URL}/${INSTALLER}"
CHECKSUM_URL="${INSTALLER_URL}.sha256"
INSTALLER_PATH="${ROOT}/tmp/bootstrap/${INSTALLER}"
CHECKSUM_PATH="${INSTALLER_PATH}.sha256"

echo "============================================================"
echo "REPRODUCIBLE SOFTWARE SETUP"
echo "============================================================"
echo "Platform: ${CONDA_SUBDIR}"
echo "Miniforge: ${MINIFORGE_VERSION}"
echo "Environment lock: $(basename "${LOCK_FILE}")"

if [[ ! -x "${MINIFORGE_PREFIX}/bin/conda" ]]; then
  echo "Installing pinned Miniforge into ${MINIFORGE_PREFIX}"
  rm -f "${INSTALLER_PATH}" "${CHECKSUM_PATH}"
  download_file "${INSTALLER_URL}" "${INSTALLER_PATH}"
  download_file "${CHECKSUM_URL}" "${CHECKSUM_PATH}"
  (
    cd "${ROOT}/tmp/bootstrap"
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum --check "$(basename "${CHECKSUM_PATH}")"
    else
      shasum -a 256 --check "$(basename "${CHECKSUM_PATH}")"
    fi
  )
  bash "${INSTALLER_PATH}" -b -p "${MINIFORGE_PREFIX}"
else
  echo "Pinned Miniforge already present."
fi

source "${MINIFORGE_PREFIX}/etc/profile.d/conda.sh"

if [[ -f "${LOCK_FILE}" ]]; then
  DESIRED_LOCK_HASH="$(sha256_one "${LOCK_FILE}")"
else
  DESIRED_LOCK_HASH=""
fi

if [[ -d "${ENV_PREFIX}" ]]; then
  if [[ -z "${DESIRED_LOCK_HASH}" ]]; then
    echo "No explicit lock exists yet; rebuilding once to establish the baseline."
    rm -rf "${ENV_PREFIX}"
  elif [[ ! -f "${ENV_LOCK_HASH_FILE}" ]]; then
    echo "Existing environment predates lock tracking; rebuilding from lock."
    rm -rf "${ENV_PREFIX}"
  elif [[ "$(cat "${ENV_LOCK_HASH_FILE}")" != "${DESIRED_LOCK_HASH}" ]]; then
    echo "Explicit lock changed; rebuilding environment."
    rm -rf "${ENV_PREFIX}"
  else
    echo "Existing environment matches the explicit lock."
  fi
fi

if [[ ! -d "${ENV_PREFIX}" ]]; then
  if [[ -f "${LOCK_FILE}" ]]; then
    echo "Creating environment from exact explicit lock."
    conda create --yes --prefix "${ENV_PREFIX}" --file "${LOCK_FILE}"
  else
    echo "Solving environment.yml once to establish the author's baseline."
    conda env create --prefix "${ENV_PREFIX}" --file environment.yml --solver libmamba
    conda list --prefix "${ENV_PREFIX}" --explicit --sha256 > "${LOCK_FILE}"
    printf '%s\n' "${ENV_YML_HASH}" > "${LOCK_SOURCE_HASH}"
    echo "Created ${LOCK_FILE}"
    echo "Created ${LOCK_SOURCE_HASH}"
    echo "Commit both after validating the final run."
  fi
  DESIRED_LOCK_HASH="$(sha256_one "${LOCK_FILE}")"
  printf '%s\n' "${DESIRED_LOCK_HASH}" > "${ENV_LOCK_HASH_FILE}"
fi

conda activate "${ENV_PREFIX}"
LOCK_SHA256="$(sha256_one "${LOCK_FILE}")"

{
  echo -e "component\tversion"
  echo -e "platform\t${CONDA_SUBDIR}"
  echo -e "environment_yml_sha256\t${ENV_YML_HASH}"
  echo -e "explicit_lock\t$(basename "${LOCK_FILE}")"
  echo -e "explicit_lock_sha256\t${LOCK_SHA256}"
  echo -e "conda\t$(conda --version | awk '{print $2}')"
  echo -e "python\t$(python --version 2>&1 | awk '{print $2}')"
  echo -e "minimap2\t$(minimap2 --version 2>&1 | tail -n 1 | tr -d '\r')"
  echo -e "datasets\t$(datasets version 2>&1 | tail -n 1 | tr -d '\r')"
  echo -e "seqkit\t$(seqkit version 2>&1 | awk '{print $3}')"
  echo -e "R\t$(Rscript --version 2>&1 | sed 's/Rscript (R) version //')"
  echo -e "circlize\t$(Rscript -e 'cat(as.character(packageVersion("circlize")))')"
} > software_versions.tsv

cat software_versions.tsv

echo "============================================================"
echo "SETUP COMPLETE"
echo "============================================================"
