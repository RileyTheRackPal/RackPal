// AC-014: "one generic test snapshots every derived output for each
// command type, applies, snapshots again, diffs, and asserts the
// declared mask covers everything that changed." No derived-data
// pipeline exists yet in this milestone (docs/03-architecture.md §6 is a
// later milestone), so this snapshots the top-level, PERSISTED document
// maps instead (via the real `JsonDocumentCodec` from the persistence
// stage) — a coverage test in spirit rather than the letter, at the
// scope M0 actually has. It still catches exactly the bug class AC-014
// exists for: a command whose declared `touches` UNDER-reports what it
// actually changed. Over-declaring is fine and expected ("when in doubt,
// over-declare" — §5.2); this test only ever asserts a superset relation,
// never exact equality.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
const _deepEq = DeepCollectionEquality();

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

RackDocument _freshDoc() => RackDocument(
  id: const Uuid('doc-epoch-mask-test'),
  appVersion: '0.1.0',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: _meta(),
);

Rack _rack(Uuid id) => Rack(
  id: id,
  name: 'Test Rack',
  designator: 'RK-1',
  heightU: 42,
  order: const FracIndex('a0'),
  meta: _meta(),
);

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.test'),
  version: 1,
  contentHash: 'sha256:test',
);

/// Every top-level key of the `"document"` envelope object, as decoded
/// JSON (not the raw private encoder — json_codec.dart's `_encodeXxx`
/// helpers are deliberately unexported; going through the public
/// `JsonDocumentCodec` and `jsonDecode` is the only route available from
/// a test in a different library, and it's the same bytes a real
/// save/reload would produce).
Map<String, Object?> _documentMap(RackDocument doc) {
  final bytes = _codec.write(doc);
  final root = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  return root['document']! as Map<String, Object?>;
}

/// Snapshots [doc], runs [mutate], snapshots again, and returns every
/// top-level `document` key whose value differs.
Set<String> _changedTopLevelKeys(RackDocument doc, void Function() mutate) {
  final before = _documentMap(doc);
  final derivedBefore = _derivedProjection(doc);
  mutate();
  final after = _documentMap(doc);
  final derivedAfter = _derivedProjection(doc);
  return {
    // THE UNION, NOT `before.keys` (#944). `underlays` is omitted from the
    // file when empty (json_codec.dart), so the first underlay a document
    // ever gets adds a key `before` does not have, and a loop over
    // `before.keys` alone could not see the change at all.
    for (final key in {...before.keys, ...after.keys})
      if (!_deepEq.equals(before[key], after[key])) key,
    // Folded in under a `derived:` prefix so every per-command test below
    // gains derived coverage without changing a line of any of them.
    for (final key in derivedBefore.keys)
      if (!_deepEq.equals(derivedBefore[key], derivedAfter[key])) key,
  };
}

// ═══════════════════════════════════════════════════════════════════
// THE DERIVED HALF (M0 clause 5, AC-014's LETTER)
// ═══════════════════════════════════════════════════════════════════
// The header above records that this file snapshots PERSISTED maps
// because no derived pipeline existed at M0, and calls itself "a
// coverage test in spirit rather than the letter". docs/12 §2.4 names
// the remedy and the three files it needs: `device_loads.dart`,
// `equipment_list.dart` and `totals.dart`. All three now exist, so the
// letter is reachable and this is it.
//
// The derived outputs are folded into the SAME changed-key set the
// persisted maps use, under a `derived:` prefix, so every one of the
// per-command tests below gains derived coverage without a line
// changing in any of them. A command whose mask does not cover a
// derived output it moved now fails, which is the bug class AC-014
// names and which the persisted-map version could only approximate.
//
// MEASURED, NOT ASSUMED: instrumented once, the derived half moves on 9
// of the 35 command cases below, across both outputs and across add,
// remove, move, rename, height and lifecycle commands. An arm that never
// fires is the trap #587 recorded, and a derived snapshot nothing moves
// would be that trap with more machinery.
//
// WHY A HAND-WRITTEN PROJECTION, AND WHAT STOPS IT ROTTING. None of
// `EquipmentRow`, `EquipmentList`, `RackRollups` or `Rollup` declares
// `==` or `toString`, so there is nothing to diff but a projection. A
// projection that silently omits a field is `VACUOUS` in exactly this
// file's sense: it would pass over a change it cannot see. So
// `_projectionCoversEveryField` reads the two source files and counts
// their `final` declarations against the numbers this projection was
// written for. Add a field and that guard fails until the projection
// learns it, which is the same trick `no_flutter_import_test.dart`
// plays with its file counter.

/// Field counts the projection below was written against, per class.
///
/// MEASURED FROM SOURCE by [_projectionCoversEveryField], never trusted.
const _projectedFieldCounts = <String, int>{
  'EquipmentRow': 14,
  'RackRollups': 11,
  'Rollup<T>': 3,
};

/// Every derived output docs/12 §2.4 names, as comparable plain data.
///
/// `device_loads.dart` is covered THROUGH `EquipmentRow.loads` rather
/// than separately: `DeviceLoads` has no whole-document builder, it is
/// resolved per device, and the equipment list resolves it for every
/// device in the document. Snapshotting it twice would not cover more.
Map<String, Object?> _derivedProjection(RackDocument doc) {
  final list = buildEquipmentList(doc);

  Object? rollup(Rollup<Object?> r) => <String, Object?>{
    'value': r.value?.toString(),
    'knownCount': r.knownCount,
    'unknownCount': r.unknownCount,
  };

  Object? loads(DeviceLoads l) => l.toString();

  final rows = <Object?>[
    for (final group in list.groups)
      for (final row in group.rows)
        <String, Object?>{
          'deviceId': row.deviceId.v,
          'designator': row.designator,
          'manufacturer': row.manufacturer,
          'model': row.model,
          'description': row.description,
          'ruIndex': row.ruIndex,
          'ruSpan': row.ruSpan,
          'rackDesignator': row.rackDesignator,
          'location': row.location,
          'mounting': row.mounting.name,
          'loads': loads(row.loads),
          'lifecycleStatus': row.lifecycleStatus.name,
          'notes': row.notes,
          // DR-130. `SetMountNoteCommand` declares `EpochMask.meta`, so
          // a projection blind to this field could not tell whether that
          // declaration is honest.
          'mountNote': row.mountNote,
        },
  ];

  final rollups = <Object?>[
    for (final rack in doc.racks.values)
      for (final face in Face.values)
        () {
          final r = computeRackRollups(
            rack: rack,
            devices: doc.devices.values,
            templates: doc.templates,
            face: face,
            landings: PortLandings.of(doc),
          );
          return <String, Object?>{
            'rack': rack.id.v,
            'face': r.face.name,
            'ruCapacity': r.ruCapacity,
            'ruUsed': r.ruUsed,
            'ruUnknownCount': r.ruUnknownCount,
            'weight': rollup(r.weight),
            'weightCapacity': r.weightCapacity?.toString(),
            'apparentVA': rollup(r.apparentVA),
            'outletsConsumed': rollup(r.outletsConsumed),
            'outletsProvided': rollup(r.outletsProvided),
            'outletsUnknownCount': r.outletsUnknownCount,
            'outletsCountedFromPorts': r.outletsCountedFromPorts,
          };
        }(),
  ];

  return <String, Object?>{
    'derived:equipmentList': rows,
    'derived:rackRollups': rollups,
  };
}

/// Reads the two derived source files and asserts the projection above
/// still sees every field. See this section's header for why.
void _projectionCoversEveryField() {
  const paths = <String, String>{
    'EquipmentRow': 'lib/src/derived/equipment_list.dart',
    'RackRollups': 'lib/src/derived/totals.dart',
    'Rollup<T>': 'lib/src/derived/totals.dart',
  };
  for (final entry in _projectedFieldCounts.entries) {
    final src = File(paths[entry.key]!).readAsStringSync();
    final start = src.indexOf('final class ${entry.key} ');
    expect(
      start,
      isNonNegative,
      reason:
          'epoch_mask_test could not find `final class ${entry.key}` in '
          '${paths[entry.key]}. The projection is keyed off that name.',
    );
    final end = src.indexOf('\n}', start);
    final body = src.substring(start, end);
    final fields = RegExp(
      r'^  final [A-Za-z_][A-Za-z0-9_<>?, ]*\s+[a-zA-Z_][a-zA-Z0-9_]*;',
      multiLine: true,
    ).allMatches(body).length;
    expect(
      fields,
      entry.value,
      reason:
          '${entry.key} now declares $fields fields, and '
          '`_derivedProjection` was written for ${entry.value}. A field '
          'the projection does not read is a change this test cannot '
          'see, which is the VACUOUS mark one level down. Extend the '
          'projection, then update `_projectedFieldCounts`.',
    );
  }
}

/// Whether [touches] declares an epoch that plausibly explains a change
/// to top-level document map [key] — i.e. whether the command's declared
/// mask is broad enough that a real derived-data pipeline keyed off these
/// epochs would NOT miss this change. Deliberately permissive (an OR of
/// every epoch that could touch [key]) — AC-014 only requires `touches`
/// to be a superset of what changed, never the exact minimal set.
bool _epochPlausiblyCovers(EpochMask touches, String key) => switch (key) {
  'devices' => touches.has(EpochMask.structure) || touches.has(EpochMask.meta),
  // `structure` JOINED THIS ARM AT #944, by the reader rule set out below:
  // the Rack view reads racks and hears `structure`. What forced it was
  // `RemovePlanUnderlayCommand` (structure | wires), which clears a rack's
  // plan pin, a field only the Plan view reads, and that view rebuilds on
  // every commit. It was a gap in this map, not in the command.
  //
  // A LIMIT THIS FUNCTION CANNOT GET PAST: it works per map, not per field.
  // The Schematic reads one rack field, `order`, to sort its layers, so a
  // command that reorders racks under `rack` alone would pass here and
  // leave the Schematic stale. No such command exists today.
  'racks' =>
    touches.has(EpochMask.rack) ||
        touches.has(EpochMask.meta) ||
        touches.has(EpochMask.structure),
  'links' || 'nets' => touches.has(EpochMask.wires),
  // M3-A's Structure family. Both maps sit under the SAME two epochs as
  // `devices`, and for the same reason: a Structure body is a device with
  // a building on the other side of it, and an outlet's editable fields
  // split into where the plate is (`structure`) and what it is called
  // (`meta`).
  'outlets' || 'structures' =>
    touches.has(EpochMask.structure) || touches.has(EpochMask.meta),
  // M3-B's location tree. THE SAME PAIR AGAIN, and the split runs the same
  // way: a node's parent is where things are (`structure`), its name and
  // code are what every schedule row and PDF callout calls the room
  // (`meta`). `estimatedRunLengthFromRack` also declares `wires` because it
  // is a cable length, which this permissive OR does not need to know
  // about — over-declaring is what AC-014 sanctions.
  'locations' =>
    touches.has(EpochMask.structure) || touches.has(EpochMask.meta),
  // Reached by exactly ONE command so far, and only because DR-021 makes a
  // location delete clear `Circuit.locationId` and `Pathway.from/to`. Both
  // are "where a thing is", so both sit under `structure`.
  'circuits' ||
  'pathways' => touches.has(EpochMask.structure) || touches.has(EpochMask.meta),
  // THE DERIVED OUTPUTS. The equipment list is a row per device carrying
  // its designator, its placement and its loads, so it moves under
  // `structure`, `meta` or `rack`. Permissive in this function's own sense:
  // AC-014 wants a superset, never the minimal set.
  'derived:equipmentList' =>
    touches.has(EpochMask.structure) ||
        touches.has(EpochMask.meta) ||
        touches.has(EpochMask.rack),
  // The rollups are per rack and per face and sum what is mounted, so they
  // move under the same three, AND UNDER `wires` SINCE DR-171: a device's
  // consumed outlets are the cords drawn to it (§11.170.4), so drawing a
  // cord on the schematic moves the outlet chip over the rack.
  'derived:rackRollups' =>
    touches.has(EpochMask.structure) ||
        touches.has(EpochMask.meta) ||
        touches.has(EpochMask.rack) ||
        touches.has(EpochMask.wires),
  // ═══════════════════════════════════════════════════════════════════
  // THE MAPS THIS TEST COULD NOT SEE UNTIL #944, AND THE RULE THEY USE
  // ═══════════════════════════════════════════════════════════════════
  // Only two screens subscribe to single epochs, and every other surface
  // rebuilds on any commit, so a mask can only be wrong where one of these
  // two reads the map. Each marks its scene dirty on every epoch it hears:
  //
  //   Rack view   structure, rack, meta, wires  (rack_canvas_screen.dart)
  //   Schematic   structure, wires, meta, sheet, style
  //
  // So THE RULE IS BY READER: a command that writes a map must declare an
  // epoch EVERY screen reading that map hears. A map both read needs one of
  // the three they share; a map one reads needs one of that screen's.
  //
  // Both read `ports` (the Schematic's pins; the Rack view's rollups and
  // findings), `templates` (the Rack view's bodies, the Schematic's net
  // labels), `settings` (colour overrides on the Schematic, rule overrides
  // in the Rack view's findings drawer) and `registries` (connector and
  // media names in labels and in findings).
  'ports' || 'templates' || 'settings' || 'registries' =>
    touches.has(EpochMask.structure) ||
        touches.has(EpochMask.wires) ||
        touches.has(EpochMask.meta),
  // The Schematic alone reads `sheets` (schematic_scene.dart).
  'sheets' =>
    touches.has(EpochMask.structure) ||
        touches.has(EpochMask.wires) ||
        touches.has(EpochMask.meta) ||
        touches.has(EpochMask.sheet) ||
        touches.has(EpochMask.style),
  // The Rack view alone reads these: `info` in its title block, and
  // `ackedFindings` through the findings drawer, which #932 found going
  // stale on an epoch the screen did not hear.
  'info' || 'ackedFindings' =>
    touches.has(EpochMask.structure) ||
        touches.has(EpochMask.rack) ||
        touches.has(EpochMask.meta) ||
        touches.has(EpochMask.wires),
  // NO EPOCH-LISTENING SCREEN READS `underlays`: the Plan view rebuilds on
  // every commit. So no mask is wrong for it today. If a Plan screen ever
  // subscribes to single epochs, this arm must name them.
  'underlays' => true,
  _ => false,
};

/// The command set only ever mutates these top-level maps; anything else
/// changing would itself be a bug (a command reaching into document state
/// it has no business touching), so this is asserted directly rather than
/// folded into the permissive per-key epoch mapping above.
const _knownMutableKeys = {
  'devices',
  'racks',
  'links',
  'nets',
  'outlets',
  'structures',
  'locations',
  'circuits',
  'pathways',
  // #944: eight top-level keys a command could write and this set did not
  // name, so no command that wrote one could be given a case here at all.
  'ports',
  'templates',
  'settings',
  'registries',
  'sheets',
  'info',
  'ackedFindings',
  'underlays',
  'derived:equipmentList',
  'derived:rackRollups',
};

void _expectTouchesCoversChanges(
  Command<RackDocument> cmd,
  Set<String> changed, {
  required Set<String> expectAtLeast,
}) {
  // `Command.touches` is nullable since M4-A, where null means "this
  // aggregate has no epoch model" — true of the Device Builder's
  // `Command<TemplateBody>`, never of a document command. Asserted rather
  // than `!`-ed, because a document command that returns null would
  // silently invalidate NOTHING and the canvas would simply not redraw.
  final touches = cmd.touches;
  expect(
    touches,
    isNotNull,
    reason:
        '${cmd.runtimeType} is a Command<RackDocument> and must declare an '
        'EpochMask; null is reserved for aggregates with no epoch model.',
  );
  expect(
    changed,
    containsAll(expectAtLeast),
    reason:
        '${cmd.runtimeType} applied but expected key(s) $expectAtLeast '
        'did not change (changed: $changed) — the test itself would be '
        'vacuous.',
  );
  expect(
    changed.difference(_knownMutableKeys),
    isEmpty,
    reason:
        '${cmd.runtimeType} changed unexpected top-level key(s) '
        '${changed.difference(_knownMutableKeys)}.',
  );
  for (final key in changed) {
    expect(
      _epochPlausiblyCovers(touches!, key),
      isTrue,
      reason:
          '${cmd.runtimeType}.touches (${touches.bits}) does not '
          'cover changed key "$key".',
    );
  }
}

/// Seeds one Structure body and one Outlet on it, and returns the
/// outlet's id.
Uuid _seedOutlet(RackDocument doc) {
  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: DateTime.utc(2026),
    actor: 'seed',
  )..apply(doc);
  final outlet = AddOutletCommand(
    structureBodyId: structure.bodyId,
    designation: 'GR-TV-1',
    order: nextOutletOrder(doc),
    now: DateTime.utc(2026),
    actor: 'seed',
  )..apply(doc);
  return outlet.id;
}

/// Seeds one root [Location] and returns its id.
Uuid _seedLocation(RackDocument doc, String name, String code) =>
    (AddLocationCommand(
      name: name,
      code: code,
      order: nextLocationOrder(doc),
      now: DateTime.utc(2026),
      actor: 'seed',
    )..apply(doc)).id;

void main() {
  group('AC-014 — declared EpochMask covers what a command actually '
      'changes', () {
    // THE GUARD THAT KEEPS THE DERIVED HALF HONEST. Runs first because a
    // projection that has fallen behind its source makes every assertion
    // below weaker without failing any of them.
    test(
      'the derived projection still reads every field it must',
      _projectionCoversEveryField,
    );

    test('AddDeviceCommand', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = AddDeviceCommand(
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'DEV-1',
        name: 'Test Device',
        placement: const RailPlacement(
          rackId: rackId,
          ruIndex: 1,
          face: Face.front,
        ),
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'devices'});
    });

    test('AddRackCommand', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = AddRackCommand(
        name: 'Media Closet',
        designator: 'RK-2',
        heightU: 42,
        order: const FracIndex('a1'),
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'racks'});
    });

    test('RemoveDeviceCommand', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      const deviceId = Uuid('dev-1');
      doc.racks[rackId] = _rack(rackId);
      doc.devices[deviceId] = DeviceInstance(
        id: deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'DEV-1',
        name: 'Test Device',
        placement: const RailPlacement(
          rackId: rackId,
          ruIndex: 1,
          face: Face.front,
        ),
        meta: _meta(),
      );
      final cmd = RemoveDeviceCommand(id: deviceId);

      _covers(doc, cmd, expectAtLeast: {'devices'});
    });

    test('MoveDeviceCommand', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      const deviceId = Uuid('dev-1');
      doc.racks[rackId] = _rack(rackId);
      doc.devices[deviceId] = DeviceInstance(
        id: deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'DEV-1',
        name: 'Test Device',
        placement: const RailPlacement(
          rackId: rackId,
          ruIndex: 1,
          face: Face.front,
        ),
        meta: _meta(),
      );
      final cmd = MoveDeviceCommand(
        id: deviceId,
        fromRuIndex: 1,
        toRuIndex: 5,
        fromFace: Face.front,
        toFace: Face.rear,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'devices'});
    });

    test('ReplacePlacementCommand', () {
      // The Staging Bin's one command (DR-205): rail to bin, and the
      // placement is the only thing it may change.
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      const deviceId = Uuid('dev-1');
      doc.racks[rackId] = _rack(rackId);
      doc.devices[deviceId] = DeviceInstance(
        id: deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'DEV-1',
        name: 'Test Device',
        placement: const RailPlacement(
          rackId: rackId,
          ruIndex: 1,
          face: Face.front,
        ),
        meta: _meta(),
      );
      final cmd = ReplacePlacementCommand(
        id: deviceId,
        to: const StagedPlacement(
          lastRackId: rackId,
          lastRuIndex: 1,
          lastFace: Face.front,
        ),
        label: LabelKey.stageDevice,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'devices'});
    });

    test('RenameEntityCommand (device)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      const deviceId = Uuid('dev-1');
      doc.racks[rackId] = _rack(rackId);
      doc.devices[deviceId] = DeviceInstance(
        id: deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'DEV-1',
        name: 'Old Name',
        placement: const RailPlacement(
          rackId: rackId,
          ruIndex: 1,
          face: Face.front,
        ),
        meta: _meta(),
      );
      final cmd = RenameEntityCommand(
        targetKind: RenameTargetKind.device,
        id: deviceId,
        from: 'Old Name',
        to: 'New Name',
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'devices'});
    });

    test('RenameEntityCommand (rack)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = RenameEntityCommand(
        targetKind: RenameTargetKind.rack,
        id: rackId,
        from: 'Test Rack',
        to: 'Renamed Rack',
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'racks'});
    });

    test('SetRackHeightCommand', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = SetRackHeightCommand(
        id: rackId,
        fromHeightU: 42,
        toHeightU: 24,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'racks'});
    });

    // One case per EpochMask branch the RackField table declares, rather
    // than one per field: twelve near-identical cases would assert the
    // same relation twelve times. The table's own per-field mask
    // assignments are asserted directly in
    // set_rack_property_command_test.dart; what THIS file exists to catch
    // is a command whose declared mask under-reports what it changed, and
    // that property is per-mask, not per-field.
    test('SetEntityPropertyCommand (rack-epoch field)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = SetEntityPropertyCommand<Rack, RackWidthClass>(
        id: rackId,
        field: RackField.widthClass,
        from: RackWidthClass.eia19,
        to: RackWidthClass.etsi,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'racks'});
    });

    test('SetEntityPropertyCommand (meta-epoch field)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = SetEntityPropertyCommand<Rack, String>(
        id: rackId,
        field: RackField.designator,
        from: 'RK-1',
        to: 'RK-9',
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'racks'});
    });

    test('SetEntityPropertyCommand (rack display field)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = SetEntityPropertyCommand<Rack, RuNumbering>(
        id: rackId,
        field: RackField.ruNumbering,
        from: RuNumbering.bottomUpFromOne,
        to: RuNumbering.topDown,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'racks'});
    });

    test('SetEntityPropertyCommand (nullable field, set and cleared)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final set = SetEntityPropertyCommand<Rack, Len?>(
        id: rackId,
        field: RackField.usableDepth,
        from: null,
        to: const Len(600000000),
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _expectTouchesCoversChanges(
        set,
        _changedTopLevelKeys(doc, () => set.apply(doc)),
        expectAtLeast: {'racks'},
      );

      // Clearing back to null must ALSO register as a change — an
      // absent-key encoding (CR-117) that silently matched the set state
      // would make this test vacuous in one direction.
      final clear = SetEntityPropertyCommand<Rack, Len?>(
        id: rackId,
        field: RackField.usableDepth,
        from: const Len(600000000),
        to: null,
        now: DateTime.utc(2026, 1, 3),
        actor: 'tester',
      );

      _expectTouchesCoversChanges(
        clear,
        _changedTopLevelKeys(doc, () => clear.apply(doc)),
        expectAtLeast: {'racks'},
      );
    });

    // ── M3-A's create/remove family (board #580) ──────────────────────
    //
    // These four shipped in `541115e` with no case here at all, which is a
    // hole in AC-014's "for every command type" rather than a decision.
    // `AddStructureCommand` is the interesting one: it is the only command
    // in the package that writes two top-level maps which are NOT a
    // link/net pair, so its declared mask has to cover both.
    test('AddStructureCommand writes BOTH devices and structures', () {
      final doc = _freshDoc();
      final cmd = AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'devices', 'structures'});
    });

    test('RemoveStructureCommand takes both, and does NOT cascade to '
        'outlets', () {
      // The no-cascade rule is deliberate (an Outlet is a fact about the
      // BUILDING and survives the panel it feeds), so `outlets` staying
      // out of the changed set is the assertion, not an omission.
      final doc = _freshDoc();
      final add = AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      AddOutletCommand(
        structureBodyId: add.bodyId,
        designation: 'GR-TV-1',
        order: nextOutletOrder(doc),
        now: DateTime.utc(2026),
        actor: 'seed',
      ).apply(doc);
      final cmd = RemoveStructureCommand(bodyId: add.bodyId);

      final changed = _covers(
        doc,
        cmd,
        expectAtLeast: {'devices', 'structures'},
      );
      expect(
        changed,
        isNot(contains('outlets')),
        reason:
            'removing a Structure body must not silently delete the wall '
            'plates it fed',
      );
    });

    test('AddOutletCommand', () {
      final doc = _freshDoc();
      final add = AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      final cmd = AddOutletCommand(
        structureBodyId: add.bodyId,
        designation: 'GR-TV-1',
        order: nextOutletOrder(doc),
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'outlets'});
    });

    test('RemoveOutletCommand', () {
      final doc = _freshDoc();
      final outletId = _seedOutlet(doc);
      final cmd = RemoveOutletCommand(id: outletId);

      _covers(doc, cmd, expectAtLeast: {'outlets'});
    });

    test('AddLocationCommand', () {
      final doc = _freshDoc();
      final cmd = AddLocationCommand(
        name: 'Living Room',
        code: 'LR',
        order: nextLocationOrder(doc),
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'locations'});
    });

    test('ReparentLocationCommand', () {
      final doc = _freshDoc();
      final house = _seedLocation(doc, 'Main House', 'MH');
      final living = _seedLocation(doc, 'Living Room', 'LR');
      final cmd =
          (buildReparentLocation(
                    doc: doc,
                    id: living,
                    newParentId: house,
                    now: DateTime.utc(2026, 1, 2),
                    actor: 'tester',
                  )
                  as ReparentLocationReady)
              .command;

      _covers(doc, cmd, expectAtLeast: {'locations'});
    });

    test('RemoveLocationCommand reaches SEVEN maps, not one', () {
      // The widest command in the package, and the reason it declares
      // `wires` as well: DR-021 clears nine carriers across seven entity
      // kinds, one of which is a `PlaceEndpoint` inside a `Link`. A mask
      // of `structure | meta` would leave the schedule showing a room that
      // is gone.
      final doc = _freshDoc();
      final room = _seedLocation(doc, 'Living Room', 'LR');
      const rackId = Uuid('rk-loc');
      doc.racks[rackId] = _rack(rackId)..locationId = room;
      final cmd = buildRemoveLocation(doc: doc, locationId: room)!;

      _covers(
        doc,
        cmd,
        expectAtLeast: {
          'locations',
          'racks',
        },
      );
    });

    test('SetEntityPropertyCommand (location, meta-epoch field)', () {
      final doc = _freshDoc();
      final id = _seedLocation(doc, 'Livng Room', 'LR');
      final cmd = SetEntityPropertyCommand<Location, String>(
        id: id,
        field: LocationField.name,
        from: 'Livng Room',
        to: 'Living Room',
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'locations'});
    });

    test('SetEntityPropertyCommand (location, nullable field set and '
        'cleared)', () {
      // BOTH DIRECTIONS, because the codec omits an absent key entirely
      // (G4, CR-114): setting a room estimate ADDS `estimatedRunLength...`
      // to the encoded node and clearing it REMOVES the key. A one-way
      // test would miss a mask that only covers the write.
      final doc = _freshDoc();
      final id = _seedLocation(doc, 'Living Room', 'LR');

      // THROUGH `SetRoomEstimateCommand` SINCE `LEN-A/5`, which is the
      // one writer of the figure and its origin marker (DR-050
      // §11.49.3). The claim is unchanged: the mask has to cover every
      // top-level key the write actually moves.
      final set = SetRoomEstimateCommand.typed(
        locationId: id,
        length: Len.fromMillimetres(21000),
      );
      _expectTouchesCoversChanges(
        set,
        _changedTopLevelKeys(doc, () => set.apply(doc)),
        expectAtLeast: {'locations'},
      );

      final clear = SetRoomEstimateCommand.cleared(locationId: id);
      _expectTouchesCoversChanges(
        clear,
        _changedTopLevelKeys(doc, () => clear.apply(doc)),
        expectAtLeast: {'locations'},
      );
    });

    test('AddHomeRunCommand writes links AND its implicit net', () {
      // `b119504`'s command, also uncovered here. The net is part of the
      // same `wires` epoch, which is what makes ONE declared mask correct
      // for two changed maps.
      final doc = _freshDoc();
      final outletId = _seedOutlet(doc);
      final cmd =
          (buildAddHomeRunCommand(
                    doc: doc,
                    outletId: outletId,
                    fieldLabel: 'GR-DATA-1',
                    designator: 'W001',
                    netName: 'N001',
                    media: const MediaTypeId('media.cat6_utp'),
                    fieldEnd: const PlaceEndpoint(description: 'Great Room'),
                    terminationField: TerminationType.keystone,
                    now: DateTime.utc(2026, 1, 2),
                    actor: 'tester',
                  )
                  as AddHomeRunReady)
              .command;

      final changed = _covers(doc, cmd, expectAtLeast: {'links'});
      expect(changed, contains('nets'));
    });

    test('SetEntityPropertyCommand (a StructureOrigin row)', () {
      // Its table is keyed by the LINK's id, so the map that changes is
      // `links` and the mask has to name `wires` — a row that declared
      // only `meta` would repaint nothing that draws cables.
      final doc = _freshDoc();
      final outletId = _seedOutlet(doc);
      final add =
          (buildAddHomeRunCommand(
                    doc: doc,
                    outletId: outletId,
                    fieldLabel: 'GR-DATA-1',
                    designator: 'W001',
                    netName: 'N001',
                    media: const MediaTypeId('media.cat6_utp'),
                    fieldEnd: const PlaceEndpoint(description: 'Great Room'),
                    terminationField: TerminationType.keystone,
                    now: DateTime.utc(2026),
                    actor: 'seed',
                  )
                  as AddHomeRunReady)
              .command
            ..apply(doc);
      final cmd =
          (buildSetStructureOriginProperty<String>(
                    doc: doc,
                    linkId: add.id,
                    field: StructureOriginField.fieldLabel,
                    to: 'GR-DATA-9',
                    now: DateTime.utc(2026, 1, 2),
                    actor: 'tester',
                  )
                  as SetStructureOriginReady<String>)
              .command;

      _covers(doc, cmd, expectAtLeast: {'links'});
    });

    // One case per EpochMask branch `OutletField`/`StructureBodyField`
    // declare, on the same reasoning as the RackField cases above: the
    // per-field mask assignments are asserted directly in
    // set_entity_property_command_test.dart, and what THIS file catches is
    // a declared mask that under-reports what the command changed.
    test('SetEntityPropertyCommand (outlet, structure-epoch field)', () {
      final doc = _freshDoc();
      final outletId = _seedOutlet(doc);
      final cmd = SetEntityPropertyCommand<Outlet, Wall?>(
        id: outletId,
        field: OutletField.wall,
        from: null,
        to: Wall.n,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'outlets'});
    });

    test('SetEntityPropertyCommand (outlet, meta-epoch field)', () {
      final doc = _freshDoc();
      final outletId = _seedOutlet(doc);
      final cmd = SetEntityPropertyCommand<Outlet, String>(
        id: outletId,
        field: OutletField.designation,
        from: 'GR-TV-1',
        to: 'GR-TV-4',
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'outlets'});
    });

    test('SetEntityPropertyCommand (outlet, nullable field set and '
        'cleared)', () {
      final doc = _freshDoc();
      final outletId = _seedOutlet(doc);
      final set = SetEntityPropertyCommand<Outlet, Len?>(
        id: outletId,
        field: OutletField.mountHeightAff,
        from: null,
        to: const Len(450000000),
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _expectTouchesCoversChanges(
        set,
        _changedTopLevelKeys(doc, () => set.apply(doc)),
        expectAtLeast: {'outlets'},
      );

      // Clearing back to unknown must ALSO register as a change — an
      // absent-key encoding (G4/CR-114) that silently matched the set
      // state would make this case vacuous in one direction.
      final clear = SetEntityPropertyCommand<Outlet, Len?>(
        id: outletId,
        field: OutletField.mountHeightAff,
        from: const Len(450000000),
        to: null,
        now: DateTime.utc(2026, 1, 3),
        actor: 'tester',
      );

      _expectTouchesCoversChanges(
        clear,
        _changedTopLevelKeys(doc, () => clear.apply(doc)),
        expectAtLeast: {'outlets'},
      );
    });

    test('SetEntityPropertyCommand (structure body)', () {
      final doc = _freshDoc();
      final add = AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      final cmd = SetEntityPropertyCommand<StructureBody, SheetEdge>(
        id: add.bodyId,
        field: StructureBodyField.sheetEdge,
        from: SheetEdge.left,
        to: SheetEdge.right,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'structures'});
    });

    test('SetEntityPropertyCommand (device lifecycle)', () {
      final doc = _freshDoc();
      final add = AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      final cmd = SetEntityPropertyCommand<DeviceInstance, LifecycleStatus>(
        id: add.deviceId,
        field: DeviceField.lifecycleStatus,
        from: LifecycleStatus.new_,
        to: LifecycleStatus.existing,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'devices'});
    });

    test('SetEntityPropertyCommand (link lifecycle)', () {
      final doc = _freshDoc();
      final add = AddLinkCommand(
        designator: 'W001',
        netName: 'N001',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      final cmd = SetEntityPropertyCommand<Link, LifecycleStatus>(
        id: add.id,
        field: LinkField.lifecycleStatus,
        from: LifecycleStatus.new_,
        to: LifecycleStatus.future,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      _covers(doc, cmd, expectAtLeast: {'links'});
    });

    test('AddLinkCommand', () {
      final doc = _freshDoc();
      final cmd = AddLinkCommand(
        designator: 'W001',
        netName: 'N001',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      final changed = _covers(doc, cmd, expectAtLeast: {'links'});
      // The implicit Net (CR-011) is part of the same wires epoch.
      expect(changed, contains('nets'));
    });

    test('RemoveLinkCommand', () {
      final doc = _freshDoc();
      final add = AddLinkCommand(
        designator: 'W001',
        netName: 'N001',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      final cmd = RemoveLinkCommand(id: add.id, netId: add.netId);

      _covers(doc, cmd, expectAtLeast: {'links'});
    });

    test('SetLinkJacketColorCommand', () {
      final doc = _freshDoc();
      final add = AddLinkCommand(
        designator: 'W001',
        netName: 'N001',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      final cmd = SetLinkJacketColorCommand(
        linkId: add.id,
        conventionId: const JacketColorId('jc.blue'),
      );

      _covers(doc, cmd, expectAtLeast: {'links'});
    });

    test('SetLinkPulledJacketColorCommand', () {
      final doc = _freshDoc();
      final add = AddLinkCommand(
        designator: 'W001',
        netName: 'N001',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      // Set the convention FIRST, so the override below is a genuine
      // exception rather than being normalised straight back to null —
      // which would make this case assert that a no-op changed 'links'.
      SetLinkJacketColorCommand(
        linkId: add.id,
        conventionId: const JacketColorId('jc.blue'),
      ).apply(doc);
      final cmd = SetLinkPulledJacketColorCommand(
        linkId: add.id,
        pulledId: const JacketColorId('jc.yellow'),
      );

      _covers(doc, cmd, expectAtLeast: {'links'});
    });
  });

  group('AC-014 over a real starter, for the fifty that had no case '
      '(#944)', () {
    test('every document command in lib/ has a case in this file', () {
      final missing = _commandsWithoutACase();
      expect(
        missing,
        isEmpty,
        reason:
            'Each concrete Command<RackDocument> needs a test here NAMED '
            'for it, so its declared EpochMask is checked against what it '
            'changes. The full-tree review (#97) found 49 without one and '
            'nothing had said so: add a case, or an entry in '
            '_exemptFromACase with the reason it cannot have one.',
      );
    });

    test('AcknowledgeFindingCommand', () {
      final doc = _house();
      _covers(doc, _ack(), expectAtLeast: {'ackedFindings'});
    });

    test('UnacknowledgeFindingCommand', () {
      final doc = _house();
      final ack = _ack()..apply(doc);
      _covers(
        doc,
        UnacknowledgeFindingCommand(id: ack.id),
        expectAtLeast: {'ackedFindings'},
      );
    });

    test('AddGangCommand', () {
      final doc = _house();
      _covers(
        doc,
        AddGangCommand(outletId: _anOutlet(doc), width: 2, height: 3),
        expectAtLeast: {'outlets'},
      );
    });

    test('RemoveGangCommand', () {
      final doc = _house();
      final outlet = _outletWithAGang(doc);
      _covers(
        doc,
        RemoveGangCommand(outletId: outlet, index: 0),
        expectAtLeast: {'outlets'},
      );
    });

    test('SetStrapSizeCommand', () {
      final doc = _house();
      final outlet = _outletWithAGang(doc);
      _covers(
        doc,
        SetStrapSizeCommand(outletId: outlet, index: 0, width: 1, height: 2),
        expectAtLeast: {'outlets'},
      );
    });

    test('SetGangPassThroughCommand', () {
      final doc = _house();
      final outlet = _outletWithAGang(doc);
      _covers(
        doc,
        SetGangPassThroughCommand(
          outletId: outlet,
          index: 0,
          style: PassThroughStyle.brush,
        ),
        expectAtLeast: {'outlets'},
      );
    });

    test('SetCellOccupantCommand', () {
      final doc = _house();
      final outlet = _outletWithAGang(doc);
      _covers(
        doc,
        SetCellOccupantCommand(
          outletId: outlet,
          gangIndex: 0,
          cellIndex: 0,
          occupant: LinkEndOccupant(doc.links.keys.first),
        ),
        expectAtLeast: {'outlets'},
      );
    });

    test('AddMediaTypeCommand', () {
      final doc = _house();
      _covers(
        doc,
        AddMediaTypeCommand(id: _mediaA, displayName: 'Test A'),
        expectAtLeast: {'registries'},
      );
    });

    test('EditMediaTypeCommand', () {
      final doc = _house();
      AddMediaTypeCommand(id: _mediaA, displayName: 'Test A').apply(doc);
      final was = doc.registries.mediaTypes[_mediaA]!;
      _covers(
        doc,
        EditMediaTypeCommand(
          from: was,
          to: MediaTypeDef(
            id: _mediaA,
            displayName: 'Test A, renamed',
            shortTag: was.shortTag,
            aliases: was.aliases,
          ),
        ),
        expectAtLeast: {'registries'},
      );
    });

    test('MergeMediaTypesCommand', () {
      final doc = _house();
      AddMediaTypeCommand(id: _mediaA, displayName: 'Test A').apply(doc);
      AddMediaTypeCommand(id: _mediaB, displayName: 'Test B').apply(doc);
      _covers(
        doc,
        MergeMediaTypesCommand(winner: _mediaA, loser: _mediaB),
        expectAtLeast: {'registries'},
      );
    });

    test('CloneSignalFamilyCommand', () {
      // SFE-B1 (`#825`). Built through the one builder that makes it, on
      // a dash and weight still free for a control family, so the case
      // exercises the command a person would actually get.
      final doc = _house();
      final free = pal1Headroom(
        palette: pal1EntriesOf(doc.registries),
        domain: doc.registries.signalDomains[const SignalDomainId('ctl')]!,
        vocabulary: pal1ClassVocabulary(pal1EntriesOf(buildSeedRegistries())),
      ).free.first;
      final built = buildCloneSignalFamily(
        doc,
        parent: const SignalFamilyId('ctl.cresnet'),
        displayName: 'Epoch mask test',
        shortTag: 'EMT',
        dashPermille: free.dashPermille,
        weightPermille: free.weightPermille,
      );
      _covers(
        doc,
        (built as CloneSignalFamilyReady).command,
        expectAtLeast: {'registries'},
      );
    });

    test('AddArrivedFamiliesCommand', () {
      // SFE-C6 (`#1034`). A family a library device brought, under an id
      // the house document does not hold.
      final doc = _house();
      final parent =
          doc.registries.signalFamilies[const SignalFamilyId(
            'ctl.cresnet',
          )]!;
      _covers(
        doc,
        AddArrivedFamiliesCommand(
          families: [
            SignalFamilyDef(
              id: const SignalFamilyId('ctl.epoch_arrival'),
              displayName: 'Epoch arrival',
              domain: parent.domain,
              defaultConnector: parent.defaultConnector,
              defaultDirection: parent.defaultDirection,
              defaultTopology: parent.defaultTopology,
              clonedFrom: parent.id,
            ),
          ],
        ),
        expectAtLeast: {'registries'},
      );
    });

    test('SetCloneLineCommand', () {
      // SFE-C7 (`#1035`). A clone made through the real builder, then
      // given another free line through the real one.
      final doc = _house();
      final menu = cloneHeadroom(doc, const SignalDomainId('ctl'))!;
      final first = menu.free.first;
      final clone =
          (buildCloneSignalFamily(
                    doc,
                    parent: const SignalFamilyId('ctl.cresnet'),
                    displayName: 'Epoch line test',
                    shortTag: 'ELT',
                    dashPermille: first.dashPermille,
                    weightPermille: first.weightPermille,
                  )
                  as CloneSignalFamilyReady)
              .command
            ..apply(doc);
      final next = cloneHeadroom(
        doc,
        const SignalDomainId('ctl'),
        changing: clone.family.id,
      )!.free.firstWhere((o) => o.weightPermille != first.weightPermille);
      final built = buildChangeCloneLine(
        doc,
        family: clone.family.id,
        dashPermille: next.dashPermille,
        weightPermille: next.weightPermille,
      );
      _covers(
        doc,
        (built as ChangeCloneLineReady).command,
        expectAtLeast: {'registries'},
      );
    });

    test('SetConnectorAliasesCommand', () {
      final doc = _house();
      final id = doc.registries.connectorTypes.keys.first;
      final was = doc.registries.connectorTypes[id]!.aliases;
      _covers(
        doc,
        SetConnectorAliasesCommand(
          id: id,
          from: was,
          to: [...was, 'epoch-mask-test'],
        ),
        expectAtLeast: {'registries'},
      );
    });

    test('AddPathwayCommand', () {
      final doc = _house();
      _covers(
        doc,
        AddPathwayCommand(
          name: 'P-TEST',
          order: const FracIndex('z0'),
          now: _now,
          actor: 'test',
        ),
        expectAtLeast: {'pathways'},
      );
    });

    test('RemovePathwayCommand', () {
      final doc = _house();
      // The pathway a cable runs through, so the command's cascade onto
      // `links` is exercised and not only its own map.
      final used = doc.links.values
          .map((l) => l.pathwayId)
          .firstWhere((p) => p != null, orElse: () => fail('no routed link'))!;
      _covers(
        doc,
        RemovePathwayCommand(id: used, now: _now),
        expectAtLeast: {'pathways', 'links'},
      );
    });

    test('AddPlanUnderlayCommand', () {
      final doc = _house();
      _covers(
        doc,
        AddPlanUnderlayCommand(underlay: _underlay()),
        expectAtLeast: {'underlays'},
      );
    });

    test('RemovePlanUnderlayCommand', () {
      final doc = _planned();
      // A rack pinned to it, so the removal's cascade clears a pin too.
      SetPlanPinCommand(
        carrier: PinCarrier.rack,
        entityId: doc.racks.keys.first,
        pin: const PlanPin(underlayId: _planId, at: PxPt(40, 50)),
      ).apply(doc);
      _covers(
        doc,
        RemovePlanUnderlayCommand(underlayId: _planId),
        expectAtLeast: {'underlays', 'racks'},
      );
    });

    test('ReorderPlanUnderlayCommand', () {
      final doc = _planned();
      _covers(
        doc,
        ReorderPlanUnderlayCommand(
          underlayId: _planId,
          order: const FracIndex('a5'),
        ),
        expectAtLeast: {'underlays'},
      );
    });

    test('RotatePlanCommand', () {
      final doc = _planned();
      _covers(
        doc,
        RotatePlanCommand(underlayId: _planId, clockwise: true),
        expectAtLeast: {'underlays'},
      );
    });

    test('SetPlanScaleCommand', () {
      final doc = _planned();
      _covers(
        doc,
        SetPlanScaleCommand(
          underlayId: _planId,
          scale: const PlanScale(
            a: PxPt(100, 100),
            b: PxPt(200, 100),
            distance: Len(36 * Len.nmPerInch),
          ),
        ),
        expectAtLeast: {'underlays'},
      );
    });

    test('SetPlanUnderlayDetailsCommand', () {
      final doc = _planned();
      _covers(
        doc,
        SetPlanUnderlayDetailsCommand(
          underlayId: _planId,
          name: 'Level 2',
          locationId: doc.locations.keys.first,
        ),
        expectAtLeast: {'underlays'},
      );
    });

    test('SetPlanPinCommand', () {
      final doc = _planned();
      _covers(
        doc,
        SetPlanPinCommand(
          carrier: PinCarrier.outlet,
          entityId: _anOutlet(doc),
          pin: const PlanPin(underlayId: _planId, at: PxPt(40, 50)),
        ),
        expectAtLeast: {'outlets'},
      );
    });

    test('ClearPlanPinCommand', () {
      final doc = _planned();
      final outlet = _anOutlet(doc);
      SetPlanPinCommand(
        carrier: PinCarrier.outlet,
        entityId: outlet,
        pin: const PlanPin(underlayId: _planId, at: PxPt(40, 50)),
      ).apply(doc);
      _covers(
        doc,
        ClearPlanPinCommand(carrier: PinCarrier.outlet, entityId: outlet),
        expectAtLeast: {'outlets'},
      );
    });

    test('SetRoomOutlineCommand', () {
      final doc = _planned();
      _covers(
        doc,
        SetRoomOutlineCommand(
          locationId: doc.locations.keys.first,
          outline: _outline(),
        ),
        expectAtLeast: {'locations'},
      );
    });

    test('ClearRoomOutlineCommand', () {
      final doc = _planned();
      final room = doc.locations.keys.first;
      SetRoomOutlineCommand(locationId: room, outline: _outline()).apply(doc);
      _covers(
        doc,
        ClearRoomOutlineCommand(locationId: room),
        expectAtLeast: {'locations'},
      );
    });

    test('AddZeroUChannelCommand', () {
      final doc = _house();
      final built = planAddZeroUChannel(
        doc: doc,
        rackId: doc.racks.keys.first,
        id: 'ch.epoch-test',
        side: ZeroUChannelSide.rearRight,
        startU: 1,
        endU: 4,
      );
      _covers(doc, _zeroU(built), expectAtLeast: {'racks'});
    });

    test('RemoveZeroUChannelCommand', () {
      final doc = _house();
      final rackId = doc.racks.keys.first;
      _zeroU(
        planAddZeroUChannel(
          doc: doc,
          rackId: rackId,
          id: 'ch.epoch-test',
          side: ZeroUChannelSide.rearRight,
          startU: 1,
          endU: 4,
        ),
      ).apply(doc);
      final built = planRemoveZeroUChannel(
        doc: doc,
        rackId: rackId,
        id: 'ch.epoch-test',
      );
      _covers(doc, _zeroU(built), expectAtLeast: {'racks'});
    });

    test('SetZeroUPositionCommand', () {
      final doc = _house();
      final (id, _) = _aZeroUDevice(doc);
      // The starter's PDU runs the channel's whole length, so it has no
      // room to slide until it is shortened, by the product's command.
      _zeroU(
        planSetZeroUSpan(
          doc: doc,
          id: id,
          span: const Len(6 * Len.nmPerInch),
          now: _now,
          actor: 'seed',
        ),
      ).apply(doc);
      final placement = doc.devices[id]!.placement as ZeroUPlacement;
      final built = planSetZeroUPosition(
        doc: doc,
        id: id,
        channelId: placement.channelId,
        offsetFromChannelStart:
            placement.offsetFromChannelStart + const Len(Len.nmPerInch),
        now: _now,
        actor: 'test',
      );
      _covers(doc, _zeroU(built), expectAtLeast: {'devices'});
    });

    test('SetZeroUSpanCommand', () {
      final doc = _house();
      final (id, _) = _aZeroUDevice(doc);
      final built = planSetZeroUSpan(
        doc: doc,
        id: id,
        span: const Len(6 * Len.nmPerInch),
        now: _now,
        actor: 'test',
      );
      _covers(doc, _zeroU(built), expectAtLeast: {'devices'});
    });

    test('SetDeviceWidthCommand', () {
      final doc = _house();
      final id = _aRailDevice(doc);
      final built = planSetDeviceWidth(
        doc: doc,
        id: id,
        startTwelfth: 0,
        spanTwelfths: 6,
        now: _now,
        actor: 'test',
      );
      final cmd = switch (built) {
        WidthChangeReady(:final command) => command,
        WidthChangeRefused() => fail('half width refused: $built'),
      };
      _covers(doc, cmd, expectAtLeast: {'devices'});
    });

    test('SetPlacementLockedCommand', () {
      final doc = _house();
      _covers(
        doc,
        SetPlacementLockedCommand(deviceIds: [_aRailDevice(doc)], locked: true),
        expectAtLeast: {'devices'},
      );
    });

    test('SaveTemplateToProjectCommand', () {
      final doc = _house();
      _covers(doc, _saveTemplate(doc), expectAtLeast: {'templates'});
    });

    test('RemoveTemplateCommand', () {
      final doc = _house();
      _saveTemplate(doc).apply(doc);
      _covers(
        doc,
        RemoveTemplateCommand(templateId: _savedTemplate),
        expectAtLeast: {'templates'},
      );
    });

    test('ForkTemplateFromDeviceCommand', () {
      final doc = _house();
      final built = buildForkTemplateFromDevice(
        doc: doc,
        deviceId: _aRailDevice(doc),
        newTemplateId: const TemplateId('tpl.epoch-fork'),
        now: _now,
        actor: 'test',
      );
      final cmd = switch (built) {
        ForkTemplateReady(:final command) => command,
        _ => fail('fork refused: $built'),
      };
      _covers(doc, cmd, expectAtLeast: {'templates', 'devices'});
    });

    test('SetProjectSettingCommand', () {
      final doc = _house();
      final was = doc.settings.defaultRackHeightU;
      _covers(
        doc,
        SetProjectSettingCommand<int>(
          field: ProjectSettingFields.defaultRackHeightU,
          from: was,
          to: was + 1,
        ),
        expectAtLeast: {'settings'},
      );
    });

    test('SetProjectInfoCommand', () {
      final doc = _house();
      _covers(
        doc,
        SetProjectInfoCommand.to(
          doc.info,
          ProjectInfoFields.clientName,
          'Sample Client, revised',
        ),
        expectAtLeast: {'info'},
      );
    });

    test('SetLegendNotesCommand', () {
      final doc = _house();
      _covers(
        doc,
        SetLegendNotesCommand.to(
          doc.info,
          abbreviations: const [LegendAbbreviation('AFF', 'above floor')],
          notes: const ['Verify in field.'],
        ),
        expectAtLeast: {'info'},
      );
    });

    test('SetProjectLogoCommand', () {
      final doc = _house();
      _covers(
        doc,
        SetProjectLogoCommand.to(
          doc.info,
          const ProjectLogo(
            imageMember: '${kLogoMemberDir}firm.png',
            format: PlanImageFormat.png,
            pixelWidth: 834,
            pixelHeight: 375,
            contentHash: 'sha256:firm',
          ),
        ),
        expectAtLeast: {'info'},
      );
    });

    test('SetFamilyColorOverrideCommand', () {
      final doc = _house();
      _covers(
        doc,
        const SetFamilyColorOverrideCommand(
          family: SignalFamilyId('video.hdmi.2_1'),
          from: null,
          to: Rgb(255, 0, 0),
        ),
        expectAtLeast: {'settings'},
      );
    });

    test('SetRuleOverrideCommand', () {
      final doc = _house();
      _covers(
        doc,
        SetRuleOverrideCommand(
          ruleId: 'PWR-001',
          from: doc.settings.ruleOverrides['PWR-001'],
          to: RuleOverride(
            severity: Severity.error,
            reason: 'Epoch-mask case.',
            by: 'test',
            at: _now,
          ),
        ),
        expectAtLeast: {'settings'},
      );
    });

    test('SetLinkClassCommand', () {
      final doc = _house();
      _covers(
        doc,
        SetLinkClassCommand(
          linkId: doc.links.keys.first,
          linkClass: LinkClass.jumper,
        ),
        expectAtLeast: {'links'},
      );
    });

    test('ClearLinkClassOverrideCommand', () {
      final doc = _house();
      final link = doc.links.keys.first;
      SetLinkClassCommand(linkId: link, linkClass: LinkClass.jumper).apply(doc);
      _covers(
        doc,
        ClearLinkClassOverrideCommand(linkId: link),
        expectAtLeast: {'links'},
      );
    });

    test('SetRackLabelCommand', () {
      final doc = _house();
      final built = buildSetRackLabel(
        doc: doc,
        linkId: _aHomeRun(doc, landed: true).id,
        to: 'EPOCH-1',
        now: _now,
        actor: 'test',
      );
      final cmd = switch (built) {
        SetRackLabelReady(:final command) => command,
        _ => fail('rack label refused: $built'),
      };
      _covers(doc, cmd, expectAtLeast: {'links'});
    });

    test('SetSignalFamilyCommand', () {
      final doc = _house();
      final link = doc.links.values.first;
      _covers(
        doc,
        SetSignalFamilyCommand(
          linkId: link.id,
          family: const SignalFamilyId('audio.line_unbal'),
          now: _now,
          actor: 'test',
        ),
        expectAtLeast: {'links'},
      );
    });

    test('SplitConductorCommand', () {
      final doc = _house();
      final cable = doc.links.values.firstWhere(
        (l) => l.conductors.length > 1,
        orElse: () => fail('whole_house has no multi-conductor cable'),
      );
      _covers(
        doc,
        SplitConductorCommand(linkId: cable.id, index: 1),
        expectAtLeast: {'links'},
      );
    });

    test('DeclareInlineAdapterCommand', () {
      final doc = _house();
      _covers(
        doc,
        DeclareInlineAdapterCommand(
          linkId: doc.links.keys.first,
          fromConnector: const ConnectorTypeId('conn.xlr3'),
          toConnector: const ConnectorTypeId('conn.rca'),
          satisfiesRuleIds: const ['CON-001'],
        ),
        expectAtLeast: {'links'},
      );
    });

    // DR-235 (`#1001`): the cable bar's two adapter edits. Each needs an
    // adapter on the cable to act on, so the fixture declares one first.
    test('SetInlineAdapterModelCommand', () {
      final doc = _house();
      doc.links.values.first.inlineAdapters.add(
        InlineAdapter(
          fromConnector: const ConnectorTypeId('conn.xlr3'),
          toConnector: const ConnectorTypeId('conn.rca'),
        ),
      );
      _covers(
        doc,
        SetInlineAdapterModelCommand(
          linkId: doc.links.keys.first,
          index: 0,
          model: 'Hosa XLR3F-RCA',
        ),
        expectAtLeast: {'links'},
      );
    });

    test('RemoveInlineAdapterCommand', () {
      final doc = _house();
      doc.links.values.first.inlineAdapters.add(
        InlineAdapter(
          fromConnector: const ConnectorTypeId('conn.xlr3'),
          toConnector: const ConnectorTypeId('conn.rca'),
        ),
      );
      _covers(
        doc,
        RemoveInlineAdapterCommand(linkId: doc.links.keys.first, index: 0),
        expectAtLeast: {'links'},
      );
    });

    // DR-236 (BRK-A/2): a conductor appended to an existing cable. Built
    // directly rather than planned, because the house starter holds no
    // second set to plan from; the mask is about what it writes.
    test('AppendSetToLinkCommand', () {
      final doc = _house();
      final link = doc.links.values.first;
      _covers(
        doc,
        AppendSetToLinkCommand(
          linkId: link.id,
          conductors: [
            Conductor(
              from: link.conductors.first.from,
              to: const OpenEndpoint('continued'),
            ),
          ],
          materialisations: const [],
        ),
        expectAtLeast: {'links'},
      );
    });

    test('BindEndpointCommand', () {
      final doc = _house();
      final link = _aHomeRun(doc, landed: false);
      final cmd = _firstReady(
        doc,
        _aPanel(doc),
        (target) => switch (buildBindEndpointCommand(
          doc: doc,
          linkId: link.id,
          port: _pin(doc, target),
          rackLabel: 'EPOCH-1',
          usedRackLabels: const {},
          now: _now,
          actor: 'test',
        )) {
          BindEndpointReady(:final command) => command,
          _ => null,
        },
      );
      _covers(doc, cmd, expectAtLeast: {'links'});
    });

    test('MoveEndpointCommand', () {
      final doc = _house();
      final link = _aHomeRun(doc, landed: true);
      final cmd = _firstReady(
        doc,
        _aPanel(doc),
        (target) => switch (buildMoveEndpointCommand(
          doc: doc,
          linkId: link.id,
          port: _pin(doc, target),
          rackLabel: 'EPOCH-1',
          usedRackLabels: const {},
          now: _now,
          actor: 'test',
        )) {
          MoveEndpointReady(:final command) => command,
          _ => null,
        },
      );
      _covers(doc, cmd, expectAtLeast: {'links'});
    });

    test('UnlandEndpointCommand', () {
      final doc = _house();
      final built = buildUnlandEndpointCommand(
        doc: doc,
        linkId: _aHomeRun(doc, landed: true).id,
        now: _now,
        actor: 'test',
      );
      final cmd = switch (built) {
        UnlandEndpointReady(:final command) => command,
        _ => fail('unland refused: $built'),
      };
      _covers(doc, cmd, expectAtLeast: {'links'});
    });

    test('ConnectPortsCommand', () {
      final doc = _house();
      _covers(doc, _anyConnect(doc), expectAtLeast: {'links'});
    });

    test('AtomicConnectCommand', () {
      final doc = _house();
      _covers(doc, _anyAtomicConnect(doc), expectAtLeast: {'links'});
    });

    test('SetPortFactCommand', () {
      final doc = _house();
      final device = _aRailDevice(doc);
      final key = _bodyOf(doc, device).ports.first.key;
      _covers(
        doc,
        SetPortFactCommand(
          deviceId: device,
          portKey: key,
          field: PortFactField.userLabel,
          value: 'Epoch label',
          designatorIfMaterialised: 'J99',
          now: _now,
          actor: 'test',
        ),
        expectAtLeast: {'ports'},
      );
    });

    test('StoreSymbolPositionsCommand', () {
      final doc = _house();
      _covers(
        doc,
        StoreSymbolPositionsCommand(
          positions: {doc.devices.keys.first: const Pt(10, 20)},
          now: _now,
          actor: 'test',
        ),
        expectAtLeast: {'sheets'},
      );
    });

    test('SetSymbolPinnedCommand', () {
      final doc = _house();
      _covers(
        doc,
        SetSymbolPinnedCommand(
          positions: {doc.devices.keys.first: const Pt(96, 40)},
          pinned: true,
          now: _now,
          actor: 'test',
        ),
        expectAtLeast: {'sheets'},
      );
    });

    test('SetMountNoteCommand', () {
      final doc = _house();
      // DR-130: the note belongs to an OFF-RACK placement.
      final device = doc.devices.values.firstWhere(
        (d) => d.placement is OffRackPlacement,
        orElse: () => fail('whole_house has no off-rack device'),
      );
      _covers(
        doc,
        SetMountNoteCommand(
          id: device.id,
          from: (device.placement as OffRackPlacement).mountNote,
          to: 'Rear rails only.',
          now: _now,
          actor: 'test',
        ),
        expectAtLeast: {'devices', 'derived:equipmentList'},
      );
    });

    test('SetRoomEstimateCommand', () {
      final doc = _house();
      _covers(
        doc,
        SetRoomEstimateCommand.typed(
          locationId: doc.locations.keys.first,
          length: const Len(40 * 12 * Len.nmPerInch),
        ),
        expectAtLeast: {'locations'},
      );
    });

    test('TidySheetCommand', () {
      final doc = _house();
      StoreSymbolPositionsCommand(
        positions: {doc.devices.keys.first: const Pt(10, 20)},
        now: _now,
        actor: 'test',
      ).apply(doc);
      _covers(doc, TidySheetCommand(), expectAtLeast: {'sheets'});
    });
  });
}

// ═══════════════════════════════════════════════════════════════════
// #944's FIXTURE AND CENSUS
// ═══════════════════════════════════════════════════════════════════
// The fifty run over `whole_house.rppj`, the richest starter: home runs
// both landed and open, four-conductor cables, zero-U channels, pathways,
// a Structure body with outlets. A command checked against a real project
// is checked against the state the product puts it in, which a two-device
// fixture per case would only approximate. What the starter lacks (gangs,
// an underlay, a sheet, media types) each case seeds with the product's
// own command first.

final Uint8List _houseBytes = File(
  '../../apps/rackpal/assets/starters/whole_house.rppj',
).readAsBytesSync();

/// A fresh decode per case, since every case mutates what it is given.
RackDocument _house() => switch (_codec.read(_houseBytes)) {
  Ok(:final value) => value,
  final other => fail('whole_house.rppj did not decode: $other'),
};

final _now = DateTime.utc(2026, 9, 24);

/// AC-014's mask check, AND CR-117's `apply; revert; apply` at the same
/// realistic state (#947).
///
/// THE SECOND HALF IS HERE BECAUSE THE FUZZ DOES NOT REACH THESE. Measured
/// on 2026-09-25, `command_roundtrip_test.dart`'s thousand sequences
/// generate 27 of the 71 document command classes; every Plan view
/// command, the gangs, the locations, the media types and the endpoint
/// moves never appear in one. One state per command is far less than a
/// random walk, and far more than nothing, which is what they had: each
/// command's revert was proven only by whatever its own unit test chose.
/// Returns the changed keys, for a case that asserts more about them.
Set<String> _covers(
  RackDocument doc,
  Command<RackDocument> cmd, {
  required Set<String> expectAtLeast,
}) {
  final before = _codec.write(doc);
  final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));
  _expectTouchesCoversChanges(cmd, changed, expectAtLeast: expectAtLeast);

  final applied = _codec.write(doc);
  cmd.revert(doc);
  expect(
    utf8.decode(_codec.write(doc)),
    utf8.decode(before),
    reason:
        '${cmd.runtimeType}: apply;revert did not restore the saved '
        'bytes (CR-117)',
  );
  cmd.apply(doc);
  expect(
    utf8.decode(_codec.write(doc)),
    utf8.decode(applied),
    reason:
        '${cmd.runtimeType}: apply;revert;apply did not land where the '
        'first apply did, so redo is not the edit the user made',
  );
  return changed;
}

AcknowledgeFindingCommand _ack() => AcknowledgeFindingCommand(
  ruleId: 'LEN-001',
  targetFingerprint: 'LEN-001:0123456789abcdef',
  reason: 'Existing condition.',
  demotedTo: Severity.off,
  now: _now,
  actor: 'test',
);

Uuid _anOutlet(RackDocument doc) => doc.outlets.keys.first;

/// An outlet given one 2x3 strap by the product's own command.
Uuid _outletWithAGang(RackDocument doc) {
  final outlet = _anOutlet(doc);
  AddGangCommand(outletId: outlet, width: 2, height: 3).apply(doc);
  return outlet;
}

const _mediaA = MediaTypeId('media.epoch_a');
const _mediaB = MediaTypeId('media.epoch_b');

const _planId = Uuid('0190e3c1-1111-7000-8000-00000000e944');

PlanUnderlay _underlay() => PlanUnderlay(
  id: _planId,
  name: 'Level 1',
  imageMember: 'underlays/$_planId.png',
  format: PlanImageFormat.png,
  pixelWidth: 4000,
  pixelHeight: 3000,
  contentHash: 'sha256:abcdef',
  order: const FracIndex('a0'),
  meta: _meta(),
);

RoomOutline _outline() => RoomOutline(
  underlayId: _planId,
  vertices: const [
    PxPt(100, 100),
    PxPt(400, 100),
    PxPt(400, 300),
    PxPt(100, 300),
  ],
);

/// The starter with one underlay, added by the product's command.
RackDocument _planned() {
  final doc = _house();
  AddPlanUnderlayCommand(underlay: _underlay()).apply(doc);
  return doc;
}

Command<RackDocument> _zeroU(ZeroUResult built) => switch (built) {
  ZeroUReady(:final command) => command,
  ZeroURefused(:final reason) => fail('zero-U planner refused: $reason'),
};

(Uuid, ZeroUPlacement) _aZeroUDevice(RackDocument doc) {
  for (final d in doc.devices.values) {
    final p = d.placement;
    if (p is ZeroUPlacement) return (d.id, p);
  }
  fail('whole_house has no zero-U device');
}

Uuid _aRailDevice(RackDocument doc) => doc.devices.values
    .firstWhere(
      (d) => d.placement is RailPlacement,
      orElse: () => fail('whole_house has no rail device'),
    )
    .id;

TemplateBody _bodyOf(RackDocument doc, Uuid deviceId) =>
    doc.templates[templateKeyFor(doc.devices[deviceId]!.templateRef)]!.body;

const _savedTemplate = TemplateId('tpl.epoch-save');

SaveTemplateToProjectCommand _saveTemplate(RackDocument doc) {
  final version = nextTemplateVersion(doc, _savedTemplate);
  return SaveTemplateToProjectCommand(
    templateId: _savedTemplate,
    version: version,
    contentHash: 'unhashed:${_savedTemplate.v}@$version',
    body: TemplateBody(
      manufacturer: 'Generic',
      model: '',
      displayName: 'Epoch',
    )..frontU = 1,
    capturedAt: _now,
  );
}

/// A home run whose rack end is a port ([landed]) or open.
Link _aHomeRun(RackDocument doc, {required bool landed}) =>
    doc.links.values.firstWhere(
      (l) =>
          l.structureOrigin != null &&
          l.conductors.length == 1 &&
          (landed
              ? l.conductors.single.to is PortEndpoint
              : l.conductors.single.to is OpenEndpoint),
      orElse: () => fail('whole_house has no ${landed ? '' : 'un'}landed run'),
    );

/// The patch panel the starter's home runs land on.
Uuid _aPanel(RackDocument doc) => doc.ports.values.first.deviceId;

PortMaterialisation _pin(RackDocument doc, ConnectTarget target) =>
    PortMaterialisation.of(
      target,
      designator: allocatePortDesignatorFor(doc, target),
    );

/// The first of [deviceId]'s ports for which [build] returns a command.
C _firstReady<C>(
  RackDocument doc,
  Uuid deviceId,
  C? Function(ConnectTarget target) build,
) {
  for (final def in _bodyOf(doc, deviceId).ports) {
    final target = resolveConnectTarget(
      doc,
      deviceId: deviceId,
      portKey: def.key.v,
    );
    if (target == null) continue;
    final built = build(target);
    if (built != null) return built;
  }
  fail('no port on ${doc.devices[deviceId]!.designator} gave a command');
}

/// The first pair of free ports anywhere in the starter the connect
/// gesture accepts, found the way a person would: by trying.
ConnectPortsCommand _anyConnect(RackDocument doc) {
  final targets = [
    for (final d in doc.devices.values)
      if (doc.templates[templateKeyFor(d.templateRef)] case final snap?)
        for (final def in snap.body.ports)
          ?resolveConnectTarget(doc, deviceId: d.id, portKey: def.key.v),
  ];
  for (final from in targets) {
    for (final to in targets) {
      if (identical(from, to)) continue;
      final built = buildConnectPortsCommand(
        doc: doc,
        from: from,
        to: to,
        media: const MediaTypeId('media.cat6'),
        now: _now,
        actor: 'test',
      );
      if (built is ConnectPortsReady) return built.command;
    }
  }
  fail('no two ports in whole_house connect');
}

/// The first pair of atomic port sets the gesture accepts.
AtomicConnectCommand _anyAtomicConnect(RackDocument doc) {
  final sets = [
    for (final d in doc.devices.values)
      if (doc.templates[templateKeyFor(d.templateRef)] case final snap?)
        for (final set in snap.body.portSets)
          if (set.atomicConnect) (d.id, set.key),
  ];
  for (final (fromId, fromKey) in sets) {
    for (final (toId, toKey) in sets) {
      if (fromId == toId) continue;
      final plan = planAtomicConnect(
        doc,
        fromDeviceId: fromId,
        fromSetKey: fromKey,
        toDeviceId: toId,
        toSetKey: toKey,
      );
      if (plan is AtomicConnectReady) {
        return buildAtomicConnectCommand(
          doc: doc,
          plan: plan.plan,
          signalFamily: const SignalFamilyId('audio.line_unbal'),
          media: const MediaTypeId('media.cat6'),
          now: _now,
          actor: 'test',
        );
      }
    }
  }
  fail('no two atomic port sets in whole_house connect');
}

/// Commands that cannot have a case here, each with the reason. Empty,
/// and a new entry is a claim the next reader should be able to check.
const _exemptFromACase = <String, String>{};

/// Every concrete `Command<RackDocument>` in `lib/` with no `test(` in
/// this file named for it. Walks `extends`/`implements` through
/// intermediate classes, so a command reached through an abstract base
/// is still found.
List<String> _commandsWithoutACase() {
  final classDecl = RegExp(
    r'^((?:abstract |final |base |sealed |interface )*)class (\w+)'
    r'(?:<[^{]*?>)?\s+(?:extends|implements|with)\s+([^{]+)\{',
    multiLine: true,
  );
  final decls = <String, (String, String)>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    for (final m in classDecl.allMatches(f.readAsStringSync())) {
      decls[m.group(2)!] = (m.group(1)!, m.group(3)!);
    }
  }
  bool isDocCommand(String name, Set<String> seen) {
    final decl = decls[name];
    if (decl == null || !seen.add(name)) return false;
    if (decl.$2.contains('Command<RackDocument>')) return true;
    return RegExp(
      r'\b([A-Z]\w*)',
    ).allMatches(decl.$2).any((m) => isDocCommand(m.group(1)!, seen));
  }

  final self = File('test/epoch_mask_test.dart').readAsStringSync();
  return [
    for (final MapEntry(key: name, value: (mods, _)) in decls.entries)
      if (!mods.contains('abstract') &&
          !mods.contains('sealed') &&
          isDocCommand(name, {}) &&
          !_exemptFromACase.containsKey(name) &&
          !RegExp("test\\(\\s*'$name\\b").hasMatch(self))
        name,
  ]..sort();
}
