# FS25_FieldToDoList

**To-Do and field work list** for Farming Simulator 25 — track your own tasks, see what to do next on each owned field, optional Precision Farming and Seasonal Crop Stress columns.

**Author:** Christian Möllmann ([knoellix](https://github.com/knoellix))  
**License:** [GNU GPL v3](LICENSE)  
**Version:** `0.1.0.1`

## Features

- **ESC menu** (dedicated tab): manual to-dos on the left, owned fields with crop status and suggested work on the right
- **In-world HUD:** `Left Ctrl + F5` — compact list of open tasks (top right, up to 5 entries)
- **Work order:** presets (e.g. plow → lime → sow → fertilize) and **alternating manure/slurry** for organic multi-pass spreading
- **Field workflow:** adopt suggestions, visit field (teleport), auto-complete when the game detects the job is done
- **List order:** `Hoch` / `Runter` mini buttons (`^` / `v`) move the selected task (no drag-and-drop in the Giants UI)
- **Done behavior:** completed tasks are grouped below open tasks; newly completed go to the top of the done group; max 10 completed (oldest pruned)
- **Selection UX:** after move, the moved task stays selected; after delete, selection is cleared
- **Harvest hints:** field suggestion column shows month labels instead of ambiguous month counts
- **Save data:** `fieldToDoList.xml` in the savegame folder (tasks debounced ~2 s after edits; settings saved immediately)

## Optional mods


| Mod                                                                                       | Status                                                                                 |
| ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| FS25_precisionFarming                                                                     | Supported — pH / nitrogen columns when PF is loaded                                    |
| [FS25_SeasonalCropStress](https://github.com/TheCodingDad-TisonK/FS25_SeasonalCropStress) | Partial / limited — moisture and stress columns may show `-` or loading; no full runtime integration yet |


Works fully without add-ons using base game field data.

## Installation

1. Download `FS25_FieldToDoList.zip` from the [latest release](https://github.com/knoellix/LS_25_todo/releases/latest).
2. Copy the ZIP (**do not extract**) to your mods folder:


| Platform               | Path                                                                                                                          |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Windows                | `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods\`                                                                 |
| macOS                  | `~/Library/Application Support/FarmingSimulator2025/mods/`                                                                    |
| Linux (Steam / Proton) | `~/.local/share/Steam/steamapps/compatdata/2300320/pfx/drive_c/users/steamuser/Documents/My Games/FarmingSimulator2025/mods/` |

1. Enable **Field To-Do List** in the in-game mod manager.
2. Load any career save — the mod activates automatically on load.
3. **Restart the game completely** after installing or updating the mod.

## Development

Build from source and install to your local mods folder:

```bash
python3 tools/generate_assets.py   # optional if DDS assets are missing
./build.sh
```

Default target (Linux Steam/Proton):
`~/.local/share/Steam/steamapps/compatdata/2300320/pfx/drive_c/users/steamuser/Documents/My Games/FarmingSimulator2025/mods/FS25_FieldToDoList.zip`

Custom target:

```bash
FS25_MODS_DIR=/path/to/mods ./build.sh
```

## Contributing

Contributions are welcome (bugfixes, features, translations).

- Start here: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Translation workflow: [Open translation issue](https://github.com/knoellix/LS_25_todo/issues/new?template=translation.yml)
- General bugs/features: [GitHub Issues](https://github.com/knoellix/LS_25_todo/issues)

## Issues

Use issue templates for bug reports, feature requests, and translations:
[GitHub Issues](https://github.com/knoellix/LS_25_todo/issues)

## Current Work In Progress

- Grass workflow is currently being refined (detection and suggestion quality across different grass/meadow states).
- Auto-completion is still work in progress and needs broader real-save testing.

## License

Copyright (C) 2026 Christian Möllmann (knoelliX).  
Released under the GNU General Public License v3 — see [LICENSE](LICENSE).