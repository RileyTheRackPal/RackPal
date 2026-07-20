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
  _ => false,
};

/// The M0 command set only ever mutates these four top-level maps
/// (devices/racks/links/nets); anything else changing would itself be a
/// bug (a command reaching into document state it has no business
/// touching), so this is asserted directly rather than folded into the
/// permissive per-key epoch mapping above.
const _knownMutableKeys = {'devices', 'racks', 'links', 'nets'};

void _expectTouchesCoversChanges(
  Command cmd,
  Set<String> changed, {
  required Set<String> expectAtLeast,
}) {
  expect(
    changed,
    containsAll(expectAtLeast),
    reason: '${cmd.runtimeType} applied but expected key(s) $expectAtLeast '
        'did not change (changed: $changed) — the test itself would be '
        'vacuous.',
  );
  expect(
    changed.difference(_knownMutableKeys),
    isEmpty,
    reason: '${cmd.runtimeType} changed unexpected top-level key(s) '
        '${changed.difference(_knownMutableKeys)}.',
  );
  for (final key in changed) {
    expect(
      _epochPlausiblyCovers(cmd.touches, key),
      isTrue,
      reason: '${cmd.runtimeType}.touches (${cmd.touches.bits}) does not '
          'cover changed key "$key".',
    );
  }
}

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
    test('SetRackPropertyCommand (rack-epoch field)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = SetRackPropertyCommand<RackWidthClass>(
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

    test('SetRackPropertyCommand (meta-epoch field)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = SetRackPropertyCommand<String>(
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

    test('SetRackPropertyCommand (rack|style display field)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final cmd = SetRackPropertyCommand<RuNumbering>(
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

    test('SetRackPropertyCommand (nullable field, set and cleared)', () {
      final doc = _freshDoc();
      const rackId = Uuid('rack-1');
      doc.racks[rackId] = _rack(rackId);
      final set = SetRackPropertyCommand<Len?>(
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
      final clear = SetRackPropertyCommand<Len?>(
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

    test('AddLinkCommand', () {
      final doc = _freshDoc();
      final cmd = AddLinkCommand(
        designator: 'W001',
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
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        now: DateTime.utc(2026),
        actor: 'seed',
      )..apply(doc);
      final cmd = RemoveLinkCommand(id: add.id, netId: add.netId);

      final changed = _changedTopLevelKeys(doc, () => cmd.apply(doc));

      _expectTouchesCoversChanges(cmd, changed, expectAtLeast: {'links'});
    });
  });
}
