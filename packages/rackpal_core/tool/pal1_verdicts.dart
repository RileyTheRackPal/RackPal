// PAL-1's verdicts, for the Python gates that used to compute their own
// (SFE-A2, DR-122 §11.121.4).
//
//     cd packages/rackpal_core
//     dart run tool/pal1_verdicts.dart < request.json
//
// `tools/pal1_check.py` still OWNS THE DATA: its `FAMILIES` and
// `DOMAIN_HUE` are what `palette_parity.py` holds the docs to and what
// `registry_parity.py` holds the seed to. What it no longer owns is the
// ARITHMETIC. It sends its table here and prints what comes back, so the
// CI gate and the clone editor read one implementation,
// `lib/src/draw/pal1.dart`, and cannot come to disagree.
//
// REQUEST, on stdin:
//
//     {"palettes": {"<name>": {
//        "hues": {"<domain>": "#RRGGBB", ...},
//        "luminance": {"<domain>": 0.16, ...},          optional
//        "families": [["<id>", "<domain>", [6000, 3000], 1000], ...]}},
//      "contrast": [[<argb>, <argb>], ...]}                optional
//
// Dashes and weights arrive in PERMILLE, as the registry stores them, so
// nothing here parses a point value. `luminance` replaces a domain's
// computed one: `legend_cvd_check.py` asks PAL-1's question of a SIMULATED
// lightness, and this is how it asks without a second copy of the rule.
//
// RESPONSE, on stdout: per palette, the in-band cross-domain pair count
// and every violation in the gate's order; the constants the rules use,
// so a caller prints them rather than restating them; and the WCAG
// contrast ratio of each requested pair.
//
// A malformed request is an exception and a non-zero exit. The caller is a
// gate, and a gate that reads "no violations" out of a crash is the
// failure this repository has met more than once.
import 'dart:convert';
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';

Future<void> main() async {
  final request =
      jsonDecode(await utf8.decoder.bind(stdin).join()) as Map<String, dynamic>;
  final palettes = request['palettes'] as Map<String, dynamic>;
  final out = <String, Object?>{
    'constants': {
      'luminanceBand': kPal1LuminanceBand,
      'weightRatioPermille': kPal1WeightRatioPermille,
      'periodFloorPermille': kPal1PeriodFloorPermille,
    },
    'palettes': {
      for (final MapEntry(:key, :value) in palettes.entries)
        key: _verdicts(value as Map<String, dynamic>),
    },
    'contrast': [
      for (final p
          in (request['contrast'] as List? ?? const []).cast<List<dynamic>>())
        contrastRatio(p[0] as int, p[1] as int),
    ],
  };
  stdout.writeln(jsonEncode(out));
}

Map<String, Object?> _verdicts(Map<String, dynamic> palette) {
  final hues = (palette['hues'] as Map<String, dynamic>).map(
    (d, h) => MapEntry(d, Rgb.fromHex(h as String)),
  );
  final seen = (palette['luminance'] as Map<String, dynamic>? ?? const {}).map(
    (d, l) => MapEntry(d, (l as num).toDouble()),
  );
  final entries = [
    for (final f in (palette['families'] as List).cast<List<dynamic>>())
      Pal1Entry(
        familyId: SignalFamilyId(f[0] as String),
        domainId: SignalDomainId(f[1] as String),
        hue: hues[f[1]]!,
        luminance: seen[f[1]],
        dashPermille: (f[2] as List).cast<int>(),
        weightPermille: f[3] as int,
      ),
  ];
  var inBand = 0;
  for (var i = 0; i < entries.length; i++) {
    for (var j = i + 1; j < entries.length; j++) {
      if (entries[i].domainId == entries[j].domainId) continue;
      if (pal1Pair(entries[i], entries[j]).inBand) inBand++;
    }
  }
  return {
    'families': entries.length,
    'inBandPairs': inBand,
    'violations': [
      for (final v in pal1Violations(entries))
        {
          'familyIds': [for (final id in v.familyIds) id.v],
          ...switch (v) {
            Pal1CrossDomainCollision(:final a, :final b) => {
              'kind': 'cross',
              'dashClass': '${a.dashClass}',
              'weightRatio': (a.weightPermille > b.weightPermille
                  ? a.weightPermille / b.weightPermille
                  : b.weightPermille / a.weightPermille),
              'deltaL': (a.luminance - b.luminance).abs(),
            },
            Pal1WithinDomainDuplicate() => {'kind': 'within'},
            Pal1PeriodBelowFloor(:final entry) => {
              'kind': 'period',
              'periodPermille': entry.periodPermille,
            },
          },
        },
    ],
  };
}
