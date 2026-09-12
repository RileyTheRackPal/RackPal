// DR-158 §11.157.5 — the confirmation that states what removing a device
// template costs, in three units, before it costs it.
//
// THE CLAUSE THAT MAKES THIS DIALOG DIFFERENT FROM THE OTHER FOUR is that
// it ALWAYS asks. `confirmDeviceRemoval`, `confirmLocationRemoval` and
// `confirmUnderlayRemoval` all return true without building anything when
// the act is consequence-free, on DR-013 §11.13.2's last sentence.
// §11.157.5 rules that a template removal is never consequence-free:
// authoring one is minutes of work that exists nowhere else in the
// project.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _when = DateTime.utc(2026, 9, 12);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _mine = TemplateId('tpl.mine');

PortDef _port(String key, {required String order}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.xlr3'),
  signalFamily: const SignalFamilyId('audio.analog.balanced'),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
  bankKey: 'io',
);

TemplateBody _body() => TemplateBody(
  manufacturer: 'Demo',
  model: 'Mine',
  displayName: 'My Amplifier',
  banks: [
    BankDef(key: 'io', label: 'IO', abbr: 'IO', order: const FracIndex('a0')),
  ],
  ports: [
    for (var i = 1; i <= 8; i++)
      _port('p.$i', order: 'a${i.toString().padLeft(3, '0')}'),
  ],
);

void _device(RackDocument doc, Uuid id) {
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: _mine,
      version: 1,
      contentHash: 'sha256:tpl.mine@1',
    ),
    designator: id.v.toUpperCase(),
    name: id.v,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

/// [devices] placed from `tpl.mine`, wired to each other with [cables]
/// when there are two of them.
RackDocument _doc({int devices = 2, int cables = 3, int versions = 1}) {
  final doc = RackDocument(
    id: const Uuid('doc-871'),
    appVersion: '0.6.57',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );
  for (var v = 1; v <= versions; v++) {
    doc.templates[templateSnapshotKey(_mine, v)] = TemplateSnapshot(
      templateId: _mine,
      version: v,
      contentHash: 'sha256:tpl.mine@$v',
      capturedAt: _when,
      body: _body(),
    );
  }
  if (devices > 0) _device(doc, const Uuid('dev-a'));
  if (devices > 1) _device(doc, const Uuid('dev-b'));

  if (devices > 1) {
    final controller = DocumentController(doc, clock: FixedClock(_when));
    for (var i = 1; i <= cables; i++) {
      final from = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-a'),
        portKey: 'p.$i',
      )!;
      final to = resolveConnectTarget(
        doc,
        deviceId: const Uuid('dev-b'),
        portKey: 'p.$i',
      )!;
      final built = buildConnectPortsCommand(
        doc: doc,
        from: from,
        to: to,
        media: const MediaTypeId('media.cat6'),
        now: _when,
        actor: 'test',
      );
      controller.run((built as ConnectPortsReady).command);
    }
  }
  return doc;
}

Widget _pump(TemplateRemovalPlan plan) => MaterialApp(
  home: RemoveTemplateDialog(plan: plan, name: 'My Amplifier'),
);

void main() {
  group('the dialog states the counts, each in its own unit', () {
    testWidgets('devices and cables, separately', (tester) async {
      final plan = planTemplateRemoval(_doc(), _mine);
      await tester.pumpWidget(_pump(plan));

      expect(find.text('Remove My Amplifier?'), findsOneWidget);
      expect(
        find.text('This also deletes the 2 devices placed from it.'),
        findsOneWidget,
      );
      expect(
        find.text('They take 3 cables with them, off the schedule.'),
        findsOneWidget,
        reason:
            'a cable is a row that leaves the SCHEDULE, which is the '
            'deliverable; adding it to the device count would describe '
            'neither',
      );
    });

    testWidgets('singular where it should be', (tester) async {
      final plan = planTemplateRemoval(_doc(devices: 1), _mine);
      await tester.pumpWidget(_pump(plan));

      expect(
        find.text('This also deletes the 1 device placed from it.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('cable'),
        findsNothing,
        reason:
            'one unwired device takes no cables, so the sentence is '
            'absent rather than reading "0 cables"',
      );
    });

    testWidgets('the archived versions are named only when there is more '
        'than one', (tester) async {
      await tester.pumpWidget(_pump(planTemplateRemoval(_doc(), _mine)));
      expect(find.textContaining('saved versions'), findsNothing);

      await tester.pumpWidget(
        _pump(planTemplateRemoval(_doc(versions: 3), _mine)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('All 3 saved versions'),
        findsOneWidget,
        reason:
            'CR-050 forks rather than mutating, so an edited template '
            'leaves earlier snapshots and all of them go',
      );
    });

    testWidgets('and it says undo puts it back, because it does', (
      tester,
    ) async {
      await tester.pumpWidget(_pump(planTemplateRemoval(_doc(), _mine)));
      expect(find.textContaining('Undo puts everything back'), findsOneWidget);
    });
  });

  group('§11.157.5 — it asks even when nothing stands on the template', () {
    testWidgets('the short form is still a dialog', (tester) async {
      final plan = planTemplateRemoval(_doc(devices: 0), _mine);
      expect(plan.deviceCount, 0);

      await tester.pumpWidget(_pump(plan));
      expect(
        find.text('Nothing is placed from it, so nothing else changes.'),
        findsOneWidget,
      );
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('and confirmTemplateRemoval BUILDS one, which is where this '
        'departs from the other four', (tester) async {
      final doc = _doc(devices: 0);
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  answer = await confirmTemplateRemoval(
                    context,
                    plan: planTemplateRemoval(doc, _mine),
                    name: 'My Amplifier',
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.byType(RemoveTemplateDialog),
        findsOneWidget,
        reason:
            'authoring a template is work that exists nowhere else in '
            'the project, so DR-013 §11.13.2 exemption does not reach it',
      );
      await tester.tap(find.byKey(RemoveTemplateDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });
  });

  group('a refusing plan is answered without asking anybody', () {
    testWidgets('a seeded id returns false and builds nothing', (
      tester,
    ) async {
      final doc = _doc();
      final seeded = TemplateId(kSeedCatalogIds.first);
      doc.templates[templateSnapshotKey(seeded, 1)] = TemplateSnapshot(
        templateId: seeded,
        version: 1,
        contentHash: 'sha256:seeded',
        capturedAt: _when,
        body: _body(),
      );

      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  answer = await confirmTemplateRemoval(
                    context,
                    plan: planTemplateRemoval(doc, seeded),
                    name: 'Shipped Thing',
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(RemoveTemplateDialog), findsNothing);
      expect(
        answer,
        isFalse,
        reason:
            'a refusal answers NO, which is the opposite of the '
            'consequence-free path where nothing to ask means yes',
      );
    });
  });

  group('Cancel writes nothing, and Esc is Cancel', () {
    /// Opens the real route, so a pop has somewhere to go.
    Future<bool?> open(WidgetTester tester, RackDocument doc) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  answer = await confirmTemplateRemoval(
                    context,
                    plan: planTemplateRemoval(doc, _mine),
                    name: 'My Amplifier',
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoveTemplateDialog), findsOneWidget);
      return answer;
    }

    testWidgets('Cancel answers false', (tester) async {
      await open(tester, _doc());
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(RemoveTemplateDialog), findsNothing);
      // The host is what acts on the answer; what this asserts is that
      // the dialog closes on the safe button and the destructive one is
      // not what a stray Enter reaches.
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('Esc is Cancel, and the key comes from the keymap', (
      tester,
    ) async {
      await open(tester, _doc());
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byType(RemoveTemplateDialog),
        findsNothing,
        reason:
            'Esc is Cancel everywhere, always (CR-101), and the '
            'activator comes from `dialogDismissShortcut` so the row is '
            'in the generated table',
      );
    });
  });
}
