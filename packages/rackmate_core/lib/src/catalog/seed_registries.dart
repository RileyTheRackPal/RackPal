// THE SEEDED SIGNAL REGISTRIES — the 8 domains and 55 families of
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
// asset, and the reason is structural, not stylistic: `rackmate_core`
// imports no Flutter, so it cannot load an asset at all (`rootBundle` is
// Flutter-only). A JSON master would have to be loaded by the app layer
// and injected through two packages, because `rackmate_export` drives
// core directly and may never import `rackmate_ui`. A seeded Dart
// catalog needs no seam, works unchanged in core's pure-Dart tests, and
// is what this repository already does four times over — 48 templates
// (`seed_catalog.dart`), connector footprints (`catalog_connectors
// .dart`), jacket-colour conventions, rack presets.
//
// ═════════════════════════════════════════════════════════════════════
// THIS IS A FOURTH COPY OF THE PALETTE, AND IT IS GATED LIKE ONE
// ═════════════════════════════════════════════════════════════════════
// `tools/pal1_check.py` REMAINS THE SINGLE AUTHORITY (DR-010 §11.10.1,
// §4.2). Hand-authoring 8 domains and 55 families into Dart creates a
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
//  * `Registries.cableSpecs` and `.outletTemplates` STAY EMPTY. §6's
//    outlet templates are real shipped content, but they are out of
//    DR-010's scope and inventing them here to make two maps look
//    populated is the fabrication G4 forbids. They are still empty; that
//    is the truth. `.mediaTypes` WAS in this list and is no longer:
//    M3-C/6 seeded canon §6.5's 38 types from `seed_media_types.dart`,
//    because the drop DSL (docs/07 §4.3, `4x Cat6`) has to resolve a
//    media name against something and there was nothing there.
//  * `SignalFamilyDef.aliases` is empty on all 55. §2.3's alias table is
//    real, but it is the Quick Add DSL's resolution table (CR-058) and
//    nothing in this build resolves an alias — §2.3 itself says "the
//    file never stores one". Populating it would ship 40 rows no code
//    reads and no gate checks.
//  * NO `glyphOverride`, and no per-family glyph. DR-010 §11.10.3 adds
//    exactly `shortTag`, `dashOverride` and a weight override; §11.10.4
//    keeps the rest of the ~20-field corpus shape out. §4.4's per-family
//    Glyph column is therefore CARRIED BY THE DOMAIN ONLY — see the note
//    on the three-glyph domains below.
//  * `topologyFree` (AC-030's registry field, set on `ctl.cresnet`,
//    `ctl.lutron_qs`, `ctl.dali`, `ctl.knx`) is not on the Dart class.
//    Owed, and named here so the four families are findable when it
//    lands.

import 'package:rackmate_core/src/catalog/catalog_connectors.dart';
import 'package:rackmate_core/src/catalog/seed_media_types.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/template.dart'
    show PortDirection, PortTopology;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/rgb.dart';

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
);

/// The 55 shipped signal families (§4.4).
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
    ),
    _family(
      'video.hdmi.2_0',
      'HDMI 2.0 (18 Gbps)',
      'video.digital',
      'conn.hdmi_a',
      src,
      p2p,
      'HD20',
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
    // The two IR families are separate because the pinout hazard is real
    // and destructive: receivers are tip = signal, ring = GND, sleeve =
    // +12 V; emitters are tip = IR in, sleeve = GND. Plugging an emitter
    // into a receiver jack destroys the emitter and can damage the
    // supply. That is why `PortDef.pinoutVariant` is a safety-adjacent
    // mandatory field on every 3.5 mm IR port (AC-052).
    _family(
      'ctl.ir_emitter',
      'IR emitter (flasher)',
      'ctl',
      'conn.3_5mm_ts',
      src,
      p2p,
      'IR',
    ),
    _family(
      'ctl.ir_receiver',
      'IR receiver',
      'ctl',
      'conn.3_5mm_trs',
      src,
      md,
      'IRRX',
      dash: [4000, 3000, 1500, 3000],
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
/// document references", which is what makes a `.rackmate`
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
/// everywhere alongside the two empty signal maps. `cableSpecs` and
/// `outletTemplates` STAY EMPTY; see the file header.
Registries buildSeedRegistries() => Registries(
  signalDomains: buildSeedSignalDomains(),
  signalFamilies: buildSeedSignalFamilies(),
  connectorTypes: buildSeedConnectorFootprints(),
  mediaTypes: buildSeedMediaTypes(),
);
