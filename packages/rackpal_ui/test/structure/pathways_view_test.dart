// M3-E/1 (#156) — the `[ Pathways ]` tab.
//
// WHAT THESE GATE. `Pathway.kind` and `Pathway.containsLineVoltage` are
// read by M5's `CODE-001` and `CODE-002` (NEC 800.154), and both sat at
// their constructor defaults on an entity NO SURFACE COULD REACH. So the
// assertions that matter are the ones that would catch the control going
// back to being decorative: a dropdown that renders the value but does
// not write it, a checkbox-shaped cell whose "false" is indistinguishable
// from "nothing rendered", and a delete that quietly takes cable with it.
//
// AND NO RULE FIRES HERE. A plenum pathway carrying line voltage is
// accepted without a word, because canon §5 says a rule not listed does
// not exist and a tier-2 rule built as a tier-1 refusal makes the product
// unable to draw a mistake (G2, CR-017). A test asserts that silence,
// because "the validation is missing" and "the validation was moved to
// M5 on purpose" look identical from the outside.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final DateTime _now = DateTime.utc(2026, 8, 9);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't');

/// The app layer's three actions, in the shape the app layer runs them:
/// build against the live document, refuse whole, then apply.
///
/// MIRRORED RATHER THAN IMPORTED, because `rackpal_ui` may not depend on
/// `apps/rackpal` and the harness has to be driveable without a
/// `DocumentController`. `pathway_actions_test.dart` on the app side
/// drives the real thing.
final class _Harness {
  _Harness(this.doc);

  final RackDocument doc;

  /// What the last edit refused with, or null if it did not refuse.
  ///
  /// The real tab shows this to the person; a test that only checked the
  /// document would pass on a silent no-op, which looks identical to a
  /// save from the outside.
  String? lastRefusal;

  PathwaysActions get actions => PathwaysActions(
    onEdit: edit,
    onAdd: add,
    onRemove: remove,
  );

  String? edit(List<PathwayCellEdit> edits) => lastRefusal = _edit(edits);

  String? _edit(List<PathwayCellEdit> edits) {
    for (final e in edits) {
      final Command<RackDocument>? command;
      switch (e.column) {
        // THROUGH THE REFUSING BUILDER, matching the app's real path.
        // `buildSetEntityProperty` would write a duplicate designator
        // silently, and a harness that is laxer than the product tests
        // a product that does not exist (DR-026 §11.25.1).
        case PathwayColumnId.designator:
          final result = buildSetPathwayDesignator(
            doc: doc,
            pathwayId: e.pathwayId,
            to: e.value,
            now: _now,
            actor: 'editor',
          );
          if (result is SetPathwayDesignatorRefused) return result.reason;
          // Unchanged is not a refusal: nothing to push, nothing wrong.
          command = result is SetPathwayDesignatorReady ? result.command : null;
        case PathwayColumnId.name:
          final trimmed = e.value.trim();
          if (trimmed.isEmpty) return 'A pathway needs a name.';
          command = buildSetEntityProperty<Pathway, String>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.name,
            to: trimmed,
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.kind:
          final kind = PathwayKind.values
              .where((k) => pathwayKindLabel(k) == e.value.trim().toUpperCase())
              .firstOrNull;
          if (kind == null) return '"${e.value}" is not a pathway kind.';
          command = buildSetEntityProperty<Pathway, PathwayKind>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.kind,
            to: kind,
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.lineVoltage:
          command = buildSetEntityProperty<Pathway, bool>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.containsLineVoltage,
            to: e.value.trim().toUpperCase() == kLineVoltageYesCell,
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.media:
          final match = doc.registries.mediaTypes.values
              .where((d) => d.isPathwayOnly && d.displayName == e.value.trim())
              .firstOrNull;
          command = buildSetEntityProperty<Pathway, MediaTypeId?>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.pathwayMedia,
            to: match?.id,
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.nominalLength:
          final parse = parseLengthCell(e.value, doc.settings.displayUnits);
          switch (parse) {
            case CellRefused<Len>(:final reason):
              return reason;
            case CellParsed<Len>(:final value):
              command = buildSetEntityProperty<Pathway, Len?>(
                doc: doc,
                id: e.pathwayId,
                field: PathwayField.nominalLength,
                to: value,
                now: _now,
                actor: 'editor',
              );
          }
        case PathwayColumnId.notes:
          command = buildSetEntityProperty<Pathway, String?>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.notes,
            to: e.value.trim().isEmpty ? null : e.value.trim(),
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.runs:
          return 'RUNS is derived.';
      }
      if (command != null) command.apply(doc);
    }
    return null;
  }

  String? add() {
    AddPathwayCommand(
      name: 'New pathway',
      order: nextPathwayOrder(doc),
      now: _now,
      actor: 'adder',
    ).apply(doc);
    return null;
  }

  String? remove(Uuid id) {
    RemovePathwayCommand(id: id, now: _now).apply(doc);
    return null;
  }
}

RackDocument _project() => RackDocument(
  id: const Uuid('doc-pathways-tab'),
  appVersion: '0.1.0',
  createdAt: _now,
  modifiedAt: _now,
  meta: _meta(),
)..registries = buildSeedRegistries();

Uuid _pathway(
  RackDocument doc,
  String id,
  String name, {
  PathwayKind kind = PathwayKind.conduit,
  bool containsLineVoltage = false,
  MediaTypeId? pathwayMedia,
  String? designator,
}) {
  final uuid = Uuid(id);
  doc.pathways[uuid] = Pathway(
    id: uuid,
    name: name,
    designator: designator,
    order: nextPathwayOrder(doc),
    meta: _meta(),
    kind: kind,
    containsLineVoltage: containsLineVoltage,
    pathwayMedia: pathwayMedia,
  );
  return uuid;
}

Uuid _link(RackDocument doc, String designator, {Uuid? pathwayId}) {
  final id = Uuid('link-$designator');
  doc.links[id] = Link(
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

/// The three dropdowns in a row, in column order.
///
/// BY TYPE AND INDEX RATHER THAN BY THE TEXT SHOWING. Every unknown in
/// this table prints the same dash, and a `TextField`'s hint is a `Text`
/// too, so `find.text('—').first` picks whichever cell happens to paint
/// first — which is how the first draft of these tests tapped the LENGTH
/// hint and concluded the MEDIA menu was empty.
Finder _kindCell(int row) => find.byType(DropdownButton<String>).at(row * 3);
Finder _lineVoltageCell(int row) =>
    find.byType(DropdownButton<String>).at(row * 3 + 1);
Finder _mediaCell(int row) =>
    find.byType(DropdownButton<String>).at(row * 3 + 2);

/// The text cell for one column, by COUNTING the text columns before it
/// rather than by a hard-coded index.
///
/// THE HARD-CODED INDEX IS WHAT BROKE. This helper exists because
/// `find.byType(TextField).first` meant "the NAME cell" only for as long
/// as `name` happened to be the first column; M3-E/2 put `DESIGNATOR`
/// in front of it and the assertion silently started testing a different
/// cell. Derived from `PathwayColumnId.values`, it survives the next
/// column too.
Finder _textCell(int row, PathwayColumnId column) {
  final textColumns = PathwayColumnId.values
      .where(
        (id) =>
            pathwayColumnIsEditable(id) &&
            id != PathwayColumnId.kind &&
            id != PathwayColumnId.lineVoltage &&
            id != PathwayColumnId.media,
      )
      .toList();
  final index = textColumns.indexOf(column);
  assert(index >= 0, '$column is not a text column');
  return find.byType(TextField).at(row * textColumns.length + index);
}

/// Rebuilds from the live document on every frame, which is what the real
/// editor does: the tab reads `currentDoc()` per build, so a command
/// applied by a callback is visible on the next pump.
///
/// THE VIEWPORT IS WIDENED TO FIT THE WHOLE ROW. The table scrolls
/// sideways below its authored width by design (`_DropTable`'s rule), and
/// a default 800 px test window leaves the delete affordance off-screen,
/// where a tap silently misses. Widening asserts against the layout the
/// editor actually gets rather than against a clipped one.
Future<void> _pump(WidgetTester tester, _Harness h) async {
  tester.view
    ..physicalSize = const Size(1400, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => PathwaysView(
            doc: h.doc,
            actions: PathwaysActions(
              onEdit: (edits) {
                final refusal = h.edit(edits);
                setState(() {});
                return refusal;
              },
              onAdd: () {
                final refusal = h.add();
                setState(() {});
                return refusal;
              },
              onRemove: (id) {
                final refusal = h.remove(id);
                setState(() {});
                return refusal;
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Picks [label] out of the dropdown at [dropdown].
Future<void> _choose(
  WidgetTester tester,
  Finder dropdown,
  String label,
) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  // A `DropdownButton`'s menu renders a SECOND copy of every item, so the
  // open menu's entry is the last match rather than the first.
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('the empty state', () {
    testWidgets('names the two gestures that make a pathway', (tester) async {
      await _pump(tester, _Harness(_project()));
      expect(find.textContaining('No conduits'), findsOneWidget);
      // It names the drop line, which is DR-032's gesture and is BUILT.
      // Copy naming an unbuilt surface is what
      // `unbuilt_copy_accuracy_test.dart` exists to catch.
      expect(find.textContaining('Living Room: 1x ENT'), findsOneWidget);
    });

    testWidgets('does not name the Plan view, which is not built', (
      tester,
    ) async {
      await _pump(tester, _Harness(_project()));
      expect(find.textContaining('Plan view'), findsNothing);
    });
  });

  group('the two fields M5 is waiting on', () {
    testWidgets('KIND writes through, including DR-031 two new values', (
      tester,
    ) async {
      final doc = _project();
      final id = _pathway(doc, 'pth-a', 'attic run to the garage');
      final h = _Harness(doc);
      await _pump(tester, h);

      expect(find.text('CONDUIT'), findsWidgets);
      await _choose(tester, _kindCell(0), 'ATTIC');

      expect(doc.pathways[id]!.kind, PathwayKind.attic);
      expect(find.text('ATTIC'), findsWidgets);
    });

    testWidgets('LINE VOLTAGE writes through, and false is a visible NO', (
      tester,
    ) async {
      // The cell is words and not a tick glyph, because the app reads it
      // back to decide the value: `✓` against blank would make "false"
      // and "nothing rendered" the same string.
      final doc = _project();
      final id = _pathway(doc, 'pth-a', 'PW-LR-1');
      final h = _Harness(doc);
      await _pump(tester, h);

      expect(find.text(kLineVoltageNoCell), findsWidgets);
      await _choose(tester, _lineVoltageCell(0), kLineVoltageYesCell);

      expect(doc.pathways[id]!.containsLineVoltage, isTrue);
    });

    testWidgets('a plenum pathway with line voltage is accepted in silence', (
      tester,
    ) async {
      // M5's `CODE-002` is an ERROR on exactly this document. It does not
      // fire here and must not: canon §5, a rule not listed does not
      // exist, and G2 requires the document be able to represent a
      // mistake so the product can flag it later.
      final doc = _project();
      final id = _pathway(doc, 'pth-a', 'riser', kind: PathwayKind.plenumSpace);
      final h = _Harness(doc);
      await _pump(tester, h);

      await _choose(tester, _lineVoltageCell(0), kLineVoltageYesCell);

      expect(doc.pathways[id]!.containsLineVoltage, isTrue);
      expect(doc.pathways[id]!.kind, PathwayKind.plenumSpace);
      expect(find.textContaining('800.154'), findsNothing);
      expect(find.textContaining('CODE-'), findsNothing);
    });
  });

  group('DESIGNATOR, hand-entered and unique where set (M3-E/2, #157)', () {
    testWidgets('it is the FIRST column, ahead of PATHWAY', (tester) async {
      // Identifiers lead everywhere else in this product: the drop table
      // opens with FIELD LABEL and RACK LABEL, the equipment list with
      // designators. Asserted on the header order rather than on a pixel
      // position, so a layout change does not fail it spuriously.
      final doc = _project();
      _pathway(doc, 'pth-a', 'attic run to the garage', designator: 'T1');
      await _pump(tester, _Harness(doc));

      final designatorX = tester.getTopLeft(find.text('DESIGNATOR')).dx;
      final pathwayX = tester.getTopLeft(find.text('PATHWAY')).dx;
      expect(designatorX, lessThan(pathwayX));
    });

    testWidgets('typing one writes it through', (tester) async {
      final doc = _project();
      final id = _pathway(doc, 'pth-a', 'attic run to the garage');
      final h = _Harness(doc);
      await _pump(tester, h);

      await tester.enterText(
        _textCell(0, PathwayColumnId.designator),
        'T1',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(doc.pathways[id]!.designator, 'T1');
      // The NAME is untouched. Two facts, and the one this column does
      // not own stays where it was (DR-026 §11.25.1).
      expect(doc.pathways[id]!.name, 'attic run to the garage');
    });

    testWidgets('a DUPLICATE springs back and says why', (tester) async {
      // The refusal has to reach the person, not just the return value.
      // A silent no-op here would look identical to a save, and two
      // trunks called T1 on one Pull Sheet is the defect the column
      // exists to prevent.
      final doc = _project();
      final a = _pathway(doc, 'pth-a', 'attic run', designator: 'T1');
      final b = _pathway(doc, 'pth-b', 'riser');
      final h = _Harness(doc);
      await _pump(tester, h);

      await tester.enterText(
        _textCell(1, PathwayColumnId.designator),
        'T1',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(doc.pathways[b]!.designator, isNull);
      expect(doc.pathways[a]!.designator, 'T1');
      expect(h.lastRefusal, contains('already used by another pathway'));
    });

    testWidgets('clearing one is legal even when another pathway has one', (
      tester,
    ) async {
      final doc = _project();
      final a = _pathway(doc, 'pth-a', 'attic run', designator: 'T1');
      _pathway(doc, 'pth-b', 'riser', designator: 'T2');
      final h = _Harness(doc);
      await _pump(tester, h);

      await tester.enterText(_textCell(0, PathwayColumnId.designator), '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Null never collides, so this is not a refusal (G4, CR-114).
      expect(doc.pathways[a]!.designator, isNull);
      expect(h.lastRefusal, isNull);
    });
  });

  group('the other columns', () {
    testWidgets('the name commits on losing focus', (tester) async {
      final doc = _project();
      final id = _pathway(doc, 'pth-a', 'New pathway');
      final h = _Harness(doc);
      await _pump(tester, h);

      await tester.enterText(
        _textCell(0, PathwayColumnId.name),
        'attic run to the garage',
      );
      // Committing on blur is what makes `Tab` work: a person filling a
      // column types, tabs, types, tabs, and never presses Enter at all.
      // Unfocusing directly is what `Tab` does to the cell being left,
      // without depending on where the next focusable widget happens to
      // be.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(doc.pathways[id]!.name, 'attic run to the garage');
    });

    testWidgets('MEDIA offers only isPathwayOnly types', (tester) async {
      // CR-109's whole point: offering `Cat6` here would let somebody
      // record that a conduit is a cable.
      final doc = _project();
      _pathway(doc, 'pth-a', 'PW-1');
      await _pump(tester, _Harness(doc));

      await tester.tap(_mediaCell(0));
      await tester.pumpAndSettle();

      expect(find.text('EMT conduit'), findsWidgets);
      expect(find.text('Cat6'), findsNothing);
    });

    testWidgets('RUNS counts cables and cannot be typed into', (tester) async {
      final doc = _project();
      final id = _pathway(doc, 'pth-a', 'PW-1');
      _link(doc, 'W1', pathwayId: id);
      _link(doc, 'W2', pathwayId: id);
      await _pump(tester, _Harness(doc));

      expect(find.text('2'), findsWidgets);
      expect(pathwayColumnIsEditable(PathwayColumnId.runs), isFalse);
    });
  });

  group('add and delete', () {
    testWidgets('the button creates a pathway the list then shows', (
      tester,
    ) async {
      final doc = _project();
      final h = _Harness(doc);
      await _pump(tester, h);

      expect(find.textContaining('No conduits'), findsOneWidget);
      await tester.tap(find.text(kAddPathwayLabel));
      await tester.pumpAndSettle();

      expect(doc.pathways, hasLength(1));
      expect(find.textContaining('No conduits'), findsNothing);
    });

    testWidgets('deleting keeps the cable and clears its route', (
      tester,
    ) async {
      // NOT A CASCADE. Nothing lives inside a pathway, so the run
      // survives having lost its recorded route, which is the state every
      // drop in this product was in until `bcb1b31`.
      final doc = _project();
      final id = _pathway(doc, 'pth-a', 'PW-1');
      final linkId = _link(doc, 'W1', pathwayId: id);
      await _pump(tester, _Harness(doc));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(doc.pathways, isEmpty);
      expect(doc.links[linkId], isNotNull);
      // CLEARED, never left dangling: a dangling id prints a `PATH` cell
      // identical to "nobody said" (G4).
      expect(doc.links[linkId]!.pathwayId, isNull);
    });

    testWidgets('the delete tooltip states the count before the click', (
      tester,
    ) async {
      final doc = _project();
      final id = _pathway(doc, 'pth-a', 'PW-1');
      _link(doc, 'W1', pathwayId: id);
      _link(doc, 'W2', pathwayId: id);
      await _pump(tester, _Harness(doc));

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.tooltip, contains('2 runs'));
    });
  });

  group('the counts', () {
    testWidgets('reports the unknown lengths even when there are none', (
      tester,
    ) async {
      // A line that disappears when the news is good makes its absence
      // unreadable: "0 lengths unknown" says the takeoff is complete.
      final doc = _project();
      _pathway(doc, 'pth-a', 'PW-1');
      _pathway(doc, 'pth-b', 'PW-2');
      await _pump(tester, _Harness(doc));

      expect(find.textContaining('2 pathways'), findsOneWidget);
      expect(find.textContaining('2 lengths unknown'), findsOneWidget);
    });

    testWidgets('names the runs that go through no pathway at all', (
      tester,
    ) async {
      final doc = _project();
      _pathway(doc, 'pth-a', 'PW-1');
      _link(doc, 'W1');
      _link(doc, 'W2');
      _link(doc, 'W3');
      await _pump(tester, _Harness(doc));

      expect(
        find.textContaining('3 runs through no pathway'),
        findsOneWidget,
      );
    });
  });
}
