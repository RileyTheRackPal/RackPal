// The ACCEPTS cell, the port grid's only multi-select (DR-081 §11.80.2,
// built at DR-134 §11.133).
//
// ═════════════════════════════════════════════════════════════════════
// DRIVEN THROUGH THE SCREEN, AND ANCHORED ON THE COLUMN HEADER
// ═════════════════════════════════════════════════════════════════════
// `byType().first` in a grid finds whichever cell the tree happened to
// build first and passes while pointing at the wrong column. Every
// assertion below locates its cell by the x of the `ACCEPTS` header,
// which is the same discipline the PINOUT cases in `port_grid_test.dart`
// use and the same one `a finder that cannot say which one` was written
// after.
//
// THE HARNESS CARRIES ITS OWN REGISTRIES, with two DOMAINS. The shared
// one in `port_grid_test.dart` declares families and no domains at all,
// and `signalFamilyCellGroups` drops a family whose domain is missing
// because it has no tag to file it under. A menu built from that registry
// would be empty, and every case here would pass by finding nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';
// The cell classes are internal to the builder; `pin_selection_test.dart`
// reaches into `src/` the same way for the same reason.
import 'package:rackpal_ui/src/builder/port_cells.dart';

final class _Measurer implements TextMeasurer {
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

/// A domain with the eight fields CR-078 requires. The colours are not
/// under test here and are distinct only so nothing reads as a clash.
SignalDomainDef _domain(String id, String name, String tag) => SignalDomainDef(
  id: SignalDomainId(id),
  displayName: name,
  tagPrefix: tag,
  color: Rgb(tag.codeUnitAt(0), 0x40, 0x80),
  colorDark: Rgb(tag.codeUnitAt(0), 0x80, 0xc0),
  dashPattern: const [],
  lineWeightPermille: 1000,
  glyph: tag.substring(0, 1),
  glyphAlt: tag.substring(0, 1),
);

const _ethernet = SignalFamilyId('net.ethernet');
const _irEmitter = SignalFamilyId('ctl.ir_emitter');

Registries _registries() => Registries(
  connectorTypes: {
    const ConnectorTypeId('conn.rj45'): const ConnectorTypeDef(
      id: ConnectorTypeId('conn.rj45'),
      displayName: 'RJ45',
    ),
  },
  signalDomains: {
    const SignalDomainId('net'): _domain('net', 'Network', 'NET'),
    const SignalDomainId('ctl'): _domain('ctl', 'Control', 'CTL'),
  },
  signalFamilies: {
    _ethernet: const SignalFamilyDef(
      id: _ethernet,
      displayName: 'Ethernet',
      domain: SignalDomainId('net'),
      defaultConnector: ConnectorTypeId('conn.rj45'),
      defaultDirection: PortDirection.bidirectional,
      defaultTopology: PortTopology.p2p,
    ),
    _irEmitter: const SignalFamilyDef(
      id: _irEmitter,
      displayName: 'IR emitter',
      domain: SignalDomainId('ctl'),
      defaultConnector: ConnectorTypeId('conn.rj45'),
      defaultDirection: PortDirection.source,
      defaultTopology: PortTopology.p2p,
    ),
  },
);

PortDef _port(String key, String order) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: _ethernet,
  face: Face.rear,
  order: FracIndex(order),
  direction: PortDirection.sink,
);

TemplateBody _template(List<PortDef> ports) =>
    TemplateBody(manufacturer: 'Generic', model: '', displayName: 'Matrix')
      ..typePrefix = 'MTX'
      ..frontU = 2
      ..ports.addAll(ports);

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

Future<_Harness> _pump(WidgetTester tester, TemplateBody template) async {
  final harness = _Harness();
  // WIDER THAN `port_grid_test.dart`'s 1740, and deliberately so. ACCEPTS
  // is the last column of the Advanced pack, which puts it past x=2800 on
  // a real window; a tap there reports `would not hit test` rather than
  // failing on what the case is about. The alternative is scrolling the
  // grid in every case, which tests the scroll view. Layout at a real
  // width is `builder_narrow_window_test.dart`'s subject and not this
  // file's.
  tester.view.physicalSize = const Size(3200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          measurer: _Measurer(),
          template: template,
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
  // THE RAIL OPENS ON THE SECTION LIST, not on Ports. Without this the
  // gear button is not on screen at all and every case below fails on
  // `Columns` rather than on what it is about.
  await tester.tap(find.widgetWithText(ListTile, 'Ports'));
  await tester.pumpAndSettle();
  return harness;
}

/// Opens the Advanced pack, which is where the column lives.
Future<void> _openAdvanced(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Columns'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Advanced'));
  await tester.pumpAndSettle();
}

/// One family's row INSIDE the open menu.
///
/// **KEYED, BECAUSE THE LABEL IS ON SCREEN TWICE.** Once the port accepts
/// a family, the cell prints its label as the summary AND the open menu
/// prints it beside a checkbox, so `find.text` is ambiguous and its
/// failure is a two-widget error rather than a wrong answer. It could as
/// easily have been a wrong answer: that is what the row key exists for.
Finder _menuRow(SignalFamilyId id) => find.byKey(ValueKey('accepts-${id.v}'));

/// The ACCEPTS cell on the only row, found by the header's x.
Finder _acceptsCell(WidgetTester tester) {
  final header = tester.getTopLeft(find.text('ACCEPTS')).dx;
  final cells = find.byType(PortAcceptsCell);
  for (var i = 0; i < tester.widgetList(cells).length; i++) {
    if ((tester.getTopLeft(cells.at(i)).dx - header).abs() < 24) {
      return cells.at(i);
    }
  }
  fail('no PortAcceptsCell under the ACCEPTS header');
}

void main() {
  group('the column reaches the grid at all', () {
    testWidgets('ACCEPTS is in the Advanced pack and is closed by default', (
      tester,
    ) async {
      await _pump(tester, _template([_port('p1', 'a0')]));
      expect(
        find.text('ACCEPTS'),
        findsNothing,
        reason: 'a pack column is hidden until the gear opens its pack',
      );
      await _openAdvanced(tester);
      expect(find.text('ACCEPTS'), findsOneWidget);
      expect(find.byType(PortAcceptsCell), findsOneWidget);
    });

    testWidgets('an untouched port reads own family only, not the dash', (
      tester,
    ) async {
      await _pump(tester, _template([_port('p1', 'a0')]));
      await _openAdvanced(tester);
      expect(find.text(kAcceptsOwnFamilyOnly), findsOneWidget);
      expect(
        find.descendant(
          of: _acceptsCell(tester),
          matching: find.text('—'),
        ),
        findsNothing,
        reason: 'G4 spends the dash on unknown and this is a statement',
      );
    });
  });

  group('ticking a family reaches the document', () {
    testWidgets('one tick lands on the port, through Save', (tester) async {
      final harness = await _pump(tester, _template([_port('p1', 'a0')]));
      await _openAdvanced(tester);

      await tester.tap(_acceptsCell(tester));
      await tester.pumpAndSettle();
      await tester.tap(_menuRow(_irEmitter));
      await tester.pumpAndSettle();

      final saved = await harness.read(tester);
      expect(saved.ports.single.acceptedFamilies, const [_irEmitter]);
    });

    testWidgets('THE MENU STAYS OPEN, so a second family costs one trip', (
      tester,
    ) async {
      // The behaviour this control exists for and the one a
      // `MenuItemButton` would have removed. Every other cell in the grid
      // commits and closes; a set is built by ticking more than once.
      final harness = await _pump(tester, _template([_port('p1', 'a0')]));
      await _openAdvanced(tester);

      await tester.tap(_acceptsCell(tester));
      await tester.pumpAndSettle();
      await tester.tap(_menuRow(_irEmitter));
      await tester.pumpAndSettle();

      expect(
        _menuRow(_ethernet),
        findsOneWidget,
        reason: 'the menu closed on the first pick',
      );
      await tester.tap(_menuRow(_ethernet));
      await tester.pumpAndSettle();

      final saved = await harness.read(tester);
      expect(saved.ports.single.acceptedFamilies, hasLength(2));
    });

    testWidgets('ticking the same family again takes it off', (tester) async {
      final harness = await _pump(
        tester,
        _template([_port('p1', 'a0')..acceptedFamilies.add(_irEmitter)]),
      );
      await _openAdvanced(tester);

      await tester.tap(_acceptsCell(tester));
      await tester.pumpAndSettle();
      await tester.tap(_menuRow(_irEmitter));
      await tester.pumpAndSettle();

      final saved = await harness.read(tester);
      expect(saved.ports.single.acceptedFamilies, isEmpty);
    });

    testWidgets('the cell then prints the family rather than the sentence', (
      tester,
    ) async {
      await _pump(
        tester,
        _template([_port('p1', 'a0')..acceptedFamilies.add(_irEmitter)]),
      );
      await _openAdvanced(tester);
      expect(find.text(kAcceptsOwnFamilyOnly), findsNothing);
      expect(
        find.descendant(
          of: _acceptsCell(tester),
          matching: find.text('CTL·IR emitter'),
        ),
        findsOneWidget,
      );
    });
  });

  group('the filter narrows and never commits', () {
    testWidgets('typing hides the rows it does not match', (tester) async {
      await _pump(tester, _template([_port('p1', 'a0')]));
      await _openAdvanced(tester);
      await tester.tap(_acceptsCell(tester));
      await tester.pumpAndSettle();

      expect(_menuRow(_ethernet), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'emitter');
      await tester.pumpAndSettle();

      expect(_menuRow(_irEmitter), findsOneWidget);
      expect(_menuRow(_ethernet), findsNothing);
    });

    testWidgets('a filter matching nothing NAMES THE RULE and picks nothing', (
      tester,
    ) async {
      // DR-025 §11.24.3 one control over: a family cannot be minted from
      // a typed token, so the empty state says so rather than listing 57
      // alternatives a person would scroll past.
      final harness = await _pump(tester, _template([_port('p1', 'a0')]));
      await _openAdvanced(tester);
      await tester.tap(_acceptsCell(tester));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'nonsense');
      await tester.pumpAndSettle();
      expect(find.text(familyFilterEmpty('nonsense')), findsOneWidget);

      final saved = await harness.read(tester);
      expect(
        saved.ports.single.acceptedFamilies,
        isEmpty,
        reason: 'a filter narrows a list; it does not choose from it',
      );
    });
  });
}
