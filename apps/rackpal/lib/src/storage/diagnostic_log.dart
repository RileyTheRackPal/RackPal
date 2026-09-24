// The local diagnostic log (DR-194, canon §11.193, board `#939`).
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS EXISTS BEFORE M8
// ═════════════════════════════════════════════════════════════════════
// A release build reported nothing anywhere. `main.dart`'s fatal handler
// routes to `FlutterError.presentError`, a no-op in release, and
// `storage_log.dart`'s typed sink had no listener, so a tester's crash
// reached the author as a description. §9.9 schedules local-first crash
// reporting for M8; DR-194 pulls this local half forward because builds are
// already in the wild. M8 still owns the remote half, CR-096's redaction
// policy as a whole, and §9.9's exit clause.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT A RECORD MAY CONTAIN, WHICH IS THE WHOLE DESIGN
// ═════════════════════════════════════════════════════════════════════
// §12.4 forbids file paths, client names and site addresses in a log, and
// an exception's MESSAGE is exactly where they land: a `FileSystemException`
// names the file it failed on, and a project file is named after a client.
// So a fatal record is the error's TYPE and its stack FRAMES, never its
// message. Frames name code, not the user's files, and the one way a
// user-side path could reach a frame, a `file:` URI, is cut to its last
// segment. Storage records reuse `logStorageEvent`'s facts, which are typed
// `int`/`bool`/`Enum` and cannot carry a `String` at all.
//
// ═════════════════════════════════════════════════════════════════════
// CAPPED BY CONSTRUCTION, AND NEVER A SECOND CRASH
// ═════════════════════════════════════════════════════════════════════
// `FileStore` has no append, and a second path to `dart:io` would break
// `storage_layering_test.dart`'s RULE 1. So the log is the newest
// [DiagnosticLog.capBytes] of records held in memory, and every record
// rewrites the file whole through the store. It cannot grow past the cap,
// and there is no rotation to get wrong. The previous session's file is
// renamed aside on [DiagnosticLog.open], because the crash worth sending is
// usually the one that ENDED the last run.
//
// Nothing here throws. A log that cannot be written says nothing; it does
// not become the crash it was meant to record.
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/file_store.dart';

/// The folder under the data root that holds the log. `Help ▸ Open
/// diagnostics folder…` opens this (DR-194).
const String kDiagnosticsFolder = 'diagnostics';

/// This session's log.
const String kDiagnosticLogName = 'rackpal.log';

/// The last session's log, kept so the crash that ended it survives the
/// launch after it.
const String kPreviousDiagnosticLogName = 'rackpal.previous.log';

/// The most a log file may hold. Big enough for several hundred records,
/// small enough to attach to a message.
const int kDiagnosticLogCapBytes = 256 * 1024;

/// The most frames one fatal record keeps. The frames that locate a
/// defect are the top ones; the bottom forty of a deep stack are the
/// framework.
const int kDiagnosticFrameLimit = 40;

/// A size-capped local log of storage events and fatal errors.
final class DiagnosticLog {
  DiagnosticLog({
    required this.fs,
    required this.directory,
    required this.context,
    DateTime Function()? now,
    this.capBytes = kDiagnosticLogCapBytes,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final FileStore fs;

  /// The diagnostics folder, already joined under the data root.
  final String directory;
  final p.Context context;
  final int capBytes;
  final DateTime Function() _now;

  final Queue<String> _lines = Queue<String>();
  int _bytes = 0;
  Future<void> _tail = Future<void>.value();

  String get path => context.join(directory, kDiagnosticLogName);
  String get previousPath =>
      context.join(directory, kPreviousDiagnosticLogName);

  /// Completes when every record so far has reached the store, or failed
  /// to. For tests and for a shutdown that wants the last line on disk.
  Future<void> get idle => _tail;

  /// Makes the folder and moves the last session's log aside.
  ///
  /// Awaited before the sink is installed, so no record of this session
  /// can be renamed away as the previous one's.
  Future<void> open() async {
    try {
      await fs.createDirectory(directory);
      if (await fs.exists(path)) {
        if (await fs.exists(previousPath)) await fs.delete(previousPath);
        await fs.rename(path, previousPath);
      }
    } on Object {
      // A log that cannot open is no reason not to start.
    }
  }

  /// The `StorageLogSink` half: install with `setStorageLogSink(log.storage)`.
  void storage(String code, Map<String, Object> facts) {
    final parts = [
      for (final e in facts.entries) '${e.key}=${_fact(e.value)}',
    ];
    _record([
      '${_stamp()} storage $code${parts.isEmpty ? '' : ' ${parts.join(' ')}'}',
    ]);
  }

  /// An uncaught error, as its type and its frames and NEVER its message.
  void fatal(Object error, StackTrace stack) {
    _record([
      '${_stamp()} fatal ${error.runtimeType}',
      ...diagnosticFramesOf(stack),
    ]);
  }

  String _stamp() => _now().toIso8601String();

  static String _fact(Object value) => value is Enum ? value.name : '$value';

  void _record(List<String> lines) {
    for (final line in lines) {
      _lines.add(line);
      _bytes += _sizeOf(line);
    }
    // Oldest first, and never the record just written: a single record
    // larger than the cap is still worth more than an empty file.
    while (_bytes > capBytes && _lines.length > lines.length) {
      _bytes -= _sizeOf(_lines.removeFirst());
    }
    final bytes = Uint8List.fromList(utf8.encode('${_lines.join('\n')}\n'));
    _tail = _tail.then((_) async {
      try {
        await fs.writeBytes(path, bytes);
      } on Object {
        // See the header: a log that cannot write says nothing.
      }
    });
  }

  static int _sizeOf(String line) => utf8.encode(line).length + 1;
}

/// [stack]'s frames, trimmed to [kDiagnosticFrameLimit], each indented, with
/// any `file:` URI cut to its last segment.
///
/// A release build's frames name `package:` URIs, which are code. A `file:`
/// URI names a place on somebody's disk, and the part of it that is not the
/// file name is the part §12.4 is about.
List<String> diagnosticFramesOf(StackTrace stack) => [
  for (final line
      in const LineSplitter()
          .convert(stack.toString())
          .where((l) => l.trim().isNotEmpty)
          .take(kDiagnosticFrameLimit))
    '  ${line.trim().replaceAllMapped(_fileUri, (m) => 'file:…/${m[1]}')}',
];

/// `file:///C:/Users/…/lib/a.dart:12:5` keeps `a.dart:12:5`. The drive
/// letter's colon is matched on its own, because a colon anywhere else ends
/// the path and starts the line number.
final RegExp _fileUri = RegExp(
  r'file:///(?:[A-Za-z]:)?(?:[^\s:)]*[/\\])?([^\s:/\\)]+)',
);
