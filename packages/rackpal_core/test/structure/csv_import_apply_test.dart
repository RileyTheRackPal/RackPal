// M3-F/6 (#652), docs/07 §5.3, RJ-012.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ROUND TRIP IS THE TEST, BECAUSE IDEMPOTENCE IS THE PROPERTY
// ═══════════════════════════════════════════════════════════════════════
// Every important case here does the same three things: import a sheet,
// APPLY what it built, then import the identical sheet again and assert
// the second pass creates nothing. That is the only shape of test that
// can catch the failure §5.3 names, because a dedup that duplicates
// passes every single-pass assertion ever written.
//
// It also catches the subtler one. RJ-012 mints a media type from an
// unrecognised spelling; if the minted type does not carry that spelling
// as an alias, the second pass fails to resolve `Cat6e` all over again
// and mints `media.cat6e_2`. Nothing about a single import shows it.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 10);
final Registries _registries = buildSeedRegistries();

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

final class _Doc {
  _Doc()
    : doc = RackDocument(
        id: const Uuid('doc-csv-apply'),
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
}

CsvImportPlan _plan(_Doc d, String csv) {
  final read = readCsv(csv);
  final table = switch (read) {
    CsvReadOk(:final table) => table,
    CsvReadRefused(:final message) => fail('refused: $message'),
  };
  return planCsvImport(
    doc: d.doc,
    rows: resolveCsvRows(
      table: table,
      mapping: CsvMapping.guess(
        table: table,
        detection: detectCsvShape(table, _registries),
        registries: _registries,
      ),
      registries: d.doc.registries,
      settings: d.doc.settings,
    ),
  );
}

CsvImportReady _build(_Doc d, String csv) {
  final built = buildCsvImport(
    doc: d.doc,
    plan: _plan(d, csv),
    now: _when,
    actor: 'test',
    structureBodyId: d.bodyId,
  );
  return switch (built) {
    CsvImportReady() => built,
    CsvImportRefused(:final reason) => fail('refused: $reason'),
  };
}

/// Import and apply, the way the app layer will: build the whole list,
/// then apply all of it or none of it.
CsvImportReady _import(_Doc d, String csv) {
  final built = _build(d, csv);
  for (final c in built.commands) {
    c.apply(d.doc);
  }
  return built;
}

void main() {
  group('a first import into an empty project', () {
    test('creates the rooms, the plates and the drops', () {
      final d = _Doc();
      final built = _import(
        d,
        'Room,Outlet,Cable Type,Qty\n'
        'Living Room,WP-1,Cat6,2\n'
        'Living Room,WP-1,RG6,1\n'
        'Attic,AP-1,Cat6,1\n',
      );
      expect(built.createdDrops, 4);
      expect(d.doc.links.length, 4);
      expect(d.doc.locations.length, 2);
      // Two rows sharing (room, plate) are ONE plate: §5.3.2's join rule
      // deciding that two new rows are one new outlet.
      expect(d.doc.outlets.length, 2);
      expect(built.warnings, isEmpty);
    });

    test('every drop lands on the named Structure body with a label', () {
      final d = _Doc();
      _import(d, 'Room,Cable Type,Qty\nAttic,Cat6,3\n');
      final origins = d.doc.links.values
          .map((l) => l.structureOrigin)
          .whereType<StructureOrigin>()
          .toList();
      expect(origins.length, 3);
      expect(origins.every((o) => o.structureBodyId == d.bodyId), isTrue);
      // CR-113: unique project-wide, and three rows arriving at once is
      // exactly where a shared reservation set earns its place.
      expect(origins.map((o) => o.fieldLabel).toSet().length, 3);
    });

    test('a derived room code is suggested, and two rooms never share one', () {
      final d = _Doc();
      _import(
        d,
        'Room,Cable Type\nLiving Room,Cat6\nLaundry Room,Cat6\nAttic,Cat6\n',
      );
      final codes = d.doc.locations.values.map((l) => l.code).toList();
      expect(codes, containsAll(['LR', 'AT']));
      expect(codes.toSet().length, codes.length);
    });
  });

  group('re-import is idempotent (§5.3), which is the whole point', () {
    test('the same sheet twice creates nothing the second time', () {
      final d = _Doc();
      const sheet =
          'Room,Outlet,Cable Type,Qty\n'
          'Living Room,WP-1,Cat6,2\n'
          'Attic,AP-1,Cat6,1\n';
      _import(d, sheet);
      expect(d.doc.links.length, 3);

      final second = _plan(d, sheet);
      expect(second.createCount, 0);
      expect(second.unchangedCount, 3);
      expect(second.newLocationNames, isEmpty);
      expect(_import(d, sheet).createdDrops, 0);
      expect(d.doc.links.length, 3, reason: 'no phantom drops');
    });

    test("RJ-012's minted type carries the spelling that made it", () {
      // The failure this catches: without the alias, pass two fails to
      // resolve `Cat6e` all over again and mints `media.cat6e_2`, and
      // nothing about a single import shows it.
      final d = _Doc();
      _import(d, 'Room,Cable Type\nAttic,Cat6e\n');
      final minted = d.doc.registries.mediaTypes.keys
          .where((k) => k.v.contains('cat6e'))
          .toList();
      expect(minted.length, 1);
      expect(minted.single, const MediaTypeId('media.cat6e'));

      _import(d, 'Room,Cable Type\nAttic,Cat6e\n');
      expect(
        d.doc.registries.mediaTypes.keys
            .where((k) => k.v.contains('cat6e'))
            .length,
        1,
        reason: 'a second pass must not mint media.cat6e_2',
      );
    });

    test('a revised sheet updates in place and adds no drops', () {
      final d = _Doc();
      const first =
          'Room,Outlet,Cable Type,Qty,Status\n'
          'Living Room,WP-1,Cat6,2,planned\n';
      _import(d, first);
      final ids = d.doc.links.keys.toSet();

      final built = _import(
        d,
        'Room,Outlet,Cable Type,Qty,Status,Notes\n'
        'Living Room,WP-1,Cat6,2,terminated,pulled Tuesday\n',
      );
      expect(built.updatedDrops, 2);
      expect(built.createdDrops, 0);
      expect(d.doc.links.keys.toSet(), ids, reason: 'the same two drops');
      expect(
        d.doc.links.values.every(
          (l) => l.roughInStatus == RoughInStatus.terminated,
        ),
        isTrue,
      );
      expect(
        d.doc.links.values.every((l) => l.notes == 'pulled Tuesday'),
        isTrue,
      );
    });
  });

  group('§5.3.5: what a sheet does not say, it does not change', () {
    test('a blank column leaves an in-app edit alone', () {
      final d = _Doc();
      _import(
        d,
        'Room,Outlet,Cable Type,Notes\nLiving Room,WP-1,Cat6,from the sheet\n',
      );
      // Somebody edits it in the app.
      final id = d.doc.links.keys.single;
      buildSetEntityProperty(
        doc: d.doc,
        id: id,
        field: LinkField.notes,
        to: 'corrected on site',
        now: _when,
        actor: 'test',
      )!.apply(d.doc);

      // The sheet is re-exported without its Notes column filled.
      _import(d, 'Room,Outlet,Cable Type,Notes\nLiving Room,WP-1,Cat6,\n');
      expect(d.doc.links[id]!.notes, 'corrected on site');
    });
  });

  group('the pathway a run travels in', () {
    test('a Bundle column files new drops under one pathway', () {
      final d = _Doc();
      _import(
        d,
        'Room,Outlet,Cable Type,Bundle\n'
        'Living Room,WP-1,Cat6,LR-TV\n'
        'Living Room,WP-1,RG6,LR-TV\n',
      );
      expect(d.doc.pathways.length, 1);
    });

    test('a CHANGED Bundle re-files an existing run', () {
      // The row `LinkField.pathwayId` was added for: before it, a run
      // could be filed under a pathway at creation and never re-filed,
      // so the plan would count a change the applier could not make.
      final d = _Doc();
      _import(
        d,
        'Room,Outlet,Cable Type,Bundle\nLiving Room,WP-1,Cat6,LR-TV\n',
      );
      final id = d.doc.links.keys.single;
      final first = d.doc.links[id]!.pathwayId;
      expect(first, isNotNull);

      final built = _import(
        d,
        'Room,Outlet,Cable Type,Bundle\nLiving Room,WP-1,Cat6,LR-CEILING\n',
      );
      expect(built.updatedDrops, 1);
      expect(d.doc.links[id]!.pathwayId, isNot(first));
      expect(d.doc.pathways.length, 2);
    });
  });

  group('the whole import is one transaction, or none of it', () {
    test('the command order lets a drop refer to a room being created', () {
      // Creations first, then drops, then updates. Applying them in
      // source order has to work against a document that holds none of
      // them yet.
      final d = _Doc();
      final built = _build(d, 'Room,Cable Type\nAttic,Cat6\n');
      expect(built.commands.first, isA<AddLocationCommand>());
      // And applying in that order does not throw.
      for (final c in built.commands) {
        c.apply(d.doc);
      }
      expect(d.doc.links.length, 1);
    });

    test(
      'reverting every command in reverse leaves the document as it was',
      () {
        final d = _Doc()..room('Living Room', 'LR');
        final before = (
          links: d.doc.links.length,
          locations: d.doc.locations.length,
          outlets: d.doc.outlets.length,
          media: d.doc.registries.mediaTypes.length,
        );
        final built = _build(
          d,
          'Room,Outlet,Cable Type,Qty\n'
          'Living Room,WP-1,Cat6,2\n'
          'Attic,AP-1,Cat6e,1\n',
        );
        for (final c in built.commands) {
          c.apply(d.doc);
        }
        for (final c in built.commands.reversed) {
          c.revert(d.doc);
        }
        expect(d.doc.links.length, before.links);
        expect(d.doc.locations.length, before.locations);
        expect(d.doc.outlets.length, before.outlets);
        // Including the media type RJ-012 minted: undoing an import has to
        // take the cable type back out of the registry too.
        expect(d.doc.registries.mediaTypes.length, before.media);
      },
    );
  });

  group('refusals about the whole import', () {
    test('a project with no Structure device is refused with a sentence', () {
      final doc = RackDocument(
        id: const Uuid('doc-no-structure'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      )..registries = buildSeedRegistries();
      final built = buildCsvImport(
        doc: doc,
        plan: const CsvImportPlan(
          rows: [],
          newLocationNames: [],
          newMediaTokens: [],
          newPathwayNames: [],
          issues: [],
        ),
        now: _when,
        actor: 'test',
      );
      expect(built, isA<CsvImportRefused>());
    });
  });
  group('an imported rack label (DR-075, `#727`)', () {
    // ═══════════════════════════════════════════════════════════════
    // TWO CLAIMS, AND THE SECOND WAS A LIVE DEFECT BEFORE THE FIRST
    // ═══════════════════════════════════════════════════════════════
    // §11.74.1: a `rack_label` column is a person choosing an
    // identifier, so it LOCKS and a later move keeps it.
    //
    // §11.74.2: the importer passed `usedFieldLabels(doc)` into every
    // origin field's `alsoUsedLabels`, and the rack label's uniqueness
    // check reads `alsoUsedRackLabels`, which nothing filled. Two rows
    // of one sheet could write one label onto two drops.
    //
    // BOTH CASES NEED TWO PASSES, and that is why the round-trip suite
    // above never met either: a drop CREATED by an import takes no rack
    // label from the sheet, so this write path is reachable only on the
    // update pass.

    test('locks, so a later move keeps it (§11.74.1)', () {
      final d = _Doc();
      _import(d, 'Room,Outlet,Cable Type,Qty\nLiving Room,WP-1,Cat6,1\n');
      expect(
        d.doc.links.values.single.structureOrigin!.rackLabelLocked,
        isFalse,
        reason: 'nothing has named it yet',
      );

      _import(
        d,
        'Room,Outlet,Cable Type,Qty,Rack Label\n'
        'Living Room,WP-1,Cat6,1,PP1-05\n',
      );
      final origin = d.doc.links.values.single.structureOrigin!;
      expect(origin.rackLabel, 'PP1-05');
      expect(
        origin.rackLabelLocked,
        isTrue,
        reason:
            'they typed it into a spreadsheet instead of into the cell, '
            'which is the same act through a different door',
      );
    });

    test('two rows of ONE sheet cannot share one (CR-113, §11.74.2)', () {
      // THE DEFECT THIS FILE EXISTS TO KEEP FIXED. Measured before the
      // fix: this exact sheet wrote `PP1-05` onto both drops.
      final d = _Doc();
      _import(
        d,
        'Room,Outlet,Cable Type,Qty\n'
        'Living Room,WP-1,Cat6,1\n'
        'Attic,AP-1,Cat6,1\n',
      );
      _import(
        d,
        'Room,Outlet,Cable Type,Qty,Rack Label\n'
        'Living Room,WP-1,Cat6,1,PP1-05\n'
        'Attic,AP-1,Cat6,1,PP1-05\n',
      );

      final labels = d.doc.links.values
          .map((l) => l.structureOrigin?.rackLabel)
          .whereType<String>()
          .toList();
      expect(labels, ['PP1-05'], reason: 'the second row is skipped');
    });

    test('a label another drop ALREADY holds is skipped, not written', () {
      // The against-document half, which the reservation now matches.
      final d = _Doc();
      _import(
        d,
        'Room,Outlet,Cable Type,Qty\n'
        'Living Room,WP-1,Cat6,1\n'
        'Attic,AP-1,Cat6,1\n',
      );
      _import(
        d,
        'Room,Outlet,Cable Type,Qty,Rack Label\n'
        'Living Room,WP-1,Cat6,1,PP1-05\n',
      );
      _import(
        d,
        'Room,Outlet,Cable Type,Qty,Rack Label\n'
        'Attic,AP-1,Cat6,1,PP1-05\n',
      );

      final labels = d.doc.links.values
          .map((l) => l.structureOrigin?.rackLabel)
          .whereType<String>()
          .toList();
      expect(labels, ['PP1-05']);
    });

    test('the rest of the row still applies when the label is skipped', () {
      // §11.74.3: a skip is per FIELD, not per row. The importer has
      // always behaved this way for an origin field and the reservation
      // must not change it into an all-or-nothing refusal.
      final d = _Doc();
      _import(
        d,
        'Room,Outlet,Cable Type,Qty\n'
        'Living Room,WP-1,Cat6,1\n'
        'Attic,AP-1,Cat6,1\n',
      );
      _import(
        d,
        'Room,Outlet,Cable Type,Qty,Rack Label\n'
        'Living Room,WP-1,Cat6,1,PP1-05\n',
      );
      _import(
        d,
        'Room,Outlet,Cable Type,Qty,Rack Label,Bundle\n'
        'Attic,AP-1,Cat6,1,PP1-05,Riser A\n',
      );

      final attic = d.doc.links.values.firstWhere(
        (l) => l.structureOrigin!.rackLabel == null,
      );
      expect(
        attic.pathwayId,
        isNotNull,
        reason: 'the colliding label was skipped; the row was not',
      );
      expect(d.doc.pathways.values.single.name, 'Riser A');
    });
  });
}
