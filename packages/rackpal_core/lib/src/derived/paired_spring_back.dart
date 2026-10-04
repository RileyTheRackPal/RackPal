// Tier 2 over a gesture that makes MORE THAN ONE pair at once (DR-234,
// canon §11.233, board `#909` and `#999`).
//
// ═══════════════════════════════════════════════════════════════════════
// A RULE IS ABOUT THE STATE, SO EVERY PAIR IS ASKED
// ═══════════════════════════════════════════════════════════════════════
// DR-116 §11.115.3 ruled that tier 2 governs the resulting state and not
// the gesture that produced it. Two gestures make several pairs in one go,
// the atomic set (one cable, N conductors) and multi-draw (N cables), and
// neither asked tier 2 at all: a stereo pair on two 3-pin blocks dropped on
// an XLR pair became a cable with no `CON-001` chip, where the pin gesture
// springs each half back.
//
// `evaluateSpringBack` answers about ONE pair, so this asks it of each pair
// in order and the first chip wins (§11.233.1), as tier 1 already does
// across a set's positions. The chip is that pair's own, so its headline
// names two jacks a person can find (§11.233.2), and the explanation gains
// a count of how many of the gesture's pairs spring back.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT A REMEDY MEANS DEPENDS ON THE GESTURE
// ═══════════════════════════════════════════════════════════════════════
// On a SET, only `CON-001`'s adapter survives (§11.233.4), and only when
// every failing pair failed on `CON-001` alone: one adapter declared on the
// cable clears every conductor, because the rule reads adapters per cable,
// and a remedy offered while another pair breaks a different rule would
// clear one rule and commit past the other. `SpringBackRule` evaluates
// `CON-001` LAST, so a pair whose chip is `CON-001` passed the other five;
// that is what makes "the first chip of every failing pair" the right test.
// The remedies that insert a device wire pin-to-pin cables and would split
// a one-cable set apart, so they are withheld.
//
// On a MULTI-DRAW, none (§11.233.5, the implementer's stated default): the
// run is N cables and a remedy that repairs one while the rest commit has
// no single meaning.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/connect_target.dart';
import 'package:rackpal_core/src/derived/spring_back_rules.dart';
import 'package:rackpal_core/src/model/rack_document.dart';

/// Which multi-pair gesture is asking, because the count's noun and the
/// remedies differ.
enum PairedGesture {
  /// One cable, N conductors (`atomicConnect`).
  set,

  /// N cables from a selected run of jacks.
  multiDraw,
}

/// The chip a multi-pair gesture springs back with, and the pair it names.
@immutable
final class PairedSpringBack {
  const PairedSpringBack({
    required this.chip,
    required this.from,
    required this.to,
    required this.failing,
    required this.asked,
  });

  /// The first failing pair's chip, with the count in its explanation and
  /// the gesture's remedies.
  final SpringBackChip chip;

  /// The pair [chip] names: the pins a remedy acts on.
  final ConnectTarget from;
  final ConnectTarget to;

  /// How many pairs spring back, the first included.
  final int failing;

  /// How many pairs were asked.
  final int asked;
}

/// Tier 2 over [pairs], in order: `null` when every pair is clear.
PairedSpringBack? evaluatePairedSpringBack(
  RackDocument doc,
  List<(ConnectTarget, ConnectTarget)> pairs, {
  required PairedGesture gesture,
}) {
  SpringBackChip? first;
  ConnectTarget? firstFrom;
  ConnectTarget? firstTo;
  var failing = 0;
  var connectorOnly = true;
  for (final (from, to) in pairs) {
    // `ontoLink: null` on both gestures, for the pin gesture's reason:
    // each mints a fresh Link, so there is none yet to carry an adapter.
    final verdict = evaluateSpringBack(doc, from, to);
    if (verdict is! SpringBackChip) continue;
    failing++;
    if (verdict.rule != SpringBackRule.connectorsDoNotMate) {
      connectorOnly = false;
    }
    if (first == null) {
      first = verdict;
      firstFrom = from;
      firstTo = to;
    }
  }
  if (first == null) return null;

  final asked = pairs.length;
  final noun = switch (gesture) {
    PairedGesture.set => "this cable's $asked paired conductors",
    PairedGesture.multiDraw => 'the $asked cables',
  };
  final count = asked < 2
      ? ''
      : ' $failing of $noun ${failing == 1 ? 'springs' : 'spring'} back.';
  final remedies = switch (gesture) {
    PairedGesture.set when connectorOnly =>
      first.remedies
          .where((r) => r == SpringBackRemedy.declareAdapter)
          .toList(growable: false),
    _ => const <SpringBackRemedy>[],
  };
  return PairedSpringBack(
    chip: SpringBackChip(
      rule: first.rule,
      headline: first.headline,
      explanation: '${first.explanation}$count',
      remedies: remedies,
    ),
    from: firstFrom!,
    to: firstTo!,
    failing: failing,
    asked: asked,
  );
}
