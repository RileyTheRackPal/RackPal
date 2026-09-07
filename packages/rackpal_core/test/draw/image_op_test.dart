// `OpImage`, `ImageRef` and the bounds pass, PLAN-A/2.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT THIS FILE IS ACTUALLY GUARDING, WHICH IS NOT "AN OP EXISTS"
// ─────────────────────────────────────────────────────────────────────────
// The op was added so a floorplan can print under callouts. The property
// that makes it safe to add is that it does NOT make a display list
// expensive to compare or to hold: it carries a container-member NAME and
// two integers, and the two backends resolve that name to bytes. A future
// hand reaching for the obvious convenience -- "just put the `Uint8List`
// on the op" -- would keep every assertion here passing except the digest
// ones, so those are written to fail if the identity of an image op ever
// stops being its reference.
//
// The bounds assertions are the other half. `BoundsCanvas` drives
// scale-to-fit and the elevation tile count, and it must be able to
// measure a scene containing a 4000 x 3000 architectural page without
// decoding it. It can, because the destination rect IS the ink.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import '../scene/op_digest.dart';

const ImageRef _ref = ImageRef(
  member: 'underlays/1c1f.png',
  format: ImageFormat.png,
  pixelWidth: 4000,
  pixelHeight: 3000,
);

const DBox _dst = DBox.fromLtwh(10, 20, 300, 225);

/// Records what the interface was asked to do, and nothing else.
final class _Recorder implements DiagramCanvas {
  final List<(ImageRef, DBox)> images = [];
  final List<Matrix4> _stack = [Matrix4.identity()];

  @override
  void drawImage(ImageRef image, DBox dst) => images.add((image, dst));

  // Everything else is unused by this file and must stay unimplemented
  // rather than silently succeed: a recorder that swallowed a call would
  // make an assertion about op ORDER pass over a scene that drew nothing.
  @override
  void save() => _stack.add(_stack.last.clone());
  @override
  void restore() => _stack.removeLast();
  @override
  int get saveCount => _stack.length;
  @override
  Matrix4 get currentTransform => _stack.last.clone();
  @override
  void transform(Matrix4 m) => throw UnimplementedError();
  @override
  void translate(double dx, double dy) => throw UnimplementedError();
  @override
  void scale(double sx, [double? sy]) => throw UnimplementedError();
  @override
  void rotate(double radians) => throw UnimplementedError();
  @override
  void clipRect(DBox r) => throw UnimplementedError();
  @override
  void clipPath(DiagramPath p, {FillRule rule = FillRule.nonZero}) =>
      throw UnimplementedError();
  @override
  void drawLine(DPt a, DPt b, Stroke s) => throw UnimplementedError();
  @override
  void drawPolyline(List<DPt> pts, Stroke s, {bool close = false}) =>
      throw UnimplementedError();
  @override
  void drawPath(DiagramPath p, {Fill? fill, Stroke? stroke}) =>
      throw UnimplementedError();
  @override
  void drawRect(DBox r, {Fill? fill, Stroke? stroke}) =>
      throw UnimplementedError();
  @override
  void drawRoundRect(DBox r, Radii radii, {Fill? fill, Stroke? stroke}) =>
      throw UnimplementedError();
  @override
  void drawCircle(DPt c, double radius, {Fill? fill, Stroke? stroke}) =>
      throw UnimplementedError();
  @override
  void drawEllipse(DPt c, double rx, double ry, {Fill? fill, Stroke? stroke}) =>
      throw UnimplementedError();
  @override
  void drawText(String text, DPt at, TextStyleSpec style) =>
      throw UnimplementedError();
  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      throw UnimplementedError();
}

void main() {
  group('ImageRef is a value, so a display list stays comparable by data', () {
    test('two refs naming the same member with the same facts are equal', () {
      const a = ImageRef(
        member: 'underlays/1c1f.png',
        format: ImageFormat.png,
        pixelWidth: 4000,
        pixelHeight: 3000,
      );
      expect(a, _ref);
      expect(a.hashCode, _ref.hashCode);
      // Built at RUNTIME from a concatenation, so `const` canonicalisation
      // cannot be what makes this pass: it is value equality or nothing.
      final built = ImageRef(
        member: <String>['underlays/', '1c1f', '.png'].join(),
        format: ImageFormat.png,
        pixelWidth: 2000 * 2,
        pixelHeight: 3000,
      );
      expect(identical(built, _ref), isFalse);
      expect(built, _ref);
      expect(built.hashCode, _ref.hashCode);
    });

    test('each of the four fields is load-bearing in ==', () {
      expect(
        const ImageRef(
          member: 'underlays/other.png',
          format: ImageFormat.png,
          pixelWidth: 4000,
          pixelHeight: 3000,
        ),
        isNot(_ref),
      );
      expect(
        const ImageRef(
          member: 'underlays/1c1f.png',
          format: ImageFormat.jpeg,
          pixelWidth: 4000,
          pixelHeight: 3000,
        ),
        isNot(_ref),
      );
      expect(
        const ImageRef(
          member: 'underlays/1c1f.png',
          format: ImageFormat.png,
          pixelWidth: 4001,
          pixelHeight: 3000,
        ),
        isNot(_ref),
      );
      expect(
        const ImageRef(
          member: 'underlays/1c1f.png',
          format: ImageFormat.png,
          pixelWidth: 4000,
          pixelHeight: 3001,
        ),
        isNot(_ref),
      );
    });

    test('aspectRatio is the fact a fit rule needs without decoding', () {
      expect(_ref.aspectRatio, closeTo(4 / 3, 1e-12));
    });

    test('a zero or negative intrinsic size is refused', () {
      expect(
        () => ImageRef(
          member: 'm.png',
          format: ImageFormat.png,
          pixelWidth: 0,
          pixelHeight: 10,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ImageRef(
          member: 'm.png',
          format: ImageFormat.png,
          pixelWidth: 10,
          pixelHeight: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the extension a member carries follows the format', () {
      expect(ImageFormat.png.extension, 'png');
      expect(ImageFormat.jpeg.extension, 'jpg');
    });
  });

  group('OpImage forwards to the one canvas method', () {
    test('replay hands the canvas exactly the ref and rect it holds', () {
      final canvas = _Recorder();
      const OpImage(_ref, _dst).replay(canvas);
      expect(canvas.images, hasLength(1));
      expect(canvas.images.single.$1, _ref);
      expect(canvas.images.single.$2, _dst);
    });

    test('a scene replays its image op in list order', () {
      final canvas = _Recorder();
      const DiagramScene(
        ops: [OpSave(), OpImage(_ref, _dst), OpRestore()],
        bounds: _dst,
        hits: [],
        minTextSizePt: 0,
        fragments: {},
      ).replay(canvas);
      expect(canvas.images, hasLength(1));
      expect(canvas.saveCount, 1, reason: 'save/restore balanced');
    });
  });

  group('BoundsCanvas measures the destination without touching bytes', () {
    const measurer = _ZeroMeasurer();

    test('an image inks exactly its destination rect, with no inflation', () {
      expect(
        inkBoundsOf(const [OpImage(_ref, _dst)], measurer: measurer),
        _dst,
      );
    });

    test('the intrinsic pixel size does not reach the ink extent', () {
      // 4000 x 3000 pixels drawn into 300 x 225 points. A bounds pass that
      // reached for the picture's own size instead of the rect would
      // report a box thirteen times too big and scale-to-fit would shrink
      // every sheet to nothing.
      final box = inkBoundsOf(
        const [OpImage(_ref, _dst)],
        measurer: measurer,
      )!;
      expect(box.width, 300);
      expect(box.height, 225);
    });

    test('a translated image inks where the transform puts it', () {
      final box = inkBoundsOf([
        const OpSave(),
        OpTransform(Matrix4.translationValues(40, 5, 0)),
        const OpImage(_ref, _dst),
        const OpRestore(),
      ], measurer: measurer)!;
      expect(box.left, 50);
      expect(box.top, 25);
      expect(box.right, 350);
      expect(box.bottom, 250);
    });

    test('a clip removes the ink it removes', () {
      final box = inkBoundsOf(const [
        OpClipRect(DBox.fromLtwh(0, 0, 100, 100)),
        OpImage(_ref, _dst),
      ], measurer: measurer)!;
      expect(box, const DBox.fromLtwh(10, 20, 90, 80));
    });

    test('a scene with no image op still measures nothing', () {
      expect(inkBoundsOf(const [], measurer: measurer), isNull);
    });
  });

  group('the determinism digest is lossless on an image op', () {
    test('it names the op and every field the op carries', () {
      final line = digestOps(const [OpImage(_ref, _dst)]);
      expect(line, contains('image'));
      expect(line, contains('underlays/1c1f.png'));
      expect(line, contains('png'));
      expect(line, contains('4000x3000'));
      expect(line, contains('10.0,20.0,310.0,245.0'));
    });

    test('EVERY field is visible to the digest, one mutation at a time', () {
      // The anti-vacuity assertion. A digest that recorded only "image"
      // would pass every `contains` above and would report two different
      // underlays as the same drawing.
      final base = digestOps(const [OpImage(_ref, _dst)]);
      final mutations = <String, List<DiagramOp>>{
        'member': const [
          OpImage(
            ImageRef(
              member: 'underlays/other.png',
              format: ImageFormat.png,
              pixelWidth: 4000,
              pixelHeight: 3000,
            ),
            _dst,
          ),
        ],
        'format': const [
          OpImage(
            ImageRef(
              member: 'underlays/1c1f.png',
              format: ImageFormat.jpeg,
              pixelWidth: 4000,
              pixelHeight: 3000,
            ),
            _dst,
          ),
        ],
        'pixelWidth': const [
          OpImage(
            ImageRef(
              member: 'underlays/1c1f.png',
              format: ImageFormat.png,
              pixelWidth: 4001,
              pixelHeight: 3000,
            ),
            _dst,
          ),
        ],
        'pixelHeight': const [
          OpImage(
            ImageRef(
              member: 'underlays/1c1f.png',
              format: ImageFormat.png,
              pixelWidth: 4000,
              pixelHeight: 3001,
            ),
            _dst,
          ),
        ],
        'dst': const [OpImage(_ref, DBox.fromLtwh(10, 20, 300, 226))],
      };
      for (final entry in mutations.entries) {
        expect(
          digestOps(entry.value),
          isNot(base),
          reason: 'the digest cannot see a changed ${entry.key}',
        );
      }
    });

    test('the same op digests the same twice, which is the point', () {
      expect(
        digestOps(const [OpImage(_ref, _dst)]),
        digestOps(const [OpImage(_ref, _dst)]),
      );
    });
  });

  group('a reference nobody can resolve is an error, not a blank page', () {
    test('the message names the member so the fault is findable', () {
      final e = MissingImageError(_ref);
      expect(e.toString(), contains('underlays/1c1f.png'));
      expect(e.toString(), contains('wiring fault'));
    });
  });
}

/// Text plays no part here; this measurer exists so `inkBoundsOf` has the
/// collaborator its signature requires.
final class _ZeroMeasurer implements TextMeasurer {
  const _ZeroMeasurer();

  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const TextMetrics(
        advanceWidth: 0,
        ascent: 0,
        descent: 0,
        capHeight: 0,
        xHeight: 0,
        lineHeight: 0,
      );
}
