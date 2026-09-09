// PLAN-F/2: what a calibration made measurable, and the boundary it must
// not cross (DR-144 §11.143.3).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASE IS THE ONE THAT MOVES EVERY PIN
// ═══════════════════════════════════════════════════════════════════════
// The rest of this file is arithmetic. The case that matters asserts a
// NEGATIVE: moving every pin to a different place changes nothing here,
// because this derivation asks whether a length is DERIVABLE and never
// what it is. A `Len` per pin would be `planLowerBound` shipped early
// under another name, without the rank, the `>=` prefix, the italic, the
// rollup exclusion or `LEN-001`'s reading, and it would pass every
// counting case below.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 9, 8);
const _ul = Uuid('ul-1');
const _other = Uuid('ul-2');
const _rackId = Uuid('rk-1');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.test'),
  version: 1,
  contentHash: 'sha256:test',
);

/// 36 inches over 100 pixels, which is `PLAN-F/1`'s own example.
const _usable = PlanScale(
  a: PxPt(100, 100),
  b: PxPt(200, 100),
  distance: Len(36 * Len.nmPerInch),
);

/// Two coincident points: stored, and unable to yield a factor.
const _degenerate = PlanScale(
  a: PxPt(100, 100),
  b: PxPt(100, 100),
  distance: Len(36 * Len.nmPerInch),
);

PlanUnderlay _underlay({Uuid id = _ul, PlanScale? scale}) => PlanUnderlay(
  id: id,
  name: 'Level 1',
  imageMember: 'underlays/$id.png',
  format: PlanImageFormat.png,
  pixelWidth: 600,
  pixelHeight: 400,
  contentHash: 'sha256:test',
  order: const FracIndex('a0'),
  meta: _meta(),
  scale: scale,
);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-1'),
  appVersion: '0.1.0',
  createdAt: _now,
  modifiedAt: _now,
  meta: _meta(),
);

void _addRack(RackDocument doc, {PlanPin? pin, Uuid id = _rackId}) {
  doc.racks[id] = Rack(
    id: id,
    name: 'Head end',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
    planPin: pin,
  );
}

void _addOutlet(RackDocument doc, String key, {PlanPin? pin}) {
  final id = Uuid(key);
  doc.outlets[id] = Outlet(
    id: id,
    structureBodyId: const Uuid('body-1'),
    designation: key,
    order: const FracIndex('a0'),
    meta: _meta(),
    planPin: pin,
  );
}

void _addDevice(RackDocument doc, String key, {PlanPin? pin}) {
  final id = Uuid(key);
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.offRackPassive,
    templateRef: _templateRef,
    designator: key,
    name: 'speaker',
    placement: OffRackPlacement(planPin: pin),
    meta: _meta(),
  );
}

PlanPin _pin(int x, int y, {Uuid on = _ul}) =>
    PlanPin(underlayId: on, at: PxPt(x, y));

void main() {
  group('the four states, and which one it reports', () {
    test('uncalibrated: the blocker is the scale, whatever else is '
        'pinned', () {
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      final m = planMeasurabilityOf(doc, _underlay());

      expect(m.blockedBy, PlanBlocker.uncalibrated);
      expect(m.measurableCount, 0);
      // AND THE STRANDED COUNT STILL REPORTS THE PINS. A surface with
      // only the first would call a fully pinned plan empty, which is
      // exactly what the underlay row did until DR-146 §11.145.4.
      expect(m.subjectPinCount, 1, reason: 'the rack is not a subject');
      expect(m.unmeasurablePinCount, 1);
    });

    test('calibrated with no rack: the blocker is the rack, which is what '
        'PLN-003 is about', () {
      final doc = _doc();
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      _addOutlet(doc, 'D-2', pin: _pin(30, 30));
      final m = planMeasurabilityOf(doc, _underlay(scale: _usable));

      expect(m.isCalibrated, isTrue);
      expect(m.rackPinned, isFalse);
      expect(m.blockedBy, PlanBlocker.noRackPinned);
      expect(m.measurableCount, 0, reason: 'no datum, so no length');
      expect(m.subjectPinCount, 2);
      expect(m.unmeasurablePinCount, 2);
    });

    test('calibrated with a rack and nothing else: the blocker is the '
        'pins', () {
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      final m = planMeasurabilityOf(doc, _underlay(scale: _usable));

      expect(m.blockedBy, PlanBlocker.noPins);
      expect(m.measurableCount, 0);
      expect(
        m.subjectPinCount,
        0,
        reason: 'the rack is the datum and the subject of nothing',
      );
      expect(m.unmeasurablePinCount, 0, reason: 'nothing is stranded');
    });

    test('calibrated, racked and pinned: nothing blocks and the count is '
        'the carriers that are not the rack', () {
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      _addOutlet(doc, 'D-2', pin: _pin(30, 30));
      _addDevice(doc, 'SPK-1', pin: _pin(40, 40));
      final m = planMeasurabilityOf(doc, _underlay(scale: _usable));

      expect(m.blockedBy, isNull);
      expect(m.measurableCount, 3);
      expect(m.subjectPinCount, 3);
      expect(m.unmeasurablePinCount, 0, reason: 'nothing is left over');
    });
  });

  group('THE BOUNDARY: it produces no length, and never has', () {
    test('MOVING EVERY PIN CHANGES NOTHING, which is what stops this being '
        'planLowerBound under another name', () {
      // The whole file's load-bearing case. A derivation that computed a
      // distance per pin would pass every counting case above and fail
      // this one, and it is the only case that can tell them apart.
      final near = _doc();
      _addRack(near, pin: _pin(10, 10));
      _addOutlet(near, 'D-1', pin: _pin(11, 11));
      _addDevice(near, 'SPK-1', pin: _pin(12, 12));

      final far = _doc();
      _addRack(far, pin: _pin(10, 10));
      _addOutlet(far, 'D-1', pin: _pin(590, 390));
      _addDevice(far, 'SPK-1', pin: _pin(500, 20));

      expect(
        planMeasurabilityOf(near, _underlay(scale: _usable)),
        planMeasurabilityOf(far, _underlay(scale: _usable)),
      );
    });

    test('AND CHANGING THE TYPED DISTANCE CHANGES NOTHING EITHER', () {
      // A scale of 36 inches and one of 36 feet make every length on the
      // plan differ by twelve and make no difference at all to whether a
      // length exists.
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      const twelveTimes = PlanScale(
        a: PxPt(100, 100),
        b: PxPt(200, 100),
        distance: Len(36 * 12 * Len.nmPerInch),
      );

      expect(
        planMeasurabilityOf(doc, _underlay(scale: _usable)),
        planMeasurabilityOf(doc, _underlay(scale: twelveTimes)),
      );
    });
  });

  group('the edges a fixture would not reach by accident', () {
    test('AN UNUSABLE SCALE IS UNCALIBRATED, not calibrated-with-zero', () {
      // `PlanScale.isUsable` is false when the two points coincide, and a
      // plan reporting itself calibrated there would promise a length the
      // model refuses to derive.
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      final m = planMeasurabilityOf(doc, _underlay(scale: _degenerate));

      expect(m.isCalibrated, isFalse);
      expect(m.blockedBy, PlanBlocker.uncalibrated);
    });

    test('A PIN ON ANOTHER PLAN IS NOT ON THIS ONE, in both counts', () {
      // A document may hold several plans, and a rack pinned on `Level 2`
      // is no datum for `Level 1`. Counting it would report `Level 1` as
      // measurable and derive nothing.
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10, on: _other));
      _addOutlet(doc, 'D-1', pin: _pin(20, 20, on: _other));
      _addOutlet(doc, 'D-2', pin: _pin(30, 30));
      final m = planMeasurabilityOf(doc, _underlay(scale: _usable));

      expect(m.rackPinned, isFalse, reason: 'that rack is on Level 2');
      expect(m.blockedBy, PlanBlocker.noRackPinned);
      expect(m.subjectPinCount, 1, reason: 'D-2 only; D-1 is on Level 2');
    });

    test('TWO PINNED RACKS COUNT THE SAME AS ONE, because which is the '
        'datum is PLAN-G to decide', () {
      // DR-144 §11.143.3 leaves that open in terms. This derivation asks
      // only whether a datum exists.
      final one = _doc();
      _addRack(one, pin: _pin(10, 10));
      _addOutlet(one, 'D-1', pin: _pin(20, 20));

      final two = _doc();
      _addRack(two, pin: _pin(10, 10));
      _addRack(two, pin: _pin(90, 90), id: const Uuid('rk-2'));
      _addOutlet(two, 'D-1', pin: _pin(20, 20));

      final a = planMeasurabilityOf(one, _underlay(scale: _usable));
      final b = planMeasurabilityOf(two, _underlay(scale: _usable));
      // NOT ONE NUMBER MOVES, and since DR-146 §11.145.5 that includes
      // the second count: both are over the subjects, and a rack is a
      // datum in either quantity. The whole value is compared rather than
      // its members, so a fourth field added later is covered here too.
      expect(a, b);
      expect(b.subjectPinCount, a.subjectPinCount);
    });

    test('A RACK-PLACED DEVICE IS NOT A CARRIER even on a pinned rack', () {
      // Only `OffRackPlacement` has a `planPin` field. A device on a rail
      // says where it is with a rack, a U and a face, and counting it
      // here would inflate the number by the whole rack.
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      doc.devices[const Uuid('dev-rail')] = DeviceInstance(
        id: const Uuid('dev-rail'),
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'AMP-1',
        name: 'amp',
        placement: const RailPlacement(
          rackId: _rackId,
          ruIndex: 4,
          face: Face.front,
        ),
        meta: _meta(),
      );

      final m = planMeasurabilityOf(doc, _underlay(scale: _usable));
      expect(m.measurableCount, 1);
      expect(
        m.subjectPinCount,
        1,
        reason:
            'D-1, and neither the rack nor '
            'the device on its rails',
      );
    });

    test('an empty document reports every count as zero and blames the '
        'scale', () {
      final m = planMeasurabilityOf(_doc(), _underlay());
      expect(m.measurableCount, 0);
      expect(m.subjectPinCount, 0);
      expect(m.unmeasurablePinCount, 0);
      expect(m.blockedBy, PlanBlocker.uncalibrated);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // PLAN-F/3: ONE POPULATION, ASSERTED ACROSS A CALIBRATION
  // ═════════════════════════════════════════════════════════════════════
  group('DR-146: the count means one thing on both sides of a '
      'calibration', () {
    test('THIRTY-NINE UNMEASURABLE BECOME THIRTY-NINE MEASURABLE, and the '
        'subject count never moves', () {
      // The user's call at §11.145.5, as the one case that can tell it
      // from the alternative it was chosen over. Counting the rack as
      // well would report forty before and thirty-nine after, and a
      // number that drops by one at the moment of a calibration reads as
      // a pin the calibration ate.
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      for (var i = 0; i < 39; i++) {
        _addOutlet(doc, 'D-$i', pin: _pin(20 + i, 20));
      }

      final before = planMeasurabilityOf(doc, _underlay());
      final after = planMeasurabilityOf(doc, _underlay(scale: _usable));

      expect(before.unmeasurablePinCount, 39);
      expect(after.measurableCount, 39);
      expect(
        before.subjectPinCount,
        after.subjectPinCount,
        reason: 'the population is the same question in both states',
      );
    });

    test('the two counts are complements in EVERY state, which is what '
        'stops either being read as the total', () {
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      _addOutlet(doc, 'D-2', pin: _pin(30, 30));

      final states = <String, PlanUnderlay>{
        'uncalibrated': _underlay(),
        'stored but unusable': _underlay(scale: _degenerate),
        'calibrated': _underlay(scale: _usable),
      };
      for (final entry in states.entries) {
        final m = planMeasurabilityOf(doc, entry.value);
        expect(
          m.measurableCount + m.unmeasurablePinCount,
          m.subjectPinCount,
          reason: entry.key,
        );
      }
    });

    test('A RACKLESS PLAN STRANDS ITS PINS TOO, which is a true answer to '
        'this question and PLN-003s to report', () {
      // The derivation answers "can a length be derived", and on a
      // calibrated plan with no datum it cannot. Which advisory says so
      // is `PLAN-I`'s: the row prints `no rack pinned` here (DR-144
      // §11.143.3) rather than this count.
      final doc = _doc();
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      final m = planMeasurabilityOf(doc, _underlay(scale: _usable));

      expect(m.blockedBy, PlanBlocker.noRackPinned);
      expect(m.unmeasurablePinCount, 1);
    });
  });

  group('PLN-001s sentence, written once in core (DR-146 §11.145.6)', () {
    PlanMeasurability stranded(int n) => PlanMeasurability(
      isCalibrated: false,
      rackPinned: true,
      subjectPinCount: n,
    );

    test('the plural is hand-written, and the VERB agrees with it', () {
      // `1 pins carry` is the `0 pathways` status bar this repository has
      // already shipped once, and the verb is the half a plural-only fix
      // leaves behind.
      expect(
        unmeasurablePinsSentence(stranded(39)),
        '39 pins carry no measurable position',
      );
      expect(
        unmeasurablePinsSentence(stranded(1)),
        '1 pin carries no measurable position',
      );
    });

    test('NOTHING STRANDED IS NULL AND NOT A ZERO SENTENCE', () {
      // `0 pins carry no measurable position` is the
      // `Calibrated · 0 measurable` DR-144 §11.143.3 refused one state
      // later: true, and it tells nobody anything.
      expect(unmeasurablePinsSentence(stranded(0)), isNull);
    });

    test('and null once those pins really can be measured', () {
      final doc = _doc();
      _addRack(doc, pin: _pin(10, 10));
      _addOutlet(doc, 'D-1', pin: _pin(20, 20));
      final m = planMeasurabilityOf(doc, _underlay(scale: _usable));

      expect(m.measurableCount, 1);
      expect(unmeasurablePinsSentence(m), isNull);
    });
  });
}
