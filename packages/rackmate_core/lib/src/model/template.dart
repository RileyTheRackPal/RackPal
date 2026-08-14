import 'package:meta/meta.dart';
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
    this.submittedBy,
    this.derivedFrom,
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

  /// Who submitted this template to the community catalog (DR-033).
  ///
  /// **Written on submission and never read by the application.** null means
  /// this template has not been submitted, and serialises as an **absent key**
  /// rather than an explicit null (G4, CR-114).
  ///
  /// The field ships ahead of the v1.1 surface that writes it, because this
  /// class has no `unknown` passthrough: a credit written by a build that knew
  /// about it would otherwise be **silently dropped** by one that did not, the
  /// first time that build re-saved the file (canon §11.32.8, DR-019
  /// §11.18.2(5)).
  SubmissionCredit? submittedBy;

  /// The template this one was forked from, or null when it is original
  /// (CR-062, DR-015 §11.15.3, board #196).
  ///
  /// **Written once, by Duplicate, and never again.** Editing a fork does
  /// not touch it: the whole point is to remember where the copy came
  /// from so that a later correction to the SOURCE can be surfaced
  /// passively. Re-pointing it at the source's newer version is the one
  /// mutation that would make CR-062's badge permanently silent.
  ///
  /// null means ORIGINAL, and serialises as an **absent key** rather than
  /// an explicit null (G4, CR-114). That is not the same as "forked from
  /// something we cannot find": a fork whose source is missing from this
  /// installation still carries a [TemplateOrigin], and the staleness
  /// question about it answers UNKNOWN rather than no.
  ///
  /// **It lives on the body rather than beside `TemplateSnapshot.version`
  /// for `submittedBy`'s reason, which is a file-layout fact.** The
  /// `.rmdx` worked example in docs/06 §7.3 writes it at the top level
  /// beside `templateId`, and a `.rmdx` has no snapshot to hang it on —
  /// the whole file IS one template. The codec flattens that layout onto
  /// this class exactly as it does `identity.`/`physical.`/`power.`
  /// (CR-053).
  TemplateOrigin? derivedFrom;
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

/// [ports] in FIXED_ORDER (docs/05 §3): the template's declared `order`,
/// tie-broken by `key`.
///
/// THE ONE SPELLING OF THE DECLARED PORT ORDER. This comparator was written
/// five times, byte for byte: `derived/connect_rules.dart`,
/// `derived/connect_target.dart`, `derived/port_set_resolution.dart`,
/// `commands/multi_draw.dart` and `draw/scene/schematic_scene.dart`.
/// `connect_target.dart` even carried a doc comment calling its copy
/// "IDENTICAL to `resolvePortSet`'s", and named the exact failure: "two
/// orderings of the same list is how a pin ends up with one number on the
/// schedule and a different one in the set that wires it". Naming the
/// coupling in prose is not the same as removing it.
///
/// The `key` tiebreak is what makes the order TOTAL, and it is not
/// decoration: `order` is a `FracIndex` compared as a raw string
/// (`catalog/catalog_ports.dart` says so), nothing enforces its uniqueness
/// within a body, and `List.sort` is not stable. Two ports sharing an
/// `order` would otherwise rank by whatever sequence the decoder happened
/// to produce, and a port's rank becomes its designator.
///
/// Returns a new list; [ports] is not mutated. Callers that need a subset
/// filter first, which is why this takes an `Iterable` rather than a body.
List<PortDef> portsInDeclaredOrder(Iterable<PortDef> ports) =>
    ports.toList()..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
    });

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

/// Who filed the pull request that proposed this template to the community
/// catalog (DR-033, canon §11.32).
///
/// **A credit, not a signature.** The application never reads this to decide
/// anything, it authenticates nothing, and anybody may write anything into it.
/// The only place the claim is tested is the pull request itself, where GitHub
/// has already established who is speaking. AC-042 deleted signatures and
/// `provenance`/`derivedFrom` chains and this does not bring them back.
///
/// **Two fields because they are two facts** (the discipline DR-026 §11.25.1
/// applied to `Pathway.designator`). A GitHub login is renameable *and* a
/// freed login is claimable by somebody else, so [handle] alone can come to
/// credit a different person years later with nothing in the file having
/// changed. [userId] never changes and is unreadable; [handle] is readable and
/// may drift. Deriving either from the other is the version of this that is
/// wrong in a way nobody notices for two years.
///
/// `@immutable` is load-bearing rather than decorative: this is the only
/// value type in this file that defines `==`, and the lint that demands the
/// annotation is right to, because a mutable class with value equality is a
/// key that changes under the map holding it. Every other field on
/// [TemplateBody] is plain-mutable pending the AC-013 retrofit; this one is
/// not, and never becomes so.
@immutable
final class SubmissionCredit {
  const SubmissionCredit({required this.handle, required this.userId});

  /// The GitHub login as it read at submission time. Display only.
  final String handle;

  /// The GitHub numeric user id. Stable across renames; the real identity.
  final int userId;

  @override
  bool operator ==(Object other) =>
      other is SubmissionCredit &&
      other.handle == handle &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(handle, userId);
}

/// The template version a fork was taken from (CR-062, board #196).
///
/// **A join, not a chain, and the distinction is what makes it v1.**
/// AC-042 deleted the `signature` field and the CRYPTOGRAPHIC provenance
/// chain and deliberately kept `contentHash`; DR-015 §11.15.3 separates
/// the two halves that ruling argued as one. This type is on the kept
/// side: one hop back to the source a Duplicate was taken from, resolved
/// by lookup and trusted no further than any other field in the file.
/// Nothing walks it transitively, nothing verifies it, and a fork whose
/// source is unknown to this installation is UNKNOWN rather than
/// up-to-date (G4). Anyone reading AC-042 alone concludes the opposite,
/// which is why board #174 is its own task.
///
/// **NOT a [TemplateRef], deliberately.** A ref carries `contentHash`
/// because it must resolve to an embedded snapshot and prove it got the
/// right one (CR-054). This resolves to nothing in particular: the source
/// may be a catalog archetype this machine has never seen, or a library
/// template the user deleted years ago, and both are ordinary. Giving it
/// a hash would put an integrity check on a link that has no integrity to
/// check, which is the apparatus AC-042 cut.
///
/// [version] is a monotonic int for CR-050's reason: a semver whose
/// components are computed adds a vocabulary without adding a capability.
@immutable
final class TemplateOrigin {
  const TemplateOrigin({required this.templateId, required this.version});

  /// The source template's stable id.
  final TemplateId templateId;

  /// The source template's version AT THE MOMENT OF THE FORK. It is a
  /// snapshot of what was copied, never updated afterwards — updating it
  /// is precisely what would silence CR-062's badge.
  final int version;

  @override
  bool operator ==(Object other) =>
      other is TemplateOrigin &&
      other.templateId == templateId &&
      other.version == version;

  @override
  int get hashCode => Object.hash(templateId, version);

  @override
  String toString() => 'TemplateOrigin(${templateId.v}@$version)';
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
