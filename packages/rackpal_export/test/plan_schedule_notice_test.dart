// PLAN-H/5: the device schedule's OMISSION notice, end to end (docs/15
// section 8, DR-152 section 11.151.4).
//
// =====================================================================
// A NOTICE WITH NO PRODUCTION READER IS THE FAILURE THIS DIRECTORY
// ALREADY MET ONCE
// =====================================================================
// `scale_notice_test.dart` exists because `DrawingScale.isToScale` shipped
// with nothing reading it, so a sheet that had left the standard-ratio
// path reached the user as an ordinary "Exported 3 sheets". The band's
// `omitted` count is the same shape of fact and reaches the user through
// the same channel, so it is asserted through the REAL entry point with
// the REAL font rather than at the layout layer, where
// `rackpal_core/test/sheet/plan_schedule_test.dart` already pins it.
//
// CR-023/G3 is the other half: a notice, NEVER a gate. Both cases assert
// the bytes were written.
//
// THE CAP IS EIGHTY AND THE CONTROL IS SIXTY, which is DR-037 section
// 11.36.1's rough-in. A test that only ever ran the overflow would pass
// against a build that noticed every plan.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');
const String _member = 'underlays/level-1.png';
const Uuid _underlayId = Uuid('ul-1');
const Uuid _roomId = Uuid('loc-1');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

/// A 2x2 opaque PNG. The image is not the subject here: the sheet only
/// has to resolve one, since an unresolvable underlay throws (docs/15
/// section 7).
Uint8List _png() {
  final image = im.Image(width: 2, height: 2, numChannels: 4)
    ..setPixelRgba(0, 0, 255, 255, 255, 255)
    ..setPixelRgba(1, 0, 0, 0, 0, 255)
    ..setPixelRgba(0, 1, 128, 128, 128, 255)
    ..setPixelRgba(1, 1, 255, 255, 255, 255);
  return Uint8List.fromList(im.encodePng(image));
}

/// A project whose only plan carries [drops] pinned outlets, each with a
/// designator of its own so each earns a callout and a row.
RackDocument _fixture(int drops) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
  );

  doc.underlays[_underlayId] = PlanUnderlay(
    id: _underlayId,
    name: 'Level 1',
    imageMember: _member,
    format: PlanImageFormat.png,
    pixelWidth: 2,
    pixelHeight: 2,
    contentHash: 'sha256:ul',
    order: const FracIndex('a0'),
    meta: _meta(),
  );

  doc.locations[_roomId] = Location(
    id: _roomId,
    kind: LocationKind.room,
    name: 'Great Room',
    code: 'GR',
    order: const FracIndex('a0'),
    meta: _meta(),
  );

  doc.racks[const Uuid('rk-1')] = Rack(
    id: const Uuid('rk-1'),
    name: 'MASTER RACK',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
    locationId: _roomId,
  );

  for (var i = 0; i < drops; i++) {
    final key = 'o${i.toString().padLeft(3, '0')}';
    doc.outlets[Uuid(key)] = Outlet(
      id: Uuid(key),
      structureBodyId: const Uuid('body-1'),
      designation: 'WP-${i + 1}',
      order: FracIndex('a$i'),
      meta: _meta(),
      locationId: _roomId,
      planPin: PlanPin(underlayId: _underlayId, at: PxPt(i % 2, i % 2)),
      gangs: <Gang>[Gang()],
    );
  }
  return doc;
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
        fileName: 'plan.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
        members: <String, Uint8List>{_member: _png()},
      ),
    );
    if (result case Err(:final error)) {
      fail('the export failed: ${(error as ExportError).message}');
    }
    return (result as Ok<ExportedDocument>).value;
  }

  /// Every text run in the exported PDF, in one bag.
  List<String> textsOf(Uint8List bytes) {
    final cmap = parseToUnicodeCMap(bytes);
    return <String>[
      for (final body in operatorStreams(bytes))
        ...interpretContentStream(
          body,
          toUnicode: cmap,
        ).texts.map((t) => t.text),
    ];
  }

  test('a rough-in of sixty drops fits, and says nothing', () async {
    final out = await export(_fixture(60));
    final texts = textsOf(out.bytes);

    // THE CONTROL RUNS FIRST. An absent notice proves nothing about a
    // sheet that was never drawn, so the table is read off the page.
    expect(texts, contains(kPlanScheduleTitle));
    expect(texts, contains('WP-60'), reason: 'the last drop of the rough-in');
    expect(out.bytes, isNotEmpty);
    for (final notice in out.notices) {
      expect(notice, isNot(contains('device schedule')));
    }
  });

  test('past the cap the summary names the sheet and the count', () async {
    final out = await export(_fixture(81));

    expect(out.bytes, isNotEmpty, reason: 'a notice is not a gate (G3)');
    expect(
      out.notices,
      contains(
        predicate<String>(
          // 76 SINCE M6-G1, 80 BEFORE: the zone band (DR-215) took one row
          // from each of the four blocks. Still above the sixty drops the
          // exit criterion needs (DR-037 §11.36.1).
          (n) => n.startsWith('T1.01: ') && n.contains('shows 76 of 81 rows'),
        ),
      ),
      reason: 'Notices: ${out.notices}',
    );
  });
}
