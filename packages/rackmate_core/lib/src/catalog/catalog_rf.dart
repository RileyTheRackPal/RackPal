// Seed catalog — "RF / Coax" (docs/catalog/seed-devices.md §3.6).

import 'package:rackmate_core/src/catalog/catalog_ports.dart';
import 'package:rackmate_core/src/model/device_glyph.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

const String kCatRf = 'RF / Coax';

Len _mm(num v) => Len.fromMillimetres(v);
Mass _kg(num v) => Mass.fromKilograms(v);

Map<String, TemplateBody> buildRfCatalog() {
  final out = <String, TemplateBody>{};

  // R01 · RF Splitter Panel, 8-way — fully passive, and the source of
  // rf.catv's DC-passing port hazard.
  final r01 = PortBuilder()
    ..p(
      'in',
      'IN',
      connector: 'conn.f_type',
      family: 'rf.catv',
      dir: PortDirection.passive,
      bank: 'input',
      bankLabel: 'Input',
      impedance: 75,
    );
  for (var i = 1; i <= 8; i++) {
    r01.p(
      'out.$i',
      'OUT $i',
      connector: 'conn.f_type',
      family: 'rf.catv',
      dir: PortDirection.passive,
      bank: 'outputs',
      bankLabel: 'Outputs',
      impedance: 75,
      // Port 1 additionally passes DC toward the source (§3.6): exactly
      // one splitter leg must, or the LNB never powers. `notes` is a
      // plain human-readable string here — a typed `requiresPowerPassing
      // Port` field is not yet in this package's `PortDef` shape (M0
      // MINIMAL SHAPE gap, same pattern as the type's other TODO fields).
      notes: i == 1
          ? 'Passes DC toward the LNB/dish (power-passing leg)'
          : null,
    );
  }
  out['R01'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'SPL-8WAY',
    displayName: 'RF Splitter Panel, 8-way',
    description:
        'All ports are PAS (passive) — a splitter leg is a physical tee, '
        'not a driven output. Exactly one output DC-passes toward the LNB.',
    category: kCatRf,
    typePrefix: 'SPL',
    tags: const ['rf', 'splitter', 'passive'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(120),
    connectorProjection: _mm(50),
    weight: _kg(0.9),
    power: PowerProfile(
      nameplateWatts: 0,
      typicalWatts: 0,
      outletsProvided: 0,
      outletsConsumed: 0,
    ),
    ports: r01.ports,
    banks: r01.banks,
  );

  // R02 · Satellite Multiswitch, SWM-16.
  final r02 = PortBuilder();
  for (var i = 1; i <= 4; i++) {
    r02.p(
      'sat.$i',
      'SAT IN $i',
      connector: 'conn.f_type',
      family: 'rf.satellite',
      dir: PortDirection.sink,
      bank: 'lnbIn',
      bankLabel: 'LNB Inputs',
      impedance: 75,
    );
  }
  r02.p(
    'ota',
    'OTA IN',
    connector: 'conn.f_type',
    family: 'rf.ota',
    dir: PortDirection.sink,
    bank: 'lnbIn',
    impedance: 75,
  );
  for (var i = 1; i <= 16; i++) {
    r02.p(
      'out.$i',
      'SWM OUT ${i.toString().padLeft(2, '0')}',
      connector: 'conn.f_type',
      family: 'rf.satellite',
      dir: PortDirection.passive,
      bank: 'rxOut',
      bankLabel: 'Receiver Outputs',
      impedance: 75,
    );
  }
  r02
    ..p(
      'power.insert',
      'POWER INSERT',
      connector: 'conn.f_type',
      family: 'power.dc_low',
      dir: PortDirection.sink,
      bank: 'power',
      bankLabel: 'Power',
    )
    ..p(
      'psu',
      'PSU (captive cord)',
      connector: 'conn.nema_5_15p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'power',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  out['R02'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'SWM-16',
    displayName: 'Satellite Multiswitch, SWM-16',
    description:
        'Hard budget: 16 tuners across all 16 outputs, not 16 receivers '
        '(a v1.2 count rule; maxDevicesPerSegment is carried as data now).',
    category: kCatRf,
    typePrefix: 'SWM',
    glyph: DeviceGlyph.switcher,
    tags: const ['satellite', 'multiswitch'],
    frontU: 1,
    rearU: 1,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(230),
    connectorProjection: _mm(55),
    weight: _kg(2.3),
    power: PowerProfile(
      nameplateWatts: 30,
      typicalWatts: 22,
      nominalVolts: 120,
      apparentVA: 24,
      powerFactor: 900,
      isContinuousLoad: true,
      outletsProvided: 0,
      outletsConsumed: 1,
      inletPlug: PlugType.nema515p,
    ),
    ports: r02.ports,
    banks: r02.banks,
  );

  return out;
}
