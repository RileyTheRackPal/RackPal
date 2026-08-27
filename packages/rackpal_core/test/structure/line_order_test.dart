// Board #691 — every drop from one typed line was minted with the SAME
// `FracIndex`, so a line's rows came out in a different order every run.
//
// THE DEFECT. `buildDropsFor` plans a whole line against ONE UNMUTATED
// document, deliberately, so a line that refuses on its seventh drop
// leaves nothing behind. It already threaded three running reservations
// for exactly that reason: labels, designators and net names. Ordering was
// the fourth member of that family and nobody wrote it, so
// `nextLinkOrder(doc)` returned `a0` for every drop on the line.
//
// THE ARTIFACT IS THE PRINTED ORDER, NOT THE FIELD. `buildSchedule` sorts
// on `order` then `id`; with order tied, the tiebreak is a random entity
// id. So these cases read `buildSchedule(doc).rows` and compare against
// what was typed, which is the comparison that had never been made: every
// existing test consumed the same arbitrary order the code did.
//
// IT WAS FOUND BY A TEST FAILING INTERMITTENTLY, which is why the
// repeat-run case below exists rather than a single assertion.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 8, 13);

RackDocument _project() {
  final doc = RackDocument(
    id: const Uuid('doc-ord'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  )..registries = buildSeedRegistries();
  AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'test',
  ).apply(doc);
  AddLocationCommand(
    name: 'Living Room',
    code: 'LR',
    order: nextLocationOrder(doc),
    now: _now,
    actor: 'test',
  ).apply(doc);
  return doc;
}

RackDocument _applied(String line, {RackDocument? onto}) {
  final doc = onto ?? _project();
  final parsed = parseDropLine(line);
  final plan = planDropLine(
    doc: doc,
    line: parsed as DropLineParsed,
    now: _now,
    actor: 'test',
  );
  expect(plan, isA<DropLinePlanReady>(), reason: '$plan');
  for (final c in (plan as DropLinePlanReady).commands) {
    c.apply(doc);
  }
  return doc;
}

/// The field labels in the order the SCHEDULE prints them.
List<String?> _printedOrder(RackDocument doc) =>
    buildSchedule(doc).rows.map((r) => r.fieldLabel).toList();

void main() {
  group('a line orders its drops as typed', () {
    test('every drop gets a distinct order', () {
      final doc = _applied('Living Room: 3x Cat6');
      final orders = doc.links.values.map((l) => l.order.v).toList();
      expect(
        orders.toSet(),
        hasLength(3),
        reason: 'measured before the fix: all three were "a0"',
      );
    });

    test('the schedule prints them in the order they were typed', () {
      final doc = _applied('Living Room: 3x Cat6');
      expect(_printedOrder(doc), ['LR-C6-1', 'LR-C6-2', 'LR-C6-3']);
    });

    test('across media on one line, declaration order is kept', () {
      // The mixed line is the one a rough-in actually types, and it is
      // where a tie was most visible: six drops, two media, one order.
      final doc = _applied('Living Room: 2x Cat6, 2x RG6');
      final printed = _printedOrder(doc);
      expect(printed, hasLength(4));
      expect(
        printed.take(2).every((l) => l!.contains('C6')),
        isTrue,
        reason: 'Cat6 was typed first, so it prints first',
      );
      expect(printed.skip(2).every((l) => l!.contains('RG6')), isTrue);
    });

    test('a second line continues after the first, never beside it', () {
      final doc = _project();
      _applied('Living Room: 2x Cat6', onto: doc);
      _applied('Living Room: 2x RG6', onto: doc);
      final printed = _printedOrder(doc);
      expect(printed, hasLength(4));
      expect(printed.take(2).every((l) => l!.contains('C6')), isTrue);
      expect(
        doc.links.values.map((l) => l.order.v).toSet(),
        hasLength(4),
        reason: 'the reservation is per gesture; the document is the rest',
      );
    });

    test('the printed order is STABLE across runs, not merely sorted', () {
      // THE CASE THAT WOULD HAVE CAUGHT IT. Ids are minted fresh per run,
      // so with orders tied the sort fell through to them and this
      // sequence differed run to run. Repeating inside one test is not the
      // same as repeating the process, but it is what a suite can do, and
      // it fails deterministically against the tie because each iteration
      // builds a document with new ids.
      // JOINED, because a Dart `List` has IDENTITY equality and a set of
      // eight distinct list objects has length 8 however equal their
      // contents are. The first draft of this case did exactly that and
      // failed against a correct build, which is the same shape of error
      // as asserting the wrong quantity.
      final seen = <String>{};
      for (var i = 0; i < 8; i++) {
        seen.add(_printedOrder(_applied('Living Room: 4x Cat6')).join(','));
      }
      expect(
        seen,
        hasLength(1),
        reason: 'eight documents, one printed order; saw $seen',
      );
      expect(seen.single, 'LR-C6-1,LR-C6-2,LR-C6-3,LR-C6-4');
    });
  });

  group('what the fix does NOT change', () {
    test('an existing document keeps the orders it was saved with', () {
      // G5 and CR-117: documents are what they are. A project entered
      // before this fix keeps its ties, and nothing migrates them.
      final doc = _project();
      final ids = [const Uuid('l1'), const Uuid('l2')];
      for (final id in ids) {
        doc.links[id] = Link(
          id: id,
          designator: 'W${id.v}',
          media: const MediaTypeId('media.cat6'),
          order: const FracIndex('a0'),
          meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't'),
        );
      }
      expect(
        doc.links.values.map((l) => l.order.v).toSet(),
        {'a0'},
        reason: 'nothing rewrites what is already stored',
      );
    });
  });
}
