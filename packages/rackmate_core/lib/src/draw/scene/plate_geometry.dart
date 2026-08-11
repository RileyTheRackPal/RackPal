// rackmate_core/src/draw/scene/plate_geometry.dart — pure Dart.
//
// The ONE place that turns DR-007's integer strap grid into diagram-space
// rectangles, on the same `1 unit = 1 PDF point at zoom 1.0` convention
// `rack_geometry.dart` establishes for elevations.
//
// ═════════════════════════════════════════════════════════════════════
// EVERY DIMENSION HERE IS MEASURED, RULED, OR LABELLED AS NEITHER
// ═════════════════════════════════════════════════════════════════════
// DR-007 §11.7.8 change 3 forbade ANY dimensioned rendering until a real
// 3-port and a real 6-port had been put under a caliper, "because a
// uniform-cell assumption that turns out false is wrong on every plate
// drawing at once". DR-038 took that measurement, DR-041 took four more,
// and this file exists because of the four.
//
//   cell nose      14.5 x 16 mm     DR-028, RULED; DR-038: uniform
//   opening        33.34 x 66.68 mm DR-041, MEASURED 2026-08-11
//   cell pitch Y   22 mm            DR-041, MEASURED
//   cell pitch X   15.95 mm         DR-041, MEASURED
//   gang pitch X   1.8125 in        DR-041, A STANDARD NOBODY MEASURED
//
// The last row is the one to keep an eye on. It is the ganged-device-box
// spacing, taken on corroboration rather than authority: a 1-gang plate
// is 2.75 in wide and a 2-gang is 4.5625 in, and the difference is
// exactly 1.8125 in, so the standard predicts a plate dimension that can
// be checked without trusting the standard. DR-041 §11.40.4 leaves it
// deliberately UNRULED so a later caliper reading overrides it with
// nothing to withdraw, which is §11.27.2's rule that an unruled figure
// with provenance outranks a ruled figure without one.
//
// **Nothing here may be replaced by a figure nobody stated.** Board #167:
// "what must NOT be inferred: a cell size in millimetres nobody stated.
// If the ruling does not give a figure, it is a stated choice and is
// recorded as one, the way SchematicWireStyle records its distances."
//
// ═════════════════════════════════════════════════════════════════════
// THE GRID IS CENTRED IN THE OPENING, NOT ANCHORED TO AN EDGE
// ═════════════════════════════════════════════════════════════════════
// §11.7.8 change 2, from the product photographs: the 1- and 2-port
// straps do NOT fill their vertical span, and the openings sit as a group
// with blank plastic above and below, symmetric about the centre. Only
// the 3-port fills it. "A renderer that lays cells out from the top edge
// will draw a 1-port strap with its jack at the top, and that is simply
// not what the part looks like."
//
// The measured pitches make that centring fall out rather than be
// imposed. Three cells at 22 mm span 2*22 + 16 = 60 mm inside 66.68,
// leaving 3.34 mm top and bottom. Two cells at 15.95 mm span
// 15.95 + 14.5 = 30.45 mm inside 33.34, leaving 1.445 mm either side.
// `plate_geometry_test.dart` asserts the symmetry rather than the
// constants, so a future edit that anchors to an edge fails on the
// artifact instead of on a number.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS FILE DELIBERATELY DOES NOT DRAW
// ═════════════════════════════════════════════════════════════════════
// The plate OUTLINE. A 1-gang Decora is about 2.75 x 4.5 in and that
// figure is an unruled "about" of exactly the kind §11.27.2 says nobody
// should quietly promote, so this file draws openings and cells and stops
// there. DR-041 §11.40.7 records it as open. Adding an outline needs a
// caliper, not a decision.
//
// Depth, module bodies, latch tabs, and the difference between a
// punchdown jack and an inline coupler: §11.7.9 B rules that "the cell
// renders from the front, and the front hides the differences", so the
// renderer needs (connector type, colour) and nothing else. This file
// supplies neither, only where each cell is.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/model/gang.dart';
import 'package:rackmate_core/src/units/len.dart';

/// Diagram-space geometry for one wall plate, on the shared scale.
///
/// Coordinates: the plate's top-left is `(0, 0)`; X grows right, Y grows
/// DOWN, the `DPt`/`ui.Canvas` sense that `rack_geometry.dart` uses.
/// Gang 0 is the LEFTMOST opening, matching `Outlet.gangs`.
@immutable
final class PlateGeometry {
  const PlateGeometry(this.gangCount);

  /// `Outlet.gangs.length`. Also the cover plate's gang count, always
  /// (DR-007 §11.7.8 change 1).
  final int gangCount;

  // ── the scale anchor, shared with rack elevations ────────────────────

  /// Diagram units per millimetre at zoom 1.0.
  ///
  /// A PLATE IS NOT A RACK AND NEEDS ITS OWN ANCHOR. `rack_geometry.dart`
  /// hangs everything off 22 units per RU, which is 0.495 units/mm: a
  /// 14.5 mm keystone nose would render 7.2 units wide, smaller than the
  /// text that has to sit beside it. 4 units per millimetre puts a
  /// 3-gang plate at about 500 units, which is the same order as a rack
  /// panel's 239 and fits a detail pane at zoom 1.0.
  ///
  /// **A STATED CHOICE, and stated here rather than discovered by
  /// somebody measuring a printout.** It is a SCREEN scale and not a
  /// physical claim: everything below derives from it through
  /// [unitsForLen] alone, so changing this number rescales the drawing
  /// and cannot distort it. The rack file's own header records the same
  /// discipline and the one time breaking it cost 11 % on every device
  /// body.
  static const double unitsPerMillimetre = 4;

  /// Diagram units per nanometre, derived so there is exactly one scale
  /// in this file.
  static double get _unitsPerNm =>
      unitsPerMillimetre / Len.nmPerMillimetre.toDouble();

  /// Converts a physical [Len] to diagram units.
  static double unitsForLen(Len l) => l.nm * _unitsPerNm;

  // ── the measured figures, as exact nanometres (CR-001) ───────────────

  /// The keystone front nose: 14.5 mm (DR-028 §11.27.1, RULED).
  static const Len cellWidth = Len(14_500_000);

  /// The keystone front nose: 16 mm (DR-028 §11.27.1, RULED).
  static const Len cellHeight = Len(16_000_000);

  /// The Decora gang opening: 33.34 mm (DR-041, MEASURED).
  static const Len openingWidth = Len(33_340_000);

  /// The Decora gang opening: 66.68 mm (DR-041, MEASURED).
  static const Len openingHeight = Len(66_680_000);

  /// Cell centre to cell centre across a 2-wide strap: 15.95 mm
  /// (DR-041, MEASURED).
  static const Len cellPitchX = Len(15_950_000);

  /// Cell centre to cell centre down a column: 22 mm (DR-041, MEASURED).
  static const Len cellPitchY = Len(22_000_000);

  /// Opening centre to opening centre across a multi-gang plate:
  /// 1.8125 in exactly.
  ///
  /// **THE ONE FIGURE HERE NOBODY MEASURED** (DR-041 §11.40.4).
  ///
  /// Written as `29/16 in` through [Len.nmPerInch] rather than as its
  /// 46.04 mm rounding. The standard is stated in inches, 1.8125 = 29/16
  /// exactly, and the whole expression is exact in integer nanometres:
  /// `25_400_000 × 29 ÷ 16 = 46_037_500`. Spelling it 46.04 mm would
  /// invite the next reader to round a figure that has no rounding in it.
  static const Len gangPitch = Len(Len.nmPerInch * 29 ~/ 16);

  // ── the derived layout ───────────────────────────────────────────────

  /// The whole drawn extent: [gangCount] openings at [gangPitch], each
  /// [openingWidth] wide.
  ///
  /// This is the OPENINGS' extent and not the plate's. See the file
  /// header: the plate outline is an unruled "about" and is not drawn.
  DBox get bounds => DBox.fromLtwh(
    0,
    0,
    gangCount <= 0
        ? 0
        : unitsForLen(openingWidth) + unitsForLen(gangPitch) * (gangCount - 1),
    unitsForLen(openingHeight),
  );

  /// The opening for gang [index], left to right.
  ///
  /// The FIRST opening starts at x = 0 and every later one is offset by
  /// [gangPitch]. On a real plate the leftmost opening sits some distance
  /// in from the plate's edge, and that distance is part of the outline
  /// nobody has measured, so it is not modelled: the drawing is
  /// openings-relative and a later outline shifts all of them together.
  DBox openingAt(int index) {
    final x = unitsForLen(gangPitch) * index;
    return DBox.fromLtwh(
      x,
      0,
      unitsForLen(openingWidth),
      unitsForLen(openingHeight),
    );
  }

  /// The rectangle of cell [cellIndex] on [strap], fitted in gang
  /// [gangIndex]'s opening.
  ///
  /// **CENTRED, both axes, per §11.7.8 change 2.** The formula is
  /// DR-041 §11.40.2's: cell `(c, r)`'s centre sits at
  /// `((c - (W-1)/2)*Px, (r - (H-1)/2)*Py)` relative to the opening
  /// centre, and there is NO width-dependent or height-dependent term
  /// anywhere in it, which is DR-038's uniform-cell finding written as
  /// code.
  ///
  /// Returns null when [cellIndex] is not a cell this strap has, rather
  /// than clamping: a caller asking for cell 6 of a 2 x 3 has a bug, and
  /// returning the last cell would draw a keystone on top of another one.
  DBox? cellAt(int gangIndex, Strap strap, int cellIndex) {
    if (!strap.holdsIndex(cellIndex)) return null;
    final opening = openingAt(gangIndex);
    final cx = (opening.left + opening.right) / 2;
    final cy = (opening.top + opening.bottom) / 2;

    final column = strap.columnOf(cellIndex);
    final row = strap.rowOf(cellIndex);
    final offsetX = (column - (strap.width - 1) / 2) * unitsForLen(cellPitchX);
    final offsetY = (row - (strap.height - 1) / 2) * unitsForLen(cellPitchY);

    final w = unitsForLen(cellWidth);
    final h = unitsForLen(cellHeight);
    return DBox.fromLtwh(
      cx + offsetX - w / 2,
      cy + offsetY - h / 2,
      w,
      h,
    );
  }

  /// Every cell rectangle of [strap] in gang [gangIndex], in cell-index
  /// order (row-major, so top-left first).
  List<DBox> cellsOf(int gangIndex, Strap strap) => [
    for (var i = 0; i < strap.cellCount; i++) cellAt(gangIndex, strap, i)!,
  ];
}
