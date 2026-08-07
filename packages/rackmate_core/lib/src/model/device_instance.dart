// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show LifecycleStatus;
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/template.dart' show TemplateRef;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';
import 'package:rackmate_core/src/units/rgb.dart';

/// rackDevice|shelf|structure|offRackPassive|virtual|blankPanel|
/// ventPanel|pdu|ups.
enum DeviceKind {
  rackDevice,
  shelf,
  structure,
  offRackPassive,
  virtual,
  blankPanel,
  ventPanel,
  pdu,
  ups,
}

/// Per-instance overrides of `TemplateBody` facts — typed, nullable
/// fields; `null` *is* the sparse "not overridden" semantics (CR-053,
/// AC-012).
///
/// M0 MINIMAL SHAPE: the entity spec names the type but not its field
/// list ("TYPED, nullable fields"); the subset below (display name, type
/// prefix, typical wattage, weight, body depth, accent colour) is a
/// deliberately incomplete but useful starting set, per this package's
/// governing instructions.
final class DeviceOverrides {
  DeviceOverrides({
    this.displayName,
    this.typePrefix,
    this.typicalWatts,
    this.weight,
    this.bodyDepth,
    this.accentColor,
  });

  String? displayName;
  String? typePrefix;
  int? typicalWatts;
  Mass? weight;
  Len? bodyDepth;
  Rgb? accentColor;
}

/// One placed (or staged) piece of equipment — the project-level
/// counterpart to a `TemplateBody`'s physical facts.
final class DeviceInstance {
  DeviceInstance({
    required this.id,
    required this.kind,
    required this.templateRef,
    required String designator,
    required String name,
    required Placement placement,
    required this.meta,
    this.designatorLocked = false,
    LifecycleStatus lifecycleStatus = LifecycleStatus.new_,
    Uuid? locationId,
    this.serialNumber,
    this.assetTag,
    this.macAddressPrimary,
    this.firmwareVersion,
    this.installedAt,
    DeviceOverrides? overrides,
    this.designatorWatermark = 0,
    this.structureBodyId,
    String? notes,
    this.colorOverride,
  }) : _designator = designator,
       _name = name,
       _placement = placement,
       _lifecycleStatus = lifecycleStatus,
       _locationId = locationId,
       overrides = overrides ?? DeviceOverrides(),
       _notes = notes;

  final Uuid id;

  /// "MTX-1" — unique project-wide.
  String _designator;
  String get designator => _designator;
  @internal
  set designator(String v) => _designator = v;

  String _name;
  String get name => _name;
  @internal
  set name(String v) => _name = v;

  Placement _placement;
  Placement get placement => _placement;
  @internal
  set placement(Placement v) => _placement = v;

  String? _notes;
  String? get notes => _notes;
  @internal
  set notes(String? v) => _notes = v;

  /// Same five-value enum as `Link.lifecycleStatus` (CR-064, CR-065,
  /// AC-018). Written through `DeviceField.lifecycleStatus`; the elevation
  /// draws it as a distinct border per state (`lifecycleStroke`) and T6.30
  /// prints it as a word (`lifecycleLabel`).
  LifecycleStatus _lifecycleStatus;
  LifecycleStatus get lifecycleStatus => _lifecycleStatus;
  @internal
  set lifecycleStatus(LifecycleStatus v) => _lifecycleStatus = v;

  /// The room this device is in. NOT the same field as
  /// `OffRackPlacement.locationId`, and `AddStructureCommand` writes the
  /// same value into both: retrofitted by M3-B/1 because
  /// `RemoveLocationCommand` clears BOTH when that room is deleted
  /// (DR-021 §11.20.2), and clearing one would leave the document
  /// disagreeing with itself.
  ///
  /// NOT a `DeviceField` row. It has no editing gesture yet; the retrofit
  /// follows the wiring, and this table stays a SUBSET of the model's
  /// `@internal` setters, which is the direction its test asserts.
  Uuid? _locationId;
  Uuid? get locationId => _locationId;
  @internal
  set locationId(Uuid? v) => _locationId = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  DeviceKind kind;

  /// ALWAYS resolves to an embedded snapshot (CR-054).
  TemplateRef templateRef;

  /// CR-034.
  bool designatorLocked;
  String? serialNumber;
  String? assetTag;
  String? macAddressPrimary;
  String? firmwareVersion;
  DateTime? installedAt;
  DeviceOverrides overrides;

  /// Reserve allocation (AC-006).
  int designatorWatermark;
  Uuid? structureBodyId;
  Rgb? colorOverride;
  EntityMeta meta;

  // No localTemplate, no zOrder, no cost/supplier — deliberately absent.
}
