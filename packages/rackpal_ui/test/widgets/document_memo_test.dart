// The derived-layer memo (M8-F1, board #424).
//
// THE FAILURE THIS GUARDS IS SILENT AND EXPENSIVE. A memo that misses too
// often costs a recompute; a memo that HITS too often shows somebody a
// stale cable schedule while they order cable. Every test below that
// asserts a miss is worth more than the ones asserting a hit.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

RackDocument _doc({int stateId = 0, String id = 'doc-1'}) => RackDocument(
  id: Uuid(id),
  appVersion: 'test',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    updatedBy: 'test',
    localRevision: 1,
  ),
)..stateId = stateId;

void main() {
  group('it remembers', () {
    test('the same state builds once and answers twice', () {
      final memo = DocumentMemo<List<int>>();
      final doc = _doc();
      var builds = 0;

      final first = memo.of(doc, () {
        builds++;
        return [1];
      });
      final second = memo.of(doc, () {
        builds++;
        return [2];
      });

      expect(builds, 1);
      expect(identical(first, second), isTrue);
    });

    test('it is empty until something is asked of it', () {
      expect(DocumentMemo<List<int>>().isEmpty, isTrue);
    });
  });

  group('it forgets, which is the half that matters', () {
    test('A NEW stateId REBUILDS, because that is a different document '
        'state and the old answer is about the old one', () {
      final memo = DocumentMemo<List<int>>();
      var builds = 0;
      List<int> ask(RackDocument d) => memo.of(d, () {
        builds++;
        return [builds];
      });

      ask(_doc(stateId: 4));
      final after = ask(_doc(stateId: 5));

      expect(builds, 2);
      expect(after, [2]);
    });

    test('AN UNDO REBUILDS TOO. `stateId` goes BACKWARDS on undo, and a '
        'memo that only noticed increases would serve the post-edit '
        'table for a document that had just been undone', () {
      final memo = DocumentMemo<List<int>>();
      var builds = 0;
      List<int> ask(RackDocument d) => memo.of(d, () {
        builds++;
        return [builds];
      });

      ask(_doc(stateId: 7));
      ask(_doc(stateId: 3));

      expect(builds, 2);
    });

    test('A SECOND DOCUMENT AT THE SAME stateId REBUILDS. `stateId` is '
        'in-memory and starts near zero, so two projects open in one '
        'session collide on their first few states', () {
      final memo = DocumentMemo<List<int>>();
      var builds = 0;
      List<int> ask(RackDocument d) => memo.of(d, () {
        builds++;
        return [builds];
      });

      ask(_doc(id: 'doc-a'));
      ask(_doc(id: 'doc-b'));

      expect(builds, 2);
    });

    test('a changed `extra` rebuilds, so a table scoped to one panel '
        'never answers for another', () {
      final memo = DocumentMemo<List<int>>();
      final doc = _doc();
      var builds = 0;
      List<int> ask(Object? extra) => memo.of(doc, () {
        builds++;
        return [builds];
      }, extra: extra);

      ask(const Uuid('body-1'));
      ask(const Uuid('body-2'));
      ask(const Uuid('body-1'));

      expect(builds, 3, reason: 'it holds ONE answer, not a map of them');
    });

    test('clear() forgets', () {
      final memo = DocumentMemo<List<int>>();
      final doc = _doc();
      var builds = 0;
      List<int> ask() => memo.of(doc, () {
        builds++;
        return [builds];
      });

      ask();
      memo.clear();
      ask();

      expect(builds, 2);
      expect(memo.isEmpty, isFalse);
    });
  });

  group('the trap its own doc warns about', () {
    test('A FRESH COLLECTION AS `extra` MISSES EVERY TIME, which is why '
        'the matrix view passes a joined string and not its Set', () {
      final memo = DocumentMemo<List<int>>();
      final doc = _doc();
      var builds = 0;
      List<int> ask(Object? extra) => memo.of(doc, () {
        builds++;
        return [builds];
      }, extra: extra);

      // A `Set` compares by identity, so two equal sets are not equal.
      ask({'a', 'b'});
      ask({'a', 'b'});
      expect(builds, 2, reason: 'this is the misuse, demonstrated');

      // The shape the call sites actually use.
      builds = 0;
      ask((cols: 'a,b'));
      ask((cols: 'a,b'));
      expect(builds, 1, reason: 'a record of primitives compares by value');
    });
  });
}
