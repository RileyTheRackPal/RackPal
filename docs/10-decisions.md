# Architecture Decision Record

This is the short-form decision log for RackMate: sixteen ADRs covering the choices that shape
the codebase, each traced back to its adjudication in the canonical decision record, followed by
the thirteen open questions that are deliberately *not* decided and are the user's to call. An
ADR here is a summary with a pointer, not a new ruling — where an ADR and a `CR-nnn`/`AC-nnn`
ruling appear to differ, the ruling wins and this file is wrong. Open questions carry no
normative weight at all: each states its options, the honest trade-off, the evidence that would
settle it, and a recommendation explicitly labelled as such.

| ADR | Title | Status | Governing rulings |
|---|---|---|---|
| [001](#adr-001-desktop-first-windows-first-mobile-read-only) | Desktop-first, Windows-first, mobile read-only | Accepted | Confirmed decision 1, AC-056, AC-016 (#23) |
| [002](#adr-002-local-single-file-projects-with-a-cloud-ready-model) | Local single-file projects, cloud-ready model | Accepted | Confirmed decision 3, CR-095, CR-094 |
| [003](#adr-003-file-extensions-and-container-format) | File extensions and container format | Accepted | CR-091, CR-063, CR-098, AC-057 |
| [004](#adr-004-schema-versioning-and-the-migration-chain) | Schema versioning and the migration chain | Accepted | CR-092, CR-093, CR-117 |
| [005](#adr-005-a-seeded-catalog-of-48-generic-archetypes) | A seeded catalog of 48 generic archetypes | Accepted | CR-061, CR-062, RJ-007, AC-052 |
| [006](#adr-006-the-templateinstance-split-copy-on-place) | The template/instance split — copy-on-place | Accepted | CR-054, CR-051, CR-053, AC-041 |
| [007](#adr-007-the-wiring-entity-model-link--service--conductor--net) | The wiring entity model | Accepted | CR-008, CR-010, CR-011, RJ-003 |
| [008](#adr-008-route-geometry-is-not-persisted) | Route geometry is not persisted | Accepted | CR-012 |
| [009](#adr-009-the-v1-routing-algorithm) | The v1 routing algorithm | Accepted | CR-013, AC-016 (#20) |
| [010](#adr-010-three-tier-validation-strictness) | Three-tier validation strictness | Accepted | CR-017, CR-018, CR-019, CR-022 |
| [011](#adr-011-state-management-riverpod-over-a-single-mutation-gate) | State management | Accepted | CR-119, AC-016 (#19), AC-013 |
| [012](#adr-012-undoredo-one-command-machinery-three-stacks) | Undo/redo — one machinery, three stacks | Accepted | CR-106, CR-094, AC-014 |
| [013](#adr-013-one-renderer-for-screen-and-pdf) | One renderer for screen and PDF | Accepted | CR-086, CR-081, CR-083, CR-087, CR-088 |
| [014](#adr-014-two-views-elevation-and-schematic) | Two views — elevation and schematic | Accepted | RJ-002, CR-105, CR-104 |
| [015](#adr-015-the-five-package-split) | The five-package split | Accepted | CR-083, CR-084 |
| [016](#adr-016-density-management-one-sheet-filter-degrade) | Density management — one sheet, filter, degrade | Accepted | CR-073, CR-103, AC-037, §10.1 |

See also [Overview](00-overview.md), [Data model](02-data-model.md),
[Architecture](03-architecture.md), [Roadmap](09-roadmap.md).

---

## ADR-001: Desktop-first, Windows-first, mobile read-only

**Status:** Accepted. Fixed by confirmed product decision 1; not open.

**Context.** The user is a professional integrator at a desk with a mouse, two monitors and a
printer. The authoring surfaces — a 45U elevation, a schematic canvas, a 30-column port grid —
are pointer-and-keyboard instruments. A phone in an attic is a different user in a different
posture doing a different job: reading.

**Decision.** v1 is a **single-window Windows desktop application** (§7.1). Mobile and tablet are
**read-only on exactly three surfaces** — rack elevation, schedule table, exported PDF — and the
app says so in copy rather than shipping a squeezed editor (AC-056). Touch is not precluded:
`CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` is built **first**, and no editor logic
anywhere branches on `PointerDeviceKind` (AC-016 #23). macOS is deferred pending §10.10.

**Consequences.** The intent layer is written before the first gesture, which costs a few days up
front and makes mobile editing a v2 product decision rather than a rewrite. Three read-only
surfaces must be designed and tested as first-class, not as leftovers. Every Windows-only
dependency taken in M0–M6 must be recorded as a named macOS debt item.

**Alternatives rejected.** A responsive single codebase that edits everywhere — it degrades the
desktop experience to serve a use case (schematic editing on a 6-inch screen) nobody has asked
for.

---

## ADR-002: Local single-file projects with a cloud-ready model

**Status:** Accepted. Fixed by confirmed product decision 3.

**Context.** Integrators keep jobs in a folder per client, on a NAS or in Dropbox, and expect to
copy, email and archive a project as one artifact. Sync, if it ever comes, must not require
reissuing every identifier in every existing file.

**Decision.** A project is **one file on disk**. The model is cloud-ready by construction and
nothing further is spent: UUIDv7 identity everywhere, **no positional identity**, `FracIndex`
ordering rather than array position (CR-027), `EntityMeta` and **tombstones on the conflict-unit
set** (CR-095), and **two counters** — `RackDocument.sequence`, strictly monotonic across every
committed transaction *and* every undo/redo, persisted, the sync cursor; and
`RackDocument.stateId`, in-memory, non-monotonic, driving `isDirty` (CR-094).

**Consequences.** Tombstones and `EntityMeta` cost file size and code in v1 for a feature that
may never ship — accepted under G5, because they are the one thing that cannot be retrofitted
without reconstruct-and-confirm over user data. `sequence` and `stateId` must never be conflated;
the temptation to use one counter for both is the defect CR-094 exists to prevent.

**Alternatives rejected.** A project *directory* (`.history/` folders, sidecar assets) — CR-098;
it breaks copy/email/archive and there are no assets left to hold once images are cut (AC-057).

---

## ADR-003: File extensions and container format

**Status:** Accepted.

**Context.** Three documents specified three containers for `.rackmate`: plain JSON, "not zipped,
not binary", and a zip carrying `project.json` plus `assets/`. The zip existed solely to hold
512 KB per-face device images.

**Decision.** Per CR-091 and §4.6:

| Extension | Contents |
|---|---|
| `.rackmate` | One project. **Plain, pretty-printed, key-sorted UTF-8 JSON**, `document` wrapper. |
| `.rmdev` | One device template. Plain JSON, **same unit regime** — `depthNm`, `weightUg`, `xNm` (CR-063). Own migration chain. |
| `.bak` | The single sibling backup of a `.rackmate`. No `.history/` folder (CR-098). |
| `.rmlib` | **Cut from v1** (AC-042). Signatures and provenance chains go with it. |

Device images are cut (AC-057), which is what dissolves the zip requirement. `DocumentCodec`
nevertheless **sniffs `PK\x03\x04` on read from commit one**, so a v2 zip container is a
non-event rather than a format break.

**Consequences.** Projects diff and merge in git, are greppable, and are debuggable by hand — a
real advantage while the format is young. Files are larger than a zip and there is no place to
put a binary asset until the sniff path is implemented.

**Alternatives rejected.** Zip from day one — it buys nothing once images are cut and costs
inspectability. A binary format — premature by an order of magnitude.

---

## ADR-004: Schema versioning and the migration chain

**Status:** Accepted.

**Context.** Two documents specified incompatible migration control flow (throwing vs
`Outcome<T>`), and the non-throwing snippet contained an inverted comparison that would have
opened a file the reader cannot understand.

**Decision.** Per CR-092, the envelope keeps format metadata at the root and all entity maps
under a `"document"` wrapper, so the magic-key check is one top-level read before any parsing.
Per CR-093, migration returns **`Outcome<T>` and never throws**:

```text
minReaderVersion >  kSchemaVersion               -> Err(NewerSchema(refuse))
schemaVersion    >  kSchemaVersion
  && minReaderVersion <= kSchemaVersion          -> Ok(doc, openReadOnly: true)   [unknown fields preserved]
schemaVersion    <  kSchemaVersion               -> apply migration chain, step by step
```

One implementation, in `rackmate_core/persistence/migrations.dart`, specified in
[docs/file-format.md](file-format.md), with a **golden corpus**: every historical schema version
keeps a fixture that must still open. Byte-round-trip stability is a tested contract (CR-117) —
key order, `unknown` maps, timestamp precision and integer formatting are all pinned, because
they are what otherwise produce spurious diffs and a lying dirty flag.

**Consequences.** Forward-compatible reads require preserving unknown fields through a Save As,
which every codec must honour. A migration is never skippable — the chain runs step by step.

**Alternatives rejected.** Exceptions for expected outcomes; a version *range* check instead of
`minReaderVersion`.

---

## ADR-005: A seeded catalog of 48 generic archetypes

**Status:** Accepted. Fixed by confirmed product decision 2; the *count* is the decision.

**Context.** Four documents stated four catalog sizes (58, 62, ~40, "~30–50"). A critique
proposed shipping the catalog at lower fidelity — names and RU heights, ports filled in later.

**Decision.** v1 ships **48 templates: 30 rack-side and 18 field-side** (CR-061), mid-band in the
confirmed 40–55, with the field devices of AC-019/AC-031 included. The count is stated in
**exactly one place**, [docs/catalog.md](catalog.md); no prose anywhere states a number. Fidelity
is full, not partial (RJ-007), and the shipping gate is **cited provenance**: every numeric field
in every template has a source in `assets/catalog/sources.md`, and a template with uncited
safety-adjacent fields does not ship (AC-052). Seeded templates are read-only; editing one
performs duplicate-and-edit, and the fork records `derivedFrom` so a later catalog correction
surfaces as a passive badge rather than being silently lost (CR-062).

**Consequences.** Authoring 48 cited templates is a real, schedulable content job, not a
side-task. The connector footprint table must be complete for every connector any of the 48 uses,
with a CI assertion (AC-050 A2.2). A low-fidelity catalog would have shipped sooner and taught
users the numbers cannot be trusted — which is the G4 failure the honesty filter exists to catch.

**Alternatives rejected.** Lower fidelity now, fill in later (RJ-007). Real SKUs — a legal and
maintenance question, see §10.9.

---

## ADR-006: The template/instance split — copy-on-place

**Status:** Accepted.

**Context.** The corpus offered two doors, four verbs and three separate snapshot stores for
"this instance differs from its template", plus a full package-manager-grade update system:
semver classifier, two-column diff, safe/additive/breaking grouping, per-cable remap ranking.

**Decision.** **Three doors, one snapshot store** (CR-054):

| Door | Effect |
|---|---|
| Edit this device only | writes typed `DeviceOverrides` / `PortOverrides`; template untouched |
| Edit the template | forks `version+1` in the library; placed instances untouched until opted in |
| Fork to a new template | new `templateId` seeded from snapshot + overrides; instance rebinds, overrides cleared, `derivedFrom` recorded |

There is no fourth "detach" verb — it produces a device with no lineage. `localTemplate` and
`PlacedDevice.snapshot` are deleted; snapshots live only in `RackDocument.templates`, keyed
`"$templateId@$version"`. Placement is **copy-on-place** (AC-041): `templateRef{templateId,
version, contentHash}` is recorded, the snapshot embedded, and an out-of-date instance gets a
passive badge — no Update Manager in v1. `contentHash` mismatch is a **warning plus a badge,
never a load failure** (AC-042). The migration join key is `PortDef.key` + `renamedFrom`, never
`portId` (CR-051), and a removed port never silently deletes a cable (CR-052).

**Consequences.** A project opens correctly with no library present, which is what makes emailing
a `.rackmate` work. Catalog corrections do not propagate in v1; the badge is the entire remedy.
The Update Manager (v1.2) needs no format change when it lands.

**Alternatives rejected.** Live template references (a library edit silently rewires shipped
projects). Per-instance detached templates (CR-054).

---

## ADR-007: The wiring entity model — Link → Service → Conductor → Net

**Status:** Accepted. The highest-blast-radius ruling in the record after the unit choice.

**Context.** Four documents used four namings (`Connection`, `PhysicalLink`+`LogicalSignal`,
`Link`+`Net`+`Conductor`, `SignalRoute`), and every one of them modelled a cable as carrying
exactly one signal. The trade says otherwise: one Cat5e routinely carries an IR emitter run, a
12 V trigger and an RS-232 to the display, on separate pairs.

**Decision.** Per CR-008, CR-010 and CR-011, four entities with strictly separated jobs:

```text
Link      one physical cable  { id, designator, class, media, jacket, gauge, shielded, plenum,
                                lengths, status, test, pathwayId, breakouts[], conductors[],
                                services[] }
  Service one signal on it    { id, signalFamily, netId, conductorRoles[], label }
Conductor one electrical path { role, from: Endpoint, to: Endpoint, pairNumber, colorCode,
                                polarity }
Net       one stored logical equivalence class, joined by the FK Service.netId
```

The word **`Connection` is banned** from code, file format, UI and prose (§4.7), as are
`PhysicalLink`, `LogicalSignal` and `CableType`. `Net` is **stored, not derived** (CR-011,
RJ-003): membership is the foreign key, never the net *name* — name-carried membership is the
KiCad typo failure and a GUI tool with a device library has no excuse for it. Union-find is used
only to *propose* merges that a command then applies. `Endpoint` is a sealed union —
`PortEndpoint`, `PlaceEndpoint`, `OpenEndpoint` (AC-018) — so a cable to a room that has no
device yet is representable. Each **`Conductor`** spans exactly two endpoints; a `Link` may touch
more than two devices via `breakouts[]` (CR-014).

**Consequences.** The schedule can render one row per cable with its services listed, which is
what an installer actually needs. `Service.netId` ships as one FK with no net editor in v1 — G5
in its purest form, since reconstructing membership later means union-find plus a
confirm-every-guess pass over existing projects.

**Alternatives rejected.** Derived nets in v1 (RJ-003 — one field now versus a reconstruction
later). One service per cable (contradicted by the trade, CR-010). `SignalRoute` as a third layer
(deferred to v2 with a Dante view, or not at all — AC-036).

---

## ADR-008: Route geometry is not persisted

**Status:** Accepted.

**Context.** One document declared "no wire coordinates, no route geometry — if you ever find
yourself persisting a polyline you have made an architectural error", then shipped waypoints,
pinned routes and `routeOverrides?` three sections later. Another declared
`Map<Uuid, List<Pt>> waypointsBySheet`.

**Decision.** Per CR-012, **no route geometry is persisted in v1**. The router is a pure
deterministic function of the model, so the drawing is always consistent with the connectivity by
construction. `waypointsBySheet`, `routeOverrides` and `RouteWaypoint` are deleted. **Symbol
placement *is* persisted** — that is genuine user intent (`SheetItem`, with `pinned`). When
manual rerouting returns in v1.1 it is stored as **constraints** — an ordered list of grid points
the router must pass through, `routeConstraintsBySheet` — never as a polyline.

**Consequences.** A stale polyline can never disagree with the model; there is no reconciliation
pass and no "the wire points at nothing" state. The user cannot nudge a wire in v1, which is an
aesthetic itch on a deterministic router, and is the accepted cost.

**Alternatives rejected.** Persisted polylines with reconciliation on load — the class of bug it
introduces (drawing and schedule silently disagreeing) is exactly what G1 cannot tolerate.

---

## ADR-009: The v1 routing algorithm

**Status:** Accepted.

**Context.** One document specified an obstacle-avoiding orthogonal trace router with an
`ObstacleField`, a `RouteCache` and per-connection incremental invalidation. Another argued
RackMate never needs a general orthogonal router, and that a full deterministic recompute is both
cheaper than the invalidation bookkeeping and perfectly stable.

**Decision.** Per CR-013: **Sugiyama layering (phases 0–4) + interval-graph channel routing, full
deterministic recompute.** `ObstacleField`, `RouteCache` and the phrase "obstacle-aware" are
deleted (§4.7). One amendment: **phase 5 — the crossing sweep and hop arcs — does not run at
commit**; it runs at paint time, scoped to the visible viewport.

```text
0 cycle-break -> 1 layer -> 2 barycentre sweep -> 3 coordinate assign -> 4 channel route
                                                                        (interval-graph colouring)
                                        ...at paint time, viewport-scoped: 5 crossing sweep + hops
```

**Consequences.** No cache invalidation code exists to be wrong. Layout is reproducible — the
same document yields the same drawing on every machine, which is a precondition for the golden
PDF tests. Recompute cost is bounded by the sheet, not the project; a sheet exceeding budget is a
density problem (ADR-016), not a routing one.

**Alternatives rejected.** Incremental invalidation (CR-013 — the bookkeeping costs more than the
recompute it saves). A general A*/obstacle router (solves a problem a channel router does not
have).

---

## ADR-010: Three-tier validation strictness

**Status:** Accepted.

**Context.** One document said validation never blocks the pen and only five rules block
creation. Another defined a "Class A — hard-invalid, refused at drag time, cannot exist in the
document" tier including HDBaseT→switch and connector mismatch. A third had the rack editor
blocking drops on seven checks. Separately, `blockExportOnErrors` defaulted to `true`.

**Decision.** Per CR-017, the binding distinction is **the gesture may hesitate; the document may
not lie** — three tiers:

| Tier | Membership | Behaviour |
|---|---|---|
| **Model-illegal** | `TOP-001..005` + placement coherence (`ruIndex` in range, host is a container, no containment cycle) | Cannot be constructed. These are states in which the model *means nothing*. |
| **Gesture-refused** | ex-Class A | **Spring-back with a reason chip**, remedies kept exactly as designed, and every chip carries `[ Connect anyway ]`. |
| **Post-hoc finding** | the other 22-rule catalogue | `error \| warning \| advisory \| off` (CR-018); never blocks anything. |

Two ex-Class A members — Dante with no network path, AVB across a non-TSN switch — are
**logically unevaluatable at drag time** (the link being drawn may be the one that completes the
path) and are demoted to findings unconditionally. Dismissal is **one mechanism**:
`AckedFinding{ruleId, targetFingerprint, reason (required), by, at, demotedTo}`, at two scopes,
and **errors are acknowledgeable** (CR-019, RJ-006). `blockExportOnErrors` is **deleted, not
deferred** (CR-022); errors gate only `ExportSpec.issuedForConstruction`, and every export emits
sheet `T0.02 — Exceptions & Acknowledgements` carrying open findings and every acknowledgement
with its reason, author and date.

**Consequences.** An as-found miswired system is documentable, which is the remediation market
(G2). No heuristic can ever hold a deliverable hostage (G3). The cost is that the app will
sometimes print a drawing it believes is wrong — with a sheet saying so.

**Alternatives rejected.** Hard-invalid at drag time (CR-017). Non-dismissible errors (RJ-006 —
refusing to let a professional override the tool's opinion about their own system is how the tool
gets abandoned). Rules as a JSON predicate AST (CR-024, AC-011 — ~20 of 70 rules cannot be
expressed in a boolean tree, and the user-authored-rules claim is withdrawn from all documents).

---

## ADR-011: State management — Riverpod over a single mutation gate

**Status:** Accepted. **VERIFY:** Riverpod 3 API surface before the provider layer is written.

**Context.** The document is a large mutable aggregate with expensive derived values (occupancy,
rollups, findings, the routed scene). Naive rebuild-everything is not viable at 45U × several
racks × a few hundred links; ad-hoc mutation from widgets is how the undo stack silently
diverges from the document.

**Decision.** **Riverpod, with one `ProviderScope` per open document.** v1 is single-document,
single-window (CR-119) — `Ctrl+N`/`Ctrl+O` prompt Save / Don't Save / Cancel and then replace —
but the per-document scope is kept exactly as designed, because it costs nothing now and makes
tabs (v1.2) and multi-window mechanical rather than a rewrite. All mutation goes through
`DocumentController`, the single gate; entity setters are `@internal`, not `part of` (AC-013).
Derived state is an explicit **three-tier pipeline driven by epoch counters**, with `lodLevel`
appearing explicitly in every scene-builder signature and every cache key (AC-016 #13).

**VERIFY:** Riverpod 3 moved `ChangeNotifierProvider` to legacy (AC-016 #19). The `epochs.revision`
adapter is hand-written — roughly 15 lines of `Provider` + `ref.onDispose`. The legacy library is
not imported.

**Consequences.** Widgets can never mutate the model directly, so undo correctness is a property
of one class. Epoch counters must be incremented correctly or a stale cache renders — covered by
the epoch-mask coverage test.

**Alternatives rejected.** `ChangeNotifier` on the document (rebuild granularity is wrong and the
class is legacy in Riverpod 3). Global singletons (kills the per-document scope and therefore
tabs).

---

## ADR-012: Undo/redo — one Command machinery, three stacks

**Status:** Accepted.

**Context.** The command stack was scoped to `RackDocument`, while the device builder's port grid
and the Structure editor's drop table both asserted undoable operations on data outside that
aggregate. Separately, undo's effect on `revision` contradicted the sync design's monotonicity
invariant.

**Decision.** Per CR-106, **one `Command`/`Transaction`/`UndoStack` machinery, generic over an
aggregate, instantiated three times**:

| Stack | Scope | Notes |
|---|---|---|
| Document | `RackDocument` | The Structure editor's edits are ordinary document commands and use this stack. |
| Template | the template being edited | Owned by the device builder; **discarded on close without save**. |
| — | settings, library operations | **Not undoable**, and therefore individually confirmable or trivially reversible. |

Per CR-094, an **undo is a change**: it increments the persisted monotonic `sequence`, while the
in-memory `stateId` is restored, so undoing back to the save point correctly marks the document
clean. Undo depth is capped at 200 with a status-bar signal (AC-058 D5; see §10.12a). The command
stack ships in M0 — it is the most expensive retrofit in the project — and carries a round-trip
property test (apply/undo/redo returns byte-identical JSON).

**Consequences.** Three stacks means three "is this undoable here?" answers the UI must make
obvious; the shared machinery is what keeps them behaving identically. Nobody builds a second
mechanism, which is the entire point of stating it once.

**Alternatives rejected.** A single global stack spanning document and library (undoing a
template edit after closing the builder is incoherent). Snapshot-based undo (memory cost scales
with document size).

---

## ADR-013: One renderer for screen and PDF

**Status:** Accepted. Described in the record as the single most consequential architectural
ruling.

**Context.** The architecture declared a display list (`DiagramScene`) as the single drawing IR —
"screen and print cannot diverge" — and then specified device faceplates, ports and
ref-designators as **real widgets**. The most information-dense content in the deliverable was
therefore drawn by a widget tree on screen and by a scene builder in print, with no parity
mechanism, defeating the guarantee exactly where it mattered most.

**Decision.** Per CR-086, **one rendering path; widgets remain as an interaction and semantics
shell.** Each device is still a `RenderBox` child of `RenderRackCanvas` — it owns hit-testing,
focus, hover, keyboard handling and `Semantics`, which is what makes the accessibility story true
— but its `paint()` **replays that device's `DiagramScene` fragment through
`FlutterDiagramCanvas`** and draws nothing itself. Pixels come from the shared IR; behaviour
comes from the widget. Supporting rulings:

- **One injected `TextMeasurer`**, backed by `PdfFont.stringMetrics`, used by the scene builder
  and by **every** backend including the Flutter one. `measureText` returns
  `TextMetrics{advanceWidth, ascent, descent, capHeight, xHeight, lineHeight}`, never a point
  (CR-081, CR-087). Flutter sets `FontFeature.disable('kern')` **and**
  `FontFeature.disable('liga')`. `TextStyleSpec` carries an explicit `TextAnchor` resolved in one
  shared pure-Dart helper. The parity test asserts on **baseline Y**, not the bounding box.
- **`RendererCaps` is deleted** (CR-088) — the moment a scene builder branches on capabilities
  there are two code paths. No gradients, shadows, blurs, blend modes or shaders, promoted from
  prose to a tested invariant.
- **Global Y-flip** in the PDF backend, not per-coordinate negation (CR-085) — the interface
  exposes `rotate()`, and rotation composed with per-coordinate negation is not a valid
  transform. Text is counter-flipped in exactly one method. `pw.CustomPaint` pre-translates to
  the widget box's bottom-left, so the flip height is `size.y`, not the page height.
- **`BoundsCanvas` ships in v1** (CR-089) — scale-to-fit, tile counts, zoom-to-fit and the key
  plan all need the diagram's true extent. `SvgDiagramCanvas` is v1.1.

**Consequences.** The parity test covers faceplates by construction rather than by discipline.
Both backends and the parity test land **together and early** (CR-120) — retrofitting parity is
the expensive failure. Anything Flutter can draw and dart_pdf cannot is simply unavailable.

**Alternatives rejected.** Widgets for screen, scene builder for print, reconciled by review — a
PDF subtly and unfixably different from the preview. Independent `measureText` per backend
(CR-081 — Skia applies GPOS kerning and `liga`; dart_pdf applies neither).

---

## ADR-014: Two views — elevation and schematic

**Status:** Accepted. The strongest rejected argument in the corpus, rejected on evidence.

**Context.** A critique argued for one canvas: wire on the rear elevation, replace drawn lines
with port badges (`→ SW-01 P04`), show lines only under a filter or on hover. Two canvases means
two mental models, two coordinate systems, two selection behaviours, two colliding keymaps and a
what-syncs-what table the user meets as a surprise.

**Decision.** Per RJ-002, **both views ship**, and the four failures the critique predicts are
fixed directly and cheaply instead:

1. A 24-port patch panel to a 24-port switch renders as 24 badges reading `→ SW-01 P04` — a table
   drawn in the worst possible place. The proposal does not survive the density it exists to fix.
2. "Takes visual inspiration from electronics schematics" is not satisfiable by a badge on an
   elevation. Deleting the view deletes a requirement (RJ-001, RJ-002).
3. Positions are **not linked** between views and never will be: an AVR sits at U14 for thermal
   reasons and mid-chain for logical ones, and slaving either to the other destroys work silently.
4. The cliffs are fixed for days, not weeks: **CR-105** signposts wiring from the elevation (a
   `🔗 0/12` chip that jumps to the schematic with the device selected) and puts the **schedule
   table as the second tab**, live from an empty project; **CR-104** makes one palette, one insert
   command, placement decided by the drop target; **CR-101** arbitrates the ~40 keybindings from
   one `Intent` registry and fixes the 16 collisions.

Connections are **created in the schematic in v1**; editing endpoints from the schedule and from
the rear-panel view lands in v1.1.

**Consequences.** Two canvases to build, test and document, and a sync table with two exception
rows that gets a coach mark at the moment of surprise (AC-048). The deliverable is visible from
minute one rather than discovered at export (G1).

**Alternatives rejected.** One view with port badges (RJ-002). A generated, non-interactive
export-only diagram (RJ-001 — it removes the requirement that the user *makes* the connections,
and it means `SheetItem.pinned` has to be retrofitted after the format ships).

---

## ADR-015: The five-package split

**Status:** Accepted.

**Context.** One document specified four packages with `rackmate_export` and `rackmate_ui` as
siblings that cannot see each other — the invariant that keeps the PDF path isolate-safe. Another
specified a single `lib/` tree with the Flutter and PDF backends in one directory and
`TextMeasurer`/`PdfFontMeasurer` in the core tree — which makes core depend on `package:pdf` and
breaks the architecture's own `no_flutter_import_test`. ADR-013's single-measurer ruling forces a
resolution.

**Decision.** Per CR-083, **five packages** — the dependency is inverted rather than the core
contaminated:

```text
rackmate_core    pure Dart. NO flutter, NO dart:ui, NO package:pdf.
                 model, commands, derived, routing, draw/ (scene builders, hit_test, BoundsCanvas),
                 persistence, units/, idformat/, library/.
                 Declares abstract TextMeasurer + TextMetrics.
rackmate_text    pure Dart. core + package:pdf (PdfTtfFont ONLY). ~5 files.
                 The single concrete TextMeasurer.
rackmate_export  pure Dart. core + text + package:pdf. PdfDiagramCanvas, sheets, furniture,
                 tables, assembly. The isolate entry point.
rackmate_ui      flutter. core + text. FlutterDiagramCanvas, render objects, widgets,
                 canvas/input/.
apps/rackmate    everything + plugins.
```

`rackmate_ui` depending on `rackmate_text` is harmless — `package:pdf` is pure Dart and
isolate-safe. The invariant that matters is preserved and **mechanically enforced**:
`rackmate_core`, where the scene builder lives, has no concrete font engine and no `dart:ui`; it
receives a `TextMeasurer` by injection, and `no_flutter_import_test` keeps banning
`package:flutter/`, `dart:ui` and `package:pdf/` in core. Hit-testing splits by concern (CR-084):
the *geometric* test (`DiagramScene.hits`, point-to-segment distance, nearest-hit) lives in
`rackmate_core/draw/hit_test.dart` — pure, synchronously testable, reusable by the read-only
mobile shell; the *pointer plumbing* (one query per frame, spatial hash, cursor policy, hover
throttle) lives in `rackmate_ui/canvas/input/`.

**Consequences.** Package boundaries are enforced by a test rather than by convention — a folder
convention "will be violated within a month by an `Offset` that 'was just easier'". Five
`pubspec.yaml` files and path dependencies to maintain.

**Alternatives rejected.** One tree with folder conventions. Four packages with `TextMeasurer` in
core (drags `package:pdf` into core and breaks the enforcement test).

---

## ADR-016: Density management — one sheet, filter, degrade

**Status:** Accepted, **and downstream of open question §10.1** — the threshold behaviour is
settled, the default idiom is not.

**Context.** A whole-house job runs to 140+ connections. Every drawn-wire schematic degrades into
spaghetti somewhere past 80, and the failure is silent: the user does not notice when the drawing
stopped being useful. Multi-sheet is the obvious answer and is a subsystem.

**Decision.** v1 ships **one schematic sheet**, with the `Sheet` entity present in the format so
nothing migrates when multi-sheet lands (CR-073, AC-037). Density is managed on the sheet
instead, by four mechanisms that are cheap because they are all filters or LOD:

| Mechanism | Ruling |
|---|---|
| Domain filter bar | `critique-ux-simplicity.md`'s density table, accepted |
| **Auto net-label degradation** above a per-sheet threshold | §7.2.3; the fork in §10.1 decides the default |
| Symbol collapse to vector pins — one constant, `kBankCollapseThreshold = 8` | CR-103 |
| `Alt`-hover transient focus | §7.2.3 |

`kBankCollapseThreshold` replaces three separate thresholds (4 for vector-pin collapse, 17 for
unit split, 8 for symbol-preview collapse); any bank of ≥ 2 ports is user-collapsible at any
time, banks over 8 auto-collapse on first layout. Unit splitting is deleted with its 17-pin
threshold (CR-070). The exporter partitions by **domain only** when multi-sheet arrives in v1.2 —
which by construction has zero cross-sheet connections, so off-sheet connectors, zone grids and
cross-reference resolution are never built at all.

**Consequences.** The first PDF is not gated behind the multi-sheet subsystem — worth 4–6 weeks
(§7.7 cut #1). If §10.1 resolves to draw-every-wire, §10.7 (multi-sheet timing) should be
re-decided in the same sitting, because a 140-connection job may not fit one sheet.

**Alternatives rejected.** Multi-sheet in v1 (CR-073). Geometric or min-cut partitioning (creates
the cross-sheet connector problem that domain partitioning does not have).

---

# Open questions

Everything above is binding. **This section is deliberately the opposite.** These are the calls
that require a human judgement about what this product is for and who is going to buy it, which
no amount of internal consistency can supply. Each states the options, the honest trade-off, what
evidence would tip it, and a **recommendation carrying no normative weight** — a recommendation
here can be overruled without amending anything; a ruling above cannot. They are ordered by blast
radius, and the first one is a fork in what the product fundamentally is.

## 10.1 Draw every wire, or net labels by default — the fork

**The most consequential open question in the project, and not a rendering preference. It decides
what RackMate is.**

- **(A) Draw every wire.** The schematic is a *drawing*: every physical link is a visible
  orthogonal polyline pin to pin, with junction dots, hop arcs, arrowheads and tag pills at both
  ends. The KiCad/AutoCAD idiom; the most literal reading of "takes visual inspiration from
  electronics schematics"; what a client expects when handed a drawing they paid for.
- **(B) Net labels by default.** Every link is a short stub carrying a generated label
  (`HDMI_MTX1_OUT3`); lines are drawn only under a domain filter, on hover, or on focus. The
  Altium/Q-SYS idiom for dense designs; the only thing legible past ~80 connections.

| | (A) Draw every wire | (B) Net labels default |
|---|---|---|
| At 20 connections | Excellent — this is what people picture | Sparse; reads as an unfinished drawing |
| At 150 connections | Unusable without filtering; the density arithmetic is correct and unarguable | Still readable; the label *is* the information |
| "Looks like a schematic" to a client | Yes, unambiguously | To an EE yes; to a homeowner it looks like a parts list with brackets |
| Router cost | Full channel routing, track ordering, crossing sweep, hop arcs — the expensive half of M2 | Layering only; routing becomes nearly free |
| Failure mode | **Silent** — degrades gradually into spaghetti and the user never learns when it stopped being useful | **Loud** — "where are the lines?", and the user learns the filter |
| Reversibility | Adding label mode later is cheap | Adding full routing later is the expensive part of M2 |

**Why it is a fork, not a default.** It propagates into whether M2 is `L` or `M`; whether
multi-sheet is ever needed (under (B) one sheet holds a whole house and CR-073's deferral becomes
permanent); whether hop arcs, junction staggering, dash-phase divergence and the Bentley–Ottmann
sweep are built at all; whether the crossing count matters; and what the PDF diagram sheet *is*.
Under (B), roughly **4–6 weeks leave the critical path** and three of the hardest correctness
problems in the corpus disappear. Under (A), the product looks like the thing the brief describes
on first sight — worth more than an engineer's instinct usually credits.

**What tips it.** Put both in front of five integrators as **printed paper**, not on screen: a
40-connection theatre rack and a 140-connection whole-house system, one sheet each, both idioms.
Ask one question — *"which would you hand to your lead installer, and which to the homeowner?"*
If the answer differs by audience, that is itself the answer: ship both as a per-sheet render mode
and let the export dialog pick. Second signal: how many reach for the paper and trace a line with
a finger. People do that with (A) and cannot with (B), and it tells you what the drawing is *for*.

**Recommendation (not a ruling).** Ship **(A) as the default with (B) as automatic degradation
above a per-sheet threshold** — ADR-016's mechanism. Rationale: first impressions are made at 20
connections, not 150, and the degradation rule means the product never meets the density cliff.
The cost is building the router in M2 — precisely the 4–6 weeks at stake. **If the paper test
comes back (B)-preferred by three of five, take (B) and reclaim the weeks;** that result would be
strong evidence and this recommendation is not worth defending against it.

## 10.2 Residential CI or commercial AV — who is the primary customer

**Options.** (a) Residential custom integration, primary. (b) Commercial / conference-room AV,
primary. (c) Both, explicitly, with a mode switch.

**Trade-off.** The corpus is written for (a) — Structure devices, home runs, rooms, TIA-570-D,
credenza racks — while several of its most expensive features are (b) features: NCS sheet
numbering, layers for phased retrofit, TIA-606 rack labels, plenum and Class 2/3 code rules,
issued-for-construction stamps. (c) sounds free and is not: it doubles the vocabulary the user
must navigate, and TIA-570-D grades are a vocabulary residential integrators do not speak
(CR-108). Every "default off for wall racks" and "simple sheet numbering" ruling above is quietly
a bet on (a).

**What tips it.** Where the first ten paying users come from. Also whether the drawings ever go to
a permit office or a GC — if they do, (b)'s drafting apparatus stops being overhead and starts
being the reason the tool is bought.

**Recommendation (not a ruling).** **(a) residential-primary, commercial-capable** — which the
rulings already implicitly assume, so this is mostly a request to make the bet explicit and stop
paying for (b) features by accident. Commercial capability stays present (the code rules, the
ISO/NCS option, the field-device set) but never fronts the UI.

## 10.3 Pricing and licensing model

**Options.** (a) One-time perpetual licence per seat. (b) Annual subscription. (c) Free tier with
watermarked PDF, paid to remove the watermark. (d) Free entirely for now, monetise later.

**Trade-off.** Integrators buy tools the way they buy tools — a purchase order, once — and they
resent subscriptions for desktop software that syncs nothing. But (a) leaves the v1.1/v1.2 work in
§7.3–7.4 unfunded, and the catalog needs continuous authoring. (c) is the classic answer for a
document-producing tool and aligns exactly with G1: the thing people pay for is the artifact. It
carries a specific hazard here — **a watermarked pull sheet is worse than useless in an attic**,
so the watermark must go on client-facing sheets and never on field sheets, which is a product
decision disguised as a pricing one.

**What tips it.** Ask five integrators what they pay for D-Tools, Visio, or their CAD seat, and
whether it was a subscription. Also whether they expense software personally or through the
company — that changes the acceptable price by an order of magnitude.

**Recommendation (not a ruling).** **(c)**, watermark on elevations and diagram sheets only, never
on the pull sheet or termination schedule. It gets the tool into hands, prices the deliverable
rather than the software, and needs none of the licence-enforcement machinery (a) and (b) do.
Affects M8's scope, so it wants deciding **before M6**.

## 10.4 Does the device builder have to be in v1

**Options.** (a) Yes — M4 stays where it is. (b) Move it after M6; ship v1 with catalog plus
`DeviceOverrides` only. (c) A reduced builder — duplicate-and-edit an existing template, no
from-scratch authoring.

**Trade-off.** The brief fixed "device builder **plus** a seeded catalog" as confirmed decision 2,
so (b) and (c) are deviations from the brief and need explicit sign-off — that is why this is a
question and not a ruling. Against that: for a 16×16 matrix the right answer is genuinely
"duplicate catalog entry V03 and rename it, 15 seconds", so the builder is a barrier to
**completeness**, not to **adoption**. It buys 4–7 weeks off the critical path at the cost of the
long tail — and the long tail is exactly where a professional discovers the tool cannot represent
their job.

**What tips it.** **Instrument M1.** Ship the catalog and count how often users hit a device that
is not in it. Miss rate under ~10% of placements → (c) is enough. Over 25% → the builder is
load-bearing and (a) is right. This is the single most decidable question in this section, and M1
answers it for free.

**Recommendation (not a ruling).** **(a) keep it in v1** — it is a confirmed decision, and
AC-049's reduction to three required fields (name, RU height, designator prefix) already removed
most of what made it expensive. But treat M1's miss-rate instrumentation as the trigger to reopen
this; if the number comes back low, take (c), reclaim the weeks, and write the deviation down.

## 10.5 Metric or imperial as the shipped default

**Options.** (a) Imperial default, metric available. (b) Locale-derived. (c) Ask on first run.

**Trade-off.** RU is imperial by definition and the North American residential market thinks in
feet, inches and AWG; the rest of the world does not, and half the equipment depth specs are
published in millimetres regardless. (b) is the obvious engineering answer and is subtly wrong
here: a Canadian integrator's OS locale says metric and their cable footage is in feet. This is
**display only** — CR-001 makes storage exact in either system and units are a separate axis from
locale — so it is cheap to change and cheap to get wrong.

**What tips it.** Where the first users are. If North America, (a) with no further thought.

**Recommendation (not a ruling).** **(a) imperial default, one obvious toggle, mixed units
permitted per-field on input** — typing `450mm` into a depth field set to inches just works.
Because the cost of being wrong is one settings row, this should not consume more attention than
it already has.

## 10.6 Is the schematic a client deliverable or an internal tool

**Options.** (a) Client deliverable — invest in drafting polish, title blocks, revision clouds,
issued-for-construction stamps. (b) Internal working document — the client gets the elevation and
the equipment list; the schematic is how the integrator thinks and how the installer
troubleshoots.

**Trade-off.** This decides how much of the drafting apparatus is worth its cost, and it interacts
with §10.1: under (b) the net-label idiom is clearly fine because the audience is technical, and
the fork largely resolves itself. Under (a) the drawing must survive being looked at by someone
who has never read a schematic — a much harder bar, arguing for (A) in §10.1 plus real drafting
furniture.

**What tips it.** Ask integrators whether they currently give clients a signal-flow drawing at
all. Many do not — the client gets a proposal, an elevation and an invoice. If none of the five
does, (b) is the answer and a meaningful amount of M6 gets simpler.

**Recommendation (not a ruling).** **(b) internal-first**, with the title block and revision block
present (cheap, and they make the document self-describing) but no further drafting ceremony until
a user asks. G1 already points here: the schedule is the deliverable, the drawing is the receipt —
and a receipt is for the person who did the work.

## 10.7 Multi-sheet timing

**Options.** (a) v1.2, as ruled in §7.4. (b) Pull into v1. (c) Never — one sheet plus domain
filtering, permanently.

**Trade-off.** CR-073 already defers it and AC-037 keeps the `Sheet` entity so the format never
migrates, so this is only about timing, not architecture. It stays open because it is downstream
of §10.1: if that resolves to (A) draw-every-wire, a 140-connection whole-house job does not fit
one sheet and multi-sheet stops being a v1.2 nicety and becomes what makes the diagram usable at
real scale. If it resolves to (B), option (c) becomes genuinely plausible forever.

**What tips it.** The same paper test as §10.1, plus the distribution of connection counts in the
first twenty real projects. Median under 60 → (a) or (c). Median over 120 → (b).

**Recommendation (not a ruling).** **(a) hold at v1.2**, and re-decide immediately after §10.1
resolves. These two should be answered in the same sitting from the same evidence.

## 10.8 How much to invest now in the cloud-ready model

**Options.** (a) Keep exactly what is ruled — stable UUIDs, `schemaVersion`, no positional
identity, tombstones, `sequence` — and spend nothing further. (b) Add sync cursor plumbing,
per-entity LWW and a conflict-resolution design now, while the model is small. (c) Drop the
cloud-ready constraint and simplify.

**Trade-off.** (c) is not available — confirmed decision 3. (a) is what §7 rules. (b) is tempting
for the usual reason (the model will never again be this small) and dangerous for the usual one:
sync semantics designed without a real multi-user use case are almost always wrong, and wrong sync
semantics in a shipped format are worse than none. Note that AC-006 already removed per-port
`EntityMeta` on the grounds that device+ports is a single conflict unit — **so some conflict-model
thinking is already baked in and should be written down rather than left folkloric.**

**What tips it.** Whether anyone asks for two people in one project. In this domain that is usually
a designer and a project manager, and the honest answer is often "they take turns".

**Recommendation (not a ruling).** **(a)**, plus **one page in `docs/` stating the intended
conflict unit and merge story**, so AC-006's assumption is recorded. Spend nothing else until a
user asks twice.

## 10.9 Generic archetypes forever, or a real-SKU catalog eventually

**Options.** (a) Generic archetypes only, permanently. (b) Generic in v1, a real-SKU library
later. (c) A community-contributed library.

**Trade-off.** Confirmed decision 2 fixes (a) for v1, so this is a v2 question — worth answering
early because it changes what `.rmdev` and the template library are *for*. Real SKUs are the
single most-requested feature in every tool of this kind and the single largest ongoing cost:
hundreds of manufacturers, constant model churn, and a real legal question about republishing
manufacturer specifications and trademarks. (c) shifts the cost and creates moderation, data
quality and provenance problems — the last directly contradicting AC-052's citation gate.

**What tips it.** Whether users start emailing each other `.rmdev` files unprompted. If they do,
(c) is already happening and the only question is whether it is supported or ignored. Also: what
D-Tools' library is actually worth to the people who pay for it.

**Recommendation (not a ruling).** **(b), with (c) as the mechanism** — a curated community
library where every submission carries the same `sources.md` citation the shipped catalog
requires. That turns AC-052's gate from a cost into the quality bar that makes a community library
trustworthy, which is the thing every community parts library fails at.

## 10.10 macOS in v1

**Options.** (a) Windows only for v1. (b) Windows and macOS from v1.

**Trade-off.** The environment is Windows and the corpus assumes it. The platform work is real but
bounded: notarisation and stapling, file-dialog and menu differences, keyboard idiom (`Cmd` vs
`Ctrl` across ~40 bindings), font availability, and a second print test matrix — call it **3–5
weeks plus ongoing CI**. Against that, a visible slice of high-end residential AV design work
happens on Macs, and a tool that cannot open there is simply invisible to those people.

**What tips it.** Ask the five integrators what is on their design desk. A five-minute question
with a decisive answer, and it should be asked **before M7**, not after.

**Recommendation (not a ruling).** **(a) Windows only for v1**, with the discipline that nothing
in M0–M6 takes a Windows-only dependency without it being written down as a macOS debt item. Add
macOS as the first post-v1 milestone if the desk survey warrants it.

## 10.11 What the beta gate actually is

**Options.** (a) M9's stated criterion — three integrators each produce a sheet set they were
willing to send out, without leaving the app. (b) A metric: N projects, N cables, zero P1 bugs for
N weeks. (c) A date.

**Trade-off.** (a) is a judgement and therefore gameable and unschedulable — which is exactly the
objection to it, and it is still the right one, because every metric available at this stage
measures the tool's internal consistency rather than its usefulness. (c) ships something on a day
regardless of whether it works. (b) is the compromise and tends to measure whichever thing was
easiest to count.

**What tips it.** Whether there is external pressure — an investor, a launch date, a paying
customer waiting. If there is, (b) or (c) is going to happen whether or not it is chosen.

**Recommendation (not a ruling).** **(a), with (b) as a floor** — the judgement gate governs, and
the metric exists only to prevent shipping something that passes the judgement gate for three
friendly users and falls over on the fourth.

## 10.12 Small calls that need an owner, not an essay

Each needs a human answer before the milestone that touches it. Recommendations only.

| # | Question | Recommendation | Needed by |
|---|---|---|---|
| a | Undo depth — the cap is 200 with a status-bar signal (AC-058 D5). Is 200 right? | Keep 200; make it a setting; revisit if anyone hits it | M0 |
| b | Autosave interval, and whether recovery is silent or prompted | 30 s, **prompt** on recovery — a silent restore of a file the user thought they had abandoned is its own data-loss event | M1 |
| c | Default rack height in the new-rack dialog | 42U; it is the modal answer, and wrong-but-adjustable beats blank | M1 |
| d | Are the four starter projects residential-only? | Three residential, one small commercial — they double as the domain-coverage argument for §10.2 | M1 |
| e | Telemetry at all, and if so opt-in or opt-out | Opt-in, local-first crash reports only (CR-096), no usage telemetry in v1 — and accept that this makes §10.4's miss-rate a manual user-interview exercise rather than a dashboard | M8 |
| f | Product name and branding investment | Defer; RJ-017 already rejects branding as a v1 requirement | M8 |
| g | Is [docs/rules.md](rules.md) user-visible documentation or internal? | **User-visible, in-app, linked from every finding** — it is the honesty surface for the 22 rules | M5 |

## 10.13 The three to answer first

If only three of the above get attention before M1 starts:

1. **§10.1 — draw every wire, or net labels.** It sizes M2, decides §10.7, and it is the only one
   whose answer changes the product's identity.
2. **§10.2 — residential or commercial primary.** The rulings already bet on residential in a
   dozen defaults; confirming or reversing that bet now is cheap, and reversing it later is not.
3. **§10.4 — is the device builder in v1.** Worth 4–7 weeks, it deviates from a confirmed decision
   either way, and M1 can be instrumented to answer it for free.

Everything else can wait until there is evidence — which is the entire point of shipping M1 as a
real release rather than as a foundation.
