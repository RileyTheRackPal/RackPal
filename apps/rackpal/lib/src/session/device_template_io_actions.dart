// `File ▸ Export device template…` and `File ▸ Import device template…`
// (DR-101 §11.100, `#236`).
//
// ─────────────────────────────────────────────────────────────────────────
// THIN, AND FOR `export_controller.dart`'s REASON
// ─────────────────────────────────────────────────────────────────────────
// Every decision this feature makes is somewhere else already:
// `template_import.dart` in core decides what an import MEANS,
// `device_template_io_dialogs.dart` in the UI asks the one question a
// person has to answer, `rmdx_codec.dart` decides the bytes, and
// `SaveTemplateToProjectCommand` writes the document. What is left here is
// the SEQUENCE, plus the two places a step can end early.
//
// ─────────────────────────────────────────────────────────────────────────
// THE FILE MENU, NOT A PALETTE CARD (DR-101 §11.100.4)
// ─────────────────────────────────────────────────────────────────────────
// Import belongs to no template, so a card menu would split the pair
// across two surfaces and make one verb learnable twice; and a card-level
// Export would be a second `FilePicker` call site, which
// `file_picker.dart`'s own header argues against by name and
// `session_layering_test.dart` RULE 7 asserts against.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT THIS DELIBERATELY DOES NOT DO
// ─────────────────────────────────────────────────────────────────────────
// It does not verify `contentHash`. Nothing in this repository computes a
// sha256 (`#795`), so AC-042's mismatch warning and its badge cannot fire:
// a placeholder never mismatches. DR-101 §11.100.6 rules that `#236` must
// not be read as having discharged them, and this header is where the next
// reader will look for that.
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/file_error_presenter.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/session_prompts.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/import_guard.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// Status line after a cancelled export.
///
/// **A CANCEL IS REPORTED, for `ExportController`'s reason**: an export is
/// a deliberate action with an expected artefact, so its absence is worth
/// one line. A cancelled OPEN is the one silent "nothing happened" this
/// app allows, because nothing was going to change either way.
const String kTemplateExportCancelledStatus =
    'Export cancelled. Nothing was written.';

const String kTemplateImportCancelledStatus =
    'Import cancelled. Nothing was added to this project.';

/// The file name a template export suggests: the display name, slugged
/// the way the id is, plus the extension.
///
/// **THE VERSION IS IN THE NAME.** Two exports of one template are two
/// different files and a person who has both wants to know which is
/// which, which is the same reason the chooser prints `v3` on the row.
String templateExportFileName(TemplateBody body, int version) {
  final slug = body.displayName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final base = slug.isEmpty ? 'device' : slug;
  return '$base-v$version$kDeviceTemplateExtension';
}

/// The two menu actions, with their collaborators bound once.
///
/// **A SIBLING OF `SessionController`, NOT A METHOD ON IT**, which is
/// `ExportController`'s own reasoning repeated because it applies
/// unchanged: these share the picker, the prompts and the writer with the
/// document's save path and nothing else. Neither touches the dirty flag,
/// the recovery snapshot, the recents list or the baseline. An IMPORT
/// does touch the document, but through the undo stack like any other
/// command, which is the whole point of it being one.
final class DeviceTemplateIo {
  const DeviceTemplateIo({
    required this.session,
    required this.controller,
    required this.picker,
    required this.writer,
    required this.fs,
    required this.prompts,
    required this.clock,
    this.initialDirectory,
    this.context,
  });

  final DocumentSession session;
  final DocumentController controller;
  final FilePicker picker;
  final AtomicWriter writer;
  final FileStore fs;
  final SessionPrompts prompts;
  final Clock clock;
  final Future<String?> Function()? initialDirectory;
  final p.Context? context;

  /// `File ▸ Export device template…`.
  Future<bool> export(
    Future<PlaceableTemplate?> Function(List<PlaceableTemplate>) chooseTemplate,
  ) => exportDeviceTemplate(
    session: session,
    picker: picker,
    writer: writer,
    chooseTemplate: chooseTemplate,
    initialDirectory: initialDirectory,
    context: context,
  );

  /// `File ▸ Import device template…`.
  Future<bool> import(
    Future<ImportTemplateChoice> Function(TemplateImportPlan) confirmImport,
  ) => importDeviceTemplate(
    session: session,
    controller: controller,
    picker: picker,
    fs: fs,
    prompts: prompts,
    clock: clock,
    confirmImport: confirmImport,
    initialDirectory: initialDirectory,
  );
}

/// Runs `File ▸ Export device template…`. True only when bytes reached
/// disk.
Future<bool> exportDeviceTemplate({
  required DocumentSession session,
  required FilePicker picker,
  required AtomicWriter writer,
  required Future<PlaceableTemplate?> Function(List<PlaceableTemplate>)
  chooseTemplate,
  Future<String?> Function()? initialDirectory,
  p.Context? context,
}) async {
  final ctx = context ?? p.context;

  // THE CHOOSER COMES BEFORE THE FILE DIALOG. Asking where to put a file
  // and only then which file it is wastes the one interaction, which is
  // `exportPdf`'s rackless check arriving in a different order.
  final rows = buildPlaceableTemplates(session.document);
  final chosen = await chooseTemplate(rows);
  if (chosen == null) {
    session.setStatus(kTemplateExportCancelledStatus);
    return false;
  }

  final snapshot = resolveLatestTemplate(session.document, chosen.id);
  if (snapshot == null) {
    // UNREACHABLE FROM THE CHOOSER, which was built from this same
    // document a moment ago, and handled anyway rather than asserted: the
    // await above is a window in which nothing stops a command running.
    session.setStatus(kTemplateExportCancelledStatus);
    return false;
  }

  final path = await picker.pickSave(
    type: FileDialogType.device,
    suggestedName: templateExportFileName(snapshot.body, snapshot.version),
    initialDirectory: await initialDirectory?.call(),
  );
  if (path == null) {
    session.setStatus(kTemplateExportCancelledStatus);
    return false;
  }

  final bytes = encodeRmdxBytes(DeviceTemplateFile.fromSnapshot(snapshot));
  final result = await writer.write(
    paths: SavePaths.forTarget(
      path,
      context: ctx,
      extensions: kDeviceTemplateExtensions,
    ),
    bytes: bytes,
    // A TEMPLATE FILE IS REGENERABLE from the project that holds it, so
    // CR-098's "the user's folder gains nothing but the file they asked
    // for" applies exactly as it does to a PDF.
    keepBackup: false,
  );
  if (result case Ok()) {
    session.setStatus(
      'Exported ${snapshot.body.displayName} v${snapshot.version}.',
    );
    return true;
  }
  return false;
}

/// Runs `File ▸ Import device template…`. True only when a template
/// entered the document.
Future<bool> importDeviceTemplate({
  required DocumentSession session,
  required DocumentController controller,
  required FilePicker picker,
  required FileStore fs,
  required SessionPrompts prompts,
  required Clock clock,
  required Future<ImportTemplateChoice> Function(TemplateImportPlan)
  confirmImport,
  Future<String?> Function()? initialDirectory,
}) async {
  final path = await picker.pickOpen(
    type: FileDialogType.device,
    initialDirectory: await initialDirectory?.call(),
  );
  // A CANCELLED OPEN IS SILENT, unlike a cancelled export: nothing was
  // going to change either way, and this is the one "nothing happened"
  // `SessionController.openDocument` already allows.
  if (path == null) return false;

  // THE SIZE CAP RUNS BEFORE THE READ (AC-058/D8, `#237`), and `#237`'s
  // own census gate is what found this: `readRmdxBytes` DOES run the
  // limits, but only after `readBytes` has already pulled the whole file
  // into memory, so a 2 GB `.rmdx` was refused at the cost of 2 GB. The
  // stat is one syscall and the refusal is the same sentence.
  //
  // A path `stat` cannot answer for is not refused here: "the file
  // vanished between the picker and the read" already has its own
  // message below, and reporting it as oversized would be a false
  // explanation.
  switch (await checkImportedFileSize(fs, path)) {
    case Err(:final error):
      await prompts.showFileError(_refused(path, error));
      return false;
    case Ok<void>():
      break;
  }

  final Uint8List bytes;
  try {
    bytes = await fs.readBytes(path);
  } on Object catch (e) {
    await prompts.showFileError(_unreadable(path, '$e'));
    return false;
  }

  final read = readRmdxBytes(bytes);
  if (read case Err(:final error)) {
    await prompts.showFileError(_refused(path, error));
    return false;
  }
  final file = (read as Ok<DeviceTemplateFile>).value;

  final plan = planTemplateImport(session.document, file);
  final choice = await confirmImport(plan);
  if (choice == ImportTemplateChoice.cancel) {
    session.setStatus(kTemplateImportCancelledStatus);
    return false;
  }

  controller.run(
    buildTemplateImport(
      session.document,
      plan,
      capturedAt: clock.nowUtc(),
      resolution: resolutionFor(choice),
    ),
  );
  session.setStatus(
    'Imported ${file.body.displayName}. It is in the palette under '
    'This project.',
  );
  return true;
}

FileErrorView _unreadable(String path, String detail) => FileErrorView(
  title: 'That file could not be read',
  detail:
      '${p.basename(path)} could not be opened. Nothing has been added to '
      'this project.\n\n$detail',
  actions: const <FileErrorAction>[
    FileErrorAction(id: FileErrorActionId.ok, label: 'OK', isPrimary: true),
  ],
);

/// The refusal, said in terms of WHICH mistake was made.
///
/// **A PROJECT FILE IS NOT A BROKEN DEVICE TEMPLATE**, and reporting it as
/// one sends the user back to re-pick the same file. That distinction is
/// the second half of M4-M1's file dialog: the filter stops most wrong
/// picks and the `kind` tag stops the rest, and it is only worth having if
/// the message spends it.
FileErrorView _refused(String path, Object error) {
  final name = p.basename(path);
  final detail = switch (error) {
    NotADeviceTemplateError() =>
      '$name is not a device template. If it is a RackPal project, open '
          'it with File ▸ Open instead.',
    NewerRmdxSchemaError() =>
      '$name was written by a newer build of RackPal and this one cannot '
          'read it without dropping what it does not understand.',
    DocumentTooLargeError() || JsonTooDeeplyNestedError() =>
      '$name is larger or more deeply nested than an import may be.',
    UnsupportedZipContainerError() =>
      '$name is an archive rather than a single device template.',
    _ => '$name could not be read as a device template.',
  };
  return FileErrorView(
    title: 'That is not a device template',
    detail: '$detail\n\nNothing has been added to this project.',
    actions: const <FileErrorAction>[
      FileErrorAction(id: FileErrorActionId.ok, label: 'OK', isPrimary: true),
    ],
  );
}
