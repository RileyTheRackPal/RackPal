// T0.01, the symbol legend's cable-type key (docs/08 §5.4, AC-054,
// DR-207, M6-B1 `#317` and M6-B2 `#318`).
//
// Asserted on the emitted ops, because the legend is a drawing: a row that
// is in `legendCableTypes` and not on the sheet is the defect a data-level
// test would pass.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

final Registries _seed = buildSeedRegistries();

SheetDef _legendDef() => SheetSet.forRacks(
  <Rack>[testRack()],
).sheets.firstWhere((s) => s.role == SheetRole.symbolLegend);

LegendSheet _build({Iterable<SignalFamilyId> inUse = const []}) =>
    buildLegendSheet(
      sheet: _legendDef(),
      info: fullProjectInfo(),
      settings: ProjectSettings(),
      revisions: const <RevisionEntry>[],
      fileName: 'legend.rppj',
      issuedAt: DateTime.utc(2026, 9, 30),
      measurer: FakeMeasurer(),
      registries: _seed,
      familiesInUse: inUse,
    );

void main() {
  group('the ten named types (canon §6.6, AC-054)', () {
    test('ARE TEN, and every family they name ships in the seed', () {
      expect(kRequirement4Types, hasLength(10));
      for (final type in kRequirement4Types) {
        for (final f in type.families) {
          expect(_seed.signalFamilies, contains(f), reason: '${type.name}: $f');
        }
      }
    });

    test('AGREE WITH pal1_check.py, so the legend and the PAL-1 check '
        'cannot name different families', () {
      // Read from the script itself: a second hand-typed copy of its table
      // is the drift this test exists to prevent.
      final script = File('../../tools/pal1_check.py').readAsStringSync();
      final block = RegExp(
        r'REQUIREMENT_4 = \{(.*?)\}',
        dotAll: true,
      ).firstMatch(script)!.group(1)!;
      final pairs = RegExp(
        "'([a-z0-9_.]+)': '([^']+)'",
      ).allMatches(block).map((m) => (m.group(1)!, m.group(2)!)).toList();
      expect(pairs, isNotEmpty, reason: 'the regex must find the table');
      final byFamily = {
        for (final t in kRequirement4Types)
          for (final f in t.families) f.v: t.name,
      };
      for (final (family, name) in pairs) {
        expect(byFamily[family], name, reason: family);
      }
    });
  });

  group('which rows (DR-207)', () {
    test('A SET WITH NO CABLES STILL PRINTS THE TEN', () {
      final rows = legendCableTypes(familiesInUse: const [], registries: _seed);
      expect(
        [for (final r in rows) r.name],
        [
          for (final t in kRequirement4Types) t.name,
        ],
      );
    });

    test('then each OTHER family in use gets its own row, and a named one '
        'in use adds none', () {
      final rows = legendCableTypes(
        familiesInUse: const [
          SignalFamilyId('net.fiber_sm'),
          SignalFamilyId('audio.line_unbal'),
        ],
        registries: _seed,
      );
      expect(rows, hasLength(11));
      expect(rows.last.families, [const SignalFamilyId('net.fiber_sm')]);
    });
  });

  group('THE PAIR (M6-B2): every line in colour and in greyscale', () {
    test('each family is drawn twice at its OWN dash and weight, once in '
        'its resolved hue and once in the grey of that hue', () {
      final ops = _build().scene.ops;
      final lines = ops.whereType<OpLine>().toList();
      for (final type in kRequirement4Types) {
        for (final f in type.families) {
          final style = resolveSignalStyle(family: f, registries: _seed);
          bool drawn(int argb) => lines.any(
            (l) =>
                l.s.argb == argb &&
                l.s.widthPt == style.widthPt &&
                _sameDash(l.s.dash, style.dash),
          );
          expect(drawn(style.argb), isTrue, reason: '$f in colour');
          expect(drawn(greyscaleOf(style.argb)), isTrue, reason: '$f in grey');
        }
      }
    });

    test('every named type and every family is labelled on the sheet', () {
      final texts = textsOf(_build().scene.ops);
      for (final type in kRequirement4Types) {
        expect(texts, contains(type.name));
        for (final f in type.families) {
          expect(texts, contains(_seed.signalFamilies[f]!.displayName));
        }
      }
      expect(texts, contains(kLegendHueNote.first), reason: 'the argument');
    });

    test('nothing is omitted on the ten alone', () {
      expect(_build().omittedRows, 0);
    });
  });

  group('the greyscale of a hue', () {
    test('is neutral, and keeps black and white', () {
      expect(greyscaleOf(0xFF000000), 0xFF000000);
      expect(greyscaleOf(0xFFFFFFFF), 0xFFFFFFFF);
      final g = greyscaleOf(0xFF0072B2);
      expect((g >> 16) & 0xFF, g & 0xFF);
      expect((g >> 8) & 0xFF, g & 0xFF);
    });

    test('puts Sky Blue and Orange at nearly one grey, which is WHY the '
        'dash layer is load-bearing (docs/08 §3.5)', () {
      final blue = greyscaleOf(0xFF56B4E9) & 0xFF;
      final orange = greyscaleOf(0xFFE69F00) & 0xFF;
      expect((blue - orange).abs(), lessThan(8));
    });
  });

  test(
    // SECOND SINCE M6-A: the cover opens a client deliverable, and the
    // legend is the sheet its title block points at.
    'T0.01 FOLLOWS THE COVER IN EVERY SET, and is counted in its total',
    () {
      final set = SheetSet.forRacks(<Rack>[testRack()]);
      final legend = set.sheets[1];
      expect(
        (legend.ncsId, legend.role, legend.index),
        (
          'T0.01',
          SheetRole.symbolLegend,
          2,
        ),
      );
      expect(legend.total, set.sheets.length);
    },
  );
}

bool _sameDash(List<double>? a, List<double>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
