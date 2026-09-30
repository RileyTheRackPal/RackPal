// rackpal_core/src/derived/device_loads.dart — pure Dart.
//
// THE one place a device's physical loads are resolved from the model, and
// THE one predicate that decides which rack a device loads.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS FILE EXISTS: A SECOND RESOLUTION PATH IS THE DRIFT
// ─────────────────────────────────────────────────────────────────────────
// Four surfaces read the same three facts about a device — its mass, its
// apparent VA and its heat: the chip strip (`derived/totals.dart`), the
// elevation's load gutter (`draw/scene/rack_load_gutter.dart`), the T6.30
// equipment list's rows and that list's per-rack subtotals
// (`derived/equipment_list.dart`). If each spells out
// `device.overrides.weight ?? body?.weight` for itself, they agree only for
// as long as nobody edits one of them. This project has already shipped a
// 1000x mass unit error that survived because the conversion was
// copy-pasted into nine files; the same shape applied to a rollup produces
// a sheet whose subtotal disagrees with the chip strip above it.
//
// So `totals.dart` was REFACTORED to call this rather than this being
// written beside it, and `equipment_list_test.dart` asserts the T6.30
// subtotal equals `computeRackRollups`' figure for the same rack on the
// same inputs.
//
// ─────────────────────────────────────────────────────────────────────────
// NULL IS "WE DO NOT KNOW". ZERO IS A MEASUREMENT.
// ─────────────────────────────────────────────────────────────────────────
// Every field on [DeviceLoads] is nullable and none of them defaults to 0
// (CR-114, G4). A caller that renders a null as `0` is fabricating; a
// caller that renders it as `—` and counts it is not. `Rollup.unknownCount`
// exists so the count survives to paper.
//
// ─────────────────────────────────────────────────────────────────────────
// BTU/hr IS DERIVED FROM typicalWatts, AND FROM NOTHING ELSE (AC-039)
// ─────────────────────────────────────────────────────────────────────────
// `btuPerHourOverride ?? wattsToBtuPerHour(typicalWatts)`, and NULL when
// `typicalWatts` is null. It is never synthesised from `apparentVA` (that
// would assume a power factor nobody authored) and never from
// `nameplateWatts` (AC-039's explicitly rejected "half of nameplate"
// behaviour). A thermal figure invented from a UL label is the kind of
// number an installer sizes a fan against.
//
// ─────────────────────────────────────────────────────────────────────────
// EVERY FIGURE HERE IS AN INPUT DRAW. CAPACITY IS NOT RESOLVED AT ALL.
// ─────────────────────────────────────────────────────────────────────────
// `PowerProfile.outputCapacityVA` / `outputCapacityWatts` are what a UPS,
// PDU or conditioner can DELIVER, and [DeviceLoads] has no field for them
// on purpose: the gear behind that device is already in the document with
// its own draw, so adding a through-rating to a rollup counts the whole
// downstream load twice. It did — P03 authored `apparentVA: 3000` and
// `whole_house` RK-1 reported 5440 VA and 15979 BTU/hr against a true
// 2490 VA and 6920 BTU/hr. If a capacity check ever lands (CR-056 checks
// UPS capacity VA against VA), it reads the template directly; it does not
// come through here.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/mass.dart';
import 'package:rackpal_core/src/units/thermal.dart';

/// The `RackDocument.templates` key for a template id at a version —
/// `"$templateId@$version"`.
///
/// One spelling, because three files used to carry their own copy of this
/// string interpolation and a key that is wrong resolves to `null`, which
/// every caller reads as "unknown template" rather than as "typo".
///
/// THE ID/VERSION FORM EXISTS FOR THE ONE SITE THAT EXTRACTION MISSED.
/// `commands/catalog_placement.dart`'s `catalogTemplateKey` pins version 1
/// for a seed id and has no `TemplateRef` to hand, so it kept its own
/// `'$catalogId@1'` under a comment naming a THIRD file as the format's
/// owner. A second spelling of the join is the same defect as a second
/// spelling of the key.
String templateKey(String templateId, int version) => '$templateId@$version';

/// [templateKey] for [ref].
String templateKeyFor(TemplateRef ref) =>
    templateKey(ref.templateId.v, ref.version);

/// Resolves [device]'s template body from [templates], or `null` when the
/// snapshot does not resolve.
///
/// CR-054 says a `TemplateRef` ALWAYS resolves. A hand-edited or truncated
/// file says otherwise, and every caller here treats the null as an unknown
/// contributor rather than as an impossibility.
TemplateBody? bodyFor(
  DeviceInstance device,
  Map<String, TemplateSnapshot> templates,
) => templates[templateKeyFor(device.templateRef)]?.body;

/// The physical loads one device contributes, each `null` when unknown.
@immutable
final class DeviceLoads {
  const DeviceLoads({
    required this.mass,
    required this.apparentVA,
    required this.typicalWatts,
    required this.btuPerHour,
  });

  /// Nothing at all is known about this device — the template snapshot did
  /// not resolve and no override supplied anything either.
  static const DeviceLoads unknown = DeviceLoads(
    mass: null,
    apparentVA: null,
    typicalWatts: null,
    btuPerHour: null,
  );

  /// `DeviceOverrides.weight` falling back to `TemplateBody.weight`.
  final Mass? mass;

  /// `PowerProfile.apparentVA`. Circuit loading is computed in VA (CR-056,
  /// AC-020), and `typicalWatts` is NEVER converted into a VA figure — a
  /// power factor that was not authored is not one this file may assume.
  final int? apparentVA;

  /// `DeviceOverrides.typicalWatts` falling back to
  /// `PowerProfile.typicalWatts`. NEVER derived from `nameplateWatts`
  /// (AC-039).
  final int? typicalWatts;

  /// `btuPerHourOverride ?? wattsToBtuPerHour(typicalWatts)`, or `null`.
  /// See the file header.
  final double? btuPerHour;

  @override
  String toString() =>
      'DeviceLoads(mass: $mass, VA: $apparentVA, W: $typicalWatts, '
      'BTU/hr: $btuPerHour)';
}

/// Resolves [device]'s loads against its [body], applying every
/// `DeviceOverrides` field that exists for the fact in question.
///
/// [body] may be `null` (an unresolved snapshot); an override still wins,
/// which is why this is not simply short-circuited — a device whose
/// template is missing but whose weight was typed in by hand is a KNOWN
/// mass, and dropping it would under-report the rack.
///
/// THE PRECEDENCE ITSELF LIVES ON `DeviceOverrides` (DR-098 §11.97.3),
/// not here. It used to be a `??` in this function, and a `??` cannot
/// express the third state an override can now hold: that the template's
/// figure does NOT govern for this instance and the real one is unknown.
/// Resolving that to null is what routes the device into
/// `Rollup.unknownCount` rather than into a total, which is G4's whole
/// argument applied one level down.
DeviceLoads resolveDeviceLoads(DeviceInstance device, TemplateBody? body) {
  final power = body?.power;
  final watts = device.overrides.resolveTypicalWatts(power?.typicalWatts);
  final override = power?.btuPerHourOverride;
  return DeviceLoads(
    mass: device.overrides.resolveWeight(body?.weight),
    apparentVA: power?.apparentVA,
    typicalWatts: watts,
    btuPerHour:
        override?.toDouble() ??
        (watts == null ? null : wattsToBtuPerHour(watts)),
  );
}

/// Which rack [device] loads, or `null` when it loads none.
///
/// Directly for rails and the 0U channel; through a chain of shelf hosts
/// for a component sitting on a rack shelf — it loads the rack exactly as
/// much as the shelf does. `OffRackPlacement` and `StagedPlacement` (the
/// Staging Bin, CR-032) belong to no rack, which is the whole point of
/// those variants.
///
/// [byId] resolves the host chain. The visited set makes a corrupt file's
/// `ShelfPlacement` cycle terminate rather than hang the UI thread.
///
/// EXTRACTED FROM `totals.dart`, which now calls it. See the file header.
Uuid? hostRackOf(
  DeviceInstance device,
  Map<Uuid, DeviceInstance> byId,
) {
  final visited = <Uuid>{};
  var current = device;
  while (visited.add(current.id)) {
    final placement = current.placement;
    switch (placement) {
      case RailPlacement():
        return placement.rackId;
      case ZeroUPlacement():
        return placement.rackId;
      case ShelfPlacement():
        final host = byId[placement.hostDeviceId];
        if (host == null) return null;
        current = host;
      case OffRackPlacement():
      case StagedPlacement():
        return null;
    }
  }
  return null;
}

/// Whether [device] loads [rackId]. The predicate `computeRackRollups` and
/// the T6.30 equipment list SHARE, so a device can never be in one and
/// missing from the other.
bool belongsToRack(
  DeviceInstance device,
  Uuid rackId,
  Map<Uuid, DeviceInstance> byId,
) => hostRackOf(device, byId) == rackId;

/// The rail placement [device]'s vertical position derives from — its own
/// when it is rail-mounted, otherwise its shelf host's.
///
/// Returns `null` for a 0U occupant, an off-rack or staged device, and a
/// shelf chain that does not terminate at a rail. Used by the elevation's
/// cumulative-mass gutter, which needs to know WHERE in the stack a mass
/// sits and must not guess when it cannot tell.
RailPlacement? supportingRailPlacement(
  DeviceInstance device,
  Map<Uuid, DeviceInstance> byId,
) {
  final visited = <Uuid>{};
  var current = device;
  while (visited.add(current.id)) {
    final placement = current.placement;
    switch (placement) {
      case RailPlacement():
        return placement;
      case ShelfPlacement():
        final host = byId[placement.hostDeviceId];
        if (host == null) return null;
        current = host;
      case ZeroUPlacement():
      case OffRackPlacement():
      case StagedPlacement():
        return null;
    }
  }
  return null;
}

/// The U-height [face]'s ELEVATION draws [device] at, or `null` when that
/// elevation does not draw it.
///
/// THE ONE PREDICATE THAT DECIDES WHAT IS ON A FACE — for everything that
/// draws it, everything that counts it and everything that asks whether
/// there is room on it:
///
///  * `scene_builder.dart` draws by it (the canvas and T2.01/T2.02);
///  * `rack_load_gutter.dart` counts what it excludes, so the sheet can
///    SAY how many devices no elevation shows;
///  * `derived/totals.dart` counts the chip strip's per-face RU by it;
///  * `commands/catalog_placement.dart`'s `elevationOccupantsOnFace` —
///    and therefore `findLowestFreeRu`, `findBlockingOccupant`, the
///    insertion caret, quick-add, keyboard nudge and drag-drop — decides
///    whether a U range is free by it.
///
/// Those were the same three lines written four times, and each surface is
/// only truthful while they agree. The two that had not been converted
/// contradicted the canvas ON THE SAME SCREEN: the chip strip read
/// `RU rear 0/42` above 19 rendered device boxes, and the rear drop
/// evaluator called U1-U3 free with UPS-1 drawn across it.
///
/// The complement — "which rails is it bolted to" — is [boltedRailFace],
/// named apart precisely so the next reader has to choose.
///
/// ── THE FACE IS THE SHEET'S, NOT THE PLACEMENT'S (docs/04 §2.2, CR-036)
/// This used to read `occupancyU(body, placement.face)` — the face the
/// device is BOLTED TO — and `scene_builder` additionally required
/// `placement.face == sheetFace`. Together those made the rear elevation
/// of every shipped starter empty: `whole_house` RK-1 mounts all 27 rail
/// devices on the FRONT rails, and 19 of them resolve to templates with
/// `rearU > 0` and `side: both`, so the model says they occupy rear U and
/// T2.02 drew none of them.
///
/// docs/04 §2.2 is explicit that the face control "selects a coordinate,
/// not a filter", and that "a 2U patch panel with `{frontU: 2, rearU: 2}`
/// renders on both faces and a rear lace bar renders only on rear". The
/// occupancy struct (CR-036) is therefore the whole answer: a rail device
/// is on [face]'s elevation exactly when its body occupies ≥ 1 U there.
/// Which rails carry its ears does not change what a technician standing
/// behind the rack sees.
///
/// `null` for a 0U channel occupant and a shelf-hosted component (neither
/// has elevation geometry — its own placement is not a rail placement),
/// and for a rail device whose snapshot does not resolve or gives zero U
/// on [face] (its height there is not knowable — see [occupancyU]).
int? elevationOccupancyU(
  DeviceInstance device,
  TemplateBody? body,
  Face face,
) {
  final placement = device.placement;
  if (placement is! RailPlacement) return null;
  return occupancyU(body, face);
}

/// The rails [device]'s ears are BOLTED TO, or `null` when it is not
/// rail-placed at all.
///
/// ── THE SECOND QUESTION, NAMED SO IT CANNOT BE MISTAKEN FOR THE FIRST
/// [elevationOccupancyU] asks about SPACE: "does this device occupy U on
/// this face, and how many". This asks about HARDWARE: "which rails carry
/// its ears". docs/04 §2.2 keeps them apart deliberately — the face
/// control "selects a coordinate, not a filter" — and every surface that
/// DRAWS, COUNTS or COLLISION-CHECKS a face wants the first one. Asking
/// this one instead is what made the rear elevation empty (T2.02 drew
/// nothing), the rear chip read `RU rear 0/42` under 19 rendered device
/// boxes, and the rear insertion caret call U1-U3 free with UPS-1 drawn
/// across it.
///
/// A caller may legitimately want this one when its answer is about to be
/// WRITTEN BACK into a `RailPlacement.face`. Exactly two are:
/// `compaction.dart` and `rack_shrink.dart`, whose plans become
/// `MoveDeviceCommand(fromFace:, toFace:)` — planning a rear-elevation
/// compaction over a front-bolted device by its elevation footprint would
/// unbolt it and re-hang it on the rear rails, which is a much larger edit
/// than "close the gaps" and one no preview would show. Those two ask
/// `boltedOccupantsOnFace`; everything else asks
/// `elevationOccupantsOnFace`.
Face? boltedRailFace(DeviceInstance device) {
  final placement = device.placement;
  return placement is RailPlacement ? placement.face : null;
}

/// Whether ANY elevation draws [device] — "is it in the picture at all".
///
/// Defined as [elevationOccupancyU] over every face rather than as its own
/// test, so the count of what no elevation shows can never describe a
/// different set from the one actually left out. `rack_load_gutter.dart`'s
/// `undrawnCount` is exactly the complement of this.
/// Whether the [face] elevation draws [device] at all: a rail device that
/// occupies U on that face, or a device sitting on a shelf that is itself
/// drawn there (DR-204 §11.203.4).
///
/// **THE SHELF HALF IS THE SAME TEST `scene_builder.dart` DRAWS BY**: it
/// lays hosts only on shelves it drew on this face, and only hosts whose
/// template resolves. `rack_load_gutter_test.dart` compares this against
/// what `buildRackScene` actually leaves out, so the two cannot drift
/// without a red test. [elevationOccupancyU] stays the rail-only question,
/// because its callers are asking about U, which a host has none of.
bool isDrawnOnFace(
  DeviceInstance device,
  TemplateBody? body,
  Face face, {
  required Map<Uuid, DeviceInstance> byId,
  required Map<String, TemplateSnapshot> templates,
}) {
  final placement = device.placement;
  if (placement is ShelfPlacement) {
    if (body == null) return false;
    final shelf = byId[placement.hostDeviceId];
    if (shelf == null) return false;
    return elevationOccupancyU(shelf, bodyFor(shelf, templates), face) != null;
  }
  return elevationOccupancyU(device, body, face) != null;
}

bool isDrawnOnSomeElevation(DeviceInstance device, TemplateBody? body) {
  for (final face in Face.values) {
    if (elevationOccupancyU(device, body, face) != null) return true;
  }
  return false;
}

/// The U-height a device with [body] occupies IN THE STACK — the taller of
/// its two faces — or `null` when neither is knowable.
///
/// The gutter's cumulative readings are a property of the RACK, not of a
/// face: both elevations print the same figures, and the boundary a mass
/// is counted at is the device's highest U wherever you stand. This used
/// to be spelled `occupancyU(body, rail.face)`, which asks the wrong
/// question of a rear lacing bar screwed to the front rails
/// (`{frontU: 0, rearU: 1}`): its mount face gives zero U, so the gutter
/// called its position unknowable and counted it at the rack top, while
/// T2.02 draws it at its stated RU. Two sheets of one set, again.
int? stackOccupancyU(TemplateBody? body) {
  if (body == null) return null;
  final u = math.max(body.frontU, body.rearU);
  return u > 0 ? u : null;
}

/// The U-height a device with [body] occupies on [face], or `null` when
/// that is not knowable.
///
/// `null` is returned BOTH when the body does not resolve AND when it
/// resolves to zero U on the face the device claims to be mounted on —
/// `rack_shrink.dart` treats that same shape as its `unmodelledRail`
/// doomed kind ("its height is not knowable"). Counting it as a measured
/// zero is how
/// the rear chip once read `RU rear 0/12` with a device rail-placed at U3.
int? occupancyU(TemplateBody? body, Face face) {
  if (body == null) return null;
  final u = face == Face.front ? body.frontU : body.rearU;
  return u > 0 ? u : null;
}
