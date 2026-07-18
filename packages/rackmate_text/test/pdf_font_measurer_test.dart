// Smoke test for PdfFontMeasurer (docs/08-pdf-export.md §7.5).
//
// Uses the real bundled IBM Plex Sans Regular TTF -- not a placeholder --
// read via dart:io File (this package is pure Dart, no Flutter
// rootBundle). The path is relative to THIS package's own directory, which
// is what `dart test` (run from packages/rackmate_text) resolves against.

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:test/test.dart';

void main() {
  test(
    'PdfFontMeasurer.measureText returns sane non-zero metrics for a real '
    'bundled font, and caches identical repeats',
    () {
      final bytes = File(
        '../../apps/rackmate/assets/fonts/IBMPlexSans-Regular.ttf',
      ).readAsBytesSync();

      final doc = PdfDocument();
      const font = FontRef('IBM Plex Sans');
      final measurer = PdfFontMeasurer.fromBytes(doc, {font: bytes});

      const style = TextStyleSpec(
        font: font,
        sizePt: 12,
        argb: 0xFF000000,
        anchor: TextAnchor.baselineLeft,
      );

      final m = measurer.measureText('AV Wa To Ty', style);

      // Sanity, not exact-value assertions: real glyph metrics vary by
      // font build, but every field must be a real, positive quantity.
      expect(m.advanceWidth, greaterThan(0));
      expect(m.ascent, greaterThan(0));
      // CONFIRMED descent is negative unscaled in the raw PdfFontMetrics --
      // measureText() must have taken .abs() so this comes out positive.
      expect(m.descent, greaterThan(0));
      expect(m.capHeight, greaterThan(0));
      expect(m.xHeight, greaterThan(0));
      expect(m.lineHeight, greaterThan(0));
      expect(m.height, closeTo(m.ascent + m.descent, 1e-9));

      // Same run + style must be served from the cache as the identical
      // TextMetrics instance (the 4-tuple cache key, not the TextAnchor,
      // is what's keyed on -- a different anchor must still hit the same
      // cache entry).
      const differentAnchor = TextStyleSpec(
        font: font,
        sizePt: 12,
        argb: 0xFF000000,
        anchor: TextAnchor.topRight,
      );
      final m2 = measurer.measureText('AV Wa To Ty', differentAnchor);
      expect(identical(m, m2), isTrue);

      // A different size must NOT hit the same cache entry.
      const biggerStyle = TextStyleSpec(
        font: font,
        sizePt: 24,
        argb: 0xFF000000,
        anchor: TextAnchor.baselineLeft,
      );
      final m3 = measurer.measureText('AV Wa To Ty', biggerStyle);
      expect(m3.advanceWidth, greaterThan(m.advanceWidth));
    },
  );
}
