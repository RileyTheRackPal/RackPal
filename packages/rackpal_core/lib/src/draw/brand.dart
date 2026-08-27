// The RackPal wordmark, as fixed outlines. DR-089, AC-058/D9, RJ-017.
// Board #768 / #769.
//
// ═════════════════════════════════════════════════════════════════════
// A PATH, FOR THE REASON `device_glyph_art.dart` IS ALREADY A PATH
// ═════════════════════════════════════════════════════════════════════
// That file's header records what a codepoint cost: Jost carried none
// of the signal glyphs, `PdfFontMeasurer` returned a near-zero advance,
// the screen's `TextPainter` fell back to a system face and drew full
// width, and `NET-NEN006` printed over a net name. Both backends had
// emitted IDENTICAL ops. Only the font behind one of them differed.
//
// A wordmark set as TEXT would reopen exactly that, and a wordmark is
// worse than a glyph: it is the one mark on the sheet whose shape a
// reader is expected to recognise rather than read.
//
// ═════════════════════════════════════════════════════════════════════
// AND A PATH BECAUSE THE LICENCE LEAVES NO OTHER DOOR
// ═════════════════════════════════════════════════════════════════════
// The letterforms are Nasalization, by Raymond Larabie (Typodermic
// Fonts Inc.). Its desktop EULA permits logos as finished materials
// under 2.2, and its definitions section then excludes such artwork
// from `Font Software` outright. What that section GIVES, two others
// take back:
//
//   * 4.3 forbids embedding the FONT SOFTWARE in any application, so no
//     font file may enter this repository, now or later. It does not
//     reach the outlines, which is why this file may exist at all;
//   * 4.5 forbids fixed artwork whose effect is to let a recipient
//     compose new text, and this one DOES reach the artwork.
//
// 4.6, PUBLICLY AVAILABLE SOFTWARE, IS NOT ON THAT LIST AND AN EARLIER
// VERSION OF THIS HEADER PUT IT THERE. It was read as taking back what
// 2.2 gives, which would have made these outlines a problem for the
// GPLv3 release. The definitions section says otherwise, in terms:
//
//     "Font Software does not include fixed artwork lawfully created
//      and distributed under Section 2.2."
//
// 4.6 forbids embedding the Font Software in Publicly Available
// Software. The outlines below are not Font Software, so the open
// question is about the font file, which was never going in. Corrected
// against the EULA shipped with the face (Typodermic Desktop v260817)
// rather than against a summary of it.
//
// 4.5 is why this file holds ONE MERGED PATH PER LOCKUP and not seven
// letters. Seven addressable letterforms is a recombinable character
// sheet whatever the file extension; one path is a logo. The merge is
// not a convenience and must not be undone by a later refactor that
// notices the subpaths and thinks them separable.
//
// Because 4.3 keeps the font out of the tree, THESE OUTLINES ARE THE
// SOURCE, not a build artifact. Regenerating them needs a licensed copy
// of the face; nothing in CI can, and nothing in CI should.
//
// ═════════════════════════════════════════════════════════════════════
// THE ROWS ARE NO LONGER EQUAL, AND THAT IS THE MARK (DR-096 §11.95.4)
// ═════════════════════════════════════════════════════════════════════
// The RackMate lockup stacked two four-letter rows. MATE was 262 units
// wider than RACK by advance and 210 by ink, so RACK carried +70/1000
// em of tracking, solved against INK rather than advances because
// advances carry side bearings and flushing on them measures as flush
// without looking it.
//
// PAL is three letters and 812 units NARROWER than RACK by ink, so the
// same solve runs the other way and needs +406/1000 em, 5.8 times as
// much. Measured, not estimated. At that spacing PAL stops reading as
// a word and reads as three initials, so the structure does not carry
// over and was not made to.
//
// So the rows are no longer flushed to each other. RACK sets the
// measure at its natural width with NO TRACKING AT ALL, the rule
// matches RACK, and PAL sits flush left beneath it. The residual on
// row 2 is not slack: it is where the mascot sits, at
// [kRackPalRileyLeft] / [kRackPalRileyTop].
//
// A CONSEQUENCE FOR ANY CALLER THAT MEASURED THE OLD BOX: the lockup
// is 2788 units wide where it was 2999, and its two rows have
// different widths for the first time.
//
// Every glyph in this face is a SINGLE CONTOUR, because its counters
// are open. No contour nests inside another, so nonzero and even-odd
// fills agree, and the two backends cannot diverge on fill rule. A
// future addition to this file that closes a counter breaks that.

import 'package:rackpal_core/src/draw/path.dart';

/// The lockup's NOMINAL box, in the units the outlines are authored in.
///
/// Nominal means cap line to baseline, so the ink exceeds it vertically
/// by [kRackPalLockupOvershoot] at each end and matches it exactly
/// left and right. That is not a defect to be trimmed: round letters
/// overshoot in every well-made face, and a box drawn tight to the ink
/// would sit the wordmark visibly high against type beside it.
///
/// The cap height is the face's own `OS/2.sCapHeight`. A caller scales
/// by the cap height it wants, never by the box, so the wordmark
/// optically matches type set beside it.
const int kRackPalLockupWidth = 2788;

/// See [kRackPalLockupWidth].
const int kRackPalLockupHeight = 1486;

/// See [kRackPalLockupWidth].
const int kRackPalLockupCapHeight = 675;

/// How far the ink passes the cap line, ABOVE ONLY.
///
/// NO LONGER SYMMETRIC, and the reason is worth keeping because a
/// reader who remembers the old constant will assume it still is.
/// Measured per glyph in the face: only `A` overshoots the cap, by 12,
/// and only `M` ever passed BELOW the baseline, also by 12. RACKMATE
/// contained an M, so its box overshot 12 at each end and the old doc
/// comment saying "symmetric" was true. RACKPAL has no M, so the
/// bottom of the box is exact and only the top overshoots.
///
/// The nominal box therefore holds ink from `-12` to
/// [kRackPalLockupHeight], not from `-12` to `height + 12`.
const int kRackPalLockupOvershoot = 12;

/// Where the rule sits in the ruled lockup, for a caller that needs to
/// align something to it.
const int kRackPalLockupRuleTop = 724;

/// See [kRackPalLockupRuleTop].
const int kRackPalLockupRuleHeight = 38;

/// Below this rendered cap height, use the unruled lockup.
///
/// Measured, not guessed: at a 13 pt cap the rule is under a third of a
/// point and prints as a smudge rather than a line, which reads as a
/// printing defect on a sheet whose whole job is to be trusted.
const int kRackPalLockupMinRuledCapPx = 20;

/// Riley's own box, authored in the same units as the lockup.
///
/// Taller than wide, at 0.806:1, which is the number that decides the
/// app icon: the lockup is 1.876:1 and cannot fill a square slot, so
/// below roughly a 48 px icon the mark IS Riley (see
/// [rackPalRileyPath]).
const int kRackPalRileyWidth = 544;

/// See [kRackPalRileyWidth]. Exactly [kRackPalLockupCapHeight], so Riley
/// stands cap-high on row 2 rather than being fitted by eye.
const int kRackPalRileyHeight = 675;

/// Where Riley sits inside the lockup: flush right to
/// [kRackPalLockupWidth], on the row-2 baseline.
///
/// 268 units clear of PAL's right edge. A caller composing the full mark
/// translates [rackPalRileyPath] by these and draws it as a SECOND path;
/// see that function for why it is never merged into the wordmark.
const int kRackPalRileyLeft = 2244;

/// See [kRackPalRileyLeft].
const int kRackPalRileyTop = 811;

const String _ruledD =
    'M 0 0 L 0 118 L 370 118 C 435 118 464 159 464 207 C 464 255 '
    '437 301 370 301 L 107 301 C 33 301 1 332 1 408 L 1 675 L 119 '
    '675 L 119 431 C 119 419 125 414 136 414 L 312 414 L 466 675 L '
    '597 675 L 440 405 C 543 376 583 286 583 202 C 583 94 518 0 366 '
    '0 Z M 997 132 C 1004 116 1015 109 1031 109 C 1047 109 1058 116 '
    '1064 132 L 1269 675 L 1400 675 L 1172 75 C 1148 12 1102 -12 '
    '1032 -12 C 961 -12 915 12 890 75 L 653 675 L 783 675 Z M 1780 '
    '0 C 1584 0 1475 111 1475 338 C 1475 564 1583 675 1780 675 L '
    '2041 675 L 2041 557 L 1780 557 C 1649 557 1593 492 1593 338 C '
    '1593 183 1650 118 1780 118 L 2041 118 L 2041 0 Z M 2182 0 L '
    '2182 675 L 2300 675 L 2300 393 L 2365 393 C 2492 393 2516 403 '
    '2553 475 L 2656 675 L 2788 675 L 2679 463 C 2639 385 2608 350 '
    '2545 333 C 2600 309 2632 270 2662 210 L 2768 0 L 2641 0 L 2538 '
    '202 C 2500 276 2481 286 2365 286 L 2300 286 L 2300 0 Z M 0 811 '
    'L 0 929 L 351 929 C 415 929 444 970 444 1019 C 444 1066 417 '
    '1112 350 1112 L 107 1112 C 33 1112 1 1143 1 1219 L 1 1486 L '
    '119 1486 L 119 1242 C 119 1230 125 1225 136 1225 L 346 1225 C '
    '504 1225 563 1115 563 1013 C 563 905 498 811 346 811 Z M 962 '
    '943 C 969 927 980 920 996 920 C 1012 920 1023 927 1029 943 L '
    '1234 1486 L 1365 1486 L 1137 886 C 1113 823 1067 799 997 799 C '
    '926 799 880 823 855 886 L 618 1486 L 748 1486 Z M 1458 811 L '
    '1458 1253 C 1458 1388 1528 1486 1707 1486 L 1976 1486 L 1976 '
    '1368 L 1714 1368 C 1608 1368 1576 1317 1576 1252 L 1576 811 Z '
    'M 0 724 L 2788 724 L 2788 762 L 0 762 Z';

const String _plainD =
    'M 0 0 L 0 118 L 370 118 C 435 118 464 159 464 207 C 464 255 '
    '437 301 370 301 L 107 301 C 33 301 1 332 1 408 L 1 675 L 119 '
    '675 L 119 431 C 119 419 125 414 136 414 L 312 414 L 466 675 L '
    '597 675 L 440 405 C 543 376 583 286 583 202 C 583 94 518 0 366 '
    '0 Z M 997 132 C 1004 116 1015 109 1031 109 C 1047 109 1058 116 '
    '1064 132 L 1269 675 L 1400 675 L 1172 75 C 1148 12 1102 -12 '
    '1032 -12 C 961 -12 915 12 890 75 L 653 675 L 783 675 Z M 1780 '
    '0 C 1584 0 1475 111 1475 338 C 1475 564 1583 675 1780 675 L '
    '2041 675 L 2041 557 L 1780 557 C 1649 557 1593 492 1593 338 C '
    '1593 183 1650 118 1780 118 L 2041 118 L 2041 0 Z M 2182 0 L '
    '2182 675 L 2300 675 L 2300 393 L 2365 393 C 2492 393 2516 403 '
    '2553 475 L 2656 675 L 2788 675 L 2679 463 C 2639 385 2608 350 '
    '2545 333 C 2600 309 2632 270 2662 210 L 2768 0 L 2641 0 L 2538 '
    '202 C 2500 276 2481 286 2365 286 L 2300 286 L 2300 0 Z M 0 811 '
    'L 0 929 L 351 929 C 415 929 444 970 444 1019 C 444 1066 417 '
    '1112 350 1112 L 107 1112 C 33 1112 1 1143 1 1219 L 1 1486 L '
    '119 1486 L 119 1242 C 119 1230 125 1225 136 1225 L 346 1225 C '
    '504 1225 563 1115 563 1013 C 563 905 498 811 346 811 Z M 962 '
    '943 C 969 927 980 920 996 920 C 1012 920 1023 927 1029 943 L '
    '1234 1486 L 1365 1486 L 1137 886 C 1113 823 1067 799 997 799 C '
    '926 799 880 823 855 886 L 618 1486 L 748 1486 Z M 1458 811 L '
    '1458 1253 C 1458 1388 1528 1486 1707 1486 L 1976 1486 L 1976 '
    '1368 L 1714 1368 C 1608 1368 1576 1317 1576 1252 L 1576 811 Z';

const String _rileyD =
    'M 320 0 C 314 3 297 18 292 22 L 289 22 L 264 47 L 261 47 C 254 '
    '53 233 76 225 86 C 217 96 216 102 212 108 L 202 119 C 199 120 '
    '199 116 195 116 L 180 116 L 177 112 L 158 112 L 155 116 L 136 '
    '116 L 133 119 C 131 119 130 117 127 119 C 123 120 116 124 111 '
    '128 L 97 145 L 98 153 L 111 153 L 112 158 C 111 159 108 157 '
    '102 159 C 96 162 84 167 77 172 L 59 186 L 59 192 C 60 194 60 '
    '195 64 197 C 68 199 82 202 86 203 L 89 206 C 91 207 92 205 95 '
    '206 L 106 214 C 106 217 96 222 94 227 C 91 231 92 236 91 239 L '
    '88 242 L 88 255 L 78 264 C 77 266 80 264 78 267 C 76 270 68 '
    '279 66 283 C 63 287 64 290 62 292 C 61 295 62 288 56 298 C 50 '
    '309 33 347 28 358 L 28 364 L 25 367 L 25 373 L 22 377 L 22 383 '
    'L 19 386 C 18 388 20 388 19 392 C 17 397 11 408 9 414 L 9 427 '
    'C 9 429 7 425 6 430 C 5 434 4 450 3 455 L 0 458 C 0 460 -1 462 '
    '6 470 L 42 506 C 50 512 48 505 52 503 L 61 494 L 77 494 L 80 '
    '497 L 92 497 L 95 500 L 127 500 L 130 503 L 139 503 C 142 502 '
    '144 500 147 495 C 150 491 155 481 156 477 L 156 470 L 164 462 '
    'C 167 462 174 465 177 466 L 180 469 L 198 469 C 204 466 210 '
    '456 212 452 C 215 448 211 449 212 445 L 223 428 L 227 428 L '
    '234 436 C 235 439 234 441 228 448 L 202 478 L 167 475 C 161 '
    '475 165 475 162 480 C 160 484 156 497 153 502 L 145 509 L 108 '
    '509 L 105 506 L 83 506 L 80 503 C 77 503 68 502 64 503 L 56 '
    '508 L 56 514 C 57 516 54 515 61 519 C 67 522 89 531 95 534 L '
    '100 539 C 100 541 95 542 94 545 C 92 548 92 555 91 558 L 88 '
    '561 L 88 583 L 92 588 C 94 588 95 588 98 588 C 102 586 108 582 '
    '111 581 L 119 583 L 119 586 C 117 588 116 591 108 597 L 69 620 '
    'L 70 625 L 95 625 L 98 628 L 108 628 L 112 633 C 113 634 110 '
    '633 109 636 C 108 639 108 648 106 652 C 105 655 102 655 100 '
    '658 L 94 670 L 98 675 L 461 675 L 466 670 C 466 668 465 667 '
    '466 664 C 467 661 470 658 472 652 C 473 645 474 631 475 627 L '
    '478 623 L 478 611 L 481 608 L 481 580 L 484 577 L 484 539 L '
    '488 536 L 488 520 L 492 519 L 495 528 L 503 523 L 503 517 L '
    '506 514 C 507 512 505 512 506 508 C 508 503 514 491 516 486 L '
    '516 477 L 519 473 L 519 464 L 522 461 L 522 411 L 527 409 L '
    '539 425 L 544 423 L 544 395 C 543 390 542 398 541 392 C 540 '
    '386 538 367 538 361 L 534 358 C 534 356 536 353 534 348 L 525 '
    '333 C 525 328 533 321 534 317 L 534 311 L 525 308 C 523 306 '
    '523 306 525 302 C 527 297 533 285 534 280 L 534 270 L 538 267 '
    'L 538 264 L 531 258 L 534 236 L 523 234 L 520 238 L 516 233 C '
    '515 225 518 197 519 189 L 522 186 L 522 111 C 521 98 520 115 '
    '519 108 C 518 101 517 77 516 70 L 512 67 L 512 58 C 512 56 510 '
    '58 509 55 C 508 52 508 43 506 39 C 505 35 501 32 500 30 C 499 '
    '27 501 27 500 23 C 499 20 496 14 494 11 L 486 3 L 483 3 L 473 '
    '12 C 471 14 476 8 470 12 C 465 17 445 33 439 38 C 433 42 452 '
    '24 436 38 C 420 51 361 105 345 119 L 342 119 L 341 58 L 338 55 '
    'L 338 36 L 334 33 L 334 20 C 334 18 332 20 331 17 L 328 2 L '
    '320 0 Z M 178 323 C 185 321 195 320 202 322 C 208 323 211 327 '
    '216 333 C 220 338 226 344 228 355 C 230 365 230 385 228 395 C '
    '226 406 218 412 214 416 C 210 420 204 418 202 419 L 198 422 C '
    '195 421 185 419 180 416 C 174 412 170 408 166 402 C 162 396 '
    '158 388 156 380 L 156 352 L 159 348 C 160 347 159 344 159 342 '
    'C 160 340 159 339 162 336 C 166 333 172 326 178 323 Z';

DiagramPath? _rileyPath;

/// Riley, the mascot, as one path with the eye as a second subpath.
///
/// A SEPARATE PATH FROM THE WORDMARK, AND FOR TWO INDEPENDENT REASONS.
/// The first is licensing: 4.5's one-merged-path rule exists because the
/// letterforms are font-derived, and Riley is not, so that rule does not
/// reach it and merging would only obscure which half the rule governs.
/// The second is mechanical and would bite even if the first did not:
/// the eye is a hole, so Riley needs an EVEN-ODD fill where the
/// letterforms are drawn nonzero. One path cannot carry two fill rules,
/// and this file's header promises that nonzero and even-odd agree for
/// the wordmark, which is only true because its counters are open.
///
/// Traced from the supplied artwork rather than drawn here, at 98.6%
/// pixel agreement against the source raster, with turns sharper than
/// 42 degrees kept as corners so the ears and the jaw teeth survive.
DiagramPath rackPalRileyPath() => _rileyPath ??= DiagramPath.fromSvg(_rileyD);

DiagramPath? _ruledPath;
DiagramPath? _plainPath;

/// The stacked RACK-over-PAL lockup, parsed once and memoised.
///
/// `ruled` adds the horizontal rule between the rows; see
/// [kRackPalLockupMinRuledCapPx] for when not to.
DiagramPath rackPalLockupPath({required bool ruled}) {
  if (ruled) {
    return _ruledPath ??= DiagramPath.fromSvg(_ruledD);
  }
  return _plainPath ??= DiagramPath.fromSvg(_plainD);
}
