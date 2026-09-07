// `FlutterDiagramCanvas.drawImage`, ON THE SCREEN (PLAN-A/3).
//
// ─────────────────────────────────────────────────────────────────────────
// THIS FILE RASTERISES, AND THAT IS DELIBERATE
// ─────────────────────────────────────────────────────────────────────────
// Almost every test in this repository asserts on DATA rather than pixels,
// which is what the display-list IR is for. This one cannot: the property
// under test is whether the picture arrives the right way up and the right
// way round, and the only artifact in which that is visible is the raster.
// A recorder-based test would assert that `drawImageRect` was called with
// two rects, which is a restatement of the code rather than a check on it,
// and would pass with the source and destination rects swapped.
//
// So a 2 x 2 image with four distinct colours is drawn into a 40 x 40 box
// and the four corners of the RESULT are sampled. Any flip, any
// transposition and any src/dst swap moves at least two of them.
//
// The sibling PDF assertion lives in
// `rackpal_export/test/pdf_canvas_image_test.dart` and is NOT symmetric:
// that backend needs a counter-flip and this one does not, because
// `ui.Canvas` is already top-left Y-down (docs/08 §7.6 divergence #1).
// Two tests, because one IR replayed two ways is exactly the thing CR-086
// promises and exactly the thing that can silently stop being true.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';

const ImageRef _ref = ImageRef(
  member: 'underlays/level-1.png',
  format: ImageFormat.png,
  pixelWidth: 2,
  pixelHeight: 2,
);

const int _side = 40;
const DBox _dst = DBox.fromLtwh(0, 0, 40, 40);

/// Four quadrants, four unmistakable colours, RGBA row-major from the TOP
/// row down, which is the order `decodeImageFromPixels` reads and the order
/// a screen draws.
final Uint8List _pixels = Uint8List.fromList(<int>[
  255, 0, 0, 255, // top-left     red
  0, 255, 0, 255, // top-right    green
  0, 0, 255, 255, // bottom-left  blue
  255, 255, 255, 255, // bottom-right white
]);

Future<ui.Image> _decode() {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    _pixels,
    2,
    2,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

/// Draws one image through the real canvas and rasterises the result.
Future<ByteData> _render(ui.Image source) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  FlutterDiagramCanvas(
    canvas,
    measurer: const _ZeroMeasurer(),
    images: (ref) => ref == _ref ? source : null,
  ).drawImage(_ref, _dst);
  final picture = recorder.endRecording();
  final raster = await picture.toImage(_side, _side);
  final bytes = await raster.toByteData();
  return bytes!;
}

/// The RGB of one pixel of a `rawRgba` buffer.
(int, int, int) _at(ByteData data, int x, int y) {
  final i = (y * _side + x) * 4;
  return (data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

/// Reads as "overwhelmingly this colour", rather than an exact match:
/// `FilterQuality.medium` blends, and the samples below are taken well
/// inside a quadrant precisely so the blend cannot reach them. An exact
/// match would be a test of the sampler.
Matcher _mostly(int r, int g, int b) => predicate<(int, int, int)>((c) {
  bool near(int actual, int want) => want > 127 ? actual > 200 : actual < 60;
  return near(c.$1, r) && near(c.$2, g) && near(c.$3, b);
}, 'approximately ($r, $g, $b)');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image source;

  setUpAll(() async {
    source = await _decode();
  });

  group('the picture arrives the right way up and the right way round', () {
    late ByteData out;

    setUpAll(() async {
      out = await _render(source);
    });

    test('the top-left of the image is the top-left of the destination', () {
      expect(_at(out, 4, 4), _mostly(255, 0, 0));
    });

    test('it is not mirrored top-to-bottom', () {
      // The single assertion a vertical flip fails: blue is the image's
      // BOTTOM-left and must land low.
      expect(_at(out, 4, 35), _mostly(0, 0, 255));
    });

    test('it is not mirrored left-to-right', () {
      expect(_at(out, 35, 4), _mostly(0, 255, 0));
    });

    test('it is not transposed', () {
      // A transposition swaps green and blue and leaves red and white
      // where they are, so the two assertions above are what catch it and
      // this one states the remaining corner.
      expect(_at(out, 35, 35), _mostly(255, 255, 255));
    });

    test('it fills the destination: the far corners are painted', () {
      expect(_at(out, 0, 0), _mostly(255, 0, 0));
      expect(_at(out, _side - 1, _side - 1), _mostly(255, 255, 255));
    });
  });

  group('a reference nobody can resolve is an error, not a blank frame', () {
    test('a canvas with no resolver throws MissingImageError', () {
      final canvas = ui.Canvas(ui.PictureRecorder());
      expect(
        () => FlutterDiagramCanvas(
          canvas,
          measurer: const _ZeroMeasurer(),
        ).drawImage(_ref, _dst),
        throwsA(isA<MissingImageError>()),
      );
    });

    test('a resolver that does not know this member throws too', () {
      final canvas = ui.Canvas(ui.PictureRecorder());
      expect(
        () => FlutterDiagramCanvas(
          canvas,
          measurer: const _ZeroMeasurer(),
          images: (ref) => null,
        ).drawImage(_ref, _dst),
        throwsA(isA<MissingImageError>()),
      );
    });
  });
}

/// Text plays no part here; this exists so the canvas has the collaborator
/// its constructor requires.
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
