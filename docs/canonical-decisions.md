# RackMate — Canonical Decision Record, Part 1

**Status:** NORMATIVE. Supersedes all six `design-*.md` documents wherever they disagree with it.
**Scope of Part 1:** resolved contradictions, accepted critiques, rejected critiques.

---

## 0. How to read this document

The six design documents were written in parallel against a shared brief and never reconciled.
They are individually strong and collectively not one specification. From this point:

- **This record is normative.** The six `design-*.md` files are demoted to **non-normative
  rationale** — they remain the best available explanation of *why* a decision was taken, and
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
3. Local **single-file `.rackmate` projects (JSON)**; cloud-ready model — stable UUIDs,
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

### CR-001 · The base length unit — four incompatible answers

- **design-data-model.md §3.7:** "`Len` = **int64 nanometres.** … Why nanometres specifically:
  1 in = 25 400 000 nm exactly."
- **design-architecture.md D3:** "**Geometry stored as `int` in hundredths of a millimetre
  (10 µm).** … *tenths-of-mm — a plausible first choice — is **not** exact: 44.45 mm = 444.5
  tenths. Use hundredths.*"
- **design-ux-rack.md (design constants):** "Logical geometry is stored as integers (`int` U
  counts, `int` tenths-of-mm)."
- **design-ux-schematic.md §1.1:** "Everything is stored as `int` tenths-of-a-millimetre. No
  doubles in the model, ever."
- **design-ux-device-builder.md §3.2:** `"depthMm": 330`, `"weightKg": 7.3`, `"xMm": 24.0` —
  floating-point millimetres.

**Ruling — `Len` is `int64` nanometres.** `design-architecture.md` D3 is right that tenths is
inexact and wrong that hundredths is exact: the EIA 1/32-in inter-panel clearance that
`design-data-model.md` itself renders (`44.45n − 0.79 mm`) is 79.375 hundredths-mm — not an
integer. Only nanometres make every imperial fraction to 1/1000 in exact (1/32 in = 793 750 nm;
1U = 44 450 000 nm). Readability of a number no human reads is not a consideration.
`Len`, and the extension types `Mass`, `Money`, `Permille`, are defined **once** in
`rackmate_core/units/` and every other document references that definition rather than
restating it. Two unit tests are written before any other code: exact 1/32-in clearance, and
zero accumulated error across a 45U stack.

### CR-002 · The 1U-in-tenths arithmetic error

- **design-ux-schematic.md §5.4:** "`heightU × 444` tenths-mm tall (EIA-310 1U = 44.45 mm =
  444 tenths, **exact — no rounding anywhere in the vertical axis**)."

**Ruling — the statement is false and is deleted.** 44.45 mm is 444.5 tenths; the stated
constant loses 0.05 mm per U and 2.25 mm across a 45U rack, which is visible on a dimensioned
print. Superseded by CR-001. `k1RackUnit = Len(44_450_000)`.

### CR-003 · Mass unit

- **design-data-model.md §2.0:** "`Mass(int ug)` … micrograms → grams exact, lb exact."
- **design-ux-rack.md §6:** `weightCapacityGrams`, `weightGrams`.
- **design-ux-device-builder.md §1.3/§3.2:** `weightKg` / `weightLb`, `"weightKg": 7.3`.

**Ruling — `Mass` is `int64` micrograms** (1 lb = 453 592 370 µg exactly). Kilograms and
pounds are display formats produced by `UnitFormatter`; neither is stored. `.rmdev` writes
`weightUg`.

### CR-004 · Schematic grid pitch and sub-grid precision

- **design-data-model.md §2.0/§3.7:** "`Pt` … **INTEGER grid units. 1 gu ≡ 2.54 mm** nominal
  pitch" with "1/64-gu sub-offsets for annotation nudging only."
- **design-ux-schematic.md §1.1:** "Base grid unit `U` | **25 tenths-mm (2.5 mm)** … Snap grid
  (default) 1U; `Alt` = free (0.1 mm), `Shift` = 4U coarse."

**Ruling — pitch from `design-ux-schematic.md`, storage from `design-data-model.md`, free
positioning deleted.** One schematic grid unit `gu` = `Len(2_500_000)` (2.5 mm); pin pitch
2 gu; the argument that AV port labels need more room than KiCad's 100 mil is correct.
Positions are `Pt{int gx, int gy}` in gu — no sub-grid, no `sx`/`sy`, no `Alt`-free nudge.
Free 0.1 mm positioning defeats the exact-integer routing that the whole layout pipeline is
built on and gives the user a way to author an unroutable drawing. Snap: 1 gu default, 4 gu
with `Shift`. If sub-grid annotation nudging is ever needed it is added as `int sx, sy` in
eighths of a gu — additive, no migration.

### CR-005 · BTU conversion constant

- **design-data-model.md §2.5:** "`typicalWatts × 3.41214`."
- **design-ux-rack.md §5.1** and **design-ux-device-builder.md §1.4:** "`watts × 3.412`."

**Ruling — one constant, `kBtuPerWattHour = 3.412142`, in `rackmate_core/units/thermal.dart`.**
Heat is **derived, never stored**; `TemplateBody.btuPerHourOverride` is retained for the rare
manufacturer figure that disagrees with the arithmetic.

### CR-006 · Rack-elevation coordinates: stored or derived

- **design-data-model.md §3.7:** "Rack elevation space is not stored. … Elevation is a
  **projection**, computed fresh, always correct by construction."
- **design-ux-rack.md (appendix):** `Placement { … final int bottomU; … final int?
  xOffsetTenthMm; }` — stored elevation geometry for shelf-hosted devices.

**Ruling — elevation geometry is derived, with one exception that is not geometry.**
A device's X/Y in the elevation is a pure function of `(Placement, rail geometry, face)` and is
never persisted. Lateral position on a **shelf** is genuine user intent and is stored — but as
an ordinal (`ShelfPlacement.order: FracIndex`) plus an optional `lateralOffset: Len?` for the
free-position case, not as a screen coordinate. See CR-035.

### CR-007 · Canvas boundary units

- **design-architecture.md §6.6:** "geometry coordinates are **document units (hundredths-mm,
  as doubles at this boundary)**."
- **design-pdf-export.md §6.1:** "**Unit convention: 1 diagram unit = 1 PDF point = 1/72 in.**
  Zero conversion on export."

**Ruling — 1 diagram unit = 1 PDF point = 1/72 in, `double` at the canvas boundary.**
This is not a breach of "no doubles": the model stores integers and the `DiagramScene` is a
transient rendering artifact that is never persisted. Conversion from `Len(nm)` to points
happens in exactly one function in the scene builder. `design-architecture.md §6.6`'s
hundredths-mm boundary is deleted, as is its dependency on CR-001's rejected unit.

---

## 1.2 The wiring entity model

### CR-008 · `Connection` vs `Link` + `Net` + `Conductor` + `SignalRoute` — four namings

- **design-data-model.md §0:** "'Connection' is three different things in this domain and
  conflating them is the single most expensive mistake available here."
- **design-ux-schematic.md §0.1:** "The document stores **connectivity only**:
  `Connection(uuid, fromPortRef, toPortRef, domain, media, label, layerId, sheetId,
  routeOverrides?)`."
- **design-architecture.md §1.2:** "`connection.dart # Connection: fromPort, toPort,
  cableType, length`."
- **design-pdf-export.md §10:** "`model/ … PhysicalLink, LogicalSignal, CableType`."

**Ruling — `design-data-model.md` wins on structure; its names are canonical.** The entity set
is `Link` (one physical cable) → `Service` (one signal carried on it, new — see CR-010) →
`Conductor` (one electrical path) and `Net` (one stored logical equivalence class).
The word **`Connection` is banned** from code, file format, and prose. `PhysicalLink`,
`LogicalSignal`, and `CableType` are deleted. `connection.dart` becomes `link.dart`; the
commands become `AddLink`/`RemoveLink`/`RetypeLink`. `SignalRoute` is deferred (AC-011).

### CR-009 · `Link` has no `signalFamily`, and the flagship rule reads one

- **design-data-model.md §3.6:** "`Link.signalFamily = video.hdbaset`, `media =
  media.cat6a_futp`."
- **design-data-model.md §2.9:** the `Link` class declares `media`, `cableSpecId`, `gaugeAwg`,
  `jacket` — **no `signalFamily`**; the family lives on `Net`.

**Ruling — the family lives on `Service`, and `SIG-001`/`SIG-002` evaluate per-service.**
`Link.dominantSignalFamily` is a derived value used only for line colour. `Net.signalFamily`
remains. This is the same field that CR-010 needs, so both are resolved by one change.

### CR-010 · One cable, one service — contradicted by the trade

- **design-data-model.md §2.9:** `Link` carries a single `media`; its `Net` a single
  `signalFamily`; `Conductor` has `role` and `pairNumber` but no family.
- **design-ux-device-builder.md §6.5:** a drop has one `Service` column, one value.
- **critique-domain-realism.md M6:** "One Cat5e … carries, on separate pairs: an IR emitter
  run, a 12 V trigger, and an RS-232 to the display. This is completely routine."

**Ruling — a `Link` carries `List<Service>`.**

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

- **design-data-model.md §3.6:** "`Net` is **stored, not derived** … **Rejected — derived-only
  nets (union-find over links at read time).** Tempting and wrong."
- **design-ux-schematic.md §1.6:** "Bus entries are **purely graphical and establish no
  connectivity** — membership is carried by **net name**."

**Ruling — stored.** Membership is the foreign key `Service.netId`. Name-carried membership is
precisely the KiCad failure that `design-ux-schematic.md §1.5` itself indicts ("typos can
prevent signals from being connected"); a GUI tool with a device library has no excuse for it.
Net *names* remain generated from a template and are never load-bearing. Bus rendering stays
purely graphical. Union-find is used only to *propose* merges, which a command then applies.

### CR-012 · Route geometry: persisted or forbidden

- **design-ux-schematic.md §0.1:** "**No wire coordinates. No route geometry.** … If you ever
  find yourself persisting a polyline, you have made an architectural error." — then §2.3
  ships waypoints, pinned routes, and `routeOverrides?`.
- **design-data-model.md §2.9:** `Map<Uuid, List<Pt>> waypointsBySheet; // manual orthogonal
  routing per sheet`.

**Ruling — no route geometry is persisted in v1.** The router is a pure deterministic function
of the model. `Link.waypointsBySheet`, `routeOverrides`, and `RouteWaypoint` are removed.
`design-ux-schematic.md` is right in principle and self-contradictory in fact. When manual
rerouting returns (v1.2) it is stored as **constraints** — an ordered list of grid points that
the router must pass through — under a field named `routeConstraintsBySheet`, never as a
polyline. **Symbol placement is persisted** (it is user intent); wire geometry is not.

### CR-013 · The router: obstacle-avoiding pathfinder or channel router

- **design-architecture.md §5.2:** `RouteCache` with an `ObstacleField`, per-connection
  incremental invalidation, "`router.dart # orthogonal trace router, obstacle-aware`",
  "~15–40 ms cold."
- **design-ux-schematic.md §2.6/§3.1:** "**Do not build incremental-reroute machinery in v1.**
  A full deterministic recompute is both cheaper than the invalidation bookkeeping and
  perfectly stable." / "RackMate **never needs a general orthogonal router**."

**Ruling — Sugiyama layering + interval-graph channel routing, full deterministic recompute.**
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

**Ruling — relaxed to the conductor.** Each **`Conductor`** spans exactly two endpoints; a
`Link` may reference up to N devices. `Link.breakouts: List<Breakout{label, atLengthFraction}>`
describes fan-outs for the schedule. I-25 is rewritten accordingly.

### CR-015 · Adapters: embedded value or real device

- **design-data-model.md §2.9/§3.5:** `InlineAdapter` is a value object inside
  `Link.inlineAdapters` with `satisfiesRuleIds`; "`CON-001` and `ELE-002` are both satisfied by
  data, not by acknowledgement."
- **design-ux-schematic.md §2.2:** "**Adapters as first-class objects.** … these are
  `ruHeight: 0`, `mountLocation: not-in-rack` passive **devices**. They appear in the netlist
  and the BOM."

**Ruling — both, split on whether the adapter has its own terminations.**
A **passive in-line adapter** with no independent cable on either side (barrel, gender changer,
null-modem shell, RCA→XLR transformer on a pigtail) is an `InlineAdapter` value on the Link.
An **active or two-cable device** (HDBaseT TX/RX pair, balun pair, RF splitter, IR connecting
block, DA) is a real `DeviceInstance` with `mountMethod: notInRack` and two or more Links.
The test is mechanical: *does an installer pull two separate cables to it?* If yes, it is a
device. `design-data-model.md` is already inconsistent here — it models RF splitters and IR
blocks as devices — and this rule resolves it. The `SIG-001` remedy
`[ Insert HDBaseT receiver ]` therefore inserts a device, correctly.

### CR-016 · "Bundle" means three different things

- **design-ux-schematic.md §1.6:** "**Bundle (snake)** — a *purely organisational* grouping of
  **physical runs** that share a conduit … `B03 · 4 runs · 40'`."
- **design-ux-device-builder.md §6.6:** `Bundle { … members: [dropId] }` — members are drops.
- **design-data-model.md §2.8:** `StructureBundle` — "One **OUTLET LOCATION**. The atomic unit
  of creation, specification and pricing."

**Ruling — two entities, two names, neither called "Bundle" alone.**

- **`Outlet`** (renamed from `StructureBundle`) — one wall plate / one ceiling location. Owns
  designation, room, mounting, and the set of Links home-running to it. The
  creation/specification/pricing atom. `design-data-model.md`'s argument for it is correct.
- **`Pathway`** (absorbing "bundle/snake" and `conduitId`/`pathwayId`) — a conduit, J-hook
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
- **design-ux-schematic.md §2.2:** "**Class A — hard-invalid. Refused at drag time. Cannot
  exist in the document.**" — including HDBaseT→switch, IR emitter→receiver, connector
  mismatch, Dante with no network path, AVB across a non-TSN switch.
- **design-ux-rack.md §3.2:** placement checks 1–4 and 6–7 "**block**" the drop.

**Ruling — `design-data-model.md` wins, with one precise concession.** The binding distinction
is:

> **The gesture may hesitate. The document may not lie.**

- **Model-level illegality** — only `TOP-001..005` (self-connection, duplicate ordered pair on
  one link, over `maxConnections`, dangling endpoint, container cycle) plus placement
  coherence (`ruIndex` within the rack; host is a container; no containment cycle). These are
  states in which the model means nothing, not states the world disallows.
- **Gesture-level refusal** — `design-ux-schematic.md`'s Class A becomes *spring-back with a
  reason chip*, and every chip carries `[ Connect anyway ]` next to its remedies. The remedy
  chips are excellent and are kept exactly as designed; only the finality goes.
- Two of Class A's members — "Dante endpoints with no network path" and "AVB traversing a
  non-AVB switch" — are **logically unevaluatable at drag time**, because the link being drawn
  may be the one that completes the path. They are demoted to post-hoc findings unconditionally.
- The rack editor's blocking drop checks are demoted to warnings **except** RU-range-free
  (physical impossibility on the same face) and fits-within-rack-extent.

### CR-018 · Severity vocabulary — three of them

- **design-data-model.md §2.10:** `error | warning | advisory | off`, plus an *acknowledged*
  state.
- **design-ux-rack.md §5.2:** `Error | Warning | Info`.
- **design-ux-schematic.md §2.2:** `error | warn | info` plus Class A.

**Ruling — `error | warning | advisory | off`.** "Info" is renamed `advisory` everywhere.
Class A is deleted per CR-017. Severity is a property of the rule *in this project*, settable
per rule; the shipped default is the catalogue value.

### CR-019 · Three dismissal mechanisms

- **design-data-model.md §3.5:** acknowledge a Finding with a written reason; it demotes and
  "the reason **PRINTS** in the schedule."
- **design-ux-rack.md §5.2:** "Warnings are dismissible per-instance with a required reason
  note … **Errors are not dismissible.**"
- **design-ux-schematic.md §6.3:** "Rules can be **muted per-project** with a required
  justification note."

**Ruling — one mechanism: `AckedFinding`, at two scopes.** An acknowledgement carries
`{ruleId, targetFingerprint, reason (required), by, at, demotedTo}`. `targetFingerprint == "*"`
means project-wide mute of that rule. **Errors are acknowledgeable**; refusing to let a
professional override the tool's opinion about their own system is how the tool gets abandoned.
`ProjectSettings.ruleSeverityOverrides: Map<String, Severity>` is deleted — it has no field for
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
| Hosted depth > shelf depth | `RCK-010` error | Warning | **advisory** | "Overhang is common and survivable" — ux-rack is right. |
| Centre of gravity | `RCK-004` warning @50% | Info @55% | **advisory @55%, default off** for wall/credenza form factors | `critique-domain-realism.md m19`. |
| Spare RU | `RCK-008` advisory <15% | Info outside 15–25% | **advisory, default off** | A planning opinion, not a fact. |
| Σ continuous amps > 80% breaker | `PWR-001` error | warn | **warning**, on typical × diversity | AC-018. |
| Duplicate device designator | I-12 load warning | Error, "enforced not suggested" | **error finding, non-blocking**; allocator prevents creation; import offers one-click renumber | Both are right about different moments. |

### CR-021 · Rules that exist in only one document

- **design-ux-rack.md §5.2** adds, with no IDs: "Device with no power source", "Unplaced devices
  in Staging Bin", "Wall rack over 80% weight", "Heat source with no vent above".
- **design-ux-schematic.md §2.2** adds: "unconnected port on a placed device", "orphan device".

**Ruling — adopted into the one catalogue with IDs**, at these severities:
`PWR-006` device with power draw and no outlet assignment — **warning**;
`RCK-014` unplaced devices present — **advisory**;
`RCK-003b` wall-mount rack over 80% of capacity — **warning** (wall racks are the documented
failure mode);
`RCK-007` heat source with no vent above — **advisory**, gated on `Rack.formFactor` (AC-034);
`TOP-010` unconnected port on a placed device — **advisory, default off**;
`TOP-011` device with zero connections — **advisory**.
There is exactly one rule catalogue, in `docs/rules.md`, and a rule that is not in it does not
exist.

### CR-022 · `blockExportOnErrors`

- **design-data-model.md §2.1:** `bool blockExportOnErrors; // default true`.
- **design-ux-simplicity.md** and **critique-domain-realism.md B3** both identify this as
  producing a permanently unexportable project.

**Ruling — the setting is deleted.** Replaced by `ExportSpec.issuedForConstruction: bool`.
Errors block only the *"ISSUED FOR CONSTRUCTION"* stamp and the revision-block `issued` flag;
they never block bytes. Every export emits sheet **`T0.02 — Exceptions & Acknowledgements`**
listing open findings and every acknowledgement with its reason, author and date. This
simultaneously discharges the promise made by three documents that acknowledgement reasons
"print in the appendix" — a sheet that appeared in no sheet list (G3).

### CR-023 · The legend-note invariant blocks export

- **design-data-model.md I-41:** "**Every sheet with `carriesLegend == false` has a non-empty
  `legendLocationNote`.** … **Blocks PDF export.**"

**Ruling — deleted as an invariant; implemented as an export-time auto-fill.** The exporter
knows which sheet carries the legend, so it writes `SYMBOL LEGEND: SEE SHEET T0.01` into every
other sheet's title block itself. There is nothing for the user to get wrong and therefore
nothing to validate. A drafting footnote must never gate a deliverable (G3).

### CR-024 · Rules as data or as code

- **design-data-model.md §2.10/§3.4:** "Compatibility rules live as **DATA** so a new adapter
  case does not need a release." `RulePredicate predicate; // declarative AST,
  JSON-serializable`. Argued as a central reason to reject enums.
- No document designs a rule-authoring or rule-inspection UI.

**Ruling — rules are Dart functions; the *catalogue* is data.** Accepted from
`critique-feasibility.md #6` — see AC-006 for the full reasoning and the surviving data layer.
The claim that users can author rules is **withdrawn** from all documents. The
connector×signal-family **compatibility matrix** genuinely is a lookup table and stays data.

---

## 1.4 The rack model

### CR-025 · RU origin — 0-based or 1-based

- **design-data-model.md §2.4:** "`ruIndex` — **1-based**, BOTTOM origin, always."
- **design-ux-rack.md (appendix):** "`bottomU` — **0-based** from the rack's physical bottom."

**Ruling — 1-based, bottom origin.** `ruIndex ∈ [1, heightU]`. The stored value equals the
printed value under the default bottom-up numbering, which deletes an entire class of
off-by-one between the elevation and the schedule. `bottomU` is renamed `ruIndex` and rebased
throughout `design-ux-rack.md`. This is the contradiction `critique-domain-realism.md` singles
out as "the one that will actually hurt", and it is asserted at load.

### CR-026 · RU numbering direction — project or rack setting

- **design-data-model.md §2.1:** `ProjectSettings.ruNumbering // bottomUpFromOne | topDown`.
- **design-ux-rack.md §2.1:** "the setting is **on the rack, not the app**, because a project
  can legitimately mix (a retrofit rack labelled by the previous integrator)."

**Ruling — per-rack, with a project default.** `Rack.ruNumbering` is authoritative;
`ProjectSettings.defaultRuNumbering` seeds new racks. The retrofit argument is decisive and the
field costs one enum. Numbering is **display only** and never affects `ruIndex` (CR-025).

### CR-027 · Ordering type — fractional index or integer

- **design-data-model.md §5.2:** "**No positional index is ever identity** … An integer
  `sortOrder` requires renumbering neighbours, and neighbour-renumbering is precisely the
  operation that makes sync impossible to retrofit."
- **design-ux-rack.md (appendix):** `int bayOrder`.
- **design-ux-device-builder.md §3.2:** `"order": 0` on ports and banks.

**Ruling — `FracIndex` everywhere in the persisted model**, including `.rmdev`. `bayOrder` and
every integer `order` are replaced. This is a G5 item: retrofitting fractional indices is a
migration touching every entity in the file.

### CR-028 · Circuits — project entity or rack child

- **design-data-model.md §2.1:** `Map<Uuid, Circuit> circuits` flat on the project;
  `Port.circuitId` on power inlets.
- **design-ux-rack.md §5.1/appendix:** "**Circuits are first-class objects on the rack.**" /
  `class Rack { … List<Circuit> circuits; }`.

**Ruling — flat `Map<Uuid, Circuit>` on the document, with `Circuit.rackId?`.** The rack
inspector renders circuits filtered by `rackId` — `design-ux-rack.md` gets its UX without the
nested list that `design-data-model.md §5.1` forbids. **One assignment chain:** circuit
membership is *derived* by walking power Links (device inlet → PDU outlet → PDU inlet →
circuit). `Port.circuitId` survives only on the ports where the rack meets the building — PDU
and UPS inlets, and hardwired devices. The "Unassigned" bucket is computed, not an entity.

### CR-029 · Shelf containment direction

- **design-data-model.md §2.4/§2.7:** child→parent (`ShelfPlacement.hostDeviceId`,
  `DeviceInstance.hostDeviceId`).
- **design-ux-rack.md §6.1:** `class ShelfOccupant { List<HostedDevice> hosts; }` — parent owns
  an ordered list.

**Ruling — child→parent only.** `ShelfPlacement{hostDeviceId, order: FracIndex,
lateralOffset: Len?}`. The parent never owns a list; `shelf.hosts` is a derived view sorted by
`order`. A parent-owned array is both a second source of truth and positional identity, which
`design-data-model.md §5.1/§5.2` forbid by name. `DeviceInstance.hostDeviceId` is deleted as
redundant with the placement variant.

### CR-030 · Half-rack lateral placement — supported or blocked

- **design-data-model.md §2.4:** `RailPlacement{startTwelfth 0..11, spanTwelfths 1..12}`, with
  "Two half-rack devices sharing 1U = {0,6} and {6,6}" as a worked example, plus I-19 and
  `RCK-011`.
- **design-ux-rack.md §3.2 check 7:** blocks the drop — "`Half-rack: needs an ear kit or a
  shelf`."

**Ruling — twelfths stay in the format; the v1 editor exposes three positions.** Retrofitting a
lateral axis into `Placement` is a migration touching every device, so the field ships (G5).
The v1 UI offers a `Width position` control with `Full (0,12) | Left half (0,6) | Right half
(6,6)` — a dropdown, not a drag interaction. A half-rack device dropped alone is **allowed**
and files an advisory naming the ear kit. Free lateral dragging is v1.2.

### CR-031 · `Placement` shape

- **design-data-model.md §2.4:** a sealed union of five variants.
- **design-ux-rack.md (appendix):** one flat class with nullable fields and
  `String? rackId; // null => Staging Bin`.

**Ruling — the sealed union, extended to carry what `design-ux-rack.md` actually needs:**

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
- **design-data-model.md:** only `UnplacedPlacement { Pt? schematicHint }` — no `lastRackId`,
  no `lastBottomU`, so "Return to Rack A U21" is unimplementable as specified.

**Ruling — the Staging Bin *is* `StagedPlacement`** (CR-031). It is a query, not an entity:
`devices.where((d) => d.placement is StagedPlacement)`. It ships in v1 with the return
affordance and `RCK-014` (CR-021).

### CR-033 · Bays are unmodelled

- **design-ux-rack.md §2.4:** "select 2+ adjacent racks → `Group as bay`. A bay draws shared
  side rails, a bracket above with the bay name, and rolls up vitals."
- No entity exists in any other document.

**Ruling — cut from v1, not reserved.** A bay is purely organisational and nothing depends on
it. When it returns it is `Bay{id, name, order, rackIds}` — a pure addition under the
additive-only rule, requiring no migration.

### CR-034 · Lock is unmodelled

- **design-ux-rack.md §3.7/§7.3/§8:** `Ctrl+L` lock/unlock, a 🔒 badge, `placement.locked`,
  auto-arrange treating locks as anchors, `refDesLocked`, "Include manually-locked designators
  (3)" in the renumber dialog.
- **design-data-model.md:** no lock field on any entity.

**Ruling — three lock flags ship in v1.** `Placement.locked` (CR-031),
`DeviceInstance.designatorLocked`, and `Link.designatorLocked` — the last auto-set when
`RoughInStatus >= pulled`, per `critique-domain-realism.md m22`: once sixty cables are
physically labelled, an accidental renumber is a day of relabelling. Renumber refuses locked
IDs by default and says how many it skipped.

### CR-035 · `mirrorRearElevation` is unmodelled, and its scope is self-contradictory

- **design-ux-rack.md §2.3:** "A **per-project** setting `mirrorRearElevation` (default
  `true`)."
- **design-ux-rack.md §4.1 and appendix:** the same field inside the *rack* inspector and on
  `class Rack`.
- **design-data-model.md:** neither.

**Ruling — per-rack (`Rack.mirrorRearElevation`, default true), with a project default.** Same
resolution as CR-026 and for the same reason. The `NOT MIRRORED` chip in the rack header when
it is off is retained — a drawing must never lie about itself.

### CR-036 · The occupancy struct

- **design-data-model.md §2.5:** `TemplateBody{frontU, rearU, side: OccupancySide, …}` with
  depth and weight as sibling fields.
- **design-ux-rack.md §6:** `class Occupancy { frontU, rearU, MountSide side, depthTenthMm,
  weightGrams }` — different enum name, depth and weight folded in.
- **design-ux-device-builder.md §1.3:** matches data-model's shape but its `side` enum is
  `front · rear · both · zeroU_vertical` — missing `none`, different casing.

**Ruling — `design-data-model.md`'s shape and spelling.**
`OccupancySide { front, rear, both, zeroUVertical, none }`. Depth and weight stay siblings on
`TemplateBody`: they are per-model physical facts with their own override semantics, and
folding them into an occupancy struct implies they vary with mounting, which they do not.

### CR-037 · Rail-type enum

- **design-data-model.md §2.3:** `tapped10_32 | tapped12_24 | squareCageNut | roundClearance |
  m6`.
- **design-ux-rack.md §2.1:** `tapped10-32 | tapped12-24 | square | clearance` — different
  spelling, `m6` missing.

**Ruling — `design-data-model.md`'s five values and spelling.** Rail type affects hole
rendering and the hardware line in the materials list; it never gates placement.

### CR-038 · Maximum rack height

- **design-ux-rack.md §4.2:** "range 1–58."
- **design-architecture.md §10.1:** "RU per rack: target 45, hard cap 60."
- **design-data-model.md:** unbounded.

**Ruling — `heightU ∈ [1, 60]`**, asserted as an invariant, with an advisory above 50. 58U and
60U products both exist; 60 is the honest cap and matches the performance envelope.

### CR-039 · Three sources of truth for voltage

- **design-data-model.md:** `PowerProfile.nominalVolts` (template) and `Circuit.volts`.
- **design-ux-rack.md (appendix):** `Rack.lineVoltage; // 120 | 230 | 240`.

**Ruling — `Circuit.volts` is authoritative downstream of a circuit.**
`PowerProfile.nominalVolts` is the device's *rated* input and is used only for a compatibility
check. `Rack.lineVoltage` is **deleted**; it was only ever a default for creating circuits, so
it becomes `ProjectSettings.defaultLineVolts`.

### CR-040 · `Rack.designator` vs `Rack.refDesPrefix`

- **design-data-model.md §2.3:** `String designator; // "RK-1" — must match schedule Location
  column`.
- **design-ux-rack.md (appendix):** `String refDesPrefix; // "R1"`, used for per-rack
  designator scoping (`R1-AMP-1`).

**Ruling — `Rack.designator` only.** Per-rack designator scoping composes from
`Rack.designator` directly (`RK-1-AMP-1`, or `RK1-AMP-1` when the separator setting is empty).
`refDesPrefix` is deleted; two identifiers for one rack is exactly the failure the schedule
exists to prevent.

---

## 1.5 Identifiers, designators, and the format engine

### CR-041 · Device designator format — three renderings

- **design-data-model.md §2.1:** `"{typePrefix}-{seq:2}" → "MTX-01"`; the JSON example uses
  `MTX-01`, `SW-01`, `STR-01`.
- **design-ux-rack.md §7.2** and **design-ux-device-builder.md §1.2:** `{prefix}-{n}` →
  `AMP-1`, `MTX-1`.
- **design-ux-schematic.md §1.2** and every wireframe: `MTX1`, `AMP2`, `SW1`, `AVR1`.

**Ruling — `{TYPE_PREFIX}{SEP}{SEQ}`, default separator `-`, default pad 0.** Ships as
`MTX-1`, `AMP-12`. `ProjectSettings.designatorSeparator` (may be empty, giving `MTX1`) and
`designatorPad` (giving `MTX-01`) cover both other renderings as project preferences. The
designator is **stored once at allocation** and never re-derived at render time; sorting is
natural-order (`AMP-2` before `AMP-10`).

### CR-042 · Port designator — template-owned or project-computed

- **design-data-model.md §2.1/§3.9:** `portDesignatorFormat "J{devSeq:2}{portSeq:2}" →
  "J2301"`, unique **project-wide**, with `designatorBlockSize: 100` reserve blocks.
- **design-ux-device-builder.md §2.5/§3.2:** `Designator` is a **template grid column**, "auto
  until manually edited"; `.rmdev` ships `"designator": "J1"`.
- **design-ux-schematic.md §1.3:** `J01`, `J09`, `J17` — two digits, per device.

**Ruling — template supplies a hint; the project allocates; uniqueness is per device.**
`PortDef.designatorHint` is a seed only. `Port.designator` is allocated at instantiation from
`ProjectSettings.portDesignatorFormat`, default **`J{PORT_SEQ:2}` → `J01`** — matching every
schematic wireframe and ASME practice. A port is always cited as `MTX-1:J09`, so project-wide
uniqueness buys nothing and reads as bizarre on a residential job. The AV block scheme
(`{DEV_BLOCK}{PORT_SEQ:2}` → `2301`) ships as a preset for commercial work; reserve-block
allocation works identically at either scope. I-12 is corrected to *unique within device*.

### CR-043 · The `STR` prefix collides in shipped data

- **design-ux-rack.md §7.2** seed prefixes: "`STR` structure."
- **design-ux-device-builder.md §7.5** catalog A06: "Multi-Zone Streaming Source — `STR`."

**Ruling — the streaming source becomes `STRM`.** Structure keeps `STR`. A CI test asserts
that no two catalog templates share a `typePrefix` with a system prefix.

### CR-044 · Structure drop labels

- **design-data-model.md §2.8:** `fieldLabel` (required, unique) + `rackLabel` (nullable,
  unique when set); formats `{type}-{room}-{dir}-{seq}` and `{floor}{space}-{panel}{port}`.
- **design-ux-device-builder.md §6.5/§6.8:** columns `Label` + `TIA-606 ID`; "**Both**
  identifiers are generated for every drop"; default `{roomAbbr}-{service}-{seq}` → `LR-TV-1`.

**Ruling — `fieldLabel` (required, project-unique) + `rackLabel` (optional, project-unique when
set).** The device-builder's `Label` column *is* `fieldLabel`; its `TIA-606 ID` column *is*
`rackLabel`. Both are generated from templates, both are editable, **both always print** — this
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

**Ruling — one grammar, one registry, one parser: `design-pdf-export.md §3.2`'s.**
It is the only formally specified one and the only one with optional segments (`[...]`), zero
padding (`:n`), and filters (`|upper`, `|first n`, `|nz`) — all of which the other three need
and none of which they define. Token names are **UPPER_SNAKE**. The three vocabularies merge;
collisions resolve to the longer, unambiguous name (`{ROOM}` and `{ROOM_ABBR}`, not `{abbr}`).
`{{` and `}}` are literal braces. `CollisionPolicy{suffixLetter | suffixNumber | error}` is
project-wide. Lives in `rackmate_core/idformat/`; five call sites (device, port, link, drop
field label, drop rack label) share it.

### CR-046 · `Location.code` vs `abbr`

- **design-data-model.md §2.2:** `String code; // "MBR"`.
- **design-ux-device-builder.md §6.2:** "an editable `abbr` (Living Room → `LR`)".

**Ruling — `Location.code`.** One field, one name; `{ROOM_ABBR}` is the token that reads it.

### CR-047 · Location vocabulary shape — tree, fixed 4-level, or flat list

- **design-data-model.md §2.2:** arbitrary-depth tree with
  `LocationKind{site, building, floor, room, zone, outdoor}`.
- **design-ux-device-builder.md §6.2:** fixed `Site → Building → Floor → Room → Outlet`.
- **design-ux-rack.md §7.5:** a **flat list** — "`Locations: Basement, Media Closet, Living
  Room…`" with inline creation.

**Ruling — one arbitrary-depth tree; the other two are views of it.** The device-builder's
four levels are the tree with `kind` filtering; the rack editor's combobox is the same tree
flattened to breadcrumb strings (`Level 1 › Living Room`) with inline creation that appends to
the currently-selected parent. `Outlet` is **not** a location level — it is the `Outlet` entity
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

**Ruling — `design-pdf-export.md` P5 is a governing principle and is adopted verbatim.**
Every designator — device, port, link, drop — is evaluated once at creation and stored. Nothing
is recomputed at render time. Changing a scheme offers a renumber with a diff; it never
silently renumbers, and it never touches a locked ID (CR-034).

### CR-049 · Net names: generated or typed

- **design-ux-schematic.md §1.5:** "**Net names are generated, never typed.**"
- **design-data-model.md §2.9:** `Net.name` is a free string the user may set, and
  `Net.designator` is `N012`.

**Ruling — generated by default, editable, never load-bearing.** `Net.name` is auto-filled from
`ProjectSettings.netNameFormat` and may be overridden; membership is always the FK (CR-011), so
a typo is cosmetic. Q-SYS's rule is adopted: duplicate *source* names prohibited, duplicate
*destination* names permitted.

---

## 1.6 Templates and the library

### CR-050 · Template version type — integer or semver

- **design-data-model.md §2.5:** `int version; // monotonic; every edit forks a new version`;
  snapshots keyed `"$templateId@$version"`; `TemplateRef{templateId, version: int,
  contentHash}`.
- **design-ux-device-builder.md §1.2/§4.2:** `version: {major, minor, patch}`, "computed from
  the diff, not chosen by the user"; `derivedFrom: {templateId, version: "1.0.0"}`.

**Ruling — `int version`, monotonic.** A semver whose components are *computed* adds a
vocabulary without adding a capability, and `TemplateRef` cannot hold one. The change class
(safe / additive / breaking) is still computed from the diff and **displayed prominently** —
it is genuinely useful — but it is not encoded in the version number.

### CR-051 · The template migration join key — `PortKey` or `portId`

- **design-data-model.md §3.3:** "`PortDef.key` — STABLE, author-assigned … This is the **ONLY**
  thing that makes connections survive a template revision", with `renamedFrom` aliases.
- **design-ux-device-builder.md §3.2/§5.3:** "**`portId` is the join key**, not label or index.
  `portId` UUIDs are generated once and preserved across every version."

**Ruling — `PortKey` string plus `renamedFrom`.** A UUID cannot express *"this port was renamed
from that one"*, which is the exact case the mechanism exists for; and a stable, readable string
key is diffable in the `.rmdev` file, which is a stated product differentiator that a UUID
destroys. `.rmdev` gains `key` and `renamedFrom` and loses `portId`. Distinguish the three
identities, which remain three (`design-data-model.md §3.3` is right about this):
`Port.id` (UUID, project graph identity, what `Conductor` references) ·
`PortDef.key` (template identity, the migration join) ·
`Port.designator` / `userLabel` (human identity, what is printed).

### CR-052 · Removed-port outcome on template migration

- **design-data-model.md §3.3 step 5:** "if the Port has no Conductors → delete. else → set
  `orphaned = true`. **DO NOT DELETE. DO NOT DELETE THE LINK.** … **Rejected — deleting
  orphaned ports and their links.** Data loss on a routine operation."
- **design-ux-device-builder.md §5.3:** per affected cable, `[ Remap ▾ ] [ Keep ] [ Del ]` —
  one click, no confirm.

**Ruling — orphan, never delete.** The Update Manager's per-cable choices are
`[ Remap ▾ ]` and `[ Keep as orphan ]`. **`[ Del ]` is removed.** A user who wants a cable gone
deletes it explicitly through the normal delete path, with its normal confirm and its normal
undo entry. Presenting destructive and non-destructive options as equal-weight one-click
siblings during a routine maintenance operation is how tools lose data.

### CR-053 · Override key namespace

- **design-data-model.md §3.2:** dotted paths into `TemplateBody` — `"weight"`,
  `"power.nameplateWatts"`, `"bodyDepth"`.
- **design-ux-device-builder.md §5.1:** `"identity.name"`, `"physical.weightKg"`,
  `"ports.<portId>.label"` — paths into the `.rmdev` *file* shape, and port overrides stored on
  the **device**.

**Ruling — neither. Typed `DeviceOverrides` and `PortOverrides` classes.** See AC-012 for the
full argument. Port overrides live on `Port` (keyed by port), never in the device's map — a
device-keyed map of port overrides re-introduces the composite-key identity the model bans.
`.rmdev`'s `identity.` / `physical.` / `power.` sections are a **file layout only**; the codec
flattens them onto `TemplateBody`.

### CR-054 · Detach mechanism — two doors, four verbs, three snapshot stores

- **design-data-model.md §3.1:** "the UI presents **exactly two doors** … **There is no third
  door.**" Plus `DeviceInstance.localTemplate` for per-instance forks, and I-9: `templateRef`
  resolves **or** `localTemplate` is non-null, "Never neither."
- **design-ux-device-builder.md §5.2:** **four** verbs, including "Detach instance
  (`templateRef → null`)", with the instance carrying its own `snapshot`.

**Ruling — three doors, one snapshot store.**

| Door | Effect |
|---|---|
| **Edit this device only** | writes `DeviceOverrides`; template untouched |
| **Edit the template** | forks `version+1` in the library; placed instances untouched until opted in |
| **Fork to a new template** | new `templateId`, seeded from snapshot + overrides, this instance rebinds, overrides cleared, `derivedFrom` recorded |

The fourth verb ("Detach instance", `templateRef → null`) is **deleted** — it produces a device
with no lineage, and door 3 covers the case with better provenance.
`DeviceInstance.localTemplate` and `PlacedDevice.snapshot` are both **deleted**: snapshots live
in exactly one place, `RackDocument.templates` keyed `"$templateId@$version"`. I-9 simplifies to
"`templateRef` always resolves to an embedded snapshot."

### CR-055 · Port banks are unmodelled

- **design-ux-device-builder.md §3.2:** a first-class `banks[]` array
  (`bankId, name, abbr, symbolSide, collapseInSymbol, order`).
- **design-ux-schematic.md §1.2:** the entire symbol layout is built on banks — edge
  assignment, brackets, folding, vector pins.
- **design-data-model.md:** only `PortGroupDef` — an *electrical* grouping (component video,
  speaker pair, `atomicConnect`). A different concept; `symbolSide` has no field.

**Ruling — model both, and stop the name collision.**
`TemplateBody.banks: List<BankDef{key, label, abbr, symbolSide, collapseInSymbol, order}>` with
`PortDef.bankKey` — a **presentation** grouping.
`PortGroupDef` is renamed **`PortSetDef`** — an **electrical** grouping (Y/Pb/Pr, L/R, +/−,
`atomicConnect`). Both ship in v1: banks drive the symbol and the auto panel layout; sets drive
atomic connect and the conductor roles of CR-010.

### CR-056 · `poeBudgetWatts` has no home, and the power model is short two fields

- **design-data-model.md §4.5:** the JSON example carries `"poeBudgetWatts": 370` as an
  **undeclared key**; `PowerProfile` has no such field, yet `NET-001` (an error) requires it.
- Neither `PowerProfile` nor `.rmdev` has apparent power or power factor, while
  `design-ux-rack.md §5.1` computes `amps = watts / 120`.

**Ruling — `PowerProfile` gains `poeBudgetWatts: int?`, `apparentVA: int?`, and
`powerFactor: int?` (permille).** Circuit loading is computed in **VA**; UPS capacity is checked
VA against VA. See AC-018 — a linear-supply amplifier at PF 0.65 under-reports current by 35%
on exactly the gear where it matters, which is the classic way to trip a breaker on a system
that "calculated fine".

### CR-057 · Passthrough pairing has no file format

- **design-data-model.md §2.6:** `PassthroughPairDef{frontKey, rearKey, sameNet}` on the
  template, with invariant I-32.
- **design-ux-device-builder.md §2.5/§3.2:** a `Paired port` grid column and a "Pair front↔rear
  by order" action — and **no pair array in the `.rmdev` schema**.

**Ruling — `.rmdev` gains `passthroughPairs: [{frontKey, rearKey, sameNet}]`.** The grid column
and the pairing action write it. The catalog's patch panels are re-authored against it. A
passthrough template whose pairs are missing is a load warning, not an error.

### CR-058 · Two incompatible vocabulary namespaces

- **design-data-model.md §3.4:** reverse-hierarchical namespaced IDs — `conn.rj45`,
  `video.hdmi.2_0`, `net.ethernet`, `power.ac_120`.
- **design-ux-device-builder.md §7:** flat bare names — `HDMI-A`, `RJ45`, `hdmi20`, `ethernet`,
  `ac-inlet` — across the largest vocabulary in the project (~35 connectors, ~45 families).
  Note `ac-inlet` is used as a *signal family* where the data model has family `power.ac_120` +
  `PortPowerSpec.role: inlet`.

**Ruling — namespaced IDs are canonical; the bare names become registry aliases.**
`ConnectorTypeDef.aliases: List<String>` and `SignalFamilyDef.aliases` hold `HDMI-A`, `hdbt`,
`rj45`, `xlr`, `spdif` and friends; the Quick Add DSL resolves against them. This gives the DSL
its ergonomics and the file format its namespacing and forward compatibility, and it is what
makes `.rmdev → .rackmate` import well-defined. `ac-inlet` is re-authored as
`power.ac_120` + `role: inlet` throughout the catalog.

### CR-059 · Gender enum is ambiguous, and a shipped rule is broken by it

- **design-data-model.md §2.6:** `male | female | genderless | jack | plug` — five values
  containing two synonym pairs.
- **design-ux-schematic.md §1.3:** "**filled = female/jack, hollow = male/plug**" — treats them
  as synonyms.
- Consequence: `CON-002` ("genders both male or both female") never fires for `jack`+`jack`.

**Ruling — three values: `male | female | genderless`.** `jack` and `plug` are deleted; a jack
is a female panel connector and a plug is male. `ConnectorTypeDef.genderApplies: bool` decides
whether `CON-002` evaluates and whether the glyph fill encodes gender — which is what
`design-ux-schematic.md` actually wanted when it restricted gender encoding to XLR, IEC, DB9,
SpeakON and fibre. Fixes a concrete bug in a shipped rule.

### CR-060 · Direction encoding

- **design-data-model.md §2.6:** `source | sink | bidirectional | busNode | passive`.
- **design-ux-device-builder.md §2.5/§7:** grid values `In / Out / Bi / Bus / Passive`, but the
  catalog notation is `i/o/b/p` where **`p` means "passive/bus node"** — two enum values
  collapsed into one letter across the entire catalog.
- **design-ux-schematic.md §1.3:** adds "Power inlet" and "Power outlet" as directions.

**Ruling — five values, and the catalog notation gains a letter.** `i o b n p` where `n` =
`busNode` and `p` = `passive`. Every catalog entry using `p` is re-audited — the distinction is
load-bearing for `DIR-002`, `BUS-001`, `BUS-002` and the multi-drop stub glyph. "Power inlet"
and "power outlet" are **not directions**: they are `sink`/`source` on a `power.*` family with
`PortPowerSpec.role`.

### CR-061 · Catalog size — four numbers

- **design-ux-device-builder.md** title and §0: "**58 Templates**", "58-device seeded catalog".
- **design-ux-device-builder.md §7.9** summary table: "Total shipped templates | **62**".
- **design-architecture.md §1.2:** "the seeded **~40** templates".
- Brief: "~30-50" in prose, **~40–55** in the confirmed decisions.

**Ruling — v1 ships 48 templates: 30 rack-side and 18 field-side.** This sits mid-band in the
confirmed 40–55 and makes room for the field devices of AC-019 without growing the authoring
job. The count is stated in exactly one place — `docs/catalog.md` — and **no prose in any
document states a number**. The gate for shipping a template is AC-052: every numeric field has
a cited source.

### CR-062 · Seeded templates are read-only — the consequence is unstated

- **design-ux-device-builder.md §5.4:** "Seeded templates ship read-only. Editing one silently
  performs **Duplicate → edit the copy**."
- No document surfaces the consequence: a user who corrects a wrong wattage forks the template
  and permanently loses catalog corrections for that device.

**Ruling — the mechanism is correct; the consequence is surfaced.** A forked template records
`derivedFrom{templateId, version}`, and when the catalog later revises that source the fork
shows a passive badge: *"Based on catalog 'HDMI Matrix 8×8' v1 — the catalog version has since
been corrected (v3). Compare…"*. No action is forced. This costs one badge and one diff view
that already exists.

### CR-063 · `.rmdev` uses floating-point millimetres

- **design-ux-device-builder.md §3.2:** `"depthMm": 330`, `"weightKg": 7.3`, `"xMm": 24.0`.
- **design-data-model.md I-1:** "**No `double` appears anywhere in the persisted model.**"

**Ruling — `.rmdev` obeys I-1.** `depthNm`, `weightUg`, `xNm`. The template file is part of the
persisted model; there is no second unit regime.

---

## 1.7 Sheets, layers, and views

### CR-064 · Layers are entirely unmodelled

- **design-ux-schematic.md §4.2:** "User-defined named layers, each with `visible / locked /
  prints` flags … **Layers are a document concept and they do persist.**" `layerId` appears in
  the Connection definition, the connections table, Properties, the search language, and
  `sheetFilter`.
- **design-data-model.md:** no `Layer` entity and no `layerId` — only
  `DeviceStatus{existing, new, future, removed}`.

**Ruling — cut from v1; `LifecycleStatus` carries the v1 need.**
`LifecycleStatus{existing, new, future, removed}` is added to **both** `DeviceInstance` and
`Link` — the design-intent axis, orthogonal to `RoughInStatus` (the progress axis). That covers
the demolition/phasing rendering conventions every drawing set actually needs. User-named layers
with per-layer print flags are a commercial-retrofit feature; they return in v2 as a pure
addition. `layerId` is **not** reserved — the additive-only rule makes reservation unnecessary.

### CR-065 · Three status vocabularies under one column header

- `DeviceStatus{existing, new, future, removed}` (design-data-model.md §2.7).
- `RoughInStatus{planned, pulled, dressed, terminated, tested, issued}` (§2.8/§2.9).
- **design-ux-device-builder.md §6.5:** `{Planned, Pulled, Terminated, Tested, In use, Spare,
  Abandoned}` — drops two, adds three.
- **design-ux-schematic.md §6.1:** a connections-table `Status` column showing `✓`/`⚠` — which
  is **DRC state**, a fourth meaning under the same header.

**Ruling — two stored axes, one derived, and "Status" is never a bare column name.**

| Axis | Values | Where |
|---|---|---|
| `LifecycleStatus` | existing · new · future · removed | design intent; devices and links |
| `RoughInStatus` | planned · pulled · dressed · terminated · tested | field progress; links only |
| *(derived)* | in use · spare | computed from whether the link has both endpoints bound |

`issued` is deleted from `RoughInStatus` — it is a revision-block concept, not a cable state.
`Abandoned` maps to `LifecycleStatus.removed`. The DRC column is headed **`ISSUES`**, never
`Status`.

### CR-066 · Sheet numbering scheme

- **design-data-model.md I-40:** `Sheet.number` must match `^[A-Z]{1,2}\d\.\d{2}$` — NCS.
- **design-pdf-export.md §12 decision 1:** agrees — "NCS `T`-discipline numbering".
- **design-ux-schematic.md §1.7:** title block shows "`SHEET 2 of 6 · VIDEO`" and "`DRG
  SR-0247`" — no NCS numbers, and `DRG` has no model field.

**Ruling — `ProjectSettings.sheetNumbering: ncs | simple`, default `simple`.**
A residential drawing set is four to eight pages; failing validation on a naming convention
built for 200-sheet commercial construction documents is exactly the nannying that pushes users
to export a PNG into Word (`critique-domain-realism.md m17`). `simple` numbers sheets `1 of 6`
with a title; `ncs` applies the regex and is the default for projects created from a commercial
starter. `DRG SR-0247` becomes `ProjectInfo.drawingNumber`, optional.

### CR-067 · `sheetFilter` vs `domainFilter`

- **design-ux-schematic.md §4.5:** a sheet filter is "domain set **+ layer set**".
- **design-data-model.md §2.11:** `Sheet.domainFilter: Set<SignalDomain>` only.

**Ruling — `domainFilter` only**, consequent on CR-064. `Sheet` also gains
`lifecycleFilter: Set<LifecycleStatus>` (default all), which is the useful half of the layer
filter and costs one field.

### CR-068 · Symbol pinning is unmodelled

- **design-ux-schematic.md §2.5:** "Every symbol is `auto` or `pinned`. Any manual move sets
  `pinned = true` … **Auto-layout never moves a pinned symbol.**"
- **design-data-model.md §2.11:** `SheetItem{targetId, position, rotationQuarterTurns,
  collapsed, zOrder}` — no `pinned`.

**Ruling — `SheetItem.pinned: bool` ships in v1.** It is one boolean and it is the entire
difference between auto-layout being usable and being feared. The *commands* around it (four
tidy/re-flow scopes, preview-diff, `Tab` variant cycling) defer to v1.3; v1 ships: first layout
is automatic, any manual move pins, `Ctrl+Shift+U` unpins, and a single `Tidy sheet` command
behind a plain confirm.

### CR-069 · Three places a symbol position can live

- `SheetItem.position` (design-data-model.md §2.11).
- `UnplacedPlacement.schematicHint` (§2.4).
- Stacking order exists as **both** `DeviceInstance.zOrder` ("schematic stacking") and
  `SheetItem.zOrder`. Precedence is undefined everywhere.

**Ruling — `SheetItem` owns both, exclusively.** `SheetItem.position` is the only symbol
position; `SheetItem.zOrder` is the only stacking order. `DeviceInstance.zOrder` is deleted.
`StagedPlacement.schematicHint` survives only as a *seed* consumed once when the first
`SheetItem` is created for that device, and is cleared thereafter.

### CR-070 · Unit splitting is unmodelled

- **design-ux-schematic.md §1.2(b):** symbols split into `MTX1:A/:B/:C`; "units may live on
  **different sheets**"; "**no symbol edge ever carries more than 16 pins**"; automatic split by
  domain for multi-sheet sets.
- **design-data-model.md:** one `SheetItem` per device per sheet; no unit letter, no per-unit
  port assignment.

**Ruling — cut from v1.** Bank collapse to vector pins (CR-055) covers the density case without
rendering one device as three bodies, which is a confusion generator for an installer audience
that has never read an FPGA schematic. If it returns in v1.2 the model addition is
`SheetItem.unitKey: String?` + `BankDef.unitKey` — additive, no migration.

### CR-071 · The rear-panel view — printable, and is it the authoring surface

- **design-ux-schematic.md §5.4:** "this is the *installer's* view … it is **what gets printed
  and taped inside the rack door**", and "**the rear panel view is the device builder's output
  surface. You build a device by drawing its rear panel.**"
- **design-ux-device-builder.md §2.6:** "**Against manual x/y authoring as a required step.** It
  is precisely the 'click 16 times' failure the brief is trying to eliminate, multiplied — a
  48-port patch panel would need 48 placements."
- **design-data-model.md §2.11:** `SheetKind` has 11 values and **no rear-panel kind**.
- **design-architecture.md §6.2:** scene layers are `rack_layer / device_layer / wire_layer` —
  no rear-panel renderer and no schematic-symbol renderer.

**Ruling — three separate answers.**
1. **Authoring:** `design-ux-device-builder.md` wins outright. Ports are authored in the grid;
   panel geometry is auto-laid-out from connector footprints; manual nudging is an optional
   hidden toggle pre-populated from the auto-layout. "You build a device by drawing its rear
   panel" is **rejected** as the authoring model.
2. **Printing:** the rear panel *is* printed in v1 — as sheet `T2.02 Rack Elevation — Rear`,
   drawn by the same scene builder with connector fields and landing cable IDs. `SheetKind`
   already has `elevationRear`; nothing new is needed.
3. **Interactive view:** the standalone rear-panel *editor* (leaders, tag pills, per-connector
   navigation, egress heat map) is **v1.1** — the highest-value deferred item in the plan.

`scene/` gains `panel_layer.dart` and `symbol_layer.dart` in v1; the schematic symbol cannot be
a widget-only artifact if it is to print (CR-086).

### CR-072 · Structure device sheet position

- **design-ux-schematic.md §3.2:** "The Structure device is **forced to layer 0, always**,
  rendered as a bank of off-page connector flags on the **left edge**."
- **design-ux-device-builder.md §6.9:** "a Structure **can be pinned to the right edge**
  instead."

**Ruling — `StructureBody.sheetEdge: left | right`, default `left`.** Layer 0 / layer N
accordingly. A utility or service-entrance structure drawn on the opposite side from the
home-run field is a legitimate and common arrangement.

### CR-073 · Multi-sheet — v1 feature or v2 upgrade

- **design-ux-schematic.md §4.5:** ships it — "`Layout → Split to Sheets…`: offers the domain
  partition, plus a **graph min-cut** alternative, plus **by rack**."
- **design-ux-schematic.md §3.4:** lists auto sheet partitioning as **v2 upgrade #6**.
- **design-pdf-export.md §5.4:** net partition with off-sheet connectors is the v1
  recommendation.

**Ruling — one schematic `Sheet` entity in v1; the *exporter* partitions by domain.**
`Sheet` exists in the model from v1 so the format never migrates, and exactly one schematic
sheet is created per project. The PDF exporter emits N domain sheets by filtering that one
sheet's contents. The decisive observation, from `critique-ux-simplicity.md`:

> A cable belongs to exactly one signal domain, therefore a **domain partition produces zero
> cross-sheet connections by construction.**

So **off-sheet connectors and cross-reference resolution are not built in v1** — the entire
expensive apparatus (paired pentagon flags, the second placement pass, min-cut cost functions,
match lines, key plans) disappears. Devices simply repeat across sheets, labelled with their
designator. The **zone grid stays** (it is ~30 lines and the schedule's `REF` column is
genuinely useful for finding a wire on a sheet). Geometric tiling and min-cut partitioning are
cut; `TilingStrategy.geometric` survives only for a single over-tall rack elevation.

### CR-074 · The "SYSTEM OVERVIEW — all devices" sheet

- **design-ux-schematic.md §4.5:** "Sheet 1 SYSTEM OVERVIEW — all devices, collapsed, buses
  only, no individual wires."
- **design-ux-schematic.md §4.6:** its own density table says 0–40 connections is the
  one-sheet-draw-everything band.

**Ruling — deleted.** The arithmetic in `critique-ux-simplicity.md` is correct: twenty symbols
at this document's own sizing rules consume 84% of an ANSI B sheet before a wire is drawn.
There is no legible all-devices sheet at target scale, and shipping one sets an expectation the
product cannot meet. The cover sheet's rack summary strip serves the "what is this system"
purpose honestly.

### CR-075 · `Sheet.viewKind` vs `Sheet.kind`

- **design-data-model.md §1** (ER diagram): `viewKind: elevation | schematic | schedule | cover
  | legend` — 5 values.
- **design-data-model.md §2.11:** `SheetKind kind` — 11 values. I-42 refers to `viewKind`.

**Ruling — one field, `SheetKind kind`, 11 values, plus `exceptions`** for the new `T0.02`
(CR-022). The ER diagram's `viewKind` is deleted and I-42 is rewritten against `kind`.

---

## 1.8 Colour, theme, and typography

### CR-076 · Default theme

- **design-architecture.md §12.3:** "`screenDark` (**the default** — this is a pro tool used in
  equipment rooms and dark UIs are the genre convention)."
- **design-ux-schematic.md §1.7:** the canonical palette section is light-first, every wireframe
  is light, and "The dark theme is for the person editing at 11 pm; **the light theme is the
  deliverable**."

**Ruling — light is the first-run default; dark ships and is one click away.** The moment that
decides whether a user trusts the tool is comparing the screen to the printed sheet, and that
comparison must succeed on first run. The genre-convention argument is real but weaker than a
trust argument (G1). Theme is a UI preference, never persisted in the document.

### CR-077 · "No user-facing export-palette option" vs three of them

- **design-ux-schematic.md §1.7:** "Export **always** renders the light/print palette regardless
  of screen theme, **with no user-facing option to do otherwise**."
- Against: `ProjectSettings.greyscaleSafeExport` (design-data-model.md §2.1), design-ux-
  schematic.md's own "Ship a **Greyscale-safe export toggle**", and design-pdf-export.md §12
  decision 16's greyscale and CMYK exports.

**Ruling — the absolutism is wrong; the rule underneath it survives in a narrower form.**

> **The screen theme never affects the export.**

Export palette is an explicit `ExportSpec.palette: colour | greyscale | cmyk`, defaulting to
`colour`, defaulting to `greyscale` in the Installer preset, and **never inherited from the UI
theme**. `ProjectSettings.greyscaleSafeExport` is **deleted** — it is an export option, not a
property of the design.

### CR-078 · Colour lives on the domain, but is stored on the family

- **design-data-model.md §3.4:** "**Colour is on the `SignalDomain` (7 values), not the family
  (43+).** No palette is CVD-safe past ~9 categories."
- **design-data-model.md §2.10:** `SignalFamilyDef` carries `Rgb color`, `List<int>
  dashPattern`, `int lineWeightPermille`, `String? glyph` — per family, 43+ entries.
- No `SignalDomainDef` exists anywhere.

**Ruling — `SignalDomainDef` is created and owns the visual language.**
`SignalDomainDef{id, displayName, tagPrefix, color, dashPattern, lineWeightPermille, glyph}` —
eight entries (7 domains + structure). `SignalFamilyDef` keeps `domain` (FK), `shortTag`, and
an optional `colorOverride` for the rare deliberate exception. This deletes the 43-entry palette
the same document argues against, and it is what makes the requirement-level colour ruling
(AC-045) implementable.

### CR-079 · Dash pattern has no stated unit

- **design-data-model.md §2.10:** `List<int> dashPattern; // [6,3]` — no unit anywhere.
- **design-ux-schematic.md §1.4:** dashes specified "in U" (grid units).
- **design-pdf-export.md §2.4/§6.2:** `Stroke.dash` in **points**, with "dash period ≥ 1.5 mm
  or it blurs to solid at 300 dpi".

**Ruling — dash patterns are in points (1/72 in), matching the renderer.** Stated once, in
`docs/visual-language.md`. The screen backend divides by the zoom scale so a dash is
zoom-invariant; the PDF backend passes them through. `dashPattern: List<int>` is permille-points
to stay integral in the file.

### CR-080 · Fonts — a named rejection contradicted

- **design-pdf-export.md §9.2:** IBM Plex Sans / Sans Condensed / Mono, SIL OFL 1.1, six TTFs,
  with a worked argument — and explicitly: "**Runner-up considered and rejected: Inter** … and
  **Roboto / Roboto Mono**."
- **design-architecture.md §12.3:** "`Inter-Regular`, `Inter-SemiBold`, `JetBrainsMono-Regular`
  in `apps/rackmate/assets/fonts/`."
- **design-architecture.md §9.4** then asserts goldens use families `RackBody`/`RackMono` — the
  pdf document's aliases with the pdf document's rejected fonts, and no `RackCond`.

**Ruling — IBM Plex.** `RackBody` = Plex Sans (Regular + SemiBold), `RackCond` = Plex Sans
Condensed, `RackMono` = Plex Mono (Regular + Bold), fallback Noto Sans Symbols 2.
`design-pdf-export.md §9.2`'s argument is fully worked — glyph disambiguation (`W014` vs `WO14`
is a real failure mode on a physical label), a true condensed cut worth 12% of schedule column
width, and Greek coverage for `Ω`/`µ`. `design-architecture.md`'s font list is asserted, not
argued. The golden-test assertion is updated to the three families.

### CR-081 · Text-metric source of truth

- **design-pdf-export.md §12 decision 11:** "**`PdfFont.stringMetrics` is the single source of
  truth for text metrics on both backends**, with Skia kerning disabled to match."
- **design-architecture.md §12.3:** bundling the same TTF "is what makes text metrics agree
  between the two" — a different and **insufficient** mechanism, since Skia applies GPOS kerning
  and `liga` and dart_pdf applies neither.
- **design-architecture.md §6.6:** `Pt measureText(String s, TextSpec spec)` — each backend
  answers independently, and the return type cannot express a baseline.

**Ruling — `design-pdf-export.md` §6.7 in full, plus the signature fix from
`critique-feasibility.md #4`.**
One injected `TextMeasurer` backed by `PdfFont.stringMetrics`, used by the scene builder and by
**every** backend including the Flutter one. `measureText` returns
`TextMetrics{advanceWidth, ascent, descent, capHeight, xHeight, lineHeight}` — never `Pt`.
`TextStyleSpec` carries an explicit `TextAnchor`, and the anchor resolves in **one shared
pure-Dart helper**, so neither adapter ever guesses a baseline. Flutter sets
`FontFeature.disable('kern')` **and** `FontFeature.disable('liga')`. The parity test asserts on
**baseline Y**, not just the bounding box. This is the ruling that forces CR-083.

### CR-082 · Line weights: screen zoom-invariance

- **design-ux-schematic.md §1.4:** "Screen weights are **zoom-independent** (multiply by
  `1/viewport.scale`)."
- **design-architecture.md §6.4:** "Anything the user *touches or reads* is constant in screen
  pixels; anything representing *physical reality* scales."

**Ruling — both, and the distinction is a field on the stroke.** `Stroke.scaleWithGeometry`
(and `Stroke.hairlineFloor` for print) already exist in `design-pdf-export.md §6.2` and are
adopted. Cable traces, symbol outlines and rack rails **scale**; UI chrome, selection halos and
hit slop are **constant in screen pixels**; sheet furniture uses `hairlineFloor` with a 0.25 pt
print floor. No stroke width is ever emitted as 0.

---

## 1.9 Architecture, packaging, and persistence

### CR-083 · Package layout — four packages or one tree

- **design-architecture.md §1.1/§2.2:** four packages; "`rackmate_export` and `rackmate_ui` are
  **siblings that cannot see each other**. That is deliberate: it is what guarantees the PDF
  path is isolate-safe."
- **design-pdf-export.md §10:** a **single** `lib/` tree with `diagram/backends/{pdf_canvas,
  svg_canvas, bounds_canvas, flutter_canvas}.dart` — the Flutter and PDF backends in one
  directory. Worse, it places `diagram/text.dart # TextMeasurer, PdfFontMeasurer` in the core
  tree, which makes core depend on `package:pdf` and breaks
  `design-architecture.md`'s own `no_flutter_import_test`.

**Ruling — five packages. Four from `design-architecture.md`, plus one that resolves the
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

`rackmate_ui` depending on `rackmate_text` is harmless — `package:pdf` is pure Dart and
isolate-safe. The invariant that actually matters is preserved and mechanically enforced:
**`rackmate_core`, where the scene builder lives, has no concrete font engine and no
`dart:ui`.** It receives a `TextMeasurer` by injection. `no_flutter_import_test` keeps banning
`package:flutter/`, `dart:ui`, and `package:pdf/` in core. `design-pdf-export.md §10`'s folder
convention is the arrangement `design-architecture.md §1.1` correctly predicts "will be violated
within a month by an `Offset` that 'was just easier'".

### CR-084 · Where hit-testing lives

- **design-pdf-export.md §10:** `diagram/hit_test.dart` — in the core tree.
- **design-architecture.md §1.2:** `rackmate_ui/canvas/input/hit_tester.dart`.

**Ruling — both, split by concern.** The *geometric* hit test (`DiagramScene.hits`,
point-to-segment distance, nearest-hit selection) lives in `rackmate_core/draw/hit_test.dart` —
pure, synchronously testable, and reusable by the read-only mobile shell. The *pointer plumbing*
(one query per frame, spatial hash, cursor policy, hover throttle) lives in
`rackmate_ui/canvas/input/`.

### CR-085 · Y-axis flip in the PDF backend

- **design-architecture.md §6.6:** "Use **per-coordinate flipping** (`double _y(double y) => _h
  - y;`) rather than a global `scale(1,-1)` transform."
- **design-pdf-export.md §6.5:** "**Take (b)** [the global flip]. The reason is that the
  interface exposes `rotate()` and `transform()`."

**Ruling — global flip.** `design-architecture.md §6.6` is internally inconsistent: the
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
  on screen and by a scene builder in print, with no parity mechanism —
  defeating D4 exactly where it matters most. `design-pdf-export.md`'s parity test compares the
  two *canvas backends*, not the two *device renderers*.

**Ruling — one rendering path; widgets remain as an interaction and semantics shell.**
Each device is still a `RenderBox` child of `RenderRackCanvas` — it owns hit-testing, focus,
hover, keyboard handling, and `Semantics`, which is what makes
`design-ux-rack.md §10.2`'s accessibility story true. But its `paint()` **replays that device's
`DiagramScene` fragment through `FlutterDiagramCanvas`**; it does not draw anything itself.
Pixels come from the shared IR; behaviour comes from the widget. Both documents get what they
argued for, D4's guarantee holds where it matters, and the parity test covers faceplates by
construction. This is the single most consequential architectural ruling in this record.

### CR-087 · `measureText` return type

- **design-architecture.md §6.6:** `Pt measureText(String s, TextSpec spec);`
- **design-pdf-export.md §6.4:** `TextMetrics measureText(String text, TextStyleSpec style);`

**Ruling — `TextMetrics`.** Subsumed by CR-081; recorded separately because it is a signature
that will otherwise be copied from the wrong document.

### CR-088 · `RendererCaps`

- **design-pdf-export.md §6.4:** `RendererCaps get caps;` with `nativeDash`, `nativeAlpha`,
  `nativeRoundRect`, `textSelectable`.
- **design-architecture.md §1.2:** mentions it in a file listing and never defines it.

**Ruling — deleted.** The moment a scene builder branches on capabilities there are two code
paths and the abstraction has already leaked. The interface is the common denominator, and
`design-pdf-export.md §6.4`'s own rule — "no gradients, no shadows, no blurs, no blend modes,
no shaders" — is promoted from prose to an invariant with a test.

### CR-089 · SVG, bounds canvas — one document only

- **design-pdf-export.md §6.1/§8.3/§10:** `SvgDiagramCanvas` and `BoundsCanvas` as first-class
  backends.
- **design-architecture.md:** neither is mentioned.

**Ruling — `BoundsCanvas` in v1, `SvgDiagramCanvas` in v1.1.** Bounds are not optional: scale-
to-fit, tile counts, zoom-to-fit and the key plan all require the diagram's true extent, and
there is no other way to get it. SVG is one file on top of an architecture that already exists.
`design-architecture.md`'s package tree is amended to list both.

### CR-090 · Model class names in the export document

- **design-pdf-export.md §10:** `RackProject, Device, Port, PhysicalLink, LogicalSignal,
  CableType, Rack, Structure`.
- **design-data-model.md:** `Project, DeviceInstance, Port, Link, Net, Rack, StructureBody`.
- **design-architecture.md:** `RackDocument, RackDevice, Connection, CableType`.

**Ruling — one glossary, in `docs/glossary.md`.** The binding names:
`RackDocument` (the in-memory mutable aggregate) · `ProjectInfo` (title-block metadata on it) ·
`Rack` · `DeviceTemplate` / `TemplateSnapshot` / `TemplateBody` · `DeviceInstance` · `Port` ·
`Link` / `Service` / `Conductor` / `Net` · `Outlet` / `Pathway` / `StructureBody` ·
`Location` · `Circuit` · `Sheet` / `SheetItem` · `Note` · `Finding` / `AckedFinding`.
Deleted: `Connection`, `RackProject`, `Device`, `RackDevice`, `PhysicalLink`, `LogicalSignal`,
`CableType`, `StructureDrop`, `StructureBundle`, `PortGroupDef`.

### CR-091 · `.rackmate` container — plain JSON or zip

- **design-data-model.md §4.1:** "v1 is **plain, pretty-printed, key-sorted UTF-8 JSON** … v2:
  ZipCodec."
- **design-architecture.md §7.1:** "**Not zipped**, not binary."
- **design-ux-device-builder.md §3.1:** "`.rackmate` | A project | **Zip**: `project.json` +
  embedded template snapshots + `assets/`."

**Ruling — plain JSON, because device images are cut from v1.** The zip requirement exists only
to carry the 512 KB per-face `frontImage`/`rearImage` that `design-ux-device-builder.md §1.5`
itself calls a scope trap and says are "not needed for correct output". Images are cut (AC-057),
so the container question resolves to plain JSON — which is also what the confirmed product
decisions specify. `DocumentCodec` ships from commit one and sniffs `PK\x03\x04` on read, so a
v2 zip container is a non-event.

### CR-092 · Envelope shape

- **design-data-model.md §4.2:** root keys (`generator`, `schemaVersion`, `minReaderVersion`,
  `appVersion`, `id`, timestamps, `revision`) with all entity maps nested under `"document"`.
- **design-architecture.md §7.1:** root keys with the project's fields at the root, no wrapper.

**Ruling — `design-data-model.md`'s envelope with the `document` wrapper.** It separates format
metadata from content, makes the magic-key check a single top-level read before any parsing, and
gives migrations one obvious place to stand.

### CR-093 · Migration control flow, and a defect in one of the two snippets

- **design-data-model.md §4.3:** `migrateToCurrent` **throws** (`FormatException`,
  `NewerSchemaException`) and returns `raw..['_openReadOnly'] = true`.
- **design-architecture.md §7.2:** returns `Outcome<JsonMap>` and never throws — "**Expected
  outcomes … are values, not exceptions.**"
- `design-architecture.md`'s snippet is also wrong: `minReader > kSchemaVersion` returns
  `NewerSchema(v, readOnly: **false**)` — backwards, it should refuse — and its trailing
  `if (v > kSchemaVersion)` is unreachable given the loop condition.

**Ruling — `Outcome<T>`, with `design-data-model.md`'s cases and the defect fixed.**
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

**Ruling — two counters, both correct, neither overloaded.**
`RackDocument.sequence` — strictly monotonic, incremented on **every** committed transaction
*and* on every undo and redo (an undo is a change). Persisted. This is the sync cursor and I-6
is rewritten to name it.
`RackDocument.stateId` — in-memory only, non-monotonic; each undo entry records the stateId
before and after, and `isDirty == stateId != savedStateId`. This preserves
`design-architecture.md`'s correct UX (undoing back to the save point marks the document clean)
without breaking the invariant the sync design rests on.

### CR-095 · Tombstones and `EntityMeta` are absent from the architecture

- **design-data-model.md §5.3/§5.4:** every entity carries `EntityMeta`; tombstones are "the one
  thing that genuinely cannot be retrofitted" — "**Do it now or accept that sync is a
  rewrite.**"
- **design-architecture.md:** tombstones are never mentioned; `EntityMeta` is only implied by a
  `d.touch(doc.clock.nowUtc(), doc.actor)` call and never defined, listed, or persisted.

**Ruling — both ship in v1, on the conflict-unit set only.** `design-architecture.md`'s omission
is an oversight, not a position (G5). But per `critique-feasibility.md #3`, `EntityMeta` is
carried **only by entities that are sync conflict units** — `RackDocument`, `Location`, `Rack`,
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

**Ruling — recovery files are never attached automatically.** A recovery file is a complete
project document containing the client's name and site address. The diagnostics bundle carries
versions, document *statistics*, the last 200 log records, and epoch/sequence values. The crash
dialog offers an explicit, default-off **"Attach the project file"** checkbox whose label reads:
*"This includes your client's name and site address."*

### CR-097 · Display units — app preference or project setting

- **design-architecture.md §12.2:** "**Display units are a user preference independent of
  locale.**"
- **design-ux-device-builder.md §1.3:** "Unit follows the **app-level preference**."
- **design-data-model.md §2.1:** `ProjectSettings.displayUnits` — persisted in the document.

**Ruling — the project wins when set; the user preference is a default and a session
override.** `ProjectSettings.displayUnits` is authoritative — a US-spec commercial job opened on
a German integrator's laptop must still read in inches, which is the deciding case and the one
CI firms actually hit. The user preference supplies the value for *new* projects. A per-session
display toggle exists and does not modify the document or mark it dirty.

### CR-098 · The `.history/` folder implies a project directory

- **design-ux-device-builder.md §5.3:** "a pre-update snapshot of `project.json` is written to
  the project's **`.history/` folder**."
- **design-architecture.md §7.3/§7.5:** single file, `.bak` sibling, recovery snapshots in
  application support.

**Ruling — deleted.** The confirmed product decision is a **local single-file `.rackmate`
project**. Pre-update snapshots go to
`getApplicationSupportDirectory()/snapshots/<docUuid>/<sequence>.rackmate`, alongside recovery
snapshots, pruned to the last 10. The user's folder gains nothing but the file they asked for
and one `.bak`.

### CR-099 · Isolate API

- **design-architecture.md §1.2/§8:** `build_document.dart # top-level fn; the **Isolate.run**
  entry point`.
- **design-pdf-export.md §12 decision 13:** "progress via captured `SendPort`; **cancel via
  `Isolate.kill`**" — neither of which `Isolate.run` supports.

**Ruling — `Isolate.spawn` + a `SendPort` pair for export.** `Isolate.run` is used only where
neither progress nor cancellation is wanted — autosave serialization. The comment in
`design-architecture.md §1.2` is corrected. On web (not a v1 target)
`kIsWeb ? buildDocument(req) : spawn(...)` is a one-line guard.

### CR-100 · PDF preview mechanism, and whether OS print ships

- **design-pdf-export.md §12 decision 14:** "Primary preview uses the **screen** renderer, so
  the core flow has zero native dependencies."
- **design-architecture.md §8.4:** `printing ^5.15.0` — "`PdfPreview` for in-app preview", with
  the pdfium build-time-download risk noted in the same document's risk register.
- Neither document states whether the OS print dialog ships in v1; `Ctrl+P` means Export in
  `design-ux-rack.md` and Command Palette in `design-ux-schematic.md`.

**Ruling — screen-renderer preview is primary and has no native dependency.**
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

**Ruling — one arbitrated keymap in `docs/keymap.md`, generated from a single `Intent`
registry** so the table cannot drift from the code again. Three arbitration principles:
**(a)** view-switching and global-command keys win over every view-local meaning;
**(b)** a key means the same thing in every view or it means nothing;
**(c)** unmodified single letters are view-local tools and must not collide between views that
share the canvas.

The binding resolutions:

| Key | Ruling |
|---|---|
| `Ctrl+1..4` | switch view: Rack · Schematic · Rear · Schedule — global |
| `Ctrl+0` / `Ctrl+9` / `Ctrl+Alt+0` | fit content · fit selection · zoom 100% — every view |
| `Ctrl+P` | Export / Print dialog — every view |
| `Ctrl+E` | Export other formats… |
| `Ctrl+K` | Command palette — every view |
| `Ctrl+F` / `Ctrl+G` | Find · Go to designator — every view |
| `F` / `Shift+F` | Focus · Isolate — schematic and rear only; **unbound in rack** |
| `Ctrl+Shift+F` | Cycle elevation face (Front → Rear → Both) — rack only |
| `Ctrl+R` | Renumber… — every view, scoped to the selection kind |
| `Ctrl+L` | Lock / unlock — every view (position in rack, route in schematic) |
| `G` / `L` | Toggle grid · Cycle label mode — every view |
| `W` | Begin wire from the selected port — schematic; warning badges move to `Ctrl+Shift+W` |
| `Ctrl+B` | Fill gaps with blanks — rack (bus creation defers with buses) |
| `Ctrl+Shift+R` | Reverse link direction — schematic (auto-arrange defers) |
| `Ctrl+Alt+3` | Outline panel — global |
| `T` | unbound in v1 (Trace defers) |

"Focus mode on this rack" is deleted as a distinct command — it is fit-selection with a rack
selected, which is `Ctrl+9`. The total shipped surface is ~40 bindings, not 170.

### CR-102 · Marquee button

- **design-ux-rack.md §3.6:** "Marquee on empty canvas: press-drag" — left button.
- **design-ux-schematic.md §2.4:** "**Right-drag** | marquee (no modifier needed, doesn't
  collide with pan)" — while §2.1 also binds right-click to "cancel current operation".

**Ruling — left-drag on empty canvas, in every view.** Right-drag is reserved for the context
menu, which is a platform expectation on desktop and which `design-ux-schematic.md` itself
double-books. The CAD window/cross convention is kept in both views: left→right selects fully
contained (solid band, `WINDOW`), right→left selects intersecting (dashed band, `CROSS`).

### CR-103 · Three thresholds for closely related collapse behaviours

- Vector-pin collapse at **≥ 4** homogeneous ports (design-ux-schematic.md §1.2c).
- Unit split at **17** pins on an edge (§1.2b).
- Bank auto-collapse in the symbol preview at **> 8** (design-ux-device-builder.md §2.7).

**Ruling — one constant, `kBankCollapseThreshold = 8`.** Any bank of ≥ 2 ports may be collapsed
by the user at any time; banks over 8 auto-collapse on first layout and in the symbol preview.
The 17-pin unit split is deleted with unit splitting (CR-070).

### CR-104 · Two places to add a device, with different consequences

- **design-ux-rack.md §1.1:** a left-hand PALETTE that places into a rack.
- **design-ux-schematic.md §8.1:** a separate LIBRARY panel with `+ New device`, which must
  produce a device with no rack position.
- Neither document says which you get, or reconciles `RailPlacement` with `StagedPlacement`.

**Ruling — one palette widget, one insert command, placement decided by the drop target.**
`Insert device…` (`Ctrl+Alt+I`, `/` search, double-click an empty U, or drag) exists in every
view. Dropping on a rack → `RailPlacement`. Dropping on the schematic canvas, or inserting with
no rack focused → `StagedPlacement` plus a `SheetItem` at the drop point. The schematic's
`+ New device` button is deleted; its LIBRARY panel is the same palette widget with the same
model. This closes the "where do I add a device" cliff that
`critique-ux-simplicity.md` identifies at the 5:30 mark of a first session.

### CR-105 · Wiring surface — the rack editor has none

- **design-ux-rack.md:** no wiring affordance anywhere; the user must discover a second view.
- **design-ux-schematic.md §5.4:** "the rear panel says **which physical jack to plug into** …
  this is what gets printed and taped inside the rack door."
- **design-data-model.md:** silent.

**Ruling — connections are created in the schematic in v1, and the rack editor signposts it.**
Two concrete mitigations, both cheap:
(a) a device with unconnected ports shows a port-count chip (`🔗 0/12`) in the elevation, and
clicking it switches to the schematic with that device selected;
(b) the **schedule table is the second tab in the app**, reachable from an empty project and
filling live as connections are made — so the deliverable is visible from minute one rather
than discovered at export (G1, and `critique-ux-simplicity.md`'s third prioritisation fix).
Editing endpoints from the schedule and from the rear-panel view lands in v1.1.

### CR-106 · Undo scope outside the document

- **design-architecture.md §4:** the command stack is scoped to `RackDocument`.
- **design-ux-device-builder.md §2.5:** asserts "Delete | **Undoable**" in the port grid, and
  §6.5 gives the drop table the same operation set — both outside `RackDocument`.

**Ruling — one `Command` machinery, three stacks.** `UndoStack` is generic over an aggregate.
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
  `polarity` — and `Link` independently carries `media`, `jacket`, `gaugeAwg`,
  `calculatedLength`, `cutLength`, `slackPercent`, `status`, `test`, `installedBy`,
  `terminatedAt`.

**Ruling — `StructureDrop` is deleted; a home run *is* a `Link`.** Fully accepted from
`critique-domain-realism.md B2` — see AC-017 for the replacement shape. One cable, one row, one
length, one certificate, one status.

### CR-108 · TIA-570-D grades as the primary specification axis

- **design-data-model.md §2.8/§3.8:** `StructureGrade{grade1, grade2, grade3, custom}`,
  `ProjectSettings.defaultBundleGrade`, and "*Add outlet: Grade 2*" as **the reason bundles
  exist**.
- **design-ux-device-builder.md §6:** the Structure editor is a room × media matrix. The word
  "grade" never appears. `ProjectSettings.defaultBundleGrade` has no UI.

**Ruling — user-defined outlet templates are first-class; grades are presets and a tag.**
`OutletTemplate{id, name, drops: [{media, service, count}]}` seeded with **TV location · AP ·
Keypad · Ceiling speaker pair · Camera · Data-only**, *and* with TIA-570-D Grade 1/2/3.
`StructureGrade` as an enum is deleted; `Outlet.tia570Grade: String?` remains as a standards tag
for specs that cite it. `critique-domain-realism.md m23` is right that essentially no CI
integrator speaks in grades, and the matrix-entry screen already got this right — the model had
it backwards.

### CR-109 · Conduit is a media type that creates a connectable port

- **design-ux-device-builder.md §6.3:** "Cond" is a media column in the entry matrix, creating a
  drop like any other.
- **design-data-model.md §3.8:** every drop is 1:1 with a `Port` on the Structure device.
- An empty conduit is not a cable and cannot be connected to anything.

**Ruling — `MediaTypeDef.isPathwayOnly: bool`.** A pathway-only entry creates a `Pathway`
(CR-016), not a Link and not a Port. It appears in the drop table and on the pull sheet — you
still pull the smurf tube and it still costs money — and it never appears in the netlist.

### CR-110 · The Structure device is in the rack palette but cannot be placed

- **design-ux-rack.md §1.1:** the palette contains "▾ Structure / ▪ Rough-in".
- **design-data-model.md I-24:** a structure device always has `UnplacedPlacement`.
- The drag interaction is undefined in every document.

**Ruling — removed from the rack palette.** A `StructureBody` is created from
`Project ▸ Structured wiring…`, or implicitly on first use of the Structure editor. It renders
in the schematic as an edge bank of flags (CR-072) and in the rack elevation not at all.

### CR-111 · `bundleStatus` — minimum or maximum

- **design-data-model.md §2.8:** "`RoughInStatus bundleStatus; // derived-**max** of member drop
  statuses`".
- **design-data-model.md I-39:** "derived as the **minimum** status across its drops".

**Ruling — minimum.** An outlet is as complete as its least-complete run; a max would report an
outlet "tested" when three of its four cables are still coiled. Also: it is **derived and not
serialized** (CR-119).

### CR-112 · The Structure device is where the location tree lives

- **design-ux-device-builder.md §6.2:** "**This tree is the project's canonical location
  vocabulary**" — and it is reachable only from the Structure editor.
- **design-ux-rack.md §7.5:** racks and devices carry a `Location` and the editor shows a flat
  combobox.

**Ruling — `Project ▸ Locations…` is a top-level panel.** Consequent on CR-047. A project with
racks and no Structure device must still be able to say which room a rack is in; today it
cannot.

### CR-113 · Multiple Structure instances

- **design-ux-device-builder.md §6.9:** "Explicitly supported and encouraged", each with its own
  name, prefix, location scope, and label template.
- **design-data-model.md §3.8:** agrees.
- **design-ux-schematic.md §3.2:** forces "the Structure device" (singular) to layer 0.

**Ruling — multiple instances ship, and layering handles all of them.** Every `left`-edge
Structure goes to layer 0, every `right`-edge one to layer N (CR-072). Drop `fieldLabel`
uniqueness is **project-wide across all Structures**, per `design-ux-device-builder.md §6.9` —
labels get printed on physical cable and must not collide across panels.

---

## 1.12 Residual internal contradictions

### CR-114 · `Extent` exists for one field

- **design-data-model.md §2.0:** `sealed class Extent { Known | Unknown }` "for
  'unknown/varies' fields".
- Used once, on `StructureDrop.calculatedLength`, while `Link.calculatedLength` is a plain
  `Len?`.

**Ruling — deleted. `null` means unknown, everywhere.** One mechanism, and the obligation moves
to the UI: a rollup must **report its unknowns** — *"Total weight 148 lb · 3 devices have no
weight"* — rather than silently treating null as zero (G4). This is
`critique-ux-simplicity.md`'s "missing data the user can see beats fabricated data the user
can't", and it is binding.

### CR-115 · Derived caches are persisted

- **design-data-model.md §5.6:** names `portIds`, `bundleStatus`, `templateUpdateAvailable` as
  "rebuildable caches, flagged as such"; I-11 says `portIds` is "rebuilt on load rather than
  trusted".
- **design-data-model.md §4.5:** all three are written into the example file.

**Ruling — derived values are never serialized.** `portIds`, `bundleStatus`,
`templateUpdateAvailable`, `Link.dominantSignalFamily`, and the deleted
`StructureDrop.terminatesAtPortId` are in-memory only. A cache in the file bloats the git diff
that plain JSON exists to keep readable, and creates a second source of truth that will
eventually disagree with the first.

### CR-116 · The worked JSON example violates the ID invariant

- **design-data-model.md I-2:** "Every entity ID is a valid **UUID v7**."
- **design-data-model.md §4.5:** every ID in the example is `"rk-1"`, `"dev-mtx1"`,
  `"p-str1-d1"`, `"sh-t201"`.

**Ruling — normative examples use real UUIDv7s.** The example is the artifact people copy. A
short-ID example may appear once, in a tutorial, explicitly banner-marked non-normative.

### CR-117 · Round-trip invariant tests the wrong property

- **design-data-model.md I-16:** `read(write(read(x))) == read(x)` — semantic round-trip.
- The stated justification for plain JSON is git-diffability and honest dirty-tracking, which
  require `write(read(bytes)) == bytes` — **byte** round-trip.

**Ruling — assert the byte round-trip.** It constrains key ordering (including inside nested
`unknown` maps), timestamp precision, and integer formatting — all of which are exactly the
things that produce spurious diffs and a lying dirty flag. Accepted from
`critique-feasibility.md #24`. I-16 is rewritten.

### CR-118 · Elevation scale — true scale or fit-to-page

Never stated in any document, while `design-pdf-export.md §4.2` prints a scale ratio in the
title block and warns "Never print `1:8` on a sheet drawn at 1:8.34 — someone will scale off
it."

**Ruling — fit-to-page, snapped to a standard ratio when within 2%, otherwise `NTS`.**
`design-pdf-export.md §4.2`'s algorithm is adopted verbatim: snap to
`1:{1,2,4,8,10,16,20,24,32,48,64,96}` when `|k − 1/n| < 2%`, print `NTS` otherwise. A ruler
therefore works whenever the block states a ratio and the block is honest when it cannot.

### CR-119 · Multi-document — tabs or single window

- **design-architecture.md §8.6:** "Ship single-window with **in-app document tabs**."
- **design-architecture.md §3.2:** one `ProviderScope` per open document.
- No UX document shows a tab strip, and no document specifies `Ctrl+N`/`Ctrl+O` behaviour with a
  dirty document open.

**Ruling — v1 is single-document, single-window.** `Ctrl+N` and `Ctrl+O` prompt Save / Don't
Save / Cancel and then replace. The per-document `ProviderScope` stays exactly as designed — it
costs nothing now and makes tabs (v1.2) and multi-window (whenever Flutter ships it) mechanical
rather than a rewrite. Tabs without a design are not a feature.

### CR-120 · The two build orders conflict

- **design-architecture.md §13:** PDF export is step 10 of 12.
- **design-pdf-export.md §11:** steps 1–5 are "roughly a week" and should be front-loaded, and
  its step 3 (backend parity) depends on `design-architecture.md`'s step 6 (the display list).

**Ruling — `design-pdf-export.md`'s spikes move to the first week; the export *feature* stays
late.** The five API verification spikes plus the sixth from `critique-feasibility.md #18` cost
a day and de-risk the largest single dependency in the project; running them in week one is
free. The `DiagramCanvas` + display list + **both** backends + the parity test land together,
early, because retrofitting parity is the expensive failure. Sheet furniture, pagination,
partitioning and the export dialog stay in their own milestone. Neither document's ordering
survives intact; the reconciled sequence is Part 2's milestone plan.

---

### CR-121 · Per-run jacket colour — one colour, or the convention plus the exception

- **docs/01-domain.md and docs/08-pdf-export.md** both listed "jacket colour" as a Pull Sheet
  extra column, and nothing in the model could populate it: `Link.jacket` is the NEC fire
  rating and `Conductor.colorCode` is the pair colour inside the sheath. Neither is the colour
  of the cable in the wall.
- **The requesting integrator (2026-07)** asked for per-run colour to carry meaning — yellow
  general data, blue control, green A/V, grey WAP, white camera/bridge/satellite, red external
  and security/fire, black direct burial and patch — and then refined it: a run is sometimes
  pulled in the *wrong* colour (ran out; prewire mistake), and that must be recordable
  "WHILE KEEPING THE KEYSTONES FOLLOWING THE NORMAL CONVENTION".

**Ruling — `Link` stores TWO nullable `JacketColorId`s, and the derived answers are computed,
never stored.** `jacketColorId` is *what the run is* (a reference to a named convention entry;
this is what a keystone follows). `jacketColorPulledId` is *what was actually pulled*, set only
when it differs from the convention — null is the normal case. Collapsing them into one stored
colour cannot express the user's sentence at all, and storing the resolved answers would create
the second copy of one physical fact that CR-107 deleted `StructureDrop` for.

Four consequences, each load-bearing:

1. **The keystone follows the convention, alone.** `keystoneColorId => conventionId`; the
   expression does not mention the override. That syntactic independence *is* the design — the
   keystone is chosen weeks after the pull, out of the same box as every other control drop's,
   and is routinely correct while the cable is not.
2. **The exception is visible, never hidden.** A wrong-colour pull prints as two tokens
   (`BLU→YEL`), never one. `isException` is a pure function of the `Link` plus the map, so
   there is no flag anyone can forget to set. *Documentation of imperfections beats no
   documentation at all.*
3. **Colour is a NAMED ENTRY, not a bare `Rgb`.** The Installer export preset defaults to
   greyscale, so a hex triple degrades to an indistinguishable grey — and was already
   indistinguishable for the ~8 % of installers with a CVD. `abbr` survives greyscale, a
   photocopy and a CVD. It also means one edit repaints a whole job, and an imported pull list's
   `Colour` column (which carries words, not hex) has somewhere to land.
4. **The convention is DATA, seeded per document, never hardcoded.** The seven above are ONE
   shop's convention; there is no industry standard for category-cable jacket colour, and
   TIA-606 standardises *administration label* colours, which is a different fact and must never
   be cited as support. A project may delete all seven and author its own.

**This does NOT touch the hue channel.** Jacket colour reaches the schedule, the label and the
keystone, never a drawn wire — see CR-078 and PAL-1. The two are unrelated facts, and coupling
them would substitute a shop's unvalidated reel colours for the Okabe–Ito palette chosen because
it survives a CVD. `jacket_colour_is_not_hue_test.dart` enforces this by source scan over the
drawing layer.

**Format impact: none.** The override encodes with `putIfNotNull`, so a document that has never
recorded a wrong-colour pull is byte-identical to before the key existed. `kSchemaVersion` stays
2 and `kMinReaderVersion` stays 2 — an additive *optional* key is the opposite of v2's breaking
omission of previously mandatory keys; an older reader never looks at it, so it neither throws
nor degrades. No migration entry changes.

**The four starter assets DO change, deliberately, and this record used to claim otherwise.** The
sentence above originally ended "No starter asset and no migration entry changes", which was false
in its own changeset: `StarterAuthor.newDocument` seeds the convention at document creation exactly
as `buildBlankDocument` does, so all four assets gained the seven-entry block, and `whole_house`
additionally gained fifteen authored `jacketColorId` values on its Cat6 home runs. That is kept
rather than reverted. A starter is a document THIS BUILD authors; a starter with no convention
would be the only document the app produces without one, and AC-052 makes the starters do triple
duty as goldens, perf fixtures and screenshot source — a golden with an empty convention cannot
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

### Section 1 summary — the ten rulings with the widest blast radius

| # | Ruling | Consequence if it had gone the other way |
|---|---|---|
| CR-001 | `Len` = int64 nanometres | Rounding in every dimensioned print; a format migration touching every entity |
| CR-008/010 | `Link` → `Service` → `Conductor` + stored `Net` | No multi-service cables, no cable schedule, or no bus semantics |
| CR-017 | The gesture may hesitate; the document may not lie | Cannot document an existing miswired system — the remediation market |
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

### AC-001 · SEV-1 #1 — three incompatible base units, one with an arithmetic error

**Accepted in full**, including the demolition of `design-architecture.md` D3 on its own stated
criterion: hundredths-mm cannot express the 1/32-in EIA clearance the design itself renders.

**Change:** CR-001, CR-002, CR-003, CR-004. Plus: `Len`, `Mass`, `Money`, `Permille` and the
schematic `Pt` are defined exactly once in `rackmate_core/units/`, and every design document is
edited to reference that definition rather than restate it. Two tests are written before any
other code — exact 1/32-in clearance, and zero accumulated error across a 45U stack — because
they are the two cases that discriminate between the candidate units.

### AC-002 · SEV-1 #2a — Y-flip

**Accepted.** `design-architecture.md §6.6` is internally inconsistent with the interface it
declares three lines earlier. **Change:** CR-085.

### AC-003 · SEV-1 #2b — two different routers were specified

**Accepted**, including the diagnosis: these are not two implementations of one router, they are
two routers. **Change:** CR-013. `ObstacleField`, `RouteCache` and "obstacle-aware" are deleted
from `design-architecture.md §1.2/§5.2`; the incremental-invalidation section goes with them.
The tier-2 derived-cache slot is not left empty — it is reassigned to the per-domain scene
sub-pictures of AC-008.

### AC-004 · SEV-1 #2c — revision monotonicity

**Accepted.** Both documents are right about different counters. **Change:** CR-094.

### AC-005 · SEV-1 #2d — Structure placement vs the Staging Bin

**Accepted**, including the observation that the Staging Bin is a real product requirement with
no representation in the model. **Change:** CR-031, CR-032.

### AC-006 · SEV-1 #3 — the file-size budget is off by 3–6×, invalidating the plain-JSON argument

**Accepted, with a stronger remedy than proposed.** The arithmetic is correct: at the design's
own target of 2,000 ports the port map alone is ~1 MB pretty-printed, and the catalog's 48-port
patch panel (96 ports on one device) makes the tail worse, not better. The knock-on to
`design-architecture.md §7.3`'s "~15 ms at 500 KB" main-isolate save is real.

**Change:**
1. **Lazy port materialisation.** A `Port` entity is serialized **only if it carries project
   state** — a conductor, an override, a pinned designator, network config, a bus address, a
   reserve flag, or an orphan flag. Everything else is reconstructed at load by key-join against
   the template snapshot. Typical file drops ~70%.
2. **Deterministic port IDs.** For template-derived ports, `Port.id` is
   `uuidv5(deviceId, portKey)` rather than random v7, so materialisation is **idempotent across
   peers** — two machines that independently connect the same port produce the same ID and the
   sync design survives. (This is the piece the critique does not supply, and without it lazy
   materialisation would break the cloud-ready decision.)
3. **Reserve allocation** survives as `DeviceInstance.designatorWatermark`, not as thousands of
   placeholder entities.
4. **`EntityMeta` off `Port`** and off every other sub-object of a conflict unit — CR-095.
5. **Plain pretty JSON is retained**, re-justified against the corrected ~600 KB figure, and
   **explicit save moves to `Isolate.run`** alongside autosave.

### AC-007 · SEV-1 #4 — `measureText` returns `Pt`; the abstraction leaks at the baseline

**Accepted in full**, including the critique's important caveat that the shared-metrics approach
*does* work and is under-specified at exactly one point. **Change:** CR-081, CR-087. The parity
test asserts on **baseline Y**; `TextSpec` carries an explicit `TextAnchor` resolved in one
shared helper; both `kern` and `liga` are disabled on the Flutter side; a kerning-heavy fixture
(`"AV Wa To Ty"`) is asserted to agree within 0.5%.

### AC-008 · SEV-2 #8 — the 8 ms commit budget under-counts the wire-layer rebuild

**Accepted.** The budget counts one stroked polyline per wire; the actual per-run cost is
polyline + dash synthesis + arrowhead + **two tag pills** + junction dots + hop arcs — roughly
8–10 ops, so ~10,000 ops rebuilt on commit, not 1,000.

**Change:** L3a splits into **eight per-domain sub-pictures**, so an edit to one HDMI run
rebuilds ~1,200 ops and seven pictures replay untouched (nearly free, since paths are already
batched by colour class). Tag pills move to their own LOD-gated picture. The commit budget is
re-baselined to **≤ 16 ms** with ≤ 8 ms reserved for non-paint terms; nothing in the product
requires sub-frame commits. The perf harness measures **op count per layer** as the CI signal —
op count is stable across runners, wall time is not.

### AC-009 · SEV-2 #7 — the label cache is ~4× too small and the label count ~5× too low

**Accepted.** 200 devices × 20 ports × 2 runs (designator + label) + headers + 2,000 pill runs
≈ 10,000 text runs against a 2,000-entry LRU — and a thrashing LRU is worse than none, because
eviction disposes a native `ui.Paragraph` in the paint path.

**Change:** cache sized at **12,000** entries and keyed on `(text, styleId, quantisedScale)`;
the critique's second observation is the better fix and is adopted — port labels are drawn from
a small set of repeated strings, so *distinct* keys collapse to low thousands even at the hard
cap. The LOD gate becomes a **test**, not an intention: at fit-to-sheet zoom the assertion is
zero text runs laid out.

### AC-010 · SEV-2 #9 — multi-sheet is a v2 stack sitting on the critical path to the first PDF

**Accepted**, and reinforced by `critique-ux-simplicity.md`'s observation that a domain
partition has zero cross-sheet connections by construction. **Change:** CR-073, CR-074. The
first end-to-end PDF requires no `SheetItem` cross-sheet state, no off-sheet connector pairs, no
unit splitting, and no min-cut.

### AC-011 · SEV-2 #6 — rules-as-data cannot express the rules in the catalogue

**Accepted.** `NET-003` (reachability), `NET-004` (path enumeration with a per-hop predicate),
`ELE-004` (parallel impedance), `ELE-005`/`ELE-008` (aggregation and cascade budgets),
`BUS-005` (two independent limits, two findings) and `PWR-001` (sum with a derate) do not fit a
boolean predicate tree. Building the AST *and* a native escape hatch yields two rule systems,
two debuggers and two test suites — and the stated payoff, user-authored rules, has no UI in any
document.

**Change:** CR-024. Rules are Dart functions in a registry keyed by `ruleId`. What stays **data**
is substantial and is the part that actually needed to be data: rule metadata (message,
rationale, remedy hint, default severity, acknowledgeable), per-project severity overrides and
acknowledgements, forward-compat on unknown `ruleId`s in `AckedFinding`, and the
connector × signal-family **compatibility matrix**, which genuinely is a lookup table and needs
no AST. `RulePredicate` is deleted. The user-authored-rules claim is withdrawn from
`design-data-model.md §3.4`, and with it §3.4's third argument against enums — the other two
(growth rate, forward compatibility) still stand and the registry design survives on them.
This also closes the import-security hole in `critique-completeness.md D8`: there is no longer
an evaluated program arriving inside a `.rmlib`.

### AC-012 · SEV-3 #12 — the dotted-path override argument is self-defeating

**Accepted.** `design-data-model.md §3.2` rejects a typed override class because it "must be
edited in lockstep with `TemplateBody` forever", then proposes a hand-maintained
`TemplateBody.pathType(String)` table with the identical lockstep requirement, minus the
compiler check, plus a runtime validation pass (I-15) the typed version does not need.
`TemplateBody` is app-defined and closed; there is no forward-compat argument, because unknown
*keys* are already handled by `EntityMeta.unknown`.

**Change:** CR-053. Typed `DeviceOverrides` and `PortOverrides` with nullable fields — null
*is* the sparse "not overridden" semantics. I-15 and the path-type table are deleted; the
property inspector binds directly.

### AC-013 · SEV-2 #10 — `part of` for library-private setters will not scale

**Accepted.** `part of` files cannot carry their own imports; ~40 entity types plus ~30 command
types in one library means one library file importing everything and 70 parts that cannot be
reasoned about independently.

**Change:** `@internal` from `package:meta` — already a declared dependency — on entity setters,
which produces an analyzer error for consumers outside `rackmate_core`, and
`rackmate_ui`/`apps/rackmate` are different packages. Belt and braces: a grep test asserting no
entity setter is called outside `src/commands/`. `design-architecture.md §2.3` rule 2 is
rewritten.

### AC-014 · SEV-3 #16 — epoch masks are hand-declared with no verification

**Accepted, and promoted.** ~30 commands × 5 epochs assigned by hand with "when in doubt,
over-declare" produces stale renders, which are the hardest class of bug to reproduce.

**Change:** one generic test — for every command type, snapshot every derived output, apply,
snapshot again, diff, and assert the declared `touches` mask covers everything that changed.
~40 lines, permanent, and it is the **highest value-per-line test not already in the plan**.
Added to the M1 exit criteria.

### AC-015 · SEV-3 #15 — template snapshots are never refcounted

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
| #17 dash phase diverges on arcs; `dashPath` is on the hot path | Divergence documented in `docs/visual-language.md` so it is not chased later; **hops suppressed on dashed domains** (control and structure — the two where hops matter least); `dashPath` explicitly profiled in the perf harness rather than assumed cheap. |
| #18 `PdfTtfFont` must exist on the main isolate too | The metrics font is constructed **lazily on first paint**, not at bootstrap, and `stringMetrics` is cached aggressively. Added as the **sixth spike** so the cold-start cost is measured against the 1.2 s budget rather than assumed. |
| #19 Riverpod 3 moved `ChangeNotifierProvider` to legacy | Verified before the provider layer is written; the `epochs.revision` adapter is hand-written (~15 lines, `Provider` + `ref.onDispose`). The legacy library is not imported. |
| #20 "sub-millisecond at N=300" ignores that crossings are unbounded by N | Phase 5 moves off the commit path: the Bentley–Ottmann sweep and hop generation run **at paint time, viewport-scoped**. Hop rendering caps out to `gap` mode above a crossing threshold. X is measured on a real 300-connection fixture before the claim is repeated. |
| #21 stroke caps/joins/miter absent from `StrokeSpec` | `cap`, `join`, `miterLimit` added; both backends set them explicitly rather than inheriting (PDF default 10 vs Flutter default 4). CR-082. |
| #22 web has no isolates | One-line `kIsWeb` guard (CR-099). Web is not a v1 target. |
| #23 the touch intent layer is in the UX doc and absent from the architecture | `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` is built **first**, in M1, and no editor logic branches on `PointerDeviceKind`. This is a confirmed product decision ("architecture must not preclude touch"), so it is not optional. |
| #24 the round-trip invariant tests the wrong property | CR-117 — assert the byte round-trip. |

### AC-017 · SEV-1 #5 — there is no roadmap and the implied scope is 16–22 months solo

**Accepted as the most important finding in the corpus.** A design set this detailed with no
cost attached reliably produces a build that stalls at 40%. The bottom-up estimate is sound and
the two build orders in the design documents are engineering sequences, not plans — no
increments, no acceptance criteria, no cut list.

**Change:** Part 2 of this record carries the milestone plan and the binding v1 cut list. Its
shape follows `critique-completeness.md §E` (M0 reconciliation → spine → rack → wiring →
export → structure → builder → hardening) rather than this critique's cut table, because two of
that table's cuts violate confirmed product decisions (see RJ-002, RJ-003). The reconciliation
milestone — this document — is mandatory and is not compressible into the first coding
milestone; the six decisions in CR-001, CR-008, CR-017, CR-051, CR-083 and CR-081 each cost a
rewrite of everything downstream if guessed wrong.

---

## 2.2 From `critique-domain-realism.md`

The governing observation of this critique is accepted outright and is now a project principle:

> **The rack is where the gear lives. The job is the cable.** Every blocker below is the same
> mistake in a different costume — an assumption that the design is complete before the wire is
> pulled.

### AC-018 · B1 — a pull sheet cannot exist before the equipment list does

**Accepted. This is the most consequential finding in all four critiques.** I-25 and
`design-ux-schematic.md §2.3`'s "loose wires are prohibited by the system" make it impossible to
schedule a run to a device that does not exist yet — which is the state of every job in February
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
result. The DRC gains `LNK-020 advisory: 14 links have unbound endpoints` — a checklist, not an
error. `design-ux-schematic.md §2.3`'s rule survives in a narrower form: **dragging a wire onto
empty canvas still reverts** (that is a gesture, not a model constraint), but "Leave this end
open…" is an explicit command in the wire's context menu and in the schedule table.

### AC-019 · B2 — one home run is modelled twice, with two lengths and two test results

**Accepted in full.** Two rows for one cable is guaranteed to diverge within a week of real use,
and it is the precise failure that stops people trusting the document.

**Change:** CR-107. `StructureDrop` is **deleted**. A home run is a `Link` whose field end is a
`PlaceEndpoint` and which carries `Link.structureOrigin{structureBodyId, outletId, fieldLabel,
rackLabel, wall?, mountHeightAff?, terminationField}`. `Outlet` (CR-016) groups Links. The
Structure device's "ports" become a rendering of those links' field endpoints, not entities that
own a duplicate of the cable's physical facts. One row, one length, one certificate, one status.

### AC-020 · B3 — the power DRC fires on every correctly designed theatre rack and blocks export

**Accepted in full, including the power-factor gap the critique adds.** `PWR-001` as an error,
computed on nameplate, with `isContinuousLoad` defaulting true, with `blockExportOnErrors` true
and errors undismissable, makes a normal residential theatre rack permanently unexportable. The
design already stores `typicalWatts` and then chose not to use it for the number that matters.

**Change, all four parts:**
1. **Circuit loading uses `typicalWatts` × a per-category diversity factor** (amplifiers 0.35 of
   nameplate by default, switches 1.0, UPS 1.0), configurable per project. Nameplate becomes an
   *advisory* second line: *"worst-case nameplate 24.9 A — verify with a clamp meter at
   commissioning."*
2. **`apparentVA` and `powerFactor` are added** (CR-056). Circuit loading is computed in VA; UPS
   capacity is checked VA against VA. A linear-supply amplifier at PF 0.65 under-reports current
   by 35% under the `watts/120` formula, which is how a system that "calculated fine" trips a
   breaker.
3. **`PWR-001` becomes a warning** with an acknowledgement that prints (CR-020).
4. **`blockExportOnErrors` is deleted** (CR-022); **errors are acknowledgeable** (CR-019). The
   `design-data-model.md §3.5` position wins over `design-ux-rack.md §5.2`, as the critique
   recommends.

### AC-021 · M6 — one cable cannot carry more than one service

**Accepted.** One Cat5e to a TV location carrying an IR emitter run, a 12 V trigger and RS-232
on separate pairs is routine; so is a 16/4 carrying a speaker pair plus a spare pair later used
for a screen trigger. The current model forces three Links on one physical cable — three pull
rows, three lengths to keep in sync, and a `TOP-002`/I-25 fight over the designator.

**Change:** CR-010. `Link.services: List<Service>`; the schedule prints one row per cable with a
services sub-line — `W044 | Cat5e | 62 ft | LR-TV | IR (pr 3, wht/brn) · 12VTRG (pr 4, brn) ·
RS232 (pr 1–2)` — which is exactly what the trim tech needs and cannot get anywhere else. The
same treatment applies to home runs, since a home run is now a Link (AC-019).

### AC-022 · M7 — front and rear occupancy are checked independently, with no depth arbitration

**Accepted.** I-20 computes front and rear occupancy independently and `RCK-005` checks one
device against the rack, so a 16-in-deep amp at U19–U21 front and an 8-in rear-rail tray at U20
rear pass validation while physically fighting for the same air. This is *the* mistake in
shallow racks, which is most residential racks — and the data to catch it (`bodyDepth`,
`connectorProjection`, `depthOffsetFromFront`, `usableDepth`) is already modelled.

**Change:** depth occupancy is modelled as an **interval on the depth axis per (RU, face)**, not
a boolean, and `RCK-012 error: front depth + rear depth + 50 mm cable allowance > usable depth
for overlapping RU ranges` is added. Separately, `connectorProjection`'s auto-suggest of
`depth + 75 mm` is replaced by a value **derived from the deepest connector type actually on the
device's rear panel** — a molded HDMI with a bend is 100–125 mm and a compression-F on RG6 is
~100 mm, both of which the flat 75 mm under-reports.

### AC-023 · M8 — a device mounted backwards is not expressible

**Accepted.** Reversing a chassis so its rear panel faces out is standard practice in credenza
racks and 2-post frames, and today the rear-panel view would show those ports on the wrong side
— actively misleading on a rack where half the gear is reversed.

**Change:** `RailPlacement.chassisRotation: normal | reversed` (CR-031). A port's effective face
is `templateFace XOR reversed`. A ↺ badge draws on the elevation. The rear-panel view groups by
**access side**, not by template face.

### AC-024 · M9 — no length mechanism exists, so every length rule is decorative

**Accepted, including the sharpest part: silence reads as approval.** There is no floor plan and
the schematic is explicitly not to scale, so `calculatedLength` has no source; the fast entry
paths never ask for length; and `LEN-001` therefore never fires — not because runs are fine but
because there is no data.

**Change, all four:**
1. **`Location.estimatedRunLengthFromRack: Len?`** — one number per room, entered once, applied
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

### AC-025 · M10 — the schedule is organised for the person drawing it, not the person holding the cable

**Accepted in full.** A schedule that says W044 runs `MTX1:J09 → HBT-GRT:J01` with a schematic
zone reference requires two sheet flips to become actionable at 7 pm behind a rack, and carries
no room, no rack, no RU, no conductor colours, no termination detail, and nothing to initial.

**Change:** the single "wiring schedule" splits into **two presets of one derivation**:

| | **Pull Sheet** | **Termination Schedule** |
|---|---|---|
| Orientation | portrait | landscape |
| Default sort | **room, then pathway** — the order the tech walks the house | **rack, then panel, then port** |
| Rows | field cables only (AC-026) | all cables landing in the rack |
| Columns add | footage subtotals per room, jacket colour, `Pulled ☐ Terminated ☐ Tested ☐ Init ___` | T568A/B, punch position, polarity, conductor colour per role, pinout notes |

Both presets add, on **both ends**: location (`RK-1 / U14 / rear`, `Great Room / TV wall /
WP-1`) and **both labels** (`fieldLabel` and `rackLabel`). The critique's observation that the
dual-label insight was correctly identified for Structure drops and then not applied to every
cable is accepted — it now applies to every cable. `Conductor.colorCode`, which exists in the
model and appears in no output, is printed.

### AC-026 · B5 — patch cords will bury the schedule

**Accepted.** 110 rows of factory patch cords in a 180-row schedule makes the 70 rows that
describe real pulls indistinguishable from noise, and nobody labels a patch cord with a `W`
number.

**Change:** `Link.class: fieldCable | jumper | powerCord | internal`, auto-classified on
creation (both endpoints in the same rack, length under 2 m, factory-assembly media ⇒ `jumper`;
any link on a `power.*` family from a PDU outlet ⇒ `powerCord`) and user-overridable. The
wiring schedule **excludes `jumper` and `powerCord` by default**, with a toggle. Jumpers roll up
into the materials list by media + length + colour. PDU outlet assignments appear on the power
schedule as an **outlet map**, not as twenty cable rows. The netlist and `Trace` still include
them — they are real, they just do not belong on a pull sheet.

### AC-027 · M13 — no low-voltage/line-voltage separation and no plenum enforcement

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
outranks ours — but the finding must exist.

### AC-028 · M14 — no unsupported-weight model

**Accepted.** A 34 lb amplifier or a 48 lb UPS on front ears alone sags, strips the rail
threads, and eventually comes out of the rack; every install manual for heavy gear says so, and
rear-support brackets are a standard rack BOM line the materials list currently cannot know
about.

**Change:** `TemplateBody.maxUnsupportedMass: Mass?`, defaulting to ~7 kg (15 lb) for
`mountMethod: rackEars`. `RCK-013 warning: DEVICE (34 lb) mounted on front ears only; requires
rear support or a shelf.` The support hardware is added to the materials list.

### AC-029 · M11 — a `Link` cannot span three devices

**Accepted.** A dual-head IR emitter and a multi-pair snake are one cable, one part number, one
pull, N devices. **Change:** CR-014.

### AC-030 · M12 — two rules that fight correct designs

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

### AC-031 · B4 — the seeded catalog has no field devices, and three shipped rules can never fire

**Accepted, and the second half is the decisive part.** All 62 templates live in or near the
rack. There is no display, projector, speaker, camera, AP, touchpanel, keypad, wall plate, or —
most conspicuously — the ISP gateway that is physically present in every residential rack in
North America. And because impedance and tap wattage live on the speaker, `ELE-004`, `ELE-005`
and `ELE-006` — three of the most valuable rules in the product — **can never fire**: the
objects they operate on do not exist.

**Change:** a **Field Devices** category of 18 templates ships in v1 (CR-061), all
`mountMethod: notInRack`, occupancy zero, authored through a **stripped builder form** — identity,
ports, location; no RU, no rack depth, no thermal class. The shipping set: display · projector ·
projection screen (it has a trigger and a power feed) · in-ceiling speaker pair · in-wall
speaker · subwoofer · outdoor speaker · 70 V pendant with a tap selector · IP camera · NVR ·
wireless AP · touchpanel · keypad · volume control · IR receiver eye · ISP gateway/ONT · OTA
antenna · F-type ground block. Speakers carry real `impedanceOhms` and a `tapWatts` selector so
the audio rules have something to evaluate.

### AC-032 · m15 — auto panel layout flows connectors across 482.6 mm

**Accepted.** 482.6 mm is the *panel* width including ears; connectors live on the chassis at
~432–442 mm, so the auto-layout would draw jacks out past the rails on the view that gets taped
inside the rack door. **Change:** `TemplateBody.chassisWidth`, defaulting to 432 mm for
`widthClass: full`; the layout flows within it, centred on the panel.

### AC-033 · m16 — power sequencing has data and no rules

**Accepted.** `sequenceStep` and `sequenceDelayMs` are modelled and a sequencer ships, with no
rule enforcing the one thing sequencing exists for. **Change:** `SEQ-001 warning: amplifier on
sequencer step 1 of 4 — amplifiers should be last on and first off.` A reversed sequence thumps
and blows drivers.

### AC-034 · m17–m24 — the remaining minors

All accepted; each is small and each changes a number or a default that reaches a drawing.

| # | Finding | Change |
|---|---|---|
| m17 | NCS sheet-number regex fails a four-page residential set | CR-066 — `sheetNumbering: ncs \| simple`, default `simple`. |
| m18 | I-41 blocks export over a drafting footnote | CR-023 — deleted; the exporter fills it in. |
| m19 | `RCK-008` / `RCK-004` are permanent noise on wall and credenza racks | CR-020 — both **advisory and default off** for `wallSwingGate`, `wallPivotCabinet`, `wallFixed`, `credenzaFurniture`; on for floor enclosures. |
| m20 | "vent panels above high-heat devices" is backwards in a sealed enclosure | The heuristic is gated on `Rack.formFactor` and on whether a fan panel is present; in a sealed fan-cooled enclosure it fills with **blanks** to force air through the intended path. |
| m21 | Grounding is not modelled | Minimum viable version ships: an F-type ground block template (AC-031), a `power.bonding` signal family, and `Rack.groundBarPresent` feeding a note on the elevation. The full commercial bonding-detail sheet is deferred (RJ-009). |
| m22 | Cable IDs have no lock, and 60 labelled cables can be renumbered by accident | CR-034 — `Link.designatorLocked`, auto-set at `RoughInStatus >= pulled`; renumber refuses locked IDs and reports the count. |
| m23 | TIA-570-D grades are a vocabulary integrators do not speak | CR-108 — outlet templates first-class, grades as presets and a standards tag. |
| m24 | `Outlet` demands `wall` and `mountHeightAff`, meaningless for a ceiling speaker pair | The outlet template drives which location fields apply; `mountSurface` gains `ceiling \| floor \| soffit \| exterior \| inGround`, none of which demands a compass direction. |

---

## 2.3 From `critique-ux-simplicity.md`

The thesis is accepted and is now principle G1: the design states that the schedule is the truth
and then spends roughly 70% of its effort on the diagram. Several of its specific cuts are
rejected in §3; the following are accepted.

### AC-035 · The three prioritisation fixes

**All three accepted, verbatim.**
1. `blockExportOnErrors` never blocks a deliverable — CR-022, and I go further and delete the
   setting.
2. Invariant I-41's export block is deleted — CR-023.
3. **The schedule table is the second tab in the app**, reachable from an empty project and
   populating live as connections are made — CR-105. It should be the thing the user watches
   fill up, not the thing they discover at export.

### AC-036 · Cut #2 — `SignalRoute`

**Accepted.** Duplicates `critique-feasibility.md #11`; see AC-016.

### AC-037 · Cut #4 — `Sheet` as a document entity, partially

**Finding accepted; the entity is kept.** Multi-sheet as a *document* feature is cut (CR-073)
and the expensive drafting apparatus around it disappears — but the `Sheet` entity itself ships,
holding exactly one schematic sheet, so the file format never migrates when multi-sheet lands
(G5). Deleting the entity to re-add it later is a migration; keeping it is one map with one
member. The critique's own key insight — a domain partition has zero cross-sheet connections —
is what makes the expensive half free to cut.

### AC-038 · Cut #5 — layers

**Accepted.** **Change:** CR-064.

### AC-039 · Cut #6 — the fabricated-data problem

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

### AC-040 · Cut #7 — the DRC catalogue, partially

**Finding accepted, magnitude adjusted.** ~60 rules is not shippable in v1 and each is a chance
to be confidently wrong about a system the user knows better than the app does. Six is too few:
`critique-domain-realism.md` adds five rules of its own, three of which (`RCK-012`, `CODE-001`,
`CODE-002`) protect the user from real money.

**Change: v1 ships 22 rules**, listed once in `docs/rules.md`:
`TOP-001..005` (blocking) · `SIG-001` · `SIG-002` · `DIR-001` · `DIR-003` · `CON-001` ·
`ELE-003` · `ELE-006` · `NET-001` · `PWR-001` · `PWR-003` · `LEN-001` · `RCK-001` · `RCK-002` ·
`RCK-003` · `RCK-012` · `RCK-013` · `CODE-001` · `CODE-002` · `LNK-020`.
Everything else moves to v1.2 behind a fixture corpus (AC-051). The acknowledgement machinery is
**kept** (RJ-006).

### AC-041 · Cut #8 — template versioning and the Update Manager, partially

**Accepted for v1.** The semver classifier, the two-column diff view, the safe/additive/breaking
grouping, the per-cable remap ranking and the conflicts-with-local-edits merge together
constitute a package manager, and v1 does not need one.

**Change:** v1 is **copy-on-place**. `templateRef{templateId, version, contentHash}` is still
recorded and the snapshot is still embedded, so nothing about the format changes when updates
land in **v1.2** — which is exactly the critique's own recommendation and is a G5 item. v1 shows
a passive "this device is based on an older catalog template" badge (CR-062) and offers only
"Fork to a new template". The `[Del]` button never ships at all (CR-052).

### AC-042 · Cut #10 — template file infrastructure, partially

**Accepted:** `.rmlib` library packs, the `signature` field, and the `provenance` /
`derivedFrom` *chain* are cut from v1. **Not accepted:** `contentHash` survives — it is three
lines, it is the snapshot-integrity guard, and it is what makes the embedded-snapshot argument
true. But I-8's "hash mismatch is a **hard load error**" is demoted to a **warning plus a badge
on the affected devices**: refusing to open a project because a snapshot was hand-edited is a
data-loss event dressed as a safety feature. Single `.rmdev` export and import stay in v1 —
they are the unit people email each other, and the plain-JSON diffability argument is one of the
few genuine differentiators in the product.

### AC-043 · Cut #11 — shelves, stripped

**Accepted.** Hosted devices are real and common; the interaction model around them is not.
**Change:** auto-pack left to right; `ShelfPlacement.order` decides sequence; free lateral
positioning, `Alt`-drag, the third focus level entered with `Enter`, and per-host depth-overhang
warnings all defer. `lateralOffset` stays in the format (CR-029) because it is one nullable
field and the free-position case is real; only the UI defers.

### AC-044 · Cut #12 — 0U gutters, partially

**Accepted for the interaction, rejected for the model.** The 16-px gutters, rotated bar
rendering, drag-into-gutter, resize handles, the `G` toggle and channel-overlap warnings all
defer to v1.1. `ZeroUPlacement` **stays in the sealed union** — a 0U PDU is a real rack occupant
that contributes weight, outlets and ports, and modelling it as `OffRackPlacement` is a lie that
would show up in every outlet-accounting number. In v1 a 0U occupant is created and edited from
the inspector (channel, start U, span) and renders as a plain bar; there is simply no drag
gesture.

### AC-045 · Cut #13 — auto-arrange with trade heuristics

**Accepted.** The design's own note that "integrators have strong and differing opinions" about
heavy-low, amp spacing, vent-above-heat and 15% spare RU is the argument for *not shipping it*,
not for shipping it with per-rule checkboxes. **Change:** v1 ships **Compact Down** and
**Compact Up** only, both with the preview-then-accept pattern that is already designed and is
the best interaction in the rack spec. `Auto-arrange` and `Fill gaps with blanks/vents` defer to
v1.2, the latter with m20's form-factor gating.

### AC-046 · Cut #14 — the keyboard surface, and the collisions

**Accepted, including that the collisions are a bug and not a preference.** ~170 bindings across
two documents, colliding on 16 keys, with `Shift+F` double-bound inside one table.
**Change:** CR-101 — ~40 bindings, one arbitrated table, generated from one `Intent` registry.

### AC-047 · The nine identifier systems

**Accepted.** `refDes`, `name`, `typeName`, port `designator`, port `userLabel`, link
`designator`, net name, drop `fieldLabel`, drop `rackLabel` — the design is right that these are
distinct concepts and wrong to expose all nine in v1.

**Change:** v1's **default** UI exposes three: device designator, port label, cable ID. The rest
exist in the model and appear in the schedule, the inspector's advanced section, and the PDF —
where they are needed and where a professional expects them — but none of them is on the primary
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
Also accepted: the empty `Location` combobox on field two of the very first dialog is removed —
location is set later, from the rack inspector or the Locations panel.

### AC-049 · The device builder's real barrier is the 25 metadata fields, not the port grid

**Accepted, and it is the right diagnosis.** The port grid is excellent — spreadsheet
ergonomics, fill-down, TSV paste, archetype generators — and the barrier in front of it is
twelve physical fields and six power fields, most of which the user does not know and half of
which are absent from the spec sheet in their hand. The result is either a guess (feeding G4's
problem) or a stall.

**Change:** **three required fields — name, RU height, designator prefix — then ports, then
done.** Everything else is optional with a visible `unknown` state that the app degrades
honestly around (CR-114). A template saved with three fields is not "incomplete"; it is a
template. The `Draft` flag survives only for templates saved with *zero* ports and no category.

---

## 2.4 From `critique-completeness.md`

### AC-050 · §A — the unmet-requirement findings

Accepted, with the ruling for each:

| Finding | Ruling |
|---|---|
| **A1.1** no agreed maximum RU | CR-038 — 1..60. |
| **A1.3** 2-post racks have no meaningful `usableDepth` | `usableDepth` becomes nullable and the depth rules skip when it is null; `RackFormFactor.openFrame2Post` documents rail-to-rail only. |
| **A2.1** no UI for creating registry entries, while user-extensibility is the central argument against enums | Partially accepted — see RJ-011. The user-authored **rules** claim is withdrawn (AC-011); a **media-type editor** and **connector aliases** ship (the Structure CSV import already creates media types, and that is correct); a full registry editor does not. |
| **A2.2** the connector footprint table has 13 entries for a catalog using ~35 connector types | Accepted — the "zero-authoring correct rear panel" claim is false as written. The table is completed for **every connector in the shipped catalog**, and a CI test asserts that every `ConnectorTypeDef` in the catalog has a footprint. |
| **A2.3** no undo model for the builder or Structure editor | CR-106. |
| **A2.4** no empty state, no DSL parse-error design, no autocomplete spec | Accepted into the hardening milestone; the DSL's discoverability argument is void without the autocomplete that teaches it. |
| **A2.5** the label-pattern grammar cannot express its own catalog (`A03`'s two simultaneous cycling sets) | Accepted — the grammar gains an explicit period on cycling sets, `{FL,FR,C,SL,SR,SBL,SBR}@7` and `{+,−}@1`, and the offending catalog entry is re-authored. |
| **A3.1** multi-conductor links have no UI in any document | Accepted — see AC-053. |
| **A3.2** no cable-length mechanism while eight rules depend on one | AC-024. |
| **A3.3** connections can only be created in the schematic, never stated | CR-105. |
| **A3.4** staged devices have undefined schematic layering | Staged devices get a `SheetItem` at insertion (CR-104) and are laid out as ordinary leaf nodes; rack position simply does not participate in their tie-break. |
| **A4.1** the brief names ten cable **types**; every document colours by **domain** | Accepted as a requirement deviation needing explicit sign-off — see AC-054. |
| **A4.2** per-type colour override is deferred to "later" | Accepted — it ships in v1 (AC-054). |
| **A4.3** no `SignalDomain` entity exists to hold the domain palette | CR-078. |
| **A5** port pinouts are modelled and never rendered | Accepted — the Termination Schedule (AC-025) prints pinout and conductor colour; the `T5.01` plate/pinout detail sheet stays auto-on when a non-standard pinout exists. |
| **A6.1–A6.4** Structure gaps | CR-108, CR-109, CR-110, CR-112. |
| **A7.1** `blockExportOnErrors` deadlock | CR-022. |
| **A7.2** the acknowledgement appendix is promised by three documents and appears in no sheet list | CR-022 — sheet `T0.02`. |
| **A7.3** the BOM is referenced by four documents and designed by none | Accepted — see AC-055. |
| **A7.4** no page-count bound or preview | Accepted — the export dialog's dry-run already computes the sheet count; it now also warns above 40 sheets and hard-caps at `maxPages: 2000`. |
| **A8.1** mobile read-only designed for 1 of 4 surfaces | Accepted with scoping — see AC-056. |
| **A8.2** the template library has no implementation home in the architecture | Accepted — `rackmate_core/library/` gains the `.rmdev` codec, its own migration chain, and a library directory service; `apps/rackmate/lib/library/` gains import/export. Its absence was an oversight. |
| **A8.3** tombstones, `EntityMeta` and `FracIndex` are absent from the architecture | CR-095, CR-027. |

### AC-051 · §D15 — ~60 rules with electrical consequences have no test strategy

**Accepted, and it is the most serious of the D-findings.** `DIR-003` describes an action that
destroys hardware; `ELE-004`/`ELE-006` describe actions that damage amplifiers. The architecture
document tests migration, commands, scenes and PDF structure — not the domain logic that is the
entire wedge.

**Change:** a **DRC fixture corpus** — for every shipped rule, at least one known-bad design that
must produce exactly that finding and one known-good near-miss that must not. The corpus is a
directory of `.rackmate` files and an assertion table. **No rule ships without its pair**, which
is also the gate that keeps the v1 catalogue at 22 (AC-040). A domain-expert review of the
shipped rules and of the catalog data is a named milestone exit criterion.

### AC-052 · §C36 / §D2 — catalog data provenance and sample projects

**Both accepted.**
- **Provenance:** every numeric field in every shipped template carries a cited source
  (manufacturer datasheet, published standard, or measured), recorded in
  `assets/catalog/sources.md`. A template whose safety-adjacent fields (`pinoutVariant`,
  `impedanceOhms`, `poeBudgetWatts`, `maxUnsupportedMass`) are uncited does not ship. This is
  the gate that sets the catalog count (CR-061), not a target number.
- **Sample projects:** the four starter projects are authored as **real `.rackmate` files** and
  do triple duty as the golden corpus, the performance fixtures, and the screenshot source. At
  least one exercises the Structure device and at least one exports cleanly to a full sheet set —
  as listed today, none demonstrates either differentiator.

### AC-053 · §A3.1 — multi-conductor links have no UI

**Accepted; the model ships, the gesture defers.** `design-data-model.md` calls one-cable-many-
conductors load-bearing decision #4 and then no document specifies the gesture that creates a
four-conductor link, how conductors are displayed or edited, or what a partially-connected group
does. Component video and stereo speaker runs — both in the seeded catalog — are unbuildable as
designed.

**Change:** `Conductor` and `PortSetDef.atomicConnect` ship in the model and the format. The v1
**gesture** is limited to `atomicConnect` sets: dragging from any member of a set connects the
whole set in one action, producing one Link with N conductors, and the roles are assigned by the
set's declared order. Hand-authoring an arbitrary conductor map defers to v1.1. A 16/4 run to two
zones is therefore one Link with four conductors in v1 — which is the case the whole decision
exists for.

### AC-054 · §A4.1/A4.2 — the brief says "colour-coded by cable type", the design colours by domain

**Accepted as a genuine deviation from a stated requirement, and it is resolved rather than
absorbed.** The technical argument is correct and is not reversed: no palette is CVD-safe past
~9 categories, and Okabe-Ito's greyscale claim is demonstrably false (Sky Blue 0.4050 vs Orange
0.4162). But the requirement names ten specific types, and today *Analog RCA* and *speaker level*
share one orange, and *S/PDIF* and *TOSLINK* share one vermillion.

**Change, three parts:**
1. **Hue = domain; dash + weight + tag = type.** Unchanged, and the argument is written into the
   legend sheet so the reader sees why.
2. **The legend prints one row per named cable type**, not per domain — each showing that type's
   exact rendering (hue, dash, weight, tag) in colour and in greyscale side by side. All ten
   types the brief names are individually identifiable on the legend and on the drawing.
3. **Per-family colour override ships in v1.** `SignalFamilyDef.colorOverride` already exists in
   the model (CR-078); it needs a settings row, not an architecture. Deferring it to "later"
   while the requirement says "colour-coded by cable type" is not defensible.

Plus a commitment the design makes implicitly and never tests: the legend is **verified against
deuteranopia and protanopia simulation and against a real greyscale laser print** before v1
ships, as a named acceptance criterion (AC-058).

### AC-055 · §A7.3 — the BOM is referenced everywhere and designed nowhere

**Accepted.** `SheetKind.bom`, `bom_table.dart`, `Money`, `cost`, `supplier`, `purchaseOrder`,
"excluded from BOM active-device totals", "total cost when a BOM exists" — a feature four
documents assume and none specifies.

**Change:** v1 ships an **Equipment List and Materials sheet** (`T6.30`), not a BOM. It has no
pricing: quantity, designators, manufacturer, model, description, RU, rack, location, face,
weight, draw, status, notes — plus the cable footage rollup by media (AC-024) and the hardware
implied by rules (ear kits, rear supports). `Money`, `cost`, `supplier` and `purchaseOrder` are
**deleted from v1**; a priced BOM is an adjacent product and no requirement asks for one.

### AC-056 · §A8.1 — mobile read-only is designed for one surface of four

**Accepted with explicit scoping**, since the confirmed decisions require mobile read-only in v1
and only `design-ux-rack.md §1.2` designs any of it.

**Change:** v1's mobile/tablet mode is **read-only viewing of three surfaces** — the rack
elevation (already designed), the **schedule table** (a real `DataTable`, trivially responsive,
and the artifact a reviewer most needs), and the **exported PDF**. The schematic canvas and the
device builder are **not** available on mobile in v1, and the app says so rather than shipping a
squeezed editor. This honours the confirmed decision honestly instead of nominally.

### AC-057 · §C4 — do device images ship in v1

**Accepted: no.** `design-ux-device-builder.md §1.5` already calls them a scope trap and states
they are "not needed for correct output". Cutting them resolves the container question (CR-091),
removes the image-decode bounds from the import-security surface, and removes ~1 MB per template
from the size budget. `frontImage`/`rearImage` are removed from `.rmdev` v1.

### AC-058 · §D1, D3, D4, D5, D7, D8, D10, D11, D12, D13, D14 — the cross-cutting gaps

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
| **D10** distribution and code signing are absent — the largest unowned area | Named as a milestone with its own lead time: Windows OV/EV certificate procurement **starts two milestones before release** because reputation-building takes weeks; macOS notarisation and stapling; vendored pdfium (CR-100); a release pipeline with symbol archival. |
| **D11** the schematic and builder have no a11y design; ghost states are far below contrast thresholds | A fully specified **keyboard path to create a connection** (select port → `W` → `Tab`/`Shift+Tab` across *all* ports with announcements → `Enter`); a WCAG AA target named; filtered-wire alpha raised from 8% to a tested floor; rack device fills gain a non-colour encoding; an NVDA/VoiceOver test matrix. |
| **D12** the DSL, the CSV synonym table and all registry display names are structurally English-only | Registry display names become localisable maps; the DSL and synonym tables are documented as English-only in v1 with the localisation path named; `l10n.yaml` and the generation step are added to CI. |
| **D13** printer margins, colour management, greyscale beyond wires, no print test matrix | A "fit to printable area" vs "actual size" choice; greyscale rules extended to faceplate fills, tints and header bands; a **print test matrix on real hardware** — laser at ANSI B/A3, plotter at ANSI D, and a photocopy reproduction — because the entire dash-pattern argument is predicated on it. |
| **D14** "degrade gracefully" has no design; no progress or cancel except on export | Documented limits with a soft warning at 1.5× and an open-read-only gate at 3×; progress and cancel on **every** operation over ~500 ms (open, save, full DRC sweep, CSV import, catalog load). |

> **The D10 row's procurement schedule is superseded — see §12.9 and §11.6.** RackMate is an internal tool; signing is self-signed with a timestamp, Microsoft Trusted Signing is the named fallback at M8, and no OV/EV certificate is procured at any milestone. The rest of D10 — macOS notarisation, vendored pdfium (CR-100), the release pipeline with symbol archival — is **unaffected and still binding**.

### AC-059 · §E — the milestone plan

**Accepted as the plan of record**, with the adjustments already stated (AC-017). In particular
its two sequencing warnings are adopted verbatim: **M0 reconciliation is not compressible into
M1**, and the rules-as-code decision must be made **before** the wiring milestone, not during it
— it is the justification for several registry decisions and deciding it late means either
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

### RJ-001 · `critique-ux-simplicity.md` cut #1 — delete the editable schematic canvas and its layout engine

**The argument.** This is roughly half the remaining work: cycle-breaking, layering, barycentre
sweep, coordinate assignment, channel routing, track ordering, hop arcs, junction staggering,
pinning, preview-diff, four tidy scopes, unit splitting, buses, off-sheet connectors, zone
grids, sheet partitioning. Replace it by wiring on the rack elevation and *generating* a
read-only diagram at export time: "Nobody hand-edits a KiCad netlist report either."

**Rejected as stated. The reduction it implies is accepted.**

The requirement list is explicit on two points that this cut removes: *"The user makes physical
connections between devices to build a wiring plan"* and *"The wiring planner takes visual
inspiration from electronics schematics."* A generated, non-interactive diagram satisfies the
second and not the first — connections have to be made somewhere, and the elevation is the wrong
somewhere for a device with sixteen rear ports at LOD levels where ports are three-pixel ticks.

The deeper problem is that the cut proves too much. If the diagram is purely generated, then
symbol placement is never user intent, and the moment one user says "put the matrix above the
switch" the entire pinning/tidy machinery has to be built anyway — after the file format has
shipped without `SheetItem.pinned`.

**What is accepted from it**, and it is most of the cost: unit splitting (CR-070), buses,
off-sheet connectors and cross-refs (CR-073), min-cut and geometric partitioning (CR-073),
preview-diff with variant cycling and the four tidy scopes (CR-068), `Trace` and the search DSL
(AC-040 deferrals). What remains in v1 is the Sugiyama pipeline phases 0–4 plus channel routing
— which `critique-feasibility.md` independently rates as sub-millisecond and which is the
cheapest part of the list — plus drag-to-connect, chain-draw, multi-draw, magnetic snap, pinning
on manual move, and one `Tidy sheet` command. That is a fraction of the cut's target and it
keeps the requirement.

> **Superseded — see §12.1 (§7.2.3 router row).** Phases 0–3 only; no channel routing, no phase 5.

### RJ-002 · `critique-ux-simplicity.md` — "pick one view for v1; wire on the rack elevation"

**The argument.** Two canvases means two mental models, two coordinate systems, two selection
behaviours, two colliding shortcut tables, and a what-syncs-what table the user meets as a
surprise before they meet it as documentation. The rear elevation is *already* the wiring
surface by the schematic document's own words. Port badges (`→ SW-01 P04`) replace drawn lines;
lines appear only under a filter or on hover.

**Rejected.** This is the strongest rejected argument in the set and it is rejected on evidence
rather than on principle.

1. **It does not survive the density it is meant to fix.** A whole-house system is dominated by
   rack→room runs. The proposal answers that those are Structure drops rendered as a flag bank —
   true, and it means the elevation gutters carry the *field* cables while the intra-rack cables
   become port badges. A 24-port patch panel to a 24-port switch then renders as 24 badges
   reading `→ SW-01 P04`, which is a table drawn in the worst possible place.
2. **It deletes the requirement, not just the view.** "Takes visual inspiration from electronics
   schematics" is not satisfiable by a badge on an elevation, and generating the schematic for
   export only (RJ-001) means the user cannot influence a drawing they are contractually handing
   to a client.
3. **The failure it predicts is real and is fixed more cheaply.** Cliff #1 and cliff #2 are
   genuine and are addressed directly — CR-105 signposts wiring from the elevation, CR-104
   removes the two-places-to-add-a-device ambiguity, CR-101 removes the colliding keymaps, and
   the sync table's two exception rows get a coach mark at the moment of surprise (AC-048).
   Those four changes cost days. Deleting a view costs a requirement.

The positions-are-not-linked argument in `design-ux-schematic.md §5.2` is correct and is
upheld: an AVR sits at U14 for thermal reasons and mid-chain for logical ones, and slaving
either to the other destroys work silently and unrecoverably.

### RJ-003 · `critique-ux-simplicity.md` cut #3 — derive `Net` in v1

**The argument.** The defence of stored nets is well-argued but every argument for it is about
buses, 70 V taps, RF cascades and terminators, all of which are being cut. Without user-named,
coloured, `N###`-designated nets, the label-flicker objection evaporates. Keep the JSON field
for forward compatibility; ship zero UI.

**Rejected.** The premise is wrong about what is being cut. `ELE-005` (70 V tap sum), `ELE-004`
(parallel low-Z), `ELE-008` (RF cascade) and the `BUS-*` family are deferred, not deleted, and
`critique-domain-realism.md B4` is simultaneously demanding the speaker templates that make
`ELE-004/005/006` fire — so the multi-endpoint semantics come back in v1.2, not never.

More decisively: this is a G5 violation in the exact shape G5 was written for. `Service.netId`
is **one foreign key**. Shipping it costs a field; adding it later means reconstructing
membership for every existing project by union-find and then asking the user to confirm the
result — which is precisely the "labels flicker on merge" failure the design rejected. "Keep
the JSON field, ship no UI" is what I am doing: v1 auto-creates an implicit singleton net per
service, exposes no net editor, and the FK is authoritative from day one.

### RJ-004 · `critique-ux-simplicity.md` cut #9 — the Structure editor's advanced half

**The argument.** Keep the room × media matrix and a flat drop table. Cut the TIA-606 pattern
engine and five label presets, bundles, CSV import with synonym mapping, `RoughInStatus`,
`TestResult`, multiple Structure instances, jacket colour, conduit, reel ID, and **dual
field/rack labels** — the last conceded as "a genuinely good observation from the field" and
"also a v2 observation."

**Rejected in substantial part.** Four of these are the product.

- **Dual labels stay.** `critique-domain-realism.md` — the field voice — calls two labels per
  drop with both printed "the single most valuable line in these four documents", and names the
  mismatch between the plate label and the panel label as *the* most common on-site failure.
  It costs one nullable string and one column. Cutting it to save that is not a trade.
- **CSV import stays.** It is not a convenience feature; it is the *entry path* for the workflow
  `critique-domain-realism.md B1` says the whole product currently fails — the contractor's pull
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

### RJ-005 · `critique-ux-simplicity.md` cut #6 — reduce the derived metrics to two numbers

**The argument.** Cut circuits, NEC derates, PoE budgets, BTU, centre of gravity, thermal class,
clearance, outlet accounting and the nameplate/typical toggle. Keep only RU used/free and weight
vs capacity — "both facts the user actually supplies."

**Rejected in part; the reasoning is accepted in full (AC-039).**

The diagnosis is exactly right and is now principle G4. The remedy is wrong because it cuts the
wrong half. Power is the number one reason a rack fails in service, and
`critique-domain-realism.md B3` is simultaneously arguing that the power model needs **more**
fidelity — apparent VA, power factor, diversity factors — not less. Two critiques point in
opposite directions here and the field voice wins: an integrator will forgive a missing BTU
figure and will not forgive a tool that let them put 25 A of amplifiers on a 20 A circuit
without a word.

**The binding resolution:** keep RU (front and rear), weight, **power in VA**, and outlet
accounting in the always-visible chip strip. Move BTU/hr, centre of gravity and thermal
adjacency to a collapsed advisory panel, closed by default. Delete every silent estimate
(CR-114, G4). No computed number blocks anything (CR-022, G3). The user is never shown a number
the app invented.

### RJ-006 · `critique-ux-simplicity.md` cut #7, second half — delete the acknowledge-with-reason machinery

**The argument.** It is "exactly right for a professional as-built deliverable and exactly wrong
for minute 10 of someone's first session, where it presents as 'type an essay to dismiss this
yellow triangle.'"

**Rejected.** The first half of cut #7 — 60 rules down to a shippable few — is accepted (AC-040,
at 22). The acknowledgement machinery is the thing that makes the reduced rule set *safe*:
because errors are acknowledgeable (CR-019), nothing has to block (CR-022), which is what makes
G3 implementable. Delete acknowledgement and the only remaining ways to handle a rule the user
disagrees with are to block them or to silence the rule globally — and the design correctly
identifies both as the failure modes that make people route around the tool.

It is also the as-built differentiator: an acknowledgement that prints — *"W042 — HDBaseT on
Cat6 patched via SW-1 port 12. Reason: existing condition, to be corrected in Phase 2. —
R. Riley, 2026-07-18"* — turns the DRC list into a remediation scope, which is a deliverable
integrators currently get from nothing.

**The first-session concern is answered without cutting it:** the reason field is required only
for a **project-wide** mute; a single-instance acknowledgement takes one click and offers a
reason field that may be left empty. The essay is only demanded where the consequence is
permanent.

### RJ-007 · `critique-ux-simplicity.md` #15 — ship the catalog at lower fidelity

**The argument.** Keep the seeded catalog but drop typical watts, BTU, clearance and thermal
class from all templates. It halves the authoring effort and stops feeding the fabricated-data
problem.

**Rejected.** It stops feeding the fabricated-data problem by removing the data instead of the
fabrication, and it takes the wrong fields with it. `typicalWatts` is the field that
`critique-domain-realism.md B3` shows is *required* for the power maths to be correct at all —
nameplate is a UL thermal rating that no integrator sizes a circuit on. Removing it does not
make the app honest; it makes the app compute breaker loading from a number everyone in the
trade knows is wrong.

The fabrication problem is fixed at its source instead: `typicalWatts` no longer defaults to
half of nameplate, unknown is null, null is displayed and counted (CR-114, AC-039), and every
shipped template's numbers carry a citation (AC-052). Clearance and thermal class are cheap and
feed rules that are deferred rather than deleted; they stay in the catalog and their rules are
default-off.

### RJ-008 · `critique-feasibility.md` #5 — the proposed v1 cut list

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
- **Cutting Structure matrix entry and CSV import is rejected** for the reasons in RJ-004 —
  they are the entry path for the workflow the field critique says is currently impossible.

Everything else in the cut table is accepted and appears in §2: `SignalRoute` (AC-016),
multi-sheet (AC-010), rear-panel view (CR-071), the rule reduction (AC-040), auto-layout
preview variants (CR-068). `Circuit` is retained but simplified (CR-028); `RevisionEntry` is
retained because the revision block generates from it and a drawing set without a revision block
is not a drawing set.

### RJ-009 · `critique-feasibility.md` #6 — withdraw the user-extensibility claim wholesale

**The argument.** With rules moved to code, "you lose only user-authored rules, which have no
UI", and §3.4's enum-rejection argument should be weakened accordingly.

**Accepted for rules; rejected for registries.** User-authored *rules* are withdrawn (AC-011).
User-extensible *registries* stay, because one of them is already load-bearing in a shipped
flow: `design-ux-device-builder.md §6.4` states that unmatched media values in a CSV import
"are **not** rejected — they are created as new user media types with a confirmation chip", and
that behaviour is correct and is the difference between an import that works and one that
throws. A media-type editor and connector aliases ship (AC-050/A2.1). §3.4's other two arguments
against enums — growth rate and the impossibility of round-tripping an unknown enum member —
are untouched by the rules decision and are sufficient on their own.

### RJ-010 · `critique-domain-realism.md` m21 — model grounding and bonding

**The argument.** No rack ground bar, no bonding conductor to the service panel, no coax ground
block, no TVSS. For commercial work the bonding detail is a required sheet; for residential the
coax ground block is a code item and a lightning-damage liability.

**Rejected for v1 beyond a minimum, accepted for v1.2.** The minimum ships now (AC-034/m21): an
F-type ground block template, a `power.bonding` signal family so a bonding conductor is
*drawable*, and `Rack.groundBarPresent` feeding a note on the elevation. The full model — busbar
entity, bonding-conductor sizing, a required bonding-detail sheet — is a commercial-market
feature that pulls in conductor sizing tables and a sheet type, and no residential v1 user is
blocked by its absence. The liability point is real and is discharged by making the ground block
present in the catalog and drawable, which is what puts it on the drawing.

### RJ-011 · `critique-domain-realism.md` B2, second half — `StructureBundle` becomes a bare grouping over Links

**The argument.** Delete `StructureDrop`; "the `StructureBundle` stays as a grouping over
Links."

**Accepted for the deletion (AC-019), rejected for the demotion.** `design-data-model.md §3.8`
is right that an outlet location is "the atomic unit of creation, specification and pricing" —
it is what "add a TV location" creates, what gets priced, what carries the room, the wall, the
mounting height and the conduit, and what the outlet templates of CR-108 instantiate. Reducing
it to an unnamed grouping loses the entity the fast entry paths are built on. It is renamed
`Outlet`, its members become Links, and it keeps its identity and its fields (CR-016).

### RJ-012 · `critique-completeness.md` A2.1 — build a registry authoring UI or drop the claim

**The argument.** There is no UI anywhere for creating a connector type, a signal family, a
media type outside Structure, a colour scheme or a compatibility rule — while user-extensible
registries are the central argument for rejecting enums. "Either build a registry editor or drop
the user-extensibility claim."

**Rejected as a binary.** The right answer is neither horn. Shipping in v1: a **media-type
editor** (already required by the CSV import flow — RJ-009), **connector aliases** (required by
the Quick Add DSL — CR-058), and a **per-family colour override** row in settings (required by
requirement 4 — AC-054). Not shipping in v1: a signal-family editor, a colour-scheme editor,
and a rule editor. The claim that survives is narrowed and true — *"media types and colours are
user-extensible; signal families and connector types are catalog-updated"* — and it is written
into `design-data-model.md §3.4` in that form. A signal family is not a thing a user should be
inventing casually: it carries direction defaults, topology, length limits, and rule
applicability, and a hand-rolled one produces silently wrong validation.

### RJ-013 · `critique-completeness.md` C25 — multi-document tabs

**The argument.** `design-architecture.md §8.6` says ship in-app document tabs; no UX document
shows them and no document specifies `Ctrl+N`/`Ctrl+O` with a dirty document open.

**Rejected for v1.** CR-119 — v1 is single-document, single-window, with a three-button
save prompt on replace. A tab strip with no design is not a feature, and the per-document
`ProviderScope` already makes tabs mechanical when they are designed. The finding that the
behaviour was unspecified is accepted; the feature is not.

### RJ-014 · `critique-completeness.md` D6 — an app update mechanism in v1

**The argument.** No app update mechanism exists; on Windows this means MSIX auto-update,
Squirrel, or manual downloads, and the choice affects signing and the installer.

**Rejected for v1; the dependency is accepted.** v1 ships a signed installer, a **"Check for
updates"** menu item that opens a download page, and a version string in the About box. Building
auto-update infrastructure before there is a release cadence is inventory. The part that
genuinely cannot wait — the code-signing certificate, whose OV/EV validation and reputation
build take weeks — is accepted and scheduled two milestones ahead of release (AC-058/D10). The
user-library migration half of D6 is accepted in full (AC-050/A8.2): `.rmdev` gets its own
migration chain, because a user's forty hand-built templates are the asset they will not forgive
you for breaking.

> **The certificate half is superseded — see §12.9 and §11.6.** There is no OV/EV validation and no reputation build, so nothing here needs scheduling two milestones ahead. RJ-014's actual ruling — no in-app auto-update in v1, a signed installer plus a version-check ping — is **reaffirmed**, and the `.rmdev` migration-chain half (AC-050/A8.2) is untouched.

### RJ-015 · `critique-completeness.md` D13 — tagged / accessible PDF

**The argument.** No PDF tagging or structure spec, despite "selectable text in the schedule is
a real differentiator."

**Rejected for v1.** dart_pdf's tagging support is limited and an accessible PDF is its own
investigation with its own acceptance criteria, and the document itself flags this. What v1
commits to is the part that is free and is what the differentiator claim actually rests on:
**text is real text, not outlines, and is selectable and searchable** — an installer can
`Ctrl+F` a cable ID in a three-page schedule. Full PDF/UA tagging is a named v2 investigation.
The rest of D13 — printer margins, greyscale beyond wires, and the real-hardware print test
matrix — is accepted (AC-058).

### RJ-016 · `critique-completeness.md` C21 — defer conductors and accept four rows for a 16/4 run

**The argument.** "Explicitly defer conductors to v1.1 and accept 4 rows on the pull sheet for a
16/4 run in v1."

**Rejected.** This is the one deferral that damages the deliverable rather than the tool. One
cable = one row on the pull sheet is the whole reason `Link`/`Conductor` was separated from
`Net` in the first place, and `design-data-model.md §3.6` argues it correctly: four rows for one
pull means four lengths to keep in sync, four labels for one cable, and an installer counting
four cables in a bag. Four rows on a pull sheet is a *worse* artifact than the Excel file the
product is replacing.

**What is accepted instead (AC-053):** the model and format ship conductors in v1, and the *v1
gesture* is limited to declared `atomicConnect` sets — dragging any member of a stereo pair or a
component-video triple connects the whole set in one action, producing one Link with N
conductors. Hand-authoring an arbitrary conductor map defers. A 16/4 to two zones is one row in
v1.

### RJ-017 · `critique-completeness.md` D9 — branding as a v1 requirement

**The argument.** No icon, logo, wordmark, splash, window icon, document icon or colour identity;
no file-type registration; no trademark search; and "for a firm handing drawings to clients, the
integrator's logo is close to table stakes" in the PDF title block.

**Accepted except for the last clause.** Icon, wordmark, window and document icons, file-type
registration for `.rackmate` and `.rmdev`, and a trademark search before any certificate or
domain is bought are all accepted into the hardening milestone (AC-058) — without file
association, double-click-to-open fails and the recents list is half-useful, which is a real
defect rather than a polish item.

**The integrator's logo in the title block is rejected for v1.** It requires a raster asset
inside the project, which reopens the container question that AC-057 just closed by cutting
images. The title block's *text* integrator block — firm, contact, licence number — ships in v1
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
catalogue, the visual language, the keymap, and the milestone plan with its cut list — all of
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
| **N1** | **One concept, one name, everywhere** — Dart identifier, JSON key, UI label, prose, commit message, and PDF column header all derive from the same entry in the glossary. Where the UI label must differ from the identifier (it often must — `Outlet` is "outlet location" to a user), both are listed and the mapping is fixed. |
| **N2** | **A banned word is banned in prose too.** `Connection` is not a synonym for `Link` in a comment. The words in §4.7 do not appear in the repository except in a migration note that explains their removal. |
| **N3** | **Types are `UpperCamelCase`; fields, JSON keys and Dart members are `lowerCamelCase`; registry IDs are `lower.dotted.snake`; format-engine tokens are `UPPER_SNAKE`; rule IDs are `AAA-000`.** No exceptions, including in `.rmdev` and `.rackmate`. |
| **N4** | **Units are in the name or in the type, never in a comment.** A field is `weightUg`, `depthNm`, `heightU`, `breakerAmps` — or it is typed `Mass`, `Len`, `Permille` and needs no suffix. A bare `weight` or `length` on a serialized field is a defect. |

`docs/glossary.md` is generated from §4.1–§4.6 and ships **in the app** as a searchable panel
(AC-058/D1). A name that is not in the glossary does not exist.

---

### 4.1 Core entity names

The binding entity vocabulary. "Owner" states which entity holds the foreign key; "Conflict unit"
states whether the entity carries `EntityMeta` per CR-095.

| Canonical type | UI label | What it is | Owner / key | Conflict unit |
|---|---|---|---|---|
| **`RackDocument`** | "project" | The in-memory mutable aggregate: flat UUID-keyed entity maps, mutated only through `Command`s. The thing `.rackmate` serializes. | root | ✅ |
| **`ProjectInfo`** | "project details" | Title-block metadata — client, site address, integrator, drawn/checked/approved by, drawing number. Field of `RackDocument`. | on document | — |
| **`ProjectSettings`** | "project settings" | Persisted per-project preferences: display units, ID formats, defaults, rule overrides. Field of `RackDocument`. | on document | — |
| **`Location`** | "location" | One node of the arbitrary-depth location tree (site ▸ building ▸ floor ▸ room ▸ zone ▸ outdoor). CR-047. | `parentId` self-ref | ✅ |
| **`Rack`** | "rack" | One physical enclosure or frame. Owns height, rails, depths, capacities, 0U channels. | `locationId` | ✅ |
| **`ZeroUChannel`** | "0U channel" | A vertical mounting channel inside a `Rack`. Sub-object, string-keyed within the rack. | inside `Rack` | — |
| **`Circuit`** | "circuit" | One branch circuit / breaker. Flat on the document with an optional `rackId`. CR-028. | `Circuit.rackId?` | ✅ |
| **`DeviceTemplate`** | "template" | The **mutable library** object. Lives in the catalog or user library. Never referenced by a device. | library | — |
| **`TemplateSnapshot`** | (not shown) | The **immutable, embedded** capture of a template at one version. Keyed `"$templateId@$version"`. | on document | — |
| **`TemplateBody`** | (not shown) | Everything physically true of the model. The payload of both of the above. | — | — |
| **`TemplateRef`** | (not shown) | `{templateId, version, contentHash}` — a device's pin to an exact snapshot. | on `DeviceInstance` | — |
| **`DeviceInstance`** | "device" | One piece of gear in this project. | `templateRef`, `placement` | ✅ |
| **`DeviceOverrides`** | "device overrides" | Typed, nullable per-instance overrides of `TemplateBody` facts. CR-053, AC-012. | on `DeviceInstance` | — |
| **`Placement`** | "placement" | Sealed union of five mounting variants. CR-031. Never called a slot. | on `DeviceInstance` | — |
| **`PortDef`** | (not shown) | The template-side port definition. Identified by `PortKey`. | inside `TemplateBody` | — |
| **`Port`** | "port" | The instance-side port. Graph identity; what a `Conductor` references. Lazily materialised (AC-006). | `deviceId` | ❌ |
| **`PortOverrides`** | "port overrides" | Typed per-port overrides. Lives **on the `Port`**, never in a device-keyed map. CR-053. | on `Port` | — |
| **`BankDef`** / **`Bank`** | "bank" | A **presentation** grouping of ports — drives symbol edges, brackets, collapse, and auto panel layout. CR-055. | `PortDef.bankKey` | ❌ |
| **`PortSetDef`** / **`PortSet`** | "port set" | An **electrical** grouping — Y/Pb/Pr, L/R, +/−, `atomicConnect`. Renamed from `PortGroupDef`. CR-055. | `PortDef.setKey` | ❌ |
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
| **`OutletTemplate`** | "outlet type" | A named recipe — "TV location", "AP", "Ceiling speaker pair". First-class; grades are presets. CR-108. | library | — |
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

**Registry types** — see §6 for their contents.

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
| `signalFamily` | `Service`, `PortDef`, `Net` | `SignalFamilyId` | CR-009 | on `Link` — it is derived there |
| `dominantSignalFamily` | `Link` | derived, **never serialized** | CR-009, CR-115 | a stored field |
| `netId` | `Service` | `Uuid`, non-null | CR-010 | on `Link` (deleted) |
| `lifecycleStatus` | `DeviceInstance`, `Link` | `existing \| new \| future \| removed \| designIntent` | CR-064, CR-065, AC-018 | `status` bare, `layerId` |
| `roughInStatus` | `Link` | `planned \| pulled \| dressed \| terminated \| tested` | CR-065 | `status` bare; `issued` is deleted |
| `fieldLabel` / `rackLabel` | `StructureOrigin` | `String` / `String?`, both project-unique, **both print** | CR-044, AC-047 | `label` / `TIA-606 ID` as field names |
| `code` | `Location` | `String` | CR-046 | `abbr` |
| `estimatedRunLengthFromRack` | `Location` | `Len?` | AC-024 | — |
| `usableDepth` | `Rack` | `Len?` (nullable — 2-post) | AC-050/A1.3 | — |
| `poeBudgetWatts`, `apparentVA`, `powerFactor` | `PowerProfile` | `int?` ×3 (`powerFactor` in permille) | CR-056, AC-020 | undeclared JSON keys |
| `nameplateWatts` / `typicalWatts` | `PowerProfile` | `int?` — **`typicalWatts` never defaults to half of nameplate** | AC-039, RJ-007 | — |
| `sequence` | `RackDocument` | `int`, strictly monotonic, persisted, the sync cursor | CR-094 | `revision` |
| `stateId` | `RackDocument` | in-memory only, non-monotonic, drives `isDirty` | CR-094 | `revision` |
| `schemaVersion` / `minReaderVersion` | envelope | `int` ×2 | CR-092 | — |
| `sheetEdge` | `StructureBody` | `left \| right`, default `left` | CR-072 | — |
| `mirrorRearElevation` | `Rack` | `bool`, default `true`, project default seeds it | CR-035 | a project-only setting |
| `groundBarPresent` | `Rack` | `bool` | AC-034/m21 | — |
| `containsLineVoltage` / `kind` | `Pathway` | `bool` / `PathwayKind` | AC-027 | — |
| `tia570Grade` | `Outlet` | `String?` — a **standards tag**, not an enum axis | CR-108 | `StructureGrade` |
| `isPathwayOnly` | `MediaTypeDef` | `bool` | CR-109 | — |
| `topologyFree` | `SignalFamilyDef` | `bool` | AC-030 | a hard-coded suppression array |
| `genderApplies` | `ConnectorTypeDef` | `bool` | CR-059 | — |
| `key` / `renamedFrom` | `PortDef` | `PortKey` / `List<PortKey>` — **the** template migration join | CR-051 | `portId` |
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
| **Locations panel** | `Project ▸ Locations…` — project-level, **not** owned by the Structure editor. CR-112. | — |
| **Structure editor** | Opens in **table mode**; matrix mode is a tab. AC-048/cliff #4. | — |
| **Device Builder** | Template authoring. **Three required fields** — name, RU height, designator prefix — then ports. AC-049. | — |
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
| Device designator | `{TYPE_PREFIX}{SEP}{SEQ}` — ships as `MTX-1`, `AMP-12` | CR-041 |
| Port designator | `J{PORT_SEQ:2}` → `J01`, **unique within the device** | CR-042 |
| Link designator | `W{SEQ:3}` → `W042` | CR-008, ASME Y14.44 |
| Cable end (implicit) | `P###` — not stored; ASME convention referenced on the legend | — |
| Net designator | `N{SEQ:3}` → `N012`; `Net.name` generated, editable, **never load-bearing** | CR-049 |
| Outlet field label | `{ROOM_ABBR}-{SERVICE}-{SEQ}` → `LR-TV-1` (preset: Residential CI) | CR-044 |
| Outlet rack label | `{FLOOR}{SPACE}-{PANEL}{PORT:2}` → `1A-A12` (preset: TIA-606 Class 2) | CR-044 |
| Rule ID | `AAA-000` — `TOP` `SIG` `DIR` `CON` `ELE` `NET` `PWR` `LEN` `RCK` `BUS` `CODE` `SEQ` `LNK` | CR-021 |
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
name — CR-045):

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
| **`.rmdev`** | A single device template. Plain JSON, same unit regime as `.rackmate` — `depthNm`, `weightUg`. CR-063. Has its own migration chain. AC-050/A8.2. |
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
| `SignalRoute` | — (cut from v1; `Trace` computes paths on demand) | AC-016/#11, AC-036 |
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
| `RendererCaps` | — (deleted; the interface is the common denominator) | CR-088 |
| `ObstacleField`, `RouteCache`, "obstacle-aware" | Sugiyama + interval-graph channel routing, full recompute | CR-013 |
| `RouteWaypoint`, `waypointsBySheet`, `routeOverrides` | — (no route geometry persisted in v1; `routeConstraintsBySheet` in v1.2) | CR-012 |
| `DeviceInstance.localTemplate`, `PlacedDevice.snapshot` | `RackDocument.templates` — one snapshot store | CR-054 |
| `Extent`, `Known`, `Unknown` | `null` means unknown, everywhere; rollups report their unknown count | CR-114, G4 |
| `calculatedLength` | `routedLength` / `cutLength` / `terminatedLength` | AC-024 |
| `StructureGrade` (enum) | `OutletTemplate` + `Outlet.tia570Grade: String?` | CR-108 |
| `Gender.jack`, `Gender.plug` | `male \| female \| genderless` + `ConnectorTypeDef.genderApplies` | CR-059 |
| `Severity.info` | `Severity.advisory` | CR-018 |
| "Class A" | spring-back with a reason chip | CR-017 |
| `Money`, `cost`, `supplier`, `purchaseOrder` | — (cut from v1; the sheet is an Equipment List, not a BOM) | AC-055 |
| `frontImage`, `rearImage` | — (cut from v1) | AC-057 |
| `Bay` | — (cut from v1, not reserved) | CR-033 |
| `Status` as a bare column header | `LIFECYCLE`, `ROUGH-IN`, or `ISSUES` | CR-065 |

> **Superseded in part — see §12.1 (§7.2.3 router row).** The banned names in the left column stand (§12.1, CR-013 row); the replacement named in the right column is now Sugiyama phases 0–3 plus a deterministic orthogonal staircase.

---

## 5. Canonical data model summary

### 5.0 Shape, after the Part 1 rulings

The document is a **flat set of UUID-keyed entity maps** — never a tree — mutated **only** through
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
- `Link → Conductor` is 1:N. A 16/4 speaker cable is **one Link with four Conductors** — one row
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
meets the building — PDU and UPS inlets and hardwired devices (CR-028).

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

A `Port` is **serialized only if it carries project state** — a conductor, an override, a pinned
designator, network config, a bus address, a tap, a reserve or orphan flag. Everything else is
reconstructed at load by key-join against the snapshot; typical files drop ~70% (AC-006).
Reserve allocation is `DeviceInstance.designatorWatermark`, not thousands of placeholders.

Template migration: join on `PortKey` (+ `renamedFrom`); a removed port with conductors is
**orphaned, never deleted**. The Update Manager offers `[ Remap ▾ ]` and `[ Keep as orphan ]`.
**There is no `[ Del ]`** (CR-052, AC-058/D5). v1 is copy-on-place; the update manager itself is
v1.2 (AC-041).

### 5.7 Wiring — Link, Service, Conductor, Net

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

`Outlet.roughInStatus` is **derived as the minimum** across its member Links — an outlet is as
complete as its least-complete run — and is **not serialized** (CR-111, CR-115).

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

Only five rules are model-level illegal — `TOP-001..005` (self-connection, duplicate ordered pair
on one link, over `maxConnections`, dangling endpoint, container cycle) — plus placement
coherence: `ruIndex` within the rack, host is a container, no containment cycle (CR-017).
v1 ships **22 rules**, listed once in `docs/rules.md`, each with a known-bad and a known-good
fixture. **No rule ships without its pair** (AC-040, AC-051).

### 5.9 Persistence contract

| Property | Binding value | Ruling |
|---|---|---|
| Container | Plain, pretty-printed, key-sorted UTF-8 JSON. `DocumentCodec` sniffs `PK\x03\x04` on read. | CR-091 |
| Envelope | Format metadata at the root; all entity maps under `"document"`. | CR-092 |
| Round trip | **Byte** round trip: `write(read(bytes)) == bytes`. Constrains key ordering — including inside `unknown` maps — timestamp precision, and integer formatting. | CR-117 |
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
interchangeable with them* — patching an HDBaseT output into a switch does not work and its
100 W PoH can damage the switch. That single check is the highest-value validation in the
product, and it is only expressible because the axes are separate.

So there are four registries, not one:

| Registry | Answers | User-extensible in v1? |
|---|---|---|
| `SignalDomainDef` | What colour, dash, weight and glyph does this class of signal draw in? | No — 8 fixed entries |
| `SignalFamilyDef` | What *is* this signal, what does it require, what may it mate with? | No — catalog-updated (RJ-012) |
| `ConnectorTypeDef` | What plugs into what, and does gender apply? | Aliases only (CR-058) |
| `MediaTypeDef` | What cable is pulled, how long may it be, what jacket? | **Yes** — the CSV import creates them (RJ-009) |

`Port.connector`, `Port.signalFamily` and `Port.carriedProtocols` are three independent fields.
`Link.media` is a fourth. `Service.signalFamily` is what a wire's colour resolves from — never
`Link` (CR-009).

---

### 6.2 The palette, and why it is built this way

#### 6.2.1 Colour encodes domain, not type — and the reasoning

There are ~50 signal families below. **No categorical palette is colour-vision-deficiency-safe
past 8–9 categories** — the Okabe–Ito authors stopped at eight for exactly that reason, having
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

- **Sky Blue `#56B4E9` (L 0.4050) vs Orange `#E69F00` (L 0.4162)** — ΔL 0.0112. Indistinguishable
  in greyscale. These are analog video and analog audio.
- **Vermillion `#D55E00` (0.2215) / Bluish Green `#009E73` (0.2569) / Reddish Purple `#CC79A7`
  (0.2930)** — a crowded 0.0715-wide band. These are digital audio, network and control.

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
- Hop arcs are **suppressed on dashed domains** — control and structure — because dash phase
  diverges across an arc and those are the two domains where hops matter least (AC-016/#17).

#### 6.2.4 The glyph channel

A glyph is drawn at the midpoint of each run and in the legend. It is the fourth channel and the
one that survives a third-generation photocopy.

**Shape encodes domain. Fill encodes tier within the domain** — filled = the domain's native
carrier, hollow = the transported / extended / networked variant. The glyph is deliberately *not*
the per-family discriminator (there is no set of 50 shapes that stays legible at 6 pt); the tag
pill is. The glyph answers "what kind of signal is this" across a room.

All glyphs are drawn from Geometric Shapes, Dingbats, or Miscellaneous Technical, all covered by
`RackBody` (IBM Plex Sans) or the `Noto Sans Symbols 2` fallback (CR-080). **A CI test asserts
that every glyph in the registry resolves in one of those two faces** — a tofu box in an exported
drawing is a defect this test exists to prevent.

#### 6.2.5 `SignalDomainDef` — the eight shipped entries

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
| `pwr` | Power | `#000000` | `#E8E8E8` *(inverted — black is invisible on dark)* | `8,3,1.5,3,1.5,3` | 2.00× | ⬢ / ⬡ / ⏚ | 0.0000 |
| `str` | Structure | `#999999` | `#A8A8A8` | `6,3,3,3` | 0.75× | ★ / ☆ | 0.3185 |
| *(reserved)* | Selection / focus | `#F0E442` | `#F5E76B` | — | — | — | 0.744 |

Dash patterns, weights, glyphs and tags are **identical across themes**. Only hue moves, and the
theme is a UI preference never persisted in the document.

> **The `str` base dash `4,4` is superseded — see §14.3.** It is **`6,3,3,3`**, class `(short,short)`, period 15 pt, and the row above is corrected in place. The §6.4 rows for `audio.spdif_optical`, `structure.pathway`, `structure.undetermined`, `video.hdmi.1_4`, `video.composite`, `audio.line_bal`, `audio.spdif_coax` and `audio.aes3` are likewise superseded by §14.3. Every effective value in this section is checked by `tools/pal1_check.py`.

`str`'s base dash was authored `4,4` rather than `design-ux-schematic.md`'s `6,3`, on the reasoning
that an even dash is unambiguous against a 2:1 dash. **That reasoning is retracted.** It predates
the mechanical dash-class definition of §14.2, under which `4,4` and `6,3` are both `(short)`, and
`4,4` @ 0.75× against analog audio's `6,3` @ 1.00× is a weight ratio of 1.33 — the identical
failure the paragraph was written to avoid. The `str` base dash is **`6,3,3,3`**, class
`(short,short)`, period 15 pt; the table row above now carries that corrected value. See **§14.3**.

---

### 6.3 `ConnectorTypeDef` — the connectors referenced below

Abbreviated to `id · display · genderApplies · contacts`. `genderApplies` decides whether
`CON-002` (both ends the same gender) evaluates and whether the symbol glyph's fill encodes
gender — which is what `design-ux-schematic.md` actually wanted when it limited gender encoding
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
entry** in the connector footprint table — the "zero-authoring correct rear panel" claim is false
without it (AC-050/A2.2).

---

### 6.4 `SignalFamilyDef` — the shipped signal families

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

#### Digital video — `#0072B2`, glyph ▲ native / △ transported

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

Key data: HDMI 2.1 passive collapses to **3–4.5 m** where 2.0 reaches ~7.5 m — a 25 ft run that
worked at 4K60 fails at 4K120, and `LEN-001` exists for exactly this. DisplayPort DP80 passive is
**1.2 m**. 12G-SDI is **~45–50 m**. HDBaseT reaches **100 m on Cat6a** at 4K and carries up to
100 W PoH; `topologyFree = false`, `acceptedFamilies` deliberately **excludes** `net.ethernet`,
and this is what makes `SIG-001` fire.

#### Analog video & RF — `#56B4E9`, glyph ▼ baseband / ▽ broadband

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

`video.component` declares a `PortSetDef` of kind `componentVideo` with `atomicConnect: true` —
three ports, one gesture, one Link with three conductors (AC-053). `rf.satellite` carries
`requiresPowerPassingPort: true`: exactly one splitter port passes DC back to the LNB, and wiring
a normal splitter means the dish never powers. `rf.catv` carries per-device insertion loss so a
cascade budget is computable (a 2-way splitter is ≈ 3.5 dB); the cascade rule itself is v1.2.

#### Analog audio — `#E69F00`, glyph ● line / ◐ speaker low-Z / ○ constant-voltage

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
evaluate — the field-device templates of AC-031 exist so these rules have objects to operate on.
`audio.speaker_cv` carries `Port.tapWatts` **per installation, not per device** (2.5 / 5 / 10 /
15 / 20 W), because the tap is a setting on the transformer, not a property of the speaker model.

#### Digital audio — `#D55E00`, glyph ◆ electrical / ◇ optical or networked

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
also the pair where the distinction carries real consequence — TOSLINK cannot carry lossless
multichannel (no DTS-HD MA, no TrueHD), which is a design constraint, not trivia.

`audio.spdif_coax` sets `nominalImpedanceOhms: 75` and is physically indistinguishable from
`audio.line_unbal` at the connector: wiring a plain analog interconnect causes intermittent
dropouts, which is why the impedance warning exists. `audio.aes3` sets `110` — 110 Ω STP, *not*
mic cable, despite the identical XLR. Dante uses **PTPv1**, AES67 **PTPv2 (IEEE 1588-2008)**;
both need QoS/DSCP and ideally a dedicated VLAN. `audio.avb` sets `requiresTsnPath: true`, and
per CR-017 the "AVB traverses a non-TSN switch" check is a **post-hoc finding**, not a drag-time
refusal, because the link being drawn may be the one that completes the path.

#### Network — `#009E73`, glyph ■ copper / □ fibre or non-Ethernet

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `net.ethernet` | **Ethernet (copper)** | `conn.rj45` | ↔ | STAR | solid | 1.50× | `NET` | ■ |
| `net.poe` | PoE / PoE+ / PoE++ | `conn.rj45` | → power, ↔ data | STAR | solid | 2.00× | `PoE` | ■ |
| `net.poh` | PoH (HDBaseT power) | `conn.rj45` | → | P2P | `14,4` | 2.00× | `PoH` | □ |
| `net.fiber_mm` | Fibre, multimode (OM3 / OM4) | `conn.lc_duplex` | ↔ | P2P / STAR | `16,4` | 1.50× | `FIB` | □ |
| `net.fiber_sm` | Fibre, singlemode (OS2) | `conn.lc_duplex` | ↔ | P2P / STAR | `16,4,3,4` | 1.50× | `FIBS` | □ |
| `net.dac` | Direct-attach copper (SFP+) | `conn.sfp_cage` | ↔ | P2P | `8,3` | 1.50× | `DAC` | □ |

`maxChannelLength` is **100 m** for copper Ethernet (90 m horizontal + 10 m patch) and it is an
error above it, not a warning — this is one of the few hard numbers in the trade. PoE, as shipped
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
on `net.poe`. `NET-001` checks Σ(PD class draw) ≤ `PowerProfile.poeBudgetWatts` — a switch's
budget is almost always well below ports × max class — and flags a Type-4 PD on a Type-2 PSE.
Fibre carries `fiberMode` and `wavelengthNm`, and **A/B pair polarity** is the fibre analogue of
null-modem: it is `Link.crossover: fiberPolarityAB`.

#### Control — `#CC79A7`, glyph ✚ point-to-point / ✳ multi-drop bus

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
KNX 64 devices per line segment, 1000 m per line. Cresnet has **two independent limits** — data
length (~915 m) *and* 24 V power drop (18 AWG at 20 W ⇒ **333 ft**) — which is why `BUS-005`
emits two findings, not one. Lutron QS is 2000 ft on 12 AWG and topology-free.

`ctl.ir_emitter` and `ctl.ir_receiver` are separate families because the pinout hazard is real
and destructive: Xantech/Niles **receivers** are tip = signal, ring = GND, sleeve = +12 V;
**emitters** are tip = IR in, sleeve = GND. Plugging an emitter into a receiver jack destroys the
emitter and can damage the supply. `PortDef.pinoutVariant` is mandatory on every 3.5 mm IR port
and is a **safety-adjacent field**, so a template with an uncited value does not ship (AC-052).
`ctl.trigger12v` requires a **mono** plug — a stereo plug shorts ring to sleeve — and carries
`maxCurrentMa: 100`, which is what makes fan-out to four amplifier triggers a finding.
`ctl.rs232` is P2P only; straight versus null-modem is determined by the DTE/DCE role of *both*
ends, carried in `SerialSpec.role`, and surfaces as `Link.crossover`.

#### Power — `#000000` (light) / `#E8E8E8` (dark, inverted), glyph ⬢ AC / ⬡ DC / ⏚ bonding

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `power.ac_branch` | **AC branch circuit** | `conn.nema_5_15p` | → | P2P to circuit | `8,3,1.5,3,1.5,3` | 2.00× | `PWR` | ⬢ |
| `power.ac_iec` | IEC device power (C13/C14, C19/C20) | `conn.iec_c14` | → | P2P | `8,3,1.5,3` | 2.00× | `IEC` | ⬢ |
| `power.ac_hardwired` | Hardwired AC | `conn.hardwired` | → | P2P | `12,3,1.5,3` | 2.00× | `HW` | ⬢ |
| `power.dc_low` | Low-voltage DC (12 / 24 V supply) | `conn.barrel_dc` | → | P2P | `6,3,1.5,3` | 1.50× | `DC` | ⬡ |
| `power.bonding` | Bonding / grounding conductor | `conn.ground_lug` | ↔ | STAR to busbar | `4,3` | 1.50× | `GND` | ⏚ |

`power.ac_120` from `design-data-model.md` and `ac-inlet` from the device-builder catalog are both
re-authored to `power.ac_branch` / `power.ac_iec` with `PortPowerSpec.role: inlet | outlet`
(CR-058, CR-060). **Inlet and outlet are not directions** — they are `sink` / `source` on a
`power.*` family plus a role. IEC odd numbers are the female connector on the cord and the next
even number the male inlet on the equipment; C13→C14 is the standard rack pigtail. Circuit
loading is computed in **VA** using `typicalWatts` × a per-category diversity factor (amplifiers
350‰ by default), with nameplate as an advisory second line — a linear-supply amplifier at PF
0.65 under-reports current by 35% under a naive `watts / 120`, which is how a system that
"calculated fine" trips a breaker (AC-020, CR-056).

`power.bonding` exists so a bonding conductor is *drawable* and therefore appears on the drawing;
the full busbar entity and conductor sizing are v1.2 (RJ-010). Links on `power.*` originating at
a PDU outlet auto-classify as `LinkClass.powerCord` and are excluded from the pull sheet by
default, appearing instead as an **outlet map** on the power schedule (AC-026).

#### Structure — `#999999`, glyph ★ home run / ☆ pathway

| id | Display name | Default connector | Dir | Topo | Dash (pt) | Wt | Tag | Glyph |
|---|---|---|---|---|---|---|---|---|
| `structure.undetermined` | Undetermined home run | `conn.unterminated` | passive | P2P | `6,3,3,3` | 0.75× | `STR` | ★ |
| `structure.pathway` | Pathway only (conduit / pull string) | — | passive | — | `1.5,3,1.5,9` | 0.75× | `PATH` | ☆ |

`structure.undetermined` is the interesting case and it is deliberate: a Cat6 home run at
rough-in may end up carrying Ethernet, HDBaseT, or nothing. The family is legal, it schedules, it
prints, it gets a `W` number and both labels, and the DRC validates **retroactively** once a
`Service` assigns a real family. `structure.pathway` pairs with `MediaTypeDef.isPathwayOnly` —
it creates a `Pathway`, never a Link and never a Port, appears on the pull sheet (you still pull
the smurf tube and it still costs money) and never appears in the netlist (CR-109).

---

### 6.5 `MediaTypeDef` — the shipped cable types

`MediaTypeDef{id, displayName, shortTag, conductorCount, pairCount, gaugeAwg, impedanceOhms,
shielded, availableJackets[], maxChannelLength, minBendRadius, outerDiameter, supports[],
isPathwayOnly, aliases[]}`. **User-extensible in v1** — an unmatched media value in a Structure
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
| `media.hdmi_active` | HDMI, active copper | `HDMIA` | 19 bonded | — | — | yes | ~7.6 m | `video.hdmi.*` — **direction-locked** |
| `media.hdmi_aoc` | HDMI, active optical (AOC) | `AOC` | hybrid | — | — | — | 15–90 m+ | `video.hdmi.*` — **direction-locked, source/display ends marked** |
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
voltage (NEC 725.136). Both are acknowledgeable like every other rule (CR-019) — an inspector's
judgement outranks ours — but **the finding must exist**, because these are two of the very few
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
  and ◆ vs ◇ — separated on three channels, not two. S/PDIF's earlier `6,3,1,3` is retracted: at
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
   An entry whose safety-adjacent fields — `pinoutVariant`, `impedanceOhms`, `poeBudgetWatts`,
   `maxRunLengthPassive`, PoE class watts — are uncited **does not ship** (AC-052).
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
its binding v1 cut list — none of which may contradict Parts 1 or 2.




**Status:** NORMATIVE, continuing Part 1 (rulings `CR-nnn` / `AC-nnn` / `RJ-nnn`) and Part 2.
**Scope of Part 3:** the scope ruling, the core loop, the milestone plan, and the open questions
that are deliberately *not* ruled on.

Every ruling in this Part cites the Part 1 IDs it derives from. Where this Part and Part 1
appear to disagree, Part 1's ruling on the *mechanism* governs and this Part's ruling on the
*release it lands in* governs — they are different axes and neither overrides the other.

---

## 7. Scope ruling

### 7.0 How the split was made

Four filters, applied in this order. A feature must pass all four to be in v1.

1. **Requirement filter.** Does one of the seven brief requirements fail without it? If yes it is
   in v1 regardless of cost. This is why the schematic canvas survives (RJ-001, RJ-002), why the
   device builder survives, why the Structure device survives, and why the PDF must contain both
   the diagram and the schedule.
2. **G5 filter — cheap now, ruinous later.** Does omitting it cost a file-format migration, a
   command-stack rewrite, or a reconstruct-and-confirm pass over existing user data? If yes, the
   *model* ships in v1 even when the *UI* does not. This is the single most-used rule below and
   it produces the "model ships, gesture defers" pattern that appears eleven times.
3. **G1 filter — does it serve the schedule?** Does it make the schedule more correct, or get the
   user to the schedule faster? `critique-ux-simplicity.md` is right that the corpus states this
   thesis and then spends ~70% of its design effort contradicting it. Features that fail this and
   pass nothing else are cut.
4. **Honesty filter — G4.** Does it fabricate a number, or present a heuristic with authority it
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

### 7.2 v1 — in scope

Grouped by subsystem. The **Why** column names the filter or the ruling that puts it here.

#### 7.2.1 Core, format, and infrastructure — all of it, no exceptions

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
| Sealed `Placement` union — rail, shelf, zero-U, off-rack, staged — with `chassisRotation`, `locked`, and lateral twelfths in the format | CR-031, CR-030, AC-023 |
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
| Three length fields — `routedLength`, `cutLength`, `terminatedLength`; `Location.estimatedRunLengthFromRack`; estimates rendered distinctly everywhere | AC-024 |
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
| Dual labels — `fieldLabel` required and `rackLabel` optional, both generated, both editable, **both always print, on every cable** | CR-044, AC-025, AC-047 |
| Structure editor opens in **table mode** with `+ Add drop`; the room × media matrix is a tab | AC-048 (cliff #4), RJ-004 |
| Outlet templates first-class; TIA-570-D grades as presets and a standards tag | AC-034 (m23), CR-108 |
| Location tree owned by a **project-level** panel, not by the Structure editor | CR-047, CR-112 |
| Multiple Structure instances | CR-113 |
| CSV import with synonym mapping | RJ-004 |
| 18 **Field Devices** templates, `mountMethod: notInRack`, authored through a stripped builder form | AC-031 |

#### 7.2.5 Device builder and catalog

| Item | Why |
|---|---|
| **Three required fields — name, RU height, designator prefix — then ports, then done.** Everything else optional with a visible `unknown` state | AC-049, CR-114 |
| The port grid in full: fill-down, TSV paste, multi-row edit, archetype generators, the pattern DSL | AC-049. The grid was never the barrier |
| Banks (presentation) and `PortSetDef` (electrical) as two distinct concepts | CR-055 |
| `PortDef.key` + `renamedFrom` as the migration join | CR-051 |
| Three doors: edit this device only / edit the template / fork to a new template. No fourth | CR-054 |
| Typed `DeviceOverrides` and `PortOverrides`; port overrides live on the port | CR-053, AC-012 |
| Copy-on-place; `templateRef{templateId, version, contentHash}` recorded; a passive "based on an older catalog template" badge | AC-041 |
| `contentHash` kept; hash mismatch is a **warning plus a badge**, never a load failure | AC-042 |
| Single `.rmdev` export/import | AC-042 |
| Full catalog at **full fidelity with cited provenance** — every numeric field sourced in `assets/catalog/sources.md`; a template with uncited safety-adjacent fields does not ship | RJ-007, AC-052 |
| Connector footprint table completed for **every** connector in the shipped catalog, with a CI assertion | AC-050 (A2.2) |
| Media-type editor and connector aliases; `SignalFamilyDef.topologyFree` as data | AC-050 (A2.1), AC-030, RJ-009 |

#### 7.2.6 Validation

| Item | Why |
|---|---|
| Rules are **Dart functions** in a registry; the catalogue metadata is data; the connector × signal-family compatibility matrix stays a lookup table | CR-024, AC-011 |
| **22 rules**, listed once in `docs/rules.md` | AC-040 |
| `error \| warning \| advisory \| off`; per-project `RuleOverride{severity, reason, by, at}` | CR-018, CR-019 |
| One dismissal mechanism, `AckedFinding`, at two scopes; **errors are acknowledgeable** | CR-019, RJ-006 |
| Only `TOP-001..005` and placement coherence are model-illegal; Class A becomes spring-back with a reason chip and `[ Connect anyway ]` | CR-017 |
| Nothing blocks export; `ExportSpec.issuedForConstruction` is the only thing errors gate | CR-022, AC-035 |
| **DRC fixture corpus — no rule ships without a known-bad and a known-good near-miss** | AC-051. This is also the gate that holds the catalogue at 22 |

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
| Print test matrix on real hardware — laser at ANSI B/A3, plotter at ANSI D, and a photocopy | AC-058 (D13). The whole dash-pattern argument is predicated on it |
| Deuteranopia/protanopia simulation and a real greyscale laser print as a named acceptance criterion | AC-054 |

#### 7.2.8 Platform, quality, and release

| Item | Why |
|---|---|
| Mobile/tablet **read-only** on exactly three surfaces: rack elevation, schedule table, exported PDF — and the app says so rather than shipping a squeezed editor | AC-056. Confirmed decision 1, honoured honestly |
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

### 7.3 v1.1 — the fast follow

Everything here is **additive**: no format migration, no command-stack change, no re-derivation of
existing user data. That is the criterion for the v1.1 bucket, not effort.

| Item | Deferred by | What it costs to wait |
|---|---|---|
| 0U gutter **interactions** — 16 px gutters, rotated bars, drag-into-gutter, resize handles, the `G` toggle, channel-overlap warnings | AC-044 | Inspector-only editing of a real occupant; not lossy |
| Free lateral positioning on shelves, `Alt`-drag, the third focus level, per-host overhang warnings | AC-043 | Auto-pack covers the common case |
| Free lateral dragging of half-rack devices | CR-030 | The dropdown covers all three real positions |
| Hand-authoring an arbitrary conductor map | AC-053 | `atomicConnect` covers component video, stereo pairs, and 16/4 — the cases the decision exists for |
| The rear-panel view as a printable sheet | CR-071, feasibility #5 | The termination schedule carries the same information in table form |
| `Trace` through pass-throughs, and the search DSL | AC-040 | Both are navigation, not correctness |
| Manual reroute, stored as `routeConstraintsBySheet` (ordered grid points the router must pass through) — never as a polyline | CR-012 | The router is deterministic; the itch is aesthetic |
| Registry editor beyond media types and connector aliases | AC-050 (A2.1) | The two extensibility paths users actually hit already ship |

### 7.4 v1.2 — the second release

Items here need either a format addition, a fixture corpus, or evidence from real projects. All
are pre-committed in the sense that the model already accommodates them (G5); none is promised on
a date.

| Item | Gate |
|---|---|
| **Multi-sheet**, partitioned **by domain only** — which by construction has zero cross-sheet connections, so off-sheet connectors, zone grids, and cross-reference resolution are never built | CR-073, AC-037. Ships when real projects show which partition users want |
| The remaining ~40 DRC rules — the `BUS-*` family, `ELE-004/005/008`, the length rules, impedance, DMX universes, DALI counts, Cresnet voltage drop, RF cascade, satellite DC-pass, fibre polarity | AC-040, AC-051. **Each ships only with its fixture pair.** This is the whole gate |
| The template **Update Manager** — opt-in migration, safe/additive/breaking grouping, per-cable `[Remap]` / `[Keep as orphan]` | AC-041. `[Del]` never ships (CR-052) |
| Auto-arrange with trade heuristics; fill gaps with blanks/vents, gated on `Rack.formFactor` | AC-045, AC-034 (m20) |
| Buses as graphical grouping with 45° entries | RJ-001 |
| Sub-grid annotation nudging as `int sx, sy` in eighths of a gu, if it is ever needed | CR-004 |
| Bays — `Bay{id, name, order, rackIds}`, a pure addition | CR-033 |
| Full commercial grounding and bonding detail sheet | AC-034 (m21), RJ-010 |

### 7.5 v2 — the next product decision, not the next release

Each of these changes what the product *is*, and each should be decided with evidence from v1
users rather than now.

| Item | Note |
|---|---|
| `SignalRoute` — Dante flows, AVoIP streams, matrix crosspoints, eARC, VLAN/multicast/latency | CR-008, AC-036. Returns **with** a Dante view or not at all. A third entity layer with no editor is dead weight |
| **Layers** — Existing / Phase 1 / Phase 2 / Future / Demo | CR-064, AC-038. Real for commercial retrofit; absent from the residential first job; multiplies every filter and every print flag. `DeviceStatus` covers 80% for one field |
| Cloud sync and multi-user | The model is already cloud-ready (stable UUIDs, `schemaVersion`, no positional identity, tombstones, `sequence`). Nothing more is spent until someone asks |
| Mobile **editing** | v1 is read-only by confirmed decision; the intent layer keeps the door open |
| A read-only **web** viewer | AC-016 (#22). One `kIsWeb` guard already exists; distribution story, not a feature |
| Unit splitting (`MTX1:A/:B/:C`) | CR-070. Only if multi-sheet lands and users demonstrably need it. It is a confusion generator and collapse covers most of the ground |
| A priced BOM with suppliers and purchase orders | AC-055. This is an adjacent product, not a missing feature |
| Real-SKU catalog | See §10.9 — a legal and maintenance question before it is a product one |

### 7.6 Not doing — and these are rulings, not omissions

| Item | Ruling |
|---|---|
| **A rule-authoring UI and the JSON predicate AST** | The claim that users can author rules is **withdrawn from all documents**. ~20 of 70 rules cannot be expressed in a boolean predicate tree, so the AST buys a second rule system, a second debugger, and a second test suite for rules nobody can write without a UI that was never designed. CR-024, AC-011 |
| **A full registry authoring UI** | RJ-012. Media types and connector aliases ship because users hit them; a general registry editor is a database admin tool wearing a product's clothes |
| **Multi-document tabs** | RJ-013. One window, one document, multiple windows if you want two |
| **Tagged / accessible PDF (PDF/UA)** | RJ-015. The accessibility budget buys the outline tree, the keyboard connection path, and the NVDA matrix — all of which help a real user. A tagged schematic helps nobody who could not already read the schedule table |
| **An in-app update mechanism in v1** | RJ-014. Signed installer plus a version-check ping; auto-update is a security surface and a support burden before there are users |
| **Device images** | AC-057. The device-builder document already calls them a scope trap. Cutting them resolves the container question, removes the image-decode import surface, and removes ~1 MB per template |
| **`.rmlib` library packs, signatures, `provenance`/`derivedFrom` chains** | AC-042. `contentHash` survives; the cryptographic apparatus does not |
| **Cable dressing, floor plans, 3D, thermal simulation** | Out of the brief. The brief says the plan ignores cable dressing, and it is right to |
| **`blockExportOnErrors`** | CR-022. Not deferred — deleted. No setting, no equivalent, no exceptions |
| **`Money`, `cost`, `supplier`, `purchaseOrder`** | AC-055 |
| **Silent estimated values** | G4, AC-039. `typicalWatts` never defaults to half of nameplate. Unknown is null, null renders `—`, and every rollup reports its unknown count. Not a scope item — a standing prohibition |

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
`critique-feasibility.md`'s 5–6 months, and this record does not pretend it does — see §9.11.

---

## 8. The core loop

RackMate is a **cable-schedule generator with a rack elevation and a schematic on the front of
it**. The product's reason to exist is the artifact that leaves the office, gets printed, gets
carried into an attic at 7 pm, and tells an installer what to pull, where it goes, what to call
it, and where to land it — without a phone call. Everything upstream of that artifact is data
entry, and the job of the software is to make the data entry fast enough and structured enough
that the artifact is correct by construction rather than by proofreading. The primary journey it
must make excellent is therefore a single unbroken loop: **create a rack, populate it from a
catalog by typing rather than dragging, wire it by clicking a port and then another port, watch
the schedule fill in live beside you, and export a sheet set that is complete and honest on the
first attempt.** Every one of those five steps is currently a place the corpus puts a cliff — an
empty required-looking dropdown on field two of the first dialog, a wiring surface with no
signpost from the rack that needs wiring, a second canvas that looks nothing like the first, a
schedule discovered only at export time, and an export blocked by a heuristic about a system the
user has not finished designing — and the rulings in Part 1 exist to remove all five (CR-105,
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
  M1, and the rules-as-code decision (CR-024) must be settled before the wiring milestone — it
  is, in Part 1, which is why the wiring milestone can start on schedule.
- **Three architecture-doc sequencing rules survive verbatim** (`design-architecture.md §13`):
  the viewport comes first because everything sits on it and it is cheapest to iterate on when
  nothing else exists; the command stack comes before the feature surface grows; and the display-
  list IR comes before the PDF backend, which makes the PDF backend nearly free. Steps 3 and 6 of
  that list are the two "do it now or pay 10× later" items and they are M0 and M1 here.

### 9.1 M0 — Foundations · **S**

Repo scaffolding plus the pure-Dart core. No UI beyond a window that opens.

**Contents.** Monorepo with four packages (CR-083) and the mechanical dependency-rule enforcement
test. `rackmate_core/units/` — `Len`, `Mass`, `Permille`, `Pt`, `Box`, `UnitFormatter`,
`kBtuPerWattHour`. The full entity set from Part 1 as immutable Dart with `@internal` setters
(AC-013). Hand-written JSON codecs both ways, `schemaVersion`, the migration harness, tombstones,
`EntityMeta`, `FracIndex`, `revision`/`sequence`. `Command` / `Transaction` / `UndoStack` /
`DocumentController`. Epoch counters. The `idformat` grammar, registry, and parser (CR-045). CI:
analyze, test, goldens, format, the no-Flutter-import test, the epoch-mask coverage test.

**Exit criterion.** `dart test` is green in `rackmate_core` with: the 1/32-inch clearance test and
the 45U-accumulation test passing exactly (CR-001); a byte round-trip test `write(read(bytes)) ==
bytes` on three fixtures (CR-117, AC-016 #24); the command round-trip property test
(`apply; revert` leaves the JSON byte-identical, including `templates.keys` — AC-015) passing on
1,000 generated command sequences; the epoch-mask coverage test passing for every command type;
and one v0→v1 migration fixture in the golden corpus. `rackmate_core` has zero Flutter imports,
enforced by a test that fails the build.

**Why it is not compressible into M1.** Six decisions — the unit base (CR-001), the wiring entity
model (CR-008), the validation philosophy (CR-017), the template join key (CR-051), the package
layout (CR-083), and the text-metric source of truth (CR-081) — each cost a rewrite of everything
downstream if guessed wrong. They are settled in this record; M0 is where they become code and
tests rather than prose.

### 9.2 M1 — The elevation release · **L**

**This is the smallest genuinely useful release, and it ships to real users.**

**Contents.** `ViewportController` with wheel/trackpad/pan/zoom and the grid painter, built first.
`CanvasIntent` on top of it, with no `PointerDeviceKind` branching anywhere above (AC-016 #23).
The hybrid `RenderRackCanvas`, device widgets, RU snapping, front/rear elevations with per-rack
mirroring. Quick-add by typing with the drop caret. The Staging Bin. Shelves with auto-pack. 0U
occupants from the inspector. Compact Up/Down with preview-then-accept, and the shrink-rack
dialog. Locks. The full seeded catalog including the 18 field devices, with `sources.md`
provenance and the connector-footprint CI assertion. Copy-on-place with `DeviceOverrides`. The
chip strip: RU, weight, VA, outlets — with unknown counts. `DiagramCanvas` + `SceneBuilder` +
both backends + the baseline-y parity test. A minimal PDF exporter: front elevation, rear
elevation, `T6.30` Equipment List and Materials, title block, revision block. Atomic save,
autosave, recovery, recents, close interception. The outline tree. Four starter projects.

**Exit criterion.** A user can open the app, create a 42U rack, populate it with 20 devices in
under four minutes using only the keyboard, and export a three-sheet PDF whose elevations are
dimensionally correct against a physical tape measure at true scale and whose equipment list
matches the rack contents exactly. The baseline-y parity test passes within 0.5% on a
kerning-heavy string. Undo restores every operation in that sequence.

**Why it is useful standalone — the honest argument.** Integrators produce rack elevations today
in Visio, in Excel with merged cells, in D-Tools if they have paid for it, and in PowerPoint if
they have not. An RU-accurate, dimensioned, printable front-and-rear elevation with an equipment
list is a **billable client deliverable in its own right** — it goes into proposals, it goes to
the GC for closet sizing and power requests, it goes to the millworker for the credenza cut-out,
and it is what gets marked up in the field. Roughly half the observed use of a rack tool never
touches wiring at all. M1 therefore is not a demo or a foundation with a UI bolted on: it
satisfies brief requirements 1 and 2 completely, and a user with only M1 has a tool they would
choose over a spreadsheet. It also puts the two most retrofit-expensive subsystems — the command
stack and the display-list IR — into production against real files before a single wire exists,
which is the sequencing `design-architecture.md §13` argues for and the reason M1 is `L` rather
than `M`.

**What M1 deliberately does not have.** No wiring, no schedule, no schematic, no Structure, no
device builder, no DRC. The app says so — an empty Schedule tab that explains it is coming is a
lie; the tab does not exist yet.

### 9.3 M2 — Wiring and the live schedule · **L**

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

### 9.4 M3 — Structure and the field · **M**

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

### 9.5 M4 — The device builder · **M**

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

### 9.6 M5 — Validation · **M**

**Contents.** The rule registry as Dart functions, the catalogue metadata as data, the compat
matrix as a lookup table. All 22 rules. Findings, severities, `AckedFinding` at both scopes,
project-wide mutes with reasons. Spring-back with reason chips and remedy chips, each with
`[ Connect anyway ]`. The `[Why?]` rationale viewer. **The DRC fixture corpus.**

**Exit criterion.** Every one of the 22 rules has a known-bad fixture that produces exactly that
finding and a known-good near-miss that produces none — no rule ships without its pair (AC-051).
A domain-expert review of the 22 rules and of the catalog data is signed off. No rule, at any
severity, prevents a PDF from being written to disk.

### 9.7 M6 — The full sheet set · **M**

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

### 9.8 M7 — Platform and access · **M**

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

### 9.9 M8 — Release engineering · **S**

**Contents.** Signed Windows installer, vendored pdfium, symbol archival, crash reporting
local-first and opt-in remote with the redaction policy reconciled (CR-096), licence model and
EULA, `showLicensePage`, version-check ping. Documented scale limits with the soft warning at 1.5×
and the open-read-only gate at 3×.

**Exit criterion.** A signed installer runs on a clean Windows 11 machine with no SmartScreen
warning, the app cold-starts within budget, a deliberately induced crash produces a local report
containing no project content, and the documented limits behave as documented.

> **The SmartScreen clause is superseded — see §11.6.2.** It splits into a build-side gate (signed, timestamped, valid publisher, **and the signature still validates after the certificate has expired**) and a distribution-side requirement that is documented rather than gated (Local Intranet UNC or Intune/GPO so Mark-of-the-Web is never applied; the ZIP trap stated explicitly). The other three clauses stand as written.

### 9.10 M9 — Beta hardening · **M**

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
not the 5–6 months its cut table promised — because that table cut a requirement (RJ-008). This
record states the real number rather than a comfortable one, because AC-017 is right that a
detailed design with no cost attached reliably stalls at 40%, and a *wrong* cost attached stalls
it at 40% while also destroying trust in the plan.

**Three levers exist if that number is unacceptable**, and they should be pulled explicitly
rather than by drift:

1. **Ship M1 as a public v0.9.** It is a real product (§9.2) and it converts 10–15 weeks of
   invisible work into user evidence that would resolve half of §10.
2. **Move M4 (device builder) after M6.** The catalog plus `DeviceOverrides` covers the common
   case; the builder is a completeness barrier, not an adoption barrier (`critique-ux-simplicity.md`
   is right about this). It defers a requirement, so it needs an explicit decision — see §10.4.
3. **Cut the catalog to 40 archetypes at full fidelity** rather than 80. The provenance gate
   (AC-052), not a target number, sets the count; 40 sourced templates beat 80 guessed ones and
   this record has already ruled that lower *fidelity* is not the lever (RJ-007).

---

## 10. Open questions

**Six of these thirteen are now ANSWERED and binding** — 10.1, 10.2, 10.4, 10.6 and 10.7 by
DR-001…DR-005 in §11, and **10.3 mooted by DR-006** (indexed in §13). **The remaining seven are
still open.** Everything in Parts 1–2 and §§7–9 is binding; the open entries below are deliberately
the opposite — the calls that require a human judgement about what this product is for and who is
going to use it, which no amount of internal consistency can supply. The six settled entries are
retained in full as the record of the argument, each marked where it stands.

> **Six of these thirteen are now ANSWERED — see §13.** 10.1 (DR-001), 10.2 (DR-002), 10.4 (DR-003), 10.6 (DR-005) and 10.7 (DR-004) are settled by the user's decisions in §11 and are **binding**, not open; 10.3 is **moot** under DR-006, which rules that no commercial release is planned. The text below is retained as the record of the argument, per the Part 4 preamble.

Each entry states the options, the honest trade-off, **what evidence would tip it**, and a
**recommendation** — clearly labelled as a recommendation and carrying no normative weight. A
recommendation here can be overruled without an amendment to this record; a ruling in Part 1
cannot.

They are ordered by blast radius. The first one is a fork in what the product fundamentally is
and everything below it is downstream of the answer.

---

### 10.1 ⚠ **Draw every wire, or net labels by default** — the fork

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
| Legibility at 20 connections | Excellent — this is what people picture | Sparse; reads as an unfinished drawing |
| Legibility at 150 connections | Unusable without filtering; the density arithmetic in `critique-ux-simplicity.md` is correct and unarguable | Still readable; the label *is* the information |
| "Looks like a schematic" to a client | Yes, unambiguously | To an electrical engineer yes; to a homeowner it looks like a parts list with brackets |
| Router cost | Full channel routing, track ordering, crossing sweep, hop arcs — the expensive half of M2 | Layering only; routing becomes nearly free |
| Failure mode | Silent — the drawing degrades gradually into spaghetti and the user does not know when it stopped being useful | Loud — the user immediately asks "where are the lines?" and learns the filter |
| Reversibility | Adding label mode later is cheap | Adding full routing later is the expensive part of M2, deferred |

**Why it is genuinely a fork and not a default.** It propagates into: whether M2 is `L` or `M`;
whether multi-sheet is ever needed (under (B) one sheet holds a whole house, and CR-073's
deferral becomes permanent); whether hop arcs, junction staggering, dash-phase divergence
(AC-016 #17) and the Bentley–Ottmann sweep (AC-016 #20) are built at all; whether the crossing
count X matters; and what the PDF diagram sheet *is*. Under (B), roughly 4–6 weeks leave the
critical path and three of the hardest correctness problems in the corpus disappear. Under (A),
the product looks like the thing the brief describes on first sight, which is worth more than an
engineer's instinct usually credits.

**What tips it.** Put both in front of five integrators, as **printed paper**, not on screen —
a 40-connection theatre rack and a 140-connection whole-house system, one sheet each, in both
idioms. Ask one question: *"which of these would you hand to your lead installer, and which
would you hand to the homeowner?"* If the answer differs by audience, that itself is the answer:
ship both as a per-sheet render mode and let the export dialog pick. Second signal: how many of
the five reach for the paper and start tracing a line with a finger. People do that with (A) and
cannot do it with (B), and it tells you what the drawing is actually *for*.

**Recommendation (not a ruling).** Ship **(A) draw every wire as the default, with (B) as an
automatic degradation above a per-sheet threshold** — which is what `design-ux-schematic.md §1.5`
already designed and what AC-040 keeps. Rationale: the requirement says the wiring planner takes
visual inspiration from electronics schematics, first impressions are made at 20 connections not
150, and the degradation rule means the product never faces the density cliff. The cost is that
the router is built in M2 rather than deferred, which is precisely the 4–6 weeks at stake. If the
paper test comes back with (B) preferred by three of five, take (B) and reclaim the weeks — that
result would be strong evidence and this recommendation is not worth defending against it.

---

### 10.2 Residential CI or commercial AV — who is the primary customer

**Options.** (a) Residential custom integration, primary. (b) Commercial / conference-room AV,
primary. (c) Both, explicitly, with a mode switch.

**Trade-off.** The corpus is written for (a) — Structure devices, home runs, rooms, TIA-570-D,
credenza racks — while several of its most expensive features are (b) features: NCS sheet
numbering, layers for phased retrofit, TIA-606 rack labels, plenum and Class 2/3 code rules,
issued-for-construction stamps. (c) sounds free and is not: it doubles the vocabulary the user
must navigate, and `critique-domain-realism.md m23` is right that TIA-570-D grades are a
vocabulary residential integrators do not speak. Every "default off for wall racks" and "simple
sheet numbering" ruling in Part 1 is quietly a bet on (a).

**What tips it.** Where the first ten paying users come from. Also: whether the drawings ever go
to a permit office or a GC — if they do, (b)'s drafting apparatus stops being overhead and starts
being the reason the tool is bought.

**Recommendation (not a ruling).** **(a) residential-primary, commercial-capable** — which is what
Part 1 already implicitly assumes, so this is mostly a request to make it explicit and stop paying
for (b) features by accident. Commercial capability stays present (the code rules, the ISO/NCS
option, the field-device set) but never fronts the UI.

---

### 10.3 Free-form pricing and licensing model

**Options.** (a) One-time perpetual licence per seat. (b) Annual subscription. (c) Free tier with
watermarked PDF, paid to remove the watermark. (d) Free entirely for now, monetise later.

**Trade-off.** Integrators buy tools the way they buy tools — a purchase order, once, and they
resent subscriptions for desktop software that does not sync anything. But (a) makes the v1.1 and
v1.2 work in §7.3–7.4 unfunded, and the catalog needs continuous authoring. (c) is the classic
answer for a document-producing tool and it aligns exactly with G1: the thing people pay for is
the artifact. It also has a specific hazard here — a watermarked pull sheet is worse than useless
in an attic, so the watermark must go on the *client-facing* sheets and not on the field sheets,
which is a product decision disguised as a pricing one.

**What tips it.** Ask five integrators what they pay for D-Tools, Visio, or their CAD seat, and
whether it was a subscription. Also whether they expense software personally or through the
company — the answer changes the acceptable price by an order of magnitude.

**Recommendation (not a ruling).** **(c)**, with the watermark on elevations and diagram sheets
only, never on the pull sheet or termination schedule. It gets the tool into hands, it prices the
deliverable rather than the software, and it does not require any of the licence-enforcement
machinery that (a) and (b) do. This also affects M8's scope, so it wants deciding before M6.

> **Moot — see §13 and §11.6, consequence 12.** DR-006 rules that no commercial release is planned, so there is nothing to price. This section is retained in full as the record of the argument: if DR-006 is ever reversed, §10.3 reopens exactly as written, watermark hazard included.

---

### 10.4 Does the device builder have to be in v1

**Options.** (a) Yes — M4 stays where it is (the current plan). (b) Move it after M6 and ship v1
with the catalog plus `DeviceOverrides` only. (c) Ship a reduced builder — duplicate-and-edit an
existing template, no from-scratch authoring.

**Trade-off.** The brief fixed "device builder PLUS a seeded catalog" as a confirmed product
decision, so (b) and (c) are deviations from the brief and need the user's explicit sign-off —
that is why this is a question and not a ruling. Against that: `critique-ux-simplicity.md`'s
observation is sharp and probably correct — for a 16×16 matrix the right answer is "duplicate
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

**Options.** (a) Imperial default, metric available. (b) Locale-derived default. (c) Ask on first
run.

**Trade-off.** RU is imperial by definition and the North American residential market thinks in
feet, inches and AWG; the rest of the world does not, and half the equipment depth specs are
published in millimetres regardless. (b) is the obvious engineering answer and it is subtly wrong
for this domain: a Canadian integrator's OS locale says metric and their cable footage is in feet.
Note this is display only — CR-001 makes storage exact in either system, and
`design-architecture.md §12.2` correctly makes units a separate axis from locale, so this decision
is cheap to change and cheap to get wrong.

**What tips it.** Where the first users are. If North America, (a) with no further thought.

**Recommendation (not a ruling).** **(a) imperial default, one obvious toggle, and mixed units
permitted per-field on input** (typing `450mm` in a depth field set to inches just works). Because
the cost of being wrong is one settings row, this should not consume any more attention than it
already has.

---

### 10.6 Is the schematic a client deliverable or an internal tool

**Options.** (a) Client deliverable — invest in drafting polish, title blocks, revision clouds,
issued-for-construction stamps. (b) Internal working document — the client gets the elevation and
the equipment list; the schematic is how the integrator thinks and how the installer troubleshoots.

**Trade-off.** This decides how much of the drafting apparatus in `design-pdf-export.md` is worth
its cost, and it interacts with 10.1 — under (b), the net-label idiom is clearly fine because the
audience is technical, and the fork mostly resolves itself. Under (a), the drawing has to survive
being looked at by someone who has never read a schematic, which is a much harder bar and argues
for (A) in 10.1 plus real drafting furniture.

**What tips it.** Ask integrators whether they currently give clients a signal-flow drawing at all.
Many do not — the client gets a proposal, an elevation, and an invoice. If none of the five does,
(b) is the answer and a meaningful amount of M6 gets simpler.

**Recommendation (not a ruling).** **(b) internal-first**, with the title block and revision block
present (they are cheap and they make the document self-describing) but no further investment in
drafting ceremony until a user asks. This record's G1 principle already points here: the schedule
is the deliverable, the drawing is the receipt — and a receipt is for the person who did the work.

---

### 10.7 Multi-sheet timing

**Options.** (a) v1.2 as ruled in §7.4. (b) Pull into v1. (c) Never — one sheet plus domain
filtering, permanently.

**Trade-off.** CR-073 already defers it and AC-037 already keeps the `Sheet` entity so the format
never migrates, so this question is only about timing, not about architecture. The reason it is
still open: if 10.1 resolves to (A) draw-every-wire, a 140-connection whole-house job does not fit
one sheet, and multi-sheet stops being a v1.2 nicety and becomes the thing that makes the diagram
usable at real scale. If it resolves to (B), (c) becomes genuinely plausible forever.

**What tips it.** The same paper test as 10.1, plus the distribution of connection counts in the
first twenty real projects. If the median is under 60, (a) or (c). If the median is over 120, (b).

**Recommendation (not a ruling).** **(a) hold at v1.2**, and re-decide immediately after 10.1
resolves — these two questions should be answered in the same sitting, from the same evidence.

---

### 10.8 How much to invest now in the cloud-ready model

**Options.** (a) Keep exactly what Part 1 rules — stable UUIDs, `schemaVersion`, no positional
identity, tombstones, `sequence` — and spend nothing further. (b) Add the sync cursor plumbing,
per-entity LWW, and a conflict-resolution design now while the model is small. (c) Drop the
cloud-ready constraint and simplify.

**Trade-off.** (c) is not available — it is confirmed decision 3. (a) is what §7 rules. (b) is
tempting for the usual reason (the model will never again be this small) and dangerous for the
usual one: sync semantics designed without a real multi-user use case are almost always wrong, and
wrong sync semantics in a shipped format are worse than no sync semantics. Note that AC-006 already
removed per-port `EntityMeta` on the grounds that the sync design declares device+ports a single
conflict unit — so some conflict-model thinking is already baked in and should be written down
rather than left implicit.

**What tips it.** Whether anyone asks for two people in one project. In this domain that is
usually a designer and a project manager, and the honest answer is often "they take turns".

**Recommendation (not a ruling).** **(a)**, plus one page in `docs/` stating the intended conflict
unit and merge story so that AC-006's assumption is recorded rather than folkloric. Spend nothing
else until a user asks twice.

---

### 10.9 Generic archetypes forever, or a real-SKU catalog eventually

**Options.** (a) Generic archetypes only, permanently. (b) Generic archetypes in v1, a real-SKU
library later. (c) A community-contributed library.

**Trade-off.** Confirmed decision 2 fixes (a) for v1, so this is a v2 question — but it is worth
answering early because it changes what `.rmdev` and the template library are *for*. Real SKUs are
the single most-requested feature in every tool of this kind and also the single largest ongoing
cost: hundreds of manufacturers, constant model churn, and a real legal question about republishing
manufacturer specifications and trademarks. (c) shifts the cost and creates a moderation and data-
quality problem, plus a provenance problem that directly contradicts AC-052's citation gate.

**What tips it.** Whether users start emailing each other `.rmdev` files unprompted. If they do,
(c) is already happening and the only question is whether it is supported or ignored. Also: what
D-Tools' library is actually worth to the people who pay for it.

**Recommendation (not a ruling).** **(b), with (c) as the mechanism** — a curated community library
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

**Options.** (a) M9's stated criterion — three integrators each produce a sheet set they were
willing to send out, without leaving the app. (b) A metric: N projects, N cables, zero P1 bugs for
N weeks. (c) A date.

**Trade-off.** (a) is a judgement and therefore gameable and unschedulable, which is exactly the
objection to it — and it is still the right one, because every metric available at this stage
measures the tool's internal consistency rather than its usefulness. (c) ships something on a day
regardless of whether it works. (b) is the compromise and it tends to measure whichever thing was
easiest to count.

**What tips it.** Whether there is external pressure — an investor, a launch date, a paying
customer waiting. If there is, (b) or (c) is going to happen whether or not it is chosen.

**Recommendation (not a ruling).** **(a), with (b) as a floor** — the judgement gate governs, and
the metric exists only to prevent shipping something that passes the judgement gate for three
friendly users and falls over on the fourth.

---

### 10.12 Small calls that need an owner, not an essay

These do not warrant the full treatment but each needs a human answer before the milestone that
touches it. Recommendations only.

| # | Question | Recommendation | Needed by |
|---|---|---|---|
| a | Undo depth — the cap is 200 with a status-bar signal (AC-058 D5). Is 200 right? | Keep 200; make it a setting; revisit if anyone hits it | M0 |
| b | Autosave interval and whether recovery is silent or prompted | 30 s, prompt on recovery — a silent restore of a file the user thought they abandoned is its own data-loss event | M1 |
| c | Default rack height in the new-rack dialog | 42U; it is the modal answer and wrong-but-adjustable beats blank | M1 |
| d | Whether the four starter projects are residential-only | Three residential, one small commercial — they double as the domain-coverage argument for 10.2 | M1 |
| e | Telemetry at all, and if so opt-in or opt-out | Opt-in, local-first crash reports only (CR-096), no usage telemetry in v1 — and accept that this makes 10.4's miss-rate instrumentation a manual user-interview exercise rather than a dashboard | M8 |
| f | Product name and branding investment | Defer; RJ-017 already rejects branding as a v1 requirement | M8 |
| g | Whether `docs/rules.md` is user-visible documentation or internal | User-visible, in-app, linked from every finding — it is the honesty surface for the 22 rules | M5 |

---

### 10.13 The three that should be answered first

> **Retired — see §13.** All three questions this section prioritises (10.1, 10.2, 10.4) are answered by DR-001, DR-002 and DR-003. Do not sequence work from this section.

If only three of the above get attention before M1 starts:

1. **§10.1 — draw every wire or net labels.** It sizes M2, decides §10.7, and it is the only one
   whose answer changes the product's identity.
2. **§10.2 — residential or commercial primary.** Part 1 already bet on residential in a dozen
   defaults; confirming or reversing that bet now is cheap and reversing it later is not.
3. **§10.4 — is the device builder in v1.** It is worth 4–7 weeks, it deviates from a confirmed
   decision either way, and M1 can be instrumented to answer it for free.

Everything else in §10 can wait until there is evidence, which is the entire point of shipping M1
as a real release rather than as a foundation.

---
---

# RackMate — Canonical Decision Record, Part 4. Amendments

**Status:** NORMATIVE. Amends Parts 1, 2 and 3.
**Authority:** these are the **user's own decisions**, given directly. Five of them (DR-001…DR-005)
are answers to §10; §10 said a recommendation there "can be overruled without an amendment to this
record", and the user overruled two of them, so this Part exists to write the overruling down
rather than to leave the record disagreeing with the product. **The sixth (DR-006) does not answer
a §10 question at all** — it is a user decision about what this product *is* and how it reaches its
users, and it supersedes a Part 2 acceptance criterion directly. Part 4 is therefore the home of
every binding user decision, not only of the §10 answers.

**Precedence, stated once and applying to every document in the repository:**

1. **Part 4 (this Part)** — the user's decisions and everything derived from them.
2. **Parts 1–3** — `CR-nnn` / `AC-nnn` / `RJ-nnn`, canonical naming, the model, the registry,
   the scope ruling, the milestone plan.
3. The authored planning documents in `docs/` — fourteen at the time this Part was written,
   fifteen since `docs/12-milestone-board.md` was added. The board is a **status** document, not a
   scope document: it records what has been demonstrated and what has not, and it changes nothing.
4. `docs/research/` — non-normative rationale.

Where Part 4 and Parts 1–3 disagree, **Part 4 wins and Parts 1–3 are historical**. Parts 1–3
are deliberately **not rewritten**: a superseded ruling with its supersession recorded is more
useful than a silently edited one, because the argument that produced it is still the argument
you need if the decision is ever revisited. §12 is the index of every such supersession. If a
ruling is not listed in §12, it stands exactly as written.

The seven decisions are numbered `DR-001` … `DR-007` (**D**ecided by the user, **R**uling). They
are cited by that ID everywhere, in the same way `CR-nnn` is.

---

## 11. User decisions (binding)

### 11.0 How to read these

Each entry states **what it settles**, **what it supersedes**, and its **derived consequences**,
enumerated concretely enough that an implementer never has to infer one. Where a consequence
removes work, the removal is named as a specific subsystem and given a home (`v1.2`, `v2`, or
`never`) so it cannot drift back across the line under R3 (scope drift). Where a consequence adds
work, it is costed.

Two of these six **reverse the record's own recommendation**. That is not a defect in the record
— §10 exists precisely so that the calls requiring a human judgement about the market are made by
the human and not by internal consistency. The reversals are DR-001 and DR-005. Neither is to be
re-argued in any document; both are to be applied.

**DR-006 is a third shape and is flagged here so it is not mis-filed.** It answers no §10 question;
it supersedes a Part 2 acceptance criterion (AC-058/D10) outright, and it moots §10.3 as a side
effect. Its consequences are enumerated under the same rule as the other five — concretely enough
that an implementer never has to infer one — and its removals are given a named home in exactly the
same way.

---

### 11.1 DR-001 · Net labels by default — the fork, answered

> **RULING — (B) NET LABELS BY DEFAULT.** Every `Link` renders, by default, as a pair of net
> labels: a short stub off each of its two pins carrying the generated net name. Drawn wires are
> available **on demand** — filter to a signal domain, `Alt`-hover, or focus/isolate a selection
> — but a drawn orthogonal polyline is **not** the default rendering of a Link on an unfiltered
> sheet.

**What it settles.** §10.1, the single most consequential open question in the project. It
decides what RackMate's schematic *is*.

**What it supersedes.** §10.1's **recommendation**, which was the opposite — "(A) draw every wire
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
state. It is never persisted, never a `ProjectSettings` field, and never a `Sheet` field — for
exactly CR-115's reason.

**11.1.2 What this does to the exported interconnect sheets.**

The exporter partitions by domain (CR-073), so **every exported interconnect sheet `T6.01…` is a
domain filter by construction and therefore renders `drawn`**. This is not an exception to
DR-001; it is DR-001's own trigger applied at export. The unfiltered all-domains schematic sheet
is not an exported artifact and never was (CR-074 deleted the all-devices overview sheet).

`ExportSpec.wireRender: auto | netLabels | drawn`, **default `auto`** = the table in §11.1.1.
`netLabels` forces label mode on every sheet, which is the right answer for a large commercial
job. `drawn` is honoured up to a per-sheet Link count above which it would be illegible, at which
point the sheet degrades to `netLabels` **and prints a note saying so** — a silent degradation is
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
| 6 | **Dash-phase divergence handling on arcs** (AC-016 #17) | moot in v1 | There are no arcs. The straight-segment `dashPath` profiling item **survives** — dashes still exist. |
| 7 | **The crossing count `X`** as a budgeted quantity | moot in v1 | Nothing consumes it. |
| 8 | **Auto net-label degradation** and its per-sheet threshold | **deleted, not deferred** | There is nothing to degrade *to*. Labels are the base state. |
| 9 | **Multi-sheet splitting** | never — see DR-004 | §10.1 predicted this: "under (B) one sheet holds a whole house, and CR-073's deferral becomes permanent". It did. |

**What explicitly does NOT leave v1 scope**, because it will otherwise be cut by association:

- Sugiyama **phases 0–3** — cycle-break, layering, barycentre crossing-reduction, coordinate
  assignment. These place the **symbols**, and symbol placement is required in both idioms.
  "Layering/ordering only" means these four phases and nothing after them.
- The **deterministic per-link orthogonal trace** used in `drawn` mode: a layer-ordered staircase
  with a fixed bend budget, no channel allocation. Deterministic, same input ⇒ byte-identical
  display list. This is the whole v1 router.
- **Every gesture**: drag-to-connect, click-click sticky, magnetic type-weighted snap, chain-draw,
  multi-draw, `atomicConnect`, re-terminating by dragging an endpoint handle, `Tidy sheet`.
  DR-001 changes how a Link is *rendered*, not how it is *made*.
- **The whole palette** — hue by domain, dash + weight + glyph + tag by family. It applies to
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

M2 was `L` (8–12 weeks) and carried the expensive half of the router. §10.1's own estimate —
"roughly 4–6 weeks leave the critical path and three of the hardest correctness problems in the
corpus disappear" — is adopted.

**M2 becomes `M` (4–7 weeks).** The consequences for the plan:

- **M1 is now the only `L` milestone**, and the critical path's centre of gravity moves from M2
  (wiring) to M1 (elevation, catalog, the drawing IR and the parity test). The walking skeleton
  and the M0→M1 sequencing constraints are unchanged.
- The three hardest correctness problems in the corpus — channel-colouring stability, crossing
  sweep determinism, and dash phase across arcs — are no longer on the critical path.
- **Risk R2 does not disappear; it changes shape.** It was "the wire-layer rebuild is 10–25 ms,
  not 4". It becomes **text-bound**: two net labels per Link is ~300 additional text runs on a
  150-run project, on top of the ~10,000 the label cache was already sized for (AC-009). The
  mitigation is the same cache, the same `(text, styleId, quantisedScale)` key and the same LOD
  gate — but it is now the *primary* commit-budget term rather than a secondary one, and the perf
  harness must measure the **label layer**, not the wire layer.
- Net labels make the **generated net name** load-bearing on screen, which raises the stakes on
  CR-049 (names are generated, editable, and never carry membership — membership is
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
   AV designer, is "supported, never fronted" — and that phrase is now normative, not descriptive.
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

**What it supersedes.** Nothing in Parts 1–3 — this confirms confirmed product decision 2 and
§10.4's own recommendation. One item in a *derived* document is withdrawn:

- **09-roadmap §6 lever 2 — "Move M4 after M6" — is WITHDRAWN.** Its own text said it "defers a
  brief requirement, so it needs an explicit decision, not a slip". DR-003 is that explicit
  decision, made in the negative. The lever list drops from three to two. Levers 1 (ship M1 as a
  public v0.9) and 3 (cut the catalog to 40 archetypes at full fidelity) are unaffected.

**Derived consequences.**

1. **M4 keeps its position and its size** (`M`), between M3 and M5, independent of M2 and M3.
2. **Requirement 2 is met at M4, not at M1.** The catalog half of R2 lands at M1; the builder
   half — which is what requirement 2 actually asks for — lands at M4. See §12.6 and the
   requirement-to-milestone traceability the roadmap now carries.
3. **Measure 7 (catalog miss rate) survives but changes purpose.** It was instrumented to resolve
   §10.4 for free. §10.4 is now answered, so the miss rate is no longer a v1-scope trigger. It is
   retained as **catalog-coverage evidence** feeding §10.9 (real-SKU catalog) and as the input to
   lever 3's sizing. It must not be described as resolving an open question.
4. **AC-049's reduction stands and is the reason this is affordable**: three required fields —
   name, RU height, designator prefix — then ports, then done. Everything else optional with a
   visible `unknown` state. The port grid was never the barrier and ships in full.
5. **Option (c) — the reduced duplicate-and-edit builder — is not a fallback.** If M4 is ever at
   risk, the lever is lever 1 or lever 3, not a partial builder.

---

### 11.4 DR-004 · Multi-sheet splitting is never built

> **RULING — (c) ONE SCHEMATIC `Sheet`, PLUS DOMAIN FILTERING, PERMANENTLY.** Multi-sheet
> authoring is not v1, not v1.1, not v1.2, not v2. It is **never**.

**What it settles.** §10.7. §10.1 said this question would resolve itself once the fork was
answered, and it did: under net labels, one sheet holds a whole house.

**What it supersedes.** §10.7's recommendation ("hold at v1.2") and, more consequentially, the
**v1.2 row in §7.4**. See §12.4.

**11.4.1 Deleted from the plan. Not deferred — deleted.**

| Deleted | Was |
|---|---|
| **Match lines** | v1.2 with multi-sheet |
| **Off-sheet connectors** (paired pentagon flags, the second placement pass, cross-reference resolution) | already not-v1 under CR-073; now never |
| **Sheet-boundary link handling** — any logic that asks which sheet an endpoint is on | v1.2 |
| **PDF tiling logic for the schematic** — `TilingStrategy` as applied to diagram sheets, key plans, min-cut and by-rack partitioning | v1.2 |
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

- **Multi-sheet authoring** — the user creates, names and populates more than one schematic
  `Sheet` in the document, and a Link can therefore have its two ends on different sheets.
  **Never built.**
- **Exporter domain partition** — one schematic `Sheet` in the document; the **exporter** emits N
  sheets `T6.01…` by filtering that one sheet's contents by `SignalDomainId`. Devices repeat
  across sheets, identified by `designator`. Zero cross-sheet connections by construction, because
  a cable belongs to exactly one domain. **Ships in v1, unchanged.**

**CR-073's exporter-partition behaviour is UNAFFECTED by DR-004 and remains correct.** Partition
at export is not multi-sheet authoring. Any sentence that treats "N sheets come out of the PDF"
as evidence that multi-sheet exists is wrong and must be reworded.

**11.4.4 What this does not remove.** The **zone grid** stays (CR-073 already kept it; DR-005
reinforces it). The schedule's `REF` column stays. `Sheet.domainFilter` and
`Sheet.lifecycleFilter` stay — they are the filter state DR-001 makes load-bearing.

---

### 11.5 DR-005 · The schematic is a client deliverable — invest in drafting polish

> **RULING — (a) CLIENT DELIVERABLE.** The sheet set is a billable artifact handed to a client, a
> GC and a job site. Full sheet furniture ships: title block, revision block, **revision clouds**,
> issued-for-construction stamps, drawing borders, zone references, and sheet numbering.

**What it settles.** §10.6.

**What it supersedes.** §10.6's **recommendation**, which was (b) internal-first with "no further
investment in drafting ceremony until a user asks". The user asked. See §12.5.

**11.5.1 THE CRITICAL NUANCE — drafting polish is orthogonal to wire idiom.**

**This decision does not reopen DR-001 and must never be read as doing so.**

§10.6's trade-off text argued that (a) "argues for (A) in 10.1". That inference is **explicitly
rejected by the user and by this amendment.** The reasoning it rested on — that a client
deliverable "has to survive being looked at by someone who has never read a schematic" — does not
hold here, because **the schematic's reader is technical**: the general contractor, the
electrician, the low-voltage sub, and a technically-literate homeowner. Those readers read net
labels. Net labels are how large electrical schematics have been drafted for forty years, and the
audience that receives this document is the audience that reads them.

The two axes:

| Axis | Decided by | Value |
|---|---|---|
| **Sheet furniture** — borders, title block, revision block, clouds, stamps, zones, numbering, index | **DR-005** | Full. Invest. |
| **Wire idiom** — how a `Link` renders inside the drawing frame | **DR-001** | Net labels by default; drawn on filter/hover/focus. |

Polish the sheet fully. Keep net labels. A beautifully drafted sheet whose connections are net
labels is a normal, professional, forty-year-old idiom — not a compromise.

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
  professional — not that the drawing outranks the schedule.
- It **sharpens** the hazard in §10.3(c): if a watermarked free tier ever ships, the watermark
  goes on client-facing sheets only and never on the Pull Sheet or Termination Schedule. A
  watermarked pull sheet is worse than useless in an attic, and DR-005 makes the client-facing set
  larger and more valuable, which makes getting that split right more important, not less.

---

### 11.6 DR-006 · RackMate is an internal tool — self-signed distribution

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
supersedes a Part 2 acceptance criterion directly. It does moot §10.3 as a side effect — consequence
12 below.

**What it supersedes.** **AC-058 (D10)**, in the half that schedules procurement:

> Windows OV/EV certificate procurement **starts two milestones before release** because
> reputation-building takes weeks

**That lead time is real and it is specific to OV/EV.** It does not attach to either path DR-006
names, so the schedule constraint it produced — and every downstream restatement of it, listed in
§12.9 — goes with it. **The other half of D10 survives untouched**: macOS notarisation and stapling
(if §10.10 ever resolves for macOS), vendored pdfium (CR-100), and a release pipeline with symbol
archival are all still M8 deliverables. DR-006 removes a *purchasing lead time*, not the *release
engineering*.

**11.6.1 Why the two-milestone lead time does not survive the ruling.**

Three distinct mechanisms were folded into "two milestones early". DR-006 removes all three:

| Mechanism | Under OV/EV | Under DR-006 |
|---|---|---|
| **Identity verification** — weeks of external, out-of-team correspondence | The reason the lead time exists | Self-signed: none. Trusted Signing: an identity check exists, but it is a one-time onboarding and it does not gate any milestone before M8 |
| **SmartScreen reputation ramp** — accrues over real download volume | The reason EV was preferred over OV (`RISK-07`'s mitigation column) | Self-signed never accrues reputation and is not distributed over the internet, so it never faces the ramp. Trusted Signing chains to Microsoft-operated roots and does not need one |
| **Hardware token shipping** | Since the CA/Browser Forum's code-signing Baseline Requirements took effect on **1 June 2023**, **OV** private keys must live on a FIPS 140-2 Level 2 / CC EAL4+ hardware module — exactly as **EV** always did. A physical token is couriered, or a cloud HSM is provisioned | Neither path involves a shipped token |

**11.6.2 M8's exit criterion, split.**

M8's criterion currently reads *"A signed installer runs on a clean Windows 11 machine **with no
SmartScreen warning**…"*. Self-signing cannot deliver that clause — **and neither can any
build-side property whatsoever**. SmartScreen Application Reputation is evaluated on files carrying
**Mark-of-the-Web**, the `Zone.Identifier` alternate data stream that a browser or other
zone-aware downloader attaches. MOTW is a function of **how a file arrived on the machine**, not of
what is inside it. A clause that mixes a build property and a delivery property cannot be a gate,
because passing it depends on something the build does not do. So it splits.

**BUILD-SIDE — a real gate, demonstrable in CI.** The installer and every binary it carries:

1. are **signed**, `Get-AuthenticodeSignature` returning `Valid`;
2. are **timestamped** against an RFC 3161 timestamp authority;
3. show a **valid publisher** in the file's Properties ▸ Digital Signatures tab, matching the
   declared subject;
4. **and the signature still validates after the signing certificate has expired.**

Clause 4 is the point of the whole gate. It is what proves the timestamp counter-signature is real
rather than a flag somebody passed and nobody checked, and it is the part people discover too
late — the day the certificate lapses, every previously shipped binary starts reporting
`NotTimeValid` and there is no way to fix already-deployed files. **It is testable today without
waiting a year**: mint a deliberately short-lived certificate (`New-SelfSignedCertificate
-NotAfter (Get-Date).AddMinutes(5)`), sign two copies of the same binary — one with
`-TimestampServer`, one without — wait out the window, and assert `Get-AuthenticodeSignature`
reports `Valid` for the timestamped copy and a time-validity failure for the other. That is a test,
not a hope.

**DISTRIBUTION-SIDE — documented, not a build gate.** Deploy over a **Local Intranet UNC share** or
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
2. **No hardware token.** See §11.6.1 — under the 2023 rules both OV and EV require keys on
   hardware, and DR-006 avoids both.
3. **The signing script is parameterised over certificate source and never hardcodes self-signed.**
   One entry point taking the source as a parameter — self-signed from a named store thumbprint, a
   `.pfx`, or Trusted Signing — with everything downstream (timestamping, hashing, the verification
   step, the artifact list) identical across sources. **This is the only consequence that costs
   anything now, and it is the one that must not be skipped**: it is the difference between the
   named fallback being a config change and being a rewrite.
4. **Every artifact a release produces signs with the same certificate and the same script** —
   installer and unpacked/portable directory alike. One certificate, one script, N outputs; portable
   and installed are the same signing problem, and consequence 3's parameterisation is what makes
   that cheap. **This schedules no build into any milestone that does not already have one.** A
   "portable build" occurs in exactly one place in the corpus — `docs/03-architecture.md:847`, which
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
   early warning is a clean test machine showing "Unknown publisher" — and whose mitigation is a GPO
   and a five-minute check, not a purchase order.
8. **`RISK-08` (beta integrators) changes population, not shape.** Three integrators become three
   internal users running three real jobs. **M9's exit criterion is unchanged** and is still
   deliberately a judgement, not a metric.
9. **AC-058/D7's licence deliverable shrinks but does not vanish.** SIL OFL 1.1 for the bundled font
   and every other bundled licence must still be registered via `LicenseRegistry` and reachable from
   `showLicensePage` — that obligation follows from **redistributing** the fonts, not from selling
   the software. What goes is the commercial EULA and any licence-enforcement machinery. (Note in
   passing that the shipped font is now Jost, not CR-080's IBM Plex, and that CR-080 carries no
   amendment; that drift is recorded in `docs/12-milestone-board.md` §4.6 and is **not** ruled here.)
10. **RJ-014 is reaffirmed and made cheaper.** No in-app auto-update in v1; a "Check for updates"
    item and a version string. Internally that item can point at the same share the installer came
    from, which is a link, not infrastructure.
11. **macOS notarisation is unaffected.** §10.10 is still open, and if it ever resolves for macOS,
    notarisation and stapling are a separate apparatus that DR-006 says nothing about — Apple's
    Gatekeeper has no self-signed path.
12. **§10.3 (pricing and licensing) is moot while DR-006 stands.** There is nothing to price. §13's
    row and §13.1's row are updated accordingly. **If DR-006 is ever reversed, §10.3 reopens exactly
    as written**, including its specific hazard — a watermark belongs on client-facing sheets only
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
binary: **the shell writes values under ComDlg32 that RackMate does not control** — at minimum
`LastVisitedPidlMRU` (this executable plus the last folder browsed) and `CIDSizeMRU` (this
executable, written even when the user cancels the dialog), **measured examples and not an
inventory** — and no supported option prevents them while the shell common dialog is the dialog.
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
  `.cer`. On such a machine the signature is present, the publisher is unknown, and — if the file
  carries MOTW — SmartScreen behaves exactly as it would for an unsigned file.
- It does **not** cut M7, M9, or any brief requirement. Nothing here touches confirmed product
  decision 4.
- It does **not** settle MSIX versus a plain signed installer. **VERIFY:** the `.rackmate`
  file-association path differs between the two and drives the choice (docs/11 §11 already carries
  this).
- **VERIFY:** Microsoft Trusted Signing eligibility before relying on the fallback being available
  on demand — it requires a verified identity, and organisation accounts have carried a minimum
  legal-existence requirement. The fallback is named so that adopting it is a config change; it is
  not asserted to be instantly available.

### 11.7 DR-007 · Keystone strap geometry ships in M3, not v1.X

> **RULING — THE LOW-VOLTAGE BOX'S INTERNAL GEOMETRY IS v1, BUILT IN M3.** An `Outlet` gains an
> ordered list of **gangs**; each gang holds one **strap**, which is a **2D grid of keystone
> positions**; each cell holds a keystone, a two-cell speaker terminal, or a blank insert. It is
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

**Why M3 and not v1.X — the argument that decided it.** M3 is *Structure and the field*; its exit
criterion is a 60-drop whole-house rough-in producing a Pull Sheet sorted by room and pathway, and
boxes **are** those drops' field ends. Three M3 checklist items already build the surface this
geometry lives in: `Outlet`/`structureOrigin`/`PlaceEndpoint`/`OpenEndpoint` in the UI, the
Structure editor with outlet templates and TIA-570-D presets, and the project-level Locations panel.
Deferring the grid means **building the `Outlet` editor twice** — once without it, once with — and
retrofitting a 2D grid into a shipped editor is worse work and a worse first UI than designing it in.

**The cost, stated rather than hidden.** M3's exit criterion does **not** require strap geometry: a
60-drop rough-in schedules and prints correctly without knowing which cell a keystone occupies. This
ruling therefore **grows a milestone that already gates M4 through M9**. M3 stays `M`, at the upper
end of that band. What is added is a model extension, its codec and migration, the strap editor
inside the Structure editor, and plate rendering — not a new subsystem, because the packing problem
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
be encoded as a **derived constraint** falling out of `W × H`, never as a hardcoded exclusion list —
a list would be a fact about a catalog, and this is a fact about geometry.

**11.7.2 Speaker terminals, and orientation that is not a preference.**

A speaker terminal occupies **two cells** and is orientable, but **orientation is constrained by
strap width**: on a 1-wide strap (1 × 2, 1 × 3) it can only be vertical, there being no horizontal
room; on a 2-wide strap (2 × 2, 2 × 3) either orientation fits. On half the shipped straps the
orientation is therefore **forced, not chosen**. A refused placement must state *why* — "no
horizontal room on a 1-wide strap" — under the standing rule that a refused action always reports
and never silently does nothing.

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

Consequent on **CR-121**. `Link.jacketColorId` — what the run *is* — drives the keystone;
`Link.jacketColorPulledId` — what was actually pulled — does not. A run mis-pulled in the wrong
colour still gets the keystone its service calls for, because the keystone is fitted weeks later out
of the same box as every other drop of that service, and is routinely correct while the cable is not.
`ResolvedJacketColor.keystoneColorId` already returns `conventionId` and mentions the override
nowhere; that syntactic independence is the design and is mutation-tested.

**11.7.6 A correction, recorded because it shaped an earlier plan.**

An earlier note in this project's task record claimed "a keystone strap is structurally a tiny rack"
and that the rack occupancy machinery — `findLowestFreeRu`, `findBlockingOccupant`, `planCompaction`,
the shrink planner — would make this cheap. **That is wrong.** A rack is one-dimensional: an RU index
plus a coarse lateral twelfth. A strap is a genuine 2D grid with orientable occupants, and none of
that code applies. It remains cheap for a different reason — the grid is bounded at six cells, so
exhaustive placement is trivial — and the cost is modelling, not algorithms.

**11.7.7 What does not move.**

The **printing** half stays at **M6**. `T5.01 Plate, Panel & Pinout Details` is already in the v1
sheet set (docs/08 §2.2) as `AUTO`, gated on any non-standard pinout existing. Strap geometry gives
that sheet a real second purpose and a reason to be `ON` far more often, but the sheet itself ships
when the full sheet set does.

**11.7.8 One question left open for the implementer, deliberately.**

`ProjectSettings.outletFieldLabelFormat` is `{ROOM_ABBR}-{SERVICE}-{SEQ}`. With N gangs, whether the
gang appears in a drop's field label — and whether that needs a new `IdFormat` token — is **not**
settled here. The idformat engine has a grammar, a registry and a parser; a token is not to be
invented silently to satisfy this feature.

---

## 12. Superseded rulings

Every ruling in Parts 1–3 that DR-001…DR-007 change or void, plus the small set of internal
contradictions the amendment sweep exposed and which are ruled here so the record does not
contradict itself. **A ruling not listed below stands exactly as written in Parts 1–3.**

Each entry gives the ID, what it said, and what now governs.

### 12.1 Superseded by DR-001 (net labels by default)

| Ruling | What it said | What now governs |
|---|---|---|
| **CR-013** | "Sugiyama layering + interval-graph channel routing, full deterministic recompute", with phase 5 (crossing sweep, hop arcs) moved to paint time. | **Superseded in part.** v1 builds **Sugiyama phases 0–3 only** — cycle-break, layer, barycentre sweep, coordinate assignment — which place symbols. Phase 4 (interval-graph channel routing) moves to **v1.2**, gated on evidence that filtered density warrants it. Phase 5 (crossing sweep + hops) is **not built**. `drawn` mode uses a deterministic layer-ordered orthogonal staircase per Link with no channel allocation. Everything CR-013 *deleted* stays deleted: `ObstacleField`, `RouteCache` and "obstacle-aware" remain banned names — the v1 router is not obstacle-aware either, it is simpler still. The interval-graph insight remains the right answer *if* #4 is ever built; it is not wrong, it is not yet needed. |
| **AC-016 #17** | Dash phase diverges across hop arcs; document it in the visual language; suppress hops on control and structure. | **Moot in v1.** No arcs are drawn, so no arc dash-phase divergence exists and there are no hops to suppress. The finding is retained as a v1.2 note attached to CR-013 phase 4. **The other half survives:** `dashPath` is still on the hot path for straight dashed segments and is still explicitly profiled in the perf harness rather than assumed cheap. |
| **AC-016 #20** | "sub-millisecond at N=300" ignores that crossings are unbounded by N; move the Bentley–Ottmann sweep and hop generation to paint time, viewport-scoped; cap hops to `gap` above a threshold; measure X on a real 300-connection fixture. | **Moot in v1.** No sweep, no hops, no cap, no X. **The 300-connection fixture survives** and changes purpose: it is now the layout-determinism and **label-density** fixture, and the thing measured on it is text-run count and commit time for the label layer, not crossings. |
| **AC-040**, density-table half | Kept `design-ux-schematic.md §1.5`'s automatic degradation to net labels above a per-sheet threshold. | **Inverted.** There is no degradation and no threshold, because labels are the base state. The **rule-catalogue half of AC-040 is untouched** and still governs — see §12.6 for its arithmetic. |
| **§7.2.3**, wiring scope table | "Domain filter bar, **auto net-label degradation**, symbol collapse to vector pins, `Alt`-hover transient focus". | The domain filter bar, symbol collapse and `Alt`-hover **stay and are load-bearing**. "Auto net-label degradation" is replaced by **"net labels as the default render; drawn wires on domain filter, hover or focus (DR-001 §11.1.1)"**. |
| **§7.2.3**, router row | "Schematic canvas: Sugiyama phases 0–4 + interval-graph channel routing, full deterministic recompute; phase 5 (crossing sweep, hops) at paint time, viewport-scoped." | **Superseded.** v1 builds **Sugiyama phases 0–3 only**, placing symbols, plus a deterministic layer-ordered orthogonal staircase per Link with no channel allocation. Phase 4 (interval-graph channel routing) is **v1.2**, gated on evidence. Phase 5 (crossing sweep, hop arcs) is **not built**. Nothing runs at paint time. This row is the same ruling as the CR-013 row above it, restated in the scope table; it was missed in the first pass and is listed here because §12's preamble makes an unlisted row read as still-binding v1 scope — the exact work DR-001 removed. The identical restatement appears at **§5.7 (3886-3889)**, **§9.3 M2 (4878)**, **§2.5 (2666)** and the banned-names table **§4.x (3323)**; all four are superseded by this row and each carries the §12.8 pointer. |
| **§9.3 (M2)** | Sized `L`; contents included phases 0–4, channel routing and phase 5. | **M2 is `M` (4–7 weeks)**, contents per §11.1.3. M1 becomes the only `L`. New cumulative plan in §12.7. |
| **§9.11** "The honest total" | Sized M2 as `L` and totalled "41–69 weeks; 12–18 months", against a table whose own final cumulative row reads 45–69. | **Superseded by §12.7.** M2 is **`M` (4–7 weeks)**; the plan totals **42–65 weeks, 11–17 months**; M1 is the only `L` and the sole long pole. The "41–69" prose figure was additionally an arithmetic error against §9.11's own table (45–69) and should not be quoted even as the historical number. **Lever 2** ("move M4 after M6") is **withdrawn by DR-003**; levers 1 (ship M1 as a public v0.9) and 3 (cut the catalog to 40 archetypes at full fidelity) survive. §9.11's lever 1 also mis-states M1 as "10–15 weeks of invisible work" — 10–15 is M1's *cumulative* position; its *duration* is 8–12 — and claims shipping M1 "would resolve half of §10", which Part 4 has since resolved directly (see §13). |
| **§10.1** recommendation | "(A) draw every wire as the default, with (B) as an automatic degradation." | **Void.** DR-001. Not to be re-argued. |

**Explicitly NOT superseded — listed here because they will otherwise be cut by association:**

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

No ruling in Parts 1–3 is superseded — DR-003 confirms confirmed product decision 2 and §10.4's
recommendation. One derived item is withdrawn:

| Item | Status |
|---|---|
| **09-roadmap §6, lever 2 — "Move M4 after M6"** | **Withdrawn.** No longer an available schedule lever. The lever list is two, not three. |
| **Measure 7 (catalog miss rate)** | **Retained, repurposed.** No longer resolves an open question; it is catalog-coverage evidence feeding §10.9 and lever 3's sizing. |

### 12.4 Superseded by DR-004 (multi-sheet never)

| Ruling | What it said | What now governs |
|---|---|---|
| **§7.4**, v1.2 table, row 1 | "**Multi-sheet**, partitioned by domain only … Ships when real projects show which partition users want." | **Deleted from v1.2.** The row moves to **§7.6 Not doing**, with DR-004 as its ruling. There is no gate and no evidence that reopens it. |
| **§7.7**, cut #1 | "Multi-sheet, off-sheet connectors, zone grids, cross-refs, min-cut, unit splitting — v1.2 / v2 — 4–6 weeks." | The cut is **permanent**, not deferred. Two corrections to the row itself: **"zone grids" was never cut** (CR-073 keeps the zone grid, and DR-005 confirms it as a v1 deliverable), and unit splitting's v2 home becomes **never**. |
| **CR-070** | Unit splitting is v2, "only if multi-sheet lands and users demonstrably need it". | Its condition can never be met. **Unit splitting moves to §7.6 Not doing.** Symbol collapse covers the ground it was for. |
| **AC-010** | Multi-sheet is a v2 stack sitting on the critical path to the first PDF; cut it. | **Reinforced and made permanent.** The finding was right and is now unconditional. |
| **§10.7** recommendation | "(a) hold at v1.2, and re-decide immediately after 10.1 resolves." | **Void.** 10.1 resolved to net labels; the re-decision is DR-004 = (c) never. |

**Explicitly NOT superseded:**

| Ruling | Status under DR-004 |
|---|---|
| **AC-037** | **Unaffected and load-bearing.** The `Sheet` entity ships in the model and the format, holding exactly one schematic sheet. It is not vestigial. If DR-004 is ever reversed, the format does not migrate. |
| **CR-073**, exporter half | **Unaffected and still correct.** The exporter emits N domain sheets `T6.01…` from the one schematic `Sheet`. Partition at export is not multi-sheet authoring — §11.4.3. |
| **CR-075** | **Unaffected.** One field, `SheetKind kind`, 11 values, plus `exceptions`. |
| **CR-066, CR-067** | **Unaffected.** `Sheet.domainFilter` and `Sheet.lifecycleFilter` are the filter state DR-001 makes load-bearing. |

### 12.5 Superseded by DR-005 (client deliverable)

| Ruling | What it said | What now governs |
|---|---|---|
| **§10.6** recommendation | "(b) internal-first, with the title block and revision block present … but **no further investment in drafting ceremony until a user asks**." | **Void.** DR-005 = (a). Full sheet furniture ships in v1: title block, revision block, **revision clouds**, IFC stamp, drawing border, zone references, sheet numbering, `T0.00` cover and drawing index. |
| **Revision clouds = v1.1** (export document, As-built preset) | "Revision **clouds** are v1.1." | **v1.** A cloud primitive on `DiagramCanvas`, driven from `RevisionEntry`, with a revision triangle carrying the revision letter. |
| **§9.7 (M6)** | Sized `M`, mid-band. | Still `M`, at the **top** of its band (+0.5–1 week) for revision clouds. Sheet furniture is not available as a schedule lever. |
| **§10.6**'s inference that (a) "argues for (A) in 10.1" | — | **Explicitly rejected.** §11.5.1. Drafting polish is sheet furniture; wire idiom is DR-001. They are orthogonal axes and this decision does not reopen that one. |

**Explicitly NOT superseded:** **CR-022 / G3** — the IFC stamp is gated on zero open errors and
**never gates bytes**; `blockExportOnErrors` stays deleted. **G1** — the schedule is still the
deliverable and the drawing is still the receipt. **RJ-015** (no PDF/UA) and **RJ-017** (no
branding in v1) stand.

### 12.6 Corrections ruled here so the record is self-consistent

These are not consequences of DR-001…DR-006. They are internal contradictions inside Parts 1–3
that the amendment sweep surfaced, and they are ruled here because leaving them would produce
exactly the contradiction §12 exists to prevent.

| # | Ruling | The contradiction | What now governs |
|---|---|---|---|
| a | **CR-071 vs §7.3 vs §7.7 cut #9** | CR-071 point 2 rules the rear panel **prints in v1** as sheet `T2.02`; §4.3 agrees ("the rear elevation still *prints* in v1"); §7.2.7 lists rear elevation in the v1 export set; but §7.3's v1.1 table says "the rear-panel view **as a printable sheet**" and §7.7 cut #9 repeats it. | **CR-071 governs, unambiguously.** Sheet **`T2.02 Rack Elevation — Rear` prints in v1**, with connector fields and landing cable IDs. What is **v1.1** is the **interactive Rear Panel view** (`Ctrl+3`) — leaders, tag pills, per-connector navigation, egress heat map. §7.3's row and §7.7 cut #9 are corrected to say "the interactive Rear Panel view". The Part 3 preamble's "Part 3 governs the release bucket" rule does not apply here, because Part 3 contradicts *itself* (§7.2.7 vs §7.3) and CR-071 is the only source that is internally consistent. |
| b | **AC-040 / §5.8 / §7.2.6 rule count** | All three state "v1 ships **22** rules". AC-040's own enumeration lists **24** IDs (`TOP-001..005`, `SIG-001`, `SIG-002`, `DIR-001`, `DIR-003`, `CON-001`, `ELE-003`, `ELE-006`, `NET-001`, `PWR-001`, `PWR-003`, `LEN-001`, `RCK-001`, `RCK-002`, `RCK-003`, `RCK-012`, `RCK-013`, `CODE-001`, `CODE-002`, `LNK-020`). CR-017 additionally names three placement-coherence conditions and assigns them no IDs. | **The enumeration governs; the count "22" is an arithmetic error.** `PLC-001`, `PLC-002` and `PLC-003` are **RATIFIED** as distinct tier-1 rules — CR-017 already rules the conditions model-illegal, CR-021 says a rule not in the catalogue does not exist, and an unnumbered blocking rule can carry neither a `Finding.ruleId` nor an AC-051 fixture pair. **The v1 catalogue is 27 rules: 8 tier-1 + 6 tier-2 + 13 tier-3.** Every occurrence of "22 rules" in every document becomes **27**. AC-051's gate is unchanged and now applies to 27 pairs. |
| c | **§6.2.2 PAL-1** | PAL-1 is stated and verified over the **eight domain base values**, while §6.4 assigns per-family `dashOverride` and weight overrides that PAL-1 never re-checks. Two shipped families collide on every non-hue channel: `audio.spdif_optical` (TOSLINK, dash `2,3`, 1.00×, domain L 0.2215) and `ctl.ir_emitter` (IR, dash `1.5,3`, 0.75×, domain L 0.2930) — ΔL 0.0715 inside the 0.10 band, same fine-dot dash class, weight ratio 1.33 below the 1.4 floor. Two of requirement 4's ten named types are indistinguishable in greyscale. A second pair, `structure.pathway` (`2,6`, 0.75×, L 0.3185) vs `ctl.ir_emitter` (ΔL 0.0255), fails identically. Enumerating the 385 in-band family pairs — rather than the eight domain rows — subsequently found **fourteen** collisions in all, six involving brief-named types. | **PAL-1 is restated over rendered family values and made pairwise and disjunctive; eight families are re-spaced.** Full statement, the dash-class definition, and the corrected registry rows are in **§14**. The authority is the executable check **`tools/pal1_check.py`**, and where a document disagrees with it the file wins. |
| d | **§7.7 cut #1** | Lists "zone grids" as cut, while CR-073 explicitly keeps the zone grid and the schedule's `REF` column depends on it. | **The zone grid ships in v1.** DR-005 confirms it. Cut #1's row drops "zone grids". |

### 12.7 The plan, re-costed

DR-001 removes 4–5 weeks from M2; DR-005 adds 0.5–1 week to M6. Nothing else moves.

| Milestone | Size | Weeks | Cumulative |
|---|---|---|---|
| M0 Foundations | `S` | 2–3 | 2–3 |
| M1 Elevation release | **`L`** | 8–12 | 10–15 |
| M2 Wiring and the live schedule | **`M`** *(was `L`)* | 4–7 | 14–22 |
| M3 Structure and the field | `M` | 4–7 | 18–29 |
| M4 Device builder | `M` | 5–7 | 23–36 |
| M5 Validation | `M` | 4–6 | 27–42 |
| M6 Full sheet set | `M` | 5–7 | 32–49 |
| M7 Platform and access | `M` | 4–6 | 36–55 |
| M8 Release engineering | `S` | 2–3 | 38–58 |
| M9 Beta hardening | `M` | 4–7 | 42–65 |

**42–65 weeks of implementation; 11–17 months to a shipped v1** for one experienced engineer.
**M1 is the only `L` milestone and the sole long pole.** Two schedule levers remain (ship M1 as a
public v0.9; cut the catalog to 40 archetypes at full fidelity); lever 2 is withdrawn by DR-003.

### 12.8 Part 1–3 sites carrying a supersession pointer

Parts 1–3 are not rewritten (see the Part 4 preamble). These sites state rulings that §11–§14
supersede, and each carries the pointer below, inserted verbatim at the stated position. The
pointer does not restate the new ruling; it names where the new ruling lives.

| # | Site | Insert at | Pointer text (verbatim) |
|---|---|---|---|
| 1 | §2.5, router restatement | after line 2666 | `> **Superseded — see §12.1 (§7.2.3 router row).** Phases 0–3 only; no channel routing, no phase 5.` |
| 2 | §4.x banned-names table, router column | after the table at 3323 | `> **Superseded in part — see §12.1 (§7.2.3 router row).** The banned names in the left column stand (§12.1, CR-013 row); the replacement named in the right column is now Sugiyama phases 0–3 plus a deterministic orthogonal staircase.` |
| 3 | §5.7, router prose | after line 3889 | `> **Third sentence superseded — see §12.1 (§7.2.3 router row).** The router is Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal staircase; there is no channel routing, no crossing sweep, no hop arcs and no paint-time phase. The first two sentences (CR-012 — route geometry never persisted, symbol placement persisted) are **unaffected and still binding** (§12.1, CR-012 row).` |
| 4 | §6.2.2, PAL-1 statement | after the PAL-1 blockquote | `> **Superseded — see §14.1; ruled at §12.6(c).** The conjunctive domain-level form stated above is not PAL-1. The binding form is **pairwise over rendered family values** and **disjunctive** (dash class differs **or** weight ratio ≥ 1.4). Stated over eight domain rows it is unsatisfiable by the shipped palette, and reading those eight rows instead of the family pairs actually drawn is what allowed collisions to ship undetected three times. The authority is the executable check **`tools/pal1_check.py`** — not this statement, and not the table below.` |
| 5 | §6.2.5, `str` row | after the domain table | ``> **The `str` base dash `4,4` is superseded — see §14.3.** It is **`6,3,3,3`**, class `(short,short)`, period 15 pt, and the row above is corrected in place. The §6.4 rows for `audio.spdif_optical`, `structure.pathway`, `structure.undetermined`, `video.hdmi.1_4`, `video.composite`, `audio.line_bal`, `audio.spdif_coax` and `audio.aes3` are likewise superseded by §14.3. Every effective value in this section is checked by `tools/pal1_check.py`.`` |
| 6 | §6.7, criterion 4 | after line 4464 | `> **Superseded — see §14.1 and §14.5.** PAL-1 is a **pairwise** test over **rendered family values**, not the eight domain colours, and its two limbs are **disjunctive** (dash class differs **or** weight ratio ≥ 1.4), not conjunctive. The conjunctive domain-level form stated here is unsatisfiable by the shipped palette and is what allowed fourteen collisions to ship. The authority is `tools/pal1_check.py`.` |
| 7 | §7.2.3, wiring scope table | after line 4601 | `> **The router row is superseded — see §12.1.** v1 builds Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal staircase. Phase 4 is v1.2; phase 5 is not built. The remaining rows of this table stand, as amended by the §7.2.3 row already listed in §12.1.` |
| 8 | §9.3, M2 contents | after line 4878 | ``> **Superseded — see §12.1 (§7.2.3 router row) and §11.1.3.** M2's router is phases 0–3 plus the orthogonal staircase, and M2 is sized `M` (4–7 weeks) — see §12.7.`` |
| 9 | §9.11, "The honest total" | above the table at 4987 | ``> **Superseded — see §12.7.** M2 is `M` (4–7 weeks); the plan totals **42–65 weeks, 11–17 months**. The "41–69" figure below is additionally an arithmetic error against this section's own table, whose final cumulative row reads 45–69. Lever 2 is withdrawn by DR-003.`` |
| 10 | §10 preamble | after line 5025 | `> **Six of these thirteen are now ANSWERED — see §13.** 10.1 (DR-001), 10.2 (DR-002), 10.4 (DR-003), 10.6 (DR-005) and 10.7 (DR-004) are settled by the user's decisions in §11 and are **binding**, not open; 10.3 is **moot** under DR-006, which rules that no commercial release is planned. The text below is retained as the record of the argument, per the Part 4 preamble.` |
| 11 | §10.13 | after the heading at 5336 | `> **Retired — see §13.** All three questions this section prioritises (10.1, 10.2, 10.4) are answered by DR-001, DR-002 and DR-003. Do not sequence work from this section.` |
| 12 | AC-058, the **D10** row | after the gap table | `> **The D10 row's procurement schedule is superseded — see §12.9 and §11.6.** RackMate is an internal tool; signing is self-signed with a timestamp, Microsoft Trusted Signing is the named fallback at M8, and no OV/EV certificate is procured at any milestone. The rest of D10 — macOS notarisation, vendored pdfium (CR-100), the release pipeline with symbol archival — is **unaffected and still binding**.` |
| 13 | RJ-014, the certificate sentence | after the RJ-014 body | `> **The certificate half is superseded — see §12.9 and §11.6.** There is no OV/EV validation and no reputation build, so nothing here needs scheduling two milestones ahead. RJ-014's actual ruling — no in-app auto-update in v1, a signed installer plus a version-check ping — is **reaffirmed**, and the `.rmdev` migration-chain half (AC-050/A8.2) is untouched.` |
| 14 | §7.2.8, the code-signing row | after the table | `> **The code-signing row is superseded — see §12.9 and §11.6.** Read it as: Windows code signing **self-signed with a timestamp server**, no certificate procured early, Microsoft Trusted Signing as the named fallback at M8. Vendored pdfium and the release pipeline with symbol archival are **unchanged**.` |
| 15 | §9.7, M6 exit criterion | after the exit paragraph | `> **The last sentence is superseded — see §12.9 and §11.6.** "Windows OV/EV certificate procurement starts here" is **deleted**. Every other clause of M6's exit criterion stands exactly as written.` |
| 16 | §9.9, M8 exit criterion | after the exit paragraph | `> **The SmartScreen clause is superseded — see §11.6.2.** It splits into a build-side gate (signed, timestamped, valid publisher, **and the signature still validates after the certificate has expired**) and a distribution-side requirement that is documented rather than gated (Local Intranet UNC or Intune/GPO so Mark-of-the-Web is never applied; the ZIP trap stated explicitly). The other three clauses stand as written.` |
| 17 | §10.3 recommendation | after the recommendation paragraph | `> **Moot — see §13 and §11.6, consequence 12.** DR-006 rules that no commercial release is planned, so there is nothing to price. This section is retained in full as the record of the argument: if DR-006 is ever reversed, §10.3 reopens exactly as written, watermark hazard included.` |

---

### 12.9 Superseded by DR-006 (internal tool, self-signed distribution)

**A numbering note, stated so nobody renumbers.** This subsection is §12.9 and not §12.6, even
though it breaks the DR-order of §12.1…§12.5, because **§12.6(a)–(d) are cited by those exact
sub-letters** across this record and the authored documents (§12.6(b) sets the 27-rule count,
§12.6(c) is PAL-1's ruling, §12.6(d) is the zone grid). Renumbering to keep the DR-order tidy would
silently break every one of those citations, which is a worse outcome than an out-of-order heading.

| Ruling | What it said | What now governs |
|---|---|---|
| **AC-058 (D10)**, procurement half | "Windows OV/EV certificate procurement **starts two milestones before release** because reputation-building takes weeks." | **Superseded in part.** No OV/EV certificate is procured, at M6 or anywhere. Signing is **self-signed** — `New-SelfSignedCertificate`, `Set-AuthenticodeSignature` **with a timestamp server**, public `.cer` to `LocalMachine\Root` and `\TrustedPublisher`, ideally by GPO — with **Microsoft Trusted Signing as the named fallback**, adoptable at M8. The lead time D10 was defending against is specific to OV/EV identity verification, the SmartScreen reputation ramp and hardware-token logistics; §11.6.1 shows none of the three attaches to either path DR-006 names. **The rest of D10 stands**: macOS notarisation and stapling, vendored pdfium (CR-100), release pipeline with symbol archival. |
| **§9.7 (M6)** exit criterion, last sentence | "Windows OV/EV certificate procurement starts here, two milestones before release." | **Deleted.** M6 has no distribution obligation of any kind. Every other clause of M6's exit criterion — the complete sheet set on all four starters, the deuteranopia/protanopia and greyscale verification, the ANSI B / ANSI D / photocopy sign-off (AC-058 D13), requirement 7 — is **unchanged**. |
| **§9.9 (M8)** exit criterion, first clause | "A signed installer runs on a clean Windows 11 machine **with no SmartScreen warning**." | **Split — §11.6.2.** No build-side property can deliver "no SmartScreen warning": SmartScreen evaluates **Mark-of-the-Web**, which is a property of how a file arrived, not of the binary. The **build-side gate** is: signed, timestamped, valid publisher in file properties, **and the signature still validates after the signing certificate has expired**. The **distribution-side requirement** is documented and not gated: Local Intranet UNC or Intune/GPO, and the ZIP trap stated explicitly. M8's other three clauses — cold start within budget, an induced crash producing a report with no project content, documented limits behaving as documented — are **unchanged**. |
| **§7.2.8**, code-signing row | "Windows code signing with certificate procurement started **two milestones early**; vendored pdfium; release pipeline with symbol archival." | **The procurement clause is superseded**; read the row as self-signed with a timestamp, no early procurement, Trusted Signing as the named fallback. **Vendored pdfium and the release pipeline are unaffected.** |
| **`RISK-07`** (roadmap §7) | "Code-signing certificate lead time blocks a finished build … prefer EV to avoid the SmartScreen reputation ramp." | **Retired in this form.** Replaced by a smaller, wholly internal risk: the public `.cer` is not deployed to the target machine's stores. Likelihood low, impact minor, early warning "a clean test machine shows *Unknown publisher*", mitigation a GPO. |
| **`RISK-08`** (roadmap §7) | "Beta integrators cannot be recruited in time for M9." | **Population changes; the risk does not disappear.** Three integrators become three internal users on three real jobs. **M9's exit criterion is unchanged** and is still a judgement, not a metric. |
| **RJ-014**, certificate sentence | "The part that genuinely cannot wait — the code-signing certificate, whose OV/EV validation and reputation build take weeks — is accepted and scheduled two milestones ahead of release (AC-058/D10)." | **Superseded in that sentence only.** Nothing needs scheduling ahead. RJ-014's ruling — **no in-app auto-update in v1**, a signed installer plus a "Check for updates" item and a version string — is **reaffirmed**, and the `.rmdev` user-library migration half (AC-050/A8.2) is untouched. |
| **§10.3** | Pricing and licensing model; recommendation (c), a free tier with a watermarked PDF. | **Moot while DR-006 stands** — there is nothing to price. Retained in full as the record of the argument. **If DR-006 is reversed, §10.3 reopens exactly as written**, watermark hazard included. Indexed at §13. |
**Derived documents that now state a superseded ruling.** These are priority-3 documents
(Part 4 preamble), not Parts 1–3, so they are **edited rather than pointered** — and the edits are
**owed, not yet made**. Each is listed here so the debt is visible rather than discovered. **This
table is the whole list; a site not on it is a defect in this table, not an exemption.**

*Signing and distribution — the sites DR-006's ruling reaches directly:*

| Document | Site | What it must become |
|---|---|---|
| `docs/11-testing-and-quality.md` §11 | Row 1, "Windows OV/EV certificate procurement — **starts at M6**" | Self-signed with a timestamp; no early procurement; Trusted Signing named as the M8 fallback |
| `docs/11-testing-and-quality.md` §11 | Row 2, "Exit criterion: a signed installer runs … with **no SmartScreen warning**" | The split criterion of §11.6.2 |
| `docs/09-roadmap.md` §4 | M6 exit criterion, last sentence | The sentence is deleted |
| `docs/09-roadmap.md` §4 | M8 exit criterion, first clause; and M8 *Risks* ("This is a purchasing decision, made at M6") | The split criterion of §11.6.2; the purchasing decision no longer exists |
| `docs/09-roadmap.md` §7 | `RISK-07` row | Retired in its stated form and replaced per consequence 7 |
| `docs/09-roadmap.md` §7 | `RISK-08` row, mitigation column | Population is internal; the criterion is unchanged |

*Decision counts and the §10.3 schedule — the sites DR-006 falsifies **arithmetically**, which is
why a debt list built around signing missed them on first pass:*

| Document | Site | What it now says | What it must become |
|---|---|---|---|
| `docs/09-roadmap.md` §8 | Item 7, at **:498** | "**Five are now answered — `DR-001` through `DR-005`**", and "pricing (§10.3) wants deciding before M6" | **Six** are settled — five answered, §10.3 **moot** (§11.6.3/12, §13). Pricing needs deciding neither before M6 nor at all while DR-006 stands. The macOS (§10.10) half of the sentence is unaffected |
| `docs/10-decisions.md` | **:6** | "…and Part 4's binding user decisions `DR-001`–`DR-005`" | `DR-001`–`DR-006` |
| `docs/10-decisions.md` | **:11**, and the DR table headed at **:37** with rows **:42-46** | "**the five user decisions `DR-001`–`DR-005`**", over a five-row table with no DR-006 row | Six decisions; a `DR-006` row reading *internal tool, self-signed distribution*, answering *nothing in §10 — moots §10.3*, with effect *no certificate procurement at any milestone; M8's criterion splits* |
| `docs/00-overview.md` §11 | **:216** | "…and the binding user decisions `DR-001`–`DR-005`" | `DR-001`–`DR-006` |

Until those edits land, **`docs/12-milestone-board.md` is the index that records the gap** — its
M6 and M8 entries quote the roadmap verbatim and then state the DR-006 amendment beneath, which is
the same pattern §12.8 uses inside this record, and its §4.11 carries both tables above.

**Explicitly NOT superseded — listed here because they will otherwise be cut by association:**

| Ruling | Status under DR-006 |
|---|---|
| **DR-005** | **Unaffected, and the confusion is foreseeable enough to name.** DR-005 is about **the sheet set**; DR-006 is about **the software**. An internal tool used by an integrator still emits sheets handed to a client, a GC and a job site. Full sheet furniture stays a v1 deliverable and stays unavailable as a schedule lever (§11.5.2/2). |
| **CR-100** | **Unaffected.** pdfium is still vendored. A network-fetched binary in a signed release is a supply-chain and reproducibility problem whether the release is sold or not. |
| **AC-058/D7** | **Shrinks, does not vanish.** SIL OFL 1.1 and every bundled licence still register via `LicenseRegistry` and stay reachable from `showLicensePage` — that follows from redistributing the fonts, not from selling the software. The commercial EULA and licence-enforcement machinery go. |
| **CR-096, AC-058/D14, the M8 crash-report clause** | **Unaffected.** Local-first, opt-in remote, no project content in a report, recovery files never attached automatically. An internal user's project data is still a client's project data. |
| **AC-056** | **Unaffected.** Mobile/tablet read-only on three named surfaces is a product decision, not a distribution one. |
| **Confirmed product decision 4** | **Unaffected.** All seven brief requirements remain in v1. DR-006 removes a purchase, not a requirement. |

### 12.10 DR-007 supersedes nothing (keystone strap geometry into M3)

**No entry, and the absence is the record.** DR-007 is the first ruling in Part 4 that voids no
Part 1–3 ruling. It is an **addition** to v1 scope made under roadmap §8.3, not a reversal, so a
reader looking for its supersession list is not missing one.

It **extends** two rulings without changing either. `Outlet` remains "ONE WALL PLATE / ONE CEILING
LOCATION" (**CR-016**) and gains an ordered gang list — the alternative, one `Outlet` per gang,
was rejected precisely because it would have redefined CR-016 rather than extended it.
**CR-121**'s keystone rule is consumed as written: the keystone follows `jacketColorId`, never
`jacketColorPulledId`. **CR-047** (the arbitrary-depth location tree), **CR-108** (outlet
templates) and **CR-112** (the project-level Locations panel) are untouched and already carry M3
checklist items.

What DR-007 does change is a **cost**, and §12.7's re-costing should be read with it: M3 stays
`M` but at the upper end, because its exit criterion — a 60-drop rough-in producing a Pull Sheet —
does not itself require strap geometry. The ruling accepts that growth deliberately, on the ground
that building the `Outlet` editor twice is worse work than building it once with the grid designed
in. See §11.7.


---

## 13. Resolved §10 questions

§10 is no longer entirely open. **Six** of its thirteen entries are **ANSWERED** — five by the
user's direct answers (DR-001…DR-005) and one, §10.3, **mooted by DR-006** rather than answered on
its own terms. The text of §10 stays in place as the record of the argument; this section is the
index of what was decided.

| § | Question | Status | Answer |
|---|---|---|---|
| **10.1** | Draw every wire, or net labels by default — the fork | **ANSWERED — DR-001** | **(B) Net labels by default.** Drawn wires on domain filter, `Alt`-hover or focus. Reverses the record's recommendation. §11.1. |
| **10.2** | Residential CI or commercial AV — the primary customer | **ANSWERED — DR-002** | **(a) Residential-primary, commercial-capable.** Commercial capability present, never fronted. Confirms the recommendation. §11.2. |
| **10.3** | Pricing and licensing model | **MOOT — DR-006** | **Nothing to price.** RackMate is an internal tool and no commercial release is planned, so no pricing or licensing model is chosen and none is needed. Retained in full as the record of the argument: **if DR-006 is reversed, §10.3 reopens exactly as written**, watermark hazard included. §11.6, consequence 12. |
| **10.4** | Does the device builder have to be in v1 | **ANSWERED — DR-003** | **(a) Yes. M4 stays where it is.** Confirms the recommendation. §11.3. |
| 10.5 | Metric or imperial default | open | — |
| **10.6** | Is the schematic a client deliverable or an internal tool | **ANSWERED — DR-005** | **(a) Client deliverable — invest in drafting polish.** Reverses the record's recommendation. Orthogonal to 10.1. §11.5. |
| **10.7** | Multi-sheet timing | **ANSWERED — DR-004** | **(c) Never.** One `Sheet` plus domain filtering, permanently. The entity remains. §11.4. |
| 10.8 | Cloud-ready investment | open | — |
| 10.9 | Generic archetypes forever, or a real-SKU catalog | open | — |
| 10.10 | macOS in v1 | open | — |
| 10.11 | What the beta gate actually is | open | — |
| 10.12 | Small calls needing an owner | (d) settled; (a)(b)(c)(e)(f)(g) open | (d) three residential + one commercial starter project, settled by DR-002. |
| 10.13 | The three to answer first | **retired** | All three — 10.1, 10.2, 10.4 — are answered. The section has served its purpose. |

### 13.1 What the answers make easier or moot

| Remaining question | Effect |
|---|---|
| **10.3 — pricing** | **Moot under DR-006 — no longer a remaining question.** The row is kept because the reasoning survives its own mooting: DR-005 makes the client-facing set larger and more valuable, which would strengthen option (c)'s logic (price the deliverable, not the software) *and* raise the stakes on the watermark split — client-facing sheets only, never the Pull Sheet or Termination Schedule. That is the state §10.3 reopens in if DR-006 is ever reversed. It no longer needs deciding before M6, or at all. |
| **10.5 — metric or imperial** | **Unchanged and still cheap.** DR-002 tilts it toward (a) imperial default, since North American residential is the stated primary market. One settings row either way. |
| **10.8 — cloud-ready investment** | **Easier.** DR-004 removes multi-sheet, which was the largest remaining source of entity-graph churn. The conflict unit is more stable than it was, so (a) — spend nothing further, write the conflict-unit page down — is now the clear answer rather than the cautious one. |
| **10.9 — real-SKU catalog** | **Better instrumented.** DR-003 keeps the builder, so the long tail has a first-class answer in v1 and the real-SKU question stops being urgent. Measure 7's miss rate now feeds this question instead of 10.4. |
| **10.10 — macOS in v1** | **Unchanged.** Independent of all five. Ask before M7. |
| **10.11 — the beta gate** | **Easier.** DR-005 makes M9's criterion sharper and more testable: "a sheet set they were willing to send out" now has a concrete bar — full sheet furniture, revision block populated, IFC stamp available. |
| **10.12(a) undo depth, (b) autosave, (c) default rack height** | Unchanged. |
| **10.12(e) telemetry** | **Easier.** Its only stated cost was that opt-in-only makes 10.4's miss-rate instrumentation manual. 10.4 is answered, so that objection is gone: opt-in, local-first crash reports only. |
| **10.12(f) branding** | Unchanged. RJ-017 stands. |
| **10.12(g) is `rules.md` user-visible** | **Answer stands, home changes.** Still user-visible, in-app, linked from every finding — but the catalogue's canonical home is the data-model document's validation section, not a separate `docs/rules.md`, and the count is **27**, not 22. |
| **10.13** | **Moot.** Retired; all three are answered. |

---

## 14. PAL-1, restated — the greyscale rule over rendered values

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
base values — which is what is actually drawn. And it is **disjunctive**: the old conjunctive
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

The first three collisions found — these fixes stand and are reproduced in the check file:

| Pair | Before | Verdict | Fix |
|---|---|---|---|
| `audio.spdif_optical` (TOSLINK, L 0.2215) vs `ctl.ir_emitter` (IR, L 0.2930) | `2,3` @ 1.00× vs `1.5,3` @ 0.75×. ΔL 0.0715; both `(dot)`; ratio **1.33**. | **FAILS.** Two of requirement 4's ten named types render as near-identical fine dots in greyscale. | **`audio.spdif_optical` weight 1.00× → `1.25×`.** Dash stays `2,3`. Ratio becomes **1.67 ≥ 1.4** ✓ |
| `structure.pathway` (L 0.3185) vs `ctl.ir_emitter` (L 0.2930) | `2,6` @ 0.75× vs `1.5,3` @ 0.75×. ΔL 0.0255; both `(dot)`; ratio **1.00**. | **FAILS.** | **`structure.pathway` dash `2,6` → `1.5,3,1.5,9`**, class `(dot,dot)` ✓, period 15 pt. Weight stays 0.75×. A double-dot reads correctly as "a route, not a conductor". |
| `structure.undetermined` (L 0.3185) vs **five** families: `audio.line_unbal` `6,3` @ 1.00×, `audio.mic` `4,3` @ 1.00×, `audio.headphone` `3,3` @ 0.75×, `ctl.rs485` `6,3` @ 1.00×, `ctl.trigger12v` `4,3` @ 0.75× | `4,4` @ 0.75×, inherited from the `str` domain base. ΔL 0.0977 / 0.0977 / 0.0977 / 0.0255 / 0.0255; **all six are `(short)`**; ratios 1.33, 1.33, **1.00**, 1.33, **1.00**. | **FAILS all five.** Against `audio.headphone` and `ctl.trigger12v` the dash class *and* the weight are identical — in greyscale they are the same line, separated by hue alone. | **The `str` domain base dash `4,4` → `6,3,3,3`**, class `(short,short)` ✓, period 15 pt, permille `[6000, 3000, 3000, 3000]`. Weight stays 0.75×. `structure.undetermined` carries no `dashOverride` and inherits it, so the legend's `str` swatch and the drawn line move together. `structure.undetermined` is the correct family to move: it is a placeholder, it is not one of requirement 4's ten named types, and moving it is one edit against five. |

`ctl.ir_emitter` is deliberately **not** touched: it is a requirement-4 named type and its `1.5,3`
was itself the correction that brought the control domain up to the dash-period floor.

**The "What was verified, and how" paragraph that stood here is retracted.** It claimed all three
fixes "were checked by enumerating every shipped `SignalFamilyDef` (55 families across the eight
domains) … and comparing it against every family in a different domain whose luminance is within
0.10", and it published per-family in-band tallies and pass counts. **No such enumeration was
performed.** Its own figures give it away: TOSLINK's in-band set is **27** families across four
domains, not the 26 it reported. That made three successive assertions that PAL-1 was "verified
clear" — each one made by reading a table of eight domain rows rather than enumerating the family
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
changed** — the Okabe–Ito domain palette is untouched.

| Family | Before | After | Class change | Why |
|---|---|---|---|---|
| `video.hdmi.1_4` | solid @ 1.00× | **solid @ 0.75×** | stays `solid` | It was byte-identical to `video.hdmi.2_0`, violating the within-domain limb. The three HDMI generations now read as a bandwidth progression **0.75× / 1.00× / 1.25×** and all stay solid — solid being the native digital-video carrier. |
| `video.composite` | `12,4` @ 1.00× | **`1.5,3` @ 1.00×** | `long` → `dot` | Weight is untouched; the analog-video base weight semantics are preserved. |
| `audio.line_bal` | `10,3` @ 1.00× | **solid @ 1.00×** | `long` → `solid` | It collided with **four** `video.analog` families at once — `video.composite`, `video.svideo`, `rf.ota` and `rf.modulated` — all at ΔL 0.0112. |
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
**every cross-domain pair** against §14.1. It exists today as **`tools/pal1_check.py`** — runnable
before any Dart exists (`python tools/pal1_check.py`, exit 0 clean, 1 on any violation) — and is
ported to `pal1_conformance_test.dart` in `rackmate_core` at M0, remaining the authority
thereafter. It is a named acceptance criterion of the registry (§6.7) and of M2's exit. The
within-domain exemption is expressed in the test as a domain-equality check, **not** as an
allowlist of pairs — an allowlist is how a real collision gets waived.

---

**End of Part 4.** DR-001…DR-007 are the user's decisions and are binding. §12 is the complete
index of what they supersede — §12.1…§12.5 and §12.9 by ruling, §12.6 by internal correction, and
§12.8 the list of Parts 1–3 sites carrying a pointer. Anything not listed there stands as written
in Parts 1–3.
