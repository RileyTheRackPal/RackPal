// Seed catalog — "Passive & Mechanical" (docs/catalog/seed-devices.md
// §3.8). All three are zero-port, `mountMethod: rackEars`, and carry NO
// `PowerProfile` at all — not zero watts, ABSENT, which is what keeps the
// weight/VA rollup's unknown count honest (P5). One representative U
// height is shipped per id (P4's parametric U-height variants are a
// picker/Device-Builder concern, not three separate catalog entries).

import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

const String kCatPassive = 'Passive & Mechanical';

Len _mm(num v) => Len((v * 1_000_000).round());
Mass _kg(num v) => Mass((v * 1_000_000).round());

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
    power: PowerProfile(),
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
    power: PowerProfile(),
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
    power: PowerProfile(),
  ),
};
