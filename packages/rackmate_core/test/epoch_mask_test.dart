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

import 'package:collection/collection.dart';
import 'package:rackmate_core/rackmate_core.dart';
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
  mutate();
  final after = _documentMap(doc);
  return {
    for (final key in before.keys)
      if (!_deepEq.equals(before[key], after[key])) key,
  };
}

/// Whether [touches] declares an epoch that plausibly explains a change
/// to top-level document map [key] — i.e. whether the command's declared
/// mask is broad enough that a real derived-data pipeline keyed off these
/// epochs would NOT miss this change. Deliberately permissive (an OR of
/// every epoch that could touch [key]) — AC-014 only requires `touches`
/// to be a superset of what changed, never the exact minimal set.
bool _epochPlausiblyCovers(EpochMask touches, String key) => switch (key) {
  'devices' => touches.has(EpochMask.structure) || touches.has(EpochMask.meta),
  'racks' => touches.has(EpochMask.rack) || touches.has(EpochMask.meta),
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
};

void _expectTouchesCoversChanges(
  Command cmd,
  Set<String> changed, {
  required Set<String> expectAtLeast,
}) {
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
      _epochPlausiblyCovers(cmd.touches, key),
      isTrue,
      reason:
          '${cmd.runtimeType}.touches (${cmd.touches.bits}) does not '
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'devices'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'racks'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'devices'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'devices'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'devices'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'racks'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'racks'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'racks'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'racks'});
    });

    test('SetEntityPropertyCommand (rack|style display field)', () {
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'racks'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(
        cmd,
        changed,
        expectAtLeast: {'devices', 'structures'},
      );
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(
        cmd,
        changed,
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'outlets'});
    });

    test('RemoveOutletCommand', () {
      final doc = _freshDoc();
      final outletId = _seedOutlet(doc);
      final cmd = RemoveOutletCommand(id: outletId);

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'outlets'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'locations'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'locations'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(
        cmd,
        changed,
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'locations'});
    });

    test('SetEntityPropertyCommand (location, nullable field set and '
        'cleared)', () {
      // BOTH DIRECTIONS, because the codec omits an absent key entirely
      // (G4, CR-114): setting a room estimate ADDS `estimatedRunLength...`
      // to the encoded node and clearing it REMOVES the key. A one-way
      // test would miss a mask that only covers the write.
      final doc = _freshDoc();
      final id = _seedLocation(doc, 'Living Room', 'LR');

      final set = SetEntityPropertyCommand<Location, Len?>(
        id: id,
        field: LocationField.estimatedRunLengthFromRack,
        from: null,
        to: Len.fromMillimetres(21000),
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );
      _expectTouchesCoversChanges(
        set,
        _changedTopLevelKeys(doc, () => set.apply(doc)),
        expectAtLeast: {'locations'},
      );

      final clear = SetEntityPropertyCommand<Location, Len?>(
        id: id,
        field: LocationField.estimatedRunLengthFromRack,
        from: Len.fromMillimetres(21000),
        to: null,
        now: DateTime.utc(2026, 1, 3),
        actor: 'tester',
      );
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'links'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'links'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'outlets'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'outlets'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'structures'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'devices'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'links'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'links'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'links'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'links'});
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

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'links'});
    });
  });
}
