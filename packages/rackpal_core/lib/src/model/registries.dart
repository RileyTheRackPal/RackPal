import 'package:rackpal_core/src/model/link.dart' show JacketListing;
import 'package:rackpal_core/src/model/outlet.dart' show OutletTemplate;
import 'package:rackpal_core/src/model/template.dart'
    show PortDirection, PortTopology;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/rgb.dart';

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
// CATALOG, because `rackpal_core` imports no Flutter and therefore
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
    this.glyphOverride,
    this.clonedFrom,
  });

  final SignalFamilyId id;
  final String displayName;

  /// The family this one was cloned from (DR-122, SFE-C3), or null for a
  /// family that ships.
  ///
  /// **PROVENANCE, AND NOTHING READS IT AS A RULE.** It is what lets a
  /// picker say *"clone of Cresnet"* at the point of use, because the
  /// parent is what a person needs to reason about the direction and
  /// topology the clone inherited (DR-244 §11.243.3). Null and absent on
  /// the wire for every shipped family, so a document written before this
  /// field re-encodes byte-for-byte.
  ///
  /// It names the parent's ID, which may not resolve: a clone carried to a
  /// project that does not hold its parent still says what it came from,
  /// and a reader falls back to the bare id rather than to nothing.
  final SignalFamilyId? clonedFrom;
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

  /// The type-within-domain SHAPE (DR-181 §11.180.2). Null inherits the
  /// domain's native [SignalDomainDef.glyph].
  ///
  /// THE FOURTH RENDER FIELD, AND DR-010 §11.10.4 KEPT IT OUT ON PURPOSE.
  /// That ruling added three and said the rest arrive when something needs
  /// them; what needed this is `#82`'s measurement. §4.4 gives every
  /// family a glyph and §4.3 gives each domain a native one and one or two
  /// more, so **26 of the 57 seeded families drew a shape the catalogue
  /// does not give them**: every family whose §4.4 glyph is another of its
  /// domain's shapes was drawn with the native one.
  ///
  /// THE REASON IS THE GREYSCALE PRINT. Shape is one of the channels that
  /// survives it (docs/05 §6.1), and a constant-voltage speaker line is
  /// not interchangeable with a low-impedance one.
  ///
  /// A `String` AND NOT AN ENUM, like the domain's two: a glyph is a
  /// codepoint the catalogue authors, and `family_glyph.dart` maps the
  /// ones it can draw to geometry and falls back to a measured text run
  /// for any it cannot. An enum here would make a registry entry a code
  /// change.
  final String? glyphOverride;

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

  /// The glyph this family actually draws. See [effectiveDashPattern] for
  /// why the rule lives here rather than at each call site.
  ///
  /// THE DOMAIN'S NATIVE GLYPH IS THE FALLBACK AND `glyphAlt` IS NEVER IT.
  /// Which of a domain's alternates a family takes is exactly the fact
  /// [glyphOverride] exists to state, and picking one by rule is the
  /// heuristic `signal_style.dart`'s header shows failing against docs/05
  /// §6.4's own table three different ways.
  String effectiveGlyph(SignalDomainDef resolvedDomain) =>
      glyphOverride ?? resolvedDomain.glyph;
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
/// **[pitch] and [genderApplies] ARRIVED AT M4-B**, both documented since
/// M0 and declared by neither the Dart nor the codec until then;
/// `json_codec.dart`'s registry-drift note listed `genderApplies` among
/// fields the corpus showed and this class never had.
final class ConnectorTypeDef {
  const ConnectorTypeDef({
    required this.id,
    required this.displayName,
    this.aliases = const [],
    this.footprintWidth,
    this.footprintHeight,
    this.pitch,
    this.genderApplies = false,
    this.matesWith = const [],
  });

  final ConnectorTypeId id;
  final String displayName;
  final List<String> aliases;
  final Len? footprintWidth;
  final Len? footprintHeight;

  /// Centre-to-centre spacing for a ROW of these connectors, which is
  /// docs/06 §5's auto-layout step 2, *flow left → right at
  /// `ConnectorTypeDef.pitch`*. Step 2 could not be written before this
  /// field existed, which is why M4-B runs ahead of the panel layer.
  ///
  /// **NOT derivable from [footprintWidth], and the corpus's own table
  /// proves it.** Most of docs/catalog/seed-devices.md §5.2's stated
  /// pitches sit 2 to 4 mm above the footprint, which looks like a
  /// uniform clearance until `conn.binding_post`, whose pitch of 20 mm is
  /// BELOW its 24 mm pair footprint because 20 mm is the ¾ inch centre
  /// spacing binding posts are actually built on. A derived pitch would
  /// have to invent that, and inventing it is what draws a rear panel
  /// wrong to scale on the one view that gets taped inside the rack door
  /// (AC-032).
  ///
  /// **NULL IS UNKNOWN AND MOST CONNECTORS ARE NULL** (G4), permanently
  /// (DR-057 §11.56.3). §5.2 states a pitch for fourteen ids and six more
  /// inherit one from a connector sharing their shell; the remaining
  /// twenty-nine have no stated pitch anywhere in the corpus and are not
  /// going to acquire an invented one.
  ///
  /// **AN ABSENT PITCH DOES NOT DISABLE AUTO-LAYOUT** (DR-057 §11.56.4).
  /// CR-071 rules that panel geometry is *"auto-laid-out from connector
  /// footprints"*, and docs/catalog §5.2's own intro says the layout
  /// *"needs a real footprint per connector"*. Neither names a pitch. The
  /// algorithm advances by `pitch ?? (footprintWidth + gutter)`: where
  /// the corpus states a real centre spacing this field supplies it,
  /// because it carries physical facts a formula cannot reach, and
  /// everywhere else the footprint does the work.
  ///
  /// So this is a REFINEMENT, not a prerequisite. Reading it as a
  /// prerequisite is a mistake made once already, from docs/06 §5's
  /// pseudocode rather than from the ruling, and it priced a feature cut
  /// that did not exist.
  final Len? pitch;

  /// Whether gender is a real distinction for this connector, and
  /// therefore whether `CON-002` ("both ends male or both ends female")
  /// evaluates and whether the schematic glyph's fill encodes gender
  /// (CR-059, canon §6.3).
  ///
  /// **A `bool` and not a `bool?`, which is a deliberate departure from
  /// this file's usual G4 shape.** CR-059 specifies `bool` in terms, and
  /// canon §6.3 authors the value for every connector the catalog ships,
  /// so there is no unknown to represent in the seed. `false` is also the
  /// safe default for the one thing that reads it: a validation rule that
  /// declines to fire costs a missed finding, and one that fires wrongly
  /// costs a false positive, which is the failure M5's whole
  /// known-good-near-miss design is built to avoid.
  ///
  /// A user-authored connector type (M4-P) therefore arrives with gender
  /// not applying until somebody says otherwise.
  final bool genderApplies;

  /// The connector ids this one physically mates with (`CON-001`, `#255`).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// EMPTY IS UNKNOWN, AND `CON-001` SKIPS IT (G4)
  /// ═══════════════════════════════════════════════════════════════════
  /// A rule that fired on an empty list would report a mating failure for
  /// every connector nobody has got to yet, which is a false FAIL on a
  /// half-seeded table. `CODE-002` already sets the precedent in the
  /// other direction: a jacket listing from an article the product cannot
  /// read is *unknown and skips* rather than passing or failing. Silence
  /// on an unknown is the only honest answer either way.
  ///
  /// It carries the same meaning for `conn.unterminated` and
  /// `conn.hardwired`, deliberately: there is no connector there to mate,
  /// so there is nothing for the rule to say. One representation serves
  /// both because the behaviour is the same, and inventing a
  /// "mates with everything" list would assert something false to make a
  /// predicate simpler.
  ///
  /// PHYSICAL MATING ONLY. `conn.bnc50` mates `conn.bnc75` and
  /// `conn.rca` mates `conn.rca75`: they share a shell and they go
  /// together. The impedance mismatch is a different fact and belongs to
  /// a different rule with its own id and severity, which v1 does not
  /// ship. `CON-001` answering "these do not mate" for a 50-into-75 joint
  /// would name the wrong defect and offer an adapter that does not fix
  /// it.
  ///
  /// SYMMETRIC, and a test holds it: if `A` lists `B` then `B` lists `A`.
  /// Plug and receptacle each name their counterpart, so the pairing is
  /// discoverable from whichever end a gesture starts at, and `CON-001`
  /// cannot decide differently depending on drag direction.
  final List<ConnectorTypeId> matesWith;
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
/// `minBendRadius`, `outerDiameter`, `supports`) stay out until
/// something reads them.
///
/// **`isPathwayOnly` HAS ARRIVED** (M3-E/1). It was held out for one
/// reason and that reason is gone: the flag's whole purpose is that such
/// a media type creates a `Pathway` instead of a `Link`, and until
/// M3-E/4 (`bcb1b31`) NOTHING IN THIS PRODUCT COULD CREATE A `Pathway`
/// AT ALL. Seeding it earlier would have marked three types with a fact
/// no code could act on.
final class MediaTypeDef {
  const MediaTypeDef({
    required this.id,
    required this.displayName,
    this.shortTag,
    this.aliases = const [],
    this.maxRunLengthPassive,
    this.maxRunLengthActive,
    this.jacketOptions = const [],
    this.isPathwayOnly = false,
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
  final List<JacketListing> jacketOptions;

  /// CR-109: **conduit is not a cable.** A medium with this set creates a
  /// `Pathway`, never a `Link` and never a `Port`.
  ///
  /// THREE OF THE 38 CARRY IT: `media.conduit_emt`, `media.conduit_ent`
  /// and `media.pull_string`, which is what canon §6.5 marks. docs/07
  /// §1 states the consequence in the trade's own terms: *"you still
  /// pull the smurf tube and it still costs money"*, so it appears in
  /// the drop table and on the Pull Sheet, and it **never appears in the
  /// netlist**.
  ///
  /// THE REJECTED ALTERNATIVE IS WHY THE FLAG EXISTS. CR-109 records it:
  /// conduit as a connectable drop like any other, *"which produces a
  /// port you can wire an HDMI cable into"*. A `bool` on the medium is
  /// what stops that at the point a drop line is planned rather than by
  /// a rule that would have to refuse it afterwards.
  ///
  /// NOT NULLABLE, and this is not a G4 lapse: `false` is the answer for
  /// every cable, which is 35 of the 38 and every user-created medium
  /// under RJ-009. There is no "nobody has said" state for whether a
  /// thing is a conduit.
  final bool isPathwayOnly;
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
/// referenced subset of, which is what makes a `.rppj` file
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
