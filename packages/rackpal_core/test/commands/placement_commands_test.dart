// Moving a device between placements without removing it (DR-204
// §11.203.5, DR-205, `#953`, `#961`).
//
// Read against the committed fixture, because it has what these commands
// exist for: a shelf with devices on it, and links on those devices. The
// assertions are the artifact: the saved bytes, the links, the ids.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../scene/schematic_fixture.dart';

final DateTime _now = DateTime.utc(2026, 9, 30, 12);
const _actor = 'the-integrator';

DeviceInstance _byDesignator(RackDocument doc, String designator) =>
    doc.devices.values.singleWhere((d) => d.designator == designator);

/// Links touching [device]'s ports, as a set of ids, through the product's
/// own lookup.
Set<String> _linksOf(RackDocument doc, DeviceInstance device) => {
  for (final port in doc.ports.values)
    if (port.deviceId == device.id)
      for (final link in linksOnPort(doc, port.id)) link.v,
};

ReplacePlacementCommand _ready(PlacementPlan plan) => switch (plan) {
  PlacementPlanReady(:final command) => command,
  PlacementPlanRefused(:final reason) => fail('refused: $reason'),
};

String _refusal(PlacementPlan plan) => switch (plan) {
  PlacementPlanRefused(:final reason) => reason,
  PlacementPlanReady() => fail('expected a refusal'),
};

void main() {
  late RackDocument doc;
  const codec = JsonDocumentCodec();
  setUp(() => doc = readSchematicFixture());

  group('into the Staging Bin', () {
    test('a device on a shelf goes to the bin with its id, ports and links, '
        'and remembers its shelf', () {
      final stb = _byDesignator(doc, 'STB-1');
      final shelfId = (stb.placement as ShelfPlacement).hostDeviceId;
      final links = _linksOf(doc, stb);
      expect(links, isNotEmpty, reason: 'the fixture wires STB-1');

      _ready(
        planStageDevice(doc: doc, id: stb.id, now: _now, actor: _actor),
      ).apply(doc);

      final after = doc.devices[stb.id]!;
      expect(after.placement, isA<StagedPlacement>());
      expect((after.placement as StagedPlacement).lastHostDeviceId, shelfId);
      expect(_linksOf(doc, after), links);
      expect(stagedDevices(doc).map((d) => d.id), contains(stb.id));
    });

    test('UNDO PUTS BACK THE SAME BYTES (CR-117)', () {
      final before = codec.write(doc);
      final stb = _byDesignator(doc, 'STB-1');
      _ready(planStageDevice(doc: doc, id: stb.id, now: _now, actor: _actor))
        ..apply(doc)
        ..revert(doc);
      expect(codec.write(doc), before);
    });

    test('a rail device remembers its rack, U and face', () {
      final rail = doc.devices.values.firstWhere(
        (d) => d.placement is RailPlacement,
      );
      final was = rail.placement as RailPlacement;
      _ready(
        planStageDevice(doc: doc, id: rail.id, now: _now, actor: _actor),
      ).apply(doc);
      final staged = doc.devices[rail.id]!.placement as StagedPlacement;
      expect(
        (staged.lastRackId, staged.lastRuIndex, staged.lastFace),
        (was.rackId, was.ruIndex, was.face),
      );
    });

    test('and the new field survives a save and a read', () {
      final stb = _byDesignator(doc, 'STB-1');
      _ready(
        planStageDevice(doc: doc, id: stb.id, now: _now, actor: _actor),
      ).apply(doc);
      final bytes = codec.write(doc);
      final back = (codec.read(bytes) as Ok<RackDocument>).value;
      expect(
        (back.devices[stb.id]!.placement as StagedPlacement).lastHostDeviceId,
        (doc.devices[stb.id]!.placement as StagedPlacement).lastHostDeviceId,
      );
      expect(codec.write(back), bytes);
    });
  });

  group('back out of it', () {
    test('onto the shelf it came off, at the right-hand end', () {
      final stb = _byDesignator(doc, 'STB-1');
      final shelfId = (stb.placement as ShelfPlacement).hostDeviceId;
      _ready(
        planStageDevice(doc: doc, id: stb.id, now: _now, actor: _actor),
      ).apply(doc);
      _ready(
        planReturnFromStaging(doc: doc, id: stb.id, now: _now, actor: _actor),
      ).apply(doc);

      final hosts = devicesOnShelf(doc, shelfId);
      expect(hosts.last.id, stb.id);
    });

    test('onto its old U when that U is still free', () {
      final rail = doc.devices.values.firstWhere(
        (d) => d.placement is RailPlacement,
      );
      final was = rail.placement as RailPlacement;
      _ready(
        planStageDevice(doc: doc, id: rail.id, now: _now, actor: _actor),
      ).apply(doc);
      _ready(
        planReturnFromStaging(doc: doc, id: rail.id, now: _now, actor: _actor),
      ).apply(doc);
      final back = doc.devices[rail.id]!.placement as RailPlacement;
      expect(
        (back.rackId, back.ruIndex, back.face),
        (was.rackId, was.ruIndex, was.face),
      );
    });

    test('and REFUSES IN WORDS when somebody else has taken that U', () {
      final rail = doc.devices.values.firstWhere(
        (d) => d.placement is RailPlacement,
      );
      final was = rail.placement as RailPlacement;
      _ready(
        planStageDevice(doc: doc, id: rail.id, now: _now, actor: _actor),
      ).apply(doc);
      // Something else moves into the gap.
      final other = doc.devices.values.firstWhere(
        (d) => d.placement is RailPlacement && d.id != rail.id,
      );
      final otherWas = other.placement as RailPlacement;
      MoveDeviceCommand(
        id: other.id,
        fromRuIndex: otherWas.ruIndex,
        toRuIndex: was.ruIndex,
        fromFace: otherWas.face,
        toFace: otherWas.face,
        now: _now,
        actor: _actor,
      ).apply(doc);

      expect(
        _refusal(
          planReturnFromStaging(
            doc: doc,
            id: rail.id,
            now: _now,
            actor: _actor,
          ),
        ),
        contains('taken by ${other.designator}'),
      );
    });
  });

  group('along and between shelves', () {
    test('a host dragged to the front of its own shelf becomes first', () {
      final shelfId = (_byDesignator(doc, 'STB-1').placement as ShelfPlacement)
          .hostDeviceId;
      final last = devicesOnShelf(doc, shelfId).last;
      _ready(
        planMoveOntoShelf(
          doc: doc,
          id: last.id,
          hostId: shelfId,
          now: _now,
          actor: _actor,
        ),
      ).apply(doc);
      expect(devicesOnShelf(doc, shelfId).first.id, last.id);
    });

    test('and after a named neighbour it lands right after it', () {
      final shelfId = (_byDesignator(doc, 'STB-1').placement as ShelfPlacement)
          .hostDeviceId;
      final hosts = devicesOnShelf(doc, shelfId);
      final moving = hosts.first;
      final anchor = hosts[2];
      _ready(
        planMoveOntoShelf(
          doc: doc,
          id: moving.id,
          hostId: shelfId,
          after: anchor.id,
          now: _now,
          actor: _actor,
        ),
      ).apply(doc);
      final order = devicesOnShelf(doc, shelfId).map((d) => d.id).toList();
      expect(order.indexOf(moving.id), order.indexOf(anchor.id) + 1);
    });

    test('a device cannot be set on something that is not a shelf', () {
      final stb = _byDesignator(doc, 'STB-1');
      final notShelf = doc.devices.values.firstWhere(
        (d) =>
            d.placement is RailPlacement &&
            bodyFor(d, doc.templates)?.isContainer != true,
      );
      expect(
        _refusal(
          planMoveOntoShelf(
            doc: doc,
            id: stb.id,
            hostId: notShelf.id,
            now: _now,
            actor: _actor,
          ),
        ),
        contains('is not a shelf'),
      );
    });

    test('TOP-005 REFUSES A LOOP, which only a MOVE can make: a shelf '
        'cannot sit on itself', () {
      final shelfId = (_byDesignator(doc, 'STB-1').placement as ShelfPlacement)
          .hostDeviceId;
      final plan = planMoveOntoShelf(
        doc: doc,
        id: shelfId,
        hostId: shelfId,
        now: _now,
        actor: _actor,
      );
      expect(_refusal(plan), contains('cannot sit on itself'));
      expect((plan as PlacementPlanRefused).ruleId, 'TOP-005');
    });

    test('and the walk finds a loop through a device that sits on the '
        'mover, however far up the chain', () {
      final stb = _byDesignator(doc, 'STB-1');
      final shelfId = (stb.placement as ShelfPlacement).hostDeviceId;
      // STB-1 sits on the shelf, so the shelf onto STB-1 closes a loop.
      expect(shelfMoveWouldLoop(doc, shelfId, stb.id), isTrue);
      // And the other way round is only a move onto a shelf.
      expect(shelfMoveWouldLoop(doc, stb.id, shelfId), isFalse);
    });
  });
}
