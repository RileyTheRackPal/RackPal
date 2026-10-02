// The logo row in File ▸ Sheet set… (`#590`, DR-216 §11.215.3, DR-217
// §11.216.3).
//
// Under the Integrator group: Choose with none; a thumbnail, its pixel size,
// Replace and Remove with one; the refusal shown in the dialog itself; and
// no row at all when the shell supplies no way to choose.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

const ProjectLogo _logo = ProjectLogo(
  imageMember: '${kLogoMemberDir}firm.png',
  format: PlanImageFormat.png,
  pixelWidth: 834,
  pixelHeight: 375,
  contentHash: 'sha256:firm',
);

/// A valid one-pixel PNG. Only its presence matters here; what a logo
/// decodes to is the import's concern.
final Uint8List _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

RackDocument _doc({ProjectLogo? logo}) {
  final when = DateTime.utc(2026, 10);
  return RackDocument(
    id: const Uuid('doc-logo'),
    appVersion: '0.6.60',
    createdAt: when,
    modifiedAt: when,
    meta: EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'test'),
    info: ProjectInfo(projectName: 'Logo', logo: logo),
  );
}

Future<List<Command<RackDocument>>> _open(
  WidgetTester tester,
  RackDocument doc, {
  ChooseLogo? onChooseLogo,
}) async {
  final ran = <Command<RackDocument>>[];
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSheetSetDialog(
              context,
              doc: doc,
              onChooseLogo: onChooseLogo,
              logoBytes: (member) => member == _logo.imageMember ? _png : null,
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

final Finder _list = find
    .descendant(
      of: find.byKey(kSheetSetListKey),
      matching: find.byType(Scrollable),
    )
    .first;

/// Builds the row, then puts it on screen (`scrollUntilVisible` stops at
/// built).
Future<void> _reveal(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(find.byKey(key), 100, scrollable: _list);
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('WITH NONE: Choose logo…, no preview and nothing to remove', (
    tester,
  ) async {
    await _open(tester, _doc(), onChooseLogo: () async => null);
    await _reveal(tester, kChooseLogoKey);
    expect(find.text('Choose logo…'), findsOneWidget);
    expect(find.byKey(kLogoThumbnailKey), findsNothing);
    expect(find.byKey(kRemoveLogoKey), findsNothing);
  });

  testWidgets('THE ROW SITS UNDER THE INTEGRATOR, beside the firm it marks', (
    tester,
  ) async {
    await _open(tester, _doc(), onChooseLogo: () async => null);
    // FROM THE LICENCE DOWN: the list builds lazily, so the row above the
    // one revealed may not exist.
    await _reveal(
      tester,
      projectInfoFieldKey(ProjectInfoFields.integratorLicense),
    );
    final licence = tester.getTopLeft(
      find.byKey(projectInfoFieldKey(ProjectInfoFields.integratorLicense)),
    );
    final logo = tester.getTopLeft(find.text('Logo'));
    final drawnBy = tester.getTopLeft(
      find.byKey(projectInfoFieldKey(ProjectInfoFields.drawnBy)),
    );
    expect(logo.dy, greaterThan(licence.dy));
    expect(logo.dy, lessThan(drawnBy.dy));
  });

  testWidgets('WITH ONE: the preview, its size, Replace and Remove', (
    tester,
  ) async {
    await _open(tester, _doc(logo: _logo), onChooseLogo: () async => null);
    await _reveal(tester, kLogoThumbnailKey);
    expect(
      find.descendant(
        of: find.byKey(kLogoThumbnailKey),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byKey(kLogoThumbnailKey)), const Size(200, 90));
    expect(find.text('834 × 375 px'), findsOneWidget);
    expect(find.text('Replace logo…'), findsOneWidget);
    expect(find.byKey(kRemoveLogoKey), findsOneWidget);
  });

  testWidgets('REMOVE is one command, and the row returns to Choose', (
    tester,
  ) async {
    final doc = _doc(logo: _logo);
    final ran = await _open(tester, doc, onChooseLogo: () async => null);
    await _reveal(tester, kRemoveLogoKey);
    await tester.tap(find.byKey(kRemoveLogoKey));
    await tester.pumpAndSettle();
    expect(ran, hasLength(1));
    expect(ran.single, isA<SetProjectLogoCommand>());
    expect(doc.info.logo, isNull);
    // THE ROW SHRANK BY THE PREVIEW, which scrolls it out of the built
    // range; back to the top and down again to find it.
    await tester.drag(_list, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await _reveal(tester, kChooseLogoKey);
    expect(find.text('Choose logo…'), findsOneWidget);
  });

  testWidgets('CHOOSE shows the new logo once the shell has set it', (
    tester,
  ) async {
    final doc = _doc();
    await _open(
      tester,
      doc,
      onChooseLogo: () async {
        SetProjectLogoCommand.to(doc.info, _logo).apply(doc);
        return const Ok(_logo);
      },
    );
    await _reveal(tester, kChooseLogoKey);
    await tester.tap(find.byKey(kChooseLogoKey));
    await tester.pumpAndSettle();
    expect(find.byKey(kLogoThumbnailKey), findsOneWidget);
    expect(find.text('Replace logo…'), findsOneWidget);
  });

  testWidgets('A REFUSAL IS SHOWN IN THE DIALOG, not behind it', (
    tester,
  ) async {
    await _open(
      tester,
      _doc(),
      onChooseLogo: () async =>
          const Err<ProjectLogo>('That file is not a logo.'),
    );
    await _reveal(tester, kChooseLogoKey);
    await tester.tap(find.byKey(kChooseLogoKey));
    await tester.pumpAndSettle();
    expect(find.text('That file is not a logo.'), findsOneWidget);
  });

  testWidgets('NO WAY TO CHOOSE, NO ROW: a control with no host is not '
      'offered', (tester) async {
    await _open(tester, _doc());
    await tester.scrollUntilVisible(
      find.byKey(projectInfoFieldKey(ProjectInfoFields.drawnBy)),
      100,
      scrollable: _list,
    );
    expect(find.byKey(kChooseLogoKey), findsNothing);
    expect(find.text('Logo'), findsNothing);
  });
}
