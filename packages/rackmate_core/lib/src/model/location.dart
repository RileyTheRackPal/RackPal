// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

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
  }) : _kind = kind,
       _name = name,
       _code = code,
       _parentId = parentId,
       _floorNumber = floorNumber,
       _spaceCode = spaceCode,
       _estimatedRunLengthFromRack = estimatedRunLengthFromRack;

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
