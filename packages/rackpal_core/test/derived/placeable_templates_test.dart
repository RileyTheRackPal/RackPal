// What a document can place (DR-077 §11.76.1, board `#733`).
//
// The property under test is that the palette's source is the DOCUMENT.
// Every case here builds a document rather than a catalog, because the
// defect this replaces was a surface reading `buildSeedCatalog()` and
// therefore agreeing with itself forever.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-1'),
  appVersion: '0.4.0',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: testMeta(),
);

TemplateSnapshot _snapshot({
  required String id,
  required int version,
  String displayName = 'Thing',
  String category = '',
}) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: version,
  contentHash: 'unhashed:$id@$version',
  capturedAt: DateTime.utc(2026),
  body: TemplateBody(
    manufacturer: 'Generic',
    model: '',
    displayName: displayName,
    category: category,
    frontU: 1,
  ),
);

void main() {
  group('the shelf is the document', () {
    test('an empty document places nothing', () {
      expect(buildPlaceableTemplates(_doc()), isEmpty);
    });

    test('a seeded snapshot reads as seeded', () {
      final doc = _doc();
      doc.templates['V01@1'] = _snapshot(id: 'V01', version: 1);
      final rows = buildPlaceableTemplates(doc);
      expect(rows, hasLength(1));
      expect(rows.single.provenance, TemplateProvenance.seeded);
      expect(rows.single.isProjectAuthored, isFalse);
      expect(rows.single.documentKey, 'V01@1');
    });

    test('an id this build does not ship reads as project-authored', () {
      final doc = _doc();
      doc.templates['tpl.hdmi_matrix_16x16@1'] = _snapshot(
        id: 'tpl.hdmi_matrix_16x16',
        version: 1,
      );
      final rows = buildPlaceableTemplates(doc);
      expect(rows.single.provenance, TemplateProvenance.project);
      expect(rows.single.isProjectAuthored, isTrue);
    });

    // The whole point of the file: a document seeded the way
    // `blank_document.dart` seeds one offers every shipped archetype,
    // and it does so WITHOUT the caller naming the catalog.
    test('a document holding the seed catalog offers all 50, all seeded', () {
      final doc = _doc();
      for (final entry in buildSeedCatalog().entries) {
        doc.templates['${entry.key}@1'] = TemplateSnapshot(
          templateId: TemplateId(entry.key),
          version: 1,
          contentHash: 'sha256:seed-${entry.key}',
          capturedAt: DateTime.utc(2026),
          body: entry.value,
        );
      }
      final rows = buildPlaceableTemplates(doc);
      expect(rows, hasLength(buildSeedCatalog().length));
      expect(
        rows.every((r) => r.provenance == TemplateProvenance.seeded),
        isTrue,
      );
    });
  });

  group('the newest version of each id (CR-050)', () {
    test('two versions of one id are one row, at the newer', () {
      final doc = _doc();
      doc.templates['tpl.amp@1'] = _snapshot(
        id: 'tpl.amp',
        version: 1,
        displayName: 'Amp',
      );
      doc.templates['tpl.amp@2'] = _snapshot(
        id: 'tpl.amp',
        version: 2,
        displayName: 'Amp mk2',
      );
      final rows = buildPlaceableTemplates(doc);
      expect(rows, hasLength(1));
      expect(rows.single.version, 2);
      expect(rows.single.body.displayName, 'Amp mk2');
      expect(rows.single.documentKey, 'tpl.amp@2');
    });

    test('insertion order does not decide which version wins', () {
      final doc = _doc();
      doc.templates['tpl.amp@3'] = _snapshot(id: 'tpl.amp', version: 3);
      doc.templates['tpl.amp@1'] = _snapshot(id: 'tpl.amp', version: 1);
      doc.templates['tpl.amp@2'] = _snapshot(id: 'tpl.amp', version: 2);
      expect(buildPlaceableTemplates(doc).single.version, 3);
    });
  });

  group('the order is total and deterministic (§8.4)', () {
    test('rows sort by template id regardless of map order', () {
      final doc = _doc();
      for (final id in ['V03', 'tpl.zebra', 'A01', 'tpl.alpha']) {
        doc.templates['$id@1'] = _snapshot(id: id, version: 1);
      }
      expect(buildPlaceableTemplates(doc).map((r) => r.id).toList(), [
        'A01',
        'V03',
        'tpl.alpha',
        'tpl.zebra',
      ]);
    });

    test('two calls on one document agree', () {
      final doc = _doc();
      for (final id in ['V03', 'tpl.zebra', 'A01']) {
        doc.templates['$id@1'] = _snapshot(id: id, version: 1);
      }
      final first = buildPlaceableTemplates(doc).map((r) => r.rowKey).toList();
      final second = buildPlaceableTemplates(doc).map((r) => r.rowKey).toList();
      expect(first, second);
    });
  });

  group('nothing is filtered out', () {
    // A 0U occupant and a field device are refused AT PLACEMENT with a
    // sentence naming the reason (`catalog_placement.dart`). Dropping
    // them here would move that refusal somewhere with no voice.
    test('a template with no rail footprint is still a row', () {
      final doc = _doc();
      doc.templates['P01@1'] = TemplateSnapshot(
        templateId: const TemplateId('P01'),
        version: 1,
        contentHash: 'h',
        capturedAt: DateTime.utc(2026),
        body: TemplateBody(
          manufacturer: 'Generic',
          model: '',
          displayName: '0U PDU',
          side: OccupancySide.zeroUVertical,
        ),
      );
      expect(buildPlaceableTemplates(doc), hasLength(1));
    });

    test('a template with no category is still a row', () {
      final doc = _doc();
      doc.templates['tpl.nameless@1'] = _snapshot(
        id: 'tpl.nameless',
        version: 1,
      );
      expect(buildPlaceableTemplates(doc).single.body.category, isEmpty);
    });
  });

  group('kSeedCatalogIds', () {
    test('holds exactly the ids buildSeedCatalog ships', () {
      expect(kSeedCatalogIds, buildSeedCatalog().keys.toSet());
    });

    test('cannot be taught that this build ships something it does not', () {
      expect(() => kSeedCatalogIds.add('tpl.forgery'), throwsUnsupportedError);
    });
  });

  // ── `#241`, DR-102 §11.101.3 and §11.101.4 ──────────────────────────
  group('the shelf is the document AND the loaded libraries', () {
    test('an empty library is no rows and changes nothing', () {
      // The default is an empty list, so every pre-#241 caller keeps its
      // old answer without saying so. What is worth an assertion is that
      // a library CONTRIBUTING NOTHING is also not a row, which is the
      // shape an empty `.rmda` on the shelf has.
      final doc = _doc();
      doc.templates['V01@1'] = _snapshot(id: 'V01', version: 1);
      final rows = buildPlaceableTemplates(
        doc,
        libraries: [_library('empty-kit', 'Empty Kit', const [])],
      );
      expect(rows, hasLength(1));
      expect(rows.single.provenance, isA<SeededProvenance>());
    });

    test('a library template is a row, tagged with the library', () {
      final rows = buildPlaceableTemplates(
        _doc(),
        libraries: [
          _library('shop-kit', 'Shop Kit', [_entry('tpl.amp', 1)]),
        ],
      );
      expect(rows, hasLength(1));
      final p = rows.single.provenance;
      expect(p, isA<LibraryProvenance>());
      expect((p as LibraryProvenance).libraryId, 'shop-kit');
      expect(p.libraryName, 'Shop Kit');
    });

    // DR-103 §11.102.8. The whole reason the type changed.
    test('a library row has NO document key and a document row has one', () {
      final doc = _doc();
      doc.templates['tpl.mine@1'] = _snapshot(id: 'tpl.mine', version: 1);
      final rows = buildPlaceableTemplates(
        doc,
        libraries: [
          _library('kit', 'Kit', [_entry('tpl.theirs', 1)]),
        ],
      );
      expect(_row(rows, 'tpl.mine').documentKey, 'tpl.mine@1');
      expect(_row(rows, 'tpl.theirs').documentKey, isNull);
    });

    // DR-102 §11.101.5: `isProjectAuthored` survives, and a library row
    // answers false to it. `exportableLibraryTemplates` filters on this,
    // so a true here would re-export somebody else's library.
    test('a library row is not project-authored', () {
      final rows = buildPlaceableTemplates(
        _doc(),
        libraries: [
          _library('kit', 'Kit', [_entry('tpl.amp', 1)]),
        ],
      );
      expect(rows.single.isProjectAuthored, isFalse);
      expect(rows.single.library?.libraryId, 'kit');
    });

    test('a document row reports no library', () {
      final doc = _doc();
      doc.templates['tpl.mine@1'] = _snapshot(id: 'tpl.mine', version: 1);
      expect(buildPlaceableTemplates(doc).single.library, isNull);
    });
  });

  // ── DR-102 §11.101.4, and it is the COMMON case ─────────────────────
  group('a template id in two sources is two rows', () {
    test('the document and a library both offering an id give two rows', () {
      final doc = _doc();
      doc.templates['tpl.hdmi_matrix_16x16@1'] = _snapshot(
        id: 'tpl.hdmi_matrix_16x16',
        version: 1,
        displayName: 'HDMI Matrix 16x16',
      );
      final rows = buildPlaceableTemplates(
        doc,
        libraries: [
          _library('shop-kit', 'Shop Kit', [
            _entry('tpl.hdmi_matrix_16x16', 1),
          ]),
        ],
      );
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.id).toSet(), {'tpl.hdmi_matrix_16x16'});
      expect(rows.map((r) => r.provenance.sourceKey).toList(), [
        'project',
        'library:shop-kit',
      ]);
    });

    test('two libraries offering one id give two rows, one each', () {
      final rows = buildPlaceableTemplates(
        _doc(),
        libraries: [
          _library('a-kit', 'A Kit', [_entry('tpl.amp', 1)]),
          _library('b-kit', 'B Kit', [_entry('tpl.amp', 1)]),
        ],
      );
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.provenance.sourceKey).toList(), [
        'library:a-kit',
        'library:b-kit',
      ]);
    });

    // The identity a `ValueKey` needs. `id` stopped being unique across
    // rows the moment libraries joined, and a duplicate `ValueKey` in a
    // `ListView` is a framework error rather than a wrong row.
    test('rowKey is unique across colliding rows where id is not', () {
      final doc = _doc();
      doc.templates['tpl.amp@1'] = _snapshot(id: 'tpl.amp', version: 1);
      final rows = buildPlaceableTemplates(
        doc,
        libraries: [
          _library('a-kit', 'A Kit', [_entry('tpl.amp', 1)]),
          _library('b-kit', 'B Kit', [_entry('tpl.amp', 1)]),
        ],
      );
      expect(rows.map((r) => r.id).toSet(), hasLength(1));
      expect(rows.map((r) => r.rowKey).toSet(), hasLength(3));
    });
  });

  group('the merged order is still total (§8.4)', () {
    // The property the comparator change exists for. `List.sort` is not
    // stable in Dart, so an id-only comparator over colliding rows would
    // let map iteration decide the palette's order.
    test('two calls with the same libraries agree, colliding ids included', () {
      final doc = _doc();
      for (final id in ['V03', 'tpl.amp', 'A01']) {
        doc.templates['$id@1'] = _snapshot(id: id, version: 1);
      }
      final libs = [
        _library('z-kit', 'Z Kit', [_entry('tpl.amp', 2), _entry('V03', 1)]),
        _library('a-kit', 'A Kit', [_entry('tpl.amp', 1)]),
      ];
      final first = buildPlaceableTemplates(doc, libraries: libs);
      final second = buildPlaceableTemplates(doc, libraries: libs);
      expect(
        first.map((r) => r.rowKey).toList(),
        second.map((r) => r.rowKey).toList(),
      );
    });

    test(
      'the document row precedes its library twins, then libraries sort',
      () {
        final doc = _doc();
        doc.templates['tpl.amp@1'] = _snapshot(id: 'tpl.amp', version: 1);
        final rows = buildPlaceableTemplates(
          doc,
          libraries: [
            _library('z-kit', 'Z Kit', [_entry('tpl.amp', 1)]),
            _library('a-kit', 'A Kit', [_entry('tpl.amp', 1)]),
          ],
        );
        expect(rows.map((r) => r.provenance.sourceKey).toList(), [
          'project',
          'library:a-kit',
          'library:z-kit',
        ]);
      },
    );

    // The libraries arrive in shelf order and their ROWS still sort by
    // id, so a library appearing second does not push its templates to
    // the bottom of the palette.
    test('rows interleave by id across sources', () {
      final doc = _doc();
      doc.templates['tpl.mid@1'] = _snapshot(id: 'tpl.mid', version: 1);
      final rows = buildPlaceableTemplates(
        doc,
        libraries: [
          _library('kit', 'Kit', [_entry('tpl.aaa', 1), _entry('tpl.zzz', 1)]),
        ],
      );
      expect(rows.map((r) => r.id).toList(), [
        'tpl.aaa',
        'tpl.mid',
        'tpl.zzz',
      ]);
    });
  });

  group('newest version of each id, per library', () {
    // A `.rmda` can hold two versions of one template, because `#240`'s
    // export packs what the project held and CR-050 keeps every earlier
    // version resolvable. Offering both as palette rows would ask a
    // version question the document's own rows never ask.
    test('a library holding v1 and v3 offers one row, at v3', () {
      final rows = buildPlaceableTemplates(
        _doc(),
        libraries: [
          _library('kit', 'Kit', [
            _entry('tpl.amp', 3, displayName: 'Amp mk3'),
            _entry('tpl.amp', 1, displayName: 'Amp'),
          ]),
        ],
      );
      expect(rows, hasLength(1));
      expect(rows.single.version, 3);
      expect(rows.single.body.displayName, 'Amp mk3');
    });

    test('list order does not decide which version wins', () {
      final rows = buildPlaceableTemplates(
        _doc(),
        libraries: [
          _library('kit', 'Kit', [
            _entry('tpl.amp', 1),
            _entry('tpl.amp', 3),
            _entry('tpl.amp', 2),
          ]),
        ],
      );
      expect(rows.single.version, 3);
    });
  });

  group('the hash the row carries', () {
    // Copy-on-place writes this into the document verbatim (DR-103
    // §11.102.2). Recomputing it anywhere on the way would make every
    // import verify by construction and AC-042's warning unreachable.
    test('a library row carries the library file s claim, not a new hash', () {
      final rows = buildPlaceableTemplates(
        _doc(),
        libraries: [
          _library('kit', 'Kit', [
            _entry('tpl.amp', 1, contentHash: 'sha256:whatever-the-file-said'),
          ]),
        ],
      );
      expect(rows.single.contentHash, 'sha256:whatever-the-file-said');
    });

    test('a document row carries the snapshot s hash', () {
      final doc = _doc();
      doc.templates['tpl.amp@1'] = _snapshot(id: 'tpl.amp', version: 1);
      expect(
        buildPlaceableTemplates(doc).single.contentHash,
        'unhashed:tpl.amp@1',
      );
    });
  });

  group('the seeded id a library also ships', () {
    // Provenance is about the SOURCE, not about the id. A library that
    // happens to contain `V01` offers a library row, and this build's
    // own `V01` is a separate seeded one.
    test('a library entry with a seed id is still a library row', () {
      final doc = _doc();
      doc.templates['V01@1'] = _snapshot(id: 'V01', version: 1);
      final rows = buildPlaceableTemplates(
        doc,
        libraries: [
          _library('kit', 'Kit', [_entry('V01', 1)]),
        ],
      );
      expect(rows.map((r) => r.provenance.sourceKey).toList(), [
        'catalog',
        'library:kit',
      ]);
    });
  });
}

/// The row for [id] from whichever source, when exactly one has it.
PlaceableTemplate _row(List<PlaceableTemplate> rows, String id) =>
    rows.singleWhere((r) => r.id == id);

LoadedLibrary _library(
  String id,
  String name,
  List<DeviceTemplateFile> templates,
) => LoadedLibrary(id: id, name: name, templates: templates);

DeviceTemplateFile _entry(
  String id,
  int version, {
  String displayName = 'Thing',
  String contentHash = 'sha256:entry',
}) => DeviceTemplateFile(
  templateId: TemplateId(id),
  version: version,
  contentHash: contentHash,
  body: TemplateBody(
    manufacturer: 'Generic',
    model: '',
    displayName: displayName,
    frontU: 1,
  ),
);
