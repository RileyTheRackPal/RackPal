// DR-129 §11.128.4 — every `FindingRemedy` reaches a row a person can
// press, and every code rule's article reaches the row it belongs to.
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE EXISTS BECAUSE A BUTTON WAS RULED TWICE AND BUILT ONCE
// ═════════════════════════════════════════════════════════════════════
// DR-128 §11.127.5 states that the issues panel "renders it as a button".
// It did not. `Finding.remedy` shipped, `PWR-003` declared one,
// `addOutletsToRack` implemented it, and `drc_panel.dart` never read the
// field.
//
// The SAME ruling made the same claim about `SpringBackRemedy`'s two
// members, and **Dart's exhaustive switch caught that one within the
// hour**, because a chip's handler must match every enum value. A
// nullable field a widget ignores has no such backstop: it compiles, and
// every test that could have noticed was written against the model.
//
// So this is the backstop, in the shape `spring_back_rules_test.dart`
// already uses for the chips: assert the pairing in BOTH directions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _at = DateTime.utc(2026, 9, 6);

/// An empty document: `groupFindings` reads only `ackedFindings` from it,
/// and no row here is acknowledged.
RackDocument _doc() => RackDocument(
  id: const Uuid('0190e0cc-0002-7000-8000-000000000000'),
  appVersion: '0.5.60',
  createdAt: _at,
  modifiedAt: _at,
  meta: EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'test'),
);

Finding _finding(String ruleId, {FindingRemedy? remedy}) => Finding(
  ruleId: ruleId,
  severity: Severity.warning,
  message: 'RK-1 is short of outlets.',
  targets: const [Uuid('rk-1')],
  primaryEntityId: const Uuid('rk-1'),
  remedy: remedy,
);

Widget _panel(
  List<Finding> findings, {
  ValueChanged<Finding>? onRemedy,
}) => MaterialApp(
  home: Scaffold(
    body: DrcPanel(
      groups: groupFindings(_doc(), findings, by: FindingGrouping.rule),
      grouping: FindingGrouping.rule,
      onGroupingChanged: (_) {},
      onRemedy: onRemedy,
    ),
  ),
);

void main() {
  group('every FindingRemedy reaches a row', () {
    test('PWR-003 is the only rule declaring one, and it declares '
        'addRackPdu', () {
      // Both directions. A remedy no rule files is a label nobody sees;
      // a rule filing one the panel cannot render is DR-128's defect.
      expect(FindingRemedy.values, [FindingRemedy.addRackPdu]);
    });

    testWidgets('and the panel draws it as a pressable button', (
      tester,
    ) async {
      Finding? pressed;
      await tester.pumpWidget(
        _panel(
          [_finding('PWR-003', remedy: FindingRemedy.addRackPdu)],
          onRemedy: (f) => pressed = f,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(FindingRemedy.addRackPdu.label),
        findsOneWidget,
        reason:
            'the panel stopped reading Finding.remedy, which is exactly '
            'the state DR-128 shipped in and described as working',
      );
      await tester.tap(find.text(FindingRemedy.addRackPdu.label));
      await tester.pumpAndSettle();
      expect(pressed?.ruleId, 'PWR-003');
    });

    testWidgets('a finding with no remedy draws no button, rather than a '
        'dead one', (tester) async {
      await tester.pumpWidget(
        _panel([_finding('LEN-001')], onRemedy: (_) {}),
      );
      await tester.pumpAndSettle();
      for (final remedy in FindingRemedy.values) {
        expect(find.text(remedy.label), findsNothing);
      }
    });

    testWidgets('and no callback means no button, not a button that '
        'throws', (tester) async {
      await tester.pumpWidget(
        _panel([_finding('PWR-003', remedy: FindingRemedy.addRackPdu)]),
      );
      await tester.pumpAndSettle();
      expect(find.text(FindingRemedy.addRackPdu.label), findsNothing);
    });
  });

  group('a code-adjacent row says so (DR-129)', () {
    test('exactly CODE-001 and CODE-002 carry a codeCitation', () {
      final cited = <String, String>{
        for (final r in kRuleCatalogue)
          if (r.codeCitation != null) r.ruleId: r.codeCitation!,
      };
      // NAMED, not counted: a count of two passes on the wrong two, and
      // a rule that quietly gained a citation would change how its row
      // is drawn.
      expect(cited, {
        'CODE-001': 'NEC 725.136',
        'CODE-002': 'NEC 800.154',
      });
    });

    testWidgets('its row shows the article beside the rule id', (
      tester,
    ) async {
      await tester.pumpWidget(_panel([_finding('CODE-002')]));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('NEC 800.154'),
        findsOneWidget,
        reason:
            'the article was findable only by reading to the end of the '
            'message, which is the finding DR-129 answers',
      );
      expect(find.textContaining(kDrcVerifyAgainst), findsOneWidget);
    });

    testWidgets('and it draws the caution DIAMOND rather than the warning '
        'triangle, at the same severity', (tester) async {
      // THE ARTIFACT IS THE MARKER, not the mapping function, because a
      // panel that computed the right status and drew the wrong shape
      // would pass a unit test of `statusForRow`.
      await tester.pumpWidget(
        _panel([_finding('CODE-002'), _finding('LEN-001')]),
      );
      await tester.pumpAndSettle();

      final markers = tester
          .widgetList<StatusMarker>(find.byType(StatusMarker))
          .map((m) => m.status)
          .toList();
      expect(
        markers,
        containsAll([ConsoleStatus.caution, ConsoleStatus.warning]),
        reason:
            'both rows are warnings; only the code one should be a '
            'diamond, and if both are the same the row kind is invisible',
      );
    });

    testWidgets('and an acknowledged code row keeps BOTH segments, in '
        'order', (tester) async {
      // THE SEGMENTS COMPOSE, and that is a third thing neither of the
      // two tests above can see. A row that dropped `acknowledged` once
      // a citation arrived, or dropped the citation once acknowledged,
      // passes every other assertion in this file. Printed whole rather
      // than matched in pieces, on this repository's own rule.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrcPanel(
              groups: [
                FindingGroup(
                  key: 'CODE-002',
                  label: 'CODE-002',
                  rows: [
                    FindingRow(
                      finding: _finding('CODE-002'),
                      acknowledgement: AckedFinding(
                        id: const Uuid(
                          '0190e0cc-0002-7000-8000-00000000000a',
                        ),
                        ruleId: 'CODE-002',
                        targetFingerprint: '*',
                        reason: 'Checked against the 2023 edition.',
                        by: 'Riley',
                        at: _at,
                        demotedTo: Severity.advisory,
                        meta: EntityMeta(
                          createdAt: _at,
                          updatedAt: _at,
                          updatedBy: 'test',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              grouping: FindingGrouping.rule,
              onGroupingChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'CODE-002 · Verify against NEC 800.154 · acknowledged',
        ),
        findsOneWidget,
      );
    });

    test('the severity itself is untouched, so the filter still finds '
        'it', () {
      // DR-129 is a rendering change. A code finding that had quietly
      // become a different SEVERITY would move between filter buckets and
      // could be overridden separately, which was not ruled.
      expect(statusForSeverity(Severity.warning), ConsoleStatus.warning);
      expect(
        statusForRow(_finding('CODE-002')),
        ConsoleStatus.caution,
      );
      expect(
        statusForRow(_finding('LEN-001')),
        ConsoleStatus.warning,
      );
      expect(_finding('CODE-002').severity, Severity.warning);
    });
  });
}
