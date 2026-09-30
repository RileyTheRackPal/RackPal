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
// SCOPE. This build emits FOUR sheet ROLES: front elevation, rear elevation,
// equipment list, and the device location plan.
//
// **THIS COMMENT SAID "exactly three" UNTIL 2026-09-23**, and had been wrong
// since `PLAN-H/1` added [SheetRole.devicePlan] on 2026-09-09. A count
// written in prose beside the enum it counts is this corpus's most-repeated
// failure, and nothing connects adding a role to editing this sentence. The
// enum is the list; read it rather than this line.
//
// The rest of §2.2's table (T0.00 cover, T0.02 exceptions, T6.01+
// interconnect, T6.10 pull sheet, T6.11 termination schedule, T6.20 unused
// home runs, T5.01 pinout details) is M6 and not yet built; T0.01, the
// legend, arrived at M6-B. The unbuilt ones are absent from [SheetRole]
// rather than stubbed, which is what lets a user-facing document state what
// prints by naming the roles rather than by counting anything
// (docs/21 §21.7).

import 'package:meta/meta.dart';
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
  /// docs/08 §5.4's `T0.01`, the symbol legend (M6-B, `#316`). FIRST in
  /// every set and `ON` (docs/08 §2.2's table), ANSI B landscape as the
  /// cover, legend and exceptions all are (§6.1).
  symbolLegend(
    'SYMBOL LEGEND',
    SheetSize.ansiBLandscape,
    perRack: false,
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
  ),

  rackElevationFront(
    'RACK ELEVATION — FRONT',
    SheetSize.ansiBPortrait,
    perRack: true,
  ),
  rackElevationRear(
    'RACK ELEVATION — REAR',
    SheetSize.ansiBPortrait,
    perRack: true,
  ),
  equipmentList(
    'EQUIPMENT LIST AND MATERIALS',
    SheetSize.ansiALandscape,
    perRack: false,
  );

  const SheetRole(this.title, this.size, {required this.perRack});

  /// What the title block's sheet-title line prints.
  final String title;
  final SheetSize size;

  /// Whether the set contains one of these per `Rack`.
  final bool perRack;
}

/// docs/08 §2.1's NCS identifier grammar,
/// `[Discipline][SheetType].[Sequence]`.
/// T0.01's id, in one place: the legend's own, and the one every other
/// sheet's title block points at.
const String _kLegendNcsId = 'T0.01';

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
String _overflowNotice(int pages) {
  const last = kEquipmentListBlockStart + kEquipmentListBlockSize - 1;
  return 'The equipment list needs $pages pages and docs/08 §2.2 gives it '
      'T6.$kEquipmentListBlockStart–T6.$last, so page '
      '${kEquipmentListBlockSize + 1} onward is numbered from '
      'T6.$kEquipmentListOverflowStart — T6.4x and T6.5x are reserved.';
}

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
/// `T6.30`, `T6.31`, … `T6.39`, then `T6.60`, `T6.61`, … .
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
String equipmentListNcsId(int page) {
  final sequence = page < kEquipmentListBlockSize
      ? kEquipmentListBlockStart + page
      : kEquipmentListOverflowStart + page - kEquipmentListBlockSize;
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
  });

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
      other.legendNcsId == legendNcsId;

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
    Iterable<PlanUnderlay> planUnderlays = const <PlanUnderlay>[],
  }) {
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

    // +1 FOR T0.01, which every set carries (docs/08 §2.2, `ON`).
    final total = 1 + plans.length + ordered.length * 2 + equipmentListSheets;
    final sheets = <SheetDef>[
      SheetDef(
        ncsId: _kLegendNcsId,
        role: SheetRole.symbolLegend,
        index: 1,
        total: total,
      ),
    ];
    var index = 2;

    // FIRST IN THE SET, AND THAT IS DR-149 §11.148.3 RATHER THAN A
    // NUMERIC ACCIDENT. Plans go after `T0.02` and before the elevations
    // because a reader orients in the building before they open a rack;
    // `T0.00`–`T0.02` are M6's and are not emitted yet, so today "after
    // the cover block" and "first" are the same position. docs/08 §2.2's
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
          ),
        );
      }
    }

    for (var page = 0; page < equipmentListSheets; page++) {
      sheets.add(
        SheetDef(
          ncsId: equipmentListNcsId(page),
          role: SheetRole.equipmentList,
          index: index++,
          total: total,
          legendNcsId: _kLegendNcsId,
        ),
      );
    }

    final notices = <String>[
      for (final sheet in sheets)
        if (!isValidNcsId(sheet.ncsId))
          _ncsNotice(sheet.ncsId)
        else if (isReservedNcsId(sheet.ncsId))
          _reservedNotice(sheet.ncsId),
      if (equipmentListSheets > kEquipmentListBlockSize)
        _overflowNotice(equipmentListSheets),
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
