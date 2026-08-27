// The port grid (M4-E1, #203).
//
// DRIVEN THROUGH THE SCREEN, NOT THE WIDGET, wherever the question is
// about a user rather than about a layout. `drive the keyboard, not the
// finder` was earned on this exact surface a week ago: nineteen tests
// drove M4-D's form by finding controls and missed both defects a user
// found in the first minute, because neither lived in a control.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

TemplateBody _blank() =>
    TemplateBody(manufacturer: 'Generic', model: '', displayName: '');

Registries _registries() => Registries(
  connectorTypes: {
    const ConnectorTypeId('conn.hdmi_a'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.hdmi_a'),
      displayName: 'HDMI Type A',
    ),
    // A SECOND CONNECTOR, added at M4-F9: `Change type…` cannot be
    // exercised against a registry offering exactly one, and the
    // `net.ethernet` family below has named `conn.rj45` as its default
    // since this harness was written without anything defining it.
    const ConnectorTypeId('conn.rj45'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.rj45'),
      displayName: 'RJ45',
    ),
  },
  signalFamilies: {
    const SignalFamilyId('net.ethernet'): const SignalFamilyDef(
      id: SignalFamilyId('net.ethernet'),
      displayName: 'Ethernet',
      domain: SignalDomainId('net'),
      defaultConnector: ConnectorTypeId('conn.rj45'),
      defaultDirection: PortDirection.bidirectional,
      defaultTopology: PortTopology.p2p,
    ),
  },
);

/// A port the auto-reveal reacts to: its family sits in the `net` domain.
PortDef _netPort(String key, {required String order}) =>
    _port(key, order: order)
      ..signalFamily = const SignalFamilyId(
        'net.ethernet',
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

/// A template that already satisfies AC-049's three, so `[Save]` is live
/// and [_Harness.read] can get at what the editor is actually holding.
TemplateBody _saveable() => _blank()
  ..displayName = 'Matrix'
  ..typePrefix = 'MTX'
  ..frontU = 2;

/// THE SESSION EDITS A COPY, WHICH IS THE POINT OF IT (CR-106). The
/// template handed to `DeviceBuilderScreen` is never mutated, so a test
/// that asserts on the object it passed in is asserting that nothing
/// happened. [read] presses Save and returns what the editor hands over,
/// which is the only honest way to see the working copy from outside.
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

/// A finder scoped to the GRID.
///
/// The rail carries docs/06 §2's bank tree beside the section list, so a
/// bank's name is now on screen TWICE by design and a bare `find.text`
/// over the whole screen cannot mean "the band header". Every assertion
/// that is about a BAND goes through here; the ones about the tree go
/// through `BankTree` in `bank_tree_test.dart`.
Finder _inGrid(Finder matching) =>
    find.descendant(of: find.byType(PortGrid), matching: matching);

/// The builder, opened on the Ports section.
Future<_Harness> _pump(
  WidgetTester tester, {
  TemplateBody? template,
  IdFormat format = const IdFormat('J{PORT_SEQ:2}'),
}) async {
  final harness = _Harness();
  tester.view.physicalSize = const Size(1400, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          template: template ?? _blank(),
          registries: _registries(),
          portDesignatorFormat: format,
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

  group('the selection (DR-061, M4-F0)', () {
    /// Three rows, so a range has a middle to include.
    Future<void> three(WidgetTester tester) => _pump(
      tester,
      template: _blank()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
        ]),
    ).then((_) {});

    /// A click in a row's body, which is any cell in it.
    Future<void> clickRow(
      WidgetTester tester,
      String label, {
      LogicalKeyboardKey? holding,
    }) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      await tester.tap(find.text(label));
      if (holding != null) await tester.sendKeyUpEvent(holding);
      await tester.pumpAndSettle();
    }

    testWidgets('a click selects the row it lands in', (tester) async {
      await three(tester);

      await clickRow(tester, 'P2');

      expect(find.widgetWithText(TextButton, 'Delete 1 selected'), findsOne);
    });

    testWidgets('clicking a row ticks its box, because the box IS the '
        'selection rather than a second set beside it', (tester) async {
      await three(tester);

      await clickRow(tester, 'P1');

      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value,
        isTrue,
      );
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value,
        isFalse,
      );
    });

    testWidgets('Shift+click takes the whole run between the two', (
      tester,
    ) async {
      await three(tester);

      await clickRow(tester, 'P1');
      await clickRow(tester, 'P3', holding: LogicalKeyboardKey.shift);

      expect(find.widgetWithText(TextButton, 'Delete 3 selected'), findsOne);
    });

    testWidgets('Ctrl+click adds one row and leaves the gap alone', (
      tester,
    ) async {
      await three(tester);

      await clickRow(tester, 'P1');
      await clickRow(tester, 'P3', holding: LogicalKeyboardKey.control);

      expect(find.widgetWithText(TextButton, 'Delete 2 selected'), findsOne);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value,
        isFalse,
        reason: 'the middle row was never touched',
      );
    });

    testWidgets('A TICK AND A CLICK BUILD THE SAME SET, which is the whole '
        'of the ruling: ticking one row then Shift+clicking another '
        'ranges from the ticked one', (tester) async {
      await three(tester);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      await clickRow(tester, 'P3', holding: LogicalKeyboardKey.shift);

      expect(find.widgetWithText(TextButton, 'Delete 3 selected'), findsOne);
    });

    testWidgets('CLICKING A CELL IN AN ALREADY-SELECTED ROW DOES NOT '
        'COLLAPSE THE SELECTION, or F2 could never fire and would fail '
        'by writing one row instead of N', (tester) async {
      await three(tester);

      await clickRow(tester, 'P1');
      await clickRow(tester, 'P3', holding: LogicalKeyboardKey.shift);
      expect(find.widgetWithText(TextButton, 'Delete 3 selected'), findsOne);

      // The gesture a person makes to start editing the batch.
      await clickRow(tester, 'P2');

      expect(
        find.widgetWithText(TextButton, 'Delete 3 selected'),
        findsOne,
        reason:
            'the row was already in the selection, so the click is about '
            'which cell to edit and not about which rows are chosen',
      );
    });

    testWidgets('a plain click on a row OUTSIDE the selection replaces it, '
        'because that is how a person starts over', (tester) async {
      await three(tester);

      await clickRow(tester, 'P1');
      await clickRow(tester, 'P2', holding: LogicalKeyboardKey.shift);
      await clickRow(tester, 'P3');

      expect(find.widgetWithText(TextButton, 'Delete 1 selected'), findsOne);
    });

    testWidgets('deleting the selection empties it, so the button does not '
        'go on counting rows that are gone', (tester) async {
      await three(tester);

      await clickRow(tester, 'P1');
      await clickRow(tester, 'P2', holding: LogicalKeyboardKey.shift);
      await tester.tap(find.widgetWithText(TextButton, 'Delete 2 selected'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Delete'), findsOne);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNull,
      );
    });
  });

  group('Ctrl+J duplicates the selection (M4-F6, DR-078)', () {
    Future<_Harness> four(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
          _port('p4', order: 'a0003'),
        ]),
    );

    Future<void> clickRowNamed(
      WidgetTester tester,
      String text, {
      LogicalKeyboardKey? holding,
    }) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      await tester.tap(find.text(text));
      if (holding != null) await tester.sendKeyUpEvent(holding);
      await tester.pumpAndSettle();
    }

    Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
    }

    testWidgets('two selected rows become four, cloned below themselves', (
      tester,
    ) async {
      final harness = await four(tester);

      await clickRowNamed(tester, 'P1');
      await clickRowNamed(tester, 'P2', holding: LogicalKeyboardKey.shift);
      await ctrl(tester, LogicalKeyboardKey.keyJ);

      final body = await harness.read(tester);
      // P5 AND P6, NOT P3 AND P4: `_port` labels a row from its key, so
      // the template already runs to P4 and §4.6's "past the highest
      // existing index" counts on from there. And they land after P2,
      // the last SELECTED row, not at the end of the template.
      expect(portsInDeclaredOrder(body.ports).map((p) => p.label), [
        'P1',
        'P2',
        'P5',
        'P6',
        'P3',
        'P4',
      ]);
    });

    // THE ROUTE, NAMED ONLY BY ITS START. `Ctrl+J` then typing must land
    // on the CLONES: duplicate-then-retype is the gesture this exists
    // for, and a test that looked up the new row and typed into it would
    // pass against a grid that left the selection on the sources.
    testWidgets('the selection follows the clones, so typing retypes them', (
      tester,
    ) async {
      final harness = await four(tester);

      await clickRowNamed(tester, 'P1');
      await ctrl(tester, LogicalKeyboardKey.keyJ);
      // No finder in between: whatever is selected now takes this one.
      await ctrl(tester, LogicalKeyboardKey.keyJ);

      final body = await harness.read(tester);
      // The second clone is of P5 and lands under it. Had the selection
      // stayed on the source, the second press would have cloned P1
      // again and put P6 BEFORE P5, which is a different list: that is
      // what makes this assertion able to fail.
      expect(portsInDeclaredOrder(body.ports).map((p) => p.label), [
        'P1',
        'P5',
        'P6',
        'P2',
        'P3',
        'P4',
      ]);
    });

    // ONE UNDO, not four. Through the toolbar button rather than a
    // chord, because focus is inside a cell `TextField` after a click and
    // `Ctrl+Z` there belongs to the field (docs/04 §8).
    testWidgets('one Undo takes the whole clone back', (tester) async {
      final harness = await four(tester);

      await clickRowNamed(tester, 'P1');
      await clickRowNamed(tester, 'P4', holding: LogicalKeyboardKey.shift);
      await ctrl(tester, LogicalKeyboardKey.keyJ);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports, hasLength(4));
    });

    testWidgets('nothing selected refuses out loud rather than silently', (
      tester,
    ) async {
      await four(tester);
      await ctrl(tester, LogicalKeyboardKey.keyJ);

      expect(
        find.textContaining('Select the ports to duplicate'),
        findsOneWidget,
      );
    });
  });

  group('Ctrl+R renumbers through a dialog (M4-F7, DR-078)', () {
    Future<_Harness> four(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
          _port('p4', order: 'a0003'),
        ]),
    );

    Future<void> clickRowNamed(
      WidgetTester tester,
      String text, {
      LogicalKeyboardKey? holding,
    }) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      await tester.tap(find.text(text));
      if (holding != null) await tester.sendKeyUpEvent(holding);
      await tester.pumpAndSettle();
    }

    Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
    }

    Future<void> openOn(WidgetTester tester, List<String> rows) async {
      await clickRowNamed(tester, rows.first);
      for (final row in rows.skip(1)) {
        await clickRowNamed(tester, row, holding: LogicalKeyboardKey.shift);
      }
      await ctrl(tester, LogicalKeyboardKey.keyR);
    }

    testWidgets('the pattern is seeded from the first selected label', (
      tester,
    ) async {
      await four(tester);
      await openOn(tester, ['P1', 'P4']);

      // `P1` infers prefix `P` and start 1, so the field offers `P{n}`
      // and the common case is pressing Enter. Same reader `Ctrl+Shift+D`
      // uses, so the two gestures cannot disagree about what the number
      // in a label is.
      final field = tester.widget<TextField>(
        find.ancestor(
          of: find.text('P{n}'),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller?.text, 'P{n}');
    });

    testWidgets('the impact list shows every row before anything is written', (
      tester,
    ) async {
      final harness = await four(tester);
      await openOn(tester, ['P1', 'P4']);

      await tester.enterText(
        find.widgetWithText(TextField, 'P{n}'),
        'IN {n}',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('4 rows will change'), findsOneWidget);
      expect(find.text('IN 1'), findsOneWidget);
      expect(find.text('IN 4'), findsOneWidget);

      // NOT WRITTEN YET. Cancelling leaves the grid alone, which is the
      // property the whole preview rests on.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), ['P1', 'P2', 'P3', 'P4']);
    });

    testWidgets('Renumber writes the labels the preview promised', (
      tester,
    ) async {
      final harness = await four(tester);
      await openOn(tester, ['P1', 'P4']);

      await tester.enterText(
        find.widgetWithText(TextField, 'P{n}'),
        'IN {n:2}',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Renumber'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(portsInDeclaredOrder(body.ports).map((p) => p.label), [
        'IN 01',
        'IN 02',
        'IN 03',
        'IN 04',
      ]);
    });

    testWidgets('Start numbers a sub-range from where the person says', (
      tester,
    ) async {
      final harness = await four(tester);
      await openOn(tester, ['P3', 'P4']);

      await tester.enterText(find.widgetWithText(TextField, 'P{n}'), 'IN {n}');
      await tester.enterText(find.widgetWithText(TextField, 'Start'), '9');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Renumber'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(portsInDeclaredOrder(body.ports).map((p) => p.label), [
        'P1',
        'P2',
        'IN 9',
        'IN 10',
      ]);
    });

    // M4-H's designed parse error, shown where the person is typing, with
    // the repair chip that carries the WHOLE fixed pattern.
    testWidgets('a bad pattern refuses to apply and offers its repair', (
      tester,
    ) async {
      await four(tester);
      await openOn(tester, ['P1', 'P4']);

      await tester.enterText(find.widgetWithText(TextField, 'P{n}'), 'IN {q}');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Renumber'),
            )
            .onPressed,
        isNull,
        reason: 'Renumber must not be pressable on a pattern that failed',
      );
      expect(find.byType(ActionChip), findsOneWidget);

      // Accepting the repair makes it applicable again, which is what
      // makes the chip a fix rather than a suggestion.
      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Renumber'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('nothing selected refuses without opening a dialog', (
      tester,
    ) async {
      await four(tester);
      await ctrl(tester, LogicalKeyboardKey.keyR);

      expect(find.text('Renumber ports'), findsNothing);
      expect(
        find.textContaining('Select the ports to renumber'),
        findsOneWidget,
      );
    });

    testWidgets('one Undo takes the whole renumber back', (tester) async {
      final harness = await four(tester);
      await openOn(tester, ['P1', 'P4']);
      await tester.enterText(find.widgetWithText(TextField, 'P{n}'), 'IN {n}');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Renumber'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), ['P1', 'P2', 'P3', 'P4']);
    });
  });

  group('Ctrl+M moves ports between banks (M4-F10, DR-078)', () {
    Future<_Harness> banked(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..banks.addAll([
          BankDef(
            key: 'in',
            label: 'Inputs',
            abbr: 'IN',
            order: const FracIndex('a1'),
          ),
          BankDef(
            key: 'out',
            label: 'Outputs',
            abbr: 'OUT',
            order: const FracIndex('a2'),
          ),
        ])
        ..ports.addAll([
          _port('p1', order: 'a0000', bank: 'in'),
          _port('p2', order: 'a0001', bank: 'in'),
          _port('p3', order: 'a0002', bank: 'out'),
        ]),
    );

    Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
    }

    testWidgets('a picked bank moves the row and keeps the band whole', (
      tester,
    ) async {
      final harness = await banked(tester);

      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      await ctrl(tester, LogicalKeyboardKey.keyM);

      expect(find.text('Move 1 port'), findsOneWidget);
      await tester.tap(find.widgetWithText(RadioListTile<String?>, 'Outputs'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Move'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(buildPortTable(body).bands.map((b) => b.title), [
        'Inputs',
        'Outputs',
      ]);
      expect(
        buildPortTable(body).bands.last.rows.map((r) => r.port.key.v),
        ['p3', 'p1'],
      );
    });

    // NOTHING PRESELECTED, so a careless Enter cannot move eight ports
    // into whichever bank sorted first: this dialog has no impact list to
    // catch that.
    testWidgets('Move is disabled until a destination is picked', (
      tester,
    ) async {
      await banked(tester);
      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      await ctrl(tester, LogicalKeyboardKey.keyM);

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Move'))
            .onPressed,
        isNull,
      );
    });

    // DR-078 section 11.77.2: it offers what exists and mints nothing, so
    // a template whose only bank is the one the rows are in refuses with a
    // sentence rather than opening a dialog with a text field in it.
    testWidgets('one bank and nowhere to go refuses without a dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        template: _saveable()
          ..banks.add(
            BankDef(
              key: 'in',
              label: 'Inputs',
              abbr: 'IN',
              order: const FracIndex('a1'),
            ),
          )
          ..ports.addAll([
            _port('p1', order: 'a0000', bank: 'in'),
            _port('p2', order: 'a0001', bank: 'in'),
          ]),
      );

      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      await ctrl(tester, LogicalKeyboardKey.keyM);

      expect(find.textContaining('Move 1 port'), findsNothing);
      expect(
        find.textContaining('no other bank to move to'),
        findsOneWidget,
      );
    });

    testWidgets('nothing selected refuses without opening a dialog', (
      tester,
    ) async {
      await banked(tester);
      await ctrl(tester, LogicalKeyboardKey.keyM);

      expect(find.textContaining('Move 1 port'), findsNothing);
      expect(find.textContaining('Select the ports to move'), findsOneWidget);
    });
  });

  group('Ctrl+T changes type behind a preview (M4-F9, DR-078)', () {
    Future<_Harness> three(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
        ]),
    );

    Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
    }

    Future<void> openOn(WidgetTester tester, List<String> rows) async {
      await tester.tap(find.text(rows.first));
      await tester.pumpAndSettle();
      for (final row in rows.skip(1)) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.tap(find.text(row));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pumpAndSettle();
      }
      await ctrl(tester, LogicalKeyboardKey.keyT);
    }

    testWidgets('Apply is dead until something is picked', (tester) async {
      await three(tester);
      await openOn(tester, ['P1', 'P3']);

      expect(find.text('Change type on 3 ports'), findsOneWidget);
      expect(
        find.text('Pick a signal family, a connector, or both.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('picking a connector previews it and Apply writes it', (
      tester,
    ) async {
      final harness = await three(tester);
      await openOn(tester, ['P1', 'P3']);

      await tester.tap(find.byType(DropdownButton<ConnectorTypeId>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RJ45').last);
      await tester.pumpAndSettle();

      // The preview is on screen BEFORE anything is written.
      expect(find.textContaining('3 rows will change'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(
        body.ports.map((p) => p.connector.v).toSet(),
        {'conn.rj45'},
      );
    });

    // #699's own sentence, on screen: what it will leave alone.
    testWidgets('it says direction and topology are left as they are', (
      tester,
    ) async {
      await three(tester);
      await openOn(tester, ['P1', 'P3']);

      await tester.tap(find.byType(DropdownButton<ConnectorTypeId>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RJ45').last);
      await tester.pumpAndSettle();

      // A connector-only change makes no claim about direction, so the
      // note is absent here and present once a family is picked.
      expect(find.text(kChangeTypeKeepsNote), findsNothing);
    });

    testWidgets('cancelling writes nothing', (tester) async {
      final harness = await three(tester);
      await openOn(tester, ['P1', 'P3']);

      await tester.tap(find.byType(DropdownButton<ConnectorTypeId>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RJ45').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.connector.v).toSet(), {'conn.hdmi_a'});
    });

    testWidgets('nothing selected refuses without opening a dialog', (
      tester,
    ) async {
      await three(tester);
      await ctrl(tester, LogicalKeyboardKey.keyT);

      expect(find.textContaining('Change type on'), findsNothing);
      expect(
        find.textContaining('Select the ports to change'),
        findsOneWidget,
      );
    });
  });

  group('Ctrl+H finds and replaces behind a preview (M4-F8, DR-078)', () {
    Future<_Harness> three(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
        ]),
    );

    Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
    }

    Future<void> openOnAll(WidgetTester tester) async {
      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.tap(find.text('P3'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      await ctrl(tester, LogicalKeyboardKey.keyH);
    }

    testWidgets('a label replacement previews, then writes', (tester) async {
      final harness = await three(tester);
      await openOnAll(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Find'), 'P');
      await tester.enterText(
        find.widgetWithText(TextField, 'Replace with'),
        'Q',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('3 rows will change'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), ['Q1', 'Q2', 'Q3']);
    });

    testWidgets('an empty Find box says so and Replace is dead', (
      tester,
    ) async {
      await three(tester);
      await openOnAll(tester);

      expect(find.text('Type what to find.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Replace'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('regex is off by default, so a bracket is a character', (
      tester,
    ) async {
      await three(tester);
      await openOnAll(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Find'), '[');
      await tester.pumpAndSettle();

      // Literal: not a refusal, just a search that matches nothing. The
      // same string with the box ticked IS a refusal, below.
      expect(
        find.text('That is not a valid regular expression.'),
        findsNothing,
      );

      // SCOPED: the grid's row gutter is full of tick boxes.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('That is not a valid regular expression.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Replace'),
            )
            .onPressed,
        isNull,
      );
    });

    // THE DANGEROUS SCOPE, on screen. `_pump` opens the builder on a
    // template whose ports were already there, so every key is published
    // and every rename row says so.
    testWidgets('the KEY scope marks a published key in the preview', (
      tester,
    ) async {
      await three(tester);
      await openOnAll(tester);

      // SCOPED TO THE DIALOG, and both halves of that mattered.
      // `widgetWithText(SegmentedButton, 'KEY')` finds the whole button
      // and taps its centre, which with four segments lands between KEY
      // and DESIG; and a bare `find.text('KEY')` is ambiguous because the
      // grid's own KEY column header is still on screen behind the modal.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('KEY'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Find'), 'p');
      await tester.enterText(
        find.widgetWithText(TextField, 'Replace with'),
        'j',
      );
      await tester.pumpAndSettle();

      expect(find.text(kPublishedKeyNote), findsWidgets);
      expect(find.textContaining('3 to check'), findsOneWidget);
    });

    testWidgets('cancelling writes nothing', (tester) async {
      final harness = await three(tester);
      await openOnAll(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Find'), 'P');
      await tester.enterText(
        find.widgetWithText(TextField, 'Replace with'),
        'Q',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), ['P1', 'P2', 'P3']);
    });

    testWidgets('nothing selected refuses without opening a dialog', (
      tester,
    ) async {
      await three(tester);
      await ctrl(tester, LogicalKeyboardKey.keyH);

      expect(find.text('Find and replace'), findsNothing);
      expect(
        find.textContaining('Select the ports to search'),
        findsOneWidget,
      );
    });
  });

  group('the batch inspector WRITES (M4-F11, DR-063)', () {
    Future<_Harness> two(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001')..face = Face.front,
        ]),
    );

    Future<void> select(WidgetTester tester) async {
      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.tap(find.text('P2'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
    }

    Finder inDock(Finder matching) =>
        find.descendant(of: find.byType(BatchInspector), matching: matching);

    // THE TRAP `#703` NAMED, and it is the first case for that reason: a
    // control seeded from mixed that fires onChanged on construction or on
    // focus writes the dash back across N rows.
    testWidgets('opening the dock on a mixed field writes nothing', (
      tester,
    ) async {
      final harness = await two(tester);
      await select(tester);

      expect(inDock(find.textContaining('Mixed (2 values)')), findsOne);

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.face), [Face.rear, Face.front]);
    });

    testWidgets('focusing and leaving a mixed text cell writes nothing', (
      tester,
    ) async {
      final harness = await two(tester);
      await select(tester);

      // NOTES AND NOT LABEL. DR-063 keeps `LABEL` and `DESIG` to one row
      // (one label across eight rows mints eight colliding keys), so the
      // dock draws no control for them at all, which the first draft of
      // this case discovered by asking for one.
      //
      // Focus the box and leave without typing: `_commit` compares
      // against the EMPTY seed, so this is equal to it and returns early.
      // That is the trap `#703` named, expressed as a route.
      final box = find.byKey(batchCellKey(PortColumnId.notes));
      expect(box, findsOne, reason: 'the dock draws no NOTES control');
      await tester.tap(box);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.notes), [null, null]);
    });

    testWidgets('picking a value in the dock writes it to every row', (
      tester,
    ) async {
      final harness = await two(tester);
      await select(tester);

      // THE DOCK'S FACE MENU, BY KEY. Tapping the `Mixed (2 values)`
      // TEXT missed its hit test, the menu never opened, and
      // `find.text('Front').last` then hit a GRID cell: the multi-row
      // edit applied, this assertion passed, and the dock was never
      // touched. The tap warning is what found it.
      await tester.tap(find.byKey(batchCellKey(PortColumnId.face)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Front').last);
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.face), [Face.front, Face.front]);
    });

    testWidgets('one Undo takes the whole batch write back', (tester) async {
      final harness = await two(tester);
      await select(tester);

      await tester.tap(find.byKey(batchCellKey(PortColumnId.face)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Front').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.face), [Face.rear, Face.front]);
    });

    testWidgets('the dock says the rule rather than pointing at the grid', (
      tester,
    ) async {
      await two(tester);
      await select(tester);

      expect(inDock(find.text(kBatchInspectorHint)), findsOne);
      expect(
        find.text('Edit any cell in the grid to change all of them.'),
        findsNothing,
      );
    });
  });

  group('fill down and fill series (DR-062, M4-F1)', () {
    Future<_Harness> four(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
          _port('p4', order: 'a0003'),
        ]),
    );

    /// Clicks a cell, which both focuses its column and selects its row.
    Future<void> clickCell(
      WidgetTester tester,
      String text, {
      LogicalKeyboardKey? holding,
    }) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      await tester.tap(find.text(text));
      if (holding != null) await tester.sendKeyUpEvent(holding);
      await tester.pumpAndSettle();
    }

    Future<void> press(
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

    testWidgets('Ctrl+D copies the top cell of the selection down the '
        'focused column', (tester) async {
      final harness = await four(tester);

      await tester.enterText(find.text('P1'), 'HDMI');
      await clickCell(tester, 'HDMI');
      await clickCell(tester, 'P4', holding: LogicalKeyboardKey.shift);
      await press(tester, LogicalKeyboardKey.keyD);

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), [
        'HDMI',
        'HDMI',
        'HDMI',
        'HDMI',
      ]);
    });

    testWidgets('Ctrl+Shift+D counts instead of copying', (tester) async {
      final harness = await four(tester);

      await tester.enterText(find.text('P1'), 'IN 01');
      await clickCell(tester, 'IN 01');
      await clickCell(tester, 'P4', holding: LogicalKeyboardKey.shift);
      await press(tester, LogicalKeyboardKey.keyD, shift: true);

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), [
        'IN 01',
        'IN 02',
        'IN 03',
        'IN 04',
      ]);
    });

    testWidgets('THE WHOLE FILL IS ONE Ctrl+Z, because one keystroke made '
        'it and one should take it back', (tester) async {
      final harness = await four(tester);

      await tester.enterText(find.text('P1'), 'IN 01');
      await clickCell(tester, 'IN 01');
      await clickCell(tester, 'P4', holding: LogicalKeyboardKey.shift);
      await press(tester, LogicalKeyboardKey.keyD, shift: true);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), ['IN 01', 'P2', 'P3', 'P4']);
    });

    testWidgets('THE COLUMN IS THE ONE WITH FOCUS, so the same rows fill '
        'differently depending on which cell was clicked', (tester) async {
      final harness = await four(tester);

      // DESIG this time, and the LABELS must come out untouched. The
      // whole selection is identical to the test above; only the column
      // the hand was in differs.
      await tester.enterText(find.text('J01'), 'X 5');
      await clickCell(tester, 'X 5');
      await clickCell(tester, 'J04', holding: LogicalKeyboardKey.shift);
      await press(tester, LogicalKeyboardKey.keyD, shift: true);

      final body = await harness.read(tester);
      expect(
        body.ports.map((p) => p.label),
        ['P1', 'P2', 'P3', 'P4'],
        reason: 'the labels were never focused, so nothing wrote to them',
      );
      expect(body.ports.map((p) => p.designatorHint), [
        'X 5',
        'X 6',
        'X 7',
        'X 8',
      ]);
    });

    testWidgets('A REFUSAL IS A SENTENCE ON SCREEN, because a key that '
        'quietly does nothing reads as a key that is not bound', (
      tester,
    ) async {
      await four(tester);

      // One row selected, so there is nothing below to fill into.
      await clickCell(tester, 'P2');
      await press(tester, LogicalKeyboardKey.keyD);

      expect(find.textContaining('Select two or more rows'), findsOne);
    });

    testWidgets('a series refused for want of a number names the key to '
        'press instead', (tester) async {
      await four(tester);

      await tester.enterText(find.text('P1'), 'SPEAKER');
      await clickCell(tester, 'SPEAKER');
      await clickCell(tester, 'P3', holding: LogicalKeyboardKey.shift);
      await press(tester, LogicalKeyboardKey.keyD, shift: true);

      expect(find.textContaining('no number in it'), findsOne);
      expect(
        find.textContaining('Fill down'),
        findsOne,
        reason: 'a refusal that does not name the way forward is a dead end',
      );
    });

    testWidgets('the complaint clears the moment the selection changes, '
        'because it was about that selection', (tester) async {
      await four(tester);

      await clickCell(tester, 'P2');
      await press(tester, LogicalKeyboardKey.keyD);
      expect(find.textContaining('Select two or more rows'), findsOne);

      await clickCell(tester, 'P3');

      expect(find.textContaining('Select two or more rows'), findsNothing);
    });
  });

  group('multi-row edit (DR-063, M4-F2)', () {
    Future<_Harness> four(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
          _port('p4', order: 'a0003'),
        ]),
    );

    Future<void> clickCell(
      WidgetTester tester,
      String text, {
      LogicalKeyboardKey? holding,
    }) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      await tester.tap(find.text(text));
      if (holding != null) await tester.sendKeyUpEvent(holding);
      await tester.pumpAndSettle();
    }

    /// The DIRECTION dropdowns belonging to GRID ROWS.
    ///
    /// NOT `find.byType(...).at(n)`, and the first draft of this file
    /// was: Quick Add's field-mode bar sits above the grid and carries a
    /// `DropdownButton<PortDirection>` of its own, so index 0 is the bar
    /// and every row is off by one. Its picker is UNSET until somebody
    /// chooses, and a row always carries a direction, so a non-null value
    /// is exactly "a row cell" and the count assertion below fails loudly
    /// if that ever stops being true.
    Finder rowDirections() => find.byWidgetPredicate(
      (w) => w is DropdownButton<PortDirection> && w.value != null,
    );

    Future<void> pickDirection(
      WidgetTester tester,
      int row,
      String value,
    ) async {
      expect(
        rowDirections(),
        findsNWidgets(4),
        reason: 'one DIRECTION cell per row and none from Quick Add',
      );
      await tester.tap(rowDirections().at(row));
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    testWidgets('EDITING ONE CELL WRITES EVERY SELECTED ROW, which is the '
        'whole of the feature', (tester) async {
      final harness = await four(tester);

      await clickCell(tester, 'P1');
      await clickCell(tester, 'P4', holding: LogicalKeyboardKey.shift);
      await pickDirection(tester, 0, 'Output');

      final body = await harness.read(tester);
      expect(
        body.ports.map((p) => p.direction),
        everyElement(PortDirection.source),
      );
    });

    testWidgets('a row OUTSIDE the selection writes only itself, because '
        'clicking elsewhere is what a person does to edit one row', (
      tester,
    ) async {
      final harness = await four(tester);

      await clickCell(tester, 'P1');
      await clickCell(tester, 'P2', holding: LogicalKeyboardKey.shift);
      await clickCell(tester, 'P4');
      await pickDirection(tester, 3, 'Output');

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.direction), [
        PortDirection.sink,
        PortDirection.sink,
        PortDirection.sink,
        PortDirection.source,
      ]);
    });

    testWidgets('THE WHOLE BATCH IS ONE Ctrl+Z, because one edit made it', (
      tester,
    ) async {
      final harness = await four(tester);

      await clickCell(tester, 'P1');
      await clickCell(tester, 'P4', holding: LogicalKeyboardKey.shift);
      await pickDirection(tester, 0, 'Output');

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(
        body.ports.map((p) => p.direction),
        everyElement(PortDirection.sink),
      );
    });

    testWidgets('A LABEL STILL WRITES ONE ROW (DR-063). One label across '
        'four rows would name four ports the same and mint four colliding '
        'keys', (tester) async {
      final harness = await four(tester);

      await clickCell(tester, 'P1');
      await clickCell(tester, 'P4', holding: LogicalKeyboardKey.shift);
      await tester.enterText(find.text('P2'), 'HDMI');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(
        body.ports.map((p) => p.label),
        ['P1', 'HDMI', 'P3', 'P4'],
        reason: 'only the row that was typed into changed',
      );
    });

    testWidgets('ONE selected row is a plain cell edit and not a batch', (
      tester,
    ) async {
      final harness = await four(tester);

      await clickCell(tester, 'P2');
      await pickDirection(tester, 1, 'Output');

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.direction), [
        PortDirection.sink,
        PortDirection.source,
        PortDirection.sink,
        PortDirection.sink,
      ]);
    });
  });

  group('the batch inspector (docs/06 §2, DR-063)', () {
    Future<void> four(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
          _port('p4', order: 'a0003'),
        ]),
    ).then((_) {});

    Future<void> select(
      WidgetTester tester,
      String from,
      String to,
    ) async {
      await tester.tap(find.text(from));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.tap(find.text(to));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
    }

    testWidgets('THE DOCK IS ABSENT UNTIL THERE IS SOMETHING TO INSPECT, '
        'because a pane that opens onto nothing is the UnbuiltView '
        'defect wearing a hat', (tester) async {
      await four(tester);

      expect(find.byType(BatchInspector), findsNothing);

      await tester.tap(find.text('P1'));
      await tester.pumpAndSettle();
      expect(
        find.byType(BatchInspector),
        findsNothing,
        reason: 'one row is a cell edit, not a batch',
      );
    });

    testWidgets('it opens on the second row and counts them', (tester) async {
      await four(tester);

      await select(tester, 'P1', 'P3');

      expect(find.byType(BatchInspector), findsOne);
      expect(find.text('3 ports selected'), findsOne);
    });

    testWidgets("AGREEMENT PRINTS THE VALUE, in the grid's own words and "
        'never an enum name', (tester) async {
      await four(tester);

      await select(tester, 'P1', 'P4');

      // All four are `sink`, which the product calls Input.
      expect(
        find.descendant(
          of: find.byType(BatchInspector),
          matching: find.text('Input'),
        ),
        findsOne,
      );
      expect(find.textContaining('PortDirection'), findsNothing);
    });

    testWidgets('A DISAGREEMENT READS "Mixed", NOT THE DASH. That is the '
        "whole of DR-063: the dash is G4's unknown and these rows are "
        'not unmeasured, they differ', (tester) async {
      await _pump(
        tester,
        template: _saveable()
          ..ports.addAll([
            _port('p1', order: 'a0000'),
            _port('p2', order: 'a0001')..face = Face.front,
          ]),
      );

      await select(tester, 'P1', 'P2');

      expect(
        find.descendant(
          of: find.byType(BatchInspector),
          matching: find.textContaining('Mixed (2 values)'),
        ),
        findsOne,
      );
    });

    testWidgets('ALL-UNMEASURED STILL READS THE DASH, which is the other '
        'half of the same ruling', (tester) async {
      await four(tester);

      await select(tester, 'P1', 'P4');

      // NOTES is unset on every row: that is unknown, not a disagreement.
      expect(
        find.descendant(
          of: find.byType(BatchInspector),
          matching: find.text('—'),
        ),
        findsWidgets,
      );
    });

    testWidgets('IT NAMES THE IDENTITY COLUMNS NOWHERE, because a batch '
        'may not write them (DR-063)', (tester) async {
      await four(tester);

      await select(tester, 'P1', 'P4');

      for (final header in ['LABEL', 'DESIG', 'KEY']) {
        expect(
          find.descendant(
            of: find.byType(BatchInspector),
            matching: find.text(header),
          ),
          findsNothing,
          reason: '$header is not batch-writable',
        );
      }
    });

    testWidgets('it follows the selection down to one row and closes', (
      tester,
    ) async {
      await four(tester);

      await select(tester, 'P1', 'P2');
      expect(find.byType(BatchInspector), findsOne);

      // OUTSIDE THE SELECTION, and the first draft of this clicked a row
      // INSIDE it and failed. That is DR-061 working: a plain click on an
      // already-selected row leaves the selection alone, because clicking
      // into a cell to start a batch edit must not collapse the batch.
      await tester.tap(find.text('P4'));
      await tester.pumpAndSettle();

      expect(find.byType(BatchInspector), findsNothing);
    });

    testWidgets('AN EDIT IN THE GRID MOVES THE READING, so the two panes '
        'cannot disagree about the same ports', (tester) async {
      await four(tester);

      await select(tester, 'P1', 'P4');
      expect(
        find.descendant(
          of: find.byType(BatchInspector),
          matching: find.text('Input'),
        ),
        findsOne,
      );

      await tester.tap(
        find
            .byWidgetPredicate(
              (w) => w is DropdownButton<PortDirection> && w.value != null,
            )
            .at(0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Output').last);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BatchInspector),
          matching: find.text('Output'),
        ),
        findsOne,
      );
    });
  });

  group('TSV copy and paste (M4-F3)', () {
    /// The platform clipboard is a channel, not a variable: a widget test
    /// has no OS behind it, so the handler below IS the clipboard for the
    /// duration of a test. Without it `Clipboard.getData` answers null
    /// and every paste case would pass by doing nothing.
    String? clipboard;

    setUp(() {
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String?;
              return null;
            }
            if (call.method == 'Clipboard.getData') {
              return clipboard == null ? null : {'text': clipboard};
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<_Harness> three(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
          _port('p3', order: 'a0002'),
        ]),
    );

    Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
    }

    Future<void> click(
      WidgetTester tester,
      String text, {
      LogicalKeyboardKey? holding,
    }) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      await tester.tap(find.text(text));
      if (holding != null) await tester.sendKeyUpEvent(holding);
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+C puts the selected rows on the clipboard, headed', (
      tester,
    ) async {
      await three(tester);

      await click(tester, 'P1');
      await click(tester, 'P3', holding: LogicalKeyboardKey.shift);
      await chord(tester, LogicalKeyboardKey.keyC);

      final text = clipboard;
      expect(text, isNotNull);
      final lines = text!.split('\n');
      expect(lines, hasLength(4), reason: 'a header and three rows');
      expect(lines.first, contains('LABEL'));
      expect(lines[1], contains('P1'));
      expect(find.textContaining('3 ports copied'), findsOne);
    });

    testWidgets('THE ROUND TRIP THROUGH THE REAL CLIPBOARD: copy three '
        'rows, paste them back, and nothing moved', (tester) async {
      final harness = await three(tester);

      await click(tester, 'P1');
      await click(tester, 'P3', holding: LogicalKeyboardKey.shift);
      await chord(tester, LogicalKeyboardKey.keyC);
      await chord(tester, LogicalKeyboardKey.keyV);

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), ['P1', 'P2', 'P3']);
    });

    testWidgets('a paste writes what the clipboard says, from the caret', (
      tester,
    ) async {
      final harness = await three(tester);

      clipboard = 'ONE\nTWO';
      await click(tester, 'P1');
      await chord(tester, LogicalKeyboardKey.keyV);

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), ['ONE', 'TWO', 'P3']);
    });

    testWidgets('A PASTE DOES NOT CREATE PORTS, and says by how many', (
      tester,
    ) async {
      final harness = await three(tester);

      clipboard = 'A\nB\nC\nD\nE';
      await click(tester, 'P1');
      await chord(tester, LogicalKeyboardKey.keyV);

      expect(find.textContaining('2 rows more'), findsOne);
      final body = await harness.read(tester);
      expect(
        body.ports.map((p) => p.label),
        ['P1', 'P2', 'P3'],
        reason:
            'it refused entirely rather than writing three and truncating: '
            'a half-applied paste is worse than none',
      );
    });

    testWidgets('the whole paste is ONE Ctrl+Z', (tester) async {
      final harness = await three(tester);

      clipboard = 'ONE\nTWO\nTHREE';
      await click(tester, 'P1');
      await chord(tester, LogicalKeyboardKey.keyV);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.map((p) => p.label), ['P1', 'P2', 'P3']);
    });

    testWidgets('copying nothing says so rather than putting an empty '
        'sheet on the clipboard', (tester) async {
      await three(tester);

      await chord(tester, LogicalKeyboardKey.keyC);

      expect(find.textContaining('Select one or more rows'), findsOne);
      expect(clipboard, isNull);
    });
  });

  group('reorder (M4-F4)', () {
    /// Four rows in one bank, plus two in a second so the band edge is a
    /// real edge rather than the end of the template.
    Future<_Harness> rows(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('p1', order: 'a0000', bank: 'in'),
          _port('p2', order: 'a0001', bank: 'in'),
          _port('p3', order: 'a0002', bank: 'in'),
          _port('p4', order: 'a0003', bank: 'in'),
          _port('q1', order: 'a0004', bank: 'out'),
          _port('q2', order: 'a0005', bank: 'out'),
        ]),
    );

    /// THE DECLARED ORDER, WHICH IS THE ARTIFACT. `body.ports` is the list
    /// the decoder happened to build; what every consumer of a template
    /// reads is `portsInDeclaredOrder`, and a reorder that changed only
    /// the former would be a reorder that did nothing.
    List<String> order(TemplateBody body) => [
      for (final port in portsInDeclaredOrder(body.ports)) port.label,
    ];

    Future<void> alt(WidgetTester tester, LogicalKeyboardKey arrow) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(arrow);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();
    }

    Future<void> click(
      WidgetTester tester,
      String text, {
      LogicalKeyboardKey? holding,
    }) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      await tester.tap(find.text(text));
      if (holding != null) await tester.sendKeyUpEvent(holding);
      await tester.pumpAndSettle();
    }

    testWidgets('THE CHORD REACHES THE GRID: Alt+Down moves the selected '
        'row past the one below it', (tester) async {
      // The route, not the planner. `buildPortNudge` is tested in core
      // over 22 cases; what a widget test can see and core cannot is
      // whether pressing the key gets there at all. M4-F0 shipped an
      // `Enter` that moved nowhere with fourteen gates green.
      final harness = await rows(tester);

      await click(tester, 'P2');
      await alt(tester, LogicalKeyboardKey.arrowDown);

      expect(order(await harness.read(tester)), [
        'P1',
        'P3',
        'P2',
        'P4',
        'Q1',
        'Q2',
      ]);
    });

    testWidgets('Alt+Up moves it back, and the pair is a round trip', (
      tester,
    ) async {
      final harness = await rows(tester);

      await click(tester, 'P2');
      await alt(tester, LogicalKeyboardKey.arrowDown);
      await alt(tester, LogicalKeyboardKey.arrowUp);

      expect(order(await harness.read(tester)), [
        'P1',
        'P2',
        'P3',
        'P4',
        'Q1',
        'Q2',
      ]);
    });

    testWidgets('a selection of two travels as a block', (tester) async {
      final harness = await rows(tester);

      await click(tester, 'P1');
      await click(tester, 'P2', holding: LogicalKeyboardKey.shift);
      await alt(tester, LogicalKeyboardKey.arrowDown);

      expect(order(await harness.read(tester)), [
        'P3',
        'P1',
        'P2',
        'P4',
        'Q1',
        'Q2',
      ]);
    });

    testWidgets('a block move is ONE undo, not one per row', (tester) async {
      final harness = await rows(tester);

      await click(tester, 'P1');
      await click(tester, 'P2', holding: LogicalKeyboardKey.shift);
      await alt(tester, LogicalKeyboardKey.arrowDown);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      expect(order(await harness.read(tester)), [
        'P1',
        'P2',
        'P3',
        'P4',
        'Q1',
        'Q2',
      ]);
    });

    testWidgets('THE BAND EDGE IS A WALL, and the toolbar says which one '
        'it hit', (tester) async {
      // The ruling: an arrow key never retypes a port. A chord that
      // quietly did nothing would be indistinguishable from one that is
      // not bound, which is how a person concludes the feature does not
      // exist.
      final harness = await rows(tester);

      await click(tester, 'Q1');
      await alt(tester, LogicalKeyboardKey.arrowUp);

      expect(find.textContaining('as far as this bank goes'), findsOne);
      expect(order(await harness.read(tester)), [
        'P1',
        'P2',
        'P3',
        'P4',
        'Q1',
        'Q2',
      ]);
    });

    testWidgets('a row that crosses no wall does not change its bank', (
      tester,
    ) async {
      final harness = await rows(tester);

      await click(tester, 'Q1');
      await alt(tester, LogicalKeyboardKey.arrowUp);

      final body = await harness.read(tester);
      expect(body.ports.firstWhere((p) => p.label == 'Q1').bankKey, 'out');
    });

    testWidgets('a selection spanning two banks is refused by name', (
      tester,
    ) async {
      await rows(tester);

      await click(tester, 'P4');
      await click(tester, 'Q1', holding: LogicalKeyboardKey.shift);
      await alt(tester, LogicalKeyboardKey.arrowDown);

      expect(find.textContaining('different banks'), findsOne);
    });

    testWidgets('every row carries a drag handle, one each', (tester) async {
      await rows(tester);

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(6));
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(6));
    });

    testWidgets('DRAGGING THE HANDLE REORDERS, AND THE BAND CATCHES IT: '
        'a drag aimed well past the bank lands at the foot of its own', (
      tester,
    ) async {
      // TWO CLAIMS IN ONE GESTURE, and the second is the ruling. The
      // drag is aimed far below the last row of the SECOND bank; a
      // reorderable list does not hand an item to a sibling list, so the
      // index clamps at this band's end and P1 lands after P4 rather than
      // among the Q rows.
      //
      // OVERSHOT ON PURPOSE, rather than aimed at a row in the middle.
      // How many pixels of travel become one index is `SliverReorderable
      // List`'s arithmetic over animations that are still running, and a
      // test that pinned a distance would be asserting Flutter's easing
      // curve. Clamping at the end is the same code path and has one
      // answer.
      final harness = await rows(tester);

      // The handles are in row order within their band, so the first is
      // P1's. The row PITCH is the gap between two gutters, which is the
      // only measurement here that assumes no padding.
      final handle = find.byType(ReorderableDragStartListener).first;
      final gutters = find.byType(Checkbox);
      final pitch =
          tester.getCenter(gutters.at(1)).dy -
          tester.getCenter(gutters.at(0)).dy;

      final drag = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 50));
      for (var step = 0; step < 8; step++) {
        await drag.moveBy(Offset(0, pitch));
        await tester.pumpAndSettle();
      }
      await drag.up();
      await tester.pumpAndSettle();

      expect(order(await harness.read(tester)), [
        'P2',
        'P3',
        'P4',
        'P1',
        'Q1',
        'Q2',
      ]);
      expect(
        (await harness.read(
          tester,
        )).ports.firstWhere((p) => p.label == 'P1').bankKey,
        'in',
      );
    });
  });

  group('view-only sort (M4-F5)', () {
    /// Three rows whose labels sort differently from their declared
    /// order, plus a second bank so the band rule is visible.
    Future<_Harness> rows(WidgetTester tester) => _pump(
      tester,
      template: _saveable()
        ..ports.addAll([
          _port('c', order: 'a0000', bank: 'in')..label = 'CHARLIE',
          _port('a', order: 'a0001', bank: 'in')..label = 'ALPHA',
          _port('b', order: 'a0002', bank: 'in')..label = 'BRAVO',
          _port('z', order: 'a0003', bank: 'out')..label = 'ZULU',
        ]),
    );

    /// The labels as they are stacked on screen, top to bottom.
    List<String> onScreen(WidgetTester tester, List<String> labels) {
      final placed = [
        for (final label in labels)
          (label: label, y: tester.getCenter(find.text(label)).dy),
      ]..sort((a, b) => a.y.compareTo(b.y));
      return [for (final row in placed) row.label];
    }

    List<String> declared(TemplateBody body) => [
      for (final port in portsInDeclaredOrder(body.ports)) port.label,
    ];

    Future<void> clickHeader(WidgetTester tester, String header) async {
      await tester.tap(find.text(header));
      await tester.pumpAndSettle();
    }

    testWidgets('A CLICK SORTS THE VIEW AND NOT THE FILE, which is the '
        'whole feature', (tester) async {
      final harness = await rows(tester);

      await clickHeader(tester, 'LABEL');

      expect(onScreen(tester, ['CHARLIE', 'ALPHA', 'BRAVO']), [
        'ALPHA',
        'BRAVO',
        'CHARLIE',
      ]);
      expect(declared(await harness.read(tester)), [
        'CHARLIE',
        'ALPHA',
        'BRAVO',
        'ZULU',
      ]);
    });

    testWidgets('the badge says it is a view, and carries both ways out', (
      tester,
    ) async {
      await rows(tester);
      await clickHeader(tester, 'LABEL');

      expect(find.textContaining('still in their declared order'), findsOne);
      expect(find.widgetWithText(TextButton, 'Clear sort'), findsOne);
      expect(find.widgetWithText(TextButton, 'Commit sort order'), findsOne);
    });

    testWidgets('a third click returns to the declared order', (tester) async {
      // The way back matters more here than in a spreadsheet: the
      // declared order is the truth, and somebody who clicked a header by
      // accident needs a route to it that is not reloading the template.
      await rows(tester);

      await clickHeader(tester, 'LABEL');
      await clickHeader(tester, 'LABEL');
      expect(find.textContaining('Z–A'), findsOne);

      await clickHeader(tester, 'LABEL');
      expect(find.textContaining('declared order'), findsNothing);
      expect(onScreen(tester, ['CHARLIE', 'ALPHA', 'BRAVO']), [
        'CHARLIE',
        'ALPHA',
        'BRAVO',
      ]);
    });

    testWidgets('the sort works inside each bank, and the bands stay', (
      tester,
    ) async {
      await rows(tester);
      await clickHeader(tester, 'LABEL');

      // ZULU is alphabetically last but it is in the other bank, so it
      // stays below all three IN rows rather than sorting among them.
      expect(onScreen(tester, ['CHARLIE', 'ALPHA', 'BRAVO', 'ZULU']), [
        'ALPHA',
        'BRAVO',
        'CHARLIE',
        'ZULU',
      ]);
    });

    testWidgets('THE DRAG HANDLE GOES INERT while a sort is showing', (
      tester,
    ) async {
      await rows(tester);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(4));

      await clickHeader(tester, 'LABEL');

      expect(find.byType(ReorderableDragStartListener), findsNothing);
      // Drawn, not removed: the gutter does not reflow and the
      // affordance reads as unavailable rather than as never existing.
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(4));
    });

    testWidgets('Alt+Up refuses in words while a sort is showing', (
      tester,
    ) async {
      final harness = await rows(tester);
      await clickHeader(tester, 'LABEL');

      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();

      expect(find.textContaining('Clear the sort first'), findsOne);
      expect(declared(await harness.read(tester)), [
        'CHARLIE',
        'ALPHA',
        'BRAVO',
        'ZULU',
      ]);
    });

    testWidgets('COMMIT ASKS FIRST, and cancelling changes nothing '
        '(AC-058/D5)', (tester) async {
      final harness = await rows(tester);
      await clickHeader(tester, 'LABEL');

      await tester.tap(find.widgetWithText(TextButton, 'Commit sort order'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOne);
      expect(find.textContaining('symbol pin order'), findsOne);
      // Three, not two. CHARLIE, ALPHA, BRAVO into ALPHA, BRAVO, CHARLIE
      // is a 3-cycle, so every row changes position and the count says
      // so. A confirm that under-counted would be the one number in the
      // dialog a person could check against the grid.
      //
      // SCOPED TO THE DIALOG, because the `in` band's own header also
      // reads "3 ports" and an unscoped finder matched both. The count
      // being right in the wrong widget is not the claim.
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('3 ports'),
        ),
        findsOne,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(declared(await harness.read(tester)), [
        'CHARLIE',
        'ALPHA',
        'BRAVO',
        'ZULU',
      ]);
      expect(find.textContaining('declared order'), findsOne);
    });

    testWidgets('confirming writes the order and clears the badge', (
      tester,
    ) async {
      final harness = await rows(tester);
      await clickHeader(tester, 'LABEL');

      await tester.tap(find.widgetWithText(TextButton, 'Commit sort order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Commit'));
      await tester.pumpAndSettle();

      expect(declared(await harness.read(tester)), [
        'ALPHA',
        'BRAVO',
        'CHARLIE',
        'ZULU',
      ]);
      // The view and the file are now the same thing, so a badge still
      // saying "this is only a view" would describe a state that ended.
      expect(find.textContaining('declared order'), findsNothing);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(4));
    });

    testWidgets('a committed sort is one undo away', (tester) async {
      final harness = await rows(tester);
      await clickHeader(tester, 'LABEL');
      await tester.tap(find.widgetWithText(TextButton, 'Commit sort order'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Commit'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      expect(declared(await harness.read(tester)), [
        'CHARLIE',
        'ALPHA',
        'BRAVO',
        'ZULU',
      ]);
    });

    testWidgets('committing an order that is already the declared one says '
        'so rather than opening a dialog', (tester) async {
      await rows(tester);
      // KEY sorts a, b, c, z which is not the declared order; PORT SEQ is
      // the declared order itself, so sorting by DESIG commits nothing.
      await clickHeader(tester, 'DESIG');

      await tester.tap(find.widgetWithText(TextButton, 'Commit sort order'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('already in this order'), findsOne);
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

      expect(_inGrid(find.text('HDMI Inputs')), findsOneWidget);
      expect(find.text('2 ports'), findsWidgets);
      expect(find.text('P1'), findsOneWidget);

      await tester.tap(_inGrid(find.text('HDMI Inputs')));
      await tester.pumpAndSettle();

      expect(
        find.text('P1'),
        findsNothing,
        reason: 'a folded band hides its rows and keeps its header',
      );
      expect(_inGrid(find.text('HDMI Inputs')), findsOneWidget);
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

      expect(_inGrid(find.text('ghost')), findsOneWidget);
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

      expect(_inGrid(find.text('Not in a bank')), findsOneWidget);
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

      // READ OFF THE FIELD'S STYLE, not off a `Text`: since M4-E2 the
      // cell is a `TextField`, and `find.text` matches its `EditableText`
      // rather than a `Text` widget.
      final auto = tester.widget<TextField>(
        find.ancestor(of: find.text('J01'), matching: find.byType(TextField)),
      );
      final pinned = tester.widget<TextField>(
        find.ancestor(
          of: find.text('HDMI-A'),
          matching: find.byType(TextField),
        ),
      );

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

  group('the cells write back (M4-E2)', () {
    /// Types [text] into the cell under [header] on the only row.
    Future<void> typeCell(
      WidgetTester tester,
      String header,
      String text,
    ) async {
      final column = tester.getTopLeft(find.text(header)).dx;
      final fields = find.byType(TextField);
      for (var i = 0; i < tester.widgetList(fields).length; i++) {
        if ((tester.getTopLeft(fields.at(i)).dx - column).abs() < 8) {
          await tester.enterText(fields.at(i), text);
          await tester.pump();
          // TAB OUT, because the cell commits on BLUR. Calling
          // `enterText` and asserting would test a `TextEditingController`
          // and nothing else, which is `drive the keyboard, not the
          // finder` in its smallest form.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          return;
        }
      }
      fail('no text cell under $header');
    }

    testWidgets('a label typed into a new row drags its key along, in one '
        'undo entry', (tester) async {
      final harness = await _pump(tester, template: _saveable());
      await tester.tap(find.widgetWithText(FilledButton, 'Add port'));
      await tester.pumpAndSettle();

      await typeCell(tester, 'LABEL', 'HDMI IN 1');

      expect((await harness.read(tester)).ports.single.label, 'HDMI IN 1');
      expect(
        (await harness.read(tester)).ports.single.key.v,
        'hdmi.in.1',
        reason: 'a key nobody has typed is not a key anybody has chosen',
      );

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      expect(
        (await harness.read(tester)).ports.single.label,
        isEmpty,
        reason:
            'one gesture, one Ctrl+Z: the label and the key move back '
            'together',
      );
      expect((await harness.read(tester)).ports.single.key.v, 'port.1');
    });

    testWidgets('once the key is typed it stops following, and the old '
        'name is NOT recorded for a port no project has seen', (tester) async {
      final harness = await _pump(tester, template: _saveable());
      await tester.tap(find.widgetWithText(FilledButton, 'Add port'));
      await tester.pumpAndSettle();

      await typeCell(tester, 'KEY', 'mine');
      await typeCell(tester, 'LABEL', 'HDMI IN 1');

      expect(
        (await harness.read(tester)).ports.single.key.v,
        'mine',
        reason: 'the label must not overwrite a key the author chose',
      );
      expect(
        (await harness.read(tester)).ports.single.renamedFrom,
        isEmpty,
        reason:
            'CR-051: `port.1` was a working title this editor invented '
            'seconds earlier and no project has ever joined through it',
      );
    });

    testWidgets('a key that WAS in the template records its old name, '
        'because a project may join cables through it', (tester) async {
      final harness = await _pump(
        tester,
        template: _saveable()..ports.add(_port('published', order: 'a0')),
      );

      await typeCell(tester, 'KEY', 'renamed');

      expect((await harness.read(tester)).ports.single.key.v, 'renamed');
      expect(
        (await harness.read(tester)).ports.single.renamedFrom.map((k) => k.v),
        ['published'],
      );
    });

    testWidgets('a published port does not drag its key when the label is '
        'corrected', (tester) async {
      final harness = await _pump(
        tester,
        template: _saveable()..ports.add(_port('published', order: 'a0')),
      );

      await typeCell(tester, 'LABEL', 'HDMI IN 2');

      expect((await harness.read(tester)).ports.single.label, 'HDMI IN 2');
      expect(
        (await harness.read(tester)).ports.single.key.v,
        'published',
        reason:
            'the migration join silently following a typo correction is '
            'the failure CR-051 exists to prevent',
      );
    });

    testWidgets('an undone key rename stays touched, so the label does not '
        'start dragging it again', (tester) async {
      final harness = await _pump(tester, template: _saveable());
      await tester.tap(find.widgetWithText(FilledButton, 'Add port'));
      await tester.pumpAndSettle();

      await typeCell(tester, 'KEY', 'mine');
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect((await harness.read(tester)).ports.single.key.v, 'port.1');

      await typeCell(tester, 'LABEL', 'HDMI IN 1');

      expect(
        (await harness.read(tester)).ports.single.key.v,
        'port.1',
        reason:
            'the touched set holds BOTH sides of a rename, so an undo '
            'lands on a key it still remembers',
      );
    });

    testWidgets('clearing a designator returns it to automatic rather than '
        'pinning a blank', (tester) async {
      final harness = await _pump(
        tester,
        template: _saveable()
          ..ports.add(_port('p1', order: 'a0')..designatorHint = 'HDMI-A'),
      );

      await typeCell(tester, 'DESIG', '');

      expect((await harness.read(tester)).ports.single.designatorHint, isNull);
      expect(find.text('J01'), findsOneWidget);
    });

    testWidgets('DIRECTION offers all five values in words', (tester) async {
      final harness = await _pump(
        tester,
        template: _saveable()..ports.add(_port('p1', order: 'a0')),
      );

      await tester.tap(find.text('Input').last);
      await tester.pumpAndSettle();

      for (final d in PortDirection.values) {
        expect(find.text(portDirectionLabel(d)), findsWidgets);
      }

      await tester.tap(find.text('Bus node').last);
      await tester.pumpAndSettle();

      expect(
        (await harness.read(tester)).ports.single.direction,
        PortDirection.busNode,
      );
    });

    testWidgets('a note is UNKNOWN when cleared, never an empty string', (
      tester,
    ) async {
      final harness = await _pump(
        tester,
        template: _saveable()
          ..ports.add(_port('p1', order: 'a0')..notes = 'hi'),
      );

      await typeCell(tester, 'NOTES', '   ');

      expect(
        (await harness.read(tester)).ports.single.notes,
        isNull,
        reason:
            'G4: an absent key is unknown, and an empty string would be a '
            'note somebody wrote',
      );
    });
  });

  group('the seven column packs (M4-E3)', () {
    testWidgets('closed by default, and the gear opens one', (tester) async {
      await _pump(
        tester,
        template: _saveable()..ports.add(_port('p1', order: 'a0')),
      );

      expect(find.text('PoE ROLE'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      expect(find.text('PoE ROLE'), findsOneWidget);
      expect(
        find.text('LABEL'),
        findsOneWidget,
        reason: 'a pack joins the core columns rather than replacing them',
      );
    });

    testWidgets('a pack the user closes stays closed even when the bank '
        'would open it', (tester) async {
      // Without the override, closing a pack the auto-reveal wants would
      // last exactly one rebuild.
      final harness = await _pump(
        tester,
        template: _saveable()..ports.add(_netPort('n1', order: 'a0')),
      );

      expect(
        find.text('PoE ROLE'),
        findsOneWidget,
        reason: 'a bank of ethernet ports reveals the Network pack',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('PoE ROLE'), findsNothing);
      expect(harness, isNotNull);
    });

    testWidgets('the app is handed the set to remember, keyed on the '
        'category', (tester) async {
      final remembered = <String, Set<PortColumnPack>>{};
      tester.view.physicalSize = const Size(1400, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceBuilderScreen(
              // ONE OF `kCatalogCategoryOrder`'S NINE. The Identity
              // section's category dropdown asserts that exactly one item
              // matches its value, so a made-up category takes the whole
              // screen down: the same assertion M3-L found on SERVICE,
              // met here by a test rather than by a user.
              template: _saveable()..category = kCatNetwork,
              registries: _registries(),
              actions: DeviceBuilderActions(
                onSave: (_) => null,
                rememberedPacks: (c) => remembered[c] ?? const {},
                onPacksRemembered: (c, packs) => remembered[c] = packs,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ListTile, 'Ports'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Serial'));
      await tester.pumpAndSettle();

      expect(remembered[kCatNetwork], contains(PortColumnPack.serial));
    });

    testWidgets('GENDER is dead on a connector that has none (CR-059)', (
      tester,
    ) async {
      await _pump(
        tester,
        template: _saveable()..ports.add(_port('p1', order: 'a0')),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      expect(find.text('GENDER'), findsOneWidget);
      expect(
        find.byTooltip('This connector has no gender.'),
        findsOneWidget,
        reason:
            'disabled rather than hidden: the column is open because the '
            'person opened the pack, and a gap where a control should be '
            'reads as a rendering fault',
      );
    });

    testWidgets('a number cell writes an int and an empty one writes '
        'UNKNOWN', (tester) async {
      final harness = await _pump(
        tester,
        template: _saveable()..ports.add(_port('p1', order: 'a0')),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Electrical'));
      await tester.pumpAndSettle();

      final column = tester.getTopLeft(find.text('IMPEDANCE')).dx;
      final fields = find.byType(TextField);
      for (var i = 0; i < tester.widgetList(fields).length; i++) {
        if ((tester.getTopLeft(fields.at(i)).dx - column).abs() < 8) {
          await tester.enterText(fields.at(i), '75');
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          break;
        }
      }

      expect((await harness.read(tester)).ports.single.impedanceOhms, 75);
    });
  });

  group('the validation dot (M4-E4)', () {
    testWidgets('a clean row has no dot at all', (tester) async {
      await _pump(
        tester,
        template: _saveable()..ports.add(_port('p1', order: 'a0')),
      );

      expect(find.byIcon(Icons.circle), findsNothing);
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
    });

    testWidgets('a filled dot for a warning, hollow for a notice', (
      tester,
    ) async {
      await _pump(
        tester,
        template: _saveable()
          ..ports.addAll([
            _port('ir', order: 'a0')
              ..signalFamily = const SignalFamilyId('ctl.ir_emitter'),
            _port('spdif', order: 'a1')
              ..signalFamily = const SignalFamilyId('audio.spdif_coax'),
          ]),
      );

      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });

    testWidgets('the tooltip says what is wrong, in words an installer '
        'can act on', (tester) async {
      await _pump(
        tester,
        template: _saveable()
          ..ports.add(
            _port('ir', order: 'a0')
              ..signalFamily = const SignalFamilyId('ctl.ir_emitter'),
          ),
      );

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byIcon(Icons.circle),
          matching: find.byType(Tooltip),
        ),
      );

      expect(tooltip.message, contains('destroys'));
      expect(tooltip.message, isNot(contains('AC-')));
    });

    testWidgets('IT DOES NOT BLOCK SAVING, which is the whole design', (
      tester,
    ) async {
      // AC-049: three fields make a template. A checker that can stop a
      // save is a fourth required field wearing a warning triangle, and
      // that is the thing the ruling deleted.
      final harness = await _pump(
        tester,
        template: _saveable()
          ..ports.add(
            _port('ir', order: 'a0')
              ..signalFamily = const SignalFamilyId('ctl.ir_emitter'),
          ),
      );

      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      expect((await harness.read(tester)).ports, hasLength(1));
    });

    testWidgets('fixing the fault clears the dot', (tester) async {
      await _pump(
        tester,
        template: _saveable()
          ..ports.add(
            _port('ir', order: 'a0')
              ..signalFamily = const SignalFamilyId('ctl.ir_emitter'),
          ),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      final column = tester.getTopLeft(find.text('PINOUT')).dx;
      final fields = find.byType(TextField);
      for (var i = 0; i < tester.widgetList(fields).length; i++) {
        if ((tester.getTopLeft(fields.at(i)).dx - column).abs() < 8) {
          await tester.enterText(fields.at(i), 'emitter');
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          break;
        }
      }

      expect(
        find.byIcon(Icons.circle),
        findsNothing,
        reason: 'live means live: the dot goes when the fault does',
      );
    });
  });

  group('the footer readout (M4-E5)', () {
    testWidgets('is there before any port is, so the shape is learnable', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('0 ports · 0 banks · Rear 0 / Front 0'), findsOneWidget);
    });

    testWidgets('counts what the grid holds, in one line', (tester) async {
      await _pump(
        tester,
        template: _saveable()
          ..ports.addAll([
            _port('a', order: 'a0', bank: 'in'),
            _port('b', order: 'a1', bank: 'in'),
            _netPort('n', order: 'a2')..face = Face.front,
          ]),
      );

      expect(
        find.text('3 ports · 2 banks · 3 HDMI Type A · Rear 2 / Front 1'),
        findsOneWidget,
      );
    });

    testWidgets('follows an edit immediately, which is what it is for', (
      tester,
    ) async {
      // "The fastest check that a generator did what the user meant" is
      // only fast if it moves when the grid does.
      await _pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add port'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 port · 1 bank'), findsOneWidget);
    });

    testWidgets('stays put while the columns scroll under it', (tester) async {
      // A footer inside the horizontal scroll would be off screen exactly
      // when a wide template made it most useful.
      await _pump(
        tester,
        template: _saveable()..ports.add(_port('p1', order: 'a0')),
      );

      final before = tester.getTopLeft(find.textContaining('1 port · 1 bank'));

      await tester.tap(find.widgetWithText(TextButton, 'Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.textContaining('1 port · 1 bank')),
        before,
      );
    });
  });

  group('the keyboard, which is how this grid is actually used', () {
    testWidgets('ENTER COMMITS AND MOVES DOWN, so a column of labels is '
        'typed without ever reaching for the mouse (M4-F0)', (tester) async {
      final harness = await _pump(
        tester,
        template: _saveable()
          ..ports.addAll([
            _port('p1', order: 'a0000'),
            _port('p2', order: 'a0001'),
            _port('p3', order: 'a0002'),
          ]),
      );

      // One cell picked with the mouse, and then the hand stays home.
      await tester.enterText(find.text('P1'), 'HDMI 1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // No finder between the two: whatever Enter moved to is what this
      // types into, which is the only way to test the ROUTE rather than
      // the destination.
      tester.testTextInput.enterText('HDMI 2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      tester.testTextInput.enterText('HDMI 3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(
        body.ports.map((p) => p.label),
        ['HDMI 1', 'HDMI 2', 'HDMI 3'],
        reason:
            'Enter landed in the LABEL cell of the next row down each '
            'time; had it stayed put, the last write would win and the '
            'first two rows would still read P1 and P2',
      );
    });

    testWidgets('Enter on the last row commits rather than losing what was '
        'typed on the way to nowhere', (tester) async {
      final harness = await _pump(
        tester,
        template: _saveable()..ports.add(_port('p1', order: 'a0000')),
      );

      await tester.enterText(find.text('P1'), 'ONLY');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final body = await harness.read(tester);
      expect(body.ports.single.label, 'ONLY');
    });

    testWidgets('Tab walks the row left to right and never lands on the '
        'section rail', (tester) async {
      // `drive the keyboard, not the finder`. The last surface this file
      // covers shipped with Tab going through the rail, and a `ListTile`
      // fires its tap on Enter, so a person tabbing across a row and
      // typing changed SECTION and lost the keystrokes.
      await _pump(
        tester,
        template: _saveable()..ports.add(_port('p1', order: 'a0')),
      );

      await tester.tap(
        find.ancestor(
          of: find.text('p1'),
          matching: find.byType(TextField),
        ),
      );
      await tester.pump();

      final stops = <double>[];
      for (var i = 0; i < 3; i++) {
        final focused = FocusManager.instance.primaryFocus?.context;
        expect(
          focused?.findAncestorWidgetOfExactType<ListTile>(),
          isNull,
          reason: 'the rail is a separate traversal group',
        );
        if (focused != null) {
          stops.add(
            (focused.findRenderObject()! as RenderBox)
                .localToGlobal(Offset.zero)
                .dx,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      expect(
        stops,
        orderedEquals(<double>[...stops]..sort()),
        reason: 'a row is read left to right, so Tab moves right',
      );
    });

    testWidgets('a key typed by hand stays typed across a trip to another '
        'section', (tester) async {
      // THE DEFECT THIS TEST WAS WRITTEN FOR. The touched set lived in
      // the grid's own `State`, and the rail rebuilds the grid, so
      // walking to Physical and back forgot that the author had chosen a
      // key and the label started dragging it again.
      final harness = await _pump(tester, template: _saveable());
      await tester.tap(find.widgetWithText(FilledButton, 'Add port'));
      await tester.pumpAndSettle();

      final column = tester.getTopLeft(find.text('KEY')).dx;
      final fields = find.byType(TextField);
      for (var i = 0; i < tester.widgetList(fields).length; i++) {
        if ((tester.getTopLeft(fields.at(i)).dx - column).abs() < 8) {
          await tester.enterText(fields.at(i), 'mine');
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          break;
        }
      }

      await tester.tap(find.widgetWithText(ListTile, 'Physical'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ports'));
      await tester.pumpAndSettle();

      final labels = find.byType(TextField);
      final labelColumn = tester.getTopLeft(find.text('LABEL')).dx;
      for (var i = 0; i < tester.widgetList(labels).length; i++) {
        if ((tester.getTopLeft(labels.at(i)).dx - labelColumn).abs() < 8) {
          await tester.enterText(labels.at(i), 'HDMI IN 1');
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          break;
        }
      }

      expect((await harness.read(tester)).ports.single.key.v, 'mine');
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

      final aBand = tester.getTopLeft(_inGrid(find.text('a')));
      final bBand = tester.getTopLeft(_inGrid(find.text('b')));
      expect(aBand.dy, lessThan(bBand.dy));
      expect(
        tester.getTopLeft(find.text('A1')).dy,
        lessThan(tester.getTopLeft(find.text('A2')).dy),
      );
    });
  });
}
