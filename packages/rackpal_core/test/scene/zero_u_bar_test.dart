// AC-044's plain bar (`#883`, DR-166 §11.165).
//
// ═══════════════════════════════════════════════════════════════════════
// THE ASSERTION THE TICKET ASKED FOR BY NAME
// ═══════════════════════════════════════════════════════════════════════
// `#883`'s DONE WHEN closes with *"a case pins that a rack-mounted and a
// 0U device are both in the scene, which no test asserts today"*. That is
// the first group below, and it is the whole defect in one line:
// `scene_builder.dart` read `if (placement is! RailPlacement) continue;`,
// so a 0U device was never drawn, never hit-tested and therefore never
// SELECTABLE, which is why `#876` had to put its inspector fields on the
// rack panel rather than on the device panel AC-044 names.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

const Uuid _rackId = Uuid('rack-1');
const Uuid _pduId = Uuid('dev-pdu');
const Uuid _ampId = Uuid('dev-amp');

Map<String, TemplateSnapshot> _templates() => <String, TemplateSnapshot>{
  'AMP@1': TemplateSnapshot(
    templateId: const TemplateId('AMP'),
    version: 1,
    contentHash: 'h',
    body: TemplateBody(
      manufacturer: 'M',
      model: 'amp',
      displayName: 'Amp',
      frontU: 2,
      side: OccupancySide.front,
    ),
    capturedAt: DateTime.utc(2026),
  ),
  'P01@1': TemplateSnapshot(
    templateId: const TemplateId('P01'),
    version: 1,
    contentHash: 'h',
    body: TemplateBody(
      manufacturer: 'M',
      model: 'pdu',
      displayName: 'PDU',
      side: OccupancySide.zeroUVertical,
      mountMethod: MountMethod.zeroU,
    ),
    capturedAt: DateTime.utc(2026),
  ),
};

Rack _rack({
  ZeroUChannelSide side = ZeroUChannelSide.frontLeft,
  bool mirror = false,
}) =>
    Rack(
        id: _rackId,
        name: 'R',
        designator: 'RK-1',
        heightU: 12,
        order: const FracIndex('a0'),
        meta: testMeta(),
        mirrorRearElevation: mirror,
      )
      ..zeroUChannels.add(
        ZeroUChannel(id: 'ch-1', side: side, startU: 1, endU: 12),
      );

DeviceInstance _amp() => DeviceInstance(
  id: _ampId,
  kind: DeviceKind.rackDevice,
  templateRef: const TemplateRef(
    templateId: TemplateId('AMP'),
    version: 1,
    contentHash: 'h',
  ),
  designator: 'AMP-1',
  name: 'Amplifier',
  placement: const RailPlacement(rackId: _rackId, ruIndex: 3, face: Face.front),
  meta: testMeta(),
);

DeviceInstance _pdu({Len? span, Len offset = Len.zero}) => DeviceInstance(
  id: _pduId,
  kind: DeviceKind.rackDevice,
  templateRef: const TemplateRef(
    templateId: TemplateId('P01'),
    version: 1,
    contentHash: 'h',
  ),
  designator: 'PDU-1',
  name: 'Vertical PDU',
  placement: ZeroUPlacement(
    rackId: _rackId,
    channelId: 'ch-1',
    offsetFromChannelStart: offset,
    spanAlongChannel: span,
    orientation: ZeroUOrientation.vertical,
  ),
  meta: testMeta(),
);

RackScene _scene({
  required List<DeviceInstance> devices,
  Rack? rack,
  Face face = Face.front,
}) => buildRackScene(
  rack: rack ?? _rack(),
  devices: devices,
  templates: _templates(),
  face: face,
  lod: LodLevel.full,
  measurer: FakeMeasurer(),
);

void main() {
  const geo = RackGeometry(12);

  group('both kinds of device are in the scene (`#883`)', () {
    test('A RACK-MOUNTED AND A 0U DEVICE ARE BOTH HIT-TESTABLE, which is '
        'what selectable MEANS on this canvas', () {
      final scene = _scene(
        devices: [
          _amp(),
          _pdu(span: kRackUnit * 12),
        ],
      );

      expect(
        scene.scene.hits.map((h) => h.entityId),
        containsAll(<String>[_ampId.v, _pduId.v]),
        reason:
            'scene_builder dropped every non-rail placement, so a 0U '
            'device could not be clicked at all',
      );
      expect(
        scene.devices.map((l) => l.deviceId),
        containsAll(<Uuid>[_ampId, _pduId]),
      );
    });

    test('and the 0U device is ABSENT when it is in no channel this rack '
        'has', () {
      // A hand-edited file can name a channel that is not there. `PLC-003`
      // reports it; the scene builder must not take the whole elevation
      // down over it.
      final rack = Rack(
        id: _rackId,
        name: 'R',
        designator: 'RK-1',
        heightU: 12,
        order: const FracIndex('a0'),
        meta: testMeta(),
      );
      final scene = _scene(devices: [_amp(), _pdu()], rack: rack);

      expect(scene.scene.hits.map((h) => h.entityId), contains(_ampId.v));
      expect(
        scene.scene.hits.map((h) => h.entityId),
        isNot(contains(_pduId.v)),
      );
    });
  });

  group('where the bar sits (§11.165.4)', () {
    DBox rectFor(RackScene scene, Uuid id) =>
        scene.devices.firstWhere((l) => l.deviceId == id).rect;

    test('ON THE RAIL, at the rail width and not the opening', () {
      final scene = _scene(devices: [_pdu(span: kRackUnit * 12)]);
      final rect = rectFor(scene, _pduId);

      expect(rect.left, geo.railLeft);
      // `closeTo`, because `railWidth` is DERIVED from the real EIA-19
      // flange rather than written down, and `rect.width` comes back
      // through `right - left`: the two differ in the last few ulps and
      // an exact match would be pinning the arithmetic rather than the
      // geometry.
      expect(rect.width, closeTo(RackGeometry.railWidth, 1e-9));
      expect(
        rect.width,
        lessThan(RackGeometry.openingWidth),
        reason: 'a bar in the opening would cover the devices',
      );
    });

    test('the RIGHT rail for a right-hand channel', () {
      final scene = _scene(
        devices: [_pdu(span: kRackUnit * 12)],
        rack: _rack(side: ZeroUChannelSide.frontRight),
      );
      expect(rectFor(scene, _pduId).left, geo.rightRailLeft);
    });

    test('and MIRRORING SWAPS THE RAILS, as it swaps everything else', () {
      final plain = _scene(
        devices: [_pdu(span: kRackUnit * 12)],
        rack: _rack(side: ZeroUChannelSide.rearLeft),
        face: Face.rear,
      );
      final mirrored = _scene(
        devices: [_pdu(span: kRackUnit * 12)],
        rack: _rack(side: ZeroUChannelSide.rearLeft, mirror: true),
        face: Face.rear,
      );

      expect(rectFor(plain, _pduId).left, geo.railLeft);
      expect(
        rectFor(mirrored, _pduId).left,
        geo.rightRailLeft,
        reason:
            'a mirrored rear elevation is the rack read from behind, so '
            'the rail the model calls left is on the viewer right',
      );
    });

    test('a FRONT channel does not draw on the rear sheet', () {
      final scene = _scene(
        devices: [_pdu(span: kRackUnit * 12)],
        face: Face.rear,
      );
      expect(
        scene.scene.hits.map((h) => h.entityId),
        isNot(contains(_pduId.v)),
      );
    });
  });

  group('how long the bar is (§11.165.1, §11.165.2)', () {
    DBox rectFor(RackScene scene) =>
        scene.devices.firstWhere((l) => l.deviceId == _pduId).rect;

    test('THE SPAN IS THE HEIGHT, measured off the channel start', () {
      final scene = _scene(devices: [_pdu(span: kRackUnit * 12)]);
      final rect = rectFor(scene);

      expect(rect.height, geo.rackHeight);
      expect(rect.bottom, geo.yBottomOfU(1));
      expect(rect.top, geo.yTopOfU(12));
    });

    test('and the OFFSET moves it up the channel without changing its '
        'length', () {
      final scene = _scene(
        devices: [_pdu(span: kRackUnit * 4, offset: kRackUnit * 4)],
      );
      final rect = rectFor(scene);

      expect(rect.height, RackGeometry.unitsPerRu * 4);
      expect(
        rect.bottom,
        geo.yBottomOfU(5),
        reason:
            'a channel starting at U 1 with a device 4 U along it is a '
            'device at U 5',
      );
    });

    test('AN UNKNOWN SPAN IS ONE U AND SAYS SO, rather than a bar the file '
        'cannot support (G4)', () {
      final scene = _scene(devices: [_pdu()]);
      final rect = rectFor(scene);

      expect(rect.height, RackGeometry.unitsPerRu);
      expect(
        scene.devices.firstWhere((l) => l.deviceId == _pduId).semanticLabel,
        contains('length not recorded'),
        reason:
            'the drawing says it with a hollow outline, which is no use '
            'to somebody who is not looking at it',
      );
    });

    test('and a KNOWN span does not carry that sentence', () {
      final scene = _scene(devices: [_pdu(span: kRackUnit * 12)]);
      expect(
        scene.devices.firstWhere((l) => l.deviceId == _pduId).semanticLabel,
        isNot(contains('not recorded')),
      );
    });
  });
}
