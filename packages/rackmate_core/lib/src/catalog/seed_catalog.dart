// The M1 seeded catalog (docs/09-roadmap.md M1 checklist #6,
// docs/catalog/seed-devices.md §3.10): 30 rack-side archetypes across
// eight categories plus 18 field devices, 48 templates total — matching
// the doc's own summary table exactly (P3: "the template count lives in
// exactly one place"). Every numeric field's provenance is recorded in
// `assets/catalog/sources.md` per AC-052 / DR-002 (generic archetypes,
// never real manufacturer SKUs).
//
// One representative configuration ships per template id — the eleven
// templates the doc marks parametric (V04, V06, V07, A01, N01, N03, P01,
// P03, X01, X02, X03) ship their most illustrative size/variant rather
// than every combination; picking a size in the palette/Device Builder is
// out of scope for this stage (M4).

import 'package:rackmate_core/src/catalog/catalog_audio.dart';
import 'package:rackmate_core/src/catalog/catalog_control.dart';
import 'package:rackmate_core/src/catalog/catalog_field.dart';
import 'package:rackmate_core/src/catalog/catalog_network.dart';
import 'package:rackmate_core/src/catalog/catalog_passive.dart';
import 'package:rackmate_core/src/catalog/catalog_power.dart';
import 'package:rackmate_core/src/catalog/catalog_rf.dart';
import 'package:rackmate_core/src/catalog/catalog_sources.dart';
import 'package:rackmate_core/src/catalog/catalog_video.dart';
import 'package:rackmate_core/src/model/template.dart';

export 'package:rackmate_core/src/catalog/catalog_audio.dart' show kCatAudio;
export 'package:rackmate_core/src/catalog/catalog_connectors.dart'
    show buildSeedConnectorFootprints, kFootprintExemptConnectors;
export 'package:rackmate_core/src/catalog/catalog_control.dart'
    show kCatControl;
export 'package:rackmate_core/src/catalog/catalog_field.dart' show kCatField;
export 'package:rackmate_core/src/catalog/catalog_network.dart'
    show kCatNetwork;
export 'package:rackmate_core/src/catalog/catalog_passive.dart'
    show kCatPassive;
export 'package:rackmate_core/src/catalog/catalog_power.dart' show kCatPower;
export 'package:rackmate_core/src/catalog/catalog_rf.dart' show kCatRf;
export 'package:rackmate_core/src/catalog/catalog_sources.dart'
    show kCatSources;
export 'package:rackmate_core/src/catalog/catalog_video.dart' show kCatVideo;
// Not a template catalog — the shop's seed cable-colour convention, here
// because it is the same kind of thing: pure seed data copied into a NEW
// document by its constructor and editable from that moment on.
export 'package:rackmate_core/src/catalog/jacket_color_convention.dart'
    show buildDefaultJacketColorConvention;

/// The category display order the palette groups by, matching
/// docs/catalog/seed-devices.md §3's section order.
const List<String> kCatalogCategoryOrder = [
  kCatVideo,
  kCatAudio,
  kCatNetwork,
  kCatControl,
  kCatSources,
  kCatRf,
  kCatPower,
  kCatPassive,
  kCatField,
];

/// Builds the full 48-template seed catalog, keyed by its stable catalog
/// id ("V01".."V07", "A01".."A06", ..., "F01".."F18" — the ids
/// docs/catalog/seed-devices.md §3 itself uses). Each key is used
/// verbatim as the `TemplateId` so a device placed from the palette
/// resolves to `"$id@1"` in `RackDocument.templates`.
Map<String, TemplateBody> buildSeedCatalog() => {
  ...buildVideoCatalog(),
  ...buildAudioCatalog(),
  ...buildNetworkCatalog(),
  ...buildControlCatalog(),
  ...buildSourcesCatalog(),
  ...buildRfCatalog(),
  ...buildPowerCatalog(),
  ...buildPassiveCatalog(),
  ...buildFieldCatalog(),
};
