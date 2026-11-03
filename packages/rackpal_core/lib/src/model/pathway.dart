// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// conduit|jhook|tray|plenumSpace|riser|directBury|exterior|attic|
/// crawlspace.
///
/// NINE VALUES, and the last two are DR-031 (canon §11.30) discharging
/// DR-020 §11.19.4, which left them open and dated the question *"Owed at
/// M3, when `Pathway` gets its editor"*.
///
/// THE OBJECTION WAS THAT BOTH ARE SPACES AND `Location` ALREADY MODELS
/// SPACES. It does, and that is a different fact: `Location` models where
/// a room IS, this models what a cable PASSES THROUGH. A run from the
/// rack to a bedroom crosses an attic that is nobody's room and belongs
/// to no room's subtree, and [Pathway.fromLocationId] /
/// [Pathway.toLocationId] are ENDPOINTS, so a space in the middle has no
/// field to live in.
///
/// WHAT A VALUE CARRIES IS A CONSEQUENCE, which is why these two sit
/// beside `plenumSpace` rather than in a taxonomy: `attic` obliges
/// temperature derating and rodent exposure, `crawlspace` obliges
/// moisture and vermin, as `plenumSpace` obliges a jacket rating
/// (NEC 800.154, `CODE-002`).
///
/// **NEITHER IS AN ERROR AND NEITHER ADDS A RULE.** The v1 catalogue
/// stays at 28. G2 requires the document be able to represent the world
/// as found, and in a retrofit an attic run is the ordinary case.
///
/// SERIALISED BY NAME, which is why DR-020 deferred the question to the
/// day the editor lands rather than settling it earlier or later: the
/// enum is complete before any gesture can write it, so no document
/// records `conduit` for a run its author would have called `attic`.
enum PathwayKind {
  conduit,
  jhook,
  tray,
  plenumSpace,
  riser,
  directBury,
  exterior,
  attic,
  crawlspace,
}

/// A conduit / j-hook / tray / trunk a `Link` may be routed through
/// (CR-016, AC-027). First-class rather than an opaque `conduitId`
/// string, because `CODE-001`/`CODE-002` need `containsLineVoltage` and
/// `kind` to protect the user from an actual code citation.
final class Pathway {
  Pathway({
    required this.id,
    required String name,
    required this.order,
    required this.meta,
    PathwayKind kind = PathwayKind.conduit,
    bool containsLineVoltage = false,
    Uuid? fromLocationId,
    Uuid? toLocationId,
    Len? nominalLength,
    MediaTypeId? pathwayMedia,
    String? designator,
    String? notes,
  }) : _name = name,
       _designator = designator,
       _notes = notes,
       _fromLocationId = fromLocationId,
       _toLocationId = toLocationId,
       _kind = kind,
       _containsLineVoltage = containsLineVoltage,
       _nominalLength = nominalLength,
       _pathwayMedia = pathwayMedia;

  final Uuid id;

  /// "attic run to the garage". THE HUMAN NAME, and not the designator
  /// beside it.
  ///
  /// The doc comment here used to read `"B03"`, which is designator-shaped
  /// and is exactly the confusion DR-026 §11.25.1 refused: the temptation
  /// was to print this field in the Pull Sheet's `PATHWAY` column and add
  /// nothing. Refused, because every other entity in this model carries a
  /// human name and a short identifier separately (`DeviceInstance`,
  /// `Rack`), and overloading them makes that column print whichever one a
  /// person happened to type.
  String _name;
  String get name => _name;
  @internal
  set name(String v) => _name = v;

  /// `T1`, `PW-LR-1`: what is written on the trunk, where one is written.
  ///
  /// MANUALLY ENTERED. NO ALLOCATOR, NO SERIES, NO FORMAT TOKEN
  /// (DR-026 §11.25.1, confirmed and made permanent by DR-037 §11.36.6).
  /// This is DR-020's distinction applied to pathways: *"the route is
  /// discovered, not designed"*, so a designator generated before anybody
  /// has opened a ceiling would be the voided design-time polyline in a
  /// shorter form. A trunk that HAS been established is the opposite case,
  /// an as-built fact somebody walked, and recording it takes nothing on
  /// trust.
  ///
  /// **MANUAL IS THE REVERSIBLE DIRECTION AND GENERATED IS NOT**, which is
  /// the whole of why it won. A nullable hand-entered string can later
  /// gain an allocator that fills the absent ones, without changing the
  /// field, the file or the column. An allocated series cannot become
  /// manual mid-project without abandoning the uniqueness its allocator
  /// assumed.
  ///
  /// Null is unknown (G4, CR-114), never "no designator": a trunk nobody
  /// has labelled yet genuinely has none, and inventing one names a
  /// conduit no installer can find.
  ///
  /// **UNIQUE WHERE SET, PROJECT-WIDE**, on CR-113's `rackLabel`
  /// precedent, and **null is not a collision**. Two trunks called `T1` on
  /// one Pull Sheet is the defect the column exists to prevent. Enforced
  /// by `buildSetPathwayDesignator`, which REFUSES; the
  /// `PathwayField.designator` row exists for readers and must not be
  /// driven through `buildSetEntityProperty`, which writes and cannot
  /// decline.
  String? _designator;
  String? get designator => _designator;
  @internal
  set designator(String? v) => _designator = v;

  String? _notes;
  String? get notes => _notes;
  @internal
  set notes(String? v) => _notes = v;

  /// THE TWO FIELDS A GREP FOR `locationId` DOES NOT FIND, which is why
  /// DR-021 enumerates the nine carriers rather than describing them.
  /// `RemoveLocationCommand` clears both when the room at either end of a
  /// pathway is deleted (§11.20.2), and that wiring is the AC-013
  /// retrofit.
  ///
  /// **`from` IS THE ROOM AND `to` IS WHERE IT GOES** (DR-035 §11.34.3).
  /// That order was open until 2026-08-10: both fields shipped at M0 with
  /// no reader establishing one, and `RemoveLocationCommand` treats them
  /// symmetrically. It is docs/08 §3.2's `FROM — ROOM` / `TO — RACK`,
  /// which `ScheduleEntry.roomId` already relies on, rather than a new
  /// convention.
  ///
  /// `to` IS WRITTEN BY NO GESTURE and that is G4: a conduit's far end is
  /// the rack in the ordinary case, and this project may hold no rack.
  Uuid? _fromLocationId;
  Uuid? get fromLocationId => _fromLocationId;
  @internal
  set fromLocationId(Uuid? v) => _fromLocationId = v;

  Uuid? _toLocationId;
  Uuid? get toLocationId => _toLocationId;
  @internal
  set toLocationId(Uuid? v) => _toLocationId = v;

  // ─────────────────────────────────────────────────────────────────
  // THE FOUR M3-E/4 WIRED (#591).
  // ─────────────────────────────────────────────────────────────────
  // Until that task, NOTHING IN THE PRODUCT CREATED A `Pathway` at all:
  // no command, no accessor table, no editor, and the only writers of
  // `doc.pathways` were `RemoveLocationCommand` clearing the two
  // location references during DR-021's cascade. So these four sat at
  // their constructor defaults on an entity that could not exist, which
  // is why they take the AC-013 retrofit here and not earlier: a field
  // converts as each is wired to a Command.

  /// What the cable passes through (DR-031, canon §11.30).
  ///
  /// DEFAULTS TO `conduit` AND IS NEVER UNKNOWN, which is deliberate and
  /// unlike its nullable neighbours: a pathway is a physical thing
  /// somebody built, so `kind` always has a true answer even when nobody
  /// has recorded it. The default is a guess in the way `roughInStatus`'s
  /// `planned` is a guess, not in the way a null length is unknown.
  PathwayKind _kind;
  PathwayKind get kind => _kind;
  @internal
  set kind(PathwayKind v) => _kind = v;

  /// Whether line voltage shares this pathway.
  ///
  /// NOT COSMETIC. `CODE-001` reads it, and `CODE-002` is an ERROR when a
  /// pathway is a plenum space and the jacket is not `cmp`/`lszh`
  /// (NEC 800.154). Both rules are M5's; M3 is where the fact is entered,
  /// which is the whole reason it has to be settable and trustworthy
  /// before M5 can read it.
  ///
  /// `bool` AND NOT `bool?`, which is a real asymmetry against G4 and is
  /// the model's existing choice rather than this task's: `false` here
  /// means "no line voltage declared", and a rule that fired on unknown
  /// would fire on every pathway nobody had answered for. If M5 finds it
  /// needs the third state, that is a ruling and a migration, not a
  /// silent widening.
  bool _containsLineVoltage;
  bool get containsLineVoltage => _containsLineVoltage;
  @internal
  set containsLineVoltage(bool v) => _containsLineVoltage = v;

  /// How long the pathway itself runs. Null is unknown (G4, CR-114), and
  /// it is NOT a cable length: a `Link.routedLength` is the cable's own
  /// figure and may exceed this one by every service loop in the run.
  Len? _nominalLength;
  Len? get nominalLength => _nominalLength;
  @internal
  set nominalLength(Len? v) => _nominalLength = v;

  /// `isPathwayOnly` media (CR-109) — which conduit this actually is.
  ///
  /// SET BY EVERY SURFACE THAT CREATES A PATHWAY FROM A MEDIUM
  /// (DR-035 §11.34.2). This comment used to say the flag did not exist
  /// and the drop line could not reach here; `4ffb9b8` added
  /// `MediaTypeDef.isPathwayOnly`, `daf1f81` made `Office: 1x ENT` build
  /// a `Pathway`, and DR-035 made that act record which medium it was.
  ///
  /// WITHOUT THIS FIELD THE MATRIX CELL COULD NOT COUNT ITS OWN WORK.
  /// docs/07 §4.2's grid is a count, and "the pathways in this room, of
  /// this medium" is unanswerable from a name that is a description
  /// (DR-032 §11.31.2). Null stays legal and is what `+ Add pathway`
  /// produces: a button press names no medium.
  MediaTypeId? _pathwayMedia;
  MediaTypeId? get pathwayMedia => _pathwayMedia;
  @internal
  set pathwayMedia(MediaTypeId? v) => _pathwayMedia = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  FracIndex order;
  EntityMeta meta;
}
