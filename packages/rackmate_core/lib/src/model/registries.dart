import 'package:rackmate_core/src/model/link.dart' show JacketRating;
import 'package:rackmate_core/src/model/outlet.dart' show OutletTemplate;
import 'package:rackmate_core/src/model/template.dart'
    show PortDirection, PortTopology;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/rgb.dart';

// The three orthogonal axes (docs/02-data-model.md §4.9): a connector, a
// medium and a signal family are three different concepts that must never
// collide on one enum (CR-008, §6.1). This file defines the Dart types
// only; the CONTENT is seeded in `catalog/` beside the template catalog.
//
// THIS COMMENT USED TO SAY the content "is catalog data shipped as
// assets/catalog/registries.json at M1". IT NEVER WAS. No such file has
// ever existed, it was declared in no pubspec, and the types below were
// constructed nowhere but the decoder — so every document ever written
// carried six EMPTY registry maps, and the first code to read one
// (`derived/schedule.dart`, M2-B) resolved nothing in any project.
//
// DR-010 (§11.10) settles it the other way: the master is a SEEDED DART
// CATALOG, because `rackmate_core` imports no Flutter and therefore
// cannot load an asset at all. `docs/02-data-model.md:834` is amended by
// that ruling. `tools/pal1_check.py` remains the single authority for the
// palette itself and the seed is gated against it.

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
/// The corpus field list runs to some twenty entries (`typicalMedia`,
/// `acceptedFamilies`, `maxRunLengthPassive`, `nominalImpedanceOhms`,
/// `requiresTermination`, `carriesPower`, …) and those stay absent by
/// DR-010 §11.10.4: only the fields AC-054's render actually needs are
/// added, and the rest arrive when something needs them.
///
/// THE THREE FIELDS DR-010 §11.10.3 ADDED, AND WHY.
/// CR-078 moved COLOUR from the family to the domain — correctly, since
/// "no palette is CVD-safe past ~9 categories" — but the model built
/// from that reading kept neither `shortTag` nor a dash nor a weight, and
/// that made AC-054 unimplementable: docs/catalog/seed-devices.md §4.4
/// gives every family its own dash and weight, so without the override
/// channel ALL EIGHT DIGITAL-VIDEO FAMILIES DRAW AS ONE IDENTICAL SOLID
/// LINE and the dash channel — the one of CR-078's four that survives
/// greyscale and a photocopy — carries nothing. CR-078 is narrowed, not
/// reversed: hue stays on the domain.
final class SignalFamilyDef {
  const SignalFamilyDef({
    required this.id,
    required this.displayName,
    required this.domain,
    required this.defaultConnector,
    required this.defaultDirection,
    required this.defaultTopology,
    this.aliases = const [],
    this.shortTag,
    this.dashOverride,
    this.lineWeightPermilleOverride,
  });

  final SignalFamilyId id;
  final String displayName;
  final SignalDomainId domain;
  final ConnectorTypeId defaultConnector;
  final PortDirection defaultDirection;
  final PortTopology defaultTopology;
  final List<String> aliases;

  /// The tag pill's type token — `HD20`, `SPK`, `232` (§4.4's `Tag`
  /// column). The schedule's `TYPE` cell wants "domain tag + family
  /// `shortTag`" (docs/08-pdf-export.md §3.2) and had to print
  /// `displayName` instead because this field did not exist; see the
  /// "what is deliberately not derived" note in `derived/schedule.dart`.
  ///
  /// NULLABLE, and null means UNKNOWN rather than empty (G4, CR-114): a
  /// family decoded from a document written before this key existed has
  /// no tag, and a caller must fall back rather than print `''`.
  final String? shortTag;

  /// The type-within-domain dash, in permille-points like
  /// [SignalDomainDef.dashPattern]. Null inherits the domain's base dash.
  ///
  /// NULL AND EMPTY ARE DIFFERENT AND BOTH OCCUR. `null` is "inherit";
  /// the EMPTY LIST is an explicit override to *solid*, which
  /// `audio.line_bal` really does declare inside the dashed
  /// `audio.analog` domain (§4.4: "This is the one place a `dashOverride`
  /// reaches for `solid` inside a dashed domain"). A non-nullable
  /// `List<int>` defaulting to `const []` could not express the
  /// difference and would silently redraw every inheriting family solid.
  final List<int>? dashOverride;

  /// The type-within-domain line weight, permille of the base signal
  /// weight (`1000` = 1×). Null inherits the domain's base weight.
  ///
  /// Load-bearing on its own, not a garnish: HDMI 1.4/2.0/2.1 are all
  /// solid and separate ONLY here (750 / 1000 / 1250), and PAL-1's limb
  /// (b) rescues a shared dash class only at a ratio ≥ 1.4.
  final int? lineWeightPermilleOverride;

  /// The dash this family actually draws, given its resolved [domain].
  ///
  /// The fallback rule lives here rather than at each call site because
  /// PAL-1 is stated over EFFECTIVE values — "after any override, not
  /// the domain base value" — and a renderer that reads `dashOverride`
  /// directly draws the domain's families all alike. `tools/
  /// registry_parity.py` checks the seed through exactly this rule.
  List<int> effectiveDashPattern(SignalDomainDef resolvedDomain) =>
      dashOverride ?? resolvedDomain.dashPattern;

  /// The line weight this family actually draws at. See
  /// [effectiveDashPattern] for why the rule is here.
  int effectiveLineWeightPermille(SignalDomainDef resolvedDomain) =>
      lineWeightPermilleOverride ?? resolvedDomain.lineWeightPermille;
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
/// M0 MINIMAL SHAPE, PLUS TWO. Canon §6.5 names fifteen fields; five
/// shipped at M0 and `shortTag`/`aliases` are added here by DR-010
/// §11.10.4's rule, which is to add what something needs and keep the
/// rest out. Both are what a media token resolves THROUGH, and the two
/// paths that resolve one are docs/07 §4.3's drop DSL (`4x Cat6`) and
/// §5.1's CSV `media` column. The remaining eight (`conductorCount`,
/// `pairCount`, `gaugeAwg`, `impedanceOhms`, `shielded`,
/// `minBendRadius`, `outerDiameter`, `supports`, `isPathwayOnly`) stay
/// out until something reads them; `isPathwayOnly` is CR-109's and
/// belongs with the matrix's EMT column.
final class MediaTypeDef {
  const MediaTypeDef({
    required this.id,
    required this.displayName,
    this.shortTag,
    this.aliases = const [],
    this.maxRunLengthPassive,
    this.maxRunLengthActive,
    this.jacketOptions = const [],
  });

  final MediaTypeId id;
  final String displayName;

  /// Canon §6.5's `Tag` column — `C6`, `RG6`, `16/4`. The trade name an
  /// installer writes on a pull list, and what a schedule prints when it
  /// has no room for `displayName`.
  ///
  /// NULLABLE, and null means UNKNOWN rather than empty, exactly as
  /// [SignalFamilyDef.shortTag] is (G4, CR-114): a media type decoded
  /// from a document written before this key existed has no tag, and a
  /// caller must fall back rather than print `''`.
  final String? shortTag;

  /// The trade spellings that resolve to this id — docs/07 §5.1's
  /// synonym block, `cat6 / cat-6 / c6 / cat6 utp → media.cat6`.
  ///
  /// Same role for a media token that [ConnectorTypeDef.aliases] has for
  /// a port head token (CR-058), and the same rule applies: an alias is
  /// for typing speed and **the file never stores one** on a `Link` —
  /// `Link.media` always holds the resolved `media.*` id. What the file
  /// stores is this table, so that a document carrying a user-created
  /// media type (RJ-009) still resolves its own synonyms on reopen.
  final List<String> aliases;

  /// The declared maximum for this medium, and **the field DR-020
  /// §11.19.2(4) calls "a new `maxLength` on the media registry"**. It is
  /// neither new nor called that; canon §11.19.7 is the census, and
  /// M3-C/6 seeded it at `acd63d5`.
  ///
  /// `LEN-002` READS THIS ONE. Seven of the 38 shipped types declare a
  /// length and thirty-one are deliberately null, because canon §6.5's
  /// `Max channel` column is hedged prose (`~150 m`, `100 m+`, `hundreds
  /// of feet`) and G4 forbids rounding a hedge into a figure an installer
  /// buys cable from. The rule is therefore SILENT on the thirty-one and
  /// counts them; it must not read null as zero or as infinity.
  final Len? maxRunLengthPassive;

  /// NULL ON ALL 38, and gated as such in `seed_media_types_test.dart`:
  /// canon §6.5 has one `Max channel` column, and this is a separate M0
  /// field with no source column to fill it from.
  ///
  /// `LEN-002` MUST NOT READ THIS ONE. A rule written against it would
  /// compile, pass its own AC-051 fixture pair if the fixture set the
  /// field, and never fire on a real document. Silent non-firing is the
  /// worst failure mode a validation rule has, which is why canon
  /// §11.19.7 rules the choice rather than leaving it to be discovered.
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
