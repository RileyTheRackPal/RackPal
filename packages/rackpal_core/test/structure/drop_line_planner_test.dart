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
import 'package:rackpal_core/rackpal_core.dart';
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

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

/// Puts a patch panel in the project, plus a telecom room carrying the two
/// identifiers the rack-label preset wants.
///
/// FRONT PORTS ARE DECLARED FIRST, DELIBERATELY. DR-040 §11.39.2 clause 4
/// lands a drop on the REAR, and a walk that took declared order without
/// filtering the face would hand the first drop `front.1`.
Uuid _panel(RackDocument doc, {String designator = 'PP-1', int positions = 3}) {
  const tplId = 'tpl.pp';
  doc.templates['$tplId@1'] = TemplateSnapshot(
    templateId: const TemplateId(tplId),
    version: 1,
    contentHash: 'sha256:$tplId',
    body: TemplateBody(
      manufacturer: 'Generic',
      model: 'PP',
      displayName: 'Patch Panel',
      typePrefix: 'PP',
      ports: [
        for (var i = 1; i <= positions; i++)
          PortDef(
            key: PortKey('front.$i'),
            label: i.toString().padLeft(2, '0'),
            connector: const ConnectorTypeId('conn.rj45'),
            signalFamily: const SignalFamilyId('net.ethernet'),
            face: Face.front,
            position: _pos,
            order: FracIndex('a$i'),
          ),
        for (var i = 1; i <= positions; i++)
          PortDef(
            key: PortKey('rear.$i'),
            label: i.toString().padLeft(2, '0'),
            connector: const ConnectorTypeId('conn.punchdown_110'),
            signalFamily: const SignalFamilyId('net.ethernet'),
            face: Face.rear,
            position: _pos,
            order: FracIndex('b$i'),
          ),
      ],
    ),
    capturedAt: _now,
  );

  final room = AddLocationCommand(
    name: 'Media Closet',
    code: 'MC',
    order: nextLocationOrder(doc),
    floorNumber: 1,
    spaceCode: 'A',
    now: _now,
    actor: 'test',
  )..apply(doc);

  final id = Uuid('dev-$designator');
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId(tplId),
      version: 1,
      contentHash: 'sha256:$tplId',
    ),
    designator: designator,
    name: 'Patch Panel',
    placement: const OffRackPlacement(),
    locationId: room.id,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  );
  return id;
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

    test('the wall end is UNKNOWN, not a decision nobody made', () {
      // `derived/schedule.dart` calls `StructureOrigin.terminationField`
      // "what the trim-out crew actually installs" and prints it. A drop
      // line says how many and of what, never how the wall end is
      // finished, so `keystone` on all of them would order a keystone
      // jack for an RG6 run (an F barrel) and for a speaker run (not a
      // jack). Asserted across MIXED media, because a single-media line
      // would pass under any single value.
      //
      // THIS ASSERTED `unterminated` UNTIL M3-J, when the field became
      // nullable (G4, CR-114). `unterminated` is a DECISION — the coil
      // left deliberately bare — and on a sheet somebody buys hardware
      // from that is a different fact from "nobody has decided".
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 1x Cat6, 1x RG6')));

      for (final l in p.doc.links.values) {
        expect(l.structureOrigin!.terminationField, isNull);
      }
    });

    test('and the schedule prints nothing for it rather than a guess', () {
      // The half that matters on paper: `ScheduleEntry.terminationType`
      // has always been nullable and its "then nothing" arm was
      // unreachable for home runs, because the model could not express
      // the state. It can now.
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 1x Cat6, 1x RG6')));

      for (final row in buildSchedule(p.doc).rows) {
        expect(row.terminationType, isNull);
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
      // schedule already, and `70cb8d5` verified it over whole_house.
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

    test('STEP 1 RESOLVES THROUGH A TEMPLATE, and the corpus label now '
        'comes out of a BLANK project', () {
      // `Exterior: 6x Cat6 @service=camera` → `EXT-CAM-4`, DR-023
      // §11.22.1's own worked line, printed by docs/07 §8's label table.
      // `CAMERA` is not `CAM`, so the modifier cannot be used literally:
      // it names the same kind of thing step 2 does, and differs only in
      // how the template is chosen.
      //
      // NOTHING IS INSERTED HERE ANY MORE. This test used to author a
      // `tpl.cam` by hand, and the one below it asserted that a real
      // document could NOT produce `EXT-CAM-4` because
      // `registries.outletTemplates` was `{}` everywhere. M3-C/4 seeded
      // `outlet.camera`, so the seed master is what resolves the token.
      final p = _project(code: 'EXT', name: 'Exterior');

      final plan = _ready(_plan(p.doc, 'Exterior: 6x Cat6 @service=camera'));
      expect(plan.fieldLabels, [
        'EXT-CAM-1',
        'EXT-CAM-2',
        'EXT-CAM-3',
        'EXT-CAM-4',
        'EXT-CAM-5',
        'EXT-CAM-6',
      ]);
    });

    test('STEP 1 still falls back to the literal for a token no template '
        'is named', () {
      // The other arm, kept: `@service=poe` on a project that authored no
      // such template must still produce a label rather than refuse.
      // Nine templates ship now, so this reaches past all of them.
      final p = _project(code: 'EXT', name: 'Exterior');
      expect(p.doc.registries.outletTemplates, isNotEmpty);

      final plan = _ready(_plan(p.doc, 'Exterior: 2x Cat6 @service=poe'));
      expect(plan.fieldLabels.first, 'EXT-POE-1');
    });

    test('STEP 1 resolves by TAG before name, which is why `tv` works', () {
      // The seeded *TV location* answers to `tv` because its tag is `TV`;
      // its NAME is two words nobody types mid-drill.
      final p = _project();

      final plan = _ready(_plan(p.doc, 'Living Room: 2x Cat6 @service=tv'));
      expect(plan.fieldLabels, ['LR-TV-1', 'LR-TV-2']);
    });

    test('STEP 2, the outlet template tag, beaten by STEP 1 when both '
        'are present', () {
      // DR-023 §11.22.2, asserted at the artifact rather than by reading
      // the chain: the drop lands on a TV location outlet and is
      // labelled CAM anyway, which is the cost the ruling accepted in as
      // many words.
      // The outlet is created from the SEEDED `outlet.tv_location`, not
      // a template authored in this test, so the step-2 arm exercises
      // the same data a real document carries.
      final p = _project();
      AddOutletCommand(
        structureBodyId: p.bodyId,
        designation: 'LR-TV-1',
        order: nextOutletOrder(p.doc),
        now: _now,
        actor: 'test',
        locationId: p.livingRoom,
        outletTemplateId: 'outlet.tv_location',
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

  group('conduit is not a cable (CR-109, DR-032)', () {
    test('a conduit-only line makes a Pathway and NO outlet, no drop, no '
        'label', () {
      // CR-109: "never a `Link` and never a `Port`". An outlet minted
      // here would be a real entity on the Structure body with no drop
      // on it, which the drop count and the outlet rollup would then
      // both have to explain.
      final p = _project();
      final plan = _ready(_plan(p.doc, 'Living Room: 1x ENT'));

      expect(plan.dropCount, 0);
      expect(plan.fieldLabels, isEmpty);
      expect(plan.outletCreated, isFalse);
      expect(plan.pathwayNames, ['Living Room ENT']);

      _apply(p.doc, plan);
      expect(p.doc.pathways.values.single.name, 'Living Room ENT');
      expect(p.doc.links, isEmpty);
      expect(p.doc.outlets, isEmpty);
    });

    test('the name is a DESCRIPTION and the designator stays null', () {
      // DR-032 §11.31.2. `PW-LR-1` is the allocated series DR-026
      // §11.25.1 refused for the designator, and a name minted at
      // creation would reintroduce it through the one field that ruling
      // left alone.
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 1x ENT')));

      final pathway = p.doc.pathways.values.single;
      expect(pathway.name, 'Living Room ENT');
      expect(pathway.name, isNot(matches(RegExp('^PW-'))));
      expect(pathway.kind, PathwayKind.conduit);
    });

    test('a mixed line makes both, and the drop count counts only drops', () {
      // docs/07 §4.2 excludes pathways from the Σ drop count in so many
      // words.
      final p = _project();
      final plan = _ready(_plan(p.doc, 'Living Room: 4x Cat6, 1x ENT'));

      expect(plan.dropCount, 4);
      expect(plan.fieldLabels, hasLength(4));
      expect(plan.pathwayNames, ['Living Room ENT']);
      expect(plan.outletCreated, isTrue);

      _apply(p.doc, plan);
      expect(p.doc.links, hasLength(4));
      expect(p.doc.pathways, hasLength(1));
      expect(p.doc.outlets, hasLength(1));
    });

    test('a count above one makes that many, each distinguishable', () {
      // Two smurf tubes are two entities: a `Pathway` has no quantity
      // field. Identical names would defeat the `PATH` column, which is
      // the same argument that rejected naming it after the medium
      // alone.
      final p = _project();
      final plan = _ready(_plan(p.doc, 'Living Room: 2x ENT'));

      expect(plan.pathwayNames, ['Living Room ENT 1', 'Living Room ENT 2']);

      _apply(p.doc, plan);
      expect(p.doc.pathways, hasLength(2));
      expect(
        p.doc.pathways.values.map((x) => x.order.v).toSet(),
        hasLength(2),
        reason: 'a shared order makes list position depend on map iteration',
      );
    });

    test('every alias for the same conduit lands on a Pathway', () {
      // `conduit`, `smurf` and `ent` all resolve to `media.conduit_ent`,
      // and the flag is on the MEDIUM, so which word was typed cannot
      // change what gets built.
      for (final token in const ['conduit', 'smurf', 'ent']) {
        final p = _project();
        final plan = _ready(_plan(p.doc, 'Living Room: 1x $token'));
        expect(plan.dropCount, 0, reason: '$token built a drop');
        expect(plan.pathwayNames, hasLength(1));
      }
    });

    test('and a cable line is completely unaffected', () {
      // The regression this guards: partitioning by a flag that is false
      // on 35 of 38 types must not perturb the ordinary path.
      final p = _project();
      final plan = _ready(_plan(p.doc, 'Living Room: 4x Cat6'));

      expect(plan.dropCount, 4);
      expect(plan.pathwayNames, isEmpty);
      expect(plan.outletCreated, isTrue);
    });
  });

  group('@panel= lands the whole line (DR-040 §11.39.2 clause 2)', () {
    test('THREE DROPS FROM ONE MODIFIER, each on its own rear position', () {
      // The clause's whole reason for being a modifier: AC-018 wants
      // forty-six of sixty landed inside fifteen minutes, and this costs
      // one `@panel=PP-1` per line rather than forty-six typed cells.
      final p = _project();
      _panel(p.doc);
      final plan = _ready(_plan(p.doc, 'Living Room: 3x Cat6 @panel=PP-1'));
      _apply(p.doc, plan);

      final ends = [for (final l in p.doc.links.values) l.conductors.first.to];
      expect(ends, everyElement(isA<PortEndpoint>()));
      expect(
        {for (final e in ends) (e as PortEndpoint).portId},
        hasLength(3),
        reason: 'three DIFFERENT positions, not three copies of one',
      );
    });

    test('THE REAR, NOT THE FRONT, and the fixture declares front first', () {
      // The front jacks are where a patch cord goes. A walk that took
      // declared order without filtering the face would put the whole
      // rough-in on the wrong side of the panel, and the archetype's own
      // description says why that breaks the Termination Schedule.
      final p = _project();
      final panelId = _panel(p.doc);
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 1x Cat6 @panel=PP-1')));

      final end = p.doc.links.values.first.conductors.first.to as PortEndpoint;
      expect(end.portId, derivePortId(panelId, const PortKey('rear.1')));
    });

    test('the rack labels are allocated in position order', () {
      final p = _project();
      _panel(p.doc);
      final plan = _ready(_plan(p.doc, 'Living Room: 3x Cat6 @panel=PP-1'));

      expect(plan.rackLabels, ['1A-PP-101', '1A-PP-102', '1A-PP-103']);
      _apply(p.doc, plan);
      expect(
        {for (final l in p.doc.links.values) l.structureOrigin!.rackLabel},
        {'1A-PP-101', '1A-PP-102', '1A-PP-103'},
      );
    });

    test('a second line takes the positions the first one did NOT', () {
      final p = _project();
      final panelId = _panel(p.doc);
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 1x Cat6 @panel=PP-1')));
      final second = _ready(_plan(p.doc, 'Living Room: 1x Cat6 @panel=PP-1'));

      expect(second.rackLabels, ['1A-PP-102']);
      _apply(p.doc, second);
      expect(
        {
          for (final l in p.doc.links.values)
            (l.conductors.first.to as PortEndpoint).portId,
        },
        {
          derivePortId(panelId, const PortKey('rear.1')),
          derivePortId(panelId, const PortKey('rear.2')),
        },
      );
    });

    test('A PANEL THAT DOES NOT EXIST REFUSES, and creates nothing', () {
      // `@panel=PP-9` is a typo far more often than an intention, and a
      // gesture that invented a 24-port device out of one would put
      // hardware nobody chose on the equipment list.
      final p = _project();
      _panel(p.doc);
      final before = p.doc.links.length;

      expect(
        _refusal(_plan(p.doc, 'Living Room: 1x Cat6 @panel=PP-9')),
        contains('called "PP-9"'),
      );
      expect(p.doc.links, hasLength(before));
    });

    test('a panel too small refuses ALL of it, and says by how much', () {
      // Landing four of six silently would leave two rows on the Pull
      // Sheet that look identical to a deliberate rough-in coil.
      final p = _project();
      _panel(p.doc);

      final reason = _refusal(_plan(p.doc, 'Living Room: 6x Cat6 @panel=PP-1'));
      expect(reason, contains('3 free position'));
      expect(reason, contains('needs 6'));
      expect(reason, contains('Nothing was landed'));
    });

    test('NO PANEL NAMED MEANS NOTHING CHANGED, which is every other line', () {
      // The regression guard: `@panel=` is opt-in, and the other 349
      // keystrokes of the drill must behave exactly as they did.
      final p = _project();
      _panel(p.doc);
      final plan = _ready(_plan(p.doc, 'Living Room: 4x Cat6'));
      _apply(p.doc, plan);

      expect(plan.rackLabels, isEmpty);
      expect(
        [for (final l in p.doc.links.values) l.conductors.first.to],
        everyElement(isA<OpenEndpoint>()),
      );
    });

    test('a panel with no floor number LANDS ANYWAY and says so ONCE', () {
      // DR-040 §11.39.5, plus the once-per-line rule: three drops onto a
      // panel with no floor number is ONE fact about ONE room, and
      // printing it three times is how a person learns to stop reading
      // warnings.
      final p = _project();
      final panelId = _panel(p.doc);
      p.doc.locations[p.doc.devices[panelId]!.locationId!]!.floorNumber = null;

      final plan = _ready(_plan(p.doc, 'Living Room: 3x Cat6 @panel=PP-1'));
      _apply(p.doc, plan);

      expect(plan.rackLabels, isEmpty);
      expect(
        plan.warnings.where((w) => w.contains('floor number')),
        hasLength(1),
      );
      expect(
        [for (final l in p.doc.links.values) l.conductors.first.to],
        everyElement(isA<PortEndpoint>()),
        reason: 'the drops were still punched down',
      );
    });

    test('the designator match is case-insensitive, like every other one', () {
      final p = _project();
      _panel(p.doc);
      expect(
        _plan(p.doc, 'Living Room: 1x Cat6 @panel=pp-1'),
        isA<DropLinePlanReady>(),
      );
    });

    test('THE WHOLE DRILL, MINUS THE HUMAN (M3-G, docs/16)', () {
      // WHAT THIS IS AND IS NOT, on `drop_entry_panel_test`'s precedent.
      // It does not time anybody: fifteen seconds per drop including
      // thinking is a human fact and board #163 is the only instrument
      // for it. What it pins is the part the SURFACE controls, which is
      // the part that could make the drill impossible before anyone runs
      // it, and it is now the AC-018 SHAPE and not only the keystrokes.
      //
      // The script is docs/16 §2 verbatim. If they drift apart, a person
      // spends fifteen minutes discovering it.
      const script = [
        'Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4 @panel=PP-1',
        'Kitchen: 2x Cat6, 1x RG6, 1x 16/4, 1x 22/4 @panel=PP-1',
        'Office: 4x Cat6, 1x RG6, 1x 22/4 @panel=PP-1',
        'Primary Bedroom: 2x Cat6, 2x RG6, 1x 16/4, 1x 22/4 @panel=PP-1',
        'Bedroom 2: 2x Cat6, 1x RG6, 1x 22/4 @panel=PP-1',
        'Bedroom 3: 2x Cat6, 1x RG6',
        'Attic: 5x Cat6',
        'Exterior: 6x Cat6',
        'Garage: 4x Cat6, 2x RG6, 1x 22/4 @panel=PP-1',
        'Media Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4 @panel=PP-1',
      ];
      const rooms = [
        ('Kitchen', 'KIT'),
        ('Office', 'OFF'),
        ('Primary Bedroom', 'MBR'),
        ('Bedroom 2', 'BR2'),
        ('Bedroom 3', 'BR3'),
        ('Attic', 'ATT'),
        ('Exterior', 'EXT'),
        ('Garage', 'GAR'),
        ('Media Room', 'MED'),
      ];

      final p = _project();
      _panel(p.doc, positions: 48);
      for (final (name, code) in rooms) {
        AddLocationCommand(
          name: name,
          code: code,
          order: nextLocationOrder(p.doc),
          now: _now,
          actor: 'test',
        ).apply(p.doc);
      }

      for (final line in script) {
        _apply(p.doc, _ready(_plan(p.doc, line)));
      }

      final drops = p.doc.links.values.toList();
      final open = [
        for (final l in drops)
          if (l.conductors.first.to is! PortEndpoint) l,
      ];

      // AC-018, clause by clause, at the artifact.
      expect(drops, hasLength(60), reason: "the drill's own size");
      expect(open, hasLength(14), reason: "AC-018's fourteen");
      expect(drops.length - open.length, 46, reason: 'and its forty-six');
      for (final l in drops) {
        expect(l.designator, isNotEmpty, reason: 'a W number');
        expect(l.structureOrigin!.fieldLabel, isNotEmpty);
      }
      // AS SETS, so a duplicate cannot hide inside a matching count (G1).
      expect(
        {for (final l in drops) l.structureOrigin!.fieldLabel},
        hasLength(60),
      );
      expect(
        {
          for (final l in drops) ?l.structureOrigin!.rackLabel,
        },
        hasLength(46),
      );
      // THE CONVERSE, which is the one that catches a fabrication: nothing
      // may name a panel position a cable has not reached (G4).
      for (final l in open) {
        expect(l.structureOrigin!.rackLabel, isNull);
      }

      // THE COST, MEASURED THEN PINNED, in that order. 349 was the figure
      // before anything landed; `@panel=` on seven of ten lines buys
      // forty-six landings for 84 more keystrokes, which is 1.8 each
      // against roughly 7 for a hand-typed `RACK LBL` cell.
      final keystrokes = script.fold(0, (n, l) => n + l.length) + script.length;
      expect(keystrokes, 433, reason: 'the measurement, pinned exactly');
      expect(
        keystrokes / drops.length,
        lessThan(8.0),
        reason:
            '$keystrokes keystrokes for ${drops.length} drops = '
            '${(keystrokes / drops.length).toStringAsFixed(2)} each',
      );
    });

    test('the binds come after the drops, because a bind names a Link', () {
      // Ordering as an assertion rather than a comment: a bind sequenced
      // ahead of its own AddHomeRunCommand names a link the document does
      // not hold yet, and would silently do nothing.
      final p = _project();
      _panel(p.doc);
      final plan = _ready(_plan(p.doc, 'Living Room: 2x Cat6 @panel=PP-1'));

      expect(
        plan.commands.indexWhere((c) => c is BindEndpointCommand),
        greaterThan(
          plan.commands.lastIndexWhere((c) => c is AddHomeRunCommand),
        ),
      );
    });
  });
  group('@nobox: a run that comes out of no box (DR-070 §11.69, `#718`)', () {
    test('it creates NO outlet, and the runs say boxless', () {
      // The gesture the user asked for by example: a ceiling speaker has
      // no low-voltage box, so there is nothing for an `Outlet` to be.
      final p = _project();
      final plan = _ready(_plan(p.doc, 'Living Room: 2x Cat6 @nobox'));
      _apply(p.doc, plan);

      expect(
        p.doc.outlets,
        isEmpty,
        reason:
            'the planner had one job up to here, find the box or make '
            'one, and this line skips both',
      );
      final origins = [
        for (final l in p.doc.links.values) l.structureOrigin!,
      ];
      expect(origins, hasLength(2));
      for (final o in origins) {
        expect(o.outletId, isNull);
        expect(o.boxless, isTrue);
      }
    });

    test('the runs still carry their room, so the sheet groups them', () {
      // `buildScheduleEntry` falls back to the RACK's room when nothing
      // else answers, and its own comment calls that a trap. With no
      // outlet the field end is the only thing that can say.
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 1x Cat6 @nobox')));

      final table = buildStructureTable(p.doc);
      expect(table.groups.single.title, 'Living Room');
      expect(table.outletCount, 0);
      expect(table.dropCount, 1);
    });

    test('an ordinary line still makes its outlet', () {
      // The other direction, without which the cases above are satisfied
      // by a planner that stopped making outlets at all.
      final p = _project();
      _apply(p.doc, _ready(_plan(p.doc, 'Living Room: 1x Cat6')));
      expect(p.doc.outlets, hasLength(1));
      expect(p.doc.links.values.single.structureOrigin!.boxless, isFalse);
    });

    test('@nobox with @outlet= is refused rather than ranked', () {
      // The line states two incompatible things and the person meant one
      // of them. Picking a winner silently is how a document comes to
      // disagree with what somebody typed.
      final p = _project();
      final refusal = _refusal(
        _plan(p.doc, 'Living Room: 1x Cat6 @nobox @outlet="LR-1"'),
      );
      expect(refusal, contains('one or the other'));
      expect(p.doc.links, isEmpty);
      expect(p.doc.outlets, isEmpty);
    });

    test('it lands on a panel like any other line', () {
      // `@nobox` is about the FIELD end. The rack end is untouched by it,
      // and a speaker run landing on an amplifier is the whole point.
      final p = _project();
      _panel(p.doc);
      _apply(
        p.doc,
        _ready(_plan(p.doc, 'Living Room: 1x Cat6 @nobox @panel=PP-1')),
      );

      final origin = p.doc.links.values.single.structureOrigin!;
      expect(origin.boxless, isTrue);
      expect(origin.rackLabel, isNotNull);
    });
  });
}
