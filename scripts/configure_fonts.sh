#!/usr/bin/env bash

# Use only locked Conda fonts.
export FONTCONFIG_PATH="${ROOT}/tmp/fontconfig"
export FONTCONFIG_FILE="${FONTCONFIG_PATH}/fonts.conf"

mkdir -p "${FONTCONFIG_PATH}/cache" || return 1

for name in \
  Ubuntu-R.ttf \
  Ubuntu-B.ttf \
  Ubuntu-RI.ttf \
  Ubuntu-BI.ttf
do
  if [[ ! -f "${ENV_PREFIX}/fonts/${name}" ]]; then
    echo "ERROR: Missing locked font: ${name}" >&2
    return 1
  fi
done

cat > "${FONTCONFIG_FILE}" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>${ENV_PREFIX}/fonts</dir>
  <cachedir>${FONTCONFIG_PATH}/cache</cachedir>
</fontconfig>
EOF

for style in Regular Bold Italic 'Bold Italic'; do
  case "${style}" in
    Regular)      name=Ubuntu-R.ttf ;;
    Bold)         name=Ubuntu-B.ttf ;;
    Italic)       name=Ubuntu-RI.ttf ;;
    'Bold Italic') name=Ubuntu-BI.ttf ;;
  esac

  actual="$(fc-match -f '%{file}' "Ubuntu:style=${style}")" || return 1

  if [[ "${actual}" != "${ENV_PREFIX}/fonts/${name}" ]]; then
    echo "ERROR: Unexpected font: ${actual}" >&2
    return 1
  fi
done

unset name style actual