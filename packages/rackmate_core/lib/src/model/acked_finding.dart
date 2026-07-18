import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show Severity;
import 'package:rackmate_core/src/units/ids.dart';

/// An acknowledgement of a computed `Finding` — the ONE dismissal
/// mechanism, with two scopes (CR-019). `Finding` itself is computed and
/// never stored (§5.8); only the acknowledgement persists.
final class AckedFinding {
  AckedFinding({
    required this.id,
    required this.ruleId,
    required this.targetFingerprint,
    required this.reason,
    required this.by,
    required this.at,
    required this.demotedTo,
    required this.meta,
    this.targetEntityId,
  });

  final Uuid id;
  final String ruleId;

  /// `"*"` means a project-wide mute of this rule (reason REQUIRED).
  final String targetFingerprint;
  final Uuid? targetEntityId;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// Optional for a single-instance acknowledgement (RJ-006); required
  /// when `targetFingerprint == "*"`.
  String reason;
  String by;
  DateTime at;
  Severity demotedTo;
  EntityMeta meta;
}
