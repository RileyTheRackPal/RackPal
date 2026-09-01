// The device builder draws its own toolbars at every width (`#803`).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY A WHOLE FILE FOR "NOTHING OVERFLOWED"
// ═══════════════════════════════════════════════════════════════════════
// `#803` was filed as one number: the port grid overflows an 800 px window
// by 63 px. Measuring it turned up three more that the ticket did not
// have, and the largest of them was in the range a person can actually
// reach. So the assertion here is not "the archetype bar fits"; it is a
// SWEEP, because the defect that was filed and the defect that mattered
// were not the same widget.
//
// A `RenderFlex` reports its overflow ONCE per render object, on the first
// paint that overflows. That is why every width gets its own `testWidgets`
// with its own tree: re-pumping one tree at a second width measures
// nothing and reports clean, which is a trap this file walked into before
// it was written.
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

/// Every exception the frame produced, not merely the first.
///
/// `takeException()` returns ONE, and with several pending it returns a
/// summary reading "Multiple exceptions (4) were detected" that names none
/// of them. Draining the queue is what turns a failure into a list a
/// person can act on.
List<Object> _drain(WidgetTester tester) {
  final out = <Object>[];
  // `Object? e`, not `var e`: `takeException()` returns `dynamic`, so an
  // inferred loop variable makes `out.add(e)` an ARGUMENT_TYPE_NOT_ASSIGNABLE
  // error, and the analyzer gate is zero for errors rather than ratcheted.
  for (
    Object? e = tester.takeException();
    e != null;
    e = tester.takeException()
  ) {
    out.add(e);
  }
  return out;
}

void main() {
  // 1000 is `kMinWindowWidth`, which `app_services.dart` enforces through
  // `setMinimumSize`, so it is the narrowest window that ships; 900 is one
  // notch below it, as margin.
  //
  // ═══════════════════════════════════════════════════════════════════
  // 800 IS DELIBERATELY ABSENT, AND WHAT IS THERE IS NOT THE PORT GRID
  // ═══════════════════════════════════════════════════════════════════
  // Measured at 800: the header's INNER controls `Row` overflows by 22.
  // `_Header` is already a `Wrap` for this exact reason and says so, and
  // it keeps its controls as ONE wrap child on purpose, so that `Save`
  // and `Save & Close` cannot land on different lines. Every fix that
  // preserves that intent splits the status chips into a third wrap
  // child, and with `WrapAlignment.spaceBetween` that moves `Unsaved`
  // and `Draft` to the CENTRE of the header at every width.
  //
  // So it is filed rather than fixed: it trades a visible change at
  // every width for an invisible one at a width the app refuses to open.
  // Adding 800 here would pin that trade as though it had been made.
  for (final width in [900.0, 1000.0, 1100.0, 1180.0, 1200.0, 1440.0]) {
    testWidgets('the Ports section overflows nothing at ${width}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
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
      await tester.tap(find.text('Ports').first);
      await tester.pumpAndSettle();

      // NOT VACUOUS. A sweep that never reached the Ports section would
      // report clean at every width and prove nothing, which is the shape
      // of green-over-nothing this repository keeps meeting.
      expect(
        find.text('Matrix I/O…'),
        findsOneWidget,
        reason: 'the archetype bar is what this test is about',
      );
      expect(find.text('Switch ports…'), findsOneWidget);
      expect(find.text('Paste…'), findsOneWidget);
      expect(find.text('Add port'), findsOneWidget);

      expect(_drain(tester), isEmpty, reason: 'at ${width}px');
    });
  }
}
