// The Device Builder's command set over a `TemplateBody` (CR-106,
// docs/03-architecture.md §5.6), and the first `Command` in this package
// whose aggregate is not a `RackDocument`.
//
// WHAT THIS FILE IS NOT. It is not the builder's form and it is not the
// port grid; those are M4-D (#175) and M4-E (#176) and they will add
// their own commands here. This file exists because M4-A/4 builds the
// builder's undo STACK, and a stack with no command type on it is a type
// parameter rather than a mechanism: nothing could be pushed, so nothing
// could be tested, and the first real command would be free to invent a
// second way of doing this. The `TemplateField` table below therefore
// starts at the metadata fields M4-D's form is about and stops there.
//
// NO CALLER YET, STATED RATHER THAN IMPLIED. Nothing in `rackpal_ui` or
// `apps/rackpal` reaches this today; M4-D is what puts a text box in
// front of it. That is the shape `a modelled field is not a reachable
// one` warns about, so it is named here instead of being discovered
// later: the reachability this file is waiting on is a whole editor
// window, not a missing wire.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';
import 'package:rackpal_core/src/units/rgb.dart';

/// A typed accessor for one editable property of a [TemplateBody]: how to
/// read it and how to write it.
///
/// The document side's equivalent is `EntityField`, and this one is
/// deliberately smaller in two ways. It carries no `EntityAccess`,
/// because there is exactly one aggregate here and no map to find it in;
/// and it carries no `EpochMask`, because a `TemplateBody` has no epochs
/// at all (see [SetTemplateFieldCommand.touches]).
final class TemplateField<T> {
  const TemplateField({
    required this.key,
    required this.get,
    required this.set,
  });

  /// A stable identifier, unique within [TemplateBodyField.all] (asserted
  /// by the unit test), because it is half of
  /// [SetTemplateFieldCommand.mergeKey] and therefore what makes
  /// coalescing per-property: typing a manufacturer collapses into one
  /// undo entry, and then typing a model does not join it.
  final String key;

  final T Function(TemplateBody body) get;
  final void Function(TemplateBody body, T value) set;

  @override
  String toString() => 'TemplateField($key)';
}

/// The `TemplateBody` metadata fields the builder's form edits.
///
/// **Five of the body's ~50 fields, on purpose.** These are the ones
/// M4-D's metadata form is made of; the occupancy, power, thermal and
/// port fields arrive with the sections that edit them, each with the
/// validation that section owns. Adding all fifty now would be fifty
/// entries nothing reads, which is the state this package already found
/// `NetworkConfig` in.
abstract final class TemplateBodyField {
  /// "Extron". Free text, not a registry: the long tail is the whole
  /// reason the builder exists.
  ///
  /// **M4-D's form PRE-FILLS the literal `Generic` (DR-056, canon
  /// §11.55).** The citation sits here rather than only in the corpus
  /// because this is where an implementer stands when the question comes
  /// up. `Generic` is the trade's standard token for *unspecified / by
  /// others* in a manufacturer column, so it is not a fabricated value
  /// under G4 but the industry's own spelling of what `—` means.
  ///
  /// Two consequences follow and are not defects. The unknown rollup
  /// reports **zero** devices missing a manufacturer, because the field
  /// holds a value (§11.55.5). And `_trimToNull` in
  /// `derived/equipment_list.dart` will therefore never see this field
  /// empty in practice, though it stays as the guard for a template
  /// authored before the form existed or edited by hand.
  static const manufacturer = TemplateField<String>(
    key: 'manufacturer',
    get: _getManufacturer,
    set: _setManufacturer,
  );

  /// "DTP CrossPoint 84". **NOT defaulted, unlike [manufacturer]**
  /// (DR-056 §11.55.5): no trade convention was offered for a model
  /// string, and inventing one would be the fabrication the manufacturer
  /// default is careful not to be. An untouched `model` prints `—` and
  /// counts as unknown.
  static const model = TemplateField<String>(
    key: 'model',
    get: _getModel,
    set: _setModel,
  );

  /// What the elevation and the equipment list print.
  static const displayName = TemplateField<String>(
    key: 'displayName',
    get: _getDisplayName,
    set: _setDisplayName,
  );

  /// "MTX" — seeds the designator format, and one of the three fields
  /// M4-D's form requires.
  static const typePrefix = TemplateField<String?>(
    key: 'typePrefix',
    get: _getTypePrefix,
    set: _setTypePrefix,
  );

  /// What the device mostly IS, as one of the eight signal domains
  /// (`#899`, DR-169 §11.168.5).
  ///
  /// **AUTHORED AND NEVER DERIVED.** A census over the 51 seeded
  /// templates found 13 whose ports belong to exactly one domain; the
  /// rest read as mixtures, because nearly everything has a power lead
  /// and a control port. Null is unknown and draws the neutral mark.
  static const primaryDomain = TemplateField<SignalDomainId?>(
    key: 'primaryDomain',
    get: _getPrimaryDomain,
    set: _setPrimaryDomain,
  );

  /// Rack units on the front face. The second of M4-D's three required
  /// fields, and the one a user gets wrong most cheaply: `0` is a
  /// MEASURED zero here (a zero-U device), never an unknown, so this
  /// field is an `int` and not an `int?` (G4 cuts the other way for
  /// occupancy than it does for weight).
  static const frontU = TemplateField<int>(
    key: 'frontU',
    get: _getFrontU,
    set: _setFrontU,
  );

  /// One of `kCatalogCategoryOrder`'s NINE strings, or empty.
  ///
  /// **A string and not an enum**, matching `TemplateBody.category` and
  /// the seeded catalog, which key their grouping on the same constant.
  /// Optional under AC-049, and load-bearing for two other things anyway:
  /// it seeds [typePrefix]'s suggestion, and it selects the default
  /// `DeviceGlyph` when the author has chosen none (DR-059 §11.58.6).
  static const category = TemplateField<String>(
    key: 'category',
    get: _getCategory,
    set: _setCategory,
  );

  /// `hdbaset`, `4k60`, `poe`. Searched over by the library browser
  /// (docs/06 §7.1), which is M4-O's.
  ///
  /// **Its accessors COPY, and that is not defensive style.** `from` on
  /// a `SetTemplateFieldCommand` is whatever `get` returned; handing back
  /// the body's own list would make `from` and the live value the same
  /// object, so `revert` would write the mutated list over itself and
  /// undo would silently do nothing. Every future list-valued field on
  /// this table has the same obligation.
  static const tags = TemplateField<List<String>>(
    key: 'tags',
    get: _getTags,
    set: _setTags,
  );

  // ── docs/06 §3.2, Physical & mounting ────────────────────────────
  //
  // OCCUPANCY IS A STRUCT, NEVER A SCALAR (CR-036). The six fields below
  // are one fact about where a device sits, and the reason they are not
  // a single "height" is that a 2U patch panel is `{front: 2, rear: 2}`,
  // a rear lacing bar is `{front: 0, rear: 1}` and a 0U PDU is
  // `{0, 0, side: zeroUVertical}`. A scalar cannot say any of the three.

  static const rearU = TemplateField<int>(
    key: 'rearU',
    get: _getRearU,
    set: _setRearU,
  );

  static const side = TemplateField<OccupancySide>(
    key: 'side',
    get: _getSide,
    set: _setSide,
  );

  static const mountMethod = TemplateField<MountMethod>(
    key: 'mountMethod',
    get: _getMountMethod,
    set: _setMountMethod,
  );

  /// Half-rack is `widthClass: half` PLUS [nominalSpanTwelfths] (CR-030),
  /// never "0.5 rack width", because 9.5 / 10 / 10.4 / 10.5 in all ship.
  static const widthClass = TemplateField<WidthClass>(
    key: 'widthClass',
    get: _getWidthClass,
    set: _setWidthClass,
  );

  static const nominalSpanTwelfths = TemplateField<int>(
    key: 'nominalSpanTwelfths',
    get: _getNominalSpanTwelfths,
    set: _setNominalSpanTwelfths,
  );

  /// **Unknown, not zero** (G4, CR-114). An untouched depth stays null,
  /// serialises as an absent key, and every rollup that reads it reports
  /// its unknown count rather than fabricating a total.
  static const bodyDepth = TemplateField<Len?>(
    key: 'bodyDepth',
    get: _getBodyDepth,
    set: _setBodyDepth,
  );

  /// Unknown, not zero, for [bodyDepth]'s reason.
  static const weight = TemplateField<Mass?>(
    key: 'weight',
    get: _getWeight,
    set: _setWeight,
  );

  /// **Defaults to 432 mm and NOT 482.6** (AC-032). 482.6 is the PANEL
  /// width including ears; flowing connectors across it draws jacks out
  /// past the rails, on the very view that gets taped inside the rack
  /// door. The default lives on `TemplateBody`'s constructor; this field
  /// is how a user overrides it for a genuinely odd chassis.
  static const chassisWidth = TemplateField<Len>(
    key: 'chassisWidth',
    get: _getChassisWidth,
    set: _setChassisWidth,
  );

  /// Feeds `RCK-013` (AC-028). Unknown until authored.
  static const maxUnsupportedMass = TemplateField<Mass?>(
    key: 'maxUnsupportedMass',
    get: _getMaxUnsupportedMass,
    set: _setMaxUnsupportedMass,
  );

  static const requiresClearanceAboveU = TemplateField<int>(
    key: 'requiresClearanceAboveU',
    get: _getClearanceAbove,
    set: _setClearanceAbove,
  );

  static const requiresClearanceBelowU = TemplateField<int>(
    key: 'requiresClearanceBelowU',
    get: _getClearanceBelow,
    set: _setClearanceBelow,
  );

  static const thermalClass = TemplateField<ThermalClass>(
    key: 'thermalClass',
    get: _getThermalClass,
    set: _setThermalClass,
  );

  /// A patch panel or a wall plate: front and rear ports pair up
  /// (CR-057). The PAIRING itself is M4-J's, in the port grid; this is
  /// the flag that says the device has one at all.
  static const isPassthrough = TemplateField<bool>(
    key: 'isPassthrough',
    get: _getIsPassthrough,
    set: _setIsPassthrough,
  );

  /// A shelf or a drawer: it holds other devices (CR-029).
  static const isContainer = TemplateField<bool>(
    key: 'isContainer',
    get: _getIsContainer,
    set: _setIsContainer,
  );

  // ── docs/06 §3.3, Power & thermal ────────────────────────────────
  //
  // ALL NULLABLE, ALL OPTIONAL, AND `typicalWatts` IS NEVER DERIVED FROM
  // `nameplateWatts` (AC-039, G4). A fabricated number that reaches a
  // circuit-loading calculation is worse than a blank, and this is the
  // single field on the form where a helpful default would do the most
  // damage: it is what the BTU/hr on the elevations is computed from.
  //
  // `outletsProvided` and `outletsConsumed` are absent from this table
  // ON PURPOSE. docs/06 §3.3 makes them READ-ONLY, counted from ports
  // whose family is `power.*`, so a text box for them would let a user
  // author a count that disagrees with the ports beside it. Counting
  // them needs the port grid, which is M4-E.

  static const nameplateWatts = TemplateField<int?>(
    key: 'nameplateWatts',
    get: _getNameplateWatts,
    set: _setNameplateWatts,
  );

  /// **NEVER derived from [nameplateWatts]** (AC-039). See the note above.
  static const typicalWatts = TemplateField<int?>(
    key: 'typicalWatts',
    get: _getTypicalWatts,
    set: _setTypicalWatts,
  );

  static const standbyWatts = TemplateField<int?>(
    key: 'standbyWatts',
    get: _getStandbyWatts,
    set: _setStandbyWatts,
  );

  static const nominalVolts = TemplateField<int?>(
    key: 'nominalVolts',
    get: _getNominalVolts,
    set: _setNominalVolts,
  );

  /// Circuit loading is computed in VA, not watts, because a
  /// linear-supply amplifier at PF 0.65 under-reports current by 35% on
  /// exactly the gear where it matters (CR-056, AC-020).
  static const apparentVA = TemplateField<int?>(
    key: 'apparentVA',
    get: _getApparentVA,
    set: _setApparentVA,
  );

  /// PERMILLE, so 0.65 is `650`. Integer units only (CR-001).
  static const powerFactor = TemplateField<int?>(
    key: 'powerFactor',
    get: _getPowerFactor,
    set: _setPowerFactor,
  );

  static const poeBudgetWatts = TemplateField<int?>(
    key: 'poeBudgetWatts',
    get: _getPoeBudgetWatts,
    set: _setPoeBudgetWatts,
  );

  /// **Exists only for the rare manufacturer figure that disagrees with
  /// the arithmetic** (CR-005). Heat is DERIVED as
  /// `typicalWatts x kBtuPerWattHour` and never stored; this is the
  /// escape hatch, not the field a form should encourage.
  static const btuPerHourOverride = TemplateField<int?>(
    key: 'btuPerHourOverride',
    get: _getBtuOverride,
    set: _setBtuOverride,
  );

  static const isContinuousLoad = TemplateField<bool>(
    key: 'isContinuousLoad',
    get: _getIsContinuousLoad,
    set: _setIsContinuousLoad,
  );

  static const inletPlug = TemplateField<PlugType?>(
    key: 'inletPlug',
    get: _getInletPlug,
    set: _setInletPlug,
  );

  // ── docs/06 §3.4, Appearance ─────────────────────────────────────

  static const accentColor = TemplateField<Rgb?>(
    key: 'accentColor',
    get: _getAccentColor,
    set: _setAccentColor,
  );

  /// Null means INHERIT the category's default, not unknown (DR-059).
  /// Read it through `effectiveGlyph`, never directly.
  static const glyph = TemplateField<DeviceGlyph?>(
    key: 'glyph',
    get: _getGlyph,
    set: _setGlyph,
  );

  /// Every field above, for the uniqueness test and for a future batch
  /// inspector. Order is presentation order, not significance.
  static const all = <TemplateField<Object?>>[
    manufacturer,
    model,
    displayName,
    category,
    typePrefix,
    frontU,
    tags,
    rearU,
    side,
    mountMethod,
    widthClass,
    nominalSpanTwelfths,
    bodyDepth,
    weight,
    chassisWidth,
    maxUnsupportedMass,
    requiresClearanceAboveU,
    requiresClearanceBelowU,
    thermalClass,
    isPassthrough,
    isContainer,
    nameplateWatts,
    typicalWatts,
    standbyWatts,
    nominalVolts,
    apparentVA,
    powerFactor,
    poeBudgetWatts,
    btuPerHourOverride,
    isContinuousLoad,
    inletPlug,
    accentColor,
    glyph,
  ];
}

String _getManufacturer(TemplateBody b) => b.manufacturer;
void _setManufacturer(TemplateBody b, String v) => b.manufacturer = v;

String _getModel(TemplateBody b) => b.model;
void _setModel(TemplateBody b, String v) => b.model = v;

String _getDisplayName(TemplateBody b) => b.displayName;
void _setDisplayName(TemplateBody b, String v) => b.displayName = v;

String? _getTypePrefix(TemplateBody b) => b.typePrefix;
void _setTypePrefix(TemplateBody b, String? v) => b.typePrefix = v;

SignalDomainId? _getPrimaryDomain(TemplateBody b) => b.primaryDomain;
void _setPrimaryDomain(TemplateBody b, SignalDomainId? v) =>
    b.primaryDomain = v;

int _getFrontU(TemplateBody b) => b.frontU;
void _setFrontU(TemplateBody b, int v) => b.frontU = v;

String _getCategory(TemplateBody b) => b.category;
void _setCategory(TemplateBody b, String v) => b.category = v;

// COPIES ON BOTH SIDES. See `TemplateBodyField.tags` for why: sharing the
// list would make a command's `from` alias the value it is meant to
// restore, and undo would appear to run and change nothing.
List<String> _getTags(TemplateBody b) => List<String>.of(b.tags);
void _setTags(TemplateBody b, List<String> v) => b.tags = List<String>.of(v);

int _getRearU(TemplateBody b) => b.rearU;
void _setRearU(TemplateBody b, int v) => b.rearU = v;

OccupancySide _getSide(TemplateBody b) => b.side;
void _setSide(TemplateBody b, OccupancySide v) => b.side = v;

MountMethod _getMountMethod(TemplateBody b) => b.mountMethod;
void _setMountMethod(TemplateBody b, MountMethod v) => b.mountMethod = v;

WidthClass _getWidthClass(TemplateBody b) => b.widthClass;
void _setWidthClass(TemplateBody b, WidthClass v) => b.widthClass = v;

int _getNominalSpanTwelfths(TemplateBody b) => b.nominalSpanTwelfths;
void _setNominalSpanTwelfths(TemplateBody b, int v) =>
    b.nominalSpanTwelfths = v;

Len? _getBodyDepth(TemplateBody b) => b.bodyDepth;
void _setBodyDepth(TemplateBody b, Len? v) => b.bodyDepth = v;

Mass? _getWeight(TemplateBody b) => b.weight;
void _setWeight(TemplateBody b, Mass? v) => b.weight = v;

Len _getChassisWidth(TemplateBody b) => b.chassisWidth;
void _setChassisWidth(TemplateBody b, Len v) => b.chassisWidth = v;

Mass? _getMaxUnsupportedMass(TemplateBody b) => b.maxUnsupportedMass;
void _setMaxUnsupportedMass(TemplateBody b, Mass? v) =>
    b.maxUnsupportedMass = v;

int _getClearanceAbove(TemplateBody b) => b.requiresClearanceAboveU;
void _setClearanceAbove(TemplateBody b, int v) => b.requiresClearanceAboveU = v;

int _getClearanceBelow(TemplateBody b) => b.requiresClearanceBelowU;
void _setClearanceBelow(TemplateBody b, int v) => b.requiresClearanceBelowU = v;

ThermalClass _getThermalClass(TemplateBody b) => b.thermalClass;
void _setThermalClass(TemplateBody b, ThermalClass v) => b.thermalClass = v;

bool _getIsPassthrough(TemplateBody b) => b.isPassthrough;
void _setIsPassthrough(TemplateBody b, bool v) => b.isPassthrough = v;

bool _getIsContainer(TemplateBody b) => b.isContainer;
void _setIsContainer(TemplateBody b, bool v) => b.isContainer = v;

// The power accessors reach THROUGH `body.power`, which is a non-null
// `PowerProfile` the constructor always supplies. No null check is
// needed and none should be added: a body with no profile is not a state
// this model has.
int? _getNameplateWatts(TemplateBody b) => b.power.nameplateWatts;
void _setNameplateWatts(TemplateBody b, int? v) => b.power.nameplateWatts = v;

int? _getTypicalWatts(TemplateBody b) => b.power.typicalWatts;
void _setTypicalWatts(TemplateBody b, int? v) => b.power.typicalWatts = v;

int? _getStandbyWatts(TemplateBody b) => b.power.standbyWatts;
void _setStandbyWatts(TemplateBody b, int? v) => b.power.standbyWatts = v;

int? _getNominalVolts(TemplateBody b) => b.power.nominalVolts;
void _setNominalVolts(TemplateBody b, int? v) => b.power.nominalVolts = v;

int? _getApparentVA(TemplateBody b) => b.power.apparentVA;
void _setApparentVA(TemplateBody b, int? v) => b.power.apparentVA = v;

int? _getPowerFactor(TemplateBody b) => b.power.powerFactor;
void _setPowerFactor(TemplateBody b, int? v) => b.power.powerFactor = v;

int? _getPoeBudgetWatts(TemplateBody b) => b.power.poeBudgetWatts;
void _setPoeBudgetWatts(TemplateBody b, int? v) => b.power.poeBudgetWatts = v;

int? _getBtuOverride(TemplateBody b) => b.power.btuPerHourOverride;
void _setBtuOverride(TemplateBody b, int? v) => b.power.btuPerHourOverride = v;

bool _getIsContinuousLoad(TemplateBody b) => b.power.isContinuousLoad;
void _setIsContinuousLoad(TemplateBody b, bool v) =>
    b.power.isContinuousLoad = v;

PlugType? _getInletPlug(TemplateBody b) => b.power.inletPlug;
void _setInletPlug(TemplateBody b, PlugType? v) => b.power.inletPlug = v;

Rgb? _getAccentColor(TemplateBody b) => b.accentColor;
void _setAccentColor(TemplateBody b, Rgb? v) => b.accentColor = v;

DeviceGlyph? _getGlyph(TemplateBody b) => b.glyph;
void _setGlyph(TemplateBody b, DeviceGlyph? v) => b.glyph = v;

/// Sets one [TemplateField] on the [TemplateBody] a
/// `TemplateEditSession` is editing.
///
/// Simpler than its document sibling by exactly what a `TemplateBody`
/// lacks: no `EntityMeta` to touch and restore, so `revert` is the
/// `from` value written back and nothing else. `MoveDeviceCommand`'s
/// warning about a revision left one higher than it started has no
/// analogue here, because a template body carries no revision.
final class SetTemplateFieldCommand<T> extends Command<TemplateBody> {
  const SetTemplateFieldCommand({
    required this.field,
    required this.from,
    required this.to,
  });

  final TemplateField<T> field;
  final T from;
  final T to;

  @override
  LabelKey get label => LabelKey.setTemplateProperty;

  /// NULL, and not [EpochMask.none]. `none` would assert that this
  /// command dirties no document epoch, which is true but useless; null
  /// says a `TemplateBody` has no epoch model to dirty, which is the
  /// actual fact and the one that stops somebody wiring the builder into
  /// `DocEpochs` (command.dart, `DocEpochs.bump`).
  @override
  EpochMask? get touches => null;

  /// Empty, and honestly so: `affects` hands the DERIVED layer its
  /// invalidation set, the derived layer is keyed on document entities,
  /// and this command touches none of them. A `TemplateBody`'s parts are
  /// keyed by `PortKey` and `BankKey`, which are not `Uuid`s.
  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  /// Per field, so a run of keystrokes in one box is one undo entry and
  /// moving to the next box starts another. No entity id in the key,
  /// unlike `SetEntityPropertyCommand`: there is one body per session.
  @override
  Object? get mergeKey => (SetTemplateFieldCommand, field.key);

  @override
  bool apply(TemplateBody aggregate) {
    field.set(aggregate, to);
    return true;
  }

  @override
  void revert(TemplateBody aggregate) => field.set(aggregate, from);

  @override
  Command<TemplateBody>? mergeWith(Command<TemplateBody> next) {
    if (next is! SetTemplateFieldCommand<T>) return null;
    if (next.field.key != field.key) return null;
    // Spans from where THIS command started to where the next one ended,
    // which is what makes the merged pair one undo step.
    return SetTemplateFieldCommand<T>(field: field, from: from, to: next.to);
  }
}
