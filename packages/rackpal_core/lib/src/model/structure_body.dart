// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart'
    show MountSurface, TerminationType, Wall;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// homeRunField|serviceEntrance|interRackTie|temporaryFeed.
enum StructureRole {
  homeRunField,
  serviceEntrance,
  interRackTie,
  temporaryFeed,
}

/// left|right, default left (CR-072).
enum SheetEdge { left, right }

/// The Structure device's body: the structured wiring entering the rack
/// (requirement 6 of the brief). Maps to the TIA-570-D Distribution
/// Device. Always paired 1:1 with a `DeviceInstance` whose
/// `kind == DeviceKind.structure`.
final class StructureBody {
  StructureBody({
    required this.id,
    required this.deviceId,
    required String title,
    required this.meta,
    StructureRole role = StructureRole.homeRunField,
    Uuid? distributionDeviceLocationId,
    String? enclosureModel,
    SheetEdge sheetEdge = SheetEdge.left,
  }) : _title = title,
       _role = role,
       _distributionDeviceLocationId = distributionDeviceLocationId,
       _enclosureModel = enclosureModel,
       _sheetEdge = sheetEdge;

  final Uuid id;

  /// The `DeviceInstance` with `kind == DeviceKind.structure`.
  final Uuid deviceId;

  /// "Rough-In - First Floor".
  String _title;
  String get title => _title;
  @internal
  set title(String v) => _title = v;

  StructureRole _role;
  StructureRole get role => _role;
  @internal
  set role(StructureRole v) => _role = v;

  /// The SMC / can / MDF location.
  Uuid? _distributionDeviceLocationId;
  Uuid? get distributionDeviceLocationId => _distributionDeviceLocationId;
  @internal
  set distributionDeviceLocationId(Uuid? v) =>
      _distributionDeviceLocationId = v;

  /// "Generic 42 in structured media enclosure".
  String? _enclosureModel;
  String? get enclosureModel => _enclosureModel;
  @internal
  set enclosureModel(String? v) => _enclosureModel = v;

  /// Which edge of the schematic sheet this body's off-page connectors
  /// bank on (CR-072). Read by `schematic_scene.dart` and `sugiyama.dart`,
  /// so it is a relayout rather than a repaint.
  SheetEdge _sheetEdge;
  SheetEdge get sheetEdge => _sheetEdge;
  @internal
  set sheetEdge(SheetEdge v) => _sheetEdge = v;

  EntityMeta meta;

  // NO bundleIds list — Outlets key back via Link.structureOrigin
  // (CR-016).
}

/// A home run's origin data — lives ON the `Link`, not a document-level
/// entity of its own (AC-019).
final class StructureOrigin {
  StructureOrigin({
    required this.structureBodyId,
    required this.outletId,
    required String fieldLabel,
    this.boxless = false,
    TerminationType? terminationField,
    TerminationType? terminationRack,
    String? rackLabel,
    bool rackLabelLocked = false,
    Wall? wall,
    MountSurface? mountSurface,
    Len? mountHeightAff,
  }) : _fieldLabel = fieldLabel,
       _terminationField = terminationField,
       _terminationRack = terminationRack,
       _rackLabel = rackLabel,
       _rackLabelLocked = rackLabelLocked,
       _wall = wall,
       _mountSurface = mountSurface,
       _mountHeightAff = mountHeightAff;

  final Uuid structureBodyId;

  /// The box this run comes out of, or NULL.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// NULL IS "NOBODY HAS SAID", AND [boxless] IS "THERE IS NO BOX"
  /// ═══════════════════════════════════════════════════════════════════
  /// Two facts, two fields, because G4 gives an absent value exactly one
  /// meaning and it is `unknown`. A ceiling speaker has NO low-voltage
  /// box: that is something a person stated, not a gap in what they
  /// know, and the Outlets page has to be able to tell it from a drop
  /// nobody has assigned yet. Folding both into a null would make the
  /// two indistinguishable in the file and uncountable on the page,
  /// which is the fusion DR-046 spent a ruling undoing when one field
  /// was serving two cable ends.
  ///
  /// Settled by the user on 2026-08-18 (`#718`), reported from real use:
  /// *"a ceiling speaker wouldn't even get a low voltage box let alone
  /// keystones"*.
  final Uuid? outletId;

  /// This run terminates on a device and comes out of no box at all.
  ///
  /// A STATEMENT, NOT AN ABSENCE. See [outletId]. It is deliberately NOT
  /// derived from whether the field end is landed: a speaker run that
  /// has been pulled and not yet terminated is boxless the day it is
  /// pulled, and a rule that waited for the bind would leave the Outlets
  /// page claiming a plate for it in the meantime, which is the fiction
  /// this exists to remove.
  ///
  /// DEFAULTS TO FALSE, so every document written before this decodes to
  /// exactly what it meant, and encodes back to the same bytes (CR-117).
  final bool boxless;

  // Every field below is wired to `StructureOriginField`
  // (commands/home_run_commands.dart) EXCEPT [rackLabelLocked], which is
  // written by `SetRackLabelCommand` beside the label it qualifies: a
  // table row's `set` is called by `revert` as well as by `apply`, so a
  // row that locked on the way in would re-lock on the way back out.
  // (The table was six rows when this note was written; DR-046 made it
  // seven by splitting the terminations, and DR-074 adds no eighth.)
  //
  // THE TWO LABELS ARE NOT SAFE TO SET DIRECTLY even from `src/commands/`:
  // CR-113 makes them unique project-wide, and only
  // `buildSetStructureOriginProperty` and `buildSetRackLabel` scan for a
  // collision. `@internal` buys the package boundary; the builders buy the
  // invariant.

  /// "LR-TV-1A" — on the wall plate. REQUIRED, unique project-wide across
  /// ALL Structure bodies (CR-113).
  String _fieldLabel;
  String get fieldLabel => _fieldLabel;
  @internal
  set fieldLabel(String v) => _fieldLabel = v;

  /// "1A-A12" — at the panel. Unique when set. Null is UNKNOWN, not "no
  /// label" (G4, CR-114).
  String? _rackLabel;
  String? get rackLabel => _rackLabel;
  @internal
  set rackLabel(String? v) => _rackLabel = v;

  /// TRUE ONLY WHEN A PERSON TYPED THE RACK LABEL (DR-074 §11.73.2).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// WHOSE NAME IS THIS, AND WHAT HAPPENS WHEN THE CABLE MOVES
  /// ═══════════════════════════════════════════════════════════════════
  /// A rack label is DERIVED from where the run landed (DR-040 §11.39.3),
  /// so `1A-PP-101` on a cable now sitting in position 04 is a wrong hole
  /// number on the one column a trim tech works from: worse than no label
  /// at all. A move therefore re-derives it. But the `RACK LBL` column
  /// lets a person type one, CR-113 makes it unique project-wide, and
  /// discarding somebody's own identifier is the loss G4 exists to
  /// refuse. One field cannot tell those two apart, which is the same
  /// shape as `Link.linkClassLocked` and for the same reason.
  ///
  /// WRITTEN BY THE `RACK LBL` CELL'S OWN EDIT PATH AND BY NOTHING ELSE.
  /// `AddHomeRunCommand` and `BindEndpointCommand` both write labels the
  /// ALLOCATOR produced, and locking those would freeze a derived name
  /// onto a cable that is free to move.
  ///
  /// ON THE WIRE THIS KEY IS ABSENT WHEN FALSE, following
  /// `Link.linkClassLocked` and deliberately NOT `designatorLocked`,
  /// which is written unconditionally: an always-written key here would
  /// rewrite every document already on disk and move `kSchemaVersion` to
  /// record something nobody has said (CR-117).
  bool _rackLabelLocked;
  bool get rackLabelLocked => _rackLabelLocked;
  @internal
  set rackLabelLocked(bool v) => _rackLabelLocked = v;

  Wall? _wall;
  Wall? get wall => _wall;
  @internal
  set wall(Wall? v) => _wall = v;

  MountSurface? _mountSurface;
  MountSurface? get mountSurface => _mountSurface;
  @internal
  set mountSurface(MountSurface? v) => _mountSurface = v;

  Len? _mountHeightAff;
  Len? get mountHeightAff => _mountHeightAff;
  @internal
  set mountHeightAff(Len? v) => _mountHeightAff = v;

  /// How the WALL-PLATE end is finished — what the trim-out crew
  /// actually installs, which is what `derived/schedule.dart` prints on
  /// the Termination Schedule.
  ///
  /// NULL IS UNKNOWN AND `unterminated` IS A DECISION (G4, CR-114). A
  /// coil left deliberately bare is `unterminated`; a drop entered at
  /// rough-in, weeks before anyone opens a box of jacks, has no answer
  /// at all, and the two are different facts on a sheet somebody buys
  /// hardware from. This field was NON-NULLABLE until M3-J, so both
  /// entry surfaces had to write a value they did not have: the drop
  /// line and the outlet picker wrote `unterminated` and their own code
  /// said, in as many words, that it was "the nearest true value, not
  /// the right one".
  ///
  /// docs/07 §5.1 already treated it as optional — `termination_field`
  /// is an unmarked CSV column, so an import without one had nothing
  /// honest to store. `_terminationOf` had a `TerminationType?` return
  /// and a "then nothing" arm from the start; the arm was simply
  /// unreachable for home runs.
  TerminationType? _terminationField;
  TerminationType? get terminationField => _terminationField;
  @internal
  set terminationField(TerminationType? v) => _terminationField = v;

  /// How the RACK end is finished, at the panel.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A SECOND FIELD, BECAUSE THERE WAS ONLY EVER ONE (DR-046 §11.45)
  /// ═══════════════════════════════════════════════════════════════════
  /// The Structure editor has drawn `FIELD TERM` and `RACK TERM` as two
  /// columns since M3-C, and **both read [terminationField]**. Two
  /// columns, one value: setting the wall end forced the panel end to
  /// claim the same thing, and the case that exposed it is ordinary:
  /// *"a speaker run might have a phoenix connector on the rack side,
  /// but binding posts on the other."* That was not awkward to express;
  /// it was **inexpressible**.
  ///
  /// **NOTHING INFERS THIS FROM [terminationField], EVER.** Roughly nine
  /// Cat6 runs in ten do match at both ends, and defaulting on that
  /// basis is precisely the defect this field exists to remove: a
  /// schedule cannot then distinguish a value somebody stated from one
  /// the product copied, which is G4's whole complaint. The convenience
  /// lives in a GESTURE instead, `Same as field` on the batch bar, which
  /// writes a real value because a person asked it to.
  ///
  /// SYMMETRICAL WITH THE LABELS. `fieldLabel` is the wall plate and
  /// `rackLabel` is the panel; this class already held both ends of that
  /// pair, so holding both ends of the termination is the shape it was
  /// already in.
  TerminationType? _terminationRack;
  TerminationType? get terminationRack => _terminationRack;
  @internal
  set terminationRack(TerminationType? v) => _terminationRack = v;
}
