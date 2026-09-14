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

/// The radius a marker gets when the caller does not choose one, as a
/// fraction of the underlay's longer side.
///
/// PROPORTIONAL AND NOT ABSOLUTE, because scene units are image pixels
/// (see the file header) and a fixed radius would draw a dot on a 4000
/// pixel scan and a blot on a 600 pixel one. 1/110 of the long side puts a
/// marker at roughly 18 units on a 2000 pixel plan, which is legible
/// against architectural line work without covering the room it is in.
///
/// **A STARTING VALUE, NOT A RULING.** The mark's appearance is UI/UX and
/// is the user's; docs/15 §7's callout treatment is PLAN-H's and will
/// revisit it with the designator pill.
const double kPlanMarkerRadiusFraction = 1 / 110;

/// How much heavier a device's outline is than an outlet's (`#901`,
/// DR-169 §11.168.6).
///
/// The device mark carried an inner dot at `r / 3` to tell it from a
/// drop, and that is exactly the space the domain glyph now occupies. A
/// stroke weight is the cheapest channel left that survives a greyscale
/// print, which is the same argument PAL-1 makes for lines.
const double kPlanDeviceRingFactor = 1.75;

/// The glyph's box as a fraction of the marker's radius.
///
/// Big enough to read at the mark's shipped size and small enough to
/// leave the fill visible around it, which is what carries the colour.
const double kPlanGlyphSideFactor = 1.15;

/// Composes [underlay] and [pins] into one scene (docs/15 §6).
///
/// [markerRadius] overrides [kPlanMarkerRadiusFraction]'s derived default.
PlanScene buildPlanScene({
  required PlanUnderlay underlay,
  required Iterable<PlanPinSubject> pins,
  PlanPalette palette = const PlanPalette(),
  double? markerRadius,
  Map<SignalDomainId, SignalDomainDef> domains = const {},
}) {
  final ops = <DiagramOp>[];
  final fragments = <String, IntRange>{};
  final hits = <HitRegion>[];

  final bounds = DBox.fromLtwh(
    0,
    0,
    underlay.pixelWidth.toDouble(),
    underlay.pixelHeight.toDouble(),
  );

  // ── the underlay, op zero ────────────────────────────────────────────
  //
  // FIRST, SO EVERYTHING ELSE IS OVER IT. There is no z-ordering mechanism
  // in a display list beyond emission order, which is exactly why
  // `schematic_paint_plan.dart` makes the sheet ground "op zero of the
  // plan": a background drawn anywhere else is a background drawn over
  // something.
  ops.add(
    OpImage(
      ImageRef(
        member: underlay.imageMember,
        format: switch (underlay.format) {
          PlanImageFormat.png => ImageFormat.png,
          PlanImageFormat.jpeg => ImageFormat.jpeg,
        },
        pixelWidth: underlay.pixelWidth,
        pixelHeight: underlay.pixelHeight,
      ),
      bounds,
    ),
  );
  fragments[underlay.id.v] = IntRange(0, ops.length);

  final r =
      markerRadius ??
      (underlay.pixelWidth > underlay.pixelHeight
              ? underlay.pixelWidth
              : underlay.pixelHeight) *
          kPlanMarkerRadiusFraction;

  // ── one fragment per pin ─────────────────────────────────────────────
  //
  // KEYED BY THE ENTITY ID, matching `buildRackScene`'s per-device
  // fragments, so a future consumer can replay one pin's ops alone
  // (CR-086) without this file changing shape.
  for (final pin in pins) {
    final start = ops.length;
    final centre = DPt(pin.at.px.toDouble(), pin.at.py.toDouble());
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
          ..add(OpRect(box, fill: palette.markerFill, stroke: palette.marker))
          ..add(
            OpLine(
              DPt(box.left, centre.y),
              DPt(box.right, centre.y),
              palette.marker,
            ),
          )
          ..add(
            OpLine(
              DPt(centre.x, box.top),
              DPt(centre.x, box.bottom),
              palette.marker,
            ),
          );
      case PlanPinCarrier.outlet:
        // A drop is the thing a designer is actually dotting (docs/15
        // §3.4), and there are sixty of them on the design case, so it is
        // the plainest mark of the three: one circle, and the domain's
        // colour costs no extra ink.
        ops.add(OpCircle(centre, r, fill: fill, stroke: palette.marker));
      case PlanPinCarrier.device:
        // THE HEAVIER RING IS WHAT KEEPS A DEVICE FROM READING AS A DROP
        // once both carry a glyph. It was an inner dot at `r / 3`, which
        // is the space the glyph now occupies; a weight is the cheapest
        // channel left that survives greyscale, and docs/15 §3.4's three
        // marks stay three.
        ops.add(
          OpCircle(
            centre,
            r,
            fill: fill,
            stroke: Stroke(
              argb: palette.marker.argb,
              widthPt: palette.marker.widthPt * kPlanDeviceRingFactor,
            ),
          ),
        );
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
          hollowWidthPt: palette.marker.widthPt,
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
    this.marker = const Stroke(argb: 0xFF101010, widthPt: 2),
    this.markerFill = const Fill(0xE6FFFFFF),
    this.markerCore = const Fill(0xFF101010),
  });

  /// The mark's outline.
  final Stroke marker;

  /// Its interior. Nearly opaque white rather than transparent, so a mark
  /// over dense line work is still a mark; a plan is not a blank page.
  final Fill markerFill;

  /// The device mark's centre dot.
  final Fill markerCore;
}
