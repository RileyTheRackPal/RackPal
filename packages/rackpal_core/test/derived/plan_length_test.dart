// PLAN-G/2: the plan floor, and the datum rule that decides most of it
// (docs/15 §4.1, DR-020 §11.19.2, DR-147 §11.146.2).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASES ARE THE FOUR THAT PICK THE WRONG THING
// ═══════════════════════════════════════════════════════════════════════
// Every arithmetic case below passes against a derivation that measures
// from the NEAREST pinned rack, or from the FIRST one, or that falls back
// to a device beyond an unpinned outlet. Four cases can tell those apart
// and they are marked. They are the ones to keep if this file is ever
// trimmed.
//
// `plan_measurability_test.dart` holds the mirror property: moving every
// pin changes nothing THERE, because that derivation asks whether a length
// is derivable. Moving a pin changes the number HERE. The two files are
// each other's boundary.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'fixtures/plan_doc.dart';

void main() {
  group('the floor itself', () {
    test('a straight line on a calibrated plan, rounded once', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final dev = d.rackDevice('PP-1', rk);
      final out = d.outlet('WP-1', pin: planPin(400, 300));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'TV wall'),
        outletId: out,
        fieldLabel: 'GR-TV-1',
      );

      // 3-4-5: 400 by 300 pixels is 500 pixels, at 0.36 in per pixel.
      expect(planLowerBoundOf(d.doc, link), inches(180));
    });

    test('two pins in the same place is a MEASURED ZERO, not a refusal', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(120, 120));
      final dev = d.rackDevice('PP-1', rk);
      final out = d.outlet('WP-1', pin: planPin(120, 120));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'on top of the rack'),
        outletId: out,
        fieldLabel: 'EQ-1',
      );

      expect(planLowerBoundOf(d.doc, link), Len.zero);
    });

    test("the subject's own riseAllowance is added, and a null one is not "
        'a guess', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final dev = d.rackDevice('PP-1', rk);
      final flat = d.room('Great Room');
      final risen = d.room('Attic drop', riseAllowance: inches(96));
      final outFlat = d.outlet('WP-1', pin: planPin(100, 0), locationId: flat);
      final outRisen = d.outlet(
        'WP-2',
        pin: planPin(100, 0),
        locationId: risen,
      );

      final a = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'flat'),
        outletId: outFlat,
        fieldLabel: 'GR-1',
      );
      final b = d.link(
        from: PortEndpoint(d.port(dev, 'J02')),
        to: const PlaceEndpoint(description: 'risen'),
        outletId: outRisen,
        fieldLabel: 'AT-1',
      );

      expect(planLowerBoundOf(d.doc, a), inches(36));
      expect(
        planLowerBoundOf(d.doc, b),
        inches(132),
        reason: 'the same line plus the 96 in rise',
      );
    });

    test('the scale is the only thing that converts: doubling the typed '
        'distance doubles the floor', () {
      Len? boundAt(Len typed) {
        final d = PlanDoc()
          ..underlay(
            scale: PlanScale(
              a: const PxPt(0, 0),
              b: const PxPt(100, 0),
              distance: typed,
            ),
          );
        final rk = d.rack('RK-1', pin: planPin(0, 0));
        final dev = d.rackDevice('PP-1', rk);
        final out = d.outlet('WP-1', pin: planPin(100, 0));
        return planLowerBoundOf(
          d.doc,
          d.link(
            from: PortEndpoint(d.port(dev, 'J01')),
            to: const PlaceEndpoint(description: 'wall'),
            outletId: out,
            fieldLabel: 'GR-1',
          ),
        );
      }

      expect(boundAt(inches(36)), inches(36));
      expect(boundAt(inches(72)), inches(72));
    });
  });

  group('the datum is the rack this run lands in', () {
    /// Two racks, both pinned, the run landing in the FAR one.
    ///
    /// LOAD-BEARING. A derivation measuring from the nearest pinned rack,
    /// or from the first in document order, returns 36 in here and passes
    /// every other case in this file.
    test('not the nearest pinned rack, and not the first one', () {
      final d = PlanDoc()
        ..underlay()
        ..rack('RK-1', pin: planPin(0, 0));
      final far = d.rack('RK-2', pin: planPin(1000, 0));
      final dev = d.rackDevice('PP-2', far);
      final out = d.outlet('WP-1', pin: planPin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'wall'),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(
        planLowerBoundOf(d.doc, link),
        inches(324),
        reason: '900 px from RK-2, not 100 px from RK-1',
      );
    });

    /// LOAD-BEARING. The rule that produces no number rather than a
    /// convenient one.
    test('an unpinned rack yields NO floor, even when another rack on the '
        'same plan is pinned', () {
      final d = PlanDoc()
        ..underlay()
        ..rack('RK-1', pin: planPin(0, 0));
      final unpinned = d.rack('RK-2');
      final dev = d.rackDevice('PP-2', unpinned);
      final out = d.outlet('WP-1', pin: planPin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'wall'),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('a jumper has both ends in one rack, so nothing is the subject', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final a = d.rackDevice('SW-1', rk);
      final b = d.rackDevice('PP-1', rk);
      d.outlet('WP-1', pin: planPin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(a, 'J01')),
        to: PortEndpoint(d.port(b, '01')),
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('a sub-feed has its ends in two racks, and a rack is a datum '
        'rather than a subject', () {
      final d = PlanDoc()..underlay();
      final one = d.rack('RK-1', pin: planPin(0, 0));
      final two = d.rack('RK-2', pin: planPin(500, 0));
      final link = d.link(
        from: PortEndpoint(d.port(d.rackDevice('SW-1', one), 'J01')),
        to: PortEndpoint(d.port(d.rackDevice('SW-2', two), 'J01')),
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    /// LOAD-BEARING, AND IT EXISTS BECAUSE A MUTATION SURVIVED THE TWO
    /// CASES ABOVE. Relaxing "exactly one rack end" to "at least one"
    /// changes nothing for an ordinary jumper or sub-feed, because their
    /// far end is a rail-placed device that carries no pin either way, so
    /// both of those tests pass against the weaker rule. This is the
    /// document that tells the two apart: a run landing in two racks whose
    /// `structureOrigin` still names a pinned outlet. Both ends in racks
    /// means it is not a field run whatever its origin says, and that
    /// outlet is stale rather than a subject.
    test('two rack ends refuse even when the origin names a pinned '
        'outlet', () {
      final d = PlanDoc()..underlay();
      final one = d.rack('RK-1', pin: planPin(0, 0));
      final two = d.rack('RK-2', pin: planPin(500, 0));
      final out = d.outlet('WP-1', pin: planPin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(d.rackDevice('SW-1', one), 'J01')),
        to: PortEndpoint(d.port(d.rackDevice('SW-2', two), 'J01')),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('a field-to-field run has no rack end at all', () {
      final d = PlanDoc()
        ..underlay()
        ..rack('RK-1', pin: planPin(0, 0));
      final out = d.outlet('WP-1', pin: planPin(100, 0));
      final link = d.link(
        from: const PlaceEndpoint(description: 'wall'),
        to: const OpenEndpoint('coil'),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('a link with no conductors has no ends', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      d.rackDevice('PP-1', rk);
      const id = Uuid('link-bare');
      final link = Link(
        id: id,
        designator: 'W099',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        meta: planMeta(),
      );
      d.doc.links[id] = link;

      expect(planLowerBoundOf(d.doc, link), isNull);
    });
  });

  group('the subject is where the cable stops', () {
    /// LOAD-BEARING. A derivation that preferred the device, or that fell
    /// back to it, measures 1000 px here instead of 100.
    test('a named outlet wins over a pinned device beyond it', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final panel = d.rackDevice('PP-1', rk);
      final tv = d.offRackDevice('TV-1', pin: planPin(1000, 0));
      final out = d.outlet('WP-1', pin: planPin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(panel, 'J01')),
        to: PortEndpoint(d.port(tv, 'HDMI-1')),
        outletId: out,
        fieldLabel: 'GR-TV-1',
      );

      expect(planLowerBoundOf(d.doc, link), inches(36));
    });

    /// LOAD-BEARING. The half of the same rule that refuses.
    test('a named outlet that is UNPINNED does not fall back to the '
        'device', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final panel = d.rackDevice('PP-1', rk);
      final tv = d.offRackDevice('TV-1', pin: planPin(1000, 0));
      final out = d.outlet('WP-1');
      final link = d.link(
        from: PortEndpoint(d.port(panel, 'J01')),
        to: PortEndpoint(d.port(tv, 'HDMI-1')),
        outletId: out,
        fieldLabel: 'GR-TV-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('no box named: the off-rack device at the field end is the '
        'subject', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final panel = d.rackDevice('PP-1', rk);
      final ceiling = d.room('Great Room', riseAllowance: inches(12));
      final spk = d.offRackDevice(
        'SPK-1',
        pin: planPin(200, 0),
        locationId: ceiling,
      );
      final link = d.link(
        from: PortEndpoint(d.port(panel, 'J01')),
        to: PortEndpoint(d.port(spk, 'IN')),
      );

      expect(planLowerBoundOf(d.doc, link), inches(84));
    });

    test('an unpinned off-rack device yields nothing', () {
      final d = PlanDoc()..underlay();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final panel = d.rackDevice('PP-1', rk);
      final spk = d.offRackDevice('SPK-1');
      final link = d.link(
        from: PortEndpoint(d.port(panel, 'J01')),
        to: PortEndpoint(d.port(spk, 'IN')),
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });
  });

  group('what the plan cannot answer', () {
    test('two underlays yield no floor, because a floorplan carries no '
        'distance between floors', () {
      final d = PlanDoc()
        ..underlay()
        ..underlay(id: kPlanUl2);
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final dev = d.rackDevice('PP-1', rk);
      final out = d.outlet('WP-1', pin: planPin(100, 0, on: kPlanUl2));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'upstairs'),
        outletId: out,
        fieldLabel: 'BR-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('an uncalibrated plan yields no floor, and a DEGENERATE scale is '
        'uncalibrated', () {
      for (final scale in <PlanScale?>[null, kDegenerateScale]) {
        final d = PlanDoc()..underlay(scale: scale);
        final rk = d.rack('RK-1', pin: planPin(0, 0));
        final dev = d.rackDevice('PP-1', rk);
        final out = d.outlet('WP-1', pin: planPin(100, 0));
        final link = d.link(
          from: PortEndpoint(d.port(dev, 'J01')),
          to: const PlaceEndpoint(description: 'wall'),
          outletId: out,
          fieldLabel: 'GR-1',
        );

        expect(
          planLowerBoundOf(d.doc, link),
          isNull,
          reason: 'scale: $scale',
        );
      }
    });

    test('a pin naming an underlay this document no longer holds is not an '
        'exception (CR-093)', () {
      final d = PlanDoc();
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final dev = d.rackDevice('PP-1', rk);
      final out = d.outlet('WP-1', pin: planPin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'wall'),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });
  });
}
