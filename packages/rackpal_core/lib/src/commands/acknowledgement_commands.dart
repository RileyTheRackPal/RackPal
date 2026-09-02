// Writing and withdrawing an acknowledgement (`#259`, M5-B2, CR-019,
// RJ-006).
//
// ═══════════════════════════════════════════════════════════════════════
// THE WRITER IS STRICT AND THE READER IS TOLERANT
// ═══════════════════════════════════════════════════════════════════════
// RJ-006 requires a written reason for a project-wide mute. That
// requirement lives HERE and in `rule_exception.dart`, and deliberately
// NOT in `AckedFinding`'s constructor, because the codec calls that
// constructor. A throwing constructor would mean a hand-edited file with
// an empty project-wide reason fails to open, and refusing to open
// somebody's drawing to punish a missing sentence is the opposite of the
// trade this product is for.
//
// So: the command cannot be built from an exception the rules refuse,
// the codec can read anything, and `T0.02` prints whatever is actually
// there. `acknowledgement_commands_test.dart` pins both halves, since a
// tolerant reader that nobody tested is indistinguishable from a strict
// one until a customer's file arrives.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO COMMANDS, NOT ONE WITH A NULLABLE
// ═══════════════════════════════════════════════════════════════════════
// `SetFamilyColorOverrideCommand` takes `from`/`to` with null meaning
// clear, and that is right for a map keyed by a fixed vocabulary of
// families. An acknowledgement is keyed by a MINTED id: writing one
// creates an entity and withdrawing one destroys it, which is the
// add/remove shape every other entity in `commands/` uses, and the undo
// entry has to name which of the two happened (see `LabelKey`).
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/acked_finding.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/util/id_gen.dart';
import 'package:rackpal_core/src/validation/rule_exception.dart';

/// Acknowledges a finding, at either of CR-019's two scopes.
///
/// [targetFingerprint] is `Finding.targetFingerprint` for one instance,
/// or `kProjectWideFingerprint` for a project-wide mute of [ruleId]. The
/// reason is optional at instance scope (RJ-006) and required at project
/// scope, which the constructor asserts through
/// [evaluateAcknowledgement] rather than re-deriving here.
///
/// The id is minted in the constructor and never in `apply()`, so redo
/// recreates the identical entity (docs/03-architecture.md §5.1).
final class AcknowledgeFindingCommand extends Command<RackDocument> {
  AcknowledgeFindingCommand({
    required this.ruleId,
    required this.targetFingerprint,
    required this.reason,
    required this.demotedTo,
    required this.now,
    required this.actor,
    this.targetEntityId,
    Uuid? id,
  }) : id = id ?? newEntityId(),
       assert(
         evaluateAcknowledgement(
               ruleId: ruleId,
               targetFingerprint: targetFingerprint,
               reason: reason,
             )
             is RuleExceptionAllowed,
         'built from an acknowledgement the rules refuse: call '
         'evaluateAcknowledgement first and show its message',
       );

  final Uuid id;
  final String ruleId;

  /// `kProjectWideFingerprint` for a project-wide mute, otherwise the
  /// finding's own fingerprint (`finding.dart`).
  final String targetFingerprint;

  /// The one entity to select when somebody clicks this row, or null.
  /// Null is not a defect: a project-wide mute is about no entity at
  /// all, and a finding about a circuit's total draw is about a set.
  final Uuid? targetEntityId;

  final String reason;

  /// What the finding becomes. `Severity.off` hides it; anything else
  /// keeps it visible at that severity and still prints the reason on
  /// `T0.02`, which is the case an inspector's "noted, and still an
  /// error" needs.
  final Severity demotedTo;

  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.acknowledgeFinding;

  /// `meta`, on `SetProjectSettingCommand`'s reasoning: an
  /// acknowledgement changes what the document SAYS about itself and
  /// moves no geometry, and `EpochMask` names entity epochs. A broader
  /// mask would claim a device moved because somebody wrote a sentence.
  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    doc.ackedFindings[id] = AckedFinding(
      id: id,
      ruleId: ruleId,
      targetFingerprint: targetFingerprint,
      targetEntityId: targetEntityId,
      reason: reason,
      by: actor,
      at: now,
      demotedTo: demotedTo,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
    );
  }

  @override
  void revert(RackDocument doc) => doc.ackedFindings.remove(id);
}

/// Withdraws an acknowledgement, putting the finding back at whatever
/// severity the rule and any `RuleOverride` give it.
///
/// Holds the removed entity itself across the apply/revert boundary,
/// exactly as `RemoveDeviceCommand` does and for the same reason: undoing
/// a removal has to reconstruct the WHOLE entity, and the object
/// [apply] pulled out of the document already is that entity, unchanged
/// down to its `EntityMeta` triple. Rebuilding it field by field is how
/// `localRevision` quietly moves and the byte round trip fails (CR-117).
final class UnacknowledgeFindingCommand extends Command<RackDocument> {
  UnacknowledgeFindingCommand({required this.id});

  final Uuid id;

  AckedFinding? _removed;

  @override
  LabelKey get label => LabelKey.unacknowledgeFinding;

  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    _removed = doc.ackedFindings.remove(id) ?? _removed;
  }

  @override
  void revert(RackDocument doc) {
    final removed = _removed;
    if (removed != null) doc.ackedFindings[id] = removed;
  }
}
