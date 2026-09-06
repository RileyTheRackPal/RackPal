// The drawer that gives `DrcPanel` a host (`#847`, DR-133 §11.132).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LAST TEST IS THE ONE THIS CHAPTER EXISTS FOR
// ═══════════════════════════════════════════════════════════════════════
// Everything above it mounts the drawer itself, which is exactly how
// `DrcPanel` passed its own suite for two days while nothing in the
// product mounted it. So the file ends by mounting `RackCanvasScreen` and
// asserting the SHELL contains a `DrcPanel`: the one assertion a widget
// test cannot make about itself, and the assertion whose absence `#847`
// is.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _at = DateTime.utc(2026, 9, 6);

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

RackDocument _doc() => RackDocument(
  id: const Uuid('0190e0dd-0003-7000-8000-000000000000'),
  appVersion: '0.5.61',
  createdAt: _at,
  modifiedAt: _at,
  meta: EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'test'),
);

Finding _finding(String ruleId, Severity severity) => Finding(
  ruleId: ruleId,
  severity: severity,
  message: 'A sentence about $ruleId.',
  targets: const [],
);

Future<bool> _pump(
  WidgetTester tester,
  List<Finding> findings, {
  bool startExpanded = false,
}) async {
  var expanded = startExpanded;
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ValidationDrawer(
            findings: findings,
            groups: groupFindings(
              _doc(),
              findings,
              by: FindingGrouping.severity,
            ),
            grouping: FindingGrouping.severity,
            onGroupingChanged: (_) {},
            expanded: expanded,
            onExpandedChanged: (v) => setState(() => expanded = v),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return expanded;
}

void main() {
  group('the collapsed rail says what it found, in words', () {
    test('a clean document is a RESULT, not a blank strip', () {
      // "No issues" rather than an empty rail: 28 px of nothing reads as
      // chrome, and the whole point of the drawer is that the engine is
      // visible without being loud.
      expect(drawerSummary(const []), kDrawerClean);
    });

    test('the counts are printed whole, and the plural is right', () {
      // PRINTED, NOT MATCHED. This repository has shipped twelve green
      // `contains` assertions over a line reading "1 ports", and the
      // first draft of `drawerSummary` had an unreachable
      // `else if (advisories > 1)` that would have printed "3 advisory".
      expect(
        drawerSummary([
          _finding('SIG-001', Severity.error),
          _finding('LEN-001', Severity.warning),
          _finding('RCK-014', Severity.advisory),
        ]),
        '1 error · 1 warning · 1 advisory',
      );
      expect(
        drawerSummary([
          _finding('SIG-001', Severity.error),
          _finding('SIG-002', Severity.error),
          _finding('RCK-014', Severity.advisory),
          _finding('RCK-014', Severity.advisory),
          _finding('RCK-014', Severity.advisory),
        ]),
        '2 errors · 3 advisories',
      );
    });

    test('findings that all resolved to off still say something true', () {
      // A document whose every rule is overridden off has findings and
      // nothing to report, and "0 errors" would be noise.
      expect(drawerSummary([_finding('SIG-001', Severity.off)]), kDrawerClean);
    });
  });

  group('it opens itself once, on an ERROR (docs/04 §1)', () {
    testWidgets('an error opens it without being asked', (tester) async {
      final expanded = await _pump(tester, [
        _finding('SIG-001', Severity.error),
      ]);
      expect(
        expanded,
        isTrue,
        reason:
            'a person who does not know the validation engine exists '
            'cannot press a key to find it, which is why the spec makes '
            'this automatic',
      );
    });

    testWidgets('a warning does NOT, and neither does an advisory', (
      tester,
    ) async {
      expect(
        await _pump(tester, [
          _finding('LEN-001', Severity.warning),
          _finding('RCK-014', Severity.advisory),
        ]),
        isFalse,
      );
    });

    test('the trigger reads the RESOLVED severity (DR-133 §11.132.3)', () {
      // A project that demoted a rule has said it does not want to be
      // stopped by it. `evaluateDocument` resolves overrides and
      // acknowledgements before this sees them, so a finding whose
      // CATALOGUE default is error but which resolved to advisory must
      // not open the drawer.
      expect(drawerShouldAutoOpen([_finding('SIG-001', Severity.error)]), true);
      expect(
        drawerShouldAutoOpen([_finding('SIG-001', Severity.advisory)]),
        false,
        reason: 'SIG-001 defaults to error; this one was demoted',
      );
    });

    testWidgets('and it does not re-open after being collapsed', (
      tester,
    ) async {
      // ONCE PER SESSION, NEVER AGAIN, the spec's own word. A user who
      // closes it has answered it, and re-opening on the next rebuild
      // would be an argument rather than a notification.
      var expanded = false;
      var rebuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuilds++;
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('rebuild'),
                    ),
                    ValidationDrawer(
                      findings: [_finding('SIG-001', Severity.error)],
                      groups: const [],
                      grouping: FindingGrouping.severity,
                      onGroupingChanged: (_) {},
                      expanded: expanded,
                      onExpandedChanged: (v) => setState(() => expanded = v),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(expanded, isTrue);

      expanded = false;
      await tester.tap(find.text('rebuild'));
      await tester.pumpAndSettle();
      expect(
        expanded,
        isFalse,
        reason: 'the latch is set, so the same errors must not re-open it',
      );
      expect(rebuilds, greaterThan(1));
    });
  });

  group('what it hosts', () {
    testWidgets('expanded, it is the real DrcPanel and nothing else', (
      tester,
    ) async {
      await _pump(
        tester,
        [_finding('LEN-001', Severity.warning)],
        startExpanded: true,
      );
      expect(find.byType(DrcPanel), findsOneWidget);
    });

    testWidgets('collapsed, the panel is not built at all', (tester) async {
      await _pump(tester, [_finding('LEN-001', Severity.warning)]);
      expect(find.byType(DrcPanel), findsNothing);
      expect(find.text('1 warning'), findsOneWidget);
    });
  });

  group('THE SHELL MOUNTS IT, which is what #847 was', () {
    testWidgets('RackCanvasScreen contains a DrcPanel, so every finding '
        'M5-F can render is reachable', (tester) async {
      // ═══════════════════════════════════════════════════════════════
      // EVERY OTHER TEST IN THIS FILE MOUNTS THE DRAWER ITSELF
      // ═══════════════════════════════════════════════════════════════
      // Which is precisely how `DrcPanel` passed its own suite while
      // nothing in the product mounted it, and how docs/12 §5.4.6 came
      // to record that a user could see findings when none could. This
      // is the one assertion a widget test cannot make about itself.
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ValidationDrawer), findsOneWidget);
      // The rail, not the panel: a clean starter document has no errors,
      // so the drawer is correctly collapsed and the panel unbuilt.
      expect(find.text(kDrawerClean), findsOneWidget);

      await tester.tap(find.text(kDrawerClean));
      await tester.pumpAndSettle();
      expect(
        find.byType(DrcPanel),
        findsOneWidget,
        reason:
            'opening the drawer must reach the panel through the SHELL, '
            'not through a test harness',
      );
    });
  });
}
