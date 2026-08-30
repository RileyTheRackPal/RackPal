// Shared port/bank authoring helper for the M1 seeded catalog
// (docs/catalog/seed-devices.md §2 — the compact port notation). This is
// NOT a parser for that notation (the notation's own grammar/DSL is a
// Device Builder concern, M4) — it is a terse Dart builder that lets each
// catalog file transcribe a notation block about as densely as the
// document itself, one call per port/bank, with the exact port COUNTS and
// connector/signal-family identities the spec gives.
//
// Every port authored through this file shares one placeholder
// `PanelPosition` (all zeros): auto rear-panel layout is P10's job (M4) and
// ports are not drawn at all in M1 (`draw/scene/device_layer.dart`'s scope
// note — "ports and wiring are M2's job"), so a real computed position
// would be fabricated precision this stage cannot back up (G4). `order` is
// a simple monotonic `FracIndex` counter per template, matching every
// other hand-authored `FracIndex` in this package's test fixtures (a real
// base-62 midpoint generator is not built yet anywhere in the corpus).

import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// **NO PANEL POSITION IS AUTHORED HERE**, and that is DR-105 §11.104.2:
/// the layout is DERIVED for all 727 shipped ports, so `PortDef.position`
/// is left null and means "automatic". This file used to pass a
/// `_kZeroPosition` constant, a second spelling of `port_commands.dart`'s
/// `kUnplacedPanelPosition`, and between them the two wrote the origin
/// into every file this product has ever produced.
///
/// Accumulates [PortDef]s and their [BankDef]s for one [TemplateBody],
/// auto-numbering `order` and auto-creating a bank (presentation grouping,
/// CR-055) the first time its key is used — the same "first use wins"
/// default the notation grammar documents for bank labels (§2.1).
final class PortBuilder {
  final List<PortDef> ports = [];
  final List<BankDef> banks = [];
  final List<PortSetDef> portSets = [];
  final Map<String, int> _bankOrder = {};
  final Set<String> _setKeys = {};
  int _n = 0;

  /// The next `order`, ZERO-PADDED — and the padding is the whole point.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// `FracIndex` SORTS AS A STRING, SO `a10` CAME BEFORE `a2`
  /// ═══════════════════════════════════════════════════════════════════
  /// `FracIndex` is `extension type const FracIndex(String v)` with no
  /// comparison operator, so every consumer orders it with
  /// `a.order.v.compareTo(b.order.v)` — a raw string compare. This
  /// counter emitted `a0 … a9, a10 …`, so from the TENTH declaration
  /// onward a template's ports sorted into an order that was neither
  /// declaration order nor anything else: measured at #93, **29 of the 45
  /// seed templates with ports were scrambled, 678 of 727 ports**.
  ///
  /// It was not a cosmetic defect and it was not multi-draw's. Four
  /// separate rules read this field, and all four were wrong on those 678
  /// ports:
  ///
  ///   * FIXED_ORDER (docs/05 §3) — `buildSymbolGeometry` draws pins in
  ///     this order, so `A01`'s zone outputs were DRAWN scrambled;
  ///   * `PORT_SEQ` — the schedule's per-device port sequence;
  ///   * `chainOutputFor` (DR-012.1) — chain-draw's "next free output";
  ///   * `portsInBank` (DR-012.2) — multi-draw's rank, which is what
  ///     found it.
  ///
  /// Four digits because the largest seed template declares 56 ports plus
  /// its banks, and because a width that can be outgrown is this same bug
  /// with a higher threshold. `catalog_order_test.dart` asserts declared
  /// order and ranked order agree for EVERY seed template, which is the
  /// gate that keeps it fixed.
  ///
  /// EXISTING SAVED DOCUMENTS ARE NOT MIGRATED, and correctly so: a
  /// `TemplateSnapshot` is a snapshot (docs/02 §6), and rewriting the
  /// order values inside one would change a device the user placed
  /// months ago to match a catalog they never re-picked from. They keep
  /// the order they were captured with; anything placed from the catalog
  /// after this fix gets the right one.
  FracIndex _next() => FracIndex('a${(_n++).toString().padLeft(4, '0')}');

  void _bank(String key, String label, SymbolSide side) {
    if (_bankOrder.containsKey(key)) return;
    _bankOrder[key] = banks.length;
    banks.add(
      BankDef(
        key: key,
        label: label,
        abbr: label.length <= 4
            ? label.toUpperCase()
            : label.substring(0, 4).toUpperCase(),
        order: _next(),
        symbolSide: side,
      ),
    );
  }

  /// Declares a [PortSetDef] (electrical grouping, CR-055) once per [key].
  void set(String key, String label, SetKind kind, {bool atomic = true}) {
    if (_setKeys.add(key)) {
      portSets.add(
        PortSetDef(key: key, label: label, kind: kind, atomicConnect: atomic),
      );
    }
  }

  /// Adds one port. [bank] is the presentation-grouping key (auto-created
  /// on first use with [bankLabel]); [setKey]/[setRole] declare membership
  /// of a [PortSetDef] previously registered with [set].
  void p(
    String key,
    String label, {
    required String connector,
    required String family,
    required String bank,
    PortDirection dir = PortDirection.bidirectional,
    Face face = Face.rear,
    String? bankLabel,
    SymbolSide bankSide = SymbolSide.left,
    String? pinout,
    int? impedance,
    bool? balanced,
    bool? phantomPower,
    Polarity? polarity,
    Gender gender = Gender.genderless,
    PoeSpec? poe,
    PortPowerSpec? power,
    int? nominalVoltage,
    int? maxCurrentMa,
    int? linkSpeedMbps,
    SfpFormFactor? sfp,
    FiberMode? fiberMode,
    ReturnChannel? returnChannel,
    String? setKey,
    String? setRole,
    String? notes,
  }) {
    _bank(bank, bankLabel ?? bank, bankSide);
    ports.add(
      PortDef(
        key: PortKey(key),
        label: label,
        connector: ConnectorTypeId(connector),
        signalFamily: SignalFamilyId(family),
        face: face,
        order: _next(),
        direction: dir,
        bankKey: bank,
        pinoutVariant: pinout,
        impedanceOhms: impedance,
        balanced: balanced,
        phantomPowerCapable: phantomPower,
        polarity: polarity,
        gender: gender,
        poe: poe,
        power: power,
        nominalVoltage: nominalVoltage,
        maxCurrentMa: maxCurrentMa,
        linkSpeedMbps: linkSpeedMbps,
        sfp: sfp,
        fiberMode: fiberMode,
        returnChannel: returnChannel,
        setKey: setKey,
        setRole: setRole,
        notes: notes,
      ),
    );
  }
}
