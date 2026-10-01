// T0.00, the cover (docs/08 §5.5, M6-A1 `#312`, DR-210).
//
// WHAT IS ASSERTED IS WHAT A READER OF THE PDF CAN FIND: every field the
// file holds prints, an empty optional line is absent rather than blank,
// the sign-off says who has NOT signed as plainly as who has, and the
// right-hand column stays empty for the index M6-A3 puts there.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

CoverSheet _build(
  ProjectInfo info, {
  FakeMeasurer? measurer,
  List<Rack>? racks,
  List<DeviceInstance> devices = const <DeviceInstance>[],
  Map<String, TemplateSnapshot> templates = const <String, TemplateSnapshot>{},
}) {
  final rackList = racks ?? <Rack>[testRack()];
  final set = SheetSet.forRacks(rackList);
  return buildCoverSheet(
    sheet: set.sheets.firstWhere((s) => s.role == SheetRole.cover),
    info: info,
    settings: ProjectSettings(),
    revisions: <RevisionEntry>[
      RevisionEntry(
        revision: 'B',
        date: DateTime.utc(2026, 9),
        description: 'Issued for rough-in',
        by: 'JS',
      ),
    ],
    fileName: 'cover.rppj',
    issuedAt: DateTime.utc(2026, 10),
    measurer: measurer ?? FakeMeasurer(),
    racks: rackList,
    devices: devices,
    templates: templates,
    landings: PortLandings.none,
    sheets: set.sheets,
  );
}

/// The texts drawn left of the index column: the cover's own, without the
/// title block's copies of the same fields.
List<OpText> _left(CoverSheet built) => [
  for (final op in textOps(built.scene.ops))
    if (op.at.x < built.indexColumn.left) op,
];

List<String> _leftTexts(CoverSheet built) =>
    _left(built).map((o) => o.text).toList();

void main() {
  test('T0.00 OPENS EVERY SET, ON B landscape, and points at the legend', () {
    final cover = SheetSet.forRacks(<Rack>[testRack()]).sheets.first;
    expect(
      (cover.ncsId, cover.role, cover.index),
      (
        'T0.00',
        SheetRole.cover,
        1,
      ),
    );
    expect(cover.size, SheetSize.ansiBLandscape);
    expect(cover.legendNcsId, 'T0.01');
  });

  test('every field the file holds prints on the left', () {
    final texts = _leftTexts(_build(fullProjectInfo()));
    expect(
      texts,
      containsAll(<String>[
        'SMITH RESIDENCE',
        'J. & M. Smith',
        '1428 Alder Ct, Portland, OR 97214',
        'PROJECT 25-1183   ·   REVISION B   ·   ISSUED 2026-10-01',
        'NBS INTEGRATION LLC',
        '(503) 555-0142',
        'OR CCB #219884',
        'DRAWN J.S.   ·   CHECKED A.B.   ·   APPROVED —',
      ]),
    );
  });

  test('APPROVED BY PRINTS HERE (DR-210 §11.209.3), and the drawing number '
      'leads the issue line', () {
    final info = fullProjectInfo();
    final built = _build(
      ProjectInfo(
        projectName: info.projectName,
        drawingNumber: 'RM-2026-014',
        approvedBy: 'K.L.',
        drawnBy: 'J.S.',
      ),
    );
    final texts = _leftTexts(built);
    expect(texts, contains('DRAWN J.S.   ·   CHECKED —   ·   APPROVED K.L.'));
    expect(
      texts,
      contains('DRAWING RM-2026-014   ·   REVISION B   ·   ISSUED 2026-10-01'),
    );
  });

  test('AN EMPTY OPTIONAL LINE COLLAPSES: no client, no address, no scope '
      'heading, no integrator heading', () {
    final texts = _leftTexts(_build(minimalProjectInfo()));
    expect(texts.first, 'Untitled Project');
    expect(texts, isNot(contains('SCOPE')));
    expect(texts, isNot(contains('INTEGRATOR')));
    expect(texts.any((t) => t.trim().isEmpty), isFalse, reason: 'no blanks');
    // The sign-off never collapses: an unsigned set says so.
    expect(texts, contains('DRAWN —   ·   CHECKED —   ·   APPROVED —'));
  });

  test('THE SCOPE WRAPS inside the left block and loses no words', () {
    const scope =
        'Supply, install and commission a 42U equipment rack serving the '
        'main floor and lower level, with distributed audio to eight zones, '
        'video distribution to four displays and a managed network with '
        'wireless coverage throughout.';
    final measurer = FakeMeasurer();
    final built = _build(
      ProjectInfo(projectName: 'X', scopeNarrative: scope),
      measurer: measurer,
    );
    final left = _left(built);
    final at = left.indexWhere((o) => o.text == 'SCOPE');
    expect(at, isNot(-1));
    final lines = left
        .skip(at + 1)
        .takeWhile((o) => o.text != 'SIGN-OFF')
        .toList();
    expect(lines.length, greaterThan(1), reason: 'it wrapped');
    expect(lines.map((o) => o.text).join(' '), scope);
    for (final o in lines) {
      expect(
        o.at.x + measurer.measureText(o.text, o.style).advanceWidth,
        lessThan(built.indexColumn.left),
        reason: o.text,
      );
    }
    expect(built.scopeTruncated, isFalse);
  });

  test('A SCOPE TOO LONG IS CUT AND SAYS SO, rather than running off', () {
    final built = _build(
      ProjectInfo(
        projectName: 'X',
        scopeNarrative: List.filled(400, 'word').join(' '),
      ),
    );
    expect(built.scopeTruncated, isTrue);
  });

  test('THE INDEX COLUMN IS RESERVED: nothing on the cover draws in it', () {
    // M6-A3 fills it. Until then a left block that grew into it would be
    // taking the space the index needs (DR-210 §11.209.1).
    final built = _build(fullProjectInfo());
    final column = built.indexColumn;
    final intruders = [
      for (final op in textOps(built.scene.ops))
        if (op.at.x >= column.left &&
            op.at.y >= column.top &&
            op.at.y <= column.bottom)
          op.text,
    ];
    expect(intruders, isEmpty);
    expect(column.height, greaterThan(300), reason: 'a full-height column');
  });
}
