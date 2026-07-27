// Seed catalog — "Video Distribution & Switching" (docs/catalog/seed-
// devices.md §3.1). One representative configuration per template id (P4's
// parametric variants are a Device Builder / picker concern, not a second
// catalog entry — §3.10 counts template ids, not expanded configurations).

import 'package:rackmate_core/src/catalog/catalog_ports.dart';
import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

const String kCatVideo = 'Video Distribution & Switching';

Len _mm(num v) => Len.fromMillimetres(v);
Mass _kg(num v) => Mass.fromKilograms(v);

PowerProfile _power({
  required int nameplate,
  required int typical,
  required int pf,
  int? standby,
  int outletsConsumed = 1,
}) => PowerProfile(
  nameplateWatts: nameplate,
  typicalWatts: typical,
  standbyWatts: standby,
  nominalVolts: 120,
  apparentVA: (typical * 1000 / pf).round(),
  powerFactor: pf,
  isContinuousLoad: true,
  outletsProvided: 0,
  outletsConsumed: outletsConsumed,
  inletPlug: PlugType.c14,
);

Map<String, TemplateBody> buildVideoCatalog() {
  final out = <String, TemplateBody>{};

  // V01 · HDMI/HDBaseT Matrix 8x8 — the flagship, worked example in the doc.
  final v01 = PortBuilder();
  for (var i = 1; i <= 8; i++) {
    v01.p(
      'hdmi.in.$i',
      'HDMI IN $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.sink,
      bank: 'hdmiIn',
      bankLabel: 'HDMI Inputs',
    );
  }
  for (var i = 1; i <= 8; i++) {
    v01.p(
      'hdbt.out.$i',
      'HDBT OUT $i',
      connector: 'conn.rj45',
      family: 'video.hdbaset',
      dir: PortDirection.source,
      bank: 'hdbtOut',
      bankLabel: 'HDBaseT Outputs',
      gender: Gender.female,
    );
  }
  for (var i = 1; i <= 8; i++) {
    v01.p(
      'hdmi.out.$i',
      'HDMI OUT $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'hdmiOut',
      bankLabel: 'Mirrored HDMI Outputs',
    );
  }
  for (var i = 1; i <= 8; i++) {
    v01.p(
      'aud.out.$i',
      'AUD OUT $i',
      connector: 'conn.euroblock_3',
      family: 'audio.line_bal',
      dir: PortDirection.source,
      bank: 'audOut',
      bankLabel: 'Zone Audio',
      balanced: true,
    );
  }
  v01
    ..p(
      'ir.in',
      'IR IN',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.ir_receiver',
      dir: PortDirection.sink,
      bank: 'control',
      bankLabel: 'Control',
      bankSide: SymbolSide.top,
      pinout: 'xantech-stereo',
    );
  for (var i = 1; i <= 8; i++) {
    v01.p(
      'ir.out.$i',
      'IR OUT $i',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_emitter',
      dir: PortDirection.source,
      bank: 'control',
      pinout: 'mono-tip-sleeve',
    );
  }
  v01
    ..p(
      'lan',
      'LAN',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'control',
    )
    ..p(
      'rs232',
      'RS-232',
      connector: 'conn.de9',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'control',
    )
    ..p(
      'ac.in',
      'AC IN',
      connector: 'conn.iec_c14',
      family: 'power.ac_iec',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      bankSide: SymbolSide.bottom,
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['V01'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'MTX-8X8-HDBT',
    displayName: 'HDMI/HDBaseT Matrix 8x8',
    description:
        'Generic 8-input, 8-output HDMI matrix with mirrored HDBaseT zone '
        'outputs, de-embedded balanced zone audio, per-output IR, LAN and '
        'RS-232 control.',
    category: kCatVideo,
    typePrefix: 'MTX',
    tags: const ['hdbaset', '4k60', 'matrix'],
    frontU: 3,
    rearU: 3,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    alternateMountMethods: const [MountMethod.shelf],
    bodyDepth: _mm(330),
    connectorProjection: _mm(68),
    weight: _kg(7.3),
    maxUnsupportedMass: _kg(7),
    requiresClearanceAboveU: 0,
    power: _power(nameplate: 90, typical: 55, pf: 950, standby: 8),
    ports: v01.ports,
    banks: v01.banks,
    portSets: v01.portSets,
  );

  // V02 · HDMI Matrix 4x4.
  final v02 = PortBuilder();
  for (var i = 1; i <= 4; i++) {
    v02.p(
      'hdmi.in.$i',
      'HDMI IN $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.sink,
      bank: 'hdmiIn',
      bankLabel: 'HDMI Inputs',
    );
  }
  for (var i = 1; i <= 4; i++) {
    v02.p(
      'hdmi.out.$i',
      'HDMI OUT $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'hdmiOut',
      bankLabel: 'HDMI Outputs',
    );
  }
  for (var i = 1; i <= 4; i++) {
    v02.p(
      'audio.out.$i',
      'AUDIO OUT $i',
      connector: 'conn.rca75',
      family: 'audio.spdif_coax',
      dir: PortDirection.source,
      bank: 'deembed',
      bankLabel: 'De-embedded Audio',
      impedance: 75,
    );
  }
  v02
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
      'rs232',
      'RS-232',
      connector: 'conn.de9',
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
  out['V02'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'MTX-4X4-HDMI',
    displayName: 'HDMI Matrix 4x4',
    category: kCatVideo,
    typePrefix: 'MTX',
    tags: const ['hdmi', 'matrix'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(280),
    connectorProjection: _mm(62),
    weight: _kg(5.4),
    power: _power(nameplate: 30, typical: 18, pf: 950, outletsConsumed: 1),
    ports: v02.ports,
    banks: v02.banks,
  );

  // V03 · HDMI Matrix 16x16.
  final v03 = PortBuilder();
  for (var i = 1; i <= 16; i++) {
    v03.p(
      'hdmi.in.$i',
      'HDMI IN ${i.toString().padLeft(2, '0')}',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.sink,
      bank: 'hdmiIn',
      bankLabel: 'HDMI Inputs',
    );
  }
  for (var i = 1; i <= 16; i++) {
    v03.p(
      'hdmi.out.$i',
      'HDMI OUT ${i.toString().padLeft(2, '0')}',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'hdmiOut',
      bankLabel: 'HDMI Outputs',
    );
  }
  for (var i = 1; i <= 16; i++) {
    v03.p(
      'aud.out.$i',
      'AUD OUT ${i.toString().padLeft(2, '0')}',
      connector: 'conn.euroblock_3',
      family: 'audio.line_bal',
      dir: PortDirection.source,
      bank: 'audOut',
      bankLabel: 'De-embedded Audio',
      balanced: true,
    );
  }
  v03
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
      'rs232',
      'RS-232',
      connector: 'conn.de9',
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
      'AC IN',
      connector: 'conn.iec_c14',
      family: 'power.ac_iec',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['V03'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'MTX-16X16-HDMI',
    displayName: 'HDMI Matrix 16x16',
    category: kCatVideo,
    typePrefix: 'MTX',
    tags: const ['hdmi', 'matrix', 'commercial'],
    frontU: 4,
    rearU: 4,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(430),
    connectorProjection: _mm(72),
    weight: _kg(14.1),
    maxUnsupportedMass: _kg(7),
    requiresClearanceAboveU: 1,
    power: _power(nameplate: 180, typical: 110, pf: 950),
    ports: v03.ports,
    banks: v03.banks,
  );

  // V04 · HDMI Distribution Amplifier 1x8.
  final v04 = PortBuilder()
    ..p(
      'hdmi.in',
      'HDMI IN',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.sink,
      bank: 'in',
      bankLabel: 'Input',
    );
  for (var i = 1; i <= 8; i++) {
    v04.p(
      'hdmi.out.$i',
      'HDMI OUT $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'out',
      bankLabel: 'Outputs',
    );
  }
  v04.p(
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
  out['V04'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'DA-1X8-HDMI',
    displayName: 'HDMI Distribution Amplifier 1x8',
    category: kCatVideo,
    typePrefix: 'DA',
    tags: const ['hdmi', 'distribution'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(180),
    connectorProjection: _mm(60),
    weight: _kg(2.3),
    power: _power(nameplate: 25, typical: 15, pf: 900),
    ports: v04.ports,
    banks: v04.banks,
  );

  // V05 · Presentation Switcher / Scaler 4x1.
  final v05 = PortBuilder();
  for (var i = 1; i <= 3; i++) {
    v05.p(
      'hdmi.in.$i',
      'HDMI IN $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.sink,
      bank: 'videoIn',
      bankLabel: 'Video Inputs',
    );
  }
  v05
    ..p(
      'usbc.in',
      'USB-C IN',
      connector: 'conn.usb_c',
      family: 'video.usbc_dpalt',
      dir: PortDirection.sink,
      bank: 'videoIn',
    )
    ..p(
      'hdmi.out',
      'HDMI OUT',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'videoOut',
      bankLabel: 'Video Outputs',
    )
    ..p(
      'hdbt.out',
      'HDBT OUT',
      connector: 'conn.rj45',
      family: 'video.hdbaset',
      dir: PortDirection.source,
      bank: 'videoOut',
      gender: Gender.female,
    )
    ..p(
      'audio.in',
      'AUDIO IN',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.sink,
      bank: 'audio',
      bankLabel: 'Audio',
    )
    ..p(
      'audio.out',
      'AUDIO OUT',
      connector: 'conn.euroblock_5',
      family: 'audio.line_bal',
      dir: PortDirection.source,
      bank: 'audio',
      balanced: true,
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
      'rs232',
      'RS-232',
      connector: 'conn.de9',
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
      'service',
      'SERVICE',
      connector: 'conn.usb_c',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      face: Face.front,
      bank: 'control',
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
  out['V05'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'SCL-4X1',
    displayName: 'Presentation Switcher / Scaler 4x1',
    category: kCatVideo,
    typePrefix: 'SCL',
    tags: const ['presentation', 'commercial'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(230),
    connectorProjection: _mm(66),
    weight: _kg(3.6),
    power: _power(nameplate: 45, typical: 28, pf: 950),
    ports: v05.ports,
    banks: v05.banks,
  );

  // V06 · HDBaseT Extender, transmitter half (P4's `role` parameter — the
  // receiver half is a fork of this shape in the real product; modelled
  // here as the shipped, hosted TX half).
  final v06 = PortBuilder()
    ..p(
      'hdmi.in',
      'HDMI IN',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.sink,
      bank: 'video',
      bankLabel: 'Video',
    )
    ..p(
      'hdmi.loop',
      'HDMI LOOP OUT',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'video',
    )
    ..p(
      'hdbt.out',
      'HDBT OUT',
      connector: 'conn.rj45',
      family: 'video.hdbaset',
      dir: PortDirection.source,
      bank: 'video',
      gender: Gender.female,
    )
    ..p(
      'ir.in',
      'IR IN',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.ir_receiver',
      dir: PortDirection.sink,
      bank: 'control',
      bankLabel: 'Control',
      pinout: 'xantech-stereo',
    )
    ..p(
      'ir.out',
      'IR OUT',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_emitter',
      dir: PortDirection.source,
      bank: 'control',
      pinout: 'mono-tip-sleeve',
    )
    ..p(
      'rs232',
      'RS-232',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'control',
    )
    ..p(
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
  out['V06'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'TX-HDBT-1',
    displayName: 'HDBaseT Extender (Transmitter)',
    description:
        'Sold as a TX/RX kit; the receiver half is a Device Builder fork '
        'of this shape (P4 — the role parameter is used for extender '
        'halves only).',
    category: kCatVideo,
    typePrefix: 'TX',
    tags: const ['hdbaset', 'extender'],
    frontU: 0,
    rearU: 0,
    side: OccupancySide.none,
    mountMethod: MountMethod.hosted,
    widthClass: WidthClass.half,
    nominalSpanTwelfths: 6,
    bodyDepth: _mm(110),
    connectorProjection: _mm(55),
    weight: _kg(0.55),
    power: _power(nameplate: 12, typical: 8, pf: 900, outletsConsumed: 0),
    ports: v06.ports,
    banks: v06.banks,
  );

  // V07 · AVoIP Endpoint, encoder half.
  final v07 = PortBuilder()
    ..p(
      'hdmi.in',
      'HDMI IN',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.sink,
      bank: 'video',
      bankLabel: 'Video',
    )
    ..p(
      'hdmi.loop',
      'HDMI LOOP OUT',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'video',
    )
    ..p(
      'network',
      'NETWORK',
      connector: 'conn.rj45',
      family: 'video.avoip',
      dir: PortDirection.bidirectional,
      bank: 'network',
      bankLabel: 'Network',
      poe: PoeSpec(role: PoeRole.pd, standard: PoeStandard.af, poeClass: 3),
    )
    ..p(
      'analog.in',
      'ANALOG IN',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.sink,
      bank: 'audio',
      bankLabel: 'Audio',
    )
    ..p(
      'analog.out',
      'ANALOG OUT',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.source,
      bank: 'audio',
    )
    ..p(
      'ir.out',
      'IR OUT',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_emitter',
      dir: PortDirection.source,
      bank: 'control',
      bankLabel: 'Control',
      pinout: 'mono-tip-sleeve',
    )
    ..p(
      'rs232',
      'RS-232',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'control',
    )
    ..p(
      'dc.in',
      '12V DC IN (opt)',
      connector: 'conn.barrel_dc',
      family: 'power.dc_low',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      nominalVoltage: 12,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['V07'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'ENC-AVOIP-1',
    displayName: 'AVoIP Endpoint (Encoder)',
    description:
        'Sold as an ENC/DEC kit; the decoder half is a Device Builder fork '
        'of this shape.',
    category: kCatVideo,
    typePrefix: 'ENC',
    tags: const ['avoip', 'sdvoe'],
    frontU: 0,
    rearU: 0,
    side: OccupancySide.none,
    mountMethod: MountMethod.hosted,
    widthClass: WidthClass.half,
    nominalSpanTwelfths: 6,
    bodyDepth: _mm(125),
    connectorProjection: _mm(55),
    weight: _kg(0.7),
    power: PowerProfile(
      nameplateWatts: 12,
      typicalWatts: 9,
      nominalVolts: 48,
      outletsProvided: 0,
      outletsConsumed: 0,
      poeBudgetWatts: null,
    ),
    ports: v07.ports,
    banks: v07.banks,
  );

  return out;
}
