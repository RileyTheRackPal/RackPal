// Seed catalog — "Control" (docs/catalog/seed-devices.md §3.4).

// A VALUE EQUAL TO THE DEFAULT IS A FACT HERE, NOT REDUNDANCY (DR-195,
// canon 11.194). A catalogue entry records what a device IS, and under
// CR-114 an explicit `0` is a measurement. Dropping an argument that
// happens to equal today's constructor default would hand the fact to the
// constructor, and the next change to that default would rewrite every
// device that had stated it with no diff here to show it.
// ignore_for_file: avoid_redundant_argument_values

import 'package:rackpal_core/src/catalog/catalog_ports.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';

const String kCatControl = 'Control';

Len _mm(num v) => Len.fromMillimetres(v);
Mass _kg(num v) => Mass.fromKilograms(v);

PowerProfile _power({
  required int nameplate,
  required int typical,
  required int pf,
}) => PowerProfile(
  nameplateWatts: nameplate,
  typicalWatts: typical,
  nominalVolts: 120,
  apparentVA: (typical * 1000 / pf).round(),
  powerFactor: pf,
  isContinuousLoad: true,
  inletPlug: PlugType.c14,
);

Map<String, TemplateBody> buildControlCatalog() {
  final out = <String, TemplateBody>{};

  // C01 · Control Processor.
  final c01 = PortBuilder();
  for (var i = 1; i <= 2; i++) {
    c01.p(
      'lan.$i',
      'LAN $i',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      bankLabel: 'Network',
    );
  }
  for (var i = 1; i <= 8; i++) {
    c01.p(
      'com.$i',
      'COM $i',
      connector: 'conn.euroblock_3',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'serial',
      bankLabel: 'Serial',
    );
  }
  for (var i = 1; i <= 8; i++) {
    c01.p(
      'ir.$i',
      'IR/SERIAL $i',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_emitter',
      dir: PortDirection.source,
      bank: 'irOut',
      bankLabel: 'IR Outputs',
      pinout: 'mono-tip-sleeve',
      // DUAL-HEAD FLASHER (M5-H2): one 3.5 mm plug, two heads, as
      // on the Episode IRF-2. Three or more needs another port or
      // an IR expansion block, which is its own device with its
      // own ports, so 2 is the physical bound and not a guess.
      maxConnections: 2,
    );
  }
  for (var i = 1; i <= 8; i++) {
    c01.p(
      'din.$i',
      'DIGITAL IN $i',
      connector: 'conn.euroblock_2',
      family: 'ctl.contact',
      dir: PortDirection.sink,
      bank: 'digitalIn',
      bankLabel: 'Digital Inputs',
    );
  }
  for (var i = 1; i <= 4; i++) {
    c01.p(
      'relay.$i',
      'RELAY $i',
      connector: 'conn.euroblock_3',
      family: 'ctl.contact',
      dir: PortDirection.source,
      bank: 'relays',
      bankLabel: 'Relays',
    );
  }
  c01
    ..p(
      'cresnet',
      'CRESNET',
      connector: 'conn.phoenix_4',
      family: 'ctl.cresnet',
      dir: PortDirection.busNode,
      bank: 'bus',
      bankLabel: 'Control Bus',
    )
    ..p(
      'setup',
      'SETUP',
      connector: 'conn.usb_c',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      face: Face.front,
      bank: 'bus',
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
  out['C01'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'CTL-PROC-1',
    displayName: 'Control Processor',
    description:
        'Carries eight of the ten ctl.* families the product ships — the '
        'IR and RS-232 requirement-4 types are reachable without a second '
        'control device.',
    category: kCatControl,
    primaryDomain: const SignalDomainId('ctl'),
    typePrefix: 'CTL',
    tags: const ['control', 'automation'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(280),
    connectorProjection: _mm(68),
    weight: _kg(3.2),
    power: _power(nameplate: 60, typical: 30, pf: 950),
    ports: c01.ports,
    banks: c01.banks,
  );

  // C02 · IR Distribution Block — the destructive-pinout hazard template.
  final c02 = PortBuilder()
    ..p(
      'ir.in.processor',
      'IR IN (from processor)',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.ir_receiver',
      dir: PortDirection.sink,
      bank: 'source',
      bankLabel: 'Source',
      pinout: 'xantech-stereo',
    );
  for (var i = 1; i <= 4; i++) {
    c02.p(
      'ir.rx.$i',
      'IR RX $i',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.ir_receiver',
      dir: PortDirection.sink,
      bank: 'rxIn',
      bankLabel: 'Receiver Inputs',
      pinout: 'xantech-stereo',
    );
  }
  for (var i = 1; i <= 16; i++) {
    c02.p(
      'emitter.$i',
      'EMITTER ${i.toString().padLeft(2, '0')}',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_emitter',
      dir: PortDirection.source,
      bank: 'emitterOut',
      bankLabel: 'Emitter Outputs',
      pinout: 'mono-tip-sleeve',
      // DUAL-HEAD FLASHER (M5-H2): one 3.5 mm plug, two heads, as
      // on the Episode IRF-2. Three or more needs another port or
      // an IR expansion block, which is its own device with its
      // own ports, so 2 is the physical bound and not a guess.
      maxConnections: 2,
    );
  }
  c02.p(
    'dc.in',
    '12V DC IN',
    connector: 'conn.barrel_dc',
    family: 'power.dc_low',
    dir: PortDirection.sink,
    bank: 'power',
    bankLabel: 'Power',
    nominalVoltage: 12,
    power: PortPowerSpec(role: PortPowerRole.inlet),
  );
  out['C02'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'IRB-4X16',
    displayName: 'IR Distribution Block',
    description:
        'Xantech/Niles receivers are tip=signal, ring=GND, sleeve=+12V; '
        'emitters are tip=IR, sleeve=GND. Plugging an emitter into a '
        'receiver jack destroys it. pinoutVariant is mandatory on every '
        '3.5 mm IR port here and is safety-adjacent (AC-052).',
    category: kCatControl,
    primaryDomain: const SignalDomainId('ctl'),
    typePrefix: 'IRB',
    glyph: DeviceGlyph.distribution,
    tags: const ['ir', 'distribution'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(140),
    connectorProjection: _mm(55),
    weight: _kg(0.9),
    power: _power(nameplate: 12, typical: 6, pf: 900),
    ports: c02.ports,
    banks: c02.banks,
  );

  // C03 · RS-232 / IP Gateway, 8-port.
  final c03 = PortBuilder();
  for (var i = 1; i <= 8; i++) {
    c03.p(
      'com.$i',
      'COM $i',
      connector: 'conn.de9',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'serial',
      bankLabel: 'Serial Ports',
    );
  }
  c03
    ..p(
      'lan',
      'LAN',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      bankLabel: 'Network',
    )
    ..p(
      'mgmt',
      'MGMT',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
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
  out['C03'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'SER-IP-8',
    displayName: 'RS-232 / IP Gateway, 8-port',
    description:
        'ctl.rs232 is P2P only — the one control family with no multi-drop '
        'story.',
    category: kCatControl,
    primaryDomain: const SignalDomainId('ctl'),
    typePrefix: 'SER',
    tags: const ['serial', 'gateway'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(230),
    connectorProjection: _mm(62),
    weight: _kg(2.3),
    power: _power(nameplate: 30, typical: 15, pf: 950),
    ports: c03.ports,
    banks: c03.banks,
  );

  return out;
}
