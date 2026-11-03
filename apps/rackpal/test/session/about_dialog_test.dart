// `Help ▸ About RackPal…` (DR-189, docs/21 §21.9).
//
// ═══════════════════════════════════════════════════════════════════════
// THE POINT OF THESE CASES IS THAT A LABEL NOBODY CHECKED SHIPS WRONG
// ═══════════════════════════════════════════════════════════════════════
// `kAppVersion` is stamped into every `RackDocument.appVersion` and every
// recovery sidecar, and until this chapter it was displayed NOWHERE, so a
// tester could not say which build they were running and docs/21 had to
// tell them to quote a folder name instead.
//
// A dialog that shows a version is worth nothing if it shows a DIFFERENT
// version from the one the document carries, which is exactly the failure
// `version_parity_test.dart` exists to catch across the six pubspecs. The
// case below asserts the dialog against the same constant the document is
// stamped with, so the two cannot drift.
//
// **AND THE LEGALESE IS ASSERTED FOR WHAT IT REFUSES TO CLAIM.** DR-189
// §11.188.6 sends the output exception to a reviewer (before v1.0, DR-259),
// and `docs/proposed-output-exception.md` carries a NOT IN FORCE banner. An
// About box implying the exception is in force would have the product asserting
// something the repository denies, which is worse than silence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/app_services.dart' show kAppVersion;
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  Future<void> openAbout(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showRackPalAboutDialog(context, version: kAppVersion),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('it shows THE SAME VERSION the document is stamped with', (
    tester,
  ) async {
    await openAbout(tester);

    expect(
      find.textContaining(kAppVersion),
      findsWidgets,
      reason:
          'a tester quotes this number and a support engineer reads the '
          'same one out of their .rppj, so the two are one constant',
    );
    expect(find.textContaining(kAppDisplayName), findsWidgets);
  });

  testWidgets('THE EXCEPTION IS NAMED AS NOT IN FORCE, which is the one '
      'thing this copy must not get wrong', (tester) async {
    await openAbout(tester);

    expect(find.textContaining('Affero'), findsWidgets);
    expect(
      find.textContaining('NOT YET IN FORCE'),
      findsWidgets,
      reason:
          'DR-189 §11.188.6 sends the output exception to a reviewer '
          'first; a dialog implying it already grants something would be '
          'the product contradicting LICENSE-EXCEPTION.md',
    );
    expect(
      find.textContaining('CC0'),
      findsWidgets,
      reason: 'the catalog is deliberately not copyleft (DR-036 §11.35.3)',
    );
  });

  testWidgets('it offers the THIRD-PARTY licence page, which is a '
      'distribution obligation rather than a courtesy', (tester) async {
    await openAbout(tester);

    // Flutter's own button, which opens `showLicensePage` over the whole
    // `LicenseRegistry`. Found case-insensitively because the framework
    // upper-cases it through the theme rather than in the string.
    final button = find.byWidgetPredicate(
      (w) => w is TextButton && _labelOf(w).toLowerCase().contains('license'),
    );
    expect(
      button,
      findsOneWidget,
      reason:
          'every dependency is MIT, BSD-3 or Apache-2.0 and all three '
          'require their notices to travel with the binary; nothing in '
          'this product surfaced them before this chapter',
    );
  });

  testWidgets('it tells the reader WHY the number matters, so a report '
      'carries it', (tester) async {
    await openAbout(tester);
    expect(find.textContaining('Quote this version'), findsOneWidget);
  });
}

String _labelOf(TextButton button) {
  final child = button.child;
  return child is Text ? (child.data ?? '') : '';
}
