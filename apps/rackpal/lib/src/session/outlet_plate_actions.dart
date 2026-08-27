// What the Outlets tab's gestures MEAN, in commands. Board M3-H/2
// (#167), DR-007 §11.7, DR-041.
//
// ═════════════════════════════════════════════════════════════════════
// A SIBLING OF `pathway_actions.dart`, AND THE SAME REASON
// ═════════════════════════════════════════════════════════════════════
// Every id crossing this boundary is an `Outlet`'s, and every id crossing
// `structure_edit_actions.dart` is a `Link`'s. Both are `Uuid`. Folding
// them together would put two entity types behind one identifier and
// leave a callee to work out which it had been handed, which is the
// mistake that only surfaces the day somebody wires a column to the wrong
// enum.
//
// ═════════════════════════════════════════════════════════════════════
// THE ARRANGE IS ONE TRANSACTION, AND THAT IS NOT A DETAIL
// ═════════════════════════════════════════════════════════════════════
// A plate arrange removes every gang, adds the planned ones and places
// every keystone: for a six-drop outlet that is a dozen commands.
// `LabelKey.arrangePlate` puts ONE entry on the undo stack for all of
// them, on `importCsv`'s reasoning at a smaller scale, because undoing an
// arrange a cell at a time is not undoing an arrange.
//
// **REMOVAL RUNS BACK TO FRONT.** `RemoveGangCommand` addresses a gang by
// POSITION and removing gang 0 renumbers every gang after it, so a
// forward loop would delete the wrong openings from the second iteration
// on. The same hazard `ConductorRef` documents for its own index, and the
// reason `model/gang.dart` says a `GangRef` describes the document it was
// resolved from and no other.
//
// ═════════════════════════════════════════════════════════════════════
// NOTHING HERE DECIDES A CELL COUNT OR A COLOUR
// ═════════════════════════════════════════════════════════════════════
// `planPlateArrangement` sizes the plate and `resolveJacketColor` answers
// the keystone. This file refuses what is not addressable and hands the
// rest to core. A refusal names the thing that was missing rather than
// returning a bare false, which is the standing rule that a refused
// action always reports and never silently does nothing.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// Builds the whole [OutletsActions] group against a live [controller].
///
/// ONE BUILDER FOR FIVE CALLBACKS, unlike `pathway_actions.dart`'s three
/// separate ones. They share every guard: the same outlet lookup, the
/// same gang-index bounds check, the same refusal sentences. Five
/// builders would be five copies of `_outletOr`.
OutletsActions buildOutletsActions({required DocumentController controller}) {
  Outlet? outletOf(Uuid id) => controller.doc.outlets[id];

  String? gangGuard(Uuid outletId, int gangIndex) {
    final outlet = outletOf(outletId);
    if (outlet == null) return 'That outlet is not in this project.';
    if (gangIndex < 0 || gangIndex >= outlet.gangs.length) {
      return 'That outlet has no gang ${gangIndex + 1}.';
    }
    return null;
  }

  return OutletsActions(
    onAddGang: (outletId) {
      if (outletOf(outletId) == null) {
        return 'That outlet is not in this project.';
      }
      controller.transact(LabelKey.addGang, (tx) {
        // NO SIZE. A gang whose strap nobody has chosen is the honest
        // result of pressing a button that says "add gang" and nothing
        // about a part (G4); see `AddGangCommand.width`.
        tx.add(AddGangCommand(outletId: outletId));
      });
      return null;
    },

    onRemoveGang: (outletId, gangIndex) {
      final refusal = gangGuard(outletId, gangIndex);
      if (refusal != null) return refusal;
      controller.transact(LabelKey.removeGang, (tx) {
        tx.add(RemoveGangCommand(outletId: outletId, index: gangIndex));
      });
      return null;
    },

    onSetStrap: (outletId, gangIndex, width, height) {
      final refusal = gangGuard(outletId, gangIndex);
      if (refusal != null) return refusal;
      // The bounds are the ruling's and the check is derived from them,
      // never a list of the five port counts (DR-007 §11.7.1).
      if (width != null && height != null && !isValidStrapSize(width, height)) {
        return 'A $width x $height strap is not a part anybody makes.';
      }
      controller.transact(LabelKey.setStrapSize, (tx) {
        tx.add(
          SetStrapSizeCommand(
            outletId: outletId,
            index: gangIndex,
            width: width,
            height: height,
          ),
        );
      });
      return null;
    },

    onSetPassThrough: (outletId, gangIndex, style) {
      final refusal = gangGuard(outletId, gangIndex);
      if (refusal != null) return refusal;
      // NO SIZE CHECK AND NO REFUSAL FOR A FULL STRAP. Discarding cells
      // is `gang_commands.dart`'s standing choice for somebody who has
      // decided the plate was wrong, and the count is
      // `occupantsLostByPassThrough`, which the picker asks BEFORE it
      // gets here.
      controller.transact(LabelKey.setGangPassThrough, (tx) {
        tx.add(
          SetGangPassThroughCommand(
            outletId: outletId,
            index: gangIndex,
            style: style,
          ),
        );
      });
      return null;
    },

    onSetCell: (outletId, gangIndex, cellIndex, occupant) {
      final refusal = gangGuard(outletId, gangIndex);
      if (refusal != null) return refusal;
      // THREE ARMS AND THREE SENTENCES (DR-047 §11.46.2). "Nobody has
      // chosen a part" and "somebody fitted a hole here" are different
      // answers to "why has this gang no cells", and one sentence for
      // both is the collapse the ruling removes: the first invites a
      // person to pick a strap, the second tells them the plate is
      // already right.
      final fitting = outletOf(outletId)!.gangs[gangIndex].fitting;
      if (fitting is PassThrough) {
        return 'Gang ${gangIndex + 1} is a pass-through, so it has no cells.';
      }
      if (fitting is! Strap) {
        return 'Gang ${gangIndex + 1} has no strap yet, so it has no cells.';
      }
      final strap = fitting;
      if (!strap.holdsIndex(cellIndex)) {
        return 'A ${strap.cellCount}-port strap has no cell ${cellIndex + 1}.';
      }
      controller.transact(LabelKey.setCellOccupant, (tx) {
        tx.add(
          SetCellOccupantCommand(
            outletId: outletId,
            gangIndex: gangIndex,
            cellIndex: cellIndex,
            occupant: occupant,
          ),
        );
      });
      return null;
    },

    onArrange: (outletId, plan) {
      final outlet = outletOf(outletId);
      if (outlet == null) return 'That outlet is not in this project.';
      if (plan.isEmpty) return 'There is nothing to arrange on this plate.';

      controller.transact(LabelKey.arrangePlate, (tx) {
        // BACK TO FRONT. See the file header: gangs are addressed by
        // position and a forward loop removes the wrong ones.
        for (var i = outlet.gangs.length - 1; i >= 0; i--) {
          tx.add(RemoveGangCommand(outletId: outletId, index: i));
        }
        for (final strap in plan.straps) {
          tx.add(
            AddGangCommand(
              outletId: outletId,
              width: strap.width,
              height: strap.height,
            ),
          );
        }
        for (final cell in plan.cells) {
          tx.add(
            SetCellOccupantCommand(
              outletId: outletId,
              gangIndex: cell.gangIndex,
              cellIndex: cell.cellIndex,
              occupant: cell.occupant,
            ),
          );
        }
        // THE BRUSHES COME BACK, AFTER the straps (DR-047 §11.46.6).
        // Arrange plans from what the drops need in cells, and a
        // pass-through needs none, so a plan that simply rebuilt the
        // plate would delete a part somebody chose. They land last
        // because the cell indices above are relative to the strap gangs
        // this loop must not renumber.
        //
        // THE INDEX COMES FROM THE PLAN, NOT FROM `outlet.gangs.length`.
        // Every gang was removed and `plan.straps.length` were added, so
        // the nth brush lands at `straps.length + n` by construction.
        // Reading the live list mid-transaction would make this depend on
        // whether `transact` applies as it collects, which is not a thing
        // this call site should know or care about.
        for (var i = 0; i < plan.keptPassThroughs.length; i++) {
          tx
            ..add(AddGangCommand(outletId: outletId))
            ..add(
              SetGangPassThroughCommand(
                outletId: outletId,
                index: plan.straps.length + i,
                style: plan.keptPassThroughs[i],
              ),
            );
        }
      });
      return null;
    },
  );
}
