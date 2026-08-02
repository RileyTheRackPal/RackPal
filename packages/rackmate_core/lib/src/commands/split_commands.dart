// DR-014 — a wire drawn from an already-wired set member to a DIFFERENT
// device splits the set. One gesture, two writes, one undo entry.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THE USER SEES, AND WHY IT IS NOT A NEW GESTURE
// ═════════════════════════════════════════════════════════════════════
// A stereo pair connected as one cable is one `Link` with two
// `Conductor`s (`AtomicConnectCommand`). Both jacks are then FULL, so
// drawing `R` anywhere else was refused by `TOP-003` — which was the
// document being RIGHT and the product having no way to say the one thing
// the user meant: *this half goes somewhere else now.*
//
// DR-014 rules that the drag itself says it. There is no modifier to
// learn and no mode to enter, because `planSetSplit` (connect_rules.dart)
// only answers on a gesture that cannot mean anything else: a full pin,
// held by exactly one conductor, in a cable that has others, pointed at a
// device that conductor does not already reach.
//
// ═════════════════════════════════════════════════════════════════════
// TWO LINKS AFTERWARDS, AND THAT IS THE BILL OF MATERIALS CHANGING
// ═════════════════════════════════════════════════════════════════════
// DR-012.2 fixes the distinction this turns on: N `Link`s and one `Link`
// with N `Conductor`s are DIFFERENT BILLS OF MATERIALS — eight cables
// versus one eight-conductor cable — and a silent choice between them is
// the harm that ruling exists to prevent. A split moves one conductor
// across that line, so the installer's pull sheet gains a row and one
// existing row loses a path.
//
// It is therefore ANNOUNCED, in the terms DR-012.2 sets: the sentence
// names both `W` numbers and what each cable now carries. The caller
// composes it — core does not own the status line — and everything the
// sentence needs is captured on `SetSplit` BEFORE the write, because
// after it the link no longer holds the conductor being described.
import 'package:meta/meta.dart';
// `RoleMismatch` — forwarded untouched from `buildConnectPortsCommand`.
// The same type the set path reports, because it is the same fact about
// the same kind of pair (atomic_connect.dart).
import 'package:rackmate_core/src/commands/atomic_connect.dart'
    show RoleMismatch;
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/connect_commands.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/derived/connect_rules.dart';
import 'package:rackmate_core/src/derived/connect_target.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Lifts ONE [Conductor] out of a `Link`, leaving the link and everything
/// else about it — its `W` number, its `Net`, its `Service`s, its jacket
/// colour and its remaining conductors — exactly as they were.
///
/// ═════════════════════════════════════════════════════════════════════
/// NOT A REMOVE, AND THE DIFFERENCE IS A ROW ON THE SCHEDULE
/// ═════════════════════════════════════════════════════════════════════
/// `RemoveLinkCommand` takes the whole cable and its implicit `Net`. This
/// takes one electrical path and keeps the cable, because the cable is
/// still there in the wall: a stereo pair whose `R` leg has been re-routed
/// is still one `W` number pulled to one place, now carrying one path
/// instead of two. Removing and re-creating it would mint a new
/// designator and change what the installer is looking for (CR-048: a
/// designator is evaluated once at creation and stored).
///
/// THE POSITION IS RESTORED, NOT APPENDED. `revert` inserts at the same
/// index rather than adding to the end, because declared order IS the
/// contract everywhere else in this gesture family — `planAtomicConnect`
/// pairs set members BY POSITION and its header records what a shift
/// costs: *"drop an unmaterialised `L` from a set and `R` slides into
/// index 0, so the gesture lands the right cable on the WRONG PIN and
/// every downstream sheet agrees with it."* An undo that reordered the
/// survivors would do that to a cable the user had just put back.
final class SplitConductorCommand extends Command {
  SplitConductorCommand({required this.linkId, required this.index});

  final Uuid linkId;

  /// Position in the link's `conductors` list — `ConductorRef.index`,
  /// resolved against the document this command was built from.
  final int index;

  Conductor? _removed;

  /// Whether [apply] has run — NOT whether it removed anything.
  ///
  /// `RemoveLinkCommand`'s flag, for `RemoveLinkCommand`'s reason: a link
  /// can leave the document underneath a command that names it (DR-013's
  /// cascade), so "apply ran and found nothing" is a legal outcome whose
  /// revert is a no-op, while "revert without apply" is still a bug.
  /// `command_roundtrip_test`'s random sequences are what found the
  /// difference the first time.
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.splitSet;

  /// `wires` alone. No port is created or destroyed — both pins keep their
  /// designators, and the one being freed is about to be landed on again
  /// by the `ConnectPortsCommand` beside this one — so `meta` would claim
  /// an identifier change that does not happen.
  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  void apply(RackDocument doc) {
    _removed = null;
    final link = doc.links[linkId];
    // OUT OF RANGE IS THE SAME ANSWER AS ABSENT. Both mean the conductor
    // this command was planned against is not there any more, which a
    // cascade or a competing edit can arrange; neither is a reason to
    // throw out of an apply.
    if (link != null && index >= 0 && index < link.conductors.length) {
      _removed = link.conductors.removeAt(index);
    }
    _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('SplitConductorCommand.revert called before apply().');
    }
    final conductor = _removed;
    final link = doc.links[linkId];
    if (conductor != null && link != null) {
      // CLAMPED, not assumed. The list can only be shorter than it was if
      // something else took a conductor too, and inserting past the end
      // throws where appending is the honest best answer.
      final at = index <= link.conductors.length
          ? index
          : link.conductors.length;
      link.conductors.insert(at, conductor);
    }
    _removed = null;
    _applied = false;
  }
}

/// What [buildSplitConnectCommands] decided.
///
/// Sealed, and in the shape `ConnectPortsResult` already takes, so a
/// surface that handles one connect refusal handles this one too. There is
/// deliberately no third arm for "no split was needed" — that is an
/// ordinary [SplitConnectReady] with an empty [SplitConnectReady.splits],
/// because the CALLER's job is identical either way and a separate arm
/// would only be a chance to forget one.
@immutable
sealed class SplitConnectResult {
  const SplitConnectResult();
}

/// The gesture is legal. Run [commands] in ONE transaction, in order.
@immutable
final class SplitConnectReady extends SplitConnectResult {
  const SplitConnectReady({
    required this.commands,
    required this.connect,
    required this.splits,
    this.roleMismatch,
  });

  /// Every split first, then the connect. A LIST rather than a
  /// `Transaction`, for `buildMultiDrawCommands`' reason: core does not
  /// know what is selected, and a `Transaction` carries the selection
  /// before and after.
  ///
  /// THE ORDER IS LOAD-BEARING. The connect's `apply` writes a conductor
  /// onto a pin the split has to have freed first — not because anything
  /// in `apply()` re-checks `TOP-003` (nothing does), but because a
  /// document that briefly holds two conductors on a one-connection jack
  /// is a document any observer between the two writes would read as
  /// illegal.
  final List<Command> commands;

  /// The new cable, for its designator. Also inside [commands].
  final ConnectPortsCommand connect;

  /// What this gesture will lift, in [commands] order. EMPTY IS THE NORMAL
  /// CASE and means the connect needed no split at all.
  final List<SetSplit> splits;

  /// Forwarded from `buildConnectPortsCommand` — see
  /// `ConnectPortsReady.roleMismatch`. A split does not change the
  /// question: the new cable's role is still a claim about ITS two pins.
  final RoleMismatch? roleMismatch;
}

/// A tier-1 rule refuses the gesture even with the splits applied.
/// DR-011.5: nothing is written, so there is no history entry to undo.
@immutable
final class SplitConnectRefused extends SplitConnectResult {
  const SplitConnectRefused(this.verdict);
  final ConnectRefused verdict;

  String get ruleId => verdict.ruleId;
  String get message => verdict.message;
}

/// Builds the commands for a pin-to-pin connect from [from] to [to],
/// splitting either end out of its cable first where DR-014 says so.
///
/// Both ends are planned, symmetrically — see [planSplitsFor], which a
/// surface calls directly to decide which pins may be aimed at.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE RULES ARE RUN ONCE, AGAINST THE DOCUMENT AS THE SPLITS WILL LEAVE IT
/// ═══════════════════════════════════════════════════════════════════════
/// `buildConnectPortsCommand` is given the planned splits as `freeing`, so
/// `TOP-003` counts the pins as they will be and the other four rules are
/// unaffected (see `evaluateConnect`). NOTHING IS APPLIED TO PLAN — the
/// tempting shortcut is to run the splits, build the connect against the
/// mutated document and revert on refusal, and it puts a half-written
/// document in front of every observer for the duration, with no undo
/// entry to explain it if anything in between throws.
///
/// A REFUSAL RETURNS NO COMMANDS AT ALL, splits included. DR-011.5 gives
/// tier 1 no `[ Connect anyway ]`, and a refused gesture that had
/// nonetheless taken a conductor out of a cable would be the worst
/// available outcome: the user is told nothing happened, and their stereo
/// pair is now a mono cable.
SplitConnectResult buildSplitConnectCommands({
  required RackDocument doc,
  required ConnectTarget from,
  required ConnectTarget to,
  required MediaTypeId media,
  required DateTime now,
  required String actor,
  ConnectAllocations? reserve,
}) {
  final splits = planSplitsFor(doc, from, to);

  final result = buildConnectPortsCommand(
    doc: doc,
    from: from,
    to: to,
    media: media,
    now: now,
    actor: actor,
    reserve: reserve,
    freeing: {for (final split in splits) split.conductor},
  );

  // ═══════════════════════════════════════════════════════════════════
  // HIGHEST INDEX FIRST, OR TWO SPLITS ON ONE CABLE LIFT THE WRONG PATH
  // ═══════════════════════════════════════════════════════════════════
  // `ConductorRef` is a POSITION, and removing one renumbers every
  // conductor after it. Two splits usually name two different links and
  // the order is irrelevant — but CR-014 lets ONE `Link` reach more than
  // two devices through a `Breakout`, so one cable can legitimately hold
  // the conductor occupying each end of this drag. Ascending, the second
  // removal takes its neighbour: the user asked to move one leg and two
  // move.
  //
  // Descending makes each removal independent of the others, and the
  // reverse-order revert `Transaction` performs then re-inserts ascending,
  // which is the order that puts every conductor back at the index it
  // came from.
  final ordered = [...splits]
    ..sort((a, b) => b.conductor.index.compareTo(a.conductor.index));

  return switch (result) {
    ConnectPortsRefused(:final verdict) => SplitConnectRefused(verdict),
    ConnectPortsReady(:final command, :final roleMismatch) => SplitConnectReady(
      commands: [
        for (final split in ordered)
          SplitConductorCommand(
            linkId: split.conductor.linkId,
            index: split.conductor.index,
          ),
        command,
      ],
      connect: command,
      splits: List<SetSplit>.unmodifiable(splits),
      roleMismatch: roleMismatch,
    ),
  };
}
