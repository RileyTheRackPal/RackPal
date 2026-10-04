// The export preview (M6-I4, `#355`, DR-230): the real pages, paged
// through, with the sheet list and the notices beside them, and a missing
// renderer that never holds the file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// A real one-pixel PNG, so `Image.memory` decodes something.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const List<PreviewSheet> _sheets = [
  PreviewSheet(
    ncsId: 'T0.00',
    title: 'COVER AND DRAWING INDEX',
    widthPt: 1224,
    heightPt: 792,
  ),
  PreviewSheet(
    ncsId: 'T2.01',
    title: 'RACK ELEVATION — FRONT · RK-1',
    widthPt: 792,
    heightPt: 1224,
  ),
  PreviewSheet(
    ncsId: 'T6.30',
    title: 'EQUIPMENT LIST AND MATERIALS',
    widthPt: 792,
    heightPt: 612,
  ),
];

void main() {
  late List<(int, int, int)> renders;
  late bool? answer;

  Future<void> open(
    WidgetTester tester, {
    List<String> notices = const ['T6.02: Smallest text is 5.27 pt.'],
    String? countWarning,
    PreviewRender Function(int page)? render,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    renders = [];
    answer = null;
    final preview = ExportPreview(
      projectName: 'Whole House',
      sheets: _sheets,
      sizeLabel: '64 KB',
      notices: notices,
      countWarning: countWarning,
      renderPage: (page, {required width, required height}) {
        renders.add((page, width, height));
        return render?.call(page) ?? PreviewImage(_png);
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                answer = await showExportPreviewDialog(context, preview),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('the header names the project, the count and the size, and '
      'the first page is drawn at its own proportions', (tester) async {
    await open(tester);
    expect(
      find.text('$kExportPreviewTitle · Whole House · 3 sheets · 64 KB'),
      findsOneWidget,
    );
    final (page, w, h) = renders.single;
    expect(page, 0);
    expect(w / h, closeTo(1224 / 792, 0.01), reason: 'landscape cover');
    expect(find.text(exportPreviewPosition(0, 3)), findsOneWidget);
    expect(find.text('T0.00 COVER AND DRAWING INDEX'), findsOneWidget);
  });

  testWidgets('Next, the arrow key and the sheet list each move the page, '
      'and a portrait sheet renders portrait', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('preview-next')));
    await tester.pumpAndSettle();
    expect(find.text(exportPreviewPosition(1, 3)), findsOneWidget);
    final (page, w, h) = renders.last;
    expect(page, 1);
    expect(h, greaterThan(w), reason: 'an elevation is portrait');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text(exportPreviewPosition(2, 3)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('preview-sheet-0')));
    await tester.pumpAndSettle();
    expect(find.text(exportPreviewPosition(0, 3)), findsOneWidget);
  });

  testWidgets('A PAGE IS RENDERED ONCE PER SIZE, not once per frame', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('preview-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preview-previous')));
    await tester.pumpAndSettle();
    expect(renders.where((r) => r.$1 == 0), hasLength(1));
  });

  testWidgets('the notices sit beside the page, and none says so', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(exportPreviewNoticesHeading(1)), findsOneWidget);
    expect(find.text('T6.02: Smallest text is 5.27 pt.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await open(tester, notices: const []);
    expect(find.text(kExportPreviewNoNotices), findsOneWidget);
  });

  testWidgets('past 40 sheets the count carries its warning', (tester) async {
    await open(tester, countWarning: kExportPreviewLargeSet);
    expect(find.text(kExportPreviewLargeSet), findsOneWidget);
  });

  testWidgets('A MISSING RENDERER NEVER HOLDS THE FILE: the page area says '
      'why, and Save still answers yes', (tester) async {
    await open(
      tester,
      render: (_) => const PreviewUnavailable('No renderer here.'),
    );
    expect(find.text('No renderer here.'), findsOneWidget);
    await tester.tap(find.text(kExportPreviewSave));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('Save answers yes and Close answers no', (tester) async {
    await open(tester);
    await tester.tap(find.text(kExportPreviewSave));
    await tester.pumpAndSettle();
    expect(answer, isTrue);

    await open(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });
}
