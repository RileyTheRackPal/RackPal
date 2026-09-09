// packages/rackpal_core/lib/src/derived/cable_footage.dart — pure Dart.
//
// AC-024 change 2: "cable footage rollup in the materials list, by media
// type, with a configurable waste factor", whose worked example is
// `Cat6: 2,140 ft estimated + 10% = 2,354 ft`. docs/08 §2.2 puts it on
// `T6.30 EQUIPMENT LIST AND MATERIALS`; DR-027 §11.26.2 puts the
// DERIVATION in M3 and the rendered sheet in M6. This file is the M3
// half. It computes and never draws.
//
// ═════════════════════════════════════════════════════════════════════
// A DIFFERENT NUMBER FOR A DIFFERENT READER THAN THE PULL SHEET'S
// ═════════════════════════════════════════════════════════════════════
// `ScheduleGroup.footage` already sums a ROOM, for the person walking
// the house. This sums a MEDIA TYPE, for the person standing at a
// counter deciding how much Cat6 to buy. #585's own closing note draws
// the line: "how much cable to order, not how much went in the wall".
//
// It is built from `buildSchedule`'s rows and not from `doc.links`
// directly, and that is the point rather than convenience: the takeoff
// and the sheet an installer works from must not be able to disagree
// about a length, a media type, or which cables are real pulls. One
// derivation, read twice (docs/08 §3.1).
//
// ═════════════════════════════════════════════════════════════════════
// WHAT COUNTS, AND WHY EACH EXCLUSION IS COUNTED RATHER THAN DROPPED
// ═════════════════════════════════════════════════════════════════════
// Only `LinkClass.fieldCable` contributes a quantity.
//
//  * **Jumpers and power cords** are manufactured assemblies bought by
//    the piece, not cable bought by the foot. docs/08 §2.2 lists their
//    rollup SEPARATELY ("by media + length + colour"), so folding them
//    in here would both double-count them and put a patch cord's length
//    into a spool order.
//  * **`internal`** is a link inside one device. Nobody pulls it.
//  * **An UNDETERMINED class is excluded too, and this is the one that
//    is easy to get wrong.** `kUndeterminedClassGroupTitle`'s own
//    comment says its footage "must not join a room's subtotal ... it is
//    the number an installer orders cable against". That argument is
//    strictly stronger here, where ordering IS the purpose: a run nobody
//    has established is a pull cannot be allowed to add a hundred feet
//    to a purchase.
//
// Every one of those is counted by reason on [CableFootage], because a
// takeoff that quietly holds fewer cables than the document is the
// failure mode, and one that says "18 rows not counted: 4 jumpers, 14
// undetermined" is not.
//
// ═════════════════════════════════════════════════════════════════════
// ESTIMATES COUNT; BOUNDS DO NOT
// ═════════════════════════════════════════════════════════════════════
// READ "WILL NOT" UNTIL `PLAN-G/1`, WHICH IS THE DAY THE SWITCH BELOW WAS
// BUILT FOR. `ScheduleLengthSource.planLowerBound` now exists, this file
// stopped compiling exactly as its author intended, and the arm is
// answered `false`.
//
// AC-024's example says `2,140 ft ESTIMATED + 10%`, so an estimate is a
// legitimate quantity here — a takeoff made before anybody has pulled
// anything is the ordinary case and the whole reason the feature exists.
// [CableFootageLine.estimatedCount] states how much of the figure rests
// on estimates, so a reader can see what the number is made of.
//
// DR-020 §11.19.2(2) rules that a plan-derived `planLowerBound` "never
// enters the footage rollup as a quantity", because a bound cannot be
// summed into "how much Cat6 to order" without making a claim it is not
// entitled to make. `_isQuantity` is therefore an EXHAUSTIVE switch with
// no default arm, so the day it was added this file stopped compiling and
// somebody decided, rather than a bound silently joining a purchase.
//
// THE MECHANISM WORKED AND ITS SCOPE WAS SMALLER THAN ITS REPUTATION
// (DR-147 §11.146.1). It guards this rollup and it does not guard
// `schedule.dart`'s `_footageOf`, which builds the sheet footer's
// `Σ 11 runs · 601 ft · 3 estimated` by summing `row.length` and never
// asking where the number came from. Two rollups, one trap; the other is
// closed by hand at `PLAN-G/3`.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IS DELIBERATELY NOT HERE: THE BOX COUNT
// ═════════════════════════════════════════════════════════════════════
// AC-024's example ends `→ 3 boxes (1000 ft)`, and that half is NOT
// built. There is no packaging field on `MediaTypeDef` and no sourced
// package size for any shipped media type, so a box count would mean
// hard-coding 1000 ft as a universal — which is false for RG6 (500 ft),
// for 16/4 (500 ft), for fibre and for anything on a reel.
//
// Adding a nullable `packageLength` and dividing by it where set would
// be worse than leaving it out, and canon §11.19.7 says why in a case
// this project has already lived through: `maxRunLengthActive` is null
// on all 38 types, and a rule written against it "would compile, pass
// its own fixture pair if the fixture set the field, and never fire on a
// real document". A box count nobody can populate is that shape exactly.
// Owed, with the missing field named, rather than faked (G4).

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/derived/totals.dart';
import 'package:rackpal_core/src/model/link.dart' show LinkClass;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/permille.dart';

/// One media type's line in the materials takeoff.
@immutable
final class CableFootageLine {
  const CableFootageLine({
    required this.mediaId,
    required this.media,
    required this.footage,
    required this.withWaste,
    required this.runCount,
    required this.estimatedCount,
    required this.boundCount,
  });

  final MediaTypeId mediaId;

  /// The registry entry, or null when the document names a media type it
  /// does not carry. The line still appears: a hundred feet of something
  /// this document cannot name is a fact a buyer needs, and dropping the
  /// row would make the takeoff quietly smaller than the schedule.
  final MediaTypeDef? media;

  /// Σ of the known lengths, with the count of runs that could supply
  /// none — built through [Rollup.fromScan], so a media type nothing
  /// known contributed to is `null` and never `0`.
  ///
  /// THE DISTINCTION IS THE TASK. `0` means "measured, and it is zero",
  /// which for a purchase means "buy none". A room of drops whose
  /// lengths simply have not been entered must not print as if it needed
  /// no cable (G4, CR-114).
  final Rollup<Len> footage;

  /// [footage] with `ProjectSettings.cableWasteFactor` applied, or null
  /// when the subtotal itself is unknown.
  ///
  /// NEVER WRITTEN BACK TO A STORED LENGTH. The waste factor is a
  /// project setting applied at the rollup; baking it into a `Link`
  /// would make an installer's measured 62 ft read 68 ft on the sheet
  /// they measured it against, and would compound the next time somebody
  /// changed the setting.
  final Len? withWaste;

  /// How many runs of this media type contributed at all, known length
  /// or not. `footage.knownCount + footage.unknownCount`, carried so a
  /// caller printing "12 runs" does not add the two itself.
  final int runCount;

  /// How many of [footage]'s known contributors were ESTIMATES rather
  /// than cut lengths. A takeoff built from estimates is still a takeoff,
  /// but a reader is entitled to know before ordering against it, and
  /// `ScheduleGroup.estimatedCount` carries the same number for a room.
  final int estimatedCount;

  /// How many of this line's runs printed a plan-derived FLOOR, and are
  /// therefore inside [footage]'s `unknownCount` rather than its sum
  /// (DR-020 §11.19.2(2), DR-147 §11.146.3).
  ///
  /// **THE SUBSET OF THE IGNORANCE THAT HAS A FLOOR UNDER IT.** A bound
  /// cannot be summed into "how much Cat6 to order" without becoming a
  /// claim it is not entitled to make, so it is excluded exactly as a
  /// missing length is; naming how many of the unknowns are bounds is
  /// what keeps the exclusion visible rather than quietly shrinking the
  /// order. [estimatedCount] is the precedent and the sibling: one says
  /// how much of the number rests on guesses, this says how much of the
  /// gap is measurable at all.
  final int boundCount;
}

/// The whole materials takeoff: one line per media type actually used,
/// plus what was left out and why.
@immutable
final class CableFootage {
  const CableFootage({
    required this.lines,
    required this.wasteFactor,
    required this.excludedJumpers,
    required this.excludedPowerCords,
    required this.excludedInternal,
    required this.excludedUndeterminedClass,
  });

  /// Ordered by media display name, then by id — a TOTAL order with no
  /// `Map` iteration in it (§8.4), so two builds of an unmodified
  /// document produce the identical table. The id tiebreak is what makes
  /// it total: two user-created media types may share a display name,
  /// and an unresolved one has no display name at all.
  final List<CableFootageLine> lines;

  /// The factor applied to every line, carried so a sheet can print
  /// `+ 10%` beside the number rather than re-reading settings.
  final Permille wasteFactor;

  final int excludedJumpers;
  final int excludedPowerCords;
  final int excludedInternal;

  /// Rows whose class nobody has established. See the file header: this
  /// is the exclusion that most looks like an omission and is most
  /// deliberate.
  final int excludedUndeterminedClass;

  int get excludedTotal =>
      excludedJumpers +
      excludedPowerCords +
      excludedInternal +
      excludedUndeterminedClass;

  /// Runs counted across every line, known length or not.
  int get runCount {
    var n = 0;
    for (final line in lines) {
      n += line.runCount;
    }
    return n;
  }

  /// Runs counted whose length nobody knows — the number that says how
  /// complete this takeoff is.
  int get unknownLengthCount {
    var n = 0;
    for (final line in lines) {
      n += line.footage.unknownCount;
    }
    return n;
  }

  /// THERE IS DELIBERATELY NO GRAND TOTAL FOOTAGE, and the absence is a
  /// decision rather than an omission: feet of Cat6 plus feet of RG6 is
  /// not a quantity anybody buys, and printing one invites a reader to
  /// treat it as an order. The per-media lines ARE the deliverable.
  /// [runCount] and [unknownLengthCount] are the document-wide numbers
  /// that mean something.
  bool get isEmpty => lines.isEmpty;
}

/// AC-024's materials takeoff for [doc].
CableFootage buildCableFootage(RackDocument doc) =>
    cableFootageOf(buildSchedule(doc), doc: doc);

/// The same derivation over a schedule a caller has already built.
///
/// SEPARATE SO NOTHING PAYS TWICE. A screen showing the schedule and the
/// takeoff together builds the rows once; `buildStructureTable` takes the
/// convenience arm for the same reason.
CableFootage cableFootageOf(Schedule schedule, {required RackDocument doc}) {
  final waste = doc.settings.cableWasteFactor;

  var jumpers = 0;
  var powerCords = 0;
  var internal = 0;
  var undetermined = 0;

  final sums = <MediaTypeId, Len>{};
  final known = <MediaTypeId, int>{};
  final unknown = <MediaTypeId, int>{};
  final estimated = <MediaTypeId, int>{};
  final bound = <MediaTypeId, int>{};

  for (final row in schedule.rows) {
    // UNDETERMINED IS NOT A CLASS and cannot be filtered as one; it is
    // excluded on its own account and counted separately, exactly as
    // `buildScheduleView` treats it.
    if (row.isClassUndetermined) {
      undetermined++;
      continue;
    }
    switch (row.linkClass!) {
      case LinkClass.jumper:
        jumpers++;
        continue;
      case LinkClass.powerCord:
        powerCords++;
        continue;
      case LinkClass.internal:
        internal++;
        continue;
      case LinkClass.fieldCable:
        break;
    }

    final id = row.mediaId;
    final length = _isQuantity(row.lengthSource) ? row.length : null;
    if (row.lengthIsBound) bound[id] = (bound[id] ?? 0) + 1;
    if (length == null) {
      unknown[id] = (unknown[id] ?? 0) + 1;
    } else {
      sums[id] = (sums[id] ?? Len.zero) + length;
      known[id] = (known[id] ?? 0) + 1;
      if (row.lengthIsEstimated) estimated[id] = (estimated[id] ?? 0) + 1;
    }
  }

  final lines = <CableFootageLine>[];
  for (final id in {...known.keys, ...unknown.keys}) {
    final def = doc.registries.mediaTypes[id];
    final footage = Rollup<Len>.fromScan(
      sum: sums[id] ?? Len.zero,
      knownCount: known[id] ?? 0,
      unknownCount: unknown[id] ?? 0,
    );
    lines.add(
      CableFootageLine(
        mediaId: id,
        media: def,
        footage: footage,
        withWaste: _withWaste(footage.value, waste),
        runCount: (known[id] ?? 0) + (unknown[id] ?? 0),
        estimatedCount: estimated[id] ?? 0,
        boundCount: bound[id] ?? 0,
      ),
    );
  }
  lines.sort((a, b) {
    final byName = (a.media?.displayName ?? '').compareTo(
      b.media?.displayName ?? '',
    );
    return byName != 0 ? byName : a.mediaId.v.compareTo(b.mediaId.v);
  });

  return CableFootage(
    lines: lines,
    wasteFactor: waste,
    excludedJumpers: jumpers,
    excludedPowerCords: powerCords,
    excludedInternal: internal,
    excludedUndeterminedClass: undetermined,
  );
}

/// Whether a length from this source may be SUMMED INTO A PURCHASE.
///
/// EXHAUSTIVE ON PURPOSE, with no default arm. DR-020 §11.19.2(2) rules
/// that a plan-derived bound never enters this rollup as a quantity, and
/// that source is coming (DR-029 puts the Plan view in v1, before M6).
/// A `default: return true` would let it in silently on the day it is
/// added; this way the analyzer stops the build and a person decides.
bool _isQuantity(ScheduleLengthSource source) => switch (source) {
  ScheduleLengthSource.cut => true,
  // AC-024's own example is an ESTIMATED total plus waste, so an
  // estimate is a quantity here. `estimatedCount` is what keeps the
  // figure's standing visible.
  ScheduleLengthSource.outletNominal => true,
  ScheduleLengthSource.roomEstimate => true,
  // THE DAY ARRIVED, AND THE ANSWER IS NO (`PLAN-G/1`, DR-020
  // §11.19.2(2)). Adding the value above stopped this file compiling,
  // which is what the arm below was arranged to do; a `default: true`
  // would have let a floor into somebody's purchase order silently.
  // Excluded is not dropped: `PLAN-G/3` adds the count that says how
  // many of this line's unknowns have a floor under them.
  ScheduleLengthSource.planLowerBound => false,
  ScheduleLengthSource.none => false,
};

/// [value] plus [waste], in integer parts per thousand (CR-001).
///
/// NO FLOATING POINT, even though `Permille.toFraction()` exists: that
/// method's own comment says it is display-only and "never used for
/// stored values". A takeoff is arithmetic somebody buys against, so it
/// stays in int64 nanometres. The truncation is sub-nanometre and cannot
/// reach a printed foot.
Len? _withWaste(Len? value, Permille waste) {
  if (value == null) return null;
  return Len(
    (value.nm * (Permille.whole.v + waste.v)) ~/ Permille.whole.v,
  );
}
