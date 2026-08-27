# RackPal: Design Review: Usability & Scope Discipline

## Verdict up front

This is exceptionally good engineering design and a badly overscoped product. Almost every individual decision is defensible; the *set* of them is not shippable by one developer in a year, and several of the most expensive ones actively make the first session worse.

The design has the right thesis and the wrong budget. It states (correctly, repeatedly) that **the schedule is the truth and the diagram is navigation**. Then it spends roughly 70% of its design effort on the diagram: a Sugiyama layout pipeline, channel routing, bus rendering, unit splitting, off-sheet connectors, zone grids, hop arcs, sheet partitioning, preview-diff auto-layout. Meanwhile the artifact that actually gets taped inside the rack door, a cable schedule an installer can pull from without phoning anyone, is gated behind a canvas the user must learn before they can create a single connection, and then gated *again* at export by two separate blocking rules.

What's genuinely right and must be protected: UUIDv7 + tombstones + per-entity metadata + flat maps + fractional indices (cheap now, rewrite later); the command stack before the feature surface grows; the display-list IR shared by screen and PDF; integer units; hand-written codecs; the outline tree for accessibility; `PortDef.key` as a stable join. Those are the "do it now or pay 10×" items and the architecture spec called them correctly. None of my cuts touch them.

---

## The core loop

> **Drop a device into a rack. Click two ports. Repeat. Export.**
>
> The output is a cable schedule. The drawing is a receipt.

Everything in v1 either serves that sentence or gets cut. Test for any feature: *does it make the schedule more correct, or does it get the user to the schedule faster?* Auto-layout preview-diff, DMX universe validation, TIA-606 label pattern engines, and BTU calculations all fail that test.

---

## Prioritised cut list

Ordered by engineering cost saved × user confusion removed.

### 1. The editable schematic canvas and its entire layout engine: CUT

This is the single largest item and it's roughly half the remaining work. Gone: cycle-breaking, layering, barycentre sweep, coordinate assignment, channel routing, track ordering, hop arcs, junction staggering, symbol pinning, preview-diff with variant cycling, `Tidy/Re-flow` at four scopes, unit splitting (`MTX1:A/:B/:C`), buses with 45° entries, off-sheet connectors, zone grids, sheet partitioning, the stale-layout chip.

**Replace with:** wire on the rack elevation (rear face), and *generate* a read-only diagram at export time. Nobody hand-edits a KiCad netlist report either.

The counter-argument, "the trade expects a signal-flow drawing", is real, and it's satisfied by generating one. It does not require letting the user drag symbols around.

### 2. `SignalRoute`: CUT entirely

Dante flows, AVoIP streams, matrix crosspoints, eARC logical return, VLAN/multicast/latency/bandwidth. A third entity layer above Link and Net, plus rules NET-003/004/005 and derived crosspoint computation. Nobody buys a rack designer to model Dante subscriptions. Delete the class; the physical cable already carries the information a schedule needs.

### 3. Stored `Net`: DERIVE it in v1

The spec's defense of stored nets is well-argued but every argument is about buses, 70V taps, RF cascades and bus terminators, all of which I'm cutting. Without user-named nets, colored nets, or `N###` designators, the "labels flicker on merge" objection evaporates. Keep the JSON field for forward compatibility; ship zero UI.

### 4. `Sheet` as a document entity: CUT

NCS numbering, zone letter/number grids, per-sheet items, `carriesLegend` with its blocking invariant, sheet filters, contact-sheet view, sheet navigator. Sheets are an **export-time construct** in v1: the export dialog picks a paper size and emits a fixed set. See the density section for why this costs nothing.

### 5. Layers (Existing / Phase 1 / Phase 2 / Future / Demo): CUT

Real for commercial retrofit, absent from the residential first job, and it multiplies every filter, every view, every print flag. `DeviceStatus{existing, new, future, removed}` already covers 80% of the need and is one field.

### 6. The derived-metrics cluster: CUT to two numbers

Circuits, NEC 210.19 continuous-load derate, PoE budgets, BTU/hr, centre-of-gravity sparkline, top-heavy warnings, thermal class, clearance-above/below, outlet accounting, nameplate-vs-typical toggle, sequencer steps.

This is the most dangerous cluster in the design, and not because it's expensive. **It fabricates data and then presents it with authority.** `typicalWatts` defaults to 50% of nameplate. BTU derives from that guess. CG derives from weights the user copied from a spec sheet or made up. Then the design paints those numbers amber and red, and `blockExportOnErrors: true` lets them stop a PDF.

The first time RackPal says "Circuit A at 14.2 A of 16.0 A" and the integrator puts a clamp meter on it and reads 6 A, they stop trusting *every number in the app*, including the ones that are right.

**Keep exactly two rollups: RU used/free, and total weight vs rack capacity.** Both are facts the user actually supplies. Everything else moves to an unbadged, non-blocking info panel, or waits for v2.

### 7. The DRC catalogue: CUT from ~60 rules to 6

Ship: source→source, connector mismatch with no adapter, HDBaseT into an Ethernet switch port, port over `maxConnections`, RU overlap, duplicate designator.

Cut: every length rule, every bus rule, every impedance rule, every power rule, DMX universes, DALI device counts, Cresnet voltage drop, RF cascade loss, satellite DC-pass, speaker polarity and impedance, fiber polarity. Each is a chance to be confidently wrong about a system the user knows better than the app does.

Cut the acknowledge-with-written-reason machinery too. It is exactly right for a professional as-built deliverable and exactly wrong for minute 10 of someone's first session, where it presents as "type an essay to dismiss this yellow triangle."

### 8. Template versioning, diff view, and the Update Manager: CUT

Semantic version bump computed from a change classifier, two-column diff view, the Update Manager with safe/additive/breaking groups, per-cable remap dropdowns ranked by similarity, and conflicts-with-local-edits merge resolution. This is a package manager.

**v1: templates are copy-on-place, full stop.** Keep `templateRef` in the file so updates can be added later without migration, that part of the data model is correct and free. The loss ("fix a wrong port count across 12 instances") is real and rare, and the fallback is survivable.

### 9. The Structure editor's advanced half: CUT

Keep: the room × media matrix with integer spinners (genuinely fast, genuinely cheap), and a flat drop table with room / media / label / connected-to.

Cut: the TIA-606 pattern engine and five label presets, bundles, CSV import with 20-column synonym mapping and wide/long shape autodetection, `RoughInStatus` lifecycle, `TestResult` with headroom dB and certifier IDs, multiple Structure instances, jacket colour, conduit, reel ID, dual field/rack labels.

The dual-label point ("the schedule carries one and the tech needs the other") is a genuinely good observation from the field. It is also a v2 observation.

### 10. Template file infrastructure: CUT to the minimum

`.rmlib` packs, content-addressed hashes, `provenance`, `derivedFrom` lineage, signature reservation, integrity checks that hard-fail on load. v1: a template is a JSON file with a UUID and an integer version. The "inert data, no executable content" framing is right and should stay in the copy; the cryptographic apparatus around it should not ship.

### 11. Shelves: KEEP, but strip the interaction model

Hosted devices are real and common. Cut lateral twelfths, free-position mode, `Alt`-drag positioning, the third focus level you enter with `Enter`, and per-host depth-overhang warnings. Auto-pack left to right, done.

### 12. Zero-U gutters and vertical PDUs: CUT

`ZeroUChannel`, `ZeroUPlacement`, the 16px gutters, rotated bar rendering, the `G` toggle, overlap warnings. The main justification was outlet accounting, which is cut in #6. A 0U PDU becomes an off-rack device.

### 13. Auto-arrange with trade heuristics: CUT

Heavy-low, amp spacing, vent-above-heat, 15% spare RU, with per-rule checkboxes in the preview bar. The spec correctly notes integrators have strong and differing opinions, which is the argument for not shipping it. Compact up/down is enough.

### 14. Keyboard surface: CUT roughly 60%

~90 bindings in the rack spec, ~80 in the schematic spec. Ship 25. And they currently **collide**, which is a bug not a preference:

| Key | Meaning A | Meaning B | Meaning C |
|---|---|---|---|
| `Shift+F` | Toggle Both-faces view | Move selection to opposite face | Isolate (schematic) |
| `Ctrl+P` | Export PDF (rack) | Command palette (schematic) | — |
| `Ctrl+1` | Zoom 100% (rack) | Switch to Rack view | Toggle domain 1 |
| `Ctrl+B` | Fill gaps with blanks | Create bus | — |
| `Ctrl+R` | Renumber dialog | Reverse connection direction | — |
| `Ctrl+L` | Lock position | Toggle wire ↔ net label | — |
| `G` | Toggle 0U gutters | Toggle grid | — |
| `L` | Cycle label mode | Tidy selection | — |
| `F` | Flip face | Focus | — |
| `T` / `W` | (rack: unbound/warnings) | Trace / marquee-wires | — |

`Shift+F` is defined twice *within the same document*.

### 15. Do NOT cut

- The **outline tree**. Cheapest correct thing in the design, doubles as power-user navigation, and it's the only honest accessibility story a canvas app has.
- **UUIDv7, tombstones, per-entity meta, flat maps, fractional indices.** Free now, rewrite later.
- **Dash pattern + text tag alongside colour.** Roughly free, and correct for CVD and for the office laser printer. (Cut the fourth glyph channel and the second TIA-606 termination-colour dimension.)
- **The 62-template seeded catalog**, but ship it at *lower fidelity*. Name, RU, depth, weight, ports. Drop typical watts, BTU, clearance, thermal class from all 62. Halves the authoring effort and stops feeding the fabricated-data problem.
- **The command stack and the display-list IR.** Build order steps 3 and 6 in the architecture spec are correct: those are the two retrofits that cost 10× later.

---

## Friction inventory: the actual first session

| Time | What happens | Friction |
|---|---|---|
| 0:00 | Start card: Blank / Home theater / Network closet / Conference / Open | **None. This is the best screen in the design.** Starter projects as first-class is right. |
| 0:30 | New rack dialog: Name, Location, Preset, Height | Minor: `Location` is a combobox bound to a vocabulary that doesn't exist yet. An empty required-looking dropdown on field two of the first dialog. |
| 1:00 | Empty rack, hint card, caret at U1 | **None. Also excellent.** |
| 1:00–4:00 | `/ ups ⏎ / 16ch ⏎ / vent ⏎ …` | **None. This is the product's best interaction and it should be the demo.** |
| 4:00 | User wants to wire | **Cliff #1.** The rack editor has no wiring. They must discover `Ctrl+2` / the SCHEMATIC tab with no signposting from a rack that is now full of unwired devices. |
| 4:15 | Schematic opens with an auto-layout they didn't choose | **Cliff #2.** "Why does my rack look completely different here?" The spec's answer (positions are deliberately unlinked, §5.2) is correct engineering and unexplained at the moment of surprise. If you need an eight-row sync table to justify a behaviour, the user is going to hit it before they read the table. |
| 5:00 | Drag from a port; canvas dims, compatible ports pulse | **None. Genuinely great.** Magnetic type-weighted snap and chain-draw are the strongest interactions in the whole design. |
| 5:30 | They need to wire to the TV, which isn't in the rack | **Cliff #3, and it's a spec inconsistency.** The schematic has its own LIBRARY panel and `+ New device`. So there are now two places to add a device with different consequences (racked vs. `UnplacedPlacement` vs. Staging Bin), and the specs don't reconcile which one you get. |
| 6:00 | They need a wall plate → the Structure device | **Cliff #4.** Four-region editor, location tree, 9-column media matrix, TIA-606 presets, bundles, CSV import. The user has *one* wall plate with an HDMI and a Cat6. The matrix mode is tuned for the 60-drop job and is actively hostile to the 2-drop job. |
| 8:00 | First DRC finding | Remedy chips (`[Insert HDBaseT receiver]`) are excellent. But if it's a warning, dismissing it requires typing a written justification. |
| 10:00 | `Ctrl+P` → export | **Cliff #5, and it's the worst one.** `blockExportOnErrors: true` is the shipped default. Their very first export can be blocked by a rule about a system they haven't finished designing. |
| 10:05 | Second export attempt | **Cliff #6.** Data-model invariant #41: any sheet with `carriesLegend == false` must carry a non-empty `legendLocationNote`, and this *blocks PDF export*. A drafting-convention invariant can stop a user from getting their file. |

**Additional friction, not time-ordered:**

- **Nine identifier systems.** `refDes` (MTX-01), `name` ("Main HDMI Matrix"), `typeName`, port `designator` (J2401), port `userLabel`, link `designator` (W042), net name (`HDMI_MTX1_OUT3`), drop `fieldLabel` (LR-TV-1A), drop `rackLabel` (1A-A12). The spec is right that these are distinct concepts. Exposing all nine in v1 is not. Ship three: device refdes, port label, cable ID.
- **`ruNumbering` is a project setting in the data model and a per-rack setting in the rack spec.** Pick one. (Per-rack is the better answer, the retrofit-rack justification is sound, but the data model doesn't have the field.)
- **Mirrored rear elevation, default on.** Physically honest and correct. A first-timer will place a device on the front, flip to rear, and see it on the wrong side. There's a coach mark budgeted for first-placement and first-warning; there isn't one for this, and this is more surprising than either.
- **The shrink-rack dialog is superb** and should be the model for every other destructive operation. Named casualties, wire counts as the cost signal, no delete option, non-destructive preselected. Nothing else in the design is this careful.

---

## Two views or one?

**The case for two (the spec's position).** Rack position is physical, thermal, weight, service access, cable reach. Schematic position is logical, signal order, readability. An AVR sits at U14 for heat and belongs mid-chain logically; a UPS sits at U1 physically and is a leaf node logically. Slaving one to the other means every thermal decision scrambles the reader's mental map, and the failure is silent and unrecoverable: twenty minutes of layout work destroyed by a rack reorder. This is correct, and the "seed and tie-break, never slave" resolution is the right *engineering* answer.

**The case for one.** Two canvases means two mental models, two coordinate systems, two selection behaviours, two shortcut tables (which already collide), and a what-syncs-what-doesn't table with two exception rows that the user meets as a surprise before they meet it as documentation. Meanwhile the rear elevation is *already* the wiring surface, the schematic spec says so itself: "the rear panel says which physical jack to plug into… this is what gets printed and taped inside the rack door," and "the rear panel view **is** the device builder's output surface." The design contains a unified model and then doesn't use it.

**Pick: one view for v1.** Wire on the rack elevation, rear face by default. Off-rack devices and Structure drops live as labelled stubs in gutters flanking the rack. Do not draw cable lines by default, draw a badge on each connected port showing the far end (`→ SW-01 P04`), and reveal lines only under a domain filter or on hover/focus. Generate the schematic as read-only PDF output.

This kills the entire layout engine, both hit-testers, both undo semantics, the sync table, cliffs #1 and #2, and the where-do-I-add-a-device ambiguity, at the cost of a v2 feature you'll be better qualified to design once you've watched ten people use v1.

The strongest objection: whole-house systems where most cables are rack→room, turning the gutter into 60 stubs. Answer: those *are* Structure drops, the spec already renders them as a bank of labelled flags grouped by room with unused-collapse, and the port-badge default means you never draw 60 lines.

---

## The density problem, evaluated honestly

**20 devices, 150 cables, one sheet: impossible. Not hard: arithmetic.**

ANSI B landscape is 432 × 279 mm. Minus 10 mm margin, 5 mm frame, and a 180 × 50 mm title block, usable area is roughly 400 × 250 mm = 100,000 mm². At the spec's own sizing rules a modest symbol (20U minimum width, header plus eight pins per side) is about 60 × 70 mm = 4,200 mm². Twenty of those is 84,000 mm². **The device bodies alone consume 84% of the sheet before a single wire is drawn.** The spec's own legibility trigger (`k × minTextPt < 6.0`) agrees; it just doesn't say out loud that at 20 devices the trigger is not a fallback, it's the only path.

So: multi-sheet is mandatory at target scale, not optional. Now grade the mitigations against that reality.

| Mitigation | Cost | Verdict |
|---|---|---|
| **Domain filter bar** (8 chips, solo/toggle, ghost vs hide) | Low | **Essential. Ship it.** This is the load-bearing mechanism. |
| **Net labels instead of drawn wires** | Low | **Essential.** Single highest legibility-per-line-of-code item in the design. |
| **Focus / `Alt`+hover transient focus** | Low | **Ship.** `Alt`-hover with no click and no mode is the best idea in the schematic spec. |
| **Symbol collapse to vector pins** | Low | **Ship.** |
| **Multi-sheet by domain** | Medium at export, **high as a document entity** | Ship as *export*, cut as *entity*. See below. |
| **Buses with 45° entries** | Medium | Cut. Graphical-only, and net labels already collapse the fan-out. |
| **Unit splitting (`MTX1:A/:B/:C`)** | High | Cut. One device rendered as three bodies across multiple sheets is a confusion generator, and collapse covers the same ground. |
| **Layers** | Medium | Cut (#5). Not a density fix. |
| **Trace signal path through pass-throughs** | High | Cut. Requires modelling continuity through patch panels, switch VLANs, matrix crosspoints, RF splitters and baluns. |
| **Off-sheet connectors + zone grid + cross-refs** | High | **Cut, and here's why it's free:** |

**The observation that makes multi-sheet cheap.** A cable belongs to exactly one signal domain. Therefore a **domain partition produces zero cross-sheet connections by construction.** The video sheet contains every video cable, whole. Nothing continues onto another sheet. You need off-sheet connectors, zone letter/number grids, and cross-reference resolution *only* for a geometric or min-cut partition, which the design offers as alternatives and which you should simply not ship. Devices repeat across sheets; a repeated device is just a device labelled with its refdes on both. No zone grid required.

So multi-sheet costs an export-dialog checkbox and a loop, and the expensive drafting apparatus around it disappears.

**Overall verdict:** the mitigations *are* sufficient, but only under a specific reading, the diagram is a filtered, per-domain, generated view and the schedule is the deliverable. The design occasionally contradicts this (Sheet 1 "SYSTEM OVERVIEW, all devices"). Delete that sheet. There is no legible all-devices sheet at 20 devices and pretending otherwise sets an expectation the product cannot meet.

---

## Is the device builder fast enough? Timing a 16×16 matrix

The spec's claim is "an 8×8 matrix, 16 signal ports plus a dozen ancillaries, takes under 30 seconds." That measures **port entry only** and it's plausible for port entry. It is not the time to create a template.

Honest walkthrough of a 16×16, using the spec's own affordances, for a user who knows the tool:

| Step | Interactions | Time |
|---|---|---|
| Name, manufacturer, model | 3 fields | 20 s |
| Category, subcategory, refdes prefix, tags | 4 controls | 25 s |
| `frontU`, `rearU`, side, mount method, width class, depth, depth-with-connectors, weight, clearance above, clearance below, container?, passthrough? | 12 controls | 70 s |
| Power: nameplate, typical, standby, voltage, phase, continuous-load | 6 controls, **2 of which are guesses** | 45 s |
| Matrix I/O generator: N, M, in-connector, out-connector, 5 companion checkboxes | 9 controls | 50 s |
| Fix generated banks: labels, sides, designator ranges | grid work | 60 s |
| Control + power banks the generator didn't emit | 2 DSL lines or ~12 fields | 40 s |
| Review, resolve validation warnings, publish | — | 30 s |
| **Total** | | **≈ 5.5 minutes** |

For a first-timer who doesn't know `{n:2}`, `@bank`, or that `hdbt` resolves to RJ45+hdbaset, add 3–4 minutes of exploration.

**The barrier isn't the port grid. The port grid is excellent**: spreadsheet ergonomics, fill-down, TSV paste, multi-row edit, archetype generators, the pattern DSL. Integrators do live in Excel and this is the correct instinct.

**The barrier is the 25 metadata fields in front of it, most of which the user does not know.** Typical watts? BTU? Clearance above? Depth with connectors? Continuous load? These come from a spec sheet that lists eight of them and omits the rest, so the user either guesses (feeding the fabricated-data problem in cut #6) or stalls.

**Fix:** three required fields (name, RU height, refdes prefix) then ports, then done. Everything else optional with a visible **unknown** state, and the app must degrade honestly: a device with no weight contributes nothing to the weight rollup, and the rollup says "3 devices have no weight." The data model already has `Extent{Known, Unknown}` and the UX never surfaces it. Surface it. **Missing data the user can see beats fabricated data the user can't.**

Also worth noting: for a 16×16 specifically, the right answer is "duplicate catalog entry V03 and rename it", about 15 seconds. The builder's real job is the long tail, where 5.5 minutes is arguably fine. So the builder isn't a barrier to *adoption*; it's a barrier to *completeness*, and making metadata optional fixes it without touching the grid.

---

## The single most important thing

**A cable schedule an installer can pull from without asking a question.**

Every row needs: a unique cable ID, both ends as device-refdes + physical port label, and the cable type. That's it. That is the artifact that leaves the office, gets printed, gets carried into an attic, and determines whether the tool gets used on the next job.

**Does the design prioritise it?** In its stated thesis, yes and emphatically. In its allocation of effort, no:

- The schedule is unreachable until the user has learned a second canvas with its own layout engine.
- Its export is blocked by `blockExportOnErrors: true` (default on) and by a legend-placement invariant.
- Its correctness rides on nine identifier systems, most of which are more likely to confuse than clarify in v1.
- The one thing that genuinely protects it (a single shared derivation feeding both the on-screen table and the PDF) gets one sentence in the architecture spec, while auto-layout stability gets three pages.

**Three changes that fix the prioritisation:**

1. `blockExportOnErrors: false` by default. Print the findings as an appendix page instead. Never let a heuristic hold a user's deliverable hostage.
2. Delete invariant #41's export block. A missing legend note is a lint, not a gate.
3. Make the schedule table the **second tab in the app**, reachable from an empty project, populating live as connections are made. It should be the thing the user watches fill up, not the thing they discover at export time.

---

## What v1 actually is

One window. A rack elevation with front and rear faces. A palette of ~40 seeded devices plus a builder with three required fields. Click a port, click another port, get a cable, on the elevation, no second canvas. A Structure panel that's a flat list of drops with a room and a media type. A live schedule table. Six validation rules that never block anything. PDF export: front elevation, rear elevation, schedule, and one generated diagram sheet per signal domain.

That is roughly 25% of what's specified here, it satisfies all seven of the user's stated requirements, and it's the version that finds out whether the other 75% is what anyone wanted.