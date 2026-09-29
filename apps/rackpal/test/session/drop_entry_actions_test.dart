// M3-A/6, #575 — the APP is the caller that drives
// `buildAddHomeRunCommand`.
//
// #575's own words: "The command layer is done. **Nothing in the app
// calls it.** ... This task should not invent a second entry surface; it
// should be the caller that loop drives."
//
// So this file tests the caller and nothing else. The loop itself is
// #147's and is tested in `rackpal_ui`; what was never tested is the
// twenty lines in `drop_entry_actions.dart` that stand between a typed
// line and the undo stack — and one of them was wrong, which is why this
// file exists rather than a note saying #147 covered it.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/drop_entry_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';

final DateTime _when = DateTime.utc(2026, 8, 7, 9, 30);

DocumentController _controller({String code = 'LR'}) {
  final doc = RackDocument(
    id: const Uuid('doc-575'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'seed'),
  )..registries = buildSeedRegistries();

  AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _when,
    actor: 'seed',
  ).apply(doc);
  AddLocationCommand(
    name: 'Living Room',
    code: code,
    order: nextLocationOrder(doc),
    now: _when,
    actor: 'seed',
  ).apply(doc);

  // A FIXED CLOCK AND A NAMED ACTOR, because both are the thing under
  // test: they must reach `EntityMeta` and the preview's must not.
  return DocumentController(
    doc,
    clock: FixedClock(_when),
    actor: 'the-integrator',
  );
}

DropLineParsed _line(String text) => parseDropLine(text) as DropLineParsed;

void main() {
  group('the caller reaches buildAddHomeRunCommand', () {
    test('a typed line becomes drops on the document', () {
      final c = _controller();
      final actions = buildDropEntryActions(controller: c);

      final result = actions.onCommit(
        _line('Living Room: 4x Cat6, 2x RG6'),
      );

      expect(result, isA<DropLinePlanReady>());
      expect(c.doc.links, hasLength(6));
      // AC-019: the origin lives ON the Link, which is what proves these
      // came through `buildAddHomeRunCommand` and not some other path.
      for (final l in c.doc.links.values) {
        expect(l.structureOrigin, isNotNull);
      }
    });

    test('a refusal changes nothing and is RETURNED, not thrown', () {
      final c = _controller();
      final actions = buildDropEntryActions(controller: c);

      final result = actions.onCommit(_line('Living Room: 2x Cat9'));

      expect(result, isA<DropLinePlanRefused>());
      expect(c.doc.links, isEmpty);
      expect(
        c.undo.canUndo,
        isFalse,
        reason: 'a refusal must not spend an undo',
      );
    });
  });

  group('THE DEFECT THIS TASK FOUND: whose name is on the cable', () {
    test("every drop records the CONTROLLER's actor, never the preview's", () {
      // THE BUG, PINNED. The panel re-plans on every keystroke to draw
      // its preview, and does it with `actor: 'preview'` and a throwaway
      // `DateTime.now()`. Those two values are not cosmetic: they are
      // written into `EntityMeta.updatedBy` and `.createdAt` on every
      // command the plan carries. Committing the PREVIEW's commands
      // stamped the literal string `preview` onto sixty cables, and no
      // gate in this repository would have noticed — the labels, the W
      // numbers and the byte round-trip are all identical either way.
      //
      // The fix is that `onCommit` takes the LINE and this layer re-plans
      // against its own clock and actor.
      final c = _controller();
      buildDropEntryActions(
        controller: c,
      ).onCommit(_line('Living Room: 3x Cat6'));

      for (final l in c.doc.links.values) {
        expect(l.meta.updatedBy, 'the-integrator');
        expect(l.meta.createdAt, _when);
      }
      expect(c.doc.outlets.values.single.meta.updatedBy, 'the-integrator');
    });

    test('and so does the outlet the line created', () {
      final c = _controller();
      buildDropEntryActions(
        controller: c,
      ).onCommit(_line('Living Room: 2x Cat6'));

      expect(c.doc.outlets.values.single.meta.createdAt, _when);
    });
  });

  group('one line is one undo entry', () {
    test('undo takes back the whole line, cables and outlet together', () {
      // What a person means by "undo that line". Nine drops undone one at
      // a time would leave an outlet with no cables on it, which is a
      // state nothing in the product creates on purpose.
      final c = _controller();
      final actions = buildDropEntryActions(controller: c);
      actions.onCommit(_line('Living Room: 4x Cat6, 2x RG6, 1x 22/4'));

      expect(c.doc.links, hasLength(7));
      expect(c.doc.outlets, hasLength(1));

      c.undoLast();

      expect(c.doc.links, isEmpty);
      expect(c.doc.outlets, isEmpty);
      expect(
        c.undo.canUndo,
        isFalse,
        reason: 'one line spent exactly one entry',
      );
    });

    test('two lines are two entries, undone newest first', () {
      final c = _controller();
      final actions = buildDropEntryActions(controller: c);
      actions.onCommit(_line('Living Room: 2x Cat6'));
      actions.onCommit(_line('Living Room: 3x RG6'));
      expect(c.doc.links, hasLength(5));

      c.undoLast();
      expect(c.doc.links, hasLength(2));
      expect(
        c.doc.links.values.every((l) => l.media.v == 'media.cat6'),
        isTrue,
        reason: 'the SECOND line came back, not part of the first',
      );
    });
  });

  group('the two offers', () {
    test('creating a room gives it a code, because the next act is to '
        'label nine cables', () {
      // The one place this layer guesses, and it is guessing because the
      // alternative is a dead stop: `{ROOM_ABBR}` reads `Location.code`,
      // and M3-B deliberately leaves it empty on a hand-made room. A room
      // created FROM a drop line is about to label cables.
      final c = _controller();
      final actions = buildDropEntryActions(controller: c);

      actions.onCreateLocation('Media Room');

      final made = c.doc.locations.values.firstWhere(
        (l) => l.name == 'Media Room',
      );
      expect(made.code, 'MR');

      // And the very next line now plans rather than refusing, which is
      // the whole point of guessing at all.
      expect(
        actions.onCommit(_line('Media Room: 2x Cat6')),
        isA<DropLinePlanReady>(),
      );
      expect(
        c.doc.links.values.map((l) => l.structureOrigin!.fieldLabel),
        ['MR-C6-1', 'MR-C6-2'],
      );
    });

    test('a project with no Structure device gets one, and then the line '
        'works', () {
      final doc = RackDocument(
        id: const Uuid('doc-bare'),
        appVersion: '0.1.0',
        createdAt: _when,
        modifiedAt: _when,
        meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 's'),
      )..registries = buildSeedRegistries();
      AddLocationCommand(
        name: 'Living Room',
        code: 'LR',
        order: nextLocationOrder(doc),
        now: _when,
        actor: 's',
      ).apply(doc);
      final c = DocumentController(
        doc,
        clock: FixedClock(_when),
        actor: 'the-integrator',
      );
      final actions = buildDropEntryActions(controller: c);

      expect(
        actions.onCommit(_line('Living Room: 2x Cat6')),
        isA<DropLinePlanNeedsStructure>(),
      );

      actions.onCreateStructure();
      expect(c.doc.structures, hasLength(1));
      expect(
        actions.onCommit(_line('Living Room: 2x Cat6')),
        isA<DropLinePlanReady>(),
      );
    });
  });

  // #945, CR-045. Both "create one" offers named the new body with a
  // literal 'STR-1', which ignored the project's designator format and
  // named it 'STR-1' even when a device already held that designator.
  // `allocateStructureDesignator` was written for exactly this and nothing
  // called it; the census of uncalled declarations is what found it.
  group("a new Structure is named by the project's own format (CR-045)", () {
    /// A project with NO Structure body yet, which is the only state the
    /// offer is made in (`_controller` above already has one).
    DocumentController bare() => DocumentController(
      RackDocument(
        id: const Uuid('doc-945'),
        appVersion: '0.1.0',
        createdAt: _when,
        modifiedAt: _when,
        meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'seed'),
      )..registries = buildSeedRegistries(),
      clock: FixedClock(_when),
      actor: 'the-integrator',
    );

    String createAndName(DocumentController c) {
      buildDropEntryActions(controller: c).onCreateStructure();
      final body = c.doc.structures.values.single;
      return c.doc.devices[body.deviceId]!.designator;
    }

    test('a default project still gets STR-1', () {
      expect(createAndName(bare()), 'STR-1');
    });

    test('a project that writes STR.01 gets STR.01, not STR-1', () {
      final c = bare();
      c.doc.settings
        ..designatorSeparator = '.'
        ..designatorPad = 2;
      expect(createAndName(c), 'STR.01');
    });

    test('a designator already in use is skipped, not duplicated', () {
      final c = bare();
      final taken = DeviceInstance(
        id: const Uuid('dev-already-str-1'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.other'),
          version: 1,
          contentHash: 'sha256:other',
        ),
        designator: 'STR-1',
        name: 'Somebody else',
        placement: const OffRackPlacement(),
        meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'seed'),
      );
      c.doc.devices[taken.id] = taken;
      expect(createAndName(c), 'STR-2');
    });
  });

  group('initialsFor', () {
    test('multi-word rooms take one letter each', () {
      expect(initialsFor('Living Room'), 'LR');
      expect(initialsFor('Primary Bedroom Closet'), 'PBC');
    });

    test('a single word takes up to three letters, because one is not a '
        'code anybody would write', () {
      expect(initialsFor('Attic'), 'ATT');
      expect(initialsFor('Garage'), 'GAR');
    });

    test('a word shorter than three letters is not padded or truncated', () {
      expect(initialsFor('Ha'), 'HA');
    });

    test('extra whitespace does not become an empty initial', () {
      expect(initialsFor('  Living   Room  '), 'LR');
    });

    test('an empty name yields an empty code rather than throwing', () {
      // The refusal path stays reachable: a room with no code refuses
      // with "needs a short code" instead of crashing the entry surface.
      expect(initialsFor('   '), '');
    });
  });
}
