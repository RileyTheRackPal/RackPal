// DR-047 — the APP is the caller that must put the brushes back.
//
// WHY THIS FILE EXISTS AT ALL. `buildOutletsActions` had no test of its
// own, and `Arrange` is the one gesture where that is expensive:
// `planPlateArrangement` returns the pass-throughs to keep, core proves
// the plan carries them, and `outlets_view_test.dart`'s harness
// REIMPLEMENTS arrange without the loop that re-fits them. So both ends
// were green and the twenty lines between them could have deleted a part
// somebody chose, which is the shape `.okf/gates/callbacks-have-callers.md`
// collects.
//
// The arrange transaction rebuilds the plate from nothing: every gang is
// removed and the planned straps are added. A brush that is not re-fitted
// is a purchase erased by a gesture nobody thinks of as destructive.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/outlet_plate_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

final DateTime _when = DateTime.utc(2026, 8, 12, 9, 30);

const _outletId = Uuid('22222222-2222-4222-8222-222222222222');
const _bodyId = Uuid('11111111-1111-4111-8111-111111111111');

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'seed');

var _seq = 0;

DocumentController _controller({List<Gang>? gangs}) {
  final doc = RackDocument(
    id: const Uuid('doc-047'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  doc.structures[_bodyId] = StructureBody(
    id: _bodyId,
    deviceId: const Uuid('33333333-3333-4333-8333-000000000001'),
    title: 'Rough-In',
    meta: _meta(),
  );
  doc.outlets[_outletId] = Outlet(
    id: _outletId,
    structureBodyId: _bodyId,
    designation: 'WP-1',
    order: const FracIndex('a0'),
    meta: _meta(),
    gangs: gangs,
  );
  return DocumentController(doc, clock: FixedClock(_when), actor: 'the-tech');
}

void _addDrop(DocumentController c, TerminationType termination) {
  _seq++;
  final link = Link(
    id: Uuid('44444444-4444-4444-8444-${_seq.toString().padLeft(12, '0')}'),
    designator: 'W$_seq',
    media: const MediaTypeId('media.cat6'),
    order: FracIndex('a$_seq'),
    meta: _meta(),
    conductors: const [
      Conductor(from: OpenEndpoint('a'), to: OpenEndpoint('b')),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: _bodyId,
      outletId: _outletId,
      fieldLabel: 'LR-DATA-$_seq',
      terminationField: termination,
    ),
  );
  c.doc.links[link.id] = link;
}

List<Gang> _gangsOf(DocumentController c) => c.doc.outlets[_outletId]!.gangs;

void main() {
  group('a pass-through is fitted through the session (DR-047)', () {
    test('the action reaches the command and lands one undo entry', () {
      final c = _controller(gangs: [Gang()]);
      final actions = buildOutletsActions(controller: c, onRemove: (_) {});

      expect(
        actions.onSetPassThrough(_outletId, 0, PassThroughStyle.brush),
        isNull,
      );
      expect(
        _gangsOf(c).single.fitting,
        const PassThrough(PassThroughStyle.brush),
      );
      expect(c.undo.undoLabelKey, LabelKey.setGangPassThrough.name);
    });

    test('a gang index nobody has is refused, and says which', () {
      final c = _controller(gangs: [Gang()]);
      final actions = buildOutletsActions(controller: c, onRemove: (_) {});
      expect(
        actions.onSetPassThrough(_outletId, 4, PassThroughStyle.brush),
        'That outlet has no gang 5.',
      );
    });

    test('a brushed gang refuses a cell in ITS OWN WORDS', () {
      // Three arms, three sentences. "No strap yet" invites somebody to
      // pick one; "it is a pass-through" tells them the plate is right.
      final c = _controller(
        gangs: [
          Gang(fitting: const PassThrough(PassThroughStyle.brush)),
          Gang(),
        ],
      );
      final actions = buildOutletsActions(controller: c, onRemove: (_) {});
      expect(
        actions.onSetCell(_outletId, 0, 0, const BlankInsert()),
        'Gang 1 is a pass-through, so it has no cells.',
      );
      expect(
        actions.onSetCell(_outletId, 1, 0, const BlankInsert()),
        'Gang 2 has no strap yet, so it has no cells.',
      );
    });
  });

  group('ARRANGE PUTS THE BRUSHES BACK (§11.46.6)', () {
    test('a brushed opening survives an arrange that rebuilds the plate', () {
      final c = _controller(
        gangs: [Gang(fitting: const PassThrough(PassThroughStyle.bullNose))],
      );
      _addDrop(c, TerminationType.keystone);
      _addDrop(c, TerminationType.keystone);

      final outlet = c.doc.outlets[_outletId]!;
      final plan = planPlateArrangement(outlet, c.doc.links.values);
      expect(
        buildOutletsActions(
          controller: c,
          onRemove: (_) {},
        ).onArrange(_outletId, plan),
        isNull,
      );

      final gangs = _gangsOf(c);
      // One strap for the two keystones, and the brush BACK, after it.
      expect(gangs, hasLength(2));
      expect((gangs[0].fitting! as Strap).cellCount, 2);
      expect(
        gangs[1].fitting,
        const PassThrough(PassThroughStyle.bullNose),
        reason: 'arrange rebuilds the plate and must not eat a chosen part',
      );
    });

    test('the whole rebuild is ONE undo entry, brushes included', () {
      final c = _controller(
        gangs: [Gang(fitting: const PassThrough(PassThroughStyle.brush))],
      );
      _addDrop(c, TerminationType.keystone);

      final plan = planPlateArrangement(
        c.doc.outlets[_outletId]!,
        c.doc.links.values,
      );
      buildOutletsActions(
        controller: c,
        onRemove: (_) {},
      ).onArrange(_outletId, plan);
      expect(c.undo.undoLabelKey, LabelKey.arrangePlate.name);

      c.undo.undo(c.doc);
      final gangs = _gangsOf(c);
      expect(gangs, hasLength(1));
      expect(
        gangs.single.fitting,
        const PassThrough(PassThroughStyle.brush),
        reason: 'one entry means the brushes unwind with the straps',
      );
    });

    test('a plate of nothing but brushes is refused rather than churned', () {
      // `PlateArrangement.isEmpty` ignores the kept brushes on purpose:
      // tearing them down and building them straight back is one undo
      // entry, no change, and a person wondering what happened.
      final c = _controller(
        gangs: [Gang(fitting: const PassThrough(PassThroughStyle.brush))],
      );
      _addDrop(c, TerminationType.rj45Plug);

      final plan = planPlateArrangement(
        c.doc.outlets[_outletId]!,
        c.doc.links.values,
      );
      expect(
        buildOutletsActions(
          controller: c,
          onRemove: (_) {},
        ).onArrange(_outletId, plan),
        'There is nothing to arrange on this plate.',
      );
      expect(
        _gangsOf(c).single.fitting,
        const PassThrough(PassThroughStyle.brush),
      );
    });
  });
}
