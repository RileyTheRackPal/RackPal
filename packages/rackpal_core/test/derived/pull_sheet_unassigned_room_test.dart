// M3-B/3, #146 — a drop with no Location cannot vanish from the Pull
// Sheet. G4 and G1 together.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS A SEPARATE FILE AND NOT THREE MORE CASES IN schedule_test
// ═══════════════════════════════════════════════════════════════════════
// The board task names the reason the property needs a gate at all:
// **the failure is invisible on any document where every drop happens to
// have a room.** Room is the Pull Sheet's PRIMARY SORT and its grouping
// (`SchedulePreset.pullSheet`), so a roomless drop is the one row with no
// band to land in, and every fixture in the corpus gives every drop a room.
// A regression here would pass the whole suite and would be found by an
// installer holding a sheet that is short two cables.
//
// It is also newly REACHABLE rather than merely representable. Before
// DR-021 a roomless drop meant someone had left the field blank; from
// M3-B/1 a delete of a room CLEARS `PlaceEndpoint.locationId` on every
// drop in it (§11.20.2), so an ordinary gesture now produces the state
// this file protects. The last case below is that gesture, end to end.
//
// ═══════════════════════════════════════════════════════════════════════
// THE TWO PROHIBITIONS ARE DIFFERENT AND BOTH ARE ASSERTED
// ═══════════════════════════════════════════════════════════════════════
//   G1 — it may not be silently dropped from the deliverable. The
//        schedule is what the installer works from; a run missing from it
//        is a cable nobody pulls.
//   G4 — it may not be filed under an invented room. "Unassigned" is a
//        FACT about the document; "Great Room" would be a guess wearing
//        the authority of data, and the room a drop is in is exactly what
//        the sheet is sorted by.
//
// An implementation could satisfy either alone: dropping the row honours
// G4 vacuously, and folding it into the first room honours G1. Only the
// explicit band honours both.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 6);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-unassigned-room'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

Uuid _room(RackDocument doc, String name) => (AddLocationCommand(
  name: name,
  code: name.substring(0, 2).toUpperCase(),
  order: nextLocationOrder(doc),
  now: _when,
  actor: 'seed',
)..apply(doc)).id;

/// One field cable, in [room] when given and nowhere when not.
void _drop(
  RackDocument doc, {
  required String designator,
  Uuid? room,
  Len? length,
  int order = 0,
}) {
  doc.links[Uuid(designator)] = Link(
    id: Uuid(designator),
    designator: designator,
    media: const MediaTypeId('media.cat6_utp'),
    order: FracIndex('a$order'),
    meta: _meta(),
    // `cutLength`, not `terminatedLength`: §3.2 column 8's chain is
    // cut -> outlet nominal -> room estimate, and the footage a Pull Sheet
    // subtotals is what was CUT off the reel. The terminated length is a
    // different column recording a different act.
    cutLength: length,
    conductors: [
      Conductor(
        from: PlaceEndpoint(description: 'wall plate', locationId: room),
        to: const OpenEndpoint('coiled at the panel'),
      ),
    ],
  );
}

ScheduleView _pullSheet(RackDocument doc) =>
    scheduleViewOf(doc, preset: SchedulePreset.pullSheet);

void main() {
  test('the Pull Sheet really is grouped and sorted by room', () {
    // The precondition every case below depends on. If the preset ever
    // stopped grouping by room, this file would keep passing while
    // asserting nothing about the sheet anyone prints.
    final view = _pullSheet(_doc());

    expect(view.grouping, ScheduleGrouping.room);
    expect(view.sort, ScheduleSort.roomThenPathway);
  });

  test('G1: a roomless drop is still on the sheet', () {
    final doc = _doc();
    final great = _room(doc, 'Great Room');
    _drop(doc, designator: 'W001', room: great);
    _drop(doc, designator: 'W002', order: 1);

    final view = _pullSheet(doc);

    expect(view.rowCount, 2);
    expect(
      [
        for (final g in view.groups)
          for (final r in g.rows) r.designator,
      ],
      containsAll(['W001', 'W002']),
    );
  });

  test('G4: it lands in a band that names the absence, not a room', () {
    final doc = _doc();
    _drop(doc, designator: 'W001');

    final view = _pullSheet(doc);

    expect(view.groups.single.title, kUngroupedTitle);
    // The band is keyed on NOTHING, which is what says "this is not an
    // entity" rather than "this is a location whose name is missing".
    expect(view.groups.single.key, isNull);
  });

  test('the band is LAST, after every real room', () {
    // Not interleaved by name. An installer works down the sheet room by
    // room; a `NO ROOM RECORDED` band sorting between `Kitchen` and
    // `Living Room` reads as a room called that.
    final doc = _doc();
    for (final (i, name) in ['Zulu Room', 'Alpha Room'].indexed) {
      final id = _room(doc, name);
      _drop(doc, designator: 'W00$i', room: id, order: i);
    }
    _drop(doc, designator: 'W009', order: 9);

    expect(_pullSheet(doc).groups.map((g) => g.title).toList(), [
      'Alpha Room',
      'Zulu Room',
      kUngroupedTitle,
    ]);
  });

  test('its footage does NOT join any room subtotal', () {
    // The number an installer orders cable against. A subtotal that
    // silently absorbed a run nobody has placed would be the fabricated
    // total G4 forbids, and it is the one number on the sheet that costs
    // money to get wrong.
    final doc = _doc();
    final great = _room(doc, 'Great Room');
    _drop(
      doc,
      designator: 'W001',
      room: great,
      length: Len.fromMillimetres(10000),
    );
    _drop(
      doc,
      designator: 'W002',
      length: Len.fromMillimetres(90000),
      order: 1,
    );

    final view = _pullSheet(doc);
    final rooms = {for (final g in view.groups) g.title: g};

    expect(rooms['Great Room']!.footage.value, Len.fromMillimetres(10000));
    expect(
      rooms[kUngroupedTitle]!.footage.value,
      Len.fromMillimetres(90000),
    );
  });

  test('the band still counts its own unknowns rather than fabricating a '
      'total', () {
    // G4 twice over: the rows are not dropped AND the band's rollup
    // reports how many of them could not supply a length.
    final doc = _doc();
    _drop(doc, designator: 'W001', length: Len.fromMillimetres(10000));
    _drop(doc, designator: 'W002', order: 1);

    final band = _pullSheet(doc).groups.single;

    expect(band.title, kUngroupedTitle);
    expect(band.rows, hasLength(2));
    expect(band.footage.unknownCount, 1);
  });

  test('a document where every drop has a room grows no empty band', () {
    // The other direction, and the reason the failure is invisible: an
    // implementation that always emitted the band would look correct on
    // every case above and add a phantom heading to every real sheet.
    final doc = _doc();
    final great = _room(doc, 'Great Room');
    _drop(doc, designator: 'W001', room: great);

    expect(_pullSheet(doc).groups.map((g) => g.title), ['Great Room']);
  });

  test('DELETING A ROOM puts its drops in the band rather than removing '
      'them (DR-021 §11.20.2)', () {
    // The gesture that makes this state ordinary rather than exotic, end
    // to end. Before M3-B/1 a roomless drop meant a blank field; now it is
    // what an undoable delete produces, and the cable it describes is
    // still in the building.
    final doc = _doc();
    final great = _room(doc, 'Great Room');
    _drop(
      doc,
      designator: 'W001',
      room: great,
      length: Len.fromMillimetres(10000),
    );
    expect(_pullSheet(doc).groups.single.title, 'Great Room');

    final cmd = buildRemoveLocation(doc: doc, locationId: great)!..apply(doc);

    final after = _pullSheet(doc);
    expect(after.rowCount, 1, reason: 'the cable is still in the building');
    expect(after.groups.single.title, kUngroupedTitle);
    expect(
      after.groups.single.rows.single.designator,
      'W001',
      reason: 'its W number survives the room being deleted',
    );

    // And undo puts the room back on the sheet, not merely in the model.
    cmd.revert(doc);
    expect(_pullSheet(doc).groups.single.title, 'Great Room');
  });
}
