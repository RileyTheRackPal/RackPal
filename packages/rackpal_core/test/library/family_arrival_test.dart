// SFE-C6 (DR-245 §11.244.3): placing a library device brings the families
// its ports name, and changes nothing already drawn.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 10, 8);

RackDocument _doc(String id) => RackDocument(
  id: Uuid(id),
  appVersion: 'test',
  createdAt: _now,
  modifiedAt: _now,
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
)..registries = buildSeedRegistries();

/// A clone of Cresnet named [name] at the [nth] free control line, made
/// by the real builder in a document of its own.
SignalFamilyDef _vantage({String name = 'Vantage', int nth = 0}) {
  final author = _doc('doc-author');
  final option = cloneHeadroom(
    author,
    const SignalDomainId('ctl'),
  )!.free.elementAt(nth);
  final built = buildCloneSignalFamily(
    author,
    parent: const SignalFamilyId('ctl.cresnet'),
    displayName: name,
    shortTag: 'VNT',
    dashPermille: option.dashPermille,
    weightPermille: option.weightPermille,
  );
  return (built as CloneSignalFamilyReady).command.family;
}

/// A library row for a keypad whose first port carries [family].
PlaceableTemplate _row(SignalFamilyDef family) {
  final body = buildSeedCatalog().values.firstWhere(
    (b) => b.ports.isNotEmpty,
  );
  body.ports.first.signalFamily = family.id;
  return PlaceableTemplate(
    templateId: const TemplateId('tpl.keypad'),
    version: 1,
    contentHash: templateContentHash(body),
    body: body,
    provenance: const LibraryProvenance(
      libraryId: 'acme',
      libraryName: 'Acme AV pack',
    ),
    carriedFamilies: [family],
  );
}

/// Plans placing [row] into [doc] and runs everything before the add.
LibraryPlacement _place(RackDocument doc, PlaceableTemplate row) {
  final plan = planLibraryPlacement(doc, row, capturedAt: _now);
  for (final c in plan.prelude) {
    c.apply(doc);
  }
  return plan;
}

SignalFamilyId _portFamily(LibraryPlacement plan) =>
    plan.snapshot.body.ports.first.signalFamily;

void main() {
  test('a family the project lacks arrives as it is, and the device names '
      'it', () {
    final vantage = _vantage();
    final doc = _doc('doc-a');
    final plan = _place(doc, _row(vantage));
    expect(doc.registries.signalFamilies[vantage.id], same(vantage));
    expect(_portFamily(plan), vantage.id);
    expect(plan.familyNotice, isNull);
  });

  test('a family the project already holds identically arrives as nothing', () {
    final vantage = _vantage();
    final doc = _doc('doc-b');
    doc.registries.signalFamilies[vantage.id] = vantage;
    final plan = _place(doc, _row(vantage));
    expect(plan.families, isNull);
    expect(_portFamily(plan), vantage.id);
  });

  test('a DIFFERENT family under the same id is left alone; the newcomer '
      'takes a fresh id and name, and the device follows it', () {
    final mine = _vantage();
    final theirs = _vantage(nth: 1);
    expect(mine.id, theirs.id, reason: 'two people, one spelling');
    final doc = _doc('doc-c');
    doc.registries.signalFamilies[mine.id] = mine;

    final plan = _place(doc, _row(theirs));
    final arrivedId = _portFamily(plan);
    expect(arrivedId, isNot(mine.id));
    expect(doc.registries.signalFamilies[mine.id], same(mine));
    final arrived = doc.registries.signalFamilies[arrivedId]!;
    expect(arrived.displayName, 'Vantage 2');
    expect(arrived.dashOverride, theirs.dashOverride);
    expect(arrived.clonedFrom, theirs.clonedFrom);
    // A re-pointed body is not what the file claimed, so its hash is the
    // body's own rather than the file's.
    expect(plan.snapshot.contentHash, templateContentHash(plan.snapshot.body));
  });

  test('placing the same device again mints nothing: no third family and no '
      'second template', () {
    final mine = _vantage();
    final theirs = _vantage(nth: 1);
    final doc = _doc('doc-d');
    doc.registries.signalFamilies[mine.id] = mine;
    final row = _row(theirs);

    final first = _place(doc, row);
    final families = doc.registries.signalFamilies.length;
    final templates = doc.templates.length;
    final second = _place(doc, row);

    expect(second.families, isNull);
    expect(second.copy, isNull, reason: 'case two: the template is held');
    expect(_portFamily(second), _portFamily(first));
    expect(doc.registries.signalFamilies, hasLength(families));
    expect(doc.templates, hasLength(templates));
  });

  test('a family that prints like one already here is placed, and said by '
      'name', () {
    // An arriving family drawn on Lutron QS's own line, which no clone
    // dialog would allow but a hand-made library can carry.
    final lutron =
        _doc('x').registries.signalFamilies[const SignalFamilyId(
          'ctl.lutron_qs',
        )]!;
    final clash = SignalFamilyDef(
      id: const SignalFamilyId('ctl.clasher'),
      displayName: 'Clasher',
      domain: lutron.domain,
      defaultConnector: lutron.defaultConnector,
      defaultDirection: lutron.defaultDirection,
      defaultTopology: lutron.defaultTopology,
      dashOverride: lutron.effectiveDashPattern(
        _doc('y').registries.signalDomains[lutron.domain]!,
      ),
      lineWeightPermilleOverride: 1000,
      clonedFrom: const SignalFamilyId('ctl.cresnet'),
    );
    final doc = _doc('doc-e');
    final plan = _place(doc, _row(clash));
    expect(plan.copy, isNotNull, reason: 'placed, not refused');
    expect(doc.registries.signalFamilies.containsKey(clash.id), isTrue);
    expect(plan.familyNotice, contains('Clasher (from Acme AV pack)'));
    expect(plan.familyNotice, contains('ctl.lutron_qs'));
  });

  test('undoing the placement takes the arrived family back out', () {
    final vantage = _vantage();
    final doc = _doc('doc-f');
    final plan = _place(doc, _row(vantage));
    for (final c in plan.prelude.reversed) {
      c.revert(doc);
    }
    expect(doc.registries.signalFamilies.containsKey(vantage.id), isFalse);
  });
}
