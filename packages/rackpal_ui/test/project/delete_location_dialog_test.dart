// M3-B/2, #145 — DR-021 §11.20.3's confirmation.
//
// Three claims, and the third is the one that would be easy to get wrong
// in a way nobody notices:
//
//   1. a location that costs nothing is not asked about at all;
//   2. both counts appear, in their own sentences, in the units the plan
//      supplies them in;
//   3. the sentence for the referring entities says they LOSE THEIR ROOM,
//      never that they are deleted. DR-021 §11.20.6 deletes no rack, cable,
//      outlet or pathway, so a dialog implying otherwise would describe a
//      cascade the ruling explicitly refuses to perform, and the user would
//      cancel a safe delete out of a fear the product invented.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _when = DateTime.utc(2026, 8, 6);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-delete-location-dialog'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

Uuid _add(RackDocument doc, String name, {Uuid? parent}) => (AddLocationCommand(
  name: name,
  code: name.substring(0, 2).toUpperCase(),
  order: nextLocationOrder(doc, parentId: parent),
  parentId: parent,
  now: _when,
  actor: 'seed',
)..apply(doc)).id;

void _addRack(RackDocument doc, String id, Uuid where) {
  doc.racks[Uuid(id)] = Rack(
    id: Uuid(id),
    name: 'Rack',
    designator: id.toUpperCase(),
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
    locationId: where,
  );
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('a location that costs nothing is never asked about', (
    tester,
  ) async {
    // DR-013 §11.13.2's last sentence, applied here. A prompt for a
    // consequence-free delete is the nag that teaches people to click
    // through prompts, including this one on the day it matters.
    final doc = _doc();
    final shed = _add(doc, 'Shed');
    final plan = planLocationRemoval(doc, shed);
    bool? answer;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await confirmLocationRemoval(
                context,
                plan: plan,
                name: 'Shed',
              );
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(find.byType(DeleteLocationDialog), findsNothing);
  });

  testWidgets('the subtree count is its own sentence', (tester) async {
    final doc = _doc();
    final house = _add(doc, 'Main House');
    _add(doc, 'Level 1', parent: house);
    _add(doc, 'Living Room', parent: house);

    await tester.pumpWidget(
      _app(
        DeleteLocationDialog(
          plan: planLocationRemoval(doc, house),
          name: 'Main House',
        ),
      ),
    );

    expect(find.text('Delete Main House?'), findsOneWidget);
    expect(
      find.text('This also deletes 2 locations inside it.'),
      findsOneWidget,
    );
  });

  testWidgets('one child is singular, because a dialog that says "1 '
      'locations" reads as a bug', (tester) async {
    final doc = _doc();
    final house = _add(doc, 'Main House');
    _add(doc, 'Level 1', parent: house);

    await tester.pumpWidget(
      _app(
        DeleteLocationDialog(
          plan: planLocationRemoval(doc, house),
          name: 'Main House',
        ),
      ),
    );

    expect(
      find.text('This also deletes 1 location inside it.'),
      findsOneWidget,
    );
  });

  testWidgets('the referring entities LOSE THEIR ROOM and are not deleted', (
    tester,
  ) async {
    // The claim this file exists for. DR-021 §11.20.6 deletes no rack.
    final doc = _doc();
    final room = _add(doc, 'Living Room');
    _addRack(doc, 'rk-1', room);
    _addRack(doc, 'rk-2', room);

    await tester.pumpWidget(
      _app(
        DeleteLocationDialog(
          plan: planLocationRemoval(doc, room),
          name: 'Living Room',
        ),
      ),
    );

    expect(find.text('2 items lose their room.'), findsOneWidget);
    expect(
      find.textContaining('cables, racks and outlets stay'),
      findsOneWidget,
    );
  });

  testWidgets('Cancel returns false, Delete returns true', (tester) async {
    final doc = _doc();
    final house = _add(doc, 'Main House');
    _add(doc, 'Level 1', parent: house);
    final plan = planLocationRemoval(doc, house);

    for (final (label, expected) in [('Cancel', false), ('Delete', true)]) {
      bool? answer;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await confirmLocationRemoval(
                  context,
                  plan: plan,
                  name: 'Main House',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(answer, expected, reason: label);
    }
  });
}
