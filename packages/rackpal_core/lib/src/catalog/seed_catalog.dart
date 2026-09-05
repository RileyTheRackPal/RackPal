// The M1 seeded catalog (docs/09-roadmap.md M1 checklist #6,
// docs/catalog/seed-devices.md §3.10): 30 rack-side archetypes across
// eight categories plus 19 field devices, 49 templates total — matching
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

import 'dart:collection';

import 'package:rackpal_core/src/catalog/catalog_audio.dart';
import 'package:rackpal_core/src/catalog/catalog_control.dart';
import 'package:rackpal_core/src/catalog/catalog_field.dart';
import 'package:rackpal_core/src/catalog/catalog_network.dart';
import 'package:rackpal_core/src/catalog/catalog_passive.dart';
import 'package:rackpal_core/src/catalog/catalog_power.dart';
import 'package:rackpal_core/src/catalog/catalog_rf.dart';
import 'package:rackpal_core/src/catalog/catalog_sources.dart';
import 'package:rackpal_core/src/catalog/catalog_video.dart';
import 'package:rackpal_core/src/model/template.dart';

export 'package:rackpal_core/src/catalog/catalog_audio.dart' show kCatAudio;
export 'package:rackpal_core/src/catalog/catalog_connectors.dart'
    show buildSeedConnectorFootprints, kFootprintExemptConnectors;
export 'package:rackpal_core/src/catalog/catalog_control.dart' show kCatControl;
export 'package:rackpal_core/src/catalog/catalog_field.dart' show kCatField;
export 'package:rackpal_core/src/catalog/catalog_network.dart' show kCatNetwork;
export 'package:rackpal_core/src/catalog/catalog_passive.dart' show kCatPassive;
export 'package:rackpal_core/src/catalog/catalog_power.dart' show kCatPower;
export 'package:rackpal_core/src/catalog/catalog_rf.dart' show kCatRf;
export 'package:rackpal_core/src/catalog/catalog_sources.dart' show kCatSources;
export 'package:rackpal_core/src/catalog/catalog_video.dart' show kCatVideo;
// Not a template catalog — the shop's seed cable-colour convention, here
// because it is the same kind of thing: pure seed data copied into a NEW
// document by its constructor and editable from that moment on.
export 'package:rackpal_core/src/catalog/jacket_color_convention.dart'
    show buildDefaultJacketColorConvention;
// Likewise: canon §6.5's 38 media types (M3-C/6), on the same contract.
export 'package:rackpal_core/src/catalog/seed_media_types.dart'
    show buildSeedMediaTypes;
// Likewise: CR-108's six outlet templates and the three TIA-570-D grade
// presets (M3-C/4).
export 'package:rackpal_core/src/catalog/seed_outlet_templates.dart'
    show buildSeedOutletTemplates;
// Likewise: the 8 signal domains and 56 signal families (DR-010 §11.10).
// Same contract again — seeded into a new document at CREATION, ordinary
// stored data from that line onward, and NEVER recomputed at save.
export 'package:rackpal_core/src/catalog/seed_registries.dart'
    show buildSeedRegistries, buildSeedSignalDomains, buildSeedSignalFamilies;

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
/// verbatim as the `TemplateId`, and a document's constructor writes each
/// one into `RackDocument.templates` at version 1.
///
/// **THE PALETTE LISTS THE DOCUMENT, NOT THIS** (DR-077 §11.76.1). This
/// used to end "so a device placed from the palette resolves to
/// `"$id@1"`", which was true of a seed and false of everything else: a
/// template authored in the Device Builder is in the document and in no
/// catalog, and pinning `@1` made a second version unplaceable. Placement
/// resolves the newest version of an id through
/// `derived/placeable_templates.dart`.
/// The ids [buildSeedCatalog] ships, as a set.
///
/// **The one place "did this build ship this id" is answered**
/// (`derived/placeable_templates.dart`, DR-077 §11.76.1). Derived from
/// the catalog rather than written out beside it, because a hand-kept
/// second list of 48 strings is a list that drifts, and the drift would
/// show up as a template badged as somebody's own work.
///
/// Lazily initialised, so the 49 templates are built once per isolate
/// rather than once per palette rebuild, and unmodifiable for the same
/// reason `buildRackPresets` copies: a caller must not be able to teach
/// this build that it ships a template it does not.
final Set<String> kSeedCatalogIds = UnmodifiableSetView(
  buildSeedCatalog().keys.toSet(),
);

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
