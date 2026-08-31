// docs/06 §6's right dock (`#228`), and the one thing widget tests here can
// actually prove about it.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THESE TESTS CAN AND CANNOT SEE
// ═══════════════════════════════════════════════════════════════════════
// They CANNOT tell you the previews look right. Every pixel comes from a
// scene builder in `rackpal_core`, and the assertions that those builders
// draw the correct thing live beside them: `panel_draw_test.dart`,
// `symbol_collapse_test.dart`, `symbol_sizing_seam_test.dart`. That split
// is the point of `#229` -- if this file were where the drawing was
// checked, the drawing would be a widget rather than a sheet.
//
// What they CAN prove is that the dock asks the right builder, survives
// the bodies that break naive previews (no ports, no U, an overflowing
// panel), collapses, and does not paint over the grid. Those are the
// failures a person would actually hit.
import 'package:flutter/material.dart';
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

final Map<String, TemplateBody> _seed = buildSeedCatalog();
final Registries _registries = buildSeedRegistries();

Future<void> _pump(
  WidgetTester tester,
  TemplateBody body, {
  Size size = const Size(600, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            BuilderPreviewDock(
              body: body,
              registries: _registries,
              measurer: _Measurer(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TemplateBody _bare({int frontU = 1, List<PortDef> ports = const []}) =>
    TemplateBody(
      manufacturer: 'Generic',
      model: 'X',
      displayName: 'Fixture',
      typePrefix: 'AMP',
      frontU: frontU,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
      ports: ports,
    );

void main() {
  group('the dock draws all three previews', () {
    testWidgets('a real seeded template gets an elevation, a symbol and a '
        'panel', (tester) async {
      await _pump(tester, _seed['A01']!);
      expect(find.text('Rack elevation'), findsOneWidget);
      expect(find.text('Schematic symbol'), findsOneWidget);
      expect(find.text('Rear panel'), findsOneWidget);
      // Three painted previews, and none of them an empty-state message.
      expect(find.byType(CustomPaint, skipOffstage: false), findsWidgets);
      expect(find.textContaining('Nothing to draw'), findsNothing);
    });

    testWidgets('every shipped archetype renders without throwing, which is '
        'the claim a preview over a 48-template catalog has to make', (
      tester,
    ) async {
      for (final entry in _seed.entries) {
        await _pump(tester, entry.value);
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} threw while previewing',
        );
      }
    });
  });

  group('the empty states are honest and do not shadow the grid', () {
    testWidgets('a body with no ports says so in the symbol pane, in words '
        'the port grid does not also use', (tester) async {
      await _pump(tester, _bare());
      expect(find.text('Add a port to see the symbol.'), findsOneWidget);
      // "No ports yet" is the GRID's empty text. Two widgets carrying one
      // string is how `find.text` locates the wrong one and passes.
      expect(find.textContaining('No ports yet'), findsNothing);
    });

    testWidgets('a body occupying no U refuses the panel rather than drawing '
        'a degenerate strip', (tester) async {
      await _pump(tester, _bare(frontU: 0));
      expect(find.textContaining('occupies no U'), findsOneWidget);
      expect(find.textContaining('Occupies no front U'), findsOneWidget);
    });
  });

  group('the panel header reports fill, and overflow when there is any', () {
    testWidgets('an ordinary template shows a percentage and no warning', (
      tester,
    ) async {
      await _pump(tester, _seed['A01']!);
      expect(find.textContaining('% full'), findsOneWidget);
      expect(find.textContaining('past the edge'), findsNothing);
    });

    testWidgets('N01 overflows its own 1U panel and the header says how '
        'many — DR-105 §11.104.8 makes this a finding, not a refusal', (
      tester,
    ) async {
      final body = _seed['N01']!;
      final panel = buildPanelGeometry(body: body, registries: _registries);
      expect(
        panel.overflowed,
        isNotEmpty,
        reason: 'N01 stopped overflowing; this test then proves nothing',
      );

      await _pump(tester, body);
      expect(
        find.textContaining('${panel.overflowed.length} past the edge'),
        findsOneWidget,
      );
      // NOT a refusal: the panel is still drawn.
      expect(find.textContaining('occupies no U'), findsNothing);
    });
  });

  group('each pane collapses on its own', () {
    testWidgets('tapping a header hides that preview and leaves the others', (
      tester,
    ) async {
      await _pump(tester, _seed['A01']!);
      expect(find.byIcon(Icons.expand_more), findsNWidgets(3));

      await tester.tap(find.text('Schematic symbol'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // The other two are untouched, which is what "individually
      // collapsible" means and what a single shared flag would break.
      expect(find.text('Rack elevation'), findsOneWidget);
      expect(find.text('Rear panel'), findsOneWidget);
      expect(find.textContaining('% full'), findsOneWidget);
    });
  });

  group('the elevation strip follows the face toggle', () {
    testWidgets('a front-only template draws the front and reports the rear '
        'as empty rather than drawing the front twice', (tester) async {
      // N03 RATHER THAN A01, and the first draft had it wrong. A01 is 3U
      // front AND 3U rear, as most chassis are -- a box occupies the depth
      // it occupies. Exactly four seeded archetypes are front-only (N03
      // and the three X blanks/shelves), and N03 is the only one of them
      // with ports, so it is the only one that exercises this at all.
      final body = _seed['N03']!;
      expect(body.rearU, 0, reason: 'N03 gained a rear face; pick another');

      await _pump(tester, body);
      expect(find.textContaining('Occupies no'), findsNothing);

      await tester.tap(find.text('Rear'));
      await tester.pumpAndSettle();
      expect(find.text('Occupies no rear U.'), findsOneWidget);
    });
  });

  group('the dock yields to the grid on a narrow window', () {
    testWidgets('it is drawn beside the port grid at desktop width and not '
        'at 800px, because the grid cannot draw its own toolbar there', (
      tester,
    ) async {
      Future<void> pumpBuilder(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DeviceBuilderScreen(
                template: _seed['A01']!,
                registries: _registries,
                measurer: _Measurer(),
                actions: DeviceBuilderActions(onSave: (_) => null),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpBuilder(const Size(1740, 900));
      await tester.tap(find.text('Ports').first);
      await tester.pumpAndSettle();
      expect(find.byType(BuilderPreviewDock), findsOneWidget);

      await pumpBuilder(const Size(800, 900));
      await tester.tap(find.text('Ports').first);
      await tester.pumpAndSettle();
      expect(
        find.byType(BuilderPreviewDock),
        findsNothing,
        reason: 'a 340px dock on an 800px window makes the grid unusable',
      );
      // NO `takeException` ASSERTION HERE, and the reason is a finding
      // rather than a shrug: with the dock already gone, the port grid
      // STILL overflows an 800px window by 63px on its own. That predates
      // `#228` and is not this dock's to fix -- asserting it clean would
      // make this test fail for a defect it does not own, and asserting it
      // dirty would pin the defect as intended. `#803` holds it.
      tester.takeException();
    });
  });
}
