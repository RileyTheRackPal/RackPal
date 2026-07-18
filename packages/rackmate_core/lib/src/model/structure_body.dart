// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart'
    show MountSurface, TerminationType, Wall;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

/// homeRunField|serviceEntrance|interRackTie|temporaryFeed.
enum StructureRole {
  homeRunField,
  serviceEntrance,
  interRackTie,
  temporaryFeed,
}

/// left|right, default left (CR-072).
enum SheetEdge { left, right }

/// The Structure device's body: the structured wiring entering the rack
/// (requirement 6 of the brief). Maps to the TIA-570-D Distribution
/// Device. Always paired 1:1 with a `DeviceInstance` whose
/// `kind == DeviceKind.structure`.
final class StructureBody {
  StructureBody({
    required this.id,
    required this.deviceId,
    required String title,
    required this.meta,
    this.role = StructureRole.homeRunField,
    this.distributionDeviceLocationId,
    this.enclosureModel,
    this.sheetEdge = SheetEdge.left,
  }) : _title = title;

  final Uuid id;

  /// The `DeviceInstance` with `kind == DeviceKind.structure`.
  final Uuid deviceId;

  /// "Rough-In - First Floor".
  String _title;
  String get title => _title;
  @internal
  set title(String v) => _title = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  StructureRole role;

  /// The SMC / can / MDF location.
  Uuid? distributionDeviceLocationId;

  /// "Generic 42 in structured media enclosure".
  String? enclosureModel;
  SheetEdge sheetEdge;
  EntityMeta meta;

  // NO bundleIds list — Outlets key back via Link.structureOrigin
  // (CR-016).
}

/// A home run's origin data — lives ON the `Link`, not a document-level
/// entity of its own (AC-019).
final class StructureOrigin {
  StructureOrigin({
    required this.structureBodyId,
    required this.outletId,
    required this.fieldLabel,
    required this.terminationField,
    this.rackLabel,
    this.wall,
    this.mountSurface,
    this.mountHeightAff,
  });

  final Uuid structureBodyId;
  final Uuid outletId;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// "LR-TV-1A" — on the wall plate. REQUIRED, unique project-wide across
  /// ALL Structure bodies (CR-113).
  String fieldLabel;

  /// "1A-A12" — at the panel. Unique when set.
  String? rackLabel;
  Wall? wall;
  MountSurface? mountSurface;
  Len? mountHeightAff;
  TerminationType terminationField;
}
