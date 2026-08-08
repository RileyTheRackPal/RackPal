// M3-C/1, #147 — the repeat-entry loop, driven by a keyboard.
//
// #147's instruction is not "build a text field". It is: *"write the loop
// first, drive it with a keyboard, and time ten drops on a stub UI. If
// ten drops are not on pace, no amount of table polish will make sixty."*
//
// WHAT A TEST CAN AND CANNOT MEASURE, STATED SO NOTHING IS OVERCLAIMED.
// It cannot time a person. Fifteen seconds per drop INCLUDING thinking is
// a human fact and board #163 (M3-G/1) is the drill that measures it.
// What a test CAN measure is the part the design actually controls: how
// many keystrokes the surface demands per drop, and whether the loop
// closes without a click. Those are gated below. The rest is M3-G's.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final DateTime _now = DateTime.utc(2026, 8, 7);

RackDocument _project({
  List<(String, String)> rooms = const [('Living Room', 'LR')],
}) {
  final doc = RackDocument(
    id: const Uuid('doc-entry'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't'),
  )..registries = buildSeedRegistries();

  AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 't',
  ).apply(doc);

  for (final (name, code) in rooms) {
    AddLocationCommand(
      name: name,
      code: code,
      order: nextLocationOrder(doc),
      now: _now,
      actor: 't',
    ).apply(doc);
  }
  return doc;
}

/// The harness the panel drives: it applies what it is given and records
/// what it was asked to do, which is all the app layer does too.
final class _Harness {
  _Harness(this.doc);

  final RackDocument doc;
  final List<String> createdLocations = [];
  final List<String> recent = [];
  int commits = 0;
  int structuresRequested = 0;

  /// Whether `onCreateStructure` actually adds a body, or only counts the
  /// request. COUNTING IS THE DEFAULT because every other test here
  /// starts from a project that already has one; the arm that creates for
  /// real is what the offer arms' re-plan is tested through.
  bool createsStructureForReal = false;

  DropEntryActions get actions => DropEntryActions(
    // THE APP'S SHAPE, NOT THE PREVIEW'S: it re-plans against its own
    // clock and actor and returns what it did. `apps/rackmate`'s real
    // `buildDropEntryActions` does exactly this; the harness mirrors it
    // so the panel is driven the way it will be driven.
    onCommit: (line) {
      final plan = planDropLine(
        doc: doc,
        line: line,
        now: _now,
        actor: 'committer',
      );
      if (plan is! DropLinePlanReady) return plan;
      for (final c in plan.commands) {
        c.apply(doc);
      }
      commits++;
      recent.insert(0, plan.fieldLabels.join(', '));
      return plan;
    },
    onCreateLocation: (name) {
      createdLocations.add(name);
      AddLocationCommand(
        name: name,
        code: name.split(' ').map((w) => w[0]).join().toUpperCase(),
        order: nextLocationOrder(doc),
        now: _now,
        actor: 't',
      ).apply(doc);
    },
    onCreateStructure: () {
      structuresRequested++;
      if (!createsStructureForReal) return;
      AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: _now,
        actor: 't',
      ).apply(doc);
    },
  );
}

Future<void> _pumpPanel(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DropEntryPanel(
            // A NEW LIST EACH BUILD is deliberate: the panel must notice a
            // document that moved under it, and `identical` on the doc is
            // how it does. The app rebuilds the same way.
            doc: h.doc,
            actions: DropEntryActions(
              onCommit: (line) {
                final r = h.actions.onCommit(line);
                setState(() {});
                return r;
              },
              onCreateLocation: (n) =>
                  setState(() => h.actions.onCreateLocation(n)),
              onCreateStructure: () =>
                  setState(() => h.actions.onCreateStructure()),
            ),
            recent: h.recent,
          ),
        ),
      ),
    ),
  );
}

/// Types [line] and presses Enter, exactly as a person would.
Future<void> _type(WidgetTester tester, String line) async {
  await tester.enterText(find.byType(TextField), line);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  group('the loop closes', () {
    testWidgets('a committed line clears the field and keeps focus', (
      tester,
    ) async {
      // THE WHOLE FEATURE. M1's drill was refuted because each placement
      // broke the loop; if the next line needs a click, sixty drops need
      // sixty clicks.
      final h = _Harness(_project());
      await _pumpPanel(tester, h);

      await _type(tester, 'Living Room: 4x Cat6');

      expect(h.commits, 1);
      expect(h.doc.links, hasLength(4));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('six lines in a row, with no interaction between them', (
      tester,
    ) async {
      final h = _Harness(
        _project(
          rooms: const [
            ('Living Room', 'LR'),
            ('Kitchen', 'KIT'),
            ('Office', 'OFF'),
            ('Primary Bedroom', 'MBR'),
            ('Attic', 'ATT'),
            ('Exterior', 'EXT'),
          ],
        ),
      );
      await _pumpPanel(tester, h);

      for (final line in const [
        'Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4',
        'Kitchen: 2x Cat6, 1x RG6, 1x 22/4',
        'Office: 4x Cat6, 1x RG6, 1x 22/4',
        'Primary Bedroom: 2x Cat6, 2x RG6, 1x 16/4',
        'Attic: 3x Cat6',
        'Exterior: 6x Cat6',
      ]) {
        await _type(tester, line);
      }

      expect(h.commits, 6);
      expect(h.doc.links, hasLength(33));
      // Every label is unique across all six lines, which is CR-113's
      // project-wide rule surviving a loop that never re-read the
      // document between lines.
      final labels = {
        for (final l in h.doc.links.values) l.structureOrigin!.fieldLabel,
      };
      expect(labels, hasLength(33));
    });

    testWidgets('A REFUSAL DOES NOT CLEAR THE FIELD', (tester) async {
      // Clearing on error is how a surface makes a person retype nine
      // drops because they wrote `Cat9`.
      final h = _Harness(_project());
      await _pumpPanel(tester, h);

      await _type(tester, 'Living Room: 4x Cat6, 1x Cat9');

      expect(h.commits, 0);
      expect(h.doc.links, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Living Room: 4x Cat6, 1x Cat9',
      );
      expect(find.textContaining('"Cat9"'), findsOneWidget);
    });
  });

  group('the preview', () {
    testWidgets('shows the LABELS before Enter, not just a count', (
      tester,
    ) async {
      // CR-048 stores a designator once at creation, so this is the last
      // cheap moment a wrong room code costs one keystroke.
      final h = _Harness(_project());
      await _pumpPanel(tester, h);

      await tester.enterText(find.byType(TextField), 'Living Room: 4x Cat6');
      await tester.pump();

      expect(find.textContaining('4 drops'), findsOneWidget);
      expect(find.textContaining('LR-C6-1'), findsOneWidget);
      expect(find.textContaining('LR-C6-4'), findsOneWidget);
      expect(h.doc.links, isEmpty, reason: 'preview must not apply anything');
    });

    testWidgets('updates as the document moves under it', (tester) async {
      // The second line must not offer labels the first line just spent.
      final h = _Harness(_project());
      await _pumpPanel(tester, h);
      await _type(tester, 'Living Room: 2x Cat6');

      await tester.enterText(find.byType(TextField), 'Living Room: 1x Cat6');
      await tester.pump();

      expect(find.textContaining('LR-C6-3'), findsOneWidget);
    });

    testWidgets('an unknown room reads as an OFFER, not an error', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pumpPanel(tester, h);

      await tester.enterText(find.byType(TextField), 'Attic: 3x Cat6');
      await tester.pump();
      expect(find.textContaining('Enter creates it'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(h.createdLocations, ['Attic']);
    });

    testWidgets('a warning is shown, never swallowed', (tester) async {
      final h = _Harness(_project());
      await _pumpPanel(tester, h);

      await tester.enterText(
        find.byType(TextField),
        'Living Room: 1x Cat6 @wall=north',
      );
      await tester.pump();

      expect(find.textContaining('does not understand'), findsOneWidget);
    });
  });

  group('THE MEASUREMENT #147 ASKED FOR', () {
    testWidgets('sixty drops cost 349 keystrokes, which is 5.82 each', (
      tester,
    ) async {
      // WHAT THIS IS AND IS NOT. It does not time a person: fifteen
      // seconds per drop including thinking is a human fact, and board
      // #163 (M3-G/1) is the drill that measures it. This measures the
      // part the SURFACE controls — how much typing sixty drops demands —
      // because that is the thing that could make the drill impossible
      // before anyone ran it.
      //
      // THE NUMBER IS MEASURED AND THEN PINNED, in that order. The first
      // version of this test asserted "under four" because four sounded
      // right; the real figure is 5.82, and the assertion below is a
      // REGRESSION CEILING over the measurement rather than a target
      // somebody hoped for. No comparison against the table mode of
      // board #148 is made here, because that table does not exist yet
      // and a number invented for it would be worth less than nothing.
      const drill = [
        'Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4',
        'Kitchen: 2x Cat6, 1x RG6, 1x 16/4, 1x 22/4',
        'Office: 4x Cat6, 1x RG6, 1x 22/4',
        'Primary Bedroom: 2x Cat6, 2x RG6, 1x 16/4, 1x 22/4',
        'Bedroom 2: 2x Cat6, 1x RG6, 1x 22/4',
        'Bedroom 3: 2x Cat6, 1x RG6',
        'Attic: 3x Cat6',
        'Exterior: 6x Cat6',
        'Garage: 4x Cat6, 2x RG6, 1x 22/4',
        'Media Room: 4x Cat6, 2x RG6, 4x 16/4, 1x 22/4',
      ];

      final h = _Harness(
        _project(
          rooms: const [
            ('Living Room', 'LR'),
            ('Kitchen', 'KIT'),
            ('Office', 'OFF'),
            ('Primary Bedroom', 'MBR'),
            ('Bedroom 2', 'BR2'),
            ('Bedroom 3', 'BR3'),
            ('Attic', 'ATT'),
            ('Exterior', 'EXT'),
            ('Garage', 'GAR'),
            ('Media Room', 'MED'),
          ],
        ),
      );
      await _pumpPanel(tester, h);

      for (final line in drill) {
        await _type(tester, line);
      }

      // One keystroke per character, plus one Enter per line.
      final keystrokes = drill.fold(0, (n, l) => n + l.length) + drill.length;
      final drops = h.doc.links.length;

      expect(drops, 60, reason: "the drill's own size");
      expect(h.commits, drill.length);
      expect(keystrokes, 349, reason: 'the measurement, pinned exactly');
      expect(
        keystrokes / drops,
        lessThan(6.0),
        reason:
            '$keystrokes keystrokes for $drops drops = '
            '${(keystrokes / drops).toStringAsFixed(2)} each',
      );

      // AND THE LOOP NEVER BROKE: ten lines, ten commits, no clicks, and
      // the field is empty and focused at the end, ready for the
      // eleventh.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('typing the room CODE instead of its name is a sixth '
        'cheaper, which is why the planner resolves both', (tester) async {
      // 292 keystrokes against 349 for the same sixty drops. Worth a
      // gate because it is the one entry-rate lever a person can pull
      // without the surface changing, and because a later "tidy-up" that
      // made `_resolveLocation` match names only would cost 16% of the
      // drill and break nothing a test could otherwise see.
      const byCode = [
        'LR: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4',
        'KIT: 2x Cat6, 1x RG6, 1x 16/4, 1x 22/4',
        'OFF: 4x Cat6, 1x RG6, 1x 22/4',
        'MBR: 2x Cat6, 2x RG6, 1x 16/4, 1x 22/4',
        'BR2: 2x Cat6, 1x RG6, 1x 22/4',
        'BR3: 2x Cat6, 1x RG6',
        'ATT: 3x Cat6',
        'EXT: 6x Cat6',
        'GAR: 4x Cat6, 2x RG6, 1x 22/4',
        'MED: 4x Cat6, 2x RG6, 4x 16/4, 1x 22/4',
      ];

      final h = _Harness(
        _project(
          rooms: const [
            ('Living Room', 'LR'),
            ('Kitchen', 'KIT'),
            ('Office', 'OFF'),
            ('Primary Bedroom', 'MBR'),
            ('Bedroom 2', 'BR2'),
            ('Bedroom 3', 'BR3'),
            ('Attic', 'ATT'),
            ('Exterior', 'EXT'),
            ('Garage', 'GAR'),
            ('Media Room', 'MED'),
          ],
        ),
      );
      await _pumpPanel(tester, h);
      for (final line in byCode) {
        await _type(tester, line);
      }

      final keystrokes = byCode.fold(0, (n, l) => n + l.length) + byCode.length;
      expect(h.doc.links, hasLength(60));
      expect(keystrokes, 292);
      expect(keystrokes, lessThan(349));
    });

    testWidgets('and every one of the sixty carries both a W number and a '
        'field label', (tester) async {
      // AC-018's clause, at the artifact. A drop that reaches the
      // document without a label is a cable nobody can find on the wall.
      final h = _Harness(
        _project(rooms: const [('Living Room', 'LR'), ('Attic', 'ATT')]),
      );
      await _pumpPanel(tester, h);
      await _type(tester, 'Living Room: 4x Cat6, 2x RG6');
      await _type(tester, 'Attic: 3x Cat6');

      for (final l in h.doc.links.values) {
        expect(l.designator, isNotEmpty);
        expect(l.structureOrigin!.fieldLabel, isNotEmpty);
        // Unbound far end: AC-018's fourteen come from exactly here.
        expect(l.structureOrigin!.rackLabel, isNull);
      }
    });
  });

  group('taking an offer re-plans, so the next Enter commits', () {
    // THE DEFECT, AND WHY IT SURVIVED M3-C/1. `_plan` is computed from a
    // document that the offer arms have just mutated, and
    // `didUpdateWidget` cannot see it: commands mutate `RackDocument` in
    // place, so the reference stays `identical`. The commit arm is safe
    // only because it CLEARS the field and clearing fires the text
    // listener; the two offer arms keep the line on purpose, so nothing
    // was re-planning them.
    //
    // The blast radius was one Structure device per keypress. It went
    // unseen because every test here starts from a project that already
    // has one, which a real new project does not.

    /// A project with rooms and NO Structure body, which is what every
    /// new project is.
    RackDocument bare() {
      final doc = RackDocument(
        id: const Uuid('doc-no-structure'),
        appVersion: '0.1.0',
        createdAt: _now,
        modifiedAt: _now,
        meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't'),
      )..registries = buildSeedRegistries();
      AddLocationCommand(
        name: 'Living Room',
        code: 'LR',
        order: nextLocationOrder(doc),
        now: _now,
        actor: 't',
      ).apply(doc);
      return doc;
    }

    testWidgets('Enter creates the Structure device, Enter again the drops', (
      tester,
    ) async {
      final h = _Harness(bare())..createsStructureForReal = true;
      await _pumpPanel(tester, h);

      await _type(tester, 'Living Room: 4x Cat6');
      expect(h.doc.structures, hasLength(1));
      expect(h.doc.links, isEmpty, reason: 'the first Enter took the offer');

      // The line was kept, so the same key commits it.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        h.doc.structures,
        hasLength(1),
        reason: 'a second body is what a stale plan would have created',
      );
      expect(h.doc.links, hasLength(4));
    });

    testWidgets('and the same holds for a room it offers to create', (
      tester,
    ) async {
      final h = _Harness(_project(rooms: const []));
      await _pumpPanel(tester, h);

      await _type(tester, 'Attic: 3x Cat6');
      expect(h.createdLocations, ['Attic']);
      expect(h.doc.links, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        h.createdLocations,
        ['Attic'],
        reason: 'a stale plan would have created a second Attic',
      );
      expect(h.doc.links, hasLength(3));
    });
  });
}
