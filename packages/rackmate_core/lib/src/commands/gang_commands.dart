// packages/rackmate_core/lib/src/commands/gang_commands.dart — pure
// Dart. Board M3-H/1 (#166), DR-007 §11.7.
//
// ═════════════════════════════════════════════════════════════════════
// WRITTEN IN THE SAME CHANGE AS THE FIELD, DELIBERATELY
// ═════════════════════════════════════════════════════════════════════
// `.okf/practices/a-modelled-field-is-not-a-reachable-one.md` records
// four fields that were modelled, persisted, byte-round-tripped and read
// by several consumers with nothing in the product able to set them:
// `Pathway`, `registries.mediaTypes`, `Link.pathwayId` and a derived
// location code. Every one was found while implementing something else,
// and each added a command nobody had scheduled.
//
// `Outlet.gangs` would have been the fifth. It has a codec, a golden
// fixture, a derived rollup and a renderer coming, and until this file
// existed its only writers were test fixtures. The practice's own check
// is "grep for what WRITES it", so this is that grep answered in advance
// rather than in the next milestone's post-mortem.
//
// ═════════════════════════════════════════════════════════════════════
// ONE LINK END LANDS IN EXACTLY ONE CELL
// ═════════════════════════════════════════════════════════════════════
// A drop is one physical cable reaching one physical jack. Nothing in
// the model structurally prevents the same `LinkEndOccupant` appearing
// in two cells of one plate, and a plate drawing that showed LR-DATA-1
// twice would be wrong in the specific way a printed sheet is wrong:
// silently, and to the person holding it in a crawlspace.
//
// So [SetCellOccupantCommand] is place, MOVE and clear in one command.
// Assigning an occupant that already sits somewhere else on the same
// outlet vacates the old cell in the same undo step. A separate
// `ClearCellCommand` is deliberately absent, because it would offer a
// caller the arm that skips the move.
//
// SCOPE IS THE OUTLET, NOT THE DOCUMENT. Two plates in two rooms may
// legitimately reference the same link only in a broken document, and
// that is a DRC finding (M5) rather than a refusal here: a command that
// silently reached into another room's plate would be editing an entity
// the user is not looking at.
//
// ═════════════════════════════════════════════════════════════════════
// SHRINKING A STRAP LOSES CELLS, AND IT SAYS SO
// ═════════════════════════════════════════════════════════════════════
// Going from a 2 x 3 to a 1 x 2 deletes four cells, and whatever was in
// them. [SetStrapSizeCommand] carries the whole previous strap for
// revert, so undo is exact; [occupantsLostByResize] is the count a
// confirmation prompt asks for BEFORE the command runs, which is
// DR-013's "a cascade with a confirmation that counts the cables"
// applied to a smaller graph.
//
// It does not refuse. A person shrinking a strap has usually decided the
// plate was wrong, and refusing would make them empty six cells by hand
// to be allowed to say so.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/gang.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Copies [strap], cells and all, so a command can hold a before-value
/// that later mutation cannot reach through.
Strap? _copyStrap(Strap? strap) => strap == null
    ? null
    : Strap(
        width: strap.width,
        height: strap.height,
        cells: Map<int, CellOccupant>.of(strap.cells),
      );

Gang _copyGang(Gang gang) => Gang(strap: _copyStrap(gang.strap));

/// How many occupants a resize of [gang] to `width x height` would
/// destroy.
///
/// **ASK THIS BEFORE COMMANDING, not after.** It is the number a
/// confirmation prompt needs, and it exists as a free function rather
/// than as a field on the command so a caller can put it in a dialog
/// without building the command it might not run.
int occupantsLostByResize(Gang gang, int width, int height) {
  final strap = gang.strap;
  if (strap == null) return 0;
  final cells = width * height;
  var lost = 0;
  for (final index in strap.cells.keys) {
    if (index >= cells) lost++;
  }
  return lost;
}

/// Appends one gang to [outletId]'s plate.
///
/// APPENDS, never inserts. Gang order is left-to-right on the physical
/// plate (see `model/gang.dart`), and a new gang is a wider box, which
/// grows to the right. Inserting in the middle would renumber every gang
/// after it and silently restate which opening every keystone is in.
final class AddGangCommand extends Command {
  AddGangCommand({required this.outletId, this.width, this.height});

  final Uuid outletId;

  /// The strap to fit, or null for a gang whose part nobody has chosen
  /// yet.
  ///
  /// **NULL IS THE HONEST DEFAULT AND IS WHAT `+ Add gang` PRODUCES.**
  /// Defaulting to a 1 x 1 would put a purchase on a materials sheet
  /// that nobody made, which is `AddPathwayCommand`'s reasoning for
  /// leaving `nominalLength` null, and G4's for every unknown in this
  /// package.
  final int? width;

  /// See [width].
  final int? height;

  @override
  LabelKey get label => LabelKey.addGang;

  /// `structure` alone: a gang is part of how the building is put
  /// together. It carries no name, no designator and nothing the meta
  /// epoch's consumers read.
  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [outletId];

  @override
  void apply(RackDocument doc) {
    final outlet = doc.outlets[outletId];
    if (outlet == null) return;
    final w = width;
    final h = height;
    outlet.gangs.add(
      Gang(
        strap: w == null || h == null ? null : Strap(width: w, height: h),
      ),
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.outlets[outletId]?.gangs.removeLast();
  }
}

/// Removes the gang at [index], and everything in it.
///
/// The whole gang is stored for revert rather than recomputed, because
/// its cells cannot be reconstructed from anything else in the document:
/// `Link.structureOrigin` says a drop lands at this OUTLET and has never
/// said which cell.
final class RemoveGangCommand extends Command {
  RemoveGangCommand({required this.outletId, required this.index});

  final Uuid outletId;
  final int index;

  Gang? _removed;

  @override
  LabelKey get label => LabelKey.removeGang;

  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [outletId];

  @override
  void apply(RackDocument doc) {
    final outlet = doc.outlets[outletId];
    if (outlet == null || index < 0 || index >= outlet.gangs.length) return;
    _removed = _copyGang(outlet.gangs[index]);
    outlet.gangs.removeAt(index);
  }

  @override
  void revert(RackDocument doc) {
    final removed = _removed;
    final outlet = doc.outlets[outletId];
    if (removed == null || outlet == null) return;
    outlet.gangs.insert(
      index.clamp(0, outlet.gangs.length),
      _copyGang(removed),
    );
  }
}

/// Fits a strap of `width x height` to the gang at [index], or removes
/// the strap entirely when both are null.
///
/// **Occupants in cells the new size does not have are DROPPED**, and
/// [occupantsLostByResize] is how a caller finds out how many before
/// asking. See this file's header for why it drops rather than refuses.
final class SetStrapSizeCommand extends Command {
  SetStrapSizeCommand({
    required this.outletId,
    required this.index,
    required this.width,
    required this.height,
  });

  final Uuid outletId;
  final int index;

  /// Null with a null [height] removes the strap: "I have not decided
  /// what part goes here after all", which is a state a person can get
  /// back to.
  final int? width;

  /// See [width].
  final int? height;

  Strap? _before;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.setStrapSize;

  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [outletId];

  @override
  void apply(RackDocument doc) {
    final outlet = doc.outlets[outletId];
    if (outlet == null || index < 0 || index >= outlet.gangs.length) return;
    final gang = outlet.gangs[index];
    _before = _copyStrap(gang.strap);
    _applied = true;

    final w = width;
    final h = height;
    if (w == null || h == null) {
      gang.strap = null;
      return;
    }
    final next = Strap(width: w, height: h);
    // KEPT BY INDEX, not by (column, row). A cell's index is its
    // identity here, so widening a 1 x 3 into a 2 x 3 leaves every
    // keystone where its NUMBER was rather than where its position was.
    // Stated because the alternative is defensible and this is the one
    // chosen: index is what the file stores and what a person just
    // clicked, and re-flowing by coordinate would move jacks a person
    // did not touch.
    for (final entry
        in (_before?.cells ?? const <int, CellOccupant>{}).entries) {
      if (next.holdsIndex(entry.key)) next.cells[entry.key] = entry.value;
    }
    gang.strap = next;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) return;
    final outlet = doc.outlets[outletId];
    if (outlet == null || index < 0 || index >= outlet.gangs.length) return;
    outlet.gangs[index].strap = _copyStrap(_before);
  }
}

/// Puts [occupant] in one cell, or clears it when [occupant] is null.
///
/// **PLACE, MOVE AND CLEAR ARE ONE COMMAND.** If [occupant] already sits
/// in another cell of this outlet, that cell is vacated in the same undo
/// step: one link end lands in exactly one cell. See the file header.
final class SetCellOccupantCommand extends Command {
  SetCellOccupantCommand({
    required this.outletId,
    required this.gangIndex,
    required this.cellIndex,
    required this.occupant,
  });

  final Uuid outletId;
  final int gangIndex;
  final int cellIndex;

  /// Null CLEARS the cell back to undecided, which is not the same as
  /// fitting a [BlankInsert]: one says nobody has decided, the other
  /// says somebody decided nothing goes there and a blank gets bought
  /// (DR-007 §11.7.4). Both are reachable from here and neither is a
  /// synonym for the other.
  final CellOccupant? occupant;

  /// What was in the target cell, so revert is exact.
  CellOccupant? _before;
  bool _hadBefore = false;

  /// The cells vacated because they held the same occupant, and what
  /// they held. Empty in the ordinary case.
  final Map<(int, int), CellOccupant> _vacated = {};

  bool _applied = false;

  @override
  LabelKey get label => LabelKey.setCellOccupant;

  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [outletId];

  @override
  void apply(RackDocument doc) {
    final outlet = doc.outlets[outletId];
    if (outlet == null || gangIndex < 0 || gangIndex >= outlet.gangs.length) {
      return;
    }
    final strap = outlet.gangs[gangIndex].strap;
    if (strap == null || !strap.holdsIndex(cellIndex)) return;

    _hadBefore = strap.cells.containsKey(cellIndex);
    _before = strap.cells[cellIndex];
    _vacated.clear();

    final next = occupant;
    if (next != null && next is! BlankInsert) {
      // A BLANK IS EXEMPT, and it has to be: a six-port strap with two
      // blanks in it is two separate purchased parts, not one part
      // appearing twice. Uniqueness is a fact about a link end, which is
      // what a blank does not have.
      _vacateDuplicatesOf(outlet, next);
    }

    if (next == null) {
      strap.cells.remove(cellIndex);
    } else {
      strap.cells[cellIndex] = next;
    }
    _applied = true;
  }

  void _vacateDuplicatesOf(Outlet outlet, CellOccupant occupant) {
    for (var g = 0; g < outlet.gangs.length; g++) {
      final other = outlet.gangs[g].strap;
      if (other == null) continue;
      for (final index in other.cells.keys.toList()) {
        if (g == gangIndex && index == cellIndex) continue;
        if (other.cells[index] == occupant) {
          _vacated[(g, index)] = other.cells.remove(index)!;
        }
      }
    }
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) return;
    final outlet = doc.outlets[outletId];
    if (outlet == null || gangIndex < 0 || gangIndex >= outlet.gangs.length) {
      return;
    }
    final strap = outlet.gangs[gangIndex].strap;
    if (strap == null) return;

    if (_hadBefore) {
      strap.cells[cellIndex] = _before!;
    } else {
      strap.cells.remove(cellIndex);
    }
    for (final entry in _vacated.entries) {
      final (gang, index) = entry.key;
      outlet.gangs[gang].strap?.cells[index] = entry.value;
    }
  }
}
