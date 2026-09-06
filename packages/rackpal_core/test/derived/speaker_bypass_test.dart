// The transformer bypass, and the level the fix belongs at (`#838`,
// M5-K, DR-131 §11.130).
//
// ═══════════════════════════════════════════════════════════════════════
// ELE-006 WAS PATCHED FIRST AND THAT WAS THE WRONG LEVEL
// ═══════════════════════════════════════════════════════════════════════
// A constant-voltage speaker whose transformer is switched out IS a
// low-impedance speaker, and landing it on a low-Z amplifier output is
// correct. The first attempt taught `ELE-006` to ignore the pairing when
// the source port was bypassed, and the gate immediately returned
// `SIG-002`: the sink's `acceptedFamilies` never listed
// `audio.speaker_cv`, and the source still CALLED itself constant
// voltage.
//
// TWO RULES DISAGREEING WITH ONE PHYSICAL SWITCH is the signal that the
// fact belongs upstream of both. It now lands in
// `resolvePortSignalFamily`, where `#233`'s port-fact resolver already
// lives, and neither rule needed changing.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../validation/fixtures/spring_back_scenarios.dart';

RackDocument _cvIntoLowZ({required bool bypassed}) => springBackPair(
  springBackPort('p', 'audio.speaker_cv', connector: 'conn.euroblock_2'),
  springBackPort(
    'p',
    'audio.speaker_lowz',
    dir: PortDirection.sink,
    connector: 'conn.euroblock_2',
  ),
  fromIsBypassed: bypassed,
);

void main() {
  group('the bypass moves the FAMILY, not just one rule verdict', () {
    test('a bypassed CV port resolves as low impedance', () {
      final doc = _cvIntoLowZ(bypassed: true);
      final target = resolveConnectTarget(
        doc,
        deviceId: springBackA,
        portKey: 'p',
      )!;
      expect(target.signalFamily, const SignalFamilyId('audio.speaker_lowz'));
      expect(
        target.def.signalFamily,
        const SignalFamilyId('audio.speaker_cv'),
        reason:
            'the TEMPLATE still says constant voltage, which is true: the '
            'speaker ships with a transformer and this one is switched out',
      );
    });

    test('and an unbypassed one is unchanged, so the default is a '
        'transformer in circuit', () {
      final doc = _cvIntoLowZ(bypassed: false);
      final target = resolveConnectTarget(
        doc,
        deviceId: springBackA,
        portKey: 'p',
      )!;
      expect(target.signalFamily, const SignalFamilyId('audio.speaker_cv'));
    });

    test('a low-Z port is NEVER bypassed into constant voltage', () {
      // There is no transformer to switch back in, so the move is one
      // way. Asserted because a symmetric implementation would look
      // tidier and would be fabricating hardware.
      final port = Port(
        id: const Uuid('p-lowz'),
        deviceId: const Uuid('d-1'),
        designator: 'SPK-1.p',
        lowZBypass: true,
      );
      final def = springBackPort('p', 'audio.speaker_lowz');
      expect(
        resolvePortSignalFamily(port, def),
        const SignalFamilyId('audio.speaker_lowz'),
      );
    });
  });

  group('so BOTH rules clear, which is the whole point', () {
    test('the known-bad still springs back, so this is not vacuous', () {
      expect(
        springBackRun(_cvIntoLowZ(bypassed: false)),
        isA<SpringBackChip>(),
      );
    });

    test('and the bypassed case clears outright', () {
      // NOT "clears ELE-006". The first fix cleared ELE-006 and SIG-002
      // took its place, which a rule-specific assertion would have
      // called a pass.
      expect(
        springBackRun(_cvIntoLowZ(bypassed: true)),
        isA<SpringBackClear>(),
      );
    });
  });

  test('a user port-family override now reaches tier 2, which it never '
      'did', () {
    // FOUND ON THE WAY, and it was nobody's ticket. `_oneOf` compared
    // `def.signalFamily`, the raw template value, so every correction
    // #233 lets a person make on an instance was invisible to every
    // tier-2 rule. The bypass is what surfaced it.
    final doc = _cvIntoLowZ(bypassed: false);
    final id = derivePortId(springBackA, const PortKey('p'));
    doc.ports[id] = Port(
      id: id,
      deviceId: springBackA,
      designator: 'SRC-1.p',
      templatePortKey: const PortKey('p'),
      overrides: PortOverrides()
        ..signalFamily = const SignalFamilyId('audio.speaker_lowz'),
    );
    expect(springBackRun(doc), isA<SpringBackClear>());
  });
}
