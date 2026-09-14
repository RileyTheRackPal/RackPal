// Seed catalog — "Audio" (docs/catalog/seed-devices.md §3.2).

import 'package:rackpal_core/src/catalog/catalog_ports.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';

const String kCatAudio = 'Audio';

Len _mm(num v) => Len.fromMillimetres(v);
Mass _kg(num v) => Mass.fromKilograms(v);

PowerProfile _power({
  required int nameplate,
  required int typical,
  required int pf,
  int? standby,
}) => PowerProfile(
  nameplateWatts: nameplate,
  typicalWatts: typical,
  standbyWatts: standby,
  nominalVolts: 120,
  apparentVA: (typical * 1000 / pf).round(),
  powerFactor: pf,
  isContinuousLoad: true,
  outletsProvided: 0,
  outletsConsumed: 1,
  inletPlug: PlugType.nema515p,
);

Map<String, TemplateBody> buildAudioCatalog() {
  final out = <String, TemplateBody>{};

  // A01 · Multi-Zone Amplifier, 16-channel (P4 param 8/16; 16ch shown).
  // ONE SET PER ZONE, DECLARED INSIDE THE LOOP. `PortBuilder.set` registers
  // once per KEY, and these ports interpolate the zone number into their
  // `setKey` — so declaring `src`/`zone` out here produced two sets that no
  // port referenced while all thirty-two ports referenced sets that did not
  // exist. See `test/catalog/port_set_integrity_test.dart` (C9) for what
  // that cost: the atomicConnect gesture joins `setKey` to `PortSetDef.key`,
  // so a dangling key is a stereo pair the gesture cannot see.
  final a01 = PortBuilder();
  for (var zone = 1; zone <= 8; zone++) {
    a01
      ..set('src$zone', 'Source $zone pair', SetKind.stereoPair)
      ..set('zone$zone', 'Zone $zone speaker pair', SetKind.speakerPair)
      ..p(
        'src.$zone.l',
        'SRC $zone L',
        connector: 'conn.rca',
        family: 'audio.line_unbal',
        dir: PortDirection.sink,
        bank: 'srcIn',
        bankLabel: 'Source Inputs',
        setKey: 'src$zone',
        setRole: 'L',
      )
      ..p(
        'src.$zone.r',
        'SRC $zone R',
        connector: 'conn.rca',
        family: 'audio.line_unbal',
        dir: PortDirection.sink,
        bank: 'srcIn',
        setKey: 'src$zone',
        setRole: 'R',
      )
      ..p(
        'zone.$zone.pos',
        'ZONE $zone +',
        connector: 'conn.euroblock_2',
        family: 'audio.speaker_lowz',
        dir: PortDirection.source,
        bank: 'zoneOut',
        bankLabel: 'Zone Speaker Outputs',
        impedance: 8,
        polarity: Polarity.positive,
        setKey: 'zone$zone',
        setRole: '+',
      )
      ..p(
        'zone.$zone.neg',
        'ZONE $zone -',
        connector: 'conn.euroblock_2',
        family: 'audio.speaker_lowz',
        dir: PortDirection.source,
        bank: 'zoneOut',
        impedance: 8,
        polarity: Polarity.negative,
        setKey: 'zone$zone',
        setRole: '-',
      )
      ..p(
        'zone.$zone.ir',
        'ZONE $zone IR',
        connector: 'conn.3_5mm_ts',
        family: 'ctl.ir_direct',
        dir: PortDirection.sink,
        bank: 'control',
        bankLabel: 'Control',
        pinout: 'mono-tip-sleeve',
        accepts: const ['ctl.ir_emitter'],
      );
  }
  for (var i = 1; i <= 2; i++) {
    a01.p(
      'sub.$i',
      'SUB OUT $i',
      connector: 'conn.rca',
      family: 'audio.sub',
      dir: PortDirection.source,
      bank: 'subOut',
      bankLabel: 'Sub Outputs',
    );
  }
  a01
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
      'trigger.in',
      'TRIGGER IN',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.trigger12v',
      dir: PortDirection.sink,
      bank: 'control',
      maxCurrentMa: 100,
    )
    ..p(
      'trigger.out',
      'TRIGGER OUT',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.trigger12v',
      dir: PortDirection.source,
      bank: 'control',
      maxCurrentMa: 100,
    )
    ..p(
      'ac.in',
      'AC (captive cord)',
      connector: 'conn.nema_5_20p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      bankSide: SymbolSide.bottom,
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['A01'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'AMP-16CH',
    displayName: 'Multi-Zone Amplifier, 16-channel',
    description:
        'Generic 16-channel/8-zone distributed audio amplifier with '
        'per-zone IR and 20 A captive-cord service.',
    category: kCatAudio,
    primaryDomain: const SignalDomainId('audio.analog'),
    typePrefix: 'AMP',
    tags: const ['multizone', 'residential'],
    frontU: 3,
    rearU: 3,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(380),
    connectorProjection: _mm(95),
    weight: _kg(17.2),
    maxUnsupportedMass: _kg(7),
    requiresClearanceAboveU: 1,
    power: _power(nameplate: 800, typical: 340, pf: 650),
    ports: a01.ports,
    banks: a01.banks,
    portSets: a01.portSets,
  );

  // A02 · AV Receiver, 7.2-channel — hosted, the densest template.
  // Declared per instance below, for the reason A01 states. `an`/`spk`
  // out here matched nothing: the ports ask for `an1`..`an4` and
  // `spkFL`..`spkSBR`.
  final a02 = PortBuilder();
  for (var i = 1; i <= 7; i++) {
    a02.p(
      'hdmi.in.$i',
      'HDMI IN $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_1',
      dir: PortDirection.sink,
      bank: 'hdmiIn',
      bankLabel: 'HDMI Inputs',
    );
  }
  a02
    ..p(
      'hdmi.in.front',
      'HDMI FRONT',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_1',
      dir: PortDirection.sink,
      face: Face.front,
      bank: 'hdmiIn',
    )
    ..p(
      'hdmi.out.main',
      'HDMI OUT MAIN',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_1',
      dir: PortDirection.source,
      bank: 'hdmiOut',
      bankLabel: 'HDMI Outputs',
      returnChannel: ReturnChannel.eArc,
    );
  for (var i = 1; i <= 2; i++) {
    a02.p(
      'hdmi.out.zone.$i',
      'HDMI OUT ZONE $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'hdmiOut',
    );
  }
  for (var i = 1; i <= 2; i++) {
    a02.p(
      'optical.in.$i',
      'OPTICAL IN $i',
      connector: 'conn.jis_f05',
      family: 'audio.spdif_optical',
      dir: PortDirection.sink,
      bank: 'digitalIn',
      bankLabel: 'Digital Audio In',
    );
  }
  for (var i = 1; i <= 2; i++) {
    a02.p(
      'coax.in.$i',
      'COAX IN $i',
      connector: 'conn.rca75',
      family: 'audio.spdif_coax',
      dir: PortDirection.sink,
      bank: 'digitalIn',
      impedance: 75,
    );
  }
  for (var i = 1; i <= 4; i++) {
    a02
      ..set('an$i', 'Analog $i stereo pair', SetKind.stereoPair)
      ..p(
        'an.$i.l',
        'ANALOG IN $i L',
        connector: 'conn.rca',
        family: 'audio.line_unbal',
        dir: PortDirection.sink,
        bank: 'analogIn',
        bankLabel: 'Analog Audio In',
        setKey: 'an$i',
        setRole: 'L',
      )
      ..p(
        'an.$i.r',
        'ANALOG IN $i R',
        connector: 'conn.rca',
        family: 'audio.line_unbal',
        dir: PortDirection.sink,
        bank: 'analogIn',
        setKey: 'an$i',
        setRole: 'R',
      );
  }
  a02
    // NEVER DECLARED AT ALL until now — the other flavour of the same
    // defect. Two ports claimed `phono` and no `set('phono', ...)` existed
    // anywhere in this file.
    ..set('phono', 'Phono stereo pair', SetKind.stereoPair)
    ..p(
      'phono.l',
      'PHONO L',
      connector: 'conn.rca',
      family: 'audio.phono',
      dir: PortDirection.sink,
      bank: 'analogIn',
      setKey: 'phono',
      setRole: 'L',
    )
    ..p(
      'phono.r',
      'PHONO R',
      connector: 'conn.rca',
      family: 'audio.phono',
      dir: PortDirection.sink,
      bank: 'analogIn',
      setKey: 'phono',
      setRole: 'R',
    )
    ..p(
      'phono.gnd',
      'PHONO GND',
      connector: 'conn.ground_lug',
      family: 'power.bonding',
      dir: PortDirection.passive,
      bank: 'analogIn',
    );
  const spkChannels = ['FL', 'FR', 'C', 'SL', 'SR', 'SBL', 'SBR'];
  for (final ch in spkChannels) {
    a02
      ..set('spk$ch', 'Speaker pair $ch', SetKind.speakerPair)
      ..p(
        'spk.$ch.pos',
        '$ch +',
        connector: 'conn.binding_post',
        family: 'audio.speaker_lowz',
        dir: PortDirection.source,
        bank: 'spkOut',
        bankLabel: 'Speaker Outputs',
        impedance: 8,
        polarity: Polarity.positive,
        setKey: 'spk$ch',
        setRole: '+',
      )
      ..p(
        'spk.$ch.neg',
        '$ch -',
        connector: 'conn.binding_post',
        family: 'audio.speaker_lowz',
        dir: PortDirection.source,
        bank: 'spkOut',
        impedance: 8,
        polarity: Polarity.negative,
        setKey: 'spk$ch',
        setRole: '-',
      );
  }
  for (var i = 1; i <= 2; i++) {
    a02.p(
      'sub.pre.$i',
      'SUB PRE OUT $i',
      connector: 'conn.rca',
      family: 'audio.sub',
      dir: PortDirection.source,
      bank: 'spkOut',
    );
  }
  a02
    ..p(
      'fm.ant',
      'FM ANTENNA',
      connector: 'conn.f_type',
      family: 'rf.ota',
      dir: PortDirection.sink,
      bank: 'tuner',
      bankLabel: 'Tuner',
      impedance: 75,
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
      'ir.in',
      'IR IN',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.ir_direct',
      dir: PortDirection.sink,
      bank: 'control',
      pinout: 'mono-tip-sleeve',
      accepts: const ['ctl.ir_emitter'],
    );
  for (var i = 1; i <= 2; i++) {
    a02.p(
      'trigger.out.$i',
      'TRIGGER OUT $i',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.trigger12v',
      dir: PortDirection.source,
      bank: 'control',
      maxCurrentMa: 100,
    );
  }
  a02
    ..p(
      'rs232',
      'RS-232',
      connector: 'conn.de9',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'control',
    )
    ..p(
      'usb',
      'USB',
      connector: 'conn.usb_c',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      face: Face.front,
      bank: 'control',
    )
    ..p(
      'phones',
      'PHONES',
      connector: 'conn.6_35mm_trs',
      family: 'audio.headphone',
      dir: PortDirection.source,
      face: Face.front,
      bank: 'control',
    )
    ..p(
      'ac.in',
      'AC (captive cord)',
      connector: 'conn.nema_5_15p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      bankSide: SymbolSide.bottom,
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['A02'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'AVR-7.2CH',
    displayName: 'AV Receiver, 7.2-channel',
    description:
        'The densest template in the catalog — proves the ground lug is a '
        'real conductor and the phono ground path prints on the schedule '
        '(AC-034/m21).',
    category: kCatAudio,
    primaryDomain: const SignalDomainId('audio.analog'),
    typePrefix: 'AVR',
    tags: const ['avr', 'hosted', 'residential'],
    frontU: 0,
    rearU: 0,
    side: OccupancySide.none,
    mountMethod: MountMethod.hosted,
    bodyDepth: _mm(380),
    connectorProjection: _mm(110),
    weight: _kg(11.8),
    power: _power(nameplate: 750, typical: 280, pf: 680),
    ports: a02.ports,
    banks: a02.banks,
    portSets: a02.portSets,
  );

  // A03 · DSP Audio Processor, 8x8 + Dante.
  final a03 = PortBuilder();
  for (var i = 1; i <= 8; i++) {
    a03.p(
      'in.$i',
      'IN $i',
      connector: 'conn.euroblock_3',
      family: 'audio.line_bal',
      dir: PortDirection.sink,
      bank: 'analogIn',
      bankLabel: 'Analog Inputs',
      balanced: true,
      phantomPower: true,
    );
  }
  for (var i = 1; i <= 8; i++) {
    a03.p(
      'out.$i',
      'OUT $i',
      connector: 'conn.euroblock_3',
      family: 'audio.line_bal',
      dir: PortDirection.source,
      bank: 'analogOut',
      bankLabel: 'Analog Outputs',
      balanced: true,
    );
  }
  for (var i = 1; i <= 2; i++) {
    a03.p(
      'aes.in.$i',
      'AES IN $i',
      connector: 'conn.xlr3',
      family: 'audio.aes3',
      dir: PortDirection.sink,
      bank: 'digital',
      bankLabel: 'Digital Audio',
      impedance: 110,
    );
  }
  for (var i = 1; i <= 2; i++) {
    a03.p(
      'aes.out.$i',
      'AES OUT $i',
      connector: 'conn.xlr3',
      family: 'audio.aes3',
      dir: PortDirection.source,
      bank: 'digital',
      impedance: 110,
    );
  }
  a03
    ..p(
      'dante.pri',
      'DANTE PRI',
      connector: 'conn.rj45',
      family: 'audio.dante',
      dir: PortDirection.bidirectional,
      bank: 'audioNet',
      bankLabel: 'Audio Network',
    )
    ..p(
      'dante.sec',
      'DANTE SEC',
      connector: 'conn.rj45',
      family: 'audio.dante',
      dir: PortDirection.bidirectional,
      bank: 'audioNet',
    )
    ..p(
      'lan',
      'CONTROL LAN',
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
    );
  for (var i = 1; i <= 8; i++) {
    a03.p(
      'gpio.$i',
      'GPIO $i',
      connector: 'conn.euroblock_2',
      family: 'ctl.contact',
      dir: PortDirection.bidirectional,
      bank: 'control',
    );
  }
  a03
    ..p(
      'config',
      'CONFIG',
      connector: 'conn.usb_c',
      family: 'net.ethernet',
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
  out['A03'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'DSP-8X8-DANTE',
    displayName: 'DSP Audio Processor, 8x8 + Dante',
    category: kCatAudio,
    primaryDomain: const SignalDomainId('audio.digital'),
    typePrefix: 'DSP',
    glyph: DeviceGlyph.processor,
    tags: const ['dsp', 'dante', 'commercial'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(300),
    connectorProjection: _mm(70),
    weight: _kg(4.1),
    power: _power(nameplate: 60, typical: 35, pf: 950),
    ports: a03.ports,
    banks: a03.banks,
  );

  // A04 · Stereo Power Amplifier, 2x200W.
  final a04 = PortBuilder()
    // `bal` and `unbal` are referenced verbatim by their ports and are
    // correct here. `spk` was not — its ports interpolate the channel —
    // so it moves into the loop below.
    ..set('bal', 'Balanced input pair', SetKind.balancedPair)
    ..set('unbal', 'Unbalanced input pair', SetKind.stereoPair);
  a04
    ..p(
      'bal.l',
      'BAL IN L',
      connector: 'conn.xlr3',
      family: 'audio.line_bal',
      dir: PortDirection.sink,
      bank: 'inputs',
      bankLabel: 'Inputs',
      balanced: true,
      setKey: 'bal',
      setRole: 'L',
    )
    ..p(
      'bal.r',
      'BAL IN R',
      connector: 'conn.xlr3',
      family: 'audio.line_bal',
      dir: PortDirection.sink,
      bank: 'inputs',
      balanced: true,
      setKey: 'bal',
      setRole: 'R',
    )
    ..p(
      'unbal.l',
      'UNBAL IN L',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.sink,
      bank: 'inputs',
      setKey: 'unbal',
      setRole: 'L',
    )
    ..p(
      'unbal.r',
      'UNBAL IN R',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.sink,
      bank: 'inputs',
      setKey: 'unbal',
      setRole: 'R',
    );
  for (final ch in ['L', 'R']) {
    a04
      ..set('spk$ch', 'Speaker pair $ch', SetKind.speakerPair)
      ..p(
        'spk.$ch.pos',
        '$ch +',
        connector: 'conn.binding_post',
        family: 'audio.speaker_lowz',
        dir: PortDirection.source,
        bank: 'spkOut',
        bankLabel: 'Speaker Outputs',
        impedance: 4,
        polarity: Polarity.positive,
        setKey: 'spk$ch',
        setRole: '+',
      )
      ..p(
        'spk.$ch.neg',
        '$ch -',
        connector: 'conn.binding_post',
        family: 'audio.speaker_lowz',
        dir: PortDirection.source,
        bank: 'spkOut',
        impedance: 4,
        polarity: Polarity.negative,
        setKey: 'spk$ch',
        setRole: '-',
      );
  }
  a04
    ..p(
      'trigger.in',
      'TRIGGER IN',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.trigger12v',
      dir: PortDirection.sink,
      bank: 'control',
      bankLabel: 'Control',
      maxCurrentMa: 100,
    )
    ..p(
      'ac.in',
      'AC (captive cord)',
      connector: 'conn.nema_5_20p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['A04'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'AMP-2X200',
    displayName: 'Stereo Power Amplifier, 2x200W',
    category: kCatAudio,
    primaryDomain: const SignalDomainId('audio.analog'),
    typePrefix: 'AMP',
    tags: const ['stereo', 'poweramp'],
    frontU: 2,
    rearU: 2,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(430),
    connectorProjection: _mm(90),
    weight: _kg(15.4),
    maxUnsupportedMass: _kg(7),
    requiresClearanceAboveU: 1,
    power: _power(nameplate: 900, typical: 380, pf: 650),
    ports: a04.ports,
    banks: a04.banks,
    portSets: a04.portSets,
  );

  // A05 · 70V/100V Commercial Amplifier, 2x250W — the only source of
  // audio.speaker_cv in the rack-side catalog.
  final a05 = PortBuilder()
    ..p(
      'in.a',
      'IN A',
      connector: 'conn.euroblock_3',
      family: 'audio.line_bal',
      dir: PortDirection.sink,
      bank: 'lineIn',
      bankLabel: 'Line Inputs',
      balanced: true,
    )
    ..p(
      'in.b',
      'IN B',
      connector: 'conn.euroblock_3',
      family: 'audio.line_bal',
      dir: PortDirection.sink,
      bank: 'lineIn',
      balanced: true,
    )
    ..p(
      'link.a',
      'LINK OUT A',
      connector: 'conn.euroblock_3',
      family: 'audio.line_bal',
      dir: PortDirection.source,
      bank: 'linkThru',
      bankLabel: 'Link Thru',
      balanced: true,
    )
    ..p(
      'link.b',
      'LINK OUT B',
      connector: 'conn.euroblock_3',
      family: 'audio.line_bal',
      dir: PortDirection.source,
      bank: 'linkThru',
      balanced: true,
    )
    // 250 W PER OUTPUT, which is the "2x250W" in this template's own
    // model string read the way an amplifier spec sheet means it: two
    // channels, each rated 250 W, not 250 W shared. DR-132 §11.131.5.
    //
    // THE CAPACITY HALF OF `ELE-005`. Until DR-132 gave `p()` a `bus`
    // parameter, no seeded port could state one, so the rule that sums
    // speaker taps had nothing to compare against on the ONLY rack-side
    // constant-voltage source in the catalogue.
    ..p(
      'cv.a',
      '70V OUT A',
      connector: 'conn.euroblock_2',
      family: 'audio.speaker_cv',
      dir: PortDirection.busNode,
      bank: 'cvOut',
      bankLabel: 'CV Speaker Outputs',
      nominalVoltage: 70,
      bus: BusCapability(maxTapWatts: 250),
    )
    ..p(
      'cv.b',
      '70V OUT B',
      connector: 'conn.euroblock_2',
      family: 'audio.speaker_cv',
      dir: PortDirection.busNode,
      bank: 'cvOut',
      nominalVoltage: 70,
      bus: BusCapability(maxTapWatts: 250),
    )
    ..p(
      'mute',
      'MUTE / PRIORITY',
      connector: 'conn.euroblock_2',
      family: 'ctl.contact',
      dir: PortDirection.sink,
      bank: 'control',
      bankLabel: 'Control',
    )
    ..p(
      'monitoring',
      'MONITORING',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'control',
    )
    ..p(
      'ac.in',
      'AC (captive cord)',
      connector: 'conn.nema_5_20p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['A05'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'AMP-70V-2X250',
    displayName: '70V/100V Commercial Amplifier, 2x250W',
    description:
        'The only rack-side source of audio.speaker_cv — a constant- '
        'voltage BUS output, not OUT (a 70V run is a multi-tap bus).',
    category: kCatAudio,
    primaryDomain: const SignalDomainId('audio.analog'),
    typePrefix: 'AMP',
    tags: const ['70v', 'commercial', 'paging'],
    frontU: 2,
    rearU: 2,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(400),
    connectorProjection: _mm(88),
    weight: _kg(12.7),
    maxUnsupportedMass: _kg(7),
    requiresClearanceAboveU: 1,
    power: _power(nameplate: 700, typical: 300, pf: 650),
    ports: a05.ports,
    banks: a05.banks,
  );

  // A06 · Multi-Zone Streaming Source, 4-stream.
  // `aux` is referenced verbatim and is correct here; `st` was not — its
  // ports interpolate the zone — so it is declared in the loop below.
  final a06 = PortBuilder()..set('aux', 'Aux pair', SetKind.stereoPair);
  for (var zone = 1; zone <= 4; zone++) {
    a06
      ..set('st$zone', 'Stream $zone pair', SetKind.stereoPair)
      ..p(
        'stream.$zone.l',
        'STREAM $zone L',
        connector: 'conn.rca',
        family: 'audio.line_unbal',
        dir: PortDirection.source,
        bank: 'analogOut',
        bankLabel: 'Analog Outputs',
        setKey: 'st$zone',
        setRole: 'L',
      )
      ..p(
        'stream.$zone.r',
        'STREAM $zone R',
        connector: 'conn.rca',
        family: 'audio.line_unbal',
        dir: PortDirection.source,
        bank: 'analogOut',
        setKey: 'st$zone',
        setRole: 'R',
      );
  }
  for (var i = 1; i <= 4; i++) {
    a06.p(
      'digital.out.$i',
      'DIGITAL OUT $i',
      connector: 'conn.rca75',
      family: 'audio.spdif_coax',
      dir: PortDirection.source,
      bank: 'digitalOut',
      bankLabel: 'Digital Outputs',
      impedance: 75,
    );
  }
  a06
    ..p(
      'aux.l',
      'AUX IN L',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.sink,
      bank: 'auxIn',
      bankLabel: 'Aux Input',
      setKey: 'aux',
      setRole: 'L',
    )
    ..p(
      'aux.r',
      'AUX IN R',
      connector: 'conn.rca',
      family: 'audio.line_unbal',
      dir: PortDirection.sink,
      bank: 'auxIn',
      setKey: 'aux',
      setRole: 'R',
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
  out['A06'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'STRM-4ZONE',
    displayName: 'Multi-Zone Streaming Source, 4-stream',
    description:
        'Typed prefix STRM, not STR — STR is the Structure device system '
        'prefix (CR-043).',
    category: kCatAudio,
    primaryDomain: const SignalDomainId('audio.digital'),
    typePrefix: 'STRM',
    glyph: DeviceGlyph.source,
    tags: const ['streaming', 'multizone'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(280),
    connectorProjection: _mm(62),
    weight: _kg(3.2),
    power: _power(nameplate: 35, typical: 20, pf: 950),
    ports: a06.ports,
    banks: a06.banks,
    portSets: a06.portSets,
  );

  return out;
}
