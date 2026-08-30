// `#795`: `contentHash` becomes a real sha256, and gets the verifying
// reader it never had.
//
// THE TRI-STATE IS THE PART THAT NEEDED TESTING MOST. Making the hash real
// is arithmetic somebody else wrote; the risk in this change is what
// happens to the values that are NOT hashes. Every project written before
// this carries `sha256:seed-A01` or `unhashed:tpl.foo@1`, and 150-odd test
// fixtures in this repository carry `'h'`. If any of those read as a
// MISMATCH, the product puts a "this was modified" badge on every device
// in every document that predates today, which is AC-042's own reasoning
// arriving from the other side.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

TemplateBody _body({
  String displayName = 'Rack UPS 1500VA',
  String model = '',
  int frontU = 2,
}) => TemplateBody(
  manufacturer: 'Generic',
  model: model,
  displayName: displayName,
  frontU: frontU,
);

void main() {
  group('the hash itself', () {
    test('it is sha256: and 64 lowercase hex digits', () {
      final h = templateContentHash(_body());
      expect(h, startsWith('sha256:'));
      expect(h.substring(7), matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(h.length, 71);
    });

    test('the same body hashes the same, every time', () {
      // Determinism is inherited rather than asserted into existence: the
      // key sort is total and the encoder writes no timestamp and no
      // locale-dependent number. This is the check that it stays true.
      expect(templateContentHash(_body()), templateContentHash(_body()));
    });

    test('two bodies differing in ONE field hash differently', () {
      // The property that makes a mismatch mean anything at all. A hash
      // over the id, or over nothing, would pass every test above and
      // fail this one.
      expect(
        templateContentHash(_body()),
        isNot(templateContentHash(_body(frontU: 3))),
      );
      expect(
        templateContentHash(_body()),
        isNot(templateContentHash(_body(model: 'ABC-1'))),
      );
    });

    test('it is over the CANONICAL bytes, so key order cannot change it', () {
      // DR-100's pair is the single description of a TemplateBody, and
      // `encodeCanonicalJsonBytes` sorts at every level. A body built by
      // a different route hashes identically, which is what makes the
      // hash portable between the builder, the seeder and the codec.
      final a = _body(model: 'X');
      final b = copyTemplateBody(a);
      expect(templateContentHash(a), templateContentHash(b));
    });

    test('every seeded template gets a DISTINCT hash', () {
      // 48 templates, 48 hashes. A collision here would mean the hash is
      // reading something less than the whole body.
      final catalog = buildSeedCatalog();
      expect(catalog.length, greaterThan(40), reason: 'non-vacuity');
      final hashes = {
        for (final body in catalog.values) templateContentHash(body),
      };
      expect(hashes.length, catalog.length);
    });
  });

  group('the verifier, and the third state that matters most', () {
    test('a body against its own hash matches', () {
      final body = _body();
      expect(templateHashMatches(body, templateContentHash(body)), isTrue);
    });

    test('an edited body against the old hash MISMATCHES', () {
      final hash = templateContentHash(_body());
      expect(templateHashMatches(_body(frontU: 9), hash), isFalse);
    });

    test('every placeholder this repository ever wrote answers UNKNOWN', () {
      // NOT `false`. Each of these is a real value from the tree before
      // `#795`, and reading any of them as a mismatch would badge every
      // device in every document written before today.
      final body = _body();
      for (final placeholder in <String>[
        'unhashed:tpl.hdmi_matrix_16x16@2', // the builder's save
        'sha256:seed-A01', // both seeders and four starters
        'sha256:demo-ups', // the demo document
        'sha256:structure-no-template', // the old sentinel
        kNoTemplateContentHash, // the new one
        'h', // ~150 test fixtures
        'sha256:test',
        '',
      ]) {
        expect(
          templateHashMatches(body, placeholder),
          isNull,
          reason: '"$placeholder" is not a hash and must not read as one',
        );
      }
    });

    test('a `sha256:` prefix over the wrong SHAPE is still unknown', () {
      // `sha256:seed-A01` has the prefix and is not a digest. So does
      // `sha256:deadbeef`, which is hex and 8 characters. Length and
      // alphabet are both checked, because the prefix alone was exactly
      // the thing that made three placeholders look real.
      final body = _body();
      expect(templateHashMatches(body, 'sha256:deadbeef'), isNull);
      expect(templateHashMatches(body, 'sha256:${'z' * 64}'), isNull);
      expect(templateHashMatches(body, 'sha256:${'A' * 64}'), isNull);
    });

    test('a well-formed hash of the WRONG body is a mismatch, not unknown', () {
      // The line between the second and third states: this one IS a
      // digest, so the answer is a verdict rather than a shrug.
      expect(
        templateHashMatches(_body(), templateContentHash(_body(frontU: 7))),
        isFalse,
      );
    });
  });

  group('what the import does with it', () {
    test('a file exported by this build verifies', () {
      final body = _body();
      final file = DeviceTemplateFile(
        templateId: const TemplateId('tpl.mx'),
        version: 1,
        contentHash: templateContentHash(body),
        body: body,
      );
      final doc = _emptyDoc();
      expect(planTemplateImport(doc, file).hashVerdict, isTrue);
      expect(planTemplateImport(doc, file).hashMismatched, isFalse);
    });

    test('a file edited after export is FLAGGED and still importable', () {
      // AC-042: a warning and a badge, never a load failure. The plan
      // reports the mismatch and `buildTemplateImport` builds a command
      // regardless, because refusing would be a data-loss event dressed
      // as a safety feature.
      final file = DeviceTemplateFile(
        templateId: const TemplateId('tpl.mx'),
        version: 1,
        contentHash: templateContentHash(_body(frontU: 9)),
        body: _body(),
      );
      final doc = _emptyDoc();
      final plan = planTemplateImport(doc, file);
      expect(plan.hashMismatched, isTrue);

      buildTemplateImport(doc, plan, capturedAt: DateTime.utc(2026)).apply(doc);
      expect(
        doc.templates.keys,
        contains('tpl.mx@1'),
        reason: 'the warning does not stop the import',
      );
    });

    test('the import stores what the FILE claimed, not what it recomputed', () {
      // If the import recomputed, every file would verify by
      // construction and the warning would be unreachable forever. The
      // document records the claim; the verdict travels on the plan.
      final file = DeviceTemplateFile(
        templateId: const TemplateId('tpl.mx'),
        version: 1,
        contentHash: templateContentHash(_body(frontU: 9)),
        body: _body(),
      );
      final doc = _emptyDoc();
      buildTemplateImport(
        doc,
        planTemplateImport(doc, file),
        capturedAt: DateTime.utc(2026),
      ).apply(doc);
      final stored = doc.templates['tpl.mx@1']!;
      expect(stored.contentHash, templateContentHash(_body(frontU: 9)));
      expect(templateHashMatches(stored.body, stored.contentHash), isFalse);
    });

    test('an old file with no real hash is UNKNOWN, not flagged', () {
      final file = DeviceTemplateFile(
        templateId: const TemplateId('tpl.mx'),
        version: 1,
        contentHash: 'unhashed:tpl.mx@1',
        body: _body(),
      );
      final plan = planTemplateImport(_emptyDoc(), file);
      expect(plan.hashVerdict, isNull);
      expect(
        plan.hashMismatched,
        isFalse,
        reason: 'no warning for a file that never carried a hash',
      );
    });
  });
}

RackDocument _emptyDoc() {
  final now = DateTime.utc(2026, 8, 29, 12);
  return RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-0000000000cc'),
    appVersion: '0.4.73',
    createdAt: now,
    modifiedAt: now,
    meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'hash'),
    info: ProjectInfo(projectName: 'Hash drill'),
  );
}
