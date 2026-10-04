// Link.crossover, written at last (`#973`, DR-231): the command, the wire,
// the schedule's notes and T5.01, for every value including DR-231's
// polarity reversed.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

/// Whole House's first cable by designator.
Link _first(RackDocument doc) =>
    (doc.links.values.toList()
          ..sort((a, b) => compareDesignators(a.designator, b.designator)))
        .first;

void _set(RackDocument doc, Link link, CrossoverKind? to) =>
    DocumentController(doc).run(
      buildSetEntityProperty(
        doc: doc,
        id: link.id,
        field: LinkField.crossover,
        to: to,
        now: DateTime.utc(2026, 10, 4),
        actor: 'test',
      )!,
    );

void main() {
  group('THE COMMAND (DR-231)', () {
    test('sets, clears, and undoes as one step', () {
      final doc = _wholeHouse();
      final link = _first(doc);
      final controller = DocumentController(doc);
      expect(link.crossover, isNull, reason: 'precondition: nobody has said');

      controller.run(
        buildSetEntityProperty(
          doc: doc,
          id: link.id,
          field: LinkField.crossover,
          to: CrossoverKind.polarityReversed,
          now: DateTime.utc(2026, 10, 4),
          actor: 'test',
        )!,
      );
      expect(link.crossover, CrossoverKind.polarityReversed);
      controller.undoLast();
      expect(link.crossover, isNull);
    });

    test('setting the value it already has is no command at all', () {
      final doc = _wholeHouse();
      final link = _first(doc);
      _set(doc, link, CrossoverKind.straight);
      expect(
        buildSetEntityProperty(
          doc: doc,
          id: link.id,
          field: LinkField.crossover,
          to: CrossoverKind.straight,
          now: DateTime.utc(2026, 10, 4),
          actor: 'test',
        ),
        isNull,
      );
    });
  });

  group('THE WIRE', () {
    for (final kind in CrossoverKind.values) {
      test('${kind.name} is written by name and read back, the file '
          'byte-stable', () {
        final doc = _wholeHouse();
        final link = _first(doc);
        _set(doc, link, kind);
        const codec = JsonDocumentCodec();
        final bytes = codec.write(doc);
        final back = (codec.read(bytes) as Ok<RackDocument>).value;
        expect(back.links[link.id]!.crossover, kind);
        expect(codec.write(back), bytes);
      });
    }

    test('UNSET IS AN ABSENT KEY, so a file nobody marked is unchanged (G4, '
        'CR-117)', () {
      final source = File(
        '../../apps/rackpal/assets/starters/whole_house.rppj',
      ).readAsBytesSync();
      const codec = JsonDocumentCodec();
      final doc = (codec.read(source) as Ok<RackDocument>).value;
      expect(
        String.fromCharCodes(codec.write(doc)),
        isNot(contains('"crossover"')),
      );
    });
  });

  group('WHAT PRINTS', () {
    test('the schedule notes it', () {
      final doc = _wholeHouse();
      final link = _first(doc);
      _set(doc, link, CrossoverKind.polarityReversed);
      final row = buildSchedule(doc).rows.firstWhere(
        (r) => r.linkId == link.id,
      );
      expect(row.derivedNotes, contains('POLARITY REVERSED'));
    });

    test('T5.01 lists a polarity-reversed cable in its own section, under '
        'the note that the swap is deliberate', () {
      final doc = _wholeHouse();
      final link = _first(doc);
      expect(
        pinoutDetailsOf(doc, buildSchedule(doc)).polarityReversed,
        isEmpty,
        reason: 'control',
      );
      _set(doc, link, CrossoverKind.polarityReversed);
      final details = pinoutDetailsOf(doc, buildSchedule(doc));
      expect(details.polarityReversed.map((e) => e.linkId), [link.id]);
      expect(details.nullModems, isEmpty);

      final items = [
        for (final page in paginatePinoutDetails(
          details: details,
          settings: doc.settings,
          drawingArea: SheetLayout.resolve(
            geometry: const SheetGeometry(SheetSize.ansiALandscape),
            revisionRowCount: 0,
          ).drawingArea,
          measurer: FakeMeasurer(),
        ))
          ...page.items,
      ];
      final head = items.whereType<PinoutSectionHead>().firstWhere(
        (h) => h.title == '$kPolarityReversedSectionTitle (1)',
      );
      expect(head.notes, [kPolarityReversedNote]);
      expect(
        items.whereType<PinoutRow>().map((r) => r.key),
        contains(link.designator),
      );
    });

    test('A NULL-MODEM SET THROUGH THE COMMAND turns T5.01 on, which no '
        'control could do before #973', () {
      final doc = _wholeHouse();
      final link = _first(doc);
      _set(doc, link, CrossoverKind.nullModem);
      expect(
        pinoutDetailsOf(
          doc,
          buildSchedule(doc),
        ).nullModems.map((e) => e.linkId),
        [link.id],
      );
    });
  });
}
