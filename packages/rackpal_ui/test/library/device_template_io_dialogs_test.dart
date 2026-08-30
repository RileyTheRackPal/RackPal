// DR-101 §11.100's two dialogs, driven by real taps.
//
// `session_prompts.dart`'s split is why these are here and not folded
// into the controller's tests: the BRANCHES live in core's
// `template_import.dart` and are tested there without a widget; what is
// left for this file is that the buttons say what the ruling says and pop
// what they claim to.
//
// THE COPY ASSERTIONS ARE THE POINT OF THIS FILE, and this repository has
// a practice about that: `1 ports` shipped once under a dozen green
// `contains` assertions that could not see grammar. So the summary line
// is asserted as a WHOLE STRING at the counts where it changes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

TemplateBody _body({
  String displayName = 'HDMI Matrix 16x16',
  int ports = 68,
  int banks = 6,
  int frontU = 4,
  int rearU = 0,
  MountMethod mountMethod = MountMethod.rackEars,
}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: displayName,
  frontU: frontU,
  rearU: rearU,
  mountMethod: mountMethod,
  banks: [
    for (var i = 0; i < banks; i++)
      BankDef(
        key: 'b$i',
        label: 'Bank $i',
        abbr: 'B$i',
        order: FracIndex('a$i'),
      ),
  ],
  ports: [
    for (var i = 0; i < ports; i++)
      PortDef(
        key: PortKey('p$i'),
        label: 'P$i',
        order: FracIndex('a$i'),
        connector: const ConnectorTypeId('conn.hdmi_a'),
        signalFamily: const SignalFamilyId('video.hdmi.2_0'),
        face: Face.rear,
        position: _somewhere,
      ),
  ],
);

/// A panel position these dialogs never read. Required by `PortDef` and
/// irrelevant here: nothing in this file draws a panel.
const PanelPosition _somewhere = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

DeviceTemplateFile _file(TemplateBody body) => DeviceTemplateFile(
  templateId: const TemplateId('tpl.mx'),
  version: 1,
  contentHash: 'unhashed:tpl.mx@1',
  body: body,
);

PlaceableTemplate _row(String name, int version) => PlaceableTemplate(
  templateId: TemplateId('tpl.${name.toLowerCase()}'),
  version: version,
  body: _body(displayName: name),
  provenance: TemplateProvenance.project,
);

/// Pumps a button that opens the dialog, and returns what popped.
Future<T?> _open<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext) show,
) async {
  T? popped;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => popped = await show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

void main() {
  group('the summary line, asserted as whole strings', () {
    test('singulars, because `1 ports` shipped once already', () {
      expect(portsAcrossBanks(1, 1), '1 port across 1 bank');
      expect(portsAcrossBanks(68, 6), '68 ports across 6 banks');
      expect(
        portsAcrossBanks(4, 0),
        '4 ports',
        reason: '`4 ports across 0 banks` reads as a defect',
      );
      expect(portsAcrossBanks(0, 0), '0 ports');
    });

    test('occupancy does not print 0U for a device that mounts in no rack', () {
      // `0U` is a REAL and different claim in this product: OccupancySide
      // carries zeroUVertical and MountMethod carries notInRack. Reading
      // one for the other is the collapse G4 refuses.
      expect(
        occupancySummary(_body(mountMethod: MountMethod.notInRack)),
        'Not rack-mounted',
      );
      // NO ROW HERE PASSES `_body`'s OWN DEFAULT, and that is worth a
      // line: `frontU: 4` would match it, so a row written that way
      // asserts against a value the helper supplied rather than one this
      // case chose. It is the same false pass §5.3.21 found twice in one
      // issue, and the analyzer happens to flag it as a redundant
      // argument, which is how it was noticed here.
      expect(occupancySummary(_body(frontU: 0)), '0U');
      expect(occupancySummary(_body(frontU: 2)), '2U');
      expect(occupancySummary(_body(frontU: 2, rearU: 2)), '2U');
      expect(
        occupancySummary(_body(frontU: 3, rearU: 2)),
        '3U front, 2U rear',
      );
      expect(occupancySummary(_body(frontU: 0, rearU: 3)), '3U rear');
    });

    test('the whole line, printed', () {
      expect(
        templateSummaryLine(_body()),
        '68 ports across 6 banks · 4U',
      );
    });
  });

  group('the import confirmation', () {
    testWidgets('says the inert-data sentence, in full', (tester) async {
      // A `contains("no scripts")` would stay green over a rewrite that
      // dropped the second half, which is why the constant is asserted.
      await _open(
        tester,
        (c) => showImportTemplateConfirm(
          c,
          plan: TemplateImportPlan(file: _file(_body())),
        ),
      );
      expect(find.text(kInertDataNotice), findsOneWidget);
      expect(
        kInertDataNotice,
        'A device template is data. It contains no scripts and nothing '
        'that runs.',
      );
    });

    testWidgets('prints what is actually in the file', (tester) async {
      await _open(
        tester,
        (c) => showImportTemplateConfirm(
          c,
          plan: TemplateImportPlan(file: _file(_body())),
        ),
      );
      expect(find.text('HDMI Matrix 16x16'), findsOneWidget);
      expect(find.text('68 ports across 6 banks · 4U'), findsOneWidget);
    });

    testWidgets('with no collision it offers ONE import button', (
      tester,
    ) async {
      await _open(
        tester,
        (c) => showImportTemplateConfirm(
          c,
          plan: TemplateImportPlan(file: _file(_body())),
        ),
      );
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Add as a new version of it'), findsNothing);
      expect(find.text('Import as a separate template'), findsNothing);
    });

    testWidgets('a collision names the INCUMBENT and offers both doors', (
      tester,
    ) async {
      // The id is a slug of the display name, so the two spellings differ
      // while colliding. Printing the incoming name would show the user a
      // string compared with itself.
      await _open(
        tester,
        (c) => showImportTemplateConfirm(
          c,
          plan: TemplateImportPlan(
            file: _file(_body(displayName: 'hdmi matrix 16X16')),
            collision: const TemplateImportCollision(
              templateId: TemplateId('tpl.mx'),
              incumbentDisplayName: 'HDMI Matrix 16x16',
              incumbentLatestVersion: 3,
            ),
          ),
        ),
      );
      expect(
        find.text(
          'A device template named "HDMI Matrix 16x16" is already in this '
          'project (version 3).',
        ),
        findsOneWidget,
      );
      expect(find.text('Add as a new version of it'), findsOneWidget);
      expect(find.text('Import as a separate template'), findsOneWidget);
      expect(
        find.text('Import'),
        findsNothing,
        reason: 'the unconditional import button is not offered beside them',
      );
    });

    testWidgets('each button pops the choice it names', (tester) async {
      for (final (label, expected) in <(String, ImportTemplateChoice)>[
        ('Add as a new version of it', ImportTemplateChoice.newVersion),
        (
          'Import as a separate template',
          ImportTemplateChoice.separateTemplate,
        ),
        ('Cancel', ImportTemplateChoice.cancel),
      ]) {
        ImportTemplateChoice? got;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async => got = await showImportTemplateConfirm(
                    context,
                    plan: TemplateImportPlan(
                      file: _file(_body()),
                      collision: const TemplateImportCollision(
                        templateId: TemplateId('tpl.mx'),
                        incumbentDisplayName: 'MX',
                        incumbentLatestVersion: 1,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(got, expected, reason: '"$label" popped the wrong choice');
      }
    });

    testWidgets('dismissing is a CANCEL and never an import', (tester) async {
      // The only non-destructive reading of "the dialog went away". The
      // future completes with null and the wrapper turns that into
      // `cancel`, so this has to be read AFTER the dismissal settles: an
      // earlier version of this test tapped the barrier and then asserted
      // nothing at all, which is a green line proving the dialog opened.
      ImportTemplateChoice? got;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => got = await showImportTemplateConfirm(
                  context,
                  plan: TemplateImportPlan(file: _file(_body())),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(got, isNull, reason: 'nothing has popped while it is open');

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(
        got,
        ImportTemplateChoice.cancel,
        reason: 'a barrier tap must not be read as consent to import',
      );
    });

    testWidgets('AC-042: an edited file WARNS and still offers Import', (
      tester,
    ) async {
      // The first surface `contentHash` has ever had (`#795`). AC-042
      // rules a mismatch a warning and a badge and NEVER a load failure,
      // so the buttons are unchanged: refusing to open a file because
      // somebody hand-edited it is a data-loss event dressed as a safety
      // feature.
      await _open(
        tester,
        (c) => showImportTemplateConfirm(
          c,
          plan: TemplateImportPlan(
            file: _file(_body()),
            hashVerdict: false,
          ),
        ),
      );
      expect(find.text(kHashMismatchWarning), findsOneWidget);
      expect(
        find.text('Import'),
        findsOneWidget,
        reason: 'the warning does not take the button away',
      );
    });

    testWidgets('a file with NO hash is not warned about', (tester) async {
      // The third state, and the one that decides whether this feature
      // is usable at all: every `.rmdx` written before `#795` carries a
      // placeholder, and warning about those would fire on every file
      // this product has ever produced.
      await _open(
        tester,
        (c) => showImportTemplateConfirm(
          c,
          plan: TemplateImportPlan(file: _file(_body())),
        ),
      );
      expect(find.text(kHashMismatchWarning), findsNothing);
    });

    testWidgets('a file that VERIFIES is not warned about either', (
      tester,
    ) async {
      await _open(
        tester,
        (c) => showImportTemplateConfirm(
          c,
          plan: TemplateImportPlan(file: _file(_body()), hashVerdict: true),
        ),
      );
      expect(find.text(kHashMismatchWarning), findsNothing);
    });

    test('the warning says EDITED, not corrupt or tampered', () {
      // A hand-edited .rmdx is a supported thing to have, and the common
      // cause is somebody fixing a label in a text editor. Copy that
      // implied an attack would be wrong about the usual case and would
      // train people to distrust their own files.
      expect(kHashMismatchWarning, contains('edited'));
      expect(kHashMismatchWarning, isNot(contains('corrupt')));
      expect(kHashMismatchWarning, isNot(contains('tamper')));
      expect(
        kHashMismatchWarning,
        contains('allowed'),
        reason: 'and it says so, rather than only implying it',
      );
    });

    test('the choice maps to core in exactly one place', () {
      expect(resolutionFor(ImportTemplateChoice.cancel), isNull);
      expect(resolutionFor(ImportTemplateChoice.importIt), isNull);
      expect(
        resolutionFor(ImportTemplateChoice.newVersion),
        TemplateImportResolution.newVersion,
      );
      expect(
        resolutionFor(ImportTemplateChoice.separateTemplate),
        TemplateImportResolution.separateTemplate,
      );
    });
  });

  group('the export chooser', () {
    testWidgets('lists every template with its version', (tester) async {
      await _open(
        tester,
        (c) => showExportTemplateChooser(
          c,
          templates: [_row('Matrix', 3), _row('Switcher', 1)],
        ),
      );
      expect(find.text('Matrix'), findsOneWidget);
      expect(find.text('Switcher'), findsOneWidget);
      expect(
        find.text('v3 · 68 ports across 6 banks · 4U'),
        findsOneWidget,
        reason: 'the version is printed: what leaves the machine is one',
      );
    });

    testWidgets('Export is disabled until a row is chosen', (tester) async {
      await _open(
        tester,
        (c) => showExportTemplateChooser(
          c,
          templates: [_row('Matrix', 1), _row('Switcher', 1)],
        ),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Switcher'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('one template is preselected; two are not', (tester) async {
      await _open(
        tester,
        (c) => showExportTemplateChooser(c, templates: [_row('Matrix', 1)]),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
        reason: 'a list of one asks a question it already knows the answer to',
      );
    });

    testWidgets('it pops the row that was tapped', (tester) async {
      PlaceableTemplate? got;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => got = await showExportTemplateChooser(
                  context,
                  templates: [_row('Matrix', 3), _row('Switcher', 1)],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switcher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export…'));
      await tester.pumpAndSettle();
      expect(got?.body.displayName, 'Switcher');
    });
  });
}
