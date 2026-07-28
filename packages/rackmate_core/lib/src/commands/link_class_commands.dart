// THE USER'S HALF OF DR-008 §11.8.2 — the classifier's half is
// `derived/link_class.dart`, and the two never write to each other.
//
// ═════════════════════════════════════════════════════════════════════
// TWO COMMANDS, AND THE SECOND IS NOT OPTIONAL
// ═════════════════════════════════════════════════════════════════════
// Setting a class by hand and handing it back to the classifier are two
// gestures with two undo entries. Folding "clear" into
// [SetLinkClassCommand] as a nullable parameter would work — `null` means
// unlock — but it makes the common case carry a nullable it never wants,
// and it gives the Edit menu one label for two opposite actions.
//
// Shipping only the setter would be worse than untidy: it is a ONE-WAY
// DOOR. §11.8.2 makes the classifier advisory, not disposable, and a user
// who classes one link by hand must be able to say "never mind, you
// were right" — otherwise the override is a trap that survives every
// later document change, which is precisely the failure the ruling's
// visible-disagreement clause exists to surface rather than create.
//
// ═════════════════════════════════════════════════════════════════════
// CLEARING DOES NOT REWRITE `linkClass`, AND THAT IS DELIBERATE
// ═════════════════════════════════════════════════════════════════════
// [ClearLinkClassOverrideCommand] drops the lock and leaves the stored
// class exactly where it was, inert. The alternative — writing the
// classifier's current answer into the field on the way out — would store
// a value that is computable from other stored facts, which is the thing
// CR-107 deleted `StructureDrop` for. It would also be wrong the moment
// the document moved again, and it would make `revert()` restore a value
// no person ever chose.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/link.dart' show LinkClass;
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Records that A PERSON says this link is [linkClass], and pins it
/// against re-classification (DR-008 §11.8.2).
///
/// Sets both pieces of state: the value, and the bit that says a human
/// put it there. The classifier is never consulted here — an assertion
/// that happens to agree with the classifier today is still an
/// assertion, and demoting it to "unlocked because it matches" would
/// silently drop the user's word the next time the document moved.
final class SetLinkClassCommand extends Command {
  SetLinkClassCommand({required this.linkId, required this.linkClass});

  /// The run being classified.
  final Uuid linkId;

  /// What the user says it is.
  final LinkClass linkClass;

  /// The pair replaced, captured in [apply] and restored by [revert].
  /// [_applied] carries the "has run" bit rather than a null check,
  /// matching `SetLinkJacketColorCommand` — and here it is load-bearing
  /// twice over, since `false` is a perfectly ordinary previous value for
  /// [_previousLocked].
  late LinkClass _previousClass;
  late bool _previousLocked;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.setLinkClass;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  void apply(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    _previousClass = link.linkClass;
    _previousLocked = link.linkClassLocked;
    _applied = true;
    link
      ..linkClass = linkClass
      ..linkClassLocked = true;
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    if (!_applied) {
      throw StateError('SetLinkClassCommand.revert called before apply().');
    }
    // BOTH fields, and the lock is the one that matters. Restoring only
    // the class would leave a link pinned by an assertion the user has
    // just undone — visibly correct, permanently deaf to the classifier.
    link
      ..linkClass = _previousClass
      ..linkClassLocked = _previousLocked;
  }
}

/// Hands this link back to the classifier, dropping the user's pin
/// (DR-008 §11.8.2).
///
/// Leaves `Link.linkClass` untouched; see the file header. After this,
/// `effectiveLinkClassOf` reads the classifier again — including `null`
/// for undetermined, which is a legitimate outcome and not a failure of
/// this command.
final class ClearLinkClassOverrideCommand extends Command {
  ClearLinkClassOverrideCommand({required this.linkId});

  /// The run being handed back.
  final Uuid linkId;

  bool _previousLocked = false;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.clearLinkClassOverride;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  void apply(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    _previousLocked = link.linkClassLocked;
    _applied = true;
    link.linkClassLocked = false;
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    if (!_applied) {
      throw StateError(
        'ClearLinkClassOverrideCommand.revert called before apply().',
      );
    }
    // Restores the LOCK ONLY, because apply() changed nothing else. The
    // stored class was already the user's; it never moved.
    link.linkClassLocked = _previousLocked;
  }
}
