// #561, DR-176 §11.175: your rack presets, the seeded ones you hide, and
// the file they live in.
import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

RackPreset _mine(String slug, {int heightU = 30}) => RackPreset(
  id: '$kUserPresetIdPrefix$slug',
  displayName: 'Mine $slug',
  heightU: heightU,
  formFactor: RackFormFactor.floorEnclosure,
  widthClass: RackWidthClass.eia19,
  railType: RailType.squareCageNut,
  usableDepth: Len.fromInches(28),
  weightCapacity: Mass.fromKilograms(300),
);

Object? _roundTrip(UserRackPresets value) =>
    jsonDecode(jsonEncode(userRackPresetsToJson(value)));

void main() {
  group('the file round-trips', () {
    test('every field a preset carries survives, in integer units', () {
      final swing = RackPreset(
        id: '${kUserPresetIdPrefix}gate',
        displayName: 'Gate 12U',
        heightU: 12,
        formFactor: RackFormFactor.wallSwingGate,
        widthClass: RackWidthClass.eia19,
        railType: RailType.tapped10_32,
        usableDepth: Len.fromInches(18),
        weightCapacity: Mass.fromKilograms(90),
        isSwingFrame: true,
        hingeSide: HingeSide.left,
      );
      final back = userRackPresetsFromJson(
        _roundTrip(
          UserRackPresets(presets: [swing], hiddenSeedIds: {'credenzaBay8U'}),
        ),
      );
      final p = back.presets.single;
      expect(p.id, swing.id);
      expect(p.displayName, 'Gate 12U');
      expect(p.heightU, 12);
      expect(p.formFactor, RackFormFactor.wallSwingGate);
      expect(p.railType, RailType.tapped10_32);
      expect(p.usableDepth, Len.fromInches(18));
      expect(p.weightCapacity, Mass.fromKilograms(90));
      expect(p.isSwingFrame, isTrue);
      expect(p.hingeSide, HingeSide.left);
      expect(back.hiddenSeedIds, {'credenzaBay8U'});
    });

    test(
      'an unknown depth or capacity is an ABSENT key, never a null (G4)',
      () {
        final json = userRackPresetsToJson(
          const UserRackPresets(
            presets: [
              RackPreset(
                id: '${kUserPresetIdPrefix}frame',
                displayName: 'Frame',
                heightU: 20,
                formFactor: RackFormFactor.openFrame2Post,
                widthClass: RackWidthClass.eia19,
                railType: RailType.tapped12_24,
              ),
            ],
          ),
        );
        final preset = (json['presets']! as List).single as Map;
        expect(preset.containsKey('usableDepthNm'), isFalse);
        expect(preset.containsKey('weightCapacityUg'), isFalse);
        expect(preset.containsKey('hingeSide'), isFalse);
      },
    );
  });

  group('reading never throws, and skips what it cannot place', () {
    test('a root that is not a map reads as empty', () {
      for (final raw in <Object?>[null, 'x', 3, <Object?>[]]) {
        final read = userRackPresetsFromJson(raw);
        expect(read.presets, isEmpty, reason: '$raw');
        expect(read.hiddenSeedIds, isEmpty, reason: '$raw');
      }
    });

    test('one unreadable preset is skipped and the rest survive', () {
      final good = userRackPresetsToJson(
        UserRackPresets(presets: [_mine('a'), _mine('b')]),
      );
      final presets = List<Object?>.of(good['presets']! as List)
        ..insert(1, <String, Object?>{'id': '${kUserPresetIdPrefix}bad'});
      final read = userRackPresetsFromJson({...good, 'presets': presets});
      expect(read.presets.map((p) => p.id), [
        '${kUserPresetIdPrefix}a',
        '${kUserPresetIdPrefix}b',
      ]);
    });

    test('a height outside 1..60 is skipped, not clamped (CR-038)', () {
      for (final height in [0, 61, -4]) {
        final json = userRackPresetsToJson(
          UserRackPresets(presets: [_mine('x')]),
        );
        ((json['presets']! as List).single as Map)['heightU'] = height;
        expect(
          userRackPresetsFromJson(jsonDecode(jsonEncode(json))).presets,
          isEmpty,
          reason: 'height $height',
        );
      }
    });

    test('an id without the user prefix is skipped, so it can never shadow '
        'a seeded preset', () {
      final json = userRackPresetsToJson(
        UserRackPresets(presets: [_mine('x')]),
      );
      ((json['presets']! as List).single as Map)['id'] = 'data42U36in';
      expect(
        userRackPresetsFromJson(jsonDecode(jsonEncode(json))).presets,
        isEmpty,
      );
    });

    test('a hidden id this build does not seed is kept for the build that '
        'does', () {
      final read = userRackPresetsFromJson(
        _roundTrip(const UserRackPresets(hiddenSeedIds: {'futurePreset9U'})),
      );
      expect(read.hiddenSeedIds, {'futurePreset9U'});
    });
  });

  group('the merged list the dropdowns read', () {
    test('seeded first in seed order, hidden ones removed, then yours in '
        'saved order', () {
      final seed = buildRackPresets();
      final merged = mergeRackPresets(
        seed,
        UserRackPresets(
          presets: [_mine('b'), _mine('a')],
          hiddenSeedIds: {'credenzaBay8U', 'wallBox6U'},
        ),
      );
      final seededKept = [
        for (final id in seed.keys)
          if (id != 'credenzaBay8U' && id != 'wallBox6U') id,
      ];
      expect(merged.keys.toList(), [
        ...seededKept,
        '${kUserPresetIdPrefix}b',
        '${kUserPresetIdPrefix}a',
      ]);
    });

    test('merging never changes the seeded list it was given', () {
      final seed = buildRackPresets();
      mergeRackPresets(
        seed,
        UserRackPresets(
          presets: [_mine('a')],
          hiddenSeedIds: {'data42U36in'},
        ),
      );
      expect(seed, hasLength(11));
      expect(seed.containsKey('data42U36in'), isTrue);
    });
  });
}
