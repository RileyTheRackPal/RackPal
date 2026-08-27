# RackPal: Device Builder, Seeded Catalog & Structure Device
## Design Specification v1

---

## 0. Design Premises

Three findings from the research drive every decision below:

1. **Templates instantiate ports** (NetBox precedent). The device *type* owns the port list; every placed instance gets those ports free. This is what makes a 58-device seeded catalog tractable and what makes the builder worth using twice.
2. **Reference designators are first-class.** XTEN-AV's users are on record complaining they cannot uniquely name devices. `refdesPrefix` is a required field on every template, not an afterthought.
3. **Connector, signal family, and direction are three orthogonal fields, never one enum.** RJ45 is a connector; Ethernet, HDBaseT, Dante, and Cresnet are signal families that share it. Collapsing them makes the highest-value validation in the product (HDBaseT-into-a-switch) impossible.

A fourth, specific to this document: **the I/O editor is a spreadsheet, not a form.** Integrators live in Excel. Every ergonomic they already know (fill-down, multi-select, paste TSV, Tab/Enter navigation) must work. Any interaction that costs one click per port is a design failure.

---

## 1. Device Builder: Structure & Metadata

### 1.1 Shell layout

Full-window editor (not a modal, a modal cannot host a 48-row grid). Three panes, persistent:

- **Left rail (200 px):** section nav + bank tree. The bank tree is the primary navigation once you're in the I/O section.
- **Center (flex):** the active section's editor.
- **Right dock (340 px, collapsible):** live preview stack + selection inspector. Swaps to a *batch inspector* when >1 grid row is selected.

Sections in the left rail, in order:

| # | Section | Required to save? |
|---|---|---|
| 1 | Identity & Classification | Yes (name, category, refdes prefix) |
| 2 | Physical & Mounting | Yes (RU / occupancy, mount method) |
| 3 | Power & Thermal | No (warns if a powered category has no inlet) |
| 4 | **Ports (I/O)** | No (blank panels legitimately have zero) |
| 5 | Panel Layout | No: progressive disclosure, see §2.6 |
| 6 | Appearance | No (colour defaults from category) |
| 7 | Notes, Docs & Publish | No |

A template can be saved incomplete at any point; it enters the library flagged **Draft** and is excluded from search unless "Include drafts" is on.

### 1.2 Section 1: Identity & Classification

| Field | Type | Notes |
|---|---|---|
| `name` | text, required | "HDMI Matrix 8×8" |
| `manufacturer` | text | Defaults to "Generic". Seeded catalog uses "Generic" throughout, the confirmed decision to avoid SKU libraries. |
| `model` | text | |
| `category` | enum, required | Video Distribution · Audio · Network · Control · Sources · RF/Coax · Power · Passive & Mechanical · Structure (reserved) |
| `subcategory` | enum, filtered by category | Matrix, Splitter, Extender, Amplifier, Switch, Patch Panel… |
| `refdesPrefix` | text, required, 2–4 chars | `MTX`, `AMP`, `SW`, `PP`, `UPS`, `BLK`. Auto-suggested from subcategory. Instances become `MTX-1`, `MTX-2`. |
| `tags` | chip input, free | `hdbaset`, `4k60`, `poe`, `commercial`, `residential`, `70v` |
| `description` | multiline | Shown in library card and PDF appendix. |
| `templateId` | UUID, read-only | Generated on create; **stable across all versions**. |
| `version` | `major.minor.patch`, read-only | See §4.2. |

### 1.3 Section 2: Physical & Mounting

Height is **never a float**. Store integer U; derive drawn height as `44.45n − 0.79 mm` for dimensioned output only.

| Field | Type | Notes |
|---|---|---|
| `occupancy.frontU` | int ≥ 0 | 0 for zero-U and rear-only items |
| `occupancy.rearU` | int ≥ 0 | A 2U patch panel is `{front:2, rear:2}`; a rear lacing bar is `{front:0, rear:1}`; a 0U PDU is `{0,0}` |
| `occupancy.side` | enum | `front` · `rear` · `both` · `zeroU_vertical` |
| `mountMethod` | enum, required | `rackEars` · `shelf` · `zeroU` · `sideMount` · `rearRail` · `furniture` · `hosted` · `notInRack` |
| `widthClass` | enum | `full` · `half` · `third` · `custom` (+ `customWidthMm`). **Never** "0.5 rack width", half-rack is genuinely unstandardized (9.5 / 10 / 10.4 / 10.5 in all ship). |
| `depthMm` | number | Chassis depth |
| `depthWithConnectorsMm` | number | Auto-suggests `depthMm + 75 mm`; used against rack usable depth |
| `weightKg` / `weightLb` | number, dual-unit | Unit follows the app-level preference; both stored |
| `isContainer` | bool | Shelves and drawers. Reveals: |
| ↳ `shelfCapacityKg` | number | 25 / 35 / 50 lb are the real numbers: low enough to matter |
| ↳ `shelfUsableDepthMm` | number | 10 in shelves are shallow; many STBs exceed them |
| `hostedHeightU` | int, only when `mountMethod: shelf/hosted` | Advisory height so the shelf picker can warn ("this 4U-tall AVR needs a 4U clear space above its 1U shelf") |
| `requiresClearanceAboveU` | int | Differentiating validation: few tools model it |
| `requiresClearanceBelowU` | int | |
| `isPassthrough` | bool | Patch panels. Reveals front↔rear port pairing in the I/O editor (§2.5) |

### 1.4 Section 3: Power & Thermal

| Field | Notes |
|---|---|
| `power.nameplateWatts` | Used for breaker/OCPD math |
| `power.typicalWatts` | Used for heat math. Defaults to 50% of nameplate with a "typical draw is 30–70% of rated" hint |
| `power.standbyWatts` | |
| `power.isContinuousLoad` | Default **true** for anything in an A/V rack (3 h+ runtime). Drives the NEC 80% derate: 12 A on a 15 A circuit, 16 A on a 20 A circuit |
| `power.voltage`, `power.phase` | |
| `heat.btuPerHour` | **Derived: `typicalWatts × 3.412`.** Read-only with an override toggle |
| `outletsProvided` | Read-only: counted from ports with `power.role: outlet` |
| `outletsConsumed` | Read-only: counted from `power.role: inlet`. **External power bricks count.** A 4×4 matrix with a 12 V barrel jack still eats a PDU outlet; this is a real and frequently-missed planning error |

A yellow banner appears if `category` is not `Passive & Mechanical` and the template has no inlet port: *"No power inlet defined. Add one, or mark this device as passive."*

### 1.5 Section 6: Appearance

Deliberately minimal. Research says photorealistic panels and per-device photography are a scope trap and already generate complaints elsewhere.

- `faceColor`, hex, defaults from category (video = deep blue-grey, audio = warm charcoal, network = slate, power = near-black, passive = light grey)
- `accentColor`, used for the front-panel LED strip / branding bar in the elevation
- `glyph`, pick from a built-in icon set (matrix, amp, switch, disc, battery, fan, blank…) rendered on the elevation strip
- `frontImage` / `rearImage`, optional PNG/SVG, **capped at 512 KB each**, with an explicit warning that images inflate the template file and are not needed for correct output

### 1.6 Section 7: Notes, Docs & Publish

Free notes, an optional documentation URL, an optional "installer notes" block that flows into the PDF appendix for every placed instance, and the **Publish** action (Draft → Published, which assigns version `1.0.0`).

---

## 2. The I/O Editor

This is the product. Everything here is optimized so that an 8×8 matrix, 16 signal ports plus a dozen ancillaries, takes under 30 seconds.

### 2.1 Layout

```
┌─ Quick Add ────────────────────────────────────────────────────────────────┐
│ ⌨ 8 hdmi in "HDMI IN {n}" @HDMI Inputs                          [ Add ▸ ] │
│ or:  Qty[8] Connector[HDMI-A ▾] Signal[hdmi20 ▾] Dir[In ▾]                │
│      Side[Rear ▾] Label[HDMI IN {n}] Bank[+ HDMI Inputs ▾]                │
└────────────────────────────────────────────────────────────────────────────┘
```

The Quick Add strip is **docked, always visible, never a modal**, and focus returns to it after every add so consecutive banks are pure typing.

Two input modes on one control:
- **Command mode (default, focus lands here on entering the section).** A single text field with a permissive mini-DSL and inline autocomplete.
- **Field mode.** The same parameters as discrete controls, for discoverability. The two are bound bidirectionally, typing in command mode updates the fields live, so the DSL teaches itself.

### 2.2 The Quick Add DSL

Grammar (all parts except qty and connector are optional and order-insensitive):

```
<qty> <connector|alias> [<signal>] [in|out|bi|pass] [front|rear|both]
      ["<label pattern>"] [@<bank>] [poe:at] [z:75] [dte] [tap:10w]
```

**Aliases resolve aggressively.** `hdmi` → connector `HDMI-A`, signal `hdmi20`, direction defaults to `in`. `rj45` → `RJ45` + `ethernet`. `hdbt` → `RJ45` + `hdbaset` (a *different* signal on the same connector; this is the whole point). `xlr` → `XLR3` + `line-bal`, gender inferred from direction (male = out, female = in). `euro3` → 3-pole Euroblock. `spdif` → `RCA` + `spdif-coax` + `impedance 75`. `toslink` → `JIS-F05` + `spdif-optical`. `bp` → binding post + `speaker-lowz`.

Examples that each produce a complete bank in one keystroke sequence:

| Typed | Result |
|---|---|
| `8 hdmi in` | 8 × HDMI-A / hdmi20 / sink / rear, labelled `HDMI IN 1…8`, bank auto-named "HDMI Inputs" |
| `16 euro2 out "ZONE {n@2} {L,R}"` | ZONE 1 L, ZONE 1 R, ZONE 2 L … ZONE 8 R: an entire 16-channel amp output bank |
| `24 rj45 poe:at @Ports "{n:2}"` | 01…24, PSE, 802.3at |
| `24 rj45 pass both "{n:2}"` | 48 ports: 24 front + 24 rear, auto-paired as a passthrough patch panel |
| `8 f out "SAT OUT {n}" dcpass:1` | 8 F-type outputs, port 1 flagged DC-passing |
| `4 xlr5 out dmx "DMX {A}"` | DMX A, B, C, D |
| `1 c14 in` | AC inlet |

### 2.3 Label pattern language

| Token | Expands to | Example |
|---|---|---|
| `{n}` | sequential integer from `start`, step `step` | 1, 2, 3 |
| `{n:2}` | zero-padded | 01, 02, 03 |
| `{n@k}` | increments every *k* rows | with k=2: 1,1,2,2,3,3 |
| `{A}` | alpha sequence | A, B, C … AA |
| `{L,R}` | cycling literal set | L, R, L, R |
| `{a,b,c}` | any cycling set | Y, Pb, Pr for component video |
| `{rev}` | descending | 8, 7, 6 |
| Literal text | passes through | `HDBT OUT {n}` |

`start` and `step` are exposed as small numeric fields beside the pattern; defaults 1 / 1.

**Auto bank naming.** If `@bank` is omitted, the bank name is derived: `"{Signal display name} {Direction plural}"` → "HDMI Inputs", "Speaker Outputs", "Network Ports". Colliding names get a numeric suffix. Renaming a bank never touches port labels.

### 2.4 Archetype generators

Above Quick Add, three buttons that emit whole port topologies:

- **Matrix I/O…**: asks *N inputs × M outputs*, connector for each side, and offers checkboxes for the usual companions: mirrored outputs, per-output audio de-embed, per-output IR, control (LAN + RS-232), AC inlet. Emits 4–7 banks in one action. This alone builds V01–V03 of the seeded catalog.
- **Switch ports…**: *N access ports* + *M uplinks*, PoE standard and per-port class, SFP form factor, management port, redundant PSU.
- **Paste from spreadsheet**: paste TSV/CSV; a column-mapping sheet appears (same engine as the Structure CSV import, §6.4). Integrators already have port lists in Excel.

### 2.5 The port grid

A virtualized data grid. Rows grouped by bank with sticky collapsible group headers.

**Core columns (always visible):**

| Col | Editor | Notes |
|---|---|---|
| ⠿ | drag handle | Reorder within and across banks |
| ☐ | checkbox | Multi-select |
| `Label` | text | The silkscreen text |
| `Designator` | text | `J14`. Auto-assigned sequentially per ASME Y14.44; **auto until manually edited**, then pinned (shown in italic vs roman) |
| `Connector` | combo | Grouped picker with footprint preview |
| `Signal` | combo, filtered by connector | Only families legal on that connector, plus "Other…" |
| `Dir` | segmented | In / Out / Bi / Bus / Passive |
| `Side` | segmented | Front / Rear |
| `Group` | combo + role | For component video (Y/Pb/Pr), stereo pairs (L/R), RGBHV, speaker ± |
| `Notes` | text | |

**Column packs**, toggled from a `⚙ Columns` menu, and **auto-revealed** when the current bank's dominant signal family calls for them:

| Pack | Columns |
|---|---|
| Electrical | Impedance (Ω), Level, Phantom, Polarity, Nominal V |
| Network | PoE role, PoE std, Type, Class, Watts, Link speed, Port role, VLANs, SFP form factor, Fiber mode, λ |
| Serial | DTE/DCE, Baud, Data, Parity, Stop, Flow |
| Bus | Segment, Address, Universe, Unit loads, Terminator, Tap W |
| Power | Role, Receptacle, Volts, Max A, Outlet mode, Seq step, Seq delay, Backing, Circuit |
| Layout | X (mm), Y (mm), Panel, Rotation |
| Passthrough | Paired port |
| Advanced | Max connections, Topology, Gender, Pinout variant, Return channel |

Column pack visibility is remembered per *category*, so opening any switch template shows the Network pack.

**Editing operations and their bindings:**

| Op | Binding | Behaviour |
|---|---|---|
| Edit cell | click, or type over selection | Enter commits + moves down; Tab commits + moves right; Esc reverts |
| Fill down | `Ctrl+D` | Copies top cell of selection to all below |
| Fill series | `Ctrl+Shift+D` | Re-applies the label pattern across the selection with a fresh start value |
| Multi-row edit | select N rows, edit any cell | Applies to every selected row. Right dock switches to the batch inspector; mixed values render as `—` and are left untouched unless set |
| Duplicate | `Ctrl+J` | Clones selection below with labels auto-incremented past the highest existing index |
| Delete | `Del` | Undoable; warns if the port is referenced by a passthrough pair |
| Reorder | drag, or `Alt+↑/↓` | Order is **semantic**: it drives symbol pin order and panel auto-layout |
| Renumber… | `Ctrl+R` | Re-applies a label pattern to the selection **in current display order** |
| Find & replace | `Ctrl+H` | Scoped to labels, designators, or notes; regex opt-in |
| Change type… | `Ctrl+T` | Bulk connector/signal change on the selection, with an impact preview |
| Move to bank… | `Ctrl+M` | |
| Copy / paste | `Ctrl+C/V` | TSV round-trips to Excel and back |
| Sort | click header | **View-only sort by default**, indicated by a badge. `Commit sort order` is a separate explicit action, because sorting is destructive to symbol pin order |
| Mirror bank | bank context menu | Duplicates a bank with direction flipped and label prefix swapped IN↔OUT. Builds the output side of a matrix in one click |

**Passthrough pairing.** When `isPassthrough` is on, the grid gains a `Paired port` column and a **Pair front↔rear by order** action. Paired ports share a net, so a trace resolves `Living Room jack → PP-1 F12 → PP-1 R12 → SW-1 P04` as a single logical path rather than two hops.

**Live validation** runs per row, surfacing a severity dot in the gutter:
- error: duplicate designator in-template; passthrough port with no pair; power outlet on a device with no inlet
- warn: RCA carrying `spdif-coax` without impedance 75; XLR carrying `aes3` without impedance 110; IR 3.5 mm port with no `pinoutVariant` set; a bank whose connectors physically cannot fit the panel width at this U height (uses the connector footprint table)

**Footer readout**: always visible, one line:
`58 ports · 3 banks · 16 HDMI · 24 RJ45 (PoE+ ×24, 370 W budget) · 8 F · 1 C14 · Rear 56 / Front 2 · Panel fill R: 71%`

### 2.6 Panel layout: and whether it ships in v1

**Recommendation: ship the auto-layout in v1; ship the manual override in v1, gated behind a toggle; never make either a prerequisite for anything.**

The argument in three parts:

**Against manual x/y authoring as a required step.** It is precisely the "click 16 times" failure the brief is trying to eliminate, multiplied, a 48-port patch panel would need 48 placements. Ports connect by *identity*, not position; the netlist, the cable schedule, and the PDF are all complete without a single coordinate. Making layout required would gate the product's actual output behind cosmetic work. This also matches the research directive not to build photorealistic panels.

**For auto-layout being in v1 regardless.** The rear elevation is where nearly all connections live, so the rear view is the *default* wiring view; it has to look like something. And the geometry is free: every connector type has a real footprint, so a layout engine can place ports without any user input:

| Connector | Footprint (mm) | Pitch |
|---|---|---|
| HDMI-A | 15.1 × 5.6 | 19 |
| RJ45 | 15.0 × 13.0 | 17 |
| RCA | ⌀ 8.4 | 11 |
| XLR3 | ⌀ 24.0 | 27 |
| F-type | ⌀ 9.5 | 13 |
| BNC | ⌀ 10.0 | 14 |
| DE-9 | 31.0 × 13.0 | 34 |
| 3.5 mm TRS | ⌀ 7.0 | 10 |
| C14 inlet | 27.0 × 20.0 | 30 |
| NEMA 5-15R | 34.0 × 27.0 | 38 |
| Euroblock 3-pole (3.5 mm pitch) | 12.5 × 10.0 | 15 |
| Binding post pair | ⌀ 12 × 2 | 20 |
| LC duplex | 12.5 × 9.0 | 14 |

Algorithm: banks in tree order; within a bank, ports in grid order; flow left→right at the pitch; wrap to a new row when the 482.6 mm panel width is exhausted; vertical rows distributed within `44.45n − 0.79 mm`; power inlets pinned to the far right, network/control to the far left, signal banks centered. This produces a recognizably correct rear panel for every one of the 58 seeded templates with zero authoring.

**For the manual override existing but being hidden.** Some devices genuinely have layouts worth capturing (a matrix where outputs are stacked in two rows, a UPS with outlets in two banks). The override is a toggle, `☐ Customize panel layout`, that reveals a canvas **pre-populated from the auto-layout**, so the interaction is nudging, not placing. Snap-to-grid at 1 mm, arrow-key nudge, align/distribute, and a "Reset to auto" button. Cheap to build because the hard part (footprints and initial placement) already exists.

**Non-negotiable constraint:** a template with no layout data is not "incomplete." The Panel Layout section shows a green "Auto" badge and is skippable forever.

### 2.7 Live preview (right dock)

Three stacked previews, each collapsible, all updating on every keystroke:

1. **Rack elevation strip**: 19 in wide at true aspect, correct `44.45n − 0.79` height, front/rear toggle, faceplate colour + glyph + name + `refdesPrefix-1` placeholder. This is what actually gets printed.
2. **Schematic symbol**: auto-generated in the KiCad/Q-SYS idiom: a rectangle with refdes top-left, name centered, model in small type below; pin stubs grouped by bank. Default sides: inputs left, outputs right, control top, power bottom, each bank overridable. Pin **shape** encodes connector class (circle = analog audio, square = control, triangle = speaker, HDMI glyph, USB glyph, hexagon = RF); pin **colour** encodes domain from the Okabe-Ito mapping (digital video `#0072B2`, analog video/RF `#56B4E9`, analog audio `#E69F00`, digital audio `#D55E00`, network `#009E73`, control `#CC79A7`, power `#000000`). Banks over 8 ports render **collapsed as a bus stub with a count badge** by default, expandable; this is what keeps a 48-port switch symbol legible.
3. **Rear panel render**: the auto-layout output, drawn to scale, with a panel-fill percentage.

---

## 3. Template File Format

### 3.1 Extensions

| Ext | Contents | Format |
|---|---|---|
| `.rmdev` | One device template | **Plain JSON, UTF-8, LF, 2-space indent, keys sorted.** Human-readable and git-diffable. Images embedded as `data:` URIs, 512 KB cap each, with a save-time warning |
| `.rmlib` | A library pack (many templates + metadata) | Zip: `library.json` manifest + `templates/*.rmdev` + `assets/` |
| `.rackpal` | A project | Zip: `project.json` + embedded template snapshots + `assets/` |

Plain JSON for the single-template case is deliberate: it is the unit people email each other and paste into forum posts, and diffability is a stated differentiator no competitor offers.

### 3.2 `.rmdev` shape (abridged)

```json
{
  "$schema": "https://rackpal.app/schema/device/1.json",
  "schemaVersion": 1,
  "kind": "device-template",
  "templateId": "0f3a...-uuid",
  "version": { "major": 1, "minor": 2, "patch": 0 },
  "contentHash": "sha256:...",
  "derivedFrom": { "templateId": "…", "version": "1.0.0" },
  "createdAt": "2026-07-18T10:00:00Z",
  "modifiedAt": "2026-07-18T10:00:00Z",
  "author": { "name": "", "org": "" },
  "signature": null,

  "identity": {
    "name": "HDMI/HDBaseT Matrix 8x8",
    "manufacturer": "Generic",
    "model": "MTX-8x8-HDBT",
    "category": "video-distribution",
    "subcategory": "matrix",
    "refdesPrefix": "MTX",
    "tags": ["hdbaset", "4k60", "residential"],
    "description": "..."
  },
  "physical": {
    "occupancy": { "frontU": 3, "rearU": 3, "side": "both" },
    "mountMethod": "rackEars",
    "widthClass": "full",
    "depthMm": 330, "depthWithConnectorsMm": 405,
    "weightKg": 7.3,
    "requiresClearanceAboveU": 0, "requiresClearanceBelowU": 0,
    "isContainer": false, "isPassthrough": false
  },
  "power":  { "nameplateWatts": 90, "typicalWatts": 55, "standbyWatts": 8,
              "voltage": 120, "phase": 1, "isContinuousLoad": true },
  "thermal":{ "btuPerHour": null, "btuOverride": false },

  "banks": [
    { "bankId": "b-uuid", "name": "HDMI Inputs", "abbr": "IN",
      "symbolSide": "left", "collapseInSymbol": true, "order": 0 }
  ],
  "ports": [
    { "portId": "p-uuid", "bankId": "b-uuid", "order": 0,
      "label": "HDMI IN 1", "designator": "J1", "designatorAuto": true,
      "connector": "HDMI-A", "signalFamily": "hdmi20",
      "carriedProtocols": ["hdmi", "hdcp2.2", "cec"],
      "direction": "sink", "side": "rear", "gender": "jack",
      "topology": "p2p", "maxConnections": 1,
      "layout": { "xMm": 24.0, "yMm": 12.0, "rotation": 0, "auto": true }
    }
  ],
  "layout": { "mode": "auto", "rearPanelCustomized": false },
  "appearance": { "faceColor": "#2B3440", "accentColor": "#0072B2",
                  "glyph": "matrix", "frontImage": null, "rearImage": null }
}
```

`portId` UUIDs are **generated once and preserved across every version of the template.** This is the single most important field in the file: it is what makes template updating non-destructive (§4).

---

## 4. Template Lifecycle

### 4.1 Library, search, favourites

- **Storage:** app library dir (seeded catalog, read-only-by-default) + user library dir (writable) + per-project embedded snapshots. A `.rmlib` can be mounted as an additional read-only source (this is how a firm shares a house style, and how a manufacturer could ship a pack later without RackPal maintaining it).
- **Browser:** grid or list, with the rack elevation strip as the card thumbnail. Left sidebar: category tree, then filter chips, RU height, mount method, "has HDMI", "has PoE", "is passthrough", "container", "used in this project", "drafts".
- **Search:** fuzzy over name, manufacturer, model, tags, description, **and port signal families**. Typing `hdbaset` surfaces every template with an HDBaseT port even if the word isn't in the name. Typing `8x8` matches `MTX-8x8-HDBT`.
- **Favourites:** star toggle; favourites pin to the top of the browser and to a dedicated palette in the rack editor.
- **Recently used** and **Used in this project** are always the first two smart folders, in practice they satisfy 80% of lookups.

### 4.2 Versioning

Templates are **immutable versioned records.** Editing a published template does not mutate it; it produces a new version. `templateId` is stable; `version` increments; every version remains resolvable from the library.

Version bump is **computed from the diff, not chosen by the user** (the user may bump higher, never lower):

| Change class | Bump | Examples |
|---|---|---|
| **Safe** | patch | Rename, description, tags, colour, glyph, weight, depth, wattage, notes, panel layout coordinates, port **label** changes, port **reordering** |
| **Additive** | minor | New port, new bank, new column data on existing ports (PoE class, impedance), new clearance requirement |
| **Breaking** | major | Port **deleted**; port `direction` reversed; port `connector` or `signalFamily` changed to something incompatible; `isPassthrough` toggled; occupancy `frontU` changed; passthrough pairing altered |

A **Version diff view** opens before saving: two-column, colour-coded, grouped by change class, with a plain-English header, *"3 safe changes, 1 additive, 0 breaking → 1.2.0 → 1.3.0. Safe to auto-apply to all 4 projects using this template."*

Version history is kept in the library as a chain of `.rmdev` files under the templateId; "Revert to 1.1.0" creates `1.4.0` with 1.1.0's content rather than rewriting history.

### 4.3 Duplicate, fork, import, export

- **Duplicate**: new `templateId`, `version 1.0.0`, name + " copy", `derivedFrom` recorded. This is the intended path for building on the seeded catalog and is offered directly from every catalog card ("Duplicate & edit").
- **Fork from an instance**: from a placed device: *"Save this instance as a new template."* Captures the instance's overrides into a fresh template. This is the most common real workflow, because the seeded catalog is archetypes and the real device is never quite the archetype.
- **Export**: `.rmdev`, or multi-select → `.rmlib`. Templates are **inert data, no executable content**; the import dialog says so explicitly, which is what makes file-based sharing safe enough to encourage.
- **Import**: collision handling on `templateId`: if the incoming ID exists at a *lower* version, offer Update; at the *same* version with a different `contentHash`, offer "Import as copy (new ID)"; at a *higher* version, offer Update with the standard diff view.

---

## 5. Editing a Template That Is Already Placed

This is where competing tools lose users, so the model is explicit.

### 5.1 The instance model

```
PlacedDevice {
  instanceId: UUID
  refdes: "MTX-1"                    // unique project-wide, enforced
  templateRef: { templateId, version } | null   // null = fully detached one-off
  snapshot: <full resolved template>            // project opens without the library
  overrides: { "identity.name": "Main Matrix",
               "ports.<portId>.label": "APPLE TV",
               "physical.weightKg": 8.1 }       // sparse path→value map
  position: { rackId, ruIndex, side, shelfHostId? }
}
```

Two consequences worth stating: a `.rackpal` file is **self-contained and shareable**: the recipient does not need your library. And an override is a *diff against the template*, so template updates and user customizations compose rather than collide.

### 5.2 Three verbs, never ambiguous

Right-clicking a placed device offers exactly three edit paths, worded to be unmistakable:

| Verb | Effect | Scope badge shown while editing |
|---|---|---|
| **Edit this device only** | Writes to `overrides`. Template untouched. Device gets a small ✎ badge in the elevation and a "(modified)" suffix in the BOM | Amber: *"Editing MTX-1 only. 3 other devices use this template and will not change."* |
| **Edit the template** | Opens the device builder on the template. Produces a new version. Existing instances are **not** auto-updated | Blue: *"Editing template 'HDMI Matrix 8×8'. Used by 4 devices across 2 projects."* |
| **Detach into a new template** | Forks: new `templateId`, seeded from snapshot + overrides, this instance rebinds to the fork, overrides cleared | Green: *"MTX-1 will use a new independent template."* |

Plus a fourth, on the template side: **Detach instance** (`templateRef → null`), for a genuine one-off that should never receive updates.

### 5.3 Propagation

**Nothing auto-updates. Ever.** Updates are opt-in, reviewed, and per-instance-reversible.

Trigger points: on project open (a non-modal toast, *"3 devices have template updates available"*), from the device inspector, or from **Project → Template Updates…**.

**The Update Manager:**

```
┌ Template Updates ─────────────────────────────────────────────────────────┐
│                                                                            │
│  ▾ SAFE & ADDITIVE (auto-applicable)                    [ Apply all (5) ]  │
│    ☑ MTX-1   HDMI Matrix 8x8      1.1.0 → 1.3.0   3 labels, +1 IR out     │
│    ☑ MTX-2   HDMI Matrix 8x8      1.1.0 → 1.3.0   (same)                  │
│    ☑ SW-1    PoE Switch 24-port   2.0.1 → 2.0.4   weight, wattage         │
│    ☑ AMP-1   16-ch Amplifier      1.0.0 → 1.1.0   +2 sub outs             │
│    ☑ PDU-1   Rack PDU 1U          1.2.0 → 1.2.1   description             │
│                                                                            │
│  ▾ BREAKING (review required)                                              │
│    ⚠ PP-2    Patch Panel 24       1.4.0 → 2.0.0                           │
│        • Rear ports changed RJ45 → punchdown  (24 ports)                  │
│        • Port "R24" deleted                                               │
│        3 cables affected:                                                  │
│          W014  STR-1 / LR-DATA-2 → PP-2 R12   [ Remap ▾ ] [ Keep ] [ Del ]│
│          W031  PP-2 R24 → SW-1 P22            [ Remap ▾ ] [ Keep ] [ Del ]│
│          W044  STR-1 / KIT-DATA-1 → PP-2 R07  [ Remap ▾ ] [ Keep ] [ Del ]│
│        [ Skip this device ]  [ Apply with choices above ]                  │
│                                                                            │
│  ▾ CONFLICTS WITH LOCAL EDITS (2)                                          │
│    ⚑ MTX-1   You renamed port J3 "APPLE TV"; template renamed it          │
│              "HDMI IN 3".   ( • Keep mine   ○ Take template's )           │
└────────────────────────────────────────────────────────────────────────────┘
```

Rules that make this work:

1. **`portId` is the join key**, not label or index. A port can be renamed, reordered, moved between banks, or retyped and still resolve, cables survive.
2. **Only deletion and incompatible retyping break a cable.** Both are surfaced with the exact affected cables, and **nothing is ever silently dropped.** Remap offers a dropdown of surviving ports on the same device filtered to compatible ones, ranked by similarity (same bank, same connector, nearest order index).
3. **Overrides survive updates by default.** If the template changes a field the user has overridden, that specific field appears in the Conflicts group with "Keep mine" preselected.
4. **The whole apply is one undo step**, and a pre-update snapshot of `project.json` is written to the project's `.history/` folder.

### 5.4 The seeded catalog and updates

Seeded templates ship read-only. Editing one silently performs **Duplicate → edit the copy**, with a one-line notice: *"Catalog templates are read-only. Editing your copy 'HDMI Matrix 8×8 (custom)'."* This keeps app-update semantics simple, RackPal can ship catalog v2 without ever clobbering user work, and it makes the correct workflow (fork the archetype) the default one.

---

## 6. The Structure Device

### 6.1 Why it needs a different editor

A rack device is a *thing with ports*. The Structure device is *a list of home runs organized by room*. Its natural entry axis is **room × media type × quantity**, not port-by-port. Forcing it through the device builder would be a category error; you would be adding 62 ports one bank at a time when what the integrator actually has in hand is a pull list.

The Structure device is: zero RU, zero weight, no rack position, `mountMethod: notInRack`, variable user-defined port list, rendered at the drawing boundary as a bank of off-page connector flags, the schematic idiom for signals entering from elsewhere.

### 6.2 Editor layout

Four regions:

- **Left: Location tree.** `Site → Building → Floor → Room → Outlet/plate`. Drag-reorderable, inline-renamable. **This tree is the project's canonical location vocabulary**: the same one the rack editor and the PDF use. Renaming "Study" to "Office" here repropagates to every label, schedule row, and diagram callout. This directly answers the documented failure where the plan says "Study", the homeowner says "Office", and the label says "Room 3". Each room carries an editable `abbr` (Living Room → `LR`), auto-derived on creation.
- **Top: dual-mode bulk entry.** Matrix mode or command mode (§6.3).
- **Center: the drop table** (§6.5).
- **Right: inspector / batch inspector**, identical ergonomics to the device builder.

### 6.3 Bulk entry: two modes on one control

**Matrix mode (the default, and the fast one.)** Rooms down the left, media types across the top, integer spinners at the intersections. Changing a cell from 0 to 2 instantly materializes two drops with auto-generated labels. This is Dante Controller's grid reapplied to structured wiring, and it is the only way 60+ drops get entered in under two minutes.

```
                     Cat6  Cat6a  RG6  RG6q  16/2  16/4  22/4  Fiber  Cond
 Living Room          [4]   [0]   [2]   [0]   [0]   [2]   [1]   [0]   [0]
 Kitchen              [2]   [0]   [1]   [0]   [0]   [1]   [1]   [0]   [0]
 Primary Bedroom      [2]   [0]   [2]   [0]   [0]   [1]   [1]   [0]   [0]
 Bedroom 2            [2]   [0]   [1]   [0]   [0]   [1]   [0]   [0]   [0]
 Office               [4]   [0]   [1]   [0]   [0]   [0]   [1]   [0]   [1]
 Patio                [1]   [0]   [1]   [0]   [0]   [2]   [0]   [0]   [0]
 Attic (APs)          [3]   [0]   [0]   [0]   [0]   [0]   [0]   [0]   [0]
 Exterior (Cameras)   [6]   [0]   [0]   [0]   [0]   [0]   [0]   [0]   [0]
 ─────────────────────────────────────────────────────────────────────────
 TOTAL                 24     0     8     0     0     7     4     0     1
```

Media columns are user-configurable; the default set covers residential CI. A `+ Media` button adds a column.

**Command mode.** One text line, same DSL family as Quick Add:

```
Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4
Attic: 3x Cat6 @service=wifi-ap
Exterior: 6x Cat6 @service=camera @status=planned
Kitchen: 2x Cat6 + 1x RG6 as bundle "KIT-TV-1"
```

The `as bundle "…"` suffix is how a multi-media single run gets created in one line, one bundle containing three drops.

### 6.4 CSV / spreadsheet import

Accepts a pull list in either **long** shape (one row per drop) or **wide** shape (rooms as rows, media as numeric columns, because that is how pull lists actually look). Shape is auto-detected: if ≥2 column headers resolve to media synonyms *and* their cells are numeric, wide mode is offered.

Import is never fail-fast. A **column-mapping sheet** shows every source header, RackPal's best guess, and a dropdown to correct it. Unmapped columns are **preserved into a `custom` map and surfaced as optional grid columns**: user data is never discarded.

**Accepted columns** (matching is case-, space-, underscore-, and hyphen-insensitive):

| Canonical field | Accepted headers | Req. |
|---|---|---|
| `location` | `location`, `room`, `area`, `zone`, `space`, `destination` | ✔ |
| `floor` | `floor`, `level`, `story` | |
| `building` | `building`, `site`, `structure` | |
| `outlet` | `outlet`, `plate`, `jack`, `wallplate`, `wall_plate_id`, `box` | |
| `dropId` | `drop_id`, `cable_id`, `cable`, `run_id`, `id`, `#` | |
| `label` | `label`, `identifier`, `tag`, `cable_label`, `tia_id` | |
| `media` | `media`, `cable_type`, `type`, `wire`, `cable` | ✔ (long) |
| `qty` | `qty`, `quantity`, `count`, `ea`, `number` | |
| `service` | `service`, `use`, `purpose`, `signal`, `function`, `application` | |
| `bundle` | `bundle`, `bundle_id`, `run`, `group`, `home_run` | |
| `length` | `length`, `length_ft`, `footage`, `ft`, `len` | |
| `terminationRack` | `termination_rack`, `rack_end`, `panel`, `panel_port`, `head_end` | |
| `terminationField` | `termination_field`, `device_end`, `field_end`, `far_end` | |
| `status` | `status`, `state`, `phase` | |
| `jacketColor` | `color`, `colour`, `jacket`, `jacket_color` | |
| `conduit` | `conduit`, `raceway`, `pathway` | |
| `notes` | `notes`, `comments`, `remarks`, `note` | |

**Media synonym table** (extensible, ships with these): `cat6 / cat-6 / cat 6 / c6 / cat6 utp` → **Cat6**; `cat6a / c6a / cat6 shielded / f/utp` → **Cat6a**; `cat5e / c5e / cat5` → **Cat5e**; `rg6 / rg-6 / coax / coaxial` → **RG6**; `rg6q / rg6 quad / quad shield` → **RG6 Quad**; `rg11` → **RG11**; `16/2 / 16-2 / 16ga 2c / spkr 16/2` → **16/2 Speaker**; `16/4 / 14/4 / 14-4` → **16/4 · 14/4 Speaker**; `22/4 / 22-4 / control / keypad` → **22/4 Control**; `os2 / smf / single mode` → **Fiber OS2**; `om3 / om4 / mmf` → **Fiber MMF**; `conduit / smurf / ent` → **Conduit (empty)**.

Unmatched media values are **not** rejected; they are created as new user media types with a confirmation chip.

Preview grid shows the parsed result with per-row validation before commit. Duplicate labels are flagged, not blocked.

### 6.5 The drop table

One row per drop; bundles render as collapsible parent rows.

| Column | Notes |
|---|---|
| ⠿ / ☐ | reorder, select |
| `Location` | combo bound to the location tree; typing a new value offers to create the room |
| `Outlet` | plate/box identifier within the room |
| `Label` | **auto-generated** from the label template (§6.8); italic while auto, roman once edited |
| `TIA-606 ID` | second, standards-compliant identifier; also auto |
| `Media` | combo from the media table |
| `Service` | Ethernet · HDBaseT · CATV/TV · Satellite · OTA · Speaker · IR · Keypad/Control · Camera · Intercom · Fiber · **Undetermined** |
| `Bundle` | combo; blank = unbundled |
| `Rack termination` | Patch panel port · F barrel · Punchdown · Euroblock · Binding post · Unterminated coil · **(auto-fills when connected)** |
| `Field termination` | RJ45 jack · F jack · Speaker binding · Bare · Device pigtail |
| `Length (ft)` | |
| `Jacket` | colour swatch: pull lists carry it and installers use it |
| `Conduit` | |
| `Status` | Planned · Pulled · Terminated · Tested · **In use** · **Spare** · Abandoned |
| `Connected to` | read-only; the rack-side port this drop lands on, if any |
| `Notes` | |

Same operation set as the device grid: fill-down, fill-series, multi-row edit, duplicate, delete, reorder, find/replace, TSV copy/paste, renumber.

**`Service: Undetermined` is a first-class, encouraged state.** At rough-in a Cat6 home run may end up carrying Ethernet, HDBaseT, or nothing. The model permits it; connecting the drop assigns the family; validation then runs retroactively (an HDBaseT-assigned drop patched into a switch throws the error it should).

### 6.6 Bundles

```
Bundle { bundleId, label, locationId, conduitId?, lengthFt?, notes,
         members: [dropId] }
```

**Purely organisational**: NetBox's explicit precedent, and exactly right for the confirmed "no cable dressing" decision. A bundle does not affect tracing, connectivity, or the netlist. It affects two things only: how the run is *drawn* (one trunk that fans out at each end rather than five parallel lines) and how it is *grouped* in the schedule.

Created three ways: select rows → **Group into bundle**; the `as bundle "…"` command suffix; or automatically on CSV import when rows share a `bundle` value.

This gets ~90% of cable-management value for ~5% of the complexity, and is the reason the Structure symbol stays readable.

### 6.7 Rendering and readability at 60+ drops

The Structure device **never renders as a rectangle with 62 pins.** Five mechanisms, layered:

1. **Off-page connector flags.** Each drop is a pennant/flag glyph at the left drawing boundary, tagged with its label. This is the schematic convention for signals entering from elsewhere and it is the correct visual language.
2. **Room grouping with headers.** Flags are grouped under a rule bearing the room name and abbreviation. Room order follows the location tree.
3. **Unused collapse (default on).** Only *connected* drops render individually. Unconnected drops per room collapse into a single summary flag: `Living Room · 3 spare (2× Cat6, 1× RG6)`, click to expand. This makes the drawing show the system, and it produces a genuinely valuable byproduct: **an "Unused home runs" page in the PDF**, which is a deliverable integrators currently don't get from anything.
4. **Bundle trunks.** A bundle draws as one thick trunk from the Structure boundary toward the rack, fanning to individual ports only at the destination. Six-drop bundles become one line for 90% of their length.
5. **Named-net mode.** Any drop can be switched from *drawn* to *named*: a flag at the Structure and a matching flag at the destination port, with the label as the join, no line crosses the sheet. This is Q-SYS's signal-names escape hatch and it is what makes a 100-run house diagrammable at all. Q-SYS's rule is adopted verbatim: duplicate *source* names prohibited, duplicate *destination* names permitted.

Plus: room-level isolate/filter in both the editor and the diagram view, and automatic **sheet paging by room group** when a Structure exceeds a configurable flag count per sheet (default 40).

### 6.8 Labelling: TIA-606 and the human name, both

Both identifiers are generated for every drop. Both print on the schedule. The diagram shows the preferred one with the other as a secondary tag. This is deliberate: the standards-compliant ID satisfies the documentation requirement, and the human-readable one satisfies the person holding the cable.

Labels come from **configurable pattern templates**, not hard-coded formats. Tokens: `{site}` `{building}` `{floor}` `{tr}` `{rack}` `{panel}` `{port:2}` `{room}` `{roomAbbr}` `{outlet}` `{service}` `{media}` `{seq}` `{seq:2}` `{bundle}`.

Shipped presets:

| Preset | Pattern | Output |
|---|---|---|
| **TIA-606 Class 1** (single building, single TR) | `{tr}{panel}-{port:2}` | `A1-12` |
| **TIA-606 Class 2** (multiple TRs) | `{floor}{tr}-{panel}{port:2}` | `1A-A12` |
| **TIA-606 Class 3** (campus) | `{building}-{floor}{tr}-{panel}{port:2}` | `B2-1A-A12` |
| **Residential CI** (default) | `{roomAbbr}-{service}-{seq}` | `LR-TV-1`, `MBR-KEY-2`, `EXT-CAM-4` |
| **Room + media** | `{roomAbbr}-{media}-{seq:2}` | `LR-CAT6-01` |

Label uniqueness is enforced **project-wide**, not per-Structure, labels get printed on physical cable and must not collide across panels. Collisions raise a warning with a one-click "renumber the later one."

### 6.9 Multiple Structure devices: yes

Explicitly supported and encouraged. A rack fed from a garage structured-media enclosure *plus* a separate exterior/camera panel *plus* a utility/service feed is a normal residential job, and one monolithic node is less useful than three named ones.

Each Structure instance carries its own name, `refdesPrefix` (default `STR`, so `STR-1`, `STR-2`), its own location subtree scope, and its own label template. Constraints:

- Drop labels unique **project-wide** across all Structures.
- A room may appear under more than one Structure (a bedroom with data from the media panel and a camera from the exterior panel), the location tree is shared, the drops are not.
- Each Structure renders as its own flag column, at the left edge by default; a Structure can be pinned to the right edge instead (useful for a utility/service entrance drawn on the opposite side).

A Structure with zero drops is valid and shows a friendly empty state pointing at the three entry paths (matrix, command, CSV import).

---

## 7. The Seeded Catalog: 58 Templates

**Notation.** Each bank is one line:

```
QTY×CONNECTOR:signal:DIR[:SIDE]  "label pattern"          ← bank name
```

- `DIR`, `i` sink/input · `o` source/output · `b` bidirectional · `p` passive/bus node
- `SIDE`, `R` rear (default, omitted) · `F` front · `FR` paired front+rear
- Modifiers in brackets: `[z75]` impedance Ω · `[poe:at/c4]` PoE std/class · `[dte]` serial role · `[dcpass]` DC-passing · `[seq:1]` sequencer step · `[ups]` UPS-backed
- Power figures are `nameplate W / typical W`; weight in lb.

Where a template is marked **parametric**, the same definition ships with a build-time U or count parameter (blank panels, vent panels, patch panels), so the 58 shipped entries collapse to 47 distinct parametric families.

---

### 7.1 Video Distribution & Switching: 10

**V01 · HDMI Matrix 4×4**: `MTX` · 1U · 12 lb · 30/18 W · 14 in deep
```
4×HDMI-A:hdmi20:i        "HDMI IN {n}"            ← HDMI Inputs
4×HDMI-A:hdmi20:o        "HDMI OUT {n}"           ← HDMI Outputs
4×RCA:spdif-coax:o[z75]  "AUDIO OUT {n}"          ← De-embedded Audio
1×RJ45:ethernet:b        "LAN"                    ← Control
1×DE-9:rs232:b[dte]      "RS-232"
1×3.5mm:ir-rx:i          "IR IN"
1×DC-2.1:dc-12v:i        "12V DC IN"              ← Power  ⚠ external brick — consumes a PDU outlet
```

**V02 · HDMI/HDBaseT Matrix 8×8**: `MTX` · 3U · 16 lb · 90/55 W · 13 in
```
8×HDMI-A:hdmi20:i          "HDMI IN {n}"           ← HDMI Inputs
8×RJ45:hdbaset:o           "HDBT OUT {n}"          ← HDBaseT Outputs   ⚠ never patch to a switch
8×HDMI-A:hdmi20:o          "HDMI OUT {n}"          ← Mirrored HDMI Outputs
8×Euroblock-3:line-bal:o   "AUD OUT {n}"           ← Zone Audio
1×3.5mm:ir-rx:i            "IR IN"                 ← Control
8×3.5mm:ir-tx:o            "IR OUT {n}"
1×RJ45:ethernet:b          "LAN"
1×DE-9:rs232:b[dte]        "RS-232"
1×C14:ac-inlet:i           "AC IN"                 ← Power
```

**V03 · HDMI Matrix 16×16**: `MTX` · 4U · 31 lb · 180/110 W · 17 in
```
16×HDMI-A:hdmi20:i         "HDMI IN {n:2}"         ← HDMI Inputs
16×HDMI-A:hdmi20:o         "HDMI OUT {n:2}"        ← HDMI Outputs
16×Euroblock-3:line-bal:o  "AUD OUT {n:2}"         ← De-embedded Audio
1×RJ45:ethernet:b          "LAN"                   ← Control
1×DE-9:rs232:b[dte]        "RS-232"
1×3.5mm:ir-rx:i            "IR IN"
1×C14:ac-inlet:i           "AC IN"                 ← Power
```

**V04 · HDMI Splitter 1×4**: `DA` · 1U · 4 lb · 15/9 W · 6 in
```
1×HDMI-A:hdmi20:i   "HDMI IN"
4×HDMI-A:hdmi20:o   "HDMI OUT {n}"
1×DC-2.1:dc-12v:i   "12V DC IN"     ⚠ external brick
```

**V05 · HDMI Splitter 1×8**: `DA` · 1U · 5 lb · 25/15 W · 7 in
```
1×HDMI-A:hdmi20:i   "HDMI IN"
8×HDMI-A:hdmi20:o   "HDMI OUT {n}"
1×DC-2.1:dc-12v:i   "12V DC IN"
```

**V06 · Presentation Switcher / Scaler 4×1**: `SCL` · 1U · 8 lb · 45/28 W · 9 in
```
3×HDMI-A:hdmi20:i          "HDMI IN {n}"          ← Video Inputs
1×USB-C:dp-alt:i           "USB-C IN"
1×HDMI-A:hdmi20:o          "HDMI OUT"             ← Video Outputs
1×RJ45:hdbaset:o           "HDBT OUT"
1×3.5mm:line-unbal:i       "AUDIO IN"             ← Audio
1×Euroblock-5:line-bal:o   "AUDIO OUT"
1×RJ45:ethernet:b          "LAN"                  ← Control
1×DE-9:rs232:b[dte]        "RS-232"
1×3.5mm:ir-rx:i            "IR IN"
1×USB-A:usb2:b:F           "SERVICE"
1×C14:ac-inlet:i           "AC IN"                ← Power
```

**V07 · HDBaseT Transmitter**: `TX` · 0U hosted (½-rack, `hostedHeightU 1`) · 1.2 lb · 12/8 W · 4 in
```
1×HDMI-A:hdmi20:i        "HDMI IN"
1×HDMI-A:hdmi20:o        "HDMI LOOP OUT"
1×RJ45:hdbaset:o[poh]    "HDBT OUT"          ⚠ HDBaseT, not Ethernet — may source 100 W PoH
1×3.5mm:ir-rx:i          "IR IN"             [pinout: xantech-stereo]
1×3.5mm:ir-tx:o          "IR OUT"            [pinout: mono-tip-sleeve]
1×3.5mm:rs232:b[dte]     "RS-232"
1×DC-2.1:dc-12v:i        "12V DC IN"
```

**V08 · HDBaseT Receiver**: `RX` · `notInRack` (lives at the display) · 1.2 lb · 0/0 W (PoH-powered)
```
1×RJ45:hdbaset:i[poh-pd] "HDBT IN"
1×HDMI-A:hdmi20:o        "HDMI OUT"
1×3.5mm:ir-rx:i          "IR IN"
1×3.5mm:ir-tx:o          "IR OUT"
1×3.5mm:rs232:b[dte]     "RS-232"
1×DC-2.1:dc-12v:i        "12V DC IN (opt)"
```

**V09 · AVoIP Encoder**: `ENC` · 0U hosted (½-rack) · 1.5 lb · 12/9 W (802.3af PD) · 5 in
```
1×HDMI-A:hdmi20:i         "HDMI IN"
1×HDMI-A:hdmi20:o         "HDMI LOOP OUT"
1×RJ45:avoip:b[poe:af/c3-pd]  "NETWORK"      ← 1 G compressed class; 10 G variant is a tag
1×3.5mm:line-unbal:i      "ANALOG IN"
1×3.5mm:line-unbal:o      "ANALOG OUT"
1×3.5mm:ir-tx:o           "IR OUT"
1×3.5mm:rs232:b[dte]      "RS-232"
1×DC-2.1:dc-12v:i         "12V DC IN (opt)"
```

**V10 · AVoIP Decoder**: `DEC` · 0U hosted (½-rack) · 1.5 lb · 12/9 W (802.3af PD) · 5 in
```
1×RJ45:avoip:b[poe:af/c3-pd]  "NETWORK"
1×HDMI-A:hdmi20:o         "HDMI OUT"
1×3.5mm:line-unbal:o      "ANALOG OUT"
1×3.5mm:ir-tx:o           "IR OUT"
1×3.5mm:rs232:b[dte]      "RS-232"
1×DC-2.1:dc-12v:i         "12V DC IN (opt)"
```

---

### 7.2 Audio: 8

**A01 · Multi-Zone Amplifier, 8-channel (4 stereo zones)**: `AMP` · 2U · 22 lb · 400/180 W · 15 in · `clearanceAbove: 1U`
```
8×RCA:line-unbal:i         "SRC {n@2} {L,R}"      ← Source Inputs
8×Euroblock-2:speaker-lowz:o "ZONE {n@2} {L,R}"   ← Zone Speaker Outputs  [polarity +/−]
2×RCA:line-unbal:o         "SUB OUT {n}"          ← Sub Outputs
4×3.5mm:ir-rx:i            "ZONE {n} IR"          ← Control
1×RJ45:ethernet:b          "LAN"
1×DE-9:rs232:b[dte]        "RS-232"
1×3.5mm:trigger-12v:i      "TRIGGER IN"
1×3.5mm:trigger-12v:o      "TRIGGER OUT"          ⚠ ~100 mA fan-out limit
1×NEMA5-15P:ac-inlet:i     "AC (captive cord)"    ← Power
```

**A02 · Multi-Zone Amplifier, 16-channel (8 stereo zones)**: `AMP` · 3U · 38 lb · 800/340 W · 16 in · `clearanceAbove: 1U`
```
16×RCA:line-unbal:i          "SRC {n@2} {L,R}"     ← Source Inputs
16×Euroblock-2:speaker-lowz:o "ZONE {n@2} {L,R}"   ← Zone Speaker Outputs
2×RCA:line-unbal:o           "SUB OUT {n}"
8×3.5mm:ir-rx:i              "ZONE {n} IR"         ← Control
1×RJ45:ethernet:b            "LAN"
1×DE-9:rs232:b[dte]          "RS-232"
1×3.5mm:trigger-12v:i        "TRIGGER IN"
1×NEMA5-20P:ac-inlet:i       "AC (captive cord)"   ← Power  ⚠ 20 A plug
```

**A03 · AV Receiver, 7.2 channel**: `AVR` · shelf-mounted, `hostedHeightU 4` · 26 lb · 750/280 W · 15 in
```
7×HDMI-A:hdmi21:i          "HDMI IN {n}"          ← HDMI Inputs
1×HDMI-A:hdmi20:i:F        "HDMI FRONT"
1×HDMI-A:hdmi21:o          "HDMI OUT MAIN"        ← HDMI Outputs  [eARC return on MAIN]
2×HDMI-A:hdmi20:o          "HDMI OUT ZONE {n+1}"
2×JIS-F05:spdif-optical:i  "OPTICAL IN {n}"       ← Digital Audio In
2×RCA:spdif-coax:i[z75]    "COAX IN {n}"
8×RCA:line-unbal:i         "ANALOG IN {n@2} {L,R}"← Analog Audio In
2×RCA:phono:i              "PHONO {L,R}"
1×Lug:ground:p             "PHONO GND"            ⚠ a real conductor to schedule
14×BindingPost:speaker-lowz:o "{FL,FR,C,SL,SR,SBL,SBR} {+,−}"  ← Speaker Outputs
2×RCA:line-unbal:o         "SUB PRE OUT {n}"
1×F:rf-ota:i               "FM ANTENNA"           ← Tuner
1×RJ45:ethernet:b          "LAN"                  ← Control / Ancillary
1×3.5mm:ir-rx:i            "IR IN"
2×3.5mm:trigger-12v:o      "TRIGGER OUT {n}"
1×DE-9:rs232:b[dte]        "RS-232"
1×USB-A:usb2:b:F           "USB"
1×TRS-6.35:headphone:o:F   "PHONES"
1×NEMA5-15P:ac-inlet:i     "AC (captive cord)"    ← Power
```

**A04 · Surround Preamp / Processor**: `PRE` · 3U · 24 lb · 120/70 W · 16 in
```
8×HDMI-A:hdmi21:i          "HDMI IN {n}"          ← HDMI Inputs
2×HDMI-A:hdmi21:o          "HDMI OUT {n}"         ← HDMI Outputs
4×JIS-F05:spdif-optical:i  "OPTICAL IN {n}"       ← Digital Audio In
2×RCA:spdif-coax:i[z75]    "COAX IN {n}"
1×XLR3-F:aes3:i[z110]      "AES IN"
8×RCA:line-unbal:i         "ANALOG IN {n@2} {L,R}"← Analog Audio In
16×XLR3-M:line-bal:o       "BAL OUT {n:2}"        ← Balanced Pre-Outs
16×RCA:line-unbal:o        "UNBAL OUT {n:2}"      ← Unbalanced Pre-Outs (mirrored)
2×XLR3-M:line-bal:o        "SUB OUT {n}"
1×RJ45:ethernet:b          "LAN"                  ← Control
1×DE-9:rs232:b[dte]        "RS-232"
2×3.5mm:trigger-12v:o      "TRIGGER OUT {n}"
1×C14:ac-inlet:i           "AC IN"                ← Power
```

**A05 · DSP Audio Processor (8×8 + Dante)**: `DSP` · 1U · 9 lb · 60/35 W · 12 in
```
8×Euroblock-3:mic-line:i   "IN {n}"               ← Analog Inputs  [phantom-capable]
8×Euroblock-3:line-bal:o   "OUT {n}"              ← Analog Outputs
1×RJ45:dante:b             "DANTE PRI"            ← Audio Network  ⚠ PTPv1; QoS/VLAN required
1×RJ45:dante:b             "DANTE SEC"
1×RJ45:ethernet:b          "CONTROL LAN"          ← Control
1×DE-9:rs232:b[dte]        "RS-232"
8×Euroblock-2:gpio:b       "GPIO {n}"
1×USB-B:usb2:b:F           "CONFIG"
1×C14:ac-inlet:i           "AC IN"                ← Power
```

**A06 · Multi-Zone Streaming Source (4 stream)**: `STR` · 1U · 7 lb · 35/20 W · 11 in
```
8×RCA:line-unbal:o         "STREAM {n@2} {L,R}"   ← Analog Outputs
4×RCA:spdif-coax:o[z75]    "DIGITAL OUT {n}"      ← Digital Outputs
2×RCA:line-unbal:i         "AUX IN {L,R}"         ← Aux Input
1×3.5mm:line-unbal:i:F     "FRONT AUX"
1×RJ45:ethernet:b          "LAN"                  ← Control
1×USB-A:usb2:b:F           "USB"
1×C14:ac-inlet:i           "AC IN"                ← Power
```

**A07 · 70V/100V Commercial Amplifier, 2×250 W**: `AMP` · 2U · 28 lb · 700/300 W · 15 in · `clearanceAbove: 1U`
```
2×Euroblock-3:line-bal:i   "IN {A,B}"             ← Line Inputs
2×Euroblock-3:line-bal:o   "LINK OUT {A,B}"       ← Link Thru
2×Euroblock-2:speaker-cv:o "70V OUT {A,B}"        ← CV Speaker Outputs  [nominalV 70, bus/multidrop]
1×Euroblock-2:contact:i    "MUTE / PRIORITY"      ← Control
1×RJ45:ethernet:b          "MONITORING"
1×NEMA5-20P:ac-inlet:i     "AC (captive cord)"    ← Power
```

**A08 · Stereo Power Amplifier, 2×200 W**: `AMP` · 2U · 34 lb · 900/380 W · 17 in · `clearanceAbove: 1U`
```
2×XLR3-F:line-bal:i        "BAL IN {L,R}"         ← Inputs
2×RCA:line-unbal:i         "UNBAL IN {L,R}"
4×BindingPost:speaker-lowz:o "{L,R} {+,−}"        ← Speaker Outputs
1×3.5mm:trigger-12v:i      "TRIGGER IN"           ← Control
1×NEMA5-20P:ac-inlet:i     "AC (captive cord)"    ← Power
```

---

### 7.3 Network & Cabling Infrastructure: 10

**N01 · PoE Switch, 8-port**: `SW` · 1U · 6 lb · 150/60 W · 10 in · **PoE budget 130 W**
```
8×RJ45:ethernet:b[poe:at/pse]  "{n}"              ← Access Ports  [1G]
2×SFP:ethernet:b               "SFP {n}"          ← Uplinks       [1G]
1×USB-C:console:b:F            "CONSOLE"          ← Management
1×C14:ac-inlet:i               "AC IN"            ← Power
```

**N02 · PoE Switch, 24-port**: `SW` · 1U · 11 lb · 450/190 W · 14 in · **PoE budget 370 W**
```
24×RJ45:ethernet:b[poe:at/pse] "{n:2}"            ← Access Ports  [1G]
4×SFP+:ethernet:b              "SFP+ {n}"         ← Uplinks       [10G]
1×RJ45:ethernet:b              "OOB MGMT"         ← Management
1×DE-9:console:b:F[dce]        "CONSOLE"
1×C14:ac-inlet:i               "AC IN"            ← Power
```

**N03 · PoE Switch, 48-port**: `SW` · 1U · 17 lb · 900/380 W · 17 in · **PoE budget 740 W** · `clearanceAbove: 1U`
```
48×RJ45:ethernet:b[poe:bt-t3/pse] "{n:2}"         ← Access Ports  [1G, 60 W Type 3]
4×SFP28:ethernet:b             "SFP28 {n}"        ← Uplinks       [25G]
1×RJ45:ethernet:b              "OOB MGMT"         ← Management
1×DE-9:console:b:F[dce]        "CONSOLE"
2×C14:ac-inlet:i               "PSU {A,B}"        ← Power (redundant)
```

**N04 · 10G Aggregation Switch**: `SW` · 1U · 12 lb · 250/120 W · 15 in
```
8×SFP+:ethernet:b     "SFP+ {n}"                  ← 10G Fiber   [10G]
4×RJ45:ethernet:b     "10GBASE-T {n}"             ← 10G Copper  [10G]
1×RJ45:ethernet:b     "OOB MGMT"                  ← Management
2×C14:ac-inlet:i      "PSU {A,B}"                 ← Power
```

**N05 · Router / Firewall**: `FW` · 1U · 9 lb · 120/55 W · 13 in
```
2×RJ45:ethernet:b     "WAN {n}"                   ← WAN
8×RJ45:ethernet:b     "LAN {n}"                   ← LAN  [1G]
2×SFP+:ethernet:b     "SFP+ {n}"                  ← Fiber
1×RJ45:ethernet:b     "MGMT"                      ← Management
1×DE-9:console:b:F[dce] "CONSOLE"
1×C14:ac-inlet:i      "AC IN"                     ← Power
```

**N06 · Wireless Controller / Site Gateway**: `WLC` · 0U hosted (½-rack) · 1 lb · 12/7 W
```
1×RJ45:ethernet:b[poe:af/pd] "LAN"
1×USB-A:usb2:b        "USB"
1×DC-2.1:dc-12v:i     "12V DC IN (opt)"
```

**N07 · Patch Panel, 12-port**: `PP` · 1U · 2 lb · 0 W · **passthrough** · parametric
```
12×RJ45:ethernet:p:F  "{n:2}"                     ← Front Jacks
12×IDC-110:ethernet:p:R "{n:2}"                   ← Rear Punchdown   [paired 1:1 with front]
```

**N08 · Patch Panel, 24-port**: `PP` · 1U · 3 lb · 0 W · **passthrough** · parametric
```
24×RJ45:ethernet:p:F  "{n:2}"                     ← Front Jacks
24×IDC-110:ethernet:p:R "{n:2}"                   ← Rear Punchdown   [paired 1:1]
```
> ⚠ 24-port panels ship as both 1U and 2U in the real world. Height is a template field, **never derived from port count**. The 2U variant ships as a parametric option, not a separate entry.

**N09 · Patch Panel, 48-port**: `PP` · 2U · 5 lb · 0 W · **passthrough** · parametric
```
48×RJ45:ethernet:p:F  "{n:2}"                     ← Front Jacks
48×IDC-110:ethernet:p:R "{n:2}"                   ← Rear Punchdown   [paired 1:1]
```

**N10 · Fiber Enclosure / LIU, 24-fiber**: `LIU` · 1U · 6 lb · 0 W · **passthrough**
```
12×LC-Duplex:fiber:p:F "LC {n:2}"                 ← Front Adapters   [OS2]
24×Splice:fiber:p:R    "SPL {n:2}"                ← Rear Splice Tray
```

---

### 7.4 Control: 6

**C01 · Control Processor**: `CTL` · 1U · 7 lb · 60/30 W · 11 in
```
2×RJ45:ethernet:b          "LAN {n}"              ← Network
8×Euroblock-3:rs232:b[dte] "COM {n}"              ← Serial   [also RS-422/485 selectable]
8×3.5mm:ir-tx:o            "IR/SERIAL {n}"        ← IR Outputs  [pinout: mono-tip-sleeve]
8×Euroblock-2:contact:i    "DIGITAL IN {n}"       ← Digital Inputs
4×Euroblock-3:relay:o      "RELAY {n}"            ← Relays  [NO/COM/NC, dry]
1×Euroblock-4:cresnet:b    "CRESNET"              ← Control Bus  [bus topology]
1×USB-A:usb2:b:F           "SETUP"
1×C14:ac-inlet:i           "AC IN"                ← Power
```

**C02 · IR Distribution Block**: `IRB` · 1U · 2 lb · 12/6 W · 5 in
```
1×3.5mm:ir-rx:i        "IR IN (from processor)"   ← Source
4×3.5mm:ir-rx:i        "IR RX {n}"                ← Receiver Inputs  [pinout: xantech-stereo, +12 V on sleeve]
16×3.5mm:ir-tx:o       "EMITTER {n:2}"            ← Emitter Outputs  [pinout: mono-tip-sleeve]
1×DC-2.1:dc-12v:i      "12V DC IN"                ← Power
```
> ⚠ Receiver and emitter jacks are **not** interchangeable. Plugging an emitter into a receiver jack destroys the emitter and can damage the supply. `pinoutVariant` on each bank is what makes RackMate catch this at drag time.

**C03 · Relay / I-O Module**: `IO` · 1U · 4 lb · 25/12 W · 8 in
```
8×Euroblock-3:relay:o   "RELAY {n}"               ← Relays  [NO/COM/NC]
8×Euroblock-2:contact:i "INPUT {n}"               ← Digital Inputs
1×RJ45:ethernet:b       "LAN"                     ← Control
1×Euroblock-4:cresnet:b "CRESNET"
1×C14:ac-inlet:i        "AC IN"                   ← Power
```

**C04 · RS-232 / IP Gateway, 8-port**: `SER` · 1U · 5 lb · 30/15 W · 8 in
```
8×DE-9:rs232:b[dte]  "COM {n}"                    ← Serial Ports
1×RJ45:ethernet:b    "LAN"                        ← Network
1×RJ45:ethernet:b    "MGMT"
1×C14:ac-inlet:i     "AC IN"                      ← Power
```

**C05 · DMX / Lighting Gateway, 4 universe**: `DMX` · 1U · 4 lb · 25/12 W · 8 in
```
4×XLR5-F:dmx512:o    "DMX OUT {A}"                ← DMX Outputs  [bus, 32 unit loads/universe, 120 Ω term at far end]
1×XLR5-M:dmx512:i    "DMX IN"
2×RJ45:ethernet:b    "sACN/ArtNet {n}"            ← Network
1×C14:ac-inlet:i     "AC IN"                      ← Power
```

**C06 · Control Bus Power Supply, 75 W**: `PSU` · 1U · 6 lb · 90/45 W · 8 in
```
4×Euroblock-4:cresnet:o  "NET {n}"                ← Bus Outputs  [24 V; 18 AWG @20 W ⇒ 333 ft limit]
1×C14:ac-inlet:i         "AC IN"                  ← Power
```

---

### 7.5 Sources: 5

**S01 · Cable / Satellite Set-Top Box**: `STB` · 0U hosted, `hostedHeightU 1` · 3 lb · 35/22 W · 10 in
```
1×F:rf-catv:i[z75]      "RF IN"
1×F:rf-catv:o[z75]      "RF OUT (loop)"
1×HDMI-A:hdmi20:o       "HDMI OUT"
2×RCA:line-unbal:o      "AUDIO OUT {L,R}"
1×RCA:spdif-coax:o[z75] "COAX DIGITAL"
1×JIS-F05:spdif-optical:o "OPTICAL"
1×RJ45:ethernet:b       "LAN"
1×USB-A:usb2:b          "USB"
1×3.5mm:ir-rx:i         "IR IN"
1×NEMA5-15P:ac-inlet:i  "AC (captive cord)"
```

**S02 · Streaming Media Player**: `SMP` · 0U hosted · 0.5 lb · 8/5 W · 4 in
```
1×HDMI-A:hdmi21:o     "HDMI OUT"
1×RJ45:ethernet:b     "LAN"
1×3.5mm:ir-rx:i       "IR IN (opt)"
1×USB-C:dc-5v:i       "USB-C POWER"     ⚠ still consumes a PDU outlet
```

**S03 · UHD Disc Player**: `BDP` · 0U hosted, `hostedHeightU 2` · 8 lb · 45/28 W · 12 in
```
1×HDMI-A:hdmi21:o        "HDMI OUT (A/V)"
1×HDMI-A:hdmi20:o        "HDMI OUT (audio only)"
1×RCA:spdif-coax:o[z75]  "COAX DIGITAL"
1×RJ45:ethernet:b        "LAN"
1×USB-A:usb2:b:F         "USB"
1×3.5mm:ir-rx:i          "IR IN"
1×NEMA5-15P:ac-inlet:i   "AC (captive cord)"
```

**S04 · Media Server / NAS**: `NAS` · 2U · 30 lb · 350/160 W · 22 in
```
2×RJ45:ethernet:b   "LAN {n}"        ← Network  [1G]
2×SFP+:ethernet:b   "SFP+ {n}"       [10G]
1×HDMI-A:hdmi20:o   "HDMI"           ← Console
2×USB-A:usb3:b      "USB {n}"
2×C14:ac-inlet:i    "PSU {A,B}"      ← Power (redundant)
```

**S05 · Network Tuner, 4-tuner OTA/QAM**: `TUN` · 0U hosted · 1 lb · 15/9 W · 5 in
```
1×F:rf-ota:i[z75]           "ANTENNA IN"
1×RJ45:ethernet:b[poe:af/pd] "LAN"
1×DC-2.1:dc-12v:i           "12V DC IN (opt)"
```

---

### 7.6 RF / Coax: 4

**R01 · RF Splitter Panel, 8-way**: `SPL` · 1U · 2 lb · **0 W passive**
```
1×F:rf-catv:p[z75]           "IN"
8×F:rf-catv:p[z75]           "OUT {n}"    ← port 1 flagged [dcpass]
```
> Loss budget is the design: an 8-way is ≈ −11 dB per port. Exactly **one** output passes DC toward the source — mis-wire it and a satellite LNB never powers.

**R02 · RF Distribution Amplifier**: `RFA` · 1U · 4 lb · 25/14 W · 7 in
```
1×F:rf-catv:i[z75]     "RF IN"
8×F:rf-catv:o[z75]     "RF OUT {n}"       ← directional; blocks the return path
1×F:rf-catv:b[z75]     "RETURN / VOIP PASS"
1×NEMA5-15P:ac-inlet:i "AC (captive cord)"
```

**R03 · RF Modulator, 2-ch HDMI → QAM**: `MOD` · 1U · 7 lb · 40/24 W · 11 in
```
2×HDMI-A:hdmi20:i   "HDMI IN {n}"
2×HDMI-A:hdmi20:o   "HDMI LOOP {n}"
1×F:rf-catv:o[z75]  "RF OUT"
1×F:rf-catv:i[z75]  "RF IN (combine)"
1×RJ45:ethernet:b   "LAN"
1×C14:ac-inlet:i    "AC IN"
```

**R04 · Satellite Multiswitch (SWM-16)**: `SWM` · 1U · 5 lb · 30/22 W · 9 in
```
4×F:rf-sat:i[z75]        "SAT IN {n}"       ← LNB Inputs  [DC-passing to LNB]
1×F:rf-ota:i[z75]        "OTA IN"
16×F:rf-sat:o[z75,dcpass] "SWM OUT {n:2}"   ← Receiver Outputs  ⚠ hard budget: 16 tuners
1×F:dc-inject:i          "POWER INSERT"
1×NEMA5-15P:ac-inlet:i   "PSU (captive cord)"
```

---

### 7.7 Power: 8

**P01 · Rack PDU, 1U, 8-outlet**: `PDU` · 1U · 7 lb · 5 W (own draw) · 20 A / 120 V
```
1×NEMA5-20P:ac-inlet:i   "AC IN (captive cord)"
8×NEMA5-15R:ac-outlet:o  "OUT {n}"      [mode: unswitched]
1×RJ45:ethernet:b        "MGMT (metered SKU)"
1×Breaker:—:—:F          "20A BREAKER"
```

**P02 · Rack PDU, 2U, 16-outlet**: `PDU` · 2U · 12 lb · 8 W · 20 A / 120 V
```
1×NEMA5-20P:ac-inlet:i     "AC IN (captive cord)"
12×NEMA5-15R:ac-outlet:o:R "REAR {n:2}"
4×NEMA5-15R:ac-outlet:o:F  "FRONT {n}"
1×RJ45:ethernet:b          "MGMT"
```

**P03 · Vertical PDU, 0U, 24-outlet**: `PDU` · **0U** (`zeroU_vertical`) · 14 lb · 10 W · 30 A / 120 V
```
1×NEMA-L5-30P:ac-inlet:i  "AC IN (captive cord)"
20×C13:ac-outlet:o        "C13 {n:2}"     [mode: unswitched]
4×C19:ac-outlet:o         "C19 {n}"
1×RJ45:ethernet:b         "MGMT"
```
> Occupies rear vertical channel; `{frontU:0, rearU:0, side:zeroU_vertical}`. Delivers 24 outlets where a 1U horizontal gives 8 — the single best RU-saving move in a dense rack.

**P04 · Power Conditioner, 1U, 8-outlet**: `PWC` · 1U · 14 lb · 10 W · 15 A / 120 V
```
1×NEMA5-15P:ac-inlet:i    "AC IN (captive cord)"
2×NEMA5-15R:ac-outlet:o   "HIGH CURRENT {n}"   [mode: unswitched]
6×NEMA5-15R:ac-outlet:o   "FILTERED {n}"       [mode: unswitched, surge]
1×3.5mm:trigger-12v:i     "TRIGGER IN"
1×RJ45:ethernet:b         "MGMT"
```

**P05 · Power Sequencer, 2U, 16-outlet**: `SEQ` · 2U · 18 lb · 12 W · 20 A / 120 V
```
1×NEMA5-20P:ac-inlet:i    "AC IN (captive cord)"
4×NEMA5-15R:ac-outlet:o   "STEP 1 OUT {n}"   [seq:1, delay 0 ms]
4×NEMA5-15R:ac-outlet:o   "STEP 2 OUT {n}"   [seq:2, delay 1000 ms]
4×NEMA5-15R:ac-outlet:o   "STEP 3 OUT {n}"   [seq:3, delay 2000 ms]
4×NEMA5-15R:ac-outlet:o   "STEP 4 OUT {n}"   [seq:4, delay 3000 ms]
1×Euroblock-2:contact:i   "REMOTE ON"
1×3.5mm:trigger-12v:i     "TRIGGER IN"
1×3.5mm:trigger-12v:o     "TRIGGER OUT"
1×RJ45:ethernet:b         "LAN"
1×DE-9:rs232:b[dte]       "RS-232"
```

**P06 · UPS, 1U, 1000 VA / 900 W**: `UPS` · 1U · 30 lb · 15 A / 120 V · **place low in the rack**
```
1×NEMA5-15P:ac-inlet:i   "AC IN (captive cord)"
4×NEMA5-15R:ac-outlet:o  "UPS OUT {n}"     [backing: ups]
2×NEMA5-15R:ac-outlet:o  "SURGE OUT {n}"   [backing: surge]
1×RJ45:ethernet:b        "NETWORK CARD"
1×USB-B:usb2:b           "USB"
1×DE-9:rs232:b[dce]      "RS-232"
```

**P07 · UPS, 2U, 1500 VA / 1350 W**: `UPS` · 2U · 48 lb · 15 A / 120 V · **place low**
```
1×NEMA5-15P:ac-inlet:i   "AC IN (captive cord)"
6×NEMA5-15R:ac-outlet:o  "UPS OUT {n}"     [backing: ups]
2×NEMA5-15R:ac-outlet:o  "SURGE OUT {n}"   [backing: surge]
1×RJ45:ethernet:b        "NETWORK CARD"
1×USB-B:usb2:b           "USB"
1×DE-9:rs232:b[dce]      "RS-232"
1×BattConn:dc-batt:b     "BATTERY EXPANSION"
```

**P08 · UPS, 3U, 3000 VA / 2700 W**: `UPS` · 3U · 92 lb · 30 A / 120 V · **place at the very bottom**
```
1×NEMA-L5-30P:ac-inlet:i "AC IN (captive cord)"
6×C13:ac-outlet:o        "C13 OUT {n}"     [backing: ups]
2×C19:ac-outlet:o        "C19 OUT {n}"     [backing: ups]
2×NEMA5-20R:ac-outlet:o  "5-20R OUT {n}"   [backing: ups]
1×RJ45:ethernet:b        "NETWORK CARD"
1×USB-B:usb2:b           "USB"
1×DE-9:rs232:b[dce]      "RS-232"
2×BattConn:dc-batt:b     "BATTERY EXPANSION {n}"
```
> A 92 lb device instantly blows a 100 lb wall-rack rating. This template is the reason `rackWeightCapacity` and a top-heavy CG warning exist.

---

### 7.8 Passive & Mechanical: 11

All zero-power, zero-port unless noted. All are `category: passive-mechanical`.

| ID | Name | Refdes | Occupancy | Weight | Ports |
|---|---|---|---|---|---|
| **X01** | Blank Panel 1U | `BLK` | `{front:1, rear:0}` | 1 lb | none |
| **X02** | Blank Panel 2U | `BLK` | `{front:2, rear:0}` | 2 lb | none |
| **X03** | Blank Panel 3U | `BLK` | `{front:3, rear:0}` | 3 lb | none |
| **X04** | Vent Panel 1U (64% open) | `VNT` | `{front:1, rear:0}` | 1 lb | none |
| **X05** | Vent Panel 2U (64% open) | `VNT` | `{front:2, rear:0}` | 2 lb | none |
| **X06** | Fan Panel 1U (3-fan) | `FAN` | `{front:1, rear:1}` | 5 lb | `1×C14:ac-inlet:i "AC IN"` · `1×Euroblock-2:sensor:i "THERMOSTAT PROBE"` · 60/35 W |
| **X07** | Rack Shelf 1U, vented | `SHF` | `{front:1, rear:0}` | 3 lb | none · **container**, cap 35 lb, usable depth 264 mm (10.4 in) |
| **X08** | Rack Shelf 2U, vented | `SHF` | `{front:2, rear:0}` | 5 lb | none · **container**, cap 50 lb, usable depth 375 mm (14.75 in) |
| **X09** | Rack Drawer 2U | `DRW` | `{front:2, rear:2}` | 12 lb | none |
| **X10** | Lacing Bar, rear L-bar | `LBP` | `{front:0, rear:1}` | 1 lb | none · consumes **rear rail holes only** |
| **X11** | Cable Pass-Through Panel 1U (brush) | `PTH` | `{front:1, rear:0}` | 1 lb | none |

X01–X05 are parametric (one template, U-height parameter) but ship pre-instantiated at the common sizes because picking from a list is faster than filling in a parameter.

---

### 7.9 Catalog summary

| Category | Count |
|---|---|
| Video Distribution & Switching | 10 |
| Audio | 8 |
| Network & Cabling Infrastructure | 10 |
| Control | 6 |
| Sources | 5 |
| RF / Coax | 4 |
| Power | 8 |
| Passive & Mechanical | 11 |
| **Total shipped templates** | **62** |
| Distinct parametric families | 47 |

Every template above carries realistic weight, depth, nameplate and typical wattage, so the per-rack rollups (total weight vs capacity, CG height, watts, BTU/hr = W × 3.412, outlets used vs available, front/rear RU free, deepest device vs usable depth) are populated from the moment a user drags anything in. That is what makes the seeded catalog a demo of the product rather than just a shape library.

---

## 8. Text Wireframes

### 8.1 Device Builder: I/O section (the primary screen)

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│  RackPal — Device Builder                    HDMI/HDBaseT Matrix 8x8  ·  v1.3.0  ·  ● Unsaved       │
│  [ ← Library ]                                        [ Version diff… ]  [ Save as 1.4.0 ]  [ ⋯ ]    │
├────────────────────┬─────────────────────────────────────────────────────────┬───────────────────────┤
│                    │ ┌─ Quick Add ─────────────────────────────────────────┐ │  ▾ RACK ELEVATION     │
│ ① Identity      ✓  │ │ ⌨  8 hdbt out "HDBT OUT {n}" @HDBaseT Outputs      │ │ ┌───────────────────┐ │
│ ② Physical      ✓  │ │                                        [ Add ▸ ]   │ │ │ ▓ MTX-1  Matrix 8x8│ │
│ ③ Power         ✓  │ │ Qty[8] Conn[RJ45▾] Sig[hdbaset▾] Dir[Out▾]        │ │ │ ▓                 │ │
│ ▶ ④ Ports      41  │ │ Side[Rear▾] Start[1] Step[1]                       │ │ │ ▓  ● ● ●      3U  │ │
│ ⑤ Panel Layout Auto│ │ [ Matrix I/O… ] [ Switch ports… ] [ Paste TSV… ]   │ │ └───────────────────┘ │
│ ⑥ Appearance    ✓  │ └─────────────────────────────────────────────────────┘ │   ( Front ) ( Rear )  │
│ ⑦ Notes            │                                                         │                       │
│                    │  [Search ports…]  ⚙Columns▾  Packs: ☑Core ☐Net ☐Bus    │  ▾ SCHEMATIC SYMBOL   │
│ ── BANKS ────────  │ ┌────────────────────────────────────────────────────┐ │ ┌───────────────────┐ │
│ ⠿ HDMI Inputs   8  │ │⠿☐│Label        │Desig│Connector│Signal  │Dir│Side│ │ │ │ MTX-1             │ │
│ ⠿ HDBaseT Out   8  │ ├──┼─────────────┼─────┼─────────┼────────┼───┼────┤ │ │ │ HDMI Matrix 8x8   │ │
│ ⠿ Mirrored HDMI 8  │ │▾ HDMI Inputs                        (8)   [ ⋯ ]  │ │ │ │◀HDMI IN  ⟨8⟩  ⟨8⟩▶│ │
│ ⠿ Zone Audio    8  │ │⠿☐│HDMI IN 1    │ J1  │HDMI-A   │hdmi20  │ In│ R  │ │ │ │            HDBT   │ │
│ ⠿ Control       10 │ │⠿☑│HDMI IN 2    │ J2  │HDMI-A   │hdmi20  │ In│ R  │ │ │ │◀IR IN    ⟨8⟩  ⟨8⟩▶│ │
│ ⠿ Power         1  │ │⠿☑│HDMI IN 3    │ J3  │HDMI-A   │hdmi20  │ In│ R  │ │ │ │            AUD    │ │
│                    │ │⠿☐│HDMI IN 4    │ J4  │HDMI-A   │hdmi20  │ In│ R  │ │ │ │◀LAN  ┌────┐  ⟨8⟩▶│ │
│ [ + New bank ]     │ │  │…                                                │ │ │ │◀232  │ AC │ HDMI │ │
│                    │ │▾ HDBaseT Outputs                    (8)   [ ⋯ ]  │ │ │ └──────┴────┴──────┘ │
│ ── VALIDATION ───  │ │⠿☐│HDBT OUT 1   │ J9  │RJ45     │hdbaset │Out│ R  │ │ │                       │
│ ● 0 errors         │ │⠿☐│HDBT OUT 2   │ J10 │RJ45     │hdbaset │Out│ R  │ │ │  ▾ REAR PANEL (auto)  │
│ ▲ 1 warning        │ │  │…                                                │ │ ┌───────────────────┐ │
│   IR OUT bank has  │ │▸ Mirrored HDMI Outputs              (8)   [ ⋯ ]  │ │ │▪▪▪▪▪▪▪▪ ▫▫▫▫▫▫▫▫ ⊙│ │
│   no pinoutVariant │ │▸ Zone Audio                         (8)   [ ⋯ ]  │ │ │▪▪▪▪▪▪▪▪ ⊚⊚⊚ ▭     │ │
│                    │ │▸ Control                           (10)   [ ⋯ ]  │ │ └───────────────────┘ │
│                    │ │▸ Power                              (1)   [ ⋯ ]  │ │  Panel fill R: 71%    │
│                    │ └────────────────────────────────────────────────────┘ │                       │
│                    │ 41 ports · 6 banks · 16 HDMI · 9 RJ45 · 8 Euroblock ·  │  ── SELECTION (2) ──  │
│                    │ 1 C14 · Rear 41 / Front 0 · ▲1                         │  Label      —         │
│                    │                                                         │  Connector  HDMI-A    │
│                    │                                                         │  Signal     hdmi20    │
│                    │                                                         │  Dir        In        │
│                    │                                                         │  Side     [Rear ▾]    │
│                    │                                                         │  Notes      —         │
└────────────────────┴─────────────────────────────────────────────────────────┴───────────────────────┘
  Ctrl+D fill down · Ctrl+J duplicate · Ctrl+R renumber · Ctrl+T change type · Ctrl+M move to bank
```

### 8.2 Device Builder: Identity & Physical section

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ ① IDENTITY & CLASSIFICATION                                                    ▾ RACK ELEVATION      │
│                                                                                ┌───────────────────┐ │
│  Name *          [ HDMI/HDBaseT Matrix 8x8                            ]        │ ▓ MTX-1           │ │
│  Manufacturer    [ Generic                    ]  Model [ MTX-8x8-HDBT ]        │ ▓  HDMI Matrix 8x8│ │
│  Category *      [ Video Distribution ▾ ]  Subcat [ Matrix ▾ ]                 │ ▓  ● ● ●      3U  │ │
│  Refdes prefix * [ MTX  ]  → instances will be MTX-1, MTX-2, MTX-3 …           └───────────────────┘ │
│  Tags            ( hdbaset ×) ( 4k60 ×) ( residential ×)  [ + ]                                      │
│  Description     [                                                     ]                             │
│                  [                                                     ]                             │
│                                                                                                      │
│ ② PHYSICAL & MOUNTING                                                                                │
│                                                                                                      │
│  Occupancy       Front [ 3 ] U    Rear [ 3 ] U    Side [ Both ▾ ]                                    │
│                  ℹ Drawn height = 44.45 × 3 − 0.79 = 132.56 mm (5.219 in)                            │
│  Mount method    [ Rack ears ▾ ]        Width class [ Full 19" ▾ ]                                   │
│  Depth           Chassis [ 330 ] mm     With connectors [ 405 ] mm  (auto +75)                       │
│  Weight          [ 16.0 ] lb   ( 7.26 kg )                                                           │
│  Clearance       Above [ 0 ] U   Below [ 0 ] U                                                       │
│  ☐ This device is a container (shelf/drawer)                                                         │
│  ☐ This device is a passthrough (front↔rear paired ports)                                            │
│                                                                                                      │
│ ③ POWER & THERMAL                                                                                    │
│                                                                                                      │
│  Nameplate  [ 90 ] W      Typical [ 55 ] W      Standby [ 8 ] W                                      │
│  Voltage    [ 120 ] V     Phase [ 1 ▾ ]         ☑ Continuous load (3 h+)                             │
│  Heat       1,876 BTU/hr  (auto: 55 W × 3.412)   ☐ Override                                          │
│  Outlets    provided 0 · consumed 1  (from Power bank)                                               │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Structure Editor: matrix bulk entry

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│  Structure: STR-1 "Media Panel — Garage"        62 drops · 41 connected · 21 spare    [ ⋯ ] [ Done ] │
│  [ Matrix ] [ Table ] [ Bundles ]        Label preset: [ Residential CI  {roomAbbr}-{service}-{seq} ▾]│
├──────────────────┬───────────────────────────────────────────────────────────────────────────────────┤
│ ── LOCATIONS ──  │  Bulk entry:  ⌨ [ Living Room: 4x Cat6, 2x RG6, 2x 16/4          ]  [ Add ▸ ]    │
│ ▾ 123 Oak St     │               or use the matrix below — spinners create drops instantly.          │
│   ▾ Level 1      │                                                                                   │
│     Living Room  │              Cat6  Cat6a  RG6  RG6q  16/2  16/4  22/4  OS2  Cond      Σ   Bundles │
│     Kitchen      │  ────────────────────────────────────────────────────────────────────────────────│
│     Office       │  Living Room   [4]   [0]   [2]   [0]   [0]   [2]   [1]  [0]   [0]     9      2    │
│     Patio        │  Kitchen       [2]   [0]   [1]   [0]   [0]   [1]   [1]  [0]   [0]     5      1    │
│   ▾ Level 2      │  Office        [4]   [0]   [1]   [0]   [0]   [0]   [1]  [0]   [1]     7      1    │
│     Primary Bdrm │  Patio         [1]   [0]   [1]   [0]   [0]   [2]   [0]  [0]   [0]     4      1    │
│     Bedroom 2    │  Primary Bdrm  [2]   [0]   [2]   [0]   [0]   [1]   [1]  [0]   [0]     6      2    │
│     Bedroom 3    │  Bedroom 2     [2]   [0]   [1]   [0]   [0]   [1]   [0]  [0]   [0]     4      1    │
│   ▾ Other        │  Bedroom 3     [2]   [0]   [1]   [0]   [0]   [1]   [0]  [0]   [0]     4      1    │
│     Attic        │  Attic         [3]   [0]   [0]   [0]   [0]   [0]   [0]  [0]   [0]     3      0    │
│     Exterior     │  Exterior      [6]   [0]   [0]   [0]   [0]   [0]   [0]  [0]   [0]     6      1    │
│                  │  Garage        [2]   [0]   [1]   [0]   [0]   [0]   [0]  [1]   [0]     4      1    │
│ [ + Room ]       │  ────────────────────────────────────────────────────────────────────────────────│
│                  │  TOTAL          28     0     9     0     0     8     4    1     1    52          │
│ Abbrev (edit):   │                                                    [ + Media column ]            │
│  Living Room→LR  │                                                                                   │
│  Primary Bdrm→MBR│  [ Import CSV… ]  [ Export CSV ]                                                  │
│  Exterior→EXT    │                                                                                   │
└──────────────────┴───────────────────────────────────────────────────────────────────────────────────┘
```

### 8.4 Structure Editor: drop table

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [ Matrix ] [▶Table ] [ Bundles ]   Filter: [All rooms ▾][All media ▾][☐ Unconnected only]  ⚙Columns  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ⠿☐│Label      │TIA-606│Location    │Outlet│Media │Service   │Bundle    │Rack term. │Status  │Conn. to│
│ ──┼───────────┼───────┼────────────┼──────┼──────┼──────────┼──────────┼───────────┼────────┼────────│
│ ▾ LIVING ROOM (LR)                                                             9 drops · 6 connected │
│ ⠿☐│LR-TV-1    │1A-A01 │Living Room │ WP-1 │Cat6  │HDBaseT   │LR-TV-1   │Coil (unterm)│Pulled│ —      │
│ ⠿☐│LR-DATA-1  │1A-A02 │Living Room │ WP-1 │Cat6  │Ethernet  │LR-TV-1   │PP-1 R01   │In use  │PP-1 R01│
│ ⠿☐│LR-DATA-2  │1A-A03 │Living Room │ WP-1 │Cat6  │Ethernet  │LR-TV-1   │PP-1 R02   │In use  │PP-1 R02│
│ ⠿☐│LR-CATV-1  │1A-F01 │Living Room │ WP-1 │RG6   │CATV/TV   │LR-TV-1   │F barrel   │In use  │SPL-1 O2│
│ ⠿☐│LR-CATV-2  │1A-F02 │Living Room │ WP-1 │RG6   │Undeterm. │LR-TV-1   │Coil       │Pulled  │ —      │
│ ⠿☐│LR-SPK-1   │1A-S01 │Living Room │ CLG  │16/4  │Speaker   │LR-AUD-1  │Euroblock  │Terminat│AMP-1 Z1│
│ ⠿☐│LR-SPK-2   │1A-S02 │Living Room │ CLG  │16/4  │Speaker   │LR-AUD-1  │Euroblock  │Terminat│AMP-1 Z2│
│ ⠿☐│LR-KEY-1   │1A-C01 │Living Room │ WP-2 │22/4  │Keypad    │LR-AUD-1  │Euroblock  │In use  │CTL-1 N1│
│ ⠿☐│LR-DATA-3  │1A-A04 │Living Room │ WP-2 │Cat6  │Undeterm. │—         │Coil       │Pulled  │ —      │
│ ▸ KITCHEN (KIT)                                                                5 drops · 4 connected │
│ ▸ OFFICE (OFF)                                                                 7 drops · 5 connected │
│ ▸ EXTERIOR (EXT)                                                               6 drops · 6 connected │
│ ▸ ATTIC (ATT)                                                                  3 drops · 3 connected │
├──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 52 drops · 41 connected · 11 spare  ·  10 bundles  ·  ▲ 1 duplicate label with STR-2                 │
│ [ Group into bundle ]  [ Renumber… ]  [ Assign to panel… ]  [ Export pull list CSV ]                 │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 8.5 Structure Editor: how it renders in the diagram

```
        STR-1  Media Panel — Garage
        ┌ LIVING ROOM ────────────────────────────────┐
        │  ▷ LR-DATA-1 ═══╗                           │            ┌──────────────┐
        │  ▷ LR-DATA-2 ═══╣  bundle LR-TV-1  ══════╗  │            │  PP-1        │
        │  ▷ LR-CATV-1 ───╢                       ║  │            │  Patch 24    │
        │  ▷ 2 spare  [+] ╝                       ║  │            └──────────────┘
        │  ▷ LR-SPK-1 ┄┄┄┄╗                       ║
        │  ▷ LR-SPK-2 ┄┄┄┄╣  bundle LR-AUD-1 ┄┄┄╗ ║
        │  ▷ LR-KEY-1 ····╝                     ║ ║
        └─────────────────────────────────────────╫─╫──────────────
        ┌ KITCHEN ───────────────────────────────╫─╫──┐
        │  ▷ KIT-DATA-1 ══╗ bundle KIT-TV-1 ═════╬═╝  │
        │  ▷ KIT-CATV-1 ──╝                      ║    │
        │  ▷ 1 spare  [+]                        ║    │
        └────────────────────────────────────────╫────┘
        ┌ EXTERIOR ──────────────────────────────╫────┐
        │  ▷ EXT-CAM-1..6  ══⟨6⟩══ bundle EXT-1 ═╝    │
        └─────────────────────────────────────────────┘

        ═ network   ─ RF/coax   ┄ speaker   · control      ▷ off-page connector flag
        [+] expands the collapsed spare-drop summary
```

### 8.6 Template Update Manager

See §5.3, the wireframe there is the shipping design.

---

## 9. Open Decisions Flagged for the Build

1. **Panel layout manual editor**: recommended for v1 *only if* the auto-layout engine lands early. It has no downstream dependents, so it is the safest thing to cut.
2. **Template signing**: the `signature` field is reserved but unimplemented. Templates are inert JSON with no executable content, so the risk is impersonation, not code execution. Defer.
3. **Media type table extensibility**: the Structure editor lets users add media types freely. If a project-local media type later needs to become global, that is a library-promotion flow not designed here.
4. **`hostedHeightU`** is introduced in this spec (§1.3) and is not in the source research. It exists because a 4U-tall AVR on a 1U shelf needs 4U of clear space and nothing else in the occupancy model expresses that. Worth confirming against the rack-editor design before it hardens.
5. **Half-rack pairing on a shelf**: two half-rack devices sharing one 1U shelf is the most common real arrangement and needs a lateral-position field on the hosted relationship. Specified here as a device-builder concern only (`widthClass`); the placement UI belongs to the rack editor spec.