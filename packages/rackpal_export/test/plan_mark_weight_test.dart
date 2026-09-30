// `#905`, DR-169 §11.168.11: a plan mark's line weight ON PAPER, read off
// the PDF the real backend writes.
//
// ═══════════════════════════════════════════════════════════════════════
// ASSERTED ON THE CONTENT STREAM, BECAUSE THE FLOOR LIVES IN THE BACKEND
// ═══════════════════════════════════════════════════════════════════════
// The defect was a stroke in scene units that rode the fit. Measured off
// the sheet's ops, a drop and a device printed at 2.52 and 4.41 points on a
// 600x450 scan and at 0.50 and 0.50 on a 6600x5100 one, where BOTH reached
// the 0.5-point floor and a device printed exactly like a drop. That floor
// is `PdfDiagramCanvas`'s, so a core test reading `widthPt` off an op would
// have to retype it; this reads what reached the paper instead.
//
// THE UNDERLAY IS LEFT OFF THE PAGE, deliberately. An `OpImage` needs a
// resolver and a real raster, and a mark's weight does not depend on what
// is under it. Every other op on the page is the sheet builder's own.
//
// AND A CIRCLE IS TWO PATHS. `PdfDiagramCanvas.drawCircle` fills and then
// strokes, each inside its own save and restore, and the interpreter
// records a path for either painting operator. The fill's recorded line
// width is whatever the state happened to hold, so each mark is read from
// the LAST circle recovered at its position, which is the stroke.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

void main() {
  late Uint8List fontBytes;

  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  /// The printed line width of a Network drop's circle and a Network
  /// device's circle on one `T1.01` built from a [w] by [h] underlay.
  Future<({double drop, double device})> printedWeights(int w, int h) async {
    final doc = pw.Document(compress: false);
    final fonts = <FontRef, PdfFont>{
      kSheetFont: PdfTtfFont(doc.document, ByteData.sublistView(fontBytes)),
    };
    final measurer = PdfFontMeasurer(fonts);
    final meta = EntityMeta(
      createdAt: DateTime.utc(2026, 9, 14),
      updatedAt: DateTime.utc(2026, 9, 14),
      updatedBy: 'test',
    );
    final underlay = PlanUnderlay(
      id: const Uuid('ul-1'),
      name: 'Level 1',
      imageMember: 'underlays/ul-1.png',
      format: PlanImageFormat.png,
      pixelWidth: w,
      pixelHeight: h,
      contentHash: 'sha256:ul',
      order: const FracIndex('a0'),
      meta: meta,
    );
    final rack = Rack(
      id: const Uuid('rack-1'),
      name: 'MASTER RACK',
      designator: 'RK-1',
      heightU: 42,
      order: const FracIndex('a0'),
      meta: meta,
    );
    final sheet = buildPlanSheet(
      sheet: SheetSet.forRacks(
        <Rack>[rack],
        planUnderlays: [underlay],
      ).sheets.firstWhere((s) => s.role == SheetRole.devicePlan),
      underlay: underlay,
      pins: [
        // The drop on the left and the device on the right, so the two are
        // told apart by position rather than by the property under test.
        PlanPinSubject(
          entityId: const Uuid('drop'),
          at: PxPt(w ~/ 4, h ~/ 2),
          carrier: PlanPinCarrier.outlet,
          domain: const SignalDomainId('net'),
        ),
        PlanPinSubject(
          entityId: const Uuid('device'),
          at: PxPt(3 * w ~/ 4, h ~/ 2),
          carrier: PlanPinCarrier.device,
          domain: const SignalDomainId('net'),
        ),
      ],
      domains: buildSeedRegistries().signalDomains,
      info: ProjectInfo(),
      settings: ProjectSettings(),
      revisions: const <RevisionEntry>[],
      fileName: 'weights.rmpj',
      issuedAt: DateTime.utc(2026, 9, 14),
      measurer: measurer,
    );

    doc.addPage(
      buildSheetPage(
        size: SheetSize.ansiBLandscape,
        scene: DiagramScene(
          ops: [
            for (final op in sheet.scene.ops)
              if (op is! OpImage) op,
          ],
          bounds: sheet.scene.bounds,
          hits: const <HitRegion>[],
          minTextSizePt: sheet.scene.minTextSizePt,
          fragments: const <String, IntRange>{},
        ),
        fonts: fonts,
        measurer: measurer,
      ),
    );

    final recovered = interpretContentStream(
      extractOperatorStream(await doc.save(), mustContain: ' c '),
    );
    // A MARK IS A CIRCLE THE PILL'S HEIGHT ACROSS. The size is a SELECTOR
    // here and not a claim: `plan_sheet_test.dart` asserts it.
    const across = kPlanMarkPrintRadiusPt * 2;
    final circles = recovered.paths
        .where(
          (p) =>
              (p.width - p.height).abs() < 0.05 &&
              (p.width - across).abs() < 0.3,
        )
        .toList();
    final left = circles.where((p) => p.left < sheet.scene.bounds.width / 2);
    final right = circles.where((p) => p.left >= sheet.scene.bounds.width / 2);
    expect(left, isNotEmpty, reason: 'no drop recovered from $circles');
    expect(right, isNotEmpty, reason: 'no device recovered from $circles');
    return (drop: left.last.lineWidthPt, device: right.last.lineWidthPt);
  }

  group('a plan mark prints at one weight on every scan (`#905`)', () {
    /// LOAD-BEARING, AND IT IS THE EXIT CRITERION.
    ///
    /// The large scan is the one that collapsed: both weights reached the
    /// floor and a device printed like a drop. The small scan is the one
    /// that bloated. Each has to come out the same as the other.
    test('a drop and a device print at the same weights on a 600x450 scan '
        'and a 6600x5100 one', () async {
      final small = await printedWeights(600, 450);
      final large = await printedWeights(6600, 5100);

      expect(large.drop, closeTo(small.drop, 1e-3));
      expect(large.device, closeTo(small.device, 1e-3));
    });

    /// LOAD-BEARING. The distinction the ring exists to carry (`#901`)
    /// survives the scan that used to erase it.
    test('a device prints heavier than a drop on the scan that used to '
        'print them alike', () async {
      final large = await printedWeights(6600, 5100);

      expect(
        large.device / large.drop,
        greaterThanOrEqualTo(1.4),
        reason:
            "PAL-1's own separation ratio, the weakest a reader can be "
            'relied on to see; measured at 0.50 and 0.50 before `#905`',
      );
    });
  });
}
