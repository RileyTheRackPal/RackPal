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
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  late SchematicScene reference;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
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
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
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
          data.startsWith('TOP-') ||
          // THE SIX TIER-2 IDS, AND THE STATUS LINE'S FORMAT RATHER THAN
          // THE ID ALONE. This filter is a whitelist, so a message it does
          // not know reads as NO MESSAGE AT ALL, which is how a
          // spring-back looked like silence to every assertion here for
          // exactly one run.
          //
          // THE TRAILING SPACE IS LOAD-BEARING. The CHIP renders the bare
          // id as its own label, so `startsWith(id)` matched the chip's
          // badge and this helper started returning 'CON-001' with
          // nothing after it — a status-line reader quietly reading a
          // widget. The status line is `'$ruleId — …'`, so requiring what
          // follows tells the two apart.
          //
          // `kSpringBackRuleIds` is derived from the enum rather than
          // typed, so a seventh rule cannot go unheard the same way.
          kSpringBackRuleIds.any((id) => data.startsWith('$id '))) {
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

  /// Tabs from the ARMED pin until the caret is on a target both
  /// validation tiers accept, and returns how many presses that took.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// ONE `Tab` STOPPED BEING ENOUGH WHEN M5-D SHIPPED
  /// ═══════════════════════════════════════════════════════════════════
  /// Every commit test below pressed `Tab` once, because one press lands
  /// on `_candidates.first`. That candidate is a free pin on `MTX-1`
  /// itself, and `MTX-1` is the seed catalog's V03: sixteen HDMI INPUTS
  /// then sixteen outputs, first four inputs wired. So the armed pin and
  /// the first candidate were both SINKS. **Two inputs with nothing
  /// driving the cable**, which is `DIR-001`, and this suite was asserting
  /// that the gesture made that cable.
  ///
  /// The rule is right and the pin choice was wrong, so this walks to a
  /// pin the rules accept instead of naming one.
  ///
  /// IT READS WHICH PIN IS ARMED OFF THE STATUS LINE rather than assuming
  /// it. The first draft took a designator and used its first free pin,
  /// which is what `caretOnto` lands on — true for the first cable of a
  /// test and false for the second, because a commit parks the caret on
  /// the SINK it just reached. A helper that assumed the caret would have
  /// been silently reasoning about the wrong pin in exactly the test whose
  /// subject is that the caret moves.
  ///
  /// IT REPLICATES THE ARM'S OWN CANDIDATE WALK rather than guessing an
  /// index, because the two must agree about ORDER for a count to mean
  /// anything: same `locatePins` order, same `evaluateConnect`, same
  /// `planSplitsFor` freeing set. `_cycleCandidate` starts at
  /// `_candidates.first` when the caret is not itself a candidate, which
  /// it never is here, so the (k+1)-th press lands on the k-th candidate.
  Future<int> tabToClearTarget(WidgetTester tester, {String? onDevice}) async {
    final said = statusOf(tester) ?? '';
    final scene = buildFixtureScene(doc);

    ConnectTarget? targetOf(PinRef ref) => resolveConnectTarget(
      doc,
      deviceId: Uuid(ref.deviceId),
      portKey: ref.portKey,
    );

    ConnectTarget? fromTarget;
    PinRef? fromRef;
    for (final pin in locatePins(scene)) {
      final t = targetOf(pin.ref);
      if (t == null) continue;
      // TWO SENTENCES NAME AN ARMED PIN, and the helper has to know
      // both: `W` says *"Wire from X ..."* and a chain-draw re-arm says
      // *"... Chained: now drawing from X, N pins can take it."* The
      // first draft knew only the first, so it reported "no wire is
      // armed" on the one gesture whose whole point is that a wire is
      // armed without a `W`.
      //
      // THE TRAILING DELIMITER MATTERS: `MTX-1 J1` is a prefix of
      // `MTX-1 J17`, so a bare `contains` would match the wrong pin on a
      // sixteen-jack device and silently count Tabs from it.
      if (said.startsWith('Wire from ${t.citation} ') ||
          said.contains('now drawing from ${t.citation} ') ||
          said.contains('now drawing from ${t.citation},')) {
        fromTarget = t;
        fromRef = pin.ref;
        break;
      }
    }
    expect(
      fromRef,
      isNotNull,
      reason:
          'no wire is armed, or the status line stopped naming the '
          'pin it armed from: $said',
    );

    var index = 0;
    for (final pin in locatePins(scene)) {
      if (pin.ref == fromRef) continue;
      final to = targetOf(pin.ref);
      if (to == null) continue;
      final freeing = <ConductorRef>{
        for (final split in planSplitsFor(doc, fromTarget!, to))
          split.conductor,
      };
      if (evaluateConnect(doc, fromTarget, to, freeing: freeing)
          is! ConnectAllowed) {
        continue;
      }
      final wanted =
          onDevice == null ||
          doc.devices[Uuid(pin.ref.deviceId)]?.designator == onDevice;
      if (wanted &&
          evaluateSpringBack(doc, fromTarget, to) is SpringBackClear) {
        for (var i = 0; i <= index; i++) {
          await press(tester, LogicalKeyboardKey.tab);
        }
        return index + 1;
      }
      index++;
    }
    throw StateError(
      'no candidate from ${fromTarget!.citation} satisfies both tiers, so '
      'this fixture can no longer demonstrate a keyboard commit at all',
    );
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
        reason:
            "arming NAMES the pin it armed from (DR-011.5's habit, "
            'applied to the affordance and not only to the refusal)',
      );
      expect(
        statusOf(tester),
        contains('can take it'),
        reason:
            'and it says how many pins can take the cable, so the '
            'user knows the mode is worth being in',
      );

      await tabToClearTarget(tester);
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
      await tabToClearTarget(tester);
      await press(tester, LogicalKeyboardKey.enter);

      expect(
        doc.ports.length,
        greaterThan(before),
        reason:
            'a connect to an unmaterialised pin has to create it, or '
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
      await tabToClearTarget(tester);
      await press(tester, LogicalKeyboardKey.enter);

      final link = doc.links.values.last;
      final family = link.services.single.signalFamily;
      expect(
        family,
        isNot(const SignalFamilyId('structure.undetermined')),
        reason:
            'the hardcode put every wire the user drew into the '
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
      await tabToClearTarget(tester);
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

    testWidgets('a RENAME does not move a symbol either (DR-076 §11.75.3)', (
      tester,
    ) async {
      // ═══════════════════════════════════════════════════════════════
      // NEW BEHAVIOUR, AND THE REASON IT BELONGS IN THIS GROUP
      // ═══════════════════════════════════════════════════════════════
      // DR-011.4 froze the sheet for a `wires` bump only. A `meta` bump —
      // a designator typed — took the full path, so Sugiyama ran again and
      // could place the sheet differently while somebody was renaming one
      // device. DR-076 §11.75.3 rules that a rename rebuilds the SYMBOLS
      // and keeps the layout, which makes this the same guarantee one
      // epoch over.
      //
      // The symbol text must still change, or "does not move" would have
      // shipped as "does not update" — the trap the case below this one
      // exists to catch for wires.
      await pump(tester);

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

      bool drawsText(String text) => tester
          .renderObject<RenderSchematicCanvas>(
            find.byType(SchematicCanvasBody),
          )
          .plan
          .ops
          .whereType<OpText>()
          .any((op) => op.text == text);

      // BUILT, NOT WRITTEN OUT: a 180-character literal is a line no
      // formatter can break, and the analyzer ratchet counts it.
      final longName = 'MATRIX-SWITCHER-${'X' * 160}-1';

      final before = origins();
      expect(drawsText('MTX-1'), isTrue, reason: 'the premise');

      controller.run(
        RenameEntityCommand(
          targetKind: RenameTargetKind.device,
          id: deviceNamed(doc, 'MTX-1').id,
          from: 'MTX-1',
          // ABSURDLY LONG ON PURPOSE, AND THAT IS THE FINDING.
          // docs/05 §3 sizes a symbol from its measured text, so only a
          // rename that changes the width can move the layout. VERIFIED BY
          // MUTATION at three lengths, with the reuse removed:
          //
          //   `MTX-9`                        — nothing moves. Same width.
          //   `MATRIX-SWITCHER-MAIN-RACK-1`  — nothing moves either.
          //   this one, ~180 characters      — the sheet moves, and the
          //                                    case fails as it should.
          //
          // So at any designator a person would actually type, a full
          // rebuild and a held layout agree on this fixture, and §11.75.3's
          // reuse is justified by COST rather than by an observed churn.
          // The length here is what makes the guarantee DETECTABLE; a
          // later reader tidying it back to something realistic would
          // leave a case that passes whatever the code does.
          to: longName,
          now: DateTime.utc(2026, 8, 19),
          actor: 'test',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        drawsText(longName),
        isTrue,
        reason: 'the symbols rebuilt, so the new designator is drawn',
      );
      expect(
        origins(),
        before,
        reason:
            'and the layout was kept, so nothing moved under the cursor '
            'of the person who just renamed it',
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
      await tabToClearTarget(tester);
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
        reason:
            'DR-011.5: a sentence naming real designators, never a '
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

      // ═══════════════════════════════════════════════════════════════
      // M5-D SPLIT THIS CLAIM IN TWO, AND ONLY THE TIER-1 HALF SURVIVES
      // ═══════════════════════════════════════════════════════════════
      // This test used to assert that every offered candidate COMMITS.
      // That is DR-011.5 about tier 1 and it still holds. It is not true
      // of tier 2 and was never meant to be: docs/05:476 makes a
      // spring-back target *"droppable"* on purpose, so the gesture
      // offers pins that then hesitate, which is the whole of what the
      // tier exists to do (DR-112 §11.111 on the two tiers answering
      // different questions).
      //
      // So the surviving claim is the sharper one: whichever candidate is
      // chosen, the outcome is one of exactly two, and NEITHER is a
      // tier-1 refusal. Either a cable is made, or a chip says which rule
      // objects and NOTHING IS WRITTEN, which is the half of CR-017 that
      // does not bend.
      var committed = 0;
      var sprangBack = 0;
      for (var round = 0; round < 4; round++) {
        // RE-SEEDED EVERY ROUND, because the two outcomes leave the caret
        // in different places: a commit parks it on the sink it just
        // reached, and a spring-back drops it (the band retracted and the
        // caret went with it, DR-114 §11.113.4). Without this the second
        // round armed from `MTX-1 J01`, a pin the fixture has already
        // filled, and refused for a reason that has nothing to do with
        // what is being tested.
        await caretOnto(tester, 'MTX-1');
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

        final said = statusOf(tester) ?? '';
        expect(
          said,
          isNot(startsWith('TOP-')),
          reason:
              'round $round chose candidate #$round, and a pin the gesture '
              'OFFERED was then refused by TIER 1 — which is the defect '
              'this test has always been about',
        );

        if (doc.links.length == 6) {
          committed++;
          expect(said, contains('connected'));
          controller.undoLast();
          await tester.pumpAndSettle();
          expect(doc.links, hasLength(5));
        } else {
          sprangBack++;
          expect(
            doc.links,
            hasLength(5),
            reason: 'a spring-back writes NOTHING (CR-017)',
          );
          expect(
            said,
            matches(RegExp(r'^(SIG|DIR|CON|ELE)-\d{3} ')),
            reason:
                'and it says WHICH rule, id first, like every other '
                'refusal on this screen (DR-011.5)',
          );
          // Back to aiming for the next round: the chip is up and the
          // wire is still armed (DR-114 §11.113.4), so one Esc closes
          // the chip and a second lets the cable go.
          await press(tester, LogicalKeyboardKey.escape);
          await press(tester, LogicalKeyboardKey.escape);
        }
      }
      expect(
        committed + sprangBack,
        4,
        reason: 'every round ended in one of the two outcomes',
      );
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
        await tabToClearTarget(tester);
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
        reason:
            'the wire is still from MTX-1; the selection is not the '
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
        reason:
            'docs/05 §7: cancel aborts "with no model mutation and no '
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
        reason:
            'a scope vanishing with no explanation is the silent no-op '
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
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
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
      await tabToClearTarget(tester);
      await press(tester, LogicalKeyboardKey.enter);

      expect(doc.links, hasLength(6), reason: 'the premise: it committed');
      expect(
        heard.where((s) => s.contains('cancelled')),
        isEmpty,
        reason:
            "the commit's OWN document change must not be reported to "
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
      //
      // AND IT MUST ALSO CLEAR TIER 2, which the older `tabUntilTarget`
      // could not ask. It stopped at the first target ON the device, and
      // MTX-1's own free INPUTS come before its outputs, so it stopped on
      // a sink-to-sink pair that `DIR-001` now springs back.
      await tabToClearTarget(tester, onDevice: 'MTX-1');
      await chainCommit(tester);

      expect(doc.links, hasLength(6), reason: 'the first cable landed');
      expect(
        statusOf(tester),
        contains('Chained'),
        reason: 'and the same sentence says the gesture continued',
      );

      // NO `W`. Straight to choosing and committing again — and choosing
      // still means a target both tiers accept, because the chain re-armed
      // from an OUTPUT and its first candidate is another of the matrix's
      // own outputs, which is `DIR-001`.
      await tabToClearTarget(tester);
      await press(tester, LogicalKeyboardKey.enter);
      expect(
        doc.links,
        hasLength(7),
        reason:
            'the second cable was drawn without re-arming by hand — '
            'which is the whole of the gesture',
      );
    });

    testWidgets('a PLAIN commit does not chain, so Shift is what asks for '
        'it', (tester) async {
      await pump(tester);
      await caretOnto(tester, 'MTX-1');
      await press(tester, LogicalKeyboardKey.keyW);
      await tabToClearTarget(tester);
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
      await tabToClearTarget(tester, onDevice: 'MTX-1');

      final aimed = statusOf(tester)!;
      final sink = aimed.split('→').last.trim().split(' ').first;
      await chainCommit(tester);
      final said = statusOf(tester)!;

      expect(said, contains('Chained'));
      expect(
        said.substring(said.indexOf('Chained')),
        contains(sink),
        reason:
            'chain-draw re-arms from the SINK, which is what makes a '
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
      await tabToClearTarget(tester);
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
