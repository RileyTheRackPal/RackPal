// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show RuNumbering;
import 'package:rackmate_core/src/model/zero_u_channel.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';

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
    this.locationId,
    this.ruNumbering = RuNumbering.bottomUpFromOne,
    this.mirrorRearElevation = true,
    this.widthClass = RackWidthClass.eia19,
    this.customPanelWidth,
    this.railType = RailType.tapped10_32,
    this.fullHoleRail = false,
    this.formFactor = RackFormFactor.floorEnclosure,
    this.usableDepth,
    this.overallDepth,
    this.overallWidth,
    this.overallHeight,
    this.weightCapacity,
    this.ownWeight,
    this.isSwingFrame = false,
    this.hingeSide,
    this.hasFrontDoor = false,
    this.hasRearDoor = false,
    this.frontDoorClearance,
    this.rearDoorClearance,
    this.groundBarPresent = false,
    List<ZeroUChannel>? zeroUChannels,
  }) : _name = name,
       _designator = designator,
       _heightU = heightU,
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

  Uuid? locationId;

  /// 1..60, asserted. Advisory above 50 (CR-038).
  int _heightU;
  int get heightU => _heightU;
  @internal
  set heightU(int v) => _heightU = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// Per-rack; DISPLAY ONLY, never affects `RailPlacement.ruIndex`
  /// (CR-026).
  RuNumbering ruNumbering;

  /// Per-rack, default true; shows a NOT MIRRORED chip when off (CR-035).
  bool mirrorRearElevation;

  RackWidthClass widthClass;
  Len? customPanelWidth;
  RailType railType;
  bool fullHoleRail;
  RackFormFactor formFactor;

  /// NULLABLE — a 2-post frame has none (AC-050/A1.3).
  Len? usableDepth;
  Len? overallDepth;
  Len? overallWidth;
  Len? overallHeight;
  Mass? weightCapacity;
  Mass? ownWeight;

  bool isSwingFrame;
  HingeSide? hingeSide;
  bool hasFrontDoor;
  bool hasRearDoor;
  Len? frontDoorClearance;
  Len? rearDoorClearance;

  /// Feeds a note on the elevation (AC-034/m21).
  bool groundBarPresent;

  /// Sub-objects, string-keyed, no `EntityMeta`.
  List<ZeroUChannel> zeroUChannels;
  FracIndex order;
  EntityMeta meta;
}
