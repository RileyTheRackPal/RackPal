import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';
import 'package:rackmate_core/src/units/rgb.dart';

// The template layer (docs/02-data-model.md §4.4). Physical facts live
// here, on immutable, content-addressed, versioned snapshots embedded in
// the file; project facts live on `DeviceInstance` (CR-054).

// --- Occupancy / mounting -------------------------------------------------

/// front|rear|both|zeroUVertical|none.
enum OccupancySide { front, rear, both, zeroUVertical, none }

/// rackEars|shelf|zeroU|sideMount|rearRail|furniture|hosted|notInRack.
enum MountMethod {
  rackEars,
  shelf,
  zeroU,
  sideMount,
  rearRail,
  furniture,
  hosted,
  notInRack,
}

/// How much lateral space a device occupies, independent of `RackWidthClass`
/// (which describes the *rack's* width standard, in rack.dart).
///
/// M0 MINIMAL SHAPE: docs/02-data-model.md declares only
/// `WidthClass widthClass` with no enumerated values in its own comment;
/// the value set below is transcribed from
/// docs/research/design-data-model.md line 385
/// (`full | half | third | quarter | customWidth`).
enum WidthClass { full, half, third, quarter, customWidth }

/// passive|lowHeat|highHeat|activeCooled.
///
/// M0 MINIMAL SHAPE: docs/02-data-model.md's worked JSON (§6.2) uses
/// `lowHeat`/`highHeat`/`passive` but the entity spec itself does not
/// enumerate the type; the fourth value is transcribed from
/// docs/research/design-data-model.md line 396.
enum ThermalClass { passive, lowHeat, highHeat, activeCooled }

// --- Port vocabulary -------------------------------------------------------

/// source|sink|bidirectional|busNode|passive (CR-060).
enum PortDirection { source, sink, bidirectional, busNode, passive }

/// Audio/video return channel a port declares — ARC or eARC.
///
/// M0 MINIMAL SHAPE / naming-drift note: the entity spec declares only
/// `ReturnChannel? returnChannel` with the parenthetical "ARC / eARC",
/// which this package's governing instructions direct to model as a
/// two-value enum. The annotated JSON worked example in
/// docs/02-data-model.md §6.2 instead shows `returnChannel` as an object
/// (`{direction, enabled, signalFamily}`) — a cross-document shape
/// inconsistency; the enum reading is used here per direct instruction,
/// noted rather than silently resolved.
enum ReturnChannel { arc, eArc }

/// A port's own topology, distinct from `NetTopologyKind` (net.dart), which
/// describes the *net* a service belongs to.
///
/// M0 MINIMAL SHAPE: not enumerated in docs/02-data-model.md itself;
/// transcribed from docs/research/design-data-model.md line 462
/// (`p2p | multidrop | star`).
enum PortTopology { p2p, multidrop, star }

/// male|female|genderless ONLY (CR-059).
enum Gender { male, female, genderless }

/// Which side of the panel a port/bank symbol draws on. left|right|top|bottom.
enum SymbolSide { left, right, top, bottom }

/// componentVideo|stereoPair|speakerPair|balancedPair (CR-055).
enum SetKind { componentVideo, stereoPair, speakerPair, balancedPair }

/// mic|lineUnbal|lineBal|phono|speaker.
///
/// M0 MINIMAL SHAPE: not enumerated in docs/02-data-model.md itself;
/// transcribed from docs/research/design-data-model.md line 474.
enum AudioLevel { mic, lineUnbal, lineBal, phono, speaker }

/// Which physical terminal a port is — on the TERMINAL, so a wiring typo
/// that inverts polarity is inexpressible rather than silently wrong
/// (AC-030).
///
/// M0 MINIMAL SHAPE: not enumerated in docs/02-data-model.md itself;
/// transcribed from docs/research/design-data-model.md line 477
/// (`positive | negative | none`).
enum Polarity { positive, negative, none }

/// C14|C20|NEMA_5_15P|hardwired|wallWart.
///
/// M0 MINIMAL SHAPE: not enumerated in docs/02-data-model.md itself
/// (only used via the worked JSON example's `"inletPlug": "C14"`);
/// transcribed from docs/research/design-data-model.md line 433.
enum PlugType { c14, c20, nema515p, hardwired, wallWart }

/// Where a port sits on the device's panel face.
///
/// Deliberately a value class, not an enum, despite this package's
/// governing instructions grouping `PanelPosition` with the enum batch:
/// docs/02-data-model.md gives no value list for it at all (unlike
/// `Gender`, `SymbolSide`, etc.), and the only concrete shape in the
/// corpus — docs/research/design-data-model.md line 468,
/// `{ruOffset:int, xTwelfth:int, xFineNm:Len, yFineNm:Len}` — is
/// inherently positional, which an enum cannot express. Judgement call,
/// noted per this package's drift-handling instructions.
///
/// M0 MINIMAL SHAPE: see citation above; docs/02-data-model.md §4.4 does
/// not define this type itself.
final class PanelPosition {
  const PanelPosition({
    required this.ruOffset,
    required this.xTwelfth,
    required this.xFineNm,
    required this.yFineNm,
  });

  final int ruOffset;
  final int xTwelfth;
  final Len xFineNm;
  final Len yFineNm;
}

// --- Placeholder value types (honesty policy) ------------------------------
//
// PoeSpec, SfpFormFactor, FiberMode, BusCapability, SerialSpec and
// PortPowerSpec are referenced by PortDef but none is given a formal type
// definition in docs/02-data-model.md §4.4 itself. Shapes below are
// assembled from the worked examples elsewhere in the corpus (cited per
// type) and are deliberately minimal — a later milestone owns the real
// spec for these subsystems.

/// pse|pd|none.
enum PoeRole { pse, pd, none }

/// af|at|bt (802.3bt Type 3 / Type 4).
enum PoeStandard { af, at, btType3, btType4 }

/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.4.
/// Fields transcribed from docs/01-domain.md §7.5
/// (`PoeSpec{role, standard, type, class, watts}`) and the worked port
/// example in docs/02-data-model.md §6.2.
final class PoeSpec {
  PoeSpec({this.role, this.standard, this.type, this.poeClass, this.watts});

  PoeRole? role;
  PoeStandard? standard;

  /// IEEE 802.3 PoE type number (1-4).
  int? type;

  /// PoE class number (0-8). Named `poeClass` because `class` is a
  /// reserved word in Dart.
  int? poeClass;
  int? watts;
}

/// sfp|sfp+|sfp28.
///
/// M0 MINIMAL SHAPE: transcribed from docs/catalog/seed-devices.md's
/// authoring shorthand (`[sfp] [sfp+] [sfp28]`); no formal type
/// definition exists in docs/02-data-model.md.
enum SfpFormFactor { sfp, sfpPlus, sfp28 }

/// singleMode|multiMode.
///
/// M0 MINIMAL SHAPE: docs/catalog/seed-devices.md ties `fiberMode` to
/// specific fibre grades (OM3/OM4/OS2), but those are `MediaTypeDef`
/// concerns; the mode itself is the standard binary split.
enum FiberMode { singleMode, multiMode }

/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.4.
/// Fields transcribed from docs/research/design-data-model.md line 494
/// (`{protocol, supportsTermination, unitLoads, addressable,
/// maxTapWatts}`); no worked JSON example exists for this type.
final class BusCapability {
  BusCapability({
    this.protocol,
    this.supportsTermination,
    this.unitLoads,
    this.addressable,
    this.maxTapWatts,
  });

  /// e.g. "rs485" | "dmx512" | "cbus" — value set not yet specified.
  String? protocol;
  bool? supportsTermination;
  int? unitLoads;
  bool? addressable;
  int? maxTapWatts;
}

/// DCE|DTE.
enum SerialRole { dce, dte }

/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.4.
/// Fields transcribed from the worked port example in
/// docs/02-data-model.md §6.2
/// (`{baud, dataBits, flowControl, parity, role, stopBits}`).
final class SerialSpec {
  SerialSpec({
    this.baud,
    this.dataBits,
    this.stopBits,
    this.parity,
    this.flowControl,
    this.role,
  });

  int? baud;
  int? dataBits;
  int? stopBits;

  /// e.g. "none" | "even" | "odd" — value set not yet specified.
  String? parity;

  /// e.g. "none" | "rtsCts" | "xonXoff" — value set not yet specified.
  String? flowControl;
  SerialRole? role;
}

/// inlet|outlet.
enum PortPowerRole { inlet, outlet }

/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.4.
/// Fields transcribed from the worked port example in
/// docs/02-data-model.md §6.2 (`{drawWatts, maxAmps, role, volts}`).
final class PortPowerSpec {
  PortPowerSpec({this.role, this.volts, this.drawWatts, this.maxAmps});

  PortPowerRole? role;
  int? volts;
  int? drawWatts;
  int? maxAmps;
}

// --- The template layer proper ---------------------------------------------

/// An immutable, content-addressed, versioned snapshot of a device's
/// physical facts, embedded in the file. Keyed on the document by
/// `"$templateId@$version"`.
final class TemplateSnapshot {
  const TemplateSnapshot({
    required this.templateId,
    required this.version,
    required this.contentHash,
    required this.body,
    required this.capturedAt,
  });

  final TemplateId templateId;

  /// Monotonic int, NOT semver (CR-050).
  final int version;

  /// sha256; a mismatch is a warning and a badge, never a load failure
  /// (AC-042).
  final String contentHash;
  final TemplateBody body;
  final DateTime capturedAt;
}

/// What a `DeviceInstance` carries to resolve its embedded snapshot.
/// ALWAYS resolves to one (CR-054).
final class TemplateRef {
  const TemplateRef({
    required this.templateId,
    required this.version,
    required this.contentHash,
  });

  final TemplateId templateId;
  final int version;
  final String contentHash;
}

/// The physical/electrical facts a device template carries. Mutated only
/// through the (future) Device Builder's own undo stack — never through a
/// document `Command` — so it is not part of this package's AC-013
/// scoping pass.
final class TemplateBody {
  TemplateBody({
    required this.manufacturer,
    required this.model,
    required this.displayName,
    this.description = '',
    this.category = '',
    this.typePrefix,
    List<String>? tags,
    this.frontU = 0,
    this.rearU = 0,
    this.side = OccupancySide.none,
    this.mountMethod = MountMethod.notInRack,
    List<MountMethod>? alternateMountMethods,
    this.widthClass = WidthClass.full,
    this.nominalSpanTwelfths = 12,
    this.customPanelWidth,
    this.bodyDepth,
    this.connectorProjection,
    this.chassisWidth = const Len(432_000_000),
    this.weight,
    this.maxUnsupportedMass,
    this.requiresClearanceAboveU = 0,
    this.requiresClearanceBelowU = 0,
    this.thermalClass = ThermalClass.passive,
    this.isContainer = false,
    this.containerWeightCapacity,
    this.containerUsableDepth,
    this.containerUsableWidth,
    this.containerVented = false,
    this.isPassthrough = false,
    List<PassthroughPairDef>? passthroughPairs,
    PowerProfile? power,
    List<PortDef>? ports,
    List<BankDef>? banks,
    List<PortSetDef>? portSets,
    this.accentColor,
    List<PanelGraphic>? panelGraphics,
  }) : tags = tags ?? [],
       alternateMountMethods = alternateMountMethods ?? [],
       passthroughPairs = passthroughPairs ?? [],
       power = power ?? PowerProfile(),
       ports = ports ?? [],
       banks = banks ?? [],
       portSets = portSets ?? [],
       panelGraphics = panelGraphics ?? [];

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart. In practice a `TemplateBody` is
  // edited by the Device Builder's own undo stack (docs/03-architecture.md
  // §5.6), not the document command set, so none of these are expected to
  // ever join the @internal-scoped set.
  String manufacturer;
  String model;
  String displayName;
  String description;
  String category;

  /// "MTX" — seeds the designator format.
  String? typePrefix;
  List<String> tags;

  // Occupancy — a struct, never a scalar (CR-036).
  int frontU;
  int rearU;
  OccupancySide side;
  MountMethod mountMethod;
  List<MountMethod> alternateMountMethods;
  WidthClass widthClass;
  int nominalSpanTwelfths;
  Len? customPanelWidth;

  /// null means unknown, never estimated (G4, CR-114).
  Len? bodyDepth;

  /// DERIVED from the deepest rear connector, not `bodyDepth + 75 mm`
  /// (AC-022/M7).
  Len? connectorProjection;

  /// Default 432 mm for full width — NOT 482.6 (AC-032).
  Len chassisWidth;

  /// null means unknown, never estimated (G4, CR-114).
  Mass? weight;

  /// Default ~7 kg for `rackEars` in practice; feeds `RCK-013` (AC-028).
  /// Not defaulted here — the ~7 kg figure is mount-method-conditional,
  /// a Device Builder concern, not a blanket class default.
  Mass? maxUnsupportedMass;

  int requiresClearanceAboveU;
  int requiresClearanceBelowU;
  ThermalClass thermalClass;

  bool isContainer;
  Mass? containerWeightCapacity;
  Len? containerUsableDepth;
  Len? containerUsableWidth;
  bool containerVented;

  bool isPassthrough;
  List<PassthroughPairDef> passthroughPairs;

  PowerProfile power;
  List<PortDef> ports;

  /// Presentation grouping (CR-055).
  List<BankDef> banks;

  /// Electrical grouping (CR-055).
  List<PortSetDef> portSets;

  Rgb? accentColor;
  List<PanelGraphic> panelGraphics;
}

/// M0 MINIMAL SHAPE: docs/02-data-model.md declares `PowerProfile` with a
/// full field list but no accompanying constructor or default policy;
/// defaults chosen below are the obviously-safe ones (unknown numeric
/// facts stay null; booleans default false) and are not a claim about a
/// real device's typical shape.
///
/// ─────────────────────────────────────────────────────────────────────────
/// DRAW IS WHAT COMES IN. CAPACITY IS WHAT GOES OUT. THEY ARE NEVER THE
/// SAME FIELD.
/// ─────────────────────────────────────────────────────────────────────────
/// [typicalWatts] and [apparentVA] are what this device pulls THROUGH ITS
/// OWN INLET, and every rollup in `derived/` sums them as connected load.
/// [outputCapacityVA] and [outputCapacityWatts] are what it can DELIVER to
/// the gear plugged into it, and nothing sums them at all.
///
/// The distinction is load-bearing because the gear behind a UPS, a PDU or
/// a conditioner is already in the document with its own draw. Authoring a
/// through-rating as a draw counts that whole downstream load a SECOND
/// time — the P03 UPS template once carried `apparentVA: 3000` (its
/// nameplate output) and made `whole_house` print 5440 VA and 15979 BTU/hr
/// for a rack drawing 2490 VA and 6920 BTU/hr, on the three sheets an
/// integrator sizes a circuit and a fan from.
final class PowerProfile {
  PowerProfile({
    this.nameplateWatts,
    this.typicalWatts,
    this.standbyWatts,
    this.nominalVolts,
    this.apparentVA,
    this.powerFactor,
    this.isContinuousLoad = false,
    this.outletsProvided,
    this.outletsConsumed,
    this.outputCapacityVA,
    this.outputCapacityWatts,
    this.inletPlug,
    this.poeBudgetWatts,
    this.btuPerHourOverride,
  });

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013); see the note on TemplateBody above — edited via
  // the Device Builder, not the document command set.

  /// UL thermal rating; advisory second line only. An INPUT figure, like
  /// every other watt field here except [outputCapacityWatts].
  int? nameplateWatts;

  /// What this device DRAWS, and the number circuit loading uses. NEVER
  /// auto-derived from nameplate (AC-039) and never the rating of what it
  /// can supply — see [outputCapacityWatts] and the class doc.
  int? typicalWatts;
  int? standbyWatts;
  int? nominalVolts;

  /// Circuit loading is computed in VA (CR-056, AC-020). What this device
  /// DRAWS; see [outputCapacityVA] and the class doc.
  int? apparentVA;

  /// Permille. 650 for a linear-supply amp.
  int? powerFactor;
  bool isContinuousLoad;

  /// How many outlets this device PROVIDES, or null when the template was
  /// never authored for outlets at all.
  ///
  /// NULLABLE, and the nullability is the point (CR-114, G4). These two
  /// shipped as non-nullable `int`s defaulting to 0, which structurally
  /// cannot tell "this device provides no outlets" from "nobody has told
  /// us how many outlets this device provides". `derived/totals.dart`
  /// therefore counted every unauthored template as a KNOWN zero, and the
  /// chip strip rendered a confident `outlets 0/0` — with no unknown
  /// superscript — on the app's own default document, which is the exact
  /// fabrication the chip strip exists to prevent. docs/06-device-builder.md
  /// already specified these as "all nullable `int` and all optional";
  /// the implementation had followed docs/02-data-model.md's terser
  /// `int outletsProvided, outletsConsumed;` line instead.
  ///
  /// A seeded template that genuinely has no outlets states `0` EXPLICITLY
  /// (see `catalog_*.dart`) — that is a measurement, and it stays one.
  int? outletsProvided;

  /// How many outlets this device CONSUMES, or null when unauthored. See
  /// [outletsProvided]; a redundant-PSU switch authors 2 (AC-020).
  int? outletsConsumed;

  /// The rated OUTPUT this device can DELIVER — a UPS's "3000 VA", a
  /// conditioner's branch rating. A CAPACITY, never a draw.
  ///
  /// `resolveDeviceLoads` does not read it and no rollup sums it, which is
  /// the whole reason it is a separate field: CR-056's "UPS capacity is
  /// checked VA against VA" needs a machine-readable rating, and the only
  /// place that rating used to live was [apparentVA], where every rollup
  /// in the project added it to the connected load. See the class doc.
  int? outputCapacityVA;

  /// The same rating in real power, when the label states both
  /// ("3000 VA / 2700 W"). Kept so the W figure on the nameplate is not
  /// lost, and kept SEPARATE so it can never be mistaken for
  /// [typicalWatts] — which is what drives the BTU/hr on the elevations.
  int? outputCapacityWatts;
  PlugType? inletPlug;

  /// `NET-001` depends on it (CR-056).
  int? poeBudgetWatts;

  /// Else `typicalWatts x kBtuPerWattHour` (CR-005).
  int? btuPerHourOverride;
}

/// One port on a template. `key` is the stable, author-assigned migration
/// join (CR-051) — never a UUID, because a UUID cannot express "this port
/// was renamed".
final class PortDef {
  PortDef({
    required this.key,
    required this.label,
    required this.connector,
    required this.signalFamily,
    required this.face,
    required this.position,
    required this.order,
    List<PortKey>? renamedFrom,
    this.designatorHint,
    List<SignalFamilyId>? carriedProtocols,
    List<SignalFamilyId>? acceptedFamilies,
    this.direction = PortDirection.bidirectional,
    this.returnChannel,
    this.topology = PortTopology.p2p,
    this.maxConnections = 1,
    this.gender = Gender.genderless,
    this.pinoutVariant,
    this.conductorCount,
    this.impedanceOhms,
    this.level,
    this.balanced,
    this.phantomPowerCapable,
    this.polarity,
    this.nominalVoltage,
    this.maxCurrentMa,
    this.bankKey,
    this.setKey,
    this.setRole,
    this.channelIndex,
    this.poe,
    this.linkSpeedMbps,
    this.sfp,
    this.fiberMode,
    this.wavelengthNm,
    this.bus,
    this.serial,
    this.power,
    this.notes,
  }) : renamedFrom = renamedFrom ?? [],
       carriedProtocols = carriedProtocols ?? [],
       acceptedFamilies = acceptedFamilies ?? [];

  final PortKey key;

  /// What a UUID cannot express: that this port was renamed.
  final List<PortKey> renamedFrom;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013); see the note on TemplateBody above.
  String label;
  String? designatorHint;

  /// Three orthogonal axes — never one enum.
  ConnectorTypeId connector;
  SignalFamilyId signalFamily;
  List<SignalFamilyId> carriedProtocols;
  List<SignalFamilyId> acceptedFamilies;

  PortDirection direction;
  ReturnChannel? returnChannel;
  PortTopology topology;
  int maxConnections;

  Gender gender;
  Face face;
  PanelPosition position;

  /// The IR emitter/receiver hazard. Must be cited (AC-052).
  String? pinoutVariant;
  int? conductorCount;

  int? impedanceOhms;
  AudioLevel? level;
  bool? balanced;
  bool? phantomPowerCapable;

  /// On the TERMINAL, so a typo is inexpressible (AC-030).
  Polarity? polarity;
  int? nominalVoltage;
  int? maxCurrentMa;

  /// -> `BankDef` (presentation).
  String? bankKey;

  /// -> `PortSetDef` (electrical).
  String? setKey;
  String? setRole;
  int? channelIndex;

  PoeSpec? poe;
  int? linkSpeedMbps;
  SfpFormFactor? sfp;
  FiberMode? fiberMode;
  int? wavelengthNm;
  BusCapability? bus;
  SerialSpec? serial;
  PortPowerSpec? power;

  FracIndex order;
  String? notes;
}

/// PRESENTATION grouping. Drives symbol edges, brackets, collapse, and
/// auto rear-panel layout (CR-055).
final class BankDef {
  BankDef({
    required this.key,
    required this.label,
    required this.abbr,
    required this.order,
    this.symbolSide = SymbolSide.left,
    this.collapseInSymbol = true,
  });

  final String key;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013); see the note on TemplateBody above.
  String label;
  String abbr;
  SymbolSide symbolSide;

  /// Whether this bank MAY collapse in the symbol. `kBankCollapseThreshold`
  /// (8) decides whether it actually does — this flag is the per-bank
  /// opt-OUT for a bank that must always show every pin.
  ///
  /// **DEFAULTS TO `true`, and it used to default to `false`** (board 96-L).
  /// docs/06 §6 rules that banks over 8 ports collapse to a vector pin with
  /// a count badge **by default** — *"which is what keeps a 48-port switch
  /// legible"* — so a `false` default contradicted the specification it was
  /// implementing. It went unnoticed because bank collapse is still on
  /// `symbol_layer.dart`'s deferral list (CR-103) and **nothing reads this
  /// field yet**, so 22 seeded banks above the threshold had quietly
  /// accumulated the value that means *never collapse*: N01's 48-port
  /// access bank, N03's two 24s, P01's 24 outlets, V03's three 16s.
  /// Whoever implements CR-103 would have had to choose between honouring
  /// the flag (defeating the feature) and honouring the threshold (making
  /// 22 stored values a lie). Fixed while the field was still inert and the
  /// fix was one line rather than a migration.
  bool collapseInSymbol;
  FracIndex order;
}

/// ELECTRICAL grouping — Y/Pb/Pr, L/R, +/- (CR-055).
final class PortSetDef {
  PortSetDef({
    required this.key,
    required this.label,
    required this.kind,
    this.atomicConnect = true,
  });

  final String key;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013); see the note on TemplateBody above.
  String label;
  SetKind kind;

  /// One gesture connects the whole set.
  bool atomicConnect;
}

/// Patch-panel front <-> rear passthrough (CR-057).
final class PassthroughPairDef {
  const PassthroughPairDef({
    required this.frontKey,
    required this.rearKey,
    required this.sameNet,
  });

  final PortKey frontKey;
  final PortKey rearKey;
  final bool sameNet;
}

/// A vector graphic reference on a device's faceplate. No bitmap
/// `frontImage`/`rearImage` exists in v1 (AC-057).
///
/// M0 MINIMAL SHAPE: docs/02-data-model.md references `PanelGraphic` by
/// name only ("no frontImage/rearImage in v1"); no field list is given.
/// `id`/`kind` plus an opaque geometry reference is the minimal shape
/// that lets a device carry more than one graphic.
final class PanelGraphic {
  PanelGraphic({required this.id, required this.kind, this.geometryRef});

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013); see the note on TemplateBody above.
  String id;

  /// e.g. "screwHole" | "vent" | "logo" | "outline" — value set not yet
  /// specified.
  String kind;

  /// Opaque reference into vector geometry data; shape not yet decided.
  String? geometryRef;
}
