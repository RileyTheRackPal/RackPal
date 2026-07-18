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

import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

const _kZeroPosition = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

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

  FracIndex _next() => FracIndex('a${_n++}');

  void _bank(String key, String label, SymbolSide side) {
    if (_bankOrder.containsKey(key)) return;
    _bankOrder[key] = banks.length;
    banks.add(
      BankDef(
        key: key,
        label: label,
        abbr: label.length <= 4 ? label.toUpperCase() : label
            .substring(0, 4)
            .toUpperCase(),
        order: _next(),
        symbolSide: side,
      ),
    );
  }

  /// Declares a [PortSetDef] (electrical grouping, CR-055) once per [key].
  void set(String key, String label, SetKind kind, {bool atomic = true}) {
    if (_setKeys.add(key)) {
      portSets.add(PortSetDef(key: key, label: label, kind: kind, atomicConnect: atomic));
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
    PortDirection dir = PortDirection.bidirectional,
    Face face = Face.rear,
    required String bank,
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
        position: _kZeroPosition,
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
