# M1 implementation log

This tracks *build* status against the *existing* spec — it does not redefine scope. The
governing documents remain [the rack editor spec](04-rack-editor.md) and
[the roadmap](09-roadmap.md); this file exists because M1 is being built across many separate
sessions and stages, and a checklist that only lives in chat history is exactly the kind of
thing that lets a "standard" feature quietly fall through the cracks. Update it at the end of
every M1 stage: move items from **Not started** to **Done**, and add anything a stage
deliberately deferred that isn't already listed below.

Status legend: **Done** (built and tested) · **Partial** (some of the cited behavior works) ·
**Not started**.

---

## 1. Against the roadmap's M1 checklist (docs/09-roadmap.md, line ~223)

| # | Item | Status |
|---|---|---|
| 1 | `ViewportController` with wheel/trackpad/pan/zoom and the grid painter | **Done** |
| 2 | `CanvasIntent` on top, no `PointerDeviceKind` branching | **Done** |
| 3 | Hybrid `RenderRackCanvas`, device widgets, RU snapping, front/rear elevations with per-rack mirroring | **Partial** — RU snapping and front/rear filtering done; **mirroring not done** |
| 4 | Quick-add by typing with the drop caret; the Staging Bin; shelves with auto-pack; 0U occupants from the inspector | **Not started** |
| 5 | Compact Up/Down with preview-then-accept, and the shrink-rack dialog; locks | **Not started** |
| 6 | The full seeded catalog (incl. 18 field devices, `sources.md` provenance, connector-footprint CI assertion) | **Not started** — still 4 hand-built demo devices |
| 7 | Copy-on-place with `DeviceOverrides`; the chip strip (RU, weight, VA, outlets) with unknown counts | **Not started** |
| 8 | `DiagramCanvas` + `SceneBuilder` + both backends + the baseline-Y parity test | **Done** — mutation-tested twice |
| 9 | Minimal PDF exporter: front elevation, rear elevation, `T6.30`, title block, revision block | **Not started** |
| 10 | Atomic save, autosave, recovery, recents, close interception; the outline tree; four starter projects | **Not started** |

---

## 2. Against the rack editor spec (docs/04-rack-editor.md), section by section

### §1 Screen layout
- [ ] Palette panel (280 px, collapsible, search, categories) — **not started**
- [ ] Inspector panel (320 px, selection section + Rack Vitals) — **not started**
- [ ] Validation drawer (28 px, auto-expands on first error) — **not started**
- [ ] Status bar (cursor context, zoom, selection rollup, project counts) — **partial**: zoom HUD only
- [x] Toolbar view switch (`Ctrl+1..4`) — **not started** (only one screen exists, no tab strip)
- [x] Face segmented control — **done** (Front/Rear toggle; "Both" view not built)
- [ ] Tablet collapse below 1080 px (read-only shell) — **not started**

### §2 The rack canvas
- [x] RU ruler with bottom-origin numbering, per-rack `ruNumbering` — **done**
- [ ] Real rail hole geometry + ear screws at zoom ≥ 0.75 — **not started** (flat placeholder fill)
- [x] LOD tiers below 0.75 (block / dotted-texture-placeholder) — **done**
- [ ] LOD tier ≥ 0.75 (holes, ear screws, port badges) and ≥ 1.50 (rear port strip, weight
      microtext, PDU outlet map) — **not started**
- [x] Front / Rear as a coordinate switch — **done**
- [ ] "Both" view (mirrored side-by-side) — **not started**
- [ ] Rear mirroring (`Rack.mirrorRearElevation`) + the "NOT MIRRORED" chip — **not started**
- [ ] `chassisRotation` reversed-face badge (↺) — **not started**
- [ ] Multiple racks laid out left-to-right by `Rack.order` — **not started** (one hardcoded rack)
- [ ] Wall-mounted rack offset/hatch rendering — **not started**

### §3 Placement
- [ ] §3.1 Drag from palette to rails (arm/lift/enter-canvas/snap/evaluate/commit), incl. the
      seven-check drop evaluation table and blocked-drop rendering — **not started** (no palette)
- [ ] §3.2 Faster paths: `/` search-and-place, double-click palette row, double-click empty U
      quick-insert popover, `Ctrl+Alt+I` insert dialog, right-click empty-U menu — **not started**
- [x] §3.3 Moving a placed device: grab, drag, commit `MoveDeviceCommand` — **done** (basic case)
  - [ ] Cross-rack move (drag past 60 px beyond a rail) — **not started**
  - [ ] `Ctrl` at drag start = duplicate — **not started**
  - [ ] `Alt` at drop = insert-and-push (displaces occupants) — **not started**
  - [ ] `Ctrl+Shift` at drop over an equal-height device = swap — **not started**
  - [ ] Live blocked-drop ghost rendering *during* the drag — **not started** (commit-time
        silent refusal only, no ghost/hatch/reason-chip feedback while dragging)
  - [ ] Lateral `Width position` dropdown (Full/Left half/Right half) — **not started** (model
        already carries `startTwelfth`/`spanTwelfths`; no UI)
- [ ] §3.4 Insertion caret (first-class object) + keyboard nudge (`↑↓`, `Shift`, `Ctrl`, `Alt`,
      `Home/End`, `PgUp/PgDn`), with 500 ms nudge coalescing — **not started**
- [x] §3.5 Selection: click replaces, `Ctrl+click` toggles — **done**
  - [ ] `Shift+click` range-select within a rack — **not started**
  - [ ] Marquee (left-drag on empty canvas, window vs. crossing) — **not started**
  - [ ] `Ctrl+A` select-all (rack, then project) — **not started**
  - [ ] Multi-select combined ruler bracket + status-bar rollup — **not started**
  - [ ] `Ctrl+L` lock / unlock — **not started**
  - [x] Delete (zero-connection immediate; confirm bar for ≥1 connection not built since no
        Links exist yet) — **done** (immediate delete only; the confirm-bar case is unreachable
        until M2 wiring exists)
  - [ ] Copy/Cut/Paste/Paste-in-place/Duplicate (`Ctrl+C/X/V/Shift+V/D`) — **not started**
- [ ] §3.6 Compact Up / Compact Down with preview overlay — **not started**

### §4 Rack configuration
- [ ] `RackInspector` panel (name, designator, location, form factor, height, width, usable
      depth, rail type, weight cap, mount, swing frame, ground bar) — **not started**
- [ ] Three ways to change height (stepper / field / drag top edge) — **not started**
- [ ] Shrink-below-occupancy modal (compact-first / move-to-bin / keep-larger, trim
      from top/bottom) — **not started**
- [ ] Rack presets (wall box, swing gate, floor enclosure, etc.) — **not started**
- [ ] Circuits panel (flat, filtered by `rackId`) — **not started**

### §5 Derived readouts
- [ ] Always-visible chip strip (RU, weight, VA, outlets, each with an unknown-count
      superscript) — **not started**
- [ ] Collapsed Rack Vitals panel (space bars, weight bar, power bar, BTU/CG advisory) —
      **not started**
- [ ] Findings surfacing: device badge (shape+colour), rack-header `⚠n` rollup, validation
      drawer with select-and-zoom — **not started** (no validation rules run yet at all — that's
      `derived/validation.dart`, not built in any stage so far)

### §6 Non-device occupants
- [ ] Blanks, vents, fans, patch panels, PDU/UPS, rear lace bar as ordinary templates with
      `OccupancySide` — **not started** (occupancy side exists in the model; no such templates
      or palette to place them from)
- [ ] 0U vertical occupants (`ZeroUPlacement`, inspector-edited, no drag) — **not started**
- [ ] Shelves and hosted devices (drop-onto-shelf, auto-pack, capacity bar, leaving-shelf
      gesture, delete-shelf prompt) — **not started**

### §7 Naming and designators
- [x] `designator` and `name` exist as data fields — **done** (model only)
- [ ] `F2` inline designator edit / `Ctrl+F2` name edit — **not started**
- [ ] Auto-assignment via the `idformat` engine on device creation (`{TYPE_PREFIX}{SEP}{SEQ}`)
      — **not started** (demo devices have hand-typed designators; `AddDeviceCommand` does not
      yet call the idformat engine — confirm/build when the catalog/creation-UI stage lands)
- [ ] Collision UI (`[Swap] [Go to]`) — **not started**
- [ ] `Ctrl+R` Renumber dialog with diff preview — **not started**
- [ ] Project-level Locations panel — **not started**

### §8 Keymap
- [x] `Del`/`Backspace` — **done**
- [x] `Ctrl+Z` / `Ctrl+Shift+Z` / `Ctrl+Y` — **done**
- [ ] Everything else in the ~40-binding table (`Ctrl+1..4`, `Ctrl+0/9/Alt+0`, `Ctrl+K/F/G`,
      `Ctrl+P/E`, `Ctrl+Shift+F`, `/`, `Enter`, arrow-key family, `Home/End/PgUp/PgDn`, `←→`
      cross-rack, `Ctrl+L`, `Ctrl+R`, `Ctrl+D`, `Ctrl+X/C/V/Shift+V`, `G`, `L`, `Ctrl+Shift+W`,
      `F2`/`Ctrl+F2`, `Ctrl+Alt+U/N`, `U`, `Ctrl+Alt+1/2/3`, `F7/F8/Shift+F8`) — **not started**.
      Generated `build/keymap.md` from one `Intent` registry (CR-101) is itself not started —
      today's shortcuts are wired ad hoc in `RackCanvasScreen`, not through a registry.

### §9 Empty state, first run, accessibility
- [ ] Start card + four starter projects (also needed as goldens/perf fixtures/screenshot
      source, per AC-052) — **not started**
- [ ] New-rack dialog (Name/Preset/Height) — **not started**
- [ ] Empty-rack hint card, other 7 empty states — **not started**
- [ ] Coach marks (first placement, first finding, first rack→schematic switch) — **not started**
- [x] Per-device `Semantics` label (designator + name + type) — **done**
- [ ] Outline tree (`Ctrl+Alt+3`), the primary AT surface — **not started**
- [ ] Full keyboard focus-region cycling (`F6`/`Shift+F6`/`Ctrl+F6`), spoken caret announcements,
      `disableAnimations` handling, hit-target sizing audit — **not started**

---

## 3. What M0/M1 has actually shipped so far (commit-level, for orientation)

Chronological, oldest first — see `git log --oneline` for the full history:

1. `chore: scaffold the five-package workspace (M0)`
2. `feat(core): implement rackmate_core through M0's command/undo system`
3. `feat(app): Windows desktop platform scaffolding; first build/run confirmed`
4. `feat(core): the shared DiagramCanvas drawing IR (M1, CR-086/CR-081)`
5. `feat(export): PdfDiagramCanvas and the concrete PdfFontMeasurer (M1)`
6. `feat(ui): FlutterDiagramCanvas, the on-screen backend (M1, CR-086)`
7. `test(app): the baseline-Y screen/print parity gate (M1, CR-081/CR-086)`
8. `feat(ui): ViewportController, grid painter, CanvasIntent (M1 walking skeleton)`
9. `feat(canvas): the rack scene builder and RenderRackCanvas (M1, CR-086)`
10. `style: swap the bundled font from IBM Plex Sans to Jost`
11. `feat(canvas): select, move, delete and undo -- routed through real commands`

288 tests passing across the workspace as of commit 11 (133 core + 42 ui + 13 app, plus the
rendering-spine packages' own suites).

---

## 4. Suggested next order

Roughly in the order that unblocks the most subsequent work, not a commitment:

1. **Seeded catalog + palette** (roadmap item 6) — replaces the 4 hand-built demo devices with
   real data and gives placement something to draw from. Blocks quick-add and drag-from-palette.
2. **Quick-add by typing + insertion caret + keyboard nudge** (roadmap item 4, §3.2/§3.4) — the
   fastest path to populating a rack and the one the exit criterion's "20 devices in under four
   minutes, keyboard only" is actually measuring.
3. **Rack configuration UI** (§4) — height changes, the shrink dialog, presets. Needed before a
   user can create a rack that isn't hardcoded.
4. **Chip strip + Rack Vitals + validation rules** (§5) — the first of the 27 v1 DRC rules
   (`derived/validation.dart` doesn't exist yet in any package).
5. **Non-device occupants + shelves + 0U** (§6).
6. **Compaction** (§3.6).
7. **Naming/designator UI + idformat wiring** (§7).
8. **Persistence wiring + starter projects** (roadmap item 10) — needed regardless of interaction
   completeness, since the exit criterion requires opening/saving real files.
9. **Minimal PDF exporter** (roadmap item 9) — the rendering spine already exists; this is sheet
   assembly on top of it.
10. **Remaining keymap + accessibility + empty states** (§8/§9) — can land incrementally
    alongside any of the above rather than as one dedicated pass.
