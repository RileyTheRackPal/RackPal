// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// site|building|floor|room|zone|outdoor.
enum LocationKind { site, building, floor, room, zone, outdoor }

/// A node in the arbitrary-depth location tree (CR-047) — never a fixed
/// 4-level site/building/floor/room struct.
final class Location {
  Location({
    required this.id,
    required LocationKind kind,
    required String name,
    required String code,
    required this.order,
    required this.meta,
    Uuid? parentId,
    int? floorNumber,
    String? spaceCode,
    Len? estimatedRunLengthFromRack,
    Len? riseAllowance,
  }) : _kind = kind,
       _name = name,
       _code = code,
       _parentId = parentId,
       _floorNumber = floorNumber,
       _spaceCode = spaceCode,
       _estimatedRunLengthFromRack = estimatedRunLengthFromRack,
       _riseAllowance = riseAllowance;

  final Uuid id;

  /// Arbitrary-depth tree (CR-047).
  ///
  /// NOT AN `EntityField` ROW, and that is the ruling rather than an
  /// omission: DR-021 §11.20.5 makes a reparent REFUSE a cycle, and a
  /// table `set` writes and returns with no way to refuse. The one command
  /// permitted to write it is `ReparentLocationCommand`, which is built
  /// through `buildReparentLocation`. Same shape as `StructureOrigin`'s
  /// two label fields, and for the same reason.
  Uuid? _parentId;
  Uuid? get parentId => _parentId;
  @internal
  set parentId(Uuid? v) => _parentId = v;

  LocationKind _kind;
  LocationKind get kind => _kind;
  @internal
  set kind(LocationKind v) => _kind = v;

  String _name;
  String get name => _name;
  @internal
  set name(String v) => _name = v;

  /// "MBR" — feeds `{ROOM_ABBR}` (CR-046).
  String _code;
  String get code => _code;
  @internal
  set code(String v) => _code = v;

  int? _floorNumber;
  int? get floorNumber => _floorNumber;
  @internal
  set floorNumber(int? v) => _floorNumber = v;

  String? _spaceCode;
  String? get spaceCode => _spaceCode;
  @internal
  set spaceCode(String? v) => _spaceCode = v;

  /// ONE number per room — this is what makes 62 usable estimates
  /// possible (AC-024).
  ///
  /// Null is UNKNOWN and the schedule counts it as such (G4, CR-114); it
  /// is never a measured zero-length run to a room nobody has walked.
  Len? _estimatedRunLengthFromRack;
  Len? get estimatedRunLengthFromRack => _estimatedRunLengthFromRack;
  @internal
  set estimatedRunLengthFromRack(Len? v) => _estimatedRunLengthFromRack = v;

  /// The vertical drop a plan structurally cannot see: ceiling to device,
  /// or floor to device, added to a plan-derived straight line so the
  /// result stays a LOWER BOUND (DR-020 §11.19.2(1), docs/15 §4.1).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// TWO RULINGS AND A DESIGN DOCUMENT SPENT THIS FIELD BEFORE IT EXISTED
  /// ═══════════════════════════════════════════════════════════════════
  /// DR-020 defines `planLowerBound` as the straight line *"plus the
  /// location's `riseAllowance` if one is set"*, docs/15 §4.1 repeats it,
  /// and a grep over every `.dart` file in this tree returned **zero
  /// occurrences** until PLAN-C. DR-037 §11.36.5 adds it. It is the
  /// THIRD field named across three documents and built into none, after
  /// `MediaTypeDef.maxLength` (canon §11.19.7) and `unknown` on
  /// `Placement` (§11.18.1), which is why the practice says to grep for
  /// the writer rather than trust the citation.
  ///
  /// **IT IS THE SURVIVOR OF A DELETED SET, AND THAT IS WHY IT IS NOT A
  /// FUDGE FACTOR.** DR-020 killed `routingFactor` and `slackAllowance`
  /// as the product guessing at building geometry it cannot observe. This
  /// one was kept for the opposite reason: a plan is FLAT, so the drop
  /// from a ceiling to a device is the one dimension it cannot see even
  /// in principle, and adding a number a human supplies keeps the result
  /// a bound instead of quietly making it a fiction.
  ///
  /// Null is UNKNOWN and `0` is a measured zero (G4, CR-114): a room
  /// where the installer has confirmed there is no rise is a different
  /// statement from a room nobody has looked at.
  Len? _riseAllowance;
  Len? get riseAllowance => _riseAllowance;
  @internal
  set riseAllowance(Len? v) => _riseAllowance = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  //
  // `order` is deliberately still here rather than pending by accident:
  // reordering siblings is a drag, and it wants `nextLocationOrder`'s
  // allocator rather than a value a caller supplies. `Outlet.order` is out
  // of its own table on the identical ground.
  FracIndex order;
  EntityMeta meta;
}
