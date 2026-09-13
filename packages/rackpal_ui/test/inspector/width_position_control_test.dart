// The `Width position` dropdown (`#269`, M5-C, CR-030, docs/04 §3).
//
// ═══════════════════════════════════════════════════════════════════════
// THE CONTROL EXISTS SO A RULE HAS SOMETHING TO REFUSE
// ═══════════════════════════════════════════════════════════════════════
// `inspector_panel.dart`'s own header listed *"§3's Width position
// dropdown"* among the things it deliberately did not build, on a rule
// worth keeping: *"rendering a plausible-looking device form with no
// working fields would be worse than rendering the honest summary."*
// `PLC-002` is what changed. The rule guarding `startTwelfth`/
// `spanTwelfths` had a predicate, an AC-051 pair and no writer anywhere
// in the product, so tier 1's *"the command is rejected"* had no command.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ASSERTION THAT IS NOT ABOUT CLICKING
// ═══════════════════════════════════════════════════════════════════════
// A device can sit at a position CR-030's three cannot name: a file from
// a v1.2 build with free lateral dragging, or one edited by hand, may
// hold `(3, 6)`. The dropdown must say so rather than displaying `Full`,
// which would misreport the drawing, and rather than saying `Mixed`,
// which would be a lie about a single device. That case has no gesture
// and is the one most likely to be got wrong.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9);
const _rackId = Uuid('r1');
const _a = Uuid('d-a');
const _b = Uuid('d-b');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

RackDocument _doc(Map<Uuid, Placement> devices) {
  final doc = RackDocument(
    id: const Uuid('doc-width-ui'),
    appVersion: '0.5.20',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  doc.templates['amp@1'] = TemplateSnapshot(
    templateId: const TemplateId('amp'),
    version: 1,
    contentHash: 'unhashed:amp@1',
    body: TemplateBody(
      manufacturer: 'Test',
      model: 'amp',
      displayName: 'Amp',
      frontU: 1,
      side: OccupancySide.front,
    ),
    capturedAt: _now,
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    designator: 'RK-1',
    name: 'Rack 1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  var i = 0;
  for (final entry in devices.entries) {
    doc.devices[entry.key] = DeviceInstance(
      id: entry.key,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('amp'),
        version: 1,
        contentHash: 'unhashed:amp@1',
      ),
      designator: 'AMP-${++i}',
      name: 'Amplifier',
      placement: entry.value,
      meta: _meta(),
    );
  }
  return doc;
}

RailPlacement _rail({int start = 0, int span = 12, int ru = 3}) =>
    RailPlacement(
      rackId: _rackId,
      ruIndex: ru,
      face: Face.front,
      startTwelfth: start,
      spanTwelfths: span,
    );

Future<List<WidthPosition>> _pump(
  WidgetTester tester,
  RackDocument doc,
  Set<Uuid> selected,
) async {
  final picked = <WidthPosition>[];
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: SizedBox()),
            SizedBox(
              width: 320,
              child: InspectorPanel(
                target: InspectorTarget.selection,
                rack: doc.racks[_rackId]!,
                doc: doc,
                presets: const {},
                selectedIds: selected,
                focusedId: selected.isEmpty ? null : selected.first,
                onZeroU: (_) {},
                onMoveZeroU: (_, _, _) {},
                onSetProperty: <T>(field, value) {},
                onRename: (_) {},
                onRequestHeight: (_) {},
                onApplyPreset: (_) {},
                onRefuse: (_) {},
                onSetLifecycle: (_) {},
                onSetWidth: picked.add,
                onSetOverride: <T>(field, value) {},
                onSetPortFact: (a, b, c, d, e) {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('a rail-placed device gets the control, reading the position '
      'it is actually at', (tester) async {
    await _pump(tester, _doc({_a: _rail(start: 6, span: 6)}), {_a});
    expect(find.text('Width position'), findsOneWidget);
    expect(find.text('Right half'), findsOneWidget);
  });

  testWidgets('an off-rack device does not get it at all, because it has '
      'no lateral position to name', (tester) async {
    await _pump(tester, _doc({_a: const OffRackPlacement()}), {_a});
    expect(find.text('Width position'), findsNothing);
  });

  testWidgets('picking one reports it, and reports the value picked '
      'rather than the one that was showing', (tester) async {
    final picked = await _pump(tester, _doc({_a: _rail()}), {_a});
    await tester.tap(find.text('Full'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Left half').last);
    await tester.pumpAndSettle();
    expect(picked, [WidthPosition.leftHalf]);
  });

  testWidgets('A POSITION THE DROPDOWN CANNOT NAME reads as the twelfths '
      'it occupies, never as Full and never as Mixed', (tester) async {
    // `(3, 6)` is legal in the format and unreachable from this control.
    // CR-030 keeps twelfths in the file precisely so a later build can
    // write one; showing `Full` here would misreport the drawing.
    await _pump(tester, _doc({_a: _rail(start: 3, span: 6)}), {_a});
    expect(find.text('Width position'), findsOneWidget);
    expect(find.text('6/12 from twelfth 3'), findsOneWidget);
    expect(find.text('Full'), findsNothing);
    expect(find.text('Mixed'), findsNothing);
  });

  testWidgets('two devices that disagree read Mixed, and one that agrees '
      'reads its shared value', (tester) async {
    final doc = _doc({_a: _rail(), _b: _rail(span: 6)});
    await _pump(tester, doc, {_a, _b});
    expect(find.text('Width position (2 devices)'), findsOneWidget);
    expect(find.text('Mixed'), findsOneWidget);

    final agreeing = _doc({_a: _rail(span: 6), _b: _rail(span: 6)});
    await _pump(tester, agreeing, {_a, _b});
    expect(find.text('Left half'), findsOneWidget);
    expect(find.text('Mixed'), findsNothing);
  });

  testWidgets('a shelf-hosted device in the selection is skipped rather '
      'than counted, so the header names what the control will move', (
    tester,
  ) async {
    final doc = _doc({
      _a: _rail(),
      _b: const ShelfPlacement(
        hostDeviceId: Uuid('d-a'),
        order: FracIndex('a0'),
      ),
    });
    await _pump(tester, doc, {_a, _b});
    expect(find.text('Width position'), findsOneWidget);
    expect(find.text('Width position (2 devices)'), findsNothing);
  });
}
