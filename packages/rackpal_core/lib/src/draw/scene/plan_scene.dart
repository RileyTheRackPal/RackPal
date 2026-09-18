// rackpal_core/src/draw/scene/plan_scene.dart — the Plan view's scene
// builder (docs/15 §6 and §7, PLAN-E/2, DR-029).
//
// The third scene builder, beside the rack elevation and the schematic. It
// composes one underlay and the pins on it into the same `DiagramScene`
// every other surface consumes, so the screen and (at PLAN-H) the T1.01
// sheet replay ONE display list rather than two renderers agreeing by hand
// (CR-086).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE IMAGE PIXEL IS ONE SCENE UNIT, AND THAT IS THE WHOLE COORDINATE RULE
// ═══════════════════════════════════════════════════════════════════════
// A `PlanPin` stores a `PxPt`: integer pixels into the underlay's own
// raster (docs/15 §3.3). The scene is `DPt`: doubles, 1 unit = 1 PDF
// point. Mapping them 1:1 makes the underlay occupy
// `DBox.fromLtwh(0, 0, pixelWidth, pixelHeight)` and a pin at `PxPt(x, y)`
// land at `DPt(x, y)`, which has three properties worth having:
//
//   * ASPECT IS PRESERVED BY CONSTRUCTION. `DiagramCanvas.drawImage` has
//     no fit rule on purpose (DR-029 §11.28.6: the caller chooses a
//     destination that does not stretch the picture, rather than the
//     canvas letterboxing silently). Choosing the intrinsic size is the
//     shortest way to honour that, and it cannot be got wrong.
//   * THE MAPPING IS TESTABLE AS AN IDENTITY, so a pin that renders in the
//     wrong place is a bug in one place rather than in a conversion.
//   * NOTHING HERE PRETENDS TO BE PHYSICAL. Scene units are not
//     millimetres and this builder knows no scale. `PlanScale` (PLAN-F)
//     is what turns pixels into `Len`, it is optional, and an
//     uncalibrated plan still locates every drop, which is the Plan
//     view's first job (docs/15 §3.1).
//
// It follows that the scene's `bounds` are the underlay's pixel extent.
// That is what a sheet scales to fit, and it is why a 600-pixel scan and a
// 4000-pixel scan of the same floor produce scenes of very different
// numeric size and identical appearance once fitted.
//
// A TURNED PLAN KEEPS THE RULE AND ADDS ONE QUARTER TURN (DR-184). A pixel
// is still one scene unit; the scene is the picture AS SEEN, so a plan
// turned once has its width and height swapped, and a pin lands where
// `PlanTurn.toScene` sends it rather than at the same two numbers. The
// identity above is `PlanTurn`'s zero case and holds exactly for every
// unturned plan, which is every plan that existed before the ruling. The
// three properties survive: a quarter turn is exact on integers, so the
// mapping is still testable as a closed form rather than a tolerance.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS BUILDER DOES NOT DRAW, LISTED SO IT IS NOT READ AS AN OMISSION
// ═══════════════════════════════════════════════════════════════════════
// No CALLOUTS: docs/15 §7's designator pills, leader lines and the
// screened underlay are the printed sheet's treatment and belong to
// PLAN-H. No SCALE BAR (PLAN-H/4). No length of any kind: DR-020 governs
// what a plan may claim and `planLowerBound` arrives at PLAN-G.
//
// What it draws is a marker per pin and the picture behind them, which is
// what an editor needs to place, select and move one.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/image_ref.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/family_glyph.dart';
import 'package:rackpal_core/src/draw/scene/plan_turn.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/px_pt.dart';

/// One pin the caller wants drawn, already resolved out of the document.
///
/// A FLAT INPUT AND NOT A `RackDocument`, on `buildRackScene`'s own
/// precedent: that builder takes a `Rack`, an `Iterable<DeviceInstance>`
/// and a template map rather than the whole aggregate. The pins on one
/// underlay come from three different collections (devices, outlets,
/// racks) and resolving them is a query, not a drawing decision, so it
/// happens once at the call site and this file stays about geometry.
@immutable
final class PlanPinSubject {
  const PlanPinSubject({
    required this.entityId,
    required this.at,
    required this.carrier,
    this.domain,
  });

  /// The entity the pin hangs on: a device, an outlet or a rack. This is
  /// what lands in the [DiagramScene.hits] region, so a click on the
  /// marker selects the thing rather than the mark.
  final Uuid entityId;

  /// Where it sits, in the underlay's own pixel space.
  final PxPt at;

  /// Which of docs/15 §3.4's three carriers this is.
  ///
  /// Carried through to the scene because the marker differs by kind: a
  /// rack is the datum every length is measured FROM (`PLN-003`), and a
  /// plan on which the rack is indistinguishable from a speaker is one
  /// somebody has to count on.
  ///
  /// **THIS CLAUSE SAID THE CARRIER WAS NOT A COLOUR DECISION** *"here:
  /// CR-078 puts colour on the signal domain, and a pin carries no
  /// domain"* until `#901` (DR-169 §11.168.4). The first half still
  /// holds and is why [domain] exists beside this field rather than
  /// instead of it: colour is the DOMAIN's, shape is the CARRIER's, and
  /// they answer different questions. What expired is the second half.
  final PlanPinCarrier carrier;

  /// What the thing on the end of this pin mostly IS, or null when
  /// nobody has said (`#901`, DR-169 §11.168.4).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// RESOLVED AT THE CALL SITE, like everything else on this struct
  /// ═══════════════════════════════════════════════════════════════════
  /// A device reads its template's `primaryDomain`, an outlet reads the
  /// recipe it was made from, and a rack has none at all: it is the
  /// datum, not a ninth domain (§11.168.8). Three different lookups
  /// through three different collections, which is a QUERY, and this
  /// file's header keeps queries out of it.
  ///
  /// **NULL DRAWS THE NEUTRAL MARK** (G4/CR-114). It is never filled in
  /// from the ports: a census over the 51 seeded templates found only 13
  /// whose ports belong to a single domain.
  final SignalDomainId? domain;

  @override
  bool operator ==(Object other) =>
      other is PlanPinSubject &&
      other.entityId == entityId &&
      other.at == at &&
      other.carrier == carrier &&
      other.domain == domain;

  @override
  int get hashCode => Object.hash(entityId, at, carrier, domain);
}

/// The three things a pin can hang on, as the SCENE sees them.
///
/// A SECOND ENUM BESIDE `PinCarrier`, AND THE DUPLICATION IS DELIBERATE.
/// `commands/plan_commands.dart`'s `PinCarrier` says which collection a
/// writer must reach into; this says which mark to draw. They have the
/// same three values today and no reason to move together: a fourth
/// carrier would need a writer and a mark, while a rack drawn differently
/// from a device needs neither. Joining them would put a drawing concern
/// in the command layer, which `draw_source_gate_test.dart` exists to
/// prevent.
enum PlanPinCarrier { rack, outlet, device }

/// The output of [buildPlanScene].
@immutable
final class PlanScene {
  const PlanScene({required this.scene, required this.underlayBounds});

  /// The one composed display list: the underlay, then every marker.
  final DiagramScene scene;

  /// The underlay's own extent, which is also the scene's ink extent when
  /// no pin sits outside the picture. Exposed separately because a caller
  /// framing the view wants the PICTURE, not the union with a stray pin
  /// somebody dragged off the edge.
  final DBox underlayBounds;
}

/// The underlay's own extent, in scene units, which are image pixels.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A FUNCTION OF THE UNDERLAY, BECAUSE THE SHEET NEEDS IT FIRST
/// ═══════════════════════════════════════════════════════════════════════
/// `plan_sheet.dart` fits the plan to its page from this box, sizes the
/// mark from that fit, and only then can build a scene (`#904`, DR-169
/// §11.168.10). Reading the box off a built [PlanScene] would make the
/// radius depend on the scene it is an argument to. So the sheet and
/// [buildPlanScene] read this one answer, and the fit cannot drift from
/// [PlanScene.underlayBounds].
///
/// **THE PLAN AS SEEN, NOT THE IMAGE AS STORED** (DR-184 §11.183.1). A plan
/// turned a quarter swaps its width and height, and a sheet that fitted the
/// stored box would size a landscape drawing as a portrait one.
DBox planUnderlayBounds(PlanUnderlay underlay) =>
    PlanTurn.of(underlay).sceneBounds;

/// How much heavier a device's ring is than a drop's outline (`#901`,
/// DR-169 §11.168.6 and §11.168.11).
///
/// The device mark carried an inner dot at `r / 3` to tell it from a
/// drop, and that is exactly the space the domain glyph now occupies. A
/// stroke weight is the cheapest channel left that survives a greyscale
/// print, which is the same argument PAL-1 makes for lines.
///
/// **TWO, AND IT WAS 1.75** (`#905`). The user ruled drafting weights: a
/// drop at the product's base line and a device at twice it, which is
/// docs/05 §5's own `2.00x` row. The ratio clears PAL-1's 1.4 with room,
/// and it only holds because the weights stopped riding the fit: at 1.75
/// of a scene-unit stroke, a 6600-pixel scan printed both at the 0.5-point
/// floor and a device exactly like a drop.
const double kPlanDeviceRingFactor = 2;

/// The glyph's box as a fraction of the marker's radius.
///
/// Big enough to read at the mark's shipped size and small enough to
/// leave the fill visible around it, which is what carries the colour.
///
/// **AND IT BOUNDS THE RING** (§11.168.11). A square glyph fills its box,
/// so its corners reach 0.813 of the radius, and a device ring whose inner
/// edge crosses that point runs black into black. Growing this factor or
/// the ring has to keep the ring under about 37% of the radius on every
/// surface; `plan_sheet_test.dart` reads that clearance off a printed
/// Network device.
const double kPlanGlyphSideFactor = 1.15;

/// Composes [underlay] and [pins] into one scene (docs/15 §6).
///
/// ═══════════════════════════════════════════════════════════════════════
/// [markerRadius] IS IN SCENE UNITS; [markerWeight] IS IN SURFACE UNITS
/// ═══════════════════════════════════════════════════════════════════════
/// The radius is geometry, so each surface states it from its own scale
/// (DR-169 §11.168.2): the canvas divides a screen size by its zoom, and
/// the sheet divides a paper size by its fit. It used to default to 1/110
/// of the underlay's longer side, and **the sheet kept taking that default
/// after the canvas had stopped**, because a caller that passed nothing
/// got the retired rule and nothing said so (`#904`). Required, a caller
/// that forgets does not compile.
///
/// The weight is a drop outline's width ON THE SURFACE, points on paper
/// and logical pixels on screen (§11.168.11), and every mark stroke is
/// emitted with `scaleWithGeometry: false`, which is CR-082's own spelling
/// of "constant on the surface": each backend divides by its own scale.
/// It was a 2-unit `Stroke` in the palette until `#905`, in scene units,
/// so it rode the fit on paper and the zoom on screen.
PlanScene buildPlanScene({
  required PlanUnderlay underlay,
  required Iterable<PlanPinSubject> pins,
  required double markerRadius,
  required double markerWeight,
  PlanPalette palette = const PlanPalette(),
  Map<SignalDomainId, SignalDomainDef> domains = const {},
}) {
  assert(
    markerRadius > 0 && markerRadius.isFinite,
    'buildPlanScene: a marker radius of $markerRadius draws nothing a '
    'person can read or click',
  );
  assert(
    markerWeight > 0 && markerWeight.isFinite,
    'buildPlanScene: a marker weight of $markerWeight is not a line',
  );
  final ops = <DiagramOp>[];
  final fragments = <String, IntRange>{};
  final hits = <HitRegion>[];

  final turn = PlanTurn.of(underlay);
  final bounds = turn.sceneBounds;

  // ── the underlay, op zero ────────────────────────────────────────────
  //
  // FIRST, SO EVERYTHING ELSE IS OVER IT. There is no z-ordering mechanism
  // in a display list beyond emission order, which is exactly why
  // `schematic_paint_plan.dart` makes the sheet ground "op zero of the
  // plan": a background drawn anywhere else is a background drawn over
  // something.
  final image = OpImage(
    ImageRef(
      member: underlay.imageMember,
      format: switch (underlay.format) {
        PlanImageFormat.png => ImageFormat.png,
        PlanImageFormat.jpeg => ImageFormat.jpeg,
      },
      pixelWidth: underlay.pixelWidth,
      pixelHeight: underlay.pixelHeight,
    ),
    // THE STORED IMAGE'S OWN BOX, which the turn below then carries into
    // the scene. For an unturned plan this is `bounds` exactly.
    DBox.fromLtwh(
      0,
      0,
      underlay.pixelWidth.toDouble(),
      underlay.pixelHeight.toDouble(),
    ),
  );
  // A TURNED PLAN IS THE SAME IMAGE UNDER ONE BRACKET (DR-184 §11.183.2),
  // the `OpSave` / `OpTransform` / `OpRestore` shape `plan_sheet.dart`
  // already wraps this whole scene in. AN UNTURNED ONE GETS NO BRACKET AT
  // ALL, so every display list, op count and exported byte that existed
  // before the turn did is unchanged by it.
  if (turn.imageToScene case final m?) {
    ops
      ..add(const OpSave())
      ..add(OpTransform(m))
      ..add(image)
      ..add(const OpRestore());
  } else {
    ops.add(image);
  }
  fragments[underlay.id.v] = IntRange(0, ops.length);

  final r = markerRadius;

  // ONE INK AND TWO WEIGHTS, NEITHER OF THEM IN SCENE UNITS (§11.168.11).
  // `scaleWithGeometry: false` hands the division to the backend, which
  // knows its own scale: the PDF canvas reads the sheet's fit off its
  // transform stack, and the plan canvas is told its zoom.
  final outline = Stroke(
    argb: palette.markerInk,
    widthPt: markerWeight,
    scaleWithGeometry: false,
  );
  final ring = Stroke(
    argb: palette.markerInk,
    widthPt: markerWeight * kPlanDeviceRingFactor,
    scaleWithGeometry: false,
  );

  // ── one fragment per pin ─────────────────────────────────────────────
  //
  // KEYED BY THE ENTITY ID, matching `buildRackScene`'s per-device
  // fragments, so a future consumer can replay one pin's ops alone
  // (CR-086) without this file changing shape.
  for (final pin in pins) {
    final start = ops.length;
    // THROUGH THE TURN, which is the identity on an unturned plan and the
    // one place a stored pixel becomes a scene point (DR-184 §11.183.2).
    final centre = turn.toScene(pin.at);
    // ═════════════════════════════════════════════════════════════════
    // COLOUR IS THE DOMAIN'S AND THE GLYPH IS WHAT SURVIVES THE PRINT
    // ═════════════════════════════════════════════════════════════════
    // CR-078 puts hue on the domain, so a mark filled with it needs no
    // new palette. The GLYPH is not decoration: `plan_sheet.dart`
    // splices this scene, the Installer preset exports greyscale, and
    // canon §14 records that the eight hues COLLIDE in greyscale by
    // design, three of them inside one luminance band. PAL-3 resolves
    // that for a line with dash and weight; a filled dot has neither, so
    // the domain's own glyph is what separates them on paper
    // (DR-169 §11.168.6).
    final def = pin.domain == null ? null : domains[pin.domain];
    final fill = def == null ? palette.markerFill : Fill(def.color.argb);
    final glyph = def == null ? null : familyGlyphFor(def.glyph);
    switch (pin.carrier) {
      case PlanPinCarrier.rack:
        // THE DATUM READS AS A DATUM. Every length on this plan is
        // measured from here (`PLN-003`), so it is a square with a cross
        // through it rather than one more dot in a field of dots.
        final box = DBox.fromLtwh(centre.x - r, centre.y - r, r * 2, r * 2);
        ops
          ..add(OpRect(box, fill: palette.markerFill, stroke: outline))
          ..add(
            OpLine(
              DPt(box.left, centre.y),
              DPt(box.right, centre.y),
              outline,
            ),
          )
          ..add(
            OpLine(
              DPt(centre.x, box.top),
              DPt(centre.x, box.bottom),
              outline,
            ),
          );
      case PlanPinCarrier.outlet:
        // A drop is the thing a designer is actually dotting (docs/15
        // §3.4), and there are sixty of them on the design case, so it is
        // the plainest mark of the three: one circle, and the domain's
        // colour costs no extra ink.
        ops.add(OpCircle(centre, r, fill: fill, stroke: outline));
      case PlanPinCarrier.device:
        // THE HEAVIER RING IS WHAT KEEPS A DEVICE FROM READING AS A DROP
        // once both carry a glyph. It was an inner dot at `r / 3`, which
        // is the space the glyph now occupies; a weight is the cheapest
        // channel left that survives greyscale, and docs/15 §3.4's three
        // marks stay three.
        ops.add(OpCircle(centre, r, fill: fill, stroke: ring));
    }
    // THE GLYPH GOES IN BOTH, AND IN THE RACK'S NEITHER. A rack has no
    // domain to draw (§11.168.8) and its square already carries a cross.
    if (glyph != null && pin.carrier != PlanPinCarrier.rack) {
      final side = r * kPlanGlyphSideFactor;
      ops.add(
        familyGlyphOp(
          glyph,
          DPt(centre.x - side / 2, centre.y),
          side / kFamilyGlyphCapFactor,
          palette.markerCore.argb,
          // A HOLLOW GLYPH IS OUTLINED AT THE MARK'S OWN WEIGHT, and on
          // the surface rather than in scene units, for the ring's reason.
          hollowWidthPt: markerWeight,
          hollowScalesWithGeometry: false,
        ),
      );
    }
    fragments[pin.entityId.v] = IntRange(start, ops.length);
    // THE HIT BOX IS THE MARKER'S SQUARE, for all three kinds. A circular
    // hit test on a mark this size buys nothing a person can feel and
    // costs the one property `hitTest` is built on: `HitRegion` is an
    // AABB, and its nearest-hit ranking already resolves two overlapping
    // pins by distance to centre.
    hits.add(
      HitRegion(
        pin.entityId.v,
        DBox.fromLtwh(centre.x - r, centre.y - r, r * 2, r * 2),
      ),
    );
  }

  return PlanScene(
    scene: DiagramScene(
      ops: ops,
      bounds: bounds,
      hits: hits,
      // NO TEXT IS DRAWN HERE, so there is no smallest text size to
      // report. `double.infinity` is what `buildRackScene` carries for the
      // same reason before any label lands, and docs/08 §6.2's legibility
      // trigger reads it as "nothing to check" rather than as zero, which
      // would read as "something illegible".
      minTextSizePt: double.infinity,
      fragments: fragments,
    ),
    underlayBounds: bounds,
  );
}

/// The plan's marks, as a palette rather than as constants at the draw
/// site, on `RackPalette`'s precedent.
///
/// GREYSCALE BY DEFAULT AND THAT IS NOT A PLACEHOLDER. PAL-1 gates the
/// rendered greyscale separation of signal FAMILIES (canon §14), and a pin
/// is not a signal family: it carries no domain, so CR-078 gives it no
/// colour to inherit. Marks on a drawing over an architect's line work are
/// black-on-white drafting practice, and docs/15 §7 already requires the
/// underlay to be screened so black callouts stay legible over it.
@immutable
final class PlanPalette {
  const PlanPalette({
    this.markerInk = 0xFF101010,
    this.markerFill = const Fill(0xE6FFFFFF),
    this.markerCore = const Fill(0xFF101010),
  });

  /// The ink every mark is outlined in, as packed ARGB.
  ///
  /// **A COLOUR AND NOTHING ELSE** (`#905`, DR-169 §11.168.11). This was a
  /// `Stroke` with a width of 2, and a palette is shared by every surface,
  /// so that width was in scene units by construction and rode the fit on
  /// paper and the zoom on screen. The weight is each surface's now, passed
  /// to `buildPlanScene` as `markerWeight`.
  final int markerInk;

  /// Its interior. Nearly opaque white rather than transparent, so a mark
  /// over dense line work is still a mark; a plan is not a blank page.
  final Fill markerFill;

  /// The device mark's centre dot.
  final Fill markerCore;
}
