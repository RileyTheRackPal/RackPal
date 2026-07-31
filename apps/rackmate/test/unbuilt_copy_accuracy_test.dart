// The app's honest-absence copy is a factual claim about this codebase, so
// it is tested against this codebase.
//
// THE DEFECT THIS FILE EXISTS FOR. The Schematic tab told its reader that
// "the Link / Service / Conductor / Net model the schematic reads does not
// exist yet", and the Schedule tab told its reader that "no Link can exist
// yet". All four models are real, live on `RackDocument`, round-trip
// through `json_codec`, and are minted together by `AddLinkCommand` —
// which `linkCountForDevice` already counts for the shrink dialog's
// casualty table. The one panel in the app whose entire purpose is to be
// accurate about what exists was inaccurate about what exists, in the
// direction that costs the most: an engineer reading it concludes the data
// model is unbuilt and rebuilds it.
//
// NO TAB IS LEFT TO CHECK — AND THAT IS WHY THIS FILE STILL EXISTS. The
// Schedule's panel went at M2-B and the Schematic's at M2-E, each time
// because a sentence in it had stopped being true. This file's own thesis
// applied to itself: the surface whose purpose is accuracy about what
// exists must be the FIRST thing to change when something starts existing,
// not the last.
//
// WHAT SURVIVED BOTH DELETIONS WAS ONE CLAUSE — NOTHING IN THIS BUILD
// CREATES A CONNECTION — AND M2-F HAS NOW KILLED THAT TOO. The Schematic
// panel said it; `kNoLinksDetail` inherited it; `SchematicCanvasScreen`'s
// `_commitWire` runs a `ConnectPortsCommand` and made it false. The
// constant is rewritten and the group below asserts the new claim the same
// way it asserted the old one: against the SOURCE of both UI packages and
// this app, never against a comment.
//
// AND THE SCAN ITSELF HAD DRIFTED, which is the sharpest lesson this file
// has produced about itself. It grepped for `AddLinkCommand(` alone — one
// of four commands that mint a `Link` — so a schematic wiring through
// `ConnectPortsCommand` would have left it green while the copy it guards
// told the user nothing could create a cable. A guard that names one of
// the things it is guarding against is a guard with a hole in exactly the
// shape of the next change.
//
// `shell_tabs_test.dart` proves the complementary thing about what is
// DRAWN: that no tab fabricates a device, a port label or a control that
// does nothing.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'session/session_fakes.dart';

/// The Schematic sheet's own honest-absence copy, as the user reads it.
///
/// Taken from the CONSTANTS rather than scraped off the screen, because
/// the sentence is only shown when the document holds no cable and this
/// file's subject is whether the sentence is TRUE, not when it appears.
/// `shell_tabs_test.dart` covers the appearing.
String get _schematicCopy => '$kNoLinksHeadline $kNoLinksDetail';

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  // The supported window (docs/04 §1), matching the sibling shell tests.
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

  final now = DateTime.utc(2026, 7, 26);

  RackDocument emptyDoc() => RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0',
    createdAt: now,
    modifiedAt: now,
    meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'test'),
  );

  group('the wiring model the copy talks about', () {
    test('AddLinkCommand really does mint a Link, a Service, a Conductor '
        'and an implicit Net', () {
      // If this ever fails, the tabs' copy is allowed to say the model does
      // not exist — and this test is the thing that says so.
      final doc = emptyDoc();
      DocumentController(doc, clock: FixedClock(now)).run(
        AddLinkCommand(
          designator: 'W001',
          netName: 'N001',
          media: const MediaTypeId('media.cat6'),
          order: const FracIndex('a0'),
          now: now,
          actor: 'test',
        ),
      );

      expect(doc.links, hasLength(1));
      expect(doc.nets, hasLength(1));
      final link = doc.links.values.single;
      expect(link.services, hasLength(1));
      expect(link.conductors, hasLength(1));
      expect(
        doc.nets.containsKey(link.services.single.netId),
        isTrue,
        reason: 'the implicit Net must be in the document, not dangling',
      );
    });

    test("a template's ports really do render as a pinned symbol", () {
      // The other half of the Schematic copy: `symbol_layer.dart` turns
      // `TemplateBody.ports` into a symbol with pins. The 48 shipped
      // templates all author ports, so this capability is reachable today.
      final body = buildSeedCatalog()['N02']!;
      expect(body.ports, isNotEmpty);
      final symbol = buildSymbolGeometry(
        id: 'sym-1',
        designator: 'FW-1',
        ports: body.ports,
        headerHeight: 4,
        portSize: 2,
        portPitch: 4,
      );
      expect(symbol.allPorts, isNotEmpty);
      expect(symbol.bodyRect.width, greaterThan(0));
    });
  });

  group('what the Schematic sheet claims about itself', () {
    test('it does not deny that the wiring model exists', () {
      final copy = _schematicCopy.toLowerCase();
      // The sentences that shipped, and the shapes they generalise to.
      // Each is FALSE against the group above.
      for (final lie in [
        'model the schematic reads does not exist',
        'no link can exist',
        'links do not exist',
        'there is no link model',
      ]) {
        expect(
          copy,
          isNot(contains(lie)),
          reason:
              'the sheet claims "$lie", which the wiring-model tests in '
              'this file disprove',
        );
      }
    });

    test('it no longer claims the four things M2-C and M2-E built', () {
      // THE COPY THAT EXPIRED. The retired panel said "No sheet is laid
      // out, no symbol is placed on one, no wire is routed between two
      // pins and no net label is drawn". All four are now false — M2-C
      // lays the sheet out, M2-D draws the labels, M2-E routes a wire on
      // a filter — and a replacement that repeated any of them would be
      // the same defect this file was written for, pointing the other
      // way.
      final copy = _schematicCopy.toLowerCase();
      for (final expired in [
        'no sheet is laid out',
        'no symbol is placed',
        'no net label is drawn',
        'the gap is the view',
      ]) {
        expect(
          copy,
          isNot(contains(expired)),
          reason: '"$expired" stopped being true at M2-C/M2-D/M2-E',
        );
      }
    });

    test('the LAST clause has expired too, and the copy no longer claims '
        'nothing creates a Link', () {
      // M2-F IS WHAT KILLED IT. "No surface in this build creates a Link,
      // so there is nothing to label. The gap is the gesture, not the
      // view." was the one sentence of the retired panel that survived
      // M2-C, M2-D and M2-E — and `SchematicCanvasScreen._commitWire` runs
      // a `ConnectPortsCommand`, so it is now false in the direction this
      // file cares about most: it understates what the build can do, and a
      // user reading it concludes there is no way to wire their project.
      final copy = _schematicCopy.toLowerCase();
      for (final expired in [
        'no surface in this build creates a link',
        'the gap is the gesture',
        'there is nothing to label',
      ]) {
        expect(
          copy,
          isNot(contains(expired)),
          reason: '"$expired" stopped being true at M2-F',
        );
      }
    });

    test('it says what IS built, and now how to use it', () {
      final copy = _schematicCopy.toLowerCase();
      // Still says what is there, or the next reader rebuilds it.
      expect(copy, contains('laid out from your document'));
      expect(copy, contains('net labels'));
      expect(copy, contains('domain filter'));
      // AND THE GESTURE, because this panel is on screen exactly when the
      // user has nothing wired and needs to know how to start. docs/05 §7's
      // keyboard route is the one that exists; AC-048's coach mark, which
      // would teach it in passing, is Phase 5.
      expect(copy, contains('press w'));
      expect(copy, contains('enter to commit'));
      expect(copy, contains('esc cancels'));
    });

    testWidgets('the Schedule tab no longer has copy to be accurate '
        'about — it has a schedule', (tester) async {
      // The complement of the group above, and the reason the Schedule
      // rows here were deleted rather than reworded: the panel is gone.
      // Its last claim, "no code turns a Link into a row", is falsified
      // by the two lines below.
      await tester.pumpWidget((await buildTestApp(measurer)).app);
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(find.byType(UnbuiltView), findsNothing);

      final doc = emptyDoc();
      DocumentController(doc, clock: FixedClock(now)).run(
        AddLinkCommand(
          designator: 'W001',
          netName: 'N001',
          media: const MediaTypeId('media.cat6'),
          order: const FracIndex('a0'),
          now: now,
          actor: 'test',
        ),
      );
      expect(
        buildSchedule(doc).rowCount,
        1,
        reason:
            'code turns a Link into a row now, so the copy that said '
            'otherwise had to go',
      );
    });

    testWidgets('a surface DOES create a Link now, and the scan looks for '
        'every command that can', (tester) async {
      // ═══════════════════════════════════════════════════════════════
      // THE SCAN WAS ABOUT TO PASS FOR THE WRONG REASON
      // ═══════════════════════════════════════════════════════════════
      // It grepped for `AddLinkCommand(` alone, and M2-F creates cables
      // through `ConnectPortsCommand` — so the moment the schematic
      // started wiring, this test would have gone on reporting "no surface
      // creates a Link" forever while the copy said the same thing and
      // both were wrong. That is EXACTLY the drift this file exists to
      // catch, arriving through the file itself.
      //
      // So the scan now names every command that mints a `Link`, and the
      // assertion is INVERTED: at least one surface must call one of them,
      // because the copy no longer claims otherwise. If a later milestone
      // deletes the gesture, this fails and the copy has to change back.
      const linkMinting = <String>[
        'AddLinkCommand(',
        'ConnectPortsCommand(',
        'buildConnectPortsCommand(',
        'AtomicConnectCommand(',
      ];
      final roots = [
        Directory('lib'),
        Directory('../../packages/rackmate_ui/lib'),
      ];
      final callers = <String>[];
      for (final root in roots) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = entity.readAsStringSync();
          if (linkMinting.any(source.contains)) callers.add(entity.path);
        }
      }
      expect(
        callers,
        isNotEmpty,
        reason:
            'the Schematic sheet tells the user to press W to draw a '
            'cable; if no surface calls a link-minting command, that '
            'sentence is a lie',
      );
      expect(
        callers.any((p) => p.contains('schematic_canvas_screen')),
        isTrue,
        reason: 'and it is the SHEET that does it — the surface whose copy '
            'makes the promise',
      );
    });
  });
}
