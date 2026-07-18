// Tests for the grid picture cache and the painter's LOD / repaint policy.
// These build a real ui.Canvas but need no widget binding.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Color, Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

const _style = GridStyle(
  minorColor: Color(0x22000000),
  majorColor: Color(0x66000000),
);

void main() {
  group('GridCache', () {
    test('reuses the picture for an equal key and rebakes for a new one', () {
      final cache = GridCache();
      addTearDown(cache.dispose);

      var bakes = 0;
      ui.Picture obtain(String key) => cache.obtain(
            key,
            const ui.Rect.fromLTRB(0, 0, 10, 10),
            (_) => bakes++,
          );

      final a = obtain('k1');
      final b = obtain('k1');
      expect(identical(a, b), isTrue);
      expect(bakes, 1);

      obtain('k2');
      expect(bakes, 2);
    });
  });

  group('GridPainter', () {
    test('paints without throwing across the whole zoom range', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final cache = GridCache();
      addTearDown(cache.dispose);
      final painter = GridPainter(viewport: vp, cache: cache, style: _style);

      for (final s in <double>[0.05, 0.5, 1, 8, 32]) {
        vp
          ..reset()
          ..zoomBy(s, screenPivot: Offset.zero);
        final recorder = ui.PictureRecorder();
        painter.paint(ui.Canvas(recorder), const Size(800, 600));
        recorder.endRecording().dispose();
      }
    });

    test(
      'shouldRepaint reacts to a style change but not to identical config',
      () {
        final vp = ViewportController();
        addTearDown(vp.dispose);
        final cache = GridCache();
        addTearDown(cache.dispose);

        final base = GridPainter(viewport: vp, cache: cache, style: _style);
        final same = GridPainter(viewport: vp, cache: cache, style: _style);
        final restyled = GridPainter(
          viewport: vp,
          cache: cache,
          style: const GridStyle(
            minorColor: Color(0x11111111),
            majorColor: Color(0x99999999),
          ),
        );

        expect(base.shouldRepaint(same), isFalse);
        expect(base.shouldRepaint(restyled), isTrue);
      },
    );
  });
}
