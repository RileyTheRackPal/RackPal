// docs/04-rack-editor.md §3.6 — the compaction planner. Every test here
// asserts on the PLAN, never on a mutated document, because that split is
// the feature: §3.6's preview overlay can only exist if planning is free
// of side effects. Two tests assert exactly that (the planner leaves the
// document untouched) rather than taking it on trust.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _rackId = Uuid('rack-compaction');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

/// A template whose front and rear heights can differ, so the "one face at
/// a time" contract and CR-036's per-face occupancy are both testable.
TemplateSnapshot _template(String id, {required int frontU, int? rearU}) =>
    TemplateSnapshot(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'sha256:$id',
      capturedAt: DateTime.utc(2026),
      body: TemplateBody(
        manufacturer: 'Generic',
        model: id,
        displayName: id,
        frontU: frontU,
        rearU: rearU ?? frontU,
        side: OccupancySide.both,
        mountMethod: MountMethod.rackEars,
      ),
    );

/// Builds a document with one [heightU] rack and the given occupants,
/// each spelled `(designator, ruIndex, heightU, face, locked)`.
RackDocument _doc(
  int heightU,
  List<({String d, int ru, int h, Face face, bool locked})> occupants,
) {
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
    final templateId = 'tpl.h${o.h}';
    doc.templates['$templateId@1'] = _template(templateId, frontU: o.h);
    doc.devices[Uuid('dev-${o.d}')] = DeviceInstance(
      id: Uuid('dev-${o.d}'),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(templateId),
        version: 1,
        contentHash: 'sha256:$templateId',
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

({String d, int ru, int h, Face face, bool locked}) _at(
  String d,
  int ru,
  int h, {
  Face face = Face.front,
  bool locked = false,
}) => (d: d, ru: ru, h: h, face: face, locked: locked);

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

    test('a device too tall to clear an anchor stays exactly where it is',
        () {
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

      expect(_targets(plan), {'TALL': 4}, reason: 'TALL must move UP to '
          'the lowest run that clears the anchor, not sit on it');
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
    test('plans ONE face and ignores occupants on the other', () {
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
      expect({
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      }, {'A': 1, 'B': 2, 'C': 4});

      for (var i = cmds.length - 1; i >= 0; i--) {
        cmds[i].revert(doc);
      }
      expect({
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      }, before);
    });

    test('an empty plan emits no commands — "nothing to do" stays nothing',
        () {
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
      expect(occ.single.deviceH, 4, reason: 'clipping to the rack extent '
          'here would hide exactly the case the shrink planner exists for');
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

    test('Compact Down packs AROUND an unmodelled device, never through it',
        () {
      final doc = _doc(12, [_at('A', 8, 2)]);
      addOrphan(doc, 'ORPHAN', 2);

      final plan = _plan(doc, CompactDirection.down);

      expect(
        _targets(plan),
        {'A': 3},
        reason: 'U1-U2 is the lowest free run only if U2 is empty, and it '
            'is not — ORPHAN is standing on it',
      );
    });

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

    test('an unmodelled device on the OTHER face anchors nothing', () {
      final doc = _doc(12, [_at('A', 8, 2)]);
      addOrphan(doc, 'ORPHAN', 2, face: Face.rear);

      final plan = _plan(doc, CompactDirection.down);

      expect(_targets(plan), {'A': 1});
    });
  });
}
