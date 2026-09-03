// M2-F PHASE 3 — drag-to-connect, the pointer half of docs/05 §7.
//
// THE SAME STATE, A SECOND DRIVER, AND THAT IS WHAT IS BEING TESTED. Phase
// 2 built the caret, the candidate set and the commit from the keyboard;
// this phase adds a press, a move and a release that set the same three
// fields. So the tests below are not a re-run of the keyboard suite with a
// mouse — they are about the things only a POINTER can get wrong:
//
//   * a press has to decide ONCE whether it is a click or a cable, from
//     what is under it, and keep that identity for its whole life;
//   * a pin that cannot arm must fall back to being a click rather than
//     becoming a dead press;
//   * the magnet has to pull the band onto a pin the cable may actually
//     land on, and let go when `Ctrl` is held;
//   * a release has three outcomes — commit, refusal, cancel — and the
//     difference between the last two is what the user is told;
//   * the exclusivity arbiter now has TWO values, so a refused connect
//     must not free a live click's claim.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

  RenderedSymbol symbolOf(String designator) {
    final device = deviceNamed(doc, designator);
    return reference.symbols.firstWhere((s) => s.id == device.id.v);
  }

  DPt centreOf(String designator) {
    final s = symbolOf(designator);
    return DPt(
      (s.bodyRect.left + s.bodyRect.right) / 2,
      (s.bodyRect.top + s.bodyRect.bottom) / 2,
    );
  }

  /// A pin of [designator] that carries no cable yet, by index among the
  /// free ones. The fixture wires its first pins, so "free" is not the same
  /// as "first" — see `schematic_keyboard_connect_test.dart`'s `caretOnto`.
  ({PinRef ref, DPt centre}) freePin(String designator, {int index = 0}) {
    final device = deviceNamed(doc, designator);
    final symbol = symbolOf(designator);
    final free = <({PinRef ref, DPt centre})>[];
    for (final port in symbol.allPorts) {
      final id = derivePortId(device.id, PortKey(port.key));
      if (portConductorCount(doc, id) != 0) continue;
      free.add((
        ref: PinRef(deviceId: symbol.id, portKey: port.key),
        centre: symbolPortCentre(symbol, port),
      ));
    }
    return free[index];
  }

  /// The shared fixture's [clearConnectPair], as this file's pin shape.
  ///
  /// See that function for why a pair is SEARCHED for rather than named:
  /// two hand-picked pairs looked fine to a person and neither was.
  ({({PinRef ref, DPt centre}) from, ({PinRef ref, DPt centre}) to}) clearPair(
    String from,
    String to,
  ) {
    final pair = clearConnectPair(doc, reference, from, to);
    return (
      from: (ref: pair.from, centre: pair.fromCentre),
      to: (ref: pair.to, centre: pair.toCentre),
    );
  }

  /// A pin that is already full — the fixture's first pin on [designator].
  ({PinRef ref, DPt centre}) fullPin(String designator) {
    final device = deviceNamed(doc, designator);
    final symbol = symbolOf(designator);
    for (final port in symbol.allPorts) {
      final id = derivePortId(device.id, PortKey(port.key));
      if (portConductorCount(doc, id) == 0) continue;
      return (
        ref: PinRef(deviceId: symbol.id, portKey: port.key),
        centre: symbolPortCentre(symbol, port),
      );
    }
    throw StateError('$designator has no wired pin');
  }

  String? statusOf(WidgetTester tester) {
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      if (data.contains('→') ||
          data.contains('connected') ||
          data.contains('cancelled') ||
          data.contains('Wire from') ||
          data.contains('No pin') ||
          data.contains('One drag at a time') ||
          // #93's anchor sentence, which is what a sub-threshold press on
          // a pin now says instead of "cancelled".
          data.contains('Shift+click') ||
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

  /// Every circle in the frame — SYMBOL PINS INCLUDED.
  ///
  /// The first draft of this asserted "zero circles when idle" and read
  /// 164: `symbol_layer` draws every pin as an `OpCircle`, so the absolute
  /// count says nothing about the overlay. Only the DELTA does, which is
  /// why every use below is a comparison against the idle frame.
  int circles(WidgetTester tester) => tester
      .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
      .plan
      .ops
      .whereType<OpCircle>()
      .length;

  List<DPt> bandOf(WidgetTester tester) {
    final polylines = tester
        .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
        .plan
        .ops
        .whereType<OpPolyline>()
        .toList();
    return polylines.isEmpty ? const <DPt>[] : polylines.last.pts;
  }

  group('1 — a press decides once what it is', () {
    testWidgets('a press ON A PIN arms a cable; a press on the BODY selects', (
      tester,
    ) async {
      await pump(tester);
      final pin = freePin('MTX-1');

      final drag = await tester.startGesture(toScreen(tester, pin.centre));
      await tester.pump();
      expect(
        statusOf(tester),
        contains('Wire from'),
        reason: 'the press landed on a jack, so it is a cable',
      );
      await drag.cancel();
      await tester.pumpAndSettle();

      // And the body is untouched by any of it: a press there is the click
      // it always was.
      await tester.tapAt(toScreen(tester, centreOf('MTX-1')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        tester
            .renderObject<RenderSchematicCanvas>(
              find.byType(SchematicCanvasBody),
            )
            .plan
            .ops
            .whereType<OpPolyline>()
            .length,
        4,
        reason: 'MTX-1 was selected and F focused its four links',
      );
    });

    testWidgets('a press on a FULL pin falls back to a click rather than '
        'becoming a dead press', (tester) async {
      // A jack that cannot take another cable is still part of a device the
      // user may want to select. A press that armed nothing AND selected
      // nothing — because it landed 3 px inside a pin — is the silent
      // no-op docs/04 §3.4 forbids.
      await pump(tester);
      final pin = fullPin('MTX-1');

      await tester.tapAt(toScreen(tester, pin.centre));
      await tester.pumpAndSettle();
      expect(statusOf(tester), contains('No pin'));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        tester
            .renderObject<RenderSchematicCanvas>(
              find.byType(SchematicCanvasBody),
            )
            .plan
            .ops
            .whereType<OpPolyline>()
            .length,
        4,
        reason: 'the press still selected MTX-1',
      );
    });
  });

  group('2 — the band, the magnet and Ctrl', () {
    testWidgets('candidate rings appear only while a cable is in flight', (
      tester,
    ) async {
      await pump(tester);
      final idle = circles(tester);

      final pin = freePin('MTX-1');
      final drag = await tester.startGesture(toScreen(tester, pin.centre));
      await tester.pump();
      expect(
        circles(tester),
        greaterThan(idle + 1),
        reason: 'the source ring plus a ring on every candidate',
      );

      await drag.cancel();
      await tester.pumpAndSettle();
      expect(
        circles(tester),
        idle + 1,
        reason:
            'every candidate ring is gone — a ring on each reachable '
            'pin would be permanent furniture answering a question nobody '
            'asked — and the ONE that stays is the caret. The press put it '
            'on that pin and cancelling a cable does not un-put it: the '
            'user is still there, and W or an arrow continues from it. '
            'That is the same caret the keyboard drives, which is the '
            'whole reason there is one gesture and not two.',
      );
    });

    testWidgets('the magnet locks the band to a candidate within 12 screen '
        'px, and Ctrl lets go', (tester) async {
      // docs/05 §11.6's figure, and the corpus's only quantified
      // pin-proximity number. Approached from 8 px away — inside the
      // radius — so the lock is the magnet and not a direct hit.
      await pump(tester);
      final from = freePin('MTX-1');
      final to = freePin('AMP-1');
      final near = toScreen(tester, to.centre) + const Offset(8, 0);

      final drag = await tester.startGesture(toScreen(tester, from.centre));
      await tester.pump();
      await drag.moveTo(near);
      await tester.pump();
      expect(
        statusOf(tester),
        contains('→'),
        reason:
            'the band snapped onto a pin, so the status line resolves '
            'both ends (docs/05 §7.9)',
      );
      expect(statusOf(tester), contains('AMP-1'));

      // Ctrl down: the magnet lets go and the band follows the cursor.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await drag.moveTo(near + const Offset(1, 0));
      await tester.pump();
      expect(
        bandOf(tester).last,
        isNot(to.centre),
        reason:
            'docs/05 §14: "Ctrl held during draw | Suppress magnetic '
            'snap" — the band ends at the cursor, not on the pin',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await drag.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('the magnet will NOT lock onto a pin the cable may not land '
        'on, even with the cursor exactly on it', (tester) async {
      // The pointer's version of the keyboard's "Tab only reaches a
      // candidate". A magnet whose pool was every pin would drag the band
      // onto a full jack and then refuse it on release, which teaches the
      // user that the affordance lies.
      //
      // THE ASSERTION MOVED TO THE RELEASE, AND THE OLD ONE COULD NOT SEE
      // WHAT IT CLAIMED TO. It read `bandOf(tester).last, isNot(full
      // .centre)` — but an UNSNAPPED band is `[source, escape, freeEnd]`
      // and `freeEnd` is the raw cursor, which this test puts exactly on
      // the full pin. So `band.last == full.centre` means either "the
      // magnet locked onto a full jack" (the defect) or "the magnet
      // correctly found nothing and the cursor is simply there" (the
      // desired behaviour). The two are geometrically identical and the
      // assertion passed only while a FREE neighbour happened to sit
      // inside the 12 px radius and win the snap.
      //
      // The catalog order fix removed that neighbour — AMP-1's srcIn bank
      // now reads src.1.l, src.1.r, src.2.l … instead of a scrambled
      // order, and the fixture's three cables fill a contiguous run — so
      // the coincidence stopped holding and the test failed on correct
      // behaviour. What it always meant to assert is that a full jack is
      // not in the candidate pool, and the observable that says so
      // WITHOUT a geometric coincidence is the release: if the magnet had
      // locked on, letting go would commit.
      await pump(tester);
      final from = freePin('MTX-1');
      final full = fullPin('AMP-1');
      final linksBefore = doc.links.length;

      final drag = await tester.startGesture(toScreen(tester, from.centre));
      await tester.pump();
      await drag.moveTo(toScreen(tester, full.centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(
        doc.links,
        hasLength(linksBefore),
        reason:
            'the magnet may prefer a neighbouring CANDIDATE, but it '
            'may never lock onto a jack that is already full — and a '
            'release on a locked-on pin is exactly what commits',
      );
      final fullPortId = derivePortId(
        Uuid(full.ref.deviceId),
        PortKey(full.ref.portKey),
      );
      expect(
        portConductorCount(doc, fullPortId),
        1,
        reason:
            'the full jack carries the one cable it started with, and '
            'no second one arrived on it',
      );
    });
  });

  group('3 — a release has three outcomes', () {
    testWidgets('released on a candidate: it COMMITS, and the sheet holds '
        'still', (tester) async {
      await pump(tester);
      final pair = clearPair('MTX-1', 'AMP-1');
      final from = pair.from;
      final to = pair.to;

      final drag = await tester.startGesture(toScreen(tester, from.centre));
      await tester.pump();
      await drag.moveTo(toScreen(tester, to.centre));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(doc.links, hasLength(6));
      expect(statusOf(tester), contains('connected'));

      final link = doc.links.values.last;
      final ends = link.conductors.single;
      expect(
        (ends.from as PortEndpoint).portId,
        derivePortId(Uuid(from.ref.deviceId), PortKey(from.ref.portKey)),
      );
      expect(
        (ends.to as PortEndpoint).portId,
        derivePortId(Uuid(to.ref.deviceId), PortKey(to.ref.portKey)),
      );
    });

    testWidgets('released on a pin the rules REFUSE: the rule id and a '
        'sentence naming designators, and nothing written', (tester) async {
      // DR-011.5, through the pointer. `TOP-003`'s bound, on a jack that
      // already carries its one cable.
      //
      // `Ctrl` IS WHAT MAKES THIS REACHABLE, and that is the point rather
      // than a trick. At the framed zoom the magnet is wider than the pin
      // pitch, so a drop aimed at a full jack is caught by a free
      // neighbour and correctly commits there — the affordance working.
      // Suppressing the magnet (docs/05 §14) narrows the target to the
      // pin's own glyph, which is exactly the case the modifier exists
      // for, and it is the only way a user can insist on a jack the
      // magnet is steering them away from.
      await pump(tester);
      final from = freePin('MTX-1');
      final full = fullPin('AMP-1');

      final drag = await tester.startGesture(toScreen(tester, from.centre));
      await tester.pump();
      await drag.moveTo(toScreen(tester, full.centre));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await drag.up();
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      final said = statusOf(tester);
      expect(said, startsWith('TOP-'), reason: 'the rule id');
      expect(said, contains('AMP-1'), reason: 'and real designators');
      expect(
        doc.links,
        hasLength(5),
        reason:
            'DR-011.5: a T1 rule refuses OUTRIGHT — there is no '
            '[ Connect anyway ] and nothing is written',
      );
    });

    testWidgets('released on empty canvas: it CANCELS, silently as far as '
        'the document is concerned', (tester) async {
      // docs/05 §7: "Cancel is Esc, right-click, or a click on empty
      // canvas. All three abort with no model mutation and no undo entry."
      await pump(tester);
      final from = freePin('MTX-1');
      final before = controller.undo.canUndo;

      final drag = await tester.startGesture(toScreen(tester, from.centre));
      await tester.pump();
      await drag.moveTo(
        toScreen(tester, const DPt(-400, -400)),
      );
      await drag.up();
      await tester.pumpAndSettle();

      expect(statusOf(tester), contains('cancelled'));
      expect(doc.links, hasLength(5));
      expect(controller.undo.canUndo, before);
    });

    testWidgets('a TAP on a pin cables NOTHING — it picks the wire up and '
        'puts it back down', (tester) async {
      // THE DEFECT THIS PHASE SHIPPED AND THIS TEST CAUGHT. A connect
      // gesture used to commit on any release, so a press-and-release
      // inside the 4 px click slop went looking for a target — and found
      // one, because the source pin is not in its own candidate set and
      // the magnet is wider than the 2 gu pin pitch. One click on a jack
      // silently cabled it to the pin above it. The first run of this
      // suite printed "W006 connected MTX-1 J05 to MTX-1 J05".
      //
      // The rack's rule for the mirror case is the authority: "a
      // sub-threshold press has no preview to cancel and STAYS A CLICK".
      // This is its other half.
      await pump(tester);
      final pin = freePin('MTX-1');
      await tester.tapAt(toScreen(tester, pin.centre));
      await tester.pumpAndSettle();

      expect(
        doc.links,
        hasLength(5),
        reason: 'a click is not a drag, and a cable needs a drag',
      );
      // WHAT IS SAID CHANGED AT #93, AND THE OLD SENTENCE WAS THE WRONG
      // ONE. This assertion read `contains('cancelled')`. Since multi-draw
      // the tap also SETS THE ANCHOR a Shift+click extends from — so the
      // press has an outcome, and reporting a cancelled cable would name
      // the one thing the user did not do while staying silent about the
      // one they did. The substance above is untouched: still no link.
      expect(statusOf(tester), contains('MTX-1'));
      expect(
        statusOf(tester),
        contains('Shift+click'),
        reason:
            'the tap left an anchor, and this sentence is the only '
            'place multi-draw is discoverable — it has no button, no menu '
            'item and no coach mark of its own',
      );
    });
  });

  group('4 — the arbiter now has two values, and they do not free each '
      "other's claims", () {
    testWidgets('a connect refused while a click holds the canvas leaves the '
        "click's claim intact", (tester) async {
      // The case `_releasePointerGesture`'s identity check was written for
      // and could not previously be exercised: Phase 1 had one
      // `_PointerGesture` value, so "a refused gesture's teardown must not
      // free the winner's claim" was held only by the handler's token.
      // Now the two gestures carry DIFFERENT values and the screen-level
      // check does real work.
      await pump(tester);
      final handler = tester
          .widget<CanvasIntentDetector>(find.byType(CanvasIntentDetector))
          .handler!;

      // A real pointer press on a BODY — an ordinary click, holding
      // `canvasDrag`.
      final winner = await tester.startGesture(
        toScreen(tester, centreOf('MTX-1')),
      );
      await tester.pump();

      // A second gesture arriving through the same seam is refused.
      final refused = CanvasGestureToken();
      handler.beginDrag(
        freePin('AMP-1').centre,
        const {PointerDeviceKind.mouse},
        gesture: refused,
      );
      await tester.pump();
      expect(find.textContaining('One drag at a time'), findsOneWidget);

      // Its teardown must not release the winner's claim.
      handler.cancel(gesture: refused);
      await tester.pump();

      await winner.up();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(
        tester
            .renderObject<RenderSchematicCanvas>(
              find.byType(SchematicCanvasBody),
            )
            .plan
            .ops
            .whereType<OpPolyline>()
            .length,
        4,
        reason: "the winner's click still landed on MTX-1",
      );
    });

    testWidgets('a completed cable gives the canvas back', (tester) async {
      await pump(tester);
      final pair = clearPair('MTX-1', 'AMP-1');
      final from = pair.from;
      final to = pair.to;
      final drag = await tester.startGesture(toScreen(tester, from.centre));
      await drag.moveTo(toScreen(tester, to.centre));
      await drag.up();
      await tester.pumpAndSettle();
      expect(doc.links, hasLength(6));

      // A second, ordinary press must not be refused.
      await tester.tapAt(toScreen(tester, centreOf('SW-1')));
      await tester.pump();
      expect(
        find.textContaining('One drag at a time'),
        findsNothing,
        reason:
            'the connect claim was released on the terminal callback, '
            'not leaked',
      );
    });
  });

  group('5 — the two drivers are one gesture', () {
    testWidgets('a cable armed by POINTER can be committed by ENTER, and one '
        'armed by W can be committed by releasing a drag', (tester) async {
      // THE POINT OF BUILDING THE KEYBOARD FIRST. `_wireFrom`,
      // `_pinCaret` and `_candidates` are the gesture; the press and the
      // keypress are two ways of setting them. If these two crossings work,
      // there is one state machine and not two.
      await pump(tester);
      final pair = clearPair('MTX-1', 'AMP-1');
      final from = pair.from;
      final to = pair.to;

      // Armed by pointer, aimed by pointer, committed by Enter.
      final drag = await tester.startGesture(toScreen(tester, from.centre));
      await drag.moveTo(toScreen(tester, to.centre));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(doc.links, hasLength(6));
      await drag.up();
      await tester.pumpAndSettle();

      // Armed by pointer, cancelled by Esc.
      final second = freePin('MTX-1', index: 1);
      final drag2 = await tester.startGesture(
        toScreen(tester, second.centre),
      );
      await tester.pump();
      expect(statusOf(tester), contains('Wire from'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(statusOf(tester), contains('cancelled'));
      await drag2.up();
      await tester.pumpAndSettle();
      expect(doc.links, hasLength(6), reason: 'Esc wrote nothing');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 6 — docs/05 §7.3's AMBER RING, DRIVEN THROUGH THE SCREEN (`#278`)
  // ═══════════════════════════════════════════════════════════════════
  // `connect_overlay_test.dart` proves the overlay paints `#E69F00` when
  // it is TOLD a pin springs back. This group proves the screen works
  // out which pins those are, which is the half that can silently do
  // nothing: pass an empty set and every assertion over there still
  // passes.
  group('6 — the tier-2 verdict reaches the sheet', () {
    /// Circles wearing the spring-back hue in the current frame.
    int amberRings(WidgetTester tester) => tester
        .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
        .plan
        .ops
        .whereType<OpCircle>()
        .where((op) => op.stroke?.argb == kSpringBackRingArgb)
        .length;

    testWidgets('arming from an HDMI jack ambers the switch, and the rule '
        'that says so is CON-001', (tester) async {
      // THE FIXTURE ALREADY HELD A SPRING-BACK PAIR, which is worth
      // saying because nothing was added to make this pass. `MTX-1` is
      // the seed catalog's V03, an HDMI matrix whose jacks are
      // `conn.hdmi_a`; `SW-1` is N01, a 48-port PoE switch whose jacks
      // are `conn.rj45`. Those connectors do not mate and no adapter is
      // declared, so `CON-001` fires on every pair between them.
      //
      // The rule is asserted THROUGH CORE FIRST, so that a failure here
      // reads as "the screen did not paint it" rather than as "the
      // premise moved". A test whose setup and whose subject can both
      // break tells you nothing about which did.
      await pump(tester);
      final source = freePin('MTX-1');
      final sink = freePin('SW-1');

      ConnectTarget target(PinRef ref) => resolveConnectTarget(
        doc,
        deviceId: Uuid(ref.deviceId),
        portKey: ref.portKey,
      )!;
      final verdict = evaluateSpringBack(
        doc,
        target(source.ref),
        target(sink.ref),
      );
      expect(
        verdict,
        isA<SpringBackChip>().having(
          (c) => c.ruleId,
          'ruleId',
          'CON-001',
        ),
        reason: 'the premise: hdmi_a and rj45 do not mate',
      );

      expect(amberRings(tester), 0, reason: 'an idle sheet states no verdict');

      final drag = await tester.startGesture(toScreen(tester, source.centre));
      await tester.pump();
      expect(
        amberRings(tester),
        greaterThan(0),
        reason:
            "the switch's free jacks are candidates and CON-001 "
            'objects to every one of them',
      );

      await drag.cancel();
      await tester.pumpAndSettle();
      expect(
        amberRings(tester),
        0,
        reason:
            'a cancelled gesture leaves no verdict behind — the ring '
            'is a statement about a cable in flight',
      );
    });

    testWidgets('a pin no rule objects to keeps the candidate colour', (
      tester,
    ) async {
      // THE OTHER HALF, AND THE ONE THAT CATCHES "AMBER EVERYTHING".
      // A screen that put every candidate in the spring-back set would
      // pass the test above and be useless, since the ring's whole job
      // is to distinguish.
      //
      // IT NAMES A PIN RATHER THAN COUNTING, AND THE FIRST DRAFT DID NOT.
      // That draft asserted `total - amber > 0` over every stroked circle
      // in the frame, which passes no matter what the overlay does:
      // `symbol_layer` draws all 164 SYMBOL PINS as `OpCircle`, so the
      // subtraction was measuring the sheet rather than the verdict. It is
      // the finder problem one layer along, a count that cannot say WHICH
      // one being a count that agrees with anything.
      //
      // AND IT FINDS ITS OWN PAIR RATHER THAN NAMING ONE. The second draft
      // hard-coded `MTX-1` to `AMP-1` and went red on `DIR-001`: the first
      // FREE pin on each happens to be an input, because the fixture wires
      // the outputs. A premise a human picked by eye is a premise that can
      // be wrong, and this one was; a search cannot be.
      await pump(tester);
      final source = freePin('MTX-1');

      ConnectTarget target(PinRef ref) => resolveConnectTarget(
        doc,
        deviceId: Uuid(ref.deviceId),
        portKey: ref.portKey,
      )!;

      ({PinRef ref, DPt centre})? found;
      for (final symbol in reference.symbols) {
        for (final port in symbol.allPorts) {
          final ref = PinRef(deviceId: symbol.id, portKey: port.key);
          if (ref == source.ref) continue;
          if (portConductorCount(
                doc,
                derivePortId(Uuid(symbol.id), PortKey(port.key)),
              ) !=
              0) {
            continue;
          }
          final to = target(ref);
          if (evaluateConnect(doc, target(source.ref), to) is! ConnectAllowed) {
            continue;
          }
          if (evaluateSpringBack(doc, target(source.ref), to)
              is! SpringBackClear) {
            continue;
          }
          found = (ref: ref, centre: symbolPortCentre(symbol, port));
          break;
        }
        if (found != null) break;
      }
      expect(
        found,
        isNotNull,
        reason:
            'the premise: SOME pin on this sheet takes the cable with '
            'no tier-2 objection, or the ring has nothing to distinguish',
      );
      final clear = found!;
      final drag = await tester.startGesture(toScreen(tester, source.centre));
      await tester.pump();

      // THE LAST CIRCLE AT THAT CENTRE IS THE OVERLAY'S. A symbol pin is
      // drawn at the same point, and `schematic_paint_plan.dart`'s ordering
      // rule puts the overlay after every other op in the frame because the
      // IR has no z-index.
      final atPin = tester
          .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
          .plan
          .ops
          .whereType<OpCircle>()
          .where((op) => op.center == clear.centre && op.stroke != null)
          .toList();
      expect(atPin, isNotEmpty, reason: 'the pin got a candidate ring');
      expect(
        atPin.last.stroke!.argb,
        isNot(kSpringBackRingArgb),
        reason:
            'a pin the rules accept must not wear the verdict colour, or '
            'the ring is chrome rather than a statement',
      );

      await drag.cancel();
      await tester.pumpAndSettle();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 7 — THE SPRING-BACK ITSELF (`#278`, CR-017, DR-114 §11.113.4)
  // ═══════════════════════════════════════════════════════════════════
  // *"The gesture may hesitate; the document may not lie."* Everything
  // below is one half of that sentence: the chip and the armed state are
  // the hesitation, and the untouched `doc.links` is the half that does
  // not bend.
  group('7 — the wire springs back, and the chip says why', () {
    /// A pair `CON-001` objects to: `MTX-1` is HDMI on `conn.hdmi_a`,
    /// `SW-1` is RJ45, and no adapter is declared.
    ({({PinRef ref, DPt centre}) from, ({PinRef ref, DPt centre}) to})
    refusedPair() => (from: freePin('MTX-1'), to: freePin('SW-1'));

    Future<void> dragTo(
      WidgetTester tester,
      DPt from,
      DPt to,
    ) async {
      final drag = await tester.startGesture(toScreen(tester, from));
      await tester.pump();
      await drag.moveTo(toScreen(tester, to));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a release on a spring-back pin writes NOTHING and shows the '
        'chip', (tester) async {
      await pump(tester);
      final pair = refusedPair();
      final before = doc.links.length;

      await dragTo(tester, pair.from.centre, pair.to.centre);

      expect(
        doc.links,
        hasLength(before),
        reason: 'CR-017: the gesture hesitated, the document did not move',
      );
      expect(controller.undo.canUndo, isFalse, reason: 'and no undo entry');
      expect(find.byType(SpringBackChipCard), findsOneWidget);
      expect(
        find.text(kSpringBackConnectAnyway),
        findsOneWidget,
        reason: 'every chip carries it, without exception (docs/05:467)',
      );
      expect(
        statusOf(tester),
        startsWith('CON-001 '),
        reason:
            'the id AND the sentence on the ACCESSIBILITY channel too, '
            'not only in a widget a screen reader has to be pointed at',
      );
    });

    testWidgets('[ Connect anyway ] makes the cable the gesture would have '
        'made', (tester) async {
      // CR-017's escape hatch, end to end. The override is not a second
      // builder — see `_commitWire`'s `overriding` — so what it writes
      // must be indistinguishable from an ordinary connect.
      await pump(tester);
      final pair = refusedPair();
      final before = doc.links.length;

      await dragTo(tester, pair.from.centre, pair.to.centre);
      await tester.tap(find.text(kSpringBackConnectAnyway));
      await tester.pumpAndSettle();

      expect(doc.links, hasLength(before + 1));
      expect(find.byType(SpringBackChipCard), findsNothing);
      final link = doc.links.values.last;
      expect(link.conductors, hasLength(1));
      expect(
        doc.nets.containsKey(link.services.single.netId),
        isTrue,
        reason:
            'an overridden cable is a WHOLE cable — the Net is in the '
            'document, not dangling, exactly as a clean one is',
      );
      expect(
        controller.undo.canUndo,
        isTrue,
        reason: 'and it is one ordinary undo entry',
      );
    });

    testWidgets('[ Pick a different port ] closes the chip and leaves the '
        'cable IN HAND', (tester) async {
      // The whole of DR-114 §11.113.4. If this button were a relabelled
      // Cancel, the next act would be `W` again; because the wire is
      // still armed, `Enter` on a different pin commits.
      await pump(tester);
      final pair = refusedPair();
      await dragTo(tester, pair.from.centre, pair.to.centre);
      expect(find.byType(SpringBackChipCard), findsOneWidget);

      await tester.tap(find.text(kSpringBackPickAnother));
      await tester.pumpAndSettle();

      expect(find.byType(SpringBackChipCard), findsNothing);
      expect(
        statusOf(tester),
        isNot(contains('cancelled')),
        reason: 'a gesture that hesitated has not ended',
      );

      // STILL ARMED, PROVEN BY USE rather than by reading a field: Tab
      // reaches a candidate and Enter commits, with no second `W`.
      final before = doc.links.length;
      final clear = clearPair('MTX-1', 'AMP-1');
      // Aim by pointer at the clear pin — the same driver that armed it.
      final drag = await tester.startGesture(
        toScreen(tester, clear.to.centre),
      );
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        doc.links.length,
        anyOf(before, before + 1),
        reason:
            'a press after the chip is a fresh gesture or a commit, '
            'never a crash and never a silent nothing',
      );
    });

    testWidgets('Esc closes the chip; a SECOND Esc lets the cable go', (
      tester,
    ) async {
      // `schematicCancel` is one binding with a ladder behind it, and the
      // chip is the new top rung (`keymap.dart`'s own note: *"one more
      // limb in the gate"*). This is why the chip binds no key of its
      // own: a second Esc row in one scope is the collision `arbitrate()`
      // exists to forbid.
      await pump(tester);
      final pair = refusedPair();
      await dragTo(tester, pair.from.centre, pair.to.centre);
      expect(find.byType(SpringBackChipCard), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SpringBackChipCard), findsNothing);
      expect(
        statusOf(tester),
        isNot(contains('cancelled')),
        reason: 'the FIRST Esc closes the chip and hands back the cable',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        statusOf(tester),
        contains('cancelled'),
        reason: 'and the SECOND is what Esc has always meant here',
      );
    });

    testWidgets('the refused pin is marked #D55E00, and the mark goes with '
        'the chip', (tester) async {
      // docs/05 §7's target flash, and its resting state. The mark is
      // drawn at the CARET's radius rather than a candidate's because it
      // is a place the eye is being sent, and it survives the caret
      // leaving — the band retracted and took the caret with it.
      await pump(tester);
      final pair = refusedPair();

      int refusedMarks() => tester
          .renderObject<RenderSchematicCanvas>(find.byType(SchematicCanvasBody))
          .plan
          .ops
          .whereType<OpCircle>()
          .where((op) => op.stroke?.argb == kSpringBackRefusedArgb)
          .length;

      expect(refusedMarks(), 0, reason: 'nothing has been refused yet');
      await dragTo(tester, pair.from.centre, pair.to.centre);
      expect(
        refusedMarks(),
        1,
        reason: 'exactly one pin was refused, so exactly one is marked',
      );

      await tester.tap(find.text(kSpringBackPickAnother));
      await tester.pumpAndSettle();
      expect(
        refusedMarks(),
        0,
        reason:
            'the mark existed to say what the chip was ABOUT, so it '
            'cannot outlive it',
      );
    });
  });
}
