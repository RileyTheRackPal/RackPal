// CR-113, multiple Structure instances in one project (M3-E/3, #158).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS FILE IS THE AUDIT THE TASK ASKED FOR, AND IT WAS WRITTEN FIRST
// ═══════════════════════════════════════════════════════════════════════
// #158's own instruction: "Find the assumptions before adding the second
// instance, or the second instance finds them." So this pins what holds
// on a two-body document BEFORE anything is changed to accommodate one,
// which is the only ordering in which the answers are trustworthy: a
// test written after the fix asserts the fix, and a test written before
// it asserts the tree.
//
// WHAT THE AUDIT FOUND, in the order the task named its worries:
//
//   * THE PULL SHEET'S SORT — fine, and fine for a reason rather than by
//     luck. It sorts room then pathway and has no Structure term, which
//     is correct: an installer walks the building, not the panel, and
//     the far end already names which panel a run lands in.
//   * THE ROLLUP'S SCOPE — fine. It is project-wide over every row,
//     which is what "how much Cat6 to order" means. A per-body rollup
//     would be the wrong number for a purchase order.
//   * THE LOCATIONS TREE'S ROOTS — untouched. Locations are not per
//     Structure body and never were; a room belongs to the building.
//   * CR-072 LAYERING — handled, per device. `_anchorFor` reads each
//     body's own `sheetEdge`, so N bodies land on N anchors rather than
//     one.
//   * CR-113 LABEL UNIQUENESS — enforced project-wide already, because
//     `usedFieldLabels` scans `doc.links` rather than one body's.
//
// The two that were NOT fine are the subject of the rest of this task,
// and both are asserted here so the fix has something to move:
// `buildStructureTable` merged both bodies when given no id, and three
// planners refused permanently because nothing could tell them which
// body to use.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 10);
const _actor = 'rriley';

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: _actor);

int _seq = 0;
Uuid _mint(String tag) => Uuid('0190e3c1-0000-7000-8000-$tag${_seq++}');

RackDocument _project() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-0000000158aa'),
  appVersion: '0.1.0+build.1',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
  info: ProjectInfo(projectName: 'Two panels'),
)..registries = buildSeedRegistries();

/// One Structure device plus its body, through the real command.
({Uuid bodyId, Uuid deviceId}) _structure(
  RackDocument doc,
  String designator,
  String title, {
  SheetEdge sheetEdge = SheetEdge.left,
}) {
  final command = AddStructureCommand(
    title: title,
    designator: designator,
    sheetEdge: sheetEdge,
    now: _when,
    actor: _actor,
  )..apply(doc);
  return (bodyId: command.bodyId, deviceId: command.deviceId);
}

Uuid _room(RackDocument doc, String name) {
  final id = _mint('room');
  doc.locations[id] = Location(
    id: id,
    kind: LocationKind.room,
    name: name,
    code: 'RM',
    order: FracIndex('a$_seq'),
    meta: _meta(),
  );
  return id;
}

Uuid _drop(
  RackDocument doc, {
  required String designator,
  required Uuid bodyId,
  required Uuid locationId,
  Len? cutLength,
}) {
  final id = _mint('link');
  doc.links[id] = Link(
    id: id,
    designator: designator,
    media: const MediaTypeId('media.cat6'),
    order: FracIndex('a${_seq.toString().padLeft(4, '0')}'),
    meta: _meta(),
    cutLength: cutLength,
    conductors: [
      Conductor(
        from: PlaceEndpoint(description: 'drop', locationId: locationId),
        to: const OpenEndpoint('coil'),
      ),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: bodyId,
      outletId: _mint('outlet'),
      fieldLabel: designator,
    ),
  );
  return id;
}

/// A house and a guest house: two panels, two rooms each.
({RackDocument doc, Uuid house, Uuid guest}) _twoPanels() {
  final doc = _project();
  final house = _structure(doc, 'STR-1', 'Media Panel');
  final guest = _structure(doc, 'STR-2', 'Guest House Panel');

  final greatRoom = _room(doc, 'Great Room');
  final guestBed = _room(doc, 'Guest Bedroom');

  _drop(
    doc,
    designator: 'W001',
    bodyId: house.bodyId,
    locationId: greatRoom,
    cutLength: Len.fromMillimetres(15000),
  );
  _drop(doc, designator: 'W002', bodyId: house.bodyId, locationId: greatRoom);
  _drop(
    doc,
    designator: 'W003',
    bodyId: guest.bodyId,
    locationId: guestBed,
    cutLength: Len.fromMillimetres(9000),
  );
  return (doc: doc, house: house.bodyId, guest: guest.bodyId);
}

/// Every drop designator in a table, across its room bands.
///
/// The table is GROUPED BY ROOM rather than flat, so there is no `rows`
/// to read; flattening here keeps the assertions about which drops are
/// present rather than about how they are banded.
Iterable<String> _designators(StructureTable table) =>
    table.groups.expand((g) => g.rows).map((r) => r.designator);

void main() {
  group('what already holds on two bodies', () {
    test('CR-113: field labels are unique across BOTH bodies, not within '
        'one', () {
      // "Labels get printed on physical cable and must not collide across
      // panels" — the ruling's own words. The scan is over doc.links, so
      // it was already project-wide; this pins that it stays so.
      final t = _twoPanels();
      expect(usedFieldLabels(t.doc), containsAll(['W001', 'W002', 'W003']));

      final refused = buildAddHomeRunCommand(
        doc: t.doc,
        outletId: t.doc.outlets.keys.isEmpty
            ? const Uuid('outlet-none')
            : t.doc.outlets.keys.first,
        // A label the OTHER body already uses.
        fieldLabel: 'W003',
        designator: 'W900',
        netName: 'W900',
        media: const MediaTypeId('media.cat6'),
        fieldEnd: const OpenEndpoint('coil'),
        now: _when,
        actor: _actor,
      );
      expect(refused, isA<AddHomeRunRefused>());
    });

    test('CR-072: each body anchors by ITS OWN sheetEdge, so two bodies '
        'are two anchors', () {
      final doc = _project();
      _structure(doc, 'STR-1', 'Media Panel');
      _structure(doc, 'STR-2', 'Head End', sheetEdge: SheetEdge.right);

      final edges = doc.structures.values.map((b) => b.sheetEdge).toList();
      expect(edges, containsAll([SheetEdge.left, SheetEdge.right]));
      // The anchor is derived per device rather than from a single
      // "the Structure device", which is what makes N bodies work.
      expect(doc.structures.length, 2);
    });

    test('the footage rollup is PROJECT-WIDE, which is the right scope for '
        'a purchase', () {
      // A per-body rollup would be the wrong number to order cable from:
      // one order covers the job, not one panel.
      final t = _twoPanels();
      final footage = buildCableFootage(t.doc);
      final cat6 = footage.lines.firstWhere(
        (l) => l.mediaId == const MediaTypeId('media.cat6'),
      );
      // Two measured runs, one from each body, summed into one figure.
      expect(cat6.footage.knownCount, 2);
      // And the one nobody measured is reported rather than absorbed (G4).
      expect(cat6.footage.unknownCount, 1);
    });

    test('the Pull Sheet sorts room then pathway with NO Structure term, '
        'and both bodies interleave by room', () {
      // Correct rather than an oversight: an installer walks the
      // building, and the far end already names which panel a run lands
      // in. A sheet grouped by panel would send somebody up and down the
      // house twice.
      final t = _twoPanels();
      final rows = scheduleViewOf(
        t.doc,
        preset: SchedulePreset.pullSheet,
        sort: ScheduleSort.roomThenPathway,
      ).rows;

      expect(rows.map((r) => r.designator), hasLength(3));
      expect(
        rows.map((r) => r.roomName),
        orderedEquals(<String?>['Great Room', 'Great Room', 'Guest Bedroom']),
      );
    });

    test('the Locations tree is untouched by how many bodies there are', () {
      final t = _twoPanels();
      // Rooms belong to the building. Neither body owns one, and adding
      // the second changed no root.
      expect(t.doc.locations.length, 2);
      for (final location in t.doc.locations.values) {
        expect(location.parentId, isNull);
      }
    });

    test("the equipment list resolves each body's OWN enclosure model", () {
      final doc = _project();
      final a = _structure(doc, 'STR-1', 'Media Panel');
      final b = _structure(doc, 'STR-2', 'Guest House Panel');
      doc.structures[a.bodyId]!.enclosureModel = 'Generic 42 in';
      doc.structures[b.bodyId]!.enclosureModel = 'Generic 28 in';

      final models = buildEquipmentList(
        doc,
      ).rows.where((r) => r.model != null).map((r) => r.model).toSet();
      expect(models, containsAll(['Generic 42 in', 'Generic 28 in']));
    });

    test('THREE PLANNERS REFUSE, and each names #158 as what retires it', () {
      // Refused rather than guessed, which is right: filing sixty drops
      // on the wrong Structure body puts them on the wrong sheet. What
      // was wrong is that nothing could NAME a body, so the refusals had
      // no way out and a two-panel project could never create anything
      // again. Each refusal cites the board item that fixes it, which is
      // `a test that asserts an absence names its due date` applied to a
      // production message.
      final t = _twoPanels();

      final matrix = planMatrixCell(
        doc: t.doc,
        locationId: t.doc.locations.keys.first,
        media: const MediaTypeId('media.cat6'),
        // FOUR, not two. The Great Room already holds two Cat6 drops, so
        // a target of two returns `Unchanged` BEFORE the planner ever
        // reaches its structure check, and the assertion would have
        // passed for a reason that has nothing to do with two bodies.
        targetCount: 4,
        now: _when,
        actor: _actor,
      );
      expect(matrix, isA<MatrixCellRefused>());

      final outlet = planOutletFromTemplate(
        doc: t.doc,
        template: t.doc.registries.outletTemplates.values.first,
        locationId: t.doc.locations.keys.first,
        now: _when,
        actor: _actor,
      );
      expect(outlet, isA<OutletTemplatePlanRefused>());
    });
  });

  group('what did NOT hold, and is what this task fixes', () {
    test('buildStructureTable filters to the body it is given', () {
      final t = _twoPanels();

      final house = buildStructureTable(t.doc, structureBodyId: t.house);
      final guest = buildStructureTable(t.doc, structureBodyId: t.guest);

      expect(_designators(house), unorderedEquals(<String>['W001', 'W002']));
      expect(_designators(guest), <String>['W003']);
    });

    test('WITH NO BODY NAMED IT MERGES BOTH, which is what the editor did '
        'because nothing ever named one', () {
      // Pinned as the state this task inherits rather than as desired
      // behaviour. The builder's contract is fine: null means "do not
      // filter". What was wrong is that the EDITOR passed null forever,
      // so two panels' drops arrived in one undifferentiated table while
      // the header said "2 Structure devices". The picker is what
      // retires that, and this assertion documents why it had to.
      final t = _twoPanels();
      final merged = buildStructureTable(t.doc);
      expect(
        _designators(merged),
        unorderedEquals(<String>['W001', 'W002', 'W003']),
      );
    });
  });

  group('naming a body is what retires the refusals', () {
    test('the bodies have a TOTAL order, by designator then id', () {
      // `StructureBody` carries no `order` field, so the picker's list
      // has to be derived. By the designator a person already reads, and
      // ending in the id because two devices may share one.
      final t = _twoPanels();
      final ordered = structureBodiesInOrder(t.doc);
      expect(ordered.map((b) => t.doc.devices[b.deviceId]!.designator), [
        'STR-1',
        'STR-2',
      ]);
      expect(defaultStructureBody(t.doc)!.id, ordered.first.id);
    });

    test('the order does not depend on insertion order', () {
      final doc = _project();
      // Created out of designator order on purpose: a builder that
      // preserved insertion would pass this by coincidence otherwise.
      _structure(doc, 'STR-2', 'Guest House Panel');
      _structure(doc, 'STR-1', 'Media Panel');
      expect(
        structureBodiesInOrder(
          doc,
        ).map((b) => doc.devices[b.deviceId]!.designator),
        ['STR-1', 'STR-2'],
      );
    });

    test('planOutletFromTemplate ACCEPTS a named body and builds on it', () {
      final t = _twoPanels();
      final plan = planOutletFromTemplate(
        doc: t.doc,
        template: t.doc.registries.outletTemplates.values.first,
        locationId: t.doc.locations.keys.first,
        structureBodyId: t.guest,
        now: _when,
        actor: _actor,
      );
      expect(plan, isA<OutletTemplatePlanReady>());

      // The artifact, not the mechanism: apply it and read which body the
      // outlet actually landed on.
      for (final c in (plan as OutletTemplatePlanReady).commands) {
        c.apply(t.doc);
      }
      expect(
        t.doc.outlets.values.map((o) => o.structureBodyId),
        everyElement(t.guest),
      );
    });

    test('planDropLine ACCEPTS a named body, and files the drops on it', () {
      final t = _twoPanels();
      final parsed = parseDropLine('Guest Bedroom: 2x Cat6');
      expect(parsed, isA<DropLineParsed>());

      final plan = planDropLine(
        doc: t.doc,
        line: parsed as DropLineParsed,
        structureBodyId: t.guest,
        now: _when,
        actor: _actor,
      );
      expect(plan, isA<DropLinePlanReady>());

      for (final c in (plan as DropLinePlanReady).commands) {
        c.apply(t.doc);
      }
      final created = t.doc.outlets.values.where(
        (o) => o.structureBodyId == t.guest,
      );
      expect(created, isNotEmpty);
    });

    test('a body that is not in the project is REFUSED by name', () {
      // The narrower refusal that survives. A stale id in a picker after
      // somebody deleted the panel is an ordinary Tuesday under DR-006's
      // shared-file reality.
      final t = _twoPanels();
      final plan = planOutletFromTemplate(
        doc: t.doc,
        template: t.doc.registries.outletTemplates.values.first,
        locationId: t.doc.locations.keys.first,
        structureBodyId: const Uuid('0190e3c1-0000-7000-8000-00000000gone'),
        now: _when,
        actor: _actor,
      );
      expect(plan, isA<OutletTemplatePlanRefused>());
      expect(
        (plan as OutletTemplatePlanRefused).reason,
        contains('not in this project'),
      );
    });
  });
}
