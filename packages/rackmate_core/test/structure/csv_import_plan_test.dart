// M3-F/6 (#652), docs/07 §5.3.
//
// ═══════════════════════════════════════════════════════════════════════
// IDEMPOTENCE IS THE PROPERTY, SO RE-IMPORT IS THE TEST
// ═══════════════════════════════════════════════════════════════════════
// §5.3: "Re-importing a corrected spreadsheet is therefore idempotent,
// which is the whole point, the pull list gets revised three times
// before drywall." Half the cases here import a file, apply what it
// planned, and import it again: the second pass must plan zero creates.
// A dedup that quietly duplicates passes every single-pass test and
// gives a job sixty phantom drops in the week the labels are printed.
//
// The other half are §5.3.5's counts, because #161 confirms them and a
// confirm that overstates what it is about to do trains the operator to
// click through it.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 10);
final Registries _registries = buildSeedRegistries();

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

final class _Doc {
  _Doc()
    : doc = RackDocument(
        id: const Uuid('doc-csv-plan'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      ) {
    doc.registries = buildSeedRegistries();
    bodyId = (AddStructureCommand(
      title: 'Rough-In',
      designator: 'STR-1',
      now: _when,
      actor: 'test',
    )..apply(doc)).bodyId;
  }

  final RackDocument doc;
  late final Uuid bodyId;

  Uuid room(String name, String code) => (AddLocationCommand(
    name: name,
    code: code,
    order: nextLocationOrder(doc),
    now: _when,
    actor: 'test',
  )..apply(doc)).id;

  /// Creates the drops a line of CSV asks for, the way the typed-line
  /// surface does, so the plan has real work to match against.
  void drops(String line) {
    final parsed = parseDropLine(line);
    final plan = planDropLine(
      doc: doc,
      line: parsed as DropLineParsed,
      now: _when,
      actor: 'test',
      structureBodyId: bodyId,
    );
    for (final c in (plan as DropLinePlanReady).commands) {
      c.apply(doc);
    }
  }
}

CsvImportPlan _plan(_Doc d, String csv) {
  final read = readCsv(csv);
  final table = switch (read) {
    CsvReadOk(:final table) => table,
    CsvReadRefused(:final message) => fail('refused: $message'),
  };
  final mapping = CsvMapping.guess(
    table: table,
    detection: detectCsvShape(table, _registries),
    registries: _registries,
  );
  return planCsvImport(
    doc: d.doc,
    rows: resolveCsvRows(
      table: table,
      mapping: mapping,
      registries: _registries,
      settings: d.doc.settings,
    ),
  );
}

void main() {
  group('an empty project: everything is a create', () {
    test('the counts are the drops, not the rows', () {
      final d = _Doc()..room('Living Room', 'LR');
      final p = _plan(d, 'Room,Cable Type,Qty\nLiving Room,Cat6,4\n');
      expect(p.createCount, 4);
      expect(p.updateCount, 0);
      expect(p.unchangedCount, 0);
      // Nothing existing is touched, so #161's dialog does not arm.
      expect(p.touchesExistingWork, isFalse);
    });

    test('a room the project does not have is offered, once', () {
      final p = _plan(
        _Doc(),
        'Room,Cable Type\nAttic,Cat6\nAttic,RG6\nGarage,Cat6\n',
      );
      expect(p.newLocationNames, ['Attic', 'Garage']);
    });

    test('RJ-012 mints one type per SPELLING, not one per row', () {
      // Forty `Cat6e` rows are one new type and forty drops on it.
      final p = _plan(
        _Doc(),
        'Room,Cable Type\nA,Cat6e\nA,Cat6e\nA,Cat6e\n',
      );
      expect(p.newMediaTokens, ['Cat6e']);
    });

    test('a pathway the project does not have is named once', () {
      final p = _plan(
        _Doc(),
        'Room,Cable Type,Bundle\nA,Cat6,LR-TV\nA,RG6,LR-TV\n',
      );
      expect(p.newPathwayNames, ['LR-TV']);
    });
  });

  group('§5.3 matching', () {
    test('a room matches by name, and whitespace does not defeat it', () {
      // Trim alone would create a second room from a double space
      // nobody can see in the spreadsheet that produced it.
      final d = _Doc()..room('Living Room', 'LR');
      expect(
        _plan(d, 'Room,Cable Type\nliving  room,Cat6\n').newLocationNames,
        isEmpty,
      );
    });

    test('a room matches by CODE when the name does not match', () {
      final d = _Doc()..room('Living Room', 'LR');
      expect(
        _plan(d, 'Room,Cable Type\nLR,Cat6\n').newLocationNames,
        isEmpty,
      );
    });

    test('an outlet is matched per ROOM, so two rooms may share WP-1', () {
      // §5.3.2's key is `(locationId, designation)`. Designation alone
      // would make the Attic row update the Living Room's plate.
      final d = _Doc()
        ..room('Living Room', 'LR')
        ..room('Attic', 'AT')
        ..drops('Living Room: 1x Cat6 @outlet="WP-1"');
      final p = _plan(d, 'Room,Outlet,Cable Type\nAttic,WP-1,Cat6\n');
      expect(p.createCount, 1);
      expect(p.updateCount, 0);
    });
  });

  group('§5.3.4 dedup, and the idempotence it exists for', () {
    test('re-importing the same sheet plans no creates at all', () {
      final d = _Doc()
        ..room('Living Room', 'LR')
        ..drops('Living Room: 2x Cat6 @outlet="WP-1"');
      const sheet = 'Room,Outlet,Cable Type,Qty\nLiving Room,WP-1,Cat6,2\n';
      final p = _plan(d, sheet);
      expect(p.createCount, 0);
      // Nothing in the sheet differs from what is there.
      expect(p.unchangedCount, 2);
      expect(p.updateCount, 0);
    });

    test('a revised sheet UPDATES rather than duplicating', () {
      final d = _Doc()
        ..room('Living Room', 'LR')
        ..drops('Living Room: 2x Cat6 @outlet="WP-1"');
      final p = _plan(
        d,
        'Room,Outlet,Cable Type,Qty,Status\n'
        'Living Room,WP-1,Cat6,2,terminated\n',
      );
      expect(p.updateCount, 2);
      expect(p.createCount, 0);
      expect(p.touchesExistingWork, isTrue);
    });

    test('two rows in one file take two different drops', () {
      // §5.3.4's ordinal-within-group. Without it both rows would fight
      // over the first drop and the second would look like a create.
      final d = _Doc()
        ..room('Living Room', 'LR')
        ..drops('Living Room: 2x Cat6 @outlet="WP-1"');
      final p = _plan(
        d,
        'Room,Outlet,Cable Type,Status\n'
        'Living Room,WP-1,Cat6,pulled\n'
        'Living Room,WP-1,Cat6,pulled\n',
      );
      final matched = p.rows.expand((r) => r.matchedLinkIds).toSet();
      expect(matched.length, 2);
      expect(p.createCount, 0);
    });

    test('a sheet asking for MORE than exists is part update, part create', () {
      final d = _Doc()
        ..room('Living Room', 'LR')
        ..drops('Living Room: 2x Cat6 @outlet="WP-1"');
      final p = _plan(
        d,
        'Room,Outlet,Cable Type,Qty,Status\n'
        'Living Room,WP-1,Cat6,5,terminated\n',
      );
      // The three totals still add up to the five drops on the sheet.
      expect(p.updateCount, 2);
      expect(p.createCount, 3);
    });

    test('a stated field label matches project-wide, ignoring the tuple', () {
      // CR-113 makes the label unique project-wide, so a drop that moved
      // room between revisions is the same drop and the label says so.
      final d = _Doc()
        ..room('Living Room', 'LR')
        ..drops('Living Room: 1x Cat6 @outlet="WP-1"');
      final label = d.doc.links.values.single.structureOrigin!.fieldLabel;
      final p = _plan(
        d,
        'Room,Outlet,Cable Type,Label,Status\n'
        'Attic,CLG-9,Cat6,$label,terminated\n',
      );
      expect(p.updateCount, 1);
      expect(p.createCount, 0);
    });

    test('a label matching nothing is a NEW drop, not a failed lookup', () {
      final d = _Doc()..room('Living Room', 'LR');
      final p = _plan(
        d,
        'Room,Cable Type,Label\nLiving Room,Cat6,LR-DATA-99\n',
      );
      expect(p.createCount, 1);
    });
  });

  group('§5.3.5: an empty cell never overwrites', () {
    test('a sheet with only lengths leaves everything else alone', () {
      // What makes a revised sheet safe to re-import over a document
      // somebody has been editing all week: the columns it does not
      // fill are not columns it clears.
      final d = _Doc()
        ..room('Living Room', 'LR')
        ..drops('Living Room: 1x Cat6 @outlet="WP-1" @status=terminated');
      final p = _plan(
        d,
        'Room,Outlet,Cable Type,Notes\nLiving Room,WP-1,Cat6,\n',
      );
      // The blank Notes column states nothing, so nothing changes.
      expect(p.unchangedCount, 1);
      expect(p.updateCount, 0);
    });

    test('a non-empty differing value DOES overwrite', () {
      final d = _Doc()
        ..room('Living Room', 'LR')
        ..drops('Living Room: 1x Cat6 @outlet="WP-1"');
      final p = _plan(
        d,
        'Room,Outlet,Cable Type,Notes\nLiving Room,WP-1,Cat6,soffit run\n',
      );
      expect(p.updateCount, 1);
    });
  });

  group('rows that do nothing are counted, never omitted', () {
    test('a row with no room is skipped and says so', () {
      final p = _plan(_Doc(), 'Room,Cable Type\n,Cat6\nAttic,Cat6\n');
      expect(p.skippedRowCount, 1);
      expect(p.createCount, 1);
    });

    test('a row naming no cable is skipped', () {
      final p = _plan(_Doc(), 'Room,Cable Type\nAttic,\n');
      expect(p.skippedRowCount, 1);
      expect(p.createCount, 0);
    });
  });

  group('§5.3.6: duplicate labels are flagged, not blocked (G3)', () {
    test('two rows sharing a label raise one issue naming both lines', () {
      final p = _plan(
        _Doc(),
        'Room,Cable Type,Label\n'
        'Attic,Cat6,LR-DATA-1\n'
        'Garage,Cat6,LR-DATA-1\n',
      );
      final issue = p.issues.single;
      expect(issue.severity, CsvIssueSeverity.warning);
      expect(issue.message, contains('2, 3'));
      // Flagged, not blocked: both rows still plan.
      expect(p.createCount, 2);
    });

    test('distinct labels raise nothing', () {
      final p = _plan(
        _Doc(),
        'Room,Cable Type,Label\nAttic,Cat6,A-1\nGarage,Cat6,A-2\n',
      );
      expect(p.issues, isEmpty);
    });
  });

  group('the wide shape plans the same way', () {
    test('one row becomes drops of several types', () {
      final d = _Doc()..room('Living Room', 'LR');
      final p = _plan(
        d,
        'Room,Cat6,RG6\nLiving Room,4,2\nAttic,1,1\n',
      );
      expect(p.createCount, 8);
      expect(p.newLocationNames, ['Attic']);
    });
  });
}
