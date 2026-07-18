# Roadmap

This document is the binding answer to "what ships when". It reproduces the scope ruling of canon §7 (what is in v1, v1.1, v1.2, v2, and what is ruled out permanently) and the milestone plan of canon §9 (M0–M9, each with a goal, a work checklist, a binary exit criterion, a size, and its risks), adds the dependency graph between milestones, a risk register, and the walking-skeleton argument for build order. It states a cost — 41–69 weeks of implementation, 12–18 months to a shipped v1 — because per AC-017 a detailed design set with no cost attached reliably stalls at 40%, and a *wrong* cost stalls it at 40% while also destroying trust in the plan. Nothing here may be re-litigated without an amendment to [Decisions](10-decisions.md).

---

## 1. The v1 line

> **v1 is a single-window Windows desktop application in which a professional integrator builds one or more racks from a seeded catalog of generic archetypes, wires them on a schematic canvas with drag-to-connect, watches a cable schedule fill in live in a second tab, and exports a PDF sheet set containing front and rear elevations, a signal-flow diagram, a pull sheet, a termination schedule, an equipment list, a legend, and an exceptions page — with a device builder for the long tail, a Structure device for the wiring entering the rack, and twenty-two validation rules that never block a deliverable.**

If a feature is not required by that sentence, it is not in v1 (canon §7.1).

### 1.1 The four filters that produced the split

Applied in order; a feature must pass all four to be in v1.

| # | Filter | Effect |
|---|---|---|
| 1 | **Requirement filter** | Does one of the seven brief requirements fail without it? If yes it is in v1 regardless of cost. This is why the schematic canvas survives (RJ-001, RJ-002), the device builder survives, the Structure device survives, and the PDF must carry both diagram and schedule. |
| 2 | **G5 — cheap now, ruinous later** | Does omitting it cost a format migration, a command-stack rewrite, or a reconstruct-and-confirm pass over user data? If yes the **model** ships in v1 even when the **UI** does not. This produces the "model ships, gesture defers" pattern that appears eleven times below. |
| 3 | **G1 — does it serve the schedule?** | Does it make the schedule more correct, or get the user to the schedule faster? Features failing this and passing nothing else are cut. |
| 4 | **G4 — honesty** | Does it fabricate a number or give a heuristic authority it has not earned? If yes it is cut or demoted regardless of cost. The failure mode is not a missing feature; it is a user who stops trusting every number in the product. |

Two things this ruling deliberately does **not** do. It does not adopt `critique-feasibility.md #5`'s cut table (RJ-008) or `critique-ux-simplicity.md`'s "what v1 actually is" (RJ-001 through RJ-007): both cut things the brief fixed, so their diagnosis is accepted in full and their remedies overshoot. And it does not treat "cut" as "deleted" — every item below has a named home, because "later" is where scope goes to rot.

---

## 2. The scope ruling

### 2.1 v1 — in scope

Grouped by subsystem; the **Why** column names the governing ruling. See [Data model](02-data-model.md) and [Architecture](03-architecture.md) for the referenced entities.

**Core, format, infrastructure — all of it, no exceptions.**

| Item | Why |
|---|---|
| `Len` = int64 nanometres, `Mass` = int64 micrograms, `Permille`, one `UnitFormatter`; `Money` deleted | CR-001, CR-003, AC-001 |
| `Pt{int gx, int gy}` in 2.5 mm grid units, no sub-grid | CR-004 |
| 1 diagram unit = 1 PDF point at the canvas boundary, `double`, converted in exactly one function | CR-007 |
| UUIDv7 identity, tombstones, `EntityMeta`, flat maps, `FracIndex` ordering everywhere including `.rmdev` | CR-027, CR-095, G5 |
| `revision` (dirty-tracking, non-monotonic) **and** `sequence` (monotonic sync cursor) as two counters | CR-094, AC-004 |
| Plain pretty JSON `.rackmate`, single file, `schemaVersion`, hand-written codecs, migration chain + golden corpus | Confirmed decision 3 |
| Unconnected ports **not materialised** as entities; key-join from the template snapshot | AC-006 — this is what makes the file-size budget real rather than 3–6× wrong |
| `Command` / `Transaction` / `UndoStack` / `DocumentController` as the single mutation gate | AC-014. The most expensive retrofit in the project |
| Epoch counters; three-tier derived pipeline; `lodLevel` in every scene-builder signature and cache key | AC-016 (#13) |
| `DiagramCanvas` display-list IR, `TextMetrics`, explicit `TextAnchor`, both backends, baseline-y parity test | CR-087, AC-007 |
| `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` built first; nothing branches on `PointerDeviceKind` | AC-016 (#23) |
| Atomic save, autosave, crash recovery, close interception, recents | Architecture §7 |
| i18n plumbing with one locale; import hardening (JSON depth/size limits on every import path) | AC-058 (D12, D8) |

**The rack** — racks 1–60 RU with per-rack `ruNumbering` and `mirrorRearElevation` (CR-038, CR-026, CR-035); 1-based bottom-origin `ruIndex` (CR-025); the sealed `Placement` union (rail, shelf, zero-U, off-rack, staged) with `chassisRotation`, `locked` and lateral twelfths (CR-031, CR-030, AC-023); front/rear elevation editing with quick-add by typing, drop caret and marquee; the Staging Bin (CR-032); shelves as auto-packing containers (CR-029, AC-043); 0U occupants from the inspector (AC-044); Compact Down/Up with preview-then-accept (AC-045); depth occupancy as an interval per (RU, face) (AC-022); the always-visible chip strip of RU, weight, VA, outlets with everything else in a collapsed advisory panel (AC-039).

**Wiring** — `Link` → `Service` → `Conductor` plus stored `Net` (CR-008, CR-010, CR-011); the word `Connection` banned from code, format and prose (CR-008); the `Endpoint` sealed union with `PortEndpoint` / `PlaceEndpoint` / `OpenEndpoint` and `LifecycleStatus.designIntent` (AC-018 — the most consequential single finding in the four critiques); `Link.class` auto-classification (AC-026); three length fields (AC-024); `Pathway` as first-class (CR-016, AC-027); `InlineAdapter` (CR-015); Sugiyama phases 0–4 with interval-graph channel routing, phase 5 at paint time (CR-013); no route geometry persisted (CR-012); drag-to-connect with magnetic snap, chain-draw, multi-draw and one `Tidy sheet` (RJ-001); **one** schematic sheet with the `Sheet` entity present in the format (CR-073, AC-037); the schedule as the **second tab**, live from an empty project (CR-105, AC-035); hue = domain, dash + weight + tag = type (AC-054).

**Structure and the field** — `Outlet` as the creation atom (CR-016); `StructureDrop` deleted, a home run is a `Link` with `structureOrigin` (AC-019, CR-107); dual labels, both always printing on every cable (CR-044, AC-025, AC-047); the Structure editor opening in **table mode** with the matrix as a tab (AC-048); outlet templates with TIA-570-D presets (CR-108); the project-level Locations panel (CR-047, CR-112); multiple Structure instances (CR-113); CSV import with synonym mapping (RJ-004); 18 field-device templates (AC-031).

**Device builder and catalog** — three required fields, then ports, then done (AC-049, CR-114); the port grid in full — fill-down, TSV paste, multi-row edit, archetype generators, the pattern DSL (the grid was never the barrier); banks vs `PortSetDef` (CR-055); `PortDef.key` + `renamedFrom` as the migration join (CR-051); the three doors (CR-054); typed overrides (CR-053, AC-012); copy-on-place with a passive stale-template badge (AC-041); `contentHash` as a warning, never a load failure (AC-042); single `.rmdev` export/import; full catalog at **full fidelity with cited provenance** (RJ-007, AC-052); the connector footprint table complete for every shipped connector with a CI assertion (AC-050).

**Validation** — rules as **Dart functions** in a registry (CR-024, AC-011); **22 rules** listed once in `docs/rules.md` (AC-040); `error | warning | advisory | off` with `RuleOverride` (CR-018, CR-019); one dismissal mechanism, `AckedFinding`, and **errors are acknowledgeable** (CR-019, RJ-006); only `TOP-001..005` and placement coherence are model-illegal (CR-017); nothing blocks export (CR-022); the DRC fixture corpus (AC-051).

**Export** — `T0.01` legend, `T0.02` exceptions and acknowledgements, front elevation, rear elevation, one schematic sheet, Pull Sheet, Termination Schedule, `T6.30` Equipment List and Materials (CR-022, AC-025, AC-055); footage rollup by media with waste factor (AC-024); **no pricing** (AC-055); `sheetNumbering` defaulting to `simple` (CR-066); dry-run sheet count with a 40-sheet warning and 2000 hard cap (AC-050); the print test matrix on real hardware (AC-058 D13); deuteranopia/protanopia simulation plus a real greyscale laser print as named acceptance criteria (AC-054). Detail in [PDF export](08-pdf-export.md).

**Platform and quality** — mobile/tablet **read-only** on exactly three surfaces, with the app saying so rather than shipping a squeezed editor (AC-056); the outline tree; a fully specified keyboard path to create a connection, WCAG AA, NVDA/VoiceOver matrix (AC-058 D11); ~40 keybindings from one `Intent` registry with the 16 collisions fixed (CR-101, AC-046); the in-app glossary and one error-message catalogue (AC-058 D1); eight empty states and the full file-layer error surface (D3, D4); progress and cancel on every operation over ~500 ms (D14); four starter projects doing triple duty as goldens, perf fixtures and screenshot source (AC-052); Windows code signing started **two milestones early** (AC-058 D10).

### 2.2 v1.1 — the fast follow

Membership criterion is **additive**: no format migration, no command-stack change, no re-derivation of user data. Not effort.

| Item | Deferred by | What it costs to wait |
|---|---|---|
| 0U gutter **interactions** — 16 px gutters, rotated bars, drag-into-gutter, resize handles, the `G` toggle, channel-overlap warnings | AC-044 | Inspector-only editing of a real occupant; not lossy |
| Free lateral positioning on shelves, `Alt`-drag, third focus level, per-host overhang warnings | AC-043 | Auto-pack covers the common case |
| Free lateral dragging of half-rack devices | CR-030 | The dropdown covers all three real positions |
| Hand-authoring an arbitrary conductor map | AC-053 | `atomicConnect` covers component video, stereo pairs, 16/4 |
| The Rear Panel view as a printable sheet | CR-071 | The termination schedule carries the same information as a table |
| `Trace` through pass-throughs, and the search DSL | AC-040 | Both are navigation, not correctness |
| Manual reroute stored as `routeConstraintsBySheet` — ordered grid points, never a polyline | CR-012 | The router is deterministic; the itch is aesthetic |
| Registry editor beyond media types and connector aliases | AC-050 | The two extensibility paths users actually hit already ship |

### 2.3 v1.2 — the second release

Each needs a format addition, a fixture corpus, or evidence from real projects. All are pre-committed in the sense that the model already accommodates them (G5); none is promised on a date.

| Item | Gate |
|---|---|
| **Multi-sheet**, partitioned **by domain only** — which by construction has zero cross-sheet connections, so off-sheet connectors, zone grids and cross-reference resolution are never built | CR-073, AC-037; ships when real projects show which partition users want |
| The remaining ~40 DRC rules — `BUS-*`, `ELE-004/005/008`, length, impedance, DMX universes, DALI counts, Cresnet voltage drop, RF cascade, satellite DC-pass, fibre polarity | AC-040, AC-051. **Each ships only with its fixture pair.** That is the whole gate |
| The template **Update Manager** — opt-in migration, safe/additive/breaking grouping, per-cable `[Remap]` / `[Keep as orphan]` | AC-041. `[Del]` never ships (CR-052) |
| Auto-arrange with trade heuristics; fill gaps with blanks/vents gated on `Rack.formFactor` | AC-045, AC-034 (m20) |
| Buses as graphical grouping with 45° entries | RJ-001 |
| Sub-grid annotation nudging as `int sx, sy` in eighths of a gu, if ever needed | CR-004 |
| Bays — `Bay{id, name, order, rackIds}`, a pure addition | CR-033 |
| Full commercial grounding and bonding detail sheet | AC-034 (m21), RJ-010 |

### 2.4 v2 — the next product decision, not the next release

Each changes what the product *is* and should be decided with evidence from v1 users.

| Item | Note |
|---|---|
| `SignalRoute` — Dante flows, AVoIP streams, matrix crosspoints, eARC, VLAN/multicast/latency | CR-008, AC-036. Returns **with** a Dante view or not at all; a third entity layer with no editor is dead weight |
| **Layers** — Existing / Phase 1 / Phase 2 / Future / Demo | CR-064, AC-038. Real for commercial retrofit, absent from the residential first job; `DeviceStatus` covers 80% for one field |
| Cloud sync and multi-user | The model is already cloud-ready; nothing more is spent until someone asks |
| Mobile **editing** | v1 is read-only by confirmed decision; the intent layer keeps the door open |
| A read-only **web** viewer | AC-016 (#22). Distribution story, not a feature — one `kIsWeb` guard already exists |
| Unit splitting (`MTX1:A/:B/:C`) | CR-070. Only if multi-sheet lands and users demonstrably need it |
| A priced BOM with suppliers and purchase orders | AC-055. An adjacent product, not a missing feature |
| Real-SKU catalog | A legal and maintenance question before it is a product one |

### 2.5 Not doing — rulings, not omissions

| Item | Ruling |
|---|---|
| **A rule-authoring UI and the JSON predicate AST** | The claim that users can author rules is withdrawn from all documents. ~20 of 70 rules are inexpressible in a boolean predicate tree, so the AST buys a second rule system, a second debugger and a second test suite for rules nobody can write without a UI that was never designed. CR-024, AC-011 |
| **A full registry authoring UI** | RJ-012. A general registry editor is a database admin tool wearing a product's clothes |
| **Multi-document tabs** | RJ-013. One window, one document; open two windows if you want two |
| **Tagged / accessible PDF (PDF/UA)** | RJ-015. The accessibility budget buys the outline tree, the keyboard connection path and the NVDA matrix instead |
| **An in-app update mechanism in v1** | RJ-014. Signed installer plus a version-check ping; auto-update is a security surface before there are users |
| **Device images** | AC-057. Resolves the container question, removes the image-decode import surface, removes ~1 MB per template |
| **`.rmlib` packs, signatures, `provenance`/`derivedFrom` chains** | AC-042. `contentHash` survives; the cryptographic apparatus does not |
| **Cable dressing, floor plans, 3D, thermal simulation** | Out of the brief |
| **`blockExportOnErrors`** | CR-022. Not deferred — deleted. No setting, no equivalent, no exceptions |
| **`Money`, `cost`, `supplier`, `purchaseOrder`** | AC-055 |
| **Silent estimated values** | G4, AC-039. A standing prohibition, not a scope item: unknown is null, null renders `—`, every rollup reports its unknown count |

### 2.6 The nine cuts that account for most of the saving

Ranked by engineering weeks removed, using `critique-feasibility.md`'s own sizing.

| # | Cut | To | Weeks saved |
|---|---|---|---|
| 1 | Multi-sheet, off-sheet connectors, zone grids, cross-refs, min-cut, unit splitting | v1.2 / v2 | 4–6 |
| 2 | ~40 of the 62 DRC rules | v1.2 | 3–4 |
| 3 | Template Update Manager, semver classifier, diff view, merge resolution | v1.2 | 2–3 |
| 4 | Preview-diff auto-layout with variant cycling, four tidy scopes, auto-arrange heuristics | v1.2 | 2–3 |
| 5 | `SignalRoute` and layers | v2 | 2 |
| 6 | 0U interactions, shelf free-positioning, half-rack drag, manual conductor authoring | v1.1 | 1.5–2 |
| 7 | The rules-as-data interpreter | Not doing | 1.5–2 |
| 8 | `.rmlib`, signatures, device images, priced BOM | Not doing / v2 | 1.5 |
| 9 | Buses, `Trace`, search DSL, rear-panel print sheet | v1.1 / v1.2 | 1.5 |

Roughly **20–26 weeks removed** from a 62–83 week bottom-up estimate, before counting the reduction inside the schematic milestone from RJ-001's accepted half.

---

## 3. The walking skeleton — what to build first, and why

The build order is not "easiest first" and it is not "most visible first". It front-loads the four things that are cheap to get right now and ruinous to retrofit, and it makes each of them prove itself against a running program before anything sits on top of it. Three sequencing rules survive verbatim from `design-architecture.md §13`:

1. **The viewport comes first**, because everything sits on it and it is cheapest to iterate on when nothing else exists.
2. **The command stack comes before the feature surface grows.** Retrofitting a mutation gate across forty entity types and six editors is the single most expensive rewrite available in this project.
3. **The display-list IR comes before the PDF backend**, which makes the PDF backend nearly free. Screen/print parity is tractable only in that order; the reverse order means every layout hour may need redoing.

The skeleton — the thinnest end-to-end path that touches every hard subsystem — is therefore:

```text
 units + Len/Mass/Pt        →  the 1/32-in and 45U tests must pass EXACTLY
        │                       (if they don't, nothing above is trustworthy)
        ▼
 entities + JSON codecs     →  write(read(bytes)) == bytes on 3 fixtures
        │                       (byte round-trip, not semantic — AC-016 #24)
        ▼
 Command/Transaction/Undo   →  apply;revert leaves the JSON byte-identical
        │                       on 1,000 generated command sequences
        ▼
 ViewportController         →  pan/zoom/grid with nothing drawn on it yet
        │
        ▼
 DiagramCanvas IR + both    →  baseline-y parity within 0.5% on a
 backends + parity test        kerning-heavy string.  ►► IF PARITY FAILS, STOP. ◄◄
        │
        ▼
 one rack, one device,      →  the first PDF that a tape measure can check
 one PDF sheet
```

Everything after that point is feature surface on a proven spine. Everything before it is a bet that, if lost, is lost cheaply. The rejected alternative — build the rack editor first because it is the demo — loses because it puts three of the four hard bets behind six weeks of UI that would then be rewritten. The parity test is a genuine stop-the-line gate, not a checkbox: `design-pdf-export.md` is right that every hour spent on layout before parity holds is an hour that may need redoing.

Two further sequencing constraints are binding, from AC-059:

- **M0 is not compressible into M1.** Six decisions — the unit base (CR-001), the wiring entity model (CR-008), the validation philosophy (CR-017), the template join key (CR-051), the package layout (CR-083), the text-metric source of truth (CR-081) — each cost a rewrite of everything downstream if guessed wrong.
- **The rules-as-code decision (CR-024) must be settled before the wiring milestone**, not during it. It justifies several registry decisions, and deciding it late means either building an interpreter nobody needs or refactoring a shipped file format. It is settled in the canon, which is why M2 can start on schedule.

---

## 4. Milestone plan

**How to read it.** `S` ≈ 2–3 weeks, `M` ≈ 4–7 weeks, `L` ≈ 8–12 weeks, for one experienced engineer, implementation only — excluding design iteration, the bug tail, and anything in the open questions that changes an answer. **Exit criteria are binary and demonstrable**; "works well" is not an exit criterion, and each one below can be checked by running something. **Every milestone ends green**: CI passes, goldens pass, the app opens the four starter projects. A milestone that ends with a known-broken build has not ended.

### M0 — Foundations · S

**Goal.** The pure-Dart core and the repo it lives in. No UI beyond a window that opens.

- [ ] Monorepo with four packages (CR-083) plus the mechanical dependency-rule enforcement test
- [ ] `rackmate_core/units/` — `Len`, `Mass`, `Permille`, `Pt`, `Box`, `UnitFormatter`, `kBtuPerWattHour`
- [ ] The full entity set as immutable Dart with `@internal` setters (AC-013)
- [ ] Hand-written JSON codecs both ways, `schemaVersion`, migration harness, tombstones, `EntityMeta`, `FracIndex`, `revision`/`sequence`
- [ ] `Command` / `Transaction` / `UndoStack` / `DocumentController`; epoch counters
- [ ] The `idformat` grammar, registry and parser (CR-045)
- [ ] CI: analyze, test, goldens, format, the no-Flutter-import test, the epoch-mask coverage test

**Exit criterion.** `dart test` green in `rackmate_core` with: the 1/32-inch clearance test and the 45U-accumulation test passing exactly (CR-001); `write(read(bytes)) == bytes` on three fixtures (CR-117, AC-016 #24); the command round-trip property test (`apply; revert` leaves the JSON byte-identical, including `templates.keys` — AC-015) passing on 1,000 generated command sequences; the epoch-mask coverage test passing for every command type; one v0→v1 migration fixture in the golden corpus. `rackmate_core` has zero Flutter imports, enforced by a test that fails the build.

**Risks.** Byte round-trip is much harder than semantic round-trip — it constrains key ordering of nested `unknown` maps, timestamp precision and integer formatting. Budget for that, or the plain-JSON git-diffability justification is not actually being tested.

### M1 — The elevation release · L

**Goal.** The smallest genuinely useful release — **and it ships to real users.**

- [ ] `ViewportController` with wheel/trackpad/pan/zoom and the grid painter, built first
- [ ] `CanvasIntent` on top of it, with no `PointerDeviceKind` branching anywhere above (AC-016 #23)
- [ ] Hybrid `RenderRackCanvas`, device widgets, RU snapping, front/rear elevations with per-rack mirroring
- [ ] Quick-add by typing with the drop caret; the Staging Bin; shelves with auto-pack; 0U occupants from the inspector
- [ ] Compact Up/Down with preview-then-accept, and the shrink-rack dialog; locks
- [ ] The full seeded catalog including the 18 field devices, with `sources.md` provenance and the connector-footprint CI assertion — see [Seed devices](catalog/seed-devices.md)
- [ ] Copy-on-place with `DeviceOverrides`; the chip strip (RU, weight, VA, outlets) with unknown counts
- [ ] `DiagramCanvas` + `SceneBuilder` + both backends + the baseline-y parity test
- [ ] Minimal PDF exporter: front elevation, rear elevation, `T6.30`, title block, revision block
- [ ] Atomic save, autosave, recovery, recents, close interception; the outline tree; four starter projects

**Exit criterion.** A user opens the app, creates a 42U rack, populates it with 20 devices in under four minutes **using only the keyboard**, and exports a three-sheet PDF whose elevations are dimensionally correct against a physical tape measure at true scale and whose equipment list matches the rack contents exactly. The baseline-y parity test passes within 0.5% on a kerning-heavy string. Undo restores every operation in that sequence.

**Why it is useful standalone.** Integrators produce rack elevations today in Visio, in Excel with merged cells, in D-Tools if they have paid for it, and in PowerPoint if they have not. An RU-accurate, dimensioned, printable front-and-rear elevation with an equipment list is a **billable client deliverable in its own right** — it goes into proposals, to the GC for closet sizing and power requests, to the millworker for the credenza cut-out, and it is what gets marked up in the field. Roughly half the observed use of a rack tool never touches wiring at all. M1 satisfies brief requirements 1 and 2 completely, and it puts the two most retrofit-expensive subsystems into production against real files before a single wire exists — which is why it is `L` and not `M`.

**What M1 deliberately lacks.** No wiring, no schedule, no schematic, no Structure, no device builder, no DRC. The app says so: an empty Schedule tab that explains it is coming is a lie, so the tab does not exist yet.

**Risks.** Scope creep from [Rack editor](04-rack-editor.md) — the elevation spec is the densest interaction document in the set and its v1.1 items (0U gestures, shelf free-positioning) are seductive. The catalog provenance gate (AC-052) is the other risk: uncited safety-adjacent fields do not ship, so template authoring is slower than the "2 weeks" line item suggests.

### M2 — Wiring and the live schedule · L

**Goal.** Requirements 3, 4 and 5. The schedule becomes a thing the user watches fill up rather than discovers at export.

- [ ] `Link` / `Service` / `Conductor` / `Net` with the `Endpoint` sealed union and `Link.class` auto-classification
- [ ] The schematic canvas: symbols with banks, vector-pin collapse, Sugiyama phases 0–4, interval-graph channel routing, full deterministic recompute, phase 5 at paint time
- [ ] Drag-to-connect with magnetic type-weighted snap, chain-draw, multi-draw, pinning on manual move, one `Tidy sheet`
- [ ] Domain filter bar, auto net-label degradation, `Alt`-hover focus
- [ ] Hue-by-domain plus dash/weight/tag by type, with the per-family colour override setting
- [ ] `atomicConnect` multi-conductor gesture
- [ ] **The schedule table as the second tab**, live from an empty project, with Pull Sheet and Termination Schedule as two views of one derivation
- [ ] Wiring signposted from the elevation (CR-105); the coach mark at the first rack→schematic switch (CR-104, AC-048)

**Exit criterion.** Starting from the M1 output, a user creates 60 connections without touching a menu; the schedule tab shows 60 correctly-sorted rows with both labels on both ends and conductor colours where they exist; the schematic re-lays-out deterministically (same input ⇒ byte-identical display list) and routes a 300-connection fixture within one frame at commit, with the crossing count X **measured and recorded rather than assumed** (AC-016 #20). The keyboard-only path to create a connection works end-to-end with screen-reader announcements.

**Risks.** The highest-risk milestone in the plan. The 8 ms commit budget is not achievable with the wire-layer rebuild included — re-baseline to ≤ 16 ms with ≤ 8 ms for non-paint terms, split L3a into per-domain sub-pictures, and move tag pills to their own picture. The text cache is sized from a wrong input: ~10,000 text runs against a 2,000-entry LRU thrashes, and a thrashing LRU is worse than none because eviction disposes a native `ui.Paragraph` in the paint path. Key on `(text, styleId, quantisedScale)` and measure. See [Schematic editor](05-schematic-editor.md).

### M3 — Structure and the field · M

**Goal.** Requirement 6, and the finding that a pull sheet must exist before the equipment list does.

- [ ] `Outlet`, `structureOrigin`, `PlaceEndpoint` and `OpenEndpoint` in the UI, `LifecycleStatus.designIntent`
- [ ] The Structure editor in table mode with the matrix as a tab; outlet templates and TIA-570-D presets
- [ ] The project-level Locations panel with the arbitrary-depth tree
- [ ] Dual-label generation for every cable; the three length fields, `Location.estimatedRunLengthFromRack`, the footage rollup with waste factor
- [ ] `Pathway` with `kind` and `containsLineVoltage`; CSV import with synonym mapping and the import-over-existing confirm; multiple Structure instances

**Exit criterion.** A 60-drop whole-house rough-in is entered in under fifteen minutes, produces 60 `Link`s each with one `fieldLabel` and one `rackLabel`, and exports a Pull Sheet sorted by room and pathway with per-room footage subtotals and initial boxes. **Fourteen of those drops have unbound far ends and every one of them still schedules, prints and carries a `W` number** (AC-018). Requirement 6 is met. See [Structure device](07-structure-device.md).

**Risks.** CSV synonym mapping is an infinite-tail feature; cap it at the shipped synonym table and let unmapped columns fall through to a manual assign step.

### M4 — The device builder · M

**Goal.** Requirement 2 in full — the long tail the catalog cannot cover.

- [ ] The three-required-field form, everything else optional with a visible `unknown` state
- [ ] The virtualised port grid: fill-down, TSV paste, multi-row edit, archetype generators, the pattern DSL with autocomplete and designed parse errors
- [ ] Banks and `PortSetDef`; the three doors (CR-054); typed `PortOverrides`
- [ ] `.rmdev` single-file export/import with `contentHash` as a warning-level check
- [ ] The stripped field-device form; the media-type editor and connector aliases; undo throughout the builder (CR-106)

**Exit criterion.** A 16×16 matrix template is authored from scratch **in under three minutes by a user who has seen the tool once**, and a template saved with exactly three fields plus ports places into a rack and appears correctly in the equipment list with `—` in every unknown column and an accurate unknown count in the rollup. See [Device builder](06-device-builder.md).

**Risks.** The pattern DSL is the scope hazard, not the grid. Ship the documented subset with designed parse errors and resist generalising it.

### M5 — Validation · M

**Goal.** 22 rules that are right, acknowledgeable, and incapable of holding a deliverable hostage.

- [ ] The rule registry as Dart functions; catalogue metadata as data; the compat matrix as a lookup table
- [ ] All 22 rules; findings, severities, `AckedFinding` at both scopes, project-wide mutes with reasons
- [ ] Spring-back with reason chips and remedy chips, each with `[ Connect anyway ]`; the `[Why?]` rationale viewer
- [ ] **The DRC fixture corpus**

**Exit criterion.** Every one of the 22 rules has a known-bad fixture producing exactly that finding and a known-good near-miss producing none — **no rule ships without its pair** (AC-051). A domain-expert review of the 22 rules and of the catalog data is signed off. No rule, at any severity, prevents a PDF from being written to disk.

**Risks.** The fixture-pair gate is what holds the catalogue at 22; the pressure to add "just one more obvious rule" without its pair is the mechanism by which this milestone becomes M. Enforce the gate in CI.

### M6 — The full sheet set · M

**Goal.** Requirement 7, and with it all seven brief requirements.

- [ ] `T0.01` legend printing one row per named cable type in colour and greyscale side by side
- [ ] `T0.02` exceptions and acknowledgements with every reason, author and date; the schematic sheet
- [ ] `T5.01` pinout detail auto-on for non-standard pinouts; sheet numbering `simple`/`ncs`
- [ ] Dry-run sheet count with the 40-sheet warning and 2000-sheet cap; export progress, cancel and preview; `kIsWeb` isolate guard
- [ ] The print test matrix on real hardware

**Exit criterion.** All four starter projects export a complete sheet set; the legend has been verified under deuteranopia and protanopia simulation and on a real greyscale laser print (AC-054); the ANSI B laser, ANSI D plotter and photocopy reproductions have all been **physically inspected and signed off** (AC-058 D13). Requirement 7 is met. **Windows OV/EV certificate procurement starts here**, two milestones before release.

**Risks.** Certificate procurement is a multi-week external dependency with identity-verification steps outside the team's control — starting it at M8 is how a finished product waits three weeks to ship.

### M7 — Platform and access · M

**Goal.** Honour confirmed decision 1 honestly, and make the app usable by someone who does not use a mouse.

- [ ] Mobile/tablet read-only on the three named surfaces, with an explicit statement for the two unavailable ones
- [ ] WCAG AA on the primary surfaces; raised filtered-wire alpha; non-colour encoding on rack device fills; the NVDA/VoiceOver matrix
- [ ] The ~40-binding arbitrated keymap generated from the `Intent` registry, plus the generated shortcut panel
- [ ] The in-app glossary; the error-message catalogue in one voice; the eight empty states; the full file-layer error surface
- [ ] Progress and cancel on every operation over 500 ms; localisation plumbing verified end to end with a pseudo-locale

**Exit criterion.** A reviewer opens a `.rackmate` file on a tablet and reads the elevation, the schedule and the PDF; the NVDA matrix passes on the elevation, the schedule and the connection-creation path; no keybinding is bound twice in the generated table; the pseudo-locale build shows no hard-coded English in the primary surfaces.

**Risks.** Accessibility work discovered this late tends to surface structural problems in the canvas surfaces. The outline tree shipping in M1 is the mitigation — it is the only honest accessibility story a canvas app has, and it exists from the first release.

### M8 — Release engineering · S

**Goal.** A thing a stranger can install.

- [ ] Signed Windows installer; vendored pdfium; symbol archival
- [ ] Crash reporting local-first, opt-in remote, with the redaction policy reconciled (CR-096)
- [ ] Licence model and EULA; `showLicensePage`; version-check ping
- [ ] Documented scale limits with the soft warning at 1.5× and the open-read-only gate at 3×

**Exit criterion.** A signed installer runs on a clean Windows 11 machine **with no SmartScreen warning**, the app cold-starts within budget, a deliberately induced crash produces a local report containing **no project content**, and the documented limits behave as documented.

**Risks.** SmartScreen reputation accrues over installs even with a valid OV certificate; an EV certificate avoids the ramp. This is a purchasing decision, made at M6.

### M9 — Beta hardening · M

**Goal.** Find out whether any of this was true.

- [ ] No new features
- [ ] Five real projects from three real integrators, run end to end
- [ ] The bug tail
- [ ] Performance measured against the recorded budgets rather than the assumed ones

**Exit criterion.** Three integrators have each produced a sheet set they were willing to send to a client or a job site, and none of the three needed to leave the app to fix something. **That is the only exit criterion that matters and it is deliberately a judgement, not a metric.**

**Risks.** Recruiting three real integrators willing to run a beta on live work is a lead-time problem, not an engineering one. Start the conversation at M6.

---

## 5. Milestone dependencies

Solid arrows are hard blocks — the downstream milestone cannot start without the named artifact. Dashed arrows are soft: the work is possible but wasteful out of order.

```text
                       ┌──────────────────────────────┐
                       │ M0  Foundations           S  │
                       │ units · entities · codecs    │
                       │ command stack · epochs       │
                       └──────────────┬───────────────┘
                                      │ mutation gate + format
                                      ▼
                       ┌──────────────────────────────┐
                       │ M1  Elevation release     L  │────────┐
                       │ viewport · CanvasIntent      │        │ DiagramCanvas IR
                       │ rack editor · catalog        │        │ + both backends
                       │ DiagramCanvas + parity test  │        │ (makes M6 cheap)
                       └───┬──────────────┬───────────┘        │
                           │ ports exist  │ devices exist      │
                           ▼              ▼                    │
        ┌──────────────────────────┐  ┌────────────────────┐   │
        │ M2  Wiring + schedule L  │  │ M4  Device builder │   │
        │ Link/Service/Conductor   │  │                 M  │   │
        │ schematic · live table   │  │ (independent of    │   │
        └───┬───────────────┬──────┘  │  M2 and M3)        │   │
            │ Link + Endpoint│         └─────────┬──────────┘  │
            ▼                │                   │             │
 ┌────────────────────────┐  │ findings need     │             │
 │ M3  Structure + field M│  │ a wired graph     │             │
 │ Outlet · home runs     │  ▼                   │             │
 │ dual labels · pathways │ ┌──────────────────┐ │             │
 └───────────┬────────────┘ │ M5  Validation M │ │             │
             │              │ 22 rules +       │ │             │
             │              │ fixture corpus   │ │             │
             │              └────────┬─────────┘ │             │
             │                       │           │             │
             └───────────┬───────────┴───────────┘             │
                         ▼                                     │
              ┌──────────────────────────┐                     │
              │ M6  Full sheet set    M  │◄────────────────────┘
              │ all 8 sheet types        │
              │ ⇒ all 7 requirements met │
              │ ⇒ START CERT PROCUREMENT │
              └──────────┬───────────────┘
                         │
                         ▼           ┌─────────────────────────┐
              ┌────────────────────┐ │ certificate arrives     │
              │ M7 Platform + a11y │ │ (external, ~2 milestone │
              │                 M  │ │  lead time)             │
              └──────────┬─────────┘ └────────────┬────────────┘
                         │                        │
                         └──────────┬─────────────┘
                                    ▼
                         ┌────────────────────┐
                         │ M8  Release eng. S │
                         └─────────┬──────────┘
                                   ▼
                         ┌────────────────────┐
                         │ M9  Beta hardening │
                         │                 M  │
                         └────────────────────┘

Hard blocks:  M0→M1 · M1→M2 · M1→M4 · M2→M3 · M2→M5 · M1→M6 · {M3,M5}→M6 · M8→M9
Soft:         M4 may float anywhere after M1 (see lever 2, §6)
              M7 may overlap M6 wherever surfaces are already frozen
```

The two structural facts in that graph: **M4 is not on the critical path** — it hangs off M1 and blocks only itself, which is what makes lever 2 below available. And **M6 is a join** — it requires the drawing (M2), the field data (M3) and the findings (M5) simultaneously, which makes it the milestone most exposed to slip anywhere upstream.

---

## 6. The honest total

| Milestone | Size | Cumulative weeks |
|---|---|---|
| M0 Foundations | S | 2–3 |
| M1 Elevation release | L | 10–15 |
| M2 Wiring and the live schedule | L | 18–27 |
| M3 Structure and the field | M | 22–34 |
| M4 Device builder | M | 27–41 |
| M5 Validation | M | 31–47 |
| M6 Full sheet set | M | 35–53 |
| M7 Platform and access | M | 39–59 |
| M8 Release engineering | S | 41–62 |
| M9 Beta hardening | M | 45–69 |

**41–69 weeks of implementation; 12–18 months to a shipped v1 with normal overhead.** Better than the 16–22 months `critique-feasibility.md` priced the unreduced design at, and not the 5–6 months its cut table promised — because that table cut a requirement (RJ-008).

**Three levers exist if that number is unacceptable.** Pull them explicitly rather than by drift.

| # | Lever | Effect | Cost |
|---|---|---|---|
| 1 | **Ship M1 as a public v0.9** | Converts 10–15 weeks of invisible work into user evidence that would resolve half the open questions | None. M1 is a real product (§4) |
| 2 | **Move M4 after M6** | Removes the device builder from the pre-requirement-complete path; the catalog plus `DeviceOverrides` covers the common case, and the builder is a completeness barrier rather than an adoption barrier | Defers a brief requirement, so it needs an explicit decision, not a slip |
| 3 | **Cut the catalog to 40 archetypes at full fidelity** rather than 80 | Removes catalog authoring weeks from M1 | None to quality — the provenance gate (AC-052) sets the count, and 40 sourced templates beat 80 guessed ones. Lower *fidelity* is not the lever (RJ-007) |

---

## 7. Risk register

Ordered by expected cost. "Early warning" is the observable that should trigger the mitigation before the risk lands.

| # | Risk | Likelihood | Impact | Mitigation | Early warning sign |
|---|---|---|---|---|---|
| R1 | **Screen/PDF text parity fails**, forcing a layout rewrite late | Medium | Severe — invalidates layout work across every sheet | Baseline-y parity test in M1 as a stop-the-line gate; `TextMetrics{width, height, ascent, descent}` never reduced to a width; both backends fed by `PdfFont.stringMetrics` (CR-087, AC-007) | The parity test is written but marked skip, or asserts on width only |
| R2 | **M2 commit budget missed** — the wire layer rebuild is 10–25 ms, not 4 | High | Major — the schematic feels laggy at exactly the density that matters | Re-baseline to ≤ 16 ms with ≤ 8 ms for non-paint terms; per-domain sub-pictures; tag pills in their own LOD-gated picture; measure **op count** per layer in CI, not wall time on a shared runner | Op count per commit rising above ~2,000 on the 300-connection fixture |
| R3 | **Scope drift back across the §2 line** — "just one more DRC rule", "just free-drag on shelves" | High | Major — this is the mechanism by which 69 weeks becomes 100 | Every deferred item has a named home and a ruling ID; PRs adding scope must cite an amendment; the fixture-pair gate (AC-051) blocks rules mechanically | A PR that adds a rule without a fixture pair, or an issue labelled `v1` with no ruling ID |
| R4 | **Catalog provenance stalls M1** — cited numbers are slower to produce than guessed ones | Medium | Moderate — M1 slips by weeks, not months | Lever 3: cut to 40 archetypes at full fidelity. Uncited safety-adjacent fields do not ship (AC-052), and that rule is not negotiable | `sources.md` lagging template count by more than ~10 entries |
| R5 | **The open fork (net labels vs every wire) is answered late**, after the schematic is built for one answer | Medium | Major — rework inside the most expensive milestone | Answer it before M2 starts; it is one of the three questions flagged as answer-first | M2 kickoff with the question still open |
| R6 | **Text cache thrash** — ~10,000 runs against a 2,000-entry LRU, with native `ui.Paragraph` disposal in the paint path | Medium | Moderate — GC pressure and native churn during pan | Key on `(text, styleId, quantisedScale)`, size from the real figure, enforce the LOD gate as a **test** rather than an intention | Cache hit rate below ~90% on the 300-connection fixture at fit-to-sheet zoom |
| R7 | **Code-signing certificate lead time** blocks a finished build | Medium | Moderate — weeks of a shippable product sitting still | Procurement starts at M6, two milestones early (AC-058 D10); prefer EV to avoid the SmartScreen reputation ramp | M7 underway with no certificate order placed |
| R8 | **Beta integrators cannot be recruited** in time for M9 | Medium | Moderate — the only exit criterion that matters becomes unverifiable | Start recruiting at M6; three integrators, five real projects; M1 shipped as v0.9 (lever 1) makes recruitment far easier | No named integrator by the end of M6 |
| R9 | **Byte round-trip proves harder than budgeted** in M0 — nested `unknown` key ordering, timestamp precision, integer formatting | Medium | Moderate — M0 is `S` and can absorb it, but only once | Write the test first; treat `unknown` map ordering as part of the codec contract, not an accident of `Map` iteration | Semantic round-trip passing while the byte test is deferred "for now" |
| R10 | **Solo-engineer bus factor** across a 12–18 month plan | Low | Severe | Everything load-bearing is a test, not a memory: the golden corpus, the DRC fixture pairs, the round-trip properties, the four starter projects. The canon plus this doc set is the handover artifact | Undocumented decisions accumulating in commit messages rather than in [Decisions](10-decisions.md) |
| R11 | **File-size budget breached** at real project scale, invalidating plain JSON | Low | Major — a format change after users have files | Ports are not materialised unless they carry state (AC-006); the four starter projects act as size fixtures with an asserted ceiling | A starter project crossing its asserted byte budget |

---

## 8. How progress is tracked in this repo

1. **The milestone is the unit of planning; the exit criterion is the unit of truth.** A milestone is not "done" when the checklist is ticked — it is done when its exit criterion has been demonstrated by running something, and the demonstration is recorded in the milestone's closing commit message.
2. **Every issue and every PR cites a ruling ID.** `CR-nnn`, `AC-nnn` or `RJ-nnn`. A change with no citation is either implementing an unadjudicated decision — in which case it needs one — or re-litigating a settled one, in which case it needs an amendment to [Decisions](10-decisions.md). This is the mechanism that makes R3 detectable rather than merely regrettable.
3. **Scope changes are amendments, not conversations.** Moving an item between v1, v1.1, v1.2, v2 and not-doing is an edit to §2 of this file with a new ruling ID, in its own commit. The tables above are the only scope list; there is no second one in an issue tracker.
4. **Green means green.** CI runs analyze, test, goldens, format, the no-Flutter-import test, the epoch-mask coverage test and the connector-footprint assertion. The perf job is warn-only for the first three months and measures op count per layer. A milestone that ends red has not ended.
5. **The four starter projects are the regression net.** They are goldens, perf fixtures and screenshot source at once, and every milestone must open all four. When a milestone adds a subsystem, the starter projects grow to exercise it — at minimum one exercises Structure and one exports a full sheet set (AC-052).
6. **Fixture gates are enforced by CI, not by review.** No DRC rule merges without a known-bad and a known-good near-miss (AC-051); no catalog template merges with an uncited safety-adjacent field (AC-052); no connector merges without a footprint entry (AC-050).
7. **Open questions are tracked separately from scope.** They are decisions awaiting human judgement, not work items; three of them should be answered before M2, and R5 exists because answering them late is the expensive failure.

See also: [Overview](00-overview.md) · [Domain](01-domain.md) · [Data model](02-data-model.md) · [Architecture](03-architecture.md) · [Testing and quality](11-testing-and-quality.md).
