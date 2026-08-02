// HALF THE M1 EXIT CRITERION, over the four REAL starter projects.
//
// The criterion reads, verbatim: "...and exports a THREE-SHEET PDF whose
// elevations are DIMENSIONALLY CORRECT AGAINST A PHYSICAL TAPE MEASURE AT
// TRUE SCALE and whose EQUIPMENT LIST MATCHES THE RACK CONTENTS EXACTLY."
// `elevation_true_scale_test.dart` is the first clause. This is the second.
//
// =====================================================================
// "EXACTLY" IS A BIJECTION, AND IT IS CHECKED IN BOTH DIRECTIONS AND IN
// TWO PLACES
// =====================================================================
// A model-level assertion ("the rows I built name the devices the document
// holds") cannot see a row that was built and then LOST -- clipped by a
// column, paginated off the end of the last page, overwritten. An
// emitted-text assertion ("this designator appears in ink on a T6.30
// page") cannot see a device that was never modelled at all, because there
// is nothing to look for.
//
// So both are asserted, and the pair is what makes the claim mean
// something:
//
//   1. the multiset of designators in the built rows == the multiset of
//      designators of every device in the document;
//   2. every one of those designators appears in TEXT ACTUALLY RECOVERED
//      from a T6.30 page's content stream.
//
// The starters are the right fixture precisely because they are real files
// that the app itself opens (`apps/rackmate/assets/starters/*.rmpj`),
// authored by `tool/generate_starters.dart` and used as goldens elsewhere
// -- so a regression here is a regression a user would meet.

import 'dart:io';
import 'dart:typed_data';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_export/rackmate_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');

const List<String> _starters = <String>[
  'apartment',
  'home_theatre',
  'small_office',
  'whole_house',
];

void main() {
  late Uint8List fontBytes;

  setUpAll(() {
    fontBytes = File(
      '../../apps/rackmate/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  Uint8List starterBytes(String name) => File(
    '../../apps/rackmate/assets/starters/$name.rmpj',
  ).readAsBytesSync();

  RackDocument documentOf(String name) =>
      (const JsonDocumentCodec().read(starterBytes(name))
              as Ok<RackDocument>)
          .value;

  Future<ExportedDocument> exportOf(String name) async {
    final result = await buildExportDocument(
      ExportRequest(
        documentJson: starterBytes(name),
        fontBytes: <FontRef, Uint8List>{_font: fontBytes},
        fileName: '$name.rmpj',
        issuedAt: DateTime.utc(2026, 7, 18),
      ),
    );
    if (result case Err(:final error)) {
      fail('$name did not export: ${(error as ExportError).message}');
    }
    return (result as Ok<ExportedDocument>).value;
  }

  /// Every text run recovered from the pages whose sheet id starts `T6.3`
  /// — the equipment list and any continuation pages.
  String scheduleText(Uint8List bytes) {
    final cmap = parseToUnicodeCMap(bytes);
    final buffer = StringBuffer();
    for (final body in operatorStreams(bytes)) {
      if (!body.contains(' re ')) continue;
      final text = interpretContentStream(body, toUnicode: cmap).allText;
      if (RegExp(r'SHEET NO\.\s+T6\.3').hasMatch(text)) buffer.writeln(text);
    }
    return buffer.toString();
  }

  for (final name in _starters) {
    group('$name.rmpj', () {
      test('exports without refusing', () async {
        final exported = await exportOf(name);
        final doc = documentOf(name);

        // 2 elevations per rack, plus at least one schedule page.
        expect(
          exported.sheetCount,
          greaterThanOrEqualTo(doc.racks.length * 2 + 1),
        );
        expect(exported.bytes, isNotEmpty);
        // A PDF, not something that merely has a length.
        expect(
          String.fromCharCodes(exported.bytes.take(5)),
          '%PDF-',
        );
      });

      test('(1) THE MODEL BIJECTION: one row per device, no more and no '
          'less', () async {
        final doc = documentOf(name);
        final list = buildEquipmentList(doc);

        final modelled = doc.devices.values.map((d) => d.designator).toList()
          ..sort();
        final rows = list.rows.map((r) => r.designator).toList()..sort();

        expect(rows, modelled);
        expect(list.rowCount, doc.devices.length);
        // ...and every row belongs to exactly one group, which is the
        // property that makes the two lists comparable at all.
        expect(
          list.groups.fold<int>(0, (n, g) => n + g.rows.length),
          doc.devices.length,
        );
      });

      test('(2) EVERY designator reaches INK on a T6.30 page', () async {
        // The assertion a model-level check cannot make. A row that is
        // modelled, paginated off the end and never drawn passes (1) and
        // fails here — which is exactly why both exist.
        final doc = documentOf(name);
        final text = scheduleText((await exportOf(name)).bytes);

        expect(
          text,
          isNotEmpty,
          reason:
              'no T6.3x page was recovered at all — every assertion '
              'below would be vacuous',
        );
        for (final device in doc.devices.values) {
          expect(
            text,
            contains(device.designator),
            reason:
                '${device.designator} is in the document and not on the '
                'sheet',
          );
        }
      });

      test('(3) the per-rack subtotal EQUALS computeRackRollups', () async {
        // The schedule and the chip strip above the canvas read the same
        // devices through the same resolver (`derived/device_loads.dart`).
        // If they ever diverge, the suite goes red rather than the sheet
        // going quietly wrong.
        final doc = documentOf(name);
        final list = buildEquipmentList(doc);

        for (final rack in doc.racks.values) {
          final group = list.groups.firstWhere((g) => g.rackId == rack.id);
          final rollups = computeRackRollups(
            rack: rack,
            devices: doc.devices.values,
            templates: doc.templates,
            face: Face.front,
          );

          expect(
            group.mass.value?.ug,
            rollups.weight.value?.ug,
            reason: '${rack.designator} mass subtotal',
          );
          expect(group.mass.unknownCount, rollups.weight.unknownCount);
          expect(group.apparentVA.value, rollups.apparentVA.value);
          expect(
            group.apparentVA.unknownCount,
            rollups.apparentVA.unknownCount,
          );
        }
      });

      test('(4) unknown values are counted against the RAW MODEL, not '
          'against themselves', () {
        // ==============================================================
        // THIS ASSERTION USED TO BE ABLE TO PASS WHILE BEING WRONG, AND
        // A MUTATION PROVED IT.
        // ==============================================================
        // It compared the em-dashed cell count against
        // `Rollup.unknownCount` — two numbers that both come out of
        // `resolveDeviceLoads`. Substituting `Mass.zero` for an unknown
        // mass moves BOTH to zero, so the mutation survived the whole
        // suite: exactly the self-referential shape this project keeps
        // shipping.
        //
        // The expectation is now computed from the DOCUMENT: a device's
        // mass is unknown iff neither its override nor its template body
        // states one. Nothing on this side of the comparison goes through
        // the resolver.
        final doc = documentOf(name);
        final list = buildEquipmentList(doc);

        for (final group in list.groups) {
          var expectedMassUnknown = 0;
          var expectedVaUnknown = 0;
          for (final row in group.rows) {
            final device = doc.devices[row.deviceId]!;
            final body = doc
                .templates['${device.templateRef.templateId.v}@'
                    '${device.templateRef.version}']
                ?.body;
            if (device.overrides.weight == null && body?.weight == null) {
              expectedMassUnknown++;
            }
            if (body?.power.apparentVA == null) expectedVaUnknown++;
          }

          expect(
            group.mass.unknownCount,
            expectedMassUnknown,
            reason: '${group.title}: mass unknown count',
          );
          expect(
            group.rows.where((r) => r.loads.mass == null).length,
            expectedMassUnknown,
            reason: '${group.title}: em-dashed mass cells',
          );
          expect(
            group.apparentVA.unknownCount,
            expectedVaUnknown,
            reason: '${group.title}: VA unknown count',
          );
        }
      });

      test(
        '(5) the sheet set is 2N + schedule pages, numbered i OF n',
        () async {
          final doc = documentOf(name);
          final exported = await exportOf(name);
          final text = scheduleText(exported.bytes);

          // "SHEET i OF n" is resolved by a dry run BEFORE anything renders,
          // so `n` must be the number of pages actually in the file. A
          // running counter would be right for a one-rack, one-page project
          // and wrong here — `small_office` has two racks and `whole_house`
          // needs two schedule pages.
          expect(
            text,
            contains('OF ${exported.sheetCount}'),
            reason: 'the printed total disagrees with the pages emitted',
          );
          expect(
            exported.sheetCount,
            doc.racks.length * 2 +
                RegExp(r'SHEET NO\.\s+T6\.3').allMatches(text).length,
          );
        },
      );

      test('(6) no pricing, and the word BOM appears nowhere', () async {
        // AC-055: `Money`, `cost`, `supplier` and `purchaseOrder` do not
        // exist in v1, and this sheet is never called a BOM.
        final text = scheduleText((await exportOf(name)).bytes);

        expect(text, isNot(contains('BOM')));
        expect(text, isNot(contains(r'$')));
        expect(text.toUpperCase(), isNot(contains('PRICE')));
        expect(text.toUpperCase(), isNot(contains('COST')));
      });

      test('(7) the omitted schedules are stated on the sheet', () async {
        final text = scheduleText((await exportOf(name)).bytes);
        expect(text, contains('CABLE AND POWER SCHEDULES NOT ISSUED'));
      });

      test('(8) the SUBTOTAL DEVICE COUNT on T6.30 is the rack contents, '
          'in ink', () async {
        // ==============================================================
        // (3) ABOVE CHECKS THE SUBTOTAL'S MASS AND VA AND NEVER ITS
        // DEVICE COUNT.
        // ==============================================================
        // Mutating `_subtotalText`'s `group.rows.length` to `+ 1` survived
        // this suite AND rackmate_core's, and put T6.30 in direct
        // contradiction with both elevations about how many devices are in
        // the rack -- which is exactly what
        // `RackLoadProfile.contributingCount`'s doc says the shared
        // denominator exists to prevent.
        //
        // The expectation comes from `hostRackOf` over the DOCUMENT (the
        // predicate T6.30 and the elevations share), not from the
        // `EquipmentGroup` whose row count is the thing under test.
        final doc = documentOf(name);
        final byId = <Uuid, DeviceInstance>{
          for (final d in doc.devices.values) d.id: d,
        };
        final text = scheduleText((await exportOf(name)).bytes);

        for (final rack in doc.racks.values) {
          final expected = doc.devices.values
              .where((d) => hostRackOf(d, byId) == rack.id)
              .length;
          final match = RegExp(
            '${RegExp.escape(rack.designator)}'
            r' SUBTOTAL\s+(\d+)\s+DEVICE',
          ).firstMatch(text);

          expect(
            match,
            isNotNull,
            reason: '${rack.designator} has no subtotal band in the ink',
          );
          expect(
            int.parse(match!.group(1)!),
            expected,
            reason:
                '${rack.designator}: T6.30 and the elevations must agree '
                'on how many devices the rack holds',
          );
        }
      });
    });
  }

  group('the fixtures are what this test thinks they are', () {
    // Guards against the whole file passing because the assets moved or
    // shrank to nothing.
    test('all four starters exist and hold racks and devices', () {
      for (final name in _starters) {
        final doc = documentOf(name);
        expect(doc.racks, isNotEmpty, reason: name);
        expect(doc.devices.length, greaterThan(5), reason: name);
      }
    });

    test('the UNKNOWN path is genuinely exercised — otherwise (4) proves '
        'nothing', () {
      // (4) compares counts, and two zeroes compare equal. If no starter
      // carried an unauthored mass or an unauthored VA, the whole G4 group
      // above would be vacuously true. This is the assertion that says the
      // fixtures reach the branch.
      var massUnknown = 0;
      var vaUnknown = 0;
      for (final name in _starters) {
        for (final group in buildEquipmentList(documentOf(name)).groups) {
          massUnknown += group.mass.unknownCount;
          vaUnknown += group.apparentVA.unknownCount;
        }
      }

      expect(
        massUnknown,
        greaterThan(0),
        reason: 'no starter has a device with an unauthored mass',
      );
      expect(
        vaUnknown,
        greaterThan(0),
        reason: 'no starter has a device with an unauthored apparentVA',
      );
    });

    test('the set covers the multi-rack AND multi-schedule-page cases', () {
      // If every starter were one rack and one page, (5) above would only
      // ever exercise the case that trivially works.
      expect(
        _starters.any((n) => documentOf(n).racks.length > 1),
        isTrue,
        reason: 'no multi-rack starter — SHEET i OF n is untested for 2N+1',
      );
      expect(
        documentOf('whole_house').devices.length,
        greaterThan(40),
        reason:
            'the schedule pagination needs a document that overflows '
            'one page',
      );
    });
  });
}
