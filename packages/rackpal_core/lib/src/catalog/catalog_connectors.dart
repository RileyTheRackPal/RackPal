// The seeded connector-footprint registry (docs/catalog/seed-devices.md
// §5.1/§5.2, AC-050/A2.2). "Every connector referenced by a shipped
// template has a footprint entry, asserted in CI" is the exact roadmap
// line this file exists to satisfy (docs/09-roadmap.md M1 checklist #6) —
// see `seed_catalog_test.dart`'s connector-footprint assertion, which walks
// every port in [buildSeedCatalog] and checks its connector resolves here
// with both footprint dimensions set.
//
// Footprint dimensions (mm, converted to exact nanometres — CR-001) are
// taken VERBATIM from §5.2's table where that section states one; the
// remaining connector ids in §5.1's registry table have no footprint row
// there, so this file synthesizes a representative value from the
// connector's well-known physical envelope (a panel-mount HDMI/XLR/RCA/
// RJ45/etc. shell is a standardized, publicly documented shape — this is
// NOT a manufacturer-specific citation). See assets/catalog/sources.md
// "Connector footprints" for the citation of every value below, and DR-002
// (generic archetypes, never real SKUs) for why no manufacturer part
// number is attached to any of them.
//
// `conn.hardwired`, `conn.ground_lug` and `conn.unterminated` are
// DELIBERATELY ABSENT: §5.1 states their footprint column as "no" — a
// hardwired lead, a ground lug and an unterminated wire end have no panel
// cutout to author, and the catalog test's assertion exempts exactly these
// three ids rather than inventing a footprint for them (G4: null is
// unknown, never estimated).
//
// ---------------------------------------------------------------------
// M4-B (board #173) ADDED TWO FIELDS, AND THEY ARE AUTHORED ON OPPOSITE
// PRINCIPLES. Read this before adding a value to either.
//
// `genderApplies` IS COMPLETE, because canon §6.3 authors it. That table
// gives a yes or no for every connector id below, so every entry here is
// a TRANSCRIPTION and none is a judgement. CR-059 is why the field
// exists: the five-value gender enum contained two synonym pairs and
// silently broke `CON-002`, whose "both ends male or both ends female"
// never fired for jack+jack.
//
// `pitch` IS DELIBERATELY SPARSE AND STAYS THAT WAY (DR-057 §11.56).
// TWENTY of the forty-nine carry one: FOURTEEN transcribed from
// docs/catalog/seed-devices.md §5.2's thirteen rows (`conn.rca` /
// `conn.rca75` share a row), and SIX that inherit from a connector
// sharing their physical shell, each marked at its entry. The remaining
// twenty-nine are null and are not going to acquire a value.
//
// DO NOT FILL THE REST IN, and specifically do not derive one from
// `footprintWidth`. It looks derivable: most of the stated pitches sit 2
// to 4 mm above their footprint, which reads as a uniform clearance.
// Then `conn.binding_post` has a pitch of 20 mm against a 24 mm pair
// footprint, BELOW it, because 20 mm is the ¾ inch centre spacing
// binding posts are actually built on, and `conn.euroblock_3`'s own name
// carries a 3.5 mm CONTACT pitch that has nothing to do with its 15 mm
// connector pitch. A formula fitted to the rest gets both of those
// wrong.
//
// AN ABSENT PITCH COSTS NOTHING, and the paragraph that used to sit here
// said otherwise. It claimed panel auto-layout was unavailable for a
// template using an unpitched connector, and that was read off docs/06
// §5's pseudocode. **CR-071 rules the layout flows from connector
// FOOTPRINTS** and §5.2's own intro says the same; neither names a
// pitch. The algorithm advances by `pitch ?? (footprintWidth + gutter)`
// (DR-057 §11.56.4), so the twenty stated pitches sharpen a layout that
// works without them.
//
// Note the footprint table above took a different call, scaling within a
// connector family for values §5.2 does not state, and
// `assets/catalog/sources.md` labels those rows as scaled. The
// shared-shell six here are the same instrument used far more narrowly:
// only where sources.md ALREADY documents two ids as one physical shell.

import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

Len _mm(num v) => Len.fromMillimetres(v);

/// Connector ids with no panel-cutout footprint by design (§5.1) — a
/// shipped template may reference these without tripping the
/// connector-footprint CI assertion.
///
/// EXEMPT FROM A FOOTPRINT, NOT FROM THE REGISTRY. They carry a
/// `ConnectorTypeDef` with null dimensions like any other connector; what
/// is exempt is the requirement to state a cutout. See the entries at the
/// end of [buildSeedConnectorFootprints].
const Set<String> kFootprintExemptConnectors = {
  'conn.hardwired',
  'conn.ground_lug',
  'conn.unterminated',
};

/// [pitchMm] is the centre-to-centre row spacing and is **omitted for
/// most connectors on purpose** — see this file's header. [gender] is
/// transcribed from canon §6.3, which authors it for every id below.
ConnectorTypeDef _c(
  String id,
  String name,
  num widthMm,
  num heightMm, {
  List<String> aliases = const [],
  num? pitchMm,
  bool gender = false,
  List<String> mates = const [],
}) => ConnectorTypeDef(
  id: ConnectorTypeId(id),
  displayName: name,
  aliases: aliases,
  footprintWidth: _mm(widthMm),
  footprintHeight: _mm(heightMm),
  pitch: pitchMm == null ? null : _mm(pitchMm),
  genderApplies: gender,
  matesWith: [for (final m in mates) ConnectorTypeId(m)],
);

/// A registry entry for a connector that has no panel cutout to author.
/// Both dimensions stay null — unknown is never estimated (G4) — and so
/// does [ConnectorTypeDef.pitch], which is the same fact: nothing with no
/// cutout has a row spacing. All three are `genderApplies: no` in canon
/// §6.3, which is the default, so none passes the flag.
ConnectorTypeDef _cNoFootprint(
  String id,
  String name, {
  List<String> aliases = const [],
}) => ConnectorTypeDef(
  id: ConnectorTypeId(id),
  displayName: name,
  aliases: aliases,
);

/// Builds the seeded `ConnectorTypeDef` registry — every connector id the
/// M1 catalog's port authoring may reference, each with a real footprint
/// (docs/catalog/seed-devices.md §5.1/§5.2).
Map<ConnectorTypeId, ConnectorTypeDef> buildSeedConnectorFootprints() {
  final all = <ConnectorTypeDef>[
    // -- Digital video --------------------------------------------------
    _c(
      'conn.hdmi_a',
      'HDMI Type A',
      15.1,
      5.6,
      aliases: const ['hdmi'],
      pitchMm: 19,
      mates: const ['conn.hdmi_a'],
    ),
    _c(
      'conn.hdmi_c',
      'HDMI Type C (Mini)',
      11.3,
      4.2,
      mates: const ['conn.hdmi_c'],
    ),
    _c(
      'conn.hdmi_d',
      'HDMI Type D (Micro)',
      9.1,
      3.4,
      mates: const ['conn.hdmi_d'],
    ),
    _c(
      'conn.dp',
      'DisplayPort',
      13.0,
      5.0,
      mates: const ['conn.dp'],
    ),
    _c(
      'conn.mini_dp',
      'Mini DisplayPort',
      8.0,
      4.0,
      mates: const ['conn.mini_dp'],
    ),
    _c(
      'conn.usb_c',
      'USB-C',
      9.0,
      3.5,
      mates: const ['conn.usb_c'],
    ),
    // -- Analog video / RF -----------------------------------------------
    _c(
      'conn.bnc75',
      'BNC 75 ohm',
      10.0,
      10.0,
      pitchMm: 14,
      gender: true,
      mates: const ['conn.bnc75', 'conn.bnc50'],
    ),
    _c(
      'conn.bnc50',
      'BNC 50 ohm',
      10.0,
      10.0,
      gender: true,
      mates: const ['conn.bnc50', 'conn.bnc75'],
    ),
    _c(
      'conn.f_type',
      'F-type',
      9.5,
      9.5,
      pitchMm: 13,
      gender: true,
      mates: const ['conn.f_type'],
    ),
    _c(
      'conn.rca',
      'RCA',
      8.4,
      8.4,
      pitchMm: 11,
      gender: true,
      mates: const ['conn.rca', 'conn.rca75'],
    ),
    _c(
      'conn.rca75',
      'RCA 75 ohm',
      8.4,
      8.4,
      pitchMm: 11,
      gender: true,
      mates: const ['conn.rca75', 'conn.rca'],
    ),
    _c(
      'conn.hd15',
      'HD-15 (VGA)',
      27.0,
      12.0,
      gender: true,
      mates: const ['conn.hd15'],
    ),
    _c(
      'conn.mini_din4',
      'Mini-DIN 4 (S-Video)',
      12.0,
      12.0,
      gender: true,
      mates: const ['conn.mini_din4'],
    ),
    // -- Analog / digital audio ------------------------------------------
    // SHARED SHELL with `conn.3_5mm_trs` below — the same 7 mm barrel,
    // which is the pairing `assets/catalog/sources.md` already makes for
    // the footprint ("applied to both TS/TRS variants of the same
    // barrel"). DR-057 §11.56.2.
    _c(
      'conn.3_5mm_ts',
      '3.5 mm mono (TS)',
      7.0,
      7.0,
      pitchMm: 10,
      mates: const ['conn.3_5mm_ts', 'conn.3_5mm_trs'],
    ),
    _c(
      'conn.3_5mm_trs',
      '3.5 mm stereo (TRS)',
      7.0,
      7.0,
      pitchMm: 10,
      mates: const ['conn.3_5mm_trs', 'conn.3_5mm_ts'],
    ),
    _c(
      'conn.6_35mm_trs',
      '1/4 in TRS',
      10.0,
      10.0,
      mates: const ['conn.6_35mm_trs'],
    ),
    _c(
      'conn.xlr3',
      'XLR3',
      24.0,
      24.0,
      aliases: const ['xlr'],
      pitchMm: 27,
      gender: true,
      mates: const ['conn.xlr3'],
    ),
    // SHARED SHELL with `conn.xlr3` — sources.md says so in terms
    // ("XLR5 shares the XLR3 shell"). DR-057 §11.56.2.
    _c(
      'conn.xlr5',
      'XLR5',
      24.0,
      24.0,
      pitchMm: 27,
      gender: true,
      mates: const ['conn.xlr5'],
    ),
    _c(
      'conn.jis_f05',
      'JIS F05 (TOSLINK)',
      7.0,
      7.0,
      aliases: const ['toslink'],
      mates: const ['conn.jis_f05'],
    ),
    // -- Network -----------------------------------------------------------
    // `hdbt` LEFT THIS LIST AT DR-060 §11.59.5, and it was never a
    // connector name: HDBaseT is a transmission standard carried over
    // twisted pair, and the connector it lands on is this 8P8C. It now
    // lives on `video.hdbaset.aliases`, where resolving it also answers
    // the question `conn.rj45` cannot -- WHICH of the six families that
    // wear this shell was meant.
    //
    // `rj45` STAYS, for two reasons and the second is the load-bearing
    // one. It genuinely names the connector; and `portConnectorShortLabel`
    // prints `aliases.first.toUpperCase()` in the port grid's CONN column
    // and footer, so deleting it would silently turn every `RJ45` cell
    // M4-E shipped into `RJ45 (8P8C)`. Grep the readers before tidying
    // seeded data.
    _c(
      'conn.rj45',
      'RJ45 (8P8C)',
      15.0,
      13.0,
      aliases: const ['rj45'],
      pitchMm: 17,
      gender: true,
      mates: const ['conn.rj45'],
    ),
    _c(
      'conn.lc_duplex',
      'LC duplex',
      12.5,
      9.0,
      aliases: const ['lc'],
      pitchMm: 14,
      gender: true,
      mates: const ['conn.lc_duplex'],
    ),
    _c(
      'conn.sc',
      'SC fibre',
      13.0,
      13.0,
      gender: true,
      mates: const ['conn.sc'],
    ),
    _c(
      'conn.st',
      'ST fibre',
      10.0,
      10.0,
      gender: true,
      mates: const ['conn.st'],
    ),
    _c(
      'conn.sfp_cage',
      'SFP/SFP+/SFP28 cage',
      14.0,
      9.0,
      aliases: const ['sfp+'],
    ),
    // -- Control -------------------------------------------------------------
    _c(
      'conn.de9',
      'DE-9 (DB9)',
      31.0,
      13.0,
      aliases: const ['db9', '232'],
      pitchMm: 34,
      gender: true,
      mates: const ['conn.de9'],
    ),
    // `euro2` mirrors the `euro3` alias three lines down, which has been
    // here since M1. The id's tail normalises to `euroblock2`, so the
    // spelling docs/06 §4.1's table actually types reached nothing.
    //
    // THIS ENTRY IS LOAD-BEARING AND NOT A CONVENIENCE. `euro2` also
    // names `audio.speaker_lowz` (DR-060 §11.59.10(b)), whose default
    // connector is `conn.binding_post`, so WITHOUT this line the token
    // would author a low-Z speaker port on a binding post. A named
    // connector beating the family's default is §11.59.4's two-registry
    // split, and it is the same mechanism `c13` forced.
    _c(
      'conn.euroblock_2',
      'Euroblock 2-pole',
      9.0,
      10.0,
      aliases: const ['euro2'],
      gender: true,
      mates: const ['conn.euroblock_2'],
    ),
    _c(
      'conn.euroblock_3',
      'Euroblock 3-pole',
      12.5,
      10.0,
      aliases: const ['euro3'],
      pitchMm: 15,
      gender: true,
      mates: const ['conn.euroblock_3'],
    ),
    _c(
      'conn.euroblock_5',
      'Euroblock 5-pole',
      18.0,
      10.0,
      gender: true,
      mates: const ['conn.euroblock_5'],
    ),
    _c(
      'conn.phoenix_4',
      'Phoenix 4-pole (Cresnet)',
      18.0,
      10.0,
      gender: true,
      mates: const ['conn.phoenix_4'],
    ),
    _c('conn.screw_terminal', 'Screw terminal', 9.0, 10.0),
    _c('conn.knx_terminal', 'KNX bus terminal', 9.0, 10.0),
    // -- Passive / mechanical audio -----------------------------------------
    _c(
      'conn.binding_post',
      'Binding post',
      12.0,
      12.0,
      aliases: const ['bp'],
      pitchMm: 20,
      gender: true,
      mates: const ['conn.banana'],
    ),
    _c(
      'conn.banana',
      'Banana plug',
      10.0,
      10.0,
      gender: true,
      mates: const ['conn.binding_post'],
    ),
    _c(
      'conn.speakon_nl4',
      'SpeakON NL4',
      24.0,
      24.0,
      gender: true,
      mates: const ['conn.speakon_nl4'],
    ),
    _c(
      'conn.punchdown_110',
      '110 punchdown',
      20.0,
      10.0,
      aliases: const ['110'],
    ),
    _c('conn.keystone', 'Keystone jack', 16.0, 16.0),
    // -- Power -----------------------------------------------------------
    // SHARED SHELL with `conn.iec_c14` — the same body, one the inlet and
    // one the outlet, which is why sources.md gives the pair a single
    // footprint row. DR-057 §11.56.2.
    _c(
      'conn.iec_c13',
      'IEC C13',
      27.0,
      20.0,
      aliases: const ['c13'],
      pitchMm: 30,
      gender: true,
      mates: const ['conn.iec_c14'],
    ),
    _c(
      'conn.iec_c14',
      'IEC C14',
      27.0,
      20.0,
      aliases: const ['c14'],
      pitchMm: 30,
      gender: true,
      mates: const ['conn.iec_c13'],
    ),
    _c(
      'conn.iec_c19',
      'IEC C19',
      35.0,
      26.0,
      aliases: const ['c19'],
      gender: true,
      mates: const ['conn.iec_c20'],
    ),
    _c(
      'conn.iec_c20',
      'IEC C20',
      35.0,
      26.0,
      aliases: const ['c20'],
      gender: true,
      mates: const ['conn.iec_c19'],
    ),
    _c(
      'conn.nema_5_15p',
      'NEMA 5-15P',
      34.0,
      27.0,
      aliases: const ['5-15p'],
      // SHARED SHELL with `conn.nema_5_15r`, below. All four 5-15/5-20
      // variants sit on the same duplex yoke, which is why sources.md
      // gives the four a single footprint row. DR-057 §11.56.2.
      pitchMm: 38,
      gender: true,
      mates: const ['conn.nema_5_15r', 'conn.nema_5_20r'],
    ),
    _c(
      'conn.nema_5_15r',
      'NEMA 5-15R',
      34.0,
      27.0,
      aliases: const ['5-15r'],
      pitchMm: 38,
      gender: true,
      mates: const ['conn.nema_5_15p'],
    ),
    _c(
      'conn.nema_5_20p',
      'NEMA 5-20P',
      34.0,
      27.0,
      aliases: const ['5-20p'],
      pitchMm: 38, // shared shell, see `conn.nema_5_15p`
      gender: true,
      mates: const ['conn.nema_5_20r'],
    ),
    _c(
      'conn.nema_5_20r',
      'NEMA 5-20R',
      34.0,
      27.0,
      aliases: const ['5-20r'],
      pitchMm: 38, // shared shell, see `conn.nema_5_15p`
      gender: true,
      mates: const ['conn.nema_5_20p', 'conn.nema_5_15p'],
    ),
    _c(
      'conn.nema_l5_30p',
      'NEMA L5-30P (twist-lock)',
      32.0,
      32.0,
      aliases: const ['l5-30p'],
      gender: true,
    ),
    _c(
      'conn.barrel_dc',
      'DC barrel',
      8.0,
      8.0,
      aliases: const ['dc'],
      gender: true,
      mates: const ['conn.barrel_dc'],
    ),
    // -- No panel cutout (§5.1 states their footprint column as "no") -----
    //
    // NULL FOOTPRINTS, NOT ABSENT ENTRIES, and the distinction is the
    // whole point. These three shipped as absent while this function was
    // only a footprint table, which was coherent. DR-010 then wired it in
    // as `Registries.connectorTypes` — the connector registry itself —
    // and absence silently changed meaning from "has no panel cutout" to
    // "IS NOT A CONNECTOR". 35 seeded ports across 8 templates and four
    // signal families (`power.ac_hardwired`, `power.bonding`,
    // `structure.undetermined`, `structure.pathway`) name these ids, so
    // every one of those references dangled — in the seed, and in the
    // `connectors` map of every document written since, including the
    // four shipped starters.
    //
    // `footprintWidth`/`footprintHeight` are nullable precisely for this
    // (registries.dart: "Both null means no footprint has been authored
    // yet — never estimated"), so the honest encoding is a real
    // `ConnectorTypeDef` carrying null dimensions. G4 is satisfied by the
    // nulls; resolution is satisfied by the entries existing.
    _cNoFootprint('conn.hardwired', 'Hardwired lead', aliases: const ['hw']),
    _cNoFootprint('conn.ground_lug', 'Ground lug', aliases: const ['gnd']),
    _cNoFootprint('conn.unterminated', 'Unterminated'),
  ];
  return {for (final c in all) c.id: c};
}
