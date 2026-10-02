// T6.20's rows (M6-E1 `#332`, DR-220 §11.219.1, §11.219.4).
//
// Run on Whole House, the one starter that carries cables, and on Whole
// House edited: its 27 home runs are 12 open at the rack and 15 landed, so
// every case DR-220 names is one edit away from real data rather than a
// hand-built document that might not resemble one.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

RackDocument _starter(String name) =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/$name.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

List<UnusedHomeRunRoom> _rows(RackDocument doc) =>
    unusedHomeRunsOf(buildSchedule(doc), doc);

List<UnusedHomeRun> _flat(RackDocument doc) => [
  for (final room in _rows(doc)) ...room.runs,
];

Link _byDesignator(RackDocument doc, String designator) =>
    doc.links.values.singleWhere((l) => l.designator == designator);

/// A landed Whole House run: its rack end is a port.
Link _landed(RackDocument doc) => doc.links.values.firstWhere(
  (l) => l.conductors.first.to is PortEndpoint,
);

/// Every conductor's field end replaced with a coil.
void _coilTheRoomEnd(Link link) {
  link.conductors = [
    for (final c in link.conductors)
      Conductor(
        from: const OpenEndpoint('coil above the ceiling'),
        to: c.to,
        role: c.role,
        pairNumber: c.pairNumber,
        colorCode: c.colorCode,
      ),
  ];
}

void main() {
  group('WHOLE HOUSE, AS SHIPPED', () {
    test('lists its twelve runs open at the rack, and none of the fifteen '
        'landed ones', () {
      final runs = _flat(_starter('whole_house'));
      expect(
        [for (final r in runs) r.entry.designator]..sort(),
        [
          'W004',
          'W005',
          'W009',
          'W010',
          'W016',
          'W017',
          'W018',
          'W020',
          'W022',
          'W023',
          'W025',
          'W026',
        ],
      );
      expect(runs.map((r) => r.open).toSet(), {OpenEnd.rack});
    });

    test('rooms print in name order, each a band of its own runs', () {
      final rooms = _rows(_starter('whole_house'));
      expect(rooms.map((r) => r.title), [
        'Bedroom 2',
        'Great Room',
        'Kitchen',
        'Media Room',
        'Patio',
        'Primary Bedroom',
      ]);
      for (final room in rooms) {
        expect(
          room.runs.map((r) => r.entry.roomName).toSet(),
          {room.title},
          reason: '${room.title} holds only its own runs',
        );
      }
    });

    test('a starter with no cables lists nothing, so T6.20 is absent', () {
      for (final name in ['apartment', 'home_theatre', 'small_office']) {
        expect(_rows(_starter(name)), isEmpty, reason: name);
      }
    });
  });

  group('WHICH END IS OPEN (§11.219.1, §11.219.3)', () {
    test('a run landed at the rack and coiled at the room is listed, ROOM', () {
      final doc = _starter('whole_house');
      final link = _landed(doc);
      expect(
        _flat(doc).map((r) => r.entry.designator),
        isNot(contains(link.designator)),
        reason: 'precondition: landed at both ends, so not unused',
      );
      _coilTheRoomEnd(link);
      final run = _flat(
        doc,
      ).singleWhere((r) => r.entry.designator == link.designator);
      expect(run.open, OpenEnd.room);
      expect(run.rackEnd.kind, ScheduleEndKind.rackPort);
    });

    test('a run open at both ends is listed, BOTH', () {
      final doc = _starter('whole_house');
      final link = _byDesignator(doc, 'W004');
      _coilTheRoomEnd(link);
      final run = _flat(doc).singleWhere((r) => r.entry.designator == 'W004');
      expect(run.open, OpenEnd.both);
    });

    test('A RUN THAT IS NOT A HOME RUN is a schedule row and not this '
        "sheet's, open end or not", () {
      final doc = _starter('whole_house');
      expect(
        _flat(doc).map((r) => r.entry.designator),
        contains('W004'),
        reason: 'precondition: listed while it is a home run',
      );
      _byDesignator(doc, 'W004').structureOrigin = null;
      expect(
        _flat(doc).map((r) => r.entry.designator),
        isNot(contains('W004')),
      );
    });
  });

  group('ORDER (§11.219.4)', () {
    test('within a room, cable ID in NATURAL order: W9 before W10', () {
      final doc = _starter('whole_house');
      // Great Room holds W004 and W005; renumbered so a string sort and a
      // natural one disagree.
      _byDesignator(doc, 'W004').designator = 'W10';
      _byDesignator(doc, 'W005').designator = 'W9';
      final great = _rows(doc).singleWhere((r) => r.title == 'Great Room');
      expect(great.runs.map((r) => r.entry.designator), ['W9', 'W10']);
    });

    test('a run whose room nobody recorded bands LAST, under '
        '$kUngroupedTitle', () {
      final doc = _starter('whole_house');
      final link = _byDesignator(doc, 'W004');
      final origin = link.structureOrigin!;
      // No room on either end and no outlet to fall back to.
      link
        ..conductors = [
          for (final c in link.conductors)
            Conductor(
              from: const PlaceEndpoint(description: 'somewhere'),
              to: c.to,
              role: c.role,
            ),
        ]
        ..structureOrigin = StructureOrigin(
          structureBodyId: origin.structureBodyId,
          outletId: null,
          fieldLabel: origin.fieldLabel,
        );
      final rooms = _rows(doc);
      expect(rooms.last.title, kUngroupedTitle);
      expect(rooms.last.roomId, isNull);
      expect(rooms.last.runs.map((r) => r.entry.designator), ['W004']);
    });
  });
}
