// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/units/ids.dart';

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

  /// **A PLANNING ESTIMATE, NOT AN NEC LOAD CALCULATION** (DR-079
  /// §11.78.4). Derived, never stored (CR-048).
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// WHAT 80% IS, AND WHAT IT IS NOT
  /// ═════════════════════════════════════════════════════════════════
  /// This comment used to read `NEC 210.19(A)(1)` and nothing else,
  /// which invited the reading that the arithmetic IS the code rule.
  /// Eighty percent of the breaker is the **continuous-load allowance**.
  /// It is not a load calculation: there are no demand factors here,
  /// nothing in this product classifies a load as continuous or
  /// non-continuous, and what `PWR-001` actually sums is typical draw
  /// times a diversity factor, in VA, which is a third quantity again.
  ///
  /// So the citation is INFORMATIVE: it names where the 80% figure comes
  /// from, and it does not claim that a circuit passing this check
  /// complies with anything. A person sizing a service does a load
  /// calculation; this number tells them which circuit to look at first.
  ///
  /// **`PWR-001` IS A WARNING AND WAS DEMOTED FROM AN ERROR** (CR-020)
  /// for the neighbouring reason, and `derived/totals.dart` refuses to
  /// invent a power factor to reach VA from watts (AC-039). The three
  /// together are one position: this product estimates, says so, and
  /// declines to fabricate the inputs it was not given.
  int get continuousLimitAmps => (breakerAmps * 4) ~/ 5;
}
