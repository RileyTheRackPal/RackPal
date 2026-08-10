// DR-033 (canon §11.32): `TemplateBody.submittedBy` records who filed the
// pull request that proposed a template to the community catalog.
//
// The field ships in v1 while the surface that writes it is v1.1, and the
// reason is a serialisation fact rather than a product one: `TemplateBody`
// has no `unknown` passthrough, so a credit written by a build that knew the
// field would be silently dropped by one that did not, the first time that
// build re-saved the file (§11.32.8). These tests are what "the field is
// really here" means.
//
// They assert the ARTIFACT: what reaches the bytes, and what comes back.
// None of them assert that the application ignores the credit, because
// "never read" is a property of every other file in the package and is not
// testable from this one.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

TemplateBody _body({SubmissionCredit? submittedBy}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'PP-24',
  displayName: '24-port patch panel',
  frontU: 1,
  submittedBy: submittedBy,
);

/// A document carrying exactly one template, so the encoded template map is
/// the only thing that can differ between two writes.
RackDocument _docWith(TemplateBody body) {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-0000000000cc'),
    appVersion: '0.1.0+build.1',
    createdAt: DateTime.utc(2026, 8, 9, 12),
    modifiedAt: DateTime.utc(2026, 8, 9, 12),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026, 8, 9, 12),
      updatedAt: DateTime.utc(2026, 8, 9, 12),
      updatedBy: 'riley',
    ),
    info: ProjectInfo(projectName: 'Community catalog fixture'),
  );
  doc.templates['tpl.demo.pp24@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.demo.pp24'),
    version: 1,
    contentHash: 'sha256:tpl.demo.pp24',
    body: body,
    capturedAt: DateTime.utc(2026, 8, 9, 12),
  );
  return doc;
}

/// Unwraps a successful read, so each test asserts its own subject rather
/// than re-asserting that the codec works.
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
  group('an unsubmitted template', () {
    test('writes NO submittedBy key at all, rather than an explicit null '
        '(G4, CR-114)', () {
      final body = _encodedBody(_docWith(_body()));

      expect(
        body.containsKey('submittedBy'),
        isFalse,
        reason: 'unknown serialises as an absent key, never a null',
      );
    });

    test('reads back as unsubmitted', () {
      final bytes = _codec.write(_docWith(_body()));

      final read = _read(bytes);

      expect(read.templates['tpl.demo.pp24@1']!.body.submittedBy, isNull);
    });

    test('round-trips byte-for-byte, so adding the field moved no existing '
        'fixture or golden (CR-117)', () {
      final first = _codec.write(_docWith(_body()));

      final second = _codec.write(_read(first));

      expect(second, equals(first));
    });
  });

  group('a submitted template', () {
    const credit = SubmissionCredit(handle: 'riley', userId: 12345);

    test('carries the handle and the numeric id as two separate facts, '
        'because a GitHub login is renameable and a freed one is '
        'claimable (DR-033 §11.32.5)', () {
      final bytes = _codec.write(_docWith(_body(submittedBy: credit)));

      final read = _read(bytes);

      final back = read.templates['tpl.demo.pp24@1']!.body.submittedBy;
      expect(back, isNotNull);
      expect(back!.handle, 'riley');
      expect(back.userId, 12345);
    });

    test('round-trips byte-for-byte (CR-117)', () {
      final first = _codec.write(_docWith(_body(submittedBy: credit)));

      final second = _codec.write(_read(first));

      expect(second, equals(first));
    });

    test('differs from an unsubmitted one by the submittedBy key and nothing '
        'else', () {
      final submitted = _encodedBody(_docWith(_body(submittedBy: credit)));
      final unsubmitted = _encodedBody(_docWith(_body()));

      expect(
        submitted.keys.toSet().difference(unsubmitted.keys.toSet()),
        {'submittedBy'},
      );
      expect(submitted['submittedBy'], {'handle': 'riley', 'userId': 12345});
    });

    test('a rename does not silently re-credit somebody else: the id survives '
        'a handle that changed', () {
      // The same person, after renaming. Same userId, different handle.
      const renamed = SubmissionCredit(handle: 'riley-shale', userId: 12345);

      final a = _read(_codec.write(_docWith(_body(submittedBy: credit))));
      final b = _read(_codec.write(_docWith(_body(submittedBy: renamed))));

      final left = a.templates['tpl.demo.pp24@1']!.body.submittedBy!;
      final right = b.templates['tpl.demo.pp24@1']!.body.submittedBy!;
      expect(left.userId, right.userId, reason: 'the identity is the id');
      expect(left.handle, isNot(right.handle), reason: 'the display drifted');
    });
  });

  group('reading a file this build did not write', () {
    test('an explicit null submittedBy reads as unsubmitted, so a file from a '
        'writer that ignored G4 still opens', () {
      final bytes = _codec.write(_docWith(_body()));
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final document = json['document']! as Map<String, Object?>;
      final templates = document['templates']! as Map<String, Object?>;
      final snapshot = templates['tpl.demo.pp24@1']! as Map<String, Object?>;
      (snapshot['body']! as Map<String, Object?>)['submittedBy'] = null;

      final read = _read(utf8.encode(jsonEncode(json)));

      expect(read.templates['tpl.demo.pp24@1']!.body.submittedBy, isNull);
    });
  });
}
