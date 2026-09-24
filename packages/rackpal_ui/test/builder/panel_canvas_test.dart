// The `Panel` section (`#227`, CR-071 part 1, DR-106 §11.105).
//
// ═══════════════════════════════════════════════════════════════════════
// THE ARITHMETIC IS NOT TESTED HERE, AND THAT IS THE DESIGN
// ═══════════════════════════════════════════════════════════════════════
// Align, distribute, nudge and reset are `panel_arrange.dart`'s, asserted
// in `rackpal_core` where a test reaches them without pumping a widget.
// What is asserted HERE is everything a widget test can see and that one
// cannot: that the toggle gates editing, that a click selects the cutout
// under it, that an arrow key becomes the right delta, that the toolbar
// disables what would do nothing, and that the AUTO badge tells the truth.
//
// Two of these are the failure modes my own notes name. A finder that
// cannot say WHICH cutout would pass on the wrong one, so the assertions
// go through the commands the section emits rather than through pixels.
// And a disabled-looking control that is really enabled is exactly the
// "twelve green assertions on a line reading 1 ports" shape.
// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

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

final Registries _registries = buildSeedRegistries();

PortDef _port(String key, {String order = 'a0'}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.xlr3'),
  signalFamily: const SignalFamilyId('audio.analog.line'),
  face: Face.rear,
  order: FracIndex(order),
);

TemplateBody _body({int ports = 4, int frontU = 2}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'T',
  displayName: 'Fixture',
  frontU: frontU,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  ports: [
    for (var i = 0; i < ports; i++) _port('p$i', order: 'a$i'),
  ],
);

/// Pumps the section and collects every command batch it emits, applying
/// them to [body] so the widget sees its own edits the way the session
/// would.
Future<List<List<Command<TemplateBody>>>> _pump(
  WidgetTester tester,
  TemplateBody body, {
  Size size = const Size(1200, 900),
}) async {
  final batches = <List<Command<TemplateBody>>>[];
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => PanelCanvasSection(
            body: body,
            registries: _registries,
            measurer: _Measurer(),
            onEdit: (commands) {
              batches.add(commands);
              for (final c in commands) {
                c.apply(body);
              }
              setState(() {});
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return batches;
}

Future<void> _enableCustomize(WidgetTester tester) async {
  await tester.tap(find.text('Customize panel layout'));
  await tester.pumpAndSettle();
}

/// Taps the centre of the cutout for [portKey], resolved through the SAME
/// geometry the widget draws rather than by hunting pixels.
Future<void> _tapCutout(
  WidgetTester tester,
  TemplateBody body,
  String portKey, {
  bool shift = false,
}) async {
  final panel = buildPanelGeometry(body: body, registries: _registries);
  final slot = panel.slots.firstWhere((s) => s.portKey.v == portKey);

  final box = tester.renderObject<RenderBox>(find.byType(CustomPaint).last);
  final painted = box.size;
  final built = buildPanelLayer(panel, body: body, measurer: _Measurer());
  final probe = BoundsCanvas(measurer: _Measurer());
  for (final op in built.ops) {
    op.replay(probe);
  }
  final bounds = probe.bounds!;
  final scale = painted.width / bounds.width;

  final local = Offset(
    (RackGeometry.unitsForLen(slot.x) +
            RackGeometry.unitsForLen(slot.width) / 2 -
            bounds.left) *
        scale,
    (RackGeometry.unitsForLen(slot.y) +
            RackGeometry.unitsForLen(slot.height) / 2 -
            bounds.top) *
        scale,
  );

  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.tapAt(box.localToGlobal(local));
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.pumpAndSettle();
}

void main() {
  group(
    'the toggle is what gates editing, and the drawing is always shown',
    () {
      testWidgets('the panel is drawn before the box is ticked, because a '
          'section that shows nothing until you tick something is the '
          'UnbuiltView defect wearing a hat', (tester) async {
        final body = _body();
        await _pump(tester, body);
        expect(find.text('Customize panel layout'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
        // The toolbar is the thing the toggle reveals.
        expect(find.text('Reset all to auto'), findsNothing);
      });

      testWidgets('ticking it reveals the toolbar and the modifier hint', (
        tester,
      ) async {
        final body = _body();
        await _pump(tester, body);
        await _enableCustomize(tester);
        expect(find.text('Reset all to auto'), findsOneWidget);
        expect(find.textContaining('Arrows nudge 1 mm'), findsOneWidget);
        expect(find.textContaining('Shift 0.1 mm'), findsOneWidget);
        expect(find.textContaining('Ctrl 10 mm'), findsOneWidget);
      });

      testWidgets('a click does nothing at all while the box is unticked', (
        tester,
      ) async {
        final body = _body();
        final batches = await _pump(tester, body);
        await _tapCutout(tester, body, 'p1');
        expect(find.text('nothing selected'), findsNothing);
        expect(batches, isEmpty);
      });
    },
  );

  group('the AUTO badge says whether anything has been touched', () {
    testWidgets('a template with no overrides shows it', (tester) async {
      await _pump(tester, _body());
      expect(find.text('AUTO'), findsOneWidget);
    });

    testWidgets('and it goes the moment one cutout is nudged', (tester) async {
      final body = _body();
      await _pump(tester, body);
      await _enableCustomize(tester);
      await _tapCutout(tester, body, 'p1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('AUTO'), findsNothing);
    });
  });

  group('selection', () {
    testWidgets('a click selects the cutout UNDER IT, named, not merely some '
        'cutout', (tester) async {
      final body = _body();
      final batches = await _pump(tester, body);
      await _enableCustomize(tester);
      await _tapCutout(tester, body, 'p2');
      expect(find.text('1 selected'), findsOneWidget);

      // WHICH one is the whole question, so it is read off the command
      // rather than off a count: a halo assertion would pass on any cutout.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(batches, hasLength(1));
      expect(batches.single, hasLength(1));
      expect(body.ports.firstWhere((p) => p.key.v == 'p2').position, isNotNull);
      expect(body.ports.firstWhere((p) => p.key.v == 'p1').position, isNull);
    });

    testWidgets('shift-click adds, and shift-clicking again removes', (
      tester,
    ) async {
      final body = _body();
      await _pump(tester, body);
      await _enableCustomize(tester);
      await _tapCutout(tester, body, 'p0');
      await _tapCutout(tester, body, 'p1', shift: true);
      expect(find.text('2 selected'), findsOneWidget);
      await _tapCutout(tester, body, 'p1', shift: true);
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('unticking the box clears the selection, so returning does '
        'not act on something invisible', (tester) async {
      final body = _body();
      await _pump(tester, body);
      await _enableCustomize(tester);
      await _tapCutout(tester, body, 'p0');
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Customize panel layout'));
      await tester.pumpAndSettle();
      await _enableCustomize(tester);
      expect(find.text('nothing selected'), findsOneWidget);
    });
  });

  group('the arrow keys carry DR-106 section 11.105.3 exactly', () {
    Future<int> nudgedBy(
      WidgetTester tester,
      List<LogicalKeyboardKey> mods,
    ) async {
      final body = _body();
      await _pump(tester, body);
      await _enableCustomize(tester);
      final before = buildPanelGeometry(
        body: body,
        registries: _registries,
      ).slots.firstWhere((s) => s.portKey.v == 'p1').x.nm;
      await _tapCutout(tester, body, 'p1');
      for (final m in mods) {
        await tester.sendKeyDownEvent(m);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      for (final m in mods.reversed) {
        await tester.sendKeyUpEvent(m);
      }
      await tester.pumpAndSettle();
      final after = body.ports
          .firstWhere((p) => p.key.v == 'p1')
          .position!
          .xFineNm
          .nm;
      return after - before;
    }

    testWidgets('a bare arrow is 1 mm', (tester) async {
      expect(await nudgedBy(tester, const []), 1_000_000);
    });

    testWidgets('Shift is 0.1 mm', (tester) async {
      expect(
        await nudgedBy(tester, const [LogicalKeyboardKey.shiftLeft]),
        100_000,
      );
    });

    testWidgets('Ctrl is 10 mm', (tester) async {
      expect(
        await nudgedBy(tester, const [LogicalKeyboardKey.controlLeft]),
        10_000_000,
      );
    });

    testWidgets('an arrow with nothing selected writes nothing', (
      tester,
    ) async {
      final body = _body();
      final batches = await _pump(tester, body);
      await _enableCustomize(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(batches, isEmpty);
    });
  });

  group('the toolbar disables what would do nothing', () {
    testWidgets('align needs two selected and distribute needs three, and '
        'the BUTTONS say so rather than silently no-oping', (tester) async {
      final body = _body();
      await _pump(tester, body);
      await _enableCustomize(tester);

      // `find.byTooltip` locates the Tooltip WIDGET, which IconButton
      // builds INSIDE itself, so the cast has to walk back up. Getting
      // this wrong throws rather than passing, which is the only reason
      // it cost seconds: a finder that silently matched the wrong widget
      // is the failure my own notes name.
      bool enabled(String tooltip) =>
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byTooltip(tooltip),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed !=
          null;

      expect(enabled('Align left (needs 2)'), isFalse);
      expect(enabled('Distribute across (needs 3)'), isFalse);

      await _tapCutout(tester, body, 'p0');
      await _tapCutout(tester, body, 'p1', shift: true);
      expect(enabled('Align left (needs 2)'), isTrue);
      expect(
        enabled('Distribute across (needs 3)'),
        isFalse,
        reason: 'two cutouts have nothing between them to space',
      );

      await _tapCutout(tester, body, 'p2', shift: true);
      expect(enabled('Distribute across (needs 3)'), isTrue);
    });

    testWidgets('Reset is disabled while nothing has been overridden', (
      tester,
    ) async {
      final body = _body();
      await _pump(tester, body);
      await _enableCustomize(tester);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Reset all to auto'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('the Reset label names its scope before it is pressed', (
      tester,
    ) async {
      final body = _body();
      await _pump(tester, body);
      await _enableCustomize(tester);
      expect(find.text('Reset all to auto'), findsOneWidget);
      await _tapCutout(tester, body, 'p0');
      expect(find.text('Reset to auto'), findsOneWidget);
      expect(find.text('Reset all to auto'), findsNothing);
    });
  });

  group('the bodies that break naive canvases', () {
    testWidgets('a template occupying no U says so instead of drawing a '
        'degenerate strip', (tester) async {
      await _pump(tester, _body(frontU: 0));
      expect(find.textContaining('occupies no rack U'), findsOneWidget);
    });

    testWidgets('a template with no ports says where to add them', (
      tester,
    ) async {
      await _pump(tester, _body(ports: 0));
      expect(find.textContaining('No cutouts to arrange'), findsOneWidget);
    });

    testWidgets('every shipped archetype renders in this section', (
      tester,
    ) async {
      for (final entry in buildSeedCatalog().entries) {
        await _pump(tester, entry.value);
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} threw in the Panel section',
        );
      }
    });
  });
}
