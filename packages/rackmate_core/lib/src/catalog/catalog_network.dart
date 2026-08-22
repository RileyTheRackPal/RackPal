// Seed catalog — "Network & Cabling Infrastructure" (docs/catalog/seed-
// devices.md §3.3).

import 'package:rackmate_core/src/catalog/catalog_ports.dart';
import 'package:rackmate_core/src/model/device_glyph.dart';
import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

const String kCatNetwork = 'Network & Cabling Infrastructure';

Len _mm(num v) => Len.fromMillimetres(v);
Mass _kg(num v) => Mass.fromKilograms(v);

PowerProfile _power({
  required int nameplate,
  required int typical,
  required int pf,
  int outletsConsumed = 1,
  int? poeBudget,
}) => PowerProfile(
  nameplateWatts: nameplate,
  typicalWatts: typical,
  nominalVolts: 120,
  apparentVA: (typical * 1000 / pf).round(),
  powerFactor: pf,
  isContinuousLoad: true,
  outletsProvided: 0,
  outletsConsumed: outletsConsumed,
  inletPlug: PlugType.c14,
  poeBudgetWatts: poeBudget,
);

Map<String, TemplateBody> buildNetworkCatalog() {
  final out = <String, TemplateBody>{};

  // N01 · PoE Switch, 48-port (P4 param 8/24/48; 48-port shown).
  final n01 = PortBuilder();
  for (var i = 1; i <= 48; i++) {
    n01.p(
      'access.$i',
      i.toString().padLeft(2, '0'),
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'access',
      bankLabel: 'Access Ports',
      linkSpeedMbps: 1000,
      poe: PoeSpec(role: PoeRole.pse, standard: PoeStandard.btType3),
    );
  }
  for (var i = 1; i <= 4; i++) {
    n01.p(
      'uplink.$i',
      'SFP28 $i',
      connector: 'conn.sfp_cage',
      family: 'net.dac',
      dir: PortDirection.bidirectional,
      bank: 'uplinks',
      bankLabel: 'Uplinks',
      sfp: SfpFormFactor.sfp28,
      linkSpeedMbps: 25000,
    );
  }
  n01
    ..p(
      'mgmt.oob',
      'OOB MGMT',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'mgmt',
      bankLabel: 'Management',
    )
    ..p(
      'console',
      'CONSOLE',
      connector: 'conn.de9',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      face: Face.front,
      bank: 'mgmt',
    )
    ..p(
      'psu.a',
      'PSU A',
      connector: 'conn.iec_c14',
      family: 'power.ac_iec',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    )
    ..p(
      'psu.b',
      'PSU B',
      connector: 'conn.iec_c14',
      family: 'power.ac_iec',
      dir: PortDirection.sink,
      bank: 'power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['N01'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'SW-48-POE',
    displayName: 'PoE Switch, 48-port',
    description:
        'Redundant dual PSU — two inlets means outletsConsumed: 2, and the '
        'chip strip outlet rollup depends on every template being honest '
        'about that.',
    category: kCatNetwork,
    typePrefix: 'SW',
    tags: const ['poe', 'switch'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(300),
    connectorProjection: _mm(50),
    weight: _kg(7.7),
    // 7.7 kg is over the 7 kg front-ear limit docs/catalog/seed-devices.md
    // §3 states as the `rackEars` default (AC-028), so RCK-013 must have an
    // object to fire on here. It was missing until the catalog's 1000x mass
    // error was fixed: every template read as ~8 g, so seed_catalog_test's
    // `weightKg > 7` gate never once ran.
    maxUnsupportedMass: _kg(7),
    requiresClearanceAboveU: 1,
    power: _power(
      nameplate: 900,
      typical: 380,
      pf: 950,
      outletsConsumed: 2,
      poeBudget: 740,
    ),
    ports: n01.ports,
    banks: n01.banks,
  );

  // N02 · Router / Firewall.
  final n02 = PortBuilder();
  for (var i = 1; i <= 2; i++) {
    n02.p(
      'wan.$i',
      'WAN $i',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'wan',
      bankLabel: 'WAN',
      linkSpeedMbps: 1000,
    );
  }
  for (var i = 1; i <= 8; i++) {
    n02.p(
      'lan.$i',
      'LAN $i',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'lan',
      bankLabel: 'LAN',
      linkSpeedMbps: 1000,
    );
  }
  for (var i = 1; i <= 2; i++) {
    n02.p(
      'sfp.$i',
      'SFP+ $i',
      connector: 'conn.sfp_cage',
      family: 'net.dac',
      dir: PortDirection.bidirectional,
      bank: 'fibre',
      bankLabel: 'Fibre',
      sfp: SfpFormFactor.sfpPlus,
      linkSpeedMbps: 10000,
    );
  }
  n02
    ..p(
      'mgmt',
      'MGMT',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'mgmt',
      bankLabel: 'Management',
    )
    ..p(
      'console',
      'CONSOLE',
      connector: 'conn.de9',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      face: Face.front,
      bank: 'mgmt',
    )
    ..p(
      'ac.in',
      'AC IN',
      connector: 'conn.iec_c14',
      family: 'power.ac_iec',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['N02'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'FW-RTR-1',
    displayName: 'Router / Firewall',
    category: kCatNetwork,
    typePrefix: 'FW',
    tags: const ['router', 'firewall'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(330),
    connectorProjection: _mm(60),
    weight: _kg(4.1),
    power: _power(nameplate: 120, typical: 55, pf: 950),
    ports: n02.ports,
    banks: n02.banks,
  );

  // N03 · Patch Panel, 24-port (P4 param 12/24/48; 24-port shown).
  final n03 = PortBuilder();
  final pairs = <PassthroughPairDef>[];
  for (var i = 1; i <= 24; i++) {
    final n = i.toString().padLeft(2, '0');
    final frontKey = 'front.$i';
    final rearKey = 'rear.$i';
    n03
      ..p(
        frontKey,
        n,
        connector: 'conn.rj45',
        family: 'net.ethernet',
        dir: PortDirection.passive,
        face: Face.front,
        bank: 'front',
        bankLabel: 'Front Jacks',
      )
      ..p(
        rearKey,
        n,
        connector: 'conn.punchdown_110',
        family: 'net.ethernet',
        dir: PortDirection.passive,
        bank: 'rear',
        bankLabel: 'Rear Punchdown',
      );
    pairs.add(
      PassthroughPairDef(
        frontKey: PortKey(frontKey),
        rearKey: PortKey(rearKey),
        sameNet: true,
      ),
    );
  }
  out['N03'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'PP-24',
    displayName: 'Patch Panel, 24-port',
    description:
        'Rear ports are 110 punchdown, not RJ45 — modelling both faces as '
        'RJ45 is the error that makes the Termination Schedule wrong on '
        'the one column the trim tech actually needs (AC-025).',
    category: kCatNetwork,
    typePrefix: 'PP',
    glyph: DeviceGlyph.patchPanel,
    tags: const ['patchpanel', 'structured-cabling'],
    frontU: 1,
    rearU: 0,
    side: OccupancySide.front,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(60),
    weight: _kg(1.4),
    isPassthrough: true,
    passthroughPairs: pairs,
    power: PowerProfile(),
    ports: n03.ports,
    banks: n03.banks,
  );

  // N04 · Fibre Enclosure / LIU, 24-fibre.
  final n04 = PortBuilder();
  for (var i = 1; i <= 12; i++) {
    n04.p(
      'lc.$i',
      'LC ${i.toString().padLeft(2, '0')}',
      connector: 'conn.lc_duplex',
      family: 'net.fiber_sm',
      dir: PortDirection.passive,
      face: Face.front,
      bank: 'front',
      bankLabel: 'Front Adapters',
      fiberMode: FiberMode.singleMode,
    );
  }
  for (var i = 1; i <= 24; i++) {
    n04.p(
      'splice.$i',
      'SPL ${i.toString().padLeft(2, '0')}',
      connector: 'conn.unterminated',
      family: 'net.fiber_sm',
      dir: PortDirection.passive,
      bank: 'rear',
      bankLabel: 'Rear Splice Tray',
      fiberMode: FiberMode.singleMode,
    );
  }
  out['N04'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'LIU-24-SM',
    displayName: 'Fibre Enclosure / LIU, 24-fibre',
    category: kCatNetwork,
    typePrefix: 'LIU',
    glyph: DeviceGlyph.patchPanel,
    tags: const ['fibre', 'liu'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(240),
    connectorProjection: _mm(55),
    weight: _kg(2.7),
    isPassthrough: true,
    power: PowerProfile(),
    ports: n04.ports,
    banks: n04.banks,
  );

  return out;
}
