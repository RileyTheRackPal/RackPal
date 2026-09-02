import 'package:rackpal_core/src/model/enums.dart' show Severity;

/// A per-project severity override for one DRC rule, keyed by `ruleId` on
/// `ProjectSettings.ruleOverrides` (CR-019). Replaces a bare
/// `Map<String, Severity>` because the justification a rule override
/// carries is exactly what an inspector or client wants to see printed
/// on sheet T0.02.
/// IMMUTABLE, WHICH THE CORPUS ALREADY SAID AND THE CODE DID NOT DO.
/// `JacketColorDef` describes itself as *"immutable with `const` fields,
/// matching `RuleOverride`: an edit replaces the whole map value, which is
/// the simplest possible undo unit"*, and until `#260` wired this type to
/// a command that claim was true of `JacketColorDef` alone. It is true of
/// both now. AC-013's note here read *"plain mutable pending `@internal`
/// retrofit, converted as each is wired to a Command"*, and the retrofit a
/// map value actually wants is not a setter: it is no setter at all,
/// because `SetRuleOverrideCommand` swaps the whole entry, and an override
/// editable in place would have an undo that restored a severity nobody
/// touched.
final class RuleOverride {
  const RuleOverride({
    required this.severity,
    required this.reason,
    required this.by,
    required this.at,
  });

  /// What this rule counts as in THIS project. `Severity.off` is a legal
  /// value and means the rule does not fire here at all.
  final Severity severity;

  /// Why. Required and non-empty at the WRITER (`#260`): a rule override
  /// is a project-scope act, and CR-019 replaced the bare severity map
  /// precisely to have somewhere to put this. The codec accepts whatever
  /// a file holds, for the reason `acknowledgement_commands.dart` argues.
  final String reason;

  final String by;
  final DateTime at;
}
