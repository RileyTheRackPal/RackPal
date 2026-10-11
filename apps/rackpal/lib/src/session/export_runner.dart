// `apps/rackpal/lib/src/session/export_runner.dart`: the export, off the
// main isolate, with progress and a cancel that stops it (M6-I2 `#353`,
// M6-I3 `#354`, CR-099, docs/08 §8.2).
//
// ═══════════════════════════════════════════════════════════════════════
// `Isolate.spawn`, NOT `Isolate.run`, BECAUSE OF THE TWO THINGS RUN LACKS
// ═══════════════════════════════════════════════════════════════════════
// CR-099: `Isolate.run` has no progress and no cancellation. So the export
// spawns one isolate per job (never a pool, never `compute` in a loop),
// hears `(sheetsDone, sheets)` over a `SendPort`, and gets its result back
// through `Isolate.exit`, which hands the PDF's bytes over without a copy.
// Cancel is `Isolate.kill(priority: immediate)`: the work stops rather
// than the dialog merely closing, and an aborted export produces nothing,
// which is correct (§8.2).
//
// EVERYTHING THAT CROSSES IS BYTES. `ExportRequest` was shaped for this
// from M1 (`export_request.dart`): the document as JSON, the fonts and the
// floorplans as `Uint8List`, a date, a name. No asset bundle, no channel
// and no `BuildContext` is reachable from the isolate, and none is needed.
//
// ═══════════════════════════════════════════════════════════════════════
// AND AN INLINE RUNNER, FOR TWO CALLERS THAT CANNOT SPAWN
// ═══════════════════════════════════════════════════════════════════════
// The web has no isolates (CR-099's one-line `kIsWeb` guard, M6-I3), and a
// widget test's fake-async zone never delivers work done in another
// isolate, so a test that spawned would hang without a word. Both get
// [runExportInline]: the same `buildExportDocument`, the same progress,
// and a cancel that discards the result because it cannot stop the work.
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_ui/rackpal_ui.dart' show ExportProgress;

/// One running export.
final class ExportJob {
  /// A job over [result] and [progress], stopped by [cancel]. The two
  /// runners below build these; a test builds one to stand in for a slow
  /// export.
  ExportJob({
    required this.result,
    required this.progress,
    required this.cancel,
  });

  /// The export's outcome, or null when it was cancelled. Completes once.
  final Future<Outcome<ExportedDocument>?> result;

  /// How far it has got; null until the set resolves.
  final ValueListenable<ExportProgress?> progress;

  /// Stops the export. [result] completes with null at once, and nothing
  /// the work produces afterwards is delivered.
  final void Function() cancel;
}

/// Starts an export of [request].
typedef ExportRunner = ExportJob Function(ExportRequest request);

/// The production runner: an isolate, except where there are none.
ExportJob runExport(ExportRequest request) =>
    kIsWeb ? runExportInline(request) : runExportInIsolate(request);

/// The export on the calling isolate, for the web and for widget tests.
ExportJob runExportInline(ExportRequest request) {
  final progress = ValueNotifier<ExportProgress?>(null);
  final done = Completer<Outcome<ExportedDocument>?>();
  // Not awaited: [done] carries the result, and `onError` routes a failure
  // into it, so the future `then` returns never errors.
  unawaited(
    buildExportDocument(
      request,
      onProgress: (sheetsDone, sheets) {
        if (!done.isCompleted) {
          progress.value = (sheetsDone: sheetsDone, sheets: sheets);
        }
      },
    ).then(
      (outcome) {
        if (!done.isCompleted) done.complete(outcome);
      },
      onError: (Object error, StackTrace stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      },
    ),
  );
  return ExportJob(
    result: done.future,
    progress: progress,
    cancel: () {
      if (!done.isCompleted) done.complete(null);
    },
  );
}

/// The export in its own isolate (CR-099).
ExportJob runExportInIsolate(ExportRequest request) {
  final progress = ValueNotifier<ExportProgress?>(null);
  final done = Completer<Outcome<ExportedDocument>?>();
  final port = ReceivePort();
  Isolate? isolate;
  var cancelled = false;

  void finish(void Function() complete) {
    if (!done.isCompleted) complete();
    port.close();
  }

  port.listen((message) {
    switch (message) {
      case (final int sheetsDone, final int sheets):
        if (!done.isCompleted) {
          progress.value = (sheetsDone: sheetsDone, sheets: sheets);
        }
      case _ExportResult(:final outcome):
        finish(() => done.complete(outcome));
      case _ExportCrashed(:final error, :final stack):
        finish(
          () => done.completeError(
            StateError('The export failed: $error'),
            StackTrace.fromString(stack),
          ),
        );
      // `onExit` sends null. Reaching it with nothing delivered means the
      // isolate died without a word, which must not leave a caller
      // waiting for ever.
      case null:
        finish(
          () => done.completeError(
            StateError('The export stopped without a result.'),
          ),
        );
    }
  });

  // Not awaited, for the inline runner's reason: `onError` routes a failed
  // spawn into [done], so the future `then` returns never errors.
  unawaited(
    Isolate.spawn<(SendPort, ExportRequest)>(
      _exportEntry,
      (port.sendPort, request),
      onExit: port.sendPort,
      debugName: 'rackpal-export',
    ).then(
      (spawned) {
        isolate = spawned;
        // A CANCEL THAT ARRIVED WHILE THE ISOLATE WAS STILL STARTING.
        if (cancelled) spawned.kill(priority: Isolate.immediate);
      },
      onError: (Object error, StackTrace stack) =>
          finish(() => done.completeError(error, stack)),
    ),
  );

  return ExportJob(
    result: done.future,
    progress: progress,
    cancel: () {
      if (done.isCompleted) return;
      cancelled = true;
      isolate?.kill(priority: Isolate.immediate);
      finish(() => done.complete(null));
    },
  );
}

/// The isolate's entry point: export, report, and exit with the result.
Future<void> _exportEntry((SendPort, ExportRequest) message) async {
  final (port, request) = message;
  try {
    final outcome = await buildExportDocument(
      request,
      onProgress: (sheetsDone, sheets) => port.send((sheetsDone, sheets)),
    );
    // `Isolate.exit` HANDS THE BYTES OVER rather than copying them.
    Isolate.exit(port, _ExportResult(outcome));
  } on Object catch (error, stack) {
    Isolate.exit(port, _ExportCrashed('$error', '$stack'));
  }
}

final class _ExportResult {
  const _ExportResult(this.outcome);

  final Outcome<ExportedDocument> outcome;
}

final class _ExportCrashed {
  const _ExportCrashed(this.error, this.stack);

  final String error;
  final String stack;
}
