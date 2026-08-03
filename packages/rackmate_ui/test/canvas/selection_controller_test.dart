// Unit tests for the observable SelectionController (docs/03 §4.4). Pure
// ChangeNotifier logic — the apply() fold for each SelectMode, focus
// tracking, and the snapshot/restore round-trip against core's Selection
// type that undo/redo rides on. No document coupling by construction, which
// is what makes "selection never dirties the file" true.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

const _a = Uuid('a');
const _b = Uuid('b');
const _c = Uuid('c');

void main() {
  group('SelectMode.replace', () {
    test('replaces the whole set and focuses the last hit', () {
      final sel = SelectionController()
        ..apply([_a, _b], SelectMode.replace)
        ..apply([_c], SelectMode.replace);
      expect(sel.ids, {_c});
      expect(sel.focus, _c);
    });

    test('replace with no hits clears and defocuses', () {
      final sel = SelectionController()
        ..apply([_a], SelectMode.replace)
        ..apply(const [], SelectMode.replace);
      expect(sel.ids, isEmpty);
      expect(sel.focus, isNull);
    });
  });

  group('SelectMode.add / subtract (Ctrl+click toggle building blocks)', () {
    test('add unions and refocuses the newly added id', () {
      final sel = SelectionController()
        ..apply([_a], SelectMode.replace)
        ..apply([_b], SelectMode.add);
      expect(sel.ids, {_a, _b});
      expect(sel.focus, _b);
    });

    test('subtract removes and clears focus only if it was removed', () {
      // focus is _b; subtracting _a leaves focus intact.
      final sel = SelectionController()
        ..apply([_a, _b], SelectMode.replace)
        ..apply([_a], SelectMode.subtract);
      expect(sel.ids, {_b});
      expect(sel.focus, _b);
      // subtracting the focused id clears focus.
      sel.apply([_b], SelectMode.subtract);
      expect(sel.ids, isEmpty);
      expect(sel.focus, isNull);
    });
  });

  test('clear() empties the selection', () {
    final sel = SelectionController()
      ..apply([_a, _b], SelectMode.replace)
      ..clear();
    expect(sel.ids, isEmpty);
    expect(sel.focus, isNull);
  });

  test('ids getter is unmodifiable (mutate only through the API)', () {
    final sel = SelectionController()..apply([_a], SelectMode.replace);
    expect(() => sel.ids.add(_b), throwsUnsupportedError);
  });

  group('snapshot / restore round-trip (undo/redo path)', () {
    test(
      'snapshot captures ids+focus; restore reinstates them and notifies',
      () {
        final sel = SelectionController()..apply([_a, _b], SelectMode.replace);
        final snap = sel.snapshot();
        expect(snap.ids, {_a, _b});
        expect(snap.focus, _b);

        // Move on, then restore the earlier snapshot (what undo does).
        var notified = 0;
        sel
          ..apply([_c], SelectMode.replace)
          ..addListener(() => notified++)
          ..restore(snap);
        expect(sel.ids, {_a, _b});
        expect(sel.focus, _b);
        expect(notified, 1);
      },
    );

    test('snapshot is independent — later mutation does not alias it', () {
      final sel = SelectionController()..apply([_a], SelectMode.replace);
      final snap = sel.snapshot();
      sel.apply([_b], SelectMode.add);
      // The captured snapshot must not have grown.
      expect(snap.ids, {_a});
    });
  });

  test('every apply notifies listeners exactly once', () {
    var count = 0;
    SelectionController()
      ..addListener(() => count++)
      ..apply([_a], SelectMode.replace)
      ..apply([_b], SelectMode.add)
      ..apply([_a], SelectMode.subtract);
    expect(count, 3);
  });

  test('is a ChangeNotifier (observable, not document state)', () {
    expect(SelectionController(), isA<ChangeNotifier>());
  });
}
