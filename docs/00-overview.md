# RackMate — Product Overview

RackMate is a Windows-first desktop application in which a custom-integration professional builds one or more equipment racks, wires them port-to-port on a schematic canvas, watches a cable schedule fill in live beside them, and exports a PDF sheet set that an installer can carry into an attic and work from without making a phone call. This document is the entry point to the planning set: it states the problem, the vision, the core loop, who the product is for, the seven brief requirements restated as things you can check by running something, what the project explicitly refuses to build, where it sits against the incumbents, and how success is measured. Every statement here is downstream of the canonical decision record; where a ruling governs, it is cited by ID (`CR-nnn` contradiction resolved, `AC-nnn` accepted critique, `RJ-nnn` rejected critique) and the full adjudication is in [the canonical decision record](canonical-decisions.md).

---

## 1. Problem statement

The industry body for high-end residential integration reports that in over 95% of technology projects **no final engineering documents are ever created**. The consequences are not abstract: installation inefficiency, higher final cost, more change orders, longer service calls, and a homeowner who cannot switch service providers because nobody knows what is behind the wall. A house with 80–150 cable runs is unremarkable, and every run should carry a label at both ends that maps to an as-built drawing.

The documented reason nobody produces these documents is that every available tool is wrong in a specific way:

| Failure mode | Where it shows up |
|---|---|
| The drawing is a rendering of a database in a *second, separately licensed* application | D-Tools drives Visio or AutoCAD; the drawing can always contradict the database |
| No unique device naming, so a rack with three identical amplifiers cannot produce a correct schedule | XTEN-AV — a verbatim, citable user complaint |
| A drawing tool with symbol properties, but no typed connection model behind it | AVSnap (free), Stardraw |
| A correct data model for the wrong domain — Ethernet, fibre and power only, no HDMI/IR/RS-232/RG6/TOSLINK | NetBox, Device42, Sunbird dcTrack |
| No data model at all; accuracy depends entirely on manual labelling discipline | Visio, draw.io, Lucidchart |
| A $9,000/yr floor and $200/hr professional services to onboard | D-Tools SI |

Nobody ships a cheap, desktop, AV-typed, netlist-backed rack-and-wiring tool that emits a correct cable schedule. That is the gap.

The second half of the problem is a documentation failure that no data model fixes by accident: **labels that do not match the language people use.** The plan says "Study", the homeowner says "Office", the label says "Room 3", and nobody wins. RackMate binds a location vocabulary to the model so one rename propagates to every label, schedule row and diagram callout (CR-047, CR-112).

---

## 2. Product vision

> **RackMate is a cable-schedule generator with a rack elevation and a schematic on the front of it.**

The artifact that justifies the product is the one that leaves the office, gets printed, gets carried into an attic at 7 pm, and tells an installer what to pull, where it goes, what to call it, and where to land it. Everything upstream of that artifact is data entry, and the software's job is to make the data entry fast enough and structured enough that the artifact is **correct by construction rather than by proofreading**.

Five principles decide the close calls (canon §0.1), and they are quoted here because most of this document is them applied mechanically:

| # | Principle |
|---|---|
| **G1** | The schedule is the deliverable; the drawing is the receipt. |
| **G2** | The document must be able to represent a wrong, incomplete, or found-in-the-field world. Only model-incoherence is illegal. |
| **G3** | A heuristic may never hold a user's deliverable hostage. |
| **G4** | Never fabricate data. Show `unknown`. |
| **G5** | Cut features, never foundations. |

G4 has teeth. `typicalWatts` never defaults to half of nameplate (AC-039, RJ-007); a missing weight contributes nothing to a rollup and the rollup reports its unknown count. The failure mode being avoided is not a missing feature — it is an integrator who puts a clamp meter on a circuit RackMate called 14.2 A, reads 6 A, and stops trusting every number in the product including the correct ones.

G3 has teeth too. `blockExportOnErrors` is **deleted, not deferred** (CR-022). Nothing gates the bytes of a PDF. Open errors gate exactly one thing: the `ISSUED FOR CONSTRUCTION` stamp.

---

## 3. The core loop

Canon §8. One unbroken sequence, and every step of it was a cliff in the raw design corpus:

```text
  create a rack
        │
        ▼
  populate it from the catalog by TYPING, not dragging      "/ ups ⏎  / 16ch ⏎  / vent ⏎"
        │
        ▼
  wire it by clicking a port and then another port          magnetic type-weighted snap
        │
        ▼
  watch the schedule fill in live beside you                a TOP-LEVEL TAB (Ctrl+4), not an export artifact
        │
        ▼
  export a sheet set that is complete and honest on the first attempt
```

The five cliffs the rulings exist to remove, in the order a first-time user meets them:

| # | Cliff | Ruling |
|---|---|---|
| 1 | The rack editor has no wiring surface and no signpost to the one that does | CR-105 — wiring is signposted from the elevation; a coach mark fires on the first switch (CR-104) |
| 2 | The schematic opens with an auto-layout the user did not choose and does not recognise | AC-048 — explained at the moment of surprise, not in an eight-row sync table |
| 3 | Two places to add a device, with different consequences | CR-104 |
| 4 | The Structure editor is a four-region matrix tuned for the 60-drop job and hostile to the 2-drop job | AC-048 — it opens in **table mode** with `+ Add drop`; the matrix is a tab |
| 5 | The first export is blocked by a heuristic, then by a legend-placement invariant | CR-022, CR-023 |

**The schedule is the deliverable; the drawing is the receipt; the rack is where the gear lives; the job is the cable.**

---

## 4. Personas

Four people touch the output. They want different things from it and only one of them opens the app.

### 4.1 The residential CI designer — the primary user

Designs a whole-house system: a credenza or closet rack, 80–150 home runs, rooms named the way the homeowner names them. Works in feet, inches and AWG. Does not speak TIA-570-D and does not want to be asked (AC-034/m23). Needs: fast population by typing, a Structure device that handles two drops as gracefully as sixty, dual labels so the field tech and the rack both get the name they use (CR-044), and a PDF that is a billable client deliverable. This is the persona Part 1 implicitly assumes throughout — and that assumption is now explicit: residential CI is the primary market and commercial capability never fronts the UI (DR-002, canon §11.2).

### 4.2 The commercial AV designer — supported, never fronted

Conference rooms, phased retrofits, drawings that may go to a GC or a permit office. Needs the drafting apparatus the residential user must never see: NCS sheet numbering (`sheetNumbering: ncs`, non-default per CR-066), TIA-606 rack labels, plenum and Class 2/3 code rules, `ISSUED FOR CONSTRUCTION`. Commercial capability stays present and stays out of the way. That phrasing is now a ruling (DR-002), not an observation. Layers for phased retrofit are the one thing this persona genuinely needs that v1 does not ship — deferred to v2 with `lifecycleStatus` covering ~80% as a single field (CR-064, AC-038).

### 4.3 The installer receiving the output — the person the product is actually for

Never opens RackMate. Holds paper, in an attic, at 7 pm, possibly wearing gloves. Needs one page: a unique cable ID, both ends as device designator plus physical port label, the cable type, the room, and a box to tick. That is the **Pull Sheet** — portrait, sorted **room then pathway**, with `Pulled ☐ Terminated ☐ Tested ☐ Init ___`, excluding jumpers and power cords by default (AC-025, AC-026). Every constraint this persona imposes wins over every drafting preference: it is why the schedule is sorted for the person holding the cable rather than the person who drew it, and why a watermark — if the product ever ships one — goes on client-facing sheets and never on the pull sheet.

### 4.4 The owner-operator — the person who buys it

Runs a 2–8 person integration shop and is also designer #4.1. Buys tools with a purchase order, resents subscriptions for desktop software that syncs nothing, and prices against AVSnap (free) and Stardraw ($275–$1,050 first year) — **not** against D-Tools' $9,000/yr. Needs the tool to pay for itself on the first job by removing a change order or a callback. Needs project files that are diffable, portable and not hostage to a cloud account. Their evaluation is thirty minutes long and happens before any support conversation, which is why the four starter projects and the type-to-populate interaction are load-bearing commercial features, not conveniences.

---

## 5. The seven core requirements as acceptance criteria

Each is binary and demonstrable. "Works well" is not an exit criterion (canon §9.0).

| # | Requirement | Acceptance criterion | Governing rulings |
|---|---|---|---|
| **R1** | User enters rack height in RU | A rack accepts `heightU` in 1..60, asserted at load. `ruIndex` is 1-based with a bottom origin; `ruNumbering` is per-rack, not project-wide. A 45U stack accumulates **zero** vertical error — a unit test, written before any other code, asserts exact 1/32-in inter-panel clearance against `Len` = int64 nanometres. | CR-038, CR-025, CR-026, CR-001, CR-002 |
| **R2** | GUI device builder with I/O specification | A user creates a working template from **three required fields** — name, RU height, designator prefix — then ports, then done. Every other field is optional with a visible `unknown` state. A 16×16 matrix is authored via the archetype generator; the port grid supports fill-down, TSV paste and multi-row edit. Ports instantiate per device from the template, NetBox-style. | AC-049, CR-114, CR-051 |
| **R3** | Physical connections between devices | Drag from a port to a port creates a `Link`. Illegal connections **spring back** with a reason chip and `[ Connect anyway ]` — they are never silently permitted and never hard-refused (G2). A `Link` carries `List<Service>`, because one Cat5e routinely carries an IR run, a 12 V trigger and RS-232 on separate pairs. A keyboard-only path to create a connection works end to end with screen-reader announcements. | CR-017, CR-010, CR-008, AC-058/D11 |
| **R4** | Colour-coded by cable type | The `T0.01` **Symbol Legend** prints **one row per named cable type** — all ten the brief names — in colour and greyscale side by side. Hue encodes domain; dash, weight, glyph and text tag encode type. Verified under protanopia and deuteranopia simulation, and on a **real greyscale office laser at ANSI B, photocopied once**. Per-family colour override ships in settings. | AC-054, CR-078, canon §6.6 |
| **R5** | Schematic idiom | **Net labels at both pins by default**; on a domain filter, `Alt`-hover or focus, links render as orthogonal routed polylines with tag pills at both ends and junction dots at genuine multi-drop nodes. Pin shapes encode type (the Q-SYS lesson). Layout is Sugiyama phases 0–3 plus a deterministic layer-ordered orthogonal trace, **fully deterministic**: same input ⇒ byte-identical display list. No route geometry is persisted; symbol placement is. | DR-001, RJ-001, RJ-002, CR-013, CR-012 |
| **R6** | Structure device | Structured wiring entering the rack is a `DeviceInstance` with `kind == structure`, rendering as an edge bank of off-page flags. A home run is a `Link` with a `StructureOrigin` and a `PlaceEndpoint` — modelled **once**, not twice. `fieldLabel` (required) and `rackLabel` (optional) are both generated, both editable, and **both print on every cable**. Multiple Structure instances are supported. | CR-107, AC-019, CR-044, CR-113 |
| **R7** | PDF containing both diagram and schedule | One export produces eleven sheet slots — nine on by default, two automatic: `T0.00` cover & drawing index, `T0.01` legend, `T0.02` exceptions & acknowledgements, `T2.01` front elevation and `T2.02` rear elevation (one pair per `Rack`), **N interconnect sheets (`T6.01…`), one per domain partition of the single schematic `Sheet`**, `T6.10` **Pull Sheet**, `T6.11` **Termination Schedule**, `T6.20` Unused Home Runs (auto, iff ≥ 1 exists), `T6.30` Equipment List and Materials, and `T5.01` Plate, Panel & Pinout Details (auto, iff a non-standard pinout exists). Elevations are dimensionally correct against a physical tape measure at true scale. **Nothing blocks the export** — findings print as an appendix. | CR-022, AC-025, AC-055, CR-023, CR-073, DR-005 |

R4 is a recorded requirement deviation with explicit sign-off (AC-050/A4.1): the brief says colour-coded *by cable type*, and hue-per-type across ~50 families is not achievable safely for colour-vision-deficient users or on a greyscale photocopy. The resolution moves type onto dash, weight, glyph and tag, and the legend audit in canon §6.6 proves all ten named types remain distinguishable on both channels.

---

## 6. Non-goals and refused scope traps

Not omissions — rulings (canon §7.6). Each has been argued and closed.

| Refused | Why | Ruling |
|---|---|---|
| CRM, quoting, proposals, procurement, purchase orders, field service | D-Tools' entire surface area, the reason its users say they are "learning a new language", and a different business. `Money`, `cost`, `supplier`, `purchaseOrder` are deleted from the model. The sheet is an **Equipment List**, never a BOM. | AC-055 |
| Visio or AutoCAD as the drawing canvas | The incumbent's core structural weakness: a second expensive licence, and a drawing that can always contradict the database. Own the canvas. | RJ-001 |
| A rule-authoring UI and the JSON predicate AST | ~20 of 70 rules cannot be expressed in a boolean predicate tree. The AST buys a second rule system, a second debugger and a second test suite for rules nobody can author without a UI that was never designed. **The user-authored-rules claim is withdrawn from all documents.** | CR-024, AC-011 |
| Real-SKU manufacturer catalog | Stencil and SKU coverage is *always* incomplete, and maintaining it is a permanent staffed cost. A seeded catalog can only ever cover archetypes, and generic archetypes at full fidelity with cited provenance beat a larger set of guessed ones. | RJ-007, AC-052 |
| Device images, 3D racks, photorealistic front panels | Cosmetic, ~1 MB per template, an image-decode import surface, and already a source of competitor complaints. 2D vector elevations with accurate RU geometry are what get printed. | AC-057 |
| Cable dressing, bend radius, tie-downs, floor plans, thermal simulation | Out of the brief, correctly. `Pathway` groups cables organisationally and does **not** affect tracing — the NetBox precedent. | brief; CR-016, AC-027 |
| Cloud sync, multi-user, accounts, an in-app updater | The model is already cloud-ready (stable UUIDs, `schemaVersion`, tombstones, `sequence`). Nothing more is spent until someone asks. Auto-update is a security surface before there are users. | v2; RJ-014 |
| Multi-document tabs | One window, one document, multiple windows if you want two. | RJ-013 |
| Tagged / accessible PDF (PDF/UA) | The accessibility budget buys the outline tree, the keyboard connection path and the NVDA matrix — all of which help a real user. A tagged schematic helps nobody who could not already read the schedule. | RJ-015 |
| Silent estimated values | A standing prohibition, not a scope item. Unknown is `null`, `null` renders `—`, every rollup reports its unknown count. | G4, AC-039 |

Two refusals from the raw prior-art analysis were themselves **overruled** and are worth naming so they are not re-proposed as cuts. "Do not build orthogonal auto-routing in v1" and "wire on the rack elevation, generate the schematic read-only" both delete a fixed brief requirement, and both are rejected (RJ-001, RJ-002). Their *diagnosis* — that the corpus spends ~70% of its effort on the drawing while calling the schedule the deliverable — is accepted in full, which is why the schematic survives at a fraction of its budgeted cost.

---

## 7. Competitive positioning

| | **RackMate** | **D-Tools SI** | **Visio + stencils** | **draw.io / Lucidchart** | **RackOnline** |
|---|---|---|---|---|---|
| Price | Desktop, anchored to Stardraw ($275–$1,050 yr 1) and free AVSnap, not to D-Tools | **$1,800/user/yr, 5-user min = $9,000/yr floor**; $200/hr services | Licence + stencil packs; commercial libraries draw open contempt on price | Free–low subscription | **Domain does not resolve — appears defunct** |
| Owns its canvas | Yes | **No** — drives Visio or AutoCAD | N/A (is the canvas) | Yes | Unknown |
| Typed ports, enforced at drag time | **Yes** — spring-back with a reason chip and `[ Connect anyway ]` | No pin-level type system | No | No | Unknown |
| Unique device designators | **Yes** — allocated at creation and stored (`MTX-1`, `AMP-12`) | Yes | Manual discipline only | Manual discipline only | Unknown |
| Derived cable schedule | **Yes — the deliverable.** Pull Sheet + Termination Schedule from one derivation | BOMs and proposals; schedule is secondary | No | No | Unknown |
| Structured-wiring / home-run model | **Yes** — `Outlet` + `StructureOrigin`, dual labels | Partial | No | No | Unknown |
| Residential AV signal types (HDMI, IR, RS-232, RG6, TOSLINK, speaker level) | **Yes — 8 domains, ~50 families** | Catalog metadata, not a typed netlist | Shapes only | No | Unknown |
| One model, many views | **Yes** — elevation, schematic, schedule, PDF are four renderings of one graph | Drawing renders the database in a *second app*, and can contradict it | No | No | Unknown |
| Diffable local project file | **Yes** — pretty-printed key-sorted JSON, stable UUIDs, `schemaVersion` | Proprietary / cloud | Binary | Cloud | Unknown |
| Blocks your export on a heuristic | **Never** (G3) | — | — | — | — |

Two competitors outside that table set the real bar. **NetBox** has the reference data model — typed templated components, front/rear pass-through ports that let a trace run straight through a patch panel, and cables carrying type, colour, length and label — but its rack elevations are read-only rendered images and its signal vocabulary is Ethernet, fibre and power. **Q-SYS Designer** has the reference interaction model — pin shape encodes type, only complementary directions connect, and a loose wire is prohibited outright. RackMate takes the data model from the first and the gesture from the second, and applies both to a domain neither serves. Notably, Q-SYS — the most refined tool in this space — ships **no auto-routing at all**; RackMate builds one anyway (CR-013, DR-001), scoped to the `drawn` render mode a domain filter or a hover turns on, and that is a deliberate, costed bet, not an oversight.

The other axis RackMate competes on is the sheet itself. The exported set is a **client deliverable with full drafting furniture** — title block, revision block, revision clouds, `ISSUED FOR CONSTRUCTION` stamp, drawing border, zone references and sheet numbering (DR-005). Sheet furniture is orthogonal to wire idiom: the schematic's reader is technical — GC, electrician, low-voltage sub, technically-literate homeowner — so the sheet is polished fully and the wires stay net-labelled (DR-001).

---

## 8. The four confirmed product decisions

Constraints, not inputs (canon §0.2). Several critique recommendations violate them and are rejected on that ground alone.

**1. Desktop-first; mobile read-only in v1; the architecture must not preclude touch.**
Rationale: the authoring surface is a canvas with a keyboard-driven quick-add, and a squeezed mobile editor would be worse than no mobile editor. Honoured honestly — mobile and tablet are read-only on exactly three surfaces (rack elevation, schedule table, exported PDF) and the app **says so** rather than shipping a degraded editor (AC-056). The door stays open at zero ongoing cost: `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` is built first and **no editor logic anywhere branches on `PointerDeviceKind`** (AC-016/#23). *Rejected alternative:* responsive-everywhere, which pays for touch in every gesture and delivers a bad experience on both.

**2. A device builder PLUS a seeded catalog of generic archetypes.**
Rationale: the Visio-stencil complaint is unambiguous — coverage is always incomplete, commercial libraries are overpriced, everyone ends up rolling their own. The catalog handles the common case and makes the first session fast; the builder handles the long tail, which is exactly where a professional discovers a tool cannot represent their job. Generic archetypes avoid the permanent staffed cost of SKU maintenance. The count is set by the **provenance gate** — every numeric field cited in `assets/catalog/sources.md`, and a template with uncited safety-adjacent fields does not ship — not by a target number (CR-061, AC-052). *Rejected alternative:* shipping the catalog at lower fidelity to halve authoring effort (RJ-007) — that trades the honesty guarantee for weeks, and honesty is the wedge.

**3. Local single-file `.rmpj` projects (JSON), cloud-ready.**
Rationale: integrators own their files, and a diffable text project is a differentiator no competitor offers. Plain, pretty-printed, key-sorted UTF-8 JSON with a `document` wrapper; UUIDv7 identity; `schemaVersion` + `minReaderVersion`; tombstones, `EntityMeta` and `FracIndex` ordering all ship in v1 even where their UI does not, because they are the retrofits that cost 10× later (G5, CR-095, CR-027). `DocumentCodec` sniffs `PK\x03\x04` from commit one, so a v2 zip container is a non-event (CR-091). *Rejected alternative:* zip-from-the-start, unnecessary once device images were cut (AC-057).

**4. All seven core requirements are represented in v1.**
Fixed by the brief and not so much a decision as the definition of done. It is the first of the four scope filters (canon §7.0) and it is why the schematic canvas, the device builder, the Structure device and the both-in-one-PDF export all survive the cut regardless of cost.

---

## 9. Measures of success

Ordered from cheapest to hardest. The last one is deliberately a judgement, not a metric.

| # | Measure | Threshold |
|---|---|---|
| 1 | **Population speed** | 20 devices into a 42U rack in **under four minutes, keyboard only**. Undo restores every operation in that sequence. (M1 exit) |
| 2 | **Dimensional truth** | Exported elevations measure correct against a **physical tape measure** at true scale; the equipment list matches rack contents exactly. (M1 exit) |
| 3 | **Wiring throughput** | 60 connections created **without touching a menu**; the schedule tab shows 60 correctly sorted rows with both labels on both ends. (M2 exit) |
| 4 | **Determinism** | Same input ⇒ **byte-identical display list**; a 300-connection fixture lays out within one frame at commit. (M2 exit) |
| 5 | **Print legibility** | All ten requirement-4 cable types remain identifiable on a **real greyscale office laser at ANSI B, photocopied once**, and under protanopia/deuteranopia simulation. |
| 6 | **Rule trustworthiness** | Every shipped rule has a known-bad fixture that produces exactly that finding and a known-good near-miss that does not. **No rule ships without its pair.** This is also the gate that holds the v1 catalogue at 27 rules. (AC-051, AC-040) |
| 7 | **Catalog miss rate** | Instrumented from M1: how often a user hits a device the catalog does not have. §10.4 is answered — the device builder ships in v1 (DR-003) — so this is no longer a scope trigger. It is catalog-coverage evidence feeding canon §10.9 and the sizing of the catalog lever. |
| 8 | **Beta gate** | **Three integrators have each produced a sheet set they were willing to send to a client or a job site, and none of the three needed to leave the app to fix something.** (M9 exit) |

Cost, stated honestly rather than comfortably: **42–65 weeks of implementation, 11–17 months to a shipped v1** for one experienced engineer. That is better than the 16–22 months the unreduced design was priced at, and it is not the 5–6 months a proposed cut table promised — because that table cut a brief requirement (RJ-008). Two explicit levers exist if the number is unacceptable, and they are to be pulled deliberately rather than by drift; see [Roadmap](09-roadmap.md).

---

## 10. Where to go next

| Document | What it holds |
|---|---|
| [Domain](01-domain.md) | The trade, the vocabulary, the signal and cable registry |
| [Data model](02-data-model.md) | `Link` → `Service` → `Conductor`, `Net`, `Placement`, templates, the file format |
| [Architecture](03-architecture.md) | The five packages, the command stack, the display-list IR, the isolate |
| [Rack editor](04-rack-editor.md) | Elevations, quick-add, the Staging Bin, compaction |
| [Schematic editor](05-schematic-editor.md) | Symbols, drag-to-connect, layout and routing, net labels and the domain filter |
| [Device builder](06-device-builder.md) | Three required fields, the port grid, the three doors |
| [Structure device](07-structure-device.md) | Outlets, home runs, dual labels, the location tree |
| [PDF export](08-pdf-export.md) | The sheet set, the schedule presets, the export contract |
| [Roadmap](09-roadmap.md) | v1 / v1.1 / v1.2 / v2, the ten milestones, the honest total |
| [Canonical decisions](canonical-decisions.md) | **Normative.** 120 `CR-nnn`, 59 `AC-nnn`, 17 `RJ-nnn`, canonical naming, the model, the registry, the scope ruling, the milestone plan, and the binding user decisions `DR-001`–`DR-005` |
| [Decisions (ADR log)](10-decisions.md) | The sixteen ADRs and the open questions, summarising the record above |
| [Testing and quality](11-testing-and-quality.md) | The DRC fixture corpus, goldens, the print test matrix |
| [Seed devices](catalog/seed-devices.md) | The archetype catalog and its provenance |

Raw working papers — non-normative rationale, superseded wherever they disagree with the decision record — are in [`docs/research/`](research/).


