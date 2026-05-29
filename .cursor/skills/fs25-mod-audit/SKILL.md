---
name: fs25-mod-audit
description: >-
  Code-Audit für die Mod FS25_FieldToDoList (Giants/FS25 Lua, Proton/Linux).
  Prüft Runtime-Sicherheit, Engine-API-Korrektheit, Feld-/Frucht-Klassifikation,
  Ernte-/Wachstumslogik, Unkraut-/Gras-Logistik und UI/HUD-Verhalten – verteilt
  auf parallele Subagenten. Verwende dieses Skill, wenn der User die Mod (oder
  Teile davon) auditieren, prüfen, reviewen, checken oder "drüberschauen" will.
---

# FS25_FieldToDoList – Audit-Koordinator

Dieses Skill koordiniert ein strukturiertes Audit der Mod. Es delegiert die
Prüf-Dimensionen an **parallele, readonly Subagenten** (`Task`, `subagent_type: explore`)
und fasst deren Befunde zu einem Report zusammen.

## Wann verwenden
- Voll-Audit der Mod oder eines geänderten Bereichs (z. B. nach einem Refactor).
- Wenn der User „audit / prüfen / review / check / schau mal drüber" zur Mod sagt.

## Scope festlegen (zuerst)
1. **Voll-Audit** (Standard): alle Dimensionen, ganzer `scripts/` + `gui/`.
2. **Diff-Audit**: nur geänderte Dateien. Erst `git status` + `git diff` lesen,
   den Subagenten nur die betroffenen Dateien/Funktionen als Fokus geben.

Wenn unklar, kurz per `AskQuestion` fragen (Voll vs. Diff). Sonst Voll-Audit.

## Pflichtkontext für jeden Subagenten
Jeder Subagent ist readonly und bekommt im Prompt mit:
- Projekt-Memory: `.cursor/rules/fs25-project-memory.mdc` (zuerst lesen).
- Sein Dimensions-Fokus (siehe unten) + die konkret zu prüfenden Dateien.
- Auftrag: **nur Befunde melden** (Datei:Zeile, Schweregrad, kurze Begründung,
  konkreter Fix-Vorschlag). Keine Änderungen vornehmen.

## Ablauf
1. **Init**: `.cursor/rules/fs25-project-memory.mdc` lesen, bei Diff-Audit `git diff`.
2. **Delegation (parallel)**: Die 6 Dimensions-Subagenten in **einer** Nachricht
   starten (`run_in_background: true`, `readonly: true`, `subagent_type: explore`).
3. **Zusammenführen**: Befunde deduplizieren, nach Schweregrad sortieren, Report bauen.
4. **Abschluss**: Report ausgeben, Rückfrage zum Beheben (siehe Report-Format).

Kleines Diff-Audit (1–2 Dateien)? Dann ohne Subagenten direkt prüfen.

---

## Dimensionen (je 1 Subagent)

### 1. Runtime-Sicherheit (Proton / Lua 5.1)
Dateien: alle `scripts/*.lua`, v. a. `FieldSavegameReader.lua`, `ToDoManager.lua`,
`SeasonalCropStressReader.lua`, `InGameMenuIntegration.lua`, `gui/FieldToDoMenuFrame.lua`.
- Kein `goto` / `::label::` (Giants-Runtime ist Lua-5.1-Stil → Datei lädt sonst nicht).
- Kein Laufzeit-Lesen von `savegame*/fields.xml`: `FieldSavegameReader.ENABLE_DISK_READ`
  muss `false` bleiben; `deferReadsUntilGameplay` aktiv; Save/Load-Guards intakt.
- Keine SCS-Feldmap-Loops (`buildFieldMap`/`enumerateFields`) in Menü-/Update-Pfaden.
- Keine wiederholten/Schleifen-Datei-Reads in Menü-/Update-Pfaden; Live-`FieldState`/Engine bevorzugen.
- `Logging.info`/`Logging.warning` statt `print()` (besonders `InGameMenuIntegration`).
- Engine-Calls in `pcall`; keine harten Crashes bei `nil` Globals.

### 2. Engine-API-Korrektheit
Fokus: jede Verwendung von FS-Globals/Manager-APIs.
- **Statische Funktionen ohne `self` aufrufen.** Z. B. `FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)`
  und `DensityMapHeightUtil.getFillLevelAtArea(...)` sind plain functions – NICHT
  `pcall(fn, util, x, z)` (das schiebt `util` als 1. Argument rein). Echte Bug-Klasse.
- Manager-Methoden mit `:`/self korrekt (`g_fruitTypeManager:getFruitTypeByIndex(i)`).
- Argument-Anzahl & -Reihenfolge gegen erwartete Signatur prüfen.
- `rawget(_G, "X")`-Guard vor optionalen Globals (PF, SCS, FSDensityMapUtil).
- Rückgaben mit `tonumber`/Typprüfung absichern; `pcall`-`ok` auswerten.

### 3. Feld- & Frucht-Klassifikation
Dateien: `FieldAdvisor.lua` (`classifyProbe`, `aggregateFieldProbes`,
`resolveGrassFruitTypeIndex`, `refineGrassFruitTypeIndex`, `getFieldFruitDisplayLabel`,
`getLocalizedFruitTitle`), `FieldScanner.lua`.
- Mehrschichtig (`arable`/`grass`/`bare_soil`/`unknown`) auf Basis **mehrerer** Proben,
  nicht nur Center-Sample; Aggregation + dominante Situation.
- Kein blind-grass-Fallback auf bearbeitetem Boden: `PLOWED`/`CULTIVATED`/`SEEDBED`
  ohne aktive Frucht → Frucht `-`, nicht Gras. Frisch gepflügt leer ≠ Gras (Feld-14-Klasse).
- Spezifische Gras-Frucht (Luzerne/Alfalfa/Klee) gewinnt vor generischem GRASS
  (`isGenericGrassFruitIndex`); `FSDensityMapUtil` + Feld-Metadaten als Quelle.
- Anzeige: spezifische Gras-Frucht darf in `getLocalizedFruitTitle` nicht zu „Gras"
  kollabieren (FillType-Titel vs. fruchteigener Name).

### 4. Ernte- & Wachstumslogik
Dateien: `FieldAdvisor.lua` (`evaluateFruitGrowth`, `isCropHarvestReady`,
`getExpectedHarvestPeriod`, `getHarvestWindowHint`, `getCalendarMonthForSeasonPeriod`,
`getCurrentSeasonPeriod`, `isSeasonalGrowthEnabled`).
- Erntereife über `FruitTypeDesc`-APIs (`getIsHarvestReady`, `getIsHarvestable`,
  `getIsCut`, `getIsGrowing`, `getIsWithered`) + min/max-Harvesting-Fallback.
- **Saison-Periode (1..12) ≠ Kalendermonat** – Mapping über `getCalendarMonthForSeasonPeriod`,
  nie Periodenindex direkt als Monat ausgeben.
- Erntemonat zielt auf **volle Reife** (`maxHarvestingGrowthState`), nicht auf das
  frühe Futterfenster (z. B. Grünmais im Sommer). seasonal vs. non-seasonal getrennt.
- `isWithered` → Pflügen/Walzen bleiben in Auto-Complete-Checks unfertig.

### 5. Unkraut & Gras-Logistik
Dateien: `FieldAdvisor.lua` (Weed-/Residue-Funktionen), `FieldTaskCompletion.lua`.
- 5%-Regel: lebendes Unkraut ≤ 5 % → erledigt (`WEED_LIVE_RATIO_DONE_THRESHOLD`).
- Tot/gesprüht erkennen: hoher `weedState` (≥ `WEED_STATE_DEAD_MIN`) bzw. Spritzrest
  ist totes Unkraut, nicht lebend. Feld-weite Abdeckung statt nur Center-Probe.
- Gras-Reststoff-Fluss `loose → swath → (collect/bale/silage) → bale_collect`
  aus Live-Daten (`DensityMapHeightUtil` + Windrow-Fill), kein generischer Rest-Zustand.
- Ballen nur innerhalb des Feldpolygons zählen (field-local).
- Auto-Complete nutzt dieselben Residue-/Bale-Signale wie die Vorschläge.

### 6. UI / To-Do / HUD
Dateien: `gui/FieldToDoMenuFrame.lua` + `.xml`, `ToDoManager.lua`,
`FieldToDoHudOverlay.lua`, `FieldToDoHudInput.lua`.
- To-Do-Reihenfolge per `sortIndex` (User-Order), nicht Work-Order-Presets.
- Hoch/Runter: verschobene Task bleibt selektiert; nach Delete Selektion clearen.
- SmoothList-Reload-Guard (`ignoreTaskSelectionChanged`), Sync per Task-ID statt Row-Index.
- Mini-Button-Labels `Hoch`/`Runter`; kein Drag-and-drop.
- HUD: nur manuelle Tasks (`getManualTasksForDisplay`), max 5 offene; schlichtes Panel.
- Offene Tasks über erledigten; erledigte cap 10; neueste erledigte oben.

---

## Subagent-Prompt-Vorlage
Pro Dimension einen `Task` starten (parallel, readonly):

```
subagent_type: explore   readonly: true   run_in_background: true
description: "FS25 Audit: <Dimension>"
prompt:
  Readonly-Audit der Mod FS25_FieldToDoList in /mnt/Lager/github/LS_25_todo.
  1) Lies .cursor/rules/fs25-project-memory.mdc.
  2) Prüfe NUR Dimension <N: Name>. Relevante Dateien: <Liste>.
     Checkliste: <Punkte aus der Dimension>.
  3) Melde Befunde als Liste: <Datei>:<Zeile> | <🔴/🟠/🟡/⚪> | Problem | Fix-Vorschlag.
  Nimm KEINE Änderungen vor. Wenn ein Bereich sauber ist, melde "ok".
```

Bei Diff-Audit zusätzlich: „Beschränke dich auf diese geänderten Stellen: <Datei:Funktion>."

## Schweregrade
- 🔴 **Bug**: falsches Verhalten / Crash-/Save-Risiko (z. B. Runtime-`fields.xml`-Read,
  Static-Call mit `self`, Saison-Periode als Monat).
- 🟠 **Risiko**: fragil / Regressionsgefahr (fehlender `pcall`, Loop-Reads in Menüpfad).
- 🟡 **Verbesserung**: Logik-/Lesbarkeits-Schliff, Doppelpfade.
- ⚪ **Hinweis**: Stil, Doku, Kleinigkeiten.

## Report-Format
```
# FS25_FieldToDoList – Audit (<Voll|Diff>)

## Zusammenfassung
<1–3 Sätze: Gesamtzustand, Anzahl je Schweregrad>

## Befunde
### 🔴 Bugs
- <Datei:Zeile> – <Problem> → <Fix>
### 🟠 Risiken
- ...
### 🟡 Verbesserungen
- ...
### ⚪ Hinweise
- ...

## Empfehlung
<Reihenfolge zum Beheben>
```
Beende mit: „Soll ich mit den 🔴 Bugs anfangen?"

## Build/Release-Hinweise (für Folge-Fixes)
- `modDesc.xml`-Version **nicht** ändern, außer der User will explizit ein Release.
- Lokaler Build: `python3 tools/generate_assets.py && ./build.sh`.
- Nach Mod-Updates: voller FS25-Neustart.
