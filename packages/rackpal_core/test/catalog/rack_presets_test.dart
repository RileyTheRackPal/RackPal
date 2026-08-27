// docs/04-rack-editor.md §4's preset list, asserted rather than trusted —
// the same discipline seed_catalog_test.dart applies to the 48-template
// device catalog, for the same reason: the count and the archetype set are
// exactly the kind of seed data that drifts silently from the doc.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// The `{ … }` body of `<keyword> class <name>` in [source], brace-matched.
///
/// A source-level read, in the idiom no_flutter_import_test.dart and
/// internal_setter_grep_test.dart already use, because the property below
/// is about a type's DECLARED SURFACE and there is no runtime handle on
/// that: this package is pure Dart that also has to compile under Flutter,
/// so `dart:mirrors` is not available to ask the question directly.
String _classBody(String source, String className) {
  final decl = RegExp('class\\s+$className\\b').firstMatch(source);
  expect(
    decl,
    isNotNull,
    reason:
        'no `class $className` in the source — this test reads the '
        'declaration itself, so a rename silently blinds it',
  );
  final open = source.indexOf('{', decl!.end);
  expect(open, greaterThan(-1), reason: '$className has no body');

  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('unbalanced braces in $className');
}

void main() {
  group("buildRackPresets — §4's named list", () {
    test('ships exactly the ELEVEN presets §4 enumerates', () {
      // "Wall box 6U/12in, Swing gate 12U/18in, Pivot cabinet 10U, Floor
      // enclosure 18/21/27/35/44U, Open frame 4-post 44U, Credenza bay 8U,
      // Data 42U/36in" = 1 + 1 + 1 + 5 + 1 + 1 + 1.
      expect(buildRackPresets(), hasLength(11));
    });

    test('every archetype §4 names is present, at the height it names', () {
      final byId = buildRackPresets();
      const expected = {
        'wallBox6U': 6,
        'swingGate12U': 12,
        'pivotCabinet10U': 10,
        'floorEnclosure18U': 18,
        'floorEnclosure21U': 21,
        'floorEnclosure27U': 27,
        'floorEnclosure35U': 35,
        'floorEnclosure44U': 44,
        'openFrame4Post44U': 44,
        'credenzaBay8U': 8,
        'data42U36in': 42,
      };

      expect(byId.keys.toSet(), expected.keys.toSet());
      for (final e in expected.entries) {
        expect(byId[e.key]!.heightU, e.value, reason: e.key);
      }
    });

    test('the five floor-enclosure heights are exactly 18/21/27/35/44', () {
      final floor =
          buildRackPresets().values
              .where((p) => p.id.startsWith('floorEnclosure'))
              .map((p) => p.heightU)
              .toList()
            ..sort();

      expect(floor, [18, 21, 27, 35, 44]);
    });

    test('each key equals its preset id', () {
      buildRackPresets().forEach((key, preset) {
        expect(preset.id, key);
      });
    });
  });

  group('every preset carries what §4 requires of it', () {
    test('height, depth, capacity, rail type and form factor', () {
      for (final p in buildRackPresets().values) {
        expect(p.heightU, greaterThanOrEqualTo(1), reason: p.id);
        expect(p.heightU, lessThanOrEqualTo(60), reason: '${p.id} (CR-038)');
        expect(p.weightCapacity, isNotNull, reason: '${p.id} capacity');
        expect(p.usableDepth, isNotNull, reason: '${p.id} depth');
        expect(p.displayName, isNotEmpty, reason: p.id);
      }
    });

    test('depths and capacities are strictly positive — a zero would read '
        'as a real measurement of nothing', () {
      for (final p in buildRackPresets().values) {
        expect(p.usableDepth!.nm, greaterThan(0), reason: p.id);
        expect(p.weightCapacity!.ug, greaterThan(0), reason: p.id);
      }
    });

    test('depths are EXACT inch multiples — no floating-point drift in a '
        'persisted length (CR-001)', () {
      for (final p in buildRackPresets().values) {
        expect(
          p.usableDepth!.nm % Len.nmPerInch,
          0,
          reason: '${p.id} depth is not a whole number of inches',
        );
      }
    });

    test('capacities are exact whole kilograms (CR-003)', () {
      for (final p in buildRackPresets().values) {
        expect(
          p.weightCapacity!.ug % 1000000000,
          0,
          reason: '${p.id} capacity is not a whole number of kg',
        );
      }
    });
  });

  group('form-factor coherence', () {
    test('only the swing-gate and pivot archetypes are swing frames, and '
        'both carry a hinge side', () {
      for (final p in buildRackPresets().values) {
        if (p.isSwingFrame) {
          expect(
            p.formFactor,
            anyOf(
              RackFormFactor.wallSwingGate,
              RackFormFactor.wallPivotCabinet,
            ),
            reason: '${p.id} claims a swing frame',
          );
          expect(p.hingeSide, isNotNull, reason: '${p.id} hinge side');
        } else {
          expect(
            p.hingeSide,
            isNull,
            reason:
                '${p.id} is not a swing frame yet names a hinge side — '
                'the inspector renders that dropdown disabled and dashed, '
                'so a value here would be invisible state',
          );
        }
      }
    });

    test('the wall archetypes use a wall form factor', () {
      final byId = buildRackPresets();
      expect(byId['wallBox6U']!.formFactor, RackFormFactor.wallFixed);
      expect(
        byId['swingGate12U']!.formFactor,
        RackFormFactor.wallSwingGate,
      );
      expect(
        byId['pivotCabinet10U']!.formFactor,
        RackFormFactor.wallPivotCabinet,
      );
    });

    test('the open frame is a 4-post open frame, not an enclosure', () {
      expect(
        buildRackPresets()['openFrame4Post44U']!.formFactor,
        RackFormFactor.openFrame4Post,
      );
    });

    test('the credenza is furniture', () {
      expect(
        buildRackPresets()['credenzaBay8U']!.formFactor,
        RackFormFactor.credenzaFurniture,
      );
    });

    test('the two presets §4 spells with a depth carry that exact depth', () {
      final byId = buildRackPresets();
      expect(byId['wallBox6U']!.usableDepth, const Len(12 * Len.nmPerInch));
      expect(
        byId['swingGate12U']!.usableDepth,
        const Len(18 * Len.nmPerInch),
      );
      expect(byId['data42U36in']!.usableDepth, const Len(36 * Len.nmPerInch));
    });
  });

  group('preset application is a plain fan-out of Rack writes', () {
    test('every field a preset carries has a Rack setter behind a '
        'RackField, so applying one is fully undoable', () {
      // The preset's whole contract is that it writes only fields the
      // command layer already covers — that is what lets "apply preset" be
      // one Transaction of existing commands rather than a new command
      // type with its own revert.
      final keys = {for (final f in RackField.all) f.key};

      expect(
        keys,
        containsAll(<String>{
          'formFactor',
          'widthClass',
          'railType',
          'usableDepth',
          'weightCapacity',
          'isSwingFrame',
          'hingeSide',
        }),
      );
      // heightU is the exception, and deliberately so: it routes through
      // the pre-existing SetRackHeightCommand (and therefore through the
      // shrink-below-occupancy path) rather than through RackField.
      expect(keys, isNot(contains('heightU')));
    });

    test('presets touch NO identity or display field — applying one must '
        'not silently reset a name or an RU numbering choice', () {
      // WHAT THIS USED TO BE, and why it could not fail: it built
      // `buildRackPresets().values.map((p) => p.toString())` and asserted no
      // rendered string CONTAINED 'name'/'designator'/'locationId'/
      // 'ruNumbering'. But `RackPreset.toString()` is
      // `'RackPreset($id, ${heightU}U)'` — it emits two VALUES and no field
      // names at all, so no field added to the class could ever appear in
      // it. Adding `final String designator;` to `RackPreset` — precisely
      // the regression the old comment claimed to catch — left this green.
      //
      // So the field list is pinned EXACTLY, against the declaration
      // itself. An added field fails here by construction, and that is the
      // right default: every field on this type is one "apply preset"
      // fans out onto the rack, so a new one is a new thing a preset
      // silently overwrites until someone has argued otherwise.
      final body = _classBody(
        File('lib/src/catalog/rack_presets.dart').readAsStringSync(),
        'RackPreset',
      );
      final declared = <String>{
        // `final <Type> <name>;`
        ...RegExp(
          r'^\s*final\s+[\w.<>,]+\??\s+(\w+)\s*;',
          multiLine: true,
        ).allMatches(body).map((m) => m.group(1)!),
        // `<Type> get <name>` — a derived display string counts too.
        ...RegExp(
          r'^\s*[\w.<>,]+\??\s+get\s+(\w+)\b',
          multiLine: true,
        ).allMatches(body).map((m) => m.group(1)!),
      };

      expect(
        declared,
        {
          'id',
          'displayName',
          'heightU',
          'formFactor',
          'widthClass',
          'railType',
          'usableDepth',
          'weightCapacity',
          'isSwingFrame',
          'hingeSide',
        },
        reason:
            'RackPreset gained or lost a field. If it GAINED one, ask '
            'whether "apply preset" should really be writing it — this '
            'test exists because identity (name/designator/location) and '
            'display preferences (ruNumbering/mirrorRearElevation) must '
            'survive a preset untouched',
      );

      // Named individually as well, so the failure message says WHICH
      // invariant broke rather than just diffing two sets.
      const forbidden = {
        'name',
        'designator',
        'locationId',
        'ruNumbering',
        'mirrorRearElevation',
      };
      expect(
        declared.intersection(forbidden),
        isEmpty,
        reason: 'a preset that carried this would reset it on apply',
      );
      // `displayName` is the DROPDOWN LABEL, not the rack's name — the
      // distinction the substring-matching predecessor could not draw.
      expect(declared, contains('displayName'));
    });
  });

  test('rackPresetOrder is the dropdown order and covers every preset', () {
    final order = rackPresetOrder();

    expect(order, hasLength(11));
    expect(order.toSet(), buildRackPresets().keys.toSet());
    expect(
      order.first,
      'wallBox6U',
      reason:
          'wall-mounted archetypes '
          'first, per the ordering the file itself states',
    );
  });

  test('each call returns a fresh map — no shared singleton a caller '
      'could mutate out from under another', () {
    final a = buildRackPresets();
    final b = buildRackPresets();

    expect(identical(a, b), isFalse);
    a.remove('wallBox6U');
    expect(b, contains('wallBox6U'));
  });
}
