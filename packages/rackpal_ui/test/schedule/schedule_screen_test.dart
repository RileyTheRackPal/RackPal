// The Schedule tab (docs/08 §3, docs/05 §12, CR-105/AC-035).
//
// WHAT THESE TESTS DEFEND, in order of how much it would cost to get
// wrong:
//
//  1. **THE SCREEN DOES NOT DERIVE.** Every number it shows comes from
//     `rackpal_core`'s `derived/schedule.dart`. The assertions below
//     compare what is on screen against what `buildScheduleView` says
//     rather than against literals, so a screen that started computing
//     its own rows would have to agree with core to pass — which is the
//     property §3.1's "one derivation" actually asks for.
//  2. **ZERO ROWS IS CORRECT, NOT AVOIDED.** CR-105 asks for a tab
//     "populating live from an EMPTY project". The header row renders
//     before any data does, and the copy states an absence in the
//     DOCUMENT rather than an accusation about the user — docs/09 M1
//     calls the other kind of empty schedule a lie.
//  3. **NOTHING HIDDEN IS SILENT.** A jumper excluded by AC-026's
//     default, a class the classifier could not determine, a jacket
//     colour pulled off-convention: each is on screen as a number.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _when = DateTime.utc(2026, 7, 28);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

RackDocument _emptyDoc() => RackDocument(
  id: const Uuid('doc-ui'),
  appVersion: 'test',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

/// Every string actually rendered below [root].
List<String> _textsUnder(WidgetTester tester, Finder root) {
  final out = <String>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      final data = widget.data;
      if (data != null) out.add(data);
    } else if (widget is RichText) {
      out.add(widget.text.toPlainText());
    }
    element.visitChildren(visit);
  }

  tester.element(root).visitChildren(visit);
  return out;
}

Future<void> _pump(WidgetTester tester, RackDocument doc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ScheduleScreen(document: doc)),
    ),
  );
  await tester.pumpAndSettle();
}

/// A document with one home run from a room to a patch-panel port, one
/// in-rack jumper, and one link whose far end names a port that does not
/// exist — the three cases the tab has to tell apart.
RackDocument _populatedDoc() {
  final doc = _emptyDoc();
  const room = Uuid('loc-great');
  const rackId = Uuid('rack-1');
  const panelId = Uuid('dev-pp');
  const switchId = Uuid('dev-sw');
  const panelPort = Uuid('port-a03');
  const panelPort2 = Uuid('port-a11');
  const switchPort = Uuid('port-p11');

  doc.locations[room] = Location(
    id: room,
    kind: LocationKind.room,
    name: 'Great Room',
    code: 'GR',
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.racks[rackId] = Rack(
    id: rackId,
    name: 'Master',
    designator: 'RK-1',
    heightU: 42,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  DeviceInstance device(Uuid id, String designator, int ru) => DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('tpl.x'),
      version: 1,
      contentHash: 'h',
    ),
    designator: designator,
    name: designator,
    placement: RailPlacement(rackId: rackId, ruIndex: ru, face: Face.rear),
    meta: _meta(),
  );
  doc.devices[panelId] = device(panelId, 'PP-1', 14);
  doc.devices[switchId] = device(switchId, 'SW-1', 20);
  for (final (id, deviceId, designator) in [
    (panelPort, panelId, 'A03'),
    (panelPort2, panelId, 'A11'),
    (switchPort, switchId, 'P11'),
  ]) {
    doc.ports[id] = Port(id: id, deviceId: deviceId, designator: designator);
  }

  // `cutLength` IS A CONSTRUCTOR ARGUMENT AND NOT A CASCADE, since
  // M3-D/2 gave it the AC-013 retrofit: the setter is `@internal`, so
  // this package cannot write it and the analyzer says so. Building the
  // fixture through the constructor is the fix rather than a workaround
  // — it is what every other field on this Link already does.
  Link link(
    String id,
    String designator,
    Endpoint from,
    Endpoint to, {
    Len? cutLength,
  }) => Link(
    id: Uuid(id),
    designator: designator,
    media: const MediaTypeId('media.cat6a_futp'),
    order: FracIndex('a$designator'),
    meta: _meta(),
    conductors: [Conductor(from: from, to: to)],
    cutLength: cutLength,
  );

  final home =
      link(
          'lnk-1',
          'W015',
          const PlaceEndpoint(description: 'TV wall', locationId: room),
          const PortEndpoint(panelPort),
          cutLength: const Len(78 * 12 * Len.nmPerInch),
        )
        ..structureOrigin = StructureOrigin(
          structureBodyId: const Uuid('sb-1'),
          outletId: const Uuid('outlet-1'),
          fieldLabel: 'GR-TV-1',
          rackLabel: '1A-A03',
          terminationField: TerminationType.keystone,
        );
  doc.links[home.id] = home;

  final jumper = link(
    'lnk-2',
    'W002',
    const PortEndpoint(switchPort),
    const PortEndpoint(panelPort2),
  );
  doc.links[jumper.id] = jumper;

  final undetermined = link(
    'lnk-3',
    'W099',
    const PortEndpoint(switchPort),
    const PortEndpoint(Uuid('port-ghost')),
  );
  doc.links[undetermined.id] = undetermined;

  return doc;
}

void main() {
  group('zero rows is a state this tab is CORRECT in (CR-105, AC-035)', () {
    testWidgets('the column headers render before any data exists', (
      tester,
    ) async {
      await _pump(tester, _emptyDoc());
      // The header row is what makes an empty schedule readable rather
      // than blank, and it is §3.2's own column list — not a set this
      // widget chose.
      for (final column in kPullSheetColumns) {
        expect(
          find.text(column.header),
          findsOneWidget,
          reason: '${column.header} is one of §3.2s ten columns',
        );
      }
    });

    testWidgets('the copy blames the DOCUMENT, never the user', (
      tester,
    ) async {
      await _pump(tester, _emptyDoc());
      expect(find.text(kNoCablesHeadline), findsOneWidget);

      final joined = _textsUnder(
        tester,
        find.byType(ScheduleScreen),
      ).join(' ').toLowerCase();
      // docs/09 M1: "an empty Schedule tab that explains it is coming is
      // a lie", and the deleted predecessor's own two strings.
      for (final lie in [
        'you have not wired',
        'coming soon',
        'no connections yet',
        'create links in the',
      ]) {
        expect(joined, isNot(contains(lie)), reason: '"$lie" is not true');
      }
    });

    testWidgets('the row count and the footage are the ones core computes, '
        'and the footage is a MEASURED zero', (tester) async {
      final doc = _emptyDoc();
      await _pump(tester, doc);
      final view = scheduleViewOf(doc, preset: SchedulePreset.pullSheet);
      expect(view.rowCount, 0);
      expect(view.footage.value, Len.zero);
      expect(find.text('0 rows'), findsOneWidget);
      expect(
        find.text('Total 0 ft'),
        findsOneWidget,
        reason:
            'nobody was asked, so this really is zero — the em dash is '
            'for a rollup that had contributors and learned nothing '
            'from them (totals.dart rule 1)',
      );
    });
  });

  group('it renders the derivation and does not recompute it', () {
    testWidgets('every visible cell of the one shown row matches '
        'ScheduleEntry.cell for the same column', (tester) async {
      final doc = _populatedDoc();
      await _pump(tester, doc);
      final view = scheduleViewOf(doc, preset: SchedulePreset.pullSheet);
      final entry = view.rows.firstWhere((r) => r.designator == 'W015');
      final texts = _textsUnder(tester, find.byType(ScheduleScreen));
      for (final column in view.columns) {
        if (column.id == ScheduleColumnId.signOff) continue;
        final expected = entry.cell(
          column.id,
          units: doc.settings.displayUnits,
        );
        expect(
          texts,
          contains(expected),
          reason:
              'the ${column.header} cell must be the string core computed, '
              'not one this widget assembled',
        );
      }
    });

    testWidgets('BOTH LABELS are on the row, on both presets (CR-044, '
        'AC-047)', (tester) async {
      final doc = _populatedDoc();
      await _pump(tester, doc);
      expect(find.text('GR-TV-1'), findsOneWidget);
      expect(find.text('1A-A03'), findsOneWidget);

      await tester.tap(find.textContaining('TERMINATION SCHEDULE'));
      await tester.pumpAndSettle();
      expect(find.text('GR-TV-1'), findsOneWidget);
      expect(find.text('1A-A03'), findsOneWidget);
    });

    testWidgets('switching preset switches the column table and the '
        'default sort with it', (tester) async {
      await _pump(tester, _populatedDoc());
      expect(find.text('FROM — ROOM / OUTLET'), findsOneWidget);
      expect(find.text('FAR PORT'), findsNothing);

      await tester.tap(find.textContaining('TERMINATION SCHEDULE'));
      await tester.pumpAndSettle();

      expect(find.text('FAR PORT'), findsOneWidget);
      expect(find.text('FROM — ROOM / OUTLET'), findsNothing);
      // §3.6 gives each preset its own default sort; carrying the Pull
      // Sheet's room order across would silently answer a different
      // question on a sheet you terminate a panel from.
      expect(
        find.text(scheduleSortLabel(ScheduleSort.rackThenPanelThenPort)),
        findsWidgets,
      );
    });
  });

  group('nothing hidden is silent', () {
    testWidgets('the jumper excluded by default is COUNTED on screen', (
      tester,
    ) async {
      await _pump(tester, _populatedDoc());
      expect(find.text('1 jumpers hidden'), findsOneWidget);
      expect(
        find.textContaining('(1 hidden)'),
        findsOneWidget,
        reason:
            'AC-026 hides jumpers by default; the toggle has to say how '
            'many, or the default exclusion is a silent one',
      );
      expect(find.text('W002'), findsNothing);
    });

    testWidgets('the toggle brings it back', (tester) async {
      await _pump(tester, _populatedDoc());
      await tester.tap(find.textContaining('Show jumpers and power cords'));
      await tester.pumpAndSettle();
      expect(find.text('W002'), findsOneWidget);
      expect(find.text('1 jumpers hidden'), findsNothing);
    });

    testWidgets('an UNDETERMINED class gets its own band and its own '
        'count — it is neither hidden nor promoted (G4)', (tester) async {
      await _pump(tester, _populatedDoc());
      expect(find.text('1 class not determined'), findsOneWidget);
      expect(
        find.textContaining(kUndeterminedClassGroupTitle),
        findsWidgets,
        reason:
            'defaulting it to fieldCable asserts a pull nobody '
            'established; defaulting it to jumper hides a real one',
      );
      expect(
        find.text('W099'),
        findsOneWidget,
        reason: 'and the cable itself is still on the sheet',
      );
    });

    testWidgets('a room band states its own footage subtotal and how many '
        'lengths it could not see', (tester) async {
      final doc = _populatedDoc();
      await _pump(tester, doc);
      // W015 is 78 ft; it is the only row in the Great Room band.
      expect(find.textContaining('Great Room — 1 runs'), findsOneWidget);
      expect(find.textContaining('78 ft'), findsWidgets);
    });

    testWidgets('a drop with NO room is on the screen too, under a band '
        'that names the absence (M3-B/3)', (tester) async {
      // `pull_sheet_unassigned_room_test.dart` pins this in the
      // derivation; this is the same claim one layer up, because the
      // screen flattens bands and rows itself and could drop a band the
      // view produced. G1 and G4: the run may not vanish from the
      // deliverable and may not be filed under an invented room.
      //
      // Newly ORDINARY rather than exotic: from M3-B/1, deleting a
      // location clears this field on every drop in it (DR-021 §11.20.2).
      final doc = _populatedDoc();
      doc.links[const Uuid('lnk-roomless')] = Link(
        id: const Uuid('lnk-roomless'),
        designator: 'W404',
        media: const MediaTypeId('media.cat6a_futp'),
        order: const FracIndex('z0'),
        meta: _meta(),
        conductors: [
          const Conductor(
            from: PlaceEndpoint(description: 'somewhere in the attic'),
            to: OpenEndpoint('coiled'),
          ),
        ],
      );

      await _pump(tester, doc);

      expect(find.text('W404'), findsOneWidget);
      expect(find.textContaining(kUngroupedTitle), findsOneWidget);
    });
  });
}
