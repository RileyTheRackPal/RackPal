// T6.30's rollups (docs/08 §2.2, M6-F `#335`, DR-219): the sections that
// ride after MATERIALS, each built here from a derivation that already
// exists and drawn by `equipment_sheet.dart`'s section mechanism.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY NUMBER IS A DERIVATION'S, NEVER RECOMPUTED HERE
// ═══════════════════════════════════════════════════════════════════════
// The footage is `cableFootageOf`'s, which the Schedule view's takeoff
// reads too, so the sheet and the screen cannot disagree about a length.
// This file only formats: it chooses words, units and columns.
import 'package:rackpal_core/src/derived/cable_footage.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/draw/sheet/equipment_sheet.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/permille.dart';

/// The footage section's band.
const String kFootageSectionTitle = 'CABLE FOOTAGE BY MEDIA';

/// What the footage section says when no field cable is counted.
const String kNoFootageText = 'NO FIELD CABLE IN THIS PROJECT.';

/// `10%`, `12.5%`: a per-mille as a person writes a percentage.
String percentOf(Permille p) =>
    p.v % 10 == 0 ? '${p.v ~/ 10}%' : '${(p.v / 10).toStringAsFixed(1)}%';

/// `1860 ft` or `567 m`, as the Schedule view's takeoff prints it; `— ft`
/// when nothing known contributed (G4: never `0`).
String footageText(Len? value, UnitSystem units) {
  final suffix = units == UnitSystem.imperial ? 'ft' : 'm';
  if (value == null) return '$kUnknownCell $suffix';
  final divisor = units == UnitSystem.imperial
      ? Len.nmPerInch * 12
      : Len.nmPerMillimetre * 1000;
  return '${(value.nm / divisor).round()} $suffix';
}

/// AC-024's cable footage rollup by media, with the waste factor.
///
/// THERE IS NO GRAND TOTAL, on `CableFootage`'s own reasoning: feet of
/// Cat6 plus feet of RG6 is not a quantity anybody buys. What the section
/// closes with instead is what it did not count, so a takeoff smaller than
/// the schedule says why.
RollupSection footageSection(CableFootage footage, UnitSystem units) {
  final columns = <SectionColumn>[
    const SectionColumn('MEDIA', 230),
    const SectionColumn('RUNS', 50, alignRight: true),
    const SectionColumn('ESTIMATED', 70, alignRight: true),
    const SectionColumn('LENGTH UNKNOWN', 90, alignRight: true),
    const SectionColumn('FOOTAGE', 100, alignRight: true),
    SectionColumn(
      'WITH WASTE (+${percentOf(footage.wasteFactor)})',
      150,
      alignRight: true,
    ),
  ];
  final rows = <List<String>>[
    for (final line in footage.lines)
      <String>[
        line.media?.displayName ?? line.mediaId.v,
        '${line.runCount}',
        '${line.estimatedCount}',
        '${line.footage.unknownCount}',
        footageText(line.footage.value, units),
        footageText(line.withWaste, units),
      ],
  ];
  final unknown = footage.unknownLengthCount;
  final bounds = _sum(footage.lines.map((l) => l.boundCount));
  final unknownNote = unknown == 1
      ? '1 run has no length yet and is not in the footage.'
      : '$unknown runs have no length yet and are not in the footage.';
  final boundNote =
      'Of those, $bounds measured off a plan give only a least length, '
      'which is not ordered against.';
  final notes = <String>[
    if (unknown > 0) unknownNote,
    if (bounds > 0) boundNote,
    if (footage.excludedTotal > 0) 'Not footage: ${_excluded(footage)}.',
  ];
  return RollupSection(
    title: kFootageSectionTitle,
    columns: columns,
    rows: rows,
    empty: kNoFootageText,
    notes: notes,
  );
}

int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);

/// `4 jumpers and 2 power cords, bought by the piece; 1 internal; 14 of
/// undetermined class`.
String _excluded(CableFootage f) {
  String n(int count, String one, String many) =>
      '$count ${count == 1 ? one : many}';
  final pieces = <String>[
    if (f.excludedJumpers > 0) n(f.excludedJumpers, 'jumper', 'jumpers'),
    if (f.excludedPowerCords > 0)
      n(f.excludedPowerCords, 'power cord', 'power cords'),
  ];
  return <String>[
    if (pieces.isNotEmpty) '${pieces.join(' and ')}, bought by the piece',
    if (f.excludedInternal > 0)
      n(f.excludedInternal, 'internal link', 'internal links'),
    if (f.excludedUndeterminedClass > 0)
      '${f.excludedUndeterminedClass} of undetermined class',
  ].join('; ');
}
