// Seed catalog — "Passive & Mechanical" (docs/catalog/seed-devices.md
// §3.8). All three are zero-port and `mountMethod: rackEars`.
//
// ═══════════════════════════════════════════════════════════════════════
// THEIR POWER IS A MEASURED ZERO, STATED (DR-211 §11.210.5)
// ═══════════════════════════════════════════════════════════════════════
// These carried an EMPTY `PowerProfile` until 2026-10-01, on the reading
// that an absent value keeps the rollup's unknown count honest. It did the
// opposite: measured on the four starters, five of Whole House's ten
// unknown power contributors were these panels, so a cover reading
// `≥ 2490 VA (10 unknown)` told a client half the rack was unspecified
// when half of the "unknown" was steel. A blank panel drawing nothing is
// not an estimate; it is the fact G4 spells as `0`. Watts (nameplate,
// typical, standby) and VA are stated as zero; voltage and power factor
// stay absent, since a part with no supply has neither.
//
// That was only half true until `PowerProfile.outletsProvided` /
// `outletsConsumed` stopped being non-nullable ints defaulting to 0:
// watts and VA were correctly absent, but outlets read as a measured
// `0/0` on the chip strip, superscript and all — the exact fabrication
// this comment claimed the category was avoiding. Since DR-171 the
// counts are not fields; a template with no ports at all, which all
// three are, is counted unknown for that reason.
//
// One representative U height is shipped per id (P4's parametric
// U-height variants are a picker/Device-Builder concern, not three
// separate catalog entries).

// A VALUE EQUAL TO THE DEFAULT IS A FACT HERE, NOT REDUNDANCY (DR-195,
// canon 11.194). A catalogue entry records what a device IS, and under
// CR-114 an explicit `0` is a measurement. Dropping an argument that
// happens to equal today's constructor default would hand the fact to the
// constructor, and the next change to that default would rewrite every
// device that had stated it with no diff here to show it.
// ignore_for_file: avoid_redundant_argument_values

import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';

const String kCatPassive = 'Passive & Mechanical';

Len _mm(num v) => Len.fromMillimetres(v);
Mass _kg(num v) => Mass.fromKilograms(v);

Map<String, TemplateBody> buildPassiveCatalog() => {
  // X01 · Blank Panel, 1U.
  'X01': TemplateBody(
    manufacturer: 'Generic',
    model: 'BLK-1U',
    displayName: 'Blank Panel, 1U',
    category: kCatPassive,
    typePrefix: 'BLK',
    tags: const ['blank', 'filler'],
    frontU: 1,
    rearU: 0,
    side: OccupancySide.front,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(25),
    weight: _kg(0.45),
    power: PowerProfile(
      nameplateWatts: 0,
      typicalWatts: 0,
      standbyWatts: 0,
      apparentVA: 0,
    ),
  ),

  // X02 · Vent Panel, 1U, 64% open.
  'X02': TemplateBody(
    manufacturer: 'Generic',
    model: 'VNT-1U',
    displayName: 'Vent Panel, 1U, 64% open',
    category: kCatPassive,
    typePrefix: 'VNT',
    tags: const ['vent', 'thermal'],
    frontU: 1,
    rearU: 0,
    side: OccupancySide.front,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(25),
    weight: _kg(0.45),
    power: PowerProfile(
      nameplateWatts: 0,
      typicalWatts: 0,
      standbyWatts: 0,
      apparentVA: 0,
    ),
  ),

  // X03 · Rack Shelf, 2U, vented — a container; hosts A02 and S01.
  'X03': TemplateBody(
    manufacturer: 'Generic',
    model: 'SHF-2U',
    displayName: 'Rack Shelf, 2U, vented',
    description:
        'A container: hosted devices consume zero additional RU. '
        'Containment is child->parent only (CR-029) — the shelf carries '
        'no list of its own.',
    category: kCatPassive,
    typePrefix: 'SHF',
    glyph: DeviceGlyph.shelf,
    tags: const ['shelf', 'container'],
    frontU: 2,
    rearU: 0,
    side: OccupancySide.front,
    mountMethod: MountMethod.rackEars,
    bodyDepth: _mm(375),
    weight: _kg(2.3),
    isContainer: true,
    containerWeightCapacity: _kg(22.7),
    containerUsableDepth: _mm(375),
    containerUsableWidth: _mm(432),
    containerVented: true,
    power: PowerProfile(
      nameplateWatts: 0,
      typicalWatts: 0,
      standbyWatts: 0,
      apparentVA: 0,
    ),
  ),
};
