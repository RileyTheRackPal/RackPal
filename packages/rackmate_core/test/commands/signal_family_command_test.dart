// DR-025 §11.24.5, board #587 — the RETROACTIVE half. A run created
// without `@signal=` can gain a family afterwards, which is what makes
// docs/07 §4.1's second clause reachable: "the DRC validates
// RETROACTIVELY when a `Service` later assigns a real family."
//
// §11.24.6 IS WHAT THIS COMMAND EXISTS FOR. The family is stored TWICE,
// on the `Service` and on its `Net`, and only the first is consumed
// today. So a build that wrote one and not the other would pass every
// rendering test in the suite. Both halves are asserted here, and the
// UNDO of both is asserted separately, because a revert that puts one
// back re-encodes consistently and is invisible to a byte comparison.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 8, 13);
const _hdbaset = SignalFamilyId('video.hdbaset');
const _avoip = SignalFamilyId('video.avoip');

({RackDocument doc, Uuid linkId}) _projectWithADrop() {
  final doc = RackDocument(
    id: const Uuid('doc-fam'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  )..registries = buildSeedRegistries();
  AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'test',
  ).apply(doc);
  AddLocationCommand(
    name: 'Living Room',
    code: 'LR',
    order: nextLocationOrder(doc),
    now: _now,
    actor: 'test',
  ).apply(doc);
  final parsed = parseDropLine('Living Room: 1x Cat6') as DropLineParsed;
  final plan =
      planDropLine(doc: doc, line: parsed, now: _now, actor: 'test')
          as DropLinePlanReady;
  for (final c in plan.commands) {
    c.apply(doc);
  }
  return (doc: doc, linkId: doc.links.keys.single);
}

SetSignalFamilyCommand _set(
  RackDocument doc,
  Uuid linkId,
  SignalFamilyId family,
) {
  final built = buildSetSignalFamily(
    doc: doc,
    linkId: linkId,
    family: family,
    now: _now,
    actor: 'test',
  );
  expect(built, isA<SetSignalFamilyReady>(), reason: '$built');
  return (built as SetSignalFamilyReady).command;
}

({SignalFamilyId service, SignalFamilyId net}) _both(
  RackDocument doc,
  Uuid linkId,
) {
  final service = doc.links[linkId]!.services.single;
  return (
    service: service.signalFamily,
    net: doc.nets[service.netId]!.signalFamily,
  );
}

void main() {
  group('a family can be set after the run exists', () {
    test('it starts undetermined, which is the encouraged state', () {
      final p = _projectWithADrop();
      final before = _both(p.doc, p.linkId);
      expect(before.service, kUndeterminedFamily);
      expect(before.net, kUndeterminedFamily);
    });

    test('setting it writes BOTH the Service and the Net', () {
      final p = _projectWithADrop();
      _set(p.doc, p.linkId, _hdbaset).apply(p.doc);
      final after = _both(p.doc, p.linkId);
      expect(after.service, _hdbaset);
      expect(
        after.net,
        _hdbaset,
        reason:
            '§11.24.6: nothing reads the Net today, so only a case '
            'that names it can see a half-write',
      );
    });

    test('undo puts BOTH back', () {
      // THE HALF-RESTORE IS THE FAILURE THIS CASE EXISTS FOR. Reverting
      // the Service alone leaves a file that re-encodes perfectly well
      // and says two different things about one run.
      final p = _projectWithADrop();
      final cmd = _set(p.doc, p.linkId, _avoip)..apply(p.doc);
      expect(_both(p.doc, p.linkId).service, _avoip);
      cmd.revert(p.doc);
      final after = _both(p.doc, p.linkId);
      expect(after.service, kUndeterminedFamily);
      expect(after.net, kUndeterminedFamily);
    });

    test('undo restores the meta stamp, not just the value', () {
      // CR-117: the 1000-sequence fuzz asserts apply-then-revert is
      // byte-identical, so a revert that moved `updatedAt` and left the
      // value right would fail it. Pinned here too, so a failure names
      // the cause rather than arriving as one line in a thousand.
      final p = _projectWithADrop();
      final meta = p.doc.links[p.linkId]!.meta;
      final at = meta.updatedAt;
      final by = meta.updatedBy;
      final rev = meta.localRevision;

      final cmd = _set(p.doc, p.linkId, _hdbaset)..apply(p.doc);
      expect(meta.localRevision, isNot(rev), reason: 'apply must move it');
      cmd.revert(p.doc);

      expect(meta.updatedAt, at);
      expect(meta.updatedBy, by);
      expect(meta.localRevision, rev);
    });

    test('re-applying after undo is idempotent, which is redo', () {
      final p = _projectWithADrop();
      _set(p.doc, p.linkId, _hdbaset)
        ..apply(p.doc)
        ..revert(p.doc)
        ..apply(p.doc);
      expect(_both(p.doc, p.linkId).service, _hdbaset);
      expect(_both(p.doc, p.linkId).net, _hdbaset);
    });
  });

  group('it refuses rather than inventing', () {
    test('a family that is not in the catalog is refused', () {
      // §11.24.3, and the asymmetry with media is deliberate: media types
      // are user-extensible in v1 and families are catalog-updated.
      final p = _projectWithADrop();
      final built = buildSetSignalFamily(
        doc: p.doc,
        linkId: p.linkId,
        family: const SignalFamilyId('video.invented'),
        now: _now,
        actor: 'test',
      );
      expect(built, isA<SetSignalFamilyRefused>());
      expect((built as SetSignalFamilyRefused).reason, contains('invented'));
    });

    test('a refusal changes NOTHING, including the registry', () {
      final p = _projectWithADrop();
      buildSetSignalFamily(
        doc: p.doc,
        linkId: p.linkId,
        family: const SignalFamilyId('video.invented'),
        now: _now,
        actor: 'test',
      );
      expect(_both(p.doc, p.linkId).service, kUndeterminedFamily);
      expect(
        p.doc.registries.signalFamilies.containsKey(
          const SignalFamilyId('video.invented'),
        ),
        isFalse,
      );
    });

    test('a link that is not in the project is refused', () {
      final p = _projectWithADrop();
      final built = buildSetSignalFamily(
        doc: p.doc,
        linkId: const Uuid('nope'),
        family: _hdbaset,
        now: _now,
        actor: 'test',
      );
      expect(built, isA<SetSignalFamilyRefused>());
    });
  });

  group('the undo label is its own, not a field edit', () {
    test('it reports setSignalFamily', () {
      final p = _projectWithADrop();
      expect(_set(p.doc, p.linkId, _hdbaset).label, LabelKey.setSignalFamily);
      expect(
        LabelKey.setSignalFamily,
        isNot(LabelKey.setEntityProperty),
        reason:
            'it writes two entities per service, so "Undo edit" would '
            'name a fraction of what it takes back',
      );
    });
  });
}
