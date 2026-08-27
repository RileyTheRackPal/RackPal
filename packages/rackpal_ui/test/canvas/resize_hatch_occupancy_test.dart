// docs/04-rack-editor.md §4.1's real-time shrink hatch, against the ONE
// question the per-gesture drag tests cannot ask: does the live preview
// enumerate the SAME occupants the release will?
//
// WHY A FILE OF ITS OWN, and why it injects a document. The divergence only
// exists for occupants `boltedOccupantsOnFace` deliberately cannot model — a
// rail device whose `templates['<id>@<version>']` snapshot is missing, or a
// device mounted in a 0U channel (core's `DoomedKind`). Both are, in
// rack_shrink_test.dart's own words, "reachable by loading a file and none by
// in-app authoring today": there is no 0U placement UI and
// `buildPlaceFromCatalogCommand` refuses a missing template. So no sequence of
// gestures against the built-in demo seed can produce one, every occupant in
// that seed is modelled, and a hatch test written against it agrees with
// itself no matter which scan the preview uses — a test that cannot fail.
// `RackCanvasScreen.document` exists for exactly this, as its own doc says.
//
// THE DEFECT THESE PIN. `planRackShrink` was fixed to enumerate those
// occupants; `_doomedRectsFor` was not, and went on deriving the hatch from
// `boltedOccupantsOnFace` alone. The top-edge drag therefore painted a clean,
// unhatched preview and a bare "12U (-12)" chip for exactly the occupants the
// planner dooms one event later, so §4.1's "the collision is visible BEFORE
// release" was false in the only case where it mattered — and the modal that
// then opened named a casualty the whole gesture had insisted did not exist.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'rack_scene_to_screen.dart';

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

const _rackId = Uuid('rack-hatch');
final _when = DateTime.utc(2026, 7, 18);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// A 24U rack holding one ordinary 2U device at U1 — comfortably below the
/// 12U the drags below aim at, so it is never the reason anything is doomed.
RackDocument _rack24U() {
  final doc = RackDocument(
    id: const Uuid('doc-hatch'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Hatch Rack',
    designator: 'RK-1',
    heightU: 24,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.templates['tpl.h2@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.h2'),
    version: 1,
    contentHash: 'sha256:tpl.h2',
    capturedAt: _when,
    body: TemplateBody(
      manufacturer: 'Generic',
      model: 'tpl.h2',
      displayName: 'Two-U device',
      frontU: 2,
      rearU: 2,
      side: OccupancySide.both,
      mountMethod: MountMethod.rackEars,
    ),
  );
  doc.devices[const Uuid('dev-low')] = DeviceInstance(
    id: const Uuid('dev-low'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.h2'),
      version: 1,
      contentHash: 'sha256:tpl.h2',
    ),
    designator: 'LOW-1',
    name: 'Low device',
    placement: const RailPlacement(
      rackId: _rackId,
      ruIndex: 1,
      face: Face.front,
    ),
    meta: _meta(),
  );
  return doc;
}

/// DEV-X: rail-placed at U20, with NO `templates['tpl.gone@1']` entry — the
/// dangling-snapshot flavour of `DoomedKind.unmodelledRail`.
void _addDanglingRailDevice(RackDocument doc) {
  doc.devices[const Uuid('dev-x')] = DeviceInstance(
    id: const Uuid('dev-x'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.gone'),
      version: 1,
      contentHash: 'sha256:tpl.gone',
    ),
    designator: 'DEV-X',
    name: 'Orphaned device',
    placement: const RailPlacement(
      rackId: _rackId,
      ruIndex: 20,
      face: Face.front,
    ),
    meta: _meta(),
  );
}

/// PDU-1 in a 0U channel spanning U1-U24 — `DoomedKind.zeroU`, whose doomed
/// footprint is its CHANNEL's span (the range that must survive for it to
/// still have a home).
void _addZeroUOccupant(RackDocument doc) {
  doc.racks[_rackId]!.zeroUChannels.add(
    ZeroUChannel(
      id: 'chan-a',
      side: ZeroUChannelSide.rearLeft,
      startU: 1,
      endU: 24,
    ),
  );
  doc.devices[const Uuid('dev-pdu')] = DeviceInstance(
    id: const Uuid('dev-pdu'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.pdu0u'),
      version: 1,
      contentHash: 'sha256:tpl.pdu0u',
    ),
    designator: 'PDU-1',
    name: 'Vertical PDU',
    placement: const ZeroUPlacement(
      rackId: _rackId,
      channelId: 'chan-a',
      offsetFromChannelStart: Len.zero,
      orientation: ZeroUOrientation.vertical,
    ),
    meta: _meta(),
  );
}

Widget _app(RackDocument doc) => MaterialApp(
  home: Scaffold(
    body: RackCanvasScreen(measurer: _FakeMeasurer(), document: doc),
  ),
);

/// A point inside §4.1's 8px top-edge grab band.
///
/// THE ANCHOR GOES THROUGH THE VIEWPORT AND THE INSET DOES NOT (`#710`).
/// The band is 8 SCREEN px scale-compensated, so the 2px offset stays in
/// screen units while scene y == 0 — the rack's top edge — is asked of the
/// live transform rather than assumed to be the canvas corner.
///
/// The x is the RACK'S CENTRE for `rack_resize_drag_test.dart`'s reason: a
/// fixed scene x that cleared the zoom HUD on the left at identity zoom
/// lands under the face toggle on the right once the rack is framed, and
/// centring puts the rack's middle at the canvas's middle, clear of both.
Offset _topEdgeGrab(WidgetTester tester) =>
    sceneToScreen(tester, _hatchGeo.rackWidth / 2, 0) + const Offset(0, 2);

/// The document under test is a 24U rack.
const _hatchGeo = RackGeometry(24);

/// Drags the top edge from 24U down to 12U, leaving the pointer DOWN so the
/// live preview can be inspected.
Future<TestGesture> _dragTopEdgeTo12U(WidgetTester tester) async {
  final g = await tester.startGesture(_topEdgeGrab(tester));
  await g.moveBy(sceneDelta(tester, 0, 12 * RackGeometry.unitsPerRu));
  await tester.pump();
  return g;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets('an occupant the rail scan cannot model is hatched DURING the '
      'drag, not sprung on the user by the modal after it', (tester) async {
    final doc = _rack24U();
    _addDanglingRailDevice(doc);
    await tester.pumpWidget(_app(doc));
    await tester.pump();

    final g = await _dragTopEdgeTo12U(tester);

    expect(find.text('12U (-12)'), findsOneWidget, reason: "§4.1's readout");
    expect(
      find.text('1 device would lose its U'),
      findsOneWidget,
      reason:
          'DEV-X sits at U20 and the rack top is coming down to U12. The '
          'preview must say so while the pointer is still down — this is the '
          'assertion the old boltedOccupantsOnFace-only scan failed, showing a '
          'bare "12U (-12)" in tertiaryContainer with no warning line at all',
    );

    // AND THE COMMIT AGREES, which is the actual invariant: the modal names
    // the same casualty the drag warned about, rather than contradicting a
    // preview that promised a free shrink one event earlier.
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Shrink RK-1 to 12U?'), findsOneWidget);
    expect(find.textContaining('DEV-X'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('a 0U-channel occupant is hatched during the drag too — the '
      'other half of what the rail scan drops', (tester) async {
    final doc = _rack24U();
    _addZeroUOccupant(doc);
    await tester.pumpWidget(_app(doc));
    await tester.pump();

    final g = await _dragTopEdgeTo12U(tester);

    expect(find.text('12U (-12)'), findsOneWidget);
    expect(
      find.text('1 device would lose its U'),
      findsOneWidget,
      reason:
          "PDU-1's channel spans U1-U24, so a 12U rack cannot hold it — "
          'and `scene_builder` draws nothing for it, which is precisely why '
          'the hatch has to come from the document rather than the layouts',
    );

    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Shrink RK-1 to 12U?'), findsOneWidget);
    expect(find.textContaining('PDU-1'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('a shrink that really is free still previews as free — the '
      'hatch did not simply become louder', (tester) async {
    // THE OTHER DIRECTION, without which the two tests above are satisfied by
    // "always warn". The same rack with only its modelled 2U occupant at U1
    // loses nobody at 12U, so the chip must stay unblocked and the release
    // must commit straight through with no modal.
    await tester.pumpWidget(_app(_rack24U()));
    await tester.pump();

    final g = await _dragTopEdgeTo12U(tester);
    expect(find.text('12U (-12)'), findsOneWidget);
    expect(find.textContaining('would lose'), findsNothing);

    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Shrink RK-1 to 12U?'), findsNothing);
    expect(find.text('12U'), findsWidgets, reason: 'the header stepper');
  });
}
