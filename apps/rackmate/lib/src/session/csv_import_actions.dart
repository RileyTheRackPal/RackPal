// apps/rackmate/src/session/csv_import_actions.dart
//
// THE APP HALF OF docs/07 §5's IMPORT. Board M3-F/2 (#160), M3-F/3
// (#161).
//
// ═════════════════════════════════════════════════════════════════════
// WHY THE FLOW LIVES HERE AND THE SURFACE LIVES IN rackmate_ui
// ═════════════════════════════════════════════════════════════════════
// It opens a native file dialog and reads a file off disk, and
// `rackmate_ui` has neither: it takes no `dart:io` and no platform
// channel. So this file does picking, reading and committing, and hands
// `showCsvImportDialog` a parsed table and a callback. Everything
// between those two points is pure: `readCsv`, `resolveCsvRows`,
// `planCsvImport` and `buildCsvImport` all live in `rackmate_core` and
// none of them knows what a file is.
//
// ═════════════════════════════════════════════════════════════════════
// THE PLAN IS BUILT TWICE, AND THAT IS DELIBERATE
// ═════════════════════════════════════════════════════════════════════
// The dialog plans continuously to render its preview; this rebuilds it
// once more, from the mapping the operator settled on, against the
// document AS IT IS AT COMMIT TIME. Handing the dialog's plan straight
// to the writer would be the one way this could apply a plan computed
// against a document that has since moved — an autosave, a second
// window, an undo behind the dialog. Re-deriving is one call and the
// inputs are deterministic, so the numbers cannot change unless the
// document did, which is exactly when they should.
//
// ═════════════════════════════════════════════════════════════════════
// ONE TRANSACTION, WHICH IS §5.3's OWN REQUIREMENT
// ═════════════════════════════════════════════════════════════════════
// "the whole import is one undoable `Command`". `LabelKey.importCsv`
// exists for this, so sixty drops, four rooms and two cable types are
// one Ctrl+Z. The confirm dialog promises exactly that in words, and
// this is what makes the promise true.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:rackmate/src/session/file_picker.dart';
import 'package:rackmate/src/storage/file_store.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// Reads a CSV file's text, or says why it could not.
///
/// **DECODED AS UTF-8 WITH REPLACEMENT, NEVER REFUSED FOR AN ENCODING.**
/// A pull list exported from an old Excel is frequently Windows-1252,
/// and the byte that differs is nearly always inside a name or a note:
/// `Café`, a curly apostrophe, a `°`. Refusing the file over one byte
/// would reject a sheet whose sixty rows are all readable, so a bad
/// sequence becomes U+FFFD, survives into the cell, and is visible in
/// the preview grid where a person can fix it. `allowMalformed` is what
/// spells that.
///
/// A BOM is `readCsv`'s to strip; this does not pre-chew the text.
///
/// **THROUGH `FileStore`, NEVER `dart:io`.** Two layering gates say so
/// and both caught the first draft of this file: RULE 10 keeps the
/// session layer off `dart:io`, and RULE 1b keeps `File(` in exactly one
/// place. Reaching past the seam here would have been a second I/O path
/// with none of the errno translation `io_file_store.dart` does, on the
/// one platform where a locked file is the normal case, because Excel is
/// still holding the sheet open.
Future<String> readCsvText(FileStore fs, String path) async =>
    utf8.decode(await fs.readBytes(path), allowMalformed: true);

/// Runs docs/07 §5's import end to end: pick, read, preview, commit.
///
/// Returns a refusal sentence for the caller to surface, or null when
/// the import committed or the user cancelled. **A CANCEL IS NOT A
/// REFUSAL** and returns null: nothing went wrong and nothing should be
/// said about it.
Future<String?> runCsvImport({
  required BuildContext context,
  required DocumentController controller,
  required FilePicker picker,
  required FileStore fs,
  Uuid? structureBodyId,
}) async {
  final path = await picker.pickOpen(type: FileDialogType.csv);
  if (path == null) return null;

  final String text;
  try {
    text = await readCsvText(fs, path);
  } on Exception catch (e) {
    // `FileStore.readBytes` declares no typed failure, so this catches
    // the interface's whole contract rather than one implementation's
    // exception class: naming `FileSystemException` would be reaching
    // through the seam for a type the seam does not promise, and would
    // miss whatever a fake or a future store throws.
    //
    // The realistic causes are all one sentence to the user: the file
    // moved between the picker and the read, or Excel still has it open,
    // which is the normal state of a pull list on a jobsite laptop.
    return 'That file could not be read. It may have moved, or another '
        'program may still have it open. ($e)';
  }

  final read = readCsv(text);
  if (read case CsvReadRefused(:final message)) return message;
  final table = (read as CsvReadOk).table;

  if (!context.mounted) return null;
  final choice = await showCsvImportDialog(
    context,
    table: table,
    currentDoc: () => controller.doc,
    fileName: _baseName(path),
  );
  if (choice == null) return null;

  return commitCsvImport(
    controller: controller,
    table: table,
    choice: choice,
    structureBodyId: structureBodyId,
  );
}

/// Applies [choice] as ONE transaction, or refuses whole.
///
/// Separated from the picking and the dialog so a test can drive the
/// write path without a file or a widget tree, which is where the
/// interesting assertions are.
String? commitCsvImport({
  required DocumentController controller,
  required CsvTable table,
  required CsvImportChoice choice,
  Uuid? structureBodyId,
}) {
  final doc = controller.doc;
  final rows = resolveCsvRows(
    table: table,
    mapping: choice.mapping,
    registries: doc.registries,
    settings: doc.settings,
  );
  final plan = planCsvImport(
    doc: doc,
    rows: rows,
    declinedLocations: choice.declinedLocations,
    declinedMediaTokens: choice.declinedMediaTokens,
  );
  final built = buildCsvImport(
    doc: doc,
    plan: plan,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
    structureBodyId: structureBodyId,
  );

  switch (built) {
    case CsvImportRefused(:final reason):
      return reason;
    case CsvImportReady(:final commands, :final warnings):
      // NOTHING TO DO IS NOT AN EMPTY TRANSACTION. Re-importing an
      // unchanged sheet is the ordinary second pass, and pushing an
      // empty entry would cost the user an undo step that undoes
      // nothing.
      if (commands.isEmpty) {
        return warnings.isEmpty ? null : _warningSentence(warnings);
      }
      controller.transact(LabelKey.importCsv, (tx) {
        for (final command in commands) {
          tx.add(command);
        }
      });
      // A ROW THAT COULD NOT BE BUILT IS REPORTED, NOT SWALLOWED, and
      // the other fifty-nine still landed (§5.3, never fail-fast).
      return warnings.isEmpty ? null : _warningSentence(warnings);
  }
}

String _warningSentence(List<CsvCellIssue> warnings) => warnings.length == 1
    ? warnings.single.message
    : '${warnings.length} rows could not be imported. '
          '${warnings.first.message}';

/// `E:\Jobs\Smith\pull-list.csv` → `pull-list.csv`.
///
/// THE NAME AND NOT THE PATH, because the dialog header shows it to
/// confirm the operator picked the file they meant, and a full path
/// pushes that answer off the right-hand edge.
String _baseName(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  return cut == -1 ? path : path.substring(cut + 1);
}
