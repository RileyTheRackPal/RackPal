// PLAN-E/2: the plan canvas render object and the image cache behind it.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIRST GROUP IS THE ONE PLAN-E/1 EXISTS TO HAVE PRODUCED, AND ITS
// PRESCRIPTION WAS WRONG IN A WAY WORTH RECORDING
// ═══════════════════════════════════════════════════════════════════════
// The spike ran a mutation that SURVIVED: dropping the paint-offset term
// out of a plan render object's transform left all six of its cases green.
// docs/12 §5.9.7.5 concluded that this chapter owed "a case that places the
// canvas below a toolbar". **That case was written and it cannot pass.**
//
// The reason is structural, not incidental. This object is
// `isRepaintBoundary`, so Flutter paints it at `Offset.zero` ALWAYS and
// carries the on-screen position on the layer instead. Putting the canvas
// under a 60px toolbar and reading `debugSceneToScreen` back gives 0, not
// 60, because the offset genuinely IS zero: the term is not being dropped,
// it has nothing in it. A widget test cannot observe the composition
// because at run time there is no composition to observe.
//
// `render_schematic_canvas.dart` reached the same wall first and its own
// test file says so: a mutation that dropped the term "survived the suite,
// which is why `schematicSceneToScreen` exists as a free function". The
// protection is the FREE FUNCTION driven with the offset a non-boundary
// would get, which is the first group here. The widget cases below assert
// what a widget test genuinely can see: that the viewport reaches the
// matrix, and that a pan repaints.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9, 8);

PlanUnderlay _underlay() => PlanUnderlay(
  id: const Uuid('ul-1'),
  name: 'Level 1',
  imageMember: 'underlays/ul-1.png',
  format: PlanImageFormat.png,
  pixelWidth: 400,
  pixelHeight: 300,
  contentHash: 'sha256:test',
  order: const FracIndex('a0'),
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
);

/// A real, tiny PNG, encoded here rather than read off disk so this file
/// needs no asset bundle and no `rootBundle` (whose stale-cache trap this
/// repository has its own note about).
Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF884422),
  );
  final image = await recorder.endRecording().toImage(w, h);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Loads a real PNG into [cache] from inside a widget test.
///
/// ═══════════════════════════════════════════════════════════════════════
/// `tester.runAsync` IS NOT OPTIONAL, AND ITS ABSENCE HANGS SILENTLY
/// ═══════════════════════════════════════════════════════════════════════
/// A `testWidgets` body runs in `flutter_test`'s FAKE-ASYNC zone, where
/// time is controlled by the harness and real engine work never lands.
/// `Picture.toImage` and `ui.instantiateImageCodec` are real engine work,
/// so awaiting either inside that zone waits forever: the file produces no
/// output at all and reads exactly like a slow suite rather than like a
/// deadlock. `runAsync` steps outside the zone for the duration.
///
/// The bare `test` cases in the cache group below need none of this --
/// there is no fake-async zone in a plain `test` -- which is why only the
/// widget cases route through here.
Future<void> _loadInto(
  WidgetTester tester,
  PlanImageCache cache,
  String member,
  int w,
  int h,
) async {
  await tester.runAsync(() async {
    await cache.load(member, await _png(w, h));
  });
}

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

Widget _host({
  required DiagramScene scene,
  required ViewportController viewport,
  required FlutterImageResolver images,
  double toolbarHeight = 0,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 800,
      height: 600,
      child: Column(
        children: [
          if (toolbarHeight > 0) SizedBox(height: toolbarHeight),
          Expanded(
            child: PlanCanvasBody(
              scene: scene,
              viewport: viewport,
              measurer: const _ZeroMeasurer(),
              images: images,
            ),
          ),
        ],
      ),
    ),
  ),
);

RenderPlanCanvas _renderObject(WidgetTester tester) =>
    tester.renderObject<RenderPlanCanvas>(find.byType(PlanCanvasBody));

void main() {
  // REQUIRED, AND ITS ABSENCE HANGS RATHER THAN FAILS. `_png` records a
  // `ui.Picture` and calls `toImage`, and `PlanImageCache.load` calls
  // `ui.instantiateImageCodec`; both need the engine binding. `testWidgets`
  // installs it, a bare `test` does not, and the cache group below is
  // deliberately bare `test`s because none of them builds a widget. Without
  // this line the whole file sits there producing no output at all, which
  // reads exactly like a slow suite.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('planSceneToScreen', () {
    test('carries the paint offset a non-boundary would get, on BOTH axes, '
        'and does not scale it by the zoom', () {
      // THE ONLY PLACE THIS COMPOSITION IS OBSERVABLE. See the file
      // header: at run time the offset is always zero, so this is driven
      // with the offset a non-repaint-boundary would receive.
      //
      // The offset is a SCREEN-space translation applied AFTER the
      // viewport's scene->screen map, so it pre-multiplies. Reversing the
      // two would multiply the widget's own position by the zoom, which is
      // the sibling of the pan-accelerates-with-zoom bug.
      final viewport = Matrix4.identity()
        ..setEntry(0, 0, 2)
        ..setEntry(1, 1, 2)
        ..setEntry(0, 3, 7)
        ..setEntry(1, 3, 11);
      final m = planSceneToScreen(const Offset(37, 64), viewport);
      final v = m.storage;
      expect(v[0], 2); // zoom survives
      expect(v[5], 2);
      // The viewport's own translation PLUS the widget's position, not the
      // widget's position multiplied by 2.
      expect(v[12], 7 + 37);
      expect(v[13], 11 + 64);
    });
  });

  group('the render object', () {
    late PlanImageCache cache;

    setUp(() => cache = PlanImageCache());
    tearDown(() => cache.dispose());

    testWidgets('replays the scene through the resolver it was given', (
      tester,
    ) async {
      // THE RESOLVER IS WIRED, ASSERTED BY THE ABSENCE OF A THROW. An
      // `OpImage` the canvas cannot resolve raises `MissingImageError`
      // during paint, so a render object that dropped `images` on the way
      // to `FlutterDiagramCanvas` fails here rather than drawing a blank.
      await _loadInto(tester, cache, 'underlays/ul-1.png', 400, 300);
      final built = buildPlanScene(underlay: _underlay(), pins: const []);

      await tester.pumpWidget(
        _host(
          scene: built.scene,
          viewport: ViewportController(),
          images: cache.resolver,
          toolbarHeight: 60,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(_renderObject(tester).debugSceneRecordings, greaterThan(0));
    });

    testWidgets('the viewport reaches the matrix the paint actually used', (
      tester,
    ) async {
      // WHAT A WIDGET TEST CAN SEE. Not the widget's own position (always
      // zero here, see the header), but the viewport transform, which is
      // the half that moves when a person pans.
      await _loadInto(tester, cache, 'underlays/ul-1.png', 400, 300);
      final viewport = ViewportController();
      final built = buildPlanScene(underlay: _underlay(), pins: const []);
      await tester.pumpWidget(
        _host(
          scene: built.scene,
          viewport: viewport,
          images: cache.resolver,
          toolbarHeight: 60,
        ),
      );

      viewport.panBy(const Offset(18, 25));
      await tester.pump();

      final m = _renderObject(tester).debugSceneToScreen!;
      // ASYMMETRIC ON PURPOSE: 18 and 25 rather than one value twice, so a
      // transposed pair cannot pass.
      expect(m.storage[12], 18);
      expect(m.storage[13], 25);
    });

    testWidgets('a pan repaints it', (tester) async {
      await _loadInto(tester, cache, 'underlays/ul-1.png', 400, 300);
      final viewport = ViewportController();
      final built = buildPlanScene(underlay: _underlay(), pins: const []);
      await tester.pumpWidget(
        _host(scene: built.scene, viewport: viewport, images: cache.resolver),
      );
      final before = _renderObject(tester).debugSceneRecordings;

      viewport.panBy(const Offset(10, 10));
      await tester.pump();

      expect(_renderObject(tester).debugSceneRecordings, greaterThan(before));
    });

    // NO WIDGET-LEVEL CASE FOR AN UNRESOLVABLE UNDERLAY, DELIBERATELY.
    //
    // docs/15 §7 requires a reference nothing resolves to THROW rather
    // than draw nothing, "because a T1.01 that is a title block over white
    // paper is indistinguishable from a plan with no drops on it". That
    // contract belongs to `FlutterDiagramCanvas.drawImage` and is tested
    // where it lives, in `draw/flutter_canvas_image_test.dart`, alongside
    // the PDF backend's twin in `rackpal_export`.
    //
    // Asserting it HERE was tried and is worse than useless: a throw
    // during `paint()` leaves the layer tree mid-recording, so a second
    // exception follows from `layer.dart`'s `picture != null` assertion
    // and `tester.takeException()` returns "Multiple exceptions (2)"
    // rather than the error. The test then fails while the behaviour is
    // correct, which is the shape that teaches somebody to delete the
    // check rather than the test.
  });

  group('PlanImageCache', () {
    test('resolves a loaded member and nothing else', () async {
      final cache = PlanImageCache();
      addTearDown(cache.dispose);
      await cache.load('underlays/a.png', await _png(8, 8));

      ImageRef ref(String member) => ImageRef(
        member: member,
        format: ImageFormat.png,
        pixelWidth: 8,
        pixelHeight: 8,
      );

      expect(cache.resolver(ref('underlays/a.png')), isNotNull);
      // NULL, NOT A THROW. Null is "not loaded", and the canvas is what
      // turns that into a `MissingImageError`; throwing here would take
      // the decision away from the layer that owns it.
      expect(cache.resolver(ref('underlays/b.png')), isNull);
    });

    test(
      'loading the same member twice decodes once and leaks nothing',
      () async {
        final cache = PlanImageCache();
        addTearDown(cache.dispose);
        final bytes = await _png(8, 8);
        final first = await cache.load('underlays/a.png', bytes);
        final second = await cache.load('underlays/a.png', bytes);

        // IDENTICAL, not merely equal: a second decode would produce a
        // second native handle and silently drop the first, which is a leak
        // no test can see except by this identity.
        expect(identical(first, second), isTrue);
        expect(cache.length, 1);
      },
    );

    test('two concurrent loads of one member settle on one image', () async {
      // The re-check after the await exists for this: both calls pass the
      // "already held?" test before either finishes decoding.
      final cache = PlanImageCache();
      addTearDown(cache.dispose);
      final bytes = await _png(8, 8);
      final results = await Future.wait([
        cache.load('underlays/a.png', bytes),
        cache.load('underlays/a.png', bytes),
      ]);
      expect(identical(results[0], results[1]), isTrue);
      expect(cache.length, 1);
    });

    test('evict drops one member and keeps the rest', () async {
      final cache = PlanImageCache();
      addTearDown(cache.dispose);
      await cache.load('underlays/a.png', await _png(8, 8));
      await cache.load('underlays/b.png', await _png(8, 8));
      cache.evict('underlays/a.png');
      expect(cache.contains('underlays/a.png'), isFalse);
      expect(cache.contains('underlays/b.png'), isTrue);
    });

    test('loading after dispose is refused, not silently ignored', () async {
      final cache = PlanImageCache()..dispose();
      await expectLater(
        cache.load('underlays/a.png', await _png(8, 8)),
        throwsStateError,
      );
    });
  });
}
