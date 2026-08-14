// CR-062, board #196: `TemplateBody.derivedFrom` records the template a
// fork was taken from, so that a later correction to the SOURCE can be
// surfaced passively instead of being lost.
//
// The field was documented from M0 in four places -- docs/06 §7.3's
// Duplicate row and its worked `.rmdx` example, docs/02 §7's fork row,
// CR-062 itself and DR-015's `.rmda` provenance -- and declared by
// neither the Dart nor the codec. Anyone reading AC-042 alone concludes
// it was cut; AC-042 cut the `signature` field and the CRYPTOGRAPHIC
// chain, and DR-015 §11.15.3 separates the two halves. This is the kept
// side.
//
// These assert the ARTIFACT: what reaches the bytes and what comes back.
// Nothing here asserts that a fork is CREATED with one, because nothing
// forks yet -- Duplicate is M4-D's shell.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

TemplateBody _body({TemplateOrigin? derivedFrom}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'PP-24',
  displayName: '24-port patch panel',
  frontU: 1,
  derivedFrom: derivedFrom,
);

/// A document carrying exactly one template, so the encoded template map
/// is the only thing that can differ between two writes.
RackDocument _docWith(TemplateBody body) {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-0000000000ce'),
    appVersion: '0.1.0+build.1',
    createdAt: DateTime.utc(2026, 8, 14, 12),
    modifiedAt: DateTime.utc(2026, 8, 14, 12),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026, 8, 14, 12),
      updatedAt: DateTime.utc(2026, 8, 14, 12),
      updatedBy: 'riley',
    ),
    info: ProjectInfo(projectName: 'Fork provenance fixture'),
  );
  doc.templates['tpl.demo.pp24@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.demo.pp24'),
    version: 1,
    contentHash: 'sha256:tpl.demo.pp24',
    body: body,
    capturedAt: DateTime.utc(2026, 8, 14, 12),
  );
  return doc;
}

RackDocument _read(Uint8List bytes) {
  final outcome = _codec.read(bytes);
  expect(outcome, isA<Ok<RackDocument>>(), reason: 'read failed');
  return (outcome as Ok<RackDocument>).value;
}

Map<String, Object?> _encodedBody(RackDocument doc) {
  final json =
      jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
  final document = json['document']! as Map<String, Object?>;
  final templates = document['templates']! as Map<String, Object?>;
  final snapshot = templates['tpl.demo.pp24@1']! as Map<String, Object?>;
  return snapshot['body']! as Map<String, Object?>;
}

void main() {
  group('an original template', () {
    test('writes NO derivedFrom key at all, rather than an explicit null '
        '(G4, CR-114)', () {
      final body = _encodedBody(_docWith(_body()));

      expect(
        body.containsKey('derivedFrom'),
        isFalse,
        reason: 'unknown serialises as an absent key, never a null',
      );
    });

    test('reads back as original', () {
      final read = _read(_codec.write(_docWith(_body())));

      expect(read.templates['tpl.demo.pp24@1']!.body.derivedFrom, isNull);
    });

    test('round-trips byte-for-byte, so adding the field moved no existing '
        'fixture or golden (CR-117)', () {
      final first = _codec.write(_docWith(_body()));

      final second = _codec.write(_read(first));

      expect(second, equals(first));
    });
  });

  group('a fork', () {
    const origin = TemplateOrigin(
      templateId: TemplateId('cat.video.v04'),
      version: 1,
    );

    test('carries the source id and the version it was taken AT', () {
      final read = _read(_codec.write(_docWith(_body(derivedFrom: origin))));

      final back = read.templates['tpl.demo.pp24@1']!.body.derivedFrom;
      expect(back, isNotNull);
      expect(back!.templateId, const TemplateId('cat.video.v04'));
      expect(back.version, 1);
    });

    test('round-trips byte-for-byte (CR-117)', () {
      final first = _codec.write(_docWith(_body(derivedFrom: origin)));

      final second = _codec.write(_read(first));

      expect(second, equals(first));
    });

    test('differs from an original by the derivedFrom key and nothing else, '
        'and that key holds TWO fields: no contentHash, because AC-042 cut '
        'the integrity apparatus and DR-015 §11.15.3 kept only the join', () {
      final forked = _encodedBody(_docWith(_body(derivedFrom: origin)));
      final original = _encodedBody(_docWith(_body()));

      expect(forked.keys.toSet().difference(original.keys.toSet()), {
        'derivedFrom',
      });
      expect(forked['derivedFrom'], {
        'templateId': 'cat.video.v04',
        'version': 1,
      });
    });

    test('is equal to another origin naming the same source at the same '
        'version, and unequal at a different one -- the version is part of '
        'the identity, because it is what CR-062 compares', () {
      const same = TemplateOrigin(
        templateId: TemplateId('cat.video.v04'),
        version: 1,
      );
      const later = TemplateOrigin(
        templateId: TemplateId('cat.video.v04'),
        version: 3,
      );

      expect(origin, same);
      expect(origin.hashCode, same.hashCode);
      expect(origin, isNot(later));
    });
  });

  group('the builder copy', () {
    test('carries the provenance, so editing a fork in the builder and '
        'saving it does not silently turn it back into an original', () {
      const origin = TemplateOrigin(
        templateId: TemplateId('cat.video.v04'),
        version: 2,
      );

      final copy = copyTemplateBody(_body(derivedFrom: origin));

      expect(copy.derivedFrom, origin);
    });
  });

  group('reading a file this build did not write', () {
    test('an explicit null derivedFrom reads as original, so a file from a '
        'writer that ignored G4 still opens', () {
      final bytes = _codec.write(_docWith(_body()));
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final document = json['document']! as Map<String, Object?>;
      final templates = document['templates']! as Map<String, Object?>;
      final snapshot = templates['tpl.demo.pp24@1']! as Map<String, Object?>;
      (snapshot['body']! as Map<String, Object?>)['derivedFrom'] = null;

      final read = _read(utf8.encode(jsonEncode(json)));

      expect(read.templates['tpl.demo.pp24@1']!.body.derivedFrom, isNull);
    });
  });
}
