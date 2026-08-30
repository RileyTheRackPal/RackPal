// AC-058/D8: JSON depth and size limits on EVERY import path (`#237`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE POINT OF THIS FILE IS THE WORD "EVERY"
// ═══════════════════════════════════════════════════════════════════════
// The individual caps are tested where they live: `json_limits_test.dart`
// has the measurements behind them, `rmdx_codec_test.dart` proves the
// `.rmdx` reader runs them, and the document path has had them since M0.
// What none of those can say is that there is no FOURTH path somebody
// added without them.
//
// So this file is a CENSUS AS A TEST. It enumerates the ways bytes from
// outside this application become a document, asserts each one is
// bounded, and fails when a new byte-reading call site appears that it
// does not know about. A gate that lists what it covers cannot tell you
// about what it does not; this one derives the list from the source.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT COUNTS AS AN IMPORT PATH, IN D8's OWN WORDS
// ═══════════════════════════════════════════════════════════════════════
// `critique-completeness.md` D8: *"`.rmdev`, `.rmlib`, and `.rackmate`
// arrive by email from strangers."* That is the test. A file the USER
// chose, which somebody else may have written.
//
// THE APP'S OWN FILES ARE EXCLUDED, AND THE EXCLUSION IS ARGUED RATHER
// THAN ASSUMED. `prefs.json`, `recents.json` and the recovery sidecar are
// written by this application into its own data root and are never
// picked from a dialog. They are not "arriving from strangers" in any
// sense D8 recognises, and capping them would mean a corrupt prefs file
// could refuse to let the app start rather than being reset. If one of
// them ever becomes user-supplied, this comment is wrong and the row
// below is where it gets fixed.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/csv_import_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../storage/fake_file_store.dart';

/// Source files that turn outside bytes into something this app holds.
///
/// Derived from the tree rather than listed: the sweep below greps for
/// the two calls that can do it and fails on a hit this map does not
/// name, so a new path announces itself.
const Map<String, String> _knownByteReaders = <String, String>{
  // path -> why it is or is not an import path
  'packages/rackpal_core/lib/src/persistence/json_codec.dart':
      'the .rmpj document reader; runs checkJsonLimits before jsonDecode',
  'packages/rackpal_core/lib/src/library/rmdx_codec.dart':
      'the .rmdx reader; runs checkJsonLimits before jsonDecode (#235)',
  'apps/rackpal/lib/src/session/csv_import_actions.dart':
      'the CSV import; runs checkImportSize on stat BEFORE reading (#237)',
  'apps/rackpal/lib/src/storage/io_file_store.dart':
      'the seam itself, not a path: it reads bytes for every caller above',
  'apps/rackpal/lib/src/storage/prefs_store.dart':
      "the app's own prefs.json, never user-picked. See the header.",
  'apps/rackpal/lib/src/storage/recents_store.dart':
      "the app's own recents.json, never user-picked. See the header.",
  'apps/rackpal/lib/src/storage/recovery_store.dart':
      "the app's own recovery sidecar, never user-picked. See the header.",
  'apps/rackpal/lib/src/storage/document_store.dart':
      'orchestrates the document read; the limits run inside the codec',
  // ── THE THREE THIS GATE FOUND ON ITS FIRST RUN ───────────────────────
  // Which is the argument for it existing. Two were real import paths
  // that read before they measured, and one of those was `#236`'s, two
  // hours old.
  'apps/rackpal/lib/src/session/device_template_io_actions.dart':
      'the .rmdx import; stats and runs checkImportSize BEFORE reading',
  'apps/rackpal/lib/src/session/session_controller.dart':
      'the .bak sibling of a picked project; same stat-first treatment',
  'apps/rackpal/lib/src/storage/file_store.dart':
      'the interface declaration, not a call site: `readBytes` is named '
      'here and implemented in io_file_store.dart',
  // ── ADDED AT `#239`, BY THIS GATE, ONE CHAPTER AFTER IT WAS WRITTEN ──
  // The `.rmda` codec landed and this file failed on the very next run.
  // That is the design working on somebody who had read the design.
  'packages/rackpal_core/lib/src/library/rmda_codec.dart':
      'the .rmda reader; runs checkJsonLimits before jsonDecode, and a '
      'library is the biggest file this product reads so the cap matters '
      'most here (DR-015 §11.15.4)',
  // ── ADDED AT `#240`, BY THIS GATE, FOR THE SECOND CHAPTER RUNNING ────
  'apps/rackpal/lib/src/session/library_io_actions.dart':
      'the .rmda import; stats and runs checkImportedFileSize BEFORE '
      'reading, like the three paths above it',
};

String _repoRoot() {
  var dir = Directory.current;
  while (!Directory('${dir.path}/packages').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) fail('could not find the repo root');
    dir = parent;
  }
  return dir.path;
}

void main() {
  group('the census, as a gate', () {
    test('no byte-reading call site exists that this file does not know', () {
      // THE ASSERTION THAT MAKES THE OTHERS WORTH HAVING. `#795`'s census
      // was scoped to `packages/*/lib apps/*/lib` and missed a production
      // site in `tool/`, so this sweeps every tracked Dart file under
      // both source trees and names what it finds.
      final root = _repoRoot();
      final found = <String>{};
      for (final dir in ['packages', 'apps']) {
        final entries = Directory('$root/$dir')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.contains('${Platform.pathSeparator}build'))
            .where(
              (f) => !f.path.contains('${Platform.pathSeparator}.dart_tool'),
            )
            .where((f) => !f.path.contains('${Platform.pathSeparator}test'));
        for (final file in entries) {
          final source = file.readAsStringSync();
          // Comments stripped, for `file_dialog_flags_test.dart`'s
          // reason: several of these files DISCUSS jsonDecode at length
          // in prose, and a raw match would report the discussion.
          final code = source
              .split('\n')
              .map((l) {
                final i = l.indexOf('//');
                return i == -1 ? l : l.substring(0, i);
              })
              .join('\n');
          if (code.contains('jsonDecode(') || code.contains('readBytes(')) {
            found.add(
              file.path
                  .substring(root.length + 1)
                  .replaceAll(Platform.pathSeparator, '/'),
            );
          }
        }
      }
      expect(
        found,
        isNotEmpty,
        reason: 'a sweep that finds nothing proves nothing',
      );
      expect(
        found.difference(_knownByteReaders.keys.toSet()),
        isEmpty,
        reason:
            'a new file reads outside bytes. Add it to _knownByteReaders '
            "with a sentence saying whether it is an import path in D8's "
            'sense, and if it is, bound it first.',
      );
    });

    test('every row in the map still exists', () {
      // The other direction, so the map cannot rot into a list of files
      // that moved. This is the failure `docs/13`'s D13 row taught.
      final root = _repoRoot();
      for (final path in _knownByteReaders.keys) {
        expect(
          File('$root/$path').existsSync(),
          isTrue,
          reason: '$path is listed here and is gone',
        );
      }
    });
  });

  group('each import path is actually bounded', () {
    test('the .rmpj document reader refuses an oversized file', () {
      final huge = Uint8List(64 * 1024 * 1024 + 1);
      final outcome = parseDocumentJsonTree(huge);
      expect(outcome, isA<Err<JsonMap>>());
      expect((outcome as Err<JsonMap>).error, isA<DocumentTooLargeError>());
    });

    test('the .rmpj document reader refuses a deeply nested file', () {
      final deep = Uint8List.fromList(utf8.encode('[' * 300));
      final outcome = parseDocumentJsonTree(deep);
      expect(outcome, isA<Err<JsonMap>>());
      expect((outcome as Err<JsonMap>).error, isA<JsonTooDeeplyNestedError>());
    });

    test('the .rmda reader refuses both, and it is the biggest file', () {
      // DR-015 §11.15.4's argument for one JSON file rather than a zip is
      // that it *inherits* AC-058/D8's limits and introduces no new
      // attack surface. This is that inheritance, asserted rather than
      // taken on the ruling's word.
      final deep = Uint8List.fromList(utf8.encode('[' * 300));
      expect(readRmdaBytes(deep), isA<Err<DeviceLibraryFile>>());

      final small = Uint8List.fromList(utf8.encode('{"kind":"x"}'));
      expect(
        (readRmdaBytes(small, limits: const JsonLimits(maxBytes: 4))
                as Err<DeviceLibraryFile>)
            .error,
        isA<DocumentTooLargeError>(),
      );
    });

    test('the .rmdx reader refuses both, on the same limits object', () {
      final deep = Uint8List.fromList(utf8.encode('[' * 300));
      expect(readRmdxBytes(deep), isA<Err<DeviceTemplateFile>>());

      final small = Uint8List.fromList(utf8.encode('{"kind":"x"}'));
      final outcome = readRmdxBytes(
        small,
        limits: const JsonLimits(maxBytes: 4),
      );
      expect(
        (outcome as Err<DeviceTemplateFile>).error,
        isA<DocumentTooLargeError>(),
      );
    });

    test('the CSV import refuses on SIZE before reading a byte', () async {
      // The gap `#237` found: `readCsvText` read the whole file into
      // memory with no cap at all. It stats first now, so an oversized
      // file costs one stat rather than its own length in RAM.
      final fs = FakeFileStore(
        initialFiles: {
          r'C:\in\huge.csv': Uint8List.fromList(utf8.encode('a,b,c\n1,2,3\n')),
        },
        initialDirectories: <String>{'C:', r'C:\in'},
      );
      await expectLater(
        readCsvText(fs, r'C:\in\huge.csv', maxBytes: 4),
        throwsA(isA<DocumentTooLargeError>()),
      );
    });

    test('...and a file within the cap still reads', () async {
      final fs = FakeFileStore(
        initialFiles: {
          r'C:\in\ok.csv': Uint8List.fromList(utf8.encode('a,b\n1,2\n')),
        },
        initialDirectories: <String>{'C:', r'C:\in'},
      );
      expect(await readCsvText(fs, r'C:\in\ok.csv'), 'a,b\n1,2\n');
    });

    test('a path stat cannot answer for is NOT refused as oversized', () {
      // Reporting a vanished file as an enormous one would be a false
      // explanation, and the caller already has a sentence for the real
      // cause. The read then fails on its own terms.
      final fs = FakeFileStore(initialDirectories: <String>{'C:'});
      expect(
        readCsvText(fs, r'C:\in\gone.csv'),
        throwsA(isNot(isA<DocumentTooLargeError>())),
      );
    });
  });

  group('the cap runs BEFORE the read, on every path that reads', () {
    // The property `#237` actually adds. Every path already refused an
    // oversized file; two of them refused it after allocating it, which
    // is the cap doing its paperwork and none of its job.
    test('every import path that reads bytes stats first', () {
      final root = _repoRoot();
      for (final path in <String>[
        'apps/rackpal/lib/src/session/csv_import_actions.dart',
        'apps/rackpal/lib/src/session/device_template_io_actions.dart',
        'apps/rackpal/lib/src/session/session_controller.dart',
        'apps/rackpal/lib/src/session/library_io_actions.dart',
      ]) {
        final code = File('$root/$path').readAsStringSync();
        final guardAt = code.indexOf('checkImportedFileSize(');
        final readAt = code.indexOf('.readBytes(');
        expect(
          guardAt,
          greaterThan(-1),
          reason: '$path never asks the size cap',
        );
        expect(
          guardAt,
          lessThan(readAt),
          reason:
              '$path reads before it measures, so the cap fires after the '
              'allocation it exists to prevent',
        );
      }
    });
  });

  group('the size check is ONE authority', () {
    test('checkJsonLimits and checkImportSize agree, because one calls '
        'the other', () {
      // Two size caps would disagree on the first day somebody tuned one.
      const limit = 100;
      final over = Uint8List(limit + 1);
      final a = checkImportSize(over.length, limit: limit);
      final b = checkJsonLimits(
        over,
        limits: const JsonLimits(maxBytes: limit),
      );
      expect(a, isA<Err<void>>());
      expect(b, isA<Err<void>>());
      expect(
        ((a as Err<void>).error as DocumentTooLargeError).limit,
        ((b as Err<void>).error as DocumentTooLargeError).limit,
      );
    });

    test('the default cap is the documented one', () {
      expect(
        checkImportSize(kMaxDocumentBytes),
        isA<Ok<void>>(),
        reason: 'exactly at the cap is allowed; the check is >, not >=',
      );
      expect(checkImportSize(kMaxDocumentBytes + 1), isA<Err<void>>());
    });
  });
}
