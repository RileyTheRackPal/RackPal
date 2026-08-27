// DR-053 (canon §11.52), board #654 — an outlet is keyed on
// `(locationId, designation)` and a room name matches with its internal
// whitespace collapsed.
//
// THE DEFECT THESE EXIST FOR. `_resolveOutlet` matched on `designation`
// ALONE, project-wide, so `Attic: 2x Cat6 @outlet="WP-1"` typed on a
// project with a Living Room `WP-1` hung the attic's drops on the LIVING
// ROOM's plate. Nothing refused, because as far as the planner was
// concerned the outlet resolved.
//
// ASSERTED AT THE ARTIFACT, WHICH HERE IS "WHICH ROOM DO THESE DROPS
// REPORT". A test that pinned `_resolveOutlet`'s return value would pass
// on a build that resolved correctly and then filed the drops somewhere
// else; what a user sees is the room on the Pull Sheet, so that is what
// these read, through `buildSchedule` on the applied document.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 8, 13);

typedef _Project = ({RackDocument doc, Uuid bodyId});

_Project _project() {
  final doc = RackDocument(
    id: const Uuid('doc-key'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  )..registries = buildSeedRegistries();
  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'test',
  )..apply(doc);
  return (doc: doc, bodyId: structure.bodyId);
}

Uuid _room(RackDocument doc, String name, String code) => (AddLocationCommand(
  name: name,
  code: code,
  order: nextLocationOrder(doc),
  now: _now,
  actor: 'test',
)..apply(doc)).id;

/// An outlet placed directly, so a test can set up the collision without
/// going through the gesture under test.
Uuid _outlet(RackDocument doc, Uuid bodyId, Uuid? roomId, String designation) {
  final add = AddOutletCommand(
    structureBodyId: bodyId,
    designation: designation,
    order: nextOutletOrder(doc),
    now: _now,
    actor: 'test',
    locationId: roomId,
  )..apply(doc);
  return add.id;
}

DropLinePlanReady _planAndApply(RackDocument doc, String line) {
  final parsed = parseDropLine(line);
  expect(parsed, isA<DropLineParsed>(), reason: 'did not parse: $line');
  final plan = planDropLine(
    doc: doc,
    line: parsed as DropLineParsed,
    now: _now,
    actor: 'test',
  );
  expect(plan, isA<DropLinePlanReady>(), reason: 'not ready: $plan');
  final ready = plan as DropLinePlanReady;
  for (final c in ready.commands) {
    c.apply(doc);
  }
  return ready;
}

/// Every room name the schedule reports for the drops on `designation`.
Set<String?> _roomsReportedFor(RackDocument doc, String designation) {
  final rows = buildSchedule(
    doc,
  ).rows.where((e) => e.outletDesignation == designation);
  return {for (final r in rows) r.roomName};
}

void main() {
  group('an outlet is keyed on (locationId, designation)', () {
    test('a same-named plate in another room is NOT joined', () {
      final p = _project();
      final living = _room(p.doc, 'Living Room', 'LR');
      _room(p.doc, 'Attic', 'ATT');
      _outlet(p.doc, p.bodyId, living, 'WP-1');

      _planAndApply(p.doc, 'Attic: 2x Cat6 @outlet="WP-1"');

      // THE ARTIFACT: the drops report the Attic, not the Living Room.
      // Before DR-053 this set was {'Living Room'}.
      expect(_roomsReportedFor(p.doc, 'WP-1'), {'Attic'});
      expect(
        p.doc.outlets.values.where((o) => o.designation == 'WP-1'),
        hasLength(2),
        reason: 'two rooms may each hold a WP-1; that is the point',
      );
    });

    test('a same-named plate in the SAME room IS joined', () {
      final p = _project();
      final living = _room(p.doc, 'Living Room', 'LR');
      final first = _outlet(p.doc, p.bodyId, living, 'WP-1');

      _planAndApply(p.doc, 'Living Room: 2x Cat6 @outlet="WP-1"');

      expect(
        p.doc.outlets.values.where((o) => o.designation == 'WP-1'),
        hasLength(1),
        reason: 'joining is the whole reason the key has a designation in it',
      );
      expect(p.doc.outlets.containsKey(first), isTrue);
    });

    test('the note names BOTH rooms, and does not refuse', () {
      final p = _project();
      final living = _room(p.doc, 'Living Room', 'LR');
      _room(p.doc, 'Attic', 'ATT');
      _outlet(p.doc, p.bodyId, living, 'WP-1');

      final ready = _planAndApply(p.doc, 'Attic: 2x Cat6 @outlet="WP-1"');

      expect(ready.dropCount, 2, reason: 'a note never costs the drops');
      final note = ready.warnings.firstWhere(
        (w) => w.contains('WP-1'),
        orElse: () => '',
      );
      expect(note, contains('Living Room'));
      expect(note, contains('Attic'));
    });

    test('no note when the designation is unique', () {
      final p = _project();
      _room(p.doc, 'Attic', 'ATT');
      final ready = _planAndApply(p.doc, 'Attic: 2x Cat6 @outlet="WP-9"');
      expect(
        ready.warnings.where((w) => w.contains('WP-9')),
        isEmpty,
        reason: 'a note on every line is a note nobody reads',
      );
    });

    test('a roomless twin is reported as NO ROOM RECORDED', () {
      // DR-021's cascade clears `locationId`, so this is an ordinary
      // undoable state and not a contrived one.
      final p = _project();
      _room(p.doc, 'Attic', 'ATT');
      _outlet(p.doc, p.bodyId, null, 'WP-1');

      final ready = _planAndApply(p.doc, 'Attic: 2x Cat6 @outlet="WP-1"');
      expect(
        ready.warnings.any((w) => w.contains(kUngroupedTitle)),
        isTrue,
        reason: 'schedule.dart has printed that string since M2-B',
      );
    });

    test('the note is deterministic when two other rooms both match', () {
      // BUILT TO FALSIFY: the rooms are created in an order that is not
      // their sorted order, so a build that reported map order coincides
      // with the right answer only by accident.
      String noteFrom(List<String> creationOrder) {
        final p = _project();
        _room(p.doc, 'Attic', 'ATT');
        for (final name in creationOrder) {
          final id = _room(p.doc, name, name.substring(0, 2).toUpperCase());
          _outlet(p.doc, p.bodyId, id, 'WP-1');
        }
        final ready = _planAndApply(p.doc, 'Attic: 1x Cat6 @outlet="WP-1"');
        return ready.warnings.firstWhere((w) => w.contains('WP-1'));
      }

      final forward = noteFrom(['Bedroom', 'Alcove']);
      final reverse = noteFrom(['Alcove', 'Bedroom']);
      expect(forward, reverse);
      expect(forward, contains('Alcove'));
    });
  });

  group('a room name matches with internal whitespace collapsed', () {
    test('a double space matches the existing room', () {
      final p = _project();
      _room(p.doc, 'Living Room', 'LR');
      _planAndApply(p.doc, 'Living  Room: 1x Cat6');
      expect(
        p.doc.locations.values.where((l) => l.name.contains('Living')),
        hasLength(1),
        reason: 'the second room is what a Pull Sheet with two Living Rooms is',
      );
    });

    test('removing the space entirely does NOT match', () {
      // The ruled reading is COLLAPSE and not STRIP: stripping would make
      // two names a person reads as distinct unrepresentable.
      final p = _project();
      _room(p.doc, 'Living Room', 'LR');
      final parsed = parseDropLine('LivingRoom: 1x Cat6');
      final plan = planDropLine(
        doc: p.doc,
        line: parsed as DropLineParsed,
        now: _now,
        actor: 'test',
      );
      expect(plan, isA<DropLinePlanNeedsLocation>());
    });

    test('case and surrounding space still match, as they always did', () {
      final p = _project();
      _room(p.doc, 'Living Room', 'LR');
      _planAndApply(p.doc, '  living room : 1x Cat6');
      expect(p.doc.locations, hasLength(1));
    });
  });
}
