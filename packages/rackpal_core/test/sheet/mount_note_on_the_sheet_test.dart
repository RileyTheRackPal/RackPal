// The mount note reaching the deliverable (`#839`, M5-L, DR-130).
//
// ═══════════════════════════════════════════════════════════════════════
// A PRODUCER THAT REACHES NO SURFACE IS THE DEFECT ONE LAYER OUT
// ═══════════════════════════════════════════════════════════════════════
// `SetMountNoteCommand` gave `OffRackPlacement.mountNote` a writer. That
// alone would repeat this milestone's own mistake in a new place: DR-128
// shipped `Finding.remedy` with a writer, an implementation and a ruling
// saying the panel rendered it, and the panel never read the field.
//
// DR-130's argument for the smallest option rests entirely on the note
// REACHING the schedule and the PDF: "a device in the AV closet on the
// top shelf should print that way". If it does not print, the ruling
// chose the small option and delivered nothing, so these tests are the
// ruling's own load-bearing claim rather than a formatting check.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

final _at = DateTime.utc(2026, 9, 6);
const _closet = Uuid('loc-closet');
const _modem = Uuid('dev-modem');

DBox _drawingArea() => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiALandscape),
  revisionRowCount: 1,
).drawingArea;

RackDocument _doc({String? mountNote, String? deviceNotes}) {
  final doc = RackDocument(
    id: const Uuid('doc-mount-sheet'),
    appVersion: 'test',
    createdAt: _at,
    modifiedAt: _at,
    meta: testMeta(),
    racks: <Uuid, Rack>{},
  );
  doc.locations[_closet] = Location(
    id: _closet,
    name: 'AV Closet',
    code: 'AVC',
    kind: LocationKind.room,
    order: const FracIndex('a0'),
    meta: testMeta(),
  );
  doc.devices[_modem] = DeviceInstance(
    id: _modem,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('X01'),
      version: 1,
      contentHash: 'sha256:x01',
    ),
    designator: 'MDM-1',
    name: 'Cable modem',
    locationId: _closet,
    notes: deviceNotes,
    placement: OffRackPlacement(locationId: _closet, mountNote: mountNote),
    meta: testMeta(),
  );
  return doc;
}

ScheduleRow _row(RackDocument doc) => paginateEquipmentList(
  list: buildEquipmentList(doc),
  drawingArea: _drawingArea(),
  measurer: FakeMeasurer(),
).single.rows.single;

void main() {
  group('the derived row carries it, separably', () {
    test('an off-rack device hands the note through', () {
      final row = buildEquipmentList(
        _doc(mountNote: 'Top shelf, left'),
      ).rows.single;
      expect(row.mountNote, 'Top shelf, left');
      expect(
        row.location,
        'AV Closet',
        reason: 'the note REFINES the location rather than replacing it',
      );
    });

    test('and a rail-placed device has none, rather than an empty one', () {
      final doc = _doc(mountNote: 'Top shelf');
      doc.racks[const Uuid('rk-1')] = Rack(
        id: const Uuid('rk-1'),
        name: 'Rack',
        designator: 'RK-1',
        heightU: 12,
        order: const FracIndex('a0'),
        meta: testMeta(),
      );
      doc.devices[_modem]!.placement = const RailPlacement(
        rackId: Uuid('rk-1'),
        ruIndex: 3,
        face: Face.front,
      );
      expect(
        buildEquipmentList(doc).rows.single.mountNote,
        isNull,
        reason:
            'a rack, a U and a face already answer where it sits, and a '
            'note beside them would be a second answer to that question',
      );
    });

    test('it is NOT folded into notes at this layer', () {
      // Two facts with two different owners: `notes` is about the device
      // and survives a move, `mountNote` is about where it sits and is
      // meaningless the moment it goes into a rack. The sheet joins them
      // for want of a fourteenth column; this layer must not.
      final row = buildEquipmentList(
        _doc(mountNote: 'Top shelf', deviceNotes: 'Spare unit'),
      ).rows.single;
      expect(row.mountNote, 'Top shelf');
      expect(row.notes, 'Spare unit');
    });
  });

  group('and it reaches the sheet, which is the ruling load-bearing bit', () {
    test('the NOTES cell prints it', () {
      expect(
        _row(_doc(mountNote: 'Top shelf, left, sideways')).noteLines.join(' '),
        contains('Top shelf'),
        reason:
            'DR-130 chose the smallest option ON THE GROUND that a note '
            'reaches every surface. If it does not print, the ruling '
            'delivered nothing',
      );
    });

    test('with the MOUNT note first, because the row has no other cell '
        'that says where the device is', () {
      final row = _row(
        _doc(mountNote: 'Top shelf', deviceNotes: 'Spare unit'),
      );
      final cell = row.noteLines.join(' ');
      expect(
        cell.indexOf('Top shelf'),
        lessThan(cell.indexOf('Spare unit')),
        reason:
            'the column truncates past kMaxNoteLines, so whichever fact '
            'is second is the one a long row loses',
      );
      // The row it sits on: every other placement cell is an unknown or
      // a NONE, which is exactly why the order matters.
      expect(row.cells[EquipmentColumn.rack.index], kUnknownCell);
      expect(row.cells[EquipmentColumn.face.index], 'NONE');
    });

    test('and one fact alone brings no separator with it', () {
      expect(
        equipmentNotesCell(
          buildEquipmentList(_doc(mountNote: 'Top shelf')).rows.single,
        ),
        'Top shelf',
      );
      expect(
        equipmentNotesCell(
          buildEquipmentList(_doc(deviceNotes: 'Spare unit')).rows.single,
        ),
        'Spare unit',
      );
      expect(
        equipmentNotesCell(buildEquipmentList(_doc()).rows.single),
        isEmpty,
      );
    });

    test('two facts are joined by kNoteJoin and nothing else', () {
      expect(
        equipmentNotesCell(
          buildEquipmentList(
            _doc(mountNote: 'Top shelf', deviceNotes: 'Spare unit'),
          ).rows.single,
        ),
        'Top shelf${kNoteJoin}Spare unit',
      );
    });

    test('the thirteen columns still sum to the frame, so nothing was '
        'silently widened to fit this', () {
      // The alternative to joining was a fourteenth column. It was
      // declined because the widths sum to the ANSI A landscape usable
      // width, and this asserts that the decline actually held.
      var total = 0.0;
      for (final c in EquipmentColumn.values) {
        total += c.width;
      }
      expect(EquipmentColumn.values.length, 13);
      expect(total, 690);
    });
  });
}
