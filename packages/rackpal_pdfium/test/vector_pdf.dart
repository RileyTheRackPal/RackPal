// A synthetic CAD plot, with a cross-reference table pdfium will accept.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS NOT `cadPlotPdf()` FROM THE CORE SUITE
// ═══════════════════════════════════════════════════════════════════════
// `pdf_page_lift_test.dart` already builds a twin of the DR-145 plot: three
// ANSI B pages, fonts, linework and no `/XObject`. It writes **no `xref`
// table at all**, because our own lifter scans for objects and does not
// need one, and a fixture is allowed to stop where the thing it tests
// stops.
//
// pdfium is a different reader and a stricter one. It parses the trailer
// and the cross-reference table, and where it cannot it falls into a
// rebuild path, so a fixture without one would be testing pdfium's damage
// recovery rather than its renderer. **A fixture that exercises the
// recovery path of the thing under test is a fixture that passes for the
// wrong reason**, so this one is well-formed: real offsets, a real
// `startxref`, a real `/Size`.
//
// The signature it shares with the real file is the part that matters:
// vector paths and text, a populated `/Resources` with a font in it, and
// no image anywhere.
import 'dart:convert';
import 'dart:typed_data';

/// The ANSI B landscape box every page of the DR-145 plot declares.
const String kAnsiBMediaBox = '/MediaBox[0 0 1224 792]';

/// A plot of [pages] pages: linework, a room name, and no image.
///
/// [content] replaces the drawn content of every page, which is how the
/// blank-page case asks for a page that paints nothing at all.
Uint8List vectorPdf({int pages = 3, String? content}) {
  final objects = <String>[
    '<</Type/Catalog/Pages 2 0 R>>',
    // Filled in below, once the kids are known.
    '',
  ];

  final kids = <String>[];
  for (var i = 0; i < pages; i++) {
    final contentObj = objects.length + 2; // 1-based, page comes first
    kids.add('${objects.length + 1} 0 R');
    objects.add(
      '<</Type/Page/Parent 2 0 R$kAnsiBMediaBox'
      '/Resources<</Font<</F1<</Type/Font/Subtype/Type1'
      '/BaseFont/Helvetica>>>>>>'
      '/Contents $contentObj 0 R>>',
    );
    final stream =
        content ??
        // A thick diagonal and a room name: enough ink that a render
        // which drew nothing is distinguishable from one that worked.
        'q 8 w 0 0 0 RG 100 100 m 1100 700 l S Q\n'
            'BT /F1 48 Tf 200 400 Td (BEDROOM ${i + 1}) Tj ET\n';
    objects.add('<</Length ${stream.length}>>\nstream\n$stream\nendstream');
  }
  objects[1] = '<</Type/Pages/Kids[${kids.join(' ')}]/Count $pages>>';

  // ── serialise, recording every object's offset ──────────────────────
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
