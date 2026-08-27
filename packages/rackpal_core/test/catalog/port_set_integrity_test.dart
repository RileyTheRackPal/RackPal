// C9 — every `PortSetDef` a port claims membership of actually exists, and
// every `atomicConnect` set has at least two members.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS EXISTS, AND WHAT IT FOUND
// ═══════════════════════════════════════════════════════════════════════
// `docs/catalog/seed-devices.md`'s C-table names this gate and its failure
// mode: *"A half-declared stereo pair, which makes the connect gesture
// undefined."* It had never been written, and when it was, the shipped seed
// catalog failed it at a scale nobody had suspected:
//
//   48 bodies · 90 `setKey` references · 72 DANGLING
//   16 declared port sets · 7 orphaned (declared, referenced by nothing)
//   7 `atomicConnect` sets with fewer than two members
//
// The cause is one line of scope in each offender. `PortBuilder.set()`
// registers a set ONCE PER KEY, and the declarations sat OUTSIDE the
// per-instance loop while the ports inside it interpolated the instance
// number into their `setKey`. A01 declared `src` and `zone`; its ports
// asked for `src1`..`src8` and `zone1`..`zone8`. Sixteen sets were needed
// and two were declared.
//
// THE CONSEQUENCE IS THE WHOLE FEATURE. AC-053's `atomicConnect` gesture —
// one drag, one `Link`, N `Conductor`s — resolves its members by joining
// `PortDef.setKey` to `PortSetDef.key`. A dangling `setKey` joins to
// nothing, so the gesture has no set to connect and silently degrades to a
// single-conductor link. Eighty percent of the seeded set-member ports were
// in that state, including every zone output of the flagship 16-channel
// amplifier.
//
// Nothing caught it because nothing looked. The catalog tests count
// templates and check footprints; no test had ever performed the join.
//
// ═══════════════════════════════════════════════════════════════════════
// THE VACUITY GUARD IS NOT OPTIONAL
// ═══════════════════════════════════════════════════════════════════════
// Every assertion below is over a filtered subset, and a filter that stops
// matching turns this file into a test that passes by examining nothing —
// the failure mode this repository has now hit five times. So the scan
// counts are asserted first, in the same shape `no_flutter_import_test.dart`
// uses: prove the scanner found real work before believing it found no
// problems.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  group('C9: port sets are wholly declared', () {
    final catalog = buildSeedCatalog();

    test('the scan reaches real templates, real sets and real members', () {
      // FIRST, AND DELIBERATELY. Each assertion below narrows the catalog;
      // if a rename or a refactor empties one of these, every later
      // expectation becomes vacuously true and this file starts lying.
      final refs = catalog.values
          .expand((b) => b.ports)
          .where((p) => (p.setKey ?? '').isNotEmpty)
          .length;
      final sets = catalog.values.expand((b) => b.portSets).length;

      expect(
        catalog.length,
        greaterThanOrEqualTo(48),
        reason:
            'the seed catalog shrank — this gate scans whatever it is '
            'handed, so a smaller catalog silently narrows it',
      );
      expect(
        refs,
        greaterThanOrEqualTo(90),
        reason:
            'no port claims set membership any more, so every join below '
            'is over an empty set and proves nothing',
      );
      expect(
        sets,
        greaterThanOrEqualTo(16),
        reason: 'no port set is declared any more',
      );
    });

    test('every setKey a port claims resolves to a PortSetDef on the same '
        'body', () {
      final dangling = <String>[];
      for (final entry in catalog.entries) {
        final body = entry.value;
        final declared = {for (final s in body.portSets) s.key};
        for (final port in body.ports) {
          final key = port.setKey;
          if (key == null || key.isEmpty) continue;
          if (!declared.contains(key)) {
            dangling.add(
              '${entry.key}.${port.key} -> setKey "$key" '
              '(declared here: ${declared.toList()..sort()})',
            );
          }
        }
      }

      expect(
        dangling,
        isEmpty,
        reason:
            'these ports claim membership of a port set their own template '
            'does not declare. The atomicConnect gesture joins setKey to '
            'PortSetDef.key, so each of these is a set the gesture can '
            'never resolve — it degrades to a one-conductor link with no '
            'error. Usual cause: a `..set(...)` declaration left OUTSIDE '
            'the per-instance loop whose ports interpolate the instance '
            'number into setKey',
      );
    });

    test('every atomicConnect set has at least two members', () {
      final underTwo = <String>[];
      for (final entry in catalog.entries) {
        final body = entry.value;
        for (final set in body.portSets) {
          if (!set.atomicConnect) continue;
          final members = body.ports.where((p) => p.setKey == set.key).length;
          if (members < 2) {
            underTwo.add('${entry.key}.${set.key}: $members member(s)');
          }
        }
      }

      expect(
        underTwo,
        isEmpty,
        reason:
            'a one-member atomic set is the "half-declared stereo pair" C9 '
            'names: the gesture fires, produces a single conductor, and '
            'the user cannot tell it from an ordinary connect',
      );
    });

    test('every declared PortSetDef is referenced by at least one port', () {
      final orphans = <String>[];
      for (final entry in catalog.entries) {
        final body = entry.value;
        final referenced = {
          for (final p in body.ports)
            if ((p.setKey ?? '').isNotEmpty) p.setKey!,
        };
        for (final set in body.portSets) {
          if (!referenced.contains(set.key)) {
            orphans.add('${entry.key}.${set.key}');
          }
        }
      }

      expect(
        orphans,
        isEmpty,
        reason:
            'a declared set nothing points at is dead weight that also '
            'PRINTS — it reaches the device builder UI and the template '
            'snapshot. It is the other half of a dangling reference and '
            'usually the same defect seen from the other end',
      );
    });
  });
}
