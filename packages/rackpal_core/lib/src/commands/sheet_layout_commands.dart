// rackpal_core/src/commands/sheet_layout_commands.dart — the schematic
// keeps its layout (DR-187 §11.186, `#916` and `#920`).
//
// ═══════════════════════════════════════════════════════════════════════
// TWO COMMANDS, AND THE SECOND IS THE WAY OUT OF THE FIRST
// ═══════════════════════════════════════════════════════════════════════
// [StoreSymbolPositionsCommand] is the freeze: it records where the
// symbols are so that the next edit does not move them.
// [TidySheetCommand] is what a person presses when the frozen sheet is a
// mess, and it is the reason the freeze is safe to ship: it clears every
// stored position that is not pinned and hands the sheet back to the
// layout (docs/05 §10, CR-068).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY A POSITION IS WRITTEN AT ALL, WHICH DR-011.4 REFUSED
// ═══════════════════════════════════════════════════════════════════════
// §11.11.4 rejected *"pinning every symbol on first layout"* because it
// *"would write a `SheetItem` per device into every document and grow the
// CR-117 byte surface to carry UI state"*. DR-187 §11.186.1 overrules that
// (canon §12.38) on the user's decision: a session-only hold loses the
// arrangement the moment the project is closed. The cost is paid where the
// ruling says and nowhere else: **on the first edit that would re-flow the
// sheet, never on opening one** (§11.186.2), so a document nobody has
// edited still carries no items at all.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/lock_commands.dart'
    show schematicSheetOf;
import 'package:rackpal_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/sheet.dart';
import 'package:rackpal_core/src/model/sheet_item.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/pt.dart';
import 'package:rackpal_core/src/util/id_gen.dart';

/// Records where symbols are, so the next edit leaves them there
/// (DR-187 §11.186.2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT ONLY EVER ADDS, AND IT NEVER PINS
/// ═══════════════════════════════════════════════════════════════════════
/// A device that already has a `SheetItem` is left exactly as it is,
/// pinned or not: this command's job is to give a position to the symbols
/// that have none, and overwriting one would move a symbol somebody placed.
/// The items it creates are UNPINNED, because storing is not pinning: the
/// layout honours both (§11.186.3) and `Tidy sheet` only re-flows these.
///
/// **Nothing to record is a refusal** (DR-156), so the common case of an
/// edit on an already-frozen sheet leaves no undo entry.
final class StoreSymbolPositionsCommand extends Command<RackDocument> {
  StoreSymbolPositionsCommand({
    required Map<Uuid, Pt> positions,
    required this.now,
    required this.actor,
  }) : positions = Map<Uuid, Pt>.unmodifiable(positions);

  /// Where each symbol was drawn BEFORE the edit that prompted this.
  final Map<Uuid, Pt> positions;

  final DateTime now;
  final String actor;

  late final Uuid _sheetId = newEntityId();
  final Map<Uuid, Uuid> _itemIds = {};

  Uuid? _createdSheet;
  final List<Uuid> _createdItems = [];
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.storeSymbolPositions;

  @override
  EpochMask get touches => EpochMask.sheet;

  @override
  Iterable<Uuid> get affects => positions.keys;

  @override
  bool apply(RackDocument doc) {
    _createdSheet = null;
    _createdItems.clear();

    final have = <Uuid>{
      for (final item
          in schematicSheetOf(doc)?.items.values ?? const <SheetItem>[])
        item.targetId,
    };
    final owed =
        positions.keys
            .where((id) => doc.devices.containsKey(id) && !have.contains(id))
            .toList()
          ..sort((a, b) => a.v.compareTo(b.v));
    if (owed.isEmpty) return _applied = false;

    var sheet = schematicSheetOf(doc);
    if (sheet == null) {
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
    for (final id in owed) {
      final itemId = _itemIds.putIfAbsent(id, newEntityId);
      sheet.items[itemId] = SheetItem(
        id: itemId,
        targetId: id,
        position: positions[id]!,
        zOrder: nextOrder([for (final i in sheet.items.values) i.zOrder]),
      );
      _createdItems.add(itemId);
    }
    return _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('StoreSymbolPositionsCommand.revert before apply().');
    }
    final sheet = schematicSheetOf(doc);
    if (sheet != null) {
      for (final id in _createdItems) {
        sheet.items.remove(id);
      }
    }
    final created = _createdSheet;
    if (created != null) doc.sheets.remove(created);
  }
}

/// Hands every unpinned symbol back to the layout (docs/05 §10, DR-187
/// §11.186.3, `#920`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT REMOVES THE ITEM RATHER THAN BLANKING IT
/// ═══════════════════════════════════════════════════════════════════════
/// A `SheetItem` whose position the layout ignores would be a row in the
/// file that means nothing, and the next freeze would have to decide
/// whether to overwrite it. Removing it restores exactly the state the
/// document had before anything was stored, which is also what makes
/// `Tidy` the honest way out of the freeze.
///
/// **A PINNED ITEM IS NEVER TOUCHED** (CR-068): the point of pinning is
/// that this command is the one thing that does not move it.
final class TidySheetCommand extends Command<RackDocument> {
  TidySheetCommand();

  final Map<Uuid, SheetItem> _removed = {};
  bool _applied = false;

  @override
  LabelKey get label => LabelKey.tidySheet;

  @override
  EpochMask get touches => EpochMask.sheet;

  @override
  Iterable<Uuid> get affects => _removed.values.map((i) => i.targetId);

  /// How many symbols a tidy would re-flow, for the confirmation that asks
  /// (docs/05 §10's *"behind a plain confirm"*).
  static int wouldReflow(RackDocument doc) => [
    for (final item
        in schematicSheetOf(doc)?.items.values ?? const <SheetItem>[])
      if (!item.pinned) item,
  ].length;

  @override
  bool apply(RackDocument doc) {
    _removed.clear();
    final sheet = schematicSheetOf(doc);
    if (sheet == null) return _applied = false;
    final going = [
      for (final item in sheet.items.values)
        if (!item.pinned) item,
    ]..sort((a, b) => a.id.v.compareTo(b.id.v));
    if (going.isEmpty) return _applied = false;
    for (final item in going) {
      _removed[item.id] = item;
      sheet.items.remove(item.id);
    }
    return _applied = true;
  }

  @override
  void revert(RackDocument doc) {
    if (!_applied) {
      throw StateError('TidySheetCommand.revert before apply().');
    }
    final sheet = schematicSheetOf(doc);
    if (sheet == null) return;
    // THE SAME OBJECTS, so an undo restores the bytes the file was read
    // from rather than items that merely compare equal.
    for (final entry in _removed.entries) {
      sheet.items[entry.key] = entry.value;
    }
  }
}
