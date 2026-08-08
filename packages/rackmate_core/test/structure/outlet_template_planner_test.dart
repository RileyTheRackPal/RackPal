// M3-C/5, #151 — `+ Add outlet ▾`, driven against a real document.
//
// WHAT THESE ASSERT. Not "the planner called the allocator" but "the
// document afterwards holds one outlet, N links, N labels and the
// citation" — house style, and it matters here because the label now has
// two possible sources and a test that pinned the intermediate would
// survive the chain being wired to the wrong one.
//
// THE ONE THAT IS THE TASK: DR-023 step 2 has been unreachable since it
// was ruled, because nothing created an `Outlet` from a template. The
// first group is that arm firing from a menu pick, with nothing typed.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 8, 8);

typedef _Project = ({RackDocument doc, Uuid bodyId, Uuid livingRoom});

_Project _project({String code = 'LR', String name = 'Living Room'}) {
  final doc = RackDocument(
    id: const Uuid('doc-tpl'),
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

OutletTemplatePlan _plan(
  _Project p,
  String templateId, {
  String? designation,
  Set<String> labels = const {},
}) => planOutletFromTemplate(
  doc: p.doc,
  template: p.doc.registries.outletTemplates[templateId]!,
  locationId: p.livingRoom,
  now: _now,
  actor: 'test',
  designation: designation,
  alsoUsedLabels: labels,
);

OutletTemplatePlanReady _ready(OutletTemplatePlan plan) {
  if (plan is OutletTemplatePlanRefused) fail('refused: ${plan.reason}');
  expect(plan, isA<OutletTemplatePlanReady>(), reason: '$plan');
  return plan as OutletTemplatePlanReady;
}

/// Applies a plan the way the surface will: one transaction, one undo.
void _apply(RackDocument doc, OutletTemplatePlanReady plan) {
  for (final c in plan.commands) {
    c.apply(doc);
  }
}

void main() {
  group("docs/07 §4.3's own sentence, end to end", () {
    test('TV location is one outlet, four links and four label pairs', () {
      // *"instantiates an OutletTemplate in one action, TV location →
      // 2 × Cat6 + 2 × RG6 as one Outlet with four Links and four label
      // pairs."*
      final p = _project();
      final plan = _ready(_plan(p, 'outlet.tv_location'));
      _apply(p.doc, plan);

      expect(p.doc.outlets, hasLength(1));
      expect(p.doc.links, hasLength(4));
      expect(plan.dropCount, 4);
    });

    test('DR-023 STEP 2 FIRES, and nothing was typed to make it', () {
      // THE TASK. `LR-TV-1` is DR-022's first worked example and until
      // this gesture existed the only way to produce it was
      // `@service=tv`, which is step 1 wearing step 2's clothes. The
      // label now comes off the outlet's own template.
      final p = _project();
      final plan = _ready(_plan(p, 'outlet.tv_location'));

      expect(plan.fieldLabels, ['LR-TV-1', 'LR-TV-2', 'LR-TV-3', 'LR-TV-4']);
    });

    test('and the outlet records what created it (CR-108)', () {
      final p = _project();
      _apply(p.doc, _ready(_plan(p, 'outlet.tv_location')));

      final outlet = p.doc.outlets.values.single;
      expect(outlet.outletTemplateId, 'outlet.tv_location');
      expect(outlet.locationId, p.livingRoom);
    });

    test('every drop is a home run on that outlet (AC-019)', () {
      final p = _project();
      _apply(p.doc, _ready(_plan(p, 'outlet.tv_location')));

      final outletId = p.doc.outlets.values.single.id;
      for (final link in p.doc.links.values) {
        expect(link.structureOrigin, isNotNull);
        expect(link.structureOrigin!.outletId, outletId);
      }
    });

    test('the media is the recipe, not the label', () {
      // Two Cat6 and two RG6 quad, whatever the four labels read.
      final p = _project();
      _apply(p.doc, _ready(_plan(p, 'outlet.tv_location')));

      final media = <String, int>{};
      for (final l in p.doc.links.values) {
        media[l.media.v] = (media[l.media.v] ?? 0) + 1;
      }
      expect(media, {'media.cat6': 2, 'media.rg6_quad': 2});
    });

    test('AC-018: every drop schedules with an unbound far end', () {
      final p = _project();
      _apply(p.doc, _ready(_plan(p, 'outlet.tv_location')));

      final rows = buildSchedule(p.doc).rows;
      expect(rows, hasLength(4));
      for (final r in rows) {
        expect(r.designator, isNotEmpty);
        expect(r.fieldLabel, isNotEmpty);
        expect(r.rackLabel, isNull, reason: 'the far end is unbound');
      }
      expect(rows.map((r) => r.designator).toSet(), hasLength(4));
    });
  });

  group('the grade presets stamp their citation (DR-024)', () {
    test('a Grade 2 outlet carries the standard it cites', () {
      final p = _project();
      final plan = _ready(_plan(p, 'outlet.tia570d_grade2'));
      _apply(p.doc, plan);

      expect(plan.tia570Grade, 'TIA-570-D Grade 2');
      expect(p.doc.outlets.values.single.tia570Grade, 'TIA-570-D Grade 2');
    });

    test('and a TV location carries NONE, which is G4', () {
      // *TV location* cites no standard. An outlet that claimed one
      // would put a citation in a document nobody made.
      final p = _project();
      final plan = _ready(_plan(p, 'outlet.tv_location'));
      _apply(p.doc, plan);

      expect(plan.tia570Grade, isNull);
      expect(p.doc.outlets.values.single.tia570Grade, isNull);
    });

    test('an untagged preset falls to DR-023 step 3, the media tag', () {
      // The three grades carry no `tag`, so their drops label by what
      // they ARE rather than by an invented `G2`.
      final p = _project();
      final plan = _ready(_plan(p, 'outlet.tia570d_grade2'));

      expect(plan.fieldLabels, [
        'LR-C6A-1',
        'LR-C6A-2',
        'LR-RG6Q-1',
        'LR-RG6Q-2',
      ]);
    });

    test('Grade 3 pulls its required fibre as ONE cable', () {
      // "2-fibre" is two strands in one jacket, pulled once.
      final p = _project();
      _apply(p.doc, _ready(_plan(p, 'outlet.tia570d_grade3')));

      final fibre = p.doc.links.values.where(
        (l) => l.media.v == 'media.os2',
      );
      expect(fibre, hasLength(1));
    });
  });

  group('the outlet', () {
    test('gets a generated designation from the room code', () {
      final p = _project();
      final plan = _ready(_plan(p, 'outlet.ap'));

      expect(plan.outletDesignation, 'LR-1');
    });

    test('and a second one does not collide with the first', () {
      final p = _project();
      _apply(p.doc, _ready(_plan(p, 'outlet.ap')));
      final second = _ready(
        _plan(
          p,
          'outlet.camera',
          labels: {
            for (final l in p.doc.links.values)
              if (l.structureOrigin case final o?) o.fieldLabel,
          },
        ),
      );

      expect(second.outletDesignation, 'LR-2');
    });

    test('an explicit designation wins over the generated one', () {
      final p = _project();
      final plan = _ready(_plan(p, 'outlet.tv_location', designation: 'WP-1'));
      _apply(p.doc, plan);

      expect(p.doc.outlets.values.single.designation, 'WP-1');
    });

    test('it never joins an existing outlet, it makes a new plate', () {
      // docs/07 §4.3 says "as one Outlet", and `outletTemplateId` is
      // provenance: adding a recipe to a plate that already exists would
      // either overwrite that or leave drops disagreeing with the
      // template they name.
      final p = _project();
      _apply(p.doc, _ready(_plan(p, 'outlet.tv_location')));
      _apply(
        p.doc,
        _ready(
          _plan(
            p,
            'outlet.tv_location',
            labels: {
              for (final l in p.doc.links.values)
                if (l.structureOrigin case final o?) o.fieldLabel,
            },
          ),
        ),
      );

      expect(p.doc.outlets, hasLength(2));
      expect(p.doc.links, hasLength(8));
    });
  });

  group('labels and numbers do not collide', () {
    test('a second TV location continues the sequence', () {
      final p = _project();
      final first = _ready(_plan(p, 'outlet.tv_location'));
      _apply(p.doc, first);

      final second = _ready(
        _plan(p, 'outlet.tv_location', labels: first.fieldLabels.toSet()),
      );
      expect(second.fieldLabels, [
        'LR-TV-5',
        'LR-TV-6',
        'LR-TV-7',
        'LR-TV-8',
      ]);
    });

    test('W numbers and net names are unique across two outlets', () {
      final p = _project();
      _apply(p.doc, _ready(_plan(p, 'outlet.tv_location')));
      _apply(
        p.doc,
        _ready(
          _plan(
            p,
            'outlet.tv_location',
            labels: {
              for (final l in p.doc.links.values)
                if (l.structureOrigin case final o?) o.fieldLabel,
            },
          ),
        ),
      );

      expect(p.doc.links.values.map((l) => l.designator).toSet(), hasLength(8));
      expect(p.doc.nets.values.map((n) => n.name).toSet(), hasLength(8));
    });

    test('planning twice against the same document is identical', () {
      // The gesture mutates nothing, so a preview drawn on every hover
      // cannot spend an id.
      final p = _project();
      final a = _ready(_plan(p, 'outlet.tv_location'));
      final b = _ready(_plan(p, 'outlet.tv_location'));

      expect(a.fieldLabels, b.fieldLabels);
      expect(p.doc.outlets, isEmpty);
      expect(p.doc.links, isEmpty);
    });
  });

  group('the refusals, and the one offer', () {
    test('a project with no Structure device is an OFFER, not an error', () {
      final doc = RackDocument(
        id: const Uuid('doc-bare'),
        appVersion: '0.1.0',
        createdAt: _now,
        modifiedAt: _now,
        meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
      )..registries = buildSeedRegistries();
      final room = AddLocationCommand(
        name: 'Attic',
        code: 'ATT',
        order: nextLocationOrder(doc),
        now: _now,
        actor: 'test',
      )..apply(doc);

      final plan = planOutletFromTemplate(
        doc: doc,
        template: doc.registries.outletTemplates['outlet.ap']!,
        locationId: room.id,
        now: _now,
        actor: 'test',
      );
      expect(plan, isA<OutletTemplatePlanNeedsStructure>());
    });

    test('a recipe with no drops refuses rather than making a bare plate', () {
      // An outlet with no cables is indistinguishable from a gesture
      // that silently failed.
      final p = _project();
      p.doc.registries.outletTemplates['tpl.empty'] = OutletTemplate(
        id: 'tpl.empty',
        name: 'Empty',
      );

      final plan = _plan(p, 'tpl.empty');
      expect(plan, isA<OutletTemplatePlanRefused>());
      expect((plan as OutletTemplatePlanRefused).reason, contains('nothing'));
      expect(p.doc.outlets, isEmpty);
    });

    test('a media type the DOCUMENT does not carry refuses and names it', () {
      // Resolved through the document's own registry, not the seed: a
      // document carries the subset it references, and a drop whose
      // media resolves to nothing would ship as a grey label.
      final p = _project();
      p.doc.registries.mediaTypes.remove(const MediaTypeId('media.cat6'));

      final plan = _plan(p, 'outlet.tv_location');
      expect(plan, isA<OutletTemplatePlanRefused>());
      expect(
        (plan as OutletTemplatePlanRefused).reason,
        contains('media.cat6'),
      );
    });

    test('a room with no code cannot be labelled, and says which field', () {
      final p = _project(code: '');
      final plan = _plan(p, 'outlet.tv_location');

      expect(plan, isA<OutletTemplatePlanRefused>());
      final reason = (plan as OutletTemplatePlanRefused).reason;
      expect(reason, contains('short code'));
      // The human field leads; the pattern is context, not the headline.
      expect(reason.indexOf('short code'), lessThan(reason.indexOf('SERVICE')));
    });

    test('nothing is applied when anything refuses', () {
      final p = _project(code: '');
      expect(_plan(p, 'outlet.tv_location'), isA<OutletTemplatePlanRefused>());

      expect(p.doc.outlets, isEmpty);
      expect(p.doc.links, isEmpty);
      expect(p.doc.nets, isEmpty);
    });
  });

  group('what a picker offers', () {
    test('nine templates, the six named ones first', () {
      // Insertion order, not alphabetical: sorting would put *AP* above
      // *TV location* and scatter the grades through the six.
      final offered = offerableOutletTemplates(buildSeedRegistries());

      expect(offered, hasLength(9));
      expect(offered.first.id, 'outlet.tv_location');
      expect(offered.last.id, 'outlet.tia570d_grade3');
    });
  });
}
