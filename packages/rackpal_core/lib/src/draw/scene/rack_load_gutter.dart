// rackpal_core/src/draw/scene/rack_load_gutter.dart — pure Dart.
//
// docs/08-pdf-export.md §2.2's elevation gutter: "cumulative mass from the
// bottom up, draw, and BTU/hr in the gutter".
//
// ─────────────────────────────────────────────────────────────────────────
// THE NUMBERS COME FROM THE SHARED RESOLVER, NOT FROM A SECOND SCAN
// ─────────────────────────────────────────────────────────────────────────
// Every mass, VA and BTU figure here is `resolveDeviceLoads`, and every
// membership decision is `hostRackOf` — the same two functions the chip
// strip (`derived/totals.dart`) and the T6.30 equipment list
// (`derived/equipment_list.dart`) call. A gutter with its own weight
// resolution is exactly the drift that produces a sheet whose total
// disagrees with the screen it was exported from.
//
// [computeRackLoadProfile] proves the join rather than asserting it: its
// TOP reading — the cumulative mass at the rack's top boundary — is
// constructed to equal the rack-wide rollup, including the devices that
// have no vertical position of their own. `rack_load_gutter_test.dart`
// asserts that against `computeRackRollups` on the same inputs.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT "CUMULATIVE FROM THE BOTTOM UP" MEANS HERE
// ─────────────────────────────────────────────────────────────────────────
// The reading at boundary `k` is the mass of everything MOUNTED AT OR
// BELOW that boundary — a device is counted once its highest U is at or
// under `k`. That is the figure a rigger reads: how much is hanging below
// this line. A device straddling the boundary is counted at its top, not
// apportioned, because a chassis is not a distributed load.
//
// A device whose vertical position is not knowable — a 0U channel
// occupant, a shelf chain that does not terminate at a rail — has no
// boundary to be counted at. It is NOT invented into one (attributing it
// to the rack bottom would be a position the model does not carry) and it
// is NOT dropped: it joins the TOP boundary's reading, so the topmost
// figure is the whole rack, and [RackLoadProfile.offAxisCount] states how
// many rows got there that way.
//
// ─────────────────────────────────────────────────────────────────────────
// UNKNOWNS ARE COUNTED AND SHOWN (G4)
// ─────────────────────────────────────────────────────────────────────────
// A reading over three devices whose masses are unknown prints
// `≥ 148.2 lb (3 unknown)`, never a bare figure — the `≥` is the honest
// operator, because the true total is at least what is known. A reading
// with NO known contributor prints `— (3 unknown)`, never `0`.
//
// ─────────────────────────────────────────────────────────────────────────
// AND SO IS WHAT THE PICTURE LEAVES OUT
// ─────────────────────────────────────────────────────────────────────────
// `scene_builder.dart`'s `_visibleDevices` draws a device only when it is
// rail-mounted and its template gives it ≥ 1 U on the face it is mounted
// on. A 0U channel occupant, a component sitting on a shelf and a rail
// device whose snapshot does not resolve are therefore on NO elevation at
// all — while T6.30 lists every one of them against this rack and this
// gutter counts their mass. Two sheets in one set contradicting each other
// about what is in a rack is the failure the M1 exit criterion's "matches
// the rack contents EXACTLY" is written against, and the sheet the
// installer actually builds from was the silent one.
//
// So [RackLoadProfile.undrawnCount] is computed with EXACTLY the predicate
// the scene builder draws by, and [rackLoadSummaryLines] states it. The
// elevation does not gain the devices — a 0U PDU has no elevation
// geometry to draw and inventing one would be worse — it gains a sentence
// saying how many it does not have and where they are listed.
//
// ─────────────────────────────────────────────────────────────────────────
// THE STATED COUNT IS THE COUNT FOR THE SHEET IT IS PRINTED ON
// ─────────────────────────────────────────────────────────────────────────
// It used to be face-INDEPENDENT ("drawn on NEITHER elevation") so that a
// front-rail device on T2.01 would not be called missing on T2.02. That
// reasoning is sound about crying wolf and wrong about the primary duty: a
// sheet must never state a count that contradicts what it visibly
// contains. `whole_house` T2.02 printed "NOT DRAWN 4 OF 31 DEVICES" —
// i.e. "27 of them are on this sheet" — over a bare 42U frame.
//
// So the sentence now states [RackLoadProfile.undrawnOn] for the face
// being drawn, and — this is what keeps it from crying wolf — SPLITS that
// number into the part that is on the opposite elevation and the part that
// is on no elevation at all. A reader is told where every one of them is,
// not merely that they are absent here.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/derived/totals.dart';
import 'package:rackpal_core/src/draw/bounds_canvas.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart';
import 'package:rackpal_core/src/draw/scene/rack_layer.dart' show LayerBuild;
import 'package:rackpal_core/src/draw/scene/rack_style.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/mass.dart';
import 'package:rackpal_core/src/units/unit_formatter.dart';

/// One cumulative reading, at one U boundary.
@immutable
final class CumulativeMassReading {
  const CumulativeMassReading({
    required this.boundaryU,
    required this.mass,
  });

  /// The boundary, counted from the rack's bottom: `0` is U1's bottom
  /// edge, `heightU` the rack's top edge — `RackGeometry.yOfBoundary`'s
  /// own `k`.
  final int boundaryU;

  /// Everything at or below [boundaryU], with the unknown contributors
  /// counted.
  final Rollup<Mass> mass;
}

/// The whole of one rack's load profile.
@immutable
final class RackLoadProfile {
  const RackLoadProfile({
    required this.readings,
    required this.totalMass,
    required this.weightCapacity,
    required this.apparentVA,
    required this.btuPerHour,
    required this.offAxisCount,
    required this.contributingCount,
    required this.undrawnCount,
    required this.undrawnFrontCount,
    required this.undrawnRearCount,
  });

  /// One entry per U boundary, `0 .. heightU`, ascending.
  final List<CumulativeMassReading> readings;

  /// The rack-wide total — equal to the last of [readings] by
  /// construction, and equal to `computeRackRollups(...).weight` by test.
  final Rollup<Mass> totalMass;

  /// `Rack.weightCapacity`. Null is UNKNOWN, never zero (CR-114).
  final Mass? weightCapacity;

  final Rollup<int> apparentVA;

  /// Σ of every contributor's BTU/hr. Derived only from `typicalWatts`
  /// (AC-039) — see `derived/device_loads.dart`.
  final Rollup<double> btuPerHour;

  /// How many contributing devices have no vertical position, and so
  /// appear only in the topmost reading. See the file header.
  ///
  /// NOT "devices with no RU": a rail device whose snapshot does not
  /// resolve lands here too, and it HAS a stated `ruIndex` — what it has
  /// not got is a knowable height, so there is no boundary to count it at.
  /// T6.30 prints that device's RU, so a sheet claiming it has none would
  /// put two sheets of one set in direct contradiction.
  final int offAxisCount;

  /// How many devices load this rack at all — the denominator T6.30's
  /// `RK-1 SUBTOTAL n DEVICES` band prints, so the two sheets join on a
  /// number the reader can compare.
  final int contributingCount;

  /// How many of those appear on NEITHER elevation. See the file header.
  ///
  /// Always ≥ [offAxisCount]: everything without a vertical position is
  /// also undrawn, and a shelf-hosted component adds to this without
  /// adding to that (it inherits its host's position but has no elevation
  /// geometry of its own).
  final int undrawnCount;

  /// How many contributing devices the FRONT elevation does not draw.
  final int undrawnFrontCount;

  /// How many contributing devices the REAR elevation does not draw.
  final int undrawnRearCount;

  /// How many contributing devices [face]'s elevation does not draw.
  ///
  /// Always ≥ [undrawnCount] — a device on no elevation is on neither of
  /// them — and the difference is exactly the set drawn only on the
  /// opposite face, which is what [rackLoadSummaryLines] tells the reader
  /// so the sentence names a place rather than a hole.
  int undrawnOn(Face face) =>
      face == Face.front ? undrawnFrontCount : undrawnRearCount;
}

/// Computes [rack]'s load profile from [devices] and [templates].
///
/// Pure and total, and deliberately taking the same four-argument shape
/// `computeRackRollups` does rather than a `RackDocument`, so a test can
/// state a scenario in four lines.
RackLoadProfile computeRackLoadProfile({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
}) {
  final byId = <Uuid, DeviceInstance>{for (final d in devices) d.id: d};

  // Known masses bucketed by the boundary they are counted at, plus the
  // unknown-mass contributors bucketed the same way — the unknown COUNT is
  // cumulative too, or a reading would state a total without saying how
  // incomplete it is.
  final knownAt = <int, Mass>{};
  final knownCountAt = <int, int>{};
  final unknownAt = <int, int>{};
  var offAxis = 0;
  var contributing = 0;
  var undrawn = 0;
  var undrawnFront = 0;
  var undrawnRear = 0;

  var vaSum = 0;
  var vaKnown = 0;
  var vaUnknown = 0;
  var btuSum = 0.0;
  var btuKnown = 0;
  var btuUnknown = 0;

  for (final device in devices) {
    if (hostRackOf(device, byId) != rack.id) continue;

    final body = bodyFor(device, templates);
    final loads = resolveDeviceLoads(device, body);
    contributing++;

    // Whether the elevations show this device at all, and whether EACH of
    // them does — THE SAME FUNCTION `scene_builder.dart` draws by, not a
    // restatement of it. A predicate written twice is the drift this
    // project keeps paying for, and here the two copies disagreeing would
    // mean the sheet states a count of omissions that is not the count of
    // what was omitted.
    // Since DR-204 a device on a drawn shelf IS drawn, so this asks
    // `isDrawnOnFace`, which knows about shelves, rather than the rail-only
    // occupancy question it asked before.
    final onFront = isDrawnOnFace(
      device,
      body,
      Face.front,
      byId: byId,
      templates: templates,
    );
    final onRear = isDrawnOnFace(
      device,
      body,
      Face.rear,
      byId: byId,
      templates: templates,
    );
    if (!onFront && !onRear) undrawn++;
    if (!onFront) undrawnFront++;
    if (!onRear) undrawnRear++;

    // Where in the stack this mass sits. A rail placement supplies it
    // directly; a shelf-hosted component inherits its host's. Anything
    // else has none — see the file header.
    final rail = supportingRailPlacement(device, byId);
    final deviceH = rail == null ? null : stackOccupancyU(body);
    final boundary = rail == null || deviceH == null
        ? null
        // The device's HIGHEST U, clamped into the rack: a device hanging
        // past the top is counted at the top rather than at a boundary
        // that does not exist.
        : (rail.ruIndex + deviceH - 1).clamp(1, rack.heightU);
    if (boundary == null) offAxis++;
    final at = boundary ?? rack.heightU;

    final mass = loads.mass;
    if (mass == null) {
      unknownAt[at] = (unknownAt[at] ?? 0) + 1;
    } else {
      knownAt[at] = (knownAt[at] ?? Mass.zero) + mass;
      knownCountAt[at] = (knownCountAt[at] ?? 0) + 1;
    }

    final va = loads.apparentVA;
    if (va == null) {
      vaUnknown++;
    } else {
      vaSum += va;
      vaKnown++;
    }

    final btu = loads.btuPerHour;
    if (btu == null) {
      btuUnknown++;
    } else {
      btuSum += btu;
      btuKnown++;
    }
  }

  final readings = <CumulativeMassReading>[];
  var runningMass = Mass.zero;
  var runningKnown = 0;
  var runningUnknown = 0;
  for (var k = 0; k <= rack.heightU; k++) {
    runningMass += knownAt[k] ?? Mass.zero;
    runningKnown += knownCountAt[k] ?? 0;
    runningUnknown += unknownAt[k] ?? 0;
    readings.add(
      CumulativeMassReading(
        boundaryU: k,
        mass: Rollup<Mass>.fromScan(
          sum: runningMass,
          knownCount: runningKnown,
          unknownCount: runningUnknown,
        ),
      ),
    );
  }

  return RackLoadProfile(
    readings: List.unmodifiable(readings),
    totalMass: readings.last.mass,
    weightCapacity: rack.weightCapacity,
    apparentVA: Rollup<int>.fromScan(
      sum: vaSum,
      knownCount: vaKnown,
      unknownCount: vaUnknown,
    ),
    btuPerHour: Rollup<double>.fromScan(
      sum: btuSum,
      knownCount: btuKnown,
      unknownCount: btuUnknown,
    ),
    offAxisCount: offAxis,
    contributingCount: contributing,
    undrawnCount: undrawn,
    undrawnFrontCount: undrawnFront,
    undrawnRearCount: undrawnRear,
  );
}

/// The em dash a gutter cell prints for a value that does not exist.
const String kGutterUnknown = '—';

/// Formats a mass rollup for the gutter — never a bare figure when
/// something is missing (G4).
///
/// `≥ 148.20 lb (3 unknown)` · `148.20 lb` · `— (3 unknown)`.
String formatMassRollup(Rollup<Mass> rollup, UnitSystem units) {
  final value = rollup.value;
  final suffix = rollup.unknownCount == 0
      ? ''
      : ' (${rollup.unknownCount} unknown)';
  if (value == null) return '$kGutterUnknown$suffix';
  final text = units == UnitSystem.metric
      ? value.toKilograms(fractionDigits: 1)
      : value.toPounds(fractionDigits: 1);
  return rollup.unknownCount == 0 ? text : '≥ $text$suffix';
}

/// Formats an integer rollup (VA) with the same honesty rule.
String formatIntRollup(Rollup<int> rollup, String unit) {
  final value = rollup.value;
  final suffix = rollup.unknownCount == 0
      ? ''
      : ' (${rollup.unknownCount} unknown)';
  if (value == null) return '$kGutterUnknown$suffix';
  final text = '$value $unit';
  return rollup.unknownCount == 0 ? text : '≥ $text$suffix';
}

/// Formats the BTU/hr rollup.
String formatBtuRollup(Rollup<double> rollup) {
  final value = rollup.value;
  final suffix = rollup.unknownCount == 0
      ? ''
      : ' (${rollup.unknownCount} unknown)';
  if (value == null) return '$kGutterUnknown$suffix';
  final text = '${value.round()} BTU/hr';
  return rollup.unknownCount == 0 ? text : '≥ $text$suffix';
}

/// How far right of the rack the gutter's text column starts.
const double kGutterGap = 40;

/// Every how many U a cumulative reading is printed.
///
/// One per U is unreadable at any print scale a 45 U rack fits on, and one
/// per 5 U lines up with the ruler's own major boundaries, so the reading
/// and the figure it belongs to are on the same line.
const int kGutterReadingStrideU = 5;

/// Builds the elevation's cumulative-mass gutter to the RIGHT of [geo]'s
/// rack box.
///
/// Emits in ABSOLUTE rack coordinates (the chassis convention), so it
/// composes into the rack scene with no translate and one `OpTransform`
/// scales the elevation and its readings together. Its ink sits outside
/// `RackGeometry.rackWidth` for the same reason the right-hand ruler does
/// — see `rack_layer.dart`'s header.
///
/// ONLY THE PER-BOUNDARY READINGS ARE IN HERE. The rack-wide summary
/// (total, capacity, draw, heat) is [rackLoadSummaryLines], drawn by the
/// sheet at PAPER scale — it is a summary, not model geometry, and putting
/// it inside the scaled bracket would also push the scene's ink below the
/// rack's own bottom edge, which is the edge the sheet anchors on.
LayerBuild buildRackLoadGutterLayer({
  required RackGeometry geo,
  required RackLoadProfile profile,
  required TextMeasurer measurer,
  required UnitSystem units,
  RackPalette palette = const RackPalette(),
  RackTypeScale typeScale = const RackTypeScale.identity(),
  double gap = kGutterGap,
}) {
  final ops = <DiagramOp>[];
  final sizePt = typeScale.size(RackTextSizes.gutter);
  final x = geo.rackWidth + gap;
  final label = rackText(sizePt, palette.deviceType, TextAnchor.midLeft);

  for (final reading in profile.readings) {
    // Boundary 0 is the rack's own bottom edge, where the cumulative
    // figure is always "nothing yet".
    if (reading.boundaryU == 0) continue;
    if (reading.boundaryU % kGutterReadingStrideU != 0 &&
        reading.boundaryU != geo.heightU) {
      continue;
    }
    ops.add(
      OpText(
        formatMassRollup(reading.mass, units),
        DPt(x, geo.yOfBoundary(reading.boundaryU)),
        label,
      ),
    );
  }

  return (
    ops: ops,
    minTextPt: ops.isEmpty ? double.infinity : sizePt,
    inkBounds: inkBoundsOf(ops, measurer: measurer),
  );
}

/// The sheet the undrawn devices ARE all listed on — docs/08 §2.2's
/// `T6.30 EQUIPMENT LIST AND MATERIALS`.
///
/// A cross-reference and not just a count, because "4 devices are not in
/// this picture" without "and here is where they are" leaves the reader
/// holding a hole rather than a pointer.
const String kUndrawnListedOnSheet = 'T6.30';

/// What the omission sentence calls the opposite elevation.
String _otherFaceWord(Face face) => face == Face.front ? 'REAR' : 'FRONT';

/// The sentence that reconciles THIS elevation with the rest of the set.
///
/// Shape: `NOT DRAWN HERE  n OF m — <where they are><why the top jumps>`.
///
/// Three facts, in one line because the band holds five and the other four
/// are the load figures (see [rackLoadSummaryLines]):
///
/// * `n` is [RackLoadProfile.undrawnOn] for THIS face — the only count a
///   reader can check against the sheet in their hands.
/// * the split says where those `n` are: `e ON REAR` for the ones the
///   opposite elevation draws, `u ONLY ON T6.30` for the ones no elevation
///   draws. When `e` is zero the second collapses to `SEE T6.30`, which is
///   the wording this sentence has always had for that case.
/// * `; k COUNTED AT TOP` is why the topmost cumulative gutter reading
///   jumps: `k` rows have no knowable position in the stack, so they are
///   counted at the rack's top boundary rather than invented onto one.
///
/// KEPT SHORT ENOUGH TO SURVIVE THE HALF-BAND. `elevation_sheet.dart`'s
/// `_band` gives each column `area.width / 2 − 8` = 337 pt and truncates
/// with a measured ellipsis, so a sentence that outgrows it reaches the
/// sheet as `…ON T6.3…`. Every clause here is abbreviated against that
/// budget, which is why the tail reads `COUNTED AT TOP` rather than
/// `COUNTED AT THE TOP` — the three-digit worst case spends the
/// difference. `elevation_omission_line_test.dart` measures it with the
/// real font rather than trusting this paragraph.
String _omissionLine(RackLoadProfile profile, Face face) {
  final here = profile.undrawnOn(face);
  final nowhere = profile.undrawnCount;
  // Drawn on the OPPOSITE elevation and not on this one. Never negative:
  // a device on no elevation is absent from this one too.
  final elsewhere = here - nowhere;
  final where = <String>[
    if (elsewhere > 0) '$elsewhere ON ${_otherFaceWord(face)}',
    if (nowhere > 0)
      elsewhere > 0
          ? '$nowhere ONLY ON $kUndrawnListedOnSheet'
          : 'SEE $kUndrawnListedOnSheet',
  ].join(', ');
  // "NOT DRAWN", never "WITH NO RU". A rail device whose template does not
  // resolve is off-axis and HAS an ruIndex — T6.30 prints it — so the old
  // sentence made two sheets of one set contradict each other. What is
  // actually true of every one of them is that the gutter counts them at
  // the top boundary because their position in the stack is not knowable.
  final offAxis = profile.offAxisCount;
  final atTop = offAxis == 0
      ? ''
      : '; ${offAxis == here ? 'ALL' : '$offAxis'} COUNTED AT TOP';
  return 'NOT DRAWN HERE  $here OF ${profile.contributingCount} — '
      '$where$atTop';
}

/// The rack-wide summary the elevation sheet prints at paper scale, for
/// the elevation of [face].
///
/// Returned as strings rather than ops so the sheet owns the typography
/// and this file owns the arithmetic — and so a test can assert on the
/// SENTENCES without a canvas.
///
/// [face] IS REQUIRED, and that is the fix for a sheet that lied: the
/// summary used to be face-independent and T2.02 printed the same
/// "NOT DRAWN 4 OF 31 DEVICES" as T2.01 while drawing nothing at all. See
/// the file header.
///
/// AT MOST FIVE LINES, and that is a hard budget rather than a habit:
/// `elevation_sheet.dart` sizes its note band at a constant
/// `kElevationHeaderBand`, and a line past `kElevationNoteLines` would
/// print over the top of the elevation it belongs to. So the omission
/// statement is ONE line carrying every count, not three. The band holds
/// six rows since DR-240, and since DR-241 a line too long for its column
/// wraps after its dash onto the next one, so five lines may print on six
/// rows; a sixth LINE here would leave a wrapped one nowhere to go.
List<String> rackLoadSummaryLines(
  RackLoadProfile profile,
  UnitSystem units,
  Face face,
) {
  final capacity = profile.weightCapacity;
  return <String>[
    'RACK TOTAL  ${formatMassRollup(profile.totalMass, units)}',
    if (capacity != null) 'CAPACITY  ${_capacity(capacity, units)}',
    'DRAW  ${formatIntRollup(profile.apparentVA, 'VA')}',
    'HEAT  ${formatBtuRollup(profile.btuPerHour)}',
    // Never silent, in either direction: a reader comparing this elevation
    // against T6.30 is owed the count of what is listed there and not
    // drawn here, and a reader comparing the topmost cumulative reading
    // against the ones below it is owed the reason it jumps.
    if (profile.undrawnOn(face) > 0) _omissionLine(profile, face),
  ];
}

String _capacity(Mass capacity, UnitSystem units) => units == UnitSystem.metric
    ? capacity.toKilograms(fractionDigits: 1)
    : capacity.toPounds(fractionDigits: 1);
