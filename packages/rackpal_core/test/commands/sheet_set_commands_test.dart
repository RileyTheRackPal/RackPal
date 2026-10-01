// T0.01's abbreviations and notes, as the file stores them and as the
// command writes them (`#969`, DR-209 §11.208.4).
//
// THREE STATES, AND THE TESTS ARE ORGANISED BY THEM: absent (the seed), a
// list (what the author wrote), and an EMPTY list (the author deleted every
// row). The middle one is the easy one; the other two are where a codec
// that wrote `[]` for null, or dropped `[]` as if it were null, would turn
// one fact into another.
import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _when = DateTime.utc(2026, 9, 30);

RackDocument _doc({
  List<LegendAbbreviation>? abbreviations,
  List<String>? notes,
}) => RackDocument(
  id: const Uuid('doc-legend'),
  appVersion: '0.6.60',
  createdAt: _when,
  modifiedAt: _when,
  meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test'),
  info: ProjectInfo(
    projectName: 'Legend',
    legendAbbreviations: abbreviations,
    legendNotes: notes,
  ),
);

Map<String, Object?> _infoOnWire(RackDocument doc) {
  final json =
      jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
  final document = json['document']! as Map<String, Object?>;
  return document['info']! as Map<String, Object?>;
}

ProjectInfo _readBack(RackDocument doc) =>
    (_codec.read(_codec.write(doc)) as Ok<RackDocument>).value.info;

void main() {
  group('on the wire', () {
    test('AN UNEDITED PROJECT WRITES NO KEY, and reads back as the seed', () {
      final doc = _doc();
      final info = _infoOnWire(doc);
      expect(info.containsKey('legendAbbreviations'), isFalse);
      expect(info.containsKey('legendNotes'), isFalse);
      final back = _readBack(doc);
      expect(back.legendAbbreviations, isNull);
      expect(back.legendNotes, isNull);
    });

    test('an edited list is written as rows and reads back exactly', () {
      final doc = _doc(
        abbreviations: const [
          LegendAbbreviation('AFF', 'above finished floor'),
          LegendAbbreviation('TYP', 'typical'),
        ],
        notes: const ['All work to NEC.', 'Verify in field.'],
      );
      expect(_infoOnWire(doc)['legendAbbreviations'], [
        {'abbreviation': 'AFF', 'meaning': 'above finished floor'},
        {'abbreviation': 'TYP', 'meaning': 'typical'},
      ]);
      expect(_infoOnWire(doc)['legendNotes'], [
        'All work to NEC.',
        'Verify in field.',
      ]);
      final back = _readBack(doc);
      expect(back.legendAbbreviations, doc.info.legendAbbreviations);
      expect(back.legendNotes, doc.info.legendNotes);
    });

    test('AN EMPTY LIST IS WRITTEN, because it is not the seed', () {
      final doc = _doc(abbreviations: const [], notes: const []);
      expect(_infoOnWire(doc)['legendAbbreviations'], isEmpty);
      expect(_infoOnWire(doc)['legendNotes'], isEmpty);
      final back = _readBack(doc);
      expect(back.legendAbbreviations, isEmpty);
      expect(back.legendNotes, isEmpty);
    });

    test('write(read(bytes)) == bytes with both lists present (CR-117)', () {
      final bytes = _codec.write(
        _doc(
          abbreviations: const [LegendAbbreviation('AFF', 'above floor')],
          notes: const ['One.'],
        ),
      );
      final again = _codec.write(
        (_codec.read(bytes) as Ok<RackDocument>).value,
      );
      expect(again, bytes);
    });
  });

  group('SetLegendNotesCommand', () {
    test('writes both lists, and revert restores what was there', () {
      final doc = _doc();
      final cmd = SetLegendNotesCommand.to(
        doc.info,
        abbreviations: const [LegendAbbreviation('AFF', 'above floor')],
        notes: const ['One.'],
      );
      expect(cmd.apply(doc), isTrue);
      expect(doc.info.legendAbbreviations, const [
        LegendAbbreviation('AFF', 'above floor'),
      ]);
      expect(doc.info.legendNotes, ['One.']);
      cmd.revert(doc);
      expect(doc.info.legendAbbreviations, isNull);
      expect(doc.info.legendNotes, isNull);
    });

    test('A WHOLLY BLANK ROW IS NOT SAVED; a half-filled one is', () {
      final doc = _doc();
      SetLegendNotesCommand.to(
        doc.info,
        abbreviations: const [
          LegendAbbreviation('  ', ''),
          LegendAbbreviation('AFF', ''),
        ],
        notes: const ['   ', 'Kept.'],
      ).apply(doc);
      expect(doc.info.legendAbbreviations, const [
        LegendAbbreviation('AFF', ''),
      ]);
      expect(doc.info.legendNotes, ['Kept.']);
    });

    test('null returns a list to the seed, which is Restore defaults', () {
      final doc = _doc(
        abbreviations: const [LegendAbbreviation('AFF', 'above floor')],
        notes: const [],
      );
      final cmd = SetLegendNotesCommand.to(
        doc.info,
        abbreviations: null,
        notes: null,
      )..apply(doc);
      expect(doc.info.legendAbbreviations, isNull);
      expect(doc.info.legendNotes, isNull);
      cmd.revert(doc);
      expect(doc.info.legendNotes, isEmpty, reason: 'empty is not null');
    });

    test('the stored lists cannot be edited in place', () {
      final doc = _doc(notes: ['One.']);
      expect(() => doc.info.legendNotes!.add('Two.'), throwsUnsupportedError);
    });
  });
}
