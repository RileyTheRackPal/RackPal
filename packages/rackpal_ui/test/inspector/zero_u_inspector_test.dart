// AC-044's inspector half, built at `#876` (DR-163 §11.162).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SURFACE VALIDATES NOTHING, SO THESE CASES ASSERT THE HANDOVER
// ═══════════════════════════════════════════════════════════════════════
// §11.162.3: `planAddZeroUChannel` already refuses a duplicate id, an
// inverted span and a span that does not fit; `planRemoveZeroUChannel`
// refuses while occupied and names the occupant; `planSetZeroUPosition`
// re-runs `evaluatePlacement` and returns `PLC-003`'s own sentence. A
// second copy of any of that in a widget is how a dialog and an edit come
// to disagree.
//
// So what these prove about the panel is that it asks the right question
// and hands over the right values. `zero_u_commands_test.dart` proves the
// planners, and `rack_canvas_screen`'s own cases prove the dispatch.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _when = DateTime.utc(2026, 9, 13);
const _rackId = Uuid('rk-1');
const _pduId = Uuid('dev-pdu');

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// A 42 U rack, optionally with channels and a PDU in the first one.
RackDocument _doc({
  List<ZeroUChannel> channels = const [],
  bool withPdu = false,
  int pduStartU = 3,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-876'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Head end',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.racks[_rackId]!.zeroUChannels.addAll(channels);
  if (withPdu && channels.isNotEmpty) {
    doc.devices[_pduId] = DeviceInstance(
      id: _pduId,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('tpl.pdu'),
        version: 1,
        contentHash: 'sha256:pdu',
      ),
      designator: 'PDU-1',
      name: 'Vertical PDU',
      placement: ZeroUPlacement(
        rackId: _rackId,
        channelId: channels.first.id,
        offsetFromChannelStart: zeroUOffsetFor(channels.first, pduStartU),
        orientation: ZeroUOrientation.vertical,
      ),
      meta: _meta(),
    );
  }
  return doc;
}

ZeroUChannel _channel({
  String id = 'ch-1',
  ZeroUChannelSide side = ZeroUChannelSide.rearLeft,
  int startU = 1,
  int endU = 42,
  String name = '',
}) => ZeroUChannel(
  id: id,
  side: side,
  startU: startU,
  endU: endU,
  name: name,
);

void main() {
  group('the rack panel adds and removes a channel (§11.162.1)', () {
    /// Pumps just the rack inspector, recording what it hands over.
    Future<List<ZeroUResult>> pumpRack(
      WidgetTester tester,
      RackDocument doc,
    ) async {
      final handed = <ZeroUResult>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 900,
              child: RackInspectorPanel(
                rack: doc.racks[_rackId]!,
                doc: doc,
                presets: const {},
                onSetProperty: <T>(_, _) {},
                onRename: (_) {},
                onRequestHeight: (_) {},
                onApplyPreset: (_) {},
                onRefuse: (_) {},
                onZeroU: handed.add,
                onMoveZeroU: (_, _, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return handed;
    }

    Future<void> reveal(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(
        f,
        120,
        scrollable: find
            .descendant(
              of: find.byType(RackInspectorPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a rack with none says so, and still offers the button', (
      tester,
    ) async {
      final handed = await pumpRack(tester, _doc());
      await reveal(tester, find.text(kNoZeroUChannels));

      expect(find.text(kNoZeroUChannels), findsOneWidget);
      expect(find.text(kAddZeroUChannelLabel), findsOneWidget);
      expect(handed, isEmpty);
    });

    testWidgets('a channel reads as its side and span, named when it has '
        'a name', (tester) async {
      await pumpRack(
        tester,
        _doc(
          channels: [
            _channel(endU: 12),
            _channel(id: 'ch-2', side: ZeroUChannelSide.frontRight, name: 'A'),
          ],
        ),
      );
      await reveal(tester, find.text(kAddZeroUChannelLabel));

      expect(find.text('Rear left'), findsOneWidget);
      expect(find.text('Rear left · U 1 to 12'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Front right · U 1 to 42'), findsOneWidget);
    });

    testWidgets('AN OCCUPIED CHANNEL SAYS WHO IS IN IT', (tester) async {
      // Not decoration: `planRemoveZeroUChannel` refuses while occupied
      // and names the device, so a row offering Remove with no hint of
      // that would be a control failing for a reason the panel could see.
      await pumpRack(
        tester,
        _doc(channels: [_channel()], withPdu: true),
      );
      await reveal(tester, find.text(kAddZeroUChannelLabel));

      expect(find.text('Rear left · U 1 to 42 · PDU-1'), findsOneWidget);
    });

    testWidgets("remove hands over the PLANNER's answer, refusal and all", (
      tester,
    ) async {
      final doc = _doc(channels: [_channel()], withPdu: true);
      final handed = await pumpRack(tester, doc);
      await reveal(tester, find.byKey(ValueKey(zeroURemoveKeyFor('ch-1'))));
      await tester.tap(find.byKey(ValueKey(zeroURemoveKeyFor('ch-1'))));
      await tester.pumpAndSettle();

      expect(handed, hasLength(1));
      final result = handed.single;
      expect(result, isA<ZeroURefused>());
      expect(
        (result as ZeroURefused).reason,
        contains('PDU-1'),
        reason:
            'the sentence is the planner and names the occupant. The '
            'panel does not re-decide it',
      );
      expect(doc.racks[_rackId]!.zeroUChannels, hasLength(1));
    });

    testWidgets('and a clear one hands over a READY command', (tester) async {
      final doc = _doc(channels: [_channel()]);
      final handed = await pumpRack(tester, doc);
      await reveal(tester, find.byKey(ValueKey(zeroURemoveKeyFor('ch-1'))));
      await tester.tap(find.byKey(ValueKey(zeroURemoveKeyFor('ch-1'))));
      await tester.pumpAndSettle();

      expect(handed.single, isA<ZeroUReady>());
      expect(
        doc.racks[_rackId]!.zeroUChannels,
        hasLength(1),
        reason: 'the PANEL does not run it, which is the seam',
      );
    });

    testWidgets('the Add button opens the form and its answer is planned', (
      tester,
    ) async {
      final doc = _doc();
      final handed = await pumpRack(tester, doc);
      await reveal(tester, find.text(kAddZeroUChannelLabel));
      await tester.tap(find.text(kAddZeroUChannelLabel));
      await tester.pumpAndSettle();

      expect(find.text(kAddZeroUChannelTitle), findsOneWidget);
      await tester.enterText(
        find.byKey(AddZeroUChannelDialog.startKey),
        '3',
      );
      await tester.enterText(find.byKey(AddZeroUChannelDialog.endKey), '20');
      await tester.tap(find.byKey(AddZeroUChannelDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(handed, hasLength(1));
      final ready = handed.single;
      expect(ready, isA<ZeroUReady>());
      (ready as ZeroUReady).command.apply(doc);
      final channel = doc.racks[_rackId]!.zeroUChannels.single;
      expect(channel.startU, 3);
      expect(channel.endU, 20);
      expect(channel.side, ZeroUChannelSide.rearLeft);
    });

    testWidgets('THE FORM DEFAULTS TO THE WHOLE RACK, 1-BASED (CR-025)', (
      tester,
    ) async {
      // The default is the one the remedy mints and the one a vertical
      // rail usually is. It is 1-based because CR-025 says so, and the
      // only producer in the product wrote U 0 until `c95224d`.
      final doc = _doc();
      final handed = await pumpRack(tester, doc);
      await reveal(tester, find.text(kAddZeroUChannelLabel));
      await tester.tap(find.text(kAddZeroUChannelLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AddZeroUChannelDialog.confirmKey));
      await tester.pumpAndSettle();

      (handed.single as ZeroUReady).command.apply(doc);
      final channel = doc.racks[_rackId]!.zeroUChannels.single;
      expect(channel.startU, 1);
      expect(channel.endU, 42);
    });

    testWidgets('Cancel hands over nothing at all', (tester) async {
      final handed = await pumpRack(tester, _doc());
      await reveal(tester, find.text(kAddZeroUChannelLabel));
      await tester.tap(find.text(kAddZeroUChannelLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(handed, isEmpty);
    });
  });

  group('the occupant row, under its channel (§11.162.1)', () {
    // IT WAS ON THE DEVICE PANEL AND COULD NOT BE REACHED THERE.
    // `scene_builder.dart` drops every placement that is not a
    // `RailPlacement`, so a 0U occupant is never drawn and never
    // selectable; a section on the device inspector would have been a
    // surface nothing could open.
    Future<List<(Uuid, String, int)>> pumpRow(
      WidgetTester tester,
      RackDocument doc,
    ) async {
      final moves = <(Uuid, String, int)>[];
      final rack = doc.racks[_rackId]!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 600,
              child: ZeroUOccupantRow(
                device: doc.devices[_pduId]!,
                channel: rack.zeroUChannels.first,
                channels: rack.zeroUChannels,
                onMove: (d, c, u) => moves.add((d, c, u)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return moves;
    }

    testWidgets('it reads the START U back, not the raw offset', (
      tester,
    ) async {
      final doc = _doc(
        channels: [_channel(startU: 5, endU: 30)],
        withPdu: true,
        pduStartU: 9,
      );
      await pumpRow(tester, doc);

      expect(
        find.widgetWithText(TextField, '9'),
        findsOneWidget,
        reason:
            'the model stores a Len from the channel start; AC-044 asks '
            'the person for a U, and `zeroUStartUOf` is the one place '
            'that conversion knows the span is inclusive',
      );
      expect(find.text('PDU-1'), findsOneWidget);
    });

    testWidgets('typing a U hands over THREE PLAIN VALUES', (tester) async {
      // `#879`'s lesson: the plan is signed, so the row must not invent a
      // clock or an actor. The host plans.
      final doc = _doc(channels: [_channel()], withPdu: true);
      final moves = await pumpRow(tester, doc);

      await tester.enterText(
        find.byKey(ValueKey(zeroUStartKeyFor(_pduId))),
        '11',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(moves, [(_pduId, 'ch-1', 11)]);
      expect(
        (doc.devices[_pduId]!.placement as ZeroUPlacement)
            .offsetFromChannelStart,
        zeroUOffsetFor(_channel(), 3),
        reason: 'the ROW does not write it, which is the seam',
      );
    });

    testWidgets('RETYPING THE SAME U IS NOT AN EDIT', (tester) async {
      // A commit-on-blur field fires whenever focus leaves it, so without
      // the guard every click away would push an undo entry that changed
      // nothing: `#863`'s shape arriving through a text box.
      final doc = _doc(channels: [_channel()], withPdu: true, pduStartU: 7);
      final moves = await pumpRow(tester, doc);

      await tester.enterText(
        find.byKey(ValueKey(zeroUStartKeyFor(_pduId))),
        '7',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(moves, isEmpty);
    });

    testWidgets('the picker is absent when there is only one channel', (
      tester,
    ) async {
      await pumpRow(tester, _doc(channels: [_channel()], withPdu: true));

      expect(find.byKey(ValueKey(zeroUChannelKeyFor(_pduId))), findsNothing);
    });

    testWidgets('and CHOOSING ANOTHER CHANNEL KEEPS THE U, not the offset', (
      tester,
    ) async {
      // Two channels that start at different Us. Carrying the raw `Len`
      // across would move the device while the person was choosing which
      // rail it hangs on.
      final doc = _doc(
        channels: [
          _channel(endU: 20),
          _channel(id: 'ch-2', startU: 10, name: 'Upper'),
        ],
        withPdu: true,
        pduStartU: 12,
      );
      final moves = await pumpRow(tester, doc);

      await tester.tap(find.byKey(ValueKey(zeroUChannelKeyFor(_pduId))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upper').last);
      await tester.pumpAndSettle();

      expect(moves, [(_pduId, 'ch-2', 12)]);
    });
  });
}
