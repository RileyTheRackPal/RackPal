// The Staging Bin and shelf hosts on the real rack canvas (DR-204, DR-205,
// `#953`, `#961`).
//
// Pumped through `RackCanvasScreen` rather than the strip alone, because
// the bin is a projection of the document and its host is this screen: a
// strip that works in isolation and is never mounted is the defect this
// repository keeps recording.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../app_like.dart';

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

final _when = DateTime.utc(2026, 9, 30);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _rack = Uuid('rack-1');
const _amp = Uuid('dev-amp');
const _shelf = Uuid('dev-shelf');
const _box = Uuid('dev-box');

void _template(RackDocument doc, String id, TemplateBody body) =>
    doc.templates['$id@1'] = TemplateSnapshot(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'sha256:$id',
      capturedAt: _when,
      body: body,
    );

void _device(
  RackDocument doc,
  Uuid id,
  String template,
  String designator,
  Placement placement,
) => doc.devices[id] = DeviceInstance(
  id: id,
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(template),
    version: 1,
    contentHash: 'sha256:$template',
  ),
  designator: designator,
  name: designator,
  placement: placement,
  meta: _meta(),
);

RackDocument _document() {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: 'DR-205'),
    registries: buildSeedRegistries(),
  );
  doc.racks[_rack] = Rack(
    id: _rack,
    name: 'HEAD END',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  _template(
    doc,
    'tpl.amp',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'AMP',
      displayName: 'Amplifier',
      frontU: 2,
      side: OccupancySide.front,
    ),
  );
  _template(
    doc,
    'tpl.shelf',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'SHELF',
      displayName: '2U shelf',
      frontU: 2,
      side: OccupancySide.front,
      isContainer: true,
    ),
  );
  _template(
    doc,
    'tpl.box',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'BOX',
      displayName: 'Cable box',
      mountMethod: MountMethod.shelf,
      shelfWidth: const Len(200_000_000),
    ),
  );
  _device(
    doc,
    _amp,
    'tpl.amp',
    'AMP-1',
    const RailPlacement(rackId: _rack, ruIndex: 9, face: Face.front),
  );
  _device(
    doc,
    _shelf,
    'tpl.shelf',
    'SHF-1',
    const RailPlacement(rackId: _rack, ruIndex: 4, face: Face.front),
  );
  _device(
    doc,
    _box,
    'tpl.box',
    'STB-1',
    const ShelfPlacement(hostDeviceId: _shelf, order: FracIndex('a0')),
  );
  return doc;
}

Future<void> _pump(WidgetTester tester, RackDocument doc) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      shortcuts: appGlobalShortcuts(),
      home: Scaffold(
        body: RackCanvasScreen(
          measurer: _FakeMeasurer(),
          document: doc,
          clock: FixedClock(_when),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A DEVICE ON A SHELF IS ON THE CANVAS, and a click selects it '
      'rather than the shelf under it (DR-204)', (tester) async {
    final doc = _document();
    await _pump(tester, doc);

    final box = find.byKey(ValueKey(_box.v));
    expect(box, findsOneWidget, reason: 'the host has a device box');
    await tester.tap(box);
    await tester.pumpAndSettle();
    // `U` acts on the selection, so it is the observable of what the
    // click selected: the host goes to the bin, the shelf stays.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.pumpAndSettle();
    expect(doc.devices[_box]!.placement, isA<StagedPlacement>());
    expect(doc.devices[_shelf]!.placement, isA<RailPlacement>());
  });

  group('the Staging Bin (DR-205)', () {
    testWidgets('is not drawn while empty', (tester) async {
      await _pump(tester, _document());
      expect(find.byType(StagingBinStrip), findsNothing);
    });

    testWidgets('U SENDS THE SELECTION THERE, off the rack and into the '
        'strip, and the return chip puts it back', (tester) async {
      final doc = _document();
      await _pump(tester, doc);

      await tester.tap(find.byKey(ValueKey(_amp.v)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey(_amp.v)),
        findsNothing,
        reason: 'off the rack',
      );
      expect(find.text('Staging Bin (1)'), findsOneWidget);
      expect(find.byKey(ValueKey('staged-${_amp.v}')), findsOneWidget);
      expect(find.textContaining('sent to the Staging Bin'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('return-${_amp.v}')));
      await tester.pumpAndSettle();

      final back = doc.devices[_amp]!.placement as RailPlacement;
      expect((back.rackId, back.ruIndex), (_rack, 9));
      expect(find.byType(StagingBinStrip), findsNothing);
      expect(find.byKey(ValueKey(_amp.v)), findsOneWidget);
    });

    testWidgets('a device taken off a shelf offers the SHELF as its way '
        'back', (tester) async {
      final doc = _document();
      await _pump(tester, doc);

      await tester.tap(find.byKey(ValueKey(_box.v)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.pumpAndSettle();

      expect(find.text('Return to SHF-1'), findsOneWidget);
      await tester.tap(find.text('Return to SHF-1'));
      await tester.pumpAndSettle();
      expect(
        (doc.devices[_box]!.placement as ShelfPlacement).hostDeviceId,
        _shelf,
      );
    });

    testWidgets('A DEVICE DRAGGED OFF THE RACK goes to the bin, not nowhere '
        '(DR-205: "should also keep wiring")', (tester) async {
      final doc = _document();
      await _pump(tester, doc);

      final amp = find.byKey(ValueKey(_amp.v));
      await tester.tap(amp);
      await tester.pumpAndSettle();
      // Grab it and carry it well past the rack's right-hand edge.
      final gesture = await tester.startGesture(tester.getCenter(amp));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();
      }
      expect(find.textContaining('Release to send AMP-1'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(doc.devices[_amp]!.placement, isA<StagedPlacement>());
      expect(
        (doc.devices[_amp]!.placement as StagedPlacement).lastRuIndex,
        9,
        reason: 'it remembers the U it came off, for its return chip',
      );
      expect(find.byKey(ValueKey('staged-${_amp.v}')), findsOneWidget);
    });

    group('A CHIP DRAGGED OUT (#964)', () {
      /// Stages AMP-1 with `U` and answers where its body was, which is
      /// now the free 2U the drags below aim at.
      Future<Offset> stageAmp(WidgetTester tester, RackDocument doc) async {
        final amp = find.byKey(ValueKey(_amp.v));
        final where = tester.getCenter(amp);
        await tester.tap(amp);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
        await tester.pumpAndSettle();
        expect(doc.devices[_amp]!.placement, isA<StagedPlacement>());
        return where;
      }

      Future<void> dragChipTo(WidgetTester tester, Offset to) async {
        final chip = find.byKey(ValueKey('staged-${_amp.v}'));
        final from = tester.getCenter(chip);
        final gesture = await tester.startGesture(from);
        const steps = 12;
        for (var i = 1; i <= steps; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
          await tester.pump();
        }
        await gesture.up();
        await tester.pumpAndSettle();
      }

      testWidgets('onto a free U, it lands there and leaves the bin', (
        tester,
      ) async {
        final doc = _document();
        await _pump(tester, doc);
        final free = await stageAmp(tester, doc);

        await dragChipTo(tester, free);

        final placed = doc.devices[_amp]!.placement;
        expect(placed, isA<RailPlacement>());
        expect(
          ((placed as RailPlacement).rackId, placed.ruIndex),
          (_rack, 9),
          reason: 'aimed at the body AMP-1 left, U9-U10',
        );
        expect(find.byType(StagingBinStrip), findsNothing);
        expect(find.textContaining('wiring kept'), findsOneWidget);
      });

      testWidgets('onto an occupied U, it is refused and stays in the bin', (
        tester,
      ) async {
        final doc = _document();
        await _pump(tester, doc);
        await stageAmp(tester, doc);

        await dragChipTo(
          tester,
          tester.getCenter(find.byKey(ValueKey(_shelf.v))),
        );

        // THE PRECONDITION, so this cannot pass on a drag that never armed:
        // the live evaluation named the occupant and the chip lingers
        // with it (docs/04 §3.1 step 5).
        expect(find.textContaining('Occupied by SHF-1'), findsWidgets);
        expect(doc.devices[_amp]!.placement, isA<StagedPlacement>());
        expect(find.byKey(ValueKey('staged-${_amp.v}')), findsOneWidget);
        await tester.pump(const Duration(seconds: 2)); // the blocked linger
      });

      testWidgets('released off the rack, it stays where it is and says '
          'so, and no "add to the Staging Bin" chip promises otherwise', (
        tester,
      ) async {
        final doc = _document();
        await _pump(tester, doc);
        await stageAmp(tester, doc);
        final chip = tester.getCenter(
          find.byKey(ValueKey('staged-${_amp.v}')),
        );

        final gesture = await tester.startGesture(chip);
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(40, 0));
          await tester.pump();
        }
        expect(find.byKey(StagingBinOverlay.chipKey), findsNothing);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(doc.devices[_amp]!.placement, isA<StagedPlacement>());
        expect(find.text('AMP-1 stays in the Staging Bin.'), findsOneWidget);
      });
    });

    testWidgets('ONE Ctrl+Z takes a U back', (tester) async {
      final doc = _document();
      await _pump(tester, doc);

      await tester.tap(find.byKey(ValueKey(_amp.v)));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(doc.devices[_amp]!.placement, isA<RailPlacement>());
      expect(find.byType(StagingBinStrip), findsNothing);
    });
  });
}
