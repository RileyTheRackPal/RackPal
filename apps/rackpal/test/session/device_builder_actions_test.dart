// What `Save` means in the Device Builder, from the app side (M4-S,
// DR-077 §11.76.3, board `#735`; DR-202, `#950`).
//
// The seam under test is the twenty lines between the button and the undo
// stack, and specifically what happens on the SECOND press. `[Save]` sits
// beside `[Save & Close]` precisely so a person can save and keep
// working, so pressing it twice is the ordinary path and not an edge
// case. It minted a second template, and nothing in fourteen gates could
// see that, because nothing in the tree read what the first one wrote.
//
// **THESE CASES HOLD ONE CLOSURE STILL, AND THE SHELL DID NOT.** They
// passed from `#778` (2026-08-26) to `#950` while the product minted
// `tpl.foo_2` again, because the shell rebuilt the closure on every save.
// The route through the real shell is `builder_save_route_test.dart`;
// this file is the rule.

// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

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

const _id = 'tpl.hdmi_matrix_16x16';

/// Stands one device on `templateId@version`, which is all DR-202 reads.
void _place(DocumentController c, int version) {
  final n = c.doc.devices.length + 1;
  c.doc.devices[Uuid('dev-$n')] = DeviceInstance(
    id: Uuid('dev-$n'),
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: const TemplateId(_id),
      version: version,
      contentHash: 'test',
    ),
    designator: 'MTX-$n',
    name: 'Matrix $n',
    placement: const OffRackPlacement(),
    meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'seed'),
  );
}

int _frontU(DocumentController c, int version) =>
    c.doc.templates['$_id@$version']!.body.frontU;

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // DR-202 §11.201.1 REPLACED THIS GROUP'S PREMISE
  // ═══════════════════════════════════════════════════════════════════
  // It was "a second Save forks a version", and every case asserted `@1`
  // then `@2`. A fork exists so a placed device keeps resolving to what it
  // was placed from, and with nothing placed it protects nobody, so the
  // user ruled on 2026-09-29 that Save REPLACES the newest version until
  // something stands on it. The id half of DR-077 §11.76.3 is untouched: a
  // second Save still never mints a second template.
  group('a second Save writes the same template', () {
    test('with nothing placed it REPLACES @1 and mints no second id', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c);

      expect(actions.onSave(_body()), isNull);
      expect(actions.onSave(_body(frontU: 4)), isNull);

      expect(c.doc.templates.keys, ['$_id@1']);
      expect(_frontU(c, 1), 4);
    });

    test('ONCE A DEVICE IS PLACED FROM IT, the next Save forks, and the '
        'device keeps its body', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c)..onSave(_body());
      _place(c, 1);

      actions
        ..onSave(_body(frontU: 4))
        ..onSave(_body(frontU: 5));

      expect(c.doc.templates.keys, ['$_id@1', '$_id@2']);
      expect(
        _frontU(c, 1),
        3,
        reason: 'the placed device resolves to @1, which nothing rewrote',
      );
      expect(
        _frontU(c, 2),
        5,
        reason: 'nothing stands on @2, so the third Save replaced it',
      );
    });

    test('the palette sees one row, at the newest body', () {
      final c = _controller();
      buildDeviceBuilderActions(controller: c)
        ..onSave(_body())
        ..onSave(_body(frontU: 4));

      final rows = buildPlaceableTemplates(c.doc);
      expect(rows, hasLength(1));
      expect(rows.single.version, 1);
      expect(rows.single.body.frontU, 4);
      expect(rows.single.provenance, TemplateProvenance.project);
    });

    test('renaming between saves does not re-id, so placed devices keep '
        'resolving', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c)..onSave(_body());
      _place(c, 1);
      actions.onSave(_body(name: 'HDMI Matrix 16x16 rev B'));

      expect(c.doc.templates.keys, ['$_id@1', '$_id@2']);
      // The DISPLAY name follows the edit; the id does not.
      expect(
        c.doc.templates['$_id@2']!.body.displayName,
        'HDMI Matrix 16x16 rev B',
      );
    });

    test('a second builder session authors a second template', () {
      final c = _controller();
      buildDeviceBuilderActions(controller: c).onSave(_body());
      // A new window is a new session, and this one names its device the
      // same thing: two devices, per `templateIdFor`'s own rule.
      buildDeviceBuilderActions(controller: c).onSave(_body());

      expect(c.doc.templates.keys, ['$_id@1', '${_id}_2@1']);
    });

    test('an explicit `editing` id writes that id from the first save', () {
      final c = _controller();
      buildDeviceBuilderActions(controller: c).onSave(_body());
      _place(c, 1);
      final again = buildDeviceBuilderActions(
        controller: c,
        editing: const TemplateId(_id),
      );

      expect(again.onSave(_body(frontU: 5)), isNull);
      expect(c.doc.templates.keys, ['$_id@1', '$_id@2']);
    });
  });

  group('the change class has a baseline only when devices stand on one', () {
    test('a new template has none, before or after its first Save', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c);
      expect(actions.placedBaseline(), isNull);
      actions.onSave(_body());
      expect(actions.placedBaseline(), isNull);
    });

    test('it is the NEWEST placed version, with its own count', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c)..onSave(_body());
      _place(c, 1);
      actions.onSave(_body(frontU: 4));
      _place(c, 2);
      _place(c, 2);
      // Nothing stands on a version newer than @2, so this forks @3.
      actions.onSave(_body(frontU: 5));

      final base = actions.placedBaseline()!;
      expect(base.version, 2);
      expect(base.count, 2);
      expect(base.body.frontU, 4);
    });
  });

  group('each save is its own undo entry', () {
    test('undo takes back a REPLACE by restoring the body it replaced', () {
      final c = _controller();
      buildDeviceBuilderActions(controller: c)
        ..onSave(_body())
        ..onSave(_body(frontU: 4));

      c.undoLast();
      expect(c.doc.templates.keys, ['$_id@1']);
      expect(_frontU(c, 1), 3);
      c.undoLast();
      expect(c.doc.templates, isEmpty);
      c
        ..redoLast()
        ..redoLast();
      expect(c.doc.templates.keys, ['$_id@1']);
      expect(_frontU(c, 1), 4);
    });

    test('undo takes back a FORK by removing only the version it added', () {
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c)..onSave(_body());
      _place(c, 1);
      actions.onSave(_body(frontU: 4));

      c.undoLast();
      expect(c.doc.templates.keys, ['$_id@1']);
      expect(_frontU(c, 1), 3);
    });
  });

  group('the content hash says what it is', () {
    // THIS GROUP USED TO PIN THE PLACEHOLDER. It asserted
    // `unhashed:tpl.hdmi_matrix_16x16@2` and was honest when written:
    // that WAS the intended behaviour, deliberately labelled so nothing
    // could mistake it for a digest. `#795` made the hash real and the
    // assertion had to move with it, which is the good case of a test
    // failing on a change rather than surviving it.
    test('it is the hash of the body that was saved', () {
      final c = _controller();
      buildDeviceBuilderActions(controller: c)
        ..onSave(_body())
        ..onSave(_body(frontU: 4));

      final saved = c.doc.templates['$_id@1']!;
      expect(saved.body.frontU, 4);
      expect(
        saved.contentHash,
        templateContentHash(saved.body),
        reason: 'a replaced snapshot records the hash of its NEW body',
      );
      expect(
        templateHashMatches(saved.body, saved.contentHash),
        isTrue,
        reason: 'and the verifier agrees, which is the pair AC-042 needs',
      );
    });

    test('two versions with DIFFERENT bodies get different hashes', () {
      // The property that makes a mismatch mean anything. Asserted
      // against a value the helper cannot supply: `_body()` and
      // `_body(frontU: 4)` differ in one field, and a hash that ignored
      // it would be a hash of the id rather than of the content.
      final c = _controller();
      final actions = buildDeviceBuilderActions(controller: c)..onSave(_body());
      _place(c, 1);
      actions.onSave(_body(frontU: 4));

      expect(
        c.doc.templates['$_id@1']!.contentHash,
        isNot(c.doc.templates['$_id@2']!.contentHash),
      );
    });
  });
}
