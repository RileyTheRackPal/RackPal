// #561, DR-176 §11.175.2: naming a preset saved from a rack.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

Rack _rack() {
  final at = DateTime.utc(2026, 9, 15);
  return Rack(
    id: const Uuid('0190f300-0000-7000-8000-000000000001'),
    name: 'Head end',
    designator: 'RK-1',
    heightU: 30,
    order: const FracIndex('a0'),
    meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
  );
}

/// Opens the dialog from a button, as a caller does, and reports what it
/// returned through [onResult] once it closes.
Future<void> _open(
  WidgetTester tester, {
  required ValueChanged<String?> onResult,
  Iterable<String> existing = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(
            await showSaveRackPreset(
              context,
              rack: _rack(),
              existingNames: existing,
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('presetNameError', () {
    test('an empty or blank name is refused', () {
      expect(presetNameError('', const []), isNotNull);
      expect(presetNameError('   ', const []), isNotNull);
    });

    test('a name already listed is refused, ignoring case and spaces', () {
      const listed = ['Floor enclosure 24U', 'Mine'];
      expect(presetNameError('floor enclosure 24u', listed), isNotNull);
      expect(presetNameError('  Mine ', listed), isNotNull);
      expect(presetNameError('Mine 2', listed), isNull);
    });
  });

  group('the dialog', () {
    testWidgets('Save returns the trimmed name and closes', (tester) async {
      String? result = 'unset';
      await _open(tester, onResult: (r) => result = r);
      await tester.enterText(
        find.byKey(SaveRackPresetDialog.nameKey),
        '  Client A 30U ',
      );
      await tester.tap(find.byKey(SaveRackPresetDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(result, 'Client A 30U');
      expect(find.byType(SaveRackPresetDialog), findsNothing);
    });

    testWidgets('a duplicate name stays open and says why', (tester) async {
      String? result = 'unset';
      await _open(
        tester,
        onResult: (r) => result = r,
        existing: const ['Taken'],
      );
      await tester.enterText(find.byKey(SaveRackPresetDialog.nameKey), 'taken');
      await tester.tap(find.byKey(SaveRackPresetDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(find.byType(SaveRackPresetDialog), findsOneWidget);
      expect(
        find.text('A preset with that name is already in the list.'),
        findsOneWidget,
      );
      expect(result, 'unset', reason: 'nothing was returned yet');
    });

    testWidgets('Cancel returns null', (tester) async {
      String? result = 'unset';
      await _open(tester, onResult: (r) => result = r);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('it opens on a name the person can keep', (tester) async {
      await _open(tester, onResult: (_) {});
      final field = tester.widget<TextField>(
        find.byKey(SaveRackPresetDialog.nameKey),
      );
      expect(field.controller!.text, '30U Head end');
    });
  });
}
