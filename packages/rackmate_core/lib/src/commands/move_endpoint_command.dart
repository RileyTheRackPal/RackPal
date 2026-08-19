// rackmate_core/src/commands/move_endpoint_command.dart — pure Dart.
//
// A DROP PUNCHED INTO THE WRONG PORT. Board `#722`, DR-074 §11.73.
//
// ─────────────────────────────────────────────────────────────────────────
// THE GAP THIS CLOSES WAS NAMED, TWICE MORE, AND LEFT OPEN EACH TIME
// ─────────────────────────────────────────────────────────────────────────
// DR-040 §11.39.6: *"a deliberate 'this was punched into the wrong port'
// gesture is not specified here."* DR-071 §11.70.4 and DR-073 §11.72.7 each
// recorded it as still owed, and `buildBindEndpointCommand` refuses a
// landed end in as many words. Until DR-074 the product could record where
// a cable landed and could never record that the record was wrong.
//
// ─────────────────────────────────────────────────────────────────────────
// ONE COMMAND, ONE UNDO ENTRY, BECAUSE THE ALTERNATIVE LIES IN BETWEEN
// ─────────────────────────────────────────────────────────────────────────
// §11.73.1. Making a person unland and then re-land costs two steps and
// leaves the document momentarily saying something false: that a cable
// nobody has moved is lying loose in the rack. Correcting a hole is the
// case the gap was named for, so it is one act.
//
// UNLAND IS ITS OWN COMMAND for the same ruling's reason, which is
// `link_class_commands.dart`'s split: folding it in as a nullable target
// makes the common case carry a null it never wants and gives the Edit
// menu one label for two opposite actions.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT MOVES, AND WHAT DELIBERATELY DOES NOT
// ─────────────────────────────────────────────────────────────────────────
//  * THE RACK LABEL FOLLOWS THE POSITION, unless a person typed it
//    (§11.73.2). See [MoveEndpointCommand.rewritesRackLabel] — the pair of
//    fields, rather than a nullable label, because "write nothing" and
//    "write no label" are two outcomes and one null cannot mean both.
//  * THE TERMINATION SURVIVES (§11.73.3). `terminationRack` describes how
//    the cable END is finished, not which hole it sits in: a run can be
//    punched onto a block this project does not model at all. Clearing it
//    would assert the crew undid work they may not have touched, which is
//    a fabrication in the direction G4 forbids.
//  * THE FREED PIN STAYS (§11.73.4). `ConnectPortsCommand`'s rule, which
//    `BindEndpointCommand` already follows: a pin the document already
//    held is not this gesture's to delete, and guessing wrong deletes a
//    jack somebody else's cable may be about to use.
import 'package:rackmate_core/src/commands/bind_endpoint_command.dart'
    show LinkEnd;
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/connect_commands.dart'
    show PortMaterialisation;
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/derived/connect_rules.dart'
    show portConductorCount;
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/port.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Re-lands one end of a home run on a different jack (DR-074 §11.73.1).
///
/// Build it through [buildMoveEndpointCommand], never directly: five of the
/// six things that can be wrong with a move are facts about the document,
/// and a command that discovered them in `apply()` would have nothing to
/// tell the user and nowhere to say it.
final class MoveEndpointCommand extends Command<RackDocument> {
  MoveEndpointCommand({
    required this.linkId,
    required this.port,
    required this.rackLabel,
    required this.rewritesRackLabel,
    required this.now,
    required this.actor,
    this.end = LinkEnd.rack,
  }) : assert(
         !rewritesRackLabel || end == LinkEnd.rack,
         'Only a rack end carries a rack label: moving a speaker run at its '
         'driver says nothing about what the panel position is called.',
       );

  final Uuid linkId;

  /// Which end is moving. `BindEndpointCommand`'s enum rather than a second
  /// one, because a caller that can land an end can move it and the two
  /// must not disagree about which `Conductor` field they mean.
  final LinkEnd end;

  /// The pin it is moving TO, flat, for `PortMaterialisation`'s stated
  /// reason: a command replayed against a moved document may not re-derive
  /// an allocation.
  final PortMaterialisation port;

  /// The re-derived label, allocated caller-side through `resolveRackLabel`
  /// exactly as a landing allocates one. NULL when the pattern could not
  /// render (DR-040 §11.39.5), and ignored entirely when
  /// [rewritesRackLabel] is false.
  final String? rackLabel;

  /// Whether this move OWNS the rack label.
  ///
  /// ═════════════════════════════════════════════════════════════════════
  /// TWO FIELDS, BECAUSE ONE NULL CANNOT CARRY TWO ANSWERS
  /// ═════════════════════════════════════════════════════════════════════
  /// False here means "leave the label exactly where it is", which is what
  /// a hand-set label gets (§11.73.2) and what every field-end move gets.
  /// True with a null [rackLabel] means "the label follows the hole, and
  /// this hole renders none" — the position moved and the name genuinely
  /// went away. Folding the two into a nullable would make a panel with no
  /// floor number indistinguishable from a person's own identifier, and
  /// the whole point of `rackLabelLocked` is that they are different.
  final bool rewritesRackLabel;

  final DateTime now;
  final String actor;

  /// What was there before, so `revert` restores rather than guesses.
  Endpoint? _previousEnd;
  String? _previousRackLabel;
  EntityMeta? _previousMeta;
  bool _applied = false;

  /// Empty unless THIS `apply()` created the target pin. See the header:
  /// only what this command minted may be un-minted.
  final List<Uuid> _materialised = [];

  @override
  LabelKey get label => LabelKey.moveEndpoint;

  /// `wires` for the conductor's end, `meta` for the rack label and for the
  /// designator a materialised port mints — `BindEndpointCommand`'s pair,
  /// for its reasons, and NOT `structure`: the jack was always drawn.
  @override
  EpochMask get touches => EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [linkId, port.portId];

  @override
  void apply(RackDocument doc) {
    // Cleared, not appended to: `apply` runs again on every redo and must
    // describe THIS run.
    _materialised.clear();
    if (!doc.ports.containsKey(port.portId)) {
      doc.ports[port.portId] = Port(
        id: port.portId,
        deviceId: port.deviceId,
        designator: port.designator,
        templatePortKey: port.portKey,
      );
      _materialised.add(port.portId);
    }

    final link = doc.links[linkId];
    if (link == null) return;
    final conductor = link.conductors.first;
    final landed = PortEndpoint(port.portId);
    _previousEnd = switch (end) {
      LinkEnd.field => conductor.from,
      LinkEnd.rack => conductor.to,
    };
    _previousMeta = link.meta;
    _applied = true;
    link.conductors[0] = Conductor(
      from: end == LinkEnd.field ? landed : conductor.from,
      to: end == LinkEnd.rack ? landed : conductor.to,
      role: conductor.role,
      pairNumber: conductor.pairNumber,
      colorCode: conductor.colorCode,
    );

    // THE OLD PIN IS LEFT WHERE IT IS (§11.73.4). It is now free, which
    // `portConductorCount` will report the moment anyone asks, and that is
    // the whole of what "freed" has to mean.
    if (rewritesRackLabel) {
      if (link.structureOrigin case final origin?) {
        _previousRackLabel = origin.rackLabel;
        origin.rackLabel = rackLabel;
      }
    }
    link.meta = EntityMeta(
      createdAt: link.meta.createdAt,
      updatedAt: now,
      updatedBy: actor,
    );
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('MoveEndpointCommand.revert called before apply().');
    }
    final link = doc.links[linkId];
    if (link != null) {
      if (_previousEnd case final was?) {
        final conductor = link.conductors.first;
        link.conductors[0] = Conductor(
          from: end == LinkEnd.field ? was : conductor.from,
          to: end == LinkEnd.rack ? was : conductor.to,
          role: conductor.role,
          pairNumber: conductor.pairNumber,
          colorCode: conductor.colorCode,
        );
      }
      // Restored only where this command wrote. A move that KEPT a
      // hand-set label captured nothing, and writing null from that
      // capture would erase the very identifier the ruling protects.
      if (rewritesRackLabel) {
        if (link.structureOrigin case final origin?) {
          origin.rackLabel = _previousRackLabel;
        }
      }
      if (_previousMeta case final meta?) link.meta = meta;
    }
    for (final portId in _materialised) {
      doc.ports.remove(portId);
    }
    _materialised.clear();
    _previousEnd = null;
    _previousRackLabel = null;
    _previousMeta = null;
    _applied = false;
  }
}

/// The outcome of [buildMoveEndpointCommand].
sealed class MoveEndpointResult {
  const MoveEndpointResult();
}

final class MoveEndpointReady extends MoveEndpointResult {
  const MoveEndpointReady(this.command, {this.keptRackLabel});

  final MoveEndpointCommand command;

  /// The hand-set label this move is LEAVING ALONE, or null when the label
  /// followed the hole.
  ///
  /// The surface says so out loud, which §11.73.2 requires: a person who
  /// moved a drop and sees an old-looking label needs to know it survived
  /// because they typed it, rather than because the move half-failed.
  final String? keptRackLabel;
}

/// The move cannot happen, and [reason] is a sentence for the user.
final class MoveEndpointRefused extends MoveEndpointResult {
  const MoveEndpointRefused(this.reason);
  final String reason;
}

/// Builds a move, or refuses with a sentence.
///
/// SIX REFUSALS, AND EACH NAMES A DIFFERENT FACT ABOUT THE DOCUMENT, on
/// `buildBindEndpointCommand`'s rule and docs/04 §3.4's: a gesture that
/// declined without saying which one it hit leaves a person re-picking pins
/// at random.
///
/// [rackLabel] is what the caller's `resolveRackLabel` produced for the new
/// position. It is IGNORED when the run's label is hand-set, and the
/// builder reports that rather than silently dropping it, so the surface
/// can tell the person their name was kept.
///
/// [usedRackLabels] is the caller's scan, passed in rather than taken here,
/// for `buildBindEndpointCommand`'s reason: a batch moving ten drops onto
/// one panel is built against ONE unmutated document and each must see the
/// labels its siblings have spent.
MoveEndpointResult buildMoveEndpointCommand({
  required RackDocument doc,
  required Uuid linkId,
  required PortMaterialisation port,
  required String? rackLabel,
  required Set<String> usedRackLabels,
  required DateTime now,
  required String actor,
  LinkEnd end = LinkEnd.rack,
}) {
  final link = doc.links[linkId];
  if (link == null) {
    return const MoveEndpointRefused('That cable is not in this project.');
  }
  final origin = link.structureOrigin;
  if (origin == null) {
    // A PATCH IS NOT A DROP, and this writes a `rackLabel` onto a
    // `StructureOrigin`. `buildBindEndpointCommand` refuses the same case
    // in the same words for the same reason.
    return MoveEndpointRefused(
      'That cable is not a home run, so it has no ${_endWord(end)} end to '
      'move. Use the schematic to re-connect two devices.',
    );
  }
  if (link.conductors.isEmpty) {
    return const MoveEndpointRefused(
      'That cable has no conductors, so there is nothing to move.',
    );
  }

  final conductor = link.conductors.first;
  final existing = switch (end) {
    LinkEnd.field => conductor.from,
    LinkEnd.rack => conductor.to,
  };
  if (existing is! PortEndpoint) {
    // NOT A LANDING. The two gestures are separable and the words say so:
    // a person who reached for a move on a loose end wants to know the end
    // is loose, not to have it quietly landed for them.
    return MoveEndpointRefused(
      "That drop's ${_endWord(end)} end is not landed yet, so there is "
      'nothing to move. Land it instead.',
    );
  }
  if (existing.portId == port.portId) {
    // ASKED BEFORE OCCUPANCY, because the occupancy test would answer this
    // case with "that jack already has a cable landed on it" — which is
    // true, and the cable is this one, and it reads as a refusal about
    // somebody else's work.
    return MoveEndpointRefused(
      '${link.designator} is already landed on ${port.designator}.',
    );
  }

  // ONE CABLE PER PUNCHDOWN POSITION, asked through `portConductorCount`
  // so `TOP-003` keeps living in exactly one place.
  if (portConductorCount(doc, port.portId) > 0) {
    return MoveEndpointRefused(
      '${port.designator} already has a cable landed on it. Pick a free '
      'position.',
    );
  }

  // THE LABEL IS THE RACK END'S ALONE, and a hand-set one outranks the
  // allocator (§11.73.2).
  final locked = origin.rackLabelLocked;
  final rewrites = end == LinkEnd.rack && !locked;
  final trimmed = rewrites ? rackLabel?.trim() : null;
  final normalised = (trimmed?.isEmpty ?? true) ? null : trimmed;
  if (normalised != null && usedRackLabels.contains(normalised)) {
    // CR-113, project-wide. The caller excludes THIS link from the scan it
    // passes, or a move would collide with the label it is replacing.
    return MoveEndpointRefused(
      'Rack label "$normalised" is already used by another drop. Rack '
      'labels are unique across the whole project.',
    );
  }

  return MoveEndpointReady(
    MoveEndpointCommand(
      linkId: linkId,
      port: port,
      rackLabel: normalised,
      rewritesRackLabel: rewrites,
      now: now,
      actor: actor,
      end: end,
    ),
    keptRackLabel: end == LinkEnd.rack && locked ? origin.rackLabel : null,
  );
}

/// The word a refusal uses for [end]. Spelled once, on
/// `bind_endpoint_command.dart`'s rule: three refusals name the end, and
/// three copies is how one of them comes to say "rear".
String _endWord(LinkEnd end) => switch (end) {
  LinkEnd.field => 'field',
  LinkEnd.rack => 'rack',
};
