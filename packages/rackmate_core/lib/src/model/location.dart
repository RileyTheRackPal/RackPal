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
    required this.kind,
    required String name,
    required String code,
    required this.order,
    required this.meta,
    this.parentId,
    this.floorNumber,
    this.spaceCode,
    this.estimatedRunLengthFromRack,
  }) : _name = name,
       _code = code;

  final Uuid id;

  /// Arbitrary-depth tree (CR-047).
  Uuid? parentId;
  LocationKind kind;

  String _name;
  String get name => _name;
  @internal
  set name(String v) => _name = v;

  /// "MBR" — feeds `{ROOM_ABBR}` (CR-046).
  String _code;
  String get code => _code;
  @internal
  set code(String v) => _code = v;

  int? floorNumber;
  String? spaceCode;

  /// ONE number per room — this is what makes 62 usable estimates
  /// possible (AC-024).
  Len? estimatedRunLengthFromRack;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  FracIndex order;
  EntityMeta meta;
}
