// M3-E/1, #156 — what the Pathways tab's gestures mean in commands.
//
// WHAT THIS GATES. `Pathway.kind` and `Pathway.containsLineVoltage` are
// read by M5's `CODE-001` and `CODE-002` (NEC 800.154), and until this
// task nothing in the product could set either: no editor existed, and
// both sat at their constructor defaults on an entity whose only writer
// was `RemoveLocationCommand` clearing two location references. So the
// assertions that matter are the ones that would catch a control that
// renders a value without writing it, and the ones that keep the undo
// stack honest about a delete that is NOT a cascade.
//
// THE VOCABULARY IS THE ROUND TRIP. The tab sends what it DISPLAYED, so
// every enum here goes out through `pathwayKindLabel` and comes back
// through it. A test drives `DIRECT BURY` specifically, because that is
// the value where a label has already stopped being the enum name
// uppercased and where matching on `.name` would break silently.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/pathway_actions.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _when = DateTime.utc(2026, 8, 9);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

final _clock = FixedClock(_when);

DocumentController _controller() {
  final doc = RackDocument(
    id: const Uuid('doc-pathway-actions'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  return DocumentController(doc, clock: _clock);
}

Uuid _pathway(DocumentController c, String name) {
  final command = AddPathwayCommand(
    name: name,
    order: nextPathwayOrder(c.doc),
    now: _when,
    actor: 'seed',
  );
  c.transact(LabelKey.addPathway, (tx) => tx.add(command));
  return command.id;
}

Uuid _link(DocumentController c, String designator, {Uuid? pathwayId}) {
  final id = Uuid('link-$designator');
  c.doc.links[id] = Link(
    id: id,
    designator: designator,
    media: const MediaTypeId('media.cat6'),
    order: FracIndex('a$designator'),
    meta: _meta(),
    pathwayId: pathwayId,
    conductors: [
      const Conductor(
        from: PlaceEndpoint(description: 'drop'),
        to: OpenEndpoint('coil'),
      ),
    ],
  );
  return id;
}

void main() {
  late DocumentController controller;

  setUp(() => controller = _controller());

  String? edit(Uuid id, PathwayColumnId column, String value) =>
      buildPathwayEditAction(controller: controller)([
        PathwayCellEdit(pathwayId: id, column: column, value: value),
      ]);

  group('the two fields M5 is waiting on', () {
    test('KIND round-trips through the label the tab displayed', () {
      final id = _pathway(controller, 'attic run');
      // `directBury` prints `DIRECT BURY`: the case where matching on
      // `.name` would compile and fail.
      expect(edit(id, PathwayColumnId.kind, 'DIRECT BURY'), isNull);
      expect(controller.doc.pathways[id]!.kind, PathwayKind.directBury);
    });

    test('DR-031 two new values are reachable', () {
      final id = _pathway(controller, 'PW-1');
      expect(edit(id, PathwayColumnId.kind, 'ATTIC'), isNull);
      expect(controller.doc.pathways[id]!.kind, PathwayKind.attic);
      expect(edit(id, PathwayColumnId.kind, 'CRAWLSPACE'), isNull);
      expect(controller.doc.pathways[id]!.kind, PathwayKind.crawlspace);
    });

    test('a kind nobody spells is refused, and the refusal lists them', () {
      final id = _pathway(controller, 'PW-1');
      final refusal = edit(id, PathwayColumnId.kind, 'DUCT');
      expect(refusal, isNotNull);
      expect(refusal, contains('CRAWLSPACE'));
      expect(controller.doc.pathways[id]!.kind, PathwayKind.conduit);
    });

    test('LINE VOLTAGE writes both ways', () {
      final id = _pathway(controller, 'PW-1');
      expect(
        edit(id, PathwayColumnId.lineVoltage, kLineVoltageYesCell),
        isNull,
      );
      expect(controller.doc.pathways[id]!.containsLineVoltage, isTrue);
      expect(edit(id, PathwayColumnId.lineVoltage, kLineVoltageNoCell), isNull);
      expect(controller.doc.pathways[id]!.containsLineVoltage, isFalse);
    });

    test('a plenum pathway with line voltage is accepted, not refused', () {
      // M5's `CODE-002` is an ERROR on exactly this. It is not
      // implemented here: canon §5, a rule not listed does not exist, and
      // a tier-2 rule built as a tier-1 refusal makes the product unable
      // to draw a mistake (G2, CR-017).
      final id = _pathway(controller, 'riser');
      expect(edit(id, PathwayColumnId.kind, 'PLENUM'), isNull);
      expect(
        edit(id, PathwayColumnId.lineVoltage, kLineVoltageYesCell),
        isNull,
      );
      expect(controller.doc.pathways[id]!.kind, PathwayKind.plenumSpace);
      expect(controller.doc.pathways[id]!.containsLineVoltage, isTrue);
    });
  });

  group('the other columns', () {
    test('a blank name is refused rather than stored', () {
      // `Pathway.name` is non-nullable, so there is no unknown state to
      // land in, and a blank one prints as the unknown dash in the Pull
      // Sheet's `PATH` column on every run through it (G4).
      final id = _pathway(controller, 'PW-LR-1');
      expect(edit(id, PathwayColumnId.name, '   '), kPathwayNeedsAName);
      expect(controller.doc.pathways[id]!.name, 'PW-LR-1');
    });

    test('a length is whole feet, and a cleared box is UNKNOWN', () {
      final id = _pathway(controller, 'PW-1');
      expect(edit(id, PathwayColumnId.nominalLength, '40'), isNull);
      expect(controller.doc.pathways[id]!.nominalLength, isNotNull);
      expect(edit(id, PathwayColumnId.nominalLength, ''), isNull);
      // Null is UNKNOWN and clearing is a legal edit; it is never a
      // measured zero (G4, CR-114).
      expect(controller.doc.pathways[id]!.nominalLength, isNull);
    });

    test('a fractional length is refused in core own words', () {
      final id = _pathway(controller, 'PW-1');
      final refusal = edit(id, PathwayColumnId.nominalLength, '62.5');
      expect(refusal, contains('whole feet'));
    });

    test('MEDIA takes a pathway-only type and refuses a cable', () {
      // CR-109: conduit is not a cable, and the flag is what stops
      // somebody recording that it is.
      final id = _pathway(controller, 'PW-1');
      expect(edit(id, PathwayColumnId.media, 'EMT conduit'), isNull);
      expect(
        controller.doc.pathways[id]!.pathwayMedia,
        const MediaTypeId('media.conduit_emt'),
      );

      final refusal = edit(id, PathwayColumnId.media, 'Cat6');
      expect(refusal, contains('pathway-only'));
      expect(
        controller.doc.pathways[id]!.pathwayMedia,
        const MediaTypeId('media.conduit_emt'),
      );
    });

    test('the unknown dash clears MEDIA back to nobody-has-said', () {
      final id = _pathway(controller, 'PW-1');
      edit(id, PathwayColumnId.media, 'EMT conduit');
      expect(edit(id, PathwayColumnId.media, kUnknownCell), isNull);
      expect(controller.doc.pathways[id]!.pathwayMedia, isNull);
    });

    test('an empty note lands as null and never as an empty string', () {
      final id = _pathway(controller, 'PW-1');
      edit(id, PathwayColumnId.notes, 'pulled 2026-08-09');
      expect(edit(id, PathwayColumnId.notes, '  '), isNull);
      expect(controller.doc.pathways[id]!.notes, isNull);
    });

    test('RUNS cannot be typed into', () {
      final id = _pathway(controller, 'PW-1');
      expect(edit(id, PathwayColumnId.runs, '6'), kRunsIsDerived);
    });

    test('an edit to a pathway that is gone is refused, not applied', () {
      expect(
        edit(const Uuid('nope'), PathwayColumnId.name, 'x'),
        'That pathway is not in this project.',
      );
    });
  });

  group('add and remove', () {
    test('add creates one pathway, undoably, with a visible placeholder', () {
      final add = buildPathwayAddAction(controller: controller);
      expect(add(), isNull);
      expect(controller.doc.pathways, hasLength(1));
      expect(controller.doc.pathways.values.single.name, kNewPathwayName);

      controller.undoLast();
      expect(controller.doc.pathways, isEmpty);
    });

    test('two adds get distinct orders, so the list order is not the map', () {
      final add = buildPathwayAddAction(controller: controller);
      add();
      add();
      final orders = controller.doc.pathways.values.map((p) => p.order.v);
      expect(orders.toSet(), hasLength(2));
    });

    test('remove keeps the cable and clears its route, and undo restores', () {
      // NOT A CASCADE. Nothing lives inside a pathway, so the run
      // survives having lost its recorded route. The reference is
      // CLEARED rather than left dangling: a dangling id prints a `PATH`
      // cell identical to "nobody said" (G4).
      final id = _pathway(controller, 'PW-1');
      final linkId = _link(controller, 'W1', pathwayId: id);

      expect(buildPathwayRemoveAction(controller: controller)(id), isNull);
      expect(controller.doc.pathways, isEmpty);
      expect(controller.doc.links[linkId], isNotNull);
      expect(controller.doc.links[linkId]!.pathwayId, isNull);

      controller.undoLast();
      expect(controller.doc.pathways[id], isNotNull);
      expect(controller.doc.links[linkId]!.pathwayId, id);
    });

    test('removing a pathway that is gone is refused', () {
      expect(
        buildPathwayRemoveAction(controller: controller)(const Uuid('nope')),
        'That pathway is not in this project.',
      );
    });
  });

  group('the wiring reads the injected clock and actor', () {
    test('an edit stamps the controller clock, not the wall clock', () {
      final id = _pathway(controller, 'PW-1');
      edit(id, PathwayColumnId.kind, 'TRAY');
      expect(controller.doc.pathways[id]!.meta.updatedAt, _when);
    });
  });
}
