// rackpal_core/src/draw/sheet/text_fit.dart — pure Dart.
//
// The three string helpers every piece of sheet furniture needs: measured
// truncation, optional-fragment joining, and THE date format. Shared so the
// title block and the revision block cannot format a date two ways on one
// sheet.
//
// Measured truncation for fixed-width sheet cells (docs/08 §3.7's
// "hard-truncate with a measured ellipsis using the shared `TextMeasurer`
// rather than trusting the widget").
//
// WHY THIS IS NOT OPTIONAL. Every string on a sheet — a model number, a
// file name, a revision description — arrives from user data and can be
// arbitrarily long. `PdfGraphics.drawString` is single-line and does not
// clip, so an unmeasured string does not wrap or ellipsise: it runs
// straight out of its cell, across the next column and off the sheet. The
// only defence is to measure through the ONE injected `TextMeasurer`
// (CR-081), which is also what makes the on-screen preview and the print
// break at the same character.

import 'package:rackpal_core/src/draw/text.dart';

/// The single-character ellipsis used for measured truncation. One glyph
/// rather than three dots so the measurement is stable and the cell does
/// not lose three characters' worth of content to the marker.
const String kEllipsis = '…';

/// [text], truncated with a measured [kEllipsis] so its advance width fits
/// [maxWidth] under [style].
///
/// Returns [text] unchanged when it already fits, and an empty string when
/// not even the ellipsis fits (a caller emitting that would produce an
/// empty text op, which `title_block_test.dart` forbids — so callers check
/// for empty rather than drawing it).
///
/// Linear from the end rather than a binary search: sheet cells hold tens
/// of characters, not thousands, and the measurer caches every result, so
/// the simple loop is both faster in practice and obviously correct.
String fitTextToWidth(
  String text,
  double maxWidth, {
  required TextStyleSpec style,
  required TextMeasurer measurer,
}) {
  if (text.isEmpty) return text;
  if (measurer.measureText(text, style).advanceWidth <= maxWidth) return text;

  final ellipsisWidth = measurer.measureText(kEllipsis, style).advanceWidth;
  if (ellipsisWidth > maxWidth) return '';

  // Trim by code UNITS is wrong for surrogate pairs; trim by runes.
  final runes = text.runes.toList();
  for (var take = runes.length - 1; take > 0; take--) {
    final candidate = String.fromCharCodes(runes.take(take));
    final width = measurer.measureText(candidate, style).advanceWidth;
    if (width + ellipsisWidth <= maxWidth) return '$candidate$kEllipsis';
  }
  return kEllipsis;
}

/// Joins the non-null, non-blank parts of [parts] with [separator].
///
/// This is how §5.2's "empty optional lines collapse rather than printing a
/// blank" is implemented at the level of ONE line: a title block line made
/// of three optional fragments prints only the fragments that exist, with
/// no doubled separators. Returns `null` when nothing survives, so the
/// caller drops the whole line rather than emitting an empty text op.
String? joinNonEmpty(Iterable<String?> parts, {String separator = ' · '}) {
  final kept = <String>[
    for (final part in parts)
      if (part != null && part.trim().isNotEmpty) part.trim(),
  ];
  return kept.isEmpty ? null : kept.join(separator);
}

/// The em dash a title-block or schedule cell prints for a value that does
/// not exist.
///
/// It is NOT a zero and NOT an empty cell: an empty cell reads as "nobody
/// filled this in" and a zero reads as a measurement. `—` reads as "there
/// is no value here", which is what a null actually means (G4, and
/// `derived/totals.dart`'s "0 means measured, null means we do not know").
const String kEmDash = '—';

/// The ONE date format on a sheet: ISO-8601 calendar date, `yyyy-MM-dd`.
///
/// Unambiguous across locales, sorts lexicographically, and matches §5.2's
/// own worked example (`DATE 2026-07-18`). Formats the [DateTime] exactly
/// as handed in — no timezone conversion — because the export path INJECTS
/// its one clock value (§8.4) and a silent `toLocal()` here would make an
/// injected instant render differently on two machines.
String formatSheetDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
