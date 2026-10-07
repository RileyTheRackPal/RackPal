// DR-240 (`#1018`): the ground bar note reaches the PRINTED elevation, whole.
//
// `#1016`'s DONE clause, read off emitted bytes: the elevation of a rack
// with Ground bar present ticked carries the note, and one without does
// not. `small_office.rppj` is that pair in one document, RK-1 ticked and
// RK-2 not, so the negative case is a real rack beside the positive one
// rather than a fixture built to be empty.
//
// And the fullest rear sheet, six notes, through the REAL font: the core
// test's `FakeMeasurer` passes any length, and `_band` cuts a note that
// does not fit with an ellipsis, which is how DR-239's first envelope line
// would have lost its last word.
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');
const Uuid _rackId = Uuid('rack-1');
final _when = DateTime.utc(2026, 10, 6);

Len _mm(int mm) => Len(mm * 1000000);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

Uint8List _fontBytes() =>
    File('../../apps/rackpal/assets/fonts/Jost-Regular.ttf').readAsBytesSync();

/// Every elevation page's text runs, keyed by its sheet id.
Map<String, List<String>> _elevationTexts(Uint8List bytes) {
  final cmap = parseToUnicodeCMap(bytes);
  final out = <String, List<String>>{};
  for (final body in operatorStreams(bytes)) {
    final runs = interpretContentStream(
      body,
      toUnicode: cmap,
    ).texts.map((t) => t.text).toList();
    final id = RegExp(
      r'SHEET NO\.\s+(T\d\.\d\d)',
    ).firstMatch(runs.join('\n'))?.group(1);
    if (id == null || !id.startsWith('T2.')) continue;
    out[id] = runs;
  }
  return out;
}

DeviceInstance _device(String id, String template, int ru, String name) =>
    DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(template),
        version: 1,
        contentHash: 'h',
      ),
      designator: id.toUpperCase(),
      name: name,
      placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: Face.rear),
      meta: _meta(),
    );

TemplateSnapshot _snap(String id, int u) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'h',
  body: TemplateBody(
    manufacturer: 'ACME',
    model: 'MDL',
    displayName: 'Widget',
    category: 'Video & Display',
    frontU: u,
    rearU: u,
    side: OccupancySide.both,
  ),
  capturedAt: _when,
);

void main() {
  test('SMALL OFFICE: RK-1 ticks the box and both its elevations print the '
      'note; RK-2 does not and neither of its does', () async {
    final json = File(
      '../../apps/rackpal/assets/starters/small_office.rppj',
    ).readAsBytesSync();
    final doc =
        (const JsonDocumentCodec().read(json) as Ok<RackDocument>).value;
    // The premise, read off the file rather than assumed.
    final racks = doc.racks.values.toList()
      ..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
      });
    expect(racks.map((r) => (r.designator, r.groundBarPresent)), [
      ('RK-1', true),
      ('RK-2', false),
    ]);

    final result = await buildExportDocument(
      ExportRequest(
        documentJson: json,
        fontBytes: <FontRef, Uint8List>{_font: _fontBytes()},
        fileName: 'small_office.rppj',
        issuedAt: _when,
      ),
    );
    final bytes = (result as Ok<ExportedDocument>).value.bytes;
    final pages = _elevationTexts(bytes);
    expect(pages.keys.toSet(), {'T2.01', 'T2.02', 'T2.03', 'T2.04'});

    for (final id in ['T2.01', 'T2.02']) {
      expect(
        pages[id]!.where((t) => t.contains('GROUND BAR')),
        [kGroundBarNote],
        reason: '$id is RK-1, ticked: the note, once and whole',
      );
    }
    for (final id in ['T2.03', 'T2.04']) {
      expect(
        pages[id]!.where((t) => t.contains('GROUND')),
        isEmpty,
        reason: '$id is RK-2, unticked',
      );
    }
  });

  test('the FULLEST REAR SHEET prints all six notes whole through the real '
      'font', () {
    final rack = Rack(
      id: _rackId,
      name: 'MASTER RACK',
      designator: 'RK-1',
      heightU: 60,
      order: const FracIndex('a0'),
      meta: _meta(),
      // The widest envelope DR-239's own fit test uses.
      overallWidth: _mm(1200),
      overallDepth: _mm(1400),
      overallHeight: _mm(2400),
      hasRearDoor: true,
      rearRailClearance: _mm(300),
      rearDoorClearance: _mm(1200),
      groundBarPresent: true,
    );
    final sheet = buildElevationSheet(
      sheet: SheetSet.forRacks(<Rack>[
        rack,
      ]).sheets.firstWhere((s) => s.role == SheetRole.rackElevationRear),
      rack: rack,
      devices: [
        _device('tall', 'BIG', 1, 'W' * 400),
        _device('sw-1', 'ONEU', 55, 'x'),
      ],
      templates: {'BIG@1': _snap('BIG', 40), 'ONEU@1': _snap('ONEU', 1)},
      info: ProjectInfo(projectName: 'Fit'),
      settings: ProjectSettings(displayUnits: UnitSystem.metric),
      revisions: const <RevisionEntry>[],
      fileName: 'fit.rppj',
      issuedAt: _when,
      measurer: PdfFontMeasurer.fromBytes(pw.Document().document, {
        kSheetFont: _fontBytes(),
      }),
    );
    expect(
      sheet.labels.allLabelled,
      isFalse,
      reason: 'the fixture no longer reaches the unlabelled-blocks note',
    );
    final texts = sheet.scene.ops.whereType<OpText>().map((o) => o.text);
    for (final note in [
      kRearDetailNote,
      kMirroredChip,
      kScaleAppliesNote,
      envelopeNote(rack, Face.rear, UnitSystem.metric)!,
      kGroundBarNote,
      sheet.labels.sheetNote!,
    ]) {
      expect(
        texts,
        contains(note),
        reason: 'a cut line ends in an ellipsis and loses its last words',
      );
    }
  });
}
