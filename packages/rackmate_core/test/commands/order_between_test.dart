// `orderBetween` and `ordersBetween` (M4-F4 `#211`, CR-027, DR-064).
//
// WHAT THESE PROTECT. `nextOrder` declined to write a midpoint generator
// for four milestones on the grounds that it would be "untested
// generality". These are the tests that claim was waiting for, and the
// property test is the one that matters: a reorder writes ONE row, so the
// only thing standing between the grid and a scrambled template is that
// the minted index really does sort where it was asked to.
//
// THE ASSERTIONS ARE ABOUT ORDER, NOT ABOUT SPELLING. Two cases pin an
// exact string, and both do it for a reason stated at the case: the seed,
// because other code reads `a0` as the first index, and the alphabet walk,
// because the whole point of that branch is that it does NOT grow a
// character per call. Everything else asks where the value sorts, which is
// the only thing any consumer of `order` ever asks.
import 'dart:math';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// `before < value < after`, under the raw string compare every reader of
/// `order` uses (`portsInDeclaredOrder`, `SheetSet.forRacks`, the lot).
void _sortsBetween(FracIndex? before, FracIndex? value, FracIndex? after) {
  expect(value, isNotNull, reason: 'no index was minted at all');
  if (before != null) {
    expect(
      value!.v.compareTo(before.v),
      greaterThan(0),
      reason: '${value.v} does not sort after ${before.v}',
    );
  }
  if (after != null) {
    expect(
      value!.v.compareTo(after.v),
      lessThan(0),
      reason: '${value.v} does not sort before ${after.v}',
    );
  }
}

void main() {
  group('orderBetween', () {
    test('with no neighbours at all it seeds, and the seed is the one '
        'every other allocator already mints', () {
      // PINNED. `nextOrder([])` answers `a0` and this has to agree with
      // it, or the first port of a template and the first port inserted
      // into an empty one would disagree about where the list starts.
      expect(orderBetween(null, null)!.v, 'a0');
      expect(orderBetween(null, null)!.v, nextOrder(const <FracIndex>[]).v);
    });

    test('with nothing below it appends, exactly as nextOrder does', () {
      expect(
        orderBetween(const FracIndex('a3'), null)!.v,
        nextOrder(const [FracIndex('a3')]).v,
      );
    });

    test('with nothing above it mints something that sorts first', () {
      const after = FracIndex('a0');
      _sortsBetween(null, orderBetween(null, after), after);
    });

    test('two indices with room between them get a value at the midpoint '
        'and no extra length', () {
      const before = FracIndex('a1');
      const after = FracIndex('a9');
      final mid = orderBetween(before, after);
      _sortsBetween(before, mid, after);
      expect(
        mid!.v.length,
        before.v.length,
        reason: 'a span with room should not need a longer index',
      );
    });

    test('two indices with no room at the character where they part still '
        'get one, by growing', () {
      const before = FracIndex('a0003');
      const after = FracIndex('a0004');
      _sortsBetween(before, orderBetween(before, after), after);
    });

    test('a run of insertions into the same tight span walks the alphabet '
        'instead of growing a character each time', () {
      // THIS IS THE BRANCH'S WHOLE PURPOSE. Chaining the naive answer
      // (`before` plus a middle character) gives `a0003V`, `a0003VV`,
      // `a0003VVV`; bumping the tail through `nextOrder` gives `a0003V`,
      // `a0003W`, `a0003X`. Both are correct and one of them is a file
      // that grows a byte per drag.
      const after = FracIndex('a0004');
      var cursor = const FracIndex('a0003');
      final minted = <FracIndex>[];
      for (var n = 0; n < 8; n++) {
        cursor = orderBetween(cursor, after)!;
        minted.add(cursor);
      }
      expect(
        minted.map((i) => i.v.length).toSet(),
        {6},
        reason:
            'eight insertions into one span produced ${minted.map(
              (i) => i.v,
            ).toList()}',
      );
      expect(minted.last.v.compareTo(after.v), lessThan(0));
    });

    test('the one unanswerable pair is refused rather than approximated', () {
      // `az` and `az0`: an index between them would have to be `az` plus
      // something below the lowest character in the alphabet. DR-064 stops
      // `nextOrder` from ever MINTING this pair; a hand-edited file can
      // still hold one, and null is what the grid turns into a sentence.
      expect(orderBetween(const FracIndex('az'), const FracIndex('az0')), null);
    });

    test('a prefix pair with two low characters after it is answerable, so '
        'the refusal is narrow rather than a whole class', () {
      const before = FracIndex('az');
      const after = FracIndex('az00');
      _sortsBetween(before, orderBetween(before, after), after);
    });

    test('an out-of-order pair is refused, not silently swapped', () {
      expect(orderBetween(const FracIndex('a5'), const FracIndex('a1')), null);
      expect(orderBetween(const FracIndex('a5'), const FracIndex('a5')), null);
    });

    test('a hand-edited index whose characters are not in the alphabet '
        'still gets an answer when one exists', () {
      // `~` is not in the alphabet and sorts above every character that
      // is. The pair still parts at position 1, so growing the tail is
      // still in range, and refusing here would refuse a file the codec
      // accepts.
      const before = FracIndex('a~');
      const after = FracIndex('b0');
      _sortsBetween(before, orderBetween(before, after), after);
    });
  });

  group('ordersBetween', () {
    test('mints a strictly increasing block, all of it inside the span', () {
      const before = FracIndex('a1');
      const after = FracIndex('a2');
      final block = ordersBetween(before, after, 8)!;
      expect(block, hasLength(8));
      _sortsBetween(before, block.first, after);
      _sortsBetween(before, block.last, after);
      for (var i = 1; i < block.length; i++) {
        expect(block[i].v.compareTo(block[i - 1].v), greaterThan(0));
      }
    });

    test('refuses the whole block when one member has nowhere to go', () {
      expect(
        ordersBetween(const FracIndex('az'), const FracIndex('az0'), 3),
        null,
      );
    });

    test('a block of none is a block, not a refusal', () {
      expect(
        ordersBetween(const FracIndex('a1'), const FracIndex('a2'), 0),
        isEmpty,
      );
    });
  });

  group('nextOrder leaves room behind it (DR-064)', () {
    test('every adjacent pair in a long allocation chain can still be '
        'split', () {
      // THE ARTIFACT OF DR-064, and the reason the extension character
      // changed. 200 allocations crosses the alphabet's end three times,
      // which is where the old `'0'` extension planted a pair that could
      // never be reordered. A 64-port patchbay reaches the first one.
      final chain = <FracIndex>[];
      for (var n = 0; n < 200; n++) {
        chain.add(nextOrder(chain));
      }
      for (var i = 1; i < chain.length; i++) {
        expect(
          chain[i].v.compareTo(chain[i - 1].v),
          greaterThan(0),
          reason: 'the chain itself is out of order at $i',
        );
        _sortsBetween(
          chain[i - 1],
          orderBetween(chain[i - 1], chain[i]),
          chain[i],
        );
      }
    });
  });

  group('the ordering survives repeated reordering', () {
    test('1000 random insertions keep the list strictly sorted', () {
      // A REORDER IS ONE FIELD WRITE, so nothing renumbers and nothing
      // re-sorts: the list is correct only if every minted index really
      // does land where it was asked to. Seeded, because a property test
      // that cannot be replayed is a bug report with no repro.
      final random = Random(20260816);
      final list = <FracIndex>[];
      for (var n = 0; n < 12; n++) {
        list.add(nextOrder(list));
      }

      for (var step = 0; step < 1000; step++) {
        final at = random.nextInt(list.length + 1);
        final before = at == 0 ? null : list[at - 1];
        final after = at == list.length ? null : list[at];
        final minted = orderBetween(before, after);
        if (minted == null) {
          // Exhaustion is a real state and it is allowed to happen here;
          // what is not allowed is a wrong answer. Move on.
          continue;
        }
        _sortsBetween(before, minted, after);
        list.insert(at, minted);
      }

      for (var i = 1; i < list.length; i++) {
        expect(
          list[i].v.compareTo(list[i - 1].v),
          greaterThan(0),
          reason: 'the list stopped being sorted at $i',
        );
      }
      expect(list.map((i) => i.v).toSet(), hasLength(list.length));
    });
  });
}
