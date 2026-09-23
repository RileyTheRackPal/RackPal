// `F7`, `F8` and `Shift+F8` work from every view and go where the fix is
// (DR-193 §11.192, board #928).
//
// Until DR-193 the three keys were `KeyScope.global` and handled only
// inside the Rack view, so on four views of six they did nothing. These
// cases press them through the REAL app (`buildTestApp` mounts `main`'s
// root actions) over the Whole house starter, whose findings point at
// cables, rack devices and nothing at all, and read back what a person
// would see: which tab is showing, what the notice says, and what the
// destination view says it selected.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';

import '../../tool/starters/starter_sources.dart';
import 'session_fakes.dart';

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  RackDocument wholeHouse() => kStarterSources
      .singleWhere((s) => s.fileName == 'whole_house.rppj')
      .build();

  Future<RackDocument> open(WidgetTester tester) async {
    final built = await buildTestApp(measurer, document: wholeHouse());
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    return built.session.services.session.document;
  }

  Future<void> showTab(WidgetTester tester, ShellView view) async {
    await tester.tap(find.widgetWithText(Tab, view.label));
    await tester.pumpAndSettle();
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  int tabIndex(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

  /// The index of the first finding of [kind], in the engine's order.
  int firstOf(RackDocument doc, FindingLocusKind kind) {
    final findings = evaluateDocument(doc);
    return findings.indexWhere((f) => findingLocusOf(doc, f).kind == kind);
  }

  testWidgets('F8 from the Schedule goes to a CABLE on the Schematic', (
    tester,
  ) async {
    final doc = await open(tester);
    final at = firstOf(doc, FindingLocusKind.cable);
    // THE PRECONDITION: the starter must hold such a finding, or every
    // assertion below is about nothing.
    expect(at, isNonNegative);
    final finding = evaluateDocument(doc)[at];

    await showTab(tester, ShellView.schedule);
    for (var i = 0; i <= at; i++) {
      await press(tester, LogicalKeyboardKey.f8);
    }

    expect(tabIndex(tester), ShellView.schematic.index);
    expect(
      find.textContaining('${finding.ruleId} (${at + 1} of '),
      findsOneWidget,
    );
    // The Schematic says what it did with THIS cable, one way or the
    // other: selected, or not drawn. A bare designator match would also
    // find the Schedule's own row, which may still be mounted.
    final link = doc.links[finding.primaryEntityId]!;
    expect(
      find.textContaining(
        RegExp('${link.designator}.*(selected|has no drawn end)'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('F8 from the Site view goes to a RACK DEVICE, selected, in '
      'its rack', (tester) async {
    final doc = await open(tester);
    final at = firstOf(doc, FindingLocusKind.rackDevice);
    expect(at, isNonNegative);

    await showTab(tester, ShellView.site);
    for (var i = 0; i <= at; i++) {
      await press(tester, LogicalKeyboardKey.f8);
    }

    expect(tabIndex(tester), ShellView.rack.index);
    expect(find.text('1 device selected'), findsOneWidget);
  });

  testWidgets('Shift+F8 walks BACKWARDS and wraps to the last finding', (
    tester,
  ) async {
    final doc = await open(tester);
    final findings = evaluateDocument(doc);
    expect(findings, isNotEmpty);

    await showTab(tester, ShellView.structuredWiring);
    await press(tester, LogicalKeyboardKey.f8, shift: true);

    expect(
      find.textContaining(
        '${findings.last.ruleId} (${findings.length} of ${findings.length})',
      ),
      findsOneWidget,
    );
  });

  testWidgets('F7 re-checks from a view with no drawer and says the counts', (
    tester,
  ) async {
    final doc = await open(tester);
    final errors = evaluateDocument(
      doc,
    ).where((f) => f.severity == Severity.error).length;
    expect(errors, isPositive);

    await showTab(tester, ShellView.schedule);
    await press(tester, LogicalKeyboardKey.f7);

    expect(
      find.textContaining(
        'Re-checked. $errors ${errors == 1 ? 'error' : 'errors'}',
      ),
      findsOneWidget,
    );
  });
}
