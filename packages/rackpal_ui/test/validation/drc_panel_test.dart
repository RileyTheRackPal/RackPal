// The issues list on screen: M5-F1 (`#294`) and the row action
// M5-F2 adds (`#295`).
//
// THE COPY IS PRINTED, NOT ONLY MATCHED. This repository has shipped
// twelve green `contains` assertions over a line reading "1 ports", so
// the empty-state test renders the real string and compares it whole.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  final at = DateTime.utc(2026, 9, 4, 12);
  const rackId = Uuid('0190e0dd-0002-7000-8000-000000000001');
  const ackId = Uuid('0190e0dd-0002-7000-8000-00000000000a');

  Finding finding(String ruleId, Severity severity, {Uuid? primary}) => Finding(
    ruleId: ruleId,
    severity: severity,
    message: 'A sentence about $ruleId.',
    targets: [if (primary != null) primary],
    primaryEntityId: primary,
  );

  // NOT `group`: that is the test package's, and shadowing it turns
  // every `group('...', () {})` in this file into a type error.
  FindingGroup aGroup(String label, List<FindingRow> rows) =>
      FindingGroup(key: label, label: label, rows: rows);

  Future<void> pump(
    WidgetTester tester,
    Widget panel, {
    Size size = const Size(900, 700),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: panel)),
    );
  }

  group('empty states are two different sentences', () {
    testWidgets('a document with no findings says so', (tester) async {
      await pump(
        tester,
        DrcPanel(
          groups: const [],
          grouping: FindingGrouping.severity,
          onGroupingChanged: (_) {},
          hasAnyFindings: false,
        ),
      );
      expect(find.text(kDrcNoFindings), findsOneWidget);
      expect(find.text(kDrcAllFiltered), findsNothing);
    });

    testWidgets('findings hidden by a filter say something else', (
      tester,
    ) async {
      await pump(
        tester,
        DrcPanel(
          groups: const [],
          grouping: FindingGrouping.severity,
          onGroupingChanged: (_) {},
        ),
      );
      expect(find.text(kDrcAllFiltered), findsOneWidget);
      expect(find.text(kDrcNoFindings), findsNothing);
    });

    test('and they really are different strings', () {
      // The two tests above would both pass if the constants were equal.
      expect(kDrcNoFindings, isNot(kDrcAllFiltered));
    });
  });

  testWidgets('a row shows its message and its rule id', (tester) async {
    await pump(
      tester,
      DrcPanel(
        groups: [
          aGroup('error', [
            FindingRow(finding: finding('SIG-001', Severity.error)),
          ]),
        ],
        grouping: FindingGrouping.severity,
        onGroupingChanged: (_) {},
      ),
    );
    expect(find.text('A sentence about SIG-001.'), findsOneWidget);
    expect(find.text('SIG-001'), findsOneWidget);
  });

  testWidgets('tapping a row reveals its locus', (tester) async {
    Uuid? revealed;
    await pump(
      tester,
      DrcPanel(
        groups: [
          aGroup('error', [
            FindingRow(
              finding: finding('SIG-001', Severity.error, primary: rackId),
            ),
          ]),
        ],
        grouping: FindingGrouping.severity,
        onGroupingChanged: (_) {},
        onReveal: (id) => revealed = id,
      ),
    );
    // ANCHORED ON THE MESSAGE, not on `byType(ListTile).first`. In a
    // list of rows that all look alike, `.first` finds the wrong one and
    // passes.
    await tester.tap(find.text('A sentence about SIG-001.'));
    expect(revealed, rackId);
  });

  testWidgets('a row with no locus is not tappable', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DrcPanel(
        groups: [
          aGroup('warning', [
            FindingRow(finding: finding('PWR-002', Severity.warning)),
          ]),
        ],
        grouping: FindingGrouping.severity,
        onGroupingChanged: (_) {},
        onReveal: (_) => taps++,
      ),
    );
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.onTap, isNull, reason: 'no single thing to navigate to');
    await tester.tap(find.text('A sentence about PWR-002.'));
    expect(taps, 0);
  });

  // DELIBERATELY NOT A CODE RULE. This test is about the acknowledged
  // segment and the reason tooltip; the rule id was incidental until
  // DR-129 made `CODE-002`'s row carry a citation segment too, at which
  // point an exact-string assertion here would have become a test of the
  // citation format wearing an acknowledgement test's name. The three
  // segments composing is a real question and is asserted where it
  // belongs, in remedy_pairing_test.dart.
  testWidgets('an acknowledged row says so and keeps its reason', (
    tester,
  ) async {
    final row = FindingRow(
      finding: finding('PWR-002', Severity.error, primary: rackId),
      acknowledgement: AckedFinding(
        id: ackId,
        ruleId: 'PWR-002',
        targetFingerprint: '*',
        reason: 'Reviewed with the AHJ.',
        by: 'riley',
        at: at,
        demotedTo: Severity.advisory,
        meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 't'),
      ),
    );
    await pump(
      tester,
      DrcPanel(
        groups: [
          aGroup('error', [row]),
        ],
        grouping: FindingGrouping.severity,
        onGroupingChanged: (_) {},
      ),
    );
    expect(find.text('PWR-002 · acknowledged'), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Reviewed with the AHJ.');
  });

  group('the group header count', () {
    test('is a bare number when nothing is acknowledged', () {
      final g = aGroup('SIG-001', [
        FindingRow(finding: finding('SIG-001', Severity.error)),
        FindingRow(finding: finding('SIG-001', Severity.error)),
      ]);
      expect(drcGroupCount(g), '2');
    });

    test('names the acknowledged share when there is one', () {
      final g = aGroup('SIG-001', [
        FindingRow(finding: finding('SIG-001', Severity.error)),
        FindingRow(
          finding: finding('SIG-001', Severity.error),
          acknowledgement: AckedFinding(
            id: ackId,
            ruleId: 'SIG-001',
            targetFingerprint: '*',
            reason: 'x',
            by: 'riley',
            at: at,
            demotedTo: Severity.error,
            meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 't'),
          ),
        ),
      ]);
      expect(drcGroupCount(g), '2 (1 acknowledged)');
    });
  });

  testWidgets('every severity on screen carries a StatusMarker', (
    tester,
  ) async {
    // DR-090 §11.89.6 made structural: a severity that reached the
    // screen as a bare colour would have no second cue. Three rows, three
    // markers in the list, plus one per filter chip.
    await pump(
      tester,
      DrcPanel(
        groups: [
          aGroup('all', [
            FindingRow(finding: finding('SIG-001', Severity.error)),
            FindingRow(finding: finding('LEN-001', Severity.warning)),
            FindingRow(finding: finding('LNK-020', Severity.advisory)),
          ]),
        ],
        grouping: FindingGrouping.severity,
        onGroupingChanged: (_) {},
      ),
    );
    expect(
      find.byType(StatusMarker),
      findsNWidgets(3 + kDrcFilterableSeverities.length),
    );
  });

  test('each severity maps to its own marker, and off is not offered', () {
    // NOT `isNotNull`, which cannot fail: `statusForSeverity` returns a
    // non-nullable `ConsoleStatus`. The contract worth pinning is that
    // the three are DISTINCT, since two severities sharing a marker is
    // the failure a reader would actually suffer.
    expect(statusForSeverity(Severity.error), ConsoleStatus.critical);
    expect(statusForSeverity(Severity.warning), ConsoleStatus.warning);
    expect(statusForSeverity(Severity.advisory), ConsoleStatus.notice);
    expect(
      kDrcFilterableSeverities.map(statusForSeverity).toSet(),
      hasLength(kDrcFilterableSeverities.length),
    );
    expect(kDrcFilterableSeverities.contains(Severity.off), isFalse);
  });

  testWidgets('unticking one severity chip keeps the other two', (
    tester,
  ) async {
    // THE NULL-FILTER TRAP: a null filter draws every chip selected, so
    // the first untick has to start from the full set. Starting from an
    // empty one would hide everything the person did not just click.
    Set<Severity>? next;
    await pump(
      tester,
      DrcPanel(
        groups: const [],
        grouping: FindingGrouping.severity,
        onGroupingChanged: (_) {},
        onSeverityFilterChanged: (s) => next = s,
      ),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'warning'));
    expect(next, {Severity.error, Severity.advisory});
  });

  testWidgets('choosing a grouping reports it', (tester) async {
    FindingGrouping? chosen;
    await pump(
      tester,
      DrcPanel(
        groups: const [],
        grouping: FindingGrouping.severity,
        onGroupingChanged: (g) => chosen = g,
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Location'));
    expect(chosen, FindingGrouping.locus);
  });

  group('the row action (M5-F2, #295)', () {
    FindingRow acked(String ruleId) => FindingRow(
      finding: finding(ruleId, Severity.error, primary: rackId),
      acknowledgement: AckedFinding(
        id: ackId,
        ruleId: ruleId,
        targetFingerprint: '*',
        reason: 'As-found.',
        by: 'riley',
        at: at,
        demotedTo: Severity.error,
        meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 't'),
      ),
    );

    testWidgets('an open row offers Acknowledge and hands back its finding', (
      tester,
    ) async {
      Finding? asked;
      await pump(
        tester,
        DrcPanel(
          groups: [
            aGroup('error', [
              FindingRow(
                finding: finding('SIG-001', Severity.error, primary: rackId),
              ),
            ]),
          ],
          grouping: FindingGrouping.severity,
          onGroupingChanged: (_) {},
          onAcknowledge: (f) => asked = f,
          onWithdraw: (_) {},
        ),
      );
      expect(find.text(kDrcWithdraw), findsNothing);
      await tester.tap(find.text(kDrcAcknowledge));
      expect(asked?.ruleId, 'SIG-001');
    });

    testWidgets('an acknowledged row offers Withdraw instead, never both', (
      tester,
    ) async {
      FindingRow? taken;
      await pump(
        tester,
        DrcPanel(
          groups: [
            aGroup('error', [acked('CODE-002')]),
          ],
          grouping: FindingGrouping.severity,
          onGroupingChanged: (_) {},
          onAcknowledge: (_) {},
          onWithdraw: (r) => taken = r,
        ),
      );
      // NEVER BOTH: they are two directions of one state, and a row
      // offering both would be asking which way the state already is.
      expect(find.text(kDrcAcknowledge), findsNothing);
      await tester.tap(find.text(kDrcWithdraw));
      expect(taken?.finding.ruleId, 'CODE-002');
    });

    testWidgets('no callback means no control, not a dead one', (tester) async {
      await pump(
        tester,
        DrcPanel(
          groups: [
            aGroup('error', [
              FindingRow(
                finding: finding('SIG-001', Severity.error, primary: rackId),
              ),
              acked('CODE-002'),
            ]),
          ],
          grouping: FindingGrouping.severity,
          onGroupingChanged: (_) {},
        ),
      );
      expect(find.text(kDrcAcknowledge), findsNothing);
      expect(find.text(kDrcWithdraw), findsNothing);
    });

    test('the two action labels are different strings', () {
      expect(kDrcAcknowledge, isNot(kDrcWithdraw));
    });
  });
}
