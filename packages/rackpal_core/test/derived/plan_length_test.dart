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

final _when = DateTime.utc(2026, 9, 8);
const _ul = Uuid('ul-1');
const _ul2 = Uuid('ul-2');

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.x'),
  version: 1,
  contentHash: 'sha256:tpl.x',
);

/// 36 inches over 100 pixels: `PLAN-F/1`'s own example, so one pixel is
/// 0.36 in and the arithmetic below is readable.
const _usable = PlanScale(
  a: PxPt(0, 0),
  b: PxPt(100, 0),
  distance: Len(36 * Len.nmPerInch),
);

/// Stored and unable to yield a factor: two coincident points.
const _degenerate = PlanScale(
  a: PxPt(10, 10),
  b: PxPt(10, 10),
  distance: Len(36 * Len.nmPerInch),
);

Len _inches(num n) => Len((n * Len.nmPerInch).round());

PlanPin _pin(int x, int y, {Uuid on = _ul}) =>
    PlanPin(underlayId: on, at: PxPt(x, y));

final class _Doc {
  _Doc()
    : doc = RackDocument(
        id: const Uuid('doc-plan-len'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      );

  final RackDocument doc;
  int _seq = 0;

  Uuid _mint(String prefix) => Uuid('$prefix-${_seq++}');

  Uuid underlay({Uuid id = _ul, PlanScale? scale = _usable}) {
    doc.underlays[id] = PlanUnderlay(
      id: id,
      name: 'Level 1',
      imageMember: 'underlays/$id.png',
      format: PlanImageFormat.png,
      pixelWidth: 2000,
      pixelHeight: 1500,
      contentHash: 'sha256:ul',
      order: const FracIndex('a0'),
      meta: _meta(),
      scale: scale,
    );
    return id;
  }

  Uuid room(String name, {Len? riseAllowance}) {
    final id = _mint('loc');
    doc.locations[id] = Location(
      id: id,
      kind: LocationKind.room,
      name: name,
      code: 'RM',
      order: FracIndex('a$_seq'),
      meta: _meta(),
      riseAllowance: riseAllowance,
    );
    return id;
  }

  Uuid rack(String designator, {PlanPin? pin}) {
    final id = _mint('rack');
    doc.racks[id] = Rack(
      id: id,
      name: designator,
      designator: designator,
      heightU: 42,
      order: FracIndex('a$_seq'),
      meta: _meta(),
      planPin: pin,
    );
    return id;
  }

  Uuid outlet(String designation, {PlanPin? pin, Uuid? locationId}) {
    final id = _mint('outlet');
    doc.outlets[id] = Outlet(
      id: id,
      structureBodyId: const Uuid('structure-1'),
      designation: designation,
      order: FracIndex('a$_seq'),
      meta: _meta(),
      locationId: locationId,
      planPin: pin,
    );
    return id;
  }

  /// A rail-mounted device in [rackId], so its endpoint resolves to a rack.
  Uuid rackDevice(String designator, Uuid rackId) {
    final id = _mint('dev');
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: _templateRef,
      designator: designator,
      name: designator,
      placement: RailPlacement(rackId: rackId, ruIndex: 1, face: Face.rear),
      meta: _meta(),
    );
    return id;
  }

  Uuid offRackDevice(String designator, {PlanPin? pin, Uuid? locationId}) {
    final id = _mint('dev');
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.offRackPassive,
      templateRef: _templateRef,
      designator: designator,
      name: designator,
      placement: OffRackPlacement(locationId: locationId, planPin: pin),
      meta: _meta(),
    );
    return id;
  }

  Uuid port(Uuid deviceId, String designator) {
    final id = _mint('port');
    doc.ports[id] = Port(id: id, deviceId: deviceId, designator: designator);
    return id;
  }

  Link link({
    required Endpoint from,
    required Endpoint to,
    Uuid? outletId,
    String? fieldLabel,
  }) {
    final id = _mint('link');
    final l = Link(
      id: id,
      designator: 'W0$_seq',
      media: const MediaTypeId('media.cat6a_futp'),
      order: FracIndex('a$_seq'),
      meta: _meta(),
      conductors: [Conductor(from: from, to: to)],
      structureOrigin: fieldLabel == null
          ? null
          : StructureOrigin(
              structureBodyId: const Uuid('structure-1'),
              outletId: outletId,
              fieldLabel: fieldLabel,
            ),
    );
    doc.links[id] = l;
    return l;
  }
}

void main() {
  group('the floor itself', () {
    test('a straight line on a calibrated plan, rounded once', () {
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      final dev = d.rackDevice('PP-1', rk);
      final out = d.outlet('WP-1', pin: _pin(400, 300));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'TV wall'),
        outletId: out,
        fieldLabel: 'GR-TV-1',
      );

      // 3-4-5: 400 by 300 pixels is 500 pixels, at 0.36 in per pixel.
      expect(planLowerBoundOf(d.doc, link), _inches(180));
    });

    test('two pins in the same place is a MEASURED ZERO, not a refusal', () {
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(120, 120));
      final dev = d.rackDevice('PP-1', rk);
      final out = d.outlet('WP-1', pin: _pin(120, 120));
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
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      final dev = d.rackDevice('PP-1', rk);
      final flat = d.room('Great Room');
      final risen = d.room('Attic drop', riseAllowance: _inches(96));
      final outFlat = d.outlet('WP-1', pin: _pin(100, 0), locationId: flat);
      final outRisen = d.outlet('WP-2', pin: _pin(100, 0), locationId: risen);

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

      expect(planLowerBoundOf(d.doc, a), _inches(36));
      expect(
        planLowerBoundOf(d.doc, b),
        _inches(132),
        reason: 'the same line plus the 96 in rise',
      );
    });

    test('the scale is the only thing that converts: doubling the typed '
        'distance doubles the floor', () {
      Len? boundAt(Len typed) {
        final d = _Doc()
          ..underlay(
            scale: PlanScale(
              a: const PxPt(0, 0),
              b: const PxPt(100, 0),
              distance: typed,
            ),
          );
        final rk = d.rack('RK-1', pin: _pin(0, 0));
        final dev = d.rackDevice('PP-1', rk);
        final out = d.outlet('WP-1', pin: _pin(100, 0));
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

      expect(boundAt(_inches(36)), _inches(36));
      expect(boundAt(_inches(72)), _inches(72));
    });
  });

  group('the datum is the rack this run lands in', () {
    /// Two racks, both pinned, the run landing in the FAR one.
    ///
    /// LOAD-BEARING. A derivation measuring from the nearest pinned rack,
    /// or from the first in document order, returns 36 in here and passes
    /// every other case in this file.
    test('not the nearest pinned rack, and not the first one', () {
      final d = _Doc()
        ..underlay()
        ..rack('RK-1', pin: _pin(0, 0));
      final far = d.rack('RK-2', pin: _pin(1000, 0));
      final dev = d.rackDevice('PP-2', far);
      final out = d.outlet('WP-1', pin: _pin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'wall'),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(
        planLowerBoundOf(d.doc, link),
        _inches(324),
        reason: '900 px from RK-2, not 100 px from RK-1',
      );
    });

    /// LOAD-BEARING. The rule that produces no number rather than a
    /// convenient one.
    test('an unpinned rack yields NO floor, even when another rack on the '
        'same plan is pinned', () {
      final d = _Doc()
        ..underlay()
        ..rack('RK-1', pin: _pin(0, 0));
      final unpinned = d.rack('RK-2');
      final dev = d.rackDevice('PP-2', unpinned);
      final out = d.outlet('WP-1', pin: _pin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(dev, 'J01')),
        to: const PlaceEndpoint(description: 'wall'),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('a jumper has both ends in one rack, so nothing is the subject', () {
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      final a = d.rackDevice('SW-1', rk);
      final b = d.rackDevice('PP-1', rk);
      d.outlet('WP-1', pin: _pin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(a, 'J01')),
        to: PortEndpoint(d.port(b, '01')),
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('a sub-feed has its ends in two racks, and a rack is a datum '
        'rather than a subject', () {
      final d = _Doc()..underlay();
      final one = d.rack('RK-1', pin: _pin(0, 0));
      final two = d.rack('RK-2', pin: _pin(500, 0));
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
      final d = _Doc()..underlay();
      final one = d.rack('RK-1', pin: _pin(0, 0));
      final two = d.rack('RK-2', pin: _pin(500, 0));
      final out = d.outlet('WP-1', pin: _pin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(d.rackDevice('SW-1', one), 'J01')),
        to: PortEndpoint(d.port(d.rackDevice('SW-2', two), 'J01')),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('a field-to-field run has no rack end at all', () {
      final d = _Doc()
        ..underlay()
        ..rack('RK-1', pin: _pin(0, 0));
      final out = d.outlet('WP-1', pin: _pin(100, 0));
      final link = d.link(
        from: const PlaceEndpoint(description: 'wall'),
        to: const OpenEndpoint('coil'),
        outletId: out,
        fieldLabel: 'GR-1',
      );

      expect(planLowerBoundOf(d.doc, link), isNull);
    });

    test('a link with no conductors has no ends', () {
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      d.rackDevice('PP-1', rk);
      const id = Uuid('link-bare');
      final link = Link(
        id: id,
        designator: 'W099',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('a0'),
        meta: _meta(),
      );
      d.doc.links[id] = link;

      expect(planLowerBoundOf(d.doc, link), isNull);
    });
  });

  group('the subject is where the cable stops', () {
    /// LOAD-BEARING. A derivation that preferred the device, or that fell
    /// back to it, measures 1000 px here instead of 100.
    test('a named outlet wins over a pinned device beyond it', () {
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      final panel = d.rackDevice('PP-1', rk);
      final tv = d.offRackDevice('TV-1', pin: _pin(1000, 0));
      final out = d.outlet('WP-1', pin: _pin(100, 0));
      final link = d.link(
        from: PortEndpoint(d.port(panel, 'J01')),
        to: PortEndpoint(d.port(tv, 'HDMI-1')),
        outletId: out,
        fieldLabel: 'GR-TV-1',
      );

      expect(planLowerBoundOf(d.doc, link), _inches(36));
    });

    /// LOAD-BEARING. The half of the same rule that refuses.
    test('a named outlet that is UNPINNED does not fall back to the '
        'device', () {
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      final panel = d.rackDevice('PP-1', rk);
      final tv = d.offRackDevice('TV-1', pin: _pin(1000, 0));
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
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      final panel = d.rackDevice('PP-1', rk);
      final ceiling = d.room('Great Room', riseAllowance: _inches(12));
      final spk = d.offRackDevice(
        'SPK-1',
        pin: _pin(200, 0),
        locationId: ceiling,
      );
      final link = d.link(
        from: PortEndpoint(d.port(panel, 'J01')),
        to: PortEndpoint(d.port(spk, 'IN')),
      );

      expect(planLowerBoundOf(d.doc, link), _inches(84));
    });

    test('an unpinned off-rack device yields nothing', () {
      final d = _Doc()..underlay();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
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
      final d = _Doc()
        ..underlay()
        ..underlay(id: _ul2);
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      final dev = d.rackDevice('PP-1', rk);
      final out = d.outlet('WP-1', pin: _pin(100, 0, on: _ul2));
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
      for (final scale in <PlanScale?>[null, _degenerate]) {
        final d = _Doc()..underlay(scale: scale);
        final rk = d.rack('RK-1', pin: _pin(0, 0));
        final dev = d.rackDevice('PP-1', rk);
        final out = d.outlet('WP-1', pin: _pin(100, 0));
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
      final d = _Doc();
      final rk = d.rack('RK-1', pin: _pin(0, 0));
      final dev = d.rackDevice('PP-1', rk);
      final out = d.outlet('WP-1', pin: _pin(100, 0));
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
