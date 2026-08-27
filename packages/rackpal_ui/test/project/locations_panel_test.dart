// M3-B/2, #145 — the `Project ▸ Locations…` panel (CR-047, CR-112,
// DR-021), driven through real taps and real text entry against a real
// `DocumentController`.
//
// THE CLAIM THIS FILE EXISTS FOR is the board task's own: NEVER a fixed
// floor/room/wall hierarchy. A UI that hard-codes depth is CR-047 being
// overturned by a widget, and it would pass any test that pumped a
// three-level fixture. So the depth cases build a FIVE-deep chain and a
// `site` nested under a `zone`, which is legal precisely because `kind`
// carries no containment.
//
// The rest: every gesture runs exactly one Command and Ctrl+Z-equivalent
// undo puts it back, the cycle refusal reaches a user as a sentence, the
// delete counts before it runs, and a document that is not a tree still
// shows every room it contains.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _when = DateTime.utc(2026, 8, 6);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// The panel wired to a real controller, the way the app wires it.
///
/// Written here rather than imported from the app, because
/// `packages/rackpal_ui` may not depend on `apps/rackpal`. The
/// equivalence between the two wirings is what `app_shell`'s own test
/// asserts.
class _Harness {
  _Harness() {
    controller = DocumentController(
      RackDocument(
        id: const Uuid('doc-locations-panel'),
        appVersion: '0.1.0',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      ),
    );
  }

  late final DocumentController controller;
  final List<String> refusals = [];
  bool confirmAnswer = true;
  int confirmationsAsked = 0;
  LocationRemovalPlan? lastPlan;

  RackDocument get doc => controller.doc;

  LocationsPanelActions get actions => LocationsPanelActions(
    onAdd: (parentId) {
      final cmd = AddLocationCommand(
        name: 'New location',
        code: '',
        order: nextLocationOrder(doc, parentId: parentId),
        parentId: parentId,
        now: _when,
        actor: 'test',
      );
      controller.run(cmd);
      return cmd.id;
    },
    onRename: (id, name) => _set(id, LocationField.name, name),
    onSetCode: (id, code) => _set(id, LocationField.code, code),
    onSetKind: (id, kind) => _set(id, LocationField.kind, kind),
    onSetFloorNumber: (id, v) => _set(id, LocationField.floorNumber, v),
    onSetSpaceCode: (id, v) => _set(id, LocationField.spaceCode, v),
    onReparent: (id, newParentId) {
      final result = buildReparentLocation(
        doc: doc,
        id: id,
        newParentId: newParentId,
        now: _when,
        actor: 'test',
      );
      return switch (result) {
        ReparentLocationReady(:final command) => () {
          controller.run(command);
          return null;
        }(),
        ReparentLocationUnchanged() => null,
        ReparentLocationRefused(:final reason) => reason,
      };
    },
    onDelete: (id) async {
      final cmd = buildRemoveLocation(doc: doc, locationId: id);
      if (cmd == null) return false;
      lastPlan = cmd.plan;
      if (cmd.plan.needsConfirmation) {
        confirmationsAsked++;
        if (!confirmAnswer) return false;
      }
      controller.run(cmd);
      return true;
    },
    onRefuse: refusals.add,
  );

  void _set<T>(Uuid id, EntityField<Location, T> field, T value) {
    final cmd = buildSetEntityProperty(
      doc: doc,
      id: id,
      field: field,
      to: value,
      now: _when,
      actor: 'test',
    );
    if (cmd != null) controller.run(cmd);
  }

  /// Seeds a location directly, bypassing the panel, so a test can set up
  /// a shape without twenty taps.
  Uuid seed(String name, {Uuid? parent, String code = ''}) {
    final cmd = AddLocationCommand(
      name: name,
      code: code,
      order: nextLocationOrder(doc, parentId: parent),
      parentId: parent,
      now: _when,
      actor: 'seed',
    );
    controller.run(cmd);
    return cmd.id;
  }

  Widget get app => MaterialApp(
    home: Scaffold(
      body: LocationsPanel(doc: doc, actions: actions),
    ),
  );
}

/// The left inset of a row, which is what encodes its depth.
double _indentOf(WidgetTester tester, String name) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(name), matching: find.byType(Container)).first,
  );
  return (container.padding! as EdgeInsets).left;
}

void main() {
  group('never a fixed hierarchy (CR-047)', () {
    testWidgets('a five-deep chain renders, each level further in', (
      tester,
    ) async {
      // FIVE, not three. A panel with a hard-coded site/building/floor/room
      // would pass a three-level fixture and fail a real building, and the
      // failure would arrive on a user's project rather than here.
      final h = _Harness();
      var parent = h.seed('L0');
      final names = ['L0'];
      for (var i = 1; i < 5; i++) {
        parent = h.seed('L$i', parent: parent);
        names.add('L$i');
      }

      await tester.pumpWidget(h.app);

      var previous = -1.0;
      for (final name in names) {
        expect(find.text(name), findsOneWidget, reason: name);
        final indent = _indentOf(tester, name);
        expect(indent, greaterThan(previous), reason: name);
        previous = indent;
      }
    });

    testWidgets('a site nests under a zone, because kind is only a label', (
      tester,
    ) async {
      // CR-047: the device builder's four levels are a VIEW of one tree.
      // A panel that ordered or nested by `kind` would be the ruling
      // overturned in a widget.
      final h = _Harness();
      final zone = h.seed('Zone');
      h.seed('Site', parent: zone);

      await tester.pumpWidget(h.app);

      expect(_indentOf(tester, 'Site'), greaterThan(_indentOf(tester, 'Zone')));
    });

    testWidgets('a new location lands under the selected one, so depth is '
        'a gesture rather than a rule', (tester) async {
      final h = _Harness()..seed('Main House');
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Main House'));
      await tester.pump();
      await tester.tap(find.text('New in Main House'));
      await tester.pump();

      expect(h.doc.locations, hasLength(2));
      final tree = LocationTree.of(h.doc);
      expect(tree.roots, hasLength(1));
      expect(tree.childrenOf(tree.roots.single), hasLength(1));
    });

    testWidgets('with nothing selected the button offers a top-level add', (
      tester,
    ) async {
      final h = _Harness()..seed('Main House');
      await tester.pumpWidget(h.app);

      expect(find.text('New location'), findsOneWidget);
      await tester.tap(find.text('New location'));
      await tester.pump();

      expect(LocationTree.of(h.doc).roots, hasLength(2));
    });
  });

  group('editing', () {
    testWidgets('typing a name runs a command and undo puts it back', (
      tester,
    ) async {
      final h = _Harness();
      final id = h.seed('Livng Room');
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Livng Room'));
      await tester.pump();
      await tester.enterText(
        find.byKey(ValueKey('name-${id.v}')),
        'Living Room',
      );
      await tester.pump();

      expect(h.doc.locations[id]!.name, 'Living Room');
      // The load-bearing property: the edit is a Command, not a poke.
      h.controller.undoLast();
      expect(h.doc.locations[id]!.name, 'Livng Room');
    });

    testWidgets('the tree row follows the name as it is typed', (
      tester,
    ) async {
      final h = _Harness();
      final id = h.seed('Livng Room');
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Livng Room'));
      await tester.pump();
      await tester.enterText(
        find.byKey(ValueKey('name-${id.v}')),
        'Living Room',
      );
      await tester.pump();

      expect(find.text('Livng Room'), findsNothing);
      expect(find.text('Living Room'), findsWidgets);
    });

    testWidgets('an unnamed location still shows a word', (tester) async {
      // G4's shape at the row level: an empty string reads as a rendering
      // bug, and a fabricated "Room 1" reads as data.
      final h = _Harness()..seed('   ');
      await tester.pumpWidget(h.app);

      expect(find.text(kUnnamedLocation), findsOneWidget);
    });
  });

  group('{FLOOR} and {SPACE} have controls at last (DR-040 §11.39.4)', () {
    /// Selects [name] and returns the harness, so each case starts from a
    /// detail pane rather than from a tree.
    Future<Uuid> open(WidgetTester tester, _Harness h, String name) async {
      final id = h.seed(name);
      await tester.pumpWidget(h.app);
      await tester.tap(find.text(name));
      await tester.pump();
      return id;
    }

    testWidgets('a floor and a space reach the document as commands', (
      tester,
    ) async {
      // THE ABSENCE THIS CLOSES, stated as the assertion: before this,
      // `floorNumber` and `spaceCode` appeared across the whole of
      // `rackpal_ui/lib` and `apps/rackpal/lib` exactly once, in a
      // comment saying they had no editor. Three of the four tokens in
      // `{FLOOR}{SPACE}-{PANEL}{PORT:2}` were therefore unreachable.
      final h = _Harness();
      final id = await open(tester, h, 'Media Closet');

      await tester.enterText(find.byKey(ValueKey('floor-${id.v}')), '1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.enterText(find.byKey(ValueKey('space-${id.v}')), 'A');
      await tester.pump();

      expect(h.doc.locations[id]!.floorNumber, 1);
      expect(h.doc.locations[id]!.spaceCode, 'A');
      // The load-bearing property, as the name field's own case puts it:
      // the edit is a Command, not a poke.
      h.controller.undoLast();
      expect(h.doc.locations[id]!.spaceCode, isNull);
    });

    testWidgets('a basement commits, and the caret survives typing it', (
      tester,
    ) async {
      // WHY THE FLOOR FIELD COMMITS ON BLUR AND THE NAME DOES NOT. `-` is
      // the first keystroke of `-1`, and a per-keystroke parse would
      // refuse it, so a person typing a basement would be told they were
      // wrong before they were finished. Nothing is refused here.
      final h = _Harness();
      final id = await open(tester, h, 'Basement');

      await tester.enterText(find.byKey(ValueKey('floor-${id.v}')), '-');
      await tester.pump();
      expect(h.refusals, isEmpty, reason: 'mid-typing is not an error');

      await tester.enterText(find.byKey(ValueKey('floor-${id.v}')), '-1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(h.doc.locations[id]!.floorNumber, -1);
      expect(h.refusals, isEmpty);
    });

    testWidgets('a floor that is not a number is refused and put back', (
      tester,
    ) async {
      // A box holding text the document does not have is a box the next
      // rebuild silently overwrites. The stored value and the refusal
      // beside it is the only pair that stays true to each other.
      final h = _Harness();
      final id = await open(tester, h, 'Attic');

      await tester.enterText(find.byKey(ValueKey('floor-${id.v}')), '2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.enterText(find.byKey(ValueKey('floor-${id.v}')), 'B');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(h.doc.locations[id]!.floorNumber, 2, reason: 'unchanged');
      expect(h.refusals, hasLength(1));
      expect(h.refusals.single, contains('basement'));
      // The RENDERED text, not the controller behind it: what the user is
      // looking at is the claim, and a box that reads `B` over a document
      // holding `2` is the defect this case exists for.
      expect(
        find.descendant(
          of: find.byKey(ValueKey('floor-${id.v}')),
          matching: find.text('2'),
        ),
        findsOneWidget,
        reason: 'the box shows what the document holds',
      );
    });

    testWidgets('clearing either one stores UNKNOWN, never 0 and never ""', (
      tester,
    ) async {
      // G4 at two fields at once. `0` is a real storey and `''` is a third
      // state every reader downstream would have to guess about, so
      // neither may be what "the user cleared the box" means.
      final h = _Harness();
      final id = await open(tester, h, 'Garage');

      await tester.enterText(find.byKey(ValueKey('floor-${id.v}')), '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.enterText(find.byKey(ValueKey('space-${id.v}')), 'B2');
      await tester.pump();
      expect(h.doc.locations[id]!.floorNumber, 0, reason: 'a measured zero');

      await tester.enterText(find.byKey(ValueKey('floor-${id.v}')), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.enterText(find.byKey(ValueKey('space-${id.v}')), '   ');
      await tester.pump();

      expect(h.doc.locations[id]!.floorNumber, isNull);
      expect(h.doc.locations[id]!.spaceCode, isNull);
    });

    testWidgets("DELETE IS REACHABLE AT THE DIALOG'S REAL SIZE, unscrolled", (
      tester,
    ) async {
      // THE REGRESSION THIS PANE ALREADY SHIPPED ONCE, as an assertion.
      // `showLocationsPanel` mounts a FIXED 720 x 520, and adding two
      // fields pushed `Delete location` out of the detail pane. The three
      // delete cases caught it only because they tap at 800 x 600, which
      // is roomier than production: a pane that fits the test viewport and
      // not the dialog would have passed all of them.
      //
      // So this mounts the real geometry and taps with no scrolling at
      // all. It fails the moment a field pushes the button off again, and
      // it is why the button lives outside the scroll view.
      final h = _Harness();
      final id = h.seed('Living Room');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 720,
                height: 520,
                child: LocationsPanel(doc: h.doc, actions: h.actions),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Living Room'));
      await tester.pump();

      // AN ANTI-VACUITY GUARD, and §3.5's C2 case is why it is an
      // assertion rather than a comment. If the fields happened to FIT at
      // 720 x 520 this case would pass with the pinned button deleted, and
      // would go on passing until the pane grew again. Asserting that the
      // field area really does overflow is what makes the tap below a test
      // of the pinning and not of a coincidence.
      final fields = tester.state<ScrollableState>(
        find
            .ancestor(
              of: find.byKey(ValueKey('parent-${id.v}')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        fields.position.maxScrollExtent,
        greaterThan(0),
        reason: 'the fields must overflow, or this proves nothing',
      );

      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();

      expect(h.doc.locations[id], isNull, reason: 'the tap landed');
    });

    testWidgets('tabbing through the floor field writes nothing', (
      tester,
    ) async {
      // An undo entry per field visited would make Ctrl+Z do nothing
      // visible, once per field somebody looked at.
      final h = _Harness();
      final id = await open(tester, h, 'Office');
      final before = h.controller.doc.locations[id]!.meta.updatedAt;

      await tester.tap(find.byKey(ValueKey('floor-${id.v}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('space-${id.v}')));
      await tester.pump();

      expect(h.doc.locations[id]!.floorNumber, isNull);
      expect(h.doc.locations[id]!.meta.updatedAt, before);
    });
  });

  group('reparenting', () {
    testWidgets('moving a node under another runs one command', (
      tester,
    ) async {
      final h = _Harness();
      final house = h.seed('Main House');
      final living = h.seed('Living Room');
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Living Room'));
      await tester.pump();
      // SCROLLED TO FIRST, because `Inside` is the last field in a pane
      // that scrolls (DR-040 §11.39.4 added a row above it). That is what
      // a person does; a test that assumed a fixed y was asserting the
      // layout while claiming to assert the reparent.
      await tester.ensureVisible(find.byKey(ValueKey('parent-${living.v}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('parent-${living.v}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main House').last);
      await tester.pumpAndSettle();

      expect(h.doc.locations[living]!.parentId, house);
      h.controller.undoLast();
      expect(h.doc.locations[living]!.parentId, isNull);
    });

    testWidgets('a move into its own subtree is not even OFFERED', (
      tester,
    ) async {
      // Filtered out of the dropdown AND still refused by the builder. The
      // second is what matters: a guard that lives only in a dropdown is a
      // guard the next entry point walks straight past.
      final h = _Harness();
      final house = h.seed('Main House');
      h.seed('Living Room', parent: house);
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Main House'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(ValueKey('parent-${house.v}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('parent-${house.v}')));
      await tester.pumpAndSettle();

      // Only `(top level)` remains: the node itself and its one descendant
      // are both excluded.
      expect(find.text('Living Room'), findsOneWidget);
      expect(find.text('(top level)'), findsWidgets);
    });

    testWidgets('a refusal from core reaches the caller as a sentence', (
      tester,
    ) async {
      // The panel does not compose this sentence and must not swallow it.
      // Driven through the actions object rather than the dropdown,
      // because the dropdown deliberately cannot offer the illegal move.
      final h = _Harness();
      final house = h.seed('Main House');
      final living = h.seed('Living Room', parent: house);

      final refusal = h.actions.onReparent(house, living);

      expect(
        refusal,
        'Main House cannot be moved inside Living Room, which is already '
        'inside it.',
      );
      expect(h.doc.locations[house]!.parentId, isNull);
    });
  });

  group('deleting (DR-021)', () {
    testWidgets('a bare leaf is deleted with no confirmation at all', (
      tester,
    ) async {
      final h = _Harness()..seed('Shed');
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Shed'));
      await tester.pump();
      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();

      expect(h.confirmationsAsked, 0);
      expect(h.doc.locations, isEmpty);
    });

    testWidgets('a node with children asks first, and the plan carries the '
        'count', (tester) async {
      final h = _Harness();
      final house = h.seed('Main House');
      h.seed('Living Room', parent: house);
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Main House'));
      await tester.pump();
      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();

      expect(h.confirmationsAsked, 1);
      expect(h.lastPlan!.locationCount, 2);
      expect(h.doc.locations, isEmpty);
    });

    testWidgets('cancelling deletes nothing and keeps the selection', (
      tester,
    ) async {
      final h = _Harness()..confirmAnswer = false;
      final house = h.seed('Main House');
      h.seed('Living Room', parent: house);
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Main House'));
      await tester.pump();
      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();

      expect(h.doc.locations, hasLength(2));
      // The detail pane is still showing the node, so Cancel did not
      // quietly do something.
      expect(find.text('Delete location'), findsOneWidget);
    });

    testWidgets('undo puts the whole subtree back', (tester) async {
      final h = _Harness();
      final house = h.seed('Main House');
      h.seed('Living Room', parent: house);
      await tester.pumpWidget(h.app);

      await tester.tap(find.text('Main House'));
      await tester.pump();
      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();
      expect(h.doc.locations, isEmpty);

      h.controller.undoLast();
      expect(h.doc.locations, hasLength(2));
    });
  });

  group('a document that is not a tree still shows every room', () {
    testWidgets('an orphaned node is listed and flagged, never dropped', (
      tester,
    ) async {
      // A `.rmpj` is hand-editable text (DR-015). The user cannot fix a
      // room they cannot see, so a panel that listed four of five rooms
      // would be the worst possible response to a file needing repair.
      final h = _Harness()..seed('Main House');
      h.doc.locations[const Uuid('orphan')] = Location(
        id: const Uuid('orphan'),
        kind: LocationKind.room,
        name: 'Orphan',
        code: 'OR',
        order: const FracIndex('z0'),
        meta: _meta(),
        parentId: const Uuid('demolished'),
      );

      await tester.pumpWidget(h.app);

      expect(find.text('Orphan'), findsOneWidget);
      expect(find.text('ORPHANED'), findsOneWidget);
    });

    testWidgets('a looping pair is listed and flagged', (tester) async {
      final h = _Harness();
      for (final (id, parent) in [('x', 'y'), ('y', 'x')]) {
        h.doc.locations[Uuid(id)] = Location(
          id: Uuid(id),
          kind: LocationKind.room,
          name: id.toUpperCase(),
          code: id.toUpperCase(),
          order: const FracIndex('a0'),
          meta: _meta(),
          parentId: Uuid(parent),
        );
      }

      await tester.pumpWidget(h.app);

      expect(find.text('LOOPS'), findsNWidgets(2));
    });
  });

  testWidgets('an empty project explains what a location is for', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);

    expect(find.text('No locations yet.'), findsOneWidget);
    await tester.tap(find.text('New location'));
    await tester.pump();

    expect(h.doc.locations, hasLength(1));
  });
}
