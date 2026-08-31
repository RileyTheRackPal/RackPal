// `Ctrl+G` `Group as set…`, `Ctrl+Shift+G` `Ungroup`, and the ROLE cell
// that stopped being free text. `#224` (M4-J2), DR-086 §11.85.
//
// DRIVEN FROM THE KEYBOARD, not from a finder pointed at a menu item,
// because there is no menu item: the chord IS the route. `drive the
// keyboard, not the finder` names the failure this avoids, and it was
// earned on this grid.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// The builder's previews measure text to decide what fits; these tests are
/// not about that, so the proportional stub the rest of the suite uses is
/// enough. `_ProportionalMeasurer` rather than `_FakeMeasurer` deliberately:
/// it returns plausible widths, so a preview laying out against it exercises
/// the real "only if it fits" branches instead of the degenerate zero case.
final class _ProportionalMeasurer implements TextMeasurer {
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

TemplateBody _blank() => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Amp',
  typePrefix: 'AMP',
  frontU: 2,
);

Registries _registries() => Registries(
  connectorTypes: {
    const ConnectorTypeId('conn.rca'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.rca'),
      displayName: 'RCA',
    ),
  },
);

PortDef _port(String key, {required String order}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.rca'),
  signalFamily: const SignalFamilyId('audio.line_unbal'),
  face: Face.rear,
  order: FracIndex(order),
);

TemplateBody _fourPorts() => _blank()
  ..ports.addAll([
    _port('a', order: 'a0000'),
    _port('b', order: 'a0001'),
    _port('c', order: 'a0002'),
    _port('d', order: 'a0003'),
  ]);

final class _Harness {
  TemplateBody? _saved;

  Future<TemplateBody> read(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final body = _saved;
    if (body == null) fail('Save is disabled: the template needs its three');
    return body;
  }
}

Future<_Harness> _pump(WidgetTester tester, {TemplateBody? template}) async {
  final harness = _Harness();
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          measurer: _ProportionalMeasurer(),
          template: template ?? _fourPorts(),
          registries: _registries(),
          actions: DeviceBuilderActions(
            onSave: (body) {
              harness._saved = body;
              return null;
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.widgetWithText(ListTile, 'Ports'));
  await tester.pumpAndSettle();
  return harness;
}

/// Ticks rows BY INDEX, which is the declared order the fixture states.
///
/// The gutter checkbox is the only `Checkbox` on a row, so `.at(i)` is the
/// i-th row's, and the fixture's four ports are declared A, B, C, D. That
/// is what the existing grid cases do and it is what makes a role
/// assertion mean something: the whole question here is which row got `L`.
Future<void> _tick(WidgetTester tester, List<int> rows) async {
  for (final row in rows) {
    await tester.tap(find.byType(Checkbox).at(row));
    await tester.pumpAndSettle();
  }
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pumpAndSettle();
}

/// Groups the first two rows through the dialog.
Future<void> _groupAB(
  WidgetTester tester,
  String name,
  String kind,
) async {
  await _tick(tester, [0, 1]);
  await _chord(tester, LogicalKeyboardKey.keyG);
  await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<SetKind>));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(kind).last);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Group'));
  await tester.pumpAndSettle();
}

void main() {
  group('Ctrl+G refuses before it opens anything', () {
    testWidgets('ONE ROW IS REFUSED IN WORDS, because a set of one cannot '
        'connect atomically and says nothing about its missing half', (
      tester,
    ) async {
      await _pump(tester);
      await _tick(tester, [0]);
      await _chord(tester, LogicalKeyboardKey.keyG);

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.textContaining('at least two ports'),
        findsOneWidget,
      );
    });

    testWidgets('and nothing selected is refused the same way', (
      tester,
    ) async {
      await _pump(tester);
      await _chord(tester, LogicalKeyboardKey.keyG);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('at least two ports'), findsOneWidget);
    });
  });

  group('the dialog previews the roles before it writes them', () {
    testWidgets('GROUP STAYS OFF UNTIL A KIND IS PICKED, because the kind '
        'decides the roles and a default would guess at the hardware', (
      tester,
    ) async {
      await _pump(tester);
      await _tick(tester, [0, 1]);
      await _chord(tester, LogicalKeyboardKey.keyG);

      expect(find.text('Group 2 ports as a set'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Front pair',
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Group'))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Pick a kind'), findsOneWidget);
    });

    testWidgets('the kind offers three, and never the one that means '
        'something other than its name', (tester) async {
      await _pump(tester);
      await _tick(tester, [0, 1]);
      await _chord(tester, LogicalKeyboardKey.keyG);
      await tester.tap(find.byType(DropdownButtonFormField<SetKind>));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stereo pair'), findsWidgets);
      expect(find.textContaining('Speaker pair'), findsWidgets);
      expect(find.textContaining('Component video'), findsWidgets);
      expect(find.textContaining('Balanced pair'), findsNothing);
    });

    testWidgets('FOUR ROWS AS A STEREO PAIR PREVIEW L, R AND TWO ROWS THAT '
        'GET NOTHING, which is what makes running out visible', (
      tester,
    ) async {
      await _pump(tester);
      await _tick(tester, [0, 1, 2, 3]);
      await _chord(tester, LogicalKeyboardKey.keyG);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Wide');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<SetKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Stereo pair').last);
      await tester.pumpAndSettle();

      expect(
        find.text('4 rows matched, 2 will change, 2 to check.'),
        findsOneWidget,
      );
      expect(find.textContaining('so it gets none'), findsWidgets);
    });
  });

  group('grouping writes the set and every member', () {
    testWidgets('two rows, and the ROLE column shows what it wrote', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _tick(tester, [0, 1]);
      await _chord(tester, LogicalKeyboardKey.keyG);
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Front pair',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<SetKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Speaker pair').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Group'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.portSets.single.label, 'Front pair');
      expect(body.portSets.single.kind, SetKind.speakerPair);
      expect(body.portSets.single.atomicConnect, isTrue);
      expect(body.ports[0].setRole, '+');
      expect(body.ports[1].setRole, '-');
    });

    testWidgets('the atomic switch is the field FIRST EDITOR ANYWHERE, and '
        'turning it off is recorded', (tester) async {
      final harness = await _pump(tester);
      await _tick(tester, [0, 1]);
      await _chord(tester, LogicalKeyboardKey.keyG);
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Loose pair',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<SetKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Stereo pair').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          SwitchListTile,
          'Connect as one '
          'cable',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Group'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.portSets.single.atomicConnect, isFalse);
    });

    testWidgets('A GROUP IS ONE Ctrl+Z, set and members together', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _tick(tester, [0, 1]);
      await _chord(tester, LogicalKeyboardKey.keyG);
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Front pair',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<SetKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Stereo pair').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Group'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.portSets, isEmpty);
      expect(body.ports.every((p) => p.setKey == null), isTrue);
    });
  });

  group('the ROLE cell is closed, and dead without a set', () {
    testWidgets('A ROW IN NO SET HAS NO ROLE PICKER AT ALL, because a role '
        'without a set is a value about nothing', (tester) async {
      await _pump(tester);

      // `SET` and `ROLE` are core columns, so both headers are up before
      // anything is grouped.
      expect(find.text('SET'), findsOneWidget);
      expect(find.text('ROLE'), findsOneWidget);
      expect(
        find.byType(DropdownButton<String?>),
        findsNWidgets(4),
        reason: 'four SET pickers, one per row, and no ROLE picker anywhere',
      );
    });

    testWidgets('AND A MEMBER OFFERS EXACTLY ITS KIND ROLES PLUS BLANK, '
        'never a fifth spelling of plus', (tester) async {
      await _pump(tester);
      await _groupAB(tester, 'Front pair', 'Speaker pair');

      // Two members gained a picker; the two loose rows did not.
      expect(find.byType(DropdownButton<String?>), findsNWidgets(6));
      expect(find.text('+'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);

      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      // The open menu, beside the closed button still showing its value.
      expect(find.text('+'), findsNWidgets(2));
      expect(find.text('-'), findsNWidgets(2));
      expect(
        find.text('L'),
        findsNothing,
        reason: 'a speaker pair is not offered a stereo role',
      );
      expect(find.text('Y'), findsNothing);
    });
  });

  group('Ctrl+Shift+G ungroups', () {
    testWidgets('IT TAKES THE HEADING WITH THE LAST MEMBER, which is the '
        'one place a PortSetDef is removed', (tester) async {
      final harness = await _pump(tester);
      await _tick(tester, [0, 1]);
      await _chord(tester, LogicalKeyboardKey.keyG);
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Front pair',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<SetKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Stereo pair').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Group'));
      await tester.pumpAndSettle();

      await _chord(tester, LogicalKeyboardKey.keyG, shift: true);

      final body = await harness.read(tester);
      expect(body.portSets, isEmpty);
      expect(body.ports.every((p) => p.setRole == null), isTrue);
    });

    testWidgets('nothing selected is refused, and a selection in no set is '
        'simply nothing to do', (tester) async {
      await _pump(tester);
      await _chord(tester, LogicalKeyboardKey.keyG, shift: true);
      expect(
        find.textContaining('take out of a set'),
        findsOneWidget,
      );

      await _tick(tester, [0, 1]);
      await _chord(tester, LogicalKeyboardKey.keyG, shift: true);
      expect(find.textContaining('take out of a set'), findsNothing);
    });
  });
}
