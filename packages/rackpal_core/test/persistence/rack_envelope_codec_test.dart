// DR-239 §11.238.2 (`#923`, ENV-1): a rack's rail clearance and door
// clearance are two measurements, and the file keeps them apart.
//
// THE CASE THIS FILE EXISTS FOR is the user's distinction: "Front Rail
// Clearance" is the depth inside the door, "Door Clearance" the swing space
// in front of it. The model had only the second. A codec that wrote one
// under the other's key would round-trip perfectly and hand a cabinetmaker
// the wrong number.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

Len _mm(int mm) => Len(mm * 1000000);

RackDocument _doc(Rack rack) => RackDocument(
  id: const Uuid('doc-envelope'),
  appVersion: 'test',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
)..racks[rack.id] = rack;

Rack _rack({Len? frontRail, Len? rearRail}) => Rack(
  id: const Uuid('rack-1'),
  name: 'Closet',
  designator: 'RK-1',
  heightU: 42,
  order: const FracIndex('a0'),
  meta: _meta(),
  overallWidth: _mm(600),
  overallDepth: _mm(1000),
  overallHeight: _mm(2000),
  ownWeight: const Mass(68 * 1000000000),
  hasFrontDoor: true,
  hasRearDoor: true,
  frontDoorClearance: _mm(600),
  rearDoorClearance: _mm(550),
  frontRailClearance: frontRail,
  rearRailClearance: rearRail,
);

const _codec = JsonDocumentCodec();

Map<String, Object?> _rackJson(Uint8List bytes) {
  final root = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  final doc = root['document']! as Map<String, Object?>;
  final racks = doc['racks']! as Map<String, Object?>;
  return racks['rack-1']! as Map<String, Object?>;
}

Rack _back(Uint8List bytes) {
  final read = _codec.read(bytes);
  expect(read, isA<Ok<RackDocument>>());
  return (read as Ok<RackDocument>).value.racks[const Uuid('rack-1')]!;
}

void main() {
  test('THE WHOLE ENVELOPE ROUND-TRIPS, byte for byte (CR-117)', () {
    final first = _codec.write(
      _doc(_rack(frontRail: _mm(75), rearRail: _mm(120))),
    );
    final back = _back(first);
    expect(_codec.write(_doc(back)), first);
    expect(
      [
        back.overallWidth,
        back.overallDepth,
        back.overallHeight,
        back.ownWeight,
        back.hasFrontDoor,
        back.hasRearDoor,
      ],
      [_mm(600), _mm(1000), _mm(2000), const Mass(68 * 1000000000), true, true],
    );
  });

  test('RAIL AND DOOR CLEARANCE ARE TWO KEYS, each with its own number', () {
    final bytes = _codec.write(
      _doc(_rack(frontRail: _mm(75), rearRail: _mm(120))),
    );
    final json = _rackJson(bytes);
    expect(json['frontRailClearanceNm'], _mm(75).nm);
    expect(json['frontDoorClearanceNm'], _mm(600).nm);
    expect(json['rearRailClearanceNm'], _mm(120).nm);
    expect(json['rearDoorClearanceNm'], _mm(550).nm);
    final back = _back(bytes);
    expect(back.frontRailClearance, _mm(75));
    expect(back.frontDoorClearance, _mm(600));
    expect(back.rearRailClearance, _mm(120));
    expect(back.rearDoorClearance, _mm(550));
  });

  test('A FILE FROM BEFORE DR-239 opens, its rail clearances unknown, and '
      'writes no key for them (G4)', () {
    final bytes = _codec.write(_doc(_rack()));
    final json = _rackJson(bytes);
    expect(json.containsKey('frontRailClearanceNm'), isFalse);
    expect(json.containsKey('rearRailClearanceNm'), isFalse);
    final back = _back(bytes);
    expect(back.frontRailClearance, isNull);
    expect(back.rearRailClearance, isNull);
    expect(back.frontDoorClearance, _mm(600), reason: 'the swing space kept');
  });
}
