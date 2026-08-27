// What `Save` means in the Device Builder, from the app side (M4-S,
// DR-077 §11.76.3, board `#735`).
//
// The seam under test is the twenty lines between the button and the undo
// stack, and specifically what happens on the SECOND press. `[Save]` sits
// beside `[Save & Close]` precisely so a person can save and keep
// working, so pressing it twice is the ordinary path and not an edge
// case. It minted a second template, and nothing in fourteen gates could
// see that, because nothing in the tree read what the first one wrote.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/device_builder_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

final DateTime _when = DateTime.utc(2026, 8, 19, 10);

DocumentController _controller() => DocumentController(
  RackDocument(
    id: const Uuid('doc-701'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'seed'),
  ),
  clock: FixedClock(_when),
  actor: 'the-integrator',
);

TemplateBody _body({String name = 'HDMI Matrix 16x16', int frontU = 3}) =>
    TemplateBody(
      manufacturer: 'Generic',
      model: '',
      displayName: name,
      typePrefix: 'MTX',
      frontU: frontU,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
    );

void main() {
  group('a second Save forks a version', () {
    test('two saves write id@1 and id@2 and mint no second id', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c);

      expect(actions.onSave(_body()), isNull);
      expect(actions.onSave(_body(frontU: 4)), isNull);

      expect(c.doc.templates.keys, [
        'tpl.hdmi_matrix_16x16@1',
        'tpl.hdmi_matrix_16x16@2',
      ]);
      expect(
        c.doc.templates.values.map((s) => s.templateId).toSet(),
        {const TemplateId('tpl.hdmi_matrix_16x16')},
      );
    });

    test('the palette sees one row, at the newer version', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c);
      actions.onSave(_body());
      actions.onSave(_body(frontU: 4));

      final rows = buildPlaceableTemplates(c.doc);
      expect(rows, hasLength(1));
      expect(rows.single.version, 2);
      expect(rows.single.body.frontU, 4);
      expect(rows.single.provenance, TemplateProvenance.project);
    });

    test('renaming between saves does not re-id, so placed devices keep '
        'resolving', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c);
      actions.onSave(_body());
      actions.onSave(_body(name: 'HDMI Matrix 16x16 rev B'));

      expect(c.doc.templates.keys, [
        'tpl.hdmi_matrix_16x16@1',
        'tpl.hdmi_matrix_16x16@2',
      ]);
      // The DISPLAY name follows the edit; the id does not.
      expect(
        c.doc.templates['tpl.hdmi_matrix_16x16@2']!.body.displayName,
        'HDMI Matrix 16x16 rev B',
      );
    });

    test('a second builder session authors a second template', () {
      final c = _controller();
      buildDeviceBuilderActions(controller: c).onSave(_body());
      // A new window is a new session, and this one names its device the
      // same thing: two devices, per `templateIdFor`'s own rule.
      buildDeviceBuilderActions(controller: c).onSave(_body());

      expect(c.doc.templates.keys, [
        'tpl.hdmi_matrix_16x16@1',
        'tpl.hdmi_matrix_16x16_2@1',
      ]);
    });

    test('an explicit `editing` id forks from the first save onward', () {
      final c = _controller();
      buildDeviceBuilderActions(controller: c).onSave(_body());
      final again = buildDeviceBuilderActions(
        controller: c,
        editing: const TemplateId('tpl.hdmi_matrix_16x16'),
      );

      expect(again.onSave(_body(frontU: 5)), isNull);
      expect(c.doc.templates.keys, [
        'tpl.hdmi_matrix_16x16@1',
        'tpl.hdmi_matrix_16x16@2',
      ]);
    });
  });

  group('each save is its own undo entry', () {
    test('undo removes only the version it added', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c);
      actions.onSave(_body());
      actions.onSave(_body(frontU: 4));

      c.undoLast();
      expect(c.doc.templates.keys, ['tpl.hdmi_matrix_16x16@1']);
      c.undoLast();
      expect(c.doc.templates, isEmpty);
      c
        ..redoLast()
        ..redoLast();
      expect(c.doc.templates.keys, [
        'tpl.hdmi_matrix_16x16@1',
        'tpl.hdmi_matrix_16x16@2',
      ]);
    });
  });

  group('the content hash says what it is', () {
    test('it is labelled unhashed and carries the version it belongs to', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c);
      actions.onSave(_body());
      actions.onSave(_body(frontU: 4));

      expect(
        c.doc.templates['tpl.hdmi_matrix_16x16@2']!.contentHash,
        'unhashed:tpl.hdmi_matrix_16x16@2',
      );
    });
  });
}
