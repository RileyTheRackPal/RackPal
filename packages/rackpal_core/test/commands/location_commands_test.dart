// M3-B/1, #144 — creating and moving a node of the location tree
// (CR-047, CR-112, DR-021).
//
// Four claims:
//
//   1. `AddLocationCommand` creates a node nothing could create before,
//      and `nextLocationOrder` allocates PER SIBLING GROUP rather than per
//      document;
//   2. the rename is a `LocationField` row on the ONE accessor table
//      (#578), not a fifth command class, and `parentId` is the one field
//      kept out of it;
//   3. `buildReparentLocation` REFUSES a cycle with a sentence that names
//      both nodes (DR-021 §11.20.5), and refuses nothing else;
//   4. every one of them is lossless under revert, which is CR-117's
//      property stated at the command rather than at the file.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _when = DateTime.utc(2026, 8, 6);
final _later = DateTime.utc(2026, 8, 7);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-location-commands'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

/// Adds one location and returns its id.
Uuid _add(RackDocument doc, String name, {Uuid? parent, String? code}) =>
    (AddLocationCommand(
      name: name,
      code: code ?? name.substring(0, 2).toUpperCase(),
      order: nextLocationOrder(doc, parentId: parent),
      parentId: parent,
      now: _when,
      actor: 'seed',
    )..apply(doc)).id;

void main() {
  group('AddLocationCommand', () {
    test('creates a node, and revert takes exactly it back out', () {
      final doc = _doc();
      final cmd = AddLocationCommand(
        name: 'Living Room',
        code: 'LR',
        order: nextLocationOrder(doc),
        // Not the `room` default: the created node has to carry the
        // kind it was asked for, and a case that passes the default
        // cannot tell that apart from the field being ignored.
        kind: LocationKind.zone,
        now: _when,
        actor: 'tester',
      )..apply(doc);

      expect(doc.locations[cmd.id]!.name, 'Living Room');
      expect(doc.locations[cmd.id]!.code, 'LR');
      expect(doc.locations[cmd.id]!.kind, LocationKind.zone);
      expect(doc.locations[cmd.id]!.parentId, isNull);

      cmd.revert(doc);
      expect(doc.locations, isEmpty);
    });

    test('redo recreates the IDENTICAL node, so a child still resolves', () {
      // The `Command` contract: ids are minted in the constructor, never
      // in `apply`. A regenerated id would leave every child location, and
      // every rack pointing at this room, naming a node that no longer
      // exists after one undo/redo.
      final doc = _doc();
      final parent = AddLocationCommand(
        name: 'Main House',
        code: 'MH',
        order: nextLocationOrder(doc),
        now: _when,
        actor: 'tester',
      )..apply(doc);
      final childId = _add(doc, 'Living Room', parent: parent.id);

      parent
        ..revert(doc)
        ..apply(doc);

      expect(doc.locations[parent.id], isNotNull);
      expect(doc.locations[childId]!.parentId, parent.id);
    });

    test('an unmeasured room estimate stays null, never a measured zero', () {
      // G4/CR-114 at the one point the user is saying they have no number.
      final doc = _doc();
      final id = _add(doc, 'Attic');

      expect(doc.locations[id]!.estimatedRunLengthFromRack, isNull);
    });

    test('nextLocationOrder allocates per sibling group, not per document', () {
      // The tree sorts siblings against each other, so a new room under
      // one parent must not inherit an index derived from an unrelated
      // branch. Both children below are the FIRST child of their own
      // parent and so must share a starting index.
      final doc = _doc();
      final house = _add(doc, 'Main House');
      final shed = _add(doc, 'Shed');

      final firstUnderHouse = nextLocationOrder(doc, parentId: house);
      _add(doc, 'Living Room', parent: house);
      _add(doc, 'Kitchen', parent: house);
      final firstUnderShed = nextLocationOrder(doc, parentId: shed);

      expect(firstUnderShed.v, firstUnderHouse.v);
      // `compareTo`, not `greaterThan`: `FracIndex` is a string and the
      // ordering that matters is the one `_sortSiblings` uses, which is
      // `String.compareTo`. Dart's `String` has no `<`.
      expect(
        nextLocationOrder(doc, parentId: house).v.compareTo(firstUnderHouse.v),
        greaterThan(0),
      );
    });

    test('roots are a sibling group of their own', () {
      final doc = _doc();
      final first = nextLocationOrder(doc);
      _add(doc, 'Main House');

      expect(nextLocationOrder(doc).v.compareTo(first.v), greaterThan(0));
    });
  });

  group('the rename is a table row (#578), not a command class', () {
    test('LocationField.name writes through SetEntityPropertyCommand', () {
      final doc = _doc();
      final id = _add(doc, 'Livng Room', code: 'LR');

      final cmd = buildSetEntityProperty(
        doc: doc,
        id: id,
        field: LocationField.name,
        to: 'Living Room',
        now: _later,
        actor: 'tester',
      )!..apply(doc);

      expect(doc.locations[id]!.name, 'Living Room');
      cmd.revert(doc);
      expect(doc.locations[id]!.name, 'Livng Room');
    });

    test('a no-op edit builds no command at all', () {
      // docs/04 §3.4's "never silently do nothing" from the other side:
      // the caller can tell "nothing to do" from "did something" instead
      // of pushing an empty entry onto the undo stack.
      final doc = _doc();
      final id = _add(doc, 'Living Room', code: 'LR');

      expect(
        buildSetEntityProperty(
          doc: doc,
          id: id,
          field: LocationField.code,
          to: 'LR',
          now: _later,
          actor: 'tester',
        ),
        isNull,
      );
    });

    test('the byte round-trip is stated for EVERY row, and the table says '
        'so', () {
      // CR-117 per row rather than per command: the table is what makes
      // adding a field cheap, so the property has to hold for the table
      // rather than for one hand-picked member of it.
      //
      // A LOOP OVER `LocationField.all` CANNOT DO THIS. `all` is typed
      // `EntityField<Location, Object?>`, and `set_entity_property_command`
      // says out loud that the erased element type is READ-ONLY: applying
      // through it throws at runtime, because the closure really is
      // `(Location, String) => void`. So the cases are written out, typed,
      // and the FIRST assertion here is that there is one per row.
      expect(
        _byteRoundTripCases.keys.toSet(),
        {for (final f in LocationField.all) f.key},
        reason:
            'a LocationField row has no byte round-trip case, or a case '
            'names a row that no longer exists',
      );

      for (final entry in _byteRoundTripCases.entries) {
        final doc = _doc();
        final id = _add(doc, 'Living Room', code: 'LR');
        final before = _codec.write(doc);

        final cmd = entry.value(doc, id)..apply(doc);

        expect(
          _codec.write(doc),
          isNot(orderedEquals(before)),
          reason:
              '${entry.key} changed nothing, so its case would pass '
              'vacuously',
        );

        cmd.revert(doc);
        expect(_codec.write(doc), orderedEquals(before), reason: entry.key);
      }
    });
  });

  group('buildReparentLocation', () {
    test('moves a root under a parent, and revert puts it back at the top', () {
      final doc = _doc();
      final house = _add(doc, 'Main House');
      final living = _add(doc, 'Living Room');
      final before = _codec.write(doc);

      final result = buildReparentLocation(
        doc: doc,
        id: living,
        newParentId: house,
        now: _later,
        actor: 'tester',
      );

      expect(result, isA<ReparentLocationReady>());
      final cmd = (result as ReparentLocationReady).command..apply(doc);
      expect(doc.locations[living]!.parentId, house);
      expect(LocationTree.of(doc).childrenOf(house), [living]);

      cmd.revert(doc);
      expect(doc.locations[living]!.parentId, isNull);
      // CR-117: the revision counter too, not just the field.
      expect(_codec.write(doc), orderedEquals(before));
    });

    test('moving to the top level is always legal', () {
      final doc = _doc();
      final house = _add(doc, 'Main House');
      final living = _add(doc, 'Living Room', parent: house);

      final result = buildReparentLocation(
        doc: doc,
        id: living,
        newParentId: null,
        now: _later,
        actor: 'tester',
      );

      expect(result, isA<ReparentLocationReady>());
      (result as ReparentLocationReady).command.apply(doc);
      expect(LocationTree.of(doc).roots, containsAll([house, living]));
    });

    test('a move that changes nothing is Unchanged, not Refused', () {
      // Three outcomes rather than two: "there was nothing to do" says
      // nothing to the user, "it was refused" must say a sentence, and a
      // caller cannot tell them apart from a null.
      final doc = _doc();
      final house = _add(doc, 'Main House');
      final living = _add(doc, 'Living Room', parent: house);

      expect(
        buildReparentLocation(
          doc: doc,
          id: living,
          newParentId: house,
          now: _later,
          actor: 'tester',
        ),
        isA<ReparentLocationUnchanged>(),
      );
    });

    group('the cycle refusal (DR-021 §11.20.5)', () {
      test('a node cannot be moved inside itself', () {
        final doc = _doc();
        final house = _add(doc, 'Main House');

        final result = buildReparentLocation(
          doc: doc,
          id: house,
          newParentId: house,
          now: _later,
          actor: 'tester',
        );

        expect(result, isA<ReparentLocationRefused>());
        expect(
          (result as ReparentLocationRefused).reason,
          'Main House cannot be moved inside itself.',
        );
      });

      test('a node cannot be moved inside its own descendant, and the '
          'sentence names both', () {
        // The discipline `connect_rules.dart` holds for all five topology
        // rules: a rule id alone is a log line. A user told only that the
        // move failed goes looking at the wrong node for why.
        final doc = _doc();
        final house = _add(doc, 'Main House');
        final level = _add(doc, 'Level 1', parent: house);
        final living = _add(doc, 'Living Room', parent: level);

        final result = buildReparentLocation(
          doc: doc,
          id: house,
          newParentId: living,
          now: _later,
          actor: 'tester',
        );

        expect(
          (result as ReparentLocationRefused).reason,
          'Main House cannot be moved inside Living Room, which is already '
          'inside it.',
        );
      });

      test('the refusal leaves the document completely untouched', () {
        // A refusal that had already written something would be the worst
        // of both: the user is told no and the file says yes.
        final doc = _doc();
        final house = _add(doc, 'Main House');
        _add(doc, 'Level 1', parent: house);
        final before = _codec.write(doc);

        buildReparentLocation(
          doc: doc,
          id: house,
          newParentId: LocationTree.of(doc).childrenOf(house).single,
          now: _later,
          actor: 'tester',
        );

        expect(_codec.write(doc), orderedEquals(before));
      });

      test('an unnamed node still produces a whole sentence', () {
        final doc = _doc();
        final blank = _add(doc, '  ', code: 'XX');
        final child = _add(doc, 'Level 1', parent: blank);

        final result = buildReparentLocation(
          doc: doc,
          id: blank,
          newParentId: child,
          now: _later,
          actor: 'tester',
        );

        expect(
          (result as ReparentLocationRefused).reason,
          '$kUnnamedLocation cannot be moved inside Level 1, which is '
          'already inside it.',
        );
      });
    });

    test('a location this document does not hold is refused, not thrown', () {
      final doc = _doc();
      _add(doc, 'Main House');

      expect(
        buildReparentLocation(
          doc: doc,
          id: const Uuid('ghost'),
          newParentId: null,
          now: _later,
          actor: 'tester',
        ),
        isA<ReparentLocationRefused>(),
      );
    });

    test('a parent this document does not hold is refused, not thrown', () {
      // Left dangling instead, the node would become `detached` in the
      // tree: visible, but in a state no gesture put it in.
      final doc = _doc();
      final living = _add(doc, 'Living Room');

      expect(
        buildReparentLocation(
          doc: doc,
          id: living,
          newParentId: const Uuid('ghost'),
          now: _later,
          actor: 'tester',
        ),
        isA<ReparentLocationRefused>(),
      );
    });
  });

  group('the undo stack sees these as distinct acts', () {
    test('two moves of one node do not merge into one undo entry', () {
      // Field edits coalesce so typing in a name box is one entry. A move
      // is not typing: merging two would offer one "undo move" that jumped
      // a subtree two levels, and the user would have to guess.
      final doc = _doc();
      final a = _add(doc, 'Main House');
      final b = _add(doc, 'Shed');
      final living = _add(doc, 'Living Room');

      ReparentLocationCommand build(Uuid? to, DateTime at) =>
          (buildReparentLocation(
                    doc: doc,
                    id: living,
                    newParentId: to,
                    now: at,
                    actor: 'tester',
                  )
                  as ReparentLocationReady)
              .command;

      final first = build(a, _later)..apply(doc);
      final second = build(b, _later);

      expect(first.mergeKey, isNull);
      expect(first.mergeWith(second), isNull);
    });

    test('the three location commands carry three different labels', () {
      // The Edit menu has to be able to say which of them is being undone.
      expect(LabelKey.addLocation, isNot(LabelKey.reparentLocation));
      expect(LabelKey.reparentLocation, isNot(LabelKey.removeLocation));
      expect(LabelKey.addLocation, isNot(LabelKey.setEntityProperty));
    });
  });
}

/// One typed edit per [LocationField] row, each moving the field to a
/// value a location created by `_add` does not already hold.
///
/// Keyed by the row's own `key`, so the test above can assert the two sets
/// agree and a new row cannot be added without a case.
final _byteRoundTripCases =
    <
      String,
      SetEntityPropertyCommand<Location, dynamic> Function(
        RackDocument doc,
        Uuid id,
      )
    >{
      'name': (doc, id) => SetEntityPropertyCommand<Location, String>(
        id: id,
        field: LocationField.name,
        from: doc.locations[id]!.name,
        to: 'Somewhere Else',
        now: _later,
        actor: 'tester',
      ),
      'code': (doc, id) => SetEntityPropertyCommand<Location, String>(
        id: id,
        field: LocationField.code,
        from: doc.locations[id]!.code,
        to: 'ZZ',
        now: _later,
        actor: 'tester',
      ),
      'kind': (doc, id) => SetEntityPropertyCommand<Location, LocationKind>(
        id: id,
        field: LocationField.kind,
        from: doc.locations[id]!.kind,
        to: LocationKind.zone,
        now: _later,
        actor: 'tester',
      ),
      'floorNumber': (doc, id) => SetEntityPropertyCommand<Location, int?>(
        id: id,
        field: LocationField.floorNumber,
        from: doc.locations[id]!.floorNumber,
        to: 2,
        now: _later,
        actor: 'tester',
      ),
      'spaceCode': (doc, id) => SetEntityPropertyCommand<Location, String?>(
        id: id,
        field: LocationField.spaceCode,
        from: doc.locations[id]!.spaceCode,
        to: '101',
        now: _later,
        actor: 'tester',
      ),
      // PLAN-C. The value is deliberately NOT round: DR-020 keeps this a
      // BOUND, and a suspiciously tidy 3 metres would round-trip through
      // any encoder that quietly went via millimetres.
      'riseAllowance': (doc, id) => SetEntityPropertyCommand<Location, Len?>(
        id: id,
        field: LocationField.riseAllowance,
        from: doc.locations[id]!.riseAllowance,
        to: const Len(2_743_200_001),
        now: _later,
        actor: 'tester',
      ),
      'estimatedRunLengthFromRack': (doc, id) =>
          SetEntityPropertyCommand<Location, Len?>(
            id: id,
            field: LocationField.estimatedRunLengthFromRack,
            from: doc.locations[id]!.estimatedRunLengthFromRack,
            to: Len.fromMillimetres(21000),
            now: _later,
            actor: 'tester',
          ),
    };
