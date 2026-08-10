// Creating, editing and deleting a `Pathway`. Board M3-E/4 (#591),
// CR-016.
//
// THE PREMISE THIS FILE EXISTS TO CLOSE: nothing in the product created a
// `Pathway`. The entity shipped at M0, round-trips through the codec, and
// is read by the schedule, the Structure editor and the matrix; the only
// writers of `doc.pathways` were `RemoveLocationCommand` clearing the two
// location references during DR-021's cascade. So `Link.pathwayId` could
// never point at anything real.
//
// The delete is the interesting half and it is NOT a cascade. Nothing
// lives inside a pathway, so no other entity is destroyed; what happens
// is that runs through it go back to having no recorded route, and the
// reference is CLEARED rather than left dangling, because a dangling
// `pathwayId` prints a `PATH` cell identical to "nobody said" (G4).
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 9);
final _later = DateTime.utc(2026, 8, 10);
const _codec = JsonDocumentCodec();

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-pathway'),
  appVersion: 'test',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

Uuid _link(RackDocument doc, String designator, {Uuid? pathwayId}) {
  final id = Uuid('link-$designator');
  doc.links[id] = Link(
    id: id,
    designator: designator,
    media: const MediaTypeId('media.cat6'),
    order: FracIndex('a$designator'),
    meta: _meta(),
    pathwayId: pathwayId,
    conductors: [
      const Conductor(
        from: PlaceEndpoint(description: 'drop'),
        to: OpenEndpoint('coil'),
      ),
    ],
  );
  return id;
}

AddPathwayCommand _add(RackDocument doc, String name, {PathwayKind? kind}) =>
    AddPathwayCommand(
      name: name,
      order: nextPathwayOrder(doc),
      now: _when,
      actor: 'tester',
      kind: kind ?? PathwayKind.conduit,
    );

void main() {
  group('creating one', () {
    test('a pathway reaches the document and undo takes it away', () {
      final doc = _doc();
      final cmd = _add(doc, 'PW-LR-1')..apply(doc);

      expect(doc.pathways[cmd.id]!.name, 'PW-LR-1');
      expect(doc.pathways[cmd.id]!.kind, PathwayKind.conduit);

      cmd.revert(doc);
      expect(doc.pathways, isEmpty);
    });

    test('the id is minted in the CONSTRUCTOR, so redo recreates the same '
        'pathway', () {
      // The `Command` contract. If `apply` minted it, a redo would build a
      // different pathway and any `Link.pathwayId` set on top of the first
      // one would resolve to nothing.
      final doc = _doc();
      final cmd = _add(doc, 'PW-LR-1');
      final id = cmd.id;

      cmd
        ..apply(doc)
        ..revert(doc)
        ..apply(doc);

      expect(doc.pathways.keys, [id]);
    });

    test('orders are allocated and stay distinct', () {
      final doc = _doc();
      final first = _add(doc, 'PW-1')..apply(doc);
      final second = _add(doc, 'PW-2')..apply(doc);

      expect(
        doc.pathways[first.id]!.order.v == doc.pathways[second.id]!.order.v,
        isFalse,
        reason: 'a shared order makes the list order depend on map iteration',
      );
    });

    test('a nominal length nobody has measured stays NULL (G4)', () {
      final doc = _doc();
      final cmd = _add(doc, 'PW-1')..apply(doc);
      expect(doc.pathways[cmd.id]!.nominalLength, isNull);
    });

    test('and the whole thing round-trips byte-identically (CR-117)', () {
      final doc = _doc();
      final before = _codec.write(doc);
      final cmd = _add(doc, 'PW-LR-1', kind: PathwayKind.attic)..apply(doc);
      expect(_codec.write(doc), isNot(orderedEquals(before)));

      cmd.revert(doc);
      expect(_codec.write(doc), orderedEquals(before));
    });
  });

  group('editing one through the accessor table', () {
    test('kind and containsLineVoltage are settable, which is what M5 '
        'needs', () {
      // #156's whole insistence: `CODE-001` and `CODE-002` read these, so
      // the facts have to be enterable and trustworthy before M5 exists.
      // NO RULE IS IMPLEMENTED HERE (canon §5).
      final doc = _doc();
      final cmd = _add(doc, 'PW-1')..apply(doc);

      buildSetEntityProperty(
        doc: doc,
        id: cmd.id,
        field: PathwayField.kind,
        to: PathwayKind.plenumSpace,
        now: _later,
        actor: 'tester',
      )!.apply(doc);
      buildSetEntityProperty(
        doc: doc,
        id: cmd.id,
        field: PathwayField.containsLineVoltage,
        to: true,
        now: _later,
        actor: 'tester',
      )!.apply(doc);

      expect(doc.pathways[cmd.id]!.kind, PathwayKind.plenumSpace);
      expect(doc.pathways[cmd.id]!.containsLineVoltage, isTrue);
    });

    test('an edit reverts byte-identically (CR-117)', () {
      final doc = _doc();
      final cmd = _add(doc, 'PW-1')..apply(doc);
      final before = _codec.write(doc);

      final edit = buildSetEntityProperty(
        doc: doc,
        id: cmd.id,
        field: PathwayField.nominalLength,
        to: const Len(30 * 1000 * Len.nmPerMillimetre),
        now: _later,
        actor: 'tester',
      )!..apply(doc);
      expect(_codec.write(doc), isNot(orderedEquals(before)));

      edit.revert(doc);
      expect(_codec.write(doc), orderedEquals(before));
    });

    test('the two location references are NOT in the table', () {
      // DR-021 owns them: `RemoveLocationCommand` clears both so nothing
      // dangles, and a table row would be a second writer on the one
      // field whose invariant lives in exactly one place.
      expect(
        PathwayField.all.map((f) => f.key),
        isNot(anyElement(anyOf('fromLocationId', 'toLocationId'))),
      );
    });
  });

  group('deleting one', () {
    test('a run through it keeps its cable and loses its route', () {
      // NOT a cascade. The link survives; what it loses is a recorded
      // route, which is the state every drop in this product was in
      // before this task.
      final doc = _doc();
      final pathway = _add(doc, 'PW-LR-1')..apply(doc);
      final linkId = _link(doc, 'W001', pathwayId: pathway.id);
      final untouched = _link(doc, 'W002');

      RemovePathwayCommand(id: pathway.id, now: _later).apply(doc);

      expect(doc.pathways, isEmpty);
      expect(doc.links[linkId], isNotNull, reason: 'the cable still exists');
      expect(
        doc.links[linkId]!.pathwayId,
        isNull,
        reason:
            'a dangling id prints a PATH cell identical to "nobody '
            'said", so the reference is cleared rather than left (G4)',
      );
      expect(doc.links[untouched]!.pathwayId, isNull);
    });

    test('and undo puts the pathway AND every reference back', () {
      final doc = _doc();
      final pathway = _add(doc, 'PW-LR-1')..apply(doc);
      final a = _link(doc, 'W001', pathwayId: pathway.id);
      final b = _link(doc, 'W002', pathwayId: pathway.id);

      final remove = RemovePathwayCommand(id: pathway.id, now: _later)
        ..apply(doc);
      expect(doc.links[a]!.pathwayId, isNull);

      remove.revert(doc);
      expect(doc.pathways[pathway.id]!.name, 'PW-LR-1');
      expect(doc.links[a]!.pathwayId, pathway.id);
      expect(doc.links[b]!.pathwayId, pathway.id);
    });

    test('it declares wires, where creating one does not', () {
      // The asymmetry is real: creating a pathway changes no cable, and
      // deleting one rewrites `Link.pathwayId` on every run through it.
      final doc = _doc();
      final add = _add(doc, 'PW-1');
      expect(add.touches.has(EpochMask.wires), isFalse);
      expect(
        RemovePathwayCommand(id: add.id, now: _later).touches.has(
          EpochMask.wires,
        ),
        isTrue,
      );
    });
  });
}
