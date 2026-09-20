#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — STEP 1 DOWNLOAD AND INPUT PREPARATION
# =============================================================================
# This step is driven entirely by config/genomes.tsv.
#
# For each configured assembly it:
#   • reads the exact versioned NCBI accession;
#   • downloads only the genomic FASTA using NCBI Datasets;
#   • unpacks the NCBI archive into a genome-specific temporary directory;
#   • requires exactly one genomic .fna file in the package;
#   • copies that FASTA to a stable data/raw/<short-name>.fna path;
#   • collects all five FASTAs for a single SeqKit statistics table.
#
# After downloading, the script calls 01_parse_genomes.py to create the
# chromosome-only Fol4287/Fo47 files and chromosome metadata used downstream.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
mkdir -p data/raw data/analysis tmp/downloads results logs
LOG="${ROOT}/logs/01_download_genomes.log"
exec > >(tee "${LOG}") 2>&1
CONFIG="config/genomes.tsv"
FASTA_FILES=()

echo "============================================================"
echo "STEP 1: DOWNLOAD EXACT VERSIONED GENOME ASSEMBLIES"
echo "============================================================"

while IFS=$'\t' read -r name accession role host_context circos; do
  [[ "${name}" == "name" ]] && continue
  [[ -z "${name}" ]] && continue
  download_dir="tmp/downloads/${name}"
  archive="${download_dir}/${accession}.zip"
  package_dir="${download_dir}/package"
  final_fasta="data/raw/${name}.fna"
  echo
  echo "Downloading ${name} (${accession})"
  rm -rf "${download_dir}"
  mkdir -p "${download_dir}" "${package_dir}"
  datasets download genome accession "${accession}" --include genome --filename "${archive}"
  unzip -q "${archive}" -d "${package_dir}"
  count="$(find "${package_dir}/ncbi_dataset/data" -type f -name '*.fna' | wc -l | tr -d ' ')"
  if [[ "${count}" -ne 1 ]]; then
    echo "ERROR: expected exactly one genomic FASTA for ${accession}; found ${count}."
    exit 1
  fi
  source_fasta="$(find "${package_dir}/ncbi_dataset/data" -type f -name '*.fna' -print | LC_ALL=C sort | head -n 1)"
  cp "${source_fasta}" "${final_fasta}"
  [[ -s "${final_fasta}" ]] || { echo "ERROR: missing FASTA ${final_fasta}"; exit 1; }
  FASTA_FILES+=("${final_fasta}")
done < "${CONFIG}"

seqkit stats -a -T "${FASTA_FILES[@]}" > results/genome_stats.tsv
python "${SCRIPT_DIR}/01_parse_genomes.py"

echo
seqkit stats data/analysis/Fol4287.chromosomes.fna
seqkit stats data/analysis/Fo47.chromosomes.fna

echo
echo "Downloaded genomes: ${#FASTA_FILES[@]}"
echo "STEP 1 COMPLETE"
