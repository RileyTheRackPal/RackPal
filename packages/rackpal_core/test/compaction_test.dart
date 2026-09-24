// docs/04-rack-editor.md §3.6 — the compaction planner. Every test here
// asserts on the PLAN, never on a mutated document, because that split is
// the feature: §3.6's preview overlay can only exist if planning is free
// of side effects. Two tests assert exactly that (the planner leaves the
// document untouched) rather than taking it on trust.
// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _rackId = Uuid('rack-compaction');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

/// A template whose front and rear heights can differ, identified by the
/// pair so two shapes never collide on one key. `side` is DERIVED from the
/// two heights rather than passed, because a body claiming `both` with
/// `rearU: 0` is a fixture that contradicts itself and would test nothing
/// real.
TemplateSnapshot _template({required int frontU, required int rearU}) {
  final id = 'tpl.f${frontU}r$rearU';
  return TemplateSnapshot(
    templateId: TemplateId(id),
    version: 1,
    contentHash: 'sha256:$id',
    capturedAt: DateTime.utc(2026),
    body: TemplateBody(
      manufacturer: 'Generic',
      model: id,
      displayName: id,
      frontU: frontU,
      rearU: rearU,
      side: frontU > 0 && rearU > 0
          ? OccupancySide.both
          : (frontU > 0 ? OccupancySide.front : OccupancySide.rear),
      mountMethod: MountMethod.rackEars,
    ),
  );
}

typedef _Occ = ({
  String d,
  int ru,
  int h,
  int? otherU,
  Face face,
  bool locked,
});

/// Builds a document with one [heightU] rack and the given occupants,
/// each spelled `(designator, ruIndex, heightU, face, locked)`.
RackDocument _doc(int heightU, List<_Occ> occupants) {
  final doc = RackDocument(
    id: const Uuid('doc-compaction'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Compaction Rack',
    designator: 'RK-1',
    heightU: heightU,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  for (final o in occupants) {
    final other = o.otherU ?? o.h;
    final snapshot = _template(
      frontU: o.face == Face.front ? o.h : other,
      rearU: o.face == Face.front ? other : o.h,
    );
    doc.templates['${snapshot.templateId.v}@1'] = snapshot;
    doc.devices[Uuid('dev-${o.d}')] = DeviceInstance(
      id: Uuid('dev-${o.d}'),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: snapshot.templateId,
        version: 1,
        contentHash: snapshot.contentHash,
      ),
      designator: o.d,
      name: 'Device ${o.d}',
      placement: RailPlacement(
        rackId: _rackId,
        ruIndex: o.ru,
        face: o.face,
        locked: o.locked,
      ),
      meta: _meta(),
    );
  }
  return doc;
}

/// [h] is the height on the face the device is BOLTED to; [otherU] is its
/// height on the other one, defaulting to [h] — the full-depth `side:
/// both` shape every shipped rack-mountable template has. Pass `otherU: 0`
/// for a device only one elevation draws, or a different number for the
/// asymmetric shape no seed template has yet.
_Occ _at(
  String d,
  int ru,
  int h, {
  Face face = Face.front,
  bool locked = false,
  int? otherU,
}) => (d: d, ru: ru, h: h, otherU: otherU, face: face, locked: locked);

CompactionPlan _plan(
  RackDocument doc,
  CompactDirection direction, {
  Face face = Face.front,
}) => planCompaction(
  rack: doc.racks[_rackId]!,
  devices: doc.devices.values,
  face: face,
  templates: doc.templates,
  direction: direction,
);

/// `designator -> toRuIndex`, the shape almost every assertion wants.
Map<String, int> _targets(CompactionPlan plan) => {
  for (final m in plan.moves) m.designator: m.toRuIndex,
};

void main() {
  group('planCompaction — Compact Down', () {
    test('packs occupants against U1, closing every gap below them', () {
      final doc = _doc(12, [_at('A', 3, 1), _at('B', 6, 2), _at('C', 10, 1)]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'A': 1, 'B': 2, 'C': 4});
      expect(plan.direction, CompactDirection.down);
      expect(plan.face, Face.front);
    });

    test('freedU is the contiguous run gained at the top, not the sum of '
        'gaps closed', () {
      // Highest occupied U before = 10 (C at U10, 1U). After: A@1, B@2-3,
      // C@4 -> highest = 4. So 6U of usable space appears at the top, even
      // though the individual gaps closed are 2 + 3 + ... — the point of
      // the assertion is that these two numbers are NOT the same and the
      // plan reports the one the user can spend.
      final doc = _doc(12, [_at('A', 3, 1), _at('B', 6, 2), _at('C', 10, 1)]);

      final plan = _plan(doc, CompactDirection.down);

      expect(plan.freedU, 6);
    });

    test('an already-packed rack yields an empty plan and frees nothing', () {
      final doc = _doc(12, [_at('A', 1, 1), _at('B', 2, 2), _at('C', 4, 1)]);

      final plan = _plan(doc, CompactDirection.down);

      expect(plan.isEmpty, isTrue);
      expect(plan.moves, isEmpty);
      expect(plan.freedU, 0);
      expect(plan.deviceCount, 0);
    });

    test('an empty rack yields an empty plan', () {
      final doc = _doc(12, []);

      expect(_plan(doc, CompactDirection.down).isEmpty, isTrue);
      expect(_plan(doc, CompactDirection.up).isEmpty, isTrue);
    });
  });

  group('planCompaction — Compact Up', () {
    test('packs occupants against the rack top', () {
      final doc = _doc(12, [_at('A', 1, 1), _at('B', 4, 2), _at('C', 8, 1)]);

      final plan = _plan(doc, CompactDirection.up);

      // C (top-most) -> U12; B (2U) -> U10-11; A -> U9.
      expect(_targets(plan), {'C': 12, 'B': 10, 'A': 9});
    });

    test('freedU is the contiguous run gained at the BOTTOM', () {
      final doc = _doc(12, [_at('A', 1, 1), _at('B', 4, 2), _at('C', 8, 1)]);

      final plan = _plan(doc, CompactDirection.up);

      // Lowest occupied U before = 1, after = 9 -> 8U free at the bottom.
      expect(plan.freedU, 8);
    });

    test('is the exact mirror of Compact Down on a symmetric layout', () {
      // Genuinely symmetric in a 10U rack: A holds U2-U3 (one free U
      // below it), B holds U8-U9 (one free U above it). Only then should
      // the two directions free the same amount.
      final down = _plan(
        _doc(10, [_at('A', 2, 2), _at('B', 8, 2)]),
        CompactDirection.down,
      );
      final up = _plan(
        _doc(10, [_at('A', 2, 2), _at('B', 8, 2)]),
        CompactDirection.up,
      );

      expect(_targets(down), {'A': 1, 'B': 3});
      expect(_targets(up), {'B': 9, 'A': 7});
      expect(down.freedU, 5);
      expect(up.freedU, 5);
    });
  });

  group('locked placements are immovable anchors (§3.6, CR-034)', () {
    test('a locked occupant never appears in the move list', () {
      final doc = _doc(12, [
        _at('A', 3, 1),
        _at('LOCKED', 6, 1, locked: true),
        _at('C', 9, 1),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(
        plan.moves.map((m) => m.designator),
        isNot(contains('LOCKED')),
      );
    });

    test('unlocked occupants pack AROUND a locked anchor, never through '
        'it', () {
      final doc = _doc(12, [
        _at('A', 3, 1),
        _at('LOCKED', 6, 1, locked: true),
        _at('C', 9, 1),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      // A -> U1. C settles at U7, immediately above the anchor — it does
      // NOT leapfrog down into the free U2-U5 below it. See the
      // order-preservation group below for why that is deliberate.
      expect(_targets(plan), {'A': 1, 'C': 7});
      // The anchor pins U6, so the top run only reaches down to U8.
      expect(plan.freedU, 2); // highest before 9, after 7
    });

    test('a device too tall to clear an anchor stays exactly where it is', () {
      // 3U device at U8; anchor holds U2. The only run below the anchor is
      // U1 alone, so the 3U device cannot pack down past it and must stay.
      final doc = _doc(12, [
        _at('ANCHOR', 2, 1, locked: true),
        _at('TALL', 8, 3),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'TALL': 3});
      // It moved down to U3-U5 — the lowest run that clears the anchor —
      // rather than being dropped, evicted, or pushed through it.
      expect(plan.moves.single.deviceH, 3);
    });

    test('never packs a device THROUGH an anchor, even from a document '
        'where the two already overlap', () {
      // MUTATION-TEST-DRIVEN. Under the invariant "no two occupants on a
      // face overlap", the monotonic packing cursor alone is enough to
      // keep unlocked devices off anchors, and the planner's explicit
      // locked-range check is unreachable — deleting it broke no test.
      //
      // But nothing in this codebase ENFORCES that invariant: there is no
      // validation engine (explicitly out of scope this stage),
      // `elevationOccupantsOnFace` returns raw model values with no checking,
      // and an overlapping document is representable, loadable and
      // round-trippable. Given one, a cursor-only planner packs TALL
      // straight through the anchor and calls it a no-op. The explicit
      // check is what makes the "locked is immovable" guarantee hold on
      // the actual input rather than on an assumption about it.
      final doc = _doc(12, [
        _at('TALL', 1, 5), // U1-U5
        _at('ANCHOR', 3, 1, locked: true), // U3 — inside TALL's range
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(
        _targets(plan),
        {'TALL': 4},
        reason:
            'TALL must move UP to '
            'the lowest run that clears the anchor, not sit on it',
      );
      expect(
        plan.moves.map((m) => m.designator),
        isNot(contains('ANCHOR')),
      );
    });

    test('an all-locked rack yields an empty plan even with gaps', () {
      final doc = _doc(12, [
        _at('A', 3, 1, locked: true),
        _at('B', 9, 1, locked: true),
      ]);

      expect(_plan(doc, CompactDirection.down).isEmpty, isTrue);
      expect(_plan(doc, CompactDirection.up).isEmpty, isTrue);
    });
  });

  group('compaction PRESERVES RELATIVE ORDER (a decision §3.6 does not '
      'make)', () {
    test('a device never leapfrogs another to reach a lower free run', () {
      // B is 1U and would "fit better" in the 3U hole at U2-U4 left when
      // the 4U device A packs down. A greedy best-fit planner would put it
      // there, silently swapping B below A. This one does not: it only
      // ever closes gaps.
      final doc = _doc(20, [_at('A', 8, 4), _at('B', 15, 1)]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'A': 1, 'B': 5});
      final order = plan.moves.map((m) => m.designator).toList();
      expect(order, ['A', 'B'], reason: 'ascending pass order');
    });

    test('relative order is identical before and after, in both '
        'directions', () {
      for (final direction in CompactDirection.values) {
        final doc = _doc(20, [
          _at('BOTTOM', 2, 1),
          _at('MIDDLE', 9, 3),
          _at('TOP', 16, 1),
        ]);
        final plan = _plan(doc, direction);

        final after = <String, int>{
          'BOTTOM': 2,
          'MIDDLE': 9,
          'TOP': 16,
          ..._targets(plan),
        };
        final byPosition = after.keys.toList()
          ..sort((a, b) => after[a]!.compareTo(after[b]!));
        expect(
          byPosition,
          ['BOTTOM', 'MIDDLE', 'TOP'],
          reason: 'compaction must not reorder the rack ($direction)',
        );
      }
    });
  });

  group('face scope', () {
    test('moves only what is BOLTED to the planned face', () {
      // Both are 1U and full depth, so each is drawn on the OTHER
      // elevation too — and neither plan may relocate the other's device,
      // because a `CompactionMove` becomes
      // `MoveDeviceCommand(fromFace:, toFace:)` and would re-hang it on
      // the wrong rails.
      final doc = _doc(12, [
        _at('FRONT', 5, 1),
        _at('REAR', 9, 1, face: Face.rear),
      ]);

      final front = _plan(doc, CompactDirection.down);
      final rear = _plan(doc, CompactDirection.down, face: Face.rear);

      expect(_targets(front), {'FRONT': 1});
      expect(_targets(rear), {'REAR': 1});
      expect(front.moves.single.face, Face.front);
      expect(rear.moves.single.face, Face.rear);
    });
  });

  // CR-036: `elevationOccupancyU` decides what a face DRAWS, and a
  // `side: both` device bolted to one face is drawn on both. Before this,
  // the planner packed around the BOLTED set only, so Compact Down on the
  // rear could propose a target `findBlockingOccupant` refuses — a preview
  // showing a device sliding into space another device is visibly standing
  // in.
  group("the other face's ink is an obstacle too", () {
    test('Compact Down packs AROUND a device the other face bolted and '
        'this one draws', () {
      // REAR is bolted to the rear rails and is full depth, so the FRONT
      // elevation draws it across U2-U3. The lowest run FRONT can reach is
      // U4, not U1.
      final doc = _doc(12, [
        _at('MOVER', 8, 2),
        _at('DRAWN', 2, 2, face: Face.rear),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'MOVER': 4});
      expect(
        plan.moves.map((m) => m.designator),
        isNot(contains('DRAWN')),
        reason:
            'it is an obstacle, not a mover: moving it would rebolt it '
            'to the front rails',
      );
    });

    test('Compact Up packs AROUND one too', () {
      final doc = _doc(12, [
        _at('MOVER', 2, 2),
        _at('DRAWN', 10, 2, face: Face.rear),
      ]);

      final plan = _plan(doc, CompactDirection.up);

      expect(_targets(plan), {'MOVER': 8});
    });

    test('a move must clear EVERY elevation that draws the mover, not just '
        'the one being planned', () {
      // The front elevation is empty below U9, so a front-only planner
      // sends MOVER to U1. But MOVER is full depth: at U1 its REAR block
      // lands on DRAWN, which is bolted to the rear rails at rear U1-U2
      // and occupies no front U at all. The only honest target is U3.
      final doc = _doc(12, [
        _at('MOVER', 9, 2),
        _at('DRAWN', 1, 2, face: Face.rear, otherU: 0),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'MOVER': 3});
    });

    test('a SINGLE-FACE mover ignores the other elevation entirely', () {
      // The mirror of the case above, and the reason the check is per-face
      // rather than "block on the union": MOVER occupies no rear U, so a
      // rear-only device at rear U1-U2 is nothing to it.
      final doc = _doc(12, [
        _at('MOVER', 9, 2, otherU: 0),
        _at('DRAWN', 1, 2, face: Face.rear, otherU: 0),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'MOVER': 1});
    });

    test('a device is never an obstacle to ITSELF across faces', () {
      // THE REGRESSION THIS GUARDS. Anchoring the elevation scan wholesale
      // — rather than the elevation scan MINUS the movers — pins every
      // full-depth device against its own reflection on the other face, and
      // Compact Down proposes nothing at all. 19 of `whole_house` RK-1's
      // 27 devices are `side: both`, so that failure would be the shipped
      // behaviour, not an edge case.
      final doc = _doc(12, [_at('A', 3, 1), _at('B', 6, 2), _at('C', 10, 1)]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'A': 1, 'B': 2, 'C': 4});
    });

    test("freedU stops at the other face's device: the U above it were "
        "never this elevation's to spend", () {
      final doc = _doc(12, [
        _at('A', 4, 1),
        _at('DRAWN', 9, 1, face: Face.rear),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'A': 1});
      expect(
        plan.freedU,
        0,
        reason:
            'DRAWN still holds U9 of this elevation; the front face '
            'gained nothing at the top',
      );
    });

    test('a rear-only device bolted to the FRONT rails blocks the rear '
        'elevation and not the front', () {
      // `{frontU: 0, rearU: 1}` on the front rails — the rear lace bar
      // `device_loads.dart` keeps naming. The front elevation does not
      // draw it, so a front-only mover packs straight past it; the rear
      // elevation does, so a rear mover does not.
      final doc = _doc(12, [
        _at('FRONTONLY', 6, 1, otherU: 0),
        _at('REARONLY', 5, 1, otherU: 0, face: Face.rear),
        _at('LACE', 1, 0, otherU: 1),
      ]);

      expect(
        _targets(_plan(doc, CompactDirection.down)),
        {'FRONTONLY': 1},
        reason: 'LACE occupies no front U, so U1 really is free here',
      );
      expect(
        _targets(_plan(doc, CompactDirection.down, face: Face.rear)),
        {'REARONLY': 2},
        reason: 'LACE draws rear U1, so the lowest rear run is U2',
      );
    });

    test('a mover is bounded by its TALLER face, so its rear block never '
        'overhangs the rack top', () {
      // `frontU 1 / rearU 4` compacted UP on the FRONT elevation. Bounded
      // by the 1U front block it would go to U12 and stand four U in a
      // twelve-U rack; the packer has to reserve the whole stack.
      final doc = _doc(12, [_at('LACE', 2, 1, otherU: 4)]);

      final plan = _plan(doc, CompactDirection.up);

      expect(_targets(plan), {'LACE': 9});
    });

    test('two movers on ONE face can still collide on the OTHER, and the '
        'pass tracks both', () {
      // X is `frontU 1 / rearU 4`, so it holds one front U and four rear
      // U. Y is 1U on both. The front elevation says U2 is free the
      // instant X is placed at U1 — and it is, but X's rear block runs to
      // rear U4, so Y cannot follow it up until U5.
      final doc = _doc(16, [
        _at('X', 1, 1, otherU: 4),
        _at('Y', 6, 1),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'Y': 5});
    });

    test('...and the next front U really is the next front U when the '
        'follower occupies no rear', () {
      // The mirror of the case above, and the reason the packing cursor
      // steps by the PLANNED face's height rather than by the stack. Z is
      // front-only, so X's four rear U are nothing to it: U2 is free, the
      // user can see that it is free, and a plan that skipped to U5 would
      // leave a hole it could not explain.
      final doc = _doc(16, [
        _at('X', 1, 1, otherU: 4),
        _at('Z', 8, 1, otherU: 0),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'Z': 2});
    });

    test('a device that could not move is an obstacle where it STANDS, not '
        'where the cursor thinks it ends', () {
      // MUTATION-TEST-DRIVEN, and the fixture is the whole test. ANCHOR
      // pins U1-U9, so STUCK — `frontU 1 / rearU 4` at U10 — has nowhere
      // legal to go: its rear block would need U10-U13 of a 12U rack. It
      // stays, overhanging, because compaction never evicts. The cursor
      // then steps past its ONE front U to U11, and B is the device that
      // finds out whether the pass remembers the other three: U11 and U12
      // are free on the front elevation and occupied on the rear.
      final doc = _doc(12, [
        _at('ANCHOR', 1, 9, locked: true),
        _at('STUCK', 10, 1, otherU: 4),
        _at('B', 12, 1),
      ]);

      final plan = _plan(doc, CompactDirection.down);

      expect(
        plan.isEmpty,
        isTrue,
        reason:
            'B has no legal home either; moving it to U11 would put it '
            "inside STUCK's rear block",
      );
    });

    test('applying a plan leaves NO range findBlockingOccupant would call '
        'occupied — the invariant the whole obstacle set exists for', () {
      for (final direction in CompactDirection.values) {
        for (final face in Face.values) {
          final doc = _doc(16, [
            _at('A', 3, 2),
            _at('B', 9, 1),
            _at('C', 14, 1, otherU: 0),
            _at('D', 5, 2, face: Face.rear),
            _at('E', 12, 1, face: Face.rear, otherU: 0),
          ]);
          final plan = _plan(doc, direction, face: face);
          for (final c in compactionCommands(
            plan,
            now: DateTime.utc(2026),
            actor: 't',
          )) {
            c.apply(doc);
          }

          for (final f in Face.values) {
            for (final o in elevationOccupantsOnFace(
              rack: doc.racks[_rackId]!,
              devices: doc.devices.values,
              face: f,
              templates: doc.templates,
            )) {
              expect(
                findBlockingOccupant(
                  rack: doc.racks[_rackId]!,
                  devices: doc.devices.values,
                  face: f,
                  templates: doc.templates,
                  ruStart: o.ruIndex,
                  deviceH: o.deviceH,
                  exceptId: o.device.id,
                ),
                isNull,
                reason:
                    '$direction on ${face.name} put '
                    '${o.device.designator} at ${f.name} U${o.ruIndex} on '
                    'top of another device',
              );
            }
          }
        }
      }
    });
  });

  group('purity', () {
    test('planning mutates no device placement and no rack', () {
      final doc = _doc(12, [_at('A', 3, 1), _at('B', 6, 2)]);
      final before = {
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      };

      _plan(doc, CompactDirection.down);
      _plan(doc, CompactDirection.up);

      expect({
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      }, before);
      expect(doc.racks[_rackId]!.heightU, 12);
    });

    test('the same inputs always produce the same move ORDER', () {
      // Determinism matters: the preview overlay and the committed
      // Transaction are built from two separate calls, and a Map-iteration-
      // order-dependent planner could show one thing and apply another.
      final a = _plan(
        _doc(12, [_at('A', 3, 1), _at('B', 6, 1), _at('C', 9, 1)]),
        CompactDirection.down,
      );
      final b = _plan(
        _doc(12, [_at('C', 9, 1), _at('B', 6, 1), _at('A', 3, 1)]),
        CompactDirection.down,
      );

      expect(
        a.moves.map((m) => '${m.designator}->${m.toRuIndex}').toList(),
        b.moves.map((m) => '${m.designator}->${m.toRuIndex}').toList(),
      );
    });
  });

  group('compactionCommands', () {
    test('emits one MoveDeviceCommand per move, preserving face', () {
      final doc = _doc(12, [_at('A', 3, 1), _at('B', 6, 2)]);
      final plan = _plan(doc, CompactDirection.down);

      final cmds = compactionCommands(
        plan,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );

      expect(cmds, hasLength(2));
      expect(cmds.every((c) => c.fromFace == c.toFace), isTrue);
      expect(cmds.map((c) => c.toRuIndex), [1, 2]);
    });

    test('applying them realises the plan; reverting in reverse restores '
        'every original position', () {
      final doc = _doc(12, [_at('A', 3, 1), _at('B', 6, 2), _at('C', 10, 1)]);
      final plan = _plan(doc, CompactDirection.down);
      final cmds = compactionCommands(
        plan,
        now: DateTime.utc(2026, 1, 2),
        actor: 'tester',
      );
      final before = {
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      };

      for (final c in cmds) {
        c.apply(doc);
      }
      expect(
        {
          for (final d in doc.devices.values)
            d.designator: (d.placement as RailPlacement).ruIndex,
        },
        {'A': 1, 'B': 2, 'C': 4},
      );

      for (var i = cmds.length - 1; i >= 0; i--) {
        cmds[i].revert(doc);
      }
      expect({
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      }, before);
    });

    test('an empty plan emits no commands — "nothing to do" stays nothing', () {
      final doc = _doc(12, [_at('A', 1, 1)]);

      expect(
        compactionCommands(
          _plan(doc, CompactDirection.down),
          now: DateTime.utc(2026),
          actor: 't',
        ),
        isEmpty,
      );
    });
  });

  group('elevationOccupantsOnFace (the shared occupancy primitive)', () {
    test('returns raw, UNCLIPPED ruIndex/deviceH so an overflowing '
        'occupant is visible', () {
      final doc = _doc(12, [_at('OVER', 11, 4)]);

      final occ = elevationOccupantsOnFace(
        rack: doc.racks[_rackId]!,
        devices: doc.devices.values,
        face: Face.front,
        templates: doc.templates,
      );

      expect(occ.single.ruIndex, 11);
      expect(
        occ.single.deviceH,
        4,
        reason:
            'clipping to the rack extent '
            'here would hide exactly the case the shrink planner exists for',
      );
    });

    test('is ascending by ruIndex and carries the locked flag', () {
      final doc = _doc(12, [
        _at('C', 9, 1),
        _at('A', 2, 1, locked: true),
        _at('B', 5, 1),
      ]);

      final occ = elevationOccupantsOnFace(
        rack: doc.racks[_rackId]!,
        devices: doc.devices.values,
        face: Face.front,
        templates: doc.templates,
      );

      expect(occ.map((o) => o.device.designator), ['A', 'B', 'C']);
      expect(occ.map((o) => o.locked), [true, false, false]);
    });

    test('findLowestFreeRu still agrees with it after the refactor', () {
      final doc = _doc(12, [_at('A', 1, 2), _at('B', 5, 1)]);

      expect(
        findLowestFreeRu(
          rack: doc.racks[_rackId]!,
          devices: doc.devices.values,
          face: Face.front,
          templates: doc.templates,
          deviceH: 2,
        ),
        3,
      );
    });
  });

  // The scan skips a rail device whose template snapshot is missing, which
  // is right for its placement callers and wrong here: a packer that
  // cannot see something bolted to the rails will pack another device
  // straight through it, out of a preview that showed no conflict at all.
  group('devices the scan cannot model are immovable anchors', () {
    /// Rail-placed on this rack, with no `templates[...]` entry — exactly
    /// what a file load can produce and `elevationOccupantsOnFace` drops.
    void addOrphan(
      RackDocument doc,
      String d,
      int ru, {
      Face face = Face.front,
    }) {
      doc.devices[Uuid('dev-$d')] = DeviceInstance(
        id: Uuid('dev-$d'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.missing'),
          version: 9,
          contentHash: 'sha256:tpl.missing',
        ),
        designator: d,
        name: 'Device $d',
        placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: face),
        meta: _meta(),
      );
    }

    test(
      'Compact Down packs AROUND an unmodelled device, never through it',
      () {
        final doc = _doc(12, [_at('A', 8, 2)]);
        addOrphan(doc, 'ORPHAN', 2);

        final plan = _plan(doc, CompactDirection.down);

        expect(
          _targets(plan),
          {'A': 3},
          reason:
              'U1-U2 is the lowest free run only if U2 is empty, and it '
              'is not — ORPHAN is standing on it',
        );
      },
    );

    test('Compact Up packs AROUND one too', () {
      final doc = _doc(12, [_at('A', 2, 2)]);
      addOrphan(doc, 'ORPHAN', 11);

      final plan = _plan(doc, CompactDirection.up);

      expect(_targets(plan), {'A': 9});
    });

    test('freedU stops at an unmodelled device: the U above it were never '
        "the user's to spend", () {
      final doc = _doc(12, [_at('A', 4, 1)]);
      addOrphan(doc, 'ORPHAN', 9);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'A': 1});
      expect(
        plan.freedU,
        0,
        reason: 'ORPHAN still holds U9; nothing was freed at the top',
      );
    });

    test('an unmodelled device on the OTHER face anchors nothing for a '
        'mover that occupies only this one', () {
      // A is front-only, so nothing it does can land on the rear rails
      // ORPHAN is bolted to. The single U ORPHAN claims is a rear U.
      final doc = _doc(12, [_at('A', 8, 2, otherU: 0)]);
      addOrphan(doc, 'ORPHAN', 2, face: Face.rear);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'A': 1});
    });

    test('...but it anchors a FULL-DEPTH mover, whose rear block would land '
        'on it', () {
      // The same fixture with A full depth. Packing A to U1 puts its rear
      // block across rear U1-U2, and ORPHAN is standing on rear U2 — a U
      // no elevation can draw, which is exactly why the packer has to be
      // told about it rather than shown it.
      final doc = _doc(12, [_at('A', 8, 2)]);
      addOrphan(doc, 'ORPHAN', 2, face: Face.rear);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'A': 3});
    });
  });
}
