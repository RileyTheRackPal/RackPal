// PLAN-C/5: the plan model on disk, and the protection that replaced the
// one its brief expected to test.
//
// ═══════════════════════════════════════════════════════════════════════
// THE TEST THIS FILE WAS ASKED FOR CANNOT BE WRITTEN, AND FINDING THAT
// OUT IS WHAT PRODUCED DR-136
// ═══════════════════════════════════════════════════════════════════════
// `#621` said: *"The plan pin is the first field that map exists to
// protect, so write the test that proves it: a document with pins, read
// by a codec that does not know the key, written back, still carrying
// them."*
//
// It does not carry them. `Placement.unknown` is a RESERVED CONTAINER and
// not a harvester: it preserves what a writer deliberately put INSIDE it
// and collects no unrecognised sibling keys, which `placement.dart` and
// `_unknownBag` both state in capitals and which is a correct
// implementation of §11.18.2(5). `planPin` is a sibling key like any
// other, so a build that does not model it drops it, which is exactly the
// hazard §11.18.1 described and bought the bag to prevent.
//
// DR-136 closes it from the other end: a document carrying plan data
// stamps `minReaderVersion` 5, so a build that cannot model a pin opens
// the file READ-ONLY and never gets to write the version that lost it.
// So this file asserts two things instead of the one that was asked for:
// the reserved-container CONTRACT, so nobody re-derives the false belief
// from an absence of tests, and the STAMP that does the protecting.

import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _fixed = DateTime.utc(2026, 9, 7, 9);

EntityMeta _meta() =>
    EntityMeta(createdAt: _fixed, updatedAt: _fixed, updatedBy: 'tester');

const _underlayId = Uuid('0190e3c1-1111-7000-8000-000000000001');
const _rackId = Uuid('0190e3c1-2222-7000-8000-000000000002');
const _locationId = Uuid('0190e3c1-3333-7000-8000-000000000003');
const _deviceId = Uuid('0190e3c1-4444-7000-8000-000000000004');
const _outletId = Uuid('0190e3c1-5555-7000-8000-000000000005');
const _bodyId = Uuid('0190e3c1-6666-7000-8000-000000000006');

const _templateRef = TemplateRef(
  templateId: TemplateId('tpl.test'),
  version: 1,
  contentHash: 'sha256:test',
);

RackDocument _doc() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-000000000000'),
  appVersion: '0.6.10',
  createdAt: _fixed,
  modifiedAt: _fixed,
  meta: _meta(),
  info: ProjectInfo(projectName: 'Ashford Residence'),
);

PlanUnderlay _underlay({PlanScale? scale, PlanSourcePage? sourcePage}) =>
    PlanUnderlay(
      id: _underlayId,
      name: 'Level 1',
      imageMember: 'underlays/$_underlayId.png',
      format: PlanImageFormat.png,
      pixelWidth: 4000,
      pixelHeight: 3000,
      contentHash: 'sha256:abcdef',
      order: const FracIndex('a0'),
      meta: _meta(),
      locationId: _locationId,
      scale: scale,
      sourcePage: sourcePage,
    );

/// The page a rendered underlay came from. Page THREE, so an off-by-one
/// in either direction is visible rather than symmetric.
const _sourcePage = PlanSourcePage(
  member: 'sources/$_underlayId.pdf',
  pageIndex: 2,
  contentHash: 'sha256:sourcepdf',
);

/// Deliberately not round: a scale that divides evenly would round-trip
/// through an encoder that quietly went via millimetres.
const _scale = PlanScale(
  a: PxPt(101, 202),
  b: PxPt(1301, 202),
  distance: Len(3_657_600_001),
);

const _pin = PlanPin(underlayId: _underlayId, at: PxPt(742, 1183));

Rack _rack({PlanPin? pin}) => Rack(
  id: _rackId,
  name: 'AV Rack',
  designator: 'RK-1',
  heightU: 42,
  order: const FracIndex('a0'),
  meta: _meta(),
  planPin: pin,
);

RackDocument _withUnderlay({PlanScale? scale, PlanSourcePage? sourcePage}) {
  final doc = _doc();
  doc.underlays[_underlayId] = _underlay(scale: scale, sourcePage: sourcePage);
  return doc;
}

int _stampOf(RackDocument doc) =>
    (jsonDecode(utf8.decode(_codec.write(doc)))
            as Map<String, Object?>)['minReaderVersion']!
        as int;

RackDocument _reopen(RackDocument doc) {
  final result = _codec.read(_codec.write(doc));
  expect(result, isA<Ok<RackDocument>>());
  return (result as Ok<RackDocument>).value;
}

void main() {
  group('PlanUnderlay round-trips, and the inputs are what persist', () {
    test('every field survives a write and a read', () {
      final back = _reopen(
        _withUnderlay(scale: _scale),
      ).underlays[_underlayId]!;

      expect(back.name, 'Level 1');
      expect(back.imageMember, 'underlays/$_underlayId.png');
      expect(back.format, PlanImageFormat.png);
      expect(back.pixelWidth, 4000);
      expect(back.pixelHeight, 3000);
      expect(back.contentHash, 'sha256:abcdef');
      expect(back.locationId, _locationId);
      expect(back.order.v, 'a0');
      expect(back.scale, _scale);
    });

    test('THE FACTOR IS NEVER STORED: the file holds two points and a Len', () {
      final out = utf8.decode(_codec.write(_withUnderlay(scale: _scale)));
      // What CR-001 requires be there.
      expect(out, contains('"distanceNm": 3657600001'));
      expect(out, contains('"px": 101'));
      expect(out, contains('"py": 202'));
      // And what it forbids: no derived ratio, under any spelling.
      expect(out, isNot(contains('nanometresPerPixel')));
      expect(out, isNot(contains('perPixel')));
      expect(out, isNot(contains('factor')));
      expect(out, isNot(contains('scaleFactor')));
    });

    test(
      'an UNCALIBRATED underlay writes no scale key and reads back null',
      () {
        final out = utf8.decode(_codec.write(_withUnderlay()));
        expect(out, isNot(contains('"scale"')));

        final back = _reopen(_withUnderlay()).underlays[_underlayId]!;
        expect(back.scale, isNull);
        expect(back.isCalibrated, isFalse);
        // AND IT DID NOT BECOME 1:1 (G4). The distinction the whole field
        // exists to preserve: uncalibrated is a fact, not a default.
        expect(back.scale?.nanometresPerPixel, isNull);
      },
    );

    test('CR-117: byte round trip over a document carrying a plan', () {
      final first = _codec.write(_withUnderlay(scale: _scale));
      final second = _codec.write(_reopen(_withUnderlay(scale: _scale)));
      expect(second, first);

      // A write, a reopen and a second write, which is the criterion's own
      // wording and catches an encoder that is stable only on the object
      // it just built.
      final third = _codec.write(
        (_codec.read(second) as Ok<RackDocument>).value,
      );
      expect(third, first);
    });

    test('the plan travels the ZIP path too, unchanged', () {
      final json = _codec.write(_withUnderlay(scale: _scale));
      final container = writeContainerBytes(json, {
        'underlays/$_underlayId.png': Uint8List.fromList(
          List<int>.generate(1024, (i) => i % 256),
        ),
      });
      final parts = (readContainerParts(container) as Ok<ContainerParts>).value;
      expect(parts.documentBytes, json);

      final back = (_codec.read(parts.documentBytes) as Ok<RackDocument>).value;
      expect(back.underlays[_underlayId]!.scale, _scale);
    });
  });

  group('PLAN-K/3: a rendered page keeps its source (DR-153 §11.152.6)', () {
    test('every field of the source page survives a write and a read', () {
      final back = _reopen(
        _withUnderlay(sourcePage: _sourcePage),
      ).underlays[_underlayId]!;

      expect(back.sourcePage, _sourcePage);
      expect(back.sourcePage!.member, 'sources/$_underlayId.pdf');
      expect(back.sourcePage!.pageIndex, 2);
      expect(back.sourcePage!.contentHash, 'sha256:sourcepdf');
    });

    /// LOAD-BEARING. The asymmetry IS the ruling: a lifted page's stored
    /// bytes already are the source, so a copy would store one drawing
    /// twice. An absent key is what says "there is nothing to keep".
    test('an underlay with no source writes no key at all', () {
      final out = utf8.decode(_codec.write(_withUnderlay()));

      expect(out, isNot(contains('sourcePage')));
      expect(
        _reopen(_withUnderlay()).underlays[_underlayId]!.sourcePage,
        isNull,
      );
    });

    test('CR-117: byte round trip over a document carrying a source page', () {
      final first = _codec.write(_withUnderlay(sourcePage: _sourcePage));
      final second = _codec.write(
        _reopen(_withUnderlay(sourcePage: _sourcePage)),
      );

      expect(second, orderedEquals(first));
    });

    /// CR-093: a hostile file is an Err and never a throw, and the check
    /// happens when the value ARRIVES rather than on the day something
    /// finally reads it.
    test('a negative page index is refused at the boundary', () {
      final tree =
          jsonDecode(
                utf8.decode(
                  _codec.write(_withUnderlay(sourcePage: _sourcePage)),
                ),
              )
              as Map<String, Object?>;
      final underlays =
          (tree['document']! as Map<String, Object?>)['underlays']!
              as Map<String, Object?>;
      final underlay = underlays[_underlayId.v]! as Map<String, Object?>;
      (underlay['sourcePage']! as Map<String, Object?>)['pageIndex'] = -1;

      final result = _codec.read(
        Uint8List.fromList(utf8.encode(jsonEncode(tree))),
      );
      expect(result, isA<Err<RackDocument>>());
    });
  });

  group('the pin round-trips on all three carriers', () {
    test('Rack', () {
      final doc = _withUnderlay()..racks[_rackId] = _rack(pin: _pin);
      expect(_reopen(doc).racks[_rackId]!.planPin, _pin);
    });

    test('Outlet', () {
      final doc = _withUnderlay();
      doc.outlets[_outletId] = Outlet(
        id: _outletId,
        structureBodyId: _bodyId,
        designation: 'WP-1',
        order: const FracIndex('a0'),
        meta: _meta(),
        planPin: _pin,
      );
      expect(_reopen(doc).outlets[_outletId]!.planPin, _pin);
    });

    test('OffRackPlacement, without the union gaining a variant', () {
      final doc = _withUnderlay();
      doc.devices[_deviceId] = DeviceInstance(
        id: _deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'SPK-1',
        name: 'Wall speaker',
        placement: const OffRackPlacement(
          locationId: _locationId,
          planPin: _pin,
        ),
        meta: _meta(),
      );

      final back = _reopen(doc).devices[_deviceId]!.placement;
      expect(back, isA<OffRackPlacement>());
      final off = back as OffRackPlacement;
      expect(off.planPin, _pin);
      // The pin did not displace the room. `locationId` remains the
      // schedule's source of room truth (docs/15 §3.4).
      expect(off.locationId, _locationId);
    });

    test('an unpinned document writes no planPin key anywhere', () {
      final doc = _withUnderlay()..racks[_rackId] = _rack();
      expect(utf8.decode(_codec.write(doc)), isNot(contains('planPin')));
    });
  });

  group('Location.riseAllowance, the field two rulings spent', () {
    Location location({Len? rise}) => Location(
      id: _locationId,
      kind: LocationKind.room,
      name: 'Great Room',
      code: 'GR',
      order: const FracIndex('a0'),
      meta: _meta(),
      riseAllowance: rise,
    );

    test('it round-trips, with its unit in the wire name', () {
      final doc = _doc();
      doc.locations[_locationId] = location(rise: const Len(2_743_200_001));
      expect(
        utf8.decode(_codec.write(doc)),
        contains('"riseAllowanceNm": 2743200001'),
      );
      expect(
        _reopen(doc).locations[_locationId]!.riseAllowance,
        const Len(2_743_200_001),
      );
    });

    test('null writes no key, and ZERO writes one', () {
      final absent = _doc()..locations[_locationId] = location();
      expect(utf8.decode(_codec.write(absent)), isNot(contains('riseAllow')));

      // G4/CR-114: a measured zero is a statement and must survive as one.
      // A room where somebody confirmed there is no rise is not a room
      // nobody has looked at.
      final zero = _doc()..locations[_locationId] = location(rise: Len.zero);
      expect(
        utf8.decode(_codec.write(zero)),
        contains('"riseAllowanceNm": 0'),
      );
      expect(_reopen(zero).locations[_locationId]!.riseAllowance, Len.zero);
    });
  });

  group('DR-136: the stamp is decided from the CONTENT', () {
    test('an ordinary document stamps kMinReaderVersion', () {
      expect(_stampOf(_doc()), kMinReaderVersion);
      expect(_stampOf(_doc()), 3);
    });

    test('an underlay alone raises it', () {
      expect(_stampOf(_withUnderlay()), kPlanMinReaderVersion);
    });

    test('each of the three pin carriers raises it on its own', () {
      final withRack = _doc()..racks[_rackId] = _rack(pin: _pin);
      expect(_stampOf(withRack), kPlanMinReaderVersion, reason: 'rack');

      final withOutlet = _doc();
      withOutlet.outlets[_outletId] = Outlet(
        id: _outletId,
        structureBodyId: _bodyId,
        designation: 'WP-1',
        order: const FracIndex('a0'),
        meta: _meta(),
        planPin: _pin,
      );
      expect(_stampOf(withOutlet), kPlanMinReaderVersion, reason: 'outlet');

      final withDevice = _doc();
      withDevice.devices[_deviceId] = DeviceInstance(
        id: _deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'SPK-1',
        name: 'Wall speaker',
        placement: const OffRackPlacement(planPin: _pin),
        meta: _meta(),
      );
      expect(_stampOf(withDevice), kPlanMinReaderVersion, reason: 'offRack');
    });

    test('A DEVICE THAT IS OFF-RACK WITHOUT A PIN DOES NOT RAISE IT, which '
        'is what stops the stamp being "any off-rack device"', () {
      final doc = _doc();
      doc.devices[_deviceId] = DeviceInstance(
        id: _deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'SPK-1',
        name: 'Wall speaker',
        placement: const OffRackPlacement(locationId: _locationId),
        meta: _meta(),
      );
      expect(_stampOf(doc), kMinReaderVersion);
    });

    test('riseAllowance DELIBERATELY DOES NOT RAISE IT', () {
      // DR-136 §11.135.5. It is an ordinary additive optional field on
      // `tia570Grade`'s precedent: an older build drops it exactly as it
      // already drops those, and a number somebody can retype is not a
      // drawing somebody spent an afternoon making. Widening the
      // predicate to every new optional field would make every document
      // unopenable on every older build.
      final doc = _doc();
      doc.locations[_locationId] = Location(
        id: _locationId,
        kind: LocationKind.room,
        name: 'Great Room',
        code: 'GR',
        order: const FracIndex('a0'),
        meta: _meta(),
        riseAllowance: const Len(2_743_200_000),
      );
      expect(_stampOf(doc), kMinReaderVersion);
    });

    test('the stamp is not sticky: clearing the plan lowers it again', () {
      final doc = _withUnderlay();
      expect(_stampOf(doc), kPlanMinReaderVersion);
      doc.underlays.clear();
      expect(_stampOf(doc), kMinReaderVersion);
    });
  });

  group('THE RESERVED CONTAINER, asserted so nobody re-derives the false '
      'belief from an absence of tests', () {
    test('`unknown` preserves what a writer put IN it', () {
      final doc = _doc();
      doc.devices[_deviceId] = DeviceInstance(
        id: _deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'SPK-1',
        name: 'Wall speaker',
        placement: const OffRackPlacement(
          locationId: _locationId,
          unknown: {'somethingLater': 42},
        ),
        meta: _meta(),
      );

      final back = _reopen(doc).devices[_deviceId]!.placement;
      expect((back as OffRackPlacement).unknown['somethingLater'], 42);
    });

    test('AND IT COLLECTS NO UNRECOGNISED SIBLING KEY, which is why the '
        'test #621 asked for could not be written', () {
      // Hand-built JSON with a sibling key this build does not model,
      // standing in for a field a LATER build will add. The bag does not
      // reach it, so it is gone after a round trip.
      //
      // This is not a defect: `placement.dart` says so in capitals and
      // names the ruling a harvester would need. It is asserted because
      // the belief that the bag protects siblings is what `#621`
      // inherited from DR-019 §11.18.1, and an absence of tests is how
      // that belief survived long enough to be built on.
      final doc = _doc();
      doc.devices[_deviceId] = DeviceInstance(
        id: _deviceId,
        kind: DeviceKind.rackDevice,
        templateRef: _templateRef,
        designator: 'SPK-1',
        name: 'Wall speaker',
        placement: const OffRackPlacement(locationId: _locationId),
        meta: _meta(),
      );

      final tree =
          jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
      final devices = (tree['document']! as Map)['devices']! as Map;
      final placement =
          (devices[_deviceId.v]! as Map)['placement']! as Map<String, Object?>;
      placement['aFieldFromLater'] = 'do not lose me';

      final rebuilt = Uint8List.fromList(utf8.encode(jsonEncode(tree)));
      final reread = (_codec.read(rebuilt) as Ok<RackDocument>).value;
      final out = utf8.decode(_codec.write(reread));

      expect(out, isNot(contains('aFieldFromLater')));
    });

    test('SO THE STAMP IS THE PROTECTION, and it is on the same document', () {
      // The two halves together: a build that does not model `planPin`
      // would drop it exactly as the case above drops its sibling, and
      // `minReaderVersion` 5 is what stops that build from ever writing.
      final doc = _withUnderlay()..racks[_rackId] = _rack(pin: _pin);
      expect(_stampOf(doc), kPlanMinReaderVersion);
      expect(kPlanMinReaderVersion, greaterThan(kMinReaderVersion));
    });
  });
}
