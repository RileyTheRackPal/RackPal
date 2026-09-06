// The `Mount note` control (`#839`, M5-L, DR-130 §11.129).
//
// ═══════════════════════════════════════════════════════════════════════
// THE CHAIN HAS TO END AT A PERSON, AND M5 KEEPS FINDING THAT IT DOES NOT
// ═══════════════════════════════════════════════════════════════════════
// `OffRackPlacement.mountNote` was modelled, serialized, round-tripped
// and seeded by the starter generator, and no gesture ever wrote one.
// DR-125 priced the cabinet head end against it anyway.
//
// A writer alone would not have fixed that. DR-128 shipped
// `Finding.remedy` with a writer, an implementation and a ruling saying
// the panel rendered it, and the panel never read the field; `#847` then
// found the panel itself has no host. So the assertion that matters here
// is not that the widget draws: it is that the widget is WIRED, and that
// a callback the panel is not given produces no control rather than a
// dead one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9, 6);
const _rackId = Uuid('r1');
const _closet = Uuid('loc-closet');
const _modem = Uuid('d-modem');
const _amp = Uuid('d-amp');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

RackDocument _doc({String? mountNote}) {
  final doc = RackDocument(
    id: const Uuid('doc-mount-ui'),
    appVersion: '0.5.61',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  doc.locations[_closet] = Location(
    id: _closet,
    name: 'AV Closet',
    code: 'AVC',
    kind: LocationKind.room,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    designator: 'RK-1',
    name: 'Rack 1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.templates['amp@1'] = TemplateSnapshot(
    templateId: const TemplateId('amp'),
    version: 1,
    contentHash: 'unhashed:amp@1',
    body: TemplateBody(
      manufacturer: 'Test',
      model: 'amp',
      displayName: 'Amp',
      frontU: 1,
      side: OccupancySide.front,
    ),
    capturedAt: _now,
  );
  doc.devices[_modem] = DeviceInstance(
    id: _modem,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('amp'),
      version: 1,
      contentHash: 'unhashed:amp@1',
    ),
    designator: 'MDM-1',
    name: 'Cable modem',
    placement: OffRackPlacement(locationId: _closet, mountNote: mountNote),
    meta: _meta(),
  );
  doc.devices[_amp] = DeviceInstance(
    id: _amp,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('amp'),
      version: 1,
      contentHash: 'unhashed:amp@1',
    ),
    designator: 'AMP-1',
    name: 'Amplifier',
    placement: const RailPlacement(
      rackId: _rackId,
      ruIndex: 3,
      face: Face.front,
    ),
    meta: _meta(),
  );
  return doc;
}

Future<List<String>> _pump(
  WidgetTester tester,
  RackDocument doc,
  Set<Uuid> selected, {
  bool wired = true,
}) async {
  final typed = <String>[];
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: InspectorPanel(
            target: InspectorTarget.selection,
            rack: doc.racks[_rackId]!,
            doc: doc,
            presets: const {},
            selectedIds: selected,
            focusedId: selected.length == 1 ? selected.single : null,
            onSetProperty: <T>(_, _) {},
            onRename: (_) {},
            onRequestHeight: (_) {},
            onApplyPreset: (_) {},
            onRefuse: (_) {},
            onSetLifecycle: (_) {},
            onSetWidth: (_) {},
            onSetOverride: <T>(_, _) {},
            onSetPortFact: (_, _, _, _, _) {},
            onSetMountNote: wired ? typed.add : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return typed;
}

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

void main() {
  group('THE SCREEN SUPPLIES THE CALLBACK, which is #847 case', () {
    testWidgets('RackCanvasScreen wires onSetMountNote, so the control is '
        'not a panel-test artefact', (tester) async {
      // ═══════════════════════════════════════════════════════════════
      // EVERY OTHER TEST IN THIS FILE MOUNTS THE PANEL ITSELF
      // ═══════════════════════════════════════════════════════════════
      // Which is exactly what `#847` records about `DrcPanel`: it passes
      // its own tests because its tests mount it, and nothing in the
      // product does. A control wired only inside a test file is a
      // control no user can reach, and this is the one assertion in this
      // file that a panel test cannot make about itself.
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RackCanvasScreen(measurer: _FakeMeasurer())),
        ),
      );
      await tester.pumpAndSettle();

      final panel = tester.widget<InspectorPanel>(
        find.byType(InspectorPanel),
      );
      expect(
        panel.onSetMountNote,
        isNotNull,
        reason:
            'the screen mounts the inspector; if it hands over no '
            'mount-note callback, the field renders nowhere a person '
            'can reach and DR-130 delivered a widget rather than a '
            'feature',
      );
    });
  });

  group('when the control appears at all', () {
    testWidgets('an off-rack device gets one', (tester) async {
      await _pump(tester, _doc(), {_modem});
      expect(find.text(kMountNoteLabel), findsOneWidget);
    });

    testWidgets('a rail-placed device does NOT, because a rack, a U and a '
        'face already answer where it sits', (tester) async {
      await _pump(tester, _doc(), {_amp});
      expect(find.text(kMountNoteLabel), findsNothing);
      // The other side of the sealed type DOES get its control, which is
      // what makes the absence above a decision rather than a bug.
      expect(find.text('Width position'), findsOneWidget);
    });

    testWidgets('and a two-device selection gets neither, rather than one '
        'that writes to whichever is first', (tester) async {
      await _pump(tester, _doc(), {_modem, _amp});
      expect(find.text(kMountNoteLabel), findsNothing);
    });
  });

  group('the wiring, which is the part that has been wrong twice', () {
    testWidgets('typing reaches the callback', (tester) async {
      final typed = await _pump(tester, _doc(), {_modem});
      await tester.enterText(
        find.byType(MountNoteField),
        'Top shelf, left',
      );
      await tester.pumpAndSettle();
      expect(
        typed,
        contains('Top shelf, left'),
        reason:
            'a control that draws and reports nothing is exactly the '
            'state DR-128 shipped Finding.remedy in',
      );
    });

    testWidgets('no callback means NO CONTROL, not a dead one', (
      tester,
    ) async {
      await _pump(tester, _doc(), {_modem}, wired: false);
      expect(
        find.text(kMountNoteLabel),
        findsNothing,
        reason:
            'a dead field invites the question of what would make it '
            'live, which is onSetWidth own precedent one control up',
      );
    });

    testWidgets('an existing note is shown rather than an empty box', (
      tester,
    ) async {
      await _pump(tester, _doc(mountNote: 'Ceiling, rear of room'), {_modem});
      expect(find.text('Ceiling, rear of room'), findsOneWidget);
    });

    testWidgets('and the hint is an EXAMPLE, so an empty field still shows '
        'the shape of an answer', (tester) async {
      await _pump(tester, _doc(), {_modem});
      expect(find.text(kMountNoteHint), findsOneWidget);
    });
  });
}
