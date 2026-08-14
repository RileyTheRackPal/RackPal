// Saving a builder template into the project. M4-D, docs/06 §7.1,
// CR-050, CR-054.
//
// The property worth the file is that a SAVE FORKS rather than mutates.
// CR-050: editing a published template does not change it, it writes
// `version + 1`, and every earlier version stays resolvable. That is
// what makes an embedded snapshot trustworthy — a device placed from v1
// still resolves to the v1 it was drawn against, a week after somebody
// corrected the wattage.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

RackDocument _doc() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-0000000000d0'),
  appVersion: '0.1.0+build.1',
  createdAt: DateTime.utc(2026, 8, 14, 12),
  modifiedAt: DateTime.utc(2026, 8, 14, 12),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026, 8, 14, 12),
    updatedAt: DateTime.utc(2026, 8, 14, 12),
    updatedBy: 'riley',
  ),
  info: ProjectInfo(projectName: 'Builder save fixture'),
);

TemplateBody _body(String name) =>
    TemplateBody(manufacturer: 'Generic', model: '', displayName: name)
      ..frontU = 2
      ..typePrefix = 'MTX';

SaveTemplateToProjectCommand _save(
  RackDocument doc,
  TemplateId id,
  TemplateBody body,
) {
  final version = nextTemplateVersion(doc, id);
  return SaveTemplateToProjectCommand(
    templateId: id,
    version: version,
    contentHash: 'unhashed:${id.v}@$version',
    body: body,
    capturedAt: DateTime.utc(2026, 8, 14, 12),
  );
}

const _id = TemplateId('tpl.mtx');

void main() {
  group('a first save', () {
    test('lands at version 1, under the key placement joins on', () {
      final doc = _doc();

      _save(doc, _id, _body('Matrix')).apply(doc);

      expect(doc.templates.keys, ['tpl.mtx@1']);
      expect(doc.templates['tpl.mtx@1']!.version, 1);
      expect(doc.templates['tpl.mtx@1']!.body.displayName, 'Matrix');
    });

    test('reverts to nothing, because it added exactly one key', () {
      final doc = _doc();
      final command = _save(doc, _id, _body('Matrix'))..apply(doc);
      expect(doc.templates, hasLength(1), reason: 'the save landed first');

      command.revert(doc);

      expect(doc.templates, isEmpty);
    });
  });

  group('a second save FORKS rather than mutating (CR-050)', () {
    test('writes version 2 and leaves version 1 exactly where it was', () {
      final doc = _doc();
      _save(doc, _id, _body('Matrix')).apply(doc);

      _save(doc, _id, _body('Matrix, corrected')).apply(doc);

      expect(doc.templates.keys, ['tpl.mtx@1', 'tpl.mtx@2']);
      expect(
        doc.templates['tpl.mtx@1']!.body.displayName,
        'Matrix',
        reason:
            'a device placed from v1 must still resolve to the v1 it was '
            'drawn against (CR-054)',
      );
      expect(doc.templates['tpl.mtx@2']!.body.displayName, 'Matrix, corrected');
    });

    test('undoing the second leaves the first, so an undo cannot strand a '
        'device that resolves against v1', () {
      final doc = _doc();
      _save(doc, _id, _body('Matrix')).apply(doc);
      final second = _save(doc, _id, _body('Corrected'))..apply(doc);
      expect(doc.templates, hasLength(2), reason: 'both saves landed');

      second.revert(doc);

      expect(doc.templates.keys, ['tpl.mtx@1']);
    });

    test('the version is allocated by the CALLER, so redo is idempotent: '
        'applying the same command twice writes the same key', () {
      // The `Command` contract. A version chosen inside `apply` would
      // advance on every redo and drift away from the TemplateRefs
      // already pointing at it.
      final doc = _doc();

      _save(doc, _id, _body('Matrix'))
        ..apply(doc)
        ..apply(doc);

      expect(doc.templates.keys, ['tpl.mtx@1']);
    });
  });

  group('nextTemplateVersion', () {
    test('ignores other templates entirely', () {
      final doc = _doc();
      _save(doc, const TemplateId('tpl.other'), _body('Other')).apply(doc);
      _save(doc, const TemplateId('tpl.other'), _body('Other')).apply(doc);

      expect(nextTemplateVersion(doc, _id), 1);
    });

    test('returns one past the HIGHEST, not one past the count, so a gap '
        'left by an undo cannot hand out a key twice', () {
      final doc = _doc();
      _save(doc, _id, _body('a')).apply(doc);
      _save(doc, _id, _body('b')).apply(doc);
      // v1 removed by hand: the shape an undo of an older save leaves.
      doc.templates.remove('tpl.mtx@1');

      expect(nextTemplateVersion(doc, _id), 3);
    });
  });

  group('the whole trip', () {
    test('a saved template survives a write and a read (CR-117)', () {
      const codec = JsonDocumentCodec();
      final doc = _doc();
      _save(doc, _id, _body('Matrix')).apply(doc);

      final first = codec.write(doc);
      final outcome = codec.read(first);

      expect(outcome, isA<Ok<RackDocument>>());
      final back = (outcome as Ok<RackDocument>).value;
      expect(back.templates['tpl.mtx@1']!.body.displayName, 'Matrix');
      expect(codec.write(back), equals(first));
    });
  });
}
