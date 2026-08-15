// The port grid's footer readout (docs/06 §4.5, M4-E5 #207).
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT IT IS FOR, WHICH IS WHY IT IS ONE LINE
// ═══════════════════════════════════════════════════════════════════════
// The board task says it plainly: "the fastest check that a generator did
// what the user meant". Somebody types `24 rj45 poe:at @Ports` and reads
// one line to see whether they got 24 of them, on the rear, drawing what
// they expected. That makes it a COUNT of what is there rather than a
// verdict on it, so nothing here has a severity and nothing here refuses.
//
// ═══════════════════════════════════════════════════════════════════════
// PANEL FILL IS NOT IN IT, AND THAT IS A DECISION RATHER THAN AN OMISSION
// ═══════════════════════════════════════════════════════════════════════
// §4.5's worked line ends `· Panel fill R: 71%`, and panel fill is a
// number only the auto-layout can produce: `panel_layer.dart` is M4-K
// (`#182`) and does not exist, and `PanelPosition` is the origin on every
// port this editor has ever created. There are three ways to handle that
// and two of them are wrong. Printing a guess is G4's fabrication.
// Printing `Panel fill R: —` is what the Structure editor's band header
// already rejected in the same situation — *"`est. run — ft` in a band
// header reads as a broken template"* — because a dash belongs in a
// COLUMN, where a reader is comparing values, not in a running sentence.
// So the clause is absent until the number exists, and M4-K adds it.
import 'package:rackmate_core/src/builder/port_table.dart';
import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// How many ports of one connector type, and what they draw.
final class PortConnectorTally {
  const PortConnectorTally({
    required this.connector,
    required this.label,
    required this.count,
    required this.poePorts,
    required this.poeWatts,
    required this.poeWattsUnknown,
    required this.poeStandard,
  });

  final ConnectorTypeId connector;

  /// The trade's short name: `HDMI`, `RJ45`, `RCA`. See
  /// [portConnectorShortLabel].
  final String label;

  final int count;

  /// How many of them SUPPLY power, which is the only half worth a
  /// budget: a PD port draws from somebody else's budget, not this
  /// device's.
  final int poePorts;

  /// Watts across the ports that state one.
  final int poeWatts;

  /// How many supplying ports state no wattage.
  ///
  /// REPORTED RATHER THAN ASSUMED ZERO, which is docs/04 §5's rule for
  /// every rollup in this application: a total that quietly leaves out
  /// what it could not read is worse than one that says how much it
  /// could not read.
  final int poeWattsUnknown;

  /// The standard, when every supplying port agrees on one. Null when
  /// they differ or none says.
  final PoeStandard? poeStandard;

  bool get suppliesPower => poePorts > 0;
}

/// The footer's numbers.
final class PortSummary {
  const PortSummary({
    required this.portCount,
    required this.bankCount,
    required this.connectors,
    required this.frontCount,
    required this.rearCount,
  });

  final int portCount;
  final int bankCount;

  /// Most numerous first. The order is TOTAL (count descending, then the
  /// connector id), so the same template reads the same way twice.
  final List<PortConnectorTally> connectors;

  final int frontCount;
  final int rearCount;
}

/// The trade's short name for a connector.
///
/// THE FIRST ALIAS, WHICH IS WHAT ALIASES ARE FOR. CR-058 puts the bare
/// trade names in `ConnectorTypeDef.aliases` and keeps the canonical ids
/// namespaced, so `conn.hdmi_a` carries `hdmi` and the footer can read
/// `32 HDMI` rather than `32 HDMI Type A`. A connector with no alias
/// falls back to its display name, which is already short for the ones
/// that have none (`RCA`, `XLR 3-pin`), and an id the registry does not
/// hold falls back to the id, so a fault stays visible here as it does in
/// the CONNECTOR column.
///
/// ONLY THE ALIAS IS UPPER-CASED, and that is not a detail. Aliases are
/// lower-case DSL tokens (`hdmi`, `rj45`), so `HDMI` is restoring the
/// spelling the trade uses. A display name is already authored the way it
/// should read, and shouting it turns `XLR 3-pin` into `XLR 3-PIN`.
String portConnectorShortLabel(Registries registries, ConnectorTypeId id) {
  final def = registries.connectorTypes[id];
  if (def == null) return id.v;
  return def.aliases.isEmpty
      ? def.displayName
      : def.aliases.first.toUpperCase();
}

/// Counts [body]'s ports for the footer.
PortSummary buildPortSummary(TemplateBody body, Registries registries) {
  final counts = <String, int>{};
  final psePorts = <String, int>{};
  final poeWatts = <String, int>{};
  final poeUnknown = <String, int>{};
  final standards = <String, Set<PoeStandard>>{};
  var front = 0;
  var rear = 0;

  for (final port in body.ports) {
    final key = port.connector.v;
    counts[key] = (counts[key] ?? 0) + 1;
    if (port.face == Face.front) {
      front++;
    } else {
      rear++;
    }

    final poe = port.poe;
    if (poe == null || poe.role != PoeRole.pse) continue;
    psePorts[key] = (psePorts[key] ?? 0) + 1;
    final watts = poe.watts;
    if (watts == null) {
      poeUnknown[key] = (poeUnknown[key] ?? 0) + 1;
    } else {
      poeWatts[key] = (poeWatts[key] ?? 0) + watts;
    }
    final standard = poe.standard;
    if (standard != null) {
      standards.putIfAbsent(key, () => <PoeStandard>{}).add(standard);
    }
  }

  final ordered = counts.keys.toList()
    // TOTAL, because `List.sort` is not stable and two connector types
    // with the same count must not swap places between two builds of the
    // same template.
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });

  return PortSummary(
    portCount: body.ports.length,
    // THE BANKS THE PORTS ACTUALLY USE, not `body.banks.length`. A bank
    // declared and then emptied is not a bank the reader can see, and a
    // ports-in-no-bank group is not a declared one. This is the count the
    // grid draws band headers for.
    bankCount: buildPortTable(body).bands.length,
    connectors: [
      for (final key in ordered)
        PortConnectorTally(
          connector: ConnectorTypeId(key),
          label: portConnectorShortLabel(registries, ConnectorTypeId(key)),
          count: counts[key]!,
          poePorts: psePorts[key] ?? 0,
          poeWatts: poeWatts[key] ?? 0,
          poeWattsUnknown: poeUnknown[key] ?? 0,
          poeStandard: switch (standards[key]) {
            final Set<PoeStandard> s when s.length == 1 => s.first,
            _ => null,
          },
        ),
    ],
    frontCount: front,
    rearCount: rear,
  );
}

/// The footer, as the one line docs/06 §4.5 draws.
///
/// `68 ports · 5 banks · 32 HDMI · 17 RJ45 (PoE+ x16, 130 W) · 1 C14 ·
/// Rear 67 / Front 1`
String portSummaryLine(PortSummary summary) {
  final parts = <String>[
    _plural(summary.portCount, 'port'),
    _plural(summary.bankCount, 'bank'),
    for (final tally in summary.connectors) _connectorPart(tally),
    'Rear ${summary.rearCount} / Front ${summary.frontCount}',
  ];
  return parts.join(' · ');
}

/// `1 port`, `6 ports`. English, and one place for it.
String _plural(int count, String noun) =>
    count == 1 ? '1 $noun' : '$count ${noun}s';

String _connectorPart(PortConnectorTally tally) {
  final head = '${tally.count} ${tally.label}';
  if (!tally.suppliesPower) return head;

  final standard = tally.poeStandard;
  final name = standard == null ? 'PoE' : portPoeStandardShortLabel(standard);
  final budget = switch ((tally.poeWatts, tally.poeWattsUnknown)) {
    (0, final unknown) when unknown > 0 => 'watts unknown',
    (final watts, 0) => '$watts W',
    (final watts, final unknown) => '$watts W and $unknown unknown',
  };
  return '$head ($name x${tally.poePorts}, $budget)';
}

/// `PoE`, `PoE+`, `PoE++`: the names on a switch's own front panel.
///
/// SHORTER THAN [portPoeStandardLabel], and both exist on purpose. A
/// dropdown cell has room for `802.3at (PoE+)` and is read once while
/// choosing; a footer running along the bottom of a 68-row grid does not,
/// and is read at a glance.
String portPoeStandardShortLabel(PoeStandard value) => switch (value) {
  PoeStandard.af => 'PoE',
  PoeStandard.at => 'PoE+',
  PoeStandard.btType3 => 'PoE++',
  PoeStandard.btType4 => 'PoE++',
};
