// The `[ Pathways ]` tab's derivation. Board M3-E/1 (#156), docs/07 §4.
//
// THE TWO THINGS ASSERTED HERE ARE THE TWO A `Pathway` CANNOT ANSWER
// ALONE: the run count, which needs a pass over `doc.links`, and the
// order, which has to be total because two pathways can share a
// `FracIndex` and map iteration is not an ordering (§8.4).
//
// The cell strings are asserted as ARTIFACTS — what a person reads in the
// column — rather than by re-deriving them from the model, which is the
// house rule that catches a table printing `0` for a length nobody
// measured.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 9);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-pathway-table'),
  appVersion: 'test',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

Pathway _pathway(
  RackDocument doc,
  String id,
  String name, {
  required String order,
  PathwayKind kind = PathwayKind.conduit,
  bool containsLineVoltage = false,
  Len? nominalLength,
  MediaTypeId? pathwayMedia,
  String? notes,
}) {
  final pathway = Pathway(
    id: Uuid(id),
    name: name,
    order: FracIndex(order),
    meta: _meta(),
    kind: kind,
    containsLineVoltage: containsLineVoltage,
    nominalLength: nominalLength,
    pathwayMedia: pathwayMedia,
    notes: notes,
  );
  doc.pathways[pathway.id] = pathway;
  return pathway;
}

void _link(RackDocument doc, String designator, {Uuid? pathwayId}) {
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
}

String _cell(PathwayTableRow row, PathwayColumnId id) =>
    pathwayCell(row, id, units: UnitSystem.imperial);

void main() {
  group('buildPathwayTable', () {
    test('an empty document has no rows and no unknowns to report', () {
      final table = buildPathwayTable(_doc());
      expect(table.isEmpty, isTrue);
      expect(table.unknownLengthCount, 0);
      expect(table.unroutedRunCount, 0);
    });

    test('counts the runs through each pathway, and the ones through none', () {
      final doc = _doc();
      _pathway(doc, 'pth-a', 'Living Room ENT', order: 'a');
      _pathway(doc, 'pth-b', 'Kitchen EMT', order: 'b');
      _link(doc, 'W1', pathwayId: const Uuid('pth-a'));
      _link(doc, 'W2', pathwayId: const Uuid('pth-a'));
      _link(doc, 'W3', pathwayId: const Uuid('pth-b'));
      _link(doc, 'W4');
      _link(doc, 'W5');

      final table = buildPathwayTable(doc);
      expect(table.rows.map((r) => r.runCount), [2, 1]);
      expect(table.unroutedRunCount, 2);
    });

    test('a pathway nothing runs through prints 0, never the dash', () {
      // DR-032's ordinary case: `Office: 1x ENT` builds a pathway and no
      // cable at all. `0` is a measured fact about the document and the
      // dash would say nobody had looked (G4).
      final doc = _doc();
      _pathway(doc, 'pth-a', 'Office ENT', order: 'a');
      final row = buildPathwayTable(doc).rows.single;
      expect(row.runCount, 0);
      expect(_cell(row, PathwayColumnId.runs), '0');
    });

    test('orders by FracIndex, and breaks a tie on the id', () {
      // The planner allocated two pathways the same order before
      // `b093062`. A comparator returning 0 here would leave the list to
      // map iteration, so the tie-break is the assertion.
      final doc = _doc();
      _pathway(doc, 'pth-z', 'second', order: 'm');
      _pathway(doc, 'pth-a', 'first', order: 'm');
      _pathway(doc, 'pth-m', 'earlier', order: 'c');

      expect(buildPathwayTable(doc).rows.map((r) => r.name), [
        'earlier',
        'first',
        'second',
      ]);
    });

    test('counts the pathways nobody has measured', () {
      final doc = _doc();
      _pathway(
        doc,
        'pth-a',
        'measured',
        order: 'a',
        nominalLength: const Len(Len.nmPerInch * 12 * 40),
      );
      _pathway(doc, 'pth-b', 'unmeasured', order: 'b');
      _pathway(doc, 'pth-c', 'also unmeasured', order: 'c');

      expect(buildPathwayTable(doc).unknownLengthCount, 2);
    });
  });

  group('pathwayCell', () {
    test('an unmeasured length prints the dash and never a zero', () {
      final doc = _doc();
      _pathway(doc, 'pth-a', 'Living Room ENT', order: 'a');
      final row = buildPathwayTable(doc).rows.single;
      expect(_cell(row, PathwayColumnId.nominalLength), kUnknownCell);
    });

    test('a measured zero prints 0', () {
      final doc = _doc();
      _pathway(doc, 'pth-a', 'stub', order: 'a', nominalLength: const Len(0));
      final row = buildPathwayTable(doc).rows.single;
      expect(_cell(row, PathwayColumnId.nominalLength), '0');
    });

    test('kind prints DR-031 two new values in full', () {
      final doc = _doc();
      _pathway(doc, 'pth-a', 'attic run', order: 'a', kind: PathwayKind.attic);
      _pathway(
        doc,
        'pth-b',
        'under the house',
        order: 'b',
        kind: PathwayKind.crawlspace,
      );
      final rows = buildPathwayTable(doc).rows;
      expect(_cell(rows[0], PathwayColumnId.kind), 'ATTIC');
      expect(_cell(rows[1], PathwayColumnId.kind), 'CRAWLSPACE');
    });

    test('line voltage says YES or NO, and never leaves the cell blank', () {
      // The app reads this cell back to decide the value, so `false` and
      // "nothing rendered" must not be the same string.
      final doc = _doc();
      _pathway(doc, 'pth-a', 'shared', order: 'a', containsLineVoltage: true);
      _pathway(doc, 'pth-b', 'clean', order: 'b');
      final rows = buildPathwayTable(doc).rows;
      expect(_cell(rows[0], PathwayColumnId.lineVoltage), kLineVoltageYesCell);
      expect(_cell(rows[1], PathwayColumnId.lineVoltage), kLineVoltageNoCell);
    });

    test('media prints the registry name, and a dangling id prints itself', () {
      final doc = _doc();
      doc.registries.mediaTypes[const MediaTypeId(
        'media.conduit_ent',
      )] = const MediaTypeDef(
        id: MediaTypeId('media.conduit_ent'),
        displayName: 'ENT / smurf tube',
        isPathwayOnly: true,
      );
      _pathway(
        doc,
        'pth-a',
        'known',
        order: 'a',
        pathwayMedia: const MediaTypeId('media.conduit_ent'),
      );
      _pathway(
        doc,
        'pth-b',
        'dangling',
        order: 'b',
        pathwayMedia: const MediaTypeId('media.gone'),
      );
      _pathway(doc, 'pth-c', 'unsaid', order: 'c');

      final rows = buildPathwayTable(doc).rows;
      expect(_cell(rows[0], PathwayColumnId.media), 'ENT / smurf tube');
      // The record of what was written survives the registry entry (G4,
      // and `jacketColorCell`'s holding).
      expect(_cell(rows[1], PathwayColumnId.media), 'media.gone');
      expect(_cell(rows[2], PathwayColumnId.media), kUnknownCell);
    });

    test('an empty name or note is unknown, never a blank cell', () {
      final doc = _doc();
      _pathway(doc, 'pth-a', '   ', order: 'a', notes: '  ');
      final row = buildPathwayTable(doc).rows.single;
      expect(_cell(row, PathwayColumnId.name), kUnknownCell);
      expect(_cell(row, PathwayColumnId.notes), kUnknownCell);
    });

    test('every column has a header and a width', () {
      for (final id in PathwayColumnId.values) {
        expect(pathwayColumnHeader(id), isNotEmpty);
        expect(pathwayColumnWidth(id), greaterThan(0));
      }
    });
  });
}
