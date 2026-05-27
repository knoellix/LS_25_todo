# Changelog

All notable changes to **FS25_FieldToDoList** are documented here.

## [0.1.0.3] — 2026-05-27

### Improved

- Field crop and ground detection uses live `FieldState` samples (more reliable than stale cached values).
- Grass/meadow handling: mow when harvest-ready; clearer post-mow hints (swath, collect, bale); reduced false “sow” on meadows.
- Plowed/cultivated ground is prioritized over leftover grass metadata in the fruit column.

### Fixed

- Field overview stability on Proton/Linux (no runtime read of savegame `fields.xml` — avoids save corruption risk).
- Lua compatibility fix that could hide all owned fields in the overview.

### Docs

- `CONTRIBUTING.md`, translation issue template, README updates.
- Repository renamed to `FS25_FieldToDoList` on GitHub.

### Known limitations

- Auto-completion still work in progress; needs more testing on real savegames.
- Some edge cases in grass classification after soil work may still need tuning.

## [0.1.0.2] — earlier pre-release

- Previous public pre-release on GitHub.

## [0.1.0.1] — earlier pre-release

- Initial public pre-release: ESC to-do list, field overview, HUD, work-order presets, PF/SCS columns (limited), grass-aware suggestions.

[0.1.0.3]: https://github.com/knoellix/FS25_FieldToDoList/compare/v0.1.0.2...v0.1.0.3
[0.1.0.2]: https://github.com/knoellix/FS25_FieldToDoList/releases/tag/v0.1.0.2
