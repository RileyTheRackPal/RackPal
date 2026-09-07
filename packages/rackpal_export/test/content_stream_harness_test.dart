// THE HARNESS SELF-TEST.
//
// `test/support/content_stream.dart` is what every PDF-geometry assertion
// in this package stands on. If it silently recovered ZERO rectangles,
// every `expect(rects.where(...), ...)` built on it would pass vacuously --
// and this project has already shipped a check that "passed" three times
// while a real defect sat underneath it.
//
// So the interpreter is exercised against HAND-WRITTEN content streams
// whose correct answers are worked out by hand in the test, with no
// production code involved on either side.

import 'dart:typed_data';

import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

void main() {
  group('CTM interpretation', () {
    test('a bare rectangle with no transform is recovered verbatim', () {
      final recovered = interpretContentStream('10 20 30 40 re S');

      expect(recovered.rects, hasLength(1));
      final r = recovered.rects.single;
      expect(r.left, closeTo(10, 1e-9));
      expect(r.bottom, closeTo(20, 1e-9));
      expect(r.width, closeTo(30, 1e-9));
      expect(r.height, closeTo(40, 1e-9));
    });

    test('a translate moves the rectangle by exactly the translation', () {
      final recovered = interpretContentStream(
        '1 0 0 1 100 200 cm 10 20 30 40 re S',
      );

      final r = recovered.rects.single;
      expect(r.left, closeTo(110, 1e-9));
      expect(r.bottom, closeTo(220, 1e-9));
      expect(r.width, closeTo(30, 1e-9));
      expect(r.height, closeTo(40, 1e-9));
    });

    test(
      'the Y-flip idiom maps a top-left box to the right user-space band',
      () {
        // This is EXACTLY what PdfDiagramCanvas emits: one global flip about
        // the box height, then diagram-space (top-left origin, Y down)
        // rectangles. A 1000 pt tall page, a box whose top is 100 below the
        // page top and which is 300 tall, must land at user-space Y 600..900.
        final recovered = interpretContentStream(
          '1 0 0 -1 0 1000 cm 50 100 200 300 re S',
        );

        final r = recovered.rects.single;
        expect(r.left, closeTo(50, 1e-9));
        expect(r.right, closeTo(250, 1e-9));
        expect(r.bottom, closeTo(600, 1e-9));
        expect(r.top, closeTo(900, 1e-9));
      },
    );

    test('a scale inside q/Q applies, and Q restores the outer CTM', () {
      final recovered = interpretContentStream(
        '1 0 0 1 10 10 cm '
        'q 2 0 0 2 0 0 cm 0 0 50 50 re S Q '
        '0 0 50 50 re S',
      );

      expect(recovered.rects, hasLength(2));
      // Inside the bracket: scaled by 2, then the outer translate.
      expect(recovered.rects[0].left, closeTo(10, 1e-9));
      expect(recovered.rects[0].width, closeTo(100, 1e-9));
      // After Q: the scale is gone, the translate remains.
      expect(recovered.rects[1].left, closeTo(10, 1e-9));
      expect(recovered.rects[1].width, closeTo(50, 1e-9));
    });

    test('nested cm operators compose in PDF order (local first)', () {
      // translate(100, 0) then scale(3) means the SCALE applies to the
      // rectangle first and the translate afterwards -- so x = 100 + 3·10.
      final recovered = interpretContentStream(
        '1 0 0 1 100 0 cm 3 0 0 3 0 0 cm 10 0 5 5 re S',
      );

      final r = recovered.rects.single;
      expect(r.left, closeTo(130, 1e-9));
      expect(r.width, closeTo(15, 1e-9));
    });

    test('a ROTATION composes correctly too, which diagonal matrices '
        'cannot prove', () {
      // Every matrix in the tests above is diagonal-plus-translation, and
      // several plausible mis-orderings of the concatenation agree on
      // those. A rotation has non-zero off-diagonal terms and separates
      // them -- and `PdfDiagramCanvas.drawText` really does emit rotations,
      // so this is coverage of a shape the exporter can produce.
      //
      // `0 1 -1 0 0 0` maps (x, y) -> (-y, x): 90 degrees. Applied FIRST,
      // then translated by (100, 0), the corner (10, 0) lands at (100, 10)
      // and the 5x5 rect spans x 95..100, y 10..15. Composed the other way
      // round it would land at (0, 110) -- nowhere near.
      final recovered = interpretContentStream(
        '1 0 0 1 100 0 cm 0 1 -1 0 0 0 cm 10 0 5 5 re S',
      );

      final r = recovered.rects.single;
      expect(r.left, closeTo(95, 1e-9));
      expect(r.right, closeTo(100, 1e-9));
      expect(r.bottom, closeTo(10, 1e-9));
      expect(r.top, closeTo(15, 1e-9));
    });

    test('45 degrees INSIDE 90 degrees composes to 135 — the case that '
        'needs all four linear terms', () {
      // Every case above leaves at least one of the two matrices diagonal,
      // so a composition that silently drops a cross term still passes
      // them. This one does not: both matrices have four non-zero linear
      // terms, so dropping ANY of a/b/c/d moves the answer.
      //
      // 45 applied first, then 90, is a 135-degree rotation:
      //   (x, y) -> (-s·x - s·y,  s·x - s·y),  s = cos 45.
      // For the 5x5 rect at (10, 0) that is x -14.142..-7.071,
      // y 3.536..10.607. Not academic: the exporter draws rotated text
      // inside a scaled, translated bracket, so both matrices are
      // non-trivial on a real elevation sheet.
      final recovered = interpretContentStream(
        '0 1 -1 0 0 0 cm '
        '0.70710678 0.70710678 -0.70710678 0.70710678 0 0 cm '
        '10 0 5 5 re S',
      );

      final r = recovered.rects.single;
      expect(r.left, closeTo(-14.1421356, 1e-5));
      expect(r.right, closeTo(-7.0710678, 1e-5));
      expect(r.bottom, closeTo(3.5355339, 1e-5));
      expect(r.top, closeTo(10.6066017, 1e-5));
      // Two rotations are still unit scale.
      expect(r.lineWidthPt, closeTo(1, 1e-5));
    });

    test('a translate INSIDE a rotation is rotated too — the case that '
        'needs both translation terms', () {
      // The translation column of the composition is `local.e·a +
      // local.f·c + e`. A test whose outer matrix is diagonal cannot see
      // the `local.f · c` term at all. Under a 90-degree outer CTM, the
      // inner translate (30, 40) must itself rotate to (-40, 30).
      final recovered = interpretContentStream(
        '0 1 -1 0 0 0 cm 1 0 0 1 30 40 cm 0 0 5 5 re S',
      );

      final r = recovered.rects.single;
      expect(r.left, closeTo(-45, 1e-9));
      expect(r.right, closeTo(-40, 1e-9));
      expect(r.bottom, closeTo(30, 1e-9));
      expect(r.top, closeTo(35, 1e-9));
    });

    test('a rotated CTM still reports a uniform scale of 1', () {
      // `uniformScale` is what turns a stroke width into a paper width; a
      // rotation must not change it.
      final recovered = interpretContentStream(
        '0 1 -1 0 0 0 cm 2 w 0 0 10 10 re S',
      );
      expect(recovered.rects.single.lineWidthPt, closeTo(2, 1e-9));
    });

    test('line width is reported scaled to paper, and Q restores it', () {
      final recovered = interpretContentStream(
        'q 0.5 0 0 0.5 0 0 cm 2 w 0 0 10 10 re S Q '
        '3 w 0 0 10 10 re S',
      );

      // 2 pt of line width under a 0.5x CTM is 1 pt on paper.
      expect(recovered.rects[0].lineWidthPt, closeTo(1, 1e-9));
      expect(recovered.rects[1].lineWidthPt, closeTo(3, 1e-9));
    });
  });

  group('general path recovery — the half `re` alone cannot see', () {
    // WHY THIS GROUP EXISTS. A device block at `LodLevel.full` is an
    // `OpRoundRect`, which lowers to `PdfGraphics.drawRRect` and emits
    // `m`/`l`/`c` and NO `re` at all. A harness that only understood `re`
    // would recover ZERO device blocks from a real elevation sheet, and
    // every assertion about their size and spacing would pass vacuously —
    // which is the precise shape of test this project keeps shipping. So
    // the path machinery gets its own self-test, against hand-written
    // streams whose answers are worked out here.

    test('a moveTo/lineTo polygon is hulled correctly', () {
      final recovered = interpretContentStream(
        '10 20 m 40 20 l 40 60 l 10 60 l S',
      );

      expect(recovered.paths, hasLength(1));
      final p = recovered.paths.single;
      expect(p.left, closeTo(10, 1e-9));
      expect(p.bottom, closeTo(20, 1e-9));
      expect(p.right, closeTo(40, 1e-9));
      expect(p.top, closeTo(60, 1e-9));
      expect(p.pointCount, 4);
    });

    test('a drawRRect-shaped path hulls to EXACTLY the rectangle, '
        'control points included', () {
      // Transcribed from `PdfGraphics.drawRRect(0, 0, 100, 50, 3, 3)` with
      // `_m4 = 0.4477`: every control point lies inside the rectangle, so
      // the hull is the rectangle itself rather than an over-estimate.
      const m = 0.4477;
      const r = 3.0;
      const w = 100.0;
      const h = 50.0;
      final k = (r - m * r).toStringAsFixed(6);
      final stream =
          '0 $r m '
          '0 $k $k 0 $r 0 c '
          '${w - r} 0 l '
          '${m * r + w - r} 0 $w $k $w $r c '
          '$w ${h - r} l '
          '$w ${m * r + h - r} ${m * r + w - r} $h ${w - r} $h c '
          '$r $h l '
          '$k $h 0 ${m * r + h - r} 0 ${h - r} c '
          '0 $r l f';

      final recovered = interpretContentStream(stream);
      final p = recovered.paths.single;
      expect(p.left, closeTo(0, 1e-6));
      expect(p.bottom, closeTo(0, 1e-6));
      expect(p.width, closeTo(w, 1e-6));
      expect(p.height, closeTo(h, 1e-6));
      // 17 points: 1 moveTo + 4 lineTo + 4 curves x 3 points.
      expect(p.pointCount, 17);
    });

    test('a path is transformed by the CTM as it is BUILT, not afterwards', () {
      // A `cm` between two segments of one path is legal PDF, and mapping
      // the hull at the end instead of the points as they arrive would put
      // the first half in the wrong space. Under the Y-flip idiom the two
      // segments must land in different bands.
      final recovered = interpretContentStream(
        '1 0 0 -1 0 1000 cm 0 100 m 10 100 l q 1 0 0 1 0 400 cm 0 0 m Q S',
      );

      final p = recovered.paths.single;
      // (0, 100) under the flip is user-space y 900; (0, 0) under the flip
      // plus a 400 translate in the flipped frame is user-space y 600.
      expect(p.top, closeTo(900, 1e-9));
      expect(p.bottom, closeTo(600, 1e-9));
    });

    test('`n` ends a path WITHOUT recording ink — a clip is not a shape', () {
      // `W n` is exactly what `PdfDiagramCanvas.clipRect` emits, and the
      // hatch band on a blank panel emits one per device. Counting a clip
      // as ink would report a shape nobody can see.
      final recovered = interpretContentStream(
        '0 0 100 100 re W n 5 5 m 6 6 l S',
      );

      expect(recovered.paths, hasLength(1));
      expect(recovered.paths.single.left, closeTo(5, 1e-9));
      // The `re` is still counted as a RECTANGLE, because that list is
      // about the operator and not about paint.
      expect(recovered.rects, hasLength(1));
    });

    test('every painting operator closes the path', () {
      for (final op in <String>[
        'f',
        'F',
        'f*',
        'S',
        's',
        'B',
        'B*',
        'b',
        'b*',
      ]) {
        final recovered = interpretContentStream('0 0 m 10 10 l $op');
        expect(recovered.paths, hasLength(1), reason: op);
      }
    });

    test('pathSized throws rather than matching nothing', () {
      final recovered = interpretContentStream('0 0 m 10 10 l S');

      expect(() => recovered.pathSized(999, 999), throwsStateError);
      expect(recovered.pathSized(10, 10).left, closeTo(0, 1e-9));
    });

    test('pathSized throws rather than SILENTLY PICKING THE FIRST of two '
        'same-sized shapes', () {
      // ==================================================================
      // THE GUARD ITS OWN DOC COMMENT PROMISED AND DID NOT IMPLEMENT.
      // ==================================================================
      // `elevation_true_scale_test.dart` reaches the chassis frame through
      // `pathSized` and then asserts WHERE it is on the paper. Two shapes
      // of the same size in two places make that an assertion about
      // whichever the interpreter happened to emit first — a green test
      // about an arbitrary rectangle, which is the exact failure mode this
      // package's harness exists to refuse.
      final recovered = interpretContentStream(
        '0 0 m 100 0 l 100 50 l 0 50 l S ' // a 100x50 at the origin
        '0 200 m 100 200 l 100 250 l 0 250 l S', // another, 200 higher
      );

      expect(recovered.pathsSized(100, 50), hasLength(2));
      expect(
        () => recovered.pathSized(100, 50),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('not unique'), contains('2')),
          ),
        ),
      );
      // ...and the caller that MEANT "both of them" still has a way to say
      // so, so the guard is a clarification and not a wall.
      expect(recovered.pathsSized(100, 50), hasLength(2));
    });

    test('a FILL AND A STROKE of one shape are ONE shape, and pathSized '
        'still answers', () {
      // `PdfDiagramCanvas.drawRoundRect` builds its path once per paint
      // operation, so a filled-and-stroked device block reaches the stream
      // as the same geometry twice. That is one block on the paper. A
      // uniqueness guard that counted raw matches would reject every
      // filled shape in the exporter — including the chassis frame the day
      // it gains a fill, which is precisely the change the guard is
      // supposed to survive rather than to forbid.
      const shape = '0 0 m 100 0 l 100 50 l 0 50 l';
      final recovered = interpretContentStream('$shape f $shape S');

      expect(recovered.pathsSized(100, 50), hasLength(2));
      expect(recovered.distinctPathsSized(100, 50), hasLength(1));
      expect(recovered.pathSized(100, 50).width, closeTo(100, 1e-9));
    });
  });

  group('text recovery', () {
    test('a hex string decodes and its baseline maps through the CTM', () {
      // <0048 0049> is "HI" when the code IS the code point, which is the
      // identity fallback the interpreter uses without a /ToUnicode map.
      final recovered = interpretContentStream(
        '1 0 0 -1 60 60 cm BT /F1 8 Tf 0 -6 Td [<00480049>]TJ ET',
      );

      expect(recovered.texts, hasLength(1));
      final t = recovered.texts.single;
      expect(t.text, 'HI');
      expect(t.baselineX, closeTo(60, 1e-9));
      // The local frame is Y-up (the flip), so Td (0, -6) lands at 60 + 6.
      expect(t.baselineY, closeTo(66, 1e-9));
      expect(t.sizePt, closeTo(8, 1e-9));
    });

    test('a /ToUnicode map is applied to the glyph codes', () {
      final recovered = interpretContentStream(
        'BT /F1 10 Tf 0 0 Td [<00010002>]TJ ET',
        toUnicode: const <int, int>{1: 0x4F, 2: 0x4B},
      );

      expect(recovered.texts.single.text, 'OK');
    });

    test('a dash array does not corrupt the operand stack', () {
      // `[] 0 d` sits between the stroke setup and the rectangle in every
      // stream PdfDiagramCanvas emits.
      final recovered = interpretContentStream('[] 0 d 5 5 10 10 re S');

      expect(recovered.rects, hasLength(1));
      expect(recovered.rects.single.left, closeTo(5, 1e-9));
    });
  });

  group('stream extraction', () {
    test('extractOperatorStream picks the smallest matching body', () {
      final bytes = Uint8List.fromList(
        'x stream\nBIG ${'.' * 500} MARK\nendstream '
                'y stream\nSMALL MARK\nendstream'
            .codeUnits,
      );

      expect(extractOperatorStream(bytes, mustContain: 'MARK'), 'SMALL MARK');
    });

    test('extractOperatorStream throws rather than returning nothing', () {
      final bytes = Uint8List.fromList('stream\nnothing\nendstream'.codeUnits);

      expect(
        () => extractOperatorStream(bytes, mustContain: 'ABSENT'),
        throwsStateError,
      );
    });

    test('parseToUnicodeCMap reads a single bfchar block', () {
      // WRAPPED IN A `stream…endstream`, because that is where a real PDF
      // keeps it and because the scan looks at stream BODIES rather than at
      // the whole file — a compressed document's CMap is deflate-encoded
      // like everything else, so scanning the raw bytes finds nothing and
      // every text run silently decodes to glyph codes.
      final bytes = Uint8List.fromList(
        'stream\n2 beginbfchar\n<0001> <0041>\n<0002> <2014>\nendbfchar\n'
                'endstream'
            .codeUnits,
      );

      expect(parseToUnicodeCMap(bytes), <int, int>{1: 0x41, 2: 0x2014});
    });

    test('parseToUnicodeCMap finds NOTHING when there is nothing, rather '
        'than throwing', () {
      // An empty map is the honest answer for a document with no embedded
      // font, and it is what makes the identity fallback (code == code
      // point) work for the hand-written streams above.
      expect(
        parseToUnicodeCMap(
          Uint8List.fromList('stream\n0 0 10 10 re S\nendstream'.codeUnits),
        ),
        isEmpty,
      );
    });

    test('parseToUnicodeCMap throws on two embedded fonts rather than '
        'silently merging their maps', () {
      final bytes = Uint8List.fromList(
        'stream\n1 beginbfchar\n<0001> <0041>\nendbfchar\nendstream '
                'stream\n1 beginbfchar\n<0001> <0042>\nendbfchar\nendstream'
            .codeUnits,
      );

      expect(() => parseToUnicodeCMap(bytes), throwsStateError);
    });
  });

  group('XObject recovery, for the image ops PLAN-A added', () {
    // WHY CORNERS AND NOT A BOX: a PDF image occupies the unit square with
    // its TOP row at v = 1, so a vertically flipped placement produces an
    // IDENTICAL bounding box and an upside-down floorplan. The interpreter
    // is therefore asked for the image's own corners, and these cases
    // check it can tell the two apart on hand-written streams.

    test('a unit-square Do under an identity CTM is the unit square', () {
      final img = interpretContentStream('/I0 Do').images.single;
      expect(img.name, 'I0');
      expect(img.bottomLeft, (0.0, 0.0));
      expect(img.topLeft, (0.0, 1.0));
      expect(img.topRight, (1.0, 1.0));
      expect(img.bottomRight, (1.0, 0.0));
    });

    test('the placement cm is applied, so a 120 x 60 image is 120 x 60', () {
      final img = interpretContentStream(
        'q 120 0 0 60 20 30 cm /Im1 Do Q',
      ).images.single;
      expect(img.name, 'Im1');
      expect(img.bottomLeft, (20.0, 30.0));
      expect(img.topRight, (140.0, 90.0));
    });

    test('A FLIPPED PLACEMENT IS DISTINGUISHABLE FROM AN UPRIGHT ONE, '
        'which is the whole reason this records corners', () {
      const upright = 'q 120 0 0 60 20 30 cm /I Do Q';
      const flipped = 'q 120 0 0 -60 20 90 cm /I Do Q';

      final a = interpretContentStream(upright).images.single;
      final b = interpretContentStream(flipped).images.single;

      // Same box on the page, both ways.
      double lo(RecoveredImage i) =>
          i.bottomLeft.$2 < i.topLeft.$2 ? i.bottomLeft.$2 : i.topLeft.$2;
      double hi(RecoveredImage i) =>
          i.bottomLeft.$2 > i.topLeft.$2 ? i.bottomLeft.$2 : i.topLeft.$2;
      expect(lo(a), lo(b));
      expect(hi(a), hi(b));

      // Opposite orientations, which is the fact a box cannot carry.
      expect(a.topLeft.$2, greaterThan(a.bottomLeft.$2));
      expect(b.topLeft.$2, lessThan(b.bottomLeft.$2));
    });

    test('the CTM in force at Do is the one used, not the one after Q', () {
      final images = interpretContentStream(
        'q 10 0 0 10 0 0 cm /A Do Q q 20 0 0 20 5 5 cm /B Do Q',
      ).images;
      expect(images.map((i) => i.name), ['A', 'B']);
      expect(images[0].topRight, (10.0, 10.0));
      expect(images[1].topRight, (25.0, 25.0));
    });

    test('a stream with no Do recovers no images, so an assertion about '
        'one cannot pass vacuously', () {
      expect(interpretContentStream('10 20 30 40 re S').images, isEmpty);
    });
  });

  group('the export package still exposes what the harness targets', () {
    test('the ANSI formats are reachable through the barrel', () {
      // Guards against the harness being exercised against a package that
      // no longer exports what the other tests import.
      expect(ansiBPortrait.width, 792);
      expect(ansiBPortrait.height, 1224);
    });
  });
}
