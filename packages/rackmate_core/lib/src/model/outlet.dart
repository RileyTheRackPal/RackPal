// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show MountSurface, Wall;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

/// ONE WALL PLATE / ONE CEILING LOCATION (CR-016). Holds no member list —
/// members are `Link`s, keyed back via `Link.structureOrigin.outletId`
/// (AC-019), so there is exactly one source of truth for membership.
final class Outlet {
  Outlet({
    required this.id,
    required this.structureBodyId,
    required String designation,
    required this.order,
    required this.meta,
    this.locationId,
    this.wall,
    this.mountSurface,
    this.mountHeightAff,
    this.floorNumber,
    this.outletTemplateId,
    this.tia570Grade,
    this.pathwayId,
    this.nominalRunLength,
    String? notes,
    Map<String, Object?>? unknown,
  }) : _designation = designation,
       _notes = notes,
       unknown = unknown ?? {};

  final Uuid id;
  final Uuid structureBodyId;

  /// Forward-compat / passthrough for fields this reader does not model
  /// (DR-019 §11.18.2(5)). Without it a build that predates a later outlet
  /// field silently DROPS that field on save, and under DR-006's
  /// shared-file reality two builds touching one project is ordinary.
  ///
  /// THE `Port` SHAPE, not `Placement`'s. `Outlet` is a mutable entity with
  /// `@internal` setters, so a fresh map per instance is right here for the
  /// same reason a shared `const` one is right on the immutable placement
  /// union. See `placement.dart` for why the two deliberately differ.
  ///
  /// IT LANDS BEFORE DR-007'S GANG LIST, deliberately. This is the field
  /// that protects the fields M3 is about to add to this very class.
  final Map<String, Object?> unknown;

  /// The outlet's own field designation.
  String _designation;
  String get designation => _designation;
  @internal
  set designation(String v) => _designation = v;

  String? _notes;
  String? get notes => _notes;
  @internal
  set notes(String? v) => _notes = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  Uuid? locationId;
  Wall? wall;
  MountSurface? mountSurface;
  Len? mountHeightAff;
  int? floorNumber;

  /// What created it (CR-108).
  String? outletTemplateId;

  /// A standards TAG, not an axis (CR-108).
  String? tia570Grade;
  Uuid? pathwayId;
  Len? nominalRunLength;
  FracIndex order;
  EntityMeta meta;
}

/// One drop within an `OutletTemplate`'s recipe.
final class OutletDrop {
  OutletDrop({required this.media, required this.service, this.count = 1});

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  MediaTypeId media;
  String service;
  int count;
}

/// A first-class recipe for creating a set of `Outlet` drops in one
/// gesture — "two Cat6 and two RG6 to every TV" (CR-108). Catalog data,
/// edited through the library flow rather than a document `Command`, so
/// it is out of scope for this package's AC-013 retrofit pass.
final class OutletTemplate {
  OutletTemplate({
    required this.id,
    required this.name,
    List<OutletDrop>? drops,
  }) : drops = drops ?? [];

  final String id;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  String name;
  List<OutletDrop> drops;
}
