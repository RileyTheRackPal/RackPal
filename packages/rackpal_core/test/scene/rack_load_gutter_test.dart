// The elevation's cumulative-mass gutter (docs/08 §2.2).
//
// The join that makes this trustworthy is the last group: the topmost
// cumulative reading EQUALS the rack-wide weight `computeRackRollups`
// reports on the same inputs. Without it the gutter would be a second,
// independently wrong answer to a question the chip strip already answers.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

const Uuid _rackId = Uuid('rack-1');

DeviceInstance _rail({
  required String id,
  required int ru,
  String template = 'T1',
}) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(template),
    version: 1,
    contentHash: 'h',
  ),
  designator: id.toUpperCase(),
  name: '',
  placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: Face.front),
  meta: testMeta(),
);

TemplateSnapshot _snap({
  String id = 'T1',
  Mass? weight,
  int? va,
  int? watts,
  int frontU = 1,
  int rearU = 0,
}) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'h',
  body: TemplateBody(
    manufacturer: 'M',
    model: 'X',
    displayName: 'X',
    frontU: frontU,
    rearU: rearU,
    side: rearU > 0
        ? (frontU > 0 ? OccupancySide.both : OccupancySide.rear)
        : OccupancySide.front,
    weight: weight,
    power: PowerProfile(apparentVA: va, typicalWatts: watts),
  ),
  capturedAt: DateTime.utc(2026),
);

Rack _rack({int heightU = 12, Mass? capacity}) => Rack(
  id: _rackId,
  name: 'R',
  designator: 'RK-1',
  heightU: heightU,
  order: const FracIndex('a0'),
  meta: testMeta(),
  weightCapacity: capacity,
);

/// One kilogram, exactly.
const Mass _kg = Mass(1_000_000_000);

void main() {
  group('cumulative from the bottom up', () {
    test('a device is counted at its HIGHEST U, not apportioned', () {
      // A chassis is not a distributed load: the figure a rigger reads is
      // "how much is hanging below this line".
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[_rail(id: 'a', ru: 4)],
        templates: <String, TemplateSnapshot>{
          'T1@1': _snap(weight: _kg, frontU: 3),
        },
      );

      // Occupies U4..U6, so it enters at boundary 6.
      expect(profile.readings[5].mass.value, Mass.zero);
      expect(profile.readings[6].mass.value, _kg);
      expect(profile.readings[7].mass.value, _kg);
    });

    test('readings are monotonically non-decreasing', () {
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[
          for (var ru = 1; ru <= 10; ru++) _rail(id: 'd$ru', ru: ru),
        ],
        templates: <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)},
      );

      var previous = -1;
      for (final reading in profile.readings) {
        final ug = reading.mass.value!.ug;
        expect(ug, greaterThanOrEqualTo(previous));
        previous = ug;
      }
      expect(profile.readings.first.mass.value, Mass.zero);
      expect(profile.readings.last.mass.value, const Mass(10_000_000_000));
    });

    test('there is one reading per U boundary, 0..heightU', () {
      final profile = computeRackLoadProfile(
        rack: _rack(heightU: 24),
        devices: const <DeviceInstance>[],
        templates: const <String, TemplateSnapshot>{},
      );

      expect(profile.readings, hasLength(25));
      expect(profile.readings.first.boundaryU, 0);
      expect(profile.readings.last.boundaryU, 24);
    });

    test('a device hanging past the rack top is counted AT the top, not '
        'at a boundary that does not exist', () {
      final profile = computeRackLoadProfile(
        rack: _rack(heightU: 4),
        devices: <DeviceInstance>[_rail(id: 'tall', ru: 3)],
        templates: <String, TemplateSnapshot>{
          'T1@1': _snap(weight: _kg, frontU: 6),
        },
      );

      expect(profile.readings.last.mass.value, _kg);
      expect(profile.readings.length, 5);
    });
  });

  group('devices with no vertical position', () {
    test('a 0U occupant lands in the TOP reading and is COUNTED as such', () {
      // Attributing it to the rack bottom would be a position the model
      // does not carry; dropping it would under-report the rack.
      final zero = DeviceInstance(
        id: const Uuid('pdu'),
        kind: DeviceKind.pdu,
        templateRef: const TemplateRef(
          templateId: TemplateId('T1'),
          version: 1,
          contentHash: 'h',
        ),
        designator: 'PDU-1',
        name: '',
        placement: const ZeroUPlacement(
          rackId: _rackId,
          channelId: 'c',
          offsetFromChannelStart: Len(0),
          orientation: ZeroUOrientation.vertical,
        ),
        meta: testMeta(),
      );

      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[zero],
        templates: <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)},
      );

      expect(profile.offAxisCount, 1);
      expect(profile.readings[11].mass.value, Mass.zero);
      expect(profile.readings.last.mass.value, _kg);
    });

    test('an empty rack says nothing about omissions — no cry wolf', () {
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: const <DeviceInstance>[],
        templates: const <String, TemplateSnapshot>{},
      );

      expect(profile.undrawnCount, 0);
      for (final face in Face.values) {
        expect(
          rackLoadSummaryLines(
            profile,
            UnitSystem.imperial,
            face,
          ).any((l) => l.contains('NOT DRAWN')),
          isFalse,
          reason: '$face',
        );
      }
    });
  });

  group('THE SET IS SELF-CONSISTENT: the elevation states what it omits', () {
    // ==================================================================
    // T6.30 LISTS EVERY DEVICE IN A RACK. THE ELEVATION DRAWS A SUBSET OF
    // THEM. THE DIFFERENCE USED TO BE SILENT.
    // ==================================================================
    // `whole_house` RK-1 holds 31 devices; T2.01 drew 27 and T2.02 drew
    // ZERO. The two rear PDUs and two shelf-hosted components appeared on
    // T6.30 with RACK = RK-1 and on no elevation at all, under a
    // "RACK TOTAL 378.0 lb" that included their mass. The installer builds
    // from the elevation.
    //
    // The elevation still does not draw them — a 0U occupant has no
    // elevation geometry and inventing one would be worse — but it now
    // says how many it is missing and where they are listed.

    /// The devices the scene builder actually emits, over BOTH faces.
    ///
    /// A SECOND, INDEPENDENT DERIVATION on purpose: it comes out of
    /// `buildRackScene`, which is what the sheet draws, so a count taken
    /// from the gutter's own arithmetic cannot agree with it by
    /// construction.
    Set<String> drawnIds(
      Rack rack,
      List<DeviceInstance> devices,
      Map<String, TemplateSnapshot> templates,
    ) => <String>{
      for (final face in Face.values)
        ...buildRackScene(
          rack: rack,
          devices: devices,
          templates: templates,
          face: face,
          lod: LodLevel.full,
          measurer: FakeMeasurer(),
        ).devices.map((d) => d.deviceId.v),
    };

    DeviceInstance zeroU(String id) => DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.pdu,
      templateRef: const TemplateRef(
        templateId: TemplateId('T1'),
        version: 1,
        contentHash: 'h',
      ),
      designator: id.toUpperCase(),
      name: '',
      placement: const ZeroUPlacement(
        rackId: _rackId,
        channelId: 'c',
        offsetFromChannelStart: Len(0),
        orientation: ZeroUOrientation.vertical,
      ),
      meta: testMeta(),
    );

    DeviceInstance onShelf(String id, String host) => DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('T1'),
        version: 1,
        contentHash: 'h',
      ),
      designator: id.toUpperCase(),
      name: '',
      placement: ShelfPlacement(
        hostDeviceId: Uuid(host),
        order: const FracIndex('a0'),
      ),
      meta: testMeta(),
    );

    test('undrawnCount is exactly what buildRackScene leaves out', () {
      final rack = _rack();
      final devices = <DeviceInstance>[
        _rail(id: 'shelf', ru: 4),
        onShelf('ontop', 'shelf'),
        zeroU('pdu'),
        // Rail-placed, template absent — a stated RU with an unknowable
        // height, so no elevation can place it.
        _rail(id: 'ghost', ru: 8, template: 'MISSING'),
      ];
      final templates = <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)};

      final profile = computeRackLoadProfile(
        rack: rack,
        devices: devices,
        templates: templates,
      );
      final drawn = drawnIds(rack, devices, templates);

      expect(drawn, <String>{'shelf'});
      expect(profile.contributingCount, 4);
      expect(
        profile.undrawnCount,
        devices.length - drawn.length,
        reason: 'the stated omission count must BE the omission',
      );
      expect(profile.undrawnCount, 3);
    });

    test('the summary states the count and where those rows are', () {
      final rack = _rack();
      final devices = <DeviceInstance>[_rail(id: 'a', ru: 1), zeroU('pdu')];

      final lines = rackLoadSummaryLines(
        computeRackLoadProfile(
          rack: rack,
          devices: devices,
          templates: <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)},
        ),
        UnitSystem.imperial,
        Face.front,
      );
      final omission = lines.singleWhere((l) => l.startsWith('NOT DRAWN'));

      expect(omission, contains('1 OF 2'));
      expect(
        omission,
        contains(kUndrawnListedOnSheet),
        reason: 'a count without a cross-reference is a hole, not a pointer',
      );
    });

    // ==================================================================
    // THE NUMBER IN THE SENTENCE IS THE undrawn COUNT, AND ONLY A FIXTURE
    // THAT SEPARATES IT FROM offAxisCount CAN SAY SO
    // ==================================================================
    // Substituting `offAxisCount` for the undrawn count in the omission
    // sentence used to survive `dart test` in both packages, because the
    // one test that read the sentence used a 1-rail + 1-zeroU fixture
    // where the two are equal. A SHELF-HOSTED device separates them: it
    // inherits its host's vertical position (so it is NOT off-axis) and
    // has no elevation geometry of its own (so it IS undrawn).
    //
    // A REAR-ONLY device separates the third pair: `undrawnCount` ("on
    // NEITHER elevation") from `undrawnOn(front)` ("not on this one").
    // Without it those two are equal in every fixture and substituting one
    // for the other survives — which turns the front sheet's "1 ON REAR"
    // back into a bare "SEE T6.30", i.e. into crying wolf.
    //
    // Every count the sentence can carry is therefore distinct here:
    //   contributing 6, undrawn(front) 4, undrawn(rear) 5, nowhere 3,
    //   offAxis 2.
    group('the sentence carries the RIGHT count, not a neighbouring one', () {
      final rack = _rack();
      final devices = <DeviceInstance>[
        // Front-only, drawn on T2.01 and not on T2.02.
        _rail(id: 'ok', ru: 2),
        // A shelf host, also front-only.
        _rail(id: 'shf', ru: 5),
        // On the shelf: a position, no elevation geometry → undrawn, NOT
        // off-axis. This is the row that separates the two counts.
        onShelf('stb', 'shf'),
        // No vertical position at all → undrawn AND off-axis.
        zeroU('pdu'),
        // A stated RU with an unknowable height → undrawn AND off-axis.
        _rail(id: 'ghost', ru: 11, template: 'MISSING'),
        // A rear lacing bar: `{frontU: 0, rearU: 1}` on the FRONT rails.
        // Drawn on T2.02 only — and it HAS a knowable position, which is
        // why it must not be counted at the top.
        _rail(id: 'lace', ru: 9, template: 'REAR'),
      ];
      final templates = <String, TemplateSnapshot>{
        'T1@1': _snap(weight: _kg),
        'REAR@1': _snap(id: 'REAR', weight: _kg, frontU: 0, rearU: 1),
      };
      final profile = computeRackLoadProfile(
        rack: rack,
        devices: devices,
        templates: templates,
      );

      test('the fixture really does separate every count', () {
        expect(profile.contributingCount, 6);
        expect(profile.undrawnCount, 3);
        expect(profile.offAxisCount, 2);
        expect(profile.undrawnOn(Face.front), 4);
        expect(profile.undrawnOn(Face.rear), 5);
        // The mutations this fixture exists to kill are only killable
        // while these are pairwise different.
        expect(profile.undrawnCount, isNot(profile.offAxisCount));
        expect(profile.undrawnCount, isNot(profile.undrawnOn(Face.front)));
        expect(profile.undrawnCount, isNot(profile.undrawnOn(Face.rear)));
        expect(
          profile.undrawnOn(Face.front),
          isNot(profile.undrawnOn(Face.rear)),
        );
      });

      test('a rear-only device has a POSITION, so it is not counted at '
          'the top', () {
        // `{frontU: 0, rearU: 1}` on the front rails: asking its MOUNT
        // face for a height gives zero and would call the position
        // unknowable, while T2.02 draws it at U9. The gutter reads the
        // stack height instead.
        final below = profile.readings[8].mass.value!;
        final at = profile.readings[9].mass.value!;
        expect(at.ug - below.ug, _kg.ug, reason: 'LACE enters at U9');
      });

      test('NOT DRAWN HERE states undrawnOn(face), never offAxisCount', () {
        for (final face in Face.values) {
          final omission = rackLoadSummaryLines(
            profile,
            UnitSystem.imperial,
            face,
          ).singleWhere((l) => l.startsWith('NOT DRAWN'));
          expect(
            omission,
            startsWith(
              'NOT DRAWN HERE  ${profile.undrawnOn(face)} OF '
              '${profile.contributingCount} ',
            ),
            reason:
                '$face: the leading count is what the reader checks '
                'against the blocks in front of them',
          );
        }
      });

      test('the count is exactly what buildRackScene leaves out, per face', () {
        // A SECOND, INDEPENDENT DERIVATION: it comes out of the scene the
        // sheet actually draws, so the gutter's arithmetic cannot agree
        // with it by construction.
        for (final face in Face.values) {
          final drawn = buildRackScene(
            rack: rack,
            devices: devices,
            templates: templates,
            face: face,
            lod: LodLevel.full,
            measurer: FakeMeasurer(),
          ).devices.length;
          expect(
            profile.undrawnOn(face),
            profile.contributingCount - drawn,
            reason: '$face: the stated omission must BE the omission',
          );
        }
      });

      test('the sentence names where the missing ones ARE', () {
        // Front: 4 missing — 1 of them on T2.02, 3 on no elevation at all.
        expect(
          rackLoadSummaryLines(
            profile,
            UnitSystem.imperial,
            Face.front,
          ).singleWhere((l) => l.startsWith('NOT DRAWN')),
          'NOT DRAWN HERE  4 OF 6 — 1 ON REAR, 3 ONLY ON T6.30; '
          '2 COUNTED AT TOP',
        );
        // Rear: 5 missing, 2 of which the FRONT elevation draws — saying
        // only "5 not drawn" would send a reader hunting for rows that
        // are one sheet away.
        expect(
          rackLoadSummaryLines(
            profile,
            UnitSystem.imperial,
            Face.rear,
          ).singleWhere((l) => l.startsWith('NOT DRAWN')),
          'NOT DRAWN HERE  5 OF 6 — 2 ON FRONT, 3 ONLY ON T6.30; '
          '2 COUNTED AT TOP',
        );
      });
    });

    test('a rack whose every device is drawn carries NO omission line', () {
      // Drawn on BOTH faces: `{frontU: 1, rearU: 1, side: both}`, which is
      // what a real 1U chassis is. A front-only device would legitimately
      // raise an omission line on the REAR sheet.
      final lines = <Face, List<String>>{
        for (final face in Face.values)
          face: rackLoadSummaryLines(
            computeRackLoadProfile(
              rack: _rack(),
              devices: <DeviceInstance>[_rail(id: 'a', ru: 1)],
              templates: <String, TemplateSnapshot>{
                'T1@1': _snap(weight: _kg, rearU: 1),
              },
            ),
            UnitSystem.imperial,
            face,
          ),
      };

      for (final face in Face.values) {
        expect(
          lines[face]!.any((l) => l.startsWith('NOT DRAWN')),
          isFalse,
          reason: '$face',
        );
      }
    });

    test('the summary never exceeds the five lines the note band holds', () {
      // `elevation_sheet.dart` sizes its band at kElevationHeaderBand =
      // 56 pt — five 8 pt lines on a 10 pt lead. A sixth prints over the
      // top of the elevation. EVERY face, because the omission line is
      // now per-face and the rear one is the longer of the two.
      final devices = <DeviceInstance>[
        _rail(id: 'a', ru: 1),
        zeroU('pdu'),
        _rail(id: 'ghost', ru: 8, template: 'MISSING'),
      ];
      for (final face in Face.values) {
        final lines = rackLoadSummaryLines(
          computeRackLoadProfile(
            rack: _rack(capacity: const Mass(90_000_000_000)),
            devices: devices,
            templates: <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)},
          ),
          UnitSystem.imperial,
          face,
        );

        expect(lines, hasLength(5), reason: '$face');
        for (final line in lines) {
          // A CHARACTER PROXY, and it is only a proxy: the real budget is
          // `area.width / 2 - 8` = 337 pt of Jost at 8 pt, which needs the
          // embedded font. `rackpal_export`'s
          // `elevation_omission_line_test.dart` measures it there and
          // asserts nothing reaches the sheet ellipsised.
          expect(line.length, lessThanOrEqualTo(80), reason: line);
        }
      }
    });

    test('the elevation NEVER claims an undrawn rail device has no RU', () {
      // The sentence this replaced said "n DEVICES WITH NO RU". A rail
      // device whose template does not resolve HAS an ruIndex — T6.30
      // prints `— · 8` for it — so the two sheets of one set contradicted
      // each other about where a device is.
      final devices = <DeviceInstance>[
        _rail(id: 'ghost', ru: 8, template: 'MISSING'),
      ];
      for (final face in Face.values) {
        final lines = rackLoadSummaryLines(
          computeRackLoadProfile(
            rack: _rack(),
            devices: devices,
            templates: <String, TemplateSnapshot>{'T1@1': _snap()},
          ),
          UnitSystem.imperial,
          face,
        );

        expect(lines.any((l) => l.contains('NO RU')), isFalse, reason: '$face');
      }
    });
  });

  group('unknowns are counted and shown, never guessed (G4)', () {
    test('a reading with SOME unknowns prints >= and the count', () {
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[
          _rail(id: 'known', ru: 1),
          _rail(id: 'unknown', ru: 2, template: 'T2'),
        ],
        templates: <String, TemplateSnapshot>{
          'T1@1': _snap(weight: _kg),
          'T2@1': _snap(id: 'T2'),
        },
      );

      final text = formatMassRollup(profile.totalMass, UnitSystem.imperial);
      expect(text, startsWith('≥ '));
      expect(text, contains('(1 unknown)'));
    });

    test('a reading with NO known contributor prints an em dash, never 0', () {
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[_rail(id: 'x', ru: 1)],
        templates: <String, TemplateSnapshot>{'T1@1': _snap()},
      );

      final text = formatMassRollup(profile.totalMass, UnitSystem.imperial);
      expect(text, startsWith(kGutterUnknown));
      expect(text, contains('(1 unknown)'));
      expect(text, isNot(contains('0.0')));
    });

    test('a complete reading prints a bare figure', () {
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[_rail(id: 'x', ru: 1)],
        templates: <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)},
      );

      final text = formatMassRollup(profile.totalMass, UnitSystem.imperial);
      expect(text, isNot(contains('≥')));
      expect(text, isNot(contains('unknown')));
      expect(text, endsWith('lb'));
    });

    test('units follow ProjectSettings.displayUnits (CR-097)', () {
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[_rail(id: 'x', ru: 1)],
        templates: <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)},
      );

      expect(formatMassRollup(profile.totalMass, UnitSystem.metric), '1.0 kg');
      expect(
        formatMassRollup(profile.totalMass, UnitSystem.imperial),
        '2.2 lb',
      );
    });

    test('BTU/hr is absent when typicalWatts is', () {
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[_rail(id: 'x', ru: 1)],
        templates: <String, TemplateSnapshot>{'T1@1': _snap(va: 200)},
      );

      expect(profile.apparentVA.value, 200);
      expect(profile.btuPerHour.value, isNull);
      expect(formatBtuRollup(profile.btuPerHour), startsWith(kGutterUnknown));
    });
  });

  group('THE JOIN: the gutter and the chip strip agree', () {
    test('the top reading EQUALS the rack-wide weight computeRackRollups '
        'reports', () {
      final rack = _rack(capacity: const Mass(90_000_000_000));
      final devices = <DeviceInstance>[
        _rail(id: 'a', ru: 1),
        _rail(id: 'b', ru: 5),
        _rail(id: 'c', ru: 9, template: 'T2'),
      ];
      final templates = <String, TemplateSnapshot>{
        'T1@1': _snap(weight: _kg, va: 100),
        'T2@1': _snap(id: 'T2'),
      };

      final profile = computeRackLoadProfile(
        rack: rack,
        devices: devices,
        templates: templates,
      );
      final rollups = computeRackRollups(
        rack: rack,
        devices: devices,
        templates: templates,
        face: Face.front,
        landings: PortLandings.none,
      );

      expect(profile.totalMass.value?.ug, rollups.weight.value?.ug);
      expect(profile.totalMass.unknownCount, rollups.weight.unknownCount);
      expect(profile.apparentVA.value, rollups.apparentVA.value);
      expect(profile.apparentVA.unknownCount, rollups.apparentVA.unknownCount);
      expect(profile.weightCapacity, rollups.weightCapacity);
    });

    test('...including when 0U and shelf occupants are in the rack', () {
      // The case the "counted at the top" rule exists for: the two scans
      // must still agree on the TOTAL even though only one of them has a
      // vertical axis.
      final shelfHost = _rail(id: 'shelf', ru: 4);
      final onShelf = DeviceInstance(
        id: const Uuid('ontop'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('T1'),
          version: 1,
          contentHash: 'h',
        ),
        designator: 'TOP-1',
        name: '',
        placement: const ShelfPlacement(
          hostDeviceId: Uuid('shelf'),
          order: FracIndex('a0'),
        ),
        meta: testMeta(),
      );
      final rack = _rack();
      final devices = <DeviceInstance>[shelfHost, onShelf];
      final templates = <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)};

      final profile = computeRackLoadProfile(
        rack: rack,
        devices: devices,
        templates: templates,
      );
      final rollups = computeRackRollups(
        rack: rack,
        devices: devices,
        templates: templates,
        face: Face.front,
        landings: PortLandings.none,
      );

      expect(profile.totalMass.value?.ug, rollups.weight.value?.ug);
      // A shelf-hosted device inherits its host's position, so it is NOT
      // off-axis.
      expect(profile.offAxisCount, 0);
    });

    test('devices in ANOTHER rack contribute to neither', () {
      final other = DeviceInstance(
        id: const Uuid('elsewhere'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('T1'),
          version: 1,
          contentHash: 'h',
        ),
        designator: 'X-1',
        name: '',
        placement: const RailPlacement(
          rackId: Uuid('rack-2'),
          ruIndex: 1,
          face: Face.front,
        ),
        meta: testMeta(),
      );

      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: <DeviceInstance>[other],
        templates: <String, TemplateSnapshot>{'T1@1': _snap(weight: _kg)},
      );

      expect(profile.totalMass.value, Mass.zero);
      expect(profile.totalMass.unknownCount, 0);
    });
  });

  group('the layer', () {
    test('draws readings only at the major boundaries the ruler uses', () {
      final profile = computeRackLoadProfile(
        rack: _rack(),
        devices: const <DeviceInstance>[],
        templates: const <String, TemplateSnapshot>{},
      );
      final layer = buildRackLoadGutterLayer(
        geo: const RackGeometry(12),
        profile: profile,
        measurer: FakeMeasurer(),
        units: UnitSystem.imperial,
      );

      // 5, 10 and the rack top (12).
      expect(layer.ops.whereType<OpText>(), hasLength(3));
    });

    test('every reading sits to the RIGHT of the rack box', () {
      final layer = buildRackLoadGutterLayer(
        geo: const RackGeometry(12),
        profile: computeRackLoadProfile(
          rack: _rack(),
          devices: const <DeviceInstance>[],
          templates: const <String, TemplateSnapshot>{},
        ),
        measurer: FakeMeasurer(),
        units: UnitSystem.imperial,
      );

      for (final op in layer.ops.whereType<OpText>()) {
        expect(op.at.x, greaterThan(const RackGeometry(12).rackWidth));
      }
    });

    test('the summary carries a capacity line only when one is known', () {
      List<String> lines({Mass? capacity}) => rackLoadSummaryLines(
        computeRackLoadProfile(
          rack: _rack(capacity: capacity),
          devices: const <DeviceInstance>[],
          templates: const <String, TemplateSnapshot>{},
        ),
        UnitSystem.imperial,
        Face.front,
      );

      expect(lines().any((l) => l.startsWith('CAPACITY')), isFalse);
      expect(
        lines(
          capacity: const Mass(90_000_000_000),
        ).any((l) => l.startsWith('CAPACITY')),
        isTrue,
      );
    });
  });
}
