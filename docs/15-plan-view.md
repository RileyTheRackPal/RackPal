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
a title block, and cannot be revised. Everything else in RackPal travels in one `.rppj` and exports
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

`.rppj` is **plain pretty JSON when the document has no binary member, and a zip container when it
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
| **A sidecar file next to the `.rppj`** | Breaks CR-091's single-file property outright, and "email the project, lose the floorplan" is the exact failure this product exists to prevent. It would also owe a new state in the file-layer error surface (AC-058/D3) |

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

**BOTH HALVES OF THE ORDINARY PATH ARE BOUGHT AS OF `PLAN-K`, 2026-09-10** (DR-153 §11.152). A page
that is one full-page image is **lifted** whole, byte for byte as the drawing office exported it, and
a page of **vectors is rendered** by a vendored pdfium: the second was refused until then, which
DR-145 §11.144.3 measured on a real AutoCAD plot and DR-138, DR-145 and DR-148 each deferred. The
population is what ended it: raster sets are the more common of the two and CAD plots are by no means
uncommon, so the refused class was ordinary rather than exceptional.

**Lifting is still preferred where it applies**, because rasterising a page whose only content is a
JPEG decodes and re-encodes it, losing a generation and gaining no pixel (DR-138 §11.137.3). A
rendered page is drawn at **300 dpi of the page's own size**, which prints at 327 dpi once `T1.01`
has fitted it, stepping down to a pixel budget rather than refusing a large sheet (§11.152.5).

**A rendered page keeps the PDF it came from** in `sources/<id>.pdf` and a lifted page does not
(§11.152.6): a lifted page's stored bytes already ARE the source, while a rendered one has thrown the
vector away and only the source can bring it back. What that keeps open is vector passthrough to the
exported sheet, which is not built and which `PLAN-J`'s print decides.

**The binary is vendored rather than downloaded** (CR-100) and is placed by a person, so nothing in a
build or in CI fetches anything.

**A multi-page PDF gets a page picker, and exactly one page becomes one underlay** (DR-037
§11.36.2). Architectural sets are multi-page and the electrical sheet is not page 1, so importing
only the first page would put the conversion step DR-029 spent 2–3 weeks buying out back on the
ordinary path. The pages are shown as a grid at thumbnail size, and the one clicked
becomes the underlay. **A lifted page and a rendered one look the same in that grid**, because the
person is choosing a drawing rather than an import mechanism; what the tile reports is the size and
resolution they would GET, never the thumbnail it just drew. **This narrows §10's exclusion rather than reversing it**: no underlay is ever
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
what keeps the paragraph above true. Writing `"underlays": {}` would add a key to every `.rppj` in
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
  int rotationQuarterTurns;    // 0..3 clockwise as seen; absent from the file at 0 (DR-184)
  FracIndex order;
  EntityMeta meta;
}
```

**`rotationQuarterTurns` ARRIVED WITH DR-184 (§11.183), 2026-09-18.** It turns the picture and never a
stored coordinate: every `PxPt` on the plan stays in the image's own pixel space and
`draw/scene/plan_turn.dart` is the one map between those pixels and the scene. A lifted PDF page takes
its value from the page's own `/Rotate`, which the lifter had been carrying down the page tree and
never reading.

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

### 3.5 `RoomOutline`, and the room estimate it fills

**BUILT AT `LEN-A`, 2026-09-11** (DR-050 §11.49). A room's shape, drawn on
one underlay as a closed polygon, stored on `Location` rather than on the
underlay because it is a fact about the ROOM.

| Field | What it is |
|---|---|
| `underlayId` | Which plan it was drawn on, for `PlanPin`'s reason |
| `vertices` | The corners, in the order drawn. **Order is the shape**: the same four points reordered is a bow tie rather than a rectangle, so it compares as a sequence |

**IMPLICITLY CLOSED.** The edge from the last corner back to the first is
implied and always exists. A stored closing vertex is a second copy of the
first, and a file whose last vertex drifted by a pixel would describe a
polygon with a hairline gap no reader would think to look for.

**THE TOOL.** Click each corner; click the first corner again to close;
right-click takes one back; `Esc` cancels the draw. The close test is in
SCREEN space, because a person aims with a mouse at what they can see and
a radius in raster pixels would be an easy target at 400% and impossible
on a plan fitted to the window.

**THE OUTLINE IS SCREEN CHROME AND DOES NOT PRINT ON `T1.01`** (§11.49.9,
`LEN-A/4`, settled at `LEN-A/7`). An outline is an estimating aid, and
`T1.01`'s criterion is that a stranger locates every drop from the printed
sheet. **The deciding fact is on the architect's drawing**: almost every
floorplan already labels its rooms, so the titles already say which space
is which and a boundary of ours would spend ink on what the sheet carries.
`buildPlanScene` therefore grows no parameter and the four byte-verified
starter goldens stay shut.

**CORRECTING ONE** is `Reshape…` on the room's row, which is a MODE and
not a live handle (§11.49.10, `LEN-A/8`). While it runs, that room's
corners drag and the canvas answers nothing else: no pin moves, no band
opens, no selection clears. A corner and a pin are both points, so a live
handle would make one of the two unreachable wherever a plate sits near a
room corner, and a stray drag would move a figure somebody is about to
quote. One command per drag, and the figure is re-derived with it.

**WHAT IT FILLS.** `Location.estimatedRunLengthFromRack`, which already
ranks below `outletNominal` and already sums, with
`estimatedRunLengthOrigin` recording that the software proposed the figure
rather than a person. The derivation is the straight line from the datum
rack's pin to the room's most distant vertex plus `riseAllowance`, and the
datum is the rack this room's runs land in (§11.49.6). **The auto-fill
never replaces a person**, and an unrecorded origin counts as a person's
(§11.49.7).

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
| **`planLowerBound`** | **BUILT AT `PLAN-G`, 2026-09-08.** Calibrated straight line, the pin on the rack **this run lands in** to the pin on its subject, plus the subject's `riseAllowance` if one is set (`derived/plan_length.dart`) | **Italic, and prefixed `≥`** |
| `none` | Nothing known | `—`, and `LEN-*` emits *"length unknown, cannot verify"* (G4) |

**It is never a takeoff number and never enters the footage rollup as a quantity.** A bound cannot
be summed into "how much Cat6 to order" without becoming a claim it is not entitled to make. The
rollup counts bound-only rows the way `Rollup.unknownCount` already counts unknowns.

**AND "THE FOOTAGE ROLLUP" IS TWO ROLLUPS, WHICH THIS SENTENCE SAID IN THE SINGULAR UNTIL `PLAN-G/3`**
(DR-147 §11.146.1). `cable_footage.dart`'s takeoff is guarded by `_isQuantity`, an exhaustive switch
with no default arm written so that adding this value stops the build until somebody decides; it
worked. `schedule.dart`'s `_footageOf` builds `ScheduleView.footage` and `ScheduleGroup.footage`,
which is docs/08 §3.8's `Σ 11 runs · 601 ft · 3 estimated` footer, and it reads a `Len?` without
asking where the number came from. **A gate's scope is part of its claim**, and a floor would have
walked into the second `Σ` with nothing to stop it. Both now refuse it and both now count it:

> `Σ 11 runs · 601 ft · 3 estimated · 2 bound`

**A BOUND ROW IS COUNTED AS AN UNKNOWN AND THAT IS NOT A DEMOTION.** The question a footage rollup
answers is how much cable to order, and a floor answers it not at all, so the row sits in
`unknownCount` exactly as a lengthless row does. `boundCount` beside it says how much of that
ignorance has a floor under it, which is strictly more than the reader had before, and `runCount`
and `unknownLengthCount` do not move.

**A FLOOR AND A GUESS ARE TWO CLAIMS AND CARRY TWO FLAGS** (§11.146.4). `lengthIsEstimated` is
**false** for a bound, because that flag is what §3.8's `3 estimated (italic)` counts, and a footer
reading `5 estimated` on three guesses and two measured floors is wrong about the one thing it
exists to say. `lengthIsBound` carries the `≥` and the exclusion, and a renderer italicises on
either. **The `≥` is in the string and the italic is not**: italic is a style a plain-text export
loses, and `41` is a number an installer cuts to.

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

**`Location.riseAllowance` READ *"DOES NOT EXIST YET"* UNTIL `PLAN-C/4` SHIPPED IT**, having been
spent by this section and by DR-020 §11.19.2(1) since 2026-08-04 against a tree where a grep returned
nothing. It is `Len? riseAllowance` on `Location`, null unknown and `0` a measured zero (G4, CR-114),
written only when present so no file on disk changes a byte.

**AND A NULL ONE COSTS THE BOUND NOTHING IT IS ENTITLED TO** (DR-147 §11.146.6). The field is null on
every location this product has ever written, so a null contributing zero is the whole of its
behaviour today, and **the result is still a true lower bound**: dropping a non-negative term from a
floor leaves a floor. That is not a G4 substitution and must not be "improved" into one. It is read
from **the subject's own location**, the outlet's or the off-rack device's, and not from the schedule
row's room, because the rise is a fact about where the device is and the row's room falls back
through a chain that can land on the far end's.

**What it is good for is `LEN-001`.** **BUILT AT `PLAN-G`, 2026-09-08** (`validation/rules_cable.dart`).
A lower bound is exactly the right input for it, because **if the bound already exceeds the limit,
the run is out of spec no matter which path it takes.** A plan can therefore prove a violation at
design time even though it can never prove compliance. That asymmetry is the whole value, and it is
stated here so nobody later "improves" the bound into an estimate.

**AND IT RUNS IN THAT DIRECTION ONLY, WHICH IS THE SENTENCE ABOVE MADE EXECUTABLE** (DR-147
§11.146.5). An unmeasured run whose floor already exceeds the limit is a proven violation with its
own message; a floor **under** the limit still emits *"length unknown, cannot verify"*, because it
says nothing about the route that will actually be pulled. The floor is deliberately **not** fed
into `knownLengthOf`, which answers *"the length this run is known to be"*: a bound admitted there
would report a run under the limit as fine, which is the compliance claim this whole section
forbids.

**THE RULES WERE NOT A HANDOFF, AND THIS PARAGRAPH USED TO IMPLY ONE.** `#639`'s brief reads *"M5
owns the rules; this task owns the input and the seam. Do not build the rules here."* It was written
on 2026-08-10 and M5 built both rules at M5-E, so the chapter is a change to shipped code. The seam
it asked to be documented also did not exist in the direction the sentence implies: `knownLengthOf`
is `terminatedLength ?? cutLength` and neither rule has ever read `ScheduleLengthSource` at all, so
*"read the bound regardless of which tier printed"* is satisfied by both rules calling
`planLowerBoundOf` themselves rather than by a second field on `ScheduleEntry`.

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

**THE PRINTED SHEET SAYS IT TOO, IN ITS OWN WORDS** (DR-151 §11.150.3). `T1.01` carries
`NOT TO SCALE · PLAN NOT CALIBRATED` where its bar would be. That is deliberately **not**
`PLN-001`'s sentence: the count is a designer's number, and the installer holding the print can
already find every drop on it. §8 carries the reasoning.

**AND THE UNCALIBRATED ROW SAYS WHAT THAT COSTS** (DR-146 §11.145.4). **BUILT AT `PLAN-F/3`,
2026-09-08.** The row read a bare `Not calibrated`, so a plan carrying thirty-nine stranded pins
printed exactly the line a plan with none printed, which is the flattering half G4 exists to refuse.
It now reads:

> Not calibrated · 39 pins carry no measurable position

which is §9's own `PLN-001` sentence, written once in `derived/plan_measurability.dart` so that the
row and the advisory `PLAN-I` will file cannot drift apart. **A plan with nothing stranded says only
the state**, because the count is the cost and an empty plan has not incurred one.

**THE COUNT IS THE SAME POPULATION IN BOTH DIRECTIONS** (§11.145.5), so thirty-nine unmeasurable
becomes thirty-nine measurable. Counting the rack as well would print forty and then thirty-nine,
and a number that drops by one at the moment of a calibration reads as a pin the calibration ate;
the rack is the datum on both sides and is in neither count.

**AND NEITHER FACT BLOCKS THE OTHER, WHICH IS NOW PROVEN AS A GESTURE RATHER THAN AS A DEFAULT.**
Every plan fixture in `rackpal_ui` is built without a scale, so every pin gesture the suite ran was
already a pin on an uncalibrated plan and passed for a reason nobody had named, while a pin on a
CALIBRATED plan was exercised nowhere. `PLAN-F/3` drags a rack out of the strip in both states: the
pin lands either way, the uncalibrated plan is exactly as uncalibrated afterwards, and the scale
comes back byte for byte. A gate would be a disabled strip row or a refused drop, and neither is
visible to a case that talks to the document.

**Recalibration is a document command like any other** and is undoable. It changes every derived
length on that plan at once, which is exactly why it goes through the command stack and not through
a settings field.

**AND WHAT IT REPORTS BACK IS A COUNT OF PINS, NOT OF LENGTHS** (§11.143.3). **BUILT AT `PLAN-F/2`,
2026-09-08** (`derived/plan_measurability.dart`), because at `PLAN-F`
there are no derived lengths to change: `planLowerBound` is `PLAN-G`'s and §6's pin-drag row already
forward-dates its recompute clause. A report counting schedule rows would print `0` on every
calibration in the product, which is a G4 report whose number is an artifact of what is unbuilt. So
the report names how many pins a length could now be derived for, and when none can, the reason:

> Calibrated Level 1. 12 pins can now be measured from the rack.

> Calibrated Level 1. No rack is pinned on this plan, so no length derives yet.

**The derivation produces no `Len`.** One per pin would be `planLowerBound` shipped early under
another name, without the rank, the `≥` prefix, the italic, the rollup exclusion or `LEN-001`'s
reading, which are five decisions §4.1 already took and `PLAN-G` owns. Which rack is the datum when
two are pinned on one plan is left to that chapter for the same reason. **The test for that boundary
is a property rather than a comment**: moving every pin changes nothing the derivation reports, and
neither does multiplying the typed distance by twelve.

**IT IS SAID TWICE, ON TWO SURFACES, BECAUSE OF AN ASYMMETRY.** The underlay row carries the standing
fact, `Calibrated · 12 measurable` or the one act still blocking a length, and that is the half that
still answers tomorrow. A snack bar on commit carries the act. A **first** calibration changes the row
so the act is visible; a **recalibration leaves that line reading exactly the same**, twelve
measurable before and twelve after, so only the message can report the most consequential edit the
feature has. `PLAN-F/2` builds both and docs/12 §5.9.16 carries the reasoning.

**THE BLOCKER IS NAMED RATHER THAN COUNTED AS ZERO.** `Calibrated · 0 measurable` is true and tells
nobody anything; `Calibrated · no rack pinned` names the act that unblocks every length on the plan,
directly above the strip that performs it. The blockers are ordered by remedy, so a plan that is
uncalibrated and rackless and empty reports the one thing to do now.

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
| Drag an existing pin | Moves it. Any `planLowerBound` on that run recomputes. **Both sentences are true as of `PLAN-G`, 2026-09-08**, and the second was forward-dated until then: the tier now exists, `planLowerBoundOf` derives one, and the schedule is rebuilt from the document on the shell's own notification, so a moved pin moves the row |
| Drag a row out of the unpinned strip onto the plan | Pins it. **This is how a RACK gets its pin** (DR-140 §11.139), and it was the gesture nothing in this table had: the palette places a device, the drop table pins an outlet, and no row put a pin on the one carrier docs/15 §3.4 calls mandatory |
| Click an outlet in the Structure editor's drop table, then click the plan | Pins that outlet. This is the fast path for a 60-drop rough-in |
| Pan, zoom | Identical to the other two canvases (AC-016 #23, `CanvasIntent`). **Verified**, not assumed: `PLAN-E/1`'s spike drives both through the same `CanvasIntentDetector` both shipped canvases use |
| Marquee-select | CR-102's left-drag, with the CAD window/cross convention. **It WAS the product's first**, and this row was combined with the one above and read *"identical to the other two canvases"* until 2026-09-07, when `PLAN-E/1` found that **neither of the other two had a marquee**. DR-139 §11.138 ruled it built once and adopted on all three, and `#848` did that: the geometry is `rackpal_core/draw/marquee.dart`, the gesture and the band are `MarqueeController`, and the rack elevation, the schematic and this canvas each contribute four lines. The row is true now, and it says which files make it so |

**Layout.** Left is the location tree, with the underlay list above it once the project has a
floorplan. The open plan's row carries `Calibrate…`, a turn left and a turn right (DR-184 §11.183.4,
also `Ctrl+Shift+Minus` and `Ctrl+Shift+Plus`), and `Remove…`; a turn holds the spot under the
middle of the canvas and keeps the zoom (§11.183.5). Centre is the plan. Right is the standard inspector, showing the selected room and, when
a plan is open, its outline on that plan. There is no fourth region and no plan-specific palette;
the device palette is the device palette.

**THIS PARAGRAPH SAID THE TREE WAS READ-ONLY HERE, with an *"edit in `Project ▸ Locations…`"*
affordance, until DR-168 §11.167 (2026-09-13).** It had the tree in this rail from the chapter
brief, which is most of the merge already decided; what it withheld was the editing, and the route
it named instead had been deleted when DR-091 §11.90 promoted Locations to a tab. The view is
called `Site` now and is the first tab, the tree is edited in it, and the three regions are
unchanged in number.

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

### 7.0 The mark, which is what a person actually reads

**BUILT AT `#897`, `#901` and `#902`, 2026-09-14** (DR-169 §11.168). Three facts, three channels,
and each answers a different question.

| Channel | What it says | Why that channel |
|---|---|---|
| **Shape** | Which CARRIER: a rack is a square with a cross, an outlet a plain circle, a device a circle at a heavier ring weight | The rack is the datum every length is measured from (`PLN-003`), so it must not read as one more dot. The device's ring replaced an inner dot, which is where the glyph now sits |
| **Colour** | Which signal DOMAIN, from CR-078's own hue | Colour lives on the domain and nowhere else. The value is authored on the template, never derived: of 51 seeded templates only 13 have ports in one domain (§11.168.5) |
| **Glyph** | The same domain again, in ink | Canon §14 records that the eight hues **collide in greyscale by design**, three inside one luminance band, and `plan_sheet.dart` splices this scene into a `T1.01` the Installer preset prints greyscale. PAL-3 separates a LINE by dash and weight; a filled dot has neither |

**THE MARK STICKS AT A FLOOR SIZE AND GROWS WITH THE PLAN ABOVE A CROSSOVER** (DR-183 §11.182.1,
`#910`, 2026-09-17). Its radius is the larger of **11 screen points** and **1/200 of the plan**, so
below the crossover it is a constant size a pointer can aim at and above it a fixed piece of the
drawing that covers the same floor at any zoom. The plan's size for that fraction is the
**geometric mean of the underlay's two pixel dimensions and not its longer side**, which is the
anchor §11.168.10 measured going wrong on paper: one fraction printed 6.87 points on a 2000x1500
plan, 5.15 on 1500x2000 and 10.20 on a 4000x1000 panorama, because a fit binds on the tighter axis
while the fraction reads the longer one.

**THIS PARAGRAPH READ "A CONSTANT SIZE IN SCREEN POINTS, AT EVERY ZOOM" UNTIL `#910`**, which was
`#897`'s rule, and DR-183 keeps that half rather than reversing it: the floor is where the
reachability argument lives, and it is the rule `kOutlineCloseRadiusPt` already states for the close
test. What came back is the proportional rule §11.168.2 retired, bounded this time, because a mark
that never grows stops belonging to the drawing once somebody is inside one room. **The retired
fraction was 1/110 of the underlay's LONGER side in SCENE units with no floor at all**: on a
3300-unit architectural sheet a **60-point mark at 1:1** with a hit box to match, reported from the
product as *"the pin size on the room view is massive"*, and four times that again at 400%.

**AND IT TOOK TWO GOES, BECAUSE THE SCREEN HAS TO REBUILD AND NOT ONLY REPAINT.** `#897` divided the
point size by the zoom in `build`, and `RenderPlanCanvas` listens to the viewport with
`markNeedsPaint`, so a zoom redrew the scene already in the tree and the mark was **7 points at 1:1
and 28 at 400%** for a day. `#903` made the canvas rebuild on a change of scale, as
`PlanOutlineLayer` and the rack canvas both already did.

**ON PAPER A MARK IS THE ROUND END OF ITS CALLOUT PILL** (§11.168.10, `#904`). This paragraph said
the sheet's half of the clause was unbuilt, and it was: `plan_sheet.dart` passed no radius and took
1/110 of the underlay's longer side, which printed at 6.87 points on a 2000x1500 plan and 5.15 on
1500x2000. The sheet now divides `kPlanMarkPrintRadiusPt` by its own fit, and that constant is
derived from the pill's height rather than written beside it, so a pill `PLAN-J`'s print re-tunes
carries the mark with it.

**AND ITS LINE WEIGHT IS CONSTANT ON BOTH SURFACES** (§11.168.11, `#905`). A drop is outlined at the
base signal weight on paper and one pixel on screen, and a device is ringed at twice that, at every
zoom and on every scan. Both were a stroke of 2 scene units that rode the fit and the zoom, and on a
6600x5100 scan a device printed exactly like a drop. The strokes are emitted with
`scaleWithGeometry: false`, and `RenderPlanCanvas` passes its zoom to `FlutterDiagramCanvas` as
`outerScale`, because the zoom sits in a transform layer the canvas's own stack cannot see. The ring
stays under about 37% of the radius, so it never reaches the corners of Network's square glyph.

**AN UNKNOWN DOMAIN DRAWS THE NEUTRAL MARK AND NO GLYPH** (G4/CR-114), and is never filled in from
the ports. That is a real state: the three passive panels carry no signal at all, an outlet built by
hand belongs to no recipe, and the three TIA-570-D grades are cabling standards rather than services.

**THE DESIGNATOR IS A HOVER, NOT A LABEL BESIDE EVERY MARK** (§11.168.7). Sixty drops in one room is
sixty labels over somebody else's drawing. It is **chrome and not scene**: a designator emitted into
the display list would print on `T1.01` for whichever mark the pointer was over when the export ran,
and §7's printed callout is a different thing with a different lifetime.

**And the plan opens FITTED**, with a `Fit` control to return to (§11.168.3). It opened at 100%
anchored to its top-left corner until `#898`, where the rack editor and the schematic have both
called `fitToContent` since M2.


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

**THE UNDERLAY PRINTS AT 25% AND THE NUMBER IS A LASER'S TO CONFIRM** (DR-149 §11.148.4).
**BUILT AT `PLAN-H/1`** as `kUnderlayInkRetained` in `rackpal_export/src/draw/plan_image.dart`, one
constant, integer per-mille (CR-001) so no float reaches a document two machines compare byte for
byte. Chosen over 18%, the legend chip's tint, because a chip is a swatch behind one rule and a
floorplan is line art whose walls and dimension strings must survive; and over 40%, because the
callout has to win. **AC-054's standard is a print on a real greyscale laser at ANSI B**, so
`PLAN-J`'s drill is the evidence and moving this afterwards is expected rather than a defect.

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
call shape, and no `/SMask` and no `ExtGState` is ever emitted. **ASSERTED OVER THE FUNCTION THAT
BUILDS ONE IN PRODUCTION**, which did not exist until `PLAN-H/1`: `PLAN-A/3` proved the canvas emits
no alpha path when handed an opaque image, and `plan_image_test.dart` now proves the resolver never
asks for one. **A transparent pixel becomes paper**, composited against white before the screen
rather than discarded, because a PNG exported from CAD usually has black under its transparency and
discarding it would print a solid bar across the sheet.

**AND THE EXPORT PATH COULD NOT REACH AN UNDERLAY AT ALL UNTIL THAT CHAPTER** (DR-149 §11.148.1).
`ExportRequest` carried the document JSON and the fonts and nothing else, so `PdfImageResolver` had
**zero production call sites** from `PLAN-A` to `PLAN-H`, which is `PLAN-E/1`'s finding one package
over. `ExportRequest.members` is the door and `planImageResolver` is the implementation. Doing it here rather than at import
also means the screening percentage can be changed by editing code, instead of by re-importing every
underlay in every project file a user owns.

**PAL-1 and the underlay.** `tools/pal1_check.py` enumerates signal families and checks rendered
greyscale separation pairwise (canon §14). An underlay is not a signal family and is excluded from
that enumeration. What is *not* excluded is the requirement that callout glyphs remain separable
against a non-white background, which is a new obligation the screening pass exists to satisfy.

**AND IT IS NOW CHECKED RATHER THAN OWED** (DR-150 §11.149.4). **BUILT AT `PLAN-H/3`.** The gate's
own exclusion block carried `CALLOUT_OVER_UNDERLAY_IS_CHECKED_AT = 'PLAN-H/3'` from `PLAN-A/5`; this
is that check. It is decidable because the screening is a constant, so the worst case is one number:

> callout over the screened underlay: black on 192 (ink retained 250 per-mille) is 11.54:1, floor 4.5:1

The gate **parses `kUnderlayInkRetained` out of `plan_image.dart`** rather than keeping a second copy,
on `registry_parity.py`'s precedent for a Python gate reading Dart. The break-even is **550
per-mille**: at 540 it passes, at 560 it fails at 4.30:1. canon §14.1 is why it is arithmetic and not
an eye, since PAL-1 shipped collisions three times from being checked by inspection.

**Callouts.** **BUILT AT `PLAN-H/3`, 2026-09-09** (`draw/sheet/plan_callouts.dart`). A leader line is
drawn only when the pill cannot sit within its own pin's clearance.

**THIS PARAGRAPH ASKED FOR TWO THINGS THAT DO NOT EXIST, AND DR-150 §11.149 RULED BOTH.** It read
*"carry the device designator and reuse the schematic's tag-pill geometry and the signal domain's
colour (CR-078)"*.

**A pin carries no domain.** `Rack` and `Outlet` hold no `SignalFamilyId` at all and an off-rack
device spans several, so a television is video **and** network; §6's own marker row already said so at
`PLAN-E/2`, one chapter after this sentence was written. AC-054 prints the sheet greyscale in any
case. So a callout has **no colour**: an opaque white stadium, a black hairline outline, black text.
Carrier kind stays in the marker shape.

> **THE FIRST SENTENCE EXPIRED ON 2026-09-14 AND THE CONCLUSION DID NOT** (DR-169 §11.168.5,
> `#900`). A pin carries a domain now: `TemplateBody.primaryDomain` and
> `OutletTemplate.primaryDomain` are **authored** fields, and `planPinDomainFor` resolves one for
> every pin through the carrier it hangs on. The observation that a television *spans* several
> domains is exactly why the field is authored rather than derived, and the census is on the model
> field: of 51 seeded templates only **13** have ports in a single domain.
>
> **The callout stays colourless, on its OTHER leg.** *"AC-054 prints the sheet greyscale in any
> case"* is untouched, and it was always sufficient on its own. What changed is that the MARKER is
> now coloured on screen and carries the domain's **glyph**, which is what survives the greyscale
> the callout was already conceding to (§11.168.6). Carrier kind still stays in the marker shape,
> and that sentence is untouched too.

**The fill is a knock-out and not a contrast device.** Black on the darkest sample the screening can
leave is 11.5:1, so luminance was never the risk; dense line work is, and it fails by **pattern**. A
dimension string crossing a designator is unreadable at any ratio.

**And the pill could not be reused.** `_PillSizer` is private to `rackpal_ui`, which `rackpal_export`
may never import: the layering debt recorded since 2026-07-28 that leaves M6's interconnect sheets
unbuildable. The **reasoning** is taken and cited at each site, and the file stays M6's.

**IT PRINTS THE CARRIER'S OWN DESIGNATOR**, `RK-1`, `WP-1`, `TV-1` (§11.149.3). The exit criterion
asks for *"the designator its Pull Sheet row prints"*, and a pinned outlet has **several** such rows,
because a row is a `Link` and a drop can carry three cables. A carrier whose designator is blank gets
its marker and no pill: an empty pill is a white box that says nothing (G4).

**A CALLOUT IS NEVER DROPPED, AND A CROWDED SHEET SAYS SO** (§11.149.5). Placement takes the preferred
offset, walks a ring when that box overlaps one already placed, and draws a leader once it has moved.
**Twenty coincident drops all place clear and crowding starts at twenty-four**, measured rather than
argued. Past that the pill is drawn overlapping and the export raises a notice naming how many: an
absent callout is a drop the stranger cannot find, an overlapping one is a drop they can read twice.

---

## 8. How plans reach the PDF

One new sheet slot.

| Slot | Sheet | Default | Contents |
|---|---|---|---|
| `T1.01…` | **Device Location Plan** | **AUTO** | One per `PlanUnderlay` that carries at least one pin. The screened underlay fitted to the sheet, device and outlet callouts with designators, the scale bar derived from calibration, a north arrow if set, and the per-plan device schedule below. **BUILT AT `PLAN-H/1`, 2026-09-09** (`draw/sheet/plan_sheet.dart`, `SheetRole.devicePlan`, ANSI B landscape): the slot, the fitted underlay, the screening and a marker per pin. The callouts landed at `PLAN-H/3`, the drawn bar at `PLAN-H/4` and the schedule at `PLAN-H/5`, all on 2026-09-09. A north arrow has no field on `PlanUnderlay` to read and is not scheduled |

**`AUTO` is load-bearing, not a preference.** M6's exit criterion is that all four starter projects
export a complete set, and the starters are checked-in byte-verified goldens that double as perf
fixtures and screenshot source (AC-052). If the plan sheet were `ON`, all four would need floorplans,
which would put raster into files that a byte-comparison test pins and would spend the file-size
budget AC-006 made real. `AUTO` means a project with no underlay emits no plan sheet and nothing
about M6 changes. `T6.20` and `T5.01` are already `AUTO`, so this needs no new machinery.

**The per-plan device schedule** follows the standard's own sample columns for a Floor Plan Device
Schedule: `Area Name | Reference | Item | Item Description` (research-domain-docs §). It is a
projection rather than a second table builder, for the reason `derived/schedule.dart` states about
the Pull Sheet and the Termination Schedule: two builders agree on the day they are written and
disagree by the end of the milestone.

**BUILT AT `PLAN-H/5`, 2026-09-09** (`derived/plan_schedule.dart`,
`draw/sheet/plan_schedule_band.dart`), and **what it projects is not the equipment list**
(DR-152 §11.151.1). `EquipmentList` is one row per `DeviceInstance`, and a plan pins three carriers
(§3.4) of which two are not devices: on a rough-in, outlets are most of what is pinned. The row
subject is a **pinned carrier**, so the schedule projects `planPinsFor` and `planPinLabelsFor`, which
`PLAN-H/3` already built for the callouts. **The reference column is therefore literally the string
the pill prints**, and a reader going from a callout to a row cannot meet two spellings of one
designator. Each remaining column reads whichever derivation owns that carrier: `computePlateFill`
for an outlet, `EquipmentRow` for a device, the rack's own height for the rack.

**Every callout resolves, the rack included** (§11.151.3). A reader who finds `RK-1` on the plan and
nothing in the table beneath it has hit the one dead end this sheet exists to prevent.

**It is set in four blocks across, and the measurement is the argument** (§11.151.4): the drawing
area is 1122 × 567 pt and a row is 12 pt, so a single column of sixty needs 734 pt and does not fit
on a 567 pt area at all. Four blocks put sixty rows in 194 pt and leave the plan 373. The band takes
what it needs and never more than 45% of the drawing area, and **past that cap of eighty rows it
prints what fits and states how many it did not** (G4), which also reaches the export summary as a
notice naming the sheet.

**Drawing index.** `T1.01` sheets resolve into the index like every other slot, after the sheet list
resolves, so the index can never name a plan that is not in the file.

**AND `AUTO` LIVES IN A DEFAULT ARGUMENT, WHICH IS WHY M6 IS UNTOUCHED.** `SheetSet.forRacks` takes
`planUnderlays` defaulting to empty, so a project with no floorplan resolves the identical set it
resolved before the role existed, and `ExportRequest.members` defaults the same way. The four
starters are byte-verified goldens (AC-052) and none of them changes.

**WHERE IT SITS IS A RULING AND NOT A NUMBER** (DR-149 §11.148.3): after `T0.02`, before the
elevations, because a reader orients in the building before they open a rack. docs/08 §2.2's table
is not ordered numerically anyway, `T5.01` sitting last at `n+5`, and **that table had no row for
`T1.01` at all** until `PLAN-H/1` added one.

**The scale bar is drawn, never printed as a ratio.** A sheet is scaled to fit, so a stated ratio
like 1:50 would be wrong the moment the page size changed. A drawn bar stays correct because it
scales with the drawing. **BUILT AT `PLAN-H/4`, 2026-09-09** (`draw/sheet/plan_scale_bar.dart`):
four alternating segments with `0` and the round total labelled, a length chosen from a ladder in the
project's own units (CR-097), largest that fits a quarter of the drawing width.

**AND IT IS NEVER REFUSED FOR SCALE** (DR-151 §11.150.5). When no ladder entry fits the budget the
smallest is taken anyway: a bar longer than a quarter of the sheet is still true, and a bar refused
for being awkward is a sheet with no bar on a plan that has a scale. The only refusal is the
uncalibrated one.

**AN UNCALIBRATED PLAN GETS NO BAR AND THE SHEET SAYS WHY ITSELF** (§11.150.2, §11.150.3):

> `NOT TO SCALE · PLAN NOT CALIBRATED`

**§9's plan for this did not reach the reader.** `PLN-001` is a **finding**: it lands in the
validation drawer and, at M6, on `T0.02 Exceptions and Acknowledgements`. The person holding the
printed `T1.01` has neither, and `SheetRole` has four values today, none of them `T0.02`. `NOT TO
SCALE` is the half that matters to that reader because it names the one thing they must not do with
the page, and the plan still locates every drop: pins and callouts need no scale at all (§1).

---

## 9. Validation

Four rules, **in their own band** and not in docs/02 §5's catalogue (DR-154 §11.153.2). None blocks
export (CR-022, G3) and all are acknowledgeable through the one `AckedFinding` mechanism (CR-019).

**BUILT AT `PLAN-I/1`, 2026-09-10** (`validation/rules_plan.dart`, `kPlanRules`). The band is
separate and the machinery is not: `kRulesById` spans both, `evaluateDocument` runs both, and a
`PLN-*` finding takes an override, an `off` and an acknowledgement through exactly the steps every
other finding does (§11.153.3).

**PROVED AT `PLAN-I/2`, AND THE TWO SENTENCES ABOVE ARE WHY THAT IS NOT THE SAME THING** (§11.153.3a,
§11.153.5a). *"None blocks export"* and *"all are acknowledgeable through the one mechanism"* were
each asserted by a sweep over `kRuleCatalogue`, which is one catalogue of two: neither reached a
`PLN-*`. Both sweeps now cover both bands and count what they reached, a real acknowledgement is
shown demoting a real finding, and a document firing all four still exports a sheet set with `T1.01`
read off the page.

**AND THE ISSUES PANEL COULD NOT NAME ANY OF THEM** (§11.153.8a). `locusLabel` knew four entity kinds
and the rules point at six, so every `PLN-*` grouped under `No single location` while the surface's
own guard promised a fifth kind would fail loudly. A plan's locus is its `name`: it has no
designator, because it is a drawing of the building rather than equipment in it.

**THREE ARE ADVISORIES AND `PLN-004` IS A WARNING** (§11.153.5). The first three say *you have not
done this yet*; the fourth says *what you are looking at may not be what you measured*.

| Rule | Severity | Fires when |
|---|---|---|
| `PLN-001` | `advisory` | An underlay is uncalibrated. *"N pins carry no measurable position"*. **The sentence and its count are built** (`PLAN-F/3`, `unmeasurablePinsSentence`), and the underlay row prints them today; what `PLAN-I` adds is the finding, its severity and its band |
| `PLN-002` | `advisory` | Devices or outlets on this plan's floor carry no pin. *"N devices in Level 1 are not on the plan"*. **THE SUBTREE, NOT THE EXACT LOCATION** (§11.153.7a): an underlay depicts a floor and the drops are filed in its rooms. The same population the unpinned strip lists, because the strip is where a person goes to fix this |
| `PLN-003` | `advisory` | An underlay has device pins but no rack pin, so no run length is derivable from it. Fires whether or not the plan is calibrated: the missing datum is the fact |
| `PLN-004` | `warning` | An underlay's `contentHash` does not match its stored bytes, so the pins and the calibration may no longer line up with the image. Never a load failure (AC-042) |

**These are v1.1 rules and they do not touch the DRC catalogue's count.** AC-040 sized that
catalogue and docs/02 §5 lists it; `PLN-*` ships with the Plan view, in its own band, and **any
document quoting a total says which band it is counting**.

**THE TOTAL IS NOT RESTATED HERE, AND THIS SENTENCE IS WHY** (DR-154 §11.153.1). It read *"do not
touch the count of 27"* while the catalogue held twenty-nine, because DR-020 added `LEN-002` and
DR-132 restored `ELE-005` and a sentence does not move with a list. The arithmetic lives in
`rule_catalogue_test.dart`, which states it tier by tier and checks it against docs/02 §5.

The plan band is gated the same way: `plan_rules_test.dart` parses this table and compares it with
`kPlanRules`, and each of the four has an AC-051 pair of its own (§11.153.4). Each pair also reports
the label the issues panel would print for every finding it produced, which is where `locusLabel`'s
missing arms were found (§11.153.8a).

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
