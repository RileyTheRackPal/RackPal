// rackpal_ui/src/canvas/schematic/spring_back_chip_card.dart
//
// docs/05 §7's REASON CHIP: what the sheet says when a cable springs back.
//
// ═════════════════════════════════════════════════════════════════════
// THE CHIP IS THE RULE'S USER INTERFACE
// ═════════════════════════════════════════════════════════════════════
// `#278` opens with that sentence and it is the whole design. Six
// predicates landed in `spring_back_rules.dart` and not one of them is
// visible to anybody: a rule nobody can read is a rule nobody obeys, and
// a rule with no way past it is one people learn to work around by not
// drawing the cable they meant to draw.
//
// `design-ux-schematic.md §2.1` gives the worked chip verbatim:
//
//     ⛔ HDBaseT output cannot terminate on an Ethernet switch port.
//        HDBaseT uses Ethernet cabling but is not interoperable; PoH
//        may damage the switch.
//        [ Insert HDBaseT receiver ]  [ Pick a different port ]  [ Why? ]
//
// and its own commentary on why the remedy is there at all: *"Offering
// the remedy is what separates a rule engine from a nag."*
//
// TWO DIFFERENCES FROM THAT MOCKUP, BOTH RULED RATHER THAN DRIFTED:
//
//  * `[ Connect anyway ]` IS ADDED. The mockup predates CR-017, under
//    which these six were Class A and refused outright. CR-017 deleted
//    the finality and kept the remedies exactly as designed, so docs/05
//    :467 now requires that *"every chip carries `[ Connect anyway ]`
//    next to its remedies"*, without exception.
//  * `[ Why? ]` IS OMITTED. DR-114 §11.113.3. AC-058/D1 names that
//    button as a defect in as many words — *"a `[Why?]` button that
//    leads nowhere"* — and canon §10(g) assigns the viewer to M5-F3
//    (`#296`). Shipping it here would be building the named defect in
//    the milestone that promised to remove it. The chip is not thereby
//    silent about why: [SpringBackChip.explanation] is the mockup's
//    second line, always present, in the trade's own words. `[ Why? ]`
//    goes DEEPER than that, to the catalogue entry, which is the thing
//    that does not exist yet.
//
// ═════════════════════════════════════════════════════════════════════
// WHERE THE COLOURS COME FROM, WHICH IS TWO PLACES ON PURPOSE
// ═════════════════════════════════════════════════════════════════════
// DR-114 §11.113.2 draws the line between what a surface IS and what it
// SAYS. The card is a panel: it takes theme roles, like `CoachMark`
// beside it, because it has to read on whatever surface the user's theme
// paints. The BADGE and the RULE ID state a verdict, so they take
// [kSpringBackRefusedArgb], the fixed `#D55E00` docs/05 §8 gives an
// `error` mark — the same colour that will sit on this very cable in the
// DRC list the moment `[ Connect anyway ]` is pressed.
//
// A MATERIAL ICON RATHER THAN THE MOCKUP'S ⛔. An emoji renders through
// the platform's colour emoji font, which means it arrives at whatever
// hue that font decided and cannot be given the verdict colour at all.
// The glyph is the thing the mockup was choosing; the colour is the
// thing DR-114 ruled on, and only one of the two can be had from an
// emoji.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/schematic/connect_overlay.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// `[ Pick a different port ]` — the mockup's own words.
///
/// A REAL BUTTON AND NOT A RELABELLED CANCEL, which is DR-114 §11.113.4.
/// CR-017's binding sentence is *"the gesture may HESITATE; the document
/// may not lie"*, and a gesture that hesitated has not ended: the wire is
/// still armed from its source and the candidate rings are still lit, so
/// this dismisses the chip and hands the user back to aiming, one frame
/// before the release they just made.
const String kSpringBackPickAnother = 'Pick a different port';

/// `[ Connect anyway ]` — CR-017's escape hatch, on every chip.
///
/// docs/02 §5.2: *"`[ Connect anyway ]` creates the Link and files a T3
/// finding."* The first half is built. **THE SECOND HALF IS NOT, AND
/// THAT IS M5-B1 RATHER THAN AN OMISSION**: `Finding` is computed and
/// never stored (docs/05 §8, CR-021), so there is no "file" for a
/// finding to be filed in. The finding APPEARS, on the next evaluation
/// pass over a document that now holds the cable, which is what a
/// computed finding means. A `filedFindings` list would be the stored
/// finding arriving through the back door.
const String kSpringBackConnectAnyway = 'Connect anyway';

/// docs/05 §7's reason chip, anchored at the target that refused.
///
/// PURE PRESENTATION AND FOUR CALLBACKS. It knows nothing about the
/// gesture, the document or the commands: the screen owns all of that,
/// and this owns the layout, the copy that is not the rule's own, and
/// the keyboard route between its buttons.
final class SpringBackChipCard extends StatelessWidget {
  const SpringBackChipCard({
    required this.chip,
    required this.onConnectAnyway,
    required this.onPickAnother,
    this.onRemedy,
    this.maxWidth = 360,
    super.key,
  });

  /// The verdict, from `evaluateSpringBack`. Its `headline` and
  /// `explanation` are rendered VERBATIM: the rule composed sentences
  /// naming the real designators, and a surface that reworded them would
  /// be a second voice for one rule.
  final SpringBackChip chip;

  /// `[ Connect anyway ]`. Never null and never absent — CR-017 admits no
  /// chip without it, so it is a required callback rather than an
  /// optional one that a caller could quietly leave off.
  final VoidCallback onConnectAnyway;

  /// `[ Pick a different port ]`.
  ///
  /// The screen calls this for `Esc` too. The KEY is not bound here (see
  /// the build method), but the ACTION is one action with two ways in.
  final VoidCallback onPickAnother;

  /// A remedy was pressed. Null means the host cannot perform remedies
  /// yet, and the buttons are then not drawn at all rather than drawn
  /// dead — the reasoning DR-114 §11.113.3 gives for `[ Why? ]` applies
  /// to any button that leads nowhere.
  final void Function(SpringBackRemedy remedy)? onRemedy;

  /// The chip is anchored at a PIN, so it must not grow to the width of
  /// the sheet. 360 logical pixels holds the worked chip's three lines at
  /// `bodySmall` without hyphenation.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const verdict = Color(kSpringBackRefusedArgb);
    final remedies = onRemedy == null
        ? const <SpringBackRemedy>[]
        : chip.remedies;

    return Semantics(
      container: true,
      // A SCREEN READER MUST HEAR THIS WITHOUT BEING ASKED. The wire
      // sprang back: something the user did was undone, and a live
      // region is how that reaches a person who cannot see the ring
      // change colour. The label is the whole chip in one sentence,
      // rule id included, because DR-011.5's rule for a refusal is the
      // id AND the sentence rather than either alone.
      liveRegion: true,
      label: '${chip.ruleId}. ${chip.headline} ${chip.explanation}',
      // NO `Esc` BINDING HERE, AND THAT IS THE REPO'S RULE RATHER THAN AN
      // OMISSION. The first draft wrapped this in `CallbackShortcuts` with
      // a `SingleActivator(escape)`, and `keymap_source_ban_test.dart`
      // refused it: AC-058/D7 and CR-101 put every keystroke in `kKeymap`,
      // because a binding built by hand is invisible to `arbitrate()` and
      // to the generated shortcut table, so nothing catches it when it
      // collides.
      //
      // AND THE REGISTRY ALREADY HOLDS THIS KEY. `schematicCancel` binds
      // Esc in `KeyScope.schematic`, and its own note describes the shape
      // this needs: *"M2-F adds a rung ABOVE the two it had ... one more
      // limb in the gate, which is exactly what layering a key means when
      // only isActionEnabled can decline one."* A chip is the next rung
      // up, so the SCREEN's cancel handler dismisses it and the wire stays
      // armed (DR-114 §11.113.4). A second Esc row in one scope would be a
      // collision the arbiter is there to forbid.
      child: FocusTraversalGroup(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            elevation: 6,
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block, size: 18, color: verdict),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chip.ruleId,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: verdict,
                                // `kConsoleEmphasis`, NOT `w700`. The
                                // first draft asked for w700 and
                                // `font_weight_coverage_test.dart`
                                // refused it: that cut is not bundled,
                                // so Flutter would SYNTHESISE it and
                                // nothing would fail visibly. This is
                                // the one real weight above Regular
                                // the bundle can draw.
                                fontWeight: kConsoleEmphasis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              chip.headline,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chip.explanation,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // WRAPPED, NOT SCROLLED. Four buttons at 360 px do
                  // not fit on one line and a chip that clipped one
                  // would hide `[ Connect anyway ]`, which is the one
                  // CR-017 says may never be missing.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final remedy in remedies)
                        FilledButton.tonal(
                          onPressed: () => onRemedy!(remedy),
                          child: Text(remedy.label),
                        ),
                      // AUTOFOCUSED, AND THE REMEDY DELIBERATELY IS
                      // NOT. A remedy is the better outcome and the
                      // one the design argues for, but SIG-001's
                      // inserts a device into the document (CR-015),
                      // and putting a mutation under the Enter key a
                      // user just pressed to commit is how a reflex
                      // becomes an edit. This one is a no-op: it
                      // closes the chip and gives the gesture back.
                      TextButton(
                        autofocus: true,
                        onPressed: onPickAnother,
                        child: const Text(kSpringBackPickAnother),
                      ),
                      // RIGHTMOST, AND THE ONLY ONE WEARING A BORDER.
                      // It is the consequential button, so it reads as
                      // deliberate rather than as one of a row.
                      //
                      // NOT "LAST IN THE TAB ORDER", which an earlier
                      // draft of this comment claimed. Measured, the
                      // ring from the opening focus is
                      // `Pick a different port` -> here -> the remedy
                      // -> back, so this is ONE Tab away and the
                      // remedy is two. That is the right way round:
                      // the override is reachable without hunting,
                      // and the button that mutates the document is
                      // the one you have to travel to.
                      OutlinedButton(
                        onPressed: onConnectAnyway,
                        child: const Text(kSpringBackConnectAnyway),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
