// SFE-A1 (DR-122 §11.121.4): PAL-1's arithmetic in core, held to the
// Python it replaces.
//
// ═════════════════════════════════════════════════════════════════════
// THE FIXTURE IS THE PYTHON'S, AND IT IS NOT REGENERATED FROM HERE
// ═════════════════════════════════════════════════════════════════════
// `test/fixtures/pal1/python_verdicts.json` was PRINTED by
// `python tools/pal1_check.py --dump-verdicts` at the commit that added
// this file, while that script still carried its own copy of the rules.
// SFE-A2 then deletes those rules, so the fixture cannot be reproduced
// from a later tree, and that is the point: it is a record of what the
// gate said BEFORE the port, and a port that changed one verdict fails
// here instead of moving the printed sheet. Do not edit it to make a case
// pass.
//
// It covers three palettes. The SHIPPED one passes, so on its own it
// would only ever show the port agreeing that nothing fails. The palette
// canon §14.3 corrected, and the control dash §14.4's floor corrected,
// carry 23 cross-domain collisions, two within-domain duplicates and one
// period failure between them, so every limb is compared in both
// directions.
import 'dart:convert';
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// `solid` or `6,3,1.5,3` in points, to permille-points.
List<int> _dash(String s) => s == 'solid'
    ? const []
    : [for (final x in s.split(',')) (double.parse(x) * 1000).round()];

int _weight(num w) => (w * 1000).round();

List<Pal1Entry> _entries(List<dynamic> rows) => [
  for (final r in rows.cast<List<dynamic>>())
    Pal1Entry(
      familyId: SignalFamilyId(r[0] as String),
      domainId: SignalDomainId(r[1] as String),
      hue: Rgb.fromHex(r[2] as String),
      dashPermille: _dash(r[3] as String),
      weightPermille: _weight(r[4] as num),
    ),
];

/// A Python failure line, reduced to what both sides can state: which
/// limb, and which families, as `cross a b`. The wording is the Python's
/// and is not compared; the verdict is. A STRING rather than a record
/// holding a list, because a record compares its list by identity and
/// every case would fail on equal contents.
String _pyFailure(String line) {
  final pair = RegExp(r'^PAL-1\((a/b|within)\): (\S+) and (\S+) ');
  final period = RegExp(r'^PERIOD: (\S+) has period');
  final m = pair.firstMatch(line);
  if (m != null) {
    return '${m[1] == 'a/b' ? 'cross' : 'within'} ${m[2]} ${m[3]}';
  }
  final p = period.firstMatch(line);
  if (p != null) return 'period ${p[1]}';
  throw StateError('unrecognised Python failure: $line');
}

String _dartFailure(Pal1Violation v) => [
  switch (v) {
    Pal1CrossDomainCollision() => 'cross',
    Pal1WithinDomainDuplicate() => 'within',
    Pal1PeriodBelowFloor() => 'period',
  },
  for (final id in v.familyIds) id.v,
].join(' ');

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/pal1/python_verdicts.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('the fixture exercises every limb in its failing direction', () {
    // Without this, a fixture regenerated over a palette that happened to
    // pass everywhere would turn the differential into a test that the
    // port agrees nothing ever fails.
    final kinds = <String>{
      for (final s in fixture.values.cast<Map<String, dynamic>>())
        for (final f in (s['failures'] as List).cast<String>())
          _pyFailure(f).split(' ').first,
    };
    expect(kinds, {'cross', 'within', 'period'});
    expect(
      (fixture['shipped'] as Map<String, dynamic>)['failures'],
      isEmpty,
    );
  });

  test('the shipped scenario is the palette that actually ships', () {
    // The differential is only about the product if its "shipped" rows
    // are the seed's EFFECTIVE values. registry_parity.py holds the seed
    // to pal1_check.py's table; this holds the fixture to the seed, so a
    // stale fixture cannot certify a palette nothing draws.
    final fromFixture = {
      for (final e in _entries(
        (fixture['shipped'] as Map<String, dynamic>)['families'] as List,
      ))
        e.familyId.v:
            '${e.domainId.v} ${e.hue.toHex()} ${e.dashPermille} '
            '${e.weightPermille}',
    };
    final fromSeed = {
      for (final e in pal1EntriesOf(buildSeedRegistries()))
        e.familyId.v:
            '${e.domainId.v} ${e.hue.toHex()} ${e.dashPermille} '
            '${e.weightPermille}',
    };
    expect(fromSeed, fromFixture);
  });

  for (final MapEntry(key: name, value: raw) in fixture.entries) {
    final scenario = raw as Map<String, dynamic>;
    final entries = _entries(scenario['families'] as List);
    final byId = {for (final e in entries) e.familyId.v: e};

    group('agrees with pal1_check.py over "$name"', () {
      test('every rendered triple', () {
        final triples = scenario['triples'] as Map<String, dynamic>;
        expect(triples.keys.toSet(), byId.keys.toSet());
        for (final MapEntry(:key, :value) in triples.entries) {
          final t = value as Map<String, dynamic>;
          final e = byId[key]!;
          expect(e.luminance, closeTo(t['L'] as double, 1e-12), reason: key);
          expect('${e.dashClass}', t['class'], reason: key);
          final period = t['period'] as num?;
          expect(
            e.periodPermille,
            period == null ? isNull : (period * 1000).round(),
            reason: key,
          );
        }
      });

      test('every cross-domain pair, limb by limb', () {
        final pairs = (scenario['pairs'] as List).cast<List<dynamic>>();
        // The SET of pairs too, not only each one's answer: a port that
        // skipped some pairs would agree on every pair it looked at.
        final expectedIds = [for (final p in pairs) '${p[0]}|${p[1]}'];
        final actualIds = [
          for (var i = 0; i < entries.length; i++)
            for (var j = i + 1; j < entries.length; j++)
              if (entries[i].domainId != entries[j].domainId)
                '${entries[i].familyId.v}|${entries[j].familyId.v}',
        ];
        expect(actualIds, expectedIds);
        for (final p in pairs) {
          final v = pal1Pair(byId[p[0]]!, byId[p[1]]!);
          final where = '${p[0]} vs ${p[1]}';
          expect(v.inBand, p[2], reason: '$where: in band');
          expect(v.sameDashClass, p[3], reason: '$where: dash class');
          expect(v.weightRescues, p[4], reason: '$where: weight ratio');
          expect(v.collides, p[5], reason: '$where: collides');
        }
      });

      test('the same violations, in the same order', () {
        expect(
          pal1Violations(entries).map(_dartFailure).toList(),
          [
            for (final f in (scenario['failures'] as List).cast<String>())
              _pyFailure(f),
          ],
        );
      });
    });
  }

  group('§14.2, the worked examples', () {
    Pal1DashClass c(String s) => Pal1DashClass.of(_dash(s));

    test('each pattern takes the class the canon prints for it', () {
      expect('${c('solid')}', 'solid');
      expect('${c('2,3')}', 'dot');
      expect('${c('1.5,3')}', 'dot');
      expect('${c('6,3')}', 'short');
      expect('${c('6,3,3,3')}', 'short/short');
      expect('${c('12,4')}', 'long');
      expect('${c('1.5,3,1.5,9')}', 'dot/dot');
    });

    test('classes are compared up to rotation', () {
      expect(c('1.5,3,4,3'), c('6,3,1,3'));
      expect(c('8,3,1.5,3,1.5,3'), c('1.5,3,1.5,3,8,3'));
      expect(c('8,3,1.5,3,1.5,3'), isNot(c('8,3,1.5,3')));
    });

    test('the mark thresholds sit where §14.2 puts them', () {
      expect(pal1MarkOf(2499), Pal1Mark.dot);
      expect(pal1MarkOf(2500), Pal1Mark.short);
      expect(pal1MarkOf(8999), Pal1Mark.short);
      expect(pal1MarkOf(9000), Pal1Mark.long);
    });
  });

  test('a weight ratio of exactly 1.4 rescues, and one permille less '
      'does not', () {
    // The boundary floating point cannot be trusted on, which is why the
    // ratio is compared in integers.
    Pal1Entry at(int w, String domain) => Pal1Entry(
      familyId: SignalFamilyId('x.$domain.$w'),
      domainId: SignalDomainId(domain),
      hue: Rgb.fromHex('#808080'),
      dashPermille: const [6000, 3000],
      weightPermille: w,
    );
    expect(pal1Pair(at(1000, 'a'), at(1400, 'b')).weightRescues, isTrue);
    expect(pal1Pair(at(1000, 'a'), at(1399, 'b')).weightRescues, isFalse);
    expect(pal1Pair(at(1000, 'a'), at(1399, 'b')).collides, isTrue);
  });

  test('the shipped seed is clean through the core implementation', () {
    final entries = pal1EntriesOf(buildSeedRegistries());
    expect(entries, hasLength(57));
    expect(pal1Violations(entries), isEmpty);
  });

  test('a family whose domain does not resolve is left out, not guessed', () {
    final seed = buildSeedRegistries();
    final orphan = seed.signalFamilies.values.first;
    final r = Registries(
      signalDomains: const {},
      signalFamilies: {orphan.id: orphan},
    );
    expect(pal1EntriesOf(r), isEmpty);
  });

  test('a supplied luminance is the one PAL-1 judges, which is how the '
      'colour-blindness check asks its question', () {
    // SFE-A2. Black and white sit a whole luminance apart, so the same
    // dash at the same weight is legible; told that a deficiency leaves
    // them at one lightness, the same pair collides.
    Pal1Entry at(String domain, String hex, {double? seen}) => Pal1Entry(
      familyId: SignalFamilyId('x.$domain'),
      domainId: SignalDomainId(domain),
      hue: Rgb.fromHex(hex),
      luminance: seen,
      dashPermille: const [6000, 3000],
      weightPermille: 1000,
    );
    expect(at('a', '#000000').luminance, 0.0);
    expect(pal1Pair(at('a', '#000000'), at('b', '#FFFFFF')).collides, isFalse);
    expect(
      pal1Pair(
        at('a', '#000000', seen: 0.40),
        at('b', '#FFFFFF', seen: 0.45),
      ).collides,
      isTrue,
    );
  });
}
