# PDF Export

The PDF is the artifact that leaves the office. Everything upstream of it (the rack, the schematic, the device builder) is data entry whose purpose is to make this file correct by construction rather than by proofreading (canon §8). This document specifies the sheet set and its ordering, the wiring schedule's two presets down to column widths and pagination, the cable-ID scheme, the greyscale strategy, sheet furniture, page setup, the export UX, and (at greatest length, because it is the only part that is expensive to change later) the shared renderer that guarantees the screen and the print are the same drawing. Read [Architecture](03-architecture.md) for the package boundaries this depends on and [Data model](02-data-model.md) for the entities named throughout.

---

## 1. The five rules the rest of this follows from

| # | Rule | Ruling | Enforced by |
|---|---|---|---|
| **P1** | **One renderer.** Every mark on a sheet (traces, device blocks, symbols, borders, title block, zone band, legend swatches) is produced by one body of code targeting an abstract `DiagramCanvas`. | CR-086, D4 | §8. The parity test replays one `DiagramScene` through both backends. |
| **P2** | **True vector, always.** No `RepaintBoundary`, no `toImage`, no PNG-in-PDF for anything a user reads. | §6.3 | **No raster anywhere.** The document is 100% vector; there is no image path in the interface (RJ-017, AC-057). |
| **P3** | **The renderer compiles without Flutter.** `dart test`, not `flutter test`, builds a full document. | CR-083 | `no_flutter_import_test` bans `package:flutter/`, `dart:ui` and `package:pdf/` in `rackpal_core`. |
| **P4** | **Colour is never the only encoding.** Four channels: hue, dash, weight, glyph, plus the tag text. | AC-054, PAL-1 | §5. |
| **P5** | **Emitted identifiers are facts about the physical world.** A designator that has been printed exists on a label in a wall. Stored at allocation, never recomputed at render time. | CR-048, CR-034 | §4. |

And one governing constraint that outranks all of them:

> **Nothing blocks the bytes.** `blockExportOnErrors` is deleted, not deferred (CR-022). Open findings gate exactly one thing — the `ISSUED FOR CONSTRUCTION` stamp and the revision block's issued flag (`ExportSpec.issuedForConstruction`). A heuristic may never hold a user's deliverable hostage (G3). Every export emits sheet `T0.02`, so the errors travel *with* the document instead of preventing it.

---

## 2. The sheet set

### 2.1 Sheet identity vs sheet numbering

Every sheet carries a stable NCS identifier (`[Discipline][SheetType].[Sequence]`, discipline `T` for Telecommunications) that this document, the code, and the test fixtures use as its name. What the *title block prints* is governed by `ProjectSettings.sheetNumbering` (CR-066):

- **`simple`** (default), `SHEET 5 OF 14 · INTERCONNECT — VIDEO`. A residential set is four to eight pages; failing validation on a naming convention built for 200-sheet construction documents is the nannying that pushes users to export a PNG into Word.
- **`ncs`**: the NCS number is printed and validated against `^[A-Z]{1,2}\d\.\d{2}$`. Default for projects created from a commercial starter.

Rejected: making NCS mandatory (design-data-model.md I-40). The exporter auto-fills each non-legend sheet's `SYMBOL LEGEND: SEE SHEET …` field with whatever number the legend sheet actually bears under the active scheme, never an invariant, never a gate (CR-023).

### 2.2 The v1 sheets, in order

This is the v1 sheet set. Canon §7.2.7's eight-item list is a summary, not a ceiling; `T0.00`, `T6.20` and `T5.01` are v1 (canon §4.3, CR-073, DR-005). `Default` is `ON` (always emitted), `AUTO` (emitted iff the data exists), or `PRESET` (only in a named preset).

| # | Sheet | ID | Default | Contents |
|---|---|---|---|---|
| 1 | **Cover & Drawing Index** | `T0.00` | ON | `ProjectInfo`: client, site address, integrator block, drawing number, issue date, current revision. Scope narrative (one editable paragraph). Drawing index generated **after** the sheet list resolves, so it can never reference a sheet that is not in the file. Rack summary strip: per `Rack`, designator, `heightU`, device count, populated RU, total mass, total draw, with an explicit unknown count (G4). |
| 2 | **Symbol Legend** | `T0.01` | ON | **One row per named cable type**, not per domain, each showing that type's exact rendering (hue, dash, weight, glyph, tag) in colour **and greyscale side by side** (AC-054). Connector symbol table at drawing scale. Device-block anatomy callout. `LifecycleStatus` border conventions. Designator conventions (`W###` cable, `J##` port, `P###` cable end per ASME Y14.44). The active ID templates with a worked decomposition. Abbreviations and general notes. |
| 3 | **Exceptions & Acknowledgements** | `T0.02` | ON | Every open `Finding` with rule ID, severity and locus; every `AckedFinding` with its reason, author and date. This is where "the reason prints", a promise three design documents made and no sheet list honoured (CR-022). Emitted even when empty, stating so. |
| 3a | **Device Location Plan** | `T1.01`… | AUTO | docs/15 §8. One per `PlanUnderlay` that carries at least one pin; an imported-but-unused underlay prints nothing. The screened underlay fitted to the sheet, a marker per pin, and (owed) callouts, the drawn scale bar and the per-plan device schedule. **ANSI B landscape**, because a building is wide and the exit criterion prints at ANSI B. **BUILT AT `PLAN-H/1`, 2026-09-09.** **This table had no row for it at all** until then, while docs/15 §8 carried the slot: a derived document missing a sheet the design document ships. Its position is a ruling and not a number, DR-149 §11.148.3, and this table is the evidence that the set is not ordered numerically anyway (`T5.01` sits last at n+5) |
| 4 | **Rack Elevation: Front** | `T2.01` | ON | One per `Rack`. RU ruler both edges per `Rack.ruNumbering`; device blocks with `designator`, name, model, RU span (`4U · 12–15`), `lifecycleStatus` border; cumulative mass from the bottom up, draw, and BTU/hr in the gutter; blanks, vents and shelves as hatched bands. |
| 5 | **Rack Elevation: Rear** | `T2.02` | ON | Same frame, rear faces, mirrored per `Rack.mirrorRearElevation`, connector fields drawn from the template footprints, every port labelled with its `designator` and the `Link.designator` landing on it. The rear panel **prints** in v1; the interactive Rear Panel view is v1.1 (CR-071). |
| 6..n | **Interconnect** | `T6.01`… | ON | One sheet per **domain partition** of the single schematic `Sheet` (CR-073). Order: Video, Audio, Network, Control, Power, Structure. A domain with zero `Link`s produces no sheet. This is partition at export, not multi-sheet authoring, which is never built (DR-004, canon §11.4.3). |
| n+1 | **Pull Sheet** | `T6.10` | ON | §3. Portrait, sorted room then pathway, `fieldCable` only. |
| n+2 | **Termination Schedule** | `T6.11` | ON | §3. Landscape, sorted rack then panel then port. |
| n+3 | **Unused Home Runs** | `T6.20` | AUTO | Home-run `Link`s whose rack end is an `OpenEndpoint`, a real deliverable and a differentiator; keep the name (canon §4.3). On iff ≥1 exists. |
| n+4 | **Equipment List and Materials** | `T6.30` | ON | Qty · designators · manufacturer · model · description · RU · rack · location · face · mass · draw · `lifecycleStatus` · notes, grouped by rack then RU descending, with passives (the `Passive & Mechanical` category) listed instead in a **MATERIALS** section at the end by item, quantity and rack (DR-211, DR-213); a rack's subtotal still counts them and says so. Plus the **cable footage rollup by media with waste factor** (AC-024), the hardware implied by rules (ear kits, rear supports), the jumper/power-cord rollup by media + length + colour, and the PDU **outlet map** that AC-026 keeps off the cable schedule. **No pricing**: `Money`, `cost`, `supplier` and `purchaseOrder` do not exist in v1 (AC-055). Never called a BOM. |
| n+5 | **Plate, Panel & Pinout Details** | `T5.01` | AUTO | On iff any non-standard pinout exists: null-modem RS-232, IR pinout variant, Euroblock role map, or a cable whose wiring standard DIFFERS FROM THE PROJECT'S (DR-180 §11.179.4; `wiringStandardExceptions` is that list). This row read "non-default T568A" until that ruling, which is the same test stated against an assumed default: a job that states T568A everywhere is not a job full of exceptions, and a job that has stated nothing has no default for a cable to be non-. |

**How the interconnect sheets render.** Interconnect sheets render **`drawn`**, orthogonal polylines with a tag pill at each end, because a domain partition is a domain filter (DR-001, canon §11.1.2). The unfiltered all-domains schematic, which renders as net labels on screen, is not an exported sheet. `ExportSpec.wireRender: auto | netLabels | drawn`, default `auto`; `drawn` degrades to `netLabels` above a per-sheet `Link` count **and prints a note on the sheet saying so**: never silently.

**Not in v1, and this is a ruling, not an omission.** `T6.40` Power Schedule appears in `design-pdf-export.md §1.1` and is absent from canon §7.2.7; it defers to v1.1, and the PDU outlet map that AC-026 depends on rides on `T6.30` instead. **`T6.50` Network/IP Schedule NO LONGER DEFERS**: DR-048 (canon §11.47) moves it into v1, in M6, as an `AUTO` slot emitted iff at least one device carries a network value. The two parted company because `NetworkConfig` has been in the format since M0 while the power data is not, so `T6.50` is a sheet over data the model already holds and `T6.40` would be a sheet plus the model to feed it. **The datasheet appendix NO LONGER DEFERS TO v2; it is never built** (DR-051, canon §11.50, §12.21). The reason stated here is real and is reaffirmed: the `pdf` package writes documents, it does not import pages. What made it a refusal rather than a deferral is a ground this sentence never carried, namely that manufacturer manuals are copyrighted and redistributing them inside a file emailed to clients is redistribution, which no release date changes. **What ships instead is a citation on `TemplateBody`**: URL, title, revision and a retrieved-on date, printed here and on the equipment list. A "SYSTEM OVERVIEW, all devices" sheet is **deleted**: twenty symbols at the schematic's own sizing rules consume 84% of an ANSI B sheet before a wire is drawn, and shipping an illegible sheet sets an expectation the product cannot meet (CR-074). The cover's rack summary strip serves that purpose honestly.

### 2.3 Why the exporter partitions, and what that deletes

The most consequential export ruling is CR-073: **one schematic `Sheet` entity exists in the document; the exporter emits N sheets by filtering it by domain.** The `Sheet` entity ships in v1 so the format never migrates (G5), and exactly one is created per project.

The load-bearing observation, from `critique-ux-simplicity.md`:

> A cable belongs to exactly one signal domain, therefore a **domain partition produces zero cross-sheet connections by construction.**

So the entire apparatus that `design-pdf-export.md §5.4` budgeted for (paired pentagon off-sheet flags, the second placement pass, cross-reference resolution, min-cut cost functions, match lines, key plans) **is not built in v1**. Devices simply repeat across sheets, identified by their `designator`. Four to six engineering weeks removed (canon §7.7 cut #1). What survives: the zone grid, because it is ~30 lines and the schedule's `REF` column is genuinely useful for finding a run on a sheet; and `TilingStrategy.geometric`, for the single case of one over-tall rack elevation.

Rejected alternative: shipping user-facing multi-sheet in v1 (`design-ux-schematic.md §4.5`), which also carried a graph min-cut partitioner and by-rack tiling. **Multi-sheet authoring is never built** (DR-004): one schematic `Sheet` plus domain filtering, permanently. Match lines, off-sheet connectors, sheet-boundary link handling and schematic PDF tiling are deleted from the plan, not deferred. The `Sheet` entity nonetheless remains in the schema (AC-037) so the file format never migrates if that is ever reversed; it is not vestigial and must not be described as removable.

Do not read "N sheets come out of the PDF" as evidence that multi-sheet exists. Exporter domain partition and multi-sheet authoring are different things: the first ships in v1 unchanged (CR-073), the second never ships.

### 2.4 Presets

Presets are the primary UI; the per-sheet checkbox list sits behind a disclosure triangle.

| Preset | Sheets | Overrides |
|---|---|---|
| **Full set** (default) | every resolved sheet | — |
| **Installer set** | Full set, rear elevation forced ON | `palette: greyscale` (CR-077), sign-off columns ON, zebra OFF |
| **Client set** | Cover, Legend, front elevations, interconnect with symbols collapsed and no port stubs, Equipment List | `palette: colour`, `Link` designators hidden on traces, NOTES column hidden |
| **This sheet only** | the sheet currently open | furniture unchanged |
| **As-built** | Full set | revision block populated from `RevisionEntry` history, `roughInStatus` column ON, `AS BUILT` stamp. Revision **clouds** ship in v1 (DR-005): an arc-scalloped closed path around the changed region, driven from `RevisionEntry`, with a revision triangle carrying the revision letter. |

Touching any individual switch moves the radio to `Custom…`. `ExportSpec` is `{preset, palette: colour \| greyscale \| cmyk, wireRender: auto \| netLabels \| drawn, issuedForConstruction, paper, maxPages}`, and the screen theme **never** affects the export (CR-077, PAL-3). `ProjectSettings.greyscaleSafeExport` is deleted: it is an export option, not a property of the design.

---

## 3. The wiring schedule

The schedule is the deliverable; the drawing is the receipt (G1). Effort and risk budget follow the schedule, and anything that degrades it loses.

### 3.1 Two presets, one derivation

`design-pdf-export.md §2` designed a single schedule organised for the person drawing it. AC-025 rules that wrong: a row reading `W044: MTX-1:J09 → HBT-GRT:J01` with a zone reference requires two sheet flips to become actionable at 7 pm behind a rack, and carries no room, no rack, no RU, no conductor colours, and nothing to initial. The single schedule splits into **two presets of one derivation**: same query, same row model, different projection.

| | **Pull Sheet** (`T6.10`) | **Termination Schedule** (`T6.11`) |
|---|---|---|
| Page | ANSI A **portrait**, usable 510 pt | ANSI A **landscape**, usable 690 pt |
| Default sort | **room, then pathway**: the order the tech walks the house | **rack, then panel, then port** |
| Rows | `Link.linkClass == fieldCable` only | every `Link` landing in a `Rack` |
| Adds | per-room footage subtotals, jacket colour (two tokens, see below), `Pulled ☐ Terminated ☐ Tested ☐ Init ___` | T568A/B, punch position, polarity, `Conductor.colorCode` per role, pinout notes |

**The jacket-colour cell.** It reads two fields, not one: `Link.jacketColorId`
(what the run IS, the convention entry, which the keystone follows) and
`Link.jacketColorPulledId` (what was actually pulled, set only when it differs).
A run pulled in the wrong colour prints **both tokens**, `BLU→YEL` at this
column's width, never one. Resolution comes from
`derived/jacket_color_resolution.dart`; the exporter formats, it does not decide.

Two constraints this cell must respect. First, the abbreviation is load-bearing
and the swatch is not: `ExportSpec.palette` ships `colour | greyscale | cmyk` and
the Installer preset defaults to **greyscale**, so a swatch alone degrades to an
indistinguishable grey, and was already indistinguishable for the ~8 % of
installers with a colour-vision deficiency (§ docs/05 §6.1). `JacketColorDef.abbr`
survives greyscale, a photocopy and a CVD. Second, a near-white or near-black
swatch needs an outline to be visible on white paper; that rendering rule is
recorded as debt in `catalog/jacket_color_convention.dart` and is still unowned.

**This colour never reaches a drawn wire's hue**: see docs/05 §6.1 and
`jacket_colour_is_not_hue_test.dart`, which gates the drawing layer by source
scan.

Both carry, **on both ends**, the location (`RK-1 / U14 / rear`, `Great Room / TV wall / WP-1`) and **both labels**: `StructureOrigin.fieldLabel` and `StructureOrigin.rackLabel` (CR-044, AC-047). The dual-label insight was correctly identified for structured wiring and then not applied to every cable; it now applies to every cable.

`jumper` and `powerCord` links are **excluded by default** from both, with a toggle (AC-026). 110 rows of factory patch cords in a 180-row schedule make the 70 rows describing real pulls indistinguishable from noise, and nobody labels a patch cord with a `W` number. They are not lost: they roll up on `T6.30` by media + length + colour, and `Trace` and the netlist still include them.

### 3.2 Pull Sheet: exact columns

ANSI A portrait, 612 × 792 pt. Widths sum to exactly 510.

```
Page             612 × 792 pt
Margins          L 54 (binding)  R 36  T 36  B 36
Border inset     6 pt inside margin
Usable width     612 − 54 − 36 − 12 = 510 pt
Title strip      full-width compact variant, 43 pt, bottom
Sheet header     18 pt
Body height      792 − 36 − 43 − 36 − 18 = 659 pt
Header row       18 pt · body row 15 pt · 2-line row 24 pt
Rows per page    ⌊(659 − 18) / 15⌋ = 42   (≈28 with heavy notes)
```

| # | Header | Width | Just. | Font | Content |
|---|---|---|---|---|---|
| 1 | `CABLE ID` | 52 | left | `RackMono` 8 Bold | `Link.designator`: `W042` |
| 2 | `TYPE` | 44 | left | `RackBody` 7 | Chip (§3.5) + domain tag + family `shortTag` |
| 3 | `FIELD LABEL` | 54 | left | `RackMono` 7.5 | `StructureOrigin.fieldLabel`: `LR-TV-1` |
| 4 | `RACK LABEL` | 50 | left | `RackMono` 7.5 | `StructureOrigin.rackLabel`: `1A-A12` |
| 5 | `FROM — ROOM / OUTLET` | 68 | left | `RackCond` 7 | `Location.name` / `Outlet` designator |
| 6 | `TO — RACK / RU / FACE` | 64 | left | `RackCond` 7 | `RK-1 / U14 / rear` |
| 7 | `MEDIA` | 58 | left | `RackCond` 7 | `MediaTypeDef.displayName` + jacket |
| 8 | `LEN` | 28 | **right** | `RackMono` 7.5 | `cutLength`; **italic** when derived from either estimate, `Outlet.nominalRunLength` first and then `Location.estimatedRunLengthFromRack` (DR-026 §11.25.2); `—` when null |
| 9 | `PATHWAY` | 36 | left | `RackMono` 7 / `RackBody` 7 | `Pathway.designator`; **falls back to `Pathway.name`** when the trunk carries none, and the FONT says which (M3-E/2, DR-026 §11.25.1). Mono for a designator, because it is an identifier somebody wrote on a trunk; body for a name, because it is prose. `ScheduleEntry.pathwayLabelIsDesignator` is the flag. `—` when the run is in no pathway at all |
| 10 | `SIGN-OFF` | 56 | centre | — | `☐ P` 12 · `☐ T` 12 · `☐ T` 12 · `INIT` 20 |

**Grouped by lifecycle (DR-206 §11.205.2).** Rows fall into sections, each with its own header and
count, in this order: **TO PULL** (`new`, `designIntent`), **EXISTING**, **TO REMOVE**, **FUTURE**.
An empty section is not drawn.

### 3.3 Termination Schedule: exact columns

ANSI A landscape, 792 × 612 pt, usable 690 pt, body 479 pt, **30 rows per page** (≈24 with heavy notes).

| # | Header | Width | Just. | Font | Content |
|---|---|---|---|---|---|
| 1 | `CABLE ID` | 56 | left | `RackMono` 8 Bold | `W042` |
| 2 | `TYPE` | 44 | left | `RackBody` 7 | chip + tag |
| 3 | `RACK LABEL` | 52 | left | `RackMono` 7.5 | |
| 4 | `FIELD LABEL` | 52 | left | `RackMono` 7.5 | |
| 5 | `RACK / RU / FACE` | 62 | left | `RackCond` 7 | |
| 6 | `DEVICE` | 74 | left | `RackBody` 7.5 | `designator` over model, 2-line only when the row is already 2-line |
| 7 | `PORT` | 46 | left | `RackMono` 7.5 | `Port.designator` + label |
| 8 | `FAR END` | 84 | left | `RackBody` 7.5 | device, `Outlet`, or `— OPEN —` for an `OpenEndpoint` |
| 9 | `FAR PORT` | 46 | left | `RackMono` 7.5 | |
| 10 | `MEDIA` | 42 | left | `RackCond` 7 | |
| 11 | `FIELD TERM` | 44 | left | `RackMono` 7 | `KEYSTONE T568B` · `F BARREL` · `LC-A` · `EURO 3` |
| 12 | `RACK TERM` | 44 | left | `RackMono` 7 | `PUNCHDOWN A03 T568B` · `LC-A`; `—` when undecided |
| 13 | `CONDUCTOR / NOTES` | 44 | left | `RackBody` 6.5 | `Conductor.colorCode` per role; wraps to 2 lines then ellipsis |

**Thirteen columns since DR-055 (§11.54), and the widths above are that ruling's.** `TERM` was one
column resolving to the **field** end while the sheet is filtered, sorted and grouped by rack, so the
one sheet built around the rack could not state the rack-side termination. The argument that settled
it was already on this table: every other fact prints **both** ends (`RACK LABEL` / `FIELD LABEL`,
`RACK / RU / FACE` / `FAR END`, `PORT` / `FAR PORT`), and termination was the only per-end fact
collapsed into one column. Width came from §3.4's own donor order, `CONDUCTOR / NOTES` first and then
`MEDIA`; Σ is still exactly 690.

**Lifecycle rides on `CABLE ID` (DR-206 §11.205.3).** `W042 EX` · `W043 RM` · `W044 FUT` · `W045 DI`,
and **no suffix for `new`**. A one-line key prints in the sheet header whenever a suffix appears on
the sheet. It costs no width, which is why it is not §3.4's `LIFECYCLE` column: these thirteen already
fill the 690 pt, and that column would promote every retrofit job's schedule to ANSI B.

**Neither column ever falls back to the other.** An end nobody has decided prints `—` (G4, CR-114).
Copying the field value across would reproduce on paper the defect DR-046 removed from the model.

**The wiring standard is IN these cells and not in a column of its own (DR-180 §11.179.4).** The cell
is the termination type, then the punch position where there is one, then the standard: `PUNCHDOWN
A03 T568B`. The standard goes last so the type and the hole stay the one thing an installer reads at
the panel. It prints only beside a termination that lands pairs on pins, which is a keystone, a
punchdown or a crimped RJ45 plug, so a genuinely four-pair run with a euroblock recorded at one end
prints `EUROBLOCK` and no standard rather than a sentence about hardware with no pins. A cable that
is not four-pair at all never reaches this question: §11.179.3 answers it one level up. A job nobody
has told prints the termination alone, never an assumed `T568B`.

**WHAT IS BUILT TODAY IS STILL ONE `TERM` COLUMN**, 52 pt, carrying the field end. DR-055's split
above is ruled and unbuilt, and that was already true before DR-180; the wiring standard prints in
the column that exists. Nothing here is waiting on the standard, and the split is not waiting on
anything but the work.

**Rule weights**: grouping without colspan, which `pw.Table` cannot do. 0.8 pt vertical rules at the block boundaries (identity ┃ ends ┃ spec ┃ notes); 0.35 pt between all other columns and between rows; 0.8 pt above and below the header; **no outer border**: the drawing border supplies it.

An `OpenEndpoint` schedules, prints, and carries a `W` number like any other end (AC-018). A home run whose far end is not yet bound is the normal state of a rough-in, not an error.

### 3.4 Optional columns

Toggled per export. Width is taken from `CONDUCTOR / NOTES` first, then `MEDIA`.

| Header | W | Just. | Enabled by |
|---|---|---|---|
| `#` | 22 | right | "Number rows" |
| `ROOM / ZONE` | 56 | left | any endpoint carries a `Location` |
| `PATHWAY` | 40 | left | any `Pathway` assigned |
| `ROUGH-IN` | 48 | centre | Installer / As-built preset |
| `LIFECYCLE` | 44 | centre | any `lifecycleStatus != new`, on a sheet with the room; **not T6.11**, which carries a `CABLE ID` suffix instead (DR-206 §11.205.3), and **not the Pull Sheet**, which groups by lifecycle (§11.205.2) |
| `ISSUES` | 40 | centre | any open `Finding` on a row |
| `ROUTED` / `TERMINATED` | 28 ea | right | the other two of the three length fields (AC-024) |
| `REF` | 40 | centre | zone grid enabled: `6.01/B3` |
| `SERVICE` | 52 | left | any `Link` carries more than one `Service` |

**`Status` is never a bare column header** (CR-065). Three vocabularies were being flown under it: `LifecycleStatus`, `RoughInStatus`, and DRC state. The headers are `LIFECYCLE`, `ROUGH-IN`, and `ISSUES`, and they mean different things.

**Overflow rule.** If `Σ widths > usable − 60`, promote the sheet to ANSI B landscape (usable 1128 pt) and emit a non-blocking notice: *"Termination schedule promoted to ANSI B (11×17), 15 columns selected."* Never shrink text below 6 pt.

### 3.5 The TYPE chip, and how the colour survives a photocopy

The chip is **not** a solid swatch. It is a 16 × 9 pt box containing a 1.5 pt horizontal line drawn with **the exact colour, dash and weight that domain uses on the diagram sheets**, over a pre-composited 18% tint (§7.6 divergence 9, no alpha in the document).

```
 ┌──────────────┐
 │ ━━━━━━━━━━━━ │  VID   solid,     1.00×, #0072B2   ▲
 │ ── ── ── ─── │  RF    12,4       1.00×, #56B4E9   ▼
 │ ─ ─ ─ ─ ─ ─  │  AUD   6,3        1.00×, #E69F00   ●
 │ ─ · ─ · ─ ·  │  DIG   6,3,1,3    1.00×, #D55E00   ◆
 │ ━━━━━━━━━━━━ │  NET   solid,     1.50×, #009E73   ■
 │ ·  ·  ·  ·   │  CTL   1.5,3      0.75×, #CC79A7   ✚
 │ ━ ·· ━ ·· ━  │  PWR   8,3,1.5,3,1.5,3  2.00×, #000000  ⬢
 │ ── ─ ── ─ ── │  STR   6,3,3,3   0.75×, #999999   ★
 └──────────────┘
```

Three consequences. **(1)** The schedule and the drawing cross-reference visually with no legend lookup, you find `━━━` in the chip, you look for `━━━` on the sheet. **(2)** Greyscale works by construction: drop the hue and the tint, and dash class **or** weight multiplier still separates every pair of families that greyscale brings together, per **PAL-1**, stated below in the rendered-value form that governs. **(3)** The tag text is the third layer and never fails: `VID·HDMI`, `CTL·232`, `AUD·SPK`.

> **PAL-1 (rendered-value form).** Every shipped `SignalFamilyDef` renders as the triple
> *(L, dashClass, weight)*, where **L** is the WCAG relative luminance of its **effective** hue,
> **dashClass** is the class of its effective dash pattern, and **weight** is its effective
> line-weight multiplier — *effective* meaning **after** any per-family override, not the domain
> base value.
>
> For **every pair of families belonging to different `SignalDomainDef`s** whose luminances satisfy
> **|L₁ − L₂| < 0.10**, at least one of the following must hold: **(a)** their dash classes differ,
> **or** **(b)** their weight multipliers differ by a factor **≥ 1.4**.
>
> Families **within one domain** are exempt from (a)/(b) — they share a hue by construction and the
> legend prints them adjacently — but any two families in one domain must still differ in **dash
> pattern, weight, or glyph**.

The rule is pairwise over **rendered family values**, not over the eight domain rows of the chip above. The chip prints each domain's *base* rendering; a family carrying a dash or weight override renders differently from its base, and it is the rendered value that reaches the paper. Reading the eight rows is not a check, the authority is `tools/pal1_check.py`, which enumerates every in-band cross-domain pair and exits non-zero on any violation. It is ported to `pal1_conformance_test.dart` in `rackpal_core` at M0 and remains the authority thereafter; where this document and that file disagree, the file wins. The dash-class definition, the collisions the check found and the palette corrections it forced are in [Schematic editor §6.3](05-schematic-editor.md) and are deliberately not restated here.

This matters because the common claim that Okabe-Ito is greyscale-safe **is false** and this project does not repeat it: Sky Blue `#56B4E9` (relative luminance 0.4050) and Orange `#E69F00` (0.4162) are ΔL 0.0112 apart, and Vermillion `#D55E00` (0.2215) / Green `#009E73` (0.2569) / Purple `#CC79A7` (0.2930) sit inside a 0.072 band. The dash-and-weight layer is load-bearing, not decoration (AC-054).

Greyscale export drops hue entirely and renders every domain black at its own dash and weight; CMYK export uses `PdfColorCmyk` with pure black as `0,0,0,1`, never rich black. The `str` base dash is `6,3,3,3`, class `(short,short)`, period 15 pt, **not** the retracted `4,4`, whose "an even dash is unambiguous against a 2:1 dash" justification does not survive the mechanical dash-class definition (canon §14.3, [Schematic editor §6.3](05-schematic-editor.md)). The chip above prints the shipped value.

### 3.6 Sort and group

Sort is single-select with a stable secondary sort on `Link.designator`. Grouping is orthogonal.

| Sort key | Use |
|---|---|
| `designator` | Reference lookup; someone reads a label in a rack and wants the row |
| **room, then pathway** | Pull Sheet default (AC-025): the order the tech walks the house |
| **rack, panel, port** | Termination Schedule default: terminate one panel at a time |
| domain, then family, then `designator` | Pull by trade: all the Cat6, then all the speaker wire |
| from device, then from port | Terminate one device at a time |
| `cutLength` descending | Reel planning and cut lists |
| `roughInStatus`, then `designator` | Punch list |

A group inserts a full-width band row, 14 pt, 12% grey fill, 2 pt leading rule in the domain colour, `RackBody` 8 Bold, count and footage subtotal right-aligned:

```
▌ NETWORK — 24 runs ──────────────────────────────────────────  1,860 ft total
```

At a page break the band repeats with ` (cont.)` appended. Group bands are precisely why pagination is hand-rolled.

### 3.7 Pagination

Do **not** hand `MultiPage` one giant `pw.Table`. Row heights here are deterministic (fixed column widths, notes capped at two lines) so paginate explicitly and make each page its own table.

```dart
List<pw.Widget> buildSchedulePages(ScheduleModel m, ScheduleLayout l) {
  final pages = <pw.Widget>[];
  var page = <ScheduleItem>[];
  var y = 0.0;
  GroupBand? openBand;

  void flush() {
    if (page.isEmpty) return;
    pages.add(_pageTable(page, l));
    page = <ScheduleItem>[];
    y = 0;
  }

  for (final item in m.flattened) {          // bands interleaved with rows
    final h = item.height(l);                // 14 | 15 | 24
    if (y + h > l.bodyHeight) {
      flush();
      if (openBand != null) {                // re-emit the band, marked (cont.)
        page.add(openBand.continuation());
        y += openBand.height(l);
      }
    }
    if (item is GroupBand) openBand = item;
    page.add(item);
    y += h;
  }
  flush();
  return pages;
}
```

Four things this buys:

1. **Header repetition is explicit**: each page's table carries its own header row, sidestepping the question of whether `Table.headerCount` repeats per page fragment. VERIFY: `pw.TableHelper` / `pw.Table` header-repeat behaviour on the pinned `pdf` version.
2. Group continuation bands work at all.
3. `Widget won't fit into the page` overflow becomes structurally impossible.
4. Deterministic row counts, so the progress reporter quotes an exact page count before it starts.

**`maxPages` is set explicitly to 2000**: the default is 20 and throws beyond it. The dry run warns above 40 sheets and hard-caps at 2000 (AC-050/A7.4).

**Long-token protection.** Model strings and labels like `RK1-HDMI-OUT-07-TO-DISPLAY-MSTR-BR` are exactly the shape that overflows or silently disappears in `pw.Text`. Sanitise on the way in, then hard-truncate with a measured ellipsis using the shared `TextMeasurer` (§7.5) rather than trusting the widget:

```dart
/// Insert zero-width spaces after separators so long identifiers can wrap.
String breakable(String s) =>
    s.replaceAllMapped(RegExp(r'[-_/.:]'), (m) => '${m[0]}​');
```

### 3.8 Rendered example: Pull Sheet, eleven rows

Residential rack: streaming box, 8×8 HDMI matrix, HDBaseT TX, AVR, 16-channel amp, 24-port PoE switch, control processor, sequenced PDU, patch panel, and one `StructureBody`. Sorted room then pathway; grouped by room.

```
┌──────────┬────────┬──────────┬──────────┬──────────────┬──────────────┬─────────────┬─────┬──────┬──────────────┐
│ CABLE ID │ TYPE   ┃ FIELD LBL│ RACK LBL │ FROM — ROOM  │ TO — RACK/RU ┃ MEDIA       │ LEN │ PATH ┃ SIGN-OFF     │
├──────────┼────────╀──────────┼──────────┼──────────────┼──────────────╀─────────────┼─────┼──────╀──────────────┤
│▌ GREAT ROOM — 4 runs ──────────────────────────────────────────────────────────────────────────  212 ft ───────│
│ W015     │▨ STR   ┃ GR-TV-1  │ 1A-A03   │ Great Room / │ RK-1 / U14 / ┃ Cat6A F/UTP │ 78  │ CD-1 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ TV wall WP-1 │ rear         ┃ CMR         │     │      ┃              │
│ W016     │▨ STR   ┃ GR-TV-2  │ 1A-A04   │ Great Room / │ RK-1 / U14 / ┃ Cat6A F/UTP │ 78  │ CD-1 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ TV wall WP-1 │ rear         ┃ CMR         │     │      ┃              │
│ W041     │▥ AUD·SPK┃ GR-SPK-1│ —        │ Great Room / │ RK-1 / U08 / ┃ 16/2 CL3    │ 62i │ JH-2 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ ceiling L/R  │ rear AMP-1   ┃             │     │      ┃              │
│ W070     │▧ RF    ┃ ANT-ROOF │ 1A-F01   │ Attic / mast │ RK-1 / U02 / ┃ RG6 quad    │ 44  │ CD-3 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │              │ rear SPL-1   ┃ swept 3 GHz │     │      ┃              │
│▌ KITCHEN — 3 runs ─────────────────────────────────────────────────────────────────────────────  141 ft ───────│
│ W042     │▥ AUD·SPK┃ KIT-SPK-1│ —       │ Kitchen /    │ RK-1 / U08 / ┃ 16/2 CL3    │ 51i │ JH-2 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ ceiling pair │ rear AMP-1   ┃             │     │      ┃ VERIFY POL.  │
│ W043     │▬ NET   ┃ KIT-AP-1 │ 1A-A11   │ Kitchen /    │ RK-1 / U20 / ┃ Cat6A F/UTP │ 47  │ CD-1 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ ceiling AP   │ rear SW-1    ┃ CMR         │     │      ┃ PoE Class 4  │
│ W044     │▨ STR   ┃ KIT-KEY-1│ 1A-A12   │ Kitchen /    │ RK-1 / U14 / ┃ Cat6A F/UTP │ 43  │ CD-1 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ keypad wall  │ rear         ┃ CMR         │     │      ┃              │
│▌ MEDIA ROOM — 4 runs ──────────────────────────────────────────────────────────────────────────  198 ft ───────│
│ W014     │▤ VID·HBT┃ MR-PROJ-1│ 1A-A07  │ Media Rm /   │ RK-1 / U16 / ┃ Cat6A F/UTP │ 66  │ CD-2 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ ceiling proj │ rear TX-1    ┃ solid CMR   │     │      ┃ NOT ETHERNET │
│ W055     │▪ CTL·232┃ MR-PROJ-C│ 1A-A08  │ Media Rm /   │ RK-1 / U22 / ┃ Cat6 + DE-9 │ 41  │ CD-2 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ ceiling proj │ rear CTL-1   ┃ adapters    │     │      ┃ NULL-MODEM   │
│ W061     │▪ CTL·IR┃ MR-EMIT-1 │ —        │ Media Rm /  │ RK-1 / U22 / ┃ 3.5 mm MONO │ 38  │ CD-2 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ rack shelf   │ rear CTL-1   ┃ emitter     │     │      ┃ NOT RCVR JACK│
│ W072     │▧ RF    ┃ MR-CATV-1│ 1A-F04   │ Media Rm /   │ RK-1 / U02 / ┃ RG6 quad    │ 53  │ CD-3 ┃ ☐  ☐  ☐  ___ │
│          │        ┃          │          │ AV wall      │ rear SPL-1   ┃             │     │      ┃              │
└──────────┴────────┸──────────┴──────────┴──────────────┴──────────────┸─────────────┴─────┴──────┸──────────────┘
▌ Σ 11 runs · 601 ft · 3 estimated (italic) ──────────────────────  SHEET 7 OF 14 · PULL SHEET · 1 OF 2
```

The same rows as a table, with the two length variants distinguished:

| CABLE ID | TYPE | FIELD LABEL | RACK LABEL | FROM, ROOM / OUTLET | TO, RACK / RU / FACE | MEDIA | LEN | PATH | NOTES (auto) |
|---|---|---|---|---|---|---|---|---|---|
| W015 | ▨ STR | GR-TV-1 | 1A-A03 | Great Room / TV wall WP-1 | RK-1 / U14 / rear PP-1 A03 | Cat6A F/UTP CMR | 78 | CD-1 | Grade 2 outlet |
| W016 | ▨ STR | GR-TV-2 | 1A-A04 | Great Room / TV wall WP-1 | RK-1 / U14 / rear PP-1 A04 | Cat6A F/UTP CMR | 78 | CD-1 | |
| W041 | ▥ AUD·SPK | GR-SPK-1 | — | Great Room / ceiling L/R | RK-1 / U08 / rear AMP-1 CH 5 ± | 16/2 CL3 | *62* | JH-2 | 1 `Link`, 2 `Conductor`s (`atomicConnect`) |
| W070 | ▧ RF | ANT-ROOF | 1A-F01 | Attic / mast | RK-1 / U02 / rear SPL-1 IN | RG6 quad, swept 3 GHz | 44 | CD-3 | OTA; preamp power injected at SPL-1 |
| W042 | ▥ AUD·SPK | KIT-SPK-1 | — | Kitchen / ceiling pair | RK-1 / U08 / rear AMP-1 CH 7 ± | 16/2 CL3 | *51* | JH-2 | **VERIFY POLARITY** |
| W043 | ▬ NET | KIT-AP-1 | 1A-A11 | Kitchen / ceiling AP | RK-1 / U20 / rear SW-1 P11 | Cat6A F/UTP CMR | 47 | CD-1 | PoE Class 4 |
| W044 | ▨ STR | KIT-KEY-1 | 1A-A12 | Kitchen / keypad wall | RK-1 / U14 / rear PP-1 A12 | Cat6A F/UTP CMR | 43 | CD-1 | far end `OpenEndpoint` |
| W014 | ▤ VID·HBT | MR-PROJ-1 | 1A-A07 | Media Rm / ceiling projector | RK-1 / U16 / rear TX-1 LINK OUT | Cat6A F/UTP solid CMR | 66 | CD-2 | **NOT ETHERNET**: do not patch to SW-1. PoH 100 W |
| W055 | ▪ CTL·232 | MR-PROJ-C | 1A-A08 | Media Rm / ceiling projector | RK-1 / U22 / rear CTL-1 COM 2 | Cat6 + DE-9 adapters | 41 | CD-2 | **NULL-MODEM** 2↔3 4↔6 7↔8 5→5 |
| W061 | ▪ CTL·IR | MR-EMIT-1 | — | Media Rm / rack shelf | RK-1 / U22 / rear CTL-1 IR 3 | 3.5 mm **mono** emitter | *38* | CD-2 | Xantech pinout; **not** the receiver jack |
| W072 | ▧ RF | MR-CATV-1 | 1A-F04 | Media Rm / AV wall | RK-1 / U02 / rear SPL-1 OUT 2 | RG6 quad | 53 | CD-3 | |

> **Three field labels in this example were corrected when M3-C/4 seeded
> the outlet templates.** Under DR-022 the `{SERVICE}` segment is the
> `OutletTemplate.tag` the drop was created from, so the words in that
> position are now shipped data rather than prose. `KIT-KP-1` became
> `KIT-KEY-1`, because canon §11.21's worked example is `MBR-KEY-2` and
> canon is normative over a derived sheet. `GR-CLG-1` and `KIT-CLG-1`
> became `GR-SPK-1` and `KIT-SPK-1`, because `CLG` is an OUTLET
> designation: docs/07 §4's table prints it in that column, beside a
> field label of `LR-SPK-1`, and it had wandered one column left. The
> seeded tags and the reasoning are in
> `packages/rackmate_core/lib/src/catalog/seed_outlet_templates.dart`.

Note what the notes are doing. `NOT ETHERNET`, `NULL-MODEM 2↔3 4↔6 7↔8 5→5`, `VERIFY POLARITY`, `not the receiver jack` are **generated from the port and connector model**, not typed by a user. That is the single highest-value thing this schedule does that a spreadsheet cannot. Italic lengths are estimates derived from `Outlet.nominalRunLength` where the drop carries one and from `Location.estimatedRunLengthFromRack` otherwise, and are tagged as such so nobody bills off them (AC-024, DR-026 §11.25.2); a null length prints `—` and the `LEN-*` rules emit *"length unknown, cannot verify"* rather than silently passing (G4).

---

## 4. Cable identifiers

### 4.1 One format engine, five call sites

TIA-606-C is explicit that the format is not mandated but must be consistent and unique, so RackPal ships a **token template engine**, not a hardcoded scheme. It lives once, in `rackpal_core/idformat/`, and five call sites share it: device `designator`, port `designator`, `Link.designator`, `StructureOrigin.fieldLabel`, and `StructureOrigin.rackLabel` (CR-045). Rejected: five bespoke generators, which is what the design corpus had.

Grammar: `{TOKEN}`, `{TOKEN:n}` zero-pad, `[...]` optional segment that collapses entirely if any token inside is empty, `|upper` `|first n` `|nz` filters, `{{`/`}}` literal braces. Tokens are **`UPPER_SNAKE`** (N3) drawn from one canonical vocabulary:

```
SITE · BUILDING · FLOOR · SPACE · TR · ROOM · ROOM_ABBR · AREA · ZONE ·
RACK · PANEL · PORT · OUTLET · PATHWAY · SERVICE · MEDIA · DOMAIN ·
TYPE_PREFIX · SEQ · DEV_SEQ · PORT_SEQ · DEV_BLOCK · SRC_REFDES · SRC_PORT ·
DST_REFDES · DST_PORT · DEVICE · DIR · RUN · N
```

### 4.2 Presets

| Preset | Template | Output | Rationale |
|---|---|---|---|
| **Sequential** *(default)* | `W{SEQ:3}` | `W001` `W042` | ASME Y14.44 / IEEE 315: `W` = cable, `J` = jack, `P` = plug. Short, never collides, matches the designator on the drawing. |
| Domain sequential | `{DOMAIN}-{SEQ:3}` | `VID-001` `NET-014` | Installers pull by trade; sorting by ID gives the pull order free. |
| Rack-scoped | `{RACK}-{DOMAIN}{SEQ:3}` | `RK1-VID001` | Multi-rack jobs stay independently renumberable. |
| Endpoint descriptive | `{SRC_REFDES} {SRC_PORT} > {DST_REFDES} {DST_PORT}` | `MTX-1 OUT 3 > DISP-LR IN 1` | AVIXA F501.01's own worked example. Too long for a schedule column, correct for the label file (§9.2). |
| AV block | `{DEV_BLOCK:2}{PORT_SEQ:2}` | `2301`…`2316` | The widespread matrix convention; **reserves IDs for unpopulated ports**, so next year's source addition renumbers nothing. |
| TIA-606-C horizontal | `{FLOOR}{SPACE}-{PANEL}{PORT:2}` | `2A-A12` | The standard's `fs-an` form verbatim. Default for `rackLabel` (CR-044). |
| Residential prewire | `{MEDIA}-{ROOM_ABBR}[-{DIR}][-{SEQ}]` | `ET-FAM-W-11` `SP-FAM-SL` | The dominant residential scheme; code tables user-editable. |
| Room-service (default `fieldLabel`) | `{ROOM_ABBR}-{SERVICE}-{SEQ}` | `LR-TV-1` | CR-044's shipped residential preset. |

Both labels are generated, both are editable, both are project-unique, and **both print on every cable, on both ends** (CR-044, AC-047). The single most common on-site failure is a mismatch between what is written on the plate in the bedroom and what is written on the patch panel port in the rack; printing one of the two is how that failure is manufactured.

### 4.3 Allocation, locking, and collisions

**Every designator is evaluated once at creation and stored** (CR-048, P5). Nothing is recomputed at render time. Two exports of an unmodified project produce the same identifiers, by construction rather than by luck.

Collisions resolve at allocation via `CollisionPolicy{suffixLetter | suffixNumber | error}`, project-wide. `design-pdf-export.md §3.4`'s claim that a duplicate is "a hard error that blocks export" **does not survive**: it contradicts CR-022 and G3. If a hand-edited or merged file arrives carrying a duplicate, it is a `SEQ-*` `Finding` that prints on `T0.02` and appears in the export dialog's notices; it never withholds bytes.

Changing a scheme offers a **renumber with a before/after diff**, never a silent rewrite, and never touches a locked identifier. `DeviceInstance.designatorLocked` and `Link.designatorLocked` are auto-set once `roughInStatus >= pulled` (CR-034, AC-034/m22), because at that point the identifier exists on a label inside a wall.

---

## 5. Sheet furniture

**Sheet furniture is a v1 deliverable (DR-005), not a polish item to be traded away under schedule pressure.** The PDF is a client deliverable: border, zone grid, title block, revision block, revision clouds, the `ISSUED FOR CONSTRUCTION` stamp and sheet numbering all ship. Note that this is orthogonal to wire idiom, sheet furniture is drafting polish, and polishing the sheet does not reopen DR-001. The schematic's reader is technical (GC, electrician, low-voltage sub, technically-literate homeowner); the sheet is polished fully and net labels stay the default.

All furniture (border, zone band, title block, revision block, revision clouds, legend swatches) is drawn through `DiagramCanvas` (P1), attached via `pw.PageTheme(buildBackground:)` wrapping `pw.FullPage(ignoreMargins: true, child: pw.CustomPaint(painter: ...))`. It therefore draws on every page including ones `MultiPage` creates by overflow, and it renders identically in the on-screen preview. VERIFY: `PageTheme.buildBackground` / `buildForeground` parameter names on the pinned `pdf` version.

### 5.1 Border and zone grid

```
Sheet edge
  ├── 0.50 in margin (0.75 in on the binding edge)
  ├── outer rule      0.7 pt   hairlineFloor
  ├── 0.22 in zone band — letters left+right, numbers top+bottom, RackMono 7
  ├── inner rule      1.0 pt   hairlineFloor
  └── drawing area
```

Zone module 4.25 in, minimum 2 × 2, ANSI B landscape gives 4 × 2, ANSI D gives 8 × 5. Origin, numbering direction and letter direction are a project setting; default origin lower-right, numbers increasing right-to-left, letters bottom-to-top. VERIFY: which origin convention ASME Y14.1 Table 1 actually mandates, both lower-right and upper-right are in live use, and this is a two-line config constant.

Zone references are computed from the **final placed geometry**, after layout, and are what the schedule's optional `REF` column points at. The zone grid survives CR-073's cuts specifically because that column is useful; off-sheet connectors and cross-reference resolution do not.

### 5.2 Title block

Bottom-right, 396 × 115 pt on ANSI B and larger; on ANSI A a full-width 690 × 43 pt (or 510 × 43 pt portrait) strip along the bottom, so the schedule table is not notched.

```
┌────────────────────────────────────────────────────────────────────────────┐
│  SMITH RESIDENCE — MASTER EQUIPMENT RACK                                   │
│  1428 Alder Ct, Portland OR 97214                                          │
│  CLIENT  J. & M. Smith                                                     │
├──────────────────────────────────────────────────────────────────────────  ┤
│  INTERCONNECT — VIDEO                                                      │
│  RK-1  MASTER RACK  ·  42U                                                 │
├──────────────┬──────────────┬──────────────┬───────────────┬───────────────┤
│ DRAWN   J.S. │ SCALE  1:8   │ SIZE   B     │ DATE 2026-07-18│ REV       C  │
│ CHK'D    —   │ PROJ 25-1183 │ DISC   T     │ FILE smith.rppj│SHEET 5/14│
├──────────────┴──────────────┴──────────────┴───────────────┴───────────────┤
│  NBS INTEGRATION LLC  ·  (503) 555-0142  ·  OR CCB #219884                 │
│  SYMBOL LEGEND: SEE SHEET T0.01          SHEET NO.  T6.01                  │
└────────────────────────────────────────────────────────────────────────────┘
```

**The logo ships in v1 as of DR-030**, in M6 beside the title block it sits in, and this line used to read *"There is no logo"*. It rides the zip container DR-019 settled and the raster path DR-029 builds for the plan sheet, so it is a fourth consumer of things already paid for rather than a new subsystem. The integrator's **text** block (firm, contact, licence number) is unchanged and still ships: the logo is added beside it, never instead of it, because the text is what a photocopy at third generation still carries.

Every field resolves from `ProjectInfo`, `Rack`, the sheet definition, or app preferences. Nothing is typed at export time. Empty optional lines collapse rather than printing a blank. Two fields are computed rather than stored:

- **Scale.** Once §6.2 picks `k`, the block reports the nearest standard ratio if `|k − 1/n| < 2%` for `n ∈ {1,2,4,8,10,16,20,24,32,48,64,96}`, otherwise `NTS`. Never print `1:8` on a sheet drawn at 1:8.34; someone will scale off it.
- **Legend reference.** Auto-filled by the exporter, per CR-023. Deleted: invariant I-41, which made a missing drafting footnote block the export.

### 5.3 Revision block

Directly above the title block, same 396 pt width, rows 13 pt, entries stacking **upward**, maximum 8 visible before `SEE SHEET T0.00 FOR FULL REVISION HISTORY`.

| REV | DATE | DESCRIPTION | BY |
|---|---|---|---|
| 30 pt, centre | 62 pt, centre | 268 pt, left | 36 pt, centre |

Rows come from `RevisionEntry`, which is a document entity and a conflict unit, **generated from project history, not hand-entered**. Re-issuing a rack drawing after a change order yields `C · 2026-07-18 · Added AMP-2, 4 speaker runs to Zone 3 · JS` automatically. `RevisionEntry` is never conflated with `RackDocument.sequence`, the strictly-monotonic sync cursor (CR-094); `issued` was deleted from `RoughInStatus` because it is a revision-block concept, not a cable state (CR-065). Revision **clouds** (a scalloped arc-chain around each element changed since the last issued revision) **ship in v1** (DR-005). A cloud is an arc-scalloped closed path around the changed region, driven from `RevisionEntry`, accompanied by a revision triangle carrying the revision letter. It is drawn with `drawPath`, so **no new `DiagramCanvas` method is required**, which is why it costs what it costs.

### 5.4 Legend sheet `T0.01`

Six blocks on one ANSI B landscape sheet:

1. **Cable-type key**: requirement 4's ten named types **always**, then one row per other family the set uses (DR-207 §11.206.2); one row per **named cable type** (not per domain), each showing its exact drawn rendering in colour and in greyscale side by side, with hue, dash, weight, glyph and tag. All ten types the brief names are individually identifiable here and on the drawing (AC-054). The hue-is-domain argument is printed on the sheet so the reader sees *why*.
2. **Connector symbol table**: every glyph used in the set, at drawing scale. Glyphs are the same `DiagramPath` constants the drawing uses, so the legend cannot drift from it.
3. **Device block anatomy**: one annotated example: designator position, name, model, port stub, port label, RU span, `lifecycleStatus` border.
4. **Convention key**: lifecycle borders; junction dot vs plain crossover (there are no hop arcs in v1, DR-001); the **net-label stub**: a labelled stub at a pin standing in for a drawn wire, which is the default rendering everywhere except a domain-filtered sheet, so the legend must explain it; home-run vs local tag-pill shape; `— OPEN —` end notation; the revision cloud and revision triangle.
5. **Identifier formats**: the active templates, expanded, with a worked decomposition field by field.
6. **Abbreviations and general notes**: editable, seeded (DR-208 §11.207.2). Edited in `File ▸ Sheet set…` as rows (DR-209 §11.208); an unedited project prints the seed, and the signal-domain tag prefixes follow the author's abbreviations, derived from the registries.

**Blocks 2 to 6 explain what the set prints (DR-208 §11.207.1).** A convention joins the key in the change that first prints it, so the key never explains a mark the reader cannot find in the set.

J-STD-710 symbol geometry becomes constants: distinctive shapes inside a 3/8 in circle, circles 0.35 in, squares 0.25 in, symbol line weight 0.014 in (1 pt), attribute text ≥ 3/32 in.

**Named acceptance criterion (AC-054, AC-058/D13):** before v1 ships, `T0.01` is rendered under protanopia and deuteranopia simulation with every domain pair still distinguishable, **and** printed on a real greyscale office laser at ANSI B and photocopied once, with all ten named cable types still identifiable. The entire dash-and-weight argument is predicated on that test, so it is run on hardware, not asserted.

### 5.5 Cover sheet `T0.00`

ANSI B landscape, first in every set (DR-210 §11.209.1). **Left**: the project block (project name,
client, site address, drawing number, current revision and issue date), the scope paragraph when
one is written, the integrator block, and the sign-off line `DRAWN · CHECKED · APPROVED`
(§11.209.3). **Right**: the drawing index, a full-height column, generated after the sheet list
resolves (§2.2): one row per sheet in set order, carrying the set position and the NCS id, a
multi-page schedule as one row with its page count, flowing into two then three sub-columns when it
outgrows one (DR-212). **Foot**: the rack summary strip (DR-211): per rack, designator, size,
active device count (passives excluded, §11.210.3), RU used per face (`F 31 · R 19`), weight, VA
and BTU/hr, each with its unknown count; racks past what fits are named in one closing row and a
notice. The title and revision blocks sit bottom-right as on every sheet. Every field is edited in
`File ▸ Sheet set…` (DR-209, DR-210 §11.209.2), and an empty optional line collapses (§5.2).

---

## 6. Page setup and fit

### 6.1 Sizes

`PdfPageFormat` ships only `a3, a4, a5, a6, letter, legal, roll57, roll80`. ANSI, ARCH and A2/A1/A0 are defined in `rackpal_export/sheets.dart`:

```dart
const _in = PdfPageFormat.inch;  // 72.0
const ansiA = PdfPageFormat( 8.5*_in, 11*_in, marginAll: 0.5*_in); //  612 ×  792
const ansiB = PdfPageFormat(  11*_in, 17*_in, marginAll: 0.5*_in); //  792 × 1224
const ansiC = PdfPageFormat(  17*_in, 22*_in, marginAll: 0.5*_in); // 1224 × 1584
const ansiD = PdfPageFormat(  22*_in, 34*_in, marginAll: 0.5*_in); // 1584 × 2448
```

Margins are overridden per sheet role to `EdgeInsets.fromLTRB(54, 36, 36, 36)`, the wider left edge is the binding margin.

| Sheet role | Size | Orientation | Why |
|---|---|---|---|
| Cover, legend, exceptions | ANSI B | landscape | matches the set |
| **Interconnect** | **ANSI B** | **landscape** | Largest size out of an ordinary office MFP, plots cheaply, **folds exactly to letter** for a job binder, and is the de facto residential-CI documentation size |
| **Rack elevations** | **ANSI B** | **portrait** | A 45 RU rack is 78.75 in tall; at 1:8 that is 9.84 in, which fits portrait with room for RU rulers and gutters |
| **Pull Sheet** | **ANSI A** | **portrait** | Carried, marked up, initialled |
| **Termination Schedule** | ANSI A | landscape | Reprinted on job-site printers |
| Equipment List, details | ANSI A | landscape | |

Non-US platform locale substitutes A4/A3. Mixed page sizes in one PDF are legal and universally supported; a **Uniform sheet size** checkbox exists for plotter workflows.

### 6.2 Fit, and the legibility trigger

```dart
double fitScale(Box content, Box avail) =>
    math.min(avail.width / content.width, avail.height / content.height);
```

Two things this must get right.

**Weights do not all scale.** Per CR-082 the distinction is a field on the stroke, not a global policy: cable traces, symbol outlines and rack rails **scale with geometry** (`Stroke.scaleWithGeometry`); sheet furniture uses `Stroke.hairlineFloor` with a **0.25 pt** print floor; UI chrome, selection halos and hit slop are constant in screen pixels and never reach the PDF. Minimum print stroke for signal geometry is **0.5 pt**, and **no stroke is ever emitted at 0**.

**Legibility, not user preference, decides sheet count.**

```dart
const kMinPrintPt = 6.0;   // hard floor
const kSoftPt     = 7.0;   // preferred

if (k * scene.minTextSizePt < kMinPrintPt) {
  // escalate, in order:
  //  1. next larger sheet size, if size escalation is permitted
  //  2. finer domain partition        (v1 — CR-073)
  //  3. TilingStrategy.geometric      (v1: over-tall single rack elevation only)
}
```

The outcome is reported in the export summary. `TilingStrategy.geometric` survives in the codebase for exactly one v1 case (**a single over-tall rack elevation**, never a schematic sheet) with a 0.5 in physical overlap band and `MATCH LINE — SEE SHEET …` along the shared edge. That edge label is a physical overlap marker on one elevation, not schematic sheet-boundary handling: match lines, off-sheet connectors and schematic tiling in the multi-sheet sense are deleted, not deferred (DR-004). Key plans, min-cut partitioning and general geometric tiling are cut (CR-073).

### 6.3 Why raster is disqualified, once, for the record

| Sheet | @300 dpi | Mpx | RGBA |
|---|---|---|---|
| ANSI A | 2550 × 3300 | 8.4 | 33.7 MB |
| **ANSI B** | **3300 × 5100** | **16.8** | **67.3 MB** |
| ANSI B @600 | 6600 × 10200 | 67.3 | 269 MB |

Peak is ~135 MB for one sheet once the PNG encode buffer is counted, multiplied by sheet count. **5100 px exceeds the 4096 max texture dimension** on a large installed base; Flutter silently clamps, so the failure mode is a quietly blurry deliverable with no error, the worst kind. Six-point schematic text at 300 dpi is 25 px tall and antialiases to mush. And text selection dies: an installer who cannot `Ctrl+F` a `W` number in a three-page schedule has a materially worse document (this is also RJ-015's reasoning for why real text, not tagged PDF, is where the accessibility budget goes). Vector: 80–400 KB per sheet. Raster: 3–15 MB per sheet.

---

## 7. The shared renderer

Everything above is policy and can be revised cheaply. This cannot. There is no off-the-shelf abstraction over `dart:ui Canvas` and `PdfGraphics`, dart_pdf ships no Canvas facade, and Syncfusion's `PdfGraphics` is a different, incompatible, commercially-licensed API. The answer is roughly 350 lines written once.

### 7.1 Packages: the boundary that makes it work

CR-083 rules **five packages**: the four from `design-architecture.md`, plus one that resolves the text-metric dependency by *inversion* rather than by contamination.

```
rackpal_core    pure Dart. no flutter, no dart:ui, NO pdf.
                 model, commands, derived, routing, draw/ (scene builders,
                 hit_test.dart, BoundsCanvas), persistence, units/, idformat/.
                 Declares abstract TextMeasurer + TextMetrics.
rackpal_text    pure Dart. core + package:pdf (for PdfTtfFont ONLY).
                 ~5 files. The single concrete TextMeasurer.
rackpal_export  pure Dart. core + rackpal_text + package:pdf.
                 PdfDiagramCanvas, sheets, furniture, tables, assembly.
                 The isolate entry point.
rackpal_ui      flutter. core + rackpal_text.
                 FlutterDiagramCanvas, render objects, widgets, canvas/input/.
apps/rackpal    everything + plugins.
```

`rackpal_ui` depending on `rackpal_text` is harmless, `package:pdf` is pure Dart and isolate-safe. The invariant that actually matters is preserved and mechanically enforced: **`rackpal_core`, where the scene builder lives, has no concrete font engine and no `dart:ui`.** It receives a `TextMeasurer` by injection. `no_flutter_import_test` bans `package:flutter/`, `dart:ui` **and** `package:pdf/` inside core.

Rejected: `design-pdf-export.md §10`'s single `lib/` tree with `backends/{pdf_canvas, flutter_canvas}.dart` side by side and `TextMeasurer` in the core tree, which would make core depend on `package:pdf` and is the arrangement `design-architecture.md §1.1` correctly predicts "will be violated within a month by an `Offset` that 'was just easier'".

Hit-testing splits by concern (CR-084): the *geometric* test (`DiagramScene.hits`, point-to-segment distance, nearest hit) lives in `rackpal_core/draw/hit_test.dart`, pure, synchronously testable, reusable by the read-only mobile shell. The *pointer plumbing* (one query per frame, spatial hash, cursor policy, hover throttle) lives in `rackpal_ui/canvas/input/`.

### 7.2 The pipeline

```
RackDocument (int-only model, Len = nm, Mass = µg)
   │
   ▼   rackpal_core/draw/scene_builder.dart
buildScene(doc, style, measurer, lodLevel) → DiagramScene
   │   THE renderer. Pure Dart. No dart:ui. No pdf.
   │   Len(nm) → diagram units in exactly one function (CR-007).
   ▼
DiagramScene { List<DiagramOp> ops; Box bounds;
               List<HitRegion> hits; double minTextSizePt;
               Map<String, Box> anchors; }
   │
   ├─► FlutterDiagramCanvas  (dart:ui Canvas)  → screen, preview, PNG   [ui]
   ├─► PdfDiagramCanvas      (PdfGraphics)     → PDF                    [pure]
   ├─► BoundsCanvas          (accumulator)     → bounds, hit regions    [pure]  v1
   └─► SvgDiagramCanvas      (StringBuffer)    → .svg                   [pure]  v1.1
```

**1 diagram unit = 1 PDF point = 1/72 in** (CR-007). Coordinates are `double` at this boundary only; the model stores integers and the `DiagramScene` is a transient artifact that is never persisted, so this is not a breach of "no doubles in the model". Conversion from `Len(nm)` happens in exactly one function in the scene builder. `design-architecture.md §6.6`'s hundredths-mm boundary is deleted.

Coordinate convention: **top-left origin, Y down, angles positive clockwise.** The PDF backend absorbs the flip once (§7.4).

`BoundsCanvas` ships in v1 and is not optional: scale-to-fit, tile counts and zoom-to-fit all require the diagram's true extent and there is no other way to get it (CR-089). `SvgDiagramCanvas` is one file on top of an architecture that already exists and ships in v1.1.

### 7.3 The interface

```dart
// rackpal_core/draw/canvas.dart — pure Dart, imports only geometry/style/path
abstract interface class DiagramCanvas {
  // ── state stack ────────────────────────────────────────────────────────
  void save();
  void restore();
  int  get saveCount;

  // ── transform (all CONCATENATE onto the current CTM) ───────────────────
  void translate(double dx, double dy);
  void scale(double sx, [double? sy]);
  void rotate(double radians);                 // positive = clockwise
  void transform(Matrix4 m);
  Matrix4 get currentTransform;                // for hairlineFloor + hit-test

  // ── clip (intersective; undone only by restore()) ──────────────────────
  void clipRect(Box r);
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero});

  // ── primitives ─────────────────────────────────────────────────────────
  void drawLine(Pt a, Pt b, Stroke s);
  void drawPolyline(List<Pt> pts, Stroke s, {bool close = false});
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke});
  void drawRect(Box r, {Fill? fill, Stroke? stroke});
  void drawRoundRect(Box r, Radii radii, {Fill? fill, Stroke? stroke});
  void drawCircle(Pt c, double radius, {Fill? fill, Stroke? stroke});
  void drawEllipse(Pt c, double rx, double ry, {Fill? fill, Stroke? stroke});
  void drawText(String text, Pt at, TextStyleSpec style);

  // ── raster — DR-029 §11.28.6's amendment. A REFERENCE, never pixels,
  //    and no opacity argument (row 9). ──────────────────────────────────
  void drawImage(ImageRef image, Box dst);

  // ── measurement — identical on every backend by construction (§7.5) ────
  TextMetrics measureText(String text, TextStyleSpec style);
}
```

This is the single declaration of `DiagramCanvas` in the corpus. [Architecture §8.1](03-architecture.md) cross-references it and does not restate it (CR-086). No method exists beyond the ones above, and none may be added without an amendment.

`drawImage`/`ImageRef` **are in the v1 interface as of DR-029**, and this sentence used to say the opposite. The Plan view ships in v1 and its `T1.01 Device Location Plan` prints a screened floorplan underlay, so the exported document is **no longer 100% vector**: there is a raster path, it has one consumer today and a second when DR-030's title-block logo lands, and `draw/canvas.dart`'s own amendment clause is what governs the addition. **The no-alpha property is unchanged and is defended separately**; see row 9 below, which is now the only thing standing between this document and an `ExtGState`.

Five decisions embedded in that shape:

- **`RendererCaps` is deleted** (CR-088). The moment a scene builder branches on capabilities there are two code paths and the abstraction has already leaked. The interface is the common denominator, and the rule that makes that denominator sufficient (**no gradients, no shadows, no blurs, no blend modes, no shaders**) is promoted from prose to an invariant with a test. Flat fills, strokes, dashes and text are what let the two backends agree *exactly* rather than approximately. That is a feature, not a limitation.
- **`measureText` returns `TextMetrics`, never `Pt`** (CR-087). A `Pt` cannot express a baseline, and the abstraction leaks precisely there.
- **Immediate-mode value objects, not retained setters.** `Stroke` and `Fill` travel with the draw call. They are therefore hashable, which is what makes the graphics-state cache in §7.10 possible, and a recorder cannot get out of sync with an interpreter.
- **`drawPolyline` is separate from `drawPath`** because orthogonal traces are the hottest primitive in this application and deserve a route that skips `DiagramPath` allocation entirely.
- **There is no `drawSvgPath`.** Authored connector-symbol `d` strings are parsed once, at catalog load, by `DiagramPath.fromSvg(String d)`. The canvas interface never parses strings, a backend that parses is a backend that can disagree with the other one, which is exactly what CR-086 exists to prevent.

`Stroke` carries `argb`, `widthPt`, `dash` (points, `List<double>?`), `dashPhase`, `cap`, `join`, `miterLimit` (10.0, matching PDF's default), plus `scaleWithGeometry` and `hairlineFloor` per CR-082, with value equality and `hashCode` on all of it. Dash patterns are in **points** (CR-079), stored in the registry as permille-points so the file stays integral: `6,3` is `[6000, 3000]`. Transform currency is `vector_math_64.Matrix4`, pure Dart, already a transitive dependency of `pdf`, accepted directly by `PdfGraphics.setTransform`, and `Matrix4.storage` is exactly the column-major `Float64List(16)` that `ui.Canvas.transform` wants. Zero conversion on either side; do not hand-roll a `Mat3`.

### 7.4 The Y-axis: global flip, and the gotcha

PDF user space is bottom-left, Y-up; diagram space is top-left, Y-down. Two candidate strategies: **(a)** per-coordinate flip `_y(y) => h - y` inside the adapter, or **(b)** one global `Matrix4(1,0,0,-1, 0,h)` pushed at construction.

**CR-085 rules (b), the global flip.** `design-architecture.md §6.6` argues for (a) and is internally inconsistent: the `DiagramCanvas` it declares three lines earlier contains `void rotate(double radians)`, and a rotation composed with per-coordinate negation is not a valid transform. Under (a), `_y()` applies to pre-transform coordinates while the CTM applies afterwards, so any non-translation transform silently produces mirrored or displaced geometry, a bug class that stays invisible until someone rotates a label 90° for a vertical rail, and is then diagnosed as "the PDF is wrong" three months later. Under (b) transforms compose correctly, text is counter-flipped in exactly one method, and `PdfGraphics.drawRect(r.left, r.top, r.width, r.height)` maps our `Box` verbatim with no `y' = H − top − height` arithmetic anywhere.

**The gotcha, recorded normatively because it will otherwise eat an afternoon:** `pw.CustomPaint` pre-translates the canvas to the *widget box's* bottom-left before calling the painter, so **the height you flip about is `size.y`, the widget's height: not the page height.** Getting it wrong offsets every diagram vertically by the margin, and the result looks plausible enough to ship.

### 7.5 Text metrics: CR-081, the load-bearing ruling

The trap: measure with `TextPainter` on screen and with `stringMetrics` in the PDF, and every measured width differs, so leader lines, callout boxes, port-label collision avoidance and centred text all disagree between screen and print. It gets reported as "the PDF doesn't match the preview" and it is miserable to chase.

Bundling the same TTF is **not** a sufficient fix; that is `design-architecture.md §12.3`'s answer and it is wrong, because Skia applies GPOS kerning and `liga` and dart_pdf applies neither. The fix is to eliminate `TextPainter` from the *layout* path entirely.

`PdfFont` / `PdfTtfFont` is pure Dart with no Flutter dependency, so it can be loaded and queried on the screen side, in the scene builder, and inside a background isolate, identically. Therefore:

1. Bundle each TTF **twice** in `pubspec.yaml`, under `fonts:` for Flutter's text engine and under `assets:` for `rootBundle.load()`. Declaring only the first makes the PDF silently fall back and every metric diverges (§10.2).
2. Load it into a `PdfTtfFont` in every context, main isolate, background isolate, screen renderer.
3. Inject one `TextMeasurer` into the scene builder, backed by `PdfFont.stringMetrics`.
4. `DiagramCanvas.measureText(String text, TextStyleSpec style)`, the **identical signature**, delegates to that same measurer on **every** backend, including the Flutter one.
5. `FlutterDiagramCanvas.drawText` still uses `TextPainter` to *rasterise* glyphs, Skia is far better at that than anything we would write, but **anchors using the injected metrics**, and disables `kern`, `liga` and `clig`.

```dart
// rackpal_core/draw/text.dart — pure Dart. Abstract only.
// THE declaration site. There is no draw/text_measurer.dart.
abstract interface class TextMeasurer {
  TextMetrics measureText(String text, TextStyleSpec style);
}

final class TextMetrics {
  final double advanceWidth, ascent, descent, capHeight, xHeight, lineHeight;
  const TextMetrics({required this.advanceWidth, required this.ascent,
                     required this.descent, required this.capHeight,
                     required this.xHeight, required this.lineHeight});
  double get height => ascent + descent;
}
```

```dart
// rackpal_text/pdf_font_measurer.dart — the ONE implementation.
final class PdfFontMeasurer implements TextMeasurer {
  PdfFontMeasurer(this._fonts);
  final Map<FontRef, PdfFont> _fonts;
  // Key is the 4-tuple EXTRACTED from the spec, never the TextStyleSpec object.
  // TextAnchor is deliberately excluded: it does not affect metrics, and
  // including it would multiply the cache 12x. Do not "simplify" this to
  // key on `style` — that is the bug.
  final _cache = <(String, FontRef, double, double), TextMetrics>{};

  @override
  TextMetrics measureText(String t, TextStyleSpec style) =>
      _cache.putIfAbsent(
          (t, style.font, style.sizePt, style.letterSpacing), () {
        final f = style.font, size = style.sizePt, ls = style.letterSpacing;
        final font = _fonts[f]!;
        final m = font.stringMetrics(t);   // VERIFY: signature; and whether
                                           // PdfFontMetrics * double exists
        return TextMetrics(
          advanceWidth: m.advanceWidth * size + ls * math.max(0, t.length - 1),
          ascent:      m.ascent.abs()  * size,
          descent:     m.descent.abs() * size,
          capHeight:   font.ascent * size * 0.72,
          xHeight:     font.ascent * size * 0.52,
          lineHeight:  (font.ascent - font.descent) * size,
        );
      });
}
```

Cache aggressively, a rack sheet re-measures the same designators hundreds of times. Both caches are sized at **12,000** entries: the `PdfFontMeasurer` metrics cache keyed on the 4-tuple above, and the paint-side label cache keyed on `(text, styleId, quantisedScale)`. 200 devices × 20 ports × 2 runs plus headers and tag pills is ~10,000 text runs, and a thrashing LRU is worse than none when eviction disposes a native `ui.Paragraph` in the paint path (AC-009).

**Anchor resolution lives in one shared pure-Dart helper**, so neither adapter ever guesses a baseline. `TextStyleSpec` carries an explicit 12-way `TextAnchor` including `baselineLeft/Center/Right`:

```dart
// rackpal_core/draw/text.dart — used verbatim by BOTH backends.
Pt anchorOffset(TextAnchor a, TextMetrics m) {
  final w = m.advanceWidth;
  final dx = switch (a) {
    TextAnchor.topLeft   || TextAnchor.midLeft   ||
    TextAnchor.bottomLeft|| TextAnchor.baselineLeft   => 0.0,
    TextAnchor.topCenter || TextAnchor.midCenter ||
    TextAnchor.bottomCenter || TextAnchor.baselineCenter => -w / 2,
    _ => -w,
  };
  final dy = switch (a) {                 // offset to the BASELINE
    TextAnchor.topLeft || TextAnchor.topCenter || TextAnchor.topRight
      => m.ascent,
    TextAnchor.midLeft || TextAnchor.midCenter || TextAnchor.midRight
      => m.ascent - m.height / 2,
    TextAnchor.bottomLeft || TextAnchor.bottomCenter || TextAnchor.bottomRight
      => -m.descent,
    _ => 0.0,                             // baseline* variants
  };
  return Pt(dx, dy);
}
```

**The parity test asserts on baseline Y**, not just the bounding box (AC-007), against a kerning-heavy fixture (`"AV Wa To Ty"`) agreeing within 0.5%. Bounding-box parity can pass while the baseline is off by the descent, and every leader line in the drawing hangs off the baseline.

### 7.6 Where the two backends diverge, and how each divergence is closed

| # | Concern | `dart:ui Canvas` | `PdfGraphics` | Reconciliation |
|---|---|---|---|---|
| 1 | Origin / Y sense | top-left, Y-down | bottom-left, Y-up | Global flip in the PDF adapter, about `size.y`. Diagram space is canonical. **CR-085** |
| 2 | Paint model | immutable `Paint` per call | stateful setters + `strokePath()` | Adapter owns the state; the interface stays immediate-mode |
| 3 | Path model | build `Path`, `drawPath(path, paint)` | stateful `moveTo`/`lineTo` + `fillPath()` | Adapter replays `DiagramPath` verbs into whichever shape the backend wants |
| 4 | Fill **and** stroke | one `Paint`, two calls | build path twice, or the `B` operator | Adapter emits the path twice. Costs bytes, not correctness; §7.10 mitigates |
| 5 | **Dash** | **none: `dart:ui` has no dashing** | native `setLineDashPattern` | Flutter side synthesises via `path_drawing`'s `dashPath` and **caches the dashed `ui.Path` per (geometry, dash) pair**. Keep `dashPhase` at 0 for parity: PDF's phase offsets into the pattern, `dashPath` restarts per sub-path |
| 6 | **Text metrics** | `TextPainter`, full shaping | `PdfFont.stringMetrics`, unkerned advances | **`stringMetrics` is the single source of truth on both backends. CR-081** |
| 7 | **Kerning / ligatures** | Skia applies GPOS `kern` and `liga` | dart_pdf applies neither | `FontFeature.disable('kern')`, `disable('liga')`, `disable('clig')` on the Flutter side. Without this, screen text is 1–3% narrower than print and every collision calculation disagrees. **CR-081** |
| 8 | Colour space | `ui.Color`, sRGB 8-bit ARGB | `PdfColor`, 4 × double, **DeviceRGB** | `PdfColor.fromInt(argb)`. DeviceRGB is unmanaged; mitigations are the CMYK palette (pure black `0,0,0,1`, never rich black) and explicit grey values for greyscale rather than luminance conversion. sRGB `OutputIntent` is v1.1 |
| 9 | **Alpha** | per-`Paint` alpha | no per-paint alpha; needs `ExtGState` | **Do not use alpha in the document: absolutely, with no exception.** Tints are pre-composited at palette-definition time (18% over white). Alpha is reserved for the on-screen selection highlight, which never reaches the PDF. The former exception was the logo-opacity path; **DR-030 returns the logo and deliberately does NOT return its opacity**, so the rule survives it. **The Plan view's SCREENED underlay is SETTLED, and not the way this row said** (DR-037 §11.36.3): screening by per-image alpha would emit the first `ExtGState` this document has ever carried, so it is not used, but the flatten and the screen both happen **where the `PdfImage` is built, in the export backend**, and NOT pre-composited at import. The stored bytes stay the architect's page, so the screening percentage is a code change rather than a re-import of every underlay in every project a user owns. Two consequences PLAN-A implements: `drawImage` takes **no opacity argument**, so there is no route from this feature to an `ExtGState`; and the resolver MUST pass `alpha: false`, because `PdfImage(..., alpha: true)` writes an `/SMask` with nobody calling `setGraphicState`, which is not the failure this row was written about and which this row forbids anyway. Gated over the saved bytes by `pdf_canvas_image_test.dart`. |
| 10 | Miter limit | `strokeMiterLimit` default **4** | PDF default **10** | Set `strokeMiterLimit = 10` on the Flutter side to match PDF, not the reverse. Invisible for orthogonal traces (90° miter ratio √2 ≈ 1.414), visible on acute symbol paths |
| 11 | Line cap | default butt | default butt | 1:1. Keep butt on dashed traces: round caps change apparent dash length on both |
| 12 | Transform | `Canvas.transform` concatenates | `setTransform(Matrix4)` **concatenates** despite the name | 1:1. `Matrix4.storage` feeds `Canvas.transform` directly. Always bracket with save/restore |
| 13 | Clip | part of save/restore, intersective | `clipPath()` consumes the current path, intersective | Semantics match; there is no "unclip" on either side |
| 14 | Zero-width strokes | `0` → one device pixel | `0` → thinnest device line, invisible at 2400 dpi | **Never emit 0.** Clamp in `_applyStroke` on both backends: 0.5 pt signal floor, 0.25 pt furniture floor (CR-082) |
| 15 | Winding under flip | — | the flip reverses winding | Only matters for `evenOdd` on nested subpaths. Symbol paths do not nest; `addEllipse` emits a consistent direction |
| 16 | Text wrapping | `TextPainter` wraps and shapes | `drawString` is single-line, baseline-origin | The interface has **no wrapping**. Multi-line is the scene builder's job: measure, split, emit N `drawText` calls at a computed leading. Layout belongs in the builder, not the backend |
| 17 | Images | full format support | `PdfImage`, pre-decoded | **IN v1 as of DR-029**, where this row used to read *"Not in v1"*. Two consumers: the Plan view's screened underlay on `T1.01`, and DR-030's title-block logo. Both ride DR-019's zip container, both store PNG or JPEG, and neither may use alpha (row 9) |
| 18 | OS text scaling | inherits accessibility scale | none | `textScaler: TextScaler.noScaling`. Without it a user at 125% OS scaling sees labels 25% larger than the PDF and blames the PDF |

### 7.7 The two adapters

```dart
// rackpal_export/draw/pdf_canvas.dart — PURE DART. Isolate-safe. No Flutter.
final class PdfDiagramCanvas implements DiagramCanvas {
  PdfDiagramCanvas({
    required PdfGraphics graphics,
    required double boxHeight,        // MUST be pw.CustomPaint's size.y — §7.4
    required Map<FontRef, PdfFont> fonts,
    required TextMeasurer measurer,
  }) : _g = graphics, _fonts = fonts, _measurer = measurer {
    _g.saveContext();
    _g.setTransform(Matrix4.identity()
      ..setEntry(1, 3, boxHeight)     // translate y
      ..setEntry(1, 1, -1.0));        // scale y by -1  → one global flip
    _stack.add(Matrix4.identity());
  }

  final PdfGraphics _g;
  final Map<FontRef, PdfFont> _fonts;
  final TextMeasurer _measurer;
  final List<Matrix4> _stack = [];

  void dispose() => _g.restoreContext();   // balances the constructor

  @override void save()    { _g.saveContext();    _stack.add(_stack.last.clone()); }
  @override void restore() { _g.restoreContext(); _stack.removeLast(); }
  void _apply(Matrix4 m)   { _g.setTransform(m);  _stack.last.multiply(m); }

  @override void rotate(double r) => _apply(Matrix4.rotationZ(r));

  /// Uniform scale of the CTM — powers hairlineFloor and the width clamp.
  double get _k {
    final m = _stack.last;
    return math.sqrt(
        (m.entry(0,0)*m.entry(1,1) - m.entry(0,1)*m.entry(1,0)).abs());
  }

  void _applyStroke(Stroke s) {
    final k = _k == 0 ? 1.0 : _k;
    var w = s.hairlineFloor ? s.widthPt / k : s.widthPt;
    final floor = s.hairlineFloor ? 0.25 : 0.5;      // pt — CR-082
    if (w * k < floor) w = floor / k;
    _g..setStrokeColor(PdfColor.fromInt(s.argb))
      ..setLineWidth(w)
      ..setLineCap(_cap(s.cap))
      ..setLineJoin(_join(s.join))
      ..setLineDashPattern(s.dash ?? const <num>[], s.dashPhase.round());
  }

  @override
  void drawRect(Box r, {Fill? fill, Stroke? stroke}) {
    // Under the global flip, (left, top, w, h) is already correct — no y math.
    if (fill != null) {
      _g.saveContext(); _applyFill(fill);
      _g..drawRect(r.left, r.top, r.width, r.height)..fillPath();
      _g.restoreContext();
    }
    if (stroke != null) {
      _g.saveContext(); _applyStroke(stroke);
      _g..drawRect(r.left, r.top, r.width, r.height)..strokePath();
      _g.restoreContext();
    }
  }

  @override
  TextMetrics measureText(String t, TextStyleSpec s) => _measurer.measureText(t, s);

  @override
  void drawText(String text, Pt at, TextStyleSpec s) {
    final font = _fonts[s.font]!;
    final m    = measureText(text, s);
    final o    = anchorOffset(s.anchor, m);      // ← the SHARED helper

    _g.saveContext();
    _applyFill(Fill(s.argb));
    // Counter-flip locally so glyphs are upright, then apply the caller's
    // rotation. Sign is negated because the local frame is now Y-up.
    _g.setTransform(Matrix4.identity()
      ..setEntry(0, 3, at.x)
      ..setEntry(1, 3, at.y)
      ..multiply(Matrix4.identity()..setEntry(1, 1, -1.0))
      ..multiply(Matrix4.rotationZ(-s.rotationRad)));
    _g.drawString(font, s.sizePt, text, o.x, -o.y, charSpace: s.letterSpacing);
    _g.restoreContext();
  }
}
```

Wiring it to a page, note `size.y`:

```dart
doc.addPage(pw.Page(
  pageTheme: sheetTheme,                  // border + title block, §5
  build: (ctx) => pw.CustomPaint(
    size: PdfPoint(usableW, usableH),
    painter: (PdfGraphics g, PdfPoint size) {
      final c = PdfDiagramCanvas(
        graphics: g,
        boxHeight: size.y,                // ← size.y, NOT page height (§7.4)
        fonts: fonts,
        measurer: measurer,
      );
      scene.replay(c);
      c.dispose();
    },
  ),
));
```

```dart
// rackpal_ui/draw/flutter_canvas.dart — the ONLY renderer file importing dart:ui.
final class FlutterDiagramCanvas implements DiagramCanvas {
  FlutterDiagramCanvas(this._c, {required TextMeasurer measurer})
      : _measurer = measurer { _stack.add(Matrix4.identity()); }

  final ui.Canvas _c;
  final TextMeasurer _measurer;
  final List<Matrix4> _stack = [];
  static final _dashCache = <(_PathKey, _DashKey), ui.Path>{};

  ui.Paint _strokePaint(Stroke s) {
    final k = _k == 0 ? 1.0 : _k;
    var w = s.hairlineFloor ? s.widthPt / k : s.widthPt;
    final floor = s.hairlineFloor ? 0.25 : 0.5;
    if (w * k < floor) w = floor / k;
    return ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..color = ui.Color(s.argb)
      ..strokeWidth = w
      ..strokeCap = _cap(s.cap)
      ..strokeJoin = _join(s.join)
      ..strokeMiterLimit = s.miterLimit    // 10.0 to match PDF — divergence 10
      ..isAntiAlias = true;
  }

  /// dart:ui has NO dash support. Synthesise, and cache — regenerating a few
  /// hundred dashed traces every frame is a measurable frame-budget hit.
  ui.Path _dashed(ui.Path p, Stroke s) => s.dash == null ? p
      : _dashCache.putIfAbsent((_PathKey(p), _DashKey(s.dash!)),
          () => dashPath(p, dashArray: CircularIntervalList<double>(s.dash!)));

  @override
  TextMetrics measureText(String t, TextStyleSpec s) =>
      _measurer.measureText(t, s);                 // ← NOT TextPainter

  @override
  void drawText(String text, Pt at, TextStyleSpec s) {
    final m = measureText(text, s);              // PDF metrics
    final o = anchorOffset(s.anchor, m);         // the SAME shared helper

    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        fontFamily: _familyFor(s.font),          // SAME TTF as the PDF (§10.2)
        fontSize: s.sizePt,
        color: ui.Color(s.argb),
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: s.letterSpacing,
        fontFeatures: const [FontFeature.disable('kern'),   // divergence 7
                             FontFeature.disable('liga'),
                             FontFeature.disable('clig')],
      )),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,          // divergence 18
    )..layout();

    _c.save();
    _c.translate(at.x, at.y);
    if (s.rotationRad != 0) _c.rotate(s.rotationRad);
    // Position by BASELINE using our metrics — identical math to the PDF side.
    tp.paint(_c, ui.Offset(o.x,
        o.y - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)!));
    _c.restore();
  }
}
```

Note `drawRoundRect` on the Flutter side builds from **our** `DiagramPath` cubics rather than `ui.RRect`, so the control points match the PDF exactly. Kappa is `0.5522847498307933` on both sides.

### 7.8 CR-086: the ruling that closes the last hole

Two documents each described half of the rendering story and no document noticed the contradiction. `design-architecture.md` D4 states that a display list is the single drawing IR and that "screen and print cannot diverge". The same document's §6.2, and all three UX documents, then state that device faceplates, ports and reference designators are drawn by **real widgets**. The consequence: the most information-dense content in the deliverable would be drawn by a widget tree on screen and by a scene builder in print, with no parity mechanism, defeating D4 exactly where it matters most. `design-pdf-export.md`'s parity test compares the two *canvas backends*, not the two *device renderers*, so it would have passed while the faceplates diverged.

**Ruling: one rendering path; widgets remain as an interaction and semantics shell.**

```
RenderRackCanvas
 └── RenderDeviceBox (one per DeviceInstance)
      ├── hitTest / focus / hover / keyboard / Semantics   ← the widget owns this
      └── paint(context, offset) {
            final canvas = FlutterDiagramCanvas(context.canvas,
                                                measurer: measurer);
            scene.fragmentFor(deviceId).replay(canvas);   ← pixels come from the IR
          }
```

Each device is still a `RenderBox` child of `RenderRackCanvas`, it owns hit-testing, focus, hover, keyboard handling and `Semantics`, which is what makes the accessibility story true and the outline tree possible. But its `paint()` **replays that device's `DiagramScene` fragment through `FlutterDiagramCanvas`**; it draws nothing itself. Pixels come from the shared IR; behaviour comes from the widget. Both documents get what they argued for, D4's guarantee holds where it matters, and the parity test covers faceplates by construction. Canon calls this "the single most consequential architectural ruling in this record".

Two consequences follow immediately. First, `rackpal_core/draw/` gains `panel_layer.dart` and `symbol_layer.dart` in v1: a schematic symbol cannot be a widget-only artifact if it is to print (CR-071, CR-086). Second, `DiagramScene` must be **fragment-addressable**, `scene.fragmentFor(entityId)` returns the op range for one entity, which is also what lets the wire layer split into eight per-domain sub-pictures so an edit to one HDMI run rebuilds ~1,200 ops instead of ~10,000 (AC-008).

### 7.9 The display list, and why the recorder earns its place

```dart
// rackpal_core/draw/ops.dart — pure Dart
sealed class DiagramOp { void replay(DiagramCanvas c); }

final class OpLine extends DiagramOp {
  final Pt a, b; final Stroke s;
  const OpLine(this.a, this.b, this.s);
  @override void replay(DiagramCanvas c) => c.drawLine(a, b, s);
}
// OpPolyline · OpRect · OpRoundRect · OpCircle · OpPath · OpText · OpImage
// OpSave · OpRestore · OpTransform · OpClipRect

final class DiagramScene {
  final List<DiagramOp> ops;
  final Box bounds;                   // → scale-to-fit, tile counts
  final List<HitRegion> hits;         // → editor selection (CR-084)
  final double minTextSizePt;         // → the legibility trigger (§6.2)
  final Map<String, IntRange> fragments;  // → CR-086 per-entity replay
  void replay(DiagramCanvas c) { for (final op in ops) op.replay(c); }
}
```

Four returns on ~60 lines: **bounds** (there is no other way to compute scale-to-fit); **hit-testing** as pure geometry; **golden tests on data rather than pixels**: `expect(scene.ops.whereType<OpText>().map((o) => o.text), contains('RK-1'))`, with no Flutter binding, no PDF bytes, and none of the flakiness of image diffing; and **a fourth backend costs one file**.

`lodLevel` is explicit in every scene-builder signature and every cache key (AC-016/#13), LOD is never inferred from a zoom value at the point of use.

### 7.10 Content-stream size

Every primitive above brackets itself in `saveContext`/`restoreContext`, which emits a `q`/`Q` pair plus a full set of `RG`/`w`/`d`/`J`/`j` operators. At 10,000 ops that is perhaps 1.5 MB of content stream where 300 KB would do. The fix, given value equality on `Stroke`/`Fill`, is a state cache that skips redundant setters and invalidates on `save`/`restore`, combined with sorting the display list by style within each z-layer so state changes collapse to roughly one per unique style, under twenty for a typical sheet.

**Not done in v1.** Keep the hook, the equality operators and the `_lastStroke`/`_lastFill` fields, so it is a one-day change, and do not spend the day until a real project produces a file you would be embarrassed to email.

---

## 8. Export UX

### 8.1 The dialog

`Ctrl+P` is the export dialog everywhere, arbitrated once against the ~18 keymap collisions the corpus carried (CR-101). Three columns: **What** (preset + sheet list), **How** (page setup, diagram, schedule, palette, title block), **Preview** (live, right).

```
╔═══════════════════════╤═══════════════════════════════╤═══════════════════════════╗
║ PRESET                │ PAGE SETUP                    │  ┌─────────────────────┐  ║
║ ◉ Full set            │ Diagram   [ANSI B ▾][Landsc▾] │  │                     │  ║
║ ○ Installer set       │ Schedules [ANSI A ▾][per role]│  │   live sheet        │  ║
║ ○ Client set          │ Elevations[Portrait ▾]        │  │   preview           │  ║
║ ○ As-built            │ ☐ Uniform sheet size          │  │   (screen renderer) │  ║
║ ○ This sheet only     │ Units     [Imperial ▾]        │  └─────────────────────┘  ║
║ ○ Custom…             │                               │   ◀  3 / 14  ▶            ║
║                       │ DIAGRAM                       │   T6.01 Interconnect —    ║
║ SHEETS       14 total │ Partition [By signal domain ▾]│   Video                   ║
║ ☑ T0.00 Cover & index │ Scale     [Fit to sheet ▾]    │                           ║
║ ☑ T0.01 Symbol legend │ ☑ Cable IDs on traces         │   ⚠ 3 notices             ║
║ ☑ T0.02 Exceptions ⚠  │ ☑ Port designators            │   · 2 open errors — the   ║
║ ☑ T2.01 RK-1 front    │                               │     ISSUED FOR CONSTRUC-  ║
║ ☑ T2.02 RK-1 rear     │ SCHEDULE                      │     TION stamp is off     ║
║ ☑ T6.01 Video         │ Sort  [per preset ▾]          │   · W055 DTE↔DTE without  ║
║ ☑ T6.02 Audio         │ Group [Room ▾]                │     null-modem (CON-004)  ║
║ ☑ T6.03 Network       │ Cols  [Choose… 10 of 19]      │   · 14 links have no      ║
║ ☑ T6.04 Control       │ ☑ Zebra striping              │     length — LEN advisory ║
║ ☑ T6.05 Power         │ ☐ Include jumpers & cords     │                           ║
║ ☑ T6.06 Structure     │                               │                           ║
║ ☑ T6.10 Pull sheet    │ PALETTE                       │                           ║
║ ☑ T6.11 Termination   │ ◉ Colour ○ Greyscale ○ CMYK   │                           ║
║ ☑ T6.20 Unused runs   │ ☐ ISSUED FOR CONSTRUCTION  ⚠  │                           ║
║ ☑ T6.30 Equipment     │ ☐ Embed .rppj source      │                           ║
║ ☐ T5.01 Pinout detail │                               │                           ║
╠═══════════════════════╧═══════════════════════════════╧═══════════════════════════╣
║  Est. 14 sheets · ~420 KB               [ Verify output ] [ Cancel ]  [ Export ]   ║
╚════════════════════════════════════════════════════════════════════════════════════╝
```

Four design notes.

1. **Presets first, checkboxes second.** Selecting a preset sets the sheets and the switches; touching any switch moves the radio to `Custom…`.
2. **Notices are surfaced before export, never as a block.** Open `Finding`s appear in the preview pane with jump-to-sheet links, and the only thing they gate is the `ISSUED FOR CONSTRUCTION` checkbox, which greys out with the reason stated (CR-022, G3).
3. **The live preview is rendered by the screen backend**, not by pdfium, same `DiagramScene`, same furniture, same fonts, same metrics, so it is faithful by construction, instant, and needs no native dependency. This is the payoff for §7 and it is the headline preview (CR-100).
4. **Size and page-count estimates come from a dry run** over the resolved sheet list, costing ~10 ms. Above 40 sheets it warns; the hard cap is 2000 (AC-050/A7.4).

### 8.2 Isolate generation, progress and cancel

`doc.save()` blocks, and so does the widget layout pass. The whole export runs off-thread. **The constraint that catches everyone: a background isolate has no `rootBundle`, no plugins, no platform channels, no `BuildContext`.** Load every font to `Uint8List` on the main isolate, then send plain bytes and JSON. There are no images to load, the document carries no raster (RJ-017, §7.6 divergence 17).

`Isolate.run` supports neither progress nor cancellation, so **CR-099 rules `Isolate.spawn` plus a `SendPort` pair** for export. `Isolate.run` is used only where neither is wanted, autosave serialisation.

```dart
// main isolate: gather everything Flutter-dependent, then hand over bytes.
final assets = ExportAssets(
  bodyTtf:     await _bytes('assets/fonts/IBMPlexSans-Regular.ttf'),
  bodyBoldTtf: await _bytes('assets/fonts/IBMPlexSans-SemiBold.ttf'),
  condTtf:     await _bytes('assets/fonts/IBMPlexSansCondensed-Regular.ttf'),
  monoTtf:     await _bytes('assets/fonts/IBMPlexMono-Regular.ttf'),
  monoBoldTtf: await _bytes('assets/fonts/IBMPlexMono-Bold.ttf'),
  symbolTtf:   await _bytes('assets/fonts/NotoSansSymbols2-Regular.ttf'),
);

final rx = ReceivePort()..listen((m) {
  if (m is ExportProgress) controller.update(m);
  if (m is ExportResult)   controller.complete(m);
});

final iso = await Isolate.spawn(exportEntry,
    ExportRequest(rx.sendPort, jsonEncode(doc.toJson()),
                  jsonEncode(spec.toJson()), assets));

cancelButton.onPressed = () => iso.kill(priority: Isolate.immediate);
// On web (not a v1 target): kIsWeb ? buildDocument(req) : spawn(...)
```

There is no partial-result recovery; an aborted export produces nothing, which is correct. Do not use `compute()` in a loop, one spawn per export is the right granularity, and do not pool.

Progress is weighted by phase, not a spinner, and is shown inline in the dialog. Under 400 ms it is not shown at all, flashing a bar for a three-sheet export looks worse than a brief pause. (Progress and cancel are required on *every* operation over ~500 ms, not just export, AC-058/D14.)

| Phase | Weight | Reportable unit |
|---|---|---|
| 1. Build scenes | 25% | per sheet |
| 2. Place, assign zones | 10% | one step |
| 3. Emit PDF (layout + serialise) | 65% | per sheet, then a final "writing" step |

**This works only because §7 kept the renderer free of `dart:ui`.** The isolate requirement and any future server-side export point at the same architectural decision; make it once, up front, because retrofitting it means touching every drawing call site.

### 8.3 Preview and save

Two preview levels. The **sheet preview** is primary, is the screen backend, and has no native dependency. **Output verification**, rendering the actual bytes, sits behind an explicit `Verify output` button, and the pdfium binaries it needs are **vendored into the repo** rather than downloaded at build time, because a network-fetched binary in a signed release is a supply-chain and reproducibility problem, not just a CI problem. **v1 ships Export-to-PDF plus "Open in system viewer"; the OS print dialog is v1.1**, pending a spike confirming that `Printing.layoutPdf` on Windows does not itself require fetched pdfium (CR-100).

Saving uses **the app's own save dialog**, `lib/src/session/file_picker.dart` over `windows/runner/file_dialog_channel.cpp`, *not* `file_selector`, which was removed from the project because it cannot set `FOS_DONTADDTORECENT` (docs/03 §10.1; `session_layering_test.dart` RULE 14d fails the build if it comes back). The PDF path gets the same dialog, the same `.rppj`-style filter mechanics and the same MRU behaviour as document Save As, for free. Default filename `{project-slug}_{rack-or-SET}_rev{REV}_{yyyy-MM-dd}.pdf` → `smith-residence_SET_revC_2026-07-18.pdf`. The revision in the filename is not optional; it is the only thing that stops the wrong PDF being on site. A deliverable is never silently written to `getApplicationDocumentsDirectory()`.

| Target | Save | Print | Share |
|---|---|---|---|
| Windows / macOS / Linux | `getSaveLocation` + `XFile.saveTo` | `Printing.layoutPdf`: **v1.1** | `Printing.sharePdf` (weak on Win/Linux) |
| iOS / Android (read-only) | `Printing.sharePdf` | `Printing.layoutPdf` | VERIFY: `bounds:` is reportedly required in practice on iPad |
| Web (not a v1 target) | Blob URL, not `data:` | — | download |

VERIFY: 11×17 on Windows reportedly needs `forceCustomPrintPaper: true` to reach the driver; and `dynamicLayout: true` re-invokes the layout callback when the user changes paper size, so the callback must honour the `PdfPageFormat` it receives.

Afterwards, a completion strip rather than a modal: `Exported 14 sheets · 438 KB · 3.1 s` with **[Open] [Show in folder] [Print] [Copy path]**. The file-layer error surface is fully enumerated, including "target PDF is open in Acrobat" (AC-058/D3, D4).

### 8.4 Determinism

Two exports of an unmodified project differ only in the date field. That means stable iteration order everywhere (sort by UUID, never rely on `Map` order) no `DateTime.now()` outside the one date field, and no random identifiers in the PDF. This is what makes golden-file testing possible and makes "did anything actually change between rev B and rev C?" answerable with `diff`. It is also downstream of P5: designators are stored at allocation, so they cannot drift between exports.

Document metadata is set (`title`, `author`, `creator`, `subject`, `keywords`) so the file is findable in a client's DMS. **Embedding the source**, attaching the `.rppj` inside the PDF via PDF/A-3b, is offered as a checkbox: the drawing then carries its own editable source, so a client or a successor integrator receives one file containing both the deliverable and the project. Costs almost nothing; worth having.

---

## 9. Non-PDF exports

| Export | Cost given §7 | Value | Ships |
|---|---|---|---|
| CSV: Pull Sheet / Termination Schedule | trivial | high | v1 |
| CSV: Equipment List and Materials | trivial | high | v1 |
| **CSV: cable label file** | trivial | **very high** | v1 |
| SVG: one sheet | ~120 lines, one file | high | v1.1 (CR-089) |
| PNG: one sheet | ~40 lines with a size cap | medium | v1.1 |
| JSON netlist | trivial; it is the model | medium | v1.1 |
| XLSX | one dependency, ~200 lines | medium | on demand |
| DXF | ~400 lines, new geometry mapping | **high** | **v1.3** (DR-188 §11.187.4) |
| DWG | a licence collision, not a line count | n/a | **declined**: the open writer is GPL-3.0 and would serve, the commercial route is GPL-incompatible (DR-188 §11.187.4) |

**The DXF row moved from `low` / `not planned` at DR-188 §11.187.4, and the COST estimate was not
what changed.** ~400 lines still looks right, because `DiagramCanvas` is an abstract interface with
two production backends already and this is a third. What moved is the **value**, on trade knowledge
this table did not have when it was written: an interchange file is what another trade x-refs into
its own set, and the Device Location Plan is the one sheet whose geometry is already in real-world
units. §12.39 carries the supersession.

### 9.1 CSV

The schedule and equipment list are already `List<List<String>>` by the time they reach the table emitter, so CSV is that array with quoting. Two things to get right: emit a **UTF-8 BOM** so Excel on Windows does not mangle `Ω` and `′`, and **quote every field** unconditionally, because model strings contain commas.

### 9.2 The cable label file

The highest value per line in the list. Brady, DYMO Rhino, Brother P-touch and Panduit software all import CSV. Emit one row per **label**, not per `Link`, four per run, per residential practice: two labels 2–4 ft apart on each end, so one survives re-termination.

```csv
label_text,line2,line3,cable_id,end,copy
"W014","TX-1 LINK OUT","-> PP-1 A03","W014","A",1
"W014","TX-1 LINK OUT","-> PP-1 A03","W014","A",2
"W014","PP-1 A03","<- TX-1 LINK OUT","W014","B",1
"W014","PP-1 A03","<- TX-1 LINK OUT","W014","B",2
```

Lines 2 and 3 follow AVIXA F501.01: the label states **where the cable connects**, not what it is. `OUT 1 Laptop`, not `HDMI cable`. Where a `StructureOrigin` exists, the field end's label text is `fieldLabel` and the rack end's is `rackLabel`.

### 9.3 What §7 makes cheap

SVG export is one file with no new geometry or text handling, and Y-down is native to SVG, so there is no flip at all; use `textLength` with the measured advance width so a consumer with different font metrics cannot reflow the labels. PNG is the screen backend into a `ui.PictureRecorder` (never a `RepaintBoundary`) with a hard 4096 px guard, because Flutter silently clamps above it. Thumbnails and any future key plan are the same scene replayed at a different scale. Golden tests assert on `DiagramScene.ops`. A future server-side or web export needs no new renderer. **None of that is free if the diagram is drawn twice**, which is the whole argument for CR-086.

---

## 10. Fonts

### 10.1 IBM Plex, and why not the built-ins

The 14 standard Type1 fonts embed nothing but are single-byte WinAnsiEncoding, and any codepoint outside Latin-1 throws `Helvetica has no Unicode support`. For this product that is not theoretical: A/V documentation routinely carries `Ω`, `°`, `±`, `µ`, `→`, `×`, `≈`, `′`/`″`, em dashes, smart quotes pasted from a proposal, and client names with accents. Never ship default Helvetica. `PdfGoogleFonts` is equally out; it does a network round-trip, so it cannot run in a background isolate and fails offline, which is exactly the rack room with no Wi-Fi where someone re-exports a drawing.

**CR-080 rules IBM Plex**, over `design-architecture.md §12.3`'s asserted Inter + JetBrains Mono.

| Alias | Font | Licence | Size |
|---|---|---|---|
| `RackBody` | IBM Plex Sans Regular + SemiBold | SIL OFL 1.1 | ~300 KB |
| `RackCond` | IBM Plex Sans Condensed Regular | SIL OFL 1.1 | ~140 KB |
| `RackMono` | IBM Plex Mono Regular + Bold | SIL OFL 1.1 | ~260 KB |
| *(fallback)* | Noto Sans Symbols 2 Regular | SIL OFL 1.1 | ~300 KB, subsettable to ~25 KB |
| | | **Bundle** | **~1.0 MB** |

Three arguments carry it, and they are worked rather than asserted. Plex Mono disambiguates `0`/`O`, `1`/`l`/`I`, `5`/`S`, `8`/`B`, in a document whose purpose is transcribing identifiers onto physical labels, `W014` vs `WO14` is a real failure mode, which makes this a safety property rather than an aesthetic one. Plex Sans Condensed is a true condensed cut worth ~12% of schedule column width, which is the difference between a 10-column and a 12-column table. And Greek coverage gives `Ω` and `µ` without a fallback hop. Runners-up rejected: Inter (no true condensed cut, mono companion is a separate project with different metrics) and Roboto (reads as Android UI, and Roboto Condensed's metrics do not match Roboto's).

**Licensing:** SIL OFL 1.1 is registered via `LicenseRegistry` and surfaced through `showLicensePage` (AC-058/D7). OFL permits commercial use, PDF embedding and redistribution with no attribution obligation in the output document; the only clause that matters is that the fonts themselves are not sold, which they are not.

### 10.2 The two-declaration trap

Declaring a font under `fonts:` makes it available to Flutter's text engine but **not** to `rootBundle.load()`, which is what `pw.Font.ttf` needs. Both entries are required, or the PDF silently falls back and every metric diverges, the exact failure §7.5 exists to prevent.

```yaml
flutter:
  fonts:
    - family: RackBody
      fonts:
        - asset: assets/fonts/IBMPlexSans-Regular.ttf
        - asset: assets/fonts/IBMPlexSans-SemiBold.ttf
          weight: 600
    - family: RackCond
      fonts:
        - asset: assets/fonts/IBMPlexSansCondensed-Regular.ttf
    - family: RackMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
        - asset: assets/fonts/IBMPlexMono-Bold.ttf
          weight: 700
  assets:
    - assets/fonts/          # ← REQUIRED as well, for rootBundle.load()
```

`fontFallback: [plexMono, notoSymbols2]` is set on the document theme even where it seems unnecessary: it is per-glyph, and the failure mode without it is a thrown exception mid-export. Belt and braces, a sanitiser maps unrepresentable codepoints to ASCII (`→` → `->`, `☐` → `[ ]`) rather than throwing, and it runs **in the scene builder, not the backend**, so the screen shows exactly what the PDF will show. A CI test asserts that every glyph in `SignalDomainDef` resolves in `RackBody` or the Noto fallback; a tofu box in an exported drawing is the defect that test exists to prevent.

**Size cost, honestly.** ~1.0 MB in the app bundle, irrelevant on desktop and irrelevant next to the Flutter engine on mobile. In the PDF, dart_pdf subsets TrueType to used glyphs, a rack drawing uses perhaps 80 distinct glyphs across three faces, so the embedded contribution is **~8–25 KB**, and a 14-sheet vector set lands at 300–500 KB.

---

## 11. Verification and exit gates

### 11.1 Unverified package claims

Every item below is cheap to confirm with a 30-line spike and expensive to discover late. Write the spike first; it is step 1 of the build order.

| # | VERIFY: | Why it matters |
|---|---|---|
| 1 | `PdfFont.stringMetrics(String)` exact signature, and whether a `PdfFontMetrics * double` operator exists | Everything in §7.5 funnels through one wrapper, so a fix is localised, but confirm before building on it |
| 2 | Whether `pw.Table.headerCount` repeats the header on each page fragment | §3.7 sidesteps it with manual pagination; confirm anyway so the workaround's necessity is known |
| 3 | `PageTheme.buildBackground` / `buildForeground` parameter names | All sheet furniture attaches here |
| 4 | The rotation sign in `drawText`'s counter-flip matrix | Render a 45°-rotated string on both backends and overlay them. Sign errors here are invisible until someone rotates a rail label |
| 5 | `Printing.layoutPdf` on Windows without fetched pdfium; `forceCustomPrintPaper` for 11×17 | Gates whether the OS print dialog can ship in v1.1 (CR-100) |
| 6 | `MultiPage.maxPages` validation behaviour in release builds | The 2000 cap must actually hold |

### 11.2 Test gates

| Gate | Assertion |
|---|---|
| `no_flutter_import_test` | `rackpal_core` imports no `package:flutter/`, no `dart:ui`, **no `package:pdf/`** (CR-083) |
| Headless document build | A full sheet set builds under `dart test`, not `flutter test` (P3) |
| **Baseline parity** | One fixture scene through both backends; **baseline Y** agrees, not merely the bounding box; kerning-heavy fixture `"AV Wa To Ty"` within 0.5% (CR-081, AC-007) |
| Faceplate parity | A `RenderDeviceBox` paint and the PDF sheet resolve to the same op range (CR-086) |
| Interface purity | No op carries a gradient, shadow, blur, blend mode or shader (CR-088) |
| Stroke floor | No emitted stroke width is 0; furniture floors at 0.25 pt, signal geometry at 0.5 pt (CR-082) |
| Scene goldens | Assertions on `DiagramScene.ops`: no pixels, no PDF bytes |
| Determinism | Two exports of an unmodified fixture are byte-identical except the date field |
| Sheet-count dry run | Warning above 40 sheets, hard cap 2000 (AC-050/A7.4) |
| **Physical print matrix** | Laser at ANSI B/A3, plotter at ANSI D, and a photocopy generation, all inspected and signed off. The entire dash-and-weight argument is predicated on it (AC-058/D13) |
| **Legend verification** | `T0.01` under protanopia and deuteranopia simulation, and on a real greyscale laser, with all ten named cable types identifiable (AC-054) |

### 11.3 Build order

The interesting risk is all in §7, so front-load it. Spikes (§11.1) → `geometry`/`style`/`path`/`text`/`canvas`/`ops` + `PdfDiagramCanvas` + a hardcoded 20-op scene → `FlutterDiagramCanvas` + the parity test → furniture → the headless build test → scene builder → schedule pagination → elevation builder → `idformat` → the domain partition → isolate, progress, cancel → dialog and preview → CSV and labels → SVG.

**If the parity test does not pass, stop.** Every hour spent on layout before screen/print parity is established is an hour that may need redoing. Milestone exit for the full sheet set (canon §9.7, M6): all four starter projects export a complete set, the legend has passed CVD and greyscale verification, and the print matrix has been physically inspected, at which point brief requirement 7 is met and, with it, all seven.

---

## See also

[Overview](00-overview.md) · [Domain](01-domain.md) · [Data model](02-data-model.md) · [Architecture](03-architecture.md) · [Rack editor](04-rack-editor.md) · [Schematic editor](05-schematic-editor.md) · [Device builder](06-device-builder.md) · [Structure device](07-structure-device.md) · [Roadmap](09-roadmap.md) · [Decisions](10-decisions.md) · [Testing and quality](11-testing-and-quality.md) · [Seed devices](catalog/seed-devices.md)
