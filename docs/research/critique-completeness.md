# RackPal Design: Completeness Audit

**Audit limitation, stated up front:** the `pdf` document was supplied truncated; it begins mid-sentence inside §9.2. I audited it against its own §12 decision summary (which enumerates §1–§8), its §10 file layout, and its §11 build order. Findings that depend on §1–§8 content are marked *(inferred)*. Everything else was read in full.

Six documents, ~55,000 words. They are individually excellent and collectively not yet a single specification. The dominant finding is that **the four consumer documents (rack, schematic, device-builder, pdf) were each written against a different mental model of the core entities, units, and validation philosophy than the data-model document specifies**, and the architecture document adds a fifth. None of these is a small reconciliation.

---

## (A) Unmet or partially-met requirements

Checked against the seven core requirements and the three confirmed product decisions.

### A1. Req 1 (RU height): **substantially met**, three gaps

- **A1.1** No agreed maximum. `ux-rack §4.2`: "range 1–58." `architecture §10.1`: "RU per rack: target 45, hard cap 60." `data-model`: unbounded. Pick one.
- **A1.2** RU origin is off-by-one between documents (see B14), a defect, not a gap, but it lands on this requirement.
- **A1.3** No spec for a rack whose front and rear rail counts differ, or for open-frame 2-post depth semantics (`usableDepth` is meaningless on a 2-post). The catalog ships 2-post presets.

### A2. Req 2 (GUI device builder + I/O): **met for ports, not met for the type system**

- **A2.1: Major.** There is **no UI anywhere for creating a connector type, a signal family, a media type (outside Structure), a colour scheme, or a compatibility rule.** `data-model §3.4` makes user-extensible registries and user-authored rules the central argument for rejecting enums ("can't be authored by a user for a proprietary Cresnet variant, and can't be inspected by the user to understand why the app is complaining") and then no document designs that authoring or inspection surface. The device-builder's Signal combo offers "Other…" with no follow-on spec. Either build a registry editor or drop the user-extensibility claim (and with it much of the enum-rejection argument).
- **A2.2** The connector **footprint table** (`ux-device-builder §2.6`, 13 entries) is the input to the auto-panel-layout that "produces a recognizably correct rear panel for every one of the 58 seeded templates with zero authoring." The seeded catalog uses ~35 connector types. Missing footprints include: SpeakON, binding post, TOSLINK/JIS-F05, IDC-110, Splice, LC-Duplex *(present)*, SFP/SFP+/SFP28, XLR5, TRS-6.35, USB-A/B/C, DC-2.1, IEC C13/C19/C20, NEMA 5-20R/L5-30P, BattConn, Breaker, Lug, Punchdown. The claim cannot be true as written.
- **A2.3** No undo/redo model for the device builder or the Structure editor. Both are heavy editing surfaces outside `RackDocument`, and `architecture §4` scopes the command stack to the document. `ux-device-builder §2.5` asserts "Delete | Undoable" with no mechanism.
- **A2.4** No empty state for a blank new template; no error design for an unparseable Quick Add line; no autocomplete spec despite "the DSL teaches itself" being the discoverability argument.
- **A2.5** The label-pattern language cannot express its own catalog. `A03` uses `"{FL,FR,C,SL,SR,SBL,SBR} {+,−}"` for 14 ports, two cycling sets of period 7 and 2 running simultaneously. The grammar defines `{a,b,c}` as a flat cycling set with no independent period; the naive expansion yields `FL+, FR−, C+, SL−…`. Either add period control to the grammar or fix the catalog entry.

### A3. Req 3 (physical connections → wiring plan): **met for point-to-point only**

- **A3.1: Major.** **Multi-conductor links have no UI in any document.** `data-model` calls this load-bearing decision #4, "a 16/4 speaker cable is **one Link with four Conductors**, not four Links. One cable = one row on the pull sheet", and specifies `Conductor{role, fromPortId, toPortId}`, `PortGroup.atomicConnect`, and `groupRole` values (`Y/Pb/Pr`, `L+/L−`). No document specifies the gesture that creates a 4-conductor link, how conductors are displayed, edited, or how a partially-connected group behaves. Component video and stereo speaker runs, both in the seeded catalog, are unbuildable as designed.
- **A3.2** **No cable-length mechanism.** `Link.calculatedLength`, `cutLength`, `slackPercent`, `StructureDrop.calculatedLength: Extent?`, the schedule's `Len` column, and `ux-schematic §2.1`'s status-bar "est. 12'" all imply an estimator. No document specifies one, and none can exist; there is no spatial model of the building and cable dressing is explicitly out of scope. Meanwhile **eight DRC rules depend on length** (`LEN-001..006`, `BUS-004`, `BUS-005`). Decide: user-entered only (and say so), or drop the rules.
- **A3.3** Connections can only be created on the schematic. The rear-panel view is called "the *installer's* view" and the schedule table makes endpoints read-only; the rack elevation has no wiring affordance. Probably correct, but never stated, and it makes the rear-panel view (the printed, taped-in-the-rack deliverable) read-only with no path to fix a wrong jack while looking at it.
- **A3.4** Devices in the Staging Bin keep "all their wiring intact" (`ux-rack §2.4`) but `ux-schematic §3.2` phase 1 assigns layers from rack position. Unplaced devices in the schematic layout are undefined.

### A4. Req 4 (colour-coded by cable type): **deviated from, defensibly, but not surfaced**

- **A4.1: Needs sign-off.** The requirement names ten cable types. All three UX documents colour by **domain** (7–8 buckets). Consequence: *Analog RCA* and *speaker level* are the same orange; *S/PDIF* and *TOSLINK* are the same vermillion. Two pairs of user-named types are indistinguishable by hue. The dash/weight/tag argument is technically correct and I would not reverse it, but this is a visible deviation from a stated requirement and should be confirmed explicitly, not absorbed silently.
- **A4.2** Following from A4.1, **per-cable-type colour override is not in v1** (`architecture §12.3`: "Later: user-customisable cable colours"). Given the requirement as written, this belongs in v1, or the legend must be provably unambiguous for the ten named types on a greyscale laser print, which is a testable claim nobody has committed to test.
- **A4.3** `data-model` has no `SignalDomain` entity. `SignalFamilyDef` carries `color`, `dashPattern`, `lineWeightPermille`, `glyph` per family (43+ entries) while `§3.4` argues colour must live on the domain (7). There is nowhere to define the domain palette.

### A5. Req 5 (board-diagram / schematic idiom): **met**

Only gap: "port pinouts" in the requirement. Pin-level data is modelled (`conductorCount`, `polarity`, `groupRole`, `pinoutVariant`, Euroblock pole counts) but never rendered. Arguably satisfied by connector glyphs + `J###` designators; confirm.

### A6. Req 6 (Structure device): **met in the model, under-built in the UI**

- **A6.1** `StructureGrade` (grade1/2/3), `ProjectSettings.defaultBundleGrade`, and the "Add outlet: Grade 2 creates one bundle with four drops" flow that `data-model §3.8` calls *the reason bundles exist*, **have no UI**. The Structure editor is a room × media matrix with no grade concept; the word never appears in `ux-device-builder`.
- **A6.2** "Conduit (empty)" is a media type in the Structure matrix. It creates a drop, which creates a Port on the Structure device, which is connectable, an empty conduit is not a cable. Needs a non-port drop kind or removal.
- **A6.3** The Structure device appears in the rack editor palette (`ux-rack §1.1`: "▾ Structure / ▪ Rough-in") but is `UnplacedPlacement` and cannot enter a rack. The drag interaction is undefined.
- **A6.4** A project with no Structure device has no way to build a location hierarchy, the location *tree* editor lives only in the Structure editor (`ux-device-builder §6.2`), while the rack editor treats locations as a flat combobox list.

### A7. Req 7 (PDF: diagram + schedule): **met (inferred), four gaps**

- **A7.1** **`blockExportOnErrors` defaults true and no document designs the blocked state.** Combined with `ux-rack §5.2` "Errors are not dismissible" and `data-model RCK-001..003, 009..011` being errors, a project with one weight overrun is permanently unexportable. Concrete deadlock (see B26, B29).
- **A7.2** The **acknowledgement/mute audit appendix** is promised by three documents (`data-model §3.5` "the reason PRINTS in the schedule"; `ux-rack §5.2` "appears in the PDF export appendix"; `ux-schematic §6.3` "prints in the PDF appendix") and appears in no sheet list. `data-model SheetKind` has 11 values, none of them an exceptions/DRC sheet.
- **A7.3** **BOM is unspecified.** `SheetKind.bom`, `bom_table.dart`, `Money`, `cost`, `supplier`, `purchaseOrder`, "Excluded from device counts and BOM 'active device' totals", "roll-ups (count, total length, total cost when a BOM exists)", a whole feature referenced by four documents and designed by none. Either spec it or cut the fields.
- **A7.4** No page-count bound, no "this will produce 47 pages" preview, no maximum, no warning.

### A8. Confirmed product decisions: **one met, two partially met**

- **A8.1 Desktop-first with a mobile/tablet read-only review mode.** Only `ux-rack §1.2` designs it (breakpoint, bottom sheet, tab bar, detents). The schematic, device builder, Structure editor, and schedule have **no tablet spec at all**, and the schematic is the view a reviewer most wants on a tablet. `architecture` has no mobile target, no mobile build config, and its dependency risk notes mention Android only for pdfium page sizes.
- **A8.2 "Templates are user-editable and shareable as files."** `.rmdev`/`.rmlib` are specified. But `architecture`'s package tree has **no template-library persistence at all**: only `catalog/starter_catalog.dart` ("loads/validates the seeded ~40 templates"). No `.rmdev` codec, no library directory service, no import/export service, no `.rmlib` zip handling, no library migration chain. The entire template lifecycle (`ux-device-builder §4`) has no implementation home.
- **A8.3 Cloud-ready data model.** Well designed in `data-model §5`, and then **tombstones are entirely absent from `architecture`**, which `data-model §5.4` names as "the one thing that genuinely cannot be retrofitted." `EntityMeta` is likewise never defined in `architecture` (only implied by a `d.touch(...)` call). `FracIndex` appears in no other document; three documents use integer ordering, which `§5.2` forbids by name.

---

## (B) Inter-document contradictions

Every item lists the two (or more) conflicting statements. **B1–B10 and B24–B29 are the ones that block coding.**

### Units and precision

**B1: The base length unit. Four answers plus floats. *(Blocking.)***
- `data-model §3.7`: "`Len` = **int64 nanometres.** … **Rejected: micrometres.**"
- `ux-rack §Design constants`: "integers (`int` U counts, `int` tenths-of-mm)"; `usableDepthTenthMm`, `weightCapacityGrams`.
- `ux-schematic §1.1`: "Everything is stored as `int` tenths-of-a-millimetre. No doubles in the model, ever."
- `architecture D3`: "**hundredths of a millimetre (10 µm)** … *tenths-of-mm, a plausible first choice, is **not** exact: 44.45 mm = 444.5 tenths. Use hundredths.*"
- `ux-device-builder §3.2`: `"depthMm": 330`, `"weightKg": 7.3`, `"xMm": 24.0`, **floating-point millimetres**, against `data-model`'s invariant I-1: "**No `double` appears anywhere in the persisted model.**"

Note the arithmetic that decides it: 1U = 44.45 mm is exact at hundredths (4445) and at nm; 1/32″ = 0.79375 mm is exact **only at nm** (793,750). `data-model`'s nanometre argument is the only one that holds if 1/32″ EIA clearances must be exact; `architecture` is right that tenths is wrong. Both cannot ship.

**B2: `ux-schematic §5.4` contains an arithmetic error that `architecture` independently catches.**
- `ux-schematic §5.4`: "`heightU × 444` tenths-mm tall (EIA-310 1U = 44.45 mm = 444 tenths, **exact: no rounding anywhere in the vertical axis**)."
- 44.45 mm = 444.5 tenths. The stated value drops 0.05 mm per U, 2.1 mm over 42U, visible at print scale.

**B3: Mass unit.** `data-model`: "`Mass` … integer micrograms." `ux-rack`: `weightCapacityGrams`, `weightGrams`. `ux-device-builder`: `"weightKg": 7.3` (float) plus `weightLb`.

**B4: Schematic grid pitch.** `data-model §2.0`: "`Pt` … **INTEGER grid units. 1 gu ≡ 2.54 mm** nominal pitch" with 1/64-gu sub-offsets "for annotation nudging only." `ux-schematic §1.1`: "Base grid unit `U` | **25 tenths-mm (2.5 mm)** … Snap grid (default) 1U; `Alt` = free (0.1 mm)." Different pitch, different sub-precision, and `ux-schematic` offers free positioning for symbols (`Alt+Arrows` nudge 0.1 mm) where `data-model` restricts sub-grid to annotations. `architecture` never mentions a schematic coordinate space at all.

**B5: BTU constant.** `data-model`: `typicalWatts × 3.41214`. `ux-rack §5.1`: `watts × 3.412`. `ux-device-builder §1.4`: `typicalWatts × 3.412`. Trivial, but they will disagree in a printed figure.

### The core wiring entity model *(Blocking: this is the largest structural conflict)*

**B6: `Connection` vs `Link` + `Net` + `Conductor` + `SignalRoute`.**
- `data-model §0`: "'Connection' is three different things in this domain and conflating them is the single most expensive mistake available here", `Link` (2-ended, N conductors) + `Net` (stored, N-way) + `SignalRoute`.
- `ux-schematic §0.1`: "The document stores **connectivity only**: `Connection(uuid, fromPortRef, toPortRef, domain, media, label, layerId, sheetId, routeOverrides?)`."
- `architecture §1.2`: `connection.dart # Connection: fromPort, toPort, cableType, length`; commands `Connect/Disconnect/ChangeCableType/SetWaypoints`.
- `pdf §10`: `model/ … PhysicalLink, LogicalSignal, CableType`, a **fourth** naming.

Two of the three consumers implement precisely the entity the data model rejects. Neither has `Net`, `Conductor`, or `SignalRoute`. `ux-schematic` is also internally inconsistent: §1.6 says "Model as one `Net` with one source port and N sink ports" while §0.1's storage definition has no Net and puts `domain`/`media` directly on the Connection.

**B7: `Link` has no `signalFamily` field, and the flagship rule depends on it.** `data-model §3.6` writes "`Link.signalFamily = video.hdbaset`"; `SIG-002` reads "the link's `signalFamily`"; the `Link` class definition in §2.9 has `media`, `cableSpecId`, `gauge`, `jacket`, **no `signalFamily`**. The family lives on `Net`. `SIG-001`/`SIG-002` as written cannot be evaluated.

**B8: Nets: stored or name-derived.**
- `data-model §3.6`: "`Net` is **stored, not derived**. **Rejected: derived-only nets (union-find over links at read time).** Tempting and wrong."
- `ux-schematic §1.6`: "Bus entries are **purely graphical and establish no connectivity**: **membership is carried by net name**." §1.5: "**Net names are generated, never typed.**"

Name-carried membership *is* the derived model. `data-model` binds membership by `Link.netId` FK.

**B9: Route geometry: persisted or forbidden.**
- `ux-schematic §0.1`: "**No wire coordinates. No route geometry.** … If you ever find yourself persisting a polyline, you have made an architectural error." (Then §2.3 ships waypoints, pinned routes, and `routeOverrides?`, internally contradictory.)
- `data-model §2.9`: `Map<Uuid, List<Pt>> waypointsBySheet; // manual orthogonal routing per sheet` and `RouteWaypoint (schematic geometry, per Sheet)`.

**B10: "Bundle" means three different things.**
- `ux-schematic §1.6`: "**Bundle (snake)**: a *purely organisational* grouping of **physical runs** that share a conduit … `B03 · 4 runs · 40'`." Has a column in the connections table and `Ctrl+K`.
- `ux-device-builder §6.6`: `Bundle { bundleId, label, locationId, conduitId?, lengthFt?, members: [dropId] }`, members are **drops**.
- `data-model §2.8`: `StructureBundle`, "One **OUTLET LOCATION**. The atomic unit of creation, specification and pricing", with `grade`, `wall`, `mountHeightAff`.

Outlet-location ≠ conduit-group. And **`data-model` has no link-level bundle entity at all**: `Link` has `pathwayId`/`conduitId` strings, no bundle FK. The schematic's entire bundle feature is unmodelled.

**B11: Adapters: embedded value or real device.**
- `data-model §2.9`: `InlineAdapter` is a value object inside `Link.inlineAdapters`, with `satisfiesRuleIds`. §3.5 resolves the RCA→XLR case by "Declare `InlineAdapter{…}`. `CON-001` and `ELE-002` are both satisfied by data."
- `ux-schematic §2.2`: "**Adapters as first-class objects.** … these are `ruHeight: 0`, `mountLocation: not-in-rack` passive **devices**. They appear in the netlist and the BOM." And the SIG-001 remedy: "`[ Insert HDBaseT receiver ]` … places the correct intermediate device and creates both connections in one undo step."

One Link with an adapter vs two Links through a device. The schedule, the BOM, and the trace all differ. `data-model` is itself inconsistent, RF splitters and IR blocks *are* modelled as `offRackPassive` devices.

### Validation philosophy *(Blocking: a product-identity decision)*

**B12: "Never block the pen" vs "hard-invalid, refused at drag time."**
- `data-model §3.5`: "Validation **never blocks the pen**… **Only five rules block creation** (`TOP-001..005`)… **A model that cannot draw a mistake cannot document reality**, cannot plan a remediation, and cannot import an as-found survey." SIG-001 is explicitly `blocksCreation: false, userAcknowledgeable: true`.
- `ux-schematic §2.2`: "**Class A: hard-invalid. Refused at drag time. Cannot exist in the document.**" Class A includes: HDBaseT→switch, IR emitter→receiver, connector mismatch, signal→power, Dante with no network path, AVB across a non-TSN switch, satellite splitter with no DC pass.
- `ux-rack §3.2`: checks 1–4 and 6–7 **block the drop** (including depth overrun), only clearance warns.

Every one of `ux-schematic`'s Class A rules is a non-blocking acknowledgeable finding in `data-model`, and `data-model` names the HDBaseT case as its worked example of "a correct depiction of an existing system you were called in to fix."

Additionally: **two Class A rules are logically unevaluatable at drag time.** "Dante/AES67 endpoints with no network path between them" and "AVB endpoints traversing a non-AVB switch" require whole-graph reachability, and the connection being drawn may be the one that completes the path. As blocking rules they are incoherent.

**B13: Severity vocabulary and dismissibility.**
- `data-model`: `error | warning | advisory | off` + an `acknowledged` state producing a printed audit line; `SIG-001` is an **error** and **is acknowledgeable**.
- `ux-rack §5.2`: `Error | Warning | Info`; "**Errors are not dismissible.** Warnings are dismissible per-instance with a required reason note."
- `ux-schematic §2.2`: `error | warn | info` (Class B) + Class A (refused); §6.3 "Rules can be **muted per-project** with a required justification note."

Three vocabularies (`advisory` vs `info`), three dismissal mechanisms (per-finding acknowledgement / per-instance dismissal-with-reason / per-project mute-with-justification), and `data-model`'s `ruleSeverityOverrides: Map<String, Severity>` has **no field for the required justification** that two documents promise will print.

**B14: Rule-by-rule severity conflicts.**

| Condition | `data-model` | `ux-rack` / `ux-schematic` |
|---|---|---|
| Σ device weight > rack capacity | `RCK-003` **error** | ux-rack **Warning** (amber 85%, red 100%) |
| Device depth > usable depth | `RCK-005` **warning** | ux-rack **Error**, and **blocks the drop** |
| Shelf hosted weight over capacity | `RCK-009` **error** | ux-rack **Warning** ("does not block the drop") |
| Hosted depth > shelf depth | `RCK-010` **error** | ux-rack **Warning** ("Overhang is common and survivable") |
| Centre of gravity | `RCK-004` **warning** at **50%** | ux-rack **Info** at **55%** |
| Spare RU | `RCK-008` advisory, **< 15%** | ux-rack Info, **outside 15–25%** |
| Σ continuous amps > 80% breaker | `PWR-001` **error** | ux-schematic **warn** |
| Duplicate designator | I-12: load **warning**, auto-renumber offered | ux-rack **Error**, "enforced, not suggested" |

**B15: Rules that exist in only one document.** `ux-rack`: "Device with no power source", "Unplaced devices in Staging Bin", "Wall rack over 80% weight", "Heat source with no vent above". `ux-schematic`: "unconnected port on a placed device", "orphan device". None has an ID; none is in `data-model`'s catalogue; two reference entities `data-model` doesn't have (Staging Bin).

### Rack model

**B16: RU origin, 0- vs 1-based.** `data-model`: "`ruIndex`, **1-based**, BOTTOM origin, always." `ux-rack §Appendix`: "`bottomU`, **0-based** from the rack's physical bottom." The rack UI displays U1 at the bottom, so `ux-rack`'s stored value differs from its own displayed value by one, everywhere.

**B17: RU numbering direction: project or rack.** `data-model`: `ProjectSettings.ruNumbering // bottomUpFromOne | topDown`. `ux-rack §2.1`: "the setting is **on the rack, not the app**, because a project can legitimately mix (a retrofit rack labelled by the previous integrator)." Both argue the point; they argue opposite conclusions.

**B18: Rack ordering.** `data-model`: `FracIndex order` + "§5.2 **No positional index is ever identity**… An integer `sortOrder` requires renumbering neighbours, and neighbour-renumbering is precisely the operation that makes sync impossible to retrofit." `ux-rack §Appendix`: `int bayOrder`. Also `ux-device-builder` `.rmdev`: `"order": 0` (integer) on ports and banks.

**B19: Circuits: whose child.** `data-model`: `Map<Uuid, Circuit> circuits` flat on Project; `Port.circuitId` on power inlets. `ux-rack §5.1`: "**Circuits are first-class objects on the rack.** PDUs are assigned to a circuit; devices are assigned to a PDU outlet"; `Appendix`: `class Rack { … List<Circuit> circuits; }`, a nested list, against `data-model §5.1` "Flat entity maps, **never** a nested tree." Two different assignment chains (port→circuit vs device→outlet→circuit) and an `Unassigned` pseudo-circuit with no model representation.

**B20: Shelf containment direction.** `data-model`: child points to parent (`DeviceInstance.hostDeviceId`, `ShelfPlacement.hostDeviceId`). `ux-rack §6.1`: `class ShelfOccupant { List<HostedDevice> hosts; }`, parent owns an ordered list of children. Two sources of truth for containment, plus a nested list (again against §5.1) and array-position ordering (against §5.2).

**B21: Half-rack devices on rails.** `data-model`: `RailPlacement{startTwelfth 0..11, spanTwelfths 1..12}`, worked example "Two half-rack devices sharing 1U = {0,6} and {6,6}", invariant I-19 and rule `RCK-011` validate lateral overlap. `ux-rack §Appendix`: no lateral field on rail placement at all; §3.2 check 7 **blocks** the drop, "`Half-rack: needs an ear kit or a shelf`." The model's headline lateral case is unbuildable in the editor that owns placement.

**B22: `Placement` shape.** `data-model`: sealed union of five variants including `OffRackPlacement`. `ux-rack`: one flat class with nullable fields, no off-rack variant, `rackId: null ⇒ Staging Bin`.

**B23: Fields present in exactly one rack model.**
- Only `data-model`: `fullHoleRail`, `formFactor` (8 values), `overallDepth/Width/Height`, `ownWeight`, `hasFrontDoor/hasRearDoor` + clearances, `zeroUChannels[]`.
- Only `ux-rack`: `refDesPrefix` ("R1"), `mount: floor|wall` + `mountHeightTenthMm` (drives the wall-rack render), `uNumbering`, `mirrorRearElevation`, `lineVoltage`, `locked` on placement, `lastRackId`/`lastBottomU`.
- Conflicting: `Rack.designator` ("RK-1") vs `Rack.refDesPrefix` ("R1"); `Rack.lineVoltage` vs `Circuit.volts` vs `PowerProfile.nominalVolts`, **three sources of truth for voltage**.

**B24: Rail-type enum.** `data-model`: `tapped10_32 | tapped12_24 | squareCageNut | roundClearance | m6`. `ux-rack §2.1`: `tapped10-32 | tapped12-24 | square | clearance`. Different spelling, `m6` missing.

**B25: Staging Bin is unmodelled.** `ux-rack §2.4` makes it a first-class per-project object with wiring preservation, a return affordance ("Return to Rack A U21" via `lastRackId`/`lastBottomU`), a `U` shortcut, a validation warning, and three feeder paths. `data-model` has only `UnplacedPlacement { Pt? schematicHint }`. `ux-schematic` never mentions it.

**B26: Bays are unmodelled.** `ux-rack §2.4`: "select 2+ adjacent racks → `Group as bay`. A bay draws shared side rails, a bracket above with the bay name, and rolls up vitals." No Bay entity anywhere.

**B27: Lock is unmodelled.** `ux-rack` has `Ctrl+L` lock/unlock, a 🔒 badge, `placement.locked`, auto-arrange treating locks as anchors, `refDesLocked`, and "Include manually-locked designators (3)" in Renumber. `data-model` has no lock field on any entity.

**B28: Rear-mirror is unmodelled**, and `ux-rack` disagrees with itself: §2.3 "A **per-project** setting `mirrorRearElevation`" vs §4.1 (inside the *rack* inspector's Display section) and §Appendix `Rack.mirrorRearElevation`. `data-model` has neither.

**B29: Occupancy struct.** `data-model`: `TemplateBody{frontU, rearU, side: OccupancySide, …}` with depth/weight as sibling fields. `ux-rack §6`: `class Occupancy { frontU, rearU, MountSide side, depthTenthMm, weightGrams }`, different enum name, and depth/weight folded in. `ux-device-builder`: matches `data-model`'s shape but its `side` enum is `front · rear · both · zeroU_vertical`, missing `none`, different casing.

### Designators, identifiers, and the format engine

**B30: Device designator format. Three renderings.**
- `data-model`: `"{typePrefix}-{seq:2}" → "MTX-01"`; JSON uses `MTX-01`, `SW-01`, `STR-01`.
- `ux-rack §7.2` / `ux-device-builder §1.2`: `{prefix}-{n}` → `AMP-1`, `MTX-1` (no padding).
- `ux-schematic §1.2` and every wireframe: `MTX1`, `AMP2`, `SW1`, `AVR1`, `STR`, **no separator**.

**B31: Port designator: template-owned or project-computed.**
- `data-model`: `portDesignatorFormat "J{devSeq:2}{portSeq:2}" → "J2301"`, project-unique, `designatorBlockSize: 100` reserve blocks; `PortDef.designatorHint` is only a seed.
- `ux-device-builder §2.5`: `Designator` is a **template grid column**, "Auto-assigned sequentially per ASME Y14.44", pinned once edited; `.rmdev` ships `"designator": "J1"`.
- `ux-schematic`: `J01`, `J09`, `J17`, 2-digit, per device.

A template-authored `J1` cannot also be a project-unique `J2301`, and `ux-device-builder` never mentions instance-level recomputation.

**B32: `STR` prefix collides in the shipped data.** `ux-rack §7.2` seed prefixes: "`STR` structure." `ux-device-builder §7.2` catalog A06: "Multi-Zone Streaming Source, `STR`." Both ship.

**B33: Structure drop labels.** `data-model`: `fieldLabel` (required, unique) + `rackLabel` (nullable, unique-when-set), formats `"{type}-{room}-{dir}-{seq}" → "ET-LIV-W-1"` and `"{floor}{space}-{panel}{port}"`. `ux-device-builder §6.5/§6.8`: columns `Label` + `TIA-606 ID`, "**Both** identifiers are generated for every drop", residential default `{roomAbbr}-{service}-{seq}` → `LR-TV-1`. Different names, different nullability, different tokens, different output shape.

**B34: No single token registry.** `data-model` tokens: `{typePrefix} {seq:2} {devSeq} {portSeq} {devBlock} {type} {room} {dir} {floor} {space} {panel} {port} {area} {run}`. `ux-device-builder §6.8` tokens: `{site} {building} {floor} {tr} {rack} {panel} {port:2} {room} {roomAbbr} {outlet} {service} {media} {seq} {seq:2} {bundle}`. `ux-schematic §1.5` net-name templates: `{DOMAIN} {SRC_REFDES} {SRC_PORT} {ROOM} {DEVICE} {N}`. Three sets, overlapping, no grammar, no escaping, no collision policy, for a feature all three ship.

**B35: Location code field.** `data-model`: `Location.code`. `ux-device-builder`: `abbr`. Same field, two names.

**B36: Location vocabulary shape.** `data-model`: arbitrary-depth tree with `LocationKind` (site/building/floor/room/zone/outdoor). `ux-device-builder §6.2`: fixed 4-level `Site → Building → Floor → Room → Outlet`. `ux-rack §7.5`: **flat list**: "`Locations: Basement, Media Closet, Living Room, Primary Bedroom…`" with inline creation.

### Templates and the library

**B37: Template version type.** `data-model`: `int version` (monotonic), snapshots keyed `"$templateId@$version"`, `TemplateRef{templateId, version: int, contentHash}`. `ux-device-builder §1.2/§4.2`: `version: {major, minor, patch}` semver computed from the diff class; `derivedFrom: {templateId, version: "1.0.0"}`. A `TemplateRef` cannot hold a semver.

**B38: Template migration join key. *(Blocking.)***
- `data-model §3.3`: "**Connections reference `Port.id`, never `(deviceId, portKey)`**" but the *migration* join is `PortDef.key` ("STABLE, author-assigned … This is the ONLY thing that makes connections survive a template revision") with `renamedFrom` aliases.
- `ux-device-builder §3.2/§5.3`: "**`portId` is the join key**, not label or index. `portId` UUIDs are generated once and preserved across every version."

`data-model`'s `PortDef` has no `portId`. `ux-device-builder`'s port has no `key` and no `renamedFrom`. Neither can execute the other's migration algorithm.

**B39: Removed-port outcome.** `data-model §3.3` step 5: "if the Port has no Conductors → delete. else → set `orphaned = true`. **DO NOT DELETE. DO NOT DELETE THE LINK.** … **Rejected: deleting orphaned ports and their links.** Data loss on a routine operation." `ux-device-builder §5.3`: per-cable inline choice `[ Remap ▾ ] [ Keep ] [ Del ]`, one click, no confirm, on the outcome the other document forbids. No `orphaned` concept.

**B40: Override key namespace.** `data-model §3.2`: dotted paths into `TemplateBody`, `"weight"`, `"power.nameplateWatts"`, `"bodyDepth"`. `ux-device-builder §5.1`: `"identity.name"`, `"physical.weightKg"`, `"ports.<portId>.label"`, paths into the `.rmdev` document shape, which has `identity`/`physical`/`power` sections `TemplateBody` does not. Also `data-model` puts port overrides on `Port.overrides`; `ux-device-builder` puts them in the *device's* map.

**B41: Detach mechanism.** `data-model §3.1`: "the UI presents **exactly two doors** … **There is no third door**", plus `localTemplate` for per-instance forks; invariant I-9: `templateRef` must resolve **or** `localTemplate` non-null, "Never neither." `ux-device-builder §5.2`: **four** verbs, including "Detach instance (`templateRef → null`)" with the instance carrying its own `snapshot`. Three overlapping snapshot mechanisms (`Project.templates` map, `PlacedDevice.snapshot`, `localTemplate`).

**B42: Port banks are unmodelled.** `ux-device-builder` `.rmdev` has a first-class `banks[]` array (`bankId, name, abbr, symbolSide, collapseInSymbol, order`) and `ux-schematic §1.2` builds its entire symbol layout on banks (edge assignment, brackets, folding, vector pins, unit splitting). `data-model` has only `PortGroupDef`, an *electrical* grouping (componentVideo, speakerPair, `atomicConnect`). Different concept; `symbolSide` has no model field.

**B43: Seeded catalog is read-only.** `ux-device-builder §5.4`: "Seeded templates ship read-only. Editing one silently performs Duplicate → edit the copy." Consequence not surfaced anywhere: a user who fixes a wrong wattage in a seeded template forks it and permanently loses catalog updates for that device. Reconcilable with the brief but needs an explicit decision and a UI affordance.

**B44: `poeBudgetWatts` has no home.** `NET-001` ("Σ PD class draw on a switch > the switch's PoE budget", **error**) needs it. `data-model`'s JSON example carries `"poeBudgetWatts": 370` as an **undeclared key** on `TemplateBody`; the class has no such field. `ux-device-builder`'s `.rmdev` schema has no field either, the budget appears only in catalog prose ("PoE budget 370 W").

**B45: Passthrough pairing has no file format.** `data-model`: `PassthroughPairDef{frontKey, rearKey, sameNet}` on the template; invariant I-32. `ux-device-builder`: a `Paired port` grid column and a "Pair front↔rear by order" action, and the seeded panels annotate "[paired 1:1 with front]", but the `.rmdev` schema in §3.2 has **no pair array** and no `sameNet` flag.

**B46: Vocabulary namespaces are incompatible.** `data-model` uses reverse-hierarchical namespaced IDs (`conn.rj45`, `video.hdmi.2_0`, `net.ethernet`, `power.ac_120`). `ux-device-builder` uses flat bare names (`HDMI-A`, `RJ45`, `hdmi20`, `ethernet`, `ac-inlet`) and its catalog is by far the largest vocabulary in the project (~35 connectors, ~45 signal families). Note `ac-inlet` is used as a *signal family* in the catalog while `data-model` models it as family `power.ac_120` + `PortPowerSpec.role: inlet`. No shared registry file exists; `.rmdev` → `.rackpal` import is undefined.

**B47: Gender enum is ambiguous.** `data-model`: `male | female | genderless | jack | plug`, five values containing two synonym pairs, with `ConnectorTypeDef.matesWith` described as a "gender-aware mating table." `ux-schematic §1.3`: "**filled = female/jack, hollow = male/plug**", treats them as synonyms. Consequence: `CON-002` ("genders both male or both female") does not fire for `jack`+`jack`. Concrete bug in a shipped rule.

**B48: Direction encoding.** `data-model`: `source | sink | bidirectional | busNode | passive`. `ux-device-builder` grid: `In / Out / Bi / Bus / Passive`; catalog notation `i/o/b/p` where **`p` means "passive/bus node"**: collapsing two distinct enum values into one letter across 62 templates. `ux-schematic` adds "Power inlet"/"Power outlet" as directions.

**B49: Catalog size.** `ux-device-builder` title: "**58 Templates**"; §0 and §7 prose: "58-device seeded catalog", "the 58 shipped entries collapse to 47 distinct parametric families"; §7.9 summary table: "**Total shipped templates | 62**". `architecture`: "the seeded ~40 templates". The brief: "~30-50".

### Sheets, layers, views

**B50: Layers are entirely unmodelled.** `ux-schematic §4.2`: "User-defined named layers, each with `visible / locked / prints` flags: *Existing*, *Phase 1*, *Phase 2*, *Future*, *Owner-furnished*, *Demo*. A connection and a device each belong to exactly one layer. **Layers are a document concept and they do persist.**" Layer appears in the Connection definition (`layerId`), the connections table, Properties, the search language, and `sheetFilter`. `data-model` has **no Layer entity and no `layerId`**: only `DeviceStatus{existing|new|future|removed}`, which is a fixed 4-value overlapping concept with no equivalent on links (links carry `RoughInStatus`, an orthogonal axis).

**B51: Three status vocabularies, one column name.** `DeviceStatus{existing|new|future|removed}`; `RoughInStatus{planned|pulled|dressed|terminated|tested|issued}`; `ux-device-builder §6.5` drop status `{Planned, Pulled, Terminated, Tested, **In use**, **Spare**, Abandoned}` (drops `dressed`/`issued`, adds three). `ux-schematic`'s connections-table `Status` column shows `✓`/`⚠`, that's **DRC state**, a fourth meaning under the same header.

**B52: Sheet numbering.** `data-model`: `Sheet.number` matching `^[A-Z]{1,2}\d\.\d{2}$`, NCS (`T0.01`, `T2.01`, `T6.02`); `pdf §12` decision 1 agrees ("NCS `T`-discipline numbering"). `ux-schematic §1.7`: title block shows "`SHEET 2 of 6 · VIDEO`" and "`DRG SR-0247`"; §4.5 sheets are "Sheet 1 SYSTEM OVERVIEW … Sheet 7 STRUCTURE." No NCS numbers, and `DRG SR-0247` has no model field.

**B53: `sheetFilter` vs `domainFilter`.** `ux-schematic §4.5`: sheet filter is "domain set **+ layer set**". `data-model Sheet`: `Set<SignalDomain> domainFilter` only, no layer filter (there are no layers).

**B54: Symbol pinning is unmodelled.** `ux-schematic §2.5`: "Every symbol is `auto` or `pinned`. Any manual move sets `pinned = true` … **Auto-layout never moves a pinned symbol**", with a 📌 badge, `Ctrl+Shift+U`, and confirm dialogs that count pinned symbols. `data-model SheetItem`: `{targetId, position, rotationQuarterTurns, collapsed, zOrder}`, no `pinned`.

**B55: Three places a symbol position can live.** `SheetItem.position`, `UnplacedPlacement.schematicHint`, and, for stacking, both `DeviceInstance.zOrder` ("schematic stacking") **and** `SheetItem.zOrder`. Precedence undefined.

**B56: Unit splitting is unmodelled.** `ux-schematic §1.2(b)`: symbols split into `MTX1:A/:B/:C`, "units may live on **different sheets**", "**no symbol edge ever carries more than 16 pins**", automatic split by domain for multi-sheet sets. `data-model`: one `SheetItem` per device per sheet, no unit letter, no per-unit port assignment.

**B57: Rear-panel view: printable or not, and is it the authoring surface.**
- `ux-schematic §5.4`: "this is the *installer's* view … it is **what gets printed and taped inside the rack door**", and "the rear panel view **is the device builder's output surface**. You build a device by drawing its rear panel."
- `ux-device-builder §2.6`: "**Against manual x/y authoring as a required step.** It is precisely the 'click 16 times' failure the brief is trying to eliminate, multiplied, a 48-port patch panel would need 48 placements." Manual layout is an optional hidden toggle behind an auto-layout.
- `data-model SheetKind`: 11 values, **no rear-panel kind**: the view cannot be printed.
- `architecture`: scene layers are `rack_layer / device_layer / wire_layer`. **No rear-panel renderer and no schematic-symbol renderer.**

**B58: Structure device sheet position.** `ux-schematic §3.2`: "The Structure device is **forced to layer 0, always**, rendered as a bank of off-page connector flags on the **left edge**." `ux-device-builder §6.9`: "a Structure **can be pinned to the right edge** instead."

### Colour, theme, typography

**B59: Default theme.** `architecture §12.3`: "`screenDark` (**the default**: this is a pro tool used in equipment rooms and dark UIs are the genre convention)." `ux-schematic §1.7`: the canonical palette section is light-first, every wireframe is light, and "The dark theme is for the person editing at 11 pm; **the light theme is the deliverable**."

**B60: "No user-facing export-palette option" vs three of them.** `ux-schematic §1.7`: "Export **always** renders the light/print palette regardless of screen theme, **with no user-facing option to do otherwise**." Against: `data-model ProjectSettings.greyscaleSafeExport` (persisted in the document), `ux-schematic`'s own "Ship a Greyscale-safe export toggle", and `pdf §12` decision 16's "greyscale PDF" export option.

**B61: Where colour and dash are defined.** `data-model` puts `color`, `dashPattern`, `lineWeightPermille`, `glyph` on `SignalFamilyDef` (43+ entries) while `§3.4` argues "Colour is on the `SignalDomain` (7 values), **not** the family." No `SignalDomainDef` exists. Also `dashPattern: List<int>` has **no stated unit** anywhere; `ux-schematic` specifies dashes in grid units U.

**B62: Fonts: a named rejection contradicted. *(Blocking for goldens.)*** `pdf §9`: IBM Plex Sans / Sans Condensed / Mono, SIL OFL, aliases `RackBody`/`RackCond`/`RackMono`, six TTFs ~1.0 MB, and explicitly: "**Runner-up considered and rejected: Inter** … and **Roboto / Roboto Mono**." `architecture §12.3`: "`Inter-Regular`, `Inter-SemiBold`, `JetBrainsMono-Regular` in `apps/rackpal/assets/fonts/`." `architecture §9.4`'s golden test then asserts families are `RackBody`/`RackMono`, the pdf doc's aliases with the pdf doc's rejected fonts, and no `RackCond`.

**B63: Text-metric source of truth. *(Blocking: this is the parity bug both docs warn about.)***
- `pdf §12` decision 11: "**`PdfFont.stringMetrics` is the single source of truth for text metrics on both backends**, with Skia kerning disabled to match." Decision 18 and the closing note: "the two failures that produce a PDF which is subtly, unfixably different from the preview."
- `architecture §12.3`: bundling the same TTF "is what makes text metrics agree between the two", a different and **insufficient** mechanism (Skia shapes with kerning/ligatures; dart_pdf does not). `architecture §6.6` puts `measureText` on `DiagramCanvas` for each backend to answer independently.

### Architecture and packaging

**B64: Package layout: four packages or one. *(Blocking.)***
- `architecture §1.2/§2.2`: four packages; "`rackpal_export` and `rackpal_ui` are **siblings that cannot see each other**. That is deliberate: it is what guarantees the PDF path is isolate-safe."
- `pdf §10`: a **single** `lib/` tree with `diagram/backends/{pdf_canvas.dart, svg_canvas.dart, bounds_canvas.dart, flutter_canvas.dart}`, the Flutter and PDF backends **in the same directory**, annotated "the ONLY Flutter-dependent file here." This is exactly the folder-convention arrangement `architecture §1.1` rejects: "a folder convention will be violated within a month by an `Offset` that 'was just easier.'"
- Worse: `pdf §10` places `diagram/text.dart # TextMeasurer, **PdfFontMeasurer**` inside the core tree. Combined with B63, core must depend on `package:pdf`, a direct violation of `architecture §2.2`'s import table (`rackpal_core → no pdf`) and of its `no_flutter_import_test`, which bans `package:pdf/` by regex.
- `hit_test.dart` lives in core (`pdf §10`) vs `rackpal_ui/canvas/input/hit_tester.dart` (`architecture §1.2`).

**B65: Devices are rendered by two code paths, and no document notices.** All three UX documents and `architecture §6.2` agree device bodies are **real Flutter widgets** ("Device faceplates + ports + ref-designators | real widgets"). But `architecture D4` states the display list is "the single drawing IR … Screen and PDF are two interpreters of it," and `draw/scene/device_layer.dart` emits devices into the scene for PDF. So device faceplates, the most information-dense content in the deliverable, are drawn by a widget tree on screen and by a scene builder in print, with **no parity mechanism**, defeating D4 exactly where it matters most. `pdf`'s parity test (`canvas_parity_test`, build step 3, "the thing that's expensive to fix late") tests the two *canvas backends*, not the two *device renderers*.

**B66: Isolate API cannot deliver its own requirements.** `architecture §1.2/§8`: `Isolate.run` (`build_document.dart # top-level fn; the Isolate.run entry point`). `pdf §12` decision 13: "progress via captured `SendPort`; **cancel via `Isolate.kill`**." `Isolate.run` supports neither progress nor cancellation; it needs `Isolate.spawn` with a port pair (which `pdf`'s `isolate_runner.dart` implies). `architecture §10.2` also budgets "PDF export ≤ 2.5 s, UI never blocks" with progress implied.

**B67: PDF preview mechanism.** `pdf §12` decision 14: "Primary preview uses the **screen** renderer, so the core flow has zero native dependencies." `architecture §8.4`: `printing ^5.15.0`, "`PdfPreview` for in-app preview," with the pdfium build-time-download risk noted. Also: **neither document says whether OS Print (as opposed to Export-to-file) ships in v1**, and `Ctrl+P` is Export in `ux-rack` and Command Palette in `ux-schematic`.

**B68: SVG export exists in one document only.** `pdf §12` decision 16 and `pdf §10` ship `svg_canvas.dart` ("SVG in v1.1, one file"); `architecture` never mentions SVG. Same for `bounds_canvas.dart` and `RendererCaps`.

**B69: Model class names in `pdf §10`.** `RackProject, Device, Port, PhysicalLink, LogicalSignal, CableType, Rack, Structure`, `RackProject` vs `Project`, `Device` vs `DeviceInstance`, `PhysicalLink`/`LogicalSignal` vs `Link`/`Net` vs `Connection`, `CableType` vs the three-registry split `data-model` explicitly renamed it away from.

**B70: `.rackpal` container: plain JSON or zip.** `data-model §4.1`: "v1 is **plain, pretty-printed, key-sorted UTF-8 JSON** … v2: ZipCodec." `architecture §7.1`: "**Not zipped**, not binary." `ux-device-builder §3.1`: "`.rackpal` | A project | **Zip: `project.json` + embedded template snapshots + `assets/`**." The third document is the one that specifies device images (512 KB `frontImage`/`rearImage`), which force a container. Decide images in/out first, then the container follows.

**B71: Envelope shape.** `data-model §4.2`: root keys + all entity maps nested under `"document": {…}`. `architecture §7.1`: root keys with `Project` fields at root, no `document` wrapper. `ux-device-builder`: `project.json` inside a zip.

**B72: Migration control flow.** `data-model §4.3`: `migrateToCurrent` **throws** (`FormatException`, `NewerSchemaException`) and returns `raw..['_openReadOnly'] = true`. `architecture §7.2`: returns `Outcome<JsonMap>` and never throws, "**Expected outcomes … are values, not exceptions.**" Also `architecture`'s snippet has a logic defect: `minReader > kSchemaVersion` returns `NewerSchema(v, readOnly: **false**)` (reads backwards; it should refuse), and the trailing `if (v > kSchemaVersion)` is unreachable given the loop condition.

**B73: `revision` monotonicity.** `data-model` I-6: "`Project.revision` is **strictly monotonic** across the life of the document and **never decreases** on save." `architecture §7.4`: "`undoOne()` and `redoOne()` **restore** the revision they were recorded at rather than incrementing it … This means `revision` is **not strictly monotonic**," and adds a separate `sequence` counter that `data-model` does not have. `data-model §5.3` uses `revision` as the sync cursor, which a non-monotonic counter cannot be.

**B74: Tombstones absent.** Covered in A8.3; restated here because it is a contradiction, not only a gap: `data-model §5.4`, "**Do it now or accept that sync is a rewrite**", against `architecture`'s complete omission.

**B75: `EntityMeta` partially absent.** `data-model §5.3`: every entity carries it; "Adding it later means a migration that **cannot backfill honest values**." `architecture` implies it via `d.touch(doc.clock.nowUtc(), doc.actor)` but never defines it, never lists it in the model files, and never persists `localRevision` or `unknown`.

**B76: Unknown-field preservation.** `data-model` I-16 and `architecture §7.1` agree it exists. Neither says where it lives on entities `architecture` defines without `EntityMeta`. `.rmdev` has no unknown-field mechanism and no `minReaderVersion` at all.

**B77: Crash-report contents contradict the redaction policy, inside one document.** `architecture §11.4`: "log entity **UUIDs**, never device names, client names, project addresses, or file paths … The diagnostics bundle includes … **never document content**." `architecture §7.5`: "**Recovery files are also the crash-report attachment (§11).**" Recovery files are full project documents containing the client's name and site address.

**B78: Display units: app preference or project setting.** `architecture §12.2`: "**Display units are a user preference independent of locale**." `ux-device-builder §1.3`: "Unit follows the **app-level preference**." `data-model`: `ProjectSettings.displayUnits // imperial | metric | mixed`, persisted **in the document**. The deciding case (a shared file opened by two integrators) is exactly the one CI firms hit.

**B79: Project history folder.** `ux-device-builder §5.3`: "a pre-update snapshot of `project.json` is written to the project's **`.history/` folder**", implying the project is a directory. `architecture §7.3/§7.5`: single file + `.bak` sibling + recovery snapshots in app-support.

### Interaction

**B80: The keymap has ~18 collisions across the two editors, with no arbitration document.**

| Key | `ux-rack` | `ux-schematic` |
|---|---|---|
| `Ctrl+P` | **Export PDF** | Command palette (Export is `Ctrl+E`) |
| `Ctrl+K` | Command palette | Add to bundle |
| `F` | Flip face | Focus |
| `Shift+F` | Toggle Both-faces view *and* move to opposite face | Isolate |
| `Ctrl+F` | Focus mode on rack | Search |
| `Ctrl+B` | Fill gaps with blanks | Create bus |
| `Ctrl+R` | Renumber dialog | Reverse direction |
| `Ctrl+Shift+R` | Auto-arrange | Clear manual route |
| `Ctrl+L` | Lock/unlock position | Wire ↔ net label |
| `Ctrl+0` | Fit all racks | Fit sheet |
| `Ctrl+1` | Zoom 100% | Rack view *(and* domain toggle*)* |
| `Ctrl+9` | Fit focused rack | Fit selection |
| `G` | Toggle 0U gutters | Toggle grid |
| `L` | Cycle label mode | Tidy selection |
| `W` | Toggle warning badges | Begin wire / marquee-wires modifier |
| `Ctrl+Alt+3` | Rack Outline panel | *(`Ctrl+3` = Rear panel view)* |

Two internal collisions as well: `ux-schematic §7` binds `Ctrl+1…Ctrl+4` to view switching **and** `Ctrl+1..8` to domain toggling; `ux-rack §8` binds `Shift+F` to two different actions conditioned on selection state without saying so.

**B81: Marquee button.** `ux-rack §3.6`: press-drag on empty canvas (left button). `ux-schematic §2.4`: "**Right-drag** | marquee (no modifier needed, doesn't collide with pan)", while §2.1 also binds right-click to "cancel current operation." Same gesture, different buttons, plus an internal ambiguity.

**B82: Collapse thresholds.** Vector-pin collapse at ≥4 homogeneous ports (`ux-schematic §1.2c`), unit split at 17 (§1.2b), bank auto-collapse in the symbol preview at >8 (`ux-device-builder §2.7`). Three thresholds for closely related behaviours.

**B83: Auto-sheet-partitioning: v1 or v2.** `ux-schematic §4.5` ships it ("`Layout → Split to Sheets…`: offers the domain partition, plus a **graph min-cut** alternative, plus **by rack**"). `ux-schematic §3.4` lists it as **v2 upgrade #6**.

### Internal contradictions worth fixing while reconciling

**B84: `data-model` §2.8 vs I-39.** "`RoughInStatus bundleStatus; // derived-**max** of member drop statuses`" vs I-39 "derived as the **minimum** status across its drops."

**B85: `data-model` `Sheet.viewKind` vs `Sheet.kind`.** The ER diagram declares `viewKind: elevation | schematic | schedule | cover | legend` (5 values); the class declares `SheetKind kind` (11 values); invariant I-42 refers to "the sheet's `viewKind`."

**B86: `data-model` JSON example violates I-2.** Every ID in §4.5 is human-readable (`"rk-1"`, `"dev-mtx1"`, `"p-str1-d1"`, `"sh-t201"`) against "Every entity ID is a valid **UUID v7**." Illustrative, but the example is the artifact people will copy.

**B87: `Extent` used once.** `StructureDrop.calculatedLength: Extent?` vs `Link.calculatedLength: Len?`. The "unknown/varies" type exists for one field.

**B88: Derived caches are persisted.** `data-model §5.6` names `portIds`, `bundleStatus`, `templateUpdateAvailable` as "rebuildable caches, flagged as such," I-11 says `portIds` is "rebuilt on load rather than trusted", and all three are written into the example file, bloating the git diff the format was made plain-JSON to keep readable.

---

## (C) Open decisions that must be made before coding

Grouped by what they block. The first six block *everything*.

### Blocks the file format and every entity

**C1. The unit.** nm / hundredths / tenths / float-mm (B1). Deciding factor: must 1/32″ EIA clearances be exact (⇒ nm) or is 0.01 mm sufficient (⇒ hundredths)? Write the answer into one normative doc and delete the other three.
**C2. The wiring entity set** (B6–B11). `Connection` alone, or `Link`+`Conductor`+`Net`+`SignalRoute`. This determines the schedule, the DRC, the schematic, the PDF, and the format. Recommend: `Link`+`Conductor`+`Net` in v1, `SignalRoute` deferred (nothing in v1 needs Dante flow modelling).
**C3. `.rackpal` container** (B70), decided by C4.
**C4. Do device images ship in v1?** `.rmdev` allows 512 KB embedded PNG/SVG per face. If yes ⇒ zip container now. Recommend **no**: `ux-device-builder §1.5` already calls them a scope trap and says they are "not needed for correct output."
**C5. Template version type and migration join key** (B37, B38). Recommend: `int` version (a semver whose meaning is computed from a diff adds a vocabulary without adding a capability), and **`PortKey` string + `renamedFrom`** as the join, a UUID cannot express "this port was renamed from that one," which is the case the whole mechanism exists for.
**C6. Ordering type** (B18), `FracIndex` everywhere or `int` everywhere. Recommend `FracIndex`; retrofitting it is a format migration touching every entity.

### Blocks the validation engine

**C7. Blocking policy** (B12). Recommend `data-model`'s "never block the pen" with one amendment: keep `ux-schematic`'s **remedy chips** (`[ Insert HDBaseT receiver ]`) as *offers on a warning* rather than as the price of a refusal. That preserves the as-built/remediation use case, which is a genuine market differentiator, without losing the teaching moment.
**C8. Severity vocabulary and dismissal model** (B13). One enum, one dismissal mechanism, one place justifications are stored, and add the justification field to `ruleSeverityOverrides`.
**C9. `blockExportOnErrors` semantics** (A7.1). If errors block and errors are undismissable, the product deadlocks. Recommend: errors block *sign-off* (a "Issued for construction" flag on the export), never the export itself; a draft export always works and prints its own exception list.
**C10. `RulePredicate`: the largest unpriced item.** `data-model §2.10` declares rules are "**DATA, not code** … `RulePredicate predicate; // declarative AST, JSON-serializable`" and shows one three-clause example. But `NET-003` ("no network path between them"), `NET-004` (traversal), `ELE-004` (parallel impedance), `ELE-005`/`ELE-008` (Σ over a net, RF cascade budget), `BUS-004`/`BUS-005` (dual limits), and `PWR-001` (Σ with derate) require graph reachability, aggregation, and unit arithmetic. No JSON AST expresses these without becoming a programming language, which then becomes an interpreter accepting untrusted imported `.rmlib` content (see D8). **Decide: rules as code with a data-driven *severity/enable* layer (recommended), or commit to designing and sandboxing a rule language.** The user-authorable-rules claim in §3.4 should be withdrawn if the former.
**C11. `AckedFinding.targetFingerprint` algorithm.** Unspecified, load-bearing (I-45 GCs acknowledgements against it), and safety-relevant, a bad fingerprint silently suppresses a *different* problem than the one the user reviewed.

### Blocks the schedule and the PDF

**C12. Cable length** (A3.2). Recommend: user-entered per link with a per-bundle default; delete `calculatedLength`; keep `LEN-*` rules but mark them "not evaluated until a length is entered" and surface that state.
**C13. Designator formats**: device, port, link, drop field, drop rack (B30–B34). One token grammar, one registry, one parser, escaping rules, collision policy.
**C14. Elevation scale**: true scale (a ruler works on the print) or fit-to-page. Construction drawings usually need the former; nothing states it.
**C15. Sheet numbering scheme** (B52) and whether a DRC/exception appendix sheet exists (A7.2).
**C16. BOM: in or out** (A7.3). If out, delete `Money`, `cost`, `supplier`, `purchaseOrder`, `SheetKind.bom`.

### Blocks the UI

**C17. Blocking drops in the rack editor** (B12, B21), including whether half-rack rail placement (twelfths) is supported.
**C18. RU origin and numbering scope** (B16, B17).
**C19. Circuit ownership and assignment chain** (B19).
**C20. Layers/phasing: adopt or drop** (B50). If adopt: model it, add a filter to the rack view, and reconcile with `DeviceStatus`.
**C21. Multi-conductor link UI** (A3.1), or explicitly defer conductors to v1.1 and accept 4 rows on the pull sheet for a 16/4 run in v1.
**C22. Rear-panel view: v1 or not, printable or not, authoring surface or projection** (B57).
**C23. Adapters: value or device** (B11).
**C24. Undo scope for template, library, Structure-import, and settings edits** (A2.3).
**C25. Multi-document: tabs or single** (`architecture §8.6` says tabs; no UX shows them), and `Ctrl+N`/`Ctrl+O` behaviour with a dirty document open.
**C26. A single arbitrated keymap** (B80).
**C27. Default theme** (B59) and display-units scope (B78).
**C28. Registry authoring UI: build it or withdraw the claim** (A2.1).

### Blocks the build

**C29. Package layout**: four packages or one tree (B64), and where `hit_test` and text measurement live.
**C30. Text-metric source of truth** (B63), and therefore whether `rackpal_core` may depend on a font engine. This is the decision `pdf §12` calls "the one thing to get right."
**C31. Device rendering: one path or two** (B65). If devices stay widgets, the parity test must cover device faceplates specifically, or D4's guarantee is void for the most important content.
**C32. Fonts** (B62).
**C33. Isolate API** (B66).
**C34. Print (OS dialog) in v1** (B67).
**C35. Tombstones and `EntityMeta`: in or out of v1** (B74, B75). `data-model`'s "can't be retrofitted" argument is correct for tombstones; it is not correct for `templateUpdateAvailable`-style caches. Decide per-mechanism, not as a bloc.
**C36. Seeded catalog: authoritative source and review process** for 62 templates' wattages, weights, depths, PoE budgets, impedances, and `pinoutVariant` values, several of which are the sole data source for safety-adjacent rules (`DIR-003` destroys hardware).

---

## (D) Missing cross-cutting concerns

### D1. Onboarding and help: one surface designed of five

`ux-rack §9` is strong (start card, starter projects, empty rack state, three contextual coach marks, the measured 25-second fastest path). Nothing else has any.

- **No schematic empty state and no first-wire onboarding.** The first connection is the hardest moment in the product; there is no design for it.
- **No help system at all** in any document: no Help menu contents, no in-app docs, no shortcut cheat-sheet UI (`ux-rack §8` says the table is "derivable from the registry", implying a panel that is never designed), no "What's this?" surface.
- **`ux-schematic`'s reason chip has a `[ Why? ]` button that leads nowhere.** Rule rationale exists in the model (`CompatibilityRuleDef.rationale`, `remedyHint`) with no viewer.
- **No glossary.** The product invents vocabulary an integrator does not have: *bank, unit, net, hyperedge, bundle, drop, twelfth, staging bin, off-sheet connector, vector pin, hop*. Half of it is EE jargon deliberately imported (which is the right call) and therefore needs teaching.
- **No error messaging catalogue**: messages are written ad hoc across four documents in four voices.

### D2. Sample projects: the best asset in the design, one wireframe box each

`ux-rack §9.1` offers Blank / Home theater (24U, 9 dev) / Network closet (12U, 6 dev) / Conference room (12U). Nobody specifies their **content, authorship, storage format, whether they include wiring, whether they include a Structure device, or whether they export cleanly to PDF**. As listed, none demonstrates the Structure device or the PDF, the two differentiators. They are also the natural golden-corpus fixtures, the natural performance fixtures, and the natural screenshot source.

### D3. Error states: the file layer is undesigned

Well covered: invalid drop, rack shrink, template breaking change, duplicate refdes, invalid wire target, rollback-failure (behaviour only).

Missing entirely:
- **Open**: corrupt file, newer schema (the `_openReadOnly` banner is never designed), permission denied, path on a disconnected network drive, file locked by another process, `.rmlib` mount missing, `contentHash` mismatch (I-8 declares it "a hard load error" with no UX), dangling foreign key (I-5 says "the loader quarantines the referencing entity", no UX for a quarantined entity).
- **Save**: disk full, read-only target, Windows path length, OneDrive/Dropbox sync conflict, target on a removed volume.
- **Export**: no disk space, and, the single most common Windows failure, **target PDF currently open in Acrobat** (rename fails, atomic write fails).
- **Import**: unparseable CSV, ambiguous column mapping, image over cap, duplicate `templateId` at equal version with differing hash (`ux-device-builder §4.3` specifies the *policy*, not the dialog).
- **Concurrency**: two app instances on one file; file changed on disk while open. Not mentioned in any document. For a Dropbox-shared job folder this is a weekly occurrence.
- **The poisoned undo stack** (`architecture §11.3`) has a described behaviour and no UI.

### D4. Empty states

Designed: empty rack. Missing: empty schematic sheet, empty schedule, empty device library / zero user templates, zero validation issues, zero search results, empty Structure (one line), empty Staging Bin, project with zero racks after deleting the last one.

### D5. Data-loss prevention: strong core, unaudited edges

`architecture §7.3/§7.5` is genuinely good: atomic temp+rename, `.bak`, autosave to a *separate* recovery file ("**Never autosave over the user's file**"), startup recovery scan, three-button close prompt.

Not audited against it:
- `ux-device-builder §5.3` offers **`[ Del ]` per affected cable as a one-click inline choice** during template update, the exact outcome `data-model §3.3` forbids as "data loss on a routine operation."
- `ux-rack §6.1` "Delete all 4" on shelf deletion (default is the safe option, good).
- `Ctrl+X` on a wired device, `Commit sort order` in the port grid, `Renumber` (has a diff, good), Structure CSV import over existing drops.
- **No project-level snapshot/versioning** beyond `.bak`, despite `RevisionEntry.frozenSnapshotId` ("optional immutable doc snapshot for as-built diff") implying one.
- **Undo cap silently drops the oldest entry** at 200 with no user signal.

### D6. Upgrade paths

Document-format migration is well designed. Everything else is absent:
- **App update mechanism**: none. On Windows this means MSIX auto-update, Squirrel, or manual downloads; the choice affects signing and the installer.
- **User library migration**: `.rmdev` carries `schemaVersion: 1` with **no migration chain, no `minReaderVersion`, and no unknown-field preservation**. A user's 40 hand-built templates are the asset they will not forgive you for breaking.
- **Seeded catalog updates**: `§5.4`'s read-only-fork model means a forked template never receives fixes. Correct mechanism, but the consequence is never surfaced to the user ("this device is a copy of a catalog template that has since been corrected").
- **Preferences migration**, **recents/window-state migration**.
- **Downgrade**: office desktop and site laptop on different versions is the normal CI configuration, and `minReaderVersion` handles the file but nothing handles the library.

### D7. Licensing

**Absent from all six documents.**
- No licence model (free / paid / trial / seat), no key handling, no EULA, no terms.
- **Third-party attribution is a shipping requirement, not a nicety.** IBM Plex is SIL OFL 1.1, the licence text must ship with the fonts. `package:pdf`, `printing`, `path_drawing`, `window_manager`, etc. are Apache-2.0/BSD/MIT with attribution obligations. Flutter provides `showLicensePage`; it must be wired, and the bundled fonts' licences must be registered manually (`LicenseRegistry.addLicense`) or they will not appear.
- Correctly avoided: `libavoid` (LGPL) is declined by both `ux-schematic §3.4` and `architecture`.

### D8. Telemetry, privacy, and import security

Privacy posture is strong (`architecture §11.5`: no telemetry by default, local crash files, opt-in, view-before-send, self-hosted Sentry not even added as a v1 dependency). Gaps:
- **The redaction policy contradicts the crash attachment** (B77).
- No privacy statement surface, no retention policy, no "clear diagnostics" action, no documented on-disk locations per OS.
- **No security review of file import at all.** `.rmdev`, `.rmlib`, and `.rackpal` arrive by email from strangers. Needed and absent: zip-slip protection on `.rmlib` extraction, entry-count and uncompressed-size limits (zip bomb), image decode bounds, JSON depth/size limits, and, critically, **`RulePredicate` is an evaluated program that can arrive inside an imported `.rmlib`**. `ux-device-builder §4.3` asserts "Templates are **inert data, no executable content**"; a rule AST is not inert. Bound the evaluator (no recursion, no unbounded graph traversal, a step budget) or make rules code-only (C10).

### D9. App naming, branding, icon, file association

- Name is used consistently; **no trademark search is mentioned**: "RackPal" is a plausible collision in adjacent hardware/AV markets and should be checked before any signing certificate or domain is bought.
- **No icon, no logo, no wordmark asset, no splash, no window icon, no document icon, no colour identity** beyond the wire palette. `ux-rack §9.1` shows "▦ RackPal", a placeholder glyph. The PDF title block prints "RackPal" as text (`ux-schematic §1.7`).
- **No file-type registration** for `.rackpal` / `.rmdev` / `.rmlib` on Windows/macOS. Without it, double-click-to-open fails, the recents list is half-useful, and `desktop_drop` is the only entry path.
- No branding hook in the PDF title block, despite `architecture §12.3` naming "Company branding in the PDF title block" as a *later* feature, for a firm handing drawings to clients, the integrator's logo is close to table stakes.

### D10. Distribution and code signing: **absent from all six documents**

This is the largest unowned area in the project.
- **Windows**: installer choice (MSIX / Inno / NSIS), **OV or EV code-signing certificate**: an unsigned exe triggers SmartScreen, which for a professional tool sold to businesses is an adoption blocker, and reputation-building on an OV cert takes weeks; per-user vs per-machine install; VC++ redistributable; file associations; uninstall.
- **macOS**: Developer ID signing, **notarisation and stapling**, hardened runtime, entitlements for user-selected file access, DMG or pkg, and the `printing` plugin's pdfium binaries must be signed and notarised too.
- **Linux**: packaging choice (deb / AppImage / Flatpak / snap) and GTK dependency set.
- **CI release pipeline**, version numbering scheme, release notes, artifact retention, crash-symbol archival.
- **`printing`'s build-time pdfium download** (`architecture §8.6` flags it as a CI risk) is also a **supply-chain and reproducible-build** problem for a signed release. Vendor the binaries.

### D11. Accessibility

`ux-rack §10` is the best a11y section I have read in a design document of this kind, focus regions, two-level canvas focus, the insertion caret announcing every U, `Semantics` on real widgets, the Rack Outline tree as the primary AT surface, `textScaler` to 2.0, `disableAnimations` with a *replacement* affordance for the shake, high-contrast, 24/44 px targets, and the correct `shouldRebuildSemantics` note.

Then:
- **`ux-schematic` has no a11y design.** It has an Outline panel and asserts the connections table is "screen-reader navigable for free," but **there is no fully specified keyboard path to create a connection**. `W` begins a wire from a selected port and `Tab` cycles ports on the *selected device*, targeting a port on a *different* device by keyboard is unspecified. No announcements, no focus regions, no semantics spec.
- **`ux-device-builder` has none** (a data grid is natively accessible, but the Quick Add DSL, the archetype dialogs, the bank tree, and the panel-layout canvas are not addressed).
- **Contrast will fail in the schematic.** Filtered wires at "**8% alpha**", non-focused content at "**10%**", drag-dim at 35%, focus dim to greyscale. `ux-rack` commits to 4.5:1 text / 3:1 outlines; `ux-schematic` commits to nothing and its ghost states are far below any threshold.
- **The rack editor's device fills are category-coloured** with no non-colour encoding, against `ux-rack §10.4`'s own rule ("No information is conveyed by colour alone").
- **Outline panel binding collides** (B80).
- No WCAG target named, no screen-reader test matrix (NVDA/JAWS/VoiceOver), no a11y acceptance criteria.

### D12. Internationalisation

`architecture §12.1` does the right thing (ARB from commit one, `LabelKey` enum for core command labels, `intl` formatting, explicit non-goal that the canvas stays LTR). Then:
- **All four UX documents hard-code English**: every label, every message, every empty state.
- **The Quick Add DSL and the CSV synonym table are structurally English-only** (`hdmi`, `in`, `out`, `rear`, `poe:at`; `room`, `cable_type`, `footage`). No document acknowledges this. A localised build ships an English command language.
- **`SignalFamilyDef.displayName`/`shortTag`, `ConnectorTypeDef.displayName`, `MediaTypeDef.displayName` are single strings**, not localisable maps, so a German build shows English signal names in the legend it prints.
- **No locale-aware number parsing** in the grid cells (`7,3` for weight).
- **`intl` `0.20.0`** is pinned in `architecture §8.4`; the ARB/`gen-l10n` toolchain is described but no `l10n.yaml` or generation step appears in the build order or CI.
- **PDF localisation** is flagged as later but the export signature is only *asked* to be designed for it, not specified.

### D13. Print correctness

Strong on palette, weights, dashes, fonts, subsetting, and the greyscale argument. Missing:
- **Printer margins vs the 10 mm border.** Most desktop laser printers cannot print within ~5–6 mm of the sheet edge on all four sides; the border and the zone marks will clip. No "fit to printable area" vs "actual size" decision.
- **No colour management.** The palette is sRGB hex; a print shop's CMYK conversion will shift it, and the greyscale collision analysis (`#56B4E9` 0.401 vs `#E69F00` 0.416) is computed on relative luminance, not on a printer's dot gain.
- **Greyscale handling is specified for wires only**: not for device faceplate fills, category tints, the elevation, or the header bands.
- **No PDF tagging/structure spec** despite "selectable text in the schedule is a real differentiator." dart_pdf's tagging support is limited; if an accessible PDF is a goal it needs its own investigation.
- **No print test matrix**: no commitment to test on a real laser at ANSI B/A3, a plotter at ANSI D, and a photocopy/fax reproduction, which is what the entire dash-pattern argument is predicated on.

### D14. Large-project behaviour

`architecture §10` sets targets and caps and derives them arithmetically (the "1000 wires × ~4 µs ≈ 4 ms" reasoning is exactly right). Missing:
- **"Degrade gracefully past this" has no design.** What happens at 501 devices, 3001 connections, a 60U × 12-rack project, a Structure with 500 drops, a 288-port template, a 3 MB file, a 200-sheet set? Refuse / warn / degrade is undecided.
- **`ux-schematic §4.6` states a degradation policy with no mechanism**: "300+ | the **schedule** is the primary artefact and the diagrams are navigation." Nothing switches modes automatically, and 300 is *inside* `architecture`'s normal target of 1000.
- **No progress or cancel on any long operation except PDF export.** Open, save, full DRC sweep, auto-layout on a dense sheet, CSV import of 2000 rows, template update across 200 instances, catalog load, all can exceed a second.
- **Scene/`ui.Picture` size for 3000 wires is unbudgeted**, as is memory for embedded `TemplateSnapshot`s (40 templates × full bodies, plus images if C4 goes the other way).
- **The layout algorithm's claim and the budget disagree by 10×** (`ux-schematic §3.3`: "sub-millisecond at N = 300"; `architecture §10.2`: "cold re-route, 1000 wires ≤ 40 ms"). Not a contradiction, but the budgets were not derived from the chosen algorithm and one of them is untested.
- **The perf harness is warn-only for three months**: sensible, but it means no perf regression can fail a build during exactly the period the hot paths are written.

### D15. Concerns not on the brief's list but unowned

- **DRC rule testing.** ~60 rules with real electrical consequences (`DIR-003` destroys hardware; `ELE-004`/`ELE-006` damage amplifiers) have **no test strategy, no fixture corpus of known-good/known-bad designs, and no domain-expert review step**. `architecture §9` tests migration, commands, scenes, and PDF structure, not the domain logic that is the product's entire wedge.
- **Catalog data provenance** (C36).
- **Label-printer export**: "a label-printer profile (Brady/Dymo/Brother) that emits both-ends labels per run" is one line for a feature integrators will judge the product on daily.
- **Import has no architectural home at all** (Structure CSV, `.rmdev`, `.rmlib`, "importing a device list" from `ux-rack §2.4`).
- **No project-settings screen and no project-metadata screen.** `Project` has ten title-block fields (`projectNumber`, `clientName`, `siteAddress`, `integratorLicense`, `drawnBy`, `checkedBy`, `approvedBy`…) and `ProjectSettings` has ~20 settings, **all unreachable**. Three documents reference "settings" as if the screen exists.
- **`Note` has no UI.** Six note kinds (callout, dimension, revision cloud, general note, warning), leader targets, callout shapes, and the only authoring affordances anywhere are "Add Net Label · Add Text."
- **Revision block: authored or generated.** `data-model` models `RevisionEntry` as authored; `pdf §12` decision 5 says "revision block **generated from project history**", and there is no project-history entity.

---

## (E) Proposed milestone plan

No document defines v1. `architecture §13` and `pdf §11` both give *build orders* (engineering sequences with no user-visible increment, no acceptance criteria, and no cut list) and they conflict on when the PDF work starts (`architecture` puts it at step 10 of 12; `pdf` wants its steps 1–5 front-loaded in week one, and `pdf` step 3 depends on `architecture` step 6). Here is a plan.

### The smallest genuinely useful v1

> **One integrator can lay out one rack, wire it, and hand a contractor a PDF that is correct enough to build from.**

Concretely, v1 ships when a user can: create a rack of arbitrary RU; populate it from a seeded catalog and from templates they built or forked themselves; declare the structured wiring entering the rack; connect ports; see live rack vitals and the errors that matter; and export a drawing set containing a rack elevation, an interconnect diagram, and a wiring schedule, from a file that will still open in five years.

**That is defensible because** each of the seven requirements is represented, nothing in it is demo-ware, and every deferred item below is genuinely additive rather than load-bearing. It is also the shortest path to the only test that matters: giving the PDF to an installer and watching them use it.

**Explicitly out of v1**, with the reason:

| Deferred | Why it is safe to defer |
|---|---|
| Buses, vector pins, unit splitting | Density mechanisms; net labels alone cover 0–80 connections, which is most residential jobs |
| Multi-sheet + off-sheet connectors + zone grid | Single ANSI B sheet + net labels covers v1's scale; this is the largest single feature in the schematic doc |
| Auto-layout, preview-diff, pin/unpin, tidy/re-flow | A deterministic first-pass layout plus manual dragging is sufficient; the preview-diff is excellent and expensive |
| Layers / phasing | `DeviceStatus` covers new/existing/future for v1 drawings |
| Focus / Isolate / Trace / minimap / search DSL | Navigation aids for projects larger than v1 targets |
| Rear-panel view | The highest-value *deferred* item; ship it first in v1.1 |
| `SignalRoute` (Dante/AVoIP/matrix crosspoints) | Commercial-scale modelling; nothing in v1 consumes it |
| Multi-conductor `Conductor` UI | Model it, don't expose it; v1 writes N rows for a 16/4 run and v1.1 collapses them |
| BOM, cost fields, label-printer export | Adjacent products; no requirement asks for them |
| Mobile/tablet review mode | Confirmed as v1 in the brief but only 1 of 4 surfaces is designed; ship as v1.1 with all four |
| Quick Add DSL, archetype generators, TSV paste, manual panel layout | The grid + fill-down covers template authoring; the DSL is a speed feature |
| Bundles (both kinds), adapters as devices, SVG export, cloud sync | Additive |

---

### M0: Reconciliation *(no code; 1–2 weeks)*

The single highest-leverage work in the project. Produce **normative** documents that supersede the five design docs (which become non-normative rationale, which is what they are good at):

- `docs/glossary.md`, one term per concept, resolving B6/B10/B42/B50/B51.
- `docs/model.md`, the entity set, the unit, the ordering type, the ID scheme. Resolves C1–C6.
- `docs/file-format.md`, envelope, container, migration contract, `.rmdev` contract. Resolves B70–B76.
- `docs/rules.md`, one rule catalogue: ID, scope, severity, blocking, predicate-in-prose, and **a worked example of a design that violates it**. Resolves B12–B15, C7–C11.
- `docs/keymap.md`, one arbitrated table across all views. Resolves B80.
- `docs/visual-language.md`, palette, dash, weight, glyph, typography, and where each is defined. Resolves B59–B63.

**Exit criterion:** a reviewer can diff each normative doc against the five design docs and every remaining difference is annotated as *"superseded, see §X."* Zero unresolved contradictions from section (B).

### M1: Spine *(weeks 3–5)*

Workspace + packages (per C29); units; `RackDocument` with epoch counters; `Command`/`Transaction`/`UndoStack`/`DocumentController`; hand-written JSON codec; migration harness + `v1_minimal` fixture; `no_flutter_import_test`; the command round-trip property test; `ViewportController` with wheel/trackpad and zoom-at-cursor; grid painter. **Plus `pdf §6.11`'s five verification spikes in a throwaway `bin/spike.dart`**: they are a day's work and they de-risk the entire export feature, so they belong here, not at M4.

**Exit:** create a rack in code → save → reload → undo → byte-identical round-trip; `dart test` under 2 s; the spikes confirm the `pdf` API behaves as assumed.

*Rationale for ordering:* `architecture §13` correctly identifies steps 3 (undo) and 6 (display list) as the two "do it now or pay 10× later" retrofits. This plan does undo here and the display list in M2 by construction rather than as a retrofit.

### M2: Rack editor *(weeks 6–11)*

`RenderRackCanvas` hybrid; rails/holes/ruler with the Tier-1 cache; device widgets; palette drag with RU snap and the validity cascade; move/nudge/duplicate/delete; selection + marquee; inspector; **~20 seeded templates covering all eight categories**; rack vitals (RU front/rear, weight, power, BTU, circuits); the rack-level DRC rules; empty state; new-rack dialog; shrink dialog; RefDes assignment + renumber; save/open/recents/close-interception/autosave/recovery.

**Build the rack painter on `DiagramCanvas` + `DiagramScene` from the first line**: including device faceplates, which resolves C31 by construction and makes M4 nearly free.

**Exit:** `ux-rack §9.4`'s nine-keystroke script works end to end; the file round-trips; the migration corpus has a second fixture.

### M3: Ports and wiring *(weeks 12–18)*

Ports instantiated from templates; the schematic canvas with a deterministic first-pass layout (Sugiyama phases 0–4 from `ux-schematic §3.2`, no preview-diff, no pinning UI beyond "a manual move sticks"); wire drag + sticky + **chain-draw** + **multi-draw** (the two highest-throughput gestures, `ux-schematic` is right that they are worth building first); magnetic snap; the connections table with bidirectional selection sync; net labels as the density valve; the topology-blocking rules plus **the ten highest-value advisory rules only** (SIG-001, DIR-001, DIR-003, CON-001, ELE-003, ELE-006, NET-001, PWR-001, PWR-003, LEN-001).

**Exit:** wire a 20-device rack; the table and the canvas agree exactly; a deliberately-wrong design produces exactly the ten findings and each one can be acknowledged with a reason that persists.

### M4: Export *(weeks 19–23)*

`PdfDiagramCanvas`; the parity test **including device faceplates**; sheet furniture (border, zone grid, title block, revision block); legend sheet; elevation sheet; interconnect sheet; schedule sheet with manual pagination; ANSI B/A + ISO A3/A4; the isolate with progress and cancel (per C33); screen-renderer preview; the export dialog; CSV export.

**Exit:** print a real job on a real laser printer and hand it to an installer. This is the milestone where the product either is or is not worth building; everything before it is scaffolding and everything after it is refinement.

### M5: Structure device *(weeks 24–28)*

Location tree editor; matrix bulk entry; drop table; automatic drop→port generation; drops rendered as off-page connector flags with room grouping and unused-collapse; drop schedule sheet; the "unused home runs" page; CSV import with column mapping.

**Exit:** a 60-drop house rough-in imports from a contractor's spreadsheet and produces a correct pull list and a correct drop schedule.

### M6: Device builder *(weeks 29–35)*

Identity / Physical / Power sections; the port grid with fill-down, fill-series, multi-row edit, duplicate, reorder, renumber, change-type, move-to-bank; auto panel layout with the **completed** footprint table (A2.2); the three live previews; `.rmdev` read/write with its own migration chain; fork-from-seeded; fork-from-instance; the Template Update Manager with `Keep`/`Remap` (no one-click `Del`, see D5); the full 62-template catalog with a documented data source.

**Exit:** build the 8×8 HDBaseT matrix from scratch in under five minutes; edit it breakingly; remap the affected cables; lose nothing.

### M7: v1 hardening *(weeks 36–44)*

Everything in section (D) that is a shipping requirement rather than a feature:

- Help menu, shortcut panel, glossary, rule-rationale viewer (`[ Why? ]`), error-message catalogue.
- Four sample projects, authored as real files, doubling as golden/perf fixtures, at least one exercising the Structure device and exporting cleanly.
- Every missing empty state and every missing file-layer error state (D3, D4).
- Licences screen with OFL/Apache attribution wired; EULA; licence model.
- Icon, wordmark, splash, window icon, document icons, file associations, trademark check.
- **Installer + code signing + notarisation on Windows and macOS**; vendored pdfium; release pipeline. *(Start the Windows OV/EV certificate procurement at M4, reputation and validation take weeks.)*
- Accessibility pass on the schematic and the device builder; contrast audit of every dim/ghost state; screen-reader matrix.
- Large-project envelope: documented limits, a soft warning at 1.5×, an "open anyway / read-only" gate at 3×, progress+cancel on every operation over ~500 ms.
- Print test matrix on real hardware, including margins and a photocopy reproduction.
- The DRC fixture corpus and a domain-expert review of the ~30 shipped rules and the 62-template catalog.
- Crash-recovery UX; diagnostics bundle with the redaction contradiction fixed (B77).

**Exit:** ship.

### Post-v1, in order

**v1.1**: Rear-panel view (the highest-value deferred item; it is the installer's page and it is what makes the device builder's output tangible). Mobile/tablet review mode across all four surfaces. Multi-conductor link UI. Label-printer export.

**v1.2**: Buses, vector pins, unit splitting, multi-sheet with off-sheet connectors and zones. This bloc is what takes the product from residential to commercial scale, and it is coherent as one release.

**v1.3**: Auto-layout with preview-diff and pinning; Focus / Isolate / Trace; search DSL; minimap. Navigation and polish, all of it designed already.

**v2**: Layers/phasing; bundles; `SignalRoute`; BOM; cloud sync (the model is ready; the app is not).

---

### Two sequencing warnings

1. **M0 is not optional and cannot be compressed into M1.** Sections (B) and (C) contain at least six decisions (the unit, the wiring entity set, the blocking policy, the join key, the package layout, and text measurement) where guessing wrong costs a rewrite of everything downstream of it. The design documents are individually strong enough that it is tempting to start coding from them; they disagree with each other in ways that only surface at integration, which is the most expensive place to find them.

2. **The `RulePredicate` decision (C10) should be made before M3, not during it.** The rules-as-data architecture is the justification for several other decisions (`data-model §3.4`'s enum rejection, the embedded registries, the user-extensibility claims, and the `.rmlib` sharing story). If rules end up as code (which I expect, given `NET-003`, `ELE-008`, and `BUS-005`) then several of those arguments weaken and the registries can be simplified considerably. Deciding it late means either building an interpreter nobody needs or refactoring the registry design after it has shipped in a file format.