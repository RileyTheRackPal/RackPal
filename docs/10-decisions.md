# Architecture Decision Record

**This file is not the normative record.** The normative record is
[docs/canonical-decisions.md](canonical-decisions.md), 120 `CR-nnn`, 59 `AC-nnn`, 17 `RJ-nnn`,
canonical naming, the model, the registry, the scope ruling, the milestone plan, and Part 4's
binding user decisions `DR-001`–`DR-023`. This file is a sixteen-ADR summary of it. Where an ADR
and a ruling appear to differ, the ruling wins and this file is wrong.

What follows is the short-form decision log for RackMate: sixteen ADRs covering the choices that
shape the codebase, each traced back to its adjudication in the canonical decision record; then
**the twenty-five user decisions `DR-001`–`DR-025`**, which are binding and override the recommendations
they answer; then the questions of canon §10, **none of which is open any longer**: ten are
answered, 10.3 is moot under DR-006, 10.13 is retired, and 10.11 alone is deferred, to M5 rather
than indefinitely. An ADR here is a summary with a pointer, not a new ruling. Open questions carry no
normative weight at all: each states its options, the honest trade-off, the evidence that would
settle it, and a recommendation explicitly labelled as such, and a recommendation the user has
overruled is marked as void where it stands.

| ADR | Title | Status | Governing rulings |
|---|---|---|---|
| [001](#adr-001-desktop-first-windows-first-mobile-read-only) | Desktop-first, Windows-first, mobile read-only | Accepted | Confirmed decision 1, AC-056, AC-016 (#23) |
| [002](#adr-002-local-single-file-projects-with-a-cloud-ready-model) | Local single-file projects, cloud-ready model | Accepted | Confirmed decision 3, CR-095, CR-094 |
| [003](#adr-003-file-extensions-and-container-format) | File extensions and container format | Accepted | CR-091, CR-063, CR-098, AC-057 |
| [004](#adr-004-schema-versioning-and-the-migration-chain) | Schema versioning and the migration chain | Accepted | CR-092, CR-093, CR-117 |
| [005](#adr-005-a-seeded-catalog-of-generic-archetypes) | A seeded catalog of generic archetypes | Accepted | CR-061, CR-062, RJ-007, AC-052 |
| [006](#adr-006-the-templateinstance-split-copy-on-place) | The template/instance split: copy-on-place | Accepted | CR-054, CR-051, CR-053, AC-041 |
| [007](#adr-007-the-wiring-entity-model-link--service--conductor--net) | The wiring entity model | Accepted | CR-008, CR-010, CR-011, RJ-003 |
| [008](#adr-008-route-geometry-is-not-persisted) | Route geometry is not persisted | Accepted | CR-012 |
| [009](#adr-009-the-v1-routing-algorithm) | The v1 routing algorithm | Accepted | CR-013, AC-016 (#20) |
| [010](#adr-010-three-tier-validation-strictness) | Three-tier validation strictness | Accepted | CR-017, CR-018, CR-019, CR-022 |
| [011](#adr-011-state-management-riverpod-over-a-single-mutation-gate) | State management | Accepted | CR-119, AC-016 (#19), AC-013 |
| [012](#adr-012-undoredo-one-command-machinery-three-stacks) | Undo/redo: one machinery, three stacks | Accepted | CR-106, CR-094, AC-014 |
| [013](#adr-013-one-renderer-for-screen-and-pdf) | One renderer for screen and PDF | Accepted | CR-086, CR-081, CR-083, CR-087, CR-088 |
| [014](#adr-014-two-views-elevation-and-schematic) | Two views: elevation and schematic | Accepted | RJ-002, CR-105, CR-104 |
| [015](#adr-015-the-five-package-split) | The five-package split | Accepted | CR-083, CR-084 |
| [016](#adr-016-density-management--one-sheet-net-labels-filter) | Density management: one sheet, net labels, filter | Accepted | CR-073, CR-103, AC-037, **DR-001**, **DR-004** |

**The twenty-four user decisions**, binding and overriding any recommendation they answer. Full text in
canon §11; the supersession index is canon §12.

> **This table listed only `DR-001`–`DR-005` until 2026-08-03**, an owed edit canon §12.9 recorded
> against DR-006 and which then went ten rulings further out of date. Seven of the twenty-four answer a
> canon §10 question and say which; the rest are rulings the work itself raised, which is why their
> `Answers` column is empty. (**The count in this note read "sixteen" against a heading that read
> "seventeen"** until DR-018's sweep; a written-out count drifts every time a ruling lands, which is
> why the rulings that change one now grep for it.) `DR-016` is the only one ruled inside a §10
> entry rather than in its own §11 subsection, because §10.12(c) is where the scope addition was
> made. **`DR-017` is the first about process rather than product**: it exists because roadmap §8.2
> requires a citable ruling id and the board item implementing it had none. **`DR-018` is the second
> scope amendment after `DR-016`**, and **`DR-019` is the first ruling to supersede another
> ruling's reasoning as well as its result** — it discharges DR-018's condition and records that
> §11.17.4's stated ground did not survive a read of `persistence/`.

| DR | Decision | Answers | Effect here |
|---|---|---|---|
| [DR-001](#dr-001--net-labels-by-default) | **Net labels by default**, drawn wires on domain filter, `Alt`-hover or focus | §10.1 | Reverses the recommendation. ADR-009 and ADR-016 are rewritten; M2 drops from `L` to `M` |
| [DR-002](#dr-002--residential-ci-primary-commercial-capable) | **Residential CI primary, commercial capable** | §10.2 | Confirms the recommendation and makes the bet explicit |
| [DR-003](#dr-003--the-device-builder-ships-in-v1) | **The device builder ships in v1**; M4 stays | §10.4 | Confirms the recommendation. The roadmap's "move M4 after M6" lever is withdrawn |
| [DR-004](#dr-004--multi-sheet-splitting-is-never-built) | **Multi-sheet splitting is never built** | §10.7 | One `Sheet` plus domain filtering, permanently. The `Sheet` **entity** stays (AC-037) |
| [DR-005](#dr-005--the-schematic-is-a-client-deliverable) | **Client deliverable: invest in drafting polish** | §10.6 | Reverses the recommendation. Full sheet furniture in v1, revision clouds included. **Orthogonal to DR-001** |
| DR-006 | **Internal tool, self-signed distribution**, no commercial release planned | *nothing in §10, **moots** §10.3* | **No certificate procurement at any milestone.** M8's criterion splits into a build-side gate and a documented distribution-side requirement (canon §11.6.2). RISK-07 retired in its stated form |
| DR-007 | **Low-voltage box / keystone plate is an entity**, in M3 | — | Every occupant is 1×1, superseding the 2-slot speaker constraint the original request assumed |
| DR-008 | **The wiring model**, `Link`/`Service`/`Conductor` | — | The M2 spine |
| DR-009 | **Windows and macOS from v1** | §10.10 | Reverses a recommendation that was explicitly *"not a ruling"*. The register it demanded is `docs/13-macos-debt-register.md` |
| DR-010 | **The registries ship as a seeded Dart catalog**, and the family gets its dash back | — | 8 domains, 55 families, seeded at document creation, ordinary stored data thereafter |
| DR-011 | **The connect gesture** (pin-to-pin, ports materialised on connect, the sheet holds still) | — | M2-F's spine; §11.11.8 deferred four rules to DR-012 |
| DR-012 | **The four gesture rules DR-011.8 deferred** | — | Phase 4 could not start without them |
| DR-013 | **Deleting a wired device cascades**, after a warning that counts the cost | — | Lossless undo; board #95 |
| DR-014 | **Drawing a wired set member at a different device splits the set** | — | Board #96-C |
| DR-015 | **The `rm` extension family** (`.rmpj`, `.rmdx`, `.rmda`) | — | A rename, **not** a format change. Re-opens AC-042's library pack as a single JSON file, not a zip. ADR-003's container table is superseded |
| DR-016 | **The starting racks become editable presets** the user tailors to their own inventory | §10.12(c) | A **scope addition under roadmap §8.3**. 42U survives as the shipped seed value; the preset **set** stops being fixed. Presets stay unpersisted on `Rack` (no `presetRef`), so this is a new writable store, not a format change. Board #561 |
| DR-017 | **`dart format` is a gate; the analyzer stays a ratchet** |: *(answers docs/12 §4.1, not a §10 entry)* | **Process, not product; no scope change.** Gate 1b in `azure-pipelines.yml` and `run_local.ps1`, so the local count is **fourteen**. Infos stay pinned in `analyze_info_baseline.txt` (**173**) rather than `--fatal-infos`, because formatting has one correct answer and style infos do not. docs/11 §7 amended; §9 clause 1 is now the fourteen-gate run. Board #566 |
| DR-018 | **The Plan view moves from not-doing to v1.1, conditionally** | — | A **scope amendment under roadmap §8.3**, the second after DR-016. Floor plans leave canon §7.6's cable-dressing row (which had only ever argued cable dressing) and land in roadmap §2.2. Placed conditionally against §2.2's additive membership criterion; **DR-019 discharges the condition** and corrects §11.17.4's reasoning. RJ-017, AC-024, AC-057 and G4 all stand. Feasibility and cost: `docs/research/feasibility-plan-view.md`. No board item |
| DR-019 | **The plan container is JSON-or-zip by sniff; v1 owes a passthrough, not a carrier** | — | **The only DR that supersedes another DR.** `.rmpj` stays plain pretty JSON with no binary member and becomes a zip container with one, so **nothing migrates** and CR-091's single file survives; the writer owes stated determinism because zip is nondeterministic and CR-117 is byte round-trip. Base64-in-JSON and a sidecar are rejected with reasons. PNG and JPEG in, **no PDF import**. **It corrects DR-018 §11.17.4**, which claimed a migration cost that a read of `persistence/` does not support: the real G5 item is that **`Placement` carries no `unknown` map**, so an older build silently drops plan pins on save. That passthrough is v1's one new item and lands in M3. The Plan view is now v1.1 **unconditionally**. Design: [Plan view](15-plan-view.md). No board item |
| DR-020 | **A plan may not predict a route; the length column's job is the as-built tally** | — | **The first ruling whose evidence is the trade rather than the corpus.** Structure (LVLs, concrete beams, purlins) forces runs into a crawlspace instead of an attic and is not knowable from a floorplan, so `docs/15` §4's design-time **route polyline is void one commit after it was written**, along with `routingFactor` and `slackAllowance`. The plan contributes **`planLowerBound`** only: italic, prefixed `≥`, never summed into the footage rollup. Its value is the asymmetry, a bound can **prove** a length violation and can never prove compliance. v1 gains three items: `Link.spliceCount: int?` (null unknown, `0` confirmed none), the generic **`LEN-002`** reading a maximum off the media registry (canon §11.19.7: the field is `maxRunLengthPassive`, it is not new, and M3-C/6 seeded it), and the **as-built tally surface in M3**. **The catalogue becomes 28** (8 + 6 + 14), superseding §12.6(b) on the number only; AC-051's gate applies to 28 pairs. `PathwayKind` gaining `attic`/`crawlspace` is left open for M3 |
| DR-021 | **Deleting a `Location` cascades the subtree and clears every reference** | — | The first ruling the location tree has raised, which until now had no delete semantics at all. The subtree goes in one undoable command; **promotion is rejected** because it rewrites the breadcrumb of every surviving room without an edit, and refusal is rejected on DR-013 §11.13.3's ground. **Nine fields across seven entities** point at a location from outside the tree, and every one is cleared to null (G4's unknown) rather than left dangling, so a cleared drop lands in the Pull Sheet's `NO ROOM RECORDED` band instead of vanishing. The count is computed once and consumed by the command, DR-013 §11.13.2's shape. A reparent that would make a node its own ancestor is **refused** the way `TOP-005` refuses a shelf cycle. No `Link`, `Outlet`, `Pathway` or drop is deleted. **No scope change.** Board #144, #145 |
| DR-022 | **`{SERVICE}` in a drop's field label is the outlet template's tag** | — | Measured, not argued: the shipped `Residential CI` preset `{ROOM_ABBR}-{SERVICE}-{SEQ}` has no `[...]` around any token, so it **throws on a rough-in drop** — the state docs/07 §4.1 calls *"first-class, encouraged"*. The corpus's own examples settle the source: `LR-TV-1`, `MBR-KEY-2`, `EXT-CAM-4` are the **TV location / Keypad / Camera** templates, not signal families. `OutletTemplate` gains a `tag`; **not a migration**, because `outletTemplates` is `{}` in all four shipped starters, which is DR-019's `Placement.unknown` argument on a smaller surface. The family `shortTag` route is rejected because CR-048 stores a designator once, so every rough-in label would read `STR` forever. The **rack label needed no ruling**: it is optional (CR-044), so AC-018's fourteen unbound drops simply have none. Amends board #150 to a one-field model change; resequences #152 before #147. **No scope change** |
| DR-023 | **The `{SERVICE}` fallback chain: modifier, then template tag, then the media's short tag** | — | The question DR-022 §11.21.6 handed to #147. Three steps and no fourth: the line's `@service=`, else the `OutletTemplate.tag` DR-022 settled, else `MediaTypeDef.shortTag`. **`@service=` outranks the template** because CR-048 stores a designator once at creation, so a label that cannot be overridden at entry can only be fixed by deleting the drop, and a sixty-drop drill cannot afford that; the accepted cost is a drop whose label may disagree with its own outlet's template. **The media tag is not the `STR` answer DR-022 rejected**: `STR` was rejected for being one placeholder word identical on every rough-in cable, and `C6`/`RG6`/`16/4` vary per drop and are facts the line stated. Refusing instead would refuse docs/07 §4.3's own first worked example and fight §4.1's *"first-class, encouraged"* undetermined state. A user-created media type with no `shortTag` (RJ-009 import) **refuses** rather than printing a raw id. Deliberately does **not** rule whether `@service=` also sets `Service.signalFamily`. **No scope change** |
| DR-024 | **Board #151 is a model field and a picker; its data half already shipped** | — | A **task re-scope**, ruled because #150 closed over half of #151 without either being wrong. #151 asked for the TIA-570-D presets and said why they are not decoration: *"Grade is a CITATION, not a suggestion."* All three shipped at `5abb8b3`, transcribed from docs/07 §1 with the source named **including the part that reads oddly** (Grade 3 is given a lower twisted-pair grade and fewer coax than Grade 2, which is flagged for docs/07 rather than corrected in code). What is left is `OutletTemplate.tia570Grade: String?`, because CR-108 keeps the grade a **tag, never an axis**, and a preset today cannot stamp the one field it exists to carry. **A builder special case on the three seeded ids is rejected**: it would key the behaviour to a string, so a user-authored preset (the first-class thing CR-108 protects) could never stamp anything, and an id rename would be a silent behaviour change. **Not a migration and CR-117 holds**: the key is absent when null, so the six named templates re-encode byte for byte. The picker is **`+ Add outlet ▾`** (docs/07 §4.3), which no task claimed, and it is the **first caller of DR-023 step 2**, an arm nothing could reach because nothing created an outlet *from* a template. Does not rule the template **library flow**, nor AC-034/m24's template-driven inspector fields. **No scope change** |
| DR-025 | **`@service=` names the label, `@signal=` names the family; they are two words** | — | The question #587 raised while #149 closed: a structured run's `Service.signalFamily` is `structure.undetermined` **forever**, because `buildAddHomeRunCommand` hardcodes it and nothing writes it afterwards, so docs/07 §4's wireframe draws a SERVICE column of values no gesture can produce. The corpus pointed two ways: §5.1's import table maps a `service` column to `SignalFamilyId`, where DR-023 resolves `@service=` through an `OutletTemplate`. **Decided by the user's own job shape**: *"one AVoIP system for most areas, but a simple HDBT transmitter/receiver pair for say, running from an AVR to a projector"*. `video.avoip` and `video.hdbaset` are the same domain, same `conn.rj45`, same Cat6, and differ in topology, so a house has runs with the same label and different families and vice versa. **The decisive form**: `video.hdbaset` excludes `net.ethernet` from `acceptedFamilies` because 100 W PoH into a switch damages it, which is `SIG-001`, *"the highest-value validation in the product"*. If the label token set the family, choosing a label would decide whether that check fires. The modifier is **`@signal=`** because §5.1 already lists `signal` for this column; it resolves by `shortTag`, id tail, then `displayName`, and **refuses** an unknown value, since §3 keeps signal families catalog-updated where RJ-012 makes media user-extensible. A CSV **`Use` column feeds the label chain and never the family**, because real pull lists put `TV`/`Data`/`Camera` there; §5.1's synonym row splits and is the one derived edit this forces. The default is untouched: a drop is still created `structure.undetermined` and a template's `service` is still never copied. **Both copies or neither**: the family is stored on the `Service` and on the `Net`, and only the first is consumed. **No scope change**; unblocks M3-F |

See also [Canonical decisions](canonical-decisions.md), normative, plus
[Overview](00-overview.md), [Data model](02-data-model.md),
[Architecture](03-architecture.md), [Roadmap](09-roadmap.md).

---

## ADR-001: Desktop-first, Windows-first, mobile read-only

**Status:** Accepted. Fixed by confirmed product decision 1; not open.

**Context.** The user is a professional integrator at a desk with a mouse, two monitors and a
printer. The authoring surfaces, a 45U elevation, a schematic canvas, a 30-column port grid,
are pointer-and-keyboard instruments. A phone in an attic is a different user in a different
posture doing a different job: reading.

**Decision.** v1 is a **single-window Windows desktop application** (§7.1). Mobile and tablet are
**read-only on exactly three surfaces** (rack elevation, schedule table, exported PDF) and the
app says so in copy rather than shipping a squeezed editor (AC-056). Touch is not precluded:
`CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` is built **first**, and no editor logic
anywhere branches on `PointerDeviceKind` (AC-016 #23). macOS is deferred pending §10.10.

**Consequences.** The intent layer is written before the first gesture, which costs a few days up
front and makes mobile editing a v2 product decision rather than a rewrite. Three read-only
surfaces must be designed and tested as first-class, not as leftovers. Every Windows-only
dependency taken in M0–M6 must be recorded as a named macOS debt item.

**Alternatives rejected.** A responsive single codebase that edits everywhere, it degrades the
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
set** (CR-095), and **two counters**: `RackDocument.sequence`, strictly monotonic across every
committed transaction *and* every undo/redo, persisted, the sync cursor; and
`RackDocument.stateId`, in-memory, non-monotonic, driving `isDirty` (CR-094).

**Consequences.** Tombstones and `EntityMeta` cost file size and code in v1 for a feature that
may never ship, accepted under G5, because they are the one thing that cannot be retrofitted
without reconstruct-and-confirm over user data. `sequence` and `stateId` must never be conflated;
the temptation to use one counter for both is the defect CR-094 exists to prevent.

**Alternatives rejected.** A project *directory* (`.history/` folders, sidecar assets), CR-098;
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
| `.rmpj` | One project. **Plain, pretty-printed, key-sorted UTF-8 JSON**, `document` wrapper. |
| `.rmdx` | One device template. Plain JSON, **same unit regime**: `depthNm`, `weightUg`, `xNm` (CR-063). Own migration chain. |
| `.rmda` | Many device templates in one file, same regime, same chain. |
| `.bak` | The single sibling backup of a `.rmpj`. No `.history/` folder (CR-098). |

Device images are cut (AC-057), which is what dissolves the zip requirement. `DocumentCodec`
nevertheless **sniffs `PK\x03\x04` on read from commit one**, so a v2 zip container is a
non-event rather than a format break.

> **Renamed by DR-015 (canon §11.15), which is a naming decision and not a format one** — no byte
> inside any of these files moved and `schemaVersion` did not advance. The three rows above were
> `.rackmate`, `.rmdev` and `.rmlib`. **`.rackmate` is still opened and still saved in place**;
> it is accepted, never written, and never migrated underneath the user (§11.15.2).
>
> **`.rmda` also un-cuts AC-042's library pack**, which is a scope edit under roadmap §8.3 rather
> than a rename. It carries neither the `signature` field nor the `provenance` chain — AC-042's
> cut kept `contentHash` and threw away the cryptographic apparatus, and an archive needs only the
> half that was kept. **It is a single JSON file rather than the zip `.rmlib` specified**, for
> exactly the reason stated two paragraphs up: the zip existed to carry device images, images are
> cut, and D8's zip-slip / entry-count / decompression-bomb surface is bought for nothing. The
> trade is compression, on a file people email once.

**Consequences.** Projects diff and merge in git, are greppable, and are debuggable by hand, a
real advantage while the format is young. Files are larger than a zip and there is no place to
put a binary asset until the sniff path is implemented.

**Alternatives rejected.** Zip from day one; it buys nothing once images are cut and costs
inspectability. A binary format, premature by an order of magnitude.

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
[the file format specification](02-data-model.md#6-the-rackmate-file-format), with a **golden corpus**: every historical schema version
keeps a fixture that must still open. Byte-round-trip stability is a tested contract (CR-117),
key order, `unknown` maps, timestamp precision and integer formatting are all pinned, because
they are what otherwise produce spurious diffs and a lying dirty flag.

**Consequences.** Forward-compatible reads require preserving unknown fields through a Save As,
which every codec must honour. A migration is never skippable, the chain runs step by step.

**Alternatives rejected.** Exceptions for expected outcomes; a version *range* check instead of
`minReaderVersion`.

---

## ADR-005: A seeded catalog of generic archetypes

**Status:** Accepted. Fixed by confirmed product decision 2; the *single home* for the count is the decision.

**Context.** Four documents stated four catalog sizes (58, 62, ~40, "~30–50"). A critique
proposed shipping the catalog at lower fidelity, names and RU heights, ports filled in later.

**Decision.** v1 ships a catalog whose size is stated in exactly one place, the summary table in
[Seed devices](catalog/seed-devices.md#310-catalog-summary-and-what-is-deliberately-not-in-it),
and in **no prose anywhere, including this sentence** (CR-061). It sits mid-band in the confirmed
40–55 and includes the field devices of AC-019/AC-031. Fidelity
is full, not partial (RJ-007), and the shipping gate is **cited provenance**: every numeric field
in every template has a source in `assets/catalog/sources.md`, and a template with uncited
safety-adjacent fields does not ship (AC-052). Seeded templates are read-only; editing one
performs duplicate-and-edit, and the fork records `derivedFrom` so a later catalog correction
surfaces as a passive badge rather than being silently lost (CR-062).

**Consequences.** Authoring the cited templates is a real, schedulable content job, not a
side-task, and the **provenance gate sets the count rather than a target** (AC-052, RJ-007), a
template with an uncited safety-adjacent field does not ship and the number goes down. The
connector footprint table must be complete for every connector any shipped template uses, with a
CI assertion (AC-050 A2.2). A low-fidelity catalog would have shipped sooner and taught
users the numbers cannot be trusted, which is the G4 failure the honesty filter exists to catch.

**Alternatives rejected.** Lower fidelity now, fill in later (RJ-007). Real SKUs, a legal and
maintenance question, see §10.9.

---

## ADR-006: The template/instance split: copy-on-place

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

There is no fourth "detach" verb; it produces a device with no lineage. `localTemplate` and
`PlacedDevice.snapshot` are deleted; snapshots live only in `RackDocument.templates`, keyed
`"$templateId@$version"`. Placement is **copy-on-place** (AC-041): `templateRef{templateId,
version, contentHash}` is recorded, the snapshot embedded, and an out-of-date instance gets a
passive badge, no Update Manager in v1. `contentHash` mismatch is a **warning plus a badge,
never a load failure** (AC-042). The migration join key is `PortDef.key` + `renamedFrom`, never
`portId` (CR-051), and a removed port never silently deletes a cable (CR-052).

**Consequences.** A project opens correctly with no library present, which is what makes emailing
a `.rackmate` work. Catalog corrections do not propagate in v1; the badge is the entire remedy.
The Update Manager (v1.2) needs no format change when it lands.

**Alternatives rejected.** Live template references (a library edit silently rewires shipped
projects). Per-instance detached templates (CR-054).

---

## ADR-007: The wiring entity model: Link → Service → Conductor → Net

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

The word **`Connection` is banned** from code, file format, UI and prose
([canon §4.7](canonical-decisions.md#47-banned-names)), as are
`PhysicalLink`, `LogicalSignal` and `CableType`. `Net` is **stored, not derived** (CR-011,
RJ-003): membership is the foreign key, never the net *name*, name-carried membership is the
KiCad typo failure and a GUI tool with a device library has no excuse for it. Union-find is used
only to *propose* merges that a command then applies. `Endpoint` is a sealed union, 
`PortEndpoint`, `PlaceEndpoint`, `OpenEndpoint` (AC-018), so a cable to a room that has no
device yet is representable. Each **`Conductor`** spans exactly two endpoints; a `Link` may touch
more than two devices via `breakouts[]` (CR-014).

**Consequences.** The schedule can render one row per cable with its services listed, which is
what an installer actually needs. `Service.netId` ships as one FK with no net editor in v1, G5
in its purest form, since reconstructing membership later means union-find plus a
confirm-every-guess pass over existing projects.

**Alternatives rejected.** Derived nets in v1 (RJ-003, one field now versus a reconstruction
later). One service per cable (contradicted by the trade, CR-010). `SignalRoute` as a third layer
(deferred to v2 with a Dante view, or not at all, AC-036).

---

## ADR-008: Route geometry is not persisted

**Status:** Accepted.

**Context.** One document declared "no wire coordinates, no route geometry, if you ever find
yourself persisting a polyline you have made an architectural error", then shipped waypoints,
pinned routes and `routeOverrides?` three sections later. Another declared
`Map<Uuid, List<Pt>> waypointsBySheet`.

**Decision.** Per CR-012, **no route geometry is persisted in v1**. The router is a pure
deterministic function of the model, so the drawing is always consistent with the connectivity by
construction. `waypointsBySheet`, `routeOverrides` and `RouteWaypoint` are deleted. **Symbol
placement *is* persisted**: that is genuine user intent (`SheetItem`, with `pinned`). When
manual rerouting returns in v1.1 it is stored as **constraints** (an ordered list of grid points
the router must pass through, `routeConstraintsBySheet`) never as a polyline.

**Consequences.** A stale polyline can never disagree with the model; there is no reconciliation
pass and no "the wire points at nothing" state. The user cannot nudge a wire in v1, which is an
aesthetic itch on a deterministic router, and is the accepted cost.

**Alternatives rejected.** Persisted polylines with reconciliation on load, the class of bug it
introduces (drawing and schedule silently disagreeing) is exactly what G1 cannot tolerate.

---

## ADR-009: The v1 routing algorithm

**Status:** Accepted.

**Context.** One document specified an obstacle-avoiding orthogonal trace router with an
`ObstacleField`, a `RouteCache` and per-connection incremental invalidation. Another argued
RackMate never needs a general orthogonal router, and that a full deterministic recompute is both
cheaper than the invalidation bookkeeping and perfectly stable.

**Decision.** Per CR-013 **as amended by DR-001**: **Sugiyama phases 0–3 place the symbols; a
deterministic layer-ordered orthogonal trace draws the wires in `drawn` mode.** Full deterministic
recompute throughout. `ObstacleField`, `RouteCache` and the phrase "obstacle-aware" are deleted
([canon §4.7](canonical-decisions.md#47-banned-names)). Because DR-001 makes net labels the
default render, the expensive half of the original ruling leaves v1: **interval-graph channel
routing is v1.2**, and **the crossing sweep, hop arcs, junction staggering and dash-phase
divergence are not built at all**. Crossings render as plain crossovers, resolved by layering and
draw order.

```text
0 cycle-break -> 1 layer -> 2 barycentre sweep -> 3 coordinate assign
                                                     |
                                                     +-> net labels (default): two stubs per Link
                                                     +-> drawn mode: deterministic layer-ordered
                                                         orthogonal trace, one polyline per Link
```

**Consequences.** No cache invalidation code exists to be wrong. Layout is reproducible, the
same document yields the same drawing on every machine, which is a precondition for the golden
PDF tests. Recompute cost is bounded by the sheet, not the project. The three hardest correctness
problems in the corpus (the Bentley–Ottmann crossing sweep, hop-arc placement and junction
staggering) are simply absent, which is 4–5 weeks and most of M2's risk (canon §11.1.5). The cost
is that under a domain filter two traces may run adjacent where a channel router would have
ordered them; that is a v1.2 upgrade, not a correctness defect.

**Alternatives rejected.** Incremental invalidation (CR-013, the bookkeeping costs more than the
recompute it saves). A general A*/obstacle router (solves a problem a channel router does not
have).

---

## ADR-010: Three-tier validation strictness

**Status:** Accepted.

**Context.** One document said validation never blocks the pen and only five rules block
creation. Another defined a "Class A, hard-invalid, refused at drag time, cannot exist in the
document" tier including HDBaseT→switch and connector mismatch. A third had the rack editor
blocking drops on seven checks. Separately, `blockExportOnErrors` defaulted to `true`.

**Decision.** Per CR-017, the binding distinction is **the gesture may hesitate; the document may
not lie**: three tiers:

| Tier | Count | Membership | Behaviour |
|---|---|---|---|
| **Model-illegal** | **8** | `TOP-001..005` + placement coherence as three ratified rules, `PLC-001` `ruIndex` in range, `PLC-002` host is a container, `PLC-003` no containment cycle | Cannot be constructed. These are states in which the model *means nothing*. |
| **Gesture-refused** | **6** | ex-Class A: `SIG-001` `SIG-002` `DIR-001` `DIR-003` `CON-001` `ELE-006` | **Spring-back with a reason chip**, remedies kept exactly as designed, and every chip carries `[ Connect anyway ]`. |
| **Post-hoc finding** | **13** | the 13-rule post-hoc catalogue | `error \| warning \| advisory \| off` (CR-018); never blocks anything. |

**8 + 6 + 14 = 28.** The v1 catalogue is **28 rules** (DR-020 added `LEN-002`), enumerated once in
[the rule catalogue](02-data-model.md#5-the-v1-validation-rule-catalogue--three-tiers). The
long-quoted "22" was an arithmetic error against an enumeration that always listed more; the
enumeration governs (canon §12.6(b)). `PLC-001`, `PLC-002` and `PLC-003` are **ratified** as
distinct tier-1 rules, because an unnumbered blocking check can carry neither a `Finding.ruleId`
nor an AC-051 fixture pair, and CR-021 says a rule not in the catalogue does not exist.

Two ex-Class A members (Dante with no network path, AVB across a non-TSN switch) are
**logically unevaluatable at drag time** (the link being drawn may be the one that completes the
path) and are demoted to findings unconditionally. Dismissal is **one mechanism**:
`AckedFinding{ruleId, targetFingerprint, reason (required), by, at, demotedTo}`, at two scopes,
and **errors are acknowledgeable** (CR-019, RJ-006). `blockExportOnErrors` is **deleted, not
deferred** (CR-022); errors gate only `ExportSpec.issuedForConstruction`, and every export emits
sheet `T0.02 — Exceptions & Acknowledgements` carrying open findings and every acknowledgement
with its reason, author and date.

**Consequences.** An as-found miswired system is documentable, which is the remediation market
(G2). No heuristic can ever hold a deliverable hostage (G3). The cost is that the app will
sometimes print a drawing it believes is wrong, with a sheet saying so.

**Alternatives rejected.** Hard-invalid at drag time (CR-017). Non-dismissible errors (RJ-006,
refusing to let a professional override the tool's opinion about their own system is how the tool
gets abandoned). Rules as a JSON predicate AST (CR-024, AC-011, ~20 of 70 rules cannot be
expressed in a boolean tree, and the user-authored-rules claim is withdrawn from all documents).

---

## ADR-011: State management: Riverpod over a single mutation gate

**Status:** Accepted. **VERIFY:** Riverpod 3 API surface before the provider layer is written.

**Context.** The document is a large mutable aggregate with expensive derived values (occupancy,
rollups, findings, the routed scene). Naive rebuild-everything is not viable at 45U × several
racks × a few hundred links; ad-hoc mutation from widgets is how the undo stack silently
diverges from the document.

**Decision.** **Riverpod, with one `ProviderScope` per open document.** v1 is single-document,
single-window (CR-119), `Ctrl+N`/`Ctrl+O` prompt Save / Don't Save / Cancel and then replace,
but the per-document scope is kept exactly as designed, because it costs nothing now and makes
tabs (v1.2) and multi-window mechanical rather than a rewrite. All mutation goes through
`DocumentController`, the single gate; entity setters are `@internal`, not `part of` (AC-013).
Derived state is an explicit **three-tier pipeline driven by epoch counters**, with `lodLevel`
appearing explicitly in every scene-builder signature and every cache key (AC-016 #13).

**VERIFY:** Riverpod 3 moved `ChangeNotifierProvider` to legacy (AC-016 #19). The `epochs.revision`
adapter is hand-written, roughly 15 lines of `Provider` + `ref.onDispose`. The legacy library is
not imported.

**Consequences.** Widgets can never mutate the model directly, so undo correctness is a property
of one class. Epoch counters must be incremented correctly or a stale cache renders, covered by
the epoch-mask coverage test.

**Alternatives rejected.** `ChangeNotifier` on the document (rebuild granularity is wrong and the
class is legacy in Riverpod 3). Global singletons (kills the per-document scope and therefore
tabs).

---

## ADR-012: Undo/redo: one Command machinery, three stacks

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
stack ships in M0, it is the most expensive retrofit in the project, and carries a round-trip
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

**Context.** The architecture declared a display list (`DiagramScene`) as the single drawing IR, 
"screen and print cannot diverge", and then specified device faceplates, ports and
ref-designators as **real widgets**. The most information-dense content in the deliverable was
therefore drawn by a widget tree on screen and by a scene builder in print, with no parity
mechanism, defeating the guarantee exactly where it mattered most.

**Decision.** Per CR-086, **one rendering path; widgets remain as an interaction and semantics
shell.** Each device is still a `RenderBox` child of `RenderRackCanvas`, it owns hit-testing,
focus, hover, keyboard handling and `Semantics`, which is what makes the accessibility story true
, but its `paint()` **replays that device's `DiagramScene` fragment through
`FlutterDiagramCanvas`** and draws nothing itself. Pixels come from the shared IR; behaviour
comes from the widget. Supporting rulings:

- **One injected `TextMeasurer`**, backed by `PdfFont.stringMetrics`, used by the scene builder
  and by **every** backend including the Flutter one. `measureText` returns
  `TextMetrics{advanceWidth, ascent, descent, capHeight, xHeight, lineHeight}`, never a point
  (CR-081, CR-087). Flutter sets `FontFeature.disable('kern')` **and**
  `FontFeature.disable('liga')`. `TextStyleSpec` carries an explicit `TextAnchor` resolved in one
  shared pure-Dart helper. The parity test asserts on **baseline Y**, not the bounding box.
- **`RendererCaps` is deleted** (CR-088), the moment a scene builder branches on capabilities
  there are two code paths. No gradients, shadows, blurs, blend modes or shaders, promoted from
  prose to a tested invariant.
- **Global Y-flip** in the PDF backend, not per-coordinate negation (CR-085), the interface
  exposes `rotate()`, and rotation composed with per-coordinate negation is not a valid
  transform. Text is counter-flipped in exactly one method. `pw.CustomPaint` pre-translates to
  the widget box's bottom-left, so the flip height is `size.y`, not the page height.
- **`BoundsCanvas` ships in v1** (CR-089), scale-to-fit, tile counts, zoom-to-fit and the key
  plan all need the diagram's true extent. `SvgDiagramCanvas` is v1.1.

**Consequences.** The parity test covers faceplates by construction rather than by discipline.
Both backends and the parity test land **together and early** (CR-120), retrofitting parity is
the expensive failure. Anything Flutter can draw and dart_pdf cannot is simply unavailable.

**Alternatives rejected.** Widgets for screen, scene builder for print, reconciled by review, a
PDF subtly and unfixably different from the preview. Independent `measureText` per backend
(CR-081, Skia applies GPOS kerning and `liga`; dart_pdf applies neither).

---

## ADR-014: Two views: elevation and schematic

**Status:** Accepted. The strongest rejected argument in the corpus, rejected on evidence.

**Context.** A critique argued for one canvas: wire on the rear elevation, replace drawn lines
with port badges (`→ SW-01 P04`), show lines only under a filter or on hover. Two canvases means
two mental models, two coordinate systems, two selection behaviours, two colliding keymaps and a
what-syncs-what table the user meets as a surprise.

**Decision.** Per RJ-002, **both views ship**, and the four failures the critique predicts are
fixed directly and cheaply instead:

1. A 24-port patch panel to a 24-port switch renders as 24 badges reading `→ SW-01 P04`, a table
   drawn in the worst possible place. The proposal does not survive the density it exists to fix.
2. "Takes visual inspiration from electronics schematics" is not satisfiable by a badge on an
   elevation. Deleting the view deletes a requirement (RJ-001, RJ-002).
3. Positions are **not linked** between views and never will be: an AVR sits at U14 for thermal
   reasons and mid-chain for logical ones, and slaving either to the other destroys work silently.
4. The cliffs are fixed for days, not weeks: **CR-105** signposts wiring from the elevation (a
   `🔗 0/12` chip that jumps to the schematic with the device selected) and makes **the Schedule a
   top-level tab, present and populating live from an empty project** (`Ctrl+4`, AC-035);
   **CR-104** makes one palette, one insert command, placement decided by the drop target;
   **CR-101** arbitrates the ~40 keybindings from one `Intent` registry and fixes the 16
   collisions.

**The v1 tab strip shows three tabs: Rack (`Ctrl+1`), Schematic (`Ctrl+2`), Schedule (`Ctrl+4`).**
`Ctrl+3` is **reserved** for the interactive Rear Panel view, which is v1.1 (CR-071); in v1 the
binding is an unbound no-op and the tab is absent from the strip. Schedule is not rebound to
`Ctrl+3` to close the gap, `Ctrl+n` is a stable view identity, not an ordinal, and moving it in
v1 to move it back in v1.1 breaks muscle memory for a cosmetic gain. Sheet `T2.02 Rack Elevation
— Rear` **prints in v1** regardless; only the interactive view is deferred.

Connections are **created in the schematic in v1**; editing endpoints from the schedule and from
the Rear Panel view lands in v1.1.

**Consequences.** Two canvases to build, test and document, and a sync table with two exception
rows that gets a coach mark at the moment of surprise (AC-048). The deliverable is visible from
minute one rather than discovered at export (G1).

**Alternatives rejected.** One view with port badges (RJ-002). A generated, non-interactive
export-only diagram (RJ-001, it removes the requirement that the user *makes* the connections,
and it means `SheetItem.pinned` has to be retrofitted after the format ships).

---

## ADR-015: The five-package split

**Status:** Accepted.

**Context.** One document specified four packages with `rackmate_export` and `rackmate_ui` as
siblings that cannot see each other, the invariant that keeps the PDF path isolate-safe. Another
specified a single `lib/` tree with the Flutter and PDF backends in one directory and
`TextMeasurer`/`PdfFontMeasurer` in the core tree, which makes core depend on `package:pdf` and
breaks the architecture's own `no_flutter_import_test`. ADR-013's single-measurer ruling forces a
resolution.

**Decision.** Per CR-083, **five packages**: the dependency is inverted rather than the core
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

`rackmate_ui` depending on `rackmate_text` is harmless, `package:pdf` is pure Dart and
isolate-safe. The invariant that matters is preserved and **mechanically enforced**:
`rackmate_core`, where the scene builder lives, has no concrete font engine and no `dart:ui`; it
receives a `TextMeasurer` by injection, and `no_flutter_import_test` keeps banning
`package:flutter/`, `dart:ui` and `package:pdf/` in core. Hit-testing splits by concern (CR-084):
the *geometric* test (`DiagramScene.hits`, point-to-segment distance, nearest-hit) lives in
`rackmate_core/draw/hit_test.dart`, pure, synchronously testable, reusable by the read-only
mobile shell; the *pointer plumbing* (one query per frame, spatial hash, cursor policy, hover
throttle) lives in `rackmate_ui/canvas/input/`.

**Consequences.** Package boundaries are enforced by a test rather than by convention, a folder
convention "will be violated within a month by an `Offset` that 'was just easier'". Five
`pubspec.yaml` files and path dependencies to maintain.

**Alternatives rejected.** One tree with folder conventions. Four packages with `TextMeasurer` in
core (drags `package:pdf` into core and breaks the enforcement test).

---

## ADR-016: Density management: one sheet, net labels, filter

**Status:** Accepted. **§10.1 and §10.7 are both answered** (DR-001, DR-004); the idiom and the
sheet count are settled, not pending.

**Context.** A whole-house job runs to 140+ connections. Every drawn-wire schematic degrades into
spaghetti somewhere past 80, and the failure is silent: the user does not notice when the drawing
stopped being useful. Multi-sheet is the obvious answer and is a subsystem.

**Decision.** v1 ships **one schematic sheet**, and, per DR-004, that is permanent: the `Sheet`
entity stays in the format so nothing migrates if the decision is ever reversed (CR-073, AC-037),
but multi-sheet authoring is never built. Density is managed on the one sheet, by four mechanisms
that are cheap because they are all filters or LOD:

| Mechanism | Ruling |
|---|---|
| **Net labels as the default render**, with drawn wires on domain filter, hover or focus | DR-001, canon §11.1 |
| Domain filter bar: now **load-bearing**, not a mitigation: it is the primary way to see wires | `critique-ux-simplicity.md`'s density table, accepted |
| Symbol collapse to vector pins: one constant, `kBankCollapseThreshold = 8` | CR-103 |
| `Alt`-hover transient focus | §7.2.3 |

**Render mode is a function of the active filter, never a persisted setting.** Unfiltered sheet ⇒
`netLabels`: every `Link` is two labelled stubs, one at each pin, with no polyline between them.
Filtered to exactly one `SignalDomainId`, or `Alt`-hover, or focus/isolate ⇒ `drawn`: every `Link`
in scope is an orthogonal polyline with a tag pill at each end. `SheetRenderMode` is **derived**
(DR-001, canon §11.1.1). There is no density threshold that switches rendering, a threshold that
changes the drawing behind the user's back is the silent failure this ADR exists to avoid.

`kBankCollapseThreshold` replaces three separate thresholds (4 for vector-pin collapse, 17 for
unit split, 8 for symbol-preview collapse); any bank of ≥ 2 ports is user-collapsible at any
time, banks over 8 auto-collapse on first layout. Unit splitting is deleted with its 17-pin
threshold (CR-070) and, its multi-sheet precondition now being impossible, is not coming back.

**Two things that sound alike and are not.** *Multi-sheet authoring* (the user creates more than
one `Sheet` and a `Link` may span two of them) is **never built** (DR-004). *Exporter domain
partition* (one `Sheet` in the document, from which the exporter emits N interconnect sheets
`T6.01…` by filtering) **ships in v1, unchanged** (CR-073). N sheets coming out of the PDF is not
evidence that multi-sheet exists. Those exported sheets render `drawn`, because a domain partition
*is* a domain filter.

**Consequences.** The first PDF is not gated behind the multi-sheet subsystem, worth 4–6 weeks
(§7.7 cut #1), and under DR-001 one sheet holds a whole house, which is what makes DR-004's
"never" honest rather than optimistic. `ExportSpec.wireRender: auto | netLabels | drawn` defaults
to `auto`; `drawn` degrades to `netLabels` above a per-sheet `Link` count **and prints a note
saying so**, never silently.

**Alternatives rejected.** Multi-sheet in v1 (CR-073) and multi-sheet ever (DR-004). Geometric or
min-cut partitioning (creates the cross-sheet connector problem that domain partitioning does not
have). Drawn wires as the default with automatic degradation to net labels, the record's own
recommendation, **overruled by DR-001**.

---

# The user decisions

The sixteen ADRs above summarise rulings the record made for itself. The five below are different
in kind: they are **the user's answers to the questions the record deliberately left open**, and
two of them reverse what the record recommended. They are binding, they outrank every ADR and
every `CR-nnn` they touch, and they are not open to re-argument here. Full text and the
supersession index are canon §11 and §12; this is the summary with a pointer, same as an ADR.

## DR-001: Net labels by default

**Answers §10.1. Reverses the recommendation.**

Every `Link` renders as a pair of net labels, one at each pin, with no polyline between them.
Drawn wires are available on demand (filter to one `SignalDomainId`, `Alt`-hover, or focus) but
they are **not** the default. `SheetRenderMode` is derived from the active filter, never persisted
and never a setting.

**What it removes from v1.** Interval-graph channel routing (v1.2), and, permanently, the
Bentley–Ottmann crossing sweep, hop arcs at crossings, junction staggering and dash-phase
divergence. Layering and draw order do the work instead; crossings render as plain crossovers.
Worth 4–5 weeks and the three hardest correctness problems in the corpus.

**What it does NOT remove**, and this matters because these are easy to cut by association:
Sugiyama phases 0–3; the deterministic per-link orthogonal trace; every connection gesture
(drag-to-connect, sticky click-click, magnetic type-weighted snap, chain-draw, multi-draw,
`atomicConnect`, re-terminating, `Tidy sheet`); the whole palette and requirement 4; symbol
placement persistence (`SheetItem.position`, `pinned`); CR-012's no-persisted-geometry rule; and
RJ-001/RJ-002, the canvas survives, it just draws differently.

**Consequences.** M2 drops from `L` to `M`, and M1 becomes the only long pole. The domain filter
bar is promoted from a density mitigation to a load-bearing control. The dominant commit-path cost
becomes **text**, not geometry, which moves the perf risk rather than removing it. ADR-009 and
ADR-016 are rewritten above; CR-013 is amended to the extent it assumed a drawn-wire default.

## DR-002: Residential CI primary, commercial capable

**Answers §10.2. Confirms the recommendation.**

Residential custom integration is the primary market and fronts the UI. Commercial capability, 
the code rules, the ISO/NCS sheet-numbering option, the field-device set, the
issued-for-construction stamp, **remains present and never fronts the UI**. Both sheet-numbering
schemes ship, default `simple` (CR-066).

**Consequences.** Mostly ratification: every "default off for wall racks" and every simple-first
default was already this bet, made implicitly. The value of the ruling is that it is now explicit,
so commercial features stop being paid for by accident and TIA-570-D grades stay out of the
vocabulary a residential integrator has to navigate (CR-108). It also settles §10.12(d): three
residential starter projects and one small commercial.

## DR-003: The device builder ships in v1

**Answers §10.4. Confirms the recommendation.**

M4 stays exactly where it is. Requirement 2 is the GUI builder, not the catalog, and it is met at
M4, the catalog half lands at M1.

**Consequences.** No plan change; the value is that it stops being an open question. The roadmap's
third schedule lever, "move M4 after M6", is **withdrawn**, leaving two. M1's catalog miss-rate
instrumentation survives with a different purpose: it is no longer a scope trigger but
catalog-coverage evidence feeding §10.9.

## DR-004: Multi-sheet splitting is never built

**Answers §10.7 with option (c), which the record listed but did not recommend.**

One schematic `Sheet` plus domain filtering, permanently. **Deleted from the plan:** match lines,
off-sheet connectors, sheet-boundary link handling, schematic PDF tiling, and unit splitting
(CR-070, whose stated condition was "only if multi-sheet lands").

**The `Sheet` entity remains in the schema** (AC-037), so the file format never migrates if this
is ever reversed. It is not vestigial and must not be described as removable.

**What survives untouched:** CR-073's exporter behaviour. One `Sheet` in the document, N
interconnect sheets `T6.01…` emitted by filtering it at export, zero cross-sheet connections by
construction. **Partitioning at export is not multi-sheet authoring**, and no document may treat
"N sheets came out of the PDF" as evidence that multi-sheet exists.

**Consequences.** DR-001 is what makes this affordable: under net labels one sheet holds a whole
house, so the density argument that made multi-sheet feel inevitable no longer applies. §10.8
(cloud-ready investment) gets easier too, multi-sheet was the largest remaining source of
entity-graph churn, so the conflict unit is now stable.

## DR-005: The schematic is a client deliverable

**Answers §10.6. Reverses the recommendation.**

The sheet set is a billable artifact handed to a client, a GC and a job site. **Full sheet
furniture ships in v1:** title block, revision block, **revision clouds** (moved from v1.1),
issued-for-construction stamps, drawing borders, zone references and sheet numbering. `T0.00 Cover
& Drawing Index` is confirmed ON, a client deliverable has a cover. Zone references are confirmed
v1, which retroactively confirms CR-073's zone grid.

**THE CRITICAL NUANCE: drafting polish is orthogonal to wire idiom. This does not reopen
DR-001.** §10.6's trade-off text argued that a client deliverable "argues for (A) in §10.1"; that
inference is **explicitly rejected**. Its premise was that the drawing must survive being read by
someone who has never read a schematic, and that premise is false here: **the schematic's reader
is technical**: the general contractor, the electrician, the low-voltage sub, a
technically-literate homeowner. Those readers read net labels, which is how large electrical
schematics have been drafted for forty years.

| Axis | Decided by | Value |
|---|---|---|
| **Sheet furniture**: borders, title block, revision block, clouds, stamps, zones, numbering, index | **DR-005** | Full. Invest. |
| **Wire idiom**: how a `Link` renders inside the drawing frame | **DR-001** | Net labels by default; drawn on filter, hover or focus. |

Polish the sheet fully. Keep net labels. A beautifully drafted sheet whose connections are net
labels is a normal, professional, forty-year-old idiom, not a compromise.

**What it does NOT do.** It adds no floor plans, riser diagrams, reflected ceiling plans,
datasheet appendices, `T6.40` Power Schedule or `T6.50` Network/IP Schedule. It does not add PDF/UA
tagging (RJ-015 stands) or branding (RJ-017 stands). It does not weaken G3: the IFC stamp is gated
on zero open errors and **never gates bytes**, and `blockExportOnErrors` remains deleted (CR-022).
It does not change G1, the schedule is still the deliverable and the drawing is still the receipt;
DR-005 says the receipt is handed to the client, so it must look drafted by a professional.

**Consequences.** M6 grows by ~0.5–1 week and sits at the top of its `M` band. It also sharpens
§10.3: a larger, more valuable client-facing set raises the stakes on the watermark split, client
sheets only, never the Pull Sheet or Termination Schedule.

---

# Open questions

Everything above is binding. **This section is deliberately the opposite.** These are the calls
that require a human judgement about what this product is for and who is going to buy it, which
no amount of internal consistency can supply. Each states the options, the honest trade-off, what
evidence would tip it, and a **recommendation carrying no normative weight**: a recommendation
here can be overruled without amending anything; a ruling above cannot.

**Five of the thirteen are now answered.** The argument text stays in place as the record of how
each was reasoned about, but where the user's decision reverses a recommendation, that
recommendation is marked **void**. Read this table before the arguments below it.

| § | Question | Status | Answer |
|---|---|---|---|
| **10.1** | Draw every wire, or net labels by default, the fork | **ANSWERED, DR-001** | **(B) Net labels by default.** Drawn wires on domain filter, `Alt`-hover or focus. **Reverses** the recommendation |
| **10.2** | Residential CI or commercial AV, the primary customer | **ANSWERED, DR-002** | **(a) Residential-primary, commercial-capable.** Confirms the recommendation |
| **10.3** | Pricing and licensing model | **MOOT: DR-006** | **Nothing to price.** RackMate is an internal tool; no commercial release is planned. Retained as the record of the argument: if DR-006 is ever reversed, 10.3 reopens exactly as written |
| **10.4** | Does the device builder have to be in v1 | **ANSWERED: DR-003** | **(a) Yes. M4 stays where it is.** Confirms the recommendation |
| **10.5** | Metric or imperial default | **ANSWERED 2026-08-03** | **Imperial default, one obvious toggle.** Confirms the recommendation. The default is already in the code; the toggle is owed (board #562) |
| **10.6** | Is the schematic a client deliverable or an internal tool | **ANSWERED, DR-005** | **(a) Client deliverable, invest in drafting polish.** **Reverses** the recommendation. Orthogonal to 10.1 |
| **10.7** | Multi-sheet timing | **ANSWERED: DR-004** | **(c) Never.** One `Sheet` plus domain filtering, permanently. The entity remains |
| **10.8** | Cloud-ready investment | **ANSWERED 2026-08-03** | **(a). Spend nothing further; RackMate is a local application.** Confirms the recommendation. The six cloud-ready properties are retained in full; [02 §8](02-data-model.md#8-cloud-readiness-properties) is ratified as the conflict-unit page. Update checks and API-key publishing to PM services are **not v1 scope** |
| **10.9** | Generic archetypes forever, or a real-SKU catalog | **ANSWERED 2026-08-03** | **Shipped catalog stays generic; user templates may carry real SKUs.** Archetypes must be editable; DR-015's `.rmda` is the sharing mechanism. `T6.30` stays an equipment list, not a BOM (AC-055) |
| **10.10** | macOS in v1 | **ANSWERED: DR-009** | **(b) Windows and macOS from v1.** **Reverses** the recommendation, which was explicitly not a ruling. The register it demanded is [13-macos-debt-register.md](13-macos-debt-register.md) |
| 10.11 | What the beta gate actually is | **DEFERRED, with a trigger** | Held until M5 lands and the UI is largely frozen. **Must be answered before the M6-J5 recruiting ask**, not before M9 |
| **10.12** | Small calls needing an owner | **ALL SEVEN SETTLED 2026-08-03** | (d) by DR-002. (a) keep 200, make it a setting (#560). (b) autosave while working, never while idle. (c) editable rack presets, **DR-016**, a scope addition under §8.3 (#561). (e) opt-in local crash log only. (f) RackMate, with a mascot and three scoped surfaces (#563–#565). (g) user-visible, and it is 28 rules since DR-020 |
| 10.13 | The three to answer first | **retired** | All three are answered |

They are ordered by blast radius, and the first one was a fork in what the product fundamentally
is, until it was answered.

## 10.1 Draw every wire, or net labels by default: the fork

> **ANSWERED — DR-001: net labels by default.** Drawn wires appear on a domain filter, `Alt`-hover
> or focus. The argument below stands as the record of how the question was reasoned about; **the
> recommendation at the end of this section is void — DR-001 reverses it** (canon §11.1).

**It was the most consequential open question in the project, and not a rendering preference. It
decided what RackMate is.**

- **(A) Draw every wire.** The schematic is a *drawing*: every physical link is a visible
  orthogonal polyline pin to pin, with junction dots, hop arcs, arrowheads and tag pills at both
  ends. The KiCad/AutoCAD idiom; the most literal reading of "takes visual inspiration from
  electronics schematics"; what a client expects when handed a drawing they paid for.
- **(B) Net labels by default.** Every link is a short stub carrying a generated label
  (`HDMI_MTX1_OUT3`); lines are drawn only under a domain filter, on hover, or on focus. The
  Altium/Q-SYS idiom for dense designs; the only thing legible past ~80 connections.

| | (A) Draw every wire | (B) Net labels default |
|---|---|---|
| At 20 connections | Excellent; this is what people picture | Sparse; reads as an unfinished drawing |
| At 150 connections | Unusable without filtering; the density arithmetic is correct and unarguable | Still readable; the label *is* the information |
| "Looks like a schematic" to a client | Yes, unambiguously | To an EE yes; to a homeowner it looks like a parts list with brackets |
| Router cost | Full channel routing, track ordering, crossing sweep, hop arcs, the expensive half of M2 | Layering only; routing becomes nearly free |
| Failure mode | **Silent** (degrades gradually into spaghetti and the user never learns when it stopped being useful | **Loud**) "where are the lines?", and the user learns the filter |
| Reversibility | Adding label mode later is cheap | Adding full routing later is the expensive part of M2 |

**Why it was a fork, not a default.** It propagated into whether M2 is `L` or `M`; whether
multi-sheet is ever needed; whether hop arcs, junction staggering, dash-phase divergence and the
Bentley–Ottmann sweep are built at all; whether the crossing count matters; and what the PDF
diagram sheet *is*. Every one of those consequences has now landed on the (B) side: M2 is `M`,
multi-sheet is never (DR-004), none of the four is built, and the crossing count is not a metric
the plan tracks.

**Recommendation (VOID: overruled by DR-001).** It recommended shipping **(A) as the default with
(B) as automatic degradation above a per-sheet threshold**, on the grounds that first impressions
are made at 20 connections rather than 150. The user took **(B)**, and with it the 4–5 weeks and
the three hardest correctness problems the router carried. Do not re-argue this; apply it. Auto
net-label degradation is not the mechanism, net labels are the default, and no density threshold
switches rendering behind the user's back.

## 10.2 Residential CI or commercial AV: who is the primary customer

> **ANSWERED — DR-002: residential CI primary, commercial capable.** Residential fronts the UI;
> commercial capability ships and never fronts it. This **confirms** the recommendation below
> rather than reversing it (canon §11.2).

**Options.** (a) Residential custom integration, primary. (b) Commercial / conference-room AV,
primary. (c) Both, explicitly, with a mode switch.

**Trade-off.** The corpus is written for (a) (Structure devices, home runs, rooms, TIA-570-D,
credenza racks) while several of its most expensive features are (b) features: NCS sheet
numbering, layers for phased retrofit, TIA-606 rack labels, plenum and Class 2/3 code rules,
issued-for-construction stamps. (c) sounds free and is not: it doubles the vocabulary the user
must navigate, and TIA-570-D grades are a vocabulary residential integrators do not speak
(CR-108). Every "default off for wall racks" and "simple sheet numbering" ruling above is quietly
a bet on (a).

**What tips it.** Where the first ten paying users come from. Also whether the drawings ever go to
a permit office or a GC, if they do, (b)'s drafting apparatus stops being overhead and starts
being the reason the tool is bought.

**Recommendation (not a ruling).** **(a) residential-primary, commercial-capable**, which the
rulings already implicitly assume, so this is mostly a request to make the bet explicit and stop
paying for (b) features by accident. Commercial capability stays present (the code rules, the
ISO/NCS option, the field-device set) but never fronts the UI.

## 10.3 Pricing and licensing model

**Options.** (a) One-time perpetual licence per seat. (b) Annual subscription. (c) Free tier with
watermarked PDF, paid to remove the watermark. (d) Free entirely for now, monetise later.

**Trade-off.** Integrators buy tools the way they buy tools (a purchase order, once) and they
resent subscriptions for desktop software that syncs nothing. But (a) leaves the v1.1/v1.2 work in
§7.3–7.4 unfunded, and the catalog needs continuous authoring. (c) is the classic answer for a
document-producing tool and aligns exactly with G1: the thing people pay for is the artifact. It
carries a specific hazard here, **a watermarked pull sheet is worse than useless in an attic**,
so the watermark must go on client-facing sheets and never on field sheets, which is a product
decision disguised as a pricing one.

**What tips it.** Ask five integrators what they pay for D-Tools, Visio, or their CAD seat, and
whether it was a subscription. Also whether they expense software personally or through the
company, that changes the acceptable price by an order of magnitude.

**Recommendation (not a ruling).** **(c)**, watermark on elevations and diagram sheets only, never
on the pull sheet or termination schedule. It gets the tool into hands, prices the deliverable
rather than the software, and needs none of the licence-enforcement machinery (a) and (b) do.
Affects M8's scope, so it wants deciding **before M6**.

## 10.4 Does the device builder have to be in v1

> **ANSWERED — DR-003: the device builder is in v1; M4 stays where it is.** This **confirms** the
> recommendation below (canon §11.3). M1's miss-rate instrumentation survives, but as
> catalog-coverage evidence for §10.9 rather than as a trigger to reopen this question.

**Options.** (a) Yes, M4 stays where it is. (b) Move it after M6; ship v1 with catalog plus
`DeviceOverrides` only. (c) A reduced builder, duplicate-and-edit an existing template, no
from-scratch authoring.

**Trade-off.** The brief fixed "device builder **plus** a seeded catalog" as confirmed decision 2,
so (b) and (c) are deviations from the brief and need explicit sign-off; that is why this is a
question and not a ruling. Against that: for a 16×16 matrix the right answer is genuinely
"duplicate catalog entry V03 and rename it, 15 seconds", so the builder is a barrier to
**completeness**, not to **adoption**. It buys 4–7 weeks off the critical path at the cost of the
long tail, and the long tail is exactly where a professional discovers the tool cannot represent
their job.

**What tips it.** It is decided; nothing tips it now. **Instrument M1 anyway**: ship the catalog
and count how often users hit a device that is not in it. That number is no longer a scope trigger;
it is catalog-coverage evidence feeding §10.9 and the sizing of the catalog lever.

**Recommendation: CONFIRMED by DR-003.** **(a) keep it in v1.** It is a confirmed decision, and
AC-049's reduction to three required fields (name, RU height, designator prefix) already removed
most of what made it expensive. The earlier caveat, treat the miss rate as a trigger to reopen
this, is withdrawn: DR-003 settles it.

## 10.5 Metric or imperial as the shipped default

**Options.** (a) Imperial default, metric available. (b) Locale-derived. (c) Ask on first run.

**Trade-off.** RU is imperial by definition and the North American residential market thinks in
feet, inches and AWG; the rest of the world does not, and half the equipment depth specs are
published in millimetres regardless. (b) is the obvious engineering answer and is subtly wrong
here: a Canadian integrator's OS locale says metric and their cable footage is in feet. This is
**display only** (CR-001 makes storage exact in either system and units are a separate axis from
locale) so it is cheap to change and cheap to get wrong.

**What tips it.** Where the first users are. If North America, (a) with no further thought.

**Recommendation (not a ruling).** **(a) imperial default, one obvious toggle, mixed units
permitted per-field on input**: typing `450mm` into a depth field set to inches just works.
Because the cost of being wrong is one settings row, this should not consume more attention than
it already has.

## 10.6 Is the schematic a client deliverable or an internal tool

> **ANSWERED — DR-005: client deliverable, invest in drafting polish.** Full sheet furniture ships
> in v1, revision clouds included. **The recommendation below is void — DR-005 reverses it**
> (canon §11.5).
>
> **Drafting polish is orthogonal to wire idiom, and this answer does not reopen §10.1.** The
> trade-off text below originally inferred that (a) argues for (A) in §10.1. **That inference is
> explicitly rejected** by the user and by canon §11.5.1, and it has been removed from the
> trade-off. Its premise — that a client deliverable must survive being read by someone who has
> never read a schematic — is false here: the schematic's reader is technical, being the GC, the
> electrician, the low-voltage sub, and a technically-literate homeowner. Those readers read net
> labels. Polish the sheet fully; keep net labels.

**Options.** (a) Client deliverable, invest in drafting polish, title blocks, revision clouds,
issued-for-construction stamps. (b) Internal working document, the client gets the elevation and
the equipment list; the schematic is how the integrator thinks and how the installer
troubleshoots.

**Trade-off.** This decides how much of the drafting apparatus is worth its cost. Under (b) the
drafting furniture beyond a title block is overhead. Under (a) it is the reason the document can
be handed over at all, and it is bought independently of how wires are drawn inside the frame,
which is §10.1's question and not this one.

**What tips it.** Ask integrators whether they currently give clients a signal-flow drawing at
all. Many do not, the client gets a proposal, an elevation and an invoice. If none of the five
does, (b) is the answer and a meaningful amount of M6 gets simpler.

**Recommendation (VOID: overruled by DR-005).** It recommended **(b) internal-first**, with the
title block and revision block present but no further drafting ceremony until a user asks. The
user asked. G1 is unchanged by the reversal, the schedule is still the deliverable and the drawing
is still the receipt; DR-005 says the receipt is handed to the client, so it must look drafted by
a professional.

## 10.7 Multi-sheet timing

> **ANSWERED — DR-004: never. One `Sheet` plus domain filtering, permanently.** Match lines,
> off-sheet connectors, sheet-boundary link handling and schematic PDF tiling are deleted from the
> plan; so is unit splitting, whose only condition was that multi-sheet land. **The `Sheet` entity
> remains in the schema** (AC-037) so the format never migrates if this is ever reversed.
>
> **CR-073's exporter behaviour is unaffected.** N interconnect sheets `T6.01…` are still emitted
> by partitioning the single `Sheet` at export. Partitioning at export is not multi-sheet
> authoring, and nothing in this answer touches it (canon §11.4).

**Options.** (a) v1.2, as ruled in §7.4. (b) Pull into v1. (c) Never, one sheet plus domain
filtering, permanently.

**Trade-off.** CR-073 already defers it and AC-037 keeps the `Sheet` entity so the format never
migrates, so this was only ever about timing, not architecture. It was downstream of §10.1, which
resolved to **(B) net labels**, and under net labels a whole-house job fits one sheet, which is
what made (c) go from plausible to correct.

**What tipped it.** DR-001. The density argument that made multi-sheet feel inevitable was an
argument about drawn wires, and there are no drawn wires by default.

**Recommendation (SUPERSEDED: the user went further).** It recommended **(a) hold at v1.2** and
re-decide once §10.1 resolved. §10.1 resolved, and the answer was **(c) never**, not v1.2.

## 10.8 How much to invest now in the cloud-ready model

> **ANSWERED 2026-08-03: (a). Spend nothing further; RackMate is a local application.** Confirms
> the recommendation. Three clauses, and the first is the one that gets misread.
>
> 1. **The six cloud-ready properties stay, in full.** *Local only* describes what the app does, not
>    licence to strip the model. Option (c) was never available and is not taken now.
> 2. **[02-data-model.md §8](02-data-model.md#8-cloud-readiness-properties) is RATIFIED** as the
>    conflict-unit and merge-story page the recommendation asked for. It was written before the
>    question was answered, so this ruling adopts a page rather than commissioning one.
> 3. **An update check and API-key publishing to project-management services** are the only
>    contemplated network uses. Both are outbound or advisory, neither is document sync, and
>    **neither is v1 scope**: adding either is a scope addition under roadmap §8.3.
>
> Reopens only if a user asks twice for two people in one project.

**Options.** (a) Keep exactly what is ruled (stable UUIDs, `schemaVersion`, no positional
identity, tombstones, `sequence`) and spend nothing further. (b) Add sync cursor plumbing,
per-entity LWW and a conflict-resolution design now, while the model is small. (c) Drop the
cloud-ready constraint and simplify.

**Trade-off.** (c) is not available, confirmed decision 3. (a) is what §7 rules. (b) is tempting
for the usual reason (the model will never again be this small) and dangerous for the usual one:
sync semantics designed without a real multi-user use case are almost always wrong, and wrong sync
semantics in a shipped format are worse than none. Note that AC-006 already removed per-port
`EntityMeta` on the grounds that device+ports is a single conflict unit, **so some conflict-model
thinking is already baked in and should be written down rather than left folkloric.**

**What tips it.** Whether anyone asks for two people in one project. In this domain that is usually
a designer and a project manager, and the honest answer is often "they take turns".

**Recommendation (not a ruling).** **(a)**, plus **one page in `docs/` stating the intended
conflict unit and merge story**, so AC-006's assumption is recorded. Spend nothing else until a
user asks twice.

## 10.9 Generic archetypes forever, or a real-SKU catalog eventually

**Options.** (a) Generic archetypes only, permanently. (b) Generic in v1, a real-SKU library
later. (c) A community-contributed library.

**Trade-off.** Confirmed decision 2 fixes (a) for v1, so this is a v2 question, worth answering
early because it changes what `.rmdev` and the template library are *for*. Real SKUs are the
single most-requested feature in every tool of this kind and the single largest ongoing cost:
hundreds of manufacturers, constant model churn, and a real legal question about republishing
manufacturer specifications and trademarks. (c) shifts the cost and creates moderation, data
quality and provenance problems, the last directly contradicting AC-052's citation gate.

**What tips it.** Whether users start emailing each other `.rmdev` files unprompted. If they do,
(c) is already happening and the only question is whether it is supported or ignored. Also: what
D-Tools' library is actually worth to the people who pay for it.

**Recommendation (not a ruling).** **(b), with (c) as the mechanism**: a curated community
library where every submission carries the same `sources.md` citation the shipped catalog
requires. That turns AC-052's gate from a cost into the quality bar that makes a community library
trustworthy, which is the thing every community parts library fails at.

## 10.10 macOS in v1

**Options.** (a) Windows only for v1. (b) Windows and macOS from v1.

**Trade-off.** The environment is Windows and the corpus assumes it. The platform work is real but
bounded: notarisation and stapling, file-dialog and menu differences, keyboard idiom (`Cmd` vs
`Ctrl` across ~40 bindings), font availability, and a second print test matrix, call it **3–5
weeks plus ongoing CI**. Against that, a visible slice of high-end residential AV design work
happens on Macs, and a tool that cannot open there is simply invisible to those people.

**What tips it.** Ask the five integrators what is on their design desk. A five-minute question
with a decisive answer, and it should be asked **before M7**, not after.

**Recommendation (not a ruling).** **(a) Windows only for v1**, with the discipline that nothing
in M0–M6 takes a Windows-only dependency without it being written down as a macOS debt item. Add
macOS as the first post-v1 milestone if the desk survey warrants it.

## 10.11 What the beta gate actually is

**Options.** (a) M9's stated criterion, three integrators each produce a sheet set they were
willing to send out, without leaving the app. (b) A metric: N projects, N cables, zero P1 bugs for
N weeks. (c) A date.

**Trade-off.** (a) is a judgement and therefore gameable and unschedulable, which is exactly the
objection to it, and it is still the right one, because every metric available at this stage
measures the tool's internal consistency rather than its usefulness. (c) ships something on a day
regardless of whether it works. (b) is the compromise and tends to measure whichever thing was
easiest to count.

**What tips it.** Whether there is external pressure, an investor, a launch date, a paying
customer waiting. If there is, (b) or (c) is going to happen whether or not it is chosen.

**Recommendation (not a ruling).** **(a), with (b) as a floor**: the judgement gate governs, and
the metric exists only to prevent shipping something that passes the judgement gate for three
friendly users and falls over on the fourth.

## 10.12 Small calls that need an owner, not an essay: ALL SEVEN SETTLED

> **ANSWERED 2026-08-03, all seven.** This table showed recommendations until then. **Three of the
> seven answers did not confirm the recommendation** and are marked, because a reader skimming the
> old column would have got them wrong: (b) revised, (c) superseded, (f) overruled.

| # | Question | Answer | Where |
|---|---|---|---|
| a | Undo depth: the cap is 200 with a status-bar signal (AC-058 D5). Is 200 right? | **Keep 200, and make it a setting.** Confirms the recommendation. The cap is already 200 (`undo_stack.dart`'s `maxEntries`) but is a **constructor parameter, not a user setting**; exposing it is owed work | Board #560 |
| b | Autosave interval, and whether recovery is silent or prompted | **REVISES the recommendation: autosave runs while the user is WORKING, never while they are idle.** The 30 s interval stands; a tick with nothing new to protect must write nothing. This **exposed a live defect**, since fixed. **The prompt-on-recovery half is unchanged** | `be23d89` |
| c | Default rack height in the new-rack dialog | **SUPERSEDES the recommendation: the starting racks become EDITABLE PRESETS.** 42U survives as the shipped seed, so the recommendation's substance lives on; what changes is that the preset set stops being fixed. A **scope addition under roadmap §8.3**, ruled as **DR-016** | Board #561 |
| d | Are the four starter projects residential-only? | **Three residential, one small commercial.** Settled by implication of DR-002; they double as the domain-coverage argument for residential-primary, commercial-capable | DR-002 |
| e | Telemetry at all, and if so opt-in or opt-out | **Opt-in, local crash log only. Telemetry is POST-v1.** Confirms the recommendation. Accepted consequence: §10.4's miss-rate instrumentation is a manual user-interview exercise, not a dashboard | CR-096 |
| f | Product name and branding investment | **OVERRULES the recommendation to defer.** The name is **RackMate**. Branding is a Protogen mascot, **Riley the RackMate**, in neutral warm white and greys so it never competes with the eight domain hues. Three surfaces follow and **they are scope, not styling**: an opt-in in-app assistant, a first-run onboarding flow, and user-customisable UI accent colours. RJ-017 rejected branding as a v1 *requirement* and is not reversed; this schedules the work | Board #563–#565 |
| g | Is [the rule catalogue](02-data-model.md#5-the-v1-validation-rule-catalogue--three-tiers) user-visible documentation or internal? | **User-visible, in-app, linked from every finding.** Confirms the recommendation. **The file deliberately does not exist**: canon §5 *is* the catalogue and CR-021 says so, so this is *publish that section*, not *write a new file*. And it is **28** rules since DR-020, not the 22 this row inherited from AC-040's arithmetic slip | Feeds M5-F3 |

## 10.13 The three to answer first: RETIRED

**All three are answered: §10.1 by DR-001, §10.2 by DR-002, §10.4 by DR-003.** This section has
served its purpose and carries no remaining instruction. Everything still open can wait until
there is evidence, which is the entire point of shipping M1 as a real release rather than as a
foundation.
