// rackpal_export/test/support/content_stream.dart -- TEST SUPPORT ONLY.
//
// A minimal PDF content-stream interpreter: it walks the `q` / `Q` / `cm`
// operators to maintain a CTM stack and maps every `re` (rectangle) and
// text-showing operator through that CTM into PDF USER SPACE POINTS.
//
// WHY THIS EXISTS RATHER THAN A REGEX OVER RAW OPERANDS. The numbers a
// `re` operator carries are in whatever space the enclosing `cm`s put it
// in. `PdfDiagramCanvas` pushes one global Y-flip (`1 0 0 -1 0 H cm`) at
// construction and a composed sheet pushes further transforms on top, so a
// raw `54 36 702 1152 re` says nothing about where the ink lands on the
// paper. USER SPACE is what a viewer and a printer consume, and it is
// therefore the only space in which "dimensionally correct against a tape
// measure" is a checkable claim.
//
// THIS FILE HAS ITS OWN TEST. `content_stream_harness_test.dart` feeds the
// interpreter a hand-written stream with known rectangles and asserts it
// recovers them. Without that, a harness that silently found ZERO `re`
// operators would make every assertion built on it vacuously true -- which
// is exactly the class of test this project has shipped before.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// A PDF transformation matrix `[a b c d e f]`, row-vector convention:
/// `(x, y) -> (a·x + c·y + e, b·x + d·y + f)`.
final class PdfMatrix {
  const PdfMatrix(this.a, this.b, this.c, this.d, this.e, this.f);

  static const PdfMatrix identity = PdfMatrix(1, 0, 0, 1, 0, 0);

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  /// This matrix applied AFTER [local] -- the composition the `cm`
  /// operator performs (`CTM' = local × CTM`).
  PdfMatrix after(PdfMatrix local) => PdfMatrix(
    local.a * a + local.b * c,
    local.a * b + local.b * d,
    local.c * a + local.d * c,
    local.c * b + local.d * d,
    local.e * a + local.f * c + e,
    local.e * b + local.f * d + f,
  );

  (double, double) apply(double x, double y) =>
      (a * x + c * y + e, b * x + d * y + f);

  /// The uniform scale factor of this matrix -- `sqrt(|det|)`.
  double get uniformScale => math.sqrt((a * d - b * c).abs());

  @override
  String toString() => 'PdfMatrix($a, $b, $c, $d, $e, $f)';
}

/// One `re` operator, mapped into user space.
final class RecoveredRect {
  const RecoveredRect({
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
    required this.lineWidthPt,
  });

  /// User-space edges. `bottom < top` because PDF user space is Y-UP.
  final double left;
  final double bottom;
  final double right;
  final double top;

  /// The line width in force when the rectangle was emitted, already
  /// multiplied by the CTM's uniform scale -- i.e. the width ON PAPER.
  final double lineWidthPt;

  double get width => right - left;
  double get height => top - bottom;

  @override
  String toString() =>
      'RecoveredRect(l: $left, b: $bottom, w: $width, h: $height, '
      'lw: $lineWidthPt)';
}

/// One PAINTED PATH, mapped into user space as its bounding box.
///
/// WHY THIS EXISTS ALONGSIDE [RecoveredRect]. `re` is only one of the ways
/// a rectangle reaches the page. `PdfGraphics.drawRRect` -- which is what a
/// device block at `LodLevel.full` lowers to -- emits `m`/`l`/`c` and no
/// `re` at all, so a harness that only understood `re` would silently find
/// ZERO device blocks and every assertion about their size would pass
/// vacuously. That is the exact failure mode this project has shipped
/// before, so the interpreter walks the general path machinery too.
///
/// The box is the hull of every path POINT, control points included. For
/// `drawRRect` that is exact rather than conservative: its four corner
/// curves have both control points inside the rectangle
/// (`graphics.dart:479-496`), and the straight edges touch all four sides.
final class RecoveredPath {
  const RecoveredPath({
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
    required this.lineWidthPt,
    required this.pointCount,
  });

  /// User-space edges. `bottom < top` because PDF user space is Y-UP.
  final double left;
  final double bottom;
  final double right;
  final double top;

  /// The line width in force when the path was painted, on paper.
  final double lineWidthPt;

  /// How many points fed the hull -- a `re` contributes 4, a rounded rect
  /// 17. Exposed so a test can tell the two apart without guessing.
  final int pointCount;

  double get width => right - left;
  double get height => top - bottom;

  @override
  String toString() =>
      'RecoveredPath(l: $left, b: $bottom, w: $width, h: $height, '
      'pts: $pointCount)';
}

/// One text-showing operator, mapped into user space.
final class RecoveredText {
  const RecoveredText({
    required this.text,
    required this.baselineX,
    required this.baselineY,
    required this.sizePt,
  });

  final String text;

  /// The baseline origin in user space.
  final double baselineX;
  final double baselineY;

  /// The point size on paper (the `Tf` size scaled by the CTM).
  final double sizePt;

  @override
  String toString() =>
      'RecoveredText("$text" @ ($baselineX, $baselineY), $sizePt pt)';
}

/// Everything the interpreter recovered from one content stream.
/// An XObject painted by `Do`, with the image's OWN four corners mapped
/// into PDF user space through the CTM in force at that moment.
///
/// WHY THE CORNERS AND NOT A BOX. A box cannot be mirrored. A PDF image
/// XObject occupies the unit square with its top row at `v = 1`, so an
/// image drawn under a Y-flipped CTM without a counter-flip lands with
/// [topLeft] BELOW [bottomLeft] on the page, and its bounding box is
/// identical either way. Recording the corners separately is the only
/// shape of evidence in which "the floorplan is upside down" is a
/// checkable claim, and an upside-down floorplan is the failure that looks
/// plausible until somebody stands in the wrong room.
final class RecoveredImage {
  const RecoveredImage({
    required this.name,
    required this.bottomLeft,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
  });

  /// The resource name from `/Name Do`, without the slash.
  final String name;

  /// The image's own bottom-left pixel corner, in user-space points.
  final (double, double) bottomLeft;

  /// The image's own TOP-left pixel corner, in user-space points. On a
  /// correctly placed image this has a LARGER y than [bottomLeft], because
  /// PDF user space is Y-up.
  final (double, double) topLeft;

  final (double, double) topRight;
  final (double, double) bottomRight;

  @override
  String toString() =>
      'RecoveredImage($name, bl=$bottomLeft, tl=$topLeft, '
      'tr=$topRight, br=$bottomRight)';
}

final class RecoveredStream {
  const RecoveredStream(
    this.rects,
    this.texts,
    this.paths, {
    this.images = const <RecoveredImage>[],
  });

  /// Rectangles from the `re` operator specifically.
  final List<RecoveredRect> rects;

  final List<RecoveredText> texts;

  /// EVERY painted path's bounding box, `re`-built ones included. See
  /// [RecoveredPath].
  final List<RecoveredPath> paths;

  /// Every XObject painted by `Do`, in stream order.
  final List<RecoveredImage> images;

  /// Every recovered text run concatenated, for `contains` assertions.
  String get allText => texts.map((t) => t.text).join('\n');

  /// The single path whose user-space box is [width] x [height], within
  /// [tolerance].
  ///
  /// Throws rather than returning null when there is no match OR when
  /// there is more than one: an assertion about "the chassis frame" that
  /// silently picked the first of two candidates would be an assertion
  /// about something else.
  ///
  /// ─────────────────────────────────────────────────────────────────────
  /// THE SECOND HALF OF THAT SENTENCE USED TO BE A PROMISE ONLY
  /// ─────────────────────────────────────────────────────────────────────
  /// The body threw on an empty match list and returned `matches.first`
  /// otherwise, so the uniqueness this doc claims was never checked. Every
  /// absolute-placement assertion in `elevation_true_scale_test.dart`
  /// reaches the chassis frame through here and relies on it. The frame is
  /// unique TODAY — but the moment a second shape lands within [tolerance]
  /// of panel-width x rack-height (a full-height blanking panel, a device
  /// occupying the whole rack, or the frame simply gaining a fill as well
  /// as a stroke, which is the same duplication [distinctPathsSized]
  /// exists to absorb), the Y-flip assertion would silently become an
  /// assertion about an arbitrary shape and keep passing.
  ///
  /// DISTINCT POSITIONS, NOT RAW MATCHES. A fill and a stroke of one shape
  /// are one shape on the paper; two shapes of the same size in two
  /// PLACES are the ambiguity this guards. So the count is taken after
  /// [distinctPathsSized] collapses coincident geometry, and a caller that
  /// wants the several-shapes case asks for it by name.
  RecoveredPath pathSized(
    double width,
    double height, {
    double tolerance = 1e-6,
  }) {
    final matches = pathsSized(width, height, tolerance: tolerance);
    if (matches.isEmpty) {
      throw StateError(
        'no painted path measuring $width x $height pt (+-$tolerance). '
        'Recovered ${paths.length} paths: ${paths.take(16).join('; ')}',
      );
    }
    final distinct = distinctPathsSized(width, height, tolerance: tolerance);
    if (distinct.length > 1) {
      throw StateError(
        'pathSized is not unique: ${distinct.length} painted paths measure '
        '$width x $height pt (+-$tolerance), in ${distinct.length} distinct '
        'places: ${distinct.join('; ')}. An assertion about "the chassis '
        'frame" that silently picked the first of these would be an '
        'assertion about something else — use pathsSized or '
        'distinctPathsSized and say which one you mean.',
      );
    }
    return matches.first;
  }

  /// Every painted path whose user-space box is [width] x [height].
  List<RecoveredPath> pathsSized(
    double width,
    double height, {
    double tolerance = 1e-6,
  }) => paths
      .where(
        (p) =>
            (p.width - width).abs() < tolerance &&
            (p.height - height).abs() < tolerance,
      )
      .toList();

  /// [pathsSized], reduced to DISTINCT positions.
  ///
  /// A `drawRoundRect` carrying both a fill and a stroke emits the same
  /// geometry TWICE -- `PdfDiagramCanvas.drawRoundRect` builds the path
  /// once per paint operation. Counting shapes without this would report
  /// two device blocks as four, and a test asserting "there are exactly
  /// two" would be asserting on an implementation detail of the painter
  /// rather than on what is on the page.
  List<RecoveredPath> distinctPathsSized(
    double width,
    double height, {
    double tolerance = 1e-6,
  }) {
    final seen = <String>{};
    return <RecoveredPath>[
      for (final p in pathsSized(width, height, tolerance: tolerance))
        if (seen.add(
          '${p.left.toStringAsFixed(3)},${p.bottom.toStringAsFixed(3)}',
        ))
          p,
    ];
  }
}

/// One PDF content-stream token: a hex string, a literal string, an array
/// delimiter, a name, a number, or an operator.
///
/// The operator alternative includes `*` (`f*`, `W*`, `T*`), the quote
/// (`'`) and the double quote, all of which are real PDF operators.
final RegExp _tokenPattern = RegExp(
  '<[0-9A-Fa-f]*>'
  r'|\(((?:\\.|[^)\\])*)\)'
  r'|\['
  r'|\]'
  r'|/[^\s/\[\]<>(){}]*'
  r'|[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?'
  r"|[A-Za-z*'\x22]+",
);

/// Interprets [stream] -- the decompressed bytes between `stream` and
/// `endstream` -- into user-space geometry.
///
/// [toUnicode] maps the 2-byte glyph codes dart_pdf writes for an embedded
/// TrueType font back to Unicode code points; pass [parseToUnicodeCMap]'s
/// result. Codes absent from the map pass through unchanged, which is what
/// makes a hand-written stream (where the codes ARE the code points)
/// readable without a font.
RecoveredStream interpretContentStream(
  String stream, {
  Map<int, int> toUnicode = const <int, int>{},
}) {
  final rects = <RecoveredRect>[];
  final texts = <RecoveredText>[];
  final paths = <RecoveredPath>[];
  final images = <RecoveredImage>[];

  // The most recent `/Name` token. `Do` takes its operand this way, and
  // the tokeniser otherwise discards names.
  var lastName = '';

  var ctm = PdfMatrix.identity;
  final ctmStack = <PdfMatrix>[];
  var lineWidth = 1.0;
  final lineWidthStack = <double>[];
  var fontSize = 0.0;
  var textX = 0.0;
  var textY = 0.0;

  final numbers = <double>[];
  final strings = <String>[];

  // The path under construction, in USER SPACE: points are mapped through
  // the CTM as they are read, because a `cm` between two segments would
  // otherwise be applied to the wrong half.
  var pathPoints = <(double, double)>[];

  void addPoint(double x, double y) => pathPoints.add(ctm.apply(x, y));

  /// A path-painting operator ends the current path; emit its hull.
  void endPath() {
    if (pathPoints.isNotEmpty) {
      paths.add(
        _hullOf(pathPoints, lineWidth * ctm.uniformScale),
      );
    }
    pathPoints = <(double, double)>[];
  }

  for (final match in _tokenPattern.allMatches(stream)) {
    final token = match.group(0)!;
    final first = token.codeUnitAt(0);

    // Operands.
    if (token == '[' || token == ']') continue;
    if (first == 0x2f /* / */ ) {
      lastName = token.substring(1);
      continue;
    }
    if (first == 0x3c /* < */ ) {
      strings.add(_decodeHexString(token, toUnicode));
      continue;
    }
    if (first == 0x28 /* ( */ ) {
      strings.add(match.group(1) ?? '');
      continue;
    }
    final asNumber = double.tryParse(token);
    if (asNumber != null) {
      numbers.add(asNumber);
      continue;
    }

    // Operators.
    switch (token) {
      case 'q':
        ctmStack.add(ctm);
        lineWidthStack.add(lineWidth);
      case 'Q':
        if (ctmStack.isNotEmpty) ctm = ctmStack.removeLast();
        if (lineWidthStack.isNotEmpty) lineWidth = lineWidthStack.removeLast();
      case 'cm':
        if (numbers.length >= 6) {
          final n = numbers.sublist(numbers.length - 6);
          ctm = ctm.after(PdfMatrix(n[0], n[1], n[2], n[3], n[4], n[5]));
        }
      case 'Do':
        images.add(
          RecoveredImage(
            name: lastName,
            bottomLeft: ctm.apply(0, 0),
            topLeft: ctm.apply(0, 1),
            topRight: ctm.apply(1, 1),
            bottomRight: ctm.apply(1, 0),
          ),
        );
      case 'w':
        if (numbers.isNotEmpty) lineWidth = numbers.last;
      case 're':
        if (numbers.length >= 4) {
          final n = numbers.sublist(numbers.length - 4);
          rects.add(_mapRect(ctm, n[0], n[1], n[2], n[3], lineWidth));
          addPoint(n[0], n[1]);
          addPoint(n[0] + n[2], n[1]);
          addPoint(n[0] + n[2], n[1] + n[3]);
          addPoint(n[0], n[1] + n[3]);
        }
      case 'm' || 'l':
        if (numbers.length >= 2) {
          addPoint(numbers[numbers.length - 2], numbers[numbers.length - 1]);
        }
      case 'c':
        // Every control point counts: for `drawRRect` they all lie inside
        // the rectangle, so the hull is exact rather than merely an upper
        // bound. See `RecoveredPath`.
        if (numbers.length >= 6) {
          final n = numbers.sublist(numbers.length - 6);
          addPoint(n[0], n[1]);
          addPoint(n[2], n[3]);
          addPoint(n[4], n[5]);
        }
      case 'v' || 'y':
        if (numbers.length >= 4) {
          final n = numbers.sublist(numbers.length - 4);
          addPoint(n[0], n[1]);
          addPoint(n[2], n[3]);
        }
      case 'f' || 'F' || 'f*' || 'S' || 's' || 'B' || 'B*' || 'b' || 'b*':
        endPath();
      case 'n':
        // `n` ends a path without painting it -- it is how a clip is
        // committed. The points are discarded rather than recorded as ink.
        pathPoints = <(double, double)>[];
      case 'Tf':
        if (numbers.isNotEmpty) fontSize = numbers.last;
      case 'Td' || 'TD':
        if (numbers.length >= 2) {
          textX = numbers[numbers.length - 2];
          textY = numbers[numbers.length - 1];
        }
      case 'Tj' || 'TJ' || "'" || '"':
        if (strings.isNotEmpty) {
          final (x, y) = ctm.apply(textX, textY);
          texts.add(
            RecoveredText(
              text: strings.join(),
              baselineX: x,
              baselineY: y,
              sizePt: fontSize * ctm.uniformScale,
            ),
          );
        }
      default:
        break;
    }
    numbers.clear();
    strings.clear();
  }

  return RecoveredStream(rects, texts, paths, images: images);
}

RecoveredPath _hullOf(List<(double, double)> points, double lineWidthPt) {
  var left = points.first.$1;
  var right = points.first.$1;
  var bottom = points.first.$2;
  var top = points.first.$2;
  for (final p in points.skip(1)) {
    if (p.$1 < left) left = p.$1;
    if (p.$1 > right) right = p.$1;
    if (p.$2 < bottom) bottom = p.$2;
    if (p.$2 > top) top = p.$2;
  }
  return RecoveredPath(
    left: left,
    bottom: bottom,
    right: right,
    top: top,
    lineWidthPt: lineWidthPt,
    pointCount: points.length,
  );
}

RecoveredRect _mapRect(
  PdfMatrix ctm,
  double x,
  double y,
  double w,
  double h,
  double lineWidth,
) {
  final corners = <(double, double)>[
    ctm.apply(x, y),
    ctm.apply(x + w, y),
    ctm.apply(x + w, y + h),
    ctm.apply(x, y + h),
  ];
  var left = corners.first.$1;
  var right = corners.first.$1;
  var bottom = corners.first.$2;
  var top = corners.first.$2;
  for (final c in corners.skip(1)) {
    if (c.$1 < left) left = c.$1;
    if (c.$1 > right) right = c.$1;
    if (c.$2 < bottom) bottom = c.$2;
    if (c.$2 > top) top = c.$2;
  }
  return RecoveredRect(
    left: left,
    bottom: bottom,
    right: right,
    top: top,
    lineWidthPt: lineWidth * ctm.uniformScale,
  );
}

String _decodeHexString(String token, Map<int, int> toUnicode) {
  final hex = token.substring(1, token.length - 1);
  final buffer = StringBuffer();
  for (var i = 0; i + 4 <= hex.length; i += 4) {
    final code = int.parse(hex.substring(i, i + 4), radix: 16);
    buffer.writeCharCode(toUnicode[code] ?? code);
  }
  return buffer.toString();
}

/// Every `stream…endstream` body in [pdfBytes], as readable operator text.
///
/// A body is yielded RAW when the document was written with
/// `compress: false`, and INFLATED when it was not. Both are needed: the
/// furniture tests build their own `pw.Document(compress: false)`, while
/// the real export entry point compresses (a 45 U elevation is ~14 KB
/// compressed and several times that raw, and shipping the larger file to
/// make a test easier would be the test dictating the deliverable).
///
/// The string indices of `String.fromCharCodes` are byte indices — one
/// char per byte — which is what makes it safe to locate a body by regex
/// and then inflate the ORIGINAL bytes at the same offsets.
List<String> operatorStreams(Uint8List pdfBytes) {
  final source = String.fromCharCodes(pdfBytes); // bytes are 0..255 -> latin1
  final pattern = RegExp(r'stream\r?\n(.*?)\r?\nendstream', dotAll: true);
  final out = <String>[];
  for (final match in pattern.allMatches(source)) {
    final body = match.group(1)!;
    out.add(body);
    final start = match.start + match.group(0)!.indexOf(body);
    try {
      out.add(
        String.fromCharCodes(
          ZLibDecoder().convert(
            pdfBytes.sublist(start, start + body.length),
          ),
        ),
      );
      // A body that is not deflate — an uncompressed stream, or a font
      // blob in some other filter — simply has no inflated form. That is
      // an answer, not an error.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {}
  }
  return out;
}

/// Returns the content-operator stream containing [mustContain].
///
/// Picks the SMALLEST matching body, so the few-KB operator stream wins
/// over the multi-hundred-KB embedded font blob. The same trick
/// `apps/rackpal/test/baseline_parity_test.dart` already relies on.
String extractOperatorStream(
  Uint8List pdfBytes, {
  required String mustContain,
}) {
  String? best;
  for (final body in operatorStreams(pdfBytes)) {
    if (body.contains(mustContain) &&
        (best == null || body.length < best.length)) {
      best = body;
    }
  }
  if (best == null) {
    throw StateError('no content stream containing "$mustContain"');
  }
  return best;
}

/// Parses the `/ToUnicode` CMap dart_pdf writes for an embedded TrueType
/// font: glyph code -> Unicode code point.
///
/// THROWS when the document contains more than one `beginbfchar` block.
/// Two embedded fonts mean two independent code->character maps, and
/// merging them would silently mis-decode text. Failing loudly here is the
/// point: the day a second face is bundled, this throws instead of
/// producing plausible nonsense.
Map<int, int> parseToUnicodeCMap(Uint8List pdfBytes) {
  // EVERY STREAM BODY, RAW AND INFLATED. A compressed document keeps its
  // /ToUnicode CMap in a deflate stream like everything else, so a scan of
  // the raw bytes alone finds nothing and every text run decodes to glyph
  // codes — which looks exactly like a page that contains no text.
  //
  // `operatorStreams` yields BOTH forms of every body, so the raw file must
  // NOT also be scanned: an uncompressed document would then match the same
  // CMap twice and trip the two-font guard below on a document with one
  // font.
  final source = operatorStreams(pdfBytes).join('\n');
  final blocks = RegExp(
    'beginbfchar(.*?)endbfchar',
    dotAll: true,
  ).allMatches(source).toList();
  if (blocks.isEmpty) return const <int, int>{};
  if (blocks.length > 1) {
    throw StateError(
      'parseToUnicodeCMap: ${blocks.length} /ToUnicode blocks found. More '
      'than one embedded font means more than one code->character map, and '
      'merging them would mis-decode text. Decode per font instead.',
    );
  }
  final entries = RegExp(
    r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]{4})>',
  ).allMatches(blocks.single.group(1)!);
  return <int, int>{
    for (final e in entries)
      int.parse(e.group(1)!, radix: 16): int.parse(e.group(2)!, radix: 16),
  };
}
