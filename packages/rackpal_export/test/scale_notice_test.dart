// THE NOTICE CHANNEL, END TO END.
//
// =====================================================================
// WHAT THIS FILE IS ABOUT
// =====================================================================
// `DrawingScale.isToScale` shipped with NO production reader anywhere in
// the repository: `ExportedDocument.notices` was populated from
// `legibility.notice` alone, so a sheet that had left the standard-ratio
// path -- or whose content ran off the drawing area -- reached the user as
// an ordinary "Exported 3 sheets", and the integrator found out on site.
//
// The assertions here run the REAL entry point (`buildExportDocument`) with
// the REAL font, because the thing under test is what the export summary
// says, and the summary is assembled in `build_document.dart`.
//
// CR-023/G3 is the other half: a notice, NEVER a gate. Every case below
// also asserts that the bytes were written.

import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');
const Uuid _rackId = Uuid('rack-1');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

/// A legal rack (`heightU` <= 60, CR-038) holding one device that occupies
/// the whole rack, whose `name` is [nameLength] characters.
///
/// Nothing here is illegal or synthetic: the device name is the only knob,
/// and it is the ordinary annotation ink that a long name produces which
/// pushes the elevation off the standard-ratio path.
RackDocument _fixture({required int heightU, required int nameLength}) {
  final rack = Rack(
    id: _rackId,
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: heightU,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  // FRONT-ONLY OCCUPANCY, and that is load-bearing for the negative
  // assertion below: an elevation draws a device exactly when the
  // occupancy struct gives it >= 1 U on THAT face (docs/04 section 2.2,
  // CR-036) -- not when the device happens to be bolted to that face's
  // rails. `rearU: 0` is what genuinely keeps this device off T2.02.
  final body = TemplateBody(
    manufacturer: 'ACME',
    model: 'MDL',
    displayName: 'Widget',
    frontU: heightU,
    side: OccupancySide.front,
  );
  return RackDocument(
    id: const Uuid('doc-1'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
    info: ProjectInfo(projectName: 'NOTICE FIXTURE'),
    racks: <Uuid, Rack>{rack.id: rack},
    devices: <Uuid, DeviceInstance>{
      const Uuid('d-1'): DeviceInstance(
        id: const Uuid('d-1'),
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
        meta: _meta(),
      ),
    },
    templates: <String, TemplateSnapshot>{
      'T1@1': TemplateSnapshot(
        templateId: const TemplateId('T1'),
        version: 1,
        contentHash: 'h',
        body: body,
        capturedAt: DateTime.utc(2026),
      ),
    },
  );
}

void main() {
  late Uint8List font;

  setUpAll(() {
    font = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  Future<ExportedDocument> export(RackDocument doc) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(doc),
        fontBytes: <FontRef, Uint8List>{_font: font},
        fileName: 'notice.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
      ),
    );
    return (result as Ok<ExportedDocument>).value;
  }

  test('an ordinary project reports no scale notice at all', () async {
    // The guard against noise. A summary that always says something is a
    // summary nobody reads, and then the one that matters is invisible too.
    final out = await export(_fixture(heightU: 42, nameLength: 12));

    expect(out.bytes, isNotEmpty);
    for (final notice in out.notices) {
      expect(notice, isNot(contains('NOT TO SCALE')));
      expect(notice, isNot(contains('past the drawing area')));
    }
  });

  test('an elevation whose content overruns its drawing area SAYS SO, and '
      'names WHICH sheet', () async {
    final out = await export(_fixture(heightU: 60, nameLength: 400));

    expect(out.bytes, isNotEmpty, reason: 'a notice is not a gate (G3)');
    expect(out.sheetCount, 3);
    expect(
      out.notices,
      contains(
        predicate<String>(
          (n) => n.startsWith('T2.01: ') && n.contains('past the drawing area'),
        ),
      ),
      reason: 'Notices: ${out.notices}',
    );

    // The REAR elevation of the same rack carries no such notice, because
    // the device's template gives it ZERO rear U and so no rear elevation
    // draws it. Without this the test would pass against an implementation
    // that notices every sheet unconditionally.
    expect(
      out.notices.where(
        (n) => n.startsWith('T2.02: ') && n.contains('past the drawing area'),
      ),
      isEmpty,
      reason: 'Notices: ${out.notices}',
    );
  });

  test('an elevation that is NOT at a standard ratio says NTS in the '
      'summary', () async {
    // Far enough past any standard ratio that the fit search lands on a
    // non-standard factor. The title block prints NTS; before this change
    // the summary was silent about it, and before the change above it could
    // print a nearby standard ratio instead.
    final out = await export(_fixture(heightU: 60, nameLength: 2000));

    expect(out.bytes, isNotEmpty);
    expect(
      out.notices,
      contains(
        predicate<String>(
          (n) =>
              n.startsWith('T2.01: ') &&
              n.contains('NOT TO SCALE') &&
              n.contains('graphic scale bar'),
        ),
      ),
      reason: 'Notices: ${out.notices}',
    );
  });

  // ====================================================================
  // AN UNLABELLED ELEVATION IS NEVER SILENT
  // ====================================================================
  // `device_layer.dart`'s first fix for "the label is taller than the
  // block" suppressed the WHOLE label branch, so a legal 58-60U rack of
  // 1U devices exported with no designator on any block -- and the export
  // summary said nothing, because `scale.notice` and `fit.notice` were
  // both null and the legibility line STRUCTURALLY cannot see a blackout
  // (a fragment that emits no text contributes `double.infinity` to
  // `minTextSizePt`, so it can only ever RAISE the reported minimum).
  group('a block too short to label reports itself', () {
    test('a 58U rack of 1U devices keeps every designator, and says '
        'nothing', () async {
      // THE CASE THAT SHIPPED. `_fitElevation` picks 1:10 at heightU >= 58
      // (57 still fits 1:8), and at 1:10 the inflated designator is 15.61
      // units against a 22-unit body -- it FITS, and only the 4-unit pads
      // did not.
      final out = await export(_manyOneU(heightU: 58, devices: 20));

      expect(out.bytes, isNotEmpty);
      final text = _elevationText(out.bytes, 'T2.01');
      for (var i = 0; i < 20; i++) {
        expect(text, contains('SW-$i'), reason: 'Notices: ${out.notices}');
      }
      expect(
        out.notices.where((n) => n.contains('unlabelled')),
        isEmpty,
        reason: 'nothing was dropped, so nothing may be reported',
      );
      expect(text, isNot(contains('TOO SHORT TO LABEL')));
    });

    test('...and when a block genuinely cannot hold its label, the sheet '
        'AND the summary both say so', () async {
      // A 40U device with a long enough name drives the fit search down to
      // 1:32, where the inflated designator is 24.97 units and a 1U body
      // is 22. The tall block keeps its label; the short one cannot, and
      // that is a fact about the sheet, not a detail of the renderer.
      final out = await export(_mixedHeights(nameLength: 400));

      expect(out.bytes, isNotEmpty, reason: 'a notice is not a gate (G3)');
      expect(
        out.notices,
        contains(
          predicate<String>(
            (n) => n.startsWith('T2.01: ') && n.contains('unlabelled'),
          ),
        ),
        reason: 'Notices: ${out.notices}',
      );
      final text = _elevationText(out.bytes, 'T2.01');
      // ON THE SHEET as well as in the summary: the summary is seen once
      // by whoever pressed Export, and the sheet is what reaches site.
      expect(text, contains('BLOCKS TOO SHORT TO LABEL AT THIS SCALE'));
      // The tall block is still named, so the degradation is graceful
      // rather than total.
      expect(text, contains('TALL'));
      expect(text, isNot(contains('SW-1')));
    });
  });
}

/// Every text run recovered from the page whose sheet id is [ncsId].
String _elevationText(Uint8List bytes, String ncsId) {
  final cmap = parseToUnicodeCMap(bytes);
  for (final body in operatorStreams(bytes)) {
    final text = interpretContentStream(body, toUnicode: cmap).allText;
    if (RegExp('SHEET NO\\.\\s+${RegExp.escape(ncsId)}').hasMatch(text)) {
      return text;
    }
  }
  fail('no $ncsId page was recovered');
}

TemplateSnapshot _snap(String id, int u) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'h',
  body: TemplateBody(
    manufacturer: 'ACME',
    model: 'MDL',
    displayName: 'Widget',
    frontU: u,
    side: OccupancySide.front,
  ),
  capturedAt: DateTime.utc(2026),
);

DeviceInstance _dev(String id, String template, int ru, String name) =>
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
      placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: Face.front),
      meta: _meta(),
    );

RackDocument _docOf(
  int heightU,
  Map<String, TemplateSnapshot> templates,
  List<DeviceInstance> devices,
) => RackDocument(
  id: const Uuid('doc-1'),
  appVersion: 'test',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: _meta(),
  info: ProjectInfo(projectName: 'LABEL FIXTURE'),
  racks: <Uuid, Rack>{
    _rackId: Rack(
      id: _rackId,
      name: 'MASTER RACK',
      designator: 'RK-1',
      heightU: heightU,
      order: const FracIndex('a0'),
      meta: _meta(),
    ),
  },
  devices: <Uuid, DeviceInstance>{for (final d in devices) d.id: d},
  templates: templates,
);

/// A legal tall rack (CR-038: heightU <= 60) holding 1 U devices.
RackDocument _manyOneU({required int heightU, required int devices}) => _docOf(
  heightU,
  <String, TemplateSnapshot>{'ONEU@1': _snap('ONEU', 1)},
  <DeviceInstance>[
    for (var i = 0; i < devices; i++) _dev('sw-$i', 'ONEU', i + 1, 'Switch'),
  ],
);

/// One 40 U block whose name is [nameLength] characters — enough
/// annotation ink to drive the fit search past 1:16 — plus one 1 U block
/// that cannot hold a label there.
RackDocument _mixedHeights({required int nameLength}) => _docOf(
  60,
  <String, TemplateSnapshot>{
    'BIG@1': _snap('BIG', 40),
    'ONEU@1': _snap('ONEU', 1),
  },
  <DeviceInstance>[
    _dev('tall', 'BIG', 1, 'W' * nameLength),
    _dev('sw-1', 'ONEU', 55, 'x'),
  ],
);
