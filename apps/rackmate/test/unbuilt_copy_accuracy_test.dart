// The `UnbuiltView` copy is a factual claim about this codebase, so it is
// tested against this codebase.
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
// `shell_tabs_test.dart` proves the unbuilt tabs FABRICATE nothing (no
// pin, no wire, no designator, no tappable control). That is a property of
// what is drawn. This file proves the complementary thing — that what is
// WRITTEN is true — and it does so by exercising the code the copy talks
// about in the same test, so the two cannot drift apart silently. A test
// that only grepped the strings would pass forever after somebody deleted
// `AddLinkCommand`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate/main.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// Opens [viewName]'s tab in a freshly pumped shell and returns the full
/// copy of the [UnbuiltView] the app builds for it.
///
/// The tab has to be OPENED: `TabBarView` builds its children lazily, so a
/// shell that has only ever shown the Rack tab has no `UnbuiltView` in its
/// tree at all — a version of this helper that just searched the tree
/// found nothing and would have "passed" every `isNot(contains(...))`
/// assertion below without reading a single character of the copy.
Future<String> _copyFor(
  WidgetTester tester,
  TextMeasurer measurer,
  String viewName,
) async {
  await tester.pumpWidget(RackMateApp(measurer: measurer));
  await tester.tap(find.text(viewName));
  await tester.pumpAndSettle();
  final view = tester.widget<UnbuiltView>(find.byType(UnbuiltView));
  expect(view.viewName, viewName);
  return '${view.absent}\n${view.why}';
}

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
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
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

  group('what the two unbuilt tabs claim', () {
    testWidgets('neither tab denies that the wiring model exists', (
      tester,
    ) async {
      for (final view in ['Schematic', 'Schedule']) {
        final copy = (await _copyFor(tester, measurer, view)).toLowerCase();
        // The two sentences that shipped, and the shapes they generalise
        // to. Each is FALSE against the group above.
        for (final lie in [
          'model the schematic reads does not exist',
          'no link can exist',
          'links do not exist',
          'there is no link model',
        ]) {
          expect(
            copy,
            isNot(contains(lie)),
            reason: '$view claims "$lie", which the wiring-model tests in '
                'this file disprove',
          );
        }
      }
    });

    testWidgets('each tab names the thing that is ACTUALLY missing', (
      tester,
    ) async {
      final schematic = (await _copyFor(
        tester,
        measurer,
        'Schematic',
      )).toLowerCase();
      // The true statements: no view creates a connection, and nothing
      // builds a schematic scene.
      expect(schematic, contains('nothing in this build creates a connection'));
      expect(schematic, contains('no sheet is laid out'));
      // And it must not understate what IS there, or the next reader
      // rebuilds it.
      expect(schematic, contains('addlinkcommand'));
      expect(schematic, contains('symbol_layer.dart'));

      final schedule = (await _copyFor(
        tester,
        measurer,
        'Schedule',
      )).toLowerCase();
      expect(schedule, contains('nothing in this build creates one'));
      expect(schedule, contains('no code turns a link into a row'));
    });

    testWidgets('no surface in the app calls AddLinkCommand — which is what '
        'lets the copy say so', (tester) async {
      // The copy's load-bearing claim is "no surface calls it". Proven
      // against the source of both UI packages and the app, not asserted.
      final roots = [
        Directory('lib'),
        Directory('../../packages/rackmate_ui/lib'),
      ];
      final callers = <String>[];
      for (final root in roots) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          if (entity.readAsStringSync().contains('AddLinkCommand(')) {
            callers.add(entity.path);
          }
        }
      }
      expect(
        callers,
        isEmpty,
        reason: 'a UI now creates Links; the unbuilt tabs must stop saying '
            'nothing does',
      );
    });
  });
}
