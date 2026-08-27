// A DEVICE'S RATED OUTPUT IS NOT ITS INPUT DRAW.
//
// =====================================================================
// WHY THIS FILE EXISTS, AND WHY THE TESTS THAT ALREADY EXISTED COULD NOT
// HAVE CAUGHT IT
// =====================================================================
// `P03 UPS-3000VA` authored `apparentVA: 3000, typicalWatts: 2700` — its
// nameplate OUTPUT rating, the load it can carry. Every rollup in
// `derived/` sums those two as CONNECTED LOAD, and the gear plugged into
// the UPS is already in the document with its own draw, so the whole
// downstream load was counted a second time. `whole_house` RK-1 printed
// `DRAW ≥ 5440 VA` and `HEAT ≥ 15979 BTU/hr` on T6.30, T2.01 and T2.02
// for a rack drawing ~2490 VA and ~6920 BTU/hr — 2.2x the circuit and
// 3.4x the heat, on the three sheets an integrator sizes a branch circuit
// and a closet fan from. Same class of error as the 1000x mass bug this
// project already shipped once.
//
// `starters_export_test` and `equipment_list_test` were both green
// throughout, and both were right to be: they assert that TWO DERIVATIONS
// OF THE SAME FIELD agree with each other. `computeRackRollups` and
// `buildEquipmentList` read `PowerProfile.apparentVA` through the one
// shared `resolveDeviceLoads`, so they agree on 5440 exactly as
// faithfully as they agree on 2490. A self-referential assertion cannot
// see a wrong input.
//
// So every figure asserted below is reasoned from OUTSIDE the model:
//   * from a branch-circuit rating (20 A x 120 V = 2400 VA);
//   * from test devices whose draw this file states itself;
//   * from what a conversion stage physically is.
// None of it is read back out of the field under test.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

/// The largest single-phase branch circuit a residential or light-
/// commercial A/V rack is fed from: 20 A at 120 V.
///
/// A CATALOG NUMBER, NOT A MODEL ONE. Nothing in `rackpal_core` derives
/// it, so a template whose authored draw exceeds it cannot have been
/// measured at an outlet — it is a through-rating, a typo, or a device
/// that needs its own service, and the seed catalog ships none of the
/// last. `P03` used to state 3000.
const int kOneBranchCircuitVA = 20 * 120;

const Uuid _rackId = Uuid('rack-1');

TemplateSnapshot _snapshot(String id, TemplateBody body) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'sha256:seed-$id',
  capturedAt: DateTime.utc(2026),
  body: body,
);

/// A device the TEST authors the draw of, so no assertion below reads its
/// magnitude back out of the catalog.
TemplateSnapshot _load({
  required String id,
  required int va,
  required int watts,
}) => _snapshot(
  id,
  TemplateBody(
    manufacturer: 'TEST',
    model: id,
    displayName: id,
    frontU: 1,
    power: PowerProfile(apparentVA: va, typicalWatts: watts),
  ),
);

DeviceInstance _railed(String id, String template, int ru) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(template),
    version: 1,
    contentHash: 'sha256:seed-$template',
  ),
  designator: id.toUpperCase(),
  name: '',
  placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: Face.front),
  meta: testMeta(),
);

void main() {
  final catalog = buildSeedCatalog();

  group('the UPS authors what it DRAWS, not what it can DELIVER', () {
    test('the 3000 VA is a CAPACITY and lives in a field nothing sums', () {
      final ups = catalog['P03']!;

      expect(ups.model, 'UPS-3000VA');
      expect(ups.power.outputCapacityVA, 3000);
      expect(ups.power.outputCapacityWatts, 2700);
    });

    test('...and its own draw is a small fraction of that rating', () {
      // INDEPENDENTLY REASONED, and deliberately not stated as a ratio
      // against `outputCapacityVA` — that would be the same
      // self-referential shape this file exists because of.
      //
      // A UPS is a conversion stage. What it presents to the branch
      // circuit on its own account is its conversion loss plus the
      // battery charger: tens of watts for a line-interactive unit, the
      // same order as the sibling P01 (10 VA) and P02 (12 VA) templates.
      // A device genuinely drawing 2700 W is a 22 A space heater, and a
      // rack holding one would need a dedicated feed and a ton of
      // cooling — which is what the sheets used to say.
      final power = catalog['P03']!.power;

      expect(power.typicalWatts, isNotNull);
      expect(power.typicalWatts, lessThan(200));
      expect(power.apparentVA, isNotNull);
      expect(power.apparentVA, lessThan(250));
      // Not zero either: the unit does burn something, and a zero would
      // read as a measurement of nothing (`derived/totals.dart` rule 1).
      expect(power.typicalWatts, greaterThan(0));
    });

    test('the heat it contributes is a fan-sized figure, not a furnace', () {
      // 2700 W is 9213 BTU/hr — a 2.7 kW heater standing in the rack. The
      // bound is reasoned from what a UPS dissipates, not from any field.
      final loads = resolveDeviceLoads(
        _railed('u', 'P03', 1),
        catalog['P03'],
      );

      expect(loads.btuPerHour, isNotNull);
      expect(loads.btuPerHour, lessThan(1000));
    });
  });

  group('no seeded template authors a through-rating as a draw', () {
    test('nothing in the catalog draws more than ONE branch circuit', () {
      // The invariant that would have caught P03 on the day it was
      // written, stated against an electrical fact rather than against
      // the catalog's own numbers. A single device drawing more than a
      // full 20 A circuit is either a through-rating in a draw field or a
      // device that needs its own service; the catalog ships none of the
      // latter, and the largest honest draw in it is an amplifier at
      // 585 VA.
      for (final entry in catalog.entries) {
        final va = entry.value.power.apparentVA;
        if (va == null) continue;
        expect(
          va,
          lessThan(kOneBranchCircuitVA),
          reason:
              '${entry.key} ${entry.value.model} authors $va VA of DRAW — '
              'more than a 20 A branch circuit can supply. If that is a '
              'rating it can DELIVER, it belongs in outputCapacityVA.',
        );
      }
    });

    test('...and the same in watts', () {
      for (final entry in catalog.entries) {
        final watts = entry.value.power.typicalWatts;
        if (watts == null) continue;
        expect(
          watts,
          lessThan(kOneBranchCircuitVA),
          reason: '${entry.key} ${entry.value.model} authors $watts W',
        );
      }
    });

    test('the scan is not vacuous — the catalog does author draws', () {
      final authored = catalog.values
          .where((b) => b.power.apparentVA != null)
          .length;
      expect(authored, greaterThan(20));
    });
  });

  group('THE MAGNITUDE, on a rack, against a figure the rollup did not '
      'produce', () {
    // Eight devices of 100 VA / 90 W each, authored HERE, behind the real
    // catalog UPS. An electrician reading the sheet is being told what
    // the rack presents to its feed. That is the eight devices plus
    // whatever the UPS itself burns — a conversion stage in front of them,
    // not a ninth 3000 VA appliance.
    //
    //   independently reasoned total  =  8 x 100 VA  +  UPS overhead
    //                                 =  800 VA + tens
    //   what the double count printed =  800 + 3000  =  3800 VA
    const downstreamCount = 8;
    const downstreamVA = 100;
    const downstreamWatts = 90;
    const expectedVA = downstreamCount * downstreamVA; // 800

    final templates = <String, TemplateSnapshot>{
      'P03@1': _snapshot('P03', catalog['P03']!),
      'LOAD@1': _load(id: 'LOAD', va: downstreamVA, watts: downstreamWatts),
    };
    final devices = <DeviceInstance>[
      _railed('ups', 'P03', 1),
      for (var i = 0; i < downstreamCount; i++)
        _railed('load$i', 'LOAD', 4 + i),
    ];
    final rack = Rack(
      id: _rackId,
      name: 'R',
      designator: 'RK-1',
      heightU: 24,
      order: const FracIndex('a0'),
      meta: testMeta(),
    );

    test('the elevation prints the connected load, not load + rating', () {
      final profile = computeRackLoadProfile(
        rack: rack,
        devices: devices,
        templates: templates,
      );

      expect(profile.apparentVA.value, isNotNull);
      expect(
        profile.apparentVA.value,
        greaterThanOrEqualTo(expectedVA),
        reason: 'the eight downstream devices are 800 VA between them',
      );
      expect(
        profile.apparentVA.value,
        lessThan(expectedVA + 200),
        reason:
            'anything near 3800 VA is the UPS rating counted as a ninth '
            'load on top of the eight it is feeding',
      );
    });

    test('...and a heat figure a fan can be sized against', () {
      // 8 x 90 W = 720 W = 2457 BTU/hr, plus the UPS's own loss. The
      // double count made this 11670.
      const downstreamBtu = downstreamCount * downstreamWatts * 3.412142;
      final profile = computeRackLoadProfile(
        rack: rack,
        devices: devices,
        templates: templates,
      );

      expect(profile.btuPerHour.value, isNotNull);
      expect(profile.btuPerHour.value, greaterThanOrEqualTo(downstreamBtu));
      expect(profile.btuPerHour.value, lessThan(downstreamBtu + 700));
    });

    test('T6.30 subtotals the same magnitude — both sheets, one truth', () {
      final doc = RackDocument(
        id: const Uuid('doc'),
        appVersion: 'test',
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        meta: testMeta(),
        racks: <Uuid, Rack>{rack.id: rack},
        devices: <Uuid, DeviceInstance>{for (final d in devices) d.id: d},
        templates: templates,
      );

      final group = buildEquipmentList(doc).groups.single;

      expect(group.apparentVA.value, greaterThanOrEqualTo(expectedVA));
      expect(group.apparentVA.value, lessThan(expectedVA + 200));
    });

    test('the UPS row itself shows its own draw, not its rating', () {
      // The row an integrator reads beside `UPS-1`. Before the fix it
      // said 3000 — indistinguishable, in a bare cell, from a device that
      // really does pull 25 A.
      final loads = resolveDeviceLoads(devices.first, catalog['P03']);

      expect(loads.apparentVA, lessThan(250));
    });
  });
}
