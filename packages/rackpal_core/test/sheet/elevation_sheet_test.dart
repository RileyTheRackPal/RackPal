// T2.01 / T2.02 composition, at the op level.
//
// The DIMENSIONAL claim is proved end to end against emitted PDF bytes in
// `rackpal_export/test/elevation_true_scale_test.dart`. This file asserts
// the things that are properties of the COMPOSITION rather than of the
// bytes: which scale is chosen and why, what the sheet says about itself,
// and that the elevation is spliced in as one bracketed fragment rather
// than redrawn.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

const Uuid _rackId = Uuid('rack-1');

DeviceInstance _device({
  required String id,
  required int ru,
  Face face = Face.front,
  LifecycleStatus lifecycle = LifecycleStatus.new_,
}) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: const TemplateRef(
    templateId: TemplateId('T1'),
    version: 1,
    contentHash: 'h',
  ),
  designator: id.toUpperCase(),
  name: 'NAME',
  placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: face),
  meta: testMeta(),
  lifecycleStatus: lifecycle,
);

Map<String, TemplateSnapshot> _templates({
  String category = 'Video & Display',
  Mass? weight,
}) => <String, TemplateSnapshot>{
  'T1@1': TemplateSnapshot(
    templateId: const TemplateId('T1'),
    version: 1,
    contentHash: 'h',
    body: TemplateBody(
      manufacturer: 'ACME',
      model: 'MDL',
      displayName: 'Widget',
      category: category,
      frontU: 2,
      rearU: 2,
      side: OccupancySide.both,
      weight: weight,
    ),
    capturedAt: DateTime.utc(2026),
  ),
};

/// A template whose device occupies [frontU] rack units on both faces —
/// tall enough that `device_layer` still emits the `name` line at a print
/// type scale.
Map<String, TemplateSnapshot> _tallTemplates(int frontU) =>
    <String, TemplateSnapshot>{
      'T1@1': TemplateSnapshot(
        templateId: const TemplateId('T1'),
        version: 1,
        contentHash: 'h',
        body: TemplateBody(
          manufacturer: 'ACME',
          model: 'MDL',
          displayName: 'Widget',
          category: 'Video & Display',
          frontU: frontU,
          rearU: frontU,
          side: OccupancySide.both,
        ),
        capturedAt: DateTime.utc(2026),
      ),
    };

ElevationSheet _build({
  int heightU = 42,
  bool mirror = true,
  SheetRole role = SheetRole.rackElevationFront,
  List<DeviceInstance>? devices,
  Map<String, TemplateSnapshot>? templates,
  List<RevisionEntry> revisions = const <RevisionEntry>[],
  Rack? rack,
  ProjectSettings? settings,
}) {
  rack ??= Rack(
    id: _rackId,
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: heightU,
    order: const FracIndex('a0'),
    meta: testMeta(),
    mirrorRearElevation: mirror,
  );
  final set = SheetSet.forRacks(<Rack>[rack]);
  return buildElevationSheet(
    sheet: set.sheets.firstWhere((s) => s.role == role),
    rack: rack,
    devices: devices ?? <DeviceInstance>[_device(id: 'amp', ru: 3)],
    templates: templates ?? _templates(),
    info: fullProjectInfo(),
    settings: settings ?? ProjectSettings(),
    revisions: revisions,
    fileName: 'smith.rppj',
    issuedAt: DateTime.utc(2026, 7, 18),
    measurer: FakeMeasurer(),
  );
}

List<String> _texts(ElevationSheet sheet) =>
    sheet.scene.ops.whereType<OpText>().map((o) => o.text).toList();

Len _mm(int mm) => Len(mm * 1000000);

/// A 42 U closet rack with DR-239's envelope entered: a front door with
/// both clearances, a rear door with only its swing space.
Rack _closet({Len? width, bool frontDoor = true}) => Rack(
  id: _rackId,
  name: 'MASTER RACK',
  designator: 'RK-1',
  heightU: 42,
  order: const FracIndex('a0'),
  meta: testMeta(),
  overallWidth: width ?? _mm(600),
  overallDepth: _mm(1000),
  overallHeight: _mm(2000),
  hasFrontDoor: frontDoor,
  frontRailClearance: _mm(75),
  frontDoorClearance: _mm(600),
  hasRearDoor: true,
  rearDoorClearance: _mm(550),
);

final _metric = ProjectSettings(displayUnits: UnitSystem.metric);

Iterable<String> _envelopeLines(ElevationSheet sheet) =>
    _texts(sheet).where((t) => t.startsWith('ENCLOSURE'));

void main() {
  group('the scale is chosen against what is actually drawn', () {
    test('a 42 U rack on ANSI B portrait lands at 1:8', () {
      expect(_build().scale.label, '1:8');
    });

    test('a 45 U rack — the worked example in docs/08 §6.1 — also lands '
        'at 1:8', () {
      expect(_build(heightU: 45).scale.label, '1:8');
    });

    test('EVERY legal rack height (1..60 U, CR-038) fits a STANDARD '
        'ratio', () {
      // §6.2's `TilingStrategy.geometric` is NOT built, on the argument
      // that every legal rack fits ANSI B portrait. That is a claim about
      // sixty cases, so all sixty are checked rather than one.
      for (var heightU = 1; heightU <= 60; heightU++) {
        final scale = _build(heightU: heightU).scale;
        expect(scale.isToScale, isTrue, reason: '${heightU}U reported NTS');
      }
      // The tallest legal rack needs 1:10 — 60 U is 105 in, and at 1:8
      // that is 945 pt against the drawing area. Stated because it is the
      // boundary the tiler would otherwise have been needed for.
      //
      // 56 U SINCE M6-G1, 57 U BEFORE. The zone band (DR-215) takes 19.68
      // pt of height, and 57 U is the one rack height it moves: 1:8 to
      // 1:10. Measured over 1..60 U against main; no other height changed.
      //
      // 55 U SINCE DR-240. The sixth note line takes 10 pt more, and 56 U
      // is the one rack height it moves, by the same measurement.
      expect(_build(heightU: 60).scale.label, '1:10');
      expect(_build(heightU: 57).scale.label, '1:10');
      expect(_build(heightU: 56).scale.label, '1:10');
      expect(_build(heightU: 55).scale.label, '1:8');
    });

    test('a SMALL rack is drawn LARGER — the fit is real, not a constant', () {
      // If `_fitElevation` were hardcoded, every rack would print at 1:8
      // and this file would prove nothing.
      final small = _build(heightU: 6).scale;
      expect(small.denominator, lessThan(8));
      expect(small.isToScale, isTrue);
    });

    test('the WIDTH axis constrains too, not only the height', () {
      // A 6 U rack is only 756 pt tall at 1:1, which fits the drawing area
      // vertically — but the ruler + panel + gutter is ~295 diagram units
      // wide, so 1:1 and 1:2 overflow 690 pt horizontally. A fit that only
      // looked at height would pick a bigger scale than this.
      expect(_build(heightU: 6).scale.denominator, greaterThanOrEqualTo(4));
    });

    test('the scale bar fits the frame at every reachable ratio', () {
      // `buildGraphicScaleBar` is always ONE FOOT of reality, which is only
      // safe because no rack is ever drawn larger than 1:4. Asserted rather
      // than argued.
      for (final heightU in <int>[1, 6, 12, 24, 42, 45, 60]) {
        final scale = _build(heightU: heightU).scale;
        expect(
          graphicScaleBarPoints(scale.physicalRatio),
          lessThan(690),
          reason: '${heightU}U at ${scale.label}',
        );
      }
    });
  });

  group('THE FALLBACK IS REACHABLE, AND IT CANNOT LIE ABOUT THE RATIO', () {
    // ====================================================================
    // THE COMMENT THAT SAID THIS COULD NOT HAPPEN WAS WRONG.
    // ====================================================================
    // `_fitElevation` used to carry "Unreachable for a legal rack (heightU
    // ≤ 60, CR-038) on ANSI B" over the branch below, and `drawing_scale`
    // used to carry "every legal rack fits ANSI B portrait at 1:8". Both
    // are false, and believing them is how the branch came to be treated as
    // untestable — while shipping a label derived from an arbitrary drawn
    // factor through a 2% window.
    //
    // Nothing illegal is needed to reach it. A 60 U rack (CR-038's own
    // maximum) holding one device tall enough to keep its `name` line, with
    // a name long enough to outrun the 690 pt drawing area: annotation is
    // pinned to a constant PAPER size by `RackTypeScale.forPaper`, so that
    // ink costs the same at every ratio and no standard ratio can absorb
    // it.
    ElevationSheet overrunning({int nameLength = 169}) => _build(
      heightU: 60,
      devices: <DeviceInstance>[
        DeviceInstance(
          id: const Uuid('wide'),
          kind: DeviceKind.rackDevice,
          templateRef: const TemplateRef(
            templateId: TemplateId('T1'),
            version: 1,
            contentHash: 'h',
          ),
          designator: 'AMP-1',
          name: 'W' * nameLength,
          placement: const RailPlacement(
            rackId: _rackId,
            ruIndex: 1,
            face: Face.front,
          ),
          meta: testMeta(),
        ),
      ],
      templates: _tallTemplates(60),
    );

    test('a legal rack really does push the fit off EVERY standard '
        'ratio', () {
      // Stated as its own assertion so the group below cannot pass
      // vacuously against a sheet that quietly landed on a standard fit.
      final sheet = overrunning();
      expect(sheet.fit.fits, isFalse);
      expect(sheet.fit.overrunPt, greaterThan(0));
    });

    test('the SCALE field names the ratio the sheet is drawn at, to the '
        'nanometre', () {
      final sheet = overrunning();

      // Not "a standard-looking ratio" — THE ratio, checked against the
      // physical chain from literals: 60 U x 1.75 in x 72 pt/in.
      expect(sheet.scale.label, '1:32');
      expect(sheet.scale.physicalRatio.k, closeTo(1 / 32, 1e-12));

      final drawn =
          sheet.rackScene.chassisBounds.height *
          sheet.scale.sceneFactor.unitsToPoints;
      expect(drawn, closeTo(60 * 1.75 * 72 / 32, 1e-9));
      expect(drawn, closeTo(236.25, 1e-9));
    });

    test('NO drawn ratio inside the 2% window is ever printed as its '
        'neighbour', () {
      // The shipped bug, swept across the whole family this fixture
      // generates: whatever ratio each sheet lands on, the label is either
      // NTS or the ratio itself — never a nearby one.
      for (var n = 150; n <= 260; n += 1) {
        final sheet = overrunning(nameLength: n);
        final label = sheet.scale.label;
        if (label == 'NTS') continue;
        final printed = int.parse(label.substring(2));
        expect(
          sheet.scale.physicalRatio.k,
          closeTo(1 / printed, 1e-9 / printed),
          reason: 'name length $n printed $label',
        );
      }
    });

    test('the fit was measured on the scene that is EMITTED', () {
      // ==================================================================
      // THE FIXED POINT. The old fallback fitted against a probe built at
      // 1:96 and emitted a scene built at a different factor, so the
      // drawing on the page was never the drawing the fit was measured on
      // — and it was always the WIDER of the two.
      // ==================================================================
      final sheet = overrunning();
      final s = sheet.scale.sceneFactor.unitsToPoints;
      final bounds = sheet.rackScene.scene.bounds;
      final area = elevationAreaOf(
        SheetLayout.resolve(
          // THE SHEET'S OWN GEOMETRY: an elevation is zoned (DR-215).
          geometry: const SheetGeometry(SheetSize.ansiBPortrait, zoned: true),
          revisionRowCount: 1,
        ).drawingArea,
      );

      final measured = <double>[
        bounds.width * s - area.width,
        bounds.height * s - area.height,
      ].reduce((a, b) => a > b ? a : b);

      expect(sheet.fit.overrunPt, closeTo(measured, 1e-9));
      // ...and it is the WIDTH that overruns: 2.37 pt of label, plus the
      // 19.68 pt the zone band took from the drawing area (DR-215).
      expect(bounds.width * s, greaterThan(area.width));
      expect(
        sheet.fit.overrunPt,
        closeTo(2.366 + 2 * (kZoneBandWidthPt - kPlainInsetPt), 0.01),
      );
    });

    test('the overrun is REPORTED, not silently shipped', () {
      final sheet = overrunning();
      expect(sheet.fit.notice, isNotNull);
      expect(sheet.fit.notice, contains('past the drawing area'));
      expect(sheet.fit.notice, contains('22.0 pt'));
      // ...and the sheet IS still scalable, which is what the notice says.
      expect(sheet.scale.isToScale, isTrue);
      expect(sheet.scale.notice, isNull);
    });

    test('an ordinary rack reports nothing at all', () {
      // The notices have to stay silent on the common case or they are
      // noise, and nobody reads them.
      for (final heightU in <int>[1, 6, 12, 24, 42, 45, 57, 60]) {
        final sheet = _build(heightU: heightU);
        expect(sheet.fit.fits, isTrue, reason: '${heightU}U overruns');
        expect(sheet.fit.notice, isNull, reason: '${heightU}U');
        expect(sheet.scale.notice, isNull, reason: '${heightU}U');
      }
    });

    test('NTS is a REAL path: when a fit exists, it is taken and it '
        'fits', () {
      // Far past the point where any standard ratio helps, the refinement
      // does find a factor the emitted scene fits inside — and that factor
      // is not a standard one, so the sheet prints NTS. The label is still
      // the truth about the drawing, which is the whole invariant.
      final sheet = overrunning(nameLength: 20000);

      expect(sheet.scale.isToScale, isFalse);
      expect(sheet.scale.label, 'NTS');
      expect(sheet.fit.fits, isTrue);
      expect(sheet.fit.notice, isNull);
      expect(sheet.scale.notice, contains('NOT TO SCALE'));
      expect(
        standardDenominatorDrawnAt(sheet.scale.physicalRatio),
        isNull,
        reason: 'an NTS sheet must not be at a standard ratio after all',
      );
    });
  });

  // DR-239 §11.238.4 (`#1014`): the printed dimension a cabinetmaker can be
  // handed. Asserted VERBATIM, because `_band` cuts a long note with an
  // ellipsis and a contains() check would pass on the cut one.
  group('the elevation prints the envelope (DR-239)', () {
    test("THE FRONT SHEET CARRIES THE FRONT DOOR, the rear the rear's", () {
      expect(_envelopeLines(_build(rack: _closet(), settings: _metric)), [
        'ENCLOSURE 600 W x 1000 D x 2000 H MM; FRONT DOOR 75 RAIL, 600 SWING',
      ]);
      expect(
        _envelopeLines(
          _build(
            rack: _closet(),
            settings: _metric,
            role: SheetRole.rackElevationRear,
          ),
        ),
        ['ENCLOSURE 600 W x 1000 D x 2000 H MM; REAR DOOR — RAIL, 550 SWING'],
        reason: 'an unknown rail clearance is a dash, never a guess (G4)',
      );
    });

    test('A RACK WITH NO NUMBER ENTERED PRINTS NO LINE, a ticked door '
        'alone included, and no door prints the size alone', () {
      expect(_envelopeLines(_build()), isEmpty);
      // Every starter ticks a door and enters no size.
      final doorOnly = Rack(
        id: _rackId,
        name: 'MASTER RACK',
        designator: 'RK-1',
        heightU: 42,
        order: const FracIndex('a0'),
        meta: testMeta(),
        hasFrontDoor: true,
      );
      expect(_envelopeLines(_build(rack: doorOnly)), isEmpty);
      expect(
        _envelopeLines(
          _build(rack: _closet(frontDoor: false), settings: _metric),
        ),
        ['ENCLOSURE 600 W x 1000 D x 2000 H MM'],
      );
    });

    test('in imperial it prints inches, as the load summary does', () {
      const line =
          'ENCLOSURE 23.6 W x 39.4 D x 78.7 H IN; FRONT DOOR 3.0 RAIL, '
          '23.6 SWING';
      expect(_envelopeLines(_build(rack: _closet())), [line]);
    });
  });

  group('the sheet says what it is and what it is not', () {
    test('the FRONT sheet states what the ratio applies to', () {
      expect(_texts(_build()), contains(kScaleAppliesNote));
    });

    test('the REAR sheet states that port detail is NOT issued', () {
      // §2.2 wants connector fields and per-port labels here. There are no
      // Links in this build, so the section is omitted — and because that
      // changes what the sheet promises, it is said ON the sheet.
      expect(
        _texts(_build(role: SheetRole.rackElevationRear)),
        contains(kRearDetailNote),
      );
    });

    test('a MIRRORED rear elevation says it is mirrored', () {
      expect(
        _texts(_build(role: SheetRole.rackElevationRear)),
        contains(kMirroredChip),
      );
    });

    test('an UNMIRRORED rear elevation carries the CR-035 chip', () {
      final texts = _texts(
        _build(role: SheetRole.rackElevationRear, mirror: false),
      );
      expect(texts, contains(kNotMirroredChip));
      expect(texts, isNot(contains(kMirroredChip)));
    });

    test('the FRONT sheet carries NEITHER mirroring chip', () {
      final texts = _texts(_build());
      expect(texts, isNot(contains(kMirroredChip)));
      expect(texts, isNot(contains(kNotMirroredChip)));
      expect(texts, isNot(contains(kRearDetailNote)));
    });

    test('no empty text op ever reaches the scene', () {
      for (final op in _build().scene.ops.whereType<OpText>()) {
        expect(op.text, isNotEmpty);
      }
    });
  });

  group('the elevation is SPLICED, not redrawn', () {
    test('the rack scene sits inside exactly one save/transform/restore '
        'bracket', () {
      final sheet = _build();
      final ops = sheet.scene.ops;

      final saveIndex = ops.indexWhere((o) => o is OpSave);
      expect(saveIndex, isNonNegative);
      expect(ops[saveIndex + 1], isA<OpTransform>());

      // Every op of the rack scene appears, in order, immediately after the
      // transform — i.e. the sheet CONCATENATED them rather than rebuilding
      // anything.
      final rackOps = sheet.rackScene.scene.ops;
      final start = saveIndex + 2;
      final spliced = ops.sublist(start, start + rackOps.length);
      expect(identical(spliced.first, rackOps.first), isTrue);
      expect(identical(spliced.last, rackOps.last), isTrue);
      expect(ops[saveIndex + 2 + rackOps.length], isA<OpRestore>());
    });

    test('the bracket transform is translate then uniform positive scale', () {
      final transform = _build().scene.ops.whereType<OpTransform>().first.m;
      final sx = transform.getColumn(0).x;
      final sy = transform.getColumn(1).y;

      expect(sx, greaterThan(0));
      expect(sy, closeTo(sx, 1e-12));
      // No shear.
      expect(transform.getColumn(0).y, closeTo(0, 1e-12));
      expect(transform.getColumn(1).x, closeTo(0, 1e-12));
    });

    test('save and restore balance across the whole sheet', () {
      var depth = 0;
      for (final op in _build().scene.ops) {
        if (op is OpSave) depth++;
        if (op is OpRestore) depth--;
        expect(depth, greaterThanOrEqualTo(0));
      }
      expect(depth, 0);
    });
  });

  group('the print treatment reaches the rack scene', () {
    test('the RU ruler is on BOTH edges (§2.2)', () {
      final sheet = _build(heightU: 12);
      final ruler = sheet.rackScene.scene.ops
          .whereType<OpText>()
          .where((o) => o.text == '5')
          .toList();

      // One per edge, at the same Y and different X.
      expect(ruler, hasLength(2));
      expect(ruler[0].at.y, closeTo(ruler[1].at.y, 1e-9));
      expect(ruler[0].at.x, isNot(closeTo(ruler[1].at.x, 1e-9)));
    });

    test('device blocks carry the RU SPAN label, not the bare U badge', () {
      final texts = _build(
        devices: <DeviceInstance>[_device(id: 'amp', ru: 12)],
      ).rackScene.scene.ops.whereType<OpText>().map((o) => o.text).toList();

      expect(texts, contains('2U · 12–13'));
      expect(texts, isNot(contains('2U')));
    });

    test('text is INFLATED so it clears the §6.2 print floor', () {
      // At 1:8 the scene's smallest text would be 8 × 0.716 = 5.73 pt on
      // paper — under the 6.0 pt hard floor. The type scale is what fixes
      // that, and `minTextSizePt × sceneFactor` is what makes the check
      // meaningful rather than decorative.
      final sheet = _build();
      final onPaper =
          sheet.rackScene.scene.minTextSizePt *
          sheet.scale.sceneFactor.unitsToPoints;

      expect(onPaper, greaterThanOrEqualTo(6.0));
      expect(onPaper, closeTo(kMinRackPaperPt, 1e-9));
    });

    test('the whole sheet clears the hard floor', () {
      final sheet = _build();
      expect(sheet.legibility.meetsHardFloor, isTrue);
      expect(sheet.scene.minTextSizePt, greaterThanOrEqualTo(kMinPrintPt));
    });

    test('a 1 U device block at 1:8 keeps its label INSIDE its body', () {
      // The risk the type scale creates: inflating text so it clears the
      // print floor can make a label taller than the block it belongs to,
      // and `PdfGraphics.drawString` neither wraps nor clips. This asserts
      // the INK, measured through the same `TextMeasurer` the layer drew
      // with, against the body rect.
      final measurer = FakeMeasurer();
      final oneU = const RackGeometry(42).deviceRect(1, 1);
      final built = buildDeviceLayer(
        DeviceInstance(
          id: const Uuid('d'),
          kind: DeviceKind.rackDevice,
          templateRef: const TemplateRef(
            templateId: TemplateId('T1'),
            version: 1,
            contentHash: 'h',
          ),
          designator: 'AMP-1',
          name: 'A name that will not fit',
          placement: const RailPlacement(
            rackId: _rackId,
            ruIndex: 1,
            face: Face.front,
          ),
          meta: testMeta(),
        ),
        TemplateBody(
          manufacturer: 'M',
          model: 'X',
          displayName: 'A type name that will not fit either',
        ),
        deviceH: 1,
        width: oneU.width,
        height: oneU.height,
        lod: LodLevel.full,
        palette: const RackPalette(),
        measurer: measurer,
        typeScale: RackTypeScale.forPaper(sceneFactor: 126 / (22 * 8)),
      );

      // THE TEXT'S ink, not the fragment's: the body's own 1 pt outline
      // straddles the rect edge by half its width, which is correct and
      // has nothing to do with whether a LABEL overflows.
      final labels = built.ops.whereType<OpText>().toList();
      expect(labels, isNotEmpty, reason: 'nothing to measure');
      final ink = inkBoundsOf(labels, measurer: measurer)!;

      expect(ink.bottom, lessThanOrEqualTo(oneU.height + 1e-9));
      expect(ink.top, greaterThanOrEqualTo(-1e-9));
      expect(ink.left, greaterThanOrEqualTo(-1e-9));
      expect(ink.right, lessThanOrEqualTo(oneU.width + 1e-9));
    });

    // ================================================================
    // THE LABEL LADDER: THE DESIGNATOR IS THE LAST RUNG, NOT THE FIRST
    // ================================================================
    // The first fix for "a label taller than its block" guarded the whole
    // branch with `_pad + designatorPt <= height - _pad`, which blacked
    // out designator, badge, name AND type together for every 1U device
    // on any elevation at 1:10 or smaller — silently. See
    // `device_layer.dart`'s header.
    group('the label ladder', () {
      DeviceLayerBuild build({
        required double height,
        RackTypeScale typeScale = const RackTypeScale.identity(),
        TextMeasurer? measurer,
      }) => buildDeviceLayer(
        DeviceInstance(
          id: const Uuid('d'),
          kind: DeviceKind.rackDevice,
          templateRef: const TemplateRef(
            templateId: TemplateId('T1'),
            version: 1,
            contentHash: 'h',
          ),
          designator: 'AMP-1',
          name: 'Amp',
          placement: const RailPlacement(
            rackId: _rackId,
            ruIndex: 1,
            face: Face.front,
          ),
          meta: testMeta(),
        ),
        TemplateBody(manufacturer: 'M', model: 'X', displayName: 'T'),
        deviceH: 1,
        width: 200,
        height: height,
        lod: LodLevel.full,
        palette: const RackPalette(),
        measurer: measurer ?? FakeMeasurer(),
        typeScale: typeScale,
      );

      test('a 1 U block at 1:10 still carries its designator and badge', () {
        // THE SHIPPED BUG, at the exact numbers that produced it: a legal
        // 58–60U rack (kMaxRackHeightU = 60, CR-038) fits at 1:10, where
        // `RackTypeScale.forPaper` inflates the 11-unit designator to
        // 15.61 and `4 + 15.61 <= 22 - 4` is false. Every 1U device on
        // both elevations became an anonymous rectangle.
        final typeScale = RackTypeScale.forPaper(sceneFactor: 126 / (22 * 10));
        final designatorPt = typeScale.size(RackTextSizes.designator);
        expect(
          designatorPt,
          greaterThan(RackGeometry.unitsPerRu - 2 * 4),
          reason: 'this fixture no longer reaches the blackout at all',
        );
        expect(
          designatorPt,
          lessThanOrEqualTo(RackGeometry.unitsPerRu),
          reason: 'the glyphs do fit the body; only the padding did not',
        );

        final built = build(
          height: RackGeometry.unitsPerRu,
          typeScale: typeScale,
        );
        final texts = built.ops.whereType<OpText>().map((o) => o.text);

        expect(texts, contains('AMP-1'));
        expect(texts, contains('1U'));
        expect(built.labelDropped, isFalse);
      });

      test('the pad shrinks before the line is given up, and the ink '
          'stays inside the body', () {
        final measurer = FakeMeasurer();
        const height = 12.0;
        final built = build(height: height, measurer: measurer);
        final labels = built.ops.whereType<OpText>().toList();

        expect(labels, isNotEmpty);
        final ink = inkBoundsOf(labels, measurer: measurer)!;
        expect(ink.top, greaterThanOrEqualTo(-1e-9));
        expect(ink.bottom, lessThanOrEqualTo(height + 1e-9));
      });

      test('type is dropped before name, and name before the designator', () {
        // Rungs 1, 2, 3 — each height keeps strictly more than the last.
        List<String> textsAt(double height) => build(
          height: height,
        ).ops.whereType<OpText>().map((o) => o.text).toList();

        expect(textsAt(60), containsAll(<String>['AMP-1', '1U', 'Amp', 'T']));
        expect(textsAt(35), containsAll(<String>['AMP-1', '1U', 'Amp']));
        expect(textsAt(35), isNot(contains('T')));
        expect(textsAt(22), containsAll(<String>['AMP-1', '1U']));
        expect(textsAt(22), isNot(contains('Amp')));
      });

      test('a body SHORTER THAN ITS GLYPHS drops the label AND SAYS SO', () {
        // The bottom of the ladder. The body is still drawn — an
        // undrawn device would be worse — but the omission is reported
        // rather than left for someone to find on site.
        final built = build(height: 8);

        expect(built.ops.whereType<OpText>(), isEmpty);
        expect(built.ops.whereType<OpRoundRect>(), hasLength(1));
        expect(
          built.labelDropped,
          isTrue,
          reason: 'an unlabelled block that reports nothing is the bug',
        );
      });

      test('a labelled block never claims a dropped label', () {
        expect(build(height: 60).labelDropped, isFalse);
        expect(build(height: 22).labelDropped, isFalse);
      });
    });

    test('a PASSIVE device is hatched and an active one is not', () {
      List<OpClipRect> clipsFor(String category) => _build(
        templates: _templates(category: category),
      ).rackScene.scene.ops.whereType<OpClipRect>().toList();

      // The hatch is `clipRect` + 45° lines — no new canvas method
      // (CR-088), so the clip is what identifies it.
      expect(clipsFor('Passive & Mechanical'), isNotEmpty);
      expect(clipsFor('Video & Display'), isEmpty);
    });

    test('the lifecycle border is DASH and WEIGHT, never hue alone (P4)', () {
      Stroke bodyStroke(LifecycleStatus status) => _build(
        devices: <DeviceInstance>[_device(id: 'amp', ru: 3, lifecycle: status)],
      ).rackScene.scene.ops.whereType<OpRoundRect>().first.stroke!;

      final newly = bodyStroke(LifecycleStatus.new_);
      final future = bodyStroke(LifecycleStatus.future);
      final removed = bodyStroke(LifecycleStatus.removed);
      final existing = bodyStroke(LifecycleStatus.existing);

      // The default is unchanged from the plain device outline.
      expect(newly.dash, isNull);
      expect(newly.widthPt, 1);
      // The others each differ in a channel that survives a photocopy.
      expect(future.dash, isNotNull);
      expect(removed.dash, isNotNull);
      expect(future.dash, isNot(removed.dash));
      expect(existing.widthPt, isNot(newly.widthPt));
      // ...and NONE of them differ only in colour.
      final all = <Stroke>[newly, future, removed, existing];
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          expect(
            all[i].dash != all[j].dash || all[i].widthPt != all[j].widthPt,
            isTrue,
            reason: 'two states differ only by colour',
          );
        }
      }
    });

    test('the CUMULATIVE readings are in the SCALED scene, beside the '
        'rack', () {
      // ==============================================================
      // ADDED BECAUSE A MUTATION SURVIVED.
      // ==============================================================
      // The rack-wide SUMMARY (`RACK TOTAL`, `DRAW`, `HEAT`) is drawn on
      // the sheet at paper scale, and the test below asserts it. The
      // per-U-boundary CUMULATIVE readings are a different thing in a
      // different coordinate space — inside the scaled bracket, aligned to
      // the ruler — and dropping them entirely passed the whole suite.
      final sheet = _build(
        heightU: 12,
        devices: <DeviceInstance>[
          _device(id: 'a', ru: 1),
          _device(id: 'b', ru: 9),
        ],
        templates: _templates(weight: const Mass(1_000_000_000)),
      );

      final rackWidth = const RackGeometry(12).rackWidth;
      final readings = sheet.rackScene.scene.ops
          .whereType<OpText>()
          .where((o) => o.at.x > rackWidth && o.text.endsWith('lb'))
          .toList();

      // Boundaries 5, 10 and the rack top (12).
      expect(readings, hasLength(3));
      // They are CUMULATIVE: the reading nearer the top is never smaller.
      final byHeight = readings.toList()
        ..sort((a, b) => b.at.y.compareTo(a.at.y));
      final figures = byHeight
          .map((o) => double.parse(o.text.split(' ').first))
          .toList();
      for (var i = 1; i < figures.length; i++) {
        expect(figures[i], greaterThanOrEqualTo(figures[i - 1]));
      }
      // ...and the topmost equals the rack total on the sheet.
      expect(
        _texts(sheet).firstWhere((t) => t.startsWith('RACK TOTAL')),
        contains(byHeight.last.text),
      );
    });

    test('the load gutter reaches the sheet with an honest unknown count', () {
      final texts = _texts(
        _build(
          devices: <DeviceInstance>[
            _device(id: 'a', ru: 1),
            _device(id: 'b', ru: 10),
          ],
        ),
      );

      // No masses are authored, so nothing may print a bare figure.
      expect(texts.any((t) => t.startsWith('RACK TOTAL')), isTrue);
      expect(texts.any((t) => t.contains('(2 unknown)')), isTrue);
      expect(texts.any((t) => t.startsWith('DRAW')), isTrue);
      expect(texts.any((t) => t.startsWith('HEAT')), isTrue);
    });

    // ==================================================================
    // EVERY ROLLUP CARRIES ITS OWN COUNT TO PAPER, NOT JUST THE MASS ONE
    // ==================================================================
    // The four `(n unknown)` assertions in this repository all read the
    // MASS rollup, so replacing the suffix expression in `formatIntRollup`
    // (VA) or `formatBtuRollup` (BTU/hr) with `''` left every suite green
    // while `whole_house` T2.01/T2.02 lost "(10 unknown)" and
    // "(9 unknown)". The `≥` alone says a total is incomplete; only the
    // count says BY HOW MANY, which is the CR-114/G4 property
    // `Rollup.unknownCount` exists to carry (`derived/device_loads.dart`).
    //
    // The three expected numbers are DISTINCT and are derived from the
    // TEMPLATE BODIES, not from the rollups — two figures that both come
    // out of `resolveDeviceLoads` compare equal under a mutation that
    // breaks both.
    test('DRAW and HEAT each state their OWN unknown count, on the '
        'sheet', () {
      final bodies = <String, ({Mass? weight, int? va, int? watts})>{
        // Nothing unknown.
        'all': (weight: const Mass(1_000_000_000), va: 100, watts: 80),
        // mass + VA + BTU unknown.
        'none': (weight: null, va: null, watts: null),
        // VA + BTU unknown.
        'massOnly': (weight: const Mass(2_000_000_000), va: null, watts: null),
        // BTU unknown.
        'noWatts': (weight: const Mass(3_000_000_000), va: 50, watts: null),
      };
      final templates = <String, TemplateSnapshot>{
        for (final entry in bodies.entries)
          '${entry.key}@1': TemplateSnapshot(
            templateId: TemplateId(entry.key),
            version: 1,
            contentHash: 'h',
            body: TemplateBody(
              manufacturer: 'ACME',
              model: 'MDL',
              displayName: 'Widget',
              frontU: 2,
              rearU: 2,
              side: OccupancySide.both,
              weight: entry.value.weight,
              power: PowerProfile(
                apparentVA: entry.value.va,
                typicalWatts: entry.value.watts,
              ),
            ),
            capturedAt: DateTime.utc(2026),
          ),
      };
      var ru = 1;
      final devices = <DeviceInstance>[
        for (final key in bodies.keys)
          DeviceInstance(
            id: Uuid(key),
            kind: DeviceKind.rackDevice,
            templateRef: TemplateRef(
              templateId: TemplateId(key),
              version: 1,
              contentHash: 'h',
            ),
            designator: key.toUpperCase(),
            name: 'NAME',
            placement: RailPlacement(
              rackId: _rackId,
              ruIndex: (ru += 3) - 3,
              face: Face.front,
            ),
            meta: testMeta(),
          ),
      ];

      // Derived from the AUTHORED FIELDS, never from a `Rollup`.
      final expectedMass = bodies.values.where((b) => b.weight == null).length;
      final expectedVa = bodies.values.where((b) => b.va == null).length;
      final expectedBtu = bodies.values.where((b) => b.watts == null).length;
      expect(<int>{expectedMass, expectedVa, expectedBtu}, hasLength(3));

      final texts = _texts(_build(devices: devices, templates: templates));
      // Two spaces: the title block has its own `DRAWN` field, and the
      // summary lines are `LABEL  value`.
      String line(String prefix) =>
          texts.singleWhere((t) => t.startsWith('$prefix  '));

      expect(line('RACK TOTAL'), contains('($expectedMass unknown)'));
      expect(line('DRAW'), contains('($expectedVa unknown)'));
      expect(line('HEAT'), contains('($expectedBtu unknown)'));
      // ...and every one of them still says the total is a floor.
      for (final prefix in <String>['RACK TOTAL', 'DRAW', 'HEAT']) {
        expect(line(prefix), contains('≥'), reason: prefix);
      }
    });
  });

  // ====================================================================
  // WHAT THE SHEET SAYS ABOUT WHAT IT DOES NOT SHOW MUST BE TRUE OF THAT
  // SHEET
  // ====================================================================
  // T2.02 used to print T2.01's omission count over a bare frame. The
  // sentence is now per-face, and it is asserted HERE — on the composed
  // sheet, where it is actually emitted — rather than only on the
  // function that formats it.
  group('the omission sentence describes THIS sheet', () {
    /// A rack holding one FRONT-ONLY device and one BOTH-FACES device, so
    /// the two elevations legitimately disagree about their contents.
    ElevationSheet sheetFor(SheetRole role) => _build(
      role: role,
      devices: <DeviceInstance>[
        _device(id: 'both', ru: 3),
        DeviceInstance(
          id: const Uuid('frontonly'),
          kind: DeviceKind.rackDevice,
          templateRef: const TemplateRef(
            templateId: TemplateId('F1'),
            version: 1,
            contentHash: 'h',
          ),
          designator: 'FRONTONLY',
          name: 'NAME',
          placement: const RailPlacement(
            rackId: _rackId,
            ruIndex: 20,
            face: Face.front,
          ),
          meta: testMeta(),
        ),
      ],
      templates: <String, TemplateSnapshot>{
        ..._templates(),
        'F1@1': TemplateSnapshot(
          templateId: const TemplateId('F1'),
          version: 1,
          contentHash: 'h',
          body: TemplateBody(
            manufacturer: 'ACME',
            model: 'MDL',
            displayName: 'Blank',
            frontU: 2,
            side: OccupancySide.front,
          ),
          capturedAt: DateTime.utc(2026),
        ),
      },
    );

    test('the stated count EQUALS the blocks the sheet is missing', () {
      for (final role in <SheetRole>[
        SheetRole.rackElevationFront,
        SheetRole.rackElevationRear,
      ]) {
        final sheet = sheetFor(role);
        final drawn = sheet.rackScene.devices.length;
        final omission = _texts(
          sheet,
        ).where((t) => t.startsWith('NOT DRAWN')).toList();

        if (drawn == 2) {
          expect(omission, isEmpty, reason: '$role draws everything');
          continue;
        }
        expect(omission, hasLength(1), reason: '$role');
        expect(
          omission.single,
          startsWith('NOT DRAWN HERE  ${2 - drawn} OF 2'),
        );
      }
    });

    test('T2.01 and T2.02 do NOT print the same sentence', () {
      // The whole defect in one assertion: the two sheets drew different
      // things and said the identical thing about it.
      String? omissionOf(SheetRole role) => _texts(
        sheetFor(role),
      ).where((t) => t.startsWith('NOT DRAWN')).firstOrNull;

      expect(
        omissionOf(SheetRole.rackElevationFront),
        isNot(omissionOf(SheetRole.rackElevationRear)),
      );
    });

    test('the rear sheet points at the front one rather than crying wolf', () {
      final omission = _texts(
        sheetFor(SheetRole.rackElevationRear),
      ).singleWhere((t) => t.startsWith('NOT DRAWN'));
      expect(omission, contains('1 ON FRONT'));
      expect(omission, isNot(contains('ONLY ON')));
    });
  });

  group('the drawing area is computed before the scale, and agrees', () {
    test('elevationAreaOf reserves both bands — 66 pt above, 34 pt '
        'below', () {
      // ==================================================================
      // THE LITERALS, BECAUSE THE CONSTANTS PROVE NOTHING ABOUT THEMSELVES.
      // ==================================================================
      // This used to read `area.top == drawing.top + kElevationHeaderBand`
      // — the same production constant `elevationAreaOf` adds, on both
      // sides of the equals. Changing 56 to 5 or to 500 kept it green; the
      // only mutation it could catch was exchanging the two bands with each
      // other. It is the shape of self-referential assertion this repo's
      // own comments say it keeps shipping.
      //
      // The numbers are checkable from the sheet instead of restated from
      // the source: the header band is six 8 pt note lines on a 10 pt
      // lead (DR-240; the sixth row is the note column's, and a sheet
      // that fills it is asserted with the ground bar note), and the
      // scale band holds a 6 pt tall bar
      // centred in it with its `1 ft` label. Both are asserted against the
      // INK that lands in them further down.
      final drawing = SheetLayout.resolve(
        // THE SHEET'S OWN GEOMETRY: an elevation is zoned (DR-215).
        geometry: const SheetGeometry(SheetSize.ansiBPortrait, zoned: true),
        revisionRowCount: 1,
      ).drawingArea;
      final area = elevationAreaOf(drawing);

      expect(kElevationHeaderBand, 66);
      expect(kElevationNoteLines, 6);
      expect(kElevationScaleBand, 34);
      expect(area.top - drawing.top, 66);
      expect(drawing.bottom - area.bottom, 34);
      expect(drawing.height - area.height, 100);
      expect(area.left, drawing.left);
      expect(area.width, drawing.width);
    });

    test('the reserved bands are the bands the sheet actually draws '
        'INTO', () {
      // The counterpart the literals above cannot supply: that 66 and 34
      // are not merely two numbers but the space the notes and the scale
      // bar occupy. Asserted on the emitted ops, in page coordinates, so
      // shrinking a band until its own content spills is a failure here
      // rather than a surprise on paper.
      final sheet = _build(heightU: 12, role: SheetRole.rackElevationRear);
      final drawing = SheetLayout.resolve(
        // THE SHEET'S OWN GEOMETRY: an elevation is zoned (DR-215).
        geometry: const SheetGeometry(SheetSize.ansiBPortrait, zoned: true),
        revisionRowCount: 1,
      ).drawingArea;
      final area = elevationAreaOf(drawing);

      // Every note/summary line sits inside the header band, and the last
      // one clears its own descender before the elevation starts.
      final band = sheet.scene.ops
          .whereType<OpText>()
          .where((o) => o.at.y >= drawing.top - 1e-9 && o.at.y < area.top)
          .toList();
      expect(band.length, greaterThanOrEqualTo(4));
      final lowest = band.map((o) => o.at.y).reduce((a, b) => a > b ? a : b);
      expect(
        lowest + kElevationNotePt,
        lessThanOrEqualTo(area.top),
        reason: 'the header band is too short for the lines it holds',
      );
      // The scale bar's rule sits in the lower band, and its ticks fit.
      final bar = sheet.scene.ops
          .whereType<OpLine>()
          .where((o) => o.a.y > area.bottom && o.a.y < drawing.bottom)
          .toList();
      expect(bar, isNotEmpty, reason: 'no scale bar in the scale band');
      for (final line in bar) {
        for (final y in <double>[line.a.y, line.b.y]) {
          expect(y, greaterThan(area.bottom));
          expect(y, lessThan(drawing.bottom));
        }
      }
    });

    test('more revisions shrink the drawing area, and it still fits', () {
      final none = _build();
      final many = _build(
        revisions: <RevisionEntry>[
          for (var i = 1; i <= 8; i++) testRevision('R$i', i),
        ],
      );

      // Both still land on a standard ratio; the taller revision block
      // simply leaves less room.
      expect(none.scale.isToScale, isTrue);
      expect(many.scale.isToScale, isTrue);
      expect(many.scene.ops.whereType<OpText>(), isNotEmpty);
    });
  });
}
