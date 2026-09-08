// PLAN-E/6: CR-102's band as geometry (DR-139 §11.138).
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY FIXTURE IS BUILT SO WINDOW AND CROSS DISAGREE
// ═══════════════════════════════════════════════════════════════════════
// The chapter's own brief says why: "assert on a document where 'fully
// contained' and 'intersecting' give different answers, or the
// window/cross rule is untested". A band that swallows both boxes whole
// passes under either rule and proves nothing about the convention.
//
// So the standing fixture is two boxes and a band that CONTAINS one and
// CLIPS the other. Window must answer one, cross must answer two, and a
// single implementation that ignored the direction cannot do both.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// `A` at 0..10, `B` at 20..40. A band across 0..25 contains A and clips B.
final _regions = <HitRegion>[
  const HitRegion('A', DBox.fromLtwh(0, 0, 10, 10)),
  const HitRegion('B', DBox.fromLtwh(20, 0, 20, 10)),
];

List<String> _sweep(DPt from, DPt to) => marqueeSelectionIn(_regions, from, to);

void main() {
  group('the mode comes from the drag direction', () {
    test('left to right is WINDOW, right to left is CROSS', () {
      expect(
        marqueeModeFor(const DPt(0, 0), const DPt(10, 10)),
        MarqueeMode.window,
      );
      expect(
        marqueeModeFor(const DPt(10, 0), const DPt(0, 10)),
        MarqueeMode.cross,
      );
    });

    test('reads X ONLY, so dragging up or down does not change it', () {
      // Every CAD package this convention comes from ignores Y. A rule
      // that read the diagonal would make an up-and-right drag a cross,
      // which is the same gesture a user means as down-and-right.
      expect(
        marqueeModeFor(const DPt(0, 100), const DPt(10, 0)),
        MarqueeMode.window,
      );
      expect(
        marqueeModeFor(const DPt(10, 0), const DPt(0, 100)),
        MarqueeMode.cross,
      );
    });

    test('a zero-width drag is a WINDOW, which is the stricter one', () {
      expect(
        marqueeModeFor(const DPt(5, 0), const DPt(5, 40)),
        MarqueeMode.window,
      );
    });
  });

  group('the two conventions, on a fixture where they DISAGREE', () {
    test('WINDOW takes only what it fully contains', () {
      // 0..25 swallows A (0..10) and clips B (20..40).
      expect(_sweep(const DPt(-1, -1), const DPt(25, 11)), ['A']);
    });

    test('CROSS takes what it merely touches', () {
      // The same band, dragged the other way.
      expect(_sweep(const DPt(25, -1), const DPt(-1, 11)), ['A', 'B']);
    });

    test('A BAND CATCHING TWO PRODUCES A SELECTION OF TWO', () {
      // The chapter's brief names this one in terms, and this repo's own
      // history says why to write it this way round: the status bar's
      // pathway count read 0 the keystroke after somebody made a pathway,
      // and its own test pinned the wrong number on a two-pathway
      // document. Two boxes in, two ids out.
      final all = _sweep(const DPt(-1, -1), const DPt(41, 11));
      expect(all, hasLength(2));
      expect(all, ['A', 'B']);
    });

    test('a band touching nothing selects nothing', () {
      expect(_sweep(const DPt(100, 100), const DPt(200, 200)), isEmpty);
    });
  });

  group('a part is not a selectable thing', () {
    test('A PIN CLIPPED BY A WINDOW DOES NOT SELECT ITS DEVICE', () {
      // The finding this file exists to pin. A schematic symbol emits one
      // region per port carrying the SYMBOL's entityId plus a body region
      // with no partKey, so a band tested against every region selects a
      // whole device because it caught one pin, in the mode that means
      // "fully contained".
      final withPins = <HitRegion>[
        // The body is far to the right and nowhere near contained.
        const HitRegion('MTX-1', DBox.fromLtwh(100, 0, 60, 40)),
        // One pin on its left edge, inside the band below.
        const HitRegion(
          'MTX-1',
          DBox.fromLtwh(98, 10, 4, 4),
          partKey: 'J07',
        ),
      ];

      expect(
        marqueeSelectionIn(withPins, const DPt(0, 0), const DPt(105, 50)),
        isEmpty,
        reason: 'the band contains a pin, not the device',
      );
    });

    test('and CROSS is not a way round it either', () {
      final withPins = <HitRegion>[
        const HitRegion('MTX-1', DBox.fromLtwh(100, 0, 60, 40)),
        const HitRegion(
          'MTX-1',
          DBox.fromLtwh(98, 10, 4, 4),
          partKey: 'J07',
        ),
      ];

      // Dragged right to left across the pin only. The BODY starts at 100
      // and the band stops at 99, so intersecting still catches nothing.
      expect(
        marqueeSelectionIn(withPins, const DPt(99, 50), const DPt(0, 0)),
        isEmpty,
      );
    });

    test('the body being caught DOES select it, so the filter is not a '
        'blanket refusal', () {
      // The other half, and the reason this is a filter rather than a
      // rule that schematic symbols are unselectable.
      final withPins = <HitRegion>[
        const HitRegion('MTX-1', DBox.fromLtwh(100, 0, 60, 40)),
        const HitRegion(
          'MTX-1',
          DBox.fromLtwh(98, 10, 4, 4),
          partKey: 'J07',
        ),
      ];

      expect(
        marqueeSelectionIn(withPins, const DPt(90, -5), const DPt(170, 50)),
        ['MTX-1'],
      );
    });
  });

  group('the result is a total order', () {
    test('ids are deduped and sorted, whatever order the scene lists', () {
      // `Set` iteration is insertion order, which follows the scene's,
      // which follows a `Map` whose order differs between a freshly built
      // document and the same one reopened from disk.
      final forward = <HitRegion>[
        const HitRegion('b', DBox.fromLtwh(0, 0, 5, 5)),
        const HitRegion('a', DBox.fromLtwh(6, 0, 5, 5)),
      ];
      final backward = forward.reversed.toList();

      expect(
        marqueeSelectionIn(forward, const DPt(-1, -1), const DPt(20, 20)),
        ['a', 'b'],
      );
      expect(
        marqueeSelectionIn(backward, const DPt(-1, -1), const DPt(20, 20)),
        ['a', 'b'],
      );
    });

    test('one entity in several regions appears once', () {
      final twice = <HitRegion>[
        const HitRegion('a', DBox.fromLtwh(0, 0, 5, 5)),
        const HitRegion('a', DBox.fromLtwh(6, 0, 5, 5)),
      ];

      expect(
        marqueeSelectionIn(twice, const DPt(-1, -1), const DPt(20, 20)),
        ['a'],
      );
    });
  });
}
