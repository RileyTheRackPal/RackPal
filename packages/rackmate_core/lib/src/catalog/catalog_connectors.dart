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

import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

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

ConnectorTypeDef _c(
  String id,
  String name,
  num widthMm,
  num heightMm, {
  List<String> aliases = const [],
}) => ConnectorTypeDef(
  id: ConnectorTypeId(id),
  displayName: name,
  aliases: aliases,
  footprintWidth: _mm(widthMm),
  footprintHeight: _mm(heightMm),
);

/// A registry entry for a connector that has no panel cutout to author.
/// Both dimensions stay null — unknown is never estimated (G4).
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
    _c('conn.hdmi_a', 'HDMI Type A', 15.1, 5.6, aliases: const ['hdmi']),
    _c('conn.hdmi_c', 'HDMI Type C (Mini)', 11.3, 4.2),
    _c('conn.hdmi_d', 'HDMI Type D (Micro)', 9.1, 3.4),
    _c('conn.dp', 'DisplayPort', 13.0, 5.0),
    _c('conn.mini_dp', 'Mini DisplayPort', 8.0, 4.0),
    _c('conn.usb_c', 'USB-C', 9.0, 3.5),
    // -- Analog video / RF -----------------------------------------------
    _c('conn.bnc75', 'BNC 75 ohm', 10.0, 10.0),
    _c('conn.bnc50', 'BNC 50 ohm', 10.0, 10.0),
    _c('conn.f_type', 'F-type', 9.5, 9.5),
    _c('conn.rca', 'RCA', 8.4, 8.4),
    _c('conn.rca75', 'RCA 75 ohm', 8.4, 8.4),
    _c('conn.hd15', 'HD-15 (VGA)', 27.0, 12.0),
    _c('conn.mini_din4', 'Mini-DIN 4 (S-Video)', 12.0, 12.0),
    // -- Analog / digital audio ------------------------------------------
    _c('conn.3_5mm_ts', '3.5 mm mono (TS)', 7.0, 7.0),
    _c('conn.3_5mm_trs', '3.5 mm stereo (TRS)', 7.0, 7.0),
    _c('conn.6_35mm_trs', '1/4 in TRS', 10.0, 10.0),
    _c('conn.xlr3', 'XLR3', 24.0, 24.0, aliases: const ['xlr']),
    _c('conn.xlr5', 'XLR5', 24.0, 24.0),
    _c(
      'conn.jis_f05',
      'JIS F05 (TOSLINK)',
      7.0,
      7.0,
      aliases: const ['toslink'],
    ),
    // -- Network -----------------------------------------------------------
    _c('conn.rj45', 'RJ45 (8P8C)', 15.0, 13.0, aliases: const ['rj45', 'hdbt']),
    _c('conn.lc_duplex', 'LC duplex', 12.5, 9.0, aliases: const ['lc']),
    _c('conn.sc', 'SC fibre', 13.0, 13.0),
    _c('conn.st', 'ST fibre', 10.0, 10.0),
    _c(
      'conn.sfp_cage',
      'SFP/SFP+/SFP28 cage',
      14.0,
      9.0,
      aliases: const ['sfp+'],
    ),
    // -- Control -------------------------------------------------------------
    _c('conn.de9', 'DE-9 (DB9)', 31.0, 13.0, aliases: const ['db9', '232']),
    _c('conn.euroblock_2', 'Euroblock 2-pole', 9.0, 10.0),
    _c(
      'conn.euroblock_3',
      'Euroblock 3-pole',
      12.5,
      10.0,
      aliases: const ['euro3'],
    ),
    _c('conn.euroblock_5', 'Euroblock 5-pole', 18.0, 10.0),
    _c('conn.phoenix_4', 'Phoenix 4-pole (Cresnet)', 18.0, 10.0),
    _c('conn.screw_terminal', 'Screw terminal', 9.0, 10.0),
    _c('conn.knx_terminal', 'KNX bus terminal', 9.0, 10.0),
    // -- Passive / mechanical audio -----------------------------------------
    _c('conn.binding_post', 'Binding post', 12.0, 12.0, aliases: const ['bp']),
    _c('conn.banana', 'Banana plug', 10.0, 10.0),
    _c('conn.speakon_nl4', 'SpeakON NL4', 24.0, 24.0),
    _c(
      'conn.punchdown_110',
      '110 punchdown',
      20.0,
      10.0,
      aliases: const ['110'],
    ),
    _c('conn.keystone', 'Keystone jack', 16.0, 16.0),
    // -- Power -----------------------------------------------------------
    _c('conn.iec_c13', 'IEC C13', 27.0, 20.0, aliases: const ['c13']),
    _c('conn.iec_c14', 'IEC C14', 27.0, 20.0, aliases: const ['c14']),
    _c('conn.iec_c19', 'IEC C19', 35.0, 26.0, aliases: const ['c19']),
    _c('conn.iec_c20', 'IEC C20', 35.0, 26.0, aliases: const ['c20']),
    _c('conn.nema_5_15p', 'NEMA 5-15P', 34.0, 27.0, aliases: const ['5-15p']),
    _c('conn.nema_5_15r', 'NEMA 5-15R', 34.0, 27.0, aliases: const ['5-15r']),
    _c('conn.nema_5_20p', 'NEMA 5-20P', 34.0, 27.0, aliases: const ['5-20p']),
    _c('conn.nema_5_20r', 'NEMA 5-20R', 34.0, 27.0, aliases: const ['5-20r']),
    _c(
      'conn.nema_l5_30p',
      'NEMA L5-30P (twist-lock)',
      32.0,
      32.0,
      aliases: const ['l5-30p'],
    ),
    _c('conn.barrel_dc', 'DC barrel', 8.0, 8.0, aliases: const ['dc']),
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
