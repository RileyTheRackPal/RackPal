// What a typed cell in the Structure MATRIX means. Board M3-C/3 (#149),
// docs/07 §4.2.
//
// ═════════════════════════════════════════════════════════════════════
// A SIBLING OF `structure_edit_actions.dart`, NOT A BRANCH OF IT
// ═════════════════════════════════════════════════════════════════════
// The two tabs edit different things. A TABLE cell is a field on one
// drop and its refusals are about values: a label that collides, a
// length that is not whole feet. A MATRIX cell is a COUNT of drops, so
// committing one can create four cables or delete four, and its refusal
// is about work already done — a run somebody has patched into a panel.
//
// Folding them into one callback would put "does this write a value or
// delete a cable" behind one signature, which is the distinction a
// person most needs the Edit menu to keep.
//
// ═════════════════════════════════════════════════════════════════════
// THE PLAN IS CORE'S AND THE TRANSACTION IS THIS FILE'S
// ═════════════════════════════════════════════════════════════════════
// `planMatrixCell` decides everything: how many to add, which rows to
// take, whether to refuse and in what words. This re-plans against the
// controller's own clock and actor for the reason `buildDropEntryActions`
// gives — a preview's timestamp and the literal string `preview` would
// otherwise reach `EntityMeta` on every cable — and then applies the
// whole list inside one transaction, because the unit a person undoes is
// the cell.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// The signature `StructureEditorActions.onSetCount` wants.
typedef StructureMatrixFn = String? Function(StructureMatrixEdit edit);

/// Wires the Structure matrix's cells to a live [DocumentController].
///
/// [structureBodyId] is the body the editor was opened on, so a project
/// with more than one does not have to guess (#158).
StructureMatrixFn buildStructureMatrixAction({
  required DocumentController controller,
  Uuid? structureBodyId,
}) => (edit) {
  final plan = planMatrixCell(
    doc: controller.doc,
    locationId: edit.locationId,
    media: edit.media,
    targetCount: edit.targetCount,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
    structureBodyId: structureBodyId,
  );

  switch (plan) {
    case MatrixCellRefused(:final reason):
      return reason;

    // NOTHING TO DO IS NOT A FAILURE. Tabbing across a row commits every
    // cell it passes, and a refusal there would put a sentence on screen
    // for navigating.
    case MatrixCellUnchanged():
      return null;

    // THE ONE ARM THAT IS AN OFFER RATHER THAN AN ANSWER, and it is
    // turned into a sentence here rather than into a silent creation.
    // docs/04 §3.4 forbids creating a device behind a person's back, and
    // the loop directly above the grid already asks the question
    // properly — so this names that surface instead of growing a second
    // way to answer it.
    //
    // It NAMES WHAT IS ON SCREEN, which is the lesson
    // `unbuilt_copy_accuracy_test.dart` was written for.
    case MatrixCellNeedsStructure():
      return kMatrixNeedsStructure;

    case MatrixCellReady(:final commands, :final added):
      controller.transact(
        // TWO LABELS, ONE GESTURE TYPE. "Undo add drops" and "Undo
        // remove drops" are opposite acts on the same grid, and a person
        // who typed the wrong number in a cell needs the Edit menu to
        // say which direction it is about to go.
        added > 0 ? LabelKey.addDrops : LabelKey.removeDrops,
        (tx) {
          for (final c in commands) {
            tx.add(c);
          }
        },
      );
      return null;
  }
};

/// What a cell says when the project has no Structure device yet.
const String kMatrixNeedsStructure =
    'This project has no Structure device for the drops to hang on. Type a '
    'line into the field above the grid and press Enter: it offers to create '
    'one.';
