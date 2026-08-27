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
      expect(rows.single.key, 'V01@1');
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
    test('a document holding the seed catalog offers all 48, all seeded', () {
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
      expect(rows, hasLength(48));
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
      expect(rows.single.key, 'tpl.amp@2');
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
      final first = buildPlaceableTemplates(doc).map((r) => r.key).toList();
      final second = buildPlaceableTemplates(doc).map((r) => r.key).toList();
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
}
