// rackmate_core/src/draw/text.dart — pure Dart, THE declaration site for
// TextMeasurer/TextMetrics/TextStyleSpec/TextAnchor/anchorOffset
// (docs/08-pdf-export.md §7.5, CR-081). There is no draw/text_measurer.dart.
//
// A NOTE ON THE NAME `DPt` USED BELOW, because this is exactly the kind of
// thing a future contributor gets wrong by pattern-matching on the wrong
// "Pt": docs/08-pdf-export.md §7.5's quoted `anchorOffset` signature reads
// `Pt anchorOffset(TextAnchor a, TextMetrics m)`. That `Pt` is NOT
// `units/pt.dart`'s `Pt{gx, gy}` — the model's integer schematic-grid
// point. It is the `DiagramCanvas` boundary's double-precision diagram
// point (1 unit = 1 PDF point, CR-007), defined once in `geometry.dart` as
// `DPt` specifically so it cannot be confused with the model's `Pt`. Every
// file under draw/ uses `DPt` for this concept; never import the model's
// `Pt` here.

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/draw/geometry.dart';

/// A bundled font family + weight, identified minimally.
///
/// SCOPE NOTE: only Jost **Regular** is bundled as of this stage
/// (`apps/rackmate/assets/fonts/Jost-Regular.ttf`) — Bold,
/// Condensed, Mono and Noto Sans Symbols are a later stage's job per the
/// architecture doc's font table. `bold` exists so callers can express
/// intent now without a breaking change later, but nothing currently
/// resolves it to a different TTF.
///
/// Deliberately `bool bold` rather than a `FontWeight`-style enum: an enum
/// literally named `FontWeight` would collide with `dart:ui`/Material's
/// own `FontWeight` in every file that has to import both (`rackmate_ui`
/// always does), which is precisely the kind of avoidable name clash this
/// project's naming discipline exists to prevent.
@immutable
final class FontRef {
  const FontRef(this.family, {this.bold = false});

  final String family;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      other is FontRef && other.family == family && other.bold == bold;

  @override
  int get hashCode => Object.hash(family, bold);

  @override
  String toString() => 'FontRef($family${bold ? ', bold' : ''})';
}

/// Where a piece of text anchors relative to the point passed to
/// `DiagramCanvas.drawText`/`OpText` — 12-way, including the `baseline*`
/// variants that anchor to the text's own baseline rather than to its
/// ascent/descent box (docs/08-pdf-export.md §7.5).
enum TextAnchor {
  topLeft,
  topCenter,
  topRight,
  midLeft,
  midCenter,
  midRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  baselineLeft,
  baselineCenter,
  baselineRight,
}

/// Everything needed to lay out and paint one run of text, identically on
/// every `DiagramCanvas` backend.
@immutable
final class TextStyleSpec {
  const TextStyleSpec({
    required this.font,
    required this.sizePt,
    required this.argb,
    required this.anchor,
    this.letterSpacing = 0.0,
    this.rotationRad = 0.0,
  });

  final FontRef font;
  final double sizePt;
  final double letterSpacing;

  /// Packed 0xAARRGGBB text colour.
  final int argb;

  /// Positive = clockwise, matching `DiagramCanvas.rotate` (§7.3).
  final double rotationRad;
  final TextAnchor anchor;

  @override
  bool operator ==(Object other) =>
      other is TextStyleSpec &&
      other.font == font &&
      other.sizePt == sizePt &&
      other.letterSpacing == letterSpacing &&
      other.argb == argb &&
      other.rotationRad == rotationRad &&
      other.anchor == anchor;

  @override
  int get hashCode =>
      Object.hash(font, sizePt, letterSpacing, argb, rotationRad, anchor);

  @override
  String toString() =>
      'TextStyleSpec(font: $font, sizePt: $sizePt, '
      'letterSpacing: $letterSpacing, argb: 0x${argb.toRadixString(16)}, '
      'rotationRad: $rotationRad, anchor: $anchor)';
}

/// Measured metrics for one run of text under one [TextStyleSpec], all in
/// diagram units (points). Transcribed verbatim from
/// docs/08-pdf-export.md §7.5.
@immutable
final class TextMetrics {
  const TextMetrics({
    required this.advanceWidth,
    required this.ascent,
    required this.descent,
    required this.capHeight,
    required this.xHeight,
    required this.lineHeight,
  });

  final double advanceWidth;
  final double ascent;
  final double descent;
  final double capHeight;
  final double xHeight;
  final double lineHeight;

  double get height => ascent + descent;
}

/// The single measurement seam that makes screen/print parity possible
/// (CR-081). `rackmate_core` declares only this interface; the one
/// concrete implementation (`PdfFontMeasurer`, backed by
/// `PdfFont.stringMetrics`) lives in `rackmate_text` and is injected into
/// the scene builder and into *every* `DiagramCanvas` backend, including
/// the Flutter one — see docs/08-pdf-export.md §7.5.
// Deliberately an interface, not a top-level function: this is a
// dependency-injection seam with exactly one intended concrete
// implementation swapped in per context (`PdfFontMeasurer` in
// `rackmate_text`), matching docs/08-pdf-export.md §7.5's verbatim
// `abstract interface class TextMeasurer` declaration.
// ignore: one_member_abstracts
abstract interface class TextMeasurer {
  TextMetrics measureText(String text, TextStyleSpec style);
}

/// Resolves a [TextAnchor] to the offset from the anchor point to where a
/// backend should place the text run's origin, i.e. the offset TO THE
/// BASELINE. Used verbatim by both `PdfDiagramCanvas` and
/// `FlutterDiagramCanvas` (docs/08-pdf-export.md §7.5) so neither adapter
/// ever guesses a baseline independently.
DPt anchorOffset(TextAnchor a, TextMetrics m) {
  final w = m.advanceWidth;
  final dx = switch (a) {
    TextAnchor.topLeft ||
    TextAnchor.midLeft ||
    TextAnchor.bottomLeft ||
    TextAnchor.baselineLeft => 0.0,
    TextAnchor.topCenter ||
    TextAnchor.midCenter ||
    TextAnchor.bottomCenter ||
    TextAnchor.baselineCenter => -w / 2,
    _ => -w,
  };
  final dy = switch (a) {
    // offset to the BASELINE
    TextAnchor.topLeft ||
    TextAnchor.topCenter ||
    TextAnchor.topRight => m.ascent,
    TextAnchor.midLeft ||
    TextAnchor.midCenter ||
    TextAnchor.midRight => m.ascent - m.height / 2,
    TextAnchor.bottomLeft ||
    TextAnchor.bottomCenter ||
    TextAnchor.bottomRight => -m.descent,
    _ => 0.0, // baseline* variants
  };
  return DPt(dx, dy);
}
