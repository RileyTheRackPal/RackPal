// M3-B/1, #144 — `doc.locations` read as a tree (CR-047, CR-112).
//
// The tree is `parentId` and nothing else, so the claims split in two.
//
// THE WELL-FORMED HALF:
//   1. roots, children and pre-order come out in `order` then id, and the
//      id tiebreak actually decides when two siblings collide on `order`;
//   2. `LocationKind` never affects shape — a `site` under a `zone` nests
//      exactly like anything else, because CR-047 rules a tree and not
//      four levels;
//   3. `pathTo`/`breadcrumbOf` render CR-047's own `Level 1 › Living Room`;
//   4. `subtreeOf` is the unit DR-021 §11.20.1 deletes.
//
// THE MALFORMED HALF, which is the half that earns the file. A `.rmpj` is
// hand-editable text (DR-015) and nothing validates `parentId` on decode,
// so a cycle and a dangling parent are both reachable INPUTS rather than
// states a command has to be prevented from reaching. Every one of these
// asserts termination first and placement second: a walk that hangs fails
// this suite by timing out, which is the only way to state "is total".
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// [order] defaults MID-ALPHABET rather than to `a0`, so that any test
/// spelling an order out is stating something: `a0` next to a default is a
/// deliberate "this one sorts first", not a value that happened to match.
Location _loc(
  String id, {
  String? parent,
  String name = '',
  String order = 'm0',
  LocationKind kind = LocationKind.room,
}) => Location(
  id: Uuid(id),
  kind: kind,
  name: name.isEmpty ? id : name,
  code: id.toUpperCase(),
  order: FracIndex(order),
  meta: _meta(),
  parentId: parent == null ? null : Uuid(parent),
);

RackDocument _doc(List<Location> locations) {
  final doc = RackDocument(
    id: const Uuid('doc-location-tree'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  for (final l in locations) {
    doc.locations[l.id] = l;
  }
  return doc;
}

List<String> _v(Iterable<Uuid> ids) => [for (final id in ids) id.v];

void main() {
  group('shape', () {
    test('an empty document has an empty tree, and every query is total', () {
      final tree = LocationTree.of(_doc(const []));

      expect(tree.roots, isEmpty);
      expect(tree.length, 0);
      expect(tree.preOrder, isEmpty);
      expect(tree.childrenOf(const Uuid('nope')), isEmpty);
      expect(tree.pathTo(const Uuid('nope')), isEmpty);
      expect(tree.subtreeOf(const Uuid('nope')), isEmpty);
      expect(tree.ancestorsOf(const Uuid('nope')), isEmpty);
      expect(tree.parentOf(const Uuid('nope')), isNull);
    });

    test('roots and children come out in order, and pre-order nests', () {
      final tree = LocationTree.of(
        _doc([
          _loc('house', order: 'a0'),
          _loc('shed', order: 'a1'),
          _loc('lounge', parent: 'house', order: 'a1'),
          _loc('kitchen', parent: 'house', order: 'a0'),
        ]),
      );

      expect(_v(tree.roots), ['house', 'shed']);
      expect(_v(tree.childrenOf(const Uuid('house'))), ['kitchen', 'lounge']);
      expect(_v(tree.preOrder), ['house', 'kitchen', 'lounge', 'shed']);
      expect(tree.length, 4);
    });

    test('two siblings sharing an order are broken by id, not by luck', () {
      // Reachable from a decoded file: nothing before `AddLocationCommand`
      // allocated `Location.order` through `nextOrder`, so a hand-written
      // or older document can collide. `List.sort` is not stable, so
      // without the id tiebreak these two could come back either way on
      // either run and the Pull Sheet's room bands would shuffle between
      // exports of an unmodified project.
      final ids = _v(
        LocationTree.of(
          _doc([
            _loc('zulu', order: 'a0'),
            _loc('alpha', order: 'a0'),
            _loc('mike', order: 'a0'),
          ]),
        ).roots,
      );

      expect(ids, ['alpha', 'mike', 'zulu']);
    });

    test('LocationKind carries no containment: a site nests under a zone', () {
      // CR-047 rules ONE arbitrary-depth tree of which the device
      // builder's four levels are a VIEW. A derivation that sorted or
      // nested by `kind` would be the ruling overturned in a helper.
      final tree = LocationTree.of(
        _doc([
          _loc('zone', kind: LocationKind.zone),
          _loc('site', parent: 'zone', kind: LocationKind.site),
          _loc('desk', parent: 'site', kind: LocationKind.outdoor),
        ]),
      );

      expect(_v(tree.roots), ['zone']);
      expect(_v(tree.pathTo(const Uuid('desk'))), ['zone', 'site', 'desk']);
      expect(tree.depthOf(const Uuid('desk')), 2);
    });
  });

  group('paths', () {
    final doc = _doc([
      _loc('house', name: 'Main House'),
      _loc('l1', parent: 'house', name: 'Level 1'),
      _loc('living', parent: 'l1', name: 'Living Room'),
      _loc('blank', parent: 'l1', name: '   '),
    ]);
    final tree = LocationTree.of(doc);

    test(
      'pathTo is root-first and inclusive; ancestorsOf is nearest-first',
      () {
        expect(_v(tree.pathTo(const Uuid('living'))), [
          'house',
          'l1',
          'living',
        ]);
        expect(_v(tree.ancestorsOf(const Uuid('living'))), ['l1', 'house']);
        expect(_v(tree.pathTo(const Uuid('house'))), ['house']);
        expect(tree.ancestorsOf(const Uuid('house')), isEmpty);
      },
    );

    test('breadcrumbOf renders CR-047 §724 verbatim', () {
      expect(
        breadcrumbOf(doc, tree, const Uuid('living')),
        'Main House › Level 1 › Living Room',
      );
    });

    test('a nameless node shows a placeholder, a missing one shows null', () {
      // Two different problems, and G4's rule is that they stay
      // distinguishable: "this room has no name yet" is a thing to type
      // into, "this room is gone" is a stale selection to clear.
      expect(
        breadcrumbOf(doc, tree, const Uuid('blank')),
        'Main House › Level 1 › $kUnnamedLocation',
      );
      expect(breadcrumbOf(doc, tree, const Uuid('ghost')), isNull);
    });

    test('depthOf answers -1 for a node the tree does not hold', () {
      // NOT 0. A panel indenting by depth would otherwise render a
      // missing node flush left, indistinguishable from a real root.
      expect(tree.depthOf(const Uuid('ghost')), -1);
      expect(tree.depthOf(const Uuid('house')), 0);
    });
  });

  group('subtreeOf, the unit DR-021 deletes', () {
    final tree = LocationTree.of(
      _doc([
        _loc('house'),
        _loc('l1', parent: 'house', order: 'a0'),
        _loc('l2', parent: 'house', order: 'a1'),
        _loc('living', parent: 'l1'),
        _loc('bed', parent: 'l2'),
        _loc('shed'),
      ]),
    );

    test('includes the node itself and every descendant, pre-order', () {
      expect(_v(tree.subtreeOf(const Uuid('house'))), [
        'house',
        'l1',
        'living',
        'l2',
        'bed',
      ]);
    });

    test('a leaf is its own subtree, and a sibling branch is untouched', () {
      expect(_v(tree.subtreeOf(const Uuid('living'))), ['living']);
      expect(_v(tree.subtreeOf(const Uuid('l1'))), ['l1', 'living']);
      expect(_v(tree.subtreeOf(const Uuid('shed'))), ['shed']);
    });

    test('an id the tree does not hold has an empty subtree', () {
      // The "nothing to do" a delete of an already-deleted location wants,
      // rather than a throw a caller has to guard.
      expect(tree.subtreeOf(const Uuid('ghost')), isEmpty);
    });
  });

  group('wouldCycle, the question the reparent refusal asks', () {
    final tree = LocationTree.of(
      _doc([
        _loc('house'),
        _loc('l1', parent: 'house'),
        _loc('living', parent: 'l1'),
        _loc('shed'),
      ]),
    );

    test('a node may not become its own parent', () {
      expect(tree.wouldCycle(const Uuid('l1'), const Uuid('l1')), isTrue);
    });

    test('a node may not move under its own descendant, at any depth', () {
      expect(tree.wouldCycle(const Uuid('house'), const Uuid('l1')), isTrue);
      expect(
        tree.wouldCycle(const Uuid('house'), const Uuid('living')),
        isTrue,
      );
    });

    test('every move that is not into its own subtree is fine', () {
      expect(
        tree.wouldCycle(const Uuid('living'), const Uuid('house')),
        isFalse,
      );
      expect(tree.wouldCycle(const Uuid('l1'), const Uuid('shed')), isFalse);
      expect(
        tree.wouldCycle(const Uuid('shed'), const Uuid('living')),
        isFalse,
      );
    });
  });

  group('a document that is not a tree', () {
    test('a dangling parent becomes a root and is reported, never dropped', () {
      final tree = LocationTree.of(
        _doc([_loc('house'), _loc('orphan', parent: 'demolished')]),
      );

      expect(_v(tree.roots), ['house', 'orphan']);
      expect(_v(tree.detached), ['orphan']);
      expect(tree.cyclic, isEmpty);
      // THE POINT: the room is still in the tree. A panel that omitted it
      // would hide the one row the user needs in order to fix the file.
      expect(tree.length, 2);
      expect(_v(tree.preOrder), containsAll(['house', 'orphan']));
    });

    test('a self-parent is the one-node cycle, and terminates', () {
      final tree = LocationTree.of(
        _doc([_loc('ouroboros', parent: 'ouroboros')]),
      );

      expect(_v(tree.cyclic), ['ouroboros']);
      expect(_v(tree.roots), ['ouroboros']);
      expect(tree.parentOf(const Uuid('ouroboros')), isNull);
      expect(tree.ancestorsOf(const Uuid('ouroboros')), isEmpty);
      expect(_v(tree.subtreeOf(const Uuid('ouroboros'))), ['ouroboros']);
    });

    test('a three-node loop terminates and reports all three', () {
      final tree = LocationTree.of(
        _doc([
          _loc('a', parent: 'c'),
          _loc('b', parent: 'a'),
          _loc('c', parent: 'b'),
        ]),
      );

      expect(_v(tree.cyclic)..sort(), ['a', 'b', 'c']);
      expect(_v(tree.roots), ['a', 'b', 'c']);
      expect(tree.preOrder, hasLength(3));
      for (final id in ['a', 'b', 'c']) {
        expect(tree.ancestorsOf(Uuid(id)), isEmpty, reason: id);
        expect(_v(tree.subtreeOf(Uuid(id))), [id], reason: id);
      }
    });

    test('a node feeding a loop is reported with it, not treated as sound', () {
      // `feeder` is not itself in the loop. It is exactly as unable to
      // reach a root as a member is, and a report naming only the loop
      // would tell the user three rooms are broken when four are.
      final tree = LocationTree.of(
        _doc([
          _loc('a', parent: 'c'),
          _loc('b', parent: 'a'),
          _loc('c', parent: 'b'),
          _loc('feeder', parent: 'a'),
        ]),
      );

      expect(_v(tree.cyclic)..sort(), ['a', 'b', 'c', 'feeder']);
      expect(tree.ancestorsOf(const Uuid('feeder')), isEmpty);
    });

    test('a sound branch that joins a settled chain stays sound', () {
      // The memoisation in `_findCycles` adopts an already-computed
      // answer. Getting that adoption backwards marks a perfectly good
      // chain cyclic the moment it meets a settled one, and every node
      // here reaches `house` by a different-length walk on purpose.
      final tree = LocationTree.of(
        _doc([
          _loc('house'),
          _loc('l1', parent: 'house'),
          _loc('l2', parent: 'l1'),
          _loc('l3', parent: 'l2'),
          _loc('joiner', parent: 'l3'),
          _loc('early', parent: 'l1'),
        ]),
      );

      expect(tree.cyclic, isEmpty);
      expect(tree.detached, isEmpty);
      expect(_v(tree.roots), ['house']);
      expect(tree.depthOf(const Uuid('joiner')), 4);
      expect(tree.depthOf(const Uuid('early')), 2);
    });

    test('a loop beside a sound tree leaves the sound tree alone', () {
      final tree = LocationTree.of(
        _doc([
          _loc('house'),
          _loc('living', parent: 'house'),
          _loc('x', parent: 'y'),
          _loc('y', parent: 'x'),
        ]),
      );

      expect(_v(tree.cyclic)..sort(), ['x', 'y']);
      expect(_v(tree.childrenOf(const Uuid('house'))), ['living']);
      expect(_v(tree.pathTo(const Uuid('living'))), ['house', 'living']);
      expect(_v(tree.roots)..sort(), ['house', 'x', 'y']);
    });
  });
}
