// DR-160 §11.159.5 — the two confirmations that state what a plate and a
// panel cost, before they cost it. Board `#877`.
//
// THE CLAUSE THAT MAKES THEM DIFFERENT FROM EACH OTHER is when they ask.
// A BARE PLATE IS NOT ASKED ABOUT, on DR-013 §11.13.2's last sentence,
// which `confirmDeviceRemoval`, `confirmLocationRemoval` and
// `confirmUnderlayRemoval` all already obey. AN EMPTY PANEL IS: it is the
// container the tab is named for, and re-creating one is a different
// order of work from re-typing a drop.
//
// EVERY COUNT COMES OFF A REAL PLAN, never off a hand-made one. A dialog
// test that constructed its own `OutletRemovalPlan` would prove the
// sentence and nothing about whether the sentence is true of the
// document, which is the whole reason §11.159.5 makes the two one object.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _when = DateTime.utc(2026, 9, 13);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _bodyId = Uuid('body-1');
const _deviceId = Uuid('device-1');
const _plate = Uuid('outlet-1');
const _bare = Uuid('outlet-bare');

/// One panel, one plate carrying [cables] drops, and a second BARE plate
/// when [bare] is set.
RackDocument _doc({int cables = 2, bool pinned = false, bool bare = false}) {
  final doc = RackDocument(
    id: const Uuid('doc-877'),
    appVersion: '0.6.60',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    registries: buildSeedRegistries(),
  );

  doc.devices[_deviceId] = DeviceInstance(
    id: _deviceId,
    templateRef: kStructureTemplateRef,
    designator: 'STR-1',
    name: 'Rough-In',
    kind: DeviceKind.structure,
    placement: const OffRackPlacement(),
    meta: _meta(),
    structureBodyId: _bodyId,
  );
  doc.structures[_bodyId] = StructureBody(
    id: _bodyId,
    deviceId: _deviceId,
    title: 'Rough-In',
    meta: _meta(),
  );

  doc.outlets[_plate] = Outlet(
    id: _plate,
    structureBodyId: _bodyId,
    designation: 'LR-1',
    order: const FracIndex('a0'),
    meta: _meta(),
    planPin: pinned
        ? const PlanPin(underlayId: Uuid('plan-1'), at: PxPt(10, 20))
        : null,
  );
  if (bare) {
    doc.outlets[_bare] = Outlet(
      id: _bare,
      structureBodyId: _bodyId,
      designation: 'KIT-1',
      order: const FracIndex('a1'),
      meta: _meta(),
    );
  }

  for (var i = 1; i <= cables; i++) {
    final linkId = Uuid('w$i');
    final netId = Uuid('n$i');
    doc.nets[netId] = Net(
      id: netId,
      name: 'N00$i',
      signalFamily: const SignalFamilyId('data.ethernet'),
      meta: _meta(),
    );
    doc.links[linkId] = Link(
      id: linkId,
      designator: 'W00$i',
      media: const MediaTypeId('media.cat6'),
      order: const FracIndex('a0'),
      meta: _meta(),
      conductors: [
        const Conductor(from: OpenEndpoint('f'), to: OpenEndpoint('r')),
      ],
      services: [
        Service(
          id: 's1',
          signalFamily: const SignalFamilyId('data.ethernet'),
          netId: netId,
        ),
      ],
      structureOrigin: StructureOrigin(
        structureBodyId: _bodyId,
        outletId: _plate,
        fieldLabel: 'LR-DATA-$i',
      ),
    );
  }
  return doc;
}

Widget _plateDialog(OutletRemovalPlan plan) => MaterialApp(
  home: RemoveOutletDialog(plan: plan, designation: 'LR-1'),
);

Widget _panelDialog(StructureRemovalPlan plan) => MaterialApp(
  home: RemoveStructureDialog(plan: plan, name: 'STR-1 · Rough-In'),
);

void main() {
  group('the plate dialog says what lands on it', () {
    testWidgets('the cable count, plural, in its own sentence', (tester) async {
      await tester.pumpWidget(
        _plateDialog(planOutletRemoval(_doc(), _plate)),
      );

      expect(find.text('Remove LR-1?'), findsOneWidget);
      expect(
        find.text(
          'This also deletes the 2 cables that land on it, off the schedule.',
        ),
        findsOneWidget,
        reason:
            'a cable is a row that leaves the SCHEDULE, which is the '
            'deliverable (DR-013 §11.13.2)',
      );
    });

    testWidgets('and singular when there is one', (tester) async {
      await tester.pumpWidget(
        _plateDialog(planOutletRemoval(_doc(cables: 1), _plate)),
      );

      expect(
        find.text(
          'This also deletes the 1 cable that lands on it, off the schedule.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('it says WHY the cables go, which is the whole argument', (
      tester,
    ) async {
      // §11.159.2. Nothing in the product can move a drop onto another
      // plate, so a cable left behind could never be re-homed. Saying so
      // is what makes this the smaller loss rather than a surprise.
      await tester.pumpWidget(
        _plateDialog(planOutletRemoval(_doc(), _plate)),
      );

      expect(
        find.textContaining('cannot be moved to another plate'),
        findsOneWidget,
      );
    });

    testWidgets('a PIN earns its own sentence and is never a count', (
      tester,
    ) async {
      // A plate carries at most one, so "1 pin" would be a number that
      // can only ever be one.
      await tester.pumpWidget(
        _plateDialog(planOutletRemoval(_doc(pinned: true), _plate)),
      );

      expect(
        find.text('Its pin on the floorplan goes with it.'),
        findsOneWidget,
      );
    });

    testWidgets('and no pin means no sentence about one', (tester) async {
      await tester.pumpWidget(
        _plateDialog(planOutletRemoval(_doc(), _plate)),
      );

      expect(find.textContaining('floorplan'), findsNothing);
    });

    testWidgets('a BARE plate is removed with no dialog at all', (
      tester,
    ) async {
      // DR-013 §11.13.2's last sentence: a prompt for a
      // consequence-free delete is the nag that teaches people to click
      // through prompts, including this one on the day it matters.
      final doc = _doc(bare: true);
      var answer = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await confirmOutletRemoval(
                  context,
                  plan: planOutletRemoval(doc, _bare),
                  designation: 'KIT-1',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(answer, isTrue, reason: 'it proceeds, it does not refuse');
    });

    testWidgets('a plate this document does not hold REFUSES rather than '
        'proceeding', (tester) async {
      // The other half of the same guard, and the two must not be one
      // answer: "nothing to ask about" and "nothing to remove" are
      // opposite outcomes.
      var answer = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await confirmOutletRemoval(
                  context,
                  plan: planOutletRemoval(_doc(), const Uuid('gone')),
                  designation: 'nowhere',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(answer, isFalse);
    });
  });

  group('the panel dialog says plates, cables and pins', () {
    testWidgets('three counts in three units, and they are not summed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _panelDialog(
          planStructureRemoval(_doc(pinned: true, bare: true), _bodyId),
        ),
      );

      expect(find.text('Remove STR-1 · Rough-In?'), findsOneWidget);
      expect(
        find.text('This also deletes the 2 plates on it.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'The 2 cables out of this panel go with it, off the schedule.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('1 of those plates is pinned on the floorplan.'),
        findsOneWidget,
      );
    });

    testWidgets('the pin sentence is absent when nothing is pinned', (
      tester,
    ) async {
      await tester.pumpWidget(
        _panelDialog(planStructureRemoval(_doc(), _bodyId)),
      );

      expect(find.textContaining('pinned on the floorplan'), findsNothing);
    });

    testWidgets('an EMPTY panel gets the short form and STILL asks', (
      tester,
    ) async {
      // Where this departs from the plate dialog above it (§11.159.5).
      final doc = _doc(cables: 0);
      doc.outlets.clear();

      await tester.pumpWidget(
        _panelDialog(planStructureRemoval(doc, _bodyId)),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Nothing is on it, so nothing else changes.'),
        findsOneWidget,
      );
      expect(find.textContaining('plates on it'), findsNothing);
    });

    testWidgets('a body this document does not hold REFUSES', (tester) async {
      var answer = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await confirmStructureRemoval(
                  context,
                  plan: planStructureRemoval(_doc(), const Uuid('gone')),
                  name: 'nowhere',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(answer, isFalse);
    });
  });
}
