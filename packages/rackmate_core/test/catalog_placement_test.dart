// Dedicated unit tests for catalog_placement.dart's pure logic:
// findLowestFreeRu, findBlockingOccupant, and buildPlaceFromCatalogCommand's
// `explicitRuIndex` parameter (the caret-targeted / drag-drop placement
// path, docs/04-rack-editor.md §3.2/§3.4). Before this stage, this logic
// was only exercised indirectly through seed_catalog_test.dart's "catalog
// placement" group (which always uses the full seeded catalog and only
// ever calls the lowest-free-U path) — this file fills that gap with a
// small, hand-built catalog so each behaviour is tested in isolation.

import 'package:rackmate_core/rackmate_core.dart';
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

/// A minimal rack-mountable template: [frontU] on the front face, real
/// occupancy (not the `notInRack` default), `rackEars`-mounted.
TemplateBody _rackTemplate({
  required int frontU,
  String model = 'test-device',
  String? typePrefix,
}) => TemplateBody(
  manufacturer: 'Test',
  model: model,
  displayName: model,
  typePrefix: typePrefix ?? 'DEV',
  frontU: frontU,
  side: OccupancySide.front,
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
    body: _rackTemplate(frontU: frontU, model: designator),
  );
  doc.devices[id] = device;
  return device;
}

void main() {
  group('findLowestFreeRu / findBlockingOccupant share one occupancy scan', () {
    test('findLowestFreeRu finds a gap between two occupants', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {});
      _place(doc, id: const Uuid('d1'), designator: 'A', rack: rack, ruIndex: 1, frontU: 2);
      _place(doc, id: const Uuid('d2'), designator: 'B', rack: rack, ruIndex: 5, frontU: 2);

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
      _place(doc, id: const Uuid('d1'), designator: 'A', rack: rack, ruIndex: 1, frontU: 2);

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
      _place(doc, id: const Uuid('d1'), designator: 'AMP-1', rack: rack, ruIndex: 4, frontU: 2);

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
      _place(doc, id: id, designator: 'SW-1', rack: rack, ruIndex: 7, frontU: 1);

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

    test('devices on the OTHER face never block', () {
      final rack = _rack();
      final doc = _docWithCatalog(rack, {});
      _place(
        doc,
        id: const Uuid('d1'),
        designator: 'PP-1',
        rack: rack,
        ruIndex: 5,
        face: Face.rear,
        frontU: 1,
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
      _place(doc, id: const Uuid('d1'), designator: 'AMP-1', rack: rack, ruIndex: 9, frontU: 2);
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

    test('omitting explicitRuIndex is unchanged: still the lowest free U',
        () {
      final rack = _rack();
      final catalog = {'V1': _rackTemplate(frontU: 1)};
      final doc = _docWithCatalog(rack, catalog);
      _place(doc, id: const Uuid('d1'), designator: 'A', rack: rack, ruIndex: 1, frontU: 1);

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
}
