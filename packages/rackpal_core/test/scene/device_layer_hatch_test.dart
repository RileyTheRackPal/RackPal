// #754 — DR-083 §11.82.2: where the mark meets a hatch, the mark wins on a
// knocked-out panel.
//
// ═════════════════════════════════════════════════════════════════════
// THESE CASES ASSERT ORDER, NOT PRESENCE, AND THAT IS THE WHOLE POINT
// ═════════════════════════════════════════════════════════════════════
// A backing rect emitted BEFORE the hatch band is drawn over immediately
// and does nothing at all, while still being present in the op list. A
// case counting ops, or even finding the rect and checking its colour,
// passes on that. So the assertions below are about INDEX: after the
// hatch, before the mark.
//
// The collision itself is not hypothetical. `kCategoryDefaultGlyph` maps
// `kCatPassive` to `blank`, and `scene_builder` hatches exactly
// `kCatPassive`, so the devices defaulting to the blank mark are
// precisely the ones buried in 45° lines.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final class _M implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

/// X01, the blank panel: `kCatPassive`, and it INHERITS `blank` from its
/// category, which is the exact pair DR-083 §11.82.2 is about.
TemplateBody _passive() => buildSeedCatalog()['X01']!;

DeviceInstance _device() => DeviceInstance(
  id: const Uuid('d1'),
  kind: DeviceKind.rackDevice,
  templateRef: const TemplateRef(
    templateId: TemplateId('tpl.probe'),
    version: 1,
    contentHash: 'sha256:x',
  ),
  designator: 'BLK-1',
  name: 'Blank',
  placement: const RailPlacement(
    rackId: Uuid('r1'),
    ruIndex: 1,
    face: Face.front,
  ),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    updatedBy: 't',
  ),
);

DeviceLayerBuild _build({required bool hatched}) => buildDeviceLayer(
  _device(),
  _passive(),
  deviceH: 1,
  width: 240,
  height: 22,
  lod: LodLevel.full,
  palette: const RackPalette(),
  measurer: _M(),
  hatched: hatched,
);

int _indexOf<T>(List<DiagramOp> ops) => ops.indexWhere((o) => o is T);
int _lastIndexOf<T>(List<DiagramOp> ops) => ops.lastIndexWhere((o) => o is T);

void main() {
  test('the seeded blank really does inherit `blank`, or every case below '
      'is about a device that does not exist', () {
    final body = _passive();
    expect(body.category, kCatPassive);
    expect(body.glyph, isNull);
    expect(effectiveGlyph(body.glyph, body.category), DeviceGlyph.blank);
  });

  group('the knockout lands between the hatch and the mark', () {
    test('a hatched body emits a backing rect AFTER the last hatch line and '
        'BEFORE the mark', () {
      final ops = _build(hatched: true).ops;
      final lastHatch = _lastIndexOf<OpLine>(ops);
      final backing = _indexOf<OpRect>(ops);
      final mark = _indexOf<OpPath>(ops);

      expect(lastHatch, greaterThan(-1), reason: 'no hatch was drawn');
      expect(backing, greaterThan(-1), reason: 'no backing rect');
      expect(mark, greaterThan(-1), reason: 'no mark');
      expect(
        backing,
        greaterThan(lastHatch),
        reason:
            'a backing rect drawn BEFORE the hatch is painted over and '
            'does nothing, while still being present in the op list',
      );
      expect(backing, lessThan(mark), reason: 'the mark must sit on top');
    });

    test('the knockout is painted in the RESOLVED body fill, so it matches '
        'the body it is cut out of', () {
      final ops = _build(hatched: true).ops;
      final backing = ops.whereType<OpRect>().first;
      final body = ops.whereType<OpRoundRect>().first;

      expect(backing.fill?.argb, body.fill?.argb);
      expect(
        backing.stroke,
        isNull,
        reason: 'an outlined knockout draws a box nobody asked for',
      );
    });

    test('the knockout covers the whole mark, with a bleed', () {
      final ops = _build(hatched: true).ops;
      final r = ops.whereType<OpRect>().first.r;
      const cap = RackTextSizes.designator * kDeviceGlyphCapFactor;

      expect(r.width, greaterThan(cap));
      expect(r.height, greaterThan(cap));
    });
  });

  group('nothing changes for a body that is not hatched', () {
    test('no backing rect at all, because at `full` the body itself is a '
        'round rect and the only OpRect would be the knockout', () {
      final ops = _build(hatched: false).ops;
      expect(ops.whereType<OpRect>(), isEmpty);
      expect(ops.whereType<OpPath>(), hasLength(1));
    });

    test(
      'the knockout costs exactly ONE extra op, on passive bodies only: '
      'the mark is not extra, it draws on every device',
      () {
        expect(
          _build(hatched: true).ops.whereType<OpRect>().length -
              _build(hatched: false).ops.whereType<OpRect>().length,
          1,
        );
      },
    );
  });
}
