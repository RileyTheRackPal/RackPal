// docs/04-rack-editor.md §5's chip strip has to FIT, at the window sizes
// this editor is actually used at.
//
// THE REGRESSION THIS PINS. The strip is laid out in the top-centre of the
// CANVAS COLUMN, and that column is `windowWidth - 280 (palette) - 320
// (inspector) - 2 (dividers)` — 422 px on a 1024x768 window, 550 px on
// 1152x720. Four always-present chips in an unbounded `Row` need more than
// that, so the strip reported `A RenderFlex overflowed by 150 pixels on the
// right` at 1024x768 and by 22 px at 1152x720. In a release build there is
// no red banner and no exception: the overflow is SILENT CLIPPING, and what
// gets clipped is the right-hand end of the strip — the VA and outlet
// numbers the widget exists to surface.
//
// WHY IT WENT UNNOTICED, and why this file sets its own sizes. Every test
// that pumps the shell or the canvas screen pins `physicalSize` to
// 1600x1000 (`rack_canvas_screen_test.dart`, `rack_metrics_row_test.dart`,
// `staging_bin_overlay_test.dart`, `widget_test.dart`, `shell_tabs_test.
// dart`), which is the one size at which the old strip fitted. A layout
// defect that only appears below 1150 px cannot be caught by a suite that
// only ever renders at 1600.
//
// HOW THIS FILE IS BUILT SO IT CAN GENUINELY FAIL. Two independent
// detectors, each with a CONTROL that proves the detector is capable of
// firing:
//
//   1. THE FRAMEWORK'S OWN OVERFLOW REPORT, via `tester.takeException()`.
//      `the detector sees a real overflow` pumps a deliberately
//      overconstrained `Row` and asserts the exception IS reported, so a
//      green run of the real assertions means "no overflow", not "this
//      harness cannot see one".
//   2. GEOMETRIC CONTAINMENT of every chip inside the strip, and of the
//      strip inside the canvas column. This is the one that still fails if
//      the strip stops reporting an overflow but starts losing a chip some
//      other way — a `ClipRect`, an `OverflowBox`, a chip pushed off the
//      end. `the detector sees a chip painted outside its box` is its
//      control, over the same helper.
//
// Both run at BOTH failing sizes, and at 1280x720 (which never failed) so a
// fix that only works when the strip is being squeezed is caught too.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'session/session_fakes.dart';

/// The four chips the demo document puts on the strip. `RU front 5/12` is
/// the only rollup any demo template authors; the other three are honestly
/// unknown, which is what they render (docs/04 §5, G4).
const _demoChips = <String>['RU front 5/12', '— lb', '— VA', 'outlets —'];

/// Sizes the editor is used at. The first two are the reported failures;
/// the third passed before this fix and must keep passing.
const _sizes = <Size>[Size(1024, 768), Size(1152, 720), Size(1280, 720)];

/// How far outside [outer] any part of [inner] is painted, in logical
/// pixels — 0 when `inner` is fully contained. Compares PAINTED rects
/// (`getRect` resolves the full paint transform, so a scaled subtree is
/// measured at the size it actually appears), which is what makes this
/// catch a clipped chip as well as an overflowing one.
double _escape(Rect inner, Rect outer) {
  final left = outer.left - inner.left;
  final right = inner.right - outer.right;
  final top = outer.top - inner.top;
  final bottom = inner.bottom - outer.bottom;
  final worst = [
    left,
    right,
    top,
    bottom,
  ].reduce((a, b) => a > b ? a : b);
  return worst > 0 ? worst : 0;
}

/// Every piece of TEXT under [container] that is painted outside it,
/// described for the failure message. Sub-pixel slack only: half a pixel is
/// antialiasing, twenty is a number nobody can read.
///
/// EVERY paragraph, not a hand-listed set of chip strings, and that is not
/// tidiness. The first version of this checked the four chip texts by name
/// and passed at 1152x720 against the very build that overflows there — the
/// 22 px that fell off the end was the outlet chip's `⁽⁴⁾` unknown-count
/// superscript, which is a sibling `Text`, not part of the chip string. A
/// superscript silently clipped off is exactly the failure docs/04 §5's
/// unknown counts exist to prevent, so the measurement covers every glyph
/// the strip paints.
List<String> _escapedText(WidgetTester tester, Finder container) {
  final box = tester.getRect(container);
  final out = <String>[];
  final paragraphs = find
      .descendant(of: container, matching: find.byType(RichText))
      .evaluate();
  for (final element in paragraphs) {
    final label = (element.widget as RichText).text.toPlainText();
    final render = element.renderObject;
    if (render is! RenderBox || !render.hasSize) {
      out.add('"$label" has no laid-out box');
      continue;
    }
    // Both corners through the paint transform, so a subtree that is
    // scaled down is measured at the size it actually appears on screen.
    final rect = Rect.fromPoints(
      render.localToGlobal(Offset.zero),
      render.localToGlobal(render.size.bottomRight(Offset.zero)),
    );
    if (rect.isEmpty) {
      out.add('"$label" paints nothing (rect $rect)');
      continue;
    }
    final escaped = _escape(rect, box);
    if (escaped > 0.5) {
      out.add(
        '"$label" is ${escaped.toStringAsFixed(1)}px outside its container '
        '(text $rect vs container $box)',
      );
    }
  }
  return out;
}

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  void setWindow(Size size) {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = size
      ..devicePixelRatio = 1;
  }

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  for (final size in _sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('the real shell lays out with no overflow at $label', (
      tester,
    ) async {
      setWindow(size);
      await tester.pumpWidget((await buildTestApp(measurer)).app);
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'laying the shell out at $label reported an overflow; in a '
            'release build that is silent clipping, not a red banner',
      );
    });

    testWidgets('every chip stays inside the strip, and the strip inside the '
        'canvas column, at $label', (tester) async {
      setWindow(size);
      await tester.pumpWidget((await buildTestApp(measurer)).app);
      await tester.pump();
      // Consumed deliberately: this test is about geometry, and the sibling
      // above is the one that owns the overflow report. Leaving it pending
      // would fail this test for the other test's reason.
      tester.takeException();

      expect(find.byType(RackMetricsRow), findsOneWidget);

      // 1. All four chips are on the strip at all. Without this the
      //    containment check below is trivially satisfiable by dropping
      //    chips, which is precisely the behaviour docs/04 §5 forbids.
      for (final chip in _demoChips) {
        expect(
          find.text(chip),
          findsOneWidget,
          reason: '"$chip" left the strip at $label',
        );
      }

      // 2. The strip is inside the canvas column — it may not spill over
      //    the palette or the inspector to buy itself room.
      final strip = tester.getRect(find.byType(RackMetricsRow));
      final column = tester.getRect(find.byType(CanvasIntentDetector));
      expect(
        _escape(strip, column),
        0,
        reason:
            'the strip escaped the canvas column at $label '
            '(strip $strip, column $column)',
      );

      // 3. Every glyph is inside the strip. This is the assertion that
      //    still fails if the strip stops overflowing but starts losing a
      //    chip — or a superscript — some other way.
      expect(
        _escapedText(tester, find.byType(RackMetricsRow)),
        isEmpty,
        reason: 'part of the strip was painted outside it at $label',
      );
    });
  }

  testWidgets('all four rollups are still READABLE, not just present — the '
      'strip is not allowed to buy its fit by dropping a chip', (tester) async {
    // The complement of the containment check. Hiding a chip whose value is
    // 0 or unknown is what the pre-rewrite strip did (`if (weightKg > 0)`),
    // and it would make every containment assertion above trivially pass.
    setWindow(const Size(1024, 768));
    await tester.pumpWidget((await buildTestApp(measurer)).app);
    await tester.pump();
    tester.takeException();

    for (final chip in _demoChips) {
      expect(find.text(chip), findsOneWidget, reason: '"$chip" left the strip');
    }
    // ...and the strip is still docs/04 §5's 20px box while it fits itself
    // into a 422px column.
    expect(tester.getSize(find.byType(RackMetricsRow)).height, 20);
  });

  group('the detectors can fire', () {
    testWidgets('the detector sees a real overflow', (tester) async {
      // Without this, `expect(takeException(), isNull)` above would pass on
      // a harness that never reports overflows at all.
      setWindow(const Size(1024, 768));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 400, height: 10),
                    SizedBox(width: 400, height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final reported = tester.takeException();
      expect(reported, isNotNull);
      expect('$reported', contains('overflowed'));
    });

    testWidgets('the detector sees text painted outside its box', (
      tester,
    ) async {
      // The same `_escapedText` helper the real assertions use, pointed at a
      // box whose content genuinely does not fit, so a green run of those
      // assertions means "contained", not "unmeasurable".
      setWindow(const Size(1024, 768));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: ValueKey('box'),
                width: 30,
                height: 20,
                child: OverflowBox(
                  maxWidth: 900,
                  child: Text('outlets —', style: TextStyle(fontSize: 40)),
                ),
              ),
            ),
          ),
        ),
      );
      tester.takeException();

      expect(
        _escapedText(tester, find.byKey(const ValueKey('box'))),
        isNotEmpty,
      );
    });

    testWidgets('the detector does NOT flag text that fits', (tester) async {
      // The other half of the control: the helper is not simply always
      // non-empty.
      setWindow(const Size(1024, 768));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                key: ValueKey('box'),
                width: 400,
                height: 60,
                child: Center(
                  child: Text('outlets —', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),
        ),
      );

      expect(_escapedText(tester, find.byKey(const ValueKey('box'))), isEmpty);
    });
  });
}
