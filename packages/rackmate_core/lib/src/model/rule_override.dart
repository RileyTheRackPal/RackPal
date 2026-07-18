import 'package:rackmate_core/src/model/enums.dart' show Severity;

/// A per-project severity override for one DRC rule, keyed by `ruleId` on
/// `ProjectSettings.ruleOverrides` (CR-019). Replaces a bare
/// `Map<String, Severity>` because the justification a rule override
/// carries is exactly what an inspector or client wants to see printed
/// on sheet T0.02.
final class RuleOverride {
  RuleOverride({
    required this.severity,
    required this.reason,
    required this.by,
    required this.at,
  });

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  Severity severity;
  String reason;
  String by;
  DateTime at;
}
