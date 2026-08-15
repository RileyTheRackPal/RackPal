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

  group('the keyboard, which is how this grid is actually used', () {
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
