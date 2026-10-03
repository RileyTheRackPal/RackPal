// rackpal_core/src/draw/sheet/sheet_def.dart — pure Dart.
//
// Sheet identity: the NCS id, the role, the paper size, and the resolved
// position in the set ("SHEET 3 OF 5"). docs/08-pdf-export.md §2.1/§2.2.
//
// WHY THE WHOLE SET IS RESOLVED BEFORE ANY SHEET IS DRAWN. §5.2's title
// block prints "SHEET i OF n". A running counter incremented during
// rendering is right for a one-rack project and wrong for a two-rack one,
// which is exactly the bug that ships: the exit criterion exercises a
// single rack, so "three-sheet PDF" is the one-rack case of `2N + 1`. So
// [SheetSet] is a dry run over the racks that produces every [SheetDef]
// with its `index`/`total` already baked in, and a sheet builder can only
// read them.
//
// SCOPE. The roles this build emits are [SheetRole]'s values; read the enum.
//
// **THIS COMMENT SAID "exactly three" UNTIL 2026-09-23, AND THEN "FOUR"**,
// which was wrong from the day T0.01 landed (M6-B) and would have been
// wrong twice over when T0.00 did (M6-A). A count written in prose beside
// the enum it counts is this corpus's most-repeated failure, and nothing
// connects adding a role to editing this sentence, so it no longer counts.
//
// The rest of §2.2's table (T6.01+ interconnect) is M6 and not yet built;
// T0.00, the cover, arrived at M6-A, T0.01, the legend, at M6-B, T0.02,
// the exceptions, at M6-C, T6.20, unused home runs, at M6-E1, T5.01 at
// M6-E2, and the Pull Sheet and Termination Schedule at M6-K. The
// unbuilt ones are absent from [SheetRole] rather than stubbed, which is
// what lets a user-facing document state what
// prints by naming the roles rather than by counting anything
// (docs/21 §21.7).

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/enums.dart' show SheetNumbering;
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/print_units.dart';

/// The paper sizes this sheet set uses (docs/08 §6.1).
///
/// Only the two roles in this build are declared. §6.1's table also assigns
/// ANSI B landscape to the cover/legend/interconnect sheets and ANSI A
/// portrait to the pull sheet; those values arrive with those sheets rather
/// than sitting here unused.
///
/// LANDSCAPE IS AN EXPLICITLY WIDE FORMAT, never a rotated portrait one.
/// `pw.FullPage._getConstraints` reads `pageFormat.width`/`height`
/// UNROTATED, so a `PageOrientation.landscape` theme plus a full-page
/// painter disagree about which axis is which. 792 × 612 has no such seam.
enum SheetSize {
  /// 792 × 1224 pt. Rack elevations — a 45 RU rack is 78.75 in tall and at
  /// 1:8 that is 9.84 in, which fits portrait with room for the RU rulers
  /// and the load gutter (§6.1).
  ansiBPortrait(11 * kPdfPointsPerInch, 17 * kPdfPointsPerInch, 'B'),

  /// 792 × 612 pt. Equipment list and details (§6.1).
  ansiALandscape(11 * kPdfPointsPerInch, 8.5 * kPdfPointsPerInch, 'A'),

  /// 612 × 792 pt. The Pull Sheet (§6.1): carried, marked up, initialled,
  /// so it is the one schedule a person holds rather than reads at a desk.
  ansiAPortrait(8.5 * kPdfPointsPerInch, 11 * kPdfPointsPerInch, 'A'),

  /// 1224 × 792 pt. The device location plan (§6.1, `PLAN-H/1`).
  ///
  /// LANDSCAPE BECAUSE A BUILDING IS WIDE, and because the exit criterion
  /// prints on ANSI B: DR-037 §11.36.1 requires the drill's `T1.01` on a
  /// real greyscale laser at that size, so the sheet the drill judges and
  /// the sheet this emits are the same paper.
  ansiBLandscape(17 * kPdfPointsPerInch, 11 * kPdfPointsPerInch, 'B');

  const SheetSize(this.widthPt, this.heightPt, this.sizeCode);

  final double widthPt;
  final double heightPt;

  /// What the title block's SIZE field prints — `B` or `A` (§5.2).
  final String sizeCode;

  /// Whether the title block is the compact full-width strip rather than
  /// the 396 × 115 bottom-right block (§5.2: "on ANSI A a full-width
  /// 690 × 43 pt strip along the bottom, so the schedule table is not
  /// notched").
  bool get usesCompactTitleBlock => sizeCode == 'A';
}

/// The sheet roles this build emits (§2.2 rows 4, 5 and n+4, plus docs/15
/// §8's `T1.01`).
///
/// **DECLARATION ORDER IS NOT SHEET ORDER.** [SheetSet.forRacks] decides
/// where each role lands in the set, and DR-149 §11.148.3 puts the plans
/// after `T0.02` and before the elevations: a reader orients in the
/// building before they open a rack. `T0.00`–`T0.02` are M6's and are not
/// emitted yet, so today the plans come first.
enum SheetRole {
  /// docs/08 §5.5's `T0.00`, the cover and drawing index (M6-A, `#311`).
  /// FIRST in every set and `ON` (docs/08 §2.2), ANSI B landscape (§6.1).
  /// Titled `COVER` until M6-A3 gave it the index, so the title never named
  /// a block the sheet did not carry.
  cover(
    'COVER AND DRAWING INDEX',
    SheetSize.ansiBLandscape,
    perRack: false,
    shortTitle: 'COVER',
  ),

  /// docs/08 §5.4's `T0.01`, the symbol legend (M6-B, `#316`). FIRST in
  /// every set and `ON` (docs/08 §2.2's table), ANSI B landscape as the
  /// cover, legend and exceptions all are (§6.1).
  symbolLegend(
    'SYMBOL LEGEND',
    SheetSize.ansiBLandscape,
    perRack: false,
    shortTitle: 'LEGEND',
  ),

  /// docs/08 §2.2's `T0.02`, exceptions and acknowledgements (M6-C,
  /// `#322`, DR-214). `ON`: in every set, after the legend, because CR-022
  /// put the findings on the deliverable instead of letting them withhold
  /// it. Continues on `T0.03` and on when one page does not hold them.
  exceptions(
    'EXCEPTIONS AND ACKNOWLEDGEMENTS',
    SheetSize.ansiBLandscape,
    perRack: false,
    shortTitle: 'EXCEPTIONS',
  ),

  /// docs/15 §8's `T1.01`, one per `PlanUnderlay` that carries at least one
  /// pin.
  ///
  /// **`AUTO`, AND THE DEFAULT IS WHERE THAT LIVES** (docs/15 §8).
  /// [SheetSet.forRacks]'s `planUnderlays` defaults to empty, so a project
  /// with no floorplan resolves the identical set it resolved before this
  /// role existed. That is what keeps M6's exit criterion still true: the
  /// four starters are byte-verified goldens (AC-052), and a sheet that
  /// were `ON` would oblige all four to carry raster.
  devicePlan(
    'DEVICE LOCATION PLAN',
    SheetSize.ansiBLandscape,
    perRack: false,
    shortTitle: 'PLAN',
    zoned: true,
  ),

  rackElevationFront(
    'RACK ELEVATION — FRONT',
    SheetSize.ansiBPortrait,
    perRack: true,
    shortTitle: 'FRONT ELEV.',
    zoned: true,
  ),
  rackElevationRear(
    'RACK ELEVATION — REAR',
    SheetSize.ansiBPortrait,
    perRack: true,
    shortTitle: 'REAR ELEV.',
    zoned: true,
  ),

  /// docs/08 §2.2's `T6.10`, the Pull Sheet (M6-K1, `#978`, DR-222). `ON`,
  /// ANSI A portrait, `T6.10` to `T6.14` then the overflow pool.
  pullSheet(
    'PULL SHEET',
    SheetSize.ansiAPortrait,
    perRack: false,
    shortTitle: 'PULL SHEET',
  ),

  /// docs/08 §2.2's Termination Schedule, `T6.15` since DR-222 (it was
  /// `T6.11`, which left a second Pull Sheet page no id). `ON`, ANSI A
  /// landscape, `T6.15` to `T6.19` then the pool (M6-K2, `#979`).
  terminationSchedule(
    'TERMINATION SCHEDULE',
    SheetSize.ansiALandscape,
    perRack: false,
    shortTitle: 'TERMINATION',
  ),

  /// docs/08 §2.2's `T6.20`, Unused Home Runs (M6-E1, `#332`, DR-220).
  /// `AUTO`: emitted iff a home run has an open end, so
  /// [SheetSet.forRacks]' `unusedHomeRunSheets` defaults to zero and a
  /// project with none resolves the set it resolved before this role
  /// existed. ANSI A landscape, the schedules' paper (§6.1).
  unusedHomeRuns(
    'UNUSED HOME RUNS',
    SheetSize.ansiALandscape,
    perRack: false,
    shortTitle: 'UNUSED RUNS',
  ),
  equipmentList(
    'EQUIPMENT LIST AND MATERIALS',
    SheetSize.ansiALandscape,
    perRack: false,
    shortTitle: 'EQUIPMENT LIST',
  ),

  /// docs/08 §2.2's `T5.01`, Plate, Panel & Pinout Details (M6-E2c,
  /// `#976`, DR-221). `AUTO`: emitted iff a pinout is non-standard, LAST
  /// in the set (`n+5`), ANSI A landscape. The title is the canonical name
  /// though this pass prints pinout tables only (§11.220.1).
  pinoutDetails(
    'PLATE, PANEL AND PINOUT DETAILS',
    SheetSize.ansiALandscape,
    perRack: false,
    shortTitle: 'PINOUT DETAILS',
  );

  const SheetRole(
    this.title,
    this.size, {
    required this.perRack,
    required this.shortTitle,
    this.zoned = false,
  });

  /// Whether this sheet carries §5.1's zone band and grid (DR-215
  /// §11.214.1): the drawings do, the tables and front matter do not.
  final bool zoned;

  /// What the title block's sheet-title line prints.
  final String title;

  /// What a NARROW drawing-index row prints instead of [title] (DR-212
  /// §11.211.4): in three sub-columns a title has about 70 pt, and
  /// `RACK ELEVATION — FRONT · RK-10` cut to fit lost either the face or
  /// the rack, the two facts that tell one elevation row from the next.
  /// The full [title] is printed wherever it fits.
  final String shortTitle;
  final SheetSize size;

  /// Whether the set contains one of these per `Rack`.
  final bool perRack;
}

/// docs/08 §2.1's NCS identifier grammar,
/// `[Discipline][SheetType].[Sequence]`.
/// T0.01's id, in one place: the legend's own, and the one every other
/// sheet's title block points at.
const String _kLegendNcsId = 'T0.01';
const String _kCoverNcsId = 'T0.00';

final RegExp kNcsIdPattern = RegExp(r'^[A-Z]{1,2}\d\.\d{2}$');

/// Whether [id] is a well-formed NCS sheet identifier.
///
/// A failure is a NOTICE in the export summary and NEVER a gate (CR-023,
/// G3 — "a heuristic may never hold a user's deliverable hostage").
bool isValidNcsId(String id) => kNcsIdPattern.hasMatch(id);

/// Sheet ids docs/08 §2.2 gives to sheets this build does not emit, mapped
/// to what they are reserved FOR.
///
/// §2.2's "Not in v1, and this is a ruling, not an omission" names `T6.40`
/// Power Schedule and `T6.50` Network/IP Schedule as v1.1 sheets. A sheet
/// of some other type printed under one of those ids is not a cosmetic
/// problem: two revisions of one project would carry the same sheet number
/// on different drawings, which is the one thing a sheet number exists to
/// prevent.
const Map<String, String> kReservedNcsIds = <String, String>{
  'T6.40': 'the v1.1 Power Schedule',
  'T6.50': 'the v1.1 Network/IP Schedule',
};

/// Whether [id] is spoken for by a sheet type this build does not emit.
bool isReservedNcsId(String id) => kReservedNcsIds.containsKey(id);

String _ncsNotice(String id) =>
    'Sheet id "$id" does not match the NCS pattern '
    '${kNcsIdPattern.pattern} — printed as-is (CR-023).';

String _reservedNotice(String id) =>
    'Sheet id "$id" is reserved for ${kReservedNcsIds[id]} '
    '(docs/08 §2.2) — printed as-is (CR-023).';

/// Says WHY the schedule's sheet numbers jump. See [equipmentListNcsId].
String _overflowNotice(int pages, int from) {
  const last = kEquipmentListBlockStart + kEquipmentListBlockSize - 1;
  return 'The equipment list needs $pages pages and docs/08 §2.2 gives it '
      'T6.$kEquipmentListBlockStart–T6.$last, so page '
      '${kEquipmentListBlockSize + 1} onward is numbered from '
      'T6.$from — T6.4x and T6.5x are reserved.';
}

/// The same, for T6.20 (DR-220 §11.219.5). See [unusedHomeRunsNcsId].
String _unusedOverflowNotice(int pages, int from) {
  const last = kUnusedHomeRunsBlockStart + kUnusedHomeRunsBlockSize - 1;
  return 'Unused home runs need $pages pages and docs/08 §2.2 gives them '
      'T6.$kUnusedHomeRunsBlockStart–T6.$last, so page '
      '${kUnusedHomeRunsBlockSize + 1} onward is numbered from '
      'T6.$from — T6.30 to T6.5x are taken or reserved.';
}

/// The first sequence number T6.20 uses (docs/08 §2.2, DR-220).
const int kUnusedHomeRunsBlockStart = 20;

/// How many sheet numbers T6.20 has to itself: `T6.20` to `T6.29`. The
/// next is the equipment list's `T6.30`.
const int kUnusedHomeRunsBlockSize = 10;

/// The NCS id for T6.20 page [page], 0-based: `T6.20` to `T6.29`, then
/// from [kEquipmentListOverflowStart] (DR-220 §11.219.5).
///
/// THE OVERFLOW IS SHARED, AND T6.20 TAKES IT FIRST because it sits first
/// in the set. The equipment list's own overflow then starts after it:
/// see [equipmentListNcsId]'s `overflowFrom`. Two schedules each counting
/// from `T6.60` would print one sheet number on two drawings, which is the
/// one thing a sheet number exists to prevent.
String unusedHomeRunsNcsId(
  int page, {
  int overflowFrom = kEquipmentListOverflowStart,
}) {
  final sequence = page < kUnusedHomeRunsBlockSize
      ? kUnusedHomeRunsBlockStart + page
      : overflowFrom + page - kUnusedHomeRunsBlockSize;
  return 'T6.${sequence.toString().padLeft(2, '0')}';
}

/// How many overflow ids T6.20 takes from [kEquipmentListOverflowStart]
/// for [pages] pages.
int _unusedOverflowCount(int pages) =>
    pages > kUnusedHomeRunsBlockSize ? pages - kUnusedHomeRunsBlockSize : 0;

/// The Pull Sheet's block, `T6.10` to `T6.14` (DR-222 §11.221.1).
const int kPullSheetBlockStart = 10;

/// The Termination Schedule's block, `T6.15` to `T6.19`. It was `T6.11`,
/// which left a second Pull Sheet page no id.
const int kTerminationBlockStart = 15;

/// How many ids each schedule's block holds.
const int kScheduleBlockSize = 5;

/// The id of page [page] (0-based) of a schedule whose block starts at
/// [blockStart], its overflow taken from [overflowFrom] on.
String scheduleNcsId(
  int page, {
  required int blockStart,
  int overflowFrom = kEquipmentListOverflowStart,
}) {
  final sequence = page < kScheduleBlockSize
      ? blockStart + page
      : overflowFrom + page - kScheduleBlockSize;
  return 'T6.${sequence.toString().padLeft(2, '0')}';
}

int _scheduleOverflowCount(int pages) =>
    pages > kScheduleBlockSize ? pages - kScheduleBlockSize : 0;

String _scheduleOverflowNotice(String name, int pages, int block, int from) =>
    '$name needs $pages pages and DR-222 gives it '
    'T6.$block–T6.${block + kScheduleBlockSize - 1}, so page '
    '${kScheduleBlockSize + 1} onward is numbered from T6.$from.';

/// The first sequence number the equipment list uses — §2.2's `T6.30`.
const int kEquipmentListBlockStart = 30;

/// How many sheet numbers the equipment list has to itself: `T6.30`
/// through `T6.39`. The next number is [kReservedNcsIds]' `T6.40`.
const int kEquipmentListBlockSize = 10;

/// Where an equipment list too long for its block continues, past BOTH
/// reserved decades — `T6.40` Power Schedule and `T6.50` Network/IP
/// Schedule. Their continuation pages would want `T6.41…` and `T6.51…`,
/// so the whole of each decade is left alone rather than only its first
/// number.
const int kEquipmentListOverflowStart = 60;

/// The NCS id for schedule page [page], 0-based.
///
/// `T6.30`, `T6.31`, … `T6.39`, then `T6.60`, `T6.61`, … . [overflowFrom]
/// moves that second run past any overflow T6.20 has already taken (DR-220
/// §11.219.5); it is [kEquipmentListOverflowStart] in a set where T6.20
/// fits its own ten.
///
/// THE JUMP IS THE POINT. This was `'T6.${30 + page}'`, which runs off the
/// end of its own block at the eleventh page and emits `T6.40` — the id
/// §2.2 reserves for the v1.1 Power Schedule — while [isValidNcsId] waved
/// it through, so the confusable case was silent and the harmless one
/// (`T6.100`, at page 71) was the one that raised a notice. A project of
/// roughly 370 devices reaches eleven pages, which is a large job and not
/// an absurd one.
///
/// The jump is not silent either: [SheetSet.forRacks] raises a notice
/// whenever it is used, because a reader looking for page 11 between
/// `T6.39` and `T6.60` is owed the reason for the gap.
String equipmentListNcsId(
  int page, {
  int overflowFrom = kEquipmentListOverflowStart,
}) {
  final sequence = page < kEquipmentListBlockSize
      ? kEquipmentListBlockStart + page
      : overflowFrom + page - kEquipmentListBlockSize;
  return 'T6.${sequence.toString().padLeft(2, '0')}';
}

/// One resolved sheet: its identity, its role, and where it sits in the
/// set. Everything a title block needs about "which sheet is this".
@immutable
final class SheetDef {
  const SheetDef({
    required this.ncsId,
    required this.role,
    required this.index,
    required this.total,
    this.rackId,
    this.rackDesignator,
    this.underlayId,
    this.underlayName,
    this.legendNcsId,
    this.stamped = false,
  });

  /// Whether this sheet prints the ISSUED FOR CONSTRUCTION stamp (DR-216).
  /// Set by the resolver on EVERY sheet of a stamped set, the way
  /// [legendNcsId] is, so each sheet's layout and furniture see it without
  /// a second parameter threaded through every builder.
  final bool stamped;

  /// The id of the set's legend sheet, on every OTHER sheet of a set that
  /// has one, for the title block's `SYMBOL LEGEND: SEE SHEET …` (docs/08
  /// §5.2, CR-023, M6-B5). Null on the legend itself and in a set with no
  /// legend, where pointing at a sheet that is not in the file would be
  /// worse than saying nothing.
  final String? legendNcsId;

  /// The stable NCS identity — `T2.01`, `T2.02`, `T6.30`.
  final String ncsId;
  final SheetRole role;

  /// 1-based position in the resolved set.
  final int index;

  /// Total sheets in the resolved set — known before rendering starts.
  final int total;

  /// The rack this sheet draws, for the per-rack roles.
  final Uuid? rackId;

  /// That rack's designator, carried so a caller does not have to re-look
  /// it up to name the sheet.
  final String? rackDesignator;

  /// The underlay this sheet draws, for [SheetRole.devicePlan].
  final Uuid? underlayId;

  /// That underlay's name — `Level 1`, `Basement` — carried on
  /// [rackDesignator]'s precedent so the title block does not re-look it
  /// up. A plan sheet's subtitle is the floor it depicts, and a set with
  /// three of them is unreadable without one.
  final String? underlayName;

  String get title => role.title;
  SheetSize get size => role.size;

  @override
  bool operator ==(Object other) =>
      other is SheetDef &&
      other.ncsId == ncsId &&
      other.role == role &&
      other.index == index &&
      other.total == total &&
      other.rackId == rackId &&
      other.rackDesignator == rackDesignator &&
      other.underlayId == underlayId &&
      other.underlayName == underlayName &&
      other.legendNcsId == legendNcsId &&
      other.stamped == stamped;

  @override
  int get hashCode => Object.hash(
    ncsId,
    role,
    index,
    total,
    rackId,
    rackDesignator,
    underlayId,
    underlayName,
    legendNcsId,
    stamped,
  );

  @override
  String toString() => 'SheetDef($ncsId, ${role.name}, $index/$total)';
}

/// The resolved sheet list for one export — §8.1 note 4's "dry run over the
/// resolved sheet list", which must complete before any sheet is rendered
/// so "SHEET i OF n" can be right.
@immutable
final class SheetSet {
  const SheetSet._(this.sheets, this.notices);

  /// Two elevation sheets per rack (front, then rear), in rack order, then
  /// one equipment list.
  ///
  /// Rack order is `Rack.order` (a fractional index, so lexicographic on
  /// its string), with `Rack.id` as the tiebreak — deterministic and never
  /// dependent on `Map` iteration order (§8.4).
  ///
  /// NCS SEQUENCE WITH MORE THAN ONE RACK. §2.2 names `T2.01` front and
  /// `T2.02` rear for the single-rack case. With N racks those two ids
  /// cannot both be reused, so the sequence continues within sheet type 2:
  /// rack i (0-based) gets `T2.{2i+1}` front and `T2.{2i+2}` rear. One rack
  /// therefore reproduces the doc's `T2.01`/`T2.02` exactly, and two racks
  /// produce `T2.01`–`T2.04` rather than a collision. Above 49 racks the
  /// sequence would exceed two digits and stop matching [kNcsIdPattern];
  /// that is reported as a notice, not a failure.
  ///
  /// [equipmentListSheets] IS THE SCHEDULE'S PAGE COUNT, AND IT COMES FROM
  /// A REAL PAGINATION. A long enough equipment list does not fit one
  /// sheet, and a "SHEET 3 OF 3" printed on the first of two schedule
  /// pages is exactly the kind of quietly-wrong figure this dry run exists
  /// to prevent. The caller paginates first — `paginateEquipmentList` is
  /// pure and needs only the drawing area and the measurer — and hands the
  /// count in here. Continuation pages take `T6.31`, `T6.32`, … — see
  /// [equipmentListNcsId] for why they stop at `T6.39`.
  factory SheetSet.forRacks(
    Iterable<Rack> racks, {
    int equipmentListSheets = 1,
    int exceptionSheets = 1,
    int unusedHomeRunSheets = 0,
    int pinoutSheets = 0,
    int pullSheets = 0,
    int terminationSheets = 0,
    bool stamped = false,
    Iterable<PlanUnderlay> planUnderlays = const <PlanUnderlay>[],
    SheetNumbering numbering = SheetNumbering.simple,
  }) {
    assert(
      exceptionSheets >= 1,
      'SheetSet.forRacks: T0.02 is always at least one sheet; an empty '
      'report is a page that says so (#325)',
    );
    assert(
      equipmentListSheets >= 1,
      'SheetSet.forRacks: the equipment list is always at least one sheet '
      '— a project with no equipment gets a sheet that says so',
    );
    final ordered = racks.toList()
      ..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
      });

    // PLAN ORDER IS `PlanUnderlay.order`, WHICH IS THE USER'S. A
    // `FracIndex` on its string, with the id as the tiebreak, exactly as
    // racks sort above: deterministic and never `Map` iteration order
    // (§8.4). DR-149 §11.148.5 takes this rather than deciding it, because
    // every other per-entity sheet in this product already sorts this way.
    final plans = planUnderlays.toList()
      ..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
      });

    // +2 FOR T0.00 AND T0.01, which every set carries (docs/08 §2.2, both
    // `ON`). The cover is FIRST, because a client deliverable opens on it
    // (DR-005 §11.5.3); the legend follows, as the cover's own title block
    // points at it. Then T0.02's pages, which every set carries too, as
    // many as the caller paginated (DR-214 §11.213.5).
    final total =
        2 +
        exceptionSheets +
        plans.length +
        ordered.length * 2 +
        pullSheets +
        terminationSheets +
        unusedHomeRunSheets +
        equipmentListSheets +
        pinoutSheets;
    final sheets = <SheetDef>[
      SheetDef(
        ncsId: _kCoverNcsId,
        role: SheetRole.cover,
        index: 1,
        total: total,
        legendNcsId: _kLegendNcsId,
        stamped: stamped,
      ),
      SheetDef(
        ncsId: _kLegendNcsId,
        role: SheetRole.symbolLegend,
        index: 2,
        total: total,
        stamped: stamped,
      ),
    ];
    var index = 3;
    for (var page = 0; page < exceptionSheets; page++) {
      sheets.add(
        SheetDef(
          ncsId: 'T0.${(2 + page).toString().padLeft(2, '0')}',
          role: SheetRole.exceptions,
          index: index++,
          total: total,
          legendNcsId: _kLegendNcsId,
          stamped: stamped,
        ),
      );
    }

    // FIRST IN THE SET, AND THAT IS DR-149 §11.148.3 RATHER THAN A
    // NUMERIC ACCIDENT. Plans go after `T0.02` and before the elevations
    // because a reader orients in the building before they open a rack;
    // `T0.00` and `T0.01` now precede them and `T0.02` will, so "after the
    // cover block" is the position. docs/08 §2.2's
    // own table is not numeric either — `T5.01` sits last.
    //
    // WHICH UNDERLAYS REACH HERE IS THE CALLER'S QUESTION, not this
    // factory's. docs/15 §8 emits one sheet per underlay THAT CARRIES AT
    // LEAST ONE PIN, and answering that needs the whole document; the
    // caller passes the survivors, exactly as it passes a real
    // `equipmentListSheets` from a real pagination. `planUnderlaysOf` is
    // the derivation.
    for (var i = 0; i < plans.length; i++) {
      final plan = plans[i];
      sheets.add(
        SheetDef(
          ncsId: 'T1.${(i + 1).toString().padLeft(2, '0')}',
          role: SheetRole.devicePlan,
          index: index++,
          total: total,
          underlayId: plan.id,
          underlayName: plan.name,
          legendNcsId: _kLegendNcsId,
          stamped: stamped,
        ),
      );
    }

    for (var i = 0; i < ordered.length; i++) {
      final rack = ordered[i];
      for (final role in const [
        SheetRole.rackElevationFront,
        SheetRole.rackElevationRear,
      ]) {
        final sequence = role == SheetRole.rackElevationFront
            ? i * 2 + 1
            : i * 2 + 2;
        sheets.add(
          SheetDef(
            ncsId: 'T2.${sequence.toString().padLeft(2, '0')}',
            role: role,
            index: index++,
            total: total,
            rackId: rack.id,
            rackDesignator: rack.designator,
            legendNcsId: _kLegendNcsId,
            stamped: stamped,
          ),
        );
      }
    }

    // THE OVERFLOW POOL IS ONE COUNTER, drawn in set order (DR-222
    // §11.221.1): the Pull Sheet's overflow, then the Termination
    // Schedule's, then T6.20's, then the equipment list's. Each starts where
    // the one before it stopped, so no id is printed on two sheets however
    // many of them overflow.
    var pool = kEquipmentListOverflowStart;

    // T6.10 AND T6.15 ARE `n+1` AND `n+2` (docs/08 §2.2), both `ON`: the
    // export always passes at least one page of each. Zero is the default
    // here so a set built only to test the racks stays the set it was.
    final pullFrom = pool;
    pool += _scheduleOverflowCount(pullSheets);
    for (var page = 0; page < pullSheets; page++) {
      sheets.add(
        SheetDef(
          ncsId: scheduleNcsId(
            page,
            blockStart: kPullSheetBlockStart,
            overflowFrom: pullFrom,
          ),
          role: SheetRole.pullSheet,
          index: index++,
          total: total,
          legendNcsId: _kLegendNcsId,
          stamped: stamped,
        ),
      );
    }
    final terminationFrom = pool;
    pool += _scheduleOverflowCount(terminationSheets);
    for (var page = 0; page < terminationSheets; page++) {
      sheets.add(
        SheetDef(
          ncsId: scheduleNcsId(
            page,
            blockStart: kTerminationBlockStart,
            overflowFrom: terminationFrom,
          ),
          role: SheetRole.terminationSchedule,
          index: index++,
          total: total,
          legendNcsId: _kLegendNcsId,
          stamped: stamped,
        ),
      );
    }

    // T6.20 IS `n+3`, BEFORE T6.30 (docs/08 §2.2, DR-220 §11.219.5), and
    // the interconnect sheets will land ahead of the schedules. Zero pages
    // is the AUTO sheet absent: the caller paginated nothing because
    // nothing is unused.
    final unusedFrom = pool;
    pool += _unusedOverflowCount(unusedHomeRunSheets);
    for (var page = 0; page < unusedHomeRunSheets; page++) {
      sheets.add(
        SheetDef(
          ncsId: unusedHomeRunsNcsId(page, overflowFrom: unusedFrom),
          role: SheetRole.unusedHomeRuns,
          index: index++,
          total: total,
          legendNcsId: _kLegendNcsId,
          stamped: stamped,
        ),
      );
    }

    final equipmentOverflowFrom = pool;
    for (var page = 0; page < equipmentListSheets; page++) {
      sheets.add(
        SheetDef(
          ncsId: equipmentListNcsId(
            page,
            overflowFrom: equipmentOverflowFrom,
          ),
          role: SheetRole.equipmentList,
          index: index++,
          total: total,
          legendNcsId: _kLegendNcsId,
          stamped: stamped,
        ),
      );
    }

    // T5.01 IS LAST (docs/08 §2.2's `n+5`, DR-221 §11.220.6): a set that is
    // not numeric, as the table itself says. Type 5 has no other sheet and
    // no reserved id, so the pages simply count up. Zero pages is the AUTO
    // sheet absent.
    for (var page = 0; page < pinoutSheets; page++) {
      sheets.add(
        SheetDef(
          ncsId: 'T5.${(page + 1).toString().padLeft(2, '0')}',
          role: SheetRole.pinoutDetails,
          index: index++,
          total: total,
          legendNcsId: _kLegendNcsId,
          stamped: stamped,
        ),
      );
    }

    // THE PATTERN IS CHECKED UNDER `ncs` ONLY (CR-066, docs/08 §2.1): it is
    // the scheme that prints the id as the sheet's number, and failing a
    // four-page residential set on a 200-sheet convention is the nannying
    // `simple` exists to spare. A RESERVED id is told under both, because
    // `SHEET NO.` prints the id on every sheet whichever scheme numbers it.
    final checkPattern = numbering == SheetNumbering.ncs;
    final notices = <String>[
      for (final sheet in sheets)
        if (checkPattern && !isValidNcsId(sheet.ncsId))
          _ncsNotice(sheet.ncsId)
        else if (isReservedNcsId(sheet.ncsId))
          _reservedNotice(sheet.ncsId),
      if (pullSheets > kScheduleBlockSize)
        _scheduleOverflowNotice(
          'The Pull Sheet',
          pullSheets,
          kPullSheetBlockStart,
          pullFrom,
        ),
      if (terminationSheets > kScheduleBlockSize)
        _scheduleOverflowNotice(
          'The Termination Schedule',
          terminationSheets,
          kTerminationBlockStart,
          terminationFrom,
        ),
      if (unusedHomeRunSheets > kUnusedHomeRunsBlockSize)
        _unusedOverflowNotice(unusedHomeRunSheets, unusedFrom),
      if (equipmentListSheets > kEquipmentListBlockSize)
        _overflowNotice(equipmentListSheets, equipmentOverflowFrom),
    ];

    return SheetSet._(List.unmodifiable(sheets), List.unmodifiable(notices));
  }

  final List<SheetDef> sheets;

  /// Non-blocking notices raised while resolving (currently NCS id
  /// validation only). Reported in the export summary; never a gate.
  final List<String> notices;

  int get total => sheets.length;

  @override
  String toString() => 'SheetSet(${sheets.length} sheets)';
}
