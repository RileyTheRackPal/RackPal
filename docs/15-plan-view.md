# The Plan View

The Plan view is RackPal's answer to the question a schedule cannot answer: **where**. A pull sheet
says that `W044` runs from `RK-1 / U14 / rear` to `Great Room / TV wall / WP-1` and gives the
installer everything except the one thing they are standing in the building to find out, which is
which wall. This document defines the floorplan underlay, the pin that puts a device on it, the
calibration that turns pixels into a real distance, the length model that keeps a measured distance
from being mistaken for a cable length, the editor, and the sheet the whole thing exports to. It
cross-references [Data model](02-data-model.md) for entity definitions rather than restating them
and cites the governing ruling ID for every decision; the adjudications are in
[the canonical decision record](canonical-decisions.md), which is normative.

**Status.** Ruled into v1.1 by **DR-018**, its container shape and one v1 obligation by **DR-019**,
and its length model by **DR-020**, which voided §4's first draft one commit after it was written,
on evidence from the trade rather than the corpus. **Moved into v1 and sequenced before M6 by
DR-029**, which also buys PDF import. **Decomposed on 2026-08-10 by DR-037**, which settles this
document's four remaining open points and corrects §4.1, §7 and §10 in place. **This line read
*"Not built"* until 2026-09-08**, on a document whose own §2, §3 and §6 each say `BUILT AT` and name
a chapter: `PLAN-A` through `PLAN-E` have closed and the container, the model, the import and the
editor all ship. What is not built is the exit criterion, which is a printed `T1.01` a stranger can
use (`PLAN-H`, `PLAN-J`). The feasibility study and cost are in
[research/feasibility-plan-view.md](research/feasibility-plan-view.md); the exit criterion is
roadmap §4 and canon §11.36.1, and the task breakdown is docs/12 §5.9.

---

## 1. What a plan does that a schedule cannot

Three things, and only three. Naming them narrowly is what keeps this document from describing a
CAD program.

**It answers "which wall".** A room name plus an outlet designation identifies a drop to somebody
who already knows the house. A dot on a plan identifies it to somebody who does not, which is the
person actually pulling wire at seven in the morning.

**It puts a floor under a length.** AC-024 gave every room one number,
`Location.estimatedRunLengthFromRack`, honest about being an estimate. A calibrated plan with the
rack pinned on it can say something stronger and narrower: that a given run is *at least* so long.
It cannot say how long, because structure decides the route and structure is discovered rather than
designed (§4).

**It survives the handoff.** The current practice this replaces is coloured dots in a notes
application. That artifact is not in the project file, is not in the sheet set, does not print with
a title block, and cannot be revised. Everything else in RackPal travels in one `.rmpj` and exports
into one drawing set; a plan that does not is not worth building.

**What it is explicitly not**, and these are limits, not omissions:

| Not this | Why |
|---|---|
| A CAD editor | No walls, no dimensions, no drawing tools at all. The only thing a user places is a pin. The underlay is a picture and stays one |
| A room-geometry model | Rooms are the `Location` tree (CR-047) and stay there. A plan does not define, contain or imply a room |
| An area takeoff | No square footage, no coverage circles, no speaker-layout arithmetic |
| A reflected ceiling plan or riser diagram | Out, per DR-005 §11.5.3, and unaffected by DR-018 |
| A replacement for the Pull Sheet | `T6.10` is the deliverable (G1). The plan is a locator |

---

## 2. The container

Ruled by **DR-019**. Stated here because every other section depends on it.

`.rmpj` is **plain pretty JSON when the document has no binary member, and a zip container when it
does**. **BUILT AT PLAN-B, 2026-09-07** (`persistence/container.dart`), and this paragraph described
it in the future tense until then. The sniff `persistence/codec.dart` has carried since M0 is now the
branch it was always shaped to be.

**Three things the implementation found that this section did not predict.** The four nondeterminism
sources are **three plus one**: extra fields are already absent in `archive 4.0.9`, so that one is
guarded by a test rather than fixed by the writer. **A truncated zip does not throw**, it decodes to
an EMPTY archive, so *zero entries* rather than *an exception* is the signature of a damaged file, and
writing it the other way round would have refused a backup to every truncated project. And the
container is an **envelope** rather than a second `DocumentCodec`, because `DocumentCodec.read` turned
out to have no caller on the app's open path at all. docs/12 §5.9.2 carries the measurements.

The consequences worth stating:

- **CR-091's "single file" survives.** A project is still one file you can email, and the floorplan
  travels inside it.
- **Nothing migrates.** A document with no underlay is byte-identical to what this build writes
  today. Existing golden corpora and the CR-117 round-trip are untouched on that path.
- **The zip path owes its own determinism.** Zip is a famously nondeterministic container: entry
  order, modification timestamps, compression level and extra fields all vary by writer. CR-117
  requires `write(read(bytes)) == bytes`, so the writer fixes all four. Entries are sorted by member
  name, timestamps are a constant rather than the wall clock, one compression method is used, and
  no extra fields are emitted.
- **Member layout** is `document.json` at the root plus `underlays/<uuid>.<ext>`. The JSON member is
  exactly the bytes the plain-JSON path would have written, so one encoder serves both.

**Two rejected alternatives**, recorded because they are the obvious ones:

| Rejected | Why |
|---|---|
| **Base64 inside the JSON** | A 2 MB PNG becomes roughly 2.7 MB of inline text in a pretty-printed file that is rewritten whole on every save, and CR-117's round-trip starts moving megabytes on every run of the core suite. It is the fast answer and the one that is regretted |
| **A sidecar file next to the `.rmpj`** | Breaks CR-091's single-file property outright, and "email the project, lose the floorplan" is the exact failure this product exists to prevent. It would also owe a new state in the file-layer error surface (AC-058/D3) |

**Raster formats accepted: PNG and JPEG. PDF IS READ, as of DR-029**, and this paragraph used to say it was not. The `pdf` package writes documents and
does not import pages (docs/08 §1.1), so a PDF floorplan would require PDFium or a WinRT path, and
either puts a multi-megabyte native binary into a self-signed portable distribution (DR-006) or owes
a `docs/13` entry against DR-009. That increment is bought: DR-029 ships it in v1 at a
costed 2–3 weeks over raster-only, because architects send PDFs and a manual conversion step
would sit on the ordinary path rather than the exceptional one. **It changes no stored format**, and
that prediction holds exactly: a PDF is rasterised at IMPORT and the member written to the zip is
still PNG or JPEG, so `PlanUnderlay.format` keeps its two values and `rackpal_core` still needs no
decoder. What it buys is a `docs/13` entry against DR-009, which DR-029 accepts and names, and which
is now **D15** and is costed with **D9** rather than twice.

**A multi-page PDF gets a page picker, and exactly one page becomes one underlay** (DR-037
§11.36.2). Architectural sets are multi-page and the electrical sheet is not page 1, so importing
only the first page would put the conversion step DR-029 spent 2–3 weeks buying out back on the
ordinary path. The pages are rasterised at thumbnail size, shown as a grid, and the one clicked
becomes the underlay. **This narrows §10's exclusion rather than reversing it**: no underlay is ever
more than one page and nothing is tiled.

---

## 3. Data model

Four additions. All are additive, all use absent-key-is-unknown (G4, CR-114), and none changes an
existing field's meaning.

**BUILT AT PLAN-C, 2026-09-07**, in `model/plan.dart`, `units/px_pt.dart` and
`commands/plan_commands.dart`. **Two things the implementation found that this section did not
predict**, both recorded in docs/12 §5.9.3 rather than only here.

**`kSchemaVersion` MOVED TO 5, AND `minReaderVersion` STOPPED BEING A CONSTANT** (DR-136 §11.135).
This section calls the additions additive and they are: every starter and every fixture re-encodes
with one line changed, the schema stamp. But the `unknown` passthrough DR-019 §11.18.2(5) bought to
stop an older build dropping pins **is a reserved container and not a harvester**, so it never
covered a sibling key like `planPin`. The loss is prevented instead by refusing the write: a document
carrying an underlay or a pin declares a reader that understands plans, and an older build opens it
read-only.

**THE `underlays` MAP IS OMITTED WHEN EMPTY**, unlike the fourteen entity maps beside it, which is
what keeps the paragraph above true. Writing `"underlays": {}` would add a key to every `.rmpj` in
existence on its next save.

### 3.1 `PlanUnderlay`

```dart
final class PlanUnderlay {
  final Uuid id;
  String name;                 // "Level 1", "Basement", "Site"
  Uuid? locationId;            // the Location this depicts, usually a floor
  String imageMember;          // zip member path, "underlays/<id>.png"
  ImageFormat format;          // png | jpeg
  int pixelWidth, pixelHeight; // intrinsic size, so aspect is known without decoding
  String contentHash;          // AC-042's survivor; a warning, never a load failure
  PlanScale? scale;            // null = UNCALIBRATED, and that is a fact, not a default
  FracIndex order;
  EntityMeta meta;
}
```

`pixelWidth`/`pixelHeight` are stored so the model can lay a plan out, hit-test a pin and size a
sheet **without decoding the image**. That keeps `rackpal_core` free of an image decoder, which
matters because core is Flutter-free by gate and because AC-057 counted the decode surface as a real
cost.

`scale == null` means uncalibrated. It does not mean 1:1 and it never acquires a guessed value.

### 3.2 `PlanScale`: store the inputs, never the factor

```dart
final class PlanScale {
  final PxPt a, b;      // two points the user picked, in image pixel space
  final Len distance;   // the real distance between them, as typed
}
```

CR-001 forbids floating-point millimetres in the model and in any file format. A scale factor is a
ratio and cannot be an integer, so **the factor is never stored**. What persists is the two integer
pixel coordinates and one `Len`, which are exactly what the user supplied. The factor is derived at
the point of use.

Derivation is a `double` intermediate, and that is allowed: CR-001 governs storage and the model, in
the same way `Pt` is integer while the canvas draws in `DPt`. Two obligations attach to it. The
result is rounded to the nanometre with a single stated rule (half away from zero) so two machines
agree, and the rounding happens **once**, at the boundary, never accumulated across segments.

### 3.3 `PxPt`, a third point type, deliberately

```dart
final class PxPt { final int px, py; }
```

Image-pixel space. It is not `Pt` (integer 2.5 mm schematic grid units, CR-004) and it is not `DPt`
(the canvas's doubles). docs/02 §4.8 warns against collapsing distinct concepts onto one name, and
these three are distinct: a schematic grid coordinate, a device-independent drawing coordinate, and
a position inside a specific raster. Naming them alike is how a pin ends up 2.5 mm from where it was
placed.

### 3.4 `PlanPin`, and the three things that carry one

```dart
final class PlanPin {
  final Uuid underlayId;
  final PxPt at;
}
```

| Carrier | Field | Why |
|---|---|---|
| `OffRackPlacement` | `PlanPin? planPin` | A wall speaker, a camera, a projector. Additive to the existing variant; `locationId` remains the schedule's source of room truth and a pin never replaces it |
| `Outlet` | `PlanPin? planPin` | The plate location. This is the thing the designer is actually dotting today (CR-016: one wall plate, one ceiling location) |
| `Rack` | `PlanPin? planPin` | **Not optional to the design.** A home run is measured *from the rack*. Without the rack pinned, no length on that plan is derivable at all, and `PLN-003` says so rather than measuring from the corner of the image |

`OffRackPlacement` gains a field rather than the sealed `Placement` union gaining a sixth variant.
A device pinned on a plan is still off-rack in a room; those are not mutually exclusive states, and
the union's five members are (CR-032, docs/02 §4.3). Placement variants keep all-`final` fields, so
setting a pin replaces the placement object, per `placement.dart`'s own header.

---

## 4. Length: the one thing a plan may honestly claim

**A plan cannot predict a route, and this document previously assumed it could.** The first draft of
this section specified a route polyline the designer would draw at design time, plus a routing
factor and a slack allowance, and treated the result as a measured length. That was wrong on the
domain, and the correction came from the trade rather than from the corpus (DR-020):

> Structure decides the route, and structure is discovered rather than designed. LVLs, concrete
> beams and heavy purlin runs regularly force a cable out of the attic and into the crawlspace, and
> which of those happens is not knowable from a floorplan. Two drops in the same room, to the same
> wall, can take paths that differ by forty feet.

A design-time polyline therefore records a guess with the visual authority of a measurement. That is
the G4 failure exactly, and worse than the per-room estimate it would have replaced, because it
looks specific.

### 4.1 The plan contributes a lower bound, and nothing else

Straight-line pin-to-pin distance on a calibrated plan is **always less than or equal to any real
route**. That makes it the one length statement a plan can make that is true regardless of what the
framing turns out to be:

> `W044` is **at least** 41 ft.

`ScheduleLengthSource` already exists in `derived/schedule.dart` and already tiers length
provenance as `cut | outletNominal | roomEstimate | none`. The plan adds **one value**, not a new
system:

The ladder, in order, **most authoritative first** (the rank is DR-037 §11.36.4):

| Source | Meaning | Prints |
|---|---|---|
| `cut` | `Link.cutLength`, the measured figure | Upright |
| `outletNominal` | `Outlet.nominalRunLength`, this drop's stored nominal | Italic, an estimate |
| `roomEstimate` | `Location.estimatedRunLengthFromRack` (AC-024) | Italic, an estimate |
| **`planLowerBound`** | **New.** Calibrated straight line, rack pin to device pin, plus the location's `riseAllowance` if one is set | **Italic, and prefixed `≥`** |
| `none` | Nothing known | `—`, and `LEN-*` emits *"length unknown, cannot verify"* (G4) |

**It is never a takeoff number and never enters the footage rollup as a quantity.** A bound cannot
be summed into "how much Cat6 to order" without becoming a claim it is not entitled to make. The
rollup counts bound-only rows the way `Rollup.unknownCount` already counts unknowns.

**IT RANKS BELOW `roomEstimate`, AND THE REASON IS THE ROLLUP RATHER THAN THE COLUMN.** Because a
bound is excluded from the footage total, ranking it above the room estimate would make every drop on
a calibrated plan leave the purchase quantity and land in `unknownCount`: **the number an integrator
orders cable from would get worse in proportion to how much of the job had been planned.**
`derived/cable_footage.dart`'s `_isQuantity` is an exhaustive switch with no default arm, written so
that adding this value stops the build until somebody decides, and this is that decision.

**The rank costs the bound nothing, because its value was never the column.** `LEN-001` and
`LEN-002` read the bound **regardless of which tier printed**, so the asymmetry survives intact: a
plan proves a violation and can never prove compliance. The bound is a rule input that happens to be
printable, not a length that happens to be checkable.

**`Location.riseAllowance` DOES NOT EXIST YET.** This section and DR-020 §11.19.2(1) have both been
spending it since 2026-08-04 and a grep over every `.dart` file in the tree returns nothing.
DR-037 §11.36.5 adds it as `Len? riseAllowance` on `Location`, null unknown and `0` a measured zero
(G4, CR-114), written only when present so no file on disk changes a byte.

**What it is good for is `LEN-001`.** That rule is already one of v1's 27 (docs/02 §5, tier 1,
Ethernet channel over 100 m). A lower bound is exactly the right input for it, because **if the
bound already exceeds the limit, the run is out of spec no matter which path it takes.** A plan can
therefore prove a violation at design time even though it can never prove compliance. That
asymmetry is the whole value, and it is stated here so nobody later "improves" the bound into an
estimate.

`riseAllowance` survives from the first draft as the one allowance worth keeping, per `Location`,
because a plan is flat and the drop from ceiling to device is the one dimension it structurally
cannot see. Adding it keeps the result a bound. `routingFactor` and `slackAllowance` are **deleted**:
both were the product guessing at building geometry, which is what §4's opening paragraph forbids.

### 4.2 As-built length capture is a different feature, and it is not this one

The `LEN` column's real job is **the tally at the end of the job**: an installer recording what they
actually pulled. That work is almost entirely independent of the Plan view, and stating so is the
most useful thing this section does, because it means the tally does not wait on a floorplan.

**Most of it already ships.** `Link` carries `routedLength`, `cutLength` and `terminatedLength`
(AC-024), plus `roughInStatus{planned, pulled, dressed, terminated, tested}` and
`TestResult{pass, headroom, certificateId}`. `derived/schedule.dart` already projects
`terminatedLength` and `roughInStatus` into every `ScheduleEntry`. Roadmap M3's checklist already
owns *"the three length fields"*. None of that is Plan view work and none of it is new scope.

**Two things are genuinely missing**, and DR-020 rules them:

| Missing | Shape |
|---|---|
| **A splice is not expressible** | `Link.spliceCount: int?`. **Null is unknown, `0` means confirmed none** (G4, CR-114), which is the same invariant `typicalWatts` follows. A splice is a real as-built fact with real consequences: on Cat6 it breaks the channel and will fail certification, on coax it is added loss, on fibre it is normal and engineered. `Link.notes` already exists and carries the why |
| **The tally has no entry surface** | An installer closing out sixty runs wants one table with a length column they tab down, not sixty inspector visits. This is the same ergonomic argument the Structure editor's bulk-entry bar already won (AC-048), applied to the other end of the job |

**What the as-built tally then makes possible** is the honest version of the footage rollup: what was
*estimated* versus what was *actually pulled*, per media, with the variance visible. That is a number
an integrator can bid the next job from, and it is the only number in this document that improves
with every job rather than being spent once.

### 4.3 The route is recorded as-built, not predicted

Where the cable actually went is a fact discovered during the pull, and it already has a home:
`Pathway` (CR-016, AC-027), which carries `kind`, `containsLineVoltage`, `fromLocationId`,
`toLocationId` and `nominalLength`. A crawlspace or an attic is expressible today as a `zone`
`Location` that a `Pathway` runs between.

**Open, for M3 when `Pathway` gets its editor:** whether `PathwayKind` should gain `attic` and
`crawlspace` alongside `conduit | jhook | tray | plenumSpace | riser | directBury | exterior`. The
argument for is that both carry real consequences an integrator acts on, namely temperature rating,
rodent exposure and moisture, in the same way `plenumSpace` carries a code consequence. The argument
against is that they are *spaces* rather than containment methods, and the location tree already
models spaces. This document does not rule it.

---

## 5. Calibration

Two picked points and one typed distance. Nothing else, and specifically no attempt to read a scale
bar out of the image.

**BUILT AT `PLAN-F/1`, 2026-09-08** (`units/distance_entry.dart`, `commands/plan_commands.dart`'s
`SetPlanScaleCommand`, `canvas/plan/plan_calibrate.dart`), and **RULED IN DETAIL BY DR-144 §11.143**
at `PLAN-F`'s decomposition, because the census found that
`PlanScale` had neither a reader nor a writer in `lib/`: `PLAN-C/2` built the model and argued its
rounding rule out in its own header, and every one of `nanometresPerPixel`, `pixelSpan`, `isUsable`,
`lengthBetween`, `lengthAlong` and `PlanUnderlay.isCalibrated` was reached only from tests. No
command set a scale at all, so `scale` is null in every document this product can make. That is the
third chapter in a row to find a modelled field nothing can reach (DR-140, DR-143).

The interaction: `Calibrate…`, click two points that span a distance you know, type it. The obvious
choice on a residential plan is a dimensioned wall; the fallback is a door, which is 32 or 36 inches
in almost all of this work and is the one thing on every floorplan whose real size the user knows
cold.

**`Calibrate…` LIVES ON THE UNDERLAY ROW** (DR-144 §11.143.4), because a calibration is a property of
an underlay, the left rail is the list of underlays, and §6 says there is no fourth region. The row
carries a state line in both directions and an action that reads `Recalibrate…` once there is a
scale to replace.

**THE PICK IS A MODE, CONSUMED BY ITS OWN SECOND CLICK** (§11.143.6). A chip, a first click, a line
following the pointer, a second click that opens the distance dialog. It borrows DR-141's shape and
not its instance: the arm mode outlives each pin on purpose, and a calibration describes exactly one
distance, so a mode that stayed armed afterwards would offer to recalibrate the plan immediately.
`Esc` on this canvas has three rungs from here: the pick, then the arm mode, then the selection.

**A TYPED DISTANCE CARRIES ITS UNIT, AND A BARE NUMBER IS REFUSED BY NAME** (§11.143.5). `36` is 36
inches or 36 feet, and the two differ by a factor of twelve applied to every length the plan will
ever yield; a guessed unit does not degrade a number, it produces a confident one that is wrong by
an order of magnitude on a drawing an installer will trust. The grammar takes `36"`, `36in`, `3'`,
`3ft`, `3' 6"`, `3' 6-1/2"`, `2.4m`, `2400mm` and `240cm`. **It diverges from `parseLengthCell`
deliberately**, which reads a bare number as whole feet because its column is whole feet of cable;
the two are not candidates for harmonisation, and a pass that unified them would silently give
calibration a default unit. `displayUnits` shapes the refusal sentence and the field's hint, not the
grammar: an explicitly united value is unambiguous on any project.

**Until an underlay is calibrated, pins may be placed and no length derives.** Placement is useful on
its own, because "which wall" does not require a scale. `PLN-001` reports the uncalibrated state as
an advisory rather than blocking anything (CR-022, G3).

**Recalibration is a document command like any other** and is undoable. It changes every derived
length on that plan at once, which is exactly why it goes through the command stack and not through
a settings field.

**AND WHAT IT REPORTS BACK IS A COUNT OF PINS, NOT OF LENGTHS** (§11.143.3), because at `PLAN-F`
there are no derived lengths to change: `planLowerBound` is `PLAN-G`'s and §6's pin-drag row already
forward-dates its recompute clause. A report counting schedule rows would print `0` on every
calibration in the product, which is a G4 report whose number is an artifact of what is unbuilt. So
the report names how many pins a length could now be derived for, and when none can, the reason:

> Calibrated Level 1. 12 pins can now be measured from the rack.

> Calibrated Level 1. No rack is pinned on this plan, so no length derives yet.

**The derivation produces no `Len`.** One per pin would be `planLowerBound` shipped early under
another name, without the rank, the `≥` prefix, the italic, the rollup exclusion or `LEN-001`'s
reading, which are five decisions §4.1 already took and `PLAN-G` owns. Which rack is the datum when
two are pinned on one plan is left to that chapter for the same reason.

---

## 6. The Plan editor

A third canvas. It reuses the viewport, selection, hit-test and command machinery that the
elevation and schematic canvases already share, and it introduces no new gesture vocabulary.

**THAT LIST SAID "viewport, selection, hit-test and drag-preview" UNTIL `PLAN-E/1` TESTED IT**, and
the drag-preview entry was wrong in the direction nobody expects. `DragPreviewController`'s
vocabulary is `deviceH`, `Face`, a snapped `ruIndex` and a blocked verdict naming an occupant, all of
which are rack rails; a pin on a floorplan has no U, no face and nothing to be blocked by, so this
canvas needs **no** drag preview rather than a generalised one. The four that remain were assembled
into a working third canvas and reused verbatim. docs/12 §5.9.7 carries the measurement, including
the three pieces this sentence has never mentioned and which the canvas does need: a render object,
an image resolver and a plan scene builder.

| Gesture | Result |
|---|---|
| Drag from the device palette or staging bin onto the plan | Places the device and sets its pin in one command. **The staging-bin half has no source yet**: `StagedPlacement`'s only writer in `lib/` is the JSON decoder, so nothing a person can reach puts a device in the bin. `PLAN-E/2` builds the palette drag; the bin's drag arrives with the bin's producer, which is the rack editor's and not this view's |
| Drag an existing pin | Moves it. Any `planLowerBound` on that run recomputes. **The recompute clause is forward-dated**: `planLowerBound` is not a `ScheduleLengthSource` value yet and nothing derives one, so `PLAN-E/2` builds the move and `PLAN-G` makes the second sentence true |
| Drag a row out of the unpinned strip onto the plan | Pins it. **This is how a RACK gets its pin** (DR-140 §11.139), and it was the gesture nothing in this table had: the palette places a device, the drop table pins an outlet, and no row put a pin on the one carrier docs/15 §3.4 calls mandatory |
| Click an outlet in the Structure editor's drop table, then click the plan | Pins that outlet. This is the fast path for a 60-drop rough-in |
| Pan, zoom | Identical to the other two canvases (AC-016 #23, `CanvasIntent`). **Verified**, not assumed: `PLAN-E/1`'s spike drives both through the same `CanvasIntentDetector` both shipped canvases use |
| Marquee-select | CR-102's left-drag, with the CAD window/cross convention. **It WAS the product's first**, and this row was combined with the one above and read *"identical to the other two canvases"* until 2026-09-07, when `PLAN-E/1` found that **neither of the other two had a marquee**. DR-139 §11.138 ruled it built once and adopted on all three, and `#848` did that: the geometry is `rackpal_core/draw/marquee.dart`, the gesture and the band are `MarqueeController`, and the rack elevation, the schematic and this canvas each contribute four lines. The row is true now, and it says which files make it so |

**Layout.** Left is the underlay list and the location tree, read-only with the same *"edit in
`Project ▸ Locations…`"* affordance the Structure editor uses (CR-112). Centre is the plan. Right is
the standard inspector. There is no fourth region and no plan-specific palette; the device palette
is the device palette.

**Unpinned carriers are visible, not hidden.** A strip along the bottom lists everything in this
plan's location that could carry a pin and does not, with a count. That strip is the difference
between a plan that is trusted and a plan that is 80% complete without saying so, and it is the same
discipline the staging bin already applies to unplaced devices (CR-032). Dragging a row out of it
onto the plan pins that row.

**THIS SAID "devices" UNTIL DR-140 §11.139, AND THE OMISSION WAS THE 80%-COMPLETE PLAN IT EXISTS TO
REFUSE.** §3.4 names three carriers and marks the rack's pin *"not optional to the design"*, and no
gesture in this document put one there: the palette places a device, the drop table pins an outlet,
and the strip listed devices. So the one absent pin that costs **every** length on the plan was the
one thing the count could not see. The strip lists off-rack devices, outlets and racks alike.

**THE COUNT IS THEREFORE A COUNT OF CARRIERS, NOT OF DEVICES**, and the two differ on any document
with an unpinned rack. A strip built from `doc.devices` alone passes every test whose fixture has no
rack, which is the trap `PLAN-E/4`'s own brief already names in the status bar that read *"0
pathways"* the keystroke after somebody made one.

**AND EVERY CLAUSE OF THAT SENTENCE HID A DECISION** (DR-142 §11.141), which is why it now has three
more. **"Unpinned" is no pin AT ALL**, never "no pin on this underlay": a carrier holds one `planPin`
and it names its plan, so a row listed as unpinned here while it is pinned on `Level 1` would MOVE
that pin when dragged, silently, as the answer to a gesture that looked like adding something. **An
underlay with no `locationId` has no filter and lists everything unpinned**, because a site plan is
not a plan of an unknown room, it is a plan not scoped to a room; matching its null against a
carrier's null would be the unknown-equals-unknown join G4 forbids. **And a carrier whose own
location is unknown is a count rather than a row**, `unlocatedCount`, which is `CR-114` applied
exactly: a row would invite pinning a second-floor speaker onto `Level 1`, and silence is the
`0 pathways` defect again.

---

## 7. Rendering

The underlay draws through a `drawImage` op on `DiagramCanvas`. **It exists as of PLAN-A, 2026-09-07**,
and this paragraph said *"that op does not exist"* until then. It was added under the interface's own
amendment clause, DR-029 §11.28.6 being the amendment; RJ-017 is superseded in part (canon §12.32) and
**the logo's opacity did not come back with it**.

**What it actually touched, against the five files this paragraph predicted.** `canvas.dart`, `ops.dart`,
the bounds canvas and both backends: as predicted. **Hit-test: nothing.** `hit_test.dart` reads
`DiagramScene.hits`, which scene builders populate, and an op type reaches it through no path at all. **The
op-count baselines: nothing moved**, which is `schematic_perf_test.dart`'s own prediction holding, because
no scene emits an `OpImage` until PLAN-C. **One file nobody predicted did break, and it is the right one**:
`test/scene/op_digest.dart`'s exhaustive switch over the sealed hierarchy, which is the determinism
instrument, so the compiler required a decision about what an image contributes to *"same document, same
display list"* before anything could build. It contributes its reference and its rect.

**`OpImage` carries a container-member REFERENCE and never pixels.** A display list is compared byte for
byte and `rackpal_core` has no image decoder and must not gain one, so each backend resolves the reference
through its own resolver: `ui.Image` on screen, `PdfImage` in the export. A reference nothing resolves
**throws** rather than drawing nothing, because a `T1.01` that is a title block over white paper is
indistinguishable from a plan with no drops on it.

**The underlay prints screened.** On screen it renders at full value; on paper it renders through a
lightening pass so that black callouts stay legible over it. This is ordinary drafting practice for
a background reference, and it also protects the callouts' greyscale separation, which is what
PAL-1 gates.

**THE LIGHTENING PASS RUNS IN THE EXPORT BACKEND, AND THE STORED BYTES ARE THE ARCHITECT'S PAGE**
(DR-037 §11.36.3). DR-029 §11.28.11 said *"pre-composited at import, the way palette tints already
are"*, and a palette tint is composited at **definition** time, which would have meant the zip held a
washed-out image and the sentence above was false. It is not: the flatten and the screen both happen
where the `PdfImage` is built.

**The obligation that clause was protecting is real and is bigger than it looked.** docs/08 row 9
forbids alpha absolutely, and reading `pdf-3.13.0` found that **`PdfImage(..., alpha: true)` writes
an `/SMask`**: a PNG underlay carrying an alpha channel emits an alpha path into the document
**without anybody calling `setGraphicState`**, which is not the failure row 9 was written about. So
the underlay is flattened to opaque RGB before it becomes a `PdfImage`, `alpha: false` is the only
call shape, and no `/SMask` and no `ExtGState` is ever emitted. Doing it here rather than at import
also means the screening percentage can be changed by editing code, instead of by re-importing every
underlay in every project file a user owns.

**PAL-1 and the underlay.** `tools/pal1_check.py` enumerates signal families and checks rendered
greyscale separation pairwise (canon §14). An underlay is not a signal family and is excluded from
that enumeration. What is *not* excluded is the requirement that callout glyphs remain separable
against a non-white background, which is a new obligation the screening pass exists to satisfy.

**Callouts** carry the device designator and reuse the schematic's tag-pill geometry and the signal
domain's colour (CR-078: colour lives on the domain, never the family). A leader line is drawn only
when the pill cannot sit within its own pin's clearance.

---

## 8. How plans reach the PDF

One new sheet slot.

| Slot | Sheet | Default | Contents |
|---|---|---|---|
| `T1.01…` | **Device Location Plan** | **AUTO** | One per `PlanUnderlay` that carries at least one pin. The screened underlay fitted to the sheet, device and outlet callouts with designators, the scale bar derived from calibration, a north arrow if set, and the per-plan device schedule below |

**`AUTO` is load-bearing, not a preference.** M6's exit criterion is that all four starter projects
export a complete set, and the starters are checked-in byte-verified goldens that double as perf
fixtures and screenshot source (AC-052). If the plan sheet were `ON`, all four would need floorplans,
which would put raster into files that a byte-comparison test pins and would spend the file-size
budget AC-006 made real. `AUTO` means a project with no underlay emits no plan sheet and nothing
about M6 changes. `T6.20` and `T5.01` are already `AUTO`, so this needs no new machinery.

**The per-plan device schedule** follows the standard's own sample columns for a Floor Plan Device
Schedule: `Area Name | Reference | Item | Item Description` (research-domain-docs §). It is a
projection of the same derivation the equipment list uses, not a second table builder, for the
reason `derived/schedule.dart` states about the Pull Sheet and the Termination Schedule: two builders
agree on the day they are written and disagree by the end of the milestone.

**Drawing index.** `T1.01` sheets resolve into the index like every other slot, after the sheet list
resolves, so the index can never name a plan that is not in the file.

**The scale bar is drawn, never printed as a ratio.** A sheet is scaled to fit, so a stated ratio
like 1:50 would be wrong the moment the page size changed. A drawn bar stays correct because it
scales with the drawing.

---

## 9. Validation

Four advisories. All are `advisory`, none blocks export (CR-022, G3), and all are acknowledgeable
through the one `AckedFinding` mechanism (CR-019).

| Rule | Fires when |
|---|---|
| `PLN-001` | An underlay is uncalibrated. *"N pins carry no measurable position"* |
| `PLN-002` | Devices or outlets in a plan's location carry no pin. *"N devices in Level 1 are not on the plan"* |
| `PLN-003` | An underlay has device pins but no rack pin, so no run length is derivable from it |
| `PLN-004` | An underlay's `contentHash` does not match its stored bytes. A **warning**, never a load failure (AC-042) |

**These are v1.1 rules and do not touch the count of 27.** AC-040 pins v1's rule catalogue at 27
(canon §12.6(b)); `PLN-*` ships with the Plan view, in its own band, and any document quoting a
total says which band it is counting. Written-out counts in this corpus have needed three sweeps
already.

---

## 10. Scope and acceptance

**In, when the Plan view ships:** PNG and JPEG underlays in the zip container; two-point
calibration; pins on devices, outlets and racks; `planLowerBound` as one new `ScheduleLengthSource`
value; the Plan editor; `T1.01` as `AUTO`; the four `PLN-*` advisories.

**Out, and these are limits rather than a backlog:** ~~PDF import~~ (**bought by DR-029**); walls,
rooms or any geometry beyond the pin; **any design-time route prediction at all** (DR-020, §4); area
takeoff and coverage; reflected ceiling plans and risers (DR-005 §11.5.3); **tiled** plans, and
**multi-page underlays** (a multi-page PDF may be *imported* through §2's page picker, and exactly
one chosen page becomes one underlay, DR-037 §11.36.2); anything that reads structure out of the
image.

**Not this document's, and shipping earlier:** the as-built tally surface, `Link.spliceCount` and
the generic `LEN-002` are **v1, in M3** (DR-020 §11.19.2). They are listed here only so a reader of
§4.2 does not go looking for them in a v1.1 feature. They do not wait on a floorplan and never
did.

**Acceptance, stated so it can be run rather than asserted:**

1. A 60-drop rough-in with a calibrated plan produces a Pull Sheet in which **every length names its
   `ScheduleLengthSource`**, every `planLowerBound` row prints its `≥`, and the `none` count is
   reported rather than absorbed.
2. Opening a project whose underlay is missing from the container yields a typed error and a named
   file-layer state (AC-058/D3), never a crash and never a silently blank plan.
3. `write(read(bytes)) == bytes` holds on the zip path across a write, a reopen and a second write,
   on two machines (CR-117).
4. A project with no underlay writes bytes **identical** to what the plain-JSON path writes today.
5. A plan sheet printed on a real greyscale laser at ANSI B keeps every callout legible over the
   screened underlay, run on hardware rather than asserted (the same standard AC-054 sets for
   `T0.01`).

---

## 11. What this document does not decide

**~~Whether the Plan view is v1 or v1.1.~~ DECIDED: it is v1, before M6 (DR-029).** DR-018 placed it
in v1.1 and DR-019 discharged the condition that placement carried; the amendment this paragraph
described as *"available"* was taken on 2026-08-09, and it is an epic rather than an `M3.5`
because renumbering M6→M10 would have cost more than the sequencing constraint is worth
(§11.28.4). The paragraph is kept rather than deleted because the reasoning that made the move
legal is the reasoning that decided it.

**Whether the tablet question changes the answer.** The practice this feature replaces happens in a
notes application, plausibly on an iPad, plausibly while walking the building. RackPal is desktop;
mobile editing is v2 (roadmap §2.4) and v1 mobile is read-only on three surfaces (AC-056). A Plan
view moves this work to a desk rather than to the site. That is a real limitation, it is recorded in
the feasibility study §7, and it is a product question rather than a design one.
