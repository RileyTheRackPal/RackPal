// DR-126 §11.125: the IR split, asserted over the SHIPPED CATALOGUE.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS FILE IS NOT JUST A ROW IN `spring_back_scenarios.dart`
// ═════════════════════════════════════════════════════════════════════
// There is a row there too, and it is not enough. DR-125 §11.124.5
// records the reason in the course of missing this very defect: "the
// AC-051 corpus is complete at 28/28 and saw none of them, because a pair
// proves a rule fires, not that it fires correctly." Those fixtures
// AUTHOR their own ports, so they demonstrate the predicate against
// families the test chose. The defect DR-126 fixes was never in the
// predicate. It was that eleven shipped ports declared the wrong family,
// and no fixture that writes its own ports can see that.
//
// So the pairs below take their family, direction, connector and
// accepted families from the shipped builders, BOTH of them: the base
// catalogue and the role variants. The port KEY is still rewritten to
// `p`, because that is what `springBackPair` addresses and a key carries
// no signal fact; every field a rule actually reads comes from the
// catalogue.
//
// ═════════════════════════════════════════════════════════════════════
// THE PROPERTY, IN ONE SENTENCE
// ═════════════════════════════════════════════════════════════════════
// An IR jack is a hazard to an emitter if and only if it is POWERED, and
// powered is what `ctl.ir_receiver` now means.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../validation/fixtures/spring_back_scenarios.dart';

/// Every seeded port carrying an IR family, as `(templateId, port)`.
///
/// BOTH MAPS, AND THE SECOND ONE IS NOT DECORATION. `buildSeedCatalog()`
/// alone returns 17 IR device inputs; the eighteenth is on
/// `V06:receiver`, a ROLE VARIANT, which lives in a different builder and
/// would have escaped this sweep in silence. `insert_receiver.dart`
/// places that exact template as the `SIG-001` remedy, so it is the one
/// IR port in the catalogue the product creates on a user's behalf.
List<(String, PortDef)> _irPorts() => [
  for (final map in [buildSeedCatalog(), buildSeedRoleVariants()])
    for (final entry in map.entries)
      for (final port in entry.value.ports)
        if (port.signalFamily.v.startsWith('ctl.ir_')) (entry.key, port),
];

/// The same port at key `p`, so `springBackPair` can address it. Family,
/// direction, connector AND accepted families are the catalogue's, which
/// is the whole point.
///
/// `accepts` IS NOT OPTIONAL HERE and leaving it out is how the first
/// draft of this file failed: `SIG-002` fired on every pair, because a
/// pin that does not carry the catalogue's `acceptedFamilies` refuses
/// every family but its own. A helper that quietly drops the field under
/// test would have made this file agree with the defect.
PortDef _asPin(PortDef p) => springBackPort(
  'p',
  p.signalFamily.v,
  dir: p.direction,
  connector: p.connector.v,
  accepts: [for (final f in p.acceptedFamilies) f.v],
);

void main() {
  group('the shipped IR ports after DR-126', () {
    test('every one names a family the registry actually defines', () {
      final families = buildSeedRegistries().signalFamilies;
      for (final (id, port) in _irPorts()) {
        expect(
          families[port.signalFamily],
          isNotNull,
          reason: '$id.${port.key.v} names ${port.signalFamily.v}',
        );
      }
    });

    test('the powered family holds only the receiver-eye circuit', () {
      final powered = [
        for (final (id, port) in _irPorts())
          if (port.signalFamily.v == 'ctl.ir_receiver') '$id.${port.key.v}',
      ]..sort();
      // C02's four RX jacks and its IR IN, plus F15's pigtail. NAMED
      // rather than counted: a count of six passes on the wrong six, and
      // getting this membership wrong is what the ruling is about.
      expect(powered, [
        'C02.ir.in.processor',
        'C02.ir.rx.1',
        'C02.ir.rx.2',
        'C02.ir.rx.3',
        'C02.ir.rx.4',
        'F15.pigtail',
      ]);
    });

    test('a powered jack keeps the ring, so it is TRS and xantech-stereo', () {
      for (final (id, port) in _irPorts()) {
        if (port.signalFamily.v != 'ctl.ir_receiver') continue;
        expect(
          port.connector.v,
          'conn.3_5mm_trs',
          reason:
              '$id.${port.key.v} carries +12 V on the sleeve and needs the '
              'ring for ground',
        );
        expect(port.pinoutVariant, 'xantech-stereo', reason: id);
      }
    });

    test(
      'a passive device input is TS and mono-tip-sleeve, so it agrees with '
      'the emitter driving it',
      () {
        final direct = _irPorts()
            .where((p) => p.$2.signalFamily.v == 'ctl.ir_direct')
            .toList();
        // EIGHTEEN PORTS FROM ELEVEN DECLARATION SITES, and the gap is
        // not a discrepancy: the eight-zone matrix amplifier declares
        // `zone.$zone.ir` inside a loop. The ruling counts sites because
        // that is what was edited; this counts ports because that is what
        // ships, and saying so here stops the next reader reconciling two
        // numbers that were never the same measurement.
        expect(direct, hasLength(18));
        for (final (id, port) in direct) {
          expect(port.connector.v, 'conn.3_5mm_ts', reason: id);
          expect(port.pinoutVariant, 'mono-tip-sleeve', reason: id);
          expect(port.direction, PortDirection.sink, reason: id);
          expect(
            port.acceptedFamilies.map((f) => f.v),
            contains('ctl.ir_emitter'),
            reason:
                '$id: without this SIG-002 refuses the emitter lead this '
                'jack exists to receive, and DIR-003 going quiet buys '
                'nothing but a different sentence',
          );
        }
      },
    );

    test('no IR port anywhere leaves its pinout unsaid (AC-052)', () {
      for (final (id, port) in _irPorts()) {
        expect(
          (port.pinoutVariant ?? '').trim(),
          isNotEmpty,
          reason: '$id.${port.key.v}: the field is safety-adjacent',
        );
      }
    });
  });

  group('DIR-003 over the real catalogue, which is where it was wrong', () {
    /// Every seeded emitter output paired against every seeded IR sink.
    Iterable<(String, PortDef, String, PortDef)> pairs() sync* {
      final ports = _irPorts();
      for (final (fromId, from) in ports) {
        if (from.signalFamily.v != 'ctl.ir_emitter') continue;
        if (from.direction != PortDirection.source) continue;
        for (final (toId, to) in ports) {
          if (to.direction != PortDirection.sink) continue;
          yield (fromId, from, toId, to);
        }
      }
    }

    test(
      'an emitter output into a DEVICE INPUT is silent, and this is the '
      'case that used to spring back saying "destroys the emitter"',
      () {
        var checked = 0;
        for (final (fromId, from, toId, to) in pairs()) {
          if (to.signalFamily.v != 'ctl.ir_direct') continue;
          expect(
            springBackRun(springBackPair(_asPin(from), _asPin(to))),
            isA<SpringBackClear>(),
            reason: '$fromId.${from.key.v} -> $toId.${to.key.v}',
          );
          checked++;
        }
        expect(checked, greaterThan(0), reason: 'the sweep found no pairs');
      },
    );

    test(
      'an emitter output into a POWERED jack still springs back, because '
      'that is the connection that destroys the emitter',
      () {
        var checked = 0;
        for (final (fromId, from, toId, to) in pairs()) {
          if (to.signalFamily.v != 'ctl.ir_receiver') continue;
          final verdict = springBackRun(
            springBackPair(_asPin(from), _asPin(to)),
          );
          expect(
            verdict,
            isA<SpringBackChip>(),
            reason: '$fromId.${from.key.v} -> $toId.${to.key.v}',
          );
          expect(
            (verdict as SpringBackChip).rule,
            SpringBackRule.irEmitterIntoReceiver,
          );
          checked++;
        }
        expect(checked, greaterThan(0), reason: 'the sweep found no pairs');
      },
    );
  });
}
