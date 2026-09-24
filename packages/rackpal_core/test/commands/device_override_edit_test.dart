// Door 1 as an ORDINARY property edit (CR-054, DR-098 §11.97.5).
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT IS ACTUALLY BEING ASSERTED
// ─────────────────────────────────────────────────────────────────────────
// The claim DR-098 makes is not "an override can be written". It is that
// writing one is the SAME act as every other property edit, so it inherits
// the undo stack, the per-property coalescing and the meta touch rather
// than acquiring its own. Each case below is one limb of that claim, and
// the one that matters most is the undo case: the state an override edit
// must never leave behind is "set AND cleared", which is the one shape the
// codec refuses to load, so a `Ctrl+Z` that half-restored would produce a
// document this application cannot reopen.
//
// The second group is the amber badge's number. It is derived rather than
// computed in the widget because three scope badges read one count, and
// the badge is the only thing between a user and the wrong door.

// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 28);
final _later = DateTime.utc(2026, 8, 28, 1);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

TemplateBody _body({Mass? weight}) => TemplateBody(
  manufacturer: 'Test',
  model: 'amp',
  displayName: 'Generic 2U Amplifier',
  frontU: 2,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  weight: weight,
  power: PowerProfile(typicalWatts: 400),
);

DeviceInstance _device(String id, {String templateId = 'amp'}) =>
    DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(templateId),
        version: 1,
        contentHash: 'sha256:test-$templateId',
      ),
      designator: id.toUpperCase(),
      name: id.toUpperCase(),
      placement: const RailPlacement(
        rackId: Uuid('rk-1'),
        ruIndex: 1,
        face: Face.front,
      ),
      meta: _meta(),
    );

RackDocument _doc({List<DeviceInstance>? devices}) {
  final doc = RackDocument(
    id: const Uuid('doc-override-edit'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.racks[const Uuid('rk-1')] = Rack(
    id: const Uuid('rk-1'),
    name: 'Test Rack',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.templates['amp@1'] = TemplateSnapshot(
    templateId: const TemplateId('amp'),
    version: 1,
    contentHash: 'sha256:test-amp',
    body: _body(weight: Mass.fromKilograms(13.6)),
    capturedAt: _now,
  );
  for (final d in devices ?? [_device('d1')]) {
    doc.devices[d.id] = d;
  }
  return doc;
}

SetEntityPropertyCommand<DeviceInstance, OverrideValue<Mass>> _setWeight(
  RackDocument doc,
  Uuid id,
  OverrideValue<Mass> to,
) => SetEntityPropertyCommand<DeviceInstance, OverrideValue<Mass>>(
  id: id,
  field: DeviceField.overrideWeight,
  from: doc.devices[id]!.overrides.weightState,
  to: to,
  now: _later,
  actor: 'test',
);

void main() {
  group('an override edit is an ordinary property edit', () {
    test('setting a weight writes the value and touches the meta', () {
      final doc = _doc();
      const id = Uuid('d1');
      final stated = Mass.fromKilograms(11.3);

      _setWeight(doc, id, OverrideStated(stated)).apply(doc);

      expect(doc.devices[id]!.overrides.weight, stated);
      expect(
        doc.devices[id]!.meta.updatedAt,
        _later,
        reason: 'an edit nothing timestamps is an edit no sync can order',
      );
    });

    test('UNDOING a clear restores INHERIT, not "set and cleared"', () {
      // THE CASE THIS FILE EXISTS FOR. `set and cleared` is the one shape
      // `_decodeDeviceOverrides` refuses, so a revert that restored the
      // value without dropping the cleared mark would leave a document
      // that saves and cannot be reopened.
      final doc = _doc();
      const id = Uuid('d1');

      final cmd = _setWeight(doc, id, const OverrideUnknown<Mass>())
        ..apply(doc);
      expect(
        doc.devices[id]!.overrides.isUnknown(DeviceOverrideField.weight),
        isTrue,
      );

      cmd.revert(doc);

      final back = doc.devices[id]!.overrides;
      expect(back.weightState, const OverrideInherited<Mass>());
      expect(back.weight, isNull);
      expect(back.isUnknown(DeviceOverrideField.weight), isFalse);
      expect(
        back.isEmpty,
        isTrue,
        reason:
            'the device said nothing before the edit and must say '
            'nothing after the undo',
      );
    });

    test('UNDOING a set restores the previous UNKNOWN rather than clearing '
        'both members', () {
      final doc = _doc();
      const id = Uuid('d1');

      // Start from unknown, then state a value over it.
      _setWeight(doc, id, const OverrideUnknown<Mass>()).apply(doc);
      final second = _setWeight(
        doc,
        id,
        OverrideStated(Mass.fromKilograms(11.3)),
      )..apply(doc);

      expect(doc.devices[id]!.overrides.weight, Mass.fromKilograms(11.3));
      expect(
        doc.devices[id]!.overrides.isUnknown(DeviceOverrideField.weight),
        isFalse,
        reason:
            'stating a value must drop the cleared mark, or the two '
            'states are held at once',
      );

      second.revert(doc);

      expect(
        doc.devices[id]!.overrides.weightState,
        const OverrideUnknown<Mass>(),
      );
      expect(doc.devices[id]!.overrides.weight, isNull);
    });

    test('the rollup follows the edit, which is the point of making it '
        'reachable at all', () {
      final doc = _doc();
      const id = Uuid('d1');
      final rack = doc.racks[const Uuid('rk-1')]!;

      RackRollups rollups() => computeRackRollups(
        rack: rack,
        devices: doc.devices.values,
        templates: doc.templates,
        face: Face.front,
        landings: PortLandings.of(doc),
      );

      expect(rollups().weight.value, Mass.fromKilograms(13.6));
      expect(rollups().weight.unknownCount, 0);

      _setWeight(doc, id, const OverrideUnknown<Mass>()).apply(doc);

      expect(rollups().weight.value, isNull);
      expect(rollups().weight.unknownCount, 1);
    });

    test('two override properties do NOT coalesce into one undo entry', () {
      // Per-property coalescing is `mergeKey`'s job and the dotted keys
      // are what keep it per-property. Clearing a weight and then a draw
      // must be two things to undo, because they are two statements.
      final doc = _doc();
      const id = Uuid('d1');

      final weightEdit = _setWeight(doc, id, const OverrideUnknown<Mass>());
      final wattsEdit =
          SetEntityPropertyCommand<DeviceInstance, OverrideValue<int>>(
            id: id,
            field: DeviceField.overrideTypicalWatts,
            from: doc.devices[id]!.overrides.typicalWattsState,
            to: const OverrideUnknown<int>(),
            now: _later,
            actor: 'test',
          );

      expect(weightEdit.mergeWith(wattsEdit), isNull);
      expect(weightEdit.mergeKey, isNot(wattsEdit.mergeKey));
    });

    test('every door-1 field declares a non-empty epoch mask', () {
      // A field that invalidates nothing is a field whose edit the canvas
      // never repaints, which is indistinguishable from a broken editor.
      for (final f in [
        DeviceField.overrideWeight,
        DeviceField.overrideTypicalWatts,
        DeviceField.overrideBodyDepth,
        DeviceField.overrideAccentColor,
      ]) {
        expect(f.touches.bits, isNot(0), reason: f.key);
      }
    });

    test('every door-1 key is namespaced, so it cannot collide with a '
        'future instance-level field of the same name', () {
      for (final f in [
        DeviceField.overrideWeight,
        DeviceField.overrideTypicalWatts,
        DeviceField.overrideBodyDepth,
        DeviceField.overrideAccentColor,
      ]) {
        expect(f.key, startsWith('overrides.'), reason: f.key);
      }
      final keys = [for (final f in DeviceField.all) f.key];
      expect(keys.toSet(), hasLength(keys.length), reason: '$keys');
    });
  });

  group("the amber badge's number", () {
    test('counts the OTHER devices on the template, not this one', () {
      final doc = _doc(
        devices: [_device('d1'), _device('d2'), _device('d3')],
      );

      expect(
        countOtherDevicesOnTemplate(doc, doc.devices[const Uuid('d1')]!),
        2,
      );
    });

    test('a template placed once has no others, and zero is a real answer', () {
      final doc = _doc();
      expect(
        countOtherDevicesOnTemplate(doc, doc.devices[const Uuid('d1')]!),
        0,
      );
    });

    test('devices on a DIFFERENT template are not counted', () {
      final doc = _doc(
        devices: [
          _device('d1'),
          _device('d2', templateId: 'switch'),
          _device('d3', templateId: 'switch'),
        ],
      );

      expect(
        countOtherDevicesOnTemplate(doc, doc.devices[const Uuid('d1')]!),
        0,
        reason:
            'the badge would otherwise reassure the user about devices '
            'the template edit could never have touched',
      );
    });
  });
}
