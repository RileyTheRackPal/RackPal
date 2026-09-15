// `#875` — the validation drawer's three callbacks reach the commands.
//
// =====================================================================
// THE FEATURE WAS BUILT THREE TIMES AND REACHABLE NONE OF THEM
// =====================================================================
// DR-128 §11.127.5 said the issues panel "renders [the remedy] as a
// button". It did not; `drc_panel.dart` never read the field. DR-129
// §11.128.4 recorded that and built the button, and
// `remedy_pairing_test.dart` was written as the backstop.
//
// **THE BUTTON THEN HAD NOTHING BEHIND IT.** `ValidationDrawer` declares
// `onAcknowledge`, `onWithdraw` and `onRemedy`, passes all three to
// `DrcPanel`, and `DrcPanel` renders a control for each when it is
// non-null. There is exactly ONE mount of `ValidationDrawer` in the
// product and it passed **none of the three**, so the buttons were absent
// and nothing failed. `AcknowledgeFindingCommand`,
// `UnacknowledgeFindingCommand` and PWR-003's whole remedy chain were
// unreachable, each with a real revert and its own suite.
//
// Every test that could have caught it was written against the panel,
// which is where the callbacks arrive, not against the mount, which is
// where they come from. So these go through `RackCanvasScreen`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../app_like.dart';

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

final _at = DateTime.utc(2026, 9, 12);
EntityMeta _meta() =>
    EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'test');

const _rack = Uuid('rk-1');

/// A template that consumes an outlet and provides none.
///
/// ONE INLET AND NO CORD DRAWN TO IT, which is how a body consumes an
/// outlet since DR-171 (§11.170.4, clause 3). It used to author
/// `outletsConsumed: 1` with no ports, which now reads as a device nobody
/// described, so `PWR-003` would never fire and this file would test an
/// empty drawer.
TemplateBody _hungry() => TemplateBody(
  manufacturer: 'Demo',
  model: 'Hungry',
  displayName: 'Hungry box',
  frontU: 1,
  side: OccupancySide.front,
  ports: [
    PortDef(
      key: const PortKey('ac.in'),
      label: 'AC IN',
      connector: const ConnectorTypeId('conn.nema_5_15p'),
      signalFamily: const SignalFamilyId('power.ac_branch'),
      face: Face.rear,
      order: const FracIndex('a0'),
      power: PortPowerSpec(role: PortPowerRole.inlet),
    ),
  ],
);

/// A rack whose devices need outlets nothing in it provides, which is
/// exactly `PWR-003`.
RackDocument _document({int devices = 2}) {
  final doc = RackDocument(
    id: const Uuid('doc-875'),
    appVersion: '0.6.57',
    createdAt: _at,
    modifiedAt: _at,
    meta: _meta(),
    info: ProjectInfo(projectName: '#875'),
    registries: buildSeedRegistries(),
  );
  doc.racks[_rack] = Rack(
    id: _rack,
    name: 'HEAD END',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.templates['hungry@1'] = TemplateSnapshot(
    templateId: const TemplateId('hungry'),
    version: 1,
    contentHash: 'sha256:hungry',
    capturedAt: _at,
    body: _hungry(),
  );
  for (var i = 0; i < devices; i++) {
    final id = Uuid('dev-$i');
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('hungry'),
        version: 1,
        contentHash: 'sha256:hungry',
      ),
      designator: 'DEV-$i',
      name: 'Device $i',
      placement: RailPlacement(rackId: _rack, ruIndex: i + 1, face: Face.front),
      meta: _meta(),
    );
  }
  return doc;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1100)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester, RackDocument doc) async {
    await tester.pumpWidget(
      MaterialApp(
        shortcuts: appGlobalShortcuts(),
        home: Scaffold(
          body: RackCanvasScreen(
            measurer: _FakeMeasurer(),
            document: doc,
            clock: FixedClock(_at),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the issues drawer, which starts collapsed.
  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byType(ValidationDrawer));
    await tester.pumpAndSettle();
  }

  /// The dialog's confirm, NOT the row's button.
  ///
  /// **THE TWO SHARE A LABEL AND THAT IS RIGHT**: the row offers to
  /// acknowledge and the dialog confirms the same verb, so renaming
  /// either to disambiguate a test would be the test writing the copy.
  /// Anchoring on the dialog is the finder's job, and `.first` would have
  /// pressed whichever happened to be earlier in the tree.
  Finder dialogConfirm() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(kAckConfirm),
  );

  group('the fixture raises the finding these tests are about', () {
    testWidgets('PWR-003 fires, with a remedy', (tester) async {
      final doc = _document();
      final findings = evaluateDocument(doc);
      expect(
        findings.where((f) => f.ruleId == 'PWR-003'),
        hasLength(1),
        reason: 'two devices consuming one outlet each, nothing providing',
      );
      expect(findings.first.remedy, FindingRemedy.addRackPdu);
      await pump(tester, doc);
      expect(find.byType(ValidationDrawer), findsOneWidget);
    });
  });

  group('`#875`: acknowledging reaches the command', () {
    testWidgets('the Acknowledge control is THERE, which it was not', (
      tester,
    ) async {
      final doc = _document();
      await pump(tester, doc);
      await openDrawer(tester);

      expect(
        find.text(kDrcAcknowledge),
        findsWidgets,
        reason:
            'the one mount passed no onAcknowledge, so DrcPanel rendered '
            'nothing and the control was absent rather than dead',
      );
    });

    testWidgets('pressing it opens the dialog and writing one lands an '
        'AckedFinding', (tester) async {
      final doc = _document();
      await pump(tester, doc);
      await openDrawer(tester);
      expect(doc.ackedFindings, isEmpty);

      await tester.tap(find.text(kDrcAcknowledge).first);
      await tester.pumpAndSettle();
      expect(find.text(kAckReasonOptional), findsOneWidget);

      await tester.tap(dialogConfirm());
      await tester.pumpAndSettle();

      expect(
        doc.ackedFindings,
        hasLength(1),
        reason:
            'RJ-006: a single-instance acknowledgement takes one '
            'click and its reason may be left empty',
      );
      expect(doc.ackedFindings.values.first.ruleId, 'PWR-003');
    });

    testWidgets('and then the row offers to WITHDRAW it, which removes it', (
      tester,
    ) async {
      final doc = _document();
      await pump(tester, doc);
      await openDrawer(tester);
      await tester.tap(find.text(kDrcAcknowledge).first);
      await tester.pumpAndSettle();
      await tester.tap(dialogConfirm());
      await tester.pumpAndSettle();
      expect(doc.ackedFindings, hasLength(1));

      await tester.tap(find.text(kDrcWithdraw).first);
      await tester.pumpAndSettle();

      expect(
        doc.ackedFindings,
        isEmpty,
        reason: 'the two directions of one state, and both now reachable',
      );
    });

    testWidgets('a PROJECT-WIDE mute is about no entity at all', (
      tester,
    ) async {
      // A MUTATION NAMED THIS GAP. Dropping the `projectWide ? null`
      // ternary, so a project-wide mute kept the rack it happened to be
      // raised on, SURVIVED: nothing here exercised the second scope.
      // The command's own contract is that "a project-wide mute is about
      // no entity at all", and a stored entity would select that rack
      // when somebody clicks the row.
      final doc = _document();
      await pump(tester, doc);
      await openDrawer(tester);

      await tester.tap(find.text(kDrcAcknowledge).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ackScopeProjectWide('PWR-003')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Agreed on site: the strip is existing and stays.',
      );
      await tester.pumpAndSettle();
      await tester.tap(dialogConfirm());
      await tester.pumpAndSettle();

      expect(doc.ackedFindings, hasLength(1));
      final ack = doc.ackedFindings.values.first;
      expect(ack.targetFingerprint, kProjectWideFingerprint);
      expect(
        ack.targetEntityId,
        isNull,
        reason: 'a project-wide mute is about no entity at all',
      );
      expect(ack.reason, isNotEmpty, reason: 'CR-019 requires it here');
    });

    testWidgets('cancelling the dialog writes nothing', (tester) async {
      final doc = _document();
      await pump(tester, doc);
      await openDrawer(tester);

      await tester.tap(find.text(kDrcAcknowledge).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(doc.ackedFindings, isEmpty);
    });
  });

  group("`#875`: PWR-003's remedy reaches the document", () {
    testWidgets('the remedy button is THERE, and it asks which', (
      tester,
    ) async {
      final doc = _document();
      await pump(tester, doc);
      await openDrawer(tester);

      expect(find.text(FindingRemedy.addRackPdu.label), findsOneWidget);
      await tester.tap(find.text(FindingRemedy.addRackPdu.label));
      await tester.pumpAndSettle();

      expect(
        find.text(kAddOutletsTitle),
        findsOneWidget,
        reason:
            'the rack provides nothing, and addOutletsToRack refuses to '
            'choose between a strip and a PDU on somebody behalf',
      );
    });

    testWidgets('choosing the rack PDU places one, and it is ONE undo entry', (
      tester,
    ) async {
      final doc = _document();
      final before = doc.devices.length;
      await pump(tester, doc);
      await openDrawer(tester);

      await tester.tap(find.text(FindingRemedy.addRackPdu.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_pduKey));
      await tester.pumpAndSettle();

      expect(doc.devices, hasLength(before + 1));
      expect(
        doc.racks[_rack]!.zeroUChannels,
        isNotEmpty,
        reason:
            'a 0U PDU needs a channel and the remedy mints one, which is '
            'the only path in the product that builds '
            'AddZeroUChannelCommand',
      );
    });

    testWidgets('and cancelling the question writes NOTHING, not even an '
        'empty undo entry', (tester) async {
      final doc = _document();
      final before = doc.devices.length;
      await pump(tester, doc);
      await openDrawer(tester);

      await tester.tap(find.text(FindingRemedy.addRackPdu.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(doc.devices, hasLength(before));
      expect(doc.racks[_rack]!.zeroUChannels, isEmpty);
    });
  });
}

const Key _pduKey = ValueKey('add-outlets-pdu');
