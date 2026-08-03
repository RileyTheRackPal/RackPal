// #93 / 93-C — the selection half of multi-draw.
//
// THE ONE PROPERTY WORTH MOST OF THIS FILE is that a `PinSelection` cannot
// hold two banks or two devices. `planMultiDraw` re-filters its sources
// precisely because a caller might get that wrong; these tests are the
// reason it never has anything to remove.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/src/canvas/schematic/connect_overlay.dart';
import 'package:rackmate_ui/src/canvas/schematic/pin_selection.dart';

/// A bank of eight, in rank order — the 8x8 matrix's output side.
const _rank = <String>[
  'out.1',
  'out.2',
  'out.3',
  'out.4',
  'out.5',
  'out.6',
  'out.7',
  'out.8',
];

PinRef _pin(String key, {String device = 'mtx'}) =>
    PinRef(deviceId: device, portKey: key);

void main() {
  group('the empty selection', () {
    test('holds nothing and drives nothing', () {
      const sel = PinSelection.none;
      expect(sel.isEmpty, isTrue);
      expect(sel.isMultiple, isFalse);
      expect(sel.length, 0);
      expect(sel.refs, isEmpty);
      expect(sel.contains(_pin('out.1')), isFalse);
    });

    test('step does nothing rather than inventing an anchor', () {
      expect(
        PinSelection.none.step(by: 1, rank: _rank),
        same(PinSelection.none),
      );
    });
  });

  group('one pin', () {
    test('is a legal state and is NOT a multi-draw', () {
      final sel = PinSelection.at(_pin('out.3'), bankKey: 'out');
      expect(sel.isEmpty, isFalse);
      expect(sel.length, 1);
      // The distinction DR-012.2 and LabelKey.multiDraw both rest on: one
      // cable is a pin-to-pin connect, whatever gesture reached it.
      expect(sel.isMultiple, isFalse);
      expect(sel.portKeys, ['out.3']);
      expect(sel.anchor, 'out.3');
      expect(sel.head, 'out.3');
    });
  });

  group('extendTo — the Shift+click range', () {
    test('runs forwards from the anchor, in rank order', () {
      final sel = PinSelection.at(
        _pin('out.2'),
        bankKey: 'out',
      ).extendTo(_pin('out.5'), bankKey: 'out', rank: _rank);
      expect(sel.portKeys, ['out.2', 'out.3', 'out.4', 'out.5']);
      expect(sel.isMultiple, isTrue);
      expect(sel.anchor, 'out.2');
      expect(sel.head, 'out.5');
    });

    test('runs BACKWARDS from the anchor and still emits rank order', () {
      // The list a user builds by clicking pin 6 then shift-clicking pin 3
      // must be the same list as 3-then-6, because `planMultiDraw` pairs
      // sources against sinks positionally.
      final sel = PinSelection.at(
        _pin('out.6'),
        bankKey: 'out',
      ).extendTo(_pin('out.3'), bankKey: 'out', rank: _rank);
      expect(sel.portKeys, ['out.3', 'out.4', 'out.5', 'out.6']);
      expect(sel.anchor, 'out.6');
      expect(sel.head, 'out.3');
    });

    test('the whole bank is two clicks — docs/05:484 own example', () {
      final sel = PinSelection.at(
        _pin('out.1'),
        bankKey: 'out',
      ).extendTo(_pin('out.8'), bankKey: 'out', rank: _rank);
      expect(sel.length, 8);
      expect(sel.portKeys, _rank);
    });

    test('extending onto ANOTHER BANK replaces, never mixes', () {
      final sel = PinSelection.at(
        _pin('out.1'),
        bankKey: 'out',
      ).extendTo(_pin('in.4'), bankKey: 'in', rank: const ['in.4']);
      expect(sel.bankKey, 'in');
      expect(sel.portKeys, ['in.4']);
      expect(sel.anchor, 'in.4');
    });

    test('extending onto ANOTHER DEVICE replaces, never mixes', () {
      final sel =
          PinSelection.at(
            _pin('out.1'),
            bankKey: 'out',
          ).extendTo(
            _pin('out.4', device: 'amp'),
            bankKey: 'out',
            rank: _rank,
          );
      expect(sel.deviceId, 'amp');
      expect(sel.portKeys, ['out.4']);
    });

    test('a rank missing an end falls back to one pin, not a guess', () {
      final sel = PinSelection.at(
        _pin('out.1'),
        bankKey: 'out',
      ).extendTo(_pin('out.5'), bankKey: 'out', rank: const ['out.5']);
      expect(sel.portKeys, ['out.5']);
    });
  });

  group('step — the keyboard range', () {
    test('grows the run by one', () {
      final sel = PinSelection.at(
        _pin('out.3'),
        bankKey: 'out',
      ).step(by: 1, rank: _rank);
      expect(sel.portKeys, ['out.3', 'out.4']);
      expect(sel.anchor, 'out.3');
      expect(sel.head, 'out.4');
    });

    test('reversing past the anchor SHRINKS then grows the other way', () {
      var sel = PinSelection.at(
        _pin('out.3'),
        bankKey: 'out',
      ).step(by: 1, rank: _rank).step(by: 1, rank: _rank);
      expect(sel.portKeys, ['out.3', 'out.4', 'out.5']);
      sel = sel.step(by: -1, rank: _rank);
      expect(sel.portKeys, ['out.3', 'out.4']);
      sel = sel.step(by: -1, rank: _rank).step(by: -1, rank: _rank);
      expect(sel.portKeys, ['out.2', 'out.3']);
    });

    test('does NOT wrap at either end of the bank', () {
      final first = PinSelection.at(_pin('out.1'), bankKey: 'out');
      expect(first.step(by: -1, rank: _rank).portKeys, ['out.1']);
      final last = PinSelection.at(_pin('out.8'), bankKey: 'out');
      expect(last.step(by: 1, rank: _rank).portKeys, ['out.8']);
    });
  });

  group('prunedAgainst — the document moved', () {
    test('keeps a selection every pin of which survives', () {
      final sel = PinSelection.at(
        _pin('out.1'),
        bankKey: 'out',
      ).extendTo(_pin('out.3'), bankKey: 'out', rank: _rank);
      expect(sel.prunedAgainst(_rank).portKeys, ['out.1', 'out.2', 'out.3']);
    });

    test('drops the WHOLE selection when one pin has gone', () {
      // Not "seven of your eight cables" — the user chose a run, and a
      // silently smaller run is the failure `_invalidateLivePreviews`
      // tears the wire down to avoid.
      final sel = PinSelection.at(
        _pin('out.1'),
        bankKey: 'out',
      ).extendTo(_pin('out.3'), bankKey: 'out', rank: _rank);
      final pruned = sel.prunedAgainst(const ['out.1', 'out.3']);
      expect(pruned.isEmpty, isTrue);
    });
  });

  group('contains and refs', () {
    test('contains is device-aware, not key-only', () {
      final sel = PinSelection.at(
        _pin('out.1'),
        bankKey: 'out',
      ).extendTo(_pin('out.3'), bankKey: 'out', rank: _rank);
      expect(sel.contains(_pin('out.2')), isTrue);
      expect(sel.contains(_pin('out.2', device: 'amp')), isFalse);
      expect(sel.contains(_pin('out.7')), isFalse);
    });

    test('refs carry the selection device and stay in rank order', () {
      final sel = PinSelection.at(
        _pin('out.4'),
        bankKey: 'out',
      ).extendTo(_pin('out.2'), bankKey: 'out', rank: _rank);
      expect(
        sel.refs.map((r) => '${r.deviceId}/${r.portKey}').toList(),
        ['mtx/out.2', 'mtx/out.3', 'mtx/out.4'],
      );
    });
  });
}
