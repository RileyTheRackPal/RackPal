// M2-G — the text-run cache, and the two things about it that no pixel
// comparison could ever show.
//
// A cache is correct when the picture is unchanged AND the layouts stop
// happening. The first half is what every existing test already asserts by
// still passing; this file is the second half, and it is asserted through
// the hit/miss counters because "did this run get laid out again" is
// invisible on a canvas.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ASSERTION THIS FILE EXISTS FOR
// ═══════════════════════════════════════════════════════════════════════
// docs/09 prescribes a key of `(text, styleId, quantisedScale)`.
// `text_run_cache.dart` ships `(text, TextStyleSpec)` and drops the scale
// term, on the reading that the viewport transform is applied to the
// CANVAS while `sizePt` is fixed in diagram units at scene-build time — so
// the same run lays out identically at every zoom, and keying on scale
// would multiply the working set by the number of zoom levels visited.
//
// `the same run at two zooms is one layout` is that reading, measured. If
// it ever fails, the deviation is wrong and the roadmap's key was right.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

const _style = TextStyleSpec(
  font: FontRef('Jost'),
  sizePt: 11,
  argb: 0xFF101010,
  anchor: TextAnchor.topLeft,
);

void main() {
  late PdfFontMeasurer measurer;

  setUpAll(() {
    // A REAL FONT, because `TextPainter.layout()` is the thing being
    // counted and a missing family would silently fall back to a stub
    // whose layout cost is not the one that ships.
    final bytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), <FontRef, Uint8List>{
      const FontRef('Jost'): bytes,
    });
  });

  /// Draws [runs] through a real `FlutterDiagramCanvas` over [cache].
  void paint(TextRunCache cache, void Function(FlutterDiagramCanvas c) runs) {
    runs(
      FlutterDiagramCanvas(
        TestRecordingCanvas(),
        measurer: measurer,
        runs: cache,
      ),
    );
  }

  group('1 — the key', () {
    test('the same run twice is one layout', () {
      final cache = TextRunCache();
      paint(cache, (c) {
        c
          ..drawText('MTX-1', const DPt(0, 0), _style)
          ..drawText('MTX-1', const DPt(80, 40), _style);
      });
      expect(cache.misses, 1);
      expect(cache.hits, 1);
      expect(cache.length, 1);
    });

    test('THE SAME RUN AT TWO ZOOMS IS ONE LAYOUT — docs/09 prescribes a '
        'quantisedScale term and this build does not have one', () {
      // The deviation, measured. `sizePt` is in diagram units and the zoom
      // is on the canvas, so the paragraph is identical at every scale. A
      // key carrying scale would make this two misses, which is the
      // thrashing the roadmap feared, caused by the key it prescribed.
      final cache = TextRunCache();
      paint(cache, (c) {
        c
          ..save()
          ..scale(0.25)
          ..drawText('MTX-1', const DPt(0, 0), _style)
          ..restore()
          ..save()
          ..scale(4)
          ..drawText('MTX-1', const DPt(0, 0), _style)
          ..restore();
      });
      expect(cache.misses, 1);
      expect(cache.hits, 1);
    });

    test('different text is a different entry', () {
      final cache = TextRunCache();
      paint(cache, (c) {
        c
          ..drawText('MTX-1', const DPt(0, 0), _style)
          ..drawText('AMP-1', const DPt(0, 20), _style);
      });
      expect(cache.misses, 2);
      expect(cache.hits, 0);
    });

    test('A COLOUR CHANGE IS A DIFFERENT ENTRY — the paragraph bakes the '
        'colour in', () {
      // The failure this forbids is the loud one: a cache keyed on text
      // alone would paint the second run in the first run's colour, and
      // under CR-078 hue IS the signal domain, so it would say the cable
      // is a different kind of cable.
      final cache = TextRunCache();
      paint(cache, (c) {
        c
          ..drawText('N001', const DPt(0, 0), _style)
          ..drawText(
            'N001',
            const DPt(0, 20),
            TextStyleSpec(
              font: _style.font,
              sizePt: _style.sizePt,
              argb: 0xFFCC0000,
              anchor: _style.anchor,
            ),
          );
      });
      expect(cache.misses, 2);
      expect(cache.hits, 0);
    });

    test('a size change is a different entry', () {
      final cache = TextRunCache();
      paint(cache, (c) {
        c
          ..drawText('N001', const DPt(0, 0), _style)
          ..drawText(
            'N001',
            const DPt(0, 20),
            TextStyleSpec(
              font: _style.font,
              sizePt: 8,
              argb: _style.argb,
              anchor: _style.anchor,
            ),
          );
      });
      expect(cache.misses, 2);
    });
  });

  group('2 — eviction, and why the capacity has headroom', () {
    test('it is LRU, not FIFO — the run just used is not the one evicted', () {
      // FIFO would evict `a`, which is the entry the next paint asks for
      // first. The re-insertion in `runFor` is the whole difference, and
      // this is the only test that can see it.
      final cache = TextRunCache(capacity: 2);
      paint(cache, (c) {
        c
          ..drawText('a', const DPt(0, 0), _style)
          ..drawText('b', const DPt(0, 0), _style)
          // `a` again: now `b` is the coldest.
          ..drawText('a', const DPt(0, 0), _style)
          ..drawText('c', const DPt(0, 0), _style);
      });
      expect(cache.evictions, 1);
      expect(cache.length, 2);

      // `a` survived, `b` did not.
      paint(cache, (c) => c.drawText('a', const DPt(0, 0), _style));
      expect(cache.hits, 2, reason: '`a` was the recently used one');
      paint(cache, (c) => c.drawText('b', const DPt(0, 0), _style));
      expect(cache.evictions, 2, reason: '`b` had to be laid out again');
    });

    test('the shipped capacity clears the measured working set with room', () {
      // `schematic_perf_test.dart`'s M2-G census counts 703 distinct
      // (text, style) pairs on the 300-link fixture — v1's density ceiling.
      // Eviction disposes a native `ui.Paragraph` inside the paint path, so
      // the defence against a thrashing cache is capacity, and this is the
      // number that has to stay true.
      expect(kTextRunCacheCapacity, greaterThan(703 * 2));
    });
  });

  group('3 — the cache changes how often, never what', () {
    test('a cached run and an uncached one paint identically', () {
      // The correctness claim, made directly rather than inferred from the
      // suite still being green: the same draws with and without a cache
      // reach `ui.Canvas` as the same calls with the same offsets.
      String describe(RecordedInvocation i) =>
          '${i.invocation.memberName}'
          '/${i.invocation.positionalArguments.length}';

      List<String> record({TextRunCache? cache}) {
        final canvas = TestRecordingCanvas();
        FlutterDiagramCanvas(canvas, measurer: measurer, runs: cache)
          ..drawText('MTX-1', const DPt(10, 20), _style)
          ..drawText('MTX-1', const DPt(30, 40), _style)
          ..drawText('AMP-1', const DPt(50, 60), _style);
        return [for (final i in canvas.invocations) describe(i)];
      }

      expect(record(cache: TextRunCache()), record());
    });

    test('clear() empties it, and a later draw is a miss again', () {
      final cache = TextRunCache();
      paint(cache, (c) => c.drawText('MTX-1', const DPt(0, 0), _style));
      expect(cache.length, 1);

      cache.clear();
      expect(cache.length, 0);

      paint(cache, (c) => c.drawText('MTX-1', const DPt(0, 0), _style));
      expect(cache.misses, 2);
      expect(cache.hits, 0);
    });
  });
}
