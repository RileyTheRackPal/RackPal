// docs/04-rack-editor.md §4.1 — the shrink displacement planner, against
// the section's own six numbered rules. Rule 3 ("DELETION IS NOT OFFERED")
// is asserted structurally rather than by inspection: no code path in this
// planner removes a device, and the purity group proves the document is
// untouched by planning.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _rackId = Uuid('rack-shrink');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

TemplateSnapshot _template(String id, int h) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'sha256:$id',
  capturedAt: DateTime.utc(2026),
  body: TemplateBody(
    manufacturer: 'Generic',
    model: id,
    displayName: id,
    frontU: h,
    rearU: h,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
  ),
);

typedef _Occ = ({String d, int ru, int h, Face face, bool locked});

_Occ _at(
  String d,
  int ru,
  int h, {
  Face face = Face.front,
  bool locked = false,
}) => (d: d, ru: ru, h: h, face: face, locked: locked);

RackDocument _doc(int heightU, List<_Occ> occupants) {
  final doc = RackDocument(
    id: const Uuid('doc-shrink'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Shrink Rack',
    designator: 'RK-1',
    heightU: heightU,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  for (final o in occupants) {
    final tid = 'tpl.h${o.h}';
    doc.templates['$tid@1'] = _template(tid, o.h);
    doc.devices[Uuid('dev-${o.d}')] = DeviceInstance(
      id: Uuid('dev-${o.d}'),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(tid),
        version: 1,
        contentHash: 'sha256:$tid',
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

Set<String> _names(List<DoomedOccupant> d) => {for (final o in d) o.designator};
Map<String, int> _targets(List<CompactionMove> m) => {
  for (final x in m) x.designator: x.toRuIndex,
};

/// Adds a device the rail occupancy scan CANNOT model, to prove the shrink
/// planner still names it. See [DoomedKind].
///
/// The three producible flavours, all reachable by loading a file and none
/// by in-app authoring today (there is no 0U placement UI and
/// `buildPlaceFromCatalogCommand` refuses a missing template) — which is
/// exactly why they need a test rather than a comment saying they cannot
/// happen.
void _addZeroU(
  RackDocument doc,
  String designator, {
  required String channelId,
}) {
  doc.devices[Uuid('dev-$designator')] = DeviceInstance(
    id: Uuid('dev-$designator'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.pdu0u'),
      version: 1,
      contentHash: 'sha256:tpl.pdu0u',
    ),
    designator: designator,
    name: 'Device $designator',
    placement: ZeroUPlacement(
      rackId: _rackId,
      channelId: channelId,
      offsetFromChannelStart: Len.zero,
      orientation: ZeroUOrientation.vertical,
    ),
    meta: _meta(),
  );
}

void _addChannel(
  RackDocument doc, {
  required String id,
  required int startU,
  required int endU,
  ZeroUChannelSide side = ZeroUChannelSide.rearLeft,
}) {
  doc.racks[_rackId]!.zeroUChannels.add(
    ZeroUChannel(id: id, side: side, startU: startU, endU: endU),
  );
}

/// A rail-placed device whose `templates[...]` snapshot is simply absent —
/// `railOccupantsOnFace` skips it, `scene_builder` declines to draw it, and
/// before this was fixed the shrink planner never saw it either.
void _addDanglingTemplate(
  RackDocument doc,
  String designator, {
  required int ru,
  Face face = Face.front,
}) {
  doc.devices[Uuid('dev-$designator')] = DeviceInstance(
    id: Uuid('dev-$designator'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.missing'),
      version: 7,
      contentHash: 'sha256:tpl.missing',
    ),
    designator: designator,
    name: 'Device $designator',
    placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: face),
    meta: _meta(),
  );
}

/// A device rail-placed on a face its template gives ZERO height on — the
/// other half of what `railOccupantsOnFace` silently drops.
void _addZeroHeightOnFace(
  RackDocument doc,
  String designator, {
  required int ru,
  required Face face,
}) {
  const tid = 'tpl.frontonly';
  doc.templates['$tid@1'] = TemplateSnapshot(
    templateId: const TemplateId(tid),
    version: 1,
    contentHash: 'sha256:$tid',
    capturedAt: DateTime.utc(2026),
    body: TemplateBody(
      manufacturer: 'Generic',
      model: tid,
      displayName: tid,
      frontU: 2,
      side: OccupancySide.front,
      mountMethod: MountMethod.rackEars,
    ),
  );
  doc.devices[Uuid('dev-$designator')] = DeviceInstance(
    id: Uuid('dev-$designator'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId(tid),
      version: 1,
      contentHash: 'sha256:$tid',
    ),
    designator: designator,
    name: 'Device $designator',
    placement: RailPlacement(rackId: _rackId, ruIndex: ru, face: face),
    meta: _meta(),
  );
}

void main() {
  group('no casualties — the height change needs no modal', () {
    test('growing loses nobody and displaces nobody', () {
      final doc = _doc(12, [_at('A', 10, 2)]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 24);

      expect(plan.isShrink, isFalse);
      expect(plan.hasCasualties, isFalse);
      expect(plan.doomed, isEmpty);
      expect(plan.shiftMoves, isEmpty);
      expect(plan.rescue, isNull);
      expect(plan.removedU, -12);
    });

    test('shrinking above the highest occupant loses nobody', () {
      final doc = _doc(24, [_at('A', 1, 2), _at('B', 5, 1)]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(plan.hasCasualties, isFalse);
      expect(plan.smallestFittingHeightU, 5);
    });

    test('an empty rack can shrink all the way to 1U', () {
      final doc = _doc(24, []);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 1);

      expect(plan.hasCasualties, isFalse);
      expect(plan.smallestFittingHeightU, 1);
    });
  });

  group('Trim from Top — the default', () {
    test('names every occupant whose top U exceeds the new height', () {
      final doc = _doc(24, [
        _at('LOW', 2, 1),
        _at('MID', 11, 2), // U11-U12 — survives a shrink to 12
        _at('HIGH', 18, 1),
        _at('STRADDLE', 12, 2), // U12-U13 — top exceeds 12, dies
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(_names(plan.doomed), {'HIGH', 'STRADDLE'});
    });

    test('reports each casualty with its designator, description, U range '
        'and link count (rule 4)', () {
      final doc = _doc(24, [_at('HIGH', 20, 2)]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);
      final casualty = plan.doomed.single;

      expect(casualty.designator, 'HIGH');
      expect(casualty.name, 'Device HIGH');
      expect(casualty.ruIndex, 20);
      expect(casualty.topRu, 21);
      expect(casualty.deviceH, 2);
      expect(casualty.face, Face.front);
      expect(casualty.linkCount, 0, reason: 'a TRUE zero — no links exist '
          'in this document — not a stub or an unknown');
    });

    test('renumbers nobody: a top trim produces no shift moves', () {
      final doc = _doc(24, [_at('LOW', 2, 1), _at('HIGH', 20, 1)]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(plan.shiftMoves, isEmpty);
    });

    test('option 3 is the highest occupied U', () {
      final doc = _doc(24, [_at('LOW', 2, 1), _at('HIGH', 18, 3)]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 4);

      expect(plan.smallestFittingHeightU, 20); // U18-U20
    });

    test('casualties are collected across BOTH faces', () {
      final doc = _doc(24, [
        _at('FRONT', 20, 1),
        _at('REAR', 22, 1, face: Face.rear),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(_names(plan.doomed), {'FRONT', 'REAR'});
      expect(
        plan.doomed.map((d) => d.face).toSet(),
        {Face.front, Face.rear},
      );
    });
  });

  group('Trim from Bottom (rule 5) — a DIFFERENT casualty set', () {
    test('shifts every surviving occupant down by the removed count', () {
      final doc = _doc(24, [_at('A', 10, 1), _at('B', 20, 2)]);

      final plan = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 20,
        trimFrom: TrimFrom.bottom,
      );

      expect(plan.removedU, 4);
      expect(plan.hasCasualties, isFalse);
      expect(_targets(plan.shiftMoves), {'A': 6, 'B': 16});
    });

    test('kills the BOTTOM occupants, not the top ones — the opposite set '
        'from a top trim of the same height', () {
      final doc = _doc(24, [_at('BOTTOM', 2, 1), _at('TOP', 22, 1)]);

      final top = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);
      final bottom = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 12,
        trimFrom: TrimFrom.bottom,
      );

      expect(_names(top.doomed), {'TOP'});
      expect(_names(bottom.doomed), {'BOTTOM'});
    });

    test('an occupant straddling the new floor dies', () {
      // Removing 12U shifts everything down by 12. A device at U12 lands
      // at U0 — below the floor — so it dies; U13 lands at U1 and lives.
      final doc = _doc(24, [_at('AT12', 12, 1), _at('AT13', 13, 1)]);

      final plan = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 12,
        trimFrom: TrimFrom.bottom,
      );

      expect(_names(plan.doomed), {'AT12'});
      expect(_targets(plan.shiftMoves), {'AT13': 1});
    });

    test('option 3 mirrors: the floor may rise only to just below the '
        'lowest occupant', () {
      final doc = _doc(24, [_at('LOW', 5, 1), _at('HIGH', 20, 1)]);

      final plan = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 4,
        trimFrom: TrimFrom.bottom,
      );

      // Lowest occupant at U5 -> at most 4U may come off the bottom.
      expect(plan.smallestFittingHeightU, 20);
    });
  });

  group('option 1 — compact first, then shrink', () {
    test('FULL success: every casualty is rescued and the requested '
        'height is reached (rule 2 preselection case)', () {
      // Three 1U devices spread across a 24U rack, target 12U.
      final doc = _doc(24, [
        _at('A', 4, 1),
        _at('B', 14, 1),
        _at('C', 20, 1),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);
      final rescue = plan.rescue!;

      expect(_names(plan.doomed), {'B', 'C'});
      expect(rescue.isFull, isTrue);
      expect(rescue.stillDoomed, isEmpty);
      expect(_names(rescue.rescued), {'B', 'C'});
      expect(rescue.achievableHeightU, 12);
      expect(_targets(rescue.moves), {'A': 1, 'B': 2, 'C': 3});
    });

    test('rescue is NULL when compaction saves nobody (rule 1: the option '
        'appears only when compaction actually helps)', () {
      // Already packed at the bottom; the casualty is a device taller than
      // the whole target height, so no amount of compacting rescues it.
      final doc = _doc(24, [_at('A', 1, 2), _at('TALL', 3, 20)]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(plan.hasCasualties, isTrue);
      expect(plan.rescue, isNull);
    });

    test('PARTIAL success: names who fits, who does not, and how far the '
        'rack can honestly go', () {
      // A(1U)@4, B(1U)@14, TALL(6U)@18-23. Target 8U.
      // Compacting down: A->1, B->2, TALL->3-8. All three actually fit!
      // So make TALL taller than the target can hold after compaction.
      final doc = _doc(24, [
        _at('A', 4, 1),
        _at('B', 14, 1),
        _at('TALL', 18, 6),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 5);
      final rescue = plan.rescue!;

      expect(_names(plan.doomed), {'B', 'TALL'});
      // Compacted: A@1, B@2, TALL@3-8. B now fits under 5U; TALL does not.
      expect(_names(rescue.rescued), {'B'});
      expect(_names(rescue.stillDoomed), {'TALL'});
      expect(rescue.isFull, isFalse);
      // Option 1 composes with option 3: 8U is the smallest the compacted
      // layout permits, and NOTHING is displaced out of the rack.
      expect(rescue.achievableHeightU, 8);
      expect(_targets(rescue.moves), {'A': 1, 'B': 2, 'TALL': 3});
    });

    test('a partial rescue is still LOSSLESS: every occupant fits inside '
        'achievableHeightU', () {
      final doc = _doc(24, [
        _at('A', 4, 1),
        _at('B', 14, 1),
        _at('TALL', 18, 6),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 5);
      final rescue = plan.rescue!;
      final finalRu = <String, int>{
        'A': 4,
        'B': 14,
        'TALL': 18,
        ..._targets(rescue.moves),
      };
      final heights = {'A': 1, 'B': 1, 'TALL': 6};

      for (final entry in finalRu.entries) {
        final top = entry.value + heights[entry.key]! - 1;
        expect(
          top <= rescue.achievableHeightU,
          isTrue,
          reason: '${entry.key} would end at U$top, above the '
              '${rescue.achievableHeightU}U the plan claims to reach — a '
              'device silently pushed out of the rack (rule 3)',
        );
        expect(entry.value >= 1, isTrue);
      }
    });

    test('respects locked anchors — a rescue never moves a locked '
        'occupant', () {
      final doc = _doc(24, [
        _at('ANCHOR', 6, 1, locked: true),
        _at('HIGH', 20, 1),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);
      final rescue = plan.rescue!;

      expect(
        rescue.moves.map((m) => m.designator),
        isNot(contains('ANCHOR')),
      );
      expect(_targets(rescue.moves), {'HIGH': 7});
    });

    test('unions BOTH faces — a shrink is physical, not per-elevation', () {
      final doc = _doc(24, [
        _at('F1', 4, 1),
        _at('F2', 20, 1),
        _at('R1', 6, 1, face: Face.rear),
        _at('R2', 22, 1, face: Face.rear),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);
      final rescue = plan.rescue!;

      expect(rescue.isFull, isTrue);
      expect(
        rescue.moves.map((m) => m.face).toSet(),
        {Face.front, Face.rear},
        reason: 'the rescue must plan both faces, not just the displayed '
            'one',
      );
      expect(_targets(rescue.moves), {'F1': 1, 'F2': 2, 'R1': 1, 'R2': 2});
    });

    test('compacts UP for a bottom trim, and the net move already includes '
        'the shift', () {
      final doc = _doc(24, [_at('A', 2, 1), _at('B', 10, 1)]);

      final plan = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 12,
        trimFrom: TrimFrom.bottom,
      );
      final rescue = plan.rescue!;

      // Compact up: B->24, A->23. Then 12U comes off the bottom: -12.
      expect(rescue.isFull, isTrue);
      expect(_targets(rescue.moves), {'B': 12, 'A': 11});
      expect(
        rescue.moves.map((m) => m.deviceId).toSet().length,
        rescue.moves.length,
        reason: 'one net move per device, not a compaction hop plus a '
            'shift hop',
      );
    });

    test('freedU is reported so the label can say "Removes NU of gaps"',
        () {
      final doc = _doc(24, [_at('A', 4, 1), _at('B', 20, 1)]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      // The top drops from U20 to U2 — eighteen U of contiguous space
      // handed back, spelled out rather than left as `greaterThan(0)` so
      // the assertion actually pins the arithmetic.
      expect(plan.rescue!.freedU, 18);
    });
  });

  // The number on §4.1's option-1 tile. `CompactionPlan.freedU` is a
  // CONTIGUOUS run at one end of ONE face, and contiguous runs do not sum:
  // folding the two faces together reports U the rack does not have.
  group('freedU is a rack-wide contiguous run, not a per-face sum', () {
    test('two faces each freeing 3U have together freed 3U, not 6U', () {
      // Front: A@1(2U), B@6(1U)  -> compacts to A@1-2, B@3. Top 6 -> 3.
      // Rear:  C@1(2U), D@6(1U)  -> identical. Top 6 -> 3.
      // Each face's own plan reports freedU 3. The rack gained 3.
      final doc = _doc(24, [
        _at('A', 1, 2),
        _at('B', 6, 1),
        _at('C', 1, 2, face: Face.rear),
        _at('D', 6, 1, face: Face.rear),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 4);
      final rescue = plan.rescue!;

      expect(
        rescue.freedU,
        3,
        reason: 'summing the faces would report 6U of gaps removed from a '
            'rack whose usable top only came down 3U',
      );
      expect(plan.smallestFittingHeightU, 6);
      expect(rescue.achievableHeightU, 4);
    });

    test('the shipped demo rack asked for 6U reports 4U, not 10U', () {
      // 12U: UPS-1@U1 2U, AMP-1@U4 2U, SW-1@U7 1U front; PP-1@U9 1U rear.
      // Front frees 7-5 = 2U; rear frees 9-1 = 8U; the sum is 10U of gaps
      // in a 12U rack. The rack's own top goes U9 -> U5.
      final doc = _doc(12, [
        _at('UPS-1', 1, 2),
        _at('AMP-1', 4, 2),
        _at('SW-1', 7, 1),
        _at('PP-1', 9, 1, face: Face.rear),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 6);
      final rescue = plan.rescue!;

      expect(rescue.freedU, 4);
      expect(plan.smallestFittingHeightU, 9);
      expect(rescue.achievableHeightU, 6);
      expect(rescue.isFull, isTrue);
    });

    test('one 1U device per face at U20 of a 24U rack frees 19U, not 38U',
        () {
      final doc = _doc(24, [
        _at('F', 20, 1),
        _at('R', 20, 1, face: Face.rear),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      // Both compact to U1: the rack top goes U20 -> U1.
      expect(plan.rescue!.freedU, 19);
    });

    test('a bottom trim mirrors: the run is the rise of the rack floor',
        () {
      // Compact UP in a 24U rack: A@2 -> U23, B@10 -> U24. The lowest
      // occupied U rises from 2 to 23, so 21U of floor comes free. The
      // per-face fold would be the same 21 here (one face), which is
      // exactly why the cross-face case above is the one that catches it.
      final doc = _doc(24, [_at('A', 2, 1), _at('B', 10, 1)]);

      final plan = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 12,
        trimFrom: TrimFrom.bottom,
      );

      expect(plan.rescue!.freedU, 21);
    });

    test('freedU, smallestFittingHeightU and achievableHeightU agree at '
        'every height, on both trims, across both faces', () {
      // The invariant, stated once: option 1 can only reach the requested
      // height, or the pre-compaction floor lowered by exactly the run
      // compaction freed. Any other pair of numbers means two of the three
      // figures on the same modal tile were computed by different code.
      final doc = _doc(24, [
        _at('A', 3, 1),
        _at('B', 9, 2),
        _at('C', 18, 1),
        _at('D', 5, 1, face: Face.rear),
        _at('E', 21, 2, face: Face.rear),
      ]);

      for (final trim in TrimFrom.values) {
        for (var h = 1; h <= 24; h++) {
          final plan = planRackShrink(
            doc: doc,
            rackId: _rackId,
            toHeightU: h,
            trimFrom: trim,
          );
          final rescue = plan.rescue;
          if (rescue == null) continue;
          final floorAfter = plan.smallestFittingHeightU - rescue.freedU;
          expect(
            rescue.achievableHeightU,
            h > floorAfter ? h : floorAfter,
            reason: 'h=$h trim=$trim: freedU=${rescue.freedU} against '
                'smallest=${plan.smallestFittingHeightU} implies a floor '
                'of $floorAfter, but the plan claims to reach '
                '${rescue.achievableHeightU}U',
          );
        }
      }
    });

    test('freedU never goes negative: the CROSS-FACE overlap document that '
        'really does drive the raw figure to -2', () {
      // THE FIXTURE IS THE WHOLE TEST, and the previous one was the wrong
      // shape. It was `A@U1 2U, B@U1 2U, C@U20 1U`, all on the FRONT face —
      // which never reaches the clamp at all: C's U20 top dominates the
      // pre-compaction floor at every height, so `preFloor - postFloor` is
      // a healthy +15 and `freedU: freed < 0 ? 0 : freed` in
      // rack_shrink.dart could be deleted outright with the whole core
      // suite green. The assertion held arithmetically, not because of the
      // thing it was defending.
      //
      // What it takes to actually push the raw figure negative is the case
      // rack_shrink.dart's own doc comment argues cannot happen — and the
      // argument is a SINGLE-FACE one, so the counterexample is
      // cross-face:
      //
      //   * FRONT: six 2U devices ALL claiming U1. Compaction re-packs the
      //     pile into U1–U12, so the front's highest occupied U goes 2 ->
      //     12. Nobody there is rescued; they are the ones pushed UP.
      //   * REAR: one 1U device at U10, which compaction drops to U1. THIS
      //     is the rescued occupant, and it is on the other face, so the
      //     doc comment's "the device it pushes past the old extremum
      //     thereby becomes the new extremum, so it is doomed both before
      //     and after" does not bind: the rescue and the pile-up are on
      //     different faces and are evaluated independently.
      //
      // preFloor is max(2 front, 10 rear) = 10; postFloor is max(12 front,
      // 1 rear) = 12; the raw `freed` is -2 at every height that yields a
      // rescue at all. "Removes -2U of gaps" is not a sentence a modal may
      // print, which is what the clamp is for.
      final doc = _doc(24, [
        for (final d in ['A', 'B', 'C', 'D', 'E', 'F']) _at(d, 1, 2),
        _at('R', 10, 1, face: Face.rear),
      ]);

      var reached = 0;
      for (var h = 1; h <= 24; h++) {
        final rescue = planRackShrink(
          doc: doc,
          rackId: _rackId,
          toHeightU: h,
        ).rescue;
        if (rescue == null) continue;
        reached++;
        expect(rescue.freedU, greaterThanOrEqualTo(0), reason: 'h=$h');
        // The clamp is doing real work here, not passing through: with it
        // removed the same heights report -2.
        expect(rescue.freedU, 0, reason: 'h=$h');
      }

      // Without this the fixture could drift back into "no rescue at any
      // height" and the loop above would assert nothing at all — exactly
      // the failure mode that made the predecessor toothless.
      expect(
        reached,
        greaterThan(0),
        reason: 'no height produced a rescue, so nothing above ran: this '
            'fixture no longer reaches the clamp it exists to defend',
      );
    });
  });

  // "Always name the casualties" is not "name the ones the occupancy scan
  // happens to see". `railOccupantsOnFace` skips 0U placements and devices
  // whose template snapshot does not resolve; a shrink planner that took
  // its casualty list from that scan alone would report `hasCasualties ==
  // false`, apply with NO modal, and leave the device outside the rack.
  group('occupants the rail scan cannot see are still named', () {
    test('a 0U device in a full-height channel dooms any top trim, and is '
        'named with its channel span', () {
      final doc = _doc(24, [_at('A', 2, 1)]);
      _addChannel(doc, id: 'ch-rear-l', startU: 1, endU: 24);
      _addZeroU(doc, 'PDU0U', channelId: 'ch-rear-l');

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(
        plan.hasCasualties,
        isTrue,
        reason: 'a false here is the whole bug: the screen applies the '
            'height with no modal at all',
      );
      expect(_names(plan.doomed), {'PDU0U'});
      final zero = plan.doomed.single;
      expect(zero.kind, DoomedKind.zeroU);
      expect(zero.ruIndex, 1);
      expect(zero.topRu, 24);
      expect(zero.face, Face.rear, reason: 'a rearLeft channel is rear');
      expect(plan.smallestFittingHeightU, 24);
      expect(plan.hasUnmodelledOccupants, isTrue);
    });

    test('a 0U device in a short channel survives a shrink that clears its '
        'channel', () {
      final doc = _doc(24, [_at('A', 2, 1)]);
      _addChannel(doc, id: 'ch', startU: 1, endU: 10);
      _addZeroU(doc, 'PDU0U', channelId: 'ch');

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(plan.hasCasualties, isFalse);
      expect(plan.smallestFittingHeightU, 10);
    });

    test('a 0U device dooms EVERY bottom trim: nothing in this system '
        'renumbers a ZeroUChannel', () {
      final doc = _doc(24, [_at('A', 20, 1)]);
      _addChannel(doc, id: 'ch', startU: 12, endU: 18);
      _addZeroU(doc, 'PDU0U', channelId: 'ch');

      final plan = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 23,
        trimFrom: TrimFrom.bottom,
      );

      expect(_names(plan.doomed), contains('PDU0U'));
      expect(
        plan.smallestFittingHeightU,
        24,
        reason: 'the only lossless bottom trim is no bottom trim',
      );
      expect(
        plan.shiftMoves.map((m) => m.designator),
        isNot(contains('PDU0U')),
      );
    });

    test('a 0U device is never rescued and never moved by compaction, and '
        'it pins how far option 1 can go', () {
      final doc = _doc(24, [_at('A', 4, 1), _at('B', 20, 1)]);
      _addChannel(doc, id: 'ch', startU: 1, endU: 18);
      _addZeroU(doc, 'PDU0U', channelId: 'ch');

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);
      final rescue = plan.rescue!;

      expect(_names(plan.doomed), {'B', 'PDU0U'});
      expect(_names(rescue.rescued), {'B'});
      expect(_names(rescue.stillDoomed), {'PDU0U'});
      expect(
        rescue.moves.map((m) => m.designator),
        isNot(contains('PDU0U')),
      );
      expect(
        rescue.achievableHeightU,
        18,
        reason: 'the channel top is immovable, so option 1 stops there — '
            'and stops LOSSLESSLY, which is the only way it may be offered',
      );
      expect(rescue.freedU, 2, reason: 'U20 -> U18, not the 19U the front '
          'face alone reclaimed');
    });

    test('a 0U device whose channelId resolves to nothing is treated as '
        'spanning the whole rack rather than guessed at', () {
      final doc = _doc(24, [_at('A', 2, 1)]);
      _addZeroU(doc, 'GHOST', channelId: 'ch-that-does-not-exist');

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 23);

      expect(_names(plan.doomed), {'GHOST'});
      expect(plan.doomed.single.topRu, 24);
      expect(plan.smallestFittingHeightU, 24);
    });

    test('a channel decoded with its ends inverted is read as the range it '
        'spans, not trusted to be well ordered', () {
      // json_codec's `_decodeRack` is explicitly the non-validating path
      // and ZeroUChannel.startU/endU are plain mutable ints behind it, so
      // "startU > endU" is a shape a file can hand us. Reading it verbatim
      // would report a 1U footprint at U18 for a channel that physically
      // runs U4-U18, and quietly under-name the casualty.
      final doc = _doc(24, [_at('A', 2, 1)]);
      _addChannel(doc, id: 'ch', startU: 18, endU: 4);
      _addZeroU(doc, 'PDU0U', channelId: 'ch');

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);
      final zero = plan.doomed.single;

      expect(zero.ruIndex, 4);
      expect(zero.deviceH, 15);
      expect(zero.topRu, 18);
    });

    test('a channel whose bottom is below U1 is floored at U1', () {
      final doc = _doc(24, [_at('A', 2, 1)]);
      _addChannel(doc, id: 'ch', startU: 0, endU: 20);
      _addZeroU(doc, 'PDU0U', channelId: 'ch');

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(plan.doomed.single.ruIndex, 1);
      expect(plan.doomed.single.topRu, 20);
      expect(plan.smallestFittingHeightU, 20);
    });

    test('a rail device with a dangling template reference is named, not '
        'skipped', () {
      final doc = _doc(24, [_at('A', 2, 1)]);
      _addDanglingTemplate(doc, 'ORPHAN', ru: 20);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(plan.hasCasualties, isTrue);
      expect(_names(plan.doomed), {'ORPHAN'});
      final orphan = plan.doomed.single;
      expect(orphan.kind, DoomedKind.unmodelledRail);
      expect(orphan.ruIndex, 20);
      expect(
        orphan.deviceH,
        1,
        reason: 'nothing in the document says how tall it is, so claim the '
            'least it can possibly occupy',
      );
      expect(plan.smallestFittingHeightU, 20);
      expect(plan.hasUnmodelledOccupants, isTrue);
    });

    test('a device rail-placed on a face its template gives zero height on '
        'is named too', () {
      final doc = _doc(24, [_at('A', 2, 1)]);
      _addZeroHeightOnFace(doc, 'SIDEWAYS', ru: 22, face: Face.rear);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(_names(plan.doomed), {'SIDEWAYS'});
      expect(plan.doomed.single.kind, DoomedKind.unmodelledRail);
      expect(plan.doomed.single.face, Face.rear);
    });

    test('an unmodelled rail device still renumbers under a bottom trim — '
        'MoveDeviceCommand does not need a template', () {
      final doc = _doc(24, [_at('A', 10, 1)]);
      _addDanglingTemplate(doc, 'ORPHAN', ru: 14);

      final plan = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 20,
        trimFrom: TrimFrom.bottom,
      );

      expect(plan.hasCasualties, isFalse);
      expect(_targets(plan.shiftMoves), {'A': 6, 'ORPHAN': 10});
    });

    test("a rail device pointing at a DIFFERENT rack is not this rack's "
        'problem', () {
      final doc = _doc(24, [_at('A', 2, 1)]);
      doc.devices[const Uuid('dev-ELSEWHERE')] = DeviceInstance(
        id: const Uuid('dev-ELSEWHERE'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.missing'),
          version: 7,
          contentHash: 'sha256:tpl.missing',
        ),
        designator: 'ELSEWHERE',
        name: 'Device ELSEWHERE',
        placement: const RailPlacement(
          rackId: Uuid('some-other-rack'),
          ruIndex: 40,
          face: Face.front,
        ),
        meta: _meta(),
      );

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(plan.hasCasualties, isFalse);
      expect(plan.hasUnmodelledOccupants, isFalse);
      expect(plan.smallestFittingHeightU, 2);
    });

    test('off-rack, staged and shelf-hosted devices are not rack occupants',
        () {
      // A shelf child holds no rack U of its own: it rides its host, and
      // the host IS enumerated. There is no invisible casualty here, so
      // naming the child would be inventing one.
      final doc = _doc(24, [_at('HOST', 1, 1)]);
      for (final (name, placement) in <(String, Placement)>[
        ('OFF', const OffRackPlacement()),
        ('STAGED', const StagedPlacement()),
        (
          'ONSHELF',
          const ShelfPlacement(
            hostDeviceId: Uuid('dev-HOST'),
            order: FracIndex('a0'),
          ),
        ),
      ]) {
        doc.devices[Uuid('dev-$name')] = DeviceInstance(
          id: Uuid('dev-$name'),
          kind: DeviceKind.rackDevice,
          templateRef: const TemplateRef(
            templateId: TemplateId('tpl.missing'),
            version: 7,
            contentHash: 'sha256:tpl.missing',
          ),
          designator: name,
          name: 'Device $name',
          placement: placement,
          meta: _meta(),
        );
      }

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 1);

      expect(plan.hasCasualties, isFalse);
      expect(plan.hasUnmodelledOccupants, isFalse);
    });

    test('option 3 stays lossless with unmodelled occupants present: no '
        'height at or above it reports a casualty', () {
      final doc = _doc(24, [_at('A', 3, 1), _at('B', 9, 2)]);
      _addChannel(doc, id: 'ch', startU: 4, endU: 14);
      _addZeroU(doc, 'PDU0U', channelId: 'ch');
      _addDanglingTemplate(doc, 'ORPHAN', ru: 17);

      for (final trim in TrimFrom.values) {
        for (var h = 1; h <= 24; h++) {
          final plan = planRackShrink(
            doc: doc,
            rackId: _rackId,
            toHeightU: h,
            trimFrom: trim,
          );
          if (h >= plan.smallestFittingHeightU) {
            expect(
              plan.hasCasualties,
              isFalse,
              reason: 'h=$h trim=$trim sits at or above the smallest '
                  'fitting height ${plan.smallestFittingHeightU} yet names '
                  '${_names(plan.doomed)}',
            );
          }
          final rescue = plan.rescue;
          if (rescue != null) {
            expect(rescue.achievableHeightU, greaterThanOrEqualTo(h));
            expect(rescue.achievableHeightU, lessThan(plan.fromHeightU));
          }
        }
      }
    });
  });

  group('rule 1 — option 1 appears only when compaction actually helps', () {
    test('a rescue that cannot lower the rack at all is no rescue', () {
      // ANCHOR is locked at the very top, so compaction can never bring
      // the rack's usable top below U24. "Compact first, then shrink to
      // 24U" on a 24U rack is an option that does nothing while claiming
      // to, which is what rule 1 exists to suppress.
      final doc = _doc(24, [
        _at('ANCHOR', 24, 1, locked: true),
        _at('MOVER', 20, 1),
      ]);

      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);

      expect(_names(plan.doomed), {'ANCHOR', 'MOVER'});
      expect(plan.rescue, isNull);
      expect(plan.smallestFittingHeightU, 24);
    });
  });

  group('purity — rule 3 holds structurally', () {
    test('planning removes no device and mutates no placement or height',
        () {
      final doc = _doc(24, [
        _at('A', 4, 1),
        _at('B', 14, 1),
        _at('C', 20, 2),
      ]);
      final before = {
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      };

      for (final trim in TrimFrom.values) {
        for (var h = 1; h <= 24; h++) {
          planRackShrink(
            doc: doc,
            rackId: _rackId,
            toHeightU: h,
            trimFrom: trim,
          );
        }
      }

      expect(doc.devices.length, 3, reason: 'DELETION IS NOT OFFERED');
      expect({
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      }, before);
      expect(doc.racks[_rackId]!.heightU, 24);
    });

    test('every reachable height produces a self-consistent plan', () {
      final doc = _doc(24, [
        _at('A', 4, 1),
        _at('B', 14, 1),
        _at('C', 20, 2),
      ]);

      for (final trim in TrimFrom.values) {
        for (var h = 1; h <= 24; h++) {
          final plan = planRackShrink(
            doc: doc,
            rackId: _rackId,
            toHeightU: h,
            trimFrom: trim,
          );
          if (h >= plan.smallestFittingHeightU) {
            expect(
              plan.hasCasualties,
              isFalse,
              reason: 'h=$h trim=$trim is at or above the smallest '
                  'fitting height ${plan.smallestFittingHeightU} yet '
                  'reports casualties',
            );
          }
          final rescue = plan.rescue;
          if (rescue != null) {
            expect(rescue.rescued, isNotEmpty, reason: 'a rescue that '
                'rescues nobody must be null (rule 1), h=$h trim=$trim');
            expect(
              rescue.achievableHeightU,
              greaterThanOrEqualTo(h),
              reason: 'a rescue can never claim to reach BELOW the '
                  'requested height, h=$h trim=$trim',
            );
          }
        }
      }
    });
  });

  group('shrinkDisplacementCommands', () {
    test('realises a rescue and reverts cleanly in reverse order', () {
      final doc = _doc(24, [
        _at('A', 4, 1),
        _at('B', 14, 1),
        _at('C', 20, 1),
      ]);
      final plan = planRackShrink(doc: doc, rackId: _rackId, toHeightU: 12);
      final cmds = shrinkDisplacementCommands(
        plan.rescue!.moves,
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
      }, {'A': 1, 'B': 2, 'C': 3});

      for (var i = cmds.length - 1; i >= 0; i--) {
        cmds[i].revert(doc);
      }
      expect({
        for (final d in doc.devices.values)
          d.designator: (d.placement as RailPlacement).ruIndex,
      }, before);
    });

    test('a bottom trim with no casualties still emits its shift moves', () {
      final doc = _doc(24, [_at('A', 10, 1)]);
      final plan = planRackShrink(
        doc: doc,
        rackId: _rackId,
        toHeightU: 20,
        trimFrom: TrimFrom.bottom,
      );

      final cmds = shrinkDisplacementCommands(
        plan.shiftMoves,
        now: DateTime.utc(2026),
        actor: 't',
      );

      expect(cmds, hasLength(1));
      expect(cmds.single.toRuIndex, 6);
    });
  });

  test('an unknown rack id is a caller bug, not a silent empty plan', () {
    final doc = _doc(12, []);

    expect(
      () => planRackShrink(
        doc: doc,
        rackId: const Uuid('nope'),
        toHeightU: 6,
      ),
      throwsArgumentError,
    );
  });
}
