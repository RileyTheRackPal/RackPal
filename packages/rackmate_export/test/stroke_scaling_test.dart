// CR-082's TWO KNOBS, at a scale != 1.
//
// =====================================================================
// THE FIELD THAT HAD NO READERS
// =====================================================================
// `Stroke` carries `scaleWithGeometry` ("cable traces, symbol outlines and
// rack rails scale with the diagram; UI chrome does not") and
// `hairlineFloor` ("sheet furniture uses a 0.25 pt print floor; everything
// else 0.5 pt"). Both backends used to branch on `hairlineFloor` ALONE for
// both decisions, so `scaleWithGeometry` had ZERO readers anywhere in the
// repository — a production field whose only appearance was its own
// declaration.
//
// It was invisible because no caller had ever applied a scale != 1. The
// elevation sheets are the first: they wrap the whole rack scene in one
// `OpTransform` at 1:8. This file is the test that separates the two
// spellings, and it FAILS on the pre-fix backends — where a
// `scaleWithGeometry: false` stroke inside a scaled bracket came out
// scaled.
//
// Asserted on the emitted content stream, in PDF user space, because the
// question "how wide is this line ON PAPER" has no other honest answer.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_export/rackmate_export.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');

/// The scale the elevation sheets really use at 1:8: `126 / (22 * 8)`.
const double _k = 126 / (22 * 8);

/// The measurer `buildRackScene` is handed by the fixtures at the bottom of
/// this file. The REAL bundled face, because a device body's size — and so
/// whether its outline is emitted at all — depends on what its labels
/// measure.
late TextMeasurer _sceneMeasurer;

void main() {
  late Uint8List fontBytes;

  setUpAll(() {
    fontBytes = File(
      '../../apps/rackmate/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
    final doc = pw.Document();
    _sceneMeasurer = PdfFontMeasurer(<FontRef, PdfFont>{
      _font: PdfTtfFont(doc.document, ByteData.sublistView(fontBytes)),
    });
  });

  /// Draws one 100x100 rect with [stroke], inside a `scale(k)` bracket, and
  /// returns the line width that reached the paper.
  Future<double> widthOnPaper(Stroke stroke, {double scale = _k}) async {
    final doc = pw.Document(compress: false);
    final fonts = <FontRef, PdfFont>{
      _font: PdfTtfFont(doc.document, ByteData.sublistView(fontBytes)),
    };
    final measurer = PdfFontMeasurer(fonts);

    final scene = DiagramScene(
      ops: <DiagramOp>[
        const OpSave(),
        OpTransform(
          Matrix4.translationValues(50, 50, 0)
            ..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
        ),
        OpRect(const DBox.fromLtwh(0, 0, 100, 100), stroke: stroke),
        const OpRestore(),
      ],
      bounds: const DBox.fromLtwh(0, 0, 792, 1224),
      hits: const <HitRegion>[],
      minTextSizePt: 8,
      fragments: const <String, IntRange>{},
    );

    doc.addPage(
      buildSheetPage(
        size: SheetSize.ansiBPortrait,
        scene: scene,
        fonts: fonts,
        measurer: measurer,
      ),
    );

    final recovered = interpretContentStream(
      extractOperatorStream(await doc.save(), mustContain: ' re '),
    );
    // The one rect this scene draws, identified by its scaled size.
    return recovered.rects
        .firstWhere((r) => (r.width - 100 * scale).abs() < 1e-3)
        .lineWidthPt;
  }

  group('scaleWithGeometry decides whether the WIDTH scales', () {
    test('true (the default): the width scales with the drawing', () async {
      // A rack rail at 1:8 really is thinner on paper than at 1:1. This is
      // the behaviour every rack stroke has and must keep.
      expect(
        await widthOnPaper(const Stroke(argb: 0xFF000000, widthPt: 2)),
        closeTo(2 * _k, 1e-4),
      );
    });

    test('FALSE: the width is constant on paper — the assertion the old '
        'backends failed', () async {
      // Before the fix this returned 2 * 0.7159 = 1.432, because both
      // backends read `hairlineFloor` for this decision and this stroke
      // does not set it.
      expect(
        await widthOnPaper(
          const Stroke(
            argb: 0xFF000000,
            widthPt: 2,
            scaleWithGeometry: false,
          ),
        ),
        closeTo(2, 1e-4),
      );
    });

    test('the two spellings COINCIDE at scale 1 — which is why nothing '
        'moved on screen', () async {
      for (final scaleWithGeometry in <bool>[true, false]) {
        expect(
          await widthOnPaper(
            Stroke(
              argb: 0xFF000000,
              widthPt: 1.4,
              scaleWithGeometry: scaleWithGeometry,
            ),
            scale: 1,
          ),
          closeTo(1.4, 1e-4),
          reason: 'scaleWithGeometry: $scaleWithGeometry',
        );
      }
    });
  });

  group('hairlineFloor decides WHICH FLOOR, independently', () {
    test('signal geometry floors at 0.5 pt', () async {
      // 0.3 pt of rack rail at 1:8 would reach the paper at 0.215 pt, which
      // is below the ink a laser reliably lays down.
      expect(
        await widthOnPaper(const Stroke(argb: 0xFF000000, widthPt: 0.3)),
        closeTo(0.5, 1e-4),
      );
    });

    test('furniture floors at 0.25 pt', () async {
      expect(
        await widthOnPaper(
          const Stroke(
            argb: 0xFF000000,
            widthPt: 0.3,
            scaleWithGeometry: false,
            hairlineFloor: true,
          ),
        ),
        closeTo(0.3, 1e-4),
      );
      expect(
        await widthOnPaper(
          const Stroke(
            argb: 0xFF000000,
            widthPt: 0.1,
            scaleWithGeometry: false,
            hairlineFloor: true,
          ),
        ),
        closeTo(0.25, 1e-4),
      );
    });

    test('THE TWO KNOBS ARE INDEPENDENT — all four combinations differ '
        'where they should', () async {
      // The check that the fix actually DECOUPLED them rather than moving
      // the coupling. A scaling stroke with the furniture floor is a legal
      // combination and must behave as both fields say.
      final scalingFine = await widthOnPaper(
        const Stroke(argb: 0xFF000000, widthPt: 0.3, hairlineFloor: true),
      );
      // 0.3 * 0.7159 = 0.215, under the 0.25 furniture floor -> clamped.
      expect(scalingFine, closeTo(0.25, 1e-4));

      final scalingCoarse = await widthOnPaper(
        const Stroke(argb: 0xFF000000, widthPt: 1, hairlineFloor: true),
      );
      // 1 * 0.7159 = 0.716, well over the floor -> not clamped, and SCALED.
      expect(scalingCoarse, closeTo(_k, 1e-4));
    });

    test('NO STROKE IS EVER EMITTED AT ZERO (CR-082)', () async {
      for (final width in <double>[0, 0.0001, 0.01]) {
        for (final floor in <bool>[true, false]) {
          expect(
            await widthOnPaper(
              Stroke(
                argb: 0xFF000000,
                widthPt: width,
                hairlineFloor: floor,
              ),
            ),
            greaterThanOrEqualTo(0.25 - 1e-6),
            reason: 'width $width, hairlineFloor $floor',
          );
        }
      }
    });
  });

  group('the elevation sheets exercise this for real', () {
    test('sheetRule sets BOTH knobs deliberately', () {
      // Furniture is drawn at 1:1 today, so `scaleWithGeometry: false`
      // changes nothing now — it is set because the field is what the
      // backends read, and a title block that ever lands inside a scaled
      // bracket must not get a scaled rule.
      final rule = sheetRule(0xFF000000, 0.7);
      expect(rule.hairlineFloor, isTrue);
      expect(rule.scaleWithGeometry, isFalse);
    });

    group('rack geometry keeps the SCALING knob, so an elevation thins '
        'honestly', () {
      // ==================================================================
      // THIS GROUP USED TO BE A TEST OF `Stroke`'s CONSTRUCTOR DEFAULTS
      // WEARING A DEVICE-LAYER LABEL.
      // ==================================================================
      // It read, in full: `const bodyStroke = Stroke(argb: 0xFF334155,
      // widthPt: 1); expect(bodyStroke.scaleWithGeometry, isTrue);` — a
      // stroke the TEST built, and then `expect(1 * _k, greaterThan(0.5))`,
      // which is arithmetic on two of this file's own constants. Nothing
      // in it touched `device_layer.dart` or `rack_layer.dart`. Adding
      // `scaleWithGeometry: false` to the real device outline left every
      // device body on every elevation at a constant 1.0 pt instead of
      // thinning to 0.716 pt — the exact behaviour this file's header says
      // the CR-082 fix was for — and this assertion still passed, because
      // it read a stroke it had constructed itself.
      //
      // So the strokes below come OUT OF `buildRackScene`, and their
      // widths are measured on paper through the same real PDF backend the
      // rest of the file uses.

      test('the DEVICE BODY outline device_layer emits reaches paper at '
          '0.716 pt at 1:8, not 1.0', () async {
        final stroke = _deviceBodyStroke(lifecycleBorders: false);

        // Read off the emitted op, not restated.
        expect(stroke.widthPt, 1);
        expect(stroke.scaleWithGeometry, isTrue);
        expect(stroke.hairlineFloor, isFalse);
        // ...and what that means ON PAPER, which is the only claim a
        // reader of the sheet can check.
        expect(await widthOnPaper(stroke), closeTo(_k, 1e-4));
        expect(await widthOnPaper(stroke), closeTo(0.7159, 1e-3));
        // Above the 0.5 pt signal floor, so the thinning is real rather
        // than clamped away — which is what makes the mutation visible.
        expect(await widthOnPaper(stroke), greaterThan(0.5));
      });

      test('...and so does the LIFECYCLE border, which is what an '
          'elevation actually draws', () async {
        // The elevation sets `lifecycleBorders: true`, so the outline that
        // reaches a printed sheet comes from `lifecycleStroke`, not from
        // the plain branch above. Both are production strokes and both
        // must thin; testing only one leaves the shipped one uncovered.
        final stroke = _deviceBodyStroke(lifecycleBorders: true);

        expect(stroke.scaleWithGeometry, isTrue);
        expect(await widthOnPaper(stroke), closeTo(_k, 1e-4));
      });

      test('the CHASSIS FRAME rack_layer emits thins with the drawing '
          'too', () async {
        // 1.2 pt of frame at 1:8 is 0.859 pt on paper. A frame that did
        // not scale would be 40% heavier than the device blocks inside it
        // instead of 20% — visible on the sheet, invisible to any
        // assertion that reads a stroke the test built.
        final stroke = _chassisFrameStroke();

        expect(stroke.widthPt, closeTo(1.2, 1e-9));
        expect(stroke.scaleWithGeometry, isTrue);
        expect(await widthOnPaper(stroke), closeTo(1.2 * _k, 1e-4));
      });

      test('the two knobs are still INDEPENDENT on a production stroke', () {
        // `sheetRule` turns both off; rack geometry leaves both on. If a
        // future refactor re-coupled them, these two would move together.
        final furniture = sheetRule(0xFF000000, 0.7);
        final rack = _deviceBodyStroke(lifecycleBorders: false);

        expect(rack.scaleWithGeometry, isNot(furniture.scaleWithGeometry));
        expect(rack.hairlineFloor, isNot(furniture.hairlineFloor));
      });
    });

    // ==================================================================
    // THE ONE PRODUCTION STROKE WHERE THE TWO KNOBS DISAGREE
    // ==================================================================
    // `symbol_layer.dart`'s schematic header rule sets `hairlineFloor:
    // true`. Every other production stroke in the repository either sets
    // both (sheet furniture) or neither (rack geometry), so this is the
    // only one whose meaning MOVED when the backends stopped reading
    // `hairlineFloor` for the width decision: from `w = widthPt / k`
    // (constant on the device) to `w = widthPt` (scaling with the CTM).
    //
    // The scaling reading is the correct one. CR-082, verbatim: "Cable
    // traces, SYMBOL OUTLINES and rack rails scale". The rule is drawn in
    // the symbol's own local coordinates, one op after the body outline
    // that has always scaled, so a rule that stayed one device-pixel wide
    // would read as a different weight at every zoom and print differently
    // again inside a scaled sheet bracket. `hairlineFloor` is kept for
    // what it now means alone: this rule may print finer than 0.5 pt.
    //
    // Not user-visible today (no production renderer replays a symbol
    // scene), which is exactly why it needs a test rather than a reviewer.
    group('the SCHEMATIC HEADER RULE scales, and prints below the signal '
        'floor', () {
      Stroke headerRule() => buildSymbolLayer(
        _headerRuleSymbol(),
        palette: const SchematicPalette(),
        measurer: _sceneMeasurer,
      ).ops.whereType<OpLine>().single.s;

      test('it names BOTH knobs, and they disagree', () {
        final rule = headerRule();
        expect(rule.widthPt, 1);
        expect(
          rule.scaleWithGeometry,
          isTrue,
          reason: 'a symbol outline scales with the diagram (CR-082)',
        );
        expect(
          rule.hairlineFloor,
          isTrue,
          reason: 'a rule may legitimately print finer than 0.5 pt',
        );
        // The property that makes this the interesting site at all: its
        // pairing matches NEITHER of the other two production patterns —
        // sheet furniture (false, true) nor rack geometry (true, false) —
        // so it is the only stroke whose meaning the split could move.
        final furniture = sheetRule(0xFF000000, 0.7);
        final rack = _deviceBodyStroke(lifecycleBorders: false);
        expect(rule.scaleWithGeometry, isNot(furniture.scaleWithGeometry));
        expect(rule.hairlineFloor, isNot(rack.hairlineFloor));
      });

      test('ON PAPER it scales with the bracket, k times, not 1/k', () async {
        // The whole difference between the two spellings, measured. At
        // k = 0.716 the pre-split behaviour put 1.397 pt on the paper;
        // scaling puts 0.716 pt. A factor of k^2 apart.
        final rule = headerRule();
        expect(await widthOnPaper(rule), closeTo(_k, 1e-4));
        expect(await widthOnPaper(rule), isNot(closeTo(1 / _k, 1e-3)));
      });

      test(
        'and hairlineFloor is what lets it go under 0.5 pt at all',
        () async {
          // 1 pt at 1:32 is 0.086 pt, clamped to the 0.25 pt PRINT floor
          // rather than the 0.5 pt signal floor. Without `hairlineFloor`
          // this rule would be twice as heavy on a small-ratio sheet.
          const small = 126 / (22 * 32);
          final onPaper = await widthOnPaper(headerRule(), scale: small);
          expect(onPaper, closeTo(0.25, 1e-4));
          // And a stroke WITHOUT the print floor clamps to 0.5 instead —
          // the assertion that makes the line above about `hairlineFloor`
          // rather than about the clamp existing.
          expect(
            await widthOnPaper(
              const Stroke(argb: 0xFF000000, widthPt: 1),
              scale: small,
            ),
            closeTo(0.5, 1e-4),
          );
        },
      );
    });
  });
}

// ── the schematic symbol whose header rule is measured above ─────────────

/// The smallest `RenderedSymbol` that emits a header rule: one port, so
/// `buildSymbolLayer` still produces exactly one `OpLine`.
RenderedSymbol _headerRuleSymbol() => buildSymbolGeometry(
  id: 'dev-1',
  designator: 'MTX-1',
  ports: <PortDef>[
    PortDef(
      key: const PortKey('J01'),
      label: 'IN 1',
      connector: const ConnectorTypeId('test'),
      signalFamily: const SignalFamilyId('video.hdmi.2_0'),
      face: Face.rear,
      position: const PanelPosition(
        ruOffset: 0,
        xTwelfth: 0,
        xFineNm: Len(0),
        yFineNm: Len(0),
      ),
      order: const FracIndex('a0'),
      direction: PortDirection.sink,
    ),
  ],
  headerHeight: 24,
  portSize: 8,
  portPitch: 16,
  minBodyWidth: 180,
);

// ── the strokes rack geometry ACTUALLY emits ─────────────────────────────

const Uuid _rackId = Uuid('rack-1');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

/// A 12 U rack holding one 2 U device — the smallest fixture that makes
/// `buildRackScene` emit both a chassis frame and a device body.
RackScene _rackScene({required bool lifecycleBorders}) {
  final rack = Rack(
    id: _rackId,
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  return buildRackScene(
    rack: rack,
    devices: <DeviceInstance>[
      DeviceInstance(
        id: const Uuid('dev-1'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('T1'),
          version: 1,
          contentHash: 'h',
        ),
        designator: 'AMP-1',
        name: 'Zone amp',
        placement: const RailPlacement(
          rackId: _rackId,
          ruIndex: 3,
          face: Face.front,
        ),
        meta: _meta(),
      ),
    ],
    templates: <String, TemplateSnapshot>{
      'T1@1': TemplateSnapshot(
        templateId: const TemplateId('T1'),
        version: 1,
        contentHash: 'h',
        body: TemplateBody(
          manufacturer: 'ACME',
          model: 'AMP-8',
          displayName: 'Eight-channel amp',
          frontU: 2,
          side: OccupancySide.front,
        ),
        capturedAt: DateTime.utc(2026),
      ),
    },
    face: Face.front,
    lod: LodLevel.full,
    measurer: _sceneMeasurer,
    options: lifecycleBorders
        ? RackSceneOptions.screen.copyWith(lifecycleBorders: true)
        : RackSceneOptions.screen,
  );
}

/// The device body outline `device_layer.dart` emitted, identified by the
/// palette colour it is drawn in rather than by its position in the list.
Stroke _deviceBodyStroke({required bool lifecycleBorders}) {
  const palette = RackPalette();
  final strokes = _rackScene(lifecycleBorders: lifecycleBorders).scene.ops
      .whereType<OpRoundRect>()
      .map((o) => o.stroke)
      .whereType<Stroke>()
      .where((s) => s.argb == palette.deviceStroke)
      .toList();
  if (strokes.length != 1) {
    throw StateError(
      'expected exactly one device body outline, found ${strokes.length} — '
      'the fixture no longer identifies what it is about',
    );
  }
  return strokes.single;
}

/// The chassis frame outline `rack_layer.dart` emitted.
Stroke _chassisFrameStroke() {
  const palette = RackPalette();
  final strokes = _rackScene(lifecycleBorders: false).scene.ops
      .whereType<OpRect>()
      .map((o) => o.stroke)
      .whereType<Stroke>()
      .where((s) => s.argb == palette.frame)
      .toList();
  if (strokes.isEmpty) {
    throw StateError('no chassis frame outline in the rack scene');
  }
  return strokes.first;
}
