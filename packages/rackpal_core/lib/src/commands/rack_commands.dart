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
import 'package:rackpal_core/src/catalog/rack_presets.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/constants.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';
import 'package:rackpal_core/src/util/id_gen.dart';

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
/// `SetEntityPropertyCommand`.
final class AddRackCommand extends Command<RackDocument> {
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
  bool apply(RackDocument doc) {
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
    return true;
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
/// "append at the end", the only insertion position a creation dialog with
/// no reorder UI can mean.
///
/// ENTITY-AGNOSTIC ON PURPOSE. This shipped as `nextRackOrder` and stayed
/// rack-shaped only for as long as racks were the one entity a command
/// created at the end of an ordered list. `Link.order` is the second
/// (DR-011.2's `ConnectPortsCommand`), and the rule — take the largest
/// index, bump or extend it — never mentioned a rack. A second copy over
/// `doc.links` would be the same eleven lines written twice, which is the
/// shape that produced this project's 1000x mass error.
///
/// The rule is small enough to state in full: take the largest existing
/// index, and either bump its last character to the next one in
/// [_fracAlphabet], or, when it is already the last character, append one.
/// Both produce a strictly greater string under `compareTo` (a greater
/// character at the same position, or a proper extension of the same
/// prefix), which is the entire postcondition.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE EXTENSION APPENDS `'1'`, NOT `'0'`, AND THAT IS DR-064
/// ═══════════════════════════════════════════════════════════════════════
/// This branch appended `_fracAlphabet[0]` while nothing reordered, and it
/// was free to. It is not free now. `'0'` is the LOWEST character, so
/// `'az'` followed by `'az0'` is a pair with nothing between it: any index
/// strictly greater than `'az'` and strictly less than `'az0'` would have
/// to be `'az'` plus something below the lowest character there is. That
/// is the one input [orderBetween] cannot answer, and a template reaches
/// it at its 63rd port, which is a patchbay. Appending `'1'` spends one of
/// 62 slots and leaves the gap open permanently.
FracIndex nextOrder(Iterable<FracIndex> existing) {
  var max = '';
  for (final index in existing) {
    if (index.v.compareTo(max) > 0) max = index.v;
  }
  if (max.isEmpty) return const FracIndex('a0');
  final lastAt = _fracAlphabet.indexOf(max[max.length - 1]);
  if (lastAt < 0 || lastAt == _fracAlphabet.length - 1) {
    // An unrecognised character (a hand-edited file) or `'z'`: extending is
    // correct for both, and is the branch that cannot fail.
    return FracIndex('$max${_fracAlphabet[1]}');
  }
  return FracIndex(
    max.substring(0, max.length - 1) + _fracAlphabet[lastAt + 1],
  );
}

/// The middle of [_fracAlphabet], which is what an index reaches for when
/// it is opening a span nothing has divided yet.
const int _fracMid = 31;

/// A [FracIndex] strictly between [before] and [after], or null when the
/// two are neighbours with nothing representable between them.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE GENERATOR [nextOrder] SPENT FOUR MILESTONES DECLINING TO WRITE
/// ═══════════════════════════════════════════════════════════════════════
/// Its comment called the general form "untested generality", and that was
/// correct for exactly as long as no surface reordered anything. M4-F4
/// reorders. docs/06 §4.6 says a reorder is one field write on one row and
/// NOT a renumber of the bank, and that sentence is true only if a value
/// can be minted between two neighbours. So here is the general form, with
/// the tests the old comment was holding out for.
///
/// A null [before] means "above everything", a null [after] means "below
/// everything", and both null is the seed. The result is strictly ordered
/// against whichever ends are given, under the same raw `compareTo` every
/// consumer of `order` already uses.
///
/// ═══════════════════════════════════════════════════════════════════════
/// NULL IS A FACT ABOUT THE ENCODING, NOT A SHRUG
/// ═══════════════════════════════════════════════════════════════════════
/// There is exactly one shape this cannot answer: [after] is [before] plus
/// the single lowest character. Nothing fits, because the answer would
/// have to be [before] plus something below the lowest character there is.
/// [nextOrder] no longer mints that pair (see DR-064 above), so a document
/// this program wrote cannot contain one; a hand-edited file can, and the
/// caller refuses in words rather than renumbering the bank behind the
/// user's back.
FracIndex? orderBetween(FracIndex? before, FracIndex? after) {
  if (after == null) {
    return nextOrder(before == null ? const <FracIndex>[] : [before]);
  }
  final b = after.v;
  if (before == null) {
    final below = _below(b);
    return below == null ? null : FracIndex(below);
  }

  final a = before.v;
  if (a.compareTo(b) >= 0) return null;

  var i = 0;
  while (i < a.length && a[i] == b[i]) {
    i++;
  }
  if (i == a.length) {
    // [before] is a prefix of [after], so the answer is [before] plus
    // something below whatever [after] adds to it.
    final below = _below(b.substring(i));
    return below == null ? null : FracIndex(a + below);
  }

  final x = _fracAlphabet.indexOf(a[i]);
  final y = _fracAlphabet.indexOf(b[i]);
  if (x >= 0 && y >= 0 && y - x >= 2) {
    // Room at the position where they part, which is the short answer and
    // the one that keeps an index from growing a character per drag.
    return FracIndex(a.substring(0, i) + _fracAlphabet[(x + y) ~/ 2]);
  }

  // Adjacent characters at the divergence, so the answer has to be longer
  // than [before]. EVERY string carrying [before]'s first `i + 1`
  // characters is below [after], whatever follows them, because position
  // `i` has already decided the comparison. So growing [before]'s own tail
  // is always in range, and growing it through [nextOrder] is what makes
  // a run of these walk the alphabet (`a3V`, `a3W`, `a3X`) instead of
  // growing a character each time (`a3V`, `a3VV`, `a3VVV`).
  final tail = a.substring(i + 1);
  return FracIndex(
    a.substring(0, i + 1) +
        (tail.isEmpty
            ? _fracAlphabet[_fracMid]
            : nextOrder([FracIndex(tail)]).v),
  );
}

/// [count] indices, strictly increasing, all strictly between [before] and
/// [after]. Null when any one of them has nowhere to go.
///
/// ALL OR NOTHING, because a block of eight rows landing as six is a
/// reorder that half happened, and the two rows left behind are somewhere
/// the person did not put them.
List<FracIndex>? ordersBetween(
  FracIndex? before,
  FracIndex? after,
  int count,
) {
  final minted = <FracIndex>[];
  var cursor = before;
  for (var n = 0; n < count; n++) {
    final next = orderBetween(cursor, after);
    if (next == null) return null;
    minted.add(next);
    cursor = next;
  }
  return minted;
}

/// A non-empty string strictly below [t], or null when there is none.
///
/// The null case is [t] being exactly the lowest character: everything
/// below it would have to start with that character and be shorter, and
/// the empty string is not an index.
String? _below(String t) {
  if (t.isEmpty) return null;
  final d = _fracAlphabet.indexOf(t[0]);
  if (d < 0) return null;
  if (d >= 2) return _fracAlphabet[d ~/ 2];
  if (d == 1) return '${_fracAlphabet[0]}${_fracAlphabet[_fracMid]}';
  // [t] starts with the lowest character, so anything below it starts with
  // that character too and the question repeats one position along.
  if (t.length == 1) return null;
  final rest = _below(t.substring(1));
  return rest == null ? _fracAlphabet[0] : '${_fracAlphabet[0]}$rest';
}

/// [nextOrder] over rack orders. Kept as a named entry point rather than
/// inlined at the two call sites so `rack_commands_test.dart`'s existing
/// coverage — including its randomised total-order property — keeps
/// naming the thing it is actually about.
FracIndex nextRackOrder(Iterable<FracIndex> existing) => nextOrder(existing);

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
