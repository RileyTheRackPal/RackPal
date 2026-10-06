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
import 'package:rackpal_core/src/derived/adapter_rollup.dart';
import 'package:rackpal_core/src/derived/cable_footage.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show hostRackOf;
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/derived/jumper_rollup.dart';
import 'package:rackpal_core/src/derived/outlet_map.dart';
import 'package:rackpal_core/src/draw/sheet/equipment_sheet.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/permille.dart';
import 'package:rackpal_core/src/validation/exceptions_report.dart';
import 'package:rackpal_core/src/validation/findings_view.dart';

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
  final captive = f.excludedCaptiveCords;
  final whose = captive == 1 ? 'its device' : 'their devices';
  return <String>[
    if (pieces.isNotEmpty) '${pieces.join(' and ')}, bought by the piece',
    // DR-238: set aside and said, so the counts on one sheet reconcile.
    if (captive > 0)
      '${n(captive, 'captive cord', 'captive cords')}, part of $whose',
    if (f.excludedInternal > 0)
      n(f.excludedInternal, 'internal link', 'internal links'),
    if (f.excludedUndeterminedClass > 0)
      '${f.excludedUndeterminedClass} of undetermined class',
  ].join('; ');
}

/// The hardware section's band.
const String kHardwareSectionTitle = 'HARDWARE IMPLIED BY THE RULES';

/// What the hardware section says when no rule implies anything.
const String kNoHardwareText = 'NO HARDWARE IMPLIED BY THE RULES.';

/// What each rule implies, by rule id (docs/08 §2.2: "ear kits, rear
/// supports").
const Map<String, String> kHardwareByRule = <String, String>{
  'RCK-013': 'Rear rail support',
  'RCK-014': 'Ear kit (half-rack)',
};

/// The hardware the rules imply (docs/08 §2.2, AC-028, CR-030, M6-F3).
///
/// ONE LINE PER FINDING, OPEN OR ACKNOWLEDGED (DR-219 §11.218.3). The
/// weight is physical; an acknowledgement usually records that the support
/// is specified, so the line stays and prints the acknowledgement's reason
/// in NOTES, where a shelf-mounted exception can be struck by hand. A rule
/// turned OFF for the project files nothing, so it implies nothing: that
/// is the project's own decision, made with a reason on T0.02.
///
/// From [report], the export's one evaluation (DR-214 §11.213.5), so the
/// list and T0.02 cannot disagree about which findings exist.
RollupSection hardwareSection(RackDocument doc, ExceptionsReport report) {
  final rows = <FindingRow>[
    for (final group in report.open) ...group.rows,
    ...report.acknowledged,
  ].where((r) => kHardwareByRule.containsKey(r.finding.ruleId)).toList();

  String designatorOf(FindingRow row) {
    final id = row.finding.primaryEntityId;
    return (id == null ? null : doc.devices[id]?.designator) ?? kUnknownCell;
  }

  String rackOf(FindingRow row) {
    for (final id in row.finding.targets) {
      final rack = doc.racks[id];
      if (rack != null) return rack.designator;
    }
    return kUnknownCell;
  }

  // TOTAL ORDER: rack, then device, then rule, then the fingerprint, which
  // is unique per finding.
  rows.sort((a, b) {
    final byRack = rackOf(a).compareTo(rackOf(b));
    if (byRack != 0) return byRack;
    final byDevice = designatorOf(a).compareTo(designatorOf(b));
    if (byDevice != 0) return byDevice;
    final byRule = a.finding.ruleId.compareTo(b.finding.ruleId);
    if (byRule != 0) return byRule;
    return a.finding.targetFingerprint.compareTo(b.finding.targetFingerprint);
  });

  return RollupSection(
    title: kHardwareSectionTitle,
    columns: const <SectionColumn>[
      SectionColumn('QTY', 30, alignRight: true),
      SectionColumn('ITEM', 170),
      SectionColumn('FOR', 90),
      SectionColumn('RACK', 80),
      SectionColumn('RULE', 60),
      SectionColumn('NOTES', 260),
    ],
    rows: <List<String>>[
      for (final row in rows)
        <String>[
          '1',
          kHardwareByRule[row.finding.ruleId]!,
          designatorOf(row),
          rackOf(row),
          row.finding.ruleId,
          if (row.reason case final reason?) 'Acknowledged: $reason' else '',
        ],
    ],
    empty: kNoHardwareText,
  );
}

/// The jumper section's band.
const String kJumperSectionTitle = 'JUMPERS AND POWER CORDS';

/// What the jumper section says when there are none.
const String kNoJumpersText = 'NO JUMPERS OR POWER CORDS IN THIS PROJECT.';

/// A lead's length as it is bought: `3 ft`, `1.5 ft`, `0.5 m`; the dash
/// when none is stated (G4).
String leadLengthText(Len? length, UnitSystem units) {
  if (length == null) return kUnknownCell;
  if (units == UnitSystem.imperial) {
    final tenths = (length.nm * 10 / (Len.nmPerInch * 12)).round();
    return tenths % 10 == 0
        ? '${tenths ~/ 10} ft'
        : '${(tenths / 10).toStringAsFixed(1)} ft';
  }
  final cm = (length.nm / (Len.nmPerMillimetre * 10)).round();
  final metres = (cm / 100)
      .toStringAsFixed(2)
      .replaceFirst(
        RegExp(r'\.?0+$'),
        '',
      );
  return '$metres m';
}

/// AC-026's jumper and power-cord rollup, by media, length and colour
/// (M6-F4). The quantities are `jumperRollupOf`'s, from the schedule's
/// rows, so they are the same leads the footage note excludes.
RollupSection jumperSection(JumperRollup rollup, UnitSystem units) {
  final unstated = rollup.noLengthCount;
  return RollupSection(
    title: kJumperSectionTitle,
    columns: const <SectionColumn>[
      SectionColumn('QTY', 30, alignRight: true),
      SectionColumn('MEDIA', 300),
      SectionColumn('LENGTH', 90, alignRight: true),
      SectionColumn('COLOUR', 150),
      SectionColumn('NOTES', 120),
    ],
    rows: <List<String>>[
      for (final line in rollup.lines)
        <String>[
          '${line.quantity}',
          line.media?.displayName ?? line.mediaId.v,
          leadLengthText(line.length, units),
          line.colour?.displayName ?? kUnknownCell,
          '',
        ],
    ],
    empty: kNoJumpersText,
    notes: <String>[
      if (unstated == 1) '1 lead has no length stated.',
      if (unstated > 1) '$unstated leads have no length stated.',
    ],
  );
}

/// The in-line adapters section's band (DR-235 §11.234.3).
const String kAdapterSectionTitle = 'IN-LINE ADAPTERS';

/// What it says when no cable carries an adapter.
const String kNoAdaptersText = 'NO IN-LINE ADAPTER IS DECLARED.';

/// DR-128 §11.127.2's promise, kept by DR-235 §11.234.3: every declared
/// adapter, by connector pair and model. The quantities are
/// `adapterRollupOf`'s, over the schedule's cables. An unstated model
/// prints as unknown on its own line and is counted underneath (G4).
RollupSection adapterSection(AdapterRollup rollup) {
  final unstated = rollup.unstatedModelCount;
  return RollupSection(
    title: kAdapterSectionTitle,
    columns: const <SectionColumn>[
      SectionColumn('QTY', 30, alignRight: true),
      SectionColumn('ADAPTER', 330),
      SectionColumn('MODEL', 330),
    ],
    rows: <List<String>>[
      for (final line in rollup.lines)
        <String>[
          '${line.quantity}',
          line.connectors,
          line.model ?? kUnknownCell,
        ],
    ],
    empty: kNoAdaptersText,
    notes: <String>[
      if (unstated == 1) '1 adapter has no model stated.',
      if (unstated > 1) '$unstated adapters have no model stated.',
    ],
  );
}

/// The outlet map's band.
const String kOutletMapSectionTitle = 'OUTLET MAP';

/// What the outlet map says when no device provides outlets.
const String kNoOutletProvidersText =
    'NO DEVICE IN THIS PROJECT PROVIDES '
    'OUTLETS.';

/// What it says when providers exist and no cord is drawn to one.
const String kNoOutletCordsText = 'NO CORD IS DRAWN TO AN OUTLET.';

/// AC-026's outlet map (M6-F5), in DR-219 §11.218.2's shape: a row per
/// outlet with a cord drawn to it, then each provider's free count, then
/// how many devices are counted as plugged in with no cord drawn. Kept OFF
/// the cable schedule, as AC-026 rules: do not move it back.
RollupSection outletMapSection(RackDocument doc, OutletMap map) {
  // A PDU IS USUALLY 0U, and a UPS may sit on a shelf: `hostRackOf` is the
  // walk the rack totals use, so the provider's rack is the totals' rack.
  String rackOf(DeviceInstance device) {
    final rackId = hostRackOf(device, doc.devices);
    return (rackId == null ? null : doc.racks[rackId]?.designator) ??
        kUnknownCell;
  }

  final rows = <List<String>>[
    for (final provider in map.providers)
      for (final a in provider.assignments)
        <String>[
          provider.device.designator,
          a.outletLabel,
          a.device?.designator ?? kUnknownCell,
          a.inletLabel ?? kUnknownCell,
          a.cord,
          rackOf(provider.device),
        ],
  ];
  final undrawn = map.undrawnDevices;
  String freeLine(OutletProvider p) =>
      '${p.device.designator}: ${p.assignedCount} of ${p.outletCount} '
      'outlets assigned, ${p.freeCount} free.';
  final undrawnLine = undrawn == 1
      ? '1 device has no cord drawn and is counted as one outlet per inlet.'
      : '$undrawn devices have no cord drawn and are counted as one outlet '
            'per inlet.';
  return RollupSection(
    title: kOutletMapSectionTitle,
    columns: const <SectionColumn>[
      SectionColumn('PROVIDER', 90),
      SectionColumn('OUTLET', 110),
      SectionColumn('DEVICE', 100),
      SectionColumn('INLET', 130),
      SectionColumn('CORD', 70),
      SectionColumn('RACK', 190),
    ],
    rows: rows,
    empty: map.providers.isEmpty ? kNoOutletProvidersText : kNoOutletCordsText,
    notes: <String>[
      for (final p in map.providers) freeLine(p),
      if (undrawn > 0) undrawnLine,
    ],
  );
}
