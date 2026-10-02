# Architecture Decision Record

**This file is not the normative record.** The normative record is
[docs/canonical-decisions.md](canonical-decisions.md), 120 `CR-nnn`, 59 `AC-nnn`, 17 `RJ-nnn`,
canonical naming, the model, the registry, the scope ruling, the milestone plan, and Part 4's
binding user decisions, now `DR-001` to `DR-110`. This file is a sixteen-ADR summary of it. Where
an ADR and a ruling appear to differ, the ruling wins and this file is wrong.

**THE COUNTS IN THIS PARAGRAPH ARE THE KIND THAT GO STALE**, and two of them had. It read
`DR-001`–`DR-023` while canon held 107, and the next paragraph promised thirty-six user
decisions against a table that stopped at DR-036 and a body that writes out five. Counts in
prose are a liability this corpus has swept five times; these are stated once, here, and the
index below is what to trust.

What follows is the short-form decision log for RackPal: sixteen ADRs covering the choices that
shape the codebase, each traced back to its adjudication in the canonical decision record; then
**the user decisions `DR-001` to `DR-121`**, which are binding and override the recommendations
they answer, five of them written out in full below and the rest indexed; then the questions of canon §10, **none of which is open any longer**: ten are
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
| [011](#adr-011-state-management-riverpod-over-a-single-mutation-gate) | State management | **Superseded by DR-088** | CR-119, AC-016 (#19), AC-013 |
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
| DR-021 | **Deleting a `Location` cascades the subtree and clears every reference** | — | The first ruling the location tree has raised, which until now had no delete semantics at all. The subtree goes in one undoable command; **promotion is rejected** because it rewrites the breadcrumb of every surviving room without an edit, and refusal is rejected on DR-013 §11.13.3's ground. **Nine fields across seven entities** (ten across eight since DR-185, §12.37) point at a location from outside the tree, and every one is cleared to null (G4's unknown) rather than left dangling, so a cleared drop lands in the Pull Sheet's `NO ROOM RECORDED` band instead of vanishing. The count is computed once and consumed by the command, DR-013 §11.13.2's shape. A reparent that would make a node its own ancestor is **refused** the way `TOP-005` refuses a shelf cycle. No `Link`, `Outlet`, `Pathway` or drop is deleted. **No scope change.** Board #144, #145 |
| DR-022 | **`{SERVICE}` in a drop's field label is the outlet template's tag** | — | Measured, not argued: the shipped `Residential CI` preset `{ROOM_ABBR}-{SERVICE}-{SEQ}` has no `[...]` around any token, so it **throws on a rough-in drop**: the state docs/07 §4.1 calls *"first-class, encouraged"*. The corpus's own examples settle the source: `LR-TV-1`, `MBR-KEY-2`, `EXT-CAM-4` are the **TV location / Keypad / Camera** templates, not signal families. `OutletTemplate` gains a `tag`; **not a migration**, because `outletTemplates` is `{}` in all four shipped starters, which is DR-019's `Placement.unknown` argument on a smaller surface. The family `shortTag` route is rejected because CR-048 stores a designator once, so every rough-in label would read `STR` forever. The **rack label needed no ruling**: it is optional (CR-044), so AC-018's fourteen unbound drops simply have none. Amends board #150 to a one-field model change; resequences #152 before #147. **No scope change** |
| DR-023 | **The `{SERVICE}` fallback chain: modifier, then template tag, then the media's short tag** | — | The question DR-022 §11.21.6 handed to #147. Three steps and no fourth: the line's `@service=`, else the `OutletTemplate.tag` DR-022 settled, else `MediaTypeDef.shortTag`. **`@service=` outranks the template** because CR-048 stores a designator once at creation, so a label that cannot be overridden at entry can only be fixed by deleting the drop, and a sixty-drop drill cannot afford that; the accepted cost is a drop whose label may disagree with its own outlet's template. **The media tag is not the `STR` answer DR-022 rejected**: `STR` was rejected for being one placeholder word identical on every rough-in cable, and `C6`/`RG6`/`16/4` vary per drop and are facts the line stated. Refusing instead would refuse docs/07 §4.3's own first worked example and fight §4.1's *"first-class, encouraged"* undetermined state. A user-created media type with no `shortTag` (RJ-009 import) **refuses** rather than printing a raw id. Deliberately does **not** rule whether `@service=` also sets `Service.signalFamily`. **No scope change** |
| DR-024 | **Board #151 is a model field and a picker; its data half already shipped** | — | A **task re-scope**, ruled because #150 closed over half of #151 without either being wrong. #151 asked for the TIA-570-D presets and said why they are not decoration: *"Grade is a CITATION, not a suggestion."* All three shipped at `5abb8b3`, transcribed from docs/07 §1 with the source named **including the part that reads oddly** (Grade 3 is given a lower twisted-pair grade and fewer coax than Grade 2, which is flagged for docs/07 rather than corrected in code). What is left is `OutletTemplate.tia570Grade: String?`, because CR-108 keeps the grade a **tag, never an axis**, and a preset today cannot stamp the one field it exists to carry. **A builder special case on the three seeded ids is rejected**: it would key the behaviour to a string, so a user-authored preset (the first-class thing CR-108 protects) could never stamp anything, and an id rename would be a silent behaviour change. **Not a migration and CR-117 holds**: the key is absent when null, so the six named templates re-encode byte for byte. The picker is **`+ Add outlet ▾`** (docs/07 §4.3), which no task claimed, and it is the **first caller of DR-023 step 2**, an arm nothing could reach because nothing created an outlet *from* a template. Does not rule the template **library flow**, nor AC-034/m24's template-driven inspector fields. **No scope change** |
| DR-025 | **`@service=` names the label, `@signal=` names the family; they are two words** | — | The question #587 raised while #149 closed: a structured run's `Service.signalFamily` is `structure.undetermined` **forever**, because `buildAddHomeRunCommand` hardcodes it and nothing writes it afterwards, so docs/07 §4's wireframe draws a SERVICE column of values no gesture can produce. The corpus pointed two ways: §5.1's import table maps a `service` column to `SignalFamilyId`, where DR-023 resolves `@service=` through an `OutletTemplate`. **Decided by the user's own job shape**: *"one AVoIP system for most areas, but a simple HDBT transmitter/receiver pair for say, running from an AVR to a projector"*. `video.avoip` and `video.hdbaset` are the same domain, same `conn.rj45`, same Cat6, and differ in topology, so a house has runs with the same label and different families and vice versa. **The decisive form**: `video.hdbaset` excludes `net.ethernet` from `acceptedFamilies` because 100 W PoH into a switch damages it, which is `SIG-001`, *"the highest-value validation in the product"*. If the label token set the family, choosing a label would decide whether that check fires. The modifier is **`@signal=`** because §5.1 already lists `signal` for this column; it resolves by `shortTag`, id tail, then `displayName`, and **refuses** an unknown value, since §3 keeps signal families catalog-updated where RJ-012 makes media user-extensible. A CSV **`Use` column feeds the label chain and never the family**, because real pull lists put `TV`/`Data`/`Camera` there; §5.1's synonym row splits and is the one derived edit this forces. The default is untouched: a drop is still created `structure.undetermined` and a template's `service` is still never copied. **Both copies or neither**: the family is stored on the `Service` and on the `Net`, and only the first is consumed. **No scope change**; unblocks M3-F |
| DR-026 | **Two M3 answers taken as interim positions, because the Plan view may move them** | — | Answers #157 and #153 together: DR-018 put the Plan view in v1.1 and a floorplan speaks to both, so each is settled for **reversibility** rather than permanently. **`Pathway.designator` exists and is MANUALLY ENTERED**, on the user's reason that *"once a trunk line is established in the home, it would be nice to know exactly where it is relative to the plans"*. That is **DR-020's own distinction applied to pathways**: the route is discovered, not designed, so a trunk already established is an as-built fact, where a generated designator would be the voided design-time polyline in a shorter form. `String? designator`, null unknown, **no allocator and no series**, unique where set on CR-113's `rackLabel` precedent. **Manual is the reversible direction and generated is not**: a nullable hand-entered string can later gain an allocator, an allocated series cannot become manual without abandoning the uniqueness it assumed. #157's feared cost is **not incurred**, since a key written only when present moves neither CR-117's byte gate nor `kSchemaVersion` (`tia570Grade`'s precedent). **`Pathway.name` is not overloaded** even though its own doc comment shows `"B03"`, because every other entity carries a name and an identifier separately. Second half: **`Outlet.nominalRunLength` is ratified AS IMPLEMENTED**, provisionally. #153 says to rule *"before anything reads it"* and **that deadline has passed**: `ScheduleLengthSource` ships four tiers with `outletNominal` second, and `whole_house` sets it on all seventeen outlets with `cutLength` on none. The Plan view is the named trigger to revisit. **No scope change**; unblocks M3-E/2 and M3-D/2 |
| DR-027 | **M3 owes the Pull Sheet's rows and its sort; M6 owns every rendered sheet** | — | Ratifies #155's proposed seam on the user's reason that *"M6 is where sheets are going to be rendered and I'd like to work those issues out all at once"*. `SheetRole` has three values and none is a Pull Sheet, while M3's exit criterion says a rough-in *exports* one, so one of the two had to give. **M3 owes the derivation** (rows, sort by room then pathway, per-room footage subtotals, as tested `rackpal_core` output); **M6 owes the sheet** (the role, the layout, the initial boxes, the page). **This AMENDS AN EXIT CRITERION**, which is why it is a ruling: §8.1 makes the criterion the unit of truth, so M3's clause 3 splits and M6 demonstrates the export. M6's own criterion needs no addition, since *"export a complete set"* already contains the sheet. It tidies a second clause rather than creating one: #574 already parks AC-018's PRINTS clause on M6 for the identical reason. **What M3 still owes is stated** so this is not read as a deferral, since an unordered untotalled structure would hand M6 the design work too. **Milestone-boundary amendment, no change to roadmap §2's contents**; unblocks M3-D/4 |
| DR-028 | **The keystone occupant cell is the FRONT NOSE, 14.5 mm × 16 mm** | — | Supplies the figure DR-007 does not give and #167 refuses to infer. The cell is **14.5 × 16 mm** and it is the **front nose**, the visible bezel face, not the body or the depth: §11.7.9 B already rules that *"the cell renders from the front, and the front hides the differences"*, so the face is what the renderer draws and the face is what is stored. **CORRECTED THE SAME DAY, and the correction is the entry's point.** The first draft recorded **15 × 16** from a range midpoint and on that basis SUPERSEDED §11.7.8's unruled *"about 14.5 × 16.0 mm"*; the user then corrected their own figure to 14.5, so **the supersession is withdrawn** and the two now corroborate. The lesson is kept: the supersession was argued from the newer figure being *"the one a person stated deliberately"*, and deliberateness was the wrong test, because **an unruled figure with provenance outranks a ruled figure without one**. Stored as `Len` nanometres per CR-001, `14_500_000` and `16_000_000`; a half-millimetre is exact in nanometres and a binary fraction in millimetres, which is the first place that invariant pays visibly. **It does NOT settle §11.7.8's change 3**, whether a cell on a 2-wide strap equals one on a 1-wide strap, which DR-007 requires be measured **before any dimensioned rendering**. **No scope change**; unblocks M3-H/2 |
| DR-029 | **The Plan view ships in v1, before M6, with PDF rasterisation** | — | A **scope amendment under §8.3, and the first that makes v1 LARGER**. The user: *"development has been exceptionally fast and I feel like it's an important feature to have."* Supersedes DR-018 point by point: v1.1 becomes v1, the conditional placement is moot (DR-019 discharged it), *"nothing is added to v1"* and *"no board item"* both fall. **§11.17.2(4) is REAFFIRMED**: it does not displace M3 and no M3 task is cut. **BEFORE M6 IS STRUCTURAL, NOT A PREFERENCE**: the feature includes a plan sheet and M6's criterion is that all four starters export a **complete** set, so a later arrival would make M6 run twice over a set about to gain a sheet, and DR-027 put the Pull Sheet in M6 the same day. **An epic, not a milestone number**, because renumbering M6→M10 would rewrite every `M6-A1`-shaped title, docs/12 §5.3–§5.8, §12.7 and dozens of canon references; the board already carries two non-numbered v1 epics (DR-009's macOS, the Store). **PDF rasterisation is bought deliberately** at 2–3 weeks over raster-only, because architects send PDFs, and it triggers the docs/13 entry DR-018 §11.17.4 predicted, likely pdfium alongside D9. **`DiagramCanvas` gains a `drawImage` op in v1** and RJ-017's §12 row is amended, though **the integrator's logo is NOT collected as a side effect**. G4 untouched: a plan yields a horizontal distance, never a route (DR-020). Mobile stays v2 and **this does not reach the tablet workflow**. DR-026's two provisional M3 positions now have a scheduled trigger. **§12.7 re-costed: 44–67 → 53–80 weeks**, and M1, M4 and the Plan view are the three `L` items where §12.7 named two |
| DR-030 | **The integrator's logo ships in v1, in M6, without its opacity** | — | The user: *"Let's add the logo in; likely during M6. If it's cheap we may as well."* Reverses the one clause **RJ-017** rejected. Two of RJ-017's three grounds fell: the raster-asset-reopens-the-container objection is gone (DR-019 settled it, DR-029 builds it) and *"lands with the v2 zip container"* arrived early. **The third STANDS and shapes the ruling**: the title block's TEXT block carries the same information, so the logo is added **beside** it and never instead of it, because a photocopy at third generation still carries a licence number and may not carry a logo. **CHEAP AS ARITHMETIC, NOT AS AN IMPRESSION**: it is the fourth consumer of three things DR-029 already builds (zip container, `drawImage` on `DiagramCanvas`, raster embedding in the PDF backend), so **if the Plan view slips, this slips with it**. **THE OPACITY DOES NOT RETURN**: docs/08 row 9 forbids alpha "absolutely, with no exception" and named the logo-opacity path as its sole former exception, so the logo comes back at full opacity, no `ExtGState` is ever emitted, and a faded logo means a faded PNG. Lands beside #343 (M6-G2, the title block); no new sequencing, because DR-029 already puts the Plan view before M6. Owes a model field, a **fit rule** (aspect preserved, never stretched), import hardening under M4-M4, and a place in the print matrix (AC-058 D13). **Does NOT return device images** (AC-057 cut those on a separate file-size argument) and does not make a logo required. **No milestone moves and §12.7 is not re-costed**, recorded as a judgement rather than a measurement |
| DR-031 | **`PathwayKind` gains `attic` and `crawlspace`** | — | Discharges **DR-020 §11.19.4**, which left the question open and dated it *"Owed at M3, when `Pathway` gets its editor"*. M3-E is that editor. The enum becomes **nine values**. **The objection was that both are spaces and the Location tree already models spaces; it does, and that is a different fact**: `Location` models where a room IS, `Pathway.kind` models what a cable PASSES THROUGH, and a run from the rack to a bedroom crosses an attic that is nobody's room, belongs to no room's subtree, and would have to be invented as a `Location` purely to be pointed at. `fromLocationId` and `toLocationId` are endpoints, so a space in the middle has no field to live in. **What the field carries is the CONSEQUENCE**, which is what makes these the same kind of value as `plenumSpace`: attic obliges temperature derating and rodent exposure, crawlspace obliges moisture and vermin. **It adds NO rule**: the catalogue stays at 28, `CODE-001` and `CODE-002` are unchanged and remain M5's, and an attic run is never an error (G2). Cheap because `PathwayKind` is **not seeded catalog data**: a Dart enum serialised by name, no registry row, no `sources.md` entry, no palette. **Settled before the editor ships on purpose**, so no document records `conduit` for a run its author would have called `attic`. Does not make the kind required, does not add `Location` kinds, and does not touch AC-040's ~40 deferred length rules |
| DR-032 | **A pathway-only medium creates a `Pathway` named for where it goes** | — | CR-109 rules that `isPathwayOnly` media create a `Pathway` "never a `Link` and never a `Port`" and never says what it is CALLED, while `Pathway.name` is required. `Living Room: 1x ENT` produces a pathway named **`Living Room ENT`**, `kind` takes its `conduit` default, and **`designator` stays null**. One pathway **per unit of the count**, since two smurf tubes are two entities and a `Pathway` has no quantity field; where the count exceeds one the names carry a 1-based index, which is a description that restarts per line and not a document-wide series. **THE DERIVED IDENTIFIER IS THE TRAP AND IS REFUSED**: `PW-LR-1` matches docs/07 §4's wireframe and is exactly what **DR-026 §11.25.1** rejected, which made the designator hand-entered with "no allocator and no series" because manual is the reversible direction. A name minted at creation would be that series wearing the one field DR-026 left alone; a description cannot be mistaken for an identifier, so the two facts stay two facts. **The medium's own name alone was rejected** for breaking the `PATH` column: two conduits to two rooms would print identical cells, and telling one route from another is that column's whole job. **All three entry surfaces do it** (drop line, matrix, CSV), because one medium must not mean two things depending on which box it was typed into. Sets no `containsLineVoltage`, makes no pathway required, and does not settle whether the Plan view OWNS pathway creation. No scope change, but **a behaviour change to a shipped gesture**: `Office: 1x ENT` made a `Link` before it and makes a `Pathway` after |
| DR-033 | **A device is submitted to the community catalog as a pull request the app opens itself** | §10.9 | Discharges **§10.9's** unruled recommendation, *"(b), with (c) as the mechanism: a curated community library where every submission carries the same citation the shipped catalog requires"*. A **second repository** holds the library as one `.rmdx` per device, because **DR-002** binds the seed to generic archetypes and **AC-052** requires cited provenance for it, so a real SKU cannot land in `catalog_audio.dart`. A `Submit to community catalog` toolbar action opens a **review sheet** showing the exact JSON, the citation and the sign-in state, chosen over a save-flow prompt because the failure being prevented is a template carrying a client's name becoming public. **TWO CLAUSES WERE CORRECTED AGAINST VERIFICATION RATHER THAN TAKEN AS ASKED.** Google OAuth cannot open a pull request, a pull request being an operation against a GitHub identity; honouring it literally buys a hosted broker holding a GitHub App key and pull requests authored by a robot. **The embedded "restricted app token" that would have avoided that broker does not survive either**: GitHub documents that a public client cannot secure a client secret because it ships in the application's code, and their secret scanning revokes GitHub tokens found in public repositories. The direct REST call the user wanted survives intact as **authorization code with PKCE**, which needs no secret and is GitHub's own preference over the device flow, the latter having no redirect URI and being phishable. `submittedBy` is **a credit, not a signature**: never read by the application, so **AC-042** stays deleted; handle and numeric id are two fields because a GitHub login is renameable and a freed one claimable, which is **DR-026's** two-facts discipline. The citation is **a photograph of the ports**, blocking submit, travelling with the pull request and never in the `.rmdx` (**AC-057**), since GitHub has no documented API for attaching an image to a pull request body. **The FIELD ships in v1 ahead of its surface**, because `_encodeTemplateBody` has no `unknown` passthrough and a v1 build would drop the credit on save (**DR-019's** argument). Scope addition under §8.3; **the surface is conditional** on a release posture §11.32.7 declines to rule |
| DR-034 | **The community library is fetched as an `.rmda` release asset, never cloned** | — | DR-033's **read** path: one feature, two directions, ruled apart because they fail differently. **"Clone" does not survive the platform**: Flutter desktop has no git, so it means vendoring libgit2 or shelling out to a binary absent from an integrator's site laptop, a native dependency on both platforms to fetch some JSON, and it drags every revision of every device to deliver the current one. **The deciding reason is that the format is already ruled and unbuilt**: **DR-015's** `.rmda` is the library pack whose codec, directory service and palette filter M4 owes anyway, so HTTPS instead of email changes the transport and nothing else; a tarball of loose `.rmdx` would be a second on-disk shape carried forever. **The user took the bundled snapshot AND the opt-in card rather than choosing, and that is the better answer**: the bundle is a floor and the fetch is a ceiling. Bundling alone ties library freshness to the app's release cadence, the exact coupling release tags exist to break; fetching alone means a first launch with no wifi shows an empty library, and since the seed is generic archetypes (**DR-002**) the user who most needs a real SKU is the one standing in a mechanical room. Update check is `releases/latest`, unauthenticated, **at most once per 24 h**, behind a **non-modal** notice. **NOT RJ-014's auto-updater**: nothing updates the application, no code is fetched, templates are inert data, and the call is the version-check ping RJ-014 explicitly permitted. **§11.33.5 is a determinism gate, not a preference**: a golden resolving a template out of a fetched library depends on a release tag and has stopped being a golden, so seed and community library are separate resolution scopes and a test says so. **A download is an import**: AC-058/D8 limits and `contentHash` verification apply, the network being no more trusted than the disk. Obliges the catalog repo to actually cut releases. Scope addition under §8.3, sharing DR-033's precondition |
| DR-035 | **A created `Pathway` records the medium it is and the room it serves** | — | DR-032 ruled what such a pathway is CALLED and §11.31.6 mentions neither field, which was invisible while one surface created pathways. **The forcing case is a broken control**: docs/07 §4.2's matrix cell is a COUNT, so it must find "the pathways in this room, of this medium", and a DR-032 pathway recorded neither: the cell would accept a number and read back `0` forever. So creation sets `pathwayMedia` and `fromLocationId`; `toLocationId` **stays null**, which is UNKNOWN and not empty (G4), because a run to the rack is a guess about a rack this project may not hold. **`from` is the room, and the orientation is being set for the first time**: both fields shipped at M0 with no reader establishing an order, and the only writer, `RemoveLocationCommand`, treats them symmetrically. docs/08 §3.2 reads every schedule row `FROM — ROOM` then `TO — RACK` and `ScheduleEntry.roomId` already relies on it, so this is the product's existing convention rather than a new one. **Rejected: the installer's own phrasing** ("conduit runs from the panel to the bedroom"), which loses on cost, since the same physical run would read `FROM = room` on its cable rows and `TO = room` on its pathway, one table apart. **The drop line is retrofitted in the same change**, because §11.31.5 requires one medium not to mean two things depending on which box a person typed it into. `+ Add pathway` sets neither and that is not an inconsistency: a button press names no room and no medium, and inventing them is what §11.31.2 refused one field over. No scope change; a behaviour change to a shipped gesture on §11.31.7's terms |
| DR-036 | **RackPal is a public GPLv3 project, the catalog is CC0, and nothing is priced** | §10.3 | The ruling **DR-033 §11.32.7 declined to make and named as its precondition**, now discharged. Five clauses: RackPal is a **public project**, reversing DR-006's *"no commercial release is planned"* as a statement about distribution; the application code is **GPLv3-or-later**; the community catalog is **CC0 1.0**; contributions arrive under a **DCO sign-off** rather than a CLA; and **nothing is priced**. **THE DEPENDENCY CENSUS WAS MEASURED, NOT RECALLED**, by reading LICENSE files in the pub cache: every dependency is permissive, and `pdf` being **Apache-2.0 closes GPLv2 permanently** because Apache's patent-termination and indemnity terms are additional restrictions under v2 and are accommodated by v3. The SIL OFL fonts AC-058/D7 speaks of are **not bundled yet**, so that obligation is future. **THE CATALOG IS NOT COPYLEFT, AND THAT IS THE CLAUSE THAT WOULD HAVE BEEN GOT WRONG.** Copy-on-place (**AC-041**) embeds a full `TemplateSnapshot` so a `.rmpj` is self-contained, so a copyleft catalog would put catalog-derived content in **every project file an integrator sends a client** and hand professional users a licensing question about their own deliverables. CC0 removes the question rather than answering it, and is the honest description of content that is largely uncopyrightable fact. Attribution survives in the pull request history and in `submittedBy`, a credit and never a licence term. **THE SEED HAS THE SAME PROBLEM AND CC0 DOES NOT REACH IT**, since the seeded catalog is Dart source and therefore GPLv3 as code, so the licence carries an explicit **output exception** in the manner of GCC's runtime library exception: a document RackPal produces is the user's own work and is not a derivative, seeded snapshots and exported sheets included, **stated in LICENSE and README rather than inferred**. **DR-006's OWN FALLBACK FIRES ON SCHEDULE**: it named Microsoft Trusted Signing *"if external distribution is ever required, adoptable at M8, with no earlier milestone needing to anticipate it"*, and the promise holds, **no milestone before M8 moves**. §11.6.1's finding that the two-milestone lead time was OV/EV-specific is untouched. **§10.3 reopened exactly as its own row warned it would** and is answered: no fee, no tier, no gate. **The watermark hazard is answered by never building one**, DR-005 having made the sheet set a client deliverable that cannot be stamped. AC-058/D7 shrinks a second time, permanently rather than pending, and grows by one, GPLv3 must register via `LicenseRegistry`. **The DCO's accepted cost is that clause 2 is near-irreversible**: without a CLA the code licence cannot change without every contributor's consent. **Neither licence grants the name**: RackPal and Riley the RackPal are trademarks (§10.12(f)) and a fork takes the code and not the mascot. No milestone moves and roadmap §2 gains nothing; licensing is not a feature. Does not rule the date the repo goes public, the forge, or governance |

## DR-037 to DR-121, indexed rather than summarised

**The table above stops at DR-036, and canon holds 117.** For seventy-one
rulings this file said nothing at all, while its own header claimed to cover
*"the thirty-six user decisions"*. The gap opened because the summary was
maintained by hand and the record was not: nothing enforces the two agreeing,
and nothing detected seventy-one absences.

**These rows carry each ruling's OWN TITLE, verbatim from its canon heading,
and no paraphrase.** That is deliberate rather than lazy. Summarising
seventy-one rulings by hand is seventy-one chances to write a plausible
sentence that misstates one, and a wrong summary in a file people consult
BEFORE the record is worse than no summary at all: it is the exact shape this
corpus has had to withdraw claims over. A title cannot misstate its own
ruling.

So this index answers one question, *"which ruling do I want and where is
it"*, and refers every other question to canon §11. The rows above keep their
fuller treatment; nothing here replaces them.

| DR | Ruling, in its own words | Where |
|---|---|---|
| DR-037 | The Plan view's exit criterion, and the four questions decomposition had to answer first | canon §11.36 |
| DR-038 | The cell is uniform across strap widths, measured; §11.7.8's change 3 is discharged | canon §11.37 |
| DR-039 | Project history: an in-file journal, an operation panel, and snapshots, in that order | canon §11.38 |
| DR-040 | A drop lands on a panel port; `@panel=` is the gesture and the rack label is allocated | canon §11.39 |
| DR-041 | The plate opening and the two cell pitches, measured; §11.7.8's last "about" is discharged | canon §11.40 |
| DR-042 | The plate outline and the gang pitch, measured; DR-041's last two hedges are discharged | canon §11.41 |
| DR-043 | The field termination gets three entry paths; the default stays Unspecified | canon §11.42 |
| DR-044 | The shipped templates carry terminations, and a euroblock occupies no cell | canon §11.43 |
| DR-045 | The field-crimped RJ45 plug, and an outlet that needs no plate | canon §11.44 |
| DR-046 | The rack end is its own termination, and nothing infers it | canon §11.45 |
| DR-047 | A gang can be fitted with a pass-through, and the plate follows from what is in it | canon §11.46 |
| DR-048 | A network value is a dated as-built fact, and `T6.50` ships in v1 | canon §11.47 |
| DR-049 | The tabular exports ship in v1: rows out, and a label sheet that is not a sheet | canon §11.48 |
| DR-050 | **Plan geometry fills the room estimate that already exists, and it buys cable.** **Its "no new tier" is scoped to ROOM GEOMETRY** and does not abolish `planLowerBound`, which its own §11.49.4 preserves by name: DR-147 §11.146.7. **Built as `LEN-A`, 2026-09-11, and §11.49.5 mis-priced it.** That clause says the work lands with the Plan view *"which is where the vertices and the calibration live"*; the calibration lived there and **a census found no polygon, no outline and no room geometry of any kind**. Six items rather than two, and the one nobody had noticed is that `estimatedRunLengthFromRack` had **no editor anywhere** since M3-D, so AC-024's one number per room was the only one of its three a person could not enter (§11.49.5a). The ceiling height that clause left open is already `riseAllowance`. **§11.49.6 rules the formula and the datum**: the farthest corner of a closed polygon plus the rise, measured from **the rack this room's runs land in**, which is DR-147 §11.146.2 transferred in substance because `estimatedRunLengthFromRack` is read PER RUN in the length ladder, so nothing consumes the estimate until a run exists and a run names its own rack. **Two head ends take the LARGER figure rather than refusing**, because `_isQuantity` is false for `planLowerBound` and `none`, so a refused estimate buys ZERO WIRE in the takeoff and the trade quotes several hundred feet over actual. No margin is folded in: DR-020's `routingFactor` stays deleted. **§11.49.7**: the auto-fill may replace the software's own guess and never a person, and an unrecorded origin counts as a person's (G4). **§11.49.8**: the marker reads on the room row and as `computedEstimateCount` beside `estimatedCount`, a SUBSET of it unlike `boundCount` which is disjoint. **§11.49.9**: the outline does NOT print on `T1.01`, settled without the print run the chapter demanded because **almost every floorplan already labels its rooms**, so the architect's own titles say which space is which and a boundary of ours would spend ink on a fact the sheet already carries; `buildPlanScene` grows no parameter and the four byte-verified starter goldens stay shut. **§11.49.10**: a finished corner drags only in a MODE, which takes the whole canvas while it runs, because a pin and a corner are both points and a live handle makes one of the two unreachable, and because a stray drag would silently move a figure somebody is about to quote. One command per drag, and the Edit menu names a reshape only because the transaction's label is passed explicitly (`#866`) | canon §11.49 |
| DR-051 | Documentation is referenced and never embedded | canon §11.50 |
| DR-052 | Git sync is v1.2 and gated on evidence; live collaboration is never | canon §11.51 |
| DR-053 | The typed line and the CSV agree on what identifies an outlet and a room | canon §11.52 |
| DR-054 | The `PORT` column prints the number on the part | canon §11.53 |
| DR-055 | The Termination Schedule prints both ends, because it already prints both ends of everything else | canon §11.54 |
| DR-056 | `Generic` is the trade's word for unspecified, so the builder pre-fills it | canon §11.55 |
| DR-057 | Connector pitch is a refinement, not a prerequisite, and stays sparse | canon §11.56 |
| DR-058 | A fork whose source cannot be seen is silent on the device and counted in the rollup | canon §11.57 |
| DR-059 | The device glyph ships, because `accentColor` alone is hue alone | canon §11.58 |
| DR-060 | Quick Add resolves family-first, because the family already names its connector | canon §11.59 |
| DR-061 | The port grid's selection is a row range and a focused column, and the tick box is that selection | canon §11.60 |
| DR-062 | Fill series infers its sequence from the top selected cell, because there is no stored pattern to re-apply | canon §11.61 |
| DR-063 | A disagreement is not an unknown, and the identity columns are not batch-editable | canon §11.62 |
| DR-064 | The reorder is within a band, and the index generator gets its missing character | canon §11.63 |
| DR-065 | A sort is a way of looking, and four things follow from saying so | canon §11.64 |
| DR-066 | The viewport is a way of looking: framed on arrival, remembered on return | canon §11.65 |
| DR-067 | A class you can assert, and a classifier you can hear disagree | canon §11.66 |
| DR-068 | Either end of a run may land on a device, because a speaker run is one cable | canon §11.67 |
| DR-069 | Whose binding posts are they? The plate's, or the speaker's | canon §11.68 |
| DR-070 | A run may come out of no box, and "there is none" is not "nobody has said" | canon §11.69 |
| DR-071 | Landing a drop is a gesture, and the product picks the hole | canon §11.70 |
| DR-072 | The sheet counts the runs nobody landed, and only the end that is a job | canon §11.71 |
| DR-073 | Finishing a run is not making a cable, and the sheet now knows the difference | canon §11.72 |
| DR-074 | A drop punched into the wrong port can be moved, and the label follows the hole | canon §11.73 |
| DR-075 | A rack label somebody imported is a rack label somebody typed | canon §11.74 |
| DR-076 | The schematic rebuilds what changed, and the epochs already say what that is | canon §11.75 |
| DR-077 | A template authored in this project reaches the rack, and the palette says where it came from | canon §11.76 |
| DR-078 | The five grid operations, and what a bulk write shows before it fires | canon §11.77 |
| DR-079 | A listing is not a material, and three code rules stop overstating what they know | canon §11.78 |
| DR-080 | The accent colour reaches the elevation, and the text colour follows it | canon §11.79 |
| DR-081 | Three unreachable port fields get a cell, and the rule that would read one is M5's | canon §11.80 |
| DR-082 | `parity` and `flowControl` are closed sets, and the corpus can now say so | canon §11.81 |
| DR-083 | The mark rides the designator line, and it wins over a hatch | canon §11.82 |
| DR-084 | The seeded catalog authors its own marks, so seventeen does not ship as nine | canon §11.83 |
| DR-085 | Mirror bank, and the two models with a reader and no writer | canon §11.84 |
| DR-086 | The port set gets its producer, and the role column stops being free text | canon §11.85 |
| DR-087 | The passthrough pair gets its creator, and the LIU that cannot be paired | canon §11.86 |
| DR-088 | State management is constructor injection and hand-rolled Listenables, and the dependency table gets a gate | canon §11.87 |
| DR-089 | The wordmark is Nasalization, shipped as outlines, and the licence is what forbids the obvious implementation | canon §11.88 |
| DR-090 | The console palette, and the rule that hue is never the only cue | canon §11.89 |
| DR-091 | The view strip carries every full-screen surface, ordered by the job | canon §11.90 |
| DR-092 | The Matrix archetype emits the port §4.3 could not, and four defaults it had no opinion on | canon §11.91 |
| DR-093 | The Switch generator copies the seeded switch, including what it declines to say | canon §11.92 |
| DR-094 | The paste sheet declares its separator, and drops what a closed model cannot hold | canon §11.93 |
| DR-095 | A milestone closes on clauses discharged or parked, and parking costs a ruling | canon §11.94 |
| DR-096 | The product is RackPal, and the wordmark is the one thing this repository cannot re-cut | canon §11.95 |
| DR-097 | The tracker grows a fourth level, and an epic's state follows its criterion | canon §11.96 |
| DR-098 | An override says three things, and two of its six fields were saying somebody else's | canon §11.97 |
| DR-099 | Door 2 moves the device it was opened from, and the Device Manager holds one draft | canon §11.98 |
| DR-100 | A `.rmdx` carries the body flat, because the sections were an illustration with 21 holes in it | canon §11.99 |
| DR-101 | An id collision on import means somebody typed the same name, and only a person knows which | canon §11.100 |
| DR-102 | The palette answers for the document AND the loaded libraries, and a template in two of them is two rows | canon §11.101 |
| DR-103 | Placing a library row copies the template into the project, and the palette says which shelf every row came from | canon §11.102 |
| DR-104 | The Device Manager tab becomes the browser, the card draws the glyph, and there is one matcher | canon §11.103 |
| DR-105 | The panel layout is DERIVED, a nudge is the override, and `PortDef.position` cannot say "auto" until it is nullable | canon §11.104 |
| DR-106 | `#227` is un-parked, and the nudge canvas gets its four unruled answers | canon §11.105 |
| DR-107 | M4-P's scope, the stripped form, and the panel a field device actually has | canon §11.106 |
| DR-108 | The preview dock is drawn at every width, and hiding it is a control | canon §11.107 |
| DR-109 | Bank collapse reaches the canvas, and the user can undo it there | canon §11.108 |
| DR-110 | `CON-002` is v1.2, and two sentences say otherwise | canon §11.109 |
| DR-111 | `#261` is `#322` seen from the other side, and DR-027 already ruled which one owns it | canon §11.110 |
| DR-112 | Tier 1 refuses the gesture, tier 3 reports the state, and the same condition may sit in both | canon §11.111 |
| DR-113 | `SIG-001` fires on the joint in front of it, and "switch port" is a path question tier 2 cannot ask | canon §11.112 |
| DR-114 | A verdict is not a cursor: the spring-back ring takes the severity hex, `[ Why? ]` waits for its viewer, and a gesture that hesitated has not ended | canon §11.113 |
| DR-115 | The remedy inserts a device and wires the run into it; the second link is unbuildable for the rule that asks for it | canon §11.114 |
| DR-116 | A rule is about the state, not about the gesture: landing a run end consults both tiers | canon §11.115 |
| DR-117 | The lockup ships, arranging supplied art is not generating it, and the manual is a games manual | canon §11.116 |
| DR-118 | The visor is a display: four registers, a BSOD and a loading face, and the manual gains a wordless narrator | canon §11.117 |
| DR-119 | The ISSUED FOR CONSTRUCTION stamp does not exist, so M5-I proves nothing is gated and the sealed ExportError says so | canon §11.118 |
| DR-120 | Vantage ships as `ctl.vantage`; a seventh two-wire bus in `ctl` is the argument for the row, not against it | canon §11.119 |
| DR-121 | P4 gains a control-bus variant axis: a keypad has one bus, and the catalogue was saying it had three | canon §11.120 |
| DR-122 | **A signal family may be CLONED from a shipped one**, which satisfies RJ-012's objection rather than overruling it: the clone inherits every field a rule reads, so there is no blank form and no hand-rolled family. PAL-1 moves from CI into the app for this case, since a user-created family does not exist when CI runs. Written to the project **and** the shelf, the project copy authoritative. Connector-type and colour-scheme editors stay refused | canon §11.121, §12.30 |
| DR-123 | **The builder's `Save` writes the project AND the user's shelf**, so an authored device follows the person to the next job. The census cut the scope to a third of the request: per-device export selection and the multi-library palette already shipped in M4-N. The project copy stays authoritative (AC-041, DR-103) and the shelf write is **not** a `Command`, so undo does not un-shelve | canon §11.122 |
| DR-124 | **An IR emitter output carries two conductors**: a dual-head flasher is one plug with two heads, and 3+ needs another port or an expansion block. `seed-devices.md` had said `2` since M0 and `catalog_ports.dart`'s `p()` had **no `maxConnections` parameter**, so all 727 seed ports took `1` by construction and tier-1 `TOP-003` refused the second head with no escape. Found by the M5-H2 review; the AC-051 pair could not see it because its fixtures author their own ports | canon §11.123 |
| DR-125 | **The M5-H2 review's twelve findings, censused and dispositioned.** Four were not what the ticket said: eARC was already correct, `NET-001`'s model was right and its sentence wrong, `RCK-003`'s band was architectural rather than a threshold, and the adapter prompt is one feature three-quarters built. **`RCK-003`'s `advisory` has never reached a user**: `evaluateDocument` discards a predicate's severity, so the catalogue will declare the band instead | canon §11.124 |
| DR-126 | **`DIR-003` was never keyed on the wrong field.** DR-125 held it for a decision on a census that was a row short: eleven device-side `IR IN` ports carried `ctl.ir_receiver` with the same direction, connector and pinout as a block's powered RX jack, so no re-keying could separate the hazard from the everyday case. The damage is a two-conductor TS plug bridging ring to sleeve on a jack that supplies +12 V, so the discriminating fact is whether the jack is POWERED. `ctl.ir_direct` ships and the eleven move to it; **the predicate does not change**. Implementing it found the second field in two days unauthorable by construction: `p()` had no `accepts` parameter, so all 727 seeded ports carried an empty `acceptedFamilies` and `SIG-002` would have refused the same connection with a different sentence | canon §11.125 |
| DR-127 | **A §8.3 amendment: the M5-H2 review's four unpriced findings enter M5**, plus a fifth of DR-126's own. Unpriced is not a state a milestone can close over. `#837` the remedy prompt generalises, `#838` `ELE-006` taps, `#839` `PLC-001` cabinet head ends, `#840` `CODE-002` surfacing, `#842`/`#841` the census of `p()`'s parameters against `PortDef`'s fields. **No rule is added**: the catalogue stays at 28 and every item changes what an existing rule offers. The estimate is not amended, but M5's remaining cost should be re-measured before M6 opens | canon §11.126 |
| DR-128 | **The remedy prompt, and the fourth field in one milestone whose only writer is the decoder.** DR-125 called this "one feature, three-quarters built"; censused, **`InlineAdapter` has no writer but `_decodeInlineAdapter`**, so `CON-001`'s promise that *"declaring the adapter clears it"* named an action nobody could take. CR-015's test splits the two chips: `CON-001` declares an inline VALUE, `SIG-002` inserts a DEVICE. The converter is **minted from the two pins**, not shipped, so it adds no catalogue row (CR-061's count moves for `P04`, the power strip, and not for this). `Finding` gains an optional remedy because `PWR-003` is a panel row and had no surface at all | canon §11.127 |
| DR-129 | **A code-adjacent finding is a different KIND of row.** `CODE-001` and `CODE-002` cite NEC articles that live only inside a message sentence, so the panel drew them exactly like a cable three metres too long. `RuleMeta` gains `codeCitation` on DR-125's precedent, and the row takes `ConsoleStatus.caution`, a **diamond** rather than a triangle: a shape says "different kind" where a colour says "different amount". The severity is untouched. **And the panel finally renders `Finding.remedy`**, which DR-128 §11.127.5 said it already did and which nothing had ever displayed | canon §11.128 |
| DR-134 | **A §8.3 amendment: `PortDef.carriedProtocols` is deleted, and DR-081's multi-select cell is built for `acceptedFamilies` alone.** The case that reached the user was wrong in its facts: protocol search WORKS (`dante` finds the seeded DSP by family and by tag, asserted since M4) and neither read is dead. **The real case is that the field is a second copy**: docs/02 §6.2 uses it for eARC over HDMI, which `returnChannel` already models with a column, seed data, a rule and a drawing, and for Dante over RJ45, which is a family plus a tag. It has no writer, and costs 737 empty arrays in `apartment.rmpj` alone. **Two of DR-081's own statements are corrected**: the codec does NOT omit an empty list, and `acceptedFamilies` IS read at connect time by three call sites since DR-126, which is why its cell is built now rather than parked. `kSchemaVersion` moves to 4 with `migrateV3ToV4`; `kMinReaderVersion` stays at 3 | canon §11.133, §12.32 |
| DR-135 | **M5 closes, the Plan view opens over it, and the version minor stops being a milestone number.** All three M5 clauses are discharged, all twenty Stories under epic 23 are `Done`, and the re-measurement DR-127 asked for before the successor opened found nothing left. **The successor is the Plan view, not M6** (DR-029 §11.28.4). docs/14 §14.0 could not name the new band, because the Plan view is an epic the plan deliberately left unnumbered: **it takes `0.6`, and M6 to M9 shift to `0.7` to `0.10`**. The minor now means the epic's position in the plan's order rather than the digit inside a milestone's name. Cheap here and expensive at DR-029 for one reason: a version minor has six gated copies and no prose ones | canon §11.134 |
| DR-136 | **A document carrying plan data declares a `minReaderVersion` that understands plans.** DR-019 §11.18.1 bought the `unknown` passthrough against a named hazard, a pre-Plan-view build silently dropping pins on save; M3-I built a **reserved container, not a harvester**, and both implementing files say so correctly. So the remedy never reached the hazard, and nothing noticed because the field it protected did not exist yet. **The fix refuses the write rather than preserving the field**: plan-carrying documents stamp `minReaderVersion` 5, so an older build opens read-only. `kSchemaVersion` moves to 5 for a reason the format's own trigger did not have, since the additions ARE byte-invisible and **the stamp still needs a number**. Costs stated: every re-saved document reads read-only on an older build, and one pin makes a project unsaveable there. Does NOT make the bag a harvester, and does not cover `riseAllowance` | canon §11.135 |
| DR-137 | **Underlay members are deflated, not stored, and rasterisation never exceeds the source's own resolution.** Measured against the first real plan set this project has been given (18 sheets, ARCH D, kept OUT of git under DR-036's pending public release). PLAN-B's header gave four reasons to STORE binary members; **two are false**. Every page deflates, 7% to 34%, and **the floor plans deflate BEST at 34%** because line art on white is not a photograph, which is the domain the rule was imported from. Deflating at the container's existing level (`bestCompression`, 9) costs **6.2 ms** on a realistic import, not "real time". The surviving reason, CR-117 exposure to the deflate implementation, **already applies to `document.json` in the same container**. Separately: the set is 60 dpi raster with zero vector content, so `PLAN-D/3`'s legibility-versus-size trade **is a lookup rather than a trade** for this input class, and 300 dpi would cost 12.9x the bytes for no information. **And a plan makes the file SMALLER**: 745,646 bytes of plain JSON becomes **234,165** as a container, a 69% drop, inverting docs/15 §2's untaken estimate | canon §11.136 |
| DR-138 | **The page a PDF already contains is lifted, not re-drawn, and pdfium waits for a PDF that needs it.** `PLAN-D/1` recorded two things about `pdfrx` as UNVERIFIED and verifying them refuses it twice: the licence is fine (MIT throughout) and **every route DOWNLOADS pdfium at build time**, which CR-100 refuses in its own words; and `pdfrx` 2.x needs Flutter 3.47 against this repo's pinned 3.44.4. **The package chosen to make vendoring one problem paid once cannot accept a vendored binary.** So the import LIFTS the embedded image when a page is one full-page image, detected **structurally** (one XObject, one `Do`, no text or path operator, `cm` covering the MediaBox) rather than guessed. **Lifting is not a cheaper rasterisation but a better one**: rasterising a page whose only content is a JPEG re-encodes it and cannot gain a pixel (DR-137 §11.136.4), so lifting is lossless by construction. Does NOT cancel pdfium, and the honest cost is stated: a vector PDF falls through to a refusal and reinstates the manual step DR-029 bought out | canon §11.137 |
| DR-139 | **The marquee CR-102 ruled is built once and adopted on all three canvases, and the row that promised it was vacuous.** docs/15 §6 gave the Plan editor marquee-select *"identical to the other two canvases"*; **neither of the other two canvases has one.** CR-102 is normative, rules left-drag in every view and specifies the CAD window/cross convention, and nothing implements any of it. **The census that found this looked past the word**: grepping `marquee` returns only comments saying it is deferred, and the finding is one layer down, that **every `SelectMode` call in `lib/` passes exactly one id** and no gesture in this product has ever put more than one thing into the selection set at once. A multi-selection nothing can multi-select is invisible to a census by name, because the type is present, correct and tested. **Built once and adopted on all three** rather than on the plan alone or deferred: CR-102's entire content is that the gesture is uniform, and discharging a uniformity ruling three times in three chapters is how it stops being one. **Not a scope amendment** (roadmap §2 does not list marquee; this assigns never-built work to a named chapter), and **its own Chapter `#848`** rather than folded into `PLAN-E/2`, so the growth is a line somebody can read | canon §11.138 |
| DR-140 | **The rack is pinned from the unpinned strip, because nothing in `PLAN-E` pinned it at all.** docs/15 §3.4 marks the rack's `PlanPin` *"not optional to the design"* and `PLN-003` fires without it, because a home run is measured FROM the rack and without one **no length on the plan is derivable at all**. `Rack.planPin` shipped at PLAN-C and `SetPlanPinCommand` has accepted `PinCarrier.rack` just as long: the model and the writer were ready and **no gesture in any of `PLAN-E`'s five chapters could press the button**. The palette places a device, the drop table pins an outlet, the strip listed devices. Each chapter is coherent; **the SET had a hole, visible only from outside any one of them**, which is M4's port grid that never created a port one epic later. So the strip lists every unpinned **carrier**, not only devices, and dragging a row out of it pins that row. A strip omitting the rack **was** the 80%-complete plan it exists to refuse. The count is therefore a count of carriers, and a strip built from `doc.devices` alone passes every test whose fixture has no rack | canon §11.139 |
| DR-141 | **A pin arms one drop at a time, and the fast path is the strip rather than the table.** docs/15 §6 gives the fast path as *"click an outlet in the drop table, then click the plan"* and stops there; sixty drops means sixty pins, so the unspecified moment is the whole question. **One arm, one pin, and the mode stays on with nothing armed**, chip up, `Esc` the only exit. **Auto-advance was offered and declined on the FAILURE MODE**: a mis-click pins the wrong drop AND advances, so recovery is an undo plus a re-arm, and the person going fast is the one who will not notice the chip moved. The two-acts-per-drop cost is real and is paid by DR-140, whose unpinned strip is already in the plan view: **`PLAN-E/4`'s strip is THE pinning workflow and `PLAN-E/3` is the secondary entry point**, so the brief's own framing is superseded. **A MODE IS NOT A REQUEST**: `SchematicRevealController` is one-shot and this outlives the pin. **Amended by a gate**: the drop-table producer was built and `actions_have_callers_test.dart` refused it, since nothing in `lib/` supplies one, so it moves to `PLAN-E/5` rather than being reworded until the regex stopped matching | canon §11.140 |
| DR-142 | **What the unpinned strip lists, and the two location fields a device already had.** docs/15 §6's *"everything in this plan's location that could carry a pin and does not"* hides a decision in every clause. **Unpinned means NO PIN AT ALL**, not "no pin on this underlay": a carrier has one `planPin` field, so a row listed as unpinned-here-but-pinned-there would silently MOVE the pin off the other plan as the answer to a gesture that presented itself as adding something. **An underlay with no location has no FILTER**, so a site plan lists every unpinned carrier; matching its null against a carrier's null would be G4's forbidden join, and listing nothing would report zero on a plan with nothing pinned. **A carrier whose own location is unknown is a COUNT, not a row** (`CR-114`), so the strip carries `unlocatedCount`. And **`PLAN-E/2` left a device's two location fields disagreeing**: `buildPlaceOnPlanCommand` sets `OffRackPlacement.locationId` and `AddDeviceCommand` has never had a `locationId` parameter, so every plan-dropped device printed **no room on the Equipment List**, unrepairable because `locationId` is deliberately not a `DeviceField`. Asking which of two fields is the room is what found it | canon §11.141 |
| DR-143 | **The floorplan importer had no caller, so the Plan view had nothing to open.** `PLAN-D` built the import sequence, the caps, the PDF page lifter and the picker, all tested, and **every one of `pickAndImportFloorplan`, `importFloorplanFrom`, `importFloorplanBytes`, `readPdfPages`, `importLiftedPdfPage` and `PdfPagePickerDialog` has ZERO call sites in `lib/`**. So `AddPlanUnderlayCommand` has no producer, the four starters carry no `underlays` key, and `PlanCanvasScreen.underlay` is required and non-null: mounting the Plan tab would have mounted a fully built view onto content the product cannot create, which is DR-091's rule from the direction it did not anticipate. **The producer is TWO pieces**: `DocumentSession._members` is written only by `adopt`, wholesale, so a menu item would have had bytes and nowhere to put them. **`actions_have_callers_test.dart` could not see any of it** because it scans function-typed fields on `*Actions` RECORDS in `rackpal_ui/lib`, and these are free functions in `apps/rackpal/lib`: a gate's scope is part of its claim, and this one's name is broader than its scan. Ruled: the producer folds into `PLAN-E/5` (not a §8.3 amendment, the work was always in scope), the command is `File ▸ Import floorplan…`, and **the `Ctrl+n` mapping is NOT renumbered**, because §11.90.4 defers it past M6 rather than until Plan lands | canon §11.142 |
| DR-144 | **A calibration carries its unit, and the number it reports back is not a length.** The `PLAN-F` census found DR-143's shape one field over: `PlanScale.nanometresPerPixel`, `pixelSpan`, `isUsable`, `lengthBetween`, `lengthAlong` and `PlanUnderlay.isCalibrated` have **zero call sites in `lib/`**, and no command sets a scale at all, so `scale` is null in every document this product can make. **`PLAN-F/2`'s "say N lengths changed" therefore had nothing to count**, because `planLowerBound` is `PLAN-G`'s and a report of `0` would be an artifact of what is unbuilt. Ruled: the count is **measurable pins**, computable today and **producing no `Len`**, since a length per pin would be `planLowerBound` early under another name; when no rack is pinned the report says that instead, eight inches from the strip that fixes it. **`Calibrate…` lives on the underlay row**, because a calibration is a property of an underlay and docs/15 §6 forbids a fourth region. **A bare number is REFUSED by name**: `36` is 36 inches or 36 feet and the two differ by twelve, applied to every length the plan yields, so the grammar takes `36"`, `3' 6"`, `2.4m` and refuses the ambiguous one, **diverging from `parseLengthCell` deliberately** so no later pass unifies them into a default unit. The pick is a **mode on DR-141's shape but consumed by its own second click**, and `Esc` grows a third rung. **The writer moves into `PLAN-F/1`**, because a dialog with nowhere to put a distance is the no-caller defect pointed the other way | canon §11.143 |
| DR-145 | **The second real plan set is all vector, so DR-138's trigger has fired and the deferral survives it.** A three-page AutoCAD 2022 plot (`pdfplot16.hdi`, ANSI B, classic xref) with **zero `/XObject`, zero `/Image` and 39 `/Font`**: the lifter refuses all three pages with `draws no image`, and that refusal is right **for the right reason**, because it sits after the MediaBox and Resources checks and so proves the parser walked a real AutoCAD file before finding nothing to lift. **The two real sets sit at opposite ends**: DR-137's eighteen sheets were every-page JPEG with zero vector, these three are all vector with zero images, and the importer covers one fork of an ordinary path that forks. DR-029 is not wrong and **its purchase is half-delivered**, which is a different sentence. Ruled: **the deferral stands and is re-examined at `PLAN-H`**, because a vendored pdfium plus an FFI binding is the largest piece left and would displace the chapters that make a plan yield a length at all, and because `T1.01` is the first thing that needs an underlay RENDERED rather than stored. The route is still not `pdfrx`. The regression fixture is a **synthetic twin** and the file stays out of the repository | canon §11.144 |
| DR-146 | **An uncalibrated plan states what it costs, and the count is one population in both directions.** `PLAN-F/3`'s census found its lead clause already discharged (no site in the model, the codec, the command or the derivation substitutes a scale; the absent key and the null read-back are already asserted), its second clause **true but proven by accident** (every plan fixture in `rackpal_ui` is uncalibrated, so every pin gesture in the suite is already the interesting case and the mirror direction, a pin on a CALIBRATED plan, is exercised nowhere), and its third a hole: `PlanMeasurability.pinnedCarrierCount` was built at `PLAN-F/2` with a doc comment naming its own caller and has **zero call sites in `lib/`**, so the row prints a bare `Not calibrated` and a plan carrying thirty-nine stranded pins reads like a plan with none. Ruled: the row says **`Not calibrated · 39 pins carry no measurable position`**, which is docs/15 §9's own `PLN-001` sentence, and **the count is the same population in both directions** so that thirty-nine unmeasurable becomes thirty-nine measurable; the rack is the datum and is in neither. So `pinnedCarrierCount` is **replaced** by `subjectPinCount` rather than retained, `measurableCount` becomes a derived getter, and the sentence lives in **core** beside the derivation because `PLN-001` is a core rule and a copied sentence drifts. The proof of both directions is **a gesture and not a model call**, since a gate would be added on a surface | canon §11.145 |
| DR-147 | **The bound measures from the run's own rack, and the two rollups it must not enter are two.** `PLAN-G`'s census found two of its four briefs describing a tree that had changed underneath them: **`LEN-001` and `LEN-002` already ship** (M5), so `#639`'s *"do not build the rules here"* has expired, and **those rules never read the tier ladder at all**, since `knownLengthOf` is `terminatedLength ?? cutLength`. It also found **two footage rollups where the booby trap guards one**: `cable_footage.dart`'s `_isQuantity` stops the build as designed, and `schedule.dart`'s `_footageOf` sums `row.length` with no source check into the sheet footer's `Σ 11 runs · 601 ft · 3 estimated`. Ruled: the datum is **the rack this link lands in**, and a rack with no pin yields no bound even when another rack is pinned on the same underlay, because the nearest or first rack is a wrong number on any job with a head end and a satellite; that rule also makes the jumper and the sub-feed fall out rather than be excluded. The bound enters **neither** `Σ` and is **counted in both**, since a `Σ` that shrinks as the job gets planned is the flattering half. **A floor and a guess are two claims and get two flags**: `lengthIsEstimated` stays false, `lengthIsBound` carries the `≥`, and the prefix goes in `lengthCell` and never in the shared `scheduleLengthCell`, which three round-tripping columns read. And the rules read the floor **only in the direction that proves something**: over the limit is a violation, under it is still *"cannot verify"*, which is DR-020's asymmetry as executable code | canon §11.146 |
| DR-148 | **The rasteriser is deferred a second time, and the debt is wired into the exit criterion rather than into a review date.** DR-145 §11.144.5 booked this review for `PLAN-H` because *"`T1.01` is the first thing that needs an underlay RENDERED rather than STORED"*. **That reason does not survive the census**: `PlanUnderlay.format` is `png | jpeg` by construction, a PDF page is lifted to one at import, and `drawImage` has rendered a stored raster since `PLAN-A`. The rasteriser is an **import** gap, not a render gap, and `PLAN-H` is not blocked. The review was held anyway, because skipping a scheduled review on the grounds that its reason was wrong is a deferral by another route. Ruled: **the deferral stands, and the second one is said out loud**; the route is still a vendored pdfium over FFI and still not `pdfrx`. **The new trigger is the exit criterion itself**: `PLAN-J`'s drill is bound to the CAD plot rather than to whichever set imports, so the epic cannot close until the rasteriser exists. That **adds no scope**, because the criterion already says *"an architect's floorplan PDF is imported without leaving the app"* and a CAD plot is one; it has been unmeetable on that input since it was written and nobody had noticed. The drill's own risk is recorded rather than discovered: run on the JPEG set it would PASS, and a green drill would read as evidence about import coverage when it is evidence about callouts | canon §11.147 |
| DR-149 | **The plan sheet's place in the set, how light it prints, and the export path that could not reach an underlay.** `PLAN-H/1`'s census found the finding upstream of every chapter: **`ExportRequest` carries no container members**, so the exporter structurally cannot reach an underlay, and `PdfImageResolver` is a typedef with **zero production call sites**. That is `PLAN-E/1`'s finding one package over, and `plan_image_cache.dart` is the model rather than a design question. **A second exhaustive switch fires here**, `build_document.dart`'s over `SheetRole`, this one by definite assignment rather than on purpose, and it forces the chapter's shape: the slot cannot land without a sheet behind it, so `#641` keeps the **evidence** (no `/SMask`, no `/ExtGState`) rather than the pass. Ruled: **`T1.01` sits after `T0.02` and before the elevations**, because a reader orients in the building before they open a rack and docs/08 §2.2's table is not numeric anyway (`T5.01` is last). **The underlay prints at 25%**, one named constant, chosen over 18% because line art is not a swatch and over 40% because the callout must win, **and confirmed by a laser rather than by this ruling**: AC-054 makes `PLAN-J`'s drill the evidence, and moving the number afterwards is expected rather than a defect | canon §11.148 |
| DR-150 | **A pin has no domain, so a callout has no colour, and the screening turns PAL-1's open obligation into arithmetic.** `#642` asks callouts to take *"the signal domain's colour"*, and none of docs/15 §3.4's three carriers resolves one: `Rack` and `Outlet` carry no `SignalFamilyId` at all and a device spans several. `plan_scene.dart` wrote that down at `PLAN-E/2`, one chapter after the brief was filed, and AC-054 prints the sheet greyscale anyway. Ruled: **one uniform callout, opaque, black**, masking what is beneath it, because the failure over line work is **pattern** and not contrast; carrier kind stays in the marker shape. It prints **the carrier's own designator**, since a pinned outlet has several Pull Sheet rows and a cable designator is not a function of a pin. **PAL-1's open obligation is discharged by a number**: the darkest sample 25% ink can leave is 192, black on it is 11.54:1, the break-even is 550 per-mille, and `pal1_check.py` parses `kUnderlayInkRetained` out of the Dart rather than keeping a second copy. Placement is a **ring of offsets then a leader**, deterministic on `planPinsFor`'s order, and **a callout is never dropped**: an absent one is a drop the stranger cannot find. **The brief's "reuse the schematic's pill" was not available**, since `_PillSizer` is private to `rackpal_ui` and `rackpal_export` may never import it, which is the layering debt recorded since 2026-07-28; the reasoning is taken and cited, the file stays M6's | canon §11.149 |
| DR-151 | **The bar is drawn, the uncalibrated sheet says so itself, and a placeholder string reached a deliverable.** `PLAN-H/1` shipped `PLAN SCALED TO FIT · SEE BAR` on `T1.01` with no bar on it. `unbuilt_copy_accuracy_test.dart` exists for that exact class and scans `rackpal_ui` and `apps/rackpal`; **a sheet string lives in core and is invisible to it**, which is the fifth gate in this epic whose scope is narrower than its subject and the first where the missed surface is PRINTED and handed to somebody. `#643` says `PLN-001` explains the missing bar, and `PLN-001` is a **finding**: it reaches the validation drawer and M6's `T0.02`, neither of which the person holding the print has. Ruled: the sheet says it itself, **`NOT TO SCALE · PLAN NOT CALIBRATED`**, because `NOT TO SCALE` names the one thing that reader must not do and the plan still locates every drop. The full `PLN-001` sentence was refused as a **designer's number** on a sheet read by the installer. The bar is **alternating segments with the ends labelled**, since a plain rule can be read only at full length and the alternation survives greyscale by construction. Its length is a round value in `displayUnits`, **never refused for scale**: when no ladder entry fits the budget the smallest is taken anyway, because a long bar is still true and a refused one is a sheet with no bar on a plan that has a scale | canon §11.150 |
| DR-152 | **The plan schedule projects the plan's own derivations, and it is set in columns because one column fails the exit criterion.** `#644` says the per-plan schedule projects *"the derivation the equipment list already uses"*, and **`EquipmentList` is one row per `DeviceInstance`**: an `Outlet` and a `Rack` appear in it nowhere, and outlets are most of what a plan pins. Fourth of `PLAN-H`'s five briefs to name something the tree does not hold, and the principle is right while the pointer is wrong. Ruled: it projects **`planPinsFor` and `planPinLabelsFor`**, which `PLAN-H/3` already built, so the reference column is literally the string the callout prints and one designator cannot have two spellings. **Every callout resolves, the rack included**, because a reader who finds `RK-1` on the plan and nothing in the table has hit the dead end this sheet exists to prevent. And **the band is set in four blocks across, measured rather than estimated**: the drawing area is 1122 × 567 pt and a row is 12, so one column of sixty needs 734 pt and does not fit, while four blocks cost 194 and leave the plan 373. **Sixty is the exit criterion's own scenario**, so a single column fails the criterion it is under. Ruled three columns and **amended to four the same day (§11.151.4a)**: the cap was drafted as *"roughly 180 rows"* and measured 60, which is the criterion's own figure, so the last-resort overflow fired on the sixty-first drop. Four blocks cap at 80 and give the plan more of the sheet at every row count | canon §11.151 |
| DR-153 | **The rasteriser is built, the deferral ends on trade evidence, and the vector is kept rather than discarded.** DR-138 deferred pdfium *"until a PDF needs it"*, DR-145 kept the deferral when one did, and DR-148 kept it a second time; all three said the missing thing was a POPULATION (*"n is one"*). The user supplied it: raster sets are the more common of the two and vector plots are by no means uncommon, so the refused class is ordinary. Mechanism unchanged and both original refusals re-checked: `pdfrx` downloads pdfium at build time against CR-100 and needs Flutter 3.47 against a pinned 3.44.4, and a pure-Dart renderer dies on the plot's 39 fonts. Ruled: a direct FFI binding over a **vendored** pdfium, Windows x64 first, pinned by version and SHA-256 and placed by a person; a leaf package `rackpal_pdfium` so `rackpal_core` keeps zero native dependencies; **300 dpi of the page's own size** (327 dpi effective on `T1.01`) with a pixel budget that steps down rather than refuses, discharging DR-145 §11.144.7; and a rasterised page **keeps its source PDF** while a lifted page does not, because a lifted page's stored bytes already ARE the source. Vector passthrough to the sheet is not built: it needs an object-graph copier and collides with the per-pixel screening, and `PLAN-J`'s print decides whether it is needed at all | canon §11.152 |
| DR-154 | **The plan advisories are a second band, the count they must not join is already wrong by one, and the pair gate follows the rule rather than the list.** DR-144 §11.143.8 left `PLN-001`'s severity and band to `PLAN-I`. The census found the count first: `#645` opens by naming the trap (*"AC-040 pins v1's catalogue at 27 and DR-020 made it 28"*) and **it is 29**, since DR-132 restored `ELE-005`; the table and the test say 29 and the PROSE says 28 in six documents, which is the sixth instance of the pattern and it arrived inside the warning about it. Ruled: `PLN-001..004` live in `kPlanRules` bound to **docs/15 §9** the way `kRuleCatalogue` is bound to docs/02 §5, because CR-021's *"a rule not listed there does not exist"* is about a specific there. **One lookup, one evaluator, one `AckedFinding`**, since a second severity path is what `drc.dart`'s header already forbids. **AC-051 follows the rule and not the list**: each `PLN-*` gets its pair and the gate reports per band, because a rule shipped without one does not become acceptable by being filed under a different heading. `PLN-004` is a **warning** and the other three advisories: three say you have not done this yet, and the fourth says what you are looking at may not be what you measured. Each states its count (G4), and `PLN-002` counts the location's **subtree**, since an underlay depicts a floor and the drops are filed in its rooms. **§11.153.7a amends that clause and DR-142's strip with it**: the shipped `unpinnedCarriersFor` matched a location EXACTLY, so on a `Level 1` plan an outlet in `Great Room` was neither listed nor counted as unlocated but dropped by a comparison, which is the `0 pathways` failure its own `unlocatedCount` was written to prevent. Both widen to one scope, because the strip is `PLN-002`'s remedy surface and a count that disagrees with the list it sends you to is the two-answers failure CR-107 keeps naming. **Three amendments from `PLAN-I/2`.** §11.153.3a: once the catalogue was two lists, the tests carrying *"every rule is acknowledgeable"* and *"every rule that files a finding has a severity"* both went on looping over `kRuleCatalogue` and reached no `PLN-*` at all, and the second is not cosmetic, since `evaluateDocument` DROPS a finding whose severity resolves to null, so a plan rule missing from `kRulesById` would never fire rather than fail; both sweeps now cover both bands and count what they reached. §11.153.5a: `findings_never_block_export_test.dart` sweeps the same one catalogue, so CR-022 was unproved for this band, and the proof reads `T1.01` OFF THE PAGE because four blank pages satisfy a `sheetCount` of four. §11.153.8a: **the issues panel could not name any of them**, since `locusLabel` knew four entity kinds and the rules point at six, so every `PLN-*` and every `ELE-005` since `#838` grouped under "No single location" while the surface's own guard promised a fifth kind would fail loudly; that guard asserted a null for an id NO rule produces, which cannot see a type rules DO | canon §11.153 |
| DR-155 | **The Plan view's walkthrough clause is parked on M6, because the Pull Sheet does not print.** The epic's exit criterion names *"the printed `T1.01` and the printed Pull Sheet"*, and **there is no Pull Sheet in the exporter**: `SheetRole` has four values and none is one, the rows exist only as a derivation rendered on screen by `ScheduleScreen`, and `rackpal_export` never references `ScheduleView`. There is no tabular export either (`EXP-A`, DR-049, unstarted). **So the clause could not have been discharged at any point in this epic's life** and no drill would have changed that. **This is DR-027's seam reaching a second criterion**, not a new decision: §11.26.3 already ruled that a milestone cannot discharge a clause about a sheet it does not own, and that reading one loosely enough to call it met is the checklist-ticking §8.1 refuses. Parked under roadmap §8.9, which requires a ruling ID and a named milestone. **M6's criterion GAINS the walkthrough**, unlike DR-027 where the existing export clause already contained the sheet: a walkthrough is a demonstration rather than an export. **The print does NOT move**: `PLAN-J/2`'s greyscale laser at ANSI B and AC-054's legibility stay with the Plan view. Board `#649` moves to `M6-J` | canon §11.154 |
| DR-156 | **A command reports whether it applied, and a transaction may take its label from its first child.** Two defects, one subject. **(1) `apply` returns `bool`**: a command that self-refused still became a child, so the transaction was recorded, the epochs bumped over an unchanged document, and the next undo called `revert` on a command that never applied and threw. `_commit` already read *"no-op edits add no history"* and could not see the case; `TxnScope.add` now drops a child that returned false, which lands ONCE because both undo stacks share it. 78 implementations, 24 of which refuse. **The return type rather than a defaulted `applied` getter**, because two members drift and a default is a hole a future refusing command falls into silently. The `StateError` in `revert` stays: the throw was never the defect. **(2) the label is read at commit**: `transact(c.label, …)` evaluates before the closure that applies, so three commands that decide their label from the document never reached the Edit menu, all three the second half of a pair (`movePlanPin`, `reshapeRoomOutline`, `recalibratePlan`). Null now means *the first child names it*; **a caller that names the act still wins**. **`Transaction.mergeKey`'s single-child mirror was drafted and rejected**: it would override a caller, and `LEN-A/4`'s outline close adds one child or two depending on a derivation, so one gesture would get two menu entries | canon §11.155 |
| DR-157 | **A rack height with no side is incoherent, and placement says so instead of quietly putting the device somewhere else.** Reported from the `PLAN-J` demo: authored devices vanished on placement while seeded ones worked. Two surfaces disagreed about one fact. The builder's save gate requires a height and **never consults `side`**; `buildPlaceFromCatalogCommand` checks `side` **before** the height, so `{frontU: 2, side: none}` returned `CatalogPlacementReady` carrying an `OffRackPlacement`: a reported success for a device nobody can see. Placement now refuses it by name, and **the distinguishing fact is the HEIGHT**, which is what keeps AC-031's eighteen field templates (`{front: 0, rear: 0, side: none}`) landing where they always did. **The builder derives the side as the height is typed**, filling a blank only, in the field edit's own transaction. A save gate was tried first and broke AC-049's three-required-fields case, which was right to break: a fourth interaction is the stall AC-049 exists to prevent | canon §11.156 |
| DR-158 | **A template is removed from a project as a whole, and it takes the devices standing on it.** Reported from the `PLAN-J` demo alongside `#870`; unlike that one, **nothing existed at all**. docs/06 §7.1's *"library operations are not undoable"* governs the M4-N **shelf**, which does not exist; a per-project embedded snapshot is project data, so removing it is a document edit and **is** undoable. **The unit is the template id, every version**, because the product addresses ids everywhere a person can see and a removal that took one snapshot would make a row vanish and silently return at the previous version. **Project-authored rows only**: the seeded 48 are what the build ships, and a per-project hole in them is a difference carried in the file forever. **The devices go with it**, after a confirmation counting templates, devices and cables in three units, and one undo puts all of it back; `DeviceInstance.templateRef` is the only referent in the model, so the cascade has exactly one edge. An unused template is still asked about, which departs from the other three plans: authoring one is work that exists nowhere else | canon §11.157 |
| DR-159 | **Undo is document-global, it says what it will take back, and the builder keeps its own stack.** Reported from the `PLAN-J` demo: *"undo doesn't appear to work anywhere "*. `UndoIntent` and `RedoIntent` had **exactly one handler in the entire tree**, inside `RackCanvasScreen`, and the app had one menu with no Undo item; the strip is seven tabs. **The intent was always right and only the installation point was wrong**: that handler's own comment says the key is document-global, and the registry row named promoting it to `KeyScope.global` as a rebinding owed a ruling. The rack KEEPS its handler, because nearest-Action-wins and only it can restore the selection `undoLast` returns. **The builder keeps its own stack** (CR-106) and `Ctrl+Z` reaches it there, so one key means two things on one tab, which the menu makes readable rather than felt. **The Edit menu is built**, specified by docs/03 §13.3 since M0 and never made, against a `LabelKey` whose 101 values carry comments arguing what it should say; the map is explicit and gated rather than de-camel-cased, because the obvious wording names the wrong act for exactly the values that were split. It is NOT localized: there is no `l10n.yaml` in this tree, and that half of §13.3 stays owed | canon §11.158 |
| DR-160 | **Removing a Structure body or an outlet, and what each takes with it.** Found by `#872`'s reachability gate: `RemoveOutletCommand` and `RemoveStructureCommand` shipped at M3-A/1 with real reverts, eight and nine test constructions between them, and **no caller anywhere in `lib/`**, while Add was wired for both. So the Structured Wiring tab could create a panel and a wall plate and take back neither. **Half the cascade was a decision and half was not.** A plate takes its home runs because `StructureOriginField` lists seven editable properties and `outletId` is not one of them: clearing it would leave a legal document holding cables no surface in the product could ever re-home. A panel takes its plates and its cables because `Outlet.structureBodyId` and `StructureOrigin.structureBodyId` are both non-nullable and `final`, so there is no version of leaving them that is not a dangling reference; §11.159.4 says which of the two a later reader may reopen. The confirmations count **plates, cables and PINS**, because a pin is walked-site work that `plan_length.dart` derives a length from. A bare plate is not asked about and an empty panel is. **A trash icon on the plate row** and **an overflow menu in the header**, the second because the picker a trash icon would have sat beside is built only when the project holds more than one body | canon §11.159 |
| DR-161 | **What the reachability gate counts, and when an exemption may be permanent.** Two of `#872`'s twelve rows were about the GATE and not the tree, and both became board items on its word alone. **`SnapshotCommand` does not exist**: that file declares nothing and holds an indented sketch inside a `//` comment, and the gate's step 1 read raw files while its step 2 read stripped ones, so a comment entered the corpus. Measured: 73 raw, 72 stripped, one phantom, nothing lost. **The identical mistake is in that file's own header pointing the other way** (attempt 2 let a name in a comment count as REACHABLE), fixed on the edge side and left on the node side. **`AddLinkCommand` is the opposite**: it exists, is used 21 times, and is deliberately not for a person, being the only Link-minting command needing no device, port or panel; nine of those sites could not be rebuilt cheaply because `allocateNetNameFor`'s two properties have no other coverage and the CR-117 sweep has no other link-creating step. So an exemption may now be PERMANENT, in a second map whose values are sentences and which the staleness check binds exactly as hard: the permanence is in the reason, not in the checking | canon §11.160 |
| DR-162 | **Taking something off the plan, and putting the pages in order.** `ClearPlanPinCommand` and `ReorderPlanUnderlayCommand` shipped at `PLAN-C` with real reverts and no caller, while `SetPlanPinCommand` and `RemovePlanUnderlayCommand` in the same file both had one: **every gesture that PLACED something was wired and neither that took it back was**, so a rack pinned to the wrong room could only be fixed by pinning it elsewhere. **`Delete` and `Backspace` on the selection**, which costs one key meaning two things (the rack's removes a device outright) and is right anyway because the label names THE SELECTION, a different kind of thing on each canvas. The unpinned strip is what makes it safe: the carrier reappears at the bottom in the same frame. A marquee clear is ONE undo step and an empty selection disables the action rather than building a transaction whose only child declines. **Pages reorder by a dedicated grip**, with whole-row drag refused because the row's own controls sit inside the drag target and up/down buttons refused on a measurement. A reorder is one `orderBetween` field write, never a renumber, and where it cannot mint a value it refuses in words. **§11.161.6 records what building it found**: this canvas never called `requestFocus`, so `Esc` has been dead here since `PLAN-E/5`; and no pointer gesture reaches the Plan tab at the app mounting, which is `#882` and is deliberately not diagnosed here | canon §11.161 |
| DR-163 | **A 0U channel is added, removed and occupied from the inspector.** AC-044 rules that in v1 a 0U occupant is *"created and edited from the inspector (channel, start U, span)"* and **the inspector half was never built**: three commands with real reverts, three planners with real refusals, and `occupantsOfZeroUChannel`, whose doc says it is public *"because the inspector needs to say 'AMP-1 is in this channel' before offering to delete it"*. **Adding takes the bounds up front** because no command edits them, so a wrong extent is replaced rather than corrected; two comments in the tree promised an editability that never existed. **The surface validates nothing**: the planners already refuse a duplicate id, an inverted span, a span that does not fit and a removal while occupied, each naming the rack, the numbers or the device. §11.162.1 records a CORRECTION: the occupant fields were ruled onto the device inspector, built there, and could not be reached, because `scene_builder.dart` drops every non-rail placement so a 0U device is never drawn or selectable (`#883`); they moved under their channel in the rack panel. §11.162.4 records the defect found on the way, where the only producer wrote a sub-1 channel citing CR-025, which forbids it. **§11.162.5 is CORRECTED by DR-164**: it deferred creating an occupant to the palette, and the palette refuses one | canon §11.162 |
| DR-164 | **A device is put into a 0U channel from the channel's own row, because nothing could put one there at all.** Reported by the user against `#876`'s list: it never shows a device, and could not. **`ZeroUTarget` has one definition, one mention in a comment and ZERO call sites**, so the only reachable writer of a `ZeroUPlacement` is `planSetZeroUPosition`, which MOVES one that already exists; the three starters that show a PDU get it from the authoring tool writing the placement directly. **The gap was recorded and recorded as HANDLED**: §11.162.5 deferred to `catalog_placement.dart`, which refuses a 0U row with *"Add it from the rack inspector"*, so **each surface deferred to the other**. Ruled: an `Add device…` control on the channel row, against a drag onto the bar, since the bar is `#883` and that would put the only producer behind AC-044's other unbuilt clause a second time. **The occupant lands at the CHANNEL START**, not a first free offset, because a 0U occupant has no extent anywhere in the format and "free" has no meaning without one. **It is NOT selected**, uniquely among placements, because selecting it swaps the inspector to a device panel for a device the elevation never draws | canon §11.163 |
| DR-165 | **The device palette is the shell's, so the Plan view can place a device.** docs/15 §6's gesture table opens with *"drag from the device palette onto the plan"*, `buildPlaceOnPlanCommand` carries the pin on the placement so one undo restores both, and `armPaletteDrag` is public with a comment saying the host that owns a palette hands the armed pointer down. **All three of `armPaletteDrag`'s call sites are tests**, and `DevicePalettePanel` had exactly one mount, inside `RackCanvasScreen`, so the palette was not on screen when the Plan tab was. `PLAN-E/5` shipped the tab and never brought it. Ruled: a **`PaletteHost`** owns the column, the rows and the search field, wrapping the Rack and Plan tabs and **no other** (a device palette on the Structure editor is a control that cannot act on anything in view). **The host hands over a RESOLVED ROW, not a key**, which removes a defect: a `rowKey` is `source/id@version`, `_placeFromPalette` passed one straight in as a `catalogId`, and its three tests all passed a bare id, so the parameter was never given the value its name promised. The search focus node is owned by the **common ancestor**, because the shell builds the tab bodies before the host's `State` exists; and `/` gains `KeyScope.plan`. **§11.164.5 records what a test found**: the column cannot be a sibling of the `TabBarView`, because a `TabBarView` is a `PageView` and positions by PIXEL OFFSET, so hiding a 280px column widened the viewport and every tab switch landed one page short. The host provides and each VIEW places its own column | canon §11.164 |
| DR-166 | **A 0U occupant has a span, and it draws as a bar on its rail.** AC-044 keeps two things in v1, an inspector editing *"channel, start U, span"* and a *"plain bar"*, and **neither could be finished because the model has no extent for a 0U occupant**: `ZeroUPlacement` carries a channel, an offset and an orientation, `TemplateBody` has no physical length and `frontU`/`rearU` are 0 for a 0U body, and `PLC-003` treats the occupant as a POINT. `zero_u_commands.dart` recorded the gap the day it was written and said closing it is a ruling. Ruled: a **`Len` span along the channel**, against running the bar to the channel end (honest only while one occupant is in a channel, and `#884` puts every one at offset 0) and against spanning the whole channel (which makes `#876`'s Start U field change nothing visible). **Absent is UNKNOWN, not a default**: every document today has none, so an occupant with no span draws as a one-U stub carrying G4's unknown marker rather than a bar the file does not support. **`PLC-003` is WIDENED rather than joined by a second rule**, because its own rationale already says *"or past the end of one, has nothing to screw into"*. The bar sits on the **rail**, ≈7.9 units derived from the real EIA-19 flange, so no elevation changes width. §11.162.1's reason for putting the fields on the rack panel is now spent and they stay there on a fresh decision | canon §11.165 |
| DR-167 | **The 0U occupant's fields move to the device inspector.** AC-044 puts *"channel, start U, span"* on the inspector and every other device property is edited on the DEVICE panel; §11.162.1 put these three on the RACK panel because a 0U device **could not be selected**, and §11.165.6 recorded that `#883` removed that reason and that they stayed put on a fresh decision. The user then made the other call. **Both earlier clauses are corrected in place**, because a reader who finds a placement argued from an obstacle that is gone will re-derive the wrong conclusion. **The CHANNELS stay on the rack panel**, which is not a compromise: adding one, removing one and the occupant count that makes a Remove about to refuse say so first are facts about the RACK, while the occupant's channel, start U and span are facts about the DEVICE. Nothing is editable in two places, and a case pins that the rack panel still NAMES what is in a channel while no longer editing it | canon §11.166 |
| DR-168 | **The Location and Plan views are one view, called `Site`.** Two tabs did adjacent halves of one job, and **the merge was half-done already**: docs/15 §6's layout paragraph has put the location tree in the Plan view's rail since the chapter brief, *"read-only with the same 'edit in `Project ▸ Locations…`' affordance"* — an affordance pointing at a menu the app does not have, since DR-091 promoted Locations to a tab (`#888`). Ruled: one view at **position 1**, `Locations`' place, because the rooms are the first thing anybody enters; the name is neither half's, since a site HAS rooms and some are drawn on a plan. **The rail is the TREE**, with the underlay list appearing once a floorplan exists, so a project with no plan is an ordinary project rather than an empty view with an import button (CR-112, docs/04 §7.5). **The tree creates a room and an outline is an attribute of one**: drawing-creates-a-room was refused because CR-047's arbitrary-depth tree makes a new room answer which parent, which kind and where in the order, and a drag has nowhere to ask. §11.90.3's table goes from seven rows to six and **§11.90.4 is what permits it**, having refused to freeze the view set before M6. CR-112, CR-047 and *"no fourth region"* all stand. `showLocationsPanel` has **no caller anywhere** and is deleted rather than ported | canon §11.167 |
| DR-169 | **A plan mark is sized in screen points, coloured by domain, and says which one it is.** Three complaints in one message after drawing rooms in the product, and the first two were **measured before they were ruled**: `kPlanMarkerRadiusFraction` is 1/110 of the plan in SCENE units, so a **60-point mark** at 1:1 on a 3300-unit sheet with a hit box to match, and the plan canvas **never calls `fitToContent`** where the rack editor and the schematic both do, so a plan opens at 100% in its top-left corner. Ruled: the mark is a **constant size in screen points** at every zoom, which is what `_withinCloseRadius` already argues for, and the proportional rule is retired rather than re-tuned; a plan **opens fitted** with a `Fit` control. **Colour encodes the carrier's primary signal domain** (CR-078's own rule), and that domain is **AUTHORED on the template, not derived**, because the census is decisive: of 51 seeded templates **13 have ports in one domain**, and excluding `pwr`/`ctl`/`str` it is 26 while **nine then have none at all**, a control keypad among them. A television reads as `(video.digital, audio.analog, net)`, so a set of port domains does not say what a device IS and G4 forbids estimating it. **The mark carries the domain's GLYPH**, because `plan_sheet.dart` splices `buildPlanScene` and §14 records that the eight hues collide in greyscale by design, three in one band, which PAL-3 resolves for a LINE with dash and weight that a filled dot does not have. The **designator is a hover**, not a label beside every mark. The **rack mark is unchanged**: it is `PLN-003`'s datum, not a ninth domain. **`buildPlanScene`'s `markerRadius` parameter has no caller anywhere**, the eighth no-producer instance, and is the seam this uses. **§11.168.10, added 2026-09-14 at `#904`: a printed mark is the round end of the callout pill beside it**, a relation and not a number, because the pill's own type size is still `PLAN-J`'s print to settle; the sheet had kept the retired fraction and printed 6.87 points on a 2000x1500 plan against 5.15 on 1500x2000. **§11.168.11, added the same day at `#905`: a mark's line weight is the drafting weight**, a drop at the base signal weight on paper and one pixel on screen and a device at twice it, constant at every zoom and on every scan and emitted with `scaleWithGeometry: false`; before it, a 6600x5100 scan printed a device and a drop at the same 0.5-point floor, and the ring has to stay under about 37% of the radius to clear the corners of Network's square glyph | canon §11.168 |
| DR-170 | **Editor chrome is drawn at its authored screen width at every zoom, and a canvas is told the zoom its layer applies.** Found building `#905`: the plan, rack and schematic canvases zoom in a `pushTransform` layer that `FlutterDiagramCanvas`'s stroke rules cannot see. **Measured at `#906`**: on the rack, which opens at about 3x, the selection outline (docs/04's 2 px) painted at 6 and 24 pixels at 3x and 12x, the hover ring at 4.5 and 18 and the port chip at 3 and 12; on the schematic at 4x, the connect rings painted at 8 and the band at 6. The chip and the overlay were `scaleWithGeometry: false` and the layer defeated the flag; the device box's rings were raw paints no flag reached. Ruled by the user: **chrome is drawn at its authored width at every zoom**, visibly thinner when a rack first opens, and **a line never paints thinner than half a physical pixel**, which moves the floor to physical pixels for scaling lines too and is what CR-082 already means on paper. **§11.169.6, added at `#907`: the rubber band is solid**, because a dashed band on this canvas already means a right-to-left intersecting marquee (CR-102); its colour was never open, since DR-114 §11.113.2 had ruled the band cursor chrome in a theme role, and this row said otherwise until then | canon §11.169 |
| DR-171 | **Outlet counts are derived, never stored.** Board `#558` was ruled on 2026-08-03 and **the ruling never reached canon**, while the code summed two authored `PowerProfile` integers that six of the 51 seed templates state against their own ports. **Measured 2026-09-14**: provided agrees with outlet ports on all 35 templates that state it, no conductor in any starter lands on a power inlet, and **`LinkClass.powerCord` is never derived** (`#908`), so a power connection is a conductor landing on an inlet-role power port rather than a link of that class. Ruled: provided counts outlet-role `power.*` ports; **the stored fields are deleted**, the project format advancing to 6 and the device template and archive formats to 3, and each migration re-hashes a template only where its stored hash attested the old bytes, so tamper evidence survives. **Consumed is resolved per device**: the cords drawn to its inlets where any are, none where only a PoE powered-device port is wired, and otherwise one per inlet port, **counted from ports and said to be**, because the user's company draws cords for PDU-fed gear and not for everything. Cords-only with the rest unknown was refused, since every starter rack would read `outlets 0/N` and `PWR-003` could not fire. The chip strip, `PWR-003` and its remedy read one resolution. **§11.170.8, added building it: an empty port list is unknown**, since AC-049 lets a template be saved before its ports are entered; **§11.170.9: the chip says the split on hover only**, the user's choice over a tilde or a dimmed figure | canon §11.170 |
| DR-172 | **The undo depth is a per-machine preference from 50 to 1000, applied at once, and a full history says so once per document.** Canon §10.12(a) asked for the setting in August; board `#560` found `UndoStack`'s 200 a default neither stack ever passed, and the oldest step dropping silently against AC-058 D5. **Measured first**: the status line never clears itself, docs/03 §11.1 budgets 200 entries with no hard cap, and no per-machine settings surface existed. Ruled by the user: **`prefs.json`, edited in a new Edit > Preferences**, while File > Project settings keeps what travels in the file; a **whole number from 50 to 1000**; **immediately**, dropping the oldest steps at once and saying how many; the full notice **once per document**, since a notice on every dropped step would own a line that never clears; and **one setting for the document and the Device Builder**. Decided building it: the field commits on Enter or Close and never on clicking away, because typing 60 on the way to 600 would drop history, and a resize goes through the controller so `editsSinceSave` stays honest. A §8.3 scope addition: the app's first per-machine settings surface | canon §11.171 |
| DR-173 | **A matrix's de-embedded zone audio is a stereo pair per zone, on two balanced 3-pin blocks.** Deferred by DR-014 §11.14.7 as `#112`: V01 and V03 modelled each zone as one mono 3-pin port, as the catalogue specification said, while a matrix de-embeds in stereo. Ruled by the user: each zone is a `stereoPair` set of an L and an R port, so one drag is one cable and dragging one half elsewhere splits it (DR-014); V01 goes from 8 zone ports to 16 and V03 from 16 to 32. Refused: one 5-pin block per zone, which hides the pair and can never split. The user's trade fact bounds it: the Triad TS-AMS kind cannot split zones and the ELAN EL-IPD-MTX-8CH kind can, so an HDMI matrix is the pair case, and a channel-splitting device is authored as mono channels. V02's S/PDIF outputs stay one port each. Decided building it: the pairs are numbered unpadded (`AUD OUT 1 L`), because the label grammar refuses a padded grouped counter and every seeded pair already reads that way | canon §11.172 |
| DR-174 | **A set on one cable draws one pennant on a bracket, and a split set draws a pennant per pin.** Board `#111`, ruled by the user on the board on 2026-08-01 and never recorded: a bracket across an atomic set's pins only when every member has a conductor end on one and the same link, read from the document and not the drawing. A split set (DR-014) or a partly wired set draws no bracket, and each wired member keeps its own pennant. Ruled 2026-09-15: the one pennant is centred on the bracket, not on the first member's pin, and the bracket takes the leader's signal colour and stroke, not a neutral grey. Measured: the label layer read only `conductors.first`, so an intact pair's second pin was unmarked; all 70 seeded atomic sets are two adjacent pins on a left or right edge | canon §11.173 |
| DR-175 | **The registry parity gate holds the seed to the specification's family table for the descriptive fields.** Board `#81`, from the DR-010 agent's mutation M13: `registry_parity.py` checked hue, dash and weight against `pal1_check.py` and was blind to a family's display name, tag, default connector, direction and topology, which only the starter goldens caught, with a failure that says to regenerate. Ruled by the user: the gate compares the seed with `docs/catalog/seed-devices.md` §4.4, exactly for name, connector and tag once markdown formatting is removed, and by the cell's leading symbol or word for direction and topology, with the id sets matched both ways. A disagreement is fixed in whichever file is wrong. Refused: a snapshot golden, reworded golden failures, and keeping the gate blind. Measured: all 57 rows already agree | canon §11.174 |
| DR-176 | **Your rack presets are saved from a rack, kept per machine, and sit beside seeded presets you can hide.** DR-016 (§10.12(c)) made the starting racks editable presets in August and named no surface, store or rule for the seeded eleven, and nothing was built. Ruled by the user: the rack inspector's Save as preset... captures the selected rack, your presets sit in their own group below the seeded ones in the Preset dropdown and the new-rack dialog, and they are renamed and deleted under Edit > Preferences; they live in `rack_presets.json` beside `prefs.json` under the data root and never in a project; the seeded eleven stay as shipped and can be hidden, not edited. Refused: a Preferences form for every field, both surfaces, storage inside `prefs.json` or as a library file, seeded presets always shown, and editing them in place | canon §11.175 |
| DR-177 | **A passthrough pair stays one front port to one rear port, and N04 stays unpaired.** Board `#557`. DR-087 §11.86.4 left open whether `PassthroughPairDef` should ever become one-to-many. Measured: of 51 seeded templates only `N04`, the 24-fibre LIU with 12 duplex front adapters over 24 rear splices, has faces that differ in count, and its 36 ports already carry the unpaired notice. Ruled by the user: no one-to-many pair; the model keeps one front key and one rear key, because the alternative is a codec change, a migration and a schedule column for one device. Refused: parking it under the v1.1 community catalog, and keeping `#557` open as the question | canon §11.176 |
| DR-178 | **A test that asserts a time runs in its own gate step, one test at a time.** Board `#843`: a docs-only commit failed the core suite when the text-bound schematic budget read 20.877 ms under suite load against 6.355 ms alone. Measured: 184 builds since, two failures and both the machine; alone today the 300-link cases take about 5 ms against a 16.67 ms frame; only `schematic_perf_test.dart` asserts a time, and the `perf` tag filters nothing. Ruled by the user: stopwatch assertions leave the package suites for one gate step of their own, run one test at a time, locally and in the pipeline; counts, digests and shapes stay in their suites; no budget changes. Refused: closing on the evidence, re-timing once before failing, and a ratio against a reference workload | canon §11.177 |
| DR-179 | **The file extensions are `.rppj`, `.rpdx` and `.rpda`, and every extension a build has written still opens.** Board `#782`, deferred by DR-096 §11.95.3 with M8 as the trigger and the letters unruled. Measured: the ticket and §11.95.3 named `.rmdev` and `.rmlib`, which DR-015 had already renamed to `.rmdx` and `.rmda`; no file stores its own extension, so it is a rename and not a migration; MSIX-7 registers the extensions before M8; and the product rename had turned DR-015's still-opened `.rackmate` into `.rackpal`, which no build wrote. Ruled by the user: `.rppj`, `.rpdx` and `.rpda`, now; `.rmpj`, `.rackmate`, `.rmdx` and `.rmda` still open and Save keeps their names; `.rackpal` comes off. Refused: renaming at M8, and keeping `rm` | canon §11.178 |
| DR-180 | **A project states its wiring standard, and a cable may override it.** Board `#80`: three of its four missing fields were settled by DR-010 and DR-026, and T568A/B was left. Measured: no model field states a standard; docs/08 prints `T568B` in its termination examples and turns `T5.01` on for a non-default T568A; the corpus's worked example stores `T568B` in `Conductor.colorCode`, the pair colour. Ruled by the user: `ProjectSettings` gains a wiring standard and a `Link` an optional override; a cable's standard is its override, else the project's, else unknown, never an assumed T568B; it is shown only on four-pair or RJ45 cables; a known standard prints beside the termination type, and a cable differing from the project turns `T5.01` on. Refused: a field per cable alone, one per end, and not modelling it | canon §11.179 |
| DR-181 | **A signal family may override its domain's glyph.** Board `#82`, whose sharpest disagreement was that `audio.speaker_cv` and `power.bonding` draw their domain's shape. Measured: it is 26 of 57 seeded families, not two, because the renderer draws only a domain's native glyph and §4.4 gives each family its own; a document carries its own copy of the registries. Ruled by the user: `SignalFamilyDef` gains an optional `glyphOverride`, set by the seed on the 26; the renderer gains ○ and ⏚; `registry_parity.py` checks the glyph column. Shape survives a greyscale print, and a constant-voltage speaker line is not a low-impedance one. Refused: the glyph as a domain property, and deciding it with family authoring. A saved project keeps its registry | canon §11.180 |
| DR-182 | **The roadmap keeps its sizes and retires its week total.** Board `#796`, with `#797` to `#799`. docs/09 §6 prices ten milestones at 44 to 67 weeks. Measured: M0 to M5 were priced at 29 to 44 weeks and took about 7.3; the v1 saga holds 20 epics; the Plan view is sized `L` with no row; nine epics have no size at all; §4's M4 heading reads `M` against §6's `L`. Ruled by the user: every v1 epic gets an `S`, `M` or `L` from its stories with the evidence named; closed milestones show actual duration beside the estimate; the week total is withdrawn rather than re-estimated, because the weeks described a team that is not the one building it; the M4 heading is corrected. Refused: a full re-cost in weeks, a caveat on 44 to 67, and leaving docs/09 alone | canon §11.181 |
| DR-183 | **A plan mark sticks at a floor size and grows with the plan above a crossover.** Board `#910`, from the user with a screenshot: it should *"stick at a certain size below a certain zoom level"* and grow with the underlay above it. **Measured first, and the screenshot was not**: the canvas computed `kPlanMarkerRadiusPt / scale`, a 7-point radius at every zoom from 5% to 3200% by construction, which is §11.168.2; the screenshot is a crop at an unknown zoom of a plan of unknown size and yields no number, so it was not converted into one. Ruled by the user, against four discs drawn at actual size and a chart of size against zoom: the radius is **`max(11 points / scale, (1/200) x planSize)`** in scene units, constant on screen below the crossover and a fixed piece of the drawing above it. The **floor rose from 7 to 11**, chosen from three sizes drawn at actual size with no reason attributed to the user beyond the choice; the glyph inside the mark goes from 8.05 points across to 12.65, and the constant-width device ring falls from 28.6% of the radius to 18.2%, further clear of §11.168.11's ceiling near 37% rather than nearer it. **1/100 was declined**: within rounding of the retired 1/110, so a mark would reach four times the floor at four times the fitted zoom, which is the *"massive"* size the original complaint was about. The plan's size is the **geometric mean of its two sides and not the longer one**, because §11.168.10 measured that anchor printing 6.87 points on a 2000x1500 plan, 5.15 on 1500x2000 and 10.20 on a 4000x1000 panorama. **It supersedes §11.168.2 in part** (§12.36) and keeps that clause's other half untouched: one place computes the radius, and the drawn mark and the hit box stay the same figure. The printed mark and the line weight are unaffected, a sheet having no zoom to cross a threshold with | canon §11.182 |
| DR-184 | **A floorplan turns in quarter turns, saved on the plan.** Board `#911`, from the user: the Plan view could not rotate a floorplan. **Measured first, and the defect was larger than the report**: `PlanUnderlay` carries no orientation at all, and the PDF lifter carries `/Rotate` down the page tree and never reads it, so a page stored portrait with `/Rotate 90` imports upright when rendered and sideways when lifted, which is the path the importer prefers. Ruled by the user: `rotationQuarterTurns`, an integer 0 to 3 clockwise on `PlanUnderlay`, which the screen and `T1.01` both follow (CR-086), on `SheetItem.rotationQuarterTurns`'s precedent. A free angle was declined because it resamples line art (DR-137), leaves empty corners on the sheet and puts trigonometry through every pin; a view-only turn because the screen and the paper would disagree. **A stored coordinate never turns**: pins, calibration points and outlines stay in image pixels and the exact integer map is applied at the point of use, so a build that drops the field shows the plan unturned with every pin still on its drop, and the reader version does not move. The file omits 0 and refuses anything outside 0 to 3. The buttons sit on the open plan's rail row beside `Calibrate…`, DR-144 §11.143.4's host; the first question offered a toolbar that does not exist (docs/15 §6, *"no fourth region"*) and the host was asked again. The keys are `Ctrl+Shift+Plus` and `Ctrl+Shift+Minus`, Acrobat's. The view turns about the canvas centre and keeps its zoom. A lifted page takes its turn from `/Rotate` and its preview is turned to match; a `/Rotate` that is not a multiple of 90 refuses the lift | canon §11.183 |
| DR-185 | **A floorplan page can be renamed and says which floor it shows, and an import asks.** Board `#912`, found while measuring DR-184. **Two modelled fields with no writer**: every page is named after its file forever, so three pages of one PDF read the same, and `PlanUnderlay.locationId` is never set by the one import caller, so the rail's room line never prints and DR-142's rule makes a floorless plan's strip list every unpinned carrier in the project. Ruled by the user: an `Edit plan…` dialog on the open plan's row with Name and Shows, one undo entry; inline editing and the inspector were declined. On import the name is the file's plus the page for a multi-page PDF, Shows is the Site tree's selection, and the same dialog opens pre-filled so `Enter` accepts; the import and its details are one undo entry, and dismissing keeps the proposal. **A plan becomes the tenth location carrier**: deleting a location clears the plans that show it, amending DR-021's census of nine (§12.37) | canon §11.184 |
| DR-186 | **`Ctrl+L` locks a rack device's position, and pins a schematic symbol where it stands.** Board `#913`. **Measured**: `Placement.locked` had no writer and compaction was its only reader, so drag, nudge, width and a bottom-trimmed shrink all moved a locked device; the schematic layout reads `SheetItem.pinned` and nothing wrote one, nor did any document hold CR-073's one schematic `Sheet`. Ruled by the user: a lock refuses moving and a shrink that would move it, and not a delete; `Ctrl+L` toggles the selection, the device inspector has a `Locked` checkbox, and a 🔒 badge marks a locked device as screen chrome that does not print. The schematic's `Ctrl+L` pins a symbol where the layout put it, now, under the same label; a first description of that option as doing nothing visible was wrong and is recorded. The first pin creates the one schematic `Sheet` | canon §11.185 |
| DR-187 | **The schematic holds its layout, and a symbol drags, nudges and pins.** Board `#914`, from the user: devices *"shift positions significantly"* when they are auto-placed, and it should *"preserve the relative location of devices, just expanding the canvas slightly"*. **Measured on the scene fixture**: adding two devices re-flows the sheet; pinning a symbol where it stands moves nothing while pinning it 24 by 8 away moves all five neighbours; and **with every symbol fixed, a new device lands exactly on top of an existing one**, so a free-slot rule is part of the job. Ruled by the user: the sheet keeps its layout and the positions go in the FILE, which **overrules DR-011.4's rejection of a `SheetItem` per device** (§12.38), against a session-only freeze that loses the arrangement overnight. They are written on the **first edit that would re-flow**, never on view, **as a CHILD of that edit's own undo entry**: §11.186.2 first said its own entry, two tests older than the ruling refuted it (one Ctrl+Z took back the arrangement and left the edit), and §11.186.2.1 replaced it. A stored position is honoured pinned or not, and pinned is what `Tidy sheet` spares. A drag or a nudge moves and pins (CR-068). **The arrows nudge when NO CARET is on screen** (§11.186.10, a correction: the clause first said *"no connect in flight"*, and the arrows are also how a pin is reached before arming, so sixteen tests refuted it). A run of presses is ONE undo entry. ↑/↓ carry a union label; ←/→ cannot, because `meaningDrift` holds `Arrow Right` to one meaning across scopes, so they carry the nudge in a note. **A drag shows a DASHED GHOST and the sheet lands on release** (§11.186.8), settled by the user after pricing three shapes: live re-routing is 0.72 ms on a 300-link house and 8.8 to 36.3 ms on a twelve-pod job against a 16.7 ms frame, and the expensive case is the sheet most in need of dragging. **`Ctrl+Shift+U` unpins and ships with the drag** (§11.186.9), because a drag pins and `Tidy sheet` spares a pinned symbol, so arranging a sheet by hand is otherwise what puts it beyond `Tidy sheet`'s reach. `Tidy sheet` sits on the domain filter bar and moves to the context menu when the drag lands (§11.186.7) | canon §11.186 |
| DR-188 | **RackPal is CAD-lite, and DXF interchange opens v1.3.** Board `#786`, from the user: docs/21's *"it is not a CAD package"* undersells a tool that calibrates plans, draws exact elevations and resolves cable footage. The reason is the user's and is trade knowledge: a precise drawing *"won't get altered and/or ignored by the installers"* is nearly impossible in this industry, documenting every change is *"unbelievably tedious"*, so the precision trade-off is negligible to the workflow. Precision is spent where it survives a site: calibrated plans, exact elevations, cable footage. **v1.3 is CREATED as a release band**, the first added since the roadmap was written, because v2 is *"the next product decision, not the next release"*. **DXF and not DWG**, declined on a LICENCE COLLISION rather than cost: the open writer is GPL-3.0, the commercial route is GPL-incompatible. Overrules docs/08 §9's `not planned` (§12.39). The Device Location Plan is in; **rack elevations are blocked on a WRITER, not a schema**: `Rack` already declares the whole physical envelope and five of its six fields have no writer and no reader | canon §11.187 |
| DR-189 | **The licence is AGPLv3-or-later, and a vendor's door is the CC0 catalog.** Board `#786`, from the user. **Reverses DR-036 §11.35.1 clause 2** (§12.40); the other four clauses stand. **The AGPL objection the question remembered is recorded nowhere**, searched across the tree, docs/, .okf/ and every commit message; the likely memory is `pdf`'s Apache-2.0 closing GPLv2, or §11.35.4's output exception. The census that admitted GPLv3 admits AGPLv3 unchanged, and the output exception carries over because AGPLv3 incorporates GPLv3 §7. **§13 is inert today** (desktop, no server, no telemetry); the value is prospective. **The real finding is that the project has never been licensed at all**: there is no `LICENSE` file and README line 168 still calls it TBD, so §11.35.4 has been undischarged since 2026-08-10. The exception text goes to a qualified reviewer, not to this author. **Vendor contributions arrive as CC0 data, never as source**, because CC0 flows into AGPL freely and the reverse would put product data under copyleft. **Provenance needs no ruling**: `TemplateProvenance` already answers which SHELF and not which author | canon §11.188 |
| DR-190 | **Close in the Device Builder asks before it discards.** Found writing docs/21 (`#924`): `Close` unmounted the builder and destroyed a dirty in-memory draft without a word. The user chose the recommended option: a dirty draft gets the project's own **Save / Don't Save / Cancel** prompt (docs/03 §9.5, all four of its rules), a clean one closes silently. `Save` on a draft that cannot be saved (AC-049) saves nothing and says why. **DR-099 §11.98.4 stands**: it refuses when a draft would be REPLACED on the way to something else; leaving is the act here | canon §11.189 |
| DR-191 | **A room's plan estimate follows its inputs, and says why when it cannot.** Found writing docs/21: the figure was derived only when an outline was drawn, so the natural order computed nothing and a late input never filled it. The user chose the recommended option: **every transaction re-derives it** through `addConsequence`, in the same undo entry; a plan figure that stops deriving is **cleared** (a guess must not stand, G4); a typed figure is never touched (§11.49.3). **Installed by the controller, not by a view**, unlike DR-187's freeze. The helper line names the missing input, gives the multi-floor case its own sentence, and loses its `AC-024` citation | canon §11.190 |
| DR-192 | **The Schedule shows the waste factor, per cable type.** Found writing docs/21: `cableWasteFactor` was applied by nothing, while `cableFootageOf` computed a finished takeoff nobody called. The user chose the recommended option: the Schedule lists each media type's known footage **raw and with waste**, with its unknown, estimated and bound counts. **No row is inflated and there is no grand total with waste**, since feet of Cat6 plus feet of RG6 is not a thing anybody buys. The help line now names the Schedule | canon §11.191 |
| DR-193 | **The validation keys work from every view and go where the fix is.** Found writing docs/21: `F7`/`F8`/`Shift+F8` were `KeyScope.global` and handled only by the Rack view. The user chose the recommended option: **the shell handles them**, and `F8` switches to the view that can fix the finding (Rack for a racked device or a rack, Schematic for a field device or a cable, Site for a floorplan), selecting the subject, in the engine's order, wrapping. **The drawer stays on the Rack view**; putting it under every view was offered and not chosen | canon §11.192 |
| DR-194 | **A local diagnostic log ships now, because builds are already in the wild.** Found by the full-tree review (`#97`): release builds report nothing, and the §12.4-safe storage log had no sink. The user chose the recommended option: **§9.9's local half is pulled forward** under Epic `#786`, as a capped local log (fatal errors as type and frames, never the message), a startup-failure dialog and `Help ▸ Open diagnostics folder…`. **M8 keeps** the opt-in remote half, CR-096's reconciliation and its exit clause | canon §11.193, §12.41 |
| DR-195 | **The seed catalogue's explicit values stay explicit.** 116 of 161 `avoid_redundant_argument_values` infos were catalogue facts such as `requiresClearanceAboveU: 0`, and under CR-114 an explicit zero is measured. The user chose the recommended option: **a documented file-wide ignore in the catalogue files, everything else swept**, pin re-measured, docs/11 §7 unchanged. **Corrected in the same chapter** (§11.194.3): the 45 non-catalogue sites were all test fixtures, which `#246` had already argued are data too, so they keep their values under the same ignore; only `cascade_invocations` is swept. Pin 233 to 23 | canon §11.194 |
| DR-196 | **The two canvas screens are not split before M7** (`#98`'s verdict). `wire_trace.dart` moved to core (`#931`); `json_codec.dart` untouched; the two 5,000-line `State` classes wait for M7, whose keyboard and screen-reader work goes through both. The user chose the recommended option | canon §11.195 |
| DR-197 | **A CSV import offers one new cable type per id, and lists every spelling.** Two spellings deriving one id showed two boxes and made one type. The user chose the recommended option: **one row per id**, named by the first spelling in sheet order, every spelling kept as an alias, declined together | canon §11.196 |
| DR-198 | **A file another program has locked is named as locked when it will not open.** A sharing violation on open read as *"something went wrong"*. The user chose the recommended option: its own error, `OpenLocked`, naming the usual holders and the remedy, **OK only**, recents kept | canon §11.197 |
| DR-199 | **An import refusal's title names the cause.** Every device library and template refusal was titled *"That is not a device library"*, including a file that is one but too large or from a newer RackPal. The user chose the recommended option: **a title per cause** (not that kind of file; needs a newer RackPal; too large to import; could not be read), details unchanged | canon §11.198 |
| DR-200 | **A path too long for Windows is named when a file will not open.** It read *"something went wrong"* on open while save has named it all along. The user chose the recommended option: `OpenPathTooLong`, **both numbers** (length and `kWindowsMaxPath`, 259, as save states it), OK only, recents kept | canon §11.199 |
| DR-201 | **The collision policy leaves Project Settings, because it governs nothing.** Allocation cannot collide and typed entry never read it. The user chose the recommended option: **the row is removed**, the stored value kept on the wire untouched (CR-117), `resolveDesignatorCollision` deleted. Typed duplicates are unchanged: allowed, flagged by validation | canon §11.200 |
| DR-202 | **Save replaces a version nothing is placed from, and the change class speaks only for placed devices.** Found with a regression of DR-077 §11.76.3: the shell rebuilt the save closure, so a new template's second Save minted `tpl.foo_2`; fixed. The user chose the recommended option twice: **Save replaces the newest version until a device is placed from it** (a seeded `@1` is never replaced), and **the change chip shows only when devices are placed**, against the version they stand on, as `Breaking · 4 placed` | canon §11.201 |
| DR-203 | **Size and mounting is asked once, on Identity, and what follows from it is derived.** How it mounts, front and rear RU and width sit in one block; `Occupies` and the span are derived on every occupancy edit, and the rear height follows the front until typed. Side-mounted and in-furniture gear take no rack units (the user's trade answer); a hosted card and a rear-only lacing bar can now be saved; Passthrough moves to the Ports toolbar. Chosen by the user from a mockup | canon §11.202 |
| DR-204 | **A device can be set on a shelf, and it is drawn there.** Nothing could create a `ShelfPlacement` and nothing drew one. Drag onto a shelf and an inspector picker, both; **any device may sit on a shelf** (the user's trade answer: rack kits are separate, device-specific and often unavailable), with a status note for rack-ear gear; a new optional **`shelfWidth`**, since `chassisWidth` is always a 432 mm default; hosts drawn and selectable; drag along reorders, onto another shelf moves, onto free rails mounts, off the rack goes to the Staging Bin and elsewhere deletes (§11.203.9); deleting a shelf asks; the header shows load against capacity, and a loaded shelf is labelled in its header only while its hosts' port chips wait for hover or selection (§11.203.10) | canon §11.203 |
| DR-205 | **The Staging Bin ships.** CR-032 ruled it into v1 and nothing built it; found when DR-204's shelf deletion needed it. A strip under the rack canvas, shown only while it holds something; in by deleting a shelf, a release off the rack (wiring kept), `U`, and Shrink Rack; Shrink Rack preselects its bin option when compaction cannot fit everyone, and option 1's partial form stages its leftovers (§11.204.6); out by a return chip (`Return to RK-1 U21`, or `Return to SHF-1` via the new `lastHostDeviceId`) or by dragging a chip | canon §11.204 |
| DR-206 | **The schedules say what a run's lifecycle is.** `ScheduleEntry.lifecycleStatus` was read by nothing, so existing, removed and future runs printed as new (`#576`). docs/08 §3.4 had already specified an optional `LIFECYCLE` column, which on T6.11 promotes every retrofit job to 11×17. The Pull Sheet groups rows into TO PULL (new, design intent), EXISTING, TO REMOVE and FUTURE; T6.11 carries a suffix on `CABLE ID` (`W042 EX`, `RM`, `FUT`, `DI`, none for new) with a key in the header | canon §11.205 |
| DR-207 | **The legend's cable-type key prints the ten named types always, then what the set uses.** docs/08 §5.4 never said which; three of four starters carry no cables, so an in-use key would be empty and would not contain the ten AC-054's photocopy test needs, and every family will not fit one sheet | canon §11.206 |
| DR-208 | **The legend explains what the set prints; its notes ship seeded.** Symbols and conventions cover the device marks, plan markers, lifecycle borders, hatch, RU span and load gutter the sheets actually draw; net-label stubs, tag pills, junction dots, OPEN ends and revision clouds join in the change that first prints them. Abbreviations and notes are seeded now and made editable in their own Chapter | canon §11.207 |
| DR-209 | **The front matter gets a `Sheet set…` dialog, and the legend's notes are its first section.** Nothing writes `ProjectInfo`, so the title block needs an editor anyway; the user chose the recommended option twice: a new File-menu dialog beside `Export PDF…` (M6-A1's title block joins it), and **rows with add and remove**, not a text box. Absent key means seeded; a list, even empty, prints exactly; `Restore defaults` returns to absent; tag prefixes stay derived | canon §11.208 |
| DR-210 | **The cover puts its index on the right, and the title block becomes editable.** The user chose the recommended option four times: `T0.00`'s drawing index is a **full-height right-hand column** (a 40-sheet index fits nowhere else); `File ▸ Sheet set…` gains Title block (Project, Client and site, Integrator, Sign-off) and Cover sections **grouped as printed**; `approvedBy` **prints on the cover**; a cleared project name is **refused with a reason**. New `ProjectInfo.scopeNarrative`, absent when unwritten; a cleared optional field is stored absent | canon §11.209 |
| DR-211 | **The cover's rack strip, and passives leave the equipment list.** Power is **VA and BTU/hr**, RU is **per face**, a strip too long is **capped with a named row and a notice**. In the user's words, *"leave out passives from an equipment list, but note them on the BOM"*: the cover counts active equipment, passive is the whole `Passive & Mechanical` category, and T6.30 lists passives by type in its materials section (M6-F6, `#970`). The seed catalog states a passive's power as **0 W / 0 VA**, since five of Whole House's ten unknown power contributors were steel panels | canon §11.210 |
| DR-212 | **The drawing index: both numbers, flat, ranges collapsed, sub-columns on overflow.** The user chose the recommended option four times: each row carries the **set position and the NCS id** as every title block prints both; **flat, in set order**; consecutive pages of one schedule collapse to **one row with its page count**; a set the column cannot hold **flows into two then three sub-columns**, and beyond that exports with a notice naming what the index omits | canon §11.211 |
| DR-213 | **T6.30's subtotals stay whole-rack, and the materials are one list.** With passives off the equipment rows (DR-211), the user chose the recommended option twice: a rack's subtotal still counts them and says so (`26 DEVICES + 5 PASSIVES (SEE MATERIALS)`), matching the cover and the elevation gutter; and a **MATERIALS section at the end**, one row per item and status with quantity, make and model and a `WHERE` split by rack. The one-row-per-device bijection becomes one row or one materials unit per device | canon §11.212 |
| DR-214 | **T0.02 leads with the project-wide exceptions, then errors first, and keeps every signed reason.** The user chose the recommended option four times: rule overrides and project-wide mutes **first**, with reason, author and date; open findings **banded by severity, errors first**, locus a column; acknowledged findings **their own section**; an acknowledgement whose finding no longer occurs **still prints, marked**. Continuation sheets are `T0.03` on; an empty sheet states that the checks ran and when | canon §11.213 |
| DR-215 | **Zones on drawing sheets only, from the lower right; revision entries and clouds park on project history.** The 0.22 in zone band and grid go on **drawing sheets only** (elevations, plans, interconnect), not the cover, legend, T0.02 or T6.30; zones run **from the lower right**, the user's reason being that ANSI C/D sheets fold out of a binder showing the ASME markings when folded. M6-G3's entry writer parks on HIST/3 (`#658`) and M6-G4's clouds on HIST/5 (`#660`), since both need project history | canon §11.214 |
| DR-216 | **Export for construction is its own command, the stamp is on every sheet, and the logo sits top-right.** The user chose the recommended option three times: `File ▸ Export for construction…` beside Export PDF, remembering nothing, stamping only with zero open errors and otherwise exporting unstamped with the reason; the stamp **on every sheet above the revision block** (a full-width band above the strip on ANSI A); the logo in **a box at the top right of the identity band**, set in Sheet set. The revision block's `issued` flag parks with G3 on `#658` | canon §11.215 |
| DR-217 | **The logo imports from PNG, JPEG, PDF or SVG, is stored as a raster, and is previewed where it is set.** The user chose all four formats over the recommended three; SVG is cheap because the `pdf` package draws it as a PDF that the vendored pdfium already rasterises. PNG and JPEG are stored verbatim (flattened only over alpha); PDF and SVG render once at import to fit the 100 x 45 pt box at 600 dpi. The Title block section shows a thumbnail with Replace and Remove. **The logo sits in a cell spanning the title block's upper band** (refining DR-216, whose identity band is 26 to 49 pt tall), and **the ANSI A strip prints none** | canon §11.216 |
| DR-218 | **On the ANSI A strip, the legend reference moves to row 1.** The compact strip put CR-023's `SYMBOL LEGEND: SEE SHEET T0.01` last on its second row, which overflows on Whole House and printed it as `SEE S…`. The user chose row 1, which holds only the project name and the sheet title and has about 480 pt free. docs/08 §2.1's *"under the active scheme"* corrected to the id CR-023 rules | canon §11.217 |
| DR-219 | **T6.30's rollups are sections with their own headers; the outlet map lists assignments; an acknowledged support still prints.** The user chose the recommended option three times: each rollup a titled section with its own header row, re-printed on a break; the outlet map one row per drawn cord plus a free count per provider; an acknowledged `RCK-013` keeps its rear-support line with the reason in NOTES. CR-030's ear-kit advisory, never built, is built as `RCK-014`, **a §8.3 amendment** the user approved: the catalogue goes to 8 + 6 + 16 | canon §11.218 |
| DR-220 | **T6.20 lists a home run open at either end, in room bands, and says which end.** The user widened canon §4.3's *"unbound rack end"* to an `OpenEndpoint` at the rack **or** the room, over the recommended rack end only; docs/01's *"terminated with no device on it"* was not taken, since on Whole House it lists every run. ANSI A landscape in room bands, rows in cable-ID order, ten columns including an `OPEN` column reading `RACK`, `ROOM` or `BOTH`. Pages `T6.20` to `T6.29`, then from `T6.60` ahead of the equipment list's overflow | canon §11.219 |

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

**Context.** Three documents specified three containers for `.rackpal`: plain JSON, "not zipped,
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

One implementation, in `rackpal_core/persistence/migrations.dart`, specified in
[the file format specification](02-data-model.md#6-the-rackpal-file-format), with a **golden corpus**: every historical schema version
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
a `.rackpal` work. Catalog corrections do not propagate in v1; the badge is the entire remedy.
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
RackPal never needs a general orthogonal router, and that a full deterministic recompute is both
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

**8 + 6 + 16.** DR-020 added `LEN-002`, DR-132 restored `ELE-005` and DR-219 §11.218.4 added `RCK-014`; the catalogue is enumerated once in
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

**Status: SUPERSEDED by DR-088 (canon §11.87, §12.27), 2026-08-25.** The Riverpod half was never
built: at v0.4.63 the package is in no `pubspec.yaml` and `ProviderScope` appears in no Dart file.
The state management is **constructor injection of one `AppServices`**, `SimpleNotifier` in core and
`ChangeNotifier` in `rackpal_ui`. **The rest of this ADR is unaffected and still binding**:
`DocumentController` as the single mutation gate, `@internal` setters (AC-013), the three-tier
epoch-driven derived pipeline, `lodLevel` in every scene-builder signature and cache key, and the
rejection of `ChangeNotifier`-on-the-document. The text below is retained as the record of the
argument, per canon's Part 4 preamble.

**The `VERIFY:` below is the point of the supersession, not a footnote to it.** It reads *"before the
provider layer is written"*, and it never fired because that layer was never written. A precondition
attached to work that does not happen is not a tripwire. The remedy is the dependency-table gate
(canon §11.87.7), which asserts a claim rather than scheduling a check.

**Original status:** Accepted. **VERIFY:** Riverpod 3 API surface before the provider layer is written.

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
**DR-091 §11.90.4 defers the whole `Ctrl+n` mapping past M6**, and the reservation below survives it untouched. `Ctrl+3` is **reserved** for the interactive Rear Panel view, which is v1.1 (CR-071); in v1 the
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

**Context.** One document specified four packages with `rackpal_export` and `rackpal_ui` as
siblings that cannot see each other, the invariant that keeps the PDF path isolate-safe. Another
specified a single `lib/` tree with the Flutter and PDF backends in one directory and
`TextMeasurer`/`PdfFontMeasurer` in the core tree, which makes core depend on `package:pdf` and
breaks the architecture's own `no_flutter_import_test`. ADR-013's single-measurer ruling forces a
resolution.

**Decision.** Per CR-083, **five packages**: the dependency is inverted rather than the core
contaminated:

```text
rackpal_core    pure Dart. NO flutter, NO dart:ui, NO package:pdf.
                 model, commands, derived, routing, draw/ (scene builders, hit_test, BoundsCanvas),
                 persistence, units/, idformat/, library/.
                 Declares abstract TextMeasurer + TextMetrics.
rackpal_text    pure Dart. core + package:pdf (PdfTtfFont ONLY). ~5 files.
                 The single concrete TextMeasurer.
rackpal_export  pure Dart. core + text + package:pdf. PdfDiagramCanvas, sheets, furniture,
                 tables, assembly. The isolate entry point.
rackpal_ui      flutter. core + text. FlutterDiagramCanvas, render objects, widgets,
                 canvas/input/.
apps/rackpal    everything + plugins.
```

`rackpal_ui` depending on `rackpal_text` is harmless, `package:pdf` is pure Dart and
isolate-safe. The invariant that matters is preserved and **mechanically enforced**:
`rackpal_core`, where the scene builder lives, has no concrete font engine and no `dart:ui`; it
receives a `TextMeasurer` by injection, and `no_flutter_import_test` keeps banning
`package:flutter/`, `dart:ui` and `package:pdf/` in core. Hit-testing splits by concern (CR-084):
the *geometric* test (`DiagramScene.hits`, point-to-segment distance, nearest-hit) lives in
`rackpal_core/draw/hit_test.dart`, pure, synchronously testable, reusable by the read-only
mobile shell; the *pointer plumbing* (one query per frame, spatial hash, cursor policy, hover
throttle) lives in `rackpal_ui/canvas/input/`.

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
| **10.3** | Pricing and licensing model | **MOOT: DR-006** | **Nothing to price.** RackPal is an internal tool; no commercial release is planned. Retained as the record of the argument: if DR-006 is ever reversed, 10.3 reopens exactly as written |
| **10.4** | Does the device builder have to be in v1 | **ANSWERED: DR-003** | **(a) Yes. M4 stays where it is.** Confirms the recommendation |
| **10.5** | Metric or imperial default | **ANSWERED 2026-08-03** | **Imperial default, one obvious toggle.** Confirms the recommendation. The default is already in the code; the toggle is owed (board #562) |
| **10.6** | Is the schematic a client deliverable or an internal tool | **ANSWERED, DR-005** | **(a) Client deliverable, invest in drafting polish.** **Reverses** the recommendation. Orthogonal to 10.1 |
| **10.7** | Multi-sheet timing | **ANSWERED: DR-004** | **(c) Never.** One `Sheet` plus domain filtering, permanently. The entity remains |
| **10.8** | Cloud-ready investment | **ANSWERED 2026-08-03** | **(a). Spend nothing further; RackPal is a local application.** Confirms the recommendation. The six cloud-ready properties are retained in full; [02 §8](02-data-model.md#8-cloud-readiness-properties) is ratified as the conflict-unit page. Update checks and API-key publishing to PM services are **not v1 scope** |
| **10.9** | Generic archetypes forever, or a real-SKU catalog | **ANSWERED 2026-08-03** | **Shipped catalog stays generic; user templates may carry real SKUs.** Archetypes must be editable; DR-015's `.rmda` is the sharing mechanism. `T6.30` stays an equipment list, not a BOM (AC-055) |
| **10.10** | macOS in v1 | **ANSWERED: DR-009** | **(b) Windows and macOS from v1.** **Reverses** the recommendation, which was explicitly not a ruling. The register it demanded is [13-macos-debt-register.md](13-macos-debt-register.md) |
| 10.11 | What the beta gate actually is | **DEFERRED, with a trigger** | Held until M5 lands and the UI is largely frozen. **Must be answered before the M6-J5 recruiting ask**, not before M9 |
| **10.12** | Small calls needing an owner | **ALL SEVEN SETTLED 2026-08-03** | (d) by DR-002. (a) keep 200, make it a setting (#560). (b) autosave while working, never while idle. (c) editable rack presets, **DR-016**, a scope addition under §8.3 (#561). (e) opt-in local crash log only. (f) RackPal, with a mascot and three scoped surfaces (#563–#565). (g) user-visible, and the catalogue's size is docs/02 §5's to state |
| 10.13 | The three to answer first | **retired** | All three are answered |

They are ordered by blast radius, and the first one was a fork in what the product fundamentally
is, until it was answered.

## 10.1 Draw every wire, or net labels by default: the fork

> **ANSWERED — DR-001: net labels by default.** Drawn wires appear on a domain filter, `Alt`-hover
> or focus. The argument below stands as the record of how the question was reasoned about; **the
> recommendation at the end of this section is void — DR-001 reverses it** (canon §11.1).

**It was the most consequential open question in the project, and not a rendering preference. It
decided what RackPal is.**

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
| a | Undo depth: the cap is 200 with a status-bar signal (AC-058 D5). Is 200 right? | **Keep 200, and make it a setting.** Confirms the recommendation. The cap is already 200 (`undo_stack.dart`'s `maxEntries`) but is a **constructor parameter, not a user setting**; exposing it is owed work. **Built 2026-09-15 as DR-172** (§11.171): a per-machine preference in Edit > Preferences, 50 to 1000, applied at once, with the full-history notice once per document | Board #560 |
| b | Autosave interval, and whether recovery is silent or prompted | **REVISES the recommendation: autosave runs while the user is WORKING, never while they are idle.** The 30 s interval stands; a tick with nothing new to protect must write nothing. This **exposed a live defect**, since fixed. **The prompt-on-recovery half is unchanged** | `be23d89` |
| c | Default rack height in the new-rack dialog | **SUPERSEDES the recommendation: the starting racks become EDITABLE PRESETS.** 42U survives as the shipped seed, so the recommendation's substance lives on; what changes is that the preset set stops being fixed. A **scope addition under roadmap §8.3**, ruled as **DR-016** | Board #561 |
| d | Are the four starter projects residential-only? | **Three residential, one small commercial.** Settled by implication of DR-002; they double as the domain-coverage argument for residential-primary, commercial-capable | DR-002 |
| e | Telemetry at all, and if so opt-in or opt-out | **Opt-in, local crash log only. Telemetry is POST-v1.** Confirms the recommendation. Accepted consequence: §10.4's miss-rate instrumentation is a manual user-interview exercise, not a dashboard | CR-096 |
| f | Product name and branding investment | **OVERRULES the recommendation to defer.** The name is **RackPal**. Branding is a Protogen mascot, **Riley the RackPal**, in neutral warm white and greys so it never competes with the eight domain hues. Three surfaces follow and **they are scope, not styling**: an opt-in in-app assistant, a first-run onboarding flow, and user-customisable UI accent colours. RJ-017 rejected branding as a v1 *requirement* and is not reversed; this schedules the work | Board #563–#565 |
| g | Is [the rule catalogue](02-data-model.md#5-the-v1-validation-rule-catalogue--three-tiers) user-visible documentation or internal? | **User-visible, in-app, linked from every finding.** Confirms the recommendation. **The file deliberately does not exist**: canon §5 *is* the catalogue and CR-021 says so, so this is *publish that section*, not *write a new file*. And it is **28** rules since DR-020, not the 22 this row inherited from AC-040's arithmetic slip | Feeds M5-F3 |

## 10.13 The three to answer first: RETIRED

**All three are answered: §10.1 by DR-001, §10.2 by DR-002, §10.4 by DR-003.** This section has
served its purpose and carries no remaining instruction. Everything still open can wait until
there is evidence, which is the entire point of shipping M1 as a real release rather than as a
foundation.
