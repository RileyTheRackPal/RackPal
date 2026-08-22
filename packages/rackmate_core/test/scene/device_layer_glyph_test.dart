// #753 — the mark reaches the elevation. DR-059's artwork placed by
// DR-083 §11.82.1.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THESE CASES EXIST AT ALL, AND IT IS NOT BELT AND BRACES
// ═════════════════════════════════════════════════════════════════════
// `device_layer` gained an op on EVERY device and all 3152 core cases
// stayed green, because nothing anywhere asserts the elevation's op
// profile. The schematic has `schematic_perf_test`'s baselines; the
// elevation has none. So a mark that never drew, or one that drew twice,
// or one that pushed the designator off the body, would all have shipped
// green. These cases are that missing floor, and they assert the
// ARTIFACT a caller receives rather than any intermediate.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// Deterministic, so a case needs no TTF and no golden.
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

DeviceInstance _device() => DeviceInstance(
  id: const Uuid('d1'),
  kind: DeviceKind.rackDevice,
  templateRef: const TemplateRef(
    templateId: TemplateId('tpl.probe'),
    version: 1,
    contentHash: 'sha256:x',
  ),
  designator: 'AMP-1',
  name: 'Probe',
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

/// A real seeded body, so the case exercises the resolution a shipped
/// project actually takes rather than a hand-built fixture.
TemplateBody _body() => buildSeedCatalog().values.first;

DeviceLayerBuild _build({
  double width = 240,
  double height = 22,
  LodLevel lod = LodLevel.full,
  TemplateBody? body,
}) => buildDeviceLayer(
  _device(),
  body ?? _body(),
  deviceH: 1,
  width: width,
  height: height,
  lod: lod,
  palette: const RackPalette(),
  measurer: _M(),
);

List<OpPath> _paths(DeviceLayerBuild b) => b.ops.whereType<OpPath>().toList();
List<OpText> _texts(DeviceLayerBuild b) => b.ops.whereType<OpText>().toList();

void main() {
  group('the mark is drawn, which 3152 green cases could not see', () {
    test('a seeded body emits exactly one path, and that is the mark', () {
      expect(_paths(_build()), hasLength(1));
    });

    test('an author who chose `none` gets no mark, and that is a choice '
        'rather than an omission', () {
      final body = _body()..glyph = DeviceGlyph.none;
      expect(_paths(_build(body: body)), isEmpty);
    });

    test('the mark is resolved through the CATEGORY, because glyph is null '
        'on all 48 seeds and reading it directly would draw nothing', () {
      final body = _body();
      expect(body.glyph, isNull);
      expect(_paths(_build(body: body)), hasLength(1));
    });
  });

  group('the text shifts by the advance, and the badge does not', () {
    test('the designator starts one advance right of the padding', () {
      final withMark = _texts(_build()).first;
      final body = _body()..glyph = DeviceGlyph.none;
      final without = _texts(_build(body: body)).first;
      expect(
        withMark.at.x - without.at.x,
        closeTo(deviceGlyphAdvance(RackTextSizes.designator), 1e-9),
      );
    });

    test('the U-height badge stays pinned to the right edge, because it is '
        'anchored there and the mark is on the other side', () {
      final withMark = _texts(_build())[1];
      final body = _body()..glyph = DeviceGlyph.none;
      final without = _texts(_build(body: body))[1];
      expect(withMark.at.x, without.at.x);
    });

    test('name and type shift with the designator, so the text column has '
        'one straight left edge rather than a step', () {
      // Tall enough that name and type both survive their fit checks.
      final texts = _texts(_build(height: 88));
      expect(texts.length, greaterThanOrEqualTo(3));
      final lefts = [texts[0].at.x, for (final t in texts.skip(2)) t.at.x];
      expect(lefts.toSet(), hasLength(1), reason: 'ragged left edge: $lefts');
    });
  });

  group('the guard drops the MARK and never a line of text', () {
    test('a body too narrow for the mark still prints its designator', () {
      final narrow = _build(width: 12);
      expect(_paths(narrow), isEmpty, reason: 'the mark should be given up');
      expect(
        _texts(narrow).map((t) => t.text),
        contains('AMP-1'),
        reason:
            'THE DESIGNATOR MUST SURVIVE: dropping the mark may never '
            'suppress a line, which is the blackout this shape avoids',
      );
    });

    test('dropping the mark is not reported as a dropped label, because a '
        'caller told that would be told something false', () {
      expect(_build(width: 12).labelDropped, isFalse);
    });

    test('a body that keeps its mark keeps its designator too', () {
      expect(_paths(_build()), hasLength(1));
      expect(_texts(_build()).map((t) => t.text), contains('AMP-1'));
    });
  });

  test('no mark at the block tier, where the designator is centred and no '
      'sheet is ever drawn', () {
    expect(_paths(_build(lod: LodLevel.block)), isEmpty);
  });
}
