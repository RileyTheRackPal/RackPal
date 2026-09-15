// Edit > Preferences (DR-172): the undo depth field refuses what the ruling
// refuses, applies on Enter or Close, and discards on Escape or a click
// outside, so a half-typed depth never drops anybody's history.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart'
    show
        RackFormFactor,
        RackPreset,
        RackWidthClass,
        RailType,
        UserRackPresets,
        buildRackPresets,
        kMaxUndoDepth,
        kMinUndoDepth,
        kUserPresetIdPrefix;
import 'package:rackpal_ui/rackpal_ui.dart';

const ValueKey<String> _field = ValueKey('preferences.undoDepth');

/// Opens the dialog over a bare app and returns every depth it applies.
Future<List<int>> _open(WidgetTester tester, {int undoDepth = 200}) async {
  final applied = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPreferencesDialog(
              context,
              undoDepth: undoDepth,
              onUndoDepthChanged: applied.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return applied;
}

/// One preset of yours (DR-176).
const _mine = RackPreset(
  id: '${kUserPresetIdPrefix}studio-16u',
  displayName: 'Studio 16U',
  heightU: 16,
  formFactor: RackFormFactor.floorEnclosure,
  widthClass: RackWidthClass.eia19,
  railType: RailType.squareCageNut,
);

/// Opens the dialog WITH the rack presets section, and returns every value
/// it hands back.
Future<List<UserRackPresets>> _openWithPresets(WidgetTester tester) async {
  final changes = <UserRackPresets>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPreferencesDialog(
              context,
              undoDepth: 200,
              onUndoDepthChanged: (_) {},
              seededPresets: buildRackPresets(),
              rackPresets: const UserRackPresets(presets: [_mine]),
              onRackPresetsChanged: changes.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return changes;
}

void main() {
  group('rack presets (DR-176)', () {
    testWidgets('the section is absent when no presets are given', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text(kRackPresetsSectionLabel), findsNothing);
    });

    testWidgets('Delete hands back your presets without that one', (
      tester,
    ) async {
      final changes = await _openWithPresets(tester);
      final delete = find.byKey(ValueKey(presetDeleteKeyFor(_mine.id)));
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(changes.single.presets, isEmpty);
    });

    testWidgets('unticking a seeded preset hides it, and ticking it shows it '
        'again', (tester) async {
      final changes = await _openWithPresets(tester);
      final wallBox = find.byKey(ValueKey(presetShowKeyFor('wallBox6U')));
      await tester.ensureVisible(wallBox);
      await tester.tap(wallBox);
      await tester.pumpAndSettle();
      expect(changes.last.hiddenSeedIds, {'wallBox6U'});

      await tester.tap(wallBox);
      await tester.pumpAndSettle();
      expect(changes.last.hiddenSeedIds, isEmpty);
    });

    testWidgets('Rename refuses a seeded name, then renames and keeps the id', (
      tester,
    ) async {
      final changes = await _openWithPresets(tester);
      final rename = find.byKey(ValueKey(presetRenameKeyFor(_mine.id)));
      await tester.ensureVisible(rename);
      await tester.tap(rename);
      await tester.pumpAndSettle();

      const nameField = ValueKey('preferences.rename-name');
      const confirm = ValueKey('preferences.rename-confirm');
      await tester.enterText(find.byKey(nameField), 'Data 42U / 36 in');
      await tester.tap(find.byKey(confirm));
      await tester.pumpAndSettle();
      expect(changes, isEmpty, reason: 'a seeded name is refused');

      await tester.enterText(find.byKey(nameField), 'Studio 18U');
      await tester.tap(find.byKey(confirm));
      await tester.pumpAndSettle();
      final renamed = changes.single.presets.single;
      expect(renamed.displayName, 'Studio 18U');
      expect(renamed.id, _mine.id);
    });
  });

  testWidgets('it opens on the depth in force, with the range in its help', (
    tester,
  ) async {
    await _open(tester, undoDepth: 350);

    expect(find.text('Preferences'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(_field)).controller!.text,
      '350',
    );
    expect(find.text(kUndoDepthHelp), findsOneWidget);
    expect(kUndoDepthHelp, contains('$kMinUndoDepth to $kMaxUndoDepth'));
  });

  for (final (typed, message) in [
    ('49', 'Between 50 and 1000.'),
    ('1001', 'Between 50 and 1000.'),
    ('lots', 'Whole numbers only.'),
    ('', 'Whole numbers only.'),
  ]) {
    testWidgets('refuses [$typed] on Close, applies nothing, and stays open', (
      tester,
    ) async {
      final applied = await _open(tester);

      await tester.enterText(find.byKey(_field), typed);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(applied, isEmpty);
      expect(find.text('Preferences'), findsOneWidget);
    });
  }

  testWidgets('Enter applies an accepted depth once, and closes', (
    tester,
  ) async {
    final applied = await _open(tester);

    await tester.enterText(find.byKey(_field), '500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(applied, [500]);
    expect(find.text('Preferences'), findsNothing);
  });

  testWidgets('Close with the depth unchanged applies nothing', (tester) async {
    final applied = await _open(tester);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(applied, isEmpty);
    expect(find.text('Preferences'), findsNothing);
  });

  testWidgets('Escape discards what was typed, so a half-typed depth drops '
      'nothing', (tester) async {
    final applied = await _open(tester);

    await tester.enterText(find.byKey(_field), '60');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(applied, isEmpty);
    expect(find.text('Preferences'), findsNothing);
  });

  testWidgets('a click outside the dialog discards it too', (tester) async {
    final applied = await _open(tester);

    await tester.enterText(find.byKey(_field), '60');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(applied, isEmpty);
    expect(find.text('Preferences'), findsNothing);
  });
}
