// The port grid (M4-E1, #203).
//
// DRIVEN THROUGH THE SCREEN, NOT THE WIDGET, wherever the question is
// about a user rather than about a layout. `drive the keyboard, not the
// finder` was earned on this exact surface a week ago: nineteen tests
// drove M4-D's form by finding controls and missed both defects a user
// found in the first minute, because neither lived in a control.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

TemplateBody _blank() =>
    TemplateBody(manufacturer: 'Generic', model: '', displayName: '');

Registries _registries() => Registries(
  connectorTypes: {
    const ConnectorTypeId('conn.hdmi_a'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.hdmi_a'),
      displayName: 'HDMI Type A',
    ),
  },
);

PortDef _port(String key, {required String order, String? bank}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: Face.rear,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  direction: PortDirection.sink,
  bankKey: bank,
);

/// The builder, opened on the Ports section.
Future<TemplateBody> _pump(
  WidgetTester tester, {
  TemplateBody? template,
  IdFormat format = const IdFormat('J{PORT_SEQ:2}'),
}) async {
  final body = template ?? _blank();
  tester.view.physicalSize = const Size(1400, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          template: body,
          registries: _registries(),
          portDesignatorFormat: format,
          actions: DeviceBuilderActions(onSave: (_) => null),
        ),
      ),
    ),
  );
  await tester.tap(find.widgetWithText(ListTile, 'Ports'));
  await tester.pumpAndSettle();
  return body;
}

void main() {
  group('the section exists at all', () {
    testWidgets('the rail opens a grid rather than a blank pane', (
      tester,
    ) async {
      await _pump(tester);

      // THE HEADERS DRAW WITH NO DATA, which is what makes an empty grid
      // readable: a person can see what the columns will be before
      // deciding what to type.
      expect(find.text('LABEL'), findsOneWidget);
      expect(find.text('DIRECTION'), findsOneWidget);
      expect(find.textContaining('No ports yet'), findsOneWidget);
    });
  });

  group('[+ Add port], which no task in M4-E owns', () {
    testWidgets('puts a row on screen, and it is undoable', (tester) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add port'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No ports yet'), findsNothing);
      expect(find.text('1 port'), findsWidgets);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No ports yet'),
        findsOneWidget,
        reason:
            'the grid writes through the builder stack, so a port is as '
            'undoable as a typed manufacturer',
      );
    });

    testWidgets('a new row is blank and says so with the dash, never with '
        'an invented label', (tester) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add port'));
      await tester.pumpAndSettle();

      // `Port 1` would be written to the file the moment the user saved
      // without touching it, and a template full of `Port 1` is worse
      // than one full of blanks: the blank is visibly unfinished.
      expect(find.text('port.1'), findsOneWidget, reason: 'the key exists');
      expect(find.text('Port 1'), findsNothing);
      expect(find.text('—'), findsWidgets);
    });
  });

  group('deleting, which no task in M4-E owns either', () {
    testWidgets('removes the ticked rows in ONE undo entry', (tester) async {
      await _pump(
        tester,
        template: _blank()
          ..ports.addAll([
            _port('p1', order: 'a0000'),
            _port('p2', order: 'a0001'),
            _port('p3', order: 'a0002'),
          ]),
      );

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Delete 2 selected'), findsOne);

      await tester.tap(find.widgetWithText(TextButton, 'Delete 2 selected'));
      await tester.pumpAndSettle();

      expect(find.text('1 port'), findsWidgets);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      expect(
        find.text('3 ports'),
        findsWidgets,
        reason:
            'two deletions in one gesture is one Ctrl+Z, which is what '
            'the transaction is for',
      );
    });

    testWidgets('the button counts what it will delete', (tester) async {
      await _pump(
        tester,
        template: _blank()..ports.add(_port('p1', order: 'a')),
      );

      // A bare "Delete" beside a grid of 68 rows does not say whether it
      // means the ticked rows or all of them.
      expect(find.widgetWithText(TextButton, 'Delete'), findsOne);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNull,
        reason: 'nothing ticked, nothing to delete',
      );
    });
  });

  group('bands', () {
    testWidgets('one per bank, with its count, and they fold', (tester) async {
      await _pump(
        tester,
        template: _blank()
          ..banks.add(
            BankDef(
              key: 'in',
              label: 'HDMI Inputs',
              abbr: 'HIN',
              order: const FracIndex('a0'),
            ),
          )
          ..ports.addAll([
            _port('p1', bank: 'in', order: 'a0000'),
            _port('p2', bank: 'in', order: 'a0001'),
          ]),
      );

      expect(find.text('HDMI Inputs'), findsOneWidget);
      expect(find.text('2 ports'), findsWidgets);
      expect(find.text('P1'), findsOneWidget);

      await tester.tap(find.text('HDMI Inputs'));
      await tester.pumpAndSettle();

      expect(
        find.text('P1'),
        findsNothing,
        reason: 'a folded band hides its rows and keeps its header',
      );
      expect(find.text('HDMI Inputs'), findsOneWidget);
    });

    testWidgets('a bank key nothing declares keeps its rows on screen and '
        'says what is wrong', (tester) async {
      // M3-L's SERVICE finding: a value no menu offers must not take the
      // table down with it. Here it must not hide the rows either, or
      // the user cannot find the thing they have to fix.
      await _pump(
        tester,
        template: _blank()..ports.add(_port('p1', bank: 'ghost', order: 'a0')),
      );

      expect(find.text('ghost'), findsOneWidget);
      expect(find.text('No such bank'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
    });

    testWidgets('ports in no bank get a band that says so in words', (
      tester,
    ) async {
      await _pump(
        tester,
        template: _blank()..ports.add(_port('p1', order: 'a0')),
      );

      expect(find.text('Not in a bank'), findsOneWidget);
    });
  });

  group('the cells', () {
    testWidgets('print the trade name and the project designator, not our '
        'ids', (tester) async {
      await _pump(
        tester,
        template: _blank()..ports.add(_port('p1', order: 'a0')),
      );

      expect(find.text('HDMI Type A'), findsOneWidget);
      expect(find.text('conn.hdmi_a'), findsNothing);
      expect(find.text('Input'), findsOneWidget, reason: 'not `sink`');
      expect(find.text('J01'), findsOneWidget);
    });

    testWidgets('follow the project format rather than a hard-wired J', (
      tester,
    ) async {
      await _pump(
        tester,
        template: _blank()..ports.add(_port('p1', order: 'a0')),
        format: const IdFormat('P{PORT_SEQ:3}'),
      );

      expect(find.text('P001'), findsOneWidget);
    });

    testWidgets('an automatic designator is italic and a pinned one is not', (
      tester,
    ) async {
      await _pump(
        tester,
        template: _blank()
          ..ports.addAll([
            _port('p1', order: 'a0000'),
            _port('p2', order: 'a0001')..designatorHint = 'HDMI-A',
          ]),
      );

      final auto = tester.widget<Text>(find.text('J01'));
      final pinned = tester.widget<Text>(find.text('HDMI-A'));

      expect(auto.style?.fontStyle, FontStyle.italic);
      expect(
        pinned.style?.fontStyle,
        isNot(FontStyle.italic),
        reason:
            'one glance says which designators a renumber would move and '
            'which the author fixed (docs/06 §4.5)',
      );
    });

    testWidgets('a family the registry does not hold prints its id rather '
        'than taking the row away', (tester) async {
      await _pump(
        tester,
        template: _blank()..ports.add(_port('p1', order: 'a0')),
      );

      // `video.hdmi.2_0` is deliberately absent from `_registries`.
      expect(find.text('video.hdmi.2_0'), findsOneWidget);
    });
  });

  group('rows are the declared order, and a band is a run of it', () {
    testWidgets('a bank interrupted by another still reads in order', (
      tester,
    ) async {
      await _pump(
        tester,
        template: _blank()
          ..ports.addAll([
            _port('a1', bank: 'a', order: 'a0000'),
            _port('b1', bank: 'b', order: 'a0001'),
            _port('a2', bank: 'a', order: 'a0002'),
          ]),
      );

      final aBand = tester.getTopLeft(find.text('a'));
      final bBand = tester.getTopLeft(find.text('b'));
      expect(aBand.dy, lessThan(bBand.dy));
      expect(
        tester.getTopLeft(find.text('A1')).dy,
        lessThan(tester.getTopLeft(find.text('A2')).dy),
      );
    });
  });
}
