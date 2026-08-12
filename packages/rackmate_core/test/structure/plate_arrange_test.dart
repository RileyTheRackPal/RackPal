// M3-H/2 (#167). The arrange proposal, and the two things it must never
// do: invent a termination, and split a speaker pair across openings when
// they fit in one.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 11);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _outletId = Uuid('22222222-2222-4222-8222-222222222222');
const _bodyId = Uuid('11111111-1111-4111-8111-111111111111');

var _seq = 0;

Link _drop({
  required String fieldLabel,
  TerminationType? termination,
  int conductors = 2,
  Uuid? id,
  Uuid? outletId,
}) {
  _seq++;
  return Link(
    id:
        id ??
        Uuid('55555555-5555-4555-8555-${_seq.toString().padLeft(12, '0')}'),
    designator: 'W$_seq',
    media: const MediaTypeId('media.cat6'),
    order: FracIndex('a$_seq'),
    meta: _meta(),
    conductors: [
      for (var i = 0; i < conductors; i++)
        const Conductor(from: OpenEndpoint('a'), to: OpenEndpoint('b')),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: _bodyId,
      outletId: outletId ?? _outletId,
      fieldLabel: fieldLabel,
      terminationField: termination,
    ),
  );
}

Outlet _outlet({List<Gang>? gangs}) => Outlet(
  id: _outletId,
  structureBodyId: _bodyId,
  designation: 'WP-1',
  order: const FracIndex('a0'),
  meta: _meta(),
  gangs: gangs,
);

void main() {
  group('the plan sizes the plate from the termination table', () {
    test('three keystone drops become one 3-port strap', () {
      final plan = planPlateArrangement(_outlet(), [
        _drop(fieldLabel: 'LR-DATA-1', termination: TerminationType.keystone),
        _drop(fieldLabel: 'LR-DATA-2', termination: TerminationType.keystone),
        _drop(fieldLabel: 'LR-TV-1', termination: TerminationType.fBarrel),
      ]);
      expect(plan.straps, [(width: 1, height: 3)]);
      expect(plan.cells, hasLength(3));
      expect(plan.skippedUnknown, 0);
    });

    test('a 16/4 on binding posts alone needs a 2x2, not a 3-port', () {
      // §11.7.2.2's case that bites, arrived at by arithmetic rather
      // than by anybody remembering it.
      final plan = planPlateArrangement(_outlet(), [
        _drop(
          fieldLabel: 'LR-SPK-1',
          termination: TerminationType.bindingPost,
          conductors: 4,
        ),
      ]);
      expect(plan.straps, [(width: 2, height: 2)]);
      expect(plan.cells, hasLength(4));
      expect(plan.cells.every((c) => c.occupant is ConductorOccupant), isTrue);
    });

    test('seven cells spill into a second gang', () {
      final plan = planPlateArrangement(_outlet(), [
        for (var i = 0; i < 7; i++)
          _drop(
            fieldLabel: 'LR-DATA-$i',
            termination: TerminationType.keystone,
          ),
      ]);
      expect(plan.straps, hasLength(2));
      expect(plan.straps.first, (width: 2, height: 3));
      expect(plan.straps.last, (width: 1, height: 1));
      expect(plan.cells.where((c) => c.gangIndex == 1), hasLength(1));
    });

    test('a coil takes no cell and does not open a gang', () {
      final plan = planPlateArrangement(_outlet(), [
        _drop(
          fieldLabel: 'LR-SPARE-1',
          termination: TerminationType.unterminated,
        ),
      ]);
      expect(plan.isEmpty, isTrue);
      expect(plan.skippedUnknown, 0);
    });
  });

  group('a drop with no termination is skipped and COUNTED', () {
    test('it never becomes a single keystone by assumption', () {
      final plan = planPlateArrangement(_outlet(), [
        _drop(fieldLabel: 'LR-DATA-1', termination: TerminationType.keystone),
        _drop(fieldLabel: 'LR-DATA-2'),
        _drop(fieldLabel: 'LR-DATA-3'),
      ]);
      // ONE cell, not three. The honest answers for an unrecorded
      // termination range from zero to four and this picks none of them.
      expect(plan.cells, hasLength(1));
      expect(plan.skippedUnknown, 2);
      expect(plan.straps, [(width: 1, height: 1)]);
    });
  });

  group('a speaker pair is not split across openings when it fits', () {
    test('five keystones then a 16/2 puts both posts in gang 1', () {
      final plan = planPlateArrangement(_outlet(), [
        for (var i = 0; i < 5; i++)
          _drop(
            fieldLabel: 'LR-DATA-$i',
            termination: TerminationType.keystone,
          ),
        // Two conductors, which is `_drop`'s default: a 16/2 pair.
        _drop(fieldLabel: 'LR-SPK-9', termination: TerminationType.bindingPost),
      ]);
      // Five fit in gang 0 with one cell spare. Filling that spare with
      // one post and pushing the other to gang 1 is LEGAL under §11.7.2
      // and is a rotten thing to hand an installer.
      final posts = plan.cells.where((c) => c.occupant is ConductorOccupant);
      expect(posts.map((c) => c.gangIndex).toSet(), hasLength(1));
      expect(posts.first.gangIndex, 1);
    });
  });

  group('the plan is deterministic', () {
    test('two runs over one document give the identical plan', () {
      final links = [
        _drop(fieldLabel: 'LR-TV-1', termination: TerminationType.fBarrel),
        _drop(fieldLabel: 'LR-DATA-1', termination: TerminationType.keystone),
        _drop(fieldLabel: 'LR-KEY-1', termination: TerminationType.punchdown),
      ];
      String render(PlateArrangement p) => p.cells
          .map((c) => '${c.gangIndex}:${c.cellIndex}:${c.occupant}')
          .join('|');
      expect(
        render(planPlateArrangement(_outlet(), links)),
        render(planPlateArrangement(_outlet(), links.reversed.toList())),
      );
    });

    test('cells come out in field-label order, not in document order', () {
      final plan = planPlateArrangement(_outlet(), [
        _drop(fieldLabel: 'LR-TV-1', termination: TerminationType.fBarrel),
        _drop(fieldLabel: 'LR-DATA-1', termination: TerminationType.keystone),
      ]);
      expect(plan.cells.first.cellIndex, 0);
      // LR-DATA-1 sorts before LR-TV-1 and therefore takes cell 0.
      expect(plan.cells.first.occupant, isA<LinkEndOccupant>());
    });
  });

  group('unplaced counts what the plate does not yet hold IN FULL', () {
    test('a half-placed 16/4 is still unplaced', () {
      final strap = Strap(width: 2, height: 3);
      final speaker = _drop(
        fieldLabel: 'LR-SPK-1',
        termination: TerminationType.bindingPost,
        conductors: 4,
      );
      strap.cells[0] = ConductorOccupant(ConductorRef(speaker.id, 0));
      strap.cells[1] = ConductorOccupant(ConductorRef(speaker.id, 1));
      // Two of four posts. Counting this as done would take it off the
      // picker with two conductors still homeless.
      expect(
        unplacedDropsOf(_outlet(gangs: [Gang(fitting: strap)]), [speaker]),
        [speaker.id],
      );

      strap.cells[2] = ConductorOccupant(ConductorRef(speaker.id, 2));
      strap.cells[3] = ConductorOccupant(ConductorRef(speaker.id, 3));
      expect(
        unplacedDropsOf(_outlet(gangs: [Gang(fitting: strap)]), [speaker]),
        isEmpty,
      );
    });

    test('a coil is not waiting for a cell', () {
      final coil = _drop(
        fieldLabel: 'LR-SPARE-1',
        termination: TerminationType.unterminated,
      );
      expect(unplacedDropsOf(_outlet(), [coil]), isEmpty);
    });

    test('a drop with no termination stays visible as unplaced', () {
      final unknown = _drop(fieldLabel: 'LR-DATA-9');
      expect(unplacedDropsOf(_outlet(), [unknown]), [unknown.id]);
    });

    test('another outlet s drops are not this plate s problem', () {
      final elsewhere = _drop(
        fieldLabel: 'KIT-DATA-1',
        termination: TerminationType.keystone,
        outletId: const Uuid('99999999-9999-4999-8999-999999999999'),
      );
      expect(unplacedDropsOf(_outlet(), [elsewhere]), isEmpty);
    });
  });

  group('arrange neither invents a pass-through nor destroys one', () {
    test('a plate of drops that need cells plans NO pass-through', () {
      // Fitting one would assert a purchase nobody made. Arrange plans
      // from §11.7.2.1's table and a brush is nowhere in it.
      final plan = planPlateArrangement(_outlet(), [
        _drop(fieldLabel: 'LR-DATA-1', termination: TerminationType.keystone),
      ]);
      expect(plan.keptPassThroughs, isEmpty);
      expect(plan.straps, hasLength(1));
    });

    test('a brushed opening comes back in the plan, in gang order', () {
      // DR-047 §11.46.6. Arrange rebuilds the plate from nothing, so a
      // brush that is not in the plan is a part deleted by a gesture
      // nobody thought was destructive.
      final plan = planPlateArrangement(
        _outlet(
          gangs: [
            Gang(fitting: const PassThrough(PassThroughStyle.bullNose)),
            Gang(fitting: Strap(width: 1, height: 1)),
            Gang(fitting: const PassThrough(PassThroughStyle.brush)),
          ],
        ),
        [_drop(fieldLabel: 'LR-DATA-1', termination: TerminationType.keystone)],
      );
      expect(plan.keptPassThroughs, [
        PassThroughStyle.bullNose,
        PassThroughStyle.brush,
      ]);
    });

    test('a plate of nothing but brushes has NOTHING to arrange', () {
      // isEmpty deliberately ignores the kept brushes: returning false
      // would make Arrange tear those gangs down and build them straight
      // back, which is one undo entry and no change.
      final plan = planPlateArrangement(
        _outlet(
          gangs: [Gang(fitting: const PassThrough(PassThroughStyle.brush))],
        ),
        [
          _drop(
            fieldLabel: 'LR-AP-1',
            termination: TerminationType.rj45Plug,
          ),
        ],
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.keptPassThroughs, [PassThroughStyle.brush]);
    });

    test('a brushed opening neither places a drop nor hides one', () {
      // It has no cells, so a drop that needs one is still unplaced.
      final drop = _drop(
        fieldLabel: 'LR-DATA-1',
        termination: TerminationType.keystone,
      );
      expect(
        unplacedDropsOf(
          _outlet(
            gangs: [Gang(fitting: const PassThrough(PassThroughStyle.brush))],
          ),
          [drop],
        ),
        [drop.id],
      );
    });
  });
}
