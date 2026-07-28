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
/// STORED ABSOLUTELY — there is no normalisation, and its removal is the
/// point. `pulledId` is a physical observation about a wall, so it is
/// written exactly as given and never compared against the convention on
/// the way in. Exception-ness is derived on READ by
/// `ResolvedJacketColor.isException`, which is the only place that can get
/// it right: the convention is mutable and the cable is not.
///
/// Three distinct states, and the middle one did not exist before:
///   * `null`                      — nobody has been out there yet
///   * equal to `jacketColorId`    — SOMEBODY CHECKED AND IT MATCHES
///   * different                   — the exception
/// The earlier version collapsed the middle into the first, which made the
/// confirming command a no-op and, once a run was re-designated, reported
/// the new convention colour as as-built while counting zero exceptions.
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

  /// The colour actually pulled, or `null` to clear the observation.
  /// Stored verbatim; see the class doc.
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
    // STORED ABSOLUTELY. `pulledId` is a PHYSICAL OBSERVATION — "the cable
    // in this wall is blue" — and a physical observation does not change
    // when a drawing is re-labelled. It is written exactly as given.
    //
    // This previously normalised `pulledId == link.jacketColorId ? null :
    // pulledId`, storing the observation as a DELTA against the
    // convention, with a comment arguing that "whether that is an
    // exception is a question about the document at the moment it is
    // applied". That is the defect stated as the design. Exception-ness is
    // a question about the document at the moment it is READ, because the
    // convention is mutable and the cable is not:
    //
    //   convention = jc.blue (control); tech records pulled = jc.blue
    //     -> normalised to null, the observation is DISCARDED
    //   weeks later the designer re-designates: convention = jc.green
    //     -> the wall still holds BLUE cable, but asBuilt reports GREEN,
    //        isException reports false, and the rollup counts zero
    //        exceptions and zero unrecorded runs
    //
    // A real divergence, invisible to every accessor — the exact failure
    // this feature exists to prevent. It was also ORDER-DEPENDENT: the
    // identical real-world history recorded convention-last survived
    // intact, so two identical histories produced two stored states, one
    // of them lying.
    //
    // Storing absolutely also gives the third state the delta form could
    // not express. `pulledId == jacketColorId` now means "SOMEBODY CHECKED
    // AND IT MATCHES", which is distinct from `null` = "nobody has said".
    // Under the old form the confirming command was a no-op.
    //
    // `ResolvedJacketColor.isException` already carries the inequality
    // limb needed for this (`pulledId != null && pulledId != conventionId`)
    // — it simply never fired, because the write path had pre-normalised
    // every matching case away.
    link.jacketColorPulledId = pulledId;
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
