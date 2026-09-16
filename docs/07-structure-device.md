# The Structure Device

The Structure device is RackPal's answer to brief requirement 6: a first-class representation of the structured wiring, the home runs, that arrive at the rack from the rest of the building. This document states what structured wiring is and how it physically reaches a rack, defines the `StructureBody` entity and the ways it deliberately differs from an ordinary `DeviceInstance`, specifies the dedicated editor that replaces the port-by-port device builder for this one case, gives the CSV import contract in full, and traces a home run from the matrix cell that created it through the schematic and into the exported sheet set. It cross-references [Data model](02-data-model.md) for entity definitions rather than restating them, and cites the governing ruling ID (`CR-nnn`, `AC-nnn`, `RJ-nnn`) for every decision; the adjudications themselves are in [the canonical decision record](canonical-decisions.md), which is normative, [10-decisions](10-decisions.md) is its short-form ADR summary.

---

## 1. What structured wiring is, and how it actually arrives

ANSI/TIA-570-D (July 2018) specifies residential telecommunications infrastructure as a **star / home-run topology**: every cabled outlet location runs back unbroken to a central **Distribution Device**. No daisy chains. That single architectural fact is what the Structure device models, not a piece of equipment, but the boundary at which N unbroken runs from elsewhere in the building present themselves at the rack. **The revision is stated rather than tracked** (DR-079 §11.78.5, and docs/01 §10 carries the retrieved-on date): the topology and the Distribution Device are revision-independent, so a later revision does not move this section.

The standard defines grades as a minimum media count per outlet location:

| Grade | Balanced twisted pair | Coax (75 Ω) | Fibre |
|---|---|---|---|
| Grade 1 | 1 × Cat6A or better | 1 | optional |
| Grade 2 | 2 × Cat6A or better | 2 | optional (2-fibre) |
| Grade 3 | 2 × Cat6 or better | 1 | **required** (2-fibre) |

Grade 2, two Cat6/6A plus two RG6 per TV location, is the canonical residential outlet and ships as a seeded preset. But grades are **not** the primary specification axis in RackPal (CR-108): essentially no CI integrator speaks in grades, the residential integrator this screen is built for **does not speak TIA-570-D and does not want to be asked** (AC-034/m23, confirmed by DR-002, residential is the primary market). They say "two Cat6 and two RG6 to every TV, one Cat6 per AP, 16/4 to every speaker pair." The first-class object is therefore the user-defined `OutletTemplate` ("TV location", "AP", "Keypad", "Ceiling speaker pair", "Camera", "Data only"), with the TIA-570-D grades shipped as three more presets and `Outlet.tia570Grade: String?` retained as a standards **tag** for specifications that cite one. Rejected alternative: `StructureGrade{grade1, grade2, grade3, custom}` as a modelled enum with `custom` as the escape hatch, which had the relationship backwards.

Physically, the runs land in one of two places. In mid-market work they terminate in a **Structured Media Center**: a recessed in-wall enclosure (14″, 21″, 28″, 42″) with module bays, not rack units. In the work RackPal targets, the SMC is replaced or supplemented by a real rack and the home runs land on **rack-mounted patch panels**, F-barrel bulkheads, punch-down blocks, Euroblocks and binding posts. Three drawing conventions are in use for representing this, and RackPal implements two of them simultaneously: an **off-rack field-infrastructure block** at the drawing boundary (the Structure device itself) whose individual runs resolve onto **real patch-panel ports inside the rack** (the port-to-drop map). J-STD-710 supplies a sanctioned "Demarcation for All Services" symbol for the former.

Two timing facts shape everything downstream. The pull happens at framing stage, weeks or months before the equipment list exists, which is why an endpoint may be unbound (AC-018) and why `structure.undetermined` is a legal signal family. Termination and certification happen after drywall, which is why `RoughInStatus{planned, pulled, dressed, terminated, tested}` and `TestResult` are real fields and not decoration (RJ-004).

---

## 2. The Structure device concept

A rack device is *a thing with ports*. The Structure device is *a list of home runs organised by room*. Its natural entry axis is **room × media × quantity**, not port-by-port; forcing 62 runs through the device builder's port grid one bank at a time is a category error. Hence a dedicated editor (§4) and a dedicated body type.

`StructureBody` is the body of a `DeviceInstance` with `kind == structure`. It differs from an ordinary device in seven concrete ways:

| # | Ordinary `DeviceInstance` | Structure |
|---|---|---|
| 1 | Placed in a rack from the palette | **Not in the rack palette at all** (CR-110). Created from `Project ▸ Structured wiring…`, or implicitly on first use of the Structure editor. Rejected: a palette entry that could be dragged but never dropped. |
| 2 | Occupies RU, has weight, depth, power | Zero RU, zero weight, `mountMethod: notInRack`. Renders in the rack elevation **not at all**. |
| 3 | Ports come from a `TemplateSnapshot` | No template. Its "ports" are a **rendering of home-run field endpoints** (AC-019), see §3. |
| 4 | Symbol is a rectangle with pins | An **edge bank of off-page connector flags** at the sheet boundary, grouped by room (§6). |
| 5 | One instance per physical box | Multiple instances are normal and encouraged (CR-113, §7). |
| 6 | Designator prefix from the catalog | `STR` is reserved system-wide; the catalog's streaming source was renamed `STRM` to clear the collision (CR-043). A CI test asserts no catalog template shares a `typePrefix` with a system prefix. |
| 7 | Deleting it deletes its ports | Deleting it must reckon with `Link`s that are real cables, the delete command offers *unbind and keep the cables* or *delete the cables too*, and writes a `Tombstone` either way (CR-095). |

A Structure with zero drops is valid and shows an empty state pointing at the three entry paths: matrix, command line, CSV import.

---

## 3. Data model

Full definitions live in [Data model](02-data-model.md) §5.7; this section states only what is specific to Structure and the reasoning attached to it.

**A home run is a `Link`. There is no drop entity.** `StructureDrop` is deleted (CR-107, AC-019) and the word is banned ([canon §4.7](canonical-decisions.md#47-banned-names)). The prior design modelled one physical cable twice (a `StructureDrop` carrying `media`, `jacket`, `gaugeAwg`, `actualLength`, `status`, `test` *and* a `Link` carrying `media`, `jacket`, `gaugeAwg`, `calculatedLength`, `status`, `test`) which is guaranteed to diverge within a week of real use and is precisely the failure that makes people stop trusting the document. One cable, one row, one length, one certificate, one status.

A home run is therefore: a `Link` whose field end is a `PlaceEndpoint` (or, once the field device exists, a `PortEndpoint`), whose rack end is a `PortEndpoint` or an `OpenEndpoint`, and which carries `StructureOrigin{structureBodyId, outletId?, boxless, fieldLabel, rackLabel, wall?, mountSurface?, mountHeightAff?, terminationField}`. `outletId` is nullable and `boxless` says why (DR-070): a ceiling speaker has no box, which is a statement, where a null alone would only mean nobody has said. `Link.linkClass` is `fieldCable`, so it is on the Pull Sheet by default (AC-026). It carries `List<Service>`, because one Cat5e to a TV location routinely carries an IR run, a 12 V trigger and RS-232 on separate pairs (CR-010, AC-021).

**"Bundle" is two entities and names neither of them** (CR-016). This is the single most important naming ruling in this document:

| Trade word | Canonical entity | What it is |
|---|---|---|
| "bundle", as in *the four cables to the TV wall* | **`Outlet`** (UI: "outlet location") | One wall plate or one ceiling location. The atom of creation, specification and pricing. Owns designation, location, wall/mount surface, height AFF, `outletTemplateId`, `tia570Grade`. Its members are `Link`s, joined by `Link.structureOrigin.outletId`. Renamed from `StructureBundle`; rejected alternative was demoting it to a bare grouping (RJ-011). |
| "bundle", as in *the snake through that conduit* | **`Pathway`** (UI may say "bundle") | A conduit, J-hook run, tray, riser or trunk that N `Link`s share, joined by `Link.pathwayId`. Purely organisational: it affects drawing (one trunk that fans out) and schedule grouping, **never connectivity**. Carries `kind` and `containsLineVoltage`, which `CODE-001` and `CODE-002` read (AC-027). |

The bare word `Bundle` appears nowhere in code, JSON, or prose.

**Rooms are not owned here.** The location tree is an arbitrary-depth `Location` hierarchy (site ▸ building ▸ floor ▸ room ▸ zone ▸ outdoor) edited from the **Site view**, the first tab, not from the Structure editor (CR-047, CR-112). A project with racks and no Structure device must still be able to say which room a rack is in. `Outlet` is *not* a location level. Each `Location` carries `code`, never `abbr` (CR-046), and `estimatedRunLengthFromRack: Len?`, one number per room that seeds every home run in that room with a per-link override (AC-024).

**Conduit is not a cable.** A media type with `MediaTypeDef.isPathwayOnly == true` (`media.conduit_emt`, `media.conduit_ent`, `media.pull_string`) creates a `Pathway`, never a `Link` and never a `Port` (CR-109). It appears in the drop table and on the Pull Sheet, you still pull the smurf tube and it still costs money, and never appears in the netlist. Rejected alternative: conduit as a connectable drop like any other, which produces a port you can wire an HDMI cable into.

**`Outlet.roughInStatus` is derived as the minimum across its member Links, and is not serialized** (CR-111, CR-115). An outlet is as complete as its least-complete run; a maximum would report an outlet "tested" while three of its four cables are still coiled in the attic.

**Media types are user-extensible in v1.** An unmatched media value in a CSV import creates a new `MediaTypeDef` with a confirmation chip rather than rejecting the row; a small media-type editor ships to support it (RJ-012). **Signal families are user-extensible BY CLONE** (DR-122): a new one is derived from a shipped family and never authored from blank, so it inherits every field a rule reads. Connector types remain catalog-updated.

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

Four regions. **Left** is the location tree, shown read-only with an inline "edit on the Site tab" affordance; it is a view of the project vocabulary, not an editor for it (CR-112). **Top** is the dual-mode bulk entry bar. **Centre** is the drop table, grouped by room with a sticky group header carrying the room `code`, the estimated run length, and the drop/connected counts. **Right** (collapsed in the wireframe) is the inspector and batch inspector, with the same ergonomics as the device builder's, see [Device builder](06-device-builder.md).

**The strip is three tabs and this wireframe draws four** (M3-E/1). `[▶ Table]`,
`[ Matrix ]` and `[ Pathways ]` are built; `[ Outlets ]` opens nothing, and a tab
that opens nothing is the `UnbuiltView` defect wearing a different hat. M3-C/2
therefore shipped with no strip at all, because AC-048 asks only that the editor
**open in table mode** and one surface satisfies that outright. The strip arrived
with the second thing to switch to, and `structure_editor_screen.dart` names the
one that is still absent beside the list it is absent from.

**The strip keeps this wireframe's order**, so the absent tab holds its place
rather than letting the built ones shuffle left: a strip that rearranged itself
as tabs arrive would move a target under the hand of anybody who had learned
where it was.

**`[ Pathways ]` is a list and an editor for what exists, and deliberately not a
routing surface.** There is no map, no assignment of runs to a conduit, and
`[Group into pathway]` is still absent from the button bar. That cap is the
user's own, stated on 2026-08-09: *"Pathway will likely be set in the plan view,
once a pathway is actually determined and set on site"*, which is DR-020 §11.19.1
applied to the entity rather than to its designator. Its eight columns are the
whole of `Pathway` minus the two location references; `KIND` and `LINE VOLTAGE`
are what M5's `CODE-001` and `CODE-002` read, and **no rule fires here** (canon
§5, G2, CR-017: a tier-2 rule built as a tier-1 refusal makes the product unable
to draw a mistake). The delete is not a cascade and its tooltip states the run
count before the click.

**`DESIGNATOR` is the tab's first and primary column, ahead of `PATHWAY`**
(M3-E/2, DR-026 §11.25.1, confirmed permanent by DR-037 §11.36.6). It is
hand-entered: no allocator, no series, no format token, because the route is
discovered rather than designed and a designator generated before anybody has
opened a ceiling records a guess. Identifiers lead in every other table here, and
the designator is what an installer matches against a label in a wall while the
name is the context around it. It is **unique where set, project-wide**, on
CR-113's `rackLabel` precedent, and a duplicate **springs back with a sentence**
rather than saving: two trunks called `T1` on one Pull Sheet is the defect the
column exists to prevent. **Null is not a collision**, so clearing one is always
legal and any number of trunks may carry none, which is the ordinary state before
anybody has walked the building.

**A project may hold more than one Structure device, and the header picks between them**
(CR-113, M3-E/3). The picker sits beside the `Structure` title and **appears only when there is
more than one**: a single-panel project is the ordinary case and gains no control it cannot
use. The editor always shows **exactly one body's** drops, never a merged view, because two
panels in one undifferentiated table is the failure CR-113's milestone exists to prevent. Every
create gesture on this surface (quick add, `+ Add outlet`, a matrix cell) files onto the body
the picker is showing. The bodies are listed by their device's designator, `STR-1` before
`STR-2`, which is the string the header already prints.

**The bulk entry bar is above the tabs, not inside one.** It is the same widget
with the same state on both, which is M3-C/3's whole instruction: *"a matrix
that is its own screen is a second place the repeat loop has to be
re-established"*. Typing a line with the grid showing puts the drops in the
grid, and typing one on a project with no rooms creates the room and then the
drops without leaving either view.

### 4.1 Table columns

Default columns are the ones a person needs to answer "what am I pulling and where does it land": field label, rack label, outlet, media, service, pathway, rack termination, rough-in status. **Optional columns**, off by default, added from `⚙ Columns`: jacket rating, jacket colour (convention), **jacket colour pulled** (the exception), conduit, `routedLength` / `cutLength` / `terminatedLength`, field termination, test result and certificate ID, installed by, notes, **class** (DR-067), **wiring** (DR-180), and any `unknown`-map columns preserved from a CSV import. Jacket colour and conduit were demoted from default to optional and reel ID was cut entirely (RJ-004).

**`WIRING` is this cable's OWN standard and never the resolved one (DR-180 &sect;11.179.2).** The job states T568A or T568B once, in project settings, and the ordinary project never opens this column: the ruling's whole trade is one entry per job replacing one per drop. The cell has three states. A standard means somebody typed an exception on this run. A dash means the cable states nothing and follows the job, which is NOT this column's unknown in the usual sense and is why clearing the cell is a real gesture rather than a deletion. `&mdash; NO RJ45 &mdash;` means a standard is not a fact about this cable at all, and such a row gets no control, because the column is editable per column while "does this cable have an 8P8C end" is per row (&sect;11.179.3). Showing the RESOLVED standard here was considered and refused: the control writes what it shows, so picking the value already on screen would silently pin that cable to a standard the project might later be changed away from. The resolved value is what the Termination Schedule prints, beside the termination type.

**Either end of a run may terminate on a device (DR-068, canon &sect;11.67).** `BindEndpoint` binds whichever end it is handed. For structured cabling the rack end is the one that lands and the field end stays a wall plate, with whatever plugs in there drawn as a separate patch cord; that is the trade and it is unchanged. For AV it is often the other way round: **an in-wall or in-ceiling speaker run is one continuous conductor from the amplifier to the binding posts on the driver**, and a product that could only land the rack end forced a second cable onto the schedule that does not exist in the building. The endpoint is symmetric; the labels are not. A rack bind allocates the rack label, because that label is derived from the panel position it just landed on. A field bind writes no label at all, because the field label names the plate, was typed when the drop was created, and is unique project-wide under CR-113.

**A drop punched into the wrong port can be moved (DR-074, canon &sect;11.73).** Two commands, because they are two acts: **MOVE** re-lands an end on a different jack in one gesture and one undo entry, and **UNLAND** returns it to open. The rack label follows the hole, since `1A-PP-101` on a cable now in position 04 is a wrong number on the one column a trim tech reads; a label somebody **typed** survives instead, and the surface says it was kept. The **termination survives both**, because it describes how the cable end is finished rather than which hole it sits in, and a run can be punched onto a block this project does not model; a person who really pulled the cable back out clears it in `RACK TERM`. Neither command deletes a jack it did not create. **Not yet built**, and &sect;11.73.5 leaves the surfaces to the task, with one gesture forbidden outright: dragging a run to empty canvas must never mean unland.

**Drag a run onto a jack to land it (DR-073, canon &sect;11.72).** A half-landed run draws a single pennant, off the end it has. Press that pennant, drag to a free jack and release, and the run lands there: the commit is `BindEndpoint`, **never** a connect, because the run already exists and connecting to finish it would put a second cable on the sheet beside the one being completed. That was the complaint this whole item began with. Either end may be the loose one, so a run drawn at its amplifier is waiting for a field end and one drawn at its wall plate is waiting for a rack end. A press on a **pin** always beats a press on a pennant, since the two hit boxes touch and making a cable is the commoner act; a patch cable's pennant arms nothing at all, because a bind would refuse it. Dropping on an occupied jack refuses, and there is still no way to move a run **off** a jack it is landed on (DR-040 &sect;11.39.6).

**The schematic counts the runs nobody landed (DR-072, canon &sect;11.71).** Its status strip prints **"N home runs not landed at the rack"**, first among the notes, because it is the only one there that names a job rather than a limitation of the drawing. A half-landed run is drawn already, as a single stub off the end it has, so the older *"N cables with no drawn end"* never mentioned it: that note folds together a run nobody landed and a link whose device carries no symbol. The **field** end is deliberately not counted, since a speaker run legitimately ends on its driver and a Cat6 drop legitimately ends at a wall plate, and a number that never reaches zero is a number people stop reading. **Still owed:** dragging a stub onto a pin to land the run from the sheet.

**`LANDS ON` punches a drop down (DR-071, canon &sect;11.70).** An optional column showing where the rack end landed, `PP-1 &middot; 01`, and the gesture that puts it there. It is the only cell in the table that is a **gesture rather than a value**: you pick a **panel** and the product allocates the next free rear position, exactly as `@panel=` does on a drop line, because which hole a drop goes in is not something anybody should type forty-six times. The menu offers **every device with a free rear position**, not just patch panels, since a speaker run lands on an amplifier. It is batchable: tick forty-six rows, pick a panel once, and each drop takes a different hole and a different rack label. A row that is already landed gets **the same menu**, meaning MOVE (DR-074 &sect;11.73.1): picking a panel re-lands the drop on that panel's next free hole, including the panel it is already on, which is the only way to say "not this hole" from a table where the product picks the hole. The menu on such a row also carries **`NOT LANDED`**, which takes the end back off its jack. The rack label follows the position unless a person typed it, and a typed one is marked with a pin in `RACK LBL` so it is clear why it stayed. The termination survives both, because it says how the cable END is finished rather than which hole it sits in; a person who really did pull the cable out clears `RACK TERM`, which is one cell. **Clearing the cell still does not unland**, and says which option does.

**A run may come out of no box (DR-070, canon &sect;11.69).** A ceiling speaker has no low-voltage box, so it has no `Outlet`, and a product that demanded one listed a plate for a speaker that has none. `StructureOrigin.outletId` is nullable, and a separate `boxless` flag states the fact: under G4 an absent value means UNKNOWN, and "there is no box" is something a person said, not a gap in what they know. The two must stay distinguishable or the Outlets page can count neither honestly. Type it with **`@nobox`** on a drop line, the DSL's first valueless flag: every other modifier answers *which one* and this answers *there is none*, so a value would invite `@nobox=false`, which is the default and says nothing. `@nobox` with `@outlet=` is refused rather than ranked. The `OUTLET` column then has three states, a designation, `&mdash; NO BOX &mdash;` and the dash, because an estimator counting plates cannot otherwise tell an unassigned drop from one that will never have a plate. **Without a box the field end must name a room**, and a run that cannot is refused at creation: the room fallback ends at the RACK's location, and a speaker run sorted onto the equipment room's page is the kind of error nobody finds until the sheet is printed.

**A binding post is on a plate or on a driver, and the word does not say which (DR-069, canon &sect;11.68).** `BINDING POST` on a run that is still headed for a wall plate needs one plate cell per conductor, which is what a speaker binding-post wall plate actually is. The same tag on a run whose field end is landed on a device needs **none**, because the posts are the speaker's and there is no plate. Nothing else reads the landing: `keystone` and `punchdown` are always the plate's, `euroblock` and `rj45Plug` are always the device's, and only `bindingPost` is genuinely either. `FIELD CONNECTOR` is **not** the way to say "it lands on the device": it names no connector at all and would leave the Termination Schedule saying nothing to a trim tech, which is why DR-045 refused it for `rj45Plug` on the same ground.

**The `CLASS` column is where a person overrules the classifier (DR-067 §11.66, canon §11.8.2).** It reads the *effective* class: the classifier's answer on a run nobody has classified, and the person's on one somebody has. Its menu is the four classes plus **`AUTO`**, which hands the run back to the classifier and is not the same thing as the dash: the dash means the classifier could not resolve an end, `AUTO` means it is the one deciding. A cell a person has set wears a **pin**, and resting on it says so, naming what the classifier now reads the run as when the two differ. That is a statement rather than a warning: overruling the classifier is a legitimate act, so the pin is never drawn as an error and never raises a validation finding. Picking the word already showing **is** an edit on this column and on no other, because that word is normally the classifier's and choosing it is how a person says "yes, and I mean it". The column reaches only links with a `structureOrigin`; a rack-to-rack jumper has a class and no row here, and the schematic-side control for it is not built.

**`conduit` ships as `PATHWAY KIND`, and the rename is a finding rather than a preference** (M3-C/2). CR-016 made the conduit a first-class `Pathway`, so "which conduit" is already the *default* `PATHWAY` column; a second column naming the same thing would undo RJ-004's demotion by accident. What is genuinely invisible without it is the **kind**, whether `PW-LR-1` is conduit, J-hook or tray, which is what `CODE-001` reads. The `unknown`-map columns are likewise **not offered yet**: there is no CSV importer (§5), so there is no unknown map to preserve, and a menu entry for a column that can never hold a value is a promise about an unbuilt feature. Both absences are named in `derived/structure_table.dart` beside the list they are absent from.

Jacket colour is **two optional columns, not one**, because it is two facts.
`Link.jacketColorId` says what the run IS (a control drop) and drives the
keystone; `Link.jacketColorPulledId` says what was actually pulled and is set
only when the two differ, null is the normal case. A tech at prewire fills the
second column and leaves the first alone; clearing the first does not clear the
second, because "a yellow jacket on a run nobody has classified" is a legal and
useful state. Both are `Command`-backed (`SetLinkJacketColorCommand`,
`SetLinkPulledJacketColorCommand`) so each undoes on its own.

Grid operations are the device builder's, unchanged: fill-down, fill-series, multi-row edit, duplicate, delete, reorder, find/replace, TSV copy-paste, renumber. Inline editing is the primary path, a cell is one click and a keystroke, and every edit is a `Command` on the undo stack.

`Service: undetermined` is a first-class, encouraged state backed by the `structure.undetermined` signal family (canon §6.4). At rough-in a Cat6 is just a Cat6. It schedules, it prints, it gets a `W` number and both labels, and the DRC validates **retroactively** when a `Service` later assigns a real family, an HDBaseT run patched into a switch throws the error it should, when it should.

### 4.2 Bulk entry: matrix mode

Rooms down, media across, integer spinners at the intersections. Changing a cell from 0 to 2 materialises two `Link`s with generated labels in one command; decrementing it deletes the two highest-sequence unconnected drops in that cell and refuses (with a spring-back chip, CR-017) to delete a connected one.

```
                Cat6  Cat6a  RG6  RG6q  16/2  16/4  22/4  OS2  EMT     ∑   Outlets
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

> **The summation header is `∑` (U+2211), not `Σ` (U+03A3).** It read as the Greek capital until the glyph-coverage gate found the product's one fallback character: Unicode separates the LETTER from the N-ARY SUMMATION operator, a column that adds a row up wants the operator, and the two look alike in most faces. Jost carries U+2211 and not U+03A3, so the right character is also the one that renders.

The `EMT` column is `isPathwayOnly` and creates `Pathway`s, not drops, its cells are tinted and excluded from the ∑ drop count (CR-109). Media columns are user-configurable; `+ Media column` opens the media-type picker with an inline "create new type" row.

**A cell is a target and not a step** (M3-C/3). The surface hands over the
number a person typed and `planMatrixCell` works out what it means against the
current document, because a `+1` computed from what the widget last drew is
`+1` against a number an undo, a typed line or a second window has already
moved. The count it reads back and the rows a decrement then takes come off one
call to `buildStructureTable`, so the number on screen and the cables that go
are the same list. A cell that already says that number produces no command at
all, since tabbing across a row commits every cell it passes.

**Highest-sequence means last in the table's own order**, reusing that
comparator rather than inventing a second one, so the runs that go are the ones
a person can see at the bottom of the room's band. A landed run is stepped over
rather than taken; the refusal is for when there are not enough spares, and it
names the floor the cell cannot go below rather than only saying no. Removing a
drop never removes the plate it hung on: an outlet with nothing pulled to it is
a real state.

**An increment creates a plate, exactly as the typed line does.** The matrix
does not know about plates: a cell is a room and a cable, and a real plate is
mixed media, so no cell can correspond to one. Joining the room's first outlet
would put speaker cable on a TV plate somebody else created, so the plate count
is one per gesture and the `Outlets` column is where that is visible rather
than hidden. This is `planOutletFromTemplate`'s rule from the other side: it
creates an outlet and never joins one.

**The grid shows every room and the table does not**, which is the one place
the two views deliberately disagree. `buildStructureTable` omits a room with no
drops because the tree beside it already lists every room; here a `0` cell is
where a person types `2`, and a matrix that hid the empty rooms would be a
bulk-entry grid you cannot enter the first drop on. Which locations get a row
is `LocationKind`'s answer and not a second notion of "room": `room`, `zone`
and `outdoor` take drops, and a `site`, `building` or `floor` gets a row only
when it already carries one.

**The tinted `EMT` column is built** (M3-E/1). It was absent for three tasks
because it needed `MediaTypeDef.isPathwayOnly`, a `Pathway` something could
create, and a drop line that honoured the flag: a tint with no `Pathway` behind
it would have claimed CR-109 held when it did not. The last piece was **DR-035**,
which gives a created pathway the medium and the room, and it is not
bookkeeping: a cell is a target, so a column that created entities it could not
then find would accept a number and read back `0` forever. The cells are excluded
from the `∑` drop count, a decrement **refuses** to take a pathway with cable
running through it and names the `[ Pathways ]` tab, and the column needs no
Structure device at all, because a `Pathway` hangs off the document as a
`Location` does (CR-112).

**One of this section's controls is still absent and says so in the source.**
`+ Media column` has no "create new type" row, because creating a media type is
the media-type editor (M4-P2). There is no `+ Room` either, and that one is not
owed: the loop above the grid already creates a room on `Enter` and CR-112 puts
the second path in the Site view, so a third would be a third place
one rule lives. The grid opens on this section's own eight columns, minus
`EMT`.

### 4.3 Bulk entry: command mode and outlet templates

One text line, the same DSL family as the device builder's Quick Add:

```text
Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4
Attic: 3x Cat6 @service=wifi-ap
Exterior: 6x Cat6 @service=camera @status=planned
Kitchen: 2x Cat6 + 1x RG6 @outlet="KIT-TV-1"
```

`@outlet="…"` creates or joins one `Outlet`, note that this is the *outlet* sense of "bundle", not the pathway sense (CR-016); the DSL uses the canonical word. `@pathway="…"` is the conduit sense.

**`@service=` names the LABEL and `@signal=` names the FAMILY, and they are two words** (DR-025).
`@service=` is DR-023's chain and reaches `{SERVICE}` in the field label; `@signal=` writes
`Service.signalFamily` and reaches the DRC, the palette and the schedule's SERVICE column. One word
cannot be both: a house running AVoIP in most zones and one HDBaseT pair from an AVR to a projector
has runs with the same label and different families, and `video.avoip` and `video.hdbaset` are the
same domain, the same `conn.rj45` and the same Cat6 in the wall. The decisive case is that
`video.hdbaset` excludes `net.ethernet` from `acceptedFamilies`, because 100 W of PoH into a switch
damages it (`SIG-001`), so a label that set the family would let a naming decision switch off the
check.

`@signal=` resolves by `shortTag`, then the id's own tail, then `displayName`, so `@signal=hbt`,
`@signal=hdbaset` and `@signal=avoip` all land. **An unresolved value refuses** rather than creating
a family, which is the opposite of RJ-012's rule for media and follows §3: media types are
user-extensible and signal families are extensible only BY CLONE (DR-122), so no typed
token can mint one. Omitting it leaves the run
`structure.undetermined`, which stays the encouraged default (§4.1).

`+ Add outlet ▾` instantiates an `OutletTemplate` in one action, *TV location* → 2 × Cat6 + 2 × RG6 as one `Outlet` with four `Link`s and four label pairs. Seeded templates: **TV location · AP · Keypad · Ceiling speaker pair · Camera · Data only**, plus **TIA-570-D Grade 1 / 2 / 3** (CR-108). The grades stay **presets and a standards tag, never an axis**: the integrator does not speak TIA-570-D and is never asked to (AC-034/m23, DR-002). Which location fields the inspector demands is driven by the template: a ceiling speaker pair asks for `mountSurface: ceiling` and never for a wall compass direction (AC-034/m24).

---

## 5. CSV import

CSV import is not a convenience feature; it is the **entry path** for the February workflow, the contractor's pull list arrives as a spreadsheet before the equipment list exists. Cutting it while accepting AC-018 would be incoherent, so it ships in v1 (RJ-004).

Two shapes are accepted and auto-detected. **Long**: one row per drop. **Wide**: rooms as rows, media as numeric columns, which is how pull lists actually look. Wide mode is offered when ≥ 2 headers resolve to media synonyms *and* their cells are numeric.

### 5.1 Columns

Header matching is case-, space-, underscore- and hyphen-insensitive. Every source header appears in a **column-mapping sheet** with RackPal's guess and a dropdown to correct it. Unmapped columns are preserved into the row's `unknown` map and surfaced as optional grid columns, user data is never discarded (canon §4.2, forward-compat).

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
| `service` → the label's `{SERVICE}` (DR-023) | `service`, `use`, `purpose`, `function`, `application` | |
| `signal` → `SignalFamilyId` | `signal` | |
| `pathway` → `Pathway.name` | `bundle`, `bundle_id`, `run`, `group`, `home_run`, `conduit`, `raceway`, `pathway` | |
| `routedLength` | `length`, `length_ft`, `footage`, `ft`, `len` | |
| rack-end termination → `PlaceEndpoint.intendedTermination` | `termination_rack`, `rack_end`, `panel`, `panel_port`, `head_end` | see note |
| `terminationField` | `termination_field`, `device_end`, `field_end`, `far_end` | |
| `roughInStatus` | `status`, `state`, `phase` | |
| `jacket` / `jacketColor` | `jacket`, `color`, `colour`, `jacket_color` | the CONVENTION side: what the run is |
| `jacketColorPulled` | `color_pulled`, `colour_pulled`, `jacket_color_pulled`, `actual_color`, `as_pulled` | the EXCEPTION side; see note |
| `notes` | `notes`, `comments`, `remarks`, `note` | |

> **The two jacket-colour columns import independently, and a value naming no
> convention entry is KEPT.** A contractor's pull list carries words (`BLU`,
> `Blue`), which map to a `JacketColorId`; a colour with no matching entry is
> imported as a dangling id and COUNTED as unknown
> (`ResolvedJacketColor.hasUnknownEntry`), never dropped and never silently
> mapped to the nearest entry — the id is the one record that a particular colour
> went in a particular wall, and it must outlive the entry naming it. A row
> carrying only an as-pulled colour, with nothing saying what the run is for, is
> likewise imported as-is: promoting it to the convention column would assert a
> purpose nobody stated (G4). An as-pulled value **equal** to the convention
> value is not an exception and normalises to absent, so an exceptions count can
> never be inflated by no-op imports.

> There is no `terminationRack` field. `StructureDrop` is deleted and a home run *is* a `Link`
> (CR-107, AC-019); `StructureOrigin` carries `terminationField` for the wall-plate end only. The
> rack end is an `Endpoint`, and where it resolves to a `PlaceEndpoint` — the normal case at
> rough-in, when the patch panel is not modelled yet — the imported value lands on
> `PlaceEndpoint.intendedTermination`, whose enum is the same `keystone | punchdown | fBarrel |
> euroblock | unterminated | fieldConnector`. Where the rack end already resolves to a real
> `PortEndpoint`, the column is **dropped with an import note**: a `PortEndpoint` carries no
> termination type because the panel port is the source of truth for it. This is not data loss — it
> is the single-source-of-truth property CR-107 was ruled to obtain.

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

Every target above resolves in `packages/rackpal_core/lib/src/catalog/seed_media_types.dart`, and a CI assertion enforces it: `seed_media_types_test.dart` transcribes this block and checks every target, every synonym, and that no synonym is claimed twice. It also checks the converse, that the seed carries no synonym this block does not list, because `media.cat6_futp` looks like it should have `c6s` and does not. RJ-012 makes an unmatched value create a new type rather than fail, so a wrong target here is a silent data-quality failure, not a loud one. An unmatched value creates a new media type with a confirmation chip; it is never a rejected row.

> **This sentence used to name `assets/catalog/registries.json`.** That file
> has never existed, was declared in no pubspec, and could not have been loaded
> if it had: `rackmate_core` imports no Flutter, so `rootBundle` is unavailable
> to it. DR-010 §11.10.1 settled the master as seeded Dart for that reason, and
> M3-C/6 (commit `acd63d5`) is what made the claim true. The equivalent
> assertion for `conn.*` and signal-family IDs lives in
> `seed_registries_test.dart`.

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

1. **Location match** is by `Location.name` then `Location.code`, case- and whitespace-insensitive, within the Structure's location scope. No match offers "create room" inline, pre-filled with a derived `code`. **DR-053 (canon §11.52) reads "whitespace-insensitive" as COLLAPSING INTERNAL RUNS and not as stripping**, so `Living  Room` matches `Living Room` and `LivingRoom` does not, and it binds **both** entry paths: the typed line matched on trim and lower-case only, so the same double-spaced name created a second room from one path and matched the existing one from the other.
2. **Outlet match** is `(locationId, designation)`. Rows sharing both join one `Outlet`. **DR-053 makes the TYPED LINE obey this too**, which it did not: `_resolveOutlet` matched on `designation` alone, project-wide, so `@outlet="WP-1"` typed in the Attic landed on the Living Room's plate. A designation that repeats in another room is **reported and never refused**, because two rooms with a `WP-1` is ordinary and a mistyped room name is not distinguishable from it by any other means.
3. **Pathway match** is by `Pathway.name`, project-wide.
4. **Drop dedup** is by `fieldLabel` when the file supplies one, otherwise by the tuple `(locationId, outletDesignation, mediaTypeId, ordinal-within-group)`. A matched row **updates** the existing `Link` field-by-field, never duplicates it; unmatched rows are created. Re-importing a corrected spreadsheet is therefore idempotent, which is the whole point, the pull list gets revised three times before drywall.
5. **Update guard.** An import that would modify an existing `Link` shows an explicit import-over-existing confirmation listing the counts (`create 14 · update 38 · unchanged 9`), and never overwrites a field the user has edited in-app unless the CSV supplies a non-empty differing value. It never touches `designator` on a `Link` whose `designatorLocked` is set (CR-034, AC-034/m22).
6. **Duplicate labels are flagged, not blocked**: a `warning` with a one-click "renumber the later one", consistent with the ban on heuristics holding a deliverable hostage (G3).
7. **Hardening.** Every import path enforces size and field-count limits (AC-058/D8), and progress with cancel is shown for any import over ~500 ms (AC-058/D14).

`Export CSV` emits the long shape with every canonical column plus preserved `unknown` columns, so export → edit in Excel → re-import is a supported round trip.

---

## 6. Rendering: drops as flags, grouped by room

The Structure device **never renders as a rectangle with 62 pins.** Its ports are a *rendering of home-run field endpoints* (AC-019), drawn as an edge bank of off-page connector flags, the schematic convention for signals entering from elsewhere, and the J-STD-710 "Demarcation for All Services" idiom. Detailed drawing rules are in [Schematic editor](05-schematic-editor.md); this section states what is Structure-specific.

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
| 3 | **Unused collapse** (default on) | Only *connected* runs render individually. Unconnected ones collapse per room into one summary flag, `Living Room · 3 spare (2× Cat6, 1× RG6)`, expandable in place. This also produces the **Unused Home Runs** page (§9). |
| 4 | **Pathway trunks** | A `Pathway` draws as one thick trunk from the boundary toward the rack, fanning to individual ports only at the destination. Six runs become one line for 90% of their length. This is the whole visual payoff of CR-016's `Pathway`. |
| 5 | **Net labels by default** | A run renders *named*, not *drawn*: a flag at the Structure and a matching flag at the destination port, with the label as the join. Duplicate *source* names prohibited, duplicate *destination* names permitted (CR-049). |

Plus room-level isolate/filter in both the editor and the schematic. Mechanism 5 is no longer conditional, canon open question 10.1 is answered:

> Render mode is a function of the active filter. Unfiltered sheet ⇒ `netLabels`: every `Link` is two labelled stubs, one at each pin, with no polyline between them. Filtered to exactly one `SignalDomainId`, or `Alt`-hover, or focus/isolate ⇒ `drawn`: every `Link` in scope is an orthogonal polyline with a tag pill at each end. `SheetRenderMode` is **derived**, never persisted, never a setting (DR-001, canon §11.1.1).

There is no density threshold that switches rendering, and nothing "degrades", the mode follows the filter, not the drop count. **The Structure device's flags were always a label rendering; DR-001 changes nothing here.** What DR-001 does change is that the *rest* of the sheet now matches the idiom the Structure device already used, so the boundary between the flag bank and the rack side stops being a change of visual language.

Automatic **sheet paging by room group** is **never built** (DR-004): there is permanently exactly one schematic `Sheet`, and room grouping is served by filtering it. The *exporter* separately partitions that one `Sheet` by domain and emits N interconnect sheets `T6.01…` (CR-073, unaffected by DR-004), partitioning at export is not multi-sheet authoring. A domain partition produces zero cross-sheet connections by construction, so no match lines, off-sheet connectors or sheet-boundary link handling are built at all.

---

## 7. Multiple Structure devices

Multiple instances ship (CR-113). A rack fed from a garage media panel *plus* a separate exterior/camera panel *plus* a utility/service entrance is a normal residential job, and one monolithic node is less useful than three named ones. Rejected alternative: an implicit singleton, which would have made `structureBodyId` unnecessary and the exterior-panel case unrepresentable.

Rules:

1. Each instance has its own name, designator (`STR-1`, `STR-2`, …), location scope, and label preset pair.
2. `StructureBody.sheetEdge: left | right`, default `left` (CR-072). Every `left` Structure lands on schematic layer 0, every `right` one on layer N, a service-entrance structure drawn on the opposite side from the home-run field is legitimate and common. Rejected alternative: forcing "the Structure device" (singular) to layer 0.
3. **`fieldLabel` uniqueness is project-wide across all Structures**, not per-instance. Labels get printed on physical cable and must not collide across panels. `rackLabel` is likewise project-unique when set.
4. A room may appear under more than one Structure, a bedroom with data from the media panel and a camera from the exterior panel. The location tree is shared; the drops are not.

---

## 8. Labelling

**Every home run carries two labels, and both always print** (CR-044). The field voice calls this "the single most valuable line in these four documents"; it costs one nullable string and one column, and cutting it was rejected (RJ-004). `fieldLabel` is required and project-unique; `rackLabel` is optional and project-unique when set. Both are generated from templates, both are editable, both appear on both ends of every schedule row (AC-025). The insight was originally applied only to Structure drops; it now applies to every cable in the project.

There is no residential labelling standard. TIA-606-C assumes floors, telecom spaces and patch panels; a house has one rack and rooms with names. TIA-606's horizontal-link identifier is literally `<floor><space>-<panel><port>`, `1A-A12`, and the standard is explicit that **the format is not mandated, only that it be consistent and unique**. That is why RackPal ships an identifier format engine rather than hard-coded schemes.

One grammar, one registry, one parser, in `rackpal_core/idformat/`, shared by five call sites, device, port, link, outlet field label, outlet rack label (CR-045). Tokens are `UPPER_SNAKE`; `{TOKEN:n}` zero-pads; `[...]` marks an optional segment; `|upper`, `|first n`, `|nz` are filters; `{{` and `}}` are literal braces. Collisions resolve by a project-wide `CollisionPolicy{suffixLetter | suffixNumber | error}`.

**Two presets ship, not five** (CR-044, AC-046):

| Preset | Pattern | Output |
|---|---|---|
| **Residential CI** (default `fieldLabel`) | `{ROOM_ABBR}-{SERVICE}-{SEQ}` | `LR-TV-1`, `MBR-KEY-2`, `EXT-CAM-4` |
| **TIA-606 Class 2** (default `rackLabel`) | `{FLOOR}{SPACE}-{PANEL}{PORT:2}` | `1A-A12` |

Both are editable, and a project may write its own pattern from the token vocabulary (canon §4.5), `{ROOM_ABBR}-{MEDIA}-{SEQ:2}` → `LR-CAT6-01` is a one-line change. **Every designator is evaluated once at creation and stored, never recomputed at render time** (CR-048). Changing a scheme offers a renumber with a diff; it never silently renumbers and it never touches a locked ID. `Link.designatorLocked` auto-sets at `roughInStatus >= pulled`, because once 60 cables are physically labelled an accidental renumber is a day of relabelling (AC-034/m22).

---

## 9. How drops reach the PDF

**There is no separate drop-schedule sheet.** The prior design's `T6.03 Structure / drop schedule` is superseded: because a home run *is* a `Link` (CR-107), it flows into the same two schedule presets as every other cable (AC-025). A dedicated drop schedule would have re-created the double-modelling that CR-107 deleted.

| Output | What home runs contribute | Ruling |
|---|---|---|
| **Pull Sheet** (`T6.10`, portrait) | Every `fieldCable`, sorted **room then pathway**: the order the tech walks the house. Per-room footage subtotals, jacket colour, both labels on both ends, and `Pulled ☐ Terminated ☐ Tested ☐ Init ___`. Pathway-only entries (conduit, pull string) appear here and nowhere else. | AC-025, AC-026, CR-109 |
| **Termination Schedule** (`T6.11`, landscape) | Every cable landing in the rack, sorted **rack, panel, port**: the port-to-drop map of §1. Adds T568A/B, punch position, polarity, and `Conductor.colorCode` per role. | AC-025 |
| **Unused Home Runs** (`T6.20`) | Home runs whose rack end is an `OpenEndpoint`, grouped by room. Emitted automatically whenever at least one exists. A deliverable integrators cannot get from anything else; the name is canonical and stays. | canon §4.3 |
| **Equipment List and Materials** (`T6.30`) | Cable footage rollup by media with a configurable waste factor, *"Cat6: 2,140 ft estimated + 10% = 2,354 ft → 3 boxes (1000 ft)"*. No pricing in v1. | AC-024, AC-055 |
| **Interconnect sheets** (`T6.01…`) | The flag banks of §6. N interconnect sheets, one per domain partition of the single schematic `Sheet`. Each partition is a domain filter, so these sheets render `drawn` rather than as net labels (DR-001). | CR-073 |

Both schedule presets carry location on **both** ends, `RK-1 / U14 / rear` and `Great Room / TV wall / WP-1`, never a schematic zone reference alone. Estimated lengths derived from `Location.estimatedRunLengthFromRack` render in italic and are tagged in the schedule so nobody bills off them (AC-024, G4); a null length makes `LEN-*` emit `advisory: length unknown, cannot verify` rather than passing silently. Unbound endpoints raise `LNK-020 advisory: N links have unbound endpoints`, a checklist, not an error, and never a gate on export (AC-018, CR-022, G3).

**The other end of the job: the as-built tally (DR-020).** The Structure editor also owns the
surface an installer closes out on, because it is the same sixty rows read back in the other
direction. One table, one length column tabbed down, recording `Link.terminatedLength` and
`Link.spliceCount` per run, not sixty inspector visits. `spliceCount` is `int?` on the G4/CR-114
pattern: **null is unknown, `0` is confirmed none**, and the two are not the same claim. A splice is
a real as-built fact with real consequences, breaking the channel on Cat6 and failing certification,
adding loss on coax, and entirely normal on fibre; `Link.notes` carries the why. `roughInStatus`
and `TestResult` already exist alongside these fields and already reach the schedule. What the
tally then makes possible is the honest footage rollup: **estimated versus actually pulled, per
media, with the variance visible**: the one number in this document that improves with every job
rather than being spent once. It is v1, in M3, and it does not wait on the Plan view
([Plan view](15-plan-view.md) §4.2).

**The tally shipped at M3-J/3 as seven optional columns**, not a screen: `TERM. LEN`, `SPLICES`,
`FIELD TERM`, `TEST`, `CERT ID`, `INSTALLED BY` and `TERMINATED`, turned on together from `⚙
Columns` as **As-built columns** and entered with the same fill-down and paste the rough-in table
uses. `ROUGH-IN` is not one of them: it is one of §4.1's eight defaults, because "how far along is
this run" is what the rough-in table is already about, where these seven answer "what did we
actually do" on a second visit. Closing out sixty runs costs three gestures. The footage rollup
that compares estimated against pulled is **#154** (M3-D/3) and is a different number for a
different reader; this task records the facts it will read.

Full sheet order, furniture and table layout are in [PDF export](08-pdf-export.md). The set is a **client deliverable** and carries full drafting furniture, title block, revision block, revision clouds, issued-for-construction stamp, drawing border, zone references and sheet numbering (DR-005). Sheet furniture is orthogonal to wire idiom: the sheet is polished fully and the wires stay net-labelled (DR-001).

---

## 10. Scope and acceptance

Everything in this document is **v1**, delivered in milestone **M3: Structure and the field** (canon §9.4), which also carries `PlaceEndpoint`/`OpenEndpoint` in the UI, the project-level Locations panel, the three length fields, and `Pathway`. The exit criterion is concrete and is the acceptance test for this document:

> A 60-drop whole-house rough-in is entered in under fifteen minutes, produces 60 `Link`s each with one `fieldLabel` and one `rackLabel`, and exports a Pull Sheet sorted by room and pathway with per-room footage subtotals and initial boxes. Fourteen of those drops have unbound far ends and every one of them still schedules, prints, and carries a `W` number. Requirement 6 is met.

One of the four starter projects authored as real `.rppj` files exercises Structure end to end, doing triple duty as a golden, a perf fixture and a screenshot source (AC-052). Field devices (display, projector, in-ceiling speaker pair, camera, AP, keypad, ISP gateway/ONT, wall plate and the rest of the 18 `mountMethod: notInRack` templates) are what the field ends eventually bind to; see [Seed devices](catalog/seed-devices.md) and [Device builder](06-device-builder.md) for the stripped authoring form they use.

**Not in v1, and these are rulings rather than omissions:** a signal-family editor or a rule editor, though the media-type editor does ship (RJ-012); reel IDs (RJ-004); pricing on any Structure output (AC-055). Outlet templates are per-installation library objects in v1. **Sharing them between projects is no longer ruled out** (AC-042 cut the library pack, DR-015 §11.15.3 re-opens it as `.rmda`, and an outlet template is a `TemplateBody` like any other) but it is ruled rather than built and nothing here depends on it.

**Never built, in any version:** automatic sheet paging by room group, and multi-sheet authoring generally (DR-004). There is permanently one schematic `Sheet`; room and domain grouping are served by filtering it and, at export, by the domain partition of CR-073. The `Sheet` entity stays in the schema (AC-037) so the file format never has to migrate if that is ever revisited.

---

**See also:** [Domain](01-domain.md) · [Data model](02-data-model.md) · [Schematic editor](05-schematic-editor.md) · [Device builder](06-device-builder.md) · [PDF export](08-pdf-export.md) · [Canonical decisions](canonical-decisions.md) · [Decisions (ADR log)](10-decisions.md) · [Testing and quality](11-testing-and-quality.md)
