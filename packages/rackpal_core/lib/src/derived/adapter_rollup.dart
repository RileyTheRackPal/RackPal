// T6.30's in-line adapters (DR-235 §11.234.3, `#1001`).
//
// ═══════════════════════════════════════════════════════════════════════
// DR-128 PROMISED THIS AND NOTHING BUILT IT
// ═══════════════════════════════════════════════════════════════════════
// DR-128 §11.127.2: "an adapter with no model reaches the BOM as an
// unspecified line". Until this file nothing in core or export read an
// adapter into any list a person buys from; the only readers of
// `Link.inlineAdapters` were the two tier-2 rules and the codec.
//
// THE SCHEDULE'S CABLES, so this table and the jumper table count over
// one set of rows: a cable the schedule does not list contributes no
// adapter here either. No lifecycle filter, for the same reason the jumper
// rollup has none: the sheet lists what the design holds, and the
// schedule's own lifecycle bands say which of it is new.
//
// AN UNSTATED MODEL IS ITS OWN LINE, never folded into a stated one with
// the same connectors (G4), and the section counts how many there are.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/inline_adapters.dart';
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One line: a quantity of one connector pair and one model.
@immutable
final class AdapterLine {
  const AdapterLine({
    required this.fromConnector,
    required this.toConnector,
    required this.connectors,
    required this.model,
    required this.quantity,
  });

  final ConnectorTypeId fromConnector;
  final ConnectorTypeId toConnector;

  /// `adapterConnectorsLabel`'s words: "Euroblock 3-pole to XLR3".
  final String connectors;

  /// Null when nobody has said what the part is.
  final String? model;

  final int quantity;
}

/// Every declared adapter on the schedule's cables, grouped.
@immutable
final class AdapterRollup {
  const AdapterRollup(this.lines);

  /// By connectors' words, then model (unstated last), then connector
  /// ids: a TOTAL order, so two builds of one document print one table.
  final List<AdapterLine> lines;

  /// How many adapters have no model stated.
  int get unstatedModelCount =>
      lines.where((l) => l.model == null).fold(0, (n, l) => n + l.quantity);

  bool get isEmpty => lines.isEmpty;
}

/// [schedule]'s cables' adapters, by connector pair and model.
AdapterRollup adapterRollupOf(Schedule schedule, RackDocument doc) {
  final counts = <(ConnectorTypeId, ConnectorTypeId, String?), int>{};
  for (final row in schedule.rows) {
    final link = doc.links[row.linkId];
    if (link == null) continue;
    for (final a in link.inlineAdapters) {
      final key = (a.fromConnector, a.toConnector, a.model);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final lines = <AdapterLine>[
    for (final MapEntry(key: (from, to, model), value: n) in counts.entries)
      AdapterLine(
        fromConnector: from,
        toConnector: to,
        connectors: connectorPairLabel(doc.registries, from, to),
        model: model,
        quantity: n,
      ),
  ]..sort(_byLine);
  return AdapterRollup(List<AdapterLine>.unmodifiable(lines));
}

int _byLine(AdapterLine a, AdapterLine b) {
  final byWords = a.connectors.compareTo(b.connectors);
  if (byWords != 0) return byWords;
  // Unstated last, then by the model's own words.
  if (a.model != b.model) {
    if (a.model == null) return 1;
    if (b.model == null) return -1;
    final byModel = a.model!.compareTo(b.model!);
    if (byModel != 0) return byModel;
  }
  final byFrom = a.fromConnector.v.compareTo(b.fromConnector.v);
  if (byFrom != 0) return byFrom;
  return a.toConnector.v.compareTo(b.toConnector.v);
}
