// The page picker (PLAN-D/3, DR-037 §11.36.2, DR-138).
//
// ═══════════════════════════════════════════════════════════════════════
// THE TILES ARE ANCHORED ON THEIR PAGE NUMBER, NEVER ON `byType().first`
// ═══════════════════════════════════════════════════════════════════════
// A grid is exactly where `find.byType(...).first` locates the wrong cell
// and PASSES: every tile is the same widget, so a test that picks the
// first one proves nothing about which page it clicked. Every case below
// walks from the "Page N" text to its ancestor tile, so a reordering or an
// off-by-one in the grid fails here rather than shipping.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// A tiny valid JPEG header. Flutter's decoder will fail on it, which is
/// deliberate: these cases are about the GRID, and every tile then takes
/// the `errorBuilder` path, so a passing case cannot be an accident of one
/// image happening to decode.
Uint8List stubJpeg(int w, int h) => Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xC0,
  0x00,
  0x11,
  0x08,
  (h >> 8) & 0xFF,
  h & 0xFF,
  (w >> 8) & 0xFF,
  w & 0xFF,
  0x03,
  0x01,
  0x22,
  0x00,
  0x02,
  0x11,
  0x01,
  0x03,
  0x11,
  0x01,
  0xFF,
  0xD9,
]);

Ok<LiftedPdfPage> liftable(int index, {int w = 2160, int h = 1440}) => Ok(
  LiftedPdfPage(
    pageIndex: index,
    bytes: stubJpeg(w, h),
    header: ImageHeader(
      format: PlanImageFormat.jpeg,
      pixelWidth: w,
      pixelHeight: h,
    ),
    sheetWidthPt: 2592,
    sheetHeightPt: 1728,
  ),
);

Err<LiftedPdfPage> refused(int index, String reason) =>
    Err(PdfPageNotLiftableError(pageIndex: index, reason: reason));

/// Opens the picker over a real route and hands back a handle on what it
/// eventually returns.
///
/// **ONE HELPER, BECAUSE THE FIRST DRAFT HAD TWO AND THAT WAS THE BUG.**
/// A case that pumped a second widget tree while the first dialog was
/// still open could not tap its own button: the old barrier was still
/// there, absorbing the pointer. The warning said so and the assertion
/// failure did not.
final class PickerHandle {
  PickerHandle();

  LiftedPdfPage? result;
  bool returned = false;
}

Future<PickerHandle> openPicker(
  WidgetTester tester,
  List<Outcome<LiftedPdfPage>> pages, {
  String fileName = 'House-Plan.pdf',
}) async {
  final handle = PickerHandle();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              handle
                ..result = await pickPdfPage(
                  context,
                  pages: pages,
                  fileName: fileName,
                )
                ..returned = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return handle;
}

void main() {
  group('the grid', () {
    testWidgets('shows one tile per page, numbered from 1', (tester) async {
      await openPicker(tester, [liftable(0), liftable(1), liftable(2)]);

      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Page 3'), findsOneWidget);
      expect(find.text('Page 0'), findsNothing);
      expect(find.text('Page 4'), findsNothing);
    });

    testWidgets('states the file name and the page count', (tester) async {
      await openPicker(tester, [liftable(0), liftable(1)]);
      expect(find.text('House-Plan.pdf, 2 pages'), findsOneWidget);
    });

    testWidgets('BOTH COUNTS ARE STATED when a page cannot be used, '
        'because "2 pages" hides one and "1 page" lies about the file', (
      tester,
    ) async {
      await openPicker(tester, [
        liftable(0),
        refused(1, 'paints its own content'),
      ]);
      expect(
        find.text('House-Plan.pdf, 1 of 2 pages can be used'),
        findsOneWidget,
      );
    });

    testWidgets('shows the resolution, which DR-137 made meaningful', (
      tester,
    ) async {
      // 2160 px across a 2592 pt (36 inch) sheet is 60 dpi: the ceiling on
      // what this page can ever show.
      await openPicker(tester, [liftable(0)]);
      expect(find.text('2160 x 1440, 60 dpi'), findsOneWidget);
    });
  });

  group('ONE CLICK IMPORTS, and it must be the page that was clicked', () {
    testWidgets('clicking page 2 returns PAGE 2', (tester) async {
      // THE CASE `byType().first` WOULD PASS WHILE RETURNING PAGE 1.
      // Every tile in a grid is the same widget, so the only honest
      // anchor is the page's own label.
      final handle = await openPicker(tester, [
        liftable(0),
        liftable(1),
        liftable(2),
      ]);

      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();

      expect(handle.returned, isTrue);
      expect(handle.result, isNotNull);
      expect(handle.result!.pageIndex, 1, reason: 'page 2 is index 1');
    });

    testWidgets('and clicking page 3 returns PAGE 3, so the mapping is not '
        'an accident of two', (tester) async {
      final handle = await openPicker(tester, [
        liftable(0),
        liftable(1),
        liftable(2),
      ]);

      await tester.tap(find.text('Page 3'));
      await tester.pumpAndSettle();

      expect(handle.result!.pageIndex, 2);
    });

    testWidgets('A REFUSED TILE IS NOT CLICKABLE, so a disabled page '
        'cannot be imported by tapping its label', (tester) async {
      final handle = await openPicker(tester, [
        refused(0, 'paints its own content'),
      ]);

      await tester.tap(find.text('Page 1'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(handle.returned, isFalse, reason: 'the dialog is still open');
      expect(handle.result, isNull);
      expect(find.text('Page 1'), findsOneWidget);
    });

    testWidgets('Cancel returns nothing', (tester) async {
      final handle = await openPicker(tester, [liftable(0)]);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(handle.returned, isTrue);
      expect(handle.result, isNull);
    });
  });

  group('a refused page says WHY, rather than "unsupported"', () {
    testWidgets('the reason is on the tile', (tester) async {
      await openPicker(tester, [
        liftable(0),
        refused(1, 'paints its own content (a `Tj` operator)'),
      ]);
      expect(
        find.text('paints its own content (a `Tj` operator)'),
        findsOneWidget,
      );
      expect(find.textContaining('unsupported'), findsNothing);
    });

    testWidgets('a refused page is still SHOWN, not dropped', (tester) async {
      // Seventeen live tiles and one that says why, not seventeen tiles
      // and a silence.
      await openPicker(tester, [
        liftable(0),
        refused(1, 'draws 2 images rather than one'),
        liftable(2),
      ]);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Page 3'), findsOneWidget);
    });
  });

  group('pdfHasLiftablePage, the caller guard', () {
    test('is false when every page is refused', () {
      expect(
        pdfHasLiftablePage([refused(0, 'a'), refused(1, 'b')]),
        isFalse,
      );
    });

    test('is true when any page can be lifted', () {
      expect(pdfHasLiftablePage([refused(0, 'a'), liftable(1)]), isTrue);
    });

    test('is false for no pages at all', () {
      expect(pdfHasLiftablePage(const []), isFalse);
    });
  });
}
