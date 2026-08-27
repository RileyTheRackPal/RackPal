// rackpal_core/src/derived/equipment_list.dart — pure Dart.
//
// The row model behind sheet `T6.30 EQUIPMENT LIST AND MATERIALS`
// (docs/08-pdf-export.md §2.2). Computes; never formats and never draws.
//
// ─────────────────────────────────────────────────────────────────────────
// ONE ROW PER DEVICE INSTANCE. QTY IS ALWAYS 1 IN THIS BUILD.
// ─────────────────────────────────────────────────────────────────────────
// §2.2's first column is `Qty`, and the obvious reading is "collapse
// identical devices into one row with a count". That collapse is
// DELIBERATELY NOT BUILT, and the reason is the milestone's own exit
// criterion: "the equipment list matches the rack contents EXACTLY". That
// is a bijection claim between devices and rows, and a quantity rollup is
// precisely the transform that makes an off-by-one invisible — to the
// reader AND to the test. The column ships (the spec has it) carrying 1;
// the collapse is recorded as deferred rather than quietly not built.
//
// ─────────────────────────────────────────────────────────────────────────
// NOTHING IS SILENTLY DROPPED
// ─────────────────────────────────────────────────────────────────────────
// Every `DeviceInstance` in the document appears in exactly one group.
// Devices that load a rack land in that rack's group; everything else —
// `OffRackPlacement`, `StagedPlacement` (the Staging Bin, CR-032), a shelf
// chain whose host is missing, and a rail placement naming a rack that is
// not in the document — lands in a trailing `NOT IN A RACK` group. An
// "equipment list" that omits equipment is the exact failure the exit
// criterion is testing for, so the partition is total by construction and
// `equipment_list_test.dart` asserts the bijection over the four real
// starter projects.
//
// ─────────────────────────────────────────────────────────────────────────
// NO PRICING (AC-055)
// ─────────────────────────────────────────────────────────────────────────
// `Money`, `cost`, `supplier` and `purchaseOrder` do not exist in v1 and no
// field here stands in for one. The word BOM appears nowhere: this is an
// equipment list, and the difference is that a BOM is a purchasing document.
//
// ─────────────────────────────────────────────────────────────────────────
// ORDER IS TOTAL AND DETERMINISTIC (§8.4)
// ─────────────────────────────────────────────────────────────────────────
// Racks by `Rack.order` then `Rack.id`; rows within a rack by RU
// DESCENDING, then by device UUID. Rows with no RU of their own — a 0U
// channel occupant, a component on a shelf — sort AFTER the rail-mounted
// rows, by UUID. No `Map` iteration order is relied on anywhere, so two
// exports of an unmodified project produce the identical table.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/derived/totals.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show LifecycleStatus;
import 'package:rackpal_core/src/model/location.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/mass.dart';

/// How a row's device is mounted — the `FACE` column's vocabulary.
///
/// Deliberately five values rather than `Face?`: "rear" and "not on a
/// face at all" are different facts, and a nullable `Face` can only spell
/// the first one.
enum EquipmentMounting {
  front,
  rear,

  /// A 0U vertical channel occupant.
  zeroU,

  /// Hosted on another device (a shelf).
  shelf,

  /// Off-rack or staged.
  none;

  /// What the FACE column prints.
  ///
  /// [none] prints `NONE`, not an empty cell and NOT [kUnknownCell]. An
  /// empty cell reads as "nobody filled this in" (`text_fit.dart`'s
  /// `kEmDash` doc) and it left the FACE column blank on every row of the
  /// `NOT IN A RACK` group — seventeen of them in `whole_house`. An em
  /// dash would be the opposite error: it means "we do not know", and an
  /// off-rack device is not on a face is a fact the model states.
  String get label => switch (this) {
    EquipmentMounting.front => 'FRONT',
    EquipmentMounting.rear => 'REAR',
    EquipmentMounting.zeroU => '0U',
    EquipmentMounting.shelf => 'SHELF',
    EquipmentMounting.none => 'NONE',
  };
}

/// What the LIFECYCLE column prints for a [LifecycleStatus].
///
/// `new_` renders as `NEW`: the trailing underscore is a Dart keyword
/// workaround (`new` is reserved) and is an implementation detail that must
/// never reach paper.
String lifecycleLabel(LifecycleStatus status) => switch (status) {
  LifecycleStatus.existing => 'EXISTING',
  LifecycleStatus.new_ => 'NEW',
  LifecycleStatus.future => 'FUTURE',
  LifecycleStatus.removed => 'REMOVED',
  LifecycleStatus.designIntent => 'DESIGN INTENT',
};

/// One line of T6.30. Holds VALUES, not formatted strings — pounds vs
/// kilograms is `ProjectSettings.displayUnits` (CR-097) applied by the
/// sheet builder, and this file never converts.
@immutable
final class EquipmentRow {
  const EquipmentRow({
    required this.deviceId,
    required this.designator,
    required this.manufacturer,
    required this.model,
    required this.description,
    required this.ruIndex,
    required this.ruSpan,
    required this.rackDesignator,
    required this.location,
    required this.mounting,
    required this.loads,
    required this.lifecycleStatus,
    required this.notes,
  });

  final Uuid deviceId;

  /// `MTX-1` — unique project-wide (CR-040), and the join the exit
  /// criterion's bijection test is stated over.
  final String designator;

  /// `TemplateBody.manufacturer`, or `null` when the snapshot does not
  /// resolve or the template does not state one.
  ///
  /// NULLABLE, and the nullability is the point (G4). It was an empty
  /// `String`, and `_dataRow` skips an empty cell — so `STR-1`, the one
  /// device in every starter with no template behind it by design
  /// (docs/07 §2), printed a row with two BLANK cells beside three em
  /// dashes and no way for a reader to tell which blank meant "none" and
  /// which meant "unfilled". The sheet renders a null as [kUnknownCell];
  /// this file still holds values, not formatted strings.
  final String? manufacturer;

  /// `TemplateBody.model` — or, for a `DeviceKind.structure` device,
  /// `StructureBody.enclosureModel`, which is a model string the document
  /// actually holds and which nothing under `derived/` used to read.
  /// `null` when neither exists.
  final String? model;

  /// The device's own name, falling back to the template's display name.
  /// Empty when neither exists — never a fabricated stand-in.
  final String description;

  /// Lowest occupied U, 1-based bottom-origin (CR-025), or `null` when the
  /// device is not rail-mounted.
  final int? ruIndex;

  /// U-height on the mounted face, or `null` when unknown or not
  /// applicable. `null` with a non-null [ruIndex] is the
  /// "unmodelled rail" shape — the device is bolted to the rails and its
  /// height is not knowable.
  final int? ruSpan;

  /// The rack's designator, or `null` for the unplaced group.
  final String? rackDesignator;

  /// `Location.name`, or `null`.
  final String? location;

  final EquipmentMounting mounting;

  /// Resolved through the SHARED [resolveDeviceLoads] — see
  /// `device_loads.dart`.
  final DeviceLoads loads;

  final LifecycleStatus lifecycleStatus;

  /// `DeviceInstance.notes`, or `null`.
  final String? notes;

  /// Always 1 in this build. See the file header.
  int get qty => 1;

  /// What the RU column prints: `4U · 12–15`, `1U · 7`, `0U`, or `—` when
  /// the span is not knowable.
  ///
  /// Uses an EN DASH for the range, matching §2.2's own `4U · 12–15`.
  String get ruLabel {
    final start = ruIndex;
    final span = ruSpan;
    if (start == null) {
      return mounting == EquipmentMounting.zeroU ? '0U' : kUnknownCell;
    }
    if (span == null) return '$kUnknownCell · $start';
    if (span == 1) return '1U · $start';
    return '${span}U · $start–${start + span - 1}';
  }
}

/// What a cell prints when the value is not known. NOT an empty cell (which
/// reads as "nobody filled this in") and NOT a zero (which reads as a
/// measurement) — see `derived/totals.dart`'s rule 1.
const String kUnknownCell = '—';

/// One group band on T6.30: a rack, or the trailing unplaced group.
@immutable
final class EquipmentGroup {
  const EquipmentGroup({
    required this.rackId,
    required this.title,
    required this.rows,
    required this.mass,
    required this.apparentVA,
  });

  /// `null` for the `NOT IN A RACK` group.
  final Uuid? rackId;

  /// The band's own line — `RK-1 · MASTER RACK · 42U` or
  /// `NOT IN A RACK`.
  final String title;

  final List<EquipmentRow> rows;

  /// Σ of this group's known masses, with the unknown contributors
  /// COUNTED (G4).
  ///
  /// Built exactly as `computeRackRollups` builds its own — a test asserts
  /// the two are equal for the same rack on the same inputs, so the
  /// schedule's subtotal and the chip strip above the canvas can never
  /// disagree.
  final Rollup<Mass> mass;

  final Rollup<int> apparentVA;

  bool get isUnplaced => rackId == null;
}

/// The whole of T6.30's data.
@immutable
final class EquipmentList {
  const EquipmentList({required this.groups, required this.unplacedCount});

  /// Rack groups in `Rack.order`, then the unplaced group if it has rows.
  final List<EquipmentGroup> groups;

  /// How many devices belong to no rack. Zero when the document is fully
  /// placed; stated on the sheet when it is not.
  final int unplacedCount;

  /// Every row, in sheet order.
  Iterable<EquipmentRow> get rows => groups.expand((g) => g.rows);

  int get rowCount => groups.fold(0, (n, g) => n + g.rows.length);
}

/// The band title for a rack.
String rackGroupTitle(Rack rack) {
  final name = rack.name.trim();
  return name.isEmpty
      ? '${rack.designator} · ${rack.heightU}U'
      : '${rack.designator} · $name · ${rack.heightU}U';
}

/// What the trailing group is called.
const String kUnplacedGroupTitle = 'NOT IN A RACK';

/// Builds T6.30's rows from [doc].
///
/// PURE and total: every device in `doc.devices` lands in exactly one
/// group. See the file header.
EquipmentList buildEquipmentList(RackDocument doc) {
  final byId = doc.devices;
  final racks = doc.racks.values.toList()
    ..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
    });
  final knownRackIds = <Uuid>{for (final rack in racks) rack.id};

  // Partition first, so the "exactly one group" property is a property of
  // this loop rather than of four independent filters that could each be
  // subtly different.
  final byRack = <Uuid, List<DeviceInstance>>{
    for (final rack in racks) rack.id: <DeviceInstance>[],
  };
  final unplaced = <DeviceInstance>[];
  for (final device in doc.devices.values) {
    final rackId = hostRackOf(device, byId);
    // A rail placement naming a rack that is not in the document is not a
    // reason to drop the device from the equipment list — it is a reason
    // to list it as unplaced. `null` and "names a rack we do not have"
    // are both "no group of its own".
    if (rackId != null && knownRackIds.contains(rackId)) {
      byRack[rackId]!.add(device);
    } else {
      unplaced.add(device);
    }
  }

  final groups = <EquipmentGroup>[
    for (final rack in racks)
      _group(
        rackId: rack.id,
        title: rackGroupTitle(rack),
        devices: byRack[rack.id]!,
        rackDesignator: rack.designator,
        doc: doc,
      ),
    if (unplaced.isNotEmpty)
      _group(
        rackId: null,
        title: kUnplacedGroupTitle,
        devices: unplaced,
        rackDesignator: null,
        doc: doc,
      ),
  ];

  return EquipmentList(
    groups: List.unmodifiable(groups),
    unplacedCount: unplaced.length,
  );
}

EquipmentGroup _group({
  required Uuid? rackId,
  required String title,
  required List<DeviceInstance> devices,
  required String? rackDesignator,
  required RackDocument doc,
}) {
  final rows = <EquipmentRow>[
    for (final device in devices)
      _row(device, doc: doc, rackDesignator: rackDesignator),
  ]..sort(_byRuDescendingThenId);

  var massSum = Mass.zero;
  var massKnown = 0;
  var massUnknown = 0;
  var vaSum = 0;
  var vaKnown = 0;
  var vaUnknown = 0;
  for (final row in rows) {
    final mass = row.loads.mass;
    if (mass == null) {
      massUnknown++;
    } else {
      massSum += mass;
      massKnown++;
    }
    final va = row.loads.apparentVA;
    if (va == null) {
      vaUnknown++;
    } else {
      vaSum += va;
      vaKnown++;
    }
  }

  return EquipmentGroup(
    rackId: rackId,
    title: title,
    rows: List.unmodifiable(rows),
    // Rule 1 through `Rollup.fromScan`, which is where it is spelled. This
    // used to restate the ternary and caption it "the SAME rule
    // `derived/totals.dart` applies", which named the coupling without
    // doing anything about it.
    mass: Rollup<Mass>.fromScan(
      sum: massSum,
      knownCount: massKnown,
      unknownCount: massUnknown,
    ),
    apparentVA: Rollup<int>.fromScan(
      sum: vaSum,
      knownCount: vaKnown,
      unknownCount: vaUnknown,
    ),
  );
}

EquipmentRow _row(
  DeviceInstance device, {
  required RackDocument doc,
  required String? rackDesignator,
}) {
  final body = bodyFor(device, doc.templates);
  final placement = device.placement;

  final (
    EquipmentMounting mounting,
    int? ruIndex,
    int? ruSpan,
  ) = switch (placement) {
    RailPlacement(:final face, :final ruIndex) => (
      face == Face.front ? EquipmentMounting.front : EquipmentMounting.rear,
      ruIndex,
      occupancyU(body, face),
    ),
    ZeroUPlacement() => (EquipmentMounting.zeroU, null, null),
    ShelfPlacement() => (EquipmentMounting.shelf, null, null),
    OffRackPlacement() || StagedPlacement() => (
      EquipmentMounting.none,
      null,
      null,
    ),
  };

  final name = device.name.trim();
  final display = (body?.displayName ?? '').trim();

  // A structure device HAS NO TEMPLATE, by spec rather than by omission
  // (docs/07 §2: "No template. Its 'ports' are a rendering of home-run
  // field endpoints"). Its model string lives on the `StructureBody` the
  // document carries beside it, and no file under `derived/` or
  // `draw/sheet/` used to read `doc.structures` at all — so
  // `whole_house`'s "Generic 42 in structured media enclosure" existed in
  // the document and was dropped from the deliverable.
  final structureModel = _trimToNull(
    doc.structures[device.structureBodyId]?.enclosureModel,
  );

  return EquipmentRow(
    deviceId: device.id,
    designator: device.designator,
    manufacturer: _trimToNull(body?.manufacturer),
    model: _trimToNull(body?.model) ?? structureModel,
    description: name.isNotEmpty ? name : display,
    ruIndex: ruIndex,
    ruSpan: ruSpan,
    rackDesignator: rackDesignator,
    location: _locationName(device.locationId, doc.locations),
    mounting: mounting,
    loads: resolveDeviceLoads(device, body),
    lifecycleStatus: device.lifecycleStatus,
    notes: device.notes,
  );
}

/// `null` for both "absent" and "present but blank", so a cell can render
/// one unknown marker instead of an empty cell for one of them.
String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _locationName(Uuid? id, Map<Uuid, Location> locations) {
  if (id == null) return null;
  final name = locations[id]?.name.trim();
  return name == null || name.isEmpty ? null : name;
}

/// RU descending, rows without an RU last, ties broken by device UUID.
///
/// A total order with no reference to `Map` iteration (§8.4). "Without an
/// RU last" rather than interleaved: a 0U occupant and a shelf-hosted
/// component have no place in a vertical sequence, and inventing one
/// (their host's RU, the rack bottom) would be a position the model does
/// not carry.
int _byRuDescendingThenId(EquipmentRow a, EquipmentRow b) {
  final ra = a.ruIndex;
  final rb = b.ruIndex;
  if (ra != rb) {
    if (ra == null) return 1;
    if (rb == null) return -1;
    return rb.compareTo(ra);
  }
  return a.deviceId.v.compareTo(b.deviceId.v);
}
