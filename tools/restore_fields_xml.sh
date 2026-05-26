#!/usr/bin/env bash
# Restore savegame1/fields.xml from the newest non-empty backup.
set -euo pipefail

SAVE_ROOT="${FS25_SAVE_ROOT:-$HOME/.local/share/Steam/steamapps/compatdata/2300320/pfx/drive_c/users/steamuser/Documents/My Games/FarmingSimulator2025}"
TARGET="$SAVE_ROOT/savegame1/fields.xml"
BACKUP_DIR="$SAVE_ROOT/savegameBackup"

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "No backup dir: $BACKUP_DIR"
    exit 1
fi

best=""
best_size=0
for dir in "$BACKUP_DIR"/savegame1_backup*; do
    [[ -d "$dir" ]] || continue
    f="$dir/fields.xml"
    [[ -f "$f" ]] || continue
    size=$(wc -c < "$f")
    if [[ "$size" -gt 64 && "$size" -gt "$best_size" ]]; then
        best="$f"
        best_size=$size
    fi
done

if [[ -z "$best" ]]; then
    echo "No backup with fields.xml > 64 bytes"
    exit 1
fi

cp -a "$best" "$TARGET"
echo "Restored $best ($best_size bytes) -> $TARGET"
