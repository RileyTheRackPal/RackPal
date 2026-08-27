// M3-C/5, #151 — `+ Add outlet ▾`, driven by taps.
//
// WHAT THESE ASSERT. That the labels are on screen BEFORE the button is
// pressed, because CR-048 stores a designator once at creation and this
// is the last cheap moment; that the choice and not the preview's plan
// crosses into the app, which is the defect M3-A/6 found in the sibling
// panel; and that the citation a grade preset carries is visible, because
// a citation nobody can see is not a citation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final DateTime _now = DateTime.utc(2026, 8, 8);

RackDocument _project({
  List<(String, String)> rooms = const [('Living Room', 'LR')],
  bool withStructure = true,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-pick'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't'),
  )..registries = buildSeedRegistries();

  if (withStructure) {
    AddStructureCommand(
      title: 'Rough-In',
      designator: 'STR-1',
      now: _now,
      actor: 't',
    ).apply(doc);
  }

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

/// The harness the picker drives: it applies what it is given and records
/// what it was asked to do, which is all the app layer does too.
final class _Harness {
  _Harness(this.doc);

  final RackDocument doc;
  final List<String> committedTemplates = [];
  int structuresRequested = 0;

  OutletTemplateActions get actions => OutletTemplateActions(
    onCommit: (template, locationId) {
      committedTemplates.add(template.id);
      // THE APP'S OWN CLOCK AND ACTOR, which is the whole reason the
      // choice crosses this boundary rather than the preview's commands.
      final plan = planOutletFromTemplate(
        doc: doc,
        template: template,
        locationId: locationId,
        now: _now,
        actor: 'harness',
      );
      if (plan is OutletTemplatePlanReady) {
        for (final c in plan.commands) {
          c.apply(doc);
        }
      }
      return plan;
    },
    onCreateStructure: () {
      structuresRequested++;
      AddStructureCommand(
        title: 'Rough-In',
        designator: 'STR-1',
        now: _now,
        actor: 't',
      ).apply(doc);
    },
  );
}

Future<void> _pump(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => OutletTemplatePicker(
            doc: h.doc,
            actions: OutletTemplateActions(
              onCommit: (t, l) {
                final plan = h.actions.onCommit(t, l);
                setState(() {});
                return plan;
              },
              onCreateStructure: () {
                h.actions.onCreateStructure();
                setState(() {});
              },
            ),
          ),
        ),
      ),
    ),
  );
}

/// Nine recipes do not fit in the list's 380 px, so a row below the fold
/// has to be scrolled to before it is in the tree at all. Asserting
/// otherwise would pin a layout the picker does not have.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -60));
    await tester.pumpAndSettle();
  }
}

/// Picks one recipe by name.
///
/// `ensureVisible` IS NOT OPTIONAL HERE. A `ListView` builds past its
/// viewport into the cache extent, so a row can be in the element tree
/// and still be clipped: `_scrollTo` stops as soon as the text EXISTS,
/// and a tap at that point lands on the clip and does nothing at all.
/// `.first` because the citation appears twice inside one tile, as its
/// name and as its trailing tag, so the ancestor finder returns the same
/// `ListTile` once per match.
Future<void> _select(WidgetTester tester, String name) async {
  await _scrollTo(tester, find.text(name));
  final tile = find.widgetWithText(ListTile, name).first;
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pump();
}

void main() {
  group('the nine recipes are on offer, with what they pull', () {
    testWidgets('every seeded template is a row', (tester) async {
      await _pump(tester, _Harness(_project()));

      for (final name in const [
        'TV location',
        'AP',
        'Keypad',
        'Ceiling speaker pair',
        'Camera',
        'Data only',
        'TIA-570-D Grade 1',
        'TIA-570-D Grade 2',
        'TIA-570-D Grade 3',
      ]) {
        await _scrollTo(tester, find.text(name));
        expect(find.text(name), findsWidgets, reason: name);
      }
    });

    testWidgets('the recipe is spelled out, not just named', (tester) async {
      // Choosing between *TV location* and *Grade 2* must not require
      // remembering what either contains.
      await _pump(tester, _Harness(_project()));

      expect(find.text('2 × Cat6 UTP · 2 × RG6 quad-shield'), findsOneWidget);
    });

    testWidgets('the {SERVICE} tag is shown, because it prints', (
      tester,
    ) async {
      // `TV` is the segment that ends up on cable, and it is the part a
      // person cannot infer from the words "Ceiling speaker pair".
      await _pump(tester, _Harness(_project()));

      expect(find.text('TV'), findsOneWidget);
      expect(find.text('SPK'), findsOneWidget);
    });

    testWidgets('a grade preset shows the standard it cites', (tester) async {
      // A citation nobody can see is not a citation. It appears twice for
      // the grades: as the name and as the trailing tag.
      await _pump(tester, _Harness(_project()));
      await _scrollTo(tester, find.text('TIA-570-D Grade 2'));

      expect(find.text('TIA-570-D Grade 2'), findsNWidgets(2));
    });
  });

  group('the preview is the labels, before anything is committed', () {
    testWidgets('picking a recipe shows what will be printed', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      await _select(tester, 'TV location');

      expect(find.text('LR-TV-1, LR-TV-2, LR-TV-3, LR-TV-4'), findsOneWidget);
      // And nothing has happened yet.
      expect(h.doc.outlets, isEmpty);
      expect(h.doc.links, isEmpty);
    });

    testWidgets('the outlet name and the citation are in the summary', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      await _select(tester, 'TIA-570-D Grade 2');

      expect(
        find.text('Outlet LR-1 · 4 drops · TIA-570-D Grade 2'),
        findsOneWidget,
      );
    });

    testWidgets('a room with no code refuses, and says which field', (
      tester,
    ) async {
      final h = _Harness(_project(rooms: const [('Attic', '')]));
      await _pump(tester, h);

      await _select(tester, 'TV location');

      expect(find.textContaining('short code'), findsOneWidget);
    });
  });

  group('committing', () {
    testWidgets('adds one outlet and its drops', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      await _select(tester, 'TV location');
      await tester.tap(find.text('Add outlet').last);
      await tester.pump();

      expect(h.doc.outlets, hasLength(1));
      expect(h.doc.links, hasLength(4));
      expect(h.committedTemplates, ['outlet.tv_location']);
    });

    testWidgets("THE CHOICE CROSSES, NOT THE PREVIEW'S COMMANDS", (
      tester,
    ) async {
      // The defect M3-A/6 found in the sibling panel: the preview plans
      // with `actor: 'preview'` and a throwaway clock, and both reach
      // `EntityMeta` on every command a plan holds. The harness re-plans
      // with its own, so the document must carry the harness's actor and
      // never the string `preview`.
      final h = _Harness(_project());
      await _pump(tester, h);

      await _select(tester, 'TV location');
      await tester.tap(find.text('Add outlet').last);
      await tester.pump();

      for (final l in h.doc.links.values) {
        expect(l.meta.updatedBy, 'harness');
        expect(l.meta.createdAt, _now);
      }
      expect(h.doc.outlets.values.single.meta.updatedBy, 'harness');
    });

    testWidgets('the recipe stays picked, so a second room is one change', (
      tester,
    ) async {
      // Placing four TV locations in four rooms should be one room change
      // and one click each. Resetting the recipe would make the second
      // cost two.
      final h = _Harness(
        _project(rooms: const [('Living Room', 'LR'), ('Kitchen', 'KIT')]),
      );
      await _pump(tester, h);

      await _select(tester, 'TV location');
      await tester.tap(find.text('Add outlet').last);
      await tester.pump();
      await tester.tap(find.text('Add outlet').last);
      await tester.pump();

      expect(h.doc.outlets, hasLength(2));
      expect(h.doc.links, hasLength(8));
    });

    testWidgets('labels continue rather than restarting', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      await _select(tester, 'TV location');
      await tester.tap(find.text('Add outlet').last);
      await tester.pump();

      final labels = {
        for (final l in h.doc.links.values)
          if (l.structureOrigin case final o?) o.fieldLabel,
      };
      expect(labels, {'LR-TV-1', 'LR-TV-2', 'LR-TV-3', 'LR-TV-4'});

      await tester.tap(find.text('Add outlet').last);
      await tester.pump();

      expect(h.doc.links, hasLength(8));
      expect(
        {
          for (final l in h.doc.links.values)
            if (l.structureOrigin case final o?) o.fieldLabel,
        },
        hasLength(8),
      );
    });
  });

  group('the offer that is not a refusal', () {
    testWidgets('no Structure device offers to create one', (tester) async {
      final h = _Harness(_project(withStructure: false));
      await _pump(tester, h);

      await _select(tester, 'TV location');

      expect(find.textContaining('no Structure device'), findsOneWidget);
      expect(find.text('Create Structure device'), findsOneWidget);

      await tester.tap(find.text('Create Structure device'));
      await tester.pump();

      expect(h.structuresRequested, 1);
      expect(h.doc.structures, hasLength(1));
      // And the button is the ordinary one again.
      expect(find.text('Add outlet'), findsWidgets);
    });

    testWidgets('a project with no rooms says where to make one', (
      tester,
    ) async {
      final h = _Harness(_project(rooms: const []));
      await _pump(tester, h);

      expect(find.textContaining('no rooms yet'), findsOneWidget);
    });
  });

  group('the recipe summary', () {
    test('names an unresolved media id rather than dropping the drop', () {
      // §6.2: an unresolved id "round-trips, renders grey with the raw id
      // as its tag, and never throws". A row that silently dropped a drop
      // would understate what is about to be pulled.
      final registries = buildSeedRegistries();
      final template = OutletTemplate(
        id: 'tpl.odd',
        name: 'Odd',
        drops: [
          OutletDrop(
            media: const MediaTypeId('media.house_special'),
            service: 'structure.undetermined',
            count: 3,
          ),
        ],
      );

      expect(
        recipeSummary(template, registries),
        '3 × media.house_special',
      );
    });
  });
}
