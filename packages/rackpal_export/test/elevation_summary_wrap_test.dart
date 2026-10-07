// DR-241 §11.240.2 (`#1022`): a load-summary line too long for its column
// wraps after its dash, measured through the REAL font.
//
// The core test proves the wrap under `FakeMeasurer`, which is 4.4 pt a
// character and agrees with Jost about nothing in particular. Whether a
// real NOT DRAWN HERE line outgrows the 319 pt column is a question about
// Jost's digits, and this file asks it: the 52-device rear sheet below
// measures past the column, so before DR-241 it reached paper as a line
// ending in an ellipsis, its last count gone.
import 'dart:io';

import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:test/test.dart';

const Uuid _rackId = Uuid('rack-1');
final _when = DateTime.utc(2026, 10, 6);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

DeviceInstance _device(String id, String template, int ru) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(template),
    version: 1,
    contentHash: 'h',
  ),
  designator: id.toUpperCase(),
  name: 'x',
  placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: Face.front),
  meta: _meta(),
);

void main() {
  test('the 52-device rear sheet prints its NOT DRAWN HERE line in two '
      'whole rows', () {
    final rack = Rack(
      id: _rackId,
      name: 'MASTER RACK',
      designator: 'RK-1',
      heightU: 45,
      order: const FracIndex('a0'),
      meta: _meta(),
      weightCapacity: const Mass(900000000000),
    );
    final measurer = PdfFontMeasurer.fromBytes(pw.Document().document, {
      kSheetFont: File(
        '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
      ).readAsBytesSync(),
    });
    const line =
        'NOT DRAWN HERE  52 OF 52 — 40 ON FRONT, 12 ONLY ON T6.30; 12 '
        'COUNTED AT TOP';
    // The premise: through the real font, this line does not fit the
    // column, so the test is about a wrap and not about a line that fits.
    final column =
        elevationAreaOf(
              SheetLayout.resolve(
                geometry: const SheetGeometry(
                  SheetSize.ansiBPortrait,
                  zoned: true,
                ),
                revisionRowCount: 1,
              ).drawingArea,
            ).width /
            2 -
        8;
    final width = measurer
        .measureText(
          line,
          const TextStyleSpec(
            font: kSheetFont,
            sizePt: kElevationNotePt,
            argb: 0xFF000000,
            anchor: TextAnchor.topRight,
          ),
        )
        .advanceWidth;
    expect(width, greaterThan(column), reason: 'the line no longer overflows');

    final sheet = buildElevationSheet(
      sheet: SheetSet.forRacks(<Rack>[
        rack,
      ]).sheets.firstWhere((s) => s.role == SheetRole.rackElevationRear),
      rack: rack,
      devices: [
        for (var i = 0; i < 40; i++) _device('sw-$i', 'FRONT', i + 1),
        for (var i = 0; i < 12; i++) _device('ghost-$i', 'MISSING', 44),
      ],
      templates: {
        'FRONT@1': TemplateSnapshot(
          templateId: const TemplateId('FRONT'),
          version: 1,
          contentHash: 'h',
          // FRONT-ONLY: `rearU` keeps its default 0 (CR-036).
          body: TemplateBody(
            manufacturer: 'ACME',
            model: 'MDL',
            displayName: 'Widget',
            frontU: 1,
            side: OccupancySide.front,
          ),
          capturedAt: _when,
        ),
      },
      info: ProjectInfo(projectName: 'Wrap'),
      settings: ProjectSettings(displayUnits: UnitSystem.metric),
      revisions: const <RevisionEntry>[],
      fileName: 'wrap.rppj',
      issuedAt: _when,
      measurer: measurer,
    );
    final texts = sheet.scene.ops.whereType<OpText>().map((o) => o.text);
    expect(texts, contains('NOT DRAWN HERE  52 OF 52 —'));
    expect(texts, contains('40 ON FRONT, 12 ONLY ON T6.30; 12 COUNTED AT TOP'));
    expect(
      texts.where((t) => t.endsWith(kEllipsis)),
      isEmpty,
      reason: 'a cut line ends in an ellipsis and loses its last count',
    );
  });
}
