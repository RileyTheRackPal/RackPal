import 'package:rackmate_core/src/model/link.dart' show JacketRating;
import 'package:rackmate_core/src/model/outlet.dart' show OutletTemplate;
import 'package:rackmate_core/src/model/template.dart'
    show PortDirection, PortTopology;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/rgb.dart';

// The three orthogonal axes (docs/02-data-model.md §4.9): a connector, a
// medium and a signal family are three different concepts that must never
// collide on one enum (CR-008, §6.1). Full registry CONTENT is catalog
// data shipped as assets/catalog/registries.json at M1 — this file only
// defines the Dart types that content deserializes into.

/// The visual language for one of the 8 fixed signal domains (CR-078):
/// colour encodes domain, dash/weight/glyph encode type-within-domain.
final class SignalDomainDef {
  const SignalDomainDef({
    required this.id,
    required this.displayName,
    required this.tagPrefix,
    required this.color,
    required this.colorDark,
    required this.dashPattern,
    required this.lineWeightPermille,
    required this.glyph,
    required this.glyphAlt,
  });

  final SignalDomainId id;
  final String displayName;
  final String tagPrefix;
  final Rgb color;
  final Rgb colorDark;

  /// Permille-points so the file stays integral, e.g. `6,3` is
  /// `[6000, 3000]` (CR-079).
  final List<int> dashPattern;
  final int lineWeightPermille;
  final String glyph;
  final String glyphAlt;
}

/// What a signal *is*: what it requires and what it may mate with.
/// Catalog-updated, not user-extensible in v1 (RJ-012).
///
/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.9.
/// Field list per this package's governing instructions.
final class SignalFamilyDef {
  const SignalFamilyDef({
    required this.id,
    required this.displayName,
    required this.domain,
    required this.defaultConnector,
    required this.defaultDirection,
    required this.defaultTopology,
    this.aliases = const [],
  });

  final SignalFamilyId id;
  final String displayName;
  final SignalDomainId domain;
  final ConnectorTypeId defaultConnector;
  final PortDirection defaultDirection;
  final PortTopology defaultTopology;
  final List<String> aliases;
}

/// What plugs into what, and whether gender applies. Aliases only,
/// user-extensible (CR-058).
///
/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.9.
///
/// [footprintWidth]/[footprintHeight] are the rectangular panel-cutout
/// footprint this connector needs on a rear panel, added for the M1 catalog
/// stage's "zero-authoring correct rear panel" claim (docs/catalog/seed-
/// devices.md §5, AC-050/A2.2): "every connector referenced by a shipped
/// template has a footprint entry, asserted in CI". Both null means no
/// footprint has been authored yet — never estimated (G4) — and a shipped
/// catalog template must not reference such a connector; see
/// `seed_catalog_test.dart`'s connector-footprint assertion.
final class ConnectorTypeDef {
  const ConnectorTypeDef({
    required this.id,
    required this.displayName,
    this.aliases = const [],
    this.footprintWidth,
    this.footprintHeight,
  });

  final ConnectorTypeId id;
  final String displayName;
  final List<String> aliases;
  final Len? footprintWidth;
  final Len? footprintHeight;
}

/// What cable is pulled, how long it may run, what jacket it takes.
/// User-extensible via CSV import (RJ-009).
///
/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.9.
final class MediaTypeDef {
  const MediaTypeDef({
    required this.id,
    required this.displayName,
    this.maxRunLengthPassive,
    this.maxRunLengthActive,
    this.jacketOptions = const [],
  });

  final MediaTypeId id;
  final String displayName;
  final Len? maxRunLengthPassive;
  final Len? maxRunLengthActive;
  final List<JacketRating> jacketOptions;
}

/// Which manufacturer part number a cable is. Optional throughout,
/// user-extensible.
///
/// M0 MINIMAL SHAPE: field list per this package's governing
/// instructions (`{id, manufacturer, partNumber, mediaTypeId}`).
final class CableSpecDef {
  const CableSpecDef({
    required this.id,
    required this.manufacturer,
    required this.partNumber,
    required this.mediaTypeId,
  });

  final String id;
  final String manufacturer;
  final String partNumber;
  final MediaTypeId mediaTypeId;
}

/// The container for all catalog/reference data a document embeds a
/// referenced subset of, which is what makes a `.rackmate` file
/// self-describing. Loaded and CSV-imported outside the document command
/// stack (docs/03-architecture.md §5.6: library operations are not
/// undoable), so its maps are plain mutable collections rather than
/// `@internal`-guarded.
final class Registries {
  Registries({
    Map<SignalDomainId, SignalDomainDef>? signalDomains,
    Map<SignalFamilyId, SignalFamilyDef>? signalFamilies,
    Map<ConnectorTypeId, ConnectorTypeDef>? connectorTypes,
    Map<MediaTypeId, MediaTypeDef>? mediaTypes,
    Map<String, CableSpecDef>? cableSpecs,
    Map<String, OutletTemplate>? outletTemplates,
  }) : signalDomains = signalDomains ?? {},
       signalFamilies = signalFamilies ?? {},
       connectorTypes = connectorTypes ?? {},
       mediaTypes = mediaTypes ?? {},
       cableSpecs = cableSpecs ?? {},
       outletTemplates = outletTemplates ?? {};

  final Map<SignalDomainId, SignalDomainDef> signalDomains;
  final Map<SignalFamilyId, SignalFamilyDef> signalFamilies;
  final Map<ConnectorTypeId, ConnectorTypeDef> connectorTypes;
  final Map<MediaTypeId, MediaTypeDef> mediaTypes;
  final Map<String, CableSpecDef> cableSpecs;
  final Map<String, OutletTemplate> outletTemplates;
}
