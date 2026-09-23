// Where a finding can be fixed (DR-193 §11.192.1, board #928).
//
// `F8` switches views on this answer, so every row of the ruling's table
// is a case here, plus the two that a table cannot show: a shelf is in the
// rack its host is in, and an id the document no longer holds is nowhere.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../derived/fixtures/plan_doc.dart';

Finding _at(Uuid? id) => Finding(
  ruleId: 'TST-001',
  severity: Severity.warning,
  message: 'test',
  targets: [?id],
  primaryEntityId: id,
);

void main() {
  test('a device on the rails is fixed on the Rack view, in its rack', () {
    final d = PlanDoc();
    final rack = d.rack('RK-2');
    final dev = d.rackDevice('AMP-1', rack);

    final locus = findingLocusOf(d.doc, _at(dev));

    expect(locus.kind, FindingLocusKind.rackDevice);
    expect(locus.subject, dev);
    expect(locus.rackId, rack);
  });

  test('a device on a SHELF is in the rack the shelf is in', () {
    final d = PlanDoc();
    final rack = d.rack('RK-1');
    final shelf = d.rackDevice('SH-1', rack);
    const source = Uuid('dev-on-shelf');
    d.doc.devices[source] = DeviceInstance(
      id: source,
      kind: DeviceKind.rackDevice,
      templateRef: kPlanTemplateRef,
      designator: 'BR-1',
      name: 'BR-1',
      placement: const ShelfPlacement(
        hostDeviceId: Uuid('dev-1'),
        order: FracIndex('a0'),
      ),
      meta: planMeta(),
    );
    // The fixture mints `dev-1` for the shelf; assert it rather than trust
    // it, or the case passes on a shelf that points at nothing.
    expect(shelf, const Uuid('dev-1'));

    expect(findingLocusOf(d.doc, _at(source)).rackId, rack);
  });

  test('a device in no rack is fixed on the Schematic', () {
    final d = PlanDoc();
    final tv = d.offRackDevice('TV-1');

    expect(findingLocusOf(d.doc, _at(tv)).kind, FindingLocusKind.fieldDevice);
  });

  test('a rack, a cable and a floorplan each name their own view', () {
    final d = PlanDoc()..underlay();
    final rack = d.rack('RK-1');
    final dev = d.rackDevice('PP-1', rack);
    final link = d.link(
      from: PortEndpoint(d.port(dev, 'J01')),
      to: const PlaceEndpoint(description: 'TV wall'),
    );

    final atRack = findingLocusOf(d.doc, _at(rack));
    expect(atRack.kind, FindingLocusKind.rack);
    expect(atRack.rackId, rack);
    expect(
      findingLocusOf(d.doc, _at(link.id)).kind,
      FindingLocusKind.cable,
    );
    expect(findingLocusOf(d.doc, _at(kPlanUl)).kind, FindingLocusKind.plan);
  });

  test('no locus, or one the document no longer holds, is nowhere', () {
    final d = PlanDoc();

    expect(findingLocusOf(d.doc, _at(null)).kind, FindingLocusKind.none);
    expect(
      findingLocusOf(d.doc, _at(const Uuid('gone'))).kind,
      FindingLocusKind.none,
    );
  });
}
