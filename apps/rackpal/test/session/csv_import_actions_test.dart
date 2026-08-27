// M3-F/2 (#160) and M3-F/3 (#161), docs/07 §5.3.
//
// ═══════════════════════════════════════════════════════════════════════
// THE WRITE PATH, WITHOUT A FILE OR A WIDGET TREE
// ═══════════════════════════════════════════════════════════════════════
// `commitCsvImport` is split out of `runCsvImport` precisely so these
// can exist: the interesting assertions are about the undo stack and the
// re-derivation, and neither needs a file dialog.
//
// The one that matters most is §5.3's own sentence, "the whole import is
// one undoable `Command`". A commit that pushed one entry per drop would
// look identical in the document and cost a person sixty presses to take
// back, which is not undoing an import.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/csv_import_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final DateTime _now = DateTime.utc(2026, 8, 10);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't');

DocumentController _controller({bool withRoom = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-import-actions'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  AddStructureCommand(
    title: 'Media Panel',
    designator: 'STR-1',
    now: _now,
    actor: 't',
  ).apply(doc);
  if (withRoom) {
    AddLocationCommand(
      name: 'Living Room',
      code: 'LR',
      order: nextLocationOrder(doc),
      now: _now,
      actor: 't',
    ).apply(doc);
  }
  return DocumentController(doc);
}

CsvTable _table(String text) {
  final read = readCsv(text);
  return switch (read) {
    CsvReadOk(:final table) => table,
    CsvReadRefused(:final message) => fail('refused: $message'),
  };
}

/// The choice the dialog would hand over for a table, with every guess
/// accepted and every box ticked.
CsvImportChoice _choice(DocumentController c, CsvTable table) =>
    CsvImportChoice(
      mapping: CsvMapping.guess(
        table: table,
        detection: detectCsvShape(table, c.doc.registries),
        registries: c.doc.registries,
      ),
      declinedLocations: const {},
      declinedMediaTokens: const {},
    );

String? _import(DocumentController c, String csv) {
  final table = _table(csv);
  return commitCsvImport(
    controller: c,
    table: table,
    choice: _choice(c, table),
  );
}

void main() {
  group('§5.3: the whole import is ONE undoable command', () {
    test('sixty drops cost one undo entry, not sixty', () {
      final c = _controller();
      final rows = [
        for (var n = 1; n <= 20; n++) 'Living Room,WP-$n,Cat6,3',
      ].join('\n');
      expect(_import(c, 'Room,Outlet,Cable Type,Qty\n$rows\n'), isNull);
      expect(c.doc.links.length, 60);

      c.undo.undo(c.doc);
      expect(
        c.doc.links,
        isEmpty,
        reason: 'one press takes the whole import back',
      );
    });

    test('undo also takes back the rooms and the cable types it invented', () {
      // The half that is easy to miss: an import that put the drops back
      // and left four rooms and a media type behind would leave the
      // project dirtier than it started.
      final c = _controller(withRoom: false);
      expect(_import(c, 'Room,Cable Type\nAttic,Cat6e\n'), isNull);
      expect(c.doc.locations.length, 1);
      expect(
        c.doc.registries.mediaTypes.containsKey(
          const MediaTypeId('media.cat6e'),
        ),
        isTrue,
      );

      c.undo.undo(c.doc);
      expect(c.doc.locations, isEmpty);
      expect(
        c.doc.registries.mediaTypes.containsKey(
          const MediaTypeId('media.cat6e'),
        ),
        isFalse,
      );
      expect(c.doc.links, isEmpty);
    });

    test('redo puts it all back', () {
      final c = _controller();
      _import(c, 'Room,Cable Type,Qty\nLiving Room,Cat6,4\n');
      c.undo.undo(c.doc);
      c.undo.redo(c.doc);
      expect(c.doc.links.length, 4);
    });
  });

  group('a second pass over an unchanged sheet', () {
    test('costs no undo entry at all', () {
      // Re-importing an unchanged sheet is the ordinary second pass, and
      // an empty transaction would cost a person an undo step that
      // undoes nothing.
      final c = _controller();
      const sheet = 'Room,Outlet,Cable Type,Qty\nLiving Room,WP-1,Cat6,2\n';
      _import(c, sheet);
      final before = c.doc.links.length;

      expect(_import(c, sheet), isNull);
      expect(c.doc.links.length, before);

      // One undo returns to the pre-import state, which it could not do
      // if the no-op had pushed an entry of its own.
      c.undo.undo(c.doc);
      expect(c.doc.links, isEmpty);
    });
  });

  group('the plan is re-derived against the document AT COMMIT TIME', () {
    test('a room created behind the dialog is matched, not duplicated', () {
      // The scenario the re-derivation exists for: the operator opens
      // the import, and something else (a second window, an undo, a
      // starter load) adds the room before they press Import. A plan
      // captured when the dialog opened would create a second one.
      final c = _controller(withRoom: false);
      final table = _table('Room,Cable Type\nLiving Room,Cat6\n');
      final choice = _choice(c, table);

      AddLocationCommand(
        name: 'Living Room',
        code: 'LR',
        order: nextLocationOrder(c.doc),
        now: _now,
        actor: 'somebody else',
      ).apply(c.doc);

      commitCsvImport(controller: c, table: table, choice: choice);
      expect(c.doc.locations.length, 1);
      expect(c.doc.links.length, 1);
    });
  });

  group('refusals reach the caller as a sentence', () {
    test('a project with no Structure device says so and writes nothing', () {
      final doc = RackDocument(
        id: const Uuid('doc-no-structure'),
        appVersion: '0.1.0',
        createdAt: _now,
        modifiedAt: _now,
        meta: _meta(),
      )..registries = buildSeedRegistries();
      final c = DocumentController(doc);
      final table = _table('Room,Cable Type\nAttic,Cat6\n');
      final refusal = commitCsvImport(
        controller: c,
        table: table,
        choice: _choice(c, table),
      );
      expect(refusal, isNotNull);
      expect(c.doc.links, isEmpty);
      expect(c.doc.locations, isEmpty);
    });
  });

  group("RJ-012's minted type can actually be labelled", () {
    test('an unrecognised cable imports, with the spelling as its tag', () {
      // FOUND BY THIS TEST FAILING. DR-023's label chain ends at
      // `MediaTypeDef.shortTag` and `buildDropsFor` REFUSES a drop whose
      // chain yields nothing rather than printing `media.cat6e` on a
      // wall plate. Every type RJ-012 minted had no tag, so "never a
      // rejected row" rejected every row naming an unrecognised cable
      // unless the sheet happened to carry a `Use` column. DR-023
      // §11.22.4 named the hole; M3-F/6 is what made it reachable.
      final c = _controller();
      expect(_import(c, 'Room,Cable Type\nLiving Room,Cat6e\n'), isNull);
      expect(c.doc.links.length, 1);
      expect(
        c.doc.registries.mediaTypes[const MediaTypeId('media.cat6e')]?.shortTag,
        'CAT6E',
      );
      // And the drop carries a real label rather than an id.
      final label = c.doc.links.values.single.structureOrigin!.fieldLabel;
      expect(label, contains('CAT6E'));
      expect(label, isNot(contains('media.')));
    });
  });

  group('a row that cannot be built does not fail the import', () {
    test('the rest still land and the failure is reported', () {
      // §5.3, never fail-fast. The reachable refusal is now a LABEL
      // one: a room with no code cannot fill `{ROOM_ABBR}`, so its
      // drops cannot be named. The other room's row is unaffected.
      final c = _controller();
      AddLocationCommand(
        name: 'Nameless',
        code: '',
        order: nextLocationOrder(c.doc),
        now: _now,
        actor: 't',
      ).apply(c.doc);

      final refusal = _import(
        c,
        'Room,Cable Type\nLiving Room,Cat6\nNameless,Cat6\n',
      );
      expect(c.doc.links.length, 1, reason: 'the good row landed');
      expect(refusal, isNotNull, reason: 'and the other one was named');
      expect(refusal, contains('3'), reason: 'by its line number');
    });
  });
}
