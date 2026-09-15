// `#239`, DR-015 §11.15.3–§11.15.4: many templates in one JSON file.
//
// THE SWEEP IS THE SAME SHAPE AS `.rmdx`'s AND FOR THE SAME REASON. A
// library is where a dropped field hurts most: one `.rmdx` losing a key
// costs one template, and one `.rmda` losing it costs every template in
// the pack, silently, because an unclaimed key does not throw. So the
// whole seed catalog goes through bytes and back and is compared byte for
// byte.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_core/src/persistence/outlet_key_retirement.dart'
    show canonicalBodyHash;
import 'package:test/test.dart';

DeviceTemplateFile _entry(String id, TemplateBody body, {int version = 1}) =>
    DeviceTemplateFile(
      templateId: TemplateId(id),
      version: version,
      contentHash: templateContentHash(body),
      body: body,
    );

DeviceLibraryFile _seedLibrary() {
  final catalog = buildSeedCatalog();
  return DeviceLibraryFile(
    name: 'Shop Kit',
    templates: [
      for (final e in catalog.entries) _entry(e.key, e.value),
    ],
  );
}

DeviceLibraryFile _readOk(Uint8List bytes) {
  final outcome = readRmdaBytes(bytes);
  switch (outcome) {
    case Ok(:final value):
      return value;
    case Err(:final error):
      fail('expected Ok, got Err($error)');
  }
}

Object _readErr(Outcome<DeviceLibraryFile> outcome) {
  switch (outcome) {
    case Ok():
      fail('expected Err, got Ok');
    case Err(:final error):
      return error;
  }
}

void main() {
  group('nothing is lost, across the whole catalog', () {
    test('48 templates survive a library round trip, byte for byte', () {
      final lib = _seedLibrary();
      expect(
        lib.templates.length,
        greaterThan(40),
        reason: 'a sweep over an empty library passes vacuously',
      );
      final first = encodeRmdaBytes(lib);
      final second = encodeRmdaBytes(_readOk(first));
      expect(second, first);
    });

    test('every entry keeps its identity, not just its body', () {
      // The reading of DR-015 this codec records in its header: a bare
      // body has no version and no id, so CR-050's chain would flatten
      // and DR-101's collision handling would have nothing to resolve on.
      final lib = _seedLibrary();
      final read = _readOk(encodeRmdaBytes(lib));
      expect(
        read.templates.map((t) => t.templateId.v).toList(),
        lib.templates.map((t) => t.templateId.v).toList(),
      );
      expect(read.templates.first.contentHash, lib.templates.first.contentHash);
    });

    test('two versions of one id both survive', () {
      // What a bare-body array could not express at all.
      final body = buildSeedCatalog().values.first;
      final lib = DeviceLibraryFile(
        name: 'Two',
        templates: [
          _entry('tpl.mx', body),
          _entry('tpl.mx', copyTemplateBody(body), version: 4),
        ],
      );
      final read = _readOk(encodeRmdaBytes(lib));
      expect(read.templates.map((t) => t.version), [1, 4]);
    });

    test('an empty library round-trips', () {
      // A pack somebody exported before adding anything to it. Legal,
      // and the reader must not treat "no templates" as malformed.
      final read = _readOk(
        encodeRmdaBytes(
          const DeviceLibraryFile(name: 'Empty', templates: []),
        ),
      );
      expect(read.name, 'Empty');
      expect(read.templates, isEmpty);
    });
  });

  group('the bytes', () {
    test('the envelope carries four keys and no more', () {
      // The manifest is ONE field on purpose. A count would disagree
      // with the array the first time somebody hand-edited one, which is
      // docs/13's D13 shape inside a file.
      final tree = rmdaToJsonTree(
        const DeviceLibraryFile(name: 'x', templates: []),
      );
      expect(tree.keys.toSet(), {
        'schemaVersion',
        'kind',
        'name',
        'templates',
      });
    });

    test('UTF-8, LF only, sorted at every level', () {
      final text = utf8.decode(encodeRmdaBytes(_seedLibrary()));
      expect(text, isNot(contains('\r')));
      final root = jsonDecode(text) as Map<String, Object?>;
      expect(root.keys.toList(), List.of(root.keys)..sort());
      final first = (root['templates']! as List).first as Map<String, Object?>;
      expect(first.keys.toList(), List.of(first.keys)..sort());
    });

    test('it shares the .rmdx schema version, not a second one', () {
      // DR-015 §11.15.4: the .rmdx chain is REUSED rather than a second
      // one invented. A .rmda is .rmdx entries in a list, so a change to
      // the entry shape is a change to both.
      expect(kRmdaSchemaVersion, kRmdxSchemaVersion);
    });
  });

  group('what it refuses, and what it refuses it AS', () {
    test('a .rmdx is NOT a broken library', () {
      // The two formats are structurally similar enough that a missing
      // `templates` key would otherwise report a shape problem for what
      // is really a wrong-file problem.
      final rmdx = encodeRmdxBytes(
        _entry('tpl.mx', buildSeedCatalog().values.first),
      );
      expect(_readErr(readRmdaBytes(rmdx)), isA<NotADeviceLibraryError>());
    });

    test('and a .rmda is not a device template, in the other direction', () {
      final rmda = encodeRmdaBytes(
        const DeviceLibraryFile(name: 'x', templates: []),
      );
      expect(readRmdxBytes(rmda), isA<Err<DeviceTemplateFile>>());
    });

    test('a ZIP is refused, and it is the likeliest wrong file of all', () {
      // `.rmlib` WAS specified as a zip, so anybody carrying an old pack
      // has one.
      expect(
        _readErr(
          readRmdaBytes(Uint8List.fromList(<int>[0x50, 0x4B, 0x03, 0x04, 0])),
        ),
        isA<UnsupportedZipContainerError>(),
      );
    });

    test('a newer schemaVersion is refused, never partially read', () {
      expect(
        _readErr(
          readRmdaJsonTree(<String, Object?>{
            'kind': kRmdaKind,
            'schemaVersion': kRmdaSchemaVersion + 1,
            'name': 'x',
            'templates': <Object?>[],
          }),
        ),
        isA<NewerRmdaSchemaError>(),
      );
    });

    test('kind is checked BEFORE the version', () {
      expect(
        _readErr(
          readRmdaJsonTree(<String, Object?>{
            'kind': 'project',
            'schemaVersion': 99,
          }),
        ),
        isA<NotADeviceLibraryError>(),
      );
    });

    test('the import limits run on this path too', () {
      // DR-015 §11.15.4's own argument for one JSON file is that it
      // inherits AC-058/D8's limits. A library is the biggest file this
      // product reads, so it is where the cap matters most.
      final bytes = encodeRmdaBytes(_seedLibrary());
      expect(
        _readErr(readRmdaBytes(bytes, limits: const JsonLimits(maxBytes: 16))),
        isA<DocumentTooLargeError>(),
      );
    });

    test('one malformed entry fails the read, it does not import a partial '
        'library', () {
      // A library is all-or-nothing on purpose: half a pack landing in
      // the palette is worse than none, because nothing on screen would
      // say which half.
      expect(
        _readErr(
          readRmdaJsonTree(<String, Object?>{
            'kind': kRmdaKind,
            'schemaVersion': kRmdaSchemaVersion,
            'name': 'x',
            'templates': <Object?>[
              {'templateId': 'a', 'version': 1, 'contentHash': 'h'},
            ],
          }),
        ),
        isNotNull,
      );
    });
  });

  group('v2 -> v3: every entry sheds the outlet counts (DR-171)', () {
    test('a v2 library opens, each entry stripped and still verifying', () {
      final tree = rmdaToJsonTree(_seedLibrary());
      tree['schemaVersion'] = 2;
      final entries = tree['templates']! as List;
      expect(entries, isNotEmpty);
      for (final entry in entries) {
        final e = entry! as Map;
        final body = e['body']! as Map<Object?, Object?>;
        (body['power']! as Map)['outletsConsumed'] = 1;
        e['contentHash'] = canonicalBodyHash(body);
      }
      switch (readRmdaJsonTree(tree)) {
        case Err(:final error):
          fail('expected Ok, got Err($error)');
        case Ok(value: final library):
          for (final t in library.templates) {
            expect(
              templateHashMatches(t.body, t.contentHash),
              isTrue,
              reason: t.body.displayName,
            );
          }
      }
    });

    test('a v1 library is still refused: the chain starts at 2', () {
      expect(
        _readErr(
          readRmdaJsonTree(<String, Object?>{
            'kind': kRmdaKind,
            'schemaVersion': 1,
            'name': 'x',
            'templates': <Object?>[],
          }),
        ),
        isA<MalformedRmdaError>(),
      );
    });
  });
}
