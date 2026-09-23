// rackpal_core/src/commands/lock_commands.dart — `Ctrl+L` (DR-186 §11.185,
// `#913`).
//
// ═══════════════════════════════════════════════════════════════════════
// TWO COMMANDS FOR ONE KEY, BECAUSE THE KEY MEANS "LOCK" IN TWO PLACES
// ═══════════════════════════════════════════════════════════════════════
// docs/04 §8 binds `Ctrl+L` to *"lock / unlock (position here, route in the
// schematic)"* and docs/05 §10 says what the schematic half is: a pinned
// symbol, which auto-layout never moves (CR-068). They are different fields
// on different entities, so they are different commands; they share a file
// and a word because a person pressing the key means one thing by it.
//
// BOTH FIELDS HAD NO WRITER. `Placement.locked` (CR-034) was set by nothing
// but the decoder and read by nothing but compaction, and `SheetItem.pinned`
// was read by the schematic layout and set by nothing at all (§11.185.0).
//
// ═══════════════════════════════════════════════════════════════════════
// SET, NOT TOGGLE, AND THE CALLER DECIDES WHICH
// ═══════════════════════════════════════════════════════════════════════
// Both commands carry the VALUE to store. The toggle rule (anything
// unlocked in the selection locks all of it, otherwise unlock all) is
// §11.185.2's and lives with the key, which is where the selection is. A
// command that toggled each device on its own would turn a mixed selection
// into its own inverse, which is the one outcome nobody pressing the key
// wants.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/sheet.dart';
import 'package:rackpal_core/src/model/sheet_item.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/pt.dart';
import 'package:rackpal_core/src/util/id_gen.dart';

/// What every gesture a lock refuses says, so the drag, the nudge, the
/// width field and the shrink cannot word it four ways (DR-186 §11.185.1).
///
/// It names the device and the way out. The KEY is not in the sentence,
/// because the key differs by platform and this file cannot know which;
/// the inspector's `Locked` checkbox is the route every platform has.
String lockedRefusal(String designator) =>
    '$designator is locked. Untick Locked in the inspector to move it.';

/// Locks or unlocks the position of every device in [deviceIds] that has
/// a position to hold (DR-186 §11.185.1).
///
/// A device with no rack position (off-rack, staged) is skipped rather
/// than refused: a selection holding one alongside rack devices is an
/// ordinary selection, and `Ctrl+L` over it means the ones it can mean.
/// **Nothing changing is a refusal**, on DR-156's contract, so a key
/// pressed over a selection that is already in the asked-for state leaves
/// no undo entry.
///
/// The ORIGINAL placement objects are kept and put back on revert, so undo
/// restores the object the file was read from and not one that merely
/// compares equal (the discipline `RemoveLocationCommand` holds).
final class SetPlacementLockedCommand extends Command<RackDocument> {
  SetPlacementLockedCommand({
    required Iterable<Uuid> deviceIds,
    required this.locked,
  }) : deviceIds = List<Uuid>.unmodifiable(
         deviceIds.toSet().toList()..sort((a, b) => a.v.compareTo(b.v)),
       );

  /// Sorted and de-duplicated, so two selections naming the same devices
  /// in a different order are the same command.
  final List<Uuid> deviceIds;

  /// The value to store.
  final bool locked;

  final Map<Uuid, Placement> _previous = {};
  bool _applied = false;

  @override
  LabelKey get label =>
      locked ? LabelKey.lockPlacement : LabelKey.unlockPlacement;

  /// `structure`, because a lock changes what compaction, a nudge and a
  /// drag may do with a placement, and the badge that shows it.
  @override
  EpochMask get touches => EpochMask.structure;

  @override
  Iterable<Uuid> get affects => deviceIds;

  @override
  bool apply(RackDocument doc) {
    _previous.clear();
    for (final id in deviceIds) {
      final device = doc.devices[id];
      if (device == null) continue;
      final current = device.placement;
      // NULL IS "A LOCK MEANS NOTHING HERE", and equal is "already so";
      // both are skips rather than refusals.
      final was = placementLocked(current);
      if (was == null || was == locked) continue;
      final next = placementWithLocked(current, locked: locked)!;
      _previous[id] = current;
      device.placement = next;
    }
    return _applied = _previous.isNotEmpty;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('SetPlacementLockedCommand.revert before apply().');
    }
    for (final entry in _previous.entries) {
      doc.devices[entry.key]?.placement = entry.value;
    }
  }
}

/// The one schematic sheet, or null when this document has none yet.
///
/// Resolved as the lowest-id `SheetKind.schematic` entry, which is the
/// rule `schematic_scene.dart` reads pins by: CR-073 says there is exactly
/// one, and `Sheet` does not enforce it, so the tie-break is stated.
Sheet? schematicSheetOf(RackDocument doc) {
  Sheet? chosen;
  for (final sheet in doc.sheets.values) {
    if (sheet.kind != SheetKind.schematic) continue;
    if (chosen == null || sheet.id.v.compareTo(chosen.id.v) < 0) {
      chosen = sheet;
    }
  }
  return chosen;
}

/// The devices whose schematic symbol is pinned (CR-068), on the one
/// schematic sheet. Empty when there is no sheet, which is every document
/// before its first pin (§11.185.4).
///
/// The same reading `schematic_scene.dart` lays out by, so the 📌 a canvas
/// draws and the symbol the layout leaves alone are the same set.
Set<Uuid> pinnedSymbolIds(RackDocument doc) => {
  for (final item in schematicSheetOf(doc)?.items.values ?? <SheetItem>[])
    if (item.pinned) item.targetId,
};

/// Pins or unpins schematic symbols (DR-186 §11.185.3, CR-068).
///
/// ═══════════════════════════════════════════════════════════════════════
/// PINNED WHERE IT STANDS
/// ═══════════════════════════════════════════════════════════════════════
/// [positions] is where each symbol is drawn now, which the canvas knows
/// and the document does not: an unpinned symbol's place is the layout's
/// answer, recomputed on every build. Pinning stores that answer, so the
/// symbol does not move when it is pinned and does not move afterwards.
/// Unpinning keeps the stored position and clears the flag, and the layout
/// is free to move the symbol again.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE FIRST PIN CREATES THE ONE SHEET (§11.185.4)
/// ═══════════════════════════════════════════════════════════════════════
/// CR-073's single schematic `Sheet` had no producer, so no document held
/// one and a pin had nowhere to live. The id of the sheet this may create,
/// and of every item, is minted ONCE and reused on redo, so anything a
/// later command resolves by id still resolves after an undo/redo pair,
/// which is `AddRackCommand`'s rule.
final class SetSymbolPinnedCommand extends Command<RackDocument> {
  SetSymbolPinnedCommand({
    required Map<Uuid, Pt> positions,
    required this.pinned,
    required this.now,
    required this.actor,
  }) : positions = Map<Uuid, Pt>.unmodifiable(positions),
       _moved = false;

  /// A DRAG OR A NUDGE (DR-187 §11.186.4, `#918`): the same write, named
  /// after the act instead of after its side effect.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A NAMED CONSTRUCTOR AND NOT A SECOND COMMAND
  /// ═══════════════════════════════════════════════════════════════════
  /// *"Any manual move sets `SheetItem.pinned = true`"* (CR-068), so a
  /// move and a pin are one write to the document and differ only in what
  /// the person believes they did. A second command would be a second
  /// place that knows how to create the one `Sheet`, mint an item and
  /// restore a previous position, which is three chances for two writers
  /// to drift. **What a second command would have bought is one enum
  /// value**, and this buys it for a field.
  SetSymbolPinnedCommand.move({
    required Map<Uuid, Pt> positions,
    required this.now,
    required this.actor,
  }) : positions = Map<Uuid, Pt>.unmodifiable(positions),
       pinned = true,
       _moved = true;

  /// Whether this was a drag rather than a pin. Reaches [label] and
  /// nothing else: the document cannot tell the two apart and must not,
  /// because CR-068 says a manual move IS a pin.
  final bool _moved;

  /// Each symbol's drawn position. Only the keys are read when unpinning.
  final Map<Uuid, Pt> positions;

  /// The value to store.
  final bool pinned;

  final DateTime now;
  final String actor;

  late final Uuid _sheetId = newEntityId();
  final Map<Uuid, Uuid> _itemIds = {};

  Uuid? _createdSheet;
  final List<Uuid> _createdItems = [];
  final Map<Uuid, ({Pt position, bool pinned})> _previous = {};
  bool _applied = false;

  @override
  LabelKey get label => _moved
      ? LabelKey.moveSymbol
      : pinned
      ? LabelKey.pinSymbol
      : LabelKey.unpinSymbol;

  /// `sheet`, which is `SheetItem`'s own epoch: positions, pinning,
  /// collapse (`command.dart`).
  @override
  EpochMask get touches => EpochMask.sheet;

  @override
  Iterable<Uuid> get affects => positions.keys;

  @override
  bool apply(RackDocument doc) {
    _createdSheet = null;
    _createdItems.clear();
    _previous.clear();

    final ids = positions.keys.where(doc.devices.containsKey).toList()
      ..sort((a, b) => a.v.compareTo(b.v));
    var sheet = schematicSheetOf(doc);
    if (sheet == null) {
      // NOTHING TO UNPIN on a document that has never pinned, and a sheet
      // created only to hold nothing would be a byte change for no act.
      if (!pinned || ids.isEmpty) return _applied = false;
      sheet = Sheet(
        id: _sheetId,
        number: 'T6',
        title: 'SYSTEM SCHEMATIC',
        order: nextOrder([for (final s in doc.sheets.values) s.order]),
        meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      );
      doc.sheets[sheet.id] = sheet;
      _createdSheet = sheet.id;
    }

    for (final id in ids) {
      final item = _itemFor(sheet, id);
      if (item == null) {
        if (!pinned) continue;
        final itemId = _itemIds.putIfAbsent(id, newEntityId);
        sheet.items[itemId] = SheetItem(
          id: itemId,
          targetId: id,
          position: positions[id]!,
          zOrder: nextOrder([for (final i in sheet.items.values) i.zOrder]),
          pinned: true,
        );
        _createdItems.add(itemId);
        continue;
      }
      final target = pinned ? positions[id]! : item.position;
      if (item.pinned == pinned && item.position == target) continue;
      _previous[item.id] = (position: item.position, pinned: item.pinned);
      item
        ..position = target
        ..pinned = pinned;
    }

    final changed =
        _createdSheet != null ||
        _createdItems.isNotEmpty ||
        _previous.isNotEmpty;
    if (!changed) return _applied = false;
    return _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('SetSymbolPinnedCommand.revert before apply().');
    }
    final sheet = schematicSheetOf(doc);
    if (sheet != null) {
      for (final itemId in _createdItems) {
        sheet.items.remove(itemId);
      }
      for (final entry in _previous.entries) {
        sheet.items[entry.key]
          ?..position = entry.value.position
          ..pinned = entry.value.pinned;
      }
    }
    final created = _createdSheet;
    if (created != null) doc.sheets.remove(created);
  }

  /// The item for [deviceId] on [sheet], lowest id first, which is the
  /// rule `schematic_scene.dart`'s `_pinnedPositions` reads by.
  static SheetItem? _itemFor(Sheet sheet, Uuid deviceId) {
    SheetItem? found;
    for (final item in sheet.items.values) {
      if (item.targetId != deviceId) continue;
      if (found == null || item.id.v.compareTo(found.id.v) < 0) found = item;
    }
    return found;
  }
}
