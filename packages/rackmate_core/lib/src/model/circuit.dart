// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// A branch circuit. FLAT on the document with an optional `rackId` — a
/// branch circuit routinely feeds more than one rack, so it is never a
/// `List<Circuit>` on `Rack` (CR-028). Membership itself (which devices
/// draw from it) is derived by walking power `Link`s; `Port.circuitId`
/// survives only where the rack meets the building.
final class Circuit {
  Circuit({
    required this.id,
    required String designator,
    required this.breakerAmps,
    required this.volts,
    required this.meta,
    this.rackId,
    this.phase,
    this.dedicated = false,
    this.locationId,
  }) : _designator = designator;

  final Uuid id;

  /// "Panel A / Breaker 14".
  String _designator;
  String get designator => _designator;
  @internal
  set designator(String v) => _designator = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  Uuid? rackId;
  int breakerAmps;

  /// AUTHORITATIVE downstream — `Rack.lineVoltage` does not exist
  /// (CR-039).
  int volts;
  int? phase;
  bool dedicated;
  Uuid? locationId;
  EntityMeta meta;

  /// NEC 210.19(A)(1) — DERIVED, never stored (CR-048).
  int get continuousLimitAmps => (breakerAmps * 4) ~/ 5;
}
