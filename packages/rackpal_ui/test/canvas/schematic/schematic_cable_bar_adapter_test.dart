// DR-235 §11.234.2 (`#1001`): the cable bar names a declared adapter.
//
// Before this, an adapter could be declared and never named or removed:
// the remedy told the person to "name the part in the inspector", and the
// schematic has no inspector. Every case selects a real cable on the real
// screen, because the defect was a host that did not exist.
//
// THE KEYBOARD CASE IS THE ONE WORTH READING. This is the first text field
// inside the schematic's keymap, where `W` arms a wire and `Delete` and
// `Backspace` remove the selected cable. The screen's guard was written for
// a field that did not exist yet; this is where it is first held to it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late SchematicScene reference;
  late Uuid w001;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 10, 4, 9)),
    );
    reference = buildFixtureScene(doc);
    w001 = doc.links.entries
        .firstWhere((e) => e.value.designator == 'W001')
        .key;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  /// One XLR3-to-RCA adapter on W001, as the remedy would have declared it.
  InlineAdapter declare() {
    final adapter = InlineAdapter(
      fromConnector: const ConnectorTypeId('conn.xlr3'),
      toConnector: const ConnectorTypeId('conn.rca'),
      satisfiesRuleIds: ['CON-001'],
    );
    doc.links[w001]!.inlineAdapters.add(adapter);
    return adapter;
  }

  Future<void> pumpAndSelect(WidgetTester tester) async {
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
    final label = reference.netLabels.firstWhere((l) => l.linkId == w001);
    final m = tester
        .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
        .debugSceneToScreen!
        .storage;
    final x = (label.pennant.left + label.pennant.right) / 2;
    final y = (label.pennant.top + label.pennant.bottom) / 2;
    await tester.tapAt(
      tester.getTopLeft(find.byType(SchematicCanvasBody)) +
          Offset(m[0] * x + m[4] * y + m[12], m[1] * x + m[5] * y + m[13]),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(SchematicCableBar),
      findsOneWidget,
      reason: 'the precondition: W001 is selected and its bar is up',
    );
  }

  Finder modelField(int i) => find.descendant(
    of: find.byKey(cableBarAdapterModelKey(i)),
    matching: find.byType(EditableText),
  );

  testWidgets('a cable with no adapter shows no adapter row', (tester) async {
    await pumpAndSelect(tester);
    expect(find.text(kCableBarAdapterLabel), findsNothing);
  });

  testWidgets('a declared adapter is NAMED BY ITS CONNECTORS, with an empty '
      'model', (tester) async {
    declare();
    await pumpAndSelect(tester);
    expect(find.text(kCableBarAdapterLabel), findsOneWidget);
    expect(find.text('XLR3 to RCA'), findsOneWidget);
    expect(find.text(kCableBarAdapterModelHint), findsOneWidget);
  });

  testWidgets('typing a model and pressing Enter names the part, as ONE undo '
      'step, and the field follows the undo', (tester) async {
    final adapter = declare();
    await pumpAndSelect(tester);
    await tester.enterText(modelField(0), 'Hosa XLR3F-RCA');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(adapter.model, 'Hosa XLR3F-RCA');
    expect(controller.undo.undoLabelKey, LabelKey.setInlineAdapterModel.name);

    controller.undoLast();
    await tester.pumpAndSettle();
    expect(adapter.model, isNull);
    expect(
      tester.widget<EditableText>(modelField(0)).controller.text,
      isEmpty,
      reason: 'a field still showing the undone name would be lying',
    );
  });

  testWidgets('A BLANK MODEL IS NO MODEL (G4)', (tester) async {
    final adapter = declare()..model = 'Hosa XLR3F-RCA';
    await pumpAndSelect(tester);
    await tester.enterText(modelField(0), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(adapter.model, isNull, reason: 'absent, not an empty string');
  });

  testWidgets('TYPING IN THE FIELD DOES NOT DRIVE THE SHEET: a W arms no '
      'wire and Backspace deletes no cable', (tester) async {
    final adapter = declare();
    await pumpAndSelect(tester);
    await tester.tap(modelField(0));
    await tester.pumpAndSettle();
    await tester.enterText(modelField(0), 'W');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(doc.links, contains(w001), reason: 'Delete removes a cable');
    expect(
      find.textContaining('Wire from'),
      findsNothing,
      reason: 'W arms a wire from the caret',
    );
    expect(adapter.model, isNull, reason: 'nothing committed yet');
  });

  testWidgets('Remove takes the adapter off, and undo puts THE SAME ONE back', (
    tester,
  ) async {
    final adapter = declare();
    await pumpAndSelect(tester);
    await tester.tap(find.byKey(cableBarAdapterRemoveKey(0)));
    await tester.pumpAndSettle();
    expect(doc.links[w001]!.inlineAdapters, isEmpty);
    expect(find.text(kCableBarAdapterLabel), findsNothing);
    expect(
      find.textContaining('removed the XLR3 to RCA adapter'),
      findsWidgets,
    );

    controller.undoLast();
    await tester.pumpAndSettle();
    expect(doc.links[w001]!.inlineAdapters.single, same(adapter));
    expect(find.text('XLR3 to RCA'), findsOneWidget);
  });
}
