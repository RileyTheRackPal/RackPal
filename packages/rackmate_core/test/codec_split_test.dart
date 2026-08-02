// The split codec pipeline (json_codec.dart): `write` == the composition
// of `encodeToJsonTree` + `encodeJsonTreeBytes`, and `read` == the
// composition of `parseDocumentJsonTree` + `readFromJsonTree`.
//
// WHY THIS TEST EXISTS AS WELL AS byte_roundtrip_test.dart. That suite
// guards CR-117 through `write`/`read`. The app's save path does NOT call
// `write` — it calls the two halves, because only the split lets it
// snapshot on the main isolate and encode in `Isolate.run`. If the halves
// ever drift from the whole, the golden corpus keeps passing while every
// file the app actually writes is wrong. So the equivalence is asserted
// directly, over the same on-disk fixtures the corpus uses.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

const _fixtures = <String>[
  'a_empty_project',
  'b_rack_and_device',
  'c_fuller_project',
  'd_templates_and_power',
];

Uint8List _readFixture(String label) =>
    File('test/fixtures/$label.rmpj.json').readAsBytesSync();

void main() {
  group('the halves compose back into the whole, byte for byte', () {
    for (final label in _fixtures) {
      test(label, () {
        final bytes = _readFixture(label);

        final viaWhole = _codec.read(bytes);
        expect(viaWhole, isA<Ok<RackDocument>>());
        final doc = (viaWhole as Ok<RackDocument>).value;

        // read: parse then decode.
        final tree = parseDocumentJsonTree(bytes);
        expect(tree, isA<Ok<JsonMap>>());
        final viaHalves = readFromJsonTree((tree as Ok<JsonMap>).value);
        expect(viaHalves, isA<Ok<RackDocument>>());

        // write: snapshot then encode.
        final wholeBytes = _codec.write(doc);
        final halfBytes = encodeJsonTreeBytes(_codec.encodeToJsonTree(doc));

        expect(halfBytes, equals(wholeBytes));
        // ...and both still satisfy CR-117 against the source file.
        expect(halfBytes, equals(bytes));
      });
    }
  });

  test('encodeToJsonTree yields PLAIN data only — nothing that would '
      'fail to cross an isolate boundary', () {
    final doc =
        (_codec.read(_readFixture('c_fuller_project')) as Ok<RackDocument>)
            .value;
    final tree = _codec.encodeToJsonTree(doc);

    // Walk the whole tree and assert every leaf is one of the five JSON
    // primitives. A `Uuid`, a `Len` or a `DateTime` surviving into the
    // tree is the failure this guards: it would encode fine here (via
    // toString) but is exactly the sort of value whose isolate-transfer
    // behaviour is not a property anyone verified.
    final offenders = <String>[];
    void walk(Object? value, String path) {
      if (value == null ||
          value is String ||
          value is int ||
          value is bool ||
          value is double) {
        return;
      }
      if (value is Map) {
        for (final e in value.entries) {
          if (e.key is! String) offenders.add('$path: non-String key ${e.key}');
          walk(e.value, '$path.${e.key}');
        }
        return;
      }
      if (value is List) {
        for (var i = 0; i < value.length; i++) {
          walk(value[i], '$path[$i]');
        }
        return;
      }
      offenders.add('$path: ${value.runtimeType}');
    }

    walk(tree, r'$');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('encodeJsonTreeBytes is a pure top-level function — the same tree '
      'twice gives identical bytes', () {
    final doc =
        (_codec.read(_readFixture('d_templates_and_power')) as Ok<RackDocument>)
            .value;
    final tree = _codec.encodeToJsonTree(doc);
    expect(encodeJsonTreeBytes(tree), equals(encodeJsonTreeBytes(tree)));
  });

  group('readFromJsonTree surfaces the §9.2 migration outcomes', () {
    JsonMap envelope({
      required int schemaVersion,
      required int minReaderVersion,
      String generator = 'RackMate',
    }) => <String, Object?>{
      'generator': generator,
      'schemaVersion': schemaVersion,
      'minReaderVersion': minReaderVersion,
      'document': <String, Object?>{},
    };

    test('minReaderVersion > kSchemaVersion refuses with '
        'NewerSchemaError', () {
      final outcome = readFromJsonTree(
        envelope(
          schemaVersion: kSchemaVersion + 1,
          minReaderVersion: kSchemaVersion + 1,
        ),
      );
      expect(
        (outcome as Err<RackDocument>).error,
        isA<NewerSchemaError>(),
      );
    });

    test('a foreign generator is NotARackMateFileError, not a crash', () {
      final outcome = readFromJsonTree(
        envelope(
          schemaVersion: 2,
          minReaderVersion: 2,
          generator: 'SomeOtherApp',
        ),
      );
      expect(
        (outcome as Err<RackDocument>).error,
        isA<NotARackMateFileError>(),
      );
    });

    test('a structurally broken envelope is an Err, never a throw', () {
      final outcome = readFromJsonTree(<String, Object?>{
        'generator': 'RackMate',
        'schemaVersion': 2,
        'minReaderVersion': 2,
        // no "document" wrapper at all
      });
      expect(outcome, isA<Err<RackDocument>>());
    });
  });

  test('a newer schemaVersion this build still satisfies opens '
      'READ-ONLY with unknown fields preserved', () {
    final bytes = _readFixture('a_empty_project');
    final root = jsonDecode(utf8.decode(bytes))! as Map<String, Object?>
      ..['schemaVersion'] = kSchemaVersion + 1
      ..['unknown'] = <String, Object?>{'futureKey': 'kept'};

    final outcome = readFromJsonTree(root);
    expect(outcome, isA<Ok<RackDocument>>());
    final ok = outcome as Ok<RackDocument>;
    expect(ok.openReadOnly, isTrue);
    expect(ok.value.unknown['futureKey'], 'kept');

    // The Save-As copy must carry the newer data forward intact.
    final rewritten = utf8.decode(_codec.write(ok.value));
    expect(rewritten, contains('futureKey'));
  });

  group('THE VERSION STAMP DESCRIBES THE BYTES, NOT THEIR SOURCE', () {
    // The failure this group exists to make impossible: a Save As from a
    // read-only newer-schema document producing a LOSSY file STAMPED WITH
    // THE NEWER VERSION. That is the worst possible combination, because
    // the stamp is exactly what the next reader trusts when it decides
    // whether to migrate and whether to gate.

    RackDocument openStampedAt(int schemaVersion, int minReaderVersion) {
      final root =
          jsonDecode(utf8.decode(_readFixture('b_rack_and_device')))!
              as Map<String, Object?>
            ..['schemaVersion'] = schemaVersion
            ..['minReaderVersion'] = minReaderVersion;
      final outcome = readFromJsonTree(root);
      expect(
        outcome,
        isA<Ok<RackDocument>>(),
        reason: 'v$schemaVersion/min$minReaderVersion should still open',
      );
      return (outcome as Ok<RackDocument>).value;
    }

    JsonMap rootOf(Uint8List bytes) =>
        jsonDecode(utf8.decode(bytes))! as Map<String, Object?>;

    test('a copy of a NEWER, read-only document is stamped with THIS '
        "build's version, not the one it was read at", () {
      // A future build wrote v(k+1) with fields this build has no class
      // member for. `_decodeRackDocument` dropped them on the way in; the
      // one thing the copy must not do is claim to still be v(k+1).
      final doc = openStampedAt(kSchemaVersion + 1, kMinReaderVersion);
      expect(
        doc.schemaVersion,
        kSchemaVersion + 1,
        reason: 'the DOCUMENT still remembers what it was read at',
      );

      final root = rootOf(_codec.write(doc));

      expect(
        root['schemaVersion'],
        kSchemaVersion,
        reason:
            'the file advertises v${kSchemaVersion + 1} while holding only '
            'v$kSchemaVersion data — the newer build then sees its own '
            'version, runs no migration, applies no read-only gate, and '
            'trusts a document whose newer fields are gone',
      );
      expect(root['minReaderVersion'], kMinReaderVersion);
    });

    test('a file that under-declares its reader requirement is re-stamped '
        'honestly', () {
      // schemaVersion is already current so no migration runs and nothing
      // re-stamps `minReaderVersion` on the way in. Re-emitting the stored
      // 1 would promise a v1 reader it can open bytes that make it throw.
      final doc = openStampedAt(kSchemaVersion, 1);
      expect(doc.minReaderVersion, 1);

      expect(rootOf(_codec.write(doc))['minReaderVersion'], kMinReaderVersion);
    });

    test('the stamp survives the split pipeline identically', () {
      // The app never calls `write`; it calls the two halves. A stamp that
      // was only correct in the composition would be wrong in every file
      // the app actually writes.
      final doc = openStampedAt(kSchemaVersion + 1, kMinReaderVersion);
      final halves = rootOf(encodeJsonTreeBytes(_codec.encodeToJsonTree(doc)));
      expect(halves['schemaVersion'], kSchemaVersion);
      expect(halves['minReaderVersion'], kMinReaderVersion);
    });

    test('and the copy therefore reopens WITHOUT the read-only gate', () {
      // The end-to-end consequence: the copy is a genuine, current-version
      // document, so Ctrl+S over it is honest rather than a second lossy
      // rewrite of a file claiming to be something it is not.
      final doc = openStampedAt(kSchemaVersion + 1, kMinReaderVersion);
      final reread = _codec.read(_codec.write(doc));
      expect(reread, isA<Ok<RackDocument>>());
      expect((reread as Ok<RackDocument>).openReadOnly, isFalse);
      expect(reread.value.schemaVersion, kSchemaVersion);
    });
  });
}
