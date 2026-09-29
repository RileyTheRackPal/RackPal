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

Ok<PdfPageOption> liftable(
  int index, {
  int w = 2160,
  int h = 1440,
  double sheetW = 2592,
  double sheetH = 1728,
  int quarterTurns = 0,
}) => Ok(
  LiftedPageOption(
    LiftedPdfPage(
      pageIndex: index,
      bytes: stubJpeg(w, h),
      header: ImageHeader(
        format: PlanImageFormat.jpeg,
        pixelWidth: w,
        pixelHeight: h,
      ),
      sheetWidthPt: sheetW,
      sheetHeightPt: sheetH,
      quarterTurns: quarterTurns,
    ),
  ),
);

/// A page of vectors, drawn rather than lifted (DR-153, `PLAN-K/4`).
///
/// **THE TILE MUST NOT BE ABLE TO TELL.** The grid is handed both kinds
/// and draws them the same, so the cases below mix them deliberately: a
/// dialog that switched on the variant would pass a suite made of one.
Ok<PdfPageOption> rendered(int index, {int w = 5100, int h = 3300}) => Ok(
  RenderedPageOption(
    pageIndex: index,
    plan: PlanRasterPlan(width: w, height: h, effectiveDpi: 300),
    previewBytes: stubJpeg(320, 207),
  ),
);

Err<PdfPageOption> refused(int index, String reason) =>
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

  PdfPageOption? result;
  bool returned = false;
}

Future<PickerHandle> openPicker(
  WidgetTester tester,
  List<Outcome<PdfPageOption>> pages, {
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

    /// LOAD-BEARING (DR-153, `PLAN-K/4`). The grid draws a THUMBNAIL of a
    /// rendered page, 320 px across, and the caption must describe the
    /// page the person would get instead. A tile reading "320 x 207, 19
    /// dpi" would be reporting the picture it just drew, which is a fact
    /// about this dialog rather than about anything on offer.
    testWidgets('a rendered page reports the size it WILL be, not its '
        'preview', (tester) async {
      await openPicker(tester, [rendered(0)]);

      expect(find.text('5100 x 3300, 300 dpi'), findsOneWidget);
      expect(find.textContaining('320 x'), findsNothing);
    });

    /// `#911`, DR-184 §11.183.6. A scanner writes a landscape sheet as a
    /// PORTRAIT page with `/Rotate 90`: 1440 x 2160 pixels on a 1728 x
    /// 2592 point box. A PDF viewer shows it landscape, and so must the
    /// tile, or the page somebody picks is not the page that arrives.
    testWidgets('A LIFTED PAGE WITH /Rotate 90 IS SHOWN TURNED, and its size '
        'reads the way it is seen', (tester) async {
      await openPicker(tester, [
        liftable(
          0,
          w: 1440,
          h: 2160,
          sheetW: 1728,
          sheetH: 2592,
          quarterTurns: 1,
        ),
      ]);

      expect(find.text('2160 x 1440, 60 dpi'), findsOneWidget);
      final turned = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byType(Image),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(turned.quarterTurns, 1);
    });

    /// The grid is handed both kinds and must not be able to tell.
    testWidgets('a lifted page and a rendered one are both live tiles', (
      tester,
    ) async {
      await openPicker(tester, [liftable(0), rendered(1)]);

      expect(find.text('House-Plan.pdf, 2 pages'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(
        find.textContaining('can be used'),
        findsNothing,
        reason: 'neither page is refused, so nothing is counted out',
      );
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

    /// A rendered tile is clicked the same way and comes back as itself,
    /// because the flow renders it again at full size afterwards and
    /// needs to know which kind it took.
    testWidgets('clicking a RENDERED page returns a rendered option', (
      tester,
    ) async {
      final handle = await openPicker(tester, [liftable(0), rendered(1)]);

      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();

      expect(handle.result, isA<RenderedPageOption>());
      expect(handle.result!.pageIndex, 1);
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
}
