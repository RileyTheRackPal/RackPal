// M3-B/2, #145 — what `Project ▸ Locations…` means in commands, and that
// the menu item reaches it.
//
// TWO LEVELS, because they can fail independently. The first half drives
// `buildLocationsPanelActions` directly: it is the translation from the
// panel's five gestures into commands, and it is the only place the
// document's clock, actor and undo stack are involved. The second half
// taps the real menu in the real shell, because a perfect wiring nothing
// opens is the shape M2-F found on `doc.ports` and M3-A/1 found on
// `StructureBody`: a mechanism no gesture reaches.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate/src/session/app_shell.dart';
import 'package:rackmate/src/session/locations_actions.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'session_fakes.dart';

final _when = DateTime.utc(2026, 8, 6);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// A FIXED clock, so "the wiring reads the injected clock" is a property a
/// test can state at all. Against `SystemClock` the assertion below would
/// compare two wall-clock reads a millisecond apart and fail at random.
final _clock = FixedClock(_when);

DocumentController _controller() => DocumentController(
  RackDocument(
    id: const Uuid('doc-locations-actions'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  ),
  clock: _clock,
);

void main() {
  group('buildLocationsPanelActions', () {
    late DocumentController controller;
    late List<String> refusals;
    late List<LocationRemovalPlan> confirmed;
    late bool answer;

    LocationsPanelActions build() => buildLocationsPanelActions(
      controller: controller,
      confirmRemoval: (plan, name) async {
        confirmed.add(plan);
        return answer;
      },
      onRefuse: refusals.add,
    );

    (int, int) countsOf(LocationRemovalPlan plan) => (
      plan.locationCount,
      plan.referenceCount,
    );

    setUp(() {
      controller = _controller();
      refusals = [];
      confirmed = [];
      answer = true;
    });

    test('creating runs a command, so undo removes the location', () {
      final actions = build();
      final id = actions.onAdd(null);

      expect(controller.doc.locations[id]!.name, kNewLocationName);
      controller.undoLast();
      expect(controller.doc.locations, isEmpty);
    });

    test('a new location has NO code, because {ROOM_ABBR} reads it', () {
      // A code derived from "New location" would put `NE` on real printed
      // labels the moment someone renamed the room and did not think to
      // look at the field beneath it.
      final id = build().onAdd(null);

      expect(controller.doc.locations[id]!.code, isEmpty);
    });

    test('creating under a parent nests, and the order is per sibling', () {
      final actions = build();
      final house = actions.onAdd(null);
      final first = actions.onAdd(house);
      final second = actions.onAdd(house);

      final tree = LocationTree.of(controller.doc);
      expect(tree.childrenOf(house), [first, second]);
    });

    test('every timestamp comes from the injected clock, never wall time', () {
      // The property that makes the app's tests time-independent. A
      // `DateTime.now()` in the wiring would be invisible until a golden
      // or a byte comparison started failing at midnight.
      final id = build().onAdd(null);

      expect(controller.doc.locations[id]!.meta.createdAt, _when);
    });

    test('renaming coalesces into one undo entry, per property', () {
      // `SetEntityPropertyCommand.mergeKey` is per property per entity, so
      // typing a room name is ONE undo entry rather than one per keystroke.
      final actions = build();
      final id = actions.onAdd(null);
      final depth = controller.undo.depth;

      for (final text in ['L', 'Li', 'Liv', 'Living Room']) {
        actions.onRename(id, text);
      }

      expect(controller.doc.locations[id]!.name, 'Living Room');
      expect(controller.undo.depth, depth + 1);
    });

    test('setting a field to what it already holds pushes nothing', () {
      final actions = build();
      final id = actions.onAdd(null);
      final depth = controller.undo.depth;

      actions.onRename(id, kNewLocationName);

      expect(controller.undo.depth, depth);
    });

    test('a legal reparent returns null and runs a command', () {
      final actions = build();
      final house = actions.onAdd(null);
      final living = actions.onAdd(null);

      expect(actions.onReparent(living, house), isNull);
      expect(controller.doc.locations[living]!.parentId, house);
      controller.undoLast();
      expect(controller.doc.locations[living]!.parentId, isNull);
    });

    test('a cycle comes back as DR-021 §11.20.5’s sentence, unrewritten', () {
      // Passed through rather than composed here. A shell that rewrote it
      // into "Cannot move location" would throw away the part naming which
      // two nodes are the problem.
      final actions = build();
      final house = actions.onAdd(null);
      final living = actions.onAdd(house);
      actions
        ..onRename(house, 'Main House')
        ..onRename(living, 'Living Room');

      expect(
        actions.onReparent(house, living),
        'Main House cannot be moved inside Living Room, which is already '
        'inside it.',
      );
      expect(controller.doc.locations[house]!.parentId, isNull);
    });

    test('a no-op reparent is null, the same as success', () {
      // `Unchanged` and `Ready` both mean "nothing to say to the user".
      // Only `Refused` carries a sentence, which is why the return type is
      // a nullable string rather than a nullable command.
      final actions = build();
      final house = actions.onAdd(null);
      final living = actions.onAdd(house);

      expect(actions.onReparent(living, house), isNull);
      expect(refusals, isEmpty);
    });

    test('a costless delete hands over a plan that needs no confirming', () {
      // THE CHECK LIVES IN `confirmLocationRemoval`, not here, exactly as
      // `confirmDeviceRemoval` owns it for a device (DR-013 §11.13.2's
      // "a device carrying nothing is deleted with no prompt at all").
      // What this level owes is that the plan it hands over says so, and
      // `delete_location_dialog_test` asserts the helper honours it.
      final actions = build();
      final id = actions.onAdd(null);

      expect(actions.onDelete(id), completion(isTrue));
      expect(confirmed.single.needsConfirmation, isFalse);
      expect(countsOf(confirmed.single), (1, 0));
    });

    test(
      'a delete that costs is confirmed with the plan’s own counts',
      () async {
        final actions = build();
        final house = actions.onAdd(null);
        actions.onAdd(house);
        controller.doc.racks[const Uuid('rk')] = Rack(
          id: const Uuid('rk'),
          name: 'Rack',
          designator: 'RK-1',
          heightU: 42,
          order: const FracIndex('a0'),
          meta: _meta(),
          locationId: house,
        );

        expect(await actions.onDelete(house), isTrue);

        expect(confirmed.single.needsConfirmation, isTrue);
        expect(countsOf(confirmed.single), (2, 1));
        expect(controller.doc.locations, isEmpty);
        // DR-021 §11.20.6: the rack stays, and simply has no room.
        expect(controller.doc.racks, hasLength(1));
        expect(controller.doc.racks[const Uuid('rk')]!.locationId, isNull);
      },
    );

    test('declining the confirmation changes nothing at all', () async {
      answer = false;
      final actions = build();
      final house = actions.onAdd(null);
      actions.onAdd(house);
      final depth = controller.undo.depth;

      expect(await actions.onDelete(house), isFalse);
      expect(controller.doc.locations, hasLength(2));
      expect(controller.undo.depth, depth);
    });

    test('deleting a location that is already gone is false, not a throw', () {
      // A stale selection, or a second delete arriving after an undo.
      expect(build().onDelete(const Uuid('ghost')), completion(isFalse));
    });

    test('undo restores the whole subtree AND the rack’s room', () async {
      final actions = build();
      final house = actions.onAdd(null);
      actions.onAdd(house);
      controller.doc.racks[const Uuid('rk')] = Rack(
        id: const Uuid('rk'),
        name: 'Rack',
        designator: 'RK-1',
        heightU: 42,
        order: const FracIndex('a0'),
        meta: _meta(),
        locationId: house,
      );

      await actions.onDelete(house);
      controller.undoLast();

      expect(controller.doc.locations, hasLength(2));
      expect(controller.doc.racks[const Uuid('rk')]!.locationId, house);
    });
  });

  group('the view that reaches it', () {
    late TextMeasurer measurer;

    setUpAll(() {
      final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
      measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
        const FontRef('Jost'): bytes,
      });
    });

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .implicitView!
        ..physicalSize = const Size(1600, 1000)
        ..devicePixelRatio = 1;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .implicitView!
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    testWidgets('the Locations TAB reaches the panel (CR-112, DR-091)', (
      tester,
    ) async {
      // The claim is unchanged and is the one that matters: the panel is
      // REACHABLE. A wiring nothing opens is the shape M2-F found on
      // `doc.ports`. What changed is the route, not the claim: DR-091
      // §11.90 made this a view, and `Project ▸ Locations…` is gone
      // because two routes to one surface is two things to keep true.
      final built = await buildTestApp(measurer);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();

      expect(
        find.text('Project'),
        findsNothing,
        reason: 'the Project menu held only views and went with them',
      );

      await tester.tap(find.text(ShellView.locations.label));
      await tester.pumpAndSettle();

      expect(find.byType(LocationsPanel), findsOneWidget);
    });

    testWidgets('a location created there lands in the real document', (
      tester,
    ) async {
      final built = await buildTestApp(measurer);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text(ShellView.locations.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New location'));
      await tester.pumpAndSettle();

      expect(
        built.session.services.session.document.locations.values.where(
          (l) => l.name == kNewLocationName,
        ),
        hasLength(1),
      );
    });
  });
}
