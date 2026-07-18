# The Structure Device

The Structure device is RackMate's answer to brief requirement 6: a first-class representation of the structured wiring — the home runs — that arrive at the rack from the rest of the building. This document states what structured wiring is and how it physically reaches a rack, defines the `StructureBody` entity and the ways it deliberately differs from an ordinary `DeviceInstance`, specifies the dedicated editor that replaces the port-by-port device builder for this one case, gives the CSV import contract in full, and traces a home run from the matrix cell that created it through the schematic and into the exported sheet set. It cross-references [Data model](02-data-model.md) for entity definitions rather than restating them, and cites the governing ruling ID (`CR-nnn`, `AC-nnn`, `RJ-nnn`) for every decision; the adjudications themselves are in [the canonical decision record](canonical-decisions.md), which is normative — [10-decisions](10-decisions.md) is its short-form ADR summary.

---

## 1. What structured wiring is, and how it actually arrives

ANSI/TIA-570-D (July 2018) specifies residential telecommunications infrastructure as a **star / home-run topology**: every cabled outlet location runs back unbroken to a central **Distribution Device**. No daisy chains. That single architectural fact is what the Structure device models — not a piece of equipment, but the boundary at which N unbroken runs from elsewhere in the building present themselves at the rack.

The standard defines grades as a minimum media count per outlet location:

| Grade | Balanced twisted pair | Coax (75 Ω) | Fibre |
|---|---|---|---|
| Grade 1 | 1 × Cat6A or better | 1 | optional |
| Grade 2 | 2 × Cat6A or better | 2 | optional (2-fibre) |
| Grade 3 | 2 × Cat6 or better | 1 | **required** (2-fibre) |

Grade 2 — two Cat6/6A plus two RG6 per TV location — is the canonical residential outlet and ships as a seeded preset. But grades are **not** the primary specification axis in RackMate (CR-108): essentially no CI integrator speaks in grades — the residential integrator this screen is built for **does not speak TIA-570-D and does not want to be asked** (AC-034/m23, confirmed by DR-002 — residential is the primary market). They say "two Cat6 and two RG6 to every TV, one Cat6 per AP, 16/4 to every speaker pair." The first-class object is therefore the user-defined `OutletTemplate` ("TV location", "AP", "Keypad", "Ceiling speaker pair", "Camera", "Data only"), with the TIA-570-D grades shipped as three more presets and `Outlet.tia570Grade: String?` retained as a standards **tag** for specifications that cite one. Rejected alternative: `StructureGrade{grade1, grade2, grade3, custom}` as a modelled enum with `custom` as the escape hatch, which had the relationship backwards.

Physically, the runs land in one of two places. In mid-market work they terminate in a **Structured Media Center** — a recessed in-wall enclosure (14″, 21″, 28″, 42″) with module bays, not rack units. In the work RackMate targets, the SMC is replaced or supplemented by a real rack and the home runs land on **rack-mounted patch panels**, F-barrel bulkheads, punch-down blocks, Euroblocks and binding posts. Three drawing conventions are in use for representing this, and RackMate implements two of them simultaneously: an **off-rack field-infrastructure block** at the drawing boundary (the Structure device itself) whose individual runs resolve onto **real patch-panel ports inside the rack** (the port-to-drop map). J-STD-710 supplies a sanctioned "Demarcation for All Services" symbol for the former.

Two timing facts shape everything downstream. The pull happens at framing stage, weeks or months before the equipment list exists — which is why an endpoint may be unbound (AC-018) and why `structure.undetermined` is a legal signal family. Termination and certification happen after drywall — which is why `RoughInStatus{planned, pulled, dressed, terminated, tested}` and `TestResult` are real fields and not decoration (RJ-004).

---

## 2. The Structure device concept

A rack device is *a thing with ports*. The Structure device is *a list of home runs organised by room*. Its natural entry axis is **room × media × quantity**, not port-by-port; forcing 62 runs through the device builder's port grid one bank at a time is a category error. Hence a dedicated editor (§4) and a dedicated body type.

`StructureBody` is the body of a `DeviceInstance` with `kind == structure`. It differs from an ordinary device in seven concrete ways:

| # | Ordinary `DeviceInstance` | Structure |
|---|---|---|
| 1 | Placed in a rack from the palette | **Not in the rack palette at all** (CR-110). Created from `Project ▸ Structured wiring…`, or implicitly on first use of the Structure editor. Rejected: a palette entry that could be dragged but never dropped. |
| 2 | Occupies RU, has weight, depth, power | Zero RU, zero weight, `mountMethod: notInRack`. Renders in the rack elevation **not at all**. |
| 3 | Ports come from a `TemplateSnapshot` | No template. Its "ports" are a **rendering of home-run field endpoints** (AC-019) — see §3. |
| 4 | Symbol is a rectangle with pins | An **edge bank of off-page connector flags** at the sheet boundary, grouped by room (§6). |
| 5 | One instance per physical box | Multiple instances are normal and encouraged (CR-113, §7). |
| 6 | Designator prefix from the catalog | `STR` is reserved system-wide; the catalog's streaming source was renamed `STRM` to clear the collision (CR-043). A CI test asserts no catalog template shares a `typePrefix` with a system prefix. |
| 7 | Deleting it deletes its ports | Deleting it must reckon with `Link`s that are real cables — the delete command offers *unbind and keep the cables* or *delete the cables too*, and writes a `Tombstone` either way (CR-095). |

A Structure with zero drops is valid and shows an empty state pointing at the three entry paths: matrix, command line, CSV import.

---

## 3. Data model

Full definitions live in [Data model](02-data-model.md) §5.7; this section states only what is specific to Structure and the reasoning attached to it.

**A home run is a `Link`. There is no drop entity.** `StructureDrop` is deleted (CR-107, AC-019) and the word is banned ([canon §4.7](canonical-decisions.md#47-banned-names)). The prior design modelled one physical cable twice — a `StructureDrop` carrying `media`, `jacket`, `gaugeAwg`, `actualLength`, `status`, `test` *and* a `Link` carrying `media`, `jacket`, `gaugeAwg`, `calculatedLength`, `status`, `test` — which is guaranteed to diverge within a week of real use and is precisely the failure that makes people stop trusting the document. One cable, one row, one length, one certificate, one status.

A home run is therefore: a `Link` whose field end is a `PlaceEndpoint` (or, once the field device exists, a `PortEndpoint`), whose rack end is a `PortEndpoint` or an `OpenEndpoint`, and which carries `StructureOrigin{structureBodyId, outletId, fieldLabel, rackLabel, wall?, mountSurface?, mountHeightAff?, terminationField}`. `Link.linkClass` is `fieldCable`, so it is on the Pull Sheet by default (AC-026). It carries `List<Service>`, because one Cat5e to a TV location routinely carries an IR run, a 12 V trigger and RS-232 on separate pairs (CR-010, AC-021).

**"Bundle" is two entities and names neither of them** (CR-016). This is the single most important naming ruling in this document:

| Trade word | Canonical entity | What it is |
|---|---|---|
| "bundle", as in *the four cables to the TV wall* | **`Outlet`** (UI: "outlet location") | One wall plate or one ceiling location. The atom of creation, specification and pricing. Owns designation, location, wall/mount surface, height AFF, `outletTemplateId`, `tia570Grade`. Its members are `Link`s, joined by `Link.structureOrigin.outletId`. Renamed from `StructureBundle`; rejected alternative was demoting it to a bare grouping (RJ-011). |
| "bundle", as in *the snake through that conduit* | **`Pathway`** (UI may say "bundle") | A conduit, J-hook run, tray, riser or trunk that N `Link`s share, joined by `Link.pathwayId`. Purely organisational: it affects drawing (one trunk that fans out) and schedule grouping, **never connectivity**. Carries `kind` and `containsLineVoltage`, which `CODE-001` and `CODE-002` read (AC-027). |

The bare word `Bundle` appears nowhere in code, JSON, or prose.

**Rooms are not owned here.** The location tree is an arbitrary-depth `Location` hierarchy (site ▸ building ▸ floor ▸ room ▸ zone ▸ outdoor) edited from a **project-level** `Project ▸ Locations…` panel, not from the Structure editor (CR-047, CR-112). A project with racks and no Structure device must still be able to say which room a rack is in. `Outlet` is *not* a location level. Each `Location` carries `code` — never `abbr` (CR-046) — and `estimatedRunLengthFromRack: Len?`, one number per room that seeds every home run in that room with a per-link override (AC-024).

**Conduit is not a cable.** A media type with `MediaTypeDef.isPathwayOnly == true` (`media.conduit_emt`, `media.conduit_ent`, `media.pull_string`) creates a `Pathway`, never a `Link` and never a `Port` (CR-109). It appears in the drop table and on the Pull Sheet — you still pull the smurf tube and it still costs money — and never appears in the netlist. Rejected alternative: conduit as a connectable drop like any other, which produces a port you can wire an HDMI cable into.

**`Outlet.roughInStatus` is derived as the minimum across its member Links, and is not serialized** (CR-111, CR-115). An outlet is as complete as its least-complete run; a maximum would report an outlet "tested" while three of its four cables are still coiled in the attic.

**Media types are user-extensible in v1.** An unmatched media value in a CSV import creates a new `MediaTypeDef` with a confirmation chip rather than rejecting the row; a small media-type editor ships to support it (RJ-012). Signal families and connector types remain catalog-updated.

---

## 4. The Structure editor

The editor **opens in table mode**; the room × media matrix is a tab beside it (AC-048, cliff #4). Rejected alternative: matrix-first, which is the fastest surface for a user who already has a pull list and the most confusing one for a user who has three drops and no idea what the grid is asking.

```
┌───────────────────────────────────────────────────────────────────────────────────────────────┐
│ Structure  STR-1 · "Media Panel — Garage"    52 drops · 41 connected · 11 spare   [⋯] [Done]  │
│ [▶ Table] [ Matrix ] [ Outlets ] [ Pathways ]   Labels: [Residential CI ▾] [TIA-606 Cl.2 ▾]   │
├────────────────────┬──────────────────────────────────────────────────────────────────────────┤
│ ── LOCATIONS ──    │ Quick add ⌨ [ Living Room: 4x Cat6, 2x RG6, 2x 16/4 @outlet=WP-1    ]▸  │
│  (read-only here;  │ Filter: [All rooms ▾] [All media ▾] [☐ Unconnected only]      ⚙ Columns │
│   edit in Project  ├──────────────────────────────────────────────────────────────────────────┤
│   ▸ Locations…)    │ ⠿☐│FIELD LABEL│RACK LBL│OUTLET│MEDIA│SERVICE  │PATHWAY │RACK TERM │ROUGH-IN│
│                    │ ──┼───────────┼────────┼──────┼─────┼─────────┼────────┼──────────┼───────│
│ ▾ 123 Oak St       │ ▾ LIVING ROOM (LR) · est. run 62 ft         9 drops · 6 connected        │
│   ▾ Level 1        │ ⠿☐│LR-TV-1    │1A-A01  │ WP-1 │Cat6 │HDBaseT  │PW-LR-1 │coil      │pulled │
│     Living Room LR │ ⠿☐│LR-DATA-1  │1A-A02  │ WP-1 │Cat6 │Ethernet │PW-LR-1 │PP-1 R01  │tested │
│     Kitchen    KIT │ ⠿☐│LR-DATA-2  │1A-A03  │ WP-1 │Cat6 │Ethernet │PW-LR-1 │PP-1 R02  │tested │
│     Office     OFF │ ⠿☐│LR-CATV-1  │1A-F01  │ WP-1 │RG6  │CATV     │PW-LR-1 │F barrel  │termin.│
│     Patio      PAT │ ⠿☐│LR-CATV-2  │1A-F02  │ WP-1 │RG6  │undeterm.│PW-LR-1 │—         │pulled │
│   ▾ Level 2        │ ⠿☐│LR-SPK-1   │1A-S01  │ CLG  │16/4 │Speaker  │PW-LR-2 │Euroblock │termin.│
│     Primary   MBR  │ ⠿☐│LR-SPK-2   │1A-S02  │ CLG  │16/4 │Speaker  │PW-LR-2 │Euroblock │termin.│
│     Bedroom 2 BR2  │ ⠿☐│LR-KEY-1   │1A-C01  │ WP-2 │22/4 │Keypad   │PW-LR-2 │Euroblock │tested │
│   ▾ Other          │ ⠿☐│LR-DATA-3  │1A-A04  │ WP-2 │Cat6 │undeterm.│—       │—         │pulled │
│     Attic     ATT  │ ▸ KITCHEN (KIT) · est. 48 ft                 5 drops · 4 connected        │
│     Exterior  EXT  │ ▸ OFFICE (OFF) · est. 70 ft                  7 drops · 5 connected        │
│                    │ ▸ EXTERIOR (EXT) · est. 120 ft               6 drops · 6 connected        │
├────────────────────┴──────────────────────────────────────────────────────────────────────────┤
│ 52 drops · 41 connected · 11 spare · 9 outlets · 8 pathways · ▲ 1 label collides with STR-2    │
│ [+ Add drop] [+ Add outlet ▾] [Group into pathway] [Renumber…] [Import CSV…] [Export CSV]      │
└───────────────────────────────────────────────────────────────────────────────────────────────┘
```

Four regions. **Left** is the location tree, shown read-only with an inline "edit in `Project ▸ Locations…`" affordance — it is a view of the project vocabulary, not an editor for it (CR-112). **Top** is the dual-mode bulk entry bar. **Centre** is the drop table, grouped by room with a sticky group header carrying the room `code`, the estimated run length, and the drop/connected counts. **Right** (collapsed in the wireframe) is the inspector and batch inspector, with the same ergonomics as the device builder's — see [Device builder](06-device-builder.md).

### 4.1 Table columns

Default columns are the ones a person needs to answer "what am I pulling and where does it land": field label, rack label, outlet, media, service, pathway, rack termination, rough-in status. **Optional columns**, off by default, added from `⚙ Columns`: jacket rating, jacket colour, conduit, `routedLength` / `cutLength` / `terminatedLength`, field termination, test result and certificate ID, installed by, notes, and any `unknown`-map columns preserved from a CSV import. Jacket colour and conduit were demoted from default to optional and reel ID was cut entirely (RJ-004).

Grid operations are the device builder's, unchanged: fill-down, fill-series, multi-row edit, duplicate, delete, reorder, find/replace, TSV copy-paste, renumber. Inline editing is the primary path — a cell is one click and a keystroke, and every edit is a `Command` on the undo stack.

`Service: undetermined` is a first-class, encouraged state backed by the `structure.undetermined` signal family (canon §6.4). At rough-in a Cat6 is just a Cat6. It schedules, it prints, it gets a `W` number and both labels, and the DRC validates **retroactively** when a `Service` later assigns a real family — an HDBaseT run patched into a switch throws the error it should, when it should.

### 4.2 Bulk entry — matrix mode

Rooms down, media across, integer spinners at the intersections. Changing a cell from 0 to 2 materialises two `Link`s with generated labels in one command; decrementing it deletes the two highest-sequence unconnected drops in that cell and refuses (with a spring-back chip, CR-017) to delete a connected one.

```
                Cat6  Cat6a  RG6  RG6q  16/2  16/4  22/4  OS2  EMT     Σ   Outlets
 ──────────────────────────────────────────────────────────────────────────────────
 Living Room     [4]   [0]   [2]   [0]   [0]   [2]   [1]  [0]  [0]     9      2
 Kitchen         [2]   [0]   [1]   [0]   [0]   [1]   [1]  [0]  [0]     5      1
 Office          [4]   [0]   [1]   [0]   [0]   [0]   [1]  [0]  [1]     7      1
 Primary Bdrm    [2]   [0]   [2]   [0]   [0]   [1]   [1]  [0]  [0]     6      2
 Attic           [3]   [0]   [0]   [0]   [0]   [0]   [0]  [0]  [0]     3      0
 Exterior        [6]   [0]   [0]   [0]   [0]   [0]   [0]  [0]  [0]     6      1
 ──────────────────────────────────────────────────────────────────────────────────
 TOTAL           28     0     9     0     0     8     4    1    1     52
                                                    [ + Media column ]  [ + Room ]
```

The `EMT` column is `isPathwayOnly` and creates `Pathway`s, not drops — its cells are tinted and excluded from the Σ drop count (CR-109). Media columns are user-configurable; `+ Media column` opens the media-type picker with an inline "create new type" row.

### 4.3 Bulk entry — command mode and outlet templates

One text line, the same DSL family as the device builder's Quick Add:

```text
Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4
Attic: 3x Cat6 @service=wifi-ap
Exterior: 6x Cat6 @service=camera @status=planned
Kitchen: 2x Cat6 + 1x RG6 @outlet="KIT-TV-1"
```

`@outlet="…"` creates or joins one `Outlet` — note that this is the *outlet* sense of "bundle", not the pathway sense (CR-016); the DSL uses the canonical word. `@pathway="…"` is the conduit sense.

`+ Add outlet ▾` instantiates an `OutletTemplate` in one action — *TV location* → 2 × Cat6 + 2 × RG6 as one `Outlet` with four `Link`s and four label pairs. Seeded templates: **TV location · AP · Keypad · Ceiling speaker pair · Camera · Data only**, plus **TIA-570-D Grade 1 / 2 / 3** (CR-108). The grades stay **presets and a standards tag, never an axis** — the integrator does not speak TIA-570-D and is never asked to (AC-034/m23, DR-002). Which location fields the inspector demands is driven by the template: a ceiling speaker pair asks for `mountSurface: ceiling` and never for a wall compass direction (AC-034/m24).

---

## 5. CSV import

CSV import is not a convenience feature; it is the **entry path** for the February workflow — the contractor's pull list arrives as a spreadsheet before the equipment list exists. Cutting it while accepting AC-018 would be incoherent, so it ships in v1 (RJ-004).

Two shapes are accepted and auto-detected. **Long**: one row per drop. **Wide**: rooms as rows, media as numeric columns, which is how pull lists actually look. Wide mode is offered when ≥ 2 headers resolve to media synonyms *and* their cells are numeric.

### 5.1 Columns

Header matching is case-, space-, underscore- and hyphen-insensitive. Every source header appears in a **column-mapping sheet** with RackMate's guess and a dropdown to correct it. Unmapped columns are preserved into the row's `unknown` map and surfaced as optional grid columns — user data is never discarded (canon §4.2, forward-compat).

| Canonical target | Accepted headers | Req. |
|---|---|---|
| `location` → `Location` | `location`, `room`, `area`, `zone`, `space`, `destination` | ✔ |
| `floor` | `floor`, `level`, `story` | |
| `building` | `building`, `site` | |
| `outlet` → `Outlet.designation` | `outlet`, `plate`, `jack`, `wallplate`, `wall_plate_id`, `box` | |
| `fieldLabel` | `label`, `identifier`, `tag`, `cable_label`, `drop_id`, `cable_id`, `run_id`, `#` | |
| `rackLabel` | `tia_id`, `tia606`, `rack_label`, `panel_id` | |
| `media` → `MediaTypeId` | `media`, `cable_type`, `type`, `wire`, `cable` | ✔ (long) |
| `qty` | `qty`, `quantity`, `count`, `ea`, `number` | |
| `service` → `SignalFamilyId` | `service`, `use`, `purpose`, `signal`, `function`, `application` | |
| `pathway` → `Pathway.name` | `bundle`, `bundle_id`, `run`, `group`, `home_run`, `conduit`, `raceway`, `pathway` | |
| `routedLength` | `length`, `length_ft`, `footage`, `ft`, `len` | |
| `terminationRack` | `termination_rack`, `rack_end`, `panel`, `panel_port`, `head_end` | |
| `terminationField` | `termination_field`, `device_end`, `field_end`, `far_end` | |
| `roughInStatus` | `status`, `state`, `phase` | |
| `jacket` / `jacketColor` | `jacket`, `color`, `colour`, `jacket_color` | |
| `notes` | `notes`, `comments`, `remarks`, `note` | |

Media synonyms ship as data and are extensible:

```text
cat6 / cat-6 / c6 / cat6 utp            → media.cat6
cat6a / c6a / f/utp                     → media.cat6a_futp
cat5e / c5e / cat5                      → media.cat5e
rg6 / rg-6 / coax                       → media.rg6
rg6q / quad shield                      → media.rg6_quad
16/2 / 16-2 / spkr 16/2                 → media.16_2
16/4 / 16-4                             → media.16_4
14/2 / 14-2                             → media.14_2
14/4 / 14-4                             → media.14_4
22/4 / control / keypad                 → media.22_4
22/2                                    → media.22_2
os2 / smf / single mode                 → media.os2
conduit / smurf / ent                   → media.conduit_ent   (isPathwayOnly)
```

14 AWG gets its own targets rather than folding onto the 16 AWG ones: mapping `14/4` to a 16 AWG media type changes the gauge and the footage rollup, and `media.14_2` / `media.14_4` exist in the registry precisely so it does not have to.

Every target above resolves in `assets/catalog/registries.json`; a CI assertion enforces it for every `media.*`, `conn.*` and signal-family ID appearing in any document (N1, seed-devices C2). RJ-012 makes an unmatched value create a new type rather than fail, so a wrong target here is a silent data-quality failure, not a loud one. An unmatched value creates a new media type with a confirmation chip; it is never a rejected row.

### 5.2 Example

```text
Room,Outlet,Cable Type,Qty,Use,Bundle,Length (ft),Panel Port,Status,Notes
Living Room,WP-1,Cat6,2,Ethernet,LR-TV,62,PP-1 R01,pulled,
Living Room,WP-1,Cat6,1,HDBaseT,LR-TV,62,,pulled,to TV — matrix TBD
Living Room,WP-1,RG6,2,CATV,LR-TV,62,F barrel,pulled,
Living Room,CLG,16/4,2,Speaker,LR-AUD,48,,pulled,ceiling pair
Attic,AP-1,Cat6,1,Ethernet,,88,PP-1 R14,terminated,AP over hall
Exterior,CAM-1..6,Cat6,6,Camera,EXT-1,120,PP-2 R01,planned,soffit
Office,,ENT 3/4",1,,,,,planned,pull string only
```

Row 2 imports as three `Link`s (`qty` 2 plus the HDBaseT row) sharing one `Outlet` `WP-1`; row 3's blank `Panel Port` becomes an `OpenEndpoint` at the rack end, which still schedules and still gets a `W` number (AC-018). The last row's `isPathwayOnly` media creates a `Pathway`, not a drop (CR-109).

### 5.3 Matching, dedup and re-import

Import is **never fail-fast**. A preview grid shows the parsed result with per-row validation before commit, and the whole import is one undoable `Command`.

1. **Location match** is by `Location.name` then `Location.code`, case- and whitespace-insensitive, within the Structure's location scope. No match offers "create room" inline, pre-filled with a derived `code`.
2. **Outlet match** is `(locationId, designation)`. Rows sharing both join one `Outlet`.
3. **Pathway match** is by `Pathway.name`, project-wide.
4. **Drop dedup** is by `fieldLabel` when the file supplies one, otherwise by the tuple `(locationId, outletDesignation, mediaTypeId, ordinal-within-group)`. A matched row **updates** the existing `Link` field-by-field, never duplicates it; unmatched rows are created. Re-importing a corrected spreadsheet is therefore idempotent, which is the whole point — the pull list gets revised three times before drywall.
5. **Update guard.** An import that would modify an existing `Link` shows an explicit import-over-existing confirmation listing the counts (`create 14 · update 38 · unchanged 9`), and never overwrites a field the user has edited in-app unless the CSV supplies a non-empty differing value. It never touches `designator` on a `Link` whose `designatorLocked` is set (CR-034, AC-034/m22).
6. **Duplicate labels are flagged, not blocked** — a `warning` with a one-click "renumber the later one", consistent with the ban on heuristics holding a deliverable hostage (G3).
7. **Hardening.** Every import path enforces size and field-count limits (AC-058/D8), and progress with cancel is shown for any import over ~500 ms (AC-058/D14).

`Export CSV` emits the long shape with every canonical column plus preserved `unknown` columns, so export → edit in Excel → re-import is a supported round trip.

---

## 6. Rendering: drops as flags, grouped by room

The Structure device **never renders as a rectangle with 62 pins.** Its ports are a *rendering of home-run field endpoints* (AC-019), drawn as an edge bank of off-page connector flags — the schematic convention for signals entering from elsewhere, and the J-STD-710 "Demarcation for All Services" idiom. Detailed drawing rules are in [Schematic editor](05-schematic-editor.md); this section states what is Structure-specific.

```
     STR-1  Media Panel — Garage
     ┌ LIVING ROOM (LR) ───────────────────────────┐
     │  ▷ LR-DATA-1 ═══╗                           │           ┌──────────────┐
     │  ▷ LR-DATA-2 ═══╣  pathway PW-LR-1  ═════╗  │           │  PP-1        │
     │  ▷ LR-CATV-1 ───╢                        ║  │           │  Patch 24    │
     │  ▷ 2 spare  [+] ╝                        ║  │           └──────────────┘
     │  ▷ LR-SPK-1 ┄┄┄┄╗                        ║
     │  ▷ LR-SPK-2 ┄┄┄┄╣  pathway PW-LR-2 ┄┄┄╗  ║
     │  ▷ LR-KEY-1 ····╝                     ║  ║
     └───────────────────────────────────────╫──╫───────────────
     ┌ KITCHEN (KIT) ────────────────────────╫──╫──┐
     │  ▷ KIT-DATA-1 ══╗ pathway PW-KIT-1 ═══╬══╝  │
     │  ▷ KIT-CATV-1 ──╝                     ║     │
     │  ▷ 1 spare  [+]                       ║     │
     └───────────────────────────────────────╫─────┘
     ┌ EXTERIOR (EXT) ───────────────────────╫─────┐
     │  ▷ EXT-CAM-1..6 ══⟨6⟩══ pathway EXT-1 ╝     │
     └─────────────────────────────────────────────┘

     ═ network   ─ RF/coax   ┄ speaker   · control    ▷ off-page flag   [+] expand spares
```

Five layered mechanisms keep this readable past 60 drops:

| # | Mechanism | Effect |
|---|---|---|
| 1 | **Off-page connector flags** | One pennant glyph per home run, tagged with its label. Never a pin on a box. |
| 2 | **Room grouping with headers** | Flags grouped under a rule bearing the room name and `Location.code`; group order follows the location tree. |
| 3 | **Unused collapse** (default on) | Only *connected* runs render individually. Unconnected ones collapse per room into one summary flag — `Living Room · 3 spare (2× Cat6, 1× RG6)` — expandable in place. This also produces the **Unused Home Runs** page (§9). |
| 4 | **Pathway trunks** | A `Pathway` draws as one thick trunk from the boundary toward the rack, fanning to individual ports only at the destination. Six runs become one line for 90% of their length. This is the whole visual payoff of CR-016's `Pathway`. |
| 5 | **Net labels by default** | A run renders *named*, not *drawn*: a flag at the Structure and a matching flag at the destination port, with the label as the join. Duplicate *source* names prohibited, duplicate *destination* names permitted (CR-049). |

Plus room-level isolate/filter in both the editor and the schematic. Mechanism 5 is no longer conditional — canon open question 10.1 is answered:

> Render mode is a function of the active filter. Unfiltered sheet ⇒ `netLabels`: every `Link` is two labelled stubs, one at each pin, with no polyline between them. Filtered to exactly one `SignalDomainId`, or `Alt`-hover, or focus/isolate ⇒ `drawn`: every `Link` in scope is an orthogonal polyline with a tag pill at each end. `SheetRenderMode` is **derived**, never persisted, never a setting (DR-001, canon §11.1.1).

There is no density threshold that switches rendering, and nothing "degrades" — the mode follows the filter, not the drop count. **The Structure device's flags were always a label rendering; DR-001 changes nothing here.** What DR-001 does change is that the *rest* of the sheet now matches the idiom the Structure device already used, so the boundary between the flag bank and the rack side stops being a change of visual language.

Automatic **sheet paging by room group** is **never built** (DR-004): there is permanently exactly one schematic `Sheet`, and room grouping is served by filtering it. The *exporter* separately partitions that one `Sheet` by domain and emits N interconnect sheets `T6.01…` (CR-073, unaffected by DR-004) — partitioning at export is not multi-sheet authoring. A domain partition produces zero cross-sheet connections by construction, so no match lines, off-sheet connectors or sheet-boundary link handling are built at all.

---

## 7. Multiple Structure devices

Multiple instances ship (CR-113). A rack fed from a garage media panel *plus* a separate exterior/camera panel *plus* a utility/service entrance is a normal residential job, and one monolithic node is less useful than three named ones. Rejected alternative: an implicit singleton, which would have made `structureBodyId` unnecessary and the exterior-panel case unrepresentable.

Rules:

1. Each instance has its own name, designator (`STR-1`, `STR-2`, …), location scope, and label preset pair.
2. `StructureBody.sheetEdge: left | right`, default `left` (CR-072). Every `left` Structure lands on schematic layer 0, every `right` one on layer N — a service-entrance structure drawn on the opposite side from the home-run field is legitimate and common. Rejected alternative: forcing "the Structure device" (singular) to layer 0.
3. **`fieldLabel` uniqueness is project-wide across all Structures**, not per-instance. Labels get printed on physical cable and must not collide across panels. `rackLabel` is likewise project-unique when set.
4. A room may appear under more than one Structure — a bedroom with data from the media panel and a camera from the exterior panel. The location tree is shared; the drops are not.

---

## 8. Labelling

**Every home run carries two labels, and both always print** (CR-044). The field voice calls this "the single most valuable line in these four documents"; it costs one nullable string and one column, and cutting it was rejected (RJ-004). `fieldLabel` is required and project-unique; `rackLabel` is optional and project-unique when set. Both are generated from templates, both are editable, both appear on both ends of every schedule row (AC-025). The insight was originally applied only to Structure drops; it now applies to every cable in the project.

There is no residential labelling standard. TIA-606-C assumes floors, telecom spaces and patch panels; a house has one rack and rooms with names. TIA-606's horizontal-link identifier is literally `<floor><space>-<panel><port>` — `1A-A12` — and the standard is explicit that **the format is not mandated, only that it be consistent and unique**. That is why RackMate ships an identifier format engine rather than hard-coded schemes.

One grammar, one registry, one parser, in `rackmate_core/idformat/`, shared by five call sites — device, port, link, outlet field label, outlet rack label (CR-045). Tokens are `UPPER_SNAKE`; `{TOKEN:n}` zero-pads; `[...]` marks an optional segment; `|upper`, `|first n`, `|nz` are filters; `{{` and `}}` are literal braces. Collisions resolve by a project-wide `CollisionPolicy{suffixLetter | suffixNumber | error}`.

**Two presets ship, not five** (CR-044, AC-046):

| Preset | Pattern | Output |
|---|---|---|
| **Residential CI** (default `fieldLabel`) | `{ROOM_ABBR}-{SERVICE}-{SEQ}` | `LR-TV-1`, `MBR-KEY-2`, `EXT-CAM-4` |
| **TIA-606 Class 2** (default `rackLabel`) | `{FLOOR}{SPACE}-{PANEL}{PORT:2}` | `1A-A12` |

Both are editable, and a project may write its own pattern from the token vocabulary (canon §4.5) — `{ROOM_ABBR}-{MEDIA}-{SEQ:2}` → `LR-CAT6-01` is a one-line change. **Every designator is evaluated once at creation and stored, never recomputed at render time** (CR-048). Changing a scheme offers a renumber with a diff; it never silently renumbers and it never touches a locked ID. `Link.designatorLocked` auto-sets at `roughInStatus >= pulled`, because once 60 cables are physically labelled an accidental renumber is a day of relabelling (AC-034/m22).

---

## 9. How drops reach the PDF

**There is no separate drop-schedule sheet.** The prior design's `T6.03 Structure / drop schedule` is superseded: because a home run *is* a `Link` (CR-107), it flows into the same two schedule presets as every other cable (AC-025). A dedicated drop schedule would have re-created the double-modelling that CR-107 deleted.

| Output | What home runs contribute | Ruling |
|---|---|---|
| **Pull Sheet** (`T6.10`, portrait) | Every `fieldCable`, sorted **room then pathway** — the order the tech walks the house. Per-room footage subtotals, jacket colour, both labels on both ends, and `Pulled ☐ Terminated ☐ Tested ☐ Init ___`. Pathway-only entries (conduit, pull string) appear here and nowhere else. | AC-025, AC-026, CR-109 |
| **Termination Schedule** (`T6.11`, landscape) | Every cable landing in the rack, sorted **rack, panel, port** — the port-to-drop map of §1. Adds T568A/B, punch position, polarity, and `Conductor.colorCode` per role. | AC-025 |
| **Unused Home Runs** (`T6.20`) | Home runs whose rack end is an `OpenEndpoint`, grouped by room. Emitted automatically whenever at least one exists. A deliverable integrators cannot get from anything else; the name is canonical and stays. | canon §4.3 |
| **Equipment List and Materials** (`T6.30`) | Cable footage rollup by media with a configurable waste factor — *"Cat6: 2,140 ft estimated + 10% = 2,354 ft → 3 boxes (1000 ft)"*. No pricing in v1. | AC-024, AC-055 |
| **Interconnect sheets** (`T6.01…`) | The flag banks of §6. N interconnect sheets, one per domain partition of the single schematic `Sheet`. Each partition is a domain filter, so these sheets render `drawn` rather than as net labels (DR-001). | CR-073 |

Both schedule presets carry location on **both** ends — `RK-1 / U14 / rear` and `Great Room / TV wall / WP-1` — never a schematic zone reference alone. Estimated lengths derived from `Location.estimatedRunLengthFromRack` render in italic and are tagged in the schedule so nobody bills off them (AC-024, G4); a null length makes `LEN-*` emit `advisory: length unknown, cannot verify` rather than passing silently. Unbound endpoints raise `LNK-020 advisory: N links have unbound endpoints` — a checklist, not an error, and never a gate on export (AC-018, CR-022, G3).

Full sheet order, furniture and table layout are in [PDF export](08-pdf-export.md). The set is a **client deliverable** and carries full drafting furniture — title block, revision block, revision clouds, issued-for-construction stamp, drawing border, zone references and sheet numbering (DR-005). Sheet furniture is orthogonal to wire idiom: the sheet is polished fully and the wires stay net-labelled (DR-001).

---

## 10. Scope and acceptance

Everything in this document is **v1**, delivered in milestone **M3 — Structure and the field** (canon §9.4), which also carries `PlaceEndpoint`/`OpenEndpoint` in the UI, the project-level Locations panel, the three length fields, and `Pathway`. The exit criterion is concrete and is the acceptance test for this document:

> A 60-drop whole-house rough-in is entered in under fifteen minutes, produces 60 `Link`s each with one `fieldLabel` and one `rackLabel`, and exports a Pull Sheet sorted by room and pathway with per-room footage subtotals and initial boxes. Fourteen of those drops have unbound far ends and every one of them still schedules, prints, and carries a `W` number. Requirement 6 is met.

One of the four starter projects authored as real `.rackmate` files exercises Structure end to end, doing triple duty as a golden, a perf fixture and a screenshot source (AC-052). Field devices — display, projector, in-ceiling speaker pair, camera, AP, keypad, ISP gateway/ONT, wall plate and the rest of the 18 `mountMethod: notInRack` templates — are what the field ends eventually bind to; see [Seed devices](catalog/seed-devices.md) and [Device builder](06-device-builder.md) for the stripped authoring form they use.

**Not in v1, and these are rulings rather than omissions:** a signal-family editor or a rule editor, though the media-type editor does ship (RJ-012); reel IDs (RJ-004); pricing on any Structure output (AC-055); and `.rmlib` library packs for sharing outlet templates between projects (AC-042). Outlet templates are per-installation library objects in v1.

**Never built, in any version:** automatic sheet paging by room group, and multi-sheet authoring generally (DR-004). There is permanently one schematic `Sheet`; room and domain grouping are served by filtering it and, at export, by the domain partition of CR-073. The `Sheet` entity stays in the schema (AC-037) so the file format never has to migrate if that is ever revisited.

---

**See also:** [Domain](01-domain.md) · [Data model](02-data-model.md) · [Schematic editor](05-schematic-editor.md) · [Device builder](06-device-builder.md) · [PDF export](08-pdf-export.md) · [Canonical decisions](canonical-decisions.md) · [Decisions (ADR log)](10-decisions.md) · [Testing and quality](11-testing-and-quality.md)
