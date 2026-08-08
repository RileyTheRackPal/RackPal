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
    Uuid? locationId,
    Wall? wall,
    MountSurface? mountSurface,
    Len? mountHeightAff,
    int? floorNumber,
    this.outletTemplateId,
    String? tia570Grade,
    Uuid? pathwayId,
    Len? nominalRunLength,
    String? notes,
    Map<String, Object?>? unknown,
  }) : _designation = designation,
       _locationId = locationId,
       _wall = wall,
       _mountSurface = mountSurface,
       _mountHeightAff = mountHeightAff,
       _floorNumber = floorNumber,
       _tia570Grade = tia570Grade,
       _pathwayId = pathwayId,
       _nominalRunLength = nominalRunLength,
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

  /// A standards TAG, not an axis (CR-108).
  String? _tia570Grade;
  String? get tia570Grade => _tia570Grade;
  @internal
  set tia570Grade(String? v) => _tia570Grade = v;

  Uuid? _locationId;
  Uuid? get locationId => _locationId;
  @internal
  set locationId(Uuid? v) => _locationId = v;

  Wall? _wall;
  Wall? get wall => _wall;
  @internal
  set wall(Wall? v) => _wall = v;

  MountSurface? _mountSurface;
  MountSurface? get mountSurface => _mountSurface;
  @internal
  set mountSurface(MountSurface? v) => _mountSurface = v;

  /// Height above finished floor. Null is UNKNOWN, never a measured zero
  /// (CR-114): a plate nobody has measured is not a plate on the floor.
  Len? _mountHeightAff;
  Len? get mountHeightAff => _mountHeightAff;
  @internal
  set mountHeightAff(Len? v) => _mountHeightAff = v;

  int? _floorNumber;
  int? get floorNumber => _floorNumber;
  @internal
  set floorNumber(int? v) => _floorNumber = v;

  Uuid? _pathwayId;
  Uuid? get pathwayId => _pathwayId;
  @internal
  set pathwayId(Uuid? v) => _pathwayId = v;

  /// The per-drop nominal the schedule can source a length from. Null is
  /// UNKNOWN and the rollup counts it as such (G4, CR-114).
  Len? _nominalRunLength;
  Len? get nominalRunLength => _nominalRunLength;
  @internal
  set nominalRunLength(Len? v) => _nominalRunLength = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command; the eight
  // above were converted by M3-A/5's `OutletField` table. These remain
  // because no Command writes them: `outletTemplateId` is provenance
  // (CR-108, "what created it") that the creating gesture sets and an
  // inspector only displays, and `order` is written by a reorder drag
  // through the `FracIndex` allocator rather than as a value a caller
  // supplies. See internal_setter_grep_test.dart.

  /// What created it (CR-108).
  String? outletTemplateId;
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
    this.tag,
    this.tia570Grade,
    List<OutletDrop>? drops,
  }) : drops = drops ?? [];

  final String id;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  String name;

  /// The label segment `{SERVICE}` renders — `TV`, `KEY`, `CAM`
  /// (DR-022 §11.21.4, DR-023 step 2).
  ///
  /// AUTHORED BESIDE THE NAME, NEVER DERIVED FROM IT. `name` is *"TV
  /// location"* and a tag truncated out of it is a guess printed on
  /// physical cable. The corpus's own worked labels are `LR-TV-1`,
  /// `MBR-KEY-2` and `EXT-CAM-4`, and no truncation rule produces all
  /// three from *TV location*, *Keypad* and *Camera*.
  ///
  /// NULLABLE, and null means UNKNOWN rather than empty (G4, CR-114): a
  /// template authored before this key existed has no tag, and DR-023's
  /// chain falls through to the media's short tag rather than printing
  /// a blank segment.
  ///
  /// NOT A MIGRATION. `registries.outletTemplates` is `{}` in all four
  /// shipped starters and in every document ever written, so a key added
  /// to an entity with zero instances everywhere costs no file a byte.
  String? tag;

  /// The standards citation this template stamps on every `Outlet` it
  /// creates — `"TIA-570-D Grade 2"` (DR-024 §11.23.2).
  ///
  /// A FIELD, NOT A SPECIAL CASE ON THE THREE SEEDED IDS. Keying the
  /// stamp to `outlet.tia570d_grade1..3` needs no model change and works
  /// for exactly the three presets this repository ships, which is the
  /// opposite of what CR-108 ruled: user-defined templates are
  /// first-class, so a shop authoring its own Grade 2, or one citing a
  /// builder's spec rather than TIA's, would stamp nothing. It would
  /// also make an id rename a silent behaviour change.
  ///
  /// A CITATION, NOT A SUGGESTION, and that is why it is a free `String`
  /// rather than an enum. CR-108 deleted `StructureGrade` and kept
  /// `Outlet.tia570Grade: String?` as a **tag for specs that cite one**;
  /// this field is the same string, carried one level up so the gesture
  /// that creates the outlet has something to copy.
  ///
  /// NULL ON THE SIX NAMED TEMPLATES, and that is G4 rather than a gap:
  /// *TV location* makes no standards claim, and writing one would put a
  /// citation in a document nobody made.
  String? tia570Grade;

  List<OutletDrop> drops;
}
