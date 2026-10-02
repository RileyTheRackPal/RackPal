// The integrator's logo, as the file stores it and as the command writes it
// (`#590`, DR-030, DR-217).
//
// ABSENT IS THE ORDINARY CASE (DR-030 §11.29.6), so the first thing proved
// is that a project with no logo writes exactly what it wrote before the
// field existed: no key, not a null.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _when = DateTime.utc(2026, 10);

const ProjectLogo _logo = ProjectLogo(
  imageMember: '${kLogoMemberDir}logo-1.png',
  format: PlanImageFormat.png,
  pixelWidth: 834,
  pixelHeight: 375,
  contentHash: 'sha256:abc',
);

RackDocument _doc({ProjectLogo? logo}) => RackDocument(
  id: const Uuid('doc-logo'),
  appVersion: '0.6.60',
  createdAt: _when,
  modifiedAt: _when,
  meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test'),
  info: ProjectInfo(projectName: 'Logo', logo: logo),
);

Map<String, Object?> _infoOnWire(Uint8List bytes) {
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  final document = json['document']! as Map<String, Object?>;
  return document['info']! as Map<String, Object?>;
}

void main() {
  group('on the wire', () {
    test('NO LOGO WRITES NO KEY, and reads back as none', () {
      final bytes = _codec.write(_doc());
      expect(_infoOnWire(bytes).containsKey('logo'), isFalse);
      final back = (_codec.read(bytes) as Ok<RackDocument>).value;
      expect(back.info.logo, isNull);
    });

    test('a logo writes its five keys and reads back equal', () {
      final bytes = _codec.write(_doc(logo: _logo));
      expect(_infoOnWire(bytes)['logo'], {
        'contentHash': 'sha256:abc',
        'format': 'png',
        'imageMember': 'logos/logo-1.png',
        'pixelHeight': 375,
        'pixelWidth': 834,
      });
      final back = (_codec.read(bytes) as Ok<RackDocument>).value;
      expect(back.info.logo, _logo);
    });

    test('BYTE ROUND-TRIP (CR-117): write(read(bytes)) == bytes', () {
      final bytes = _codec.write(_doc(logo: _logo));
      final again = _codec.write(
        (_codec.read(bytes) as Ok<RackDocument>).value,
      );
      expect(again, bytes);
    });

    test('a zero-sized logo is refused at the boundary, not drawn', () {
      final bytes = _codec.write(_doc(logo: _logo));
      final text = utf8
          .decode(bytes)
          .replaceFirst(RegExp(r'"pixelWidth":\s*834'), '"pixelWidth": 0');
      expect(text, isNot(utf8.decode(bytes)), reason: 'the edit landed');
      final read = _codec.read(Uint8List.fromList(utf8.encode(text)));
      expect(read, isA<Err<RackDocument>>());
    });
  });

  group('SetProjectLogoCommand', () {
    test('sets, and undo restores none', () {
      final doc = _doc();
      final command = SetProjectLogoCommand.to(doc.info, _logo);
      expect(command.apply(doc), isTrue);
      expect(doc.info.logo, _logo);
      command.revert(doc);
      expect(doc.info.logo, isNull);
    });

    test('removes, and undo restores the logo', () {
      final doc = _doc(logo: _logo);
      final command = SetProjectLogoCommand.to(doc.info, null);
      expect(command.apply(doc), isTrue);
      expect(doc.info.logo, isNull);
      command.revert(doc);
      expect(doc.info.logo, _logo);
    });

    test('REMOVE ON NO LOGO IS NOT AN UNDO STEP', () {
      final doc = _doc();
      expect(SetProjectLogoCommand.to(doc.info, null).apply(doc), isFalse);
    });

    test('the Edit menu names it as its own act', () {
      expect(
        SetProjectLogoCommand.to(_doc().info, _logo).label,
        LabelKey.setProjectLogo,
      );
    });
  });
}
