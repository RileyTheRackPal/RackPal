// THE GATE. "Elevations are DIMENSIONALLY CORRECT AGAINST A PHYSICAL TAPE
// MEASURE AT TRUE SCALE" -- the M1 exit criterion -- proved without a
// printer.
//
// =====================================================================
// HOW IT AVOIDS BEING A TEST THAT CANNOT FAIL
// =====================================================================
// This project has repeatedly shipped assertions that could not fail: a
// frozen-clock timing test, a rendering assertion compared against the
// constant that fed it, a catalog test asserting non-null over a 1000x unit
// error. Three deliberate defences here:
//
// 1. IT ASSERTS ON THE EMITTED BYTES, not on the calculator. The real
//    export entry point runs, `doc.save()` produces real PDF bytes, and the
//    page's operator stream is recovered and interpreted through the actual
//    `q`/`Q`/`cm` operators into PDF USER SPACE POINTS -- the space a
//    viewer and a printer consume.
//
// 2. THE RATIO IS READ BACK OUT OF THE SHEET. The `n` every expectation
//    below is divided by is regexed out of the title block's own SCALE
//    field, in the same PDF. The number a human would scale off the paper
//    is the number the test converts with -- so an exporter that draws at
//    1:8.34 and prints "1:8" fails, which is section 5.2's exact
//    prohibition ("NEVER print 1:8 on a sheet drawn at 1:8.34 -- someone
//    will scale off it").
//
// 3. EVERY EXPECTATION IS COMPUTED FROM LITERALS. 44_450_000 nm per U,
//    25_400_000 nm per inch, 72.0 points per inch, 482_600_000 nm of EIA-19
//    panel, 450_850_000 nm of clear opening, and the page's own
//    792/1224/54/36/6. NOTHING here reads `unitsPerRu`, `pointsForLen`,
//    `sceneFactor` or any other production quantity.
//
// And the harness itself has its own self-test
// (`content_stream_harness_test.dart`), because a recovery that silently
// found nothing would make all of this vacuous. This file additionally
// asserts that it found the shapes it is about, and that they are not all
// the same shape.

import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

// -- the physical chain, from literals and nothing else --------------------

/// Exactly one rack unit, in nanometres (EIA-310: 1 U = 1.75 in).
const int _nmPerU = 44_450_000;

/// Exactly one inch, in nanometres.
const int _nmPerInch = 25_400_000;

/// PDF user space: 1/72 in (PDF 32000-1 section 8.3.2.3).
const double _ptPerInch = 72;

/// EIA-19 panel width, 19 in.
const int _nmPanel = 482_600_000;

/// EIA-19 clear opening between the rails, 17.75 in
/// (19 in less two 0.625 in flanges).
const int _nmOpening = 450_850_000;

/// One EIA-19 rail flange, 0.625 in — half the difference between the
/// panel and the clear opening.
const int _nmFlange = 15_875_000;

/// One foot of reality -- what the graphic scale bar measures.
const int _nmFoot = 12 * _nmPerInch;

double _pt(int nm) => nm * _ptPerInch / _nmPerInch;

/// How close a recovered length has to be, in points.
///
/// =====================================================================
/// WHY THIS IS NOT 1e-9, AND WHY THAT IS NOT A FUDGE
/// =====================================================================
/// `PdfNum.precision` is a compile-time `const int = 5` in pdf 3.13.0
/// (`format/num.dart:26`), so EVERY number dart_pdf writes into a content
/// stream is `toStringAsFixed(5)`. The elevation's scene factor at 1:8 is
/// 126/176 = 0.715909090..., which reaches the page as `0.71591` — an
/// absolute error of 4.1e-7 per unit. Over a 45 U rack (990 diagram units)
/// that accumulates to 9e-4 pt.
///
/// So the residual is a property of the PDF WRITER's number format, not of
/// this exporter's arithmetic, and it is not injectable. The tolerance is
/// therefore set from that bound rather than tuned until the test passed:
/// 5e-6 of rounding per unit over at most ~1000 units is 5e-3 pt, and 0.01
/// pt is twice that.
///
/// AND IT IS PHYSICALLY MEANINGLESS: 0.01 pt is 1/7200 in — about a
/// thousandth of the width of a pencil line, four orders of magnitude finer
/// than a tape measure resolves and two finer than a 600 dpi printer's own
/// dot. A mutation that matters at all moves these figures by whole points:
/// the scene factor x 1.01 moves the 45 U height by 7 pt, `unitsPerRu`
/// 22 -> 23 by 32 pt. The tolerance cannot hide any of them, and
/// `_toleranceIsPhysicallyNegligible` below asserts the bound rather than
/// leaving it as a claim in a comment.
const double _tol = 0.01;

// -- the paper, from literals ---------------------------------------------

const double _pageW = 792;
const double _pageH = 1224;
const double _marginB = 36;
const double _inset = 6;

/// The title block, from docs/08 section 5.2.
const double _titleBlockH = 115;

/// A revision block holding ONE body row (`NO REVISIONS RECORDED`) plus its
/// header, at section 5.3's 13 pt rows.
const double _revisionBlockH = 2 * 13;

/// `elevation_sheet.dart`'s scale-bar band. (Its header band is above the
/// elevation and so does not enter the bottom-edge arithmetic below.)
const double _scaleBand = 34;

/// Where the rack's own bottom edge lands, in PAGE coordinates (Y down).
///
/// frame bottom 1224 - 36 - 6 = 1182; less the title block and the
/// revision block gives the drawing area's bottom at 1041; less the scale
/// bar band gives 1007.
const double _rackBottomPageY =
    _pageH - _marginB - _inset - _titleBlockH - _revisionBlockH - _scaleBand;

/// The same edge in PDF USER SPACE, which is Y-UP.
const double _rackBottomUserY = _pageH - _rackBottomPageY;

const FontRef _font = FontRef('Jost');

const int _rackHeightU = 45;

// -- the fixture ----------------------------------------------------------

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

/// The half-width template: 6 twelfths of the clear opening, 1 U tall.
///
/// A PARTIAL-WIDTH DEVICE IS WHAT MAKES MIRRORING VISIBLE AT ALL. A
/// full-width block spans the whole opening, so reflecting it about the
/// opening's centre maps it onto itself — every full-width fixture in the
/// world passes a mirroring test that does nothing. The four starters
/// contain no `Face.rear` and no partial-width placement whatsoever, so
/// before this fixture nothing anywhere observed the rear reflection in
/// emitted bytes.
const int _halfSpanTwelfths = 6;

TemplateSnapshot _snapshot(String id, TemplateBody body) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'h',
  body: body,
  capturedAt: DateTime.utc(2026),
);

/// A 45 U rack with a 1 U full-width device at the very bottom (U1) and
/// another at the very top (U45), plus a HALF-WIDTH pair at U20 — one on
/// each face, at the same lateral placement, so the rear elevation's
/// reflection is a comparison rather than an assertion about one number.
///
/// 45 U is docs/08 section 6.1's own worked example -- "a 45 RU rack is
/// 78.75 in tall; at 1:8 that is 9.84 in" -- so the sheet this produces is
/// the one the doc claims fits, and (e) below reproduces its figure.
RackDocument _fixture() {
  final rack = Rack(
    id: const Uuid('rack-1'),
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: _rackHeightU,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  DeviceInstance device(
    String id,
    String designator,
    int ru, {
    String templateId = 'T1',
    Face face = Face.front,
    int spanTwelfths = 12,
  }) => DeviceInstance(
    id: Uuid(id),
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(templateId),
      version: 1,
      contentHash: 'h',
    ),
    designator: designator,
    name: '',
    placement: RailPlacement(
      rackId: rack.id,
      ruIndex: ru,
      face: face,
      spanTwelfths: spanTwelfths,
    ),
    meta: _meta(),
  );

  return RackDocument(
    id: const Uuid('doc-1'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
    info: ProjectInfo(projectName: 'SCALE FIXTURE'),
    racks: <Uuid, Rack>{rack.id: rack},
    devices: <Uuid, DeviceInstance>{
      const Uuid('d-low'): device('d-low', 'LOW-1', 1),
      const Uuid('d-high'): device('d-high', 'HIGH-1', _rackHeightU),
      const Uuid('d-half-f'): device(
        'd-half-f',
        'HALF-F',
        20,
        templateId: 'T2',
        spanTwelfths: _halfSpanTwelfths,
      ),
      const Uuid('d-half-r'): device(
        'd-half-r',
        'HALF-R',
        20,
        templateId: 'T3',
        face: Face.rear,
        spanTwelfths: _halfSpanTwelfths,
      ),
    },
    templates: <String, TemplateSnapshot>{
      'T1@1': _snapshot(
        'T1',
        TemplateBody(
          manufacturer: 'Generic',
          model: 'DEV-1U',
          displayName: 'Test Device, 1U',
          frontU: 1,
          side: OccupancySide.front,
          mountMethod: MountMethod.rackEars,
        ),
      ),
      'T2@1': _snapshot(
        'T2',
        TemplateBody(
          manufacturer: 'Generic',
          model: 'HALF-1U',
          displayName: 'Half Width, 1U',
          frontU: 1,
          side: OccupancySide.front,
          mountMethod: MountMethod.rackEars,
        ),
      ),
      'T3@1': _snapshot(
        'T3',
        TemplateBody(
          manufacturer: 'Generic',
          model: 'HALF-1U-R',
          displayName: 'Half Width Rear, 1U',
          rearU: 1,
          side: OccupancySide.rear,
          mountMethod: MountMethod.rackEars,
        ),
      ),
    },
  );
}

/// A rack of [heightU] with NOTHING in it — the fixture for the ratio
/// sweep, where the claim is about the chassis and a device would only add
/// same-sized shapes to disambiguate.
RackDocument _bareRack(int heightU) {
  final rack = Rack(
    id: const Uuid('rack-1'),
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: heightU,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  return RackDocument(
    id: const Uuid('doc-1'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
    info: ProjectInfo(projectName: 'SCALE FIXTURE'),
    racks: <Uuid, Rack>{rack.id: rack},
  );
}

void main() {
  late Uint8List fontBytes;
  late Uint8List bytes;
  late RecoveredStream front;
  late int n;

  /// THE REAL ENTRY POINT. Not a hand-assembled scene: if the app's export
  /// path and this test's path could differ, this test would be about
  /// something the user never receives.
  Future<Uint8List> export(RackDocument document) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(document),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: 'scale.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
      ),
    );
    return (result as Ok<ExportedDocument>).value.bytes;
  }

  setUpAll(() async {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();

    bytes = await export(_fixture());

    // The FRONT elevation is the first page, and its stream is the one
    // carrying `SHEET NO.  T2.01`.
    front = interpretContentStream(
      _streamContaining(bytes, 'T2.01'),
      toUnicode: parseToUnicodeCMap(bytes),
    );

    // (2) THE RATIO COMES OFF THE SHEET. Recovered from the SCALE field's
    // own text run, in the same PDF, and every expectation below divides
    // by it.
    n = _ratioOn(front);
  });

  group('the recovery found the sheet it is about', () {
    test('rectangles, paths and text are all present, and they differ', () {
      // Without this, an interpreter that found nothing would make every
      // expectation below vacuously true.
      expect(front.rects.length, greaterThanOrEqualTo(3));
      expect(front.paths.length, greaterThanOrEqualTo(3));
      expect(front.texts.length, greaterThanOrEqualTo(20));
      expect(
        front.paths.map((p) => '${p.left},${p.bottom},${p.width}').toSet(),
        hasLength(greaterThan(3)),
        reason: 'if every path were identical, the CTM walk is broken',
      );
    });

    test('the sheet reports a STANDARD ratio, not NTS', () {
      // A 45 U rack on ANSI B portrait must land on a standard denominator
      // — if it ever reports NTS, the fit search below is not doing what
      // this file claims it does and every `/n` here is meaningless.
      expect(n, isIn(const <int>[1, 2, 4, 8, 10, 16, 20, 24, 32, 48, 64, 96]));
      expect(front.allText, isNot(contains('NTS')));
    });

    test("...and it is 1:8, which is docs/08 section 6.1's own worked "
        'example', () {
      expect(n, 8);
    });
  });

  group('(a)-(e) the drawing is at the ratio it prints', () {
    test('(a) the chassis frame is 45 U tall, to the nanometre', () {
      final expected = _rackHeightU * _pt(_nmPerU) / n;
      final panel = _pt(_nmPanel) / n;

      final frame = front.pathSized(panel, expected, tolerance: _tol);
      expect(frame.height, closeTo(expected, _tol));
    });

    test('(b) the mounting panel is EXACTLY 19 in wide at the ratio', () {
      final expected = _pt(_nmPanel) / n;
      final height = _rackHeightU * _pt(_nmPerU) / n;

      final frame = front.pathSized(expected, height, tolerance: _tol);
      expect(frame.width, closeTo(expected, _tol));
    });

    test('(b2) A FULL-WIDTH DEVICE BODY IS EXACTLY THE 17.75 in CLEAR '
        'OPENING — the rail-width assertion', () {
      // THE ASSERTION THAT FORCED A CORE CHANGE. `RackGeometry.railWidth`
      // was 20 diagram units of legibility chrome, and the rails sit INSIDE
      // the 19 in panel, so the drawn clear opening was 198.9 units — about
      // 15.8 in against a real EIA-19 opening of 17.75 in, and every
      // full-width device body inherited that 11% horizontal error while
      // the vertical axis and the overall panel width were exact. The
      // milestone's "dimensionally correct" claim could not survive it.
      //
      // `railWidth` is now derived from the real 0.625 in flange, which
      // makes 19 - 2 x 0.625 = 17.75 in fall out of `openingWidth`. This
      // test FAILED before that change; the visible cost is thinner rails
      // on screen, recorded in docs/m1-implementation-log.md.
      final expected = _pt(_nmOpening) / n;
      final rowHeight = _pt(_nmPerU) / n;

      final blocks = front.distinctPathsSized(
        expected,
        rowHeight,
        tolerance: _tol,
      );
      expect(
        blocks,
        hasLength(2),
        reason:
            'both 1 U devices are full-width bodies of exactly the '
            'clear opening',
      );
    });

    test('(c) 44 U of pitch separates a device at U1 from one at U45', () {
      final rowHeight = _pt(_nmPerU) / n;
      final width = _pt(_nmOpening) / n;
      final blocks = front.distinctPathsSized(width, rowHeight, tolerance: _tol)
        ..sort((a, b) => a.bottom.compareTo(b.bottom));

      expect(blocks, hasLength(2));
      // U1's bottom edge and U45's bottom edge are 44 U apart.
      expect(
        blocks[1].bottom - blocks[0].bottom,
        closeTo((_rackHeightU - 1) * _pt(_nmPerU) / n, _tol),
      );
    });

    test('(d) each 1 U device block is exactly one U tall', () {
      final rowHeight = _pt(_nmPerU) / n;
      final width = _pt(_nmOpening) / n;

      for (final block in front.pathsSized(width, rowHeight, tolerance: _tol)) {
        expect(block.height, closeTo(rowHeight, _tol));
      }
    });

    test('(e) THE TAPE MEASURE: a 45 U rack at 1:8 is 9.84375 in of paper', () {
      // Written as a literal so a reviewer can check it against a ruler by
      // hand — 45 x 1.75 in = 78.75 in of rack, at 1:8 is 9.84375 in, which
      // is docs/08 section 6.1's own "9.84 in" reproduced from first
      // principles rather than copied.
      expect(n, 8, reason: 'the literal below is stated for 1:8');

      final panel = _pt(_nmPanel) / n;
      final height = _rackHeightU * _pt(_nmPerU) / n;
      final frame = front.pathSized(panel, height, tolerance: _tol);

      // The tolerance in INCHES: 0.01 pt / 72.
      expect(frame.height / 72, closeTo(9.84375, _tol / 72));
      expect(frame.width / 72, closeTo(19.0 / 8, _tol / 72));
    });

    test('_toleranceIsPhysicallyNegligible: the slack this file allows is '
        'finer than anything that prints', () {
      // Stated as an assertion rather than as a paragraph, so a future
      // widening of `_tol` to make something pass has to argue with a red
      // test. 0.01 pt is 1/7200 in; a 600 dpi laser's own dot is 1/600 in,
      // twelve times coarser.
      expect(_tol / 72, lessThan(1 / 600));
      // ...and it is far smaller than the smallest thing the sheet claims
      // to measure: one rack unit at the smallest standard ratio.
      expect(_tol, lessThan(_pt(_nmPerU) / 96 / 100));
    });

    test('(f) the graphic scale bar is exactly one foot of reality', () {
      // A photocopied sheet loses its printed ratio and keeps this bar, so
      // the bar being the right LENGTH is a separate claim from the label
      // being the right number.
      //
      // The bar is drawn in PAGE coordinates at 1:1 — outside the scaled
      // bracket — so it carries none of the CTM rounding the geometry
      // above does and is asserted tightly.
      final expected = _pt(_nmFoot) / n;
      // The band between the drawing area's bottom edge and the rack's own
      // bottom edge, in user space.
      const bandTop = _rackBottomUserY;
      const bandBottom =
          _pageH -
          (_pageH - _marginB - _inset - _titleBlockH - _revisionBlockH);

      final bars = front.paths
          .where(
            (p) =>
                p.height.abs() < 1e-6 &&
                (p.width - expected).abs() < 1e-6 &&
                p.bottom > bandBottom &&
                p.top < bandTop,
          )
          .toList();

      expect(
        bars,
        isNotEmpty,
        reason:
            'no ${expected.toStringAsFixed(3)} pt horizontal rule in the '
            'scale-bar band ($bandBottom..$bandTop) — the scale bar is '
            'missing, the wrong length or in the wrong place',
      );
      expect(front.allText, contains('1 ft'));
    });
  });

  group('(g) absolute placement — the Y-flip check', () {
    test('the rack sits ON the drawing area bottom, derived from page '
        'literals', () {
      // (a)-(d) are all DIFFERENCES, so a flip about the wrong height
      // passes every one of them. This one cannot: it names where the rack
      // is on the paper, in user space, from 1224/36/6/115/26/34 and
      // nothing else.
      final panel = _pt(_nmPanel) / n;
      final height = _rackHeightU * _pt(_nmPerU) / n;
      final frame = front.pathSized(panel, height, tolerance: _tol);

      expect(frame.bottom, closeTo(_rackBottomUserY, _tol));
      expect(frame.top, closeTo(_rackBottomUserY + height, _tol));
    });

    test('the title block is at the BOTTOM of the sheet, not mirrored to '
        'the top', () {
      final title = front.rects.firstWhere(
        (r) => (r.width - 396).abs() < 0.01 && (r.height - 115).abs() < 0.01,
        orElse: () => throw StateError('no 396 x 115 title block'),
      );
      expect(title.bottom, closeTo(_marginB + _inset, 1e-3));
      expect(title.top, lessThan(_pageH / 2));
    });

    test('nothing is drawn outside the page', () {
      for (final path in front.paths) {
        expect(path.left, greaterThanOrEqualTo(-1));
        expect(path.right, lessThanOrEqualTo(_pageW + 1));
        expect(path.bottom, greaterThanOrEqualTo(-1));
        expect(path.top, lessThanOrEqualTo(_pageH + 1));
      }
    });

    test('the drawn elevation stays clear of the title block', () {
      // The drawing area's bottom is above the furniture by construction;
      // asserting it on the BYTES catches a composition that placed the
      // content correctly in one coordinate space and drew it in another.
      const furnitureTop =
          _pageH -
          (_pageH - _marginB - _inset - _titleBlockH - _revisionBlockH);
      final panel = _pt(_nmPanel) / n;
      final height = _rackHeightU * _pt(_nmPerU) / n;
      expect(
        front.pathSized(panel, height, tolerance: _tol).bottom,
        greaterThanOrEqualTo(furnitureTop - _tol),
      );
    });
  });

  group('the ratio the block prints is the ratio the sheet is drawn at', () {
    test('the recovered geometry and the printed label agree', () {
      // The join between defence (2) and defence (3), stated as its own
      // assertion: the physical ratio MEASURED off the emitted bytes,
      // computed with no production code, equals 1/n for the n the sheet
      // printed.
      final panel = _pt(_nmPanel) / n;
      final height = _rackHeightU * _pt(_nmPerU) / n;
      final frame = front.pathSized(panel, height, tolerance: _tol);

      // Paper inches divided by real inches.
      const realInches = _rackHeightU * _nmPerU / _nmPerInch;
      final measured = (frame.height / _ptPerInch) / realInches;

      // `_tol` points of slack in the numerator is this much in k.
      const slack = _tol / _ptPerInch / realInches;
      expect(measured, closeTo(1 / n, slack));

      // AND THE SLACK IS AN ORDER OF MAGNITUDE INSIDE WHAT SECTION 5.2
      // FORBIDS. The doc's rule is that a sheet may print `1:n` only when
      // the drawn ratio is within 2% of 1/n; this test's slack is
      // ~0.1% of that, so it cannot admit the lie the rule is about.
      expect(slack, lessThan(0.02 / n / 10));
    });
  });

  group('EVERY ratio the exporter emits, not just 1:8', () {
    // ====================================================================
    // ONE FIXTURE AT ONE RATIO WAS PROVING ONE RATIO.
    // ====================================================================
    // Everything above runs on a single 45 U rack with `expect(n, 8)` hard
    // asserted, so the two OTHER denominators the exporter reaches in
    // normal operation had no byte-level assertion anywhere:
    //
    //   * 1:4 for 1 U-24 U — the 12 U and 24 U credenza case, which is the
    //     single most likely sheet an integrator actually receives;
    //   * 1:10 for a 60 U rack, CR-038's maximum.
    //
    // A regression confined to a non-1:8 denominator — a wrong entry in
    // `kStandardScaleDenominators`, a fit that selects a ratio not on the
    // list, an off-by-one in the fit loop's `<=` — would have shipped
    // entirely green.
    //
    // Each case below measures the CHASSIS on the emitted page against
    // `heightU x 44_450_000 x 72 / 25_400_000 / n` and `482_600_000 x 72 /
    // 25_400_000 / n`, with `n` read off that same sheet's SCALE field.

    /// Measures the chassis on the front elevation of a bare [heightU]
    /// rack and returns `(n, frame)`.
    Future<(int, RecoveredPath)> chassisOf(int heightU) async {
      final pdf = await export(_bareRack(heightU));
      final sheet = interpretContentStream(
        _streamContaining(pdf, 'T2.01'),
        toUnicode: parseToUnicodeCMap(pdf),
      );
      final ratio = _ratioOn(sheet);
      return (
        ratio,
        sheet.pathSized(
          _pt(_nmPanel) / ratio,
          heightU * _pt(_nmPerU) / ratio,
          tolerance: _tol,
        ),
      );
    }

    test('a 1 U rack is drawn at 1:4 and measures 342.000 x 31.500 pt', () {
      // The literals, so a reviewer can check them by hand: 19 in / 4 is
      // 4.75 in = 342 pt; 1.75 in / 4 is 0.4375 in = 31.5 pt.
      expect(_pt(_nmPanel) / 4, closeTo(342, 1e-9));
      expect(_pt(_nmPerU) / 4, closeTo(31.5, 1e-9));

      expect(
        chassisOf(1),
        completion(
          isA<(int, RecoveredPath)>()
              .having((r) => r.$1, 'ratio', 4)
              .having((r) => r.$2.width, 'width', closeTo(342, _tol))
              .having((r) => r.$2.height, 'height', closeTo(31.5, _tol)),
        ),
      );
    });

    test('the CREDENZA CASE — 12 U and 24 U — is drawn at 1:4, to the '
        'nanometre', () async {
      // The sheet an integrator is most likely to be holding while cutting
      // an opening, and it was the ratio with no byte-level assertion.
      for (final heightU in <int>[12, 24]) {
        final (ratio, frame) = await chassisOf(heightU);
        expect(ratio, 4, reason: '${heightU}U');
        expect(
          frame.height,
          closeTo(heightU * _pt(_nmPerU) / 4, _tol),
          reason: '${heightU}U',
        );
        expect(frame.width, closeTo(_pt(_nmPanel) / 4, _tol));
        // ...and it sits on the same stated line every other sheet does.
        expect(frame.bottom, closeTo(_rackBottomUserY, _tol));
      }
    });

    test('a 60 U rack — CR-038 maximum — is drawn at 1:10 and measures '
        '136.801 x 756.004 pt', () async {
      expect(_pt(_nmPanel) / 10, closeTo(136.8, 1e-6));
      expect(60 * _pt(_nmPerU) / 10, closeTo(756, 1e-6));

      final (ratio, frame) = await chassisOf(60);
      expect(ratio, 10);
      expect(frame.width, closeTo(136.8, _tol));
      expect(frame.height, closeTo(756, _tol));
      expect(frame.bottom, closeTo(_rackBottomUserY, _tol));
    });

    test('the sweep really does cover MORE THAN ONE ratio', () async {
      // Without this the three tests above could all be exercising 1:8 and
      // the group would be the very thing it was written to replace.
      final ratios = <int>{
        for (final heightU in <int>[1, 24, 45, 60])
          (await chassisOf(heightU)).$1,
      };
      expect(ratios, <int>{4, 8, 10});
    });
  });

  group('the REAR sheet is drawn to the same standard', () {
    late RecoveredStream rear;

    setUpAll(() {
      rear = interpretContentStream(
        _streamContaining(bytes, 'T2.02'),
        toUnicode: parseToUnicodeCMap(bytes),
      );
    });

    test('T2.02 carries a 45 U panel at the same ratio', () {
      final panel = _pt(_nmPanel) / n;
      final height = _rackHeightU * _pt(_nmPerU) / n;

      final frame = rear.pathSized(panel, height, tolerance: _tol);
      expect(frame.bottom, closeTo(_rackBottomUserY, _tol));
      // ...and says what it does not contain.
      expect(rear.allText, contains('PORT AND CONNECTION DETAIL'));
    });

    test('A HALF-WIDTH REAR DEVICE IS MIRRORED, and the reflection is '
        'visible in the emitted bytes', () async {
      // ==================================================================
      // NOTHING ANYWHERE OBSERVED REAR MIRRORING ON PAPER.
      // ==================================================================
      // The architecture is right and `rack_mirror_test.dart` covers the
      // reflection well at SCENE level — `RackGeometry.deviceRect` moves
      // the layout, `rackpal_export` contains no mirroring logic at all —
      // but nothing joined that to a sheet. If `buildElevationSheet` ever
      // passed the wrong `face` to `buildRackScene` for T2.02, or if the
      // `OpTransform` splice mis-anchored a mirrored rect, the PDF-level
      // suite would not have noticed: the fixture placed both devices on
      // `Face.front`, so T2.02 carried zero device blocks, and the four
      // starters contain no `Face.rear` and no partial-width placement to
      // catch it either.
      //
      // The fixture now carries a HALF-WIDTH device at U20 on each face,
      // at the same lateral placement (`startTwelfth: 0`, six twelfths of
      // the opening). Unmirrored, both would sit against the LEFT rail.
      // Mirrored, the rear one sits against the RIGHT rail — and that is
      // the whole difference between a sheet an installer can work from
      // and one that puts every device on the wrong side of the rack.
      final half = _pt(_nmOpening) / 2 / n;
      final rowHeight = _pt(_nmPerU) / n;
      final panel = _pt(_nmPanel) / n;
      final flange = _pt(_nmFlange) / n;
      final rackHeight = _rackHeightU * _pt(_nmPerU) / n;

      final frontBlock = front.distinctPathsSized(
        half,
        rowHeight,
        tolerance: _tol,
      );
      final rearBlock = rear.distinctPathsSized(
        half,
        rowHeight,
        tolerance: _tol,
      );
      // The fixture is what this test thinks it is: exactly one half-width
      // block on each face, and it really is half the clear opening.
      expect(frontBlock, hasLength(1), reason: 'front half-width block');
      expect(rearBlock, hasLength(1), reason: 'rear half-width block');
      expect(half * 2, closeTo(_pt(_nmOpening) / n, 1e-9));

      // Each block is measured against ITS OWN sheet's chassis, because
      // the two elevations are centred independently in the drawing area
      // and their absolute X need not agree.
      final frontFrame = front.pathSized(panel, rackHeight, tolerance: _tol);
      final rearFrame = rear.pathSized(panel, rackHeight, tolerance: _tol);

      // FRONT: hard against the left rail, one flange in from the panel.
      expect(
        frontBlock.single.left - frontFrame.left,
        closeTo(flange, _tol),
        reason: 'the front half-width device is not against the left rail',
      );

      // REAR: hard against the RIGHT rail — the reflection.
      expect(
        rearFrame.right - rearBlock.single.right,
        closeTo(flange, _tol),
        reason: 'the rear half-width device was NOT mirrored',
      );

      // Stated as the reflection itself: the front block's distance from
      // its left rail equals the rear block's distance from its right
      // rail, which is what "reflected about the opening centre" means for
      // a pair placed identically.
      expect(
        frontBlock.single.left - frontFrame.left,
        closeTo(rearFrame.right - rearBlock.single.right, _tol),
      );

      // ...and the two are genuinely on OPPOSITE sides, so the assertions
      // above cannot both be satisfied by a block that spans the whole
      // opening or by a fixture that quietly drew the same thing twice.
      final frontCentre = frontFrame.left + panel / 2;
      final rearCentre = rearFrame.left + panel / 2;
      expect(frontBlock.single.right, lessThan(frontCentre + _tol));
      expect(rearBlock.single.left, greaterThan(rearCentre - _tol));
    });
  });
}

/// The `n` the SCALE field on [sheet] prints, read off the sheet's own
/// text runs.
int _ratioOn(RecoveredStream sheet) {
  final label = sheet.texts
      .map((t) => t.text)
      .firstWhere(
        (t) => RegExp(r'^1:\d+$').hasMatch(t),
        orElse: () => throw StateError(
          'no "1:n" run on the sheet. Runs: '
          '${sheet.texts.map((t) => t.text).take(40).toList()}',
        ),
      );
  return int.parse(RegExp(r'^1:(\d+)$').firstMatch(label)!.group(1)!);
}

/// The operator stream of the page whose text contains [marker].
///
/// `extractOperatorStream` picks the smallest matching body, which is what
/// keeps the few-KB operator stream winning over the embedded font blob.
/// The marker is a SHEET ID, so each page is addressed by the identity it
/// prints rather than by its index in the file.
String _streamContaining(Uint8List bytes, String marker) {
  final cmap = parseToUnicodeCMap(bytes);
  for (final body in operatorStreams(bytes)) {
    if (!body.contains(' re ')) continue;
    if (interpretContentStream(body, toUnicode: cmap).allText.contains(
      marker,
    )) {
      return body;
    }
  }
  throw StateError('no page whose text contains "$marker"');
}
