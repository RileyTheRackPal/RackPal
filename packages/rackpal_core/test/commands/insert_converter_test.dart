// DR-128 §11.127.3: `SIG-002`'s remedy, driven through a real
// transaction.
//
// ═════════════════════════════════════════════════════════════════════
// THE ARTIFACT IS "BOTH RULES GO QUIET ON BOTH NEW CABLES"
// ═════════════════════════════════════════════════════════════════════
// The converter's ports are authored from the two pins, so `SIG-002` and
// `CON-001` clear on each side by CONSTRUCTION rather than by being
// suppressed. A test that asserted "the device has two ports" would pass
// on a converter whose families were the wrong way round, which is the
// one mistake this file can actually make.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../validation/fixtures/spring_back_scenarios.dart';

final _at = DateTime.utc(2026, 9, 5);

/// An HDBaseT output facing a composite input: two families that do not
/// agree, on connectors that do not mate either.
///
/// The source's connector is left to `springBackPort`'s default, which is
/// `conn.rj45` and is what HDBaseT actually runs on. Stating it here would
/// be redundant, and the assertions below name it explicitly anyway.
RackDocument _needsConverter() => springBackPair(
  springBackPort('p', 'video.hdbaset'),
  springBackPort(
    'p',
    'video.composite',
    dir: PortDirection.sink,
    connector: 'conn.rca',
  ),
);

ConnectTarget _src(RackDocument doc) =>
    resolveConnectTarget(doc, deviceId: springBackA, portKey: 'p')!;
ConnectTarget _snk(RackDocument doc) =>
    resolveConnectTarget(doc, deviceId: springBackB, portKey: 'p')!;

void main() {
  late RackDocument doc;
  late DocumentController controller;

  setUp(() {
    doc = _needsConverter();
    controller = DocumentController(doc, clock: FixedClock(_at));
  });

  /// Runs the remedy the way the screen will.
  InsertConverterResult run() {
    late InsertConverterResult result;
    controller.transact(LabelKey.connectPorts, (tx) {
      result = insertSignalConverter(
        tx,
        doc: doc,
        from: _src(doc),
        to: _snk(doc),
        now: _at,
        actor: 'test',
      );
    });
    return result;
  }

  group('the premise, so nothing below is vacuous', () {
    test('SIG-002 fires on the bare pair', () {
      final verdict = evaluateSpringBack(doc, _src(doc), _snk(doc));
      expect(verdict, isA<SpringBackChip>());
      expect(
        (verdict as SpringBackChip).rule,
        SpringBackRule.familyNotAccepted,
      );
    });

    test('and the fixture starts with two devices and no cables', () {
      expect(doc.devices, hasLength(2));
      expect(doc.links, isEmpty);
    });
  });

  group('what the remedy leaves behind', () {
    test('a third device, off-rack, named for what it bridges', () {
      final result = run();
      expect(result, isA<InsertConverterDone>());
      final done = result as InsertConverterDone;
      expect(doc.devices, hasLength(3));
      final conv = doc.devices[done.converterId]!;
      expect(conv.placement, isA<OffRackPlacement>());
      expect(done.displayName, contains('Converter'));
      expect(
        done.displayName,
        contains('HDBaseT'),
        reason:
            'the family DISPLAY name, not its id, because this string '
            'is what a person reads on the sheet',
      );
    });

    test('two cables, one on each side, in ONE undo entry', () {
      run();
      expect(doc.links, hasLength(2));
      controller.undoLast();
      expect(
        doc.links,
        isEmpty,
        reason:
            'one undo takes back the whole '
            'remedy, not the last cable of it',
      );
      expect(doc.devices, hasLength(2));
    });

    test('and the template lands in the PROJECT, so the shipped catalogue '
        'is untouched (CR-061 stays at 49)', () {
      final result = run() as InsertConverterDone;
      final conv = doc.devices[result.converterId]!;
      final id = conv.templateRef.templateId.v;
      expect(id, startsWith('conv.'));
      expect(doc.templates.keys.any((k) => k.startsWith(id)), isTrue);
      expect(
        buildSeedCatalog().keys,
        isNot(contains(id)),
        reason: 'a minted converter is project data, never a seed',
      );
    });
  });

  group('the property the whole design rests on', () {
    test('SIG-002 and CON-001 are both silent on BOTH new cables', () {
      final done = run() as InsertConverterDone;
      final inPin = resolveConnectTarget(
        doc,
        deviceId: done.converterId,
        portKey: kConverterInKey,
      )!;
      final outPin = resolveConnectTarget(
        doc,
        deviceId: done.converterId,
        portKey: kConverterOutKey,
      )!;

      for (final (a, b, what) in [
        (_src(doc), inPin, 'source into the converter'),
        (outPin, _snk(doc), 'converter into the sink'),
      ]) {
        expect(
          evaluateSpringBack(doc, a, b),
          isA<SpringBackClear>(),
          reason:
              '$what still springs back, so the remedy moved the problem '
              'rather than fixing it',
        );
      }
    });

    test('the input takes the SOURCE end and the output takes the SINK '
        'end, which is the one thing that can be backwards', () {
      final done = run() as InsertConverterDone;
      final body = bodyFor(doc.devices[done.converterId]!, doc.templates)!;
      final inPort = body.ports.firstWhere(
        (p) => p.key.v == kConverterInKey,
      );
      final outPort = body.ports.firstWhere(
        (p) => p.key.v == kConverterOutKey,
      );
      expect(inPort.signalFamily.v, 'video.hdbaset');
      expect(inPort.connector.v, 'conn.rj45');
      expect(inPort.direction, PortDirection.sink);
      expect(outPort.signalFamily.v, 'video.composite');
      expect(outPort.connector.v, 'conn.rca');
      expect(outPort.direction, PortDirection.source);
    });

    test('it states no wattage and no model, because nothing has said '
        'what they are (G4, DR-120 precedent)', () {
      final done = run() as InsertConverterDone;
      final body = bodyFor(doc.devices[done.converterId]!, doc.templates)!;
      expect(body.model, isEmpty);
      expect(body.manufacturer, isEmpty);
      expect(body.weight, isNull);
    });

    test('the template id is deterministic, so the same conversion twice '
        'is one body rather than two', () {
      expect(
        converterTemplateId(
          const SignalFamilyId('video.hdbaset'),
          const SignalFamilyId('video.composite'),
        ),
        'conv.video_hdbaset-to-video_composite',
      );
      // Direction is part of the meaning: these are different boxes.
      expect(
        converterTemplateId(
          const SignalFamilyId('video.composite'),
          const SignalFamilyId('video.hdbaset'),
        ),
        isNot(
          converterTemplateId(
            const SignalFamilyId('video.hdbaset'),
            const SignalFamilyId('video.composite'),
          ),
        ),
      );
    });
  });

  group('what it refuses, and why each one is reachable', () {
    test('two ends already carrying one family have nothing to convert', () {
      doc = springBackPair(
        springBackPort('p', 'video.composite', connector: 'conn.rca'),
        springBackPort(
          'p',
          'video.composite',
          dir: PortDirection.sink,
          connector: 'conn.rca',
        ),
      );
      controller = DocumentController(doc, clock: FixedClock(_at));
      final result = run();
      expect(result, isA<InsertConverterRefused>());
      expect(
        (result as InsertConverterRefused).message,
        contains('nothing to convert'),
      );
    });

    test('a sink that has since learned to accept the family is refused, '
        'because a port override can widen it after the chip was drawn', () {
      doc = springBackPair(
        springBackPort('p', 'video.hdbaset'),
        springBackPort(
          'p',
          'video.composite',
          dir: PortDirection.sink,
          connector: 'conn.rca',
          accepts: ['video.hdbaset'],
        ),
      );
      controller = DocumentController(doc, clock: FixedClock(_at));
      final result = run();
      expect(result, isA<InsertConverterRefused>());
      expect(
        (result as InsertConverterRefused).message,
        contains('already accepts'),
      );
      expect(doc.devices, hasLength(2), reason: 'nothing was minted');
    });

    test(
      'a full source pin is refused before anything is minted (TOP-003)',
      () {
        // ONE CONNECTION EACH, unlike the shared fixture's default of four.
        // The default exists so a tier-2 scenario never trips tier 1 by
        // accident; this case is the opposite and wants the pin to fill.
        doc = springBackPair(
          springBackPort('p', 'video.hdbaset', maxConnections: 1),
          springBackPort(
            'p',
            'video.composite',
            dir: PortDirection.sink,
            connector: 'conn.rca',
            maxConnections: 1,
          ),
        );
        controller = DocumentController(doc, clock: FixedClock(_at));
        expect(run(), isA<InsertConverterDone>());
        // The source now carries the converter's cable, so a second remedy
        // on the same pin has nothing to route.
        final second = run();
        expect(second, isA<InsertConverterRefused>());
        expect((second as InsertConverterRefused).message, contains('TOP-003'));
        expect(
          doc.devices,
          hasLength(3),
          reason: 'the refusal must not leave a second converter behind',
        );
      },
    );

    test('a pair that is not source-into-sink is refused', () {
      doc = springBackPair(
        springBackPort('p', 'video.hdbaset'),
        springBackPort('p', 'video.composite', connector: 'conn.rca'),
      );
      controller = DocumentController(doc, clock: FixedClock(_at));
      expect(run(), isA<InsertConverterRefused>());
    });
  });
}
