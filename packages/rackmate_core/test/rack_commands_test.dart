// AddRackCommand — the command docs/09-roadmap.md M1's exit criterion
// ("a user … creates a 42U rack") names and this repository did not have
// (docs/12-milestone-board.md §3.2 clause 2).
//
// The three properties every command in this package owes
// (docs/03-architecture.md §5.1) are asserted here against the REAL
// `JsonDocumentCodec` bytes rather than semantically, because CR-117 is a
// byte property and a semantic comparison would pass on a document whose
// map ORDER had changed:
//
//   * `apply; revert` restores the bytes exactly;
//   * `apply; revert; apply` lands on the same bytes as a single `apply`;
//   * the id is minted in the constructor, so redo recreates the identical
//     entity (asserted by taking the id BEFORE the first apply and finding
//     the same key after the second).
import 'dart:convert';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 7, 27, 12);

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

RackDocument _docWithOneRack({String designator = 'RK-1'}) {
  final doc = RackDocument(
    id: const Uuid('doc-add-rack-test'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
  );
  doc.racks[const Uuid('rack-seed')] = Rack(
    id: const Uuid('rack-seed'),
    name: 'Rack 1',
    designator: designator,
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  return doc;
}

RackDocument _emptyDoc() => RackDocument(
  id: const Uuid('doc-add-rack-test-empty'),
  appVersion: '0.1.0',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: _meta(),
);

List<int> _bytes(RackDocument doc) => _codec.write(doc);

Map<String, Object?> _racksJson(RackDocument doc) {
  final root =
      jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
  final document = root['document']! as Map<String, Object?>;
  return document['racks']! as Map<String, Object?>;
}

Map<String, Object?> _rackJson(RackDocument doc, Uuid id) =>
    _racksJson(doc)[id.v]! as Map<String, Object?>;

void main() {
  group('AddRackCommand', () {
    test('apply inserts the rack; revert removes it (CR-117 byte identity)',
        () {
      final doc = _docWithOneRack();
      final before = _bytes(doc);

      final cmd = AddRackCommand(
        name: 'Media Closet',
        designator: 'RK-2',
        heightU: 42,
        order: const FracIndex('a1'),
        now: _now,
        actor: 'local',
      )..apply(doc);

      expect(doc.racks, hasLength(2));
      final created = doc.racks[cmd.id]!;
      expect(created.heightU, 42);
      expect(created.name, 'Media Closet');
      expect(created.designator, 'RK-2');
      final afterFirstApply = _bytes(doc);

      cmd.revert(doc);
      expect(doc.racks, hasLength(1));
      expect(
        _bytes(doc),
        before,
        reason: 'apply; revert must restore the exact bytes (CR-117)',
      );

      // The trailing `apply` half of `apply; revert; apply`. The id was
      // minted in the constructor, so this recreates the identical entity
      // rather than a second rack under a new id.
      cmd.apply(doc);
      expect(doc.racks.keys, contains(cmd.id));
      expect(
        _bytes(doc),
        afterFirstApply,
        reason: 'redo must be byte-identical to the original apply',
      );
    });

    test('stamps EntityMeta from its own `now`/`actor`, not the clock', () {
      final doc = _docWithOneRack();
      final cmd = AddRackCommand(
        name: 'Media Closet',
        designator: 'RK-2',
        heightU: 12,
        order: const FracIndex('a1'),
        now: _now,
        actor: 'unit-test',
      )..apply(doc);

      final meta = doc.racks[cmd.id]!.meta;
      expect(meta.createdAt, _now);
      expect(meta.updatedAt, _now);
      expect(meta.updatedBy, 'unit-test');
    });

    test('declares rack|meta, affects its own id, and is labelled addRack',
        () {
      final cmd = AddRackCommand(
        name: 'Media Closet',
        designator: 'RK-2',
        heightU: 12,
        order: const FracIndex('a1'),
        now: _now,
        actor: 'local',
      );
      expect(cmd.label, LabelKey.addRack);
      expect(cmd.touches.has(EpochMask.rack), isTrue);
      expect(cmd.touches.has(EpochMask.meta), isTrue);
      expect(cmd.affects, [cmd.id]);
      // No merge behaviour: two rack creations are two undo entries.
      expect(cmd.mergeKey, isNull);
    });

    test('carries the preset facts onto the new rack', () {
      final doc = _docWithOneRack();
      final preset = buildRackPresets()['swingGate12U']!;
      final result = buildAddRackCommand(
        doc: doc,
        name: 'Gate',
        heightU: preset.heightU,
        now: _now,
        actor: 'local',
        preset: preset,
      );
      final cmd = (result as AddRackReady).command..apply(doc);

      final rack = doc.racks[cmd.id]!;
      expect(rack.heightU, 12);
      expect(rack.formFactor, RackFormFactor.wallSwingGate);
      expect(rack.widthClass, preset.widthClass);
      expect(rack.railType, preset.railType);
      expect(rack.usableDepth, preset.usableDepth);
      expect(rack.weightCapacity, preset.weightCapacity);
      expect(rack.isSwingFrame, isTrue);
      expect(rack.hingeSide, HingeSide.left);
    });

    test('the typed height OVERRIDES the preset height (docs/04 §9 lists '
        'Preset and Height as two fields)', () {
      final doc = _docWithOneRack();
      final preset = buildRackPresets()['floorEnclosure44U']!;
      expect(preset.heightU, 44);

      final result = buildAddRackCommand(
        doc: doc,
        name: 'Main',
        heightU: 42,
        now: _now,
        actor: 'local',
        preset: preset,
      );
      final cmd = (result as AddRackReady).command..apply(doc);
      final rack = doc.racks[cmd.id]!;
      expect(rack.heightU, 42);
      // …and the archetype's other facts still landed, so the rack is a
      // floor enclosure that happens to be 42U — which is exactly what
      // the inspector will read back as "Custom".
      expect(rack.formFactor, RackFormFactor.floorEnclosure);
      expect(rack.usableDepth, preset.usableDepth);
    });

    test("with no preset, every non-dialog field keeps Rack's own default",
        () {
      final doc = _docWithOneRack();
      final cmd =
          (buildAddRackCommand(
                    doc: doc,
                    name: 'Plain',
                    heightU: 42,
                    now: _now,
                    actor: 'local',
                  )
                  as AddRackReady)
              .command
            ..apply(doc);
      final rack = doc.racks[cmd.id]!;
      // The three §9 does NOT ask about must not be invented (G4).
      expect(rack.locationId, isNull);
      expect(rack.ruNumbering, RuNumbering.bottomUpFromOne);
      expect(rack.mirrorRearElevation, isTrue);
      expect(rack.usableDepth, isNull);
      expect(rack.weightCapacity, isNull);
    });

    test('the persisted rack survives a full write/read round trip', () {
      final doc = _docWithOneRack();
      final cmd =
          (buildAddRackCommand(
                    doc: doc,
                    name: 'Media Closet',
                    heightU: 42,
                    now: _now,
                    actor: 'local',
                    preset: buildRackPresets()['data42U36in'],
                  )
                  as AddRackReady)
              .command
            ..apply(doc);

      final reread = _codec.read(_codec.write(doc)) as Ok<RackDocument>;
      final reloaded = reread.value.racks[cmd.id]!;
      expect(reloaded.designator, 'RK-2');
      expect(reloaded.heightU, 42);
      expect(reloaded.usableDepth, const Len(36 * Len.nmPerInch));
      expect(
        _codec.write(reread.value),
        _codec.write(doc),
        reason: 'write(read(write(doc))) == write(doc) — CR-117',
      );
    });

    test('the encoded rack carries the height the command was given', () {
      final doc = _docWithOneRack();
      final cmd = AddRackCommand(
        name: 'Media Closet',
        designator: 'RK-2',
        heightU: 42,
        order: const FracIndex('a1'),
        now: _now,
        actor: 'local',
      )..apply(doc);
      expect(_rackJson(doc, cmd.id)['heightU'], 42);
    });
  });

  group('allocateRackDesignator (docs/04 §7, CR-040/CR-048)', () {
    test('RK-1 in an empty document, then RK-2, then RK-3', () {
      final doc = _emptyDoc();
      expect(allocateRackDesignator(doc: doc), 'RK-1');

      AddRackCommand(
        name: 'A',
        designator: allocateRackDesignator(doc: doc),
        heightU: 42,
        order: const FracIndex('a0'),
        now: _now,
        actor: 'local',
      ).apply(doc);
      expect(allocateRackDesignator(doc: doc), 'RK-2');

      AddRackCommand(
        name: 'B',
        designator: allocateRackDesignator(doc: doc),
        heightU: 42,
        order: const FracIndex('a1'),
        now: _now,
        actor: 'local',
      ).apply(doc);
      expect(allocateRackDesignator(doc: doc), 'RK-3');
    });

    test('fills the lowest unused integer, not max+1', () {
      final doc = _emptyDoc();
      for (final (index, designator) in ['RK-1', 'RK-3'].indexed) {
        AddRackCommand(
          name: designator,
          designator: designator,
          heightU: 42,
          order: FracIndex('a$index'),
          now: _now,
          actor: 'local',
        ).apply(doc);
      }
      expect(allocateRackDesignator(doc: doc), 'RK-2');
    });

    test('honours a project-customised separator', () {
      final doc = _emptyDoc()..settings.designatorSeparator = '.';
      expect(allocateRackDesignator(doc: doc), 'RK.1');
    });
  });

  group('nextRackOrder', () {
    /// The exact comparator `equipment_list.dart` and `SheetSet.forRacks`
    /// sort racks by — restated here so this test cannot pass under a
    /// comparison the production code does not use.
    int cmp(FracIndex a, FracIndex b) => a.v.compareTo(b.v);

    test('an empty document starts at a0', () {
      expect(nextRackOrder(const <FracIndex>[]).v, 'a0');
    });

    test('bumps the last character of the largest index', () {
      expect(nextRackOrder(const [FracIndex('a0')]).v, 'a1');
      expect(nextRackOrder(const [FracIndex('a0'), FracIndex('a1')]).v, 'a2');
    });

    test('crosses the alphabet class boundaries in ASCII order', () {
      expect(nextRackOrder(const [FracIndex('a9')]).v, 'aA');
      expect(nextRackOrder(const [FracIndex('aZ')]).v, 'aa');
    });

    test('extends rather than wrapping at the last character', () {
      expect(nextRackOrder(const [FracIndex('az')]).v, 'az0');
    });

    test('an unrecognised trailing character extends rather than throwing',
        () {
      expect(nextRackOrder(const [FracIndex('a~')]).v, 'a~0');
    });

    test('the result sorts strictly after every input, for 200 successive '
        'appends', () {
      final orders = <FracIndex>[const FracIndex('a0')];
      for (var i = 0; i < 200; i++) {
        final next = nextRackOrder(orders);
        for (final existing in orders) {
          expect(
            cmp(next, existing),
            greaterThan(0),
            reason: '$next must sort after $existing',
          );
        }
        orders.add(next);
      }
      // And the whole run is already in ascending order — the property the
      // elevation sheet order depends on.
      final sorted = [...orders]..sort(cmp);
      expect(sorted, orders);
    });
  });

  group('buildAddRackCommand refuses loudly (docs/04 §3.4)', () {
    test('an empty or whitespace name is refused with a reason', () {
      final doc = _docWithOneRack();
      for (final name in ['', '   ', '\t']) {
        final result = buildAddRackCommand(
          doc: doc,
          name: name,
          heightU: 42,
          now: _now,
          actor: 'local',
        );
        expect(result, isA<AddRackRefused>());
        expect((result as AddRackRefused).reason, contains('name'));
      }
      expect(doc.racks, hasLength(1));
    });

    test('a height outside CR-038 [1, 60] is refused with a reason', () {
      final doc = _docWithOneRack();
      for (final h in [0, -3, kMaxRackHeightU + 1, 999]) {
        final result = buildAddRackCommand(
          doc: doc,
          name: 'Too tall',
          heightU: h,
          now: _now,
          actor: 'local',
        );
        expect(result, isA<AddRackRefused>(), reason: 'heightU $h');
        expect((result as AddRackRefused).reason, contains('60U'));
      }
    });

    test('the name is trimmed, and the boundary heights are accepted', () {
      final doc = _docWithOneRack();
      for (final h in [1, kMaxRackHeightU]) {
        final result = buildAddRackCommand(
          doc: doc,
          name: '  Media Closet  ',
          heightU: h,
          now: _now,
          actor: 'local',
        );
        expect(result, isA<AddRackReady>());
        expect((result as AddRackReady).command.name, 'Media Closet');
        expect(result.command.heightU, h);
      }
    });

    test('allocates the designator and the order from the document', () {
      final doc = _docWithOneRack();
      final result =
          buildAddRackCommand(
                doc: doc,
                name: 'Second',
                heightU: 42,
                now: _now,
                actor: 'local',
              )
              as AddRackReady;
      expect(result.command.designator, 'RK-2');
      expect(result.command.order.v, 'a1');
    });
  });

  group('undo through the real DocumentController', () {
    test('run then undo then redo restores the racks map exactly', () {
      final doc = _docWithOneRack();
      final controller = DocumentController(doc);
      // The `racks` MAP, not the whole envelope: `DocEpochs.bump` advances
      // the persisted `sequence` counter on every commit, undo AND redo
      // (CR-094), so whole-document byte identity across an undo is
      // deliberately false. The `apply; revert` byte property is asserted
      // against the raw command above, which is where it belongs.
      final before = _racksJson(doc);

      final cmd =
          (buildAddRackCommand(
                    doc: doc,
                    name: 'Media Closet',
                    heightU: 42,
                    now: _now,
                    actor: 'local',
                  )
                  as AddRackReady)
              .command;
      controller.run(cmd);
      expect(doc.racks, hasLength(2));
      final afterRun = _racksJson(doc);

      controller.undoLast();
      expect(doc.racks, hasLength(1));
      expect(_racksJson(doc), before);

      controller.redoLast();
      expect(doc.racks, hasLength(2));
      expect(_racksJson(doc), afterRun);
    });

    test('the rack epoch advances on commit', () {
      final doc = _docWithOneRack();
      final controller = DocumentController(doc);
      final rackEpoch = controller.epochs.rack.value;
      final metaEpoch = controller.epochs.meta.value;

      controller.run(
        (buildAddRackCommand(
                  doc: doc,
                  name: 'Media Closet',
                  heightU: 42,
                  now: _now,
                  actor: 'local',
                )
                as AddRackReady)
            .command,
      );

      expect(controller.epochs.rack.value, greaterThan(rackEpoch));
      expect(controller.epochs.meta.value, greaterThan(metaEpoch));
    });
  });
}
