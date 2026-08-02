// THE OTHER HALF OF THE M1 EXIT CRITERION'S "EXACTLY", ON THE ELEVATIONS.
//
// =====================================================================
// T2.02 WAS BLANK ON EVERY SHIPPED STARTER, AND SAID OTHERWISE
// =====================================================================
// Measured off the real emitted PDF for
// `apps/rackmate/assets/starters/whole_house.rmpj`: T2.01 carried 27
// device designators as ink and T2.02 carried ZERO -- 68 recovered paths,
// all frame and RU ruler. Both sheets printed the identical band, claiming
// only "NOT DRAWN 4 OF 31 DEVICES". 19 of RK-1's 27 rail devices resolve
// to templates with `rearU > 0` and `side: both`, so the MODEL said they
// occupy rear U; `_visibleDevices` dropped them on `placement.face != face`
// and the summary was face-independent, so one of the three sheets the
// exit criterion names was empty and stated a count contradicting its own
// contents.
//
// So this file asserts, against ink recovered from the emitted bytes:
//
//   1. every device the OCCUPANCY STRUCT puts on a face reaches that
//      face's sheet as a designator -- computed from the document, never
//      from the scene builder;
//   2. the omission sentence's leading count is the number of devices that
//      sheet does NOT draw, and the two elevations of one rack do not
//      print the same sentence when they draw different things;
//   3. the DRAW and HEAT lines carry their own `(n unknown)` counts, taken
//      from the authored template fields rather than from a `Rollup`;
//   4. nothing in the band reached the paper truncated -- the sentences
//      above are only true if they are whole.
//
// Every number on the expectation side is derived from the .rmpj file.
// A test that compared the sheet against `computeRackLoadProfile` would be
// comparing the gutter's arithmetic with itself.

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

/// The measured ellipsis `fitTextToWidth` appends when a line does not fit.
const String _ellipsis = '…';

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
      (const JsonDocumentCodec().read(starterBytes(name)) as Ok<RackDocument>)
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

  /// Every elevation page, keyed by its NCS id, as recovered text runs.
  Map<String, List<String>> elevationTexts(Uint8List bytes) {
    final cmap = parseToUnicodeCMap(bytes);
    final out = <String, List<String>>{};
    for (final body in operatorStreams(bytes)) {
      final stream = interpretContentStream(body, toUnicode: cmap);
      final runs = stream.texts.map((t) => t.text).toList();
      final id = RegExp(
        r'SHEET NO\.\s+(T\d\.\d\d)',
      ).firstMatch(runs.join('\n'))?.group(1);
      if (id == null || !id.startsWith('T2.')) continue;
      out[id] = runs;
    }
    return out;
  }

  /// The racks in the order `SheetSet.forRacks` puts them in, so
  /// `T2.{2i+1}` / `T2.{2i+2}` can be mapped back to a rack.
  List<Rack> orderedRacks(RackDocument doc) => doc.racks.values.toList()
    ..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
    });

  TemplateBody? bodyOf(RackDocument doc, DeviceInstance device) => doc
      .templates['${device.templateRef.templateId.v}@'
          '${device.templateRef.version}']
      ?.body;

  /// The designators the OCCUPANCY STRUCT puts on [face]'s elevation of
  /// [rack] -- read straight off the document (docs/04 section 2.2: a
  /// device renders on a face when it occupies >= 1 U there, whichever
  /// rails carry its ears).
  Set<String> shouldBeDrawn(RackDocument doc, Rack rack, Face face) => <String>{
    for (final device in doc.devices.values)
      if (device.placement case RailPlacement(rackId: final id) when id ==
          rack.id)
        if (bodyOf(doc, device) case final body?)
          if ((face == Face.front ? body.frontU : body.rearU) > 0)
            device.designator,
  };

  /// Every device that loads [rack] at all -- the denominator T6.30's
  /// subtotal and the elevation's omission sentence share.
  int contributingTo(RackDocument doc, Rack rack) {
    final byId = <Uuid, DeviceInstance>{
      for (final d in doc.devices.values) d.id: d,
    };
    return doc.devices.values
        .where((d) => hostRackOf(d, byId) == rack.id)
        .length;
  }

  for (final name in _starters) {
    group('$name.rmpj', () {
      test('every device the model puts on a face reaches THAT face as '
          'ink', () async {
        final doc = documentOf(name);
        final sheets = elevationTexts((await exportOf(name)).bytes);
        final racks = orderedRacks(doc);

        expect(
          sheets,
          hasLength(racks.length * 2),
          reason: 'the elevation pages were not recovered at all',
        );

        for (var i = 0; i < racks.length; i++) {
          for (final (offset, face) in <(int, Face)>[
            (1, Face.front),
            (2, Face.rear),
          ]) {
            final id = 'T2.${(i * 2 + offset).toString().padLeft(2, '0')}';
            final runs = sheets[id]!;
            final expected = shouldBeDrawn(doc, racks[i], face);

            for (final designator in expected) {
              expect(
                runs,
                contains(designator),
                reason:
                    '$id: $designator occupies ${face.name} U in the model '
                    'and is not on the ${face.name} elevation',
              );
            }
          }
        }
      });

      test('the omission sentence states what THIS sheet is missing',
          () async {
        final doc = documentOf(name);
        final sheets = elevationTexts((await exportOf(name)).bytes);
        final racks = orderedRacks(doc);

        for (var i = 0; i < racks.length; i++) {
          final rack = racks[i];
          final total = contributingTo(doc, rack);
          for (final (offset, face) in <(int, Face)>[
            (1, Face.front),
            (2, Face.rear),
          ]) {
            final id = 'T2.${(i * 2 + offset).toString().padLeft(2, '0')}';
            final runs = sheets[id]!;
            final missing = total - shouldBeDrawn(doc, rack, face).length;
            final omission = runs
                .where((t) => t.startsWith('NOT DRAWN'))
                .toList();

            if (missing == 0) {
              expect(omission, isEmpty, reason: '$id must not cry wolf');
              continue;
            }
            expect(omission, hasLength(1), reason: id);
            expect(
              omission.single,
              startsWith('NOT DRAWN HERE  $missing OF $total '),
              reason:
                  '$id: the stated count must be the count of blocks this '
                  'sheet does not have',
            );
            // ...and it names a PLACE for every one of them, not just a
            // hole: the opposite elevation, T6.30, or both.
            expect(
              omission.single,
              anyOf(
                contains('T6.30'),
                contains('ON FRONT'),
                contains('ON REAR'),
              ),
              reason: '$id: a count without a cross-reference is a hole',
            );
          }
        }
      });

      test('DRAW and HEAT carry the unknown counts the TEMPLATES imply',
          () async {
        final doc = documentOf(name);
        final byId = <Uuid, DeviceInstance>{
          for (final d in doc.devices.values) d.id: d,
        };
        final sheets = elevationTexts((await exportOf(name)).bytes);
        final racks = orderedRacks(doc);

        for (var i = 0; i < racks.length; i++) {
          final rack = racks[i];
          final members = doc.devices.values.where(
            (d) => hostRackOf(d, byId) == rack.id,
          );
          // Straight off the authored fields. `apparentVA` has no
          // override, and BTU/hr is `btuPerHourOverride ?? watts` and
          // NEVER derived from VA or nameplate (AC-039).
          final vaUnknown = members
              .where((d) => bodyOf(doc, d)?.power.apparentVA == null)
              .length;
          final btuUnknown = members.where((d) {
            final power = bodyOf(doc, d)?.power;
            return power?.btuPerHourOverride == null &&
                (d.overrides.typicalWatts ?? power?.typicalWatts) == null;
          }).length;

          for (final offset in <int>[1, 2]) {
            final id = 'T2.${(i * 2 + offset).toString().padLeft(2, '0')}';
            final runs = sheets[id]!;
            final draw = runs.singleWhere((t) => t.startsWith('DRAW  '));
            final heat = runs.singleWhere((t) => t.startsWith('HEAT  '));

            expect(
              draw,
              vaUnknown == 0
                  ? isNot(contains('unknown'))
                  : contains('($vaUnknown unknown)'),
              reason: '$id DRAW',
            );
            expect(
              heat,
              btuUnknown == 0
                  ? isNot(contains('unknown'))
                  : contains('($btuUnknown unknown)'),
              reason: '$id HEAT',
            );
          }
        }
      });

      test('nothing in the note band reached the paper truncated', () async {
        // Every sentence above is only true if it is whole:
        // `elevation_sheet.dart`'s `_band` gives each column
        // `area.width / 2 - 8` = 337 pt and ellipsises what does not fit.
        for (final entry in elevationTexts((await exportOf(name)).bytes)
            .entries) {
          for (final run in entry.value) {
            expect(
              run,
              isNot(contains(_ellipsis)),
              reason: '${entry.key}: "$run" was truncated on the sheet',
            );
          }
        }
      });
    });
  }

  group('the fixture reaches the case this file exists for', () {
    test('whole_house RK-1 has rail devices with REAR occupancy, and they '
        'are the majority', () async {
      // Without this the assertions above pass on a document where every
      // rail device is front-only and the rear elevation is legitimately
      // empty -- i.e. vacuously.
      final doc = documentOf('whole_house');
      final rack = orderedRacks(doc).single;
      final front = shouldBeDrawn(doc, rack, Face.front);
      final rear = shouldBeDrawn(doc, rack, Face.rear);

      expect(front, hasLength(27));
      expect(rear, hasLength(19));
      expect(rear, isNot(front));
      // ...and every one of the 19 is mounted on the FRONT rails, which is
      // precisely the case the old `placement.face != face` line dropped.
      for (final device in doc.devices.values) {
        if (!rear.contains(device.designator)) continue;
        expect(
          (device.placement as RailPlacement).face,
          Face.front,
          reason: device.designator,
        );
      }
    });

    test('...and T2.02 now carries all 19 of them', () async {
      final doc = documentOf('whole_house');
      final rack = orderedRacks(doc).single;
      final runs = elevationTexts((await exportOf('whole_house')).bytes)
          ['T2.02']!;

      for (final designator in shouldBeDrawn(doc, rack, Face.rear)) {
        expect(runs, contains(designator));
      }
      // The eight front-only ones are NOT on it — the sheet is a rear
      // elevation, not a copy of T2.01.
      final frontOnly =
          shouldBeDrawn(doc, rack, Face.front)
              .difference(shouldBeDrawn(doc, rack, Face.rear));
      expect(frontOnly, hasLength(8));
      for (final designator in frontOnly) {
        expect(runs, isNot(contains(designator)));
      }
    });

    test('the two elevations of one rack print DIFFERENT omission '
        'sentences', () async {
      // The defect, as one assertion: they drew different things and said
      // the identical thing about it.
      final sheets = elevationTexts((await exportOf('whole_house')).bytes);
      String? omission(String id) =>
          sheets[id]!.where((t) => t.startsWith('NOT DRAWN')).firstOrNull;

      expect(omission('T2.01'), isNotNull);
      expect(omission('T2.02'), isNotNull);
      expect(omission('T2.01'), isNot(omission('T2.02')));
    });
  });
}
