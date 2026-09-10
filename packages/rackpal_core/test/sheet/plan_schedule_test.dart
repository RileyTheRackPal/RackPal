// PLAN-H/5: the Floor Plan Device Schedule (docs/15 §8, DR-152 §11.151).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASES ARE THE TWO DEAD ENDS
// ═══════════════════════════════════════════════════════════════════════
// A schedule under a plan has exactly two ways to fail its reader, and
// both are about a reference that goes nowhere: a callout on the drawing
// with no row beneath it, and a row whose reference is not the string on
// the drawing. Everything else here is layout arithmetic.
//
// The second is why the reference column is `planPinLabelsFor`'s output
// rather than a second resolution: two spellings of one designator is a
// dead end that looks like a table.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

const _ul = Uuid('ul-1');

PlanUnderlay _underlay() => PlanUnderlay(
  id: _ul,
  name: 'Level 1',
  imageMember: 'underlays/ul-1.png',
  format: PlanImageFormat.png,
  pixelWidth: 2000,
  pixelHeight: 1500,
  contentHash: 'sha256:ul',
  order: const FracIndex('a0'),
  meta: testMeta(),
);

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-plan-sched'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: testMeta(),
  );
  doc.underlays[_ul] = _underlay();
  return doc;
}

PlanPin _pin(int x, int y) => PlanPin(underlayId: _ul, at: PxPt(x, y));

Uuid _room(RackDocument doc, String key, String name) {
  final id = Uuid(key);
  doc.locations[id] = Location(
    id: id,
    kind: LocationKind.room,
    name: name,
    code: 'RM',
    order: const FracIndex('a0'),
    meta: testMeta(),
  );
  return id;
}

void _addRack(RackDocument doc, {PlanPin? pin, Uuid? locationId}) {
  doc.racks[const Uuid('rk')] = Rack(
    id: const Uuid('rk'),
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: testMeta(),
    locationId: locationId,
    planPin: pin,
  );
}

void _addOutlet(
  RackDocument doc,
  String key,
  String designation, {
  PlanPin? pin,
  Uuid? locationId,
  int gangs = 0,
}) {
  doc.outlets[Uuid(key)] = Outlet(
    id: Uuid(key),
    structureBodyId: const Uuid('body-1'),
    designation: designation,
    order: const FracIndex('a0'),
    meta: testMeta(),
    locationId: locationId,
    planPin: pin,
    gangs: [for (var i = 0; i < gangs; i++) Gang()],
  );
}

List<PlanScheduleRow> _rows(RackDocument doc) =>
    planScheduleFor(doc, _ul, equipment: buildEquipmentList(doc));

void main() {
  group('every callout resolves', () {
    /// LOAD-BEARING. DR-152 §11.151.3.
    test('the RACK has a row, because it is the thing a stranger looks for '
        'first', () {
      final doc = _doc();
      final room = _room(doc, 'loc-eq', 'Equipment Room');
      _addRack(doc, pin: _pin(10, 10), locationId: room);

      final rows = _rows(doc);
      expect(rows, hasLength(1));
      expect(rows.single.reference, 'RK-1');
      expect(rows.single.item, 'Rack');
      expect(rows.single.areaName, 'Equipment Room');
      expect(rows.single.description, contains('42U'));
    });

    /// LOAD-BEARING. The reference column IS the callout's string.
    test('every reference on the plan appears in the table, spelled the '
        'same way', () {
      final doc = _doc();
      final room = _room(doc, 'loc-gr', 'Great Room');
      _addRack(doc, pin: _pin(10, 10), locationId: room);
      _addOutlet(doc, 'o1', 'WP-1', pin: _pin(20, 20), locationId: room);
      _addOutlet(doc, 'o2', 'WP-2', pin: _pin(30, 30), locationId: room);

      final pins = planPinsFor(doc, _ul);
      final callouts = planPinLabelsFor(doc, pins).values.toSet();
      final referenced = _rows(doc).map((r) => r.reference).toSet();

      expect(referenced, callouts, reason: 'no pill without a row');
      expect(callouts, hasLength(3));
    });

    test('a carrier with no designator has neither a callout nor a row', () {
      final doc = _doc();
      final room = _room(doc, 'loc-gr', 'Great Room');
      _addOutlet(doc, 'blank', '   ', pin: _pin(20, 20), locationId: room);

      expect(planPinLabelsFor(doc, planPinsFor(doc, _ul)), isEmpty);
      expect(_rows(doc), isEmpty);
    });

    test("a pin on ANOTHER underlay is not in this plan's table", () {
      final doc = _doc();
      final room = _room(doc, 'loc-gr', 'Great Room');
      _addOutlet(
        doc,
        'o1',
        'WP-9',
        pin: const PlanPin(underlayId: Uuid('ul-2'), at: PxPt(5, 5)),
        locationId: room,
      );
      expect(_rows(doc), isEmpty);
    });
  });

  group('what each column says', () {
    test('an outlet is described by its plate, from computePlateFill', () {
      final doc = _doc();
      final room = _room(doc, 'loc-gr', 'Great Room');
      _addOutlet(
        doc,
        'o1',
        'WP-1',
        pin: _pin(20, 20),
        locationId: room,
        gangs: 2,
      );

      final row = _rows(doc).single;
      expect(row.item, 'Outlet');
      expect(row.description, contains('2-gang'));
    });

    /// G4: an unstated room is an unknown, never the underlay's name.
    test('a carrier with no location prints the unknown token', () {
      final doc = _doc();
      _addOutlet(doc, 'o1', 'WP-1', pin: _pin(20, 20));

      expect(_rows(doc).single.areaName, kPlanScheduleUnknown);
      expect(
        _rows(doc).single.areaName,
        isNot('Level 1'),
        reason: "the underlay's name is not the carrier's room",
      );
    });

    /// G4: a room whose name is blank is still an unknown room.
    test('a blank room name reads as unknown, not as an empty column', () {
      final doc = _doc();
      final blank = _room(doc, 'loc-blank', '   ');
      _addOutlet(doc, 'o1', 'WP-1', pin: _pin(20, 20), locationId: blank);

      expect(_rows(doc).single.areaName, kPlanScheduleUnknown);
    });
  });

  group('the order is total', () {
    test('area, then reference, then id; and two builds agree', () {
      final doc = _doc();
      final att = _room(doc, 'loc-at', 'Attic');
      final gr = _room(doc, 'loc-gr', 'Great Room');
      _addOutlet(doc, 'o3', 'WP-3', pin: _pin(30, 30), locationId: gr);
      _addOutlet(doc, 'o1', 'WP-1', pin: _pin(10, 10), locationId: gr);
      _addOutlet(doc, 'o2', 'WP-2', pin: _pin(20, 20), locationId: att);

      final rows = _rows(doc);
      expect(
        rows.map((r) => '${r.areaName}/${r.reference}'),
        orderedEquals([
          'Attic/WP-2',
          'Great Room/WP-1',
          'Great Room/WP-3',
        ]),
      );
      expect(
        _rows(doc).map((r) => r.reference),
        orderedEquals(rows.map((r) => r.reference)),
      );
    });

    /// LOAD-BEARING for §8.4. Nothing forbids two drops sharing a
    /// designation, and `List.sort` is not stable, so the id is what makes
    /// two exports of one document byte for byte identical.
    ///
    /// FORTY OF THEM, AND THE COUNT IS THE WHOLE TEST. Dart sorts a list
    /// shorter than about thirty-three by insertion, which happens to
    /// preserve order, and longer ones by a dual-pivot quicksort, which
    /// does not: measured here, deleting the id tiebreak leaves ten rows
    /// untouched and reorders forty. A two-row case would have passed
    /// against a comparator with no tiebreak at all.
    test('forty carriers sharing an area and a reference still order', () {
      final doc = _doc();
      final gr = _room(doc, 'loc-gr', 'Great Room');
      for (var i = 0; i < 40; i++) {
        _addOutlet(
          doc,
          'o${i.toString().padLeft(3, '0')}',
          'WP-1',
          pin: _pin(i, i),
          locationId: gr,
        );
      }

      expect(
        _rows(doc).map((r) => r.entityId.v),
        orderedEquals(<String>[
          for (var i = 0; i < 40; i++) 'o${i.toString().padLeft(3, '0')}',
        ]),
      );
    });
  });

  group('the band under the plan', () {
    PlanScheduleBand band(int rowCount, {DBox? area}) => buildPlanScheduleBand(
      rows: [
        for (var i = 0; i < rowCount; i++)
          PlanScheduleRow(
            entityId: Uuid('e${i.toString().padLeft(3, '0')}'),
            areaName: 'Great Room',
            reference: 'WP-$i',
            item: 'Outlet',
            description: '2-gang · 1 drop',
          ),
      ],
      // The measured drawing area of a real `T1.01`.
      area: area ?? const DBox.fromLtwh(51, 30, 1122, 567),
      measurer: FakeMeasurer(),
    );

    test('an empty plan gets no band at all, not an empty heading', () {
      final b = band(0);
      expect(b.ops, isEmpty);
      expect(b.height, 0);
    });

    /// LOAD-BEARING. DR-152 §11.151.4: a single column cannot print the
    /// exit criterion's own scenario.
    test('sixty rows fit, and leave the plan more than half the sheet', () {
      final b = band(60);

      expect(b.shown, 60);
      expect(b.omitted, 0, reason: 'every drop of a real rough-in');
      expect(
        b.height,
        lessThan(567 * 0.5),
        reason: 'one column would have needed 734 pt of a 567 pt area',
      );
    });

    /// LOAD-BEARING. The cap is a number DR-152 turns on, and its first
    /// draft said 180 when the layout held 60. It is pinned here rather
    /// than described in a comment.
    test('the cap on a real T1.01 is eighty rows, and the 81st is counted', () {
      expect(band(80).omitted, 0, reason: 'four blocks of twenty');
      expect(band(81).shown, 80);
      expect(band(81).omitted, 1);
    });

    test('a small plan gives the band only what it needs', () {
      expect(band(6).height, lessThan(band(60).height));
    });

    test('every block carries its own headers', () {
      // A reader scanning the third block across does not look back at the
      // first to find out which field they are in.
      final texts = textsOf(band(60).ops);
      for (final header in kPlanScheduleHeaders) {
        expect(
          texts.where((t) => t == header).length,
          greaterThan(1),
          reason: '$header appears once per block',
        );
      }
    });

    /// LOAD-BEARING. G4: a table quietly shorter than the drawing above it
    /// is the dead end this schedule exists to close.
    test('past the cap it prints what fits and SAYS how many it did not', () {
      // A deliberately tiny area, since no real document reaches the cap.
      final b = band(40, area: const DBox.fromLtwh(51, 30, 320, 120));

      expect(b.omitted, greaterThan(0));
      expect(b.shown + b.omitted, 40);
      expect(
        textsOf(b.ops).first,
        contains('OF 40 SHOWN'),
        reason: 'the count is on the sheet, not only in a notice',
      );
    });

    /// LOAD-BEARING. `shown` is a claim about the sheet, so count the sheet.
    test('every row it claims to show is actually drawn', () {
      for (final count in <int>[4, 10, 60]) {
        final b = band(count);
        final texts = textsOf(b.ops);
        expect(b.shown, count);
        for (var i = 0; i < count; i++) {
          expect(
            texts.where((t) => t == 'WP-$i').length,
            1,
            reason: 'WP-$i is missing from a band of $count',
          );
        }
      }
    });

    test('a block with nothing left to print is never opened', () {
      // Five rows over four blocks fill three, and the fourth would be a
      // set of headers over no rows.
      expect(textsOf(band(5).ops).where((t) => t == 'AREA').length, 3);
    });

    test(
      'an area too short for even one row still prints one, and says so',
      () {
        final b = band(5, area: const DBox.fromLtwh(51, 30, 320, 40));
        expect(b.shown, 1, reason: 'a band that shows nothing is a blank form');
        expect(b.omitted, 4);
      },
    );

    /// The house rule the rest of the sheet furniture keeps.
    test('no empty text op ever reaches the scene', () {
      for (final b in <PlanScheduleBand>[
        band(10),
        band(60),
        band(40, area: const DBox.fromLtwh(51, 30, 320, 120)),
        // Fields narrower than a single ellipsis.
        band(4, area: const DBox.fromLtwh(51, 30, 24, 120)),
      ]) {
        expect(textsOf(b.ops), everyElement(isNotEmpty));
      }
    });

    /// LOAD-BEARING for four blocks across: a cell that overran its field
    /// would print on top of the AREA of the block beside it.
    test('a long description is truncated to its own column', () {
      final long = 'AUDIO DROP ' * 40;
      final b = buildPlanScheduleBand(
        rows: [
          PlanScheduleRow(
            entityId: const Uuid('e0'),
            areaName: 'Great Room',
            reference: 'WP-1',
            item: 'Outlet',
            description: long,
          ),
        ],
        area: const DBox.fromLtwh(51, 30, 1122, 567),
        measurer: FakeMeasurer(),
      );

      const style = TextStyleSpec(
        font: kSheetFont,
        sizePt: kSchedulePt,
        argb: 0xFF000000,
        anchor: TextAnchor.midLeft,
      );
      // The measured layout of a real `T1.01`: four blocks of 270 pt.
      // Written out rather than recomputed from the constants, which would
      // agree with the implementation whichever direction it is wrong in.
      const blockWidth = 270.0;
      final field = blockWidth * kPlanScheduleFieldShares.last;
      final drawn = textsOf(b.ops).last;

      expect(drawn, isNot(long));
      expect(
        FakeMeasurer().measureText(drawn, style).advanceWidth,
        lessThanOrEqualTo(field - kPlanScheduleCellPadPt),
      );
    });

    test('and says nothing when nothing was omitted', () {
      expect(textsOf(band(10).ops).first, kPlanScheduleTitle);
    });
  });
}
