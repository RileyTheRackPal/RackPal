// `File ▸ Export device library…` and `File ▸ Import device library…`
// (`#240`, DR-015 §11.15.3, AC-042, AC-058/D8).
//
// ─────────────────────────────────────────────────────────────────────────
// THIN, FOR device_template_io_actions.dart's REASON, AND THINNER
// ─────────────────────────────────────────────────────────────────────────
// Every decision is somewhere else already: `rmda_codec.dart` decides the
// bytes, `library_import.dart` decides what an import brings in and what
// an export offers, `library_directory.dart` decides where the shelf is,
// `import_guard.dart` decides how big a file may be, and the dialogs ask
// the person. What is left here is the SEQUENCE and the places it ends
// early.
//
// ─────────────────────────────────────────────────────────────────────────
// AN IMPORT COPIES THE FILE ONTO THE SHELF; IT DOES NOT REFERENCE IT
// ─────────────────────────────────────────────────────────────────────────
// Derivable rather than ruled, and stated so nobody re-derives it: a
// library referenced in place lives wherever the user picked it, which is
// routinely a USB stick or a network share. Referencing would make the
// palette's contents depend on what is currently plugged in, and the
// portable build in particular is FOR people who unplug things.
//
// The bytes are copied VERBATIM, not re-encoded from the parsed object.
// Re-encoding would silently normalise a hand-edited file and destroy the
// evidence AC-042's mismatch warning is about: the shelf holds what the
// sender sent.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT THIS DELIBERATELY DOES NOT DO
// ─────────────────────────────────────────────────────────────────────────
// It does not decide what a library MEANS to the palette. DR-102
// §11.101.3 rules that the palette answers for the document AND the
// loaded libraries; the merge is `#241`'s and the surface is `#242`'s.
// What this file gained from them is one method, [LibraryIo.shelf], and
// one line in `_importLibrary`: the shell re-reads the shelf after a
// successful import, so a library lands in the palette without a reopen.
//
// This paragraph read *"nothing reads the shelf yet"* until `#242`, and
// it was true when it was written.
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/file_error_presenter.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/session_prompts.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/import_guard.dart';
import 'package:rackpal/src/storage/library_directory.dart';
import 'package:rackpal/src/storage/library_shelf.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

const String kLibraryExportCancelledStatus =
    'Export cancelled. Nothing was written.';

const String kLibraryImportCancelledStatus =
    'Import cancelled. Nothing was added to your libraries.';

/// Said when a project has authored nothing, BEFORE any dialog opens.
///
/// For `exportPdf`'s reason: asking somebody to name a library and then
/// telling them there is nothing to put in it wastes the one interaction.
const String kNothingToPackStatus =
    'This project has no templates of its own to pack. Author one in the '
    'Device Builder first; the 48 shipped archetypes are not exported '
    'because every install already has them.';

/// A file name for [name], slugged the way template exports are.
String libraryExportFileName(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${slug.isEmpty ? 'library' : slug}$kDeviceLibraryExtension';
}

/// The two menu actions, with their collaborators bound once.
final class LibraryIo {
  const LibraryIo({
    required this.session,
    required this.picker,
    required this.writer,
    required this.fs,
    required this.prompts,
    required this.dataRoot,
    this.initialDirectory,
    this.context,
  });

  final DocumentSession session;
  final FilePicker picker;
  final AtomicWriter writer;
  final FileStore fs;
  final SessionPrompts prompts;

  /// Null in the degraded session, and that is the whole of the handling.
  ///
  /// `DataRootUnusable` means there is nowhere to keep a library, so
  /// IMPORT is unavailable and EXPORT is not: an export writes to the
  /// user's chosen directory, which is not the data root and has never
  /// been affected by that failure. One nullable field expresses both.
  final String? dataRoot;

  final Future<String?> Function()? initialDirectory;
  final p.Context? context;

  Future<bool> export(
    Future<ExportLibraryRequest?> Function(List<DeviceTemplateFile>) ask,
  ) => exportDeviceLibrary(
    session: session,
    picker: picker,
    writer: writer,
    askForLibrary: ask,
    initialDirectory: initialDirectory,
    context: context,
  );

  /// Every library on the shelf, decoded (`#242`, DR-102 §11.101.3).
  ///
  /// **THE DEGRADED SESSION IS AN EMPTY SHELF AND NOT AN ERROR**, the
  /// same one nullable field expressing it that expresses import being
  /// unavailable: `DataRootUnusable` means there is nowhere to keep a
  /// library, so there is nothing to read. The palette keeps working,
  /// because it reads the document and the seed and neither lives here.
  Future<List<ShelfLibrary>> shelf() async {
    final root = dataRoot;
    if (root == null) return const [];
    return loadLibraryShelf(fs, root, context: context);
  }

  Future<bool> import(
    Future<bool> Function(LibraryImportPreview) confirm,
  ) => importDeviceLibrary(
    session: session,
    picker: picker,
    writer: writer,
    fs: fs,
    prompts: prompts,
    dataRoot: dataRoot,
    confirmImport: confirm,
    initialDirectory: initialDirectory,
    context: context,
  );
}

/// Runs `File ▸ Export device library…`. True only when bytes landed.
Future<bool> exportDeviceLibrary({
  required DocumentSession session,
  required FilePicker picker,
  required AtomicWriter writer,
  required Future<ExportLibraryRequest?> Function(List<DeviceTemplateFile>)
  askForLibrary,
  Future<String?> Function()? initialDirectory,
  p.Context? context,
}) async {
  final ctx = context ?? p.context;

  final candidates = exportableLibraryTemplates(session.document);
  if (candidates.isEmpty) {
    session.setStatus(kNothingToPackStatus);
    return false;
  }

  final request = await askForLibrary(candidates);
  if (request == null) {
    session.setStatus(kLibraryExportCancelledStatus);
    return false;
  }

  final path = await picker.pickSave(
    type: FileDialogType.library,
    suggestedName: libraryExportFileName(request.name),
    initialDirectory: await initialDirectory?.call(),
  );
  if (path == null) {
    session.setStatus(kLibraryExportCancelledStatus);
    return false;
  }

  final bytes = encodeRmdaBytes(
    DeviceLibraryFile(
      name: request.name,
      templates: request.selected,
      // DR-245 §11.244.1: once for the library, the families its devices
      // name that do not ship.
      signalFamilies: familiesToCarry([
        for (final t in request.selected) t.body,
      ], session.document.registries),
    ),
  );
  final result = await writer.write(
    paths: SavePaths.forTarget(
      path,
      context: ctx,
      extensions: kDeviceLibraryExtensions,
    ),
    bytes: bytes,
    // Regenerable from the project that holds the templates, so CR-098's
    // "the user's folder gains nothing but the file they asked for".
    keepBackup: false,
  );
  if (result case Ok()) {
    final n = request.selected.length;
    session.setStatus(
      'Exported ${request.name}: ${n == 1 ? '1 template' : '$n templates'}.',
    );
    return true;
  }
  return false;
}

/// Runs `File ▸ Import device library…`. True only when a library landed
/// on the shelf.
Future<bool> importDeviceLibrary({
  required DocumentSession session,
  required FilePicker picker,
  required AtomicWriter writer,
  required FileStore fs,
  required SessionPrompts prompts,
  required String? dataRoot,
  required Future<bool> Function(LibraryImportPreview) confirmImport,
  Future<String?> Function()? initialDirectory,
  p.Context? context,
}) async {
  final ctx = context ?? p.context;

  // THE DEGRADED SESSION IS REFUSED BEFORE THE DIALOG, not after the
  // read. There is nowhere to put a library, and finding that out after
  // the user has picked a file and read a warning is the wasted
  // interaction `exportPdf` already refuses to inflict.
  if (dataRoot == null) {
    await prompts.showFileError(
      const FileErrorView(
        title: 'Libraries are unavailable this session',
        detail:
            'RackPal could not open a writable data folder when it '
            'started, so there is nowhere to keep a library. Documents '
            'still open and save normally.',
        actions: <FileErrorAction>[
          FileErrorAction(
            id: FileErrorActionId.ok,
            label: 'OK',
            isPrimary: true,
          ),
        ],
      ),
    );
    return false;
  }

  final path = await picker.pickOpen(
    type: FileDialogType.library,
    initialDirectory: await initialDirectory?.call(),
  );
  // A cancelled open is silent: nothing was going to change either way.
  if (path == null) return false;

  switch (await checkImportedFileSize(fs, path)) {
    case Err(:final error):
      await prompts.showFileError(_refused(ctx, path, error));
      return false;
    case Ok<void>():
      break;
  }

  final Uint8List bytes;
  try {
    bytes = await fs.readBytes(path);
  } on Object catch (e) {
    await prompts.showFileError(_unreadable(ctx, path, '$e'));
    return false;
  }

  final read = readRmdaBytes(bytes);
  if (read case Err(:final error)) {
    await prompts.showFileError(_refused(ctx, path, error));
    return false;
  }
  final library = (read as Ok<DeviceLibraryFile>).value;

  if (!await confirmImport(previewLibraryImport(library))) {
    session.setStatus(kLibraryImportCancelledStatus);
    return false;
  }

  // THE SHELF IS CREATED ON THE WAY PAST, which is what
  // `library_directory.dart` says: it does not exist until something is
  // imported, and creating it at startup would put an empty folder on a
  // user's stick to record that they have never used a feature.
  final shelf = libraryDirectoryPath(dataRoot, context: ctx);
  try {
    await fs.createDirectory(shelf);
  } on Object catch (e) {
    await prompts.showFileError(_unreadable(ctx, shelf, '$e'));
    return false;
  }

  // THE BYTES ARE COPIED VERBATIM. Re-encoding from `library` would
  // normalise a hand-edited file and destroy the evidence the mismatch
  // warning was just about.
  //
  // Through `AtomicWriter` like every other write in this app, so the
  // copy shares the one `SaveQueue` and cannot interleave with an
  // autosave over the same directory. `keepBackup: false` for the same
  // reason a PDF does: the shelf gains the file the user asked for and
  // nothing else (CR-098).
  final result = await writer.write(
    paths: SavePaths.forTarget(
      ctx.join(shelf, ctx.basename(path)),
      context: ctx,
      extensions: kDeviceLibraryExtensions,
    ),
    bytes: bytes,
    keepBackup: false,
  );
  if (result case Err()) {
    await prompts.showFileError(
      _unreadable(ctx, shelf, 'the library could not be copied to the shelf'),
    );
    return false;
  }

  final n = library.templates.length;
  session.setStatus(
    'Imported ${library.name}: ${n == 1 ? '1 template' : '$n templates'}. '
    'It is on your library shelf.',
  );
  return true;
}

FileErrorView _unreadable(p.Context ctx, String path, String detail) =>
    FileErrorView(
      title: 'That library could not be read',
      detail:
          '${ctx.basename(path)} could not be opened. Nothing has been '
          'added to your libraries.\n\n$detail',
      actions: const <FileErrorAction>[
        FileErrorAction(
          id: FileErrorActionId.ok,
          label: 'OK',
          isPrimary: true,
        ),
      ],
    );

/// The refusal, said in terms of WHICH mistake was made.
///
/// A `.rpdx` reported as a broken library sends the user back to re-pick
/// the same file, which is M4-M1's argument for the `kind` tag and the
/// only reason having one is worth anything.
///
/// THE TITLE NAMES THE CAUSE TOO (DR-199). It said *"That is not a device
/// library"* for every refusal, including a file that is one and is merely
/// too large or newer than this build, under a detail line saying so.
FileErrorView _refused(p.Context ctx, String path, Object error) {
  final name = ctx.basename(path);
  final (title, detail) = switch (error) {
    NotADeviceLibraryError() => (
      'That is not a device library',
      '$name is not a device library. If it is a single device '
          'template, use File ▸ Import device template… instead.',
    ),
    NewerRmdaSchemaError() => (
      'This library needs a newer RackPal',
      '$name was written by a newer build of RackPal and this one cannot '
          'read it without dropping what it does not understand.',
    ),
    DocumentTooLargeError() || JsonTooDeeplyNestedError() => (
      'That library is too large to import',
      '$name is larger or more deeply nested than an import may be.',
    ),
    UnsupportedZipContainerError() => (
      'That is not a device library',
      '$name is a zip archive. A RackPal library is a single JSON file '
          '(DR-015); a zipped pack is from a format that never shipped.',
    ),
    _ => (
      'That library could not be read',
      '$name could not be read as a device library.',
    ),
  };
  return FileErrorView(
    title: title,
    detail: '$detail\n\nNothing has been added to your libraries.',
    actions: const <FileErrorAction>[
      FileErrorAction(id: FileErrorActionId.ok, label: 'OK', isPrimary: true),
    ],
  );
}
