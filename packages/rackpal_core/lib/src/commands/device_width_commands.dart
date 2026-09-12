// Lateral position: the writer `PLC-002` has been waiting for (`#269`,
// M5-C, CR-030).
//
// ═════════════════════════════════════════════════════════════════════
// A RULE WITH NO WRITER REFUSES NOTHING
// ═════════════════════════════════════════════════════════════════════
// `PLC-002` (`startTwelfth` in `[0,11]`, `spanTwelfths` in `[1,12]`,
// their sum at most 12) shipped its predicate and its AC-051 pair at
// M5-C, and a census found nothing in core, the UI or the app shell that
// wrote either field: `MoveDeviceCommand` carries them across a move and
// the codec reads them off a file, and that was the whole population.
// Tier 1 is *"the command is rejected"*, so until something could write a
// bad value the rule was a predicate nobody called.
//
// docs/04 §3 has specified the control the whole time: *"Lateral position
// is a `Width position` dropdown, `Full (0,12) | Left half (0,6) | Right
// half (6,6)`, writing `startTwelfth`/`spanTwelfths` (CR-030)."*
//
// ═════════════════════════════════════════════════════════════════════
// THE COMMAND TAKES TWELFTHS, THE UI OFFERS THREE. THAT IS DELIBERATE.
// ═════════════════════════════════════════════════════════════════════
// [WidthPosition] is CR-030's three, and a command whose parameter was
// that enum could not be given an illegal value at all: `PLC-002` would
// be unfireable by construction, which is a comfortable way to leave a
// rule untested rather than a way to satisfy it.
//
// So the command takes the raw twelfths the MODEL carries, the planner
// refuses the ones `PLC-002` refuses, and the dropdown offers three. When
// CR-030's *"free lateral dragging is v1.2"* arrives it writes arbitrary
// twelfths through this same gate rather than needing a second one.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/derived/placement_rules.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The lateral positions the v1 editor offers (CR-030, docs/04 §3).
///
/// NOT THE FORMAT'S VOCABULARY, and the distinction is CR-030's whole
/// ruling: twelfths stay in the file because *"retrofitting a lateral
/// axis into `Placement` is a migration touching every device"*, while
/// the v1 UI exposes three of the seventy-eight legal `(start, span)`
/// pairs. This enum is the UI's list. `PLC-002` governs the other
/// seventy-five.
enum WidthPosition {
  full(0, 12, 'Full'),
  leftHalf(0, 6, 'Left half'),
  rightHalf(6, 6, 'Right half');

  const WidthPosition(this.startTwelfth, this.spanTwelfths, this.label);

  final int startTwelfth;
  final int spanTwelfths;

  /// What the dropdown row reads, HERE rather than in the widget, so an
  /// undo entry and the control cannot disagree about which one was
  /// picked (`SetFamilyColorOverrideCommand`'s precedent).
  final String label;

  /// The position matching [startTwelfth]/[spanTwelfths], or null when
  /// the device sits somewhere the v1 dropdown cannot express.
  ///
  /// NULL IS A REAL ANSWER AND THE CONTROL MUST SHOW IT. A file authored
  /// by a v1.2 build with free lateral dragging, or by hand, can hold
  /// `(3, 6)`; a dropdown that silently displayed `Full` for it would
  /// misreport the document, and one that silently CORRECTED it on open
  /// would edit somebody's drawing without being asked.
  static WidthPosition? matching(int startTwelfth, int spanTwelfths) {
    for (final p in values) {
      if (p.startTwelfth == startTwelfth && p.spanTwelfths == spanTwelfths) {
        return p;
      }
    }
    return null;
  }
}

/// What [planSetDeviceWidth] decided.
sealed class WidthChangeResult {
  const WidthChangeResult();
}

final class WidthChangeReady extends WidthChangeResult {
  const WidthChangeReady(this.command);
  final SetDeviceWidthCommand command;
}

final class WidthChangeRefused extends WidthChangeResult {
  const WidthChangeRefused(this.reason, {this.ruleId});

  /// A complete sentence for the person who asked, on `ConnectRefused`'s
  /// contract.
  final String reason;

  /// `"PLC-002"` when a tier-1 rule refused, null when the refusal is not
  /// a rule at all: a device that is not rail-placed has no lateral
  /// position, and no catalogue entry says so (CR-021).
  final String? ruleId;
}

/// Plans a lateral-position change for [id], or refuses it.
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT REFUSES ON ANY TIER-1 FAULT IN THE RESULT, NOT ONLY ON `PLC-002`
/// ═══════════════════════════════════════════════════════════════════════
/// A device already sitting outside its rack, which DR-112 makes a legal
/// document state reachable by import or a hand edit, cannot have its
/// width changed until it is back inside. That follows
/// `connect_rules.dart`'s stated position on `TOP-005`, which it
/// evaluates as a PRECONDITION rather than as something the gesture could
/// create: *"a connect must not write a `Link` into a region of the
/// document that is already model-illegal."*
///
/// The alternative, refusing only on the rule this edit could break, was
/// considered and is worse in the one way that matters: `PLC-001` sorts
/// before `PLC-002`, so a device at U 40 given a span of 13 would have
/// its span accepted because the RU fault masked the lateral one.
WidthChangeResult planSetDeviceWidth({
  required RackDocument doc,
  required Uuid id,
  required int startTwelfth,
  required int spanTwelfths,
  required DateTime now,
  required String actor,
}) {
  final device = doc.devices[id];
  if (device == null) {
    return const WidthChangeRefused('That device is not in this document.');
  }
  final placement = device.placement;
  if (placement is! RailPlacement) {
    return WidthChangeRefused(
      '${device.designator} is not mounted to the rails, so it has no '
      'width position.',
    );
  }
  final verdict = evaluatePlacement(
    doc: doc,
    placement: _rebuild(placement, startTwelfth, spanTwelfths),
    body: bodyFor(device, doc.templates),
    designator: device.designator,
  );
  if (verdict is PlacementRefused) {
    return WidthChangeRefused(verdict.message, ruleId: verdict.ruleId);
  }
  return WidthChangeReady(
    SetDeviceWidthCommand(
      id: id,
      fromStartTwelfth: placement.startTwelfth,
      fromSpanTwelfths: placement.spanTwelfths,
      toStartTwelfth: startTwelfth,
      toSpanTwelfths: spanTwelfths,
      now: now,
      actor: actor,
    ),
  );
}

/// Writes a device's lateral position, replacing the whole
/// `RailPlacement` and carrying every other field across unchanged.
///
/// Built only by [planSetDeviceWidth]. The constructor is public because
/// `command_roundtrip_test.dart` and undo/redo need it, and it asserts
/// nothing: by the time this exists the planner has already refused every
/// value `PLC-002` refuses, and an assert here would fire on a REDO after
/// a rack shrink made an unrelated fault appear.
final class SetDeviceWidthCommand extends Command<RackDocument> {
  SetDeviceWidthCommand({
    required this.id,
    required this.fromStartTwelfth,
    required this.fromSpanTwelfths,
    required this.toStartTwelfth,
    required this.toSpanTwelfths,
    required this.now,
    required this.actor,
  });

  final Uuid id;
  final int fromStartTwelfth;
  final int fromSpanTwelfths;
  final int toStartTwelfth;
  final int toSpanTwelfths;
  final DateTime now;
  final String actor;

  // The same cache, for the same reason, as `MoveDeviceCommand`'s: the
  // untouched `RailPlacement` fields survive because apply and revert read
  // them off the CURRENT placement, but `EntityMeta.touch()` overwrites
  // the triple with no way to recover it, and CR-117's byte round-trip
  // fails on every generated sequence containing one of these otherwise.
  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.setDeviceWidth;

  /// `structure`, and NOT `wires`. A lateral move changes where the box is
  /// drawn across the opening; it does not move a port's rail position,
  /// and `MoveDeviceCommand` declares `wires` because a change of U
  /// re-routes every cable landing on it.
  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  Object? get mergeKey => (SetDeviceWidthCommand, id);

  @override
  bool apply(RackDocument doc) {
    final d = doc.devices[id]!;
    final base = _requireRail(d);
    _prevUpdatedAt = d.meta.updatedAt;
    _prevUpdatedBy = d.meta.updatedBy;
    _prevLocalRevision = d.meta.localRevision;
    d.placement = _rebuild(base, toStartTwelfth, toSpanTwelfths);
    d.meta.touch(now, actor);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final d = doc.devices[id]!;
    final base = _requireRail(d);
    d.placement = _rebuild(base, fromStartTwelfth, fromSpanTwelfths);
    final prevAt = _prevUpdatedAt;
    final prevBy = _prevUpdatedBy;
    final prevRev = _prevLocalRevision;
    if (prevAt == null || prevBy == null || prevRev == null) {
      throw StateError('SetDeviceWidthCommand.revert called before apply().');
    }
    d.meta.restoreTo(
      updatedAt: prevAt,
      updatedBy: prevBy,
      localRevision: prevRev,
    );
  }

  RailPlacement _requireRail(DeviceInstance d) {
    final current = d.placement;
    if (current is RailPlacement) return current;
    throw StateError(
      'SetDeviceWidthCommand requires device $id to be rail-placed; '
      'found ${current.runtimeType}.',
    );
  }
}

RailPlacement _rebuild(
  RailPlacement base,
  int startTwelfth,
  int spanTwelfths,
) => RailPlacement(
  rackId: base.rackId,
  ruIndex: base.ruIndex,
  face: base.face,
  startTwelfth: startTwelfth,
  spanTwelfths: spanTwelfths,
  depthOffsetFromFront: base.depthOffsetFromFront,
  chassisRotation: base.chassisRotation,
  locked: base.locked,
);
