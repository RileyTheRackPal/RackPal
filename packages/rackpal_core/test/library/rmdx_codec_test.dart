// DR-100 §11.99: a `.rmdx` carries the body FLAT, and these are the
// assertions that make that checkable rather than merely written down.
//
// ==================================================================
// THE ONE THAT MATTERS IS THE 48-TEMPLATE SWEEP
// ==================================================================
// The defect DR-100 exists to prevent is SILENT and has no symptom at
// write time: a key that no part of the file layout claims does not
// throw, does not warn and does not fail to encode. It simply is not in
// the file, and the person who finds out is the one whose emailed
// template came back missing its model number.
//
// docs/06 §7.3's `identity.`/`physical.`/`power.` sections placed 18 of
// the encoder's 39 keys, so a codec built from that example would have
// dropped 21 of them, `model` among them. Nothing in a hand-written
// fixture catches that, because a fixture asserts the fields somebody
// thought of. **The sweep asserts the fields nobody thought of**: every
// seeded template, encoded to bytes, read back, re-encoded, compared
// BYTE for byte.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

DeviceTemplateFile _file(
  TemplateBody body, {
  String id = 'A01',
  int version = 1,
  String contentHash = 'unhashed:A01@1',
}) => DeviceTemplateFile(
  templateId: TemplateId(id),
  version: version,
  contentHash: contentHash,
  body: body,
);

TemplateBody _seed(String id) {
  final body = buildSeedCatalog()[id];
  expect(body, isNotNull, reason: 'seed id $id no longer ships');
  return body!;
}

/// The `Ok` value, or a failure naming the error.
DeviceTemplateFile _readOk(Uint8List bytes) {
  final outcome = readRmdxBytes(bytes);
  switch (outcome) {
    case Ok(:final value):
      return value;
    case Err(:final error):
      fail('expected Ok, got Err($error)');
  }
}

Object _readErr(Outcome<DeviceTemplateFile> outcome) {
  switch (outcome) {
    case Ok():
      fail('expected Err, got Ok');
    case Err(:final error):
      return error;
  }
}

void main() {
  group('DR-100: the body is flat and nothing is lost', () {
    test('every seeded template survives a file round trip, byte for byte', () {
      final catalog = buildSeedCatalog();
      expect(
        catalog.length,
        greaterThan(40),
        reason:
            'a sweep over an empty or truncated catalog passes vacuously. '
            'This is the same non-vacuity guard the suite floors are',
      );
      for (final entry in catalog.entries) {
        final first = encodeRmdxBytes(_file(entry.value, id: entry.key));
        final second = encodeRmdxBytes(_readOk(first));
        expect(
          second,
          first,
          reason:
              'template ${entry.key} does not survive .rmdx. A key the '
              'file layout fails to claim is a key the file silently '
              'drops, which is the whole of DR-100',
        );
      }
    });

    test("the body in the file is the encoder's own map, key for key", () {
      // THE ASSERTION THAT WOULD HAVE FAILED ON THE SECTIONED LAYOUT.
      // 39 keys go in; a partition that claimed 18 of them would put 18
      // here and this would name the 21 it dropped.
      final body = _seed(buildSeedCatalog().keys.first);
      final tree = rmdxToJsonTree(_file(body));
      final flat = templateBodyToJson(body);
      expect(
        (tree['body']! as Map).keys.toSet(),
        flat.keys.toSet(),
        reason: 'the file body IS templateBodyToJson, not a projection of it',
      );
    });

    test('`model` specifically survives, and it is named for a reason', () {
      // docs/06 §7.3's worked example omits `model` from `identity`. It
      // is a required constructor parameter, always encoded, and DR-056
      // keeps it UNDEFAULTED so it prints as an unknown. docs/17's
      // clause-2 drill goes looking for exactly this cell, so a codec
      // that dropped it would refute a drill about a defect it caused.
      final body = _seed(buildSeedCatalog().keys.first);
      final read = _readOk(encodeRmdxBytes(_file(body)));
      expect(read.body.model, body.model);
      expect(
        templateBodyToJson(read.body)['model'],
        isNotNull,
        reason: 'present in the file even when it is the empty string',
      );
    });

    test('the envelope carries SIX keys and no more', () {
      // Catches the other direction: a field hoisted OUT of the body and
      // onto the envelope gives one fact two homes. `derivedFrom` is the
      // live temptation, since docs/06 §7.3 drew it at the top level.
      final tree = rmdxToJsonTree(_file(_seed(buildSeedCatalog().keys.first)));
      expect(tree.keys.toSet(), {
        'schemaVersion',
        'kind',
        'templateId',
        'version',
        'contentHash',
        'body',
      });
    });

    test('derivedFrom lives INSIDE body, where the encoder puts it', () {
      final origin = _seed(buildSeedCatalog().keys.first);
      final forked = copyTemplateBody(origin)
        ..derivedFrom = const TemplateOrigin(
          templateId: TemplateId('SRC'),
          version: 2,
        );
      final tree = rmdxToJsonTree(_file(forked));
      expect(tree['derivedFrom'], isNull, reason: 'never on the envelope');
      expect((tree['body']! as Map)['derivedFrom'], isNotNull);
      final read = _readOk(encodeRmdxBytes(_file(forked)));
      expect(read.body.derivedFrom?.templateId.v, 'SRC');
      expect(read.body.derivedFrom?.version, 2);
    });
  });

  group('the bytes are the canonical shape docs/06 §7.3 requires', () {
    late Uint8List bytes;
    setUp(() {
      bytes = encodeRmdxBytes(_file(_seed(buildSeedCatalog().keys.first)));
    });

    test('UTF-8, LF only, two-space indent', () {
      final text = utf8.decode(bytes);
      expect(text, isNot(contains('\r')), reason: 'LF, never CRLF');
      expect(
        text.split('\n')[1],
        startsWith('  "'),
        reason: 'two-space indent at the first nesting level',
      );
    });

    test('keys are sorted at every level', () {
      final text = utf8.decode(bytes);
      // Root order proves the sort ran at all; `body` proves it recursed.
      final root = jsonDecode(text) as Map<String, Object?>;
      expect(root.keys.toList(), List.of(root.keys)..sort());
      final body = root['body']! as Map<String, Object?>;
      expect(body.keys.toList(), List.of(body.keys)..sort());
    });

    test('an unknown is an ABSENT key and never an explicit null', () {
      // G4 / CR-114, inherited from the encoder rather than restated.
      // `weight` is null on a template nobody weighed.
      final body = copyTemplateBody(_seed(buildSeedCatalog().keys.first))
        ..weight = null;
      final text = utf8.decode(encodeRmdxBytes(_file(body)));
      expect(text, isNot(contains('null')));
      expect(text, isNot(contains('weightUg')));
    });
  });

  group('what the reader refuses, and what it refuses it AS', () {
    test('a project file is NOT A DEVICE TEMPLATE, not a broken one', () {
      // The second half of M4-M1's file dialog. The filter stops most
      // wrong picks; this stops the rest, and the message has to say
      // which mistake was made or the user re-picks the same file.
      final err = _readErr(
        readRmdxJsonTree(<String, Object?>{
          'schemaVersion': 2,
          'generator': 'rackpal',
          'document': <String, Object?>{},
        }),
      );
      expect(err, isA<NotADeviceTemplateError>());
    });

    test('kind is checked BEFORE the version', () {
      // A `.rmpj` also carries a schemaVersion, and version-first would
      // report a project as a device template from the wrong era.
      final err = _readErr(
        readRmdxJsonTree(<String, Object?>{
          'schemaVersion': 99,
          'kind': 'project',
        }),
      );
      expect(err, isA<NotADeviceTemplateError>());
      expect(err, isNot(isA<NewerRmdxSchemaError>()));
    });

    test('a newer schemaVersion is REFUSED, never opened read-only', () {
      // The asymmetry with `.rmpj` is deliberate: AC-012 makes
      // `TemplateBody` closed with no `unknown` passthrough, so there is
      // nothing to open read-only WITH.
      final err = _readErr(
        readRmdxJsonTree(<String, Object?>{
          'kind': kRmdxKind,
          'schemaVersion': kRmdxSchemaVersion + 1,
        }),
      );
      expect(err, isA<NewerRmdxSchemaError>());
    });

    test('a version the chain cannot reach is an error, not a shrug', () {
      final err = _readErr(
        readRmdxJsonTree(<String, Object?>{
          'kind': kRmdxKind,
          'schemaVersion': 0,
        }),
      );
      expect(err, isA<MalformedRmdxError>());
    });

    test('a non-integer schemaVersion is malformed, not unmigratable', () {
      final err = _readErr(
        readRmdxJsonTree(<String, Object?>{
          'kind': kRmdxKind,
          'schemaVersion': '1',
        }),
      );
      expect(err, isA<MalformedRmdxError>());
    });

    test('a zip is refused before anything tries to parse it', () {
      // `.rmda` is deliberately NOT a zip (DR-015 §11.15.4), so anything
      // sniffing as one arrived here by accident.
      final err = _readErr(
        readRmdxBytes(Uint8List.fromList(<int>[0x50, 0x4B, 0x03, 0x04, 0x00])),
      );
      expect(err, isA<UnsupportedZipContainerError>());
    });

    test('the import limits run on THIS path, not only on .rmpj', () {
      // AC-058/D8 says every import path. #237 censuses them; this one
      // is paid on the day it lands.
      final bytes = encodeRmdxBytes(
        _file(_seed(buildSeedCatalog().keys.first)),
      );
      final err = _readErr(
        readRmdxBytes(bytes, limits: const JsonLimits(maxBytes: 8)),
      );
      expect(err, isA<DocumentTooLargeError>());
    });

    test('malformed JSON comes back as Err and never throws', () {
      // CR-093: the read path returns, it does not throw.
      final err = _readErr(readRmdxBytes(Uint8List.fromList(utf8.encode('{'))));
      expect(err, isNotNull);
    });
  });

  group('contentHash is CARRIED, and nothing here pretends otherwise', () {
    test('a placeholder round-trips verbatim', () {
      // Nothing in lib/ computes a sha256; every hash in the tree today
      // is a labelled placeholder. AC-042's warning is #236's, and it
      // cannot fire until somebody makes the hash real, because a
      // placeholder never mismatches. Asserted so the gap is visible in
      // a test run rather than only in a comment.
      // A value the default does NOT supply, so a green here proves the
      // hash was carried rather than that the fixture agreed with itself.
      // That is the false pass §5.3.21 found twice in one issue.
      final read = _readOk(
        encodeRmdxBytes(
          _file(
            _seed(buildSeedCatalog().keys.first),
            contentHash: 'unhashed:Z99@4',
          ),
        ),
      );
      expect(read.contentHash, 'unhashed:Z99@4');
    });

    test('fromSnapshot takes all four facts off the snapshot', () {
      final body = _seed(buildSeedCatalog().keys.first);
      final file = DeviceTemplateFile.fromSnapshot(
        TemplateSnapshot(
          templateId: const TemplateId('X9'),
          version: 7,
          contentHash: 'sha256:deadbeef',
          body: body,
          capturedAt: DateTime.utc(2026, 8, 29),
        ),
      );
      expect(file.templateId.v, 'X9');
      expect(file.version, 7);
      expect(file.contentHash, 'sha256:deadbeef');
      expect(
        rmdxToJsonTree(file).containsKey('capturedAt'),
        isFalse,
        reason:
            'a file has no capture time; that is not a fact about the '
            'template',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // v1 -> v2: `carriedProtocols` is gone (DR-134 §11.133)
  // ═══════════════════════════════════════════════════════════════════
  // THE FIRST STEP THE CHAIN HAS EVER HAD. `migrateRmdxToCurrent` shipped
  // empty at M4-M and said so: it bought "the SEAM plus the refusal, so
  // that the first person to bump `kRmdxSchemaVersion` adds a row to a
  // table that already exists". This is that row, and the cases below are
  // the ones a v1 file on somebody's disk actually meets.
  group('v1 -> v2, the first step the .rmdx chain has ever had', () {
    /// A v1 tree: the shape an older build wrote, key and all.
    JsonMap v1Tree({String? hash}) {
      final body = templateBodyToJson(_seed('A01'));
      final ports = body['ports']! as List;
      for (final port in ports) {
        (port! as Map)['carriedProtocols'] = <String>['net.ethernet'];
      }
      return <String, Object?>{
        'kind': kRmdxKind,
        'schemaVersion': 1,
        'templateId': 'A01',
        'version': 1,
        'contentHash': hash ?? 'sha256:${'a' * 64}',
        'body': body,
      };
    }

    test('the fixture really is a v1 tree carrying the key', () {
      // The control every migration group in this repository opens with:
      // an input that does not contain the thing being migrated proves
      // the code compiles rather than that it works.
      final raw = v1Tree();
      final ports = (raw['body']! as Map)['ports']! as List;
      expect(ports, isNotEmpty);
      expect(
        (ports.first! as Map).containsKey('carriedProtocols'),
        isTrue,
      );
    });

    test('a v1 file still opens, and comes back at the current version', () {
      final outcome = readRmdxJsonTree(v1Tree());
      expect(outcome, isA<Ok<DeviceTemplateFile>>());
    });

    test('the key is stripped from every port', () {
      switch (migrateRmdxToCurrent(v1Tree(), storedSchemaVersion: 1)) {
        case Err(:final error):
          fail('expected Ok, got Err($error)');
        case Ok(value: final migrated):
          expect(migrated['schemaVersion'], kRmdxSchemaVersion);
          final ports = (migrated['body']! as Map)['ports']! as List;
          expect(ports, isNotEmpty);
          for (final port in ports) {
            expect(
              (port! as Map).containsKey('carriedProtocols'),
              isFalse,
            );
          }
      }
    });

    test(
      'THE HASH IS RECOMPUTED, so a v1 file does not import as tampered',
      () {
        // The half that needed a decision. `contentHash` is taken over
        // `templateBodyToJson`'s canonical bytes and this migration changes
        // those bytes, so without recomputing, every file exported before
        // DR-134 would report `mismatched` for a reason that has nothing to
        // do with its content. A warning that fires on every older file is
        // one a person learns to click past, and then it is gone for the
        // files it was built for.
        final real = templateContentHash(_seed('A01'));
        final outcome = readRmdxJsonTree(v1Tree(hash: 'sha256:${'a' * 64}'));
        switch (outcome) {
          case Err(:final error):
            fail('expected Ok, got Err($error)');
          case Ok(value: final file):
            expect(file.contentHash, real);
            expect(
              templateHashMatches(file.body, file.contentHash),
              isTrue,
              reason: 'a migrated v1 file verifies against itself',
            );
        }
      },
    );

    test('a v2 file is not touched, so the check still MEANS something', () {
      // The half that makes the case above safe. Recomputing on every
      // read would make the hash verify by construction and stop being
      // tamper evidence at all; only the migration recomputes.
      final tampered = <String, Object?>{
        ...v1Tree(),
        'schemaVersion': kRmdxSchemaVersion,
        'contentHash': 'sha256:${'b' * 64}',
      };
      switch (readRmdxJsonTree(tampered)) {
        case Err(:final error):
          fail('expected Ok, got Err($error)');
        case Ok(value: final file):
          expect(file.contentHash, 'sha256:${'b' * 64}');
          expect(templateHashMatches(file.body, file.contentHash), isFalse);
      }
    });

    test("a v1 tree with a malformed body is the DECODER's error", () {
      // The migration does not swallow it: `readRmdxJsonTree` decodes
      // next and names the real key path, which is the only message that
      // helps somebody fix the file.
      final broken = <String, Object?>{
        ...v1Tree(),
        'body': <String, Object?>{'ports': 'not a list'},
      };
      expect(readRmdxJsonTree(broken), isA<Err<DeviceTemplateFile>>());
    });
  });
}
