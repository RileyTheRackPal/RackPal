// M3-C/1, #147 — the repeat-entry loop, driven against a real document.
//
// THE PARSER TESTS PROVED THE TEXT READS. These prove the line becomes
// drops: nine `Link`s from one line, nine labels, one outlet, one undo
// entry, and DR-023's fallback chain in all three of its steps.
//
// WHAT IS DELIBERATELY ASSERTED AT THE ARTIFACT. Not "the planner called
// the allocator" but "the document afterwards holds these nine labels" —
// house style, and it matters here because the label chain has three
// sources and a test that pinned the intermediate would survive the
// chain being wired backwards.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 8, 7);

typedef _Project = ({RackDocument doc, Uuid bodyId, Uuid livingRoom});

/// A project with one Structure device and one room whose code is `LR`,
/// which is the minimum a drop line needs.
_Project _project({String code = 'LR', String name = 'Living Room'}) {
  final doc = RackDocument(
    id: const Uuid('doc-dsl'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  )..registries = buildSeedRegistries();

  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'test',
  )..apply(doc);

  final room = AddLocationCommand(
    name: name,
    code: code,
    order: nextLocationOrder(doc),
    now: _now,
    actor: 'test',
  )..apply(doc);

  return (doc: doc, bodyId: structure.bodyId, livingRoom: room.id);
}

DropLinePlan _plan(
  RackDocument doc,
  String line, {
  Set<String> labels = const {},
}) {
  final parsed = parseDropLine(line);
  expect(parsed, isA<DropLineParsed>(), reason: 'did not parse: $line');
  return planDropLine(
    doc: doc,
    line: parsed as DropLineParsed,
    now: _now,
    actor: 'test',
    alsoUsedLabels: labels,
  );
}

DropLinePlanReady _ready(DropLinePlan p) {
  if (p is DropLinePlanRefused) fail('refused: ${p.reason}');
  expect(p, isA<DropLinePlanReady>(), reason: '$p');
  return p as DropLinePlanReady;
}

String _refusal(DropLinePlan p) => (p as DropLinePlanRefused).reason;

/// Applies a plan the way the surface will: one transaction, one undo.
void _apply(RackDocument doc, DropLinePlanReady plan) {
  for (final c in plan.commands) {
    c.apply(doc);
  }
}

void main() {
  group("docs/07 §4.3's first line, end to end", () {
    test('nine drops, one outlet, nine labels', () {
      final p = _project();
      final plan = _ready(
        _plan(p.doc, 'Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4'),
      );

      expect(plan.dropCount, 9);
      expect(plan.outletCreated, isTrue);
      // The outlet plus nine drops.
      expect(plan.commands, hasLength(10));

      _apply(p.doc, plan);
      expect(p.doc.links, hasLength(9));
      expect(p.doc.outlets, hasLength(1));
    });

    test('every drop is a home run carrying a structureOrigin (AC-019)', () {
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 4x Cat6')));

      for (final l in p.doc.links.values) {
        expect(l.structureOrigin, isNotNull);
        expect(l.structureOrigin!.structureBodyId, p.bodyId);
      }
    });

    test('the far end is UNBOUND, which is the state AC-018 is about', () {
      // Fourteen of M3's sixty drops have unbound far ends. Bulk entry is
      // where they come from: at rough-in nothing has landed on a panel.
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 4x Cat6')));

      for (final l in p.doc.links.values) {
        expect(l.structureOrigin!.rackLabel, isNull);
      }
    });

    test('the wall end is UNTERMINATED, not a keystone nobody chose', () {
      // `derived/schedule.dart` calls `StructureOrigin.terminationField`
      // "what the trim-out crew actually installs" and prints it. A drop
      // line says how many and of what, never how the wall end is
      // finished, so `keystone` on all of them would order a keystone
      // jack for an RG6 run (an F barrel) and for a speaker run (not a
      // jack). Asserted across MIXED media, because a single-media line
      // would pass under either value.
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 1x Cat6, 1x RG6')));

      for (final l in p.doc.links.values) {
        expect(
          l.structureOrigin!.terminationField,
          TerminationType.unterminated,
        );
      }
    });

    test('the field end carries the room, so the Pull Sheet can group', () {
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 2x Cat6')));

      final ends = p.doc.links.values.map((l) => l.conductors.first.from);
      for (final e in ends) {
        expect(e, isA<PlaceEndpoint>());
        expect((e as PlaceEndpoint).locationId, p.livingRoom);
      }
    });

    test('AC-018: every drop the loop makes SCHEDULES, with its W number '
        'and its field label, far end unbound', () {
      // M3-A's exit criterion in one assertion. That issue opens with
      // "AC-018 is currently unreachable BY CONSTRUCTION ... the work is
      // producing the drops, not teaching the schedule" — M2-B taught the
      // schedule already, and `301136f` verified it over whole_house.
      // What nothing asserted until now is that drops produced by THIS
      // path arrive there, which is the whole of what M3-A was for.
      //
      // AC-018's fourth clause, "prints", is not reachable in M3 at all:
      // `SheetRole` has three values and none is a cable schedule (board
      // #574). Deliberately not claimed here.
      final p = _project();
      _apply(
        p.doc,
        _ready(_plan(p.doc, 'Living Room: 4x Cat6, 2x RG6, 1x 22/4')),
      );

      final rows = buildSchedule(p.doc).rows;
      expect(rows, hasLength(7));
      for (final r in rows) {
        expect(r.designator, isNotEmpty);
        expect(r.fieldLabel, isNotEmpty);
        expect(r.rackLabel, isNull, reason: 'the far end is unbound');
      }
      // One W number is one physical cable and one schedule row (G1).
      expect(rows.map((r) => r.designator).toSet(), hasLength(7));
    });

    test('W numbers and net names do not collide inside one line', () {
      // The `alsoUsed` reservation, at the artifact: nine drops built
      // against ONE unmutated document would otherwise all be W001.
      final p = _project();
      _apply(
        p.doc,
        _ready(_plan(p.doc, 'Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4')),
      );

      final designators = p.doc.links.values.map((l) => l.designator).toSet();
      expect(designators, hasLength(9));
    });
  });

  group("DR-023's chain, all three steps", () {
    test('STEP 3, no template and no modifier: the media short tag', () {
      // `Living Room: 4x Cat6` → `LR-C6-1`. docs/07 §4.1: "at rough-in a
      // Cat6 is just a Cat6", and this is the label that says so.
      final p = _project();
      final plan = _ready(_plan(p.doc, 'Living Room: 4x Cat6'));

      expect(plan.fieldLabels, ['LR-C6-1', 'LR-C6-2', 'LR-C6-3', 'LR-C6-4']);
    });

    test('STEP 3 varies per media, which is why it is not the STR answer', () {
      // The whole distinction DR-022 §11.21.5 turned on: `STR` would be
      // the same word on all nine.
      final p = _project();
      final plan = _ready(
        _plan(p.doc, 'Living Room: 1x Cat6, 1x RG6, 1x 16/4'),
      );

      expect(plan.fieldLabels, ['LR-C6-1', 'LR-RG6-1', 'LR-16/4-1']);
    });

    test('STEP 1 RESOLVES THROUGH A TEMPLATE, which is what makes the '
        "corpus's own EXT-CAM label come out", () {
      // `@service=camera` → `EXT-CAM-4` (docs/01 §571, DR-023 §11.22.1).
      // `CAMERA` is not `CAM`, so the modifier cannot be used literally:
      // it names the same kind of thing step 2 does, and differs only in
      // how the template is chosen.
      final p = _project(code: 'EXT', name: 'Exterior');
      p.doc.registries.outletTemplates['tpl.cam'] = OutletTemplate(
        id: 'tpl.cam',
        name: 'Camera',
        tag: 'CAM',
      );

      final plan = _ready(_plan(p.doc, 'Exterior: 6x Cat6 @service=camera'));
      expect(plan.fieldLabels.first, 'EXT-CAM-1');
    });

    test('STEP 1 falls back to the literal when no template is named '
        'that, so the modifier works before #150 seeds any', () {
      // `registries.outletTemplates` is `{}` in every document today, so
      // this arm is the only reachable one and the corpus's `EXT-CAM-4`
      // is NOT reproducible until #150 lands. Asserted so that fact is
      // visible here rather than discovered there.
      final p = _project(code: 'EXT', name: 'Exterior');
      expect(p.doc.registries.outletTemplates, isEmpty);

      final plan = _ready(_plan(p.doc, 'Exterior: 6x Cat6 @service=camera'));
      expect(plan.fieldLabels.first, 'EXT-CAMERA-1');
    });

    test('STEP 2, the outlet template tag, beaten by STEP 1 when both '
        'are present', () {
      // DR-023 §11.22.2, asserted at the artifact rather than by reading
      // the chain: the drop lands on a TV location outlet and is
      // labelled CAM anyway, which is the cost the ruling accepted in as
      // many words.
      final p = _project();
      p.doc.registries.outletTemplates['tpl.tv'] = OutletTemplate(
        id: 'tpl.tv',
        name: 'TV location',
        tag: 'TV',
      );
      AddOutletCommand(
        structureBodyId: p.bodyId,
        designation: 'LR-TV-1',
        order: nextOutletOrder(p.doc),
        now: _now,
        actor: 'test',
        locationId: p.livingRoom,
        outletTemplateId: 'tpl.tv',
      ).apply(p.doc);

      final withTemplate = _ready(
        _plan(p.doc, 'Living Room: 2x Cat6 @outlet="LR-TV-1"'),
      );
      expect(withTemplate.fieldLabels, ['LR-TV-1', 'LR-TV-2']);

      final overridden = _ready(
        _plan(
          p.doc,
          'Living Room: 2x Cat6 @outlet="LR-TV-1" @service=cam',
          labels: withTemplate.fieldLabels.toSet(),
        ),
      );
      expect(overridden.fieldLabels, ['LR-CAM-1', 'LR-CAM-2']);
    });

    test('THE ONE HOLE: a media type with no short tag refuses', () {
      // DR-023 §11.22.4. Reachable only for a user-created type from an
      // RJ-009 import, and it must not print `media.house_special` on a
      // label.
      final p = _project();
      const id = MediaTypeId('media.house_special');
      p.doc.registries.mediaTypes[id] = const MediaTypeDef(
        id: id,
        displayName: 'House special',
      );

      final refusal = _refusal(_plan(p.doc, 'Living Room: 2x House special'));
      expect(refusal, contains('no short tag'));
      expect(refusal, contains('@service='));
    });
  });

  group('resolving the media token', () {
    test("docs/07 §4.3's own four tokens all resolve", () {
      final r = buildSeedRegistries();
      for (final (token, id) in const [
        ('Cat6', 'media.cat6'),
        ('RG6', 'media.rg6'),
        ('16/4', 'media.16_4'),
        ('22/4', 'media.22_4'),
      ]) {
        expect(resolveMediaToken(r, token)?.id.v, id, reason: token);
      }
    });

    test('is case-, space-, underscore- and hyphen-insensitive, which is '
        "docs/07 §5.1's own rule", () {
      final r = buildSeedRegistries();
      for (final token in const ['cat6', 'CAT-6', 'Cat 6', 'cat_6', 'C6']) {
        expect(resolveMediaToken(r, token)?.id.v, 'media.cat6', reason: token);
      }
    });

    test('resolves through the id tail, so a type with no alias and no '
        'tag is still reachable', () {
      // What an RJ-009 import creates: an id and nothing else.
      final r = buildSeedRegistries();
      expect(
        resolveMediaToken(r, 'coax_video_75')?.id.v,
        'media.coax_video_75',
      );
    });

    test('an unknown token refuses and quotes what was typed', () {
      final p = _project();
      final refusal = _refusal(_plan(p.doc, 'Living Room: 2x Cat9'));
      expect(refusal, contains('"Cat9"'));
      expect(refusal, contains('Cat6, RG6, 16/4'));
    });
  });

  group('the outlet', () {
    test('one is created per line when none is named', () {
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 4x Cat6')));

      expect(p.doc.outlets, hasLength(1));
      expect(p.doc.outlets.values.single.locationId, p.livingRoom);
      expect(p.doc.outlets.values.single.designation, 'LR-1');
    });

    test('@outlet= JOINS an existing one rather than making a second', () {
      // docs/07 §4.3: `@outlet="…"` "creates or joins one Outlet".
      final p = _project();
      final first = _ready(
        _plan(p.doc, 'Living Room: 2x Cat6 @outlet="KIT-1"'),
      );
      _apply(p.doc, first);
      expect(p.doc.outlets, hasLength(1));

      final second = _ready(
        _plan(p.doc, 'Living Room: 1x RG6 @outlet="KIT-1"'),
      );
      expect(second.outletCreated, isFalse);
      _apply(p.doc, second);

      expect(p.doc.outlets, hasLength(1));
      expect(p.doc.links, hasLength(3));
    });

    test('two unnamed lines in one room get two outlets, not one', () {
      // A line is a plate. Two lines are two plates unless told
      // otherwise, which is what `@outlet=` is for.
      final p = _project();
      final a = _ready(_plan(p.doc, 'Living Room: 2x Cat6'));
      _apply(p.doc, a);
      final b = _ready(
        _plan(p.doc, 'Living Room: 2x RG6', labels: a.fieldLabels.toSet()),
      );
      _apply(p.doc, b);

      expect(p.doc.outlets, hasLength(2));
      expect(
        p.doc.outlets.values.map((o) => o.designation).toSet(),
        {'LR-1', 'LR-2'},
      );
    });
  });

  group('the offers that are not refusals', () {
    test('an unknown room is an OFFER, naming the room as typed', () {
      final p = _project();
      final plan = _plan(p.doc, 'Attic: 3x Cat6');

      expect(plan, isA<DropLinePlanNeedsLocation>());
      expect((plan as DropLinePlanNeedsLocation).locationName, 'Attic');
    });

    test('a project with no Structure device is an OFFER too', () {
      final doc = RackDocument(
        id: const Uuid('doc-bare'),
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

      expect(
        _plan(doc, 'Living Room: 2x Cat6'),
        isA<DropLinePlanNeedsStructure>(),
      );
    });

    test('a room resolves by NAME or by CODE, case-insensitively', () {
      // Sixty drops typed by hand means `living room` as often as
      // `Living Room`, and `LR` as often as either.
      final p = _project();
      for (final spelling in const ['Living Room', 'living room', 'LR', 'lr']) {
        expect(
          _plan(p.doc, '$spelling: 1x Cat6'),
          isA<DropLinePlanReady>(),
          reason: spelling,
        );
      }
    });
  });

  group('nothing is applied when anything refuses', () {
    test('a line refusing on its LAST item creates nothing at all', () {
      // The reason the planner mutates nothing. Eight drops from a line
      // that asked for nine, with no ninth and no message, is the worst
      // outcome available to a bulk surface.
      final p = _project();
      final plan = _plan(p.doc, 'Living Room: 8x Cat6, 1x Cat9');

      expect(plan, isA<DropLinePlanRefused>());
      expect(p.doc.links, isEmpty);
      expect(p.doc.outlets, isEmpty);
    });

    test('planning twice against the same document is identical', () {
      // It mutates nothing, so it is safe to call on every keystroke for
      // a live preview — which is what the entry surface does.
      final p = _project();
      final a = _ready(_plan(p.doc, 'Living Room: 4x Cat6'));
      final b = _ready(_plan(p.doc, 'Living Room: 4x Cat6'));
      expect(a.fieldLabels, b.fieldLabels);
      expect(p.doc.links, isEmpty);
    });
  });

  group('labels continue across lines rather than restarting', () {
    test('a second line in the same room picks up where the first left', () {
      final p = _project();
      final a = _ready(_plan(p.doc, 'Living Room: 2x Cat6'));
      _apply(p.doc, a);

      final b = _ready(_plan(p.doc, 'Living Room: 2x Cat6'));
      expect(b.fieldLabels, ['LR-C6-3', 'LR-C6-4']);
    });

    test('a gap left by a deleted drop is reused, not skipped', () {
      // `_lowestUnused`'s contract reaching the surface: CR-113 makes
      // field labels unique, not monotonic.
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 3x Cat6')));
      final victim = p.doc.links.values.firstWhere(
        (l) => l.structureOrigin!.fieldLabel == 'LR-C6-2',
      );
      p.doc.links.remove(victim.id);

      expect(_ready(_plan(p.doc, 'Living Room: 1x Cat6')).fieldLabels, [
        'LR-C6-2',
      ]);
    });
  });

  group('what the line asked for and this build did not do', () {
    test('@status= parses, refuses a bad value, and WARNS on a good one', () {
      final p = _project();
      expect(
        _refusal(_plan(p.doc, 'Living Room: 1x Cat6 @status=nonsense')),
        contains('planned'),
      );

      final plan = _ready(_plan(p.doc, 'Living Room: 1x Cat6 @status=planned'));
      expect(plan.warnings.single, contains('planned'));
      expect(plan.dropCount, 1);
    });

    test('an unknown modifier warns rather than vanishing', () {
      // Somebody who typed `@wall=north` and watched a drop appear has
      // been told their input was understood.
      final p = _project();
      final plan = _ready(_plan(p.doc, 'Living Room: 1x Cat6 @wall=north'));
      expect(plan.warnings.single, contains('@wall'));
    });

    test('@pathway= warns, because Pathways are board #156', () {
      final p = _project();
      final plan = _ready(
        _plan(p.doc, 'Living Room: 1x Cat6 @pathway="North chase"'),
      );
      expect(plan.warnings.single, contains('North chase'));
    });
  });

  group('a room with no code cannot be labelled, and says which field', () {
    test('leads with the field a person fills, and shows the pattern '
        'second', () {
      // M3-B gives a new Location no code on purpose, so this is the
      // ordinary first-run state and not an edge case.
      //
      // THE ORDER IS THE CLAIM. "needs a short code" is the actionable
      // half and comes first; the pattern follows because a project that
      // customised it needs to see what it customised it to. A sentence
      // that led with `{ROOM_ABBR}` would be telling the user about a
      // format string when they asked to enter cable.
      final p = _project(code: '');
      final refusal = _refusal(_plan(p.doc, 'Living Room: 2x Cat6'));

      expect(refusal, contains('Living Room'));
      expect(refusal, contains('short code'));
      expect(
        refusal.indexOf('short code'),
        lessThan(refusal.indexOf('ROOM_ABBR')),
      );
    });
  });
}
