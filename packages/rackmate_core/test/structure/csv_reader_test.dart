// M3-F/5 (#651), docs/07 §5, AC-058/D8.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THESE TESTS ASSERT IS THE TABLE, NOT THE LEXER
// ═══════════════════════════════════════════════════════════════════════
// House style: assert the artifact. So nothing here reaches for a
// private state machine or pins an intermediate buffer; every case hands
// [readCsv] a string a real export could contain and states what the
// resulting rows and cells are. The lexer can be rewritten and these
// stay true, which is the only reason they are worth having.
//
// The cases that earn their place are the ones where a plausible
// implementation is WRONG and still passes a happy-path test: a trailing
// newline that invents a row, a CRLF that survives into a cell and makes
// dedup fail invisibly, a long row whose overflow is dropped, and a
// `Conduit` column that is a cable in one file and a pathway in the
// next.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

CsvTable _ok(String text, {CsvLimits limits = CsvLimits.standard}) {
  final read = readCsv(text, limits: limits);
  return switch (read) {
    CsvReadOk(:final table) => table,
    CsvReadRefused(:final message) => fail('refused: $message'),
  };
}

CsvReadRefused _refused(String text, {CsvLimits limits = CsvLimits.standard}) {
  final read = readCsv(text, limits: limits);
  return switch (read) {
    CsvReadRefused() => read,
    CsvReadOk() => fail('expected a refusal'),
  };
}

/// docs/07 §5.2's example, verbatim. At column zero because the content
/// of a raw block string is the fixture: indenting it would put spaces
/// inside the cells.
const _example = '''
Room,Outlet,Cable Type,Qty,Use,Bundle,Length (ft),Panel Port,Status,Notes
Living Room,WP-1,Cat6,2,Ethernet,LR-TV,62,PP-1 R01,pulled,
Living Room,WP-1,Cat6,1,HDBaseT,LR-TV,62,,pulled,to TV
Living Room,WP-1,RG6,2,CATV,LR-TV,62,F barrel,pulled,
Living Room,CLG,16/4,2,Speaker,LR-AUD,48,,pulled,ceiling pair
Attic,AP-1,Cat6,1,Ethernet,,88,PP-1 R14,terminated,AP over hall
Exterior,CAM-1..6,Cat6,6,Camera,EXT-1,120,PP-2 R01,planned,soffit
Office,,"ENT 3/4""",1,,,,,planned,pull string only
''';

void main() {
  group('RFC 4180, the parts a pull list actually uses', () {
    test('a plain file is headers and rows', () {
      final t = _ok('Room,Qty\nLiving Room,2\nAttic,1\n');
      expect(t.headers, ['Room', 'Qty']);
      expect(t.rows.length, 2);
      expect(t.rows[0].cells, ['Living Room', '2']);
      expect(t.rows[1].cells, ['Attic', '1']);
    });

    test('a quoted field keeps its commas', () {
      final t = _ok('Room,Notes\nAttic,"AP over hall, soffit run"\n');
      expect(t.rows.single.cells, ['Attic', 'AP over hall, soffit run']);
    });

    test('a doubled quote is one literal quote', () {
      final t = _ok('Room,Notes\nShop,"the 3/4"" conduit"\n');
      expect(t.rows.single.cells[1], 'the 3/4" conduit');
    });

    test('a quote that is not at the start of a field is just a quote', () {
      // RFC 4180 makes `"` special only where a field opens. A pull list
      // writes inches this way constantly and refusing it would be a
      // parser telling a contractor to stop measuring in inches.
      final t = _ok('Room,Media\nShop,ENT 3/4"\n');
      expect(t.rows.single.cells[1], 'ENT 3/4"');
    });

    test('a quoted field may contain a newline, and the row survives', () {
      final t = _ok('Room,Notes\nAttic,"first\nsecond"\nGarage,x\n');
      expect(t.rows.length, 2);
      expect(t.rows[0].cells[1], 'first\nsecond');
      expect(t.rows[1].cells, ['Garage', 'x']);
    });
  });

  group('the things that differ by which machine exported the file', () {
    test('CRLF, LF and a lone CR all read the same', () {
      const wanted = [
        ['a', '1'],
        ['b', '2'],
      ];
      for (final eol in ['\n', '\r\n', '\r']) {
        final t = _ok('Room,Qty${eol}a,1${eol}b,2$eol');
        expect(
          t.rows.map((r) => r.cells),
          wanted,
          reason: 'EOL ${eol.codeUnits}',
        );
      }
    });

    test('a CRLF INSIDE a quoted cell normalises to a plain newline', () {
      // The one that would never be noticed. §5.3's dedup compares
      // `fieldLabel` and its update guard compares notes, so a surviving
      // `\r` makes a row differ from itself across two exports of the
      // same sheet with nothing on screen to show why.
      final t = _ok('Room,Notes\r\nAttic,"one\r\ntwo"\r\n');
      expect(t.rows.single.cells[1], 'one\ntwo');
      expect(t.rows.single.cells[1], isNot(contains('\r')));
    });

    test('a leading byte-order mark is not part of the first header', () {
      final t = _ok('﻿Room,Qty\na,1\n');
      expect(t.headers.first, 'Room');
      expect(matchCsvHeader(t.headers.first), CsvColumnTarget.location);
    });

    test('a trailing newline does not invent an empty final row', () {
      expect(_ok('Room\na\n').rows.length, 1);
      expect(_ok('Room\na').rows.length, 1);
    });
  });

  group('nothing is silently discarded (G4, docs/04 §3.4)', () {
    test('a short row pads and does not shift its cells left', () {
      final t = _ok('Room,Qty,Notes\nAttic,1\n');
      expect(t.rows.single.cells, ['Attic', '1', '']);
      expect(t.rows.single.isRagged, isFalse);
    });

    test('a long row KEEPS its overflow rather than truncating', () {
      // An unescaped comma in a notes cell, which is how this happens in
      // the field. The text after the comma is the half a person most
      // wants to see, so it reaches the preview grid.
      final t = _ok('Room,Notes\nAttic,to TV,matrix TBD\n');
      expect(t.rows.single.cells, ['Attic', 'to TV']);
      expect(t.rows.single.overflow, ['matrix TBD']);
      expect(t.rows.single.isRagged, isTrue);
    });

    test('blank separator lines are skipped AND counted', () {
      final t = _ok('Room,Qty\na,1\n\n\nb,2\n');
      expect(t.rows.length, 2);
      expect(t.blankLinesSkipped, 2);
    });

    test('a whitespace-only line counts as blank too', () {
      final t = _ok('Room,Qty\na,1\n   \nb,2\n');
      expect(t.rows.length, 2);
      expect(t.blankLinesSkipped, 1);
    });

    test('a line of nothing but commas is a real empty row', () {
      // Not the blank-line case: the operator left a row in place with
      // its columns intact, which the preview grid should show as empty
      // rather than pretend it never existed.
      final t = _ok('Room,Qty\na,1\n,\n');
      expect(t.rows.length, 2);
      expect(t.rows[1].cells, ['', '']);
      expect(t.blankLinesSkipped, 0);
    });
  });

  group('the line number is the one a person can find in Excel', () {
    test('an embedded newline pushes later rows down, and it is tracked', () {
      final t = _ok('Room,Notes\nAttic,"one\ntwo"\nGarage,x\n');
      expect(t.rows[0].line, 2);
      expect(t.rows[1].line, 4);
    });

    test('a skipped blank line still advances the count', () {
      final t = _ok('Room,Qty\na,1\n\nb,2\n');
      expect(t.rows[1].line, 4);
    });
  });

  group('headers reach the mapping sheet as the operator typed them', () {
    test('case and spacing survive; only matching normalises', () {
      final t = _ok('  Cable Type  ,ROOM\nCat6,Attic\n');
      expect(t.headers, ['Cable Type', 'ROOM']);
      expect(matchCsvHeader(t.headers[0]), CsvColumnTarget.media);
      expect(matchCsvHeader(t.headers[1]), CsvColumnTarget.location);
    });

    test('two columns may carry one header, and both are kept', () {
      // Not an error here. Two headers claiming one target is a question
      // the mapping sheet asks, and it cannot ask it about a column this
      // layer threw away.
      final t = _ok('Notes,Notes\na,b\n');
      expect(t.headers, ['Notes', 'Notes']);
      expect(t.rows.single.cells, ['a', 'b']);
    });

    test('an empty header is a column, not an absence', () {
      final t = _ok('Room,,Qty\na,x,1\n');
      expect(t.headers, ['Room', '', 'Qty']);
      expect(t.rows.single.cells, ['a', 'x', '1']);
    });
  });

  group('the file itself can be refused, and says why', () {
    test('an empty or whitespace-only file', () {
      expect(_refused('').reason, CsvRefusal.empty);
      expect(_refused('\n\n  \n').reason, CsvRefusal.empty);
    });

    test('a quote that never closes, with the line it opened on', () {
      final r = _refused('Room,Notes\nAttic,"never closed\nGarage,x\n');
      expect(r.reason, CsvRefusal.unterminatedQuote);
      expect(r.line, 2);
    });

    test('a semicolon file is DIAGNOSED, never sniffed and re-parsed', () {
      // Sniffing a delimiter is a heuristic and RJ-004 capped the tail
      // this feature grows. A refusal naming what was found tells the
      // operator what to change and can never parse a file the wrong way
      // silently.
      final r = _refused('Room;Qty;Notes\nAttic;1;x\n');
      expect(r.reason, CsvRefusal.wrongDelimiter);
      expect(r.message, contains('semicolons'));
    });

    test('a tab-separated file is diagnosed the same way', () {
      expect(
        _refused('Room\tQty\nAttic\t1\n').message,
        contains('tabs'),
      );
    });

    test('a semicolon INSIDE a proper CSV is not a delimiter problem', () {
      // The file the sniff would get wrong. It has commas, so it parses,
      // and the semicolon is just a character in a notes cell.
      final t = _ok('Room,Notes\nAttic,"pull; then terminate"\n');
      expect(t.rows.single.cells[1], 'pull; then terminate');
    });

    test('every AC-058/D8 ceiling refuses rather than truncating', () {
      const tiny = CsvLimits(maxCharacters: 12, maxRows: 2, maxFields: 3);
      expect(
        _refused('Room,Qty\na,1\nb,2\nc,3\n', limits: tiny).reason,
        CsvRefusal.tooLarge,
      );
      expect(
        _refused(
          'Room,Qty\na,1\nb,2\nc,3\n',
          limits: const CsvLimits(maxRows: 2),
        ).reason,
        CsvRefusal.tooManyRows,
      );
      expect(
        _refused(
          'a,b,c,d\n1,2,3,4\n',
          limits: const CsvLimits(maxFields: 3),
        ).reason,
        CsvRefusal.tooManyFields,
      );
    });

    test('a file at exactly the row limit is accepted', () {
      // The boundary, because an off-by-one here refuses a legal import
      // and the message would blame the operator for it.
      final t = _ok('Room\na\nb\n', limits: const CsvLimits(maxRows: 2));
      expect(t.rows.length, 2);
    });
  });

  group("docs/07 §5.2's own worked example", () {
    test('ten columns and seven rows, none of them ragged', () {
      final t = _ok(_example);
      expect(t.headers.length, 10);
      expect(t.rows.length, 7);
      expect(t.rows.every((r) => !r.isRagged), isTrue);
    });

    test('the blank cells are blank and not shifted', () {
      final t = _ok(_example);
      // Row 2's empty `Panel Port` is §5.2's `OpenEndpoint` at the rack
      // end; if it shifted, `Status` would read as a port.
      expect(t.rows[1].cells[7], '');
      expect(t.rows[1].cells[8], 'pulled');
      // The last row has no outlet and no use, bundle, length or port.
      expect(t.rows[6].cells[1], '');
      expect(t.rows[6].cells[2], 'ENT 3/4"');
      expect(t.rows[6].cells[8], 'planned');
    });

    test('`Length (ft)` is unmapped here, exactly as #159 pinned it', () {
      // The consequence `csv_header_map.dart` names in its own doc
      // comment, restated at the layer that produces the header: the
      // spec's example carries a parenthesised unit, four transforms do
      // not strip it, and the column routes to the manual assign step.
      // Asserted here so the two files cannot drift apart.
      final t = _ok(_example);
      expect(matchCsvHeader(t.headers[6]), isNull);
      expect(matchCsvHeader(t.headers[0]), CsvColumnTarget.location);
      expect(matchCsvHeader(t.headers[2]), CsvColumnTarget.media);
    });
  });

  group('long or wide (docs/07 §5)', () {
    final registries = buildSeedRegistries();

    CsvShapeDetection detect(String text) =>
        detectCsvShape(_ok(text), registries);

    test("§5.2's example is long", () {
      final d = detect('Room,Cable Type,Qty\nAttic,Cat6,2\n');
      expect(d.shape, CsvShape.long);
      expect(d.mediaColumns, isEmpty);
    });

    test('two numeric cable columns offer wide', () {
      final d = detect('Room,Cat6,RG6\nLiving Room,4,2\nAttic,1,\n');
      expect(d.shape, CsvShape.wide);
      expect(d.mediaColumns, [1, 2]);
      expect(d.reason, contains('Cat6'));
    });

    test('one cable column is not enough', () {
      final d = detect('Room,Cat6,Notes\nAttic,4,x\n');
      expect(d.shape, CsvShape.long);
    });

    test('cable columns holding WORDS are not counts', () {
      final d = detect('Room,Cat6,RG6\nAttic,yes,no\n');
      expect(d.shape, CsvShape.long);
    });

    test('a blank column is evidence of nothing', () {
      // All-empty is not "all numeric". Counting it would let a sheet
      // with one real cable column and one empty one flip to wide.
      final d = detect('Room,Cat6,RG6\nAttic,4,\nGarage,2,\n');
      expect(d.shape, CsvShape.long);
    });

    test('a blank CELL does not disqualify its column', () {
      // A wide pull list leaves the speaker column empty for rooms with
      // no speakers. What the blank MEANS is M3-F/6's question.
      final d = detect('Room,Cat6,RG6\nA,4,2\nB,,1\n');
      expect(d.shape, CsvShape.wide);
    });

    test('an explicit media column settles it as long', () {
      // Numeric columns named like cables sitting beside a `Cable Type`
      // column are something else. Reading this as wide would silently
      // reinterpret every row.
      final d = detect('Room,Cable Type,Cat6,RG6\nAttic,Cat6,4,2\n');
      expect(d.shape, CsvShape.long);
      expect(d.reason, contains('Cable Type'));
    });

    test('`Conduit` is a cable when it holds numbers', () {
      // It is BOTH: `matchCsvHeader` calls it a pathway, and
      // `media.conduit_ent` seeds `conduit` as an alias. The cells
      // decide, and it takes two such columns to move the shape.
      expect(matchCsvHeader('Conduit'), CsvColumnTarget.pathway);
      final d = detect('Room,Cat6,Conduit\nAttic,4,1\n');
      expect(d.shape, CsvShape.wide);
      expect(d.mediaColumns, [1, 2]);
    });

    test('`Conduit` is a pathway when it holds names', () {
      final d = detect('Room,Cat6,Conduit\nAttic,4,LR-1\nGarage,2,LR-1\n');
      expect(d.shape, CsvShape.long);
    });

    test('a negative count is not a count', () {
      final d = detect('Room,Cat6,RG6\nAttic,4,-1\n');
      expect(d.shape, CsvShape.long);
    });
  });
}
