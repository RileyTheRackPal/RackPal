// ONE ENTRY IN A SHOP'S CABLE-COLOUR CONVENTION.
//
// ==================================================================
// WHY THIS IS A NAMED ENTRY AND NOT A BARE `Rgb` ON `Link`
// ==================================================================
// A jacket colour recorded as a colour ALONE stops being information the
// moment the sheet is printed the way field copies are printed.
// `ExportSpec.palette` ships `colour | greyscale | cmyk` and the
// Installer preset defaults to GREYSCALE (docs/05 §6.3, PAL-3), so seven
// swatches become seven indistinguishable greys — and they were already
// indistinguishable for the ~8 % of installers with a colour-vision
// deficiency that docs/05 §6.1 names by number. [abbr] and [meaning]
// survive greyscale, a photocopy and a CVD; a hex triple does not. That
// is PAL-1's reasoning applied to a different fact.
//
// The other three reasons, briefly: one edit here re-colours a whole job
// when a GC mandates a different palette; a shared DEFINITION is the only
// thing that can make a keystone colour and a cable colour provably the
// same fact rather than two values that can silently disagree; and a
// contractor's imported pull list has a "Colour" column reading `BLU` or
// `Blue` — words, which map to an entry, never hex, which has nowhere to
// land.
//
// ==================================================================
// THE COST, STATED
// ==================================================================
// A one-off — a purple cable because that is what was on the truck —
// cannot be recorded as a bare colour. It needs one new convention
// entry. That is one gesture, and it buys a legend that is correct
// rather than a swatch that is silently meaningless.
import 'package:rackpal_core/src/units/rgb.dart';

/// One colour in the shop's convention: what it looks like, what it is
/// called, and — when the user has said — what it MEANS.
///
/// Immutable with `const` fields, matching `RuleOverride`: an edit
/// replaces the whole map value, which is the simplest possible undo
/// unit. No `operator==`, consistent with every other def in the model.
final class JacketColorDef {
  const JacketColorDef({
    required this.displayName,
    required this.abbr,
    required this.color,
    this.meaning = '',
  });

  /// "Blue".
  final String displayName;

  /// "BLU" — a three-character code, because the Pull Sheet's 510 pt is
  /// already allocated across ten columns (docs/08 §3.2) and jacket
  /// colour is an OPTIONAL column that has to steal width from one of
  /// them. Not derivable by truncating [displayName]: `Grey` -> `GRY`.
  final String abbr;

  /// The swatch. An authored print-ink approximation of a real jacket,
  /// never a hue the renderer draws a wire in — see
  /// `jacket_colour_is_not_hue_test.dart`.
  final Rgb color;

  /// "Control — touchpanel / IR / RS-232".
  ///
  /// EMPTY MEANS THE USER HAS NOT SAID, and is never guessed (G4). A
  /// consumer showing an entry with no meaning shows the name alone; it
  /// does not invent one from the colour.
  final String meaning;
}
