// REAR MIRRORING (docs/04 §2.2, CR-035, roadmap M1 item 3).
//
// The property that matters most here is the one a screenshot would never
// show: mirroring is a LAYOUT reflection and not a canvas `scale(-1, 1)`,
// so no text on the rear sheet is drawn backwards. The last group asserts
// that against the composed scene's transforms directly, because the cheap
// wrong fix — one negative X scale around the whole elevation — passes
// every rectangle assertion in this file.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import '../sheet/sheet_test_support.dart';

const Uuid _rackId = Uuid('rack-1');

DeviceInstance _device({
  required String id,
  required int ru,
  Face face = Face.rear,
  int startTwelfth = 0,
  int spanTwelfths = 12,
}) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: const TemplateRef(
    templateId: TemplateId('T1'),
    version: 1,
    contentHash: 'h',
  ),
  designator: id.toUpperCase(),
  name: 'NAME',
  placement: RailPlacement(
    rackId: _rackId,
    ruIndex: ru,
    face: face,
    startTwelfth: startTwelfth,
    spanTwelfths: spanTwelfths,
  ),
  meta: testMeta(),
);

Map<String, TemplateSnapshot> _templates() => <String, TemplateSnapshot>{
  'T1@1': TemplateSnapshot(
    templateId: const TemplateId('T1'),
    version: 1,
    contentHash: 'h',
    body: TemplateBody(
      manufacturer: 'M',
      model: 'X',
      displayName: 'Thing',
      frontU: 2,
      rearU: 2,
      side: OccupancySide.both,
    ),
    capturedAt: DateTime.utc(2026),
  ),
};

Rack _rack({bool mirror = true}) => Rack(
  id: _rackId,
  name: 'R',
  designator: 'RK-1',
  heightU: 12,
  order: const FracIndex('a0'),
  meta: testMeta(),
  mirrorRearElevation: mirror,
);

void main() {
  const geo = RackGeometry(12);

  group('RackGeometry.deviceRect mirroring', () {
    test('a full-width device is UNCHANGED by mirroring', () {
      // start 0, span 12 reflects to start 12 - 0 - 12 = 0. The overwhelming
      // majority of real devices, and the reason the UI tests did not move.
      expect(geo.deviceRect(3, 2, mirrored: true), geo.deviceRect(3, 2));
    });

    test('a half-width device at twelfth 0 lands at twelfth 6', () {
      final left = geo.deviceRect(3, 2, spanTwelfths: 6);
      final mirrored = geo.deviceRect(3, 2, spanTwelfths: 6, mirrored: true);
      final right = geo.deviceRect(3, 2, startTwelfth: 6, spanTwelfths: 6);

      expect(mirrored, right);
      expect(mirrored, isNot(left));
    });

    test('a mirrored rect is the EXACT reflection about the opening '
        'centre', () {
      final centre = geo.openingLeft + RackGeometry.openingWidth / 2;
      final plain = geo.deviceRect(1, 1, startTwelfth: 1, spanTwelfths: 4);
      final mirrored = geo.deviceRect(
        1,
        1,
        startTwelfth: 1,
        spanTwelfths: 4,
        mirrored: true,
      );

      // Reflecting x about `centre` maps left -> right and right -> left.
      expect(2 * centre - plain.right, closeTo(mirrored.left, 1e-9));
      expect(2 * centre - plain.left, closeTo(mirrored.right, 1e-9));
    });

    test('MIRRORING TWICE IS THE IDENTITY, over every legal span', () {
      // The algebraic property the whole reflection rests on. Expressed as
      // "reflect the reflected start" rather than by calling the function
      // twice, because the function takes a bool rather than composing.
      for (var start = 0; start < 12; start++) {
        for (var span = 1; span + start <= 12; span++) {
          final once = 12 - start - span;
          final twice = 12 - once - span;
          expect(twice, start, reason: 'start $start span $span');
        }
      }
    });

    test('VERTICAL geometry is untouched — mirroring is lateral only', () {
      final plain = geo.deviceRect(4, 3, spanTwelfths: 6);
      final mirrored = geo.deviceRect(4, 3, spanTwelfths: 6, mirrored: true);

      expect(mirrored.top, plain.top);
      expect(mirrored.bottom, plain.bottom);
      expect(mirrored.width, closeTo(plain.width, 1e-9));
    });

    test('the round trip through ruIndexForTopY still holds when mirrored', () {
      // The existing forward/inverse round trip is what stops drag-to-move
      // drifting. Mirroring must not touch it, because it does not touch Y.
      for (var deviceH = 1; deviceH <= 4; deviceH++) {
        for (var ru = 1; ru <= geo.maxRuIndexFor(deviceH); ru++) {
          final rect = geo.deviceRect(
            ru,
            deviceH,
            startTwelfth: 3,
            spanTwelfths: 6,
            mirrored: true,
          );
          expect(geo.ruIndexForTopY(rect.top, deviceH), ru);
        }
      }
    });
  });

  group('buildRackScene honours Rack.mirrorRearElevation', () {
    RackScene build({required bool mirror, required Face face}) =>
        buildRackScene(
          rack: _rack(mirror: mirror),
          devices: <DeviceInstance>[
            _device(id: 'half', ru: 3, face: face, spanTwelfths: 6),
          ],
          templates: _templates(),
          face: face,
          lod: LodLevel.full,
          measurer: FakeMeasurer(),
        );

    test('the REAR face mirrors when the flag is on (the default)', () {
      final rear = build(mirror: true, face: Face.rear);
      final expected = geo.deviceRect(3, 2, spanTwelfths: 6, mirrored: true);

      expect(rear.devices.single.rect, expected);
      // ...and the hit region moves with it, so selection on the rear
      // elevation targets what the user is looking at.
      expect(rear.scene.hits.single.bounds, expected);
    });

    test('the REAR face does NOT mirror when the flag is off', () {
      final rear = build(mirror: false, face: Face.rear);

      expect(rear.devices.single.rect, geo.deviceRect(3, 2, spanTwelfths: 6));
    });

    test('the FRONT face never mirrors, flag or no flag', () {
      for (final mirror in <bool>[true, false]) {
        final front = build(mirror: mirror, face: Face.front);
        expect(
          front.devices.single.rect,
          geo.deviceRect(3, 2, spanTwelfths: 6),
          reason: 'mirror: $mirror',
        );
      }
    });
  });

  group('TEXT IS NEVER MIRRORED — the assertion that rules out scale(-1)', () {
    RackScene rearScene() => buildRackScene(
      rack: _rack(),
      devices: <DeviceInstance>[
        _device(id: 'a', ru: 1, spanTwelfths: 6),
        _device(id: 'b', ru: 5, startTwelfth: 6, spanTwelfths: 6),
      ],
      templates: _templates(),
      face: Face.rear,
      lod: LodLevel.full,
      measurer: FakeMeasurer(),
    );

    test('no OpTransform in a mirrored rear scene has a negative X scale', () {
      // A canvas `scale(-1, 1)` around the elevation would satisfy every
      // rectangle assertion above and print every designator, name and
      // model string backwards. This is the check that separates the two
      // implementations, so it reads the composed scene's actual
      // transforms rather than trusting the design.
      final transforms = rearScene().scene.ops
          .whereType<OpTransform>()
          .toList();

      expect(transforms, isNotEmpty, reason: 'nothing to check');
      for (final op in transforms) {
        final x = op.m.getColumn(0);
        final y = op.m.getColumn(1);
        expect(x.x, greaterThan(0), reason: 'negative X scale: ${op.m}');
        expect(y.y, greaterThan(0), reason: 'negative Y scale: ${op.m}');
        // A pure translate has a positive determinant; a reflection has a
        // negative one. Belt and braces, because a reflection could also
        // be spelled with off-diagonal terms.
        expect(x.x * y.y - y.x * x.y, greaterThan(0));
      }
    });

    test('every device bracket is a PURE TRANSLATION', () {
      // Asserting the SHAPE is what makes the negative-scale check above
      // meaningful: it confirms there is exactly one kind of transform in a
      // rack scene, so a reflection would have to be a new one.
      for (final op in rearScene().scene.ops.whereType<OpTransform>()) {
        final linear = Matrix4.copy(op.m)..setTranslationRaw(0, 0, 0);
        expect(linear, Matrix4.identity(), reason: '${op.m}');
      }
    });

    test('the two faces emit the SAME text, only in different places', () {
      // Mirroring must not change what is written, only where. If a canvas
      // flip were used the strings would be identical too — so this alone
      // is not the proof; it is the companion to the transform check.
      List<String> textsFor(Face face) => buildRackScene(
        rack: _rack(),
        devices: <DeviceInstance>[_device(id: 'a', ru: 2, face: face)],
        templates: _templates(),
        face: face,
        lod: LodLevel.full,
        measurer: FakeMeasurer(),
      ).scene.ops.whereType<OpText>().map((o) => o.text).toList();

      expect(textsFor(Face.rear), textsFor(Face.front));
    });
  });
}
