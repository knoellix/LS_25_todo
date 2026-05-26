#!/usr/bin/env bash
# Kill orphaned GOverlay/Gamescope reapers that still reference FS25 after the game exited.
set -euo pipefail

PATTERN='gamescopereaper.*Farming Simulator 25|FarmingSimulator2025\.exe'

echo "Before:"
pgrep -af "$PATTERN" || echo "  (none)"

pkill -9 -f 'gamescopereaper.*Farming Simulator 25' 2>/dev/null || true
pkill -9 -f 'FarmingSimulator2025.exe' 2>/dev/null || true

sleep 1

echo "After:"
if pgrep -af "$PATTERN" >/dev/null; then
    echo "Still running — try: steam quit, then run this script again."
    pgrep -af "$PATTERN"
    exit 1
fi

echo "  (none) — OK"

SAVE="${FS25_SAVEGAME_DIR:-$HOME/.local/share/Steam/steamapps/compatdata/2300320/pfx/drive_c/users/steamuser/Documents/My Games/FarmingSimulator2025/savegame1}"
FIELDS="$SAVE/fields.xml"
if [[ -f "$FIELDS" ]]; then
    echo "fields.xml: $(wc -c < "$FIELDS") bytes — $FIELDS"
else
    echo "fields.xml: missing — $FIELDS"
fi
