// M2-F PHASE 2 — the keyboard route to a connection, driven end to end.
//
// THIS SUITE EXISTS BECAUSE THE LAST ONE LIKE IT WAS REFUTED. DR-011's "the
// order that matters" records what happened at M1: the user hit the
// keyboard-only time target and still needed a mouse, because each
// placement made the new device the sole selection and the caret was
// consulted ONLY when the selection was empty. Back-to-back `Enter`s used
// the caret once and then fell back forever. The mechanism read as working
// because its FIRST invocation did.
//
// So the tests below are arranged around that failure shape rather than
// around the feature list. The headline is not "a cable can be drawn" —
// it is "the SECOND cable can be drawn the same way as the first, without
// touching the selection", which is the assertion a single-shot test cannot
// make and the one that would have caught M1.
//
// docs/05 §7's keyboard path: "`Tab` to a port, `W` to begin a wire,
// `Tab`/arrow to a candidate port with the same illumination feedback
// spoken through `Semantics`, `Enter` to commit, `Esc` to cancel."

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late SchematicScene reference;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    doc = buildSchematicTestDocument();
    controller = DocumentController(
      doc,
      clock: FixedClock(DateTime.utc(2026, 7, 29, 9)),
    );
    reference = buildFixtureScene(doc);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchematicCanvasScreen(
            measurer: const FakeMeasurer(),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Matrix4 matrixOf(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .debugSceneToScreen!;

  Offset toScreen(WidgetTester tester, DPt p) {
    final m = matrixOf(tester).storage;
    return tester.getTopLeft(find.byType(SchematicCanvasBody)) +
        Offset(
          m[0] * p.x + m[4] * p.y + m[12],
          m[1] * p.x + m[5] * p.y + m[13],
        );
  }

  DPt centreOf(String designator) {
    final device = deviceNamed(doc, designator);
    final symbol = reference.symbols.firstWhere((s) => s.id == device.id.v);
    return DPt(
      (symbol.bodyRect.left + symbol.bodyRect.right) / 2,
      (symbol.bodyRect.top + symbol.bodyRect.bottom) / 2,
    );
  }

  /// The status line the screen is currently showing, or null.
  ///
  /// THIS IS THE ANNOUNCEMENT CHANNEL, not a decoration.
  /// `StatusMessageController.show` calls `SemanticsService.announce` in
  /// the same breath — it is the only `announce` call site in the
  /// repository — so asserting the text is asserting what a screen reader
  /// says. M2-F's clause is "works end to end WITH SCREEN-READER
  /// ANNOUNCEMENTS", and this is where that is measured.
  String? statusOf(WidgetTester tester) {
    final texts = tester.widgetList<Text>(find.byType(Text));
    for (final text in texts) {
      final data = text.data;
      if (data == null) continue;
      if (data.contains('→') ||
          data.contains('connected') ||
          data.contains('cancelled') ||
          data.contains('Wire from') ||
          data.contains('No pin') ||
          data.contains('No candidate') ||
          data.startsWith('TOP-')) {
        return data;
      }
    }
    return null;
  }

  /// How many of [designator]'s pins, counting down from the top of its
  /// first edge, the fixture has already filled.
  ///
  /// MEASURED, BECAUSE THE HARD-CODED VERSION WAS WRONG THE MOMENT THE
  /// CATALOG WAS FIXED. This was `steps = 1` with a paragraph explaining
  /// that MTX-1's first pin is wired and the second is free. That was true
  /// only because `PortDef.order` was SCRAMBLED: `PortBuilder` emitted
  /// `a0 … a9, a10 …` into a `FracIndex` that sorts as a string, so the
  /// matrix's left edge was drawn `hdmi.in.1, hdmi.in.10, hdmi.in.11 …`
  /// and the pin below the wired one happened to be `hdmi.in.10`, free.
  /// With the order corrected the edge reads `1, 2, 3, 4 …` and the
  /// fixture's four MTX-1 cables fill a contiguous run at the top.
  ///
  /// The old comment said this arrangement was "not a workaround for the
  /// fixture; it is the behaviour under test" and that a fixture change
  /// should "fail loudly instead of quietly aiming somewhere else". It did
  /// fail loudly, which is the good half. The lesson is the other half: a
  /// number derived from the document cannot go stale, and a literal `1`
  /// standing for "how many pins the fixture wired" always can.
  int wiredRunOn(String designator) {
    final device = deviceNamed(doc, designator);
    final symbol = reference.symbols.firstWhere((s) => s.id == device.id.v);
    var n = 0;
    for (final port in symbol.allPorts) {
      final id = derivePortId(device.id, PortKey(port.key));
      if (portConductorCount(doc, id) == 0) break;
      n++;
    }
    return n;
  }

  /// Puts the caret on the first FREE pin of [designator].
  ///
  /// THE FIRST PRESS SEEDS, THE REST STEP. Selecting the device and
  /// pressing an arrow SEEDS the caret onto that device's first pin — the
  /// only place the selection is allowed to influence the caret at all —
  /// and on this fixture that pin heads a run the fixture has already
  /// wired. Each of those carries a cable and `maxConnections` defaults to
  /// 1, so a wire armed from one has no legal target anywhere and the
  /// screen correctly refuses to arm. The remaining presses step past the
  /// run, to the first free pin below it.
  Future<void> caretOnto(
    WidgetTester tester,
    String designator, {
    int? steps,
  }) async {
    final count = steps ?? wiredRunOn(designator);
    await tester.tapAt(toScreen(tester, centreOf(designator)));
    await tester.pumpAndSettle();
    for (var i = 0; i <= count; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
  }

  /// Presses [key] once and settles.
  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  group('1 — the route, end to end', () {
    testWidgets('arrows reach a pin, W arms it, Enter commits ONE link with '
        'ONE undo entry', (tester) async {
      await pump(tester);
      expect(doc.links, hasLength(5), reason: 'the fixture wires five');

      await caretOnto(tester, 'MTX-1');

      await press(tester, LogicalKeyboardKey.keyW);
      expect(
        statusOf(tester),
        contains('Wire from MTX-1'),
        reason: "arming NAMES the pin it armed from (DR-011.5's habit, "
            'applied to the affordance and not only to the refusal)',
      );
      expect(
        statusOf(tester),
        contains('can take it'),
        reason: 'and it says how many pins can take the cable, so the '
            'user knows the mode is worth being in',
      );

      await press(tester, LogicalKeyboardKey.tab);
      expect(statusOf(tester), contains('→'));

      final undoBefore = controller.undo.canUndo;
      await press(tester, LogicalKeyboardKey.enter);

      expect(doc.links, hasLength(6), reason: 'one cable, not two');
      final link = doc.links.values.last;
      expect(link.conductors, hasLength(1));
      expect(link.services, hasLength(1));
      expect(
        doc.nets.containsKey(link.services.single.netId),
        isTrue,
        reason: 'the implicit Net is in the document, not dangling',
      );
      expect(statusOf(tester), contains('connected'));

      // ONE undo entry for one gesture — DR-011.1's reason for
      // materialising ports inside apply() rather than as a sibling
      // command in a transaction.
      expect(undoBefore || controller.undo.canUndo, isTrue);
      controller.undoLast();
      await tester.pumpAndSettle();
      expect(doc.links, hasLength(5));
    });

    testWidgets('the ports it lands on are MATERIALISED by the commit — '
        'DR-011.1, and nothing else in the app does it', (tester) async {
      // The finding that forced DR-011: the only `doc.ports[id] = Port(...)`
      // in the tree is in a BUILD TOOL, so on a document built by placing
      // devices from the palette every port set resolved to all-null
      // members and `planAtomicConnect` returned zero conductors.
      await pump(tester);
      final before = doc.ports.length;

      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.enter);

      expect(
        doc.ports.length,
        greaterThan(before),
        reason: 'a connect to an unmaterialised pin has to create it, or '
            'the conductor lands on an id nothing resolves',
      );
      final link = doc.links.values.last;
      for (final end in [
        link.conductors.single.from,
        link.conductors.single.to,
      ]) {
        expect(end, isA<PortEndpoint>());
        expect(doc.ports.containsKey((end as PortEndpoint).portId), isTrue);
      }
    });

    testWidgets("the link carries the PIN'S family, never "
        'structure.undetermined — DR-011.3', (tester) async {
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.enter);

      final link = doc.links.values.last;
      final family = link.services.single.signalFamily;
      expect(
        family,
        isNot(const SignalFamilyId('structure.undetermined')),
        reason: 'the hardcode put every wire the user drew into the '
            'Structure domain, under a coach mark (AC-048) that teaches '
            'them to filter by domain',
      );
      expect(doc.nets[link.services.single.netId]!.signalFamily, family);
    });
  });

  group('2 — DR-011.4: the sheet holds still', () {
    testWidgets('committing a cable moves NOT ONE symbol', (tester) async {
      await pump(tester);

      /// Every symbol's ORIGIN, read off the bracketing translate the paint
      /// plan emits per symbol.
      ///
      /// NOT THE `OpRect`s, and the first draft of this test made exactly
      /// that mistake: a symbol's fragment is built in LOCAL space with its
      /// body at (0, 0) — `schematic_paint_plan.dart`'s "a symbol fragment
      /// is local; a domain fragment is absolute" — so comparing rects
      /// compares numbers that cannot move however far the symbol does.
      /// The only absolute `OpRect` in the list is the sheet GROUND, which
      /// is `scene.bounds` inflated and is SUPPOSED to grow when a new
      /// cable adds labels. So the draft asserted nothing about symbols and
      /// everything about the one rectangle that legitimately changes.
      ///
      /// NOR EVERY `OpTransform`, which was the second draft and was wrong
      /// for the mirror-image reason: `symbol_layer` brackets each pin's
      /// direction ARROWHEAD in its own save/translate/rotate, so the list
      /// holds 108 transforms of which 104 are local pin geometry that
      /// cannot move either. The four that matter are the ones at SAVE
      /// DEPTH ZERO — the per-symbol brackets the paint plan emits — so
      /// the walk tracks depth rather than filtering by type.
      List<(double, double)> origins() {
        final ops = tester
            .renderObject<RenderSchematicCanvas>(
              find.byType(SchematicCanvasBody),
            )
            .plan
            .ops;
        final out = <(double, double)>[];
        var depth = 0;
        for (var i = 0; i < ops.length; i++) {
          final op = ops[i];
          if (op is OpRestore) {
            depth--;
            continue;
          }
          if (op is! OpSave) continue;
          depth++;
          if (depth != 1) continue;
          final next = i + 1 < ops.length ? ops[i + 1] : null;
          if (next is OpTransform) {
            out.add((next.m.storage[12], next.m.storage[13]));
          }
        }
        return out;
      }

      final before = origins();
      expect(before, hasLength(4), reason: 'four symbols on this fixture');

      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.enter);
      expect(doc.links, hasLength(6), reason: 'the premise: it committed');

      // `AtomicConnectCommand.touches => EpochMask.wires` is what used to
      // make this false: the epoch bumped, the scene cache missed, and
      // Sugiyama ran again over the NEW edge set. docs/05:747 — "auto-layout
      // never fires as a side effect" — was already written; DR-011.4 is
      // what makes it TRUE.
      expect(
        origins(),
        before,
        reason: 'a symbol moved when a cable was created',
      );
    });

    testWidgets('...and the labels DID rebuild — held is not frozen', (
      tester,
    ) async {
      // The other half of the ruling's sentence: "symbol positions freeze;
      // WIRES AND LABELS REBUILD". Without this, "the sheet holds still"
      // could have shipped as "the sheet stops updating" and the new cable
      // would be invisible until something else forced a rebuild.
      await pump(tester);
      int labelOps() => tester
          .renderObject<RenderSchematicCanvas>(
            find.byType(SchematicCanvasBody),
          )
          .plan
          .ops
          .length;

      final before = labelOps();
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.enter);
      expect(labelOps(), greaterThan(before));
    });
  });

  group('3 — DR-011.5: T1 refuses outright, and says which rule', () {
    testWidgets('a FULL pin cannot be armed from at all, and the refusal '
        'carries the designator', (tester) async {
      // TOP-003's bound, reached the way a user reaches it. The seeding
      // press lands the caret on `hdmi.in.1`, which the fixture has
      // already wired and whose effective maxConnections is 1 — so no pin
      // on the sheet can take a second cable from it and the gesture must
      // say so rather than enter a mode with nothing to aim at.
      await pump(tester);
      await caretOnto(tester, 'MTX-1', steps: 0);
      final linksBefore = doc.links.length;
      await press(tester, LogicalKeyboardKey.keyW);

      final said = statusOf(tester);
      expect(said, contains('No pin'));
      expect(
        said,
        contains('MTX-1'),
        reason: 'DR-011.5: a sentence naming real designators, never a '
            "generic string — the user's next action depends on WHICH "
            'pin is full',
      );

      // Nothing armed, so `Enter` behind it writes nothing.
      await press(tester, LogicalKeyboardKey.enter);
      expect(doc.links, hasLength(linksBefore));
    });

    testWidgets('a pin the gesture OFFERS is never then refused, whichever '
        'candidate is chosen', (tester) async {
      // THE INVARIANT BEHIND "Tab only reaches a candidate". The keyboard's
      // equivalent of docs/05 §7's "compatible ports illuminate" is that
      // the caret cannot land on a pin that would refuse — so a commit on
      // an offered pin must succeed. It is not circular: `_beginWire` filters
      // with `evaluateConnect` while the commit goes through
      // `buildConnectPortsCommand`, which ALSO allocates two port
      // designators and a link designator and can fail on its own terms.
      //
      // FOUR ROUNDS, EACH LANDING ON A DIFFERENT CANDIDATE, so the claim is
      // about the LIST and not about the one pin a single-shot test
      // happened to pick. Each round is undone before the next, which is
      // what keeps it deterministic: a commit fills both pins it touches
      // (`maxConnections` defaults to 1), so without the undo the second
      // round would be arming from a pin the first round just used up —
      // a legitimate refusal that would look like a failure here.
      await pump(tester);
      await caretOnto(tester, 'MTX-1');

      for (var round = 0; round < 4; round++) {
        await press(tester, LogicalKeyboardKey.keyW);
        expect(
          statusOf(tester),
          contains('Wire from'),
          reason: 'round $round armed',
        );
        for (var tab = 0; tab <= round; tab++) {
          await press(tester, LogicalKeyboardKey.tab);
        }
        await press(tester, LogicalKeyboardKey.enter);
        expect(
          doc.links,
          hasLength(6),
          reason: 'round $round chose candidate #$round, and a pin that was '
              'OFFERED was then refused',
        );
        expect(statusOf(tester), contains('connected'));

        controller.undoLast();
        await tester.pumpAndSettle();
        expect(doc.links, hasLength(5));
      }
    });

    testWidgets('W on a pin nothing can accept REFUSES to arm, and says '
        'why, naming the pin', (tester) async {
      // Every other pin removed, so the only candidate pool is empty. The
      // gesture must not enter a mode the user cannot aim in.
      await pump(tester);
      controller.transact(LabelKey.removeDevice, (tx) {
        for (final designator in ['AMP-1', 'SW-1', 'DIS-1']) {
          tx.add(RemoveDeviceCommand(id: deviceNamed(doc, designator).id));
        }
      });
      await tester.pumpAndSettle();

      await caretOnto(tester, 'MTX-1');
      final linksBefore = doc.links.length;
      await press(tester, LogicalKeyboardKey.keyW);

      final said = statusOf(tester);
      expect(said, isNotNull, reason: 'never a silent no-op (docs/04 §3.4)');
      expect(said, contains('MTX-1'), reason: 'the sentence names the pin');

      // And `Enter` behind it commits nothing, because nothing armed.
      await press(tester, LogicalKeyboardKey.enter);
      expect(doc.links, hasLength(linksBefore));
    });
  });

  group('4 — the caret is authoritative (the M1 refutation)', () {
    testWidgets('the SECOND cable is drawn exactly like the first, with no '
        'round trip through the selection', (tester) async {
      // THE ASSERTION M1 NEEDED AND DID NOT HAVE. A caret consulted only
      // when the selection is empty works once — the first gesture — and
      // then the commit leaves something selected and every later gesture
      // silently uses that instead. Two cables in a row, driven by the
      // identical key sequence, is the smallest test that can tell the
      // difference.
      //
      // ONE TAP, AT THE VERY START, AND NEVER AGAIN. That is the whole
      // assertion: everything after it is `arrows`, `W`, `Tab`, `Enter`.
      // A caret that fell back to the selection would still produce cable
      // one — the tap seeded it — and would silently re-aim cable two at
      // whatever the commit left selected.
      await pump(tester);
      await caretOnto(tester, 'MTX-1');

      for (var i = 0; i < 2; i++) {
        await press(tester, LogicalKeyboardKey.keyW);
        expect(
          statusOf(tester),
          contains('Wire from'),
          reason: 'cable ${i + 1} armed from the caret',
        );
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.enter);
        expect(
          doc.links,
          hasLength(5 + i + 1),
          reason: 'cable ${i + 1} committed',
        );
        // The commit leaves the caret on the SINK, which it has just
        // filled — so the next cable starts with the same arrow the user
        // would press anyway. Deliberate: the eye is at the sink, and
        // Phase 4's chain-draw re-arms from exactly there.
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
    });

    testWidgets('a selection change does NOT move a caret that already '
        'exists', (tester) async {
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      final armed = statusOf(tester);
      expect(armed, contains('MTX-1'));

      // Click a different device. The armed wire — and the caret it was
      // armed from — must be untouched: a click selects, it does not
      // re-aim a cable the user is holding.
      await tester.tapAt(toScreen(tester, centreOf('AMP-1')));
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.tab);
      expect(
        statusOf(tester),
        contains('MTX-1'),
        reason: 'the wire is still from MTX-1; the selection is not the '
            'caret and must never become it',
      );
    });
  });

  group('5 — Esc is layered, and Tab is only borrowed', () {
    testWidgets('Esc cancels the WIRE first, and leaves the selection and '
        'the focus scope alone', (tester) async {
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyF); // focus MTX-1's subgraph
      await press(tester, LogicalKeyboardKey.keyW);
      expect(statusOf(tester), contains('Wire from'));

      await press(tester, LogicalKeyboardKey.escape);
      expect(
        statusOf(tester),
        contains('cancelled'),
        reason: 'the outermost thing in flight goes first, and says so',
      );

      // The focus scope survived that keystroke: a user holding a
      // half-drawn cable who pressed Esc must not also lose the more
      // expensive of the two states.
      final wires = tester
          .renderObject<RenderSchematicCanvas>(
            find.byType(SchematicCanvasBody),
          )
          .plan
          .ops
          .whereType<OpPolyline>()
          .length;
      expect(
        wires,
        greaterThan(0),
        reason: "focus mode is still drawing MTX-1's links",
      );
    });

    testWidgets('a cancelled wire writes NOTHING — no link, no undo entry', (
      tester,
    ) async {
      await pump(tester);
      final before = controller.undo.canUndo;
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.escape);

      expect(doc.links, hasLength(5));
      expect(doc.ports.length, buildSchematicTestDocument().ports.length);
      expect(
        controller.undo.canUndo,
        before,
        reason: 'docs/05 §7: cancel aborts "with no model mutation and no '
            'undo entry"',
      );
    });

    testWidgets('Tab is handed BACK to focus traversal when no wire is in '
        'flight', (tester) async {
      // THE ACCESSIBILITY HALF, and the reason both Tab rows are gated.
      // The canvas autofocuses; a schematic that owned bare Tab
      // unconditionally would be a surface a keyboard-only user could
      // enter and never leave — which fails the very requirement
      // (AC-058/D11) the keyboard route exists to meet.
      await pump(tester);
      final before = FocusManager.instance.primaryFocus;
      await press(tester, LogicalKeyboardKey.tab);
      expect(
        FocusManager.instance.primaryFocus,
        isNot(same(before)),
        reason: 'an idle sheet does not consume Tab',
      );
    });
  });

  group('6 — a document change under a live wire tears it down, out loud', () {
    testWidgets('the gesture is dropped whole and the reason is said', (
      tester,
    ) async {
      // `_candidates` is a set of VERDICTS computed against a document
      // state that no longer exists, and a stale one is wrong in the
      // direction that says yes. Repairing it silently would continue a
      // gesture whose premise the user was shown and can no longer trust.
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      expect(statusOf(tester), contains('Wire from'));

      controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'SW-1').id));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Wire cancelled'),
        findsOneWidget,
        reason: 'a scope vanishing with no explanation is the silent no-op '
            'docs/04 §3.4 forbids',
      );

      // And the wire really is gone: Enter commits nothing.
      final links = doc.links.length;
      await press(tester, LogicalKeyboardKey.enter);
      expect(doc.links, hasLength(links));
    });
  });

  group('7 — what a SCREEN READER actually hears', () {
    /// Every `SemanticsService.announce` this screen makes, in order.
    ///
    /// M2-F's clause is "works end to end WITH SCREEN-READER
    /// ANNOUNCEMENTS", and `find.text` cannot measure that: the status
    /// line shows the LAST message, while a screen reader hears EVERY
    /// one. A message that is instantly overwritten on screen is still
    /// spoken in full.
    List<String> spoken(WidgetTester tester) {
      final out = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<
        Object?
      >(SystemChannels.accessibility, (message) async {
        if (message is Map && message['type'] == 'announce') {
          final data = message['data'] as Map?;
          final text = data?['message'];
          if (text is String) out.add(text);
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      return out;
    }

    testWidgets('a successful commit is announced ONCE, and never as a '
        'cancellation', (tester) async {
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);

      final heard = spoken(tester);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.enter);

      expect(doc.links, hasLength(6), reason: 'the premise: it committed');
      expect(
        heard.where((s) => s.contains('cancelled')),
        isEmpty,
        reason: "the commit's OWN document change must not be reported to "
            'the user as the edit that cancelled their wire — they are '
            'told it succeeded and, one message earlier, that it was '
            'thrown away',
      );
      expect(heard.where((s) => s.contains('connected')), hasLength(1));
    });

    testWidgets('a cancellation caused by SOMEBODY ELSE is still '
        'announced', (tester) async {
      // The other half, and the reason the fix is a latch rather than
      // deleting the teardown message: an edit from another view really
      // does invalidate the wire, and saying nothing would be the silent
      // no-op docs/04 §3.4 forbids.
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);

      final heard = spoken(tester);
      controller.run(RemoveDeviceCommand(id: deviceNamed(doc, 'SW-1').id));
      await tester.pumpAndSettle();

      expect(heard.where((s) => s.contains('cancelled')), hasLength(1));
    });
  });

  group('8 — chain-draw (docs/05:482, DR-012.1)', () {
    /// Commits with `Shift` held — docs/05:483's "Shift held at commit".
    /// A SEPARATE keymap row from bare Enter, because `SingleActivator`
    /// matches modifiers exactly and the bare row would not fire.
    Future<void> chainCommit(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
    }

    /// Tabs through the candidate ring until the live resolution line
    /// names [designator] as the TARGET.
    ///
    /// Needed because "which pin is candidate #1" is a property of the
    /// fixture's layout, and the first draft of these tests aimed at
    /// whatever came first — which was SW-1, a network switch with no
    /// HDMI output, so every chain correctly ENDED and no test ever
    /// exercised one continuing.
    Future<bool> tabUntilTarget(
      WidgetTester tester,
      String designator,
    ) async {
      for (var i = 0; i < 60; i++) {
        await press(tester, LogicalKeyboardKey.tab);
        final now = statusOf(tester);
        if (now != null && now.contains('→ $designator')) return true;
      }
      return false;
    }

    testWidgets('Shift at commit RE-ARMS from the sink device, so the next '
        'cable needs no W at all', (tester) async {
      // "ATV-1 -> MTX-1 IN1, MTX-1 OUT1 -> DA-1 IN, DA-1 OUT1 -> TV is
      // three gestures with no round trip through IDLE" (docs/05:482). The
      // assertion is that the SECOND cable commits without pressing W.
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      // AIMED AT MTX-1 ITSELF, deliberately. A chain can only continue
      // where the SINK has a free output of the same family, and on this
      // fixture the matrix is the device that does — a loopback between
      // two of its own jacks is legal (only pin-to-ITSELF is not) and is
      // the deterministic way to reach a sink that chains.
      expect(await tabUntilTarget(tester, 'MTX-1'), isTrue);
      await chainCommit(tester);

      expect(doc.links, hasLength(6), reason: 'the first cable landed');
      expect(
        statusOf(tester),
        contains('Chained'),
        reason: 'and the same sentence says the gesture continued',
      );

      // NO `W`. Straight to choosing and committing again.
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.enter);
      expect(
        doc.links,
        hasLength(7),
        reason: 'the second cable was drawn without re-arming by hand — '
            'which is the whole of the gesture',
      );
    });

    testWidgets('a PLAIN commit does not chain, so Shift is what asks for '
        'it', (tester) async {
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.enter);

      expect(statusOf(tester), isNot(contains('Chained')));
      await press(tester, LogicalKeyboardKey.enter);
      expect(doc.links, hasLength(6), reason: 'nothing was armed to commit');
    });

    testWidgets('the re-arm is on the device the cable just REACHED', (
      tester,
    ) async {
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      expect(await tabUntilTarget(tester, 'MTX-1'), isTrue);

      final aimed = statusOf(tester)!;
      final sink = aimed.split('→').last.trim().split(' ').first;
      await chainCommit(tester);
      final said = statusOf(tester)!;

      expect(said, contains('Chained'));
      expect(
        said.substring(said.indexOf('Chained')),
        contains(sink),
        reason: 'chain-draw re-arms from the SINK, which is what makes a '
            'chain a chain rather than a repeat',
      );
    });

    testWidgets('a chained commit is ONE announcement, not three', (
      tester,
    ) async {
      // The commit, the teardown and the re-arm are three internal events
      // and ONE user action. `_committingWire` suppresses the teardown's
      // message and `announce: false` suppresses the re-arm's, leaving a
      // single sentence that covers all of it.
      final heard = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            if (message is Map && message['type'] == 'announce') {
              final data = message['data'] as Map?;
              final text = data?['message'];
              if (text is String) heard.add(text);
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );

      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      await press(tester, LogicalKeyboardKey.tab);
      heard.clear();
      await chainCommit(tester);
      // Either outcome is one sentence; which one depends on the sink.

      expect(heard, hasLength(1));
      expect(heard.single, contains('connected'));
      expect(
        heard.single,
        anyOf(contains('Chained'), contains('chain ends')),
      );
      expect(heard.single, isNot(contains('cancelled')));
    });
  });
}
