// M3-H/2 (#167) and M3-H/3 (#168) — the Outlets tab.
//
// WHAT THESE GATE. The tab's design claim is the same one every other
// surface in this editor makes: it renders derivations and contains
// none. So the cases that matter are the ones that would catch it
// starting to decide things, and the two that would be worst are both
// about G4 wearing a colour: a cell nobody has decided about drawn as a
// blank, and an unknown jacket colour drawn as a real one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final DateTime _now = DateTime.utc(2026, 8, 11);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't');

const _outletId = Uuid('22222222-2222-4222-8222-222222222222');
const _bodyId = Uuid('11111111-1111-4111-8111-111111111111');

var _seq = 0;

/// A project with one Structure body, one outlet, and whatever drops the
/// case needs.
RackDocument _project({
  List<Gang>? gangs,
  Map<JacketColorId, JacketColorDef>? conventions,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-outlets'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  if (conventions != null) {
    doc.settings.jacketColorConventions.addAll(conventions);
  }
  doc.structures[_bodyId] = StructureBody(
    id: _bodyId,
    deviceId: const Uuid('33333333-3333-4333-8333-000000000001'),
    title: 'Media Panel',
    meta: _meta(),
  );
  doc.outlets[_outletId] = Outlet(
    id: _outletId,
    structureBodyId: _bodyId,
    designation: 'WP-1',
    order: const FracIndex('a0'),
    meta: _meta(),
    gangs: gangs,
  );
  return doc;
}

Link _addDrop(
  RackDocument doc, {
  required String fieldLabel,
  TerminationType? termination,
  int conductors = 2,
  JacketColorId? convention,
  JacketColorId? pulled,
}) {
  _seq++;
  final link = Link(
    id: Uuid('44444444-4444-4444-8444-${_seq.toString().padLeft(12, '0')}'),
    designator: 'W$_seq',
    media: const MediaTypeId('media.cat6'),
    order: FracIndex('a$_seq'),
    meta: _meta(),
    jacketColorId: convention,
    jacketColorPulledId: pulled,
    conductors: [
      for (var i = 0; i < conductors; i++)
        const Conductor(from: OpenEndpoint('a'), to: OpenEndpoint('b')),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: _bodyId,
      outletId: _outletId,
      fieldLabel: fieldLabel,
      terminationField: termination,
    ),
  );
  doc.links[link.id] = link;
  return link;
}

/// The `RemoveGangCommand`s the harness actually applied, in order.
///
/// KEPT SO UNDO CAN BE DRIVEN ON THE REAL OBJECT. A fresh command cannot
/// revert one that has already run: `RemoveGangCommand` stores the gang
/// it removed, so a second instance built after the fact finds the index
/// out of range and no-ops. This list is what makes an undo assertion in
/// a widget test mean anything, and its absence is how the first draft of
/// that case passed while asserting nothing.
final List<RemoveGangCommand> _appliedRemovals = <RemoveGangCommand>[];

/// Applies the tab's gestures straight to [doc]: the commands are core's
/// and this package may not reach for a `DocumentController`.
OutletsActions _actions(RackDocument doc, {List<String>? log}) =>
    OutletsActions(
      onAddGang: (outletId) {
        log?.add('addGang');
        AddGangCommand(outletId: outletId).apply(doc);
        return null;
      },
      onRemoveGang: (outletId, gangIndex) {
        log?.add('removeGang $gangIndex');
        final command = RemoveGangCommand(
          outletId: outletId,
          index: gangIndex,
        );
        _appliedRemovals.add(command);
        command.apply(doc);
        return null;
      },
      onSetStrap: (outletId, gangIndex, width, height) {
        log?.add('setStrap $gangIndex ${width}x$height');
        SetStrapSizeCommand(
          outletId: outletId,
          index: gangIndex,
          width: width,
          height: height,
        ).apply(doc);
        return null;
      },
      onSetCell: (outletId, gangIndex, cellIndex, occupant) {
        log?.add('setCell $gangIndex:$cellIndex ${occupant.runtimeType}');
        SetCellOccupantCommand(
          outletId: outletId,
          gangIndex: gangIndex,
          cellIndex: cellIndex,
          occupant: occupant,
        ).apply(doc);
        return null;
      },
      onArrange: (outletId, plan) {
        log?.add('arrange ${plan.straps.length} gang');
        final outlet = doc.outlets[outletId]!;
        for (var i = outlet.gangs.length - 1; i >= 0; i--) {
          RemoveGangCommand(outletId: outletId, index: i).apply(doc);
        }
        for (final strap in plan.straps) {
          AddGangCommand(
            outletId: outletId,
            width: strap.width,
            height: strap.height,
          ).apply(doc);
        }
        for (final cell in plan.cells) {
          SetCellOccupantCommand(
            outletId: outletId,
            gangIndex: cell.gangIndex,
            cellIndex: cell.cellIndex,
            occupant: cell.occupant,
          ).apply(doc);
        }
        return null;
      },
    );

Future<void> _pump(
  WidgetTester tester,
  RackDocument doc, {
  List<String>? log,
  Size? surface,
}) async {
  // A PLATE IS DRAWN TO SCALE, so a 3-gang one is 647 units wide and does
  // not fit the 800x600 default surface once the outlet list and the drop
  // list have taken their columns. The pane scrolls horizontally rather
  // than clipping, which means `getRect` on a wide plate measures the
  // VIEWPORT and not the part. Cases that measure the drawing therefore
  // ask for a surface the drawing fits in, rather than the drawing being
  // shrunk to fit a test.
  if (surface != null) {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OutletsView(
          doc: doc,
          structureBodyId: _bodyId,
          actions: _actions(doc, log: log),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the tab opens something', () {
    testWidgets('an outlet with nothing on it says so, and is not called '
        'plateless', (tester) async {
      // A surface, not a blank. The rule `shell_tabs_test.dart` states
      // and the reason this tab was absent until M3-H.
      //
      // THIS CASE USED TO EXPECT "no gangs yet" FOR AN EMPTY OUTLET, and
      // that was the collapsed sentence DR-045 §11.44.4 split: an empty
      // outlet and a plateless one both have zero gangs, and only the
      // drop count tells them apart.
      await _pump(tester, _project());
      // THE PLATE PANE'S OWN SENTENCE, not the drop list's. Those two
      // said the same words for a moment and the finder matched both,
      // which is how the duplication was noticed at all.
      expect(find.textContaining('Nothing to fit yet'), findsOneWidget);
      expect(find.text('+ Add gang'), findsOneWidget);
      expect(find.text('Arrange'), findsOneWidget);
    });

    testWidgets('a drop that needs a cell asks for a gang', (tester) async {
      final doc = _project();
      _addDrop(
        doc,
        fieldLabel: 'LR-DATA-1',
        termination: TerminationType.keystone,
      );
      await _pump(tester, doc);
      expect(find.textContaining('no gangs yet'), findsOneWidget);
    });

    testWidgets('AN AP BOX IS FINISHED, and says so (DR-045 §11.44.4)', (
      tester,
    ) async {
      // The case the product could not express: one Cat6 into an access
      // point that mounts straight to the box. No strap, no cover plate,
      // nothing missing. It read as unfinished work from M3-H until now.
      final doc = _project();
      _addDrop(
        doc,
        fieldLabel: 'LR-AP-1',
        termination: TerminationType.rj45Plug,
      );
      await _pump(tester, doc);
      expect(find.textContaining('needs no plate'), findsOneWidget);
      expect(find.textContaining('no gangs yet'), findsNothing);
    });

    testWidgets('an UNKNOWN termination is never called plateless', (
      tester,
    ) async {
      // G4: "needs no plate" over a drop nobody has terminated is a
      // guess, and it is the guess that omits a part from a materials
      // sheet.
      final doc = _project();
      _addDrop(doc, fieldLabel: 'LR-DATA-9');
      await _pump(tester, doc);
      expect(find.textContaining('needs no plate'), findsNothing);
      expect(find.textContaining('no gangs yet'), findsOneWidget);
    });

    testWidgets('a project with no outlets says so rather than blanking', (
      tester,
    ) async {
      final doc = _project()..outlets.clear();
      await _pump(tester, doc);
      expect(find.textContaining('No outlets yet'), findsOneWidget);
    });

    testWidgets('the cover plate chip is gangs.length, always', (tester) async {
      // §11.7.8 change 1, on screen: N straps plus exactly ONE N-gang
      // cover plate, and the count is never free.
      await _pump(tester, _project(gangs: [Gang(), Gang(), Gang()]));
      expect(find.text('3-gang cover plate'), findsOneWidget);
    });
  });

  group('a gang with no strap says so, and does not say zero', () {
    testWidgets('the label reads No strap rather than 0-port', (tester) async {
      await _pump(tester, _project(gangs: [Gang()]));
      // "0-port" would make an undecided part look like a decided one.
      expect(find.text('No strap'), findsOneWidget);
      expect(find.text('0-port'), findsNothing);
    });

    testWidgets('a fitted strap names its port count', (tester) async {
      await _pump(
        tester,
        _project(gangs: [Gang(strap: Strap(width: 2, height: 3))]),
      );
      expect(find.text('6-port'), findsOneWidget);
    });
  });

  group('the plate is drawn as one part (DR-042)', () {
    testWidgets('a 3-gang plate is ONE outline at the measured width', (
      tester,
    ) async {
      await _pump(
        tester,
        _project(
          gangs: [
            Gang(strap: Strap(width: 1, height: 3)),
            Gang(strap: Strap(width: 2, height: 3)),
            Gang(),
          ],
        ),
        surface: const Size(1600, 900),
      );
      // Until DR-042 this was three free-floating boxes with an
      // arbitrary gap: a picture of some holes rather than of a part.
      final rect = tester.getRect(find.byKey(const ValueKey('plate-outline')));
      expect(
        rect.width,
        closeTo(
          PlateGeometry.unitsForLen(PlateGeometry.plateWidthFor(3)),
          0.01,
        ),
      );
    });

    testWidgets('EVERY CELL LANDS INSIDE ITS OWN OPENING', (tester) async {
      // The case that catches the coordinate rebase. `cellAt` returns
      // PLATE coordinates and each gang widget's box IS its opening, so
      // the opening's inset has to come back off. Forget it and every
      // cell shifts down and right by 18 x 24 mm, which is visible but
      // is exactly the kind of thing that ships because the picture
      // still looks like a plate.
      await _pump(
        tester,
        _project(
          gangs: [
            Gang(strap: Strap(width: 2, height: 3)),
            Gang(strap: Strap(width: 2, height: 3)),
          ],
        ),
        surface: const Size(1600, 900),
      );
      for (var g = 0; g < 2; g++) {
        final opening = tester.getRect(
          find.byKey(ValueKey('plate-opening-$g')),
        );
        for (var c = 0; c < 6; c++) {
          final cell = tester.getRect(find.byKey(ValueKey('plate-cell-$g-$c')));
          expect(
            opening.contains(cell.topLeft),
            isTrue,
            reason: 'gang $g cell $c top-left',
          );
          expect(
            opening.contains(cell.bottomRight),
            isTrue,
            reason: 'gang $g cell $c bottom-right',
          );
        }
      }
    });

    testWidgets('the openings are inset from the plate edge, both axes', (
      tester,
    ) async {
      // §11.7.8 change 2 made visible rather than implied: there is real
      // plastic before the first hole and after the last one.
      await _pump(
        tester,
        _project(gangs: [Gang(strap: Strap(width: 1, height: 1))]),
        surface: const Size(1600, 900),
      );
      final plate = tester.getRect(find.byKey(const ValueKey('plate-outline')));
      final opening = tester.getRect(
        find.byKey(const ValueKey('plate-opening-0')),
      );
      final left = opening.left - plate.left;
      final right = plate.right - opening.right;
      final top = opening.top - plate.top;
      final bottom = plate.bottom - opening.bottom;
      expect(left, closeTo(right, 0.01));
      expect(top, closeTo(bottom, 0.01));
      expect(
        left,
        closeTo(PlateGeometry.unitsForLen(PlateGeometry.edgeMarginX), 0.01),
      );
    });
  });

  group('a gang can be deleted (M3-H/5, #674)', () {
    testWidgets('an EMPTY gang goes without a prompt', (tester) async {
      // A dialog for a gesture that destroys nothing trains people to
      // dismiss dialogs, which is what makes the one that matters
      // ineffective.
      final doc = _project(
        gangs: [
          Gang(),
          Gang(strap: Strap(width: 1, height: 1)),
        ],
      );
      final log = <String>[];
      await _pump(tester, doc, log: log);

      await tester.tap(find.byKey(const ValueKey('plate-remove-0')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(log, ['removeGang 0']);
      expect(doc.outlets[_outletId]!.gangs, hasLength(1));
    });

    testWidgets('a gang WITH CELLS asks first and counts what it discards', (
      tester,
    ) async {
      final strap = Strap(width: 2, height: 3);
      strap.cells[0] = const LinkEndOccupant(
        Uuid('44444444-4444-4444-8444-000000000001'),
      );
      strap.cells[3] = const BlankInsert();
      final doc = _project(gangs: [Gang(strap: strap)]);
      final log = <String>[];
      // A WINDOW, NOT A PHONE. A 2x3 plate is 457 units tall before any
      // chrome, so at the 800x600 default the controls under it sit off
      // the bottom of the surface and a tap silently misses.
      await _pump(tester, doc, log: log, surface: const Size(1600, 900));

      await tester.tap(find.byKey(const ValueKey('plate-remove-0')));
      await tester.pumpAndSettle();
      // DR-013's "a confirmation that counts the cables", at gang scale.
      expect(find.textContaining('2 filled cell(s)'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(doc.outlets[_outletId]!.gangs, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('plate-remove-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(log, ['removeGang 0']);
      expect(doc.outlets[_outletId]!.gangs, isEmpty);
    });

    testWidgets('the x deletes the gang it sits under, not the first', (
      tester,
    ) async {
      // Gangs are addressed by POSITION, so an off-by-one here removes a
      // different opening and looks like it worked.
      final doc = _project(
        gangs: [
          Gang(strap: Strap(width: 1, height: 1)),
          Gang(strap: Strap(width: 2, height: 3)),
          Gang(),
        ],
      );
      final log = <String>[];
      await _pump(tester, doc, log: log, surface: const Size(1600, 900));

      await tester.tap(find.byKey(const ValueKey('plate-remove-1')));
      await tester.pumpAndSettle();
      expect(log, ['removeGang 1']);

      final gangs = doc.outlets[_outletId]!.gangs;
      expect(gangs, hasLength(2));
      // The 6-port went; the 1-port and the strapless one remain, in
      // order.
      expect(gangs[0].strap!.cellCount, 1);
      expect(gangs[1].strap, isNull);
    });

    testWidgets('undo puts the gang back with everything in it', (
      tester,
    ) async {
      // The command already tests this; what this adds is that the
      // GESTURE reaches that command rather than some other path.
      const linkId = Uuid('44444444-4444-4444-8444-000000000002');
      final strap = Strap(width: 1, height: 2);
      strap.cells[1] = const LinkEndOccupant(linkId);
      final doc = _project(gangs: [Gang(strap: strap)]);
      _appliedRemovals.clear();

      await _pump(tester, doc, surface: const Size(1600, 900));
      await tester.tap(find.byKey(const ValueKey('plate-remove-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(doc.outlets[_outletId]!.gangs, isEmpty);

      // REVERTING THE COMMAND THE GESTURE ACTUALLY RAN. A fresh instance
      // would find index 0 out of range on an empty list and no-op,
      // which is how the first draft of this case passed nothing while
      // looking like it asserted undo.
      expect(_appliedRemovals, hasLength(1));
      _appliedRemovals.single.revert(doc);
      expect(doc.outlets[_outletId]!.gangs, hasLength(1));
      expect(
        doc.outlets[_outletId]!.gangs.single.strap!.cells[1],
        const LinkEndOccupant(linkId),
      );
    });
  });

  group('a cell offers two different answers for "empty"', () {
    testWidgets('blank insert and clear are separate options', (tester) async {
      final doc = _project(gangs: [Gang(strap: Strap(width: 1, height: 1))]);
      final log = <String>[];
      await _pump(tester, doc, log: log);

      await tester.tap(find.byKey(const ValueKey('plate-cell-0-0')));
      await tester.pumpAndSettle();

      // ONE IS A PURCHASE AND ONE IS THE ABSENCE OF A DECISION, and the
      // labels have to say which is which or the materials sheet ends up
      // ordering blanks nobody chose (§11.7.4).
      expect(find.textContaining('Blank insert'), findsOneWidget);
      expect(find.textContaining('Clear it'), findsOneWidget);

      await tester.tap(find.textContaining('Blank insert'));
      await tester.pumpAndSettle();
      expect(log, ['setCell 0:0 BlankInsert']);
      expect(
        doc.outlets[_outletId]!.gangs[0].strap!.cells[0],
        isA<BlankInsert>(),
      );
    });

    testWidgets('DISMISSING the picker changes nothing', (tester) async {
      // The bug this exists to prevent: `Clear it` and a dismissed dialog
      // both spell null, so a bare `CellOccupant?` return makes pressing
      // Escape erase a cell. Cancel must never be destructive.
      final strap = Strap(width: 1, height: 1);
      strap.cells[0] = const BlankInsert();
      final doc = _project(gangs: [Gang(strap: strap)]);
      final log = <String>[];
      await _pump(tester, doc, log: log);

      await tester.tap(find.byKey(const ValueKey('plate-cell-0-0')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(log, isEmpty);
      expect(
        doc.outlets[_outletId]!.gangs[0].strap!.cells[0],
        isA<BlankInsert>(),
      );
    });

    testWidgets('a binding-post drop offers one option PER POST', (
      tester,
    ) async {
      final doc = _project(gangs: [Gang(strap: Strap(width: 2, height: 2))]);
      _addDrop(
        doc,
        fieldLabel: 'LR-SPK-1',
        termination: TerminationType.bindingPost,
        conductors: 4,
      );
      await _pump(tester, doc);

      await tester.tap(find.byKey(const ValueKey('plate-cell-0-0')));
      await tester.pumpAndSettle();
      // A cell holds ONE conductor, so the person has to say which
      // (§11.7.2.1). One option for the drop would put four posts behind
      // one click and then be unable to place the other three.
      //
      // BY POST AND NOT BY A COUNT OF THE LABEL, because the drop list
      // behind the dialog carries `LR-SPK-1` too and a bare count of
      // that string was off by one for a reason that had nothing to do
      // with what this case is about.
      for (var post = 1; post <= 4; post++) {
        expect(find.text('LR-SPK-1  post $post'), findsOneWidget);
      }
    });
  });

  group('the keystone follows the CONVENTION (M3-H/3, CR-121)', () {
    testWidgets('a mis-pulled run keeps its convention colour on the cell', (
      tester,
    ) async {
      const blue = JacketColorId('jc.blue');
      const yellow = JacketColorId('jc.yellow');
      final doc = _project(
        conventions: {
          blue: const JacketColorDef(
            displayName: 'Blue',
            abbr: 'BLU',
            color: Rgb(0, 0, 255),
          ),
          yellow: const JacketColorDef(
            displayName: 'Yellow',
            abbr: 'YEL',
            color: Rgb(255, 255, 0),
          ),
        },
      );
      final link = _addDrop(
        doc,
        fieldLabel: 'LR-CTL-1',
        termination: TerminationType.keystone,
        convention: blue,
        pulled: yellow,
      );
      final strap = Strap(width: 1, height: 1);
      strap.cells[0] = LinkEndOccupant(link.id);
      doc.outlets[_outletId]!.gangs.add(Gang(strap: strap));
      await _pump(tester, doc);

      // THE EXCEPTION IS TEXT AND NEVER A HUE. The keystone is fitted
      // weeks after the pull out of the box the convention calls for, so
      // it is BLU on a run that went in yellow.
      final tip = tester.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tip.message, contains('BLU'));
      expect(tip.message, contains('PULLED YEL'));
      // And the drop list says the same thing in the same order.
      expect(find.textContaining('PULLED YEL'), findsWidgets);
    });

    testWidgets('a run with no convention colour is drawn as UNKNOWN', (
      tester,
    ) async {
      final doc = _project();
      final link = _addDrop(
        doc,
        fieldLabel: 'LR-DATA-1',
        termination: TerminationType.keystone,
      );
      final strap = Strap(width: 1, height: 1);
      strap.cells[0] = LinkEndOccupant(link.id);
      doc.outlets[_outletId]!.gangs.add(Gang(strap: strap));
      await _pump(tester, doc);

      // NOT A DEFAULT GREY. Grey is a colour somebody could have chosen,
      // and six grey jacks would be indistinguishable from six nobody
      // specified (G4).
      final tip = tester.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tip.message, contains('no jacket colour recorded'));
    });

    testWidgets('a dangling colour id is distinguished from an absent one', (
      tester,
    ) async {
      final doc = _project();
      final link = _addDrop(
        doc,
        fieldLabel: 'LR-DATA-1',
        termination: TerminationType.keystone,
        convention: const JacketColorId('jc.deleted'),
      );
      final strap = Strap(width: 1, height: 1);
      strap.cells[0] = LinkEndOccupant(link.id);
      doc.outlets[_outletId]!.gangs.add(Gang(strap: strap));
      await _pump(tester, doc);

      // "Somebody said blue and the entry is gone" is a different fact
      // from "nobody said", and the resolver keeps them apart, so the
      // surface has to as well.
      final tip = tester.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tip.message, contains('not in this project'));
    });
  });

  group('the counts are the derivation and are never folded together', () {
    testWidgets('an unknown drop is counted, not absorbed into shortfall', (
      tester,
    ) async {
      final doc = _project(gangs: [Gang(strap: Strap(width: 1, height: 3))]);
      _addDrop(
        doc,
        fieldLabel: 'LR-DATA-1',
        termination: TerminationType.keystone,
      );
      _addDrop(doc, fieldLabel: 'LR-DATA-2');
      await _pump(tester, doc);

      // Room for everything KNOWN and one drop nobody has terminated is
      // not a plate that fits. `totals.dart`'s rule 2 on screen.
      expect(find.textContaining('1 unknown'), findsWidgets);
      expect(find.textContaining('fits'), findsNothing);
    });

    testWidgets('unplaced counts partial placement as unplaced', (
      tester,
    ) async {
      final doc = _project(gangs: [Gang(strap: Strap(width: 2, height: 3))]);
      final speaker = _addDrop(
        doc,
        fieldLabel: 'LR-SPK-1',
        termination: TerminationType.bindingPost,
        conductors: 4,
      );
      doc.outlets[_outletId]!.gangs[0].strap!.cells[0] = ConductorOccupant(
        ConductorRef(speaker.id, 0),
      );
      await _pump(tester, doc);
      expect(find.text('1 of 1 unplaced'), findsOneWidget);
    });
  });

  group('Arrange sizes the plate and reports what it left out', () {
    testWidgets('an empty plate arranges without a confirmation', (
      tester,
    ) async {
      final doc = _project();
      for (var i = 0; i < 3; i++) {
        _addDrop(
          doc,
          fieldLabel: 'LR-DATA-$i',
          termination: TerminationType.keystone,
        );
      }
      final log = <String>[];
      await _pump(tester, doc, log: log);

      await tester.tap(find.text('Arrange'));
      await tester.pumpAndSettle();

      expect(log, ['arrange 1 gang']);
      final gangs = doc.outlets[_outletId]!.gangs;
      expect(gangs, hasLength(1));
      expect(gangs[0].strap!.cellCount, 3);
      expect(gangs[0].strap!.cells, hasLength(3));
    });

    testWidgets('a plate with work on it ASKS FIRST and Cancel means it', (
      tester,
    ) async {
      final doc = _project();
      final link = _addDrop(
        doc,
        fieldLabel: 'LR-DATA-1',
        termination: TerminationType.keystone,
      );
      final strap = Strap(width: 2, height: 3);
      strap.cells[4] = LinkEndOccupant(link.id);
      doc.outlets[_outletId]!.gangs.add(Gang(strap: strap));
      final log = <String>[];
      await _pump(tester, doc, log: log);

      await tester.tap(find.text('Arrange'));
      await tester.pumpAndSettle();
      // DR-013's confirmation that COUNTS what it will discard.
      expect(find.textContaining('1 keystone(s)'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      // Untouched: still a 6-port with the jack in cell 4.
      expect(doc.outlets[_outletId]!.gangs[0].strap!.cells[4], isNotNull);
    });

    testWidgets('nothing to arrange says WHY when the cause is unknowns', (
      tester,
    ) async {
      final doc = _project();
      _addDrop(doc, fieldLabel: 'LR-DATA-1');
      _addDrop(doc, fieldLabel: 'LR-DATA-2');
      await _pump(tester, doc);

      await tester.tap(find.text('Arrange'));
      await tester.pumpAndSettle();
      // A refused action reports and never silently does nothing.
      expect(
        find.textContaining('no recorded field termination'),
        findsOneWidget,
      );
    });
  });
}
