// DR-098 §11.97.3: an override says one of THREE things, not two.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT THESE ASSERT, AND WHY IT IS NOT THE RESOLVER
// ─────────────────────────────────────────────────────────────────────────
// `resolveWeight` returning null for a cleared field is the mechanism. The
// ARTIFACT is what the rack subtotal then prints, and it is the artifact
// that G4 and CR-114 are rules about: a device whose weight is UNKNOWN must
// leave the total incomplete and be COUNTED, and must not be quietly
// totalled at whatever figure the template happened to carry.
//
// So every state test below goes through `computeRackRollups` and asserts
// both halves of the rollup, which is `totals_test.dart`'s own standard:
// "a null with no count is just as unusable as a fabricated zero".
//
// THE FIXTURE'S TEMPLATE STATES A WEIGHT, AND THAT IS DELIBERATE. The
// difference between INHERIT and UNKNOWN is only observable when there is
// something to inherit; against a template whose weight is null all three
// states produce an identical rollup and the suite would pass while
// proving nothing. That is the vacuity shape §5.3.16 recorded, where an
// existence assertion could not see forty-eight marks collapse to nine.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 27);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

Rack _rack() => Rack(
  id: const Uuid('rk-1'),
  name: 'Test Rack',
  designator: 'RK-1',
  heightU: 12,
  order: const FracIndex('a0'),
  meta: _meta(),
);

/// The template of the ruling's own worked example: a generic 2U
/// amplifier that STATES 30 lb.
TemplateBody _body({Mass? weight, int? typicalWatts, Rgb? accentColor}) =>
    TemplateBody(
      manufacturer: 'Test',
      model: 'amp',
      displayName: 'Generic 2U Amplifier',
      frontU: 2,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
      weight: weight,
      accentColor: accentColor,
      power: PowerProfile(typicalWatts: typicalWatts),
    );

TemplateSnapshot _snapshot(TemplateBody body) => TemplateSnapshot(
  templateId: const TemplateId('amp'),
  version: 1,
  contentHash: 'sha256:test-amp',
  body: body,
  capturedAt: _now,
);

DeviceInstance _device({DeviceOverrides? overrides}) => DeviceInstance(
  id: const Uuid('d1'),
  kind: DeviceKind.rackDevice,
  templateRef: const TemplateRef(
    templateId: TemplateId('amp'),
    version: 1,
    contentHash: 'sha256:test-amp',
  ),
  designator: 'AMP-1',
  name: 'AMP-1',
  placement: const RailPlacement(
    rackId: Uuid('rk-1'),
    ruIndex: 1,
    face: Face.front,
  ),
  overrides: overrides,
  meta: _meta(),
);

RackDocument _docWith(DeviceOverrides o, {Mass? templateWeight}) {
  final doc = RackDocument(
    id: const Uuid('doc-device-overrides'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.racks[const Uuid('rk-1')] = _rack();
  doc.templates['amp@1'] = _snapshot(_body(weight: templateWeight));
  doc.devices[const Uuid('d1')] = _device(overrides: o);
  return doc;
}

RackRollups _rollups(DeviceInstance device, TemplateBody body) =>
    computeRackRollups(
      rack: _rack(),
      devices: [device],
      templates: {'amp@1': _snapshot(body)},
      face: Face.front,
      landings: PortLandings.none,
    );

/// The `overrides` object exactly as it lands in the file.
JsonMap _encodedOverrides(DeviceOverrides o) {
  final tree = const JsonDocumentCodec().encodeToJsonTree(_docWith(o));
  final devices = (tree['document']! as JsonMap)['devices']! as JsonMap;
  final device = devices.values.first! as JsonMap;
  return device['overrides']! as JsonMap;
}

void main() {
  final templateWeight = Mass.fromKilograms(13.6);

  group('the three states, read off the rack subtotal (DR-098 §11.97.3)', () {
    test('INHERIT: no override, so the template governs and it is a total', () {
      final r = _rollups(_device(), _body(weight: templateWeight));

      expect(r.weight.value, templateWeight);
      expect(
        r.weight.unknownCount,
        0,
        reason: 'the template stated a weight and nothing contradicted it',
      );
    });

    test('SET: the instance states a different weight and it is totalled', () {
      final stated = Mass.fromKilograms(11.3);
      final r = _rollups(
        _device(overrides: DeviceOverrides(weight: stated)),
        _body(weight: templateWeight),
      );

      expect(r.weight.value, stated);
      expect(r.weight.unknownCount, 0);
    });

    test(
      'UNKNOWN: the template states a weight, the instance says it does not '
      'know, and the subtotal is INCOMPLETE rather than the template figure',
      () {
        final overrides = DeviceOverrides()..clear(DeviceOverrideField.weight);
        final r = _rollups(
          _device(overrides: overrides),
          _body(weight: templateWeight),
        );

        // BOTH HALVES. A null with no count is as unusable as a fabricated
        // zero, and the template's figure surviving in the total is the
        // fabricated rollup CR-114 forbids.
        expect(
          r.weight.value,
          isNull,
          reason: 'no contributor could supply a mass',
        );
        expect(r.weight.unknownCount, 1);
        expect(
          r.weight.value,
          isNot(templateWeight),
          reason:
              'this is the defect the ruling is about: a figure the instance '
              'disowned must not survive as a measurement',
        );
      },
    );

    test('UNKNOWN is not reachable by SETTING null, which means inherit', () {
      // The only state the two-state class could express, and the reason
      // it was not enough: a null override is INHERIT and always was.
      final r = _rollups(
        _device(overrides: DeviceOverrides()),
        _body(weight: templateWeight),
      );

      expect(r.weight.value, templateWeight);
      expect(r.weight.unknownCount, 0);
    });

    test('a cleared typicalWatts takes the derived heat figure with it', () {
      final overrides = DeviceOverrides()
        ..clear(DeviceOverrideField.typicalWatts);
      final loads = resolveDeviceLoads(
        _device(overrides: overrides),
        _body(weight: templateWeight, typicalWatts: 400),
      );

      expect(loads.typicalWatts, isNull);
      expect(
        loads.btuPerHour,
        isNull,
        reason:
            'heat is derived from watts, so an unknown draw cannot '
            'produce a known BTU figure',
      );
    });
  });

  group('clear and inherit each undo the other', () {
    test('clear drops a value that was set, so both cannot be held', () {
      final o = DeviceOverrides(weight: Mass.fromKilograms(11.3))
        ..clear(DeviceOverrideField.weight);

      expect(o.weight, isNull);
      expect(o.isUnknown(DeviceOverrideField.weight), isTrue);
    });

    test('inherit removes the cleared mark and leaves no value', () {
      final o = DeviceOverrides()
        ..clear(DeviceOverrideField.weight)
        ..inherit(DeviceOverrideField.weight);

      expect(o.weight, isNull);
      expect(o.isUnknown(DeviceOverrideField.weight), isFalse);
      expect(o.isEmpty, isTrue);
    });

    test('an untouched override says nothing at all', () {
      expect(DeviceOverrides().isEmpty, isTrue);
    });
  });

  group('on the wire (CR-114, CR-117)', () {
    test(
      'an empty override writes NO cleared key, so the shipped corpus does '
      'not move',
      () {
        final encoded = _encodedOverrides(DeviceOverrides());

        expect(encoded.containsKey('cleared'), isFalse);
        expect(
          encoded,
          isEmpty,
          reason:
              'every override block in all four starters and all six '
              'fixtures is `{}`, and this ruling must not have moved one',
        );
      },
    );

    test('a cleared field writes a PRESENT key, because an absent one '
        'already means inherit', () {
      final o = DeviceOverrides()..clear(DeviceOverrideField.weight);
      expect(_encodedOverrides(o)['cleared'], ['weight']);
    });

    test('cleared is written in ENUM order, not insertion order', () {
      // Set iteration is insertion-ordered in Dart, so without the sort
      // two documents that cleared the same fields in a different
      // sequence would write different bytes, and determinism is a
      // project invariant rather than a nicety.
      final a = DeviceOverrides()
        ..clear(DeviceOverrideField.accentColor)
        ..clear(DeviceOverrideField.typicalWatts);
      final b = DeviceOverrides()
        ..clear(DeviceOverrideField.typicalWatts)
        ..clear(DeviceOverrideField.accentColor);

      expect(_encodedOverrides(a)['cleared'], ['typicalWatts', 'accentColor']);
      expect(_encodedOverrides(a)['cleared'], _encodedOverrides(b)['cleared']);
    });

    test(
      'every field survives a real byte round-trip in the UNKNOWN state',
      () {
        for (final field in DeviceOverrideField.values) {
          final doc = _docWith(DeviceOverrides()..clear(field));
          final bytes = const JsonDocumentCodec().write(doc);
          final back = const JsonDocumentCodec().read(bytes);

          expect(
            back,
            isA<Ok<RackDocument>>(),
            reason: '$field failed to read',
          );
          final overrides =
              (back as Ok<RackDocument>).value.devices.values.first.overrides;

          expect(
            overrides.isUnknown(field),
            isTrue,
            reason: '$field lost its cleared state through the codec',
          );
          expect(
            const JsonDocumentCodec().write(back.value),
            bytes,
            reason: 'CR-117: write(read(bytes)) == bytes, for $field',
          );
        }
      },
    );

    test('SET and CLEARED at once is refused BY NAME, not normalised', () {
      final tree = const JsonDocumentCodec().encodeToJsonTree(
        _docWith(DeviceOverrides(weight: Mass.fromKilograms(11.3))),
      );
      final devices = (tree['document']! as JsonMap)['devices']! as JsonMap;
      final device = devices.values.first! as JsonMap;
      // Hand-build the contradiction this application cannot produce.
      (device['overrides']! as JsonMap)['cleared'] = ['weight'];

      final outcome = readFromJsonTree(tree);
      expect(outcome, isA<Err<RackDocument>>());
      final error = (outcome as Err<RackDocument>).error;
      expect(error, isA<FormatException>());
      expect(
        (error as FormatException).message,
        allOf(contains('weight'), contains('DR-098')),
        reason:
            'either way of picking a winner silently discards a '
            'statement the document made, so the refusal names the field',
      );
    });

    test('an unknown field name in cleared is refused rather than dropped', () {
      final tree = const JsonDocumentCodec().encodeToJsonTree(
        _docWith(DeviceOverrides()),
      );
      final devices = (tree['document']! as JsonMap)['devices']! as JsonMap;
      final device = devices.values.first! as JsonMap;
      (device['overrides']! as JsonMap)['cleared'] = ['displayName'];

      final outcome = readFromJsonTree(tree);
      expect(
        outcome,
        isA<Err<RackDocument>>(),
        reason:
            'displayName was DELETED by DR-098 §11.97.4, so a file '
            'naming it states something this model no longer has',
      );
    });
  });
}
