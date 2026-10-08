// SFE-C1 and SFE-C2: the clone dialog, parent first, every line drawn as
// it prints with the taken ones dimmed (DR-122, DR-243, DR-244).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-clone-dialog'),
  appVersion: 'test',
  createdAt: DateTime.utc(2026, 10, 7),
  modifiedAt: DateTime.utc(2026, 10, 7),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026, 10, 7),
    updatedAt: DateTime.utc(2026, 10, 7),
    updatedBy: 'test',
  ),
)..registries = buildSeedRegistries();

/// Opens the dialog from a button, so the command it returns is caught.
Future<List<CloneSignalFamilyCommand?>> _open(
  WidgetTester tester,
  RackDocument doc,
) async {
  final returned = <CloneSignalFamilyCommand?>[];
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                returned.add(await showCloneFamilyDialog(context, doc: doc)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return returned;
}

/// Picks Cresnet from the parent list, through its filter, as a person.
Future<void> _pickCresnet(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('service-filter')),
    'cresnet',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('CTL·Cresnet'));
  await tester.pumpAndSettle();
}

/// Scrolls [swatch] into view and taps it. `scrollUntilVisible` only
/// guarantees the row is BUILT, so `ensureVisible` follows it.
Future<void> _tapSwatch(WidgetTester tester, Finder swatch) async {
  await tester.scrollUntilVisible(
    swatch,
    120,
    scrollable: find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(swatch);
  await tester.pumpAndSettle();
  await tester.tap(swatch);
  await tester.pumpAndSettle();
}

Future<void> _name(WidgetTester tester) async {
  await tester.enterText(find.byKey(kCloneNameFieldKey), 'Vantage');
  await tester.enterText(find.byKey(kCloneTagFieldKey), 'VNT');
  await tester.pumpAndSettle();
}

/// The labels of every swatch the dialog shows as chosen.
List<String?> _selected() => [
  for (final e
      in find
          .byWidgetPredicate(
            (w) => w is Semantics && (w.properties.selected ?? false),
          )
          .evaluate())
    (e.widget as Semantics).properties.label,
];

bool _submitEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(kCloneSubmitKey)).onPressed != null;

void main() {
  testWidgets('the parent comes first, and then stays in view', (
    tester,
  ) async {
    await _open(tester, _doc());
    // Nothing to name yet: the only thing on offer is a parent.
    expect(find.byKey(kCloneNameFieldKey), findsNothing);
    expect(find.byKey(const ValueKey('service-filter')), findsOneWidget);

    await _pickCresnet(tester);
    expect(
      find.descendant(
        of: find.byKey(kCloneParentBannerKey),
        matching: find.text('Clone of Cresnet (ctl.cresnet)'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(kCloneNameFieldKey), findsOneWidget);

    // And the person can go back and choose again.
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.byKey(kCloneNameFieldKey), findsNothing);
  });

  testWidgets('a taken line says what takes it, and cannot be cloned', (
    tester,
  ) async {
    await _open(tester, _doc());
    await _pickCresnet(tester);
    await _name(tester);
    // `10,3` at 1.00x is Lutron QS's line.
    await _tapSwatch(
      tester,
      find.byKey(cloneSwatchKey(const [10000, 3000], 1000)),
    );

    // The tapped swatch is the one shown as chosen. The highlight compared
    // options by identity and never showed until this asked for it.
    expect(_selected(), ['long at 1.00×, taken']);
    // And the sentence is ON SCREEN, which it was not while it sat at the
    // foot of a thirteen-row grid inside the scrolling list.
    final reason = find.byKey(kCloneReasonKey);
    expect(tester.widget<Text>(reason).data, contains('ctl.lutron_qs'));
    expect(
      tester.getRect(reason).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(AlertDialog)).bottom),
    );
    expect(_submitEnabled(tester), isFalse);
  });

  testWidgets('a free line clones, and the command carries what was chosen', (
    tester,
  ) async {
    final doc = _doc();
    final free = cloneHeadroom(doc, const SignalDomainId('ctl'))!.free.first;
    final returned = await _open(tester, doc);
    await _pickCresnet(tester);
    expect(_submitEnabled(tester), isFalse, reason: 'nothing chosen yet');
    await _name(tester);
    await _tapSwatch(
      tester,
      find.byKey(cloneSwatchKey(free.dashPermille, free.weightPermille)),
    );
    // POSITIVELY, not "no reason found": a reason that was never built
    // passed that check vacuously while the verdict sat off screen.
    expect(find.byKey(kCloneFreeKey), findsOneWidget);
    expect(find.byKey(kCloneReasonKey), findsNothing);
    expect(_submitEnabled(tester), isTrue);

    await tester.tap(find.byKey(kCloneSubmitKey));
    await tester.pumpAndSettle();

    final made = returned.single!.family;
    expect(made.displayName, 'Vantage');
    expect(made.shortTag, 'VNT');
    expect(made.clonedFrom, const SignalFamilyId('ctl.cresnet'));
    expect(made.dashOverride, free.dashPermille);
    expect(made.lineWeightPermilleOverride, free.weightPermille);
    // The dialog decided nothing: what it returned applies.
    expect(returned.single!.apply(doc), isTrue);
  });

  testWidgets('every line on the menu is drawn, one swatch per option', (
    tester,
  ) async {
    await _open(tester, _doc());
    await _pickCresnet(tester);
    final menu = cloneMenu();
    final swatches = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('clone-swatch-'),
    );
    expect(swatches, findsNWidgets(menu.dashes.length * menu.weights.length));
  });
}
