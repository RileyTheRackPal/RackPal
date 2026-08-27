// rackpal_core/src/draw/scene/plate_geometry.dart — pure Dart.
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
//   gang pitch X   1.8125 in        DR-042, MEASURED 2026-08-11
//   plate outline  2.75 x 4.5 in    DR-042, MEASURED 2026-08-11
//
// EVERY FIGURE IN THIS FILE IS NOW MEASURED, and the last two arrived one
// day after the first four. The gang pitch spent that day here as a
// STATED CHOICE labelled "a standard nobody measured", deliberately
// unruled under DR-041 §11.40.4 so a caliper reading could replace it
// with nothing to withdraw. It did, and there is no supersession entry
// anywhere in the corpus as a result. §11.27.2 records what the other
// path costs: a figure elevated to a ruling had to be un-elevated within
// hours, taking a wrongly-superseded parenthetical with it.
//
// **Nothing here may be replaced by a figure nobody stated.** Board #167:
// "what must NOT be inferred: a cell size in millimetres nobody stated.
// If the ruling does not give a figure, it is a stated choice and is
// recorded as one, the way SchematicWireStyle records its distances."
// The rule stands even though nothing in this file needs it today: the
// next dimension this product wants will arrive the same way.
//
// ═════════════════════════════════════════════════════════════════════
// THE EDGE MARGIN IS INVARIANT, AND THAT IS WHY THE PAIR IS TRUSTED
// ═════════════════════════════════════════════════════════════════════
// An N-gang plate is 2.75 + (N-1) x 1.8125 in wide. Combined with a
// 33.34 mm opening at a 1.8125 in pitch, the plastic between the plate's
// edge and its outermost opening comes out 18.255 mm FOR EVERY N.
//
// That is not arithmetic anybody arranged. It holds only if the outline
// formula and the pitch are BOTH right and it drifts with N if either is
// wrong, so it is evidence about the pair rather than a restatement of
// one of them. `plate_geometry_test.dart` carries it as a case.
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
// The strap's own plastic outside the opening, which §11.7.9 B keeps
// invisible: the cover plate hides it in every elevation this product
// draws. And anything in depth, which §11.7.9 C files as a box-fill fact,
// and box fill is not v1.
//
// Depth, module bodies, latch tabs, and the difference between a
// punchdown jack and an inline coupler: §11.7.9 B rules that "the cell
// renders from the front, and the front hides the differences", so the
// renderer needs (connector type, colour) and nothing else. This file
// supplies neither, only where each cell is.
//
// THE OUTLINE USED TO BE ON THIS LIST and came off at DR-042. What it was
// waiting for was a caliper and not a decision, which is why it was
// recorded as an open measurement rather than resolved by the most
// convenient reading (G4).
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/model/gang.dart';
import 'package:rackpal_core/src/units/len.dart';

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
  /// 1.8125 in exactly (DR-042, MEASURED).
  ///
  /// Written as `29/16 in` through [Len.nmPerInch] rather than as its
  /// 46.04 mm rounding. The figure is stated in inches, 1.8125 = 29/16
  /// exactly, and the whole expression is exact in integer nanometres:
  /// `25_400_000 × 29 ÷ 16 = 46_037_500`. Spelling it 46.04 mm would
  /// invite the next reader to round a figure that has no rounding in it.
  static const Len gangPitch = Len(Len.nmPerInch * 29 ~/ 16);

  /// A 1-gang plate's outline: 2.75 in wide (DR-042, MEASURED).
  ///
  /// A multi-gang plate is [plateWidthFor] wide; this is the N = 1 case
  /// and the base every other one is built from.
  static const Len plateWidth1Gang = Len(Len.nmPerInch * 11 ~/ 4);

  /// A plate's outline height: 4.5 in (DR-042, MEASURED). It does not
  /// change with gang count, which is why there is no `plateHeightFor`.
  static const Len plateHeight = Len(Len.nmPerInch * 9 ~/ 2);

  // ── the derived layout ───────────────────────────────────────────────

  /// An N-gang plate's outline width: `2.75 + (N − 1) × 1.8125` in.
  ///
  /// DERIVED FROM THE TWO MEASURED FIGURES rather than tabulated, so the
  /// 5-gang case a catalog does not stock is expressible and no list of
  /// plate widths can drift from the pitch beside it. Zero gangs is zero
  /// width rather than a 1-gang plate with nothing in it.
  static Len plateWidthFor(int gangCount) => gangCount <= 0
      ? Len.zero
      : Len(plateWidth1Gang.nm + gangPitch.nm * (gangCount - 1));

  /// The plastic between the plate's edge and its outermost opening,
  /// horizontally. **18.255 mm, and the same for every gang count.**
  ///
  /// THE INVARIANCE IS THE EVIDENCE, not a convenience. It holds only if
  /// [plateWidthFor] and [gangPitch] are both right and it drifts with
  /// the gang count if either is wrong, which is why DR-042 leads with it
  /// rather than with either measurement alone.
  static Len get edgeMarginX =>
      Len((plateWidth1Gang.nm - openingWidth.nm) ~/ 2);

  /// The plastic above and below an opening. 23.81 mm.
  static Len get edgeMarginY => Len((plateHeight.nm - openingHeight.nm) ~/ 2);

  /// The whole drawn extent: the plate outline.
  ///
  /// THIS BECAME THE PLATE AT DR-042 and used to be the openings' extent,
  /// because the outline was an unruled *"about"* nobody was allowed to
  /// promote. Consumers that positioned things against `bounds` now get a
  /// box that is 36.51 mm wider and 47.62 mm taller, which is the correct
  /// change and is worth knowing about.
  DBox get bounds => DBox.fromLtwh(
    0,
    0,
    unitsForLen(plateWidthFor(gangCount)),
    gangCount <= 0 ? 0 : unitsForLen(plateHeight),
  );

  /// The opening for gang [index], left to right.
  ///
  /// **INSET BY [edgeMarginX] AND [edgeMarginY]**, so gang 0's opening no
  /// longer starts at the origin: the origin is the plate's top-left
  /// corner and there is real plastic before the first hole. That is the
  /// whole visible difference DR-042 buys, and it is what makes §11.7.8
  /// change 2's "blank plastic above and below" something a person can
  /// see rather than something the corpus asserts.
  DBox openingAt(int index) => DBox.fromLtwh(
    unitsForLen(edgeMarginX) + unitsForLen(gangPitch) * index,
    unitsForLen(edgeMarginY),
    unitsForLen(openingWidth),
    unitsForLen(openingHeight),
  );

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
