# RackMate: Canonical Decision Record, Part 1

**Status:** NORMATIVE. Supersedes all six `design-*.md` documents wherever they disagree with it.
**Scope of Part 1:** resolved contradictions, accepted critiques, rejected critiques.

---

## 0. How to read this document

The six design documents were written in parallel against a shared brief and never reconciled.
They are individually strong and collectively not one specification. From this point:

- **This record is normative.** The six `design-*.md` files are demoted to **non-normative
  rationale**: they remain the best available explanation of *why* a decision was taken, and
  they are wrong wherever this record contradicts them. Every design doc gets a banner to that
  effect.
- **Every ruling below is binding and is not to be re-litigated** without a written amendment
  to this record.
- Rulings are numbered `CR-nnn` (contradiction resolved), `AC-nnn` (accepted critique),
  `RJ-nnn` (rejected critique). Downstream documents and commit messages cite these IDs.

### 0.1 The governing frame

Five principles decide most of the close calls below. Where a ruling looks arbitrary, it is
almost always one of these applied mechanically.

| # | Principle | Consequence |
|---|---|---|
| **G1** | **The schedule is the deliverable; the drawing is the receipt.** | Effort and risk budget follow the schedule. Anything that delays or degrades the schedule loses. |
| **G2** | **The document must be able to represent a wrong, incomplete, or found-in-the-field world.** | `design-data-model.md §3.5` is correct: a model that cannot draw a mistake cannot document reality. Only model-incoherence is illegal. |
| **G3** | **A heuristic may never hold a user's deliverable hostage.** | No computed number, no trade opinion, and no drafting convention blocks an export. |
| **G4** | **Never fabricate data. Show `unknown`.** | A missing weight contributes nothing to a rollup and the rollup says so. Silent 50%-of-nameplate estimates are prohibited. |
| **G5** | **Cut features, never foundations.** | Units, IDs, tombstones, per-entity metadata, fractional indices, the command stack, and the drawing IR ship in v1 even when their UI does not. Everything expensive to retrofit is done now. |

### 0.2 The four confirmed product decisions are constraints, not inputs

The brief fixed these and they are not open. Several critique recommendations violate them and
are rejected in §3 on that ground alone:

1. Desktop-first; **mobile read-only in v1**; architecture must not preclude touch.
2. **A device builder *plus* a seeded catalog of ~40–55 generic archetypes.**
3. Local **single-file `.rackmate` projects (JSON)**; cloud-ready model, stable UUIDs,
   `schemaVersion`, no positional identity.
4. Seven core requirements, all represented in v1: RU height, device builder with I/O,
   physical connections, colour-coding by cable type, schematic idiom, Structure device,
   PDF containing **both** diagram and schedule.

---

# 1. Resolved contradictions

120 rulings. Each names the conflict, quotes both sides with their source file, and states the
single binding decision.

---

## 1.1 Units, precision, and coordinate spaces

### CR-001 · The base length unit: four incompatible answers

- **design-data-model.md §3.7:** "`Len` = **int64 nanometres.** … Why nanometres specifically:
  1 in = 25 400 000 nm exactly."
- **design-architecture.md D3:** "**Geometry stored as `int` in hundredths of a millimetre
  (10 µm).** … *tenths-of-mm, a plausible first choice, is **not** exact: 44.45 mm = 444.5
  tenths. Use hundredths.*"
- **design-ux-rack.md (design constants):** "Logical geometry is stored as integers (`int` U
  counts, `int` tenths-of-mm)."
- **design-ux-schematic.md §1.1:** "Everything is stored as `int` tenths-of-a-millimetre. No
  doubles in the model, ever."
- **design-ux-device-builder.md §3.2:** `"depthMm": 330`, `"weightKg": 7.3`, `"xMm": 24.0`, 
  floating-point millimetres.

**Ruling: `Len` is `int64` nanometres.** `design-architecture.md` D3 is right that tenths is
inexact and wrong that hundredths is exact: the EIA 1/32-in inter-panel clearance that
`design-data-model.md` itself renders (`44.45n − 0.79 mm`) is 79.375 hundredths-mm, not an
integer. Only nanometres make every imperial fraction to 1/1000 in exact (1/32 in = 793 750 nm;
1U = 44 450 000 nm). Readability of a number no human reads is not a consideration.
`Len`, and the extension types `Mass`, `Money`, `Permille`, are defined **once** in
`rackmate_core/units/` and every other document references that definition rather than
restating it. Two unit tests are written before any other code: exact 1/32-in clearance, and
zero accumulated error across a 45U stack.

### CR-002 · The 1U-in-tenths arithmetic error

- **design-ux-schematic.md §5.4:** "`heightU × 444` tenths-mm tall (EIA-310 1U = 44.45 mm =
  444 tenths, **exact: no rounding anywhere in the vertical axis**)."

**Ruling: the statement is false and is deleted.** 44.45 mm is 444.5 tenths; the stated
constant loses 0.05 mm per U and 2.25 mm across a 45U rack, which is visible on a dimensioned
print. Superseded by CR-001. `k1RackUnit = Len(44_450_000)`.

### CR-003 · Mass unit

- **design-data-model.md §2.0:** "`Mass(int ug)` … micrograms → grams exact, lb exact."
- **design-ux-rack.md §6:** `weightCapacityGrams`, `weightGrams`.
- **design-ux-device-builder.md §1.3/§3.2:** `weightKg` / `weightLb`, `"weightKg": 7.3`.

**Ruling: `Mass` is `int64` micrograms** (1 lb = 453 592 370 µg exactly). Kilograms and
pounds are display formats produced by `UnitFormatter`; neither is stored. `.rmdev` writes
`weightUg`.

### CR-004 · Schematic grid pitch and sub-grid precision

- **design-data-model.md §2.0/§3.7:** "`Pt` … **INTEGER grid units. 1 gu ≡ 2.54 mm** nominal
  pitch" with "1/64-gu sub-offsets for annotation nudging only."
- **design-ux-schematic.md §1.1:** "Base grid unit `U` | **25 tenths-mm (2.5 mm)** … Snap grid
  (default) 1U; `Alt` = free (0.1 mm), `Shift` = 4U coarse."

**Ruling: pitch from `design-ux-schematic.md`, storage from `design-data-model.md`, free
positioning deleted.** One schematic grid unit `gu` = `Len(2_500_000)` (2.5 mm); pin pitch
2 gu; the argument that AV port labels need more room than KiCad's 100 mil is correct.
Positions are `Pt{int gx, int gy}` in gu, no sub-grid, no `sx`/`sy`, no `Alt`-free nudge.
Free 0.1 mm positioning defeats the exact-integer routing that the whole layout pipeline is
built on and gives the user a way to author an unroutable drawing. Snap: 1 gu default, 4 gu
with `Shift`. If sub-grid annotation nudging is ever needed it is added as `int sx, sy` in
eighths of a gu, additive, no migration.

### CR-005 · BTU conversion constant

- **design-data-model.md §2.5:** "`typicalWatts × 3.41214`."
- **design-ux-rack.md §5.1** and **design-ux-device-builder.md §1.4:** "`watts × 3.412`."

**Ruling: one constant, `kBtuPerWattHour = 3.412142`, in `rackmate_core/units/thermal.dart`.**
Heat is **derived, never stored**; `TemplateBody.btuPerHourOverride` is retained for the rare
manufacturer figure that disagrees with the arithmetic.

### CR-006 · Rack-elevation coordinates: stored or derived

- **design-data-model.md §3.7:** "Rack elevation space is not stored. … Elevation is a
  **projection**, computed fresh, always correct by construction."
- **design-ux-rack.md (appendix):** `Placement { … final int bottomU; … final int?
  xOffsetTenthMm; }` — stored elevation geometry for shelf-hosted devices.

**Ruling: elevation geometry is derived, with one exception that is not geometry.**
A device's X/Y in the elevation is a pure function of `(Placement, rail geometry, face)` and is
never persisted. Lateral position on a **shelf** is genuine user intent and is stored, but as
an ordinal (`ShelfPlacement.order: FracIndex`) plus an optional `lateralOffset: Len?` for the
free-position case, not as a screen coordinate. See CR-035.

### CR-007 · Canvas boundary units

- **design-architecture.md §6.6:** "geometry coordinates are **document units (hundredths-mm,
  as doubles at this boundary)**."
- **design-pdf-export.md §6.1:** "**Unit convention: 1 diagram unit = 1 PDF point = 1/72 in.**
  Zero conversion on export."

**Ruling: 1 diagram unit = 1 PDF point = 1/72 in, `double` at the canvas boundary.**
This is not a breach of "no doubles": the model stores integers and the `DiagramScene` is a
transient rendering artifact that is never persisted. Conversion from `Len(nm)` to points
happens in exactly one function in the scene builder. `design-architecture.md §6.6`'s
hundredths-mm boundary is deleted, as is its dependency on CR-001's rejected unit.

---

## 1.2 The wiring entity model

### CR-008 · `Connection` vs `Link` + `Net` + `Conductor` + `SignalRoute`: four namings

- **design-data-model.md §0:** "'Connection' is three different things in this domain and
  conflating them is the single most expensive mistake available here."
- **design-ux-schematic.md §0.1:** "The document stores **connectivity only**:
  `Connection(uuid, fromPortRef, toPortRef, domain, media, label, layerId, sheetId,
  routeOverrides?)`."
- **design-architecture.md §1.2:** "`connection.dart # Connection: fromPort, toPort,
  cableType, length`."
- **design-pdf-export.md §10:** "`model/ … PhysicalLink, LogicalSignal, CableType`."

**Ruling: `design-data-model.md` wins on structure; its names are canonical.** The entity set
is `Link` (one physical cable) → `Service` (one signal carried on it, new, see CR-010) →
`Conductor` (one electrical path) and `Net` (one stored logical equivalence class).
The word **`Connection` is banned** from code, file format, and prose. `PhysicalLink`,
`LogicalSignal`, and `CableType` are deleted. `connection.dart` becomes `link.dart`; the
commands become `AddLink`/`RemoveLink`/`RetypeLink`. `SignalRoute` is deferred (AC-011).

### CR-009 · `Link` has no `signalFamily`, and the flagship rule reads one

- **design-data-model.md §3.6:** "`Link.signalFamily = video.hdbaset`, `media =
  media.cat6a_futp`."
- **design-data-model.md §2.9:** the `Link` class declares `media`, `cableSpecId`, `gaugeAwg`,
  `jacket`, **no `signalFamily`**; the family lives on `Net`.

**Ruling: the family lives on `Service`, and `SIG-001`/`SIG-002` evaluate per-service.**
`Link.dominantSignalFamily` is a derived value used only for line colour. `Net.signalFamily`
remains. This is the same field that CR-010 needs, so both are resolved by one change.

### CR-010 · One cable, one service: contradicted by the trade

- **design-data-model.md §2.9:** `Link` carries a single `media`; its `Net` a single
  `signalFamily`; `Conductor` has `role` and `pairNumber` but no family.
- **design-ux-device-builder.md §6.5:** a drop has one `Service` column, one value.
- **critique-domain-realism.md M6:** "One Cat5e … carries, on separate pairs: an IR emitter
  run, a 12 V trigger, and an RS-232 to the display. This is completely routine."

**Ruling: a `Link` carries `List<Service>`.**

```
Link    { id, designator, designatorLocked, class, media, jacket, gauge, shielded, plenum,
          lengths, status, test, pathwayId, breakouts[], conductors[], services[] }
Service { id, signalFamily, netId, conductorRoles[], label }
Conductor { role, from: Endpoint, to: Endpoint, pairNumber, colorCode, polarity }
```

`Link.netId` is deleted; `Service.netId` is non-null. A single-service cable has exactly one
`Service` and the UI never shows the concept. The schedule prints one row per **cable** with a
services sub-line. Resolves CR-009 and AC-021 together.

### CR-011 · `Net`: stored or name-derived

- **design-data-model.md §3.6:** "`Net` is **stored, not derived** … **Rejected: derived-only
  nets (union-find over links at read time).** Tempting and wrong."
- **design-ux-schematic.md §1.6:** "Bus entries are **purely graphical and establish no
  connectivity**: membership is carried by **net name**."

**Ruling: stored.** Membership is the foreign key `Service.netId`. Name-carried membership is
precisely the KiCad failure that `design-ux-schematic.md §1.5` itself indicts ("typos can
prevent signals from being connected"); a GUI tool with a device library has no excuse for it.
Net *names* remain generated from a template and are never load-bearing. Bus rendering stays
purely graphical. Union-find is used only to *propose* merges, which a command then applies.

### CR-012 · Route geometry: persisted or forbidden

- **design-ux-schematic.md §0.1:** "**No wire coordinates. No route geometry.** … If you ever
  find yourself persisting a polyline, you have made an architectural error.", then §2.3
  ships waypoints, pinned routes, and `routeOverrides?`.
- **design-data-model.md §2.9:** `Map<Uuid, List<Pt>> waypointsBySheet; // manual orthogonal
  routing per sheet`.

**Ruling: no route geometry is persisted in v1.** The router is a pure deterministic function
of the model. `Link.waypointsBySheet`, `routeOverrides`, and `RouteWaypoint` are removed.
`design-ux-schematic.md` is right in principle and self-contradictory in fact. When manual
rerouting returns (v1.2) it is stored as **constraints**, an ordered list of grid points that
the router must pass through, under a field named `routeConstraintsBySheet`, never as a
polyline. **Symbol placement is persisted** (it is user intent); wire geometry is not.

### CR-013 · The router: obstacle-avoiding pathfinder or channel router

- **design-architecture.md §5.2:** `RouteCache` with an `ObstacleField`, per-connection
  incremental invalidation, "`router.dart # orthogonal trace router, obstacle-aware`",
  "~15–40 ms cold."
- **design-ux-schematic.md §2.6/§3.1:** "**Do not build incremental-reroute machinery in v1.**
  A full deterministic recompute is both cheaper than the invalidation bookkeeping and
  perfectly stable." / "RackMate **never needs a general orthogonal router**."

**Ruling: Sugiyama layering + interval-graph channel routing, full deterministic recompute.**
`ObstacleField`, `RouteCache`, and the phrase "obstacle-aware" are deleted from
`design-architecture.md`. The interval-graph-colouring argument is the strongest single
technical insight in the corpus and it eliminates the invalidation machinery entirely. One
amendment from `critique-feasibility.md #20`: phase 5 (crossing sweep, hop arcs) is **not** run
at commit; it runs at paint time, scoped to the visible viewport.

### CR-014 · `Link` spans exactly two devices

- **design-data-model.md I-25:** "every conductor's `fromPortId`/`toPortId` resolve to live
  ports on **exactly two distinct devices** across the whole link. A link spanning three
  devices is corrupt."
- **critique-domain-realism.md M11:** "A dual-head IR emitter: one 3.5 mm plug at the IR block,
  two emitter heads on two components. One cable, one part number, one pull, three devices."

**Ruling: relaxed to the conductor.** Each **`Conductor`** spans exactly two endpoints; a
`Link` may reference up to N devices. `Link.breakouts: List<Breakout{label, atLengthFraction}>`
describes fan-outs for the schedule. I-25 is rewritten accordingly.

### CR-015 · Adapters: embedded value or real device

- **design-data-model.md §2.9/§3.5:** `InlineAdapter` is a value object inside
  `Link.inlineAdapters` with `satisfiesRuleIds`; "`CON-001` and `ELE-002` are both satisfied by
  data, not by acknowledgement."
- **design-ux-schematic.md §2.2:** "**Adapters as first-class objects.** … these are
  `ruHeight: 0`, `mountLocation: not-in-rack` passive **devices**. They appear in the netlist
  and the BOM."

**Ruling: both, split on whether the adapter has its own terminations.**
A **passive in-line adapter** with no independent cable on either side (barrel, gender changer,
null-modem shell, RCA→XLR transformer on a pigtail) is an `InlineAdapter` value on the Link.
An **active or two-cable device** (HDBaseT TX/RX pair, balun pair, RF splitter, IR connecting
block, DA) is a real `DeviceInstance` with `mountMethod: notInRack` and two or more Links.
The test is mechanical: *does an installer pull two separate cables to it?* If yes, it is a
device. `design-data-model.md` is already inconsistent here, it models RF splitters and IR
blocks as devices, and this rule resolves it. The `SIG-001` remedy
`[ Insert HDBaseT receiver ]` therefore inserts a device, correctly.

### CR-016 · "Bundle" means three different things

- **design-ux-schematic.md §1.6:** "**Bundle (snake)**: a *purely organisational* grouping of
  **physical runs** that share a conduit … `B03 · 4 runs · 40'`."
- **design-ux-device-builder.md §6.6:** `Bundle { … members: [dropId] }`, members are drops.
- **design-data-model.md §2.8:** `StructureBundle`, "One **OUTLET LOCATION**. The atomic unit
  of creation, specification and pricing."

**Ruling: two entities, two names, neither called "Bundle" alone.**

- **`Outlet`** (renamed from `StructureBundle`), one wall plate / one ceiling location. Owns
  designation, room, mounting, and the set of Links home-running to it. The
  creation/specification/pricing atom. `design-data-model.md`'s argument for it is correct.
- **`Pathway`** (absorbing "bundle/snake" and `conduitId`/`pathwayId`), a conduit, J-hook
  run, tray, or trunk that N Links share. Purely organisational: affects drawing (one trunk
  that fans out) and schedule grouping, never connectivity. Promoted to a first-class entity
  because AC-027 needs it to carry `containsLineVoltage` and `kind`.

The word "bundle" survives only as UI copy for `Pathway`.

---

## 1.3 Validation philosophy

### CR-017 · "Never block the pen" vs "hard-invalid, refused at drag time"

- **design-data-model.md §3.5:** "Validation **never blocks the pen** … **Only five rules block
  creation** … **A model that cannot draw a mistake cannot document reality**, cannot plan a
  remediation, and cannot import an as-found survey." `SIG-001` is
  `blocksCreation: false, userAcknowledgeable: true`.
- **design-ux-schematic.md §2.2:** "**Class A: hard-invalid. Refused at drag time. Cannot
  exist in the document.**": including HDBaseT→switch, IR emitter→receiver, connector
  mismatch, Dante with no network path, AVB across a non-TSN switch.
- **design-ux-rack.md §3.2:** placement checks 1–4 and 6–7 "**block**" the drop.

**Ruling: `design-data-model.md` wins, with one precise concession.** The binding distinction
is:

> **The gesture may hesitate. The document may not lie.**

- **Model-level illegality**: only `TOP-001..005` (self-connection, duplicate ordered pair on
  one link, over `maxConnections`, dangling endpoint, container cycle) plus placement
  coherence (`ruIndex` within the rack; host is a container; no containment cycle). These are
  states in which the model means nothing, not states the world disallows.
- **Gesture-level refusal**: `design-ux-schematic.md`'s Class A becomes *spring-back with a
  reason chip*, and every chip carries `[ Connect anyway ]` next to its remedies. The remedy
  chips are excellent and are kept exactly as designed; only the finality goes.
- Two of Class A's members, "Dante endpoints with no network path" and "AVB traversing a
  non-AVB switch", are **logically unevaluatable at drag time**, because the link being drawn
  may be the one that completes the path. They are demoted to post-hoc findings unconditionally.
- The rack editor's blocking drop checks are demoted to warnings **except** RU-range-free
  (physical impossibility on the same face) and fits-within-rack-extent.

### CR-018 · Severity vocabulary: three of them

- **design-data-model.md §2.10:** `error | warning | advisory | off`, plus an *acknowledged*
  state.
- **design-ux-rack.md §5.2:** `Error | Warning | Info`.
- **design-ux-schematic.md §2.2:** `error | warn | info` plus Class A.

**Ruling: `error | warning | advisory | off`.** "Info" is renamed `advisory` everywhere.
Class A is deleted per CR-017. Severity is a property of the rule *in this project*, settable
per rule; the shipped default is the catalogue value.

### CR-019 · Three dismissal mechanisms

- **design-data-model.md §3.5:** acknowledge a Finding with a written reason; it demotes and
  "the reason **PRINTS** in the schedule."
- **design-ux-rack.md §5.2:** "Warnings are dismissible per-instance with a required reason
  note … **Errors are not dismissible.**"
- **design-ux-schematic.md §6.3:** "Rules can be **muted per-project** with a required
  justification note."

**Ruling: one mechanism: `AckedFinding`, at two scopes.** An acknowledgement carries
`{ruleId, targetFingerprint, reason (required), by, at, demotedTo}`. `targetFingerprint == "*"`
means project-wide mute of that rule. **Errors are acknowledgeable**; refusing to let a
professional override the tool's opinion about their own system is how the tool gets abandoned.
`ProjectSettings.ruleSeverityOverrides: Map<String, Severity>` is deleted; it has no field for
the justification that two documents promise will print. It is replaced by
`Map<String, RuleOverride{severity, reason, by, at}>`.

### CR-020 · Rule-by-rule severity conflicts

`design-data-model.md` §3.5 and `design-ux-rack.md` §5.2 disagree on eight rules. Binding
severities, with the deciding argument:

| Rule | data-model | ux-rack | **Ruling** | Why |
|---|---|---|---|---|
| Σ weight > rack capacity | `RCK-003` error | Warning | **warning** (advisory at 85%) | A found over-spec install must be documentable (G2). |
| Device depth > usable depth | `RCK-005` warning | Error, blocks drop | **warning**, never blocks | `design-ux-rack.md §4.4` already refuses to displace on a depth change; blocking the drop but not the resize is incoherent. |
| Shelf hosted weight over capacity | `RCK-009` error | Warning | **warning** | Same as weight. |
| Hosted depth > shelf depth | `RCK-010` error | Warning | **advisory** | "Overhang is common and survivable": ux-rack is right. |
| Centre of gravity | `RCK-004` warning @50% | Info @55% | **advisory @55%, default off** for wall/credenza form factors | `critique-domain-realism.md m19`. |
| Spare RU | `RCK-008` advisory <15% | Info outside 15–25% | **advisory, default off** | A planning opinion, not a fact. |
| Σ continuous amps > 80% breaker | `PWR-001` error | warn | **warning**, on typical × diversity | AC-018. |
| Duplicate device designator | I-12 load warning | Error, "enforced not suggested" | **error finding, non-blocking**; allocator prevents creation; import offers one-click renumber | Both are right about different moments. |

### CR-021 · Rules that exist in only one document

- **design-ux-rack.md §5.2** adds, with no IDs: "Device with no power source", "Unplaced devices
  in Staging Bin", "Wall rack over 80% weight", "Heat source with no vent above".
- **design-ux-schematic.md §2.2** adds: "unconnected port on a placed device", "orphan device".

**Ruling: adopted into the one catalogue with IDs**, at these severities:
`PWR-006` device with power draw and no outlet assignment, **warning**;
`RCK-014` unplaced devices present, **advisory**;
`RCK-003b` wall-mount rack over 80% of capacity, **warning** (wall racks are the documented
failure mode);
`RCK-007` heat source with no vent above, **advisory**, gated on `Rack.formFactor` (AC-034);
`TOP-010` unconnected port on a placed device, **advisory, default off**;
`TOP-011` device with zero connections, **advisory**.
There is exactly one rule catalogue, in `docs/rules.md`, and a rule that is not in it does not
exist.

### CR-022 · `blockExportOnErrors`

- **design-data-model.md §2.1:** `bool blockExportOnErrors; // default true`.
- **design-ux-simplicity.md** and **critique-domain-realism.md B3** both identify this as
  producing a permanently unexportable project.

**Ruling: the setting is deleted.** Replaced by `ExportSpec.issuedForConstruction: bool`.
Errors block only the *"ISSUED FOR CONSTRUCTION"* stamp and the revision-block `issued` flag;
they never block bytes. Every export emits sheet **`T0.02 — Exceptions & Acknowledgements`**
listing open findings and every acknowledgement with its reason, author and date. This
simultaneously discharges the promise made by three documents that acknowledgement reasons
"print in the appendix", a sheet that appeared in no sheet list (G3).

### CR-023 · The legend-note invariant blocks export

- **design-data-model.md I-41:** "**Every sheet with `carriesLegend == false` has a non-empty
  `legendLocationNote`.** … **Blocks PDF export.**"

**Ruling: deleted as an invariant; implemented as an export-time auto-fill.** The exporter
knows which sheet carries the legend, so it writes `SYMBOL LEGEND: SEE SHEET T0.01` into every
other sheet's title block itself. There is nothing for the user to get wrong and therefore
nothing to validate. A drafting footnote must never gate a deliverable (G3).

### CR-024 · Rules as data or as code

- **design-data-model.md §2.10/§3.4:** "Compatibility rules live as **DATA** so a new adapter
  case does not need a release." `RulePredicate predicate; // declarative AST,
  JSON-serializable`. Argued as a central reason to reject enums.
- No document designs a rule-authoring or rule-inspection UI.

**Ruling: rules are Dart functions; the *catalogue* is data.** Accepted from
`critique-feasibility.md #6`, see AC-006 for the full reasoning and the surviving data layer.
The claim that users can author rules is **withdrawn** from all documents. The
connector×signal-family **compatibility matrix** genuinely is a lookup table and stays data.

---

## 1.4 The rack model

### CR-025 · RU origin: 0-based or 1-based

- **design-data-model.md §2.4:** "`ruIndex`, **1-based**, BOTTOM origin, always."
- **design-ux-rack.md (appendix):** "`bottomU`, **0-based** from the rack's physical bottom."

**Ruling: 1-based, bottom origin.** `ruIndex ∈ [1, heightU]`. The stored value equals the
printed value under the default bottom-up numbering, which deletes an entire class of
off-by-one between the elevation and the schedule. `bottomU` is renamed `ruIndex` and rebased
throughout `design-ux-rack.md`. This is the contradiction `critique-domain-realism.md` singles
out as "the one that will actually hurt", and it is asserted at load.

### CR-026 · RU numbering direction: project or rack setting

- **design-data-model.md §2.1:** `ProjectSettings.ruNumbering // bottomUpFromOne | topDown`.
- **design-ux-rack.md §2.1:** "the setting is **on the rack, not the app**, because a project
  can legitimately mix (a retrofit rack labelled by the previous integrator)."

**Ruling: per-rack, with a project default.** `Rack.ruNumbering` is authoritative;
`ProjectSettings.defaultRuNumbering` seeds new racks. The retrofit argument is decisive and the
field costs one enum. Numbering is **display only** and never affects `ruIndex` (CR-025).

### CR-027 · Ordering type: fractional index or integer

- **design-data-model.md §5.2:** "**No positional index is ever identity** … An integer
  `sortOrder` requires renumbering neighbours, and neighbour-renumbering is precisely the
  operation that makes sync impossible to retrofit."
- **design-ux-rack.md (appendix):** `int bayOrder`.
- **design-ux-device-builder.md §3.2:** `"order": 0` on ports and banks.

**Ruling: `FracIndex` everywhere in the persisted model**, including `.rmdev`. `bayOrder` and
every integer `order` are replaced. This is a G5 item: retrofitting fractional indices is a
migration touching every entity in the file.

### CR-028 · Circuits: project entity or rack child

- **design-data-model.md §2.1:** `Map<Uuid, Circuit> circuits` flat on the project;
  `Port.circuitId` on power inlets.
- **design-ux-rack.md §5.1/appendix:** "**Circuits are first-class objects on the rack.**" /
  `class Rack { … List<Circuit> circuits; }`.

**Ruling: flat `Map<Uuid, Circuit>` on the document, with `Circuit.rackId?`.** The rack
inspector renders circuits filtered by `rackId`, `design-ux-rack.md` gets its UX without the
nested list that `design-data-model.md §5.1` forbids. **One assignment chain:** circuit
membership is *derived* by walking power Links (device inlet → PDU outlet → PDU inlet →
circuit). `Port.circuitId` survives only on the ports where the rack meets the building, PDU
and UPS inlets, and hardwired devices. The "Unassigned" bucket is computed, not an entity.

### CR-029 · Shelf containment direction

- **design-data-model.md §2.4/§2.7:** child→parent (`ShelfPlacement.hostDeviceId`,
  `DeviceInstance.hostDeviceId`).
- **design-ux-rack.md §6.1:** `class ShelfOccupant { List<HostedDevice> hosts; }`, parent owns
  an ordered list.

**Ruling: child→parent only.** `ShelfPlacement{hostDeviceId, order: FracIndex,
lateralOffset: Len?}`. The parent never owns a list; `shelf.hosts` is a derived view sorted by
`order`. A parent-owned array is both a second source of truth and positional identity, which
`design-data-model.md §5.1/§5.2` forbid by name. `DeviceInstance.hostDeviceId` is deleted as
redundant with the placement variant.

### CR-030 · Half-rack lateral placement: supported or blocked

- **design-data-model.md §2.4:** `RailPlacement{startTwelfth 0..11, spanTwelfths 1..12}`, with
  "Two half-rack devices sharing 1U = {0,6} and {6,6}" as a worked example, plus I-19 and
  `RCK-011`.
- **design-ux-rack.md §3.2 check 7:** blocks the drop, "`Half-rack: needs an ear kit or a
  shelf`."

**Ruling: twelfths stay in the format; the v1 editor exposes three positions.** Retrofitting a
lateral axis into `Placement` is a migration touching every device, so the field ships (G5).
The v1 UI offers a `Width position` control with `Full (0,12) | Left half (0,6) | Right half
(6,6)`, a dropdown, not a drag interaction. A half-rack device dropped alone is **allowed**
and files an advisory naming the ear kit. Free lateral dragging is v1.2.

### CR-031 · `Placement` shape

- **design-data-model.md §2.4:** a sealed union of five variants.
- **design-ux-rack.md (appendix):** one flat class with nullable fields and
  `String? rackId; // null => Staging Bin`.

**Ruling: the sealed union, extended to carry what `design-ux-rack.md` actually needs:**

```
sealed Placement
  RailPlacement    { rackId, ruIndex, face, startTwelfth, spanTwelfths,
                     depthOffsetFromFront?, chassisRotation, locked }
  ShelfPlacement   { hostDeviceId, order, lateralOffset?, locked }
  ZeroUPlacement   { rackId, channelId, offsetFromChannelStart, orientation, locked }
  OffRackPlacement { locationId?, mountNote? }
  StagedPlacement  { lastRackId?, lastRuIndex?, lastFace?, schematicHint? }
```

`UnplacedPlacement` is renamed `StagedPlacement` and gains the return-to-rack fields.
`chassisRotation` is new (AC-023).

### CR-032 · The Staging Bin is unmodelled

- **design-ux-rack.md §2.4:** a first-class per-project object with wiring preservation, a
  return affordance ("Return to Rack A U21"), a `U` shortcut, a validation warning, and three
  feeder paths.
- **design-data-model.md:** only `UnplacedPlacement { Pt? schematicHint }`, no `lastRackId`,
  no `lastBottomU`, so "Return to Rack A U21" is unimplementable as specified.

**Ruling: the Staging Bin *is* `StagedPlacement`** (CR-031). It is a query, not an entity:
`devices.where((d) => d.placement is StagedPlacement)`. It ships in v1 with the return
affordance and `RCK-014` (CR-021).

### CR-033 · Bays are unmodelled

- **design-ux-rack.md §2.4:** "select 2+ adjacent racks → `Group as bay`. A bay draws shared
  side rails, a bracket above with the bay name, and rolls up vitals."
- No entity exists in any other document.

**Ruling: cut from v1, not reserved.** A bay is purely organisational and nothing depends on
it. When it returns it is `Bay{id, name, order, rackIds}`, a pure addition under the
additive-only rule, requiring no migration.

### CR-034 · Lock is unmodelled

- **design-ux-rack.md §3.7/§7.3/§8:** `Ctrl+L` lock/unlock, a 🔒 badge, `placement.locked`,
  auto-arrange treating locks as anchors, `refDesLocked`, "Include manually-locked designators
  (3)" in the renumber dialog.
- **design-data-model.md:** no lock field on any entity.

**Ruling: three lock flags ship in v1.** `Placement.locked` (CR-031),
`DeviceInstance.designatorLocked`, and `Link.designatorLocked`, the last auto-set when
`RoughInStatus >= pulled`, per `critique-domain-realism.md m22`: once sixty cables are
physically labelled, an accidental renumber is a day of relabelling. Renumber refuses locked
IDs by default and says how many it skipped.

### CR-035 · `mirrorRearElevation` is unmodelled, and its scope is self-contradictory

- **design-ux-rack.md §2.3:** "A **per-project** setting `mirrorRearElevation` (default
  `true`)."
- **design-ux-rack.md §4.1 and appendix:** the same field inside the *rack* inspector and on
  `class Rack`.
- **design-data-model.md:** neither.

**Ruling: per-rack (`Rack.mirrorRearElevation`, default true), with a project default.** Same
resolution as CR-026 and for the same reason. The `NOT MIRRORED` chip in the rack header when
it is off is retained, a drawing must never lie about itself.

### CR-036 · The occupancy struct

- **design-data-model.md §2.5:** `TemplateBody{frontU, rearU, side: OccupancySide, …}` with
  depth and weight as sibling fields.
- **design-ux-rack.md §6:** `class Occupancy { frontU, rearU, MountSide side, depthTenthMm,
  weightGrams }` — different enum name, depth and weight folded in.
- **design-ux-device-builder.md §1.3:** matches data-model's shape but its `side` enum is
  `front · rear · both · zeroU_vertical`, missing `none`, different casing.

**Ruling: `design-data-model.md`'s shape and spelling.**
`OccupancySide { front, rear, both, zeroUVertical, none }`. Depth and weight stay siblings on
`TemplateBody`: they are per-model physical facts with their own override semantics, and
folding them into an occupancy struct implies they vary with mounting, which they do not.

### CR-037 · Rail-type enum

- **design-data-model.md §2.3:** `tapped10_32 | tapped12_24 | squareCageNut | roundClearance |
  m6`.
- **design-ux-rack.md §2.1:** `tapped10-32 | tapped12-24 | square | clearance`, different
  spelling, `m6` missing.

**Ruling: `design-data-model.md`'s five values and spelling.** Rail type affects hole
rendering and the hardware line in the materials list; it never gates placement.

### CR-038 · Maximum rack height

- **design-ux-rack.md §4.2:** "range 1–58."
- **design-architecture.md §10.1:** "RU per rack: target 45, hard cap 60."
- **design-data-model.md:** unbounded.

**Ruling: `heightU ∈ [1, 60]`**, asserted as an invariant, with an advisory above 50. 58U and
60U products both exist; 60 is the honest cap and matches the performance envelope.

### CR-039 · Three sources of truth for voltage

- **design-data-model.md:** `PowerProfile.nominalVolts` (template) and `Circuit.volts`.
- **design-ux-rack.md (appendix):** `Rack.lineVoltage; // 120 | 230 | 240`.

**Ruling: `Circuit.volts` is authoritative downstream of a circuit.**
`PowerProfile.nominalVolts` is the device's *rated* input and is used only for a compatibility
check. `Rack.lineVoltage` is **deleted**; it was only ever a default for creating circuits, so
it becomes `ProjectSettings.defaultLineVolts`.

### CR-040 · `Rack.designator` vs `Rack.refDesPrefix`

- **design-data-model.md §2.3:** `String designator; // "RK-1" — must match schedule Location
  column`.
- **design-ux-rack.md (appendix):** `String refDesPrefix; // "R1"`, used for per-rack
  designator scoping (`R1-AMP-1`).

**Ruling: `Rack.designator` only.** Per-rack designator scoping composes from
`Rack.designator` directly (`RK-1-AMP-1`, or `RK1-AMP-1` when the separator setting is empty).
`refDesPrefix` is deleted; two identifiers for one rack is exactly the failure the schedule
exists to prevent.

---

## 1.5 Identifiers, designators, and the format engine

### CR-041 · Device designator format: three renderings

- **design-data-model.md §2.1:** `"{typePrefix}-{seq:2}" → "MTX-01"`; the JSON example uses
  `MTX-01`, `SW-01`, `STR-01`.
- **design-ux-rack.md §7.2** and **design-ux-device-builder.md §1.2:** `{prefix}-{n}` →
  `AMP-1`, `MTX-1`.
- **design-ux-schematic.md §1.2** and every wireframe: `MTX1`, `AMP2`, `SW1`, `AVR1`.

**Ruling: `{TYPE_PREFIX}{SEP}{SEQ}`, default separator `-`, default pad 0.** Ships as
`MTX-1`, `AMP-12`. `ProjectSettings.designatorSeparator` (may be empty, giving `MTX1`) and
`designatorPad` (giving `MTX-01`) cover both other renderings as project preferences. The
designator is **stored once at allocation** and never re-derived at render time; sorting is
natural-order (`AMP-2` before `AMP-10`).

### CR-042 · Port designator: template-owned or project-computed

- **design-data-model.md §2.1/§3.9:** `portDesignatorFormat "J{devSeq:2}{portSeq:2}" →
  "J2301"`, unique **project-wide**, with `designatorBlockSize: 100` reserve blocks.
- **design-ux-device-builder.md §2.5/§3.2:** `Designator` is a **template grid column**, "auto
  until manually edited"; `.rmdev` ships `"designator": "J1"`.
- **design-ux-schematic.md §1.3:** `J01`, `J09`, `J17`, two digits, per device.

**Ruling: template supplies a hint; the project allocates; uniqueness is per device.**
`PortDef.designatorHint` is a seed only. `Port.designator` is allocated at instantiation from
`ProjectSettings.portDesignatorFormat`, default **`J{PORT_SEQ:2}` → `J01`**: matching every
schematic wireframe and ASME practice. A port is always cited as `MTX-1:J09`, so project-wide
uniqueness buys nothing and reads as bizarre on a residential job. The AV block scheme
(`{DEV_BLOCK}{PORT_SEQ:2}` → `2301`) ships as a preset for commercial work; reserve-block
allocation works identically at either scope. I-12 is corrected to *unique within device*.

### CR-043 · The `STR` prefix collides in shipped data

- **design-ux-rack.md §7.2** seed prefixes: "`STR` structure."
- **design-ux-device-builder.md §7.5** catalog A06: "Multi-Zone Streaming Source, `STR`."

**Ruling: the streaming source becomes `STRM`.** Structure keeps `STR`. A CI test asserts
that no two catalog templates share a `typePrefix` with a system prefix.

### CR-044 · Structure drop labels

- **design-data-model.md §2.8:** `fieldLabel` (required, unique) + `rackLabel` (nullable,
  unique when set); formats `{type}-{room}-{dir}-{seq}` and `{floor}{space}-{panel}{port}`.
- **design-ux-device-builder.md §6.5/§6.8:** columns `Label` + `TIA-606 ID`; "**Both**
  identifiers are generated for every drop"; default `{roomAbbr}-{service}-{seq}` → `LR-TV-1`.

**Ruling: `fieldLabel` (required, project-unique) + `rackLabel` (optional, project-unique when
set).** The device-builder's `Label` column *is* `fieldLabel`; its `TIA-606 ID` column *is*
`rackLabel`. Both are generated from templates, both are editable, **both always print**: this
is, per `critique-domain-realism.md`, "the single most valuable line in these four documents"
and it is not negotiable. Two presets ship, not five (AC-046): `Residential CI`
(`{ROOM_ABBR}-{SERVICE}-{SEQ}`) and `TIA-606 Class 2` (`{FLOOR}{SPACE}-{PANEL}{PORT:2}`).

### CR-045 · Three token vocabularies, no grammar, no registry

- **design-data-model.md §3.9:** `{typePrefix} {seq:2} {devSeq} {portSeq} {devBlock} {type}
  {room} {dir} {floor} {space} {panel} {port} {area} {run}`.
- **design-ux-device-builder.md §6.8:** `{site} {building} {floor} {tr} {rack} {panel} {port:2}
  {room} {roomAbbr} {outlet} {service} {media} {seq} {seq:2} {bundle}`.
- **design-ux-schematic.md §1.5:** `{DOMAIN} {SRC_REFDES} {SRC_PORT} {ROOM} {DEVICE} {N}`.
- **design-pdf-export.md §3.2:** a fourth set with a formal grammar including optional segments
  and filters.

**Ruling: one grammar, one registry, one parser: `design-pdf-export.md §3.2`'s.**
It is the only formally specified one and the only one with optional segments (`[...]`), zero
padding (`:n`), and filters (`|upper`, `|first n`, `|nz`), all of which the other three need
and none of which they define. Token names are **UPPER_SNAKE**. The three vocabularies merge;
collisions resolve to the longer, unambiguous name (`{ROOM}` and `{ROOM_ABBR}`, not `{abbr}`).
`{{` and `}}` are literal braces. `CollisionPolicy{suffixLetter | suffixNumber | error}` is
project-wide. Lives in `rackmate_core/idformat/`; five call sites (device, port, link, drop
field label, drop rack label) share it.

### CR-046 · `Location.code` vs `abbr`

- **design-data-model.md §2.2:** `String code; // "MBR"`.
- **design-ux-device-builder.md §6.2:** "an editable `abbr` (Living Room → `LR`)".

**Ruling: `Location.code`.** One field, one name; `{ROOM_ABBR}` is the token that reads it.

### CR-047 · Location vocabulary shape: tree, fixed 4-level, or flat list

- **design-data-model.md §2.2:** arbitrary-depth tree with
  `LocationKind{site, building, floor, room, zone, outdoor}`.
- **design-ux-device-builder.md §6.2:** fixed `Site → Building → Floor → Room → Outlet`.
- **design-ux-rack.md §7.5:** a **flat list**: "`Locations: Basement, Media Closet, Living
  Room…`" with inline creation.

**Ruling: one arbitrary-depth tree; the other two are views of it.** The device-builder's
four levels are the tree with `kind` filtering; the rack editor's combobox is the same tree
flattened to breadcrumb strings (`Level 1 › Living Room`) with inline creation that appends to
the currently-selected parent. `Outlet` is **not** a location level; it is the `Outlet` entity
of CR-016. Critically, the location editor is **not owned by the Structure editor**: it is a
project-level panel (`Project ▸ Locations…`), which closes the gap in
`critique-completeness.md A6.4` where a project with no Structure device cannot build a
location hierarchy at all.

### CR-048 · Cable ID materialisation

- **design-pdf-export.md P5/§3.6:** "IDs are **stored, not recomputed** … materialised onto the
  link at creation time … A PDF exported yesterday and today from an unmodified project are
  byte-comparable."
- **design-data-model.md §3.9:** the format engine is described as evaluating templates, with
  no statement about when.

**Ruling: `design-pdf-export.md` P5 is a governing principle and is adopted verbatim.**
Every designator (device, port, link, drop) is evaluated once at creation and stored. Nothing
is recomputed at render time. Changing a scheme offers a renumber with a diff; it never
silently renumbers, and it never touches a locked ID (CR-034).

### CR-049 · Net names: generated or typed

- **design-ux-schematic.md §1.5:** "**Net names are generated, never typed.**"
- **design-data-model.md §2.9:** `Net.name` is a free string the user may set, and
  `Net.designator` is `N012`.

**Ruling: generated by default, editable, never load-bearing.** `Net.name` is auto-filled from
`ProjectSettings.netNameFormat` and may be overridden; membership is always the FK (CR-011), so
a typo is cosmetic. Q-SYS's rule is adopted: duplicate *source* names prohibited, duplicate
*destination* names permitted.

---

## 1.6 Templates and the library

### CR-050 · Template version type: integer or semver

- **design-data-model.md §2.5:** `int version; // monotonic; every edit forks a new version`;
  snapshots keyed `"$templateId@$version"`; `TemplateRef{templateId, version: int,
  contentHash}`.
- **design-ux-device-builder.md §1.2/§4.2:** `version: {major, minor, patch}`, "computed from
  the diff, not chosen by the user"; `derivedFrom: {templateId, version: "1.0.0"}`.

**Ruling: `int version`, monotonic.** A semver whose components are *computed* adds a
vocabulary without adding a capability, and `TemplateRef` cannot hold one. The change class
(safe / additive / breaking) is still computed from the diff and **displayed prominently**, 
it is genuinely useful, but it is not encoded in the version number.

### CR-051 · The template migration join key: `PortKey` or `portId`

- **design-data-model.md §3.3:** "`PortDef.key`, STABLE, author-assigned … This is the **ONLY**
  thing that makes connections survive a template revision", with `renamedFrom` aliases.
- **design-ux-device-builder.md §3.2/§5.3:** "**`portId` is the join key**, not label or index.
  `portId` UUIDs are generated once and preserved across every version."

**Ruling: `PortKey` string plus `renamedFrom`.** A UUID cannot express *"this port was renamed
from that one"*, which is the exact case the mechanism exists for; and a stable, readable string
key is diffable in the `.rmdev` file, which is a stated product differentiator that a UUID
destroys. `.rmdev` gains `key` and `renamedFrom` and loses `portId`. Distinguish the three
identities, which remain three (`design-data-model.md §3.3` is right about this):
`Port.id` (UUID, project graph identity, what `Conductor` references) ·
`PortDef.key` (template identity, the migration join) ·
`Port.designator` / `userLabel` (human identity, what is printed).

### CR-052 · Removed-port outcome on template migration

- **design-data-model.md §3.3 step 5:** "if the Port has no Conductors → delete. else → set
  `orphaned = true`. **DO NOT DELETE. DO NOT DELETE THE LINK.** … **Rejected: deleting
  orphaned ports and their links.** Data loss on a routine operation."
- **design-ux-device-builder.md §5.3:** per affected cable, `[ Remap ▾ ] [ Keep ] [ Del ]`, 
  one click, no confirm.

**Ruling: orphan, never delete.** The Update Manager's per-cable choices are
`[ Remap ▾ ]` and `[ Keep as orphan ]`. **`[ Del ]` is removed.** A user who wants a cable gone
deletes it explicitly through the normal delete path, with its normal confirm and its normal
undo entry. Presenting destructive and non-destructive options as equal-weight one-click
siblings during a routine maintenance operation is how tools lose data.

### CR-053 · Override key namespace

- **design-data-model.md §3.2:** dotted paths into `TemplateBody`, `"weight"`,
  `"power.nameplateWatts"`, `"bodyDepth"`.
- **design-ux-device-builder.md §5.1:** `"identity.name"`, `"physical.weightKg"`,
  `"ports.<portId>.label"`, paths into the `.rmdev` *file* shape, and port overrides stored on
  the **device**.

**Ruling: neither. Typed `DeviceOverrides` and `PortOverrides` classes.** See AC-012 for the
full argument. Port overrides live on `Port` (keyed by port), never in the device's map, a
device-keyed map of port overrides re-introduces the composite-key identity the model bans.
`.rmdev`'s `identity.` / `physical.` / `power.` sections are a **file layout only**; the codec
flattens them onto `TemplateBody`.

### CR-054 · Detach mechanism: two doors, four verbs, three snapshot stores

- **design-data-model.md §3.1:** "the UI presents **exactly two doors** … **There is no third
  door.**" Plus `DeviceInstance.localTemplate` for per-instance forks, and I-9: `templateRef`
  resolves **or** `localTemplate` is non-null, "Never neither."
- **design-ux-device-builder.md §5.2:** **four** verbs, including "Detach instance
  (`templateRef → null`)", with the instance carrying its own `snapshot`.

**Ruling: three doors, one snapshot store.**

| Door | Effect |
|---|---|
| **Edit this device only** | writes `DeviceOverrides`; template untouched |
| **Edit the template** | forks `version+1` in the library; placed instances untouched until opted in |
| **Fork to a new template** | new `templateId`, seeded from snapshot + overrides, this instance rebinds, overrides cleared, `derivedFrom` recorded |

The fourth verb ("Detach instance", `templateRef → null`) is **deleted**: it produces a device
with no lineage, and door 3 covers the case with better provenance.
`DeviceInstance.localTemplate` and `PlacedDevice.snapshot` are both **deleted**: snapshots live
in exactly one place, `RackDocument.templates` keyed `"$templateId@$version"`. I-9 simplifies to
"`templateRef` always resolves to an embedded snapshot."

### CR-055 · Port banks are unmodelled

- **design-ux-device-builder.md §3.2:** a first-class `banks[]` array
  (`bankId, name, abbr, symbolSide, collapseInSymbol, order`).
- **design-ux-schematic.md §1.2:** the entire symbol layout is built on banks, edge
  assignment, brackets, folding, vector pins.
- **design-data-model.md:** only `PortGroupDef`, an *electrical* grouping (component video,
  speaker pair, `atomicConnect`). A different concept; `symbolSide` has no field.

**Ruling: model both, and stop the name collision.**
`TemplateBody.banks: List<BankDef{key, label, abbr, symbolSide, collapseInSymbol, order}>` with
`PortDef.bankKey`, a **presentation** grouping.
`PortGroupDef` is renamed **`PortSetDef`**: an **electrical** grouping (Y/Pb/Pr, L/R, +/−,
`atomicConnect`). Both ship in v1: banks drive the symbol and the auto panel layout; sets drive
atomic connect and the conductor roles of CR-010.

### CR-056 · `poeBudgetWatts` has no home, and the power model is short two fields

- **design-data-model.md §4.5:** the JSON example carries `"poeBudgetWatts": 370` as an
  **undeclared key**; `PowerProfile` has no such field, yet `NET-001` (an error) requires it.
- Neither `PowerProfile` nor `.rmdev` has apparent power or power factor, while
  `design-ux-rack.md §5.1` computes `amps = watts / 120`.

**Ruling: `PowerProfile` gains `poeBudgetWatts: int?`, `apparentVA: int?`, and
`powerFactor: int?` (permille).** Circuit loading is computed in **VA**; UPS capacity is checked
VA against VA. See AC-018, a linear-supply amplifier at PF 0.65 under-reports current by 35%
on exactly the gear where it matters, which is the classic way to trip a breaker on a system
that "calculated fine".

### CR-057 · Passthrough pairing has no file format

- **design-data-model.md §2.6:** `PassthroughPairDef{frontKey, rearKey, sameNet}` on the
  template, with invariant I-32.
- **design-ux-device-builder.md §2.5/§3.2:** a `Paired port` grid column and a "Pair front↔rear
  by order" action, and **no pair array in the `.rmdev` schema**.

**Ruling: `.rmdev` gains `passthroughPairs: [{frontKey, rearKey, sameNet}]`.** The grid column
and the pairing action write it. The catalog's patch panels are re-authored against it. A
passthrough template whose pairs are missing is a load warning, not an error.

### CR-058 · Two incompatible vocabulary namespaces

- **design-data-model.md §3.4:** reverse-hierarchical namespaced IDs, `conn.rj45`,
  `video.hdmi.2_0`, `net.ethernet`, `power.ac_120`.
- **design-ux-device-builder.md §7:** flat bare names, `HDMI-A`, `RJ45`, `hdmi20`, `ethernet`,
  `ac-inlet`, across the largest vocabulary in the project (~35 connectors, ~45 families).
  Note `ac-inlet` is used as a *signal family* where the data model has family `power.ac_120` +
  `PortPowerSpec.role: inlet`.

**Ruling: namespaced IDs are canonical; the bare names become registry aliases.**
`ConnectorTypeDef.aliases: List<String>` and `SignalFamilyDef.aliases` hold `HDMI-A`, `hdbt`,
`rj45`, `xlr`, `spdif` and friends; the Quick Add DSL resolves against them. This gives the DSL
its ergonomics and the file format its namespacing and forward compatibility, and it is what
makes `.rmdev → .rackmate` import well-defined. `ac-inlet` is re-authored as
`power.ac_120` + `role: inlet` throughout the catalog.

### CR-059 · Gender enum is ambiguous, and a shipped rule is broken by it

- **design-data-model.md §2.6:** `male | female | genderless | jack | plug`, five values
  containing two synonym pairs.
- **design-ux-schematic.md §1.3:** "**filled = female/jack, hollow = male/plug**", treats them
  as synonyms.
- Consequence: `CON-002` ("genders both male or both female") never fires for `jack`+`jack`.

**Ruling: three values: `male | female | genderless`.** `jack` and `plug` are deleted; a jack
is a female panel connector and a plug is male. `ConnectorTypeDef.genderApplies: bool` decides
whether `CON-002` evaluates and whether the glyph fill encodes gender, which is what
`design-ux-schematic.md` actually wanted when it restricted gender encoding to XLR, IEC, DB9,
SpeakON and fibre. Fixes a concrete bug in a shipped rule.

### CR-060 · Direction encoding

- **design-data-model.md §2.6:** `source | sink | bidirectional | busNode | passive`.
- **design-ux-device-builder.md §2.5/§7:** grid values `In / Out / Bi / Bus / Passive`, but the
  catalog notation is `i/o/b/p` where **`p` means "passive/bus node"**: two enum values
  collapsed into one letter across the entire catalog.
- **design-ux-schematic.md §1.3:** adds "Power inlet" and "Power outlet" as directions.

**Ruling: five values, and the catalog notation gains a letter.** `i o b n p` where `n` =
`busNode` and `p` = `passive`. Every catalog entry using `p` is re-audited, the distinction is
load-bearing for `DIR-002`, `BUS-001`, `BUS-002` and the multi-drop stub glyph. "Power inlet"
and "power outlet" are **not directions**: they are `sink`/`source` on a `power.*` family with
`PortPowerSpec.role`.

### CR-061 · Catalog size: four numbers

- **design-ux-device-builder.md** title and §0: "**58 Templates**", "58-device seeded catalog".
- **design-ux-device-builder.md §7.9** summary table: "Total shipped templates | **62**".
- **design-architecture.md §1.2:** "the seeded **~40** templates".
- Brief: "~30-50" in prose, **~40–55** in the confirmed decisions.

**Ruling: v1 ships 48 templates: 30 rack-side and 18 field-side.** This sits mid-band in the
confirmed 40–55 and makes room for the field devices of AC-019 without growing the authoring
job. The count is stated in exactly one place, `docs/catalog.md`, and **no prose in any
document states a number**. The gate for shipping a template is AC-052: every numeric field has
a cited source.

### CR-062 · Seeded templates are read-only: the consequence is unstated

- **design-ux-device-builder.md §5.4:** "Seeded templates ship read-only. Editing one silently
  performs **Duplicate → edit the copy**."
- No document surfaces the consequence: a user who corrects a wrong wattage forks the template
  and permanently loses catalog corrections for that device.

**Ruling: the mechanism is correct; the consequence is surfaced.** A forked template records
`derivedFrom{templateId, version}`, and when the catalog later revises that source the fork
shows a passive badge: *"Based on catalog 'HDMI Matrix 8×8' v1, the catalog version has since
been corrected (v3). Compare…"*. No action is forced. This costs one badge and one diff view
that already exists.

### CR-063 · `.rmdev` uses floating-point millimetres

- **design-ux-device-builder.md §3.2:** `"depthMm": 330`, `"weightKg": 7.3`, `"xMm": 24.0`.
- **design-data-model.md I-1:** "**No `double` appears anywhere in the persisted model.**"

**Ruling: `.rmdev` obeys I-1.** `depthNm`, `weightUg`, `xNm`. The template file is part of the
persisted model; there is no second unit regime.

---

## 1.7 Sheets, layers, and views

### CR-064 · Layers are entirely unmodelled

- **design-ux-schematic.md §4.2:** "User-defined named layers, each with `visible / locked /
  prints` flags … **Layers are a document concept and they do persist.**" `layerId` appears in
  the Connection definition, the connections table, Properties, the search language, and
  `sheetFilter`.
- **design-data-model.md:** no `Layer` entity and no `layerId`, only
  `DeviceStatus{existing, new, future, removed}`.

**Ruling: cut from v1; `LifecycleStatus` carries the v1 need.**
`LifecycleStatus{existing, new, future, removed}` is added to **both** `DeviceInstance` and
`Link`, the design-intent axis, orthogonal to `RoughInStatus` (the progress axis). That covers
the demolition/phasing rendering conventions every drawing set actually needs. User-named layers
with per-layer print flags are a commercial-retrofit feature; they return in v2 as a pure
addition. `layerId` is **not** reserved, the additive-only rule makes reservation unnecessary.

### CR-065 · Three status vocabularies under one column header

- `DeviceStatus{existing, new, future, removed}` (design-data-model.md §2.7).
- `RoughInStatus{planned, pulled, dressed, terminated, tested, issued}` (§2.8/§2.9).
- **design-ux-device-builder.md §6.5:** `{Planned, Pulled, Terminated, Tested, In use, Spare,
  Abandoned}` — drops two, adds three.
- **design-ux-schematic.md §6.1:** a connections-table `Status` column showing `✓`/`⚠`, which
  is **DRC state**, a fourth meaning under the same header.

**Ruling: two stored axes, one derived, and "Status" is never a bare column name.**

| Axis | Values | Where |
|---|---|---|
| `LifecycleStatus` | existing · new · future · removed | design intent; devices and links |
| `RoughInStatus` | planned · pulled · dressed · terminated · tested | field progress; links only |
| *(derived)* | in use · spare | computed from whether the link has both endpoints bound |

`issued` is deleted from `RoughInStatus`; it is a revision-block concept, not a cable state.
`Abandoned` maps to `LifecycleStatus.removed`. The DRC column is headed **`ISSUES`**, never
`Status`.

### CR-066 · Sheet numbering scheme

- **design-data-model.md I-40:** `Sheet.number` must match `^[A-Z]{1,2}\d\.\d{2}$`, NCS.
- **design-pdf-export.md §12 decision 1:** agrees, "NCS `T`-discipline numbering".
- **design-ux-schematic.md §1.7:** title block shows "`SHEET 2 of 6 · VIDEO`" and "`DRG
  SR-0247`" — no NCS numbers, and `DRG` has no model field.

**Ruling: `ProjectSettings.sheetNumbering: ncs | simple`, default `simple`.**
A residential drawing set is four to eight pages; failing validation on a naming convention
built for 200-sheet commercial construction documents is exactly the nannying that pushes users
to export a PNG into Word (`critique-domain-realism.md m17`). `simple` numbers sheets `1 of 6`
with a title; `ncs` applies the regex and is the default for projects created from a commercial
starter. `DRG SR-0247` becomes `ProjectInfo.drawingNumber`, optional.

### CR-067 · `sheetFilter` vs `domainFilter`

- **design-ux-schematic.md §4.5:** a sheet filter is "domain set **+ layer set**".
- **design-data-model.md §2.11:** `Sheet.domainFilter: Set<SignalDomain>` only.

**Ruling: `domainFilter` only**, consequent on CR-064. `Sheet` also gains
`lifecycleFilter: Set<LifecycleStatus>` (default all), which is the useful half of the layer
filter and costs one field.

### CR-068 · Symbol pinning is unmodelled

- **design-ux-schematic.md §2.5:** "Every symbol is `auto` or `pinned`. Any manual move sets
  `pinned = true` … **Auto-layout never moves a pinned symbol.**"
- **design-data-model.md §2.11:** `SheetItem{targetId, position, rotationQuarterTurns,
  collapsed, zOrder}` — no `pinned`.

**Ruling: `SheetItem.pinned: bool` ships in v1.** It is one boolean and it is the entire
difference between auto-layout being usable and being feared. The *commands* around it (four
tidy/re-flow scopes, preview-diff, `Tab` variant cycling) defer to v1.3; v1 ships: first layout
is automatic, any manual move pins, `Ctrl+Shift+U` unpins, and a single `Tidy sheet` command
behind a plain confirm.

### CR-069 · Three places a symbol position can live

- `SheetItem.position` (design-data-model.md §2.11).
- `UnplacedPlacement.schematicHint` (§2.4).
- Stacking order exists as **both** `DeviceInstance.zOrder` ("schematic stacking") and
  `SheetItem.zOrder`. Precedence is undefined everywhere.

**Ruling: `SheetItem` owns both, exclusively.** `SheetItem.position` is the only symbol
position; `SheetItem.zOrder` is the only stacking order. `DeviceInstance.zOrder` is deleted.
`StagedPlacement.schematicHint` survives only as a *seed* consumed once when the first
`SheetItem` is created for that device, and is cleared thereafter.

### CR-070 · Unit splitting is unmodelled

- **design-ux-schematic.md §1.2(b):** symbols split into `MTX1:A/:B/:C`; "units may live on
  **different sheets**"; "**no symbol edge ever carries more than 16 pins**"; automatic split by
  domain for multi-sheet sets.
- **design-data-model.md:** one `SheetItem` per device per sheet; no unit letter, no per-unit
  port assignment.

**Ruling: cut from v1.** Bank collapse to vector pins (CR-055) covers the density case without
rendering one device as three bodies, which is a confusion generator for an installer audience
that has never read an FPGA schematic. If it returns in v1.2 the model addition is
`SheetItem.unitKey: String?` + `BankDef.unitKey`, additive, no migration.

### CR-071 · The rear-panel view: printable, and is it the authoring surface

- **design-ux-schematic.md §5.4:** "this is the *installer's* view … it is **what gets printed
  and taped inside the rack door**", and "**the rear panel view is the device builder's output
  surface. You build a device by drawing its rear panel.**"
- **design-ux-device-builder.md §2.6:** "**Against manual x/y authoring as a required step.** It
  is precisely the 'click 16 times' failure the brief is trying to eliminate, multiplied, a
  48-port patch panel would need 48 placements."
- **design-data-model.md §2.11:** `SheetKind` has 11 values and **no rear-panel kind**.
- **design-architecture.md §6.2:** scene layers are `rack_layer / device_layer / wire_layer`, 
  no rear-panel renderer and no schematic-symbol renderer.

**Ruling: three separate answers.**
1. **Authoring:** `design-ux-device-builder.md` wins outright. Ports are authored in the grid;
   panel geometry is auto-laid-out from connector footprints; manual nudging is an optional
   hidden toggle pre-populated from the auto-layout. "You build a device by drawing its rear
   panel" is **rejected** as the authoring model.
2. **Printing:** the rear panel *is* printed in v1, as sheet `T2.02 Rack Elevation — Rear`,
   drawn by the same scene builder with connector fields and landing cable IDs. `SheetKind`
   already has `elevationRear`; nothing new is needed.
3. **Interactive view:** the standalone rear-panel *editor* (leaders, tag pills, per-connector
   navigation, egress heat map) is **v1.1**: the highest-value deferred item in the plan.

`scene/` gains `panel_layer.dart` and `symbol_layer.dart` in v1; the schematic symbol cannot be
a widget-only artifact if it is to print (CR-086).

### CR-072 · Structure device sheet position

- **design-ux-schematic.md §3.2:** "The Structure device is **forced to layer 0, always**,
  rendered as a bank of off-page connector flags on the **left edge**."
- **design-ux-device-builder.md §6.9:** "a Structure **can be pinned to the right edge**
  instead."

**Ruling: `StructureBody.sheetEdge: left | right`, default `left`.** Layer 0 / layer N
accordingly. A utility or service-entrance structure drawn on the opposite side from the
home-run field is a legitimate and common arrangement.

### CR-073 · Multi-sheet: v1 feature or v2 upgrade

- **design-ux-schematic.md §4.5:** ships it, "`Layout → Split to Sheets…`: offers the domain
  partition, plus a **graph min-cut** alternative, plus **by rack**."
- **design-ux-schematic.md §3.4:** lists auto sheet partitioning as **v2 upgrade #6**.
- **design-pdf-export.md §5.4:** net partition with off-sheet connectors is the v1
  recommendation.

**Ruling: one schematic `Sheet` entity in v1; the *exporter* partitions by domain.**
`Sheet` exists in the model from v1 so the format never migrates, and exactly one schematic
sheet is created per project. The PDF exporter emits N domain sheets by filtering that one
sheet's contents. The decisive observation, from `critique-ux-simplicity.md`:

> A cable belongs to exactly one signal domain, therefore a **domain partition produces zero
> cross-sheet connections by construction.**

So **off-sheet connectors and cross-reference resolution are not built in v1**: the entire
expensive apparatus (paired pentagon flags, the second placement pass, min-cut cost functions,
match lines, key plans) disappears. Devices simply repeat across sheets, labelled with their
designator. The **zone grid stays** (it is ~30 lines and the schedule's `REF` column is
genuinely useful for finding a wire on a sheet). Geometric tiling and min-cut partitioning are
cut; `TilingStrategy.geometric` survives only for a single over-tall rack elevation.

### CR-074 · The "SYSTEM OVERVIEW: all devices" sheet

- **design-ux-schematic.md §4.5:** "Sheet 1 SYSTEM OVERVIEW, all devices, collapsed, buses
  only, no individual wires."
- **design-ux-schematic.md §4.6:** its own density table says 0–40 connections is the
  one-sheet-draw-everything band.

**Ruling: deleted.** The arithmetic in `critique-ux-simplicity.md` is correct: twenty symbols
at this document's own sizing rules consume 84% of an ANSI B sheet before a wire is drawn.
There is no legible all-devices sheet at target scale, and shipping one sets an expectation the
product cannot meet. The cover sheet's rack summary strip serves the "what is this system"
purpose honestly.

### CR-075 · `Sheet.viewKind` vs `Sheet.kind`

- **design-data-model.md §1** (ER diagram): `viewKind: elevation | schematic | schedule | cover
  | legend` — 5 values.
- **design-data-model.md §2.11:** `SheetKind kind`, 11 values. I-42 refers to `viewKind`.

**Ruling: one field, `SheetKind kind`, 11 values, plus `exceptions`** for the new `T0.02`
(CR-022). The ER diagram's `viewKind` is deleted and I-42 is rewritten against `kind`.

---

## 1.8 Colour, theme, and typography

### CR-076 · Default theme

- **design-architecture.md §12.3:** "`screenDark` (**the default**: this is a pro tool used in
  equipment rooms and dark UIs are the genre convention)."
- **design-ux-schematic.md §1.7:** the canonical palette section is light-first, every wireframe
  is light, and "The dark theme is for the person editing at 11 pm; **the light theme is the
  deliverable**."

**Ruling: light is the first-run default; dark ships and is one click away.** The moment that
decides whether a user trusts the tool is comparing the screen to the printed sheet, and that
comparison must succeed on first run. The genre-convention argument is real but weaker than a
trust argument (G1). Theme is a UI preference, never persisted in the document.

### CR-077 · "No user-facing export-palette option" vs three of them

- **design-ux-schematic.md §1.7:** "Export **always** renders the light/print palette regardless
  of screen theme, **with no user-facing option to do otherwise**."
- Against: `ProjectSettings.greyscaleSafeExport` (design-data-model.md §2.1), design-ux-
  schematic.md's own "Ship a **Greyscale-safe export toggle**", and design-pdf-export.md §12
  decision 16's greyscale and CMYK exports.

**Ruling: the absolutism is wrong; the rule underneath it survives in a narrower form.**

> **The screen theme never affects the export.**

Export palette is an explicit `ExportSpec.palette: colour | greyscale | cmyk`, defaulting to
`colour`, defaulting to `greyscale` in the Installer preset, and **never inherited from the UI
theme**. `ProjectSettings.greyscaleSafeExport` is **deleted**: it is an export option, not a
property of the design.

### CR-078 · Colour lives on the domain, but is stored on the family

- **design-data-model.md §3.4:** "**Colour is on the `SignalDomain` (7 values), not the family
  (43+).** No palette is CVD-safe past ~9 categories."
- **design-data-model.md §2.10:** `SignalFamilyDef` carries `Rgb color`, `List<int>
  dashPattern`, `int lineWeightPermille`, `String? glyph` — per family, 43+ entries.
- No `SignalDomainDef` exists anywhere.

**Ruling: `SignalDomainDef` is created and owns the visual language.**
`SignalDomainDef{id, displayName, tagPrefix, color, dashPattern, lineWeightPermille, glyph}`,
eight entries (7 domains + structure). `SignalFamilyDef` keeps `domain` (FK), `shortTag`, and
an optional `colorOverride` for the rare deliberate exception. This deletes the 43-entry palette
the same document argues against, and it is what makes the requirement-level colour ruling
(AC-045) implementable.

### CR-079 · Dash pattern has no stated unit

- **design-data-model.md §2.10:** `List<int> dashPattern; // [6,3]`, no unit anywhere.
- **design-ux-schematic.md §1.4:** dashes specified "in U" (grid units).
- **design-pdf-export.md §2.4/§6.2:** `Stroke.dash` in **points**, with "dash period ≥ 1.5 mm
  or it blurs to solid at 300 dpi".

**Ruling: dash patterns are in points (1/72 in), matching the renderer.** Stated once, in
`docs/visual-language.md`. The screen backend divides by the zoom scale so a dash is
zoom-invariant; the PDF backend passes them through. `dashPattern: List<int>` is permille-points
to stay integral in the file.

### CR-080 · Fonts: a named rejection contradicted

- **design-pdf-export.md §9.2:** IBM Plex Sans / Sans Condensed / Mono, SIL OFL 1.1, six TTFs,
  with a worked argument, and explicitly: "**Runner-up considered and rejected: Inter** … and
  **Roboto / Roboto Mono**."
- **design-architecture.md §12.3:** "`Inter-Regular`, `Inter-SemiBold`, `JetBrainsMono-Regular`
  in `apps/rackmate/assets/fonts/`."
- **design-architecture.md §9.4** then asserts goldens use families `RackBody`/`RackMono`, the
  pdf document's aliases with the pdf document's rejected fonts, and no `RackCond`.

**Ruling: IBM Plex.** `RackBody` = Plex Sans (Regular + SemiBold), `RackCond` = Plex Sans
Condensed, `RackMono` = Plex Mono (Regular + Bold), fallback Noto Sans Symbols 2.
`design-pdf-export.md §9.2`'s argument is fully worked, glyph disambiguation (`W014` vs `WO14`
is a real failure mode on a physical label), a true condensed cut worth 12% of schedule column
width, and Greek coverage for `Ω`/`µ`. `design-architecture.md`'s font list is asserted, not
argued. The golden-test assertion is updated to the three families.

### CR-081 · Text-metric source of truth

- **design-pdf-export.md §12 decision 11:** "**`PdfFont.stringMetrics` is the single source of
  truth for text metrics on both backends**, with Skia kerning disabled to match."
- **design-architecture.md §12.3:** bundling the same TTF "is what makes text metrics agree
  between the two", a different and **insufficient** mechanism, since Skia applies GPOS kerning
  and `liga` and dart_pdf applies neither.
- **design-architecture.md §6.6:** `Pt measureText(String s, TextSpec spec)`, each backend
  answers independently, and the return type cannot express a baseline.

**Ruling: `design-pdf-export.md` §6.7 in full, plus the signature fix from
`critique-feasibility.md #4`.**
One injected `TextMeasurer` backed by `PdfFont.stringMetrics`, used by the scene builder and by
**every** backend including the Flutter one. `measureText` returns
`TextMetrics{advanceWidth, ascent, descent, capHeight, xHeight, lineHeight}`, never `Pt`.
`TextStyleSpec` carries an explicit `TextAnchor`, and the anchor resolves in **one shared
pure-Dart helper**, so neither adapter ever guesses a baseline. Flutter sets
`FontFeature.disable('kern')` **and** `FontFeature.disable('liga')`. The parity test asserts on
**baseline Y**, not just the bounding box. This is the ruling that forces CR-083.

### CR-082 · Line weights: screen zoom-invariance

- **design-ux-schematic.md §1.4:** "Screen weights are **zoom-independent** (multiply by
  `1/viewport.scale`)."
- **design-architecture.md §6.4:** "Anything the user *touches or reads* is constant in screen
  pixels; anything representing *physical reality* scales."

**Ruling: both, and the distinction is a field on the stroke.** `Stroke.scaleWithGeometry`
(and `Stroke.hairlineFloor` for print) already exist in `design-pdf-export.md §6.2` and are
adopted. Cable traces, symbol outlines and rack rails **scale**; UI chrome, selection halos and
hit slop are **constant in screen pixels**; sheet furniture uses `hairlineFloor` with a 0.25 pt
print floor. No stroke width is ever emitted as 0.

---

## 1.9 Architecture, packaging, and persistence

### CR-083 · Package layout: four packages or one tree

- **design-architecture.md §1.1/§2.2:** four packages; "`rackmate_export` and `rackmate_ui` are
  **siblings that cannot see each other**. That is deliberate: it is what guarantees the PDF
  path is isolate-safe."
- **design-pdf-export.md §10:** a **single** `lib/` tree with `diagram/backends/{pdf_canvas,
  svg_canvas, bounds_canvas, flutter_canvas}.dart` — the Flutter and PDF backends in one
  directory. Worse, it places `diagram/text.dart # TextMeasurer, PdfFontMeasurer` in the core
  tree, which makes core depend on `package:pdf` and breaks
  `design-architecture.md`'s own `no_flutter_import_test`.

**Ruling: five packages. Four from `design-architecture.md`, plus one that resolves the
text-metric dependency by inversion rather than by contamination.**

```
rackmate_core    pure Dart. no flutter, no dart:ui, NO pdf.
                 model, commands, derived, routing, draw/ (incl. scene builders, hit_test,
                 BoundsCanvas), persistence. Declares abstract TextMeasurer + TextMetrics.
rackmate_text    pure Dart. core + package:pdf (for PdfTtfFont ONLY).
                 ~5 files. The single concrete TextMeasurer.
rackmate_export  pure Dart. core + rackmate_text + package:pdf. PdfDiagramCanvas, sheets,
                 furniture, tables, document assembly. Isolate entry point.
rackmate_ui      flutter. core + rackmate_text. FlutterDiagramCanvas, render objects, widgets.
apps/rackmate    everything + plugins.
```

`rackmate_ui` depending on `rackmate_text` is harmless, `package:pdf` is pure Dart and
isolate-safe. The invariant that actually matters is preserved and mechanically enforced:
**`rackmate_core`, where the scene builder lives, has no concrete font engine and no
`dart:ui`.** It receives a `TextMeasurer` by injection. `no_flutter_import_test` keeps banning
`package:flutter/`, `dart:ui`, and `package:pdf/` in core. `design-pdf-export.md §10`'s folder
convention is the arrangement `design-architecture.md §1.1` correctly predicts "will be violated
within a month by an `Offset` that 'was just easier'".

### CR-084 · Where hit-testing lives

- **design-pdf-export.md §10:** `diagram/hit_test.dart`, in the core tree.
- **design-architecture.md §1.2:** `rackmate_ui/canvas/input/hit_tester.dart`.

**Ruling: both, split by concern.** The *geometric* hit test (`DiagramScene.hits`,
point-to-segment distance, nearest-hit selection) lives in `rackmate_core/draw/hit_test.dart`,
pure, synchronously testable, and reusable by the read-only mobile shell. The *pointer plumbing*
(one query per frame, spatial hash, cursor policy, hover throttle) lives in
`rackmate_ui/canvas/input/`.

### CR-085 · Y-axis flip in the PDF backend

- **design-architecture.md §6.6:** "Use **per-coordinate flipping** (`double _y(double y) => _h
  - y;`) rather than a global `scale(1,-1)` transform."
- **design-pdf-export.md §6.5:** "**Take (b)** [the global flip]. The reason is that the
  interface exposes `rotate()` and `transform()`."

**Ruling: global flip.** `design-architecture.md §6.6` is internally inconsistent: the
`DiagramCanvas` interface it declares three lines earlier contains `void rotate(double
radians)`, and a rotation composed with per-coordinate negation is not a valid transform. The
failure is invisible until someone rotates a label 90° for a vertical rail, at which point it
is diagnosed as "the PDF is wrong" months later. Text is counter-flipped in exactly one method.
The gotcha is recorded normatively: `pw.CustomPaint` pre-translates to the **widget box's**
bottom-left, so the flip height is `size.y`, not the page height.

### CR-086 · Devices are rendered by two code paths and no document notices

- **design-architecture.md D4:** "**A display list (`DiagramScene`) is the single drawing IR.**
  Screen and PDF are two interpreters of it. … Screen and print cannot diverge."
- **design-architecture.md §6.2 and all three UX documents:** "Device faceplates + ports +
  ref-designators | **real widgets**".
- Consequence: the most information-dense content in the deliverable is drawn by a widget tree
  on screen and by a scene builder in print, with no parity mechanism,
  defeating D4 exactly where it matters most. `design-pdf-export.md`'s parity test compares the
  two *canvas backends*, not the two *device renderers*.

**Ruling: one rendering path; widgets remain as an interaction and semantics shell.**
Each device is still a `RenderBox` child of `RenderRackCanvas`, it owns hit-testing, focus,
hover, keyboard handling, and `Semantics`, which is what makes
`design-ux-rack.md §10.2`'s accessibility story true. But its `paint()` **replays that device's
`DiagramScene` fragment through `FlutterDiagramCanvas`**; it does not draw anything itself.
Pixels come from the shared IR; behaviour comes from the widget. Both documents get what they
argued for, D4's guarantee holds where it matters, and the parity test covers faceplates by
construction. This is the single most consequential architectural ruling in this record.

### CR-087 · `measureText` return type

- **design-architecture.md §6.6:** `Pt measureText(String s, TextSpec spec);`
- **design-pdf-export.md §6.4:** `TextMetrics measureText(String text, TextStyleSpec style);`

**Ruling: `TextMetrics`.** Subsumed by CR-081; recorded separately because it is a signature
that will otherwise be copied from the wrong document.

### CR-088 · `RendererCaps`

- **design-pdf-export.md §6.4:** `RendererCaps get caps;` with `nativeDash`, `nativeAlpha`,
  `nativeRoundRect`, `textSelectable`.
- **design-architecture.md §1.2:** mentions it in a file listing and never defines it.

**Ruling: deleted.** The moment a scene builder branches on capabilities there are two code
paths and the abstraction has already leaked. The interface is the common denominator, and
`design-pdf-export.md §6.4`'s own rule ("no gradients, no shadows, no blurs, no blend modes,
no shaders") is promoted from prose to an invariant with a test.

### CR-089 · SVG, bounds canvas: one document only

- **design-pdf-export.md §6.1/§8.3/§10:** `SvgDiagramCanvas` and `BoundsCanvas` as first-class
  backends.
- **design-architecture.md:** neither is mentioned.

**Ruling: `BoundsCanvas` in v1, `SvgDiagramCanvas` in v1.1.** Bounds are not optional: scale-
to-fit, tile counts, zoom-to-fit and the key plan all require the diagram's true extent, and
there is no other way to get it. SVG is one file on top of an architecture that already exists.
`design-architecture.md`'s package tree is amended to list both.

### CR-090 · Model class names in the export document

- **design-pdf-export.md §10:** `RackProject, Device, Port, PhysicalLink, LogicalSignal,
  CableType, Rack, Structure`.
- **design-data-model.md:** `Project, DeviceInstance, Port, Link, Net, Rack, StructureBody`.
- **design-architecture.md:** `RackDocument, RackDevice, Connection, CableType`.

**Ruling: one glossary, in `docs/glossary.md`.** The binding names:
`RackDocument` (the in-memory mutable aggregate) · `ProjectInfo` (title-block metadata on it) ·
`Rack` · `DeviceTemplate` / `TemplateSnapshot` / `TemplateBody` · `DeviceInstance` · `Port` ·
`Link` / `Service` / `Conductor` / `Net` · `Outlet` / `Pathway` / `StructureBody` ·
`Location` · `Circuit` · `Sheet` / `SheetItem` · `Note` · `Finding` / `AckedFinding`.
Deleted: `Connection`, `RackProject`, `Device`, `RackDevice`, `PhysicalLink`, `LogicalSignal`,
`CableType`, `StructureDrop`, `StructureBundle`, `PortGroupDef`.

### CR-091 · `.rackmate` container: plain JSON or zip

- **design-data-model.md §4.1:** "v1 is **plain, pretty-printed, key-sorted UTF-8 JSON** … v2:
  ZipCodec."
- **design-architecture.md §7.1:** "**Not zipped**, not binary."
- **design-ux-device-builder.md §3.1:** "`.rackmate` | A project | **Zip**: `project.json` +
  embedded template snapshots + `assets/`."

**Ruling: plain JSON, because device images are cut from v1.** The zip requirement exists only
to carry the 512 KB per-face `frontImage`/`rearImage` that `design-ux-device-builder.md §1.5`
itself calls a scope trap and says are "not needed for correct output". Images are cut (AC-057),
so the container question resolves to plain JSON, which is also what the confirmed product
decisions specify. `DocumentCodec` ships from commit one and sniffs `PK\x03\x04` on read, so a
v2 zip container is a non-event.

### CR-092 · Envelope shape

- **design-data-model.md §4.2:** root keys (`generator`, `schemaVersion`, `minReaderVersion`,
  `appVersion`, `id`, timestamps, `revision`) with all entity maps nested under `"document"`.
- **design-architecture.md §7.1:** root keys with the project's fields at the root, no wrapper.

**Ruling: `design-data-model.md`'s envelope with the `document` wrapper.** It separates format
metadata from content, makes the magic-key check a single top-level read before any parsing, and
gives migrations one obvious place to stand.

### CR-093 · Migration control flow, and a defect in one of the two snippets

- **design-data-model.md §4.3:** `migrateToCurrent` **throws** (`FormatException`,
  `NewerSchemaException`) and returns `raw..['_openReadOnly'] = true`.
- **design-architecture.md §7.2:** returns `Outcome<JsonMap>` and never throws, "**Expected
  outcomes … are values, not exceptions.**"
- `design-architecture.md`'s snippet is also wrong: `minReader > kSchemaVersion` returns
  `NewerSchema(v, readOnly: **false**)` (backwards, it should refuse) and its trailing
  `if (v > kSchemaVersion)` is unreachable given the loop condition.

**Ruling: `Outcome<T>`, with `design-data-model.md`'s cases and the defect fixed.**
`minReaderVersion > kSchemaVersion` ⇒ `Err(NewerSchema(refuse))`.
`schemaVersion > kSchemaVersion && minReaderVersion <= kSchemaVersion` ⇒
`Ok(doc, openReadOnly: true)` with unknown fields preserved for a subsequent Save As.
Both snippets are deleted in favour of one implementation in
`rackmate_core/persistence/migrations.dart`, specified in `docs/file-format.md`.

### CR-094 · `revision` monotonicity

- **design-data-model.md I-6:** "`Project.revision` is **strictly monotonic** across the life of
  the document and **never decreases** on save." §5.3 uses it as the sync cursor.
- **design-architecture.md §7.4:** undo "**restore**[s] the revision they were recorded at
  rather than incrementing it … This means `revision` is **not strictly monotonic**."

**Ruling: two counters, both correct, neither overloaded.**
`RackDocument.sequence`, strictly monotonic, incremented on **every** committed transaction
*and* on every undo and redo (an undo is a change). Persisted. This is the sync cursor and I-6
is rewritten to name it.
`RackDocument.stateId`, in-memory only, non-monotonic; each undo entry records the stateId
before and after, and `isDirty == stateId != savedStateId`. This preserves
`design-architecture.md`'s correct UX (undoing back to the save point marks the document clean)
without breaking the invariant the sync design rests on.

### CR-095 · Tombstones and `EntityMeta` are absent from the architecture

- **design-data-model.md §5.3/§5.4:** every entity carries `EntityMeta`; tombstones are "the one
  thing that genuinely cannot be retrofitted", "**Do it now or accept that sync is a
  rewrite.**"
- **design-architecture.md:** tombstones are never mentioned; `EntityMeta` is only implied by a
  `d.touch(doc.clock.nowUtc(), doc.actor)` call and never defined, listed, or persisted.

**Ruling: both ship in v1, on the conflict-unit set only.** `design-architecture.md`'s omission
is an oversight, not a position (G5). But per `critique-feasibility.md #3`, `EntityMeta` is
carried **only by entities that are sync conflict units**: `RackDocument`, `Location`, `Rack`,
`DeviceInstance`, `Link`, `Net`, `Circuit`, `Sheet`, `Note`, `StructureBody`, `Outlet`,
`Pathway`, `AckedFinding`, `RevisionEntry`. It is **not** carried by `Port`, `Conductor`,
`Service`, `SheetItem`, or `ZeroUChannel`, which are sub-objects of a conflict unit and whose
per-entity LWW metadata is dead weight by the design's own conflict model. Those carry a bare
`Map<String, Object?> unknown` for forward compatibility and nothing else.

### CR-096 · Crash reports contradict the redaction policy, inside one document

- **design-architecture.md §11.4:** "log entity **UUIDs**, never device names, client names,
  project addresses, or file paths … The diagnostics bundle includes … **never document
  content.**"
- **design-architecture.md §7.5:** "**Recovery files are also the crash-report attachment
  (§11).**"

**Ruling: recovery files are never attached automatically.** A recovery file is a complete
project document containing the client's name and site address. The diagnostics bundle carries
versions, document *statistics*, the last 200 log records, and epoch/sequence values. The crash
dialog offers an explicit, default-off **"Attach the project file"** checkbox whose label reads:
*"This includes your client's name and site address."*

### CR-097 · Display units: app preference or project setting

- **design-architecture.md §12.2:** "**Display units are a user preference independent of
  locale.**"
- **design-ux-device-builder.md §1.3:** "Unit follows the **app-level preference**."
- **design-data-model.md §2.1:** `ProjectSettings.displayUnits`, persisted in the document.

**Ruling: the project wins when set; the user preference is a default and a session
override.** `ProjectSettings.displayUnits` is authoritative, a US-spec commercial job opened on
a German integrator's laptop must still read in inches, which is the deciding case and the one
CI firms actually hit. The user preference supplies the value for *new* projects. A per-session
display toggle exists and does not modify the document or mark it dirty.

### CR-098 · The `.history/` folder implies a project directory

- **design-ux-device-builder.md §5.3:** "a pre-update snapshot of `project.json` is written to
  the project's **`.history/` folder**."
- **design-architecture.md §7.3/§7.5:** single file, `.bak` sibling, recovery snapshots in
  application support.

**Ruling: deleted.** The confirmed product decision is a **local single-file `.rackmate`
project**. Pre-update snapshots go to
`getApplicationSupportDirectory()/snapshots/<docUuid>/<sequence>.rackmate`, alongside recovery
snapshots, pruned to the last 10. The user's folder gains nothing but the file they asked for
and one `.bak`.

### CR-099 · Isolate API

- **design-architecture.md §1.2/§8:** `build_document.dart # top-level fn; the **Isolate.run**
  entry point`.
- **design-pdf-export.md §12 decision 13:** "progress via captured `SendPort`; **cancel via
  `Isolate.kill`**": neither of which `Isolate.run` supports.

**Ruling: `Isolate.spawn` + a `SendPort` pair for export.** `Isolate.run` is used only where
neither progress nor cancellation is wanted, autosave serialization. The comment in
`design-architecture.md §1.2` is corrected. On web (not a v1 target)
`kIsWeb ? buildDocument(req) : spawn(...)` is a one-line guard.

### CR-100 · PDF preview mechanism, and whether OS print ships

- **design-pdf-export.md §12 decision 14:** "Primary preview uses the **screen** renderer, so
  the core flow has zero native dependencies."
- **design-architecture.md §8.4:** `printing ^5.15.0`, "`PdfPreview` for in-app preview", with
  the pdfium build-time-download risk noted in the same document's risk register.
- Neither document states whether the OS print dialog ships in v1; `Ctrl+P` means Export in
  `design-ux-rack.md` and Command Palette in `design-ux-schematic.md`.

**Ruling: screen-renderer preview is primary and has no native dependency.**
`PdfPreview`/pdfium sits behind an explicit **"Verify output"** button, and the pdfium binaries
are **vendored into the repo** rather than downloaded at build time (a network-fetched binary in
a signed release is a supply-chain and reproducibility problem, not just a CI problem).
**v1 ships Export-to-PDF plus "Open in system viewer"; the OS print dialog is v1.1**, pending a
spike confirming that `Printing.layoutPdf` on Windows does not itself require the fetched
pdfium. `Ctrl+P` is the export dialog everywhere (CR-101).

---

## 1.10 Interaction

### CR-101 · The keymap has ~18 collisions and no arbitration document

`design-ux-rack.md §8` defines ~90 bindings; `design-ux-schematic.md §7` defines ~80. They
collide on at least 16 keys, and `design-ux-rack.md` binds `Shift+F` to two different actions
within one table.

| Key | design-ux-rack.md | design-ux-schematic.md |
|---|---|---|
| `Ctrl+P` | Export PDF | Command palette |
| `Ctrl+K` | Command palette | Add to bundle |
| `Ctrl+F` | Focus mode on rack | Search |
| `F` | Flip face | Focus |
| `Shift+F` | Both-faces view *and* move to opposite face | Isolate |
| `Ctrl+B` | Fill gaps with blanks | Create bus |
| `Ctrl+R` | Renumber dialog | Reverse direction |
| `Ctrl+Shift+R` | Auto-arrange | Clear manual route |
| `Ctrl+L` | Lock position | Wire ↔ net label |
| `Ctrl+0/1/9` | Fit all / 100% / fit rack | Fit sheet / Rack view / fit selection |
| `G` | Toggle 0U gutters | Toggle grid |
| `L` | Cycle label mode | Tidy selection |
| `W` | Toggle warning badges | Begin wire |

**Ruling: one arbitrated keymap in `docs/keymap.md`, generated from a single `Intent`
registry** so the table cannot drift from the code again. Three arbitration principles:
**(a)** view-switching and global-command keys win over every view-local meaning;
**(b)** a key means the same thing in every view or it means nothing;
**(c)** unmodified single letters are view-local tools and must not collide between views that
share the canvas.

The binding resolutions:

| Key | Ruling |
|---|---|
| `Ctrl+1..4` | switch view: Rack · Schematic · Rear · Schedule, global |
| `Ctrl+0` / `Ctrl+9` / `Ctrl+Alt+0` | fit content · fit selection · zoom 100%: every view |
| `Ctrl+P` | Export / Print dialog: every view |
| `Ctrl+E` | Export other formats… |
| `Ctrl+K` | Command palette: every view |
| `Ctrl+F` / `Ctrl+G` | Find · Go to designator: every view |
| `F` / `Shift+F` | Focus · Isolate: schematic and rear only; **unbound in rack** |
| `Ctrl+Shift+F` | Cycle elevation face (Front → Rear → Both), rack only |
| `Ctrl+R` | Renumber…: every view, scoped to the selection kind |
| `Ctrl+L` | Lock / unlock: every view (position in rack, route in schematic) |
| `G` / `L` | Toggle grid · Cycle label mode: every view |
| `W` | Begin wire from the selected port: schematic; warning badges move to `Ctrl+Shift+W` |
| `Ctrl+B` | Fill gaps with blanks: rack (bus creation defers with buses) |
| `Ctrl+Shift+R` | Reverse link direction: schematic (auto-arrange defers) |
| `Ctrl+Alt+3` | Outline panel: global |
| `T` | unbound in v1 (Trace defers) |

"Focus mode on this rack" is deleted as a distinct command; it is fit-selection with a rack
selected, which is `Ctrl+9`. The total shipped surface is ~40 bindings, not 170.

### CR-102 · Marquee button

- **design-ux-rack.md §3.6:** "Marquee on empty canvas: press-drag", left button.
- **design-ux-schematic.md §2.4:** "**Right-drag** | marquee (no modifier needed, doesn't
  collide with pan)", while §2.1 also binds right-click to "cancel current operation".

**Ruling: left-drag on empty canvas, in every view.** Right-drag is reserved for the context
menu, which is a platform expectation on desktop and which `design-ux-schematic.md` itself
double-books. The CAD window/cross convention is kept in both views: left→right selects fully
contained (solid band, `WINDOW`), right→left selects intersecting (dashed band, `CROSS`).

### CR-103 · Three thresholds for closely related collapse behaviours

- Vector-pin collapse at **≥ 4** homogeneous ports (design-ux-schematic.md §1.2c).
- Unit split at **17** pins on an edge (§1.2b).
- Bank auto-collapse in the symbol preview at **> 8** (design-ux-device-builder.md §2.7).

**Ruling: one constant, `kBankCollapseThreshold = 8`.** Any bank of ≥ 2 ports may be collapsed
by the user at any time; banks over 8 auto-collapse on first layout and in the symbol preview.
The 17-pin unit split is deleted with unit splitting (CR-070).

### CR-104 · Two places to add a device, with different consequences

- **design-ux-rack.md §1.1:** a left-hand PALETTE that places into a rack.
- **design-ux-schematic.md §8.1:** a separate LIBRARY panel with `+ New device`, which must
  produce a device with no rack position.
- Neither document says which you get, or reconciles `RailPlacement` with `StagedPlacement`.

**Ruling: one palette widget, one insert command, placement decided by the drop target.**
`Insert device…` (`Ctrl+Alt+I`, `/` search, double-click an empty U, or drag) exists in every
view. Dropping on a rack → `RailPlacement`. Dropping on the schematic canvas, or inserting with
no rack focused → `StagedPlacement` plus a `SheetItem` at the drop point. The schematic's
`+ New device` button is deleted; its LIBRARY panel is the same palette widget with the same
model. This closes the "where do I add a device" cliff that
`critique-ux-simplicity.md` identifies at the 5:30 mark of a first session.

### CR-105 · Wiring surface: the rack editor has none

- **design-ux-rack.md:** no wiring affordance anywhere; the user must discover a second view.
- **design-ux-schematic.md §5.4:** "the rear panel says **which physical jack to plug into** …
  this is what gets printed and taped inside the rack door."
- **design-data-model.md:** silent.

**Ruling: connections are created in the schematic in v1, and the rack editor signposts it.**
Two concrete mitigations, both cheap:
(a) a device with unconnected ports shows a port-count chip (`🔗 0/12`) in the elevation, and
clicking it switches to the schematic with that device selected;
(b) the **schedule table is the second tab in the app**, reachable from an empty project and
filling live as connections are made, so the deliverable is visible from minute one rather
than discovered at export (G1, and `critique-ux-simplicity.md`'s third prioritisation fix).
Editing endpoints from the schedule and from the rear-panel view lands in v1.1.

### CR-106 · Undo scope outside the document

- **design-architecture.md §4:** the command stack is scoped to `RackDocument`.
- **design-ux-device-builder.md §2.5:** asserts "Delete | **Undoable**" in the port grid, and
  §6.5 gives the drop table the same operation set, both outside `RackDocument`.

**Ruling: one `Command` machinery, three stacks.** `UndoStack` is generic over an aggregate.
The device builder owns a stack scoped to the template being edited (discarded on close without
save); the Structure editor's edits are ordinary document commands and use the document stack;
settings and library operations are **not** undoable and must therefore be individually
confirmable or trivially reversible. Stated once so nobody builds a second mechanism.

---

## 1.11 The Structure device

### CR-107 · One home run is modelled twice

- **design-data-model.md §3.8:** "Termination into the rack is a normal `Link`.
  `StructureDrop.terminatesAtPortId` is a **denormalized convenience cache**; the source of
  truth is a Link."
- **design-data-model.md §2.8/§2.9:** `StructureDrop` carries `media`, `jacket`, `gaugeAwg`,
  `actualLength`, `terminationRack`, `terminationField`, `status`, `test`, `reelId`,
  `polarity`, and `Link` independently carries `media`, `jacket`, `gaugeAwg`,
  `calculatedLength`, `cutLength`, `slackPercent`, `status`, `test`, `installedBy`,
  `terminatedAt`.

**Ruling: `StructureDrop` is deleted; a home run *is* a `Link`.** Fully accepted from
`critique-domain-realism.md B2`, see AC-017 for the replacement shape. One cable, one row, one
length, one certificate, one status.

### CR-108 · TIA-570-D grades as the primary specification axis

- **design-data-model.md §2.8/§3.8:** `StructureGrade{grade1, grade2, grade3, custom}`,
  `ProjectSettings.defaultBundleGrade`, and "*Add outlet: Grade 2*" as **the reason bundles
  exist**.
- **design-ux-device-builder.md §6:** the Structure editor is a room × media matrix. The word
  "grade" never appears. `ProjectSettings.defaultBundleGrade` has no UI.

**Ruling: user-defined outlet templates are first-class; grades are presets and a tag.**
`OutletTemplate{id, name, drops: [{media, service, count}]}` seeded with **TV location · AP ·
Keypad · Ceiling speaker pair · Camera · Data-only**, *and* with TIA-570-D Grade 1/2/3.
`StructureGrade` as an enum is deleted; `Outlet.tia570Grade: String?` remains as a standards tag
for specs that cite it. `critique-domain-realism.md m23` is right that essentially no CI
integrator speaks in grades, and the matrix-entry screen already got this right, the model had
it backwards.

### CR-109 · Conduit is a media type that creates a connectable port

- **design-ux-device-builder.md §6.3:** "Cond" is a media column in the entry matrix, creating a
  drop like any other.
- **design-data-model.md §3.8:** every drop is 1:1 with a `Port` on the Structure device.
- An empty conduit is not a cable and cannot be connected to anything.

**Ruling: `MediaTypeDef.isPathwayOnly: bool`.** A pathway-only entry creates a `Pathway`
(CR-016), not a Link and not a Port. It appears in the drop table and on the pull sheet, you
still pull the smurf tube and it still costs money, and it never appears in the netlist.

### CR-110 · The Structure device is in the rack palette but cannot be placed

- **design-ux-rack.md §1.1:** the palette contains "▾ Structure / ▪ Rough-in".
- **design-data-model.md I-24:** a structure device always has `UnplacedPlacement`.
- The drag interaction is undefined in every document.

**Ruling: removed from the rack palette.** A `StructureBody` is created from
`Project ▸ Structured wiring…`, or implicitly on first use of the Structure editor. It renders
in the schematic as an edge bank of flags (CR-072) and in the rack elevation not at all.

### CR-111 · `bundleStatus`: minimum or maximum

- **design-data-model.md §2.8:** "`RoughInStatus bundleStatus; // derived-**max** of member drop
  statuses`".
- **design-data-model.md I-39:** "derived as the **minimum** status across its drops".

**Ruling: minimum.** An outlet is as complete as its least-complete run; a max would report an
outlet "tested" when three of its four cables are still coiled. Also: it is **derived and not
serialized** (CR-119).

### CR-112 · The Structure device is where the location tree lives

- **design-ux-device-builder.md §6.2:** "**This tree is the project's canonical location
  vocabulary**": and it is reachable only from the Structure editor.
- **design-ux-rack.md §7.5:** racks and devices carry a `Location` and the editor shows a flat
  combobox.

**Ruling: `Project ▸ Locations…` is a top-level panel.** Consequent on CR-047. A project with
racks and no Structure device must still be able to say which room a rack is in; today it
cannot.

### CR-113 · Multiple Structure instances

- **design-ux-device-builder.md §6.9:** "Explicitly supported and encouraged", each with its own
  name, prefix, location scope, and label template.
- **design-data-model.md §3.8:** agrees.
- **design-ux-schematic.md §3.2:** forces "the Structure device" (singular) to layer 0.

**Ruling: multiple instances ship, and layering handles all of them.** Every `left`-edge
Structure goes to layer 0, every `right`-edge one to layer N (CR-072). Drop `fieldLabel`
uniqueness is **project-wide across all Structures**, per `design-ux-device-builder.md §6.9`,
labels get printed on physical cable and must not collide across panels.

**BUILT at M3-E/3 (#158), 2026-08-10, and the audit is the more useful half.** Five of the
seven things a two-body document could have broken were already correct, each for a stated
reason rather than by luck: the Pull Sheet's sort has no Structure term (an installer walks
the building, not the panel, and the far end already names which panel a run lands in); the
footage rollup is project-wide (one purchase order covers the job); the Locations tree is
untouched (a room belongs to the building); layering is per device, so N bodies land on N
anchors; and `fieldLabel` uniqueness was already scanned over `doc.links` rather than over
one body's drops, which is this ruling's own clause holding without anybody checking.

**Two were not.** `buildStructureTable` merges every body when handed no id, and the editor
passed none **forever**, so two panels' drops arrived in one undifferentiated table while the
header said *"2 Structure devices"*. And three planners refused above one body, correctly,
since filing sixty drops on the wrong panel puts them on the wrong sheet, but **nothing could
NAME a body**, so a two-panel project could never create an outlet or a drop again. Each of
those refusals cited #158 by number in its own message, which is why the task cost minutes to
scope.

**What shipped:** a header dropdown, hidden on a one-panel project; `structureBodyId` threaded
through `planDropLine` and `planOutletFromTemplate` (`planMatrixCell` already had it) and
carried on the edit payloads rather than captured when an action is built; and
`structureBodiesInOrder`, a **derived** total order by the paired device's designator ending in
the body id. **`StructureBody` gains no `order` field**: adding one would rewrite the file for
every existing document to serve a dropdown.

---

## 1.12 Residual internal contradictions

### CR-114 · `Extent` exists for one field

- **design-data-model.md §2.0:** `sealed class Extent { Known | Unknown }` "for
  'unknown/varies' fields".
- Used once, on `StructureDrop.calculatedLength`, while `Link.calculatedLength` is a plain
  `Len?`.

**Ruling: deleted. `null` means unknown, everywhere.** One mechanism, and the obligation moves
to the UI: a rollup must **report its unknowns**, *"Total weight 148 lb · 3 devices have no
weight"*, rather than silently treating null as zero (G4). This is
`critique-ux-simplicity.md`'s "missing data the user can see beats fabricated data the user
can't", and it is binding.

### CR-115 · Derived caches are persisted

- **design-data-model.md §5.6:** names `portIds`, `bundleStatus`, `templateUpdateAvailable` as
  "rebuildable caches, flagged as such"; I-11 says `portIds` is "rebuilt on load rather than
  trusted".
- **design-data-model.md §4.5:** all three are written into the example file.

**Ruling: derived values are never serialized.** `portIds`, `bundleStatus`,
`templateUpdateAvailable`, `Link.dominantSignalFamily`, and the deleted
`StructureDrop.terminatesAtPortId` are in-memory only. A cache in the file bloats the git diff
that plain JSON exists to keep readable, and creates a second source of truth that will
eventually disagree with the first.

### CR-116 · The worked JSON example violates the ID invariant

- **design-data-model.md I-2:** "Every entity ID is a valid **UUID v7**."
- **design-data-model.md §4.5:** every ID in the example is `"rk-1"`, `"dev-mtx1"`,
  `"p-str1-d1"`, `"sh-t201"`.

**Ruling: normative examples use real UUIDv7s.** The example is the artifact people copy. A
short-ID example may appear once, in a tutorial, explicitly banner-marked non-normative.

### CR-117 · Round-trip invariant tests the wrong property

- **design-data-model.md I-16:** `read(write(read(x))) == read(x)`, semantic round-trip.
- The stated justification for plain JSON is git-diffability and honest dirty-tracking, which
  require `write(read(bytes)) == bytes`, **byte** round-trip.

**Ruling: assert the byte round-trip.** It constrains key ordering (including inside nested
`unknown` maps), timestamp precision, and integer formatting, all of which are exactly the
things that produce spurious diffs and a lying dirty flag. Accepted from
`critique-feasibility.md #24`. I-16 is rewritten.

### CR-118 · Elevation scale: true scale or fit-to-page

Never stated in any document, while `design-pdf-export.md §4.2` prints a scale ratio in the
title block and warns "Never print `1:8` on a sheet drawn at 1:8.34; someone will scale off
it."

**Ruling: fit-to-page, snapped to a standard ratio when within 2%, otherwise `NTS`.**
`design-pdf-export.md §4.2`'s algorithm is adopted verbatim: snap to
`1:{1,2,4,8,10,16,20,24,32,48,64,96}` when `|k − 1/n| < 2%`, print `NTS` otherwise. A ruler
therefore works whenever the block states a ratio and the block is honest when it cannot.

### CR-119 · Multi-document: tabs or single window

- **design-architecture.md §8.6:** "Ship single-window with **in-app document tabs**."
- **design-architecture.md §3.2:** one `ProviderScope` per open document.
- No UX document shows a tab strip, and no document specifies `Ctrl+N`/`Ctrl+O` behaviour with a
  dirty document open.

**Ruling: v1 is single-document, single-window.** `Ctrl+N` and `Ctrl+O` prompt Save / Don't
Save / Cancel and then replace. The per-document `ProviderScope` stays exactly as designed; it
costs nothing now and makes tabs (v1.2) and multi-window (whenever Flutter ships it) mechanical
rather than a rewrite. Tabs without a design are not a feature.

### CR-120 · The two build orders conflict

- **design-architecture.md §13:** PDF export is step 10 of 12.
- **design-pdf-export.md §11:** steps 1–5 are "roughly a week" and should be front-loaded, and
  its step 3 (backend parity) depends on `design-architecture.md`'s step 6 (the display list).

**Ruling: `design-pdf-export.md`'s spikes move to the first week; the export *feature* stays
late.** The five API verification spikes plus the sixth from `critique-feasibility.md #18` cost
a day and de-risk the largest single dependency in the project; running them in week one is
free. The `DiagramCanvas` + display list + **both** backends + the parity test land together,
early, because retrofitting parity is the expensive failure. Sheet furniture, pagination,
partitioning and the export dialog stay in their own milestone. Neither document's ordering
survives intact; the reconciled sequence is Part 2's milestone plan.

---

### CR-121 · Per-run jacket colour: one colour, or the convention plus the exception

- **docs/01-domain.md and docs/08-pdf-export.md** both listed "jacket colour" as a Pull Sheet
  extra column, and nothing in the model could populate it: `Link.jacket` is the NEC fire
  rating and `Conductor.colorCode` is the pair colour inside the sheath. Neither is the colour
  of the cable in the wall.
- **The requesting integrator (2026-07)** asked for per-run colour to carry meaning, yellow
  general data, blue control, green A/V, grey WAP, white camera/bridge/satellite, red external
  and security/fire, black direct burial and patch, and then refined it: a run is sometimes
  pulled in the *wrong* colour (ran out; prewire mistake), and that must be recordable
  "WHILE KEEPING THE KEYSTONES FOLLOWING THE NORMAL CONVENTION".

**Ruling: `Link` stores TWO nullable `JacketColorId`s, and the derived answers are computed,
never stored.** `jacketColorId` is *what the run is* (a reference to a named convention entry;
this is what a keystone follows). `jacketColorPulledId` is *what was actually pulled*, set only
when it differs from the convention, null is the normal case. Collapsing them into one stored
colour cannot express the user's sentence at all, and storing the resolved answers would create
the second copy of one physical fact that CR-107 deleted `StructureDrop` for.

Four consequences, each load-bearing:

1. **The keystone follows the convention, alone.** `keystoneColorId => conventionId`; the
   expression does not mention the override. That syntactic independence *is* the design, the
   keystone is chosen weeks after the pull, out of the same box as every other control drop's,
   and is routinely correct while the cable is not.
2. **The exception is visible, never hidden.** A wrong-colour pull prints as two tokens
   (`BLU→YEL`), never one. `isException` is a pure function of the `Link` plus the map, so
   there is no flag anyone can forget to set. *Documentation of imperfections beats no
   documentation at all.*
3. **Colour is a NAMED ENTRY, not a bare `Rgb`.** The Installer export preset defaults to
   greyscale, so a hex triple degrades to an indistinguishable grey, and was already
   indistinguishable for the ~8 % of installers with a CVD. `abbr` survives greyscale, a
   photocopy and a CVD. It also means one edit repaints a whole job, and an imported pull list's
   `Colour` column (which carries words, not hex) has somewhere to land.
4. **The convention is DATA, seeded per document, never hardcoded.** The seven above are ONE
   shop's convention; there is no industry standard for category-cable jacket colour, and
   TIA-606 standardises *administration label* colours, which is a different fact and must never
   be cited as support. A project may delete all seven and author its own.

**This does NOT touch the hue channel.** Jacket colour reaches the schedule, the label and the
keystone, never a drawn wire, see CR-078 and PAL-1. The two are unrelated facts, and coupling
them would substitute a shop's unvalidated reel colours for the Okabe–Ito palette chosen because
it survives a CVD. `jacket_colour_is_not_hue_test.dart` enforces this by source scan over the
drawing layer.

**Format impact: none.** The override encodes with `putIfNotNull`, so a document that has never
recorded a wrong-colour pull is byte-identical to before the key existed. `kSchemaVersion` stays
2 and `kMinReaderVersion` stays 2, an additive *optional* key is the opposite of v2's breaking
omission of previously mandatory keys; an older reader never looks at it, so it neither throws
nor degrades. No migration entry changes.

**The four starter assets DO change, deliberately, and this record used to claim otherwise.** The
sentence above originally ended "No starter asset and no migration entry changes", which was false
in its own changeset: `StarterAuthor.newDocument` seeds the convention at document creation exactly
as `buildBlankDocument` does, so all four assets gained the seven-entry block, and `whole_house`
additionally gained fifteen authored `jacketColorId` values on its Cat6 home runs. That is kept
rather than reverted. A starter is a document THIS BUILD authors; a starter with no convention
would be the only document the app produces without one, and AC-052 makes the starters do triple
duty as goldens, perf fixtures and screenshot source, a golden with an empty convention cannot
catch a codec regression in the block, and a screenshot source shows the empty state forever. The
fifteen colours are assigned from each run's PURPOSE, never from its media (five distinct colours
across one media type), and `jc.red`/`jc.black` are stocked and pulled by nothing, which is the
third state the format exists to express, exercised on shipped bytes. `dart run
tool/generate_starters.dart --check` reports all four unchanged, so the assets are exactly what the
checked-in generator produces; CR-117 (`write(read(bytes)) == bytes`) is a property of a STORED
document under round trip, which this does not touch.

> **Known limitation, flagged not fixed:** `Link` has no `unknown` passthrough map (`EntityMeta`,
> `Port`, `SheetItem` and `RackDocument` all have one), so an older build that opens a newer file
> and re-saves silently drops the override. Bumping the schema version would not help — it would
> make the older build refuse the file outright, which is worse. Only adding `Link.unknown` fixes
> it, and that changes every `Link`'s bytes. Already true of `jacketColorId`; the override adds
> no new class of loss.

> **Deliberately out of scope:** the keystone cannot record its *own* exception. A shop that
> installs the wrong keystone colour has nowhere to put that. This matches the user's stated
> scope, and the escape hatch is cheap and identical in shape — a third nullable
> `JacketColorId` on the same object — so it is not pre-built.

---

### Section 1 summary: the ten rulings with the widest blast radius

| # | Ruling | Consequence if it had gone the other way |
|---|---|---|
| CR-001 | `Len` = int64 nanometres | Rounding in every dimensioned print; a format migration touching every entity |
| CR-008/010 | `Link` → `Service` → `Conductor` + stored `Net` | No multi-service cables, no cable schedule, or no bus semantics |
| CR-017 | The gesture may hesitate; the document may not lie | Cannot document an existing miswired system, the remediation market |
| CR-022 | `blockExportOnErrors` deleted; exceptions sheet added | A heuristic holds the deliverable hostage; users export a PNG into Word |
| CR-025 | RU index 1-based, bottom origin | The elevation says U7 and the label says U8 |
| CR-051 | `PortKey` + `renamedFrom` is the migration join | Template revisions rewire the project, or renames become rewires |
| CR-073 | One sheet in v1; the exporter partitions by domain | The first PDF is gated behind the entire multi-sheet subsystem |
| CR-081 | One `TextMeasurer`, `PdfFont.stringMetrics`, baseline-asserted parity | A PDF that is subtly and unfixably different from the preview |
| CR-083 | Five packages; `rackmate_text` inverts the metrics dependency | Either core depends on `package:pdf`, or screen and print measure differently |
| CR-086 | Devices paint by replaying their scene fragment | D4's parity guarantee is void for the densest content in the deliverable |

---

# 2. Accepted critiques

Every blocker and major from the four critique documents is answered here or in §3. Nothing is
silently dropped. Each entry states the finding, the ruling, and the concrete design change.

Two framing notes:

- Where a critique's *finding* is accepted but its *proposed remedy* differs from mine, the
  finding is accepted here and the remedy difference is stated in the ruling. That is not a
  partial rejection; the finding is what matters.
- Several accepted findings imply the same code change. Cross-references are given rather than
  repeating the change.

---

## 2.1 From `critique-feasibility.md`

### AC-001 · SEV-1 #1: three incompatible base units, one with an arithmetic error

**Accepted in full**, including the demolition of `design-architecture.md` D3 on its own stated
criterion: hundredths-mm cannot express the 1/32-in EIA clearance the design itself renders.

**Change:** CR-001, CR-002, CR-003, CR-004. Plus: `Len`, `Mass`, `Money`, `Permille` and the
schematic `Pt` are defined exactly once in `rackmate_core/units/`, and every design document is
edited to reference that definition rather than restate it. Two tests are written before any
other code (exact 1/32-in clearance, and zero accumulated error across a 45U stack) because
they are the two cases that discriminate between the candidate units.

### AC-002 · SEV-1 #2a: Y-flip

**Accepted.** `design-architecture.md §6.6` is internally inconsistent with the interface it
declares three lines earlier. **Change:** CR-085.

### AC-003 · SEV-1 #2b: two different routers were specified

**Accepted**, including the diagnosis: these are not two implementations of one router, they are
two routers. **Change:** CR-013. `ObstacleField`, `RouteCache` and "obstacle-aware" are deleted
from `design-architecture.md §1.2/§5.2`; the incremental-invalidation section goes with them.
The tier-2 derived-cache slot is not left empty; it is reassigned to the per-domain scene
sub-pictures of AC-008.

### AC-004 · SEV-1 #2c: revision monotonicity

**Accepted.** Both documents are right about different counters. **Change:** CR-094.

### AC-005 · SEV-1 #2d: Structure placement vs the Staging Bin

**Accepted**, including the observation that the Staging Bin is a real product requirement with
no representation in the model. **Change:** CR-031, CR-032.

### AC-006 · SEV-1 #3: the file-size budget is off by 3–6×, invalidating the plain-JSON argument

**Accepted, with a stronger remedy than proposed.** The arithmetic is correct: at the design's
own target of 2,000 ports the port map alone is ~1 MB pretty-printed, and the catalog's 48-port
patch panel (96 ports on one device) makes the tail worse, not better. The knock-on to
`design-architecture.md §7.3`'s "~15 ms at 500 KB" main-isolate save is real.

**Change:**
1. **Lazy port materialisation.** A `Port` entity is serialized **only if it carries project
   state**: a conductor, an override, a pinned designator, network config, a bus address, a
   reserve flag, or an orphan flag. Everything else is reconstructed at load by key-join against
   the template snapshot. Typical file drops ~70%.
2. **Deterministic port IDs.** For template-derived ports, `Port.id` is
   `uuidv5(deviceId, portKey)` rather than random v7, so materialisation is **idempotent across
   peers**: two machines that independently connect the same port produce the same ID and the
   sync design survives. (This is the piece the critique does not supply, and without it lazy
   materialisation would break the cloud-ready decision.)
3. **Reserve allocation** survives as `DeviceInstance.designatorWatermark`, not as thousands of
   placeholder entities.
4. **`EntityMeta` off `Port`** and off every other sub-object of a conflict unit, CR-095.
5. **Plain pretty JSON is retained**, re-justified against the corrected ~600 KB figure, and
   **explicit save moves to `Isolate.run`** alongside autosave.

### AC-007 · SEV-1 #4: `measureText` returns `Pt`; the abstraction leaks at the baseline

**Accepted in full**, including the critique's important caveat that the shared-metrics approach
*does* work and is under-specified at exactly one point. **Change:** CR-081, CR-087. The parity
test asserts on **baseline Y**; `TextSpec` carries an explicit `TextAnchor` resolved in one
shared helper; both `kern` and `liga` are disabled on the Flutter side; a kerning-heavy fixture
(`"AV Wa To Ty"`) is asserted to agree within 0.5%.

### AC-008 · SEV-2 #8: the 8 ms commit budget under-counts the wire-layer rebuild

**Accepted.** The budget counts one stroked polyline per wire; the actual per-run cost is
polyline + dash synthesis + arrowhead + **two tag pills** + junction dots + hop arcs, roughly
8–10 ops, so ~10,000 ops rebuilt on commit, not 1,000.

**Change:** L3a splits into **eight per-domain sub-pictures**, so an edit to one HDMI run
rebuilds ~1,200 ops and seven pictures replay untouched (nearly free, since paths are already
batched by colour class). Tag pills move to their own LOD-gated picture. The commit budget is
re-baselined to **≤ 16 ms** with ≤ 8 ms reserved for non-paint terms; nothing in the product
requires sub-frame commits. The perf harness measures **op count per layer** as the CI signal,
op count is stable across runners, wall time is not.

### AC-009 · SEV-2 #7: the label cache is ~4× too small and the label count ~5× too low

**Accepted.** 200 devices × 20 ports × 2 runs (designator + label) + headers + 2,000 pill runs
≈ 10,000 text runs against a 2,000-entry LRU, and a thrashing LRU is worse than none, because
eviction disposes a native `ui.Paragraph` in the paint path.

**Change:** cache sized at **12,000** entries and keyed on `(text, styleId, quantisedScale)`;
the critique's second observation is the better fix and is adopted, port labels are drawn from
a small set of repeated strings, so *distinct* keys collapse to low thousands even at the hard
cap. The LOD gate becomes a **test**, not an intention: at fit-to-sheet zoom the assertion is
zero text runs laid out.

### AC-010 · SEV-2 #9: multi-sheet is a v2 stack sitting on the critical path to the first PDF

**Accepted**, and reinforced by `critique-ux-simplicity.md`'s observation that a domain
partition has zero cross-sheet connections by construction. **Change:** CR-073, CR-074. The
first end-to-end PDF requires no `SheetItem` cross-sheet state, no off-sheet connector pairs, no
unit splitting, and no min-cut.

### AC-011 · SEV-2 #6: rules-as-data cannot express the rules in the catalogue

**Accepted.** `NET-003` (reachability), `NET-004` (path enumeration with a per-hop predicate),
`ELE-004` (parallel impedance), `ELE-005`/`ELE-008` (aggregation and cascade budgets),
`BUS-005` (two independent limits, two findings) and `PWR-001` (sum with a derate) do not fit a
boolean predicate tree. Building the AST *and* a native escape hatch yields two rule systems,
two debuggers and two test suites, and the stated payoff, user-authored rules, has no UI in any
document.

**Change:** CR-024. Rules are Dart functions in a registry keyed by `ruleId`. What stays **data**
is substantial and is the part that actually needed to be data: rule metadata (message,
rationale, remedy hint, default severity, acknowledgeable), per-project severity overrides and
acknowledgements, forward-compat on unknown `ruleId`s in `AckedFinding`, and the
connector × signal-family **compatibility matrix**, which genuinely is a lookup table and needs
no AST. `RulePredicate` is deleted. The user-authored-rules claim is withdrawn from
`design-data-model.md §3.4`, and with it §3.4's third argument against enums, the other two
(growth rate, forward compatibility) still stand and the registry design survives on them.
This also closes the import-security hole in `critique-completeness.md D8`: there is no longer
an evaluated program arriving inside a `.rmlib`.

### AC-012 · SEV-3 #12: the dotted-path override argument is self-defeating

**Accepted.** `design-data-model.md §3.2` rejects a typed override class because it "must be
edited in lockstep with `TemplateBody` forever", then proposes a hand-maintained
`TemplateBody.pathType(String)` table with the identical lockstep requirement, minus the
compiler check, plus a runtime validation pass (I-15) the typed version does not need.
`TemplateBody` is app-defined and closed; there is no forward-compat argument, because unknown
*keys* are already handled by `EntityMeta.unknown`.

**Change:** CR-053. Typed `DeviceOverrides` and `PortOverrides` with nullable fields, null
*is* the sparse "not overridden" semantics. I-15 and the path-type table are deleted; the
property inspector binds directly.

### AC-013 · SEV-2 #10: `part of` for library-private setters will not scale

**Accepted.** `part of` files cannot carry their own imports; ~40 entity types plus ~30 command
types in one library means one library file importing everything and 70 parts that cannot be
reasoned about independently.

**Change:** `@internal` from `package:meta`, already a declared dependency, on entity setters,
which produces an analyzer error for consumers outside `rackmate_core`, and
`rackmate_ui`/`apps/rackmate` are different packages. Belt and braces: a grep test asserting no
entity setter is called outside `src/commands/`. `design-architecture.md §2.3` rule 2 is
rewritten.

### AC-014 · SEV-3 #16: epoch masks are hand-declared with no verification

**Accepted, and promoted.** ~30 commands × 5 epochs assigned by hand with "when in doubt,
over-declare" produces stale renders, which are the hardest class of bug to reproduce.

**Change:** one generic test, for every command type, snapshot every derived output, apply,
snapshot again, diff, and assert the declared `touches` mask covers everything that changed.
~40 lines, permanent, and it is the **highest value-per-line test not already in the plan**.
Added to the M1 exit criteria.

### AC-015 · SEV-3 #15: template snapshots are never refcounted

**Accepted.** `AddDeviceCommand.revert` must remove an inserted `TemplateSnapshot` only if no
other device references it, and `RemoveDeviceCommand` must not orphan one that is still used.

**Change:** snapshot insertion and removal become explicit child commands within the
transaction, with the refcount computed from `devices.values`. The existing round-trip property
test catches this for free once the generator emits add-device commands, so the change is really
"make the generator do that".

### AC-016 · SEV-3 #11, #13, #14, #17, #18, #19, #20 and SEV-4 #21–#24

All accepted; each is small and each is recorded so it is not rediscovered.

| Finding | Change |
|---|---|
| #11 `SignalRoute` has no v1 UI surface | Cut from v1 (CR-008). `Trace` computes paths on demand; `NET-003/004` compute reachability. Returns in v2 with a Dante view. |
| #13 layer-cache key omits LOD | `lodLevel` becomes an explicit parameter of every `SceneBuilder.build*` and part of every cache key; goldens pin the LOD, with one golden specifically at print LOD. |
| #14 `RendererCaps` is an unbounded escape hatch | Deleted (CR-088); the no-gradients/no-shadows rule becomes an invariant with a test. |
| #17 dash phase diverges on arcs; `dashPath` is on the hot path | Divergence documented in `docs/visual-language.md` so it is not chased later; **hops suppressed on dashed domains** (control and structure, the two where hops matter least); `dashPath` explicitly profiled in the perf harness rather than assumed cheap. |
| #18 `PdfTtfFont` must exist on the main isolate too | The metrics font is constructed **lazily on first paint**, not at bootstrap, and `stringMetrics` is cached aggressively. Added as the **sixth spike** so the cold-start cost is measured against the 1.2 s budget rather than assumed. |
| #19 Riverpod 3 moved `ChangeNotifierProvider` to legacy | Verified before the provider layer is written; the `epochs.revision` adapter is hand-written (~15 lines, `Provider` + `ref.onDispose`). The legacy library is not imported. |
| #20 "sub-millisecond at N=300" ignores that crossings are unbounded by N | Phase 5 moves off the commit path: the Bentley–Ottmann sweep and hop generation run **at paint time, viewport-scoped**. Hop rendering caps out to `gap` mode above a crossing threshold. X is measured on a real 300-connection fixture before the claim is repeated. |
| #21 stroke caps/joins/miter absent from `StrokeSpec` | `cap`, `join`, `miterLimit` added; both backends set them explicitly rather than inheriting (PDF default 10 vs Flutter default 4). CR-082. |
| #22 web has no isolates | One-line `kIsWeb` guard (CR-099). Web is not a v1 target. |
| #23 the touch intent layer is in the UX doc and absent from the architecture | `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` is built **first**, in M1, and no editor logic branches on `PointerDeviceKind`. This is a confirmed product decision ("architecture must not preclude touch"), so it is not optional. |
| #24 the round-trip invariant tests the wrong property | CR-117: assert the byte round-trip. |

### AC-017 · SEV-1 #5: there is no roadmap and the implied scope is 16–22 months solo

**Accepted as the most important finding in the corpus.** A design set this detailed with no
cost attached reliably produces a build that stalls at 40%. The bottom-up estimate is sound and
the two build orders in the design documents are engineering sequences, not plans, no
increments, no acceptance criteria, no cut list.

**Change:** Part 2 of this record carries the milestone plan and the binding v1 cut list. Its
shape follows `critique-completeness.md §E` (M0 reconciliation → spine → rack → wiring →
export → structure → builder → hardening) rather than this critique's cut table, because two of
that table's cuts violate confirmed product decisions (see RJ-002, RJ-003). The reconciliation
milestone, this document, is mandatory and is not compressible into the first coding
milestone; the six decisions in CR-001, CR-008, CR-017, CR-051, CR-083 and CR-081 each cost a
rewrite of everything downstream if guessed wrong.

---

## 2.2 From `critique-domain-realism.md`

The governing observation of this critique is accepted outright and is now a project principle:

> **The rack is where the gear lives. The job is the cable.** Every blocker below is the same
> mistake in a different costume — an assumption that the design is complete before the wire is
> pulled.

### AC-018 · B1: a pull sheet cannot exist before the equipment list does

**Accepted. This is the most consequential finding in all four critiques.** I-25 and
`design-ux-schematic.md §2.3`'s "loose wires are prohibited by the system" make it impossible to
schedule a run to a device that does not exist yet, which is the state of every job in February
when drywall goes up in three weeks. `StructureDrop` covers only runs originating at a Structure
device; it cannot express "Cat6 from the rack to the projector shelf, 15 ft service loop", a
spare conduit pull string, or the run to the gate operator.

**Change:** a `Link` endpoint becomes a sealed union.

```
sealed Endpoint
  PortEndpoint  { portId }
  PlaceEndpoint { locationId, description, intendedTermination, serviceLoop: Len? }
  OpenEndpoint  { description }          // deliberately unterminated; a coil in a J-hook
```

Plus `LifecycleStatus.designIntent` on `Link`, distinct from `RoughInStatus.planned`.
An unbound endpoint **schedules, prints, gets a `W` number and gets a label.** Binding it later
is one command (`BindEndpoint`) that preserves the ID, the length, the jacket, and the test
result. The DRC gains `LNK-020 advisory: 14 links have unbound endpoints`, a checklist, not an
error. `design-ux-schematic.md §2.3`'s rule survives in a narrower form: **dragging a wire onto
empty canvas still reverts** (that is a gesture, not a model constraint), but "Leave this end
open…" is an explicit command in the wire's context menu and in the schedule table.

### AC-019 · B2: one home run is modelled twice, with two lengths and two test results

**Accepted in full.** Two rows for one cable is guaranteed to diverge within a week of real use,
and it is the precise failure that stops people trusting the document.

**Change:** CR-107. `StructureDrop` is **deleted**. A home run is a `Link` whose field end is a
`PlaceEndpoint` and which carries `Link.structureOrigin{structureBodyId, outletId, fieldLabel,
rackLabel, wall?, mountHeightAff?, terminationField}`. `Outlet` (CR-016) groups Links. The
Structure device's "ports" become a rendering of those links' field endpoints, not entities that
own a duplicate of the cable's physical facts. One row, one length, one certificate, one status.

### AC-020 · B3: the power DRC fires on every correctly designed theatre rack and blocks export

**Accepted in full, including the power-factor gap the critique adds.** `PWR-001` as an error,
computed on nameplate, with `isContinuousLoad` defaulting true, with `blockExportOnErrors` true
and errors undismissable, makes a normal residential theatre rack permanently unexportable. The
design already stores `typicalWatts` and then chose not to use it for the number that matters.

**Change, all four parts:**
1. **Circuit loading uses `typicalWatts` × a per-category diversity factor** (amplifiers 0.35 of
   nameplate by default, switches 1.0, UPS 1.0), configurable per project. Nameplate becomes an
   *advisory* second line: *"worst-case nameplate 24.9 A, verify with a clamp meter at
   commissioning."*
2. **`apparentVA` and `powerFactor` are added** (CR-056). Circuit loading is computed in VA; UPS
   capacity is checked VA against VA. A linear-supply amplifier at PF 0.65 under-reports current
   by 35% under the `watts/120` formula, which is how a system that "calculated fine" trips a
   breaker.
3. **`PWR-001` becomes a warning** with an acknowledgement that prints (CR-020).
4. **`blockExportOnErrors` is deleted** (CR-022); **errors are acknowledgeable** (CR-019). The
   `design-data-model.md §3.5` position wins over `design-ux-rack.md §5.2`, as the critique
   recommends.

### AC-021 · M6: one cable cannot carry more than one service

**Accepted.** One Cat5e to a TV location carrying an IR emitter run, a 12 V trigger and RS-232
on separate pairs is routine; so is a 16/4 carrying a speaker pair plus a spare pair later used
for a screen trigger. The current model forces three Links on one physical cable, three pull
rows, three lengths to keep in sync, and a `TOP-002`/I-25 fight over the designator.

**Change:** CR-010. `Link.services: List<Service>`; the schedule prints one row per cable with a
services sub-line (`W044 | Cat5e | 62 ft | LR-TV | IR (pr 3, wht/brn) · 12VTRG (pr 4, brn) ·
RS232 (pr 1–2)`) which is exactly what the trim tech needs and cannot get anywhere else. The
same treatment applies to home runs, since a home run is now a Link (AC-019).

### AC-022 · M7: front and rear occupancy are checked independently, with no depth arbitration

**Accepted.** I-20 computes front and rear occupancy independently and `RCK-005` checks one
device against the rack, so a 16-in-deep amp at U19–U21 front and an 8-in rear-rail tray at U20
rear pass validation while physically fighting for the same air. This is *the* mistake in
shallow racks, which is most residential racks, and the data to catch it (`bodyDepth`,
`connectorProjection`, `depthOffsetFromFront`, `usableDepth`) is already modelled.

**Change:** depth occupancy is modelled as an **interval on the depth axis per (RU, face)**, not
a boolean, and `RCK-012 error: front depth + rear depth + 50 mm cable allowance > usable depth
for overlapping RU ranges` is added. Separately, `connectorProjection`'s auto-suggest of
`depth + 75 mm` is replaced by a value **derived from the deepest connector type actually on the
device's rear panel**: a molded HDMI with a bend is 100–125 mm and a compression-F on RG6 is
~100 mm, both of which the flat 75 mm under-reports.

### AC-023 · M8: a device mounted backwards is not expressible

**Accepted.** Reversing a chassis so its rear panel faces out is standard practice in credenza
racks and 2-post frames, and today the rear-panel view would show those ports on the wrong side,
actively misleading on a rack where half the gear is reversed.

**Change:** `RailPlacement.chassisRotation: normal | reversed` (CR-031). A port's effective face
is `templateFace XOR reversed`. A ↺ badge draws on the elevation. The rear-panel view groups by
**access side**, not by template face.

### AC-024 · M9: no length mechanism exists, so every length rule is decorative

**Accepted, including the sharpest part: silence reads as approval.** There is no floor plan and
the schematic is explicitly not to scale, so `calculatedLength` has no source; the fast entry
paths never ask for length; and `LEN-001` therefore never fires, not because runs are fine but
because there is no data.

**Change, all four:**
1. **`Location.estimatedRunLengthFromRack: Len?`**: one number per room, entered once, applied
   to every home run in that room with a per-link override. Ninety seconds of input turns 62
   null lengths into 62 usable estimates. Estimated values render in italic everywhere and are
   tagged in the schedule so nobody bills off them.
2. **Cable footage rollup in the materials list**, by media type, with a configurable waste
   factor: *"Cat6: 2,140 ft estimated + 10% = 2,354 ft → 3 boxes (1000 ft)."* This is the single
   most-used output of a takeoff and it is currently absent.
3. **Three length fields, three columns:** `routedLength` (estimate), `cutLength` (what to pull),
   `terminatedLength` (as-built). The pull sheet wants the second; the as-built wants the third.
   `calculatedLength` is deleted.
4. **`LEN-*` rules emit `advisory: length unknown, cannot verify`** when the length is null,
   rather than silently passing (G4).

### AC-025 · M10: the schedule is organised for the person drawing it, not the person holding the cable

**Accepted in full.** A schedule that says W044 runs `MTX1:J09 → HBT-GRT:J01` with a schematic
zone reference requires two sheet flips to become actionable at 7 pm behind a rack, and carries
no room, no rack, no RU, no conductor colours, no termination detail, and nothing to initial.

**Change:** the single "wiring schedule" splits into **two presets of one derivation**:

| | **Pull Sheet** | **Termination Schedule** |
|---|---|---|
| Orientation | portrait | landscape |
| Default sort | **room, then pathway**: the order the tech walks the house | **rack, then panel, then port** |
| Rows | field cables only (AC-026) | all cables landing in the rack |
| Columns add | footage subtotals per room, jacket colour, `Pulled ☐ Terminated ☐ Tested ☐ Init ___` | T568A/B, punch position, polarity, conductor colour per role, pinout notes |

Both presets add, on **both ends**: location (`RK-1 / U14 / rear`, `Great Room / TV wall /
WP-1`) and **both labels** (`fieldLabel` and `rackLabel`). The critique's observation that the
dual-label insight was correctly identified for Structure drops and then not applied to every
cable is accepted, it now applies to every cable. `Conductor.colorCode`, which exists in the
model and appears in no output, is printed.

### AC-026 · B5: patch cords will bury the schedule

**Accepted.** 110 rows of factory patch cords in a 180-row schedule makes the 70 rows that
describe real pulls indistinguishable from noise, and nobody labels a patch cord with a `W`
number.

**Change:** `Link.class: fieldCable | jumper | powerCord | internal`, auto-classified on
creation (both endpoints in the same rack, length under 2 m, factory-assembly media ⇒ `jumper`;
any link on a `power.*` family from a PDU outlet ⇒ `powerCord`) and user-overridable. The
wiring schedule **excludes `jumper` and `powerCord` by default**, with a toggle. Jumpers roll up
into the materials list by media + length + colour. PDU outlet assignments appear on the power
schedule as an **outlet map**, not as twenty cable rows. The netlist and `Trace` still include
them; they are real, they just do not belong on a pull sheet.

### AC-027 · M13: no low-voltage/line-voltage separation and no plenum enforcement

**Accepted.** `JacketRating` and `conduitId`/`pathwayId` are modelled and no rule uses them,
while NEC 725.136 (Class 2/3 sharing a raceway with line voltage) and NEC 800.154 (CMR in a
plenum) are two of the very few checks in the whole product that protect the user from an actual
code citation and a red-tagged job.

**Change:** `Pathway` is promoted to a first-class entity (CR-016) with
`kind: conduit | jhook | tray | plenumSpace | riser | directBury | exterior` and
`containsLineVoltage: bool`. Two rules:
`CODE-001 error: Class 2/3 conductor in a pathway carrying line-voltage circuits`;
`CODE-002 error: pathway kind == plenumSpace and jacket ∉ {cmp, lszh}`.
Both are acknowledgeable like every other rule (CR-019), because an inspector's judgement
outranks ours, but the finding must exist.

### AC-028 · M14: no unsupported-weight model

**Accepted.** A 34 lb amplifier or a 48 lb UPS on front ears alone sags, strips the rail
threads, and eventually comes out of the rack; every install manual for heavy gear says so, and
rear-support brackets are a standard rack BOM line the materials list currently cannot know
about.

**Change:** `TemplateBody.maxUnsupportedMass: Mass?`, defaulting to ~7 kg (15 lb) for
`mountMethod: rackEars`. `RCK-013 warning: DEVICE (34 lb) mounted on front ears only; requires
rear support or a shelf.` The support hardware is added to the materials list.

### AC-029 · M11: a `Link` cannot span three devices

**Accepted.** A dual-head IR emitter and a multi-pair snake are one cable, one part number, one
pull, N devices. **Change:** CR-014.

### AC-030 · M12: two rules that fight correct designs

**Accepted, both.**
- **`BUS-006`** (RS-485 star warning, suppressed only for Lutron QS and DALI) would fire on
  every correctly-wired Crestron job for the life of the product, since Cresnet explicitly
  supports star and home-run topology and star from a Cresnet supply is the recommended
  residential approach. **Change:** the suppression list becomes a registry field,
  `SignalFamilyDef.topologyFree: bool`, so it is data rather than a hard-coded exception array
  and users can extend it for proprietary buses; `ctl.cresnet` ships with it set.
- **`ELE-003`** (speaker polarity inverted; error; blocks export) derives its data from
  user-typed `Conductor.role` strings, so on a 16/4 across eight zones it will fire on typos
  roughly 100× more often than on real errors. **Change:** demoted to **warning**, and polarity
  becomes a **derived** property of the port pairing (`PortDef.polarity` on the terminal) rather
  than a free-text role, so the typo is not expressible.

### AC-031 · B4: the seeded catalog has no field devices, and three shipped rules can never fire

**Accepted, and the second half is the decisive part.** All 62 templates live in or near the
rack. There is no display, projector, speaker, camera, AP, touchpanel, keypad, wall plate, or, 
most conspicuously, the ISP gateway that is physically present in every residential rack in
North America. And because impedance and tap wattage live on the speaker, `ELE-004`, `ELE-005`
and `ELE-006`, three of the most valuable rules in the product, **can never fire**: the
objects they operate on do not exist.

**Change:** a **Field Devices** category of 18 templates ships in v1 (CR-061), all
`mountMethod: notInRack`, occupancy zero, authored through a **stripped builder form**: identity,
ports, location; no RU, no rack depth, no thermal class. The shipping set: display · projector ·
projection screen (it has a trigger and a power feed) · in-ceiling speaker pair · in-wall
speaker · subwoofer · outdoor speaker · 70 V pendant with a tap selector · IP camera · NVR ·
wireless AP · touchpanel · keypad · volume control · IR receiver eye · ISP gateway/ONT · OTA
antenna · F-type ground block. Speakers carry real `impedanceOhms` and a `tapWatts` selector so
the audio rules have something to evaluate.

### AC-032 · m15: auto panel layout flows connectors across 482.6 mm

**Accepted.** 482.6 mm is the *panel* width including ears; connectors live on the chassis at
~432–442 mm, so the auto-layout would draw jacks out past the rails on the view that gets taped
inside the rack door. **Change:** `TemplateBody.chassisWidth`, defaulting to 432 mm for
`widthClass: full`; the layout flows within it, centred on the panel.

### AC-033 · m16: power sequencing has data and no rules

**Accepted.** `sequenceStep` and `sequenceDelayMs` are modelled and a sequencer ships, with no
rule enforcing the one thing sequencing exists for. **Change:** `SEQ-001 warning: amplifier on
sequencer step 1 of 4 — amplifiers should be last on and first off.` A reversed sequence thumps
and blows drivers.

### AC-034 · m17–m24: the remaining minors

All accepted; each is small and each changes a number or a default that reaches a drawing.

| # | Finding | Change |
|---|---|---|
| m17 | NCS sheet-number regex fails a four-page residential set | CR-066: `sheetNumbering: ncs \| simple`, default `simple`. |
| m18 | I-41 blocks export over a drafting footnote | CR-023: deleted; the exporter fills it in. |
| m19 | `RCK-008` / `RCK-004` are permanent noise on wall and credenza racks | CR-020: both **advisory and default off** for `wallSwingGate`, `wallPivotCabinet`, `wallFixed`, `credenzaFurniture`; on for floor enclosures. |
| m20 | "vent panels above high-heat devices" is backwards in a sealed enclosure | The heuristic is gated on `Rack.formFactor` and on whether a fan panel is present; in a sealed fan-cooled enclosure it fills with **blanks** to force air through the intended path. |
| m21 | Grounding is not modelled | Minimum viable version ships: an F-type ground block template (AC-031), a `power.bonding` signal family, and `Rack.groundBarPresent` feeding a note on the elevation. The full commercial bonding-detail sheet is deferred (RJ-009). |
| m22 | Cable IDs have no lock, and 60 labelled cables can be renumbered by accident | CR-034: `Link.designatorLocked`, auto-set at `RoughInStatus >= pulled`; renumber refuses locked IDs and reports the count. |
| m23 | TIA-570-D grades are a vocabulary integrators do not speak | CR-108: outlet templates first-class, grades as presets and a standards tag. |
| m24 | `Outlet` demands `wall` and `mountHeightAff`, meaningless for a ceiling speaker pair | The outlet template drives which location fields apply; `mountSurface` gains `ceiling \| floor \| soffit \| exterior \| inGround`, none of which demands a compass direction. |

---

## 2.3 From `critique-ux-simplicity.md`

The thesis is accepted and is now principle G1: the design states that the schedule is the truth
and then spends roughly 70% of its effort on the diagram. Several of its specific cuts are
rejected in §3; the following are accepted.

### AC-035 · The three prioritisation fixes

**All three accepted, verbatim.**
1. `blockExportOnErrors` never blocks a deliverable, CR-022, and I go further and delete the
   setting.
2. Invariant I-41's export block is deleted, CR-023.
3. **The schedule table is the second tab in the app**, reachable from an empty project and
   populating live as connections are made, CR-105. It should be the thing the user watches
   fill up, not the thing they discover at export.

### AC-036 · Cut #2: `SignalRoute`

**Accepted.** Duplicates `critique-feasibility.md #11`; see AC-016.

### AC-037 · Cut #4: `Sheet` as a document entity, partially

**Finding accepted; the entity is kept.** Multi-sheet as a *document* feature is cut (CR-073)
and the expensive drafting apparatus around it disappears, but the `Sheet` entity itself ships,
holding exactly one schematic sheet, so the file format never migrates when multi-sheet lands
(G5). Deleting the entity to re-add it later is a migration; keeping it is one map with one
member. The critique's own key insight, a domain partition has zero cross-sheet connections,
is what makes the expensive half free to cut.

### AC-038 · Cut #5: layers

**Accepted.** **Change:** CR-064.

### AC-039 · Cut #6: the fabricated-data problem

**The critique's *reasoning* is accepted in full and becomes principle G4;** its proposed cut to
two rollups is rejected (RJ-005). The dangerous part is not the cost, it is that
`typicalWatts` defaults to 50% of nameplate, BTU derives from that guess, CG derives from
weights the user copied or invented, and the design then paints those numbers amber and red and
lets them block a PDF. The first time the app says "14.2 A of 16.0 A" and a clamp meter reads
6 A, the user stops trusting every number in the product.

**Change:**
1. **No silent estimates, anywhere.** `typicalWatts` no longer defaults to half of nameplate.
   Unknown is null, null is shown as `—`, and every rollup reports its unknown count (CR-114).
2. **Estimated values are visually distinct** (dotted underline on screen, italic in print) and
   labelled as estimates in the schedule.
3. **No computed number blocks anything** (CR-022, G3).
4. BTU/hr, centre of gravity and thermal adjacency move to a **collapsed advisory panel, closed
   by default**. RU, weight, power (VA) and outlets stay in the always-visible chip strip,
   because those are the four numbers that decide whether a rack is buildable.

### AC-040 · Cut #7: the DRC catalogue, partially

**Finding accepted, magnitude adjusted.** ~60 rules is not shippable in v1 and each is a chance
to be confidently wrong about a system the user knows better than the app does. Six is too few:
`critique-domain-realism.md` adds five rules of its own, three of which (`RCK-012`, `CODE-001`,
`CODE-002`) protect the user from real money.

**Change: v1 ships 27 rules**, listed once in **canon §5**:
`TOP-001..005` (blocking) · `PLC-001` · `PLC-002` · `PLC-003` (blocking) · `SIG-001` · `SIG-002` ·
`DIR-001` · `DIR-003` · `CON-001` ·
`ELE-003` · `ELE-006` · `NET-001` · `PWR-001` · `PWR-003` · `LEN-001` · `RCK-001` · `RCK-002` ·
`RCK-003` · `RCK-012` · `RCK-013` · `CODE-001` · `CODE-002` · `LNK-020`.

> **Amended per §12.6(b), paid 2026-08-03.** This paragraph read *"22 rules, listed once in
> `docs/rules.md`"* over an enumeration of **24** ids. The enumeration governs and "22" was an
> arithmetic error; `PLC-001..003` are ratified as distinct tier-1 rules, giving **27**. The home is
> **canon §5**, not `docs/rules.md`: that file deliberately does not exist, because CR-021 rules
> that a rule not in the catalogue does not exist and §5 *is* the catalogue (§10.12(g)).
Everything else moves to v1.2 behind a fixture corpus (AC-051). The acknowledgement machinery is
**kept** (RJ-006).

### AC-041 · Cut #8: template versioning and the Update Manager, partially

**Accepted for v1.** The semver classifier, the two-column diff view, the safe/additive/breaking
grouping, the per-cable remap ranking and the conflicts-with-local-edits merge together
constitute a package manager, and v1 does not need one.

**Change:** v1 is **copy-on-place**. `templateRef{templateId, version, contentHash}` is still
recorded and the snapshot is still embedded, so nothing about the format changes when updates
land in **v1.2**, which is exactly the critique's own recommendation and is a G5 item. v1 shows
a passive "this device is based on an older catalog template" badge (CR-062) and offers only
"Fork to a new template". The `[Del]` button never ships at all (CR-052).

### AC-042 · Cut #10: template file infrastructure, partially

**Accepted:** `.rmlib` library packs, the `signature` field, and the `provenance` /
`derivedFrom` *chain* are cut from v1. **Not accepted:** `contentHash` survives; it is three
lines, it is the snapshot-integrity guard, and it is what makes the embedded-snapshot argument
true. But I-8's "hash mismatch is a **hard load error**" is demoted to a **warning plus a badge
on the affected devices**: refusing to open a project because a snapshot was hand-edited is a
data-loss event dressed as a safety feature. Single `.rmdev` export and import stay in v1;
they are the unit people email each other, and the plain-JSON diffability argument is one of the
few genuine differentiators in the product.

### AC-043 · Cut #11: shelves, stripped

**Accepted.** Hosted devices are real and common; the interaction model around them is not.
**Change:** auto-pack left to right; `ShelfPlacement.order` decides sequence; free lateral
positioning, `Alt`-drag, the third focus level entered with `Enter`, and per-host depth-overhang
warnings all defer. `lateralOffset` stays in the format (CR-029) because it is one nullable
field and the free-position case is real; only the UI defers.

### AC-044 · Cut #12: 0U gutters, partially

**Accepted for the interaction, rejected for the model.** The 16-px gutters, rotated bar
rendering, drag-into-gutter, resize handles, the `G` toggle and channel-overlap warnings all
defer to v1.1. `ZeroUPlacement` **stays in the sealed union**: a 0U PDU is a real rack occupant
that contributes weight, outlets and ports, and modelling it as `OffRackPlacement` is a lie that
would show up in every outlet-accounting number. In v1 a 0U occupant is created and edited from
the inspector (channel, start U, span) and renders as a plain bar; there is simply no drag
gesture.

### AC-045 · Cut #13: auto-arrange with trade heuristics

**Accepted.** The design's own note that "integrators have strong and differing opinions" about
heavy-low, amp spacing, vent-above-heat and 15% spare RU is the argument for *not shipping it*,
not for shipping it with per-rule checkboxes. **Change:** v1 ships **Compact Down** and
**Compact Up** only, both with the preview-then-accept pattern that is already designed and is
the best interaction in the rack spec. `Auto-arrange` and `Fill gaps with blanks/vents` defer to
v1.2, the latter with m20's form-factor gating.

### AC-046 · Cut #14: the keyboard surface, and the collisions

**Accepted, including that the collisions are a bug and not a preference.** ~170 bindings across
two documents, colliding on 16 keys, with `Shift+F` double-bound inside one table.
**Change:** CR-101, ~40 bindings, one arbitrated table, generated from one `Intent` registry.

### AC-047 · The nine identifier systems

**Accepted.** `refDes`, `name`, `typeName`, port `designator`, port `userLabel`, link
`designator`, net name, drop `fieldLabel`, drop `rackLabel`, the design is right that these are
distinct concepts and wrong to expose all nine in v1.

**Change:** v1's **default** UI exposes three: device designator, port label, cable ID. The rest
exist in the model and appear in the schedule, the inspector's advanced section, and the PDF, 
where they are needed and where a professional expects them, but none of them is on the primary
authoring path. The one exception is the drop's dual label, which prints from day one
(CR-044) because `critique-domain-realism.md` is right that it is the single most valuable
line in the corpus.

### AC-048 · The friction inventory

**Accepted as a punch list.** Each cliff has a named owner:
cliff #1 (no wiring in the rack editor) → CR-105;
cliff #2 (the schematic looks nothing like the rack) → a one-time coach mark at the moment of
first switch, plus the `📐 Rack order changed · Tidy sheet` chip that is already designed;
cliff #3 (two places to add a device) → CR-104;
cliff #4 (the Structure editor is tuned for 60 drops and hostile to 2) → the editor opens in
**table mode** with a `+ Add drop` row; matrix mode is a tab, not the entry point;
cliff #5 (export blocked) → CR-022;
cliff #6 (legend invariant blocks export) → CR-023.
Also accepted: the empty `Location` combobox on field two of the very first dialog is removed,
location is set later, from the rack inspector or the Locations panel.

### AC-049 · The device builder's real barrier is the 25 metadata fields, not the port grid

**Accepted, and it is the right diagnosis.** The port grid is excellent (spreadsheet
ergonomics, fill-down, TSV paste, archetype generators) and the barrier in front of it is
twelve physical fields and six power fields, most of which the user does not know and half of
which are absent from the spec sheet in their hand. The result is either a guess (feeding G4's
problem) or a stall.

**Change:** **three required fields (name, RU height, designator prefix) then ports, then
done.** Everything else is optional with a visible `unknown` state that the app degrades
honestly around (CR-114). A template saved with three fields is not "incomplete"; it is a
template. The `Draft` flag survives only for templates saved with *zero* ports and no category.

---

## 2.4 From `critique-completeness.md`

### AC-050 · §A: the unmet-requirement findings

Accepted, with the ruling for each:

| Finding | Ruling |
|---|---|
| **A1.1** no agreed maximum RU | CR-038: 1..60. |
| **A1.3** 2-post racks have no meaningful `usableDepth` | `usableDepth` becomes nullable and the depth rules skip when it is null; `RackFormFactor.openFrame2Post` documents rail-to-rail only. |
| **A2.1** no UI for creating registry entries, while user-extensibility is the central argument against enums | Partially accepted: see RJ-011. The user-authored **rules** claim is withdrawn (AC-011); a **media-type editor** and **connector aliases** ship (the Structure CSV import already creates media types, and that is correct); a full registry editor does not. |
| **A2.2** the connector footprint table has 13 entries for a catalog using ~35 connector types | Accepted: the "zero-authoring correct rear panel" claim is false as written. The table is completed for **every connector in the shipped catalog**, and a CI test asserts that every `ConnectorTypeDef` in the catalog has a footprint. |
| **A2.3** no undo model for the builder or Structure editor | CR-106. |
| **A2.4** no empty state, no DSL parse-error design, no autocomplete spec | Accepted into the hardening milestone; the DSL's discoverability argument is void without the autocomplete that teaches it. |
| **A2.5** the label-pattern grammar cannot express its own catalog (`A03`'s two simultaneous cycling sets) | Accepted: the grammar gains an explicit period on cycling sets, `{FL,FR,C,SL,SR,SBL,SBR}@7` and `{+,−}@1`, and the offending catalog entry is re-authored. |
| **A3.1** multi-conductor links have no UI in any document | Accepted: see AC-053. |
| **A3.2** no cable-length mechanism while eight rules depend on one | AC-024. |
| **A3.3** connections can only be created in the schematic, never stated | CR-105. |
| **A3.4** staged devices have undefined schematic layering | Staged devices get a `SheetItem` at insertion (CR-104) and are laid out as ordinary leaf nodes; rack position simply does not participate in their tie-break. |
| **A4.1** the brief names ten cable **types**; every document colours by **domain** | Accepted as a requirement deviation needing explicit sign-off, see AC-054. |
| **A4.2** per-type colour override is deferred to "later" | Accepted; it ships in v1 (AC-054). |
| **A4.3** no `SignalDomain` entity exists to hold the domain palette | CR-078. |
| **A5** port pinouts are modelled and never rendered | Accepted: the Termination Schedule (AC-025) prints pinout and conductor colour; the `T5.01` plate/pinout detail sheet stays auto-on when a non-standard pinout exists. |
| **A6.1–A6.4** Structure gaps | CR-108, CR-109, CR-110, CR-112. |
| **A7.1** `blockExportOnErrors` deadlock | CR-022. |
| **A7.2** the acknowledgement appendix is promised by three documents and appears in no sheet list | CR-022: sheet `T0.02`. |
| **A7.3** the BOM is referenced by four documents and designed by none | Accepted: see AC-055. |
| **A7.4** no page-count bound or preview | Accepted: the export dialog's dry-run already computes the sheet count; it now also warns above 40 sheets and hard-caps at `maxPages: 2000`. |
| **A8.1** mobile read-only designed for 1 of 4 surfaces | Accepted with scoping: see AC-056. |
| **A8.2** the template library has no implementation home in the architecture | Accepted: `rackmate_core/library/` gains the `.rmdev` codec, its own migration chain, and a library directory service; `apps/rackmate/lib/library/` gains import/export. Its absence was an oversight. |
| **A8.3** tombstones, `EntityMeta` and `FracIndex` are absent from the architecture | CR-095, CR-027. |

### AC-051 · §D15: ~60 rules with electrical consequences have no test strategy

**Accepted, and it is the most serious of the D-findings.** `DIR-003` describes an action that
destroys hardware; `ELE-004`/`ELE-006` describe actions that damage amplifiers. The architecture
document tests migration, commands, scenes and PDF structure, not the domain logic that is the
entire wedge.

**Change:** a **DRC fixture corpus**: for every shipped rule, at least one known-bad design that
must produce exactly that finding and one known-good near-miss that must not. The corpus is a
directory of `.rackmate` files and an assertion table. **No rule ships without its pair**, which
is also the gate that keeps the v1 catalogue at **27** (AC-040, corrected by §12.6(b)). A domain-expert review of the
shipped rules and of the catalog data is a named milestone exit criterion.

### AC-052 · §C36 / §D2: catalog data provenance and sample projects

**Both accepted.**
- **Provenance:** every numeric field in every shipped template carries a cited source
  (manufacturer datasheet, published standard, or measured), recorded in
  `assets/catalog/sources.md`. A template whose safety-adjacent fields (`pinoutVariant`,
  `impedanceOhms`, `poeBudgetWatts`, `maxUnsupportedMass`) are uncited does not ship. This is
  the gate that sets the catalog count (CR-061), not a target number.
- **Sample projects:** the four starter projects are authored as **real `.rackmate` files** and
  do triple duty as the golden corpus, the performance fixtures, and the screenshot source. At
  least one exercises the Structure device and at least one exports cleanly to a full sheet set,
  as listed today, none demonstrates either differentiator.

### AC-053 · §A3.1: multi-conductor links have no UI

**Accepted; the model ships, the gesture defers.** `design-data-model.md` calls one-cable-many-
conductors load-bearing decision #4 and then no document specifies the gesture that creates a
four-conductor link, how conductors are displayed or edited, or what a partially-connected group
does. Component video and stereo speaker runs, both in the seeded catalog, are unbuildable as
designed.

**Change:** `Conductor` and `PortSetDef.atomicConnect` ship in the model and the format. The v1
**gesture** is limited to `atomicConnect` sets: dragging from any member of a set connects the
whole set in one action, producing one Link with N conductors, and the roles are assigned by the
set's declared order. Hand-authoring an arbitrary conductor map defers to v1.1. A 16/4 run to two
zones is therefore one Link with four conductors in v1, which is the case the whole decision
exists for.

### AC-054 · §A4.1/A4.2: the brief says "colour-coded by cable type", the design colours by domain

**Accepted as a genuine deviation from a stated requirement, and it is resolved rather than
absorbed.** The technical argument is correct and is not reversed: no palette is CVD-safe past
~9 categories, and Okabe-Ito's greyscale claim is demonstrably false (Sky Blue 0.4050 vs Orange
0.4162). But the requirement names ten specific types, and today *Analog RCA* and *speaker level*
share one orange, and *S/PDIF* and *TOSLINK* share one vermillion.

**Change, three parts:**
1. **Hue = domain; dash + weight + tag = type.** Unchanged, and the argument is written into the
   legend sheet so the reader sees why.
2. **The legend prints one row per named cable type**, not per domain, each showing that type's
   exact rendering (hue, dash, weight, tag) in colour and in greyscale side by side. All ten
   types the brief names are individually identifiable on the legend and on the drawing.
3. **Per-family colour override ships in v1.** `SignalFamilyDef.colorOverride` already exists in
   the model (CR-078); it needs a settings row, not an architecture. Deferring it to "later"
   while the requirement says "colour-coded by cable type" is not defensible.

Plus a commitment the design makes implicitly and never tests: the legend is **verified against
deuteranopia and protanopia simulation and against a real greyscale laser print** before v1
ships, as a named acceptance criterion (AC-058).

### AC-055 · §A7.3: the BOM is referenced everywhere and designed nowhere

**Accepted.** `SheetKind.bom`, `bom_table.dart`, `Money`, `cost`, `supplier`, `purchaseOrder`,
"excluded from BOM active-device totals", "total cost when a BOM exists", a feature four
documents assume and none specifies.

**Change:** v1 ships an **Equipment List and Materials sheet** (`T6.30`), not a BOM. It has no
pricing: quantity, designators, manufacturer, model, description, RU, rack, location, face,
weight, draw, status, notes, plus the cable footage rollup by media (AC-024) and the hardware
implied by rules (ear kits, rear supports). `Money`, `cost`, `supplier` and `purchaseOrder` are
**deleted from v1**; a priced BOM is an adjacent product and no requirement asks for one.

### AC-056 · §A8.1: mobile read-only is designed for one surface of four

**Accepted with explicit scoping**, since the confirmed decisions require mobile read-only in v1
and only `design-ux-rack.md §1.2` designs any of it.

**Change:** v1's mobile/tablet mode is **read-only viewing of three surfaces**: the rack
elevation (already designed), the **schedule table** (a real `DataTable`, trivially responsive,
and the artifact a reviewer most needs), and the **exported PDF**. The schematic canvas and the
device builder are **not** available on mobile in v1, and the app says so rather than shipping a
squeezed editor. This honours the confirmed decision honestly instead of nominally.

### AC-057 · §C4: do device images ship in v1

**Accepted: no.** `design-ux-device-builder.md §1.5` already calls them a scope trap and states
they are "not needed for correct output". Cutting them resolves the container question (CR-091),
removes the image-decode bounds from the import-security surface, and removes ~1 MB per template
from the size budget. `frontImage`/`rearImage` are removed from `.rmdev` v1.

### AC-058 · §D1, D3, D4, D5, D7, D8, D10, D11, D12, D13, D14: the cross-cutting gaps

All accepted as **named work with a named home**, because the pattern across them is that they
are unowned rather than hard.

| Gap | Change |
|---|---|
| **D1** no help system, no glossary, no error-message catalogue, a `[Why?]` button that leads nowhere | `docs/glossary.md` ships **in-app** as a searchable panel; `CompatibilityRuleDef.rationale` gets the viewer `[Why?]` already promises; one error-message catalogue with one voice; a shortcut panel generated from the `Intent` registry (CR-101). |
| **D3** the entire file-layer error surface is undesigned | Designed as a set: corrupt file, newer schema (the read-only banner), permission denied, disconnected network path, file locked, hash mismatch (AC-042), quarantined dangling reference, disk full, read-only target, Windows path length, cloud-sync conflict, **target PDF open in Acrobat** (the most common Windows export failure), and two app instances on one file. |
| **D4** eight missing empty states | All eight designed alongside the one that exists. |
| **D5** data-loss edges | `[Del]` removed (CR-052); shelf deletion keeps its safe default; `Ctrl+X` on a wired device, `Commit sort order`, and CSV-import-over-existing-drops all gain confirms; the undo cap at 200 gains a status-bar signal instead of silently dropping the oldest entry. |
| **D7** licensing is absent from all six documents | SIL OFL 1.1 text ships with the fonts and is registered via `LicenseRegistry.addLicense`; `showLicensePage` is wired; a licence model and EULA are a named milestone deliverable, not an afterthought. |
| **D8** no security review of file import | Zip-slip protection, entry-count and uncompressed-size limits, and JSON depth/size limits on every import path. The evaluated-rule-AST hole closes with AC-011. |
| **D10** distribution and code signing are absent, the largest unowned area | Named as a milestone with its own lead time: Windows OV/EV certificate procurement **starts two milestones before release** because reputation-building takes weeks; macOS notarisation and stapling; vendored pdfium (CR-100); a release pipeline with symbol archival. |
| **D11** the schematic and builder have no a11y design; ghost states are far below contrast thresholds | A fully specified **keyboard path to create a connection** (select port → `W` → `Tab`/`Shift+Tab` across *all* ports with announcements → `Enter`); a WCAG AA target named; filtered-wire alpha raised from 8% to a tested floor; rack device fills gain a non-colour encoding; an NVDA/VoiceOver test matrix. |
| **D12** the DSL, the CSV synonym table and all registry display names are structurally English-only | Registry display names become localisable maps; the DSL and synonym tables are documented as English-only in v1 with the localisation path named; `l10n.yaml` and the generation step are added to CI. |
| **D13** printer margins, colour management, greyscale beyond wires, no print test matrix | A "fit to printable area" vs "actual size" choice; greyscale rules extended to faceplate fills, tints and header bands; a **print test matrix on real hardware** (laser at ANSI B/A3, plotter at ANSI D, and a photocopy reproduction) because the entire dash-pattern argument is predicated on it. |
| **D14** "degrade gracefully" has no design; no progress or cancel except on export | Documented limits with a soft warning at 1.5× and an open-read-only gate at 3×; progress and cancel on **every** operation over ~500 ms (open, save, full DRC sweep, CSV import, catalog load). |

> **The D10 row's procurement schedule is superseded — see §12.9 and §11.6.** RackMate is an internal tool; signing is self-signed with a timestamp, Microsoft Trusted Signing is the named fallback at M8, and no OV/EV certificate is procured at any milestone. The rest of D10 — macOS notarisation, vendored pdfium (CR-100), the release pipeline with symbol archival — is **unaffected and still binding**.

### AC-059 · §E: the milestone plan

**Accepted as the plan of record**, with the adjustments already stated (AC-017). In particular
its two sequencing warnings are adopted verbatim: **M0 reconciliation is not compressible into
M1**, and the rules-as-code decision must be made **before** the wiring milestone, not during it;
it is the justification for several registry decisions and deciding it late means either
building an interpreter nobody needs or refactoring a shipped file format.

---

# 3. Rejected critiques

Seventeen findings or recommendations are rejected, in whole or in part. Each is named, its
argument is stated fairly, and the reason for rejection is given. Nothing is dropped silently.

Three grounds account for most of them:

- **The confirmed product decisions are constraints, not inputs** (§0.2). Four recommendations
  cut something the brief fixed.
- **Cheap now, ruinous later** (G5). Several cuts remove a field or an FK that costs nothing to
  ship and a format migration to add back. `critique-ux-simplicity.md`'s own "do NOT cut" list
  is accepted wholesale on exactly this ground; some of its cuts fail the same test it wrote.
- **The finding is right and the remedy overshoots.** Where that is the case the finding is
  accepted in §2 and only the remedy is rejected here.

---

### RJ-001 · `critique-ux-simplicity.md` cut #1: delete the editable schematic canvas and its layout engine

**The argument.** This is roughly half the remaining work: cycle-breaking, layering, barycentre
sweep, coordinate assignment, channel routing, track ordering, hop arcs, junction staggering,
pinning, preview-diff, four tidy scopes, unit splitting, buses, off-sheet connectors, zone
grids, sheet partitioning. Replace it by wiring on the rack elevation and *generating* a
read-only diagram at export time: "Nobody hand-edits a KiCad netlist report either."

**Rejected as stated. The reduction it implies is accepted.**

The requirement list is explicit on two points that this cut removes: *"The user makes physical
connections between devices to build a wiring plan"* and *"The wiring planner takes visual
inspiration from electronics schematics."* A generated, non-interactive diagram satisfies the
second and not the first, connections have to be made somewhere, and the elevation is the wrong
somewhere for a device with sixteen rear ports at LOD levels where ports are three-pixel ticks.

The deeper problem is that the cut proves too much. If the diagram is purely generated, then
symbol placement is never user intent, and the moment one user says "put the matrix above the
switch" the entire pinning/tidy machinery has to be built anyway, after the file format has
shipped without `SheetItem.pinned`.

**What is accepted from it**, and it is most of the cost: unit splitting (CR-070), buses,
off-sheet connectors and cross-refs (CR-073), min-cut and geometric partitioning (CR-073),
preview-diff with variant cycling and the four tidy scopes (CR-068), `Trace` and the search DSL
(AC-040 deferrals). What remains in v1 is the Sugiyama pipeline phases 0–4 plus channel routing
, which `critique-feasibility.md` independently rates as sub-millisecond and which is the
cheapest part of the list, plus drag-to-connect, chain-draw, multi-draw, magnetic snap, pinning
on manual move, and one `Tidy sheet` command. That is a fraction of the cut's target and it
keeps the requirement.

> **Superseded — see §12.1 (§7.2.3 router row).** Phases 0–3 only; no channel routing, no phase 5.

### RJ-002 · `critique-ux-simplicity.md`: "pick one view for v1; wire on the rack elevation"

**The argument.** Two canvases means two mental models, two coordinate systems, two selection
behaviours, two colliding shortcut tables, and a what-syncs-what table the user meets as a
surprise before they meet it as documentation. The rear elevation is *already* the wiring
surface by the schematic document's own words. Port badges (`→ SW-01 P04`) replace drawn lines;
lines appear only under a filter or on hover.

**Rejected.** This is the strongest rejected argument in the set and it is rejected on evidence
rather than on principle.

1. **It does not survive the density it is meant to fix.** A whole-house system is dominated by
   rack→room runs. The proposal answers that those are Structure drops rendered as a flag bank,
   true, and it means the elevation gutters carry the *field* cables while the intra-rack cables
   become port badges. A 24-port patch panel to a 24-port switch then renders as 24 badges
   reading `→ SW-01 P04`, which is a table drawn in the worst possible place.
2. **It deletes the requirement, not just the view.** "Takes visual inspiration from electronics
   schematics" is not satisfiable by a badge on an elevation, and generating the schematic for
   export only (RJ-001) means the user cannot influence a drawing they are contractually handing
   to a client.
3. **The failure it predicts is real and is fixed more cheaply.** Cliff #1 and cliff #2 are
   genuine and are addressed directly, CR-105 signposts wiring from the elevation, CR-104
   removes the two-places-to-add-a-device ambiguity, CR-101 removes the colliding keymaps, and
   the sync table's two exception rows get a coach mark at the moment of surprise (AC-048).
   Those four changes cost days. Deleting a view costs a requirement.

The positions-are-not-linked argument in `design-ux-schematic.md §5.2` is correct and is
upheld: an AVR sits at U14 for thermal reasons and mid-chain for logical ones, and slaving
either to the other destroys work silently and unrecoverably.

### RJ-003 · `critique-ux-simplicity.md` cut #3: derive `Net` in v1

**The argument.** The defence of stored nets is well-argued but every argument for it is about
buses, 70 V taps, RF cascades and terminators, all of which are being cut. Without user-named,
coloured, `N###`-designated nets, the label-flicker objection evaporates. Keep the JSON field
for forward compatibility; ship zero UI.

**Rejected.** The premise is wrong about what is being cut. `ELE-005` (70 V tap sum), `ELE-004`
(parallel low-Z), `ELE-008` (RF cascade) and the `BUS-*` family are deferred, not deleted, and
`critique-domain-realism.md B4` is simultaneously demanding the speaker templates that make
`ELE-004/005/006` fire, so the multi-endpoint semantics come back in v1.2, not never.

More decisively: this is a G5 violation in the exact shape G5 was written for. `Service.netId`
is **one foreign key**. Shipping it costs a field; adding it later means reconstructing
membership for every existing project by union-find and then asking the user to confirm the
result, which is precisely the "labels flicker on merge" failure the design rejected. "Keep
the JSON field, ship no UI" is what I am doing: v1 auto-creates an implicit singleton net per
service, exposes no net editor, and the FK is authoritative from day one.

### RJ-004 · `critique-ux-simplicity.md` cut #9: the Structure editor's advanced half

**The argument.** Keep the room × media matrix and a flat drop table. Cut the TIA-606 pattern
engine and five label presets, bundles, CSV import with synonym mapping, `RoughInStatus`,
`TestResult`, multiple Structure instances, jacket colour, conduit, reel ID, and **dual
field/rack labels**: the last conceded as "a genuinely good observation from the field" and
"also a v2 observation."

**Rejected in substantial part.** Four of these are the product.

- **Dual labels stay.** `critique-domain-realism.md`, the field voice, calls two labels per
  drop with both printed "the single most valuable line in these four documents", and names the
  mismatch between the plate label and the panel label as *the* most common on-site failure.
  It costs one nullable string and one column. Cutting it to save that is not a trade.
- **CSV import stays.** It is not a convenience feature; it is the *entry path* for the workflow
  `critique-domain-realism.md B1` says the whole product currently fails, the contractor's pull
  list arrives as a spreadsheet in February. Cutting it while accepting B1 would be incoherent.
- **`RoughInStatus` and `TestResult` stay** (the latter reduced to pass/fail + certificate ID).
  They are what turn the design PDF into the as-built PDF, they are what make the "unused home
  runs" page possible, and they are two enum fields and a small record. The as-built deliverable
  is a differentiator nobody in this category ships.
- **Multiple Structure instances stay.** Media panel + exterior/camera panel + service entrance
  is a normal residential job; the cost is that `structureBodyId` is a foreign key instead of an
  implicit singleton.

**Accepted from it:** five label presets reduce to two (CR-044); "bundles" as a *conduit*
concept becomes `Pathway` and as an *outlet* concept becomes `Outlet` (CR-016), which is a
simplification of a genuinely confused area; reel ID is cut; jacket colour and conduit become
optional columns rather than default ones.

### RJ-005 · `critique-ux-simplicity.md` cut #6: reduce the derived metrics to two numbers

**The argument.** Cut circuits, NEC derates, PoE budgets, BTU, centre of gravity, thermal class,
clearance, outlet accounting and the nameplate/typical toggle. Keep only RU used/free and weight
vs capacity, "both facts the user actually supplies."

**Rejected in part; the reasoning is accepted in full (AC-039).**

The diagnosis is exactly right and is now principle G4. The remedy is wrong because it cuts the
wrong half. Power is the number one reason a rack fails in service, and
`critique-domain-realism.md B3` is simultaneously arguing that the power model needs **more**
fidelity (apparent VA, power factor, diversity factors) not less. Two critiques point in
opposite directions here and the field voice wins: an integrator will forgive a missing BTU
figure and will not forgive a tool that let them put 25 A of amplifiers on a 20 A circuit
without a word.

**The binding resolution:** keep RU (front and rear), weight, **power in VA**, and outlet
accounting in the always-visible chip strip. Move BTU/hr, centre of gravity and thermal
adjacency to a collapsed advisory panel, closed by default. Delete every silent estimate
(CR-114, G4). No computed number blocks anything (CR-022, G3). The user is never shown a number
the app invented.

### RJ-006 · `critique-ux-simplicity.md` cut #7, second half: delete the acknowledge-with-reason machinery

**The argument.** It is "exactly right for a professional as-built deliverable and exactly wrong
for minute 10 of someone's first session, where it presents as 'type an essay to dismiss this
yellow triangle.'"

**Rejected.** The first half of cut #7, 60 rules down to a shippable few, is accepted (AC-040,
at **27**; §12.6(b)). The acknowledgement machinery is the thing that makes the reduced rule set *safe*:
because errors are acknowledgeable (CR-019), nothing has to block (CR-022), which is what makes
G3 implementable. Delete acknowledgement and the only remaining ways to handle a rule the user
disagrees with are to block them or to silence the rule globally, and the design correctly
identifies both as the failure modes that make people route around the tool.

It is also the as-built differentiator: an acknowledgement that prints, *"W042, HDBaseT on
Cat6 patched via SW-1 port 12. Reason: existing condition, to be corrected in Phase 2.,
R. Riley, 2026-07-18"*, turns the DRC list into a remediation scope, which is a deliverable
integrators currently get from nothing.

**The first-session concern is answered without cutting it:** the reason field is required only
for a **project-wide** mute; a single-instance acknowledgement takes one click and offers a
reason field that may be left empty. The essay is only demanded where the consequence is
permanent.

### RJ-007 · `critique-ux-simplicity.md` #15: ship the catalog at lower fidelity

**The argument.** Keep the seeded catalog but drop typical watts, BTU, clearance and thermal
class from all templates. It halves the authoring effort and stops feeding the fabricated-data
problem.

**Rejected.** It stops feeding the fabricated-data problem by removing the data instead of the
fabrication, and it takes the wrong fields with it. `typicalWatts` is the field that
`critique-domain-realism.md B3` shows is *required* for the power maths to be correct at all,
nameplate is a UL thermal rating that no integrator sizes a circuit on. Removing it does not
make the app honest; it makes the app compute breaker loading from a number everyone in the
trade knows is wrong.

The fabrication problem is fixed at its source instead: `typicalWatts` no longer defaults to
half of nameplate, unknown is null, null is displayed and counted (CR-114, AC-039), and every
shipped template's numbers carry a citation (AC-052). Clearance and thermal class are cheap and
feed rules that are deferred rather than deleted; they stay in the catalog and their rules are
default-off.

### RJ-008 · `critique-feasibility.md` #5: the proposed v1 cut list

**The argument.** A ~5–6 month v1 that still demos the wedge: cut the device builder (ship
catalog + field overrides only), cut Structure bundles, CSV import and matrix entry (ship a flat
drop table and one label template), cut the rear-panel view, cut 58 of 70 DRC rules, cut
multi-sheet, cut `SignalRoute`/`Circuit`/`RevisionEntry`.

**Accepted except for two items, both rejected on the confirmed decisions.**

- **Cutting the device builder is not available.** Confirmed decision 2 is "Device builder
  **PLUS** a seeded catalog"; requirement 2 is "A GUI device builder lets the user create
  devices and specify their I/O." The builder ships. What is accepted is
  `critique-ux-simplicity.md`'s far better diagnosis (AC-049): the barrier is the 25 metadata
  fields in front of the grid, not the grid, and three required fields fixes it at almost no
  cost. The Quick Add DSL, archetype generators and TSV paste defer; the grid does not.
- **Cutting Structure matrix entry and CSV import is rejected** for the reasons in RJ-004, 
  they are the entry path for the workflow the field critique says is currently impossible.

Everything else in the cut table is accepted and appears in §2: `SignalRoute` (AC-016),
multi-sheet (AC-010), rear-panel view (CR-071), the rule reduction (AC-040), auto-layout
preview variants (CR-068). `Circuit` is retained but simplified (CR-028); `RevisionEntry` is
retained because the revision block generates from it and a drawing set without a revision block
is not a drawing set.

### RJ-009 · `critique-feasibility.md` #6: withdraw the user-extensibility claim wholesale

**The argument.** With rules moved to code, "you lose only user-authored rules, which have no
UI", and §3.4's enum-rejection argument should be weakened accordingly.

**Accepted for rules; rejected for registries.** User-authored *rules* are withdrawn (AC-011).
User-extensible *registries* stay, because one of them is already load-bearing in a shipped
flow: `design-ux-device-builder.md §6.4` states that unmatched media values in a CSV import
"are **not** rejected; they are created as new user media types with a confirmation chip", and
that behaviour is correct and is the difference between an import that works and one that
throws. A media-type editor and connector aliases ship (AC-050/A2.1). §3.4's other two arguments
against enums, growth rate and the impossibility of round-tripping an unknown enum member,
are untouched by the rules decision and are sufficient on their own.

### RJ-010 · `critique-domain-realism.md` m21: model grounding and bonding

**The argument.** No rack ground bar, no bonding conductor to the service panel, no coax ground
block, no TVSS. For commercial work the bonding detail is a required sheet; for residential the
coax ground block is a code item and a lightning-damage liability.

**Rejected for v1 beyond a minimum, accepted for v1.2.** The minimum ships now (AC-034/m21): an
F-type ground block template, a `power.bonding` signal family so a bonding conductor is
*drawable*, and `Rack.groundBarPresent` feeding a note on the elevation. The full model (busbar
entity, bonding-conductor sizing, a required bonding-detail sheet) is a commercial-market
feature that pulls in conductor sizing tables and a sheet type, and no residential v1 user is
blocked by its absence. The liability point is real and is discharged by making the ground block
present in the catalog and drawable, which is what puts it on the drawing.

### RJ-011 · `critique-domain-realism.md` B2, second half: `StructureBundle` becomes a bare grouping over Links

**The argument.** Delete `StructureDrop`; "the `StructureBundle` stays as a grouping over
Links."

**Accepted for the deletion (AC-019), rejected for the demotion.** `design-data-model.md §3.8`
is right that an outlet location is "the atomic unit of creation, specification and pricing";
it is what "add a TV location" creates, what gets priced, what carries the room, the wall, the
mounting height and the conduit, and what the outlet templates of CR-108 instantiate. Reducing
it to an unnamed grouping loses the entity the fast entry paths are built on. It is renamed
`Outlet`, its members become Links, and it keeps its identity and its fields (CR-016).

### RJ-012 · `critique-completeness.md` A2.1: build a registry authoring UI or drop the claim

**The argument.** There is no UI anywhere for creating a connector type, a signal family, a
media type outside Structure, a colour scheme or a compatibility rule, while user-extensible
registries are the central argument for rejecting enums. "Either build a registry editor or drop
the user-extensibility claim."

**Rejected as a binary.** The right answer is neither horn. Shipping in v1: a **media-type
editor** (already required by the CSV import flow, RJ-009), **connector aliases** (required by
the Quick Add DSL, CR-058), and a **per-family colour override** row in settings (required by
requirement 4, AC-054). Not shipping in v1: a signal-family editor, a colour-scheme editor,
and a rule editor. The claim that survives is narrowed and true, *"media types and colours are
user-extensible; signal families and connector types are catalog-updated"*, and it is written
into `design-data-model.md §3.4` in that form. A signal family is not a thing a user should be
inventing casually: it carries direction defaults, topology, length limits, and rule
applicability, and a hand-rolled one produces silently wrong validation.

### RJ-013 · `critique-completeness.md` C25: multi-document tabs

**The argument.** `design-architecture.md §8.6` says ship in-app document tabs; no UX document
shows them and no document specifies `Ctrl+N`/`Ctrl+O` with a dirty document open.

**Rejected for v1.** CR-119, v1 is single-document, single-window, with a three-button
save prompt on replace. A tab strip with no design is not a feature, and the per-document
`ProviderScope` already makes tabs mechanical when they are designed. The finding that the
behaviour was unspecified is accepted; the feature is not.

### RJ-014 · `critique-completeness.md` D6: an app update mechanism in v1

**The argument.** No app update mechanism exists; on Windows this means MSIX auto-update,
Squirrel, or manual downloads, and the choice affects signing and the installer.

**Rejected for v1; the dependency is accepted.** v1 ships a signed installer, a **"Check for
updates"** menu item that opens a download page, and a version string in the About box. Building
auto-update infrastructure before there is a release cadence is inventory. The part that
genuinely cannot wait (the code-signing certificate, whose OV/EV validation and reputation
build take weeks) is accepted and scheduled two milestones ahead of release (AC-058/D10). The
user-library migration half of D6 is accepted in full (AC-050/A8.2): `.rmdev` gets its own
migration chain, because a user's forty hand-built templates are the asset they will not forgive
you for breaking.

> **The certificate half is superseded — see §12.9 and §11.6.** There is no OV/EV validation and no reputation build, so nothing here needs scheduling two milestones ahead. RJ-014's actual ruling — no in-app auto-update in v1, a signed installer plus a version-check ping — is **reaffirmed**, and the `.rmdev` migration-chain half (AC-050/A8.2) is untouched.

### RJ-015 · `critique-completeness.md` D13: tagged / accessible PDF

**The argument.** No PDF tagging or structure spec, despite "selectable text in the schedule is
a real differentiator."

**Rejected for v1.** dart_pdf's tagging support is limited and an accessible PDF is its own
investigation with its own acceptance criteria, and the document itself flags this. What v1
commits to is the part that is free and is what the differentiator claim actually rests on:
**text is real text, not outlines, and is selectable and searchable**: an installer can
`Ctrl+F` a cable ID in a three-page schedule. Full PDF/UA tagging is a named v2 investigation.
The rest of D13 (printer margins, greyscale beyond wires, and the real-hardware print test
matrix) is accepted (AC-058).

### RJ-016 · `critique-completeness.md` C21: defer conductors and accept four rows for a 16/4 run

**The argument.** "Explicitly defer conductors to v1.1 and accept 4 rows on the pull sheet for a
16/4 run in v1."

**Rejected.** This is the one deferral that damages the deliverable rather than the tool. One
cable = one row on the pull sheet is the whole reason `Link`/`Conductor` was separated from
`Net` in the first place, and `design-data-model.md §3.6` argues it correctly: four rows for one
pull means four lengths to keep in sync, four labels for one cable, and an installer counting
four cables in a bag. Four rows on a pull sheet is a *worse* artifact than the Excel file the
product is replacing.

**What is accepted instead (AC-053):** the model and format ship conductors in v1, and the *v1
gesture* is limited to declared `atomicConnect` sets, dragging any member of a stereo pair or a
component-video triple connects the whole set in one action, producing one Link with N
conductors. Hand-authoring an arbitrary conductor map defers. A 16/4 to two zones is one row in
v1.

### RJ-017 · `critique-completeness.md` D9: branding as a v1 requirement

**The argument.** No icon, logo, wordmark, splash, window icon, document icon or colour identity;
no file-type registration; no trademark search; and "for a firm handing drawings to clients, the
integrator's logo is close to table stakes" in the PDF title block.

**Accepted except for the last clause.** Icon, wordmark, window and document icons, file-type
registration for `.rackmate` and `.rmdev`, and a trademark search before any certificate or
domain is bought are all accepted into the hardening milestone (AC-058), without file
association, double-click-to-open fails and the recents list is half-useful, which is a real
defect rather than a polish item.

**The integrator's logo in the title block is rejected for v1.** It requires a raster asset
inside the project, which reopens the container question that AC-057 just closed by cutting
images. The title block's *text* integrator block (firm, contact, licence number) ships in v1
and carries the same information. The logo lands with the v2 zip container, alongside device
images, as one change rather than two.

---

## 3.1 Coverage ledger

Every blocker and major from the four critiques, with its disposition. No finding is
undispositioned.

| Source | Finding | Disposition |
|---|---|---|
| feasibility | SEV-1 #1 units | **AC-001** |
| feasibility | SEV-1 #2a Y-flip · #2b router · #2c revision · #2d placement | **AC-002 · AC-003 · AC-004 · AC-005** |
| feasibility | SEV-1 #3 file size / port materialisation | **AC-006** |
| feasibility | SEV-1 #4 `measureText` baseline | **AC-007** |
| feasibility | SEV-1 #5 no roadmap / scope | **AC-017**; cut list partly **RJ-008** |
| feasibility | SEV-2 #6 rules as data | **AC-011**; extensibility claim partly **RJ-009** |
| feasibility | SEV-2 #7 label cache | **AC-009** |
| feasibility | SEV-2 #8 commit budget | **AC-008** |
| feasibility | SEV-2 #9 multi-sheet | **AC-010** |
| feasibility | SEV-2 #10 `part of` | **AC-013** |
| feasibility | SEV-3 #11–#20, SEV-4 #21–#24 | **AC-016** (with #12 → AC-012, #15 → AC-015, #16 → AC-014) |
| domain-realism | B1 unbound endpoints | **AC-018** |
| domain-realism | B2 home run modelled twice | **AC-019**; bundle demotion **RJ-011** |
| domain-realism | B3 power DRC blocks correct racks | **AC-020** |
| domain-realism | B4 no field devices | **AC-031** |
| domain-realism | B5 patch cords bury the schedule | **AC-026** |
| domain-realism | M6 one cable many services | **AC-021** |
| domain-realism | M7 depth arbitration | **AC-022** |
| domain-realism | M8 reversed chassis | **AC-023** |
| domain-realism | M9 no length mechanism | **AC-024** |
| domain-realism | M10 schedule organised wrong | **AC-025** |
| domain-realism | M11 three-device link | **AC-029** |
| domain-realism | M12 BUS-006 / ELE-003 | **AC-030** |
| domain-realism | M13 line-voltage / plenum | **AC-027** |
| domain-realism | M14 rear support | **AC-028** |
| domain-realism | m15–m24 | **AC-032 · AC-033 · AC-034**; m21 partly **RJ-010** |
| ux-simplicity | cut #1 schematic canvas | **RJ-001** (reduction accepted) |
| ux-simplicity | cut #2 `SignalRoute` | **AC-036** |
| ux-simplicity | cut #3 derive `Net` | **RJ-003** |
| ux-simplicity | cut #4 `Sheet` entity | **AC-037** (partial) |
| ux-simplicity | cut #5 layers | **AC-038** |
| ux-simplicity | cut #6 derived metrics | **AC-039** (reasoning) + **RJ-005** (remedy) |
| ux-simplicity | cut #7 DRC catalogue | **AC-040**; acknowledgement machinery **RJ-006** |
| ux-simplicity | cut #8 template versioning | **AC-041** |
| ux-simplicity | cut #9 Structure editor | **RJ-004** (substantially) |
| ux-simplicity | cut #10 template file infra | **AC-042** (partial) |
| ux-simplicity | cut #11 shelves | **AC-043** |
| ux-simplicity | cut #12 zero-U | **AC-044** (partial) |
| ux-simplicity | cut #13 auto-arrange | **AC-045** |
| ux-simplicity | cut #14 keyboard surface | **AC-046** |
| ux-simplicity | cut #15 "do NOT cut" list | **accepted wholesale** (G5) |
| ux-simplicity | one view for v1 | **RJ-002** |
| ux-simplicity | nine identifier systems | **AC-047** |
| ux-simplicity | friction inventory, cliffs #1–#6 | **AC-048** |
| ux-simplicity | device-builder metadata barrier | **AC-049** |
| ux-simplicity | three prioritisation fixes | **AC-035** |
| completeness | A1–A8 requirement gaps | **AC-050** (A2.1 partly **RJ-012**, A3.1 → AC-053, A4.1/A4.2 → AC-054, A7.3 → AC-055, A8.1 → AC-056) |
| completeness | B1–B88 contradictions | **§1, CR-001 … CR-120** |
| completeness | C1–C36 open decisions | **§1 and §2**; C21 **RJ-016**, C25 **RJ-013** |
| completeness | D1–D5, D7, D8, D10–D14 | **AC-058** |
| completeness | D6 upgrade paths | **AC-050/A8.2** + **RJ-014** |
| completeness | D9 branding | **AC-058** + **RJ-017** |
| completeness | D15 DRC testing, catalog provenance | **AC-051 · AC-052** |
| completeness | §E milestone plan | **AC-059** |

---

**End of Part 1.** Part 2 carries the normative model, the file-format contract, the rule
catalogue, the visual language, the keymap, and the milestone plan with its cut list, all of
which are downstream of the 120 rulings above and none of which may contradict them.



**Status:** NORMATIVE. Continues Part 1 (`canon-part1.md`). Supersedes all six `design-*.md`
documents wherever they disagree with it.
**Scope of Part 2:** canonical naming (§4), the canonical data model summary (§5), and the
canonical signal / cable type registry (§6).

Part 1 rulings are cited as `CR-nnn`, `AC-nnn`, `RJ-nnn` and the governing principles as
`G1`–`G5`. Nothing here may contradict them; where this document appears to add something, it is
applying a Part 1 ruling to a name, a field, or a data row.

---

## 4. Canonical naming

### 4.0 Why this section is binding

The six design documents produced, between them, three names for the wiring entity, four for the
device entity, four token vocabularies, two coordinate units, three severity vocabularies, and
two spellings of nearly every enum. Part 1 resolved which concept wins. §4 fixes the **spelling**,
because a resolved concept with three spellings is still three concepts by the time it reaches
code review.

Four rules govern every name below.

| # | Rule |
|---|---|
| **N1** | **One concept, one name, everywhere**: Dart identifier, JSON key, UI label, prose, commit message, and PDF column header all derive from the same entry in the glossary. Where the UI label must differ from the identifier (it often must, `Outlet` is "outlet location" to a user), both are listed and the mapping is fixed. |
| **N2** | **A banned word is banned in prose too.** `Connection` is not a synonym for `Link` in a comment. The words in §4.7 do not appear in the repository except in a migration note that explains their removal. |
| **N3** | **Types are `UpperCamelCase`; fields, JSON keys and Dart members are `lowerCamelCase`; registry IDs are `lower.dotted.snake`; format-engine tokens are `UPPER_SNAKE`; rule IDs are `AAA-000`.** No exceptions, including in `.rmdev` and `.rackmate`. |
| **N4** | **Units are in the name or in the type, never in a comment.** A field is `weightUg`, `depthNm`, `heightU`, `breakerAmps`, or it is typed `Mass`, `Len`, `Permille` and needs no suffix. A bare `weight` or `length` on a serialized field is a defect. |

`docs/glossary.md` is generated from §4.1–§4.6 and ships **in the app** as a searchable panel
(AC-058/D1). A name that is not in the glossary does not exist.

---

### 4.1 Core entity names

The binding entity vocabulary. "Owner" states which entity holds the foreign key; "Conflict unit"
states whether the entity carries `EntityMeta` per CR-095.

| Canonical type | UI label | What it is | Owner / key | Conflict unit |
|---|---|---|---|---|
| **`RackDocument`** | "project" | The in-memory mutable aggregate: flat UUID-keyed entity maps, mutated only through `Command`s. The thing `.rackmate` serializes. | root | ✅ |
| **`ProjectInfo`** | "project details" | Title-block metadata: client, site address, integrator, drawn/checked/approved by, drawing number. Field of `RackDocument`. | on document | — |
| **`ProjectSettings`** | "project settings" | Persisted per-project preferences: display units, ID formats, defaults, rule overrides. Field of `RackDocument`. | on document | — |
| **`Location`** | "location" | One node of the arbitrary-depth location tree (site ▸ building ▸ floor ▸ room ▸ zone ▸ outdoor). CR-047. | `parentId` self-ref | ✅ |
| **`Rack`** | "rack" | One physical enclosure or frame. Owns height, rails, depths, capacities, 0U channels. | `locationId` | ✅ |
| **`ZeroUChannel`** | "0U channel" | A vertical mounting channel inside a `Rack`. Sub-object, string-keyed within the rack. | inside `Rack` | — |
| **`Circuit`** | "circuit" | One branch circuit / breaker. Flat on the document with an optional `rackId`. CR-028. | `Circuit.rackId?` | ✅ |
| **`DeviceTemplate`** | "template" | The **mutable library** object. Lives in the catalog or user library. Never referenced by a device. | library | — |
| **`TemplateSnapshot`** | (not shown) | The **immutable, embedded** capture of a template at one version. Keyed `"$templateId@$version"`. | on document | — |
| **`TemplateBody`** | (not shown) | Everything physically true of the model. The payload of both of the above. | — | — |
| **`TemplateRef`** | (not shown) | `{templateId, version, contentHash}`: a device's pin to an exact snapshot. | on `DeviceInstance` | — |
| **`DeviceInstance`** | "device" | One piece of gear in this project. | `templateRef`, `placement` | ✅ |
| **`DeviceOverrides`** | "device overrides" | Typed, nullable per-instance overrides of `TemplateBody` facts. CR-053, AC-012. | on `DeviceInstance` | — |
| **`Placement`** | "placement" | Sealed union of five mounting variants. CR-031. Never called a slot. | on `DeviceInstance` | — |
| **`PortDef`** | (not shown) | The template-side port definition. Identified by `PortKey`. | inside `TemplateBody` | — |
| **`Port`** | "port" | The instance-side port. Graph identity; what a `Conductor` references. Lazily materialised (AC-006). | `deviceId` | ❌ |
| **`PortOverrides`** | "port overrides" | Typed per-port overrides. Lives **on the `Port`**, never in a device-keyed map. CR-053. | on `Port` | — |
| **`BankDef`** / **`Bank`** | "bank" | A **presentation** grouping of ports: drives symbol edges, brackets, collapse, and auto panel layout. CR-055. | `PortDef.bankKey` | ❌ |
| **`PortSetDef`** / **`PortSet`** | "port set" | An **electrical** grouping: Y/Pb/Pr, L/R, +/−, `atomicConnect`. Renamed from `PortGroupDef`. CR-055. | `PortDef.setKey` | ❌ |
| **`PassthroughPairDef`** | "paired port" | `{frontKey, rearKey, sameNet}` on a patch-panel template. CR-057. | inside `TemplateBody` | — |
| **`Link`** | "cable" / "run" | **One physical cable.** One `W###` designator, one schedule row, one thing a human pulls. | document map | ✅ |
| **`Service`** | "service" | One signal carried on a `Link`. A `Link` has `List<Service>`. CR-010. Hidden in the UI when there is exactly one. | inside `Link` | ❌ |
| **`Conductor`** | "conductor" | One electrical path within a `Link`, spanning exactly two `Endpoint`s. CR-014. | inside `Link` | ❌ |
| **`Endpoint`** | "end" | Sealed union: `PortEndpoint` · `PlaceEndpoint` · `OpenEndpoint`. AC-018. | inside `Conductor` | — |
| **`Breakout`** | "breakout" | A fan-out point on a multi-device `Link` (dual-head IR emitter, snake). CR-014. | inside `Link` | — |
| **`InlineAdapter`** | "adapter" | A **passive in-line** adapter with no independent cable on either side. CR-015. An adapter an installer pulls two cables to is a `DeviceInstance`, not this. | inside `Link` | — |
| **`Net`** | "net" | One **stored** logical equivalence class. Membership is the FK `Service.netId`, never a name. CR-011. | document map | ✅ |
| **`StructureBody`** | "structured wiring" | The body of a `DeviceInstance` with `kind == structure`. Renders as an edge bank of off-page flags. | `deviceId` | ✅ |
| **`StructureOrigin`** | (not shown) | The field-end facts a home-run `Link` carries: structure body, outlet, both labels, wall, height, field termination. AC-019. | on `Link` | — |
| **`Outlet`** | "outlet location" | **One wall plate / one ceiling location.** The atom of creation, specification and pricing. Renamed from `StructureBundle`. CR-016, RJ-011. | `structureBodyId` | ✅ |
| **`OutletTemplate`** | "outlet type" | A named recipe: "TV location", "AP", "Ceiling speaker pair". First-class; grades are presets. CR-108. | library | — |
| **`Pathway`** | "pathway" (UI may say "bundle") | A conduit, J-hook run, tray or trunk that N `Link`s share. Purely organisational. Carries `kind` and `containsLineVoltage`. CR-016, AC-027. | document map | ✅ |
| **`Sheet`** | "sheet" | One output sheet. Exactly one schematic `Sheet` exists in v1; the **exporter** partitions by domain. CR-073. | document map | ✅ |
| **`SheetItem`** | (not shown) | The placement of one entity on one sheet. **The only** symbol position and the only stacking order. CR-069. | inside `Sheet` | ❌ |
| **`Note`** | "note" | Annotation, anchored to any entity or free-floating. | document map | ✅ |
| **`RevisionEntry`** | "revision" | One row of the drawing revision block. Never conflated with `RackDocument.sequence`. CR-094. | document map | ✅ |
| **`Finding`** | "issue" | DRC output. **Computed, never stored.** | derived | — |
| **`AckedFinding`** | "acknowledgement" | The persisted acknowledgement of a finding, with a required reason at project scope. CR-019. | document map | ✅ |
| **`RuleOverride`** | "rule setting" | `{severity, reason, by, at}` per rule for this project. Replaces the bare severity map. CR-019. | in `ProjectSettings` | — |
| **`Tombstone`** | (not shown) | `{deletedAt, entityType, by}`. Ships in v1. CR-095, G5. | on document | — |
| **`EntityMeta`** | (not shown) | `{createdAt, updatedAt, updatedBy, localRevision, unknown}`. Carried by conflict units only. CR-095. | on conflict units | — |

**Registry types**: see §6 for their contents.

| Canonical type | What it is |
|---|---|
| **`Registries`** | The embedded subset of catalog data this document actually references, at the version used. |
| **`SignalDomainDef`** | **New in Part 1 (CR-078).** Owns the visual language: colour, dash, weight, glyph, tag prefix. Eight entries. |
| **`SignalFamilyDef`** | One signal family. Carries `domain` (FK), `shortTag`, capability limits, `topologyFree`, and an optional `colorOverride` / `dashOverride` / `glyphOverride`. |
| **`ConnectorTypeDef`** | One connector. Carries `genderApplies`, `matesWith`, contact count, footprint. |
| **`MediaTypeDef`** | One cable/medium. Carries conductor and pair counts, impedance, jackets, channel length, `isPathwayOnly`. |
| **`CableSpecDef`** | One manufacturer part number bound to a `MediaTypeId`. Optional throughout. |

---

### 4.2 Canonical field names

Only the fields that were spelled more than one way, or whose spelling is load-bearing.

| Canonical field | On | Type | Ruling | Never call it |
|---|---|---|---|---|
| `ruIndex` | `RailPlacement` | `int`, **1-based, bottom origin** | CR-025 | `bottomU`, `startU`, `slot`, `position` |
| `heightU` | `Rack` | `int`, 1..60 | CR-038 | `ru`, `units`, `size` |
| `ruNumbering` | `Rack` | enum, per-rack | CR-026 | a project-only setting |
| `designator` | `Rack`, `DeviceInstance`, `Link`, `Port`, `Net`, `Circuit` | `String`, **stored at allocation** | CR-041, CR-048 | `refDes`, `refDesPrefix`, `tag`, `id` |
| `designatorLocked` | `DeviceInstance`, `Link` | `bool` | CR-034 | `refDesLocked` |
| `startTwelfth` / `spanTwelfths` | `RailPlacement` | `int` 0..11 / 1..12 | CR-030 | `xOffset`, `widthFraction` |
| `chassisRotation` | `RailPlacement` | `normal \| reversed` | AC-023 | `flipped`, `backwards` |
| `locked` | every `Placement` variant | `bool` | CR-034 | `pinned` (that word belongs to `SheetItem`) |
| `order` | `Location`, `Rack`, `Link`, `Outlet`, `PortDef`, `BankDef`, `ShelfPlacement`, `Sheet` | **`FracIndex`** | CR-027 | `int order`, `sortOrder`, `bayOrder`, `index` |
| `pinned` | `SheetItem` | `bool` | CR-068 | `manual`, `locked` |
| `weightUg` | serialized `Mass` fields | `int` µg | CR-003 | `weightKg`, `weightLb`, `weightGrams` |
| `depthNm`, `lengthNm`, `xNm` | serialized `Len` fields | `int` nm | CR-001, CR-063 | `depthMm`, `xMm`, tenths, hundredths |
| `bodyDepth`, `connectorProjection`, `chassisWidth` | `TemplateBody` | `Len` | AC-022, AC-032 | — |
| `maxUnsupportedMass` | `TemplateBody` | `Mass?` | AC-028 | — |
| `routedLength` / `cutLength` / `terminatedLength` | `Link` | `Len?` ×3 | AC-024 | `calculatedLength` (deleted), `lengthFt` |
| `media` | `Link` | `MediaTypeId` | CR-008 | `cableType` |
| `class` (Dart: `linkClass`) | `Link` | `fieldCable \| jumper \| powerCord \| internal` | AC-026 | `kind`, `category` |
| `signalFamily` | `Service`, `PortDef`, `Net` | `SignalFamilyId` | CR-009 | on `Link`; it is derived there |
| `dominantSignalFamily` | `Link` | derived, **never serialized** | CR-009, CR-115 | a stored field |
| `netId` | `Service` | `Uuid`, non-null | CR-010 | on `Link` (deleted) |
| `lifecycleStatus` | `DeviceInstance`, `Link` | `existing \| new \| future \| removed \| designIntent` | CR-064, CR-065, AC-018 | `status` bare, `layerId` |
| `roughInStatus` | `Link` | `planned \| pulled \| dressed \| terminated \| tested` | CR-065 | `status` bare; `issued` is deleted |
| `fieldLabel` / `rackLabel` | `StructureOrigin` | `String` / `String?`, both project-unique, **both print** | CR-044, AC-047 | `label` / `TIA-606 ID` as field names |
| `code` | `Location` | `String` | CR-046 | `abbr` |
| `estimatedRunLengthFromRack` | `Location` | `Len?` | AC-024 | — |
| `usableDepth` | `Rack` | `Len?` (nullable, 2-post) | AC-050/A1.3 | — |
| `poeBudgetWatts`, `apparentVA`, `powerFactor` | `PowerProfile` | `int?` ×3 (`powerFactor` in permille) | CR-056, AC-020 | undeclared JSON keys |
| `nameplateWatts` / `typicalWatts` | `PowerProfile` | `int?` (**`typicalWatts` never defaults to half of nameplate**) | AC-039, RJ-007 | — |
| `sequence` | `RackDocument` | `int`, strictly monotonic, persisted, the sync cursor | CR-094 | `revision` |
| `stateId` | `RackDocument` | in-memory only, non-monotonic, drives `isDirty` | CR-094 | `revision` |
| `schemaVersion` / `minReaderVersion` | envelope | `int` ×2 | CR-092 | — |
| `sheetEdge` | `StructureBody` | `left \| right`, default `left` | CR-072 | — |
| `mirrorRearElevation` | `Rack` | `bool`, default `true`, project default seeds it | CR-035 | a project-only setting |
| `groundBarPresent` | `Rack` | `bool` | AC-034/m21 | — |
| `containsLineVoltage` / `kind` | `Pathway` | `bool` / `PathwayKind` | AC-027 | — |
| `tia570Grade` | `Outlet` | `String?`: a **standards tag**, not an enum axis | CR-108 | `StructureGrade` |
| `isPathwayOnly` | `MediaTypeDef` | `bool` | CR-109 | — |
| `topologyFree` | `SignalFamilyDef` | `bool` | AC-030 | a hard-coded suppression array |
| `genderApplies` | `ConnectorTypeDef` | `bool` | CR-059 | — |
| `key` / `renamedFrom` | `PortDef` | `PortKey` / `List<PortKey>`: **the** template migration join | CR-051 | `portId` |
| `unknown` | every persisted object | `Map<String, Object?>`, preserved and re-emitted | §4.4 forward-compat | — |

---

### 4.3 Canonical view, sheet and output names

| Canonical name | What it is | Notes |
|---|---|---|
| **Rack Editor** | The elevation authoring view. `Ctrl+1`. | Not "rack view", not "elevation editor". |
| **Schematic** | The wiring authoring view. `Ctrl+2`. **The only place connections are created in v1.** CR-105. | Not "diagram", not "wiring canvas". |
| **Rear Panel view** | The interactive rear-panel view. `Ctrl+3`. **v1.1.** CR-071. | The rear elevation still *prints* in v1. |
| **Schedule** | The live schedule table. `Ctrl+4`. **The second tab in the app**, populated from an empty project. AC-035. | Not "table view", not "BOM". |
| **Staging Bin** | The UI surface for devices with `StagedPlacement`. A query, not an entity. CR-032. | Not "unplaced", not "tray". |
| **Locations panel** | `Project ▸ Locations…`: project-level, **not** owned by the Structure editor. CR-112. | — |
| **Structure editor** | Opens in **table mode**; matrix mode is a tab. AC-048/cliff #4. | — |
| **Device Builder** | Template authoring. **Three required fields** (name, RU height, designator prefix) then ports. AC-049. | — |
| **Pull Sheet** | Field-cable schedule preset: portrait, sorted **room then pathway**, with `Pulled ☐ Terminated ☐ Tested ☐ Init ___`. AC-025. | Excludes `jumper` and `powerCord` by default. AC-026. |
| **Termination Schedule** | Rack-side schedule preset: landscape, sorted **rack, panel, port**, with pinout, punch position, polarity and conductor colour. AC-025. | — |
| **Equipment List and Materials** | Sheet `T6.30`. **No pricing.** Includes the cable footage rollup by media with waste factor. AC-055, AC-024. | Never called a BOM. `Money`, `cost`, `supplier`, `purchaseOrder` are deleted from v1. |
| **Exceptions & Acknowledgements** | Sheet `T0.02`. Every open finding and every acknowledgement with reason, author, date. CR-022. | This is where "the reason prints". |
| **Symbol Legend** | Sheet `T0.01`. **One row per named cable type**, in colour and greyscale side by side. AC-054. | Other sheets' title blocks are auto-filled with `SYMBOL LEGEND: SEE SHEET T0.01`. CR-023. |
| **Unused Home Runs** | The page listing home-run `Link`s with an unbound rack end. | A differentiator; keep the name. |
| **`ISSUED FOR CONSTRUCTION`** | The stamp. Gated on zero open errors. **Never gates bytes.** CR-022, G3. | — |

Sheet numbering is `ProjectSettings.sheetNumbering: ncs | simple`, **default `simple`** (CR-066).

---

### 4.4 Canonical concept names

| Canonical term | Meaning | Never |
|---|---|---|
| **the schedule** | The tabular deliverable. G1: *the schedule is the deliverable; the drawing is the receipt.* | "the table" |
| **the drawing** | The sheet set. | "the diagram", "the print" |
| **conflict unit** | An entity that carries `EntityMeta` and is an LWW unit for future sync. CR-095. | — |
| **materialised port** | A `Port` serialized because it carries project state; others are key-joined at load. AC-006. | "real port" |
| **deterministic port ID** | `uuidv5(deviceId, portKey)` for template-derived ports. AC-006. | — |
| **acknowledgement** | An `AckedFinding`. Reason **required** only at project scope. CR-019, RJ-006. | "dismissal", "mute", "suppression" |
| **spring-back** | The gesture-level refusal with a reason chip and `[ Connect anyway ]`. CR-017. | "blocked", "invalid", "Class A" |
| **the gesture may hesitate; the document may not lie** | The binding validation frame. CR-017. | — |
| **copy-on-place** | v1's template binding: snapshot embedded, no update manager. AC-041. | "pinning", "vendoring" |
| **the three doors** | Edit this device only · Edit the template · Fork to a new template. CR-054. | "detach" (deleted) |
| **domain partition** | The exporter's sheet split. Produces **zero** cross-sheet connections by construction. CR-073. | "multi-sheet" |
| **tag pill** | The `W042 · HDMI · 25 ft` label on a run at both ends. | "label", "badge" |
| **home run** | A `Link` with a `PlaceEndpoint` field end and a `StructureOrigin`. AC-019. | "drop" |
| **drop** | UI-only word for a home run inside the Structure editor's table. | a model entity |
| **diagram unit** | 1 diagram unit = 1 PDF point = 1/72 in, `double` at the canvas boundary only. CR-007. | a persisted unit |
| **grid unit (`gu`)** | `Len(2_500_000)` = 2.5 mm. Schematic pitch; pin pitch 2 gu. CR-004. | "U" (that means rack unit) |
| **rack unit (`U`)** | `Len(44_450_000)` = 44.45 mm exactly. CR-001, CR-002. | — |

---

### 4.5 Canonical identifiers, formats and tokens

| Thing | Canonical form | Ruling |
|---|---|---|
| Device designator | `{TYPE_PREFIX}{SEP}{SEQ}`: ships as `MTX-1`, `AMP-12` | CR-041 |
| Port designator | `J{PORT_SEQ:2}` → `J01`, **unique within the device** | CR-042 |
| Link designator | `W{SEQ:3}` → `W042` | CR-008, ASME Y14.44 |
| Cable end (implicit) | `P###`: not stored; ASME convention referenced on the legend | — |
| Net designator | `N{SEQ:3}` → `N012`; `Net.name` generated, editable, **never load-bearing** | CR-049 |
| Outlet field label | `{ROOM_ABBR}-{SERVICE}-{SEQ}` → `LR-TV-1` (preset: Residential CI) | CR-044 |
| Outlet rack label | `{FLOOR}{SPACE}-{PANEL}{PORT:2}` → `1A-A12` (preset: TIA-606 Class 2) | CR-044 |
| Rule ID | `AAA-000`: `TOP` `SIG` `DIR` `CON` `ELE` `NET` `PWR` `LEN` `RCK` `BUS` `CODE` `SEQ` `LNK` | CR-021 |
| Registry ID | `lower.dotted.snake`, reverse-hierarchical: `video.hdmi.2_1`, `conn.rj45`, `media.cat6a_futp` | CR-058 |
| Registry alias | bare trade names (`hdmi`, `hdbt`, `rj45`, `xlr`, `spdif`) as `aliases: List<String>` | CR-058 |
| Template snapshot key | `"$templateId@$version"` | CR-050 |
| Format-engine token | `UPPER_SNAKE` | CR-045 |

**The format engine** is one grammar, one registry, one parser, in `rackmate_core/idformat/`
(CR-045). Five call sites share it: device, port, link, outlet field label, outlet rack label.
Grammar: `{TOKEN}`, `{TOKEN:n}` zero-pad, `[...]` optional segment, `|upper` `|first n` `|nz`
filters, `{{` / `}}` literal braces. Collisions resolve by
`CollisionPolicy{suffixLetter | suffixNumber | error}`, project-wide.

Canonical token vocabulary (the merge of four; collisions resolved to the longer, unambiguous
name, CR-045):

`SITE` · `BUILDING` · `FLOOR` · `SPACE` · `TR` · `ROOM` · `ROOM_ABBR` · `AREA` · `ZONE` ·
`RACK` · `PANEL` · `PORT` · `OUTLET` · `PATHWAY` · `SERVICE` · `MEDIA` · `DOMAIN` ·
`TYPE_PREFIX` · `SEQ` · `DEV_SEQ` · `PORT_SEQ` · `DEV_BLOCK` · `SRC_REFDES` · `SRC_PORT` ·
`DST_REFDES` · `DST_PORT` · `DEVICE` · `DIR` · `RUN` · `N`

**Every designator is evaluated once at creation and stored** (CR-048, P5). Nothing is recomputed
at render time. Changing a scheme offers a renumber with a diff, never a silent rewrite, and
never touches a locked ID (CR-034).

---

### 4.6 Canonical file, package and asset names

| Name | What it is |
|---|---|
| **`.rackmate`** | A project. **Plain, pretty-printed, key-sorted UTF-8 JSON** with a `document` wrapper. CR-091, CR-092. `DocumentCodec` sniffs `PK\x03\x04` from commit one so a v2 zip container is a non-event. |
| **`.rmdev`** | A single device template. Plain JSON, same unit regime as `.rackmate`, `depthNm`, `weightUg`. CR-063. Has its own migration chain. AC-050/A8.2. |
| **`.bak`** | The single sibling backup of a `.rackmate`. No `.history/` folder. CR-098. |
| **`.rmlib`** | Library pack. **Cut from v1.** AC-042. |
| `rackmate_core` | Pure Dart. No `package:flutter`, no `dart:ui`, **no `package:pdf`**. Model, commands, derived, routing, `draw/` (scene builders, `hit_test.dart`, `BoundsCanvas`), persistence, `units/`, `idformat/`, `library/`. Declares abstract `TextMeasurer` + `TextMetrics`. |
| `rackmate_text` | Pure Dart. `rackmate_core` + `package:pdf` for `PdfTtfFont` only. ~5 files. **The single concrete `TextMeasurer`.** CR-083. |
| `rackmate_export` | Pure Dart. `PdfDiagramCanvas`, sheets, furniture, tables, assembly. The isolate entry point. |
| `rackmate_ui` | Flutter. `FlutterDiagramCanvas`, render objects, widgets, `canvas/input/`. |
| `apps/rackmate` | The app. |
| `docs/glossary.md` | Generated from §4. Ships in-app. |
| `docs/rules.md` | **The one rule catalogue.** A rule not in it does not exist. CR-021. |
| `docs/visual-language.md` | Colour, dash, weight, glyph, LOD, and the dash-phase-on-arcs caveat. CR-079, AC-016/#17. |
| `docs/keymap.md` | Generated from the single `Intent` registry. ~40 bindings. CR-101. |
| `docs/catalog.md` | **The only place a template count is stated.** CR-061. |
| `docs/file-format.md` | The envelope, the migration chain, the byte-round-trip contract. CR-093, CR-117. |
| `assets/catalog/sources.md` | A cited source for every numeric field in every shipped template. AC-052. |
| Fonts | `RackBody` = IBM Plex Sans (Regular + SemiBold) · `RackCond` = IBM Plex Sans Condensed · `RackMono` = IBM Plex Mono (Regular + Bold) · fallback Noto Sans Symbols 2. SIL OFL 1.1. CR-080. |

---

### 4.7 Banned names

These appear in one or more design documents and are **deleted**. N2 applies: they do not appear
in code, JSON, UI, or prose.

| Banned | Use instead | Ruling |
|---|---|---|
| `Connection` | `Link` | CR-008 |
| `PhysicalLink` | `Link` | CR-008, CR-090 |
| `LogicalSignal` | `Service` (on a Link) or `Net` (equivalence class) | CR-008, CR-010 |
| `CableType`, `SignalType` | `SignalFamilyDef` + `ConnectorTypeDef` + `MediaTypeDef` | CR-008 |
| `SignalRoute` |: (cut from v1; `Trace` computes paths on demand) | AC-016/#11, AC-036 |
| `RackProject`, `Device`, `RackDevice` | `RackDocument`, `DeviceInstance` | CR-090 |
| `RackSlot`, "slot" | `Placement` | data-model §0 |
| `StructureDrop` | a `Link` with a `StructureOrigin` | CR-107, AC-019 |
| `StructureBundle`, bare "Bundle" | `Outlet` (location) or `Pathway` (conduit) | CR-016 |
| `PortGroupDef`, `PortGroup` | `PortSetDef` / `PortSet` (electrical) or `BankDef` / `Bank` (presentation) | CR-055 |
| `bottomU` | `ruIndex` | CR-025 |
| `refDes`, `refDesPrefix` | `designator`, `Rack.designator` | CR-040, CR-041 |
| `Layer`, `layerId` | `LifecycleStatus` (+ `Sheet.lifecycleFilter`) | CR-064, CR-067 |
| `viewKind` | `Sheet.kind` | CR-075 |
| `blockExportOnErrors` | `ExportSpec.issuedForConstruction` | CR-022 |
| `greyscaleSafeExport` | `ExportSpec.palette: colour \| greyscale \| cmyk` | CR-077 |
| `ruleSeverityOverrides: Map<String, Severity>` | `Map<String, RuleOverride>` | CR-019 |
| `RulePredicate` | Dart functions in a registry keyed by `ruleId` | CR-024, AC-011 |
| `RendererCaps` |: (deleted; the interface is the common denominator) | CR-088 |
| `ObstacleField`, `RouteCache`, "obstacle-aware" | Sugiyama + interval-graph channel routing, full recompute | CR-013 |
| `RouteWaypoint`, `waypointsBySheet`, `routeOverrides` |: (no route geometry persisted in v1; `routeConstraintsBySheet` in v1.2) | CR-012 |
| `DeviceInstance.localTemplate`, `PlacedDevice.snapshot` | `RackDocument.templates`: one snapshot store | CR-054 |
| `Extent`, `Known`, `Unknown` | `null` means unknown, everywhere; rollups report their unknown count | CR-114, G4 |
| `calculatedLength` | `routedLength` / `cutLength` / `terminatedLength` | AC-024 |
| `StructureGrade` (enum) | `OutletTemplate` + `Outlet.tia570Grade: String?` | CR-108 |
| `Gender.jack`, `Gender.plug` | `male \| female \| genderless` + `ConnectorTypeDef.genderApplies` | CR-059 |
| `Severity.info` | `Severity.advisory` | CR-018 |
| "Class A" | spring-back with a reason chip | CR-017 |
| `Money`, `cost`, `supplier`, `purchaseOrder` |: (cut from v1; the sheet is an Equipment List, not a BOM) | AC-055 |
| `frontImage`, `rearImage` |: (cut from v1) | AC-057 |
| `Bay` |: (cut from v1, not reserved) | CR-033 |
| `Status` as a bare column header | `LIFECYCLE`, `ROUGH-IN`, or `ISSUES` | CR-065 |

> **Superseded in part — see §12.1 (§7.2.3 router row).** The banned names in the left column stand (§12.1, CR-013 row); the replacement named in the right column is now Sugiyama phases 0–3 plus a deterministic orthogonal staircase.

---

## 5. Canonical data model summary

### 5.0 Shape, after the Part 1 rulings

The document is a **flat set of UUID-keyed entity maps**, never a tree, mutated **only** through
undoable `Command`s. Physical facts live on immutable, versioned `TemplateSnapshot`s embedded in
the file; project facts live on `DeviceInstance`. Wiring is three layers, not two:
`Link` (one cable) → `Service` (one signal on it) → `Conductor` (one electrical path), with
`Net` as the stored logical equivalence class hanging off `Service.netId`. Validation never
blocks the pen. **Every persisted number is an integer.**

Six shape changes from `design-data-model.md`, all forced by Part 1:

1. `Link` gained `services: List<Service>`; `Link.netId` moved to `Service.netId` (CR-010).
2. A `Conductor` end is a sealed `Endpoint`, so a cable can be scheduled before the device at
   its far end exists (AC-018).
3. `StructureDrop` is gone; a home run **is** a `Link` carrying `StructureOrigin` (AC-019).
4. `Outlet` and `Pathway` are first-class; "bundle" names nothing (CR-016).
5. `SignalDomainDef` exists and owns the visual language; `SignalFamilyDef` no longer carries a
   43-entry palette (CR-078).
6. `EntityMeta` is carried by conflict units only; sub-objects carry a bare `unknown` map
   (CR-095, AC-006).

### 5.1 Entity–relationship overview

```
RackDocument ─────────────────────────────────────────────────────────────────┐
 │ id, schemaVersion, minReaderVersion, sequence, info, settings               │
 │                                                                             │
 ├─1:N─▶ Location             (tree, arbitrary depth; parentId self-ref)       │
 ├─1:N─▶ Rack                 (└─ ZeroUChannel[] inline)                       │
 ├─0:N─▶ Circuit              (flat; optional rackId)                          │
 │                                                                             │
 ├─1:N─▶ TemplateSnapshot     ◀── IMMUTABLE, content-addressed, refcounted     │
 │        │ key = "$templateId@$version"                                       │
 │        └─ TemplateBody ─┬─1:N─▶ PortDef          (key: PortKey, + renamedFrom)
 │                         ├─0:N─▶ BankDef          (presentation grouping)    │
 │                         ├─0:N─▶ PortSetDef       (electrical grouping)      │
 │                         └─0:N─▶ PassthroughPairDef                          │
 │                                                                             │
 ├─1:N─▶ DeviceInstance                                                        │
 │        │ templateRef ────────────────▶ TemplateSnapshot                     │
 │        │ designator, name, lifecycleStatus, placement, overrides, locationId│
 │        ├─0:N─▶ Port         (OWNED; lazily materialised; templatePortKey)   │
 │        └─0:1──▶ StructureBody   (iff kind == structure)                     │
 │                  └─1:N─▶ Outlet ──1:N─▶ (Link, via Link.structureOrigin)    │
 │                                                                             │
 ├─1:N─▶ Link                 ◀── ONE PHYSICAL CABLE. one W###. one row.       │
 │        │ designator, class, media, jacket, gauge, lengths, statuses         │
 │        ├─1:N─▶ Service     { signalFamily, netId, conductorRoles[], label } │
 │        ├─1:N─▶ Conductor   { role, from: Endpoint, to: Endpoint, pair, … }  │
 │        ├─0:N─▶ Breakout                                                     │
 │        ├─0:N─▶ InlineAdapter                                                │
 │        ├─0:1──▶ StructureOrigin  (home runs only)                           │
 │        └─0:1──▶ pathwayId ─────▶ Pathway                                    │
 │                                                                             │
 ├─1:N─▶ Net                  ◀── STORED. membership = Service.netId (FK)      │
 ├─0:N─▶ Pathway              (conduit / j-hook / tray; containsLineVoltage)   │
 │                                                                             │
 ├─1:N─▶ Sheet                └─1:N─▶ SheetItem  (position, pinned, zOrder)    │
 ├─0:N─▶ Note                                                                  │
 ├─0:N─▶ RevisionEntry                                                         │
 ├─0:N─▶ AckedFinding         ◀── Findings are computed; only acks persist     │
 ├─1:1──▶ Registries  { signalDomains, signalFamilies, connectors, media,      │
 │                      cableSpecs, outletTemplates }                          │
 └─1:1──▶ Tombstones  Map<Uuid, {deletedAt, entityType, by}>                   │
```

**Cardinality notes that matter.**

- A `Port` is owned by exactly one `DeviceInstance` and **never shared**. A patch panel's front
  and rear jacks are two `Port`s bound by a `PassthroughPairDef`.
- `Link → Conductor` is 1:N. A 16/4 speaker cable is **one Link with four Conductors**: one row
  on the pull sheet, one thing a human pulls (RJ-016).
- `Link → Service` is 1:N. One Cat5e carrying an IR run, a 12 V trigger and RS-232 on separate
  pairs is one Link with three Services (CR-010, AC-021).
- Each **`Conductor`** spans exactly two endpoints; a **`Link`** may reach N devices via
  `Breakout`s (CR-014).
- `TemplateSnapshot` is immutable and content-addressed: it can never be a sync conflict and
  never a dangling edit. Insertion and removal are explicit refcounted child commands (AC-015).

### 5.2 Primitives and value types

```dart
extension type const Uuid(String v)           { }   // UUIDv7 for entities
extension type const SignalDomainId(String v) { }   // "video.digital"
extension type const SignalFamilyId(String v) { }   // "video.hdmi.2_1"
extension type const ConnectorTypeId(String v){ }   // "conn.hdmi_a"
extension type const MediaTypeId(String v)    { }   // "media.cat6a_futp"
extension type const PortKey(String v)        { }   // "hdmi_out_3"  template-stable
extension type const TemplateId(String v)     { }
extension type const FracIndex(String v)      { }   // LexoRank "a0", "a0V", "a1"

/// int64 NANOMETRES. The load-bearing unit choice. CR-001.
/// 1 in = 25 400 000 nm · 1 U = 44 450 000 nm · 1/32 in = 793 750 nm — all exact.
extension type const Len(int nm) { }

/// int64 MICROGRAMS. 1 lb = 453 592 370 µg exactly. CR-003.
extension type const Mass(int ug) { }

/// Parts per thousand. Power factor, line weight, slack, diversity factor.
extension type const Permille(int v) { }

/// Schematic canvas coordinate. INTEGER grid units, 1 gu = Len(2_500_000). CR-004.
/// No sub-grid. No sx/sy. No free positioning.
final class Pt { final int gx, gy; const Pt(this.gx, this.gy); }

final class Rgb { final int r, g, b, a; }

/// Carried by CONFLICT UNITS ONLY. CR-095.
final class EntityMeta {
  DateTime createdAt, updatedAt;      // UTC, microsecond
  String   updatedBy;
  int      localRevision;
  Map<String, Object?> unknown = {};  // forward-compat: preserve and re-emit
}
```

Constants, defined once in `rackmate_core/units/`:
`kRackUnit = Len(44_450_000)` · `kGridUnit = Len(2_500_000)` · `kPinPitch = 2 gu` ·
`kBtuPerWattHour = 3.412142` · `kBankCollapseThreshold = 8` · `kMaxRackHeightU = 60`.
Two tests are written **before any other code**: exact 1/32-in inter-panel clearance, and zero
accumulated error across a 45U stack (AC-001).

### 5.3 Document, settings, info

```dart
final class RackDocument {
  final Uuid id;
  int schemaVersion, minReaderVersion;      // 1, 1
  String appVersion;                        // diagnostics only
  DateTime createdAt, modifiedAt;

  int sequence;                             // strictly monotonic; ++ on EVERY committed
                                            // transaction AND on every undo/redo. Persisted.
                                            // The sync cursor. CR-094.
  int stateId;                              // in-memory only; isDirty == stateId != savedStateId

  ProjectInfo info;
  ProjectSettings settings;

  Map<Uuid, Location>       locations = {};
  Map<Uuid, Rack>           racks     = {};
  Map<Uuid, DeviceInstance> devices   = {};
  Map<Uuid, Port>           ports     = {};   // MATERIALISED ports only. AC-006.
  Map<Uuid, Net>            nets      = {};
  Map<Uuid, Link>           links     = {};
  Map<Uuid, Pathway>        pathways  = {};
  Map<Uuid, Outlet>         outlets   = {};
  Map<Uuid, StructureBody>  structures = {};
  Map<Uuid, Circuit>        circuits  = {};
  Map<Uuid, Sheet>          sheets    = {};   // exactly one schematic sheet in v1. CR-073.
  Map<Uuid, Note>           notes     = {};
  Map<Uuid, AckedFinding>   ackedFindings = {};

  Map<String, TemplateSnapshot> templates = {};   // key "$templateId@$version"
  Registries registries;

  List<RevisionEntry> revisionBlock = [];
  Map<Uuid, Tombstone> tombstones = {};
  EntityMeta meta;
}

final class ProjectInfo {
  String projectName, projectNumber, drawingNumber;   // AVIXA D401.01 title block
  String clientName;
  Address siteAddress;
  String integratorName, integratorContact, integratorLicense;   // text; no logo in v1. RJ-017.
  String drawnBy, checkedBy, approvedBy;
}

final class ProjectSettings {
  UnitSystem displayUnits;                 // AUTHORITATIVE over the app preference. CR-097.
  RuNumbering defaultRuNumbering;          // seeds Rack.ruNumbering. CR-026.
  bool defaultMirrorRearElevation;         // seeds Rack.mirrorRearElevation. CR-035.
  SheetNumbering sheetNumbering;           // ncs | simple — DEFAULT simple. CR-066.

  // Format engine. One grammar, one parser. CR-045, CR-048.
  IdFormat deviceDesignatorFormat;         // "{TYPE_PREFIX}{SEP}{SEQ}"      → "MTX-1"
  IdFormat portDesignatorFormat;           // "J{PORT_SEQ:2}"                → "J01"
  IdFormat linkDesignatorFormat;           // "W{SEQ:3}"                     → "W042"
  IdFormat netNameFormat;
  IdFormat outletFieldLabelFormat;         // "{ROOM_ABBR}-{SERVICE}-{SEQ}"  → "LR-TV-1"
  IdFormat outletRackLabelFormat;          // "{FLOOR}{SPACE}-{PANEL}{PORT:2}" → "1A-A12"
  String designatorSeparator;              // "-"; may be empty ⇒ "MTX1"
  int designatorPad;                       // 0; 2 ⇒ "MTX-01"
  CollisionPolicy collisionPolicy;
  int designatorBlockSize;                 // reserve blocks for commercial port numbering

  Map<String, RuleOverride> ruleOverrides; // {severity, reason, by, at}. CR-019.
  Map<SignalFamilyId, Rgb> familyColorOverrides;   // ships in v1. AC-054.
  Map<String, Permille> diversityFactorsByCategory; // amplifiers 350‰ default. AC-020.
  Permille cableWasteFactor;               // 100‰ default, for the footage rollup. AC-024.

  MediaTypeId defaultNetworkMedia;
  int defaultRackHeightU;                  // 12
  int defaultLineVolts;                    // 120 — seeds new Circuits. CR-039.
}
```

`ProjectSettings.blockExportOnErrors` and `greyscaleSafeExport` **do not exist** (CR-022, CR-077).
Export options live on `ExportSpec`: `{palette: colour|greyscale|cmyk, issuedForConstruction,
paper, preset, maxPages}`, and the screen theme never affects the export.

### 5.4 Location, Rack, Circuit

```dart
final class Location {
  final Uuid id;
  Uuid? parentId;
  LocationKind kind;              // site|building|floor|room|zone|outdoor
  String name;                    // "Master Bedroom"
  String code;                    // "MBR" — feeds {ROOM_ABBR}. CR-046.
  int? floorNumber; String? spaceCode;
  Len? estimatedRunLengthFromRack;   // ONE number per room ⇒ 62 usable estimates. AC-024.
  FracIndex order;
  EntityMeta meta;
}

final class Rack {
  final Uuid id;
  String name, designator;        // "RK-1" — the ONLY rack identifier. CR-040.
  Uuid? locationId;

  int heightU;                    // 1..60, asserted. Advisory above 50. CR-038.
  RuNumbering ruNumbering;        // per-rack; DISPLAY ONLY, never affects ruIndex. CR-026.
  bool mirrorRearElevation;       // per-rack, default true; NOT MIRRORED chip when off. CR-035.

  RackWidthClass widthClass;      // eia19|eia23|tenInch|etsi|customWidth
  Len? customPanelWidth;
  RailType railType;              // tapped10_32|tapped12_24|squareCageNut|roundClearance|m6
  bool fullHoleRail;
  RackFormFactor formFactor;      // floorEnclosure|openFrame4Post|openFrame2Post|wallSwingGate
                                  // |wallPivotCabinet|wallFixed|credenzaFurniture|portableCase
                                  // Gates RCK-004, RCK-007, RCK-008. AC-034/m19, m20.

  Len? usableDepth;               // NULLABLE — 2-post has none; depth rules skip. AC-050/A1.3
  Len? overallDepth, overallWidth, overallHeight;
  Mass? weightCapacity, ownWeight;

  bool isSwingFrame; HingeSide? hingeSide;
  bool hasFrontDoor, hasRearDoor;
  Len? frontDoorClearance, rearDoorClearance;
  bool groundBarPresent;          // feeds a note on the elevation. AC-034/m21.

  List<ZeroUChannel> zeroUChannels;
  FracIndex order;
  EntityMeta meta;
}

final class Circuit {
  final Uuid id;
  String designator;              // "Panel A / Breaker 14"
  Uuid? rackId;                   // flat on the document; the inspector filters. CR-028.
  int breakerAmps, volts;         // volts is AUTHORITATIVE downstream. CR-039.
  int? phase; bool dedicated;
  Uuid? locationId;
  int get continuousLimitAmps => (breakerAmps * 4) ~/ 5;   // NEC 210.19(A)(1)
  EntityMeta meta;
}
```

`Rack.lineVoltage` is deleted (CR-039). Circuit membership is **derived** by walking power Links
(device inlet → PDU outlet → PDU inlet → circuit); `Port.circuitId` survives only where the rack
meets the building, PDU and UPS inlets and hardwired devices (CR-028).

### 5.5 Placement

```dart
sealed class Placement { }   // elevation X/Y is NEVER stored — it is derived. CR-006.

final class RailPlacement extends Placement {
  final Uuid rackId;
  final int  ruIndex;             // 1-BASED, BOTTOM ORIGIN, ALWAYS. CR-025.
  final Face face;                // front | rear
  final int  startTwelfth;        // 0..11  — v1 UI exposes Full(0,12)/Left(0,6)/Right(6,6)
  final int  spanTwelfths;        // 1..12  — free lateral drag is v1.2. CR-030.
  final Len? depthOffsetFromFront;
  final ChassisRotation chassisRotation;   // normal | reversed. AC-023.
  final bool locked;
}
final class ShelfPlacement extends Placement {
  final Uuid hostDeviceId;        // CHILD → PARENT only. The parent never owns a list. CR-029.
  final FracIndex order;          // auto-pack left→right in v1. AC-043.
  final Len? lateralOffset;       // stays in the format; UI defers.
  final bool locked;
}
final class ZeroUPlacement extends Placement {
  final Uuid rackId; final String channelId;
  final Len offsetFromChannelStart; final Orientation orientation;
  final bool locked;              // inspector-edited in v1; no drag gesture. AC-044.
}
final class OffRackPlacement extends Placement {
  final Uuid? locationId; final String? mountNote;
}
final class StagedPlacement extends Placement {          // IS the Staging Bin. CR-032.
  final Uuid? lastRackId; final int? lastRuIndex; final Face? lastFace;
  final Pt? schematicHint;        // consumed ONCE when the first SheetItem is created. CR-069.
}
```

`DeviceInstance.hostDeviceId` is deleted as redundant with `ShelfPlacement` (CR-029).
`Bay` does not exist (CR-033).

### 5.6 Template, device, port

```dart
final class TemplateSnapshot {
  final TemplateId templateId; final int version;   // monotonic int, NOT semver. CR-050.
  final String contentHash;     // sha256; mismatch = warning + badge, never a load failure. AC-042
  final TemplateBody body; final DateTime capturedAt;
}

final class TemplateBody {
  String manufacturer, model, displayName, description, category;
  String? typePrefix;                     // "MTX" — seeds the designator format
  List<String> tags;

  // Occupancy — a struct, never a scalar. CR-036.
  int frontU, rearU;
  OccupancySide side;                     // front|rear|both|zeroUVertical|none
  MountMethod mountMethod;                // rackEars|shelf|zeroU|sideMount|rearRail
                                          // |furniture|hosted|notInRack
  List<MountMethod> alternateMountMethods;
  WidthClass widthClass; int nominalSpanTwelfths; Len? customPanelWidth;

  Len bodyDepth;
  Len? connectorProjection;               // DERIVED from the deepest rear connector, not +75mm
  Len chassisWidth;                       // default 432 mm for full width — NOT 482.6. AC-032.
  Mass weight;
  Mass? maxUnsupportedMass;               // default ~7 kg for rackEars. Feeds RCK-013. AC-028.

  int requiresClearanceAboveU, requiresClearanceBelowU;
  ThermalClass thermalClass;

  bool isContainer; Mass? containerWeightCapacity;
  Len? containerUsableDepth, containerUsableWidth; bool containerVented;

  bool isPassthrough;
  List<PassthroughPairDef> passthroughPairs;   // now in .rmdev. CR-057.

  PowerProfile power;
  List<PortDef> ports;
  List<BankDef> banks;                    // presentation. CR-055.
  List<PortSetDef> portSets;              // electrical. CR-055.

  Rgb? accentColor;
  List<PanelGraphic> panelGraphics;
}                                          // no frontImage/rearImage in v1. AC-057.

final class PowerProfile {
  int? nameplateWatts;                    // UL thermal rating; ADVISORY second line only
  int? typicalWatts;                      // the number circuit loading uses. NEVER auto-derived.
  int? standbyWatts, nominalVolts;
  int? apparentVA;                        // circuit loading is computed in VA. CR-056, AC-020.
  int? powerFactor;                       // permille. 650 for a linear-supply amp.
  bool isContinuousLoad;
  int outletsProvided, outletsConsumed;
  PlugType? inletPlug;
  int? poeBudgetWatts;                    // now declared. NET-001 depends on it. CR-056.
  int? btuPerHourOverride;                // else typicalWatts × kBtuPerWattHour
}

final class PortDef {
  final PortKey key;                      // STABLE, author-assigned. THE migration join. CR-051.
  final List<PortKey> renamedFrom;        // what a UUID cannot express
  String label; String? designatorHint;

  ConnectorTypeId connector;              // THREE ORTHOGONAL AXES. Never one enum.
  SignalFamilyId  signalFamily;
  List<SignalFamilyId> carriedProtocols, acceptedFamilies;

  PortDirection direction;                // source|sink|bidirectional|busNode|passive. CR-060.
  ReturnChannel? returnChannel;           // ARC / eARC
  PortTopology topology; int maxConnections;

  Gender gender;                          // male|female|genderless ONLY. CR-059.
  Face face; PanelPosition position;
  String? pinoutVariant;                  // IR hazard; safety-adjacent ⇒ must be cited. AC-052.
  int? conductorCount;

  int? impedanceOhms; AudioLevel? level; bool? balanced, phantomPowerCapable;
  Polarity? polarity;                     // on the TERMINAL, so a typo is inexpressible. AC-030.
  int? nominalVoltage, maxCurrentMa;

  String? bankKey;                        // → BankDef
  String? setKey, setRole; int? channelIndex;   // → PortSetDef

  PoeSpec? poe; int? linkSpeedMbps; SfpFormFactor? sfp;
  FiberMode? fiberMode; int? wavelengthNm;
  BusCapability? bus; SerialSpec? serial; PortPowerSpec? power;

  FracIndex order; String? notes;
}

final class DeviceInstance {
  final Uuid id;
  DeviceKind kind;                        // rackDevice|shelf|structure|offRackPassive
                                          // |virtual|blankPanel|ventPanel|pdu|ups
  TemplateRef templateRef;                // ALWAYS resolves to an embedded snapshot. CR-054.
  String designator, name;                // "MTX-1" — unique project-wide
  bool designatorLocked;                  // CR-034
  LifecycleStatus lifecycleStatus;        // existing|new|future|removed. CR-064.
  Placement placement;
  Uuid? locationId;
  String? serialNumber, assetTag, macAddressPrimary, firmwareVersion;
  DateTime? installedAt;
  DeviceOverrides overrides;              // TYPED, nullable fields. CR-053, AC-012.
  Uuid? structureBodyId;
  String? notes; Rgb? colorOverride;
  EntityMeta meta;
}                                          // no localTemplate, no zOrder, no cost/supplier.

final class Port {
  final Uuid id;                          // uuidv5(deviceId, portKey) when template-derived
  final Uuid deviceId;
  final PortKey? templatePortKey;         // null for instance-added ports
  PortOverrides overrides;                // typed. Lives HERE, not in a device map. CR-053.
  String? userLabel; String designator;   // "J01" — unique within the device. CR-042.
  bool orphaned, reserved;
  NetworkConfig? network;
  int? busAddress, busUniverse; bool? isBusTerminator;
  int? tapWatts;                          // 70/100 V transformer tap — per INSTALLATION
  Uuid? circuitId;                        // only where the rack meets the building
  PoeAssignment? poeActual;
  String? notes;
}                                          // NO EntityMeta. CR-095.
```

A `Port` is **serialized only if it carries project state**: a conductor, an override, a pinned
designator, network config, a bus address, a tap, a reserve or orphan flag. Everything else is
reconstructed at load by key-join against the snapshot; typical files drop ~70% (AC-006).
Reserve allocation is `DeviceInstance.designatorWatermark`, not thousands of placeholders.

Template migration: join on `PortKey` (+ `renamedFrom`); a removed port with conductors is
**orphaned, never deleted**. The Update Manager offers `[ Remap ▾ ]` and `[ Keep as orphan ]`.
**There is no `[ Del ]`** (CR-052, AC-058/D5). v1 is copy-on-place; the update manager itself is
v1.2 (AC-041).

### 5.7 Wiring: Link, Service, Conductor, Net

```dart
final class Link {                        // ONE PHYSICAL CABLE. One W###. One schedule row.
  final Uuid id;
  String designator;                      // "W042"
  bool designatorLocked;                  // auto-set at roughInStatus >= pulled. AC-034/m22.
  LinkClass linkClass;                    // fieldCable|jumper|powerCord|internal — auto-
                                          // classified, user-overridable. Schedule excludes
                                          // jumper + powerCord by default. AC-026.

  List<Service>   services;               // 1..N. CR-010, AC-021.
  List<Conductor> conductors;             // 1..N. One 16/4 = one Link, four Conductors. RJ-016.
  List<Breakout>  breakouts;              // fan-outs; a Link may reach N devices. CR-014.
  List<InlineAdapter> inlineAdapters;     // passive only; two-cable devices are DeviceInstances

  MediaTypeId media; String? cableSpecId;
  int? gaugeAwg; JacketRating? jacket; bool shielded, plenum;

  Len? routedLength, cutLength, terminatedLength;   // three fields, three columns. AC-024.
  Permille? slack;
  Uuid? pathwayId;                        // → Pathway
  CrossoverKind? crossover;               // straight|nullModem|fiberPolarityAB

  LifecycleStatus lifecycleStatus;        // + designIntent, for a cable with no device yet
  RoughInStatus roughInStatus;            // planned|pulled|dressed|terminated|tested
  TestResult? test;                       // pass/fail + certificate id. RJ-004.
  String? installedBy; DateTime? terminatedAt;

  StructureOrigin? structureOrigin;       // home runs. AC-019.
  String? notes; FracIndex order;
  EntityMeta meta;
}                                          // no netId, no waypoints, no autoRoute. CR-012.

final class Service {                     // ONE SIGNAL carried on the cable
  final String id;
  SignalFamilyId signalFamily;
  Uuid netId;                             // NON-NULL. Implicit singleton net if unassigned.
  List<String> conductorRoles;            // which conductors carry it — "pr 3", "pr 1–2"
  String? label;
}

final class Conductor {
  final String role;                      // "" | "Y" | "Pb" | "Pr" | "L+" | "L−" | "+" | "−"
  final Endpoint from, to;                // EXACTLY two ends. CR-014.
  final int? pairNumber;
  final String? colorCode;                // "blue/white" — PRINTS on the termination schedule
}

sealed class Endpoint { }                                        // AC-018
final class PortEndpoint  extends Endpoint { final Uuid portId; }
final class PlaceEndpoint extends Endpoint {
  final Uuid? locationId; final String description;
  final TerminationType? intendedTermination; final Len? serviceLoop;
}
final class OpenEndpoint  extends Endpoint { final String description; }

final class StructureOrigin {
  final Uuid structureBodyId, outletId;
  String fieldLabel;                      // "LR-TV-1A" — on the wall plate. REQUIRED, unique.
  String? rackLabel;                      // "1A-A12"   — at the panel.    Unique when set.
  Wall? wall; MountSurface? mountSurface;  // + ceiling|floor|soffit|exterior|inGround. m24.
  Len? mountHeightAff;
  TerminationType terminationField;
}

final class Net {                         // STORED. Membership is Service.netId. CR-011.
  final Uuid id;
  String name;                            // generated, editable, NEVER load-bearing. CR-049.
  String? designator;                     // "N012"
  SignalFamilyId signalFamily;
  NetTopologyKind topology;
  Rgb? colorOverride;
  bool isImplicit;                        // auto singleton for a lone P2P service
  Uuid? busTerminatorPortIdA, busTerminatorPortIdB;
  int? busUniverse, nominalVoltage;
  String? notes;
  EntityMeta meta;
}

final class Pathway {                     // conduit / j-hook / tray / trunk. CR-016, AC-027.
  final Uuid id;
  String name;                            // "B03"
  PathwayKind kind;                       // conduit|jhook|tray|plenumSpace|riser
                                          // |directBury|exterior
  bool containsLineVoltage;               // CODE-001 depends on it
  Uuid? fromLocationId, toLocationId;
  Len? nominalLength; MediaTypeId? pathwayMedia;   // isPathwayOnly media. CR-109.
  String? notes; FracIndex order;
  EntityMeta meta;
}

final class Outlet {                      // ONE WALL PLATE / ONE CEILING LOCATION. CR-016.
  final Uuid id; final Uuid structureBodyId;
  String designation;                     // the outlet's own field designation
  Uuid? locationId;
  Wall? wall; MountSurface? mountSurface; Len? mountHeightAff; int? floorNumber;
  String? outletTemplateId;               // what created it. CR-108.
  String? tia570Grade;                    // a standards TAG, not an axis
  Uuid? pathwayId; Len? nominalRunLength;
  String? notes; FracIndex order;
  EntityMeta meta;
}                                          // members are Links, via Link.structureOrigin.outletId
```

`Outlet.roughInStatus` is **derived as the minimum** across its member Links, an outlet is as
complete as its least-complete run, and is **not serialized** (CR-111, CR-115).

Route geometry is **never persisted** (CR-012). Symbol placement is (`SheetItem`); wire geometry
is not. The router is a pure deterministic function of the model: Sugiyama layering plus
interval-graph channel routing, full recompute, with the crossing sweep and hop arcs run at
**paint time, viewport-scoped** (CR-013, AC-016/#20).

> **Third sentence superseded — see §12.1 (§7.2.3 router row).** The router is Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal staircase; there is no channel routing, no crossing sweep, no hop arcs and no paint-time phase. The first two sentences (CR-012 — route geometry never persisted, symbol placement persisted) are **unaffected and still binding** (§12.1, CR-012 row).

### 5.8 Sheet, Note, Finding, Tombstone

```dart
final class Sheet {
  final Uuid id;
  String number;                          // "T2.01" (ncs) or "2" (simple). CR-066.
  String title;
  SheetKind kind;                         // cover|legend|exceptions|elevationFront|elevationRear
                                          // |schematic|wiringSchedule|dropSchedule|equipmentList
                                          // |networkSchedule|powerSchedule|pullSheet
  PaperSize paper; Orientation orientation;
  int scaleNumerator, scaleDenominator;   // 0/0 ⇒ NTS. Fit-to-page, snapped within 2%. CR-118.
  bool carriesLegend;                     // legendLocationNote is AUTO-FILLED at export. CR-023.
  List<Uuid> includedRackIds, includedDeviceIds;
  Set<SignalDomainId> domainFilter;
  Set<LifecycleStatus> lifecycleFilter;   // the useful half of layers. CR-067.
  Map<Uuid, SheetItem> items;
  FracIndex order;
  EntityMeta meta;
}

final class SheetItem {
  final Uuid id, targetId;
  Pt position;                            // THE only symbol position. CR-069.
  int rotationQuarterTurns;               // 0..3 — no float angles
  bool collapsed;
  bool pinned;                            // any manual move sets it. Auto-layout never moves a
                                          // pinned symbol. CR-068.
  FracIndex zOrder;                       // THE only stacking order
}

final class AckedFinding {
  final Uuid id; final String ruleId;
  final String targetFingerprint;         // "*" ⇒ project-wide mute (reason REQUIRED)
  final Uuid? targetEntityId;
  String reason;                          // optional for a single instance. RJ-006.
  String by; DateTime at; Severity demotedTo;
  EntityMeta meta;
}
```

`Finding` is computed and never stored. Severity is `error | warning | advisory | off` (CR-018).
**Errors are acknowledgeable** and nothing blocks export (CR-019, CR-022, G3). Every export emits
`T0.02 — Exceptions & Acknowledgements`.

Only five rules are model-level illegal, `TOP-001..005` (self-connection, duplicate ordered pair
on one link, over `maxConnections`, dangling endpoint, container cycle), plus placement
coherence: `ruIndex` within the rack, host is a container, no containment cycle (CR-017).
v1 ships **27 rules**, listed once in **§5** of this record, each with a known-bad and a known-good
fixture. **No rule ships without its pair** (AC-040, AC-051). *(Was "22 rules ... `docs/rules.md`";
corrected per §12.6(b) and §10.12(g), paid 2026-08-03.)*

### 5.9 Persistence contract

| Property | Binding value | Ruling |
|---|---|---|
| Container | Plain, pretty-printed, key-sorted UTF-8 JSON. `DocumentCodec` sniffs `PK\x03\x04` on read. | CR-091 |
| Envelope | Format metadata at the root; all entity maps under `"document"`. | CR-092 |
| Round trip | **Byte** round trip: `write(read(bytes)) == bytes`. Constrains key ordering, including inside `unknown` maps, timestamp precision, and integer formatting. | CR-117 |
| Migration | `Outcome<T>`, never exceptions. `minReaderVersion > kSchemaVersion` ⇒ `Err(NewerSchema(refuse))`. `schemaVersion > kSchemaVersion && minReaderVersion <= kSchemaVersion` ⇒ `Ok(doc, openReadOnly: true)` with unknown fields preserved for Save As. | CR-093 |
| Derived values | **Never serialized**: `portIds`, `Outlet.roughInStatus`, `templateUpdateAvailable`, `Link.dominantSignalFamily`, elevation X/Y, circuit membership. | CR-115, CR-006 |
| Floats | **None** in any persisted model, including `.rmdev`. | I-1, CR-063 |
| IDs | UUIDv7 for entities; `uuidv5(deviceId, portKey)` for template-derived ports. Normative examples use real UUIDs. | CR-116, AC-006 |
| Snapshots | `getApplicationSupportDirectory()/snapshots/<docUuid>/<sequence>.rackmate`, last 10. No `.history/` in the user's folder. | CR-098 |
| Crash reports | Recovery files are **never** auto-attached. An explicit, default-off checkbox reads *"This includes your client's name and site address."* | CR-096 |
| Import security | Zip-slip protection, entry-count and uncompressed-size caps, JSON depth and size limits on every import path. No evaluated program arrives in any file. | AC-058/D8, AC-011 |

---

## 6. Canonical signal and cable type registry

**This section is data that ships.** It is the authored content of
`assets/catalog/registries.json`, embedded into every `.rackmate` as the subset the document
references (CR-090's self-describing-file argument). It is not illustrative.

### 6.1 The three orthogonal axes, restated

The single most expensive mistake available in this domain is one enum. RJ45 is a **connector**;
Cat6a is a **medium**; Ethernet, HDBaseT, Dante and Cresnet are **signal families** that share
both. HDBaseT explicitly reuses Ethernet conductors, cable and connectors *and is not
interchangeable with them*, patching an HDBaseT output into a switch does not work and its
100 W PoH can damage the switch. That single check is the highest-value validation in the
product, and it is only expressible because the axes are separate.

So there are four registries, not one:

| Registry | Answers | User-extensible in v1? |
|---|---|---|
| `SignalDomainDef` | What colour, dash, weight and glyph does this class of signal draw in? | No: 8 fixed entries |
| `SignalFamilyDef` | What *is* this signal, what does it require, what may it mate with? | No: catalog-updated (RJ-012) |
| `ConnectorTypeDef` | What plugs into what, and does gender apply? | Aliases only (CR-058) |
| `MediaTypeDef` | What cable is pulled, how long may it be, what jacket? | **Yes**: the CSV import creates them (RJ-009) |

`Port.connector`, `Port.signalFamily` and `Port.carriedProtocols` are three independent fields.
`Link.media` is a fourth. `Service.signalFamily` is what a wire's colour resolves from, never
`Link` (CR-009).

---

### 6.2 The palette, and why it is built this way

#### 6.2.1 Colour encodes domain, not type: and the reasoning

There are ~50 signal families below. **No categorical palette is colour-vision-deficiency-safe
past 8–9 categories**: the Okabe–Ito authors stopped at eight for exactly that reason, having
verified their set through protanopia, deuteranopia and tritanopia simulation. Assigning a hue
per cable type therefore does not produce a colour-coded drawing; it produces an unreadable one,
and it fails hardest for the ~8% of male installers with a CVD who are the exact audience.

So RackMate uses **four independent encoding channels**, and hue is never one of them alone:

| Channel | Encodes | Survives CVD | Survives greyscale | Survives photocopy/fax |
|---|---|---|---|---|
| **Hue** | domain (8) | ✅ (Okabe–Ito) | ❌ | ❌ |
| **Dash pattern** | type-within-domain | ✅ | ✅ | ✅ |
| **Line weight** | domain tier (0.75× – 2.0×) | ✅ | ✅ | ✅ |
| **Glyph + tag pill** | exact family | ✅ | ✅ | ✅ |

The tag pill (`W042 · HDMI · 25 ft`, drawn at both ends of every run) is the encoding that never
fails, and it is mandatory, not decorative.

#### 6.2.2 The honest greyscale caveat, and the rule it generates

Several sources claim Okabe–Ito "has distinct luminance values so it works in greyscale."
**Computing WCAG relative luminance shows that claim is false**, and RackMate does not repeat it.
Two collision bands exist in the shipped palette:

- **Sky Blue `#56B4E9` (L 0.4050) vs Orange `#E69F00` (L 0.4162)**: ΔL 0.0112. Indistinguishable
  in greyscale. These are analog video and analog audio.
- **Vermillion `#D55E00` (0.2215) / Bluish Green `#009E73` (0.2569) / Reddish Purple `#CC79A7`
  (0.2930)**: a crowded 0.0715-wide band. These are digital audio, network and control.

The collisions are placed **deliberately**, not accepted. Each colliding pair is separated
maximally on the other three channels, and that is promoted from a hope to a checkable rule:

> **PAL-1 — Within any greyscale luminance band narrower than 0.10, no two domains may share a
> dash class, and their line weights must differ by a factor of ≥ 1.4.**

> **Superseded — see §14.1; ruled at §12.6(c).** The conjunctive domain-level form stated above is
> not PAL-1. The binding form is **pairwise over rendered family values** and **disjunctive** (dash
> class differs **or** weight ratio ≥ 1.4). Stated over eight domain rows it is unsatisfiable by
> the shipped palette, and reading those eight rows instead of the family pairs actually drawn is
> what allowed collisions to ship undetected three times. The authority is the executable check
> **`tools/pal1_check.py`** — not this statement, and not the table below.

The table below is the superseded domain-level verdict, retained as the record of the argument.
It is **not** a verification: it reads eight domain rows, not the family pairs that are drawn.
Conformance is established only by running `tools/pal1_check.py`.

| Collision band | Domains | Dash class | Weight | Verdict |
|---|---|---|---|---|
| L ≈ 0.40 | Analog video / RF · Analog audio | long dash `12,4` vs short dash `6,3` | 1.0× vs 1.0× | ✅ dash class differs; glyphs ▼ vs ● |
| L ≈ 0.22–0.29 | Digital audio · Network · Control | dash-dot vs **solid** vs fine dot | 1.0× · 1.5× · 0.75× | ✅ 2.0× spread across the band |

> **PAL-2 — Yellow `#F0E442` is reserved for selection and focus and is never a cable.** At
> L 0.744 it is illegible as a thin line on white paper.

> **PAL-3 — The screen theme never affects the export.** Export palette is
> `ExportSpec.palette: colour | greyscale | cmyk`, default `colour`, default `greyscale` in the
> Installer preset, never inherited from the UI theme (CR-077). Greyscale export drops hue
> entirely and renders every domain in black at its own dash and weight — and
> `tools/pal1_check.py` is what establishes that this is sufficient.

#### 6.2.3 Units and storage

- **Dash patterns are in points (1/72 in)**, matching the renderer, stated once in
  `docs/visual-language.md` (CR-079). Stored as `List<int>` of **permille-points** so the file
  stays integral: `6,3` is `[6000, 3000]`, `1.5,3` is `[1500, 3000]`. The screen backend divides
  by the zoom scale so a dash is zoom-invariant; the PDF backend passes them through.
- **Line weight** is `Permille`; `1000` = 1× = the base signal weight.
- **Minimum print stroke is 0.5 pt** and no stroke is ever emitted at 0; sheet furniture uses
  `Stroke.hairlineFloor` with a 0.25 pt print floor (CR-082).
- **Every shipped dash period is ≥ 4.5 pt (1.59 mm)**, above the 1.5 mm floor below which a dash
  blurs to solid at 300 dpi. `design-ux-schematic.md`'s control-domain `1,3` dot has a 4.0 pt
  period (1.41 mm) and is **corrected to `1.5,3`** here.
- Hop arcs are **suppressed on dashed domains**, control and structure, because dash phase
  diverges across an arc and those are the two domains where hops matter least (AC-016/#17).

#### 6.2.4 The glyph channel

A glyph is drawn at the midpoint of each run and in the legend. It is the fourth channel and the
one that survives a third-generation photocopy.

**Shape encodes domain. Fill encodes tier within the domain**: filled = the domain's native
carrier, hollow = the transported / extended / networked variant. The glyph is deliberately *not*
the per-family discriminator (there is no set of 50 shapes that stays legible at 6 pt); the tag
pill is. The glyph answers "what kind of signal is this" across a room.

All glyphs are drawn from Geometric Shapes, Dingbats, or Miscellaneous Technical, all covered by
`RackBody` (IBM Plex Sans) or the `Noto Sans Symbols 2` fallback (CR-080). **A CI test asserts
that every glyph in the registry resolves in one of those two faces**: a tofu box in an exported
drawing is a defect this test exists to prevent.

#### 6.2.5 `SignalDomainDef`: the eight shipped entries

`SignalDomainDef{id, displayName, tagPrefix, color, colorDark, dashPattern, lineWeightPermille,
glyph, glyphAlt}`. This entity is new in CR-078 and is what deleted the 43-entry per-family
palette that `design-data-model.md` simultaneously carried and argued against.

| `id` | Display name | Light hex | Dark hex | Base dash (pt) | Weight | Glyph (native / transported) | Rel. lum. |
|---|---|---|---|---|---|---|---|
| `video.digital` | Digital Video | `#0072B2` | `#4DA6DD` | solid | 1.00× | ▲ / △ | 0.1525 |
| `video.analog` | Analog Video & RF | `#56B4E9` | `#8ACFF5` | `12,4` | 1.00× | ▼ / ▽ | 0.4050 |
| `audio.analog` | Analog Audio | `#E69F00` | `#F0B443` | `6,3` | 1.00× | ● / ◐ / ○ | 0.4162 |
| `audio.digital` | Digital Audio | `#D55E00` | `#F07A33` | `6,3,1,3` | 1.00× | ◆ / ◇ | 0.2215 |
| `net` | Network | `#009E73` | `#2FC79A` | solid | 1.50× | ■ / □ | 0.2569 |
| `ctl` | Control | `#CC79A7` | `#E29CC3` | `1.5,3` | 0.75× | ✚ / ✳ | 0.2930 |
| `pwr` | Power | `#000000` | `#E8E8E8` *(inverted: black is invisible on dark)* | `8,3,1.5,3,1.5,3` | 2.00× | ⬢ / ⬡ / ⏚ | 0.0000 |
| `str` | Structure | `#999999` | `#A8A8A8` | `6,3,3,3` | 0.75× | ★ / ☆ | 0.3185 |
| *(reserved)* | Selection / focus | `#F0E442` | `#F5E76B` | — | — | — | 0.744 |

Dash patterns, weights, glyphs and tags are **identical across themes**. Only hue moves, and the
theme is a UI preference never persisted in the document.

> **The `str` base dash `4,4` is superseded — see §14.3.** It is **`6,3,3,3`**, class `(short,short)`, period 15 pt, and the row above is corrected in place. The §6.4 rows for `audio.spdif_optical`, `structure.pathway`, `structure.undetermined`, `video.hdmi.1_4`, `video.composite`, `audio.line_bal`, `audio.spdif_coax` and `audio.aes3` are likewise superseded by §14.3. Every effective value in this section is checked by `tools/pal1_check.py`.

`str`'s base dash was authored `4,4` rather than `design-ux-schematic.md`'s `6,3`, on the reasoning
that an even dash is unambiguous against a 2:1 dash. **That reasoning is retracted.** It predates
the mechanical dash-class definition of §14.2, under which `4,4` and `6,3` are both `(short)`, and
`4,4` @ 0.75× against analog audio's `6,3` @ 1.00× is a weight ratio of 1.33, the identical
failure the paragraph was written to avoid. The `str` base dash is **`6,3,3,3`**, class
`(short,short)`, period 15 pt; the table row above now carries that corrected value. See **§14.3**.

---

### 6.3 `ConnectorTypeDef`: the connectors referenced below

Abbreviated to `id · display · genderApplies · contacts`. `genderApplies` decides whether
`CON-002` (both ends the same gender) evaluates and whether the symbol glyph's fill encodes
gender, which is what `design-ux-schematic.md` actually wanted when it limited gender encoding
to XLR, IEC, DE-9, SpeakON and fibre (CR-059). Gender values are `male | female | genderless`
only; `jack` and `plug` are deleted.

| id | Display | Gender applies | Contacts |
|---|---|---|---|
| `conn.hdmi_a` · `conn.hdmi_c` · `conn.hdmi_d` | HDMI Type A / C / D | no | 19 |
| `conn.dp` · `conn.mini_dp` | DisplayPort / Mini DisplayPort | no | 20 |
| `conn.usb_c` | USB-C | no | 24 |
| `conn.bnc75` · `conn.bnc50` | BNC 75 Ω / BNC 50 Ω | **yes** | 1 |
| `conn.f_type` | F-type | **yes** | 1 |
| `conn.rca` · `conn.rca75` | RCA / RCA 75 Ω | **yes** | 1 |
| `conn.hd15` | HD-15 (VGA) | **yes** | 15 |
| `conn.mini_din4` | Mini-DIN 4 (S-Video) | **yes** | 4 |
| `conn.3_5mm_ts` · `conn.3_5mm_trs` | 3.5 mm mono / stereo | no | 2 / 3 |
| `conn.6_35mm_trs` | 1/4 in TRS | no | 3 |
| `conn.xlr3` · `conn.xlr5` | XLR3 / XLR5 | **yes** | 3 / 5 |
| `conn.jis_f05` | JIS F05 (TOSLINK / EIAJ optical) | no | — |
| `conn.rj45` | RJ45 (8P8C) | **yes** | 8 |
| `conn.lc_duplex` · `conn.sc` · `conn.st` | LC duplex / SC / ST | **yes** | — |
| `conn.sfp_cage` | SFP / SFP+ / SFP28 cage | no | — |
| `conn.de9` | DE-9 (commonly mis-called DB9) | **yes** | 9 |
| `conn.euroblock_2` · `_3` · `_5` | Euroblock / Phoenix 2, 3, 5-pole | **yes** | 2 / 3 / 5 |
| `conn.phoenix_4` | 4-pin Phoenix (Cresnet) | **yes** | 4 |
| `conn.screw_terminal` · `conn.knx_terminal` | Screw terminal / KNX bus terminal | no | 2 |
| `conn.binding_post` · `conn.banana` | Binding post / banana | **yes** | 1 |
| `conn.speakon_nl4` | SpeakON NL4 | **yes** | 4 |
| `conn.punchdown_110` · `conn.keystone` | 110 punchdown / keystone | no | 8 |
| `conn.iec_c13` · `_c14` · `_c19` · `_c20` | IEC 60320 C13 / C14 / C19 / C20 | **yes** | 3 |
| `conn.nema_5_15p` · `_5_15r` · `_5_20p` · `_5_20r` · `conn.nema_l5_30p` | NEMA plugs and receptacles | **yes** | 3 |
| `conn.barrel_dc` | DC barrel | **yes** | 2 |
| `conn.hardwired` · `conn.ground_lug` · `conn.unterminated` | Hardwired / ground lug / unterminated | no | — |

Aliases (`hdmi`, `hdbt`, `rj45`, `xlr`, `spdif`, `toslink`, `euro3`, `bp`, `db9` → `conn.de9`)
live in `ConnectorTypeDef.aliases` and are what the Quick Add DSL resolves against (CR-058).
**A CI test asserts every `ConnectorTypeDef` referenced by a shipped template has a footprint
entry** in the connector footprint table, the "zero-authoring correct rear panel" claim is false
without it (AC-050/A2.2).

---

### 6.4 `SignalFamilyDef`: the shipped signal families

`SignalFamilyDef{id, displayName, shortTag, domain, defaultConnector, defaultDirection,
defaultTopology, typicalMedia[], acceptedFamilies[], adaptableTo[], maxRunLengthPassive,
maxRunLengthActive, nominalImpedanceOhms, maxUnitLoads, maxDevicesPerSegment,
requiresTermination, carriesPower, topologyFree, aliases[], colorOverride?, dashOverride?,
glyphOverride?}`.

**Colour is inherited from the domain** (CR-078) and the hex is printed here as the *effective*
value so this table is self-contained. `dashOverride` is the type-within-domain channel required
by AC-054 and is what makes each of the brief's ten named types individually identifiable.
`ProjectSettings.familyColorOverrides` lets a user override any hue in v1 (AC-054 part 3).

Direction key: **→** unidirectional source→sink · **↔** bidirectional · **BUS** multi-drop shared
medium · **⤳** logical flow riding a network. Topology: **P2P** · **MD** multi-drop · **STAR**.

#### Digital video: `#0072B2`, glyph ▲ native / △ transported

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `video.hdmi.1_4` | HDMI 1.4 | `conn.hdmi_a` | → | P2P | solid | 0.75× | `HD14` | ▲ |
| `video.hdmi.2_0` | HDMI 2.0 (18 Gbps) | `conn.hdmi_a` | → (+ARC ↔) | P2P | solid | 1.00× | `HD20` | ▲ |
| `video.hdmi.2_1` | HDMI 2.1 (48 Gbps) | `conn.hdmi_a` | → (+eARC ↔) | P2P | solid | 1.25× | `HD21` | ▲ |
| `video.displayport` | DisplayPort 1.4 / 2.1 | `conn.dp` | → (+AUX ↔) | P2P / MST | `18,4` | 1.00× | `DP` | ▲ |
| `video.sdi` | SDI (HD / 3G / 6G / 12G) | `conn.bnc75` | → | P2P (+loop) | `10,3` | 1.00× | `SDI` | ▲ |
| `video.hdbaset` | **HDBaseT (5Play)** | `conn.rj45` | → video, ↔ ctl | P2P | `14,4` | 1.25× | `HBT` | △ |
| `video.usbc_dpalt` | USB-C DP Alt Mode | `conn.usb_c` | ↔ | P2P | `6,2` | 1.00× | `UCV` | ▲ |
| `video.avoip` | AV-over-IP (SDVoE / JPEG XS / NDI) | `conn.rj45` | ⤳ | STAR | `14,4,2,4` | 1.00× | `AVIP` | △ |

Key data: HDMI 2.1 passive collapses to **3–4.5 m** where 2.0 reaches ~7.5 m, a 25 ft run that
worked at 4K60 fails at 4K120, and `LEN-001` exists for exactly this. DisplayPort DP80 passive is
**1.2 m**. 12G-SDI is **~45–50 m**. HDBaseT reaches **100 m on Cat6a** at 4K and carries up to
100 W PoH; `topologyFree = false`, `acceptedFamilies` deliberately **excludes** `net.ethernet`,
and this is what makes `SIG-001` fire.

#### Analog video & RF: `#56B4E9`, glyph ▼ baseband / ▽ broadband

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `video.composite` | Composite (CVBS) | `conn.rca75` | → | P2P | `1.5,3` | 1.00× | `CVBS` | ▼ |
| `video.component` | Component YPbPr | `conn.rca75` | → | P2P (3-port set) | `12,4,3,4` | 1.00× | `YPBPR` | ▼ |
| `video.vga` | VGA / RGBHV | `conn.hd15` | → (+DDC ↔) | P2P | `12,4,3,4,3,4` | 1.00× | `VGA` | ▼ |
| `video.svideo` | S-Video | `conn.mini_din4` | → | P2P | `9,4` | 1.00× | `SVID` | ▼ |
| `rf.catv` | RF / CATV distribution | `conn.f_type` | → (↔ DOCSIS) | **MD** | `12,4` | 1.50× | `RF` | ▽ |
| `rf.satellite` | Satellite / SWM | `conn.f_type` | ↔ | **MD, power-passing** | `12,4,3,4` | 1.50× | `SAT` | ▽ |
| `rf.ota` | OTA antenna | `conn.f_type` | → | MD | `16,4` | 1.00× | `OTA` | ▽ |
| `rf.modulated` | RF modulated channel | `conn.f_type` | → | MD | `12,4` | 1.00× | `RFM` | ▽ |

`video.component` declares a `PortSetDef` of kind `componentVideo` with `atomicConnect: true`,
three ports, one gesture, one Link with three conductors (AC-053). `rf.satellite` carries
`requiresPowerPassingPort: true`: exactly one splitter port passes DC back to the LNB, and wiring
a normal splitter means the dish never powers. `rf.catv` carries per-device insertion loss so a
cascade budget is computable (a 2-way splitter is ≈ 3.5 dB); the cascade rule itself is v1.2.

#### Analog audio: `#E69F00`, glyph ● line / ◐ speaker low-Z / ○ constant-voltage

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `audio.line_unbal` | **Line level, unbalanced (RCA)** | `conn.rca` | → | P2P | `6,3` | 1.00× | `AUD` | ● |
| `audio.line_bal` | Line level, balanced | `conn.xlr3` | → | P2P | solid | 1.00× | `AUDB` | ● |
| `audio.mic` | Mic level | `conn.xlr3` | → | P2P | `4,3` | 1.00× | `MIC` | ● |
| `audio.phono` | Phono / turntable | `conn.rca` | → | P2P | `4,3,1.5,3` | 1.00× | `PHNO` | ● |
| `audio.speaker_lowz` | **Speaker level, low-Z** | `conn.binding_post` | → | P2P / parallel | `6,3` | **2.00×** | `SPK` | ◐ |
| `audio.speaker_cv` | Speaker, constant-voltage 70 / 100 / 25 V | `conn.euroblock_2` | → | **BUS (multi-tap)** | `10,3,2,3` | **2.00×** | `70V` | ○ |
| `audio.sub` | Subwoofer / LFE | `conn.rca` | → | P2P (or Y-split) | `8,3` | 1.25× | `SUB` | ● |
| `audio.headphone` | Headphone | `conn.6_35mm_trs` | → | P2P | `3,3` | 0.75× | `HP` | ● |

This is where the brief's "Analog RCA" and "speaker level" would have collided on one orange, and
they do not: `AUD` is a 1.00× short dash with a filled circle; `SPK` is a **2.00×** stroke with a
half-filled circle. In greyscale that is a 2× weight difference, which is the most legible
discriminator available.

`audio.line_bal` sets `balanced: true`; **gender is load-bearing** on XLR (male = output, female
= input) and `genderApplies` is true. `audio.phono` requires a separate ground conductor, which
is a real `Conductor` on the schedule, not a footnote. `audio.speaker_lowz` carries
`impedanceOhms` on the terminal so `ELE-004` (parallel speakers below the amp's minimum load) can
evaluate, the field-device templates of AC-031 exist so these rules have objects to operate on.
`audio.speaker_cv` carries `Port.tapWatts` **per installation, not per device** (2.5 / 5 / 10 /
15 / 20 W), because the tap is a setting on the transformer, not a property of the speaker model.

#### Digital audio: `#D55E00`, glyph ◆ electrical / ◇ optical or networked

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `audio.spdif_coax` | **S/PDIF, coaxial (75 Ω)** | `conn.rca75` | → | P2P | `12,4,3,4` | 1.00× | `SPD` | ◆ |
| `audio.spdif_optical` | **TOSLINK (optical S/PDIF)** | `conn.jis_f05` | → | P2P | `2,3` | 1.25× | `OPT` | ◇ |
| `audio.aes3` | AES/EBU (AES3, 110 Ω) | `conn.xlr3` | → | P2P | `12,4,10,4` | 1.00× | `AES` | ◆ |
| `audio.aes3id` | AES3id (75 Ω BNC) | `conn.bnc75` | → | P2P | `10,3,1,3,1,3` | 1.00× | `AES75` | ◆ |
| `audio.dante` | Dante | `conn.rj45` | ⤳ | STAR | `6,3,1,3` | 1.50× | `DNT` | ◇ |
| `audio.aes67` | AES67 | `conn.rj45` | ⤳ | STAR | `6,3,1,3,1,3` | 1.50× | `A67` | ◇ |
| `audio.avb` | AVB / Milan | `conn.rj45` | ↔ | STAR (**TSN switches only**) | `8,3,1,3` | 1.50× | `AVB` | ◇ |

The brief's "S/PDIF" and "TOSLINK" would have collided on one vermillion, and they do not: a
`6,3,1,3` dash-dot with a filled diamond versus a fine `2,3` dot with a hollow diamond. This is
also the pair where the distinction carries real consequence, TOSLINK cannot carry lossless
multichannel (no DTS-HD MA, no TrueHD), which is a design constraint, not trivia.

`audio.spdif_coax` sets `nominalImpedanceOhms: 75` and is physically indistinguishable from
`audio.line_unbal` at the connector: wiring a plain analog interconnect causes intermittent
dropouts, which is why the impedance warning exists. `audio.aes3` sets `110`, 110 Ω STP, *not*
mic cable, despite the identical XLR. Dante uses **PTPv1**, AES67 **PTPv2 (IEEE 1588-2008)**;
both need QoS/DSCP and ideally a dedicated VLAN. `audio.avb` sets `requiresTsnPath: true`, and
per CR-017 the "AVB traverses a non-TSN switch" check is a **post-hoc finding**, not a drag-time
refusal, because the link being drawn may be the one that completes the path.

#### Network: `#009E73`, glyph ■ copper / □ fibre or non-Ethernet

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `net.ethernet` | **Ethernet (copper)** | `conn.rj45` | ↔ | STAR | solid | 1.50× | `NET` | ■ |
| `net.poe` | PoE / PoE+ / PoE++ | `conn.rj45` | → power, ↔ data | STAR | solid | 2.00× | `PoE` | ■ |
| `net.poh` | PoH (HDBaseT power) | `conn.rj45` | → | P2P | `14,4` | 2.00× | `PoH` | □ |
| `net.fiber_mm` | Fibre, multimode (OM3 / OM4) | `conn.lc_duplex` | ↔ | P2P / STAR | `16,4` | 1.50× | `FIB` | □ |
| `net.fiber_sm` | Fibre, singlemode (OS2) | `conn.lc_duplex` | ↔ | P2P / STAR | `16,4,3,4` | 1.50× | `FIBS` | □ |
| `net.dac` | Direct-attach copper (SFP+) | `conn.sfp_cage` | ↔ | P2P | `8,3` | 1.50× | `DAC` | □ |

`maxChannelLength` is **100 m** for copper Ethernet (90 m horizontal + 10 m patch) and it is an
error above it, not a warning; this is one of the few hard numbers in the trade. PoE, as shipped
data on `PoeSpec{role, standard, type, class, watts}`:

| Standard | Type | Classes | PSE max | PD max | Pairs |
|---|---|---|---|---|---|
| 802.3af (PoE) | 1 | 0–3 | 15.4 W | 12.95 W | 2 |
| 802.3at (PoE+) | 2 | 4 | 30 W | 25.5 W | 2 |
| 802.3bt (PoE++) | **3** | 5, 6 | **60 W** | ~40 W / ~51 W | **4** |
| 802.3bt (PoE++) | **4** | 7, 8 | **90 W** | ~62 W / ~73 W | **4** |
| PoH (HDBaseT) | — | — | **up to 100 W** | — | **4** |

PoH is *based on* 802.3at and modified for 4-pair 100 W delivery. It is **not** interoperable
with a standard PoE PSE, which is why it is its own family with its own glyph rather than a flag
on `net.poe`. `NET-001` checks Σ(PD class draw) ≤ `PowerProfile.poeBudgetWatts`, a switch's
budget is almost always well below ports × max class, and flags a Type-4 PD on a Type-2 PSE.
Fibre carries `fiberMode` and `wavelengthNm`, and **A/B pair polarity** is the fibre analogue of
null-modem: it is `Link.crossover: fiberPolarityAB`.

#### Control: `#CC79A7`, glyph ✚ point-to-point / ✳ multi-drop bus

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `ctl.ir_emitter` | **IR emitter (flasher)** | `conn.3_5mm_ts` | → | P2P | `1.5,3` | 0.75× | `IR` | ✚ |
| `ctl.ir_receiver` | IR receiver | `conn.3_5mm_trs` | → to block | MD | `4,3,1.5,3` | 0.75× | `IRRX` | ✚ |
| `ctl.rs232` | **RS-232** | `conn.de9` | ↔ | **P2P only** | `6,3,1.5,3` | 0.75× | `232` | ✚ |
| `ctl.rs485` | RS-485 | `conn.euroblock_3` | ↔ half-duplex | **BUS** | `6,3` | 1.00× | `485` | ✳ |
| `ctl.dmx512` | DMX512-A | `conn.xlr5` | → over RS-485 | **BUS** | `8,3,1.5,3` | 1.00× | `DMX` | ✳ |
| `ctl.contact` | Contact closure / relay / GPIO | `conn.euroblock_2` | → drive or ← sense | P2P | `1.5,3,4,3` | 0.75× | `CC` | ✚ |
| `ctl.trigger12v` | 12 V trigger | `conn.3_5mm_ts` | → | P2P | `4,3` | 0.75× | `TRG` | ✚ |
| `ctl.cresnet` | Cresnet | `conn.phoenix_4` | ↔ | **BUS**, topology-free | `10,3,1.5,3` | 1.00× | `CN` | ✳ |
| `ctl.lutron_qs` | Lutron QS / HomeWorks link | `conn.rj45` | ↔ | **BUS**, topology-free | `10,3` | 1.00× | `QS` | ✳ |
| `ctl.dali` | DALI / DALI-2 | `conn.screw_terminal` | ↔ | **BUS**, topology-free | `5,3,1.5,3` | 1.00× | `DALI` | ✳ |
| `ctl.knx` | KNX TP1 | `conn.knx_terminal` | ↔ | **BUS** (line / tree) | `7,3,1.5,3` | 1.00× | `KNX` | ✳ |

`topologyFree: true` ships set on `ctl.cresnet`, `ctl.lutron_qs`, `ctl.dali` and `ctl.knx`. This
is a **registry field, not a hard-coded suppression array** (AC-030): a star-wired Cresnet run is
Crestron's own recommended residential approach, and a rule that fires on every correctly wired
Crestron job for the life of the product is worse than no rule.

Shipped limits: RS-485 **32 unit loads**, 120 Ω termination at *both* ends only, 1200 m.
DMX512-A 32 unit loads, 512 channels per universe, terminator at the far end, `busUniverse` on
the port. DALI **64 devices per line**, ~300 m, polarity-free (a wiring error is inexpressible).
KNX 64 devices per line segment, 1000 m per line. Cresnet has **two independent limits**, data
length (~915 m) *and* 24 V power drop (18 AWG at 20 W ⇒ **333 ft**), which is why `BUS-005`
emits two findings, not one. Lutron QS is 2000 ft on 12 AWG and topology-free.

`ctl.ir_emitter` and `ctl.ir_receiver` are separate families because the pinout hazard is real
and destructive: Xantech/Niles **receivers** are tip = signal, ring = GND, sleeve = +12 V;
**emitters** are tip = IR in, sleeve = GND. Plugging an emitter into a receiver jack destroys the
emitter and can damage the supply. `PortDef.pinoutVariant` is mandatory on every 3.5 mm IR port
and is a **safety-adjacent field**, so a template with an uncited value does not ship (AC-052).
`ctl.trigger12v` requires a **mono** plug, a stereo plug shorts ring to sleeve, and carries
`maxCurrentMa: 100`, which is what makes fan-out to four amplifier triggers a finding.
`ctl.rs232` is P2P only; straight versus null-modem is determined by the DTE/DCE role of *both*
ends, carried in `SerialSpec.role`, and surfaces as `Link.crossover`.

#### Power: `#000000` (light) / `#E8E8E8` (dark, inverted), glyph ⬢ AC / ⬡ DC / ⏚ bonding

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `power.ac_branch` | **AC branch circuit** | `conn.nema_5_15p` | → | P2P to circuit | `8,3,1.5,3,1.5,3` | 2.00× | `PWR` | ⬢ |
| `power.ac_iec` | IEC device power (C13/C14, C19/C20) | `conn.iec_c14` | → | P2P | `8,3,1.5,3` | 2.00× | `IEC` | ⬢ |
| `power.ac_hardwired` | Hardwired AC | `conn.hardwired` | → | P2P | `12,3,1.5,3` | 2.00× | `HW` | ⬢ |
| `power.dc_low` | Low-voltage DC (12 / 24 V supply) | `conn.barrel_dc` | → | P2P | `6,3,1.5,3` | 1.50× | `DC` | ⬡ |
| `power.bonding` | Bonding / grounding conductor | `conn.ground_lug` | ↔ | STAR to busbar | `4,3` | 1.50× | `GND` | ⏚ |

`power.ac_120` from `design-data-model.md` and `ac-inlet` from the device-builder catalog are both
re-authored to `power.ac_branch` / `power.ac_iec` with `PortPowerSpec.role: inlet | outlet`
(CR-058, CR-060). **Inlet and outlet are not directions**: they are `sink` / `source` on a
`power.*` family plus a role. IEC odd numbers are the female connector on the cord and the next
even number the male inlet on the equipment; C13→C14 is the standard rack pigtail. Circuit
loading is computed in **VA** using `typicalWatts` × a per-category diversity factor (amplifiers
350‰ by default), with nameplate as an advisory second line, a linear-supply amplifier at PF
0.65 under-reports current by 35% under a naive `watts / 120`, which is how a system that
"calculated fine" trips a breaker (AC-020, CR-056).

`power.bonding` exists so a bonding conductor is *drawable* and therefore appears on the drawing;
the full busbar entity and conductor sizing are v1.2 (RJ-010). Links on `power.*` originating at
a PDU outlet auto-classify as `LinkClass.powerCord` and are excluded from the pull sheet by
default, appearing instead as an **outlet map** on the power schedule (AC-026).

#### Structure: `#999999`, glyph ★ home run / ☆ pathway

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `structure.undetermined` | Undetermined home run | `conn.unterminated` | passive | P2P | `6,3,3,3` | 0.75× | `STR` | ★ |
| `structure.pathway` | Pathway only (conduit / pull string) | — | passive | — | `1.5,3,1.5,9` | 0.75× | `PATH` | ☆ |

`structure.undetermined` is the interesting case and it is deliberate: a Cat6 home run at
rough-in may end up carrying Ethernet, HDBaseT, or nothing. The family is legal, it schedules, it
prints, it gets a `W` number and both labels, and the DRC validates **retroactively** once a
`Service` assigns a real family. `structure.pathway` pairs with `MediaTypeDef.isPathwayOnly`,
it creates a `Pathway`, never a Link and never a Port, appears on the pull sheet (you still pull
the smurf tube and it still costs money) and never appears in the netlist (CR-109).

---

### 6.5 `MediaTypeDef`: the shipped cable types

`MediaTypeDef{id, displayName, shortTag, conductorCount, pairCount, gaugeAwg, impedanceOhms,
shielded, availableJackets[], maxChannelLength, minBendRadius, outerDiameter, supports[],
isPathwayOnly, aliases[]}`. **User-extensible in v1**: an unmatched media value in a Structure
CSV import is not rejected; it is created as a new user media type with a confirmation chip
(RJ-009), which is the difference between an import that works and one that throws.

| id | Display | Tag | Cond / pairs | AWG | Ω | Shielded | Max channel | Supports (primary) |
|---|---|---|---|---|---|---|---|---|
| `media.cat5e` | Cat5e UTP | `C5E` | 8 / 4 | 24 | 100 | no | 100 m | `net.ethernet`, `video.hdbaset` (1080p), `ctl.*` on spare pairs |
| `media.cat6` | Cat6 UTP | `C6` | 8 / 4 | 23 | 100 | no | 100 m | `net.ethernet`, `video.hdbaset` |
| `media.cat6_futp` | Cat6 F/UTP | `C6S` | 8 / 4 | 23 | 100 | **yes** | 100 m | as above; preferred for HDBaseT |
| `media.cat6a_futp` | **Cat6a F/UTP** | `C6A` | 8 / 4 | 23 | 100 | **yes** | 100 m | `net.ethernet` 10G, `video.hdbaset` 4K, `audio.dante` |
| `media.rg6` | **RG6** | `RG6` | 1 coax | 18 | 75 | yes | ~150 m | `rf.catv`, `rf.ota`, `rf.modulated` |
| `media.rg6_quad` | RG6 quad-shield | `RG6Q` | 1 coax | 18 | 75 | yes | ~150 m | `rf.satellite` (swept to 3 GHz), `rf.catv` |
| `media.rg59` | RG59 | `RG59` | 1 coax | 20 | 75 | yes | ~100 m | `video.composite`, `audio.spdif_coax` |
| `media.rg11` | RG11 | `RG11` | 1 coax | 14 | 75 | yes | ~300 m | `rf.catv` trunk |
| `media.coax_video_75` | Precision 75 Ω video coax (1694A class) | `V75` | 1 coax | 20 | 75 | yes | 12G ~45 m | `video.sdi`, `video.component` |
| `media.mic_stp` | Mic / line shielded twisted pair | `STP2` | 2 + shield | 22 | — | yes | 100 m+ | `audio.mic`, `audio.line_bal` |
| `media.aes_110` | 110 Ω AES/DMX cable | `Z110` | 2 + shield | 22 | 110 | yes | 100 m | `audio.aes3`, `ctl.dmx512` |
| `media.dmx_120` | 120 Ω DMX / RS-485 cable | `Z120` | 2 + shield | 22 | 120 | yes | 1200 m | `ctl.dmx512`, `ctl.rs485` |
| `media.16_2` | 16/2 speaker | `16/2` | 2 | 16 | — | no | gauge/length table | `audio.speaker_lowz` |
| `media.16_4` | 16/4 speaker | `16/4` | 4 | 16 | — | no | — | `audio.speaker_lowz` (stereo or bi-amp on one pull) |
| `media.14_2` · `media.14_4` | 14/2 · 14/4 speaker | `14/2` `14/4` | 2 / 4 | 14 | — | no | ~15 m at 8 Ω | `audio.speaker_lowz` |
| `media.12_2` | 12/2 speaker | `12/2` | 2 | 12 | — | no | — | `audio.speaker_lowz` long runs |
| `media.18_2_cv` | 18/2 constant-voltage | `18/2` | 2 | 18 | — | no | hundreds of feet | `audio.speaker_cv` |
| `media.22_2` · `media.22_4` | 22/2 · 22/4 control | `22/2` `22/4` | 2 / 4 | 22 | — | optional | long | `ctl.contact`, `ctl.trigger12v`, `ctl.ir_emitter` |
| `media.cresnet_18_22` | Cresnet (18 AWG power + 22 AWG data) | `CN` | 4 / 2 | 18 + 22 | — | yes | 915 m data · **333 ft at 20 W** | `ctl.cresnet` |
| `media.knx_tp1` | KNX TP1 bus cable | `KNX` | 2 (+2) | 22 | — | yes | 1000 m | `ctl.knx` |
| `media.dali_2c` | DALI 2-conductor (mains-rated) | `DALI` | 2 | 18 | — | no | ~300 m | `ctl.dali` |
| `media.hdmi_passive` | HDMI, passive | `HDMI` | 19 bonded | — | — | yes | 2.1: 3–4.5 m · 2.0: ~7.5 m | `video.hdmi.*` |
| `media.hdmi_active` | HDMI, active copper | `HDMIA` | 19 bonded | — | — | yes | ~7.6 m | `video.hdmi.*`: **direction-locked** |
| `media.hdmi_aoc` | HDMI, active optical (AOC) | `AOC` | hybrid | — | — | — | 15–90 m+ | `video.hdmi.*`, **direction-locked, source/display ends marked** |
| `media.dp_cable` | DisplayPort cable | `DP` | — | — | — | yes | DP80 passive 1.2 m | `video.displayport` |
| `media.usbc_cable` | USB-C cable | `USBC` | — | — | — | yes | ~1–2 m at full BW | `video.usbc_dpalt` |
| `media.om3` · `media.om4` | Fibre OM3 · OM4 multimode | `OM3` `OM4` | 2 strands | — | — | — | ~300–400 m at 10 G | `net.fiber_mm` |
| `media.os2` | Fibre OS2 singlemode | `OS2` | 2 strands | — | — | — | 10–40 km | `net.fiber_sm` |
| `media.pof_toslink` | Plastic optical fibre (TOSLINK) | `POF` | 1 | — | — | — | ~5–10 m (glass 30 m+) | `audio.spdif_optical` |
| `media.so_cord` | SO / SJ power cord | `SO` | 3 | 14–12 | — | no | — | `power.ac_branch` |
| `media.iec_cordage` | IEC rated cordage | `IEC` | 3 | 18–14 | — | no | short | `power.ac_iec` |
| `media.bonding_6awg` | Bonding conductor | `GND` | 1 | 6 | — | no | — | `power.bonding` |
| `media.conduit_emt` · `media.conduit_ent` | EMT conduit · ENT (smurf tube) | `EMT` `ENT` | — | — | — | — | — | **`isPathwayOnly: true`** |
| `media.pull_string` | Pull string | `PULL` | — | — | — | — | — | **`isPathwayOnly: true`** |

`JacketRating` is `cl2 | cl3 | cmr | cmp | lszh | directBurial`. It is not decorative: `CODE-002`
is an error when `Pathway.kind == plenumSpace` and the jacket is not `cmp` or `lszh` (NEC
800.154), and `CODE-001` is an error when a Class 2/3 conductor shares a pathway with line
voltage (NEC 725.136). Both are acknowledgeable like every other rule (CR-019), an inspector's
judgement outranks ours, but **the finding must exist**, because these are two of the very few
checks in the whole product that protect the user from a code citation and a red-tagged job
(AC-027).

---

### 6.6 Requirement 4 coverage

Requirement 4 names ten cable types and demands the plan be colour-coded by them. Part 1 accepted
(AC-054) that hue-per-type is not achievable safely and resolved it as: **hue = domain; dash +
weight + glyph + tag = type; the legend prints one row per named type in colour and greyscale side
by side.** This is the audit that the resolution actually covers what was asked.

| Named in requirement 4 | Canonical family (or media) | Effective hue | Dash | Wt | Glyph | Tag |
|---|---|---|---|---|---|---|
| **Analog RCA** | `audio.line_unbal` | `#E69F00` | `6,3` | 1.00× | ● | `AUD` |
| **HDMI** | `video.hdmi.2_0` / `2_1` / `1_4` | `#0072B2` | solid | 1.00× / 1.25× / 0.75× | ▲ | `HD20` `HD21` `HD14` |
| **Network** | `net.ethernet` (+ `net.poe`) | `#009E73` | solid | 1.50× / 2.00× | ■ | `NET` `PoE` |
| **IR** | `ctl.ir_emitter` (+ `ctl.ir_receiver`) | `#CC79A7` | `1.5,3` / `4,3,1.5,3` | 0.75× | ✚ | `IR` `IRRX` |
| **RS-232** | `ctl.rs232` | `#CC79A7` | `6,3,1.5,3` | 0.75× | ✚ | `232` |
| **RG6** | `media.rg6` carrying `rf.catv` / `rf.satellite` / `rf.ota` | `#56B4E9` | `12,4` / `12,4,3,4` / `16,4` | 1.50× / 1.50× / 1.00× | ▽ | `RF` `SAT` `OTA` |
| **S/PDIF** | `audio.spdif_coax` | `#D55E00` | `12,4,3,4` | 1.00× | ◆ | `SPD` |
| **TOSLINK** | `audio.spdif_optical` | `#D55E00` | `2,3` | 1.25× | ◇ | `OPT` |
| **Speaker level** | `audio.speaker_lowz` (+ `audio.speaker_cv`) | `#E69F00` | `6,3` / `10,3,2,3` | **2.00×** | ◐ / ○ | `SPK` `70V` |
| **Power** | `power.ac_branch` / `power.ac_iec` | `#000000` | `8,3,1.5,3,1.5,3` / `8,3,1.5,3` | 2.00× | ⬢ | `PWR` `IEC` |
| *"etc."* | 37 further families across the same 8 domains | — | — | — | — | — |

The two within-domain collisions the requirement would have produced are both resolved on
non-hue channels, and both resolutions are legible in a greyscale photocopy:

- **Analog RCA vs speaker level** (both `#E69F00`): identical dash, but **1.00× vs 2.00×** stroke
  and ● vs ◐. A 2× weight difference is the single most legible mono discriminator available.
- **S/PDIF vs TOSLINK** (both `#D55E00`): `12,4,3,4` long-short @ 1.00× vs `2,3` fine dot @ 1.25×,
  and ◆ vs ◇, separated on three channels, not two. S/PDIF's earlier `6,3,1,3` is retracted: at
  class `(dot,short)` it collided with six `ctl` families, RS-232 among them, which is two of the
  ten named types rendering as one line. The authority for both values is `tools/pal1_check.py`.

RG6 is correctly a **medium**, not a signal (that is the point of the three-axis split), so it is
colour-coded by what it carries. The legend row for RG6 shows all three of its families, which is
more informative than a single "RG6" swatch would have been.

---

### 6.7 Acceptance criteria for this registry

These are named milestone exit criteria, not aspirations.

1. **Provenance.** Every numeric field in every registry entry carries a cited source
   (manufacturer datasheet, published standard, or measured) in `assets/catalog/sources.md`.
   An entry whose safety-adjacent fields (`pinoutVariant`, `impedanceOhms`, `poeBudgetWatts`,
   `maxRunLengthPassive`, PoE class watts) are uncited **does not ship** (AC-052).
2. **CVD verification.** The `T0.01` legend sheet is rendered and checked under **protanopia and
   deuteranopia simulation**, and every pair of domains must remain distinguishable (AC-054).
3. **Greyscale verification.** The same legend is printed on a **real greyscale office laser** at
   ANSI B and photocopied once, and every one of the ten requirement-4 types must remain
   identifiable. The entire dash-and-weight argument is predicated on this test, so it is run on
   hardware, not simulated (AC-058/D13).
4. **PAL-1 is a unit test.** Compute WCAG relative luminance for all eight domain colours; for
   every pair within 0.10, assert differing dash class and a weight ratio ≥ 1.4.

   > **Superseded — see §14.1 and §14.5.** PAL-1 is a **pairwise** test over **rendered family values**, not the eight domain colours, and its two limbs are **disjunctive** (dash class differs **or** weight ratio ≥ 1.4), not conjunctive. The conjunctive domain-level form stated here is unsatisfiable by the shipped palette and is what allowed fourteen collisions to ship. The authority is `tools/pal1_check.py`.

5. **Dash floor is a unit test.** Assert every shipped dash period ≥ 4.5 pt (1.5875 mm). 4.25 pt is
   1.4992 mm and is *below* the 1.5 mm physical floor the rule derives from (§14.4).
6. **Glyph coverage is a unit test.** Assert every glyph in the registry resolves in `RackBody` or
   `Noto Sans Symbols 2`.
7. **Referential integrity is a unit test.** Every `defaultConnector` resolves; every
   `typicalMedia` entry resolves; every `MediaTypeDef.supports` entry resolves; every
   `SignalFamilyDef.domain` resolves to one of the eight; every connector referenced by a shipped
   template has a footprint entry (AC-050/A2.2); no two catalog templates share a `typePrefix`
   with a system prefix (CR-043).
8. **DRC fixtures.** Every rule that reads this registry ships with one known-bad design that must
   produce exactly that finding and one known-good near-miss that must not. **No rule ships
   without its pair** (AC-051).
9. **Domain-expert review** of the shipped registry values and the rule catalogue is a named
   milestone exit criterion, not a code review.

---

**End of Part 2.** Part 3 carries the rule catalogue (`docs/rules.md`), the visual language
document, the arbitrated keymap, the sheet set and export contract, and the milestone plan with
its binding v1 cut list, none of which may contradict Parts 1 or 2.




**Status:** NORMATIVE, continuing Part 1 (rulings `CR-nnn` / `AC-nnn` / `RJ-nnn`) and Part 2.
**Scope of Part 3:** the scope ruling, the core loop, the milestone plan, and the open questions
that are deliberately *not* ruled on.

Every ruling in this Part cites the Part 1 IDs it derives from. Where this Part and Part 1
appear to disagree, Part 1's ruling on the *mechanism* governs and this Part's ruling on the
*release it lands in* governs; they are different axes and neither overrides the other.

---

## 7. Scope ruling

### 7.0 How the split was made

Four filters, applied in this order. A feature must pass all four to be in v1.

1. **Requirement filter.** Does one of the seven brief requirements fail without it? If yes it is
   in v1 regardless of cost. This is why the schematic canvas survives (RJ-001, RJ-002), why the
   device builder survives, why the Structure device survives, and why the PDF must contain both
   the diagram and the schedule.
2. **G5 filter: cheap now, ruinous later.** Does omitting it cost a file-format migration, a
   command-stack rewrite, or a reconstruct-and-confirm pass over existing user data? If yes, the
   *model* ships in v1 even when the *UI* does not. This is the single most-used rule below and
   it produces the "model ships, gesture defers" pattern that appears eleven times.
3. **G1 filter: does it serve the schedule?** Does it make the schedule more correct, or get the
   user to the schedule faster? `critique-ux-simplicity.md` is right that the corpus states this
   thesis and then spends ~70% of its design effort contradicting it. Features that fail this and
   pass nothing else are cut.
4. **Honesty filter: G4.** Does it fabricate a number, or present a heuristic with authority it
   has not earned? If yes it is cut or demoted regardless of cost, because the failure mode is
   not a missing feature, it is a user who stops trusting every number in the product.

Two things this ruling deliberately does **not** do:

- It does not adopt `critique-feasibility.md #5`'s cut table (RJ-008) or
  `critique-ux-simplicity.md`'s "what v1 actually is" (RJ-001, RJ-002, RJ-003, RJ-004, RJ-005,
  RJ-006, RJ-007). Both cut things the brief fixed. Their *diagnosis* is accepted in full; their
  *remedies* overshoot in the specific places named in §3 of Part 1.
- It does not treat "cut" as "deleted". Everything below has a named home: v1, v1.1, v1.2, v2, or
  the explicit not-doing list. Nothing is left in the ambiguous "later" state that
  `critique-completeness.md` correctly flags as where scope goes to rot.

### 7.1 The v1 line, stated in one paragraph

> **v1 is a single-window Windows desktop application in which a professional integrator builds
> one or more racks from a seeded catalog of generic archetypes, wires them on a schematic canvas
> with drag-to-connect, watches a cable schedule fill in live in a second tab, and exports a
> PDF sheet set containing front and rear elevations, a signal-flow diagram, a pull sheet, a
> termination schedule, an equipment list, a legend, and an exceptions page — with a device
> builder for the long tail, a Structure device for the wiring entering the rack, and twenty-two
> validation rules that never block a deliverable.**

If a feature is not required by that sentence, it is not in v1.

### 7.2 v1: in scope

Grouped by subsystem. The **Why** column names the filter or the ruling that puts it here.

#### 7.2.1 Core, format, and infrastructure: all of it, no exceptions

| Item | Why |
|---|---|
| `Len` = int64 nanometres, `Mass` = int64 micrograms, `Money` deleted, `Permille`, one `UnitFormatter` | CR-001, CR-003, AC-001. The two discriminating tests (1/32-in clearance, 45U accumulation) are written before any other code |
| `Pt{int gx, int gy}` in 2.5 mm grid units; no sub-grid | CR-004 |
| 1 diagram unit = 1 PDF point at the canvas boundary, `double`, converted in exactly one function | CR-007 |
| UUIDv7 identity, tombstones, `EntityMeta`, flat maps, `FracIndex` ordering everywhere including `.rmdev` | CR-027, CR-095, G5. `critique-ux-simplicity.md`'s own do-NOT-cut list, accepted wholesale |
| `revision` (dirty-tracking, non-monotonic) **and** `sequence` (strictly monotonic sync cursor) as two counters | CR-094, AC-004 |
| Plain pretty JSON `.rackmate`, single file, `schemaVersion`, hand-written codecs, migration chain + golden corpus | Confirmed decision 3; architecture step 2 |
| **Unconnected ports are not materialised as document entities**; ports resolve by key-join from the template snapshot, with a per-device allocation watermark | AC-006. This is what makes the file-size budget real rather than 3–6× wrong |
| `Command` / `Transaction` / `UndoStack` / `DocumentController` as the single mutation gate, with the round-trip property test and the epoch-mask coverage test | Architecture step 3; AC-014. The most expensive retrofit in the project |
| `@internal` setters, not `part of` | AC-013 |
| Epoch counters; three-tier derived pipeline; `lodLevel` explicit in every scene-builder signature and every cache key | AC-016 (#13) |
| `DiagramCanvas` display-list IR, `TextMetrics{advanceWidth, ascent, descent, capHeight, xHeight, lineHeight}`, explicit `TextAnchor` resolved in the shared scene builder, both backends fed by `PdfFont.stringMetrics`, baseline-y parity test | CR-087, AC-007. Architecture step 6 |
| `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` built first; no editor logic branches on `PointerDeviceKind` | AC-016 (#23). Confirmed decision 1 makes this non-optional |
| Atomic save, autosave, crash recovery, close interception, recents | Architecture §7 |
| i18n plumbing with one locale; `l10n.yaml` in CI; localisable registry display names | AC-058 (D12) |
| Import hardening: JSON depth/size limits on every import path | AC-058 (D8) |

#### 7.2.2 The rack

| Item | Why |
|---|---|
| Racks 1–60 RU, per-rack `ruNumbering` and `mirrorRearElevation` with project defaults | CR-038, CR-026, CR-035 |
| 1-based bottom-origin `ruIndex`, asserted at load | CR-025 |
| Sealed `Placement` union (rail, shelf, zero-U, off-rack, staged) with `chassisRotation`, `locked`, and lateral twelfths in the format | CR-031, CR-030, AC-023 |
| Front/rear elevation editing, quick-add by typing, drop caret, marquee | Best interaction in the corpus per the friction inventory |
| Staging Bin as `StagedPlacement` with the return affordance | CR-032 |
| Shelves as containers, child→parent only, **auto-pack left to right** | CR-029, AC-043 |
| 0U occupants created and edited **from the inspector** (channel, start U, span), rendered as plain bars | AC-044 |
| Half-rack via a three-value `Width position` dropdown | CR-030 |
| Compact Down / Compact Up with preview-then-accept; the shrink-rack dialog pattern | AC-045 |
| Locks: `Placement.locked`, `DeviceInstance.designatorLocked`, `Link.designatorLocked` auto-set at `RoughInStatus >= pulled` | CR-034, AC-034 (m22) |
| Depth occupancy as an interval per (RU, face), not a boolean | AC-022 |
| Always-visible chip strip: **RU, weight, power in VA, outlets**. Everything else in a collapsed advisory panel, closed by default | AC-039 |

#### 7.2.3 Wiring

| Item | Why |
|---|---|
| `Link` → `Service` → `Conductor`, plus stored `Net` with `Service.netId` as the FK | CR-008, CR-010, CR-011, RJ-003 |
| The word `Connection` banned from code, format, and prose | CR-008 |
| `Endpoint` sealed union: `PortEndpoint`, `PlaceEndpoint`, `OpenEndpoint`; `LifecycleStatus.designIntent` | AC-018. The most consequential single finding in the four critiques |
| `Link.class{fieldCable, jumper, powerCord, internal}`, auto-classified; schedule excludes jumpers and power cords by default | AC-026 |
| Three length fields: `routedLength`, `cutLength`, `terminatedLength`; `Location.estimatedRunLengthFromRack`; estimates rendered distinctly everywhere | AC-024 |
| `Pathway` as a first-class entity with `kind` and `containsLineVoltage` | CR-016, AC-027 |
| `InlineAdapter` for passive one-cable adapters; real devices for anything an installer pulls two cables to | CR-015 |
| Conductors ship in model and format; the v1 **gesture** covers `atomicConnect` sets only | AC-053, RJ-016 |
| Schematic canvas: Sugiyama phases 0–4 + interval-graph channel routing, full deterministic recompute; phase 5 (crossing sweep, hops) at paint time, viewport-scoped | CR-013, AC-016 (#20) |
| No route geometry persisted; symbol placement persisted | CR-012 |
| Drag-to-connect with magnetic type-weighted snap, chain-draw, multi-draw, pinning on manual move, one `Tidy sheet` command | RJ-001 |
| Domain filter bar, auto net-label degradation, symbol collapse to vector pins, `Alt`-hover transient focus | `critique-ux-simplicity.md`'s density table, accepted |
| **One** schematic sheet, with the `Sheet` entity present in the format | CR-073, AC-037 |
| Wiring is signposted from the rack elevation; the schedule table is the **second tab**, live from an empty project | CR-105, AC-035 |
| Hue = domain; dash + weight + tag = type; per-family colour override in settings; legend prints one row per named cable type in colour and greyscale | AC-054 |

> **The router row is superseded — see §12.1.** v1 builds Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal staircase. Phase 4 is v1.2; phase 5 is not built. The remaining rows of this table stand, as amended by the §7.2.3 row already listed in §12.1.

#### 7.2.4 Structure and the field

| Item | Why |
|---|---|
| `Outlet` (ex-`StructureBundle`) as the creation/specification atom | CR-016 |
| `StructureDrop` **deleted**; a home run is a `Link` with `structureOrigin` | AC-019, CR-107 |
| Dual labels: `fieldLabel` required and `rackLabel` optional, both generated, both editable, **both always print, on every cable** | CR-044, AC-025, AC-047 |
| Structure editor opens in **table mode** with `+ Add drop`; the room × media matrix is a tab | AC-048 (cliff #4), RJ-004 |
| Outlet templates first-class; TIA-570-D grades as presets and a standards tag | AC-034 (m23), CR-108 |
| Location tree owned by a **project-level** panel, not by the Structure editor | CR-047, CR-112 |
| Multiple Structure instances | CR-113 |
| CSV import with synonym mapping | RJ-004 |
| 18 **Field Devices** templates, `mountMethod: notInRack`, authored through a stripped builder form | AC-031 |

#### 7.2.5 Device builder and catalog

| Item | Why |
|---|---|
| **Three required fields (name, RU height, designator prefix) then ports, then done.** Everything else optional with a visible `unknown` state | AC-049, CR-114 |
| The port grid in full: fill-down, TSV paste, multi-row edit, archetype generators, the pattern DSL | AC-049. The grid was never the barrier |
| Banks (presentation) and `PortSetDef` (electrical) as two distinct concepts | CR-055 |
| `PortDef.key` + `renamedFrom` as the migration join | CR-051 |
| Three doors: edit this device only / edit the template / fork to a new template. No fourth | CR-054 |
| Typed `DeviceOverrides` and `PortOverrides`; port overrides live on the port | CR-053, AC-012 |
| Copy-on-place; `templateRef{templateId, version, contentHash}` recorded; a passive "based on an older catalog template" badge | AC-041 |
| `contentHash` kept; hash mismatch is a **warning plus a badge**, never a load failure | AC-042 |
| Single `.rmdev` export/import | AC-042 |
| Full catalog at **full fidelity with cited provenance**: every numeric field sourced in `assets/catalog/sources.md`; a template with uncited safety-adjacent fields does not ship | RJ-007, AC-052 |
| Connector footprint table completed for **every** connector in the shipped catalog, with a CI assertion | AC-050 (A2.2) |
| Media-type editor and connector aliases; `SignalFamilyDef.topologyFree` as data | AC-050 (A2.1), AC-030, RJ-009 |

#### 7.2.6 Validation

| Item | Why |
|---|---|
| Rules are **Dart functions** in a registry; the catalogue metadata is data; the connector × signal-family compatibility matrix stays a lookup table | CR-024, AC-011 |
| **27 rules**, listed once in **§5** of this record | AC-040, corrected by §12.6(b); home per §10.12(g) |
| `error \| warning \| advisory \| off`; per-project `RuleOverride{severity, reason, by, at}` | CR-018, CR-019 |
| One dismissal mechanism, `AckedFinding`, at two scopes; **errors are acknowledgeable** | CR-019, RJ-006 |
| Only `TOP-001..005` and placement coherence are model-illegal; Class A becomes spring-back with a reason chip and `[ Connect anyway ]` | CR-017 |
| Nothing blocks export; `ExportSpec.issuedForConstruction` is the only thing errors gate | CR-022, AC-035 |
| **DRC fixture corpus: no rule ships without a known-bad and a known-good near-miss** | AC-051. This is also the gate that holds the catalogue at **27** (§12.6(b)) |

#### 7.2.7 Export

| Item | Why |
|---|---|
| `T0.01` legend · `T0.02` exceptions & acknowledgements · front elevation · rear elevation · one schematic sheet · **Pull Sheet** · **Termination Schedule** · `T6.30` Equipment List and Materials | CR-022, AC-025, AC-055 |
| Pull Sheet sorted by room then pathway; Termination Schedule by rack then panel then port; both carry location and both labels on both ends, plus conductor colours | AC-025 |
| Cable footage rollup by media with a waste factor | AC-024 |
| No pricing. `Money`, `cost`, `supplier`, `purchaseOrder` deleted from v1 | AC-055 |
| Legend location auto-filled by the exporter; no invariant, no gate | CR-023 |
| `sheetNumbering: ncs \| simple`, default `simple` | CR-066, AC-034 (m17) |
| Sheet-count dry run, warning above 40 sheets, hard cap 2000 | AC-050 (A7.4) |
| Print test matrix on real hardware: laser at ANSI B/A3, plotter at ANSI D, and a photocopy | AC-058 (D13). The whole dash-pattern argument is predicated on it |
| Deuteranopia/protanopia simulation and a real greyscale laser print as a named acceptance criterion | AC-054 |

#### 7.2.8 Platform, quality, and release

| Item | Why |
|---|---|
| Mobile/tablet **read-only** on exactly three surfaces: rack elevation, schedule table, exported PDF, and the app says so rather than shipping a squeezed editor | AC-056. Confirmed decision 1, honoured honestly |
| The outline tree | `critique-ux-simplicity.md` #15. The only honest accessibility story a canvas app has |
| A fully specified keyboard path to create a connection; WCAG AA target; filtered-wire alpha raised to a tested floor; NVDA/VoiceOver matrix | AC-058 (D11) |
| ~40 keybindings, one arbitrated table, generated from one `Intent` registry; the 16 collisions fixed | CR-101, AC-046 |
| `docs/glossary.md` shipped in-app as a searchable panel; `[Why?]` wired to `rationale`; one error-message catalogue with one voice | AC-058 (D1) |
| The eight missing empty states; the full file-layer error surface incl. "target PDF open in Acrobat" | AC-058 (D3, D4) |
| Progress and cancel on **every** operation over ~500 ms | AC-058 (D14) |
| Four starter projects authored as real `.rackmate` files, doing triple duty as goldens, perf fixtures, and screenshot source; at least one exercises Structure and one exports a full sheet set | AC-052 |
| SIL OFL 1.1 registered via `LicenseRegistry`; `showLicensePage` wired; licence model and EULA as named deliverables | AC-058 (D7) |
| Windows code signing with certificate procurement started **two milestones early**; vendored pdfium; release pipeline with symbol archival | AC-058 (D10) |

> **The code-signing row is superseded — see §12.9 and §11.6.** Read it as: Windows code signing **self-signed with a timestamp server**, no certificate procured early, Microsoft Trusted Signing as the named fallback at M8. Vendored pdfium and the release pipeline with symbol archival are **unchanged**.

### 7.3 v1.1: the fast follow

Everything here is **additive**: no format migration, no command-stack change, no re-derivation of
existing user data. That is the criterion for the v1.1 bucket, not effort.

| Item | Deferred by | What it costs to wait |
|---|---|---|
| 0U gutter **interactions**: 16 px gutters, rotated bars, drag-into-gutter, resize handles, the `G` toggle, channel-overlap warnings | AC-044 | Inspector-only editing of a real occupant; not lossy |
| Free lateral positioning on shelves, `Alt`-drag, the third focus level, per-host overhang warnings | AC-043 | Auto-pack covers the common case |
| Free lateral dragging of half-rack devices | CR-030 | The dropdown covers all three real positions |
| Hand-authoring an arbitrary conductor map | AC-053 | `atomicConnect` covers component video, stereo pairs, and 16/4, the cases the decision exists for |
| The rear-panel view as a printable sheet | CR-071, feasibility #5 | The termination schedule carries the same information in table form |
| `Trace` through pass-throughs, and the search DSL | AC-040 | Both are navigation, not correctness |
| Manual reroute, stored as `routeConstraintsBySheet` (ordered grid points the router must pass through), never as a polyline | CR-012 | The router is deterministic; the itch is aesthetic |
| Registry editor beyond media types and connector aliases | AC-050 (A2.1) | The two extensibility paths users actually hit already ship |
| **Submitting a device to the community catalog**: the Device Builder's review sheet, GitHub sign-in by authorization code with PKCE, the fork-branch-commit-pull-request sequence, and the port-photograph citation | **DR-033**, a scope addition under §8.3. **Precondition discharged by DR-036** (§11.35): the posture and licence are ruled | The `.rmdx` still exports and imports, so a device is still shareable as a file (DR-015). What waits is the one-click path and the shared library it fills. **`TemplateBody.submittedBy` does not wait** and ships in v1, because the template body has no `unknown` passthrough and a v1 build would drop the credit on save (§11.32.8) |
| **Installing and updating the community library**: the bundled snapshot, the first-run opt-in card, the `.rmda` release-asset fetch, and the once-daily `releases/latest` check behind a non-modal notice | **DR-034**, a scope addition under §8.3, sharing DR-033's now-discharged precondition | Nothing, until DR-033's row ships: an empty library has nothing to distribute. The seeded catalog is unaffected and is what v1 draws from. **The separation of the two libraries is not deferrable** and is a determinism gate, because a golden that resolves a template out of a fetched library depends on a release tag (§11.33.5) |

### 7.4 v1.2: the second release

Items here need either a format addition, a fixture corpus, or evidence from real projects. All
are pre-committed in the sense that the model already accommodates them (G5); none is promised on
a date.

| Item | Gate |
|---|---|
| **Multi-sheet**, partitioned **by domain only**, which by construction has zero cross-sheet connections, so off-sheet connectors, zone grids, and cross-reference resolution are never built | CR-073, AC-037. Ships when real projects show which partition users want |
| The remaining ~40 DRC rules: the `BUS-*` family, `ELE-004/005/008`, the length rules, impedance, DMX universes, DALI counts, Cresnet voltage drop, RF cascade, satellite DC-pass, fibre polarity | AC-040, AC-051. **Each ships only with its fixture pair.** This is the whole gate |
| The template **Update Manager**: opt-in migration, safe/additive/breaking grouping, per-cable `[Remap]` / `[Keep as orphan]` | AC-041. `[Del]` never ships (CR-052) |
| Auto-arrange with trade heuristics; fill gaps with blanks/vents, gated on `Rack.formFactor` | AC-045, AC-034 (m20) |
| Buses as graphical grouping with 45° entries | RJ-001 |
| Sub-grid annotation nudging as `int sx, sy` in eighths of a gu, if it is ever needed | CR-004 |
| Bays: `Bay{id, name, order, rackIds}`, a pure addition | CR-033 |
| Full commercial grounding and bonding detail sheet | AC-034 (m21), RJ-010 |

### 7.5 v2: the next product decision, not the next release

Each of these changes what the product *is*, and each should be decided with evidence from v1
users rather than now.

| Item | Note |
|---|---|
| `SignalRoute`: Dante flows, AVoIP streams, matrix crosspoints, eARC, VLAN/multicast/latency | CR-008, AC-036. Returns **with** a Dante view or not at all. A third entity layer with no editor is dead weight |
| **Layers**: Existing / Phase 1 / Phase 2 / Future / Demo | CR-064, AC-038. Real for commercial retrofit; absent from the residential first job; multiplies every filter and every print flag. `DeviceStatus` covers 80% for one field |
| Cloud sync and multi-user | The model is already cloud-ready (stable UUIDs, `schemaVersion`, no positional identity, tombstones, `sequence`). Nothing more is spent until someone asks. **SUPERSEDED, SPLIT IN TWO BY DR-052, see §12.22**: sync moves *forward* to v1.2 (git) with divergence detection in v1, and **simultaneous multi-user editing moves to never**. The reasoning in this cell survives and is what made the split possible: a cloud-ready model is why sync is cheap, and it is irrelevant to concurrent editing |
| Mobile **editing** | v1 is read-only by confirmed decision; the intent layer keeps the door open |
| A read-only **web** viewer | AC-016 (#22). One `kIsWeb` guard already exists; distribution story, not a feature |
| Unit splitting (`MTX1:A/:B/:C`) | CR-070. Only if multi-sheet lands and users demonstrably need it. It is a confusion generator and collapse covers most of the ground |
| A priced BOM with suppliers and purchase orders | AC-055. This is an adjacent product, not a missing feature |
| Real-SKU catalog | See §10.9: a legal and maintenance question before it is a product one |

### 7.6 Not doing: and these are rulings, not omissions

| Item | Ruling |
|---|---|
| **A rule-authoring UI and the JSON predicate AST** | The claim that users can author rules is **withdrawn from all documents**. ~20 of 70 rules cannot be expressed in a boolean predicate tree, so the AST buys a second rule system, a second debugger, and a second test suite for rules nobody can write without a UI that was never designed. CR-024, AC-011 |
| **A full registry authoring UI** | RJ-012. Media types and connector aliases ship because users hit them; a general registry editor is a database admin tool wearing a product's clothes |
| **Multi-document tabs** | RJ-013. One window, one document, multiple windows if you want two |
| **Tagged / accessible PDF (PDF/UA)** | RJ-015. The accessibility budget buys the outline tree, the keyboard connection path, and the NVDA matrix, all of which help a real user. A tagged schematic helps nobody who could not already read the schedule table |
| **An in-app update mechanism in v1** | RJ-014. Signed installer plus a version-check ping; auto-update is a security surface and a support burden before there are users |
| **Device images** | AC-057. The device-builder document already calls them a scope trap. Cutting them resolves the container question, removes the image-decode import surface, and removes ~1 MB per template |
| **`.rmlib` library packs, signatures, `provenance`/`derivedFrom` chains** | AC-042. `contentHash` survives; the cryptographic apparatus does not |
| **Cable dressing, floor plans, 3D, thermal simulation** | Out of the brief. The brief says the plan ignores cable dressing, and it is right to |
| **`blockExportOnErrors`** | CR-022. Not deferred: deleted. No setting, no equivalent, no exceptions |
| **`Money`, `cost`, `supplier`, `purchaseOrder`** | AC-055 |
| **Silent estimated values** | G4, AC-039. `typicalWatts` never defaults to half of nameplate. Unknown is null, null renders `—`, and every rollup reports its unknown count. Not a scope item, a standing prohibition |

> **Superseded in part — see §12.11 (DR-018).** **Floor plans leave the cable-dressing row** and
> are v1.1, conditionally: v1.2 unless the underlay carrier ships in v1 (roadmap §2.2's additive
> membership criterion). Cable dressing, 3D and thermal simulation are unaffected and stay out. The
> row's rationale had only ever argued cable dressing.

### 7.7 The nine cuts that account for most of the saving

Ranked by engineering weeks removed. Everything in this table is either deferred with a named
home above or ruled out in §7.6.

| # | Cut | From | Weeks saved (feasibility's own sizing) |
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

That is roughly **20–26 weeks removed** from a 62–83 week bottom-up estimate, before counting the
reduction inside the schematic milestone from RJ-001's accepted half. It does not get to
`critique-feasibility.md`'s 5–6 months, and this record does not pretend it does, see §9.11.

---

## 8. The core loop

RackMate is a **cable-schedule generator with a rack elevation and a schematic on the front of
it**. The product's reason to exist is the artifact that leaves the office, gets printed, gets
carried into an attic at 7 pm, and tells an installer what to pull, where it goes, what to call
it, and where to land it, without a phone call. Everything upstream of that artifact is data
entry, and the job of the software is to make the data entry fast enough and structured enough
that the artifact is correct by construction rather than by proofreading. The primary journey it
must make excellent is therefore a single unbroken loop: **create a rack, populate it from a
catalog by typing rather than dragging, wire it by clicking a port and then another port, watch
the schedule fill in live beside you, and export a sheet set that is complete and honest on the
first attempt.** Every one of those five steps is currently a place the corpus puts a cliff (an
empty required-looking dropdown on field two of the first dialog, a wiring surface with no
signpost from the rack that needs wiring, a second canvas that looks nothing like the first, a
schedule discovered only at export time, and an export blocked by a heuristic about a system the
user has not finished designing) and the rulings in Part 1 exist to remove all five (CR-105,
CR-104, CR-022, CR-023, AC-035, AC-048). The drawing is not the deliverable and it is not
decoration either: it is the receipt, the thing the integrator hands the client to prove the
schedule describes a real system, and the thing the integrator themselves reads to find the
mistake. That is why the schematic canvas survives the cut (RJ-001, RJ-002) and why it is
nonetheless allowed to cost a fraction of what the corpus budgeted for it. **The schedule is the
deliverable; the drawing is the receipt; the rack is where the gear lives; the job is the cable.**

---

## 9. Milestone plan

### 9.0 How to read this plan

- **Sizing.** `S` ≈ 2–3 weeks, `M` ≈ 4–7 weeks, `L` ≈ 8–12 weeks, for one experienced engineer,
  implementation only. These are the same units `critique-feasibility.md #5` used, re-bucketed
  against the §7 scope. They exclude design iteration, the bug tail, and anything in §10 that
  changes an answer.
- **Exit criteria are binary and demonstrable.** "Works well" is not an exit criterion. Each one
  below can be checked by running something.
- **Every milestone ends green.** CI passes, goldens pass, the app opens the four starter
  projects. A milestone that ends with a known-broken build has not ended.
- **Two sequencing constraints are binding and come from AC-059:** M0 is not compressible into
  M1, and the rules-as-code decision (CR-024) must be settled before the wiring milestone; it
  is, in Part 1, which is why the wiring milestone can start on schedule.
- **Three architecture-doc sequencing rules survive verbatim** (`design-architecture.md §13`):
  the viewport comes first because everything sits on it and it is cheapest to iterate on when
  nothing else exists; the command stack comes before the feature surface grows; and the display-
  list IR comes before the PDF backend, which makes the PDF backend nearly free. Steps 3 and 6 of
  that list are the two "do it now or pay 10× later" items and they are M0 and M1 here.

### 9.1 M0: Foundations · **S**

Repo scaffolding plus the pure-Dart core. No UI beyond a window that opens.

**Contents.** Monorepo with four packages (CR-083) and the mechanical dependency-rule enforcement
test. `rackmate_core/units/`, `Len`, `Mass`, `Permille`, `Pt`, `Box`, `UnitFormatter`,
`kBtuPerWattHour`. The full entity set from Part 1 as immutable Dart with `@internal` setters
(AC-013). Hand-written JSON codecs both ways, `schemaVersion`, the migration harness, tombstones,
`EntityMeta`, `FracIndex`, `revision`/`sequence`. `Command` / `Transaction` / `UndoStack` /
`DocumentController`. Epoch counters. The `idformat` grammar, registry, and parser (CR-045). CI:
analyze, test, goldens, format, the no-Flutter-import test, the epoch-mask coverage test.

**Exit criterion.** `dart test` is green in `rackmate_core` with: the 1/32-inch clearance test and
the 45U-accumulation test passing exactly (CR-001); a byte round-trip test `write(read(bytes)) ==
bytes` on three fixtures (CR-117, AC-016 #24); the command round-trip property test
(`apply; revert` leaves the JSON byte-identical, including `templates.keys`, AC-015) passing on
1,000 generated command sequences; the epoch-mask coverage test passing for every command type;
and one v0→v1 migration fixture in the golden corpus. `rackmate_core` has zero Flutter imports,
enforced by a test that fails the build.

**Why it is not compressible into M1.** Six decisions, the unit base (CR-001), the wiring entity
model (CR-008), the validation philosophy (CR-017), the template join key (CR-051), the package
layout (CR-083), and the text-metric source of truth (CR-081), each cost a rewrite of everything
downstream if guessed wrong. They are settled in this record; M0 is where they become code and
tests rather than prose.

### 9.2 M1: The elevation release · **L**

**This is the smallest genuinely useful release, and it ships to real users.**

**Contents.** `ViewportController` with wheel/trackpad/pan/zoom and the grid painter, built first.
`CanvasIntent` on top of it, with no `PointerDeviceKind` branching anywhere above (AC-016 #23).
The hybrid `RenderRackCanvas`, device widgets, RU snapping, front/rear elevations with per-rack
mirroring. Quick-add by typing with the drop caret. The Staging Bin. Shelves with auto-pack. 0U
occupants from the inspector. Compact Up/Down with preview-then-accept, and the shrink-rack
dialog. Locks. The full seeded catalog including the 18 field devices, with `sources.md`
provenance and the connector-footprint CI assertion. Copy-on-place with `DeviceOverrides`. The
chip strip: RU, weight, VA, outlets, with unknown counts. `DiagramCanvas` + `SceneBuilder` +
both backends + the baseline-y parity test. A minimal PDF exporter: front elevation, rear
elevation, `T6.30` Equipment List and Materials, title block, revision block. Atomic save,
autosave, recovery, recents, close interception. The outline tree. Four starter projects.

**Exit criterion.** A user can open the app, create a 42U rack, populate it with 20 devices in
under four minutes using only the keyboard, and export a three-sheet PDF whose elevations are
dimensionally correct against a physical tape measure at true scale and whose equipment list
matches the rack contents exactly. The baseline-y parity test passes within 0.5% on a
kerning-heavy string. Undo restores every operation in that sequence.

**Why it is useful standalone: the honest argument.** Integrators produce rack elevations today
in Visio, in Excel with merged cells, in D-Tools if they have paid for it, and in PowerPoint if
they have not. An RU-accurate, dimensioned, printable front-and-rear elevation with an equipment
list is a **billable client deliverable in its own right**: it goes into proposals, it goes to
the GC for closet sizing and power requests, it goes to the millworker for the credenza cut-out,
and it is what gets marked up in the field. Roughly half the observed use of a rack tool never
touches wiring at all. M1 therefore is not a demo or a foundation with a UI bolted on: it
satisfies brief requirements 1 and 2 completely, and a user with only M1 has a tool they would
choose over a spreadsheet. It also puts the two most retrofit-expensive subsystems, the command
stack and the display-list IR, into production against real files before a single wire exists,
which is the sequencing `design-architecture.md §13` argues for and the reason M1 is `L` rather
than `M`.

**What M1 deliberately does not have.** No wiring, no schedule, no schematic, no Structure, no
device builder, no DRC. The app says so, an empty Schedule tab that explains it is coming is a
lie; the tab does not exist yet.

### 9.3 M2: Wiring and the live schedule · **L**

**Contents.** `Link` / `Service` / `Conductor` / `Net` with the `Endpoint` sealed union and
`Link.class` auto-classification. The schematic canvas: symbols with banks, vector-pin collapse,
Sugiyama phases 0–4, interval-graph channel routing, full deterministic recompute, phase 5 at
paint time. Drag-to-connect with magnetic type-weighted snap, chain-draw, multi-draw, pinning on
manual move, one `Tidy sheet`. The domain filter bar, auto net-label degradation, `Alt`-hover
focus. Hue-by-domain plus dash/weight/tag by type, with the per-family colour override setting.
`atomicConnect` multi-conductor gesture. **The schedule table as the second tab**, live from an
empty project, with the Pull Sheet and Termination Schedule presets as two views of one
derivation. Wiring signposted from the elevation (CR-105); the coach mark at the first
rack→schematic switch (CR-104, AC-048).

> **Superseded — see §12.1 (§7.2.3 router row) and §11.1.3.** M2's router is phases 0–3 plus the orthogonal staircase, and M2 is sized `M` (4–7 weeks) — see §12.7.

**Exit criterion.** Starting from the M1 output, a user creates 60 connections without touching a
menu; the schedule tab shows 60 correctly-sorted rows with both labels on both ends and conductor
colours where they exist; the schematic re-lays-out deterministically (same input ⇒ byte-identical
display list) and routes a 300-connection fixture within one frame at commit, with the crossing
count X measured and recorded rather than assumed (AC-016 #20). The keyboard-only path to create
a connection works end-to-end with screen-reader announcements (AC-058 D11).

### 9.4 M3: Structure and the field · **M**

**Contents.** `Outlet`, `structureOrigin`, `PlaceEndpoint` and `OpenEndpoint` in the UI,
`LifecycleStatus.designIntent`. The Structure editor in table mode with the matrix as a tab.
Outlet templates and the TIA-570-D presets. The project-level Locations panel with the
arbitrary-depth tree. Dual-label generation for every cable. The three length fields,
`Location.estimatedRunLengthFromRack`, and the footage rollup with waste factor. `Pathway` with
`kind` and `containsLineVoltage`. CSV import with synonym mapping and the import-over-existing
confirm. Multiple Structure instances.

**Exit criterion.** A 60-drop whole-house rough-in is entered in under fifteen minutes, produces
60 `Link`s each with one `fieldLabel` and one `rackLabel`, and exports a Pull Sheet sorted by room
and pathway with per-room footage subtotals and initial boxes. Fourteen of those drops have
unbound far ends and every one of them still schedules, prints, and carries a `W` number
(AC-018). Requirement 6 is met.

### 9.5 M4: The device builder · **M**

**Contents.** The three-required-field form with everything else optional and a visible `unknown`
state. The virtualised port grid: fill-down, TSV paste, multi-row edit, archetype generators, the
pattern DSL with autocomplete and designed parse errors (AC-050 A2.4). Banks and `PortSetDef`.
The three doors (CR-054). Typed `PortOverrides`. `.rmdev` single-file export/import with
`contentHash` as a warning-level check. The stripped field-device form. The media-type editor and
connector aliases. Undo throughout the builder (CR-106).

**Exit criterion.** A 16×16 matrix template is authored from scratch in under three minutes by a
user who has seen the tool once, and a template saved with exactly three fields plus ports places
into a rack and appears correctly in the equipment list with `—` in every unknown column and an
accurate unknown count in the rollup. Requirement 2 is met in full.

### 9.6 M5: Validation · **M**

**Contents.** The rule registry as Dart functions, the catalogue metadata as data, the compat
matrix as a lookup table. **All 27 rules** (§12.6(b)). Findings, severities, `AckedFinding` at both scopes,
project-wide mutes with reasons. Spring-back with reason chips and remedy chips, each with
`[ Connect anyway ]`. The `[Why?]` rationale viewer. **The DRC fixture corpus.**

**Exit criterion.** Every one of the **27** rules has a known-bad fixture that produces exactly that
finding and a known-good near-miss that produces none, no rule ships without its pair (AC-051).

> **This exit criterion read "22" until 2026-08-03**, five rules short of the count §12.6(b) ruled,
> and it is the site where the arithmetic slip cost the most: an exit criterion is the unit of truth
> under roadmap §8.1, so M5 could have been declared met with `PLC-001..003` and two others
> unfixtured. Corrected per §12.6(b), which directs the replacement in **every** document.
A domain-expert review of the **27** rules and of the catalog data is signed off. No rule, at any
severity, prevents a PDF from being written to disk.

### 9.7 M6: The full sheet set · **M**

**Contents.** `T0.01` legend printing one row per named cable type in colour and greyscale side by
side; `T0.02` exceptions and acknowledgements with every reason, author and date; the schematic
sheet; `T5.01` pinout detail auto-on for non-standard pinouts. Sheet numbering `simple`/`ncs`.
The dry-run sheet count with the 40-sheet warning and the 2000-sheet cap. Export progress and
cancel. Preview. `kIsWeb` isolate guard. The print test matrix on real hardware.

**Exit criterion.** All four starter projects export a complete sheet set; the legend has been
verified under deuteranopia and protanopia simulation and on a real greyscale laser print
(AC-054); the ANSI B laser, ANSI D plotter, and photocopy reproductions have all been physically
inspected and signed off (AC-058 D13). Requirement 7 is met. **All seven brief requirements are
now met.** Windows OV/EV certificate procurement starts here, two milestones before release.

> **The last sentence is superseded — see §12.9 and §11.6.** "Windows OV/EV certificate procurement starts here" is **deleted**. Every other clause of M6's exit criterion stands exactly as written.

### 9.8 M7: Platform and access · **M**

**Contents.** Mobile/tablet read-only on the three named surfaces, with an explicit statement for
the two that are unavailable. WCAG AA pass on the primary surfaces; the raised filtered-wire
alpha; non-colour encoding on rack device fills; the NVDA/VoiceOver matrix. The ~40-binding
arbitrated keymap generated from the `Intent` registry, plus the generated shortcut panel. The
in-app glossary. The error-message catalogue in one voice. The eight empty states. The full
file-layer error surface. Progress and cancel on every operation over 500 ms. Localisation
plumbing verified end to end with a pseudo-locale.

**Exit criterion.** A reviewer opens a `.rackmate` file on a tablet and reads the elevation, the
schedule, and the PDF; the NVDA matrix passes on the elevation, the schedule, and the connection-
creation path; no keybinding is bound twice in the generated table; the pseudo-locale build shows
no hard-coded English in the primary surfaces.

### 9.9 M8: Release engineering · **S**

**Contents.** Signed Windows installer, vendored pdfium, symbol archival, crash reporting
local-first and opt-in remote with the redaction policy reconciled (CR-096), licence model and
EULA, `showLicensePage`, version-check ping. Documented scale limits with the soft warning at 1.5×
and the open-read-only gate at 3×.

**Exit criterion.** A signed installer runs on a clean Windows 11 machine with no SmartScreen
warning, the app cold-starts within budget, a deliberately induced crash produces a local report
containing no project content, and the documented limits behave as documented.

> **The SmartScreen clause is superseded — see §11.6.2.** It splits into a build-side gate (signed, timestamped, valid publisher, **and the signature still validates after the certificate has expired**) and a distribution-side requirement that is documented rather than gated (Local Intranet UNC or Intune/GPO so Mark-of-the-Web is never applied; the ZIP trap stated explicitly). The other three clauses stand as written.

### 9.10 M9: Beta hardening · **M**

**Contents.** No new features. Five real projects from three real integrators, run end to end.
The bug tail. Performance against the recorded budgets rather than the assumed ones.

**Exit criterion.** Three integrators have each produced a sheet set they were willing to send to
a client or a job site, and none of the three needed to leave the app to fix something. That is
the only exit criterion that matters and it is deliberately a judgement, not a metric.

### 9.11 The honest total

> **Superseded — see §12.7.** M2 is `M` (4–7 weeks); the plan totals **42–65 weeks, 11–17 months**. The "41–69" figure below is additionally an arithmetic error against this section's own table, whose final cumulative row reads 45–69. Lever 2 is withdrawn by DR-003.

| Milestone | Size | Cumulative |
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

**41–69 weeks of implementation; 12–18 months to a shipped v1 with normal overhead.** That is
better than the 16–22 months `critique-feasibility.md` priced the unreduced design at, and it is
not the 5–6 months its cut table promised, because that table cut a requirement (RJ-008). This
record states the real number rather than a comfortable one, because AC-017 is right that a
detailed design with no cost attached reliably stalls at 40%, and a *wrong* cost attached stalls
it at 40% while also destroying trust in the plan.

**Three levers exist if that number is unacceptable**, and they should be pulled explicitly
rather than by drift:

1. **Ship M1 as a public v0.9.** It is a real product (§9.2) and it converts 10–15 weeks of
   invisible work into user evidence that would resolve half of §10.
2. **Move M4 (device builder) after M6.** The catalog plus `DeviceOverrides` covers the common
   case; the builder is a completeness barrier, not an adoption barrier (`critique-ux-simplicity.md`
   is right about this). It defers a requirement, so it needs an explicit decision, see §10.4.
3. **Cut the catalog to 40 archetypes at full fidelity** rather than 80. The provenance gate
   (AC-052), not a target number, sets the count; 40 sourced templates beat 80 guessed ones and
   this record has already ruled that lower *fidelity* is not the lever (RJ-007).

---

## 10. Open questions

**Nothing in this section is open. See §13 for the index.** Ten of the thirteen are **ANSWERED and
binding**, 10.3 is **moot** under DR-006, 10.13 is **retired**, and 10.11 alone is **deferred**,
with a trigger that fires before the M6-J5 recruiting ask. Everything in Parts 1–2 and §§7–9 is
binding; these entries were deliberately the opposite, the calls requiring a human judgement about
what this product is for and who is going to use it, which no amount of internal consistency can
supply. That judgement has now been given. Every entry is **retained in full as the record of the
argument**, each marked where it stands.

> **Do not read an entry's body as an open question.** Where an entry carries an `ANSWERED` block,
> that block governs and the options, trade-off and recommendation beneath it are history. A
> recommendation that the answer overruled says so in its own text.

Each entry states the options, the honest trade-off, **what evidence would tip it**, and a
**recommendation**: clearly labelled as a recommendation and carrying no normative weight. A
recommendation here can be overruled without an amendment to this record; a ruling in Part 1
cannot.

They are ordered by blast radius. The first one is a fork in what the product fundamentally is
and everything below it is downstream of the answer.

---

### 10.1 ⚠ **Draw every wire, or net labels by default**: the fork

**This is the most consequential open question in the project and it is not a rendering
preference. It decides what RackMate is.**

**The two products.**

- **(A) Draw every wire.** The schematic is a *drawing*. Every physical link is a visible
  orthogonal polyline from pin to pin, with junction dots, hop arcs at crossings, arrowheads,
  and tag pills at both ends. This is the KiCad/AutoCAD idiom, it is what "takes visual
  inspiration from electronics schematics" most literally means, and it is what a client
  expects to see when they are handed a drawing they are paying for.
- **(B) Net labels by default.** Every link is a short stub off its pin carrying a generated
  label (`HDMI_MTX1_OUT3`), and lines are drawn only when the user filters to a domain, hovers,
  or focuses. This is the Altium/Q-SYS idiom for dense designs, it is the only thing that stays
  legible past ~80 connections, and it is how large electrical schematics have been drafted for
  forty years.

**The honest trade-off.**

| | **(A) Draw every wire** | **(B) Net labels default** |
|---|---|---|
| Legibility at 20 connections | Excellent; this is what people picture | Sparse; reads as an unfinished drawing |
| Legibility at 150 connections | Unusable without filtering; the density arithmetic in `critique-ux-simplicity.md` is correct and unarguable | Still readable; the label *is* the information |
| "Looks like a schematic" to a client | Yes, unambiguously | To an electrical engineer yes; to a homeowner it looks like a parts list with brackets |
| Router cost | Full channel routing, track ordering, crossing sweep, hop arcs, the expensive half of M2 | Layering only; routing becomes nearly free |
| Failure mode | Silent (the drawing degrades gradually into spaghetti and the user does not know when it stopped being useful | Loud) the user immediately asks "where are the lines?" and learns the filter |
| Reversibility | Adding label mode later is cheap | Adding full routing later is the expensive part of M2, deferred |

**Why it is genuinely a fork and not a default.** It propagates into: whether M2 is `L` or `M`;
whether multi-sheet is ever needed (under (B) one sheet holds a whole house, and CR-073's
deferral becomes permanent); whether hop arcs, junction staggering, dash-phase divergence
(AC-016 #17) and the Bentley–Ottmann sweep (AC-016 #20) are built at all; whether the crossing
count X matters; and what the PDF diagram sheet *is*. Under (B), roughly 4–6 weeks leave the
critical path and three of the hardest correctness problems in the corpus disappear. Under (A),
the product looks like the thing the brief describes on first sight, which is worth more than an
engineer's instinct usually credits.

**What tips it.** Put both in front of five integrators, as **printed paper**, not on screen,
a 40-connection theatre rack and a 140-connection whole-house system, one sheet each, in both
idioms. Ask one question: *"which of these would you hand to your lead installer, and which
would you hand to the homeowner?"* If the answer differs by audience, that itself is the answer:
ship both as a per-sheet render mode and let the export dialog pick. Second signal: how many of
the five reach for the paper and start tracing a line with a finger. People do that with (A) and
cannot do it with (B), and it tells you what the drawing is actually *for*.

**Recommendation (not a ruling).** Ship **(A) draw every wire as the default, with (B) as an
automatic degradation above a per-sheet threshold**, which is what `design-ux-schematic.md §1.5`
already designed and what AC-040 keeps. Rationale: the requirement says the wiring planner takes
visual inspiration from electronics schematics, first impressions are made at 20 connections not
150, and the degradation rule means the product never faces the density cliff. The cost is that
the router is built in M2 rather than deferred, which is precisely the 4–6 weeks at stake. If the
paper test comes back with (B) preferred by three of five, take (B) and reclaim the weeks, that
result would be strong evidence and this recommendation is not worth defending against it.

---

### 10.2 Residential CI or commercial AV: who is the primary customer

**Options.** (a) Residential custom integration, primary. (b) Commercial / conference-room AV,
primary. (c) Both, explicitly, with a mode switch.

**Trade-off.** The corpus is written for (a) (Structure devices, home runs, rooms, TIA-570-D,
credenza racks) while several of its most expensive features are (b) features: NCS sheet
numbering, layers for phased retrofit, TIA-606 rack labels, plenum and Class 2/3 code rules,
issued-for-construction stamps. (c) sounds free and is not: it doubles the vocabulary the user
must navigate, and `critique-domain-realism.md m23` is right that TIA-570-D grades are a
vocabulary residential integrators do not speak. Every "default off for wall racks" and "simple
sheet numbering" ruling in Part 1 is quietly a bet on (a).

**What tips it.** Where the first ten paying users come from. Also: whether the drawings ever go
to a permit office or a GC, if they do, (b)'s drafting apparatus stops being overhead and starts
being the reason the tool is bought.

**Recommendation (not a ruling).** **(a) residential-primary, commercial-capable**, which is what
Part 1 already implicitly assumes, so this is mostly a request to make it explicit and stop paying
for (b) features by accident. Commercial capability stays present (the code rules, the ISO/NCS
option, the field-device set) but never fronts the UI.

---

### 10.3 Free-form pricing and licensing model

**Options.** (a) One-time perpetual licence per seat. (b) Annual subscription. (c) Free tier with
watermarked PDF, paid to remove the watermark. (d) Free entirely for now, monetise later.

**Trade-off.** Integrators buy tools the way they buy tools, a purchase order, once, and they
resent subscriptions for desktop software that does not sync anything. But (a) makes the v1.1 and
v1.2 work in §7.3–7.4 unfunded, and the catalog needs continuous authoring. (c) is the classic
answer for a document-producing tool and it aligns exactly with G1: the thing people pay for is
the artifact. It also has a specific hazard here, a watermarked pull sheet is worse than useless
in an attic, so the watermark must go on the *client-facing* sheets and not on the field sheets,
which is a product decision disguised as a pricing one.

**What tips it.** Ask five integrators what they pay for D-Tools, Visio, or their CAD seat, and
whether it was a subscription. Also whether they expense software personally or through the
company, the answer changes the acceptable price by an order of magnitude.

**Recommendation (not a ruling).** **(c)**, with the watermark on elevations and diagram sheets
only, never on the pull sheet or termination schedule. It gets the tool into hands, it prices the
deliverable rather than the software, and it does not require any of the licence-enforcement
machinery that (a) and (b) do. This also affects M8's scope, so it wants deciding before M6.

> **Moot — see §13 and §11.6, consequence 12.** DR-006 rules that no commercial release is planned, so there is nothing to price. This section is retained in full as the record of the argument: if DR-006 is ever reversed, §10.3 reopens exactly as written, watermark hazard included.

---

### 10.4 Does the device builder have to be in v1

**Options.** (a) Yes, M4 stays where it is (the current plan). (b) Move it after M6 and ship v1
with the catalog plus `DeviceOverrides` only. (c) Ship a reduced builder, duplicate-and-edit an
existing template, no from-scratch authoring.

**Trade-off.** The brief fixed "device builder PLUS a seeded catalog" as a confirmed product
decision, so (b) and (c) are deviations from the brief and need the user's explicit sign-off;
that is why this is a question and not a ruling. Against that: `critique-ux-simplicity.md`'s
observation is sharp and probably correct, for a 16×16 matrix the right answer is "duplicate
catalog entry V03 and rename it, 15 seconds", so the builder is a barrier to **completeness**, not
to **adoption**. It buys 4–7 weeks off the critical path at the cost of the long tail, and the
long tail is exactly where a professional discovers the tool cannot represent their job.

**What tips it.** Instrument M1: ship the catalog and count how often users hit a device that is
not in it. If the miss rate is under ~10% of placements, (c) is enough for v1. If it is over 25%,
the builder is load-bearing and (a) is right. This is the single most decidable question in this
section and M1 decides it for free.

**Recommendation (not a ruling).** **(a) keep it in v1**, because it is a confirmed decision and
because AC-049's three-required-fields reduction already removed most of what made it expensive.
But treat M1's miss-rate instrumentation as the trigger to reopen this, and if the number comes
back low, take (c) and reclaim the weeks with the deviation written down.

---

### 10.5 Metric or imperial as the shipped default

> **ANSWERED 2026-08-03 — imperial default, with one obvious toggle. Confirms the recommendation
> below.** `ProjectSettings.displayUnits` already defaults to `UnitSystem.imperial` and four
> surfaces read it as authoritative. **The toggle does not exist**: nothing in the tree writes
> `displayUnits` except the constructor default and the decoder, so the setting is currently
> unreachable by a user. That is owed work — board #562 — and it is the whole of what this answer
> costs.

**Options.** (a) Imperial default, metric available. (b) Locale-derived default. (c) Ask on first
run.

**Trade-off.** RU is imperial by definition and the North American residential market thinks in
feet, inches and AWG; the rest of the world does not, and half the equipment depth specs are
published in millimetres regardless. (b) is the obvious engineering answer and it is subtly wrong
for this domain: a Canadian integrator's OS locale says metric and their cable footage is in feet.
Note this is display only, CR-001 makes storage exact in either system, and
`design-architecture.md §12.2` correctly makes units a separate axis from locale, so this decision
is cheap to change and cheap to get wrong.

**What tips it.** Where the first users are. If North America, (a) with no further thought.

**Recommendation (not a ruling).** **(a) imperial default, one obvious toggle, and mixed units
permitted per-field on input** (typing `450mm` in a depth field set to inches just works). Because
the cost of being wrong is one settings row, this should not consume any more attention than it
already has.

---

### 10.6 Is the schematic a client deliverable or an internal tool

**Options.** (a) Client deliverable, invest in drafting polish, title blocks, revision clouds,
issued-for-construction stamps. (b) Internal working document, the client gets the elevation and
the equipment list; the schematic is how the integrator thinks and how the installer troubleshoots.

**Trade-off.** This decides how much of the drafting apparatus in `design-pdf-export.md` is worth
its cost, and it interacts with 10.1, under (b), the net-label idiom is clearly fine because the
audience is technical, and the fork mostly resolves itself. Under (a), the drawing has to survive
being looked at by someone who has never read a schematic, which is a much harder bar and argues
for (A) in 10.1 plus real drafting furniture.

**What tips it.** Ask integrators whether they currently give clients a signal-flow drawing at all.
Many do not, the client gets a proposal, an elevation, and an invoice. If none of the five does,
(b) is the answer and a meaningful amount of M6 gets simpler.

**Recommendation (not a ruling).** **(b) internal-first**, with the title block and revision block
present (they are cheap and they make the document self-describing) but no further investment in
drafting ceremony until a user asks. This record's G1 principle already points here: the schedule
is the deliverable, the drawing is the receipt, and a receipt is for the person who did the work.

---

### 10.7 Multi-sheet timing

**Options.** (a) v1.2 as ruled in §7.4. (b) Pull into v1. (c) Never, one sheet plus domain
filtering, permanently.

**Trade-off.** CR-073 already defers it and AC-037 already keeps the `Sheet` entity so the format
never migrates, so this question is only about timing, not about architecture. The reason it is
still open: if 10.1 resolves to (A) draw-every-wire, a 140-connection whole-house job does not fit
one sheet, and multi-sheet stops being a v1.2 nicety and becomes the thing that makes the diagram
usable at real scale. If it resolves to (B), (c) becomes genuinely plausible forever.

**What tips it.** The same paper test as 10.1, plus the distribution of connection counts in the
first twenty real projects. If the median is under 60, (a) or (c). If the median is over 120, (b).

**Recommendation (not a ruling).** **(a) hold at v1.2**, and re-decide immediately after 10.1
resolves, these two questions should be answered in the same sitting, from the same evidence.

---

### 10.8 How much to invest now in the cloud-ready model

> **ANSWERED 2026-08-03: (a). Keep exactly what Part 1 rules and spend nothing further.** RackMate
> is a local application. This confirms the recommendation and answers its *what tips it* clause
> directly: nobody has asked for two people in one project, and the product is not being built for
> it.
>
> **1. The six cloud-ready properties are retained in full.** This is the clause most likely to be
> misread later, so it is stated first. *Local only* describes what the application does; it is not
> permission to strip the model. Flat entity maps, `FracIndex` ordering (CR-027), `EntityMeta` on
> conflict units (CR-095), UUIDv7 entity ids with deterministic UUIDv5 for template-derived ports,
> tombstones (CR-095) and `sequence` as the monotonic cursor (CR-094) all stand exactly as ruled.
> **Option (c), drop the constraint and simplify, was never available and is not taken now.**
> Tombstones especially: docs/02 §8 names them as the one property that genuinely cannot be
> retrofitted, and a local-only product is not a reason to spend that.
>
> **2. `docs/02-data-model.md` §8 is ratified as the conflict-unit and merge-story page.** The
> recommendation asked for one page recording AC-006's device-plus-ports assumption rather than
> leaving it folkloric. That page was written before the question was answered: §8 carries the six
> properties, the per-entity conflict-unit table, the structurally-cannot-conflict set and the
> sync-hostile constructs list. It is **ratified, not commissioned**, and it is the canonical
> statement. Its closing sentence deferred to this question and is replaced by this answer. Note
> the precedence consequence: §8 is a priority-3 derived document, so what binds is this ruling,
> and §8 is the place the reasoning is written down.
>
> **3. Two network uses are contemplated, and neither is v1 scope.** The user names an update check
> and outbound publishing to project-management services that expose an API key. Both are outbound
> or advisory, neither is document sync, and neither touches the conflict model. They are recorded
> so a later reader does not read this answer as *no network, ever*, and they are **not scheduled**:
> adding either is a scope addition under §8.3 and needs its own ruling id.
>
> **What would reopen this.** A user asking twice for two people in one project, which is the
> original recommendation's own trigger. Nothing else.

**Options.** (a) Keep exactly what Part 1 rules (stable UUIDs, `schemaVersion`, no positional
identity, tombstones, `sequence`) and spend nothing further. (b) Add the sync cursor plumbing,
per-entity LWW, and a conflict-resolution design now while the model is small. (c) Drop the
cloud-ready constraint and simplify.

**Trade-off.** (c) is not available; it is confirmed decision 3. (a) is what §7 rules. (b) is
tempting for the usual reason (the model will never again be this small) and dangerous for the
usual one: sync semantics designed without a real multi-user use case are almost always wrong, and
wrong sync semantics in a shipped format are worse than no sync semantics. Note that AC-006 already
removed per-port `EntityMeta` on the grounds that the sync design declares device+ports a single
conflict unit, so some conflict-model thinking is already baked in and should be written down
rather than left implicit.

**What tips it.** Whether anyone asks for two people in one project. In this domain that is
usually a designer and a project manager, and the honest answer is often "they take turns".

**Recommendation (not a ruling).** **(a)**, plus one page in `docs/` stating the intended conflict
unit and merge story so that AC-006's assumption is recorded rather than folkloric. Spend nothing
else until a user asks twice.

---

### 10.9 Generic archetypes forever, or a real-SKU catalog eventually

> **ANSWERED 2026-08-03 — the SHIPPED catalog stays generic archetypes; the USER's own templates may
> carry real SKUs.** Two clauses, and the second is the one that matters commercially.
>
> **1. Archetypes must be editable, not a wall.** A user who meets a device differing from a seeded
> archetype by a few ports must edit the archetype, never re-author it from scratch. This is already
> the specified behaviour and needs building rather than deciding: docs/06 §7.3's `Duplicate & edit`
> is *"the intended path for building on the archetypes"*, and seeded templates are read-only such
> that editing one **silently duplicates first** with a one-line notice. M4 owes the surface.
>
> **2. A user-authored template may state a real manufacturer and model, and that is what makes the
> equipment list accurate.** AC-052's provenance gate and DR-002's generic-archetypes rule bind the
> **SEEDED** catalog — they are about what *this project* ships and can cite. They do not reach a
> template a user authored about hardware they are actually installing, where the SKU is a fact the
> user holds and the project does not.
>
> **The sharing mechanism is already ruled and needs nothing further: DR-015's `.rmda`.** A curated
> SKU library is a device archive, authored by whoever owns the SKUs and shared as a file.
>
> **One boundary to keep, because the word invites the fields:** an accurate manufacturer and model
> make `T6.30` a correct *equipment list*, not a BOM. `Money`, `cost`, `supplier` and
> `purchaseOrder` remain deleted from v1 (AC-055), and the sheet is still never called a BOM.
> Reversing that is a separate decision this one does not make.

**Options.** (a) Generic archetypes only, permanently. (b) Generic archetypes in v1, a real-SKU
library later. (c) A community-contributed library.

**Trade-off.** Confirmed decision 2 fixes (a) for v1, so this is a v2 question, but it is worth
answering early because it changes what `.rmdev` and the template library are *for*. Real SKUs are
the single most-requested feature in every tool of this kind and also the single largest ongoing
cost: hundreds of manufacturers, constant model churn, and a real legal question about republishing
manufacturer specifications and trademarks. (c) shifts the cost and creates a moderation and data-
quality problem, plus a provenance problem that directly contradicts AC-052's citation gate.

**What tips it.** Whether users start emailing each other `.rmdev` files unprompted. If they do,
(c) is already happening and the only question is whether it is supported or ignored. Also: what
D-Tools' library is actually worth to the people who pay for it.

**Recommendation (not a ruling).** **(b), with (c) as the mechanism**: a curated community library
where every submission carries the same `sources.md` citation the shipped catalog requires. It
turns AC-052's gate from a cost into the quality bar that makes a community library trustworthy,
which is the thing every community parts library fails at.

---

### 10.10 macOS in v1

**Options.** (a) Windows only for v1. (b) Windows and macOS from v1.

**Trade-off.** The environment is Windows and the corpus assumes it, and the platform-specific work
is real but bounded: notarisation and stapling, file-dialog and menu differences, keyboard idiom
(`Cmd` vs `Ctrl` across ~40 bindings), font availability, and a second print test matrix. Call it
3–5 weeks plus ongoing CI. Against that, a visible slice of high-end residential AV design work
happens on Macs, and a tool that cannot open there is simply invisible to those people.

**What tips it.** Ask the five integrators what is on their design desk. This is a five-minute
question with a decisive answer, and it should be asked before M7 rather than after.

**Recommendation (not a ruling).** **(a) Windows only for v1**, with the discipline that nothing in
M0–M6 may take a Windows-only dependency without it being written down as a macOS debt item. Add
macOS as the first post-v1 milestone if the desk survey warrants it.

---

### 10.11 What the beta gate actually is

**Options.** (a) M9's stated criterion, three integrators each produce a sheet set they were
willing to send out, without leaving the app. (b) A metric: N projects, N cables, zero P1 bugs for
N weeks. (c) A date.

**Trade-off.** (a) is a judgement and therefore gameable and unschedulable, which is exactly the
objection to it, and it is still the right one, because every metric available at this stage
measures the tool's internal consistency rather than its usefulness. (c) ships something on a day
regardless of whether it works. (b) is the compromise and it tends to measure whichever thing was
easiest to count.

**What tips it.** Whether there is external pressure, an investor, a launch date, a paying
customer waiting. If there is, (b) or (c) is going to happen whether or not it is chosen.

**Recommendation (not a ruling).** **(a), with (b) as a floor**: the judgement gate governs, and
the metric exists only to prevent shipping something that passes the judgement gate for three
friendly users and falls over on the fourth.

---

### 10.12 Small calls that need an owner, not an essay

These do not warrant the full treatment but each needs a human answer before the milestone that
touches it. Recommendations only.

| # | Question | Recommendation | Needed by |
|---|---|---|---|
| a | Undo depth: the cap is 200 with a status-bar signal (AC-058 D5). Is 200 right? | **ANSWERED 2026-08-03: keep 200, and make it a setting.** Confirms the recommendation. The cap is already 200 (`undo_stack.dart`'s `maxEntries`) but is a **constructor parameter, not a user setting**: exposing it is owed work, board #560 | M0 |
| b | Autosave interval and whether recovery is silent or prompted | **ANSWERED 2026-08-03, and it revises the recommendation: autosave runs while the user is WORKING, never while they are idle.** The 30 s interval stands; what changes is that a tick with nothing new to protect must write nothing. **This exposed a live defect**: suppression carried a 2 s expiry, so a document left dirty and idle rewrote an identical ~600 KB snapshot every 30 s indefinitely (the dirty check cannot catch it: a recovery snapshot is not a save, so the document stays dirty against disk forever). Suppression now keys on `stateId` alone. **The prompt-on-recovery half is UNCHANGED and still stands**: a silent restore of a file the user thought they had abandoned is its own data-loss event | M1 |
| c | Default rack height in the new-rack dialog | **ANSWERED 2026-08-03, and it supersedes the recommendation rather than confirming it: the starting racks become EDITABLE PRESETS the user tailors to their own inventory.** 42U remains the shipped default, so the recommendation's substance survives as a seed value; what changes is that the preset set stops being fixed. This is a **scope addition under §8.3** and is ruled as **DR-016**. `rack_presets.dart` already anticipates it in so many words, *"a future editable-presets UI has the same shape to hang off"*, and presets are deliberately **not persisted on `Rack`** (no `presetRef`), so a user-authored preset store is a new writable location and not a document-format change. Board #561 | M1 |
| d | Whether the four starter projects are residential-only | Three residential, one small commercial: they double as the domain-coverage argument for 10.2 | M1 |
| e | Telemetry at all, and if so opt-in or opt-out | **ANSWERED 2026-08-03: opt-in, local crash log only. Telemetry is POST-v1.** Confirms the recommendation. Accepted consequence: 10.4's miss-rate instrumentation is a manual user-interview exercise, not a dashboard | M8 |
| f | Product name and branding investment | **ANSWERED 2026-08-03, and it OVERRULES the recommendation to defer.** The name is **RackMate**, settled. Branding is a Protogen mascot, **Riley the RackMate**: neutral warm white with greys, so the mascot never competes with the eight signal-domain hues. Three surfaces follow, and **they are scope, not styling**: an opt-in Clippy-style in-app assistant; a first-run onboarding flow; and user-customisable UI accent colours. RJ-017 rejected branding as a v1 *requirement* and is not reversed, this schedules the work, and where it lands is a sequencing call. Board #563, #564, #565 | M8 |
| g | Whether `docs/rules.md` is user-visible documentation or internal | **ANSWERED 2026-08-03: user-visible, in-app, linked from every finding.** Confirms the recommendation. **Note the file deliberately does not exist**: canon §5 IS the catalogue and CR-021 says so, so this is *publish that section*, not *write a new file*. And it is **27** rules, not the 22 this row inherited from AC-040's arithmetic slip. Feeds M5-F3's `[Why?]` viewer | M5 |

---

### 10.13 The three that should be answered first

> **Retired — see §13.** All three questions this section prioritises (10.1, 10.2, 10.4) are answered by DR-001, DR-002 and DR-003. Do not sequence work from this section.

If only three of the above get attention before M1 starts:

1. **§10.1: draw every wire or net labels.** It sizes M2, decides §10.7, and it is the only one
   whose answer changes the product's identity.
2. **§10.2: residential or commercial primary.** Part 1 already bet on residential in a dozen
   defaults; confirming or reversing that bet now is cheap and reversing it later is not.
3. **§10.4: is the device builder in v1.** It is worth 4–7 weeks, it deviates from a confirmed
   decision either way, and M1 can be instrumented to answer it for free.

Everything else in §10 can wait until there is evidence, which is the entire point of shipping M1
as a real release rather than as a foundation.

---
---

# RackMate: Canonical Decision Record, Part 4. Amendments

**Status:** NORMATIVE. Amends Parts 1, 2 and 3.
**Authority:** these are the **user's own decisions**, given directly. Five of them (DR-001…DR-005)
are answers to §10; §10 said a recommendation there "can be overruled without an amendment to this
record", and the user overruled two of them, so this Part exists to write the overruling down
rather than to leave the record disagreeing with the product. **The sixth (DR-006) does not answer
a §10 question at all**: it is a user decision about what this product *is* and how it reaches its
users, and it supersedes a Part 2 acceptance criterion directly. Part 4 is therefore the home of
every binding user decision, not only of the §10 answers.

**Precedence, stated once and applying to every document in the repository:**

1. **Part 4 (this Part)**: the user's decisions and everything derived from them.
2. **Parts 1–3**: `CR-nnn` / `AC-nnn` / `RJ-nnn`, canonical naming, the model, the registry,
   the scope ruling, the milestone plan.
3. The authored planning documents in `docs/`, **`docs/00` through `docs/14`**. Fourteen when this
   Part was written; `docs/12-milestone-board.md`, `docs/13-macos-debt-register.md` and
   `docs/14-deployment.md` have been added since, and the range is written as a range so the next
   addition does not make this sentence wrong. `docs/12` is a **status** document, not a scope
   document: it records what has been demonstrated and what has not, and it changes nothing.
4. `docs/research/`, non-normative rationale.

Where Part 4 and Parts 1–3 disagree, **Part 4 wins and Parts 1–3 are historical**. Parts 1–3
are deliberately **not rewritten**: a superseded ruling with its supersession recorded is more
useful than a silently edited one, because the argument that produced it is still the argument
you need if the decision is ever revisited. §12 is the index of every such supersession. If a
ruling is not listed in §12, it stands exactly as written.

The decisions are numbered `DR-nnn` (**D**ecided by the user, **R**uling) and are cited by that id
everywhere, in the same way `CR-nnn` is. **There are seventeen, `DR-001` through `DR-017`.** All
but one have their own §11 subsection; `DR-016` alone is ruled inside §10.12(c), because that is
where the scope addition it makes was argued. **`DR-017` is the first that is about process rather
than product**, and it exists because §8.2 requires a citable id and a board item had none. *(This sentence read "the seven decisions are numbered DR-001 …
DR-007" until 2026-08-03, and had been wrong since DR-008. A count in a preamble is exactly the
kind of sentence nobody re-reads, so it is now written as a range that has to be maintained
alongside the section list rather than as a word.)*

---

## 11. User decisions (binding)

### 11.0 How to read these

Each entry states **what it settles**, **what it supersedes**, and its **derived consequences**,
enumerated concretely enough that an implementer never has to infer one. Where a consequence
removes work, the removal is named as a specific subsystem and given a home (`v1.2`, `v2`, or
`never`) so it cannot drift back across the line under R3 (scope drift). Where a consequence adds
work, it is costed.

Two of these six **reverse the record's own recommendation**. That is not a defect in the record,
§10 exists precisely so that the calls requiring a human judgement about the market are made by
the human and not by internal consistency. The reversals are DR-001 and DR-005. Neither is to be
re-argued in any document; both are to be applied.

**DR-006 is a third shape and is flagged here so it is not mis-filed.** It answers no §10 question;
it supersedes a Part 2 acceptance criterion (AC-058/D10) outright, and it moots §10.3 as a side
effect. Its consequences are enumerated under the same rule as the other five, concretely enough
that an implementer never has to infer one, and its removals are given a named home in exactly the
same way.

---

### 11.1 DR-001 · Net labels by default: the fork, answered

> **RULING — (B) NET LABELS BY DEFAULT.** Every `Link` renders, by default, as a pair of net
> labels: a short stub off each of its two pins carrying the generated net name. Drawn wires are
> available **on demand** — filter to a signal domain, `Alt`-hover, or focus/isolate a selection
> — but a drawn orthogonal polyline is **not** the default rendering of a Link on an unfiltered
> sheet.

**What it settles.** §10.1, the single most consequential open question in the project. It
decides what RackMate's schematic *is*.

**What it supersedes.** §10.1's **recommendation**, which was the opposite, "(A) draw every wire
as the default, with (B) as an automatic degradation above a per-sheet threshold". The
recommendation carried no normative weight and is now void. **This is not to be re-argued in any
document.** Any prose that presents draw-every-wire as the default, or net labels as a
*degradation*, *fallback*, *density mitigation* or *mode the product falls back into*, is
inverted: labels are the base state and wires are the opt-in overlay.

**11.1.1 The render-mode rule, stated normatively.**

Render mode is a **function of the active filter**, not a user setting and not a threshold:

| Scope | Mode | What is drawn |
|---|---|---|
| Unfiltered sheet (all domains) | `netLabels` | Every Link is two labelled stubs, one at each pin. No polyline between them. |
| Filtered to exactly one `SignalDomainId` | `drawn` | Every Link in scope is an orthogonal polyline with a tag pill at each end. |
| `Alt`-hover on a symbol, pin or Link | `drawn`, transient | Only the hovered element's Links, for the duration of the hover. |
| Focus / isolate on a selection | `drawn`, scoped | Only the selection's Links. |

`SheetRenderMode { netLabels, drawn }` is a **derived** value, computed from the active filter
state. It is never persisted, never a `ProjectSettings` field, and never a `Sheet` field, for
exactly CR-115's reason.

**11.1.2 What this does to the exported interconnect sheets.**

The exporter partitions by domain (CR-073), so **every exported interconnect sheet `T6.01…` is a
domain filter by construction and therefore renders `drawn`**. This is not an exception to
DR-001; it is DR-001's own trigger applied at export. The unfiltered all-domains schematic sheet
is not an exported artifact and never was (CR-074 deleted the all-devices overview sheet).

`ExportSpec.wireRender: auto | netLabels | drawn`, **default `auto`** = the table in §11.1.1.
`netLabels` forces label mode on every sheet, which is the right answer for a large commercial
job. `drawn` is honoured up to a per-sheet Link count above which it would be illegible, at which
point the sheet degrades to `netLabels` **and prints a note saying so**: a silent degradation is
the failure mode §10.1 named as (A)'s worst property, and it is not reintroduced through the
export dialog.

**11.1.3 Subsystems that leave v1 scope. This is the exhaustive list.**

| # | Subsystem | New home | Why |
|---|---|---|---|
| 1 | **Interval-graph channel routing** (Sugiyama phase 4) | **v1.2**, gated on evidence | Channel allocation and track ordering exist to keep 150 simultaneous polylines legible. At domain-filtered density (a 150-run house is ~25 runs per domain) a layer-ordered orthogonal trace is sufficient. |
| 2 | **Track ordering / channel assignment** within a routing corridor | v1.2, with #1 | Same argument; it is the same code. |
| 3 | **Bentley–Ottmann crossing sweep** (Sugiyama phase 5, first half) | **never**, unless #1 lands | Its only consumer is hop-arc placement. |
| 4 | **Hop arcs at crossings** (phase 5, second half), and `Hops: arc \| gap \| none` | **never**, unless #1 lands | Crossings render as plain crossovers in v1. |
| 5 | **Junction staggering** | never | A density mitigation for drawn wires that are not drawn. |
| 6 | **Dash-phase divergence handling on arcs** (AC-016 #17) | moot in v1 | There are no arcs. The straight-segment `dashPath` profiling item **survives**: dashes still exist. |
| 7 | **The crossing count `X`** as a budgeted quantity | moot in v1 | Nothing consumes it. |
| 8 | **Auto net-label degradation** and its per-sheet threshold | **deleted, not deferred** | There is nothing to degrade *to*. Labels are the base state. |
| 9 | **Multi-sheet splitting** | never: see DR-004 | §10.1 predicted this: "under (B) one sheet holds a whole house, and CR-073's deferral becomes permanent". It did. |

**What explicitly does NOT leave v1 scope**, because it will otherwise be cut by association:

- Sugiyama **phases 0–3**: cycle-break, layering, barycentre crossing-reduction, coordinate
  assignment. These place the **symbols**, and symbol placement is required in both idioms.
  "Layering/ordering only" means these four phases and nothing after them.
- The **deterministic per-link orthogonal trace** used in `drawn` mode: a layer-ordered staircase
  with a fixed bend budget, no channel allocation. Deterministic, same input ⇒ byte-identical
  display list. This is the whole v1 router.
- **Every gesture**: drag-to-connect, click-click sticky, magnetic type-weighted snap, chain-draw,
  multi-draw, `atomicConnect`, re-terminating by dragging an endpoint handle, `Tidy sheet`.
  DR-001 changes how a Link is *rendered*, not how it is *made*.
- **The whole palette**: hue by domain, dash + weight + glyph + tag by family. It applies to
  drawn wires, to the tag pill, to the net-label stub's leader, to the legend `T0.01`, and to the
  `TYPE` chip in the schedule. Requirement 4 is unaffected by DR-001 and its acceptance test is
  unchanged.
- **`SheetItem.position` / `pinned`** and manual symbol placement (CR-068, CR-069).
- **The domain filter bar**, which is now load-bearing rather than a mitigation: it is the primary
  affordance for seeing wires at all.

**11.1.4 Rulings whose reasoning is superseded.** Recorded in §12.1. In summary: **CR-013**'s
router type is superseded to the extent it assumed a draw-every-wire default; **AC-016 #17 and
#20** are moot in v1; **AC-040**'s density-table half is inverted; **CR-012**, **RJ-001** and
**RJ-002** are *unaffected* and are listed there so nobody assumes otherwise.

**11.1.5 M2 is re-sized.**

M2 was `L` (8–12 weeks) and carried the expensive half of the router. §10.1's own estimate, 
"roughly 4–6 weeks leave the critical path and three of the hardest correctness problems in the
corpus disappear", is adopted.

**M2 becomes `M` (4–7 weeks).** The consequences for the plan:

- **M1 is now the only `L` milestone**, and the critical path's centre of gravity moves from M2
  (wiring) to M1 (elevation, catalog, the drawing IR and the parity test). The walking skeleton
  and the M0→M1 sequencing constraints are unchanged.
- The three hardest correctness problems in the corpus, channel-colouring stability, crossing
  sweep determinism, and dash phase across arcs, are no longer on the critical path.
- **Risk R2 does not disappear; it changes shape.** It was "the wire-layer rebuild is 10–25 ms,
  not 4". It becomes **text-bound**: two net labels per Link is ~300 additional text runs on a
  150-run project, on top of the ~10,000 the label cache was already sized for (AC-009). The
  mitigation is the same cache, the same `(text, styleId, quantisedScale)` key and the same LOD
  gate, but it is now the *primary* commit-budget term rather than a secondary one, and the perf
  harness must measure the **label layer**, not the wire layer.
- Net labels make the **generated net name** load-bearing on screen, which raises the stakes on
  CR-049 (names are generated, editable, and never carry membership, membership is
  `Service.netId`). The name is now the primary visual identity of a connection, so its generation
  rule is a legibility decision, not a cosmetic one.

---

### 11.2 DR-002 · Residential CI primary, commercial capable

> **RULING — (a) RESIDENTIAL CUSTOM INTEGRATION IS THE PRIMARY MARKET AND FRONTS THE UI.**
> Commercial capability — the code rules, the ISO/NCS sheet-numbering option, the field-device
> set, the drafting apparatus — **remains present and never fronts the UI**.

**What it settles.** §10.2. It converts a bet Part 1 made a dozen times implicitly into a stated
constraint that a reviewer can hold a design against.

**What it supersedes.** Nothing. §10.2's recommendation was (a) and the user confirmed it. The
value of this entry is that it stops being *implicit*: every "default off for wall racks", every
"simple sheet numbering", every "does not speak TIA-570-D and does not want to be asked" is now
traceable to a ruling instead of to a habit.

**Derived consequences.**

1. **The primary persona is 00-overview §4.1**, the residential CI designer. §4.2, the commercial
   AV designer, is "supported, never fronted", and that phrase is now normative, not descriptive.
2. **`ProjectSettings.sheetNumbering` default `simple`** (CR-066) is confirmed as a *ruling*
   rather than a default. `ncs` remains fully implemented and is reachable from the commercial
   starter project and from settings; it is never the first-run state.
3. **TIA-570-D grades remain a standards *tag*, never an axis** (CR-108). Reaffirmed against
   AC-034/m23: integrators say "two Cat6 and two RG6 to every TV", not "Grade 2".
4. **`CODE-001` and `CODE-002` stay in v1 and are not "commercial features".** NEC 725.136 and
   800.154 apply to a house. They are among the very few checks that protect a residential user
   from a red-tagged job (AC-027).
5. **The 18 field-device templates stay** (AC-031). Field devices are more residential than
   commercial, not less.
6. **§10.12(d) is settled by implication:** the four starter projects are **three residential and
   one small commercial**. The commercial one exists to keep the commercial path exercised in CI
   and to be the domain-coverage evidence for this decision; it is not a second product.
7. **A "commercial mode" switch is refused.** §10.2 option (c) is rejected on its own stated
   grounds: it doubles the vocabulary the user must navigate. Commercial capability is reached
   through settings and starter projects, never through a mode.

---

### 11.3 DR-003 · The device builder ships in v1

> **RULING — (a) THE DEVICE BUILDER IS IN v1. M4 STAYS WHERE IT IS.**

**What it settles.** §10.4. No change to the existing plan; it is recorded here so it stops being
an open question and so nobody re-derives it as a schedule lever under pressure.

**What it supersedes.** Nothing in Parts 1–3, this confirms confirmed product decision 2 and
§10.4's own recommendation. One item in a *derived* document is withdrawn:

- **09-roadmap §6 lever 2, "Move M4 after M6", is WITHDRAWN.** Its own text said it "defers a
  brief requirement, so it needs an explicit decision, not a slip". DR-003 is that explicit
  decision, made in the negative. The lever list drops from three to two. Levers 1 (ship M1 as a
  public v0.9) and 3 (cut the catalog to 40 archetypes at full fidelity) are unaffected.

**Derived consequences.**

1. **M4 keeps its position and its size** (`M`), between M3 and M5, independent of M2 and M3.
2. **Requirement 2 is met at M4, not at M1.** The catalog half of R2 lands at M1; the builder
   half, which is what requirement 2 actually asks for, lands at M4. See §12.6 and the
   requirement-to-milestone traceability the roadmap now carries.
3. **Measure 7 (catalog miss rate) survives but changes purpose.** It was instrumented to resolve
   §10.4 for free. §10.4 is now answered, so the miss rate is no longer a v1-scope trigger. It is
   retained as **catalog-coverage evidence** feeding §10.9 (real-SKU catalog) and as the input to
   lever 3's sizing. It must not be described as resolving an open question.
4. **AC-049's reduction stands and is the reason this is affordable**: three required fields, 
   name, RU height, designator prefix, then ports, then done. Everything else optional with a
   visible `unknown` state. The port grid was never the barrier and ships in full.
5. **Option (c), the reduced duplicate-and-edit builder, is not a fallback.** If M4 is ever at
   risk, the lever is lever 1 or lever 3, not a partial builder.

---

### 11.4 DR-004 · Multi-sheet splitting is never built

> **RULING — (c) ONE SCHEMATIC `Sheet`, PLUS DOMAIN FILTERING, PERMANENTLY.** Multi-sheet
> authoring is not v1, not v1.1, not v1.2, not v2. It is **never**.

**What it settles.** §10.7. §10.1 said this question would resolve itself once the fork was
answered, and it did: under net labels, one sheet holds a whole house.

**What it supersedes.** §10.7's recommendation ("hold at v1.2") and, more consequentially, the
**v1.2 row in §7.4**. See §12.4.

**11.4.1 Deleted from the plan. Not deferred: deleted.**

| Deleted | Was |
|---|---|
| **Match lines** | v1.2 with multi-sheet |
| **Off-sheet connectors** (paired pentagon flags, the second placement pass, cross-reference resolution) | already not-v1 under CR-073; now never |
| **Sheet-boundary link handling**: any logic that asks which sheet an endpoint is on | v1.2 |
| **PDF tiling logic for the schematic**: `TilingStrategy` as applied to diagram sheets, key plans, min-cut and by-rack partitioning | v1.2 |
| **`Layout → Split to Sheets…`** and every UI surface that creates a second schematic `Sheet` | v1.2 |
| **Unit splitting** (`MTX1:A/:B/:C`, CR-070) | v2, conditional on multi-sheet landing. Its condition can now never be met, so it moves to §7.6. |

`TilingStrategy.geometric` **survives** for its one non-schematic use: a single over-tall rack
elevation that does not fit one page. That is page tiling of one drawing, not sheet partitioning
of a document, and CR-073 already scoped it that way.

**11.4.2 The `Sheet` entity REMAINS in the schema. This is not negotiable.**

**AC-037 stands unchanged.** `Sheet` ships in the model and the file format, holding exactly one
schematic sheet per project, with `number`, `title`, `kind`, `paper`, `orientation`, `scale*`,
`carriesLegend`, `includedRackIds`, `includedDeviceIds`, `domainFilter`, `lifecycleFilter`,
`items`, `order` and `meta`. Deleting the entity to re-add it later is a format migration;
keeping it is one map with one member (G5). **If this decision is ever reversed, the file format
does not change.** No document may describe `Sheet` as vestigial, dead, or a candidate for
removal.

**11.4.3 The distinction every document must preserve.**

These are two different things and the corpus conflates them:

- **Multi-sheet authoring**: the user creates, names and populates more than one schematic
  `Sheet` in the document, and a Link can therefore have its two ends on different sheets.
  **Never built.**
- **Exporter domain partition**: one schematic `Sheet` in the document; the **exporter** emits N
  sheets `T6.01…` by filtering that one sheet's contents by `SignalDomainId`. Devices repeat
  across sheets, identified by `designator`. Zero cross-sheet connections by construction, because
  a cable belongs to exactly one domain. **Ships in v1, unchanged.**

**CR-073's exporter-partition behaviour is UNAFFECTED by DR-004 and remains correct.** Partition
at export is not multi-sheet authoring. Any sentence that treats "N sheets come out of the PDF"
as evidence that multi-sheet exists is wrong and must be reworded.

**11.4.4 What this does not remove.** The **zone grid** stays (CR-073 already kept it; DR-005
reinforces it). The schedule's `REF` column stays. `Sheet.domainFilter` and
`Sheet.lifecycleFilter` stay; they are the filter state DR-001 makes load-bearing.

---

### 11.5 DR-005 · The schematic is a client deliverable: invest in drafting polish

> **RULING — (a) CLIENT DELIVERABLE.** The sheet set is a billable artifact handed to a client, a
> GC and a job site. Full sheet furniture ships: title block, revision block, **revision clouds**,
> issued-for-construction stamps, drawing borders, zone references, and sheet numbering.

**What it settles.** §10.6.

**What it supersedes.** §10.6's **recommendation**, which was (b) internal-first with "no further
investment in drafting ceremony until a user asks". The user asked. See §12.5.

**11.5.1 THE CRITICAL NUANCE: drafting polish is orthogonal to wire idiom.**

**This decision does not reopen DR-001 and must never be read as doing so.**

§10.6's trade-off text argued that (a) "argues for (A) in 10.1". That inference is **explicitly
rejected by the user and by this amendment.** The reasoning it rested on (that a client
deliverable "has to survive being looked at by someone who has never read a schematic") does not
hold here, because **the schematic's reader is technical**: the general contractor, the
electrician, the low-voltage sub, and a technically-literate homeowner. Those readers read net
labels. Net labels are how large electrical schematics have been drafted for forty years, and the
audience that receives this document is the audience that reads them.

The two axes:

| Axis | Decided by | Value |
|---|---|---|
| **Sheet furniture**: borders, title block, revision block, clouds, stamps, zones, numbering, index | **DR-005** | Full. Invest. |
| **Wire idiom**: how a `Link` renders inside the drawing frame | **DR-001** | Net labels by default; drawn on filter/hover/focus. |

Polish the sheet fully. Keep net labels. A beautifully drafted sheet whose connections are net
labels is a normal, professional, forty-year-old idiom, not a compromise.

**11.5.2 Concrete additions to v1.**

1. **Revision clouds move from v1.1 to v1.** They are currently listed as v1.1 on the As-built
   preset. They ship: a cloud primitive on `DiagramCanvas` (an arc-scalloped closed path around a
   bounding region), driven from `RevisionEntry`, with a revision triangle carrying the revision
   letter. Cost ≈ 0.5–1 week in M6.
2. **The drafting apparatus in the export document's sheet-furniture section is confirmed v1 and
   is not available as a schedule lever.** Border, zone band and grid, title block, revision
   block, legend swatches: all v1, all drawn through `DiagramCanvas` (P1/CR-086).
3. **`T0.00 Cover & Drawing Index` is confirmed ON in v1.** A client deliverable has a cover. The
   drawing index is generated after the sheet list resolves so it can never reference a sheet that
   is not in the file.
4. **Zone references are confirmed v1**, which retroactively confirms CR-073's decision to keep
   the zone grid and corrects §7.7 cut #1, which listed "zone grids" as cut (§12.6).
5. **`ISSUED FOR CONSTRUCTION` is unchanged**: gated on zero open errors, and it **never gates
   bytes** (CR-022, G3). DR-005 raises the stamp's value; it does not weaken G3. `blockExportOnErrors`
   remains deleted.
6. **Both sheet-numbering schemes ship**, default `simple` (CR-066), per DR-002.
7. **M6 grows by ~0.5–1 week** and moves to the top of its `M` band.

**11.5.3 What DR-005 does NOT do.**

- It does not add floor plans, riser diagrams, reflected ceiling plans, datasheet appendices,
  `T6.40` Power Schedule or `T6.50` Network/IP Schedule to v1. Those remain out (v1.1 / v2).
- It does not add PDF/UA tagging (RJ-015 stands).
- It does not add branding as a v1 requirement (RJ-017 stands).
- It does not change G1. The schedule is still the deliverable; the drawing is still the receipt.
  DR-005 says the receipt is handed to the client, so it must look like it was drafted by a
  professional, not that the drawing outranks the schedule.
- It **sharpens** the hazard in §10.3(c): if a watermarked free tier ever ships, the watermark
  goes on client-facing sheets only and never on the Pull Sheet or Termination Schedule. A
  watermarked pull sheet is worse than useless in an attic, and DR-005 makes the client-facing set
  larger and more valuable, which makes getting that split right more important, not less.

---

### 11.6 DR-006 · RackMate is an internal tool: self-signed distribution

> **RULING — (a) INTERNAL TOOL. NO COMMERCIAL RELEASE IS PLANNED.** RackMate is distributed inside
> the organisation that builds it. Code signing for that distribution is **self-signed**: a
> code-signing certificate minted with PowerShell `New-SelfSignedCertificate`, applied with
> `Set-AuthenticodeSignature` **and a timestamp server**, with the public `.cer` deployed to
> `LocalMachine\Root` **and** `LocalMachine\TrustedPublisher` on every target machine, ideally by
> Group Policy. **Microsoft Trusted Signing is the named fallback** if external distribution is ever
> required — adoptable at M8, with **no earlier milestone needing to anticipate it**.

**What it settles.** How this product reaches the people who use it. AC-058/D10 called distribution
and code signing "the largest unowned area" in the corpus; it is also the only external dependency
in the plan whose lead time nobody in this project controls.

**DR-006 is the first ruling in this Part that is not an answer to a §10 question.** DR-001…DR-005
are the user's answers to §10.1, §10.2, §10.4, §10.6 and §10.7. This one originates outside §10 and
supersedes a Part 2 acceptance criterion directly. It does moot §10.3 as a side effect, consequence
12 below.

**What it supersedes.** **AC-058 (D10)**, in the half that schedules procurement:

> Windows OV/EV certificate procurement **starts two milestones before release** because
> reputation-building takes weeks

**That lead time is real and it is specific to OV/EV.** It does not attach to either path DR-006
names, so the schedule constraint it produced (and every downstream restatement of it, listed in
§12.9) goes with it. **The other half of D10 survives untouched**: macOS notarisation and stapling
(if §10.10 ever resolves for macOS), vendored pdfium (CR-100), and a release pipeline with symbol
archival are all still M8 deliverables. DR-006 removes a *purchasing lead time*, not the *release
engineering*.

**11.6.1 Why the two-milestone lead time does not survive the ruling.**

Three distinct mechanisms were folded into "two milestones early". DR-006 removes all three:

| Mechanism | Under OV/EV | Under DR-006 |
|---|---|---|
| **Identity verification**: weeks of external, out-of-team correspondence | The reason the lead time exists | Self-signed: none. Trusted Signing: an identity check exists, but it is a one-time onboarding and it does not gate any milestone before M8 |
| **SmartScreen reputation ramp**: accrues over real download volume | The reason EV was preferred over OV (`RISK-07`'s mitigation column) | Self-signed never accrues reputation and is not distributed over the internet, so it never faces the ramp. Trusted Signing chains to Microsoft-operated roots and does not need one |
| **Hardware token shipping** | Since the CA/Browser Forum's code-signing Baseline Requirements took effect on **1 June 2023**, **OV** private keys must live on a FIPS 140-2 Level 2 / CC EAL4+ hardware module, exactly as **EV** always did. A physical token is couriered, or a cloud HSM is provisioned | Neither path involves a shipped token |

**11.6.2 M8's exit criterion, split.**

M8's criterion currently reads *"A signed installer runs on a clean Windows 11 machine **with no
SmartScreen warning**…"*. Self-signing cannot deliver that clause, **and neither can any
build-side property whatsoever**. SmartScreen Application Reputation is evaluated on files carrying
**Mark-of-the-Web**, the `Zone.Identifier` alternate data stream that a browser or other
zone-aware downloader attaches. MOTW is a function of **how a file arrived on the machine**, not of
what is inside it. A clause that mixes a build property and a delivery property cannot be a gate,
because passing it depends on something the build does not do. So it splits.

**BUILD-SIDE: a real gate, demonstrable in CI.** The installer and every binary it carries:

1. are **signed**, `Get-AuthenticodeSignature` returning `Valid`;
2. are **timestamped** against an RFC 3161 timestamp authority;
3. show a **valid publisher** in the file's Properties ▸ Digital Signatures tab, matching the
   declared subject;
4. **and the signature still validates after the signing certificate has expired.**

Clause 4 is the point of the whole gate. It is what proves the timestamp counter-signature is real
rather than a flag somebody passed and nobody checked, and it is the part people discover too
late, the day the certificate lapses, every previously shipped binary starts reporting
`NotTimeValid` and there is no way to fix already-deployed files. **It is testable today without
waiting a year**: mint a deliberately short-lived certificate (`New-SelfSignedCertificate
-NotAfter (Get-Date).AddMinutes(5)`), sign two copies of the same binary (one with
`-TimestampServer`, one without) wait out the window, and assert `Get-AuthenticodeSignature`
reports `Valid` for the timestamped copy and a time-validity failure for the other. That is a test,
not a hope.

**DISTRIBUTION-SIDE: documented, not a build gate.** Deploy over a **Local Intranet UNC share** or
via **Intune/GPO**, so MOTW is never applied and SmartScreen is never consulted. Deploying the
public `.cer` to `LocalMachine\Root` and `LocalMachine\TrustedPublisher` by Group Policy is part of
the same deployment note: `Root` is what makes the chain validate; `TrustedPublisher` is what makes
the publisher trusted rather than merely known.

> **THE ZIP TRAP — state it explicitly in the deployment note, every time.** Modern Windows
> Explorer **propagates MOTW into extracted files**. A portable ZIP fetched over HTTP therefore
> **re-arms SmartScreen for every binary inside it**, regardless of how well the binaries are
> signed — and it does so silently, because the archive looked fine when it was downloaded. The
> failure is invisible until a user on a fresh machine sees the blue full-screen prompt. A portable
> build handed over HTTP is not the same artifact as the same bytes handed over `\\share\`, and any
> document that offers a ZIP download must say so.

**11.6.3 Derived consequences.**

1. **No certificate purchase.** No CA relationship, no line item, no renewal calendar, no
   procurement task in any milestone.
2. **No hardware token.** See §11.6.1, under the 2023 rules both OV and EV require keys on
   hardware, and DR-006 avoids both.
3. **The signing script is parameterised over certificate source and never hardcodes self-signed.**
   One entry point taking the source as a parameter (self-signed from a named store thumbprint, a
   `.pfx`, or Trusted Signing) with everything downstream (timestamping, hashing, the verification
   step, the artifact list) identical across sources. **This is the only consequence that costs
   anything now, and it is the one that must not be skipped**: it is the difference between the
   named fallback being a config change and being a rewrite.
4. **Every artifact a release produces signs with the same certificate and the same script**: 
   installer and unpacked/portable directory alike. One certificate, one script, N outputs; portable
   and installed are the same signing problem, and consequence 3's parameterisation is what makes
   that cheap. **This schedules no build into any milestone that does not already have one.** A
   "portable build" occurs in exactly one place in the corpus, `docs/03-architecture.md:847`, which
   observes that pinning `path_provider_windows` to a single call site *"keeps M2's portable build a
   one-function change"*. That is an **architecture property**, not a deliverable: neither roadmap
   §4 M2 nor §9.3 above lists any build, packaging or distribution item, and `portable` does not
   occur in `docs/09-roadmap.md` or `docs/11-testing-and-quality.md` at all. **All
   release-engineering deliverables remain at M8.** If a portable output is ever wanted earlier,
   that is a scope edit under roadmap §8.3 and not something this consequence grants.
5. **M6's exit clause "Windows OV/EV certificate procurement starts here" is deleted**, not moved.
   M6's exit criterion is otherwise unchanged.
6. **M8's exit criterion is split** per §11.6.2. Its size (`S`, 2–3 weeks) is unchanged as a
   ruling; in practice it loses the procurement and EULA work and gains the timestamp-expiry test.
7. **`RISK-07` (certificate lead time) is retired in its stated form.** It is replaced by a smaller,
   wholly internal risk: **the public `.cer` is not present in the target machine's stores**, whose
   early warning is a clean test machine showing "Unknown publisher", and whose mitigation is a GPO
   and a five-minute check, not a purchase order.
8. **`RISK-08` (beta integrators) changes population, not shape.** Three integrators become three
   internal users running three real jobs. **M9's exit criterion is unchanged** and is still
   deliberately a judgement, not a metric.
9. **AC-058/D7's licence deliverable shrinks but does not vanish.** SIL OFL 1.1 for the bundled font
   and every other bundled licence must still be registered via `LicenseRegistry` and reachable from
   `showLicensePage`, that obligation follows from **redistributing** the fonts, not from selling
   the software. What goes is the commercial EULA and any licence-enforcement machinery. (Note in
   passing that the shipped font is now Jost, not CR-080's IBM Plex, and that CR-080 carries no
   amendment; that drift is recorded in `docs/12-milestone-board.md` §4.6 and is **not** ruled here.)
10. **RJ-014 is reaffirmed and made cheaper.** No in-app auto-update in v1; a "Check for updates"
    item and a version string. Internally that item can point at the same share the installer came
    from, which is a link, not infrastructure.
11. **macOS notarisation is unaffected.** §10.10 is still open, and if it ever resolves for macOS,
    notarisation and stapling are a separate apparatus that DR-006 says nothing about, Apple's
    Gatekeeper has no self-signed path.
12. **§10.3 (pricing and licensing) is moot while DR-006 stands.** There is nothing to price. §13's
    row and §13.1's row are updated accordingly. **If DR-006 is ever reversed, §10.3 reopens exactly
    as written**, including its specific hazard, a watermark belongs on client-facing sheets only
    and never on the Pull Sheet or Termination Schedule, because a watermarked pull sheet is worse
    than useless in an attic (§11.5.3).
13. **DR-005 is untouched, and must not be read as weakened.** DR-005 rules that **the sheet set** is
    a client deliverable handed to a client, a GC and a job site. DR-006 rules that **the software**
    is not commercially distributed. Those are different artifacts: an internal tool used by an
    integrator still emits sheets that go to a job site. **Full sheet furniture remains a v1
    deliverable and remains unavailable as a schedule lever** (§11.5.2/2). Cutting M6's furniture on
    the authority of DR-006 would be citing a ruling that says nothing about it.

**11.6.4 The measured registry fact, recorded because it bounds a claim.**

RackMate's own code **writes no registry key**. Beside that, and measured against the shipped
binary: **the shell writes values under ComDlg32 that RackMate does not control**, at minimum
`LastVisitedPidlMRU` (this executable plus the last folder browsed) and `CIDSizeMRU` (this
executable, written even when the user cancels the dialog), **measured examples and not an
inventory**, and no supported option prevents them while the shell common dialog is the dialog.
What *is* suppressed, via `FOS_DONTADDTORECENT`, is `OpenSavePidlMRU` and the `%APPDATA%\…\Recent`
shortcut, so **no project file name reaches the host machine** (docs/03 §10.1).

This is recorded in Part 4 because the internal-distribution story rests on it: **any portable
build's no-trace claim is a bound, not a closed list.** Stating it as a closed list has been wrong
four times running, which is why `apps/rackmate/test/session/registry_claim_test.dart` fails if the
architecture document restates it as one. Any deployment note written for §11.6.2's
distribution side **repeats the bound and does not enumerate keys**.

**11.6.5 What DR-006 does not do.**

- It does **not** authorise shipping unsigned. An unsigned internal binary is a worse trust story
  than a self-signed one, and clause 4 of the build-side gate is the only thing that catches an
  expiring-certificate failure before users do.
- It does **not** claim a self-signed binary is trusted on a machine that has not received the
  `.cer`. On such a machine the signature is present, the publisher is unknown, and, if the file
  carries MOTW, SmartScreen behaves exactly as it would for an unsigned file.
- It does **not** cut M7, M9, or any brief requirement. Nothing here touches confirmed product
  decision 4.
- It does **not** settle MSIX versus a plain signed installer. **VERIFY:** the `.rackmate`
  file-association path differs between the two and drives the choice (docs/11 §11 already carries
  this).
- **VERIFY:** Microsoft Trusted Signing eligibility before relying on the fallback being available
  on demand; it requires a verified identity, and organisation accounts have carried a minimum
  legal-existence requirement. The fallback is named so that adopting it is a config change; it is
  not asserted to be instantly available.

### 11.7 DR-007 · Keystone strap geometry ships in M3, not v1.X

> **RULING — THE LOW-VOLTAGE BOX'S INTERNAL GEOMETRY IS v1, BUILT IN M3.** An `Outlet` gains an
> ordered list of **gangs**; each gang holds one **strap**, which is a **2D grid of keystone
> positions**; each cell holds **at most one keystone** — every occupant is 1 × 1, a speaker binding
> post included (§11.7.2, revised 2026-07-28) — or a blank insert. It is
> built in **M3 — Structure and the field**, alongside the `Outlet` UI that milestone already
> schedules, and **not** deferred to v1.X.

**What it settles.** Where the internal geometry of a wall plate is built, and therefore whether
the `Outlet` editor is built once or twice. The question arose because RackMate models field
devices but cannot arrange them into low-voltage boxes for a wiring schedule, and a room-by-room
visual guide of what should be where is the artefact an installer actually works from.

**What it supersedes.** Nothing. **This is an addition to v1 scope**, made under roadmap §8.3
(moving an item between v1, v1.1, v1.2, v2 and not-doing requires a new ruling ID). It **extends**
CR-016 rather than replacing it: `Outlet` remains "ONE WALL PLATE / ONE CEILING LOCATION" and
gains a gang list. Nothing about CR-047's location tree, CR-108's outlet templates, CR-112's
Locations panel or AC-019's membership rule changes.

**Why M3 and not v1.X: the argument that decided it.** M3 is *Structure and the field*; its exit
criterion is a 60-drop whole-house rough-in producing a Pull Sheet sorted by room and pathway, and
boxes **are** those drops' field ends. Three M3 checklist items already build the surface this
geometry lives in: `Outlet`/`structureOrigin`/`PlaceEndpoint`/`OpenEndpoint` in the UI, the
Structure editor with outlet templates and TIA-570-D presets, and the project-level Locations panel.
Deferring the grid means **building the `Outlet` editor twice** (once without it, once with) and
retrofitting a 2D grid into a shipped editor is worse work and a worse first UI than designing it in.

**The cost, stated rather than hidden.** M3's exit criterion does **not** require strap geometry: a
60-drop rough-in schedules and prints correctly without knowing which cell a keystone occupies. This
ruling therefore **grows a milestone that already gates M4 through M9**. M3 stays `M`, at the upper
end of that band. What is added is a model extension, its codec and migration, the strap editor
inside the Structure editor, and plate rendering, not a new subsystem, because the packing problem
is bounded at six cells.

**11.7.1 The geometry, and why five ports do not exist.**

A strap is exactly `W × H` with **W ∈ {1, 2}** and **H ∈ {1, 2, 3}**:

| Ports | Grid |
|---|---|
| 1 | 1 × 1 |
| 2 | 1 × 2 |
| 3 | 1 × 3 |
| 4 | 2 × 2 |
| 6 | 2 × 3 |

**5 is not expressible under those bounds, and that is why five-port straps do not exist.** It is to
be encoded as a **derived constraint** falling out of `W × H`, never as a hardcoded exclusion list,
a list would be a fact about a catalog, and this is a fact about geometry.

**11.7.2 EVERY OCCUPANT IS 1 × 1. There are no multi-cell occupants and no orientation.**

> **SUPERSEDED AND REPLACED 2026-07-28**, on the user's statement: *"We use single post keystones,
> one per conductor."* The original text is preserved at the end of this subsection because a
> ruling that was wrong is worth being able to find.

A cell holds **at most one keystone**, and every keystone is exactly one cell. A speaker drop is not
a two-cell occupant; it is **N single-post keystones**, one per conductor, each an ordinary 1 × 1
occupant that may sit in any free cell. Two posts of a stereo pair need not be adjacent, need not be
in the same column, and need not be in the same order on every plate.

**What this deletes.** Orientation, in its entirety; there is nothing to rotate. The
"forced on 1-wide, free on 2-wide" rule, and the refusal message it required. Packing, which
§11.7.6 called *"trivial because the grid is bounded at six cells"*: with no occupant larger than a
cell there is **no packing problem at all**, only a set of cells each holding zero or one keystone.
The strap becomes the simplest possible container.

**11.7.2.1 How many cells a field end needs: a function of TERMINATION, not of the cable.**

The tempting generalisation from *"one per conductor"* is that cells always equal conductors. **That
is false for the most common drop in the building.** A Cat6 run terminating in one RJ45 jack occupies
**one** cell no matter how its conductors are modelled. The rule is:

| Termination | Cells at that end |
|---|---|
| binding post / single post (speaker) | **one per `Conductor` landing there**: 16/2 → 2 cells, 16/4 → 4 cells |
| modular jack (`keystone`, `fBarrel`, and the HDMI / 3.5 mm modules) | **one per `Link` end** |
| `punchdown` | one per `Link` end |
| `unterminated`, `fieldConnector` | **zero**: nothing is on the plate |

`TerminationType` (`model/enums.dart:20`) already carries exactly this distinction and is the hook
M3 should read; it does not yet name a binding-post case, and adding one is the smallest change that
makes this table computable. `Conductor` already models the other half, `conductor.dart:44`,
*"A 16/4 speaker cable is one `Link` with four `Conductor`s (RJ-016)"*, with `role` already ranging
over `"L+"`, `"L-"`, `"+"`, `"-"`, which are precisely the per-post labels.

**11.7.2.2 The consequence for a 16/4 run, stated because it is the case that bites.**

Four conductors, four binding posts, **four cells**. A 16/4 speaker drop therefore does not fit on a
1-, 2-, or 3-port strap at all; it needs a 4- or 6-port. That is a real constraint on plate
selection and it falls straight out of the table above rather than being a rule anyone has to
remember.

> **THE SUPERSEDED TEXT, verbatim.** *"A speaker terminal occupies **two cells** and is orientable,
> but **orientation is constrained by strap width**: on a 1-wide strap (1 × 2, 1 × 3) it can only be
> vertical, there being no horizontal room; on a 2-wide strap (2 × 2, 2 × 3) either orientation fits.
> On half the shipped straps the orientation is therefore **forced, not chosen**. A refused placement
> must state why — 'no horizontal room on a 1-wide strap' — under the standing rule that a refused
> action always reports and never silently does nothing."* This was written from a description of a
> dual-post module. The photographed part is single-post, and the shop uses single-post. It was
> ruling the expensive side of a fork it did not know it was on.

**11.7.3 The hierarchy: one `Outlet`, N gangs.**

```
Location (room)
  └─ Outlet          = one wall plate / box     [EXISTS — CR-016]
       └─ Gang × N   = one gang opening         [NEW]
            └─ Strap = W × H cell grid          [NEW]
                 └─ keystone | speaker terminal (2 cells) | blank
```

`Outlet` stays the plate and gains an **ordered** gang list. One-`Outlet`-per-gang was considered
and rejected: it would lose the fact that two drops **share a box**, which is exactly the fact a
room-by-room guide exists to show, and it would redefine a shipped ruling rather than extend one.

**11.7.4 Blank inserts are occupants, not absence.**

A six-port strap with four positions used needs **two blanks**, and those are purchasable line items
that belong on the materials sheet. The precedent one scale up is exact: `X01 Blank Panel` is a
catalog template, not a gap in a rack.

**11.7.5 Keystone colour follows the convention, not the cable.**

Consequent on **CR-121**. `Link.jacketColorId`, what the run *is*, drives the keystone;
`Link.jacketColorPulledId`, what was actually pulled, does not. A run mis-pulled in the wrong
colour still gets the keystone its service calls for, because the keystone is fitted weeks later out
of the same box as every other drop of that service, and is routinely correct while the cable is not.
`ResolvedJacketColor.keystoneColorId` already returns `conventionId` and mentions the override
nowhere; that syntactic independence is the design and is mutation-tested.

**11.7.6 A correction, recorded because it shaped an earlier plan.**

An earlier note in this project's task record claimed "a keystone strap is structurally a tiny rack"
and that the rack occupancy machinery (`findLowestFreeRu`, `findBlockingOccupant`, `planCompaction`,
the shrink planner) would make this cheap. **That is wrong.** A rack is one-dimensional: an RU index
plus a coarse lateral twelfth. A strap is a 2D grid, and none of that code applies to a 2D grid.

**Both of that paragraph's other claims have since been overtaken, in the same direction.** It also
called the occupants *"orientable"* and said placement was cheap only because *"the grid is bounded
at six cells, so exhaustive placement is trivial"*. Under §11.7.2 as revised on 2026-07-28 there are
**no orientable occupants and no placement problem whatsoever**: every occupant is 1 × 1, so a cell
is free or taken and there is nothing to search. The conclusion outlived the argument and is now
stronger than it, the rack machinery does not apply, the cost is modelling rather than algorithms,
and the algorithm the hedge was written against turns out not to exist.

**11.7.7 What does not move.**

The **printing** half stays at **M6**. `T5.01 Plate, Panel & Pinout Details` is already in the v1
sheet set (docs/08 §2.2) as `AUTO`, gated on any non-standard pinout existing. Strap geometry gives
that sheet a real second purpose and a reason to be `ON` far more often, but the sheet itself ships
when the full sheet set does.

**11.7.8 The physical reference, and the three things it changes.**

*Added 2026-07-28. The user supplied photographs of the real parts: keystone straps in 1, 2, 3, 4
and 6 port, and Decora cover plates in 1, 2 and 3 gang.*

**What it confirms.** §11.7.1's table is exactly right, part for part, 1, 2, 3, 4, 6, and **no
five-port strap exists in the reference**, which is the prediction `W ∈ {1,2} × H ∈ {1,2,3}` makes.
The 4- and 6-port parts are visibly two columns wide, so §11.7.2's claim that orientation is forced
on 1-wide straps and free on 2-wide ones holds against the physical objects rather than against an
argument. Nothing in §11.7.1–11.7.3 needs changing.

**Change 1: THE COVER PLATE IS A SEPARATE PART, AND A SEPARATE LINE ITEM.** The reference makes
plain what §11.7.3's tree elides: a strap and a Decora plate are two distinct purchasable objects.
The strap screws to the box and carries the keystones; the plate covers it and has its own gang
count. So an `Outlet` with N gangs is **N straps plus exactly ONE N-gang cover plate**, and the
plate's gang count is not free; it is `Outlet.gangs.length`, always. §11.7.4 already rules that
blank inserts are occupants and therefore line items; the cover plate is the same argument one
level up and was simply missed. The materials sheet owes both.

**Change 2: THE CELL GRID IS CENTRED IN THE OPENING, NOT ANCHORED TO AN EDGE.** In the reference,
the 1- and 2-port straps do **not** fill their vertical span: the openings sit as a group with blank
plastic above and below, symmetric about the centre. Only the 3-port fills it. A renderer that lays
cells out from the top edge will draw a 1-port strap with its jack at the top, and that is simply
not what the part looks like. `W × H` is the occupancy model and stays; the **placement** of that
grid inside the plate opening is a separate fact and this is it.

**Change 3: one dimension is NOT settled and must be measured, not inferred.** Whether a cell on a
2-wide strap is the same size as a cell on a 1-wide strap is **not** answerable from the reference.
The 1-wide openings read as proportionally wider than the 2-wide ones, but these are product
photographs at different scales and that appearance is as likely to be an artefact as a fact. The
arithmetic permits a single uniform cell (a standard keystone is about 14.5 × 16.0 mm and a Decora
opening about 33.3 × 66.7 mm, so 2 × 14.5 = 29 mm fits across and 3 × 16.0 = 48 mm fits down) but
*permits* is not *is*. **One caliper measurement of a real 3-port and a real 6-port settles it**, and
it must be taken before any dimensioned rendering, because a uniform-cell assumption that turns out
false is wrong on every plate drawing at once. Recorded as an open measurement rather than resolved
by the most convenient reading (G4).

> **DISCHARGED by DR-038 (§11.37) on 2026-08-10, with a caliper: the cells ARE identical across
> strap widths.** Every cell is DR-028's 14.5 × 16 mm nose on a 1-wide and a 2-wide alike, so the
> arithmetic above was right and *permits* turned out to be *is*. Dimensioned rendering is unblocked
> for the M3 strap editor and for `T5.01` at M6. **Change 2 is untouched**: the grid is still centred
> in the opening rather than anchored to an edge, and the opening's own dimensions are still an
> *"about"*.

> **AND THE OPENING IS NO LONGER AN "ABOUT" EITHER, per DR-041 (§11.40) on 2026-08-11.** Measured at
> **33.34 × 66.68 mm**, confirming this subsection's parenthetical to within 0.04 mm, and with it the
> two cell pitches, **22 mm vertical and 15.95 mm horizontal**, which turn change 2's *"centred in
> the opening"* from a rule into coordinates. Both centrings fall out of the measured numbers rather
> than being imposed on them. This paragraph's arithmetic was right twice: once about the cell, and
> once about the opening the cell sits in.

**11.7.9 The keystone modules themselves: and the one that contradicts §11.7.2.**

*Added 2026-07-28, from the parts in `docs/reference/keystone/`.*

The second batch of reference is the **occupants** rather than the straps: Cat6 couplers in six
colours, an F-type barrel, an HDMI right-angle coupler, a 3.5 mm/IR module, blank inserts, and a
speaker binding post. Four findings, in descending order of how much they change.

**A. THE SPEAKER TERMINAL IS ONE POST PER KEYSTONE, WHICH CONTRADICTS §11.7.2.** The reference
(`6148z2IDmeL...jpg`) shows **two separate single-post modules**, one red-banded, one black-banded
, each occupying ONE cell, not one double-wide module spanning two. If that is the part in use,
then **there is no two-cell occupant, and therefore no orientation to constrain**: a speaker pair is
two ordinary 1×1 keystones that happen to belong together, and they can sit in any two cells,
adjacent or not. §11.7.2's entire "orientation is forced on a 1-wide strap, free on a 2-wide one"
argument would then be modelling a constraint that does not exist.

**ASKED, AND ANSWERED THE SAME DAY.** This entry was first written as an open fork, both parts
exist in the world, the user's earlier description (*"speaker terminals needing two units, which
could be oriented horizontally or vertically depending on the strap being used"*) described the
dual-post module while the photograph showed the single-post one, and the two readings led to very
different models. The user settled it directly: **"We use single post keystones, one per
conductor."**

So the flat model wins. §11.7.2 is rewritten accordingly and the original is preserved there.

| The fork, as it was posed | Outcome |
|---|---|
| every occupant is 1 × 1: a flat grid plus a "these belong together" grouping | **THIS.** Simpler by a wide margin: no orientation, no refusal message, no packing |
| some occupants span 2 cells: multi-cell occupants, orientation, packing | not the part in use; ruled out |

**The lesson is worth more than the answer.** The ruling had already picked the expensive branch,
from a verbal description, without knowing it was on a fork at all, and it would have shipped a
packing-and-orientation subsystem for a problem that does not exist. Nothing in the corpus could
have caught that; only the photograph did. **A physical reference is worth more than a careful
reading of a description**, and DR-007 is now two-for-two on that (see also §11.7.8's cover plate).

**B. THE CELL RENDERS FROM THE FRONT, AND THE FRONT HIDES THE DIFFERENCES.** *(Corrected by the user
on 2026-07-28; the first draft of this entry got it backwards and the error is instructive.)* A
keystone is drawn face-on in a plate elevation, and face-on a punchdown jack and an inline coupler
are **the same object**: a coloured bezel with a connector opening. The renderer therefore needs
`(connector type, colour)` and nothing else, not the termination style, not the part number, not
whether there is a punchdown block or a second socket behind it. That is a real simplification and
it should be taken.

The first draft instead read the Cat6 reference's colour lineup (red, blue, orange, yellow, white,
black) as a **catalog constraint**, noted that green and grey were missing while both are CR-121
conventions, and concluded that keystone colour availability had to be modelled as a per-catalog
fact with an "unavailable in this colour" path on the materials sheet. **That was wrong, and it was
wrong in a specific way worth naming: a stock photograph's colour lineup is what one seller
photographed, not what the world stocks.** The user's position is unchanged and was stated when
CR-121 was written; *"we can get keystones in every color we can get wire"*. §11.7.5 stands
unqualified, no availability modelling is owed, and the six colours in that image carry no meaning
at all.

**C. Modules differ in depth and exit direction, which is a box-fill fact.** The HDMI reference is a
**right-angle** coupler whose cable exits sideways; the F-type is a straight barrel; the speaker post
is a binding post with a pigtail. Cell occupancy says nothing about any of this, and per B the front
elevation will not show it either. Not M3 geometry, but it is the reason a 6-port strap can be
electrically fine and still not close.

**E. Minor, and it strengthens §11.7.8.** The 2-port strap (`images.jpg`) shows the centred grid
plainly, blank plastic above, between and below. The 6-port strap's cells read as portrait, taller
than wide, which is consistent with a uniform standard-keystone cell. That is support for the
uniform-cell hypothesis, **not** a measurement, and §11.7.8's caliper is still owed.

**11.7.10 One question left open for the implementer, deliberately.**

`ProjectSettings.outletFieldLabelFormat` is `{ROOM_ABBR}-{SERVICE}-{SEQ}`. With N gangs, whether the
gang appears in a drop's field label, and whether that needs a new `IdFormat` token, is **not**
settled here. The idformat engine has a grammar, a registry and a parser; a token is not to be
invented silently to satisfy this feature.

---

### 11.8 DR-008 · The three wiring-model questions M2-A could not answer from the corpus

> **RULING — settled by the user on 2026-07-28**, at the point M2-A needed each one and the
> corpus did not contain it. Three unrelated questions, ruled together because they arose
> together and each blocks a specific step of the same task.

**Why a ruling rather than an implementer's choice.** All three change behaviour a document
records, and two of them **narrow rulings already in Parts 1–3**. §8.3's rule is that scope does
not move without an ID.

---

**11.8.1 A jumper is a Link with both ends in the same rack. Nothing else.**

> Supersedes the multi-limb reading of **AC-026**. Length does not enter into it, and neither
> does whether the cable was factory-assembled.

AC-026 gives `fieldCable | jumper | powerCord | internal` as "auto-classified,
user-overridable" and its supporting text gestures at a short run of factory-assembly media.
**Both of those extra limbs are struck.** The rule is: resolve each end to a rack
(`rackOfEndpoint`); if both resolve and are equal, `jumper`.

**Three reasons, and the third is decisive.**

1. **The corpus's own reference jumper fails the factory-assembly limb.** `docs/02-data-model.md`
   shows W002 with `"linkClass": "jumper"` and `"media": "media.cat6"`, bulk box cable. Either
   the reference fixture violates AC-026 or the limb was never a conjunct. It was never a
   conjunct.
2. **Nothing can evaluate the other two limbs.** `MediaTypeDef`'s field list, in the code
   (`registries.dart`) *and* in this document's own §6.5, has no factory-assembly flag; and a
   freshly-drawn link has all three of AC-024's lengths null, so a length test is unevaluable at
   exactly the moment classification is supposed to happen.
3. **Same-rack is the fact the schedule actually wants.** A jumper is excluded from the Pull
   Sheet because *nobody pulls it through a wall*; that is a statement about where its ends are,
   not about its length or its provenance. A 3 m service loop between two devices in one rack is
   still not a pull; a 1 m run between two racks still is.

`powerCord` and `internal` are untouched by this ruling.

---

**11.8.2 A user-set `linkClass` survives a document change that would re-classify it, and the
disagreement is visible.**

The classifier is **advisory**. When a user sets the class by hand, that assertion is stored and
kept; if the document later changes so that the classifier would say something else, **the user's
value stands and the divergence is reportable**.

This needs **two pieces of state, not one**: the same shape, and for the same reason, as
`Link.jacketColorId` / `jacketColorPulledId` under **CR-121**. With a single field there is no
way to distinguish *"the classifier said `jumper`"* from *"a person said `jumper`"*, so moving a
device either silently overwrites a human judgement or is silently ignored, with nothing able to
tell you which happened. The precedent is already on this class: `Link.designatorLocked`.

**The stored flag is `true`-only and absent otherwise**, per CR-117's absent-key-is-not-null
contract, so no existing document's bytes move and `kSchemaVersion` does not change.

---

**11.8.3 `atomicConnect` on mismatched sets connects what fits, leaves the remainder open, and
warns.**

> Answers the sub-question **AC-053 names in its own diagnosis and does not resolve**: what
> happens when a 3-member set is dragged onto a 2-member set.

The gesture does **not** refuse. It creates the `Link`, pairs members in the set's declared
order, and every unpaired member becomes a `Conductor` with an `OpenEndpoint`. The user is
warned that the run is incomplete.

**This is the user's call, made against a recommendation to refuse**, and the reasoning for
taking it is worth recording: in the field a partially-landed run is a real state, and a gesture
that refuses it forces the user to model the truth as a lie or not at all. `OpenEndpoint` exists
precisely to represent "a coil left unterminated".

**The cost is stated rather than discovered.** Validation does not exist until M5, so between now
and then the warning has only the status line to appear on, and a half-connected run **will look
complete on the schedule**. That is a real gap. It is acceptable because it is *derivable, not
lost*: a `Link` carrying a conductor with an `OpenEndpoint` is a fact in the document, so M5's
rule needs no new state and no migration; it reads what M2-A already writes. **M5 owes a rule
for it**, and this paragraph is the record of that debt.

---

### 11.9 DR-009 · macOS ships in v1

> **RULING — settled by the user on 2026-07-28.** §10.10 asked the question and recommended
> against; the user has ruled the other way. Recorded as an amendment with its own ID because
> **§8.3 requires one**: moving anything between v1/v1.1/v1.2/v2 is an amendment, not a doc edit.

**§10.10 offered two options.** (a) Windows only for v1. (b) Windows and macOS from v1. **Option
(b) is taken.** §10.10 is closed, and its status in the open-questions table (`open`, *"ask before
M7"*) is discharged. The question was asked and answered ahead of M7 rather than after it, which
is what that line wanted.

**The recommendation this overturns was explicitly not a ruling**, and its own reasoning is why
overturning it is cheap rather than expensive. §10.10 argued that *"a visible slice of high-end
residential AV design work happens on Macs, and a tool that cannot open there is simply invisible
to those people"*, and set against that a bounded 3–5 weeks. It then recommended (a) on the
strength of a desk survey it never ran.

---

**11.9.1 The debt register exists now, and it is a work list rather than a ledger.**

§10.10's recommendation carried a condition: *"nothing in M0–M6 may take a Windows-only dependency
without it being written down as a macOS debt item."* **That condition was never kept.** The
sentence appears in three documents (`docs/10-decisions.md:72`, `:1036`, and §10.10 itself) and
no register was ever created, so not one item was ever recorded.

`docs/13-macos-debt-register.md` is that register, compiled against `0f83628` by direct
inspection. Under this ruling it is not a deferral ledger: **its items are to be cleared.**

**THE DEBT IS SMALLER THAN §10.10 ASSUMED, AND THE REGISTER SAYS WHY.** The seams macOS needs were
already built, for other reasons: `Platform.isWindows` appears nowhere in Dart, the platform split
is an injected `isWindows` flag whose own comment already reasons about macOS errno tables and the
259-vs-4096 path limit, `FilePicker` is an `abstract interface class` with the Win32 dialog as one
implementation, the metrics font is bundled rather than system, and `path_provider_windows` sits
behind a single grep-enforced call site. §10.10's *"font availability"* cost item does not apply to
this tree at all.

**Two items carry lead time and neither is code**: Apple Developer enrolment and notarisation
(D8), and a second physical print matrix for AC-054 (D11). Both should start early *because* they
are not code.

**One thing is genuinely unknown and is not being asserted away**: whether CR-117's byte-exactness
gate survives a platform change. A platform-dependent float or font metric would surface there
first. It is cheap to measure once a macOS CI job exists, and it is the only item that could turn
a bounded port into a design question.

---

**11.9.2 Only the keyboard-modifier extraction (D7) is pulled into M2.**

The rest of the register is scheduled by its own dependencies, not crammed into this milestone.
D7 is the exception, and the reason is that **it is the only item that gets more expensive with
every commit.**

There are **22** hard-coded `SingleActivator` bindings today (four in `app_shell.dart:69-76`,
eighteen in `rack_canvas_screen.dart:3278-3350`) and §10.10 prices the `Cmd`-vs-`Ctrl` work
across *"~40 bindings"*. **M2-F adds the connection-creation keyboard path**, which moves the count
toward that estimate. Extracting the modifier now is roughly half the edit it becomes after.

It also pays two debts that were already owed and unrelated to macOS: M7's exit criterion requires
*"no keybinding bound twice **in the generated table**"* and the milestone board records that
**nothing generates a table**; CR-101's 16 collisions are unfixed for exactly that reason. One
extraction discharges the macOS modifier, the generated table and the collision arbitration.

**M2's exit expectation is amended accordingly.** This does not add a clause to the M2 exit
criterion in the roadmap (it is scheduling, not a criterion) but M2 is not to be called done
with D7 outstanding.

---

**11.9.3 What this does NOT change.**

- **DR-006 stands unaltered.** RackMate is an internal tool and Windows distribution remains
  self-signed with a timestamp, Microsoft Trusted Signing as the named fallback at M8. macOS
  notarisation is **additive**, and it was never in doubt: §12.9 already records that the macOS
  half of D10 is *"unaffected and still binding"*, it simply had no milestone to attach to.
  DR-009 gives it one.
- **No M0–M6 decision is reopened.** Every Windows-only dependency taken so far is recorded in
  the register and cleared on its own schedule. Nothing already built is wrong.
- **The milestone board is not re-stamped here.** `docs/12-milestone-board.md` is an audit pinned
  to `0fa532d`; its M7 row reading *"Windows-only"* and its §5.6 note that `apps/rackmate` has no
  `macos/` directory are **statements of fact at that commit and remain true**. They are
  superseded as SCOPE by this ruling, not as observations. Re-stamping a pinned audit without
  re-verifying its other claims would be worse than leaving it dated.

---

### 11.10 DR-010 · The registries ship as a seeded Dart catalog, and the family gets its dash back

> **RULING — settled by the user on 2026-07-28**, at the point M2-B became the first code in the
> repository ever to read `doc.registries` and found every map empty in every document.

**The finding that forced it.** `registries.dart:12` says the content "is catalog data shipped as
`assets/catalog/registries.json` at M1". That file **does not exist**, is declared in no pubspec,
and `SignalDomainDef`/`SignalFamilyDef` are constructed nowhere but the decoder. All four starter
projects carry `signalDomains: {}` and `signalFamilies: {}`, as do all six fixtures, for all six
maps. `buildSeedConnectorFootprints()` exists as a Dart seed and is **dead**, consumed only by its
own test, which is why `connectors: 0` everywhere too.

---

**11.10.1 The master catalog is SEEDED DART, not a JSON asset. This amends
`docs/02-data-model.md:834`.**

That line says the full contents are "shipped as `assets/catalog/registries.json`". They are not,
and they will not be.

**`rackmate_core` imports no Flutter, so it cannot load an asset at all**: `rootBundle` is
Flutter-only. A JSON master would have to be loaded by the app layer and injected through two
packages, because `rackmate_export` drives core directly and may never import `rackmate_ui`. A
seeded Dart catalog needs no seam, works in core's pure-Dart tests unchanged, and is what this
repository already does four times: 48 templates (`buildSeedCatalog`), connector footprints,
jacket-colour conventions, rack presets.

The JSON form's one real advantage, editing the catalog without a rebuild, is an ANTI-FEATURE
here. RackMate is an internal tool under DR-006 and the catalog is canon; a hand-edited registry
that disagrees with `docs/catalog/seed-devices.md` is the drift `palette_parity.py` was written to
catch after it "shipped four times".

**`tools/pal1_check.py` REMAINS THE SINGLE AUTHORITY for the palette, and the Dart seed is gated
against it.** Authoring 8 domains and 55 families into Dart by hand creates a fourth copy of data
that already exists in three places, which is precisely the failure mode this repository has been
bitten by. The seed is therefore checked against `pal1_check.py` by a parity gate in the same
family as `palette_parity.py`, that tool proves the DOCS agree with the authority; the new one
proves the CODE does.

---

**11.10.2 A document carries the registry subset it references, and that subset is written at
DOCUMENT CREATION: never computed at save.**

`docs/02:834`'s "the subset a document references is embedded in the file, which is what makes a
`.rackmate` self-describing" **stands and is implemented**.

**IT MUST NOT BE A CODEC TRANSFORM, and the reason is CR-117.** If `write()` recomputed the
referenced subset, then reading a document carrying an entry nothing references and writing it
back would DROP that entry, and `write(read(bytes)) == bytes` is the property the whole byte
suite is built on. Elision at save turns a hand-edited or forward-version file into silent data
loss. So a new document is seeded from the Dart master; thereafter the registries are ordinary
stored data that round-trips verbatim, like every other entity.

**`kSchemaVersion` does not move.** The `registries` key already exists and is written
unconditionally; populating it is additive within a key every reader already parses.

**Existing documents are not migrated.** A document with empty registries keeps them, and every
unresolved id degrades to the `unknown(rawId)` placeholder §6.2's own acceptance rule already
requires, "round-trips, renders grey with the raw id as its tag, and never throws". M2-B's
unresolved COUNTS are that rule working, not a defect to be fixed by rewriting user files. The
four starters ARE regenerated, deliberately, through `UPDATE_GOLDENS=1` with a reviewable diff,
because they are shipped fixtures rather than user data.

---

**11.10.3 `SignalFamilyDef` regains the type-within-domain channel.**

CR-078 moved COLOUR from the family to the domain, correctly: "no palette is CVD-safe past ~9
categories". It is quoted as also leaving the family only `shortTag` and an optional
`colorOverride`, and the model built from that has neither, plus no dash and no weight.

**That reading makes AC-054 unimplementable.** `seed-devices.md` §4.4 states plainly that
`dashOverride` "is the type-within-domain channel required by AC-054 and is what makes each of the
brief's ten named types individually identifiable", and §4.4's own table gives a distinct dash and
weight per family, `video.hdmi.1_4` solid 0.75×, `2_0` solid 1.00×, `2_1` solid 1.25×,
`displayport` `18,4`, `sdi` `10,3`, `hdbaset` `14,4`. With the model as built, ALL EIGHT DIGITAL
VIDEO FAMILIES DRAW AS ONE IDENTICAL SOLID LINE, and the dash channel (one of CR-078's four
encoding channels, and the one that survives greyscale) carries nothing.

So `SignalFamilyDef` gains `shortTag`, `dashOverride` and a weight override. **CR-078 is narrowed,
not reversed**: hue stays on the domain, which is the ruling's actual load-bearing claim; dash and
weight were never what "no palette is CVD-safe past ~9 categories" was arguing about.

The new fields are **ADDITIVE AND OPTIONAL**, written only when present, so no existing document's
bytes move, the `linkClassLocked` contract from §11.8.2, applied again.

---

**11.10.4 What this does not settle.**

`SignalFamilyDef`'s corpus field list runs to some twenty entries, `typicalMedia`,
`acceptedFamilies`, `adaptableTo`, `maxRunLengthPassive`, `nominalImpedanceOhms`,
`requiresTermination`, `carriesPower` and more. The model's "M0 MINIMAL SHAPE" note stays true and
those stay absent. Only the three fields AC-054's render actually needs are added here. The rest
arrive when something needs them, and `LEN-001`, which §4.4 says exists for exactly the HDMI 2.1
run-length cliff, will be the thing that needs `maxRunLengthPassive`.

---

### 11.11 DR-011 · The connect gesture: pin-to-pin, ports materialised on connect, and the sheet holds still

> **RULING — settled by the user on 2026-07-29**, at the point M2-F was scoped and the connect API
> M2-A shipped was read against the document M2-F actually has to run on.

**The three findings that forced it.** Each was verified by direct inspection, not inferred.

1. **Nothing in the application ever materialises a `Port`.** The only `doc.ports[id] = Port(...)`
   in the tree is `apps/rackmate/tool/starters/authoring.dart:463`, a **build tool**, not app
   code. `resolvePortSet` fills `portId` only where `doc.ports` already contains the derived id
   (`port_set_resolution.dart:121-123`), and `planAtomicConnect` skips any position where both
   `portId`s are null (`atomic_connect.dart:150`). **On a document built by placing devices from
   the palette, which is the document the M2 exit criterion starts from, every port set resolves
   to all-null members and `planAtomicConnect` returns a plan with zero conductors.** The connect
   API M2-A shipped could not have created a single conductor.
2. **Committing a link re-runs Sugiyama and moves every symbol.**
   `AtomicConnectCommand.touches => EpochMask.wires` (`atomic_connect.dart:245`); the schematic
   subscribes to `epochs.wires` (`schematic_canvas_screen.dart:238`), bumps `_sceneEpoch` (`:273`),
   misses the scene cache keyed on it (`:321-334`) and rebuilds, Sugiyama over the **new** edge
   set. Only `SheetItem.pinned` items are exempt (`schematic_scene.dart:806-821`), and **no command
   anywhere writes `EpochMask.sheet`**: the sole occurrence in the tree is the declaration at
   `command.dart:69`. Nothing is ever pinned, so every commit can rearrange the sheet.
3. **Every link the gesture creates would land in domain `str`.** `AtomicConnectCommand.apply`
   hardcodes `SignalFamilyId('structure.undetermined')` on both the `Net` and the `Service`
   (`atomic_connect.dart:255, 267`), which `seed_registries.dart:969-977` maps to domain `'str'`.

---

**11.11.1 Ports are materialised INSIDE the connect command's `apply()`.**

Not at device placement, that contradicts AC-006's lazy design and inflates every saved file with
ports nobody connected. Not as a sibling command inside a transaction either: `TxnScope.add` applies
immediately (`document_controller.dart:30-33`), so a transaction that materialises and then bails
leaves a history entry that did nothing the user can see, and `document_controller.dart:164`'s
"no-op edits add no history" stops being true.

Materialisation plans from `derivePortId` directly rather than requiring `doc.ports` to be
pre-populated. It is **idempotent**, and `revert` removes exactly what that `apply` added and
**never a port that already existed**.

---

**11.11.2 The gesture is PIN-TO-PIN. `atomicConnect` is the special case, not the general one.**

`ConnectPortsCommand` (one `Link`, one `Conductor`, two `PortEndpoint`s) is the general path.
`AtomicConnectCommand` is reserved for the case where the grabbed pin belongs to a `PortSetDef`
flagged `atomicConnect: true`.

**The evidence is arithmetic, not preference. 223 of the 257 catalog ports carry no `setKey` at
all**: no HDMI, RJ45, IR or outlet port is reachable set-to-set, because `resolvePortSet` requires
a declared `PortSetDef` (`port_set_resolution.dart:98-105`). The specifications were always
pin-level: docs/05:477 snaps to *"a port's glyph centre"*, docs/05:490 is *"`Tab` to a port … `Enter`
to commit"*, and `SymbolHitResult` returns a `portKey` (`symbol_hit_test.dart:149`). **Under a
set-to-set-only gesture the M2 exit criterion's sixty connections are not merely hard, they are
unreachable on the seed catalog.**

This also makes `PortSetDef.atomicConnect` load-bearing for the first time. It is a persisted
per-set opt-out that `planAtomicConnect` never reads (`template.dart:651, 662`); M2-F enforces it or
the flag is decorative.

---

**11.11.3 The command carries the port's REAL signal family.**

`ConnectPortsCommand` takes `signalFamily`, and `AtomicConnectCommand` is widened to take it too.
The value is known at plan time from `PortDef.signalFamily` (`template.dart:572`) and is already on
`SymbolPort.family` (`symbol_layer.dart:122`), so no document join is needed to compute it.

The hardcode was not a small wrong default. **It contradicts DR-001 and the coach mark that teaches
it**: AC-048 fires *"Filter to a domain to draw the wires"* (docs/04:468), and under the hardcode
every wire the user had just drawn would appear under Structure and never under Digital Video. The
render model and the commit path disagreed.

---

**11.11.4 Creating a link does NOT re-lay-out the sheet. Symbol positions freeze; wires and labels
rebuild.**

A `wires`-epoch bump reuses the existing node layout and rebuilds only the wire and label layers.

This is not a new rule; it is docs/05-schematic-editor.md:747 as already written: *"Auto-layout
never fires as a side effect."* What is new is that it is now **true**. Of the three shapes
considered, this is the only one that adds nothing to the saved file: pinning every symbol on first
layout would write a `SheetItem` per device into every document and grow the CR-117 byte surface to
carry UI state, and accepting the reflow would break chain-draw specifically, the next source pin
would have moved out from under the user between one link and the next.

**Corollary, and it is a live defect either way:** `_framed` is a one-shot latch never reset
(`schematic_canvas_screen.dart:621-623`), so any relayout that widens the sheet pushes content
off-screen with no re-frame.

---

**11.11.5 T1 violations are refused outright. There is no `[ Connect anyway ]`.**

The corpus contradicted itself: docs/02-data-model.md:854 gives T1's escape as *"None. There is
nothing to escape to"*, while docs/05-schematic-editor.md:441-456 routes model-illegal drops into a
spring-back box whose feedback line offers `[ Connect anyway ]`. **docs/02 governs.** M2 would
otherwise ship a way to persist a topology violation two milestones before M5's validation exists to
flag it.

Every refusal carries the TOP rule id **and a user-facing sentence naming the real designators**:
*"AVR-1 J03 already carries 1 of 1 connections"*, not a generic string. First-failure-wins in a
fixed, documented order. **TOP-001…005 only**; the six T2 rules stay deferred to M5 per
docs/09-roadmap.md:299.

---

**11.11.6 `Enter` commits on both canvases, under ONE label. The registry gets the retrofit, not a
loophole.**

docs/05:490 specifies `Enter` to commit a wire. **The M2-H registry as built cannot express that**:
the rack scope owns bare `Enter` labelled *"Apply the compaction preview"* (`keymap.dart:729-736`),
and `meaningDrift` compares label strings across scopes (`keymap.dart:1117-1134`), so a schematic
bare `Enter` with any other label fails arbitration.

Both scopes bind bare `Enter` under a **single shared label**, commit what is in flight, and
`applyCompaction`'s label is retrofitted to match. The same treatment applies to `Tab` and the
arrows against the caret rows (`keymap.dart:630-645`).

The rejected alternative is worth recording: widening `meaningDrift` to permit per-scope labels
would have been the smaller edit and is the wrong one. **`meaningDrift` exists precisely to stop one
key meaning two things, and a keyboard-only user cannot see a scope boundary**, which is the
population this clause is for.

---

**11.11.7 "Pinning on manual move" and "one Tidy sheet" are OUT of M2-F.**

They share the M2 roadmap line with the wire gestures and have **zero model support**: there is no
symbol-move gesture on the schematic, and no command touches `EpochMask.sheet`. They become their
own task so the roadmap line does not silently stay open. Note the coupling, had §11.11.4 gone the
other way, the `SheetItem` writer would have been pulled back in regardless.

---

**11.11.8 What this does not settle.** Three gesture rules remain underspecified in the corpus and
are ruled when M2-F Phase 4 reaches them, not before: chain-draw's *"the sink device's matching
output"* (docs/05:482) never defines *matching*; multi-draw's *"in rank order"* (docs/05:484) never
defines *rank*, and multi-draw is N Links where `atomicConnect` is one Link with N Conductors, one
line apart, which changes the schedule's row count if they are swapped; and *"type-weighted"* snap
is never quantified, while its only example (docs/05:477) names **connector** types where
compatibility is defined over **signalFamily** (:473), weighting on the connector actively pushes
toward SIG-001, since RJ45-carrying-`video.hdbaset` and RJ45-carrying-`net.ethernet` are the same
connector and docs/05:145 calls them the two most dangerous ports in the taxonomy.

Also unsettled: **where the AC-048 coach mark's "first" is persisted.** NOT FOUND in any normative
document. Document state re-fires per file and puts UI chrome inside CR-117's byte-exact format;
app-support prefs (docs/03:825) does not mention coach marks. It is decided in Phase 5.

> **All four are now ruled — see §11.12 (DR-012).**

---

### 11.12 DR-012 · The four gesture rules DR-011.8 deferred

> **RULING — settled by the user on 2026-07-31**, at the point M2-F Phases 0–3 had shipped and
> Phase 4 could not start without them. DR-011.8 named three and said they would be "ruled when
> M2-F Phase 4 reaches them, not before"; the fourth is the coach-mark question the same clause
> sent to Phase 5.

**The evidence that decided three of the four is the same evidence, and it is arithmetic.** Three
`PortDef` fields that look purpose-built for these questions are declared, round-trip through the
codec, and are **populated on none of the 727 seed catalog ports**: `acceptedFamilies`,
`channelIndex` and (per DR-011's own §11.11 finding) `maxConnections`. `seed_registries.dart:394`
says the first one outright, *"The exclusion list is not on the M0 class yet; the family separation
is."* A rule written against an empty field is a rule that does nothing on every real document,
which is the trap `effectiveMaxConnections` was introduced to escape in Phase 0 and which these
clauses escape the same way.

---

**11.12.1 Chain-draw's "matching output" means THE SAME `signalFamily`, in template order.**

docs/05:482 re-arms from *"the sink device's matching output"*, and its own worked example rules out
the reading that sounds most natural: `ATV-1 → MTX-1 IN1` then `MTX-1 OUT1 → DA-1`. **A matrix
switcher has no pairing between IN1 and OUT1**, that is what makes it a matrix, so *matching*
cannot mean "the output paired with that input". Nothing in the model pairs them either.

So it is the first free output whose `signalFamily` equals the family of the cable just committed,
tie-broken by `PortDef.order` then `key`. **That tiebreak is not a new ordering**: it is the sort
`_seqIn` already uses for `PORT_SEQ`, whose own comment records why, two orderings of one port list
is how a pin ends up with one number on the schedule and a different one in the set that wires it.

The rejected alternative is weighting on the CONNECTOR, and it is rejected for §11.12.3's reason.
Where no such output exists the chain ENDS and says so; a chain that silently stopped would be the
no-op docs/04 §3.4 forbids, arriving at the end of a gesture the user thought was continuing.

---

**11.12.2 Multi-draw's "rank" is `PortDef.order` then `key`: and it stays N `Link`s.**

Two halves, and only the first was genuinely open.

**Rank** is the template's declared order, the same sort as §11.12.1 and for the same reason.
`channelIndex` is the field that looks purpose-built for this and is **undocumented, nullable and
set on no seed port**, so a rule reading it would fall through to this answer on every real document
with an extra branch nothing could test.

**The N-Links half was never actually ambiguous, and is ruled here so it cannot drift.** docs/05:484
says multi-draw creates *"N `Link`s"*; the very next paragraph says an `atomicConnect` set is *"one
gesture producing one `Link` with N `Conductor`s"* (AC-053). DR-011.8's concern was that the two sit
one line apart and swapping them changes the schedule's row count, eight `Link`s on the pull sheet
versus one cable with eight conductors is a different bill of materials. The distinction is
**deliberate and preserved**: multi-draw is N cables the installer pulls separately; an atomic set
is one cable whose conductors happen to be countable.

---

**11.12.3 Type-weighted snap weights `signalFamily`, and the preference is ABSOLUTE inside the snap
radius.**

docs/05:477's example names **connector** types ("an HDMI band prefers an HDMI port even if an RJ45
port is 3 px nearer") while :473 defines compatibility over **`signalFamily`**. Weighting the
connector is not a harmless simplification: RJ45-carrying-`video.hdbaset` and
RJ45-carrying-`net.ethernet` are the SAME CONNECTOR, docs/05:145 calls them the two most dangerous
ports in the taxonomy, and `seed_registries.dart:394` records that patching an HDBaseT output into a
switch does not work and its 100 W PoH can damage the switch. A magnet that steered toward that
would be the product's own worst mistake, made sixty times an hour.

So the axis is the family, read through an `effectiveAcceptsFamily` in the shape
`effectiveMaxConnections` established: `PortDef.acceptedFamilies` when it is non-empty, exact family
equality when it is empty, which is every seed port today.

**The weight is absolute rather than a number**, because the corpus gives no number (only "more than
3 px") and inventing one would be a second unquantified figure. A family match beats a non-match
anywhere inside docs/05 §11.6's 12 screen px radius, which already bounds the effect. `Ctrl`
suppresses the magnet entirely (docs/05 §14) and is the documented way to insist on the other pin,
a mechanism M2-F Phase 3 already built, and which governs the drop as well as the preview.

---

**11.12.4 The AC-048 coach mark's "first" is persisted in APP-SUPPORT PREFS.**

Not document state: it would re-fire for every new file, and it would put UI chrome inside CR-117's
byte-exact surface, the identical objection that decided §11.11.4 against pinning every symbol.

Not unpersisted either: a mark that returns every launch until dismissed is a nag, not a coach mark.

App-support prefs is an addition to a store that already exists, 
`productionApplicationSupportDirectory` (one call site, `data_root.dart`), rather than a new
mechanism. docs/03:825 does not mention coach marks, which is why this needed a ruling and not a
lookup. Persisting per USER rather than per PROJECT is also what "first time" means to the person
reading it: the second project is not the first time they have seen the app.

---

**11.12.5 What this does not settle.** The T2 compatibility matrix is still absent,
`acceptedFamilies` is declared and empty, and `SIG-001` does not exist until M5. §11.12.3 is
therefore an ordering heuristic over pins the tier-1 rules have ALREADY allowed, and it is not
validation and must not be read as any. When M5 populates the matrix, §11.12.3's
`effectiveAcceptsFamily` is the seam it lands on.

---

### 11.13 DR-013 · Deleting a wired device cascades, after a warning that counts the cost

**The question.** `RemoveDeviceCommand.apply` carries a `TODO(post-M0)`: it removes the
`DeviceInstance` and *"does not yet decrement any TemplateSnapshot refcount, nor clean up orphaned
`Port`/`Link` references to this device"*. That was **inert while nothing in the application wrote
`doc.ports`**: the finding DR-011 opens with. §11.11.1 makes the connect command materialise ports
inside `apply()`, so from M2-F the note describes a live defect: deleting a wired device leaves
`Link`s whose `PortEndpoint`s name ports that no longer exist, and the schedule prints a row citing
a device that is not in the document. **"The gesture may hesitate; the document may not lie"
(CR-017)** is exactly what that breaks.

**Ruling: cascade, with a confirmation that names the count, and an undo that puts the cables
back.** Settled by the user on 2026-08-01.

**11.13.1 Removing a device removes every `Link` that terminates on it, and its materialised
`Port`s, in ONE undoable command.** Not orphaning (the document would lie), not a refusal
(§11.13.3), and not AC-018's `OpenEndpoint` demotion, which was the recommendation and was
rejected. The rejection is worth recording, because the recommendation was not wrong about the
model: `OpenEndpoint` genuinely does express "a cable whose far end is unbound", and demotion would
have kept every row and every `W` number on the pull sheet. What it would ALSO have kept is a pull
sheet full of half-cables nobody asked for, on a document the user believes they simplified, and
M5's validation, which is where "this run ends nowhere" becomes a visible finding, does not exist
yet. **A cable to a device that has been deleted is not a design intent; it is debris.**

**11.13.2 The confirmation states the count before anything is removed**, in the shape docs/04
§4.1's shrink dialog already uses for the same class of question: this is the second place in the
product where one gesture destroys work the user cannot see all of. A delete that silently drops a
dozen rows off the schedule is the failure G1 makes most expensive, **the schedule is the
deliverable**, so the count is the whole point of the dialog and a bare "Are you sure?" does not
discharge this clause. A device carrying nothing is deleted with no prompt at all.

**11.13.3 Refusal was considered and rejected.** *"Unwire it first"* is cheap and honest, and it is
the only place in the product where an ordinary edit would be blocked by a condition the user can
see and disagree with. CR-017 reserves refusal for the five tier-1 topology rules, whose escape
docs/02 §5 gives as *"None. There is nothing to escape to."* Wanting a device gone is not that.

**11.13.4 Undo restores the cables, not just the device.** `revert` must put back every `Link`,
`Service`, `Conductor`, `Net` and `Port` that `apply` removed, with the SAME ids, the discipline
`ConnectPortsCommand` already holds for the ports it materialises (§11.11.1: *"removing on revert
exactly what it added"*). Anything less makes delete-then-undo a lossy round trip through the one
entity CR-117's byte gate is about.

**11.13.5 What this does not settle.** The `TemplateSnapshot` refcount half of the same `TODO` is
untouched: `RemoveDeviceCommand` still does not drop a template snapshot that nothing references
any more. It is not a lie in the document (an unreferenced snapshot is inert, and AC-006's lazy
design means files carry snapshots for devices that were never placed) so it is file size, not
correctness, and it stays deferred.

---

### 11.14 DR-014 · Drawing a wired set member at a different device splits the set

**The question.** §11.8.3's `atomicConnect` makes a stereo pair ONE `Link` with two
`Conductor`s. Both jacks are then full, so `TOP-003` refuses every later cable from either of
them, reported from the field as *"the Right analog audio channels can't have connections made
once the left channel is made."* The document was correct; the product had no way to express the
one thing the user meant, which is *this half goes somewhere else now*. Board item #110 costed four
ways to say it and found that **no free single modifier exists**: `Ctrl` is the magnet suppressor
and additive selection (docs/04 §3.5), `Alt` is DR-001's drawn-wire hover, `Shift` is multi-draw's
run-selection (#93). Every option was a chord, a scarce unmodified letter, a pointer gesture with
no keyboard equivalent (breaking §11.11.6's parity), or a re-ruling of §11.11.2.

**Ruling: the drag says it. Splitting is automatic when a wire is drawn to a DIFFERENT device.**
Settled by the user on 2026-08-01, against all four costed options.

**11.14.1 No new input vocabulary is spent.** There is no modifier, no mode letter, no
double-click and no dialog. This is what makes §11.11.6's keyboard/pointer parity free rather than
argued, there is no chord to reach on a keyboard, and it means there is nothing to discover: the
drag the user already tried IS the gesture.

**11.14.2 A split fires only where the gesture cannot mean anything else: four conditions, all
required.** (1) the pin is FULL, so a connect that TOP-003 would allow never splits; (2) EXACTLY
ONE conductor end lands on it, because "which of these did you mean to displace" has no derivable
answer; (3) its `Link` carries MORE THAN ONE conductor; (4) that conductor's far end is not already
on the device being drawn to. An `OpenEndpoint` or `PlaceEndpoint` far end splits, neither names a
device to be the same as, while an UNRESOLVABLE `PortEndpoint` does not, because *"I cannot tell
which device that is"* is not *"it is a different one"*.

**11.14.3 Condition 3 is the one with teeth, and it is what keeps a split from being a delete.**
Lifting the only conductor out of a `Link` leaves a `W` number and a schedule row for a cable with
no electrical path, which `ConnectPortsCommand`'s own zero-conductor guard calls *"no conductor at
all"* and throws over. Re-routing a single run by dragging its end is a real gesture and a
reasonable thing to want; it is **not this one**, and it must not happen by accident to a user who
was aiming at a stereo pair. G1 makes that failure the most expensive kind: the schedule is the
deliverable and the loss is invisible until it is printed.

**11.14.4 The announcement names the bill of materials, per §11.12.2.** A split moves one conductor
across the line between *one cable with N conductors* and *N cables*, the pull sheet gains a row
and an existing row loses a path, and a silent choice between those two is the harm DR-012.2
exists to prevent. Naming the `W` number alone does not discharge this: the sentence states the
COUNT, as *"…split out of W001, which now carries 1 conductor instead of 2."* The Edit menu label is
`splitSet`, not `connectPorts`, for the same reason.

**11.14.5 A refusal writes nothing, splits included.** §11.11.5 gives tier 1 no `[ Connect anyway ]`.
A gesture refused after having nonetheless lifted a conductor would be the worst outcome available, 
the user is told nothing happened and their stereo pair is now a mono cable, so the rules are
evaluated ONCE, against the document as the splits will leave it, and nothing is applied in order
to plan.

**11.14.6 §11.11.2 is amended, not overturned.** The branch is still decided BY THE JACK. What
changes is that a set which is ALREADY ONE CABLE has no legal set gesture left, every member is
full, so a full member arms the pin-to-pin path instead. An unwired member still arms the whole
set. A set is one cable the first time and splittable afterwards.

**11.14.7 What this does not settle.** Dragging FROM an unwired set member ONTO a wired one still
arms the set gesture and still finds the target set unavailable. Splitting a WHOLE target set out of
its cable is a materially larger action than lifting one member and was not ruled on; the reported
gesture, grab the member that is already wired, is the direction that works. Deferred with #111
(the set bracket, which must now distinguish a set that is one cable from one that has been split)
and #112 (stereo pairs for de-embedded zone audio).

---

### 11.15 DR-015 · The `rm` extension family, and what a device archive is

**The question.** The product's three user-visible file kinds were named in three different
idioms, `.rackmate` for a project, `.rmdev` for a device template, `.rmlib` for a library pack,
and only the first has ever existed. The owner chose one family: **`.rmpj` project, `.rmdx`
device, `.rmda` device archive.**

**11.15.1 The ruling.**

| Extension | Contents | Status |
|---|---|---|
| `.rmpj` | One project. Plain, pretty-printed, key-sorted UTF-8 JSON, `document` wrapper. **Renames `.rackmate`.** | Built (`dc22ddc`) |
| `.rmdx` | One device template. Plain JSON, same unit regime (CR-063), own migration chain. **Renames `.rmdev`.** | Spec only: nothing constructs one (docs/12 §5.3) |
| `.rmda` | Many device templates in one file. **Renames `.rmlib` and un-cuts it.** | Not built, not scheduled: §11.15.4 |
| `.bak` | The single sibling backup of a `.rmpj`. No `.history/` folder. | Unchanged (CR-098) |

**NOT ONE BYTE INSIDE A FILE MOVES.** CR-091's container ruling stands verbatim, `schemaVersion`
does not advance, and the migration chain is not involved. This is a rename, and calling it
anything more would put a format change in the record that did not happen.

**11.15.2 `.rackmate` is still opened, and still saved in place.** Not deprecated, not migrated
on open, not renamed underneath the user. `kDocumentExtensions` lists both spellings; the path
normaliser appends the first and treats every entry as already-correct. The consequence that
forced this shape: `SessionController.save()` runs the ALREADY-OPEN path back through that
normaliser, so a single-entry list would turn a team's `Smith.rackmate` into
`Smith.rackmate.rmpj` on `Ctrl+S`, a second file, the first left holding older bytes and still
in the recents list, and nothing looking wrong until they open the wrong one. **Save As and a
never-saved document still reach for `.rmpj`, so the old spelling is accepted and never
propagated.**

The same rule governs the app's own files. A snapshot and a recovery pair ARE ordinary documents
(§9.4), so both carry the project extension and both had to learn the old one, see docs/12 §5.1
for the two silent-loss paths that fell out of that and were closed with it.

**11.15.3 The device archive is not a new idea; it is AC-042's cut, re-opened.** The corpus
already specifies this file. It is `.rmlib`, and AC-042 cut it from v1 together with the
`signature` field and the `provenance`/`derivedFrom` chain. So `.rmda` is a **rename plus a scope
edit under roadmap §8.3**, and it is recorded as one rather than as a naming decision that
happened to add a feature.

What AC-042 cut and what it kept is worth restating, because the two halves are separable and the
cut was argued as one thing. It kept `contentHash`, "three lines, and it is what makes the
embedded-snapshot argument true". It cut the cryptographic apparatus. **`.rmda` needs neither.**
A library pack that carries no signature and no provenance chain is exactly the `contentHash`-only
object the surviving half already describes, N times over. Nothing in AC-042's reasoning argues
against the container; it argues against the trust machinery that was bolted to it.

**11.15.4 `.rmda` IS A SINGLE JSON FILE, NOT A ZIP, and this is the ruling's one real content.**

`.rmlib` was specified as a zip. That is what makes it expensive, and the expense is documented:
docs/research/critique-completeness.md D8 lists **zip-slip protection, entry-count limits,
uncompressed-size limits (zip bomb) and image-decode bounds** as needed-and-absent for it, and
separately warns that `RulePredicate`, "an evaluated program", could arrive inside one.

**The zip buys nothing here.** It existed to carry per-face device images, and images are cut
(AC-057). A device template is inert JSON with no binary member. So the container question
resolves exactly as it did for the project file, and it is the SAME argument, made once already
by CR-091: *"The zip alternative existed only to carry per-face device images, and images are cut
from v1, so the container question resolves to what the confirmed product decisions already
specified."* Applying it a second time is consistency, not a new call.

A `.rmda` is therefore **one JSON file holding a manifest and an array of `TemplateBody`**, in the
`.rmdx` regime, with the `.rmdx` migration chain reused rather than a second one invented. It
inherits AC-058/D8's existing JSON depth and size limits and introduces **no new attack surface at
all**: no path traversal, no decompression bomb, no entry count. It also stays diffable, which a
zip of JSON is not, and `.gitattributes` can protect it byte-exactly the way it protects the other
two.

The cost, stated plainly so nobody discovers it later: **no compression.** A pack of 500 templates
is a few MB of JSON where a zip would be a few hundred KB. That is the entire trade, it is
measured in a file people email once, and it is the right side of it.

**11.15.5 What `.rmda` still does not have, and why it is not scheduled here.** The file format is
the small half. The owner's stated goal is *"multiple device libraries loaded into the device
palette and filtered as needed"*, and none of that exists: there is no library directory service,
no import/export surface, no notion of a template's SOURCE library, and no palette filter keyed
to one. docs/research/critique-completeness.md A8.2 says the same thing about the whole template
lifecycle, *"no implementation home"*. Ruling the format now and building the subsystem later is
deliberate: the format is what other decisions have to be consistent with, and it is decidable
today. The subsystem is M4 work and is tracked on the board.

**11.15.6 What this does not settle.** File-type REGISTRATION (double-click-to-open, the shell
icon, the MSIX `FileTypeAssociation`) is not ruled here and does not exist for any extension,
old or new (critique-completeness: *"No file-type registration for `.rackmate` / `.rmdev` /
`.rmlib` on Windows/macOS"*). It is now cheaper to do, because there is one coherent family to
register instead of three idioms, and it belongs with the MSIX epic where the manifest is.

---

### 11.16 DR-017 · `dart format` is a gate; the analyzer stays a ratchet

**Ruled 2026-08-03.** The first `DR` that is about **process rather than product**. It is numbered
because roadmap §8.2 requires every issue and PR to cite a ruling id, and the board item
implementing this decision (#566) had nothing to cite. A binding user decision without an id is
indistinguishable, to §8.2's reader, from an unadjudicated one.

**11.16.1 What was asked.** `docs/12` §4.1 recorded an open decision and marked it the user's
rather than an engineer's: `docs/11` §7 documented two gates, `dart analyze --fatal-infos
--fatal-warnings` and `dart format --output=none --set-exit-if-changed .`, and **neither ran**. Both
failed on the tree as it stood. The choice was to make the tree satisfy the documented gates, or to
amend `docs/11` §7 to the gates actually intended. Standing up CI without deciding would have
produced a permanently red `main`, which trains people to ignore output and is worse than no CI.

**11.16.2 The ruling: both, split by gate.**

1. **`dart format --output=none --set-exit-if-changed .` is a gate, absolutely.** It is **gate 1b**
   in `azure-pipelines.yml` and in `tools/ci/run_local.ps1`. The local gate count is **fourteen**.
2. **The analyzer keeps its ratchet.** Zero errors and zero warnings, gated; infos pinned to an
   exact number in `tools/ci/analyze_info_baseline.txt`. **Not `--fatal-infos`.**
3. **`docs/11` §7 is amended** to describe the pipeline that exists.

**11.16.3 Why the two halves differ, since they were documented as one.** Formatting is mechanical:
it has exactly one correct answer, the gate's own remedy is the same command a developer types, and
once paid it stays paid. Analyzer infos are not that. They are style opinions with real
disagreement in them, clearing them is judgement work rather than a command, and gating them
absolutely against a 195-info tree would have made `main` red on the first push. The ratchet gets
the property that matters, which is that the number cannot grow, without the property that would
have made the gate ignored. **Treating the two as one question was the error `docs/11` §7 encoded.**

**11.16.4 What it does not rule.** Clearing the remaining infos and switching gate 4 to
`--fatal-infos` is **not** foreclosed and is **not** scheduled. It stays available at any time. This
ruling declines to make it a milestone's problem, nothing more.

**11.16.5 Scope.** **None.** This changes no item's place in v1, v1.1, v1.2, v2 or not-doing, so
§8.3 does not apply and roadmap §2 is untouched. It changes the **definition of done**: `docs/11`
§9 clause 1 now reads as the fourteen-gate local run.

**11.16.6 What it cost, and the general lesson.** The decision sat open long enough for its own
premise to drift: `docs/12` §4.1 and `azure-pipelines.yml` both record **88** unformatted files,
measured when they were written, and it was **124** when the sweep was finally run. The analyzer
pin moved 195, then 194, then 173 across the same period. **A deferred mechanical decision does not
hold still**, which is the argument for gating this class immediately rather than scheduling it.

**11.16.7 Landed.** `b6ff394` (the sweep, 124 files, pin 194 to 173), `ecdf3b2` (the gate, in both
lists, mutation-tested), `c6408cb` (`docs/11` §7 rewritten; it had specified a **GitHub Actions**
workflow at `.github/workflows/ci.yaml` with a three-OS matrix, a directory this project has never
had), `50ba327` (three derived sites the first sweep missed). Board **#566**, closed.

---

### 11.17 DR-018 · The Plan view moves from not-doing to v1.1, conditionally

**Ruled 2026-08-04.** A **scope amendment under roadmap §8.3**, and the second after DR-016. It
moves one item out of the not-doing table, adds nothing to v1, and changes no milestone's contents
or cost.

**11.17.1 What was asked.** A "Plan" view that accepts an uploaded floorplan, allows field devices
to be placed on it, and drives the pull schedule and diagram set from those placements. The stated
motivation is that the system designer currently marks device locations as coloured dots in the iOS
Notes app, and work is inevitably done incorrectly against them. The feasibility study is
`docs/research/feasibility-plan-view.md`, written against the tree at `ff61aa7`; this ruling cites
it rather than restating it.

**11.17.2 The ruling.**

1. **The Plan view is v1.1, not not-doing.** The §7.6 row is amended: `Cable dressing, 3D, thermal
   simulation` remain out of the brief; **floor plans leave that row**. Roadmap §2.5 is amended
   identically, and roadmap §2.2 gains the item. This is the one scope list (§8.3).
2. **The v1.1 placement is conditional, and the condition is stated.** Roadmap §2.2's membership
   criterion is *additive: no format migration, no command-stack change, no re-derivation of user
   data*. A stored floorplan raster is a format change under every available design. **If the
   underlay carrier does not ship in v1, the Plan view is v1.2**, by §2.2's own rule and without
   further argument.
3. **Nothing is added to v1 by this ruling.** The carrier decision named in 11.17.4 is owed, not
   granted. DR-018 does not put a byte of it in v1 on its own authority.
4. **The Plan view does not displace M3.** It is a better front end for what M3 builds and is not a
   substitute for it. `T6.10` remains the answer to the motivating problem.
5. **Reevaluation is scheduled by condition, not by date.** If the plan runs ahead of its
   §12.7 position, the placement is reconsidered. Nothing else triggers it.

**11.17.3 Why the old ruling moved so cheaply.** It should be recorded that §7.6's floor-plan row
was never argued. Four unrelated items share one table cell, and the rationale attached to it
(*"The brief says the plan ignores cable dressing, and it is right to"*) defends the first item
only. DR-005 §11.5.3 independently describes floor plans as *"remain out (v1.1 / v2)"*, a deferral
with a named home rather than a prohibition, which is a different thing from DR-004's *never*. The
amendment reconciles the two statements in favour of the one that was reasoned.

**11.17.4 The decision this ruling does NOT make, and when it is owed.** How a raster is stored is
**open**. The candidates are base64 inside the pretty JSON, or the zip container CR-091 parked for
v2, and the feasibility study §3.2 costs both. It is owed **before M3 closes**, because M3 is the
milestone that first puts field devices into user files and roadmap §2.1's filter 2 (G5) says a
decision of this shape ships its model in v1 even when its UI does not. Deferring it past M3 turns
an additive change into a migration over user data, which is the precise failure G5 names.

Two facts belong with that decision when it is made. **AC-057 cut device images specifically to
close the container question** and named removing the image-decode import surface as a benefit;
§11.15 records the same observation from the other side. Reopening it is a real cost and is not to
be presented as free. And **`docs/13` gains an entry** if the chosen import path is a Windows-only
rasterizer, because DR-009 puts macOS in v1.

**11.17.5 What it does not rule, beyond 11.17.4.** It does not add `drawImage`/`ImageRef` to
`DiagramCanvas`; **RJ-017 stands** and the interface's own amendment clause still governs. It does
not add `T6.40`, `T6.50`, riser diagrams or reflected ceiling plans, which stay where DR-005
§11.5.3 left them. It does not weaken **G4**: a plan yields a measured horizontal distance, never a
route, and a plan-derived length stays tagged as an estimate under AC-024 unless a human marks it
measured. It does not reverse **AC-024**, which keeps its per-room number as the source that ships.
It does not touch **mobile editing**, which is v2 (§2.4) and read-only in v1 (AC-056). The
feasibility study §7 records that the motivating workflow is a tablet one and that this feature
does not reach it.

**11.17.6 Cost, for the record and not for scheduling.** 5–7 weeks minimum viable, **7–10
recommended** (raster import only, zip container), 9–13 with PDF rasterization on both platforms.
Feasibility study §6 carries the phase breakdown. **This does not enter §12.7's totals**, which
cost v1, and none of it is v1.

**11.17.7 Landed.** Ruling and scope list, this commit. Nothing is implemented and nothing is
scheduled. No board item.

---

### 11.18 DR-019 · The plan container is JSON-or-zip by sniff; v1 owes a passthrough, not a carrier

**Ruled 2026-08-04.** Answers the question DR-018 §11.17.4 left open and **corrects the premise it
left it open on**. The correction is the more useful half of this ruling and is stated first.

**11.18.1 DR-018 §11.17.4 was wrong about why the decision was urgent.** It said the raster carrier
was owed before M3 closes because G5 applies: omitting it would cost a format migration. **It would
not.** The format already absorbs this addition. `looksLikeZip` returns a typed
`UnsupportedZipContainerError` rather than crashing, `minReaderVersion` signals forward-incompat
honestly, `PlanUnderlay` would be an absent entity map and a pin an absent key (G4, CR-114), and no
existing plain-JSON file would change a byte. The reasoning was assumed from the shape of the
question rather than checked against `persistence/`, and the check is what this ruling ran.

**There is a real G5 item, and it is a different and much smaller one.** `unknown` passthrough
exists on exactly four things in this tree: the root envelope, `EntityMeta`, `Port` and `SheetItem`.
**`Placement` has none.** `json_codec.dart` decodes `OffRackPlacement` as exactly `locationId` and
`mountNote` and re-encodes exactly those two, so a build that predates the Plan view, opening a file
that has plan pins, **silently drops them on save**. Under DR-006 this is an internal tool whose
users share files, so mixed-version editing of one project is an ordinary Tuesday rather than an
edge case, and silent field loss is precisely what G4's discipline forbids.

**11.18.2 The ruling.**

1. **The container shape is `.rmpj` = plain pretty JSON with no binary member, zip container with
   one.** The existing `PK\x03\x04` sniff becomes the discriminator it was already shaped to be.
   CR-091's single-file property survives; a document with no underlay writes bytes identical to
   today's.
2. **The zip writer owes stated determinism**, because CR-117 requires `write(read(bytes)) ==
   bytes` and zip is nondeterministic by default: entries sorted by member name, a constant
   timestamp rather than the wall clock, one compression method, no extra fields. Member layout is
   `document.json` plus `underlays/<uuid>.<ext>`, and the JSON member is byte-for-byte what the
   plain path would have written, so one encoder serves both.
3. **Base64-in-JSON and a sidecar file are both rejected**, with reasons, in docs/15 §2. They are
   the obvious alternatives and the record should show they were considered rather than missed.
4. **Raster in, PDF out.** PNG and JPEG are read; PDF is not. `pdf` writes documents and does not
   import pages, so PDF import means PDFium or WinRT, and either adds a multi-megabyte native binary
   to a self-signed portable distribution (DR-006) or owes a `docs/13` entry against DR-009. PDF
   import stays available later and changes no stored format when it comes.
5. **What v1 owes is the passthrough, not the carrier.** An `unknown` map on the `Placement` union
   and on `Outlet`, matching the pattern `Port`, `SheetItem` and `EntityMeta` already use. It lands
   in **M3**, it is days rather than weeks, and it protects every future placement field rather than
   only this one. **The container itself is built with the Plan view, not in M3.**
6. **DR-018's condition is discharged, and the Plan view is v1.1 unconditionally.** Roadmap §2.2's
   membership criterion forbids a format *migration*; the shape ruled in (1) migrates nothing, since
   every existing file stays plain JSON and stays readable. So the criterion is satisfied on its own
   terms rather than by exception.

**11.18.3 What it does not rule.** Whether the Plan view is pulled into v1 as an `M3.5`. That stays
available, stays a §8.3 amendment, and is better taken after M3 has been used than before it is
built. DR-018 §11.17.2 clause 5 is unchanged: the trigger is running ahead of §12.7's position,
nothing else.

**11.18.4 Scope.** **v1 grows by one item**, the §11.18.2(5) passthrough, which is why this is a
§8.3 amendment and not a note. Roadmap §2.1 gains it. No milestone is re-costed: it is days inside
M3's existing `M`, and it adds no clause to M3's exit criterion, because the criterion is a 60-drop
rough-in producing a Pull Sheet and a forward-compat guard neither helps nor hinders that.

**11.18.5 The general lesson, since this is the second one this week.** DR-018 §11.17.4 asserted a
migration cost from the shape of the question. DR-017 §11.16.6 recorded a premise that drifted while
its decision sat open. **Both are the same failure**: a claim about the codebase that was reasoned
rather than read. The remedy is not more caution, it is `grep`, and the cost of skipping it here
would have been a v1 scope addition of several weeks in place of one of several days.

**11.18.6 Landed.** Ruling, scope list and the design document `docs/15-plan-view.md`, this commit
and the two beside it. The passthrough is not implemented; it is M3's. No board item.

---

### 11.19 DR-020 · A plan may not predict a route; the length column's job is the as-built tally

**Ruled 2026-08-04.** A **scope amendment under roadmap §8.3** and the first ruling in this record
whose evidence is the trade rather than the corpus. It corrects `docs/15-plan-view.md` §4 one
commit after that document was written.

**11.19.1 What the trade said, and why it overturns §4's first draft.** `docs/15` §4 specified a
**route polyline** the designer would draw at design time on the plan, a project-level
`routingFactor` and a `slackAllowance`, and treated the sum as a *measured* length. The user's
correction:

> Structural elements — LVLs, concrete beams, heavy purlin usage — regularly force a run through a
> crawlspace instead of the attic, and which of those happens is not knowable when the plan is
> drawn. There may be no need to pre-plan exact runs at all.

**The route is discovered, not designed.** Two drops in the same room to the same wall can take
paths differing by tens of feet, decided by framing nobody has opened up yet. A design-time
polyline therefore stores a guess wearing the visual authority of a measurement, which is G4's
central prohibition, and it is *worse* than the per-room estimate it would have replaced because it
looks specific. **§4's first draft is void and is not to be re-argued from.**

**11.19.2 The ruling, five parts.**

1. **The Plan view predicts no routes.** The route polyline, `routingFactor` and `slackAllowance`
   are **deleted**. The plan's only length contribution is **`planLowerBound`**: the calibrated
   straight line from rack pin to device pin, plus the location's `riseAllowance` if one is set.
   It is one new value on the **existing** `ScheduleLengthSource` enum, not a new mechanism.
2. **A bound is not an estimate, and the distinction is load-bearing.** `planLowerBound` prints
   italic and **prefixed `≥`**, and **never enters the footage rollup as a quantity**: a bound
   cannot be summed into "how much Cat6 to order" without making a claim it is not entitled to
   make. Its value is the asymmetry: **a plan can prove a length violation and can never prove
   compliance**, because if the bound already exceeds the limit no path can rescue it.
3. **`Link.spliceCount: int?` ships in v1, in M3.** Null is unknown, `0` is confirmed none
   (G4, CR-114). A splice is a real as-built fact with real consequences: on Cat6 it breaks the
   channel and fails certification, on coax it is loss, on fibre it is normal and engineered.
   `Link.notes` already exists and carries the why.
4. **`LEN-002` ships in v1, and the catalogue becomes 28.** *A run's known length exceeds the
   declared maximum for its media type.* One generic rule reading a **new `maxLength` on the media
   registry** rather than one rule per medium: one AC-051 fixture pair instead of three or ten, and
   a new medium's limit costs a registry row rather than an amendment. Tier 3. **The field is not
   new and is not called that; it is `MediaTypeDef.maxRunLengthPassive`, and §11.19.7 is the
   census.**
   **The v1 catalogue is 28 rules: 8 tier-1 + 6 tier-2 + 14 tier-3.** AC-051's gate is unchanged
   and now applies to 28 pairs.
5. **The as-built tally surface ships in M3**, with the Structure editor, reusing its bulk-entry
   ergonomics (AC-048). An installer closing out sixty runs needs one table with a length column
   they tab down, not sixty inspector visits.

**11.19.3 Why most of this was already built, which is why it is cheap.** `Link` already carries
`routedLength`, `cutLength`, `terminatedLength` (AC-024), `roughInStatus{planned, pulled, dressed,
terminated, tested}` and `TestResult{pass, headroom, certificateId}`. `derived/schedule.dart`
already projects `terminatedLength` and `roughInStatus` into every `ScheduleEntry`, and
`ScheduleLengthSource` already tiers provenance as `cut | outletNominal | roomEstimate | none`.
M3's checklist already owns *"the three length fields"*. **The as-built story was 80 % modelled and
0 % reachable**, which is the gap this ruling closes. `docs/15` §4's first draft did not notice the
enum existed and invented a parallel four-tier scheme; that is the second time in this record a
design was written without reading the code it duplicates (§11.18.5).

**11.19.4 What it does not rule.** Whether `PathwayKind` gains `attic` and `crawlspace` alongside
`conduit | jhook | tray | plenumSpace | riser | directBury | exterior`. Both carry consequences an
integrator acts on (temperature rating, rodent, moisture) in the way `plenumSpace` carries a code
consequence, but both are *spaces* and the location tree already models spaces. **Owed at M3**, when
`Pathway` gets its editor. **DISCHARGED by DR-031 (§11.30) on 2026-08-09**: both values are added,
because `Location` models where a room is and `Pathway.kind` models what a cable passes through, and
an attic a run crosses is nobody's room. It also does not add length rules per medium beyond
`LEN-002`; AC-040's deferral of the remaining ~40 rules to v1.2 stands.

**11.19.5 Scope.** **v1 grows by three items**: `Link.spliceCount`, `LEN-002` plus its registry
`maxLength`, and the as-built tally surface. **v1.1 shrinks by one**: the Plan view's route
polyline. **M3 grows for the second time** (DR-007 was the first) and stays `M` at its upper end;
the tally surface is a column on a table the milestone already builds, not a new screen. M5 gains
one rule and one fixture pair. Roadmap §2.1, §2.2 and M3's checklist are amended.

**11.19.6 Landed.** Ruling, scope list, `docs/15` §4 rewritten, and the 28-rule sweep across ten
documents. Board M3-J (#569) was added afterwards and decomposed on 2026-08-08 into #583–#586;
`Link.spliceCount` shipped at `70a93f4`.

**11.19.7 The registry field is not new, and this is the census rather than a decision.** §11.19.2(4)
asks for *"a new `maxLength` on the media registry"*. There is no such field and there never was one
to add: `MediaTypeDef` has carried **`maxRunLengthPassive`** and **`maxRunLengthActive`** since M0,
and M3-C/6 seeded the first of them at `acd63d5`. Board #569 asked which milestone owned the field
before any model work landed; the answer is that **M3 owns it and M3 has already shipped it**, so M5
owes only the rule. Ruled here rather than in a board comment because three derived documents and
this one all name a field that does not exist, and the next reader to implement `LEN-002` would
otherwise add a third.

**`LEN-002` reads `maxRunLengthPassive` and must not read the active one.** `maxRunLengthActive` is
**null on all 38** shipped media types and gated as such, because canon §6.5 has one `Max channel`
column and the active field is a separate M0 field with no source. A rule written against it would
compile, pass its own AC-051 fixture pair if the fixture set the field, and **never fire on a real
document**. Silent non-firing is the worst failure mode a validation rule has, and it is the one
this clause exists to prevent.

**Seven of 38, not 38 of 38, and the rule must survive that.** Thirty-one types carry no declared
maximum because canon §6.5's column is hedged prose (`~150 m`, `100 m+`, `hundreds of feet`), and G4
forbids rounding a hedge into a figure an installer buys cable from. `LEN-002` is therefore
**silent** on those thirty-one rather than treating null as zero or as infinity, and it reports how
many runs it could not check, the way `LEN-001` already emits *"length unknown, cannot verify"*
rather than passing silently.

**Nothing above changes what §11.19.2(4) ruled.** One generic rule over a registry field, tier 3,
one fixture pair, still in M5. Only the field's name and its existing state are corrected.

---

### 11.20 DR-021 · Deleting a `Location` cascades the subtree and clears every reference

**Ruled 2026-08-06.** M3-B/1 (board #144) asks for the four commands the location tree has never
had: add, rename, reparent, delete. Three of the four are unambiguous. **The corpus says nothing at
all about what a delete costs**, and the tree is the one entity where that silence is expensive,
because `Location.parentId` makes the damage recursive (CR-047) and **nine fields across seven
entities point at a location** from outside the tree, two of them inside immutable value objects.

**The census is part of the ruling, because the question was asked with seven.** They are
`Rack.locationId`, `DeviceInstance.locationId`, `OffRackPlacement.locationId`, `Outlet.locationId`,
`StructureBody.distributionDeviceLocationId`, `Circuit.locationId`, `Pathway.fromLocationId`,
`Pathway.toLocationId` and `PlaceEndpoint.locationId`. A case-sensitive grep for `locationId` finds
seven of the nine and misses both of `Pathway`'s, because they are spelled `fromLocationId` and
`toLocationId`. **Two of the nine were found by censusing the field rather than by grepping for the
name it was expected to have**, which is DR-012's habit applied to a smaller question.

**11.20.1 The subtree goes, in one undoable command.** Deleting a node deletes every descendant.
**Promotion was considered and rejected**: reparenting the children onto the deleted node's parent
leaves every surviving room carrying a breadcrumb nobody edited it to have, and a vocabulary whose
addresses change without an edit is the failure `docs/00` opens with, *"the plan says Study, the
homeowner says Office, the label says Room 3, and nobody wins"*. **Refusal was considered and
rejected on DR-013 §11.13.3's ground**, which is not re-argued here: CR-017 reserves refusal for the
five tier-1 topology rules, whose escape `docs/02` §5 gives as *"None. There is nothing to escape
to."* Wanting a room gone is not that.

**11.20.2 Every reference is cleared to null, never left dangling.** Null is G4's unknown and is
what the derivations already read: a drop whose room is cleared prints under the Pull Sheet's own
`NO ROOM RECORDED` band (`schedule.dart`'s `kUngroupedTitle`) rather than vanishing from the
deliverable or acquiring an invented room. **Leaving the ids is cheaper and is rejected**: a file
reopened next month cannot tell a dangling id from data loss, and CR-017's *"the document may not
lie"* is exactly about a file asserting a thing that is not there.

**11.20.3 The count is computed once, before anything moves, and the command consumes it.** DR-013
§11.13.2's shape for DR-013's reason, and `device_removal.dart`'s: two walks asking the same
question is how the dialog and the edit drift apart, and a dialog that said "4 rooms" and removed
five is worse than no dialog. It counts **locations and referring entities**, in those two units,
because those are the two things the user is about to lose.

**11.20.4 Undo restores all of it, with the same ids.** DR-013 §11.13.4 verbatim, and it reaches
one step further here. `OffRackPlacement` and `PlaceEndpoint` are immutable, so clearing them means
constructing replacements; `revert` must therefore put the **original** objects back rather than
reconstruct equal ones. Anything less makes delete-then-undo a lossy round trip through the one
property CR-117's byte gate is about.

**11.20.5 A reparent refuses a cycle.** Not a delete question, but the other half of the same
command set, ruled here so it has an id to cite. A reparent that would make a node its own ancestor
is **refused**, walking child to parent with a visited set and a sentence naming both nodes, exactly
as `TOP-005` walks a shelf chain. This is not the refusal §11.20.1 rejects: a cycle is not a design
the user disagrees with, it is a tree that is not a tree, and every derivation over it (roots, the
path to a node, the breadcrumb, the Pull Sheet's own room order) is non-terminating rather than
wrong.

**11.20.6 What it does not do, and what it does not rule.** It does not delete a `Link`, an
`Outlet`, a `Pathway` or a drop. **A cable pulled to a wall is a fact about the building and
survives the room being renamed out of existence**, which is the argument
`RemoveStructureCommand` already makes about an outlet surviving the panel it feeds. DR-013's
cascade stops at this boundary and is not authority to cross it. It also does not rule where a
location may be deleted from; the panel is M3-B/2's question.

**11.20.7 Scope.** **No scope change.** M3-B is unchanged in size and the roadmap is not amended;
this settles a question inside a milestone that already owns the work. Board #144 and #145 cite it.

---

### 11.21 DR-022 · `{SERVICE}` in a drop's field label is the outlet template's tag

**Ruled 2026-08-07.** M3-D/1 (board #152) wires the two label formats that have round-tripped
since M0 with exactly one caller each, the codec. CR-044 ships their defaults as two named presets
and CR-045 gives the grammar. **Neither says where `{SERVICE}` gets its value**, and the question
is not academic: `{ROOM_ABBR}-{SERVICE}-{SEQ}` has no `[...]` around any of its three tokens, so a
missing one is `MissingTokenValueException` rather than a blank.

**11.21.1 The measurement that forced the question.** Rendering the two shipped defaults against
the drops M3's own exit criterion describes:

| Case | `{ROOM_ABBR}-{SERVICE}-{SEQ}` |
|---|---|
| every token known | `GR-TV-1` |
| **service undetermined** (docs/07 §4.1: *"at rough-in a Cat6 is just a Cat6"*) | **throws** |
| no room | **throws** |

The rough-in drop is not an edge case. `docs/07` §4.1 calls `Service: undetermined` *"a
first-class, encouraged state"* and canon §6.4 gives it a seeded family, so **the default field
label cannot render the state the product most encourages**.

**11.21.2 The rack label needed no ruling and got none.** `{FLOOR}{SPACE}-{PANEL}{PORT:2}` throws
without a `PORT`, and AC-018 puts **fourteen of the sixty** drops on unbound far ends. But
`StructureOrigin.rackLabel` is **optional** (CR-044 above, in its own words: *"`rackLabel`
(optional, project-unique when set)"*), so those fourteen simply have none. Nothing is fabricated
and nothing throws, because nothing renders. This is recorded so the next reader does not go
looking for the ruling that handled it.

**11.21.3 Ruling: `{SERVICE}` is the tag of the `OutletTemplate` the drop was created from.**
Settled by the user on 2026-08-07. It is the only answer that reproduces the corpus's own worked
examples: `LR-TV-1`, `MBR-KEY-2` and `EXT-CAM-4` (docs/07 §5, docs/01 §571) are **TV location**,
**Keypad** and **Camera**, which are three of the six seeded templates docs/07 §4.3 names. They
are not signal families and never were; reading them as families is the misreading this ruling
exists to prevent.

**11.21.4 `OutletTemplate` gains a `tag`, and it is not a migration.** The entity is `{id, name,
drops}` today. `name` is *"TV location"* and a tag derived from it by truncation is a guess printed
on physical cable, so the tag is authored beside the template. **`registries.outletTemplates` is
`{}` in all four shipped starters and in every document ever written** (board #150 asserts it; the
starters were checked). A key added to an entity with zero instances everywhere costs no file a
byte, which is DR-019's argument for `Placement.unknown` applied to a smaller surface.

**This amends board #150**, which says the outlet-template seed is *"data plus a builder, not a
model change"*. It is now a one-field model change plus data plus a builder.

**11.21.5 The two rejected answers, and what each would have cost.** **The signal family's
`shortTag`** needs no model change and gives `LR-STR-1`, because `structure.undetermined.shortTag`
is `STR`. CR-048 evaluates a designator **once at creation and stores it**, so that label never
becomes `LR-NET-1` when a real service is assigned: sixty labels on physical cable that all say the
same word, and the word is the placeholder. **Making the segment optional** in the shipped preset
(`{ROOM_ABBR}-[{SERVICE}-]{SEQ}`) is cheapest, needs nothing new, and edits a CR-044 preset cited in
five documents so that its own examples stop rendering.

**11.21.6 What it does not rule.** Where `{SERVICE}` comes from for a drop created with **no
template at all** (`Attic: 3x Cat6`, docs/07 §4.3's second example). The DSL has an explicit
`@service=` modifier for exactly that, and which of the two wins, and what happens when neither is
supplied, is **M3-C/1's question**, because M3-C/1 is where the entry surface decides what it can
refuse. This ruling settles the SOURCE, not the fallback chain.

**11.21.7 Scope.** **No scope change.** Two tasks inside M3 are resequenced, not added: #152 runs
before #147, because a repeat-entry loop that makes nine drops from one line needs nine labels and
CR-045 forbids building them by concatenation. #150 grows by one model field.

---

### 11.22 DR-023 · The `{SERVICE}` fallback chain, and what a line with no service is called

**Settled by the user on 2026-08-07**, answering the question DR-022 §11.21.6 explicitly left to
M3-C/1 (board #147): *"which of the two wins, and what happens when neither is supplied"*. DR-022
settled the **source**; this settles the **chain**.

**11.22.1 The chain, in order.** `{SERVICE}` resolves from the first of these that is present:

| | Source | Example |
|---|---|---|
| 1 | The line's `@service=` modifier | `Exterior: 6x Cat6 @service=camera` → `EXT-CAM-4` |
| 2 | The `tag` of the `OutletTemplate` the drop's `Outlet` was created from (DR-022) | a *TV location* outlet → `LR-TV-1` |
| 3 | The `shortTag` of the drop's **media type** | `Living Room: 4x Cat6` → `LR-C6-1` |

There is no fourth step and no placeholder. Every step is a fact the person supplied on the line or
stored on the outlet.

**Step 1 resolves THROUGH a template before it falls back to the literal, and the worked example is
why.** `@service=camera` renders `CAM`, not `CAMERA`. The modifier names the same kind of thing
step 2 does, an `OutletTemplate`, and differs only in **how that template is chosen**: typed on this
line rather than carried by the outlet. So the value is looked up against `outletTemplates` by
`tag` first and then by `name`, and what reaches the label is the template's `tag`. Where nothing
is named that, the literal is used, upper-cased: `@service=poe` on a project that authored no
template must still produce a label, and refusing would make the modifier useless until board #150
seeds the six.

**Consequence, recorded rather than left to be discovered:** `registries.outletTemplates` is `{}` in
every document today, so the literal arm is currently the only reachable one and **`EXT-CAM-4` is
not reproducible until #150 lands**. It is a gate in `drop_line_planner_test.dart`, in both
directions, so the day templates are seeded the corpus's own label appears rather than being
noticed.

**11.22.2 Why `@service=` outranks the template, which is step 1 beating step 2.** CR-048 evaluates
a designator **once at creation and stores it**. A label that cannot be overridden at the moment of
entry can only be corrected by deleting the drop and re-entering it, which is the one operation a
sixty-drop drill cannot afford. The modifier is also the more specific statement: it is typed on
*this line*, about *these drops*, where the template is a default carried by the outlet.

**The cost is accepted and named.** A drop can now carry a label that disagrees with its own
outlet's template: six Cat6 on a *TV location* outlet with `@service=camera` are labelled `CAM` and
sit on an outlet called *TV location*. That is a true record of what the installer was told, and
the alternative, silently ignoring a modifier the person typed, is what docs/04 §3.4 forbids
outright.

**11.22.3 Why the media's `shortTag` is step 3, and why this is not the `STR` answer DR-022
rejected.** docs/07 §4.1: *"`Service: undetermined` is a first-class, encouraged state ... At
rough-in a Cat6 is just a Cat6."* A chain that refuses `Living Room: 4x Cat6` refuses the corpus's
own first worked example of the entry surface, and does it at the exact point where friction is
most expensive.

DR-022 §11.21.5 rejected `structure.undetermined.shortTag` and the reason was **not** that a
fallback is wrong. It was that `STR` is a *placeholder word*, identical on every rough-in cable in
the project, stored forever by CR-048: sixty labels that all say the same thing, and the thing they
say is "we do not know". The media tag fails none of that. `C6`, `RG6`, `16/4` and `22/4` **vary
per drop**, they are facts the line actually stated, and `LR-C6-1` is a sentence an installer can
act on with a label printer in one hand.

**What it costs, stated plainly:** `{SERVICE}` now means *what this drop is for* when a template or
modifier says so, and *what this drop is* when neither does. One token, two senses. The alternative
readings each cost more: refusing costs the encouraged state, and a placeholder costs sixty
identical labels on physical cable.

**11.22.4 A media type with no `shortTag` is the one hole, and it refuses.** `shortTag` is nullable
on `MediaTypeDef` (G4, CR-114) and all 38 seeded types carry one, but a **user-created** type from
an RJ-009 CSV import may not. That drop reports `LabelTokensMissing(['SERVICE'])` through M3-D/1's
existing outcome and is refused with a sentence naming the two fixes. It is not defaulted, and it
is not given the raw media id: a label is printed on cable and `media.cat6` is not a label.

**11.22.5 What this does not rule.** Whether `@service=` also sets the drop's `Service.signalFamily`
is **not** settled here and is not the same question. docs/07 §4.1 backs the drop's Service column
with the `structure.undetermined` family and §5.1 maps the CSV `service` column to a
`SignalFamilyId`, while the token this ruling governs is a **label segment**. The two share a word
and are different fields; `@service=camera` names no signal family, because there is none. Drops
created by the loop take `structure.undetermined` until something assigns a real family, which is
§4.1's retroactive-DRC path working as written. **A later ruling may connect them; this one keeps
them apart deliberately, so that the label chain is not blocked on the taxonomy question.**

**11.22.6 Scope.** **No scope change.** No task is added, moved or grown. This is the fallback
policy #147 was told to decide, and #147's own description is unchanged by it.

---

### 11.23 DR-024 · Board #151 is a model field and a picker; its data half already shipped

**Settled by the user on 2026-08-08**, after M3-C/4 (#150) closed at `5abb8b3`. #151 is *"TIA-570-D
presets"*, and #150 shipped the three presets as part of seeding the nine outlet templates. What
was left was neither presets nor data, so the task is re-scoped rather than left to be discovered
half-done.

**11.23.1 What #150 already delivered against #151's own brief.** #151 asked for the grade presets
and gave the reason they are not decoration: *"Grade is a CITATION, not a suggestion: it names a
published standard, so a preset that does not match the standard is a wrong fact in the document
(G4). Transcribe with the source beside it."* `outlet.tia570d_grade1`/`2`/`3` are transcribed from
docs/07 §1's table with that source named in the seed header, **including the part that reads
oddly**: docs/07 gives Grade 3 a lower twisted-pair grade and fewer coax than Grade 2, which is not
how the published standard stacks them, and a silent correction in code would have made the seed
disagree with the document it claims to transcribe. The disagreement is flagged for docs/07 and the
transcription stands.

**11.23.2 The remainder is one model field: `OutletTemplate.tia570Grade: String?`.** CR-108 keeps
`Outlet.tia570Grade` as a **standards tag, never an axis**, and the whole-house fixture sets it by
hand. So a grade preset today cannot stamp the very tag it exists to carry, and the picker has
nothing to copy from.

**The rejected answer is a builder special case on the three seeded ids.** Cheaper, needs no model
change, and keys the behaviour to the strings `outlet.tia570d_grade1..3`. It fails on the property
CR-108 exists to protect: **user-defined templates are first-class**, so a shop that authors its own
Grade 2 preset, or one citing a builder's spec rather than TIA's, could never stamp anything. It
also makes an id rename a silent behaviour change, which is the class of failure a `String?` on the
entity does not have.

**Not a migration, and CR-117 is not at risk.** The key is additive and absent when null, so the six
named templates write no `tia570Grade` and re-encode byte for byte. A document written between
`5abb8b3` and this change carries the three grade entries without the key; reading it yields null,
writing it omits the key, and `write(read(bytes)) == bytes` holds. Only documents created after the
change carry it, which is the same contract `tag` landed on in DR-022 §11.21.4.

**11.23.3 The picker is `+ Add outlet ▾`, and no task claimed it.** docs/07 §4's button bar carries
it and §4.3 says what it does: *"instantiates an `OutletTemplate` in one action, TV location → 2 ×
Cat6 + 2 × RG6 as one `Outlet` with four `Link`s and four label pairs."* #148 is the table's rows
and columns, #149 is the matrix tab; neither description mentions it, and #150 explicitly shipped
the master without a gesture to instantiate it. It goes here, because a preset with no way to place
it is the half of #151 that was never the point.

One `Command`, one undo entry, and it stamps `Outlet.tia570Grade` from the template. It is also
**the first caller of DR-023 step 2**. The chain's middle arm, the outlet's template tag, has had
no way to be reached, because nothing until now creates an outlet *from* a template.

**11.23.4 What this does not rule.** The **library flow** that edits templates. CR-108 makes
user-defined templates first-class and `Registries.outletTemplates` is ordinary editable stored data
after the seed copy (docs/03 §5.6), but which surface edits it is not settled here. Nor is
**AC-034/m24**, *"which location fields the inspector demands is driven by the template"*: a
ceiling speaker pair asking for `mountSurface: ceiling` and never a wall compass direction. That
needs a second model field and a UI contract, and adding it to this task would make the same mistake
this ruling is correcting.

**11.23.5 Scope.** **No scope change to roadmap §2.** #151 is narrowed in one direction, its data
half is delivered, and named in the other, it acquires a gesture no task claimed. The task count is
unchanged and no milestone moves.

### 11.24 DR-025 · `@service=` names the label, `@signal=` names the family; they are two words

**Settled by the user on 2026-08-09**, answering the question board #587 raised while M3-C/3 (#149)
closed. The finding was that a structured run's `Service.signalFamily` is `structure.undetermined`
forever and **no gesture in the product can change it**: `buildAddHomeRunCommand` hardcodes it,
nothing writes it afterwards, and docs/07 §4's own wireframe draws a SERVICE column of values no
gesture can produce.

The ruling is not about the starting value, which is right and unchanged. It is about which word
sets the family, because the corpus points two ways: docs/07 §5.1's import table maps a `service`
column to **`SignalFamilyId`**, while DR-023 §11.22 resolves `@service=` through an `OutletTemplate`
by tag then by name, making its value a template handle.

**Ruling: they are two different facts and they get two different words.** `@service=` is unchanged
and DR-023 stands entirely; a new `@signal=` names the signal family.

**11.24.1 The user's own evidence, which is what decides it.** *"We often have situations where we
use one AVoIP system for most areas, but use a simple HDBT transmitter/receiver pair for say,
running from an AVR to a projector."*

Both families ship and are deliberately separate: `video.avoip` (*AV-over-IP, SDVoE / JPEG XS /
NDI*, `conn.rj45`, **star**) and `video.hdbaset` (*HDBaseT 5Play*, `conn.rj45`, **point-to-point**).
Same domain, same connector, same Cat6 in the wall. So one house has runs that are **the same label
and different families**, and three AVoIP drops to a TV, a projector and a display are **the same
family and different labels**. One word cannot carry both without being wrong in one direction on
every job that mixes the two, which the user reports is the ordinary case rather than the exotic
one.

**11.24.2 The decisive form of the argument: a naming decision must not be able to switch off a
safety check.** `seed_registries.dart` on `video.hdbaset`, quoted rather than paraphrased because
it is the reason this ruling has consequences beyond tidiness:

> `acceptedFamilies` deliberately EXCLUDES `net.ethernet` — patching an HDBaseT output into a
> switch does not work and its 100 W PoH can damage the switch. That check (`SIG-001`) is the
> highest-value validation in the product and is only expressible because this is its own family.

If `{SERVICE}` set the family, then choosing a label would decide whether SIG-001 fires. A label is
a naming decision governed by CR-045 and CR-048 and stored once at creation; a family is an
electrical fact the DRC reads. Letting the first drive the second is how a rule stops meaning
anything.

**11.24.3 The modifier is `@signal=`**, chosen because docs/07 §5.1 already lists `signal` as an
accepted header for exactly this column, so the DSL and the importer share one word rather than
acquiring a third. It resolves against `registries.signalFamilies` by `shortTag`, then the id's own
tail, then `displayName`, which is `resolveMediaToken`'s widest-last shape: `@signal=hbt`,
`@signal=hdbaset` and `@signal=avoip` all land.

**An unresolved value REFUSES**, and does not create a family. This is the opposite of RJ-012's rule
for media and the difference is already ruled: docs/07 §3 says *"Media types are user-extensible in
v1 … Signal families and connector types remain catalog-updated."* A family invented from a typo
would be a family with no domain, no colour, no dash and no `acceptedFamilies`, which is a run the
DRC and the palette both cannot reason about.

**11.24.4 A CSV `Use` column feeds the label chain and never the family.** Real pull lists put `TV`,
`Data`, `Camera`, `Speaker` in that column, which name templates rather than families, and DR-023's
chain already resolves exactly those. The family is stated deliberately or not at all: from
`@signal=`, from the editor's SERVICE column, or from a CSV column that maps to `signal`.

**docs/07 §5.1's table is owed the edit**, and it is the only derived-document change this ruling
forces: the row reading `service` → `SignalFamilyId` with headers `service, use, purpose, signal,
function, application` splits, with `signal` going to the family and the rest to the label. The
accepted cost is that importing a list whose `Use` column says `HDBaseT` leaves those runs
undetermined; the alternative is a spreadsheet word silently setting the fact SIG-001 reads.

**11.24.5 The default is unchanged and is not what this ruling touches.** A drop is created
`structure.undetermined` (docs/07 §4.1: *"at rough-in a Cat6 is just a Cat6"*), an
`OutletTemplate`'s `OutletDrop.service` stays intent and is still never copied onto the `Link`, and
a line with no `@signal=` sets no family. What changes is that §4.1's second clause becomes
reachable: *"the DRC validates RETROACTIVELY when a `Service` later assigns a real family."*

**11.24.6 One implementation fact the task must not miss: the family is stored TWICE.**
`buildAddHomeRunCommand` writes it to `Service.signalFamily` and to `Net.signalFamily`. Today only
the first is consumed, and docs/05 §5 is explicit that colour *"resolves from `Service.signalFamily`,
never from the `Link`"*; `Net.signalFamily` is written once, serialised, and read by nothing but the
codec. A command that sets one and not the other leaves the file carrying two answers to one
question, in the one place nothing would notice, which is CR-107's failure in miniature. Both are
written or neither is.

**11.24.7 Scope.** **No scope change to roadmap §2.** docs/07 §4.1 already promises the capability
and §4's wireframe already draws it; no task was ever cut for it, so #587 is a decomposition gap
rather than an amendment. **M3-F is unblocked by this ruling**: #159 could not be written while a
contractor's `Use` column had two possible targets.

### 11.25 DR-026 · Two M3 answers taken as interim positions, because the Plan view may move them

**Settled by the user on 2026-08-09**, answering board #157 and #153 together. Both are questions
M3 cannot avoid and neither is safe to answer permanently: DR-018 moved the Plan view into v1.1,
and a floorplan speaks to both. The ruling is therefore two positions **chosen for reversibility**,
and reversibility is the criterion here rather than a caveat attached to one.

**11.25.1 `Pathway.designator` exists and is MANUALLY ENTERED (#157).** The user's reason: *"once a
trunk line is established in the home, it would be nice to know exactly where it is relative to the
plans."*

**This is DR-020's own distinction applied to pathways.** §11.19.1 ruled that *"the route is
discovered, not designed"* and voided a design-time polyline for storing a guess wearing the
authority of a measurement. A trunk that **has been established** is the opposite case: it is an
as-built fact somebody walked, and recording where it is takes nothing on trust. A designator a
person types is a record; one generated before anybody has opened a ceiling would be the voided
polyline in a shorter form.

So: `String? designator`, null is unknown (G4, CR-114), **no allocator, no series, no format
token**.

**Manual is the reversible direction and generated is not**, which is the whole of why it wins. A
nullable hand-entered string can later gain an allocator that fills the absent ones, without
changing the field, the file or the column. An allocated series cannot become manual mid-project
without abandoning the uniqueness its allocator assumed. #157 asked which of three to build; the
user asked for whichever is easy to change later, and only one of them is.

**Unique where set, project-wide**, on CR-113's `rackLabel` precedent: two trunks called `T1` on one
Pull Sheet is the defect the column exists to prevent, and null is not a collision.

**#157's own cost estimate is over-stated, and this ruling does not incur it.** The task reads
*"adding one changes stored state (CR-117's byte gate, `kSchemaVersion`)"*. A nullable key written
only when present does neither: every file already on disk re-encodes byte for byte and the schema
version does not move. That is `tia570Grade`'s precedent (DR-024) and `MediaTypeDef.aliases`'s
before it.

**`Pathway.name` IS NOT OVERLOADED, and the finding is stated because it makes #157's third option
look cheaper than it is.** The field exists, its own doc comment gives `"B03"` as the example, which
is designator-shaped, and docs/07 §4's wireframe prints `PW-LR-1` in the PATHWAY column. The
temptation is therefore to print the name and add nothing. Refused: every other entity in this model
carries a human name and a short identifier separately (`DeviceInstance`, `Rack`), and a trunk
called *"attic run to the garage"* and one called `PW-LR-1` are two facts. Overloading them makes
the Pull Sheet column print whichever one a person happened to type.

**11.25.2 `Outlet.nominalRunLength` is RATIFIED AS IMPLEMENTED, provisionally (#153).** The task
says *"RATIFY OR OVERRULE ITS PLACEMENT before anything reads it"*. **That deadline has passed**,
and the task must not be picked up and priced as preventive. `ScheduleLengthSource` already ships
four tiers, `cut | outletNominal | roomEstimate | none`, with the second one's own doc comment
declaring itself *"a DELIBERATE addition, stated here rather than buried"*;
`OutletField.nominalRunLength` is Command-backed; and `whole_house` populates it on **all seventeen**
outlets while setting `cutLength` on **none**. The choice was made and shipped at M2-B, and the
corpus's own fixture depends on it.

The tier therefore stands as written: more specific than the room estimate, less authoritative than
a cut length, printed as an estimate and never as a measurement.

**It is provisional and the Plan view is the named trigger.** Whether a floorplan supersedes any of
the four tiers is open, is not ruled here, and is owed when DR-018's condition resolves.

**11.25.1a BUILT, at M3-E/2 (#157), 2026-08-10.** `Pathway.designator` ships exactly as ruled: a
nullable hand-entered string, no allocator, no series, no format token. **The ruling's own cost
finding held against the encoder**: the key is written only when present, so the checked-in fixture
corpus is byte-unchanged and `kSchemaVersion` did not move, refuting #157's description, which had
priced a schema bump and a fourth designator series. Uniqueness where set is enforced by
`buildSetPathwayDesignator`, a **refusing** builder on `buildSetStructureOriginProperty`'s shape
(M3-A/8), because the field table's `set` writes and cannot decline; **null is not a collision**, so
clearing is always legal and any number of trunks may carry none.

**Two consequences the ruling did not name, both settled at DR-037's UI/UX pass.** docs/08 §3.2
column 9 always specified `Pathway.designator` while `ScheduleEntry.pathwayName` read `Pathway.name`
and **said so in its own doc comment**; the column now prints the designator and **falls back to the
name**, with `pathwayLabelIsDesignator` telling the sheet which it got so the font can distinguish an
identifier from prose. *That fallback is not the overload §11.25.1 refused*: the refusal was about
**storing** two facts in one field, and both are stored separately here. The Pull Sheet's pathway
grouping and its sort follow the same resolved value, because a band headed `T1` over rows printing a
description is a sheet contradicting itself.

**11.25.3 Scope.** **No scope change to roadmap §2.** #157 gains a nullable field and no series;
#153 ratifies behaviour that already ships. Neither adds a milestone item. M3-E/2 and M3-D/2 are
unblocked.

### 11.26 DR-027 · M3 owes the Pull Sheet's rows and its sort; M6 owns every rendered sheet

**Settled by the user on 2026-08-09**, ratifying the seam board #155 proposed: *"M6 is where sheets
are going to be rendered and I'd like to work those issues out all at once."*

**11.26.1 The tension it resolves.** `SheetRole` has three values, `rackElevationFront`,
`rackElevationRear` and `equipmentList`; there is no Pull Sheet and no Termination Schedule in the
exporter. M3's exit criterion nonetheless says a rough-in *"exports a Pull Sheet sorted by room and
pathway with per-room footage subtotals and initial boxes"*. One of the two has to give.

**11.26.2 The ruling.** M3 owes the **derivation**: the rows, the sort by room then pathway, and the
per-room footage subtotals, as tested output of `rackmate_core`. M6 owes the **sheet**: the
`SheetRole`, the layout, the initial boxes and the page.

**11.26.3 It amends an exit criterion, which is why it is a ruling and not a note.** §8.1 makes the
exit criterion the unit of truth, so moving a clause across a milestone boundary is an amendment
under §8.3. **M3's clause 3 is amended**: M3 demonstrates the rows, the sort and the subtotals, and
**M6 demonstrates the export**. M3 cannot discharge a clause about a sheet it does not own, and
reading that clause loosely enough to call it met would be precisely the checklist-ticking §8.1
refuses. M6's criterion needs no addition: *"all four starter projects export a complete set"*
already contains the sheet.

**It tidies a second clause rather than creating one.** Board #574 already parks AC-018's PRINTS
clause on M6 for the identical reason: *"there is no Pull Sheet and no Termination Schedule in the
exporter at all, so there is no sheet for an unbound run to print on."* One seam, two clauses, now
stated once instead of discovered twice.

**11.26.4 What M3 still owes, so this is not read as a deferral.** The derivation is the
load-bearing half and it stays in M3: sorted rows, per-room subtotals, and the unknown counts G4
requires of every rollup. A milestone that shipped an unordered, untotalled data structure would
hand M6 the design work along with the rendering, and the seam would have become an excuse.

**11.26.5 Scope.** **A milestone-boundary amendment; no change to roadmap §2's contents.** Nothing
leaves v1 and nothing joins it. One clause moves from M3's criterion to M6's. M3-D/4 is unblocked.

### 11.27 DR-028 · The keystone occupant cell is the FRONT NOSE, 14.5 mm × 16 mm

**Settled by the user on 2026-08-09**, supplying the figure DR-007 does not give and board #167
refuses to infer. **Corrected by the user the same day**, and the correction is kept in full below
because what it caught is worth more than the figure.

**11.27.1 The figure.** A cell is **14.5 mm wide by 16 mm tall**, and it is the **front nose** of the
keystone: the visible bezel face, not the body, the latch or the depth behind the plate.

**THE NOSE IS THE ONLY DIMENSION THIS PRODUCT NEEDS, and §11.7.9 B is why.** That entry rules that
*"the cell renders from the front, and the front hides the differences"*: a keystone is drawn
face-on in a plate elevation, where a punchdown jack and an inline coupler are the same object, a
coloured bezel with a connector opening. So the face is what the renderer draws and the face is what
gets stored. Nothing in v1 draws a plate in section.

**11.27.2 THE FIRST DRAFT OF THIS RULING WAS WRONG, AND IT OVERRULED A FIGURE THAT WAS RIGHT.** It
recorded **15 × 16** from *"standard for 110 Keystones is 16mm tall, but width can vary. 15mm is
right in the middle of the range"*, treated the width as a stated choice at the centre of a range,
and on that basis **superseded §11.7.8's parenthetical** *"a standard keystone is about 14.5 × 16.0
mm"*. The user then corrected their own figure: *"the front nose of each keystone is 14.5 mm wide by
16 mm tall. My own research was incorrect."*

**That supersession is withdrawn.** §11.7.8's number was right, was arrived at independently, and
now corroborates rather than conflicts. The arithmetic it was written to support is DR-007's
original: 2 × 14.5 = 29 mm across a Decora opening of about 33.3, and 3 × 16 = 48 mm down about
66.7.

**The lesson, which this record exists to keep.** A figure carried as an unruled *"about"* inside an
arithmetic check survived contact with reality, and a figure elevated to a ruling did not. The
supersession was written on the reasoning that *"this ruling's is the one to build from, because it
is the one a person stated deliberately"*, and deliberateness turned out to be the wrong test:
the earlier number had a source and the later one had a recollection. **An unruled figure with
provenance outranks a ruled figure without one**, and the corpus should not have been edited to
agree with the newer of two numbers merely because it was newer.

**11.27.3 The provenance, stated at its real strength.** The width is no longer a choice at the
centre of a range; it is the dimension of a standard part, stated by the user and independently
matching §11.7.8. It is **not yet physically confirmed**: the user is seeking manufacturer CAD for
the brand in use and will otherwise measure one against a rule. That confirmation is welcome and is
not a blocker, because two independent statements now agree.

**11.27.4 WHAT THIS DOES NOT SETTLE, and it must not be read as settling it.** §11.7.8's **change 3
remains open**: whether a cell on a 2-wide strap is the same size as a cell on a 1-wide strap. That
is a question about two parts, not about one figure, and DR-007 requires it be *measured rather than
inferred* **before any dimensioned rendering**, because a uniform-cell assumption that turns out
false is wrong on every plate drawing at once. Supplying one cell size does not answer it, and a
reader who takes this ruling as licence to assume uniformity has made exactly the inference §11.7.8
forbids.

> **ANSWERED by DR-038 (§11.37) on 2026-08-10, by measurement rather than by inference.** The cells
> are identical across strap widths, so this figure now describes every cell on every strap. **This
> clause was right to refuse the inference and is not weakened by the answer agreeing with it**: the
> reasoning available in advance (a cell must fit the nose) established only a lower bound, and a
> roomier 1-wide opening would have satisfied it while breaking every plate drawing.

**11.27.5 Stored as `Len` in nanometres (CR-001).** 14.5 mm is `14_500_000` nm and 16 mm is
`16_000_000` nm. No floating-point millimetres, in the model or in any file format.

**A HALF-MILLIMETRE IS WHY THE UNIT IS NANOMETRES**, and this is the first place in the corpus where
that pays visibly rather than in principle. `14.5` is exact as an integer count of nanometres and is
a binary fraction as a count of millimetres; CR-001 chose int64 nanometres precisely so a dimension
like this needs no `double` anywhere between the ruling and the rendered plate.

**11.27.6 One cell size is the entire geometry, and that is DR-007's doing.** §11.7.2, revised
2026-07-28, makes **every occupant 1 × 1**, a speaker binding post included, so a strap is a grid of
equal cells and the only questions left are plate sizes, orientation and which cells are filled. Had
occupants stayed multi-cell, this ruling would have owed a size per occupant kind and would have got
one of them wrong.

**11.27.7 Scope.** **No scope change.** DR-007 already placed keystone geometry in M3; this supplies
one figure it left open. M3-H/2 is unblocked.

### 11.28 DR-029 · The Plan view ships in v1, before M6, with PDF rasterisation

**Settled by the user on 2026-08-09.** A **scope amendment under roadmap §8.3**, and the first one
that makes v1 larger rather than smaller or merely rearranged. The user's reason: *"development has
been exceptionally fast and I feel like it's an important feature to have."*

**11.28.1 The ruling.** The Plan view leaves roadmap §2.2 and joins **§2.1**. It is **v1**. It is
sequenced to be **finished before M6**, it ships **with PDF rasterisation**, and it gets **its own
board epic rather than a milestone number**.

**11.28.2 What of DR-018 this supersedes, listed one by one so nothing is left half-true.**

| DR-018 said | Now |
|---|---|
| §11.17.2(1) the Plan view is **v1.1** | **Superseded.** It is v1. |
| §11.17.2(2) the placement is **conditional** on the underlay carrier shipping in v1 | **Moot.** DR-019 answered the carrier and roadmap §2.2 already recorded the condition as discharged. |
| §11.17.2(3) *"Nothing is added to v1 by this ruling"* | **Superseded.** This ruling adds it. |
| §11.17.6 *"This does not enter §12.7's totals"* | **Superseded.** It does, and §12.7 is re-costed below. |
| §11.17.7 *"Nothing is scheduled. No board item."* | **Superseded.** An epic exists. |
| §11.17.2(5) reevaluation **by condition, not by date** | **Discharged.** The reevaluation happened, and this is its outcome. |
| §11.17.2(4) *"The Plan view does not displace M3"* | **Reaffirmed, unchanged.** It is a better front end for what M3 builds and is not a substitute for it. **No M3 task is cut by this ruling**, and `T6.10` remains the answer to the motivating problem. |

**11.28.3 BEFORE M6 IS NOT A PREFERENCE, IT IS THE ONLY ORDERING THAT DOES NOT MAKE M6 RUN TWICE.**
Roadmap §2.2 describes the feature as including *"a plan sheet in the set"*, and M6's exit criterion
is that **all four starter projects export a complete set**. A Plan view landing after M6 would
have M6 declared met over a sheet set that is about to gain a sheet, so M6's criterion would have to
be re-demonstrated against a different set. The user's instinct is therefore structurally right and
is recorded as an argument rather than as a scheduling wish.

The same seam is already carrying weight in that direction. **DR-027 put the Pull Sheet's rendering
in M6 this same day**, and board #574 parks AC-018's PRINTS clause there. M6 is the milestone where
sheets become real, and everything that owes it a sheet must precede it.

**11.28.4 It gets an epic, NOT a milestone number, and the reason is the corpus rather than taste.**
Renumbering M6→M7→M8→M9→M10 would rewrite every `M6-A1`-shaped task title, docs/12 §5.3–§5.8's
headers, §12.7's table, and dozens of references across canon and the roadmap including AC-058's
print matrix and #574. The board already carries **two non-numbered v1 epics** for exactly this
reason, `macOS support ships in v1 (DR-009)` and the Store epic, so the precedent is the project's
own. **The sequencing constraint is a stated dependency, not a number.**

**11.28.5 It ships WITH PDF rasterisation, which is a deliberate purchase of 2–3 weeks.** Floor
plans arrive from architects as PDF, and a raster-only import would put a conversion step between
the user and the feature on the ordinary path rather than the exceptional one. DR-018 §11.17.6
costs the levels: 5–7 weeks minimum viable, 7–10 raster-only, **9–13 with PDF rasterisation on both
platforms**. The last is chosen.

**`docs/13` GAINS AN ENTRY, and DR-018 §11.17.4 predicted this exact one**: *"`docs/13` gains an
entry if the chosen import path is a Windows-only rasterizer, because DR-009 puts macOS in v1."* It
does. The likely rasteriser is **pdfium**, which the debt register is already discussing for a
different reason at D9 (*"if printing is adopted, vendor pdfium per platform (CR-100)"*), so the two
should be costed together rather than twice.

**11.28.6 `DiagramCanvas` GAINS A `drawImage` OP IN V1, and this is the ruling that does it.** §12's
RJ-017 row currently reads *"`DiagramCanvas` still gains no `drawImage` by any ruling to date.
docs/15 §7 records that adding one is part of building the Plan view and names what it touches."*
That sentence stops being true here. `draw/canvas.dart`'s own amendment clause governs the addition,
and docs/15 §7 is the existing account of what it costs.

**One consequence that is NOT ruled here and must not be inferred.** RJ-017 rejected the
integrator's logo in the title block partly because *"it requires a raster asset inside the project,
which reopens the container question that AC-057 just closed by cutting images"*. DR-019 answered
the container question and this ruling ships raster handling, so **that particular ground is gone**
and the logo would now be cheap. It still does not ship: RJ-017 is not reversed by a ruling that
never considered it, and anyone who wants it should ask for it directly rather than collect it as a
side effect.

**11.28.7 What does not change.** **G4 is untouched**: a plan yields a measured horizontal distance,
**never a route**, and DR-020's *"the route is discovered, not designed"* stands in full. A
plan-derived length remains an estimate under AC-024 unless a human marks it measured, and AC-024's
per-room number remains the source that ships. **Mobile editing stays v2** (AC-056): the feasibility
study §7 records that the motivating workflow is a tablet one and **that this feature does not reach
it**, which is worth restating now that it is v1, because shipping it will not by itself put a plan
in a technician's hands on site.

**11.28.8 Two provisional M3 positions now have a scheduled trigger rather than a hypothetical one.**
DR-026 §11.25.1 (`Pathway.designator` hand-entered) and §11.25.2 (`Outlet.nominalRunLength` ratified
as implemented) both name the Plan view as the condition on which they are revisited. This morning
that was an open-ended "if"; it is now an epic sequenced before M6. **Both must be re-read when this
epic is decomposed**, and the decomposition task carries that instruction.

**11.28.9 The plan, re-costed.** The Plan view is `L` at **9–13 weeks**, placed between M5 and M6;
the ruling constrains only its relationship to M6. §12.7's table gains a row and its totals move
from 44–67 weeks to **53–80 weeks**. **M1, M4 and the Plan view are now the three `L` items**, where
§12.7 previously named two.

**11.28.10 Scope.** **v1 grows by one item and 9–13 weeks.** Roadmap §2.1 gains a subsystem
paragraph and §2.2 loses its row. **The milestone's contents and its exit criterion are owed at
decomposition**, not here: this ruling settles that it ships, when, and how much of it, and the
first task of the epic is to decompose it (the rule M3-0 established).

**11.28.11 Four derived sentences this ruling falsified, corrected the same day and listed because
the first pass missed them.** DR-029 named the `drawImage` op and stopped there, which was
incomplete in a way worth recording: a ruling that adds a raster to an exported sheet falsifies
every claim the export document makes about being vector-only, and those claims were three
paragraphs apart in one file.

| Sentence | Where | Now |
|---|---|---|
| *"The exported document is therefore 100% vector with no raster path and no alpha path at all."* | docs/08 §6.2 | **False.** `T1.01` prints a screened underlay. There is a raster path; the no-alpha property survives separately. |
| Backend table row 17, *"Images: **Not in v1.**"* | docs/08 | **False.** Two consumers: the underlay, and DR-030's logo. |
| *"There is no logo."* | docs/08 §5, the title block | **False as of DR-030.** |
| *"PDF is not read. The user exports a page to an image first."* | docs/15 §2 | **False.** DR-029 buys that increment. |

**AND ONE LIVE QUESTION THE PLAN VIEW EPIC MUST SETTLE BEFORE `T1.01` RENDERS.** docs/08 row 9
forbids alpha *"absolutely, with no exception"*, and docs/15 calls the underlay **screened**.
Screening by per-image alpha would emit the first `ExtGState` this document has ever carried and
break that rule. **The underlay must be pre-composited at import**, the way palette tints already
are at 18 % over white, and #589 carries it.

**11.28.12 One cost that is smaller than it looks.** docs/15 predicted that PDF import *"changes no
stored format"*, and the prediction holds exactly: a PDF is rasterised **at import** and the member
written to the zip is still PNG or JPEG, so `PlanUnderlay.format` keeps its two values and
`rackmate_core` still needs no image decoder. What is bought is an import path and a `docs/13`
entry, not a model change.

### 11.29 DR-030 · The integrator's logo ships in v1, in M6, without its opacity

**Settled by the user on 2026-08-09:** *"Let's add the logo in; likely during M6. If it's cheap we
may as well."*

**11.29.1 What it reverses, and what it leaves standing.** RJ-017 accepted
`critique-completeness.md` D9 *"except for the last clause"* and rejected the integrator's logo for
v1 on three grounds:

| RJ-017's ground | Status |
|---|---|
| It requires a raster asset inside the project, *"which reopens the container question that AC-057 just closed by cutting images"* | **Gone.** DR-019 settled the container and DR-029 builds it. |
| *"The logo lands with the v2 zip container, alongside device images"* | **Arrived early.** DR-029 brings the carrier into v1. |
| *"The title block's **text** integrator block ships in v1 and carries the same information"* | **STANDS, and is not overturned.** The logo is added **beside** the text, never instead of it. |

The third ground is the one that survives contact, and it is why this ruling adds rather than
replaces: a photocopy at third generation still carries the firm, the contact and the licence
number, and it may well not carry a logo.

**11.29.2 Why it is cheap, as arithmetic rather than as an impression.** The logo is the **fourth
consumer of three things already being built**: DR-019's zip container, DR-029's `drawImage` op on
`DiagramCanvas`, and DR-029's raster embedding in the PDF backend for `T1.01`. On its own account it
adds a model field, a fit rule and a print check. **If the Plan view slips out of v1, this slips
with it**, because every one of those three is DR-029's.

**11.29.3 THE OPACITY DOES NOT COME BACK, and that is this ruling's one real constraint.** docs/08
row 9 forbids alpha *"absolutely, with no exception"* and records that the sole former exception was
the logo-opacity path, *"gone with the logo"*. **The logo returns at full opacity.** No `ExtGState`
is emitted, `setGraphicState` is never called, and an invariant that was written around this
feature's absence survives its return. A user who wants a faded logo supplies a faded PNG, which
moves the compositing to import where the underlay's is going too.

**11.29.4 It lands in M6, and the ordering already works without a new constraint.** #341 (M6-G) is
sheet furniture in full and #343 (M6-G2) is the title block. DR-029 puts the Plan view before M6, so
the container, the canvas op and the PDF raster path all exist by the time M6-G runs. Nothing needs
sequencing beyond what DR-029 already fixed.

**11.29.5 What it owes on its own account**, so decomposition does not discover it: a model field
mirroring `PlanUnderlay`'s shape (member path, format, pixel dimensions so layout needs no decode,
`contentHash` as a warning and never a load failure, AC-042); a **fit rule**, because title-block
real estate is fixed and a logo's aspect is arbitrary, so fit-inside with aspect preserved and never
stretched; **import hardening** on M4-M4's rule that every import path carries limits, meaning a
format allowlist and byte-size and pixel-dimension caps; and a place in **the print matrix** (AC-058
D13, #360), because a logo that smears to black on a greyscale laser is a defect the vector sheets
could not previously have. Stored bytes go in verbatim, so M6-I5's byte-determinism assertion is
unaffected.

**11.29.6 What it does not do.** It does not return **device images**: AC-057 cut those on a
separate argument about file size and the 3–6× budget, and nothing here touches it. It does not add
alpha. It does not make a logo **required**: absent is the ordinary case, and G4's
absent-key-is-unknown applies to a firm that has no logo or does not want one on the sheet.

**11.29.7 Scope.** **v1 grows by one small item inside M6.** No milestone moves and **§12.7 is not
re-costed**: the addition is days against M6's 5–7 weeks. That is a judgement rather than a
measurement, and it is recorded as one: if decomposition finds otherwise, M6's row moves and this
paragraph is what it will be checked against.

---

### 11.30 DR-031 · `PathwayKind` gains `attic` and `crawlspace`; the discharge of DR-020 §11.19.4

**Settled by the user on 2026-08-09**, at the moment DR-020 named. §11.19.4 left one question open
and dated it: *"Whether `PathwayKind` gains `attic` and `crawlspace` … **Owed at M3**, when
`Pathway` gets its editor."* M3-E is that editor and this is the discharge.

**11.30.1 The ruling.** `PathwayKind` becomes **nine values**: `conduit | jhook | tray |
plenumSpace | riser | directBury | exterior | attic | crawlspace`.

**11.30.2 The tension §11.19.4 named, and why it resolves this way.** The objection is that both are
*spaces*, and the location tree already models spaces. It does, and that is not the same fact.
**`Location` models where a room IS; `Pathway.kind` models what a cable PASSES THROUGH.** A run from
the rack to a bedroom crosses an attic that is nobody's room, belongs to no room's subtree, and
would have to be invented as a `Location` purely to be pointed at. `fromLocationId` and
`toLocationId` are the pathway's **endpoints**, so a space in the middle has no field to live in.

**What the field is for is the CONSEQUENCE**, which is what makes this the same kind of value as
`plenumSpace` rather than a taxonomy exercise. `plenumSpace` earns its place because it carries a
code consequence (NEC 800.154, `CODE-002`). The two added here carry consequences an integrator acts
on with the same seriousness:

| Value | What it obliges |
|---|---|
| `attic` | Temperature derating, and rodent exposure |
| `crawlspace` | Moisture, and vermin |

**11.30.3 It is deliberately not a rule, and M5 is unaffected.** This ruling adds two enum values
and **no validation**. The v1 catalogue stays at **28 rules** (DR-020 §11.19.2(4)); nothing here
adds a 29th, and no existing rule changes its reading. `CODE-001` and `CODE-002` are M5's and are
written against `containsLineVoltage` and `plenumSpace` exactly as before. **A `attic` run is not
an error and must never become one**: G2 requires the document be able to represent the world as
found, and an attic run is the ordinary case in a retrofit rather than a defect.

**11.30.4 The cost, stated because it is the reason this was cheap to settle now rather than
later.** `PathwayKind` is **not seeded catalog data**: it is a Dart enum serialised by name, with no
registry row, no `sources.md` entry and no palette. Two values cost two enum members, two picker
entries and two label strings.

**Settling it BEFORE the editor ships is the whole point of the timing.** The field serialises by
name, so values added after documents exist are readable going forward but leave earlier documents
having recorded `conduit` for a run somebody would now call `attic`. DR-020 deferred this to *"when
`Pathway` gets its editor"* precisely so the enum would be complete on the day the first gesture
could write it, and no document would carry a value chosen from a short list.

**11.30.5 What it does not rule.** It does not say a pathway's kind is **required**; the field keeps
its `conduit` default and nothing refuses a run whose kind nobody has set. It does not add
`Location` kinds for attic or crawlspace, which remains available if a project genuinely wants an
attic as a place rather than as a route. And it does not touch the remaining open half of §11.19.4,
which is AC-040's deferral of ~40 length rules to v1.2.

**11.30.6 Scope.** **No scope change to roadmap §2.** No feature joins or leaves v1, no milestone
moves, and §12.7 is not re-costed. **DR-020 §11.19.4's first clause is discharged** and should be
read with this section beside it. **M3-E/1 is unblocked.**

---

### 11.31 DR-032 · A pathway-only medium creates a `Pathway` named for where it goes

**Settled by the user on 2026-08-09.** CR-109 rules that a medium with `isPathwayOnly` creates a
`Pathway`, *"never a `Link` and never a `Port`"*. It does not say what the `Pathway` is **called**,
and `Pathway.name` is required. This supplies that, the way DR-028 supplied the figure DR-007 left
open.

**11.31.1 The ruling.** An entry surface meeting a pathway-only medium creates a `Pathway`
**per unit of the count**, each **named from the location and the medium as the user typed them**:
`Living Room: 1x ENT` produces a pathway named **`Living Room ENT`**. `kind` takes its `conduit`
default and **`designator` stays null**.

**The count is real and is not a quantity field.** `2x ENT` is two smurf tubes, and a `Pathway` has
no quantity: two runs are two entities, exactly as two Cat6 drops are two `Link`s. **Where the count
exceeds one the names carry a 1-based index** (`Living Room ENT 1`, `Living Room ENT 2`), for
§11.31.3's reason applied within a single line rather than across two rooms: identical `PATH` cells
defeat the column. **The index is part of a description and is not a series** — it says *"the second
ENT to the Living Room"* and it restarts per line, where `PW-LR-1` would be a document-wide
allocation. A count of one takes no index, because there is nothing to distinguish it from.

*This paragraph corrects this ruling's own first draft*, which said *"one `Pathway` per item"* and
was written from a worked example whose count was one. It is corrected before any code reads it,
and the wrong phrasing is quoted here rather than replaced silently, which is the same discipline
§11.27.2 applied to DR-028's withdrawn figure.

**11.31.2 Why a DESCRIPTION and not a derived identifier, which is the whole ruling.** The tempting
answer is `PW-LR-1`: it matches docs/07 §4's wireframe, it sorts, and it looks like every other
short identifier in the product. **It is the thing DR-026 §11.25.1 refused.** That ruling made
`Pathway.designator` hand-entered with *"no allocator and no series"*, because a trunk already
established is an as-built fact and manual is the reversible direction: a nullable hand-entered
string can later gain an allocator, and an allocated series cannot become manual without abandoning
the uniqueness it assumed. A name minted `PW-LR-1` at creation time would be that series, wearing
the one field DR-026 deliberately left alone.

A description cannot be mistaken for an identifier, so the two facts stay two facts, which is
§11.25.1's other holding: *"a trunk called 'attic run to the garage' and one called `PW-LR-1` are
two facts"*.

**11.31.3 The rejected alternative, and the column it breaks.** Naming the pathway after the medium
alone (`ENT`) is simpler and is honest that nobody has named it. It fails on the Pull Sheet: two
conduits to two rooms would print the identical `PATH` cell, and telling one run's route from
another's **is that column's entire job** (docs/08 §3.2). The location is what makes the name
distinguishing, and it costs nothing because the user has already typed it.

**11.31.4 The designator stays null, and that is the as-built half.** Nothing allocates it and no
gesture here sets it. It is filled in when somebody has walked the run, which is DR-020 §11.19.1's
*"the route is discovered, not designed"* applied to the identifier. The user's stated expectation
on the same day, recorded because it shapes where the gesture eventually lives: *"Pathway will
likely be set in the plan view, once a pathway is actually determined and set on site."*

**11.31.5 Which surfaces do this.** All three that resolve a media token: docs/07 §4.3's drop-line
DSL, §4.2's matrix column, and §5.1's CSV importer. The corpus names the last two explicitly
(§4.2's tinted `EMT` column, §5.2's worked row *"the last row's `isPathwayOnly` media creates a
`Pathway`, not a drop"*) and is silent on the first only because §4.3's examples happen to use
cable. **One medium must not mean two things depending on which box a person typed it into**, which
is the failure `structure_matrix.dart` already records as its reason for being a projection of the
table rather than a second derivation.

**11.31.6 What it does not rule.** It does not make a pathway REQUIRED for anything, and it does not
set `containsLineVoltage`, which nobody has stated by typing a medium. It does not touch the Σ drop
count, whose exclusion docs/07 §4.2 already states. And it does not settle whether the Plan view
**owns** pathway creation rather than merely offering it; that is a bigger question and is not asked
here.

**11.31.7 Scope.** **No scope change to roadmap §2.** CR-109 is implemented rather than amended, and
no milestone moves. **Note it is a behaviour change to a shipped gesture**: a drop line reading
`Office: 1x ENT` made a `Link` until this ruling and makes a `Pathway` after it. Nothing has
shipped to a user, so no document carries the old shape.

---

### 11.32 DR-033 · The community catalog is a second repository, and the app opens the pull request itself

**Settled by the user on 2026-08-09.** §10.9 ruled what the **shipped** catalog contains and left
sharing at DR-015's `.rmda`, which is a file you email to somebody. Its recommendation went further
and was never ruled: *"(b), with (c) as the mechanism: a curated community library where every
submission carries the same `sources.md` citation the shipped catalog requires."* This rules it, and
names the surface that makes it happen: a submit action in the Device Builder that opens a pull
request against a separate catalog repository.

**11.32.1 The ruling, in seven clauses.**

1. **A second repository holds the community library**, one `.rmdx` per device. It is **not**
   `packages/rackmate_core/lib/src/catalog/`, which is Dart and stays Dart (§11.32.4).
2. **The Device Builder gains a `Submit to community catalog` toolbar action**, opening a review
   sheet showing the exact JSON to be proposed, the citation, and the sign-in state, before anything
   leaves the machine.
3. **Identity is GitHub, obtained by OAuth authorization code with PKCE**, loopback redirect on
   `127.0.0.1` at an ephemeral port. **No credential is embedded in the binary.** REST calls go from
   the app to GitHub directly. There is no server and no broker (§11.32.2).
4. **`TemplateBody.submittedBy` records the GitHub handle and the numeric user id.** Written on
   submission, **never read by the application**, absent when the template has not been submitted.
5. **The citation bar is a photograph of the device's ports**, satisfied either by an image the app
   commits to the contributor's own fork or by a URL to a manufacturer image. **It blocks submit.**
6. **Evidence never enters the `.rmdx`.** AC-057 deleted device images from the model and this does
   not reopen that. Evidence travels with the pull request (§11.32.6).
7. **v1.1, and conditional on a precondition this ruling does not rule** (§11.32.7).

**11.32.2 The embedded token, proposed and withdrawn, which is the load-bearing half.** The user's
first design had the app call GitHub's REST API directly carrying *"a restricted app token"* embedded
*"securely"* in the binary, on the correct reasoning that a broker service is a large and permanent
operating cost for a desktop tool. **The direct call survives. The embedded token does not.** The
user asked for verification before committing to a mechanism, and GitHub's own documentation for
public clients answers it: a native app *"cannot secure your client secret"*, because you *"ship the
client secret in the application's code"*. No obfuscation repairs this, since whatever key decrypts
the embedded credential ships beside it.

**Three failures of a shared token have nothing to do with theft, and are the reasons that would
stand even if the binary were unreadable.** It arrives from **one identity**, so clause 4's credit
becomes an unverifiable self-declaration and the attribution this feature exists to produce is gone.
It shares **one rate limit**, so a single enthusiastic contributor stops everyone. And revoking it is
**an app release**, not a click.

**The theft argument is also not hypothetical under §11.32.7's intended posture.** GitHub's secret
scanning automatically revokes GitHub tokens found in public repositories, so a credential committed
to a public source tree is dead before the first contributor finds the button that uses it.

**What replaces it costs nothing, which is why this correction is cheap.** GitHub states the
`client_secret` is not needed for the device flow, so a secret-free direct-REST design already
exists in two forms. The ruling takes **authorization code with PKCE** rather than device flow, on
GitHub's own preference: device flow has no redirect URI at all and is therefore usable to
impersonate an app in a phishing attack, and it is documented for constrained environments such as
CLIs and headless systems. RackMate is a windowed desktop application that can open a browser and
listen on loopback, so it is not that environment and does not get that exemption. Sources:
`docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps` and
`.../best-practices-for-creating-an-oauth-app`.

**11.32.3 Why not Google OAuth, which is what was asked for.** A pull request is an operation against
a GitHub identity. Google OAuth establishes that somebody controls a Google account, which is not
that identity and cannot be exchanged for it. Honouring the request literally requires a hosted
service holding a GitHub App private key and opening pull requests under a bot account, which buys a
server, a key rotation, an abuse surface, a store of personal data, and pull requests whose author is
a robot with the human buried in the body. It was priced at weeks against days and the user withdrew
it once the constraint was verified rather than asserted.

**11.32.4 The second repository, and what DR-002 and AC-052 keep.** The seeded catalog is Dart source
under DR-002's generic-archetype rule and AC-052's citation gate. A community submission is a real
manufacturer and a real model, which §10.9 explicitly permits for user-authored templates and
explicitly refuses for the seed: *"AC-052's provenance gate and DR-002's generic-archetypes rule bind
the SEEDED catalog"*. Landing community devices in `catalog_audio.dart` would violate both, so they
land somewhere else. The second repository also keeps a moderation queue out of the application
repository's pull request list, and keeps device submissions from running the fourteen gates, which
exist to protect a Flutter application and have nothing useful to say about a patch panel.

**11.32.5 `submittedBy` is a credit, not a signature, and this does not reopen AC-042.** AC-042
deleted signatures and `provenance`/`derivedFrom` chains from v1 and kept `contentHash`. Nothing here
returns: the field is a plain record of who filed a pull request, it authenticates nothing, and **the
application never reads it**. Anybody may type anything into it, and the only place the claim is
actually tested is the pull request, where GitHub has already established who is speaking.

**Handle and numeric id are two fields because they are two facts**, the discipline DR-026 §11.25.1
applied to `Pathway.designator`. A GitHub login is renameable, and a freed login is claimable by
somebody else, so a handle alone can come to credit a different person years later without anything
having changed in the file. The numeric id never changes and is unreadable; the handle is readable
and may drift. Storing one and deriving the other is the version of this that is wrong in a way
nobody notices for two years.

**11.32.6 The citation bar is a photograph, and AC-057 is why it is not in the file.** The user's bar:
*"a photo/photos of the ports on the device itself"*, on the reasoning that a contributor either has
the unit in front of them and a phone, or can find the manufacturer's image. **This is a stronger
citation than a URL, not a weaker one**: a photograph of the actual rear panel is a primary source,
where a manufacturer product page is a secondary one that returns 404 about as fast as the product
is discontinued. Both are accepted; neither may be skipped.

**Where it travels is fixed by two constraints, one of them external.** AC-057 keeps images out of
the model, so the photograph is never `.rmdx` payload. And GitHub has **no documented REST API for
attaching an image to a pull request body**: the drag-and-drop path is a web interface feature, and
the `uploads.github.com` endpoint that community tools use is undocumented and unsupported, which
disqualifies it as the foundation of a shipped feature. So the app **commits** the image to the
contributor's own fork under an evidence path, using the supported contents API, where it renders in
the pull request diff for review and never reaches the upstream repository. The app downscales
before committing, because a fork is not a place to put unmodified phone camera output.

**The repository's history is the provenance store, and the file is not.** A merged device is joined
to the pull request that introduced it by ordinary version control, which is where the photograph,
the reviewer's questions and the contributor's answers already live. That is the shape AC-042 wanted
when it deleted the in-file chain.

**11.32.7 The precondition this ruling does not rule.** DR-006 rules RackMate an internal tool with
no commercial release planned, and §10.8's answer names an update check and API-key publishing as the
only contemplated network uses, neither in v1 scope. **A community with contributors is a public
project**, and this feature is a third network use. The user's stated intent, recorded because the
v1.1 item depends on it: *"It will eventually become a public project."* That is an intent and not a
ruling. **The submission surface may not ship before the release posture and the licence are ruled**,
because a submit button aimed at a repository nobody can see is an expensive way to build a form.
This ruling deliberately does not settle it: it is a licensing decision as much as a distribution
one, and it deserves its own argument rather than a clause in somebody else's.

> **DISCHARGED 2026-08-10 by DR-036 (§11.35).** RackMate is a public project under GPLv3-or-later,
> the community catalog is CC0, and nothing is priced. **This precondition no longer holds anything
> back**: DR-033 and DR-034 are unconditional v1.1 items on their own merits. The paragraph above is
> kept as written, rather than edited, because it is the record of what the surface was waiting on
> and of the fact that it was made to wait deliberately.

**11.32.8 Scope, and the one part that lands now.** **A scope change under roadmap §8.3**: a new row
in §7.3 and roadmap §2.2. The v1.1 membership criterion is met, since nothing here migrates a format
or re-derives user data.

**The `submittedBy` field itself lands in v1, ahead of its surface.** `TemplateBody` has **no
`unknown` passthrough**: `_encodeTemplateBody` builds a fixed map, so a `.rmdx` carrying a credit
written by a v1.1 build would have that credit **silently dropped** by any v1 build that opened and
re-saved it. That is exactly DR-019 §11.18.2(5)'s argument, where a build predating a field drops it
on save and the remedy was to land the mechanism early. Here the remedy is cheaper than a passthrough
because the field is one nullable record and the format is not yet built at all. Model ships, gesture
defers, which is §7.0's filter 2 doing the job it was written for.

**What it does not rule.** It does not choose between an OAuth App and a GitHub App for the client
registration, which is a spike in the build task and turns on fine-grained permission scoping rather
than on anything decided here. It does not specify the review workflow, the moderation policy, or who
holds merge rights on the second repository. It does not make submission a step in any other flow:
clause 2's toolbar action is the only entry point ruled, and a palette context menu would be a second
one somebody may add later. And it does not give the seeded catalog a submission path, which
§11.32.4 is the reason for.

---

### 11.33 DR-034 · The community library arrives as an `.rmda` release asset, and is never cloned

**Settled by the user on 2026-08-09**, the same day and in the same conversation as DR-033, which it
completes. DR-033 is the **write** path, one device leaving one machine. This is the **read** path,
the whole library arriving on every machine. They are one feature with two directions and are ruled
separately because they fail differently.

**11.33.1 The ruling, in seven clauses.**

1. **One `.rmda` per release tag**, attached as a release asset and fetched over HTTPS. **Nothing is
   cloned and no git is involved** (§11.33.2).
2. **The installer bundles a snapshot `.rmda`**, so a first launch with no connectivity still has a
   community library. The bundled tag is recorded.
3. **First run offers and never blocks.** A dismissible card in the first-run experience, with the
   device count and the download size. Declining costs nothing and being offline costs nothing.
4. **The update check is `releases/latest`, unauthenticated, at most once per 24 hours on launch.**
   If the tag differs from the installed one, a **non-modal** notice offers the update.
5. **Updating is a user action.** The installed library records its tag and is never replaced behind
   the user's back.
6. **The community library is a separate library**, filterable in the palette by DR-015 §11.15.5's
   mechanism. It is **never merged into the seed** (§11.33.5).
7. **v1.1, under DR-033 §11.32.7's precondition**, which governs both directions.

**11.33.2 Why it is not a clone, which is the word the request arrived in.** Three reasons, in
ascending order of cost.

**Flutter desktop has no git.** Cloning means vendoring libgit2 or shelling out to a `git` binary
that is not installed on an integrator's site laptop. That is a native dependency on both platforms
and an entry in `docs/13` for a feature whose entire job is to fetch some JSON. **A clone also drags
the history**, which is every revision of every device anybody ever proposed, to deliver the current
one.

**The third reason is the one that decides it: the format is already ruled and not yet built.**
DR-015 §11.15.3 ruled `.rmda` as the device archive, and M4 already owes *"the codec, the library
directory service, import/export, and the palette filter that makes more than one library usable"*.
A community release **is** a library pack. Fetching one over HTTPS instead of receiving one by email
changes the transport and nothing else, so the download lands in a slot the product already has a
concept of, and the import path is the path a user's own `.rmda` already takes. **A tarball of loose
`.rmdx` files would be a second on-disk shape**, and the library directory service would carry both
forever because the first users to install one would never stop having it.

**11.33.3 The floor and the ceiling, which is why both answers were taken.** The user took the
bundled library **and** the opt-in card rather than choosing. That is not indecision and it is the
better answer: **the bundle is a floor and the fetch is a ceiling.** A bundled snapshot alone ties
the library's freshness to the application's release cadence, which is the exact coupling release
tags exist to break. A fetch alone means a first launch in a half-built house with no wifi shows an
empty library, and **the seeded catalog is generic archetypes** (DR-002), so the user who most needs
a real SKU is the one standing in the mechanical room. Together, the offline case is a stale library
rather than no library, and connectivity is an upgrade rather than a prerequisite.

**A consequence to expect rather than be surprised by:** the application ships less often than the
catalog does, so the bundled tag will nearly always be behind on first launch. **The first-run card
and the update notice are therefore the same mechanism**, and the card states which it is offering.

**11.33.4 This is not RJ-014's auto-updater, and the distinction is not a technicality.** RJ-014
refused an in-app update mechanism for v1 on the ground that *"auto-update is a security surface
before there are users"*, and allowed a signed installer plus a version-check ping. **Nothing here
updates the application.** A `.rmda` is inert data: docs/06 §7.3 already states templates
*"are inert data with no executable content, and the import dialog says so"*. No code is fetched, nothing is
executed, and the signed installer remains the only thing that changes the binary. Clause 4's check
is the version-check ping RJ-014 explicitly permitted, pointed at a catalog instead of a release.

**11.33.5 The community library may not touch determinism, and this is a gate.** Determinism is a
project invariant: same document, same display list, same exported bytes. The four starter projects
do triple duty as goldens, perf fixtures and screenshot source (AC-052). **If a golden could resolve
a template out of a library that arrives over the network, the goldens would depend on a release tag
and stop being goldens.** So the seed and the community library are separate resolution scopes, the
starters and every golden read the seed only, and a test asserts it. This is the one clause here
that constrains implementation rather than product behaviour, and it is the one most likely to be
violated by accident, because merging the two libraries into one palette list is the obvious
shortcut and it is invisible until a golden moves under somebody six months later.

**11.33.6 A download is an import, and gets the import path's defences.** AC-058/D8's JSON depth and
size limits apply to a fetched bundle exactly as to a file the user chose, because **the network is
not a more trusted input than the disk**, and the release asset is written by whoever holds merge
rights on a repository full of strangers' contributions. The bundle's `contentHash` is verified
before it is installed (AC-042 keeps `contentHash` for exactly this class of use), the fetch is
HTTPS, and a failure leaves the previously installed library in place rather than a half-written
directory.

**11.33.7 What this obliges, stated so it is not discovered later.** The catalog repository must
**cut releases**: a tag, a workflow that bundles every `.rmdx` into one `.rmda`, and the asset
attached. A repository that merges pull requests and never tags produces an application whose update
check truthfully reports that there is nothing new, forever. That is a standing maintenance cost of
this ruling and it belongs to whoever holds the second repository, not to the application.

**11.33.8 Scope, and what it does not rule.** **A scope change under roadmap §8.3**, v1.1, sharing
DR-033's precondition. It does not set the release cadence, the bundle size budget, or the retention
policy for superseded library versions. It does not rule whether a user may pin to an older tag,
which is a real request that costs nothing to add later and should not be guessed at now. It does not
give the update check a telemetry channel of any kind: §10.12(e)'s opt-in local-first position is
untouched, and an unauthenticated `releases/latest` call sends nothing but the fact that somebody
launched the application.

---

### 11.34 DR-035 · A created `Pathway` records the medium it is and the room it serves

**Settled by the user on 2026-08-10.** DR-032 §11.31.1 rules what a pathway created from a
pathway-only medium is **called**. It is silent on what else that act records, and §11.31.6's list of
what it does not rule does not mention either field. The silence was invisible while only one surface
created pathways; it stops being invisible the moment §11.31.5's second surface is built.

**11.34.1 The forcing case, which is a broken control and not a tidiness argument.** docs/07 §4.2's
matrix cell is a **count**: a person types `3` into `[Living Room × EMT]` and the cell must then read
`3`, and typing `1` must remove two. Reading it back means finding *"the pathways in this room, of
this medium"*, and a `Pathway` created under DR-032 records **neither**: `pathwayMedia` is null and
both location references are null. A cell that accepts a number and always reads back `0` is not a
partially built feature, it is a control that lies, and it would ship the tinted column docs/07 §4.2
draws while making it unusable.

**11.34.2 The ruling.** An entry surface that creates a `Pathway` from a pathway-only medium sets,
in addition to DR-032's name:

1. **`pathwayMedia`** to the resolved `MediaTypeId`. It is the medium the user named; the field's own
   doc comment calls it *"which conduit this actually is"*, and nothing else in the document can
   answer that question afterwards.
2. **`fromLocationId`** to the room the line or the cell named. `toLocationId` **stays null**, which
   is UNKNOWN and not empty (G4, CR-114): nobody has said where the other end lands, and a run to the
   rack is a guess about a rack this project may not hold.

**`kind` and `containsLineVoltage` are still untouched**, exactly as §11.31.6 has it: typing a medium
states neither.

**11.34.3 `from` is the room, and the reason is that this product already has one convention.**
`Pathway.fromLocationId` and `Pathway.toLocationId` have shipped since M0 with **no reader that
establishes an order**: the only writer is `RemoveLocationCommand` clearing both during DR-021's
cascade, which treats them symmetrically. So the orientation is genuinely open and is being set here
for the first time.

docs/08 §3.2 reads every schedule row **`FROM — ROOM`** then **`TO — RACK`**, and
`ScheduleEntry.roomId` is already oriented on that basis, which `buildStructureTable` relies on. Room
is the *from* end throughout the product. The rejected alternative is the installer's own phrasing,
*"conduit runs from the panel to the bedroom"*, which is how a person describes pulling it and is a
perfectly good sentence. It loses on cost: it would make the same physical run read `FROM = room` on
its cable rows and `TO = room` on its pathway, one table apart, so *"which end is the wall"* would
have two answers in one editor.

**11.34.4 Both surfaces produce the same entity, and that is §11.31.5 restated.** The drop line
already shipped (`b093062`) and did not set these fields, so it is **retrofitted in the same change**
rather than left as the odd one out. §11.31.5's holding is that *"one medium must not mean two things
depending on which box a person typed it into"*; two surfaces that agree on the name and disagree on
the medium would satisfy the letter of DR-032 and break its point.

**11.34.5 What this does not touch.** `+ Add pathway` on the Pathways tab sets **neither** field, and
that is not an inconsistency: it has no room and no medium to record, because somebody pressed a
button on a list rather than naming either. Inventing them there is the failure DR-032 §11.31.2
already refused in the name field, one field over. Nothing is made required: a pathway with no medium
and no room is legal, is what the button produces, and prints the unknown dash in both columns.

**11.34.6 Scope.** **No scope change to roadmap §2.** CR-109 and DR-032 are implemented rather than
amended, and no milestone moves. It is a **behaviour change to a shipped gesture** on §11.31.7's own
terms: a drop line reading `Office: 1x ENT` recorded a bare name before this ruling and records the
medium and the room after it. Nothing has shipped to a user, so no document carries the old shape,
and the four starters are checked rather than assumed: none types a conduit through a drop line.

---

### 11.35 DR-036 · RackMate is a public GPLv3 project, the catalog is CC0, and nothing is priced

**Settled by the user on 2026-08-10.** This is the ruling DR-033 §11.32.7 declined to make and named
as its precondition. It **reverses DR-006's first clause**, answers §10.3 **on its own terms** rather
than leaving it moot, and unblocks the v1.1 community catalog.

**11.35.1 The ruling, in five clauses.**

1. **RackMate is a public project.** DR-006's *"NO COMMERCIAL RELEASE IS PLANNED"* is reversed as a
   statement about **distribution**. Development happens in the open.
2. **The application code is GPLv3-or-later.** All five packages and the app shell.
3. **The community catalog is CC0 1.0**, a public domain dedication, and is **not** GPL
   (§11.35.3, which is the clause most likely to have been got wrong).
4. **Contributions arrive under a DCO sign-off**, not a contributor licence agreement.
5. **Nothing is priced.** §10.3 is answered: no fee, no tier, no gate, no enforcement.

**11.35.2 The dependency census, measured rather than recalled.** Read out of the pub cache at
`pdf` 3.13.0, not from memory, because a licence claim reasoned from the shape of a question is the
error §11.18.5 already records once.

| Licence | Packages |
|---|---|
| **Apache-2.0** | `pdf` |
| MIT | `uuid`, `path_drawing`, `window_manager`, `screen_retriever` |
| BSD-3-Clause | `collection`, `meta`, `path`, `vector_math`, `path_provider_windows`, the Flutter SDK |

Every dependency is permissive, so every option was open **but one**: `pdf` being Apache-2.0 closes
**GPLv2 permanently**, because Apache's patent-termination and indemnity terms are additional
restrictions under v2 and are explicitly accommodated by v3. The tree is clean for GPLv3 and always
was. **The SIL OFL fonts AC-058/D7 speaks of are not bundled yet**: `assets/` holds only `catalog/`,
so that obligation is future rather than current, and D7's `LicenseRegistry` wiring now owes GPLv3
itself as well.

**11.35.3 Why the catalog is NOT copyleft, which is the clause that would have been got wrong.**
Copy-on-place (AC-041, docs/06 §8.1) embeds a full `TemplateSnapshot` into `RackDocument.templates`
so that *"a `.rmpj` file is therefore self-contained: the recipient does not need your library"*.
**Under a copyleft catalog, every project file an integrator sends a client contains
catalog-derived content**, and the product would be handing professional users a licensing question
about their own deliverables. Nobody reads a licence before emailing a drawing set; they would
simply be quietly non-compliant, at scale, because of an architectural decision made for an
unrelated reason.

**CC0 removes the question instead of answering it.** It is also the honest description of the
content, which is largely uncopyrightable fact: a device has four rack units, eight HDMI inputs and
an IEC C14 inlet whoever writes it down. **Attribution survives where it belongs**, in the pull
request history and in `submittedBy`, which DR-033 §11.32.5 already made a credit rather than a
licence term. Requiring attribution as a *licence condition* would put that same travel problem back
into every embedded snapshot, which is why CC-BY was refused.

**11.35.4 The output exception, because the seed has the same problem and CC0 does not reach it.**
The seeded catalog is **Dart source inside `rackmate_core`** and is therefore GPLv3 as code. Copy-on-
place embeds *seeded* snapshots into `.rmpj` files exactly as it embeds community ones, so fixing
only the community catalog would leave the identical defect wearing the archetypes that ship in the
binary.

**So the licence carries an explicit output exception**, in the manner of the GCC runtime library
exception and of Bison's: **a document produced by RackMate is the user's own work and is not a
derivative of RackMate**, and that includes template snapshots embedded from the seeded catalog and
every exported PDF sheet. **This is stated in `LICENSE` and in the README, not inferred**, because an
exception nobody can find is not one. Without it, GPLv3 on a program whose whole purpose is to emit
a client deliverable is a trap set for the people the product exists to serve.

**11.35.5 What DR-006 loses, and the fallback it already named firing on schedule.** Reversed: the
internal-tool posture and the no-commercial-release clause, and with them §10.3's mootness.

**Not reversed, and this is DR-006 being right in advance**: it named **Microsoft Trusted Signing**
as the fallback *"if external distribution is ever required, adoptable at M8, with no earlier
milestone needing to anticipate it"*. That condition has now fired, and the promise holds: **no
milestone before M8 changes**, because self-signing was never load-bearing for anything but delivery.
Public distribution makes the switch necessary rather than optional, since a self-signed binary
downloaded over the internet carries Mark-of-the-Web and meets the SmartScreen ramp §11.6.2 split
M8's criterion over. **§11.6.1's reasoning survives intact**: the three mechanisms it removed were
specific to OV/EV procurement and none of them returns.

**11.35.6 §10.3 is answered on its own terms, and the watermark hazard stays buried.** §13 records
§10.3 as MOOT with the standing note that *"if DR-006 is reversed, §10.3 reopens exactly as written,
watermark hazard included"*. It has reopened, and the answer is **nothing is priced**: no perpetual
licence, no subscription, no free tier with a paid ceiling.

**The watermark is the part that mattered and it never gets built.** §10.3's option (c) would have
watermarked client-facing sheets, and **DR-005 makes the whole sheet set a client deliverable**,
which is precisely what makes a watermark unshippable rather than merely unpleasant: an integrator
cannot send a stamped drawing to a homeowner. AC-058/D7 shrinks a second time. DR-006 consequence 9
already deleted the commercial EULA and the enforcement machinery; this keeps them deleted
permanently rather than pending, and what survives is the same obligation as before, every bundled
licence reachable from `showLicensePage`, now including GPLv3.

**11.35.7 A DCO and not a CLA, and what that deliberately forecloses.** The Developer Certificate of
Origin is a `Signed-off-by` line asserting the contributor has the right to submit. **DR-033's
submission flow can add it automatically**, so the friction for a contributor is zero, which is the
whole argument: a signed agreement deters exactly the one-device drive-by contribution the catalog
exists to collect.

**What it costs is unilateral relicensing, and that cost is accepted knowingly.** Without a CLA, the
code licence cannot be changed later without every contributor's consent. **Clause 2 is therefore
close to irreversible in practice**, and is taken meaning it rather than as a default.

**11.35.8 Neither licence grants the name.** *RackMate* and **Riley the RackMate** (§10.12(f)) are
trademarks and are not licensed by GPLv3 or by CC0. A fork may take the code and **may not take the
name or the mascot**. Stated because §10.12(f) scheduled real branding work and a reader who assumes
the code licence covers it has assumed wrong.

**11.35.9 Scope, and what it discharges.** **No milestone moves and roadmap §2 gains nothing.**
Licensing is not a feature.

**DR-033 §11.32.7's precondition is discharged.** The submission surface (DR-033) and the library
fetch (DR-034) are no longer conditional; both stay **v1.1** on their own merits, and the
conditional clause leaves their §7.3 rows.

**What it obliges**, none of it in v1's critical path: a verbatim `LICENSE` at the repository root
with the §11.35.4 exception stated beside it; a `LICENSE` in the catalog repository carrying CC0; a
`CONTRIBUTING.md` carrying the DCO text; `LicenseRegistry` registration so `showLicensePage` shows
GPLv3; and the M8 switch to Trusted Signing.

**What it does not rule.** **Not the date the repository actually becomes public**, which is a
readiness call and not a licensing one. Not which forge hosts it: DR-033 assumes GitHub because pull
requests are its mechanism, and this ruling does not independently ratify that. Not governance, merge
rights, or a code of conduct. And **not the licence on a user's own authored templates**, which are
the user's work under §11.35.4 and were never the project's to license.

### 11.36 DR-037 · The Plan view's exit criterion, and the four questions decomposition had to answer first

**Settled by the user on 2026-08-10**, discharging board #589 (`PLAN-0`). DR-029 §11.28.10 left the
epic's **contents and its exit criterion** to decomposition rather than to the ruling, and §11.28.8
required DR-026's two provisional M3 positions to be re-read here. This is that task's output.

**11.36.1 The exit criterion.** Stated in roadmap §4's form, binary and demonstrable:

> An architect's floorplan PDF is imported **without leaving the app**, calibrated from one known
> dimension, and the rack plus every drop of a real rough-in carries a pin. The project exports a
> sheet set whose `T1.01 Device Location Plan` places a callout for every pinned drop, each printing
> the designator its Pull Sheet row prints. **A person who has never seen the building is handed the
> printed `T1.01` and the printed Pull Sheet, and locates every drop without asking a question.**
> The set is printed on a real greyscale laser at ANSI B and every callout stays legible over the
> screened underlay (AC-054's standard). `write(read(bytes)) == bytes` holds on the zip path across
> a write, a reopen and a second write, and a project with **no** underlay writes bytes identical to
> what the plain-JSON path writes today.

**The stranger clause is the criterion and the rest is scaffolding.** DR-018's motivation is that
the designer marks device locations as coloured dots in a notes application and *"work is inevitably
done incorrectly against them"*. A dot in Notes is legible to the person who drew it; that is
exactly why it fails. Every other clause here is checkable by a machine or by the author, and an
author cannot test legibility to somebody else. It is the same standard M9-F sets (*"three sheet
sets someone was willing to send"*) and the same shape as M1's tape measure: an act, performed, with
a result that can come back negative.

**11.36.2 Four questions decomposition could not defer, each with the evidence rather than the
preference.**

| Question | Ruled | Because |
|---|---|---|
| **Where the underlay is screened** | **Stored original; the screening pass runs in the PDF backend at export.** | See §11.36.3: docs/15 §7 and DR-029 §11.28.11 contradicted each other and only one of them survives contact with `PdfImage`. |
| **Where `planLowerBound` ranks** | **Below `roomEstimate`, above `none`.** The ladder is `cut > outletNominal > roomEstimate > planLowerBound > none`. | See §11.36.4. Ranking it higher makes the footage rollup **worse the more of the job is planned**, which is measurable in `cable_footage.dart` today. |
| **Multi-page PDFs** | **A page picker with rasterised thumbnails; one chosen page becomes one underlay.** | The electrical sheet is not page 1 of an architectural set. First-page-only reinstates the manual conversion step DR-029 spent 2–3 weeks buying out, on the ordinary path rather than the exceptional one. Importing all pages puts 39 unpinned rasters in the zip and spends AC-006's budget on them. |
| **How hard the physical clause is** | **The stranger walkthrough, as a clause of the criterion and not a follow-up.** | §11.36.1. |

**11.36.3 THE SCREENING CONTRADICTION, AND THE MECHANISM THAT DECIDES IT.** docs/15 §7 says the
underlay *"renders at full value"* on screen and is screened on paper. DR-029 §11.28.11 says it must
be *"pre-composited at import, the way palette tints already are at 18 % over white"*. **Those are
not the same instruction.** A palette tint is composited at *definition* time, so the stored value
**is** the screened one; applied to an underlay, that means the zip holds a washed-out image and
docs/15 §7's first half is false.

**The prohibition is real and is bigger than `ExtGState`.** docs/08 row 9 forbids alpha *"absolutely,
with no exception"*, and `pdf-3.13.0`'s `PdfImage` was read rather than assumed: **`PdfImage(...,
alpha: true)` writes an `/SMask` entry**, a second image object serving as a soft mask. A PNG
underlay carrying an alpha channel therefore emits an alpha path into the PDF **without anybody
calling `setGraphicState`**, which is the failure mode row 9 would not have caught, because row 9 is
written about `ExtGState`.

**The ruling separates the two obligations that DR-029 had fused.** *No alpha reaches the PDF* is
absolute and is discharged in the export backend: the underlay is flattened to opaque RGB and the
screening is composited there, so `/SMask` is never emitted and `alpha: false` is the only call
shape. *The stored bytes* stay the architect's page, unmodified. **§11.28.11's requirement is met;
its stated location is not, and the location was the part that was wrong.** The gain is not
aesthetic: a screening percentage that lives in the export path can be changed by editing code,
while one baked in at import can only be changed by re-importing every underlay in every project
file a user owns.

**11.36.4 `planLowerBound` RANKS BELOW `roomEstimate`, AND THE CODE ALREADY KNEW TO ASK.**
`derived/cable_footage.dart:302`'s `_isQuantity` decides whether a length may be **summed into a
purchase**, and its own header records that it was left as an **exhaustive switch with no default
arm** precisely so *"the day it is added this file stops compiling and somebody decides, rather than
a bound silently joining a purchase"*. This is that day, and the decision is the one that file was
written to force.

DR-020 §11.19.2(2) rules a bound out of the rollup as a quantity. `ScheduleLengthSource` is **one
value per row**, so a rank is not optional. Rank the bound **above** `roomEstimate` and every drop on
a calibrated plan leaves the footage total and lands in `unknownCount`: **the number an integrator
orders cable from degrades in proportion to how much of the job has been planned**, which is a
perverse result for a planning feature and would have been discovered by somebody ordering short.

So the bound prints only when nothing better is known. **That does not weaken it, because its value
was never the column.** `LEN-001` and `LEN-002` read the bound **regardless of which tier printed**,
which preserves DR-020's asymmetry intact: a plan can prove a violation and can never prove
compliance. The bound is a rule input that happens to be printable, not a length that happens to be
checkable.

**11.36.5 `Location.riseAllowance` DOES NOT EXIST, and two rulings spend it as though it does.**
DR-020 §11.19.2(1) defines `planLowerBound` as *"the calibrated straight line from rack pin to device
pin, **plus the location's `riseAllowance` if one is set**"*, and docs/15 §4.1 repeats it. A grep over
every `.dart` file in the tree returns **zero occurrences**. `Location` carries
`estimatedRunLengthFromRack` and no second `Len`.

It is added here, by this ruling, as `Len? riseAllowance` on `Location`: **null is unknown, `0` is a
measured zero** (G4, CR-114), written only when present, so no file on disk changes a byte and
`kSchemaVersion` does not move (`tia570Grade`'s precedent, DR-024). **It is the survivor of a deleted
set**: DR-020 killed `routingFactor` and `slackAllowance` as the product guessing at building
geometry, and kept this one because a plan is flat and the drop from ceiling to device is the one
dimension it structurally cannot see. Adding it keeps the result a bound.

**This is the third time a field named across three documents turned out not to exist**, after
`MediaTypeDef.maxLength` (§11.19.7, which was `maxRunLengthPassive` all along) and `unknown` on
`Placement` (§11.18.1). The pattern is not carelessness about names; it is that **a design document
and a ruling can agree with each other without either having read the model**, and agreement between
two documents reads exactly like verification.

**11.36.6 DR-026's two provisional positions, re-read as §11.28.8 required. BOTH ARE CONFIRMED, and
neither for the reason that made them provisional.**

**§11.25.1 `Pathway.designator` stays hand-entered.** DR-026 made it provisional because *"a
floorplan speaks to"* the question. It does, and it speaks **for** manual entry rather than against
it. The user's stated reason was *"once a trunk line is established in the home, it would be nice to
know exactly where it is relative to the plans"*, and the plan is the **consumer** of a designator,
not a source of one. DR-020 governs why: the route is discovered, not designed, so a plan cannot know
that a trunk exists, let alone allocate it a number. The Plan view makes the field more useful and
supplies nothing to it. **No allocator, no series, no format token**, unchanged.

**§11.25.2 `Outlet.nominalRunLength`'s tier stands, and the open question attached to it is now
answered.** DR-026 left open *"whether a floorplan supersedes any of the four tiers"*. It supersedes
**none of them**. §11.36.4 places the plan's contribution at the bottom of the ladder, so the three
shipped tiers keep their order and their meanings exactly. `ScheduleLengthSource`'s doc comment
carries a forward pointer to this question and is corrected in place rather than left to be read as
still open.

**11.36.7 What the decomposition is, and the one number worth stating.** Ten issues (#597–#606) and
forty-three tasks (#607–#649), `PLAN-A` through `PLAN-J`, under epic #588. The order is a dependency order and not a
preference: the canvas op (`PLAN-A`) and the container (`PLAN-B`) are the two things every other
issue consumes, and `PLAN-E`'s plan canvas is the row the feasibility study §6 names as *"the one
most likely to be wrong in the optimistic direction"*. **No cost is re-estimated here.** DR-029's
`L` at 9–13 weeks stands; a decomposition that quietly re-priced the epic it was decomposing would
be a scope amendment wearing a task's clothes (§8.3).

**11.36.8 What this does NOT rule, listed so it is not inferred.** Not the rasteriser: `pdfium`
is DR-029's *likely* answer and `PLAN-D/1` picks it against `Windows.Data.Pdf` and costs it with
docs/13's D9, which is a decision that needs the tree read, not a decision that needs a user.
**Not the integrator's logo**, which is DR-030's and lands in M6 (§11.29.4); the Plan view builds
three of its four dependencies and collects none of the credit. **Not the rasterisation resolution**,
which `PLAN-D/3` settles against AC-006's file-size budget with a measurement. **Not mobile**: AC-056
stands, v1 mobile is read-only, and shipping this puts a plan on a desk and not in a technician's
hand on site (§11.28.7).

**11.36.9 Scope.** **No scope change to roadmap §2, and this ruling is careful not to be one.** The
Plan view is already v1 by DR-029; §11.36.5's `riseAllowance` is a field DR-020 already specified and
this ruling only observes that it was never built. Roadmap §4 gains the epic's checklist and exit
criterion, docs/12 gains §5.9, docs/13 gains **D15** for the rasteriser, and docs/15 is corrected at
§4.1, §7 and §10.

### 11.37 DR-038 · The cell is uniform across strap widths, measured; §11.7.8's change 3 is discharged

**Settled by the user on 2026-08-10, with a caliper.** DR-007 §11.7.8 change 3 recorded that
whether a cell on a 2-wide strap is the same size as a cell on a 1-wide strap was **not answerable
from the reference**, required a physical measurement of a real 3-port and a real 6-port, and had to
be taken **before any dimensioned rendering**, *"because a uniform-cell assumption that turns out
false is wrong on every plate drawing at once"*. It has been taken.

**11.37.1 The finding.** The cells are **identical across strap widths**. Every cell on every strap
is DR-028's 14.5 mm × 16 mm front nose, on a 1-wide and a 2-wide alike. A strap is therefore a grid
of uniform cells with no width-dependent term anywhere in it.

**11.37.2 THE MEASUREMENT IS THE AUTHORITY, AND THE ARGUMENT BESIDE IT IS CORROBORATION.** The user
also offered a reason: *"all cells are required to fit the 14.5x16mm nose of a keystone insert
anyway, so them being identical makes sense."* That argument is good and it is **not what settles
this**, and the distinction is §11.27.2's own lesson applied one ruling later. The argument
establishes a **lower** bound: a cell must be at least nose-sized or the part does not go in. It
does not establish an upper one, and a 1-wide strap whose openings were deliberately roomier would
satisfy it while breaking every uniform-cell drawing. **The caliper closes the gap the reasoning
leaves open**, which is exactly why §11.7.8 asked for a caliper and not for an argument.

Recorded this way round deliberately. §11.27.2 records a figure being wrongly elevated over an
earlier one because it had been *"stated deliberately"*, and concluded that **provenance outranks
deliberateness**. Here the provenance is a physical part and a measuring tool, and the corpus should
say so rather than lead with the tidier sentence.

**11.37.3 What it unblocks, and it is more than the editor.** §11.7.8's prohibition was on **any
dimensioned rendering**, which reaches further than M3:

| Blocked on change 3 | Now |
|---|---|
| The M3 strap editor drawing a plate to scale (M3-H/2, #167) | **Unblocked.** A cell is one size, everywhere, and the editor may draw dimensioned rather than schematic. |
| `T5.01 Plate, Panel & Pinout Details` at **M6** | **Unblocked in advance.** DR-007 §11.7.7 keeps the printing at M6, and M6 now inherits a settled geometry rather than an open measurement it would have discovered late. |
| DR-028 §11.27.4's explicit reservation | **Discharged.** That clause warned that supplying one cell size *"does not answer"* uniformity and that a reader taking it as licence to assume uniformity had made the forbidden inference. Nobody has to infer it now. |

**11.37.4 What it does NOT settle.** The **plate opening** dimensions and the position of the cell
grid within them. §11.7.8 change 2 stands untouched: the grid is **centred in the opening, not
anchored to an edge**, and a 1- or 2-port strap does not fill its vertical span. Uniform cells make
the grid's *internal* geometry trivial; where that grid sits inside a Decora opening is a different
measurement and this ruling does not claim it. The ~33.3 × 66.7 mm opening figure in §11.7.8 remains
an *"about"* carried inside an arithmetic check, and §11.27.2 is the reason nobody should quietly
promote it.

> **SUPPLIED by DR-041 (§11.40) on 2026-08-11, one day later and by the same instrument.** The
> opening is **33.34 × 66.68 mm** measured, and the grid's position within it is
> **22 mm vertical / 15.95 mm horizontal** cell pitch, also measured. **This clause was right to
> refuse the figure and is not weakened by the measurement agreeing with the "about"**: the horizontal
> pitch was independently derivable to 15.947 from the opening width alone, and that derivation
> assumed an even-margin manufacturing convention which nothing available in advance could confirm.

**11.37.5 DR-007 is now three-for-three on physical reference.** §11.7.9's lesson was that *"a
physical reference is worth more than a careful reading of a description"*, scored two-for-two on
the single-post keystone and the separate cover plate. The caliper is the third, and it is the first
where the reference settled a question the corpus had correctly identified as unanswerable rather
than one it had answered wrongly. **Naming an open measurement is what made this cheap**: the
question was written down, scoped to two parts, and assigned a tool, so discharging it took one
person a minute rather than a design session.

**11.37.6 Scope.** **No scope change.** Nothing enters or leaves v1; an open measurement inside an
existing ruling is closed. Board #167 loses its "must not be inferred" hazard and gains a figure.

### 11.38 DR-039 · Project history: an in-file journal, an operation panel, and snapshots, in that order

**Settled by the user on 2026-08-11**, from a request for *"a full undo/redo history with snapshots
taken at regular intervals ... that can be rolled back to if a bulk of edits needs to be undone
quickly"*, refined to *"similar to what Autodesk Fusion has for its revision system"* and then to
*"I do want the versioning in-file; it may be necessary to have this for troubleshooting in the
future. The more documentation that is held over the HISTORY of a project, the easier it is to read
WHY a change was made."*

**This is a §8.3 amendment and roadmap §2 gains a line.** Nothing in the scope list mentions
project history, and the machinery that exists (`SnapshotStore`, `Tombstone`, `EntityMeta`) was
built for other reasons.

**11.38.1 "What did it look like" and "why did it change" are two artifacts, and the second is the
one the user asked for.** A snapshot answers the first: it is a whole document, ~870 kB of
uncompressed JSON, and recovering a REASON from ten of them means diffing and inferring. The
second is answered by a JOURNAL: an append-only log of what happened, when, by whom, with a
comment. That is text, it is kilobytes, and it needs no container.

The request named snapshots and cited the journal's benefit. Both ship; the journal ships first,
because it is what the stated reason needs.

**11.38.2 The journal is IN THE FILE, and it costs no schema version.** CR-117's additive-optional
contract is why: a key written only when present leaves every existing document encoding
byte-for-byte, so `kSchemaVersion` does not move. Reading and writing a file without editing it
appends nothing, so `write(read(bytes)) == bytes` is untouched.

**In-file is the requirement and not an implementation detail.** The user's reason is
troubleshooting a project somebody sends you, and application-support storage cannot serve it:
history left on the author's machine is absent from the artifact under investigation.

**11.38.3 Grain: milestones and saves, not every command.** One entry per save, per bulk act (CSV
import, template apply, bulk delete, matrix fill), and per issued drawing revision, each carrying a
timestamp, an actor, a generated summary and an optional user comment. **Every-command was
refused**: a 60-drop rough-in is already several hundred commands and a project's life is tens of
thousands, which is megabytes of journal in an uncompressed file, unreadable by the person it
exists to inform, and it would make the ZIP container a prerequisite (§11.38.6). **Saves-only was
also refused**: a bulk act between two saves would go unrecorded, which is the exact
troubleshooting case the request named.

**11.38.4 CR-095's tombstones are the same feature, half-built, and this ruling finishes them.**
`Tombstone` records `deletedAt`, `entityType` and `by`, is encoded, decoded and byte-round-tripped,
and its own doc comment says it *"Ships in v1 even though no history UI exists yet"*. **Nothing in
`lib/` has ever constructed one**, so `doc.tombstones` is empty in every document this product has
produced. That is the fourth instance of the pattern the practice bundle now names, and it is why
the journal work starts by filling in the gesture rather than by inventing a parallel record.

`EntityMeta{createdAt, updatedAt, updatedBy}` is already on every entity, already in the file, and
already surfaced nowhere.

**11.38.5 The operation panel is NOT a Fusion timeline, and the surface must not imply it is.**
Fusion's timeline scrubs a PARAMETRIC feature tree: editing feature 12 recomputes 13 through 40.
`UndoStack` is a linear log of applied mutations with a `revert()`, so operations 13 through 40
were written against the state 12 produced and cannot be recomputed against a rule. **Undo-to-a-
point is available; edit-in-the-middle is not**, and no amount of UI makes it so. The panel says
this by its shape rather than by a tooltip.

The panel is otherwise nearly free: `UndoStack` already holds 200 entries and merges within 400 ms,
and every command already carries a `LabelKey`.

**11.38.6 Snapshots stay in application support for now, and the ZIP container is a SEPARATE
ruling.** `.rmpj` is plain uncompressed JSON. Moving it to a container would fix a real parsing
concern and shrink files ~8×, and it is the right eventual home for snapshots and for DR-030's
integrator logo. It is also one to two weeks dominated by CR-117 determinism (ZIP carries per-entry
mtime, compression level, entry order and CRC, none of which may vary), by re-baselining thirteen
byte-exact artifacts and their `.gitattributes` pins, and by AC-058/D8's zip-slip and
inflation-limit work becoming mandatory on File ▸ Open rather than deferrable on import.

**The sequencing decision is that application-support snapshots do not block a container, and
in-file snapshots would.** Versions are files; moving them into a container later is a copy loop
and one migration. Committing to in-file snapshots now makes the container a prerequisite for
shipping any of it. The journal is in-file from the start because it is small enough that this
argument does not apply to it.

**11.38.7 Restore is PROMOTE, never overwrite** (Fusion's semantics, and they make the cheap
implementation the correct one). Restoring version 7 while on version 12 creates version 13 as a
copy of 7 and destroys nothing. Two consequences: it does not need DR-013's destructive-confirm
pattern, because it is not destructive; and it may be implemented as `DocumentSession.adopt`, the
existing File ▸ Open path, without adding a mutation primitive to the layer roadmap §2 line 48
calls *"the most expensive retrofit in the project"*.

**11.38.8 Naming: VERSIONS are file states; REVISIONS are issued drawings.** `RevisionEntry
{revision, date, description, by}` already exists and is the title-block revision table (*"Rev B,
2026-03-14, Issued for construction"*). Using one word for both would put two meanings on one term
in one document class. Issuing a revision is a natural journal entry and a natural snapshot
trigger, which is a relationship worth having and not a reason to merge them.

**11.38.9 CR-098's "pruned to the last 10" is amended for snapshots to a retention the user can
set, defaulting to a day of history.** Ten was chosen for pre-migration backups, where it is
generous. It is wrong for interval snapshots: at ten minutes it is 100 minutes of history. The
pre-update snapshot behaviour CR-098 rules is otherwise untouched.

**11.38.10 SNAPSHOTS ARE DIFFABLE, and the diff is what makes the journal answer "why".** The
journal says *"14:20, imported smith-pull-list.csv, 61 drops"*. A diff of the snapshots either side
of that entry says WHICH 61 and what changed on each. Index and detail are different artifacts and
the pair is what the request asked for; neither alone is.

**The property this rests on is already enforced rather than newly required.** `json_codec.dart`
writes *"plain, pretty-printed, key-sorted UTF-8 JSON"* with a deep sort, and CR-117 gates the
result byte-for-byte. Sorted keys make a textual diff stable and minimal; byte-exactness makes every
difference a REAL change rather than serialisation noise. Most project formats can claim neither,
and a diff over one that could not would be unreadable.

**11.38.11 The diff is computed over the CODEC'S OUTPUT, never over the object graph.** Two
reasons, and the second is the one that decides it.

The codec is total and CR-117's 1000-sequence fuzz harness already proves it. An object-graph
walker would be a second traversal with no such proof, and the field it forgot would be invisible
in exactly the way a diff must never be. The entity maps are also flat and UUID-keyed, so
added / removed / changed falls out of a map comparison for free.

**The accessor tables are used to PRETTIFY, never to enumerate.** `LinkField`, `LocationField`,
`PathwayField` and their siblings name and format a field for a human, and a key none of them
carries falls back to its raw spelling. Enumerating the comparison FROM those tables would be the
census trap this project has already paid for twice: they cover fields a gesture edits, not fields
that exist, so a diff built on them would silently omit every field nothing has been wired to yet.
Built this way the diff is total on day one and merely gets friendlier as the tables grow.

A consequence worth having: `unknown` passthrough maps appear in a diff automatically, so a field
written by a NEWER build shows up as a change rather than as nothing.

**11.38.12 Scope.** **Roadmap §2 gains "project history: an in-file journal, an operation panel,
promote-not-overwrite snapshots and a document diff".** The ZIP container is explicitly NOT in this
amendment and needs its own ruling. The milestone this lands in is open; it is not M3, which is
mid-flight.
### 11.39 DR-040 · A drop lands on a panel port; `@panel=` is the gesture and the rack label is allocated

**Settled by the user on 2026-08-11**, from a census taken before M3-G's stopwatch rather than after
it. Board #163 says *"run the drill EARLY, on a rough build ... a drill run on a rough build finds
them while the design can still move"*, and the reading that pays is **find the reasons it cannot
pass while they are still cheap**. Three were reachable from a grep.

**11.39.1 What the census found, and none of it was visible from the suite.** M3's criterion wants
sixty drops of which forty-six land at a rack and fourteen stay open. The product could only ever
make the second kind:

| Absence | Evidence |
|---|---|
| **Nothing allocates a `rackLabel`.** | `allocateOutletRackLabel` has four callers and all four are in `drop_label_allocator_test.dart`. |
| **Nothing binds a far end.** | `drop_build.dart:159` never passes `rackEnd`, so `home_run_commands.dart:224` writes `OpenEndpoint('not yet landed')` on every drop the product can create. Sixty of sixty. |
| **`BindEndpoint` was never written.** | Zero `.dart` files. §2186 names it, `docs/01` §535 and `docs/02` §663 both cite it as though it exists. |
| **`{FLOOR}` and `{SPACE}` have no editor.** | `floorNumber` and `spaceCode` appear in the whole of `packages/rackmate_ui/lib` and `apps/rackmate/lib` **exactly once**, in a `locations_panel.dart` comment saying they are deliberately unedited. |
| **`{PANEL}` has no source field at all.** | It is in `kIdFormatTokens` and in the shipped preset. Nothing in the model answers it. |

**Three of the four tokens in the shipped TIA-606 preset were unreachable**, so
`{FLOOR}{SPACE}-{PANEL}{PORT:2}` could not render on any document this product has ever written,
and could not have even if the binding had existed. That is the finding that would have cost the
second drill run rather than the first.

**11.39.2 The ruling, in four clauses.**

1. **A landed far end is a `PortEndpoint` on a patch panel device.** `BindEndpoint` is built, in
   `rackmate_core`, and it materialises the port inside `apply()` exactly as DR-011.1 rules for the
   connect gesture. `derivePortId` is a pure UUIDv5 over `(deviceId, portKey)` (CR-116, AC-006), so
   the id is knowable before the pin exists and no panel needs pre-materialised ports.
2. **The gesture is `@panel=` on the drop line.** `Media Room: 4x Cat6 @panel=PP-1` lands every drop
   on that line. Ten modifiers cover forty-six drops, which keeps the drill near the measured 5.82
   keystrokes per drop instead of adding forty-six hand-typed cells to a fifteen-minute clock.
3. **The rack label is ALLOCATED, never typed**, through the one format engine (CR-045), on the
   field label's precedent. A typed string is governed by no pattern, so a project that customised
   its preset would get sixty labels that ignore it.
4. **The drop lands on the REAR port.** The N03 archetype's own description says why: *"Rear ports
   are 110 punchdown, not RJ45: modelling both faces as RJ45 is the error that makes the Termination
   Schedule wrong on the one column the trim tech actually needs (AC-025)."* A structured drop is
   punched down. The front jack is where a patch cord goes.

**11.39.3 `{PANEL}` is the panel device's designator, and the alternative was invented data.** CR-044
ships the preset and renders it `1A-A12`, which is a TIA-606 example and not a specification: it
names no source for the panel segment. The model has exactly one identifier for a panel, because
**the model has no `Panel` entity** and `schedule.dart:205` already says so out loud, calling a patch
panel *"a `DeviceInstance` like any other"* and sorting §3.6's `rack, panel, port` on the device
designator. So `{PANEL}` is that designator and the default preset renders `1A-PP-101`. Adding a
`panelLetter` field to make `1A-A12` reproducible would be **inventing a fact nobody stated** to
match an example, which is §11.27.2's error with the provenance running the other way.

**11.39.4 `{FLOOR}` and `{SPACE}` become editable on the `Location`, and they are the RACK's.** The
fields, the `LocationField` entries and the commands all exist; only the two controls are missing,
and `locations_panel.dart:110` says they were left out because the third field on that list belonged
with M3-D. That reason has expired. **The floor and space that render are the panel's, read through
the panel device's location, never the drop's room**: `1A` is the telecom room, and a drop from a
bedroom on the second floor does not get a `2` because it starts there.

**11.39.5 A bind that cannot render a label still binds.** The endpoint and the label are two facts
and G4 forbids fusing them. A panel whose location has no floor number produces a bound
`PortEndpoint` and **an absent `rackLabel`**, with the refusal sentence naming the field to fill, on
`missingTokenSentence`'s existing pattern. The alternative, refusing the bind, would make an
unrelated missing token undo a physical fact somebody stated.

**11.39.6 What this does NOT settle.** **`LNK-020` stays M5's.** Its canonical text is literally
*"14 links have unbound endpoints"*, and after this ruling it will finally be able to say something
true, but the rule catalogue is M5's and building one rule early buys nothing. **Unbinding is not
ruled**: `BindEndpoint` gets a `revert` because every command does, and a deliberate *"this was
punched into the wrong port"* gesture is not specified here. **The front jacks are untouched**: this
ruling lands a drop on the rear and says nothing about patching the front to a switch, which is the
schematic's job and M2's gesture.

**11.39.7 Scope.** **No scope change under §8.3.** Nothing enters or leaves v1 and M3's exit
criterion is not amended: this is the criterion's *existing* clause 2b and clause 4 being made
reachable, which is a build. **This is a decomposition gap on #591's and #587's precedent**, both
filed in this same milestone with the same reasoning: a capability the corpus promised, that no task
owned, found by censusing rather than by pricing. The board grows by a new M3-K issue for the
binding and its four tasks.

**It is fair to record what it costs anyway.** DR-007 and DR-020 were M3's first two growths and
§5.2 already reads the row as `M`-at-its-ceiling. This is not a third growth, but four tasks arriving
at the exit criterion have the same effect on a calendar as if it were, and the row should be read as
`M`-over-ceiling until the drill returns a verdict.

**11.39.8 `{PORT}` is the number PRINTED ON THE PART, taken mid-task when the build produced
`1A-PP-1J04`.** §11.39.3 ruled `{PANEL}` and was silent about `{PORT}`, and the silence had a
visible answer: `ConnectTarget.portDesignator` renders `J04`, because `portDesignatorFormat` is
`J{PORT_SEQ:2}` and `PORT_SEQ` counts a position's place in the whole template **including the front
jacks a drop never touches**. `J04` appears nowhere on the physical panel, so a tech on a ladder
holding a cable labelled `1A-PP-1J04` has to translate it against a panel silkscreened `01 … 24`.
CR-044's own example is `1A-A12`, and the `12` in it is a position.

**The archetype already carries the number.** `catalog_network.dart` calls `n03.p(rearKey, n, …)`
with `n` the zero-padded position, which lands in `PortDef.label`. So `{PORT}` takes the label where
a template declares one and the designator where it does not, and the shipped preset renders
`1A-PP-101`.

**What this deliberately does NOT fix, so nobody reads it as fixed.** The Termination Schedule's
`RACK TERM` column still prints the *designator* for the same hole, so two columns describe one
position two ways. **That disagreement is older than this ruling**: it is between `portDesignator`
and the physical part, and it exists today on every device with authored port labels. Closing it
means teaching designator ALLOCATION to honour an authored label, which changes the connect gesture's
output across the whole catalog and is its own ruling and its own task. It is filed, not smuggled in.

### 11.40 DR-041 · The plate opening and the two cell pitches, measured; §11.7.8's last "about" is discharged

**Settled by the user on 2026-08-11, with a caliper**, at the point M3-H/2 needed each figure and
the corpus did not contain it. DR-038 §11.37.4 named exactly what was still missing: *"The **plate
opening** dimensions and the position of the cell grid within them"*, and warned that the
~33.3 × 66.7 mm figure was an *"about"* nobody should quietly promote. It is no longer an about.

**11.40.1 The five figures, and what each one is worth.** A plate drawing needs all five and the
corpus previously had one.

| Figure | Value | Provenance |
|---|---|---|
| Cell, the front nose | **14.5 × 16 mm** | DR-028 §11.27.1, ruled; DR-038 makes it uniform across strap widths |
| Gang opening | **33.34 × 66.68 mm** | **Measured 2026-08-11.** Confirms §11.7.8's ~33.3 × 66.7 to within 0.04 mm |
| Cell pitch, vertical | **22 mm** | **Measured 2026-08-11** |
| Cell pitch, horizontal | **15.95 mm** | **Measured 2026-08-11**, after being derived to 15.947 from the opening width. See §11.40.3 |
| Gang pitch, horizontal | **1.8125 in = 46.0375 mm** | **A STANDARD, NOT A MEASUREMENT.** The ganged-device-box spacing. See §11.40.4 |

**Every one of them checks out against the others, and that is the point of listing them together.**
Three cells at a 22 mm vertical pitch span 2 × 22 + 16 = 60 mm inside a 66.68 mm opening, leaving
3.34 mm of plastic above and below, symmetric. Two cells at a 15.95 mm horizontal pitch span
15.95 + 14.5 = 30.45 mm inside 33.34, leaving 1.445 mm either side, symmetric. **That symmetry is
§11.7.8's change 2 falling out of the arithmetic rather than being asserted by it**: the grid is
centred in the opening, and the numbers agree without anyone arranging them to.

**11.40.2 What this makes computable, stated as the formula, because the formula is the deliverable.**
For a `W × H` strap in an opening `(Wo, Ho)`, with pitches `(Px, Py)` and a cell `(Wc, Hc)`, cell
`(c, r)`'s centre sits at `((c − (W−1)/2)·Px, (r − (H−1)/2)·Py)` relative to the opening's centre.
**There is no width-dependent term and no height-dependent term anywhere in it**, which is DR-038's
finding expressed as code rather than as a sentence, and it is why a 1-port strap renders with its
single jack centred rather than at the top.

**11.40.3 One figure was derived first and measured second, and the order is the record.** The
horizontal pitch was reachable by arithmetic: three equal margins across the opening give
`3m + 2 × 14.5 = 33.34`, so `m = 1.4467` and the pitch is `15.947`. That derivation was offered as an
option and **explicitly labelled as the kind of plausible inference §11.7.8 change 3 forbade on the
cell size**, to be recorded as a stated choice rather than a ruling. The user measured it instead
and got **15.95**.

**The derivation being right does not make offering it the right call, and the corpus should say so
plainly.** §11.27.2 already records a figure being wrongly elevated because it sounded deliberate,
and §11.37.2 records an argument that established a lower bound being correctly refused as an
answer. This is the same shape a third time: an even-margin layout was one manufacturing convention
among several, a strap with a wider centre web would have satisfied every constraint stated and
broken every 4- and 6-port drawing, and **nothing available in advance could distinguish the two.**
The caliper could. It agreed. Agreement after the fact is not evidence that the inference was safe
before it.

**11.40.4 THE GANG PITCH IS THE ONE FIGURE NOBODY MEASURED, and it is marked as such everywhere it
appears.** 1.8125 in is the ganged-device-box spacing, and it is taken on **corroboration rather than
on authority**: a 1-gang plate is 2.75 in wide and a 2-gang is 4.5625 in, and the difference is
exactly 1.8125 in, so the standard predicts a plate dimension that can be checked without trusting
it. With a 33.34 mm opening it leaves 12.7 mm of plastic between neighbours, which is a real web
rather than an implausible one.

**It is a stated choice, NOT a ruled figure**, and that is deliberate under §11.27.2's rule that an
unruled figure with provenance outranks a ruled figure without one. Leaving it unruled means a later
caliper reading **wins automatically, with nothing to withdraw**. Ruling it would set up exactly the
supersession-and-retraction that entry exists to prevent.

**11.40.5 A WRONG READING WAS REFUTED BY ARITHMETIC BEFORE IT REACHED THE CODE, and that is the
reusable part.** The gang pitch was first given as **22 mm**, which is impossible: an opening is
33.34 mm wide, so two openings 22 mm apart overlap by 11.34 mm. **The check is one line and needs no
tools: a pitch cannot be smaller than the opening is wide.** The reading was real, it was simply the
*vertical cell* pitch, and the question that recovered it was the user's own, *"are we speaking
vertically or horizontally?"*, which exposed that the request had not named an axis.

**Two lessons, and the second is the one that generalises.** First, a dimension request must name its
axis, because a plate has three distinct centre-to-centre distances and they differ by a factor of
three. Second, **every figure in §11.40.1 sits in an inequality with at least one other figure**, and
those inequalities are free. A number that violates one is wrong before anybody draws with it. The
corpus already believed a physical reference beats a careful reading (§11.7.9); this adds that
**arithmetic beats a physical reading that was answering a different question**.

**11.40.6 Stored as `Len` in nanometres (CR-001), and all five are exact.** `33_340_000`,
`66_680_000`, `22_000_000`, `15_950_000` nm, and the gang pitch as `46_037_500` nm, which is
1.8125 in taken through `Len.nmPerInch` rather than through its 46.04 mm rounding. **The hundredths
of a millimetre are why this is not a `double` problem**: 33.34 and 15.95 are exact integer counts of
nanometres and are not binary fractions of a millimetre, which is §11.27.5's observation arriving
with four more instances of itself.

**11.40.7 What it does NOT settle, listed so nothing is read as settled.**

| Open | Why it is not needed yet |
|---|---|
| The **plate outline** (a 1-gang Decora is ~2.75 × 4.5 in) | ~~Nothing in M3 draws the plate's edge~~. **MEASURED by DR-042 (§11.41) on 2026-08-11**, one day later, and the *"about"* was right: 2.75 × 4.5 in exactly. The editor draws the edge now |
| The **strap's own plastic** outside the opening | Hidden behind the cover plate in every elevation the product draws (§11.7.9 B: the front hides the differences) |
| Anything in **depth** | §11.7.9 C: module depth and exit direction are a box-fill fact, and box fill is not v1 |
| Where the opening sits **within** the plate outline | Falls out of the outline the moment somebody measures it, and until then there is no outline to sit inside |

**11.40.8 Scope.** **No scope change.** Nothing enters or leaves roadmap §2. DR-007 already placed
keystone geometry in M3 and DR-038 already unblocked dimensioned rendering; this supplies the four
figures that rendering needs and marks the fifth as unmeasured. **M3-H/2 (#167) has no remaining
"must not be inferred" hazard**: every dimension it draws with is now either measured, ruled, or
labelled in the geometry source as a standard nobody has checked.

> **THE FIFTH IS NO LONGER UNMEASURED, per DR-042 (§11.41) on 2026-08-11.** The gang pitch was
> measured and is 1.8125 in, so §11.40.4's stated choice is now a measurement and this clause's
> last hedge is discharged. **The mechanism worked exactly as §11.40.4 designed it**: because the
> figure was deliberately left unruled, the caliper reading replaced it with **nothing to withdraw
> and no supersession to write**.

### 11.41 DR-042 · The plate outline and the gang pitch, measured; DR-041's last two hedges are discharged

**Settled by the user on 2026-08-11, with a caliper**, one day after DR-041 and against the two
things that ruling deliberately declined to claim. **This entry exists mostly to record that
DR-041's own mechanism worked**, and that is worth more than either figure.

**11.41.1 The two figures.**

| Figure | Value | Was |
|---|---|---|
| 1-gang plate outline | **2.75 × 4.5 in** (69.85 × 114.3 mm) | §11.40.7's unruled *"about"* |
| Gang pitch, centre to centre | **1.8125 in** (46.0375 mm) | §11.40.4's *"a standard nobody measured"* |

An N-gang plate is therefore `2.75 + (N − 1) × 1.8125` in wide: 2.75, 4.5625, 6.375, 8.1875.

**11.41.2 NOTHING IS SUPERSEDED AND NOTHING IS WITHDRAWN, WHICH IS THE POINT.** §11.40.4 left the
gang pitch a **stated choice rather than a ruled figure**, on §11.27.2's rule that an unruled figure
with provenance outranks a ruled figure without one, and said in as many words that this meant *"a
later caliper reading wins automatically, with nothing to withdraw"*. The reading arrived the next
day and that is exactly what happened: **no supersession entry, no §12 row, no corpus edit reversing
an earlier claim**. Compare §11.27.2, where the same class of figure was elevated to a ruling and had
to be un-elevated within hours, taking a wrongly-superseded parenthetical with it.

**The reusable rule, stated so it is not re-derived a third time.** *When a figure is needed before
it can be measured, record it where a measurement can replace it silently.* A ruled figure has to be
overturned; a labelled stated choice is simply overwritten. The cost of the discipline is one
sentence in a source file. The cost of skipping it is a retraction inside the normative document.

**11.41.3 The cross-check, and it is stronger than either measurement alone.** With the outline and
the pitch both fixed, the plastic between a plate's edge and its outermost opening is
`(width(N) − (33.34 + 46.0375 × (N − 1))) / 2`, which evaluates to **18.255 mm for every N**:

| Gang count | Plate width | Edge margin |
|---|---|---|
| 1 | 2.7500 in | 18.255 mm |
| 2 | 4.5625 in | 18.255 mm |
| 3 | 6.3750 in | 18.255 mm |
| 4 | 8.1875 in | 18.255 mm |

**That invariance is not imposed and it is not arithmetic anybody arranged.** It holds only if the
outline formula and the pitch are *both* right, and it drifts with `N` if either is wrong. It is
therefore evidence about the pair rather than a restatement of one of them, and it lands in
`plate_geometry_test.dart` as a case rather than as a paragraph, per
`.okf/practices/a-dimension-sits-in-an-inequality.md`.

**11.41.4 Every figure stays exact in integer nanometres (CR-001).** `69_850_000`, `114_300_000`,
`46_037_500`, with margins of `18_255_000` horizontally and `23_810_000` vertically. **All five are
exact because the inch is exact**: 2.75 = 11/4, 4.5 = 9/2 and 1.8125 = 29/16, each written through
`Len.nmPerInch` rather than through a millimetre rounding, so no `double` appears anywhere between
this ruling and a rendered plate. §11.27.5's observation now has nine instances.

**11.41.5 What it unblocks.** `plate_geometry.dart` stops being **openings-relative** and draws the
plate edge, so the Outlets tab renders a part rather than a set of holes floating in space. §11.7.8
change 2's *"blank plastic above and below, symmetric about the centre"* becomes visible rather than
implied: a 1-port strap now demonstrably sits in the middle of a plate, which is the appearance that
paragraph was written from. `T5.01` at M6 inherits the outline along with everything else.

**11.41.6 What remains open, and it is now a short list.** The **strap's own plastic** outside the
opening, which §11.7.9 B keeps invisible because the cover plate hides it in every elevation this
product draws; and **anything in depth**, which §11.7.9 C files as a box-fill fact and box fill is
not v1. Neither blocks a drawing. **DR-007 §11.7.8's three changes are now fully discharged**, and no
figure anywhere in the keystone geometry is an *"about"*.

**11.41.7 Scope.** **No scope change.** Nothing enters or leaves roadmap §2, no milestone moves, and
no earlier ruling is amended. Two open measurements close.

### 11.42 DR-043 · The field termination gets three entry paths; the default stays Unspecified

**Settled by the user on 2026-08-11**, from board #668: nothing in the product sets
`StructureOrigin.terminationField`, so DR-007 §11.7.2.1's cell-count table has no input and M3-H's
`Arrange` correctly refuses every drop the product can create.

**11.42.1 The default does not move, and that half is a ruling by omission.** `terminationField` stays
**nullable, defaulting to null, meaning Unspecified**. M3-J made it nullable precisely so neither
entry surface would write a value it did not have, and both surfaces' own code said `unterminated`
was *"the nearest true value, not the right one"*. **Nothing here re-introduces that guess.** A drop
created by any path this ruling adds still comes out Unspecified unless somebody said otherwise, and
`Arrange` still reports what it could not place (G4, CR-114).

**11.42.2 Three paths, and the ordering of them is the argument.** The user's question was *"do we
have a GUI path yet? Typing a large amount of text is going to put off a lot of people."* A census
found **five drop-entry surfaces**, of which four are already mouse-driven: `+ Add outlet ▾`, the
Matrix tab, the table's cells, and CSV import. The typed line is one of five, not the only one.

| Path | Gesture | Who it serves |
|---|---|---|
| **`OutletDrop.termination`** on a template | **Zero extra clicks.** `+ Add outlet ▾` already picks a recipe | the mouse-first person, and it is the strongest path we have |
| **`4x Cat6:keystone`** on the drop line | 9 characters per item | the typist, and the ad-hoc mixed line |
| **Multi-select and batch set** on the table | tick rows, set the column once | fixing a house after the fact |

**THE TEMPLATE IS THE LOAD-BEARING ONE AND IT WAS NOT WHAT #668 ASKED FOR.** #668 proposed a
modifier. A modifier serves the person already typing; it does nothing for the person clicking, who
is the one the question was about. A template already says *"TV location = 2 × Cat6 + 2 × RG6"*, and
**how that Cat6 terminates is a property of the recipe rather than of the day**, so putting the field
there makes the mouse path produce fully-specified drops for free. Shipping only the modifier would
have left `+ Add outlet ▾`, the one route a mouse-first person lives in, as the single route that
could not express a termination.

**11.42.3 The item grammar, and why a colon.** Items parse as `count` + `mediaToken` today; the five
existing modifiers (`@service`, `@signal`, `@outlet`, `@pathway`, `@panel`) are **line-level**,
scanned off the end. A per-item termination is therefore a genuine grammar change and not another
modifier.

`4x Cat6:keystone` binds to the item it follows, reads left to right, and costs **9 characters
against `@term=`'s 15**, which matters when AC-018's whole measured script is 433 keystrokes.
**`@term=` was rejected on a second ground that is worse than the character count**: it would have
looked identical to five modifiers that apply to the whole line while applying to one item, with
nothing in the syntax to say so.

**The separator is safe and that was checked rather than assumed.** No media display name or alias in
the seed catalog contains a colon; they contain spaces and slashes (`Cat6 F/UTP`, `16/4`) and the
room separator is the line's FIRST colon, which sits at a different nesting level. An item's own
first colon is therefore unambiguous.

**11.42.4 The vocabulary is core's, and no alias is invented.** A termination token matches on
`terminationLabel`'s spelling and on the enum name, both normalised for case and non-alphanumerics,
so `f barrel`, `fbarrel`, `F BARREL` and `fBarrel` all reach `TerminationType.fBarrel`. **Nothing
shorter is accepted**: `post` does not resolve to `bindingPost`, because inventing trade shorthand in
a parser is how a product ends up with two vocabularies and the refusal is the cheaper teacher. A bad
token is refused with a caret and the accepted list, on `drop_line_parser.dart`'s existing rule that
a refusal quotes the person back.

**11.42.5 The six shipped templates are NOT seeded with terminations.** They stay null.

> **SUPERSEDED BY DR-044 (§11.43) THE SAME DAY, before a line of it was built.** A census found that
> **nothing in this product can author an `OutletTemplate`**, so *"a shop authoring its own template
> says what it terminates in"* describes a capability that does not exist, and this clause together
> with §11.42.2 would have produced a permanently unreachable field. The DR-024 precedent below is
> also mis-cited: that ruling refused a STANDARDS CITATION, and a termination is a recipe fact of the
> same kind as the cable count already in the recipe. **The nine shipped templates are seeded**; see
> §11.43.3 for the five values and their provenance. **This is
DR-024 §11.23.2's refusal repeated deliberately**: that ruling kept `tia570Grade` null on all six
because *"TV location makes no standards claim, and writing one would put a citation in a document
nobody made"*. A termination is the same class of claim. A shop authoring its own template says what
it terminates in; the shipped six say nothing, and produce Unspecified, which is the honest output.

**11.42.6 Multi-select is new machinery and is priced as such.** The table has **no selection model
today**; §4's wireframe draws row checkboxes that nothing implements. The batch path goes through the
same refusing builder a single cell edit does, and the whole batch is **one undo entry**, on
`importCsv`'s reasoning: undoing a batch a row at a time is not undoing a batch. **All or nothing**,
matching `StructureEditorActions.onEdit`'s existing contract, because a batch that wrote nine of ten
rows and reported an error leaves a person to work out which nine.

**11.42.7 Scope.** **No scope change to roadmap §2.** Nothing enters or leaves v1. `OutletDrop` gains
one nullable field, the drop-line grammar gains one production, and the Structure table gains a
selection model it was already drawn with. **M3 gains an issue**, M3-L, which is a decomposition gap
rather than a growth in the sense §11.39 draws: the clause was never in an exit criterion, and
DR-007 §11.7.2.1 named `TerminationType` as *"the hook M3 should read"* while saying nothing about
what writes it. Board #668 is closed by M3-L.

### 11.43 DR-044 · The shipped templates carry terminations, and a euroblock occupies no cell

**Settled by the user on 2026-08-11**, and this ruling exists because **DR-043 §11.42.5 was wrong one
clause deep and a census caught it before a line of it was built.**

**11.43.1 What the census found, and why §11.42.5 could not stand.** §11.42.2 made
`OutletDrop.termination` **the load-bearing path**, on the argument that a modifier serves the person
already typing while the question was about the person clicking. §11.42.5 then left the shipped
templates null, on the reasoning that *"a shop authoring its own template says what it terminates
in"*.

***Nothing in this product can author an `OutletTemplate`.*** There is no command, no editor, and the
only writer of `registries.outletTemplates` anywhere outside test fixtures is `buildSeedRegistries()`
at document creation. `seed_outlet_templates.dart`'s own header says so: *"NO LIBRARY FLOW ... This
ships the master, not an editor for it."*

So the two clauses together would have produced a field that is **null on every template in every
document, for ever, with nothing able to set it**: the fifth instance of
`.okf/practices/a-modelled-field-is-not-a-reachable-one.md`, and the first caught **before** the
field was written rather than in the next milestone. §11.42.2's argument for preferring the template
over the modifier was, as written, void.

**11.43.2 §11.42.5 IS SUPERSEDED, and the cause is a mis-cited precedent rather than a change of
mind.** That clause leaned on DR-024 §11.23.2, which kept `tia570Grade` null on the six named
templates because *"TV location makes no standards claim, and writing one would put a citation in a
document nobody made"*.

**That is a ruling about a STANDARDS CITATION, and a termination is not one.** A citation asserts
conformance to an external document somebody has to be answerable for. A termination is a fact about
the recipe of the same kind as the cable count already in it: *"TV location = 2 × Cat6 + 2 × RG6"*
already says what gets pulled, and saying the Cat6 lands on a punchdown is that sentence continuing.
The precedent was reached for because it looked similar and was about something else.

**11.43.3 The five values, with provenance per row.** The user specified each rather than accepting a
set offered to them, which is why this table has a provenance column at all.

| Media | Termination | Source |
|---|---|---|
| `media.cat6`, `media.cat6a_futp` | **`punchdown`** | Stated by the user. NOT the `keystone` that was offered as the ordinary answer |
| `media.rg6_quad` | **`fBarrel`** | Stated by the user, and it is the part in DR-007 §11.7.9's own reference photographs |
| `media.22_4` | **`euroblock`** | Stated by the user. Zero cells per §11.43.4, so a keypad fills the gang and needs no keystone |
| `media.16_4` | **`bindingPost`** | **NOT ASKED AGAIN.** Already on the record: §11.7.2's supersession rests on the user's *"We use single post keystones, one per conductor"* |
| `media.os2` | **`keystone`** | Stated by the user. An LC keystone, one cell, in the grid like any other jack |

**`punchdown` OVER `keystone` IS THE ROW WORTH NOTING**, because it is where asking beat offering.
The recommended option was `keystone` and the shop's answer was `punchdown`. Face-on the two are the
same object under §11.7.9 B, so the drawing is unaffected and the **Termination Schedule** is not:
the sheet an installer works from now prints what this shop does. Had the seed been taken from the
recommendation, nothing would have looked wrong and one printed column would have been quietly false
on every data drop in every job.

**11.43.4 A EUROBLOCK OCCUPIES ZERO CELLS, closing a gap DR-007 left that M3-H filled by inference.**
§11.7.2.1's table names `keystone`, `fBarrel` and the module family as one cell per `Link` end,
`punchdown` as one, binding posts as one per `Conductor`, and `unterminated` and `fieldConnector` as
**zero**. **It does not mention `euroblock` at all.**

M3-H's `cellsRequiredFor` put it at **one**, silently, in the same arm as `keystone`. That is exactly
the class of inference §11.7.8 change 3 refused on a dimension, made on a count instead, and it
shipped.

The ruling: **zero, in the "nothing is on the plate" row beside `unterminated` and `fieldConnector`.**
A euroblock is a pluggable screw terminal on a **device**, so the conductors land on a keypad or an
amplifier and no jack occupies a cell. The keypad makes it concrete: the device fills the gang, and a
plate sized to give it a keystone as well would be one cell too big on every keypad drop in a house.

**How it was found is the reusable part.** Not by reading the code and not by a test: by **seeding a
value and having to say what the value meant**. The Keypad template could not be seeded without
answering "and how many cells is that". **A fact you have to write down gets audited; a fact you
infer does not.**

**11.43.5 What is still unreachable, stated so it is not read as closed.** There is **still no
authoring surface for `OutletTemplate`**, and this ruling does not add one: DR-024 §11.23.4 already
records which surface edits the registries as unsettled, and DR-033/DR-034 place the library flow in
the community-catalog work. What changes is that the **nine shipped templates now carry the fact**, so
the mouse path produces arrangeable plates today. A shop wanting its own recipe still cannot have one,
and that is a live cap on §11.42.2's argument rather than a discharged one.

**11.43.6 Scope.** **No scope change to roadmap §2.** One clause of a ruling dated the same day is
superseded, one gap in DR-007 §11.7.2.1 is closed, and nine seeded records gain a field they were
always going to need. `kSchemaVersion` does not move: an omitted-when-null key is additive and an
older reader skips it (CR-117).

**11.43.7 A SENTENCE OF THIS RULING WAS FALSE AND THE GOLDENS CAUGHT IT WITHIN THE HOUR.** §11.43.6
first read *"`registries.outletTemplates` is `{}` in every shipped starter and in every document ever
written, so the seed change costs no existing file a byte"*. **All four starters carry all nine
seeded templates**, because `apps/rackmate/tool/starters/authoring.dart` assigns
`buildSeedRegistries()` into each, and `starter_assets_test.dart` failed on all four the first time
the suite ran. They are regenerated with the seed and the four golden files change.

**The claim was not invented here; it was INHERITED, and that is the part worth keeping.** It is a
verbatim copy of a paragraph that has sat on `OutletTemplate.tag` since DR-022, and **it was already
false there**: those same starters carry `tag` on six templates and `tia570Grade` on three, on disk,
today. The chain ran doc comment, to second doc comment, to normative ruling, in three steps and one
afternoon, and each step looked like a citation of the one before it.

**Two rules the corpus already had, and neither fired.**
`.okf/practices/two-documents-agreeing-is-not-verification.md` says a citation is evidence of intent
rather than of existence; here it was not even two documents, it was one sentence read twice. And
counts written into prose are recorded in this project's own memory as a liability, because
**a sentence asserting a count is not checkable by reading the sentence.** What caught it was a test
that reads the bytes. The correction is therefore not only to the wording: the claim is now stated
where a golden can contradict it, and both doc comments say what the starters actually contain.

### 11.44 DR-045 · The field-crimped RJ45 plug, and an outlet that needs no plate

**Settled by the user on 2026-08-12**, from a request grounded in two installation facts rather than
in the model: *"some instances (AVOIP/HDBT transceivers, namely) recommend not using
keystones/patch cables for reliability reasons, and most AP locations ... are on low voltage boxes,
but feature no plate/strap due to the AP mounting directly to the box."*

**11.44.1 `TerminationType` gains `rj45Plug`, printing `RJ45 PLUG`.** A Cat6 run crimped into a male
RJ45 plug and pushed straight into the device. **It is not `keystone` and it is not `punchdown`**:
both of those are a jack, and the whole point of this termination is that there is no jack. Nor is it
`fieldConnector`, which names no connector at all and would leave the Termination Schedule saying
nothing useful to somebody deciding whether to reach for a crimper or a punchdown tool.

**The reason is reliability rather than tidiness, and it belongs in the record.** A keystone plus a
patch cable puts **two extra mated connections** on a link carrying uncompressed video, and AVoIP and
HDBaseT vendors recommend a continuous run for exactly that. The product now lets a drawing say so.

**11.44.2 IT OCCUPIES ZERO CELLS, and this time the question was asked rather than assumed.** The
plug goes into the device, so nothing sits in a keystone cell. It joins `euroblock`, `unterminated`
and `fieldConnector` in §11.7.2.1's *"nothing is on the plate"* row.

**§11.43.4 is why this was asked.** M3-H put `euroblock` at one cell silently, on an inference nobody
wrote down, and it took a seeding exercise to surface it. The same guess was available here and was
not taken. **A termination's cell count is now a question this project asks out loud every time the
enum grows**, which is the cheapest possible form of that lesson.

**11.44.3 The shipped AP template changes from `punchdown` to `rj45Plug`.** One Cat6 to an access
point that **mounts directly to the box**, so the run terminates in a plug and the box needs no plate
at all. This is the first seeded value to change since DR-044 set it, and it regenerates the four
starter goldens again.

**`TV location` DELIBERATELY DOES NOT CHANGE.** The user said *"some instances"* recommend it, and a
template asserting a plug for every TV in every job would put a claim in six records nobody made,
which is DR-024 §11.23.2's refusal and DR-044 §11.43.2's correction of it read together: a
termination is a recipe fact, and *"this recipe sometimes does X"* is not one. The drop line's
`:rj45 plug` covers the exception, which is what §11.42.3 built it for.

**11.44.4 AN OUTLET WHOSE DROPS ALL TERMINATE OFF-PLATE NEEDS NO PLATE, AND THAT IS DERIVED.** An AP
box with one `rj45Plug` drop is **finished**: no gangs, no strap, no cover plate, nothing missing.

***The product could not say that, and the failure is G4's.*** `_NoGangs` reads *"This outlet has no
gangs yet. Add one, or press Arrange to size the plate from the drops that land here"*, which is the
**undecided** sentence. A correctly-finished AP box has read as unfinished work since M3-H. That is
DR-007 §11.7.4's blank-insert-versus-empty-cell distinction, one level up and got wrong: *nobody has
said* and *somebody said no plate* are different facts and the surface collapsed them.

**THREE STATES, NOT TWO**, and the third is the one G4 cares about:

| State | What it means |
|---|---|
| no drops land here yet | nothing to say. Not plateless, just empty |
| drops land here and **every one is known to terminate off-plate** | **needs no plate.** Settled |
| drops land here that need cells, **or whose termination is unknown** | a plate is missing, or nobody can say |

**AN UNKNOWN TERMINATION FALLS IN THE THIRD ROW AND NEVER THE SECOND.** "Needs no plate" asserted
over a drop nobody has terminated is a guess, and it is the guess that would make a materials sheet
omit a part somebody has to buy.

**11.44.5 DERIVED, NOT STORED (CR-107).** `PlateFill` already computes every input: an outlet whose
drops need zero cells with zero gangs and zero unknowns already returns `isSettled`. **The derivation
was correct and only the copy was wrong.** A stored `hasPlate` flag would be the second copy of one
physical fact that CR-107 deleted `StructureDrop` over, and it would go stale the first time somebody
changed a drop's termination.

**11.44.6 What this does NOT settle, raised by the user in the same breath.** Asked how many cells a
plug occupies, the answer was *"zero, but the plate is a separate question"*: some off-plate runs
still come through a **pass-through or brush plate**, which occupies no strap cell and **is a
purchasable line item**.

**That is a third object and this ruling does not model it.** §11.7.8 change 1 already separates a
strap from a cover plate; a pass-through plate is a plate with **no strap behind it**, which
`PlateFill.coverPlateGangs` structurally cannot express, because that getter returns `gangs.length`
and a plateless outlet has zero gangs by construction. It needs its own ruling on whether the plate
is a property of the **outlet** or of the **drop**, and then a materials line. **Filed, not
smuggled in.** Nothing is wrong today; the materials sheet simply does not know about a part that
gets bought.

**11.44.7 Scope.** **No scope change to roadmap §2.** One enum value, one seeded template, one
derived getter and one corrected sentence on a surface. `kSchemaVersion` does not move: enum values
serialize by name, so no document in existence contains this one.

### 11.45 DR-046 · The rack end is its own termination, and nothing infers it

**Settled by the user on 2026-08-12**, reported as *"the rack termination shouldn't be automatically
set by the field termination ... 90% of the time we'll have the same termination on both ends for a
CAT6, but a speaker run might have a phoenix connector on the rack side, but binding posts on the
other."*

**11.45.1 IT WAS WORSE THAN AUTOMATIC. THERE WAS ONLY ONE FIELD.**
`StructureOrigin.terminationField` is documented as *"how the WALL-PLATE end is finished"*. The
`FIELD TERM` column read it, and the `RACK TERM` column read it too, by way of
`_terminationOf`. **Two columns, one value, since M3-C.**

So the speaker run above was not awkward to express, it was **inexpressible**: recording binding
posts in the room forced the schedule to claim binding posts at the panel. And the column most people
saw was the one showing the other end's data, because `RACK TERM` was a **default** column and
`FIELD TERM` was **optional**.

**`StructureOrigin` gains `terminationRack`**, beside `terminationField`. That class already held
`fieldLabel` and `rackLabel`, so holding both ends of the termination is the shape it was already in.

**11.45.2 NOTHING INFERS ONE FROM THE OTHER, AND THE 90 % IS THE ARGUMENT AGAINST DOING SO.** The
user's own figure is that nine Cat6 runs in ten match at both ends. **Defaulting on that basis
re-creates precisely the defect being removed**: a schedule cannot then distinguish a value somebody
stated from one the product copied, which is G4's complaint in its purest form. A run whose panel end
nobody has decided prints the unknown marker.

**The convenience is a GESTURE, not a default.** `Rack term: same as field` on the batch bar fills
`RACK TERM` from `FIELD TERM` on the selected visible rows. It writes **real** values because a
person asked for them, it lands as **one** undo entry, and it **skips rows whose field end is
unknown** rather than copying *"nobody has said"* onto a second column, which would make the two
agree for the wrong reason.

**11.45.3 The drop line takes a second colon: `2x 16/4:binding post:euroblock`.** Field first, rack
second. **One colon still means the field end alone**, so every line written under DR-043 parses
unchanged. A bad rack token refuses the **whole line** with its own caret, on the same vocabulary as
the field end: a termination is a termination, and the end it is on is which colon it followed.

**11.45.4 `FIELD TERM` becomes a default column.** Both ends side by side is what makes the
distinction teach itself, and until now the visible one was showing the wrong end. It also **leaves
the as-built group**, because a group that toggles a column already on screen turns it **off**, which
is not what *"show me the as-built set"* means.

**11.45.5 THE PRINTED TERMINATION SCHEDULE IS DELIBERATELY UNCHANGED.** `ScheduleColumnId.term` still
resolves to the field end. That sheet is **M6's under DR-027** and its column set is a sheet change,
not an editor change; a twelve-column landscape sheet gaining a thirteenth is exactly the kind of
thing §11.26 moved out of M3. **Filed as board #679, not smuggled in.** The editor is correct now and
the sheet is unchanged, which is a stated inconsistency rather than a hidden one.

**11.45.6 What this does NOT add.** **`OutletDrop` gains no rack termination.** A template says what
a recipe pulls and how it lands in the room; what it lands on at the panel depends on which panel,
which is a fact about a job rather than about a recipe. Nothing prevents adding one later, and
nothing today would populate it.

**11.45.7 Scope.** **No scope change to roadmap §2.** One nullable field, one grammar production, one
column moved from optional to default, one gesture. `kSchemaVersion` does not move: the key is
omitted when null, and it is null on every home run ever written because the field did not exist.

---

### 11.46 DR-047 · A gang can be fitted with a pass-through, and the plate follows from what is in it

**Settled by the user on 2026-08-12**, answering the question DR-045 §11.44.6 filed as board #678:
a pass-through or brush plate *"occupies no strap cell and IS a purchasable line item"*, and nothing
in the model could say so.

**11.46.1 THE QUESTION WAS ASKED AS "OUTLET OR DROP" AND THE ANSWER IS NEITHER.** §11.44.6 named two
places the fact could live. A census before pricing found a third, already built and already carrying
the right distinction: **`Gang.strap` is nullable, and null means *nobody has picked a part yet***. A
brush plate is a gang opening somebody has **decided** gets no strap, which is a different fact from
one nobody has reached.

**That is §11.7.4's distinction at a third scale, and the two below it are already ruled.** A cell
holds nothing (undecided) or a `BlankInsert` (decided, and a purchase). An outlet has no drops
(empty) or every drop off-plate (**needs no plate**, §11.44.4). And now a gang has no fitting chosen
(undecided) or a pass-through (decided, and a purchase). **Each of the first two was got wrong once
and cost a correction**, so the third is ruled before it is built rather than after.

**Why not the drop.** `StructureOrigin.outletId` is **non-nullable**: every drop in the document
already has an outlet, so the drop buys no expressiveness. It costs plenty. Three runs through one
brush plate become three claims about one physical object; two drops sharing a box can disagree about
what covers it; and a materials line would have to de-duplicate by `outletId` to recover the
outlet-level answer, which is the outlet option computed the hard way and one milestone later.

**Why not a plate kind on the outlet.** It cannot express a **mixed plate**, one 2-gang cover plate
with a keystone strap behind one opening and a brush at the other, which is an ordinary thing to
install. It is also a **second copy of a fact the gangs already carry**: a gang holding six keystones
requires a Decora opening, so a document could assert `brush` over it and nothing would catch the
contradiction. CR-107 deleted `StructureDrop` over exactly that shape. And it would be null on every
outlet in every document ever written, so under G4 every plate in every job would read *"kind
unknown"* on the day the field shipped.

**11.46.2 `Gang.strap` becomes `Gang.fitting`, and `Strap` is one kind of fitting.**

```
GangFitting (sealed, nullable)
  ├─ Strap        W x H cell grid, exactly as today  [DR-007 §11.7.1]
  └─ PassThrough  a hole in the plate, with a style  [NEW]
```

**Null still means UNKNOWN** and is still an absent key on the wire (G4, CR-114). The rename is not
cosmetic: a `Strap?` typed field makes *"this opening is a brush"* unsayable, and the sealed switch
is what forces every reader to say which of the three states it means. No convenience getter returns
null for a pass-through, because that is precisely the collapse this ruling removes.

**11.46.3 Two styles, `brush` and `bullNose`, and the vocabulary was ASKED.** The user names three
parts they buy: a **whole brush or pass-through plate**, a **Decora-format brush insert**, and a
**bull-nose or grommet plate**. The first two are the same opening in two forms and §11.46.4 derives
which; the third is a different opening and is the second enum value.

**A keystone-format brush insert was offered and DECLINED**, so there is **no fourth `CellOccupant`**
and nothing here touches a strap's cells. Recorded because a declined option is evidence and an
unasked one is not: this is the enum-growth question §11.44.2 made standing, asked and answered in
the same breath as the fitting itself.

**11.46.4 The plate is DERIVED from the fittings, and the rule is total.**

| The gangs | The plate | The inserts |
|---|---|---|
| none at all | **no plate** (§11.44.4's plateless outlet, unchanged) | none |
| every one a pass-through, **all one style** | one N-gang plate **of that style** | none |
| any gang holds a strap, or the styles differ | one N-gang **Decora** cover plate | **one per pass-through gang**, each of its own style |
| any gang's fitting unchosen | as above for what IS chosen, **and the unchosen are counted** | a **lower bound**, read beside that count |

**The middle two rows are the user's decision and the reasoning is stock rather than model.** Nobody
manufactures every Decora-plus-brush combination, so a plate with a strap behind one opening and a
brush at another is genuinely bought as a standard plate plus an insert. **Mixed styles fail the same
way**, which is why the rule keys on *one style* rather than on *all pass-through*: a plate that is
brush at one opening and bull-nose at the next is not a part either.

**No field records which form was bought, and §11.27.2 is why.** A derivation with its reasoning
written down outranks a stored field without one, so a shop that stocks Decora plates and inserts
rather than brush plates can be served later by an override that wins **with nothing to withdraw**.
The alternative was a plate-form field null on every outlet in every existing document, which buys a
purchasing preference at the price of a G4 unknown on every plate in the product.

**ROW 4 CHANGES A SENTENCE THE PRODUCT USED TO SAY, AND THE CHANGE IS THE POINT.** A plate with
openings but nothing fitted in any of them used to read *"3-gang cover plate"*, which was true when
there was one kind of plate and is a guess now: an unfitted opening could still become a brush and
make the whole plate one integral part. It reads *"3-gang plate, kind unknown"* until somebody says.
**One strap anywhere settles it**, because a strap needs a Decora opening and no later decision
changes that, so **the finished plate reads exactly as it always did** and only the half-built one
is newly honest.

**11.46.5 What the counts do, and one sentence of DR-045 that this changes.** `PlateFill` gains a
count of pass-through gangs and renames `strapsUnchosen` to `fittingsUnchosen`, because **a gang
destined for a brush was never a strap nobody chose** and a name that has stopped describing its
field is worse than a missing one. A pass-through provides **zero cells** and blocks nothing, so a
plate whose every opening is decided is `isSettled` whether or not any of them holds a jack.

**`needsNoPlate` does NOT move, and the reason is the correction.** It stays `gangCount == 0`: an
outlet covered by a brush plate is **not a plateless outlet**, it is an outlet with a plate that has
no jacks in it. §11.44.6 wrote that a pass-through plate is *"a plate with no strap behind it, which
`PlateFill.coverPlateGangs` structurally cannot express"*. **That was true only while a brush had no
gang.** Give the opening its gang and the count falls out of `gangs.length` exactly as it already
did, and the getter needs no change at all. See §12.19.

**11.46.6 `Arrange` never fits a pass-through and never destroys one.** `planPlateArrangement` sizes
straps from what the drops need in cells; a pass-through is a decision about a part, made by a person,
and a plan that invented one would be asserting a purchase nobody made. The other direction matters
more: a run of `Arrange` over an outlet whose openings a designer has already brushed must not
silently replace them with straps sized for zero cells.

**11.46.7 Scope.** **No scope change to roadmap §2.** One sealed type, two enum values, one command,
one picker, one derived rollup. **`kSchemaVersion` does not move**: the `strap` key is written exactly
as before for a strap, and `passThrough` is a key no document in existence contains, which is CR-117's
additive case.

---

### 11.47 DR-048 · A network value is a dated as-built fact, and `T6.50` ships in v1

**Settled by the user on 2026-08-12**, from a request for static IP settings on the sheets:
*"when a service tech looks at a rack, the first thing they usually want to do is connect to the
problem system ... having the IP scheme of every fixed device in the system right there on the
sheets would be incredibly valuable for those late-afternoon rats nest rack troubleshoots."*

**11.47.1 THE MODEL HAS CARRIED THIS SINCE M0 AND NOTHING HAS EVER WRITTEN IT.**
`NetworkConfig{hostname, ip, subnet, gw, mac, vlans[], portRole}` sits on `Port` (docs/02 §4.5), is
encoded and decoded by `json_codec.dart`, and byte-round-trips. `DeviceInstance.macAddressPrimary`
sits beside `serialNumber`, `assetTag`, `firmwareVersion` and `installedAt` in the same condition.

A census taken before this was priced found the assignment count:

```
grep -rn "network\s*=\|network:" --include=*.dart .
→ json_codec.dart:1361:  network: decodeNullableObject(
```

**One hit, and it is the decoder.** Not a command, not a widget, **not a test fixture**. Every
earlier instance of this pattern had at least a fixture; this is the pure case, and the only way a
`NetworkConfig` has ever existed in this product is a hand-edited `.rmpj`. It is the **seventh**
instance of the practice, and the **first found by reading rather than by using**, because the
request was censused before it was estimated rather than after.

**It reads as nearly-shipped from three directions**, which is why nobody caught it: the field is
modelled, the codec works, and `sheet_def.dart`'s `kReservedNcsIds` **reserves `T6.50` for "the v1.1
Network/IP Schedule"**. A reserved sheet number is evidence of intent doing duty as evidence of
existence, which is §11.19.7's failure wearing a sheet id.

**11.47.2 The management address is a DEVICE fact and the per-port facts stay on the port.** The
user's constraint is the one that settles it: *"switches will have static IPs marked out by devices
themselves."* A managed switch has **one** management address and **forty-eight** ports, so an
address hung off a port is a fact filed under an arbitrary one of them.

`DeviceInstance` **gains `network: NetworkConfig?`**, beside the as-built identity block it already
carries. `Port.network` is unchanged and keeps what it is for: VLAN membership, `portRole`, and the
address of a device that genuinely has more than one.

**The existing type is reused rather than a scalar added**, because a static assignment that records
an address without its subnet and gateway is not usable by the tech it exists to serve, and
`NetworkConfig` already carries both with a working codec. **`kSchemaVersion` does not move**: the
whole `network` key is absent when null, which is CR-117's additive-optional case, and
`macAddressPrimary`'s `putIfNotNull` is the pattern being copied.

**11.47.3 EVERY NETWORK VALUE CARRIES `verifiedOn`, BECAUSE G4 CANNOT SEE STALE.**
G4 handles *unknown* completely: null, absent key, counted, never estimated. It has **no mechanism
for a value that was true and is not**. An address recorded in March and re-assigned in June is not
null, is not counted, and prints in the same typeface as a fact.

That failure is worse here than almost anywhere else in the product, because the reader is a tech
standing at a rack at the end of a day, and a confidently wrong address costs twenty minutes of
proving it wrong. So `NetworkConfig` **gains `verifiedOn: DateTime?`**, and a value without one
renders as **unverified** rather than as fact.

**A document-level "network data as of" date was refused.** The real case is four devices
re-addressed last week and thirty untouched, and one date per project cannot tell them apart; it
would launder the stale thirty into the fresh four's credibility.

**11.47.4 `T6.50` Network/IP Schedule ships in v1, in M6.** This is a **§8.3 amendment** and it
**supersedes DR-005 §11.5.3**, which put `T6.40` and `T6.50` *"out (v1.1 / v2)"*. **`T6.40` Power
Schedule does not move** and stays exactly where DR-005 left it; only `T6.50` is amended, on the
ground that the data is already in the format while the power data is not.

**The sheet is `AUTO`, iff at least one device carries a network value**, on the pattern `T6.20`
(Unused Home Runs) and `T5.01` (Plate, Panel & Pinout) already set. A residential job with no managed
switch must not print a blank page, and an empty sheet in a client deliverable reads as an omission
rather than as an absence.

**The set becomes twelve slots: nine `ON` and three `AUTO`.** It was eleven, nine and two, and the
count is stated in **six places across four documents**, every one of which is edited by this ruling
rather than left to be found. It becomes thirteen when `T1.01` lands ahead of it (docs/12 §1).

**11.47.5 Roadmap §2 never carried this at all, in any release.** `grep -in network docs/09-roadmap.md`
returns **nothing**. So the amendment is doing two jobs: resolving DR-005's *"v1.1 / v2"* hedge to a
single destination, and putting a row in the one scope list §8.3 recognises. **A ruling deferring
something is not the same as a scope list carrying it**, and the gap between those two is where this
sat for the whole project.

**11.47.6 The surface is columns first and the inspector second.** Toggleable columns in the table
via `⚙ Columns`, with `Ctrl+D` fill-down and the batch bar, plus a **read-only** summary in the
device inspector.

The table is primary because the alternative fails the same test DR-020 §11.19.2(5) already applied
to the as-built tally: **an installer closing out a job needs one table they tab down, not sixty
inspector visits.** The inspector summary is read-only so there is exactly one place a value is
written, which is what keeps the batch bar and the panel from disagreeing about what was set.

**11.47.7 The address launches a browser, behind a confirmation that shows the URL.** Taken against
the recommendation, on the user's stated workflow: a copy of the project lives at the client's home
and changes are saved back to it, and the trade already runs remote-access systems (UniFi with
Teleport, OvrC, Eero Insight, Nice Management Cloud, BlueBolt) that put a tech on that network
routinely. **The objection was that the drawing machine is not on the rack's network; the answer is
that in this trade it frequently is**, and techs already know which system to reach for and when.

The confirmation shows the target before anything opens, so the gesture is never a silent navigation
to a user-supplied address.

**11.47.8 Scope bound: modelled devices with fixed addressing, and not an inventory.** From the
user: *"a client personal device is very unlikely to have a static IP, so it doesn't need one."*
The schedule covers devices this product already models that carry a fixed address. It is **not** a
DHCP client list, it does not discover anything, and nothing on it is derived from the live network.

**11.47.9 A G4 DEFECT IN THE EXISTING CODEC, EXPOSED BY MAKING THE FIELD REACHABLE.**
`_encodeNetworkConfig` opens `final json = <String, Object?>{'vlans': n.vlans};`, so `vlans` is
written **unconditionally** and an untouched list encodes as `"vlans": []`. Under CR-114 that says
*measured zero VLANs* where the fact is *nobody said*, and it is the `designatorLocked`
anti-pattern the bundle already warns is copied by proximity.

It has never mattered, because nothing ever constructed a `NetworkConfig`. **It matters the moment
this ships**, and on a device-level record it is the common case rather than the rare one. It is
fixed with this work rather than filed, because filing it means shipping the defect and the fix in
that order.

**11.47.10 Scope.** **v1 grows by three items**: `DeviceInstance.network`, `NetworkConfig.verifiedOn`,
and the `T6.50` sheet. **M6 grows** by one `AUTO` sheet and moves within its `M`; docs/12 §5.5's
slot arithmetic is edited. **M4 is untouched**: this is instance data, not template data, and no
device template gains a field.

**What it does not rule.** Whether an address is **validated** as well-formed, or checked for
collisions inside a project. Both are DRC rules, both belong to M5's catalogue with an AC-051 fixture
pair each, and neither is added here: `LEN-002`'s history (§11.19.7) is the precedent for a rule
shipping one milestone after the field it reads. It also does not rule `T6.40`, does not add
discovery of any kind, and does not give `TemplateBody` a network field.

---

### 11.48 DR-049 · The tabular exports ship in v1: rows out, and a label sheet that is not a sheet

**Settled by the user on 2026-08-12**, from a request for label exporting: *"seems like a very cheap
add; all the data's there. Just a matter of formatting for label printers/label sheets."* Taken
together with a request to export to D-Tools and XTEN-AV, because the two are one object.

**11.48.1 It discharges board #653, which has been waiting for exactly this.** M3-F/7 was filed as
`RULING NEEDED, deferred` rather than built, and the reason it was filed that way is the test worth
keeping: docs/07 §5.3's closing line promises the CSV round trip, **roadmap §2 does not name it**,
and docs/07 is derived and priority-3. *A promise living in exactly one derived document is a scope
question for the user, not a hole to quietly fill.* That is now answered rather than still open.

**11.48.2 CSV/TSV export ships in v1, and the round trip is a property rather than a phrase.**
`import(export(doc))` must reproduce the same rows. It is the CSV analogue of
CR-117 and it is testable, which matters because *"the round trip"* has been an aspiration in
docs/07 since M3-F and nothing has ever asserted it. **The reader stack already exists**
(`csv_reader.dart`, `csv_mapping.dart`, `csv_import_plan.dart`, `csv_import_apply.dart`,
`csv_row_resolve.dart` and the dialog); only the writer is missing.

**11.48.3 THE CSV WRITER IS M6's, NOT M3's, ON DR-027's SEAM.** #653 sits under M3-F today. M3's
exit criterion is a 60-drop rough-in, and §11.26 already ruled that **M3 owes derivations and M6 owns
outputs**. A CSV file is an output. Moving it is the same seam applied a second time rather than a
new judgement, and it keeps a milestone that is one human act from closing from growing on its way
out.

**11.48.4 The label sheet ships in v1, and it is NOT a slot in the sheet set.** This is the clause
that took the most thought and it follows from DR-005: **the sheet set is a client deliverable**. A
page of adhesive labels is a shop artifact. Putting it in the set means either handing a homeowner a
sheet of labels or inventing a per-sheet suppression rule for client exports, and the second is a
mechanism built to hide a mistake made by the first.

So it is a **separate export action** with its own dialog. **The twelve-slot count does not change**,
`SheetRole` gains nothing, and DR-048's arithmetic stands as written.

**11.48.5 `SheetSize` gains US Letter portrait, and the enum has exactly two values today.**
`ansiBPortrait` (11 × 17) and `ansiALandscape` (11 × 8.5). Neither is Letter portrait, so **the sheet
machinery physically cannot emit an Avery-style page**; this is an enum change, not a layout change.

**It is the same enum `D14` already owes A4/A3 on** (docs/13, board #453): docs/08:509 requires a
non-US platform locale to substitute A4/A3 and `SheetSize` has neither, so **a Windows machine in a
metric locale has that problem today**. The two are done together or the second is done twice.

**11.48.6 What prints on a label is the dual labels, both ends, and nothing is invented.**
`fieldLabel` and `rackLabel` already exist on every cable and CR-044, AC-025 and AC-047 already
require both to print. The label export is a different **arrangement** of a derivation that is
already correct, which is the whole reason it is cheap.

**11.48.7 NO PRINTER DRIVERS, AND THIS IS A REFUSAL RATHER THAN A DEFERRAL.** Brother P-touch, Dymo
Rhino and Epson LabelWorks each speak a different dialect. An export nobody has run on the actual
hardware scores `VACUOUS` under docs/12 §0's legend, and this project already carries **two unfunded
print matrices** (AC-058 `D11` and `D13`) that nobody has executed. Adding a third is how the first
two stay unexecuted for ever.

**A CSV is what covers them.** Every label program on the market imports one, the mapping is the
user's to make once, and it needs no hardware this project does not have.

**11.48.8 D-TOOLS AND XTEN-AV GET NO EXPORTER, AND THE REASON IS TESTABILITY.** D-Tools SI is a
licensed Windows/SQL product; XTEN-AV's API sits behind a commercial agreement. **An exporter for a
format that cannot be opened in the target application cannot be demonstrated**, which is the same
`VACUOUS` mark as above and a support channel staffed for ever against a schema that changes on
somebody else's release cadence.

**It is also a positioning claim.** docs/00 §4.2 commits this product to pricing against AVSnap and
Stardraw, **explicitly not against D-Tools**, and board #91 already warns that changing what the
corpus asserts about positioning is an amendment rather than a doc edit. A dedicated exporter says
*"we are the drawing front end for your D-Tools workflow"*, which is a smaller product than the one
roadmap §2 describes. **The generic CSV serves the same user** through an import wizard those
products already ship, with no vendor coupling and no test environment nobody owns.

**11.48.9 Scope.** **v1 grows by three items**: the CSV/TSV writer with an asserted round trip, the
label export action with its dialog, and `SheetSize.usLetterPortrait`. Roadmap §2.1 gains a row it
has never had. **M6 grows** by the writer and the label action; **M3 shrinks** by #653 moving off it.
**The sheet set does not grow**, so §11.47.4's twelve slots are unaffected.

**What it does not rule.** Which columns a CSV carries by default, which is a surface decision for
the task. Not the label media size, beyond the page being Letter portrait. Not a D-Tools or XTEN-AV
integration in any release, and **that half is a refusal, not a deferral**: no gate reopens it, on
DR-004's pattern.

---

### 11.49 DR-050 · Plan geometry fills the room estimate that already exists, and it buys cable

**Settled by the user on 2026-08-12**, from a request for Specifi-styled wire-run length estimation:
*"room dimensions can be derived from the user placing vertices on the plan view ... and ceiling
heights can be easily specified."*

**11.49.1 THE CENSUS CORRECTED THE QUESTION BEFORE IT CORRECTED THE ANSWER, AND THIS RECORD LED WITH
THE WRONG FRAMING FIRST.** The request was initially put to the user against the claim that
DR-020 §11.19.2(2) forbids an estimate from entering the footage rollup. **It forbids a BOUND**,
which is not the same object, and the difference is the whole ruling:

| Source | Exists? | Reachable? | Sums into a purchase? |
|---|---|---|---|
| `cut` | yes | yes | **yes** |
| `outletNominal` | yes | yes | **yes** (DR-026 §11.25.2) |
| `roomEstimate` | yes | **yes**, `Location.estimatedRunLengthFromRack` | **yes** |
| `planLowerBound` | not built | not built | **no**, DR-020 §11.19.2(2) |

`cable_footage.dart`'s `_isQuantity` returns `true` for `roomEstimate` today, and says why in its own
comment: *"AC-024's own example is an ESTIMATED total plus waste, so an estimate is a quantity here.
`estimatedCount` is what keeps the figure's standing visible."* **So the shipped position was never
that estimates may not buy cable.** It is that they may, and that the count of them is reported
beside the total.

**11.49.2 THEREFORE NO NEW TIER, AND THIS IS THE RULING.** `ScheduleLengthSource` gains nothing.
Plan geometry becomes a **better way to populate `Location.estimatedRunLengthFromRack`**, a field that
already exists, is already written by `set_entity_property_command.dart`, already ranks below
`outletNominal`, and already sums.

A fourth tier would buy a provenance distinction, and the user's own ground is that the distinction
does not pay here: *"it's used to estimate quotes, with a healthy margin for error ... in most A/V
companies, wire is a consumable."* **Machinery for a distinction nobody acts on is machinery that
gets read as significant by the next person.**

**11.49.3 A COMPUTED VALUE IS MARKED AS COMPUTED, AND THAT IS DR-046'S LESSON HONOURED RATHER THAN
CONTRADICTED.** When geometry proposes the figure, the field records that it was **proposed rather
than typed**. §11.45.2 ruled that nothing may copy a field termination into the rack termination,
because a schedule that fills the second column can no longer tell a stated value from an assumed
one, and the same hazard exists here.

**What differs is the cost of being wrong, and that is why the answers differ.** A termination is a
**discrete part**: a wrong value orders a keystone jack for an F barrel, and no margin absorbs it.
A length is a **continuous estimate consumed with a margin the user controls**, and the user's
trade evidence is that the margin is wide and the material is a consumable. **Different failure
costs justify different defaults**, and a rule applied without that test would have forbidden a
feature on the strength of a precedent about a different kind of fact.

The marker is one nullable field and it is cheap; it exists so that a later reader asking *"did
somebody measure this room or did the software guess it"* has an answer, which is the question
`estimatedCount` already exists to keep askable.

**11.49.4 DR-020 IS NOT SUPERSEDED AND MUST NOT BE READ AS WEAKENED.** `planLowerBound` remains
forbidden from the rollup. **The route is still discovered rather than designed**, the route
polyline, `routingFactor` and `slackAllowance` are still deleted and still not to be re-argued from,
and §11.19.1's evidence stands: framing decides the path and framing is not knowable when the plan is
drawn.

**A room's dimensions are not a route.** What this ruling adds is a way to compute a *room-level*
figure from measured geometry instead of from a person's recollection, into a tier that already
existed for room-level figures. **A per-drop figure derived from a drawn path remains forbidden.**

**11.49.5 Scope.** **v1 grows by two items**: the geometry-to-estimate derivation and the
computed-versus-typed marker. Both land with the **Plan view**, which is where the vertices and the
calibration live, and it is already a v1 epic sequenced before M6 (DR-029). `Location` gains a
ceiling height if the derivation needs one, which is a field question for the task rather than a
ruling.

**What it does not rule.** The formula. Whether a rise is added per storey, whether the figure is
straight-line or perimeter, and what margin if any is folded in are all decisions for the task, and
all of them are cheaper to change than a provenance tier. It also does not touch `LEN-002` or the
waste factor.

---

### 11.50 DR-051 · Documentation is referenced and never embedded

**Settled by the user on 2026-08-12**, from a request for embedded manuals and spec sheets: *"who
wants to frantically try to use their Google-Fu to find documentation for some obscure device that's
locked behind a dealer portal they don't have access to at the end of the day."* The user raised file
size as the concern; three other grounds turned out to bind harder.

**11.50.1 THE EXPORTER STRUCTURALLY CANNOT DO IT TODAY.** docs/08 §2.2, written long before this was
asked: *"the `pdf` package writes documents, it does not import pages."* That is a capability limit
of the only PDF library in the tree, not a preference, so embedding a manufacturer PDF into the sheet
set is **impossible** rather than expensive.

**11.50.2 DR-015 ALREADY REFUSED THE CONTAINER THIS WOULD NEED, AND THE ARGUMENT TRANSFERS INTACT.**
§11.15.4 ruled `.rmda` a single JSON file and not a zip, because the zip existed only to carry binary
members, images are cut, and a zip buys **zip-slip protection, entry-count limits, uncompressed-size
limits and image-decode bounds** as new attack surface with nothing on the other side. Embedding
documents reopens every one of those and **adds parsing untrusted PDFs from the internet**, which is
a class of surface this product has none of today.

**11.50.3 The arithmetic is worse than the concern that raised it.** A whole document is ~870 kB of
uncompressed JSON (§11.38.1). One mid-range AVR manual is 8 to 40 MB, and base64 in JSON adds a
further third. A forty-device house would carry a payload **one to two orders of magnitude larger
than the drawing it decorates**, and it would destroy the diffability that CR-117, DR-039's document
diff and any future sync all depend on.

**11.50.4 The ground the request did not raise, and it is the one that ends it.** Manufacturer
manuals are **copyrighted**. Redistributing them inside a project file that is emailed to clients is
redistribution, at scale, by a product whose users are professionals. **The dealer portal the request
complains about exists precisely to control that.** A CC0 catalog (DR-036 §11.35.3) cannot carry
them, and the output exception at §11.35.4 does not reach content the project never had the right to
embed.

**11.50.5 The ruling: a citation, and a date.** `TemplateBody` carries a reference block: **URL,
document title, revision, and a retrieved-on date.** No file. It prints on `T5.01` and in the
equipment list.

**The date is what makes it honest, and it is DR-048's mechanism reused deliberately.** §11.47.3
added `verifiedOn` because **G4 handles unknown and has no mechanism for stale**. A link has exactly
that failure: it rots silently, and a rotted link with a retrieval date at least tells a tech how old
the claim is. An embedded file has the same failure and cannot be dated out of it, because a manual
embedded in 2026 documents firmware 1.2 while the device ships 3.0 in 2028, authoritative-looking and
wrong.

It also **reuses machinery that exists**: CR-061's provenance gate and `assets/catalog/sources.md`
already do this exact shape for catalog data.

**11.50.6 Embedding is refused permanently, on DR-004's pattern.** Not v1, not v1.1, not v1.2, not
v2. **docs/08 §2.2's "the datasheet appendix defers to v2" is superseded** (§12.21): a deferral
implies a release in which the objections lapse, and none of the four does. The library limit could
be engineered around; the copyright ground cannot.

**11.50.7 Scope.** v1 grows by one item, the reference block and its printing. No container, no
binary member, no new dependency, no `SheetRole`. **v2 does not shrink, because it never held the
row**: the appendix's v2 promise lived in two derived documents and DR-005's bullet, and roadmap §2
has never mentioned a datasheet in any release (§12.21). Roadmap §2.5 gains it as a ruling.

---

### 11.51 DR-052 · Git sync is v1.2 and gated on evidence; live collaboration is never

**Settled by the user on 2026-08-12**, from two requests taken together, because they are one
question: git syncs the file between people, live collaboration edits it simultaneously.

**11.51.1 LIVE COLLABORATION IS NEVER, ON DR-004's PATTERN.** Not v1, not v1.1, not v1.2, not v2.
Deleted from the plan rather than deferred, and three separate things make it so:

1. **It deletes determinism's precondition.** *Same document, same display list, same exported
   bytes* holds because there is one writer. Concurrency does not weaken that guarantee, it removes
   what makes it true, and a 1000-sequence fuzz harness asserting byte identity is asserting a
   property of a single-writer system.
2. **It renegotiates CR-117.** A CRDT needs per-field causal metadata in the file. That is a
   schema version, a migration chain, and the end of *an absent key means not present*, which is the
   sentence the entire persistence suite rests on. Operational transform avoids the format cost and
   needs a server plus a rebase rule **per command type**, of which there are around forty.
3. **Undo has no good multi-user answer.** §11.38.5 already had to explain that undo-to-a-point works
   and edit-in-the-middle does not, because each operation was written against the state its
   predecessor produced. Multi-user undo asks whose undo, and reverts either the user's last act or
   the document's; both are wrong often enough that shipping products maintain apology pages about
   it.

**And the workflow it serves is rarer than it sounds.** Two integrators on one house hand off far
more often than they co-edit, and a handoff is the sync problem below, not this one.

**11.51.2 Git sync is v1.2, gated on evidence, and the gate is the point.** §2.3's membership rule is
that each item needs a format addition, a fixture corpus, or evidence from real projects. This one
needs the third: **real projects showing two people whose handoff a file share does not already
solve.** It ships if that evidence appears and does not if it does not, which is the same shape as
interval-graph channel routing's row.

**11.51.3 DIFFABLE IS NOT MERGEABLE, AND THAT IS THE WHOLE ENGINEERING RISK.** CR-117 gives
byte-exact key-sorted output, so `git diff` reads well and `git log` is genuinely useful. **A
three-way merge is a different problem.** Two designers who each add a device produce a textual merge
that **succeeds** and a document that may carry duplicate designators, colliding `FracIndex` orders,
or an `UndoStack` that no longer describes the file.

**So the ruling forbids the tempting half: RackMate performs no merge.** It detects that the file
changed underneath it, refuses to overwrite silently, and offers a side-by-side. Merging is git's job
and a person's, and an in-app three-way merge UI for this format is how a sync feature becomes a
corruption feature.

**11.51.4 It does not replace DR-039's journal and must not be read as doing so.** §11.38.2 put the
journal **in the file** because *"history left on the author's machine is absent from the artifact
under investigation"*, and the user's stated reason was troubleshooting a project somebody sends you.
**Git puts history on a server**, so a `.rmpj` emailed to a client carries none of it. The two solve
different problems and the journal is not deferred by this.

**11.51.5 Authentication inherits DR-033's constraint, which is already settled.** §11.32 established
that **no desktop binary can hold a secret**, and its answer is the authorization-code flow with
PKCE. Git sync uses the same mechanism, and nothing here re-opens it. It also does not ratify a
forge: DR-034 §11.33 already ruled that a library is **fetched, never cloned**, because *"clone does
not survive a platform with no git"*, and that reasoning applies to any user without git on their
machine.

**11.51.6 Scope.** **v1 grows by one small item** and it is the part that solves the reported
problem: **detect that a `.rmpj` changed underneath an open session, warn before overwriting, and
offer a side-by-side rather than a merge.** It works on any file sync a user already pays for, needs
no authentication, and does not touch the format. **v1.2 gains the git row**, gated as above. **v2
loses nothing, because live collaboration was never on it.**

**What it does not rule.** Which forge, what a sync UI looks like, or whether the app ever bundles a
git implementation as against shelling out to one. All are downstream of evidence that has not
arrived.

---

### 11.52 DR-053 · The typed line and the CSV agree on what identifies an outlet and a room

**Settled by the user on 2026-08-13**, closing board #654, which was filed during M3-F/6 as a
defect found while building something else and explicitly not fixed there: *"changing which outlet
an existing gesture joins is a behaviour change to a shipped surface, decided inside a task about
CSV."*

**11.52.1 The defect, and it is a wrong answer rather than a missing one.**
`drop_line_planner.dart`'s `_resolveOutlet` matches an `Outlet` by `designation` **alone,
project-wide**. docs/07 §5.3.2 states the key as **`(locationId, designation)`**.

So `Attic: 2x Cat6 @outlet="WP-1"`, typed on a project that already has a Living Room `WP-1`, hangs
the attic's drops on **the Living Room's plate**. Nothing refuses, because as far as the planner is
concerned the outlet resolved. The drops then carry the wrong room on the Pull Sheet, in the
per-room footage subtotals and in the schematic's room grouping.

**This is the normal residential case and not an edge one.** docs/07 §5.2's own worked example uses
`WP-1`, `CLG`, `AP-1` and `CAM-1..6`, **none of which is room-scoped by construction**.

**11.52.2 The ruling: `(locationId, designation)`, as already stated.** The code moves to the
document rather than the document to the code, and the reason is sitting forty lines away in the
same file. **`_resolvePanel` already refuses to match a device by NAME**, and its comment says why:

> A designator is the identifier printed on the rack and on every schedule (CR-042); a device NAME
> is free text that two panels can share, and a gesture that landed on *"whichever Patch Panel
> matched first"* would put the drop in a different rack depending on map order.

**That argument is about outlets word for word.** `doc.outlets` is a map, its iteration order is not
a fact about the project, and a first-match-wins rule over free text is the same defect the same
file already refuses one function along.

**11.52.3 A repeated name is REPORTED and never refused.** When the typed room has no such outlet and
another room does, the planner **creates the new one and says which room already carries that name.**

Refusing would be wrong: two rooms with a `WP-1` is ordinary. Staying silent would be wrong for a
narrower reason: **a mistyped room name and a genuine second plate produce the identical outcome**,
so the one moment the product can tell the operator anything useful is the moment it declines to
join them. This is G4's shape rather than its letter, the fact being surfaced is *"this looks
like something you already have"*, and it is a note rather than a refusal because
G3 forbids a heuristic holding the work hostage.

**11.52.4 Room matching collapses internal whitespace, and the two paths stop disagreeing.**
`_resolveLocation` matches on **trim and lower-case**; `csv_row_resolve.dart` implements §5.3.1's
**case- and whitespace-insensitive** rule. So `Living  Room` typed with a double space creates a
second room, and the same string imported from a spreadsheet matches the existing one. **Two entry
paths disagreeing about whether two rooms are one room**, which is the disagreement that produces a
Pull Sheet with two Living Rooms on it.

**Internal runs collapse; whitespace is not stripped entirely.** `Living  Room` matches
`Living Room` and `LivingRoom` does not. Stripping outright would catch one more class of typo and
would also make two names a person reads as distinct unrepresentable in one project, which is a
larger claim than §5.3.1 makes. **The narrower reading is the one that cannot be wrong in a way the
user cannot undo.**

**11.52.5 Nothing migrates, and that is a property of where the rule lives.** Resolution happens **at
gesture time**; no key is stored. So no existing document changes, no `.rmpj` byte moves, and
`kSchemaVersion` does not advance. What changes is which `Outlet` the **next** typed line joins.

**11.52.6 Scope.** No roadmap §2 change: docs/07 §5.3 already promised both rules and the code
implemented one of them. This is a **decomposition-gap fix under the §11.24.7 test**, not an
amendment, and it is ruled rather than merely fixed because §11.52.3's note and §11.52.4's choice of
reading are both decisions the corpus did not already contain.

**What it does not rule.** Whether `Outlet.designation` should be unique within a location at the
model level, which is a validation question with an AC-051 fixture pair and belongs to M5.

---

### 11.53 DR-054 · The `PORT` column prints the number on the part

**Settled by the user on 2026-08-13**, closing board #667, and it **discharges an open item DR-040
named rather than superseding anything.**

**11.53.1 THE TASK'S OWN TITLE IS WRONG, AND A LATER RULING MADE IT WORSE.** #667 is filed as
*"`RACK TERM` and `RACK LBL` name one hole two ways"*. **There is no `rackTerm` column**;
`ScheduleColumnId` has `port` and `term`, and **DR-046 (§11.45) has since given "rack term" a
specific and entirely different meaning**, the rack-end termination type. A reader picking the task
up today looks at the termination columns, finds them correct, and is lost.

The two columns that describe one hole are **`PORT` and `RACK LBL`**. Recorded because
the practice of re-reading a task against canon before pricing it says a board task is a snapshot of what was
unknown on the day it was written, and this is the sharper version: **the task's own vocabulary was
re-assigned underneath it by a ruling three weeks later.**

**11.53.2 What each column prints today.** `RACK LBL` renders `1A-PP-101`, whose `01` comes from
`panelPositionToken` and therefore from **`PortDef.label`, the number silkscreened on the part**
(DR-040 §11.39.8). `PORT` renders `portCell`, which is **`Port.designator`** plus any user label, and
`portDesignatorFormat` is `J{PORT_SEQ:2}` where `PORT_SEQ` counts the **front** jacks a drop never
touches. On a three-up/three-down fixture that is `J04` for the hole labelled `01`.

**So one sheet carries two numbers for one position, and a tech on a ladder has to know which is
which.**

**11.53.3 The ruling: `PORT` renders the position token.** `panelPositionToken` is reused rather
than a second rule written, and the reuse is the argument: **it already falls back to the designator
when a template authors no label.** So the change is uniform rather than special-cased, a panel port
prints `01` and an ordinary device port still prints `J09` exactly as now, and `farPort` gets the
same treatment for free because it renders through the same `portCell`.

**11.53.4 The deeper fix was available and is deliberately not taken.**
`bind_endpoint_command.dart`'s own comment names it: *"closing it means teaching designator
ALLOCATION to honour an authored label, which is its own ruling and touches the connect gesture's
output for every device in the catalog."*

**It is refused on a cost the comment does not state.** `Port.designator` is **stored** project state,
unique within a device (CR-042). Changing allocation changes what **new** ports get and leaves every
already-materialised port carrying what it was given, so **one document would hold `J04` on the
ports bound last week and `01` on the ports bound today, with no migration able to reconcile them**
without rewriting identifiers other entities reference. A rendering rule has no such tail.

**11.53.5 The allocated designator stops appearing on any sheet, and that is a loss worth naming.**
After this, `Port.designator` is visible only in the app. That is the right side of the trade because
**it identifies a `Port` to the software and not to a person on a ladder**: CR-044's own worked
example is `1A-A12`, a position number, and nothing an installer holds is silkscreened `J04`. But it
is stated rather than glossed, because the next person to ask *"where did the port designator go"*
deserves to find the answer rather than a surprise.

**11.53.6 This DISCHARGES rather than supersedes, which is the third relationship this record
recognises.** DR-040 §11.39.8 is a *"what this does not fix, stated so nobody reads it as fixed"*
clause. Answering it leaves DR-040 entirely intact, exactly as **§11.30 discharged DR-020
§11.19.4**, so there is **no §12 entry** and a reader of §11.39.8 should follow the pointer here
rather than infer that DR-040 was amended.

**11.53.7 Scope.** No roadmap §2 change and no milestone moves. One rendering function gains a
caller, two columns agree, nothing is stored, nothing migrates, and `kSchemaVersion` does not
advance. **It is not #679**, which is the `TERM` column meaning the field end on a sheet whose
editor now distinguishes both ends, and which DR-027 parks on M6.

---

### 11.54 DR-055 · The Termination Schedule prints both ends, because it already prints both ends of everything else

**Settled by the user on 2026-08-13**, closing board #679 and **answering the inconsistency DR-046
§11.45.5 filed rather than hid.** It discharges that clause and supersedes nothing.

**11.54.1 THE TASK UNDERSTATED ITS OWN FINDING, AND THE CENSUS IS WHAT CORRECTED IT.** #679 is filed
as *"the sheet and the editor now disagree about what `TERM` means"*, which is true and is the
smaller half. The larger half: **`StructureOrigin.terminationRack` reaches no printed output
anywhere.** Its only consumer in the tree is `structure_table.dart`'s own column; `rackmate_export`
contains not one reference to any schedule column, and the whole derived schedule layer names the
field alone.

**And it is absent from the one sheet built around the rack.** `buildScheduleView` drops every row
where `!row.landsInRack` for this preset, sorts `rackThenPanelThenPort` and groups by rack. **So the
Termination Schedule is a rack-side work order that cannot state the rack-side termination**, which
is a sharper defect than a column with a stale name.

**11.54.2 The decisive argument was already on the sheet, about its other columns.** §3.3's twelve
columns print **both ends of every other fact**: identity is `RACK LABEL` and `FIELD LABEL`, location
is `RACK / RU / FACE` and `FAR END`, port is `PORT` and `FAR PORT`. **Termination is the only per-end
fact the sheet collapses into a single column**, and §3.3's rule-weight grouping files it in the
*spec* block beside `MEDIA`, as though it were a property of the cable rather than of an end.

**DR-046 ruled that exact collapse wrong in the model**, where one field served two columns and a
speaker run with a phoenix at the panel was inexpressible. The sheet carried the same collapse and
nobody had carried the argument across. This is the shape §11.52's note names: **a rule already
argued for one entity is evidence about its neighbours.**

**11.54.3 The ruling: thirteen columns.** `TERM` becomes **`FIELD TERM`** and **`RACK TERM`** joins
it. `FIELD TERM` renders `StructureOrigin.terminationField` through the existing chain, including its
`PlaceEndpoint.intendedTermination` fallback; `RACK TERM` renders `terminationRack` and has no
fallback, because DR-046's whole content is that **nothing infers one end from the other**.

**11.54.4 The width arithmetic, which the sheet had no room for until its own §3.4 supplied the
rule.** The sheet is ANSI A landscape, usable **690 pt, fully allocated**. §3.4 already names the
donor order for a column that has to fit: *"width is taken from `CONDUCTOR / NOTES` first, then
`MEDIA`"*. Both donors are used and nothing else moves:

| Column | Was | Now |
|---|---|---|
| `MEDIA` | 56 | **42** |
| `TERM` | 52 | retired |
| `FIELD TERM` | | **44** |
| `RACK TERM` | | **44** |
| `CONDUCTOR / NOTES` | 66 | **44** |
| **Σ** | **690** | **690** |

The nine identity and end columns are untouched. `CONDUCTOR / NOTES` keeps its two-line wrap and
loses a little of its ellipsis budget, which is the cost and is accepted.

**11.54.5 An unknown end prints the unknown token and NEVER the other end's value.** G4 and CR-114,
in the place they are cheapest to get wrong: a run terminated at the plate and not yet at the panel
prints its field type and `—` beside it, and a reader learns that the rack end is undecided. Copying
the field value across would reproduce the precise defect DR-046 exists to remove, on paper, where it
is hardest to correct.

**11.54.6 Two alternatives were offered and both are refused, with reasons.** **One cell carrying
both ends** (`T568B › 110 A03`) keeps twelve columns and needs no arithmetic, and it fails on the
measurement: 52 pt at `RackMono` 7 does not hold two termination tokens, `F BARREL › F BARREL`
overruns on the third row of the worked example, and the header would have to teach a reading order.
**`TERM` meaning the rack end** costs one line and no layout, and it **reverses the defect instead of
resolving it**: the field end would then print nowhere in the product, which is today's complaint
with the ends exchanged.

**11.54.7 The two-visit objection was put to the user and answered.** A field end is terminated at
trim-out and a rack end at rack build, often weeks apart and sometimes by different people, which is
a real argument for two documents. **The user ruled one sheet.** The sheet is the cable's record and
already serves both readers for labels, locations and ports; a second sheet is a new `SheetRole`
under DR-049 and buys nothing this one cannot carry. **Recorded because the objection is sound and
was overruled on trade grounds, not missed.**

**11.54.8 Who builds it, and why this ruling ships no code.** §11.26.4 splits it: *"the derivation is
the load-bearing half and it stays in M3"*, meaning sorted rows, subtotals and G4's counts. **A column
set carrying `header` and `widthPt` is presentation**, so `kTerminationScheduleColumns` and the page
it lays out are **M6's under DR-027 §11.26**. The derivation is already done and was done before this
was asked: both fields exist, both round-trip, and both are populated by the editor.

**Nothing renders this sheet today.** `rackmate_export` has no schedule renderer at all, so there is
no printed page to re-lay and no drift to fear in the meantime; the code keeps a twelve-column
constant and a pointer to this ruling until M6 reaches it.

**11.54.9 Scope.** **No scope change to roadmap §2.** The Termination Schedule is already in scope,
already has an exact column table, and gains one column inside its existing page. No model field, no
codec change, no migration, and `kSchemaVersion` does not advance. **docs/08 §3.3's table is edited to
match rather than pointered**, so §12 is owed nothing.

---

### 11.55 DR-056 · `Generic` is the trade's word for unspecified, so the builder pre-fills it

**Settled by the user on 2026-08-14**, ratifying `docs/06-device-builder.md` §3.1's existing
sentence *"Defaults to `Generic`"* and giving it the ruling it never had. It supersedes nothing.

**11.55.1 The question was raised as a contradiction that does not exist, and the correction is
recorded because it is the instructive part.** M4-A flagged that board `#175` names the builder's
three required fields as `displayName`, RU height and `typePrefix`, while `TemplateBody`'s
constructor requires `manufacturer`, `model` and `displayName`. **Those are not two claims about the
same thing.** AC-049 (§2.3) rules the FORM's required set and docs/06 §1 and §3 state it in terms;
the constructor is a Dart signature the builder satisfies by supplying values. A constructor
parameter was read as a product rule, and the corpus had answered the actual question before it was
asked, which is precisely the failure the *re-read a task against canon* practice exists to prevent.

**AC-049 stands untouched: three required fields, `displayName`, `frontU`, `typePrefix`.** Nothing
in this ruling adds a fourth or removes one.

**11.55.2 The real question the census surfaced, which canon WAS silent on.** `docs/06` §3.1's
default sits in a **derived, priority-3 document**, and its stated reason is about the seed: *"The
whole seeded catalog is `Generic`"*, which 31 catalog entries confirm. That justifies the seeded
bodies, which hard-code the string in Dart. **It says nothing about what a USER's untouched field
should become**, and the two diverge the first time somebody authors a real device.

The consequence is concrete and printed. `equipment_list.dart:428` runs
`_trimToNull(body?.manufacturer)`, and `equipment_sheet.dart:606` renders
`row.manufacturer ?? kUnknownCell`, so a blank manufacturer reaches paper as **`—`** and is counted
as an unknown, while `Generic` reaches paper as `Generic` and is counted as known.

**11.55.3 The ruling: the form pre-fills the literal `Generic`, and the reason is trade convention.**
**`Generic` is standard within the industry** in a manufacturer column: it is the recognised token
for *unspecified* / *by others* / *contractor's choice*, and the people reading an equipment list
parse it as such. It is therefore **not a fabricated value under G4** but the trade's own spelling of
the same fact `—` states, on a document whose readers already know the word.

**11.55.4 The objection that was put and answered, recorded so it is not re-run.** The argument
against was that a value the user never typed reaches a client-facing deliverable, where `Generic`
would read as a claim that a real device is a no-name unit, and that the unknown rollup, which exists
to catch exactly that before a sheet goes out, cannot see a field holding a value.

**That argument depends entirely on how a reader parses the word, and it was wrong about the
reader.** A convention the trade already reads as "unspecified" is not misread as a product claim.
The objection was an inference about document reading made without trade knowledge, and the same
class has been overruled on the same grounds at **§11.47** (DR-048: the drawing machine *"is not on
the rack's network"*, when a project copy at the client's home routinely is) and at **§11.54.7**
(DR-055: two visits, therefore two sheets). Named rather than counted, so the list stays true when
there is a fourth. **The generalisation is the useful part: put "how the trade works" objections as
questions, not findings.**

**11.55.5 One consequence is stated rather than hidden, because it follows and is not a defect.**
The unknown rollup will report **zero** devices missing a manufacturer, because the field holds a
value. That is the intended behaviour under this ruling and not a bug in `totals.dart`; a future
reader finding "0 devices have no manufacturer" beside a sheet full of `Generic` should read this
clause rather than file a defect.

**`model` is NOT defaulted and stays blank**, exactly as docs/06 §3.1 has it: the table gives
`manufacturer` a default and gives `model` none, no trade convention was offered for a model string,
and an invented one would be the fabrication this ruling is careful not to be. An untouched `model`
therefore still prints `—` and still counts as unknown.

**11.55.6 Scope.** **No scope change to roadmap §2, no model change, no codec change, no migration**,
and `kSchemaVersion` does not advance. The nullable-fields option, making
`TemplateBody.manufacturer`/`model` `String?` so an untouched field is an absent key per CR-114
rather than an empty string normalised by `_trimToNull` at read time, **was offered and not taken**;
the present-key-holding-empty-string shape stands. docs/06 §3.1 is edited to carry this ruling's id
rather than pointered, so §12 is owed nothing.

**11.55.7 Who builds it.** M4-D (`#175`), the metadata form. Nothing ships with this ruling: the
form does not exist, and M4-A built machinery beneath it. `TemplateBodyField.manufacturer`
(`builder/template_commands.dart`) carries the citation, because that is where the implementer is
standing when the question arises.

---

### 11.56 DR-057 · Connector pitch is a refinement, not a prerequisite, and stays sparse

**Settled by the user on 2026-08-14**, during M4-B (board `#173`). It supersedes nothing and
**corrects a reading of docs/06 §5 that was about to cut a feature nobody had ruled out.**

**11.56.1 What M4-B found.** `ConnectorTypeDef.pitch` and `.genderApplies` were documented from M0
and declared by neither the Dart nor the codec. The two turned out to be authorable on opposite
terms. **`genderApplies` was never open work**: §6.3 already carries a complete yes/no table for
every connector, so all 49 are a transcription and none is a judgement. **`pitch` is stated for 13
rows naming 14 ids** in docs/catalog/seed-devices.md §5.2, and for nothing else in the corpus.

**11.56.2 Shared-shell inheritance: SIX ids inherit a pitch, and the instrument is borrowed rather
than invented.** `conn.3_5mm_ts` from `_trs` (one 7 mm barrel), `conn.xlr5` from `xlr3`,
`conn.iec_c13` from `_c14` (one body, one the inlet), and `conn.nema_5_15p` / `_5_20p` / `_5_20r`
from `_5_15r` (one duplex yoke). **Every one of those pairings is already made and cited in
`assets/catalog/sources.md`'s FOOTPRINT table**, so this reuses an existing documented derivation
instead of adding a second kind of provenance.

Held in the test as a RELATION and not as six more literals: each inheritor must equal its source,
so re-authoring `conn.xlr3` drags `conn.xlr5` with it. Six duplicated numbers would drift apart,
which is the failure a shared-shell rule invites.

**11.56.3 The remaining twenty-nine have no pitch, permanently.** Thirteen of them block real
catalog ports: `conn.euroblock_2`, `conn.punchdown_110`, `conn.usb_c`, `conn.screw_terminal`,
`conn.barrel_dc`, `conn.sfp_cage`, `conn.iec_c19`, `conn.jis_f05`, `conn.phoenix_4`,
`conn.nema_l5_30p`, `conn.euroblock_5`, `conn.6_35mm_trs`, `conn.sc`. **No value is invented for
any of them.** A pitch looks derivable from `footprintWidth`, since most stated ones sit 2 to 4 mm
above it, and then `conn.binding_post` states 20 mm against a 24 mm pair footprint, BELOW it,
because ¾ inch is the centre spacing binding posts are physically built on.

**11.56.4 AND THAT COSTS NOTHING, WHICH IS THE CORRECTION THIS RULING EXISTS FOR.** The question
was first put to the user as a trade-off between sparse pitch and auto-layout coverage, priced at
**14 of 45 shipped templates**. That price came from **docs/06 §5's pseudocode**, *"flow left →
right at `ConnectorTypeDef.pitch`"*, in a derived priority-3 document.

**Every normative statement says footprint.** CR-071 §1 rules panel geometry *"auto-laid-out from
connector footprints"*; docs/catalog §5.2's own introduction says the layout *"needs a real
footprint per connector"*; roadmap §2 lists *"the connector footprint table complete for every
shipped connector"*. **The word pitch appears in no ruling.**

**The algorithm therefore advances by `pitch ?? (footprintWidth + gutter)`,** and skips the three
connectors §5.1 gives no cutout, since a hardwired lead occupies no panel width. Auto-layout runs
on **45 of 45** templates with ports. The 20 stated pitches sharpen a layout that works without
them, and the gutter is **one stated layout constant**, the same kind of thing as `kGridUnit`, not
a physical claim about 29 connectors.

**Its value is left to M4-K**, where it can be judged against a rendered panel rather than a table.
The evidence available now: the stated pitches sit 2 to 4 mm above their footprints, excluding
`conn.binding_post`, whose real spacing is narrower than its pair footprint and which needs no
gutter because it states one.

**11.56.5 The mistake is recorded because it is the second of its kind in three days.** DR-056
§11.55.1 read a Dart constructor as a product rule; this read a derived document's pseudocode as a
requirement. Both were caught by the same instrument, re-reading the question against canon before
acting on it, and in this case only just: the ruling was being drafted when the check ran. **A
derived document that describes a mechanism is not a ruling about what the mechanism needs.**

**11.56.6 Scope.** **No scope change to roadmap §2, which never named a pitch**, and no feature is
cut: §11.56.4 is why. No migration and `kSchemaVersion` does not advance, because both new keys are
written only when present, so every document already on disk still satisfies CR-117. The four
shipped starters regenerate, since the seeded registry now carries values; their only byte delta is
the two new keys.

**docs/06 §5 is edited to match rather than pointered**, so §12 is owed nothing: its algorithm step
2 gains the fallback and its *"carries a real footprint and pitch"* sentence becomes true as
written.

**11.56.7 Who builds what.** M4-B (`#173`) ships the fields, the codec, the authoring and the
gates. **M4-K (`#182`) owns the algorithm, the gutter constant and the no-cutout skip**, none of
which exists yet: there is no `panel_layer.dart`. `ConnectorTypeDef.pitch`'s own doc comment
carries this ruling, because that is where the next implementer will be standing.

### 11.57 DR-058 · A fork whose source cannot be seen is silent on the device and counted in the rollup

**Settled by the user on 2026-08-14**, during M4-C (board `#198`). It supersedes nothing and fills a
gap CR-062 left because the case had not come up: **the ruling says what happens when the source
was corrected, and says nothing about what happens when the source cannot be found at all.**

**11.57.1 The gap is routine, not exotic.** CR-062 compares a fork's `derivedFrom{templateId,
version}` against the source's current version. That comparison needs a shelf holding the source,
and there are four of them arriving across four milestones: a document's own `templates` map, the
seeded catalog, the user library (M4-N) and DR-034's fetched community pack. A project opened on a
second machine, or one whose author deleted the library template years ago, reaches a state where
**no shelf in view holds the id**. So does a shelf holding only a version OLDER than the fork
claims, which is a partial shelf rather than a correction.

**11.57.2 The ruling.** No badge on the device, and the count is reported by the rollup. Three
options were put:

| | What it does | Why not |
|---|---|---|
| **No badge, counted** | The device shows nothing; the template list reports *"N forks could not be checked"* | **RULED.** |
| A quiet neutral badge per device | A greyed *"source not available"* marker | Fires on every fork in every project opened anywhere else, which is normal and not a problem. A marker that is always on stops being read, and CR-062's whole design is a badge that means something when it appears |
| Treat it as up to date | No badge, no count | Makes an unknown look like a measured *no*. This is exactly the fabrication G4/CR-114 forbid everywhere else in the model, applied to a version number instead of a wattage |

**11.57.3 It is G4 applied to a comparison rather than to a value, and that is the general form
worth keeping.** *"Null is unknown, never estimated. Every rollup reports its unknown count rather
than fabricating a total."* A resolver that answers `current` when it merely failed to look is the
same defect as a load rollup that totals the devices it could price and omits the ones it could
not. The count is what makes the silence visible somewhere rather than nowhere.

**11.57.4 One consequence, stated because it decides a pixel.** The version number a partial shelf
DID find is withheld along with the verdict. A badge reading *"the catalog is at v1"* beside *"you
forked v3"* invites the reader to conclude the catalog rolled backwards, which is a claim nobody
made. `ForkResolution.currentSourceVersion` is therefore null on `sourceUnknown`, and
`showsStaleBadge` is a property rather than a `status != current` comparison spelled at each call
site, because that comparison is wrong in exactly this case.

**11.57.5 Scope.** No scope change: CR-062 already names the badge and roadmap §2 already carries
the device library. `ForkStatus`, `ForkResolution` and `ForkAudit` are `rackmate_core` only; **no
widget ships**, because nothing forks yet (Duplicate is M4-D `#175`) and no library holds one
(M4-N). No migration and `kSchemaVersion` does not advance: `derivedFrom` is written only when
present, so every document already on disk still satisfies CR-117. `builder/fork_status.dart`
carries this ruling in its own header, for DR-057 §11.56.7's reason.

### 11.58 DR-059 · The device glyph ships, because `accentColor` alone is hue alone

**Settled by the user on 2026-08-14**, during M4-C's census of M4-D (board `#175`, `#201`). **This
is a §8.3 amendment, not a decomposition gap**, and the distinction is the reason it has its own
ruling ID and its own commit: roadmap §2's device-builder line does not name a glyph, and neither
does any ruling in Parts 1 to 3.

**11.58.1 What the question was.** docs/06 §3.4 says Appearance carries *"`accentColor` and a glyph
from a built-in icon set, both defaulting from category"*. There is no icon set, no model field and
no ruling behind that sentence. **Every `glyph` in canon is `SignalDomainDef.glyph`**, which is
CR-078's channel 4a on the *schematic* and a different axis entirely: it identifies a signal family,
not a device. So the device glyph lived in exactly one derived, priority-3 sentence, which
`check a decomposition for holes` makes a scope question for the user rather than a hole to fill
quietly. It was put as one, with a recommendation to drop it.

**11.58.2 The user ruled it in, and the census had already found the better reason.** Three facts,
measured rather than reasoned:

| | Finding |
|---|---|
| `accentColor` is authored on **0 of the 48** seeded templates | It is not merely unread, it is unwritten. DR-012's *"the field is empty"* case exactly |
| `accentColor` is read by **no renderer at all** | `grep` across `packages/*/lib` returns the model, the codec and M4-C's change-class table. `draw/scene/device_layer.dart` fills every device with `palette.deviceFill`, one uniform colour |
| So the Appearance section as specified would offer **two controls and no channel that reaches paper** | Which is the defect `shell_tabs_test.dart` exists to prevent, arriving through a section rather than a tab |

**11.58.3 And CR-078's own argument makes the case the derived sentence never made.** *"Hue is
never used alone"*, because no categorical palette is CVD-safe past 8 or 9 categories and because
**hue dies in greyscale and on a photocopy, which is how these drawings reach a job site**. The
elevation is the single sheet that argument bites hardest on: it is the one that gets taped inside
the rack door. Shipping `accentColor` as the only appearance channel would be hue alone, on the
worst possible sheet, in a codebase that has a CI gate against exactly that on the schematic. The
glyph is that redundancy applied one surface over.

**11.58.4 IT IS GEOMETRY, NEVER A CHARACTER, and this is not a preference.**
`draw/scene/family_glyph.dart` exists because the signal glyph was once a codepoint: **Jost carries
none of them, so `PdfFontMeasurer` returned a near-zero advance while the screen's `TextPainter`
fell back to a system font and drew it at full width.** Measured short, drawn wide, and the field
saw `NET-NEN006` printed over the net name. It was invisible to every gate because both backends
emitted identical ops and only the font behind one of them differed. The device glyph is drawn as
paths, its advance computed from the type size, for that reason and no other.

**11.58.5 The value set is censused, not invented, and is capped by legibility.** The set could
have been one glyph per shipped archetype, which the 48 templates would put near 40. **It is 17
plus `none`**, because the mark is drawn 1U tall on a greyscale photocopy and a 40-way silhouette
distinction is not readable at that size: `measure the control before choosing it`, applied to an
icon. Silhouettes group by what a box *is*, so several catalog ids share one: the three HDMI
matrices are one `matrix`, and F04 through F08 are one `speaker`. Every one of the 48 resolves, and
a gate asserts it.

**11.58.6 Defaulting from category reuses `kCatalogCategoryOrder` and does not restate it.** That
constant is the palette's own grouping order and carries **nine** categories. docs/06 §3.1's
eight-item list is an abbreviation of it that also drops `Field Devices` and respells three of the
others, so it is corrected to point at the constant rather than to compete with it. A second list of
categories is how the palette and the builder come to disagree about what a device is.

**11.58.7 Who builds what, because the artwork is not the field.** **M4-D (`#201`) ships the enum,
`TemplateBody.glyph`, the codec, the change class and the default-from-category table.** The
**vector artwork and its renderers are a new issue** sequenced with M4-K (`#182`), which already
owns the three live previews and is the first surface where a device glyph would appear at all.
Folding 17 hand-drawn paths, a PDF parity pass and a golden regeneration into the metadata-form
task would swamp it, and M4-K is where a glyph can be judged against a rendered panel rather than
against a table: DR-057 §11.56.7 made the same split for `pitch` and for the same reason.

**11.58.8 Scope.** **Roadmap §2's device-builder line is amended** to name the glyph beside AC-049,
which is the §8.3 edit this ruling exists to authorise. docs/06 §3.4 is edited to match rather than
pointered, so §12 is owed nothing. `kSchemaVersion` does not advance: the key is written only when
the glyph is not the category default, so every document already on disk still satisfies CR-117.
**`accentColor`'s unreachability is NOT fixed here** and is filed as its own finding: making it
reach `device_layer.dart` changes the elevation, regenerates four starters' goldens and must clear
PAL-1, none of which belongs in a metadata form.

### 11.59 DR-060 · Quick Add resolves family-first, because the family already names its connector

**Settled on 2026-08-15**, during M4-G's census of the Quick Add DSL (board `#178`, `#214`). **This
is not a §8.3 amendment**: roadmap §2 already names *"the pattern DSL with autocomplete and designed
parse errors"*, and nothing here adds or removes scope. It has a ruling ID because it **reverses the
lookup direction docs/06 §4.1 states** and settles a precedence question CR-058 never reached.

**11.59.1 What the question was.** CR-058 rules that bare trade names become registry aliases and
that *"the Quick Add DSL resolves against them"*, holding them on both `ConnectorTypeDef.aliases`
and `SignalFamilyDef.aliases`. docs/06 §4.1 spells the resolution out one way round: a token yields
a connector **and** a family, and `hdbt` and `rj45` are offered as the proof that the design works,
*"a different family on the same connector, which is the entire point of keeping connector, family
and direction orthogonal"*. What neither document says is **which table is consulted first**, which
matters the moment one token appears in both.

**11.59.2 The census, which found the premise unbuilt.** Board `#178` and `#214` both assert that
`aliases` *"already exists on both `ConnectorTypeDef` and `SignalFamilyDef`"*. Measured against the
tree:

| | Finding |
|---|---|
| `ConnectorTypeDef.aliases` | **Populated.** 22 entries in `catalog/catalog_connectors.dart` |
| `SignalFamilyDef.aliases` | **55 families, zero aliases.** The `_family()` helper at `catalog/seed_registries.dart:274` **does not accept an `aliases` parameter at all**, so the seed could not express one if it wanted to |
| canon §6.3's alias table | Lists **connector aliases only**. §6.4, which specifies `SignalFamilyDef`, lists none |

So the field exists and the data does not, and the orthogonality claim was **unresolvable by
anything in the tree**: `hdbt` and `rj45` are both aliases on `conn.rj45`, and no table anywhere
maps either token to a family. `a modelled field is not a reachable one`, for the fifth consecutive
M4 task, and the fifth time the first useful hour went into reading rather than typing.

**11.59.3 THE RESOLVER ALREADY EXISTS, AND ITS OWN DOCSTRING ASKED FOR THIS RULING.**
`resolveSignalFamilyToken` (`structure/drop_line_planner.dart:707`, exported) implements DR-025
§11.24.3's chain, `shortTag` then the id's own tail then `displayName`, and it is already shared by
two callers: the Structure CSV `signal` column (M3-F/6) and `@signal=` (`#587`). Its docstring is
explicit about the gap and about the remedy:

> **`aliases` IS NOT IN THE CHAIN, AND DR-025 IS WHY.** The ruling names three steps and
> `SignalFamilyDef.aliases` is not among them. That reads like an oversight next to
> [resolveMediaToken], where aliases are the authority, and it is not: media aliases are the
> user-extensible surface RJ-009 governs, and a signal family's are catalog data serving the
> schematic. **Widening this chain is a ruling.**

**This is that ruling, and the consequence is that Quick Add does not get a resolver of its own.**
The same docstring already gives the reason, one paragraph up: *"Two copies would be two chances to
disagree about what `hbt` means."* A third caller is exactly the case it was written against.

**11.59.4 Ruling: aliases join the chain at its head, and THE TWO REGISTRIES ANSWER INDEPENDENTLY.**
A Quick Add token yields a **pair**, and each half is resolved by its own registry:

```text
family    := aliases → shortTag → id tail → displayName          (may be UNKNOWN)
connector := ConnectorTypeDef.aliases → id tail                  (may be UNKNOWN)
            ELSE family.defaultConnector, when the family resolved
direction := family.defaultDirection, unless the command states one
```

The family half is `resolveSignalFamilyToken` widened by one step; the connector half is new and
belongs to Quick Add. **Aliases go at the head rather than the tail**, which is `resolveMediaToken`'s
shape (*"`aliases` is the authority, then `shortTag`, then the id's own tail, then `displayName`"*)
applied to the family for the same reason: an alias is authored deliberately and the other three are
derivations that happen to collide usefully. `hbt`, `hdbaset` and `avoip` already landed through the
later steps and still do; **`hdbt`, the spelling docs/06 §4.1 and §9.1 actually type, landed nowhere
at all**, and that is what the new step is for.

**A SINGLE FIRST-HIT-WINS CHAIN WAS THE FIRST DRAFT OF THIS CLAUSE AND `c13` KILLED IT.** A rack PDU
has C13 **outlets** and a C14 **inlet**, and both are `power.ac_iec`, because CR-058 already ruled
that inlet and outlet are `PortPowerSpec.role` rather than families of their own. Under one chain,
`c13` would resolve family-first to `power.ac_iec` and take that family's `defaultConnector`, which
is `conn.iec_c14`, and **every outlet on every power strip in the catalog would be authored with the
wrong connector**, silently, on the panel drawing an electrician builds from. Resolving the two
halves separately gives `c13` → `power.ac_iec` + `conn.iec_c13` and `c14` → `power.ac_iec` +
`conn.iec_c14`, which is what the words mean. The general statement: **a family knows a *default*
connector, and a default loses to a named one.**

**Either half may come back UNKNOWN, and that is the feature.** `xlr` matches a connector and no
family, because an XLR3 carries `audio.line_bal`, `audio.mic`, `audio.aes3` or `ctl.dmx512` and the
token does not say which. The port is created with the connector set and the family blank rather
than with a guess, which is G4 arriving in a parser: **null is unknown, never estimated.** The grid's
validation dots (M4-E) already mark a family-less port, so the state is visible and correctable
rather than silent.

**The dependency runs one way and only one way, which is why the family is resolved first.**
`SignalFamilyDef`
carries `defaultConnector`, `defaultDirection` and `defaultTopology`, all three populated for all 55
families since M0. A family therefore determines a connector. **A connector determines nothing**:
`conn.rj45` is worn by `net.ethernet`, `video.hdbaset`, `net.poe`, `ctl.rs485` and more, and asking
it which family was meant is asking a question it does not hold the answer to. Family-first makes
`hdbt` → `video.hdbaset` → `conn.rj45` and `rj45` → `net.ethernet` → `conn.rj45` fall out of a field
that has been sitting in the model since M0, rather than out of a second parallel table that has to
be kept honest against the first. docs/06 §4.1's `hdmi` → `conn.hdmi_a` + `video.hdmi.2_0` reaches
the identical answer by the reverse route; the difference only shows on a token that collides, and
every interesting token collides.

**11.59.5 `hdbt` LEAVES THE CONNECTOR TABLE and `rj45` STAYS, and the difference is measured, not
tidy.** Both are presently aliases on `conn.rj45`. `hdbt` is a data error rather than a redundancy:
HDBaseT is a transmission standard carried over twisted pair, and the connector it lands on is an
8P8C. Under §11.59.4 it is outranked by step 1 and never read again, which is worse than wrong, it
is dead data that reads as live. **It moves to `video.hdbaset.aliases` and the connector table loses
it.** The general test is that **a connector alias must be a name for the connector**.

**`rj45` passes that test and has a second reason to stay that a tidy-up would have deleted.**
`portConnectorShortLabel` (`builder/port_summary.dart:113`) reads `def.aliases.first.toUpperCase()`
to print the port grid's `Conn` column and its footer, so `conn.rj45` prints `RJ45` **because of
this list**. Removing the entry would have made the column M4-E shipped seven commits ago start
printing a display name. `hdbt` is `aliases[1]`, so its removal changes no rendered cell. Grepping
the readers before editing seeded data is the whole of the difference here.

**11.59.6 SEEDING FAMILY ALIASES CHANGES A SURFACE THAT IS ALREADY SHIPPED, and it changes it for
the better.** `structure_table.dart:667` already spreads `...family.aliases` into
`SignalFamilyCellOption.searchKey`, the M3 signal picker's filter text. The list has been empty since
M0, so the picker has been searching over label, `shortTag`, id and display name and nothing else.
**Every alias seeded here immediately becomes a search term in a picker no task in M4 names**, which
is a behaviour change on a shipped surface and is recorded here rather than discovered later by
someone wondering why the filter got better. It is the outcome that field was written for.

**11.59.7 What this costs on disk, which is less than it looks.** `_encodeSignalFamilyDef` writes
`'aliases': d.aliases` **unconditionally** (`json_codec.dart:2474`), unlike `MediaTypeDef`, which
that file's own comment at :2601 explains is conditional precisely to avoid adding a key to every
entry in every existing document. So `"aliases":[]` is **already present on all 55 families in every
starter on disk**. Seeding them changes values, never the key set, so **`kSchemaVersion` does not
move** and CR-117 is untouched: a document written before this ruling still decodes and re-encodes
byte-for-byte through its own recorded values. The four checked-in starters are regenerated because
they are generated artifacts of the seed, which is a visible line in the diff and not a golden being
quietly relaxed.

**11.59.8 The alias set is trade vocabulary and is authored as a reviewable table, not inferred.**
`trade knowledge beats workflow reasoning` is a practice in this bundle because reasoning about how
installers speak has produced a wrong ruling before. The seeded set is therefore **deliberately
narrow**: the tokens docs/06 §4.1 and §9.1 already name, plus the unambiguous ones, and **no family
is given an alias merely to have one**. A family with no alias is still reachable by its full id.
A gate asserts the set is collision-free under §11.59.4's precedence, that every family alias
resolves, and that no alias is also a family id or a connector id.

**11.59.9 Who builds what.** **M4-G (`#178`) widens the shared resolver and owns the alias seed**,
and widening it is the change the CSV `signal` column and `@signal=` inherit for free. M4-P (`#187`)
keeps the **alias editor**, the surface on which a user adds their own; the two do not overlap and
the split is the ordinary one between seeded catalog data and a user-authoring UI. M4-H (`#179`,
tasks `#217`, `#218`, `#219`) is **folded into M4-G's delivery** rather than sequenced after it,
settled by the user on 2026-08-15: the DSL's grammar quotes label patterns in every one of §9.1's
thirteen steps, so a Quick Add shipped without the pattern language produces sixteen identically
named ports and cannot perform a single step of the example the milestone is measured by. That is
`check a decomposition for holes` on the same milestone that earned the practice. **Folding is a
decomposition change, not a scope change**, so it is recorded on the board and in docs/12 §5.3.6,
and §8.3 is not engaged.

**11.59.10 TWO CALLS THE USER MADE AND THE AGENT DID NOT, both settled on 2026-08-15 against a
stated recommendation.** `trade knowledge beats workflow reasoning` is a practice here because
reasoning about how installers work has produced a wrong ruling before, so both are recorded with
the recommendation they overruled rather than presented as if they had always been the plan.

**(a) A derived bank name is built from the family's FIRST ALIAS, falling back to `shortTag`, and
docs/06 §4.2's stated rule is wrong.** §4.2 says the name is `"{family display name} {direction
plural}"`. The seeded display name for `video.hdmi.2_0` is `HDMI 2.0 (18 Gbps)`, so that rule yields
**"HDMI 2.0 (18 Gbps) Inputs"**, while §4.1's own example table and §2's layout sketch BOTH show the
bank as **"HDMI Inputs"**. The rule and its worked examples contradict each other, which is
`a spec table is an illustration until censused` arriving from the other direction: here the PROSE
is the illustration and the examples are the specification. Alias-then-`shortTag` reproduces
"HDMI Inputs" and "HDBT Outputs" exactly as both examples write them. **docs/06 §4.2 is edited to
match rather than pointered**, so §12 is owed nothing.

The cost is that **alias ORDER now carries display meaning**, which it already did for connectors:
`portConnectorShortLabel` has printed `aliases.first` in the port grid's CONN column since M4-E. The
convention is therefore extended rather than invented, and it is stated on both fields. `ctl
.ir_emitter` gains `ir` AHEAD of `ir35` for this reason and no other, so its bank derives as
**"IR Outputs"** rather than "IR35 Outputs"; an installer writes the former, and `ir` already
resolved to that family through `shortTag` anyway, so the alias adds a display fact rather than a
vocabulary one.

**(b) `euro2` DEFAULTS TO `audio.speaker_lowz`, and the recommendation to leave it unknown is
overruled.** The agent's argument was that a 2-pole euroblock carries low-Z or constant-voltage,
that the token does not say which, and that guessing wrong puts 70 V on an 8 Ω run. **The user ruled
that low-Z is the overwhelming case in the racks this tool is for**, which is a fact about the trade
and not about the parser, and the cell remains editable in the grid with one keystroke. Recorded
because §11.59.4's "either half may come back UNKNOWN" is now carried by `xlr` alone, and a later
reader finding `euro2` resolved would otherwise think the invariant had eroded. **It has not**: `xlr`
still refuses, because an XLR3 carries four families with no majority among them, and that is the
distinction, a default is legitimate where the trade HAS a default and never where it merely has a
most-common-guess. The resolution runs through §11.59.4's two-registry split unchanged: `euro2` names
`audio.speaker_lowz`, whose `defaultConnector` is `conn.binding_post`, and the connector table's own
`euro2` overrides it to `conn.euroblock_2`. The same mechanism `c13` forced.

**11.59.11 ONE TOKEN RESOLVES TO A DIFFERENT FAMILY IN ONE DIRECTION, AND A DESTRUCTIVE PINOUT IS
WHY.** Settled by the user on 2026-08-15, after the summary line was read against real output and
`1 ir35 in "IR IN"` was seen resolving to **`ctl.ir_emitter`**.

`seed_registries.dart` states the hazard where the two IR families are declared: *"receivers are
tip = signal, ring = GND, sleeve = +12 V; emitters are tip = IR in, sleeve = GND. Plugging an
emitter into a receiver jack destroys the emitter and can damage the supply."* AC-052 makes
`pinoutVariant` mandatory on every 3.5 mm IR port for exactly that reason. docs/06 §9.1 then types
`ir35 out` at step 9 for emitters and `1 ir35 in "IR IN"` at step 12 for the matrix's IR **input**,
which is a receiver input. **One token, two families, and the direction is what separates them.**

**Ruling: `ir35 in` resolves to `ctl.ir_receiver`, `ir35 out` to `ctl.ir_emitter`,** and the
connector follows the swapped family's default unless one was named, which §11.59.4 already governs.

**IT IS A NAMED TABLE HOLDING ONE ROW, NOT AN `if`.** A second directional pair is then a row rather
than a second branch. It is deliberately NOT a field on `SignalFamilyDef`: expressing one fact would
cost a model field, a codec change and four regenerated starters, and DR-010 §11.10.4's rule is to
seed a field once something needs it. **If a second pair ever appears, that is the something.**

**This is the only exception to "one alias, one family" in the resolver**, and it is stated here so
a reader finding it does not conclude the rule has eroded. The test for admitting another is the one
this passed: a wrong answer is not merely inconvenient but **destroys hardware**.

### 11.60 DR-061 · The port grid's selection is a row range and a focused column, and the tick box is that selection

**Settled by the user on 2026-08-15**, at M4-F's pick-up census (board `#177`, and the task `#695`
this ruling created). **This is not a §8.3 amendment**: docs/06 §4.6 already tabulates every editing
operation and roadmap §2 already carries the grid. It has a ruling ID because **§4.6 describes the
selection two incompatible ways and the corpus never says what one is**, so every M4-F task rested
on a word with no referent.

**11.60.1 The two phrasings.** §4.6's `Fill down` row reads *"copies the top cell of the selection
to every cell below it"*, which describes a **column of cells with a top**. Its `Multi-row edit` row
reads *"select N rows, edit any cell"*, which describes a **set of rows**. A cell range and a row
set are different objects, and a reader building either one satisfies half the table.

**11.60.2 The census: there was no selection at all.** `port_grid.dart:175` holds `_ticked`, a
`Set<String>` of port keys, fed by a checkbox in the gutter and read by exactly one thing, the
delete button. There is no anchor, no focused cell, no range and no painting of one. **None of
M4-F's five tasks builds one**, because each was written from its own operation's risk and the
selection was never in dispute: `check a decomposition for holes` in its input form, for the sixth
time in this repository.

**11.60.3 The ruling.** The grid's selection is:

```text
selection := a contiguous run of rows, plus the individual rows Ctrl+click has added or removed
column    := whichever cell holds focus
```

Click selects one row. `Shift`+click extends from the anchor. `Ctrl`+click toggles one row. The
checkbox in the gutter toggles the same row in the same set. `Delete` acts on it, unchanged from
M4-E.

**11.60.4 WHY NOT A 2D CELL RECTANGLE, WHICH IS WHAT EXCEL DOES.** The premise for one is real:
docs/06 §4 is explicit that *"integrators live in Excel"* and that every ergonomic they know has to
work. So the rectangle was priced against §4.6's own table rather than against the sentence, row by
row:

| What the operation needs | §4.6 rows |
|---|---|
| Whole rows, no column at all | `Multi-row edit`, `Duplicate`, `Delete`, `Reorder`, `Renumber…`, `Move to bank…`, `Copy / paste`, `Sort`, `Mirror bank` |
| Rows, and it **names its own columns** | `Fill series` (the label), `Change type…` (connector and family), `Find & replace` (a scope the dialog picks from labels, keys, designators or notes) |
| Rows, and **one** column from elsewhere | `Fill down` |
| One cell | `Edit cell` |

**A rectangle would be consulted by one row of fourteen, and that one wants a single column rather
than a range.** The three operations that look column-shaped each carry their own column in their
definition, which is why they read as column-shaped and why a selection cannot tell them anything
they do not already know. Building the rectangle would be `measure the control before choosing it`
answered the wrong way: a painting layer, a keyboard model crossing collapsed bands and sticky
headers, and a partial-row TSV paste whose meaning nobody has decided, bought for `Ctrl+D`.

**The Excel premise is honoured where it is actually load-bearing**, which is `Copy / paste`: M4-F3's
own test is a **whole bank** copied out and pasted back, byte-compared on the resulting
`TemplateBody`. Whole rows are what round-trips.

**11.60.5 THE TICK BOX IS THE SELECTION, one set with two affordances.** The alternatives were both
rejected for the same reason. Keeping ticks and selection as separate sets puts two highlight states
on one row and makes every operation carry a question about which set it reads, which is reported as
a bug rather than as confusion. Deleting the tick boxes removes the grid's only affordance that is
discoverable without knowing a modifier key.

Subsuming them costs nothing and preserves something: a tick set is already non-contiguous, so
`Ctrl`+click needs no new state, and **M4-E's delete tests keep their meaning exactly**, because the
set they act on is the same set under a new name.

**11.60.6 WHAT THIS DOES NOT DECIDE.** The selection is a view concept and does not serialize:
nothing here reaches `TemplateBody`, the codec or `kSchemaVersion`, and CR-117 is untouched. It says
nothing about the Structure editor's table, which has its own selection question and no ruling; when
that surface grows one, this is the precedent to argue from and not a rule it already obeys.

### 11.61 DR-062 · Fill series infers its sequence from the top selected cell, because there is no stored pattern to re-apply

**Settled by the user on 2026-08-15**, during M4-F1 (`#208`). **This is not a §8.3 amendment**:
docs/06 §4.6 already gives `Fill series` its key and its row. It has a ruling ID because **the row
names a stored artifact that has never existed**, so the feature could not be built as written.

**11.61.1 The census.** §4.6 reads *"Re-applies **the** label pattern across the selection with a
fresh `start`"*. Measured against the tree:

| | Finding |
|---|---|
| `PortDef` | no pattern field |
| `BankDef` | `key`, `label`, `abbr`, `symbolSide`, `collapseInSymbol`, `order`. **No pattern** |
| `TemplateBody` | no pattern field |
| `LabelPattern` | referenced by **two files in the tree**: its own, and `quick_add.dart`, where it lives in a `TextField` and is discarded when the bar clears |

The definite article points at nothing. `a modelled field is not a reachable one` inverted: not a
field with no gesture, but **a gesture naming a field nobody modelled**.

**11.61.2 The row four lines below it is what settles the shape.** `Renumber…` `Ctrl+R` reads
*"re-applies **a** label pattern to the selection in current display order"*. **Indefinite article,
and an ellipsis**, which by convention means a dialog. `Fill series` has neither. So the corpus
already distinguishes them: one asks the user for a pattern, the other acts immediately from
something it can work out for itself. A `Fill series` that prompted would be `Renumber…` with a
second binding, and one of the two would then have to be deleted.

**11.61.3 The ruling.** The series is **inferred from the top selected cell**, on Excel's own rule:
the **last** run of digits becomes the counter, everything around it stays literal. `IN 01` yields
`IN 01, IN 02, IN 03`.

**THE LAST RUN AND NOT THE FIRST, and this catalog is why.** Labels here routinely carry a
standard's number before the port's: `HDMI 2.0 IN 1`, `802.3bt PORT 4`, `RS-232 CTL 2`. A rule
reading the first run would count the standard and leave the port number alone, wrong in exactly the
cases that matter most.

**THE TOP CELL IS THE START**, which is what *"a fresh `start`"* becomes once the pattern is
inferred: fresh relative to the selection rather than to the bank. Selecting rows 9 through 16 and
pressing it keeps them 09 through 16; a counter restarting at 1 would renumber them over the eight
above.

**11.61.4 Why not store the pattern.** `BankDef.labelPattern` is the only reading that makes *"the"*
literally true, and it was rejected on coverage rather than on cost. It is **null for every port
created by `+ Add port`, by paste (M4-I3), or by any archetype generator M4-I builds**, so the
feature would work on Quick Add's banks and silently decline everywhere else. Inference works on all
of them. DR-010 §11.10.4's rule is to seed a field once something needs it, and one feature that
would half-use it is not that.

**11.61.5 A REFUSAL IS A SENTENCE, NEVER A SILENCE.** Five ways a fill declines, each with its own
message naming the way forward: fewer than two rows, no focused column, a column no fill may write
(`KEY`, `PAIRED WITH`, `WAS CALLED`), a series asked of a non-text column, and a top cell holding no
digits. **A key that quietly does nothing is indistinguishable from one that is not bound**, which
is how a person concludes a feature does not exist. `SPEAKER` therefore refuses rather than falling
back to a copy, because the fallback would be discovered sixteen rows later.

**11.61.6 Fill series is text-only, and narrowly.** Three columns carry one: `LABEL`, `DESIG`,
`NOTES`. `poeWatts` 15, 16, 17 would rewrite a bank's electrical facts as a counting sequence.
**`SET` and `ROLE` are excluded for a stronger reason**: they are keys into `PortSetDef`, so a
series down one invents memberships no set declares, which is the dangling-reference state the grid
already draws a red band for. Both still fill **down**, where copying one valid key into four rows
is exactly what a person means.

### 11.62 DR-063 · A disagreement is not an unknown, and the identity columns are not batch-editable

**Settled by the user on 2026-08-15**, during M4-F2 (`#209`). **Not a §8.3 amendment**: docs/06 §4.6
already gives multi-row edit its row and §2 already draws the batch inspector. It has a ruling ID
because it **corrects two things §4.6 says**, and the first of them is a G4 collision.

**11.62.1 `—` ALREADY MEANS SOMETHING.** §4.6's multi-row row reads *"mixed values render `—` and
are left untouched unless explicitly set"*. The second half is right and is enforced. The first half
spells a disagreement the way the whole product spells an **unknown**: `kUnknownCell`, G4/CR-114,
*nobody has measured this*.

Eight ports nobody has measured and eight ports carrying 75 Ω and 110 Ω are **different facts**, and
an installer reading `—` on `IMPEDANCE` concludes the first while the second is true. That happens on
the one surface built specifically for looking at many rows at once.

**Ruling: `—` keeps its single meaning. A disagreement renders as `Mixed (N values)`**, naming how
many distinct values the selection holds. CR-114 states the same discipline for a document: a rollup
**reports its unknown count rather than fabricating a total**. This is that rule applied to a column
of N rows.

**AN UNKNOWN AMONG VALUES IS A DISAGREEMENT**, counted as one of the values. Three ports at 75 Ω and
five unmeasured is `Mixed (2 values)`, because calling it either agreement or unknown fabricates.

**11.62.2 THE IDENTITY COLUMNS ARE EXCLUDED FROM MULTI-ROW EDIT.** §4.6 says *"edit any cell, it
applies to every selected row"*, and `LABEL` and `DESIG` are the two cells where that is almost
never the intent and is expensive when it is not:

| | What one edit across eight rows does |
|---|---|
| `LABEL` | eight ports called `HDMI IN`; and on a port this session created the KEY follows the label, so `autoPortKey` also mints eight colliding keys suffixed `.2`, `.3`, `.4` |
| `DESIG` | eight duplicate designators, which the grid's own validation dot then reports on every row |

**The capability is not lost, it is routed.** `Ctrl+Shift+D` writes a column of labels and is the
gesture designed for it (DR-062), so the answer to *"name all sixteen"* is a key that already exists
rather than one that collides. **A confirmation dialog was the rejected third option**: docs/06 §4's
binding premise is that any interaction costing one click per port is a design failure, and a modal
in the middle of the grid whose criterion is measured with a stopwatch is that failure wearing a
safety label.

`KEY`, `PAIRED WITH` and `WAS CALLED` remain out for `port_fill.dart`'s reasons, which have not
changed: a key is `final` on the model, a pairing is a `passthroughPairs` entry rather than a field,
and `renamedFrom` is CR-051's alias trail, which a batch write would be forging.

**11.62.3 WHAT IT DOES NOT DECIDE.** The batch inspector is what docs/06 §2 already says it is: the
right dock **swaps** to it when more than one row is selected. The three live previews that occupy
the dock the rest of the time are M4-K (`#182`) and are not built, so the dock exists only in the
batch state until then, which is `device_builder_screen.dart`'s standing rule that a pane opening
onto nothing is the `UnbuiltView` defect wearing a different hat.

### 11.63 DR-064 · The reorder is within a band, and the index generator gets its missing character

**Settled by the user on 2026-08-16**, during M4-F4 (`#211`). **A §8.3 amendment in one clause**
(11.63.1 narrows a sentence in docs/06 §4.5); the rest either implements what §4.6 already rules or
fixes a defect found while doing so.

**11.63.1 THE DRAG HANDLE REORDERS WITHIN A BANK, NOT ACROSS BANKS.** docs/06 §4.5's column table
says the `⠿` handle reorders *"within and across banks"*. Within is built. Across is not, and the
reason is structural rather than an omission: the grid's bands are **pinned sticky headers over
per-band lists**, and no toolkit reorderable list hands a dragged item to a sibling list. The three
ways out were priced:

| Option | What it costs |
|---|---|
| **(a) Within a band, taken** | One reorderable list per band. The sticky header survives, the drop indicator and the autoscroll come from the framework, and a widget test can drive the whole gesture. Moving a port to another bank stays the `Bank` column, which is already built and is one edit. |
| (b) Across banks, headers demoted to list items | Cross-bank drag works as drawn. The **pinned bank header goes**, so a person forty rows into the HDMI inputs can no longer see that these are the HDMI inputs. That header was built deliberately in M4-E1. |
| (c) Across banks, hand-built over the pinned layout | Both behaviours. Custom hit-testing, a custom drop indicator and hand-written autoscroll inside a widget that already scrolls in both axes: roughly three times the code, and the part no widget test can reach is exactly the part that breaks. |

**Ruling: (a).** The capability is **routed, not lost**, on DR-063's precedent: the `Bank` column is
the way across and every refusal names it out loud. §4.5's handle row is amended to read *"Reorder
within a bank"*, with the routing stated beside it.

**11.63.2 AN ARROW KEY NEVER RETYPES A PORT.** `Alt+↑` on the top row of a band **refuses and says
so**, rather than moving the row into the band above and adopting its `bankKey`. The keyboard path
is pure arithmetic and could have crossed even though the drag cannot, and that is exactly the
argument against it: the chord would then sometimes mean *move* and sometimes mean *move and
reclassify*, and a structural edit to the template delivered by an arrow key is how a jack ends up
in the wrong bank on a printed panel. The keyboard and the mouse agree about where the wall is.

**11.63.3 A SELECTION MOVES AS A BLOCK.** A drag or an `Alt` press with N rows selected moves all N,
keeping their order relative to each other and landing them contiguous. This is DR-061 and DR-063's
reading continued: selecting N rows and acting means acting on N rows, and a reorder that ignored
the selection would be the one grid verb that does, which is an exception learned by being
surprised. A block with a gap in it lands closed up, above the nearest row above it that is staying
put. **N rows moved is N field writes and no others**, which is what §4.6 means by *not a renumber of
the bank*.

**11.63.4 `nextOrder` EXTENDS WITH `'1'`, NOT `'0'`.** A defect, found while building the midpoint
generator, in code that shipped in M0 and was correct until this task.

`nextOrder` allocates the next `FracIndex` by bumping the last character, or by appending one when
that character is already the alphabet's last. It appended `'0'`, which is the **lowest** character,
so `'az'` was followed by `'az0'`: a pair with **nothing representable between it**, since any index
strictly between them would have to be `'az'` plus something below the lowest character there is.
A template reaches that pair at its **63rd port**, which is a patchbay. Every insertion between those
two rows would have had to be refused for a reason nobody could see or fix.

**Appending `'1'` costs one of 62 slots and leaves the gap open permanently.** The test that pins it
walks a 200-long allocation chain and splits every adjacent pair, and it was checked that reverting
the character fails it. No shipped starter or catalog template contains an index ending in `'z'`, so
no file on disk holds the pair.

**`orderBetween` returns null rather than renumbering.** One input shape has no answer and it is now
unreachable by anything this program mints. A hand-edited file can still hold it, and the honest
response is a named refusal: renumbering the neighbours is precisely the operation CR-027 chose this
field's type to avoid.

**11.63.5 WHAT IT DOES NOT DECIDE.** The auto-designator renumbering that follows a reorder is not
changed and is not a defect. `PORT_SEQ` is the rank in the declared order and `J{PORT_SEQ:2}` renders
from it, so moving a port renumbers it and everything below it. A silkscreen follows the physical
order of the jacks; CR-042 leaves the project to allocate, and a `designatorHint` the author pinned
survives untouched, because that is what pinning means.

### 11.64 DR-065 · A sort is a way of looking, and four things follow from saying so

**Settled by the user on 2026-08-16**, during M4-F5 (`#212`). **Not a §8.3 amendment.** docs/06
§4.6 already rules the sort view-only with a badge and `Commit sort order` a separate explicit
action, and AC-058/D5 already gives that action a confirm. This records the four things neither
document decides, each of which is a fork the implementation could not avoid.

**11.64.1 A SORT WORKS INSIDE EACH BAND.** A bank is a presentation grouping the template's author
made (CR-055) and the grid draws it as a pinned sticky header. A sort is a question about the rows,
not about whether the grouping exists, so each band sorts within itself and the headers stay.

Flattening the bands while sorted was the alternative and it loses twice: it hides the structure at
the moment a person is scanning for an outlier, and it makes the commit **interleave the banks in
the declared order**, which reorders the bands themselves. That is a large structural edit arriving
from a header click.

Sorting within a band also makes the commit a **permutation of the positions each band already
occupies**: the k-th smallest index the band held goes to the k-th row on screen. No index is
minted, so a commit can never be refused for lack of room; the band keeps its place among the other
banks, so committing a sort of the HDMI inputs cannot move the outputs; and only the ports that
actually move are written.

**11.64.2 AN UNKNOWN IS NOT A VALUE, SO IT LEADS NEITHER ORDERING.** Unknowns sort **last ascending
and last descending**, which means the null branch runs outside the direction flip.

A spreadsheet treats a blank as the smallest thing there is. Here that answers *"the lowest
impedance on this device is eight ports nobody has measured"*, which is the precise fabrication G4
and CR-114 exist to prevent, delivered to the one person most likely to act on it. DR-063 made the
same call one task earlier for a different reading of the same dash.

**11.64.3 A REORDER REFUSES WHILE A SORT IS SHOWING.** The drag handle is drawn dimmed and inert,
and `Alt+↑`/`Alt+↓` refuse in words naming the badge.

Under a sort, *up on screen* is not *up in the order a move would write*, so a drag would land the
row somewhere the person cannot predict from what is in front of them. The two rejected options
were both worse: letting the gesture operate on the declared order makes the row visibly jump to an
unrelated place, and having it silently commit the sort first turns a data-loss edge into an
accident, which is the exact thing AC-058/D5 gave the action a confirm to prevent.

**11.64.4 THE CONFIRM NAMES THE CONSEQUENCE, NOT THE ROWS.** *"This rewrites the declared order of N
ports. The symbol pin order, the rear panel layout and the automatic designators all follow it.
Undoable."*

`completeness §D5` credits `Renumber` with having a diff and names `Commit sort order` as lacking
one. A full before-and-after list is the honest reading of that, and it is 64 lines inside a modal
on the device this grid exists for; **a list nobody reads is a confirm nobody reads.** What a person
cannot see is not *which* rows move, which is on screen in front of them, but *what else follows the
order*, which is three things and none of them visible here. The count is what makes it checkable.

**11.64.5 WHAT IT DOES NOT DECIDE, AND ONE THING LEFT VISIBLE ON PURPOSE.** A sorted grid shows
`J01` somewhere in the middle, because `PortTableRow.portSeq` is the rank in the **declared** order
and the designator renders from it. That is not a defect to paper over: it is the one glance that
tells a person the rows in front of them are not the rows in the file, and it is the reason the
badge can be believed.

---

### 11.65 DR-066 · The viewport is a way of looking: framed on arrival, remembered on return

**Settled by the user on 2026-08-17**, during M6 (`#710`, and DR-066's own commit). **Not a §8.3
amendment.** No document decided what a rack canvas shows when you first look at it; the screen
did whatever `reset()` plus a caret nudge happened to produce, which was zoom 1.0 with U1 pushed
just far enough onto the screen to be legal.

**11.65.1 A RACK ARRIVES SHOWING ALL OF ITSELF.** The opening view fits the whole rack into the
canvas and centres it.

At zoom 1.0 a 42U rack shows about two thirds of its height, so the first act of every session was
to zoom out, and the state a person judges an elevation from was one they had to build by hand
every time. Nothing in the corpus required unity: CR-001's integer units fix what a scene
coordinate *means*, not what magnification it is drawn at, in the same way that defining a metre
does not commit a map to printing at 1:1.

**11.65.2 CENTRED IN THE SPACE THAT IS FREE, NOT IN THE BOX.** The fit targets the canvas minus an
84px top band, and the result is then pushed down past it.

The zoom HUD, the face toggle and the header row are all pinned at `top: 12` and span roughly 60px
of floating chrome. docs/04 §4.1's drag-to-resize is an 8px grab band centred on the rack's **top
edge**, which is precisely where a raw centring puts that edge: under the chrome, where no pointer
reaches it. A documented affordance that cannot be clicked is not a cosmetic defect, and nine
widget cases reported it within the same minute the framing changed.

**11.65.3 EACH RACK REMEMBERS WHERE IT WAS LEFT, FOR THE SESSION.** Switching to RK-2 and back
returns RK-1 to the pan and zoom it was left at. The memory lives on the screen's state: not in the
`.rmpj`, where a pan would dirty a file under CR-117's byte round-trip, and not in preferences,
where a bad view would outlive the restart that is currently the only way to escape one.

**A REMEMBERED VIEW IS DECLINED WHEN THE RACK'S HEIGHT CHANGED.** Growing a rack from 9U to 42U
moves U1 by up to 726 scene units, which is off the bottom of any window this app supports, so a
view remembered at the old height is not a view of the same thing. The height is therefore stored
beside the matrix and a mismatch re-frames under 11.65.1 rather than restoring.

**11.65.4 NOTHING CHASES A CARET ACROSS A RACK SWITCH.** The keep-the-caret-visible pan declines
while the viewport still belongs to a different rack than the model does.

This is recorded because the bug it fixes is invisible by construction and will be re-introduced by
anyone who does not know it. The caret listener fires from `setState`, one layout **before** the
framing pass, so for one moment the geometry is the incoming rack's while the matrix is still the
outgoing rack's. A screen-space answer computed across that mismatch describes neither rack:
switching a 12U view to a 42U rack put U1 at y = 2960 on a 1000px canvas, so the pan "rescued" a
caret that was never lost by moving 1984px, and the memory in 11.65.3 then recorded that as where
the outgoing rack was left. The restore was returning RK-1 to a place it had never been.

**11.65.5 WHAT THIS COSTS THE TEST SUITE, RECORDED SO IT IS NOT RE-LEARNED.** Sixty-six widget
cases failed on the first framing change, none of them because the behaviour was wrong. Every one
had written `canvasOrigin(tester) + Offset(rect.left, rect.top)`, which is scene→screen **only
while the transform is the identity**, and eight drag cases had passed scene units to `moveBy` as
though they were pixels. A test that hard-codes a camera is asserting the mechanism, not the
artifact. They now go through the same `ViewportController` the canvas paints with, so the next
change to the opening view costs nothing in test edits.

---

### 11.66 DR-067 · A class you can assert, and a classifier you can hear disagree

**Settled by the user on 2026-08-17**, during M3 (`#712`). **Not a §8.3 amendment.** DR-008 §11.8.2
already rules the classifier advisory, a user's class binding, and the disagreement visible. What
none of that decided is where a person does it, which is why for two milestones the answer was
**nowhere**: `SetLinkClassCommand` and `ClearLinkClassOverrideCommand` were complete in core, with
undo, and no surface in the product called either. A class could be classified and never asserted.

**11.66.1 THE CONTROL IS A `CLASS` COLUMN IN THE STRUCTURE EDITOR, AND ITS MENU HAS FIVE ENTRIES.**
Four classes plus `AUTO`.

The editor already owns the machinery this needs: closed-set dropdown cells, fill-down, the batch
bar, and one edit path per column. The schematic's selection inspector was the alternative and it
reaches more links, jumpers and rack-to-rack runs included, but setting a class one wire at a time
is the ergonomics DR-020 §11.19.2(5) rejected for lengths in the same words: "one table with a
column they tab down, not sixty inspector visits". **What this deliberately does not reach is a link
with no `structureOrigin`**, which is a real gap and is recorded as one rather than papered over;
the inspector remains the right home for it and is not built.

**`AUTO` IS NOT THE DASH AND THE DIFFERENCE IS THE COLUMN'S POINT.** The dash means the classifier
could not resolve an end, which is G4 applied to a classifier and is a fact about the document.
`AUTO` means "let the classifier decide", which is a decision and is the default state of every
link. Spelling them the same would make handing a run back indistinguishable from declaring it a
mystery. It also follows that the dash is **not on the menu**, so a run with an effective class of
nothing has no option to sit on and renders as a hint over an empty value.

**11.66.2 THE COLUMN IS OPTIONAL, NOT A NINTH DEFAULT.** §4.1's set answers *"what am I pulling and
where does it land"*. A class is normally derived and normally right, so a column carrying it by
default would spend width teaching people something the classifier already knows. `FIELD TERM`
became a default at DR-046 because two ends were being conflated into one; nothing here is being
got wrong by default.

**11.66.3 AN OVERRIDE IS PINNED, AND THE PIN CARRIES THE CLASSIFIER'S ANSWER IN WORDS.** A cell a
person has set draws a pin; resting on it says so, and says what the classifier now reads the run as
when the two differ.

**NOT AN ERROR, AND NOT A VALIDATION FINDING.** Overruling the classifier is something §11.8.2
provides for. A rule not in the 28-rule catalogue does not exist (CR-021), and a warning on a
legitimate act is how people learn to ignore warnings. The mark is drawn in `tertiary`, never in
`error`.

**A SENTENCE, NOT A COLOUR.** §11.8.2's clause is that the disagreement stays *visible*, and a
glyph that changes shade says only "something". *"You set jumper; this now looks like a field
cable"* is the statement the ruling asks for, and it is the only thing that keeps an override
auditable after the document moves under it. Both endings name `AUTO`, because a pin a person cannot
see how to remove is the one-way door `ClearLinkClassOverrideCommand` exists to prevent.

**11.66.4 PICKING THE WORD ALREADY ON SCREEN IS AN EDIT HERE, AND ONLY HERE.** For `ROUGH-IN`,
`FIELD TERM` and `RACK TERM` the label shown is the stored value, so re-picking it changes nothing.
For `CLASS` the label shown is normally the **classifier's**, so picking it moves the run from
"nobody has said" to "a person says so". That is a real change of state, and it is the one
`SetLinkClassCommand` explicitly refuses to demote: an assertion that happens to agree today is
still an assertion, and dropping it would lose the person's word the next time the document moved.

**11.66.5 WHAT `AUTO` DOES NOT DO.** It drops the pin and leaves the stored class where it was,
inert. Writing the classifier's current answer into the field on the way out would store a value
computable from other stored facts, which is what CR-107 deleted `StructureDrop` for, and would make
undo restore a value no person ever chose.


### 11.67 DR-068 · Either end of a run may land on a device, because a speaker run is one cable

**Settled by the user on 2026-08-18**, during M3 (`#713`, `#714`), after diagramming a real system.
**Not a §8.3 amendment.** AC-018 already names `BindEndpoint` and rules that binding preserves the
id, the length, the jacket and the test result. What it did not decide is which END may bind, and
the implementation answered "the rack one" without the question being put.

**11.67.1 A HOME RUN MAY TERMINATE ON A DEVICE AT EITHER END.** `BindEndpointCommand` takes a
`LinkEnd` and writes `Conductor.from` or `.to` accordingly. It defaults to the rack end, so every
call site written before this keeps its meaning untouched.

For structured cabling the old behaviour was right and stays available: a Cat6 drop ends at a wall
plate, and whatever plugs in there is a separate patch cord that the schedule should show as a
separate cable. For AV it was wrong often enough to matter. **An in-wall or in-ceiling speaker run
is ONE continuous conductor from the amplifier to the binding posts on the driver**, and a product
that could not say so forced the user to draw a second cable that does not exist, on the sheet whose
whole purpose is to be true.

**11.67.2 THE ENDPOINT IS SYMMETRIC AND THE LABELS ARE NOT.** A rack bind writes the rack label; a
field bind writes no label at all, and the constructor asserts that a field bind is not handed one.

This is a fact about the two labels rather than an omission. A **rack label is derived from where
the run landed**: `{FLOOR}`, `{PORT}`, allocated against the panel position, and therefore
unknowable until the bind happens. A **field label names the wall plate**, was typed when the drop
was created, and is unique project-wide under CR-113. Landing a speaker records where the copper
ends and says nothing about what the plate is called; writing one from the other would be the fusion
G4 forbids, and would collide the moment two speakers landed in one room. The revert is scoped the
same way, or a field bind would clear a panel position out of a null it never captured.

**11.67.3 DR-040 §11.39.2 CLAUSE 4 STANDS, AND STOPS BEING INHERITED.** Rear-only is a rule about
**the two sides of a panel in a rack**: one takes pulled cable, the other takes patch cords, and the
drop belongs on the first. An in-wall speaker has no such geometry, its binding posts are simply its
terminals, and inheriting the split offered it zero positions and refused every direct run. The free
position walk now takes the end, so clause 4 governs the rack end exactly as before.

**11.67.4 WHAT THE SCHEMATIC CAN AND CANNOT SHOW, RECORDED AS A CONSTRAINT.** The sheet is a device
graph: symbols come from `doc.devices`, and `_edgeFor` returns null when either end is not a
`PortEndpoint`. So a run with **one** end landed can hang a stub off the device it reached, and a
run with **neither** end landed has nothing to hang off and cannot be drawn at all. Those must be
**counted on the sheet** rather than omitted from it, because the user's own reason for asking is the
one that matters: *"someone's going to forget one or two and not notice it until the schematic is
ready to be printed."* A sheet that silently holds fewer runs than the project does is the failure
this ruling exists to prevent, not a lesser version of it.

---

### 11.68 DR-069 · Whose binding posts are they? The plate's, or the speaker's

**Settled by the user on 2026-08-18** (`#717`), reported from real use: tagging a ceiling speaker's
run `BINDING POST` demanded two plate cells, *"and a ceiling speaker wouldn't even get a low voltage
box let alone keystones"*. **Amends DR-007 §11.7.2.1's binding-post arm.**

**11.68.1 THE CELL COUNT FOLLOWS WHERE THE RUN LANDS, NOT THE TERMINATION WORD.** A `bindingPost`
field end that is bound to a device port needs **zero** cells. One that is still a place needs **one
cell per conductor**, exactly as before.

Both readings of the word are real hardware, and that is what makes this the one arm the enum cannot
answer alone. A **speaker binding-post wall plate** is a product: its posts are on the plate, each
conductor lands in a cell, and §11.7.2.1's original arm was written for it and is still right. An
**in-ceiling driver's** posts are on the driver, and nothing sits in a cell because there is no
plate. `keystone` and `punchdown` are always the plate's; `euroblock` and `rj45Plug` are always the
device's; only `bindingPost` is genuinely either. DR-068 is what made the difference expressible.

**11.68.2 NO OTHER ARM READS THE LANDING**, and the narrowness is the rule rather than an
implementation detail. A test asserts it for every other member, because a landed end says where the
copper goes and not what it goes into. An unknown termination stays unknown either way: there is no
"probably zero" arm and there must never be one (G4).

**11.68.3 TWO ALTERNATIVES WERE REFUSED, AND ONE OF THEM BY THIS RECORD'S OWN PRECEDENT.**

`fieldConnector` as a catch-all is refused for the reason DR-045 §11.44.1 already refused it for
`rj45Plug`: it *"names no connector at all and would leave the Termination Schedule saying nothing
useful to somebody deciding whether to reach for a crimper or a punchdown tool"*. A ceiling speaker
has no connector at all, so the tag would be both uninformative and false, on the one column a trim
tech actually works from.

A new `directTermination` member is refused because it puts one fact in two places. The topology is
already recorded, by DR-068, as which endpoint the conductor holds; a second statement of it in the
termination enum lets a document say `DIRECT TERMINATION` on a run whose field end is an unlanded
wall plate, and the schedule would then print a termination the model says did not happen. That is
the conflation DR-046 spent a ruling undoing when one field was serving two cable ends.

**11.68.4 THIS IS THE THIRD TIME THE ENUM HAS BEEN ASKED A QUESTION IT CANNOT ANSWER, and the
pattern is the finding.** DR-044 §11.43.4 corrected `euroblock` from one cell to zero on precisely
this reasoning, after M3-H had put it beside `keystone` *"on an inference nobody wrote down"*. DR-045
§11.44.2 then asked it of `rj45Plug` out loud rather than inferring it, and said why. The question a
cell count actually turns on is **whose hardware is this**, and for two of the nine terminations the
word does not carry it.


### 11.69 DR-070 · A run may come out of no box, and "there is none" is not "nobody has said"

**Settled by the user on 2026-08-18** (`#713`, `#718`), from the same session as DR-068 and DR-069
and for the same reason: *"a ceiling speaker wouldn't even get a low voltage box let alone
keystones"*. **Amends AC-018 and DR-007's shared assumption that every home run has an `Outlet`.**

**11.69.1 A HOME RUN NAMES A LOCATION ALWAYS AND AN OUTLET ONLY WHEN THERE IS A BOX.**
`StructureOrigin.outletId` becomes nullable.

The Outlets page listed a plate for a speaker that has none, which is the class of quiet fiction
that gets believed on site. Every other reading of the field was already correct by construction:
`computePlateFill`, `plate_arrange` and the CSV importer all filter on `origin.outletId != outlet.id`,
which excludes a boxless run without being told to.

**11.69.2 THE ABSENCE IS NOT THE STATEMENT. A SECOND FIELD IS.** `StructureOrigin.boxless` sits
beside the nullable id.

G4 gives an absent value exactly one meaning and it is **unknown**. A ceiling speaker having no box
is something a person **stated**, and a drop nobody has assigned yet is a gap in what is known.
Folding both into a null makes them indistinguishable in the file and uncountable on the page, which
is the fusion DR-046 spent a ruling undoing when one field was serving two cable ends. Two facts,
two fields.

**IT IS NOT DERIVED FROM THE LANDING.** A speaker run is boxless the day it is pulled, months before
anyone terminates it, so a rule that waited for DR-068's field-end bind would leave the Outlets page
claiming a plate for it in the meantime. That is the fiction this removes, not a smaller version of
it.

**11.69.3 CR-117 HOLDS AND `kSchemaVersion` DOES NOT MOVE.** `outletId` was required until now, so
every document ever written carries one: reading yields it and writing writes it back. `boxless` is
written **only when true**, because false is what every older document means and emitting it would
rewrite every home run in the corpus on first save. This is the same permission DR-008 §11.8.2 took
for `linkClassLocked`, and it rests on the same property, so it is gated the same way: by a wire
test whose load-bearing cases are the **negative** ones.

**11.69.4 THE GESTURE IS `@nobox`, A FLAG.** The first valueless modifier in the drop-line DSL.
Every other one answers *which one*; this answers *there is none*, and `@nobox=true` invites
`@nobox=false`, which is the default and states nothing. It is deliberately **not** `@outlet=none`,
which would put "there is no box" into the field that names the box, and a person naming an outlet
`none` is doing something legal and unrelated. With `@outlet=` it **refuses** rather than ranking
one above the other, because the line states two incompatible things and the person meant one.

**11.69.5 THE OUTLET COLUMN HAS THREE STATES.** A designation, `— NO BOX —`, or the dash.
`kNoBoxCell` is a distinct token for the reason `kOpenEndCell` is: an estimator counting plates off
that column cannot otherwise tell an unassigned drop from one that will never have a plate.

**11.69.6 WITHOUT A BOX THE FIELD END MUST NAME A ROOM, AND A RUN THAT CANNOT IS REFUSED.**
`buildScheduleEntry` resolves a run's room as `from.locationId ?? outlet?.locationId ??
to.locationId`, and its own comment calls the last term a trap: *"a run's room is where its drop is,
not where its rack is ... AC-025's 'the order the tech walks the house' means nothing if every row
groups under the equipment room."* With a box the outlet answers. Without one the field end is the
only thing that can, so a boxless run carrying no location would sort itself silently onto the
wrong page of the sheet an installer walks the house with. Refused at creation rather than papered
over at render time.

**11.69.7 WHAT IS STILL UNKNOWN WITHOUT A BOX.** `wall`, `mountSurface` and `mountHeightAff` are
copied from the outlet when there is one and left **unknown** when there is not. The outlet is the
authority on where a run sits; substituting a height for a run with no outlet would put a number on
a schedule nobody measured.


### 11.70 DR-071 · Landing a drop is a gesture, and the product picks the hole

**Settled by the user on 2026-08-18** (`#715`), as the third phase of `#713`. **Not a §8.3
amendment.** AC-018 names `BindEndpoint` and DR-040 §11.39.2 rules how a drop lands; neither says
where a person does it, and for two milestones the answer was **only while typing the line that
creates the drops**. A run entered without `@panel=` could never be landed at all.
`label_key.dart` had already described the missing gesture in prose: *"the single bind a person
makes when they punch one stray drop down"*.

**11.70.1 THE CONTROL IS A `LANDS ON` COLUMN, AND ITS MENU OFFERS PANELS RATHER THAN POSITIONS.**

Every other editable column in that table writes what it is handed. This one is handed a **panel**
and allocates a position, which is what `@panel=` has done since M3-K/2: which hole a drop goes in
is the product's job. A menu of every free position on a job is hundreds of rows and asks a person
to choose something the allocator does better and faster.

**IT OFFERS EVERY DEVICE WITH A FREE REAR POSITION, not "every patch panel".** `@panel=` matches on
designator against any device for the same reason, and DR-068 §11.67.1's speaker run lands on an
**amplifier**: a filter that knew what a patch panel was would refuse the case that ruling exists
for. What makes a device offerable is that it has somewhere for a pulled cable to go, which
`freePanelPositions` already answers.

**11.70.2 IT IS BATCHABLE ON A RUNNING RESERVATION, and that is the property that makes it worth
building.** Landing forty-six drops on one panel is **one value across forty-six rows and forty-six
different holes**. Each edit therefore has to see the positions its siblings took, which
`freePanelPositions(alsoClaimed:)` was written for. Without it every drop in a batch lands on
position 1 and the gesture is silently nonsense: the kind of defect that is invisible in the app and
discovered at the panel.

The rack label rides with the bind, because it is **derived from the position** and the bind is the
only moment the position is known (DR-040 §11.39.3). A label that cannot render does not undo the
punchdown (§11.39.5): the pin is a physical fact and the name is not.

**11.70.3 A LANDED ROW SHOWS TEXT, NOT A CONTROL.** This is the only cell in the table that differs
per **row** rather than per column, and the model is what decides it rather than a preference.
`buildBindEndpointCommand` refuses a drop that is already landed, because DR-040 §11.39.6 leaves
moving one to a different port **unruled** and silently re-landing would rewrite a termination
somebody recorded. A dropdown on such a row would be a control whose every use is refused, which is
`#711`'s defect drawn on purpose.

The action refuses anyway rather than trusting the surface, because the batch bar can still aim at a
landed row.

**11.70.4 WHAT THIS DOES NOT DO, AND IT IS THE SAME GAP DR-040 LEFT.** There is still no way to move
a drop OFF a port it is punched into. Clearing the cell refuses in words rather than unlanding,
because an unbind is a different gesture with different consequences for the rack label and the
termination, and §11.39.6 has never ruled it. Recorded here as an absence a person will meet, not as
one this ruling closes.

> **CLOSED BY DR-074 §11.73** (`#720`, built `#722`–`#725`). The clause above keeps its own words
> because it is DR-071's record of what was true on 2026-08-18. What is no longer true: a landed row
> now offers the same panel menu an unlanded one does, meaning MOVE, plus `NOT LANDED`; the cell
> that used to draw as text draws a control again, and §11.70.3's reasoning is spent rather than
> wrong. **Clearing the cell still refuses**, and now names the option that does the job.


### 11.71 DR-072 · The sheet counts the runs nobody landed, and only the end that is a job

**Settled by the user on 2026-08-18** (`#716`), the last phase of `#713`, and prompted by the
reason they gave for wanting it at all: *"someone's going to forget one or two and not notice it
until the schematic is ready to be printed."* **Not a §8.3 amendment.**

**11.71.1 TWO OF THIS PHASE'S THREE CLAUSES WERE ALREADY BUILT, and the record says so because the
finding is worth more than the work.** `net_label_layer.dart`'s `_endsOf` drops one end without
dropping the other, so a **half-landed run already draws the stub for the end it has**; its own doc
gives the reason (*"that flag is the only place the reader learns the run exists at all"*). A run
with neither end drawn is already in `unlabelledLinkIds`, the status strip already prints it, and
`net_label_layer_test.dart` pins both.

This was **checked rather than believed**. A comment asserting the product already handles something
is exactly what `#711` cost a ruling's worth of time over, and the alternative here was rebuilding
working machinery beside itself.

**11.71.2 WHAT WAS MISSING WAS A SENTENCE A PERSON CAN ACT ON.** *"N cables with no drawn end"* folds
together a run nobody landed and a link whose device carries no symbol: two problems with two
different fixes. A **half-landed** run is in neither, because it is drawn. So the sheet said nothing
whatever about the case that prompted the request.

`unlandedHomeRunIds` counts home runs whose **rack end** is not punched down, and the strip prints
it **first**, because it is the only note there that names a job rather than a limitation of the
drawing.

**11.71.3 THE FIELD END IS DELIBERATELY NOT COUNTED.** DR-068 §11.67.1 lets a speaker run land on
its driver, and a Cat6 drop ends at a wall plate for good. Counting unlanded field ends would put a
number on the sheet that never reaches zero, which is how a person learns to stop reading a number.

The rack end is different in kind. AC-018 makes an unbound one legitimate **at rough-in** (fourteen
of sixty, by that criterion's own arithmetic), and a job somebody is printing a schematic for is
past rough-in.

**11.71.4 WHAT IS STILL OWED, AND IT IS THE HALF THE USER ASKED FOR BY NAME.** There is no gesture
yet to **drag a stub onto a pin** and land the run from the sheet. The pieces exist (pennants are
hit-testable through `linkAtPoint`, and `buildBindEndpointCommand` takes it from there); what is
missing is a second arming path through `CanvasIntentDetector`, a wire origin that can hold a
pending landing as well as a pin, and a release that **binds rather than connects**. The distinction
is the whole point: `ConnectPortsCommand` would make a second cable beside the one the person is
trying to finish, which is the defect `#713` was filed for.

**IT IS RECORDED AS OWED RATHER THAN STARTED**, on the user's call, because that gesture lives in
the file with the exclusivity arbiter and the `_owned` token, whose header records three prior
defects in its mirror and which shipped `#704` green four days earlier while breaking both canvases
in the user's hands. The count above stands on its own and the sheet is honest without it; the
gesture is convenience on top of an accurate drawing, and it is worth starting rested.


### 11.72 DR-073 · Finishing a run is not making a cable, and the sheet now knows the difference

**Settled by the user on 2026-08-18** (`#719`), closing `#713`. **Not a §8.3 amendment.** DR-011
scopes drag-to-connect into the schematic and DR-071 §11.70.4 recorded this gesture as owed.

**11.72.1 DRAGGING A HALF-LANDED RUN'S PENNANT ONTO A FREE JACK LANDS IT.** The commit is
`BindEndpointCommand`, never `ConnectPortsCommand`.

This is the sentence `#713` was filed over, in the user's own words: *"if a user were to just
directly connect a speaker to an amplifier in the schematic view it would create two wires on the
project."* A run pulled at framing stage **already exists**. It carries a `W` number, a length, a
jacket and possibly a `TestResult`, and what it lacks is a pin at one end. A connect run against it
puts a second cable on the sheet beside the one the person is trying to finish, and the schedule
then prints two rows for one piece of copper.

**11.72.2 THE PREVIEW BAND IS THE CABLE, WHICH IS WHY THIS FITS THE EXISTING GESTURE.** The armed
source is the pin the run is **already** on, not the pennant.

That is a statement about the model rather than a convenience. A half-landed run landed onto a
second pin genuinely is a cable between those two pins, so the band drawn while the pointer is down
is exactly what the document holds one event later. The magnet, the candidate rings, the caret and
the whole teardown path therefore need no branch at all, which is most of the reason this change is
small in a file whose header records three prior gesture defects.

**11.72.3 EITHER END MAY BE THE LOOSE ONE, SO THE GRAB CARRIES WHICH.** DR-068 §11.67.1 lets a
speaker run land on its driver: a run drawn at its amplifier is waiting for a **field** end, and one
drawn at its wall plate is waiting for a **rack** end. A gesture that assumed the rack end would
rewrite the wrong half of the cable. The rack label is allocated only for a rack end, per §11.67.2.

**11.72.4 A PIN ALWAYS BEATS A PENNANT.** They sit beside one another and their hit boxes touch.
Landing a run is the rarer act and must never steal the commoner one, so the pennant is asked only
where the pin question found nothing.

**11.72.5 A PATCH CABLE'S PENNANT ARMS NOTHING.** `buildBindEndpointCommand` refuses anything with
no `StructureOrigin`, so arming there would be a control whose every use is refused, which is
`#711`'s defect drawn on purpose and the same call DR-071 §11.70.3 made for a landed row in the
table. The press falls back to the ordinary click that selects the cable.

**11.72.6 THE CANDIDATE SET IS THE FREE PINS, WHICH IS A DIFFERENT QUESTION FROM `evaluateConnect`'S.**
A bind's only occupancy rule is `TOP-003`, one cable per position, asked through
`portConductorCount` rather than answered a second time in the surface, because the command asks it
that way and two copies would let a ring say yes where the commit says no. There is no preferred
set: DR-012.3's magnet ranks candidates by whether they accept the SOURCE's family, which is a
question about a cable being created, and this one exists already.

**11.72.7 WHAT IS STILL NOT POSSIBLE, unchanged from DR-071 §11.70.4.** There is no gesture to move
a run OFF a pin it is landed on, here or in the table, because DR-040 §11.39.6 has never ruled the
unbind. Dropping onto an occupied jack refuses in the command's own words.

> **CLOSED BY DR-074 §11.73** (`#720`, built `#722`–`#725`). Dragging a landed run's pennant onto a
> free jack now MOVES that end. The gesture is this one, with the hit test taught to answer WHICH
> pennant: both flags of a run carry the same link id, so the reading that finishes a half-landed
> run and the reading that moves a landed one run in opposite directions off the same press.
> **Dropping onto an occupied jack still refuses**, in the move command's words rather than the
> bind's.


### 11.73 DR-074 · A drop punched into the wrong port can be moved, and the label follows the hole

**Settled by the user on 2026-08-18** (`#720`). **Closes the gap DR-040 §11.39.6 left open** and
which DR-071 §11.70.4 and DR-073 §11.72.7 each recorded as still owed. §11.39.6's own words are the
need: *"a deliberate 'this was punched into the wrong port' gesture is not specified here."*

**11.73.1 TWO COMMANDS, BECAUSE THEY ARE TWO ACTS WITH TWO CONSEQUENCES.**

* **MOVE** re-lands an end on a different jack. **One command and one undo entry**, because
  correcting a hole is the case the gap was named for and making a person unland then re-land costs
  two steps and leaves the document momentarily saying something false.
* **UNLAND** returns an end to an `OpenEndpoint`. Rarer and real: the panel is being replaced, or
  the drop turned out to be spare after all.

This is `link_class_commands.dart`'s split, for its stated reason: folding the second into the first
as a nullable parameter makes the common case carry a null it never wants and gives the Edit menu
one label for two opposite actions.

**11.73.2 THE RACK LABEL FOLLOWS THE POSITION, UNLESS A PERSON TYPED IT.** A move re-derives the
label; a hand-set one survives, and the surface says it was kept.

A rack label is derived from where the run landed (DR-040 §11.39.3), so `1A-PP-101` on a cable now
sitting in position 04 is a wrong hole number on the one column a trim tech works from. That is
worse than no label. But the `RACK LBL` column lets a person type one, CR-113 makes it unique
project-wide, and silently discarding somebody's own identifier is the loss G4 exists to refuse.

**THIS NEEDS A BIT, AND IT IS SPELLED THE WAY ITS TWO PRECEDENTS ARE.** `rackLabelLocked` on
`StructureOrigin`, written by the `RACK LBL` cell's own edit path and by nothing else. On the wire
it is **absent when false**, following `Link.linkClassLocked` and deliberately **not**
`designatorLocked`, which is written unconditionally: an always-written key here would rewrite every
document already on disk and move `kSchemaVersion` for nothing (CR-117).

**AND AN UNLAND CLEARS AN ALLOCATED LABEL, BY THE SAME ARGUMENT EXTENDED.** A label naming a
position the cable has left is wrong whether the cable went to another hole or to no hole. A
hand-set label survives an unland for the same reason it survives a move. **This clause was not put
to the user as its own question** and is recorded as an extension of §11.73.2's reasoning rather
than as a separate decision, so that a later reader can see which is which.

**11.73.3 THE TERMINATION SURVIVES BOTH, AND THE SURFACE SAYS SO.** `terminationRack` describes how
the cable END is finished, not which hole it sits in: a run can be punched onto a block this project
does not model at all. Clearing it on an unland would assert the crew undid work they may not have
touched, which is a fabrication in the direction G4 forbids. A person who really did pull the cable
back out clears it in the `RACK TERM` column, which is one cell and already exists.

Asking each time was considered and refused: AC-058/D5 does not list this as a data-loss edge, and a
confirm people learn to click through is worse than a default they can see and correct.

**11.73.4 NEITHER COMMAND REMOVES A PORT IT DID NOT CREATE.** `ConnectPortsCommand`'s rule, and
`BindEndpointCommand` already follows it: a pin the document already held is not this gesture's to
delete, and guessing wrong deletes a jack somebody else's cable may be about to use. A freed pin
that came from a template was always drawn and stays drawn.

**11.73.5 WHAT THIS DOES NOT DECIDE.** Which gestures reach the two commands. The `LANDS ON` cell
currently draws a landed row as plain text (DR-071 §11.70.3) precisely because re-landing was
unruled, and that reasoning is now spent; whether the cell becomes a menu, and whether dragging a
landed run's pennant to another jack means MOVE, are surface questions this ruling deliberately
leaves to the task. **Dragging a run to empty canvas must not mean unland**, which is the one
gesture named here, and named to forbid: it is a stray drag away from silently undoing a
termination.

### 11.74 DR-075 · A rack label somebody imported is a rack label somebody typed

**Settled by the user on 2026-08-19** (`#727`). **Amends DR-074 §11.73.2**, whose mechanism clause
reads *"written by the `RACK LBL` column's own edit path and by nothing else"*. That sentence was
written to keep the ALLOCATOR out, and it kept the CSV importer out with it.

**11.74.1 THE TEST IS WHO AUTHORED THE NAME, NOT WHICH CONTROL CARRIED IT.** `rackLabelLocked` means
*a person chose this identifier*, and a `rack_label` column in an imported sheet is a person choosing
one: they typed it into a spreadsheet instead of into a cell, which is the same act reaching the same
field through a different door. So an imported label locks, and a later move keeps it (§11.73.2)
rather than re-deriving it from the new position.

**THE COUNTER-ARGUMENT IS REAL AND IS OUTWEIGHED.** A sheet exported from this product carries
labels the ALLOCATOR produced, so a round trip out and back would lock names nobody chose, and a
later move would then keep a label naming the hole the cable has left: the failure §11.73.2 exists
to prevent, arrived at from the other side. It is outweighed because **the product cannot tell the
two sheets apart and must not guess**, and because the two mistakes are not equal: a wrongly locked
label is visible in the `RACK LBL` cell, carries the pin that says a person set it, and is cleared by
emptying the box; a wrongly discarded one is gone. G4's direction of travel decides it.

**11.74.2 AND THE IMPORTER HAD NO RUNNING RACK-LABEL RESERVATION AT ALL, WHICH IS A LIVE CR-113
DEFECT AND NOT A CONSEQUENCE OF THIS RULING.** `csv_import_apply.dart` passes `usedFieldLabels(doc)`
into `alsoUsedLabels` for **every** origin field it writes. `buildSetStructureOriginProperty` reads
that parameter for the FIELD label and reads `alsoUsedRackLabels` for the rack label, and nothing
ever filled the second. Two rows of one import naming the same rack label were each checked against
one unmutated document, and both passed.

**MEASURED, NOT REASONED.** A probe written before the fix imported two drops and then re-imported
the same sheet carrying `PP1-05` on both rows: two links, one label. It is reachable only on the
**update** pass, because a drop created by an import takes no rack label from the sheet, which is
why the existing suite's round-trip cases never met it.

**11.74.3 A COLLISION IS SKIPPED, NOT REFUSED, AND THAT IS THE IMPORTER'S EXISTING CONTRACT RATHER
THAN A NEW DECISION.** `_origin` drops any result that is not `Ready`, so a rack label colliding with
one already in the document has always been silently left alone while the rest of the row applied.
The reservation makes the within-sheet case behave the same way as the against-document case, which
is the smaller change and the consistent one.

**IT IS RECORDED AS A KNOWN LIMITATION.** docs/04 §3.4 says never silently do nothing, and an import
that skips a field without saying so is doing exactly that. The import already has a `warnings`
channel and this is a candidate for it; wiring it is not this ruling's work, and pretending the
current behaviour is fine would be worse than naming it.

---

### 11.75 DR-076 · The schematic rebuilds what changed, and the epochs already say what that is

**Settled by the user on 2026-08-19** (`#702`). The issue's own description says a ruling is owed
before building, because *"which epochs invalidate which fragments"* is a design question DR-011.4
only half answers. This is that ruling. **Not a §8.3 amendment**: nothing moves between milestones,
and AC-008's remedy is refined rather than withdrawn.

**11.75.1 THE PRESCRIBED REMEDY CANNOT MEET THE BUDGET ON ITS OWN, AND THE NUMBERS ARE WHY THIS
RULING EXISTS.** AC-008 rules that L3a splits into eight per-domain sub-pictures so *"an edit to one
HDMI run rebuilds ~1,200 ops and seven pictures replay untouched"*. Measured on the 12-pod fixture,
3,600 links across 1,128 devices, warm:

| | time | ops |
|---|---|---|
| whole build | **144 ms** | 78,660 |
| every symbol position held | 94 ms | |
| **symbols alone, zero links** | **75 ms** | **49,860** |

**The symbol half is 52% of the build before a single cable exists, and it is domain-independent.** A
perfect eight-way domain split saves at best the seven-eighths of the link half that did not change,
about 60 ms, and lands at ~84 ms against a 16.7 ms frame. AC-008 is not wrong; it is **half the
answer**, and the half it names is the smaller one.

**11.75.2 THE INVALIDATION MODEL IS THE EPOCH MODEL THAT ALREADY EXISTS.** `DocEpochs` carries six
independent notifiers (`structure`, `wires`, `rack`, `meta`, `style`, `sheet`) and its own doc says
they exist so `rackmate_ui` *"can subscribe to exactly the epochs one widget cares about instead of
rebuilding on every commit"*. Every command declares its `touches` mask, and `MoveEndpointCommand`,
`ConnectPortsCommand` and `BindEndpointCommand` all declare `wires | meta`. **The schematic collapses
all six into one `_sceneEpoch` and rebuilds everything.** The matrix this ruling asks for is
therefore mostly written already, per command, and unread.

The scene splits in three tiers, each keyed on what can move it:

| Tier | Rebuilt when | Cost at 3,600 links |
|---|---|---|
| **Layout** — Sugiyama phases 0–3, symbol positions | `structure` | ~50 ms |
| **Symbols** — the symbol layer's ops and text | `structure`, `meta` | ~75 ms |
| **Wires and labels** — net-label pennants, drawn wires | `wires` | ~19 ms |

A cable drawn declares `wires | meta`. Under §11.75.3 that rebuilds the symbol tier and the wire
tier and **reuses the layout**, which is DR-011.4's clause restated as a cache key rather than as a
parameter: *"committing a link must not re-lay-out the sheet"* is already the rule, and freezing the
layout is how it stops being re-derived.

**MEASURED WHILE BUILDING §11.75.2, AND IT CHANGES WHAT THIS RULING IS FOR.** Adding **one** cable to
the shipped fixture and rebuilding the scene from scratch moves **88 of its 91 symbols**. The new
edge changes what Sugiyama's ordering sweep sees, and the two label measurements feeding its params
change with it, so the whole sheet reshuffles under the cursor of the person who just drew a wire.
Holding the layout moves none.

So the tier model is not only a performance remedy: **it is how DR-011.4's "committing a link must
not re-lay-out the sheet" is actually kept.** A scene cache that missed and rebuilt honestly would be
correct by this ruling's timing argument and wrong by that one. The equality gate in §11.75.5 is
therefore against the SAME document, never against a fresh layout of a changed one, and a test
asserting the latter would be asserting the churn as intended behaviour.

**11.75.3 A RENAME REBUILDS SYMBOLS AND NOT LAYOUT.** A designator changes what a symbol PRINTS and
not where anything sits. Re-running layout for one would move symbols under the person's cursor,
which is the failure DR-011.4 forbids for its own reason and which is worse during trim-out, when
renames arrive in bursts. Paying the symbol tier for a rename is accepted: it is 75 ms on an
infrequent act, against 144 ms today.

**NOT DEFERRING THE REDRAW WAS CONSIDERED AND REFUSED.** A stale designator on the sheet while the
schedule shows the new one is two documents disagreeing about a device's name, which is the class of
defect this product exists to prevent.

**11.75.4 THE ONE-FRAME BUDGET BINDS THE EDIT, NOT THE OPEN.** M2's criterion was written against a
house with one rack and states one frame; a cold build of a twelve-pod commercial job is ~144 ms and
happens **once, behind a file load the person is already waiting through**. So the incremental path
asserts `_oneFrameMs` and the cold build keeps a ratchet ceiling.

This is a narrowing of what the budget was assumed to cover, and it is stated rather than assumed
because the alternative is real work with a real cost: meeting one frame on a cold build means
attacking Sugiyama and the symbol layer themselves, inside the determinism guarantees
`sugiyama.dart`'s header defends. **No user has reported open time.** If one does, this clause is
where to argue with.

**11.75.5 DETERMINISM IS NOT NEGOTIABLE AND IS WHAT THE TESTS PIN.** CR-012 and `sugiyama.dart`'s
rules survive unchanged: no hash-container iteration, total orders, and the same document producing
the same display list. **An incremental rebuild must produce the byte-identical scene a whole rebuild
would**, and that equality is the gate, not the timing. A cache that is faster and different is a
defect this project would ship as a golden diff nobody could read.

**11.75.6 AC-008'S DOMAIN SPLIT IS RETAINED AND RESEQUENCED.** It is measured after the tiers land,
not before: if the wire tier is already inside one frame, eight sub-pictures buy nothing and add a
second invalidation axis to reason about. The clause stays true and stops being the first move.

---

## 12. Superseded rulings

Every ruling in Parts 1–3 that DR-001…DR-036 change or void, plus the small set of internal
contradictions the amendment sweep exposed and which are ruled here so the record does not
contradict itself. **A ruling not listed below stands exactly as written in Parts 1–3.**

Each entry gives the ID, what it said, and what now governs.

### 12.1 Superseded by DR-001 (net labels by default)

| Ruling | What it said | What now governs |
|---|---|---|
| **CR-013** | "Sugiyama layering + interval-graph channel routing, full deterministic recompute", with phase 5 (crossing sweep, hop arcs) moved to paint time. | **Superseded in part.** v1 builds **Sugiyama phases 0–3 only** (cycle-break, layer, barycentre sweep, coordinate assignment) which place symbols. Phase 4 (interval-graph channel routing) moves to **v1.2**, gated on evidence that filtered density warrants it. Phase 5 (crossing sweep + hops) is **not built**. `drawn` mode uses a deterministic layer-ordered orthogonal staircase per Link with no channel allocation. Everything CR-013 *deleted* stays deleted: `ObstacleField`, `RouteCache` and "obstacle-aware" remain banned names, the v1 router is not obstacle-aware either, it is simpler still. The interval-graph insight remains the right answer *if* #4 is ever built; it is not wrong, it is not yet needed. |
| **AC-016 #17** | Dash phase diverges across hop arcs; document it in the visual language; suppress hops on control and structure. | **Moot in v1.** No arcs are drawn, so no arc dash-phase divergence exists and there are no hops to suppress. The finding is retained as a v1.2 note attached to CR-013 phase 4. **The other half survives:** `dashPath` is still on the hot path for straight dashed segments and is still explicitly profiled in the perf harness rather than assumed cheap. |
| **AC-016 #20** | "sub-millisecond at N=300" ignores that crossings are unbounded by N; move the Bentley–Ottmann sweep and hop generation to paint time, viewport-scoped; cap hops to `gap` above a threshold; measure X on a real 300-connection fixture. | **Moot in v1.** No sweep, no hops, no cap, no X. **The 300-connection fixture survives** and changes purpose: it is now the layout-determinism and **label-density** fixture, and the thing measured on it is text-run count and commit time for the label layer, not crossings. |
| **AC-040**, density-table half | Kept `design-ux-schematic.md §1.5`'s automatic degradation to net labels above a per-sheet threshold. | **Inverted.** There is no degradation and no threshold, because labels are the base state. The **rule-catalogue half of AC-040 is untouched** and still governs, see §12.6 for its arithmetic. |
| **§7.2.3**, wiring scope table | "Domain filter bar, **auto net-label degradation**, symbol collapse to vector pins, `Alt`-hover transient focus". | The domain filter bar, symbol collapse and `Alt`-hover **stay and are load-bearing**. "Auto net-label degradation" is replaced by **"net labels as the default render; drawn wires on domain filter, hover or focus (DR-001 §11.1.1)"**. |
| **§7.2.3**, router row | "Schematic canvas: Sugiyama phases 0–4 + interval-graph channel routing, full deterministic recompute; phase 5 (crossing sweep, hops) at paint time, viewport-scoped." | **Superseded.** v1 builds **Sugiyama phases 0–3 only**, placing symbols, plus a deterministic layer-ordered orthogonal staircase per Link with no channel allocation. Phase 4 (interval-graph channel routing) is **v1.2**, gated on evidence. Phase 5 (crossing sweep, hop arcs) is **not built**. Nothing runs at paint time. This row is the same ruling as the CR-013 row above it, restated in the scope table; it was missed in the first pass and is listed here because §12's preamble makes an unlisted row read as still-binding v1 scope, the exact work DR-001 removed. The identical restatement appears at **§5.7 (3886-3889)**, **§9.3 M2 (4878)**, **§2.5 (2666)** and the banned-names table **§4.x (3323)**; all four are superseded by this row and each carries the §12.8 pointer. |
| **§9.3 (M2)** | Sized `L`; contents included phases 0–4, channel routing and phase 5. | **M2 is `M` (4–7 weeks)**, contents per §11.1.3. M1 becomes the only `L`. New cumulative plan in §12.7. |
| **§9.11** "The honest total" | Sized M2 as `L` and totalled "41–69 weeks; 12–18 months", against a table whose own final cumulative row reads 45–69. | **Superseded by §12.7.** M2 is **`M` (4–7 weeks)**; the plan totals **42–65 weeks, 11–17 months**; M1 is the only `L` and the sole long pole. The "41–69" prose figure was additionally an arithmetic error against §9.11's own table (45–69) and should not be quoted even as the historical number. **Lever 2** ("move M4 after M6") is **withdrawn by DR-003**; levers 1 (ship M1 as a public v0.9) and 3 (cut the catalog to 40 archetypes at full fidelity) survive. §9.11's lever 1 also mis-states M1 as "10–15 weeks of invisible work", 10–15 is M1's *cumulative* position; its *duration* is 8–12, and claims shipping M1 "would resolve half of §10", which Part 4 has since resolved directly (see §13). |
| **§10.1** recommendation | "(A) draw every wire as the default, with (B) as an automatic degradation." | **Void.** DR-001. Not to be re-argued. |

> **Two rows above state a total and a "sole long pole" that DR-001 made true and a later ruling
> moved.** They are DR-001's record and keep its words. **The live figures are §12.7's: M4 is `L`,
> 7–9 weeks, the plan totals 44–67 weeks / 11–18 months, and M1 and M4 are both `L`.** M4's row was
> re-derived on 2026-08-02 at that milestone's decomposition, because DR-015 put the device-library
> subsystem on its checklist and the earlier `M`/5–7 predated it (docs/12 §5.3).

**Explicitly NOT superseded: listed here because they will otherwise be cut by association:**

| Ruling | Status under DR-001 |
|---|---|
| **CR-012** | **Unaffected.** No route geometry is persisted, in either idiom. Symbol placement is persisted; wire geometry is not. `RouteWaypoint`, `waypointsBySheet` and `routeOverrides` remain banned names. |
| **RJ-001** | **Unaffected and reaffirmed.** The editable schematic canvas and its layout engine survive. Drag-to-connect, magnetic type-weighted snap, chain-draw, multi-draw, pinning on manual move and `Tidy sheet` all ship in v1. DR-001 changes how a Link is *rendered*, not whether the canvas exists or how a Link is *made*. |
| **RJ-002** | **Unaffected and reaffirmed.** The Schematic remains a separate view and remains the only place connections are created in v1 (CR-105). Wiring is not moved onto the rack elevation. |
| **CR-068, CR-069** | **Unaffected.** `SheetItem.position` is the one symbol position; any manual move sets `pinned`. |
| **CR-078, CR-079, CR-082, AC-054, PAL-1/2/3** | **Unaffected.** The palette applies to drawn wires, tag pills, net-label leaders, the `T0.01` legend and the schedule's `TYPE` chip. Requirement 4 and its acceptance test are untouched by DR-001. |
| **CR-049** | **Unaffected in mechanism, raised in importance.** Net names stay generated, editable and never load-bearing for membership (`Service.netId` is membership). The name is now the primary on-screen identity of a connection, so its generation rule is a legibility decision. |
| **CR-105, AC-035** | **Unaffected.** The Schedule is still present from an empty project and still populates live. |

### 12.2 Superseded by DR-002 (residential primary)

No ruling is superseded. DR-002 **confirms** CR-066 (`simple` default), CR-108 (grades as a tag),
AC-027 (`CODE-001`/`CODE-002` in v1), AC-031 (18 field devices) and AC-034/m23, and converts each
from an implicit bet into a stated constraint. §10.12(d) is settled by implication: **three
residential starter projects and one small commercial**.

### 12.3 Superseded by DR-003 (device builder in v1)

No ruling in Parts 1–3 is superseded, DR-003 confirms confirmed product decision 2 and §10.4's
recommendation. One derived item is withdrawn:

| Item | Status |
|---|---|
| **09-roadmap §6, lever 2: "Move M4 after M6"** | **Withdrawn.** No longer an available schedule lever. The lever list is two, not three. |
| **Measure 7 (catalog miss rate)** | **Retained, repurposed.** No longer resolves an open question; it is catalog-coverage evidence feeding §10.9 and lever 3's sizing. |

### 12.4 Superseded by DR-004 (multi-sheet never)

| Ruling | What it said | What now governs |
|---|---|---|
| **§7.4**, v1.2 table, row 1 | "**Multi-sheet**, partitioned by domain only … Ships when real projects show which partition users want." | **Deleted from v1.2.** The row moves to **§7.6 Not doing**, with DR-004 as its ruling. There is no gate and no evidence that reopens it. |
| **§7.7**, cut #1 | "Multi-sheet, off-sheet connectors, zone grids, cross-refs, min-cut, unit splitting, v1.2 / v2, 4–6 weeks." | The cut is **permanent**, not deferred. Two corrections to the row itself: **"zone grids" was never cut** (CR-073 keeps the zone grid, and DR-005 confirms it as a v1 deliverable), and unit splitting's v2 home becomes **never**. |
| **CR-070** | Unit splitting is v2, "only if multi-sheet lands and users demonstrably need it". | Its condition can never be met. **Unit splitting moves to §7.6 Not doing.** Symbol collapse covers the ground it was for. |
| **AC-010** | Multi-sheet is a v2 stack sitting on the critical path to the first PDF; cut it. | **Reinforced and made permanent.** The finding was right and is now unconditional. |
| **§10.7** recommendation | "(a) hold at v1.2, and re-decide immediately after 10.1 resolves." | **Void.** 10.1 resolved to net labels; the re-decision is DR-004 = (c) never. |

**Explicitly NOT superseded:**

| Ruling | Status under DR-004 |
|---|---|
| **AC-037** | **Unaffected and load-bearing.** The `Sheet` entity ships in the model and the format, holding exactly one schematic sheet. It is not vestigial. If DR-004 is ever reversed, the format does not migrate. |
| **CR-073**, exporter half | **Unaffected and still correct.** The exporter emits N domain sheets `T6.01…` from the one schematic `Sheet`. Partition at export is not multi-sheet authoring, §11.4.3. |
| **CR-075** | **Unaffected.** One field, `SheetKind kind`, 11 values, plus `exceptions`. |
| **CR-066, CR-067** | **Unaffected.** `Sheet.domainFilter` and `Sheet.lifecycleFilter` are the filter state DR-001 makes load-bearing. |

### 12.5 Superseded by DR-005 (client deliverable)

| Ruling | What it said | What now governs |
|---|---|---|
| **§10.6** recommendation | "(b) internal-first, with the title block and revision block present … but **no further investment in drafting ceremony until a user asks**." | **Void.** DR-005 = (a). Full sheet furniture ships in v1: title block, revision block, **revision clouds**, IFC stamp, drawing border, zone references, sheet numbering, `T0.00` cover and drawing index. |
| **Revision clouds = v1.1** (export document, As-built preset) | "Revision **clouds** are v1.1." | **v1.** A cloud primitive on `DiagramCanvas`, driven from `RevisionEntry`, with a revision triangle carrying the revision letter. |
| **§9.7 (M6)** | Sized `M`, mid-band. | Still `M`, at the **top** of its band (+0.5–1 week) for revision clouds. Sheet furniture is not available as a schedule lever. |
| **§10.6**'s inference that (a) "argues for (A) in 10.1" | — | **Explicitly rejected.** §11.5.1. Drafting polish is sheet furniture; wire idiom is DR-001. They are orthogonal axes and this decision does not reopen that one. |

**Explicitly NOT superseded:** **CR-022 / G3**: the IFC stamp is gated on zero open errors and
**never gates bytes**; `blockExportOnErrors` stays deleted. **G1**: the schedule is still the
deliverable and the drawing is still the receipt. **RJ-015** (no PDF/UA) and **RJ-017** (no
branding in v1) stand.

### 12.6 Corrections ruled here so the record is self-consistent

These are not consequences of DR-001…DR-006. They are internal contradictions inside Parts 1–3
that the amendment sweep surfaced, and they are ruled here because leaving them would produce
exactly the contradiction §12 exists to prevent.

| # | Ruling | The contradiction | What now governs |
|---|---|---|---|
| a | **CR-071 vs §7.3 vs §7.7 cut #9** | CR-071 point 2 rules the rear panel **prints in v1** as sheet `T2.02`; §4.3 agrees ("the rear elevation still *prints* in v1"); §7.2.7 lists rear elevation in the v1 export set; but §7.3's v1.1 table says "the rear-panel view **as a printable sheet**" and §7.7 cut #9 repeats it. | **CR-071 governs, unambiguously.** Sheet **`T2.02 Rack Elevation — Rear` prints in v1**, with connector fields and landing cable IDs. What is **v1.1** is the **interactive Rear Panel view** (`Ctrl+3`), leaders, tag pills, per-connector navigation, egress heat map. §7.3's row and §7.7 cut #9 are corrected to say "the interactive Rear Panel view". The Part 3 preamble's "Part 3 governs the release bucket" rule does not apply here, because Part 3 contradicts *itself* (§7.2.7 vs §7.3) and CR-071 is the only source that is internally consistent. |
| b | **AC-040 / §5.8 / §7.2.6 rule count** | All three state "v1 ships **22** rules". AC-040's own enumeration lists **24** IDs (`TOP-001..005`, `SIG-001`, `SIG-002`, `DIR-001`, `DIR-003`, `CON-001`, `ELE-003`, `ELE-006`, `NET-001`, `PWR-001`, `PWR-003`, `LEN-001`, `RCK-001`, `RCK-002`, `RCK-003`, `RCK-012`, `RCK-013`, `CODE-001`, `CODE-002`, `LNK-020`). CR-017 additionally names three placement-coherence conditions and assigns them no IDs. | **The enumeration governs; the count "22" is an arithmetic error.** `PLC-001`, `PLC-002` and `PLC-003` are **RATIFIED** as distinct tier-1 rules, CR-017 already rules the conditions model-illegal, CR-021 says a rule not in the catalogue does not exist, and an unnumbered blocking rule can carry neither a `Finding.ruleId` nor an AC-051 fixture pair. **The v1 catalogue is 27 rules: 8 tier-1 + 6 tier-2 + 13 tier-3.** Every occurrence of "22 rules" in every document becomes **27**. AC-051's gate is unchanged and now applies to 27 pairs. |
| c | **§6.2.2 PAL-1** | PAL-1 is stated and verified over the **eight domain base values**, while §6.4 assigns per-family `dashOverride` and weight overrides that PAL-1 never re-checks. Two shipped families collide on every non-hue channel: `audio.spdif_optical` (TOSLINK, dash `2,3`, 1.00×, domain L 0.2215) and `ctl.ir_emitter` (IR, dash `1.5,3`, 0.75×, domain L 0.2930), ΔL 0.0715 inside the 0.10 band, same fine-dot dash class, weight ratio 1.33 below the 1.4 floor. Two of requirement 4's ten named types are indistinguishable in greyscale. A second pair, `structure.pathway` (`2,6`, 0.75×, L 0.3185) vs `ctl.ir_emitter` (ΔL 0.0255), fails identically. Enumerating the 385 in-band family pairs, rather than the eight domain rows, subsequently found **fourteen** collisions in all, six involving brief-named types. | **PAL-1 is restated over rendered family values and made pairwise and disjunctive; eight families are re-spaced.** Full statement, the dash-class definition, and the corrected registry rows are in **§14**. The authority is the executable check **`tools/pal1_check.py`**, and where a document disagrees with it the file wins. |
| d | **§7.7 cut #1** | Lists "zone grids" as cut, while CR-073 explicitly keeps the zone grid and the schedule's `REF` column depends on it. | **The zone grid ships in v1.** DR-005 confirms it. Cut #1's row drops "zone grids". |

### 12.7 The plan, re-costed

DR-001 removes 4–5 weeks from M2; DR-005 adds 0.5–1 week to M6; **DR-015 adds 2 weeks to M4**.

| Milestone | Size | Weeks | Cumulative |
|---|---|---|---|
| M0 Foundations | `S` | 2–3 | 2–3 |
| M1 Elevation release | **`L`** | 8–12 | 10–15 |
| M2 Wiring and the live schedule | **`M`** *(was `L`)* | 4–7 | 14–22 |
| M3 Structure and the field | `M` | 4–7 | 18–29 |
| M4 Device builder | **`L`** *(was `M`)* | **7–9** *(was 5–7)* | 25–38 |
| M5 Validation | `M` | 4–6 | 29–44 |
| **The Plan view** *(DR-029)* | **`L`** | **9–13** | 38–57 |
| M6 Full sheet set | `M` | 5–7 | 43–64 |
| M7 Platform and access | `M` | 4–6 | 47–70 |
| M8 Release engineering | `S` | 2–3 | 49–73 |
| M9 Beta hardening | `M` | 4–7 | 53–80 |

**53–80 weeks of implementation; 13–21 months to a shipped v1** for one experienced engineer.
**M1, M4 and the Plan view are the three `L` items.**

> **The Plan view row is DR-029, added 2026-08-09**, and it is the first amendment that makes v1
> LARGER. It is an epic rather than a milestone number, so it carries no `Mn` and renumbers
> nothing; it is placed between M5 and M6 because the ruling constrains only that it finish
> **before M6**, which is the one ordering that does not make M6's *"all four starter projects
> export a complete set"* run twice over a set about to gain a plan sheet. The weeks are
> DR-018 §11.17.6's own costing at the PDF-rasterisation level. **The month figures carry
> §12.7's existing weeks-to-months scaling forward rather than re-deriving it**; the weeks are
> the auditable number and the months were never a clean division.

> **M4's row moved on 2026-08-02, at that milestone's decomposition and not before.** DR-015 put the
> device-library subsystem onto M4's checklist — the library directory service, the `.rmda` codec and
> its import/export, template provenance, the palette filter, the library browser, and parameterising
> the Windows file dialog — and the `M`/5–7 predated all of it. The re-derivation was deferred to
> decomposition deliberately, because that is the first moment there are tasks to count against
> (roadmap §8.1; #71). **The bottom-up sum over M4's 17 issues came to ~10–15 weeks; only the ~2 weeks
> DR-015 accounts for are adopted here**, since re-pricing the base needs velocity evidence that does
> not exist yet. The gap is recorded in docs/12 §5.3 rather than absorbed silently, because a schedule
> that quietly grows is the one nobody can audit. This supersedes the "sole long pole" reading above
> for M4 only; every other row is unchanged. Two schedule levers remain (ship M1 as a
public v0.9; cut the catalog to 40 archetypes at full fidelity); lever 2 is withdrawn by DR-003.

### 12.8 Part 1–3 sites carrying a supersession pointer

Parts 1–3 are not rewritten (see the Part 4 preamble). These sites state rulings that §11–§14
supersede, and each carries the pointer below, inserted verbatim at the stated position. The
pointer does not restate the new ruling; it names where the new ruling lives.

| # | Site | Insert at | Pointer text (verbatim) |
|---|---|---|---|
| 1 | §2.5, router restatement | at the end of RJ-001, before the RJ-002 heading | `> **Superseded — see §12.1 (§7.2.3 router row).** Phases 0–3 only; no channel routing, no phase 5.` |
| 2 | §4.x banned-names table, router column | after the banned-names table | `> **Superseded in part — see §12.1 (§7.2.3 router row).** The banned names in the left column stand (§12.1, CR-013 row); the replacement named in the right column is now Sugiyama phases 0–3 plus a deterministic orthogonal staircase.` |
| 3 | §5.7, router prose | after the route-geometry paragraph | `> **Third sentence superseded — see §12.1 (§7.2.3 router row).** The router is Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal staircase; there is no channel routing, no crossing sweep, no hop arcs and no paint-time phase. The first two sentences (CR-012 — route geometry never persisted, symbol placement persisted) are **unaffected and still binding** (§12.1, CR-012 row).` |
| 4 | §6.2.2, PAL-1 statement | after the PAL-1 blockquote | `> **Superseded — see §14.1; ruled at §12.6(c).** The conjunctive domain-level form stated above is not PAL-1. The binding form is **pairwise over rendered family values** and **disjunctive** (dash class differs **or** weight ratio ≥ 1.4). Stated over eight domain rows it is unsatisfiable by the shipped palette, and reading those eight rows instead of the family pairs actually drawn is what allowed collisions to ship undetected three times. The authority is the executable check **`tools/pal1_check.py`** — not this statement, and not the table below.` |
| 5 | §6.2.5, `str` row | after the domain table | ``> **The `str` base dash `4,4` is superseded: see §14.3.** It is **`6,3,3,3`**, class `(short,short)`, period 15 pt, and the row above is corrected in place. The §6.4 rows for `audio.spdif_optical`, `structure.pathway`, `structure.undetermined`, `video.hdmi.1_4`, `video.composite`, `audio.line_bal`, `audio.spdif_coax` and `audio.aes3` are likewise superseded by §14.3. Every effective value in this section is checked by `tools/pal1_check.py`.`` |
| 6 | §6.7, criterion 4 | indented inside criterion 4, before criterion 5 | `> **Superseded — see §14.1 and §14.5.** PAL-1 is a **pairwise** test over **rendered family values**, not the eight domain colours, and its two limbs are **disjunctive** (dash class differs **or** weight ratio ≥ 1.4), not conjunctive. The conjunctive domain-level form stated here is unsatisfiable by the shipped palette and is what allowed fourteen collisions to ship. The authority is `tools/pal1_check.py`.` |
| 7 | §7.2.3, wiring scope table | after the table | `> **The router row is superseded — see §12.1.** v1 builds Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal staircase. Phase 4 is v1.2; phase 5 is not built. The remaining rows of this table stand, as amended by the §7.2.3 row already listed in §12.1.` |
| 8 | §9.3, M2 contents | after the contents paragraph | ``> **Superseded: see §12.1 (§7.2.3 router row) and §11.1.3.** M2's router is phases 0–3 plus the orthogonal staircase, and M2 is sized `M` (4–7 weeks), see §12.7.`` |
| 9 | §9.11, "The honest total" | under the heading, above the milestone table | ``> **Superseded: see §12.7.** M2 is `M` (4–7 weeks); the plan totals **42–65 weeks, 11–17 months**. The "41–69" figure below is additionally an arithmetic error against this section's own table, whose final cumulative row reads 45–69. Lever 2 is withdrawn by DR-003.`` |
| 10 | §10 preamble | after the first preamble paragraph | `> **Six of these thirteen are now ANSWERED — see §13.** 10.1 (DR-001), 10.2 (DR-002), 10.4 (DR-003), 10.6 (DR-005) and 10.7 (DR-004) are settled by the user's decisions in §11 and are **binding**, not open; 10.3 is **moot** under DR-006, which rules that no commercial release is planned. The text below is retained as the record of the argument, per the Part 4 preamble.` |
| 11 | §10.13 | after the heading | `> **Retired — see §13.** All three questions this section prioritises (10.1, 10.2, 10.4) are answered by DR-001, DR-002 and DR-003. Do not sequence work from this section.` |
| 12 | AC-058, the **D10** row | after the gap table | `> **The D10 row's procurement schedule is superseded — see §12.9 and §11.6.** RackMate is an internal tool; signing is self-signed with a timestamp, Microsoft Trusted Signing is the named fallback at M8, and no OV/EV certificate is procured at any milestone. The rest of D10 — macOS notarisation, vendored pdfium (CR-100), the release pipeline with symbol archival — is **unaffected and still binding**.` |
| 13 | RJ-014, the certificate sentence | after the RJ-014 body | `> **The certificate half is superseded — see §12.9 and §11.6.** There is no OV/EV validation and no reputation build, so nothing here needs scheduling two milestones ahead. RJ-014's actual ruling — no in-app auto-update in v1, a signed installer plus a version-check ping — is **reaffirmed**, and the `.rmdev` migration-chain half (AC-050/A8.2) is untouched.` |
| 14 | §7.2.8, the code-signing row | after the table | `> **The code-signing row is superseded — see §12.9 and §11.6.** Read it as: Windows code signing **self-signed with a timestamp server**, no certificate procured early, Microsoft Trusted Signing as the named fallback at M8. Vendored pdfium and the release pipeline with symbol archival are **unchanged**.` |
| 15 | §9.7, M6 exit criterion | after the exit paragraph | `> **The last sentence is superseded — see §12.9 and §11.6.** "Windows OV/EV certificate procurement starts here" is **deleted**. Every other clause of M6's exit criterion stands exactly as written.` |
| 16 | §9.9, M8 exit criterion | after the exit paragraph | `> **The SmartScreen clause is superseded — see §11.6.2.** It splits into a build-side gate (signed, timestamped, valid publisher, **and the signature still validates after the certificate has expired**) and a distribution-side requirement that is documented rather than gated (Local Intranet UNC or Intune/GPO so Mark-of-the-Web is never applied; the ZIP trap stated explicitly). The other three clauses stand as written.` |
| 17 | §10.3 recommendation | after the recommendation paragraph | `> **Moot — see §13 and §11.6, consequence 12.** DR-006 rules that no commercial release is planned, so there is nothing to price. This section is retained in full as the record of the argument: if DR-006 is ever reversed, §10.3 reopens exactly as written, watermark hazard included.` |
| 18 | §7.6, cable-dressing row | after the table | `> **Superseded in part — see §12.11 (DR-018).** **Floor plans leave the cable-dressing row** and are v1.1, conditionally: v1.2 unless the underlay carrier ships in v1 (roadmap §2.2's additive membership criterion). Cable dressing, 3D and thermal simulation are unaffected and stay out. The row's rationale had only ever argued cable dressing.` |

---

### 12.9 Superseded by DR-006 (internal tool, self-signed distribution)

**A numbering note, stated so nobody renumbers.** This subsection is §12.9 and not §12.6, even
though it breaks the DR-order of §12.1…§12.5, because **§12.6(a)–(d) are cited by those exact
sub-letters** across this record and the authored documents (§12.6(b) sets the 27-rule count,
§12.6(c) is PAL-1's ruling, §12.6(d) is the zone grid). Renumbering to keep the DR-order tidy would
silently break every one of those citations, which is a worse outcome than an out-of-order heading.

| Ruling | What it said | What now governs |
|---|---|---|
| **AC-058 (D10)**, procurement half | "Windows OV/EV certificate procurement **starts two milestones before release** because reputation-building takes weeks." | **Superseded in part.** No OV/EV certificate is procured, at M6 or anywhere. Signing is **self-signed** (`New-SelfSignedCertificate`, `Set-AuthenticodeSignature` **with a timestamp server**, public `.cer` to `LocalMachine\Root` and `\TrustedPublisher`, ideally by GPO) with **Microsoft Trusted Signing as the named fallback**, adoptable at M8. The lead time D10 was defending against is specific to OV/EV identity verification, the SmartScreen reputation ramp and hardware-token logistics; §11.6.1 shows none of the three attaches to either path DR-006 names. **The rest of D10 stands**: macOS notarisation and stapling, vendored pdfium (CR-100), release pipeline with symbol archival. |
| **§9.7 (M6)** exit criterion, last sentence | "Windows OV/EV certificate procurement starts here, two milestones before release." | **Deleted.** M6 has no distribution obligation of any kind. Every other clause of M6's exit criterion, the complete sheet set on all four starters, the deuteranopia/protanopia and greyscale verification, the ANSI B / ANSI D / photocopy sign-off (AC-058 D13), requirement 7, is **unchanged**. |
| **§9.9 (M8)** exit criterion, first clause | "A signed installer runs on a clean Windows 11 machine **with no SmartScreen warning**." | **Split: §11.6.2.** No build-side property can deliver "no SmartScreen warning": SmartScreen evaluates **Mark-of-the-Web**, which is a property of how a file arrived, not of the binary. The **build-side gate** is: signed, timestamped, valid publisher in file properties, **and the signature still validates after the signing certificate has expired**. The **distribution-side requirement** is documented and not gated: Local Intranet UNC or Intune/GPO, and the ZIP trap stated explicitly. M8's other three clauses (cold start within budget, an induced crash producing a report with no project content, documented limits behaving as documented) are **unchanged**. |
| **§7.2.8**, code-signing row | "Windows code signing with certificate procurement started **two milestones early**; vendored pdfium; release pipeline with symbol archival." | **The procurement clause is superseded**; read the row as self-signed with a timestamp, no early procurement, Trusted Signing as the named fallback. **Vendored pdfium and the release pipeline are unaffected.** |
| **`RISK-07`** (roadmap §7) | "Code-signing certificate lead time blocks a finished build … prefer EV to avoid the SmartScreen reputation ramp." | **Retired in this form.** Replaced by a smaller, wholly internal risk: the public `.cer` is not deployed to the target machine's stores. Likelihood low, impact minor, early warning "a clean test machine shows *Unknown publisher*", mitigation a GPO. |
| **`RISK-08`** (roadmap §7) | "Beta integrators cannot be recruited in time for M9." | **Population changes; the risk does not disappear.** Three integrators become three internal users on three real jobs. **M9's exit criterion is unchanged** and is still a judgement, not a metric. |
| **RJ-014**, certificate sentence | "The part that genuinely cannot wait (the code-signing certificate, whose OV/EV validation and reputation build take weeks) is accepted and scheduled two milestones ahead of release (AC-058/D10)." | **Superseded in that sentence only.** Nothing needs scheduling ahead. RJ-014's ruling (**no in-app auto-update in v1**, a signed installer plus a "Check for updates" item and a version string) is **reaffirmed**, and the `.rmdev` user-library migration half (AC-050/A8.2) is untouched. |
| **§10.3** | Pricing and licensing model; recommendation (c), a free tier with a watermarked PDF. | **Moot while DR-006 stands**: there is nothing to price. Retained in full as the record of the argument. **If DR-006 is reversed, §10.3 reopens exactly as written**, watermark hazard included. Indexed at §13. |
**Derived documents that now state a superseded ruling.** These are priority-3 documents
(Part 4 preamble), not Parts 1–3, so they are **edited rather than pointered**, and the edits are
**owed, not yet made**. Each is listed here so the debt is visible rather than discovered. **This
table is the whole list; a site not on it is a defect in this table, not an exemption.**

*Signing and distribution, the sites DR-006's ruling reaches directly:*

| Document | Site | What it must become |
|---|---|---|
| `docs/11-testing-and-quality.md` §11 | Row 1, "Windows OV/EV certificate procurement, **starts at M6**" | Self-signed with a timestamp; no early procurement; Trusted Signing named as the M8 fallback |
| `docs/11-testing-and-quality.md` §11 | Row 2, "Exit criterion: a signed installer runs … with **no SmartScreen warning**" | The split criterion of §11.6.2 |
| `docs/09-roadmap.md` §4 | M6 exit criterion, last sentence | The sentence is deleted |
| `docs/09-roadmap.md` §4 | M8 exit criterion, first clause; and M8 *Risks* ("This is a purchasing decision, made at M6") | The split criterion of §11.6.2; the purchasing decision no longer exists |
| `docs/09-roadmap.md` §7 | `RISK-07` row | Retired in its stated form and replaced per consequence 7 |
| `docs/09-roadmap.md` §7 | `RISK-08` row, mitigation column | Population is internal; the criterion is unchanged |

*Decision counts and the §10.3 schedule, the sites DR-006 falsifies **arithmetically**, which is
why a debt list built around signing missed them on first pass:*

| Document | Site | What it now says | What it must become |
|---|---|---|---|
| `docs/09-roadmap.md` §8 | Item 7, at **:498** | "**Five are now answered, `DR-001` through `DR-005`**", and "pricing (§10.3) wants deciding before M6" | **Six** are settled, five answered, §10.3 **moot** (§11.6.3/12, §13). Pricing needs deciding neither before M6 nor at all while DR-006 stands. The macOS (§10.10) half of the sentence is unaffected |
| `docs/10-decisions.md` | **:6** | "…and Part 4's binding user decisions `DR-001`–`DR-005`" | `DR-001`–`DR-006` |
| `docs/10-decisions.md` | **:11**, and the DR table headed at **:37** with rows **:42-46** | "**the five user decisions `DR-001`–`DR-005`**", over a five-row table with no DR-006 row | Six decisions; a `DR-006` row reading *internal tool, self-signed distribution*, answering *nothing in §10, moots §10.3*, with effect *no certificate procurement at any milestone; M8's criterion splits* |
| `docs/00-overview.md` §11 | **:216** | "…and the binding user decisions `DR-001`–`DR-005`" | `DR-001`–`DR-006` |

Until those edits land, **`docs/12-milestone-board.md` is the index that records the gap**: its
M6 and M8 entries quote the roadmap verbatim and then state the DR-006 amendment beneath, which is
the same pattern §12.8 uses inside this record, and its §4.11 carries both tables above.

**Explicitly NOT superseded: listed here because they will otherwise be cut by association:**

| Ruling | Status under DR-006 |
|---|---|
| **DR-005** | **Unaffected, and the confusion is foreseeable enough to name.** DR-005 is about **the sheet set**; DR-006 is about **the software**. An internal tool used by an integrator still emits sheets handed to a client, a GC and a job site. Full sheet furniture stays a v1 deliverable and stays unavailable as a schedule lever (§11.5.2/2). |
| **CR-100** | **Unaffected.** pdfium is still vendored. A network-fetched binary in a signed release is a supply-chain and reproducibility problem whether the release is sold or not. |
| **AC-058/D7** | **Shrinks, does not vanish.** SIL OFL 1.1 and every bundled licence still register via `LicenseRegistry` and stay reachable from `showLicensePage`, that follows from redistributing the fonts, not from selling the software. The commercial EULA and licence-enforcement machinery go. |
| **CR-096, AC-058/D14, the M8 crash-report clause** | **Unaffected.** Local-first, opt-in remote, no project content in a report, recovery files never attached automatically. An internal user's project data is still a client's project data. |
| **AC-056** | **Unaffected.** Mobile/tablet read-only on three named surfaces is a product decision, not a distribution one. |
| **Confirmed product decision 4** | **Unaffected.** All seven brief requirements remain in v1. DR-006 removes a purchase, not a requirement. |

### 12.10 DR-007 supersedes nothing (keystone strap geometry into M3)

**No entry, and the absence is the record.** DR-007 is the first ruling in Part 4 that voids no
Part 1–3 ruling. It is an **addition** to v1 scope made under roadmap §8.3, not a reversal, so a
reader looking for its supersession list is not missing one.

It **extends** two rulings without changing either. `Outlet` remains "ONE WALL PLATE / ONE CEILING
LOCATION" (**CR-016**) and gains an ordered gang list, the alternative, one `Outlet` per gang,
was rejected precisely because it would have redefined CR-016 rather than extended it.
**CR-121**'s keystone rule is consumed as written: the keystone follows `jacketColorId`, never
`jacketColorPulledId`. **CR-047** (the arbitrary-depth location tree), **CR-108** (outlet
templates) and **CR-112** (the project-level Locations panel) are untouched and already carry M3
checklist items.

What DR-007 does change is a **cost**, and §12.7's re-costing should be read with it: M3 stays
`M` but at the upper end, because its exit criterion, a 60-drop rough-in producing a Pull Sheet,
does not itself require strap geometry. The ruling accepts that growth deliberately, on the ground
that building the `Outlet` editor twice is worse work than building it once with the grid designed
in. See §11.7.

### 12.11 Superseded by DR-018 (the Plan view moves to v1.1, conditionally)

| Ruling | What it said | What now governs |
|---|---|---|
| **§7.6**, cable-dressing row | `Cable dressing, floor plans, 3D, thermal simulation \| Out of the brief. The brief says the plan ignores cable dressing, and it is right to` | **Superseded in part.** Floor plans leave the row and become **v1.1 (roadmap §2.2), conditionally**: v1.2 unless the underlay carrier ships in v1, because a stored raster is a format migration and §2.2's membership criterion is additive. Cable dressing, 3D and thermal simulation are **unaffected** and stay out of the brief. The rationale sentence had only ever argued cable dressing; the other three shared its cell without an argument of their own. §11.17. |

**Explicitly NOT superseded:**

| Ruling | Status under DR-018 |
|---|---|
| **RJ-017** | **Unaffected and still binding.** `DiagramCanvas` gains no `drawImage`/`ImageRef` by this ruling, and `draw/canvas.dart`'s own amendment clause still governs any attempt to add one. |
| **AC-057** | **Unaffected as written**, and its reasoning is preserved rather than waived: cutting device images closed the container question and removed the image-decode import surface. DR-018 §11.17.4 records that a Plan view **reopens both**, and requires that cost to be stated when the carrier decision is made. `.rmdev`/`.rmdx` gain no image member. |
| **AC-024** | **Unaffected and still the shipping mechanism.** `Location.estimatedRunLengthFromRack` stays the v1 length source. A plan measurement, if one ever exists, feeds the same field. |
| **G4** | **Unaffected, and DR-018 §11.17.5 restates it against this specific temptation.** A plan yields a measured horizontal distance, never a route. A plan-derived length stays tagged as an estimate unless a human marks it measured. |
| **DR-005** §11.5.3 | **Consumed, not contradicted.** It said floor plans *"remain out (v1.1 / v2)"*, which is the deferral DR-018 acts on. Riser diagrams, reflected ceiling plans, `T6.40` and `T6.50` stay exactly where it left them. |
| **DR-009** | **Unaffected, and it constrains the import path.** macOS is v1, so a Windows-only rasterizer would owe a `docs/13` entry. |
| **AC-056**, §2.4 mobile | **Unaffected.** v1 mobile stays read-only and mobile editing stays v2. DR-018 does not reach the tablet workflow that motivated the request. |
| **§12.7**, the plan's totals | **Unaffected.** §12.7 costs v1. Nothing DR-018 places is in v1, so no row and no total moves. |

### 12.12 Superseded by DR-019 (container shape; the passthrough replaces the carrier)

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-018 §11.17.4** | The raster carrier decision is owed before M3 closes, **because G5 applies: omitting it converts a later additive change into a migration over user data.** | **Superseded, and the stated reason was wrong.** Omitting the carrier costs **no migration**: the zip sniff already returns a typed error, `minReaderVersion` signals forward-incompat, and an absent entity map and an absent key are how this format expresses "not present" (G4, CR-114). The real G5 item is narrower, **`Placement` has no `unknown` passthrough**, so an older build silently drops plan pins on save. That passthrough is what v1 owes and what lands in M3; the container is built with the feature. §11.18.1, §11.18.2(5). |
| **DR-018 §11.17.2** clauses 2 and 3 | The v1.1 placement is **conditional**: v1.2 unless the underlay carrier ships in v1. Nothing is added to v1. | **Both discharged, in opposite directions.** The container shape ruled at §11.18.2(1) migrates nothing, so roadmap §2.2's additive criterion is satisfied on its own terms and **the Plan view is v1.1 unconditionally**. Clause 3 no longer holds either: **v1 grows by one item**, the §11.18.2(5) passthrough. |
| **CR-091**, the container half | Plain pretty JSON `.rmpj`, single file; a zip container is a v2 possibility that "costs nothing to add without touching call sites". | **Extended exactly as it anticipated, not superseded.** `.rmpj` is plain JSON with no binary member and zip with one. The single-file property is **unchanged and is the reason the sidecar alternative was rejected**. `DocumentCodec`'s abstraction is what makes this cheap, which is the property CR-091 bought it for. |

**Explicitly NOT superseded:**

| Ruling | Status under DR-019 |
|---|---|
| **CR-117** | **Unaffected and it constrains the writer.** Zip is nondeterministic by default, so §11.18.2(2) fixes entry order, timestamps, compression method and extra fields. The plain-JSON path's existing round-trip and golden corpus are untouched, because a document without an underlay writes identical bytes. |
| **AC-057** | **Unaffected.** No image member reaches `.rmdev`/`.rmdx`, and device images stay cut. What DR-019 opens is a *project* container, which is a different file and a different question. |
| **RJ-017** | **Superseded in part by DR-029 and DR-030.** `DiagramCanvas` **gains a `drawImage` op in v1** (DR-029), and **the integrator's logo ships in v1 during M6** (DR-030), which is the last clause RJ-017 rejected. Two of RJ-017's three grounds fell to DR-019 and DR-029; **the third stands and governs the shape**: the title block's TEXT integrator block still ships and the logo is added beside it, never instead of it. **The logo's OPACITY does not return**, so docs/08 row 9's no-alpha rule survives the feature it was written around. Everything else RJ-017 accepted (icon, wordmark, window and document icons, file-type registration, the trademark search) is untouched. |
| **AC-040**, the count of 27 | **Unaffected.** The four `PLN-*` advisories in docs/15 §9 ship with the Plan view in its own band and are not v1 rules. Any document quoting a rule total says which band it counts. |
| **AC-024** | **Unaffected and extended, not replaced.** `Location.estimatedRunLengthFromRack` remains tier 3 of docs/15 §4's four tiers and remains the answer for every room without a plan. |
| **G4 / CR-114** | **Unaffected, and it is the reason §11.18.1's correction matters.** Silent field loss on save is the same class of failure as a fabricated number: the document stops saying what it knows. |

### 12.13 Superseded by DR-020 (no predicted routes; the catalogue becomes 28)

| Ruling | What it said | What now governs |
|---|---|---|
| **§12.6(b)**, the rule count | *"The v1 catalogue is 27 rules: 8 tier-1 + 6 tier-2 + 13 tier-3."* | **Superseded on the number only.** `LEN-002` is added as a tier-3 rule, so the catalogue is **28: 8 tier-1 + 6 tier-2 + 14 tier-3**. Everything else in §12.6(b) stands exactly as written, including the ratification of `PLC-001..003` and the finding that AC-040's "22" was an arithmetic error. **AC-051's fixture gate is unchanged and applies to 28 pairs.** §11.19.2(4). |
| **AC-040**, the v1 rule set | *"v1 ships this set and no more"*, with the remaining `LEN` rules moving to v1.2 behind a fixture corpus. | **Superseded by one rule.** `LEN-002` joins v1; the rest of the `LEN` family and the other ~40 deferred rules stay v1.2 exactly as AC-040 placed them. The mechanism matters: `LEN-002` is **generic**, reading a declared `maxLength` off the media registry, so adding a medium's limit is a registry row and not a further amendment to this ruling. |
| **`docs/15` §4**, first draft | A design-time **route polyline**, a `routingFactor` and a `slackAllowance`, treated as a measured length. | **Void, one commit after it was written.** The route is discovered rather than designed: structure (LVLs, concrete beams, purlins) forces runs into a crawlspace instead of an attic and is not knowable from a floorplan. The plan contributes **`planLowerBound`** and nothing else. §11.19.1. |
| **Roadmap §2.2**, Plan view row | *"plan-measured run lengths"* | **Reworded to "a plan-derived lower bound".** The row otherwise stands and the item stays v1.1 (DR-018, DR-019). |

**Explicitly NOT superseded:**

| Ruling | Status under DR-020 |
|---|---|
| **AC-024** | **Unaffected and vindicated.** Its three length fields are exactly the shape the as-built tally needed, and `Location.estimatedRunLengthFromRack` remains the shipping estimate. DR-020 makes the third field reachable rather than changing any of them. |
| **AC-051** | **Unaffected. The gate is the point.** No rule ships without a known-bad and a known-good near-miss; `LEN-002` ships with its pair or it does not ship. |
| **LEN-001** | **Unaffected and now better fed.** It stays tier-3, error, Ethernet over 100 m. `planLowerBound` is a sound input to it precisely because a bound that already exceeds the limit settles the question. |
| **CR-016, AC-027** (`Pathway`) | **Unaffected.** The as-built route is recorded there, and a crawlspace is expressible today as a `zone` `Location` a `Pathway` runs between. Whether `PathwayKind` gains `attic`/`crawlspace` is left open at §11.19.4. |
| **G3, CR-022** | **Unaffected.** `LEN-002` is a finding like any other and gates nothing. |

---

### 12.14 Superseded by DR-033 (the community catalog submission surface)

| Ruling | What it said | What now governs |
|---|---|---|
| **§10.8's answer**, the network-use clause | *"An update check and API-key publishing to project-management services are the only contemplated network uses and are not v1 scope."* | **Superseded on the enumeration only.** There is a **third** contemplated network use: the Device Builder's authenticated submission to the community catalog. The clause's substance is untouched and is in fact honoured twice over. DR-033 keeps the use **out of v1** exactly as §10.8 requires, and it arrives as the §8.3 amendment the parenthetical demanded rather than by drift. §11.32.8. |
| **§10.9's answer**, the sharing mechanism | *"DR-015's `.rmda` is the sharing mechanism."* | **Extended, not replaced.** `.rmda` remains the answer for a library you hand to somebody. It was never an answer for a library **strangers contribute to**, which is what §10.9's own recommendation asked for and what DR-033 supplies. Both ship. §11.32.1. |

**Explicitly NOT superseded:**

| Ruling | Status under DR-033 |
|---|---|
| **DR-002, AC-052** | **Unaffected, and the reason the second repository exists.** They bind the seeded catalog, which stays generic archetypes with cited provenance and gains no submission path. §11.32.4. |
| **AC-042** | **Unaffected.** `submittedBy` is a credit that authenticates nothing and that the application never reads. Signatures and `provenance`/`derivedFrom` chains stay deleted, and the pull request history is where the chain lives instead. §11.32.5. |
| **AC-057** | **Unaffected and load-bearing.** Device images stay out of the model. The port photograph is pull request evidence committed to the contributor's fork, never `.rmdx` payload. §11.32.6. |
| **DR-006** | **Unaffected here, and it is the precondition.** The internal-tool ruling stands until something reverses it. DR-033's surface may not ship first, and §11.32.7 declines to rule the reversal rather than smuggling it in. |
| **DR-015** | **Unaffected.** `.rmda` is ruled and still unbuilt; DR-033 adds a second distribution path and removes nothing from the first. |
| **CR-117, G4/CR-114** | **Unaffected and binding on the new field.** `submittedBy` is absent when unknown, never an explicit null, and round-trips byte-for-byte with keys sorted. |

---

### 12.15 Superseded by DR-034 (installing and updating the community library)

| Ruling | What it said | What now governs |
|---|---|---|
| **§12.14's own row on §10.8** | The third contemplated network use is the Device Builder's submission. | **Corrected while the ink is wet.** The third use has **two directions**, and §12.14 named only the one DR-033 ruled. Submission (DR-033) and library fetch plus update check (DR-034) are one network use with a write half and a read half. **Both stay out of v1**, so §10.8's substance is still untouched and the count in §12.14's row was the only thing wrong with it. §11.33.1. |

**Explicitly NOT superseded:**

| Ruling | Status under DR-034 |
|---|---|
| **RJ-014** | **Unaffected, and narrower than it looks.** It refused an in-app mechanism that updates the **application**, and permitted a signed installer plus a version-check ping. DR-034 updates **data**, fetches no code, executes nothing, and its `releases/latest` call is that permitted ping aimed at a catalog. The binary still changes only by installer. §11.33.4. |
| **DR-015** | **Unaffected and reused rather than extended.** `.rmda` is the archive format already ruled; DR-034 adds a transport for it and does not touch the format, the codec, or §11.15.5's palette filter, which is the mechanism that makes a second library usable in the first place. |
| **AC-052** | **Unaffected.** The four starters and every golden resolve out of the seed, never out of a fetched library, which is what keeps them goldens. §11.33.5. |
| **AC-058/D8, AC-042** | **Unaffected and now load-bearing on a second path.** JSON depth and size limits apply to a downloaded bundle exactly as to a chosen file, and `contentHash` is verified before install. The network is not a more trusted input than the disk. §11.33.6. |
| **§10.12(e), telemetry** | **Unaffected.** Opt-in and local-first stands. An unauthenticated release check reports nothing but that somebody launched the application, and no channel is added. §11.33.8. |
| **DR-002** | **Unaffected, and the reason clause 2 exists.** The seed is generic archetypes, so an offline first launch without a bundled library is precisely the user who needed a real SKU and cannot reach one. §11.33.3. |

---

### 12.16 Superseded by DR-036 (public GPLv3 project, CC0 catalog, nothing priced)

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-006 §11.6**, the posture clause | *"(a) INTERNAL TOOL. NO COMMERCIAL RELEASE IS PLANNED.* RackMate is distributed inside the organisation that builds it." | **Superseded on posture and on distribution.** RackMate is a public project, developed in the open under GPLv3-or-later. **The rest of DR-006 stands**, including §11.6.1's finding that the two-milestone lead time was specific to OV/EV procurement. §11.35.1, §11.35.5. |
| **DR-006's signing answer** | Self-signed, with Trusted Signing as a fallback *"if external distribution is ever required"*. | **The fallback fires, exactly as it was written to.** Public distribution makes Microsoft Trusted Signing necessary at M8. **No milestone before M8 changes**, which is the promise DR-006 made when it named the fallback, and it holds. §11.35.5. |
| **§10.3, pricing** | **MOOT under DR-006**, retained with the standing note that it reopens exactly as written if DR-006 is reversed. | **Reopened and ANSWERED on its own terms: nothing is priced.** No perpetual licence, no subscription, no free tier. **The watermark hazard the note preserved is answered by never building one**, DR-005 having made the whole sheet set a client deliverable. §11.35.6, and §13's row. |
| **AC-058/D7**, the licence deliverable | Already shrunk once by DR-006 consequence 9, which deleted the commercial EULA and enforcement machinery. | **Shrinks a second time and stops being provisional.** The EULA and enforcement stay deleted permanently rather than pending a commercial decision that will not come. **It also grows by one**: GPLv3 itself must register via `LicenseRegistry` and be reachable from `showLicensePage`. §11.35.6. |
| **DR-033 §11.32.7**, the precondition | *"The submission surface may not ship before the release posture and the licence are ruled."* | **Discharged.** Both are ruled here. DR-033 and DR-034 are unconditional v1.1 items on their own merits, and their §7.3 rows lose the conditional. §11.35.9. |

**Explicitly NOT superseded:**

| Ruling | Status under DR-036 |
|---|---|
| **AC-041, copy-on-place** | **Unaffected, and the reason clauses 3 and the output exception exist.** A `.rmpj` stays self-contained. What changes is that the licence now says so out loud: a document RackMate produces is the user's own work, seeded snapshots included. §11.35.3, §11.35.4. |
| **DR-005** | **Unaffected and load-bearing.** The sheet set being a client deliverable is exactly why a watermark could never have shipped, so the pricing model that would have needed one was never really available. §11.35.6. |
| **§10.12(f), branding** | **Unaffected and explicitly not licensed.** *RackMate* and Riley the RackMate are trademarks; neither GPLv3 nor CC0 grants them. A fork takes the code and not the name. §11.35.8. |
| **RJ-014** | **Unaffected.** Going public does not add an in-app application updater. A signed installer plus a version check is still the whole story, and DR-034's catalog check is still data rather than code. |
| **§10.8** | **Unaffected.** Its network-use enumeration was already amended by DR-033 and DR-034 (§12.14, §12.15); a licence adds no network use of its own. |

---

### 12.17 Superseded by DR-037 (the Plan view's exit criterion and the four decomposition answers)

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-029 §11.28.11**, the screening clause | *"The underlay must be **pre-composited at import**, the way palette tints already are at 18 % over white, and #589 carries it."* | **Superseded on WHERE, reaffirmed on WHAT.** No alpha reaches the PDF; that half is absolute and is strengthened, because reading `PdfImage` found a second alpha path (`/SMask`) that the `ExtGState` framing would not have caught. The compositing happens **in the export backend**, not at import, so the stored bytes stay the architect's page. §11.36.3. |
| **docs/15 §7**, *"On screen it renders at full value; on paper it renders through a lightening pass"* | Both halves, as written. | **Both halves now hold**, and they did not under §11.28.11's literal reading. The sentence stops being a contradiction rather than being corrected. §11.36.3. |
| **DR-026 §11.25.2**, the open half | *"Whether a floorplan supersedes any of the four tiers is open, is not ruled here, and is owed when DR-018's condition resolves."* | **Answered: it supersedes none of them.** `planLowerBound` is a fifth value ranked **below** `roomEstimate`, so the three shipped tiers keep their order and their meanings. §11.36.4, §11.36.6. |
| **DR-026 §11.25.1 / §11.25.2**, the provisional status | Both positions *"chosen for reversibility"*, with the Plan view named as the revisit trigger. | **The trigger has fired and both are CONFIRMED.** They stop being provisional. §11.36.6. |
| **DR-020 §11.19.2(1)** and **docs/15 §4.1**, *"plus the location's `riseAllowance` if one is set"* | Both name the field as though it exists. | **It did not exist and is added by §11.36.5.** `Len? riseAllowance` on `Location`, null unknown, written only when present, no byte on disk changes and `kSchemaVersion` does not move. |
| **docs/15 §10**, the Out list | *"multi-page or tiled plans"* are out. | **Tiled stays out; multi-page is narrowed rather than reversed.** A multi-page PDF may be **imported** through a page picker, and exactly one chosen page becomes one underlay. No underlay is ever more than one page and nothing is tiled. §11.36.2. |

**Explicitly NOT superseded:**

| Ruling | Status under DR-037 |
|---|---|
| **DR-020 §11.19.2(2)**, the bound is not a quantity | **Unaffected and now enforced by a rank rather than by a convention.** `_isQuantity` excludes `planLowerBound`; the rollup counts those rows rather than absorbing them. §11.36.4. |
| **DR-020 §11.19.1**, the route is discovered | **Unaffected and load-bearing twice.** It is why the plan yields a bound and not a length, and it is why `Pathway.designator` stays hand-entered. §11.36.6. |
| **docs/08 row 9**, no alpha | **Unaffected and widened in coverage.** The rule survives the first feature that could have broken it, and now names `/SMask` as well as `ExtGState`. §11.36.3. |
| **AC-040**, the 27-rule catalogue *(28 under DR-020)* | **Unaffected.** The four `PLN-*` advisories ship in their own band and are not added to the total, exactly as docs/15 §9 states. |
| **DR-029 §11.28.9**, the cost | **Unaffected. `L`, 9–13 weeks, unchanged.** A decomposition does not re-price the epic it decomposes; that would be a §8.3 amendment wearing a task's clothes. §11.36.7. |
| **AC-056**, mobile read-only | **Unaffected.** This ships to a desk, not to a technician on site, and §11.28.7 already said so. |

### 12.18 Superseded by DR-044 (the shipped templates carry terminations)

**One clause, and it is the shortest-lived entry in this section: hours.** DR-043 was ruled on
2026-08-11 and DR-044 superseded a clause of it the same day, before any of it was built.

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-043 §11.42.5** | The six shipped `OutletTemplate`s are **not** seeded with terminations and stay null, because *"a shop authoring its own template says what it terminates in"*, on DR-024 §11.23.2's precedent. | **Superseded.** **All nine shipped templates are seeded** (§11.43.3). The clause failed on a fact rather than on a judgement: **nothing in this product can author an `OutletTemplate`**, so the sentence describes a capability that does not exist, and the field would have been null everywhere for ever. The DR-024 precedent was also mis-cited: that ruling refused a **standards citation**, and a termination is a recipe fact of the same kind as the cable count already in the recipe. |
| **DR-043 §11.42.2**, the template is the load-bearing path | **Restored rather than superseded.** The argument was sound and its premise was false; §11.43 supplies the premise. **Its cap survives**: a shop still cannot author its own recipe, and §11.43.5 records that as live rather than discharged. |

**Nothing else in DR-043 moves.** The default stays Unspecified (§11.42.1), the colon grammar
(§11.42.3), the vocabulary rule (§11.42.4) and the batch machinery (§11.42.6) are untouched.

**Why this is a §12 entry and DR-042 was not.** DR-042 replaced a figure that had been deliberately
recorded as a **stated choice** precisely so it could be replaced silently, so there was nothing to
withdraw. This voids a **clause of a ruling**, which is the thing §12 exists to index. The contrast
is the whole practical argument for §11.40.4's discipline: one of these needed an entry here and the
other did not.

### 12.19 Corrected by DR-047 (a gang can be fitted with a pass-through)

**A premise rather than a judgement, and it is listed because §12's preamble makes an unlisted
sentence read as still binding.** DR-045 filed the pass-through plate honestly and did not model it;
what it also did was describe the obstacle, and the description stopped being true the moment the
obstacle was removed.

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-045 §11.44.6** | A pass-through plate is *"a plate with no strap behind it, which `PlateFill.coverPlateGangs` structurally cannot express, because that getter returns `gangs.length` and a plateless outlet has zero gangs by construction."* | **Premise changed, conclusion withdrawn.** True only while a brush opening had no gang. Under §11.46.2 the opening **is** a gang, fitted with a `PassThrough` rather than a `Strap`, so the plate's gang count falls out of `gangs.length` as it always did and **`coverPlateGangs` is unchanged**. The sentence's *other* half stands and is reaffirmed: a pass-through plate is a **third object** after the strap and the cover plate, and §11.7.8 change 1's separation is what made room for it. |
| **DR-045 §11.44.6**, the open question | *"It needs its own ruling on whether the plate is a property of the **outlet** or of the **drop**."* | **Answered as neither**, §11.46.1. Both readings were live and both are refused: the drop buys nothing (`outletId` is non-nullable) and costs a de-duplication rule; the outlet cannot express a mixed plate and duplicates a fact the gangs carry. **A question with two named options is not a closed set**, and this is the second time in three rulings that censusing the code before pricing the task produced the answer neither option contained (see DR-043 §11.42, where five drop-entry surfaces corrected a task that had asked for a modifier). |

**Nothing else in DR-045 moves.** `TerminationType.rj45Plug` and its zero cells (§11.44.2), the AP
template (§11.44.3), the three states of an outlet (§11.44.4) and the derived-never-stored rule
(§11.44.5) are all untouched, and §11.46.5 restates the last of them rather than amending it.

---

### 12.20 Superseded by DR-048 (`T6.50` ships in v1; a network value is dated)

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-005 §11.5.3**, first bullet | *"It does not add floor plans, riser diagrams, reflected ceiling plans, datasheet appendices, `T6.40` Power Schedule or `T6.50` Network/IP Schedule to v1. Those remain out (v1.1 / v2)."* | **Superseded for `T6.50` ALONE.** The Network/IP Schedule ships in **v1, in M6**, as an `AUTO` slot emitted iff at least one device carries a network value (§11.47.4). **Every other item in that bullet is untouched and stays out**: floor plans went to v1 by their own ruling (DR-029) and riser diagrams, reflected ceiling plans, the datasheet appendix and **`T6.40` Power Schedule** remain exactly where DR-005 left them. The asymmetry has a reason and it is not preference: `NetworkConfig` is in the format today and the power data is not, so `T6.50` is a sheet over data the model already holds while `T6.40` would be a sheet plus the model to feed it. |
| **docs/08 §2.2** | *"`T6.40` Power Schedule and `T6.50` Network/IP Schedule … defer to v1.1"*, under the heading **"Not in v1, and this is a ruling, not an omission."* | **Half superseded.** The heading was accurate and is the reason this took an amendment rather than a doc edit. `T6.40`'s row stands verbatim. `T6.50` moves into v1 and its sentence is rewritten in place. |
| **§12.11's DR-018 row** and **§11.17** | Recorded that DR-018 *"does not add `T6.40`, `T6.50`, riser diagrams or reflected ceiling plans, which stay where DR-005 left them."* | **Still true of DR-018, and now historical for `T6.50`.** DR-018 did not move it; DR-048 does. The row is kept as written because it is DR-018's record and editing it would falsify what that ruling did. |

**One thing this does NOT supersede, stated because its absence looks like an oversight.** Roadmap §2
carried **no row for `T6.50` in any release**, so there is nothing in the scope list to supersede;
§2.1 gains a row rather than §2.2 losing one. **A ruling that defers something and a scope list that
carries it are two different artifacts**, and this item had the first and never the second for the
whole life of the project, which is how a reserved sheet id came to be the most authoritative-looking
statement about it (§11.47.1).

---

### 12.21 Superseded by DR-051 (documentation is referenced and never embedded)

| Ruling | What it said | What now governs |
|---|---|---|
| **docs/08 §2.2** | *"The datasheet appendix defers to v2, the `pdf` package writes documents, it does not import pages."* | **The deferral becomes a refusal.** Not v1, not v1.1, not v1.2, **not v2**, on DR-004's pattern. **The stated reason survives and is reaffirmed**: the library limit is real and is restated at §11.50.1. What changes is the destination, because a deferral implies a release in which the objections lapse and **none of the four does**. The library limit could be engineered around; the **copyright** ground (§11.50.4) cannot be, at any date, by any amount of work. |
| **DR-005 §11.5.3**, first bullet | Listed *"datasheet appendices"* among the things it does not add to v1, *"out (v1.1 / v2)"*. | **Superseded for the datasheet appendix, which now has no release at all.** The rest of that bullet is unaffected here; `T6.50` moved at §12.20 and everything else stays where DR-005 left it. |

**ROADMAP §2.4 NEVER CARRIED THE DATASHEET APPENDIX, and this row was drafted claiming it did.**
`grep -in datasheet docs/09-roadmap.md` returns nothing. The v2 promise lived in **docs/08 §2.2 and
docs/10:803**, both derived, plus DR-005's bullet, which is the only normative site. **So v2 does not
shrink by a line, because it never held one**, and roadmap §2.5 gains the row instead. Recorded as a
correction rather than silently fixed, because it is the *third* time in three days that a v-number
in a derived document has been mistaken for a scope-list entry (§11.47.5 is the same finding about
`T6.50`, from the opposite direction).

**Explicitly NOT superseded.** **DR-015 §11.15.4 is untouched and is load-bearing here**: `.rmda` is a
single JSON file and not a zip, and §11.50.2 *applies* that argument rather than revisiting it.
**DR-036 §11.35.3 and §11.35.4 are untouched**: the CC0 catalog and the output exception both stand,
and §11.50.4's point is that neither reaches content the project never had the right to embed in the
first place.

---

### 12.22 Superseded by DR-052 (git sync is v1.2; live collaboration is never)

| Ruling | What it said | What now governs |
|---|---|---|
| **Roadmap §2.4**, v2 row; **docs/00 §7**; **canon §4867** | *"Cloud sync and multi-user. The model is already cloud-ready (stable UUIDs, `schemaVersion`, no positional identity, tombstones, `sequence`). Nothing more is spent until someone asks."* | **SPLIT, because the row is two features wearing one name.** **Sync** (moving one document between machines and people, one writer at a time) moves **forward** to v1.2 as git sync, gated on evidence, plus a v1 divergence warning. **Multi-user** in the sense of simultaneous editing moves to **never** (§11.51.1). The row's *reasoning* survives both halves and is why the split is possible: the model being cloud-ready is exactly what makes sync cheap and is **irrelevant** to concurrent editing, which fails on determinism, CR-117 and undo rather than on identity. |
| **Roadmap §2.4**, the same row's "nothing more is spent until someone asks" | A standing deferral with no gate. | **Replaced by a real gate for the sync half**: real projects showing a handoff a file share does not already solve (§11.51.2). *"Until someone asks"* is not a gate, because somebody has now asked and the sentence gives no way to tell whether that settles it. |

**Explicitly NOT superseded.** **DR-039 is untouched and is not replaced by this** (§11.51.4): the
in-file journal exists because history on a server is absent from the artifact under investigation,
which git does not fix and makes slightly worse. **DR-033 §11.32's no-secrets constraint governs the
authentication** and is not re-opened. **DR-034 §11.33's "fetched, never cloned"** is not contradicted:
it ruled how a *library* arrives, on the ground that clone does not survive a platform with no git,
and that ground is why §11.51.6 puts the v1 item on plain file divergence rather than on git.


---

### 12.23 Amended by DR-069 (a binding post is on a plate or on a driver, and the word does not say)

**Listed because §12's preamble makes an unlisted row read as still binding**, and because the row
below is the one a reader consults when sizing a strap.

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-007 §11.7.2.1**, the binding-post row | "binding post / single post (speaker) &#124; **one per `Conductor` landing there**: 16/2 → 2 cells, 16/4 → 4 cells" | **Amended, and only for a landed field end.** The row stands unchanged for a run that terminates AT A PLATE, which is what it was written for: a speaker binding-post wall plate is a product, its posts are on the plate and each conductor lands in a cell. A run whose field end is bound to a DEVICE port needs **zero** cells, because the posts are the driver's and there is no plate. See §11.68.1. |

**Nothing else in DR-007 moves.** The modular-jack row, the `punchdown` row and the "nothing is on
the plate" row are untouched, and §11.68.2 asserts that no other termination reads the landing at
all.

**The same table's closing paragraph is now spent rather than wrong.** It says `TerminationType`
*"does not yet name a binding-post case, and adding one is the smallest change that makes this table
computable"*. The member was added and the table is computable; what the sentence could not
anticipate is that the member would turn out to name two different objects. That is §11.68.4's
finding, and it is the third time the enum has been asked whose hardware a termination belongs to.


---

### 12.24 Premise changed by DR-070 (`outletId` is no longer non-nullable)

**A premise rather than a judgement, listed because §12's preamble makes an unlisted sentence read
as still binding**, and because the sentence is load-bearing in the reasoning of a ruling that
stands.

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-047 §11.46.1** | Ruling the plate a property of neither the outlet nor the drop, it priced the drop reading as buying nothing *"(`outletId` is non-nullable)"* and costing a de-duplication rule. | **Premise changed, conclusion UNAFFECTED and reaffirmed.** `outletId` is nullable under §11.69.1, so the parenthesis is no longer true. The conclusion never rested on it: the plate is a property of the **gangs**, `coverPlateGangs` returns `gangs.length`, and a boxless run has no outlet to carry a plate either way. The de-duplication cost the ruling named is likewise untouched. Recorded so a later reader does not take a false parenthesis for a live argument, or reopen a settled question on the strength of it. |

**Nothing else in DR-047 moves.** §11.46.2's three gang states and §11.46.5's derived-never-stored
rule are untouched.


---

### 12.25 Answered by DR-074 (unbinding is ruled)

**Listed because §12's preamble makes an unlisted sentence read as still binding**, and this one has
been cited three times since it was written.

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-040 §11.39.6** | *"**Unbinding is not ruled**: `BindEndpoint` gets a `revert` because every command does, and a deliberate 'this was punched into the wrong port' gesture is not specified here."* | **Answered by DR-074 §11.73.** A MOVE and an UNLAND are two commands; the rack label follows the position unless a person typed it; the termination survives both. The sentence's other half stands: a `revert` is still not an unbind, and the two commands are forward acts with their own undo entries. |

**Two rulings leaned on the gap while it was open, and both are now spent rather than wrong.**
DR-071 §11.70.3 draws a landed `LANDS ON` row as plain text, and DR-073 §11.72.5 refuses an already
landed pennant, each citing §11.39.6's silence as the reason. The refusals were correct while
re-landing had no meaning. **Whether either surface should now offer the gesture is left to the
task** by §11.73.5 rather than decided here, and until it is built both behave exactly as ruled.


### 12.26 Amended by DR-075 (an imported rack label is a person's assertion)

| Ruling | What it said | What now governs |
|---|---|---|
| **DR-074 §11.73.2** | *"`rackLabelLocked` on `StructureOrigin`, written by the `RACK LBL` cell's own edit path **and by nothing else**."* | **Amended by DR-075 §11.74.** The clause was written to keep the ALLOCATOR out and kept the CSV importer out with it. A `rack_label` column in an imported sheet is a person choosing an identifier, so it locks too. **The rest of §11.73.2 is untouched:** `AddHomeRunCommand` and `BindEndpointCommand` still write allocator labels and still do not lock, absent-when-false is unchanged, and a blank cell still clears both. |

**The defect DR-075 §11.74.2 records is not a consequence of this amendment.** The importer had no
running rack-label reservation before it either, so two rows of one sheet could already write one
label onto two drops.
---

## 13. Resolved §10 questions

**§10 has no open entries left.** Of its thirteen: **eleven are ANSWERED**, one (§10.11) is
**DEFERRED with a trigger** that fires before M6-J5, and one (§10.13) is **retired** because the
three questions it prioritised are all answered. The text of §10 stays in place as the record of the
argument; this section is the index of what was decided.

Closed as of 2026-08-03, except **§10.3, which reopened and was answered on 2026-08-10** when DR-036
reversed DR-006 and made it a live question again, exactly as its own row had warned it would.
§10.11 is the only entry still owing an answer, and it owes it to M5, not to now.

| § | Question | Status | Answer |
|---|---|---|---|
| **10.1** | Draw every wire, or net labels by default, the fork | **ANSWERED, DR-001** | **(B) Net labels by default.** Drawn wires on domain filter, `Alt`-hover or focus. Reverses the record's recommendation. §11.1. |
| **10.2** | Residential CI or commercial AV, the primary customer | **ANSWERED, DR-002** | **(a) Residential-primary, commercial-capable.** Commercial capability present, never fronted. Confirms the recommendation. §11.2. |
| **10.3** | Pricing and licensing model | **REOPENED, then ANSWERED 2026-08-10: DR-036** | **Nothing is priced.** No perpetual licence, no subscription, no free tier with a paid ceiling. **The row's own warning came true**: DR-036 reversed DR-006, §10.3 reopened exactly as written, and the watermark hazard it preserved is answered by never building one, since DR-005 makes the whole sheet set a client deliverable and an integrator cannot send a stamped drawing to a homeowner. The licensing half is answered too: **GPLv3-or-later** for the code, **CC0** for the community catalog, with an output exception putting every document RackMate produces outside both. §11.35. |
| **10.4** | Does the device builder have to be in v1 | **ANSWERED: DR-003** | **(a) Yes. M4 stays where it is.** Confirms the recommendation. §11.3. |
| **10.5** | Metric or imperial default | **ANSWERED 2026-08-03** | **Imperial default, one obvious toggle.** Confirms the recommendation. The default is already in the code; the toggle is owed (#562). §10.5. |
| **10.6** | Is the schematic a client deliverable or an internal tool | **ANSWERED, DR-005** | **(a) Client deliverable, invest in drafting polish.** Reverses the record's recommendation. Orthogonal to 10.1. §11.5. |
| **10.7** | Multi-sheet timing | **ANSWERED: DR-004** | **(c) Never.** One `Sheet` plus domain filtering, permanently. The entity remains. §11.4. |
| **10.8** | Cloud-ready investment | **ANSWERED 2026-08-03** | **(a). Spend nothing further; RackMate is a local application.** Confirms the recommendation. The six cloud-ready properties are **retained in full** and option (c) is not taken. `docs/02` §8 is **ratified** as the conflict-unit and merge-story page the recommendation asked for, rather than commissioned. An update check and API-key publishing to project-management services are the only contemplated network uses and are **not v1 scope** (§8.3 applies to either). §10.8. **Amended by DR-033 and DR-034**: there is a third contemplated network use, the community catalog, in a write direction (submission) and a read direction (library fetch and update check). Both are likewise not v1 (§12.14, §12.15). |
| **10.9** | Generic archetypes forever, or a real-SKU catalog | **ANSWERED 2026-08-03** | **Shipped catalog stays generic; user templates may carry real SKUs.** Archetypes must be editable (docs/06 §7.3's `Duplicate & edit`), and DR-015's `.rmda` is the sharing mechanism. AC-052/DR-002 bind the SEED only. `T6.30` stays an equipment list, not a BOM (AC-055). §10.9. **Its recommendation is discharged by DR-033**, which builds the curated community library as a second repository the app submits to. §10.9's stated tipping condition was whether users start swapping device files unprompted; the user settled it by deciding to support the swap rather than waiting to observe it. §11.32. |
| **10.10** | macOS in v1 | **ANSWERED: DR-009** | **(b) Windows and macOS from v1.** Reverses the record's recommendation, which was explicitly *"not a ruling"* and rested on a desk survey that was never run. The register §10.10 demanded and never received is `docs/13-macos-debt-register.md`. §11.9. |
| 10.11 | What the beta gate actually is | **DEFERRED 2026-08-03, with a trigger** | Held until M5 (Validation) lands and the UI is largely frozen, on the ground that the bar is easier to state against a product than against a plan. **It must be answered before the M6 recruiting ask (M6-J5)**, not before M9; you cannot ask three people to commit real jobs without saying what you will judge. |
| 10.12 | Small calls needing an owner | **ALL SEVEN SETTLED 2026-08-03** | (d) three residential + one commercial starter, by DR-002. **(a)** keep 200, make it a setting (#560). **(b)** autosave while working, never while idle, and it exposed a live defect, now fixed. **(c)** editable rack presets, **DR-016**, a scope addition under §8.3 (#561). |
| 10.13 | The three to answer first | **retired** | All three (10.1, 10.2, 10.4) are answered. The section has served its purpose. |

### 13.1 What the answers make easier or moot

| Remaining question | Effect |
|---|---|
| **10.3, pricing** | **Moot under DR-006, no longer a remaining question.** The row is kept because the reasoning survives its own mooting: DR-005 makes the client-facing set larger and more valuable, which would strengthen option (c)'s logic (price the deliverable, not the software) *and* raise the stakes on the watermark split, client-facing sheets only, never the Pull Sheet or Termination Schedule. That is the state §10.3 reopens in if DR-006 is ever reversed. It no longer needs deciding before M6, or at all. |
| **10.5: metric or imperial** | **Unchanged and still cheap.** DR-002 tilts it toward (a) imperial default, since North American residential is the stated primary market. One settings row either way. |
| **10.8, cloud-ready investment** | **ANSWERED 2026-08-03, no longer a remaining question.** The row is kept because the reasoning is what produced the answer: DR-004 removed multi-sheet, the largest remaining source of entity-graph churn, which made the conflict unit stable enough that (a) became the clear answer rather than the cautious one. The second half of that recommendation, *write the conflict-unit page down*, turned out to be already paid: `docs/02` §8 existed and was ratified rather than written. |
| **10.9: real-SKU catalog** | **Better instrumented.** DR-003 keeps the builder, so the long tail has a first-class answer in v1 and the real-SKU question stops being urgent. Measure 7's miss rate now feeds this question instead of 10.4. |
| **10.10, macOS in v1** | **ANSWERED by DR-009, no longer a remaining question.** The row is kept, like 10.3's, because the reasoning survives being answered: the 3–5 week estimate and the cost list it rests on are what `docs/13` was checked against, and two of that list's items (font availability, and the `Cmd`/`Ctrl` spread across "~40 bindings") turned out not to hold for this tree in the way §10.10 assumed. The first does not apply at all; the second is 22 bindings today and is being extracted in M2 before it reaches 40. |
| **10.11: the beta gate** | **Easier.** DR-005 makes M9's criterion sharper and more testable: "a sheet set they were willing to send out" now has a concrete bar, full sheet furniture, revision block populated, IFC stamp available. |
| **10.12(a) undo depth, (b) autosave, (c) default rack height** | Unchanged. |
| **10.12(e) telemetry** | **Easier.** Its only stated cost was that opt-in-only makes 10.4's miss-rate instrumentation manual. 10.4 is answered, so that objection is gone: opt-in, local-first crash reports only. |
| **10.12(f) branding** | Unchanged. RJ-017 stands. |
| **10.12(g) is `rules.md` user-visible** | **Answer stands, home changes.** Still user-visible, in-app, linked from every finding, but the catalogue's canonical home is the data-model document's validation section, not a separate `docs/rules.md`, and the count is **27**, not 22. |
| **10.13** | **Moot.** Retired; all three are answered. |

---

## 14. PAL-1, restated: the greyscale rule over rendered values

Ruled under §12.6(c). This section supersedes the statement of PAL-1 in §6.2.2 and the domain-level
verdict table beneath it. It does **not** change any hue, and it does not change requirement 4's
resolution (hue = domain; dash + weight + glyph + tag = type).

### 14.1 The restated rule

> **PAL-1 (rendered-value form).** Every shipped `SignalFamilyDef` renders as the triple
> *(L, dashClass, weight)*, where **L** is the WCAG relative luminance of its **effective** hue,
> **dashClass** is the class of its effective dash pattern per the mechanical definition below, and
> **weight** is its effective line-weight multiplier — *effective* meaning **after** any
> `colorOverride`, `dashOverride` or weight override declared in the signal-family registry, not
> the domain base value.
>
> For **every pair of families belonging to different `SignalDomainDef`s** whose luminances satisfy
> **|L₁ − L₂| < 0.10**, at least one of the following must hold: **(a)** their dash classes differ,
> **or** **(b)** their weight multipliers differ by a factor **≥ 1.4**.
>
> Families **within one domain** are exempt from (a)/(b) — they share a hue by construction, the
> legend prints them adjacently, and the tag pill disambiguates them — but any two families in one
> domain must still differ in **dash pattern, weight, or glyph**.

Two things changed and both matter. It is now stated over **rendered family values**, not domain
base values, which is what is actually drawn. And it is **disjunctive**: the old conjunctive
reading ("no two may share a dash class, *and* weights must differ by ≥ 1.4") is unsatisfiable by
the shipped palette and was never the intent; the domain-level verdict table quoted the maximum
spread across a band rather than checking pairs, which is how the collision survived.

### 14.2 Dash class, defined mechanically so a test can compute it

A dash pattern is a repeating sequence of alternating **marks** and **gaps** in points. Classify
each mark: **dot** < 2.5 pt · **short** 2.5–8.9 pt · **long** ≥ 9 pt. The **dash class** is the
sequence of mark classes over one period, compared **up to rotation**. `solid` is its own class.

Worked: `2,3` → `(dot)` · `1.5,3` → `(dot)` · `6,3` → `(short)` ·
`6,3,3,3` → `(short,short)` · `12,4` → `(long)` · `6,3,1,3` → `(short,dot)` ·
`1.5,3,4,3` → `(dot,short)` = `(short,dot)` by rotation · `1.5,3,1.5,9` → `(dot,dot)` ·
`8,3,1.5,3,1.5,3` → `(short,dot,dot)`.

### 14.3 The collisions, and their fixes

**Eight families moved in total: the three below, plus the five in "The further five" beneath the
table.** The authority for every effective value is `tools/pal1_check.py`.

The first three collisions found, these fixes stand and are reproduced in the check file:

| Pair | Before | Verdict | Fix |
|---|---|---|---|
| `audio.spdif_optical` (TOSLINK, L 0.2215) vs `ctl.ir_emitter` (IR, L 0.2930) | `2,3` @ 1.00× vs `1.5,3` @ 0.75×. ΔL 0.0715; both `(dot)`; ratio **1.33**. | **FAILS.** Two of requirement 4's ten named types render as near-identical fine dots in greyscale. | **`audio.spdif_optical` weight 1.00× → `1.25×`.** Dash stays `2,3`. Ratio becomes **1.67 ≥ 1.4** ✓ |
| `structure.pathway` (L 0.3185) vs `ctl.ir_emitter` (L 0.2930) | `2,6` @ 0.75× vs `1.5,3` @ 0.75×. ΔL 0.0255; both `(dot)`; ratio **1.00**. | **FAILS.** | **`structure.pathway` dash `2,6` → `1.5,3,1.5,9`**, class `(dot,dot)` ✓, period 15 pt. Weight stays 0.75×. A double-dot reads correctly as "a route, not a conductor". |
| `structure.undetermined` (L 0.3185) vs **five** families: `audio.line_unbal` `6,3` @ 1.00×, `audio.mic` `4,3` @ 1.00×, `audio.headphone` `3,3` @ 0.75×, `ctl.rs485` `6,3` @ 1.00×, `ctl.trigger12v` `4,3` @ 0.75× | `4,4` @ 0.75×, inherited from the `str` domain base. ΔL 0.0977 / 0.0977 / 0.0977 / 0.0255 / 0.0255; **all six are `(short)`**; ratios 1.33, 1.33, **1.00**, 1.33, **1.00**. | **FAILS all five.** Against `audio.headphone` and `ctl.trigger12v` the dash class *and* the weight are identical, in greyscale they are the same line, separated by hue alone. | **The `str` domain base dash `4,4` → `6,3,3,3`**, class `(short,short)` ✓, period 15 pt, permille `[6000, 3000, 3000, 3000]`. Weight stays 0.75×. `structure.undetermined` carries no `dashOverride` and inherits it, so the legend's `str` swatch and the drawn line move together. `structure.undetermined` is the correct family to move: it is a placeholder, it is not one of requirement 4's ten named types, and moving it is one edit against five. |

`ctl.ir_emitter` is deliberately **not** touched: it is a requirement-4 named type and its `1.5,3`
was itself the correction that brought the control domain up to the dash-period floor.

**The "What was verified, and how" paragraph that stood here is retracted.** It claimed all three
fixes "were checked by enumerating every shipped `SignalFamilyDef` (55 families across the eight
domains) … and comparing it against every family in a different domain whose luminance is within
0.10", and it published per-family in-band tallies and pass counts. **No such enumeration was
performed.** Its own figures give it away: TOSLINK's in-band set is **27** families across four
domains, not the 26 it reported. That made three successive assertions that PAL-1 was "verified
clear", each one made by reading a table of eight domain rows rather than enumerating the family
pairs actually drawn, and each one false. The palette those assertions certified carried
**fourteen** collisions, six of them involving types requirement 4 names by hand: S/PDIF against
RS-232, DMX512, DALI, KNX, contact closure and IR receive.

**A rule checked by inspection is not checked, and the remedy is to stop making the claim in
prose.** No part of this record may assert that a manual PAL-1 sweep was performed, or enumerate
which families were checked against which. The authority is a committed, executable check:

> **`tools/pal1_check.py` is the authority.** It enumerates all **55** shipped families, computes
> each rendered triple *(L, dashClass, weight)*, and tests all **385** in-band cross-domain pairs
> against §14.1 plus the within-domain and dash-period limbs. It exits 0 on the corrected palette
> and reproduces all fourteen violations if the corrections are reverted. **Where this document
> and that file disagree, the file wins and the document is wrong.** It is ported to
> `pal1_conformance_test.dart` in `rackmate_core` at M0 and is the authority thereafter (§14.5).

**The further five.** Enumerating the pairs rather than the eight domain rows found five more
families that had to move. All five preserve their domain's base weight semantics, and **no hue
changed**: the Okabe–Ito domain palette is untouched.

| Family | Before | After | Class change | Why |
|---|---|---|---|---|
| `video.hdmi.1_4` | solid @ 1.00× | **solid @ 0.75×** | stays `solid` | It was byte-identical to `video.hdmi.2_0`, violating the within-domain limb. The three HDMI generations now read as a bandwidth progression **0.75× / 1.00× / 1.25×** and all stay solid, solid being the native digital-video carrier. |
| `video.composite` | `12,4` @ 1.00× | **`1.5,3` @ 1.00×** | `long` → `dot` | Weight is untouched; the analog-video base weight semantics are preserved. |
| `audio.line_bal` | `10,3` @ 1.00× | **solid @ 1.00×** | `long` → `solid` | It collided with **four** `video.analog` families at once (`video.composite`, `video.svideo`, `rf.ota` and `rf.modulated`) all at ΔL 0.0112. |
| `audio.spdif_coax` | `6,3,1,3` @ 1.00× | **`12,4,3,4` @ 1.00×** | `(dot,short)` → `(long,short)` | Requirement 4's S/PDIF. Cleared all six `ctl` collisions: RS-232, DMX512, DALI, KNX, contact closure and IR receive. |
| `audio.aes3` | `10,3,1,3` @ 1.00× | **`12,4,10,4` @ 1.00×** | `(dot,long)` → `(long,long)` | Cleared `ctl.cresnet` and `video.avoip`. |

Effective values for all eight moved families live in `tools/pal1_check.py`'s `FAMILIES` table,
which is the row-for-row source the §6.4 registry rows must match.

### 14.4 The dash-period floor

**≥ 4.5 pt (1.5875 mm).** The competing figure of 4.25 pt is wrong: 4.25 pt = 1.4992 mm, which is
*below* the 1.5 mm physical floor the rule is derived from, and 4.5 pt is the figure that
generated the shipped correction of the control domain's `1,3` (4.0 pt period) to `1.5,3` (4.5 pt).
Every occurrence of "≥ 4.25 pt" becomes **"≥ 4.5 pt"**. Every corrected pattern clears it:
`2,3` = 5 pt, `1.5,3,1.5,9` = 15 pt, `6,3,3,3` = 15 pt, `1.5,3` = 4.5 pt, `12,4,3,4` = 23 pt,
`12,4,10,4` = 30 pt (the remaining two corrections are `solid`, which has no period). The floor is
a limb of `tools/pal1_check.py`, so this list is checked rather than asserted.

### 14.5 The test that makes this real

A unit test enumerates every shipped `SignalFamilyDef`, computes its rendered triple, and checks
**every cross-domain pair** against §14.1. It exists today as **`tools/pal1_check.py`**, runnable
before any Dart exists (`python tools/pal1_check.py`, exit 0 clean, 1 on any violation), and is
ported to `pal1_conformance_test.dart` in `rackmate_core` at M0, remaining the authority
thereafter. It is a named acceptance criterion of the registry (§6.7) and of M2's exit. The
within-domain exemption is expressed in the test as a domain-equality check, **not** as an
allowlist of pairs, an allowlist is how a real collision gets waived.

---

**End of Part 4.** DR-001…DR-036 are the user's decisions and are binding. §12 is the complete
index of what they supersede, §12.1…§12.5, §12.9, §12.11, §12.12 and §12.13 by ruling, §12.6 by
internal correction, and §12.8 the list of Parts 1–3 sites carrying a pointer. **Two entries
supersede another DR**: §12.12 (DR-018's reasoning as well as its ruling) and §12.13, which also
corrects §12.6(b)'s rule count from 27 to 28. Anything not listed there stands as written
in Parts 1–3.

**§11.30 supersedes nothing and DISCHARGES something**, which is a third relationship and is why it
has no §12 entry. DR-020 §11.19.4 is a *"what it does not rule"* clause with a date on it; answering
it leaves DR-020 entirely intact and simply makes one of its open questions closed. A reader of
§11.19.4 should follow the pointer there rather than infer that DR-020 was amended.
