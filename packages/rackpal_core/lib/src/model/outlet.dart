// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart'
    show MountSurface, TerminationType, Wall;
import 'package:rackpal_core/src/model/gang.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

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
    PlanPin? planPin,
    List<Gang>? gangs,
    Map<String, Object?>? unknown,
  }) : gangs = gangs ?? [],
       _designation = designation,
       _locationId = locationId,
       _wall = wall,
       _mountSurface = mountSurface,
       _mountHeightAff = mountHeightAff,
       _floorNumber = floorNumber,
       _tia570Grade = tia570Grade,
       _pathwayId = pathwayId,
       _nominalRunLength = nominalRunLength,
       _notes = notes,
       _planPin = planPin,
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

  /// Where this outlet's plate sits on a floorplan (docs/15 §3.4).
  ///
  /// **THE THING THE DESIGNER IS ACTUALLY DOTTING TODAY.** The practice
  /// this feature replaces is coloured dots in a notes application, and
  /// what those dots mark is plates: one wall plate, one ceiling location
  /// (CR-016). The device pin and the rack pin exist so a length can be
  /// derived; this one exists because it is the drawing people already
  /// make by hand.
  ///
  /// Null is UNKNOWN, not "at the origin" (G4, CR-114).
  PlanPin? _planPin;
  PlanPin? get planPin => _planPin;
  @internal
  set planPin(PlanPin? v) => _planPin = v;

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

  /// The gang openings in this plate, LEFT TO RIGHT (DR-007 §11.7.3).
  ///
  /// **`Outlet` STAYS THE PLATE AND GAINS A LIST**, which is why this is
  /// a field here rather than one `Outlet` per gang. That alternative was
  /// considered and rejected in the ruling: it "would lose the fact that
  /// two drops SHARE A BOX, which is exactly the fact a room-by-room
  /// guide exists to show", and it would redefine CR-016 rather than
  /// extend it.
  ///
  /// **THE COVER PLATE IS NOT IN HERE, AND ITS GANG COUNT IS THIS
  /// LIST'S LENGTH.** §11.7.8 change 1: a strap and a Decora plate are
  /// two distinct purchasable objects, so an `Outlet` with N gangs is N
  /// straps plus exactly ONE N-gang cover plate. That count is never
  /// free and never stored, because a stored copy of `gangs.length` is
  /// the second copy of one physical fact that CR-107 deleted
  /// `StructureDrop` over. `derived/plate_fill.dart` computes it.
  ///
  /// **EMPTY ON EVERY DOCUMENT EVER WRITTEN**, which is why the codec
  /// omits the key when empty and `kSchemaVersion` does not move: a key
  /// added to a list that is empty everywhere costs no existing file a
  /// byte (CR-117).
  ///
  /// ACCESS CONTROL: plain mutable pending the AC-013 retrofit, like
  /// `Link.conductors`. Gangs are added, removed and reordered through
  /// `commands/gang_commands.dart`.
  List<Gang> gangs;
}

/// One drop within an `OutletTemplate`'s recipe.
final class OutletDrop {
  OutletDrop({
    required this.media,
    required this.service,
    this.count = 1,
    this.termination,
  });

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  MediaTypeId media;
  String service;
  int count;

  /// How this drop's FIELD end is finished, stamped on every `Link` the
  /// template creates (DR-043 §11.42.2, DR-044 §11.43).
  ///
  /// **A RECIPE FACT, IN THE SAME FAMILY AS [count].** "TV location =
  /// 2 × Cat6 + 2 × RG6" already says what gets pulled; saying the Cat6
  /// lands on a punchdown is that sentence continuing. DR-044 §11.43.2
  /// records why the opposite was briefly ruled and why it was wrong:
  /// DR-024 refused a *standards citation* on these templates, which is a
  /// different kind of claim.
  ///
  /// **THIS IS THE MOUSE PATH.** `+ Add outlet ▾` is the route a
  /// mouse-first person lives in, and until this field existed it was the
  /// ONE route that could not express a termination. DR-007 §11.7.2.1's
  /// cell-count table reads `StructureOrigin.terminationField`, so a
  /// template that carries this produces plates `Arrange` can size.
  ///
  /// **NULLABLE, AND NULL STAYS UNSPECIFIED** (G4, CR-114). DR-043
  /// §11.42.1 does not move: a template that makes no claim produces
  /// drops that make none either, and M3-J made the field nullable
  /// precisely so no surface would write a value it did not have.
  ///
  /// **IT DOES COST THE FOUR STARTERS BYTES, AND THE CLAIM THAT IT WOULD
  /// NOT WAS ALREADY IN THIS FILE AND ALREADY FALSE.** [OutletTemplate.tag]
  /// below says `registries.outletTemplates` is `{}` in all four shipped
  /// starters; they carry all NINE seeded templates, six of them with a
  /// `tag` on disk. This comment said the same thing for one commit,
  /// inherited by copying, until `starter_assets_test.dart` failed on all
  /// four files at once. The starters are regenerated with DR-044's seed.
  ///
  /// `kSchemaVersion` STILL DOES NOT MOVE, and that half was never in
  /// doubt: an omitted-when-null key is additive, and an older reader
  /// skips it (CR-117).
  TerminationType? termination;
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
    this.primaryDomain,
    List<OutletDrop>? drops,
  }) : drops = drops ?? [];

  final String id;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  String name;

  /// What an outlet made from this recipe mostly serves, as one of the
  /// eight signal domains (`#900`, DR-169 §11.168.4). Null is unknown.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// AUTHORED, AND THE CENSUS FOR IT IS SMALLER AND CLEARER
  /// ═══════════════════════════════════════════════════════════════════
  /// A drop's `service` IS a signal family, so unlike a device template
  /// an outlet's domains CAN be read off its recipe. Measured over the
  /// nine shipped templates: **five resolve to exactly one domain, three
  /// resolve to two, and one is `structure.undetermined`**, which is the
  /// state docs/07 calls first-class at rough-in.
  ///
  /// **The one that breaks it is the most common outlet in the trade.**
  /// `TV location` is two Cat6 and two RG6, so it reads as `net` and
  /// `video.analog` at once, and a TV outlet is about the television.
  /// Deriving would leave the flagship recipe neutral while colouring
  /// `Data only`, which is the wrong way round.
  ///
  /// **The three TIA-570-D grades are deliberately null**, and that is
  /// not an omission: a grade is a CABLING STANDARD rather than a
  /// service, so *"which domain is a Grade 2 outlet"* has no answer to
  /// author. They are the same three that carry no `tag` for the same
  /// reason.
  ///
  /// An `Outlet` resolves this through [Outlet.outletTemplateId], which
  /// is nullable: an outlet whose template has been removed, or which
  /// was never made from one, has no domain and draws the neutral mark.
  SignalDomainId? primaryDomain;

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
  /// **THIS PARAGRAPH USED TO CLAIM `registries.outletTemplates` IS `{}`
  /// IN ALL FOUR SHIPPED STARTERS. IT IS NOT, AND WAS NOT WHEN THAT WAS
  /// WRITTEN.** Every starter carries all nine seeded templates, six of
  /// them with this very field on disk: `authoring.dart` assigns
  /// `buildSeedRegistries()` into each one. Adding a key here changes
  /// four checked-in golden files, and `starter_assets_test.dart` is
  /// what says so. Found at DR-044, when the claim was copied onto
  /// [OutletDrop.termination] and the goldens went red.
  ///
  /// What survives is the part that was about the FORMAT rather than
  /// about the corpus: an omitted-when-null key is additive and
  /// `kSchemaVersion` does not move (CR-117).
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
