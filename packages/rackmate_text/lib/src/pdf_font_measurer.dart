// rackmate_text/lib/src/pdf_font_measurer.dart -- the ONE concrete
// TextMeasurer (CR-081, docs/08-pdf-export.md §7.5). This package's only
// consumer of `package:pdf` is `PdfTtfFont`/`PdfFontMetrics`, both of which
// live in the LOW-LEVEL API (`package:pdf/pdf.dart`), so that is the only
// import from `pdf` this file needs -- never `package:pdf/widgets.dart`'s
// `pw.Font`, which does not expose `stringMetrics` at all (confirmed by a
// real compile error during this stage's API spike).
//
// VERIFIED API FACTS this file is written against (spiked directly, no
// longer VERIFY: items):
//  - `stringMetrics` is declared on `PdfFont` (and inherited/overridden by
//    `PdfTtfFont`), taking a `String` and returning `PdfFontMetrics`.
//  - `PdfTtfFont` REQUIRES a `PdfDocument` to construct --
//    `PdfTtfFont(doc, byteData)` -- there is no document-free factory,
//    which is why `PdfFontMeasurer.fromBytes` below takes one.
//  - `PdfFontMetrics.{advanceWidth, ascent, descent, leftBearing,
//    rightBearing, maxHeight}` are all EM-RELATIVE (unscaled) doubles --
//    multiply by point size to get real units -- and `descent` is
//    NEGATIVE (below the baseline), so `.abs()` is required to get a
//    positive descent magnitude.
//  - `PdfFontMetrics` supports `operator *(double)` (scales every field),
//    though this file computes scaled fields directly rather than via that
//    operator, matching docs/08-pdf-export.md §7.5's own quoted shape.
//  - `font.ascent` / `font.descent` (on `PdfFont`/`PdfTtfFont` itself, not
//    on the per-string `PdfFontMetrics`) exist and are the same unscaled
//    per-em values.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// The single concrete [TextMeasurer] (docs/08-pdf-export.md §7.5,
/// CR-081), backed by [PdfFont.stringMetrics]. Injected into the scene
/// builder and into *every* `DiagramCanvas` backend -- including the
/// Flutter one -- so on-screen layout and PDF layout can never disagree,
/// which is CR-081's entire point.
final class PdfFontMeasurer implements TextMeasurer {
  PdfFontMeasurer(this._fonts);

  /// Loads [fontBytes] into a [PdfTtfFont] per [FontRef], registered
  /// against [doc], and builds the [PdfFontMeasurer] from the result.
  ///
  /// This is the shape the caller (a later `apps/rackmate` stage) actually
  /// uses: `rackmate_text` is pure Dart with no Flutter `rootBundle`, so it
  /// cannot load font assets itself -- the raw TTF bytes must be read by
  /// the caller (e.g. via `dart:io` or `rootBundle.load()`) and handed in
  /// here already decoded.
  factory PdfFontMeasurer.fromBytes(
    PdfDocument doc,
    Map<FontRef, Uint8List> fontBytes,
  ) {
    final fonts = <FontRef, PdfFont>{
      for (final entry in fontBytes.entries)
        entry.key: PdfTtfFont(doc, ByteData.sublistView(entry.value)),
    };
    return PdfFontMeasurer(fonts);
  }

  final Map<FontRef, PdfFont> _fonts;

  // Key is the 4-tuple EXTRACTED from the spec, never the TextStyleSpec
  // object. TextAnchor is deliberately excluded: it does not affect
  // metrics, and including it would multiply the cache 12x. Do not
  // "simplify" this to key on `style` -- that is the bug §7.5 warns about.
  //
  // §7.5 sizes this cache at 12,000 entries -- "a rack sheet re-measures
  // the same designators hundreds of times", and ~10,000 distinct text
  // runs is the expected working set (200 devices x 20 ports x 2 runs,
  // plus headers/tag pills). Dart's `Map` literal is a `LinkedHashMap`
  // under the hood (insertion-ordered), so `keys.first` below gives cheap
  // FIFO eviction of the OLDEST-INSERTED entry once the cap is hit. That is
  // not a true LRU -- a cache hit does not "refresh" an entry's position,
  // so a hot entry inserted long ago can still be evicted ahead of a cold
  // one inserted recently -- but it is a reasonable simple approximation
  // for M1 per the task brief's own guidance ("a literal Map without
  // eviction is acceptable too"). KNOWN GAP, recorded honestly: swap for a
  // real promote-on-hit LRU before this ships to a real project at the
  // scale where eviction churn would actually show up.
  static const int _cacheCapacity = 12000;
  final _cache = <(String, FontRef, double, double), TextMetrics>{};

  @override
  TextMetrics measureText(String t, TextStyleSpec style) {
    final key = (t, style.font, style.sizePt, style.letterSpacing);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }

    final f = style.font;
    final size = style.sizePt;
    final ls = style.letterSpacing;
    final font = _fonts[f]!;
    final m = font.stringMetrics(t); // CONFIRMED: PdfFont.stringMetrics
    final metrics = TextMetrics(
      advanceWidth: m.advanceWidth * size + ls * math.max(0, t.length - 1),
      ascent: m.ascent.abs() * size,
      // CONFIRMED descent is negative unscaled -- .abs() before scaling.
      descent: m.descent.abs() * size,
      capHeight: font.ascent * size * 0.72,
      xHeight: font.ascent * size * 0.52,
      lineHeight: (font.ascent - font.descent) * size,
    );

    if (_cache.length >= _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = metrics;
    return metrics;
  }
}
