// Seed catalog — "Field Devices" (docs/catalog/seed-devices.md §3.9). Every
// entry is `mountMethod: notInRack`, occupancy `{0, 0, none}`, no rack
// depth — the category exists so `ELE-004`/`ELE-005`/`ELE-006` (three of
// the highest-value rules in the product) have a speaker/tap object to
// read `impedanceOhms`/`tapWatts` from at all (AC-031).

import 'package:rackmate_core/src/catalog/catalog_ports.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/mass.dart';

const String kCatField = 'Field Devices';

Mass _kg(num v) => Mass.fromKilograms(v);

TemplateBody _field({
  required String model,
  required String displayName,
  String description = '',
  required String typePrefix,
  List<String> tags = const [],
  required Mass weight,
  PowerProfile? power,
  required List<PortDef> ports,
  required List<BankDef> banks,
  List<PortSetDef> portSets = const [],
}) => TemplateBody(
  manufacturer: 'Generic',
  model: model,
  displayName: displayName,
  description: description,
  category: kCatField,
  typePrefix: typePrefix,
  tags: tags,
  frontU: 0,
  rearU: 0,
  side: OccupancySide.none,
  mountMethod: MountMethod.notInRack,
  weight: weight,
  power: power ?? PowerProfile(),
  ports: ports,
  banks: banks,
  portSets: portSets,
);

Map<String, TemplateBody> buildFieldCatalog() {
  final out = <String, TemplateBody>{};

  // F01 · Display (flat panel).
  final f01 = PortBuilder();
  for (var i = 1; i <= 4; i++) {
    f01.p(
      'hdmi.$i',
      'HDMI $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_1',
      dir: PortDirection.sink,
      bank: 'video',
      bankLabel: 'Video',
      returnChannel: i == 1 ? ReturnChannel.arc : null,
    );
  }
  f01
    ..p(
      'optical.out',
      'OPTICAL OUT',
      connector: 'conn.jis_f05',
      family: 'audio.spdif_optical',
      dir: PortDirection.source,
      bank: 'audio',
      bankLabel: 'Audio',
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
      gender: Gender.female,
    )
    ..p(
      'ir',
      'IR',
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
  out['F01'] = _field(
    model: 'DISP-1',
    displayName: 'Display (flat panel)',
    description:
        'ARC on HDMI 1 is the only mechanism for audio travelling up a '
        'link whose defaultDirection is source->sink.',
    typePrefix: 'DISP',
    tags: const ['display', 'field'],
    weight: _kg(18.1),
    power: PowerProfile(
      nameplateWatts: 200,
      typicalWatts: 120,
      nominalVolts: 120,
      apparentVA: 126,
      powerFactor: 950,
      isContinuousLoad: true,
      outletsProvided: 0,
      outletsConsumed: 1,
      inletPlug: PlugType.nema515p,
    ),
    ports: f01.ports,
    banks: f01.banks,
  );

  // F02 · Projector.
  final f02 = PortBuilder();
  for (var i = 1; i <= 2; i++) {
    f02.p(
      'hdmi.$i',
      'HDMI $i',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_1',
      dir: PortDirection.sink,
      bank: 'video',
      bankLabel: 'Video',
    );
  }
  f02
    ..p(
      'hdbt.in',
      'HDBT IN',
      connector: 'conn.rj45',
      family: 'video.hdbaset',
      dir: PortDirection.sink,
      bank: 'video',
      gender: Gender.female,
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
      gender: Gender.female,
    )
    ..p(
      'screen.trigger',
      'SCREEN TRIGGER',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.trigger12v',
      dir: PortDirection.source,
      bank: 'control',
      maxCurrentMa: 100,
    )
    ..p(
      'ir',
      'IR',
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
  out['F02'] = _field(
    model: 'PROJ-1',
    displayName: 'Projector',
    typePrefix: 'PROJ',
    tags: const ['projector', 'field'],
    weight: _kg(7.3),
    power: PowerProfile(
      nameplateWatts: 400,
      typicalWatts: 280,
      nominalVolts: 120,
      apparentVA: 295,
      powerFactor: 950,
      isContinuousLoad: true,
      outletsProvided: 0,
      outletsConsumed: 1,
      inletPlug: PlugType.nema515p,
    ),
    ports: f02.ports,
    banks: f02.banks,
  );

  // F03 · Projection Screen, motorised.
  final f03 = PortBuilder()
    ..p(
      'trigger.in',
      '12V TRIGGER IN',
      connector: 'conn.3_5mm_ts',
      family: 'ctl.trigger12v',
      dir: PortDirection.sink,
      bank: 'control',
      bankLabel: 'Control',
      maxCurrentMa: 100,
    )
    ..p(
      'dry.contact',
      'DRY CONTACT / RS-232 KIT',
      connector: 'conn.euroblock_2',
      family: 'ctl.contact',
      dir: PortDirection.sink,
      bank: 'control',
    )
    ..p(
      'ac.in',
      'AC (hardwired)',
      connector: 'conn.hardwired',
      family: 'power.ac_hardwired',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['F03'] = _field(
    model: 'SCRN-MOTOR-1',
    displayName: 'Projection Screen, motorised',
    description:
        'Takes both a trigger AND a hardwired line-voltage feed — '
        'integrators forget the second one.',
    typePrefix: 'SCRN',
    tags: const ['screen', 'field'],
    weight: _kg(22.7),
    power: PowerProfile(
      nameplateWatts: 180,
      typicalWatts: 90,
      nominalVolts: 120,
      apparentVA: 100,
      powerFactor: 900,
      inletPlug: PlugType.hardwired,
    ),
    ports: f03.ports,
    banks: f03.banks,
  );

  // F04 · In-Ceiling Speaker Pair — the canonical atomicConnect (16/4) case.
  final f04 = PortBuilder()..set('spk', 'Speaker pair', SetKind.speakerPair);
  for (final ch in ['L', 'R']) {
    f04
      ..p(
        'spk.$ch.pos',
        '$ch +',
        connector: 'conn.screw_terminal',
        family: 'audio.speaker_lowz',
        dir: PortDirection.passive,
        bank: 'terminals',
        bankLabel: 'Terminals',
        impedance: 8,
        polarity: Polarity.positive,
        setKey: 'spk$ch',
        setRole: '+',
      )
      ..p(
        'spk.$ch.neg',
        '$ch -',
        connector: 'conn.screw_terminal',
        family: 'audio.speaker_lowz',
        dir: PortDirection.passive,
        bank: 'terminals',
        impedance: 8,
        polarity: Polarity.negative,
        setKey: 'spk$ch',
        setRole: '-',
      );
  }
  out['F04'] = _field(
    model: 'SPK-CEIL-PAIR',
    displayName: 'In-Ceiling Speaker Pair',
    description:
        'One ceiling location, one 16/4 pull, four conductors, one '
        'gesture — the canonical atomicConnect case (AC-053, RJ-016).',
    typePrefix: 'SPK',
    tags: const ['speaker', 'ceiling', 'field'],
    weight: _kg(2.7),
    ports: f04.ports,
    banks: f04.banks,
    portSets: f04.portSets,
  );

  // F05 · In-Wall Speaker.
  final f05 = PortBuilder()
    ..set('spk', 'Speaker pair', SetKind.speakerPair)
    ..p(
      'spk.pos',
      '+',
      connector: 'conn.screw_terminal',
      family: 'audio.speaker_lowz',
      dir: PortDirection.passive,
      bank: 'terminals',
      bankLabel: 'Terminals',
      impedance: 8,
      polarity: Polarity.positive,
      setKey: 'spk',
      setRole: '+',
    )
    ..p(
      'spk.neg',
      '-',
      connector: 'conn.screw_terminal',
      family: 'audio.speaker_lowz',
      dir: PortDirection.passive,
      bank: 'terminals',
      impedance: 8,
      polarity: Polarity.negative,
      setKey: 'spk',
      setRole: '-',
    );
  out['F05'] = _field(
    model: 'SPK-WALL-1',
    displayName: 'In-Wall Speaker',
    typePrefix: 'SPK',
    tags: const ['speaker', 'wall', 'field'],
    weight: _kg(3.2),
    ports: f05.ports,
    banks: f05.banks,
    portSets: f05.portSets,
  );

  // F06 · Subwoofer, powered.
  final f06 = PortBuilder()
    ..p(
      'lfe.in',
      'LFE IN',
      connector: 'conn.rca',
      family: 'audio.sub',
      dir: PortDirection.sink,
      bank: 'audio',
      bankLabel: 'Audio',
    )
    ..p(
      'lfe.thru',
      'LFE THRU',
      connector: 'conn.rca',
      family: 'audio.sub',
      dir: PortDirection.source,
      bank: 'audio',
    )
    ..p(
      'trigger.in',
      '12V TRIGGER IN',
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
      connector: 'conn.nema_5_15p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['F06'] = _field(
    model: 'SUB-POWERED-1',
    displayName: 'Subwoofer, powered',
    description: 'Needs a signal run AND a receptacle at the same location.',
    typePrefix: 'SUB',
    tags: const ['subwoofer', 'field'],
    weight: _kg(22.7),
    power: PowerProfile(
      nameplateWatts: 500,
      typicalWatts: 150,
      nominalVolts: 120,
      apparentVA: 231,
      powerFactor: 650,
      isContinuousLoad: true,
      outletsProvided: 0,
      outletsConsumed: 1,
      inletPlug: PlugType.nema515p,
    ),
    ports: f06.ports,
    banks: f06.banks,
  );

  // F07 · Outdoor / Landscape Speaker.
  final f07 = PortBuilder()
    ..set('spk', 'Speaker pair', SetKind.speakerPair)
    ..p(
      'pos',
      '+',
      connector: 'conn.unterminated',
      family: 'audio.speaker_lowz',
      dir: PortDirection.passive,
      bank: 'pigtail',
      bankLabel: 'Pigtail',
      impedance: 8,
      polarity: Polarity.positive,
      setKey: 'spk',
      setRole: '+',
    )
    ..p(
      'neg',
      '-',
      connector: 'conn.unterminated',
      family: 'audio.speaker_lowz',
      dir: PortDirection.passive,
      bank: 'pigtail',
      impedance: 8,
      polarity: Polarity.negative,
      setKey: 'spk',
      setRole: '-',
    );
  out['F07'] = _field(
    model: 'SPK-OUTDOOR-1',
    displayName: 'Outdoor / Landscape Speaker',
    description: 'Runs to this device default to a directBurial jacket.',
    typePrefix: 'SPK',
    tags: const ['speaker', 'outdoor', 'field'],
    weight: _kg(1.8),
    ports: f07.ports,
    banks: f07.banks,
    portSets: f07.portSets,
  );

  // F08 · 70V Pendant Speaker — the only field source of a tapWatts
  // selector.
  final f08 = PortBuilder()
    ..set('tap', 'CV tap pair', SetKind.speakerPair)
    ..p(
      'pos',
      '+',
      connector: 'conn.unterminated',
      family: 'audio.speaker_cv',
      dir: PortDirection.busNode,
      bank: 'pigtail',
      bankLabel: 'Pigtail',
      polarity: Polarity.positive,
      setKey: 'tap',
      setRole: '+',
    )
    ..p(
      'neg',
      '-',
      connector: 'conn.unterminated',
      family: 'audio.speaker_cv',
      dir: PortDirection.busNode,
      bank: 'pigtail',
      polarity: Polarity.negative,
      setKey: 'tap',
      setRole: '-',
    );
  out['F08'] = _field(
    model: 'SPK-70V-PENDANT',
    displayName: '70V Pendant Speaker',
    description:
        'tapWatts is a per-installation selector (2.5/5/10/15/20 W), not a '
        'per-device fact — the transformer tap is set on the ladder.',
    typePrefix: 'SPK',
    tags: const ['speaker', '70v', 'field'],
    weight: _kg(2.3),
    ports: f08.ports,
    banks: f08.banks,
    portSets: f08.portSets,
  );

  // F09 · IP Camera.
  final f09 = PortBuilder()
    ..p(
      'lan',
      'LAN',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      bankLabel: 'Network',
      linkSpeedMbps: 1000,
      poe: PoeSpec(role: PoeRole.pd, standard: PoeStandard.af, poeClass: 3),
    )
    ..p(
      'alarm.io',
      'ALARM I/O',
      connector: 'conn.euroblock_2',
      family: 'ctl.contact',
      dir: PortDirection.bidirectional,
      bank: 'control',
      bankLabel: 'Control',
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
  out['F09'] = _field(
    model: 'CAM-IP-1',
    displayName: 'IP Camera',
    typePrefix: 'CAM',
    tags: const ['camera', 'poe', 'field'],
    weight: _kg(0.7),
    power: PowerProfile(
      nameplateWatts: 12,
      typicalWatts: 8,
      nominalVolts: 48,
      outletsProvided: 0,
      outletsConsumed: 0,
    ),
    ports: f09.ports,
    banks: f09.banks,
  );

  // F10 · NVR.
  final f10 = PortBuilder();
  for (var i = 1; i <= 8; i++) {
    f10.p(
      'poe.cam.$i',
      'PoE CAM $i',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      bankLabel: 'Network',
      poe: PoeSpec(role: PoeRole.pse, standard: PoeStandard.at),
    );
  }
  f10
    ..p(
      'lan',
      'LAN',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      linkSpeedMbps: 1000,
    )
    ..p(
      'hdmi',
      'HDMI',
      connector: 'conn.hdmi_a',
      family: 'video.hdmi.2_0',
      dir: PortDirection.source,
      bank: 'console',
      bankLabel: 'Console',
    );
  for (var i = 1; i <= 2; i++) {
    f10.p(
      'usb.$i',
      'USB $i',
      connector: 'conn.usb_c',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'console',
    );
  }
  f10.p(
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
  out['F10'] = _field(
    model: 'NVR-8CH',
    displayName: 'NVR',
    typePrefix: 'NVR',
    tags: const ['nvr', 'video-surveillance', 'field'],
    weight: _kg(6.8),
    power: PowerProfile(
      nameplateWatts: 120,
      typicalWatts: 65,
      nominalVolts: 120,
      apparentVA: 68,
      powerFactor: 950,
      isContinuousLoad: true,
      outletsProvided: 0,
      outletsConsumed: 1,
      inletPlug: PlugType.c14,
      poeBudgetWatts: 120,
    ),
    ports: f10.ports,
    banks: f10.banks,
  );

  // F11 · Wireless Access Point.
  final f11 = PortBuilder()
    ..p(
      'lan',
      'LAN / PoE',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      bankLabel: 'Network',
      linkSpeedMbps: 1000,
      poe: PoeSpec(role: PoeRole.pd, standard: PoeStandard.at, poeClass: 4),
    )
    ..p(
      'dc.in',
      '48V DC IN (opt)',
      connector: 'conn.barrel_dc',
      family: 'power.dc_low',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      nominalVoltage: 48,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['F11'] = _field(
    model: 'AP-1',
    displayName: 'Wireless Access Point',
    description:
        'The AP and the camera together make NET-001 meaningful: eight '
        'class-4 PDs against a switch budget well below ports x max class.',
    typePrefix: 'AP',
    tags: const ['wifi', 'poe', 'field'],
    weight: _kg(0.9),
    power: PowerProfile(
      nameplateWatts: 30,
      typicalWatts: 18,
      nominalVolts: 48,
      outletsProvided: 0,
      outletsConsumed: 0,
    ),
    ports: f11.ports,
    banks: f11.banks,
  );

  // F12 · Touchpanel.
  final f12 = PortBuilder()
    ..p(
      'lan',
      'LAN / PoE',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'network',
      bankLabel: 'Network',
      linkSpeedMbps: 1000,
      poe: PoeSpec(role: PoeRole.pd, standard: PoeStandard.af, poeClass: 3),
    )
    ..p(
      'cresnet',
      'CRESNET (24V)',
      connector: 'conn.phoenix_4',
      family: 'ctl.cresnet',
      dir: PortDirection.busNode,
      bank: 'bus',
      bankLabel: 'Control Bus',
    )
    ..p(
      'dc.in',
      '24V DC IN (opt)',
      connector: 'conn.barrel_dc',
      family: 'power.dc_low',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
      nominalVoltage: 24,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['F12'] = _field(
    model: 'TP-1',
    displayName: 'Touchpanel',
    typePrefix: 'TP',
    tags: const ['touchpanel', 'control', 'field'],
    weight: _kg(1.4),
    power: PowerProfile(
      nameplateWatts: 25,
      typicalWatts: 15,
      nominalVolts: 24,
      outletsProvided: 0,
      outletsConsumed: 0,
    ),
    ports: f12.ports,
    banks: f12.banks,
  );

  // F13 · Keypad.
  final f13 = PortBuilder()
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
      'qs.link',
      'QS LINK (alt)',
      connector: 'conn.rj45',
      family: 'ctl.lutron_qs',
      dir: PortDirection.busNode,
      bank: 'bus',
    );
  out['F13'] = _field(
    model: 'KP-1',
    displayName: 'Keypad',
    description:
        'ctl.cresnet and ctl.lutron_qs both ship topologyFree: true — '
        'Lutron QS is 2000 ft on 12 AWG; Cresnet is limited twice over '
        '(data length and 24V power drop).',
    typePrefix: 'KP',
    tags: const ['keypad', 'control', 'field'],
    weight: _kg(0.2),
    power: PowerProfile(
      nameplateWatts: 3,
      typicalWatts: 2,
      outletsProvided: 0,
      outletsConsumed: 0,
    ),
    ports: f13.ports,
    banks: f13.banks,
  );

  // F14 · Volume Control — a real DeviceInstance, not an InlineAdapter
  // (CR-015): two independent cable pulls land here.
  final f14 = PortBuilder()
    ..set('in', 'Input pair', SetKind.speakerPair)
    ..set('out', 'Output pair', SetKind.speakerPair)
    ..p(
      'in.pos',
      'IN +',
      connector: 'conn.screw_terminal',
      family: 'audio.speaker_lowz',
      dir: PortDirection.passive,
      bank: 'input',
      bankLabel: 'Input',
      polarity: Polarity.positive,
      setKey: 'in',
      setRole: '+',
    )
    ..p(
      'in.neg',
      'IN -',
      connector: 'conn.screw_terminal',
      family: 'audio.speaker_lowz',
      dir: PortDirection.passive,
      bank: 'input',
      polarity: Polarity.negative,
      setKey: 'in',
      setRole: '-',
    )
    ..p(
      'out.pos',
      'OUT +',
      connector: 'conn.screw_terminal',
      family: 'audio.speaker_lowz',
      dir: PortDirection.passive,
      bank: 'output',
      bankLabel: 'Output',
      polarity: Polarity.positive,
      setKey: 'out',
      setRole: '+',
    )
    ..p(
      'out.neg',
      'OUT -',
      connector: 'conn.screw_terminal',
      family: 'audio.speaker_lowz',
      dir: PortDirection.passive,
      bank: 'output',
      polarity: Polarity.negative,
      setKey: 'out',
      setRole: '-',
    );
  out['F14'] = _field(
    model: 'VC-1',
    displayName: 'Volume Control',
    typePrefix: 'VC',
    tags: const ['volume-control', 'passive', 'field'],
    weight: _kg(0.3),
    ports: f14.ports,
    banks: f14.banks,
    portSets: f14.portSets,
  );

  // F15 · IR Receiver Eye — the other half of C02's destructive-pinout
  // hazard.
  final f15 = PortBuilder()
    ..p(
      'pigtail',
      'PIGTAIL TO BLOCK',
      connector: 'conn.3_5mm_trs',
      family: 'ctl.ir_receiver',
      dir: PortDirection.source,
      bank: 'pigtail',
      bankLabel: 'Pigtail',
      pinout: 'xantech-stereo',
    );
  out['F15'] = _field(
    model: 'IRR-EYE-1',
    displayName: 'IR Receiver Eye',
    description:
        'Tip=signal, ring=GND, sleeve=+12V. Shares an identical 3.5 mm '
        'connector with an emitter — pinoutVariant is the only thing '
        'standing between the drawing and a dead emitter (AC-052).',
    typePrefix: 'IRR',
    tags: const ['ir', 'receiver', 'field'],
    weight: _kg(0.05),
    ports: f15.ports,
    banks: f15.banks,
  );

  // F16 · ISP Gateway / ONT — the single most conspicuous prior omission.
  final f16 = PortBuilder()
    ..p(
      'coax',
      'COAX / DOCSIS',
      connector: 'conn.f_type',
      family: 'rf.catv',
      dir: PortDirection.sink,
      bank: 'wan',
      bankLabel: 'WAN',
      impedance: 75,
    )
    ..p(
      'fibre',
      'FIBRE / GPON',
      connector: 'conn.sc',
      family: 'net.fiber_sm',
      dir: PortDirection.sink,
      bank: 'wan',
      fiberMode: FiberMode.singleMode,
    );
  for (var i = 1; i <= 2; i++) {
    f16.p(
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
  f16
    ..p(
      'tel',
      'TEL',
      connector: 'conn.rj45',
      family: 'ctl.rs232',
      dir: PortDirection.passive,
      bank: 'voice',
      bankLabel: 'Voice',
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
  out['F16'] = _field(
    model: 'ONT-1',
    displayName: 'ISP Gateway / ONT',
    description:
        'Physically present in essentially every North American '
        'residential rack, and the device the whole network hangs off.',
    typePrefix: 'ONT',
    tags: const ['isp', 'ont', 'field'],
    weight: _kg(1.1),
    power: PowerProfile(
      nameplateWatts: 25,
      typicalWatts: 15,
      nominalVolts: 12,
      outletsProvided: 0,
      outletsConsumed: 0,
    ),
    ports: f16.ports,
    banks: f16.banks,
  );

  // F17 · OTA Antenna.
  final f17 = PortBuilder()
    ..p(
      'feed',
      'FEED',
      connector: 'conn.f_type',
      family: 'rf.ota',
      dir: PortDirection.passive,
      bank: 'feed',
      bankLabel: 'Feed',
      impedance: 75,
    );
  out['F17'] = _field(
    model: 'ANT-OTA-1',
    displayName: 'OTA Antenna',
    typePrefix: 'ANT',
    tags: const ['antenna', 'ota', 'field'],
    weight: _kg(3.6),
    ports: f17.ports,
    banks: f17.banks,
  );

  // F18 · F-Type Ground Block.
  final f18 = PortBuilder()
    ..p(
      'line',
      'LINE',
      connector: 'conn.f_type',
      family: 'rf.catv',
      dir: PortDirection.passive,
      bank: 'coax',
      bankLabel: 'Coax',
      impedance: 75,
    )
    ..p(
      'load',
      'LOAD',
      connector: 'conn.f_type',
      family: 'rf.catv',
      dir: PortDirection.passive,
      bank: 'coax',
      impedance: 75,
    )
    ..p(
      'bonding',
      'BONDING LUG',
      connector: 'conn.ground_lug',
      family: 'power.bonding',
      dir: PortDirection.passive,
      bank: 'bonding',
      bankLabel: 'Bonding',
    );
  out['F18'] = _field(
    model: 'GB-COAX-1',
    displayName: 'F-Type Ground Block',
    description:
        'A code item and an actual lightning-damage liability (AC-034/m21).',
    typePrefix: 'GB',
    tags: const ['ground-block', 'code', 'field'],
    weight: _kg(0.1),
    ports: f18.ports,
    banks: f18.banks,
  );

  return out;
}
