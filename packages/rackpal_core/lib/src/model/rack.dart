// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart' show RuNumbering;
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/zero_u_channel.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';

/// eia19|eia23|tenInch|etsi|customWidth.
enum RackWidthClass { eia19, eia23, tenInch, etsi, customWidth }

/// tapped10_32|tapped12_24|squareCageNut|roundClearance|m6.
enum RailType { tapped10_32, tapped12_24, squareCageNut, roundClearance, m6 }

/// floorEnclosure|openFrame4Post|openFrame2Post|wallSwingGate|
/// wallPivotCabinet|wallFixed|credenzaFurniture|portableCase.
enum RackFormFactor {
  floorEnclosure,
  openFrame4Post,
  openFrame2Post,
  wallSwingGate,
  wallPivotCabinet,
  wallFixed,
  credenzaFurniture,
  portableCase,
}

/// left|right.
enum HingeSide { left, right }

/// A physical enclosure/frame that hosts devices on rails, shelves, or 0U
/// channels.
final class Rack {
  Rack({
    required this.id,
    required String name,
    required String designator,
    required int heightU,
    required this.order,
    required this.meta,
    Uuid? locationId,
    PlanPin? planPin,
    RuNumbering ruNumbering = RuNumbering.bottomUpFromOne,
    bool mirrorRearElevation = true,
    RackWidthClass widthClass = RackWidthClass.eia19,
    this.customPanelWidth,
    RailType railType = RailType.tapped10_32,
    this.fullHoleRail = false,
    RackFormFactor formFactor = RackFormFactor.floorEnclosure,
    Len? usableDepth,
    this.overallDepth,
    this.overallWidth,
    this.overallHeight,
    Mass? weightCapacity,
    this.ownWeight,
    bool isSwingFrame = false,
    HingeSide? hingeSide,
    this.hasFrontDoor = false,
    this.hasRearDoor = false,
    this.frontDoorClearance,
    this.rearDoorClearance,
    this.frontRailClearance,
    this.rearRailClearance,
    bool groundBarPresent = false,
    List<ZeroUChannel>? zeroUChannels,
  }) : _name = name,
       _designator = designator,
       _heightU = heightU,
       _locationId = locationId,
       _planPin = planPin,
       _ruNumbering = ruNumbering,
       _mirrorRearElevation = mirrorRearElevation,
       _widthClass = widthClass,
       _railType = railType,
       _formFactor = formFactor,
       _usableDepth = usableDepth,
       _weightCapacity = weightCapacity,
       _isSwingFrame = isSwingFrame,
       _hingeSide = hingeSide,
       _groundBarPresent = groundBarPresent,
       zeroUChannels = zeroUChannels ?? [];

  final Uuid id;

  String _name;
  String get name => _name;
  @internal
  set name(String v) => _name = v;

  /// "RK-1" — the ONLY rack identifier (CR-040).
  String _designator;
  String get designator => _designator;
  @internal
  set designator(String v) => _designator = v;

  Uuid? _locationId;
  Uuid? get locationId => _locationId;
  @internal
  set locationId(Uuid? v) => _locationId = v;

  /// Where this rack sits on a floorplan (docs/15 §3.4).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// NOT OPTIONAL TO THE DESIGN, WHATEVER THE `?` SAYS
  /// ═══════════════════════════════════════════════════════════════════
  /// A home run is measured FROM THE RACK. Without this pin, no length on
  /// that plan is derivable at all, and the product must say so rather
  /// than measure from the corner of the image, which would produce a
  /// number that looks like a cable length and is a property of how the
  /// architect cropped the page. `PLN-003` is the advisory that says it.
  ///
  /// Nullable because a rack that has not been pinned yet is the ordinary
  /// state of every project before somebody opens the Plan view, and G4
  /// spells that absence as null rather than as a guess.
  PlanPin? _planPin;
  PlanPin? get planPin => _planPin;
  @internal
  set planPin(PlanPin? v) => _planPin = v;

  /// 1..60, asserted. Advisory above 50 (CR-038).
  ///
  /// The assert lives on the SETTER, not the constructor: the setter is
  /// the command path, where an out-of-range value is a caller bug worth
  /// crashing a debug build over. The constructor is also the DECODE path
  /// (`json_codec.dart`'s `_decodeRack`), and turning a hostile or
  /// corrupt file into a debug-mode crash there would be a worse failure
  /// than loading it — file-level validation belongs to the codec, which
  /// is a separate concern from this invariant.
  int _heightU;
  int get heightU => _heightU;
  @internal
  set heightU(int v) {
    assert(v >= 1 && v <= 60, 'Rack.heightU must be in [1, 60] (CR-038)');
    _heightU = v;
  }

  /// Per-rack; DISPLAY ONLY, never affects `RailPlacement.ruIndex`
  /// (CR-026).
  RuNumbering _ruNumbering;
  RuNumbering get ruNumbering => _ruNumbering;
  @internal
  set ruNumbering(RuNumbering v) => _ruNumbering = v;

  /// Per-rack, default true; shows a NOT MIRRORED chip when off (CR-035).
  bool _mirrorRearElevation;
  bool get mirrorRearElevation => _mirrorRearElevation;
  @internal
  set mirrorRearElevation(bool v) => _mirrorRearElevation = v;

  RackWidthClass _widthClass;
  RackWidthClass get widthClass => _widthClass;
  @internal
  set widthClass(RackWidthClass v) => _widthClass = v;

  RailType _railType;
  RailType get railType => _railType;
  @internal
  set railType(RailType v) => _railType = v;

  RackFormFactor _formFactor;
  RackFormFactor get formFactor => _formFactor;
  @internal
  set formFactor(RackFormFactor v) => _formFactor = v;

  /// NULLABLE — a 2-post frame has none (AC-050/A1.3). Null means
  /// UNKNOWN/not applicable, never zero (CR-114).
  Len? _usableDepth;
  Len? get usableDepth => _usableDepth;
  @internal
  set usableDepth(Len? v) => _usableDepth = v;

  Mass? _weightCapacity;
  Mass? get weightCapacity => _weightCapacity;
  @internal
  set weightCapacity(Mass? v) => _weightCapacity = v;

  bool _isSwingFrame;
  bool get isSwingFrame => _isSwingFrame;
  @internal
  set isSwingFrame(bool v) => _isSwingFrame = v;

  HingeSide? _hingeSide;
  HingeSide? get hingeSide => _hingeSide;
  @internal
  set hingeSide(HingeSide? v) => _hingeSide = v;

  /// Feeds a note on the elevation (AC-034/m21).
  bool _groundBarPresent;
  bool get groundBarPresent => _groundBarPresent;
  @internal
  set groundBarPresent(bool v) => _groundBarPresent = v;

  // ACCESS CONTROL: the fields below are still plain mutable, pending the
  // @internal retrofit (AC-013). Converted as each is wired to a Command;
  // the twelve above have been. These remain because no Command writes
  // them yet — `customPanelWidth` and `fullHoleRail` have no inspector
  // control, the `overall*` dimensions and `ownWeight` are derived/
  // read-only display, and doors, door clearances and 0U channels belong
  // to sections not yet built. See internal_setter_grep_test.dart.
  Len? customPanelWidth;
  bool fullHoleRail;
  Len? overallDepth;
  Len? overallWidth;
  Len? overallHeight;
  Mass? ownWeight;
  bool hasFrontDoor;
  bool hasRearDoor;

  /// DOOR CLEARANCE IS THE SWING SPACE in front of the door, which a
  /// closet or millwork must leave free (DR-239 §11.238.2, the trade's own
  /// term). Null is unknown (CR-114).
  Len? frontDoorClearance;
  Len? rearDoorClearance;

  /// RAIL CLEARANCE IS THE DEPTH INSIDE the door, between the rail and the
  /// closed door, which handles, cable and door-mounted fans eat (DR-239
  /// §11.238.2). A different measurement from [frontDoorClearance] with a
  /// different trade name; the model had one field where the trade has
  /// two. Null is unknown (CR-114).
  Len? frontRailClearance;
  Len? rearRailClearance;

  /// Sub-objects, string-keyed, no `EntityMeta`.
  List<ZeroUChannel> zeroUChannels;
  FracIndex order;
  EntityMeta meta;
}
