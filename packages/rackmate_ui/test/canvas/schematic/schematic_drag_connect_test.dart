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
          data.startsWith('TOP-')) {
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
        reason: 'every candidate ring is gone — a ring on each reachable '
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
        reason: 'the band snapped onto a pin, so the status line resolves '
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
        reason: 'docs/05 §14: "Ctrl held during draw | Suppress magnetic '
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
        reason: 'the magnet may prefer a neighbouring CANDIDATE, but it '
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
        reason: 'the full jack carries the one cable it started with, and '
            'no second one arrived on it',
      );
    });
  });

  group('3 — a release has three outcomes', () {
    testWidgets('released on a candidate: it COMMITS, and the sheet holds '
        'still', (tester) async {
      await pump(tester);
      final from = freePin('MTX-1');
      final to = freePin('AMP-1');

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
        reason: 'DR-011.5: a T1 rule refuses OUTRIGHT — there is no '
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
        reason: 'the tap left an anchor, and this sentence is the only '
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
      final from = freePin('MTX-1');
      final to = freePin('AMP-1');
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
        reason: 'the connect claim was released on the terminal callback, '
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
      final from = freePin('MTX-1');
      final to = freePin('AMP-1');

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
}
