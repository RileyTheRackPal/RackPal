// How a declared in-line adapter is named to a person (DR-235, `#1001`).
//
// ONE SPELLING FOR EVERY SURFACE. The cable bar, T6.30's table and the
// schedule's notes all name an adapter by its two connectors, and three
// sites composing that sentence would be three chances to disagree about
// which end comes first or what an unknown connector prints as.
//
// AN UNKNOWN CONNECTOR PRINTS ITS ID, not a blank. The id is the fact the
// document holds; a blank would read as "no connector", which is a
// different and false claim (G4).
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// [id]'s display name in [registries], or the id when it has none.
String connectorName(Registries registries, ConnectorTypeId id) {
  final name = registries.connectorTypes[id]?.displayName.trim() ?? '';
  return name.isEmpty ? id.v : name;
}

/// "Euroblock 3-pole to XLR3": an adapter's two connectors, source side
/// first, as `DeclareInlineAdapterCommand` records them.
String connectorPairLabel(
  Registries registries,
  ConnectorTypeId from,
  ConnectorTypeId to,
) => '${connectorName(registries, from)} to ${connectorName(registries, to)}';

/// [connectorPairLabel] for [adapter].
String adapterConnectorsLabel(Registries registries, InlineAdapter adapter) =>
    connectorPairLabel(registries, adapter.fromConnector, adapter.toConnector);
