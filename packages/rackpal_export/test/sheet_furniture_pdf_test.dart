// SHEET FURNITURE, END TO END, ASSERTED ON THE BYTES A VIEWER CONSUMES.
//
// The core tests prove the layout arithmetic of the furniture against a
// fake measurer. This one proves that the arithmetic survives the whole
// pipeline -- `buildSheetFurniture` -> `DiagramScene` -> `PdfDiagramCanvas`
// -> `pw.Page` -> `doc.save()` -- and lands on the paper where it was
// supposed to, in PDF USER SPACE, with the REAL bundled TTF and the REAL
// `PdfFontMeasurer`.
//
// It is the test that would catch:
//   * a Y-flip about the wrong height (the section 7.4 gotcha) -- the
//     ABSOLUTE user-space position of the frame is asserted, not merely its
//     size, and the title block is deliberately asymmetric in Y;
//   * a page format whose /MediaBox disagrees with the furniture layout;
//   * text that is composed but never emitted;
//   * a stroke that reaches the paper at zero width.
//
// Every expectation is computed from LITERALS -- 792, 1224, 54, 36, 6 --
// and never from the output of `SheetGeometry`.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

// -- the paper, from literals ---------------------------------------------
const double _pageW = 792;
const double _pageH = 1224;
const double _marginL = 54;
const double _marginT = 36;
const double _marginR = 36;
const double _marginB = 36;
const double _inset = 6;

const FontRef _font = FontRef('Jost');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

Rack _rack() => Rack(
  id: const Uuid('rack-1'),
  name: 'MASTER RACK',
  designator: 'RK-1',
  heightU: 42,
  order: const FracIndex('a0'),
  meta: _meta(),
);

ProjectInfo _info() => ProjectInfo(
  projectName: 'SMITH RESIDENCE',
  projectNumber: '25-1183',
  clientName: 'J. & M. Smith',
  siteAddress: Address(
    line1: '1428 Alder Ct',
    city: 'Portland',
    region: 'OR',
    postalCode: '97214',
  ),
  integratorName: 'NBS INTEGRATION LLC',
  integratorContact: '(503) 555-0142',
  integratorLicense: 'OR CCB #219884',
  drawnBy: 'J.S.',
);

void main() {
  late Uint8List fontBytes;

  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  /// Builds a one-sheet PDF carrying only furniture, and returns its bytes.
  Future<Uint8List> renderFurniture({
    List<RevisionEntry> revisions = const <RevisionEntry>[],
    SheetSize size = SheetSize.ansiBPortrait,
    DrawingScale? scale,
    DateTime? issuedAt,
  }) async {
    final doc = pw.Document(compress: false);
    final font = PdfTtfFont(doc.document, ByteData.sublistView(fontBytes));
    final fonts = <FontRef, PdfFont>{_font: font};
    final measurer = PdfFontMeasurer(fonts);

    final set = SheetSet.forRacks(<Rack>[_rack()]);
    final sheet = set.sheets.firstWhere((s) => s.size == size);

    final furniture = buildSheetFurniture(
      sheet: sheet,
      info: _info(),
      settings: ProjectSettings(),
      rack: sheet.role.perRack ? _rack() : null,
      revisions: revisions,
      scale: scale ?? DrawingScale.standard(8),
      fileName: 'smith.rmpj',
      issuedAt: issuedAt ?? DateTime.utc(2026, 7, 18),
      measurer: measurer,
    );

    doc.addPage(
      buildSheetPage(
        size: size,
        scene: furniture.scene,
        fonts: fonts,
        measurer: measurer,
      ),
    );
    return doc.save();
  }

  RecoveredStream recover(Uint8List bytes) => interpretContentStream(
    extractOperatorStream(bytes, mustContain: ' re '),
    toUnicode: parseToUnicodeCMap(bytes),
  );

  group('the harness finds real content (guard against a vacuous suite)', () {
    test('rectangles and text are both recovered, and they differ', () async {
      final recovered = recover(await renderFurniture());

      expect(
        recovered.rects.length,
        greaterThanOrEqualTo(3),
        reason: 'frame x2 + title block outline at minimum',
      );
      expect(
        recovered.rects.map((r) => '${r.left},${r.bottom},${r.width}').toSet(),
        hasLength(greaterThan(1)),
        reason: 'if every rect were identical, the CTM walk is broken',
      );
      expect(recovered.texts.length, greaterThanOrEqualTo(10));
    });
  });

  group('the border lands where the paper says it should', () {
    test('the outer rule is the margin box in USER SPACE', () async {
      final recovered = recover(await renderFurniture());

      // 792 - 54 - 36 = 702 wide, 1224 - 36 - 36 = 1152 tall. In user
      // space (Y-UP) the bottom edge is `marginBottom` above the page
      // bottom and the top edge is `pageH - marginTop`.
      final outer = recovered.rects.firstWhere(
        (r) => (r.width - 702).abs() < 0.01,
        orElse: () => throw StateError('no 702 pt wide rectangle emitted'),
      );

      expect(outer.left, closeTo(_marginL, 1e-3));
      expect(outer.right, closeTo(_pageW - _marginR, 1e-3));
      expect(outer.bottom, closeTo(_marginB, 1e-3));
      expect(outer.top, closeTo(_pageH - _marginT, 1e-3));
      expect(outer.height, closeTo(1152, 1e-3));
    });

    test('the inner rule is 6 pt inside it: 690 x 1140 at (60, 42)', () async {
      final recovered = recover(await renderFurniture());
      final inner = recovered.rects.firstWhere(
        (r) => (r.width - 690).abs() < 0.01,
        orElse: () => throw StateError('no 690 pt wide rectangle emitted'),
      );

      expect(inner.left, closeTo(_marginL + _inset, 1e-3));
      expect(inner.right, closeTo(_pageW - _marginR - _inset, 1e-3));
      expect(inner.bottom, closeTo(_marginB + _inset, 1e-3));
      expect(inner.top, closeTo(_pageH - _marginT - _inset, 1e-3));
      expect(inner.height, closeTo(1140, 1e-3));
    });

    test(
      'the rules reach the paper at 0.7 and 1.0 pt, never at zero',
      () async {
        final recovered = recover(await renderFurniture());
        final outer = recovered.rects.firstWhere(
          (r) => (r.width - 702).abs() < 0.01,
        );
        final inner = recovered.rects.firstWhere(
          (r) => (r.width - 690).abs() < 0.01,
        );

        expect(outer.lineWidthPt, closeTo(0.7, 1e-6));
        expect(inner.lineWidthPt, closeTo(1.0, 1e-6));
        // CR-082 / divergence 14: no stroke is EVER emitted at 0.
        for (final rect in recovered.rects) {
          expect(rect.lineWidthPt, greaterThanOrEqualTo(0.25 - 1e-9));
        }
      },
    );
  });

  group('the title block lands bottom-right', () {
    test(
      'a 396 x 115 rectangle sits in the bottom-right of the frame',
      () async {
        final recovered = recover(await renderFurniture());

        final title = recovered.rects.firstWhere(
          (r) => (r.width - 396).abs() < 0.01 && (r.height - 115).abs() < 0.01,
          orElse: () =>
              throw StateError('no 396 x 115 title block rectangle emitted'),
        );

        // Bottom-right of the drawing frame: right edge at
        // 792 - 36 - 6 = 750, bottom edge at 36 + 6 = 42 in user space.
        expect(title.right, closeTo(_pageW - _marginR - _inset, 1e-3));
        expect(title.bottom, closeTo(_marginB + _inset, 1e-3));
        expect(title.left, closeTo(_pageW - _marginR - _inset - 396, 1e-3));
      },
    );

    test('THE Y-FLIP CHECK: the title block is at the BOTTOM of the sheet, '
        'not mirrored to the top', () async {
      // The border assertions above are symmetric in Y once the top and
      // bottom margins are equal, so a flip about the wrong height could
      // still satisfy them. This one cannot be: the title block is
      // deliberately asymmetric in Y.
      final recovered = recover(await renderFurniture());
      final title = recovered.rects.firstWhere(
        (r) => (r.width - 396).abs() < 0.01 && (r.height - 115).abs() < 0.01,
      );

      expect(title.top, lessThan(_pageH / 2));
      expect(title.bottom, closeTo(42, 1e-3));
    });

    test(
      'every resolved field is text that ACTUALLY reaches the page',
      () async {
        // Modelled-but-never-drawn is the failure a field-level assertion
        // would miss entirely.
        final text = recover(await renderFurniture()).allText;

        for (final expected in <String>[
          'SMITH RESIDENCE',
          'MASTER RACK',
          '1428 Alder Ct, Portland, OR 97214',
          'CLIENT  J. & M. Smith',
          'RACK ELEVATION',
          'DRAWN',
          'J.S.',
          'SCALE',
          '1:8',
          'SIZE',
          'DATE',
          '2026-07-18',
          'PROJ',
          '25-1183',
          'DISC',
          'FILE',
          'smith.rmpj',
          'NBS INTEGRATION LLC',
          'SHEET 1 OF 3',
          'SHEET NO.  T2.01',
        ]) {
          expect(text, contains(expected), reason: expected);
        }
      },
    );

    test('an NTS sheet prints NTS on the paper, not a nearby ratio', () async {
      final bytes = await renderFurniture(
        scale: DrawingScale.fitted(
          sceneFactorForRatio(PhysicalRatio.oneOver(8.34)),
        ),
      );
      final text = recover(bytes).allText;

      expect(text, contains('NTS'));
      expect(text, isNot(contains('1:8')));
    });

    test(
      'no text run reaches the page at a size below the 6 pt floor',
      () async {
        final recovered = recover(await renderFurniture());
        expect(recovered.texts, isNotEmpty);
        for (final run in recovered.texts) {
          expect(
            run.sizePt,
            greaterThanOrEqualTo(6.0 - 1e-6),
            reason: run.text,
          );
        }
      },
    );
  });

  group('the revision block', () {
    test('with no history, one honest sentence reaches the paper', () async {
      final text = recover(await renderFurniture()).allText;

      expect(text, contains('NO REVISIONS RECORDED'));
      expect(text, contains('DESCRIPTION'));
      // Nothing fabricated, and no pointer to a sheet not in this file.
      expect(text, isNot(contains('T0.00')));
      expect(text, isNot(contains('Initial issue')));
    });

    test('with history, the entries reach the paper and the newest is '
        'highest on it', () async {
      final bytes = await renderFurniture(
        revisions: <RevisionEntry>[
          RevisionEntry(
            revision: 'A',
            date: DateTime.utc(2026, 3, 2),
            description: 'Issued for review',
            by: 'JS',
          ),
          RevisionEntry(
            revision: 'B',
            date: DateTime.utc(2026, 7, 18),
            description: 'Added AMP-2',
            by: 'JS',
          ),
        ],
      );
      final recovered = recover(bytes);

      expect(recovered.allText, contains('Issued for review'));
      expect(recovered.allText, contains('Added AMP-2'));

      // In USER SPACE (Y-up), higher on the page is a LARGER Y.
      double yOf(String needle) =>
          recovered.texts.firstWhere((t) => t.text == needle).baselineY;
      expect(yOf('Added AMP-2'), greaterThan(yOf('Issued for review')));
      expect(yOf('Issued for review'), greaterThan(yOf('DESCRIPTION')));
    });

    test(
      'the block grows upward from the title block as rows are added',
      () async {
        final recovered = recover(
          await renderFurniture(
            revisions: <RevisionEntry>[
              for (var i = 1; i <= 4; i++)
                RevisionEntry(
                  revision: 'R$i',
                  date: DateTime.utc(2026, i),
                  description: 'change $i',
                  by: 'JS',
                ),
            ],
          ),
        );

        // 4 body rows + 1 header = 5 rows of 13 pt = 65 pt, sitting directly
        // on top of the 115 pt title block whose bottom is at user-space 42.
        final revision = recovered.rects.firstWhere(
          (r) => (r.width - 396).abs() < 0.01 && (r.height - 65).abs() < 0.01,
          orElse: () => throw StateError('no 396 x 65 revision block emitted'),
        );
        expect(revision.bottom, closeTo(42 + 115, 1e-3));
        expect(revision.top, closeTo(42 + 115 + 65, 1e-3));
      },
    );
  });

  group('the ANSI A compact strip', () {
    test('is a full-width 690 x 43 band along the bottom of a 792 x 612 '
        'page', () async {
      final bytes = await renderFurniture(size: SheetSize.ansiALandscape);
      final recovered = recover(bytes);

      final strip = recovered.rects.firstWhere(
        (r) => (r.width - 690).abs() < 0.01 && (r.height - 43).abs() < 0.01,
        orElse: () => throw StateError('no 690 x 43 compact strip emitted'),
      );
      expect(strip.left, closeTo(60, 1e-3));
      expect(strip.bottom, closeTo(42, 1e-3));

      // The page really is 612 tall: the top edge of the frame is at
      // 612 - 36 - 6 = 570.
      final inner = recovered.rects.firstWhere(
        (r) => (r.width - 690).abs() < 0.01 && (r.height - 528).abs() < 0.01,
        orElse: () => throw StateError('no 690 x 528 frame emitted'),
      );
      expect(inner.top, closeTo(570, 1e-3));

      expect(recovered.allText, contains('SHEET NO.  T6.30'));
      expect(recovered.allText, contains('EQUIPMENT LIST AND MATERIALS'));
      // No revision history table on the compact strip.
      expect(recovered.allText, isNot(contains('NO REVISIONS RECORDED')));
    });
  });

  group('determinism, scoped honestly', () {
    test('two renders with the same injected date have byte-identical '
        'CONTENT STREAMS', () async {
      // FILE-LEVEL determinism is IMPOSSIBLE on pdf 3.13.0 and this test
      // does not claim it: `PdfDocument.documentID` is
      // sha256(DateTime.now() + Random.secure()) and lands in the trailer
      // /ID, and `PdfInfo` hardcodes /CreationDate: DateTime.now(). Neither
      // is injectable. So the claim made -- and asserted -- is that the
      // DRAWN CONTENT is deterministic.
      final at = DateTime.utc(2026, 7, 18);
      final a = extractOperatorStream(
        await renderFurniture(issuedAt: at),
        mustContain: ' re ',
      );
      final b = extractOperatorStream(
        await renderFurniture(issuedAt: at),
        mustContain: ' re ',
      );

      expect(a, b);
    });

    test('a different injected date changes the content stream', () async {
      final a = extractOperatorStream(
        await renderFurniture(issuedAt: DateTime.utc(2026, 7, 18)),
        mustContain: ' re ',
      );
      final b = extractOperatorStream(
        await renderFurniture(issuedAt: DateTime.utc(2027)),
        mustContain: ' re ',
      );

      expect(a, isNot(b));
      // ...and the DATE run is what moved.
      final text = recover(
        await renderFurniture(issuedAt: DateTime.utc(2027)),
      ).allText;
      expect(text, contains('2027-01-01'));
    });

    test('two renders with the same date are NOT byte-identical as FILES, '
        'which is why the claim above is scoped to content streams', () async {
      final at = DateTime.utc(2026, 7, 18);
      final a = await renderFurniture(issuedAt: at);
      final b = await renderFurniture(issuedAt: at);

      // If this ever starts passing, pdf gained an injectable document id
      // and the determinism gate can be widened. Asserting the current
      // reality keeps the limitation visible instead of remembered.
      expect(a, isNot(b));
    });
  });
}
