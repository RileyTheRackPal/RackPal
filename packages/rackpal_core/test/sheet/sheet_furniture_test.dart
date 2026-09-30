// draw/sheet/sheet_furniture.dart — the composition, and the API pass 2
// consumes.
//
// The two-step dance this asserts (layout → scale → furniture) is what
// keeps the dependency acyclic: the drawing area depends on the revision
// count but NOT on the scale, while the SCALE field depends on the scale,
// which depends on the drawing area.

import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

final DateTime _issued = DateTime.utc(2026, 7, 18);

SheetFurniture furnitureFor({
  SheetDef? sheet,
  Rack? rack,
  bool noRack = false,
  ProjectInfo? info,
  List<RevisionEntry> revisions = const <RevisionEntry>[],
  DrawingScale? scale,
  DateTime? issuedAt,
}) {
  final set = oneRackSheetSet();
  final resolved =
      sheet ??
      set.sheets.firstWhere((s) => s.role == SheetRole.rackElevationFront);
  return buildSheetFurniture(
    sheet: resolved,
    info: info ?? fullProjectInfo(),
    settings: ProjectSettings(),
    rack: noRack ? null : (rack ?? testRack()),
    revisions: revisions,
    scale: scale ?? DrawingScale.standard(8),
    fileName: 'smith.rppj',
    issuedAt: issuedAt ?? _issued,
    measurer: FakeMeasurer(),
  );
}

void main() {
  group('composition', () {
    test('one call yields frame + title block + revision block', () {
      final furniture = furnitureFor();
      final frameRects = furniture.ops
          .whereType<OpRect>()
          .where((r) => r.r.width > 600)
          .toList();

      // The two border rules are the only ops that span the page.
      expect(frameRects, hasLength(2));
      expect(furniture.ops.whereType<OpText>(), isNotEmpty);
      // Title block content plus the revision block's header row.
      expect(textsOf(furniture.ops), contains('SHEET NO.  T2.01'));
      expect(textsOf(furniture.ops), contains('DESCRIPTION'));
      expect(textsOf(furniture.ops), contains(kNoRevisionsText));
    });

    test('the compact sheet has NO revision block ops', () {
      final set = oneRackSheetSet();
      final furniture = furnitureFor(sheet: set.sheets.last, noRack: true);

      expect(furniture.layout.revisionBlockBox, isNull);
      expect(textsOf(furniture.ops), isNot(contains(kNoRevisionsText)));
      expect(textsOf(furniture.ops), isNot(contains('DESCRIPTION')));
      // …but the REV field still prints, so the sheet still states its
      // revision. Only the HISTORY TABLE is absent.
      expect(
        textsOf(furniture.ops).join(' '),
        contains('REV'),
      );
    });

    test('all furniture ink stays inside the margin box', () {
      for (final revisions in <List<RevisionEntry>>[
        const <RevisionEntry>[],
        <RevisionEntry>[for (var i = 1; i <= 12; i++) testRevision('R$i', i)],
      ]) {
        final furniture = furnitureFor(revisions: revisions);
        final ink = inkBoundsOf(furniture.ops, measurer: FakeMeasurer())!;
        final page = furniture.layout.geometry.marginBox.inflate(1);

        expect(ink.left, greaterThanOrEqualTo(page.left));
        expect(ink.right, lessThanOrEqualTo(page.right));
        expect(ink.top, greaterThanOrEqualTo(page.top));
        expect(ink.bottom, lessThanOrEqualTo(page.bottom));
      }
    });

    test('no furniture op ever carries an empty string', () {
      for (final info in <ProjectInfo>[
        fullProjectInfo(),
        halfProjectInfo(),
        minimalProjectInfo(),
      ]) {
        expect(
          textsOf(furnitureFor(info: info).ops).where((t) => t.trim().isEmpty),
          isEmpty,
        );
      }
    });
  });

  group('the API pass 2 consumes', () {
    test('sheetLayoutFor answers the drawing area WITHOUT a scale', () {
      // The whole point: a caller can size its content before it knows what
      // ratio it will be drawn at.
      final set = oneRackSheetSet();
      final layout = sheetLayoutFor(
        set.sheets.firstWhere((s) => s.role == SheetRole.rackElevationFront),
        const <RevisionEntry>[],
      );
      expect(layout.drawingArea, const DBox.fromLtwh(60, 42, 690, 999));
    });

    test('the layout buildSheetFurniture uses is the SAME one '
        'sheetLayoutFor returned', () {
      // If these ever diverged, content would be laid out for one drawing
      // area and furniture drawn against another.
      final set = oneRackSheetSet();
      final standalone = sheetLayoutFor(
        set.sheets.firstWhere((s) => s.role == SheetRole.rackElevationFront),
        const <RevisionEntry>[],
      );
      final composed = furnitureFor().layout;

      expect(composed.drawingArea, standalone.drawingArea);
      expect(composed.titleBlockBox, standalone.titleBlockBox);
      expect(composed.revisionBlockBox, standalone.revisionBlockBox);
    });

    test('the drawing area shrinks as revision history grows', () {
      final none = furnitureFor().drawingArea;
      final many = furnitureFor(
        revisions: <RevisionEntry>[
          for (var i = 1; i <= 8; i++) testRevision('R$i', i),
        ],
      ).drawingArea;

      expect(many.height, lessThan(none.height));
      expect(none.height - many.height, 7 * 13.0);
    });

    test('the exposed scene is replayable and page-sized', () {
      final furniture = furnitureFor();
      final scene = furniture.scene;

      expect(scene.ops, furniture.ops);
      expect(scene.bounds, const DBox.fromLtwh(0, 0, 792, 1224));
      expect(scene.hits, isEmpty);
      expect(scene.minTextSizePt, greaterThanOrEqualTo(kMinPrintPt));

      // It really replays — through the pure-core BoundsCanvas, which is
      // the same DiagramCanvas contract the PDF and Flutter backends
      // implement. Asserting `isNotNull` here would be the shape of test
      // this project has shipped before, so the recovered extent is pinned
      // instead: replaying must reach the outer border rule (the margin
      // box, 54..750 x 36..1188 grown by half its 0.7 pt width) and must
      // not stray outside the paper.
      final canvas = BoundsCanvas(measurer: FakeMeasurer());
      scene.replay(canvas);
      final bounds = canvas.bounds!;

      expect(bounds.left, closeTo(54 - 0.35, 0.01));
      expect(bounds.top, closeTo(36 - 0.35, 0.01));
      expect(bounds.right, closeTo(792 - 36 + 0.35, 0.01));
      expect(bounds.bottom, closeTo(1224 - 36 + 0.35, 0.01));
    });

    test('furniture reports the resolved title-block fields', () {
      final furniture = furnitureFor();
      expect(furniture.fields.sheetTitle, 'RACK ELEVATION — FRONT');
      expect(furniture.fields.projectLine, startsWith('SMITH RESIDENCE'));
    });
  });

  group('determinism (§8.4)', () {
    test('two builds of the same inputs produce identical ops', () {
      expect(
        describeOps(furnitureFor().ops),
        describeOps(furnitureFor().ops),
      );
    });

    test('only the DATE moves when the injected clock moves', () {
      final a = describeOps(furnitureFor(issuedAt: _issued).ops);
      final b = describeOps(
        furnitureFor(issuedAt: DateTime.utc(2027, 1, 2)).ops,
      );

      expect(a, hasLength(b.length));
      final differing = <int>[
        for (var i = 0; i < a.length; i++)
          if (a[i] != b[i]) i,
      ];
      expect(differing, hasLength(1));
      expect(a[differing.single], contains('2026-07-18'));
    });

    test('sheet_furniture.dart calls DateTime.now() nowhere', () {
      // The clock is a parameter all the way down. This project has already
      // shipped a frozen-clock test that could not fail; injection plus the
      // assertion above is the antidote, and this is the belt.
      for (final path in <String>[
        'lib/src/draw/sheet/sheet_furniture.dart',
        'lib/src/draw/sheet/title_block.dart',
        'lib/src/draw/sheet/revision_block.dart',
        'lib/src/draw/sheet/sheet_frame.dart',
        'lib/src/draw/sheet/drawing_scale.dart',
      ]) {
        expect(
          _sourceWithoutComments(path),
          isNot(contains('DateTime.now')),
          reason: path,
        );
      }
    });
  });
}

String _sourceWithoutComments(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');
