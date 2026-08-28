// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart' show LifecycleStatus;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/template.dart' show TemplateRef;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';
import 'package:rackpal_core/src/units/rgb.dart';

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

/// The `TemplateBody` facts a placed instance may override, named as a
/// type so that [DeviceOverrides.cleared] is a set of THESE and never a
/// set of strings (CR-053, AC-012: typed, never dotted-path maps).
enum DeviceOverrideField { typicalWatts, weight, bodyDepth, accentColor }

/// Per-instance overrides of `TemplateBody` facts — typed, nullable
/// fields (CR-053, AC-012).
///
/// ─────────────────────────────────────────────────────────────────────
/// THREE STATES, NOT TWO (DR-098 §11.97.3)
/// ─────────────────────────────────────────────────────────────────────
/// `null` used to carry both of the two things this class has to say, and
/// they are different statements. G4/CR-114 rule that null is UNKNOWN;
/// this class's own header ruled that null is NOT OVERRIDDEN. So a
/// generic 2U amplifier template declaring 30 lb could be restated at 30
/// lb, or replaced with some other number, and there was no way to say
/// "the unit actually in this rack is a different model and I do not know
/// what it weighs" — whereupon `RCK-003` totals the template's figure as
/// a measurement and the subtotal prints a mass with no unknown counted
/// against it, which is the fabricated rollup CR-114 exists to forbid.
///
/// A field therefore says exactly one of:
///
/// * **inherit** — the field is null and absent from [cleared]. The
///   template's value governs. This is the state of every override block
///   in the shipped corpus.
/// * **set** — the field is non-null. This instance states this value.
/// * **unknown** — the field is named in [cleared]. The template's value
///   does NOT govern here and the true value is not known, so every
///   rollup counts it rather than totalling it.
///
/// **The third state cannot be an explicit `null` on the wire**, because
/// CR-114 rules that unknown serializes as an absent key and an absent
/// key already means inherit. It is carried by a present key instead: see
/// `_encodeDeviceOverrides`.
///
/// **Set and cleared at once is a contradiction, not a precedence.** The
/// resolvers below would have to pick one, and either choice silently
/// discards a statement the document made. The codec refuses such a file
/// by name rather than normalising it, and [clear] and [inherit] each
/// undo the other so nothing in the app can build one.
///
/// FIELD LIST, and why it is four (DR-098 §11.97.4). `displayName` and
/// `typePrefix` are DELETED: `DeviceInstance.name` and the designator
/// allocator (with `designatorLocked`) already carry those two facts at
/// instance level, and two spellings of one fact is how a document comes
/// to say it two different ways. `bodyDepth` stays declared and unread;
/// M5's `RCK-012` is its named consumer, and the tri-state above is what
/// makes leaving it unread honest, since absent asserts nothing.
final class DeviceOverrides {
  DeviceOverrides({
    this.typicalWatts,
    this.weight,
    this.bodyDepth,
    this.accentColor,
    Set<DeviceOverrideField>? cleared,
  }) : cleared = cleared ?? <DeviceOverrideField>{};

  int? typicalWatts;
  Mass? weight;
  Len? bodyDepth;
  Rgb? accentColor;

  /// The fields this instance states are UNKNOWN, as distinct from the
  /// ones it does not override. Empty is the overwhelmingly common case
  /// and serializes as an absent key.
  final Set<DeviceOverrideField> cleared;

  /// True when this instance says nothing at all, which is what every
  /// override block on disk says today.
  bool get isEmpty =>
      cleared.isEmpty &&
      typicalWatts == null &&
      weight == null &&
      bodyDepth == null &&
      accentColor == null;

  /// States [field] as UNKNOWN, dropping any value previously set for it
  /// so the two states cannot both be held.
  void clear(DeviceOverrideField field) {
    _write(field, null);
    cleared.add(field);
  }

  /// Returns [field] to INHERIT: no value, not cleared.
  void inherit(DeviceOverrideField field) {
    _write(field, null);
    cleared.remove(field);
  }

  /// True when [field] is stated UNKNOWN by this instance.
  bool isUnknown(DeviceOverrideField field) => cleared.contains(field);

  // ─────────────────────────────────────────────────────────────────────
  // THE RESOLVERS ARE HERE AND NOWHERE ELSE
  // ─────────────────────────────────────────────────────────────────────
  // `derived/device_loads.dart`'s header is the argument, written for the
  // two-state version of this and unchanged by the third: four surfaces
  // read the same facts, and if each spells the precedence out for itself
  // they agree only until somebody edits one. A tri-state has three
  // branches where a `??` had one, which is three times as much to get
  // subtly different in four places.

  /// The instance's word on typical wattage given the template's, or
  /// `null` for unknown. AC-039 is unaffected: nothing here derives this
  /// from `nameplateWatts`.
  int? resolveTypicalWatts(int? fromTemplate) =>
      isUnknown(DeviceOverrideField.typicalWatts)
      ? null
      : (typicalWatts ?? fromTemplate);

  /// The instance's word on mass given the template's, or `null` for
  /// unknown.
  Mass? resolveWeight(Mass? fromTemplate) =>
      isUnknown(DeviceOverrideField.weight) ? null : (weight ?? fromTemplate);

  /// The instance's word on body depth given the template's, or `null`
  /// for unknown. No reader yet; M5's `RCK-012` is the named one.
  Len? resolveBodyDepth(Len? fromTemplate) =>
      isUnknown(DeviceOverrideField.bodyDepth)
      ? null
      : (bodyDepth ?? fromTemplate);

  /// The instance's word on accent colour given the template's, or `null`
  /// for unknown. DR-080 §11.79.4's precedence with the third state
  /// added: a cleared accent falls through to `palette.deviceFill` at the
  /// call site exactly as an absent one does, because "I do not know this
  /// device's colour" and "nobody said" paint the same box.
  Rgb? resolveAccentColor(Rgb? fromTemplate) =>
      isUnknown(DeviceOverrideField.accentColor)
      ? null
      : (accentColor ?? fromTemplate);

  void _write(DeviceOverrideField field, Object? value) {
    switch (field) {
      case DeviceOverrideField.typicalWatts:
        typicalWatts = value as int?;
      case DeviceOverrideField.weight:
        weight = value as Mass?;
      case DeviceOverrideField.bodyDepth:
        bodyDepth = value as Len?;
      case DeviceOverrideField.accentColor:
        accentColor = value as Rgb?;
    }
  }
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
