// rackmate_core/src/structure/csv_reader.dart — pure Dart.
//
// TEXT IN, A TABLE OF STRINGS OUT. Board M3-F/5 (#651), docs/07 §5,
// AC-058/D8.
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE KNOWS NOTHING ABOUT A DOCUMENT, AND THAT IS THE POINT
// ═════════════════════════════════════════════════════════════════════
// `drop_line_parser.dart` states the same rule for the typed DSL and the
// reason carries over unchanged: a parser that needs a `RackDocument` to
// be tested cannot be tested at the speed a bulk-entry path has to be
// iterated on. So [readCsv] takes a `String` and returns rows of
// strings. Which column is which is #159's table; which cable a cell
// names is the document's registry; which `Link` a row becomes is
// M3-F/6. None of those live here.
//
// The one function in this file that does read a registry is
// [detectCsvShape], and it takes one as an argument rather than reaching
// for a document, for the same reason.
//
// ═════════════════════════════════════════════════════════════════════
// RAGGED ROWS ARE DATA. THE FILE ITSELF CAN STILL BE REFUSED
// ═════════════════════════════════════════════════════════════════════
// docs/07 §5.3: "Import is never fail-fast." That is a rule about ROWS,
// and it is honoured exactly: a short row pads with empty cells, a long
// row keeps its overflow in [CsvRow.overflow] rather than dropping it,
// and both reach the preview grid where a person can see them.
//
// It is NOT a rule that every byte sequence is a CSV. A file whose
// quoting never closes, or that is larger than [CsvLimits] allows, is
// refused as a whole with a sentence, because the alternative is
// importing four hundred rows as one cell and calling it success.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/structure/csv_header_map.dart';
import 'package:rackmate_core/src/structure/drop_line_planner.dart'
    show resolveMediaToken;

/// The ceilings every import path enforces (AC-058/D8).
///
/// **THE NUMBERS ARE ANCHORED RATHER THAN ROUND**, because a limit
/// nobody can derive is a limit somebody raises the first time it fires.
/// M3's exit criterion is a 60-drop whole-house rough-in. A large
/// commercial job is a few thousand drops. [maxRows] is 50,000, roughly
/// ten times the largest job this product claims to serve, and
/// [maxCharacters] is 8 MiB, which at the ~150 bytes a populated
/// long-shape row occupies is the same order as [maxRows] rather than an
/// independent guess. [maxFields] is 512 against a canonical column set
/// of nineteen: a wide-shape sheet carries one column per media type,
/// the seeded registry has fourteen, and RJ-009 lets a shop add more.
///
/// Exceeding one is a REFUSAL WITH A REASON and never a truncation. A
/// silently truncated import is the worst outcome available here: it
/// looks like it worked.
@immutable
final class CsvLimits {
  const CsvLimits({
    this.maxCharacters = 8 * 1024 * 1024,
    this.maxRows = 50000,
    this.maxFields = 512,
  });

  /// The cap that exists for the machine rather than the job.
  ///
  /// CHARACTERS, NOT BYTES, and named for what it counts. [readCsv]
  /// takes a decoded `String`, so a byte ceiling is the reading side's
  /// to enforce before it decodes; claiming one here would be a limit
  /// measured in the wrong unit for every non-ASCII file.
  final int maxCharacters;

  /// Data rows, not counting the header.
  final int maxRows;

  /// Fields in any one record, header included.
  final int maxFields;

  static const CsvLimits standard = CsvLimits();
}

/// Why [readCsv] refused a whole file.
///
/// Every value here is a fact about the FILE. Nothing a single row can
/// do produces one of these; that is [CsvRow]'s job and the preview
/// grid's.
enum CsvRefusal {
  /// Nothing but whitespace, or nothing at all.
  empty,

  /// A field opened with `"` and the file ended before it closed.
  unterminatedQuote,

  /// The header row parsed as a single field that contains a `;` or a
  /// tab. See [readCsv] for why this is a refusal and not a sniff.
  wrongDelimiter,

  /// [CsvLimits.maxCharacters].
  tooLarge,

  /// [CsvLimits.maxRows].
  tooManyRows,

  /// [CsvLimits.maxFields].
  tooManyFields,
}

/// The outcome of [readCsv].
sealed class CsvRead {
  const CsvRead();
}

/// The file parsed. Rows may still be ragged and cells may still be
/// nonsense; both are the preview grid's to show.
@immutable
final class CsvReadOk extends CsvRead {
  const CsvReadOk(this.table);

  final CsvTable table;
}

/// The file was not read, with a sentence a person can act on.
@immutable
final class CsvReadRefused extends CsvRead {
  const CsvReadRefused(this.reason, this.message, {this.line});

  final CsvRefusal reason;

  /// One sentence, already written for a human. Surfaces show it
  /// verbatim rather than mapping [reason] to their own wording, so that
  /// the reason a file was refused is stated in one place.
  final String message;

  /// 1-based source line, where the refusal has one.
  final int? line;
}

/// One record, as strings, in source order.
@immutable
final class CsvRow {
  const CsvRow({
    required this.line,
    required this.cells,
    this.overflow = const [],
  });

  /// 1-based source line on which this record STARTS.
  ///
  /// Not the row index: a quoted cell may contain newlines, so the tenth
  /// record can begin on the fortieth line, and the number a person
  /// needs in order to find the row in Excel is this one.
  final int line;

  /// Exactly `CsvTable.headers.length` cells, padded with `''` where the
  /// source row was short.
  final List<String> cells;

  /// Fields beyond the header count, KEPT.
  ///
  /// A row longer than its header is usually an unescaped comma inside a
  /// notes cell, and the text after that comma is the half a person
  /// most wants to see. Dropping it would be the silent discard
  /// docs/04 §3.4 forbids.
  final List<String> overflow;

  bool get isRagged => overflow.isNotEmpty;
}

/// A header row and its records.
@immutable
final class CsvTable {
  const CsvTable({
    required this.headers,
    required this.rows,
    required this.blankLinesSkipped,
  });

  /// AS TYPED. Not normalised, not trimmed of case, not de-duplicated.
  ///
  /// The mapping sheet shows a person the header from their own
  /// spreadsheet, so the original spelling has to survive to it;
  /// [matchCsvHeader] normalises at the point of comparison. Two columns
  /// may carry the same header, which is not an error here and is a
  /// question the mapping sheet asks.
  final List<String> headers;

  final List<CsvRow> rows;

  /// Wholly empty lines dropped between records, COUNTED.
  ///
  /// Hand-edited pull lists carry blank separator lines and a row of one
  /// empty field is not a drop, so they are skipped. The count exists
  /// because G4's rule is that nothing is discarded without being
  /// reported, even when the discarded thing is nothing.
  final int blankLinesSkipped;
}

const int _quote = 0x22;
const int _comma = 0x2c;
const int _cr = 0x0d;
const int _lf = 0x0a;
const int _bom = 0xfeff;

/// Reads RFC 4180 CSV: comma-separated, `"`-quoted, `""` for a literal
/// quote inside a quoted field.
///
/// **COMMA ONLY, AND THE ALTERNATIVE IS DIAGNOSED RATHER THAN GUESSED.**
/// Sniffing a delimiter means choosing between `,`, `;` and tab by
/// counting them, which is a heuristic, and the file it gets wrong is
/// the one with semicolons inside its notes. So a header row that parses
/// as a single field containing a `;` or a tab is REFUSED with
/// [CsvRefusal.wrongDelimiter] and a sentence naming what was found.
/// That is strictly more useful than a sniff: the operator learns what
/// to change, and no file is ever parsed the wrong way silently. If a
/// semicolon dialect later has to be read, it is a ruling and a
/// user-visible choice, not a counter.
///
/// **EMBEDDED LINE ENDINGS INSIDE A QUOTED CELL NORMALISE TO `\n`.** A
/// cell's content must not differ by invisible characters according to
/// which machine exported the file, because §5.3's drop dedup compares
/// `fieldLabel` strings and its update guard compares notes: a CRLF that
/// survives into a cell makes a row differ from itself across two
/// exports of the same sheet, and nothing on screen shows why.
///
/// Never throws. Every failure is a [CsvReadRefused].
CsvRead readCsv(String text, {CsvLimits limits = CsvLimits.standard}) {
  if (text.length > limits.maxCharacters) {
    return CsvReadRefused(
      CsvRefusal.tooLarge,
      'This file is ${text.length} characters, over the '
      '${limits.maxCharacters}-character import limit.',
    );
  }

  final source = text.isNotEmpty && text.codeUnitAt(0) == _bom
      ? text.substring(1)
      : text;

  final records = <_Record>[];
  final field = StringBuffer();
  var record = <String>[];
  var line = 1;
  var recordLine = 1;
  var inQuotes = false;
  var sawAnyField = false;
  var blankLines = 0;

  void endField() {
    record.add(field.toString());
    field.clear();
    sawAnyField = true;
  }

  void endRecord() {
    endField();
    records.add(_Record(recordLine, record));
    record = <String>[];
    sawAnyField = false;
  }

  var i = 0;
  while (i < source.length) {
    final c = source.codeUnitAt(i);

    if (inQuotes) {
      if (c == _quote) {
        // `""` is one literal quote; a lone `"` closes the field.
        if (i + 1 < source.length && source.codeUnitAt(i + 1) == _quote) {
          field.writeCharCode(_quote);
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      // Normalise CRLF and a lone CR to `\n`; see the doc comment.
      if (c == _cr) {
        field.writeCharCode(_lf);
        line++;
        if (i + 1 < source.length && source.codeUnitAt(i + 1) == _lf) i++;
        i++;
        continue;
      }
      if (c == _lf) line++;
      field.writeCharCode(c);
      i++;
      continue;
    }

    if (c == _quote && field.isEmpty) {
      inQuotes = true;
      i++;
      continue;
    }
    if (c == _comma) {
      endField();
      if (record.length + 1 > limits.maxFields) {
        return CsvReadRefused(
          CsvRefusal.tooManyFields,
          'Line $recordLine has more than ${limits.maxFields} columns.',
          line: recordLine,
        );
      }
      i++;
      continue;
    }
    if (c == _cr || c == _lf) {
      if (c == _cr &&
          i + 1 < source.length &&
          source.codeUnitAt(i + 1) == _lf) {
        i++;
      }
      line++;
      i++;
      // A wholly empty line is a separator, not a record of one empty
      // field. `blankLinesSkipped` counts them.
      if (!sawAnyField && field.isEmpty && record.isEmpty) {
        blankLines++;
        recordLine = line;
        continue;
      }
      endRecord();
      recordLine = line;
      continue;
    }

    field.writeCharCode(c);
    i++;
  }

  if (inQuotes) {
    return CsvReadRefused(
      CsvRefusal.unterminatedQuote,
      'A quoted value opened on line $recordLine and never closed.',
      line: recordLine,
    );
  }
  // A trailing newline must not produce a final empty record.
  if (sawAnyField || field.isNotEmpty || record.isNotEmpty) endRecord();

  // A line of nothing but commas is a real (empty) row and survives.
  // A line of nothing but SPACES produced one whitespace-only field and
  // reached here rather than the lexer's blank-line arm, so it is
  // counted in the same total.
  var blanks = blankLines;
  final kept = <_Record>[];
  for (final r in records) {
    if (r.fields.length == 1 && r.fields.single.trim().isEmpty) {
      blanks++;
      continue;
    }
    kept.add(r);
  }

  if (kept.isEmpty) {
    return const CsvReadRefused(
      CsvRefusal.empty,
      'This file has no rows.',
    );
  }

  final headerRecord = kept.first;
  final headers = headerRecord.fields.map((f) => f.trim()).toList();

  if (headers.length == 1 &&
      (headers.single.contains(';') || headers.single.contains('\t'))) {
    final found = headers.single.contains(';') ? 'semicolons' : 'tabs';
    return CsvReadRefused(
      CsvRefusal.wrongDelimiter,
      'This file separates its columns with $found. RackMate reads '
      'comma-separated CSV; re-export or save it with commas.',
      line: headerRecord.line,
    );
  }
  if (headers.length > limits.maxFields) {
    return CsvReadRefused(
      CsvRefusal.tooManyFields,
      'This file has ${headers.length} columns, over the '
      '${limits.maxFields}-column import limit.',
      line: headerRecord.line,
    );
  }
  if (kept.length - 1 > limits.maxRows) {
    return CsvReadRefused(
      CsvRefusal.tooManyRows,
      'This file has ${kept.length - 1} rows, over the '
      '${limits.maxRows}-row import limit.',
      line: headerRecord.line,
    );
  }

  final rows = <CsvRow>[];
  for (final r in kept.skip(1)) {
    final cells = <String>[];
    final overflow = <String>[];
    for (var n = 0; n < r.fields.length; n++) {
      if (n < headers.length) {
        cells.add(r.fields[n]);
      } else {
        overflow.add(r.fields[n]);
      }
    }
    while (cells.length < headers.length) {
      cells.add('');
    }
    rows.add(CsvRow(line: r.line, cells: cells, overflow: overflow));
  }

  return CsvReadOk(
    CsvTable(headers: headers, rows: rows, blankLinesSkipped: blanks),
  );
}

@immutable
final class _Record {
  const _Record(this.line, this.fields);
  final int line;
  final List<String> fields;
}

/// Which of docs/07 §5's two shapes a file is.
enum CsvShape {
  /// One row per drop. The shape [kRequiredLongShapeTargets] governs.
  long,

  /// Rooms as rows, media as numeric columns. How pull lists actually
  /// look.
  wide,
}

/// [detectCsvShape]'s answer.
///
/// A RECOMMENDATION AND NOT A VERDICT. docs/07 §5 says wide mode is
/// "OFFERED" when the test passes, so the surface presents this with a
/// way to overrule it. [reason] is what it shows next to the choice.
@immutable
final class CsvShapeDetection {
  const CsvShapeDetection({
    required this.shape,
    required this.mediaColumns,
    required this.reason,
  });

  final CsvShape shape;

  /// Header indexes whose header names a media type and whose cells are
  /// all counts. Empty when [shape] is [CsvShape.long].
  final List<int> mediaColumns;

  /// One sentence, for the surface to print beside the offer.
  final String reason;
}

/// docs/07 §5's test, verbatim: wide when "≥ 2 headers resolve to media
/// synonyms *and* their cells are numeric".
///
/// **THE HEADERS RESOLVE AGAINST THE DOCUMENT'S REGISTRY, NOT AGAINST
/// #159's TABLE**, and the distinction is that file's own finding. Which
/// COLUMN a header names is a fixed set; which CABLE it names is open,
/// per document, and already shipped as `MediaTypeDef.aliases` under
/// DR-010 and RJ-009. A wide sheet's headers are cables, so
/// [resolveMediaToken] is the right resolver and `matchCsvHeader` is
/// not.
///
/// ═════════════════════════════════════════════════════════════════════
/// `Conduit` IS BOTH THINGS, AND THE NUMERIC TEST IS WHAT SEPARATES THEM
/// ═════════════════════════════════════════════════════════════════════
/// `matchCsvHeader('conduit')` is `CsvColumnTarget.pathway`; docs/07
/// §5.1's media block maps `conduit / smurf / ent` to
/// `media.conduit_ent`. One word, two meanings, and both are correct:
/// a `Conduit` column holding `LR-1` names a pathway, and one holding
/// `2` counts a cable. The cells decide, and because the test needs TWO
/// such columns, an ambiguous one on its own can never flip a long file
/// into a wide one by itself.
///
/// **AN EXPLICIT MEDIA COLUMN SETTLES IT AS LONG.** A sheet carrying
/// `Cable Type` has declared how it says which cable a row is, so
/// numeric columns beside it are something else the operator will map
/// by hand. Detecting wide there would silently reinterpret every row.
CsvShapeDetection detectCsvShape(CsvTable table, Registries registries) {
  for (var n = 0; n < table.headers.length; n++) {
    if (matchCsvHeader(table.headers[n]) == CsvColumnTarget.media) {
      return CsvShapeDetection(
        shape: CsvShape.long,
        mediaColumns: const [],
        reason:
            'Column "${table.headers[n]}" says which cable each row '
            'is, so every row is one drop.',
      );
    }
  }

  final mediaColumns = <int>[];
  for (var n = 0; n < table.headers.length; n++) {
    if (resolveMediaToken(registries, table.headers[n]) == null) continue;
    if (!_columnIsCounts(table, n)) continue;
    mediaColumns.add(n);
  }

  if (mediaColumns.length < 2) {
    return CsvShapeDetection(
      shape: CsvShape.long,
      mediaColumns: const [],
      reason: mediaColumns.isEmpty
          ? 'No column header names a cable, so every row is one drop.'
          : 'Only one column header names a cable, so every row is one '
                'drop.',
    );
  }

  final names = mediaColumns.map((n) => table.headers[n]).join(', ');
  return CsvShapeDetection(
    shape: CsvShape.wide,
    mediaColumns: mediaColumns,
    reason:
        '${mediaColumns.length} columns are cable counts ($names), so '
        'each row is a room.',
  );
}

/// Every non-empty cell in column [index] is a non-negative whole
/// number.
///
/// **BLANK COUNTS AS A COUNT, AND IT IS NOT ZERO YET.** A wide pull list
/// leaves the speaker column empty for rooms with no speakers, so
/// requiring every cell to be filled would reject the shape the test
/// exists to find. What a blank MEANS is M3-F/6's question under G4, and
/// this function deliberately does not answer it: it only says the
/// column is not holding words.
///
/// A column that is entirely blank is not evidence of anything and does
/// not count.
bool _columnIsCounts(CsvTable table, int index) {
  var sawOne = false;
  for (final row in table.rows) {
    final cell = row.cells[index].trim();
    if (cell.isEmpty) continue;
    final n = int.tryParse(cell);
    if (n == null || n < 0) return false;
    sawOne = true;
  }
  return sawOne;
}
