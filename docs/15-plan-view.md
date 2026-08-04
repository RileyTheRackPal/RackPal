# The Plan View

The Plan view is RackMate's answer to the question a schedule cannot answer: **where**. A pull sheet
says that `W044` runs from `RK-1 / U14 / rear` to `Great Room / TV wall / WP-1` and gives the
installer everything except the one thing they are standing in the building to find out, which is
which wall. This document defines the floorplan underlay, the pin that puts a device on it, the
calibration that turns pixels into a real distance, the length model that keeps a measured distance
from being mistaken for a cable length, the editor, and the sheet the whole thing exports to. It
cross-references [Data model](02-data-model.md) for entity definitions rather than restating them
and cites the governing ruling ID for every decision; the adjudications are in
[the canonical decision record](canonical-decisions.md), which is normative.

**Status.** Ruled into v1.1 by **DR-018**, with its container shape and its one v1 obligation ruled
by **DR-019**. Not built. The feasibility study and cost are in
[research/feasibility-plan-view.md](research/feasibility-plan-view.md).

---

## 1. What a plan does that a schedule cannot

Three things, and only three. Naming them narrowly is what keeps this document from describing a
CAD program.

**It answers "which wall".** A room name plus an outlet designation identifies a drop to somebody
who already knows the house. A dot on a plan identifies it to somebody who does not, which is the
person actually pulling wire at seven in the morning.

**It makes a length measurable rather than assumed.** AC-024 gave every room one number,
`Location.estimatedRunLengthFromRack`, and that number is honest about being an estimate. A
calibrated plan with the rack pinned on it can do better for the runs that matter, and can say
which tier each number came from.

**It survives the handoff.** The current practice this replaces is coloured dots in a notes
application. That artifact is not in the project file, is not in the sheet set, does not print with
a title block, and cannot be revised. Everything else in RackMate travels in one `.rmpj` and exports
into one drawing set; a plan that does not is not worth building.

**What it is explicitly not**, and these are limits, not omissions:

| Not this | Why |
|---|---|
| A CAD editor | No walls, no dimensions, no drawing tools beyond the pin and the route polyline. The underlay is a picture and stays one |
| A room-geometry model | Rooms are the `Location` tree (CR-047) and stay there. A plan does not define, contain or imply a room |
| An area takeoff | No square footage, no coverage circles, no speaker-layout arithmetic |
| A reflected ceiling plan or riser diagram | Out, per DR-005 §11.5.3, and unaffected by DR-018 |
| A replacement for the Pull Sheet | `T6.10` is the deliverable (G1). The plan is a locator |

---

## 2. The container

Ruled by **DR-019**. Stated here because every other section depends on it.

`.rmpj` is **plain pretty JSON when the document has no binary member, and a zip container when it
does**. The discriminator already exists: `persistence/codec.dart` sniffs `PK\x03\x04` today and
returns `UnsupportedZipContainerError`, a typed error written precisely so a container could arrive
later without a crash. That sniff becomes the branch it was always shaped to be.

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

**Raster formats accepted: PNG and JPEG.** PDF is not read. The `pdf` package writes documents and
does not import pages (docs/08 §1.1), so a PDF floorplan would require PDFium or a WinRT path, and
either puts a multi-megabyte native binary into a self-signed portable distribution (DR-006) or owes
a `docs/13` entry against DR-009. The user exports a page to an image first. PDF import stays
available as a later increment that changes no stored format.

---

## 3. Data model

Four additions. All are additive, all use absent-key-is-unknown (G4, CR-114), and none changes an
existing field's meaning.

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
sheet **without decoding the image**. That keeps `rackmate_core` free of an image decoder, which
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

## 4. Length: what a plan may claim, and what it may not

This is the section G4 governs and the one most likely to be got wrong, because the wrong version is
easier to build and looks better.

**A straight line between two pins is not a cable length.** It ignores rise and drop, it ignores the
path around a stairwell, it ignores the service loop, and it is systematically short. A number that
is systematically short, presented as exact, is worse than no number: it is the failure AC-039 and
G4 exist to prevent, and it reaches a job site as a cable that does not make it.

**Four tiers, each tagged, none silent.**

| Tier | Source | Renders |
|---|---|---|
| 1 · **Measured** | The user drew a route polyline on a calibrated plan. Sum of calibrated segments, plus the location's rise allowance | Roman. This tier does not exist today at all |
| 2 · **Plan estimate** | Calibrated straight-line pin-to-pin × `routingFactor`, plus rise and slack allowances | **Italic**, per AC-024 |
| 3 · **Room estimate** | `Location.estimatedRunLengthFromRack`, unchanged | **Italic**, per AC-024 |
| 4 · **Unknown** | No plan, no room number | `—`, and `LEN-*` emits *"length unknown, cannot verify"* (G4) |

**AC-024 is extended, not replaced.** `Location.estimatedRunLengthFromRack` stays exactly as it is
and remains the answer for every room without a plan. The tiers resolve in order and each row of the
schedule reports which tier produced it. The footage rollup already reports its unknown count
(G4); it gains a per-tier breakdown for the same reason.

**The allowances are visible numbers, not hidden constants.**

- `routingFactor` is project-level, default **1.0**, meaning the product does not inflate a
  straight line unless a human tells it to. A default above 1.0 would be the product quietly
  guessing at building geometry.
- `riseAllowance` is per `Location`: the vertical drop or rise from the plan's plane to the device.
  This is the number a plan structurally cannot see, and asking for it once per room is the same
  ninety-seconds-of-input trade AC-024 already made and won.
- `slackAllowance` is project-level, applied once per run.

Every one of them appears in the equipment list's footage rollup with its value, so a reader can
reconstruct any number on any sheet.

---

## 5. Calibration

Two picked points and one typed distance. Nothing else, and specifically no attempt to read a scale
bar out of the image.

The interaction: `Calibrate…`, click two points that span a distance you know, type it. The obvious
choice on a residential plan is a dimensioned wall; the fallback is a door, which is 32 or 36 inches
in almost all of this work and is the one thing on every floorplan whose real size the user knows
cold.

**Until an underlay is calibrated, pins may be placed and no length derives.** Placement is useful on
its own, because "which wall" does not require a scale. `PLN-001` reports the uncalibrated state as
an advisory rather than blocking anything (CR-022, G3).

**Recalibration is a document command like any other** and is undoable. It changes every derived
length on that plan at once, which is exactly why it goes through the command stack and not through
a settings field.

---

## 6. The Plan editor

A third canvas. It reuses the viewport, selection, hit-test and drag-preview machinery that the
elevation and schematic canvases already share, and it introduces no new gesture vocabulary.

| Gesture | Result |
|---|---|
| Drag from the device palette or staging bin onto the plan | Places the device and sets its pin in one command |
| Drag an existing pin | Moves it. Lengths in tier 1 and 2 recompute |
| Click an outlet in the Structure editor's drop table, then click the plan | Pins that outlet. This is the fast path for a 60-drop rough-in |
| `Route…` on a selected link, then click along the plan | Draws the route polyline. Promotes that link to tier 1 |
| Pan, zoom, marquee-select | Identical to the other two canvases (AC-016 #23, `CanvasIntent`) |

**Layout.** Left is the underlay list and the location tree, read-only with the same *"edit in
`Project ▸ Locations…`"* affordance the Structure editor uses (CR-112). Centre is the plan. Right is
the standard inspector. There is no fourth region and no plan-specific palette; the device palette
is the device palette.

**Unpinned devices are visible, not hidden.** A strip along the bottom lists devices in this plan's
location that carry no pin, with a count. That strip is the difference between a plan that is
trusted and a plan that is 80% complete without saying so, and it is the same discipline the staging
bin already applies to unplaced devices (CR-032).

---

## 7. Rendering

The underlay draws through a new `drawImage` op on `DiagramCanvas`. **That op does not exist**, is
excluded by RJ-017, and the interface's own header forbids adding a method without an amendment.
Adding it is part of building this feature and is costed in the feasibility study §3.1; it touches
`canvas.dart`, `ops.dart`, the bounds canvas, both backends, hit-test, and the op-count baselines
that are M2-C's record.

**The underlay prints screened.** On screen it renders at full value; on paper it renders through a
lightening pass so that black callouts stay legible over it. This is ordinary drafting practice for
a background reference, and it also protects the callouts' greyscale separation, which is what
PAL-1 gates.

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
calibration; pins on devices, outlets and racks; the route polyline; the four-tier length model with
its allowances; the Plan editor; `T1.01` as `AUTO`; the four `PLN-*` advisories.

**Out, and these are limits rather than a backlog:** PDF import; walls, rooms or any geometry beyond
the pin and the polyline; area takeoff and coverage; reflected ceiling plans and risers (DR-005
§11.5.3); multi-page or tiled plans; anything that reads structure out of the image.

**Acceptance, stated so it can be run rather than asserted:**

1. A 60-drop rough-in with a calibrated plan produces a Pull Sheet in which **every length names its
   tier**, and the tier-4 count is reported rather than absorbed.
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

**Whether the Plan view is v1 or v1.1.** DR-018 places it in v1.1 and DR-019 discharges the condition
that placement carried. Pulling it into v1 as an `M3.5` remains available and is a further amendment
under roadmap §8.3, to be taken or declined after M3 lands, when the field-device model has been
used rather than only designed.

**Whether the tablet question changes the answer.** The practice this feature replaces happens in a
notes application, plausibly on an iPad, plausibly while walking the building. RackMate is desktop;
mobile editing is v2 (roadmap §2.4) and v1 mobile is read-only on three surfaces (AC-056). A Plan
view moves this work to a desk rather than to the site. That is a real limitation, it is recorded in
the feasibility study §7, and it is a product question rather than a design one.
