// Seed catalog — "Power" (docs/catalog/seed-devices.md §3.7).

import 'package:rackpal_core/src/catalog/catalog_ports.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';

const String kCatPower = 'Power';

Len _mm(num v) => Len.fromMillimetres(v);
Mass _kg(num v) => Mass.fromKilograms(v);

Map<String, TemplateBody> buildPowerCatalog() {
  final out = <String, TemplateBody>{};

  // P01 · Rack PDU, 0U vertical 24-outlet (P4 param 1U-8/2U-16/0U-24; the
  // 0U variant shown — the single best RU-saving move in a dense rack).
  final p01 = PortBuilder()
    ..p(
      'ac.in',
      'AC IN (captive cord)',
      connector: 'conn.nema_l5_30p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'inlet',
      bankLabel: 'Inlet',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  for (var i = 1; i <= 20; i++) {
    p01.p(
      'c13.$i',
      'C13 ${i.toString().padLeft(2, '0')}',
      connector: 'conn.iec_c13',
      family: 'power.ac_iec',
      dir: PortDirection.source,
      bank: 'outlets',
      bankLabel: 'Outlets',
      gender: Gender.female,
      power: PortPowerSpec(role: PortPowerRole.outlet),
    );
  }
  for (var i = 1; i <= 4; i++) {
    p01.p(
      'c19.$i',
      'C19 $i',
      connector: 'conn.iec_c19',
      family: 'power.ac_iec',
      dir: PortDirection.source,
      bank: 'outlets',
      gender: Gender.female,
      power: PortPowerSpec(role: PortPowerRole.outlet),
    );
  }
  p01
    ..p(
      'mgmt',
      'MGMT',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'management',
      bankLabel: 'Management',
    )
    ..p(
      'ground',
      'GROUND LUG',
      connector: 'conn.ground_lug',
      family: 'power.bonding',
      dir: PortDirection.passive,
      bank: 'bonding',
      bankLabel: 'Bonding',
    );
  out['P01'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'PDU-0U-24',
    displayName: 'Rack PDU, 0U vertical, 24-outlet',
    description:
        'The 0U vertical variant occupies a ZeroUChannel, not rail holes — '
        'this is why 0U occupants are created and edited from the '
        'inspector in v1 rather than dragged (AC-044).',
    category: kCatPower,
    primaryDomain: const SignalDomainId('pwr'),
    typePrefix: 'PDU',
    tags: const ['pdu', 'zerou'],
    frontU: 0,
    rearU: 0,
    side: OccupancySide.zeroUVertical,
    mountMethod: MountMethod.zeroU,
    bodyDepth: _mm(60),
    weight: _kg(6.4),
    power: PowerProfile(
      nameplateWatts: 10,
      typicalWatts: 10,
      nominalVolts: 120,
      apparentVA: 10,
      powerFactor: 1000,
      outletsProvided: 24,
      outletsConsumed: 1,
      inletPlug: PlugType.hardwired,
    ),
    ports: p01.ports,
    banks: p01.banks,
  );

  // P02 · Power Conditioner / Sequencer, 2U, 16-outlet.
  final p02 = PortBuilder()
    ..p(
      'ac.in',
      'AC IN (captive cord)',
      connector: 'conn.nema_5_20p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'inlet',
      bankLabel: 'Inlet',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  for (var step = 1; step <= 4; step++) {
    for (var i = 1; i <= 4; i++) {
      p02.p(
        'step$step.out.$i',
        'STEP $step OUT $i',
        connector: 'conn.nema_5_15r',
        family: 'power.ac_branch',
        dir: PortDirection.source,
        bank: 'seqOutlets',
        bankLabel: 'Sequenced Outlets',
        gender: Gender.female,
        power: PortPowerSpec(role: PortPowerRole.outlet),
        notes: 'Sequence step $step, delay ${(step - 1) * 1000} ms',
      );
    }
  }
  p02
    ..p(
      'remote.on',
      'REMOTE ON',
      connector: 'conn.euroblock_2',
      family: 'ctl.contact',
      dir: PortDirection.sink,
      bank: 'control',
      bankLabel: 'Control',
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
    );
  out['P02'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'SEQ-2U-16',
    displayName: 'Power Conditioner / Sequencer, 2U, 16-outlet',
    description:
        'Sequence step and delay are carried per outlet; SEQ-001 (v1.2) '
        'reads them — amplifiers must be last-on/first-off or a reversed '
        'sequence thumps and blows drivers (AC-033).',
    category: kCatPower,
    primaryDomain: const SignalDomainId('pwr'),
    typePrefix: 'SEQ',
    tags: const ['sequencer', 'conditioner'],
    frontU: 2,
    rearU: 2,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(300),
    connectorProjection: _mm(65),
    weight: _kg(8.2),
    // Over the 7 kg front-ear limit (AC-028) — see the same note on N01.
    maxUnsupportedMass: _kg(7),
    power: PowerProfile(
      nameplateWatts: 12,
      typicalWatts: 12,
      nominalVolts: 120,
      apparentVA: 12,
      powerFactor: 1000,
      outletsProvided: 16,
      outletsConsumed: 1,
      inletPlug: PlugType.nema515p,
    ),
    ports: p02.ports,
    banks: p02.banks,
  );

  // P03 · UPS, 3000 VA (P4 param 1000/1500/3000; the 3000 VA variant
  // shown — the single most likely wall-rack over-capacity call in the
  // catalog at 41.7 kg).
  final p03 = PortBuilder()
    ..p(
      'ac.in',
      'AC IN (captive cord)',
      connector: 'conn.nema_l5_30p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'inlet',
      bankLabel: 'Inlet',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  for (var i = 1; i <= 6; i++) {
    p03.p(
      'c13.$i',
      'C13 OUT $i',
      connector: 'conn.iec_c13',
      family: 'power.ac_iec',
      dir: PortDirection.source,
      bank: 'outlets',
      bankLabel: 'Outlets',
      gender: Gender.female,
      power: PortPowerSpec(role: PortPowerRole.outlet),
      notes: 'Battery-backed',
    );
  }
  for (var i = 1; i <= 2; i++) {
    p03.p(
      'c19.$i',
      'C19 OUT $i',
      connector: 'conn.iec_c19',
      family: 'power.ac_iec',
      dir: PortDirection.source,
      bank: 'outlets',
      gender: Gender.female,
      power: PortPowerSpec(role: PortPowerRole.outlet),
      notes: 'Battery-backed',
    );
  }
  for (var i = 1; i <= 2; i++) {
    p03.p(
      'nema520r.$i',
      '5-20R OUT $i',
      connector: 'conn.nema_5_20r',
      family: 'power.ac_branch',
      dir: PortDirection.source,
      bank: 'outlets',
      gender: Gender.female,
      power: PortPowerSpec(role: PortPowerRole.outlet),
      notes: 'Battery-backed',
    );
  }
  p03
    ..p(
      'network.card',
      'NETWORK CARD',
      connector: 'conn.rj45',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'management',
      bankLabel: 'Management',
    )
    ..p(
      'usb',
      'USB',
      connector: 'conn.usb_c',
      family: 'net.ethernet',
      dir: PortDirection.bidirectional,
      bank: 'management',
    )
    ..p(
      'rs232',
      'RS-232',
      connector: 'conn.de9',
      family: 'ctl.rs232',
      dir: PortDirection.bidirectional,
      bank: 'management',
    )
    ..p(
      'battery.expansion',
      'BATTERY EXPANSION',
      connector: 'conn.hardwired',
      family: 'power.dc_low',
      dir: PortDirection.bidirectional,
      bank: 'power',
      bankLabel: 'Power',
    );
  out['P03'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'UPS-3000VA',
    displayName: 'UPS, 3000 VA',
    description:
        'A 41.7 kg device instantly blows a wall-rack rating — the reason '
        'Rack.weightCapacity, the CG advisory and RCK-013 exist. UPS '
        'capacity is checked VA against VA, never W against W (CR-056) — '
        'the 3000 VA is outputCapacityVA, not a draw.',
    category: kCatPower,
    primaryDomain: const SignalDomainId('pwr'),
    typePrefix: 'UPS',
    glyph: DeviceGlyph.battery,
    tags: const ['ups', 'battery', 'placeLow'],
    frontU: 3,
    rearU: 3,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(480),
    connectorProjection: _mm(85),
    weight: _kg(41.7),
    maxUnsupportedMass: _kg(7),
    // ── THE 3000 VA IS A THROUGH-RATING, NOT A DRAW ───────────────────
    // This template used to author `apparentVA: 3000, typicalWatts: 2700`
    // — the unit's rated OUTPUT. Every rollup in `derived/` sums those as
    // CONNECTED LOAD, and the gear behind the UPS is already in the
    // document with its own draw, so the whole downstream load was counted
    // twice: `whole_house` RK-1 printed 5440 VA and 15979 BTU/hr on T6.30,
    // T2.01 and T2.02 for a rack that draws ~2440 VA. That is the number an
    // integrator sizes a branch circuit and a closet fan against.
    //
    // The rating now lives in `outputCapacityVA`/`outputCapacityWatts`,
    // which nothing sums. What stays in the draw fields is what the UPS
    // ITSELF pulls through its own inlet: conversion loss plus the battery
    // charger. For a line-interactive unit of this size that is a
    // tens-of-watts figure, and it is authored at the NO-LOAD value the way
    // the sibling P01/P02 templates author their own idle draw (10 VA and
    // 12 VA). The extra loss a UPS dissipates in proportion to the load
    // riding on it is NOT modelled and is deliberately not invented here —
    // there is no field for "a function of downstream draw", and a fan is
    // sized off this number.
    //
    // `nameplateWatts` follows the same convention P01 and P02 already use
    // for distribution gear: the unit's own maximum consumption, NOT the
    // through-rating printed on its UL label. That label's 2700 W is
    // `outputCapacityWatts`.
    power: PowerProfile(
      nameplateWatts: 50,
      typicalWatts: 45,
      nominalVolts: 120,
      apparentVA: 50,
      powerFactor: 900,
      outletsProvided: 10,
      outletsConsumed: 1,
      outputCapacityVA: 3000,
      outputCapacityWatts: 2700,
      inletPlug: PlugType.hardwired,
    ),
    ports: p03.ports,
    banks: p03.banks,
  );

  // ═══════════════════════════════════════════════════════════════════
  // P04 · Rack Power Strip, 6-outlet, shelf (DR-128 §11.127.8)
  // ═══════════════════════════════════════════════════════════════════
  // THE CHEAPEST FIX FOR `PWR-003` WAS THE ONE THING THE CATALOGUE COULD
  // NOT DRAW. Three templates provided outlets before this one and every
  // one of them is a piece of distribution gear: a 24-outlet PDU, a 16-
  // outlet sequencer, a 10-outlet UPS. The trade's ordinary answer to
  // "two more things to plug in than places to plug them" is none of
  // those. From the user, 2026-09-05:
  //
  //   "a small bank of PoE injectors or Sonos Ports connected to a simple
  //    power strip and then plugged into a PDU outlet to allow for remote
  //    resetting (Via BlueBOLT or OvrC, e.g.) and automation/power
  //    sequencing"
  //
  // and "these small power strips are commonly just set on a shelf in the
  // rack", which is why `mountMethod` is `shelf` and not `zeroU`.
  //
  // THE MODEL ALREADY EXPRESSED IT. `outletsConsumed: 1` with
  // `outletsProvided: 6` is exactly a strip, and it is the shape the
  // other three already use, so `PWR-003`'s arithmetic needed no change:
  // the strip closes a shortfall by FIVE, not six, because it eats an
  // outlet to give six.
  //
  // SIX CITES A PRODUCT, WHICH IS AC-052 IN THE FORM THE RULE WANTS.
  // The user's source: "6 outlets is standard on the most basic Wattbox
  // power strip, which is easily the most common my company installs."
  // The ROW stays generic per §10.9, so this is a `Rack Power Strip` and
  // not a WattBox; the brand records where the number came from.
  //
  // NO WATTAGE OF ITS OWN, and that is a fact rather than an omission: a
  // passive strip draws nothing. `outletsProvided`/`Consumed` are the
  // only power facts it has, so `PowerProfile` states those and stays
  // silent on the rest (G4/CR-114, AC-039).
  final p04 = PortBuilder()
    ..p(
      'ac.in',
      'AC IN (captive cord)',
      connector: 'conn.nema_5_15p',
      family: 'power.ac_branch',
      dir: PortDirection.sink,
      bank: 'inlet',
      bankLabel: 'Inlet',
      gender: Gender.male,
      power: PortPowerSpec(role: PortPowerRole.inlet),
    );
  for (var i = 1; i <= 6; i++) {
    p04.p(
      'out.$i',
      'OUT $i',
      connector: 'conn.nema_5_15r',
      family: 'power.ac_branch',
      dir: PortDirection.source,
      bank: 'outlets',
      bankLabel: 'Outlets',
      gender: Gender.female,
      power: PortPowerSpec(role: PortPowerRole.outlet),
    );
  }
  out['P04'] = TemplateBody(
    manufacturer: 'Generic',
    model: 'PSTRIP-6',
    displayName: 'Rack Power Strip, 6-outlet, shelf',
    description:
        'A passive strip, set on a shelf and fed from a PDU or sequencer '
        'outlet so the gear on it can be power-cycled remotely. It draws '
        'nothing itself.',
    category: kCatPower,
    primaryDomain: const SignalDomainId('pwr'),
    typePrefix: 'PS',
    tags: const ['strip', 'shelf', 'passive'],
    // NO RAIL HOLES AND NO U OF ITS OWN, WHICH IS THE SHELF'S JOB. A
    // strip lying on a shelf is not mounted to the rails, so
    // `mountMethod` is `shelf`; the U it sits in belongs to the shelf,
    // which is its own template. Claiming rail holes here would put a
    // device on the elevation that no installer screws in.
    //
    // `frontU`, `rearU` and `side` are left to their defaults of 0, 0 and
    // `none`, which say exactly that, so they are not restated here.
    mountMethod: MountMethod.shelf,
    bodyDepth: _mm(45),
    weight: _kg(0.7),
    power: PowerProfile(
      nominalVolts: 120,
      outletsProvided: 6,
      outletsConsumed: 1,
      inletPlug: PlugType.nema515p,
    ),
    ports: p04.ports,
    banks: p04.banks,
  );

  return out;
}
