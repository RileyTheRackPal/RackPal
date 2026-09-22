// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take;
// collapsing the pair into a cascade would delete the intermediate
// assertion.
//
// Lateral position, and the writer `PLC-002` was waiting for (`#269`,
// M5-C, CR-030).
//
// ═══════════════════════════════════════════════════════════════════════
// THE POINT OF THIS FILE IS THAT THE RULE CAN NOW FIRE
// ═══════════════════════════════════════════════════════════════════════
// `PLC-002` had a predicate and an AC-051 pair from the day it shipped and
// nothing that could hand it a bad value: `MoveDeviceCommand` carried the
// twelfths across a move and the codec read them off a file, and that was
// the whole population of writers. Tier 1 is *"the command is rejected"*,
// so the tests that matter here are the ones where a command is.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 2, 16);
const _dev = Uuid('dev-1');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

RackDocument _doc({
  Placement? placement,
  int heightU = 12,
  bool locked = false,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-width'),
    appVersion: '0.5.20',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.racks[const Uuid('rk-1')] = Rack(
    id: const Uuid('rk-1'),
    name: 'Test Rack',
    designator: 'RK-1',
    heightU: heightU,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.templates['tpl.w@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.w'),
    version: 1,
    contentHash: 'sha256:tpl.w',
    body: TemplateBody(
      manufacturer: 'Acme',
      model: 'HALF',
      displayName: 'HALF',
      typePrefix: 'AMP',
      frontU: 1,
      side: OccupancySide.front,
    ),
    capturedAt: _now,
  );
  doc.devices[_dev] = DeviceInstance(
    id: _dev,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.w'),
      version: 1,
      contentHash: 'sha256:tpl.w',
    ),
    designator: 'AMP-1',
    name: 'Amplifier',
    placement:
        placement ??
        RailPlacement(
          rackId: const Uuid('rk-1'),
          ruIndex: 3,
          face: Face.front,
          // UNLOCKED BY DEFAULT SINCE DR-186. It was `true`, which was
          // free while nothing read the field and is now the one value
          // that refuses every plan in this file.
          locked: locked,
          chassisRotation: ChassisRotation.reversed,
        ),
    meta: _meta(),
  );
  return doc;
}

WidthChangeResult _plan(RackDocument doc, int start, int span) =>
    planSetDeviceWidth(
      doc: doc,
      id: _dev,
      startTwelfth: start,
      spanTwelfths: span,
      now: _now,
      actor: 'R. Riley',
    );

void main() {
  group('CR-030 three positions, which is what the v1 editor offers', () {
    test('every one of them is accepted and lands in the placement', () {
      for (final p in WidthPosition.values) {
        final doc = _doc();
        final result = _plan(doc, p.startTwelfth, p.spanTwelfths);
        expect(result, isA<WidthChangeReady>(), reason: p.label);
        (result as WidthChangeReady).command.apply(doc);
        final placement = doc.devices[_dev]!.placement as RailPlacement;
        expect(placement.startTwelfth, p.startTwelfth, reason: p.label);
        expect(placement.spanTwelfths, p.spanTwelfths, reason: p.label);
      }
    });

    test('and matching() round-trips each of them', () {
      for (final p in WidthPosition.values) {
        expect(
          WidthPosition.matching(p.startTwelfth, p.spanTwelfths),
          p,
          reason: p.label,
        );
      }
    });

    test('matching() is NULL for a position the dropdown cannot express, '
        'because a control that displayed Full for (3,6) would misreport '
        'the document', () {
      expect(WidthPosition.matching(3, 6), isNull);
      expect(WidthPosition.matching(0, 4), isNull);
    });
  });

  group('PLC-002 can finally fire, which is the whole point', () {
    test('KNOWN-BAD: a span of 13 is refused and the refusal cites the '
        'rule', () {
      final result = _plan(_doc(), 0, 13);
      expect(result, isA<WidthChangeRefused>());
      expect((result as WidthChangeRefused).ruleId, 'PLC-002');
      expect(result.reason, contains('AMP-1'));
      expect(result.reason, endsWith('.'));
    });

    test('NEAR-MISS: a span of 12 is the full opening and is accepted', () {
      expect(_plan(_doc(), 0, 12), isA<WidthChangeReady>());
    });

    test('KNOWN-BAD: a half-rack device at twelfth 7 runs past the rail', () {
      final result = _plan(_doc(), 7, 6);
      expect(result, isA<WidthChangeRefused>());
      expect((result as WidthChangeRefused).ruleId, 'PLC-002');
    });

    test('NEAR-MISS: the same device at twelfth 6 fits exactly', () {
      expect(_plan(_doc(), 6, 6), isA<WidthChangeReady>());
    });

    test('a refused plan writes NOTHING, so the document is untouched', () {
      final doc = _doc();
      final before = _codec.write(doc);
      expect(_plan(doc, 0, 13), isA<WidthChangeRefused>());
      expect(_codec.write(doc), before);
    });
  });

  group('refusals that are not rules carry no rule id (CR-021)', () {
    test('A LOCKED DEVICE IS REFUSED BY NAME (DR-186 §11.185.1), because a '
        'width position is a position', () {
      final doc = _doc(locked: true);
      final result = _plan(doc, 0, 6);

      expect(result, isA<WidthChangeRefused>());
      expect((result as WidthChangeRefused).reason, contains('AMP-1'));
      expect(result.reason, lockedRefusal('AMP-1'));
      expect(
        (doc.devices[_dev]!.placement as RailPlacement).startTwelfth,
        0,
        reason: 'a refused plan writes nothing',
      );
    });

    test('and the command refuses too, for a caller that skipped the '
        'planner', () {
      // The planner is the user-facing refusal; this is the line that
      // holds when something builds the command directly.
      final unlocked = _doc();
      final command = (_plan(unlocked, 6, 6) as WidthChangeReady).command;
      final locked = _doc(locked: true);

      expect(command.apply(locked), isFalse);
      expect(
        (locked.devices[_dev]!.placement as RailPlacement).startTwelfth,
        0,
      );
    });

    test('a device that is not rail-placed has no width position', () {
      final doc = _doc(placement: const OffRackPlacement());
      final result = _plan(doc, 0, 6);
      expect(result, isA<WidthChangeRefused>());
      final refused = result as WidthChangeRefused;
      expect(refused.ruleId, isNull);
      expect(refused.reason, contains('AMP-1'));
    });

    test('a device that is not in the document at all', () {
      final doc = _doc();
      doc.devices.remove(_dev);
      final result = _plan(doc, 0, 6);
      expect(result, isA<WidthChangeRefused>());
      expect((result as WidthChangeRefused).ruleId, isNull);
    });
  });

  group('the write itself', () {
    test('carries every other RailPlacement field across, which is what '
        'replacing a whole immutable placement makes easy to lose', () {
      final doc = _doc();
      (_plan(doc, 0, 6) as WidthChangeReady).command.apply(doc);
      final placement = doc.devices[_dev]!.placement as RailPlacement;
      expect(placement.ruIndex, 3);
      expect(placement.face, Face.front);
      // `locked` IS NOT ON THIS LIST ANY MORE, and its absence is the
      // point: a locked device refuses the edit (DR-186 §11.185.1), so
      // there is no width write over one for a field to survive. The case
      // below is where the lock is asserted instead.
      expect(placement.chassisRotation, ChassisRotation.reversed);
      expect(placement.rackId, const Uuid('rk-1'));
    });

    test('apply, revert, apply lands on identical bytes (CR-117)', () {
      final doc = _doc();
      final before = _codec.write(doc);
      final cmd = (_plan(doc, 6, 6) as WidthChangeReady).command;
      cmd.apply(doc);
      final applied = _codec.write(doc);
      cmd.revert(doc);
      expect(_codec.write(doc), before);
      cmd.apply(doc);
      expect(_codec.write(doc), applied);
    });

    test('names its own act, because "Undo Move Device" in front of '
        'somebody who picked Left half names the wrong one', () {
      final cmd = (_plan(_doc(), 0, 6) as WidthChangeReady).command;
      expect(cmd.label, LabelKey.setDeviceWidth);
      expect(cmd.label, isNot(LabelKey.moveDevice));
    });

    test('declares structure and NOT wires: the box moves across the '
        'opening, no cable re-routes', () {
      final cmd = (_plan(_doc(), 0, 6) as WidthChangeReady).command;
      expect(cmd.touches!.has(EpochMask.structure), isTrue);
      expect(cmd.touches!.has(EpochMask.wires), isFalse);
    });
  });

  group('a pre-existing fault blocks the edit, deliberately', () {
    test('a device already outside its rack cannot have its width '
        'changed until it is back inside', () {
      // DR-112 makes this a legal document state, reachable by import or
      // a hand edit. `connect_rules.dart` takes the same position on
      // TOP-005: a command must not write a placement into a region of
      // the document that is already model-illegal.
      final doc = _doc(
        placement: const RailPlacement(
          rackId: Uuid('rk-1'),
          ruIndex: 40,
          face: Face.front,
        ),
      );
      final result = _plan(doc, 0, 6);
      expect(result, isA<WidthChangeRefused>());
      expect((result as WidthChangeRefused).ruleId, 'PLC-001');
    });

    test('and the ORDER is why that is not merely tolerable: PLC-001 '
        'sorts first, so refusing only on PLC-002 would let a bad span '
        'through on an out-of-bounds device', () {
      final doc = _doc(
        placement: const RailPlacement(
          rackId: Uuid('rk-1'),
          ruIndex: 40,
          face: Face.front,
        ),
      );
      expect(_plan(doc, 0, 13), isA<WidthChangeRefused>());
    });
  });
}
