// docs/06 §2's bank tree, and §4.6's bank menu on both of its mount
// points. Board `#181` / `#223` (M4-J1), DR-085.
//
// DRIVEN THROUGH THE SCREEN, which is what `port_grid_test.dart`'s header
// argues for and what `drive the keyboard, not the finder` was earned on:
// every case here starts from a rail a person can see and ends at a
// template the editor hands back through Save. Nothing pokes a command in
// and reads the model.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

TemplateBody _blank() => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Matrix',
  typePrefix: 'MTX',
  frontU: 2,
);

Registries _registries() => Registries(
  connectorTypes: {
    const ConnectorTypeId('conn.hdmi_a'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.hdmi_a'),
      displayName: 'HDMI Type A',
    ),
  },
);

/// A port. **[direction] defaults to `sink`**, not to `PortDef`'s own
/// `bidirectional`, because a mirror is only interesting over ports that
/// have an opposite and every fixture here would otherwise repeat it.
PortDef _port(
  String key, {
  required String order,
  String? bank,
  PortDirection direction = PortDirection.sink,
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: Face.rear,
  order: FracIndex(order),
  direction: direction,
  bankKey: bank,
);

BankDef _bank(String key, String label, String abbr, String order) =>
    BankDef(key: key, label: label, abbr: abbr, order: FracIndex(order));

/// A matrix with an `IN` bank of three and one loose port.
TemplateBody _matrix() => _blank()
  ..banks.add(_bank('in', 'IN', 'IN', 'a0'))
  ..ports.addAll([
    _port('in.1', bank: 'in', order: 'a0000'),
    _port('in.2', bank: 'in', order: 'a0001'),
    // THE THIRD IS THE ONE THE PREVIEW HAS TO NAME (DR-085 §11.84.3):
    // `bidirectional` has no opposite, so a mirror copies it through.
    _port(
      'in.3',
      bank: 'in',
      order: 'a0002',
      direction: PortDirection.bidirectional,
    ),
    _port('loose', order: 'a0003'),
  ]);

final class _Harness {
  TemplateBody? _saved;

  /// THE SESSION EDITS A COPY (CR-106), so the only honest way to see the
  /// working template from outside is to press Save.
  Future<TemplateBody> read(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final body = _saved;
    if (body == null) fail('Save is disabled: the template needs its three');
    return body;
  }
}

/// The tree lives in the rail, so its finders are scoped to `BankTree`
/// and the grid's to `PortGrid`. A bank's name is on screen twice by
/// design and a bare `find.text` cannot say which one it means.
Finder _inTree(Finder matching) =>
    find.descendant(of: find.byType(BankTree), matching: matching);

Finder _inGrid(Finder matching) =>
    find.descendant(of: find.byType(PortGrid), matching: matching);

Future<_Harness> _pump(
  WidgetTester tester, {
  TemplateBody? template,
  Size size = const Size(1400, 820),
}) async {
  final harness = _Harness();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          template: template ?? _matrix(),
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
  await tester.pumpAndSettle();
  return harness;
}

/// Opens the `⋯` menu on a tree row and picks [item].
Future<void> _treeMenu(
  WidgetTester tester,
  String bankLabel,
  String item,
) async {
  final row = find.ancestor(
    of: _inTree(find.text(bankLabel)),
    matching: find.byType(ListTile),
  );
  await tester.tap(
    find.descendant(of: row, matching: find.byTooltip('Bank actions')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  group('the tree is in the rail, and it is a fact about the template', () {
    testWidgets('it lists every band the grid draws, with its count', (
      tester,
    ) async {
      await _pump(tester);

      expect(_inTree(find.text('BANKS')), findsOneWidget);
      expect(_inTree(find.text('IN')), findsOneWidget);
      expect(_inTree(find.text('3 ports')), findsOneWidget);
      expect(_inTree(find.text('Not in a bank')), findsOneWidget);
      expect(_inTree(find.text('1 port')), findsOneWidget);
    });

    testWidgets('IT IS THERE ON EVERY SECTION, not only on Ports, because a '
        'rail that reflowed would move the tile under the cursor', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(ListTile, 'Power'));
      await tester.pumpAndSettle();

      expect(_inTree(find.text('IN')), findsOneWidget);
    });

    testWidgets('a template with no banks gets a sentence, not a blank', (
      tester,
    ) async {
      await _pump(tester, template: _blank());

      expect(_inTree(find.textContaining('No banks yet')), findsOneWidget);
    });

    testWidgets('ONLY A DECLARED BANK HAS A MENU: Not in a bank and an '
        'undeclared key are places, not banks', (tester) async {
      await _pump(
        tester,
        template: _blank()
          ..ports.addAll([
            _port('ghost.1', bank: 'ghost', order: 'a0'),
            _port('loose', order: 'a1'),
          ]),
      );

      // Two rows, no menu on either.
      expect(_inTree(find.text('ghost')), findsOneWidget);
      expect(_inTree(find.text('Not in a bank')), findsOneWidget);
      expect(_inTree(find.byTooltip('Bank actions')), findsNothing);
    });
  });

  group('New bank', () {
    testWidgets('creates one, and it is on the tree with no ports in it', (
      tester,
    ) async {
      final harness = await _pump(tester, template: _blank());

      await tester.tap(_inTree(find.byTooltip('New bank')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'HDMI Outputs',
      );
      await tester.pumpAndSettle();

      // The abbreviation FOLLOWS the name until it is typed in.
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Abbreviation'),
            )
            .controller
            ?.text,
        'HDMI',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(_inTree(find.text('HDMI Outputs')), findsOneWidget);
      expect(_inTree(find.text('0 ports')), findsOneWidget);

      final body = await harness.read(tester);
      expect(body.banks.single.label, 'HDMI Outputs');
      expect(body.banks.single.abbr, 'HDMI');
    });

    testWidgets('A DUPLICATE LABEL IS REFUSED IN WORDS and Create stays off, '
        'because buildQuickAdd matches banks BY LABEL', (tester) async {
      await _pump(tester);

      await tester.tap(_inTree(find.byTooltip('New bank')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'IN');
      await tester.pumpAndSettle();

      expect(find.text('A bank called IN already exists.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('an empty name cannot be created either', (tester) async {
      await _pump(tester, template: _blank());

      await tester.tap(_inTree(find.byTooltip('New bank')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create'),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('Rename', () {
    testWidgets('from the tree, and the band header follows', (tester) async {
      final harness = await _pump(tester);

      await _treeMenu(tester, 'IN', 'Rename…');
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'HDMI Inputs',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
      await tester.pumpAndSettle();

      expect(_inTree(find.text('HDMI Inputs')), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Ports'));
      await tester.pumpAndSettle();
      expect(_inGrid(find.text('HDMI Inputs')), findsOneWidget);

      final body = await harness.read(tester);
      expect(body.banks.single.label, 'HDMI Inputs');
      expect(
        body.banks.single.key,
        'in',
        reason: 'a rename never touches the key PortDef.bankKey points at',
      );
    });

    testWidgets('A BANK MAY KEEP ITS OWN NAME: opening Rename and pressing '
        'the button is not a duplicate-label refusal', (tester) async {
      await _pump(tester);

      await _treeMenu(tester, 'IN', 'Rename…');

      expect(find.textContaining('already exists'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Rename'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('A RENAME DOES NOT RETYPE THE ABBREVIATION, because that is '
        'a value the author already chose', (tester) async {
      final harness = await _pump(tester);

      await _treeMenu(tester, 'IN', 'Rename…');
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'HDMI Inputs',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.banks.single.abbr, 'IN');
    });

    testWidgets('THE SECOND MOUNT POINT: the same menu is on the grid band '
        'header, where the cursor already is', (tester) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(ListTile, 'Ports'));
      await tester.pumpAndSettle();

      final header = find.ancestor(
        of: _inGrid(find.text('IN')),
        matching: find.byType(Material),
      );
      await tester.tap(
        find
            .descendant(of: header, matching: find.byTooltip('Bank actions'))
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Rename…'), findsOneWidget);
      expect(find.text('Mirror bank…'), findsOneWidget);
      expect(find.text('Remove (ports stay)'), findsOneWidget);
    });

    testWidgets('and the band header of a bank nobody declared has none', (
      tester,
    ) async {
      await _pump(
        tester,
        template: _blank()..ports.add(_port('ghost.1', bank: 'g', order: 'a0')),
      );
      await tester.tap(find.widgetWithText(ListTile, 'Ports'));
      await tester.pumpAndSettle();

      expect(_inGrid(find.byTooltip('Bank actions')), findsNothing);
    });
  });

  group('Remove', () {
    testWidgets('TAKES THE HEADING AND NOT THE PORTS, which is CR-055: they '
        'land in Not in a bank, in front of the person', (tester) async {
      final harness = await _pump(tester);

      await _treeMenu(tester, 'IN', 'Remove (ports stay)');

      expect(_inTree(find.text('IN')), findsNothing);
      expect(
        _inTree(find.text('4 ports')),
        findsOneWidget,
        reason: 'three un-banded ports joined the one already loose',
      );

      final body = await harness.read(tester);
      expect(body.banks, isEmpty);
      expect(body.ports.length, 4);
      expect(body.ports.every((p) => p.bankKey == null), isTrue);
    });

    testWidgets('one Ctrl+Z puts the heading back and re-bands exactly the '
        'ports it took', (tester) async {
      final harness = await _pump(tester);

      await _treeMenu(tester, 'IN', 'Remove (ports stay)');
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.banks.single.key, 'in');
      expect(body.ports.where((p) => p.bankKey == 'in').length, 3);
      expect(
        body.ports.singleWhere((p) => p.key.v == 'loose').bankKey,
        isNull,
        reason: 'an already-loose port stays loose',
      );
    });
  });

  group('Mirror bank (DR-085)', () {
    testWidgets('THE PREVIEW NAMES EVERY ROW IT LEAVES ALONE, which is '
        '§11.84.3, and the summary counts them', (tester) async {
      await _pump(tester);

      await _treeMenu(tester, 'IN', 'Mirror bank…');

      expect(find.text('Mirror IN'), findsOneWidget);
      expect(
        find.text('3 rows matched, 2 will change, 1 to check.'),
        findsOneWidget,
      );
      expect(find.textContaining('has no opposite'), findsOneWidget);
      expect(find.text('in.3'), findsOneWidget);
    });

    testWidgets('IN swaps to OUT on its own, because that is the case the '
        'docs/06 row is about', (tester) async {
      await _pump(tester);

      await _treeMenu(tester, 'IN', 'Mirror bank…');

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Name'))
            .controller
            ?.text,
        'OUT',
      );
    });

    testWidgets('mirroring copies the ports with source and sink flipped, '
        'under NEW keys, and nothing writes a renamedFrom', (tester) async {
      final harness = await _pump(tester);

      await _treeMenu(tester, 'IN', 'Mirror bank…');
      await tester.tap(find.widgetWithText(FilledButton, 'Mirror'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.banks.map((b) => b.label), ['IN', 'OUT']);
      final copied = body.ports.where((p) => p.bankKey == 'out').toList();
      expect(copied.length, 3);
      expect(
        copied.where((p) => p.direction == PortDirection.source).length,
        2,
        reason: 'the two sinks flipped',
      );
      expect(
        copied.where((p) => p.direction == PortDirection.bidirectional).length,
        1,
        reason: 'bidirectional has no opposite and copies through (CR-060)',
      );
      expect(copied.every((p) => p.renamedFrom.isEmpty), isTrue);
      expect(
        copied.every((p) => p.key.v.startsWith('out.')),
        isTrue,
        reason: 'DR-085 §11.84.5: new keys derive from the NEW bank key',
      );
      expect(
        body.ports.where((p) => p.bankKey == 'in').length,
        3,
        reason: 'the source bank is left exactly as it was',
      );
    });

    testWidgets('a sixteen-port mirror is ONE Ctrl+Z', (tester) async {
      final harness = await _pump(tester);

      await _treeMenu(tester, 'IN', 'Mirror bank…');
      await tester.tap(find.widgetWithText(FilledButton, 'Mirror'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.banks.length, 1);
      expect(body.ports.length, 4);
    });

    testWidgets('A BANK WITH NOTHING TO SWAP LEAVES THE FIELD EMPTY AND SAYS '
        'WHY, and Mirror stays off until a person names it', (tester) async {
      await _pump(
        tester,
        template: _blank()
          ..banks.add(_bank('hdmi', 'HDMI', 'HDMI', 'a0'))
          ..ports.add(_port('hdmi.1', bank: 'hdmi', order: 'a0')),
      );

      await _treeMenu(tester, 'HDMI', 'Mirror bank…');

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Name'))
            .controller
            ?.text,
        '',
      );
      expect(find.textContaining('no IN or OUT'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Mirror'),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'HDMI Mirror',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Mirror'),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  group('clicking a bank navigates', () {
    testWidgets('FROM ANOTHER SECTION IT SWITCHES TO PORTS, so the tree is '
        'never navigation into a section a person is not in', (tester) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(ListTile, 'Power'));
      await tester.pumpAndSettle();
      expect(find.byType(PortGrid), findsNothing);

      await tester.tap(_inTree(find.text('IN')));
      await tester.pumpAndSettle();

      expect(find.byType(PortGrid), findsOneWidget);
    });

    testWidgets('AND IT SCROLLS THE BAND INTO VIEW, on a template long '
        'enough that the band starts off screen', (tester) async {
      // Sixty ports in the first bank, so the second band is well past the
      // bottom of any window this app opens in.
      final body = _blank()
        ..banks.addAll([
          _bank('first', 'First', 'F', 'a0'),
          _bank('last', 'Last', 'L', 'a1'),
        ]);
      for (var i = 0; i < 60; i++) {
        body.ports.add(
          _port('first.$i', bank: 'first', order: 'a${1000 + i}'),
        );
      }
      body.ports.add(_port('last.1', bank: 'last', order: 'a9000'));

      await _pump(tester, template: body, size: const Size(1400, 700));
      await tester.tap(find.widgetWithText(ListTile, 'Ports'));
      await tester.pumpAndSettle();

      expect(
        _inGrid(find.text('LAST.1')),
        findsNothing,
        reason: 'the last band starts below the fold, or this proves nothing',
      );

      await tester.tap(_inTree(find.text('Last')));
      await tester.pumpAndSettle();

      expect(_inGrid(find.text('LAST.1')), findsOneWidget);
    });

    testWidgets('a declared bank with no ports has no band, and clicking it '
        'is not an error', (tester) async {
      await _pump(
        tester,
        template: _matrix()..banks.add(_bank('empty', 'Empty', 'E', 'a1')),
      );

      await tester.tap(_inTree(find.text('Empty')));
      await tester.pumpAndSettle();

      expect(find.byType(PortGrid), findsOneWidget);
      expect(_inTree(find.text('0 ports')), findsOneWidget);
    });
  });
}
