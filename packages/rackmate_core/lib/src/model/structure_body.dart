// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart'
    show MountSurface, TerminationType, Wall;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

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
    TerminationType? terminationField,
    String? rackLabel,
    Wall? wall,
    MountSurface? mountSurface,
    Len? mountHeightAff,
  }) : _fieldLabel = fieldLabel,
       _terminationField = terminationField,
       _rackLabel = rackLabel,
       _wall = wall,
       _mountSurface = mountSurface,
       _mountHeightAff = mountHeightAff;

  final Uuid structureBodyId;
  final Uuid outletId;

  // Every field below is wired to `StructureOriginField`
  // (commands/home_run_commands.dart), so all six are converted. THE TWO
  // LABELS ARE NOT SAFE TO SET DIRECTLY even from `src/commands/`: CR-113
  // makes them unique project-wide, and only
  // `buildSetStructureOriginProperty` scans for a collision. `@internal`
  // buys the package boundary; the builder buys the invariant.

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
}
