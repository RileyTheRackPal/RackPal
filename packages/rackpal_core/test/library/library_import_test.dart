// `#240`: what an import brings in, and what an export offers.
//
// THE TRI-STATE IS AGAIN THE PART THAT NEEDS TESTING. `#795` established
// that `templateHashMatches` answers `null` for anything that is not a
// real digest. A library made before the hash was real carries
// placeholders on every template in it, so folding UNKNOWN into MISMATCH
// here would badge every library anybody has ever made, all at once
// rather than one template at a time.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 8, 29, 12);

TemplateBody _body(String name, {String model = ''}) => TemplateBody(
  manufacturer: 'Generic',
  model: model,
  displayName: name,
  frontU: 2,
);

DeviceTemplateFile _verified(String id, TemplateBody body) =>
    DeviceTemplateFile(
      templateId: TemplateId(id),
      version: 1,
      contentHash: templateContentHash(body),
      body: body,
    );

DeviceTemplateFile _edited(String id, TemplateBody body) => DeviceTemplateFile(
  templateId: TemplateId(id),
  version: 1,
  // A real digest, of a DIFFERENT body: edited after export.
  contentHash: templateContentHash(_body('something else')),
  body: body,
);

DeviceTemplateFile _unhashed(String id, TemplateBody body) =>
    DeviceTemplateFile(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'unhashed:$id@1',
      body: body,
    );

RackDocument _doc() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-0000000000dd'),
  appVersion: '0.4.78',
  createdAt: _now,
  modifiedAt: _now,
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'lib'),
  info: ProjectInfo(projectName: 'Library drill'),
);

void _hold(RackDocument doc, String id, TemplateBody body, {int version = 1}) {
  doc.templates[templateSnapshotKey(
    TemplateId(id),
    version,
  )] = TemplateSnapshot(
    templateId: TemplateId(id),
    version: version,
    contentHash: templateContentHash(body),
    body: body,
    capturedAt: _now,
  );
}

void main() {
  group('what an import brings in', () {
    test('a clean library reports no mismatch and nothing unverifiable', () {
      final preview = previewLibraryImport(
        DeviceLibraryFile(
          name: 'Shop Kit',
          templates: [
            _verified('a', _body('Amp')),
            _verified('b', _body('Switch')),
          ],
        ),
      );
      expect(preview.name, 'Shop Kit');
      expect(preview.templateCount, 2);
      expect(preview.hasMismatch, isFalse);
      expect(preview.unverifiable, 0);
    });

    test('an edited template is NAMED, not just counted', () {
      // A warning saying "1 template was edited" invites exactly the
      // question the list answers, and the dialog then does the work
      // twice.
      final preview = previewLibraryImport(
        DeviceLibraryFile(
          name: 'Kit',
          templates: [
            _verified('a', _body('Amp')),
            _edited('b', _body('Switch')),
          ],
        ),
      );
      expect(preview.mismatched, ['Switch']);
      expect(preview.hasMismatch, isTrue);
      expect(preview.templateCount, 2, reason: 'it still imports both');
    });

    test('a library with NO real hashes is unverifiable, not mismatched', () {
      // THE CASE THAT DECIDES WHETHER THIS FEATURE IS USABLE. Every
      // .rmda written before #795 carries placeholders on every
      // template. Reporting those as edited badges every library
      // anybody has made, all at once.
      final preview = previewLibraryImport(
        DeviceLibraryFile(
          name: 'Old Kit',
          templates: [
            _unhashed('a', _body('Amp')),
            _unhashed('b', _body('Switch')),
          ],
        ),
      );
      expect(preview.mismatched, isEmpty);
      expect(preview.hasMismatch, isFalse);
      expect(preview.unverifiable, 2);
    });

    test('the three states are counted separately in one file', () {
      final preview = previewLibraryImport(
        DeviceLibraryFile(
          name: 'Mixed',
          templates: [
            _verified('a', _body('Amp')),
            _edited('b', _body('Switch')),
            _unhashed('c', _body('Panel')),
          ],
        ),
      );
      expect(preview.mismatched, ['Switch']);
      expect(preview.unverifiable, 1);
      expect(preview.templateCount, 3);
    });

    test('an empty library previews without incident', () {
      final preview = previewLibraryImport(
        const DeviceLibraryFile(name: 'Empty', templates: []),
      );
      expect(preview.templateCount, 0);
      expect(preview.hasMismatch, isFalse);
    });
  });

  group('what an export offers', () {
    test('project-authored templates only; the seed is excluded', () {
      // Not a filter but a correctness point: every install already ships
      // the 48, so packing them makes a large file whose contents the
      // recipient already has, under ids that would then collide with
      // their own copies on import.
      final doc = _doc();
      final seeded = buildSeedCatalog();
      for (final e in seeded.entries) {
        _hold(doc, e.key, e.value);
      }
      _hold(doc, 'tpl.mine', _body('My Matrix'));

      final offered = exportableLibraryTemplates(doc);
      expect(offered.map((t) => t.templateId.v), ['tpl.mine']);
    });

    test('a project that authored nothing offers nothing', () {
      // The caller says so BEFORE opening a dialog; this is the value it
      // branches on.
      final doc = _doc();
      for (final e in buildSeedCatalog().entries) {
        _hold(doc, e.key, e.value);
      }
      expect(exportableLibraryTemplates(doc), isEmpty);
    });

    test('the NEWEST version of each id, not every version', () {
      // Inherited from buildPlaceableTemplates for its stated reason: a
      // person packing a kit means the templates as they stand, and
      // CR-050 keeps earlier versions resolvable where they were placed.
      final doc = _doc();
      _hold(doc, 'tpl.mine', _body('Mk I'));
      _hold(doc, 'tpl.mine', _body('Mk II'), version: 2);
      final offered = exportableLibraryTemplates(doc);
      expect(offered, hasLength(1));
      expect(offered.single.version, 2);
      expect(offered.single.body.displayName, 'Mk II');
    });

    test('what it offers round-trips through the codec unchanged', () {
      // The join between #239 and #240: an export is these entries in a
      // .rmda, so the property that matters is that packing them and
      // reading them back gives the same templates.
      final doc = _doc();
      _hold(doc, 'tpl.a', _body('Amp', model: 'A-1'));
      _hold(doc, 'tpl.b', _body('Switch', model: 'S-1'));

      final offered = exportableLibraryTemplates(doc);
      final bytes = encodeRmdaBytes(
        DeviceLibraryFile(name: 'Kit', templates: offered),
      );
      final read = readRmdaBytes(bytes);
      expect(read, isA<Ok<DeviceLibraryFile>>());
      final back = (read as Ok<DeviceLibraryFile>).value;
      expect(back.templates.map((t) => t.body.model), ['A-1', 'S-1']);

      // And every one of them verifies, because the snapshots carried
      // real hashes: an export of a healthy project is a clean library.
      expect(previewLibraryImport(back).hasMismatch, isFalse);
      expect(previewLibraryImport(back).unverifiable, 0);
    });
  });
}
