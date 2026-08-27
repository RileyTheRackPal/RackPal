// DR-059: `TemplateBody.glyph` on the wire. Board #201, M4-D/3.
//
// THE PROPERTY WORTH THE FILE is that an unchosen glyph writes NO KEY, so
// adding this field costs every document already on disk exactly nothing
// and the four checked-in starters do not regenerate. Writing the
// RESOLVED value instead would have put a key on all 48 seeded templates
// and lost the author's choice the moment a category changed, which is
// the same class of bug as storing a derived number (CR-005).
//
// The absent key here means INHERIT, not unknown. It is the shape
// `SignalFamilyDef.dashOverride` already has, so no rollup counts it and
// nothing prints an em dash for it.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

TemplateBody _body({DeviceGlyph? glyph}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'MTX-8',
  displayName: 'HDMI Matrix 8x8',
  category: kCatVideo,
  frontU: 4,
  glyph: glyph,
);

RackDocument _docWith(TemplateBody body) {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-0000000000cf'),
    appVersion: '0.1.0+build.1',
    createdAt: DateTime.utc(2026, 8, 14, 12),
    modifiedAt: DateTime.utc(2026, 8, 14, 12),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026, 8, 14, 12),
      updatedAt: DateTime.utc(2026, 8, 14, 12),
      updatedBy: 'riley',
    ),
    info: ProjectInfo(projectName: 'Glyph fixture'),
  );
  doc.templates['tpl.demo.mtx@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.demo.mtx'),
    version: 1,
    contentHash: 'sha256:tpl.demo.mtx',
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
  final snapshot = templates['tpl.demo.mtx@1']! as Map<String, Object?>;
  return snapshot['body']! as Map<String, Object?>;
}

void main() {
  group('an unchosen glyph', () {
    test('writes NO key, so no document on disk gains one and no starter '
        'regenerates', () {
      expect(_encodedBody(_docWith(_body())).containsKey('glyph'), isFalse);
    });

    test('reads back unchosen, and still resolves to the category mark', () {
      final read = _read(_codec.write(_docWith(_body())));

      final back = read.templates['tpl.demo.mtx@1']!.body;
      expect(back.glyph, isNull);
      expect(effectiveGlyph(back.glyph, back.category), DeviceGlyph.matrix);
    });

    test('round-trips byte-for-byte (CR-117)', () {
      final first = _codec.write(_docWith(_body()));

      expect(_codec.write(_read(first)), equals(first));
    });
  });

  group('a chosen glyph', () {
    test('survives the trip as the choice, not as the resolved mark', () {
      final read = _read(
        _codec.write(_docWith(_body(glyph: DeviceGlyph.extender))),
      );

      expect(
        read.templates['tpl.demo.mtx@1']!.body.glyph,
        DeviceGlyph.extender,
      );
    });

    test('is written even when it happens to equal the category default, '
        'so changing the category later does not silently change the mark', () {
      final body = _encodedBody(
        _docWith(_body(glyph: DeviceGlyph.matrix)),
      );

      expect(body['glyph'], 'matrix');
    });

    test('round-trips byte-for-byte (CR-117)', () {
      final first = _codec.write(_docWith(_body(glyph: DeviceGlyph.speaker)));

      expect(_codec.write(_read(first)), equals(first));
    });

    test('differs from an unchosen one by the glyph key and nothing else', () {
      final chosen = _encodedBody(_docWith(_body(glyph: DeviceGlyph.camera)));
      final unchosen = _encodedBody(_docWith(_body()));

      expect(chosen.keys.toSet().difference(unchosen.keys.toSet()), {'glyph'});
    });

    test('an explicit `none` is a value and reaches the file, because it '
        'is a choice the category must not override', () {
      final body = _encodedBody(_docWith(_body(glyph: DeviceGlyph.none)));

      expect(body['glyph'], 'none');
    });
  });

  group('a file this build did not write', () {
    test('refuses a glyph nobody defined rather than falling back to a '
        'picture the author never chose', () {
      final bytes = _codec.write(_docWith(_body()));
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final document = json['document']! as Map<String, Object?>;
      final templates = document['templates']! as Map<String, Object?>;
      final snapshot = templates['tpl.demo.mtx@1']! as Map<String, Object?>;
      (snapshot['body']! as Map<String, Object?>)['glyph'] = 'toaster';

      final outcome = _codec.read(utf8.encode(jsonEncode(json)));

      expect(outcome, isNot(isA<Ok<RackDocument>>()));
    });

    test('an explicit null reads as unchosen, so a writer that ignored the '
        'absent-key rule still opens', () {
      final bytes = _codec.write(_docWith(_body()));
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final document = json['document']! as Map<String, Object?>;
      final templates = document['templates']! as Map<String, Object?>;
      final snapshot = templates['tpl.demo.mtx@1']! as Map<String, Object?>;
      (snapshot['body']! as Map<String, Object?>)['glyph'] = null;

      final read = _read(utf8.encode(jsonEncode(json)));

      expect(read.templates['tpl.demo.mtx@1']!.body.glyph, isNull);
    });
  });
}
