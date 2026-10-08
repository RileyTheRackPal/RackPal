// SFE-C3: a cloned family is told apart from a shipped one at the point of
// use, by its parent and by a filter (DR-122; the user's choice of
// 2026-10-07).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-picker-provenance'),
  appVersion: 'test',
  createdAt: DateTime.utc(2026, 10, 7),
  modifiedAt: DateTime.utc(2026, 10, 7),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026, 10, 7),
    updatedAt: DateTime.utc(2026, 10, 7),
    updatedBy: 'test',
  ),
)..registries = buildSeedRegistries();

/// [doc] with Vantage cloned from Cresnet, through the real builder.
RackDocument _withClone(RackDocument doc) {
  final free = cloneHeadroom(doc, const SignalDomainId('ctl'))!.free.first;
  final built = buildCloneSignalFamily(
    doc,
    parent: const SignalFamilyId('ctl.cresnet'),
    displayName: 'Vantage',
    shortTag: 'VNT',
    dashPermille: free.dashPermille,
    weightPermille: free.weightPermille,
  );
  (built as CloneSignalFamilyReady).command.apply(doc);
  return doc;
}

Future<void> _pump(WidgetTester tester, RackDocument doc) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FamilyPickerPanel(
          groups: signalFamilyCellGroups(doc.registries),
          selected: null,
          onPick: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a clone says what it was cloned from; a shipped family says '
      'nothing', (tester) async {
    await _pump(tester, _withClone(_doc()));
    await tester.enterText(
      find.byKey(const ValueKey('service-filter')),
      'ctl',
    );
    await tester.pumpAndSettle();

    Finder rowOf(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(
        of: rowOf('CTL·Vantage'),
        matching: find.text('clone of Cresnet'),
      ),
      findsOneWidget,
    );
    // The row is there, so its having no chip is a finding and not a pass
    // over a row that was never built.
    expect(rowOf('CTL·Cresnet'), findsOneWidget);
    expect(
      find.descendant(
        of: rowOf('CTL·Cresnet'),
        matching: find.textContaining('clone of'),
      ),
      findsNothing,
    );
  });

  testWidgets('"Clones only" narrows to clones, and is not offered on a '
      'project that has none', (tester) async {
    await _pump(tester, _doc());
    expect(find.byKey(kClonesOnlyKey), findsNothing);

    await _pump(tester, _withClone(_doc()));
    expect(find.text('CTL·Cresnet'), findsOneWidget);
    await tester.tap(find.byKey(kClonesOnlyKey));
    await tester.pumpAndSettle();
    expect(find.text('CTL·Vantage'), findsOneWidget);
    expect(find.text('CTL·Cresnet'), findsNothing);
  });
}
