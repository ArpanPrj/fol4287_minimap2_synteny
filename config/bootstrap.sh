#!/usr/bin/env bash
# =============================================================================
# ANNOTATION GUIDE — BOOTSTRAP PATH CONFIGURATION
# =============================================================================
# This file performs no installation itself. It only defines values used by
# setup.sh and scripts/common.sh.
#
# MINIFORGE_VERSION pins the bootstrap distribution.
# SOFTWARE_ROOT chooses an external cache location under the user's home folder
# unless the optional FOL4287_MINIMAP2_SOFTWARE_DIR variable overrides it.
# Keeping the Conda environment outside the repository avoids committing huge
# software directories and avoids poor performance when a WSL project sits on a
# Windows-mounted drive.
# =============================================================================
MINIFORGE_VERSION="26.7.2-0"
SOFTWARE_ROOT="${FOL4287_MINIMAP2_SOFTWARE_DIR:-${HOME}/.cache/fol4287_minimap2_synteny}"
MINIFORGE_PREFIX="${SOFTWARE_ROOT}/miniforge-${MINIFORGE_VERSION}"
ENV_PREFIX="${SOFTWARE_ROOT}/environment"
