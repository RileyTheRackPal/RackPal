// M3-C/5, #151 — the APP is the caller that drives
// `planOutletFromTemplate`.
//
// The picker is `rackmate_ui`'s and is tested there. What this file tests
// is the twenty lines between a pick and the undo stack, which is exactly
// the seam M3-A/6 found a defect in on the sibling surface: the preview's
// clock and the literal string `preview` reaching `EntityMeta` on real
// cable records, invisible to all fourteen gates.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/src/session/outlet_template_actions.dart';
import 'package:rackmate_core/rackmate_core.dart';

final DateTime _when = DateTime.utc(2026, 8, 8, 9, 30);

typedef _Wired = ({DocumentController controller, Uuid livingRoom});

_Wired _controller({String code = 'LR', bool withStructure = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-151'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'seed'),
  )..registries = buildSeedRegistries();

  if (withStructure) {
    AddStructureCommand(
      title: 'Rough-In',
      designator: 'STR-1',
      now: _when,
      actor: 'seed',
    ).apply(doc);
  }
  final room = AddLocationCommand(
    name: 'Living Room',
    code: code,
    order: nextLocationOrder(doc),
    now: _when,
    actor: 'seed',
  )..apply(doc);

  // A FIXED CLOCK AND A NAMED ACTOR, because both are the thing under
  // test: they must reach `EntityMeta` and the preview's must not.
  return (
    controller: DocumentController(
      doc,
      clock: FixedClock(_when),
      actor: 'the-integrator',
    ),
    livingRoom: room.id,
  );
}

OutletTemplate _template(DocumentController c, String id) =>
    c.doc.registries.outletTemplates[id]!;

void main() {
  group('the caller reaches planOutletFromTemplate', () {
    test('a picked recipe becomes one outlet and its drops', () {
      final w = _controller();
      final actions = buildOutletTemplateActions(controller: w.controller);

      final result = actions.onCommit(
        _template(w.controller, 'outlet.tv_location'),
        w.livingRoom,
      );

      expect(result, isA<OutletTemplatePlanReady>());
      expect(w.controller.doc.outlets, hasLength(1));
      expect(w.controller.doc.links, hasLength(4));
      // AC-019: the origin lives ON the Link, which is what proves these
      // came through `buildAddHomeRunCommand` and not some other path.
      for (final l in w.controller.doc.links.values) {
        expect(l.structureOrigin, isNotNull);
      }
    });

    test('and the outlet records the template that created it', () {
      final w = _controller();
      buildOutletTemplateActions(
        controller: w.controller,
      ).onCommit(_template(w.controller, 'outlet.tv_location'), w.livingRoom);

      expect(
        w.controller.doc.outlets.values.single.outletTemplateId,
        'outlet.tv_location',
      );
    });
  });

  group('WHOSE NAME IS ON THE CABLE', () {
    test("the controller's actor and clock reach EntityMeta, never the "
        "picker's preview", () {
      // The defect M3-A/6 found on the sibling surface. The picker plans
      // with `actor: 'preview'` and `DateTime.now()` to draw its preview,
      // and those reach every command a plan holds. If this file handed
      // the app the preview's COMMANDS instead of the choice, every
      // cable in the document would record `preview` as its author and
      // nothing downstream would question it.
      final w = _controller();
      buildOutletTemplateActions(
        controller: w.controller,
      ).onCommit(_template(w.controller, 'outlet.tv_location'), w.livingRoom);

      for (final l in w.controller.doc.links.values) {
        expect(l.meta.updatedBy, 'the-integrator');
        expect(l.meta.createdAt, _when);
      }
      expect(
        w.controller.doc.outlets.values.single.meta.updatedBy,
        'the-integrator',
      );
      for (final n in w.controller.doc.nets.values) {
        expect(n.meta.updatedBy, 'the-integrator');
      }
    });
  });

  group('one pick is one undo entry', () {
    test('undo takes the plate back with its cables', () {
      final w = _controller();
      final c = w.controller;
      buildOutletTemplateActions(
        controller: c,
      ).onCommit(_template(c, 'outlet.tv_location'), w.livingRoom);

      expect(c.doc.outlets, hasLength(1));
      expect(c.doc.links, hasLength(4));

      expect(c.undo.canUndo, isTrue);
      c.undo.undo(c.doc);

      // ALL FIVE COMMANDS, not the last one. A plate and its four cables
      // are what a person means by "that outlet".
      expect(c.doc.outlets, isEmpty);
      expect(c.doc.links, isEmpty);
    });

    test('and it is labelled as an outlet, not as drops', () {
      // `LabelKey.addOutletFromTemplate` rather than `addDrops`: the unit
      // the person undoes is the plate they pointed at.
      final w = _controller();
      final c = w.controller;
      buildOutletTemplateActions(
        controller: c,
      ).onCommit(_template(c, 'outlet.tv_location'), w.livingRoom);

      expect(c.undo.undoLabelKey, LabelKey.addOutletFromTemplate.name);
    });

    test('a refusal spends no undo entry', () {
      // A room with no code cannot be labelled, so nothing is applied.
      final w = _controller(code: '');
      final c = w.controller;
      final result = buildOutletTemplateActions(
        controller: c,
      ).onCommit(_template(c, 'outlet.tv_location'), w.livingRoom);

      expect(result, isA<OutletTemplatePlanRefused>());
      expect(c.doc.outlets, isEmpty);
      expect(c.doc.links, isEmpty);
      expect(c.undo.canUndo, isFalse);
    });
  });

  group('the offer', () {
    test('a project with no Structure device gets one, and then works', () {
      final w = _controller(withStructure: false);
      final c = w.controller;
      final actions = buildOutletTemplateActions(controller: c);

      expect(
        actions.onCommit(_template(c, 'outlet.ap'), w.livingRoom),
        isA<OutletTemplatePlanNeedsStructure>(),
      );

      actions.onCreateStructure();
      expect(c.doc.structures, hasLength(1));

      expect(
        actions.onCommit(_template(c, 'outlet.ap'), w.livingRoom),
        isA<OutletTemplatePlanReady>(),
      );
      expect(c.doc.links, hasLength(1));
    });
  });

  group('the grade presets, end to end through the app', () {
    test('a Grade 2 pick stamps the citation on the outlet', () {
      // DR-024's whole point: the preset can now stamp the standards tag
      // it exists to carry, and the tag reaches the document.
      final w = _controller();
      final c = w.controller;
      buildOutletTemplateActions(
        controller: c,
      ).onCommit(_template(c, 'outlet.tia570d_grade2'), w.livingRoom);

      expect(
        c.doc.outlets.values.single.tia570Grade,
        'TIA-570-D Grade 2',
      );
    });

    test('and undo takes the citation back with the plate', () {
      final w = _controller();
      final c = w.controller;
      buildOutletTemplateActions(
        controller: c,
      ).onCommit(_template(c, 'outlet.tia570d_grade2'), w.livingRoom);

      c.undo.undo(c.doc);
      expect(c.doc.outlets, isEmpty);
    });
  });
}
