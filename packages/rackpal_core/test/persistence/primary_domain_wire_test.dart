// DR-169 §11.168.5: `TemplateBody.primaryDomain` on the wire (`#899`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE PROPERTY WORTH THE FILE is that an unset domain writes NO KEY, so
// adding this field costs every document already on disk exactly nothing,
// the four checked-in starters do not regenerate, and no template's
// content hash moves. `templateContentHash` hashes `templateBodyToJson`,
// so a key written unconditionally would have re-hashed all 51 seeded
// templates for a field nobody had filled in yet.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THE ABSENT KEY MEANS UNKNOWN, WHICH IS NOT WHAT `glyph`'s MEANS
// ═══════════════════════════════════════════════════════════════════════
// `device_glyph_wire_test.dart` has the same SHAPE one field over and a
// different meaning: an absent `glyph` means INHERIT, and the category
// resolves it. An absent `primaryDomain` means nobody has said, which is
// G4/CR-114's unknown: it draws the neutral mark on a plan and is never
// filled in from the ports. The census on the model field says why it
// cannot be: of 51 seeded templates only 13 have ports in one domain.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
const _net = SignalDomainId('net');

TemplateBody _body({SignalDomainId? domain}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'SW-24',
  displayName: 'Managed Switch 24-port',
  category: kCatNetwork,
  frontU: 1,
  primaryDomain: domain,
);

RackDocument _docWith(TemplateBody body) {
  final when = DateTime.utc(2026, 9, 13, 12);
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-0000000000d9'),
    appVersion: '0.1.0+build.1',
    createdAt: when,
    modifiedAt: when,
    meta: EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'riley'),
    info: ProjectInfo(projectName: 'Domain fixture'),
  );
  doc.templates['tpl.demo.sw@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.demo.sw'),
    version: 1,
    contentHash: 'sha256:tpl.demo.sw',
    body: body,
    capturedAt: when,
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
  final snapshot = templates['tpl.demo.sw@1']! as Map<String, Object?>;
  return snapshot['body']! as Map<String, Object?>;
}

void main() {
  group('an unset primary domain', () {
    test('writes NO key, so nothing on disk gains one and no content hash '
        'moves', () {
      expect(
        _encodedBody(_docWith(_body())).containsKey('primaryDomain'),
        isFalse,
      );
    });

    test('reads back unset, and is NOT filled in from the ports', () {
      final read = _read(_codec.write(_docWith(_body())));

      expect(read.templates['tpl.demo.sw@1']!.body.primaryDomain, isNull);
    });

    test('leaves the content hash where it was', () {
      // The field exists and is null, which must hash as the body did
      // before the field existed. Anything else re-hashes 51 seeded
      // templates for a value nobody authored.
      final withField = templateContentHash(_body());
      final withoutTheKey = templateContentHash(
        TemplateBody(
          manufacturer: 'Generic',
          model: 'SW-24',
          displayName: 'Managed Switch 24-port',
          category: kCatNetwork,
          frontU: 1,
        ),
      );

      expect(withField, withoutTheKey);
    });

    test('round-trips byte-for-byte (CR-117)', () {
      final first = _codec.write(_docWith(_body()));

      expect(_codec.write(_read(first)), equals(first));
    });
  });

  group('an authored primary domain', () {
    test('survives the trip', () {
      final read = _read(_codec.write(_docWith(_body(domain: _net))));

      expect(read.templates['tpl.demo.sw@1']!.body.primaryDomain, _net);
    });

    test('is written as the domain id, which is what the registry is '
        'keyed by', () {
      expect(
        _encodedBody(_docWith(_body(domain: _net)))['primaryDomain'],
        'net',
      );
    });

    test('round-trips byte-for-byte (CR-117)', () {
      final first = _codec.write(
        _docWith(_body(domain: const SignalDomainId('video.digital'))),
      );

      expect(_codec.write(_read(first)), equals(first));
    });

    test('differs from an unset one by that key and nothing else', () {
      final set = _encodedBody(_docWith(_body(domain: _net)));
      final unset = _encodedBody(_docWith(_body()));

      expect(
        set.keys.toSet().difference(unset.keys.toSet()),
        {'primaryDomain'},
      );
      expect(unset.keys.toSet().difference(set.keys.toSet()), isEmpty);
    });

    test('DOES move the content hash, which is the cost of authoring one', () {
      // Recorded rather than regretted: `#900` fills in 51 seeded
      // templates, and every one of them re-hashes. The starters
      // regenerate with it.
      expect(
        templateContentHash(_body(domain: _net)),
        isNot(templateContentHash(_body())),
      );
    });
  });
}
