// #755 — DR-080: the accent becomes the body fill, and the ink follows it.
//
// ═════════════════════════════════════════════════════════════════════
// THE CASE THAT MATTERS IS `pure black does not print black on black`
// ═════════════════════════════════════════════════════════════════════
// `accentColor` shipped a control at M4-D and no renderer at all, so for
// four months a user could pick a colour and nothing anywhere showed it.
// DR-059 deferred the fix on a price that turned out to be wrong in both
// halves, and the cost it never named is the one these cases guard: the
// body is filled and then FOUR text ops are drawn over it, all dark inks
// chosen against a near-white default, while one of the eight shipped
// swatches is Rgb(0, 0, 0).
import 'package:rackmate_core/rackmate_core.dart';
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

const _black = Rgb(0, 0, 0);
const _yellow = Rgb(0xF0, 0xE4, 0x42);
const _blue = Rgb(0x00, 0x72, 0xB2);

DeviceInstance _device({Rgb? override}) => DeviceInstance(
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
  overrides: DeviceOverrides(accentColor: override),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    updatedBy: 't',
  ),
);

TemplateBody _body({Rgb? accent}) =>
    buildSeedCatalog()['V01']!..accentColor = accent;

DeviceLayerBuild _build({Rgb? accent, Rgb? override, double height = 88}) =>
    buildDeviceLayer(
      _device(override: override),
      _body(accent: accent),
      deviceH: 1,
      width: 240,
      height: height,
      lod: LodLevel.full,
      palette: const RackPalette(),
      measurer: _M(),
    );

int _bodyFill(DeviceLayerBuild b) =>
    b.ops.whereType<OpRoundRect>().first.fill!.argb;

Set<int> _inks(DeviceLayerBuild b) =>
    b.ops.whereType<OpText>().map((t) => t.style.argb).toSet();

void main() {
  group('the accent becomes the fill, in CR-054 door order', () {
    test('with no accent anywhere the body keeps the palette fill, so an '
        'unaccented rack is byte-for-byte what it was', () {
      expect(_bodyFill(_build()), const RackPalette().deviceFill);
    });

    test('a template accent fills the body', () {
      expect(_bodyFill(_build(accent: _yellow)), _yellow.argb);
    });

    test('an instance override beats the template, because door 1 is the '
        'more specific statement', () {
      expect(
        _bodyFill(_build(accent: _yellow, override: _blue)),
        _blue.argb,
      );
    });

    test('an override with no template accent still fills', () {
      expect(_bodyFill(_build(override: _blue)), _blue.argb);
    });
  });

  group('the ink follows the fill, which is the whole cost DR-059 missed', () {
    test('over a light accent the labels keep the dark palette inks', () {
      const p = RackPalette();
      final inks = _inks(_build(accent: _yellow));
      expect(inks, contains(p.deviceDesignator));
      expect(inks, isNot(contains(p.deviceDesignatorOnDark)));
    });

    test('OVER PURE BLACK THE LABELS GO LIGHT, which is the defect this '
        'ruling exists to prevent: black text on a black device', () {
      const p = RackPalette();
      final inks = _inks(_build(accent: _black));
      expect(inks, contains(p.deviceDesignatorOnDark));
      expect(
        inks,
        isNot(contains(p.deviceDesignator)),
        reason: 'not one label may stay dark over a black body',
      );
    });

    test('the MARK goes light too, or the silhouette disappears on exactly '
        'the bodies that need it most', () {
      const p = RackPalette();
      final path = _build(accent: _black).ops.whereType<OpPath>().first;
      expect(path.stroke?.argb ?? path.fill?.argb, p.deviceDesignatorOnDark);
    });

    test('every one of the four label inks flips together, so no line is '
        'left behind on a dark body', () {
      const p = RackPalette();
      final dark = {
        p.deviceDesignator,
        p.deviceName,
        p.deviceType,
        p.deviceBadge,
      };
      expect(_inks(_build(accent: _black)).intersection(dark), isEmpty);
    });
  });

  test('the fill decision is the shared one, so the layer and the gate '
      'cannot disagree about what "dark" means', () {
    expect(prefersLightInk(_black.argb), isTrue);
    expect(prefersLightInk(_yellow.argb), isFalse);
    expect(_bodyFill(_build(accent: _black)), _black.argb);
  });
}
