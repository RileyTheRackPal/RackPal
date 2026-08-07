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
    Uuid? locationId,
  }) : _designator = designator,
       _locationId = locationId;

  final Uuid id;

  /// "Panel A / Breaker 14".
  String _designator;
  String get designator => _designator;
  @internal
  set designator(String v) => _designator = v;

  /// Retrofitted by M3-B/1: `RemoveLocationCommand` clears this when the
  /// room a circuit is in is deleted (DR-021 §11.20.2), and wiring a field
  /// to a Command IS the AC-013 retrofit.
  Uuid? _locationId;
  Uuid? get locationId => _locationId;
  @internal
  set locationId(Uuid? v) => _locationId = v;

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
  EntityMeta meta;

  /// NEC 210.19(A)(1) — DERIVED, never stored (CR-048).
  int get continuousLimitAmps => (breakerAmps * 4) ~/ 5;
}
