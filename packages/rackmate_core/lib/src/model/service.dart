import 'package:rackmate_core/src/units/ids.dart';

/// ONE SIGNAL carried on a `Link`'s cable. A single Cat5e carrying an IR
/// run, a 12 V trigger and RS-232 on separate pairs is one `Link` with
/// three `Service`s (CR-010, AC-021). A sub-object of `Link` — local
/// `String` id, no document-level `Uuid` identity, no `EntityMeta`
/// (§4.8: dead weight on a conflict unit this fine-grained).
final class Service {
  Service({
    required this.id,
    required this.signalFamily,
    required this.netId,
    List<String>? conductorRoles,
    this.label,
  }) : conductorRoles = conductorRoles ?? [];

  final String id;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  SignalFamilyId signalFamily;

  /// NON-NULL — an implicit singleton net is auto-created if unassigned
  /// (CR-011).
  Uuid netId;

  /// Which conductors carry it — e.g. "pr 3", "pr 1-2".
  List<String> conductorRoles;
  String? label;
}
