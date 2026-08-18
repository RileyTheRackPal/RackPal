// `#719`, DR-073: dragging a half-landed home run's pennant onto a free
// jack LANDS the run, and does not make a second cable beside it.
//
// THE DISTINCTION THIS FILE EXISTS FOR. `ConnectPortsCommand` CREATES a
// cable. A run pulled at framing stage already exists: it has a `W`
// number, a length, a jacket and possibly a test result, and what it
// lacks is a pin at one end. A connect run against it makes a SECOND
// cable beside the one the user is trying to finish, which is exactly the
// complaint `#713` was filed for:
//
//   > "if a user were to just directly connect a speaker to an amplifier
//   > in the schematic view it would create two wires on the project"
//
// So the load-bearing assertions here are the NEGATIVE ones: the link
// count does not move, and the run's own id is the one that gained a pin.
//
// THE GESTURE IS DRIVEN, NEVER THE HANDLER. `#704` shipped green in this
// package against tests that asserted a field the listener under test had
// just written, and broke both canvases in the user's hands. Every case
// below presses, moves and releases.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late SchematicScene reference;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 8, 18, 9)),
    );
    reference = buildFixtureScene(doc);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchematicCanvasScreen(
            measurer: const FakeMeasurer(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Matrix4 matrixOf(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .debugSceneToScreen!;

  Offset toScreen(WidgetTester tester, DPt p) {
    final m = matrixOf(tester).storage;
    return tester.getTopLeft(find.byType(SchematicCanvasBody)) +
        Offset(
          m[0] * p.x + m[4] * p.y + m[12],
          m[1] * p.x + m[5] * p.y + m[13],
        );
  }

  RenderedSymbol symbolOf(String designator) {
    final device = deviceNamed(doc, designator);
    return reference.symbols.firstWhere((s) => s.id == device.id.v);
  }

  /// A free jack on [designator], by index among the free ones.
  ({PinRef ref, DPt centre}) freePin(String designator, {int index = 0}) {
    final device = deviceNamed(doc, designator);
    final symbol = symbolOf(designator);
    final free = <({PinRef ref, DPt centre})>[];
    for (final port in symbol.allPorts) {
      final id = derivePortId(device.id, PortKey(port.key));
      if (portConductorCount(doc, id) != 0) continue;
      free.add((
        ref: PinRef(deviceId: symbol.id, portKey: port.key),
        centre: symbolPortCentre(symbol, port),
      ));
    }
    return free[index];
  }

  /// Turns one of the fixture's cables into a HALF-LANDED HOME RUN: a
  /// `StructureOrigin`, one end still on its pin, the other out at a wall
  /// plate. This is what a drop looks like between the pull and the trim.
  Uuid makeHalfLandedRun() {
    final link = doc.links.values.firstWhere(
      (l) => l.conductors.isNotEmpty && l.conductors.first.to is PortEndpoint,
    );
    link
      ..structureOrigin = StructureOrigin(
        structureBodyId: const Uuid('body-1'),
        outletId: const Uuid('outlet-1'),
        fieldLabel: 'LR-TV-1',
      )
      ..conductors[0] = Conductor(
        from: link.conductors.first.from,
        to: const PlaceEndpoint(description: 'Living Room TV wall'),
      );
    reference = buildFixtureScene(doc);
    return link.id;
  }

  /// The pennant drawn for [linkId]. A half-landed run has exactly ONE.
  DPt pennantOf(Uuid linkId) {
    final labels = reference.netLabels
        .where((l) => l.linkId == linkId)
        .toList();
    expect(
      labels,
      hasLength(1),
      reason:
          'a half-landed run draws the stub for the end it HAS, and that '
          'single flag is what this gesture grabs',
    );
    final box = labels.single.pennant;
    return DPt((box.left + box.right) / 2, (box.top + box.bottom) / 2);
  }

  Future<void> dragFromTo(WidgetTester tester, DPt from, DPt to) async {
    final drag = await tester.startGesture(
      toScreen(tester, from),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveTo(toScreen(tester, to));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
  }

  testWidgets('dragging a run onto a free jack LANDS it and makes NO second '
      'cable', (tester) async {
    final runId = makeHalfLandedRun();
    await pump(tester);
    final before = doc.links.length;
    final target = freePin('MTX-1');

    await dragFromTo(tester, pennantOf(runId), target.centre);

    expect(
      doc.links.length,
      before,
      reason:
          'the run existed already; a connect here would have put a second '
          'cable on the sheet beside the one being finished, which is the '
          'whole of `#713`',
    );
    final landed = doc.links[runId]!.conductors.first.to;
    expect(landed, isA<PortEndpoint>());
    expect(
      (landed as PortEndpoint).portId,
      derivePortId(Uuid(target.ref.deviceId), PortKey(target.ref.portKey)),
      reason: 'and it landed on the jack the pointer was released over',
    );
  });

  testWidgets('the run keeps everything AC-018 says a bind preserves', (
    tester,
  ) async {
    final runId = makeHalfLandedRun();
    final was = doc.links[runId]!;
    final designator = was.designator;
    final fieldLabel = was.structureOrigin!.fieldLabel;
    await pump(tester);

    await dragFromTo(tester, pennantOf(runId), freePin('MTX-1').centre);

    final now = doc.links[runId]!;
    expect(now.designator, designator, reason: 'the W number is the cable');
    expect(now.structureOrigin!.fieldLabel, fieldLabel);
  });

  testWidgets('one undo takes the landing back, and the run survives it', (
    tester,
  ) async {
    final runId = makeHalfLandedRun();
    await pump(tester);
    await dragFromTo(tester, pennantOf(runId), freePin('MTX-1').centre);
    expect(doc.links[runId]!.conductors.first.to, isA<PortEndpoint>());

    controller.undoLast();
    await tester.pumpAndSettle();

    expect(
      doc.links[runId],
      isNotNull,
      reason:
          'undoing a LANDING must not delete the cable: the run was pulled '
          'weeks before anybody touched this sheet',
    );
    expect(doc.links[runId]!.conductors.first.to, isNot(isA<PortEndpoint>()));
  });

  testWidgets('a press on a PIN is still a cable, not a landing', (
    tester,
  ) async {
    // The precedence rule. A pennant sits beside its pin and the two hit
    // boxes touch; landing a run is the rarer act and must never steal
    // the commoner one.
    makeHalfLandedRun();
    await pump(tester);
    final before = doc.links.length;

    await dragFromTo(tester, freePin('MTX-1').centre, freePin('AMP-1').centre);

    expect(
      doc.links.length,
      before + 1,
      reason: 'pin to pin is a connect and still creates a cable',
    );
  });

  testWidgets(
    'a patch cable pennant arms nothing, so the press stays a click',
    (tester) async {
      // `buildBindEndpointCommand` refuses anything with no
      // `StructureOrigin`. Arming on one would be a gesture whose every
      // commit is refused, which is `#711`'s defect drawn on purpose.
      await pump(tester);
      final before = doc.links.length;
      final patch = reference.netLabels.first;
      expect(doc.links[patch.linkId]!.structureOrigin, isNull);
      final box = patch.pennant;
      final centre = DPt(
        (box.left + box.right) / 2,
        (box.top + box.bottom) / 2,
      );

      await dragFromTo(tester, centre, freePin('MTX-1').centre);

      expect(doc.links.length, before, reason: 'nothing was created');
    },
  );

  testWidgets('Esc abandons a landing with no model change', (tester) async {
    final runId = makeHalfLandedRun();
    await pump(tester);
    final target = freePin('MTX-1');

    final drag = await tester.startGesture(
      toScreen(tester, pennantOf(runId)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveTo(toScreen(tester, target.centre));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await drag.up();
    await tester.pumpAndSettle();

    expect(
      doc.links[runId]!.conductors.first.to,
      isNot(isA<PortEndpoint>()),
      reason:
          'docs/05 section 7: a cancel makes no model mutation and no undo '
          'entry, and a landing is no different',
    );
  });
}
