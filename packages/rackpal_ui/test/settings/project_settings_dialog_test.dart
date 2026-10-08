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
  List<LibraryFamily> libraryFamilies = const [],
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
              // `#879`: a RuleOverride is signed, so the dialog needs a
              // clock and an author for that one section.
              clock: FixedClock(DateTime.utc(2026, 9, 12)),
              actor: 'test',
              libraryFamilies: libraryFamilies,
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

/// The rule the PICKER shows first, sorted the way it sorts.
///
/// `_firstShown`'s reasoning, for the other list: both are virtualised,
/// so a row chosen for being recognisable is very often below the fold
/// and never built.
RuleMeta _firstOverridable() =>
    (kRulesById.values
            .where(
              (r) => ruleAcceptsAnException(r.ruleId, 'overridden') == null,
            )
            .toList()
          ..sort((a, b) => a.ruleId.compareTo(b.ruleId)))
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
        // Drawn by Sheet set instead, and required there by its own test.
        if (kSettingsDrawnInSheetSet.contains(f.key)) continue;
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

    testWidgets('the collision policy is NOT offered: it governed nothing '
        '(DR-201)', (tester) async {
      // The list is lazy, so the whole of it is walked rather than the
      // first screen searched: absent at every row's scroll position.
      await _open(tester, _doc());
      for (final f in ProjectSettingFields.all) {
        if (kSettingsDrawnInSheetSet.contains(f.key)) continue;
        await tester.scrollUntilVisible(
          find.text(f.label),
          120,
          scrollable: _list,
        );
        expect(
          find.textContaining('collision policy'),
          findsNothing,
          reason: 'at ${f.key}',
        );
      }
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

  group('CR-066: sheet numbering (#347)', () {
    testWidgets('THE CHOICES SAY WHAT THEY PRINT, not the enum, and picking '
        'NCS is one command', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final simple = find.text('Simple (SHEET 5 OF 14)');
      await tester.ensureVisible(simple);
      await tester.pumpAndSettle();
      expect(find.text('ncs'), findsNothing);
      expect(
        find.text(
          'What each title block prints as the sheet number. Every sheet '
          'keeps its own id, like T2.01, either way.',
        ),
        findsOneWidget,
      );
      await tester.tap(simple);
      await tester.pumpAndSettle();
      await tester.tap(find.text('National CAD Standard (T2.01)').last);
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      expect(doc.settings.sheetNumbering, SheetNumbering.ncs);
    });
  });

  group("DR-180: the job's wiring standard", () {
    // THE CASE THIS GROUP EXISTS FOR is the LAST one: getting back to
    // unset. A three-item dropdown was chosen over a two-item one for
    // exactly that, so a test that only proved a standard can be PICKED
    // would pass just as happily against the one-way door the user turned
    // down.

    Future<void> pick(WidgetTester tester, String item) async {
      // SCROLLED TO FIRST: rows above it may grow (the sheet numbering row
      // gained a help line at `#347`), and a tap off screen hits nothing.
      await tester.ensureVisible(find.byKey(kWiringStandardSettingKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kWiringStandardSettingKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    testWidgets('an untouched project reads "Not stated" rather than showing '
        'an empty box or assuming T568B', (tester) async {
      final doc = _doc();
      await _open(tester, doc);
      await tester.scrollUntilVisible(
        find.byKey(kWiringStandardSettingKey),
        120,
        scrollable: _list,
      );
      expect(
        find.descendant(
          of: find.byKey(kWiringStandardSettingKey),
          matching: find.text(kNotStatedLabel),
        ),
        findsOneWidget,
      );
      expect(doc.settings.wiringStandard, isNull);
    });

    testWidgets('picking one writes it', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      await tester.scrollUntilVisible(
        find.byKey(kWiringStandardSettingKey),
        120,
        scrollable: _list,
      );
      await pick(tester, 'T568B');

      expect(doc.settings.wiringStandard, WiringStandard.t568b);
      expect(ran, hasLength(1));
      final cmd = ran.single as SetProjectSettingCommand<WiringStandard?>;
      expect(cmd.field.key, ProjectSettingFields.wiringStandard.key);
    });

    testWidgets('and "Not stated" takes it BACK OFF, which is the whole '
        'reason unset is an item rather than a blank', (tester) async {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568a;
      final ran = await _open(tester, doc);
      await tester.scrollUntilVisible(
        find.byKey(kWiringStandardSettingKey),
        120,
        scrollable: _list,
      );
      await pick(tester, kNotStatedLabel);

      expect(doc.settings.wiringStandard, isNull);
      expect(ran, hasLength(1));
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
      // BUILT, THEN ON SCREEN: the list is virtualised, and the rows above
      // this one grew at `#347`.
      await tester.scrollUntilVisible(field, 100, scrollable: _list);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
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

    testWidgets('an UNKNOWN TOKEN is refused too, and this is the case the '
        'first draft let escape unhandled', (tester) async {
      // `{NOPE}` is not a syntax error: the regex reporter sees it, and
      // `requiredTokens()` throws `UnrecognisedTokenException`, which is a
      // DIFFERENT type from the syntax one. The first draft ran the
      // throwing check first and caught only the syntax type, so typing
      // this into the field threw straight out of a text field.
      final doc = _doc();
      final ran = await _open(tester, doc);
      final was = doc.settings.netNameFormat.pattern;

      // SCROLLED TO FIRST. 'Net name' sits below the fold and a `ListView`
      // never builds it, so the descendant finder matched nothing and
      // `enterText` threw "Bad state: No element" rather than reporting a
      // missing row. The 'Port designator' case above only works without
      // this because it happens to be high in the list.
      await tester.scrollUntilVisible(
        find.text('Net name'),
        120,
        scrollable: _list,
      );
      final field = find.descendant(
        of: find.widgetWithText(ListTile, 'Net name'),
        matching: find.byType(TextField),
      );
      // BUILT, THEN ON SCREEN: the list is virtualised, and the rows above
      // this one grew at `#347`.
      await tester.scrollUntilVisible(field, 100, scrollable: _list);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'N{NOPE}');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'it must not throw');
      expect(ran, isEmpty);
      expect(doc.settings.netNameFormat.pattern, was);
      expect(find.textContaining('Unknown token'), findsOneWidget);
    });

    testWidgets('a pattern it CAN read is accepted', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final field = find.descendant(
        of: find.widgetWithText(ListTile, 'Port designator'),
        matching: find.byType(TextField),
      );
      // BUILT, THEN ON SCREEN: the list is virtualised, and the rows above
      // this one grew at `#347`.
      await tester.scrollUntilVisible(field, 100, scrollable: _list);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
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

  // ═══════════════════════════════════════════════════════════════════
  // `#879` — the per-project rule severity, which had no route at all
  // ═══════════════════════════════════════════════════════════════════
  // `SetRuleOverrideCommand` shipped at M5-B3 with a real revert and
  // eight test constructions. `showRuleSeverityDialog` shipped with its
  // own suite. `RuleOverride` carries the severity, the reason, the
  // author and the date, all persisted and all printed on `T0.02`.
  // NOTHING OPENED THE DIALOG, so none of it could be reached.
  group('`#879`: a rule severity is a standing decision, taken here', () {
    /// Scrolls the SETTINGS list, using the `_list` finder this file
    /// already worked out: a descendant finder matching several
    /// scrollables throws "Bad state: Too many elements", which is the
    /// mistake its own comment records and the one this helper repeated
    /// on its first draft.
    Future<void> scrollToSection(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text(kOverrideARule),
        200,
        scrollable: _list,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an untouched project says so, rather than showing an '
        'empty box', (tester) async {
      final doc = _doc();
      await _open(tester, doc);
      await scrollToSection(tester);

      expect(
        find.textContaining('No rule is overridden'),
        findsOneWidget,
        reason: 'an empty list with no sentence reads as a broken panel',
      );
    });

    testWidgets('overriding one emits the command, with the reason and the '
        'author on it', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      await scrollToSection(tester);

      await tester.tap(find.text(kOverrideARule));
      await tester.pumpAndSettle();

      // THE FIRST ROW THE PICKER SHOWS, not a rule id chosen for being
      // familiar. This file's `_firstShown` already records why: the
      // list is virtualised, so a row below the fold is never built and
      // `tap` reports "found 0 widgets" rather than tapping the wrong
      // one. The first draft here asked for PWR-003 and met exactly
      // that.
      final rule = _firstOverridable();
      await tester.tap(find.text(rule.ruleId));
      await tester.pumpAndSettle();

      // THE SEVERITY DIALOG, NOT THE SETTINGS ONE UNDERNEATH IT. Both
      // are `AlertDialog`s and the settings dialog is still in the tree,
      // so `find.byType(AlertDialog)` matches two and a descendant
      // finder throws "Bad state: Too many elements". Anchoring on the
      // confirm button names the one that is on top without depending on
      // overlay order.
      final severityDialog = find.ancestor(
        of: find.text(kSeverityApply),
        matching: find.byType(AlertDialog),
      );
      await tester.tap(
        find.descendant(
          of: severityDialog,
          matching: find.text(Severity.warning.name),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: severityDialog,
          matching: find.byType(TextField),
        ),
        'Existing strip stays; agreed with the owner.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(kSeverityApply));
      await tester.pumpAndSettle();

      expect(ran.whereType<SetRuleOverrideCommand>(), hasLength(1));
      final written = doc.settings.ruleOverrides[rule.ruleId];
      expect(written, isNotNull);
      expect(written!.severity, Severity.warning);
      expect(written.reason, 'Existing strip stays; agreed with the owner.');
      expect(
        written.by,
        'test',
        reason: 'the author is half of what makes it a signed decision',
      );
    });

    testWidgets('the row shows the REASON, because that is what prints on '
        'T0.02', (tester) async {
      final doc = _doc();
      doc.settings.ruleOverrides['PWR-003'] = RuleOverride(
        severity: Severity.warning,
        reason: 'Existing strip stays.',
        by: 'test',
        at: DateTime.utc(2026, 9, 12),
      );
      await _open(tester, doc);
      await scrollToSection(tester);

      expect(find.text('Existing strip stays.'), findsOneWidget);
      expect(find.textContaining('PWR-003'), findsWidgets);
    });

    testWidgets('and clearing it removes the entry rather than writing the '
        'default back', (tester) async {
      final doc = _doc();
      doc.settings.ruleOverrides['PWR-003'] = RuleOverride(
        severity: Severity.warning,
        reason: 'Existing strip stays.',
        by: 'test',
        at: DateTime.utc(2026, 9, 12),
      );
      final ran = await _open(tester, doc);
      await scrollToSection(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('rule-override-PWR-003')),
          matching: find.text('Clear'),
        ),
      );
      await tester.pumpAndSettle();

      expect(ran.whereType<SetRuleOverrideCommand>(), hasLength(1));
      expect(
        doc.settings.ruleOverrides.containsKey('PWR-003'),
        isFalse,
        reason:
            'an override that AGREES with the default still reports as '
            'overridden and still prints its reason, so clearing has to '
            'remove the row',
      );
    });

    testWidgets('choosing "use the default" REMOVES the override rather '
        'than recording one that agrees with it', (tester) async {
      // A MUTATION NAMED THIS GAP. Making the null severity write an
      // override instead of clearing one SURVIVED, because nothing here
      // opened an existing row and chose the default.
      //
      // The distinction is the dialog's own typedef: *"a severity that
      // happens to equal the default is a different act from choosing
      // the default: the first removes the override, the second records
      // a standing decision that agrees with it and prints its reason on
      // T0.02."*
      final rule = overridableRules().first;
      final doc = _doc();
      doc.settings.ruleOverrides[rule.ruleId] = RuleOverride(
        severity: Severity.warning,
        reason: 'Was agreed; no longer applies.',
        by: 'test',
        at: DateTime.utc(2026, 9, 12),
      );
      final ran = await _open(tester, doc);
      await scrollToSection(tester);

      // TAPPING THE ROW re-opens the control pre-filled, which is the
      // only route to the default option.
      await tester.tap(find.byKey(ValueKey('rule-override-${rule.ruleId}')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(severityUseDefault(rule.defaultSeverity)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kSeverityApply));
      await tester.pumpAndSettle();

      expect(ran.whereType<SetRuleOverrideCommand>(), hasLength(1));
      expect(
        doc.settings.ruleOverrides.containsKey(rule.ruleId),
        isFalse,
        reason:
            'an override that agrees with the default still reports as '
            'overridden and still prints, so the default option has to '
            'remove the row rather than rewrite it',
      );
    });

    testWidgets('the picker lists what CORE says is overridable, in its '
        'order', (tester) async {
      // THE FIRST DRAFT ASSERTED A TIER-1 RULE WAS ABSENT AND WAS
      // VACUOUS. The picker is virtualised, so a tier-1 row below the
      // fold is never built and `findsNothing` passes whether the rule
      // was excluded or merely out of sight; a mutation that deleted the
      // filter SURVIVED. The exclusion is now `overridableRules()` and
      // `rule_override_command_test.dart` reads every rule to prove it.
      // What is left for THIS file is that the picker shows that list,
      // which its first row can say without being built lazily.
      final doc = _doc();
      await _open(tester, doc);
      await scrollToSection(tester);

      await tester.tap(find.text(kOverrideARule));
      await tester.pumpAndSettle();

      expect(
        find.text(overridableRules().first.ruleId),
        findsOneWidget,
        reason: "the picker renders core's list, in core's order",
      );
    });
  });

  testWidgets('Signal families lists a clone by its parent, and its button '
      'opens the clone dialog at the parent (SFE-C1)', (tester) async {
    final doc = _doc();
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

    await _open(tester, doc);
    await tester.scrollUntilVisible(
      find.byKey(kCloneFamilyButtonKey),
      120,
      scrollable: _list,
    );
    await tester.ensureVisible(find.byKey(kCloneFamilyButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Vantage'), findsOneWidget);
    expect(find.textContaining('clone of Cresnet'), findsOneWidget);

    await tester.tap(find.byKey(kCloneFamilyButtonKey));
    await tester.pumpAndSettle();
    // The parent comes first: the picker, and no name field yet.
    expect(find.byKey(const ValueKey('service-filter')), findsOneWidget);
    expect(find.byKey(kCloneNameFieldKey), findsNothing);
  });

  testWidgets('a family a library brought that prints like another is '
      'marked, by name, until it does not (DR-245)', (tester) async {
    final doc = _doc();
    final lutron =
        doc.registries.signalFamilies[const SignalFamilyId('ctl.lutron_qs')]!;
    // On Lutron QS's own line, as a hand-made library could carry it.
    doc.registries.signalFamilies[const SignalFamilyId(
      'ctl.clasher',
    )] = SignalFamilyDef(
      id: const SignalFamilyId('ctl.clasher'),
      displayName: 'Clasher',
      domain: lutron.domain,
      defaultConnector: lutron.defaultConnector,
      defaultDirection: lutron.defaultDirection,
      defaultTopology: lutron.defaultTopology,
      dashOverride: const [10000, 3000],
      lineWeightPermilleOverride: 1000,
      clonedFrom: const SignalFamilyId('ctl.cresnet'),
    );
    await _open(tester, doc);
    const mark = ValueKey('family-clash-ctl.clasher');
    await tester.scrollUntilVisible(
      find.byKey(mark),
      120,
      scrollable: _list,
    );
    expect(
      tester.widget<Text>(find.byKey(mark)).data,
      contains('ctl.lutron_qs'),
    );
    // The warning is an ICON beside the sentence: the bundled face has no
    // `\u26a0` glyph, and the glyph-coverage gate refused it as a box.
    expect(
      find.descendant(
        of: find.ancestor(of: find.byKey(mark), matching: find.byType(Row)),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Change line fixes a clash: a free line picked, the mark goes '
      '(SFE-C7)', (tester) async {
    final doc = _doc();
    final lutron =
        doc.registries.signalFamilies[const SignalFamilyId('ctl.lutron_qs')]!;
    const id = SignalFamilyId('ctl.clasher');
    doc.registries.signalFamilies[id] = SignalFamilyDef(
      id: id,
      displayName: 'Clasher',
      domain: lutron.domain,
      defaultConnector: lutron.defaultConnector,
      defaultDirection: lutron.defaultDirection,
      defaultTopology: lutron.defaultTopology,
      dashOverride: const [10000, 3000],
      lineWeightPermilleOverride: 1000,
      clonedFrom: const SignalFamilyId('ctl.cresnet'),
    );
    final free = cloneHeadroom(
      doc,
      lutron.domain,
      changing: id,
    )!.free.first;
    final ran = await _open(tester, doc);

    const button = ValueKey('change-line-ctl.clasher');
    await tester.scrollUntilVisible(find.byKey(button), 120, scrollable: _list);
    await tester.ensureVisible(find.byKey(button));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('family-clash-ctl.clasher')), findsOne);

    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    final swatch = find.byKey(
      cloneSwatchKey(free.dashPermille, free.weightPermille),
    );
    await tester.ensureVisible(swatch);
    await tester.pumpAndSettle();
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kChangeLineSubmitKey));
    await tester.pumpAndSettle();

    expect(ran.whereType<SetCloneLineCommand>(), hasLength(1));
    expect(doc.registries.signalFamilies[id]!.dashOverride, free.dashPermille);
    expect(familyPrintClash(doc, id), isNull);
    expect(
      find.byKey(const ValueKey('family-clash-ctl.clasher')),
      findsNothing,
    );
  });

  testWidgets('a family from a library is offered, added through the same '
      'rules as a device, and then no longer offered (SFE-C8)', (tester) async {
    final doc = _doc();
    final lutron =
        doc.registries.signalFamilies[const SignalFamilyId('ctl.lutron_qs')]!;
    final vantage = SignalFamilyDef(
      id: const SignalFamilyId('ctl.vantage_2'),
      displayName: 'Vantage',
      domain: lutron.domain,
      defaultConnector: lutron.defaultConnector,
      defaultDirection: lutron.defaultDirection,
      defaultTopology: lutron.defaultTopology,
      shortTag: 'VNT',
      dashOverride: const [4000, 3000],
      lineWeightPermilleOverride: 2000,
      clonedFrom: const SignalFamilyId('ctl.cresnet'),
    );
    final ran = await _open(
      tester,
      doc,
      libraryFamilies: [(libraryName: 'My library', family: vantage)],
    );
    const add = ValueKey('adopt-family-My library-ctl.vantage_2');
    await tester.scrollUntilVisible(find.byKey(add), 120, scrollable: _list);
    await tester.ensureVisible(find.byKey(add));
    await tester.pumpAndSettle();
    expect(find.text('From your libraries'), findsOneWidget);
    expect(find.textContaining('from My library'), findsOneWidget);

    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    expect(ran.whereType<AddArrivedFamiliesCommand>(), hasLength(1));
    expect(doc.registries.signalFamilies[vantage.id], same(vantage));
    expect(find.byKey(add), findsNothing);
    expect(find.text('From your libraries'), findsNothing);
  });
}
