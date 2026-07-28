// Rack-shaped commands. Today that is exactly one: [AddRackCommand], the
// command docs/09-roadmap.md M1's exit criterion needs and this repository
// did not have — `docs/12-milestone-board.md` §3.2 clause 2 records the
// grep that returned nothing for `AddRack`/`addRack`/`createRack`, so a
// user could only ever be HANDED the 42U rack `blank_document.dart` seeds.
//
// WHY A NEW FILE rather than a fourth class in `set_rack_property_command
// .dart`. That file's own header argues for one class over twelve because
// "the shape is identical"; this shape is not. An add mints an entity and
// its `EntityMeta` from nothing (the `AddDeviceCommand` shape), where every
// command in that file snapshots and restores a PRIOR meta triple. Adding
// it there would mean one file whose header describes half its contents.
//
// WHY NO `RemoveRackCommand` HERE. A rack removal has to answer what
// happens to its occupants — orphan them into `OffRackPlacement`, delete
// them, or refuse — and that is a design question docs/04 does not settle
// (there is no delete-rack affordance in §8's keymap and no §9 empty state
// for "you just deleted the rack you were editing"). Shipping a half-answer
// would be worse than the honest absence: this file adds the direction the
// exit criterion names and nothing else.
import 'package:rackmate_core/src/catalog/rack_presets.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/idformat/designator_allocator.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/constants.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// The type prefix a rack's designator is allocated under — `RK-1`, `RK-2`
/// (CR-040: `Rack.designator` is the ONLY rack identifier, so there is no
/// second `refDesPrefix` to reconcile this with).
const String kRackTypePrefix = 'RK';

/// Creates a brand-new [Rack]. The id is minted in the constructor (never
/// in `apply()`) so redo recreates the identical entity — the same rule
/// `AddDeviceCommand` follows, and for the same reason: anything stacked on
/// top of this command (a device placed into the rack) still resolves after
/// an undo/redo pair.
///
/// Every `apply()` builds a fresh [Rack] from this command's own immutable
/// fields, including the [EntityMeta] it stamps, so every construction is
/// field-for-field identical and CR-117's byte round-trip holds under
/// `apply; revert; apply`. There is no prior state to preserve — the rack
/// did not exist before the first `apply()`.
///
/// FIELD COVERAGE IS DELIBERATELY THE PRESET'S, NOT `Rack`'s. The nine
/// constructor arguments below are exactly docs/04 §9's three dialog fields
/// (name, designator-and-height) plus the six facts a [RackPreset] states.
/// Everything else — `locationId`, `ruNumbering`, `mirrorRearElevation`,
/// doors, 0U channels — keeps `Rack`'s own constructor default, because a
/// creation dialog that silently set them would be inventing values the
/// user was never shown (G4). They are all editable afterwards through
/// `SetRackPropertyCommand`.
final class AddRackCommand extends Command {
  AddRackCommand({
    required this.name,
    required this.designator,
    required this.heightU,
    required this.order,
    required this.now,
    required this.actor,
    this.formFactor = RackFormFactor.floorEnclosure,
    this.widthClass = RackWidthClass.eia19,
    this.railType = RailType.tapped10_32,
    this.usableDepth,
    this.weightCapacity,
    this.isSwingFrame = false,
    this.hingeSide,
    Uuid? id,
  }) : id = id ?? newEntityId(),
       assert(
         heightU >= 1 && heightU <= kMaxRackHeightU,
         'AddRackCommand.heightU must be in [1, $kMaxRackHeightU] (CR-038)',
       );

  final Uuid id;
  final String name;

  /// "RK-1" — allocated by [allocateRackDesignator] at BUILD time and
  /// stored, never recomputed at render time (docs/04 §7, CR-048).
  final String designator;
  final int heightU;
  final FracIndex order;
  final RackFormFactor formFactor;
  final RackWidthClass widthClass;
  final RailType railType;
  final Len? usableDepth;
  final Mass? weightCapacity;
  final bool isSwingFrame;
  final HingeSide? hingeSide;
  final DateTime now;
  final String actor;

  @override
  LabelKey get label => LabelKey.addRack;

  /// `rack` for the enclosure itself (`EpochMask.rack`'s own doc comment
  /// names "rack add/remove"), `meta` for the designator and name the
  /// header bar and the equipment list read.
  @override
  EpochMask get touches => EpochMask.rack | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id];

  @override
  void apply(RackDocument doc) {
    doc.racks[id] = Rack(
      id: id,
      name: name,
      designator: designator,
      heightU: heightU,
      order: order,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      widthClass: widthClass,
      railType: railType,
      formFactor: formFactor,
      usableDepth: usableDepth,
      weightCapacity: weightCapacity,
      isSwingFrame: isSwingFrame,
      hingeSide: hingeSide,
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.racks.remove(id);
  }
}

/// The designator a NEW rack should receive: `RK-1`, then `RK-2`, … — the
/// lowest unused positive integer for the prefix, rendered through the ONE
/// format engine (docs/04 §7, CR-045) rather than a second `'RK-$n'` string
/// concatenation that could disagree with a project's customised separator
/// or padding.
String allocateRackDesignator({
  required RackDocument doc,
  String typePrefix = kRackTypePrefix,
}) => allocateDeviceDesignator(
  settings: doc.settings,
  typePrefix: typePrefix,
  usedDesignators: {for (final r in doc.racks.values) r.designator},
);

/// Every character a [FracIndex] this function mints can contain, in ASCII
/// order — which is what makes plain `String.compareTo` (the comparator
/// `equipment_list.dart` and `SheetSet.forRacks` both sort racks by) agree
/// with the alphabet's own order. `'0'..'9' < 'A'..'Z' < 'a'..'z'` in ASCII,
/// so this string is sorted as written.
const String _fracAlphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

/// A [FracIndex] that sorts strictly AFTER every index in [existing] —
/// "append at the end", the only insertion position a New-rack dialog with
/// no reorder UI can mean.
///
/// NOT a general LexoRank `between(a, b)`. Fractional indices exist so an
/// item can be inserted BETWEEN two others without renumbering, and this
/// codebase has no surface that reorders racks; writing the general form
/// now would be untested generality. The rule here is small enough to state
/// in full: take the largest existing index, and either bump its last
/// character to the next one in [_fracAlphabet], or — when it is already the
/// last character — append `'0'`. Both produce a strictly greater string
/// under `compareTo` (a greater character at the same position, or a proper
/// extension of the same prefix), which is the entire postcondition.
FracIndex nextRackOrder(Iterable<FracIndex> existing) {
  var max = '';
  for (final index in existing) {
    if (index.v.compareTo(max) > 0) max = index.v;
  }
  if (max.isEmpty) return const FracIndex('a0');
  final lastAt = _fracAlphabet.indexOf(max[max.length - 1]);
  if (lastAt < 0 || lastAt == _fracAlphabet.length - 1) {
    // An unrecognised character (a hand-edited file) or `'z'`: extending is
    // correct for both, and is the branch that cannot fail.
    return FracIndex('$max${_fracAlphabet[0]}');
  }
  return FracIndex(
    max.substring(0, max.length - 1) + _fracAlphabet[lastAt + 1],
  );
}

/// The outcome of [buildAddRackCommand] — a ready command or the reason
/// there is none, in the shape `CatalogPlacementResult` already establishes,
/// so a caller can honour docs/04 §3.4's "never silently do nothing".
sealed class AddRackResult {
  const AddRackResult();
}

final class AddRackReady extends AddRackResult {
  const AddRackReady(this.command);
  final AddRackCommand command;
}

final class AddRackRefused extends AddRackResult {
  const AddRackRefused(this.reason);
  final String reason;
}

/// Builds the [AddRackCommand] for docs/04 §9's New-rack dialog: three
/// fields — [name], [preset] and [heightU] — against [doc], which supplies
/// the two values the dialog does NOT ask for (the allocated designator and
/// the sort order).
///
/// [heightU] is the dialog's own field and OVERRIDES the preset's height:
/// §9 lists Preset and Height as two separate fields, so a user who picks
/// "Floor enclosure 44U" and then types 42 means 42. The preset still
/// supplies form factor, width class, rail type, depth and capacity, and
/// the rack simply reads "Custom" in the inspector's preset dropdown
/// afterwards — `matchingPresetId` compares `heightU` too, so the rack never
/// claims to be an archetype it is not.
AddRackResult buildAddRackCommand({
  required RackDocument doc,
  required String name,
  required int heightU,
  required DateTime now,
  required String actor,
  RackPreset? preset,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return const AddRackRefused('A rack needs a name.');
  }
  if (heightU < 1 || heightU > kMaxRackHeightU) {
    return const AddRackRefused(
      'Height must be between 1U and ${kMaxRackHeightU}U (CR-038).',
    );
  }
  return AddRackReady(
    AddRackCommand(
      name: trimmed,
      designator: allocateRackDesignator(doc: doc),
      heightU: heightU,
      order: nextRackOrder(doc.racks.values.map((r) => r.order)),
      now: now,
      actor: actor,
      formFactor: preset?.formFactor ?? RackFormFactor.floorEnclosure,
      widthClass: preset?.widthClass ?? RackWidthClass.eia19,
      railType: preset?.railType ?? RailType.tapped10_32,
      usableDepth: preset?.usableDepth,
      weightCapacity: preset?.weightCapacity,
      isSwingFrame: preset?.isSwingFrame ?? false,
      hingeSide: preset?.hingeSide,
    ),
  );
}
