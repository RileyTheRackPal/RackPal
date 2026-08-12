// M3-L/1 (#671) and M3-L/2 (#672), DR-043 §11.42 and DR-044 §11.43.
//
// The three paths a field termination can now arrive by, and the one
// thing all three still refuse to do: write a value nobody stated.
import 'dart:convert';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 11);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 't');

RackDocument _project() {
  final doc = RackDocument(
    id: const Uuid('doc-term'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  AddStructureCommand(
    title: 'Media Panel',
    designator: 'STR-1',
    now: _when,
    actor: 't',
  ).apply(doc);
  AddLocationCommand(
    name: 'Living Room',
    code: 'LR',
    order: nextLocationOrder(doc),
    now: _when,
    actor: 't',
  ).apply(doc);
  return doc;
}

/// Commits one typed line and returns the plan.
DropLinePlan _commit(RackDocument doc, String line) {
  final parsed = parseDropLine(line);
  if (parsed is! DropLineParsed) {
    fail('the line did not parse: $parsed');
  }
  final plan = planDropLine(
    doc: doc,
    line: parsed,
    now: _when,
    actor: 't',
  );
  if (plan is DropLinePlanReady) {
    for (final c in plan.commands) {
      c.apply(doc);
    }
  }
  return plan;
}

List<TerminationType?> _terminations(RackDocument doc) => [
  for (final l in doc.links.values) l.structureOrigin?.terminationField,
];

void main() {
  group('the default does not move (DR-043 §11.42.1)', () {
    test('a line with no colon leaves every drop Unspecified', () {
      final doc = _project();
      _commit(doc, 'Living Room: 2x Cat6');
      expect(_terminations(doc), [null, null]);
    });

    test('and the key is ABSENT on disk, not an explicit null', () {
      final doc = _project();
      _commit(doc, 'Living Room: 1x Cat6');
      const codec = JsonDocumentCodec();
      expect(
        utf8.decode(codec.write(doc)),
        isNot(contains('"terminationField"')),
      );
    });
  });

  group('4x Cat6:punchdown, the item grammar (DR-043 §11.42.3)', () {
    test('the colon binds to the item it follows, not to the line', () {
      final doc = _project();
      _commit(doc, 'Living Room: 2x Cat6:punchdown, 1x RG6:f barrel');
      final byLabel = {
        for (final l in doc.links.values)
          l.structureOrigin!.fieldLabel: l.structureOrigin!.terminationField,
      };
      // TWO ITEMS, TWO DIFFERENT ANSWERS. A line-level `@term=` could not
      // express this at all, which is the argument for the colon.
      expect(
        byLabel.values.where((t) => t == TerminationType.punchdown).length,
        2,
      );
      expect(
        byLabel.values.where((t) => t == TerminationType.fBarrel).length,
        1,
      );
    });

    test('an item with no colon stays Unspecified beside one that has', () {
      final doc = _project();
      _commit(doc, 'Living Room: 1x Cat6:punchdown, 1x RG6');
      final set = _terminations(doc).toSet();
      expect(set, {TerminationType.punchdown, null});
    });

    test('the count still parses, so 4x means four', () {
      final doc = _project();
      _commit(doc, 'Living Room: 4x Cat6:punchdown');
      expect(doc.links, hasLength(4));
      expect(
        _terminations(doc).every((t) => t == TerminationType.punchdown),
        isTrue,
      );
    });
  });

  group('the vocabulary is core’s and no alias is invented (§11.42.4)', () {
    test('case and punctuation do not matter', () {
      for (final token in ['fBarrel', 'fbarrel', 'F BARREL', 'f barrel']) {
        expect(
          resolveTerminationToken(token),
          TerminationType.fBarrel,
          reason: token,
        );
      }
    });

    test('"post" does NOT resolve to bindingPost', () {
      // Trade shorthand in a parser is how a product ends up with two
      // vocabularies, one of them undocumented.
      expect(resolveTerminationToken('post'), isNull);
      expect(
        resolveTerminationToken('binding post'),
        TerminationType.bindingPost,
      );
    });

    test('a bad token refuses the WHOLE line and lists what is accepted', () {
      final doc = _project();
      final plan = _commit(doc, 'Living Room: 2x Cat6:wombat, 1x RG6');
      expect(plan, isA<DropLinePlanRefused>());
      final refused = plan as DropLinePlanRefused;
      expect(refused.reason, contains('wombat'));
      expect(refused.reason, contains('PUNCHDOWN'));
      // NOTHING WAS CREATED. A line that cannot be parsed leaves no
      // drops, which is `buildDropsFor`'s all-or-nothing read one stage
      // earlier.
      expect(doc.links, isEmpty);
    });

    test('a caret points at the token and not at the line', () {
      final plan = _commit(_project(), 'Living Room: 2x Cat6:wombat');
      final refused = plan as DropLinePlanRefused;
      expect(refused.column, isNotNull);
      expect(
        'Living Room: 2x Cat6:wombat'.substring(refused.column!),
        'wombat',
      );
    });

    test('an empty termination is refused by the parser, with a caret', () {
      final parsed = parseDropLine('Living Room: 2x Cat6:');
      expect(parsed, isA<DropLineMalformed>());
      expect(
        (parsed as DropLineMalformed).reason,
        contains('nothing after it'),
      );
    });

    test('every accepted spelling round-trips through the token list', () {
      // The refusal sentence and the resolver cannot disagree about what
      // is accepted, because the sentence is built from this list.
      for (final token in terminationTokens()) {
        expect(resolveTerminationToken(token), isNotNull, reason: token);
      }
      expect(terminationTokens(), hasLength(TerminationType.values.length));
    });
  });

  group('the template path, which needs no typing at all (§11.42.2)', () {
    test('the nine shipped templates all carry a termination (DR-044)', () {
      // 11.43.1: with none of them seeded and no way to author one, the
      // field would have been null everywhere for ever.
      final templates = buildSeedRegistries().outletTemplates;
      expect(templates, hasLength(9));
      for (final t in templates.values) {
        for (final d in t.drops) {
          expect(
            d.termination,
            isNotNull,
            reason: '${t.name} / ${d.media.v}',
          );
        }
      }
    });

    test('twisted pair is PUNCHDOWN, which is the shop’s answer', () {
      // 11.43.3: `keystone` was the recommended option and punchdown was
      // the answer. Face-on the two draw identically, so only the
      // Termination Schedule would have shown the difference.
      final templates = buildSeedRegistries().outletTemplates;
      final tv = templates['outlet.tv_location']!;
      expect(
        tv.drops.firstWhere((d) => d.media.v == 'media.cat6').termination,
        TerminationType.punchdown,
      );
      expect(
        tv.drops.firstWhere((d) => d.media.v == 'media.rg6_quad').termination,
        TerminationType.fBarrel,
      );
    });

    test('a keypad is a euroblock, and therefore needs no cell', () {
      final templates = buildSeedRegistries().outletTemplates;
      final keypad = templates['outlet.keypad']!;
      expect(keypad.drops.single.termination, TerminationType.euroblock);
      expect(cellsRequiredFor(keypad.drops.single.termination, 4), 0);
    });

    test('a speaker pair is binding posts, four cells for a 16/4', () {
      final templates = buildSeedRegistries().outletTemplates;
      final spk = templates['outlet.ceiling_speaker_pair']!;
      expect(spk.drops.single.termination, TerminationType.bindingPost);
      // §11.7.2.2's case that bites, arrived at from a seeded recipe.
      expect(cellsRequiredFor(spk.drops.single.termination, 4), 4);
    });

    test('+ Add outlet stamps the recipe onto every drop it creates', () {
      final doc = _project();
      final plan = planOutletFromTemplate(
        doc: doc,
        template: doc.registries.outletTemplates['outlet.tv_location']!,
        locationId: doc.locations.values.single.id,
        now: _when,
        actor: 't',
      );
      expect(plan, isA<OutletTemplatePlanReady>());
      for (final c in (plan as OutletTemplatePlanReady).commands) {
        c.apply(doc);
      }
      // THE WHOLE POINT OF THE TEMPLATE FIELD: four drops, all specified,
      // nobody typed anything.
      final terms = _terminations(doc);
      expect(terms, hasLength(4));
      expect(terms.contains(null), isFalse);
      expect(
        terms.where((t) => t == TerminationType.punchdown).length,
        2,
      );
      expect(terms.where((t) => t == TerminationType.fBarrel).length, 2);
    });

    test('and the plate Arrange produces is now sizeable', () {
      // The end of the chain #668 was raised about: before DR-043 every
      // drop the product could create reported as unknown here.
      final doc = _project();
      final plan =
          planOutletFromTemplate(
                doc: doc,
                template: doc.registries.outletTemplates['outlet.tv_location']!,
                locationId: doc.locations.values.single.id,
                now: _when,
                actor: 't',
              )
              as OutletTemplatePlanReady;
      for (final c in plan.commands) {
        c.apply(doc);
      }
      final outlet = doc.outlets.values.single;
      final arrangement = planPlateArrangement(outlet, doc.links.values);
      expect(arrangement.skippedUnknown, 0);
      expect(arrangement.cells, hasLength(4));
      expect(arrangement.straps, [(width: 2, height: 2)]);
    });
  });

  group('an OutletDrop.termination survives the file (CR-117)', () {
    test('it round-trips byte-exactly, and null writes no key', () {
      const codec = JsonDocumentCodec();
      final doc = _project();
      doc.registries.outletTemplates['t.specified'] = OutletTemplate(
        id: 't.specified',
        name: 'Specified',
        drops: [
          OutletDrop(
            media: const MediaTypeId('media.cat6'),
            service: 'net.ethernet',
            termination: TerminationType.punchdown,
          ),
        ],
      );
      doc.registries.outletTemplates['t.silent'] = OutletTemplate(
        id: 't.silent',
        name: 'Silent',
        drops: [
          OutletDrop(
            media: const MediaTypeId('media.cat6'),
            service: 'net.ethernet',
          ),
        ],
      );

      final first = codec.write(doc);
      final reread = codec.read(first);
      expect(reread, isA<Ok<RackDocument>>());
      final back = (reread as Ok<RackDocument>).value;
      expect(codec.write(back), equals(first));

      expect(
        back
            .registries
            .outletTemplates['t.specified']!
            .drops
            .single
            .termination,
        TerminationType.punchdown,
      );
      expect(
        back.registries.outletTemplates['t.silent']!.drops.single.termination,
        isNull,
      );
    });
  });
}
