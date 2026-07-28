// TWO COMMANDS, NOT ONE, and the reason is not stylistic.
//
// ═════════════════════════════════════════════════════════════════════
// WHY NOT ONE COMMAND WITH TWO PARAMETERS
// ═════════════════════════════════════════════════════════════════════
// A single `SetLinkJacketColorsCommand({JacketColorId? convention,
// JacketColorId? pulled})` cannot distinguish "leave this one alone"
// from "clear this one" — both arrive as `null`. Encoding the difference
// would need a sentinel or a wrapper per parameter, which is a worse
// version of having two commands.
//
// The domain says the same thing. These are two facts recorded by two
// different people at two different times: the DESIGNER picks the
// convention entry at design time, the TECH records the exception at
// prewire, often weeks later and often in the field. Two gestures, two
// undo entries.
//
// ═════════════════════════════════════════════════════════════════════
// CLEARING THE CONVENTION DOES NOT CASCADE-CLEAR THE OVERRIDE
// ═════════════════════════════════════════════════════════════════════
// Deliberate. Cascades are undo hazards — a single `revert()` then has
// to restore state a *different* command's before-value describes — and
// "override only, no convention" is a LEGAL state (a tech observed a
// yellow jacket; nobody has said what the run is for). Silently
// discarding that observation because the semantic field was cleared
// would destroy an observed physical fact, which is the opposite of what
// this feature is for.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Sets (or clears, with `null`) WHAT THE RUN IS — the convention entry
/// `Link.jacketColorId` references.
///
/// Does NOT touch `Link.jacketColorPulledId`; see the file header.
final class SetLinkJacketColorCommand extends Command {
  SetLinkJacketColorCommand({required this.linkId, required this.conventionId});

  /// The run being described.
  final Uuid linkId;

  /// The convention entry to name, or `null` to clear.
  final JacketColorId? conventionId;

  /// The value replaced, captured in [apply] and restored by [revert] —
  /// the `RemoveLinkCommand` pattern. Nullable-and-absent are the same
  /// thing here, so [_applied] carries the "has run" bit rather than a
  /// null check that cannot tell "cleared a null" from "never applied".
  JacketColorId? _previous;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.setLinkJacketColor;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  void apply(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    _previous = link.jacketColorId;
    _applied = true;
    link.jacketColorId = conventionId;
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    if (!_applied) {
      throw StateError(
        'SetLinkJacketColorCommand.revert called before apply().',
      );
    }
    link.jacketColorId = _previous;
  }
}

/// Records (or clears, with `null`) WHAT WAS ACTUALLY PULLED — the
/// exception `Link.jacketColorPulledId` carries.
///
/// NORMALISATION, STATED RATHER THAN HIDDEN. An override equal to the
/// run's current convention id is stored as `null`, because pulling the
/// convention colour is not an exception. This makes "no exception" have
/// exactly ONE on-disk spelling, which CR-117's byte-exactness needs —
/// two documents meaning the same thing would otherwise encode
/// differently — and it stops an exceptions count being inflated by
/// no-op overrides.
///
/// It is deliberately the only cleverness in this command, and the
/// resolver does NOT rely on it: `ResolvedJacketColor.isException`
/// re-checks the inequality itself, because a hand-edited file or a CSV
/// import never passed through here.
///
/// Does NOT touch `Link.jacketColorId`, and in particular never PROMOTES
/// an override to the convention: doing so would assert what the run is
/// for, which nobody has said (G4).
final class SetLinkPulledJacketColorCommand extends Command {
  SetLinkPulledJacketColorCommand({
    required this.linkId,
    required this.pulledId,
  });

  /// The run being described.
  final Uuid linkId;

  /// The colour actually pulled, or `null` to clear the exception. A
  /// value equal to the run's convention id is normalised to `null` —
  /// see the class doc.
  final JacketColorId? pulledId;

  JacketColorId? _previous;
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.setLinkPulledJacketColor;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  void apply(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    _previous = link.jacketColorPulledId;
    _applied = true;
    // The normalisation. Note it reads the link's CURRENT convention id
    // rather than a value captured in the constructor: the command
    // records "the pulled colour is X", and whether that is an exception
    // is a question about the document at the moment it is applied.
    link.jacketColorPulledId = pulledId == link.jacketColorId ? null : pulledId;
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    if (!_applied) {
      throw StateError(
        'SetLinkPulledJacketColorCommand.revert called before apply().',
      );
    }
    link.jacketColorPulledId = _previous;
  }
}
