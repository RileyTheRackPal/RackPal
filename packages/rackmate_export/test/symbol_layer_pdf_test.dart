// The point of relocating the schematic symbol into `rackmate_core`, made
// executable (CR-071, CR-086, docs/05-schematic-editor.md §3).
//
// While `symbol_layer.dart` lived in `rackmate_ui` and painted immediate-mode
// through a `FlutterDiagramCanvas`, THIS FILE COULD NOT HAVE BEEN WRITTEN:
// `rackmate_export` is a sibling of `rackmate_ui` and must never import it,
// so the schematic could never have reached the PDF backend. The ruling that
// screen and print share ONE drawing IR was broken in substance, not just on
// paper. These tests prove it is now whole — the export package builds a
// device symbol using nothing but `rackmate_core`, and replays it onto a
// real `PdfGraphics`.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_export/rackmate_export.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:test/test.dart';

const _kZeroPosition = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

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
  position: _kZeroPosition,
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
    File('../../apps/rackmate/assets/fonts/Jost-Regular.ttf').readAsBytesSync();

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
  test(
    'rackmate_export imports rackmate_core only — never its sibling '
    'rackmate_ui (the constraint that forced the relocation)',
    () {
      // Same shape as rackmate_core's no_flutter_import_test: a source-level
      // gate, so the rule fails a test run rather than a code review.
      final banned = RegExp(r'''import\s+['"]package:rackmate_ui/''');
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        expect(
          banned.hasMatch(f.readAsStringSync()),
          isFalse,
          reason: '${f.path} imports rackmate_ui',
        );
      }
    },
  );

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

  test('every pin is FILLED with portFill and STROKED with portStroke — the '
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
      reason: 'portStroke reached the page as a pin FILL — the two are '
          'swapped, or an arrowhead changed colour',
    );
  });

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
