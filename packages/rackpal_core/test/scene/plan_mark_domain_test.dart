// A plan mark is coloured by its domain and carries that domain's glyph
// (`#901`, DR-169 §11.168.4 and §11.168.6).
//
// ═══════════════════════════════════════════════════════════════════════
// THE GREYSCALE CASE IS THE POINT OF THE GLYPH, AND IT IS NOT COSMETIC
// ═══════════════════════════════════════════════════════════════════════
// `plan_sheet.dart` SPLICES this scene, so every mark on screen is a mark
// on `T1.01`, and the Installer preset exports greyscale. Canon §14
// records that the eight domain hues COLLIDE in greyscale BY DESIGN:
// analog video against analog audio at L ≈ 0.40, and digital audio,
// network and control together at L ≈ 0.22-0.29. PAL-3 resolves that for
// a LINE by keeping its dash class and line weight; a filled dot has
// neither.
//
// So the marks for two domains in one luminance band have to differ in
// their OPS rather than only in their colours, and that is what the case
// below asserts: strip every colour out and the three in the tightest
// band still draw three different things.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 9, 14);

PlanUnderlay _underlay() => PlanUnderlay(
  id: const Uuid('ul-1'),
  name: 'Level 1',
  imageMember: 'plans/a.png',
  format: PlanImageFormat.png,
  pixelWidth: 600,
  pixelHeight: 400,
  contentHash: 'sha256:test',
  order: const FracIndex('a0'),
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
);

PlanScene _scene(
  PlanPinCarrier carrier,
  SignalDomainId? domain, {
  Map<SignalDomainId, SignalDomainDef>? domains,
}) => buildPlanScene(
  underlay: _underlay(),
  // Any radius serves: every case here compares one mark with another.
  markerRadius: 7,
  markerWeight: 1,
  pins: [
    PlanPinSubject(
      entityId: const Uuid('e1'),
      at: const PxPt(300, 200),
      carrier: carrier,
      domain: domain,
    ),
  ],
  domains: domains ?? buildSeedRegistries().signalDomains,
);

/// The ops of the one marker, with every colour removed.
///
/// **A GREYSCALE EXPORT DROPS HUE ENTIRELY** (PAL-3), so this is what the
/// printed sheet has left to tell two marks apart with.
List<String> _shapeOnly(PlanScene s) => [
  // op 0 is the underlay image.
  for (final op in s.scene.ops.skip(1))
    switch (op) {
      OpCircle() => 'circle r=${op.radius} strokeWidth=${op.stroke?.widthPt}',
      OpRect() => 'rect ${op.r.width}x${op.r.height}',
      OpLine() => 'line',
      // THE PATH ITSELF, ROUNDED, NOT A SUMMARY OF IT. A command COUNT
      // said a square and a diamond were the same mark, which is how the
      // first version of this case passed over two identical grey dots.
      // A greyscale printer reads the geometry.
      OpPath() =>
        'path filled=${op.fill != null} '
            '${op.p.commands.map((c) => c.toString()).join(",")}',
      _ => op.runtimeType.toString(),
    },
];

void main() {
  final registries = buildSeedRegistries();
  const net = SignalDomainId('net');
  const ctl = SignalDomainId('ctl');
  const digitalAudio = SignalDomainId('audio.digital');

  group('colour comes from the domain (§11.168.4)', () {
    test('an outlet mark is filled with its domain hue', () {
      final scene = _scene(PlanPinCarrier.outlet, net);
      final circle = scene.scene.ops.whereType<OpCircle>().single;

      expect(circle.fill?.argb, registries.signalDomains[net]!.color.argb);
    });

    test('AN UNKNOWN DOMAIN DRAWS THE NEUTRAL MARK, never a guess (G4)', () {
      final scene = _scene(PlanPinCarrier.outlet, null);
      final circle = scene.scene.ops.whereType<OpCircle>().single;

      expect(circle.fill?.argb, const PlanPalette().markerFill.argb);
      expect(
        scene.scene.ops.whereType<OpPath>(),
        isEmpty,
        reason:
            'no domain means no glyph, rather than a glyph for the '
            'first domain in some order',
      );
    });

    test('a domain the registry does not define is unknown, not a crash', () {
      // A document written against a catalogue this build does not have.
      final scene = _scene(
        PlanPinCarrier.outlet,
        const SignalDomainId('domain.invented'),
      );
      final circle = scene.scene.ops.whereType<OpCircle>().single;

      expect(circle.fill?.argb, const PlanPalette().markerFill.argb);
    });

    test('THE RACK IS UNTOUCHED, because it is the datum and not a ninth '
        'domain (§11.168.8)', () {
      final withDomain = _shapeOnly(_scene(PlanPinCarrier.rack, net));
      final without = _shapeOnly(_scene(PlanPinCarrier.rack, null));

      expect(withDomain, without);
      expect(
        _scene(PlanPinCarrier.rack, net).scene.ops.whereType<OpPath>(),
        isEmpty,
        reason: 'a rack draws no glyph: its square already carries a cross',
      );
    });
  });

  group('the glyph is what survives the print (§11.168.6)', () {
    test('a mark with a domain carries one', () {
      final scene = _scene(PlanPinCarrier.outlet, net);

      expect(scene.scene.ops.whereType<OpPath>(), hasLength(1));
    });

    test('THE THREE DOMAINS IN ONE LUMINANCE BAND STILL DIFFER WITH EVERY '
        'COLOUR REMOVED', () {
      // Canon §14: digital audio, network and control sit at L 0.22-0.29,
      // which is a collision the palette places DELIBERATELY and resolves
      // on the other channels. On a line those are dash and weight. On a
      // mark they are the glyph.
      final shapes = {
        for (final d in [digitalAudio, net, ctl])
          d.v: _shapeOnly(_scene(PlanPinCarrier.outlet, d)),
      };

      expect(
        shapes.values.map((s) => s.join('|')).toSet(),
        hasLength(3),
        reason:
            'two of these print as the same grey dot, so a greyscale '
            'T1.01 cannot tell a keypad from a switch',
      );
    });

    test('and so do all eight, pairwise', () {
      final byDomain = {
        for (final d in registries.signalDomains.keys)
          d.v: _shapeOnly(_scene(PlanPinCarrier.outlet, d)).join('|'),
      };

      expect(byDomain.values.toSet(), hasLength(byDomain.length));
    });
  });

  group('the carrier still reads (§11.168.6)', () {
    test('A DEVICE IS NOT A DROP even when both carry the same glyph', () {
      // The device mark carried an inner dot to say so, and that is the
      // space the glyph now occupies. The ring weight is what replaced it,
      // and it has to survive greyscale like everything else here.
      final device = _shapeOnly(_scene(PlanPinCarrier.device, net));
      final outlet = _shapeOnly(_scene(PlanPinCarrier.outlet, net));

      expect(device, isNot(outlet));
    });

    test('and the three carriers are three marks, as docs/15 §3.4 has it', () {
      final shapes = {
        for (final c in PlanPinCarrier.values)
          c.name: _shapeOnly(_scene(c, net)).join('|'),
      };

      expect(shapes.values.toSet(), hasLength(3));
    });
  });
}
