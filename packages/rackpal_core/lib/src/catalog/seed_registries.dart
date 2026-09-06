// THE SEEDED SIGNAL REGISTRIES — the 8 domains and 57 families of
// docs/catalog/seed-devices.md §4.3/§4.4 (= canon §6.2.5/§6.4).
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS AT ALL
// ═════════════════════════════════════════════════════════════════════
// `registries.dart` used to say the content "is catalog data shipped as
// assets/catalog/registries.json at M1". IT NEVER WAS. No such file has
// ever existed, it was declared in no pubspec, and `SignalDomainDef`/
// `SignalFamilyDef` were constructed nowhere but the decoder — so every
// document ever written carried SIX EMPTY REGISTRY MAPS. M2-B was the
// first code in the repository to read `doc.registries` and it resolved
// nothing, in every starter and every fixture. This file is the hole.
//
// DR-010 §11.10.1 settles the master as SEEDED DART rather than a JSON
// asset, and the reason is structural, not stylistic: `rackpal_core`
// imports no Flutter, so it cannot load an asset at all (`rootBundle` is
// Flutter-only). A JSON master would have to be loaded by the app layer
// and injected through two packages, because `rackpal_export` drives
// core directly and may never import `rackpal_ui`. A seeded Dart
// catalog needs no seam, works unchanged in core's pure-Dart tests, and
// is what this repository already does four times over — 50 templates
// (`seed_catalog.dart`), connector footprints (`catalog_connectors
// .dart`), jacket-colour conventions, rack presets.
//
// ═════════════════════════════════════════════════════════════════════
// THIS IS A FOURTH COPY OF THE PALETTE, AND IT IS GATED LIKE ONE
// ═════════════════════════════════════════════════════════════════════
// `tools/pal1_check.py` REMAINS THE SINGLE AUTHORITY (DR-010 §11.10.1,
// §4.2). Hand-authoring 8 domains and 57 families into Dart creates a
// fourth copy of data that already exists in three places, and doc-vs-
// authority drift is precisely the failure `tools/palette_parity.py` was
// written to catch after — in its own words — it "shipped four times".
//
// So `tools/registry_parity.py` gates THIS FILE against that authority
// on domain hue, family domain, effective dash and effective weight, and
// runs in CI beside `palette_parity.py`. That tool proves the DOCS agree
// with the authority; the new one proves the CODE does. If you change a
// dash, a weight or a hex here, change `pal1_check.py` in the same
// commit and run both — the values below were NOT arrived at by reading
// a table, and neither is their correctness.
//
// ═════════════════════════════════════════════════════════════════════
// ENCODING: PERMILLE-POINTS AND PERMILLE WEIGHTS (CR-079)
// ═════════════════════════════════════════════════════════════════════
// Dash patterns are points (1/72 in) stored as `List<int>` of PERMILLE-
// points so the file stays integral and no persisted length is a float
// (CR-001, CR-003): `6,3` is `[6000, 3000]`, `1.5,3` is `[1500, 3000]`,
// and `solid` is the EMPTY LIST. Line weight is permille of the base
// signal weight: `1000` = 1.00×, `750` = 0.75×, `1500` = 1.50×.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IS DELIBERATELY ABSENT, SO IT READS AS A GAP AND NOT AN OVERSIGHT
// ═════════════════════════════════════════════════════════════════════
//  * `Registries.cableSpecs` STAYS EMPTY. Real shipped content in §6,
//    but out of DR-010's scope, and inventing it here to make the map
//    look populated is the fabrication G4 forbids. It is still empty;
//    that is the truth. TWO IDS HAVE LEFT THIS LIST: `.mediaTypes` to
//    M3-C/6, because the drop DSL (docs/07 §4.3, `4x Cat6`) has to
//    resolve a media name against something, and `.outletTemplates` to
//    M3-C/4, because seventeen outlets in the whole-house starter name
//    ids that resolved to nothing. Both were seeded once something
//    needed them, which is DR-010 §11.10.4's rule working.
//  * `SignalFamilyDef.aliases` WAS empty on all 55, and this bullet used
//    to explain why: it is the Quick Add DSL's resolution table (CR-058)
//    and nothing in the build resolved an alias, so populating it would
//    have shipped rows no code read and no gate checked. **DR-060
//    §11.59 is the something that needed it** — the same DR-010 §11.10.4
//    rule that moved `.mediaTypes` and `.outletTemplates` out of this
//    list. `resolveSignalFamilyToken` now reads them and
//    `signal_family_alias_test.dart` gates them.
//
//    THE SET IS SPARSE ON PURPOSE and the reason is not restraint for
//    its own sake: that resolver already reaches a family by `shortTag`,
//    by the id's own tail and by `displayName`, so most trade spellings
//    ALREADY LANDED and an entry here would be a second way to say what
//    one already says. `hdbaset`, `hbt`, `dante`, `ethernet` and `avoip`
//    have no alias for exactly that reason. See `_family`'s docstring.
//  * NO `glyphOverride`, and no per-family glyph. DR-010 §11.10.3 adds
//    exactly `shortTag`, `dashOverride` and a weight override; §11.10.4
//    keeps the rest of the ~20-field corpus shape out. §4.4's per-family
//    Glyph column is therefore CARRIED BY THE DOMAIN ONLY — see the note
//    on the three-glyph domains below.
//  * `topologyFree` (AC-030's registry field, set on `ctl.cresnet`,
//    `ctl.lutron_qs`, `ctl.dali`, `ctl.knx`) is not on the Dart class.
//    Owed, and named here so the four families are findable when it
//    lands.

import 'package:rackpal_core/src/catalog/catalog_connectors.dart';
import 'package:rackpal_core/src/catalog/seed_media_types.dart';
import 'package:rackpal_core/src/catalog/seed_outlet_templates.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart'
    show PortDirection, PortTopology;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/rgb.dart';

// ─────────────────────────────────────────────────────────────────────
// DOMAINS
// ─────────────────────────────────────────────────────────────────────

/// One §4.3 row. Positional and in the table's own column order so a
/// reader can diff the two side by side, and so `tools/registry_parity
/// .py` can read the call without a Dart parser.
///
/// Hexes are the doc's own `#RRGGBB` strings rather than `Rgb(r, g, b)`
/// triples: the authority (`pal1_check.py`'s `DOMAIN_HUE`) is a hex map,
/// the WCAG luminances in §4.3 are recomputed from these exact strings,
/// and a transcription error is visible at a glance in this form and
/// invisible in decimal.
SignalDomainDef _domain(
  String id,
  String displayName,
  String tagPrefix,
  String light,
  String dark,
  List<int> dash,
  int weight,
  String glyph,
  String glyphAlt,
) => SignalDomainDef(
  id: SignalDomainId(id),
  displayName: displayName,
  tagPrefix: tagPrefix,
  color: Rgb.fromHex(light),
  colorDark: Rgb.fromHex(dark),
  dashPattern: dash,
  lineWeightPermille: weight,
  glyph: glyph,
  glyphAlt: glyphAlt,
);

/// The eight fixed signal domains (§4.3 / canon §6.2.5 — the two tables
/// were cross-checked row by row and agree exactly).
///
/// EIGHT, NOT NINE. §4.3's table carries a ninth *(reserved)* row for
/// selection/focus yellow `#F0E442`, and it is deliberately NOT a domain
/// here: PAL-2 says that hue "is reserved for selection and focus and is
/// never a cable". Seeding it would put a ninth swatch in the legend and
/// a ninth entry in the domain filter bar for something no `Service` can
/// ever resolve to.
///
/// THE DARK HEX IS NOT A COMPUTED TINT. Only hue moves between themes;
/// dash, weight, glyph and tag are identical across them, and the theme
/// is a UI preference never persisted in a document. `pwr` INVERTS —
/// `#000000` light, `#E8E8E8` dark — because black is invisible on dark,
/// which is why the pair is stored rather than derived.
///
/// THE THREE-GLYPH DOMAINS LOSE THEIR THIRD SHAPE HERE, and it is worth
/// saying out loud: `SignalDomainDef` carries `glyph`/`glyphAlt` only —
/// "native / transported" — but §4.3 gives `audio.analog` three (● line
/// / ◐ speaker low-Z / ○ constant-voltage) and `pwr` three (⬢ AC / ⬡ DC
/// / ⏚ bonding). The first two are stored; the third has nowhere to
/// live until a per-family glyph exists, which DR-010 §11.10.4 keeps out
/// of scope. `audio.speaker_cv` (○) and `power.bonding` (⏚) are the two
/// families that render with the wrong shape until then.
Map<SignalDomainId, SignalDomainDef> buildSeedSignalDomains() {
  final all = <SignalDomainDef>[
    // Tag prefixes are docs/08-pdf-export.md §3.5's TYPE-chip legend,
    // which is the only place all eight are printed together — VID, RF,
    // AUD, DIG, NET, CTL, PWR, STR, in this same row order. NOTE THE
    // DISAGREEMENT: docs/02-data-model.md §6.2's worked JSON shows
    // single letters ("tagPrefix": "C" for ctl, "N" for net). §3.5 is
    // taken because it is complete, because `VID·HDMI`/`CTL·232`/
    // `AUD·SPK` is the form the schedule's TYPE cell prints, and because
    // a one-letter `N` collides with the `N` net designator prefix that
    // `seed_catalog_test.dart` already guards as a system prefix.
    _domain(
      'video.digital',
      'Digital Video',
      'VID',
      '#0072B2',
      '#4DA6DD',
      // solid — the native carrier of the digital-video domain, which is
      // what HDMI is for; the three HDMI generations separate on weight.
      [],
      1000,
      '▲',
      '△',
    ),
    _domain(
      'video.analog',
      'Analog Video & RF',
      'RF',
      '#56B4E9',
      '#8ACFF5',
      [12000, 4000],
      1000,
      '▼',
      '▽',
    ),
    _domain(
      'audio.analog',
      'Analog Audio',
      'AUD',
      '#E69F00',
      '#F0B443',
      [6000, 3000],
      1000,
      '●',
      '◐',
    ),
    _domain(
      'audio.digital',
      'Digital Audio',
      'DIG',
      '#D55E00',
      '#F07A33',
      [6000, 3000, 1000, 3000],
      1000,
      '◆',
      '◇',
    ),
    _domain(
      'net',
      'Network',
      'NET',
      '#009E73',
      '#2FC79A',
      [],
      1500,
      '■',
      '□',
    ),
    _domain(
      'ctl',
      'Control',
      'CTL',
      '#CC79A7',
      '#E29CC3',
      [1500, 3000],
      750,
      '✚',
      '✳',
    ),
    _domain(
      'pwr',
      'Power',
      'PWR',
      '#000000',
      // INVERTED on purpose — see the doc comment above.
      '#E8E8E8',
      [8000, 3000, 1500, 3000, 1500, 3000],
      2000,
      '⬢',
      '⬡',
    ),
    _domain(
      'str',
      'Structure',
      'STR',
      '#999999',
      '#A8A8A8',
      // `6,3,3,3`, class (short,short), period 15 pt — NOT the retracted
      // `4,4`. `4,4` and `6,3` are both class (short) under §4.2's
      // mechanical definition and 0.75×/1.00× is a ratio of 1.33, so the
      // "an even dash is unambiguous against a 2:1 dash" reasoning is
      // the very collision it was written to avoid (§14.3). Do not
      // "restore" it.
      [6000, 3000, 3000, 3000],
      750,
      '★',
      '☆',
    ),
  ];
  return {for (final d in all) d.id: d};
}

// ─────────────────────────────────────────────────────────────────────
// FAMILIES
// ─────────────────────────────────────────────────────────────────────

/// One §4.4 row, in the table's column order: id, display name, domain,
/// default connector, direction, topology, tag — then the dash and
/// weight, WHICH ARE OMITTED WHEN THE FAMILY INHERITS ITS DOMAIN'S.
///
/// STORING THE OVERRIDE AND NOT THE EFFECTIVE VALUE IS THE POINT. §4.4
/// prints effective values so its table is self-contained; the model
/// stores overrides so that `SignalFamilyDef.effectiveDashPattern` has
/// something to fall back to and so a domain-level correction (as `str`
/// took at §14.3) reaches every family that never overrode it. The
/// parity gate applies the same fallback before comparing, so it checks
/// the inheritance rule as well as the values.
/// [aliases] is DR-060 §11.59.8's set, and it is DELIBERATELY SPARSE.
/// `resolveSignalFamilyToken` already reaches a family by `shortTag`, by
/// the id's own tail and by `displayName`, so `hdbaset`, `hbt`, `dante`
/// and `ethernet` have always landed and none of them needs an entry
/// here. **An alias is authored only where the trade's spelling reaches
/// nothing**: `hdbt` is docs/06 §4.1's own token and matched no step of
/// that chain. A family with no alias is not unreachable, and adding one
/// "for symmetry" widens the collision surface for nothing.
SignalFamilyDef _family(
  String id,
  String displayName,
  String domain,
  String connector,
  PortDirection direction,
  PortTopology topology,
  String shortTag, {
  List<int>? dash,
  int? weight,
  List<String> aliases = const [],
}) => SignalFamilyDef(
  id: SignalFamilyId(id),
  displayName: displayName,
  domain: SignalDomainId(domain),
  defaultConnector: ConnectorTypeId(connector),
  defaultDirection: direction,
  defaultTopology: topology,
  shortTag: shortTag,
  dashOverride: dash,
  lineWeightPermilleOverride: weight,
  aliases: aliases,
);

/// The 57 shipped signal families (§4.4).
///
/// ═══════════════════════════════════════════════════════════════════
/// HOW §4.4's `Dir` AND `Topo` COLUMNS ARE READ, MECHANICALLY
/// ═══════════════════════════════════════════════════════════════════
/// Those two columns are prose, and `PortDirection`/`PortTopology` are
/// five- and three-value enums, so a rule is stated here rather than a
/// judgement made per row:
///
///   * `defaultDirection` is the FIRST arrow in the cell, mapped by
///     §2.2's own table: `→` ⇒ `source`, `↔` ⇒ `bidirectional`, and
///     `passive` ⇒ `passive`. A parenthetical or second arrow describes
///     a return/auxiliary channel — `→ (+ARC ↔)`, `→ power, ↔ data`,
///     `→ drive or ← sense` — and is NOT modelled at M0.
///   * `⤳` ("logical flow riding a network": `video.avoip`,
///     `audio.dante`, `audio.aes67`) has no enum value. It is recorded
///     as `bidirectional`, which is what the physical RJ45 port is; the
///     "logical flow" fact is lost and is owed a field.
///   * `busNode` is never a family default. §2.2's examples of it are
///     PORTS on devices (a Cresnet drop, a CV speaker tap), and §4.4
///     puts the bus fact in the `Topo` column instead — so e.g.
///     `audio.speaker_cv` is `source` + `multidrop`, not `busNode`.
///   * `defaultTopology`: `P2P` ⇒ `p2p`, `MD`/`BUS` ⇒ `multidrop`,
///     `STAR` ⇒ `star`. Where a cell lists two (`P2P / MST`, `P2P /
///     STAR`, `P2P / parallel`) the FIRST is taken.
///
/// ═══════════════════════════════════════════════════════════════════
/// THE ONE INVENTED VALUE, DECLARED
/// ═══════════════════════════════════════════════════════════════════
/// `structure.pathway`'s connector cell in §4.4 is `—`, and
/// `SignalFamilyDef.defaultConnector` is non-nullable. It is recorded as
/// `conn.unterminated`, which is the registry's OWN name for "no
/// termination" (§5.1 lists it with no footprint for exactly that
/// reason) — the nearest true id, not a new one. Its topology cell is
/// also `—`; `p2p` is recorded because a pathway "creates a `Pathway`,
/// never a Link and never a Port" (CR-109), so no topology it could
/// carry is observable.
Map<SignalFamilyId, SignalFamilyDef> buildSeedSignalFamilies() {
  const src = PortDirection.source;
  const snk = PortDirection.sink;
  const bi = PortDirection.bidirectional;
  const pas = PortDirection.passive;
  const p2p = PortTopology.p2p;
  const md = PortTopology.multidrop;
  const star = PortTopology.star;

  final all = <SignalFamilyDef>[
    // ── Digital video — #0072B2, ▲ native / △ transported ────────────
    //
    // All three HDMI generations stay SOLID and separate ON WEIGHT
    // ALONE, as a bandwidth progression. HDMI 1.4 was authored at 1.00×,
    // which made it byte-identical to 2.0 on all four channels and
    // failed PAL-1's within-domain limb; 0.75× also reads correctly as
    // "the slow one". 0.75×/1.00× is a ratio of 1.33 and would NOT clear
    // the cross-domain limb — it does not have to, because the
    // within-domain limb needs only dash, weight or glyph to differ.
    _family(
      'video.hdmi.1_4',
      'HDMI 1.4',
      'video.digital',
      'conn.hdmi_a',
      src,
      p2p,
      'HD14',
      weight: 750,
      aliases: const ['hdmi14'],
    ),
    _family(
      'video.hdmi.2_0',
      'HDMI 2.0 (18 Gbps)',
      'video.digital',
      'conn.hdmi_a',
      src,
      p2p,
      'HD20',
      aliases: const ['hdmi', 'hdmi20'],
    ),
    _family(
      'video.hdmi.2_1',
      'HDMI 2.1 (48 Gbps)',
      'video.digital',
      'conn.hdmi_a',
      src,
      p2p,
      'HD21',
      weight: 1250,
      aliases: const ['hdmi21'],
    ),
    _family(
      'video.displayport',
      'DisplayPort 1.4 / 2.1',
      'video.digital',
      'conn.dp',
      src,
      p2p,
      'DP',
      dash: [18000, 4000],
    ),
    _family(
      'video.sdi',
      'SDI (HD / 3G / 6G / 12G)',
      'video.digital',
      'conn.bnc75',
      src,
      p2p,
      'SDI',
      dash: [10000, 3000],
    ),
    // HDBaseT is △ TRANSPORTED, and `acceptedFamilies` deliberately
    // EXCLUDES `net.ethernet` — patching an HDBaseT output into a switch
    // does not work and its 100 W PoH can damage the switch. That check
    // (`SIG-001`) is the highest-value validation in the product and is
    // only expressible because this is its own family. The exclusion
    // list is not on the M0 class yet; the family separation is.
    _family(
      'video.hdbaset',
      'HDBaseT (5Play)',
      'video.digital',
      'conn.rj45',
      src,
      p2p,
      'HBT',
      dash: [14000, 4000],
      weight: 1250,
      aliases: const ['hdbt'],
    ),
    _family(
      'video.usbc_dpalt',
      'USB-C DP Alt Mode',
      'video.digital',
      'conn.usb_c',
      bi,
      p2p,
      'UCV',
      dash: [6000, 2000],
    ),
    _family(
      'video.avoip',
      'AV-over-IP (SDVoE / JPEG XS / NDI)',
      'video.digital',
      'conn.rj45',
      bi,
      star,
      'AVIP',
      dash: [14000, 4000, 2000, 4000],
    ),

    // ── Analog video & RF — #56B4E9, ▼ baseband / ▽ broadband ────────
    //
    // `video.composite`'s dash is `1.5,3` (class (dot)), NOT the `12,4`
    // domain base it was authored with. At `12,4` 1.00× it was one of
    // four `video.analog` families sharing class (long) with
    // `audio.line_bal` at `10,3` 1.00× across a ΔL of 0.0112 — the
    // analog-video and analog-audio hues are 0.4050 and 0.4162, about as
    // deep inside the 0.10 band as two domains can be. A fine dot is
    // also the honest reading: it is the lowest-bandwidth video signal
    // in the registry.
    _family(
      'video.composite',
      'Composite (CVBS)',
      'video.analog',
      'conn.rca75',
      src,
      p2p,
      'CVBS',
      dash: [1500, 3000],
    ),
    _family(
      'video.component',
      'Component YPbPr',
      'video.analog',
      'conn.rca75',
      src,
      p2p,
      'YPBPR',
      dash: [12000, 4000, 3000, 4000],
    ),
    _family(
      'video.vga',
      'VGA / RGBHV',
      'video.analog',
      'conn.hd15',
      src,
      p2p,
      'VGA',
      dash: [12000, 4000, 3000, 4000, 3000, 4000],
    ),
    _family(
      'video.svideo',
      'S-Video',
      'video.analog',
      'conn.mini_din4',
      src,
      p2p,
      'SVID',
      dash: [9000, 4000],
    ),
    _family(
      'rf.catv',
      'RF / CATV distribution',
      'video.analog',
      'conn.f_type',
      src,
      md,
      'RF',
      weight: 1500,
    ),
    _family(
      'rf.satellite',
      'Satellite / SWM',
      'video.analog',
      'conn.f_type',
      bi,
      md,
      'SAT',
      dash: [12000, 4000, 3000, 4000],
      weight: 1500,
    ),
    _family(
      'rf.ota',
      'OTA antenna',
      'video.analog',
      'conn.f_type',
      src,
      md,
      'OTA',
      dash: [16000, 4000],
    ),
    _family(
      'rf.modulated',
      'RF modulated channel',
      'video.analog',
      'conn.f_type',
      src,
      md,
      'RFM',
    ),

    // ── Analog audio — #E69F00, ● line / ◐ speaker low-Z / ○ CV ──────
    //
    // This is where the brief's "Analog RCA" and "speaker level" would
    // have collided on one orange, and they do not: `AUD` is a 1.00×
    // short dash with a filled circle; `SPK` is a 2.00× stroke with a
    // half-filled circle. In greyscale that is a 2× weight difference,
    // the most legible discriminator available.
    _family(
      'audio.line_unbal',
      'Line level, unbalanced (RCA)',
      'audio.analog',
      'conn.rca',
      src,
      p2p,
      'AUD',
    ),
    // THE EMPTY LIST IS AN EXPLICIT SOLID OVERRIDE, not "no override" —
    // see `SignalFamilyDef.dashOverride`. `audio.line_bal` was authored
    // `10,3`, class (long), and collided simultaneously with FOUR
    // `video.analog` families — composite, svideo, rf.ota, rf.modulated
    // — all at ΔL 0.0112 and all at 1.00×, so neither PAL-1 limb rescued
    // any of them. Solid is unoccupied in `audio.analog` and a balanced
    // line is the domain's cleanest carrier. This is the one place a
    // `dashOverride` reaches for solid inside a dashed domain.
    _family(
      'audio.line_bal',
      'Line level, balanced',
      'audio.analog',
      'conn.xlr3',
      src,
      p2p,
      'AUDB',
      dash: [],
    ),
    _family(
      'audio.mic',
      'Mic level',
      'audio.analog',
      'conn.xlr3',
      src,
      p2p,
      'MIC',
      dash: [4000, 3000],
    ),
    _family(
      'audio.phono',
      'Phono / turntable',
      'audio.analog',
      'conn.rca',
      src,
      p2p,
      'PHNO',
      dash: [4000, 3000, 1500, 3000],
    ),
    _family(
      'audio.speaker_lowz',
      'Speaker level, low-Z',
      'audio.analog',
      'conn.binding_post',
      src,
      p2p,
      'SPK',
      weight: 2000,
      // `euro2` IS HERE AND NOT ON `audio.speaker_cv`, WHOSE DEFAULT
      // CONNECTOR THE EUROBLOCK ACTUALLY IS. DR-060 §11.59.10(b): the
      // user ruled low-Z the overwhelming case in the racks this tool
      // is for, overruling a recommendation to leave the family unknown.
      // The connector table's own `euro2` then overrides this family's
      // `conn.binding_post` default, which is §11.59.4's two-registry
      // split doing the same work `c13` forced it to do.
      //
      // `speaker` is first, so the derived bank name is "Speaker
      // Outputs" rather than "EURO2 Outputs" (§11.59.10(a)).
      aliases: const ['speaker', 'euro2'],
    ),
    _family(
      'audio.speaker_cv',
      'Speaker, constant-voltage 70 / 100 / 25 V',
      'audio.analog',
      'conn.euroblock_2',
      src,
      md,
      '70V',
      dash: [10000, 3000, 2000, 3000],
      weight: 2000,
      aliases: const ['100v', 'cv'],
    ),
    _family(
      'audio.sub',
      'Subwoofer / LFE',
      'audio.analog',
      'conn.rca',
      src,
      p2p,
      'SUB',
      dash: [8000, 3000],
      weight: 1250,
    ),
    _family(
      'audio.headphone',
      'Headphone',
      'audio.analog',
      'conn.6_35mm_trs',
      src,
      p2p,
      'HP',
      dash: [3000, 3000],
      weight: 750,
    ),

    // ── Digital audio — #D55E00, ◆ electrical / ◇ optical or networked
    //
    // TWO DASHES HERE WERE RE-AUTHORED AND ONE IS A REQUIREMENT-4 TYPE.
    // `audio.digital` sits at L 0.2215, inside the 0.10 band against
    // `ctl` (0.2930), `video.digital` (0.1525) AND `net` (0.2569) at
    // once — the most crowded hue in the palette — and dash-dot is the
    // most crowded class. At `6,3,1,3` S/PDIF collided with SIX `ctl`
    // families including RS-232 and IR receive, two more of the ten
    // types the brief names by hand; at `10,3,1,3` AES3 collided with
    // `ctl.cresnet` and `video.avoip`. The replacements take (long,
    // short) and (long,long). DO NOT "restore" the dash-dot patterns for
    // family resemblance: the resemblance is what broke them.
    _family(
      'audio.spdif_coax',
      'S/PDIF, coaxial (75 Ω)',
      'audio.digital',
      'conn.rca75',
      src,
      p2p,
      'SPD',
      dash: [12000, 4000, 3000, 4000],
      aliases: const ['spdif'],
    ),
    // TOSLINK's weight was raised from 1.00×: at 1.00× it collided with
    // `ctl.ir_emitter` on every non-hue channel — ΔL 0.0715, both fine-
    // dot class, weight ratio only 1.33 — which fails PAL-1 in
    // greyscale. At 1.25× the ratio is 1.67 and the pair passes.
    _family(
      'audio.spdif_optical',
      'TOSLINK (optical S/PDIF)',
      'audio.digital',
      'conn.jis_f05',
      src,
      p2p,
      'OPT',
      dash: [2000, 3000],
      weight: 1250,
    ),
    _family(
      'audio.aes3',
      'AES/EBU (AES3, 110 Ω)',
      'audio.digital',
      'conn.xlr3',
      src,
      p2p,
      'AES',
      dash: [12000, 4000, 10000, 4000],
    ),
    _family(
      'audio.aes3id',
      'AES3id (75 Ω BNC)',
      'audio.digital',
      'conn.bnc75',
      src,
      p2p,
      'AES75',
      dash: [10000, 3000, 1000, 3000, 1000, 3000],
    ),
    _family(
      'audio.dante',
      'Dante',
      'audio.digital',
      'conn.rj45',
      bi,
      star,
      'DNT',
      weight: 1500,
    ),
    _family(
      'audio.aes67',
      'AES67',
      'audio.digital',
      'conn.rj45',
      bi,
      star,
      'A67',
      dash: [6000, 3000, 1000, 3000, 1000, 3000],
      weight: 1500,
    ),
    _family(
      'audio.avb',
      'AVB / Milan',
      'audio.digital',
      'conn.rj45',
      bi,
      star,
      'AVB',
      dash: [8000, 3000, 1000, 3000],
      weight: 1500,
    ),

    // ── Network — #009E73, ■ copper / □ fibre or non-Ethernet ────────
    //
    // PoH is □ and its own family rather than a flag on `net.poe`: it is
    // *based on* 802.3at but modified for 4-pair 100 W delivery and is
    // NOT interoperable with a standard PoE PSE.
    _family(
      'net.ethernet',
      'Ethernet (copper)',
      'net',
      'conn.rj45',
      bi,
      star,
      'NET',
      // `lan` LEADS, for §11.59.10(a)'s reason: `rj45` is the
      // connector, and a bank of Ethernet ports is "LAN", not "RJ45".
      aliases: const ['lan', 'rj45'],
    ),
    _family(
      'net.poe',
      'PoE / PoE+ / PoE++',
      'net',
      'conn.rj45',
      src,
      star,
      'PoE',
      weight: 2000,
    ),
    _family(
      'net.poh',
      'PoH (HDBaseT power)',
      'net',
      'conn.rj45',
      src,
      p2p,
      'PoH',
      dash: [14000, 4000],
      weight: 2000,
    ),
    _family(
      'net.fiber_mm',
      'Fibre, multimode (OM3 / OM4)',
      'net',
      'conn.lc_duplex',
      bi,
      p2p,
      'FIB',
      dash: [16000, 4000],
    ),
    _family(
      'net.fiber_sm',
      'Fibre, singlemode (OS2)',
      'net',
      'conn.lc_duplex',
      bi,
      p2p,
      'FIBS',
      dash: [16000, 4000, 3000, 4000],
    ),
    _family(
      'net.dac',
      'Direct-attach copper (SFP+)',
      'net',
      'conn.sfp_cage',
      bi,
      p2p,
      'DAC',
      dash: [8000, 3000],
    ),

    // ── Control — #CC79A7, ✚ point-to-point / ✳ multi-drop bus ───────
    //
    // THE THREE IR FAMILIES ARE SEPARATE BECAUSE THE PINOUT HAZARD IS
    // REAL AND DESTRUCTIVE: receivers are tip = signal, ring = GND,
    // sleeve = +12 V; emitters are tip = IR in, sleeve = GND. Plugging an
    // emitter into a receiver jack destroys the emitter and can damage the
    // supply. That is why `PortDef.pinoutVariant` is a safety-adjacent
    // mandatory field on every 3.5 mm IR port (AC-052).
    //
    // THERE ARE THREE AND NOT TWO SINCE DR-126 §11.125, and the reason is
    // that the sentence above names the wrong discriminator. The damage is
    // a two-conductor TS plug bridging ring to sleeve on a jack that
    // SUPPLIES +12 V; it has nothing to do with what the far device is
    // called. `ctl.ir_receiver` therefore means the POWERED receiver-eye
    // circuit (a block's RX jacks, its `IR IN`, the eye's pigtail), and
    // `ctl.ir_direct` means the passive device input an emitter lead
    // lands on. Eleven ports carried the first name while being the
    // second thing, which is why `DIR-003` fired an `error` spring-back on
    // an emitter head reaching a television.
    _family(
      'ctl.ir_emitter',
      'IR emitter (flasher)',
      'ctl',
      'conn.3_5mm_ts',
      src,
      p2p,
      'IR',
      // `ir` IS FIRST AND THAT IS THE WHOLE REASON IT IS HERE. It
      // already resolved to this family through `shortTag`, so it adds
      // no vocabulary; it adds a DISPLAY fact, because DR-060
      // §11.59.10(a) derives a bank name from `aliases.first` and an
      // installer writes "IR Outputs" rather than "IR35 Outputs".
      aliases: const ['ir', 'ir35'],
    ),
    _family(
      'ctl.ir_receiver',
      'IR receiver (powered eye)',
      'ctl',
      'conn.3_5mm_trs',
      src,
      md,
      'IRRX',
      dash: [4000, 3000, 1500, 3000],
    ),
    // `1.5,9` IS THE EMITTER'S OWN DOT AT THREE TIMES THE GAP, and the
    // pattern was searched rather than picked: 3,928 candidates were run
    // through `tools/pal1_check.py` in full and 1,209 survived, so the
    // choice among them is a design one. It reads as the IR family's
    // quieter sibling on T0.01, which is what it is, and a 7.5 pt gap
    // difference is unmistakable at 300 dpi where the 0.5 pt separating
    // the near misses (`2,3`, `1.5,4`) would not be. The exact-tuple
    // within-domain limb cannot see a pattern that TILES to another one,
    // so `1.5,3,1.5,3` was excluded by hand: it renders as `1.5,3`.
    _family(
      'ctl.ir_direct',
      'IR direct (device input)',
      'ctl',
      'conn.3_5mm_ts',
      snk,
      p2p,
      'IRD',
      dash: [1500, 9000],
    ),
    _family(
      'ctl.rs232',
      'RS-232',
      'ctl',
      'conn.de9',
      bi,
      p2p,
      '232',
      dash: [6000, 3000, 1500, 3000],
      // `rs232` LEADS AND `de9` FOLLOWS. DR-060 §11.59.10(a) makes
      // `aliases.first` the bank-name head, and `de9` is a CONNECTOR,
      // so leading with it derived a bank called "DE9 Ports": a plug
      // labelling a signal. `rs232` already resolved through the id
      // tail, so it adds a display fact and no vocabulary.
      aliases: const ['rs232', 'de9'],
    ),
    _family(
      'ctl.rs485',
      'RS-485',
      'ctl',
      'conn.euroblock_3',
      bi,
      md,
      '485',
      dash: [6000, 3000],
      weight: 1000,
    ),
    _family(
      'ctl.dmx512',
      'DMX512-A',
      'ctl',
      'conn.xlr5',
      src,
      md,
      'DMX',
      dash: [8000, 3000, 1500, 3000],
      weight: 1000,
    ),
    _family(
      'ctl.contact',
      'Contact closure / relay / GPIO',
      'ctl',
      'conn.euroblock_2',
      src,
      p2p,
      'CC',
      dash: [1500, 3000, 4000, 3000],
    ),
    _family(
      'ctl.trigger12v',
      '12 V trigger',
      'ctl',
      'conn.3_5mm_ts',
      src,
      p2p,
      'TRG',
      dash: [4000, 3000],
    ),
    _family(
      'ctl.cresnet',
      'Cresnet',
      'ctl',
      'conn.phoenix_4',
      bi,
      md,
      'CN',
      dash: [10000, 3000, 1500, 3000],
      weight: 1000,
    ),
    _family(
      'ctl.lutron_qs',
      'Lutron QS / HomeWorks link',
      'ctl',
      'conn.rj45',
      bi,
      md,
      'QS',
      dash: [10000, 3000],
      weight: 1000,
    ),
    _family(
      'ctl.dali',
      'DALI / DALI-2',
      'ctl',
      'conn.screw_terminal',
      bi,
      md,
      'DALI',
      dash: [5000, 3000, 1500, 3000],
      weight: 1000,
    ),
    _family(
      'ctl.knx',
      'KNX TP1',
      'ctl',
      'conn.knx_terminal',
      bi,
      md,
      'KNX',
      dash: [7000, 3000, 1500, 3000],
      weight: 1000,
    ),
    // VANTAGE IS THE SEVENTH TWO-WIRE BUS IN THIS DOMAIN, and that is
    // the argument for it rather than an objection. RS-485, DALI, KNX,
    // Cresnet, Lutron QS and contact closure all land on two conductors
    // at a terminal, so a Vantage run drawn as "some two-wire bus"
    // is a run an installer can land on the wrong controller. A family
    // of its own is what makes the drawing say which one.
    //
    // `conn.hardwired`, AND THE FIRST DRAFT HAD IT WRONG. It shipped as
    // `conn.screw_terminal`, inferred from `ctl.dali`, flagged in this
    // comment as the one value not taken from a stated fact and as the
    // first thing to correct. It was corrected within the day: Vantage
    // joins the bus with Wago or wire nut connections, so there is no
    // connector at all and the conductors are spliced, which is
    // `power.ac_hardwired`'s situation exactly and its connector too.
    _family(
      'ctl.vantage',
      'Vantage station bus (Legrand)',
      'ctl',
      'conn.hardwired',
      bi,
      md,
      'VTG',
      // 9 is the free slot in this domain's dash-dot run: DALI 5,
      // RS-232 6, KNX 7, DMX 8, Cresnet 10. PAL-1 passes at 57 families.
      dash: [9000, 3000, 1500, 3000],
      weight: 1000,
    ),

    // ── Power — #000000 light / #E8E8E8 dark, ⬢ AC / ⬡ DC / ⏚ bonding
    //
    // INLET AND OUTLET ARE NOT DIRECTIONS (CR-058, CR-060). They are
    // `sink`/`source` on a `power.*` family plus `PortPowerSpec.role`,
    // which is why there is no `ac-inlet` family here. `power.bonding`
    // exists so a bonding conductor is DRAWABLE and therefore appears on
    // the drawing at all; the busbar entity and conductor sizing are
    // v1.2 (RJ-010).
    _family(
      'power.ac_branch',
      'AC branch circuit',
      'pwr',
      'conn.nema_5_15p',
      src,
      p2p,
      'PWR',
      // `ac` LEADS, same rule: the NEMA tokens all name connectors.
      aliases: const ['ac', '5-15p', '5-15r', '5-20p', '5-20r', 'l5-30p'],
    ),
    _family(
      'power.ac_iec',
      'IEC device power (C13/C14, C19/C20)',
      'pwr',
      'conn.iec_c14',
      src,
      p2p,
      'IEC',
      dash: [8000, 3000, 1500, 3000],
      // `iec` LEADS so the bank derives "IEC Inputs" rather than
      // "C13 Inputs" (§11.59.10(a)); the four cordage tokens follow
      // and are what an integrator actually types.
      aliases: const ['iec', 'c13', 'c14', 'c19', 'c20'],
    ),
    _family(
      'power.ac_hardwired',
      'Hardwired AC',
      'pwr',
      'conn.hardwired',
      src,
      p2p,
      'HW',
      dash: [12000, 3000, 1500, 3000],
    ),
    _family(
      'power.dc_low',
      'Low-voltage DC (12 / 24 V supply)',
      'pwr',
      'conn.barrel_dc',
      src,
      p2p,
      'DC',
      dash: [6000, 3000, 1500, 3000],
      weight: 1500,
    ),
    _family(
      'power.bonding',
      'Bonding / grounding conductor',
      'pwr',
      'conn.ground_lug',
      bi,
      star,
      'GND',
      dash: [4000, 3000],
      weight: 1500,
    ),

    // ── Structure — #999999, ★ home run / ☆ pathway ──────────────────
    //
    // `structure.undetermined` is the interesting case and it is
    // deliberate: a Cat6 home run at rough-in may end up carrying
    // Ethernet, HDBaseT, or nothing. The family is legal, it schedules,
    // it prints, it gets a `W` number and both labels, and the DRC
    // validates RETROACTIVELY once a `Service` assigns a real family.
    // Its dash is the `str` domain base, not an override.
    _family(
      'structure.undetermined',
      'Undetermined home run',
      'str',
      'conn.unterminated',
      pas,
      p2p,
      'STR',
    ),
    // A DOUBLE DOT (period 15 pt), not the single `2,6` it was authored
    // with: at 0.75× against `ctl.ir_emitter`'s `1.5,3` at 0.75× — ΔL
    // 0.0255, same fine-dot class, weight ratio 1.00 — it violated
    // PAL-1. A double dot also reads correctly as "a route, not a
    // conductor" and is unique in the shipped set.
    _family(
      'structure.pathway',
      'Pathway only (conduit / pull string)',
      'str',
      'conn.unterminated',
      pas,
      p2p,
      'PATH',
      dash: [1500, 3000, 1500, 9000],
    ),
  ];
  return {for (final f in all) f.id: f};
}

// ─────────────────────────────────────────────────────────────────────
// THE MASTER A NEW DOCUMENT IS SEEDED FROM
// ─────────────────────────────────────────────────────────────────────

/// The registry master a NEW document starts from (DR-010 §11.10.2).
///
/// SEEDED AT CREATION, NEVER COMPUTED AT SAVE, and the reason is CR-117.
/// `docs/02-data-model.md:834` says a document embeds "the subset a
/// document references", which is what makes a `.rackpal`
/// self-describing — but if `write()` RECOMPUTED that subset, then
/// reading a document carrying an entry nothing references and writing
/// it back would DROP that entry, and `write(read(bytes)) == bytes` is
/// the property the whole byte suite is built on. Elision at save turns
/// a hand-edited or forward-version file into silent data loss. So this
/// is copied in once, by the two document-creation sites
/// (`buildBlankDocument` and `StarterAuthor.newDocument`), and from that
/// moment the registries are ORDINARY STORED DATA that round-trips
/// verbatim, exactly like the seed catalog and the jacket-colour
/// convention beside it.
///
/// EXISTING DOCUMENTS ARE NOT MIGRATED. A document with empty registries
/// keeps them and every unresolved id degrades to the `unknown(rawId)`
/// placeholder §6.2's own acceptance rule already requires — "round-
/// trips, renders grey with the raw id as its tag, and never throws".
/// M2-B's unresolved counts are that rule working, not a defect to be
/// fixed by rewriting user files.
///
/// `connectorTypes` IS INCLUDED and was previously dead —
/// `buildSeedConnectorFootprints()` shipped at M1 and was consumed only
/// by its own test, which is why DR-010's finding reads `connectors: 0`
/// everywhere alongside the two empty signal maps. `cableSpecs` STAYS
/// EMPTY; see the file header.
Registries buildSeedRegistries() => Registries(
  signalDomains: buildSeedSignalDomains(),
  signalFamilies: buildSeedSignalFamilies(),
  connectorTypes: buildSeedConnectorFootprints(),
  mediaTypes: buildSeedMediaTypes(),
  outletTemplates: buildSeedOutletTemplates(),
);
