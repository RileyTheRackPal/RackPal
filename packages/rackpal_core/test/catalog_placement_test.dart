// Dedicated unit tests for catalog_placement.dart's pure logic:
// findLowestFreeRu, findBlockingOccupant, and buildPlaceFromCatalogCommand's
// `explicitRuIndex` parameter (the caret-targeted / drag-drop placement
// path, docs/04-rack-editor.md §3.2/§3.4). Before this stage, this logic
// was only exercised indirectly through seed_catalog_test.dart's "catalog
// placement" group (which always uses the full seeded catalog and only
// ever calls the lowest-free-U path) — this file fills that gap with a
// small, hand-built catalog so each behaviour is tested in isolation.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 7, 18);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

Rack _rack({int heightU = 12}) => Rack(
  id: const Uuid('rk-1'),
  name: 'Test Rack',
  designator: 'RK-1',
  heightU: heightU,
  order: const FracIndex('a0'),
  meta: _meta(),
);

/// A minimal rack-mountable template: [frontU] on the front face and
/// [rearU] on the rear, real occupancy (not the `notInRack` default),
/// `rackEars`-mounted.
///
/// [rearU] defaults to 0 — a half-depth, front-only device — so the tests
/// that mean "occupies one face only" say so by construction. CR-036's
/// `side: both` case is the one where the occupancy struct and the mount
/// face diverge, and it has to be spelled out to be tested.
TemplateBody _rackTemplate({
  required int frontU,
  int rearU = 0,
  String model = 'test-device',
  String? typePrefix,
}) => TemplateBody(
  manufacturer: 'Test',
  model: model,
  displayName: model,
  typePrefix: typePrefix ?? 'DEV',
  frontU: frontU,
  rearU: rearU,
  side: frontU > 0 && rearU > 0
      ? OccupancySide.both
      : (rearU > 0 ? OccupancySide.rear : OccupancySide.front),
  mountMethod: MountMethod.rackEars,
);

TemplateBody _fieldTemplate({String model = 'test-field'}) => TemplateBody(
  manufacturer: 'Test',
  model: model,
  displayName: model,
  typePrefix: 'FLD',
);

RackDocument _docWithCatalog(Rack rack, Map<String, TemplateBody> catalog) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.racks[rack.id] = rack;
  for (final entry in catalog.entries) {
    doc.templates[catalogTemplateKey(entry.key)] = TemplateSnapshot(
      templateId: TemplateId(entry.key),
      version: 1,
      contentHash: 'sha256:test-${entry.key}',
      body: entry.value,
      capturedAt: _now,
    );
  }
  return doc;
}

DeviceInstance _place(
  RackDocument doc, {
  required Uuid id,
  required String designator,
  required Rack rack,
  required int ruIndex,
  Face face = Face.front,
  int frontU = 2,
  int rearU = 0,
}) {
  final device = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId('placed-$designator'),
      version: 1,
      contentHash: 'sha256:placed-$designator',
    ),
    designator: designator,
    name: designator,
    placement: RailPlacement(rackId: rack.id, ruIndex: ruIndex, face: face),
    meta: _meta(),
  );
  doc.templates['placed-$designator@1'] = TemplateSnapshot(
    templateId: TemplateId('placed-$designator'),
    version: 1,
    contentHash: 'sha256:placed-$designator',
    capturedAt: _now,
    body: _rackTemplate(frontU: frontU, rearU: rearU, model: designator),
  );
  doc.devices[id] = device;
  return device;
}

void main() {
  group('findLowestFreeRu / findBlockingOccupant share one occupancy scan', () {
    test('findLowestFreeRu finds a gap between two occupants', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {});
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'A',
        rack: rack,
        ruIndex: 1,
        frontU: 2,
      );
      _place(
        doc,
        id: const Uuid('d2'),
        designator: 'B',
        rack: rack,
        ruIndex: 5,
        frontU: 2,
      );

      final ru = findLowestFreeRu(
        rack: rack,
        devices: doc.devices.values,
        face: Face.front,
        templates: doc.templates,
        deviceH: 2,
      );
      // U1-2 and U5-6 occupied; U3-4 is the lowest free 2U gap.
      expect(ru, 3);
    });

    test('findBlockingOccupant returns null for a genuinely free range', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {});
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'A',
        rack: rack,
        ruIndex: 1,
        frontU: 2,
      );

      final blocker = findBlockingOccupant(
        rack: rack,
        devices: doc.devices.values,
        face: Face.front,
        templates: doc.templates,
        ruStart: 5,
        deviceH: 2,
      );
      expect(blocker, isNull);
    });

    test('findBlockingOccupant reports the exact occupant overlapping the '
        'range', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {});
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'AMP-1',
        rack: rack,
        ruIndex: 4,
        frontU: 2,
      );

      final blocker = findBlockingOccupant(
        rack: rack,
        devices: doc.devices.values,
        face: Face.front,
        templates: doc.templates,
        ruStart: 5, // overlaps AMP-1's U4-U5 at U5
        deviceH: 2,
      );
      expect(blocker, isNotNull);
      expect(blocker!.designator, 'AMP-1');
    });

    test('exceptId excludes a device from blocking its OWN current range', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {});
      final id = const Uuid('d1');
      _place(
        doc,
        id: id,
        designator: 'SW-1',
        rack: rack,
        ruIndex: 7,
        frontU: 1,
      );

      final blocker = findBlockingOccupant(
        rack: rack,
        devices: doc.devices.values,
        face: Face.front,
        templates: doc.templates,
        ruStart: 7,
        deviceH: 1,
        exceptId: id,
      );
      expect(blocker, isNull);
    });

    test('a device that occupies ONLY the other face never blocks', () {
      // A genuinely rear-only patch panel: `frontU 0 / rearU 1`. Nothing
      // of it is on the front elevation, so nothing of it is in the way
      // there. This used to be spelled as "mounted on the rear rails",
      // which is a DIFFERENT statement — see the test below.
      final rack = _rack();
      final doc = _docWithCatalog(rack, {});
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'PP-1',
        rack: rack,
        ruIndex: 5,
        face: Face.rear,
        frontU: 0,
        rearU: 1,
      );

      final blocker = findBlockingOccupant(
        rack: rack,
        devices: doc.devices.values,
        face: Face.front,
        templates: doc.templates,
        ruStart: 5,
        deviceH: 1,
      );
      expect(blocker, isNull);
    });

    test('a FRONT-mounted side:both device BLOCKS the rear range it is '
        'drawn across (docs/04 §2.2, CR-036)', () {
      // `whole_house` RK-1, exactly: UPS-1 is bolted to the FRONT rails at
      // U1 with `frontU 3 / rearU 3 / side: both`, so the rear elevation
      // draws it over rear U1-U3. The scan used to filter on
      // `placement.face == face`, so `findLowestFreeRu(face: rear,
      // deviceH: 1)` answered 1 and `findBlockingOccupant` reported the
      // range free — the insertion caret sat on top of UPS-1's drawn
      // block and a palette drop onto rear U1 was evaluated "not blocked",
      // with no "Occupied by UPS-1 (U1-U3)" reason. Committing it put two
      // device blocks in the same rear U on the canvas AND on T2.02.
      final rack = _rack(heightU: 42);
      final doc = _docWithCatalog(rack, {});
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'UPS-1',
        rack: rack,
        ruIndex: 1,
        frontU: 3,
        rearU: 3,
      );

      final blocker = findBlockingOccupant(
        rack: rack,
        devices: doc.devices.values,
        face: Face.rear,
        templates: doc.templates,
        ruStart: 1,
        deviceH: 1,
      );
      expect(blocker, isNotNull);
      expect(blocker!.designator, 'UPS-1');

      expect(
        findLowestFreeRu(
          rack: rack,
          devices: doc.devices.values,
          face: Face.rear,
          templates: doc.templates,
          deviceH: 1,
        ),
        4,
        reason:
            'rear U1-U3 is where UPS-1 is drawn; U4 is the first free '
            'rear slot',
      );

      // The front face is unchanged by the repair: UPS-1 blocked front
      // U1-U3 before and blocks it now.
      expect(
        findLowestFreeRu(
          rack: rack,
          devices: doc.devices.values,
          face: Face.front,
          templates: doc.templates,
          deviceH: 1,
        ),
        4,
      );
    });

    test('the caret-targeted quick-add path names the cross-face occupant '
        'in its refusal', () {
      // The same case one layer up: `buildPlaceFromCatalogCommand` with an
      // explicit caret on rear U2 must FAIL with UPS-1's designator and
      // range, not quietly succeed into occupied space.
      final rack = _rack(heightU: 42);
      final doc = _docWithCatalog(rack, {
        'V1': _rackTemplate(frontU: 0, rearU: 1, model: 'rear blank'),
      });
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'UPS-1',
        rack: rack,
        ruIndex: 1,
        frontU: 3,
        rearU: 3,
      );

      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V1',
        targetRack: rack,
        now: _now,
        actor: 'test',
        explicitRuIndex: 2,
      );

      expect(result, isA<CatalogPlacementFailed>());
      expect(
        (result as CatalogPlacementFailed).reason,
        'Occupied by UPS-1 (U1-U3).',
      );
    });
  });

  group('buildPlaceFromCatalogCommand — explicitRuIndex (caret targeting)', () {
    test('places exactly at explicitRuIndex when the range is free, NOT '
        'the lowest free U', () {
      final rack = _rack();
      final catalog = {'V1': _rackTemplate(frontU: 1)};
      final doc = _docWithCatalog(rack, catalog);
      // U1 is free (nothing placed) but the caret says U6 — the whole
      // point of explicitRuIndex is that it does NOT fall back to U1.
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V1',
        targetRack: rack,
        now: _now,
        actor: 'tester',
        explicitRuIndex: 6,
      );
      expect(result, isA<CatalogPlacementReady>());
      final placement =
          (result as CatalogPlacementReady).command.placement as RailPlacement;
      expect(placement.ruIndex, 6);
      expect(placement.face, Face.front);
    });

    test('fails with the occupant\'s designator and range when the caret '
        'lands on an existing device', () {
      final rack = _rack();
      final catalog = {'V1': _rackTemplate(frontU: 2)};
      final doc = _docWithCatalog(rack, catalog);
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'AMP-1',
        rack: rack,
        ruIndex: 9,
        frontU: 2,
      );
      // AMP-1 occupies U9-U10 on a 12U rack; target U10 overlaps it.
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V1',
        targetRack: rack,
        now: _now,
        actor: 'tester',
        explicitRuIndex: 10,
      );
      expect(result, isA<CatalogPlacementFailed>());
      final reason = (result as CatalogPlacementFailed).reason;
      expect(reason, contains('AMP-1'));
      expect(reason, contains('U9'));
      expect(reason, contains('U10'));
    });

    test('fails with a "Needs NU, only MU free at top" message when the '
        'caret would overflow the rack', () {
      final rack = _rack(heightU: 12);
      final catalog = {'V4': _rackTemplate(frontU: 4)};
      final doc = _docWithCatalog(rack, catalog);
      // U11 + 4U - 1 = U14, past the 12U rack; only 2U (U11-U12) free at
      // the top.
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V4',
        targetRack: rack,
        now: _now,
        actor: 'tester',
        explicitRuIndex: 11,
      );
      expect(result, isA<CatalogPlacementFailed>());
      final reason = (result as CatalogPlacementFailed).reason;
      expect(reason, contains('Needs 4U'));
      expect(reason, contains('only 2U free at top'));
    });

    test('a field (notInRack) template ignores explicitRuIndex entirely — '
        'still off-rack', () {
      final rack = _rack();
      final catalog = {'F1': _fieldTemplate()};
      final doc = _docWithCatalog(rack, catalog);
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'F1',
        targetRack: rack,
        now: _now,
        actor: 'tester',
        explicitRuIndex: 6,
      );
      expect(result, isA<CatalogPlacementReady>());
      expect(
        (result as CatalogPlacementReady).command.placement,
        isA<OffRackPlacement>(),
      );
    });

    test('omitting explicitRuIndex is unchanged: still the lowest free U', () {
      final rack = _rack();
      final catalog = {'V1': _rackTemplate(frontU: 1)};
      final doc = _docWithCatalog(rack, catalog);
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'A',
        rack: rack,
        ruIndex: 1,
        frontU: 1,
      );

      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V1',
        targetRack: rack,
        now: _now,
        actor: 'tester',
      );
      expect(result, isA<CatalogPlacementReady>());
      final placement =
          (result as CatalogPlacementReady).command.placement as RailPlacement;
      expect(placement.ruIndex, 2); // U1 occupied, U2 is the lowest free.
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // DR-077 §11.76.3: placement resolves the NEWEST version of an id.
  // ═════════════════════════════════════════════════════════════════════
  // The key was pinned to `"$id@1"`, which was invisible for as long as
  // nothing could save a second version. `#735` makes a second Save fork
  // one, at which point a pinned read places a stale body.
  group('buildPlaceFromCatalogCommand — the version it resolves', () {
    test('places the newest version when a document holds two', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {
        'tpl.amp': _rackTemplate(frontU: 1, model: 'amp v1'),
      });
      doc.templates['tpl.amp@2'] = TemplateSnapshot(
        templateId: const TemplateId('tpl.amp'),
        version: 2,
        contentHash: 'unhashed:tpl.amp@2',
        body: _rackTemplate(frontU: 2, model: 'amp v2'),
        capturedAt: _now,
      );

      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'tpl.amp',
        targetRack: rack,
        now: _now,
        actor: 'tester',
      );

      final ready = result as CatalogPlacementReady;
      expect(ready.command.templateRef.version, 2);
      expect(ready.command.name, 'amp v2');
      // The 2U height of v2 is what the placement was computed against,
      // which is the half a stale read would have got wrong silently.
      expect(ready.command.templateRef.contentHash, 'unhashed:tpl.amp@2');
    });

    test('a device placed from v1 keeps resolving v1 after v2 exists', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {
        'tpl.amp': _rackTemplate(frontU: 1, model: 'amp v1'),
      });
      final first =
          (buildPlaceFromCatalogCommand(
                    doc: doc,
                    catalogId: 'tpl.amp',
                    targetRack: rack,
                    now: _now,
                    actor: 'tester',
                  )
                  as CatalogPlacementReady)
              .command
            ..apply(doc);

      doc.templates['tpl.amp@2'] = TemplateSnapshot(
        templateId: const TemplateId('tpl.amp'),
        version: 2,
        contentHash: 'unhashed:tpl.amp@2',
        body: _rackTemplate(frontU: 2, model: 'amp v2'),
        capturedAt: _now,
      );

      expect(doc.devices[first.id]!.templateRef.version, 1);
      expect(bodyFor(doc.devices[first.id]!, doc.templates)!.model, 'amp v1');
    });

    test('an id no version of which is present still refuses by name', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {
        'V1': _rackTemplate(frontU: 1),
      });
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'NOPE',
        targetRack: rack,
        now: _now,
        actor: 'tester',
      );
      expect(
        (result as CatalogPlacementFailed).reason,
        'Unknown catalog template "NOPE".',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // PLAN-E/2: THE THIRD DROP TARGET (docs/15 §6, CR-104)
  // ═════════════════════════════════════════════════════════════════════
  // The property every case here is really about is docs/15 §6's "in one
  // command, so one undo restores both". These assert the ARTIFACT that
  // guarantees it: exactly one command comes back, and the pin is on the
  // placement it creates rather than arriving behind a second write.
  group('PLAN-E/2: a device dropped on a plan', () {
    test('is placed off-rack with its pin, by one command', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {'F1': _fieldTemplate()});
      final underlay = _underlay(doc, locationId: const Uuid('loc-1'));

      final result = buildPlaceOnPlanCommand(
        doc: doc,
        catalogId: 'F1',
        now: _now,
        actor: 'tester',
        onPlan: (
          locationId: underlay.locationId,
          pin: PlanPin(underlayId: underlay.id, at: const PxPt(120, 340)),
        ),
      );

      final command = (result as CatalogPlacementReady).command..apply(doc);
      final device = doc.devices.values.single;
      final placement = device.placement as OffRackPlacement;
      expect(placement.planPin?.underlayId, underlay.id);
      expect(placement.planPin?.at, const PxPt(120, 340));
      expect(placement.locationId, const Uuid('loc-1'));

      // ONE UNDO RESTORES BOTH. The pin rides on the placement, so there
      // is no second write for a revert to miss and no window in which
      // the device exists unpinned.
      command.revert(doc);
      expect(doc.devices, isEmpty);
    });

    test(
      'takes the underlay location, and an unlocated plan gives no room',
      () {
        // G4: a site plan depicts no room, so `null` is an honest unknown
        // rather than a room guessed from a picture (docs/15 §3.4).
        final rack = _rack();
        final doc = _docWithCatalog(rack, {'F1': _fieldTemplate()});
        final underlay = _underlay(doc);
        expect(underlay.locationId, isNull);

        final result = buildPlaceOnPlanCommand(
          doc: doc,
          catalogId: 'F1',
          now: _now,
          actor: 'tester',
          onPlan: (
            locationId: underlay.locationId,
            pin: PlanPin(underlayId: underlay.id, at: const PxPt(5, 6)),
          ),
        );
        (result as CatalogPlacementReady).command.apply(doc);
        final placement =
            doc.devices.values.single.placement as OffRackPlacement;
        expect(placement.locationId, isNull);
        expect(placement.planPin?.at, const PxPt(5, 6));
      },
    );

    test('a RACK-MOUNTABLE template lands off-rack too, because a plan is '
        'not a rack', () {
      // CR-104: the drop target decides. A 2U amplifier dropped on a
      // floorplan is an off-rack amplifier, which is what a rack-shaped
      // box in a credenza actually is. The interesting half is that the
      // rack in this document is untouched: an rail-mount template plus a
      // present rack is exactly the input that would take the RailPlacement
      // branch if the plan target were ignored.
      final rack = _rack();
      final doc = _docWithCatalog(rack, {'A1': _rackTemplate(frontU: 2)});
      final underlay = _underlay(doc);

      final result = buildPlaceOnPlanCommand(
        doc: doc,
        catalogId: 'A1',
        now: _now,
        actor: 'tester',
        onPlan: (
          locationId: null,
          pin: PlanPin(underlayId: underlay.id, at: const PxPt(9, 9)),
        ),
      );
      (result as CatalogPlacementReady).command.apply(doc);
      final device = doc.devices.values.single;
      expect(device.placement, isA<OffRackPlacement>());
      expect((device.placement as OffRackPlacement).planPin, isNotNull);
    });

    test('a pin naming an underlay the document lost is REFUSED, and no '
        'device is created', () {
      // SetPlanPinCommand answers this by returning without writing,
      // which is right when the carrier already exists. Here the same
      // silence would create a device and discard the one thing the
      // gesture was about.
      final rack = _rack();
      final doc = _docWithCatalog(rack, {'F1': _fieldTemplate()});

      final result = buildPlaceOnPlanCommand(
        doc: doc,
        catalogId: 'F1',
        now: _now,
        actor: 'tester',
        onPlan: (
          locationId: null,
          pin: const PlanPin(
            underlayId: Uuid('gone'),
            at: PxPt(1, 1),
          ),
        ),
      );
      expect(result, isA<CatalogPlacementFailed>());
      expect(
        (result as CatalogPlacementFailed).reason,
        contains(
          'not in the '
          'project any more',
        ),
      );
      expect(doc.devices, isEmpty);
    });

    // NO "NEITHER TARGET" CASE, AND ITS ABSENCE IS THE POINT.
    //
    // The first draft of this feature put an `onPlan:` argument on
    // `buildPlaceFromCatalogCommand` and relaxed `targetRack` to `Rack?`,
    // which made "called with no target at all" reachable and therefore
    // worth a test. It also made nine existing `targetRack: doc.racks[id]!`
    // call sites carry an unnecessary `!` — and those `!` are the thing
    // that turns a missing rack into an immediate throw at the line that
    // got it wrong. The analyzer caught the redundancy; the design cost
    // was the eager failure behind it.
    //
    // `buildPlaceOnPlanCommand` is a separate entry point for exactly that
    // reason, so a call with no target does not compile. A test asserting
    // a refusal here would be asserting a state the types forbid.
  });
}

/// Adds one underlay to [doc] and returns it. Nothing here decodes an
/// image: `PlanUnderlay` stores its own pixel size for exactly that
/// reason (docs/15 §3.1).
PlanUnderlay _underlay(RackDocument doc, {Uuid? locationId}) {
  final underlay = PlanUnderlay(
    id: const Uuid('ul-1'),
    name: 'Level 1',
    locationId: locationId,
    imageMember: 'underlays/ul-1.png',
    format: PlanImageFormat.png,
    pixelWidth: 2000,
    pixelHeight: 1400,
    contentHash: 'sha256:test-underlay',
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.underlays[underlay.id] = underlay;
  return underlay;
}
