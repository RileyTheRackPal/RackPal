// docs/04-rack-editor.md §9's New-rack dialog — "three fields — Name,
// Preset, Height — and `Enter` commits" — and `showNewRack`, the one path
// that turns its result into an `AddRackCommand`.
//
// The clause under test is M1's exit clause 2, "a user … creates a 42U
// rack", which docs/12-milestone-board.md §3.2 marked NOT BUILT because
// nothing anywhere created a rack. These tests are about the dialog and the
// command; `test/canvas/rack_creation_test.dart` is about what the canvas
// does with the rack afterwards, which is the half that decides whether the
// button produces something the user can actually see.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-new-rack'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
  );
  doc.racks[const Uuid('rk1')] = Rack(
    id: const Uuid('rk1'),
    name: 'Rack 1',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  return doc;
}

Finder _dialogFields() => find.descendant(
  of: find.byType(NewRackDialog),
  matching: find.byType(TextField),
);

Finder _nameField() => _dialogFields().at(0);
Finder _heightField() => _dialogFields().at(1);

/// Pumps a host with a button that opens the dialog, so the real
/// `showDialog` route is exercised rather than the widget in isolation.
Future<DocumentController> _pumpHost(
  WidgetTester tester, {
  void Function(NewRackOutcome)? onOutcome,
}) async {
  final controller = DocumentController(_doc());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final outcome = await showNewRack(
                context: context,
                controller: controller,
                presets: buildRackPresets(),
              );
              onOutcome?.call(outcome);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('the three fields (docs/04 §9)', () {
    testWidgets('Name, Preset and Height — and nothing else; no Location '
        'combobox (AC-048)', (tester) async {
      await _pumpHost(tester);

      expect(find.byType(NewRackDialog), findsOneWidget);
      expect(_dialogFields(), findsNWidgets(2));
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Preset'), findsOneWidget);
      expect(find.text('Height (U)'), findsOneWidget);
      // §9 removes it explicitly, and this is the assertion that keeps it
      // removed.
      expect(find.text('Location'), findsNothing);
    });

    testWidgets("opens on the blank project's own shape: no preset, 42U, "
        'and the next free designator', (tester) async {
      await _pumpHost(tester);

      expect(NewRackDialog.defaultHeightU, 42);
      expect(
        tester.widget<TextField>(_heightField()).controller!.text,
        '42',
      );
      expect(
        tester.widget<TextField>(_nameField()).controller!.text,
        'Rack 2',
      );
      expect(find.text('No preset (custom)'), findsOneWidget);
      expect(find.textContaining('Will be created as RK-2'), findsOneWidget);
    });
  });

  group('committing', () {
    testWidgets('Enter in the Name field commits and runs the command', (
      tester,
    ) async {
      NewRackOutcome? outcome;
      final controller = await _pumpHost(
        tester,
        onOutcome: (o) => outcome = o,
      );

      await tester.tap(_nameField());
      await tester.pump();
      await tester.enterText(_nameField(), 'Media Closet');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(NewRackDialog), findsNothing);
      expect(outcome, isA<NewRackCreated>());
      final created = (outcome! as NewRackCreated).command;
      expect(created.name, 'Media Closet');
      expect(created.heightU, 42);
      expect(created.designator, 'RK-2');
      expect(controller.doc.racks, hasLength(2));
      expect(controller.doc.racks[created.id]!.heightU, 42);
      // Through the real command stack, so it undoes like everything else.
      expect(controller.undo.canUndo, isTrue);
      controller.undoLast();
      expect(controller.doc.racks, hasLength(1));
    });

    testWidgets('the Create button commits too, and Cancel mutates nothing', (
      tester,
    ) async {
      NewRackOutcome? outcome;
      final controller = await _pumpHost(
        tester,
        onOutcome: (o) => outcome = o,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(outcome, isA<NewRackCancelled>());
      expect(controller.doc.racks, hasLength(1));
      expect(controller.undo.canUndo, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(outcome, isA<NewRackCreated>());
      expect(controller.doc.racks, hasLength(2));
    });
  });

  group('Preset and Height are two fields', () {
    testWidgets('picking a preset rewrites the height box…', (tester) async {
      await _pumpHost(tester);

      await tester.tap(find.text('No preset (custom)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wall box 6U / 12 in').last);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_heightField()).controller!.text, '6');
    });

    testWidgets("…and typing over it afterwards wins, with the preset's "
        'other facts still applied', (tester) async {
      NewRackOutcome? outcome;
      await _pumpHost(tester, onOutcome: (o) => outcome = o);

      await tester.tap(find.text('No preset (custom)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wall box 6U / 12 in').last);
      await tester.pumpAndSettle();

      await tester.enterText(_heightField(), '9');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final created = (outcome! as NewRackCreated).command;
      expect(created.heightU, 9);
      expect(created.formFactor, RackFormFactor.wallFixed);
      expect(created.usableDepth, const Len(12 * Len.nmPerInch));
    });
  });

  group('refusals are visible, not silent (docs/04 §3.4)', () {
    testWidgets('an empty name disables Create and says why', (tester) async {
      await _pumpHost(tester);

      await tester.enterText(_nameField(), '');
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('a height outside CR-038 [1, 60] disables Create and names '
        'the bound', (tester) async {
      await _pumpHost(tester);

      await tester.enterText(_heightField(), '61');
      await tester.pumpAndSettle();
      expect(find.text('1–60U (CR-038)'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.enterText(_heightField(), '');
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(_heightField(), '60');
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  });
}
