// The point of relocating the schematic symbol into `rackpal_core`, made
// executable (CR-071, CR-086, docs/05-schematic-editor.md §3).
//
// While `symbol_layer.dart` lived in `rackpal_ui` and painted immediate-mode
// through a `FlutterDiagramCanvas`, THIS FILE COULD NOT HAVE BEEN WRITTEN:
// `rackpal_export` is a sibling of `rackpal_ui` and must never import it,
// so the schematic could never have reached the PDF backend. The ruling that
// screen and print share ONE drawing IR was broken in substance, not just on
// paper. These tests prove it is now whole — the export package builds a
// device symbol using nothing but `rackpal_core`, and replays it onto a
// real `PdfGraphics`.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:test/test.dart';

import 'support/source_gate.dart';

var _order = 0;

PortDef _port(
  String key,
  String label, {
  required String family,
  required PortDirection direction,
}) => PortDef(
  key: PortKey(key),
  label: label,
  connector: const ConnectorTypeId('test'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  order: FracIndex('a${_order++}'),
  direction: direction,
);

/// An 8-in / 8-out HDMI matrix with control on top and an IEC inlet below —
/// docs/05 §3.1's worked `MTX-1` example, minus the parts §3 defers.
RenderedSymbol _mtx1({int inputs = 8, int outputs = 8}) {
  _order = 0;
  return buildSymbolGeometry(
    id: 'dev-mtx-1',
    designator: 'MTX-1',
    name: 'Head End',
    ports: [
      for (var i = 1; i <= inputs; i++)
        _port(
          'J0$i',
          'IN $i',
          family: 'video.hdmi.2_0',
          direction: PortDirection.sink,
        ),
      for (var i = 1; i <= outputs; i++)
        _port(
          'J1$i',
          'OUT $i',
          family: 'video.hdmi.2_0',
          direction: PortDirection.source,
        ),
      _port(
        'J17',
        'RS-232',
        family: 'ctl.rs232',
        direction: PortDirection.sink,
      ),
      _port(
        'J18',
        'LAN',
        family: 'net.ethernet',
        direction: PortDirection.sink,
      ),
      _port(
        'J20',
        'IEC C14',
        family: 'power.ac_iec',
        direction: PortDirection.sink,
      ),
    ],
    headerHeight: 24,
    portSize: 8,
    portPitch: 16,
    minBodyWidth: 180,
  );
}

Uint8List _bytes() =>
    File('../../apps/rackpal/assets/fonts/Jost-Regular.ttf').readAsBytesSync();

/// Renders [ops] onto a real `PdfGraphics` through `PdfDiagramCanvas` and
/// returns the finished PDF bytes.
///
/// Compression is OFF so the content stream can be read back and asserted
/// on. "The bytes are non-empty" says almost nothing; counting the PDF
/// operators the ops actually lowered to says what reached the page.
Future<Uint8List> _render(List<DiagramOp> ops) async {
  final bytes = _bytes();
  final doc = pw.Document(compress: false);
  const fontRef = FontRef('Jost');
  final measurer = PdfFontMeasurer.fromBytes(doc.document, {fontRef: bytes});
  final fonts = <FontRef, PdfFont>{
    fontRef: PdfTtfFont(doc.document, ByteData.sublistView(bytes)),
  };

  doc.addPage(
    pw.Page(
      build: (context) => pw.CustomPaint(
        size: const PdfPoint(400, 400),
        painter: (PdfGraphics graphics, PdfPoint size) {
          final canvas = PdfDiagramCanvas(
            graphics: graphics,
            boxHeight: size.y,
            fonts: fonts,
            measurer: measurer,
          )..save();
          for (final op in ops) {
            op.replay(canvas);
          }
          canvas.restore();
        },
      ),
    ),
  );
  return Uint8List.fromList(await doc.save());
}

/// Occurrences of the PDF content-stream operator [op] in [pdf] — a
/// whitespace-delimited token, so `c` does not match the `c` inside a name
/// or a number. Also used for whole operand+operator phrases such as
/// `1 0 0 rg`, which the same delimiters keep from matching the `1 0 0` of
/// a `cm` matrix.
int _count(Uint8List pdf, String op) => RegExp(
  '(?<=\\s)${RegExp.escape(op)}(?=\\s)',
).allMatches(String.fromCharCodes(pdf)).length;

/// [pdf] with the trailer's `/ID` array blanked.
///
/// That array is a fresh random document identifier generated inside
/// `pw.Document.save()`; it is the ONLY part of the output that is not a
/// function of the ops (verified by rendering the same op twice — 118 bytes
/// differ, all of them inside `/ID`). Everything else, the entire page
/// content stream included, is left alone so a byte comparison of two
/// stabilised documents is a byte comparison of the drawing.
Uint8List _stable(Uint8List pdf) => Uint8List.fromList(
  String.fromCharCodes(pdf)
      .replaceAll(
        RegExp(r'/ID\[<[0-9a-fA-F]*><[0-9a-fA-F]*>\]'),
        '/ID[<><>]',
      )
      .codeUnits,
);

TextMeasurer _measurer() {
  final bytes = _bytes();
  return PdfFontMeasurer.fromBytes(pw.Document().document, {
    const FontRef('Jost'): bytes,
  });
}

void main() {
  group('rackpal_export never reaches its sibling rackpal_ui (the '
      'constraint that forced the relocation)', () {
    // ====================================================================
    // THE GATE USED THE PATTERN ITS OWN SIBLING DOCUMENTS AS BROKEN.
    // ====================================================================
    // It was `RegExp(r"""import\s+['"]package:rackpal_ui/""")` over lib/
    // — the exact naive shape `rackpal_core/test/no_flutter_import_test
    // .dart` replaced, and for the same three reasons: an `export` in the
    // barrel is invisible to it, a conditional import puts the URI after
    // `)` rather than after `import`, and `\s+` requires whitespace that
    // valid Dart does not. It also never looked at the pubspec, where a
    // dependency is DECLARED, and it had no vacuity guard, so a run that
    // found no files passed.
    //
    // `support/source_gate.dart` carries the directive scanner; the
    // spellings it must catch are proved below rather than asserted in a
    // comment.

    test('no source file under lib/ pulls in rackpal_ui, Flutter or '
        'dart:ui', () {
      final offenders = <String>[];
      var scanned = 0;
      for (final f in dartFilesUnder('lib')) {
        scanned++;
        for (final uri in bannedUris(f.readAsStringSync())) {
          offenders.add('${f.path} pulls in $uri');
        }
      }

      // Guards the guard: a scan that found no files would pass vacuously.
      // The sibling gate in core says `greaterThan(10)`; this package's
      // lib/ is smaller (7 files at the time of writing), so the floor is
      // set below that and above zero, which is the property that matters.
      expect(scanned, greaterThan(5));
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('...and the PUBSPEC does not declare them either, which is where '
        'a dependency actually comes from', () {
      // A source scan cannot see a dependency that has been added but not
      // yet imported, and that is the state a package is in for exactly as
      // long as it takes to write the next line. `flutter` here would also
      // stop this package being isolate-safe pure Dart, which is the whole
      // reason the two backends are siblings.
      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue, reason: 'run from the package root');

      final deps = pubspec.readAsLinesSync().where(
        (l) => !l.trimLeft().startsWith('#'),
      );
      for (final banned in <String>['rackpal_ui', 'flutter']) {
        expect(
          deps.any(
            (l) => RegExp('^\\s+$banned\\s*:').hasMatch(l),
          ),
          isFalse,
          reason: 'pubspec.yaml declares a dependency on $banned',
        );
      }
      // ...and the scan is not vacuous: the dependencies it IS allowed to
      // have are there to be found.
      expect(
        deps.any((l) => RegExp(r'^\s+rackpal_core\s*:').hasMatch(l)),
        isTrue,
      );
    });

    group('the pattern catches every legal spelling — the three the old '
        'one missed', () {
      // Strings, not files: the point is what the matcher does, and a
      // fixture file containing a real rackpal_ui import could not live
      // under lib/ without failing the gate above.
      test('a plain import', () {
        expect(bannedUris("import 'package:rackpal_ui/rackpal_ui.dart';"), [
          'package:rackpal_ui/',
        ]);
      });

      test('an EXPORT — the barrel is a re-export surface, and this is the '
          'spelling that would hand rackpal_ui to every consumer', () {
        expect(bannedUris("export 'package:rackpal_ui/rackpal_ui.dart';"), [
          'package:rackpal_ui/',
        ]);
      });

      test('a CONDITIONAL import, where the banned URI follows `)` and not '
          '`import`', () {
        expect(
          bannedUris(
            "import 'stub.dart' "
            "if (dart.library.ui) 'package:rackpal_ui/rackpal_ui.dart';",
          ),
          ['package:rackpal_ui/'],
        );
      });

      test('no whitespace after the keyword', () {
        expect(bannedUris('import"package:rackpal_ui/rackpal_ui.dart";'), [
          'package:rackpal_ui/',
        ]);
      });

      test('Flutter and dart:ui directly, without going through '
          'rackpal_ui', () {
        expect(bannedUris("import 'package:flutter/material.dart';"), [
          'package:flutter/',
        ]);
        expect(bannedUris("import 'dart:ui' deferred as ui;"), ['dart:ui']);
      });
    });

    group('the pattern does not cry wolf', () {
      test('the permitted imports are permitted', () {
        expect(
          bannedUris('''
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:vector_math/vector_math_64.dart';
'''),
          isEmpty,
        );
      });

      test('a COMMENT naming rackpal_ui is prose, not an import — which '
          'this very file depends on', () {
        expect(
          bannedUris("""
// `rackpal_export` must never import 'package:rackpal_ui/…'.
/* import 'package:flutter/material.dart'; would be a violation. */
import 'package:pdf/pdf.dart';
"""),
          isEmpty,
        );
      });
    });
  });

  test('the export package can build a symbol fragment from core alone', () {
    final built = buildSymbolLayer(
      _mtx1(),
      palette: const SchematicPalette(),
      measurer: _measurer(),
    );

    // Body fill + header band + body outline.
    expect(built.ops.whereType<OpRect>(), hasLength(3));
    // The hairline rule under the header.
    expect(built.ops.whereType<OpLine>(), hasLength(1));
    // One circle per pin: 8 in + 8 out + 2 control/network + 1 power.
    expect(built.ops.whereType<OpCircle>(), hasLength(19));
    // Designator, instance name, and one label per pin.
    expect(
      built.ops.whereType<OpText>().map((o) => o.text),
      containsAll(['MTX-1', 'Head End', 'IN 1', 'OUT 8', 'RS-232', 'IEC C14']),
    );
    expect(built.minTextPt, lessThan(RackTextSizes.designator));
  });

  test('the symbol fragment replays onto a real PdfGraphics, and every pin '
      'lands in the content stream as real curve operators', () async {
    final built = buildSymbolLayer(
      _mtx1(),
      palette: const SchematicPalette(),
      measurer: _measurer(),
    );
    // Same ops, minus the pin circles — so the body, header, rule, text and
    // arrowheads are byte-for-byte identical between the two renders and
    // the ONLY difference measured is the pin ink.
    final withoutPins = built.ops.whereType<OpCircle>().isEmpty
        ? built.ops
        : built.ops.where((op) => op is! OpCircle).toList();

    final full = await _render(built.ops);
    final bare = await _render(withoutPins);

    expect(full, isNotEmpty);
    // `PdfGraphics` lowers one circle to four cubic Bézier segments, and a
    // pin is BOTH filled and stroked — so it emits the four-curve path
    // twice, once per paint. Eight `c` operators per pin therefore also
    // proves the fill and the stroke both reached the page, not just the
    // geometry.
    const curvesPerPin = 8;
    expect(
      _count(full, 'c') - _count(bare, 'c'),
      curvesPerPin * 19,
      reason: 'the 19 pins did not reach the page as filled, stroked curves',
    );
    // The body rect, the header band and the body outline are all still
    // there in both.
    expect(_count(bare, 're'), greaterThanOrEqualTo(3));
  });

  test(
    'a symbol that has MOVED replays byte-identically — the fragment is '
    'position-independent, so a move never invalidates a cached page',
    () async {
      const palette = SchematicPalette();
      final measurer = _measurer();
      final symbol = _mtx1(inputs: 2, outputs: 2);
      final relocated = symbol.movedTo(const DPt(1234, -567));

      // THE MOVE HAPPENED. Without this the byte comparison below cannot
      // tell "the fragment is position-independent" from "`movedTo` ignored
      // its argument and we rendered the same symbol twice" — which is a
      // real defect (it would strand every symbol at the origin) and one
      // that makes every assertion in this test pass.
      expect(symbol.bodyRect.topLeft, const DPt(0, 0));
      expect(relocated.bodyRect.topLeft, const DPt(1234, -567));

      final atOrigin = await _render(
        buildSymbolLayer(symbol, palette: palette, measurer: measurer).ops,
      );
      final moved = await _render(
        buildSymbolLayer(relocated, palette: palette, measurer: measurer).ops,
      );

      // BYTES, not byte COUNTS. A length comparison passes for any defect
      // that keeps the stream the same size — and a leaked absolute
      // coordinate very often does, because `1234` and `-567` are the same
      // width as plenty of local values. This is the load-bearing proof that
      // the fragment is position-independent, so it compares the drawing.
      expect(_stable(moved), _stable(atOrigin));
      // …and the comparison is not vacuous: there IS a page of content
      // under it.
      expect(_count(atOrigin, 'c'), greaterThan(0));
    },
  );

  test(
    'every pin is FILLED with portFill and STROKED with portStroke — the '
    'two are not interchangeable and a swap is visible on the page', //
    () async {
      // A pin's fill and its stroke lower to the SAME four Bézier segments, so
      // every count-based assertion in this file — total bytes, `c` operators,
      // `re` operators — survives exchanging the two colours, and the page
      // then renders 19 pins inside out. This reads the colours themselves.
      const palette = SchematicPalette(
        portFill: 0xFFFF0000, // red — the symbol uses it nowhere else
        portStroke: 0xFF00FF00, // green — likewise
      );
      final pdf = await _render(
        buildSymbolLayer(_mtx1(), palette: palette, measurer: _measurer()).ops,
      );

      // `PdfGraphics.setColor` emits the non-stroking colour (`rg`), which is
      // what a fill is; `setStrokeColor` emits `RG`.
      expect(
        _count(pdf, '1 0 0 rg'),
        19,
        reason: 'the 19 pin circles were not filled with portFill',
      );
      // portStroke appears as a FILL exactly 19 times and no more: the
      // direction arrowheads, which are deliberately solid in the pin's
      // stroke colour. Swapping the circle's fill and stroke turns this into
      // 38 (and the assertion above into 0).
      expect(
        _count(pdf, '0 1 0 rg'),
        19,
        reason:
            'portStroke reached the page as a pin FILL — the two are '
            'swapped, or an arrowhead changed colour',
      );
    },
  );

  test('the export path receives the symbol INK bounds, and they reach past '
      'the body on every side', () {
    // Scale-to-fit divides by this box (ops.dart: "-> scale-to-fit, tile
    // counts"). A symbol draws its pins ON its body edge and its top/bottom
    // labels outside it, so a page sized from `bodyRect` alone would clip
    // half of every outermost pin and the whole of 'RS-232' / 'LAN' /
    // 'IEC C14'.
    final symbol = _mtx1();
    final built = buildSymbolLayer(
      symbol,
      palette: const SchematicPalette(),
      measurer: _measurer(),
    );
    final ink = built.inkBounds;
    expect(ink, isNotNull);
    // Local coordinates, like the ops: the body sits at (0, 0).
    expect(ink!.left, lessThan(0));
    expect(ink.top, lessThan(0));
    expect(ink.right, greaterThan(symbol.bodyRect.width));
    expect(ink.bottom, greaterThan(symbol.bodyRect.height));
    // portSize is 8, so each pin circle alone reaches 4 out; the labels
    // reach further still on the top and bottom edges.
    expect(ink.left, lessThanOrEqualTo(-4));
    expect(ink.top, lessThan(-4));
  });
}
