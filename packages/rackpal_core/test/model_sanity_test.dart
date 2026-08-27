// Sanity checks that the model/ entity graph (docs/02-data-model.md §4)
// constructs correctly and the load-bearing invariants hold. Byte-level
// round-trip tests belong to the persistence stage next; this file only
// confirms the Dart types compile together, wire up correctly, and behave
// as documented.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

void main() {
  group('RackDocument — the aggregate constructs and holds entities', () {
    test('an empty document has sensible defaults', () {
      final doc = RackDocument(
        id: const Uuid('doc-1'),
        appVersion: '0.1.0',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: _meta(),
      );

      expect(doc.schemaVersion, kSchemaVersion);
      expect(doc.sequence, 0);
      expect(doc.stateId, 0);
      expect(doc.racks, isEmpty);
      expect(doc.sheets, isEmpty);
      expect(doc.info.projectName, 'Untitled Project');
      expect(doc.settings.displayUnits, UnitSystem.imperial);
      expect(doc.settings.cableWasteFactor, const Permille(100));
    });

    test('a rack, device, port and link all join up', () {
      final rack = Rack(
        id: const Uuid('rack-1'),
        name: 'AV Rack',
        designator: 'RK-1',
        heightU: 12,
        order: const FracIndex('a0'),
        meta: _meta(),
      );

      const deviceId = Uuid('dev-1');
      final device = DeviceInstance(
        id: deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.generic.hdmi_matrix_4x4'),
          version: 2,
          contentHash: 'sha256:deadbeef',
        ),
        designator: 'MTX-1',
        name: '4x4 HDMI Matrix',
        placement: RailPlacement(
          rackId: rack.id,
          ruIndex: 3,
          face: Face.rear,
        ),
        meta: _meta(),
      );

      const portKey = PortKey('hdmi_in_1');
      final port = Port(
        id: derivePortId(deviceId, portKey),
        deviceId: deviceId,
        designator: 'J01',
        templatePortKey: portKey,
      );

      final link = Link(
        id: const Uuid('link-1'),
        designator: 'W001',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        meta: _meta(),
        conductors: [
          Conductor(from: PortEndpoint(port.id), to: const OpenEndpoint('TV')),
        ],
      );

      final doc =
          RackDocument(
              id: const Uuid('doc-2'),
              appVersion: '0.1.0',
              createdAt: DateTime.utc(2026),
              modifiedAt: DateTime.utc(2026),
              meta: _meta(),
            )
            ..racks[rack.id] = rack
            ..devices[device.id] = device
            ..ports[port.id] = port
            ..links[link.id] = link;

      expect(doc.racks[rack.id]!.heightU, 12);
      expect(doc.devices[deviceId]!.designator, 'MTX-1');
      expect(doc.links[link.id]!.conductors, hasLength(1));
      expect(
        (doc.devices[deviceId]!.placement as RailPlacement).ruIndex,
        3,
      );
    });
  });

  group('Placement — sealed union is exhaustively switchable', () {
    test('every variant resolves through a switch with no default', () {
      String describe(Placement p) => switch (p) {
        RailPlacement(:final ruIndex) => 'rail:$ruIndex',
        ShelfPlacement(:final hostDeviceId) => 'shelf:${hostDeviceId.v}',
        ZeroUPlacement(:final channelId) => 'zeroU:$channelId',
        OffRackPlacement() => 'offRack',
        StagedPlacement() => 'staged',
      };

      expect(
        describe(
          const RailPlacement(
            rackId: Uuid('r1'),
            ruIndex: 5,
            face: Face.front,
          ),
        ),
        'rail:5',
      );
      expect(describe(const StagedPlacement()), 'staged');
      expect(describe(const OffRackPlacement()), 'offRack');
    });
  });

  group('Port — deterministic template-derived id (CR-116, AC-006)', () {
    test('the same (deviceId, portKey) always derives the same id', () {
      const deviceId = Uuid('dev-42');
      const portKey = PortKey('hdmi_out_3');

      final first = derivePortId(deviceId, portKey);
      final second = derivePortId(deviceId, portKey);

      expect(first, equals(second));
    });

    test('a different portKey derives a different id', () {
      const deviceId = Uuid('dev-42');
      final a = derivePortId(deviceId, const PortKey('hdmi_out_1'));
      final b = derivePortId(deviceId, const PortKey('hdmi_out_2'));

      expect(a, isNot(equals(b)));
    });
  });

  group('Circuit — derived NEC continuous limit (CR-048)', () {
    test('80% of the breaker rating, never stored', () {
      final circuit = Circuit(
        id: const Uuid('circuit-1'),
        designator: 'Panel A / Breaker 14',
        breakerAmps: 20,
        volts: 120,
        meta: _meta(),
      );

      expect(circuit.continuousLimitAmps, 16);
    });
  });

  group('@internal setters are usable from within the package', () {
    test('Rack.name/designator/heightU are mutable via their setters', () {
      final rack =
          Rack(
              id: const Uuid('rack-2'),
              name: 'Old Name',
              designator: 'RK-2',
              heightU: 12,
              order: const FracIndex('a0'),
              meta: _meta(),
            )
            ..name = 'New Name'
            ..designator = 'RK-2A'
            ..heightU = 24;

      expect(rack.name, 'New Name');
      expect(rack.designator, 'RK-2A');
      expect(rack.heightU, 24);
    });
  });

  group('EntityMeta — the one mutation entry point', () {
    test('touch() advances updatedAt/updatedBy and localRevision', () {
      final meta = _meta();
      final createdAt = meta.createdAt;
      final later = DateTime.utc(2026, 7, 18);

      meta.touch(later, 'rriley');

      expect(meta.createdAt, createdAt); // never changes
      expect(meta.updatedAt, later);
      expect(meta.updatedBy, 'rriley');
      expect(meta.localRevision, 1);
    });
  });

  group('IdFormat integration — ProjectSettings default patterns render', () {
    test('the default device designator format matches the worked example', () {
      final settings = ProjectSettings();
      final rendered = settings.deviceDesignatorFormat.render({
        'TYPE_PREFIX': 'MTX',
        'SEP': '-',
        'SEQ': 1,
      });

      expect(rendered, 'MTX-1');
    });
  });
}
