// Widget tests for docs/04-rack-editor.md §5's chip strip — roadmap M1
// item #7, "the chip strip (RU, weight, VA, outlets) with unknown counts".
//
// The strip shipped with no tests and with the wrong number on screen: its
// one call site passed `ruFree: 0` with a `TODO(M1)` attached, so a 12U
// rack holding 5U read "12/12U · 0 free". The `wired into
// RackCanvasScreen` group at the bottom is the regression guard for that
// exact figure, driven through the real screen and the real face toggle.
//
// The rest is §5's honesty contract: unknown is `null`, `null` renders
// `—` (never `0`), and every rollup states its unknown count as a
// superscript that expands on hover.

import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final class _FakeMeasurer implements TextMeasurer {
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

RackRollups _rollups({
  Face face = Face.front,
  int ruCapacity = 24,
  int ruUsed = 15,
  int ruUnknownCount = 0,
  Mass? weight = const Mass(67_132_070_760), // 148.00 lb
  int weightUnknown = 0,
  Mass? weightCapacity = const Mass(90_718_474_000), // 200.00 lb
  int? va = 1240,
  int vaUnknown = 0,
  int? outletsUsed = 14,
  int? outletsProvided = 16,
  int outletsUnknown = 0,
  int? outletsConsumedUnknown,
  int? outletsCombinedUnknown,
}) => RackRollups(
  face: face,
  ruCapacity: ruCapacity,
  ruUsed: ruUsed,
  ruUnknownCount: ruUnknownCount,
  weight: Rollup(
    value: weight,
    knownCount: weight == null ? 0 : 1,
    unknownCount: weightUnknown,
  ),
  weightCapacity: weightCapacity,
  apparentVA: Rollup(
    value: va,
    knownCount: va == null ? 0 : 1,
    unknownCount: vaUnknown,
  ),
  outletsConsumed: Rollup(
    value: outletsUsed,
    knownCount: outletsUsed == null ? 0 : 1,
    unknownCount: outletsConsumedUnknown ?? outletsUnknown,
  ),
  outletsProvided: Rollup(
    value: outletsProvided,
    knownCount: outletsProvided == null ? 0 : 1,
    unknownCount: outletsUnknown,
  ),
  // The combined count `computeRackRollups` reports for the ONE chip that
  // renders both rollups. Defaults to the symmetric case every seeded
  // template produces today (provided and consumed silent together), and is
  // overridable so the divergent shape — which no template in this build
  // can author — is still reachable from a test.
  outletsUnknownCount: outletsCombinedUnknown ?? outletsUnknown,
);

Future<void> _pumpStrip(
  WidgetTester tester,
  RackRollups rollups, {
  UnitSystem units = UnitSystem.imperial,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(child: RackMetricsRow(rollups: rollups, units: units)),
    ),
  ),
);

void main() {
  group('RU reads USED over CAPACITY, and names its face', () {
    testWidgets('front', (tester) async {
      await _pumpStrip(tester, _rollups(ruUsed: 5, ruCapacity: 12));
      expect(find.text('RU front 5/12'), findsOneWidget);
    });

    testWidgets('rear — the same rack has a different answer', (tester) async {
      await _pumpStrip(
        tester,
        _rollups(face: Face.rear, ruUsed: 1, ruCapacity: 12),
      );
      expect(find.text('RU rear 1/12'), findsOneWidget);
      expect(find.text('RU front 1/12'), findsNothing);
    });

    testWidgets('an EMPTY rack reads 0/12, not 12/12', (tester) async {
      // The shipped bug in one assertion: the widget used to derive USED
      // from a FREE count it was never given, so `ruFree: 0` printed the
      // rack as completely full.
      await _pumpStrip(tester, _rollups(ruUsed: 0, ruCapacity: 12));
      expect(find.text('RU front 0/12'), findsOneWidget);
      expect(find.text('RU front 12/12'), findsNothing);
    });
  });

  group('unknown renders an em dash, never a zero (G4, CR-114)', () {
    testWidgets('an unknown weight total keeps the capacity and the unit', (
      tester,
    ) async {
      await _pumpStrip(tester, _rollups(weight: null, weightUnknown: 3));
      expect(find.text('—/200 lb'), findsOneWidget);
      expect(find.text('0/200 lb'), findsNothing);
    });

    testWidgets('an unknown VA total still says what it is about', (
      tester,
    ) async {
      await _pumpStrip(tester, _rollups(va: null, vaUnknown: 4));
      expect(find.text('— VA'), findsOneWidget);
      expect(find.text('0 VA'), findsNothing);
    });

    testWidgets('unknown outlets render a dash rather than 0/0', (
      tester,
    ) async {
      await _pumpStrip(
        tester,
        _rollups(outletsUsed: null, outletsProvided: null, outletsUnknown: 2),
      );
      expect(find.text('outlets —'), findsOneWidget);
    });

    testWidgets('a ZERO total is shown as 0 — measured is not unknown', (
      tester,
    ) async {
      // The other half of the rule, and the one the old code got wrong in
      // the opposite direction: it HID any chip whose value was 0, so a
      // rack that genuinely draws nothing looked identical to one nobody
      // has measured.
      await _pumpStrip(tester, _rollups(va: 0));
      expect(find.text('0 VA'), findsOneWidget);
      expect(find.text('— VA'), findsNothing);
    });

    testWidgets('a rack with no stated capacity shows the total alone', (
      tester,
    ) async {
      await _pumpStrip(tester, _rollups(weightCapacity: null));
      expect(find.text('148 lb'), findsOneWidget);
    });
  });

  group('unknown COUNTS (docs/04 §5 superscripts)', () {
    testWidgets('a rollup with nothing unknown shows no superscript', (
      tester,
    ) async {
      await _pumpStrip(tester, _rollups());
      expect(find.textContaining('⁽'), findsNothing);
    });

    testWidgets('one unknown contributor shows ⁽¹⁾ on that rollup only', (
      tester,
    ) async {
      await _pumpStrip(tester, _rollups(weightUnknown: 1));
      expect(find.text('⁽¹⁾'), findsOneWidget);
    });

    testWidgets('multi-digit counts render digit by digit', (tester) async {
      await _pumpStrip(tester, _rollups(weightUnknown: 12));
      expect(find.text('⁽¹²⁾'), findsOneWidget);
    });

    testWidgets('every rollup carries its OWN count', (tester) async {
      await _pumpStrip(
        tester,
        _rollups(
          ruUnknownCount: 1,
          weightUnknown: 3,
          vaUnknown: 4,
          outletsUnknown: 2,
        ),
      );
      expect(find.text('⁽¹⁾'), findsOneWidget);
      expect(find.text('⁽³⁾'), findsOneWidget);
      expect(find.text('⁽⁴⁾'), findsOneWidget);
      expect(find.text('⁽²⁾'), findsOneWidget);
    });

    testWidgets("the superscript expands on hover to §5's sentence", (
      tester,
    ) async {
      await _pumpStrip(tester, _rollups(weight: null, weightUnknown: 3));

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.text('⁽³⁾'), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, contains('Total weight —/200 lb'));
      expect(tooltip.message, contains('3 devices have no weight'));
      expect(tooltip.message, contains('not counted'));
    });

    testWidgets('the singular reads "1 device has", not "1 devices have"', (
      tester,
    ) async {
      await _pumpStrip(tester, _rollups(vaUnknown: 1));
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.text('⁽¹⁾'), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, contains('1 device has no VA figure'));
    });

    testWidgets('a fully known rollup has no tooltip to expand', (
      tester,
    ) async {
      await _pumpStrip(tester, _rollups());
      expect(
        find.ancestor(
          of: find.text('RU front 15/24'),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
    });

    testWidgets('the outlets chip counts CONSUMED silence too, not just '
        'PROVIDED (G4)', (tester) async {
      // THE REGRESSION. `outlets a/b` is derived from BOTH rollups, but the
      // chip took its superscript and its tooltip from
      // `outletsProvided.unknownCount` alone. Feed it the divergent shape
      // `derived/totals.dart` counts separately and
      // test/derived/totals_test.dart already exercises — a PDU that states
      // only `outletsProvided`, an amp that states only `outletsConsumed` —
      // and the chip rendered a complete-looking `outlets 1/24` with no
      // superscript and nothing to hover.
      //
      // NOT reachable from today's data: every seeded template and all four
      // demo templates author both fields or neither, so the two counts
      // always move together. That is exactly why it needs a test.
      await _pumpStrip(
        tester,
        _rollups(
          outletsUsed: 1,
          outletsProvided: 24,
          // `outletsUnknown` is the PROVIDED count and stays at its
          // default 0: every device states how many outlets it provides.
          outletsConsumedUnknown: 2,
          outletsCombinedUnknown: 2,
        ),
      );

      expect(find.text('outlets 1/24'), findsOneWidget);
      expect(
        find.text('⁽²⁾'),
        findsOneWidget,
        reason: 'two devices are missing from the figure the chip displays',
      );
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.text('⁽²⁾'), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, contains('Outlets 1/24'));
      expect(tooltip.message, contains('2 devices have no outlet count'));
    });
  });

  group('formatting', () {
    testWidgets('VA below a thousand stays in VA', (tester) async {
      await _pumpStrip(tester, _rollups(va: 840));
      expect(find.text('840 VA'), findsOneWidget);
    });

    testWidgets("VA at or above a thousand reads as kVA, in §5's own "
        'two-decimal shape', (tester) async {
      await _pumpStrip(tester, _rollups(va: 2500));
      expect(find.text('2.50 kVA'), findsOneWidget);
    });

    testWidgets('outlets read CONSUMED over PROVIDED', (tester) async {
      await _pumpStrip(tester, _rollups(outletsUsed: 3, outletsProvided: 8));
      expect(find.text('outlets 3/8'), findsOneWidget);
    });

    testWidgets('metric display units switch the weight chip to kg '
        '(CR-097: the project setting is authoritative)', (tester) async {
      await _pumpStrip(tester, _rollups(), units: UnitSystem.metric);
      expect(find.text('67.1/90.7 kg'), findsOneWidget);
      expect(find.text('148/200 lb'), findsNothing);
    });

    testWidgets('imperial is the pound form', (tester) async {
      await _pumpStrip(tester, _rollups());
      expect(find.text('148/200 lb'), findsOneWidget);
    });

    testWidgets("the strip is §5's 20 px — the LITERAL 20, not whatever "
        'stripHeight happens to say', (tester) async {
      // This used to read `expect(getSize(...).height,
      // RackMetricsRow.stripHeight)`, and `stripHeight` is the constant that
      // feeds the widget's own `SizedBox(height: stripHeight)`. Both sides
      // resolved to the same symbol, so 40, 0 and 200 all passed and the
      // number in the test's title was never asserted anywhere. docs/04 §5
      // says 20 px; 20 is what a test may say.
      expect(RackMetricsRow.stripHeight, 20);
      await _pumpStrip(tester, _rollups());
      expect(tester.getSize(find.byType(RackMetricsRow)).height, 20);
    });
  });

  group('wired into RackCanvasScreen (the regression this fixes)', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
          .implicitView!
        ..physicalSize = const Size(1600, 1000)
        ..devicePixelRatio = 1;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
          .implicitView!
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    Widget app() => MaterialApp(
      home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
    );

    testWidgets('the demo rack reads 5/12 on the front, not 12/12', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump();

      // UPS-1 (2U @U1) + AMP-1 (2U @U4) + SW-1 (1U @U7) = 5 U of 12.
      expect(find.text('RU front 5/12'), findsOneWidget);
      expect(find.text('12/12U'), findsNothing);
      expect(find.text('0 free'), findsNothing);
    });

    testWidgets('flipping to the REAR elevation re-reads the strip', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump();

      await tester.tap(find.text('Rear'));
      await tester.pumpAndSettle();

      // PP-1 is a rear-only 1U patch panel at U9.
      expect(find.text('RU rear 1/12'), findsOneWidget);
      expect(find.text('RU front 5/12'), findsNothing);
    });

    testWidgets('placing a device from the palette moves the number', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('RU front 5/12'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Blank Panel');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, 'Blank Panel, 1U');
      await tester.tap(row);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(
        find.text('RU front 6/12'),
        findsOneWidget,
        reason: 'a 1U blank panel landed in the lowest free U',
      );
    });

    testWidgets('the demo rack states its unknowns rather than showing 0', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump();

      // None of the four demo templates authors a weight, a VA figure OR
      // an outlet count. The outlet chip used to be excluded from this
      // assertion because `PowerProfile.outletsProvided`/`outletsConsumed`
      // were non-nullable ints defaulting to 0, so the strip rendered a
      // confident `outlets 0/0` with no superscript on the app's own
      // default document — the one fabricated zero still on screen in the
      // widget whose whole job is to refuse them. Three chips, three
      // superscripts.
      expect(find.text('— lb'), findsOneWidget);
      expect(find.text('— VA'), findsOneWidget);
      expect(find.text('outlets —'), findsOneWidget);
      expect(find.text('⁽⁴⁾'), findsNWidgets(3));
    });

    testWidgets('the strip does NOT sit over the bottom of the canvas', (
      tester,
    ) async {
      // It shipped as an opaque 36px `Positioned.fill` + `Align.
      // bottomCenter` bar, absorbing every pointer event aimed at the
      // lowest RUs. docs/04 §5 puts it in the rack HEADER.
      await tester.pumpWidget(app());
      await tester.pump();

      final strip = tester.getRect(find.byType(RackMetricsRow));
      final canvas = tester.getRect(find.byType(CanvasIntentDetector));
      final header = tester.getRect(find.byType(RackHeaderBar));

      expect(
        strip.top,
        greaterThanOrEqualTo(header.top),
        reason: 'the strip belongs under the rack header',
      );
      expect(strip.top - header.bottom, lessThan(12));
      expect(
        strip.bottom,
        lessThan(canvas.bottom - 100),
        reason: 'nowhere near the bottom rails',
      );
    });

    testWidgets('a pointer at the very bottom of the canvas still reaches '
        'the canvas', (tester) async {
      // The functional half of the test above. No existing test drives a
      // gesture at the bottom edge, so the opaque bar swallowing clicks
      // there went unnoticed; this fails if anything opaque returns.
      await tester.pumpWidget(app());
      await tester.pump();

      final canvas = tester.getRect(find.byType(CanvasIntentDetector));
      final amp = tester.getCenter(
        find.descendant(
          of: find.byKey(const ValueKey('dev-amp')),
          matching: find.byType(DeviceBox),
        ),
      );

      await tester.tapAt(amp);
      await tester.pump();
      bool ampSelected() => tester.allRenderObjects
          .whereType<RenderDeviceBox>()
          .firstWhere((r) => r.deviceId == 'dev-amp')
          .selected;
      expect(ampSelected(), isTrue);

      // 6px above the canvas's bottom edge — inside the band the old
      // 36px metrics bar covered.
      await tester.tapAt(Offset(canvas.center.dx, canvas.bottom - 6));
      await tester.pump();
      expect(
        ampSelected(),
        isFalse,
        reason: 'the click reached the canvas and cleared the selection',
      );
    });
  });
}
