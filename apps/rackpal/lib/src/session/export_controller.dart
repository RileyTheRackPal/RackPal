// `File ▸ Export PDF…`.
//
// ==================================================================
// IT REUSES THE SAVE PATH RATHER THAN INVENTING ONE
// ==================================================================
// docs/08 §8.3: "Saving uses the app's own save dialog … The PDF path gets
// the same dialog, the same `.rppj`-style filter mechanics and the same
// MRU behaviour as document Save As, for free."
//
// So this controller is deliberately thin: `picker.pickSave` →
// `SavePaths.forTarget(…, extension: '.pdf')` → `AtomicWriter.write` →
// `describeSaveError` + `SessionPrompts.showFileError`. That inherits the
// whole enumerated failure surface the persistence stage built —
// `SaveDiskFull`, `SaveReadOnlyTarget`, `SavePathTooLong`,
// `SaveUnreachable`, and the one this feature is most likely to meet,
// `SaveLocked`: AC-058/D4's "the target PDF is open in Acrobat".
//
// `keepBackup: false` because a PDF is a REGENERABLE DELIVERABLE, not the
// project. CR-098's "the user's folder gains nothing but the file they
// asked for" applies with more force here, not less: nobody wants a
// `smith_SET_revA_2026-07-18.pdf.bak` beside their drawing set.
//
// ==================================================================
// NEVER SILENTLY DO NOTHING
// ==================================================================
// Three outcomes report, and none of them is silence:
//   * a cancelled picker  → "Export cancelled."
//   * a rackless document → refused BEFORE the dialog, with the reason
//   * a success           → "Exported 3 sheets · 214 KB"
// A document with no racks would otherwise produce a one-sheet PDF of
// nothing, which is worse than a refusal because it looks like a
// deliverable.
//
// ==================================================================
// NO NEW KEYBINDING THIS STAGE
// ==================================================================
// docs/08 §8.1 gives export `Ctrl+P`. `session_layering_test.dart` RULE 14
// asserts EXACTLY four bindings and eight activators, and that rule exists
// so the file group cannot quietly grow a fifth member. Adding `Ctrl+P`
// here would edit it by stealth. One File menu entry ships; the binding is
// recorded as deferred so the decision is taken explicitly.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/export_runner.dart';
import 'package:rackpal/src/session/file_error_presenter.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/session_prompts.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/errors.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/storage_log.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_ui/rackpal_ui.dart' show FileErrorAction, FileErrorView;

/// Reads the bundled TTFs. Injected because `rackpal_export` is pure Dart
/// and cannot reach an asset bundle, and because the session layer may not
/// touch `dart:io` (`session_layering_test.dart` RULE 10) — so the one
/// place that knows how to load an asset is `main.dart`'s wiring, and a
/// test supplies bytes directly.
typedef ExportFontLoader = Future<Map<FontRef, Uint8List>> Function();

/// The one bundled face, as `rackpal_export` names it.
///
/// SCOPE NOTE: only Jost Regular is bundled (docs/08 §10.1's full font
/// table is a later stage). It is declared TWICE in `pubspec.yaml` —
/// under `fonts:` for Flutter's text engine and under `assets:` so it is
/// loadable as raw bytes here — which is §10.2's "two-declaration trap",
/// and dropping either side makes the two backends measure different
/// fonts.
const FontRef kExportFont = FontRef('Jost');

/// The asset the [kExportFont] bytes come from.
const String kExportFontAsset = 'assets/fonts/Jost-Regular.ttf';

/// The production [ExportFontLoader].
Future<Map<FontRef, Uint8List>> loadExportFontsFromBundle() async {
  final data = await rootBundle.load(kExportFontAsset);
  return <FontRef, Uint8List>{
    // `asUint8List(offsetInBytes, lengthInBytes)` rather than
    // `buffer.asUint8List()`: an `AssetBundle` may return a `ByteData`
    // that is a VIEW into a larger buffer, and taking the whole buffer
    // would prepend and append whatever surrounds it. The starter loader
    // learned this the hard way — see `bytesOfAssetData`'s own note.
    kExportFont: data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    ),
  };
}

/// How long an export runs before its progress is shown (docs/08 §8.2):
/// under this, a bar flashed on screen looks worse than a pause.
const Duration kExportProgressDelay = Duration(milliseconds: 400);

/// What the status line says when the user backs out of the dialog.
const String kExportCancelledStatus = 'Export cancelled.';

/// The menu item that requests the ISSUED FOR CONSTRUCTION stamp (DR-216
/// §11.215.1). A constant because a test finds the item by it.
const String kExportForConstructionLabel = 'Export for construction…';

/// What a document with no racks is told, out loud.
const String kExportNoRacksTitle = 'Nothing to export.';

/// Runs `File ▸ Export PDF…` for the one open document.
final class ExportController {
  ExportController({
    required this.session,
    required this.picker,
    required this.prompts,
    required this.writer,
    required this.fontLoader,
    required this.clock,
    this.initialDirectory,
    this.runner = runExport,
    p.Context? context,
  }) : context = context ?? p.context;

  /// Starts the export off the main isolate (CR-099, M6-I2). Injected so a
  /// widget test runs it inline, where fake async can see it finish.
  final ExportRunner runner;

  final DocumentSession session;
  final FilePicker picker;
  final SessionPrompts prompts;
  final AtomicWriter writer;
  final ExportFontLoader fontLoader;
  final Clock clock;
  final p.Context context;

  /// Where the save dialog opens. Supplied by the shell so the PDF dialog
  /// starts where the last document save did, exactly as §8.3 asks.
  final Future<String?> Function()? initialDirectory;

  /// Exports the current document. Returns true only when bytes reached
  /// disk.
  ///
  /// [issuedForConstruction] is `File ▸ Export for construction…` (DR-216
  /// §11.215.1): it REQUESTS the stamp for this one export and remembers
  /// nothing. An open error withholds the stamp and never the file, and the
  /// status line says which happened.
  Future<bool> exportPdf({bool issuedForConstruction = false}) async {
    // ── refuse a rackless document BEFORE the dialog ────────────────────
    //
    // Before, not after: asking the user where to put a file and only then
    // saying there is nothing to put in it wastes the one interaction.
    if (session.document.racks.isEmpty) {
      await prompts.showFileError(
        const FileErrorView(
          title: kExportNoRacksTitle,
          detail:
              'This project has no racks, so there is no elevation to draw '
              'and no equipment to schedule. Add a rack and try again — '
              'nothing has been written.',
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

    final chosen = await picker.pickSave(
      suggestedName: exportFileNameFor(
        displayName: session.displayName,
        document: session.document,
        issuedAt: clock.nowUtc(),
      ),
      initialDirectory: await initialDirectory?.call(),
    );
    // A CANCEL IS REPORTED. `SessionController.openDocument` treats a
    // cancelled OPEN as the one silent "nothing happened" it allows,
    // because nothing was going to change either way. An export is a
    // deliberate action with an expected artefact, so its absence is worth
    // one line.
    if (chosen == null) {
      session.setStatus(kExportCancelledStatus);
      return false;
    }

    // ── build ───────────────────────────────────────────────────────────
    //
    // ENCODED FIRST, SYNCHRONOUSLY, then handed over as bytes. Same reason
    // `storage/serialization.dart` splits its two phases: what crosses into
    // the builder must be a SNAPSHOT of one document state, not the live
    // mutable graph, or an edit racing the export can be half-included.
    final json = const JsonDocumentCodec().write(session.document);
    final job = runner(
      ExportRequest(
        documentJson: json,
        fontBytes: await fontLoader(),
        // THE FLOORPLAN BYTES, AND THE EXPORT COULD NOT REACH THEM UNTIL
        // `PLAN-H/1` (DR-149 §11.148.1). They ride from open to save on
        // `DocumentSession.members` and had no third reader; `T1.01` is
        // the first sheet that draws an image, so it is the first thing
        // that ever needed them. Snapshotted with the JSON above, for the
        // same reason: `members` is replaced wholesale rather than
        // mutated, so an import racing an export cannot half-appear.
        members: session.members,
        // THE PROJECT'S OWN FILE NAME, as docs/08 §5.2's worked example
        // prints it (`FILE smith.rppj`) and `title_block.dart` documents
        // it. This passed the PDF's name from the save dialog, which is
        // not data about the project; and since DR-230 previews the bytes
        // BEFORE the save dialog, it could not be known anyway. An unsaved
        // project has no file, and the field prints its dash.
        fileName: switch (session.filePath) {
          final path? => context.basename(path),
          null => '',
        },
        // ONE clock value for the whole export (§8.4). Injected, never
        // `DateTime.now()` inside a sheet builder.
        issuedAt: clock.nowUtc(),
        issuedForConstruction: issuedForConstruction,
      ),
    );
    final built = await _awaitWithProgress(job);
    // CANCELLED, AND SAID: the work was stopped and nothing was written.
    if (built == null) {
      session.setStatus(kExportCancelledStatus);
      return false;
    }
    if (built case Err(:final error)) {
      await prompts.showFileError(_describeExportError(error as ExportError));
      return false;
    }
    final exported = (built as Ok<ExportedDocument>).value;

    return _write(
      SavePaths.forTarget(
        chosen,
        context: context,
        extensions: const <String>[kPdfExtension],
      ),
      exported,
    );
  }

  /// [job]'s outcome, showing its progress only if it is still running
  /// after [kExportProgressDelay] (docs/08 §8.2). Null when it was
  /// cancelled.
  Future<Outcome<ExportedDocument>?> _awaitWithProgress(ExportJob job) async {
    final finished = job.result.then<void>((_) {}, onError: (Object _) {});
    // A TIMER THAT IS CANCELLED, NOT A `Future.delayed` RACED AGAINST THE
    // JOB. The race left its 400 ms delay pending after every fast export,
    // which a widget test reports as a timer outliving the tree, and which
    // in the app is a stray wake-up for nothing.
    final timer = Timer(kExportProgressDelay, () {
      unawaited(
        prompts.showExportProgress(
          progress: job.progress,
          finished: finished,
          onCancel: job.cancel,
        ),
      );
    });
    try {
      return await job.result;
    } finally {
      timer.cancel();
    }
  }

  Future<bool> _write(SavePaths paths, ExportedDocument exported) async {
    final result = await writer.write(
      paths: paths,
      bytes: exported.bytes,
      // See the file header: a PDF is regenerable, and CR-098 says the
      // user's folder gains nothing but the file they asked for.
      keepBackup: false,
    );

    if (result case Ok(:final value)) {
      logStorageEvent('pdf_exported', {
        'sheets': exported.sheetCount,
        'bytes': value.bytesWritten,
        'notices': exported.notices.length,
      });
      session.setStatus(
        describeExportSuccess(
          sheetCount: exported.sheetCount,
          bytesWritten: value.bytesWritten,
          notices: exported.notices,
          stamped: exported.stamped,
          stampWithheld: exported.stampWithheld,
        ),
        // THE SENTENCES, NOT ONLY THE COUNT (DR-224): until this line the
        // count was all that reached the user.
        notices: exported.notices,
      );
      return true;
    }

    final error = (result as Err<WriteReceipt>).error;
    if (error is! SaveError) {
      throw StateError('AtomicWriter.write returned a non-SaveError: $error');
    }
    // THE WHOLE ENUMERATED SURFACE, FOR FREE. `SaveLocked` here is
    // AC-058/D4's "the target PDF is open in Acrobat", and it already has
    // its own copy and its own Retry button because the document save path
    // needed the same thing.
    final pressed = await prompts.showFileError(
      describeSaveError(error, context: context),
    );
    switch (pressed) {
      case FileErrorActionId.retry:
        return _write(paths, exported);
      case FileErrorActionId.overwrite:
        return _write(paths, exported);
      default:
        // Refused, and reported. Nothing is silent.
        return false;
    }
  }

  FileErrorView _describeExportError(ExportError error) => FileErrorView(
    title: switch (error) {
      ExportNoRacks() => kExportNoRacksTitle,
      ExportDocumentUnreadable() => 'That project could not be exported.',
      ExportFontMissing() => 'A font this build needs is missing.',
      ExportTooManySheets() => 'Too many sheets to export.',
    },
    detail: '${error.message} Nothing has been written.',
    actions: const <FileErrorAction>[
      FileErrorAction(
        id: FileErrorActionId.ok,
        label: 'OK',
        isPrimary: true,
      ),
    ],
  );
}

/// docs/08 §8.3's default filename:
/// `{project-slug}_{rack-or-SET}_rev{REV}_{yyyy-MM-dd}.pdf`.
///
/// THE REVISION IS NOT OPTIONAL, and §8.3 says why in one sentence: "it is
/// the only thing that stops the wrong PDF being on site." A document with
/// no revision history — the normal case in this build, since no
/// `RevisionEntry` generator exists — gets `rev-`, which is honest: there
/// is no revision, and a filename claiming `revA` would be inventing one.
String exportFileNameFor({
  required String displayName,
  required RackDocument document,
  required DateTime issuedAt,
}) {
  final slug = slugify(displayName);
  // ONE rack names itself; more than one is a SET. The exit criterion's
  // three-sheet PDF is the one-rack case, and `SET` is what stops two
  // exports of a two-rack project from claiming to be the same rack.
  final scope = document.racks.length == 1
      ? slugify(document.racks.values.single.designator)
      : 'SET';
  final revision = newestRevisionLabel(document.revisionBlock);
  final rev = revision == null || revision.trim().isEmpty
      ? '-'
      : slugify(revision);
  final date = formatSheetDate(issuedAt);
  return '${slug}_${scope}_rev${rev}_$date$kPdfExtension';
}

/// Lower-cases, and replaces every run of anything that is not a letter or
/// a digit with a single hyphen.
///
/// A file name reaches a Windows filesystem, an email attachment and a
/// client's DMS. `Smith Residence — Phase 2 (rev C)` must not arrive as a
/// path the OS refuses, and the characters Windows forbids
/// (`\ / : * ? " < > |`) are a subset of what this removes.
String slugify(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'project' : slug;
}

/// §8.3's completion strip, as one status line.
///
/// The notice count is INCLUDED rather than swallowed: §6.2's legibility
/// check and the NCS id validation both report here, and a notice nobody
/// is told about is a notice that did not happen. It is never a gate
/// (CR-023, G3) — the bytes are already on disk by the time this is built.
String describeExportSuccess({
  required int sheetCount,
  required int bytesWritten,
  required List<String> notices,
  bool stamped = false,
  String? stampWithheld,
}) {
  final sheets = '$sheetCount sheet${sheetCount == 1 ? '' : 's'}';
  final size = formatByteSize(bytesWritten);
  final n = notices.length;
  return <String>[
    'Exported $sheets',
    size,
    // THE STAMP BEFORE THE NOTICES (DR-216 §11.215.1): it is the outcome of
    // the command the user chose, and a withheld stamp is printed whole
    // rather than counted, with the sheet that lists the errors.
    if (stamped) 'issued for construction',
    ?stampWithheld,
    if (n > 0) noticeCountLabel(n),
  ].join(' · ');
}

/// `1 notice`, `6 notices`: the status line's last segment, and the text
/// its link wears (DR-224). One function, so the link finds the words the
/// line prints.
String noticeCountLabel(int n) => '$n notice${n == 1 ? '' : 's'}';

/// `214 KB`, `1.4 MB`. Kilobytes are 1024 bytes, which is what a Windows
/// file listing shows.
String formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.round()} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
