// Seed catalog — "Sources" (docs/catalog/seed-devices.md §3.5).

import 'package:rackmate_core/src/catalog/catalog_ports.dart';
import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

const String kCatSources = 'Sources';

Len _mm(num v) => Len.fromMillimetres(v);
Mass _kg(num v) => Mass.fromKilograms(v);

Map<String, TemplateBody> buildSourcesCatalog() {
  final out = <String, TemplateBody>{};

  // S01 · Cable/Satellite Set-Top Box — the archetype every consumer source
  // forks from (a streaming player, disc player or console is a Device
  // Builder "Mirror bank" job from here — P3).
  final s01 = PortBuilder()..set('an', 'Analog stereo pair', SetKind.stereoPair);
  s01
    ..p(
      'rf.in',
      'RF IN',
      connector: 'conn.f_type',
      family: 'rf.catv',
      dir: PortDirection.sink,
      bank: 'rf',
      bankLabel: 'RF',
      impedance: 75,
    )
    ..p(
      'rf.loop',
      'RF OUT (loop)',
      connector: 'conn.f_type',
      family: 'rf.catv',
      dir: PortDirection.passive,
      bank: 'rf',
      impedance: 75,
    )
    ..p(
      'hdmi.out',
      'HDMI OUT',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'video',
      bankLabel: 'Video',
    )
    ..p(
      'audio.l',
      'AUDIO OUT L',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.source,
      bank: 'audio',
      bankLabel: 'Audio',
      setKey: 'an',
      setRole: 'L',
    )
    ..p(
      'audio.r',
      'AUDIO OUT R',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.source,
      bank: 'audio',
      setKey: 'an',
      setRole: 'R',
    )
    ..p(
      'coax.digital',
      'COAX DIGITAL',
      connector: 'conn.rca75',
      family: 'audio.spdif_coax',
      dir: PortDirection.source,
      bank: 'audio',
      impedance: 75,
    )
    ..p(
      'optical',
      'OPTICAL',
      connector: 'conn.jis_f05',
      family: 'audio.spdif_optical',
      dir: PortDirection.source,
      bank: 'audio',
    )
    ..p(
      'lan',
      'LAN',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'control',
      bankLabel: 'Control',
    )
    ..p(
      'usb',
      'USB',
      connector: 'conn.usb_c',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'control',
    )
    ..p(
      'ir.in',
      'IR IN',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.ir_receiver',
      dir: PortDirection.sink,
      bank: 'control',
      pinout: 'xantech-stereo',
    )
    ..p(
      'ac.in',
      'AC (captive cord)',
      connector: 'conn.nema_5_15p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['S01'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'STB-1',
    displayName: 'Cable / Satellite Set-Top Box',
    category: kCatSources,
    typePrefix: 'STB',
    tags: const ['source', 'hosted'],
    frontU: 0,
    rearU: 0,
    side: OccupancySide.none,
    mountMethod: MountMethod.hosted,
    bodyDepth: _mm(250),
    connectorProjection: _mm(70),
    weight: _kg(1.4),
    power: PowerProfile(
      nameplateWatts: 35,
      typicalWatts: 22,
      nominalVolts: 120,
      apparentVA: 24,
      powerFactor: 900,
      isContinuousLoad: true,
      outletsProvided: 0,
      outletsConsumed: 1,
      inletPlug: PlugType.nema515p,
    ),
    ports: s01.ports,
    banks: s01.banks,
    portSets: s01.portSets,
  );

  // S02 · Media Server / NAS — the only extraDeep rack-side template.
  final s02 = PortBuilder()
    ..p(
      'lan.1',
      'LAN 1',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      bankLabel: 'Network',
      linkSpeedMbps: 1000,
    )
    ..p(
      'lan.2',
      'LAN 2',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      linkSpeedMbps: 1000,
    )
    ..p(
      'sfp.1',
      'SFP+ 1',
      connector: 'conn.sfp_cage',
      family: 'net.dac',
      dir: PortDirection.bidirectional,
      bank: 'network',
      sfp: SfpFormFactor.sfpPlus,
      linkSpeedMbps: 10000,
    )
    ..p(
      'sfp.2',
      'SFP+ 2',
      connector: 'conn.sfp_cage',
      family: 'net.dac',
      dir: PortDirection.bidirectional,
      bank: 'network',
      sfp: SfpFormFactor.sfpPlus,
      linkSpeedMbps: 10000,
    )
    ..p(
      'hdmi',
      'HDMI',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'console',
      bankLabel: 'Console',
    )
    ..p(
      'usb.1',
      'USB 1',
      connector: 'conn.usb_c',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      face: Face.front,
      bank: 'console',
    )
    ..p(
      'usb.2',
      'USB 2',
      connector: 'conn.usb_c',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      face: Face.front,
      bank: 'console',
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
  out['S02'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'NAS-2U',
    displayName: 'Media Server / NAS',
    description:
        'The only extraDeep template in the catalog; exercises RCK-012 '
        '(front + rear depth + 50 mm allowance against usableDepth).',
    category: kCatSources,
    typePrefix: 'NAS',
    tags: const ['nas', 'server'],
    frontU: 2,
    rearU: 2,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(560),
    connectorProjection: _mm(80),
    weight: _kg(13.6),
    maxUnsupportedMass: _kg(7),
    power: PowerProfile(
      nameplateWatts: 350,
      typicalWatts: 160,
      nominalVolts: 120,
      apparentVA: 168,
      powerFactor: 950,
      isContinuousLoad: true,
      outletsProvided: 0,
      outletsConsumed: 2,
      inletPlug: PlugType.c14,
    ),
    ports: s02.ports,
    banks: s02.banks,
  );

  return out;
}
