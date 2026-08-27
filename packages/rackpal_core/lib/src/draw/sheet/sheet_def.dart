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
// SCOPE. This build emits exactly three sheet ROLES — front elevation, rear
// elevation, equipment list. The other nine sheets in §2.2's table (T0.00
// cover, T0.01 legend, T0.02 exceptions, T6.01+ interconnect, T6.10 pull
// sheet, T6.11 termination schedule, T6.20 unused home runs, T5.01 pinout
// details) are M6 and most of them need `Link`s, which do not exist until
// M2. They are absent from [SheetRole] rather than stubbed.

import 'package:meta/meta.dart';
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
  ansiALandscape(11 * kPdfPointsPerInch, 8.5 * kPdfPointsPerInch, 'A');

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

/// The three sheet roles this build emits (§2.2 rows 4, 5 and n+4).
enum SheetRole {
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
  });

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
      other.rackDesignator == rackDesignator;

  @override
  int get hashCode =>
      Object.hash(ncsId, role, index, total, rackId, rackDesignator);

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

    final total = ordered.length * 2 + equipmentListSheets;
    final sheets = <SheetDef>[];
    var index = 1;

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
