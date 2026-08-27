// draw/sheet/sheet_frame.dart — page geometry and the section 5.1 border.
//
// Every expectation is a LITERAL from docs/08 §6.1/§3.2/§3.3/§5.2, not a
// restatement of the arithmetic in the code. Where the doc states a derived
// figure (the 690 pt usable width) it is asserted directly, because that is
// the number the schedule column widths were designed against.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  group('page sizes (section 6.1)', () {
    test('ANSI B portrait is 792 × 1224 pt (11 × 17 in)', () {
      expect(SheetSize.ansiBPortrait.widthPt, 792.0);
      expect(SheetSize.ansiBPortrait.heightPt, 1224.0);
      expect(SheetSize.ansiBPortrait.sizeCode, 'B');
      expect(SheetSize.ansiBPortrait.usesCompactTitleBlock, isFalse);
    });

    test('ANSI A landscape is 792 × 612 pt — wide, never a rotated '
        'portrait', () {
      expect(SheetSize.ansiALandscape.widthPt, 792.0);
      expect(SheetSize.ansiALandscape.heightPt, 612.0);
      expect(SheetSize.ansiALandscape.sizeCode, 'A');
      expect(SheetSize.ansiALandscape.usesCompactTitleBlock, isTrue);
      expect(
        SheetSize.ansiALandscape.widthPt,
        greaterThan(SheetSize.ansiALandscape.heightPt),
      );
    });
  });

  group('margins and the drawing frame', () {
    test('the standard margins are fromLTRB(54, 36, 36, 36)', () {
      expect(SheetMargins.standard.left, 54.0, reason: 'binding edge');
      expect(SheetMargins.standard.top, 36.0);
      expect(SheetMargins.standard.right, 36.0);
      expect(SheetMargins.standard.bottom, 36.0);
    });

    test('ANSI B portrait: margin box 702 × 1152 at (54, 36)', () {
      const geometry = SheetGeometry(SheetSize.ansiBPortrait);
      expect(geometry.marginBox, const DBox.fromLtwh(54, 36, 702, 1152));
    });

    test('ANSI B portrait: drawing frame 690 × 1140 at (60, 42)', () {
      const geometry = SheetGeometry(SheetSize.ansiBPortrait);
      expect(geometry.frameBox, const DBox.fromLtwh(60, 42, 690, 1140));
    });

    test('the usable width is the 690 pt of section 3.3 on both landscape '
        'sizes', () {
      // 792 − 54 − 36 − 12 = 690, which is the figure the schedule column
      // widths in section 3.3 sum to. If this ever moves, those tables no
      // longer fit the paper they were designed for.
      expect(const SheetGeometry(SheetSize.ansiALandscape).frameBox.width, 690);
      expect(const SheetGeometry(SheetSize.ansiBPortrait).frameBox.width, 690);
    });

    test('ANSI A landscape: drawing frame 690 × 528 at (60, 42)', () {
      const geometry = SheetGeometry(SheetSize.ansiALandscape);
      expect(geometry.frameBox, const DBox.fromLtwh(60, 42, 690, 528));
    });

    test('the page box starts at the origin, Y down', () {
      const geometry = SheetGeometry(SheetSize.ansiBPortrait);
      expect(geometry.pageBox, const DBox.fromLtwh(0, 0, 792, 1224));
    });
  });

  group('the border layer (section 5.1)', () {
    test('emits exactly two stroked rectangles and no fills', () {
      final layer = buildSheetFrameLayer(
        const SheetGeometry(SheetSize.ansiBPortrait),
      );
      final rects = layer.ops.whereType<OpRect>().toList();

      expect(layer.ops, hasLength(2));
      expect(rects, hasLength(2));
      expect(rects.every((r) => r.fill == null), isTrue);
    });

    test('the outer rule is 0.7 pt and the inner is 1.0 pt, both at the '
        '0.25 pt furniture floor (CR-082)', () {
      final layer = buildSheetFrameLayer(
        const SheetGeometry(SheetSize.ansiBPortrait),
      );
      final rects = layer.ops.whereType<OpRect>().toList();

      expect(rects[0].r, const DBox.fromLtwh(54, 36, 702, 1152));
      expect(rects[0].stroke!.widthPt, 0.7);
      expect(rects[1].r, const DBox.fromLtwh(60, 42, 690, 1140));
      expect(rects[1].stroke!.widthPt, 1.0);
      // hairlineFloor selects the 0.25 pt floor rather than the 0.5 pt
      // signal floor — furniture is drafting chrome, not signal geometry.
      expect(rects.every((r) => r.stroke!.hairlineFloor), isTrue);
    });

    test('draws no text', () {
      final layer = buildSheetFrameLayer(
        const SheetGeometry(SheetSize.ansiBPortrait),
      );
      expect(layer.ops.whereType<OpText>(), isEmpty);
      expect(layer.minTextPt, double.infinity);
    });

    test('honours a palette override', () {
      final layer = buildSheetFrameLayer(
        const SheetGeometry(SheetSize.ansiBPortrait),
        palette: const SheetPalette(rule: 0xFF123456),
      );
      expect(
        layer.ops.whereType<OpRect>().every(
          (r) => r.stroke!.argb == 0xFF123456,
        ),
        isTrue,
      );
    });
  });

  group('SheetLayout — full title block (ANSI B)', () {
    final layout = SheetLayout.resolve(
      geometry: const SheetGeometry(SheetSize.ansiBPortrait),
      revisionRowCount: 1,
    );

    test('the title block is 396 × 115, bottom-right of the frame', () {
      expect(layout.titleBlockBox.width, 396.0);
      expect(layout.titleBlockBox.height, 115.0);
      expect(layout.titleBlockBox.right, layout.frameBox.right);
      expect(layout.titleBlockBox.bottom, layout.frameBox.bottom);
      expect(layout.titleBlockBox, const DBox.fromLtwh(354, 1067, 396, 115));
    });

    test('the revision block sits directly above it, same 396 pt width', () {
      final box = layout.revisionBlockBox!;
      expect(box.width, 396.0);
      expect(box.left, layout.titleBlockBox.left);
      expect(box.bottom, layout.titleBlockBox.top);
      // One body row + one header row, 13 pt each.
      expect(box.height, 26.0);
    });

    test('the revision block grows upward as rows are added', () {
      for (final rows in <int>[1, 3, 8, 9]) {
        final grown = SheetLayout.resolve(
          geometry: const SheetGeometry(SheetSize.ansiBPortrait),
          revisionRowCount: rows,
        );
        expect(grown.revisionBlockBox!.height, (rows + 1) * 13.0);
        expect(grown.revisionBlockBox!.bottom, grown.titleBlockBox.top);
        // …at the drawing area's expense, never overlapping it.
        expect(grown.drawingArea.bottom, grown.revisionBlockBox!.top);
      }
    });

    test('the drawing area is the frame above the furniture', () {
      expect(layout.drawingArea, const DBox.fromLtwh(60, 42, 690, 999));
      expect(layout.drawingArea.bottom, layout.revisionBlockBox!.top);
      expect(
        layout.drawingArea.intersects(layout.titleBlockBox.inflate(-0.01)),
        isFalse,
      );
    });
  });

  group('SheetLayout — compact title strip (ANSI A)', () {
    final layout = SheetLayout.resolve(
      geometry: const SheetGeometry(SheetSize.ansiALandscape),
      revisionRowCount: 1,
    );

    test('the strip is full width × 43 pt along the bottom, so the '
        'schedule table is not notched', () {
      expect(layout.titleBlockBox.width, 690.0);
      expect(layout.titleBlockBox.height, 43.0);
      expect(layout.titleBlockBox.left, layout.frameBox.left);
      expect(layout.titleBlockBox.right, layout.frameBox.right);
      expect(layout.titleBlockBox.bottom, layout.frameBox.bottom);
    });

    test('there is NO revision block — a stated deviation', () {
      // Stacking an eight-row revision grid above a full-width strip would
      // notch the table by 130 pt and undo the reason the strip is
      // full-width in the first place. The REV field still prints.
      expect(layout.revisionBlockBox, isNull);
    });

    test('the drawing area runs to the top of the strip', () {
      expect(layout.drawingArea, const DBox.fromLtwh(60, 42, 690, 485));
      expect(layout.drawingArea.bottom, layout.titleBlockBox.top);
    });

    test('the revision row count does not change the compact layout', () {
      final many = SheetLayout.resolve(
        geometry: const SheetGeometry(SheetSize.ansiALandscape),
        revisionRowCount: 9,
      );
      expect(many.drawingArea, layout.drawingArea);
      expect(many.titleBlockBox, layout.titleBlockBox);
    });
  });

  group('column widths add up', () {
    test('the five title-grid columns sum to 396', () {
      expect(
        kTitleGridColumnWidths.fold<double>(0, (a, b) => a + b),
        kTitleBlockWidth,
      );
    });

    test('the four revision columns sum to 396 (section 5.3)', () {
      expect(kRevisionColumnWidths, <double>[30, 62, 268, 36]);
      expect(
        kRevisionColumnWidths.fold<double>(0, (a, b) => a + b),
        kTitleBlockWidth,
      );
    });
  });

  group('furniture text sizes clear the legibility floor', () {
    test('every declared size is at or above 6.0 pt', () {
      // Furniture is drawn at 1:1, so these ARE the printed sizes. A
      // 5.5 pt "it will probably be fine" label is exactly the thing this
      // asserts mechanically instead of by inspection.
      expect(SheetTextSizes.all, isNotEmpty);
      for (final size in SheetTextSizes.all) {
        expect(size, greaterThanOrEqualTo(kMinPrintPt));
      }
    });
  });
}
