// The integrator's logo in the title block (`#590`, DR-030, DR-216
// §11.215.3, DR-217 §11.216.4 and §11.216.5).
//
// A ruled cell at the right of the whole upper band, the logo fitted into
// 100 x 45 pt and centred in it, the same size on every sheet; the text
// narrowed to what remains; nothing on the compact strip; and with no logo,
// the block exactly as it was.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

const ProjectLogo _wide = ProjectLogo(
  imageMember: '${kLogoMemberDir}wide.png',
  format: PlanImageFormat.png,
  pixelWidth: 1200,
  pixelHeight: 300,
  contentHash: 'sha256:wide',
);

const ProjectLogo _tall = ProjectLogo(
  imageMember: '${kLogoMemberDir}tall.png',
  format: PlanImageFormat.png,
  pixelWidth: 300,
  pixelHeight: 600,
  contentHash: 'sha256:tall',
);

ProjectInfo _info({ProjectLogo? logo, String? name}) {
  final info = fullProjectInfo();
  return ProjectInfo(
    projectName: name ?? info.projectName,
    projectNumber: info.projectNumber,
    clientName: info.clientName,
    siteAddress: info.siteAddress,
    integratorName: info.integratorName,
    integratorContact: info.integratorContact,
    integratorLicense: info.integratorLicense,
    drawnBy: info.drawnBy,
    checkedBy: info.checkedBy,
    logo: logo,
  );
}

TitleBlockFields _fields(SheetDef sheet, ProjectInfo info) =>
    TitleBlockFields.resolve(
      info: info,
      settings: ProjectSettings(),
      sheet: sheet,
      rack: sheet.rackId == null ? null : testRack(),
      revisions: const <RevisionEntry>[],
      scale: DrawingScale.standard(8),
      fileName: 'smith.rppj',
      issuedAt: DateTime.utc(2026, 10),
    );

DBox _box(SheetDef sheet) =>
    sheetLayoutFor(sheet, const <RevisionEntry>[]).titleBlockBox;

List<DiagramOp> _ops(SheetDef sheet, ProjectInfo info) => buildTitleBlockLayer(
  box: _box(sheet),
  fields: _fields(sheet, info),
  measurer: FakeMeasurer(),
  compact: sheet.size.usesCompactTitleBlock,
).ops;

SheetDef _role(SheetRole role) =>
    oneRackSheetSet().sheets.firstWhere((s) => s.role == role);

void main() {
  test('the field carries the logo AT FULL VALUE, never screened', () {
    final logo = _fields(_role(SheetRole.cover), _info(logo: _wide)).logo!;
    expect(logo.member, _wide.imageMember);
    expect((logo.pixelWidth, logo.pixelHeight), (1200, 300));
    expect(logo.screened, isFalse);
    expect(_fields(_role(SheetRole.cover), _info()).logo, isNull);
  });

  test('ONE IMAGE, inside the 100 x 45 box at the top right, aspect kept, '
      'the same size on every full-block sheet', () {
    DBox? first;
    for (final sheet in oneRackSheetSet().sheets.where(
      (s) => !s.size.usesCompactTitleBlock,
    )) {
      final images = _ops(sheet, _info(logo: _wide)).whereType<OpImage>();
      expect(images, hasLength(1), reason: sheet.ncsId);
      final dst = images.single.dst;
      final box = _box(sheet);
      // A 4:1 logo is width-bound: 100 wide, 25 tall.
      expect(dst.width, closeTo(kLogoBoxWidth, 1e-9), reason: sheet.ncsId);
      expect(dst.width / dst.height, closeTo(4, 1e-9), reason: sheet.ncsId);
      expect(dst.right, closeTo(box.right - 4, 1e-9), reason: sheet.ncsId);
      expect(dst.top, greaterThan(box.top), reason: sheet.ncsId);
      final size = (dst.width, dst.height);
      first ??= dst;
      expect(size, (first.width, first.height), reason: sheet.ncsId);
    }
  });

  test('a TALL logo is height-bound and centred in the box', () {
    final dst = _ops(
      _role(SheetRole.cover),
      _info(logo: _tall),
    ).whereType<OpImage>().single.dst;
    expect(dst.height, closeTo(kLogoBoxHeight, 1e-9));
    expect(dst.width, closeTo(kLogoBoxHeight / 2, 1e-9));
    final box = _box(_role(SheetRole.cover));
    final cellCentre = box.right - kLogoCellWidth / 2;
    expect((dst.left + dst.right) / 2, closeTo(cellCentre, 1e-9));
  });

  test('THE TEXT STOPS AT THE CELL: a long project line is fitted to what '
      'remains, not drawn under the logo', () {
    final sheet = _role(SheetRole.cover);
    final long = 'A PROJECT NAME LONG ENOUGH TO RUN THE FULL WIDTH ' * 3;
    final ops = _ops(sheet, _info(logo: _wide, name: long));
    final cellLeft = _box(sheet).right - kLogoCellWidth;
    final texts = ops.whereType<OpText>().toList();
    final ink = inkBoundsOf(<DiagramOp>[
      ...texts.take(5),
    ], measurer: FakeMeasurer())!;
    expect(ink.right, lessThanOrEqualTo(cellLeft));
    // The control: without a logo the same line runs past where the cell
    // would be, so the assertion above is about the cell and not the name.
    final plain = _ops(sheet, _info(name: long)).whereType<OpText>().take(5);
    final plainInk = inkBoundsOf(<DiagramOp>[
      ...plain,
    ], measurer: FakeMeasurer())!;
    expect(plainInk.right, greaterThan(cellLeft));
  });

  test('NO LOGO, NO CELL: the block is exactly what it was', () {
    for (final sheet in oneRackSheetSet().sheets) {
      final ops = _ops(sheet, _info());
      expect(ops.whereType<OpImage>(), isEmpty, reason: sheet.ncsId);
      final box = _box(sheet);
      final vertical = ops.whereType<OpLine>().where(
        (l) =>
            l.a.x == l.b.x &&
            (l.a.x - (box.right - kLogoCellWidth)).abs() < 1e-9,
      );
      expect(vertical, isEmpty, reason: sheet.ncsId);
    }
  });

  test('THE COMPACT STRIP PRINTS NO LOGO (§11.216.5)', () {
    final compact = oneRackSheetSet().sheets.where(
      (s) => s.size.usesCompactTitleBlock,
    );
    expect(compact, isNotEmpty, reason: 'the premise: a set has an A sheet');
    for (final sheet in compact) {
      expect(
        _ops(sheet, _info(logo: _wide)).whereType<OpImage>(),
        isEmpty,
        reason: sheet.ncsId,
      );
      expect(
        _ops(sheet, _info(logo: _wide)),
        hasLength(_ops(sheet, _info()).length),
        reason: sheet.ncsId,
      );
    }
  });

  test('fitInside keeps the aspect and never stretches', () {
    const box = DBox.fromLtwh(10, 20, 100, 45);
    final wide = fitInside(box, 4);
    expect((wide.width, wide.height), (100, 25));
    expect(wide.top, closeTo(30, 1e-9));
    final tall = fitInside(box, 0.5);
    expect((tall.width, tall.height), (22.5, 45));
    expect(tall.left, closeTo(48.75, 1e-9));
  });
}
