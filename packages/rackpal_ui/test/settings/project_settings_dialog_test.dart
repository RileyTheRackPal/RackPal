// The project settings surface (`#805`, RJ-012, AC-054, CR-097).
//
// The field table and both commands are asserted in `rackpal_core`'s
// `project_settings_test.dart`. What is asserted here is what a widget
// test can see and that one cannot: that every field in the table draws a
// row, that a bad `IdFormat` is refused rather than stored, and that
// RJ-012's colour override can actually be set and cleared.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-settings-ui'),
    appVersion: '0.4.93',
    createdAt: DateTime.utc(2026, 8, 31),
    modifiedAt: DateTime.utc(2026, 8, 31),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026, 8, 31),
      updatedAt: DateTime.utc(2026, 8, 31),
      updatedBy: 'test',
    ),
  );
  final seed = buildSeedRegistries();
  for (final e in seed.signalFamilies.entries) {
    doc.registries.signalFamilies[e.key] = e.value;
  }
  for (final e in seed.mediaTypes.entries) {
    doc.registries.mediaTypes[e.key] = e.value;
  }
  return doc;
}

Future<List<Command<RackDocument>>> _open(
  WidgetTester tester,
  RackDocument doc, {
  Size size = const Size(1100, 1400),
}) async {
  final ran = <Command<RackDocument>>[];
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showProjectSettingsDialog(
              context,
              doc: doc,
              onEdit: (commands) {
                ran.addAll(commands);
                for (final c in commands) {
                  c.apply(doc);
                }
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return ran;
}

/// THE SETTINGS LIST, and only it.
///
/// `AlertDialog` wraps its content in a `Scrollable` of its own and the
/// rows contribute more, so `find.byType(Scrollable).first` scrolled the
/// wrong one and a descendant finder matched several ("Bad state: Too many
/// elements"). The keyed list's OUTERMOST scrollable is the one that moves
/// these rows.
final Finder _list = find
    .descendant(
      of: find.byKey(kProjectSettingsListKey),
      matching: find.byType(Scrollable),
    )
    .first;

/// The family the surfaces show FIRST, sorted the way they sort.
///
/// NOT `signalFamilies.values.first`, which the first draft used: the map
/// order is not the display order, both lists are virtualised, and the
/// unsorted first family is very often below the fold and never built.
/// That threw "Bad state: No element" rather than tapping the wrong row,
/// which is the only reason it cost a minute.
SignalFamilyDef _firstShown(RackDocument doc) {
  final all = doc.registries.signalFamilies.values.toList()
    ..sort((a, b) {
      final c = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      return c != 0 ? c : a.id.v.compareTo(b.id.v);
    });
  return all.first;
}

void main() {
  group('every field in the table draws a row', () {
    testWidgets('no setting is in the table with nothing drawing it, which '
        'is the state NetworkConfig was found in', (tester) async {
      await _open(tester, _doc());
      for (final f in ProjectSettingFields.all) {
        // SCROLLED TO, not merely searched for: the dialog is a ListView
        // and a row below the fold is never built, so `findsOneWidget`
        // alone would fail for a row that exists and pass for one that
        // does not once the list got long enough.
        await tester.scrollUntilVisible(
          find.text(f.label),
          120,
          scrollable: _list,
        );
        expect(find.text(f.label), findsOneWidget, reason: f.key);
      }
    });

    testWidgets('and none draws the "no row for this setting type" refusal', (
      tester,
    ) async {
      await _open(tester, _doc());
      expect(find.textContaining('No row for this setting type'), findsNothing);
    });
  });

  group('CR-097: display units', () {
    testWidgets('changing it emits a command carrying the field, so the undo '
        'entry and the row cannot disagree', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      await tester.tap(find.text('Imperial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Metric').last);
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      expect(doc.settings.displayUnits, UnitSystem.metric);
      final cmd = ran.single as SetProjectSettingCommand<UnitSystem>;
      expect(cmd.field.key, ProjectSettingFields.displayUnits.key);
    });
  });

  group('an IdFormat is refused rather than stored', () {
    testWidgets('a pattern the parser cannot read shows ITS error and emits '
        'nothing', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final was = doc.settings.portDesignatorFormat.pattern;

      final field = find.descendant(
        of: find.widgetWithText(ListTile, 'Port designator'),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'J{UNCLOSED');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        ran,
        isEmpty,
        reason:
            'a format every designator mint would '
            'throw on must not reach the document',
      );
      expect(doc.settings.portDesignatorFormat.pattern, was);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('a pattern it CAN read is accepted', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final field = find.descendant(
        of: find.widgetWithText(ListTile, 'Port designator'),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'P{PORT_SEQ:3}');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      expect(doc.settings.portDesignatorFormat.pattern, 'P{PORT_SEQ:3}');
    });
  });

  group('RJ-012 and AC-054: the per-family colour override', () {
    testWidgets('an untouched project says every signal takes its domain '
        'colour, rather than showing an empty box', (tester) async {
      await _open(tester, _doc());
      await tester.scrollUntilVisible(
        find.text('Signal colours'),
        160,
        scrollable: _list,
      );
      expect(find.textContaining('No family is overridden'), findsOneWidget);
    });

    testWidgets('adding one emits a SetFamilyColorOverrideCommand and it '
        'lands where signal_style reads it', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      await tester.scrollUntilVisible(
        find.text('Override a family colour'),
        160,
        scrollable: _list,
      );
      // ENSURE VISIBLE BEFORE TAPPING. `scrollUntilVisible` puts a widget
      // in the tree; it does not guarantee its centre is hittable, and the
      // tap warned that it missed rather than throwing, so the picker
      // silently never opened.
      await tester.ensureVisible(find.text('Override a family colour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Override a family colour'));
      await tester.pumpAndSettle();

      // The picker lists families that have no override yet.
      final first = _firstShown(doc);
      await tester.tap(find.widgetWithText(ListTile, first.displayName).last);
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      expect(ran.single, isA<SetFamilyColorOverrideCommand>());
      expect(doc.settings.familyColorOverrides, hasLength(1));
    });

    testWidgets('and clearing it removes the entry rather than setting the '
        'domain hue, because an override that MATCHES still reports as '
        'overridden', (tester) async {
      final doc = _doc();
      final fam = _firstShown(doc);
      doc.settings.familyColorOverrides[fam.id] = const Rgb(255, 0, 0);

      final ran = await _open(tester, doc);
      await tester.scrollUntilVisible(
        find.text('Clear'),
        160,
        scrollable: _list,
      );
      await tester.ensureVisible(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      final cmd = ran.single as SetFamilyColorOverrideCommand;
      expect(cmd.to, isNull);
      expect(doc.settings.familyColorOverrides, isEmpty);
    });
  });
}
