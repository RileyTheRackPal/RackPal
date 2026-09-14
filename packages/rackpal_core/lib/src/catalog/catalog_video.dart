// Seed catalog — "Video Distribution & Switching" (docs/catalog/seed-
// devices.md §3.1). One representative configuration per template id (P4's
// parametric variants are a Device Builder / picker concern, not a second
// catalog entry — §3.10 counts template ids, not expanded configurations).

import 'package:rackpal_core/src/catalog/catalog_ports.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';

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
  v01..p(
    'ir.in',
    'IR IN',
    connector: 'conn.3_5mm_ts',
    family: 'ctl.ir_direct',
    dir: PortDirection.sink,
    bank: 'control',
    bankLabel: 'Control',
    bankSide: SymbolSide.top,
    pinout: 'mono-tip-sleeve',
    accepts: const ['ctl.ir_emitter'],
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
      // DUAL-HEAD FLASHER (M5-H2): one 3.5 mm plug, two heads, as
      // on the Episode IRF-2. Three or more needs another port or
      // an IR expansion block, which is its own device with its
      // own ports, so 2 is the physical bound and not a guess.
      maxConnections: 2,
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
    primaryDomain: const SignalDomainId('video.digital'),
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
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_direct',
      dir: PortDirection.sink,
      bank: 'control',
      pinout: 'mono-tip-sleeve',
      accepts: const ['ctl.ir_emitter'],
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
    primaryDomain: const SignalDomainId('video.digital'),
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
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_direct',
      dir: PortDirection.sink,
      bank: 'control',
      pinout: 'mono-tip-sleeve',
      accepts: const ['ctl.ir_emitter'],
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
    primaryDomain: const SignalDomainId('video.digital'),
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
    primaryDomain: const SignalDomainId('video.digital'),
    typePrefix: 'DA',
    glyph: DeviceGlyph.distribution,
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
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_direct',
      dir: PortDirection.sink,
      bank: 'control',
      pinout: 'mono-tip-sleeve',
      accepts: const ['ctl.ir_emitter'],
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
    primaryDomain: const SignalDomainId('video.digital'),
    typePrefix: 'SCL',
    glyph: DeviceGlyph.switcher,
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
      // §540's `[poh:pse]`, which §367 maps to a `PoeSpec` on `net.poh`.
      // TRANSCRIBED AT `#813`, having been specified since M1 and never
      // written: the annotation was in the doc and the argument was not
      // in the code, which `#812` found only because it added the
      // receiver's matching `[poh:pd]` beside it.
      //
      // THIS IS THE END THAT SUPPLIES THE POWER, and it is the reason
      // `SIG-001` exists at all: docs/01:470 and the seed registry both
      // record that PoH runs *"up to 100 W over four pairs"* and *"can
      // damage the switch"*. A PSE role on this port is the datum that
      // sentence is about.
      //
      // `standard` IS ABSENT, exactly as on the receiver's inlet and for
      // the same reason (G4). `PoeStandard` is `{af, at, btType3,
      // btType4}`, IEEE 802.3 and nothing else, while PoH *"is based on
      // 802.3at but modified, and is NOT interoperable with a standard
      // PoE PSE"*. Naming one of those four to fill the field would be a
      // false standard on a safety-adjacent one.
      //
      // AND NO `watts` EITHER. 100 W is the SPEC'S CEILING rather than
      // this archetype's figure, and AC-052 admits a published standard
      // or a representative value, not a ceiling wearing the costume of
      // a measurement. An absent watt figure is unknown, which is true.
      poe: PoeSpec(role: PoeRole.pse),
    )
    ..p(
      'ir.in',
      'IR IN',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_direct',
      dir: PortDirection.sink,
      bank: 'control',
      bankLabel: 'Control',
      pinout: 'mono-tip-sleeve',
      accepts: const ['ctl.ir_emitter'],
    )
    ..p(
      'ir.out',
      'IR OUT',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_emitter',
      dir: PortDirection.source,
      bank: 'control',
      pinout: 'mono-tip-sleeve',
      // DUAL-HEAD FLASHER (M5-H2): one 3.5 mm plug, two heads, as
      // on the Episode IRF-2. Three or more needs another port or
      // an IR expansion block, which is its own device with its
      // own ports, so 2 is the physical bound and not a guess.
      maxConnections: 2,
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
    primaryDomain: const SignalDomainId('video.digital'),
    typePrefix: 'TX',
    glyph: DeviceGlyph.extender,
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
      // DUAL-HEAD FLASHER (M5-H2): one 3.5 mm plug, two heads, as
      // on the Episode IRF-2. Three or more needs another port or
      // an IR expansion block, which is its own device with its
      // own ports, so 2 is the physical bound and not a guess.
      maxConnections: 2,
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
    primaryDomain: const SignalDomainId('video.digital'),
    typePrefix: 'ENC',
    glyph: DeviceGlyph.extender,
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

/// P4's DERIVED role halves for the two video templates that carry the
/// role parameter — V06's receiver and V07's decoder.
///
/// ═══════════════════════════════════════════════════════════════════════
/// NOT CATALOG ENTRIES, WHICH IS THE WHOLE POINT
/// ═══════════════════════════════════════════════════════════════════════
/// [buildVideoCatalog] still returns seven bodies and §3.10's count is
/// untouched. P4 rejects *"four separate templates, which spends four of
/// thirty rack-side slots on two products"* and §540 rejects *"separate
/// `TX` and `RX` templates"* by name, so these live beside their bases and
/// are reached through `catalog_roles.dart` rather than through the map.
///
/// TRANSCRIBED FROM §540 AND §575, NOT DERIVED FROM THE BASES. The halves
/// are not a direction flip: the receiver DROPS `HDMI IN` and renames
/// `HDMI LOOP OUT` to `HDMI OUT`, seven ports becoming six, and the
/// decoder drops two of the encoder's eight. P4's summary line says the
/// halves *"differ only in port direction"*; the per-template listings say
/// otherwise and they are the specific spec.
///
/// EVERY PHYSICAL FACT IS THE BASE'S, which is P4's stated reason for one
/// template rather than two: *"the halves share every physical fact"*. The
/// receiver is the one exception the doc itself makes, and it makes it
/// explicitly — `notInRack`, no depth, and **0 W** because its power comes
/// down the `net.poh` conductor from the transmitter (§540's note).
Map<String, TemplateBody> buildVideoRoleVariants() {
  final out = <String, TemplateBody>{};

  // V06 · HDBaseT Extender, RECEIVER half (§540).
  final v06rx = PortBuilder()
    ..p(
      'hdbt.in',
      'HDBT IN',
      connector: 'conn.rj45',
      family: 'video.hdbaset',
      dir: PortDirection.sink,
      bank: 'video',
      bankLabel: 'Video',
      gender: Gender.female,
      // §540's `[poh:pd]`, which §367 maps to a `PoeSpec` on `net.poh`.
      //
      // `standard` IS DELIBERATELY ABSENT, AND THAT IS G4 RATHER THAN AN
      // OVERSIGHT. `PoeStandard` is `{af, at, btType3, btType4}`, which is
      // IEEE 802.3 and nothing else, and docs/01:470 is explicit that PoH
      // *"is based on 802.3at but modified, and is NOT interoperable with
      // a standard PoE PSE"*. Naming any of those four here would put a
      // false standard on a safety-adjacent field to avoid an empty one,
      // which is what G4 forbids. The ROLE is known and shipped; the
      // standard is unknown to this vocabulary and stays absent.
      poe: PoeSpec(role: PoeRole.pd),
    )
    ..p(
      'hdmi.out',
      'HDMI OUT',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'video',
    )
    ..p(
      'ir.in',
      'IR IN',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_direct',
      dir: PortDirection.sink,
      bank: 'control',
      bankLabel: 'Control',
      pinout: 'mono-tip-sleeve',
      accepts: const ['ctl.ir_emitter'],
    )
    ..p(
      'ir.out',
      'IR OUT',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_emitter',
      dir: PortDirection.source,
      bank: 'control',
      pinout: 'mono-tip-sleeve',
      // DUAL-HEAD FLASHER (M5-H2): one 3.5 mm plug, two heads, as
      // on the Episode IRF-2. Three or more needs another port or
      // an IR expansion block, which is its own device with its
      // own ports, so 2 is the physical bound and not a guess.
      maxConnections: 2,
    )
    ..p(
      'rs232',
      'RS-232',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.rs232',
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
  out['V06:receiver'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'RX-HDBT-1',
    displayName: 'HDBaseT Extender (Receiver)',
    description:
        'The receiver half of the TX/RX kit V06 ships as its transmitter. '
        'Powered over the link (PoH), so it draws nothing from the rack.',
    category: kCatVideo,
    typePrefix: 'RX',
    glyph: DeviceGlyph.extender,
    tags: const ['hdbaset', 'extender'],
    // `notInRack` AND NO DEPTH, both from §540. The receiver lives at the
    // display end of the run, which is the whole reason the kit exists, so
    // it occupies no U and has no rack depth to state.
    mountMethod: MountMethod.notInRack,
    weight: _kg(0.55),
    // ZERO IS MEASURED ZERO HERE, NOT UNKNOWN (G4/CR-114). §540: *"The
    // receiver draws 0 W from the rack and its `outletsConsumed` is 0 —
    // its power comes down the `net.poh` conductor from the transmitter.
    // That is a genuinely different power topology from everything else in
    // the catalog and the power rollup has to get it right."* An absent
    // figure would make the rollup count this device in its UNKNOWN column,
    // which is the opposite of what is true about it.
    power: PowerProfile(
      nameplateWatts: 0,
      typicalWatts: 0,
      outletsProvided: 0,
      outletsConsumed: 0,
    ),
    ports: v06rx.ports,
    banks: v06rx.banks,
  );

  // V07 · AVoIP Endpoint, DECODER half (§575).
  final v07dec = PortBuilder()
    ..p(
      'network',
      'NETWORK',
      connector: 'conn.rj45',
      family: 'video.avoip',
      bank: 'network',
      bankLabel: 'Network',
      poe: PoeSpec(role: PoeRole.pd, standard: PoeStandard.af, poeClass: 3),
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
      'analog.out',
      'ANALOG OUT',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.source,
      bank: 'audio',
      bankLabel: 'Audio',
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
      // DUAL-HEAD FLASHER (M5-H2): one 3.5 mm plug, two heads, as
      // on the Episode IRF-2. Three or more needs another port or
      // an IR expansion block, which is its own device with its
      // own ports, so 2 is the physical bound and not a guess.
      maxConnections: 2,
    )
    ..p(
      'rs232',
      'RS-232',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.rs232',
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
  // EVERY PHYSICAL FACT IS THE ENCODER'S, unlike V06's pair. §575 states
  // one set of figures above both halves — *"hosted, half-width · shallow
  // (125 mm + 55 mm) · 0.7 kg · 12 / 9 W (802.3af PD)"* — and lists the
  // roles under it, so the decoder differs in ports alone.
  out['V07:decoder'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'DEC-AVOIP-1',
    displayName: 'AVoIP Endpoint (Decoder)',
    description:
        'The decoder half of the endpoint pair V07 ships as its encoder. '
        'One part number, two roles (P4).',
    category: kCatVideo,
    typePrefix: 'DEC',
    glyph: DeviceGlyph.extender,
    tags: const ['avoip', 'sdvoe'],
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
    ),
    ports: v07dec.ports,
    banks: v07dec.banks,
  );

  return out;
}
