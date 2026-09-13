// DR-013 §11.13.2 — the confirmation that names the count, on the screen.
//
// The CORE half is `rackpal_core/test/device_removal_test.dart`: the
// cascade, the plan, and the byte-identical undo. This file is the half
// only a mounted screen can get wrong:
//
//   * a device carrying NOTHING is deleted with no prompt at all;
//   * a device carrying cables prompts, and the prompt states the COUNT;
//   * Cancel writes nothing — not the device, not the cables;
//   * Delete removes both, as ONE undo entry;
//   * and the number on the dialog is the number that goes.

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

final _when = DateTime.utc(2026, 8, 2);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _wired = Uuid('dev-wired');
const _far = Uuid('dev-far');
const _bare = Uuid('dev-bare');
const _rack = Uuid('rack-1');

TemplateBody _body(String model) => TemplateBody(
  manufacturer: 'Demo',
  model: model,
  displayName: model,
  // Rail-mounted and 1U, so the canvas draws a hit-testable box for it.
  frontU: 1,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  banks: [
    BankDef(key: 'io', label: 'IO', abbr: 'IO', order: const FracIndex('a0')),
  ],
  ports: [
    for (var i = 1; i <= 6; i++)
      PortDef(
        key: PortKey('p.$i'),
        label: 'P$i',
        connector: const ConnectorTypeId('conn.xlr3'),
        signalFamily: const SignalFamilyId('audio.analog.balanced'),
        face: Face.rear,
        position: _pos,
        order: FracIndex('a${i.toString().padLeft(3, '0')}'),
        bankKey: 'io',
      ),
  ],
);

void _place(RackDocument doc, Uuid id, String designator, int ru) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    capturedAt: _when,
    body: _body(designator),
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
    ),
    designator: designator,
    name: designator,
    placement: RailPlacement(rackId: _rack, ruIndex: ru, face: Face.front),
    meta: _meta(),
  );
}

/// A rack with one wired device, its far end, and one idle device.
RackDocument _document({int cables = 3}) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: 'DR-013'),
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
  _place(doc, _wired, 'WIR-1', 1);
  _place(doc, _far, 'FAR-1', 4);
  _place(doc, _bare, 'BAR-1', 7);

  final controller = DocumentController(doc, clock: FixedClock(_when));
  for (var i = 1; i <= cables; i++) {
    final from = resolveConnectTarget(doc, deviceId: _wired, portKey: 'p.$i')!;
    final to = resolveConnectTarget(doc, deviceId: _far, portKey: 'p.$i')!;
    final built = buildConnectPortsCommand(
      doc: doc,
      from: from,
      to: to,
      media: const MediaTypeId('media.cat6'),
      now: _when,
      actor: 'test',
    );
    controller.run((built as ConnectPortsReady).command);
  }
  return doc;
}

void main() {
  group('the dialog itself — §11.13.2', () {
    testWidgets('states the COUNT, not a bare "are you sure?"', (
      tester,
    ) async {
      final doc = _document();
      final plan = planDeviceRemoval(doc, _wired);

      await tester.pumpWidget(
        MaterialApp(
          home: DeleteDeviceDialog(
            plans: [plan],
            designators: const {_wired: 'WIR-1'},
            totalDevices: 1,
          ),
        ),
      );

      expect(find.textContaining('WIR-1'), findsWidgets);
      expect(
        find.text('This also deletes 3 cables.'),
        findsOneWidget,
        reason:
            'the count is the whole point of the dialog — a delete '
            'that silently drops rows off the schedule is the failure G1 '
            'makes most expensive',
      );
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('says "1 cable" rather than "1 cables"', (tester) async {
      final doc = _document(cables: 1);
      await tester.pumpWidget(
        MaterialApp(
          home: DeleteDeviceDialog(
            plans: [planDeviceRemoval(doc, _wired)],
            designators: const {_wired: 'WIR-1'},
            totalDevices: 1,
          ),
        ),
      );
      expect(find.text('This also deletes 1 cable.'), findsOneWidget);
    });

    // `#873` — DR-013 §11.13.2 in the other direction.
    //
    // A cable between TWO selected devices is in BOTH their plans, because
    // `planDeviceRemoval` asks "which links land on this device" and the
    // answer is yes at each end. The transaction removes it once. A sum
    // over the plans therefore states a number the edit does not deliver,
    // which is the promise the ruling exists to keep: "a dialog that said
    // 4 cables and removed 5 would be worse than no dialog". Saying 6 and
    // removing 3 is the same broken promise wearing a friendlier face.
    testWidgets('counts a cable BETWEEN two selected devices ONCE', (
      tester,
    ) async {
      final doc = _document();
      final wired = planDeviceRemoval(doc, _wired);
      final far = planDeviceRemoval(doc, _far);

      // The fixture's three cables run WIR-1 to FAR-1, so each plan sees
      // all three and the union is still three.
      expect(wired.cableCount, 3);
      expect(far.cableCount, 3);

      await tester.pumpWidget(
        MaterialApp(
          home: DeleteDeviceDialog(
            plans: [wired, far],
            designators: const {_wired: 'WIR-1', _far: 'FAR-1'},
            totalDevices: 2,
          ),
        ),
      );

      expect(
        find.text('This also deletes 3 cables.'),
        findsOneWidget,
        reason:
            'three cables exist and three go; six is a number no '
            'gesture produces',
      );
    });

    testWidgets('and it says undo puts them back, because it does', (
      tester,
    ) async {
      final doc = _document();
      await tester.pumpWidget(
        MaterialApp(
          home: DeleteDeviceDialog(
            plans: [planDeviceRemoval(doc, _wired)],
            designators: const {_wired: 'WIR-1'},
            totalDevices: 1,
          ),
        ),
      );
      expect(find.textContaining('Undo puts them back'), findsOneWidget);
    });
  });

  group('confirmDeviceRemoval — when it asks and when it does not', () {
    testWidgets('a device carrying NOTHING shows no dialog and returns true', (
      tester,
    ) async {
      // §11.13.2's last sentence, and the reason it matters: a prompt for
      // a consequence-free delete is the nag that teaches people to click
      // through prompts, including this one on the day it counts.
      final doc = _document();
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                answer = await confirmDeviceRemoval(
                  context,
                  plans: [planDeviceRemoval(doc, _bare)],
                  designators: const {_bare: 'BAR-1'},
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(DeleteDeviceDialog), findsNothing);
      expect(answer, isTrue);
    });

    testWidgets('a wired device DOES ask, and Cancel answers false', (
      tester,
    ) async {
      final doc = _document();
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                answer = await confirmDeviceRemoval(
                  context,
                  plans: [planDeviceRemoval(doc, _wired)],
                  designators: const {_wired: 'WIR-1'},
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteDeviceDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });

    testWidgets('Esc is Cancel, and the key comes from kKeymap', (
      tester,
    ) async {
      final doc = _document();
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                answer = await confirmDeviceRemoval(
                  context,
                  plans: [planDeviceRemoval(doc, _wired)],
                  designators: const {_wired: 'WIR-1'},
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(answer, isFalse, reason: 'Esc is Cancel, everywhere, always');
    });
  });

  group('the whole gesture, on the canvas', () {
    Future<void> pump(WidgetTester tester, RackDocument doc) async {
      await tester.pumpWidget(
        MaterialApp(
          // DR-159 §11.158.3: undo and redo are GLOBAL bindings, so a
          // screen pumped without the root's map is a configuration
          // the product does not ship. See test/app_like.dart.
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

    Future<void> selectAndDelete(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)).first);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
    }

    testWidgets('deleting an UNWIRED device is as immediate as it ever was', (
      tester,
    ) async {
      final doc = _document();
      await pump(tester, doc);
      await selectAndDelete(tester, _bare.v);

      expect(find.byType(DeleteDeviceDialog), findsNothing);
      expect(doc.devices.containsKey(_bare), isFalse);
    });

    testWidgets('deleting a WIRED device asks first and writes nothing until '
        'it is answered', (tester) async {
      final doc = _document();
      final linksBefore = doc.links.length;
      await pump(tester, doc);
      await selectAndDelete(tester, _wired.v);

      expect(find.byType(DeleteDeviceDialog), findsOneWidget);
      expect(
        doc.devices.containsKey(_wired),
        isTrue,
        reason: 'nothing is written while the question is open',
      );
      expect(doc.links, hasLength(linksBefore));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(doc.devices.containsKey(_wired), isTrue);
      expect(doc.links, hasLength(linksBefore));
    });

    testWidgets('confirming removes the device AND its cables, and the '
        'number that goes is the number the dialog said', (tester) async {
      final doc = _document();
      final linksBefore = doc.links.length;
      await pump(tester, doc);
      await selectAndDelete(tester, _wired.v);

      expect(find.text('This also deletes 3 cables.'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(doc.devices.containsKey(_wired), isFalse);
      expect(
        linksBefore - doc.links.length,
        3,
        reason:
            'ONE NUMBER, ONE SOURCE — the dialog and the command both '
            'read planDeviceRemoval',
      );
      // And the far end survives, with its own ports.
      expect(doc.devices.containsKey(_far), isTrue);
    });

    // `#873`, end to end and through the real mounting. The number in
    // the sentence has to be the number the transaction delivers, which
    // is the whole of what §11.13.2 promises; a widget test on the dialog
    // alone cannot see whether the delete agrees with it.
    testWidgets('selecting BOTH ends of a run states 3 and removes 3', (
      tester,
    ) async {
      final doc = _document();
      final linksBefore = doc.links.length;
      await pump(tester, doc);

      await tester.tap(find.byKey(ValueKey(_wired.v)).first);
      await tester.pumpAndSettle();
      // Ctrl+click ADDS, which is `_dragModifierToggle`'s whole job. The
      // modifier is read at beginDrag, so it must be down before the tap.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byKey(ValueKey(_far.v)).first);
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(find.byType(DeleteDeviceDialog), findsOneWidget);
      expect(find.text('Delete 2 devices?'), findsOneWidget);
      expect(find.text('This also deletes 3 cables.'), findsOneWidget);
      expect(
        find.textContaining('run between devices in this list'),
        findsOneWidget,
        reason:
            'the per-device breakdown says 3 and 3, so the headline '
            'saying 3 needs its one missing sentence',
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        linksBefore - doc.links.length,
        3,
        reason:
            'the stated count IS the count removed, which is the only '
            'thing the dialog promises',
      );
      expect(doc.devices.containsKey(_wired), isFalse);
      expect(doc.devices.containsKey(_far), isFalse);
    });

    testWidgets('and Ctrl+Z puts the device and every cable back', (
      tester,
    ) async {
      final doc = _document();
      final linksBefore = doc.links.keys.toSet();
      await pump(tester, doc);
      await selectAndDelete(tester, _wired.v);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(doc.devices.containsKey(_wired), isTrue);
      expect(
        doc.links.keys.toSet(),
        linksBefore,
        reason: '§11.13.4 — the SAME ids, not equivalent objects',
      );
    });
  });
}
