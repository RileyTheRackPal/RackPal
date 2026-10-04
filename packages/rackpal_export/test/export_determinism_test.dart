// §8.4's determinism, through the real export entry.
//
// =====================================================================
// WHAT IS CLAIMED: THE FILE, SINCE M6-I5
// =====================================================================
// §8.4 says "two exports of an unmodified project differ only in the date
// field". The pinned pdf 3.13.0 writes `sha256(DateTime.now() +
// Random.secure())` into the trailer `/ID` and the wall clock into
// `/CreationDate`, and exposes neither, so until M6-I5 (`#356`) the claim
// was narrowed to the DRAWN CONTENT and the last test here asserted that
// the FILES differed, keeping the limit visible.
//
// `deterministic_pdf.dart` now rewrites both tokens in place, at the same
// length, from `issuedAt` and from the file's own contents. So the claim
// is the whole file, and the last group asserts it: one document at one
// date is one file. If a `pdf` upgrade moves either token, that group goes
// red rather than a rewrite quietly doing nothing.
//
// =====================================================================
// WHY THIS FILE EXISTS SEPARATELY FROM sheet_furniture_pdf_test.dart
// =====================================================================
// A MUTATION SAID SO. That file proves the injected clock is honoured on a
// furniture-only render it assembles itself. Replacing `request.issuedAt`
// with `DateTime.now()` INSIDE `buildExportDocument`'s elevation branch
// passed the entire suite: nothing asserted the date on a sheet that had
// come out of the real entry point. §8.4's "no `DateTime.now()` outside
// the one date field" was therefore held by a comment, not a test.

import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

/// One rack, one device: a three-sheet set, which is the exit criterion's
/// own shape.
RackDocument _document() {
  final rack = Rack(
    id: const Uuid('rack-1'),
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: 24,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  return RackDocument(
    id: const Uuid('doc-1'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
    info: ProjectInfo(projectName: 'DETERMINISM FIXTURE'),
    racks: <Uuid, Rack>{rack.id: rack},
    devices: <Uuid, DeviceInstance>{
      const Uuid('d-1'): DeviceInstance(
        id: const Uuid('d-1'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('T1'),
          version: 1,
          contentHash: 'h',
        ),
        designator: 'AMP-1',
        name: 'Zone amp',
        placement: RailPlacement(
          rackId: rack.id,
          ruIndex: 4,
          face: Face.front,
        ),
        meta: _meta(),
      ),
    },
    templates: <String, TemplateSnapshot>{
      'T1@1': TemplateSnapshot(
        templateId: const TemplateId('T1'),
        version: 1,
        contentHash: 'h',
        body: TemplateBody(
          manufacturer: 'ACME',
          model: 'AMP-8',
          displayName: 'Eight-channel amp',
          frontU: 2,
          rearU: 2,
          side: OccupancySide.both,
        ),
        capturedAt: DateTime.utc(2026),
      ),
    },
  );
}

void main() {
  late Uint8List fontBytes;

  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  Future<Uint8List> export(DateTime issuedAt) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(_document()),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: 'fixture.rmpj',
        issuedAt: issuedAt,
      ),
    );
    return (result as Ok<ExportedDocument>).value.bytes;
  }

  /// Every page's operator stream, in file order.
  List<String> pages(Uint8List bytes) => <String>[
    for (final body in operatorStreams(bytes))
      if (body.contains(' re ') && body.contains('BT')) body,
  ];

  /// Every text run on every page.
  String allText(Uint8List bytes) {
    final cmap = parseToUnicodeCMap(bytes);
    return pages(
      bytes,
    ).map((b) => interpretContentStream(b, toUnicode: cmap).allText).join('\n');
  }

  group('the harness sees the whole set', () {
    test('eight sheets, the cover, legend and exceptions first, each with '
        'its own operator stream', () async {
      final bytes = await export(DateTime.utc(2026, 7, 18));
      // Without this the comparisons below could be comparing two empty
      // lists and passing. EIGHT SINCE M6-K (DR-222): the Pull Sheet and the
      // Termination Schedule are ON, so every set carries both.
      expect(pages(bytes), hasLength(8));
      for (final page in pages(bytes)) {
        expect(page.length, greaterThan(500));
      }
    });
  });

  group('content-stream determinism', () {
    test('two exports with the SAME injected date draw byte-identical '
        'content', () async {
      final at = DateTime.utc(2026, 7, 18);
      expect(pages(await export(at)), pages(await export(at)));
    });

    test('a DIFFERENT injected date changes the content', () async {
      expect(
        pages(await export(DateTime.utc(2026, 7, 18))),
        isNot(pages(await export(DateTime.utc(2027, 3, 9)))),
      );
    });
  });

  group('THE INJECTED CLOCK IS THE ONLY CLOCK (§8.4)', () {
    test('the injected date reaches EVERY sheet, and no other date '
        'does', () async {
      // The mutation this test exists for replaced `request.issuedAt` with
      // `DateTime.now()` in ONE branch of `buildExportDocument`. Asserting
      // per-sheet is what makes a single-branch substitution visible.
      final bytes = await export(DateTime.utc(2027, 3, 9));
      final cmap = parseToUnicodeCMap(bytes);
      final sheets = pages(bytes);

      expect(sheets, hasLength(8));
      for (var i = 0; i < sheets.length; i++) {
        final text = interpretContentStream(
          sheets[i],
          toUnicode: cmap,
        ).allText;
        expect(text, contains('2027-03-09'), reason: 'sheet ${i + 1}');
      }

      // ...and today's date does NOT appear anywhere on the drawing. A
      // wall-clock leak that happened to be run on the injected date would
      // pass the assertion above; this one names the specific way it
      // fails.
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(allText(bytes), isNot(contains(today)), reason: today);
    });

    test('a date one DAY apart still changes every sheet', () async {
      // A coarse leak (a year field taken from the clock, a date formatted
      // to the month) would survive a comparison of two dates a year
      // apart. One day is the finest thing the format carries.
      final a = await export(DateTime.utc(2026, 7, 18));
      final b = await export(DateTime.utc(2026, 7, 19));

      expect(allText(a), contains('2026-07-18'));
      expect(allText(b), contains('2026-07-19'));
      expect(pages(a), isNot(pages(b)));
    });
  });

  group('the export REFUSES rather than crashing', () {
    // ADDED BECAUSE A MUTATION SURVIVED. Both branches below are guards
    // with real copy behind them, and neither had a test — a production
    // branch nothing reads is a branch that is one edit from not working.

    test('a missing font is a reported refusal, not a null-check crash', () {
      // `PdfDiagramCanvas.drawText` does `_fonts[s.font]!`. Without the
      // pre-flight, a missing face surfaces halfway through rendering,
      // inside what the user experiences as "Export PDF", with a partly
      // built document and no message.
      expect(
        buildExportDocument(
          ExportRequest(
            documentJson: const JsonDocumentCodec().write(_document()),
            fontBytes: const <FontRef, Uint8List>{},
            fileName: 'fixture.rmpj',
            issuedAt: DateTime.utc(2026, 7, 18),
          ),
        ),
        completion(
          isA<Err<ExportedDocument>>().having(
            (e) => e.error,
            'error',
            isA<ExportFontMissing>(),
          ),
        ),
      );
    });

    test('a document with no racks is a reported refusal', () async {
      final rackless = RackDocument(
        id: const Uuid('empty'),
        appVersion: 'test',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: _meta(),
      );
      final result = await buildExportDocument(
        ExportRequest(
          documentJson: const JsonDocumentCodec().write(rackless),
          fontBytes: <FontRef, Uint8List>{_font: fontBytes},
          fileName: 'empty.rmpj',
          issuedAt: DateTime.utc(2026, 7, 18),
        ),
      );

      expect(result, isA<Err<ExportedDocument>>());
      expect((result as Err<ExportedDocument>).error, isA<ExportNoRacks>());
      // ...and it says so in a sentence, not a type name.
      expect((result.error as ExportError).message, contains('no racks'));
    });

    test('bytes that are not a document are a reported refusal', () async {
      final result = await buildExportDocument(
        ExportRequest(
          documentJson: Uint8List.fromList('not json'.codeUnits),
          fontBytes: <FontRef, Uint8List>{_font: fontBytes},
          fileName: 'junk.rmpj',
          issuedAt: DateTime.utc(2026, 7, 18),
        ),
      );

      expect(result, isA<Err<ExportedDocument>>());
      expect(
        (result as Err<ExportedDocument>).error,
        isA<ExportDocumentUnreadable>(),
      );
    });

    test('every ExportError carries a sentence a user can read', () {
      // A refusal that reaches the dialog as `Instance of ...` is a
      // refusal nobody can act on.
      for (final error in <ExportError>[
        const ExportNoRacks(),
        const ExportFontMissing(_font),
        const ExportDocumentUnreadable('cause'),
        const ExportTooManySheets(2001),
      ]) {
        expect(error.message, isNotEmpty);
        expect(error.message, isNot(contains('Instance of')));
        expect(error.message.trim().endsWith('.'), isTrue, reason: '$error');
      }
    });
  });

  group('THE FILE IS DETERMINISTIC (§8.4, M6-I5)', () {
    test('two exports at one date are ONE FILE, byte for byte', () async {
      final at = DateTime.utc(2026, 7, 18);
      expect(await export(at), await export(at));
    });

    test(
      'the creation date is the injected one, never the wall clock',
      () async {
        final bytes = await export(DateTime.utc(2027, 3, 9, 14, 5, 6));
        final text = String.fromCharCodes(bytes);
        expect(text, contains('/CreationDate(D:20270309140506Z)'));
      },
    );

    test('the ID is the contents: a different date or a different project '
        'is a different ID, and both slots agree', () async {
      final id = RegExp(r'/ID\[<([0-9a-f]{64})><([0-9a-f]{64})>\]');
      Match idOf(Uint8List b) => id.firstMatch(String.fromCharCodes(b))!;
      final a = idOf(await export(DateTime.utc(2026, 7, 18)));
      final b = idOf(await export(DateTime.utc(2026, 7, 19)));
      expect(a.group(1), a.group(2));
      expect(a.group(1), isNot(b.group(1)));
      expect(a.group(1), isNot('0' * 64), reason: 'the hash was written');
    });

    test(
      'the rewrite keeps the file readable: every sheet still parses',
      () async {
        expect(pages(await export(DateTime.utc(2026, 7, 18))), hasLength(8));
      },
    );

    test('a file whose tokens it does not recognise is returned '
        'untouched', () {
      final odd = Uint8List.fromList('%PDF-1.4 no tokens here'.codeUnits);
      expect(
        deterministicPdfBytes(odd, issuedAt: DateTime.utc(2026)),
        same(odd),
      );
    });
  });
}
