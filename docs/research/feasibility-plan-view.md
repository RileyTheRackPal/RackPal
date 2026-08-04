# Feasibility · the Plan view

**Written 2026-08-04, against the tree at `ff61aa7`.** Unlike the rest of this directory, this
paper was not produced by the original research pass. It was written after M2 closed, against
code that exists, in response to a user request for a feasibility check and an estimate. Where it
cites a file and a line, that citation was read rather than recalled.

**The question asked.** A "Plan" view that accepts an uploaded PDF or similar document of a
floorplan, allows field devices to be placed on it, and drives a full pull schedule and diagram
set from those placements. The stated motivation: the system designer currently places coloured
dots in the iOS Notes app over the locations that need wiring, and the result is that somebody
inevitably does something incorrectly.

**The answer in one line.** Technically feasible, and the domain model is unusually well prepared
for it. The cost is not in the model and not in the schedule. It is in the fact that no part of
this codebase has ever handled a bitmap, and closing that gap reopens a container question that
AC-057 was written to close.

---

## 1. Governance: this is an amendment, not a task

Floor plans are ruled out of scope in four places:

| Site | Text |
|---|---|
| `docs/09-roadmap.md` §2.5 | `Cable dressing, floor plans, 3D, thermal simulation \| Out of the brief` |
| `canonical-decisions.md` §7.6 | Same row, with the rationale *"The brief says the plan ignores cable dressing, and it is right to"* |
| `docs/00-overview.md` §, out-of-scope table | Same row |
| `docs/01-domain.md` §7.6 | `Floor plans, 3D, thermal simulation \| Out of the brief (§7.6)` |

Two properties of that ruling matter to whether it can be moved.

**It is not a "never".** DR-004 says multi-sheet splitting is *"never built"*, and the roadmap
files it accordingly. Floor plans are not in that category. DR-005 §11.5.3 states directly that
DR-005 *"does not add floor plans, riser diagrams, reflected ceiling plans ... to v1. Those remain
out (v1.1 / v2)."* A named future home is a deferral, not a prohibition, and moving a deferral
between release bands is ordinary §8.3 work.

**The ruling was never argued on its own merits.** The §7.6 row bundles four unrelated items, and
the rationale sentence attached to it defends only the first of them. Cable dressing was argued.
Floor plans rode along in the same table cell. That is the weakest scope ruling in §7.6 and the
cheapest of them to amend, and this paper says so rather than pretending the row carries more
weight than it does.

**A second constraint, which is the one that binds.** Roadmap §2.2 states a membership criterion
for v1.1, and it is not about effort:

> Membership criterion is **additive**: no format migration, no command-stack change, no
> re-derivation of user data. Not effort.

A floorplan raster has to be stored. Storing it is a format change under any of the available
designs (§4.2 below). **The Plan view therefore fails §2.2's membership test on its face**, and
"put it in v1.1" is not a legal placement unless the format carrier is landed in v1 first. That
is not a technicality invented here; it is the same G5 reasoning roadmap §2.1's filter 2 already
applies eleven times, and §5 below recommends taking it.

---

## 2. What already exists

Most of the conceptual work is done. This is the strongest argument for the feature and it is
worth stating precisely, because the parts that exist are exactly the parts that are usually
expensive.

| Requirement | Already in the tree |
|---|---|
| Rooms, arbitrary depth | `Location`, CR-047, `packages/rackmate_core/lib/src/model/location.dart` |
| Field devices not in a rack | `OffRackPlacement{locationId, mountNote}`, `model/placement.dart:112` |
| Conduit and j-hook runs with endpoints and a length | `Pathway{kind, fromLocationId, toLocationId, nominalLength}`, `model/pathway.dart` |
| Low-voltage boxes and plates | `Outlet`, `StructureBody` (DR-007 puts the keystone strap in M3) |
| Somewhere to put a measured length | `routedLength`, `cutLength`, `terminatedLength` (AC-024) |
| Estimated-versus-measured honesty | Built into the schedule already: estimates render italic and are tagged, null prints an em rule, `LEN-*` emits *"length unknown, cannot verify"* (G4) |
| The pull schedule itself | `derived/schedule.dart`, one derivation and two presets |
| Sheet furniture, title block, revision block, drawing index | Done, both backends, DR-005 |
| Viewport, selection, hit-test, drag preview, undo | Two canvases' worth in `rackmate_ui`, reusable |

The load-bearing one is `Location.estimatedRunLengthFromRack`. AC-024 put it there as the pull
sheet's length source and gave it the honesty apparatus that G4 demands. **A plan measurement is a
better source feeding that same field**, not a new number needing a new column, a new rollup and a
new set of rules. The schedule side of this feature is close to free, and that is unusual.

---

## 3. What does not exist: raster, anywhere

This is the entire cost, and it is one gap with four consequences.

### 3.1 `DiagramCanvas` has no `drawImage`, deliberately

`packages/rackmate_core/lib/src/draw/canvas.dart:20`:

> The single drawing IR both the screen and PDF backends replay (CR-086). No `drawImage`/`ImageRef`
> in v1 (RJ-017 defers the title-block logo to v2) and no `RendererCaps` (CR-088). The interface is
> the common denominator: flat fills, strokes, dashes and text only.

The same file's header states that it *"must not gain a method beyond the ones below without an
amendment"*, and `draw/sheet/title_block.dart:48` repeats the reasoning from the other side. Adding
a raster op touches the interface, `draw/ops.dart` (a new `OpImage` in a sealed hierarchy), the
bounds canvas, `rackmate_ui/src/draw/flutter_canvas.dart`, `rackmate_export/src/draw/pdf_canvas.dart`,
hit-test, and the op-count baselines in `schematic_perf_test.dart` that are M2-C's record.

### 3.2 `.rmpj` is plain JSON and the codec actively refuses a container

`persistence/codec.dart` sniffs `PK\x03\x04` and returns `UnsupportedZipContainerError` rather than
letting a zip reach the JSON parser. CR-091 chose plain pretty JSON and parked a zip container as a
v2 possibility. A raster forces the question:

- **Base64 inside the JSON.** A 2 MB PNG becomes roughly 2.7 MB of inline text in a pretty-printed
  file that the user's backup and sync tooling copies whole on every save, and CR-117's byte
  round-trip test starts round-tripping megabytes on every run of the core suite.
- **The zip container CR-091 parked.** Correct, and more work: migration chain, golden corpus,
  round-trip, and the `DocumentCodec` seam finally getting its second implementation.

Note what this reopens. **AC-057 cut device images specifically to close this**: *"Cutting them
resolves the container question (CR-091), removes the image-decode bounds from the import-security
surface, and removes ~1 MB per template."* Canon §11.15 makes the same observation from the other
direction, that images *"reopen the container question that AC-057 just closed"*. Reopening it is
the honest price of this feature and should be stated in the ruling rather than discovered in
implementation.

### 3.3 The `pdf` package cannot read a PDF

`docs/08-pdf-export.md` §1.1 states it while explaining why the datasheet appendix defers to v2:
*"the `pdf` package writes documents, it does not import pages."* Accepting a PDF floorplan
therefore requires a rasterizer:

| Option | Cost |
|---|---|
| `pdfrx` / `pdfx` (PDFium) | A large native DLL in the portable ZIP. Licence is fine for the GPLv3 question (PDFium is BSD-3-Clause) |
| `Windows.Data.Pdf` (WinRT) | No third-party dependency, Windows only, and DR-009 puts macOS in v1, so it lands on `docs/13`'s debt register immediately |
| No PDF import; PNG and JPEG only | Zero new native surface. Costs the user one export step |

The native-DLL option deserves weight beyond its engineering hours. This project removed
`file_selector` and the `path_provider` umbrella in part because they dragged an Android JNI bridge
and `dartjni.dll` into a Windows Release build, and `apps/rackmate/pubspec.yaml` carries a long
comment explaining that trade and a test that fails the build if the package returns. Adding a
multi-megabyte unsigned native binary to a self-signed internal distribution (DR-006) runs directly
against that grain.

### 3.4 It is a new untrusted-input surface

AC-058/D12 put JSON depth and size limits on every import path. Image decoders are a well-known
memory-safety surface, and AC-057 counted removing that surface as one of four benefits of cutting
device images. Whatever is decided, the plan underlay import needs the same hardening treatment the
JSON paths already got, and that work is real.

### 3.5 One smaller item: PAL-1

`tools/pal1_check.py` gates rendered greyscale luminance across family pairs, and CR-078 makes
colour a property of the signal domain. An arbitrary raster underlay injects greyscale values that
the palette does not control. The underlay needs to be excluded from that check explicitly, and the
plan sheet's device callouts need to remain PAL-1 conformant against a background that is not
white. Small, but it is the kind of thing that is found late if nobody writes it down.

---

## 4. Design notes that materially change the cost

### 4.1 Raster-only import removes most of §3.3 and §3.4

Accepting PNG and JPEG only, and asking the user to export a page to an image from whatever
produced the PDF, deletes the rasterizer dependency, the native DLL, the macOS debt entry and the
larger half of the security surface. It costs the user one step. PDF import remains available later
as a separable increment that changes no stored format.

This paper recommends it, and recommends against treating "upload a PDF" as an inseparable part of
the request.

### 4.2 Length must not be derived from pin-to-pin geometry alone

G4 is a standing prohibition: null is unknown, never estimated, and `0` means measured zero. A
straight line between two pins on a plan is not a cable route. It ignores drop and rise, it ignores
the path around a stairwell, and it is systematically short.

The honest model is that a plan yields a **measured horizontal distance**, to which a per-location
drop or rise allowance and a slack allowance are added, and the result **stays tagged as an
estimate** under AC-024's existing italic-and-tagged apparatus unless a human marks it measured. A
plan-derived number that presents as exact is precisely the failure G4 exists to prevent, and it is
worse than the current one-number-per-room estimate because it looks authoritative.

### 4.3 Coordinates are `Len`, not `Pt`

`units/pt.dart` is the schematic grid: integer 2.5 mm grid units, CR-004, no sub-grid and no free
positioning. Plan coordinates are real-world positions and belong in `Len` (int64 nanometres,
CR-001). Scale calibration is two picked points plus a typed real distance, and the resulting
scale factor must not become a floating-point millimetre anywhere in the model or the file format.

---

## 5. The M3 interaction, and the reason to decide something now

M3 is *Structure and the field*: `Outlet`, `StructureBody`, `Pathway`, the `Location` tree UI, and
an exit criterion of a 60-drop rough-in entered in under fifteen minutes producing a sorted Pull
Sheet. `docs/12` §5.2 records it as `NOT BUILT`, model only, with its M2 block lifted.

The Plan view is a better front end for exactly what M3 builds. That ordering has two consequences.

**Do not build it before M3.** It would be a UI for a subsystem that has no UI, and it puts M3's
own exit criterion at risk while inflating an `M` milestone.

**But decide the format carrier during M3, not after it.** Roadmap §2.1's filter 2 (G5, *cheap now
and ruinous later*) exists for this case and states the remedy: *"Does omitting it cost a format
migration ... ? If yes the **model** ships in v1 even when the **UI** does not."* The roadmap notes
this pattern already appears eleven times.

Concretely, landing in v1 the underlay reference, the plan-pin coordinate on the placement union,
and whichever container decision §3.2 resolves to, costs days rather than weeks and converts the
later Plan view from a migration over user data into an additive UI. **It is also the only thing
that makes a v1.1 placement legal under §2.2's membership criterion.** Without it the feature is
v1.2 by the roadmap's own rule, and saying so is cheaper now than discovering it during a v1.1
planning pass.

---

## 6. Estimate

Sized in the same unit roadmap §6 uses. For calibration: M2 (wiring and the live schedule) was
`M`, 4 to 7 weeks; M1 (the elevation release) was `L`, 8 to 12; the remaining M2 to M9 band is 32
to 50.

| Phase | Weeks |
|---|---|
| Amendment: the ruling, roadmap §2, the derived-document edits (§8.3, its own commit) | 0.5 |
| `OpImage` through the IR and both backends; op-count baselines; PAL-1 exclusion | 1 – 1.5 |
| Container: zip `.rmpj`, migration chain, golden corpus, CR-117 round-trip | 1.5 – 2.5 |
| Plan model: underlay entity, pin placement variant, two-point scale calibration in `Len`, commands, serialization | 1 – 1.5 |
| **Plan canvas**: underlay render, pan and zoom, place/drag/select pins, pin-to-`Location` binding, inspector, palette drag | 2 – 3 |
| Plan-measured length into `routedLength`; drop and slack allowances; the G4 discipline in §4.2 | 0.5 – 1 |
| Plan sheet in the set (`T1.01`), per-plan device schedule, drawing index integration | 1 – 1.5 |
| Tests to house standard: 2206 today, per-suite floors, raster goldens | 0.5 – 1 |

| Shape | Weeks | Note |
|---|---|---|
| **Minimum viable** (raster only, base64 with a size cap, no container) | **5 – 7** | Pays the container cost back later, with user data already in the field |
| **Recommended** (raster only, zip container) | **7 – 10** | §4.1 plus §3.2's correct answer |
| **Full** (PDF import via PDFium, both platforms) | **9 – 13** | Plus a `docs/13` entry and a native binary in the ZIP |

The plan canvas row is the largest and is the one most likely to be wrong in the optimistic
direction. It is smaller than M1's canvas work only because the viewport, selection, hit-test,
drag-preview and command machinery already exist; if any of those turn out to be coupled to rack or
schematic semantics more tightly than a read suggests, that row grows first.

---

## 7. Two risks worth naming before any of this is scheduled

**The device is an iPad and RackMate is not on it.** The stated current workflow is coloured dots in
iOS Notes, which implies a tablet and plausibly a walkthrough on site. RackMate is a Windows-first
desktop application with macOS ruled in by DR-009. Roadmap §2.4 defers mobile **editing** to v2 and
AC-056 makes v1 mobile read-only on exactly three surfaces, with the app saying so rather than
shipping a squeezed editor. **A Plan view in RackMate does not replace the iPad workflow. It moves
it to a desk.** If the value of the current practice depends on marking up a plan while walking the
house, this feature does not deliver that value, and the real question is a much larger one about
mobile editing. Establishing which of the two is true costs a conversation and should happen before
any of §6 is spent.

**The stated failure is what M3 already exists to fix.** *"Someone doing something incorrectly"* is
the problem the Pull Sheet was designed against: `T6.10`, portrait, sorted room then pathway,
per-room footage subtotals, and `Pulled ☐ Terminated ☐ Tested ☐ Init ___` on every row (AC-025).
That is M3's exit criterion almost verbatim, and M3 is unbuilt with its blocker lifted. The Plan
view improves on it, because no table replaces a location drawing for a rough-in, and a plan is
genuinely the right artefact for answering *where*. But the mechanism that stops the errors
described in the request is M3, and it is already scheduled, already ruled, and already in v1.

---

## 8. Recommendation

1. Amend the scope ruling and place the Plan view in **v1.1**, conditional on §5's format carrier
   landing in v1. Without that carrier it is v1.2 under roadmap §2.2's own membership criterion.
2. Scope it **raster only**. Treat PDF import as a later separable increment.
3. Answer the container question (§3.2) **before M3 closes**, because it is a G5 decision and M3 is
   the milestone that puts field devices into user files.
4. Reevaluate the placement if the plan runs ahead of schedule.
5. Resolve §7's iPad question before spending any of §6.
