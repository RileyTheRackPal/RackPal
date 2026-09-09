# Roadmap

This document is the binding answer to "what ships when". It reproduces the scope ruling of canon §7 (what is in v1, v1.1, v1.2, v2, and what is ruled out permanently) and the milestone plan of canon §9 (M0–M9, each with a goal, a work checklist, a binary exit criterion, a size, and its risks), adds the dependency graph between milestones, a risk register, and the walking-skeleton argument for build order. It states a cost (42–65 weeks of implementation, 11–17 months to a shipped v1) because per AC-017 a detailed design set with no cost attached reliably stalls at 40%, and a *wrong* cost stalls it at 40% while also destroying trust in the plan. Nothing here may be re-litigated without an amendment to [the canonical decision record](canonical-decisions.md).

---

## 1. The v1 line

> **v1 is a single-window Windows desktop application in which a professional integrator builds one or more racks from a seeded catalog of generic archetypes, wires them on a schematic canvas with drag-to-connect, watches a cable schedule fill in live in a top-level tab that is present and populating from an empty project, and exports a fully drafted PDF sheet set containing a cover and drawing index, front and rear elevations, N interconnect sheets, a pull sheet, a termination schedule, an equipment list, a legend, and an exceptions page — with a device builder for the long tail, a Structure device for the wiring entering the rack, and twenty-eight validation rules that never block a deliverable.**

If a feature is not required by that sentence, it is not in v1 (canon §7.1).

**Residential CI is the primary market; commercial capability ships and never fronts the UI (DR-002).** Every "default off for wall racks", every `simple` sheet-numbering default and every deferred TIA-570-D grade is that bet made explicit rather than made by accident.

### 1.1 The four filters that produced the split

Applied in order; a feature must pass all four to be in v1.

| # | Filter | Effect |
|---|---|---|
| 1 | **Requirement filter** | Does one of the seven brief requirements fail without it? If yes it is in v1 regardless of cost. This is why the schematic canvas survives (RJ-001, RJ-002), the device builder survives, the Structure device survives, and the PDF must carry both diagram and schedule. |
| 2 | **G5: cheap now, ruinous later** | Does omitting it cost a format migration, a command-stack rewrite, or a reconstruct-and-confirm pass over user data? If yes the **model** ships in v1 even when the **UI** does not. This produces the "model ships, gesture defers" pattern that appears eleven times below. |
| 3 | **G1: does it serve the schedule?** | Does it make the schedule more correct, or get the user to the schedule faster? Features failing this and passing nothing else are cut. |
| 4 | **G4: honesty** | Does it fabricate a number or give a heuristic authority it has not earned? If yes it is cut or demoted regardless of cost. The failure mode is not a missing feature; it is a user who stops trusting every number in the product. |

Two things this ruling deliberately does **not** do. It does not adopt `critique-feasibility.md #5`'s cut table (RJ-008) or `critique-ux-simplicity.md`'s "what v1 actually is" (RJ-001 through RJ-007): both cut things the brief fixed, so their diagnosis is accepted in full and their remedies overshoot. And it does not treat "cut" as "deleted", every item below has a named home, because "later" is where scope goes to rot.

---

## 2. The scope ruling

### 2.1 v1: in scope

Grouped by subsystem; the **Why** column names the governing ruling. See [Data model](02-data-model.md) and [Architecture](03-architecture.md) for the referenced entities.

**Core, format, infrastructure: all of it, no exceptions.**

| Item | Why |
|---|---|
| `Len` = int64 nanometres, `Mass` = int64 micrograms, `Permille`, one `UnitFormatter`; `Money` deleted | CR-001, CR-003, AC-001 |
| `Pt{int gx, int gy}` in 2.5 mm grid units, no sub-grid | CR-004 |
| 1 diagram unit = 1 PDF point at the canvas boundary, `double`, converted in exactly one function | CR-007 |
| UUIDv7 identity, tombstones, `EntityMeta`, flat maps, `FracIndex` ordering everywhere including `.rmdx` | CR-027, CR-095, G5 |
| `revision` (dirty-tracking, non-monotonic) **and** `sequence` (monotonic sync cursor) as two counters | CR-094, AC-004 |
| Plain pretty JSON `.rmpj`, single file, `schemaVersion`, hand-written codecs, migration chain + golden corpus | Confirmed decision 3 |
| `unknown` passthrough on the `Placement` union and on `Outlet`, matching `Port`/`SheetItem`/`EntityMeta` | DR-019 §11.18.2(5). Lands in M3, days not weeks. Without it a build that predates a later field **silently drops it on save**, which under DR-006's shared-file reality is an ordinary Tuesday. Protects every future placement field, not only the Plan view's pin |
| Unconnected ports **not materialised** as entities; key-join from the template snapshot | AC-006; this is what makes the file-size budget real rather than 3–6× wrong |
| `Command` / `Transaction` / `UndoStack` / `DocumentController` as the single mutation gate | AC-014. The most expensive retrofit in the project |
| Epoch counters; three-tier derived pipeline; `lodLevel` in every scene-builder signature and cache key | AC-016 (#13) |
| `DiagramCanvas` display-list IR, `TextMetrics`, explicit `TextAnchor`, both backends, baseline-y parity test | CR-087, AC-007 |
| `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` built first; nothing branches on `PointerDeviceKind` | AC-016 (#23) |
| Atomic save, autosave, crash recovery, close interception, recents | Architecture §7 |
| i18n plumbing with one locale; import hardening (JSON depth/size limits on every import path) | AC-058 (D12, D8) |

**The rack**: racks 1–60 RU with per-rack `ruNumbering` and `mirrorRearElevation` (CR-038, CR-026, CR-035); 1-based bottom-origin `ruIndex` (CR-025); the sealed `Placement` union (rail, shelf, zero-U, off-rack, staged) with `chassisRotation`, `locked` and lateral twelfths (CR-031, CR-030, AC-023); front/rear elevation editing with quick-add by typing, drop caret and marquee; the Staging Bin (CR-032); shelves as auto-packing containers (CR-029, AC-043); 0U occupants from the inspector (AC-044); Compact Down/Up with preview-then-accept (AC-045); depth occupancy as an interval per (RU, face) (AC-022); the always-visible chip strip of RU, weight, VA, outlets with everything else in a collapsed advisory panel (AC-039).

**Wiring**: `Link` → `Service` → `Conductor` plus stored `Net` (CR-008, CR-010, CR-011); the word `Connection` banned from code, format and prose (CR-008); the `Endpoint` sealed union with `PortEndpoint` / `PlaceEndpoint` / `OpenEndpoint` and `LifecycleStatus.designIntent` (AC-018, the most consequential single finding in the four critiques); `Link.class` auto-classification (AC-026); three length fields (AC-024) **plus `spliceCount: int?` and the as-built tally surface that makes them reachable** (DR-020); `Pathway` as first-class (CR-016, AC-027); `InlineAdapter` (CR-015); **net labels by default with drawn wires on domain filter, `Alt`-hover or focus** (DR-001); Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal trace, with interval-graph channel routing deferred to v1.2 (CR-013 as amended); no route geometry persisted (CR-012); drag-to-connect with magnetic snap, chain-draw, multi-draw and one `Tidy sheet` (RJ-001); **one** schematic sheet with the `Sheet` entity present in the format (CR-073, AC-037); **the Schedule is a top-level tab, present and populating live from an empty project** (`Ctrl+4`, CR-105, AC-035); hue = domain, dash + weight + tag = type (AC-054).

**Structure and the field**: `Outlet` as the creation atom (CR-016); `StructureDrop` deleted, a home run is a `Link` with `structureOrigin` (AC-019, CR-107); dual labels, both always printing on every cable (CR-044, AC-025, AC-047); the Structure editor opening in **table mode** with the matrix as a tab (AC-048); outlet templates with TIA-570-D presets (CR-108); the project-level Locations panel (CR-047, CR-112); multiple Structure instances (CR-113); CSV import with synonym mapping (RJ-004); 18 field-device templates (AC-031).

**Device builder and catalog**: three required fields, then ports, then done (AC-049, CR-114); **a device glyph from a built-in 17-mark set, defaulting from category and drawn as geometry rather than as a codepoint, so `accentColor` is never the only appearance channel (DR-059, CR-078's "hue is never used alone" applied to the elevation), **and the accent itself reaching that elevation as the device body fill, with the four label colours computed from its luminance and the fill sequenced after the marks so two devices never differ by hue alone (DR-080)**; the port grid in full, fill-down, TSV paste, multi-row edit, archetype generators, the pattern DSL (the grid was never the barrier); banks vs `PortSetDef` (CR-055); `PortDef.key` + `renamedFrom` as the migration join (CR-051); the three doors (CR-054); typed overrides (CR-053, AC-012); copy-on-place with a passive stale-template badge (AC-041); `contentHash` as a warning, never a load failure (AC-042); single `.rmdx` export/import; full catalog at **full fidelity with cited provenance** (RJ-007, AC-052); the connector footprint table complete for every shipped connector with a CI assertion (AC-050).

**Validation**: rules as **Dart functions** in a registry (CR-024, AC-011); **`MediaTypeDef.maxRunLengthPassive` feeding the generic `LEN-002`** (DR-020, canon §11.19.7: the field is not new and M3-C/6 already seeded it); **28 rules** listed once in [the rule catalogue](02-data-model.md#5-the-v1-validation-rule-catalogue--three-tiers) (AC-040 and §12.6(b), both as amended by DR-020); `error | warning | advisory | off` with `RuleOverride` (CR-018, CR-019); one dismissal mechanism, `AckedFinding`, and **errors are acknowledgeable** (CR-019, RJ-006); only `TOP-001..005` and placement coherence are model-illegal (CR-017); nothing blocks export (CR-022); the DRC fixture corpus (AC-051). **AMENDED BY DR-127 §11.126** with the M5-H2 review's five unpriced consequences, none of which adds a rule: the remedy prompt generalises to `SIG-002`, `CON-001` and `PWR-003` (`#837`); `ELE-006` gains a tap selector and CV-to-Low-Z switching (`#838`); `PLC-001` learns a cabinet head end, the COMMON residential case (`#839`); `CODE-002` surfaces as more than a panel row (`#840`); and `p()`'s parameters are censused against `PortDef`'s fields (`#841`), after three fields in one milestone were found unwritable by construction. **The catalogue stays at 28** (CR-021, AC-040).

**Export**: twelve sheet slots, nine `ON` and three `AUTO`: `T0.00` Cover & Drawing Index, `T0.01` Symbol Legend, `T0.02` Exceptions & Acknowledgements, `T2.01` Rack Elevation, Front and `T2.02` Rack Elevation, Rear (one of each per `Rack`), **`T6.01…` Interconnect: N sheets, one per domain partition of the single schematic `Sheet`** (CR-073), `T6.10` Pull Sheet, `T6.11` Termination Schedule, `T6.20` Unused Home Runs (AUTO, iff ≥ 1 exists), `T6.30` Equipment List and Materials, **`T6.50` Network/IP Schedule (AUTO, iff ≥ 1 device carries a network value, DR-048)**, and `T5.01` Plate, Panel & Pinout Details (AUTO, iff a non-standard pinout exists) (CR-022, AC-025, AC-055); **full drafting furniture (drawing border, zone band and grid, title block, revision block, revision clouds and the issued-for-construction stamp) because the sheet set is a client deliverable (DR-005)**; the integrator's **logo** in the title block beside the text block, at full opacity and never instead of it (DR-030, reversing RJ-017's last clause); footage rollup by media with waste factor (AC-024); **no pricing** (AC-055); `sheetNumbering` defaulting to `simple` (CR-066); dry-run sheet count with a 40-sheet warning and 2000 hard cap (AC-050); the print test matrix on real hardware (AC-058 D13); deuteranopia/protanopia simulation plus a real greyscale laser print as named acceptance criteria (AC-054). Detail in [PDF export](08-pdf-export.md).

**The Plan view** (DR-029, v1 as of 2026-08-09, **finished before M6**): a floorplan underlay imported as raster **or PDF**, field devices pinned on it, **a plan-derived lower bound** on run length, and a plan sheet in the set. The container is DR-019's JSON-or-zip by sniff, so nothing migrates and every existing file stays readable. It **does not displace M3** and is a better front end for what M3 builds (DR-018 §11.17.2(4)); it **yields a measured horizontal distance and never a route** (DR-020), so a plan-derived length is an estimate under AC-024 unless a human marks it measured; and it **does not reach the tablet workflow**, which stays read-only in v1 (AC-056) and editable in v2. It is sequenced before M6 because M6's criterion is that all four starters export a **complete** set, and a plan sheet arriving afterwards would make that criterion run twice. Adding it puts a `drawImage` op on `DiagramCanvas` (RJ-017 as amended by DR-029) and an entry in [the macOS debt register](13-macos-debt-register.md) for the PDF rasteriser. Design: [Plan view](15-plan-view.md). Feasibility and cost: `docs/research/feasibility-plan-view.md`.

**A signal-family editor, clone-only** (DR-122, amendment of 2026-09-05): a family may be **cloned from a shipped one** and never authored from blank, which is how RJ-012's objection is satisfied rather than overruled. It refused a signal-family editor because *"a hand-rolled one produces silently wrong validation"*, and that is true: a family drives `defaultDirection`, `defaultTopology`, `defaultConnector` and `acceptedFamilies`, which `TOP-003`, `DIR-001`, `SIG-002` and `CON-001` all read, so a wrong topology yields **confident wrong validation** rather than a gap. A clone inherits every field a rule reads; the author renames it, sets a `shortTag` and picks a dash and weight. `ctl.vantage` (DR-120) would have been *clone Cresnet, rename, change the connector*. **PAL-1 moves from CI into the app for this case**, because a user-created family does not exist when CI runs: the editor runs PAL-1's arithmetic live and refuses a colliding dash and weight, which requires those rules to live in `rackpal_core` and not only in `tools/pal1_check.py`. **CR-078 is untouched structurally**, since a clone inherits its parent's domain and colour lives on the domain, so no clone can introduce a hue. The family is written into the project **and** onto the user's shelf, the project copy being authoritative for the drawing (AC-041, DR-103). **Still refused**: a connector-type editor, a colour-scheme editor and user-authored rules (RJ-012, AC-011). Canon §11.121, §12.30.

**An authored device reaches the shelf** (DR-123, amendment of 2026-09-05): the builder's `Save` writes the device into the project **and** onto the user's library shelf, so requirement 2's *"author the long tail once and use it everywhere"* holds for devices a person CREATES and not only for devices that arrive by import. **Most of the surrounding request already shipped in M4-N** and the ruling records that census rather than re-specifying it: per-device selection on export and a palette listing every shelf library with source chips are both built. **The project copy stays authoritative for the drawing** (AC-041, DR-103): a document never resolves a device out of a shelf, because that is the live library reference docs/02 refuses and prices as drawings that change silently across machines. **The shelf write is not a `Command`** and does not enter the `UndoStack`, since AC-014's single mutation gate is scoped to the document and the shelf is shared across projects; an undo that quietly removed an asset from a personal library is the more damaging surprise. **A shelf failure is a notice, never a refusal**, and the project save completes first. Only authored devices are shelved, the 50 seeded templates ship with the app. Canon §11.122.

**Project history** (DR-039, amendment of 2026-08-11): an **in-file journal** of saves, bulk acts and issued revisions, each with actor, generated summary and optional comment, finishing CR-095's tombstones on the way; an **operation panel** over the existing `UndoStack` that undoes to a point and does not pretend to be a parametric timeline; **promote-not-overwrite snapshots** in application support, retention user-set; and a **document diff** between any two snapshots, computed over the codec's key-sorted output so it is total. The ZIP container is NOT in this line and needs its own ruling (canon §11.38).

**Tabular exports** (DR-049, amendment of 2026-08-12): a **CSV/TSV writer** with `import(export(doc))` asserted as a real property rather than a phrase, discharging board #653, whose reader stack already ships from M3-F and only ever lacked a writer; a **label export** of the dual labels, both ends, as a **separate export action and NOT a slot in the sheet set**, because DR-005 makes the set a client deliverable and a page of adhesive labels is a shop artifact; and `SheetSize.usLetterPortrait`, the same enum `D14` already owes A4/A3 on (#453), since the two values today are ANSI B portrait and ANSI A landscape and neither is Letter. **No printer drivers**: Brother, Dymo and Epson each speak a different dialect, an export nobody has run on the hardware is `VACUOUS` under docs/12 §0, and this project already carries two unexecuted print matrices. **No D-Tools or XTEN-AV exporter, ever**: it cannot be demonstrated without a licensed seat, and docs/00 §4.2 positions this product explicitly not against D-Tools. Canon §11.48.

**Plan-derived run length** (DR-050, amendment of 2026-08-12): plan geometry **fills the room estimate that already exists**, `Location.estimatedRunLengthFromRack`, which is already writable and already sums into the footage rollup; **no new `ScheduleLengthSource` tier**, because the user's ground is that wire is a consumable quoted with margin and a provenance distinction nobody acts on reads as significant to the next person. A computed value is **marked as computed**, which is DR-046's lesson honoured: the difference is that a termination is a discrete part where a wrong value orders the wrong object, and a length is a continuous estimate consumed with a margin. **DR-020 is not weakened**: `planLowerBound` still never sums, the route is still discovered rather than designed, and a per-drop figure derived from a drawn path is still forbidden. A room's dimensions are not a route. Canon §11.49.

**Device documentation** (DR-051, amendment of 2026-08-12): `TemplateBody` carries a reference block, **URL, title, revision and a retrieved-on date**, and never a file. The date is DR-048's `verifiedOn` mechanism reused, because G4 handles unknown and has no mechanism for stale and a link rots silently. Embedding is **refused permanently** and not deferred (§12.21): the `pdf` package cannot import pages, DR-015 §11.15.4's container argument applies unchanged and would add parsing untrusted PDFs, a forty-device house would carry a payload one to two orders of magnitude larger than the drawing, and manufacturer manuals are **copyrighted**, which no release date and no amount of work changes. Canon §11.50.

**Divergence detection** (DR-052, amendment of 2026-08-12): detect that a `.rmpj` changed underneath an open session, **warn before overwriting, and offer a side-by-side rather than a merge**. It works on any file sync a user already pays for, needs no authentication and does not touch the format. **RackPal performs no merge, in any release**: byte-exact key-sorted output makes a diff legible and does not make a three-way merge safe, since two people each adding a device merge textually and may produce duplicate designators or colliding `FracIndex` orders. Canon §11.51.

**Network addressing** (DR-048, amendment of 2026-08-12): `DeviceInstance` gains `network: NetworkConfig?` for the device's management address, beside the as-built identity block it already carries; `NetworkConfig` gains `verifiedOn: DateTime?`, because G4 handles *unknown* and has no mechanism for *stale*, and an undated value renders as unverified rather than as fact; toggleable columns in the table with `Ctrl+D` fill-down and the batch bar, plus a read-only summary in the device inspector; the address opens a browser behind a confirmation showing the URL; and the `T6.50` sheet above. `Port.network` is unchanged and keeps the per-port facts (VLAN, `portRole`, a second address). **The field has been in the format since M0 with no writer anywhere, not even a test fixture**, so most of this is reachability rather than modelling. It is bounded to devices this product models that carry a fixed address, and is **not** a DHCP inventory and discovers nothing. Canon §11.47, §12.20.

**Platform and quality**: mobile/tablet **read-only** on exactly three surfaces, with the app saying so rather than shipping a squeezed editor (AC-056); the outline tree; a fully specified keyboard path to create a connection, WCAG AA, NVDA/VoiceOver matrix (AC-058 D11); ~40 keybindings from one `Intent` registry with the 16 collisions fixed (CR-101, AC-046); the in-app glossary and one error-message catalogue (AC-058 D1); eight empty states and the full file-layer error surface (D3, D4); progress and cancel on every operation over ~500 ms (D14); four starter projects doing triple duty as goldens, perf fixtures and screenshot source (AC-052); Windows code signing started **two milestones early** (AC-058 D10).

### 2.2 v1.1: the fast follow

Membership criterion is **additive**: no format migration, no command-stack change, no re-derivation of user data. Not effort.

| Item | Deferred by | What it costs to wait |
|---|---|---|
| 0U gutter **interactions**: 16 px gutters, rotated bars, drag-into-gutter, resize handles, the `G` toggle, channel-overlap warnings | AC-044 | Inspector-only editing of a real occupant; not lossy |
| Free lateral positioning on shelves, `Alt`-drag, third focus level, per-host overhang warnings | AC-043 | Auto-pack covers the common case |
| Free lateral dragging of half-rack devices | CR-030 | The dropdown covers all three real positions |
| Hand-authoring an arbitrary conductor map | AC-053 | `atomicConnect` covers component video, stereo pairs, 16/4 |
| The **interactive** Rear Panel view: `Ctrl+3`, leaders, tag pills, per-connector navigation, egress heat map | CR-071 | The rear elevation still **prints** in v1 as sheet `T2.02`; the termination schedule carries the same information in table form |
| `Trace` through pass-throughs, and the search DSL | AC-040 | Both are navigation, not correctness |
| Manual reroute stored as `routeConstraintsBySheet`, ordered grid points, never a polyline | CR-012 | The router is deterministic; the itch is aesthetic |
| Registry editor beyond media types and connector aliases | AC-050 | The two extensibility paths users actually hit already ship |
| **Submitting a device to the community catalog**: the Device Builder's review sheet, GitHub sign-in by authorization code with PKCE, the fork-branch-commit-pull-request sequence, the port-photograph citation | **DR-033**, §8.3 addition. **Unblocked**: canon §11.32.7's precondition is discharged by DR-036 | `.rmdx` still exports and imports, so a device is still shareable as a file. **`TemplateBody.submittedBy` does not wait**: it ships in v1 because the template body has no `unknown` passthrough and a v1 build would drop the credit on save |
| **Installing and updating the community library**: the bundled snapshot, the first-run opt-in card, the `.rmda` release-asset fetch, the once-daily `releases/latest` check behind a non-modal notice | **DR-034**, §8.3 addition, sharing DR-033's discharged precondition | Nothing until submission ships; an empty library has nothing to distribute. **The two libraries' separation is not deferrable**: it is a determinism gate, since a golden resolving a template out of a fetched library depends on a release tag (canon §11.33.5) |

### 2.3 v1.2: the second release

Each needs a format addition, a fixture corpus, or evidence from real projects. All are pre-committed in the sense that the model already accommodates them (G5); none is promised on a date.

| Item | Gate |
|---|---|
| Interval-graph channel routing for `drawn` mode, track ordering inside a channel, replacing the deterministic layer-ordered trace | DR-001, CR-013 as amended; ships if real sheets show the simple trace producing unreadable overlap under a domain filter |
| The remaining ~39 DRC rules: `BUS-*`, `ELE-004/005/008`, impedance, DMX universes, DALI counts, Cresnet voltage drop, RF cascade, satellite DC-pass, fibre polarity | AC-040, AC-051. **Each ships only with its fixture pair.** That is the whole gate. **The `LEN` family left this row at DR-020**: `LEN-002` is generic over `MediaTypeDef.maxRunLengthPassive`, so per-medium length limits are registry rows in v1 rather than rules deferred to here |
| The template **Update Manager**: opt-in migration, safe/additive/breaking grouping, per-cable `[Remap]` / `[Keep as orphan]` | AC-041. `[Del]` never ships (CR-052) |
| Auto-arrange with trade heuristics; fill gaps with blanks/vents gated on `Rack.formFactor` | AC-045, AC-034 (m20) |
| Buses as graphical grouping with 45° entries | RJ-001 |
| Sub-grid annotation nudging as `int sx, sy` in eighths of a gu, if ever needed | CR-004 |
| Bays: `Bay{id, name, order, rackIds}`, a pure addition | CR-033 |
| Full commercial grounding and bonding detail sheet | AC-034 (m21), RJ-010 |
| **Git sync of a `.rmpj` between machines and people**, authenticated by authorization code with PKCE (DR-033's no-secrets constraint) | **DR-052** §11.51.2. Ships if real projects show a handoff that a file share does not already solve. **RackPal performs no merge in any release**: byte-exact key-sorted output makes a diff legible and does not make a three-way merge safe. The v1 half, divergence detection with a side-by-side, is §2.1 and does not wait for this |

### 2.4 v2: the next product decision, not the next release

Each changes what the product *is* and should be decided with evidence from v1 users.

| Item | Note |
|---|---|
| `SignalRoute`: Dante flows, AVoIP streams, matrix crosspoints, eARC, VLAN/multicast/latency | CR-008, AC-036. Returns **with** a Dante view or not at all; a third entity layer with no editor is dead weight |
| **Layers**: Existing / Phase 1 / Phase 2 / Future / Demo | CR-064, AC-038. Real for commercial retrofit, absent from the residential first job; `DeviceStatus` covers 80% for one field |
| ~~Cloud sync and multi-user~~ | **SPLIT BY DR-052 (§12.22) and this row is gone.** It was two features wearing one name. **Sync** moved *forward*: git sync is §2.3, gated on evidence, and divergence detection is §2.1. **Simultaneous multi-user editing** moved to §2.5, never. The row's reasoning survives and is why the split was possible: a cloud-ready model is what makes sync cheap and is irrelevant to concurrent editing, which fails on determinism, CR-117 and undo rather than on identity |
| Mobile **editing** | v1 is read-only by confirmed decision; the intent layer keeps the door open |
| A read-only **web** viewer | AC-016 (#22). Distribution story, not a feature, one `kIsWeb` guard already exists |
| A priced BOM with suppliers and purchase orders | AC-055. An adjacent product, not a missing feature |
| Real-SKU catalog | A legal and maintenance question before it is a product one |

### 2.5 Not doing: rulings, not omissions

| Item | Ruling |
|---|---|
| **Multi-sheet authoring** | **DR-004: never built.** One schematic `Sheet` plus domain filtering, permanently. Match lines, off-sheet connectors, sheet-boundary link handling and schematic PDF tiling go with it. The `Sheet` **entity** ships in v1 so the format never migrates if this is ever reversed (AC-037). The exporter's domain partition is unaffected and still emits N interconnect sheets `T6.01…` (CR-073), **partition at export is not multi-sheet authoring** |
| **Unit splitting (`MTX1:A/:B/:C`)** | CR-070, DR-004. Its stated condition was "only if multi-sheet lands", which can now never happen. The 17-pin threshold is deleted with it; `kBankCollapseThreshold = 8` is the one remaining constant (CR-103) |
| **A rule-authoring UI and the JSON predicate AST** | The claim that users can author rules is withdrawn from all documents. ~20 of 70 rules are inexpressible in a boolean predicate tree, so the AST buys a second rule system, a second debugger and a second test suite for rules nobody can write without a UI that was never designed. CR-024, AC-011 |
| **A full registry authoring UI** | RJ-012 **as amended by DR-122**: a signal family may be **cloned** from a shipped one. A general registry editor, a connector-type editor and a colour-scheme editor remain a database admin tool wearing a product's clothes |
| **Multi-document tabs** | RJ-013. One window, one document; open two windows if you want two |
| **Tagged / accessible PDF (PDF/UA)** | RJ-015. The accessibility budget buys the outline tree, the keyboard connection path and the NVDA matrix instead |
| **An in-app update mechanism in v1** | RJ-014. Signed installer plus a version-check ping; auto-update is a security surface before there are users |
| **Device images** | AC-057. Resolves the container question, removes the image-decode import surface, removes ~1 MB per template |
| **Signatures and `provenance`/`derivedFrom` chains** | AC-042. `contentHash` survives; the cryptographic apparatus does not. **The library pack came back** as `.rmda` (DR-015 §11.15.3), a scope edit under §8.3, ruled and not yet built, and it needs neither of the two things still cut here |
| **Cable dressing, 3D, thermal simulation** | Out of the brief. **Floor plans left this row at DR-018** and are §2.2, conditionally. The row's rationale had only ever argued cable dressing; the other three rode along in the same cell |
| **`blockExportOnErrors`** | CR-022. Not deferred: deleted. No setting, no equivalent, no exceptions |
| **`Money`, `cost`, `supplier`, `purchaseOrder`** | AC-055 |
| **Silent estimated values** | G4, AC-039. A standing prohibition, not a scope item: unknown is null, null renders `—`, every rollup reports its unknown count |
| **Live / P2P collaboration: simultaneous editing of one document** | **DR-052 §11.51.1: never built.** Three independent grounds, any one sufficient. It deletes determinism's precondition, since *same document, same display list, same exported bytes* holds because there is one writer. It renegotiates CR-117, since a CRDT needs per-field causal metadata in the file and OT needs a server plus a rebase rule per command type, of which there are ~40. And undo has no good multi-user answer (§11.38.5). **Sync is a different feature and is not cut**: §2.3 and §2.1 |
| **Embedded manuals, spec sheets and datasheet appendices** | **DR-051 §11.50.6: never built**, and this was a v2 deferral until 2026-08-12. The `pdf` package writes documents and cannot import pages; DR-015 §11.15.4's container argument applies unchanged and would add parsing untrusted PDFs; a forty-device house would carry a payload one to two orders of magnitude larger than the drawing. **The ground that makes it never rather than later is copyright**: manufacturer manuals are not the project's to redistribute inside a file that gets emailed to clients, and no release date changes that. **What ships instead is a citation**: URL, title, revision and a retrieved-on date (§2.1) |
| **Label-printer drivers: Brother, Dymo, Epson dialects** | **DR-049 §11.48.7.** An export nobody has run on the hardware is `VACUOUS` under docs/12 §0, and this project already carries two unexecuted print matrices (`D11`, `D13`). **The label sheet and the CSV both ship** (§2.1); every label program on the market imports a CSV, and the mapping is the user's to make once |
| **A D-Tools or XTEN-AV exporter** | **DR-049 §11.48.8.** It cannot be demonstrated without a licensed seat, neither vendor publishes a stable import schema, and docs/00 §4.2 positions this product against AVSnap and Stardraw and **explicitly not against D-Tools**, so shipping one is a positioning amendment wearing a feature's clothes. The generic CSV serves the same user through an import wizard those products already ship |

### 2.6 The ten cuts that account for most of the saving

Ranked by engineering weeks removed, using `critique-feasibility.md`'s own sizing.

| # | Cut | To | Weeks saved |
|---|---|---|---|
| 1 | Multi-sheet authoring, off-sheet connectors, cross-refs, min-cut, unit splitting | **never** (DR-004) | 4–6 |
| 2 | Interval-graph channel routing, the Bentley–Ottmann crossing sweep, hop arcs, junction staggering | v1.2 / never (DR-001) | 4–5 |
| 3 | ~40 of the 62 DRC rules | v1.2 | 3–4 |
| 4 | Template Update Manager, semver classifier, diff view, merge resolution | v1.2 | 2–3 |
| 5 | Preview-diff auto-layout with variant cycling, four tidy scopes, auto-arrange heuristics | v1.2 | 2–3 |
| 6 | `SignalRoute` and layers | v2 | 2 |
| 7 | 0U interactions, shelf free-positioning, half-rack drag, manual conductor authoring | v1.1 | 1.5–2 |
| 8 | The rules-as-data interpreter | Not doing | 1.5–2 |
| 9 | Signatures, device images, priced BOM | Not doing / v2 | 1.5 |
| 10 | Buses, `Trace`, search DSL, the interactive Rear Panel view | v1.1 / v1.2 | 1.5 |

Roughly **25–31 weeks removed** from a 62–83 week bottom-up estimate, before counting the reduction inside the schematic milestone from RJ-001's accepted half. Cut 1 lists **zone grids nowhere**: the zone grid is kept by CR-073, the schedule's `REF` column depends on it, and DR-005 confirms it as a v1 deliverable (canon §12.6(d)). Cut 2 is DR-001's, and it is the reason M2 is now `M`.

---

## 3. The walking skeleton: what to build first, and why

The build order is not "easiest first" and it is not "most visible first". It front-loads the four things that are cheap to get right now and ruinous to retrofit, and it makes each of them prove itself against a running program before anything sits on top of it. Three sequencing rules survive verbatim from `design-architecture.md §13`:

1. **The viewport comes first**, because everything sits on it and it is cheapest to iterate on when nothing else exists.
2. **The command stack comes before the feature surface grows.** Retrofitting a mutation gate across forty entity types and six editors is the single most expensive rewrite available in this project.
3. **The display-list IR comes before the PDF backend**, which makes the PDF backend nearly free. Screen/print parity is tractable only in that order; the reverse order means every layout hour may need redoing.

The skeleton, the thinnest end-to-end path that touches every hard subsystem, is therefore:

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

Everything after that point is feature surface on a proven spine. Everything before it is a bet that, if lost, is lost cheaply. The rejected alternative, build the rack editor first because it is the demo, loses because it puts three of the four hard bets behind six weeks of UI that would then be rewritten. The parity test is a genuine stop-the-line gate, not a checkbox: `design-pdf-export.md` is right that every hour spent on layout before parity holds is an hour that may need redoing.

Two further sequencing constraints are binding, from AC-059:

- **M0 is not compressible into M1.** Six decisions, the unit base (CR-001), the wiring entity model (CR-008), the validation philosophy (CR-017), the template join key (CR-051), the package layout (CR-083), the text-metric source of truth (CR-081), each cost a rewrite of everything downstream if guessed wrong.
- **The rules-as-code decision (CR-024) must be settled before the wiring milestone**, not during it. It justifies several registry decisions, and deciding it late means either building an interpreter nobody needs or refactoring a shipped file format. It is settled in the canon, which is why M2 can start on schedule.

---

## 4. Milestone plan

**How to read it.** `S` ≈ 2–3 weeks, `M` ≈ 4–7 weeks, `L` ≈ 8–12 weeks, for one experienced engineer, implementation only, excluding design iteration, the bug tail, and anything in the open questions that changes an answer. **Exit criteria are binary and demonstrable**; "works well" is not an exit criterion, and each one below can be checked by running something. **Every milestone ends green**: CI passes, goldens pass, the app opens the four starter projects. A milestone that ends with a known-broken build has not ended.

**Which milestone meets which brief requirement.** "Requirement N is met" appears as an exit criterion only for R6 and R7 below; this table is the rest of the map, so no reader has to infer it.

| Requirement | Met at | Note |
|---|---|---|
| R1 rack height in RU | M1 | |
| R2 GUI device builder | M4 | catalog half at M1; the builder is the requirement (DR-003) |
| R3 physical connections | M2 | |
| R4 colour-coded by type | M2 | legend verified on hardware at M6 |
| R5 schematic idiom | M2 | net labels by default (DR-001) |
| R6 Structure device | M3 | |
| R7 PDF, diagram + schedule | M6 | |

### M0: Foundations · S

**Goal.** The pure-Dart core and the repo it lives in. No UI beyond a window that opens.

- [ ] Monorepo with five packages (CR-083) plus the mechanical dependency-rule enforcement test
- [ ] `rackpal_core/units/`, `Len`, `Mass`, `Permille`, `Pt`, `Box`, `UnitFormatter`, `kBtuPerWattHour`
- [ ] The full entity set as immutable Dart with `@internal` setters (AC-013)
- [ ] Hand-written JSON codecs both ways, `schemaVersion`, migration harness, tombstones, `EntityMeta`, `FracIndex`, `revision`/`sequence`
- [ ] `Command` / `Transaction` / `UndoStack` / `DocumentController`; epoch counters
- [ ] The `idformat` grammar, registry and parser (CR-045)
- [ ] CI: analyze, test, goldens, format, the no-Flutter-import test, the epoch-mask coverage test

**Exit criterion.** `dart test` green in `rackpal_core` with: the 1/32-inch clearance test and the 45U-accumulation test passing exactly (CR-001); `write(read(bytes)) == bytes` on three fixtures (CR-117, AC-016 #24); the command round-trip property test (`apply; revert` leaves the JSON byte-identical, including `templates.keys`, AC-015) passing on 1,000 generated command sequences; the epoch-mask coverage test passing for every command type; one v0→v1 migration fixture in the golden corpus. `rackpal_core` has zero Flutter imports, enforced by a test that fails the build.

**Risks.** Byte round-trip is much harder than semantic round-trip, it constrains key ordering of nested `unknown` maps, timestamp precision and integer formatting. Budget for that, or the plain-JSON git-diffability justification is not actually being tested.

### M1: The elevation release · L

**Goal.** The smallest genuinely useful release, **and it ships to real users.**

- [ ] `ViewportController` with wheel/trackpad/pan/zoom and the grid painter, built first
- [ ] `CanvasIntent` on top of it, with no `PointerDeviceKind` branching anywhere above (AC-016 #23)
- [ ] Hybrid `RenderRackCanvas`, device widgets, RU snapping, front/rear elevations with per-rack mirroring
- [ ] Quick-add by typing with the drop caret; the Staging Bin; shelves with auto-pack; 0U occupants from the inspector
- [ ] Compact Up/Down with preview-then-accept, and the shrink-rack dialog; locks
- [ ] The full seeded catalog including the 18 field devices, with `sources.md` provenance and the connector-footprint CI assertion, see [Seed devices](catalog/seed-devices.md)
- [ ] Copy-on-place with `DeviceOverrides`; the chip strip (RU, weight, VA, outlets) with unknown counts
- [ ] `DiagramCanvas` + `SceneBuilder` + both backends + the baseline-y parity test
- [ ] Minimal PDF exporter: front elevation, rear elevation, `T6.30`, title block, revision block
- [ ] Atomic save, autosave, recovery, recents, close interception; the outline tree; four starter projects

**Exit criterion.** A user opens the app, creates a 42U rack, populates it with 20 devices in under four minutes **using only the keyboard**, and exports a three-sheet PDF whose elevations are dimensionally correct against a physical tape measure at true scale and whose equipment list matches the rack contents exactly. The baseline-y parity test passes within 0.5% on a kerning-heavy string. Undo restores every operation in that sequence.

**Why it is useful standalone.** Integrators produce rack elevations today in Visio, in Excel with merged cells, in D-Tools if they have paid for it, and in PowerPoint if they have not. An RU-accurate, dimensioned, printable front-and-rear elevation with an equipment list is a **billable client deliverable in its own right**: it goes into proposals, to the GC for closet sizing and power requests, to the millworker for the credenza cut-out, and it is what gets marked up in the field. Roughly half the observed use of a rack tool never touches wiring at all. M1 satisfies brief requirement 1 completely and the **catalog half** of requirement 2; the builder half, which is what requirement 2 actually asks for, lands at M4 (DR-003). It also puts the two most retrofit-expensive subsystems into production against real files before a single wire exists, which is why it is `L` and not `M`, and why it is now the only `L` milestone in the plan.

**What M1 deliberately lacks.** No wiring, no schedule, no schematic, no Structure, no device builder, no DRC. The app says so: an empty Schedule tab that explains it is coming is a lie, so the tab does not exist yet.

**Risks.** Scope creep from [Rack editor](04-rack-editor.md), the elevation spec is the densest interaction document in the set and its v1.1 items (0U gestures, shelf free-positioning) are seductive. The catalog provenance gate (AC-052) is the other risk: uncited safety-adjacent fields do not ship, so template authoring is slower than the "2 weeks" line item suggests.

### M2: Wiring and the live schedule · M

**Goal.** Requirements 3, 4 and 5. The schedule becomes a thing the user watches fill up rather than discovers at export.

**M2 was `L`.** DR-001 removes interval-graph channel routing, the crossing sweep, hop arcs and junction staggering, 4–5 weeks and the three hardest correctness problems in the corpus (canon §11.1.5). **M1 is now the only `L` milestone and the sole long pole.**

- [ ] `Link` / `Service` / `Conductor` / `Net` with the `Endpoint` sealed union and `Link.class` auto-classification
- [ ] The schematic canvas: symbols with banks, vector-pin collapse, Sugiyama phases 0–3 (cycle-break, layer, barycentre, coordinate assign) placing the symbols, a deterministic layer-ordered orthogonal trace drawing the wires in `drawn` mode, full deterministic recompute
- [ ] Drag-to-connect with magnetic type-weighted snap, chain-draw, multi-draw, pinning on manual move, one `Tidy sheet`
- [ ] **Net-label rendering as the default**; the domain filter bar as the primary way to see wires; `Alt`-hover and focus for transient `drawn` mode
- [ ] Hue-by-domain plus dash/weight/tag by type, with the per-family colour override setting
- [ ] `atomicConnect` multi-conductor gesture
- [ ] **The Schedule as a top-level tab** (`Ctrl+4`), present and populating live from an empty project, with Pull Sheet and Termination Schedule as two views of one derivation
- [ ] Wiring signposted from the elevation (CR-105); the coach mark at the first rack→schematic switch (CR-104, AC-048)

**Exit criterion.** Starting from the M1 output, a user creates 60 connections without touching a menu; the schedule tab shows 60 correctly-sorted rows with both labels on both ends and conductor colours where they exist; the schematic re-lays-out deterministically (same input ⇒ byte-identical display list) and routes a 300-connection fixture within one frame at commit, with the **label-layer commit cost measured and recorded** on that fixture rather than assumed (AC-016 #20). The keyboard-only path to create a connection works end-to-end with screen-reader announcements.

**Risks.** Still the highest-risk milestone, but the risk has moved. Under DR-001 the dominant commit-path term is **text**, not geometry: two net labels per `Link` puts ~300 additional text runs on a 150-connection project on top of the ~10,000 the cache must be sized for. Re-baseline to ≤ 16 ms with ≤ 8 ms for non-paint terms, key the text cache on `(text, styleId, quantisedScale)`, and keep the per-domain sub-pictures; they are what lets a domain filter switch to `drawn` mode without rebuilding seven other pictures. A 2,000-entry LRU against ~10,000 runs thrashes, and a thrashing LRU is worse than none because eviction disposes a native `ui.Paragraph` in the paint path. See [Schematic editor](05-schematic-editor.md).

### M3: Structure and the field · M

**Goal.** Requirement 6, and the finding that a pull sheet must exist before the equipment list does.

- [ ] `Outlet`, `structureOrigin`, `PlaceEndpoint` and `OpenEndpoint` in the UI, `LifecycleStatus.designIntent`
- [ ] The Structure editor in table mode with the matrix as a tab; outlet templates and TIA-570-D presets
- [ ] The project-level Locations panel with the arbitrary-depth tree
- [ ] Dual-label generation for every cable; the three length fields, `Location.estimatedRunLengthFromRack`, the footage rollup with waste factor
- [ ] **The as-built tally surface**: one table an installer tabs down to record `terminatedLength` and `spliceCount` per run, reusing the Structure editor's bulk-entry ergonomics rather than a second table (DR-020 §11.19.2(5), AC-048). `Link.spliceCount: int?`, null unknown and `0` confirmed none (G4, CR-114)
- [ ] The `unknown` passthrough on `Placement` and `Outlet` (DR-019 §11.18.2(5))
- [ ] `Pathway` with `kind` and `containsLineVoltage`; CSV import with synonym mapping and the import-over-existing confirm; multiple Structure instances

**Exit criterion.** A 60-drop whole-house rough-in is entered in under fifteen minutes, produces 60 `Link`s each with one `fieldLabel` and one `rackLabel`, and exports a Pull Sheet sorted by room and pathway with per-room footage subtotals and initial boxes. **Fourteen of those drops have unbound far ends and every one of them still schedules, prints and carries a `W` number** (AC-018). Requirement 6 is met. See [Structure device](07-structure-device.md).

**Risks.** CSV synonym mapping is an infinite-tail feature; cap it at the shipped synonym table and let unmapped columns fall through to a manual assign step.

### M4: The device builder · M

**Goal.** Requirement 2 in full, the long tail the catalog cannot cover.

- [ ] The three-required-field form, everything else optional with a visible `unknown` state
- [ ] The virtualised port grid: fill-down, TSV paste, multi-row edit, archetype generators, the pattern DSL with autocomplete and designed parse errors
- [ ] Banks and `PortSetDef`; the three doors (CR-054); typed `PortOverrides`
- [ ] `.rmdx` single-file export/import with `contentHash` as a warning-level check
- [ ] `.rmda` device archives: the codec, the library directory service, import/export, and the palette filter that makes more than one library usable (DR-015 §11.15.5, the format is ruled; none of the subsystem exists). Board #170
- [ ] The stripped field-device form; the media-type editor and connector aliases; undo throughout the builder (CR-106)

**Exit criterion.** A 16×16 matrix template is authored from scratch **in under three minutes by a user who has seen the tool once**, and a template saved with exactly three fields plus ports places into a rack and appears correctly in the equipment list with `—` in every unknown column and an accurate unknown count in the rollup. See [Device builder](06-device-builder.md).

**Risks.** The pattern DSL is the scope hazard, not the grid. Ship the documented subset with designed parse errors and resist generalising it. **§6 was re-derived at this milestone's decomposition and M4 is now `L`, 7–9 weeks**: the `M`/5–7 predated DR-015 putting the library subsystem on the checklist above. Two further items decomposition surfaced and no estimate had ever held: making `Command` generic so the builder can own an undo stack (CR-106), which touches every command in `commands/`, and authoring `ConnectorTypeDef.pitch`, without which §5's auto-layout algorithm cannot be written at all (docs/12 §5.3).

### M5: Validation · M

**Goal.** 28 rules that are right, acknowledgeable, and incapable of holding a deliverable hostage.

- [ ] The rule registry as Dart functions; catalogue metadata as data; the compat matrix as a lookup table
- [ ] All 28 rules, 8 tier-1, 6 tier-2, 14 tier-3, enumerated once in [the rule catalogue](02-data-model.md#5-the-v1-validation-rule-catalogue--three-tiers); findings, severities, `AckedFinding` at both scopes, project-wide mutes with reasons
- [ ] Spring-back with reason chips and remedy chips, each with `[ Connect anyway ]`; the `[Why?]` rationale viewer
- [ ] **The DRC fixture corpus**

**Exit criterion.** Every one of the **28** rules has a known-bad fixture producing exactly that finding and a known-good near-miss producing none, **no rule ships without its pair** (AC-051). A domain-expert review of the 28 rules and of the catalog data is signed off. No rule, at any severity, prevents a PDF from being written to disk.

**Risks.** The fixture-pair gate is what holds the catalogue at 27; the pressure to add "just one more obvious rule" without its pair is the mechanism by which this milestone overruns. Enforce the gate in CI.

### The Plan view · L · an epic, not a milestone number · finished before M6

**Goal.** Answer *where*. A schedule says `W044` runs from `RK-1 / U14 / rear` to `Great Room / TV wall / WP-1` and gives the installer everything except which wall.

**It has no milestone number on purpose** (DR-029 §11.28.4): renumbering M6→M10 would rewrite every `M6-A1`-shaped task title, docs/12 §5.3–§5.8's headers, §12.7's table and dozens of canon references. **The sequencing is a stated dependency, not a number.** It sits between M5 and M6 because M6's criterion is that all four starters export a **complete** set, and a plan sheet arriving afterwards would make that criterion run twice. It **does not displace M3** and no M3 task is cut (DR-018 §11.17.2(4)).

- [ ] `drawImage` on `DiagramCanvas` through the IR and both backends, under `draw/canvas.dart`'s own amendment clause (DR-029 §11.28.6); op-count baselines re-recorded; the underlay excluded from PAL-1 explicitly
- [ ] The zip container DR-019 ruled: `document.json` plus `underlays/<uuid>.<ext>`, entries sorted, a constant timestamp, one compression method, no extra fields, and CR-117 holding on the zip path
- [ ] `PlanUnderlay`, `PlanScale`, `PxPt` and `PlanPin` on `OffRackPlacement`, `Outlet` and `Rack`; **`Location.riseAllowance`, which DR-020 specified and nothing ever built** (DR-037 §11.36.5)
- [ ] Import: PNG and JPEG, **a PDF page LIFTED at import with a page picker** (DR-037 §11.36.2 as amended by DR-138 §11.137, which replaced rasterising with lifting the image the page already contains), the format allowlist and the byte and pixel caps every import path owes (AC-058/D8) **The importer had NO CALLER until `PLAN-E/5`** (DR-143 §11.142.1): every function was built and tested and nothing in `lib/` invoked any of it, so `AddPlanUnderlayCommand` had no producer and no project could hold a floorplan. `File ▸ Import floorplan…` is that caller (`96126c0`).
- [ ] The Plan editor as a third canvas, reusing the viewport, selection, hit-test and command machinery **and no drag preview** (`PLAN-E/1` measured it: `DragPreviewController` speaks in rack units and a pin has none of them, docs/12 §5.9.7.3); a third render object, an image resolver and a plan scene builder, which were on nobody's list; the Structure-table-then-plan fast path for a 60-drop rough-in; the unpinned strip with its count
- [x] **One marquee, built once and adopted on all three canvases** (DR-139 §11.138, discharging CR-102, which was ruled and never built anywhere); `#848`. **BUILT** at `PLAN-E/6`: the geometry is `rackpal_core/draw/marquee.dart`, the gesture and the band are `MarqueeController`, and the rack elevation, the schematic and the plan each contribute four lines. The `partKey` filter is the part that would have been wrong by default, and it is the schematic that would have shown it
- [ ] **The rack's own pin, from the unpinned strip** (DR-140 §11.139). `Rack.planPin` and `SetPlanPinCommand` shipped at PLAN-C and **no gesture in any chapter put a pin on a rack**; without it `PLN-003` fires and no length on the plan derives at all. **The gesture is built** (`PLAN-E/4`, `b484117`): `PlanCanvasScreenState.armCarrierDrag` pins any of the three carriers, and the strip is where a rack row comes from. The clause stays open on the clause's own standard, since nothing mounts the strip until `PLAN-E/5`
- [ ] **The drop-table fast path's mode** (DR-141 §11.140): one arm, one pin, and the mode stays visible with nothing armed. **`PLAN-E/4`'s strip is the primary pinning workflow** and this is the secondary entry point; its drop-table producer lands with `PLAN-E/5`, because a gate proved it unreachable before the Plan view has a home. **AND IT WAS DEAD IN THE SHIPPED APP FROM `PLAN-E/6` UNTIL `PLAN-F/0`** (`9538fa1`): the marquee arms a band on every press that misses a pin, `commitDrag` asked `isActive`, and the armed-pin branch below it was unreachable on every mounting that supplies a band, which is every mounting in the product. The canvas tests predate the band and pass null, so the suite stayed green over a dead gesture
- [ ] Two-point calibration, recalibration as an undoable document command, and **uncalibrated as a fact rather than a default** (DR-144 §11.143). **THE PICK, THE PARSER AND THE WRITER SHIP AT `PLAN-F/1`** (`f5e0f46`): `PlanScale` had neither a reader nor a writer in `lib/` and `scale` was null in every document this product could make, which is DR-143's shape one field over. A typed distance **carries its unit**, because a bare `36` is 36 inches or 36 feet and the guess is wrong by twelve on every length the plan yields. **`PLAN-F/2` BUILT THE REPORT** (`derived/plan_measurability.dart`): a count of PINS and never a `Len`, said on two surfaces because a RECALIBRATION leaves the row identical and only a message can report it. Its mask clause was discharged a chapter early, and the census behind it found that the two surfaces which must refresh do not read epochs at all while the two that do read them cannot show a calibration. The clause stays open on `PLAN-F/3`'s uncalibrated-as-a-fact half
- [ ] `planLowerBound` as a fifth `ScheduleLengthSource`, ranked **below `roomEstimate`** and out of the footage rollup as a quantity (DR-020 §11.19.2(2), DR-037 §11.36.4); `LEN-001` reads the bound whichever tier printed
- [ ] `T1.01 Device Location Plan`, `AUTO`, the twelfth sheet slot: the screened underlay **composited in the export backend so no alpha and no `/SMask` reaches the file**, callouts, a drawn scale bar, and the per-plan device schedule
- [ ] The four `PLN-*` advisories, in their own band, added to no total

**Exit criterion.** An architect's floorplan PDF is imported **without leaving the app**, calibrated from one known dimension, and the rack plus every drop of a real rough-in carries a pin. The project exports a sheet set whose `T1.01` places a callout for every pinned drop, each printing the designator its Pull Sheet row prints. **A person who has never seen the building is handed the printed `T1.01` and the printed Pull Sheet, and locates every drop without asking a question.** The set is printed on a real greyscale laser at ANSI B and every callout stays legible over the screened underlay (AC-054). `write(read(bytes)) == bytes` holds on the zip path across a write, a reopen and a second write, and a project with **no** underlay writes bytes identical to what the plain-JSON path writes today. See [Plan view](15-plan-view.md), [feasibility](research/feasibility-plan-view.md), and canon §11.28 / §11.36.

**Risks.** The plan canvas is the largest row and the feasibility study §6 names it *"the one most likely to be wrong in the optimistic direction"*: it is smaller than M1's canvas work **only because** the viewport, selection, hit-test and drag-preview machinery already exist, and if any of those turn out to be coupled to rack or schematic semantics more tightly than a read suggests, that row grows first. **`PLAN-E/1` TESTED THAT AND IT WAS RIGHT FOR THE WRONG REASON** (docs/12 §5.9.7): four of the five named pieces reuse verbatim, the fifth deletes work rather than adding it, and the row grows because the list was **incomplete** rather than because anything on it was coupled. Checking the named risks would have cleared the row. The second risk is quieter: this ships to a desk and **not** to a technician on site (AC-056, DR-029 §11.28.7), so it does not by itself replace the tablet workflow that motivated it.

### M6: The full sheet set · M

**Goal.** Requirement 7, and with it all seven brief requirements.

**M6 sits at the top of its `M` band:** DR-005 confirms full sheet furniture as a v1 deliverable and adds revision clouds (+0.5–1 week). **Sheet furniture is orthogonal to wire idiom**: the schematic's reader is technical (the GC, the electrician, the low-voltage sub, a technically-literate homeowner) and those readers read net labels. Polish the sheet fully; keep net labels. DR-005 does not reopen DR-001 (canon §11.5.1).

- [ ] `T0.00` cover and drawing index, the index generated after the sheet list resolves so it can never name a sheet that is not in the file
- [ ] `T0.01` legend printing one row per named cable type in colour and greyscale side by side
- [ ] `T0.02` exceptions and acknowledgements with every reason, author and date; **the `T6.01…` interconnect sheets, one per domain partition of the single schematic `Sheet`** (CR-073), rendering `drawn` because a domain partition *is* a domain filter
- [ ] `T6.20` Unused Home Runs, auto-on when at least one exists; `T5.01` pinout detail auto-on for non-standard pinouts; sheet numbering `simple`/`ncs`, default `simple`
- [ ] **Sheet furniture in full (DR-005): drawing border, zone band and grid, title block, revision block, revision clouds driven from `RevisionEntry` with a lettered revision triangle, and the `ISSUED FOR CONSTRUCTION` stamp**: all drawn through `DiagramCanvas`. The stamp is gated on zero open errors and **never gates bytes** (CR-022, G3)
- [ ] Dry-run sheet count with the 40-sheet warning and 2000-sheet cap; export progress, cancel and preview; `kIsWeb` isolate guard
- [ ] The print test matrix on real hardware

**Exit criterion.** All four starter projects export a complete sheet set; the legend has been verified under deuteranopia and protanopia simulation and on a real greyscale laser print (AC-054); the ANSI B laser, ANSI D plotter and photocopy reproductions have all been **physically inspected and signed off** (AC-058 D13). Requirement 7 is met.

> **The certificate sentence that used to close this criterion is DELETED — DR-006, canon §12.9.** It read *"Windows OV/EV certificate procurement starts here, two milestones before release."* **M6 has no distribution obligation of any kind.** Signing is self-signed with a timestamp, with Microsoft Trusted Signing as the named fallback adoptable at M8; no OV/EV certificate is procured at M6 or anywhere. Every other clause above is unchanged. *(Owed edit, paid 2026-08-03 — a board task had already been written against the stale sentence and had to be withdrawn.)*

**Risks.** The real M6 lead-time item is **not** a certificate; it is **recruiting M9's integrators**, which RISK-08 keeps and DR-006 only changes the population of. Start that conversation here.

### M7: Platform and access · M

**Goal.** Honour confirmed decision 1 honestly, and make the app usable by someone who does not use a mouse.

- [ ] Mobile/tablet read-only on the three named surfaces, with an explicit statement for the two unavailable ones
- [ ] WCAG AA on the primary surfaces; raised filtered-wire alpha; non-colour encoding on rack device fills; the NVDA/VoiceOver matrix
- [ ] The ~40-binding arbitrated keymap generated from the `Intent` registry, plus the generated shortcut panel
- [ ] The in-app glossary; the error-message catalogue in one voice; the eight empty states; the full file-layer error surface
- [ ] Progress and cancel on every operation over 500 ms; localisation plumbing verified end to end with a pseudo-locale

**Exit criterion.** A reviewer opens a `.rmpj` file on a tablet and reads the elevation, the schedule and the PDF; the NVDA matrix passes on the elevation, the schedule and the connection-creation path; no keybinding is bound twice in the generated table; the pseudo-locale build shows no hard-coded English in the primary surfaces.

**Risks.** Accessibility work discovered this late tends to surface structural problems in the canvas surfaces. The outline tree shipping in M1 is the mitigation; it is the only honest accessibility story a canvas app has, and it exists from the first release.

### M8: Release engineering · S

**Goal.** A thing a stranger can install.

- [ ] Signed Windows installer; vendored pdfium; symbol archival
- [ ] Crash reporting local-first, opt-in remote, with the redaction policy reconciled (CR-096)
- [ ] Licence model and EULA; `showLicensePage`; version-check ping
- [ ] Documented scale limits with the soft warning at 1.5× and the open-read-only gate at 3×

**Exit criterion.** A signed installer runs on a clean Windows 11 machine, the app cold-starts within budget, a deliberately induced crash produces a local report containing **no project content**, and the documented limits behave as documented.

> **The first clause is SPLIT, not deleted — DR-006, canon §11.6.2/§12.9.** It read *"…with no SmartScreen warning."* **No build-side property can deliver that**: SmartScreen evaluates **Mark-of-the-Web**, which is a property of how a file arrived, not of the binary. So the **build-side gate** is — signed, timestamped, a valid publisher in file properties, **and the signature still validates after the signing certificate has expired**. The **distribution-side requirement** is documented and not gated: Local Intranet UNC or Intune/GPO, and docs/14 §14.2's ZIP trap stated explicitly. The other three clauses are unchanged. *(Owed edit, paid 2026-08-03.)*

**Risks.** The purchasing decision this section used to name **no longer exists** (DR-006). The residual risk is smaller and wholly internal: the public `.cer` is not deployed to the target machine's stores. Low likelihood, minor impact; early warning is a clean test machine showing *Unknown publisher*; mitigation is a GPO.

### M9: Beta hardening · M

**Goal.** Find out whether any of this was true.

- [ ] No new features
- [ ] Five real projects from three real integrators, run end to end
- [ ] The bug tail
- [ ] Performance measured against the recorded budgets rather than the assumed ones

**Exit criterion.** Three integrators have each produced a sheet set they were willing to send to a client or a job site, and none of the three needed to leave the app to fix something. **That is the only exit criterion that matters and it is deliberately a judgement, not a metric.**

**Risks.** Recruiting three real integrators willing to run a beta on live work is a lead-time problem, not an engineering one. Start the conversation at M6.

---

## 5. Milestone dependencies

Solid arrows are hard blocks, the downstream milestone cannot start without the named artifact. Dashed arrows are soft: the work is possible but wasteful out of order.

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
        │ M2  Wiring + schedule M  │  │ M4  Device builder │   │
        │ Link/Service/Conductor   │  │                 M  │   │
        │ schematic · net labels   │  │ (independent of    │   │
        │ live table               │  │  M2 and M3)        │   │
        └───┬───────────────┬──────┘  │                    │   │
            │ Link + Endpoint│         └─────────┬──────────┘  │
            ▼                │                   │             │
 ┌────────────────────────┐  │ findings need     │             │
 │ M3  Structure + field M│  │ a wired graph     │             │
 │ Outlet · home runs     │  ▼                   │             │
 │ dual labels · pathways │ ┌──────────────────┐ │             │
 └───────────┬────────────┘ │ M5  Validation M │ │             │
             │              │ 28 rules +       │ │             │
             │              │ fixture corpus   │ │             │
             │              └────────┬─────────┘ │             │
             │                       │           │             │
             └───────────┬───────────┴───────────┘             │
                         ▼                                     │
              ┌──────────────────────────┐                     │
              │ M6  Full sheet set    M  │◄────────────────────┘
              │ 12 sheet slots, furniture│
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
Soft:         M4 may float anywhere after M1 — but it ships in v1 regardless (DR-003)
              M7 may overlap M6 wherever surfaces are already frozen
```

The two structural facts in that graph: **M4 is not on the critical path**: it hangs off M1 and blocks only itself, so it can be resequenced freely, though DR-003 rules that it cannot be dropped from v1. And **M6 is a join**: it requires the drawing (M2), the field data (M3) and the findings (M5) simultaneously, which makes it the milestone most exposed to slip anywhere upstream. A third fact is new: **M1 is now the sole `L` and the only long pole**, because DR-001 took the router out of M2.

---

## 6. The honest total

Re-costed per canon §12.7. DR-001 removes 4–5 weeks from M2; DR-005 adds 0.5–1 week to M6; **DR-015 adds 2 weeks to M4**, counted at that milestone's decomposition (#71) and not before.

| Milestone | Size | Weeks | Cumulative |
|---|---|---|---|
| M0 Foundations | `S` | 2–3 | 2–3 |
| M1 Elevation release | **`L`** | 8–12 | 10–15 |
| M2 Wiring and the live schedule | **`M`** *(was `L`)* | 4–7 | 14–22 |
| M3 Structure and the field | `M` | 4–7 | 18–29 |
| M4 Device builder | **`L`** *(was `M`)* | **7–9** *(was 5–7)* | 25–38 |
| M5 Validation | `M` | 4–6 | 29–44 |
| M6 Full sheet set | `M` | 5–7 | 34–51 |
| M7 Platform and access | `M` | 4–6 | 38–57 |
| M8 Release engineering | `S` | 2–3 | 40–60 |
| M9 Beta hardening | `M` | 4–7 | 44–67 |

**44–67 weeks of implementation; 11–18 months to a shipped v1 with normal overhead.** The reduction from the previously stated 45–69 / 12–18 is DR-001's removal of the channel router, the crossing sweep and the hop arcs from M2, partly offset by DR-005's revision clouds in M6. (The pre-DR-001 figure is **45–69**, the final cumulative row of canon §9.11's own table; the "41–69" that section's prose quotes is an arithmetic slip against that table and is not the historical number.) Better than the 16–22 months `critique-feasibility.md` priced the unreduced design at, and not the 5–6 months its cut table promised, because that table cut a requirement (RJ-008). **M1 and M4 are the two `L` milestones.** M4 became one when DR-015 put the device-library subsystem on its checklist; the +2 is the library directory service, the `.rmda` codec and its import/export, template provenance, the palette filter, the library browser and the file-dialog parameterisation, none of which the 5–7 ever contained.

> **The bottom-up sum came out higher than this, and the difference is on the record rather than buried in it.** Summing the 17 issues M4 decomposed into gives roughly **10–15 weeks**, and the part of that attributable to DR-015 is only ~1.5–2. The rest says the pre-DR-015 base of 5–7 was already optimistic. **Only the DR-015 delta is adopted above**, because it is the one change with a ruling behind it; re-pricing the base needs velocity evidence this project does not yet have, and swapping a stale number for a differently-invented one buys nothing. Flagged in docs/12 §5.3 as an open question for the first M4 task to answer with real data.

**Two levers exist if that number is unacceptable.** Pull them explicitly rather than by drift.

| # | Lever | Effect | Cost |
|---|---|---|---|
| 1 | **Ship M1 as a public v0.9** | Converts 10–15 weeks of invisible work into user evidence that would resolve half the remaining open questions | None. M1 is a real product (§4) |
| 2 | **Cut the catalog to 40 archetypes at full fidelity** rather than 80 | Removes catalog authoring weeks from M1 | None to quality: the provenance gate (AC-052) sets the count, and 40 sourced templates beat 80 guessed ones. Lower *fidelity* is not the lever (RJ-007) |

A third lever, **moving M4 after M6**, was available until DR-003 ruled the device builder into v1. It is withdrawn.

---

## 7. Risk register

Ordered by expected cost. "Early warning" is the observable that should trigger the mitigation before the risk lands.

**Risk IDs are `RISK-nn`. The bare `Rn` form means a brief requirement and nothing else (N1).**

| # | Risk | Likelihood | Impact | Mitigation | Early warning sign |
|---|---|---|---|---|---|
| `RISK-01` | **Screen/PDF text parity fails**, forcing a layout rewrite late | Medium | Severe: invalidates layout work across every sheet | Baseline-y parity test in M1 as a stop-the-line gate; `TextMetrics{advanceWidth, ascent, descent, capHeight, xHeight, lineHeight}` never reduced to a width; both backends fed by `PdfFont.stringMetrics` (CR-087, AC-007) | The parity test is written but marked skip, or asserts on width only |
| `RISK-02` | **M2 commit budget missed.** The wire-layer rebuild is no longer the dominant term under DR-001, but the commit path is still the tightest budget in the plan | Medium | Major: the schematic feels laggy at exactly the density that matters | Re-baseline to ≤ 16 ms with ≤ 8 ms for non-paint terms; **keep the per-domain sub-pictures: they are what lets a domain filter switch to `drawn` mode without rebuilding seven other pictures**; tag pills in their own LOD-gated picture; measure **op count** per layer in CI, not wall time on a shared runner | Op count per commit rising above ~2,000 on the 300-connection fixture |
| `RISK-03` | **Scope drift back across the §2 line** ("just one more DRC rule", "just free-drag on shelves" | High | Major), this is the mechanism by which 65 weeks becomes 100 | Every deferred item has a named home and a ruling ID; PRs adding scope must cite an amendment; the fixture-pair gate (AC-051) blocks rules mechanically | A PR that adds a rule without a fixture pair, or an issue labelled `v1` with no ruling ID |
| `RISK-04` | **Catalog provenance stalls M1** (cited numbers are slower to produce than guessed ones | Medium | Moderate) M1 slips by weeks, not months | Lever 3: cut to 40 archetypes at full fidelity. Uncited safety-adjacent fields do not ship (AC-052), and that rule is not negotiable | `sources.md` lagging template count by more than ~10 entries |
| `RISK-05` | **The label layer misses the commit budget.** DR-001 makes two net labels per `Link` the default render, so the dominant commit-path term is **text**, not geometry: ~300 additional text runs on a 150-connection project on top of the ~10,000 the cache is sized for (AC-009) | Medium | Major: the default render is the one that has to be fast | Measure the **label layer** in the perf harness; key the cache on `(text, styleId, quantisedScale)`; enforce the LOD gate as a test | Text-cache hit rate below ~90% on the 300-connection fixture at fit-to-sheet zoom |
| `RISK-06` | **Text cache thrash**: ~10,000 runs against a 2,000-entry LRU, with native `ui.Paragraph` disposal in the paint path. The mechanism behind `RISK-05`, tracked separately because it also bites the elevation and the schedule | Medium | Moderate: GC pressure and native churn during pan | Size from the real figure (12,000 entries, AC-009), not the assumed one; the same key as `RISK-05`; a thrashing LRU is worse than none | Eviction count per frame rising during a plain pan with nothing selected |
| `RISK-07` | ~~Code-signing certificate lead time blocks a finished build~~ **RETIRED IN THAT FORM: DR-006 (canon §12.9).** Replaced by: **the public `.cer` is not deployed to the target machine's trust stores** | Low *(was Medium)* | Minor *(was Moderate)*: an internal machine shows *Unknown publisher*; nothing is blocked | Ship the `.cer` with the build and deploy it to `LocalMachine\Root` and `\TrustedPublisher`, ideally by GPO. **There is no procurement and no reputation ramp to defend against**: the lead time D10 feared was specific to OV/EV identity verification and hardware-token logistics, none of which attaches to self-signing or to Trusted Signing | A clean test machine shows *Unknown publisher* |
| `RISK-08` | **Beta integrators cannot be recruited** in time for M9 | Medium | Moderate: the only exit criterion that matters becomes unverifiable | Start recruiting at M6; three integrators, five real projects; M1 shipped as v0.9 (lever 1) makes recruitment far easier. **DR-006 changes the POPULATION, not the lead time**: three integrators become three internal users on three real jobs, which is easier to recruit and does not remove the need to ask early. M9's exit criterion is unchanged and is still a judgement, not a metric | No named integrator by the end of M6 |
| `RISK-09` | **Byte round-trip proves harder than budgeted** in M0 (nested `unknown` key ordering, timestamp precision, integer formatting | Medium | Moderate) M0 is `S` and can absorb it, but only once | Write the test first; treat `unknown` map ordering as part of the codec contract, not an accident of `Map` iteration | Semantic round-trip passing while the byte test is deferred "for now" |
| `RISK-10` | **Solo-engineer bus factor** across an 11–17 month plan | Low | Severe | Everything load-bearing is a test, not a memory: the golden corpus, the DRC fixture pairs, the round-trip properties, the four starter projects. The canon plus this doc set is the handover artifact | Undocumented decisions accumulating in commit messages rather than in [the canonical decision record](canonical-decisions.md) |
| `RISK-11` | **File-size budget breached** at real project scale, invalidating plain JSON | Low | Major: a format change after users have files | Ports are not materialised unless they carry state (AC-006); the four starter projects act as size fixtures with an asserted ceiling | A starter project crossing its asserted byte budget |

---

## 8. How progress is tracked in this repo

1. **The milestone is the unit of planning; the exit criterion is the unit of truth.** A milestone is not "done" when the checklist is ticked; it is done when its exit criterion has been demonstrated by running something, and the demonstration is recorded in the milestone's closing commit message.
2. **Every issue and every PR cites a ruling ID.** `CR-nnn`, `AC-nnn`, `RJ-nnn` or `DR-nnn`. A change with no citation is either implementing an unadjudicated decision, in which case it needs one, or re-litigating a settled one, in which case it needs an amendment to [the canonical decision record](canonical-decisions.md). This is the mechanism that makes `RISK-03` detectable rather than merely regrettable.
3. **Scope changes are amendments, not conversations.** Moving an item between v1, v1.1, v1.2, v2 and not-doing is an edit to §2 of this file with a new ruling ID, in its own commit. The tables above are the only scope list; there is no second one in an issue tracker.
4. **Green means green.** CI runs analyze, test, goldens, format, the no-Flutter-import test, the epoch-mask coverage test and the connector-footprint assertion. The perf job is warn-only for the first three months and measures op count per layer. A milestone that ends red has not ended.
5. **The four starter projects are the regression net.** They are goldens, perf fixtures and screenshot source at once, and every milestone must open all four. When a milestone adds a subsystem, the starter projects grow to exercise it, at minimum one exercises Structure and one exports a full sheet set (AC-052).
6. **Fixture gates are enforced by CI, not by review.** No DRC rule merges without a known-bad and a known-good near-miss (AC-051); no catalog template merges with an uncited safety-adjacent field (AC-052); no connector merges without a footprint entry (AC-050).
7. **Open questions are tracked separately from scope.** They are decisions awaiting human judgement, not work items. **The binding user decisions run `DR-001` through `DR-087` (canon §11; `DR-016` alone is ruled inside §10.12(c) rather than in its own subsection).** The total is deliberately NOT written out here: this sentence has now been stale twice, and canon §11's own list is the one place the rulings can be counted without a second number going out of date. Of them, DR-017 is the first to rule on **process rather than product**, DR-019 the first to supersede another ruling's *reasoning* as well as its result, and DR-020 the first whose evidence is the trade rather than the corpus, and **canon §10 no longer has an open entry**. Of its thirteen questions: **ten are ANSWERED** (§10.1, §10.2, §10.4, §10.6, §10.7 by DR-001–DR-005; §10.10 by DR-009; §10.5, §10.8, §10.9 and all seven of §10.12 answered directly on 2026-08-03); **§10.3 pricing is MOOT** rather than answered, because DR-006 makes RackPal an internal tool and there is nothing to price (canon §11.6.3, §13); **§10.13 is retired**, its three priorities all answered; and **§10.11, the beta gate, is DEFERRED with a trigger** and is the only entry still owing an answer. It is owed **before the M6-J5 recruiting ask**, not before M9, on the ground that the bar is easier to state against a product than against a plan. *(Owed edit, paid 2026-08-03. This replaces a list of five remaining questions that four rulings had already closed, which is exactly the failure mode §8.3 exists to catch.)*
8. **A closed task names the commit that closed it.** Adopted 2026-08-03, forward-only, existing closed items are deliberately not backfilled, because a hash reconstructed by archaeology months later is a guess wearing the costume of a record. §8.2 makes every issue cite the ruling it implements; this is the other end of the same join, and between them a board row points backwards to *why* and forwards to *what shipped*. Under the atomic-commit habit a task usually closes with one hash; a task that took several lists them. **This is the only mechanism connecting the board to the tree**: without it, answering "what actually shipped for this row?" is a `git log` dig whose answer degrades every week.
9. **A milestone opens only over a predecessor whose clauses are all discharged or parked** (DR-095, canon §11.94). Discharged means `DEMONSTRATED` or `CONFIRMED`, which docs/12 §0 already rules are the only two of the seven marks that discharge an exit clause; this rule adds no definition, it adds the boundary at which that one has to hold. **Parked** means reassigned by ruling ID to a named later milestone, with the structural reason the clause cannot be discharged where it sits: DR-027 is the precedent, splitting M3's Pull Sheet clause so that M3 owes the derivation and M6 owes the sheet, and `#574` is the second instance. Parking costs a ruling ID because without a price it becomes the word for every clause nobody wants to do. **Closing is the moment that binds**; opening is a soft edge that `M5-0a` and `M8-F1` both crossed usefully, and §14.0's version rule already contemplates work landing against a later milestone. **Retroactive to M0**, deliberately departing from §8.8's forward-only stance: a hash reconstructed months later is archaeology, but a clause's evidence is in the tree and can be re-run, so applying this backwards recovers facts rather than inventing them. Enforced by review as of 2026-08-26; the CI gate that reads docs/12's clause tables is filed as `#780` and is **blocked on normalising every clause table to the seven marks**, because M3's table today says `BUILT`, which is `BELIEVED` wearing a word that reads like a discharge.

See also: [Overview](00-overview.md) · [Domain](01-domain.md) · [Data model](02-data-model.md) · [Architecture](03-architecture.md) · [Testing and quality](11-testing-and-quality.md).
