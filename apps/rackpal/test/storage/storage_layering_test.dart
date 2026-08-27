// SOURCE-LEVEL GATES. The same pattern as the existing `no_print_test`
// and `no_flutter_import_test`: some rules are cheaper to enforce with a
// grep than to remember, and a rule nobody enforces is a rule that lasts
// until the first hurried afternoon.
//
// Seven rules, each with a stated consequence:
//
//  1. `dart:io` appears in exactly two files, both named here. Everything
//     above them is testable without a disk BECAUSE it cannot reach one.
//  2. `getApplicationSupportDirectory` appears in exactly ONE file. That
//     single call site is the whole reason M2's portable build is a
//     one-function change instead of a five-store retrofit.
//  3. The recovery directory is NAMED in exactly one file (CR-096). A
//     recovery file is a complete project containing the client's name
//     and site address; no future diagnostics path may reach one by
//     accident.
//  4. Nothing in the storage tests sleeps. `Future.delayed` in a test
//     here means either a real wall-clock wait or a race waiting to be
//     flaky, and every duration in this layer is already injected.
//  5. No print()/debugPrint() in this layer — the one place a storage
//     failure tempts a quick print of a path, which is also a §12.4
//     redaction violation.
//  6. No storage log call passes a String fact, for the same reason.
//  7. The real filesystem's write path really does fsync. Durability is
//     the one part of the FileStore contract a unit test cannot observe,
//     so it is held here — as a grep, labelled as one.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _libStorage = 'lib/src/storage';
const _testStorage = 'test/storage';

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  return withoutBlocks
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');
}

List<File> _dartFilesUnder(String path) {
  final dir = Directory(path);
  expect(
    dir.existsSync(),
    isTrue,
    reason: 'run from the app root; $path must exist',
  );
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

String _basename(File f) => f.path.split(Platform.pathSeparator).last;

void main() {
  test('RULE 1 — dart:io appears only in the two files allowed to have '
      'it', () {
    // io_file_store.dart is the single filesystem implementation.
    // data_root.dart needs `Platform.resolvedExecutable` for the portable
    // marker check, and nothing else — its decision logic is pure and
    // fully unit-tested.
    const allowed = {'io_file_store.dart', 'data_root.dart'};

    final offenders = <String>[];
    var scanned = 0;
    for (final file in _dartFilesUnder('lib')) {
      scanned++;
      final source = _stripComments(file.readAsStringSync());
      if (!RegExp('''['"]dart:io['"]''').hasMatch(source)) continue;
      if (!allowed.contains(_basename(file))) {
        offenders.add(file.path);
      }
    }

    expect(scanned, greaterThan(5), reason: 'a vacuous scan proves nothing');
    expect(
      offenders,
      isEmpty,
      reason:
          'dart:io outside the seam:\n${offenders.join('\n')}\n'
          'Everything above FileStore is testable without a disk only '
          'because it cannot reach one.',
    );
  });

  test('RULE 1b — File( and Directory( are constructed in exactly one '
      'file', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      if (_basename(file) == 'io_file_store.dart') continue;
      final source = _stripComments(file.readAsStringSync());
      for (final pattern in [
        RegExp(r'(?<![\w.$])File\s*\('),
        RegExp(r'(?<![\w.$])Directory\s*\('),
        RegExp(r'(?<![\w.$])FileStat\.'),
      ]) {
        if (pattern.hasMatch(source)) {
          offenders.add('${file.path}: ${pattern.pattern}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('RULE 2 — the application-support lookup is called from exactly '
      'ONE file', () {
    final callers = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final source = _stripComments(file.readAsStringSync());
      if (source.contains('getApplicationSupportPath') ||
          source.contains('getApplicationSupportDirectory')) {
        callers.add(_basename(file));
      }
    }

    expect(
      callers,
      ['data_root.dart'],
      reason:
          'THIS ASSERTION IS THE PORTABLE-BUILD RETROFIT GUARD. Every '
          'store takes its root as a constructor argument; the moment a '
          'second file looks the directory up for itself, M2 stops being '
          'a one-function change.',
    );
  });

  test('RULE 2b — the path-provider package is imported by exactly one '
      'file', () {
    final importers = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final source = _stripComments(file.readAsStringSync());
      if (RegExp('package:path_provider[_a-z]*/').hasMatch(source)) {
        importers.add(_basename(file));
      }
    }
    expect(importers, ['data_root.dart']);
  });

  test('RULE 3 — CR-096: the recovery directory is NAMED in exactly one '
      'file', () {
    // A recovery file is a COMPLETE PROJECT containing the client's name
    // and site address. Making it structurally unreachable from a
    // diagnostics path is cheaper than remembering not to attach it.
    final namers = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final source = _stripComments(file.readAsStringSync());
      if (RegExp("'recovery'").hasMatch(source) ||
          source.contains('kRecoveryDirName =')) {
        namers.add(_basename(file));
      }
    }
    expect(
      namers,
      ['recovery_store.dart'],
      reason:
          'the recovery directory must be reachable only through '
          'RecoveryStore, which exposes scan/write/delete and NO '
          'bulk-read or bundle method — the second clause is the CR-096 '
          'group in recovery_store_test.dart, which inventories that '
          'API; this rule only closes the directory-name half',
    );
  });

  test('RULE 4 — nothing in the storage tests sleeps', () {
    // Every duration in this layer is injected: the promote backoff, the
    // recents probe timeout, the clock. A `Future.delayed` in a test here
    // is either a real wall-clock wait or a race, and both get worse as
    // the suite grows.
    final offenders = <String>[];
    var scanned = 0;
    for (final file in _dartFilesUnder(_testStorage)) {
      scanned++;
      final lines = _stripComments(file.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'Future\.delayed|sleep\s*\(').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(scanned, greaterThan(5));
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('RULE 5 — the storage layer does not reach for print()', () {
    // The sibling of the existing no_print gates, scoped to this layer's
    // strongest temptation: a storage failure is exactly the moment
    // someone reaches for a quick print of the path — which is also a
    // §12.4 redaction violation.
    final offenders = <String>[];
    for (final file in _dartFilesUnder(_libStorage)) {
      final lines = _stripComments(file.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'(?<![\w.$])(print|debugPrint)\s*\(').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('RULE 7 — the document write path really does fsync', () {
    // A GREP, AND LABELLED AS ONE. Durability is the single part of the
    // FileStore contract that cannot be observed from a unit test:
    // nothing short of cutting power distinguishes "the bytes are in the
    // page cache" from "the bytes are on the platter", so
    // file_store_contract_test.dart pins everything else and is silent
    // here.
    //
    // What IS proven mechanically is the ORDERING — the crash suite
    // replays every journal prefix under power-loss semantics and fails
    // if the commit does not precede the promote. That proof rests on one
    // premise the model cannot check for itself: that `FileSink.flush()`
    // and `FileStore.copy()` really commit in the REAL implementation.
    // This rule is that premise, held at the only level available.
    //
    // The specific regression it guards is the one that was there:
    // `File.openWrite()` returns an `IOSink` whose `flush()` waits for
    // `write(2)` and never calls `FlushFileBuffers`. Reaching for it
    // again is the natural simplification, and it silently un-does the
    // whole durability story.
    final source = _stripComments(
      File('$_libStorage/io_file_store.dart').readAsStringSync(),
    );

    expect(
      source,
      isNot(contains('openWrite()')),
      reason:
          '`File.openWrite()` gives an IOSink, and IOSink.flush() is '
          'NOT an fsync — it waits for write(2) and stops. The promote that '
          'follows is journalled while the data extents are not, which is '
          'a torn file at the name the user knows.',
    );
    expect(
      source,
      contains('RandomAccessFile'),
      reason: 'the sink must own a handle it can actually flush',
    );

    // THE THREE COMMIT POINTS, each named exactly, so DELETING one fails
    // here. Measured limit of the technique, stated rather than glossed:
    // a grep sees the call, not the semantics. Someone who wraps
    // `await _commit(to);` in a condition that is usually false slips
    // past this rule, and no test in the tree catches that — a mutation
    // that SURVIVED and is reported as surviving. Only a power cut
    // distinguishes the two, and nothing in a unit test can arrange one.
    expect(
      // COUNTED, not merely present: there are exactly two handles that
      // must be flushed — the streaming sink's (the document write path,
      // the highest-stakes write in the app, and the one whose torn
      // result the user meets as "the file appears to be damaged") and
      // `_commit`'s. A `contains` would let either one be deleted while
      // the other kept the assertion green.
      RegExp(r'await handle\.flush\(\);').allMatches(source).length,
      2,
      reason:
          'both durability points must survive: the streaming sink, and '
          'the commit that keeps the backup copy whole',
    );
    expect(
      source,
      contains('await _commit(to);'),
      reason:
          'the copy that produces `.bak.tmp` is renamed to `.bak` moments '
          'later; an uncommitted copy plus a journalled rename is a TORN '
          'BACKUP, and one that happens to parse as valid JSON is a '
          'silent corruption vector (I2)',
    );
    expect(
      source,
      contains('flush: true'),
      reason: 'writeBytes commits via writeAsBytes(flush: true)',
    );
    expect(source, contains('writeAsBytes'));
  });

  test('RULE 6 — §12.4: no storage log call passes a String fact', () {
    // Enforced by the signature at runtime too (`logStorageEvent`'s
    // assert), but a grep catches it at review time, before a client's
    // name has ever reached a log file on a real machine.
    final offenders = <String>[];
    for (final file in _dartFilesUnder(_libStorage)) {
      final source = _stripComments(file.readAsStringSync());
      for (final call in RegExp(
        r'logStorageEvent\s*\([^;]*?\)\s*;',
        dotAll: true,
      ).allMatches(source)) {
        final text = call[0]!;
        // Everything after the event-code argument.
        final afterCode = text.indexOf(',');
        if (afterCode == -1) continue;
        final args = text.substring(afterCode);
        // A quoted string in VALUE position: `: 'something'`.
        if (RegExp(r""":\s*['"]""").hasMatch(args)) {
          offenders.add('${file.path}: $text');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a String fact is how a client name or a site address '
          'reaches a log file:\n${offenders.join('\n')}',
    );
  });
}
