// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart' show LifecycleStatus;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/port.dart' show NetworkConfig;
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

/// One overridable fact's COMPLETE state, as a single value.
///
/// ─────────────────────────────────────────────────────────────────────
/// WHY THIS TYPE EXISTS AT ALL
/// ─────────────────────────────────────────────────────────────────────
/// `DeviceOverrides` stores the three states of DR-098 §11.97.3 across two
/// members: a nullable field and the [DeviceOverrides.cleared] set. That is
/// the right STORAGE, because it is what makes an unset field cost nothing
/// on the wire. It is the wrong thing to hand an editor.
///
/// `EntityField`'s `get`/`set` pair carries exactly one `T`, and the undo
/// stack's coalescing, its `mergeKey` and its `revert` are all built on
/// that shape. Splitting an override edit into "write the field" and
/// "write the cleared set" would put it on a second mechanism with a
/// second undo story, and a user who cleared a weight and pressed
/// `Ctrl+Z` once could land in the state the codec refuses. So the three
/// states become one value, and door 1 reuses the machinery every other
/// property edit already has.
///
/// NAMING, because it diverges from the ruling by one word. §11.97.3 calls
/// the states *inherit*, *set* and *unknown*. The middle one is
/// [OverrideStated] here rather than `OverrideSet`, because `set` is
/// already the name of the accessor that writes any of the three, and a
/// type called `OverrideSet` sitting beside `EntityField.set` reads as the
/// setter rather than as one of its possible values.
///
/// IMMUTABLE, UNLIKE EVERYTHING AROUND IT. The document graph is mutable by
/// CR-083 and `DeviceOverrides` is mutable with it. This is not part of the
/// graph: it is a value passed to and from an editor, held as the `from`
/// and `to` of an undo entry. `SetEntityPropertyCommand` keeps both for the
/// life of the stack, so a mutable one would let a later edit reach back
/// and change what `Ctrl+Z` restores.
@immutable
sealed class OverrideValue<T> {
  const OverrideValue();

  /// The value this state resolves to when it is the instance's word, or
  /// `null` for both *inherit* and *unknown*. Callers that must tell those
  /// two apart switch on the type; [DeviceOverrides]'s resolvers are the
  /// ones that do.
  T? get valueOrNull => switch (this) {
    OverrideStated<T>(:final value) => value,
    _ => null,
  };
}

/// *inherit*: this instance has no opinion and the template governs.
final class OverrideInherited<T> extends OverrideValue<T> {
  const OverrideInherited();

  @override
  bool operator ==(Object other) => other is OverrideInherited<T>;

  @override
  int get hashCode => Object.hash(OverrideInherited, T);

  @override
  String toString() => 'OverrideInherited<$T>()';
}

/// *set*: this instance states [value].
final class OverrideStated<T> extends OverrideValue<T> {
  const OverrideStated(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      other is OverrideStated<T> && other.value == value;

  @override
  int get hashCode => Object.hash(OverrideStated, T, value);

  @override
  String toString() => 'OverrideStated<$T>($value)';
}

/// *unknown*: the template's value does NOT govern here, and the true
/// value is not known. Every rollup counts this rather than totalling it.
final class OverrideUnknown<T> extends OverrideValue<T> {
  const OverrideUnknown();

  @override
  bool operator ==(Object other) => other is OverrideUnknown<T>;

  @override
  int get hashCode => Object.hash(OverrideUnknown, T);

  @override
  String toString() => 'OverrideUnknown<$T>()';
}

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
    int? typicalWatts,
    Mass? weight,
    Len? bodyDepth,
    Rgb? accentColor,
    Set<DeviceOverrideField>? cleared,
  }) : _typicalWatts = typicalWatts,
       _weight = weight,
       _bodyDepth = bodyDepth,
       _accentColor = accentColor,
       cleared = cleared ?? <DeviceOverrideField>{};

  // ─────────────────────────────────────────────────────────────────────
  // AC-013's PUBLIC-GETTER / @internal-SETTER PAIRS, RETROFITTED HERE
  // ─────────────────────────────────────────────────────────────────────
  // These were plain public mutable fields from M0 until DR-098, which was
  // harmless for exactly as long as nothing wrote one. The moment door 1
  // gives them a producer it stops being harmless: a public setter is a
  // second writer that bypasses the command system, so an override set
  // that way is absent from the undo stack, touches no `EntityMeta` and
  // invalidates no epoch, and the canvas keeps painting the old figure.
  //
  // `set_entity_property_command_test.dart`'s "the retrofit and the tables
  // agree" case is what found this, by failing the moment `DeviceField`
  // gained four rows with no `@internal` setter behind them. That is the
  // test doing precisely the job its own comment claims.

  int? _typicalWatts;
  int? get typicalWatts => _typicalWatts;
  @internal
  set typicalWatts(int? v) => _typicalWatts = v;

  Mass? _weight;
  Mass? get weight => _weight;
  @internal
  set weight(Mass? v) => _weight = v;

  Len? _bodyDepth;
  Len? get bodyDepth => _bodyDepth;
  @internal
  set bodyDepth(Len? v) => _bodyDepth = v;

  Rgb? _accentColor;
  Rgb? get accentColor => _accentColor;
  @internal
  set accentColor(Rgb? v) => _accentColor = v;

  /// The fields this instance states are UNKNOWN, as distinct from the
  /// ones it does not override. Empty is the overwhelmingly common case
  /// and serializes as an absent key.
  ///
  /// MUTABLE AND PUBLIC, unlike the four above, and the asymmetry is worth
  /// a sentence: this is a `final` collection whose contents only [clear]
  /// and [inherit] change, and both of those are `@internal`. Making the
  /// set itself unmodifiable would cost a copy on every edit to close a
  /// hole the two writers above it already close.
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
  @internal
  void clear(DeviceOverrideField field) {
    _write(field, null);
    cleared.add(field);
  }

  /// Returns [field] to INHERIT: no value, not cleared.
  @internal
  void inherit(DeviceOverrideField field) {
    _write(field, null);
    cleared.remove(field);
  }

  /// True when [field] is stated UNKNOWN by this instance.
  bool isUnknown(DeviceOverrideField field) => cleared.contains(field);

  // ─────────────────────────────────────────────────────────────────────
  // THE STATE ACCESSORS: two members in, one value out
  // ─────────────────────────────────────────────────────────────────────
  // Written out four times rather than generated from the enum, because
  // each one is the only place its `T` is named and a generic version
  // would hand every caller an `OverrideValue<Object>` to cast. The
  // repetition is four lines each and it is what keeps `weightState`
  // typed to `Mass` all the way out to the widget.

  OverrideValue<int> get typicalWattsState =>
      _stateOf(DeviceOverrideField.typicalWatts, typicalWatts);
  @internal
  set typicalWattsState(OverrideValue<int> v) =>
      _applyState(DeviceOverrideField.typicalWatts, v);

  OverrideValue<Mass> get weightState =>
      _stateOf(DeviceOverrideField.weight, weight);
  @internal
  set weightState(OverrideValue<Mass> v) =>
      _applyState(DeviceOverrideField.weight, v);

  OverrideValue<Len> get bodyDepthState =>
      _stateOf(DeviceOverrideField.bodyDepth, bodyDepth);
  @internal
  set bodyDepthState(OverrideValue<Len> v) =>
      _applyState(DeviceOverrideField.bodyDepth, v);

  OverrideValue<Rgb> get accentColorState =>
      _stateOf(DeviceOverrideField.accentColor, accentColor);
  @internal
  set accentColorState(OverrideValue<Rgb> v) =>
      _applyState(DeviceOverrideField.accentColor, v);

  OverrideValue<T> _stateOf<T>(
    DeviceOverrideField field,
    T? value,
  ) {
    if (isUnknown(field)) return OverrideUnknown<T>();
    if (value != null) return OverrideStated<T>(value);
    return OverrideInherited<T>();
  }

  void _applyState<T>(
    DeviceOverrideField field,
    OverrideValue<T> state,
  ) {
    // GOES THROUGH [clear] AND [inherit] rather than writing `cleared`
    // directly, so the "never both" invariant has exactly one enforcement
    // point and this setter cannot drift away from it.
    switch (state) {
      case OverrideInherited<T>():
        inherit(field);
      case OverrideUnknown<T>():
        clear(field);
      case OverrideStated<T>(:final value):
        cleared.remove(field);
        _write(field, value);
    }
  }

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
    this.network,
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

  /// The device's MANAGEMENT address: hostname, IP, subnet, gateway, VLANs
  /// and when somebody last checked them (DR-048 §11.47.2). Null when
  /// nobody has said, which is every device until somebody does.
  ///
  /// ON THE DEVICE, NOT A PORT. A managed switch has one management address
  /// and forty-eight ports, so an address hung off a port is a fact filed
  /// under an arbitrary one of them. `Port.network` keeps what is genuinely
  /// per-port: VLAN membership, `portRole`, and the address of a device
  /// that really has more than one.
  ///
  /// ITS `mac` IS NOT THE DEVICE'S MAC. That is [macAddressPrimary], the
  /// one home DR-226 §11.225.4 gave it; nothing writes `network.mac` on a
  /// device, so the fact cannot live in two places.
  NetworkConfig? network;
  DeviceOverrides overrides;

  /// Reserve allocation (AC-006).
  int designatorWatermark;
  Uuid? structureBodyId;
  Rgb? colorOverride;
  EntityMeta meta;

  // No localTemplate, no zOrder, no cost/supplier — deliberately absent.
}
