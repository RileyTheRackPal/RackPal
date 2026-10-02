// An AUTO sheet that is absent is absent from the file AND the index
// (M6-A4 `#315`, docs/08 §2.2, DR-212).
//
// ═══════════════════════════════════════════════════════════════════════
// THE TICKET NAMES A SHEET THAT DOES NOT EXIST YET, SO THIS TESTS THE CLASS
// ═══════════════════════════════════════════════════════════════════════
// `#315` reads: "export a project with no unused home runs and assert T6.20
// appears in neither the file nor the index". T6.20 was M6-E and not a
// `SheetRole` when this was written, so that literal assertion would have
// passed over a sheet that could not be emitted at all, which proves
// nothing. Two things were asserted instead, and together they catch the
// whole class the ticket names:
//
//  1. ON REAL PDFs, THE INDEX AND THE PAGES ARE THE SAME SET. Every page's
//     `SHEET NO.` is in the cover's index, and the index names no id that
//     is not a page. Run over every starter, so the day T6.20, T5.01 or
//     T6.50 lands as AUTO, an index that lists it without emitting it (or
//     the reverse) fails here with no new test written.
//  2. THE AUTO SHEET THAT EXISTS TODAY, `T1.01`, absent and present: a
//     floorplan with nothing pinned to it emits no plan page and no index
//     row, and one pin brings both back. The control is the point: a
//     fixture that never produced a `T1` page would pass part 1 vacuously.
//  3. T6.20, NOW THAT IT EXISTS (M6-E3 `#334`, DR-220), the ticket's own
//     assertion and its control: Whole House prints it and indexes it, and
//     the same project with its open ends landed does neither.
//  4. T5.01 (M6-E3 `#334`, DR-221): Home Theatre prints and indexes it for
//     its receiver ports; Apartment, with nothing non-standard, does
//     neither; and Home Theatre with every receiver variant cleared does
//     neither, the control.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');
const String _member = 'underlays/main-floor.png';
const Uuid _underlayId = Uuid('0190f315-0000-7000-8000-0000000000a1');

final RegExp _sheetNo = RegExp(r'SHEET NO\.\s+(T\d\.\d+)');

void main() {
  late Uint8List fontBytes;
  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  RackDocument starter(String name) =>
      (const JsonDocumentCodec().read(
                File(
                  '../../apps/rackpal/assets/starters/$name.rppj',
                ).readAsBytesSync(),
              )
              as Ok<RackDocument>)
          .value;

  /// A 2x2 PNG: the plan sheet only has to resolve an image.
  Uint8List png() {
    final image = im.Image(width: 2, height: 2, numChannels: 4)
      ..setPixelRgba(0, 0, 255, 255, 255, 255)
      ..setPixelRgba(1, 1, 0, 0, 0, 255);
    return Uint8List.fromList(im.encodePng(image));
  }

  Future<Uint8List> export(
    RackDocument doc, {
    Map<String, Uint8List> members = const <String, Uint8List>{},
  }) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: const JsonDocumentCodec().write(doc),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: 'auto.rppj',
        issuedAt: DateTime.utc(2026, 10),
        members: members,
      ),
    );
    return (result as Ok<ExportedDocument>).value.bytes;
  }

  /// Each page's text, keyed by the `SHEET NO.` its title block prints.
  Map<String, String> pagesById(Uint8List bytes) {
    final cmap = parseToUnicodeCMap(bytes);
    return {
      for (final body in operatorStreams(bytes))
        if (_sheetNo.firstMatch(
              interpretContentStream(body, toUnicode: cmap).allText,
            )
            case final m?)
          m.group(1)!: interpretContentStream(body, toUnicode: cmap).allText,
    };
  }

  /// The sheet ids the cover's index names, read off the cover's text:
  /// every `Tn.nn` on T0.00 that is not its own title block's.
  Set<String> indexedIds(String coverText) {
    final ids = <String>{};
    for (final m in RegExp(r'T\d\.\d+(?:–T\d\.\d+)?').allMatches(coverText)) {
      final token = m.group(0)!;
      if (!token.contains('–')) {
        ids.add(token);
        continue;
      }
      // A COLLAPSED RUN, `T6.30–T6.32`: every sheet in it is a page, not
      // only its two ends. This read both ends alone until Whole House's
      // list ran to three pages at `#340`, when T6.31 went unaccounted for.
      final ends = token.split('–');
      final prefix = ends.first.substring(0, ends.first.indexOf('.') + 1);
      final from = int.parse(ends.first.split('.').last);
      final to = int.parse(ends.last.split('.').last);
      for (var n = from; n <= to; n++) {
        ids.add('$prefix${n.toString().padLeft(2, '0')}');
      }
    }
    return ids;
  }

  /// Whole House with a floorplan added, pinned or not.
  RackDocument withPlan({required bool pinned}) {
    final doc = starter('whole_house');
    doc.underlays[_underlayId] = PlanUnderlay(
      id: _underlayId,
      name: 'Main Floor',
      imageMember: _member,
      format: PlanImageFormat.png,
      pixelWidth: 2,
      pixelHeight: 2,
      contentHash: 'sha256:${'0' * 64}',
      order: const FracIndex('a0'),
      meta: EntityMeta(
        createdAt: DateTime.utc(2026, 10),
        updatedAt: DateTime.utc(2026, 10),
        updatedBy: 'test',
      ),
    );
    if (pinned) {
      final pin = SetPlanPinCommand(
        carrier: PinCarrier.rack,
        entityId: doc.racks.values.single.id,
        pin: const PlanPin(underlayId: _underlayId, at: PxPt(1, 1)),
      );
      expect(pin.apply(doc), isTrue, reason: 'precondition: the pin landed');
    }
    return doc;
  }

  group('1. THE INDEX AND THE PAGES ARE THE SAME SET, on every starter', () {
    for (final name in [
      'apartment',
      'home_theatre',
      'small_office',
      'whole_house',
    ]) {
      test(name, () async {
        final pages = pagesById(await export(starter(name)));
        expect(pages, contains('T0.00'), reason: 'the cover was emitted');
        // T0.01 is also named by the cover's own title block (`SYMBOL
        // LEGEND: SEE SHEET T0.01`) and T0.00 by its `SHEET NO.`; both are
        // pages, so neither can hide a defect in either direction.
        final indexed = indexedIds(pages['T0.00']!);
        expect(
          indexed,
          containsAll(pages.keys),
          reason: 'a page the index does not list',
        );
        expect(
          pages.keys,
          containsAll(indexed),
          reason: 'the index lists a sheet the file does not contain',
        );
      });
    }
  });

  group('2. THE AUTO PLAN SHEET, absent and present', () {
    test(
      'A FLOORPLAN WITH NOTHING PINNED emits no T1 page and no T1 row',
      () async {
        final pages = pagesById(
          await export(
            withPlan(pinned: false),
            members: <String, Uint8List>{_member: png()},
          ),
        );
        expect(pages.keys.where((id) => id.startsWith('T1.')), isEmpty);
        expect(
          indexedIds(pages['T0.00']!).where((id) => id.startsWith('T1.')),
          isEmpty,
        );
        expect(pages['T0.00'], isNot(contains('DEVICE LOCATION PLAN')));
      },
    );

    test('THE CONTROL: one pin brings back the page AND the row', () async {
      final pages = pagesById(
        await export(
          withPlan(pinned: true),
          members: <String, Uint8List>{_member: png()},
        ),
      );
      expect(pages.keys, contains('T1.01'));
      expect(indexedIds(pages['T0.00']!), contains('T1.01'));
      expect(pages['T0.00'], contains('DEVICE LOCATION PLAN'));
    });
  });

  group('3. T6.20, absent and present (M6-E3)', () {
    test(
      'WHOLE HOUSE, twelve runs open at the rack: the page AND the row',
      () async {
        final pages = pagesById(await export(starter('whole_house')));
        expect(pages.keys, contains('T6.20'));
        expect(indexedIds(pages['T0.00']!), contains('T6.20'));
        expect(pages['T0.00'], contains('UNUSED HOME RUNS'));
      },
    );

    test('THE SAME PROJECT WITH NOTHING UNUSED: no page and no row', () async {
      final doc = starter('whole_house');
      // Remove the twelve open runs rather than land them: a run with no
      // open end is what the sheet leaves out, and this is the cheapest
      // edit that leaves the project otherwise as shipped.
      doc.links.removeWhere(
        (_, l) => l.conductors.any(
          (c) => c.from is OpenEndpoint || c.to is OpenEndpoint,
        ),
      );
      expect(doc.links, isNotEmpty, reason: 'the landed runs remain');
      final pages = pagesById(await export(doc));
      expect(pages.keys.where((id) => id.startsWith('T6.2')), isEmpty);
      expect(
        indexedIds(pages['T0.00']!).where((id) => id.startsWith('T6.2')),
        isEmpty,
      );
      expect(pages['T0.00'], isNot(contains('UNUSED HOME RUNS')));
    });
  });

  group('4. T5.01, absent and present (M6-E3)', () {
    test(
      'HOME THEATRE, six powered receiver ports: the page AND the row',
      () async {
        final pages = pagesById(await export(starter('home_theatre')));
        expect(pages.keys, contains('T5.01'));
        expect(indexedIds(pages['T0.00']!), contains('T5.01'));
      },
    );

    test('APARTMENT, nothing non-standard: no page and no row', () async {
      final pages = pagesById(await export(starter('apartment')));
      expect(pages.keys.where((id) => id.startsWith('T5.')), isEmpty);
      expect(
        indexedIds(pages['T0.00']!).where((id) => id.startsWith('T5.')),
        isEmpty,
      );
    });

    test('THE CONTROL: Home Theatre with its receiver variants cleared has '
        'neither', () async {
      final doc = starter('home_theatre');
      for (final t in doc.templates.values) {
        for (final p in t.body.ports) {
          if (p.pinoutVariant == 'xantech-stereo') p.pinoutVariant = null;
        }
      }
      final pages = pagesById(await export(doc));
      expect(pages.keys.where((id) => id.startsWith('T5.')), isEmpty);
      expect(
        indexedIds(pages['T0.00']!).where((id) => id.startsWith('T5.')),
        isEmpty,
      );
    });
  });
}
