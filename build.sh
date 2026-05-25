#!/usr/bin/env bash
# Deploy FS25_FieldToDoList to the local Farming Simulator 25 mods folder (CachyOS / Arch).
set -euo pipefail

MOD_NAME="FS25_FieldToDoList"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/.build"
ZIP_PATH="${BUILD_DIR}/${MOD_NAME}.zip"

# Default FS25 user mod path on Linux; override with FS25_MODS_DIR if needed.
FS25_MODS_DIR="${FS25_MODS_DIR:-${HOME}/.local/share/Steam/steamapps/compatdata/2300320/pfx/drive_c/users/steamuser/Documents/My Games/FarmingSimulator2025/mods/}"

echo "==> Building ${MOD_NAME}"

if [[ -f "${SCRIPT_DIR}/tools/generate_assets.py" ]]; then
    if python3 "${SCRIPT_DIR}/tools/generate_assets.py"; then
        echo "==> Assets generated (SVG → DDS)"
    else
        echo "warning: asset generation failed — install ImageMagick and/or rsvg-convert" >&2
    fi
fi

if [[ ! -f "${SCRIPT_DIR}/modDesc.xml" ]]; then
    echo "error: modDesc.xml not found in ${SCRIPT_DIR}" >&2
    exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/icon.dds" ]]; then
    echo "warning: icon.dds missing — run: python3 tools/generate_assets.py" >&2
fi

if [[ ! -f "${SCRIPT_DIR}/gui/menuIcon.dds" ]]; then
    echo "warning: gui/menuIcon.dds missing — ESC tab icon will fallback or look wrong" >&2
fi

for icon in add edit done delete; do
    if [[ ! -f "${SCRIPT_DIR}/gui/icons/${icon}.dds" ]]; then
        echo "warning: gui/icons/${icon}.dds missing — run: python3 tools/generate_assets.py" >&2
    fi
done

mkdir -p "${BUILD_DIR}"
rm -f "${ZIP_PATH}"

create_zip() {
    # Ship runtime assets only: FS loads DDS + GUI XML/Lua, not SVG sources or unused icon DDS.
    local zip_entries=(
        modDesc.xml
        icon.dds
        gui/menuIcon.dds
        gui/icons/add.dds
        gui/icons/edit.dds
        gui/icons/done.dds
        gui/icons/delete.dds
        gui/FieldToDoMenuFrame.xml
        gui/FieldToDoMenuFrame.lua
        scripts
        translations
    )

    if command -v zip >/dev/null 2>&1; then
        (
            cd "${SCRIPT_DIR}"
            zip -r "${ZIP_PATH}" "${zip_entries[@]}"
        )
        return
    fi

    python3 - "${SCRIPT_DIR}" "${ZIP_PATH}" <<'PY'
import sys
import zipfile
from pathlib import Path

root = Path(sys.argv[1])
out = Path(sys.argv[2])
entries = [
    "modDesc.xml",
    "icon.dds",
    "gui/menuIcon.dds",
    "gui/icons/add.dds",
    "gui/icons/edit.dds",
    "gui/icons/done.dds",
    "gui/icons/delete.dds",
    "gui/FieldToDoMenuFrame.xml",
    "gui/FieldToDoMenuFrame.lua",
    "scripts",
    "translations",
]

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    for name in entries:
        path = root / name
        if path.is_dir():
            for file in sorted(path.rglob("*")):
                if file.is_file():
                    zf.write(file, file.relative_to(root).as_posix())
        elif path.is_file():
            zf.write(path, path.relative_to(root).as_posix())
        else:
            print(f"warning: missing zip entry {path}", file=sys.stderr)
PY
}

create_zip

verify_zip_contents() {
    local zip_path="$1"
    local forbidden
    forbidden="$(unzip -Z1 "${zip_path}" 2>/dev/null | grep -E '\.svg$' || true)"
    if [[ -n "${forbidden}" ]]; then
        echo "error: zip must not contain SVG sources:" >&2
        echo "${forbidden}" >&2
        exit 1
    fi
}

if command -v unzip >/dev/null 2>&1; then
    verify_zip_contents "${ZIP_PATH}"
fi

if [[ "${SKIP_INSTALL:-0}" == "1" ]]; then
    echo "==> Built: ${ZIP_PATH} (SKIP_INSTALL=1, not copying to local mods folder)"
    exit 0
fi

mkdir -p "${FS25_MODS_DIR}"
cp -f "${ZIP_PATH}" "${FS25_MODS_DIR}/${MOD_NAME}.zip"

echo "==> Installed: ${FS25_MODS_DIR}/${MOD_NAME}.zip"
