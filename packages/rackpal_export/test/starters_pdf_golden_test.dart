// THE FOUR STARTER PDFs, HELD AGAINST COMMITTED BYTES (DR-253).
//
// =====================================================================
// THE QUESTION THIS FILE EXISTS TO ANSWER
// =====================================================================
// docs/13 §4 called one item "genuinely unknown": whether the PDF's content
// streams survive a platform change. `export_determinism_test.dart` cannot
// say, because it compares two exports made in ONE process, and a platform
// difference is the same in both of them. A committed golden can: the bytes
// were written on Windows, and definition 2 (`azure-pipelines-macos.yml`,
// DR-255) runs this suite on macOS against them.
//
// A golden here is what DR-253 rules it is: a committed fixture compared
// exactly. No tolerance, on either platform. If the platforms disagree,
// the disagreement is docs/13's to record, not this file's to absorb.
//
// =====================================================================
// TWO LAYERS, BECAUSE THEY FAIL FOR DIFFERENT REASONS
// =====================================================================
// Every stream in the file is deflated by `dart:io`'s zlib (`pdf` 3.13.0's
// `defaultDeflate`), and the deflated bytes are a property of the SDK's
// zlib build as much as of the drawing. So each starter is asserted twice:
//
//   1. THE CONTENT. Every indirect object, its streams inflated and its
//      `/Length` (a compressed length) blanked, equals the golden's. This
//      is the docs/13 question itself: did the DRAWING come out the same?
//   2. THE FILE. The exported bytes equal the golden, byte for byte. This
//      is docs/08 §8.4's "one document at one date is one file", held
//      across machines rather than within one process.
//
// (2) failing while (1) passes says the encoding moved and the drawing did
// not. (1) failing names the object, the page it draws, and the first
// differing byte with context from both sides, so a run on a machine
// nobody can log into still says what moved.
//
// WHAT WAS PINNED BEFORE THIS WAS WRITTEN, from a census of the export
// path: the issue date is injected; `/CreationDate` and `/ID` are
// rewritten from it and from the contents (M6-I5, `deterministic_pdf.dart`);
// the starters are `eol=lf` and the font is `binary` in `.gitattributes`;
// no `Platform`, locale, time zone or hash-ordered collection is read
// anywhere in rackpal_export, rackpal_text or rackpal_core's lib. What is
// left is the SDK: its zlib, and the platform libm behind `math.sin`,
// `math.cos` and `math.pow`, which the scene and `pdf` itself call.
//
// Regenerate with `UPDATE_GOLDENS=1 flutter test test/starters_pdf_golden_
// test.dart`, as `byte_roundtrip_test.dart` does: a deliberate, reviewed
// step, and the diff on the four files is the change.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

const FontRef _font = FontRef('Jost');

const List<String> _starters = <String>[
  'apartment',
  'home_theatre',
  'small_office',
  'whole_house',
];

final bool _updateGoldens = Platform.environment['UPDATE_GOLDENS'] == '1';

/// One indirect object, read for comparison: its dictionary (or whole body,
/// for an object that is not a dictionary) with `/Length` blanked, and its
/// stream inflated when it is `/FlateDecode`.
class PdfObjectView {
  PdfObjectView(this.number, this.head, this.data);

  final int number;
  final String head;
  final Uint8List? data;

  bool get isXRef => head.contains('/Type/XRef');
}

/// Every indirect object in [pdf], keyed by object number.
///
/// SEQUENTIAL, NOT A REGEX OVER THE FILE: a stream is skipped by its own
/// `/Length`, so nothing is ever matched inside deflated bytes, where
/// `12 0 obj` can occur by chance.
Map<int, PdfObjectView> readPdfObjects(Uint8List pdf) {
  final text = latin1.decode(pdf);
  final header = RegExp(r'(\d+) 0 obj\s*');
  final out = <int, PdfObjectView>{};
  var at = 0;
  while (true) {
    final m = header.allMatches(text, at).firstOrNull;
    if (m == null) break;
    final number = int.parse(m.group(1)!);
    var i = m.end;
    String head;
    Uint8List? data;
    if (text.startsWith('<<', i)) {
      final end = _dictEnd(text, i);
      head = text.substring(i, end);
      i = end;
      final stream = RegExp(r'\s*stream\r?\n').matchAsPrefix(text, i);
      if (stream != null) {
        final length = int.parse(
          RegExp(r'/Length\s+(\d+)').firstMatch(head)!.group(1)!,
        );
        final raw = pdf.sublist(stream.end, stream.end + length);
        data = head.contains('/FlateDecode')
            ? Uint8List.fromList(zlib.decode(raw))
            : raw;
        i = stream.end + length;
      }
      i = text.indexOf('endobj', i);
    } else {
      final end = text.indexOf('endobj', i);
      head = text.substring(i, end).trim();
      i = end;
    }
    out[number] = PdfObjectView(
      number,
      head.replaceAll(RegExp(r'/Length\s+\d+'), '/Length ?'),
      data,
    );
    at = i + 'endobj'.length;
  }
  return out;
}

/// The offset just past the dictionary opening at [start], honouring
/// nested dictionaries, `(literal)` strings with escapes, and `<hex>`.
int _dictEnd(String text, int start) {
  var depth = 0;
  var i = start;
  while (i < text.length) {
    if (text.startsWith('<<', i)) {
      depth++;
      i += 2;
    } else if (text.startsWith('>>', i)) {
      depth--;
      i += 2;
      if (depth == 0) return i;
    } else if (text[i] == '(') {
      var nest = 0;
      for (; i < text.length; i++) {
        if (text[i] == r'\') {
          i++;
        } else if (text[i] == '(') {
          nest++;
        } else if (text[i] == ')' && --nest == 0) {
          break;
        }
      }
      i++;
    } else if (text[i] == '<') {
      i = text.indexOf('>', i) + 1;
    } else {
      i++;
    }
  }
  throw StateError('unterminated dictionary at $start');
}

/// What each object draws, for a reader of a failure: `sheet 3 content`
/// for a page's operator stream, its `/Type` otherwise.
Map<int, String> labelPdfObjects(Map<int, PdfObjectView> objects) {
  final labels = <int, String>{};
  for (final o in objects.values) {
    final type = RegExp(r'/Type/(\w+)').firstMatch(o.head)?.group(1);
    labels[o.number] = type ?? (o.data == null ? 'object' : 'stream');
  }
  final pages = objects.values
      .where((o) => o.head.contains('/Type/Pages'))
      .expand(
        (o) => RegExp(r'(\d+) 0 R').allMatches(
          RegExp(r'/Kids\[([^\]]*)\]').firstMatch(o.head)?.group(1) ?? '',
        ),
      )
      .map((m) => int.parse(m.group(1)!))
      .toList();
  for (var i = 0; i < pages.length; i++) {
    final page = objects[pages[i]];
    final contents = RegExp(
      r'/Contents (\d+) 0 R',
    ).firstMatch(page?.head ?? '');
    labels[pages[i]] = 'sheet ${i + 1} page';
    if (contents != null) {
      labels[int.parse(contents.group(1)!)] = 'sheet ${i + 1} content';
    }
  }
  return labels;
}

/// Every way [fresh]'s objects differ from [golden]'s, one line each,
/// naming the object, what it draws and the first differing byte. Empty
/// when the content is identical. The cross-reference stream is left out:
/// its body is byte offsets, which move whenever any deflated length does,
/// and the file comparison already holds it.
List<String> contentDifferences(Uint8List golden, Uint8List fresh) {
  final a = readPdfObjects(golden);
  final b = readPdfObjects(fresh);
  final labels = labelPdfObjects(a);
  final out = <String>[];
  final numbers = {...a.keys, ...b.keys}.toList()..sort();
  for (final n in numbers) {
    final x = a[n];
    final y = b[n];
    final name = 'obj $n (${labels[n] ?? 'new'})';
    if (x == null || y == null) {
      out.add('$name: only in the ${x == null ? 'export' : 'golden'}');
      continue;
    }
    if (x.isXRef && y.isXRef) continue;
    if (x.head != y.head) {
      out.add('$name dictionary: ${_firstDifference(x.head, y.head)}');
    }
    final xd = x.data == null ? '' : latin1.decode(x.data!);
    final yd = y.data == null ? '' : latin1.decode(y.data!);
    if (xd != yd) {
      out.add(
        '$name stream, ${xd.length} bytes in the golden and ${yd.length} '
        'exported: ${_firstDifference(xd, yd)}',
      );
    }
  }
  return out;
}

String _firstDifference(String golden, String fresh) {
  var i = 0;
  while (i < golden.length && i < fresh.length && golden[i] == fresh[i]) {
    i++;
  }
  String around(String s) {
    final from = (i - 40).clamp(0, s.length);
    final to = (i + 40).clamp(0, s.length);
    return jsonEncode(s.substring(from, to));
  }

  return 'first difference at byte $i, golden ${around(golden)}, exported '
      '${around(fresh)}';
}

void main() {
  late Uint8List fontBytes;

  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  Future<Uint8List> exportOf(String name) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: File(
          '../../apps/rackpal/assets/starters/$name.rppj',
        ).readAsBytesSync(),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: '$name.rppj',
        issuedAt: DateTime.utc(2026, 7, 18),
      ),
    );
    if (result case Err(:final error)) {
      fail('$name did not export: ${(error as ExportError).message}');
    }
    return (result as Ok<ExportedDocument>).value.bytes;
  }

  File goldenOf(String name) => File('test/fixtures/starters/$name.pdf');

  /// The committed bytes, or a failure that says they are an INPUT.
  Uint8List readGolden(String name) {
    final file = goldenOf(name);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the golden test/fixtures/starters/$name.pdf is missing. It is a '
          'checked-in INPUT, not an output: regenerate deliberately with '
          'UPDATE_GOLDENS=1 and commit the diff.',
    );
    return file.readAsBytesSync();
  }

  for (final name in _starters) {
    group('$name.rppj', () {
      test("(1) THE CONTENT: every object, inflated, is the golden's "
          '(docs/13 §4)', () async {
        final fresh = await exportOf(name);
        if (_updateGoldens) {
          goldenOf(name)
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(fresh);
          markTestSkipped('UPDATE_GOLDENS=1: regenerated $name');
          return;
        }
        final golden = readGolden(name);

        // NOT VACUOUS: the reader reached every sheet's operator stream, and
        // each one draws text. Two empty object maps would compare equal.
        final objects = readPdfObjects(golden);
        final labels = labelPdfObjects(objects);
        final drawn = [
          for (final o in objects.values)
            if (labels[o.number]!.endsWith(' content')) o,
        ];
        final tree = objects.values.firstWhere(
          (o) => o.head.contains('/Type/Pages'),
        );
        final sheets = RegExp(r'/Count (\d+)').firstMatch(tree.head)!;
        expect(drawn, hasLength(int.parse(sheets.group(1)!)));
        for (final o in drawn) {
          expect(
            latin1.decode(o.data!),
            contains(']TJ'),
            reason: labels[o.number],
          );
        }

        final differences = contentDifferences(golden, fresh);
        expect(
          differences,
          isEmpty,
          reason:
              'the DRAWING of $name differs from the golden written on '
              'Windows. If this run is not on Windows, this is the docs/13 '
              '§4 finding and belongs there as a D-row; if the change is '
              'intended, regenerate with UPDATE_GOLDENS=1.\n'
              '${differences.join('\n')}',
        );
      });

      test('(2) THE FILE: the export is the golden byte for byte '
          '(docs/08 §8.4)', () async {
        if (_updateGoldens) {
          markTestSkipped('UPDATE_GOLDENS=1: (1) regenerated $name');
          return;
        }
        final golden = readGolden(name);
        final fresh = await exportOf(name);
        if (sha256.convert(fresh) == sha256.convert(golden)) return;

        // Said as one sentence a log reader can act on, not a 60 KB list
        // dump: where the bytes part, and whether the drawing parted too.
        var at = 0;
        while (at < golden.length &&
            at < fresh.length &&
            golden[at] == fresh[at]) {
          at++;
        }
        final verdict = contentDifferences(golden, fresh).isEmpty
            ? "Every object INFLATES to the golden's, so the drawing is "
                  'identical and the ENCODING moved: the deflated bytes, and '
                  'the offsets that follow them.'
            : 'The drawing differs too; (1) names where.';
        fail(
          "$name.pdf is ${fresh.length} bytes against the golden's "
          '${golden.length}, first differing at byte $at (sha256 '
          '${sha256.convert(fresh)} against ${sha256.convert(golden)}). '
          '$verdict',
        );
      });
    });
  }

  group('the comparison can see a difference', () {
    // A comparison that cannot fail proves nothing on either platform. So a
    // single byte is changed inside one sheet's operator stream, the stream
    // re-deflated and the file rebuilt around it, and the change must be
    // named, by object and by sheet, and nothing else with it.
    test('one byte changed in one sheet is that sheet and no other '
        'object', () {
      final golden = readGolden('apartment');
      final objects = readPdfObjects(golden);
      final labels = labelPdfObjects(objects);
      final target = objects.values.firstWhere(
        (o) => labels[o.number] == 'sheet 2 content',
      );
      final drawn = latin1.decode(target.data!);
      final at = drawn.indexOf(']TJ');
      final changed = Uint8List.fromList(
        latin1.encode(drawn.replaceRange(at, at + 3, ']Tj')),
      );

      final mutated = _replaceStream(golden, target.number, changed);
      final differences = contentDifferences(golden, mutated);

      expect(differences, hasLength(1));
      expect(differences.single, startsWith('obj ${target.number} '));
      expect(differences.single, contains('(sheet 2 content) stream'));
      expect(differences.single, contains('first difference at byte '));
    });

    test('an identical file has no differences', () {
      final golden = readGolden('whole_house');
      expect(contentDifferences(golden, Uint8List.fromList(golden)), isEmpty);
    });
  });
}

/// [pdf] with object [number]'s stream replaced by [data], deflated, and
/// its `/Length` corrected. The cross-reference offsets are left stale,
/// which the object reader never consults.
Uint8List _replaceStream(Uint8List pdf, int number, Uint8List data) {
  final text = latin1.decode(pdf);
  final start = text.indexOf('\n$number 0 obj') + 1;
  final streamAt = text.indexOf('stream\n', start) + 'stream\n'.length;
  final head = text.substring(start, streamAt);
  final length = int.parse(
    RegExp(r'/Length\s+(\d+)').firstMatch(head)!.group(1)!,
  );
  final deflated = zlib.encode(data);
  final newHead = head.replaceFirst(
    RegExp(r'/Length\s+\d+'),
    '/Length ${deflated.length}',
  );
  return Uint8List.fromList([
    ...pdf.sublist(0, start),
    ...latin1.encode(newHead),
    ...deflated,
    ...pdf.sublist(streamAt + length),
  ]);
}
