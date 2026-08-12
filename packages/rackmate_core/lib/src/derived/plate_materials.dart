// packages/rackmate_core/lib/src/derived/plate_materials.dart
//
// THE PARTS ONE OUTLET'S PLATE IS MADE OF (DR-047 §11.46.4). Computed
// from the fittings; never formatted and never drawn.
//
// ═════════════════════════════════════════════════════════════════════
// THE SEAM: M3 DERIVES, M6 PRINTS
// ═════════════════════════════════════════════════════════════════════
// DR-027 §11.26.2 puts every rendered sheet in M6 and §11.26.4 names the
// derivation as the load-bearing half M3 owes. This file is that half for
// `T6.30`'s plate lines, exactly as `cable_footage.dart` is for the
// footage rollup. Nothing here knows a column width.
//
// ═════════════════════════════════════════════════════════════════════
// FOUR PART FAMILIES, AND THREE OF THEM WERE ALREADY RULED
// ═════════════════════════════════════════════════════════════════════
//   strap        one per gang that holds one, sized W x H  §11.7.1
//   cover plate  EXACTLY ONE, N-gang, N = gangs.length     §11.7.8 ch.1
//   blank        one per BlankInsert                       §11.7.4
//   pass-through one per brushed opening, when the plate
//                itself is not the brush                   §11.46.4  NEW
//
// The cover plate's STYLE is the only new question, and the answer is a
// derivation rather than a field. §11.46.4:
//
//   every opening a pass-through of ONE style -> one integral plate of
//     that style, no inserts
//   anything else                             -> a Decora plate, plus
//     one insert per brushed opening
//
// THAT IS A FACT ABOUT WHAT IS STOCKED, not about the model. Nobody
// manufactures every Decora-plus-brush combination, so a plate with a
// strap behind one opening and a brush at another is genuinely bought as
// a standard plate plus an insert. Mixed STYLES fail the same way, which
// is why the rule keys on "one style" and not on "all pass-through".
//
// AND IT IS A DERIVATION RATHER THAN A FIELD FOR §11.27.2'S REASON: a
// shop that stocks Decora plates and inserts rather than brush plates can
// be served later by an override, and that override wins with NOTHING TO
// WITHDRAW. A stored plate-form field would have been null on every
// outlet in every document ever written, so under G4 every plate in the
// product would have read "form unknown" the day it shipped.
//
// ═════════════════════════════════════════════════════════════════════
// AN UNCHOSEN GANG MAKES THE PLATE UNNAMEABLE, NOT ABSENT (G4)
// ═════════════════════════════════════════════════════════════════════
// A gang nobody has fitted could become a strap (Decora plate) or a
// brush (possibly an integral plate). So with one unchosen gang and no
// strap anywhere, the plate is [CoverPlateKind.unknown] and NO insert
// count is emitted, because the two answers travel together: the same
// opening is either an insert or part of the plate.
//
// The straps and blanks stay exact throughout. They are facts about
// fittings somebody HAS chosen, and withholding them because a different
// opening is undecided would be counting down instead of counting.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show PassThroughStyle;
import 'package:rackmate_core/src/model/gang.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// What one outlet's cover plate is.
///
/// **FIVE VALUES RATHER THAN A NULLABLE STYLE**, for the reason
/// `EquipmentMounting` gives for its own five: *"no plate at all"* and
/// *"nobody can say yet"* are different facts, and a `PassThroughStyle?`
/// can only spell one of them.
enum CoverPlateKind {
  /// No plate at all: the outlet has no gangs. DR-045 §11.44.4's
  /// plateless outlet, where an access point mounts straight to the box.
  none,

  /// A standard Decora cover plate: N openings, each showing a strap or
  /// a pass-through insert.
  decora,

  /// The plate itself is brushed at every opening. One part; no inserts.
  brush,

  /// The plate itself is bull-nose or grommeted at every opening.
  bullNose,

  /// Gangs nobody has fitted, and nothing else on the plate settles it.
  /// **Not a plate that is missing: a plate nobody can name yet.**
  unknown,
}

/// The parts one `Outlet`'s plate needs, derived (DR-047 §11.46.4).
@immutable
final class PlateMaterials {
  const PlateMaterials({
    required this.outletId,
    required this.coverPlate,
    required this.coverPlateGangs,
    required this.strapPortCounts,
    required this.passThroughInserts,
    required this.blankInserts,
    required this.gangsUnchosen,
  });

  final Uuid outletId;

  /// What the one cover plate is. See [CoverPlateKind].
  final CoverPlateKind coverPlate;

  /// Its gang count, always `gangs.length` (§11.7.8 change 1). Zero when
  /// [coverPlate] is [CoverPlateKind.none], and a real count even when
  /// the kind is [CoverPlateKind.unknown]: **how many openings is known
  /// even when what covers them is not.**
  final int coverPlateGangs;

  /// One entry per fitted strap, its cell count: `[2, 6]` is a 2-port and
  /// a 6-port. **In gang order**, so the list is a function of the plate
  /// and not of a map's iteration (§8.4).
  final List<int> strapPortCounts;

  /// One entry per opening needing a **separate** pass-through insert,
  /// in gang order.
  ///
  /// **EMPTY WHEN THE PLATE IS INTEGRAL**, because then the brush is the
  /// plate and buying an insert as well would be ordering the same hole
  /// twice. Also empty when [coverPlate] is [CoverPlateKind.unknown]:
  /// the two answers travel together, since one undecided opening is
  /// exactly what decides between an insert and an integral plate.
  final List<PassThroughStyle> passThroughInserts;

  /// Blank inserts fitted (§11.7.4). A decision and a purchase; an empty
  /// cell nobody has decided about is neither, and is not counted here.
  final int blankInserts;

  /// Gangs whose fitting nobody has chosen.
  ///
  /// **READ EVERY COUNT ABOVE BESIDE THIS ONE.** Non-zero means the part
  /// list is a lower bound, which is `totals.dart`'s rule 2 on a smaller
  /// number. It is also the only thing that produces
  /// [CoverPlateKind.unknown].
  final int gangsUnchosen;

  /// True when nothing here is waiting on a person.
  bool get isComplete => gangsUnchosen == 0;
}

/// Computes [PlateMaterials] for [outlet].
///
/// Reads the gangs and nothing else: unlike `computePlateFill` this asks
/// what the plate IS rather than whether it fits the drops, so no links
/// are needed and none are taken.
PlateMaterials computePlateMaterials(Outlet outlet) {
  final strapPortCounts = <int>[];
  final passThroughStyles = <PassThroughStyle>[];
  var blankInserts = 0;
  var gangsUnchosen = 0;
  var strapCount = 0;

  for (final gang in outlet.gangs) {
    switch (gang.fitting) {
      case null:
        gangsUnchosen++;
      case PassThrough(:final style):
        passThroughStyles.add(style);
      case final Strap strap:
        strapCount++;
        strapPortCounts.add(strap.cellCount);
        for (final occupant in strap.cells.values) {
          if (occupant is BlankInsert) blankInserts++;
        }
    }
  }

  final gangCount = outlet.gangs.length;
  final coverPlate = _kindOf(
    gangCount: gangCount,
    strapCount: strapCount,
    gangsUnchosen: gangsUnchosen,
    styles: passThroughStyles,
  );

  return PlateMaterials(
    outletId: outlet.id,
    coverPlate: coverPlate,
    coverPlateGangs: gangCount,
    strapPortCounts: List.unmodifiable(strapPortCounts),
    // INSERTS ONLY WHEN THE PLATE IS DECORA. See [passThroughInserts].
    passThroughInserts: List.unmodifiable(
      coverPlate == CoverPlateKind.decora
          ? passThroughStyles
          : const <PassThroughStyle>[],
    ),
    blankInserts: blankInserts,
    gangsUnchosen: gangsUnchosen,
  );
}

/// §11.46.4's table, in order. The order is load-bearing: a strap
/// anywhere settles the plate as Decora whatever else is undecided,
/// because an opening a strap shows through is a Decora opening and
/// nothing a later decision does can change that.
CoverPlateKind _kindOf({
  required int gangCount,
  required int strapCount,
  required int gangsUnchosen,
  required List<PassThroughStyle> styles,
}) {
  if (gangCount == 0) return CoverPlateKind.none;
  if (strapCount > 0) return CoverPlateKind.decora;
  // No strap anywhere, so an unfitted gang could still turn this into an
  // integral plate. Nobody can name it yet, and guessing "Decora" here
  // would put a part on a sheet on the strength of an absence of work.
  if (gangsUnchosen > 0) return CoverPlateKind.unknown;
  // Every opening is a pass-through. One style is one part; two styles
  // are not a part anybody makes, so it falls back to a plate plus
  // inserts exactly as a mixed strap-and-brush plate does.
  final first = styles.first;
  if (styles.any((s) => s != first)) return CoverPlateKind.decora;
  return switch (first) {
    PassThroughStyle.brush => CoverPlateKind.brush,
    PassThroughStyle.bullNose => CoverPlateKind.bullNose,
  };
}
