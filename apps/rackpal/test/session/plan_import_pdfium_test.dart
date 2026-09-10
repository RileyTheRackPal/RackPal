// PLAN-K/4 end to end: a CAD plot imports, through the REAL pdfium
// (DR-153 §11.152).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FLOW'S OWN CASES USE A FAKE RENDERER, AND THAT IS NOT ENOUGH
// ═══════════════════════════════════════════════════════════════════════
// `pdf_page_import_test.dart` hands the flow a closure that returns a PNG
// of the size it was asked for. That proves the sequence: which page is
// offered, what is stored, which members are written. It proves nothing
// about pdfium, and a fake that agrees with the flow would keep agreeing
// with it after the binding broke.
//
// This repository has been caught by exactly that once: a parser whose
// thirty-one synthetic cases all passed and which refused every page of
// the first real file it was given.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIXTURE CARRIES A REAL CROSS-REFERENCE TABLE
// ═══════════════════════════════════════════════════════════════════════
// Our own lifter scans for objects and needs no `xref`, so the fixtures
// beside this one do not write one. pdfium parses the trailer and the
// table, and where it cannot it falls into a damage-recovery path: a
// fixture without one would be testing that recovery rather than the
// renderer, which is a case passing for the wrong reason.
//
// The signature it shares with DR-145's real plot is what matters: vector
// paths and text, a populated `/Resources` with a font in it, and no image
// anywhere.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/pdf_rasteriser.dart';
import 'package:rackpal/src/session/plan_import_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

final _fixed = DateTime.utc(2026, 9, 10, 9);

/// One interpolated constant rather than adjacent literals: PDF
/// dictionary syntax has no whitespace between its tokens, and the
/// lint that wants some would change the fixture.
const String _kFontRes =
    '<</Font<</F1<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>>>>>';
const String _kPageDict = '/MediaBox[0 0 144 72]/Resources$_kFontRes';

/// A 144 x 72 pt plot: one thick diagonal, one room name, no image.
///
/// Small so the case is quick, and the ruled 300 dpi makes it 600 x 300.
Uint8List wellFormedVectorPdf() {
  const content =
      'q 4 w 0 0 0 RG 10 10 m 130 60 l S Q\n'
      'BT /F1 12 Tf 20 40 Td (BEDROOM 1) Tj ET\n';
  final objects = <String>[
    '<</Type/Catalog/Pages 2 0 R>>',
    '<</Type/Pages/Kids[3 0 R]/Count 1>>',
    '<</Type/Page/Parent 2 0 R$_kPageDict/Contents 4 0 R>>',
    '<</Length ${content.length}>>\nstream\n$content\nendstream',
  ];

  final buf = BytesBuilder();
  void put(String s) => buf.add(latin1.encode(s));
  put('%PDF-1.7\n');

  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buf.length);
    put('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }

  final xref = buf.length;
  put('xref\n0 ${objects.length + 1}\n');
  put('0000000000 65535 f \n');
  for (final offset in offsets) {
    put('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  put('trailer\n<</Size ${objects.length + 1}/Root 1 0 R>>\n');
  put('startxref\n$xref\n%%EOF\n');
  return buf.toBytes();
}

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-1'),
  appVersion: '0.1.0',
  createdAt: _fixed,
  modifiedAt: _fixed,
  meta: EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'tester'),
);

({DocumentSession session, FloorplanIo io}) _harness(Uint8List pdf) {
  final session = DocumentSession(
    controller: DocumentController(
      _doc(),
      clock: FixedClock(_fixed),
      actor: 'tester',
    ),
    context: p.Context(style: p.Style.windows),
  );
  return (
    session: session,
    // NO RASTERISER PASSED, so this is the one the app ships.
    io: FloorplanIo(
      session: session,
      picker: FakeFilePicker(openPaths: [r'C:\plans\cad.pdf']),
      fs: FakeFileStore(initialFiles: {r'C:\plans\cad.pdf': pdf}),
    ),
  );
}

void main() {
  group('the real pdfium, through the whole importer', () {
    test('a page of vectors is offered as a RENDERED option', () {
      final pages =
          (readPdfPages(wellFormedVectorPdf(), rasteriser: pdfiumRenderPng)
                  as Ok<List<Outcome<PdfPageOption>>>)
              .value;

      expect(pages, hasLength(1));
      final option = (pages.single as Ok<PdfPageOption>).value;
      expect(option, isA<RenderedPageOption>());
      // 144 x 72 pt at the ruled 300 dpi.
      expect(option.resultWidth, 600);
      expect(option.resultHeight, 300);
    });

    /// LOAD-BEARING. Everything short of a crash produces a plausible
    /// PNG of the right size, so the case has to look at the ink.
    test(
      'the imported underlay CARRIES THE DRAWING, not a blank page',
      () async {
        final pdf = wellFormedVectorPdf();
        final h = _harness(pdf);

        final result = await h.io.import(
          pickPage: (pages, fileName) async =>
              (pages.single as Ok<PdfPageOption>).value,
        );

        final underlay = (result! as Ok<PlanUnderlay>).value;
        expect(underlay.format, PlanImageFormat.png);
        expect(underlay.pixelWidth, 600);
        expect(underlay.pixelHeight, 300);

        final stored = img.decodePng(h.session.members[underlay.imageMember]!)!;
        var dark = 0;
        for (var y = 0; y < stored.height; y++) {
          for (var x = 0; x < stored.width; x++) {
            if (stored.getPixel(x, y).r < 64) dark++;
          }
        }
        expect(
          dark,
          greaterThan(100),
          reason: 'the diagonal and the room name are dark pixels',
        );
        expect(
          dark,
          lessThan(stored.width * stored.height ~/ 2),
          reason: 'a page rendered onto an unfilled bitmap comes back black',
        );
      },
    );

    test('and the source PDF rides into the container with it', () async {
      final pdf = wellFormedVectorPdf();
      final h = _harness(pdf);

      final result = await h.io.import(
        pickPage: (pages, fileName) async =>
            (pages.single as Ok<PdfPageOption>).value,
      );

      final underlay = (result! as Ok<PlanUnderlay>).value;
      expect(underlay.sourcePage!.pageIndex, 0);
      expect(h.session.members[underlay.sourcePage!.member], pdf);
    });
  });
}
