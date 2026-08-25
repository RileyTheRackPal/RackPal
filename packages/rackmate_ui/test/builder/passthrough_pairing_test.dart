// `Pair front↔rear by order` and the `PAIRED WITH` cell that stopped
// being read-only. `#225` (M4-J3), DR-087 §11.86.
//
// DRIVEN THROUGH THE SCREEN. The column only exists when `isPassthrough`
// is on, and that switch is on the Physical section, so a case that
// handed `PortGrid` a passthrough body directly would skip the route a
// person actually takes and could not see the gating at all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

Registries _registries() => Registries(
  connectorTypes: {
    const ConnectorTypeId('conn.rj45'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.rj45'),
      displayName: 'RJ45',
    ),
  },
);

PortDef _port(
  String key,
  String label, {
  required String order,
  required Face face,
}) => PortDef(
  key: PortKey(key),
  label: label,
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: face,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  direction: PortDirection.passive,
);

/// A three-position panel. [passthrough] off is the pre-M4-J3 state and
/// the one the column gating is measured against.
TemplateBody _panel({bool passthrough = true}) {
  final body = TemplateBody(
    manufacturer: 'Generic',
    model: 'PP-3',
    displayName: 'Panel',
    typePrefix: 'PP',
    frontU: 1,
    isPassthrough: passthrough,
  );
  for (var i = 1; i <= 3; i++) {
    body.ports.add(
      _port('f$i', 'F$i', order: 'a10$i', face: Face.front),
    );
  }
  for (var i = 1; i <= 3; i++) {
    body.ports.add(_port('r$i', 'R$i', order: 'a20$i', face: Face.rear));
  }
  return body;
}

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

Future<_Harness> _pump(
  WidgetTester tester, {
  TemplateBody? template,
  Size size = const Size(1600, 900),
}) async {
  final harness = _Harness();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          template: template ?? _panel(),
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

/// The `PAIRED WITH` cell on the row whose KEY is [portKey].
///
/// **BY COLUMN AND ROW GEOMETRY, and it has to be.** `SET` and `PAIRED
/// WITH` are both `DropdownButton` over a nullable string, so
/// `find.byType(...).first` picks the SET cell of row 1 and a case
/// written that way passes while testing the wrong column entirely.
///
/// **THE ROW IS FOUND BY ITS KEY AND NOT ITS LABEL**, which the first
/// draft did and which broke the moment a pair existed: once F1 is paired
/// with R2, the string `R2` is on screen twice, in R2's own LABEL cell and
/// in F1's `PAIRED WITH` button. A key appears in exactly one place.
Finder _pairCell(WidgetTester tester, String portKey) {
  final column = tester.getRect(find.text('PAIRED WITH'));
  final row = tester.getRect(find.text(portKey));
  final buttons = find.byType(DropdownButton<String?>).evaluate().toSet();
  return find.byElementPredicate((element) {
    if (!buttons.contains(element)) return false;
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached) return false;
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    return bounds.center.dx >= column.left - 6 &&
        bounds.center.dx <= column.right + 6 &&
        (bounds.center.dy - row.center.dy).abs() < 12;
  });
}

/// What the `PAIRED WITH` picker on [portKey]'s row offers, by key.
///
/// READ OFF THE CONTROL rather than counted in the open overlay: every
/// closed `DropdownButton` builds its own items to size itself, so a
/// count over the whole tree finds sixteen and says nothing about which
/// picker they belong to.
List<String?> _offeredTo(WidgetTester tester, String portKey) => tester
    .widget<DropdownButton<String?>>(_pairCell(tester, portKey))
    .items!
    .map((item) => item.value)
    .toList();

List<String> _pairsOf(TemplateBody body) => [
  for (final p in body.passthroughPairs) '${p.frontKey.v}->${p.rearKey.v}',
];

void main() {
  group('the action is only there when it can do something', () {
    testWidgets('a passthrough shows it, and an ordinary template does not', (
      tester,
    ) async {
      await _pump(tester, template: _panel(passthrough: false));
      expect(find.text('Pair front to rear'), findsNothing);
      expect(
        find.text('PAIRED WITH'),
        findsNothing,
        reason: 'the column rides the same switch the button does',
      );
    });

    testWidgets('and the switch on the Physical section turns both on, '
        'which is the route a person actually takes', (tester) async {
      // TALL, because the Physical form's switch sits below the fold at
      // the ordinary height and a `ListView` does not build what it is not
      // showing. Scrolling to it would work too and would test the
      // scrolling; this case is about the gate the switch opens.
      await _pump(
        tester,
        template: _panel(passthrough: false),
        size: const Size(1600, 2000),
      );

      await tester.tap(find.widgetWithText(ListTile, 'Physical'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Passthrough'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ports'));
      await tester.pumpAndSettle();

      expect(find.text('Pair front to rear'), findsOneWidget);
      expect(find.text('PAIRED WITH'), findsOneWidget);
    });
  });

  group('Pair front to rear by order', () {
    testWidgets('pairs the panel and SAYS WHAT IT DID', (tester) async {
      final harness = await _pump(tester);

      await tester.tap(find.text('Pair front to rear'));
      await tester.pumpAndSettle();

      expect(find.text('Paired 3 ports.'), findsOneWidget);

      final body = await harness.read(tester);
      expect(_pairsOf(body), ['f1->r1', 'f2->r2', 'f3->r3']);
    });

    testWidgets('IT REPORTS THE PORTS IT COULD NOT PAIR, which is the '
        'seeded fibre LIU case arriving on an authored template', (
      tester,
    ) async {
      final body = _panel()
        ..ports.add(_port('r4', 'R4', order: 'a204', face: Face.rear))
        ..ports.add(_port('r5', 'R5', order: 'a205', face: Face.rear));

      await _pump(tester, template: body);
      await tester.tap(find.text('Pair front to rear'));
      await tester.pumpAndSettle();

      expect(
        find.text('Paired 3 ports. 2 rear ports had no partner left.'),
        findsOneWidget,
      );
    });

    testWidgets('a second press refuses in words rather than doing it again', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Pair front to rear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pair front to rear'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing left to pair'), findsOneWidget);
    });

    testWidgets('THE WHOLE RUN IS ONE Ctrl+Z', (tester) async {
      final harness = await _pump(tester);

      await tester.tap(find.text('Pair front to rear'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.passthroughPairs, isEmpty);
    });
  });

  group('the PAIRED WITH cell', () {
    testWidgets('OFFERS THE OTHER FACE AND NOTHING ELSE, plus a blank', (
      tester,
    ) async {
      await _pump(tester);

      expect(_offeredTo(tester, 'f1'), [null, 'r1', 'r2', 'r3']);
      expect(
        _offeredTo(tester, 'r1'),
        [null, 'f1', 'f2', 'f3'],
        reason: 'a rear row is offered fronts, and never another rear',
      );
    });

    testWidgets('AND ITS MENU READS IN LABELS, which is what is printed on '
        'the jack', (tester) async {
      await _pump(tester);

      await tester.tap(_pairCell(tester, 'f1'));
      await tester.pumpAndSettle();

      // The overlay is open, so each rear label is on screen twice: its
      // own LABEL cell and this menu's row for it. The KEY column goes on
      // printing `r2`, which is its job and not what this is about.
      expect(find.text('R2'), findsNWidgets(2));
      expect(find.text('R3'), findsNWidgets(2));
    });

    testWidgets('pairing one row by hand writes both ends the right way '
        'round, and the rear row reads it back', (tester) async {
      final harness = await _pump(tester);

      await tester.tap(_pairCell(tester, 'f1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('R2').last);
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(_pairsOf(body), ['f1->r2']);
      expect(
        tester.widget<DropdownButton<String?>>(_pairCell(tester, 'r2')).value,
        'f1',
        reason: 'a pair is one fact seen from two rows',
      );
    });

    testWidgets('A TAKEN PARTNER IS NOT OFFERED TWICE, so a double-booked '
        'port is not a state this grid can mint', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Pair front to rear'));
      await tester.pumpAndSettle();

      expect(
        _offeredTo(tester, 'f1'),
        [null, 'r1'],
        reason: 'r2 and r3 are taken by F2 and F3; r1 is its own',
      );
    });

    testWidgets('and the blank unpairs it again', (tester) async {
      final harness = await _pump(tester);
      await tester.tap(find.text('Pair front to rear'));
      await tester.pumpAndSettle();

      await tester.tap(_pairCell(tester, 'f1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kUnknownCell).last);
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(_pairsOf(body), ['f2->r2', 'f3->r3']);
    });
  });
}
