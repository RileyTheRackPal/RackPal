// The port grid's selection (DR-061, M4-F0 #695).
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Six rows, which is enough to have a middle.
const _order = ['a', 'b', 'c', 'd', 'e', 'f'];

void main() {
  group('a plain click', () {
    test('selects one row and anchors on it', () {
      final s = PortSelection.empty.selectOnly('c');
      expect(s.keys, {'c'});
      expect(s.anchor, 'c');
    });

    test('replaces whatever was selected before', () {
      final s = PortSelection.empty
          .selectOnly('a')
          .extendTo('d', _order)
          .selectOnly('f');
      expect(s.keys, {'f'});
    });

    test('keeps the focused column, because clicking a row is not a '
        'statement about which column matters', () {
      final s = PortSelection.empty
          .withColumn(PortColumnId.label)
          .selectOnly('b');
      expect(s.column, PortColumnId.label);
    });
  });

  group('Shift+click', () {
    test('takes the contiguous run from the anchor, downward', () {
      final s = PortSelection.empty.selectOnly('b').extendTo('e', _order);
      expect(s.inOrder(_order), ['b', 'c', 'd', 'e']);
    });

    test('takes the contiguous run from the anchor, upward', () {
      final s = PortSelection.empty.selectOnly('e').extendTo('b', _order);
      expect(s.inOrder(_order), ['b', 'c', 'd', 'e']);
    });

    test('leaves the anchor where it was, so a second one CORRECTS the '
        'range rather than extending from where the first landed', () {
      final s = PortSelection.empty
          .selectOnly('b')
          .extendTo('f', _order)
          .extendTo('c', _order);
      expect(s.anchor, 'b');
      expect(s.inOrder(_order), ['b', 'c']);
    });

    test('replaces the set rather than adding to it', () {
      final s = PortSelection.empty
          .selectOnly('a')
          .toggle('f')
          .extendTo('c', _order);
      expect(s.inOrder(_order), ['c', 'd', 'e', 'f']);
      expect(s.contains('a'), isFalse);
    });

    test('with no anchor is a plain click, because a range needs two ends', () {
      final s = PortSelection.empty.extendTo('d', _order);
      expect(s.keys, {'d'});
      expect(s.anchor, 'd');
    });

    test('with an anchor the grid no longer shows is a plain click', () {
      final s = PortSelection.empty.selectOnly('gone').extendTo('d', _order);
      expect(s.keys, {'d'});
    });

    test('RANGES OVER THE VISIBLE ROWS ONLY, so a collapsed band is not '
        'silently swept into a fill-down', () {
      // `c` and `d` are inside a folded bank, so the grid does not offer
      // them and the order it hands over does not hold them.
      const visible = ['a', 'b', 'e', 'f'];
      final s = PortSelection.empty.selectOnly('b').extendTo('e', visible);
      expect(s.keys, {'b', 'e'});
      expect(s.contains('c'), isFalse);
      expect(s.contains('d'), isFalse);
    });
  });

  group('Ctrl+click, which is also the tick box', () {
    test('adds a row without disturbing the rest', () {
      final s = PortSelection.empty
          .selectOnly('a')
          .extendTo('b', _order)
          .toggle('e');
      expect(s.inOrder(_order), ['a', 'b', 'e']);
    });

    test('removes a row that was in the set', () {
      final s = PortSelection.empty
          .selectOnly('a')
          .extendTo('c', _order)
          .toggle('b');
      expect(s.inOrder(_order), ['a', 'c']);
    });

    test('anchors even when it REMOVES, because the anchor is where the '
        'hand last was and not what is selected', () {
      final s = PortSelection.empty
          .selectOnly('a')
          .extendTo('c', _order)
          .toggle('b');
      expect(s.anchor, 'b');
      expect(s.extendTo('d', _order).inOrder(_order), ['b', 'c', 'd']);
    });
  });

  group('the top of the selection', () {
    test('is the first selected row in DISPLAY order, not the first one '
        'clicked', () {
      final s = PortSelection.empty.selectOnly('e').extendTo('b', _order);
      expect(s.top(_order), 'b');
    });

    test('follows a re-ordered display, which is what makes fill down '
        'mean the same thing under F5 view-only sort', () {
      final s = PortSelection.empty.selectOnly('b').extendTo('d', _order);
      expect(s.top(_order), 'b');
      expect(s.top(['f', 'e', 'd', 'c', 'b', 'a']), 'd');
    });

    test('is null when nothing is selected', () {
      expect(PortSelection.empty.top(_order), isNull);
    });

    test('ignores a selected row the display no longer holds', () {
      final s = PortSelection.empty.selectOnly('a').toggle('c');
      expect(s.top(const ['c', 'd']), 'c');
    });
  });

  group('pruning to the ports that still exist', () {
    test('drops a deleted row so no count counts rows that are not there', () {
      final s = PortSelection.empty
          .selectOnly('a')
          .extendTo('c', _order)
          .prunedTo({'a', 'c'});
      expect(s.keys, {'a', 'c'});
    });

    test('drops the anchor with it, so a later Shift+click cannot range '
        'from a row that was deleted', () {
      final s = PortSelection.empty
          .selectOnly('b')
          .extendTo('d', _order)
          .prunedTo({'c', 'd'});
      expect(s.anchor, isNull);
    });

    test('keeps the anchor when the anchor survived', () {
      final s = PortSelection.empty
          .selectOnly('b')
          .extendTo('d', _order)
          .prunedTo({'b', 'c'});
      expect(s.anchor, 'b');
    });

    test('returns the same object when nothing changed, so a rebuild is '
        'not a new selection', () {
      final s = PortSelection.empty.selectOnly('b').extendTo('d', _order);
      expect(identical(s.prunedTo({'a', 'b', 'c', 'd'}), s), isTrue);
    });

    test('keeps the focused column, which a deleted ROW says nothing '
        'about', () {
      final s = PortSelection.empty
          .selectOnly('b')
          .withColumn(PortColumnId.notes)
          .prunedTo(const <String>{});
      expect(s.column, PortColumnId.notes);
      expect(s.isEmpty, isTrue);
    });
  });

  group('the focused column', () {
    test('is null until a cell reports focus', () {
      expect(PortSelection.empty.column, isNull);
    });

    test('survives every row gesture, because the two are orthogonal '
        'and that is the whole of DR-061', () {
      final s = PortSelection.empty
          .withColumn(PortColumnId.connector)
          .selectOnly('a')
          .extendTo('c', _order)
          .toggle('e');
      expect(s.column, PortColumnId.connector);
    });

    test('clears when focus leaves the grid, without clearing the rows', () {
      final s = PortSelection.empty
          .selectOnly('a')
          .withColumn(PortColumnId.label)
          .withoutColumn();
      expect(s.column, isNull);
      expect(s.keys, {'a'});
    });
  });

  group('the selection cannot be mutated through the set it hands out', () {
    test('because a caller holding one must not be able to change what '
        'the grid is about to draw', () {
      final s = PortSelection.empty.selectOnly('a');
      expect(() => s.keys.add('b'), throwsUnsupportedError);
    });
  });

  // Tab has no rule here: default focus traversal already walks the grid
  // in reading order, skips closed packs and scrolls, measured through the
  // real grid for #949, so columnAfter, columnBefore and rowAbove (which no
  // key in docs/06 §4.6 reaches) were deleted with their tests.
  group('Enter movement', () {
    test('Enter moves down, and crosses a band header without stopping', () {
      // `c` ends one band and `d` starts the next; the flat row order is
      // what `PortTable.rows` hands over for exactly this reason.
      expect(rowBelow('c', _order), 'd');
    });

    test('down stops at the last row rather than wrapping', () {
      expect(rowBelow('f', _order), isNull);
    });

    test('a row the display no longer holds moves nowhere', () {
      expect(rowBelow('gone', _order), isNull);
    });
  });
}
