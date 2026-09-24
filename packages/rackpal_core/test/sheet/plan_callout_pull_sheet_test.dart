// The Plan view's fourth clause, at the join it names (`#943`): "`T1.01`
// places a callout for every pinned drop, each printing the designator its
// Pull Sheet row prints."
//
// DR-150 §11.149.3 settled what that means: the callout prints the pinned
// CARRIER's own designator, because a pinned outlet has several Pull Sheet
// rows and a cable designator is not a function of a pin, and that
// designator "appears on every Pull Sheet row for that drop". The first half
// was tested (`plan_sheet_test.dart`, "each carrier prints its OWN
// designator"). The second half, the join a person reconciling the plan
// against the sheet actually walks, was argued and never run.
//
// So the drops come from a real CSV import, the way a rough-in arrives, and
// the assertion is the same string on both sides: whatever the callout
// prints, every Pull Sheet row for that outlet's drops must show it.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 9, 24);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _plan = Uuid('0190e3c1-1111-7000-8000-000000000001');

/// A project with a Structure body, the plan, and the rough-in [csv]
/// imported through the real planner.
RackDocument _imported(String csv) {
  final doc = RackDocument(
    id: const Uuid('doc-callout-join'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  final bodyId = (AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _when,
    actor: 'test',
  )..apply(doc)).bodyId;
  doc.underlays[_plan] = PlanUnderlay(
    id: _plan,
    name: 'Level 1',
    imageMember: 'underlays/$_plan.png',
    format: PlanImageFormat.png,
    pixelWidth: 4000,
    pixelHeight: 3000,
    contentHash: 'sha256:level-1',
    order: const FracIndex('a0'),
    meta: _meta(),
  );

  final table = switch (readCsv(csv)) {
    CsvReadOk(:final table) => table,
    CsvReadRefused(:final message) => fail('refused: $message'),
  };
  final plan = planCsvImport(
    doc: doc,
    rows: resolveCsvRows(
      table: table,
      mapping: CsvMapping.guess(
        table: table,
        detection: detectCsvShape(table, doc.registries),
        registries: doc.registries,
      ),
      registries: doc.registries,
      settings: doc.settings,
    ),
  );
  final built = buildCsvImport(
    doc: doc,
    plan: plan,
    now: _when,
    actor: 'test',
    structureBodyId: bodyId,
  );
  final ready = switch (built) {
    CsvImportReady() => built,
    CsvImportRefused(:final reason) => fail('refused: $reason'),
  };
  for (final c in ready.commands) {
    c.apply(doc);
  }
  return doc;
}

void _pinEveryOutlet(RackDocument doc) {
  var x = 100;
  for (final outlet in doc.outlets.values) {
    SetPlanPinCommand(
      carrier: PinCarrier.outlet,
      entityId: outlet.id,
      pin: PlanPin(underlayId: _plan, at: PxPt(x, 200)),
    ).apply(doc);
    x += 300;
  }
}

void main() {
  const roughIn =
      'Room,Outlet,Cable Type,Qty\n'
      'Living Room,WP-1,Cat6,2\n'
      'Living Room,WP-1,RG6,1\n'
      'Attic,AP-1,Cat6,1\n'
      'Office,WP-2,Cat6,2\n';

  test(
    'every pinned outlet has Pull Sheet rows, so the join is not vacuous',
    () {
      final doc = _imported(roughIn);
      _pinEveryOutlet(doc);

      final pinned = planPinsFor(doc, _plan).map((p) => p.entityId).toSet();
      expect(pinned, hasLength(3), reason: 'WP-1, AP-1 and WP-2');

      final rows = scheduleViewOf(doc, preset: SchedulePreset.pullSheet).rows;
      for (final outletId in pinned) {
        final drops = rows.where(
          (r) => doc.links[r.linkId]?.structureOrigin?.outletId == outletId,
        );
        expect(drops, isNotEmpty, reason: 'outlet $outletId has drops');
      }
    },
  );

  test("each Pull Sheet row for a pinned drop prints its callout's "
      'designator, spelled the same', () {
    final doc = _imported(roughIn);
    _pinEveryOutlet(doc);

    final labels = planPinLabelsFor(doc, planPinsFor(doc, _plan));
    final rows = scheduleViewOf(doc, preset: SchedulePreset.pullSheet).rows;

    var checked = 0;
    for (final row in rows) {
      final outletId = doc.links[row.linkId]?.structureOrigin?.outletId;
      if (outletId == null) continue;
      final callout = labels[outletId];
      expect(
        callout,
        isNotNull,
        reason: 'every drop here is on a pinned plate',
      );
      expect(
        row.cell(ScheduleColumnId.fromRoomOutlet, units: UnitSystem.imperial),
        contains(callout),
        reason:
            'a person holding T1.01 finds "$callout" on the plan and must find '
            'the same string on this row of the Pull Sheet',
      );
      checked++;
    }
    expect(checked, 6, reason: 'all six drops of the rough-in were walked');
  });
}
