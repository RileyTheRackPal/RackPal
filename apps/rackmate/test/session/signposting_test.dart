// M2-F PHASE 5 — the two rulings that only the SHELL can satisfy.
//
// CR-105's chip is drawn by the elevation and answered by the schematic,
// but neither tab may reach the other and `rackmate_ui` contains no shell
// at all: the tab switch exists only here. AC-048's coach mark is the same
// shape — "the first time the Schematic is opened" is an event that only
// the thing owning the `TabController` can observe.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS FILE IS FOR THAT THE PACKAGE-LEVEL TESTS CANNOT BE
// ═══════════════════════════════════════════════════════════════════════
// `rackmate_ui`'s `port_chip_test.dart` proves the chip calls its callback
// and `schematic_reveal_test.dart` proves a parked request is honoured.
// Neither can prove they are WIRED TO EACH OTHER, and a signpost that is
// perfectly implemented at both ends and connected to nothing is exactly
// the failure CR-105 exists to prevent.
//
// DR-012.4 is likewise only testable here: it rules that the mark's
// "first" lives in APP-SUPPORT PREFS — not in the document (it would
// re-fire per file and put UI chrome inside CR-117's byte surface) and not
// unpersisted (a nag). The store is the app's; so is the proof.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackmate/src/session/app_services.dart';
import 'package:rackmate/src/session/app_shell.dart';
import 'package:rackmate/src/storage/data_root.dart';
import 'package:rackmate/src/storage/prefs_store.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import '../rack_scene_to_screen.dart';
import '../storage/fake_file_store.dart';
import 'session_fakes.dart';

const _rackId = Uuid('rack-sign');
const _amp = Uuid('dev-amp');
const _mtx = Uuid('dev-mtx');
final _when = DateTime.utc(2026, 8, 2);
const _geo = RackGeometry(12);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _port(String key, String order) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.xlr3'),
  signalFamily: const SignalFamilyId('audio.analog.balanced'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
  maxConnections: 4,
);

void _addDevice(
  RackDocument doc,
  Uuid id,
  String designator,
  int ruIndex,
  int frontU,
  int portCount,
) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    capturedAt: _when,
    body: TemplateBody(
      manufacturer: 'Demo',
      model: tpl,
      displayName: designator,
      frontU: frontU,
      ports: [
        for (var i = 1; i <= portCount; i++) _port('p.$i', 'a$i'),
      ],
    ),
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
    ),
    designator: designator,
    name: designator,
    placement: RailPlacement(
      rackId: _rackId,
      ruIndex: ruIndex,
      face: Face.front,
    ),
    meta: _meta(),
  );
}

/// A 12U rack, two wireable devices, and ONE cable already drawn.
///
/// THE CABLE IS NOT DECORATION. The shell holds AC-048's mark back on a
/// sheet with no links — the mark teaches how to SEE wires, and spending a
/// once-per-user hint where there are none spends it where it cannot mean
/// anything. Every coach-mark test below therefore needs a document that
/// has one, and the `no links` test needs one that does not.
RackDocument _wiredDocument({bool withLink = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-sign'),
    appVersion: kAppVersion,
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Signpost Rack',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  _addDevice(doc, _amp, 'AMP-1', 4, 2, 6);
  _addDevice(doc, _mtx, 'MTX-1', 8, 1, 6);
  if (!withLink) return doc;

  final built = buildConnectPortsCommand(
    doc: doc,
    from: resolveConnectTarget(doc, deviceId: _amp, portKey: 'p.1')!,
    to: resolveConnectTarget(doc, deviceId: _mtx, portKey: 'p.1')!,
    media: kUnstatedMedia,
    now: _when,
    actor: 'test',
  );
  (built as ConnectPortsReady).command.apply(doc);
  return doc;
}

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

  Future<TestSession> pump(
    WidgetTester tester, {
    RackDocument? document,
    FakeFileStore? fs,
    DataRoot? dataRoot,
  }) async {
    final built = await buildTestApp(
      measurer,
      document: document ?? _wiredDocument(),
      fs: fs,
      dataRoot: dataRoot,
    );
    await tester.pumpWidget(built.app);
    await tester.pumpAndSettle();
    return built.session;
  }

  /// Taps the centre of [designator]'s CR-105 chip on the rack elevation.
  ///
  /// The rect is rebuilt here from `portChipRect` and the device's own
  /// layout, with the app's REAL measurer — the same function the painter
  /// and the screen's hit test both call. Aiming at a device's centre
  /// instead would pass on a build where the chip does not exist.
  Future<void> tapChip(
    WidgetTester tester,
    int ru,
    int heightU,
    String label,
  ) async {
    final device = _geo.deviceRect(ru, heightU);
    final chip = portChipRect(
      deviceWidth: device.width,
      deviceHeight: device.height,
      label: label,
      measurer: measurer,
    )!;
    await tester.tapAt(
      sceneToScreen(
        tester,
        device.left + chip.left + chip.width / 2,
        device.top + chip.top + chip.height / 2,
      ),
    );
    await tester.pumpAndSettle();
  }

  int tabIndex(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

  Future<void> switchToSchematic(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, 'Schematic'));
    await tester.pumpAndSettle();
  }

  Finder coachMark() => find.text(kCoachMarkSchematicFilterText);

  group('1 — CR-105, joined up across the strip', () {
    testWidgets('clicking the chip switches to the Schematic', (tester) async {
      await pump(tester);
      // BY KEY, NOT BY ORDINAL. DR-091 reordered the strip and the Rack
      // moved from index 0 to 2; the app still OPENS there, because
      // §11.90.3 rules the order and not the landing view.
      expect(
        tabIndex(tester),
        kViewKeyToTabIndex[1],
        reason: 'the app opens on the Rack tab',
      );

      await tapChip(tester, 4, 2, '1/6');

      expect(tabIndex(tester), kViewKeyToTabIndex[2]);
      expect(find.byType(SchematicCanvasScreen), findsOneWidget);
    });

    testWidgets('and arrives with THAT device selected', (tester) async {
      // Observed the way `rackmate_ui`'s own suite observes a schematic
      // selection: `F` focuses it, and focus is what draws wires
      // (§11.1.1's third row). Nothing is drawn before the reveal.
      await pump(tester);
      await tapChip(tester, 4, 2, '1/6');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();

      final ops = tester
          .renderObject<RenderSchematicCanvas>(
            find.byType(SchematicCanvasBody),
          )
          .plan
          .ops;
      expect(
        ops.whereType<OpPolyline>(),
        isNotEmpty,
        reason: 'a wire is drawn, so a device really is selected there',
      );
    });

    testWidgets('the chip is on the OTHER device too, and reveals that one', (
      tester,
    ) async {
      await pump(tester);
      await tapChip(tester, 8, 1, '1/6');
      expect(tabIndex(tester), kViewKeyToTabIndex[2]);
    });
  });

  group('2 — AC-048, and where its "first" lives (DR-012.4)', () {
    testWidgets('it fires the first time the Schematic is opened', (
      tester,
    ) async {
      await pump(tester);
      expect(coachMark(), findsNothing, reason: 'not on the Rack tab');

      await switchToSchematic(tester);
      expect(coachMark(), findsOneWidget);
    });

    testWidgets('`Got it` retires it, and writes that to prefs.json', (
      tester,
    ) async {
      final t = await pump(tester);
      await switchToSchematic(tester);
      expect(coachMark(), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Got it'));
      await tester.pumpAndSettle();
      expect(coachMark(), findsNothing);

      // DR-012.4: APP-SUPPORT PREFS. Read off the bytes on the fake disk
      // rather than off the in-memory store, because "persisted" is a
      // claim about a file.
      final path = t.context.join(kTestDataRoot, kPrefsFileName);
      final raw = jsonDecode(utf8.decode(await t.fs.readBytes(path)));
      expect(
        (raw as Map)['coachMarksSeen'],
        contains(kCoachMarkSchematicFilter),
      );
    });

    testWidgets('filtering a domain retires it too — a user who did the '
        'thing has learnt it', (tester) async {
      final t = await pump(tester);
      await switchToSchematic(tester);
      expect(coachMark(), findsOneWidget);

      // The first domain chip on the filter bar — an `InkWell`, and the
      // chips are the bar's leading children (the `All`/`None` buttons
      // are `TextButton`s after them).
      await tester.tap(
        find
            .descendant(
              of: find.byType(DomainFilterBar),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(coachMark(), findsNothing);
      expect(
        t.services.prefsStore!.current.hasSeenCoachMark(
          kCoachMarkSchematicFilter,
        ),
        isTrue,
      );
    });

    testWidgets('leaving and returning does not bring it back', (
      tester,
    ) async {
      await pump(tester);
      await switchToSchematic(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Got it'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Rack'));
      await tester.pumpAndSettle();
      await switchToSchematic(tester);

      expect(coachMark(), findsNothing);
    });

    testWidgets('a SECOND launch over the same prefs never shows it — per '
        'USER, not per project', (tester) async {
      // "Persisting per USER rather than per PROJECT is also what 'first
      // time' means to the person reading it: the second project is not
      // the first time they have seen the app." (§11.12.4.) The second
      // app below gets a DIFFERENT document and the SAME disk.
      final fs = FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      );
      await pump(tester, fs: fs);
      await switchToSchematic(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Got it'));
      await tester.pumpAndSettle();

      await pump(tester, fs: fs, document: _wiredDocument());
      await switchToSchematic(tester);
      expect(coachMark(), findsNothing);
    });

    testWidgets('an empty sheet does not spend it', (tester) async {
      // The mark teaches how to SEE wires. A document with none has
      // nothing for the filter to reveal, and `kNoLinksDetail` is what
      // speaks there instead.
      await pump(tester, document: _wiredDocument(withLink: false));
      await switchToSchematic(tester);
      expect(coachMark(), findsNothing);
    });

    testWidgets('a degraded session still teaches, once, without a store', (
      tester,
    ) async {
      // A read-only stick or a locked-down profile: no `prefs.json` to
      // write. Refusing to teach the domain filter because a folder is
      // read-only would be worse than a session-scoped dismissal, and a
      // crash on the null store would be worse than both.
      final t = await pump(
        tester,
        dataRoot: const DataRootUnusable(
          attemptedPath: r'C:\nope',
          portable: false,
          cause: 'the data folder is read-only in this test',
        ),
      );
      expect(t.services.prefsStore, isNull);

      await switchToSchematic(tester);
      expect(coachMark(), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Got it'));
      await tester.pumpAndSettle();
      expect(coachMark(), findsNothing);
    });
  });

  group('3 — AppPrefs carries the marks', () {
    test('an unknown or malformed entry is dropped, not fatal', () {
      // `prefs.json` is hand-editable and a convenience file must never
      // stop the app starting — the rule the rest of this class follows.
      expect(
        AppPrefs.fromJson(<String, Object?>{
          'coachMarksSeen': ['a', 42, '', null, 'b'],
        }).coachMarksSeen,
        <String>{'a', 'b'},
      );
      expect(
        AppPrefs.fromJson(<String, Object?>{
          'coachMarksSeen': 'not a list',
        }).coachMarksSeen,
        isEmpty,
      );
    });

    test('it round-trips, sorted, and is absent when empty', () {
      const prefs = AppPrefs(coachMarksSeen: <String>{'z', 'a'});
      expect(prefs.toJson()['coachMarksSeen'], <String>['a', 'z']);
      expect(
        AppPrefs.fromJson(prefs.toJson()).coachMarksSeen,
        <String>{'a', 'z'},
      );
      expect(
        const AppPrefs().toJson().containsKey('coachMarksSeen'),
        isFalse,
        reason: 'a file that has never seen a mark says nothing about them',
      );
    });

    test('withCoachMarkSeen adds without disturbing anything else', () {
      // The defect `AppServices.prefs` documents at length: a
      // load-modify-write that drops a sibling field. This one is add-only
      // by construction.
      const before = AppPrefs(
        lastSaveDirectory: r'C:\jobs',
        maximized: true,
        coachMarksSeen: <String>{'first'},
      );
      final after = before.withCoachMarkSeen('second');
      expect(after.coachMarksSeen, <String>{'first', 'second'});
      expect(after.lastSaveDirectory, r'C:\jobs');
      expect(after.maximized, isTrue);
      expect(after.hasSeenCoachMark('first'), isTrue);
      expect(after.hasSeenCoachMark('third'), isFalse);
    });
  });
}
