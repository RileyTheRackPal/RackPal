// packages/rackpal_core/lib/src/derived/totals.dart
//
// docs/03-architecture.md's `derived/ ... totals.dart`: the four rollups
// docs/04-rack-editor.md §5's always-visible chip strip reads
// (`RU 15/24 · 148/200 lb ⁽³⁾ · 1.24 kVA · outlets 14/16`).
//
// THE HONESTY RULES THIS FILE EXISTS TO ENFORCE (docs/04 §5, G4, CR-114):
//
//  1. **No fabricated numbers, ever.** A total is `null` when nothing
//     known contributed to it — never `0`. `0` means "measured, and it is
//     zero"; `null` means "we do not know". A non-nullable `int` field
//     defaulting to `0` structurally cannot tell those apart, which is
//     exactly how the chip strip came to read "12/12U · 0 free" on a rack
//     with 5 U occupied.
//  2. **Every rollup states its unknown count.** `Rollup.unknownCount` is
//     how many contributing devices could not supply a value. A caller
//     that renders a total without also rendering this number is showing
//     a number that is quietly wrong by an unstated amount.
//
// FACE SEMANTICS, decided here and stated rather than left implicit.
// docs/04 §5's one-line strip shows a single `RU 15/24` while its Vitals
// panel shows Front and Rear as separate bars, and the same section rules
// that "front and rear RU are tracked separately, because 'how much room
// is left' genuinely has two answers". So:
//
//  * **RU is per-face** — [computeRackRollups] takes the face being
//    displayed and counts only that one. A caller MUST say which face its
//    number belongs to, or the strip silently changes meaning when the
//    user flips to the rear elevation. "On this face" means OCCUPIES U
//    there (`derived/device_loads.dart`'s `elevationOccupancyU`, CR-036),
//    NOT "is bolted to those rails" — the same predicate the canvas under
//    this strip draws by, because a strip that answers that question
//    differently from the picture beneath it is worse than no strip.
//  * **Weight, VA and outlets are rack-wide** — both faces, plus 0U
//    channel occupants and shelf-hosted devices. A device loads the rack's
//    weight capacity and draws from its circuits whichever face it is
//    bolted to; splitting those per face would invent a distinction the
//    physical rack does not have.
//
// This file computes and never formats. Pounds vs kilograms is
// `ProjectSettings.displayUnits` (CR-097) applied by the presentation
// layer through `unit_formatter.dart`; nothing here converts.

import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/mass.dart';

/// One derived total, with the count of contributors that could not supply
/// a value (docs/04 §5: "every rollup states its unknown count").
///
/// [value] is `null` **iff** at least one device contributed to this
/// rollup and none of them supplied a known value — "we know nothing about
/// this", which renders `—`. A rack with no contributors at all reports a
/// genuine zero: an empty rack really does weigh nothing extra and really
/// does provide no outlets, and that is a measurement, not a guess.
/// [T] is deliberately UNBOUNDED rather than `T extends Object`: `Mass` is
/// an extension type (units/mass.dart), and an extension type's only
/// supertype is `Object?`, so an `Object` bound would exclude the one
/// rollup that most needs exact integer arithmetic.
final class Rollup<T> {
  const Rollup({
    required this.value,
    required this.knownCount,
    required this.unknownCount,
  });

  /// Rule 1, applied to a scan that accumulated [sum] over [knownCount]
  /// contributors while [unknownCount] of them could supply nothing.
  ///
  /// THE ONE PLACE THE RULE IS SPELLED. It was written four times: a
  /// private `_totalOrUnknown` here, a VERBATIM copy of that same private
  /// helper in `draw/scene/rack_load_gutter.dart`, and the ternary inline
  /// in `derived/equipment_list.dart` (twice) and `derived/schedule.dart`.
  /// The latter three each carried a comment pointing at this file, which
  /// is an acknowledgement that they were copies rather than a defence
  /// against their drifting. All four agreed, so nothing was ever wrong;
  /// `derived/device_loads.dart`'s header makes the argument for why
  /// agreeing-for-now is not a state to leave a rule in, and this project
  /// has already shipped a 1000x error that survived because one
  /// conversion was pasted into nine files.
  ///
  /// A FACTORY RATHER THAN A SHARED FUNCTION, because rule 1 is a
  /// CONSTRAINT BETWEEN [value] and the two counts, not a calculation that
  /// happens to be shared. A free function leaves the unnamed constructor
  /// perfectly able to contradict it; this way a rollup built from a scan
  /// derives its `value` from the very counts it goes on to report. The
  /// unnamed constructor stays public for tests and fixtures that need to
  /// state an arbitrary rollup, including a deliberately inconsistent one.
  factory Rollup.fromScan({
    required T sum,
    required int knownCount,
    required int unknownCount,
  }) => Rollup<T>(
    // Unknown ONLY when nothing known contributed AND somebody failed to.
    // Nobody asked at all is a genuine zero: an empty rack really does
    // weigh nothing extra.
    value: knownCount == 0 && unknownCount > 0 ? null : sum,
    knownCount: knownCount,
    unknownCount: unknownCount,
  );

  /// The total over the contributors that supplied a value, or `null` when
  /// none did. NEVER a stand-in zero — see the class doc.
  final T? value;

  /// How many contributing devices supplied a value.
  final int knownCount;

  /// How many contributing devices did NOT — the superscript docs/04 §5
  /// puts on the chip and expands on hover.
  final int unknownCount;

  /// True when the total itself is unknown. Distinct from
  /// `unknownCount > 0`, which only says the total is INCOMPLETE.
  bool get isUnknown => value == null;
}

/// docs/04 §5's four always-visible rollups for one rack, with RU counted
/// on [face] and everything else counted rack-wide (see the file header).
final class RackRollups {
  const RackRollups({
    required this.face,
    required this.ruCapacity,
    required this.ruUsed,
    required this.ruUnknownCount,
    required this.weight,
    required this.weightCapacity,
    required this.apparentVA,
    required this.outletsConsumed,
    required this.outletsProvided,
    required this.outletsUnknownCount,
  });

  /// The face [ruUsed]/[ruFree] describe. Presentation MUST surface this;
  /// an unlabelled `5/12` means something different on each elevation.
  final Face face;

  /// `Rack.heightU`.
  final int ruCapacity;

  /// Distinct RU slots in `[1, ruCapacity]` occupied on [face]. Overlapping
  /// placements (an `RCK-001` error state, which the model permits and the
  /// validation engine will one day file) count once, not twice, and a
  /// device hanging past the top of the rack contributes only the slots
  /// that actually exist.
  final int ruUsed;

  /// Devices rail-placed in this rack whose occupancy could not be
  /// determined ON ANY FACE, so it is NOT in [ruUsed]. Two causes, both
  /// counted: the template snapshot did not resolve (CR-054 says a
  /// `TemplateRef` always does; a corrupt or hand-edited file says
  /// otherwise), or it resolved and gives the device ZERO U on BOTH faces.
  /// Silently under-reporting RU in either case would be exactly the
  /// fabricated number G4 forbids — see the scan itself.
  ///
  /// A device that simply does not appear on THIS elevation (a front-only
  /// blank seen from the rear) is not unknown and is not counted: the
  /// model states its rear height, and it is zero.
  final int ruUnknownCount;

  /// `ruCapacity - ruUsed`. Unaffected by [ruUnknownCount] on purpose: free
  /// space is measured from what is known to be occupied, and the unknown
  /// count is what tells the reader the figure is optimistic.
  int get ruFree => ruCapacity - ruUsed;

  /// Σ of every contributor's resolved weight (`DeviceOverrides.weight`
  /// falling back to `TemplateBody.weight`), rack-wide.
  final Rollup<Mass> weight;

  /// `Rack.weightCapacity` — the denominator in §5's `148/200 lb`. Null is
  /// UNKNOWN, never zero (CR-114); it is not part of [weight] because it
  /// is a fact about the rack, not a rollup over devices.
  final Mass? weightCapacity;

  /// Σ `PowerProfile.apparentVA`, rack-wide. VA and not watts because
  /// circuit loading is computed in VA (CR-056, AC-020), and `typicalWatts`
  /// is NEVER converted into a VA figure here — a power factor that was not
  /// authored is not a power factor this file may assume (AC-039's
  /// rejected "half of nameplate" behaviour, restated).
  final Rollup<int> apparentVA;

  /// Σ `PowerProfile.outletsConsumed`, rack-wide — the `14` of §5's
  /// `outlets 14/16`.
  final Rollup<int> outletsConsumed;

  /// Σ `PowerProfile.outletsProvided`, rack-wide — the `16`.
  final Rollup<int> outletsProvided;

  /// How many contributing devices are missing from the COMBINED
  /// `consumed/provided` figure — i.e. devices whose template stated
  /// neither outlet count, or only one of the two.
  ///
  /// WHY THIS EXISTS AS ITS OWN FIELD, and is not a presentation concern.
  /// docs/04 §5 renders `outlets 14/16` as ONE chip carrying ONE unknown
  /// superscript, but that chip reads TWO rollups. Rule 2 of this file's
  /// header ("every rollup states its unknown count") therefore obliges the
  /// chip to state the unknown count of the thing it actually displays, and
  /// that number is not recoverable from [outletsConsumed]`.unknownCount`
  /// and [outletsProvided]`.unknownCount`:
  ///
  ///  * Either count ALONE drops the other rollup's ignorance. The chip
  ///    used to take `outletsProvided.unknownCount` and nothing else, so a
  ///    rack of one PDU (states `outletsProvided`, silent on consumed) and
  ///    one amp (states `outletsConsumed`, silent on provided) rendered a
  ///    complete-looking `outlets 1/24` with no superscript at all.
  ///  * `max` of the two UNDER-counts that same rack: both counts are 1,
  ///    but TWO devices are missing from the figure.
  ///  * Their SUM OVER-counts the ordinary case: a device that states
  ///    neither is one incomplete contributor, not two.
  ///
  /// The exact answer is `|A ∪ B|` over the two sets of silent devices, and
  /// only the scan below sees the devices themselves. Guessing it in the
  /// widget would be the fabricated number G4 forbids, so the scan reports
  /// it.
  final int outletsUnknownCount;
}

/// Computes docs/04 §5's chip-strip rollups for [rack] with the elevation
/// showing [face].
///
/// Pure, total, and dependent on nothing but its arguments — deliberately
/// taking `(rack, devices, templates, face)` rather than a `RackDocument`
/// so it survives the arrival of a real `DocumentController` untouched, and
/// so a test can state a scenario in four lines.
///
/// WHICH DEVICES CONTRIBUTE. Rail-placed and 0U-placed devices naming this
/// rack, plus shelf-placed devices whose host chain lands in it — a
/// component sitting on a rack shelf loads the rack exactly as much as the
/// shelf does. Off-rack and staged (`StagedPlacement`, the Staging Bin —
/// CR-032) devices contribute to no rack, which is the whole point of
/// those variants.
RackRollups computeRackRollups({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required Face face,
}) {
  final byId = <Uuid, DeviceInstance>{for (final d in devices) d.id: d};

  final occupiedRu = <int>{};
  var ruUnknownCount = 0;

  var weightSum = Mass.zero;
  var weightKnown = 0;
  var weightUnknown = 0;

  var vaSum = 0;
  var vaKnown = 0;
  var vaUnknown = 0;

  var consumedSum = 0;
  var consumedKnown = 0;
  var consumedUnknown = 0;

  var providedSum = 0;
  var providedKnown = 0;
  var providedUnknown = 0;

  // Devices missing from the COMBINED `consumed/provided` figure — the
  // union of the two silences, counted here because only this loop can see
  // it (see `RackRollups.outletsUnknownCount`).
  var outletsUnknown = 0;

  for (final device in devices) {
    // THE SHARED PREDICATE (`derived/device_loads.dart`), not a private
    // copy. T6.30's equipment list calls the identical function, so a
    // device can never be counted in one and missing from the other.
    if (!belongsToRack(device, rack.id, byId)) continue;

    final body = bodyFor(device, templates);
    // THE SHARED RESOLUTION, likewise. See device_loads.dart's header for
    // why a second `overrides.weight ?? body?.weight` spelling is the
    // drift this file exists to prevent.
    final loads = resolveDeviceLoads(device, body);

    // ── RU, on the displayed face only ───────────────────────────────
    final placement = device.placement;
    if (placement is RailPlacement) {
      // THE SHARED PREDICATE AGAIN, and for the same reason: the CANVAS
      // sitting directly under this chip strip draws by
      // `elevationOccupancyU`, so the strip must count by it or the two
      // surfaces of one screen answer "what is on this face" differently.
      // They did. This used to require `placement.face == face` — the
      // rails the device is BOLTED TO rather than the U it OCCUPIES — so
      // after the elevation started honouring CR-036's occupancy struct
      // the chip read `RU rear 0/42` on `whole_house` while 19
      // `RenderDeviceBox`es rendered beneath it over 28 distinct rear U.
      // docs/04 §2.2: the face control "selects a coordinate, not a
      // filter".
      final deviceH = elevationOccupancyU(device, body, face);
      if (deviceH != null) {
        for (var u = placement.ruIndex; u < placement.ruIndex + deviceH; u++) {
          if (u >= 1 && u <= rack.heightU) occupiedRu.add(u);
        }
      } else if (!isDrawnOnSomeElevation(device, body)) {
        // UNKNOWN, not a measured zero. Something is bolted to this rack's
        // rails and NO elevation can say how tall it is: the snapshot
        // failed to resolve (CR-054 says it never should; a hand-edited
        // file says otherwise), or it resolved to zero U on BOTH faces.
        // This case used to fall through and be counted as a KNOWN
        // zero-occupancy contributor — the rear chip read `RU rear 0/12`
        // with no superscript while a device was rail-placed at U3. That
        // is the unknown contributor G4 forbids dropping, and
        // `rack_shrink.dart` treats the identical shape as
        // `DoomedKind.unmodelledRail`.
        //
        // The `else` this does NOT take is the device that is drawn on the
        // OTHER elevation: a front-only blank viewed from the rear, or a
        // rear lace bar bolted to the front rails viewed from the front,
        // occupies measurably ZERO U here. Counting those as unknown would
        // put a superscript on every chip in a half-depth rack and say
        // "we do not know" about the one thing the model states plainly.
        ruUnknownCount++;
      }
    }

    // ── weight / VA / outlets, rack-wide ─────────────────────────────
    final weight = loads.mass;
    if (weight == null) {
      weightUnknown++;
    } else {
      weightSum += weight;
      weightKnown++;
    }

    final va = loads.apparentVA;
    if (va == null) {
      vaUnknown++;
    } else {
      vaSum += va;
      vaKnown++;
    }

    // `outletsProvided`/`outletsConsumed` ARE nullable now, and this is the
    // reason. They shipped as non-nullable `int`s defaulting to 0, so a
    // resolved-but-never-authored template (the app's own four demo
    // templates; `catalog_passive.dart`'s three, whose header states in so
    // many words that they carry no power data) was counted as a MEASURED
    // zero and the chip strip read a confident `outlets 0/0` with no
    // superscript — rule 2 of this file's header, broken on first launch.
    //
    // Counted SEPARATELY per rollup, because a template may state one and
    // not the other, and a shared count would silently attribute one
    // rollup's ignorance to the other.
    final consumed = loads.outletsConsumed;
    if (consumed == null) {
      consumedUnknown++;
    } else {
      consumedSum += consumed;
      consumedKnown++;
    }

    final provided = loads.outletsProvided;
    if (provided == null) {
      providedUnknown++;
    } else {
      providedSum += provided;
      providedKnown++;
    }

    // ONE increment for a device that is silent about either half, which is
    // the whole reason this is counted here rather than combined afterwards.
    if (consumed == null || provided == null) outletsUnknown++;
  }

  return RackRollups(
    face: face,
    ruCapacity: rack.heightU,
    ruUsed: occupiedRu.length,
    ruUnknownCount: ruUnknownCount,
    weight: Rollup.fromScan(
      sum: weightSum,
      knownCount: weightKnown,
      unknownCount: weightUnknown,
    ),
    weightCapacity: rack.weightCapacity,
    apparentVA: Rollup.fromScan(
      sum: vaSum,
      knownCount: vaKnown,
      unknownCount: vaUnknown,
    ),
    outletsConsumed: Rollup.fromScan(
      sum: consumedSum,
      knownCount: consumedKnown,
      unknownCount: consumedUnknown,
    ),
    outletsProvided: Rollup.fromScan(
      sum: providedSum,
      knownCount: providedKnown,
      unknownCount: providedUnknown,
    ),
    outletsUnknownCount: outletsUnknown,
  );
}

// `_belongsToRack` and `_templateKey` USED TO LIVE HERE. They moved to
// `derived/device_loads.dart` verbatim so the T6.30 equipment list, its
// per-rack subtotals and the elevation's load gutter run the SAME scan
// this file does — see that file's header, and
// `equipment_list_test.dart`'s cross-check that the schedule's subtotal
// equals this function's `weight` rollup on the same inputs.
