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
// from `Font Software` outright. What that section GIVES, three others
// take back:
//
//   * 4.3 forbids embedding the font in any application, so no font
//     file may enter this repository, now or later;
//   * 4.6 forbids inclusion in Publicly Available Software, which is
//     the GPLv3 release under consideration, in all but name;
//   * 4.5 forbids fixed artwork whose effect is to let a recipient
//     compose new text.
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
// WHY THE TWO ROWS ARE NOT THE SAME AS TWO ROWS
// ═════════════════════════════════════════════════════════════════════
// MATE is 262 upem units wider than RACK, so stacking them raw ragged
// the right edge and left the rule ending against nothing. RACK is
// therefore tracked +70/1000 em, solved against INK rather than
// advances: advances carry side bearings, so flushing on them measures
// as flush and does not look it. The residual is zero units.
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
const int kRackPalLockupWidth = 2999;

/// See [kRackPalLockupWidth].
const int kRackPalLockupHeight = 1486;

/// See [kRackPalLockupWidth].
const int kRackPalLockupCapHeight = 675;

/// How far the round letters pass the cap line and the baseline.
///
/// Symmetric, and measured rather than assumed.
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

const String _ruledD =
    'M0 0 L0 118 L370 118 C435 118 464 159 464 207 C464 255 437 301 '
    '370 301 L107 301 C33 301 1 332 1 408 L1 675 L119 675 L119 431 '
    'C119 419 125 414 136 414 L312 414 L466 675 L597 675 L440 405 '
    'C543 376 583 286 583 202 C583 94 518 0 366 0 Z M1067 132 C1074 '
    '116 1085 109 1101 109 C1117 109 1128 116 1134 132 L1339 675 '
    'L1470 675 L1242 75 C1218 12 1172 -12 1102 -12 C1031 -12 985 12 '
    '960 75 L723 675 L853 675 Z M1920 0 C1724 0 1615 111 1615 338 '
    'C1615 564 1723 675 1920 675 L2181 675 L2181 557 L1920 557 '
    'C1789 557 1733 492 1733 338 C1733 183 1790 118 1920 118 L2181 '
    '118 L2181 0 Z M2392 0 L2392 675 L2510 675 L2510 393 L2575 393 '
    'C2702 393 2726 403 2763 475 L2866 675 L2998 675 L2889 463 '
    'C2849 385 2818 350 2755 333 C2810 309 2842 270 2872 210 L2978 '
    '0 L2851 0 L2748 202 C2710 276 2691 286 2575 286 L2510 286 '
    'L2510 0 Z M118 956 C118 930 135 913 166 913 C193 913 208 927 '
    '213 949 L309 1362 C329 1449 378 1498 472 1498 C565 1498 611 '
    '1451 632 1362 L729 949 C734 927 748 913 776 913 C807 913 824 '
    '930 824 956 L824 1486 L941 1486 L941 950 C941 860 888 799 779 '
    '799 C682 799 632 847 613 932 L518 1345 C512 1369 498 1383 473 '
    '1383 C448 1383 434 1369 428 1345 L333 932 C314 847 259 799 163 '
    '799 C54 799 1 860 1 950 L1 1486 L118 1486 Z M1385 943 C1392 '
    '927 1403 920 1419 920 C1435 920 1446 927 1452 943 L1657 1486 '
    'L1788 1486 L1560 886 C1536 823 1490 799 1420 799 C1349 799 '
    '1303 823 1278 886 L1041 1486 L1171 1486 Z M1835 811 L1835 929 '
    'L2032 929 L2032 1486 L2151 1486 L2151 929 L2348 929 L2348 811 '
    'Z M2660 811 C2501 811 2434 887 2434 995 C2434 1069 2466 1121 '
    '2529 1147 C2467 1173 2432 1225 2432 1302 C2432 1407 2497 1486 '
    '2657 1486 L2999 1486 L2999 1368 L2657 1368 C2588 1368 2555 '
    '1336 2555 1283 C2555 1228 2590 1201 2658 1201 L2993 1201 L2993 '
    '1094 L2661 1094 C2593 1094 2558 1069 2558 1014 C2558 962 2589 '
    '929 2660 929 L2998 929 L2998 811 Z M0 724 L2999 724 L2999 762 '
    'L0 762 Z';

const String _plainD =
    'M0 0 L0 118 L370 118 C435 118 464 159 464 207 C464 255 437 301 '
    '370 301 L107 301 C33 301 1 332 1 408 L1 675 L119 675 L119 431 '
    'C119 419 125 414 136 414 L312 414 L466 675 L597 675 L440 405 '
    'C543 376 583 286 583 202 C583 94 518 0 366 0 Z M1067 132 C1074 '
    '116 1085 109 1101 109 C1117 109 1128 116 1134 132 L1339 675 '
    'L1470 675 L1242 75 C1218 12 1172 -12 1102 -12 C1031 -12 985 12 '
    '960 75 L723 675 L853 675 Z M1920 0 C1724 0 1615 111 1615 338 '
    'C1615 564 1723 675 1920 675 L2181 675 L2181 557 L1920 557 '
    'C1789 557 1733 492 1733 338 C1733 183 1790 118 1920 118 L2181 '
    '118 L2181 0 Z M2392 0 L2392 675 L2510 675 L2510 393 L2575 393 '
    'C2702 393 2726 403 2763 475 L2866 675 L2998 675 L2889 463 '
    'C2849 385 2818 350 2755 333 C2810 309 2842 270 2872 210 L2978 '
    '0 L2851 0 L2748 202 C2710 276 2691 286 2575 286 L2510 286 '
    'L2510 0 Z M118 956 C118 930 135 913 166 913 C193 913 208 927 '
    '213 949 L309 1362 C329 1449 378 1498 472 1498 C565 1498 611 '
    '1451 632 1362 L729 949 C734 927 748 913 776 913 C807 913 824 '
    '930 824 956 L824 1486 L941 1486 L941 950 C941 860 888 799 779 '
    '799 C682 799 632 847 613 932 L518 1345 C512 1369 498 1383 473 '
    '1383 C448 1383 434 1369 428 1345 L333 932 C314 847 259 799 163 '
    '799 C54 799 1 860 1 950 L1 1486 L118 1486 Z M1385 943 C1392 '
    '927 1403 920 1419 920 C1435 920 1446 927 1452 943 L1657 1486 '
    'L1788 1486 L1560 886 C1536 823 1490 799 1420 799 C1349 799 '
    '1303 823 1278 886 L1041 1486 L1171 1486 Z M1835 811 L1835 929 '
    'L2032 929 L2032 1486 L2151 1486 L2151 929 L2348 929 L2348 811 '
    'Z M2660 811 C2501 811 2434 887 2434 995 C2434 1069 2466 1121 '
    '2529 1147 C2467 1173 2432 1225 2432 1302 C2432 1407 2497 1486 '
    '2657 1486 L2999 1486 L2999 1368 L2657 1368 C2588 1368 2555 '
    '1336 2555 1283 C2555 1228 2590 1201 2658 1201 L2993 1201 L2993 '
    '1094 L2661 1094 C2593 1094 2558 1069 2558 1014 C2558 962 2589 '
    '929 2660 929 L2998 929 L2998 811 Z';

DiagramPath? _ruledPath;
DiagramPath? _plainPath;

/// The stacked RACK-over-MATE lockup, parsed once and memoised.
///
/// `ruled` adds the horizontal rule between the rows; see
/// [kRackPalLockupMinRuledCapPx] for when not to.
DiagramPath rackPalLockupPath({required bool ruled}) {
  if (ruled) {
    return _ruledPath ??= DiagramPath.fromSvg(_ruledD);
  }
  return _plainPath ??= DiagramPath.fromSvg(_plainD);
}
