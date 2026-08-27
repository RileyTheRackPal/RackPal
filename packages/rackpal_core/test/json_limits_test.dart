// Import hardening (docs/03-architecture.md §9.5).
//
// The depth scan's justification was CORRECTED against measurement. See
// json_limits.dart's header for the full account; the short version is
// that `jsonDecode` handles a million levels of nesting quite happily
// (measured), and the thing that actually breaks is `deepSortKeys` and
// `JsonEncoder` on the WRITE side, with a `StackOverflowError` at 10 000
// levels — an `Error`, so no `on Exception` guard in this package catches
// it, thrown from a `write()` that is documented as non-fallible.
//
// The guard therefore turns "your save mysteriously died an hour after
// you opened this file" into "that file is nested too deeply to be a
// RackPal project", at open time. `roundTripSurvivesTheCap` below is
// what pins that story down.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('scanMaxJsonDepth', () {
    test('flat values are depth 0', () {
      expect(scanMaxJsonDepth(_bytes('null')), 0);
      expect(scanMaxJsonDepth(_bytes('42')), 0);
      expect(scanMaxJsonDepth(_bytes('"hello"')), 0);
    });

    test('counts object and array nesting', () {
      expect(scanMaxJsonDepth(_bytes('{}')), 1);
      expect(scanMaxJsonDepth(_bytes('[]')), 1);
      expect(scanMaxJsonDepth(_bytes('{"a":{"b":{"c":1}}}')), 3);
      expect(scanMaxJsonDepth(_bytes('[[[[1]]]]')), 4);
      expect(scanMaxJsonDepth(_bytes('{"a":[{"b":[1]}]}')), 4);
    });

    test('reports the MAXIMUM, not the final, depth', () {
      // Two shallow siblings around one deep one.
      expect(scanMaxJsonDepth(_bytes('{"a":1,"b":{"c":{"d":1}},"e":2}')), 3);
    });

    // The whole reason the scan is hand-written rather than a naive
    // bracket count: a project name of "}}}}" is legal and common enough
    // (a Windows path, a note, a regex in a label) that miscounting it
    // would refuse real files.
    test('brackets INSIDE a string literal do not count', () {
      expect(scanMaxJsonDepth(_bytes('{"a":"{{{{{{"}')), 1);
      expect(scanMaxJsonDepth(_bytes('{"a":"}}}}}}"}')), 1);
      expect(scanMaxJsonDepth(_bytes('{"[":"]"}')), 1);
    });

    test('an ESCAPED quote does not end the string', () {
      // Without escape handling the scanner would think the string ended
      // at the \" and start counting the [[[ that follow.
      expect(scanMaxJsonDepth(_bytes(r'{"a":"he said \"[[[\" loudly"}')), 1);
    });

    test('an escaped BACKSLASH at the end of a string does not swallow '
        'the closing quote', () {
      // "c:\\" is a two-character value ending in one backslash. If the
      // scanner treated the second backslash as escaping the quote it
      // would run off into the rest of the document in string mode and
      // report depth 1 for everything after.
      expect(scanMaxJsonDepth(_bytes(r'{"p":"c:\\"}{"q":{"r":1}}')), 2);
    });

    test('multi-byte UTF-8 never masquerades as a bracket', () {
      // Every continuation byte has the high bit set, so no fragment of
      // an emoji or a CJK code point can equal 0x7B/0x5B/0x22/0x5C.
      const json = '{"name":"Café 日本 🎛️","nested":{"a":1}}';
      expect(scanMaxJsonDepth(_bytes(json)), 2);
      expect(jsonDecode(json), isA<Map<String, Object?>>());
    });

    test('stopAt short-circuits so a pathological file is cheap', () {
      final deep = _bytes('[' * 100000);
      expect(scanMaxJsonDepth(deep, stopAt: 65), 65);
    });

    test('unbalanced closers clamp at zero instead of going negative', () {
      // Malformed JSON is jsonDecode's problem to report; this function
      // must merely not let a stray `}` hide a subsequent real nesting.
      expect(scanMaxJsonDepth(_bytes('}}}{"a":{"b":1}}')), 2);
    });
  });

  group('checkJsonLimits', () {
    test('accepts an ordinary document', () {
      expect(
        checkJsonLimits(_bytes('{"a":{"b":[1,2,3]}}')),
        isA<Ok<void>>(),
      );
    });

    test('refuses a document over the byte cap, naming both numbers', () {
      final big = Uint8List(2048);
      final outcome = checkJsonLimits(
        big,
        limits: const JsonLimits(maxBytes: 1024),
      );
      expect(outcome, isA<Err<void>>());
      final error = (outcome as Err<void>).error;
      expect(error, isA<DocumentTooLargeError>());
      expect((error as DocumentTooLargeError).bytes, 2048);
      expect(error.limit, 1024);
    });

    test('the byte cap is checked BEFORE the depth scan', () {
      // An over-large file must not be scanned end to end first — the
      // point of the size cap is to refuse without touching the content.
      final big = Uint8List.fromList(utf8.encode('[' * 4096));
      final outcome = checkJsonLimits(
        big,
        limits: const JsonLimits(maxBytes: 16, maxDepth: 8),
      );
      expect((outcome as Err<void>).error, isA<DocumentTooLargeError>());
    });

    test('refuses a document over the depth cap', () {
      final outcome = checkJsonLimits(
        _bytes('[[[[[[[[[[1]]]]]]]]]]'),
        limits: const JsonLimits(maxDepth: 4),
      );
      expect(outcome, isA<Err<void>>());
      final error = (outcome as Err<void>).error;
      expect(error, isA<JsonTooDeeplyNestedError>());
      expect((error as JsonTooDeeplyNestedError).limit, 4);
      expect(error.depth, greaterThan(4));
    });

    test('accepts a document exactly AT the depth cap', () {
      expect(
        checkJsonLimits(
          _bytes('[[[[1]]]]'),
          limits: const JsonLimits(maxDepth: 4),
        ),
        isA<Ok<void>>(),
      );
    });

    test('the real format nests far below the shipped default', () {
      // Guards the constant against being tightened into a limit that
      // refuses real projects.
      expect(kMaxJsonDepth, greaterThanOrEqualTo(32));
      expect(kMaxDocumentBytes, greaterThanOrEqualTo(3 * 1024 * 1024));
    });
  });

  group('THE FAILURE THE DEPTH CAP ACTUALLY PREVENTS', () {
    // These three tests are the measurement, written down so nobody has
    // to take the header comment on faith — and so that a future Dart
    // release changing any of it fails here rather than in the field.

    test('jsonDecode itself survives absurd nesting — the parser is NOT '
        'the problem', () {
      final deep = '${'{"a":' * 100000}1${'}' * 100000}';
      expect(
        jsonDecode(deep),
        isA<Map<String, Object?>>(),
        reason:
            "Dart's JSON parser is iterative. If this ever starts "
            'throwing, the depth cap gains a second justification — but '
            'it does not have this one today.',
      );
    });

    test('...but deepSortKeys and JsonEncoder DO overflow, with an '
        'Error that `on Exception` cannot catch', () {
      final deep = jsonDecode('${'{"a":' * 20000}1${'}' * 20000}');

      var caughtAsException = false;
      var caughtAsError = false;
      try {
        jsonEncode(deep);
      } on Exception {
        caughtAsException = true;
        // Catching an Error is exactly what is under test: the point is
        // that this branch, and NOT the Exception one, is the one that
        // fires — which is why no `on Exception` guard in the
        // persistence layer can contain it.
        // ignore: avoid_catching_errors
      } on Error {
        caughtAsError = true;
      }

      expect(
        caughtAsException,
        isFalse,
        reason:
            'this is the crux: every `on Exception catch` guard in '
            'the persistence layer walks straight past it',
      );
      expect(
        caughtAsError,
        isTrue,
        reason:
            'StackOverflowError, thrown from inside a write() that '
            'is documented as non-fallible and catches nothing',
      );
    });

    test('so the cap refuses it at OPEN time, as a value', () {
      final bomb = _bytes('${'{"a":' * 100000}1${'}' * 100000}');
      final outcome = parseDocumentJsonTree(bomb);
      expect(outcome, isA<Err<JsonMap>>());
      expect(
        (outcome as Err<JsonMap>).error,
        isA<JsonTooDeeplyNestedError>(),
        reason:
            'one sentence the user can act on, an hour before the '
            'save that would otherwise have died',
      );
    });
  });

  group('parseDocumentJsonTree', () {
    test('100 000 nested arrays come back as an Err', () {
      final bomb = _bytes('${'[' * 100000}1${']' * 100000}');
      expect(
        (parseDocumentJsonTree(bomb) as Err<JsonMap>).error,
        isA<JsonTooDeeplyNestedError>(),
      );
    });

    test('an over-large file comes back as an Err', () {
      final outcome = parseDocumentJsonTree(
        Uint8List(4096),
        limits: const JsonLimits(maxBytes: 128),
      );
      expect(
        (outcome as Err<JsonMap>).error,
        isA<DocumentTooLargeError>(),
      );
    });

    test('the zip sniff still fires first', () {
      final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0]);
      expect(
        (parseDocumentJsonTree(zip) as Err<JsonMap>).error,
        isA<UnsupportedZipContainerError>(),
      );
    });

    test('malformed JSON is an Err, never a throw', () {
      expect(
        (parseDocumentJsonTree(_bytes('{ not json')) as Err<JsonMap>).error,
        isA<FormatException>(),
      );
    });

    test('a JSON array at the root is an Err (the envelope is an '
        'object)', () {
      expect(
        (parseDocumentJsonTree(_bytes('[1,2,3]')) as Err<JsonMap>).error,
        isA<FormatException>(),
      );
    });

    test('a valid envelope parses to a tree', () {
      final outcome = parseDocumentJsonTree(_bytes('{"generator":"X"}'));
      expect(outcome, isA<Ok<JsonMap>>());
      expect((outcome as Ok<JsonMap>).value['generator'], 'X');
    });
  });
}
