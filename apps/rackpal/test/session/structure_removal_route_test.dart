// `#877`, DR-160 §11.159 — a plate and a panel can be removed, and the
// route from the control to the document is the real one.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS SEPARATELY FROM THE WIDGET TESTS
// ═════════════════════════════════════════════════════════════════════
// `outlets_view_test.dart` proves the rail's trash icon calls its host
// with the right plate, and `structure_editor_screen_test.dart` proves
// the header menu calls its host with the right body. Both harnesses
// SUPPLY THOSE CALLBACKS THEMSELVES, so what happens next was covered by
// nobody. That is the exact hole `#879`'s second mutation opened: a
// widget test passing its own actor cannot see a shell that hands over
// none.
//
// So this drives the APP: the real tab, the real confirmation, the real
// `DocumentController` and the real undo stack.
//
// ═════════════════════════════════════════════════════════════════════
// AND `#872` CANNOT SEE THIS EITHER
// ═════════════════════════════════════════════════════════════════════
// The reachability gate proves a PATH from a declaration in `lib/` to
// each command. It cannot prove the path runs, or that the confirmation
// the person answered is the plan the transaction consumed. A green gate
// over a control that opens a dialog and then removes the wrong plate is
// exactly the shape it is blind to.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal/src/session/blank_document.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'session_fakes.dart';

final _when = DateTime.utc(2026, 9, 13);

/// A blank project with one Structure body, two rooms and three drops
/// across two plates.
///
/// BUILT THROUGH THE REAL PLANNER, not by hand: `planDropLine` is what
/// the quick-add bar runs, so the plates, their designations and the
/// `structureOrigin` on every drop are the ones a person would actually
/// have produced. A hand-built fixture is where a removal test can agree
/// with itself about a shape the product never makes.
({RackDocument doc, Uuid bodyId}) _project() {
  final doc = buildBlankDocument(now: _when, appVersion: '0.1.0');
  for (final (name, code) in [('Living Room', 'LR'), ('Kitchen', 'KIT')]) {
    AddLocationCommand(
      name: name,
      code: code,
      order: nextLocationOrder(doc),
      now: _when,
      actor: 'test',
    ).apply(doc);
  }

  final add = AddStructureCommand(
    title: 'Rough-In',
    designator: allocateStructureDesignator(doc: doc),
    now: _when,
    actor: 'test',
  )..apply(doc);

  for (final line in ['Living Room: 2x Cat6', 'Kitchen: 1x Cat6']) {
    final parsed = parseDropLine(line) as DropLineParsed;
    final plan = planDropLine(
      doc: doc,
      structureBodyId: add.bodyId,
      line: parsed,
      now: _when,
      actor: 'test',
    );
    for (final command in (plan as DropLinePlanReady).commands) {
      command.apply(doc);
    }
  }

  return (doc: doc, bodyId: add.bodyId);
}

/// The plate the planner made for [room], found through its location.
Outlet _plateIn(RackDocument doc, String room) => doc.outlets.values.firstWhere(
  (o) => doc.locations[o.locationId]?.name == room,
);

void main() {
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
      ..physicalSize = const Size(1600, 1400)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> openOutletsTab(WidgetTester tester) async {
    await tester.tap(find.text(ShellView.structuredWiring.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kOutletsTabLabel));
    await tester.pumpAndSettle();
  }

  group('the plate, from the rail (§11.159.2)', () {
    testWidgets('the trash icon asks first, and Cancel takes nothing', (
      tester,
    ) async {
      final fixture = _project();
      final built = await buildTestApp(measurer, document: fixture.doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final doc = built.session.services.session.document;
      final plate = _plateIn(doc, 'Living Room');

      await openOutletsTab(tester);
      await tester.tap(find.byKey(ValueKey(outletRemoveKeyFor(plate.id))));
      await tester.pumpAndSettle();

      // THE COUNT IS THE POINT OF THE DIALOG (DR-013 §11.13.2), and it is
      // the number the transaction will consume rather than a second walk
      // over the same document.
      expect(
        find.text(
          'This also deletes the 2 cables that land on it, off the '
          'schedule.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(doc.outlets.containsKey(plate.id), isTrue);
      expect(doc.links, hasLength(3));
    });

    testWidgets('Remove takes the plate and its cables, and no others', (
      tester,
    ) async {
      final fixture = _project();
      final built = await buildTestApp(measurer, document: fixture.doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final doc = built.session.services.session.document;
      final plate = _plateIn(doc, 'Living Room');
      final kitchen = _plateIn(doc, 'Kitchen');

      await openOutletsTab(tester);
      await tester.tap(find.byKey(ValueKey(outletRemoveKeyFor(plate.id))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RemoveOutletDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(doc.outlets.containsKey(plate.id), isFalse);
      expect(doc.outlets.containsKey(kitchen.id), isTrue);
      expect(doc.links, hasLength(1));
      expect(
        doc.links.values.single.structureOrigin!.outletId,
        kitchen.id,
        reason: 'the other room keeps its plate and its drop',
      );
    });

    testWidgets('and the Edit menu says what it will take back', (
      tester,
    ) async {
      // `#874`'s machinery meeting `#877`'s gesture. The whole cascade is
      // ONE entry (§11.159.7) and it is named for what the person did,
      // not for the cables that went with it.
      final fixture = _project();
      final built = await buildTestApp(measurer, document: fixture.doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final doc = built.session.services.session.document;
      final plate = _plateIn(doc, 'Living Room');

      await openOutletsTab(tester);
      await tester.tap(find.byKey(ValueKey(outletRemoveKeyFor(plate.id))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RemoveOutletDialog.confirmKey));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Undo Remove outlet'), findsOneWidget);

      await tester.tap(find.text('Undo Remove outlet'));
      await tester.pumpAndSettle();
      expect(doc.outlets.containsKey(plate.id), isTrue);
      expect(
        doc.links,
        hasLength(3),
        reason: 'one undo puts the cables back too (DR-013 §11.13.4)',
      );
    });
  });

  group('the panel, from the header menu (§11.159.3)', () {
    testWidgets('the overflow menu removes the body, its plates and its '
        'cables', (tester) async {
      final fixture = _project();
      final built = await buildTestApp(measurer, document: fixture.doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final doc = built.session.services.session.document;

      await tester.tap(find.text(ShellView.structuredWiring.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kStructureHeaderMenuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kRemoveStructureLabel));
      await tester.pumpAndSettle();

      // Two plates, three cables, and the title is the header's own
      // spelling of the body.
      expect(find.text('Remove STR-1 · Rough-In?'), findsOneWidget);
      expect(
        find.text('This also deletes the 2 plates on it.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'The 3 cables out of this panel go with it, off the '
          'schedule.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(RemoveStructureDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(doc.structures, isEmpty);
      expect(
        doc.devices,
        isEmpty,
        reason: 'the paired device goes with the body, never alone',
      );
      expect(doc.outlets, isEmpty);
      expect(doc.links, isEmpty);
    });

    testWidgets('one undo puts the whole panel back', (tester) async {
      final fixture = _project();
      final built = await buildTestApp(measurer, document: fixture.doc);
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();
      final doc = built.session.services.session.document;

      await tester.tap(find.text(ShellView.structuredWiring.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kStructureHeaderMenuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kRemoveStructureLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RemoveStructureDialog.confirmKey));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SubmenuButton, 'Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Undo Remove structure'), findsOneWidget);
      await tester.tap(find.text('Undo Remove structure'));
      await tester.pumpAndSettle();

      expect(doc.structures, hasLength(1));
      expect(doc.outlets, hasLength(2));
      expect(doc.links, hasLength(3));
    });

    testWidgets('the menu is ABSENT on a project with no Structure device', (
      tester,
    ) async {
      // DR-091's rule at the size of one item: a control with nothing to
      // act on is absent rather than present and inert. The quick-add
      // loop is what offers to create a body, and this tab opens on it.
      final built = await buildTestApp(
        measurer,
        document: buildBlankDocument(now: _when, appVersion: '0.1.0'),
      );
      await tester.pumpWidget(built.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text(ShellView.structuredWiring.label));
      await tester.pumpAndSettle();

      expect(find.byKey(kStructureHeaderMenuKey), findsNothing);
    });
  });

  testWidgets('THE DOCUMENT IS NOT FROZEN WHILE THE DIALOG IS OPEN, and the '
      'removal follows the LIVE one', (tester) async {
    // ═════════════════════════════════════════════════════════════════
    // THE RE-PLAN SURVIVED A MUTATION AND IS REACHABLE, WHICH IS RARE
    // ═════════════════════════════════════════════════════════════════
    // `_removeOutlet` plans twice: once for the sentence the person
    // answers, once for the edit that runs. Replacing the second with the
    // first survived, so nothing saw the difference, and the first
    // question to ask a survivor is whether the branch is reachable at
    // all (`a-guard-the-model-makes-unreachable.md`).
    //
    // **IT IS, AND `#874` IS WHY.** Undo moved to `KeyScope.global` with
    // its `Shortcuts` above the `Navigator`, so `Ctrl+Z` reaches
    // `undoFromShell` from inside a modal route: probed here, the
    // document went from 2 links to 3 with the confirmation still up.
    // Before that ruling the key was per-canvas and a dialog had nothing
    // above it to reach.
    //
    // **THE STALE COUNT IS THE COST AND IT IS THE SMALLER ONE.** The
    // dialog said one cable and two go. The alternative leaves the
    // restored drop naming a plate that is gone, which is the state
    // §11.159.2 exists to prevent, and `_removeTemplate` already
    // recorded the choice: remove what is actually there rather than what
    // was there a moment ago.
    final fixture = _project();
    final built = await buildTestApp(measurer, document: fixture.doc);
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    final session = built.session.services.session;
    final doc = session.document;
    final plate = _plateIn(doc, 'Living Room');
    final going = doc.links.values.firstWhere(
      (l) => l.structureOrigin?.outletId == plate.id,
    );

    // A drop deleted from the table, which is an ordinary edit and the
    // only thing here that needs to be undoable.
    session.controller.transact(LabelKey.removeLink, (tx) {
      tx.add(
        RemoveLinkCommand(
          id: going.id,
          netId: netToRemoveWith(session.controller.doc, going.id),
        ),
      );
    });
    await tester.pumpAndSettle();

    await openOutletsTab(tester);
    await tester.tap(find.byKey(ValueKey(outletRemoveKeyFor(plate.id))));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This also deletes the 1 cable that lands on it, off the schedule.',
      ),
      findsOneWidget,
      reason: 'the sentence describes the document as it stands right now',
    );

    // And then it does not stand that way any more.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      doc.links,
      hasLength(3),
      reason: 'Ctrl+Z reached the shell from inside the modal route',
    );

    await tester.tap(find.byKey(RemoveOutletDialog.confirmKey));
    await tester.pumpAndSettle();

    // THE INVARIANT, NOT THE COUNT. A link naming an outlet this document
    // no longer holds is the one outcome §11.159.2 forbids, and it is
    // what running the answered plan would have produced.
    for (final link in doc.links.values) {
      final outletId = link.structureOrigin?.outletId;
      if (outletId != null) {
        expect(
          doc.outlets.containsKey(outletId),
          isTrue,
          reason: 'no cable may be left naming a plate that is gone',
        );
      }
    }
    expect(doc.outlets.containsKey(plate.id), isFalse);
    expect(doc.links, hasLength(1), reason: 'both of its drops went');
  });
}
