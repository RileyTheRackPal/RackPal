// rackpal_core/src/derived/location_tree.dart — pure Dart.
//
// The shape of `doc.locations` read as a tree: roots, children, the path to
// a node, and the subtree a delete would take. Board M3-B/1, CR-047,
// CR-112.
//
// ═══════════════════════════════════════════════════════════════════════
// THE TREE IS `parentId` AND NOTHING ELSE
// ═══════════════════════════════════════════════════════════════════════
// CR-047 rules ONE arbitrary-depth tree, of which the device builder's
// four levels and the rack editor's flat combobox are both VIEWS. So this
// file derives structure from `Location.parentId` alone and never from
// `LocationKind`: a `room` under a `room` is legal, a `site` under a
// `zone` is legal, and a UI that infers depth from the enum is CR-047
// being overturned by a widget. `kind` is a label the user picks; it
// carries no containment.
//
// ═══════════════════════════════════════════════════════════════════════
// TOTAL AGAINST A DOCUMENT THAT IS NOT A TREE
// ═══════════════════════════════════════════════════════════════════════
// `ReparentLocationCommand` refuses to CREATE a cycle (DR-021 §11.20.5),
// which says nothing about a document that already holds one. Nothing
// validates `parentId` on decode, `.rppj` is a text format people hand-edit
// (DR-015), and G5's forward-compatibility story means a file written by a
// build that had no such refusal is openable by one that does.
//
// So every walk here carries a visited set and TERMINATES. A node whose
// chain loops, or whose parent is not in the document, is reported in
// [LocationTree.cyclic] / [LocationTree.detached] AND STILL APPEARS as a
// root. That is G4's shape rather than a convenience: the alternative is
// a panel that silently omits a room the file contains, which is the one
// outcome worse than showing it in the wrong place. The user cannot fix
// what they cannot see.
//
// ═══════════════════════════════════════════════════════════════════════
// A SHAPE SNAPSHOT, NOT A VIEW ONTO THE DOCUMENT
// ═══════════════════════════════════════════════════════════════════════
// [LocationTree] holds ids and edges, never a `RackDocument`, and it is
// rebuilt after any command that touches the tree. [breadcrumbOf] therefore
// takes the document as an argument rather than reading a captured one: a
// tree whose SHAPE is a snapshot and whose NAMES are live would be stale in
// one half and current in the other, and no call site could tell which.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/location.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// `Level 1 › Living Room` — CR-047's own spelling for the rack editor's
/// flattened combobox.
const String kLocationBreadcrumbSeparator = ' › ';

/// What a location with no name shows as. `kUnknownCell` in `schedule.dart`
/// is the same idea on the same grounds (G4): an empty string in a
/// breadcrumb reads as a rendering bug, and a fabricated "Room 1" reads as
/// data.
const String kUnnamedLocation = '(unnamed)';

/// `doc.locations` indexed as a tree: parent to children, plus the two
/// fault sets a malformed document produces.
///
/// Built once per read rather than answered per query. The panel draws
/// every node and the delete plan walks a whole subtree, and both would
/// otherwise rescan `doc.locations` per node.
@immutable
final class LocationTree {
  /// POSITIONAL, and private-named rather than `children`/`parents`,
  /// because Dart forbids a private NAMED parameter and the analyzer
  /// gate's `prefer_initializing_formals` forbids the assign-through
  /// workaround. Nothing outside this file calls it.
  const LocationTree._(
    this.roots,
    this._children,
    this._parents,
    this.detached,
    this.cyclic,
  );

  /// Indexes [doc]'s locations.
  factory LocationTree.of(RackDocument doc) {
    if (doc.locations.isEmpty) return empty;

    final parents = <Uuid, Uuid?>{};
    final detached = <Uuid>{};
    for (final entry in doc.locations.entries) {
      final parentId = entry.value.parentId;
      if (parentId == null) {
        parents[entry.key] = null;
      } else if (!doc.locations.containsKey(parentId)) {
        // The edge is DROPPED, not kept and skipped later. A parent that
        // is not in the document cannot be walked to, so recording it
        // would leave every consumer re-deciding what to do about it.
        parents[entry.key] = null;
        detached.add(entry.key);
      } else {
        // A SELF-PARENT IS NOT SPECIAL-CASED. It is the one-node cycle,
        // and `_findCycles` reaches it by the same walk that finds a
        // four-node one, so it is reported identically rather than as a
        // second kind of fault.
        parents[entry.key] = parentId;
      }
    }

    final cyclic = _findCycles(parents);
    // EVERY unreachable node becomes a root, so the panel shows it flat
    // rather than nested inside a loop that has no top. Flat and reported
    // is the honest rendering of "this region of the file is not a tree";
    // preserving the loop's edges would draw a hierarchy that cannot be
    // scrolled to the top of.
    for (final id in cyclic) {
      parents[id] = null;
    }

    final children = <Uuid, List<Uuid>>{};
    final roots = <Uuid>[];
    for (final entry in parents.entries) {
      final parentId = entry.value;
      if (parentId == null) {
        roots.add(entry.key);
      } else {
        (children[parentId] ??= <Uuid>[]).add(entry.key);
      }
    }

    _sortSiblings(roots, doc.locations);
    for (final siblings in children.values) {
      _sortSiblings(siblings, doc.locations);
    }

    return LocationTree._(
      List<Uuid>.unmodifiable(roots),
      {
        for (final e in children.entries)
          e.key: List<Uuid>.unmodifiable(e.value),
      },
      Map<Uuid, Uuid?>.unmodifiable(parents),
      Set<Uuid>.unmodifiable(detached),
      Set<Uuid>.unmodifiable(cyclic),
    );
  }

  /// The tree of a document with no locations at all, which is what every
  /// new project starts as until the panel creates one.
  static const LocationTree empty = LocationTree._(
    <Uuid>[],
    <Uuid, List<Uuid>>{},
    <Uuid, Uuid?>{},
    <Uuid>{},
    <Uuid>{},
  );

  /// Every node with no parent, plus every node in [detached] and
  /// [cyclic]. Sorted by `order` then id.
  final List<Uuid> roots;

  final Map<Uuid, List<Uuid>> _children;
  final Map<Uuid, Uuid?> _parents;

  /// Nodes whose `parentId` names a location this document does not hold.
  ///
  /// Reachable from a hand-edited file and from a delete that predates
  /// DR-021's cascade. They are roots, not omissions.
  final Set<Uuid> detached;

  /// Nodes that cannot reach a root: the members of a parent cycle, and
  /// any node whose chain feeds into one.
  ///
  /// BOTH, not just the loop itself. A node hanging off a cycle is exactly
  /// as unreachable from a root as a member of it, and a report naming
  /// only the loop would tell a user four rooms are broken when six are.
  final Set<Uuid> cyclic;

  /// Every id in the tree, unordered. `preOrder` is the ordered form.
  Iterable<Uuid> get ids => _parents.keys;

  int get length => _parents.length;

  bool contains(Uuid id) => _parents.containsKey(id);

  /// [id]'s parent, or null when it is a root, is [detached], is [cyclic],
  /// or is not in this document at all.
  ///
  /// Four causes, one answer, and callers want the same thing for all of
  /// them: nothing above this node to walk to.
  Uuid? parentOf(Uuid id) => _parents[id];

  /// [id]'s direct children, sorted by `order` then id.
  List<Uuid> childrenOf(Uuid id) => _children[id] ?? const <Uuid>[];

  /// [id]'s ancestors, NEAREST FIRST, excluding [id] itself.
  ///
  /// Empty for a root and for an id this tree does not hold. Terminates on
  /// a cyclic document because `LocationTree.of` has already cut those
  /// chains, and carries its own visited set anyway: this method is the one
  /// most likely to be reached for by a caller holding a tree built from a
  /// different document.
  List<Uuid> ancestorsOf(Uuid id) {
    final out = <Uuid>[];
    final visited = <Uuid>{id};
    var current = _parents[id];
    while (current != null && visited.add(current)) {
      out.add(current);
      current = _parents[current];
    }
    return out;
  }

  /// The path from the root down to [id], INCLUSIVE of both ends.
  ///
  /// `[id]` alone for a root. Empty for an id this tree does not hold,
  /// which is what makes it safe to call on a stale selection.
  List<Uuid> pathTo(Uuid id) {
    if (!_parents.containsKey(id)) return const <Uuid>[];
    return [...ancestorsOf(id).reversed, id];
  }

  /// How deep [id] sits. A root is `0`.
  ///
  /// Returns `-1` for an id this tree does not hold, so a caller
  /// indenting a list cannot silently render a missing node flush left as
  /// though it were a root.
  int depthOf(Uuid id) =>
      _parents.containsKey(id) ? ancestorsOf(id).length : -1;

  /// [id] and every descendant, in pre-order: a parent immediately before
  /// its own children, siblings in `order` then id.
  ///
  /// THE UNIT DR-021 §11.20.1 DELETES, and the unit its confirmation
  /// counts. Empty for an id this tree does not hold, which is the same
  /// "nothing to do" a delete of an already-deleted location wants.
  List<Uuid> subtreeOf(Uuid id) {
    if (!_parents.containsKey(id)) return const <Uuid>[];
    final out = <Uuid>[];
    _visit(id, out, <Uuid>{});
    return List<Uuid>.unmodifiable(out);
  }

  /// Every node, in pre-order, roots first.
  ///
  /// What the panel draws top to bottom, and what a breadcrumb list is
  /// generated from.
  List<Uuid> get preOrder {
    final out = <Uuid>[];
    final visited = <Uuid>{};
    for (final root in roots) {
      _visit(root, out, visited);
    }
    return List<Uuid>.unmodifiable(out);
  }

  /// Whether making [childId] a child of [newParentId] would create a
  /// cycle: true when they are the same node, or when [newParentId] is
  /// already somewhere below [childId].
  ///
  /// The QUESTION only. `buildReparentLocation` (location_commands.dart)
  /// owns the refusal and its sentence, because a bare bool at a call site
  /// is a refusal nobody has to explain.
  bool wouldCycle(Uuid childId, Uuid newParentId) {
    if (childId == newParentId) return true;
    final visited = <Uuid>{newParentId};
    var current = _parents[newParentId];
    while (current != null && visited.add(current)) {
      if (current == childId) return true;
      current = _parents[current];
    }
    return false;
  }

  void _visit(Uuid id, List<Uuid> out, Set<Uuid> visited) {
    if (!visited.add(id)) return;
    out.add(id);
    for (final child in childrenOf(id)) {
      _visit(child, out, visited);
    }
  }
}

/// `Main House › Level 1 › Living Room` — [id]'s path rendered with each
/// node's `name`.
///
/// The rack editor's combobox is this string (CR-047: *"the same tree
/// flattened to breadcrumb strings"*), and so is the label on any surface
/// that has room for one line rather than a tree.
///
/// Returns null for an id [doc] does not hold. NOT the empty string and
/// not a placeholder: a caller showing a location that is gone has a
/// different problem from one showing a location with no name, and G4's
/// rule is that the two stay distinguishable.
String? breadcrumbOf(
  RackDocument doc,
  LocationTree tree,
  Uuid id, {
  String separator = kLocationBreadcrumbSeparator,
}) {
  final path = tree.pathTo(id);
  if (path.isEmpty) return null;
  return path.map((n) => _displayName(doc.locations[n])).join(separator);
}

/// One node's name for display, never an empty string.
String _displayName(Location? location) {
  final name = location?.name.trim() ?? '';
  return name.isEmpty ? kUnnamedLocation : name;
}

/// Sorts one sibling list in place by `order`, then by id.
///
/// THE ID TIEBREAK IS NOT OPTIONAL. Dart's `List.sort` is not stable, and
/// `Location.order` collisions are reachable from a decoded file, since
/// nothing before `AddLocationCommand` allocated one through `nextOrder`.
/// Without a total comparator two runs over the same document could order
/// two same-`order` rooms differently, and the Pull Sheet's room bands
/// would shuffle between exports of an unmodified project.
void _sortSiblings(List<Uuid> ids, Map<Uuid, Location> locations) {
  ids.sort((a, b) {
    final byOrder = (locations[a]?.order.v ?? '').compareTo(
      locations[b]?.order.v ?? '',
    );
    return byOrder != 0 ? byOrder : a.v.compareTo(b.v);
  });
}

/// Every node whose parent chain never reaches a root.
///
/// Iterative, and it MEMOISES the answer per node rather than walking from
/// scratch per node: a straight chain of N locations is otherwise N walks
/// of average length N/2, and the location tree is the one structure in
/// this model a user is free to make arbitrarily deep. Each node is
/// settled exactly once, so the whole pass is linear.
Set<Uuid> _findCycles(Map<Uuid, Uuid?> parents) {
  /// true = this node's chain reaches a root. false = it does not.
  final settled = <Uuid, bool>{};
  final cyclic = <Uuid>{};

  for (final start in parents.keys) {
    if (settled.containsKey(start)) continue;

    final chain = <Uuid>[];
    final onChain = <Uuid>{};
    Uuid? current = start;
    bool? terminates;

    while (current != null) {
      final known = settled[current];
      if (known != null) {
        // Ran into an answer an earlier chain computed. It is this
        // chain's answer too, because everything above `current` is
        // shared with it. Adopting it is what makes this pass linear, and
        // getting it BACKWARDS here would mark a perfectly good chain
        // cyclic the moment it joined a settled one.
        terminates = known;
        break;
      }
      if (!onChain.add(current)) {
        terminates = false;
        break;
      }
      chain.add(current);
      current = parents[current];
    }

    // Falling out of the loop means `current` is null: the chain reached
    // a node with no parent, which is the definition of reaching a root.
    terminates ??= true;

    for (final id in chain) {
      settled[id] = terminates;
      // A node feeding a cycle can no more reach a root than a member of
      // the cycle can, so the whole chain goes in, not just the loop.
      if (!terminates) cyclic.add(id);
    }
  }
  return cyclic;
}
