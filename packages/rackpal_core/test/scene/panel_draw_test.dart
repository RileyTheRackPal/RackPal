// `buildPanelLayer` — the rear panel as ink, not as coordinates.
//
// `panel_layer_test.dart` covers the LAYOUT (`#226`). This covers the
// DRAWING (`#229`), and the two are separate questions: the layout can be
// right while the drawing loses a cutout, and the failure would be
// invisible in the builder and visible only on the sheet that gets taped
// inside a rack door.
//
// The assertions here are about the ARTIFACT — what ink exists, where, and
// in what colour — never about how the loop that emitted it is written.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final class _Measurer implements TextMeasurer {
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

/// A measurer that reports every string as ABSURDLY wide, so the "only if
/// it fits" branch can be exercised without inventing a template whose
/// labels happen to be long.
final class _WideMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const TextMetrics(
        advanceWidth: 10000,
        ascent: 1,
        descent: 1,
        capHeight: 1,
        xHeight: 1,
        lineHeight: 1,
      );
}

final Map<String, TemplateBody> _seed = buildSeedCatalog();
final Registries _registries = buildSeedRegistries();

/// SEED ARCHETYPES WHEREVER POSSIBLE, for `panel_layer_test.dart`'s own
/// stated reason: the claim is "zero-authoring correct rear panel", and a
/// body invented here would prove the arithmetic rather than that the 48
/// shipped templates draw.
TemplateBody _seedBody(String id) => _seed[id]!;

PortDef _port(
  String key,
  String connector, {
  String order = 'a0',
  String label = '',
  PanelPosition? position,
}) => PortDef(
  key: PortKey(key),
  label: label.isEmpty ? key : label,
  connector: ConnectorTypeId(connector),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  order: FracIndex(order),
  position: position,
);

TemplateBody _body({int frontU = 1, List<PortDef> ports = const []}) =>
    TemplateBody(
      manufacturer: 'Generic',
      model: '',
      displayName: 'Fixture',
      frontU: frontU,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
      ports: ports,
    );

List<PortDef> _ports(int n, {String connector = 'conn.xlr3'}) => [
  for (var i = 0; i < n; i++)
    _port(
      'p$i',
      connector,
      order: 'a${i.toString().padLeft(3, '0')}',
      label: 'J${i + 1}',
    ),
];

void main() {
  group('buildPanelLayer draws what buildPanelGeometry laid out', () {
    test('one cutout per slot, and the panel outline around them', () {
      final body = _body(ports: _ports(4));
      final panel = buildPanelGeometry(body: body, registries: _registries);
      final built = buildPanelLayer(
        panel,
        body: body,
        measurer: _Measurer(),
      );

      expect(panel.slots, hasLength(4), reason: 'fixture stopped laying out');
      // Four cutouts, drawn as round rects. The panel outline and the
      // chassis field are plain rects, so the two never collide in this
      // count — which is why the cutout is the shape it is.
      expect(
        built.ops.whereType<OpRoundRect>(),
        hasLength(4),
        reason: 'a slot was laid out and never drawn',
      );
      expect(
        built.ops.whereType<OpRect>().length,
        greaterThanOrEqualTo(2),
        reason: 'panel outline and 432mm chassis field',
      );
    });

    test('the chassis field is drawn INSIDE the panel, which is the whole '
        'of AC-032 made visible', () {
      final body = _body(ports: _ports(2));
      final panel = buildPanelGeometry(body: body, registries: _registries);
      final built = buildPanelLayer(panel, body: body, measurer: _Measurer());

      final rects = built.ops.whereType<OpRect>().toList();
      expect(rects.length, 2);
      final outline = rects.first;
      final chassis = rects.last;
      // 432 is strictly inside 482.6, and the field is centred, so the
      // inset is equal on both sides. A regression that flowed across the
      // PANEL width would make these equal and draw jacks over the ears.
      expect(chassis.r.left, greaterThan(outline.r.left));
      expect(chassis.r.right, lessThan(outline.r.right));
      expect(
        chassis.r.left - outline.r.left,
        closeTo(outline.r.right - chassis.r.right, 1e-9),
        reason: 'the chassis field is not centred on the panel',
      );
      expect(chassis.stroke?.dash, isNotNull, reason: 'chassis reads dashed');
    });

    test('an overflowing cutout is DRAWN and FLAGGED, not dropped and not '
        'clipped — DR-105 §11.104.8', () {
      // A SEEDED ARCHETYPE, and this is the case that made the fixture
      // rule worth following. An invented 40-port body does NOT overflow:
      // an RJ45 cutout is 10 mm, so 40 of them is 400 mm inside a 432 mm
      // chassis and one row. `#226` found the real cases by measuring, and
      // N01 (48-port access switch, 1U) is one of exactly two.
      final body = _seedBody('N01');
      final panel = buildPanelGeometry(body: body, registries: _registries);
      expect(
        panel.overflowed,
        isNotEmpty,
        reason: 'fixture stopped overflowing; this test then proves nothing',
      );

      final built = buildPanelLayer(panel, body: body, measurer: _Measurer());
      final cutouts = built.ops.whereType<OpRoundRect>().toList();
      expect(
        cutouts,
        hasLength(panel.slots.length),
        reason: 'an overflowing slot was dropped from the drawing',
      );

      const chrome = PanelPalette();
      final flagged = cutouts
          .where((o) => o.stroke?.argb == chrome.overflowStroke)
          .length;
      expect(
        flagged,
        panel.overflowed.length,
        reason: 'the flag count must equal the overflow count exactly',
      );

      // And the ink reaches BELOW the panel, which is the visible half of
      // the ruling: a reader has to be able to see that it does not fit.
      final panelRect = built.ops.whereType<OpRect>().first.r;
      expect(
        built.inkBounds!.bottom,
        greaterThan(panelRect.bottom),
        reason: 'overflow ink was folded back inside the panel bounds',
      );
    });

    test('a nudged cutout reads as authored, by weight and outline, never '
        'as a different kind of jack', () {
      final body = _body(ports: _ports(3));
      body.ports[1].position = const PanelPosition(
        ruOffset: 0,
        xTwelfth: 6,
        xFineNm: Len.zero,
        yFineNm: Len.zero,
      );
      final panel = buildPanelGeometry(body: body, registries: _registries);
      expect(panel.slots.where((s) => s.nudged), hasLength(1));

      final built = buildPanelLayer(panel, body: body, measurer: _Measurer());
      const chrome = PanelPalette();
      final nudged = built.ops
          .whereType<OpRoundRect>()
          .where((o) => o.stroke?.argb == chrome.nudgedStroke)
          .toList();
      expect(nudged, hasLength(1));
      // Heavier, and still a round rect of the same radius: the cutout is
      // the same hole in the same metal, and only its provenance differs.
      final plain = built.ops.whereType<OpRoundRect>().firstWhere(
        (o) => o.stroke?.argb == chrome.cutoutStroke,
      );
      expect(nudged.single.stroke!.widthPt, greaterThan(plain.stroke!.widthPt));
      expect(nudged.single.radii, plain.radii);
    });

    test('a designator is drawn only if it MEASURES narrower than its own '
        'cutout, because an overhanging label names the wrong hole', () {
      final body = _body(ports: _ports(4));
      final panel = buildPanelGeometry(body: body, registries: _registries);

      final normal = buildPanelLayer(panel, body: body, measurer: _Measurer());
      expect(
        normal.ops.whereType<OpText>(),
        isNotEmpty,
        reason: 'short labels on wide XLR cutouts should fit',
      );

      final wide = buildPanelLayer(
        panel,
        body: body,
        measurer: _WideMeasurer(),
      );
      expect(
        wide.ops.whereType<OpText>(),
        isEmpty,
        reason: 'nothing measured narrow enough, so nothing may be drawn',
      );
      // The cutouts are unaffected — suppression drops the LABEL, never
      // the hole.
      expect(
        wide.ops.whereType<OpRoundRect>().length,
        normal.ops.whereType<OpRoundRect>().length,
      );
      expect(
        wide.minTextPt,
        double.infinity,
        reason: 'no text was emitted, so there is no smallest size',
      );
    });

    test('a port whose label is empty draws its cutout and no text', () {
      final body = _body(
        ports: [
          for (final k in ['a', 'b'])
            PortDef(
              key: PortKey(k),
              label: '',
              connector: const ConnectorTypeId('conn.xlr3'),
              signalFamily: const SignalFamilyId('audio.analog.line'),
              face: Face.rear,
              order: FracIndex(k),
            ),
        ],
      );
      final panel = buildPanelGeometry(body: body, registries: _registries);
      final built = buildPanelLayer(panel, body: body, measurer: _Measurer());
      expect(built.ops.whereType<OpRoundRect>(), hasLength(2));
      expect(built.ops.whereType<OpText>(), isEmpty);
    });

    test('two calls on one body emit equal op lists — the drawing is as '
        'deterministic as the layout it comes from', () {
      final body = _body(frontU: 2, ports: _ports(12));
      final panel = buildPanelGeometry(body: body, registries: _registries);
      final a = buildPanelLayer(panel, body: body, measurer: _Measurer());
      final b = buildPanelLayer(panel, body: body, measurer: _Measurer());
      expect(a.ops.length, b.ops.length);
      expect(a.inkBounds, b.inkBounds);
      for (var i = 0; i < a.ops.length; i++) {
        expect(a.ops[i].runtimeType, b.ops[i].runtimeType, reason: 'op $i');
      }
    });

    test('a body that occupies no U still lays out and still draws, and its '
        'fill is 0% because there is no panel to fill', () {
      // WRITTEN AS AN ASSUMPTION AND CORRECTED BY THE RUN. The guess was
      // that a zero-U body draws nothing. It lays out and draws normally:
      // `frontU`/`rearU` are RACK occupancy, and a wall plate or a field
      // device has none while still having a plate with holes in it.
      //
      // `fillPermille` is the part that is deliberate rather than
      // incidental — it returns 0 on a zero-area panel and the field is
      // documented as meaning "a field device rather than a full one",
      // which is G4's shape: report the unknown, never fabricate a total.
      final body = _body(frontU: 0, ports: _ports(3));
      final panel = buildPanelGeometry(body: body, registries: _registries);
      expect(panel.height, Len.zero);
      expect(panel.fillPermille, 0);
      expect(panel.slots, hasLength(3), reason: 'the plate still has holes');

      final built = buildPanelLayer(panel, body: body, measurer: _Measurer());
      expect(built.ops.whereType<OpRoundRect>(), hasLength(3));
      // The DOCK is where this becomes a non-drawing: `_PanelPreview`
      // refuses a zero-height panel and says why, rather than showing a
      // degenerate strip. That belongs in the widget, not in the layer,
      // because the layer has no idea what it is being drawn into.
    });
  });
}
