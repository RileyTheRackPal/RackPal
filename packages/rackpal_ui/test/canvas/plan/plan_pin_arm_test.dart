// PLAN-E/3: the drop-table-then-plan fast path (docs/15 §6, DR-141
// §11.140).
//
// The ruling this file is really about is that **the mode outlives the
// pin**. A one-shot request would pass a test that only pinned once, so
// the cases below pin and then look at what is still on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9, 8);
const _outletId = Uuid('out-1');
const _linkId = Uuid('lnk-1');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

const _armed = ArmedPin(outletId: _outletId, label: 'D-014');

/// A document with one outlet and one link that runs from it.
RackDocument _doc({bool withOrigin = true, bool withOutlet = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  if (withOutlet) {
    doc.outlets[_outletId] = Outlet(
      id: _outletId,
      structureBodyId: const Uuid('body-1'),
      designation: 'D-014',
      order: const FracIndex('a0'),
      meta: _meta(),
    );
  }
  doc.links[_linkId] = Link(
    id: _linkId,
    designator: 'W-001',
    media: const MediaTypeId('media.cat6'),
    order: const FracIndex('a0'),
    meta: _meta(),
    structureOrigin: withOrigin
        ? StructureOrigin(
            structureBodyId: const Uuid('body-1'),
            outletId: _outletId,
            fieldLabel: 'GR-DATA-1',
          )
        : null,
  );
  return doc;
}

Widget _chipHost(PlanPinArmController arm) => MaterialApp(
  home: Scaffold(
    body: AnimatedBuilder(
      animation: arm,
      builder: (context, _) => arm.isActive
          ? PlanPinArmChip(armed: arm.armed, onDismiss: arm.dismiss)
          : const SizedBox.shrink(),
    ),
  ),
);

void main() {
  group('the mode', () {
    test('starts off, and arming turns it on', () {
      final arm = PlanPinArmController();
      expect(arm.isActive, isFalse);
      expect(arm.armed, isNull);

      arm.arm(_armed);
      expect(arm.isActive, isTrue);
      expect(arm.armed, _armed);
    });

    test('OUTLIVES THE PIN, which is the whole ruling', () {
      // DR-141 §11.140.2. A one-shot request (schematic_reveal.dart's
      // `take()`) would leave `isActive` false here, and a test that only
      // ever pinned once could not tell the two apart.
      final arm = PlanPinArmController()
        ..arm(_armed)
        ..pinned();
      expect(arm.isActive, isTrue, reason: 'the chip must stay up');
      expect(arm.armed, isNull, reason: 'nothing is armed until re-picked');
    });

    test('does not auto-advance to another subject', () {
      // The declined design (DR-141 §11.140.2). If a later change made
      // `pinned()` arm the next unpinned outlet, this is where it shows.
      final arm = PlanPinArmController()
        ..arm(_armed)
        ..pinned();
      expect(arm.armed, isNull);
    });

    test('Esc is the only thing that ends it', () {
      final arm = PlanPinArmController()
        ..arm(_armed)
        ..pinned();
      expect(arm.isActive, isTrue);
      arm.dismiss();
      expect(arm.isActive, isFalse);
      expect(arm.armed, isNull);
    });

    test('arming a second drop replaces the first without confirmation', () {
      const other = ArmedPin(outletId: Uuid('out-2'), label: 'D-015');
      final arm = PlanPinArmController()
        ..arm(_armed)
        ..arm(other);
      expect(arm.armed, other);
    });

    test('a pin with nothing armed notifies nobody', () {
      // A stray plan click must not rebuild every listener to change
      // nothing.
      var notifications = 0;
      PlanPinArmController()
        ..addListener(() => notifications++)
        ..pinned();
      expect(notifications, 0);
    });
  });

  group('what a drop row arms', () {
    test('resolves the row to its OUTLET, not its link', () {
      // Rows are keyed by linkId and a pin hangs on an Outlet. The join is
      // Link.structureOrigin.outletId, which derived/structure_matrix.dart
      // already walks.
      expect(armSubjectFor(_doc(), _linkId), _outletId);
      expect(armRefusalFor(_doc(), _linkId), isNull);
    });

    test('a cable that runs to no outlet is REFUSED by name', () {
      // Not every row is a drop. A link with no StructureOrigin has no
      // outlet to carry a pin, and a row that silently does nothing is the
      // no-op docs/04 §3.4 forbids.
      final doc = _doc(withOrigin: false);
      expect(armSubjectFor(doc, _linkId), isNull);
      expect(
        armRefusalFor(doc, _linkId),
        contains('does not run to an outlet'),
      );
    });

    test('an origin naming a deleted outlet is refused, not dereferenced', () {
      final doc = _doc(withOutlet: false);
      expect(armSubjectFor(doc, _linkId), isNull);
      expect(armRefusalFor(doc, _linkId), contains('not in the project'));
    });

    test('a row for a link the document lost is refused', () {
      expect(armRefusalFor(_doc(), const Uuid('gone')), contains('any more'));
    });
  });

  group('the chip', () {
    testWidgets('names the armed drop, so the next click is not a guess', (
      tester,
    ) async {
      final arm = PlanPinArmController()..arm(_armed);
      await tester.pumpWidget(_chipHost(arm));
      expect(find.byKey(PlanPinArmChip.chipKey), findsOneWidget);
      expect(find.textContaining('D-014'), findsOneWidget);
    });

    testWidgets('after a pin it says what to do next, not merely that it is '
        'on', (tester) async {
      // The sentence IS the feature: the mode is left running so this
      // stays on screen, and "on with nothing armed" has to be
      // distinguishable from "failed".
      final arm = PlanPinArmController()..arm(_armed);
      await tester.pumpWidget(_chipHost(arm));
      arm.pinned();
      await tester.pump();

      expect(find.byKey(PlanPinArmChip.chipKey), findsOneWidget);
      expect(find.text(kPinArmIdleLabel), findsOneWidget);
      expect(find.textContaining('D-014'), findsNothing);
    });

    testWidgets('carries its own way out', (tester) async {
      // A mode whose exit is a keystroke nobody mentions is a mode people
      // quit by closing the project.
      final arm = PlanPinArmController()..arm(_armed);
      await tester.pumpWidget(_chipHost(arm));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(arm.isActive, isFalse);
      expect(find.byKey(PlanPinArmChip.chipKey), findsNothing);
    });
  });
}
