// DR-101 §11.100: an id collision on import means somebody typed the same
// name, and the two resolutions are different documents.
//
// THE ASSERTION THAT MATTERS IS THE ONE ABOUT INSTANCES. `templateIdFor`'s
// header rules that silently joining an existing id "would put one
// template's ports on the other's instances", so the separate-template
// branch is checked by what a PLACED device still resolves to, not by the
// id string alone. A test that only compared ids would pass over exactly
// the defect the ruling exists to prevent.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 29, 12);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'drill');

TemplateBody _body(String displayName, {String model = ''}) => TemplateBody(
  manufacturer: 'Generic',
  model: model,
  displayName: displayName,
  frontU: 2,
);

RackDocument _doc() => RackDocument(
  id: const Uuid('0190e3c1-0000-7000-8000-0000000000aa'),
  appVersion: '0.4.73',
  createdAt: _now,
  modifiedAt: _now,
  meta: _meta(),
  info: ProjectInfo(projectName: 'Import drill'),
);

/// Puts [body] in the document at `id@version`, the way a save does.
void _hold(
  RackDocument doc,
  String id,
  int version,
  TemplateBody body,
) {
  doc.templates[templateSnapshotKey(
    TemplateId(id),
    version,
  )] = TemplateSnapshot(
    templateId: TemplateId(id),
    version: version,
    contentHash: 'unhashed:$id@$version',
    body: body,
    capturedAt: _now,
  );
}

DeviceTemplateFile _file(
  String id,
  int version,
  TemplateBody body, {
  String hash = 'unhashed:incoming',
}) => DeviceTemplateFile(
  templateId: TemplateId(id),
  version: version,
  contentHash: hash,
  body: body,
);

void main() {
  group('planTemplateImport says whether a question is owed', () {
    test('a free id owes no question', () {
      final doc = _doc();
      _hold(doc, 'tpl.other', 1, _body('Something Else'));
      final plan = planTemplateImport(
        doc,
        _file('tpl.hdmi_matrix', 3, _body('HDMI Matrix')),
      );
      expect(plan.collides, isFalse);
      expect(plan.collision, isNull);
    });

    test('a taken id reports the INCUMBENT, not the incoming file', () {
      // The id is a slug of the name, so two spellings collide while
      // reading differently. A prompt showing only the incoming name
      // would leave the user comparing a string against itself.
      final doc = _doc();
      _hold(doc, 'tpl.hdmi_matrix', 1, _body('HDMI Matrix'));
      _hold(doc, 'tpl.hdmi_matrix', 3, _body('HDMI Matrix (rev B)'));
      final plan = planTemplateImport(
        doc,
        _file('tpl.hdmi_matrix', 1, _body('hdmi matrix')),
      );
      expect(plan.collides, isTrue);
      expect(plan.collision!.incumbentDisplayName, 'HDMI Matrix (rev B)');
      expect(
        plan.collision!.incumbentLatestVersion,
        3,
        reason: 'the LATEST, so the dialog can say what it would extend',
      );
    });
  });

  group('the free-id branch preserves what the file said', () {
    test("the file's own version survives, it is not reset to 1", () {
      final doc = _doc();
      buildTemplateImport(
        doc,
        planTemplateImport(doc, _file('tpl.mx', 3, _body('MX'))),
        capturedAt: _now,
      ).apply(doc);
      expect(doc.templates.keys, contains('tpl.mx@3'));
      expect(
        doc.templates.keys,
        isNot(contains('tpl.mx@1')),
        reason: 'nothing invents versions the file never had',
      );
    });

    test('a later import of @4 slots in above it', () {
      final doc = _doc();
      buildTemplateImport(
        doc,
        planTemplateImport(doc, _file('tpl.mx', 3, _body('MX'))),
        capturedAt: _now,
      ).apply(doc);
      final second = planTemplateImport(doc, _file('tpl.mx', 4, _body('MX')));
      expect(second.collides, isTrue);
      buildTemplateImport(
        doc,
        second,
        capturedAt: _now,
        resolution: TemplateImportResolution.newVersion,
      ).apply(doc);
      expect(
        latestTemplateVersions(doc.templates)[const TemplateId('tpl.mx')],
        4,
      );
    });
  });

  group('newVersion: the send-it-back-fixed flow', () {
    test('it extends the incumbent chain and placement follows', () {
      final doc = _doc();
      _hold(doc, 'tpl.mx', 1, _body('MX'));
      _hold(doc, 'tpl.mx', 2, _body('MX'));
      final plan = planTemplateImport(
        doc,
        _file('tpl.mx', 9, _body('MX', model: 'fixed by a colleague')),
      );
      buildTemplateImport(
        doc,
        plan,
        capturedAt: _now,
        resolution: TemplateImportResolution.newVersion,
      ).apply(doc);

      // nextTemplateVersion, NOT the file's 9: the chain is this
      // document's, and a gap would be a version nobody wrote.
      expect(doc.templates.keys, contains('tpl.mx@3'));
      expect(doc.templates.keys, isNot(contains('tpl.mx@9')));
      final placeable = buildPlaceableTemplates(doc);
      final row = placeable.firstWhere(
        (p) => p.templateId == const TemplateId('tpl.mx'),
      );
      expect(row.version, 3);
      expect(row.body.model, 'fixed by a colleague');
    });
  });

  group('separateTemplate: two devices stay two devices', () {
    test('a placed instance still resolves to the template it was placed '
        'from', () {
      // THE DEFECT DR-101 EXISTS TO PREVENT, asserted where it would
      // actually show: not on the id string, but on what a device that
      // was already in the rack now reads as.
      final doc = _doc();
      _hold(doc, 'tpl.mx', 1, _body('MX', model: 'MINE'));
      final incoming = _file('tpl.mx', 1, _body('MX', model: 'THEIRS'));

      buildTemplateImport(
        doc,
        planTemplateImport(doc, incoming),
        capturedAt: _now,
        resolution: TemplateImportResolution.separateTemplate,
      ).apply(doc);

      expect(doc.templates['tpl.mx@1']!.body.model, 'MINE');
      final suffixed = doc.templates.keys.firstWhere((k) => k != 'tpl.mx@1');
      expect(suffixed, 'tpl.mx_2@1');
      expect(doc.templates[suffixed]!.body.model, 'THEIRS');
    });

    test('the suffixed import lands at version 1, whatever the file said', () {
      final doc = _doc();
      _hold(doc, 'tpl.mx', 7, _body('MX'));
      buildTemplateImport(
        doc,
        planTemplateImport(doc, _file('tpl.mx', 7, _body('MX'))),
        capturedAt: _now,
        resolution: TemplateImportResolution.separateTemplate,
      ).apply(doc);
      expect(doc.templates.keys, contains('tpl.mx_2@1'));
    });
  });

  group('what the import carries through untouched', () {
    test('contentHash is the FILE’s, never recomputed', () {
      // Nothing computes a sha256 yet (#795). Recomputing a fake here
      // would put a second answer beside the one that ships.
      final doc = _doc();
      buildTemplateImport(
        doc,
        planTemplateImport(
          doc,
          _file('tpl.mx', 1, _body('MX'), hash: 'sha256:from-the-file'),
        ),
        capturedAt: _now,
      ).apply(doc);
      expect(doc.templates['tpl.mx@1']!.contentHash, 'sha256:from-the-file');
    });

    test('derivedFrom survives BOTH branches, pointing where it did', () {
      // Overwriting it on the separate-template branch was considered and
      // declined: it would record this import as the origin and destroy
      // the author's real lineage. A TemplateOrigin naming a template
      // this installation lacks is a case the model already handles.
      final doc = _doc();
      _hold(doc, 'tpl.mx', 1, _body('MX'));
      final body = _body('MX')
        ..derivedFrom = const TemplateOrigin(
          templateId: TemplateId('tpl.elsewhere'),
          version: 4,
        );
      buildTemplateImport(
        doc,
        planTemplateImport(doc, _file('tpl.mx', 1, body)),
        capturedAt: _now,
        resolution: TemplateImportResolution.separateTemplate,
      ).apply(doc);
      expect(
        doc.templates['tpl.mx_2@1']!.body.derivedFrom?.templateId,
        const TemplateId('tpl.elsewhere'),
      );
      expect(doc.templates['tpl.mx_2@1']!.body.derivedFrom?.version, 4);
    });

    test('the import is one undo step and reverts cleanly', () {
      final doc = _doc();
      final cmd = buildTemplateImport(
        doc,
        planTemplateImport(doc, _file('tpl.mx', 2, _body('MX'))),
        capturedAt: _now,
      )..apply(doc);
      expect(doc.templates.keys, contains('tpl.mx@2'));
      cmd.revert(doc);
      expect(
        doc.templates.keys,
        isEmpty,
        reason: 'an import a user undoes leaves nothing behind',
      );
    });
  });
}
