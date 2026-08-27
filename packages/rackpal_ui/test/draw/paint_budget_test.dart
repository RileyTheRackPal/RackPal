@Tags(['perf'])
library;

// M2-G — the PAINT half of M2's budget, measured and recorded.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS BESIDE `schematic_perf_test.dart`
// ═══════════════════════════════════════════════════════════════════════
// M2's exit criterion asks the schematic to "route a 300-connection
// fixture within one frame at commit, with the label-layer commit cost
// measured and recorded". `rackpal_core`'s `schematic_perf_test.dart`
// measures the SCENE BUILD — the document projected onto the graph, phases
// 0-3, the display list emitted — and it is a pure-Dart package, so it
// cannot measure a `ui.Canvas`.
//
// A commit that builds a display list in 3 ms and then takes 40 ms to
// paint it has not met "within one frame". This is that second half.
//
// ═══════════════════════════════════════════════════════════════════════
// THE CAVEAT, STATED RATHER THAN BURIED
// ═══════════════════════════════════════════════════════════════════════
// `flutter test` does not register the shipped Jost with the engine, so
// `TextPainter.layout()` here lays out through the test font. The ABSOLUTE
// milliseconds are therefore not the ones a shipped build pays.
//
// THE RATIO IS. Cached and uncached runs lay out the same strings through
// the same code path with the same font, so "how much of the paint is
// repeated text layout" is answered honestly by this file even though "how
// many milliseconds is a paint" is not. The absolute figure is printed
// anyway, labelled, because a number that is directionally right and
// honestly captioned is worth more than no number at all — and the day the
// harness registers the real font it becomes the right number without this
// file changing.
//
// IT READS `rackpal_core`'s TEST FIXTURE ACROSS A PACKAGE BOUNDARY, which
// is a coupling and is deliberate: `schematic_fixture.dart`'s own header
// argues that "a budget measured against a graph invented inside the test
// that measures it is a budget measured against nothing", and a second
// 300-link document built here to avoid the path would be exactly that.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// One frame at 60 Hz — the criterion's own unit, not a tuned threshold.
const double _oneFrameMs = 1000 / 60;

/// `rackpal_core`'s committed 300-link golden, reached across the package
/// boundary. See the file header for why it is not rebuilt here.
const String _fixturePath =
    '../rackpal_core/test/fixtures/e_three_hundred_links.rmpj.json';

void main() {
  late PdfFontMeasurer measurer;
  late SchematicScene scene;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), <FontRef, Uint8List>{
      const FontRef('Jost'): font,
    });

    final bytes = File(_fixturePath).readAsBytesSync();
    final read = const JsonDocumentCodec().read(bytes);
    if (read is! Ok<RackDocument>) {
      throw StateError('$_fixturePath did not decode: $read');
    }
    scene = buildSchematicScene(doc: read.value, measurer: measurer);
  });

  /// Replays the whole display list once, returning the elapsed microseconds.
  int replay(TextRunCache? cache) {
    final recorder = ui.PictureRecorder();
    final canvas = FlutterDiagramCanvas(
      ui.Canvas(recorder),
      measurer: measurer,
      runs: cache,
    );
    final watch = Stopwatch()..start();
    for (final op in scene.scene.ops) {
      op.replay(canvas);
    }
    watch.stop();
    recorder.endRecording().dispose();
    return watch.elapsedMicroseconds;
  }

  int bestOf(int n, TextRunCache? cache) {
    var best = 1 << 30;
    for (var i = 0; i < n; i++) {
      final us = replay(cache);
      if (us < best) best = us;
    }
    return best;
  }

  test('the fixture is the one the budget is defined against', () {
    // A budget met by a smaller sheet is not met — `schematic_perf_test`'s
    // own rule, restated here because this file reads the same golden
    // through a different path and a moved file must fail loudly.
    expect(scene.symbols.length, greaterThan(80));
    expect(
      scene.scene.ops.whereType<OpText>().length,
      greaterThan(2000),
      reason:
          'the census counted 2374 runs; a fixture that lost its text '
          'would measure a paint that is not the one under budget',
    );
  });

  test('replaying the 300-link display list, with and without the cache', () {
    // WARM-UP: the first replay pays JIT for the whole canvas path, which
    // is not what a pan costs in a running editor.
    for (var i = 0; i < 3; i++) {
      replay(null);
    }

    final coldUs = bestOf(10, null);

    // THE STEADY STATE IS THE PAN, and a pan re-records the picture over a
    // cache that is already warm. So the cache is filled first and then
    // measured — measuring a cold cache would measure the first frame
    // after an edit, which is the case the cache helps least and is not
    // the one the budget is about.
    final cache = TextRunCache();
    final firstCachedUs = replay(cache);
    final warmUs = bestOf(10, cache);

    final texts = scene.scene.ops.whereType<OpText>().length;
    final saved = coldUs - warmUs;
    final pct = coldUs == 0 ? 0 : (saved * 100 / coldUs).round();

    // `print`, not `printOnFailure`: `schematic_perf_test.dart`'s rule —
    // a number that only appears when the test fails is recorded nowhere.
    // ignore: avoid_print
    print(
      'M2-G paint path [300-link fixture, TEST FONT — see file header]:\n'
      '  ops                ${scene.scene.ops.length} '
      '($texts text runs, ${cache.length} distinct)\n'
      '  uncached replay    best of 10 = ${coldUs / 1000}ms\n'
      '  cached, first      ${firstCachedUs / 1000}ms  (cold cache: every '
      'run laid out, plus the bookkeeping)\n'
      '  cached, warm       best of 10 = ${warmUs / 1000}ms  '
      '(the pan case)\n'
      '  saved              ${saved / 1000}ms, $pct% of the uncached paint\n'
      '  cache              ${cache.misses} distinct runs held, '
      '${cache.evictions} evictions, ${cache.hits} hits CUMULATIVE across '
      'the 11 cached replays above (capacity $kTextRunCacheCapacity)\n'
      '  frame budget       ${_oneFrameMs}ms',
    );

    // THE ONE THING ASSERTED, and it is the claim rather than the number:
    // the cache must eliminate layouts, and the working set must fit. The
    // milliseconds are RECORDED, not gated, because the caveat above makes
    // an absolute threshold here a promise this harness cannot keep — and
    // a gate that fails for the harness's reasons teaches people to ignore
    // it.
    expect(
      cache.evictions,
      0,
      reason:
          'the densest document v1 admits must not evict — eviction '
          'disposes a native ui.Paragraph inside the paint path',
    );
    expect(
      cache.hits,
      greaterThan(cache.misses),
      reason:
          'a cache that misses more than it hits is not worth the '
          'bookkeeping',
    );
  });
}
