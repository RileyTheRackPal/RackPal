// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take —
// checking the state after apply is what makes the check after revert mean
// anything. Collapsing the pair into a cascade would delete the
// intermediate assertion, which is the opposite of a simplification.
//
// commands/set_entity_property_command.dart — board M3-A/5, AC-013.
//
// =====================================================================
// THE TWO LOAD-BEARING GROUPS ARE THE LAST TWO
// =====================================================================
// `the retrofit and the tables agree` is what makes this task's own claim
// true rather than merely intended: "wiring a field to a Command IS the
// AC-013 retrofit". It greps the two model files for `@internal` setters
// and asserts the set matches the table keys EXACTLY, in both directions,
// so retrofitting a field without wiring it (an inspector cannot reach it)
// and wiring a field without retrofitting it (anything at all can write it
// behind the command system's back) are both failures.
//
// `CR-117 byte identity` is here rather than left to the generic harness
// because `command_roundtrip_test.dart`'s random walk HAS NO STRUCTURE
// ARMS AT ALL — it generates devices, racks and links, and never an
// `Outlet` — so the whole M3-A command family would otherwise have no
// byte-identity coverage. That gap predates this task (it is #140's) and
// is a board item; these cases cover this command in the meantime.
import 'dart:io';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 8, 6);
final _later = DateTime.utc(2026, 8, 7);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

/// A project with one Structure body, one Outlet on it, and one home run
/// pulled from that outlet — so every one of the four tables has a real
/// entity to be exercised against.
({
  RackDocument doc,
  Uuid bodyId,
  Uuid outletId,
  Uuid deviceId,
  Uuid linkId,
})
_project() {
  final doc = RackDocument(
    id: const Uuid('doc-entity-props'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'seed',
  )..apply(doc);
  final outlet = AddOutletCommand(
    structureBodyId: structure.bodyId,
    designation: 'GR-TV-1',
    order: nextOutletOrder(doc),
    now: _now,
    actor: 'seed',
  )..apply(doc);
  final run =
      (buildAddHomeRunCommand(
                doc: doc,
                outletId: outlet.id,
                fieldLabel: 'GR-DATA-1',
                designator: 'W001',
                netName: 'N001',
                media: const MediaTypeId('media.cat6_utp'),
                fieldEnd: const PlaceEndpoint(description: 'Great Room'),
                terminationField: TerminationType.keystone,
                now: _now,
                actor: 'seed',
              )
              as AddHomeRunReady)
          .command
        ..apply(doc);

  return (
    doc: doc,
    bodyId: structure.bodyId,
    outletId: outlet.id,
    // The Structure device. It has no template by spec (docs/07 §2), and
    // `buildEquipmentList` handles that, so it is a legitimate row on
    // T6.30 and does not need a template snapshot staged for it.
    deviceId: structure.deviceId,
    linkId: run.id,
  );
}

/// The word T6.30 prints in [deviceId]'s STATUS position, through the real
/// derivation rather than by re-reading the enum.
String _statusWordFor(RackDocument doc, Uuid deviceId) {
  final row = [
    for (final group in buildEquipmentList(doc).groups)
      for (final r in group.rows)
        if (r.deviceId == deviceId) r,
  ].single;
  return lifecycleLabel(row.lifecycleStatus);
}

SetEntityPropertyCommand<E, T> _cmd<E, T>(
  Uuid id,
  EntityField<E, T> field,
  T from,
  T to, {
  DateTime? now,
}) => SetEntityPropertyCommand<E, T>(
  id: id,
  field: field,
  from: from,
  to: to,
  now: now ?? _later,
  actor: 'tester',
);

/// Every `@internal` setter name declared in model file [fileName].
Set<String> _internalSetters(String fileName) {
  final source = File('lib/src/model/$fileName').readAsStringSync();
  return {
    for (final m in RegExp(
      r'@internal\s*\n\s*set\s+(\w+)\s*\(',
    ).allMatches(source))
      m.group(1)!,
  };
}

void main() {
  group('the accessor tables', () {
    test('every key is unique within its table — a duplicate would '
        'silently merge two unrelated properties into one undo entry', () {
      for (final table in [OutletField.all, StructureBodyField.all]) {
        final keys = [for (final f in table) f.key];
        expect(keys.toSet(), hasLength(keys.length), reason: '$keys');
      }
    });

    test('every field declares a non-empty epoch mask', () {
      for (final f in [...OutletField.all, ...StructureBodyField.all]) {
        expect(f.touches.bits, isNot(0), reason: f.key);
      }
    });

    test('text fields touch meta; physical fields touch structure', () {
      // The split `EpochMask`'s own doc comments describe: `meta` is
      // "designators, names, notes", `structure` is where a thing sits.
      for (final f in [
        OutletField.designation,
        OutletField.notes,
        OutletField.tia570Grade,
        StructureBodyField.title,
        StructureBodyField.enclosureModel,
      ]) {
        expect(f.touches.has(EpochMask.meta), isTrue, reason: f.key);
      }
      for (final f in [
        OutletField.locationId,
        OutletField.wall,
        OutletField.mountSurface,
        OutletField.mountHeightAff,
        OutletField.floorNumber,
        OutletField.pathwayId,
        OutletField.nominalRunLength,
        StructureBodyField.role,
        StructureBodyField.distributionDeviceLocationId,
        StructureBodyField.sheetEdge,
      ]) {
        expect(f.touches.has(EpochMask.structure), isTrue, reason: f.key);
      }
    });

    test('nominalRunLength also declares wires — it is a CABLE length the '
        'schedule prints in a link row', () {
      expect(OutletField.nominalRunLength.touches.has(EpochMask.wires), isTrue);
    });

    test('every field names the access its entity type requires', () {
      for (final f in OutletField.all) {
        expect(f.access.name, 'outlet', reason: f.key);
      }
      for (final f in StructureBodyField.all) {
        expect(f.access.name, 'structureBody', reason: f.key);
      }
    });

    test('get and set round-trip through a real Outlet for every field', () {
      final p = _project();
      final outlet = p.doc.outlets[p.outletId]!;

      // Each pair is (a value, a second DISTINCT value) so no case can
      // pass by the field already holding what was written.
      void check<T>(EntityField<Outlet, T> f, T a, T b) {
        f.set(outlet, a);
        expect(f.get(outlet), a, reason: '${f.key} -> a');
        f.set(outlet, b);
        expect(f.get(outlet), b, reason: '${f.key} -> b');
      }

      check(OutletField.designation, 'GR-TV-9', 'GR-TV-2');
      check(OutletField.notes, 'behind the panel', null);
      check(OutletField.tia570Grade, 'grade2', null);
      check(OutletField.locationId, const Uuid('loc-1'), null);
      check(OutletField.wall, Wall.s, null);
      check(OutletField.mountSurface, MountSurface.ceiling, null);
      check(OutletField.mountHeightAff, const Len(450000000), null);
      check(OutletField.floorNumber, 2, null);
      check(OutletField.pathwayId, const Uuid('pw-1'), null);
      check(OutletField.nominalRunLength, const Len(25000000000), null);
    });

    test('get and set round-trip through a real StructureBody for every '
        'field', () {
      final p = _project();
      final body = p.doc.structures[p.bodyId]!;

      void check<T>(EntityField<StructureBody, T> f, T a, T b) {
        f.set(body, a);
        expect(f.get(body), a, reason: '${f.key} -> a');
        f.set(body, b);
        expect(f.get(body), b, reason: '${f.key} -> b');
      }

      check(StructureBodyField.title, 'Second Floor', 'MDF');
      check(StructureBodyField.enclosureModel, 'Generic 42 in', null);
      check(
        StructureBodyField.role,
        StructureRole.serviceEntrance,
        StructureRole.homeRunField,
      );
      check(
        StructureBodyField.distributionDeviceLocationId,
        const Uuid('loc-2'),
        null,
      );
      check(StructureBodyField.sheetEdge, SheetEdge.right, SheetEdge.left);
    });
  });

  group('apply / revert', () {
    test('writes the value and restores it exactly, including the meta '
        'triple', () {
      final p = _project();
      final outlet = p.doc.outlets[p.outletId]!;
      final beforeAt = outlet.meta.updatedAt;
      final beforeBy = outlet.meta.updatedBy;
      final beforeRev = outlet.meta.localRevision;
      final cmd = _cmd(
        p.outletId,
        OutletField.designation,
        'GR-TV-1',
        'GR-TV-4',
      );

      cmd.apply(p.doc);
      expect(outlet.designation, 'GR-TV-4');
      expect(outlet.meta.updatedBy, 'tester');

      cmd.revert(p.doc);
      expect(outlet.designation, 'GR-TV-1');
      expect(outlet.meta.updatedAt, beforeAt);
      expect(outlet.meta.updatedBy, beforeBy);
      expect(
        outlet.meta.localRevision,
        beforeRev,
        reason:
            'a revision left one higher than before apply is exactly what '
            'breaks CR-117 byte identity',
      );
    });

    test('touches the entity being edited and no other', () {
      // The Structure device and its body share one `EntityMeta` INSTANCE
      // at creation (`AddStructureCommand` hands the same object to both),
      // so editing the body must not be readable as an edit to something
      // else through a shared reference.
      final p = _project();
      final outletRev = p.doc.outlets[p.outletId]!.meta.localRevision;

      _cmd(p.bodyId, StructureBodyField.title, 'Rough-In', 'MDF')
        ..apply(p.doc)
        ..revert(p.doc);

      expect(p.doc.outlets[p.outletId]!.meta.localRevision, outletRev);
    });

    test('is idempotent under alternation (apply; revert; apply)', () {
      final once = _project();
      final thrice = _project();

      _cmd(
        once.bodyId,
        StructureBodyField.sheetEdge,
        SheetEdge.left,
        SheetEdge.right,
      ).apply(once.doc);
      _cmd(
          thrice.bodyId,
          StructureBodyField.sheetEdge,
          SheetEdge.left,
          SheetEdge.right,
        )
        ..apply(thrice.doc)
        ..revert(thrice.doc)
        ..apply(thrice.doc);

      // docs/03-architecture.md §5.1's law: `apply` alone and
      // `apply; revert; apply` land in the identical state.
      expect(
        thrice.doc.structures[thrice.bodyId]!.sheetEdge,
        SheetEdge.right,
      );
      expect(
        thrice.doc.structures[thrice.bodyId]!.meta.localRevision,
        once.doc.structures[once.bodyId]!.meta.localRevision,
        reason:
            'the meta triple must land identically too, or CR-117 byte '
            'identity fails on any sequence containing a redo',
      );
    });

    test('a nullable field round-trips through null in both directions', () {
      final p = _project();
      final setIt = _cmd<Outlet, Len?>(
        p.outletId,
        OutletField.mountHeightAff,
        null,
        const Len(450000000),
      );

      setIt.apply(p.doc);
      expect(p.doc.outlets[p.outletId]!.mountHeightAff, const Len(450000000));
      setIt.revert(p.doc);
      expect(
        p.doc.outlets[p.outletId]!.mountHeightAff,
        isNull,
        reason:
            'unset must survive a round trip as unset, not as zero '
            '(G4, CR-114)',
      );
    });

    test('revert before apply throws rather than silently corrupting the '
        'meta triple', () {
      final p = _project();

      expect(
        () => _cmd(p.outletId, OutletField.floorNumber, null, 2).revert(p.doc),
        throwsStateError,
      );
    });

    test('an entity the document no longer holds names itself', () {
      // An undo stack replayed against the wrong document, or a command
      // outliving what it edits. Either is a bug worth a sentence rather
      // than a null dereference three frames deeper.
      final p = _project();
      final cmd = _cmd(p.outletId, OutletField.floorNumber, null, 2);
      RemoveOutletCommand(id: p.outletId).apply(p.doc);

      expect(
        () => cmd.apply(p.doc),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('outlet'), contains('floorNumber')),
          ),
        ),
      );
    });
  });

  group('CR-117 byte identity: revert restores the exact bytes', () {
    void expectByteIdentical<E, T>(
      SetEntityPropertyCommand<E, T> cmd,
      RackDocument doc,
    ) {
      final before = _codec.write(doc);
      cmd.apply(doc);
      expect(
        _codec.write(doc),
        isNot(orderedEquals(before)),
        reason: 'the command changed nothing, so the check below is vacuous',
      );
      cmd.revert(doc);
      expect(_codec.write(doc), orderedEquals(before));
    }

    test('an Outlet text field', () {
      final p = _project();
      expectByteIdentical(
        _cmd(p.outletId, OutletField.designation, 'GR-TV-1', 'GR-TV-4'),
        p.doc,
      );
    });

    test('a StructureBody enum field', () {
      final p = _project();
      expectByteIdentical(
        _cmd(
          p.bodyId,
          StructureBodyField.sheetEdge,
          SheetEdge.left,
          SheetEdge.right,
        ),
        p.doc,
      );
    });

    test('setting an unknown field, which is an ABSENT KEY becoming a '
        'present one', () {
      final p = _project();
      expectByteIdentical(
        _cmd<Outlet, Len?>(
          p.outletId,
          OutletField.mountHeightAff,
          null,
          const Len(450000000),
        ),
        p.doc,
      );
    });

    test('CLEARING a field back to unknown, which is the direction an '
        'explicit null would break', () {
      final p = _project();
      _cmd<Outlet, Len?>(
        p.outletId,
        OutletField.mountHeightAff,
        null,
        const Len(450000000),
      ).apply(p.doc);

      expectByteIdentical(
        _cmd<Outlet, Len?>(
          p.outletId,
          OutletField.mountHeightAff,
          const Len(450000000),
          null,
          now: DateTime.utc(2026, 8, 8),
        ),
        p.doc,
      );
    });

    test('a cleared field leaves NO key behind, rather than a null one', () {
      final p = _project();
      _cmd<Outlet, int?>(
        p.outletId,
        OutletField.floorNumber,
        null,
        2,
      ).apply(p.doc);
      _cmd<Outlet, int?>(
        p.outletId,
        OutletField.floorNumber,
        2,
        null,
        now: DateTime.utc(2026, 8, 8),
      ).apply(p.doc);

      expect(
        String.fromCharCodes(_codec.write(p.doc)),
        isNot(contains('floorNumber')),
        reason:
            'G4/CR-114: unknown serializes as an absent key, never an '
            'explicit null',
      );
    });
  });

  group('merge behaviour — coalescing is PER PROPERTY, PER ENTITY', () {
    test('two edits to the same field merge, keeping the ORIGINAL '
        'from-value', () {
      final p = _project();
      final first = _cmd(p.outletId, OutletField.designation, 'a', 'b');
      final second = _cmd(p.outletId, OutletField.designation, 'b', 'c');

      final merged =
          first.mergeWith(second)! as SetEntityPropertyCommand<Outlet, String>;

      expect(merged.from, 'a');
      expect(merged.to, 'c');
    });

    test('a merged command reverts all the way to the original value', () {
      final p = _project();
      final first = _cmd(
        p.outletId,
        OutletField.designation,
        'GR-TV-1',
        'GR-TV-2',
      )..apply(p.doc);
      final second = _cmd(
        p.outletId,
        OutletField.designation,
        'GR-TV-2',
        'GR-TV-3',
      )..apply(p.doc);

      first.mergeWith(second)!.revert(p.doc);

      expect(p.doc.outlets[p.outletId]!.designation, 'GR-TV-1');
      expect(
        p.doc.outlets[p.outletId]!.meta.localRevision,
        0,
        reason:
            'the merged command must carry the meta snapshot captured by '
            'the FIRST command forward, not the second one',
      );
    });

    test('two DIFFERENT fields never merge', () {
      final p = _project();
      final a = _cmd(p.outletId, OutletField.designation, 'a', 'b');
      final b = _cmd(p.outletId, OutletField.notes, null, 'note');

      expect(a.mergeWith(b), isNull);
      expect(a.mergeKey == b.mergeKey, isFalse);
    });

    test('the same field on two different outlets never merges', () {
      final p = _project();
      final a = _cmd(p.outletId, OutletField.designation, 'a', 'b');
      final b = _cmd(const Uuid('other'), OutletField.designation, 'a', 'b');

      expect(a.mergeWith(b), isNull);
      expect(a.mergeKey == b.mergeKey, isFalse);
    });

    test('an Outlet edit never merges with a StructureBody edit', () {
      final p = _project();
      final outlet = _cmd(p.outletId, OutletField.designation, 'a', 'b');
      final body = _cmd(p.outletId, StructureBodyField.title, 'a', 'b');

      expect(outlet.mergeWith(body), isNull);
    });

    test('every field of BOTH tables has a distinct merge key for one and '
        'the same id', () {
      // No key is shared between the two tables today. This is the guard
      // that stays true the day one is — an `Outlet.locationId` and a
      // `StructureBody.locationId` edited in the same gesture must not
      // collapse into one undo entry, and the entity id alone would not
      // separate them if a caller ever reused one.
      const id = Uuid('same-id');
      final keys = <Object?>{
        for (final f in OutletField.all)
          SetEntityPropertyCommand<Outlet, Object?>(
            id: id,
            field: f,
            from: null,
            to: null,
            now: _now,
            actor: 't',
          ).mergeKey,
        for (final f in StructureBodyField.all)
          SetEntityPropertyCommand<StructureBody, Object?>(
            id: id,
            field: f,
            from: null,
            to: null,
            now: _now,
            actor: 't',
          ).mergeKey,
      };

      expect(
        keys,
        hasLength(OutletField.all.length + StructureBodyField.all.length),
      );
    });

    test('does not merge with an unrelated command type', () {
      final p = _project();

      expect(
        _cmd(
          p.outletId,
          OutletField.designation,
          'a',
          'b',
        ).mergeWith(RemoveOutletCommand(id: p.outletId)),
        isNull,
      );
    });
  });

  group('buildSetEntityProperty', () {
    test('returns null when the value is already what was asked for', () {
      final p = _project();

      expect(
        buildSetEntityProperty(
          doc: p.doc,
          id: p.outletId,
          field: OutletField.designation,
          to: 'GR-TV-1',
          now: _later,
          actor: 't',
        ),
        isNull,
        reason:
            'a no-op must be distinguishable from a real edit so the '
            'caller does not push an empty undo entry',
      );
    });

    test('captures the CURRENT value as `from`', () {
      final p = _project();
      final cmd = buildSetEntityProperty(
        doc: p.doc,
        id: p.bodyId,
        field: StructureBodyField.role,
        to: StructureRole.serviceEntrance,
        now: _later,
        actor: 't',
      )!;

      expect(cmd.from, StructureRole.homeRunField);
      expect(cmd.to, StructureRole.serviceEntrance);
    });

    test('handles the unknown-to-value and value-to-unknown transitions', () {
      final p = _project();

      final set = buildSetEntityProperty<Outlet, Len?>(
        doc: p.doc,
        id: p.outletId,
        field: OutletField.nominalRunLength,
        to: const Len(25000000000),
        now: _later,
        actor: 't',
      )!;
      expect(set.from, isNull);
      set.apply(p.doc);

      final clear = buildSetEntityProperty<Outlet, Len?>(
        doc: p.doc,
        id: p.outletId,
        field: OutletField.nominalRunLength,
        to: null,
        now: _later,
        actor: 't',
      )!;
      expect(clear.from, const Len(25000000000));
      expect(clear.to, isNull);
    });

    test('an unknown id THROWS rather than returning null — that is a '
        'caller bug, not a no-op', () {
      final p = _project();

      expect(
        () => buildSetEntityProperty(
          doc: p.doc,
          id: const Uuid('nope'),
          field: OutletField.designation,
          to: 'x',
          now: _later,
          actor: 't',
        ),
        throwsArgumentError,
      );
    });
  });

  group('LifecycleStatus is reachable through a gesture (M3-A/7)', () {
    // The property this group exists for, in the board item's words: the
    // model has carried the five-value enum since M0 and NOTHING COULD
    // CHANGE IT, so four of the five elevation borders were reachable only
    // by hand-authoring a file. `lifecycle_status_expression_test.dart`
    // pins that the five borders and the five labels differ; this pins
    // that the app can put a device or a cable into each of them.
    test('all five states are reachable on a DEVICE, and undo comes back', () {
      final p = _project();
      final device = p.doc.devices[p.deviceId]!;
      expect(device.lifecycleStatus, LifecycleStatus.new_);

      for (final status in LifecycleStatus.values) {
        final cmd = buildSetEntityProperty(
          doc: p.doc,
          id: p.deviceId,
          field: DeviceField.lifecycleStatus,
          to: status,
          now: _later,
          actor: 'tester',
        );
        if (status == LifecycleStatus.new_) {
          expect(
            cmd,
            isNull,
            reason: 'the device already holds the default; that is a no-op',
          );
          continue;
        }
        cmd!.apply(p.doc);
        expect(device.lifecycleStatus, status);
        cmd.revert(p.doc);
        expect(device.lifecycleStatus, LifecycleStatus.new_);
      }
    });

    test('all five states are reachable on a LINK', () {
      final p = _project();
      final link = p.doc.links[p.linkId]!;

      for (final status in LifecycleStatus.values) {
        if (status == LifecycleStatus.new_) continue;
        buildSetEntityProperty(
          doc: p.doc,
          id: p.linkId,
          field: LinkField.lifecycleStatus,
          to: status,
          now: _later,
          actor: 'tester',
        )!.apply(p.doc);
        expect(link.lifecycleStatus, status);
      }
    });

    test('DESIGN INTENT reaches T6.30 from a gesture, which is the whole '
        'point', () {
      // Before this task the equipment list could print `DESIGN INTENT`
      // only for a device somebody had hand-authored into a file. The
      // label table and the command are joined here so neither can be
      // changed without the other being considered.
      final p = _project();
      expect(_statusWordFor(p.doc, p.deviceId), 'NEW');

      buildSetEntityProperty(
        doc: p.doc,
        id: p.deviceId,
        field: DeviceField.lifecycleStatus,
        to: LifecycleStatus.designIntent,
        now: _later,
        actor: 'tester',
      )!.apply(p.doc);

      expect(_statusWordFor(p.doc, p.deviceId), 'DESIGN INTENT');
    });

    test('the device field declares BOTH epochs the rack canvas listens '
        'to', () {
      // `structure` redraws the elevation border, `meta` refreshes T6.30's
      // word. Declaring one would leave a user looking at a stale surface
      // after an edit they just made.
      expect(
        DeviceField.lifecycleStatus.touches.has(EpochMask.structure),
        isTrue,
      );
      expect(DeviceField.lifecycleStatus.touches.has(EpochMask.meta), isTrue);
    });

    test('the link field declares wires, not structure — a cable reaches '
        'paper through the schedule and the schematic', () {
      expect(LinkField.lifecycleStatus.touches.has(EpochMask.wires), isTrue);
      expect(LinkField.lifecycleStatus.touches.has(EpochMask.meta), isTrue);
    });

    test('a device edit and a link edit never merge with each other', () {
      final p = _project();
      final device = _cmd(
        p.deviceId,
        DeviceField.lifecycleStatus,
        LifecycleStatus.new_,
        LifecycleStatus.existing,
      );
      final link = _cmd(
        p.linkId,
        LinkField.lifecycleStatus,
        LifecycleStatus.new_,
        LifecycleStatus.existing,
      );

      expect(device.mergeWith(link), isNull);
      expect(device.mergeKey == link.mergeKey, isFalse);
    });

    test('a device lifecycle edit round-trips byte-identically', () {
      final p = _project();
      final before = _codec.write(p.doc);
      final cmd = _cmd(
        p.deviceId,
        DeviceField.lifecycleStatus,
        LifecycleStatus.new_,
        LifecycleStatus.removed,
      )..apply(p.doc);
      expect(_codec.write(p.doc), isNot(orderedEquals(before)));

      cmd.revert(p.doc);
      expect(_codec.write(p.doc), orderedEquals(before));
    });
  });

  group('Link.spliceCount — null is unknown, 0 is none (M3-J/2)', () {
    // DR-020 §11.19.2(3). A splice is a real as-built fact with real
    // consequences: on Cat6 it breaks the channel and fails
    // certification, on coax it is loss, on fibre it is normal and
    // engineered. The whole reason it is `int?` is that a non-nullable
    // `int` defaulting to 0 cannot tell "nobody has looked" from
    // "somebody looked and there are none".

    ({RackDocument doc, Uuid linkId}) seeded() {
      final p = _project();
      return (doc: p.doc, linkId: p.linkId);
    }

    void setSplices(RackDocument doc, Uuid linkId, int? to) {
      buildSetEntityProperty(
        doc: doc,
        id: linkId,
        field: LinkField.spliceCount,
        to: to,
        now: _later,
        actor: 'tester',
      )!.apply(doc);
    }

    test('a new run has NOT been looked at', () {
      final p = seeded();
      expect(p.doc.links[p.linkId]!.spliceCount, isNull);
    });

    test('a confirmed none is 0 and survives the round trip AS 0', () {
      // The case a falsy-write codec would destroy. `0` is a measurement:
      // somebody opened the ceiling and counted.
      final p = seeded();
      setSplices(p.doc, p.linkId, 0);

      final read = _codec.read(_codec.write(p.doc));
      final link = (read as Ok<RackDocument>).value.links[p.linkId]!;
      expect(link.spliceCount, 0);
      expect(link.spliceCount, isNotNull);
    });

    test('and UNKNOWN is an absent key, never an explicit null', () {
      // G4's serialization rule (CR-114), asserted on the wire rather
      // than on the model, because the model cannot tell the two apart.
      final p = seeded();
      final tree = _codec.encodeToJsonTree(p.doc);
      final links =
          (tree['document']! as Map<String, Object?>)['links']!
              as Map<String, Object?>;
      final link = links[p.linkId.v]! as Map<String, Object?>;

      expect(link.containsKey('spliceCount'), isFalse);
    });

    test('a confirmed none WRITES the key, which is the whole point', () {
      final p = seeded();
      setSplices(p.doc, p.linkId, 0);

      final tree = _codec.encodeToJsonTree(p.doc);
      final links =
          (tree['document']! as Map<String, Object?>)['links']!
              as Map<String, Object?>;
      final link = links[p.linkId.v]! as Map<String, Object?>;

      expect(link['spliceCount'], 0);
    });

    test('clearing the cell goes back to UNKNOWN, not to zero', () {
      // An installer who typed a number into the wrong row must be able
      // to take the claim back, not merely correct it to "none".
      final p = seeded();
      setSplices(p.doc, p.linkId, 2);
      expect(p.doc.links[p.linkId]!.spliceCount, 2);

      setSplices(p.doc, p.linkId, null);
      expect(p.doc.links[p.linkId]!.spliceCount, isNull);
    });

    test('the edit round-trips byte-identically on revert (CR-117)', () {
      final p = seeded();
      final before = _codec.write(p.doc);
      final cmd = buildSetEntityProperty(
        doc: p.doc,
        id: p.linkId,
        field: LinkField.spliceCount,
        to: 3,
        now: _later,
        actor: 'tester',
      )!..apply(p.doc);
      expect(_codec.write(p.doc), isNot(orderedEquals(before)));

      cmd.revert(p.doc);
      expect(_codec.write(p.doc), orderedEquals(before));
    });

    test('it declares wires and meta, like every other Link field', () {
      // A splice count reaches paper through the schedule, so the
      // schematic canvas and the sheet both have to see the epoch move.
      expect(LinkField.spliceCount.touches.has(EpochMask.wires), isTrue);
      expect(LinkField.spliceCount.touches.has(EpochMask.meta), isTrue);
    });

    test('and it never merges with the lifecycle edit beside it', () {
      // Coalescing is per property, per entity: an undo that took back a
      // splice count AND a lifecycle change would describe neither.
      final p = seeded();
      final splice = buildSetEntityProperty(
        doc: p.doc,
        id: p.linkId,
        field: LinkField.spliceCount,
        to: 1,
        now: _later,
        actor: 'tester',
      )!;
      final lifecycle = buildSetEntityProperty(
        doc: p.doc,
        id: p.linkId,
        field: LinkField.lifecycleStatus,
        to: LifecycleStatus.existing,
        now: _later,
        actor: 'tester',
      )!;

      expect(splice.mergeWith(lifecycle), isNull);
      expect(splice.mergeKey == lifecycle.mergeKey, isFalse);
    });
  });

  group('the retrofit and the tables agree (AC-013)', () {
    // The task's claim is that wiring a field to a Command IS the
    // `@internal` retrofit. These two cases are what make that a fact
    // instead of an intention, and they fail in BOTH directions:
    // retrofitting without wiring leaves a field no inspector can reach,
    // and wiring without retrofitting leaves a field anything at all can
    // write behind the command system's back.
    //
    // Reads the model source relative to CWD, like
    // internal_setter_grep_test.dart — run the suite from the package
    // directory.
    test('every @internal Outlet setter has a table row, and vice versa', () {
      expect(
        _internalSetters('outlet.dart'),
        {for (final f in OutletField.all) f.key},
      );
    });

    test('every @internal StructureBody setter has a table row, and vice '
        'versa', () {
      // ONE FILE, TWO TABLES. `structure_body.dart` declares both
      // `StructureBody` and `StructureOrigin`, and the second's table
      // lives in `home_run_commands.dart` beside the builder that guards
      // CR-113 (see that file's block comment). This case is what CAUGHT
      // the origin retrofit when M3-A/8 made it: it read as a
      // `StructureBodyField`-only equality and failed the moment six new
      // `@internal` setters appeared in the file, which is exactly what an
      // earlier revision of this comment said it was here to do.
      //
      // The origin keys are NAMESPACED (`origin.fieldLabel`) so their
      // merge keys cannot collide with a future `Link.fieldLabel`, so the
      // comparison is against the setter NAME: the part after the dot.
      expect(_internalSetters('structure_body.dart'), {
        for (final f in StructureBodyField.all) f.key,
        for (final f in StructureOriginField.all) f.key.split('.').last,
      });
    });

    test('every @internal Location setter has a table row, except the one '
        'DR-021 keeps out', () {
      // `parentId` IS an `@internal` setter and is deliberately NOT a
      // table row: DR-021 §11.20.5 makes a reparent refuse a cycle, and a
      // row's `set` writes and returns with no way to refuse.
      // `ReparentLocationCommand` owns it, behind `buildReparentLocation`.
      //
      // Named literally here rather than filtered out by a predicate, so
      // that a SECOND field escaping the table fails this case instead of
      // slipping through a rule that was written for one.
      expect(_internalSetters('location.dart'), {
        for (final f in LocationField.all) f.key,
        'parentId',
      });
    });

    test('every DeviceInstance and Link table key has an @internal setter '
        'behind it', () {
      // ONE DIRECTION ONLY for these two, and the asymmetry is real rather
      // than laziness: `DeviceInstance.designator`, `.name`, `.placement`
      // and `.notes` are converted setters wired to `RenameEntityCommand`
      // and `MoveDeviceCommand`, and `Link` has five of its own. So these
      // tables are SUBSETS, and the direction that must hold is that no
      // table row writes a field the retrofit skipped.
      expect(
        _internalSetters('device_instance.dart'),
        containsAll([for (final f in DeviceField.all) f.key]),
      );
      expect(
        _internalSetters('link.dart'),
        containsAll([for (final f in LinkField.all) f.key]),
      );
    });
  });
}
