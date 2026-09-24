// Door 3 of CR-054, "fork to a new template" (DR-099 §11.98).
//
// =====================================================================
// THE ASSERTION THAT MATTERS IS THAT NOTHING MOVED
// =====================================================================
// A fork seeds a new template from the snapshot PLUS the instance's
// overrides, then clears those overrides. If the seeding is incomplete,
// the overridden facts are lost twice over: gone from the instance because
// door 3 cleared them, and never written to the template because the copy
// missed them. Nothing would throw. The rack subtotal would simply be a
// different number afterwards.
//
// So the load-bearing case reads `computeRackRollups` on both sides of the
// fork and asserts it is UNCHANGED. That is the artifact; `derivedFrom`
// being set and `overrides.isEmpty` being true are the mechanism, and they
// would both pass on a fork that silently dropped the mass.
//
// THE UNKNOWN CASE IS THE ONE A TWO-STATE OVERRIDE COULD NOT HAVE POSED.
// An override saying "the template's figure does not govern and I do not
// know the real one" must NOT copy that figure into the fork, or the
// number the user disowned comes back in a template where nothing records
// that they disowned it.

// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 29);
final _later = DateTime.utc(2026, 8, 29, 1);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

TemplateBody _body() => TemplateBody(
  manufacturer: 'Test',
  model: 'amp',
  displayName: 'Generic 2U Amplifier',
  frontU: 2,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  weight: Mass.fromKilograms(13.6),
  bodyDepth: Len.fromMillimetres(300),
  power: PowerProfile(typicalWatts: 400),
);

DeviceInstance _device(String id, {DeviceOverrides? overrides}) =>
    DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('amp'),
        version: 1,
        contentHash: 'unhashed:amp@1',
      ),
      designator: id.toUpperCase(),
      name: id.toUpperCase(),
      placement: const RailPlacement(
        rackId: Uuid('rk-1'),
        ruIndex: 1,
        face: Face.front,
      ),
      overrides: overrides,
      meta: _meta(),
    );

RackDocument _doc({DeviceOverrides? overrides, int devices = 1}) {
  final doc = RackDocument(
    id: const Uuid('doc-fork'),
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
    contentHash: 'unhashed:amp@1',
    body: _body(),
    capturedAt: _now,
  );
  doc.devices[const Uuid('d1')] = _device('d1', overrides: overrides);
  if (devices > 1) doc.devices[const Uuid('d2')] = _device('d2');
  return doc;
}

Rollup<Mass> _mass(RackDocument doc) => computeRackRollups(
  rack: doc.racks.values.single,
  devices: doc.devices.values,
  templates: doc.templates,
  face: Face.front,
  landings: PortLandings.of(doc),
).weight;

ForkTemplateFromDeviceCommand _fork(RackDocument doc) {
  final r = buildForkTemplateFromDevice(
    doc: doc,
    deviceId: const Uuid('d1'),
    newTemplateId: const TemplateId('amp_fork'),
    now: _later,
    actor: 'test',
  );
  return (r as ForkTemplateReady).command;
}

void main() {
  group('the fork carries the facts across, which is the whole job', () {
    test('THE RACK SUBTOTAL DOES NOT MOVE when a stated mass is forked', () {
      // If the seeding missed `weight`, the instance loses it (door 3
      // clears overrides) and the template never gained it. Nothing
      // throws; the subtotal is just quietly wrong afterwards.
      final stated = Mass.fromKilograms(11.3);
      final doc = _doc(overrides: DeviceOverrides(weight: stated));

      final before = _mass(doc);
      expect(before.value, stated);

      _fork(doc).apply(doc);

      final after = _mass(doc);
      expect(after.value, before.value);
      expect(after.unknownCount, before.unknownCount);
      expect(
        doc.devices[const Uuid('d1')]!.overrides.isEmpty,
        isTrue,
        reason:
            'the values are in the template now, so keeping them on the '
            'instance would apply them twice',
      );
    });

    test('AN UNKNOWN OVERRIDE CLEARS THE FIELD in the fork rather than '
        'resurrecting the template figure', () {
      final doc = _doc(
        overrides: DeviceOverrides()..clear(DeviceOverrideField.weight),
      );

      final before = _mass(doc);
      expect(before.value, isNull);
      expect(before.unknownCount, 1);

      _fork(doc).apply(doc);

      expect(
        doc.templates['amp_fork@1']!.body.weight,
        isNull,
        reason: 'the disowned figure must not come back in the fork',
      );
      final after = _mass(doc);
      expect(after.value, isNull);
      expect(after.unknownCount, 1);
    });

    test('the device rebinds to the new template at version 1', () {
      final doc = _doc();
      _fork(doc).apply(doc);

      final ref = doc.devices[const Uuid('d1')]!.templateRef;
      expect(ref.templateId, const TemplateId('amp_fork'));
      expect(ref.version, 1);
      expect(doc.templates.containsKey('amp_fork@1'), isTrue);
    });

    test('OTHER instances of the source are untouched', () {
      final doc = _doc(devices: 2);
      _fork(doc).apply(doc);

      expect(
        doc.devices[const Uuid('d2')]!.templateRef.templateId,
        const TemplateId('amp'),
        reason: 'door 3 rebinds the one instance it was invoked on',
      );
      expect(doc.templates.containsKey('amp@1'), isTrue);
    });

    test('the source template is left exactly as it was', () {
      final doc = _doc(
        overrides: DeviceOverrides(weight: Mass.fromKilograms(11.3)),
      );
      final sourceWeight = doc.templates['amp@1']!.body.weight;

      _fork(doc).apply(doc);

      expect(
        doc.templates['amp@1']!.body.weight,
        sourceWeight,
        reason:
            'the fork copies; a shared list or a shallow clone would '
            'show up here first',
      );
    });
  });

  group('derivedFrom gets its first producer (CR-062)', () {
    test('records the source id and the version AT THE FORK', () {
      final doc = _doc();
      _fork(doc).apply(doc);

      expect(
        doc.templates['amp_fork@1']!.body.derivedFrom,
        const TemplateOrigin(templateId: TemplateId('amp'), version: 1),
      );
    });

    test('the source template says nothing, which is what an original '
        'says by saying nothing', () {
      final doc = _doc();
      _fork(doc).apply(doc);

      expect(doc.templates['amp@1']!.body.derivedFrom, isNull);
    });

    test('the stale-fork rule now has something to answer about', () {
      // `fork_status.dart` has carried this rule since M4-C with no
      // producer. This is the first time it can be asked a real question.
      final doc = _doc();
      _fork(doc).apply(doc);

      final forked = doc.templates['amp_fork@1']!.body;
      final resolved = resolveForkStatus(
        forked,
        sourceVersions: latestTemplateVersions(doc.templates),
      );
      expect(
        resolved.status,
        isNot(ForkStatus.original),
        reason:
            'a forked template is not an original, and until now '
            'nothing in the tree could produce one to check',
      );
      expect(resolved.origin, isNotNull);
    });
  });

  group('refusals name the reason rather than doing nothing', () {
    test('a device that is not in the document', () {
      final doc = _doc();
      final r = buildForkTemplateFromDevice(
        doc: doc,
        deviceId: const Uuid('nope'),
        newTemplateId: const TemplateId('x'),
        now: _later,
        actor: 'test',
      );
      expect(r, isA<ForkTemplateFailed>());
    });

    test('a snapshot that does not resolve, named with the designator', () {
      final doc = _doc()..templates.remove('amp@1');
      final r = buildForkTemplateFromDevice(
        doc: doc,
        deviceId: const Uuid('d1'),
        newTemplateId: const TemplateId('x'),
        now: _later,
        actor: 'test',
      );
      expect(r, isA<ForkTemplateFailed>());
      expect((r as ForkTemplateFailed).reason, contains('D1'));
    });

    test('an id this project already holds', () {
      final doc = _doc();
      final r = buildForkTemplateFromDevice(
        doc: doc,
        deviceId: const Uuid('d1'),
        newTemplateId: const TemplateId('amp'),
        now: _later,
        actor: 'test',
      );
      expect(r, isA<ForkTemplateFailed>());
      expect((r as ForkTemplateFailed).reason, contains('amp'));
    });
  });

  group('undo puts every part of it back', () {
    test('the ref, the overrides AND the minted template', () {
      final stated = Mass.fromKilograms(11.3);
      final doc = _doc(overrides: DeviceOverrides(weight: stated));

      _fork(doc)
        ..apply(doc)
        ..revert(doc);

      final device = doc.devices[const Uuid('d1')]!;
      expect(device.templateRef.templateId, const TemplateId('amp'));
      expect(device.templateRef.version, 1);
      expect(
        device.overrides.weight,
        stated,
        reason:
            'an undo that cleared the overrides would lose the edit '
            'the fork was built from',
      );
      expect(
        doc.templates.containsKey('amp_fork@1'),
        isFalse,
        reason:
            'a template left behind by an undone fork is a shelf entry '
            'nothing points at',
      );
    });

    test('and the rollup returns to where it started', () {
      final doc = _doc(
        overrides: DeviceOverrides()..clear(DeviceOverrideField.weight),
      );
      final before = _mass(doc);

      _fork(doc)
        ..apply(doc)
        ..revert(doc);

      final after = _mass(doc);
      expect(after.value, before.value);
      expect(after.unknownCount, before.unknownCount);
    });
  });

  test('the forked document round-trips byte-exactly (CR-117)', () {
    final doc = _doc(
      overrides: DeviceOverrides(weight: Mass.fromKilograms(11.3)),
    );
    _fork(doc).apply(doc);

    final bytes = const JsonDocumentCodec().write(doc);
    final back = const JsonDocumentCodec().read(bytes);
    expect(back, isA<Ok<RackDocument>>());
    expect(
      const JsonDocumentCodec().write((back as Ok<RackDocument>).value),
      bytes,
    );
    expect(
      back.value.templates['amp_fork@1']!.body.derivedFrom,
      const TemplateOrigin(templateId: TemplateId('amp'), version: 1),
      reason:
          'the lineage has to survive a save, or CR-062 badges nothing '
          'after a reopen',
    );
  });
}
