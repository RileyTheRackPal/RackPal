// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take;
// collapsing the pair into a cascade would delete the intermediate
// assertion.
//
// `#721`, DR-074 §11.73.2 — the write path that says A PERSON named the
// hole.
//
// =====================================================================
// THE PROPERTY THIS FILE IS FOR
// =====================================================================
// A rack label has two authors and one field. The allocator writes one
// when a run lands, because the label is derived from the position
// (DR-040 §11.39.3); a person writes one in the `RACK LBL` column. A MOVE
// re-derives the first and must keep the second, so something has to
// record which is which, and `rackLabelLocked` is it.
//
// The load-bearing group is `clearing the cell`. A locked null would say
// "nobody may ever name this", which no surface can undo — the one-way
// door `ClearLinkClassOverrideCommand` exists to refuse — and it is
// reachable by the ordinary act of emptying a box.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 18);
final _later = DateTime.utc(2026, 8, 19);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

/// One Structure body, one Outlet, and TWO home runs, because CR-113 needs
/// a second drop to collide with.
({RackDocument doc, Uuid linkA, Uuid linkB}) _project() {
  final doc = RackDocument(
    id: const Uuid('doc-rack-label'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'seed',
  )..apply(doc);
  final outlet = AddOutletCommand(
    structureBodyId: structure.bodyId,
    designation: 'GR-TV-1',
    order: nextOutletOrder(doc),
    now: _now,
    actor: 'seed',
  )..apply(doc);

  AddHomeRunCommand drop(String label, String designator, String? rackLabel) =>
      (buildAddHomeRunCommand(
                doc: doc,
                outletId: outlet.id,
                fieldLabel: label,
                designator: designator,
                netName: designator,
                media: const MediaTypeId('media.cat6_utp'),
                fieldEnd: const PlaceEndpoint(description: 'Great Room'),
                terminationField: TerminationType.keystone,
                rackLabel: rackLabel,
                now: _now,
                actor: 'seed',
              )
              as AddHomeRunReady)
          .command
        ..apply(doc);

  final a = drop('GR-DATA-1', 'W001', 'PP1-01');
  final b = drop('GR-DATA-2', 'W002', 'PP1-02');
  return (doc: doc, linkA: a.id, linkB: b.id);
}

SetRackLabelResult _set(
  RackDocument doc,
  Uuid linkId,
  String? to, {
  Set<String> alsoUsedRackLabels = const {},
}) => buildSetRackLabel(
  doc: doc,
  linkId: linkId,
  to: to,
  now: _later,
  actor: 'tester',
  alsoUsedRackLabels: alsoUsedRackLabels,
);

SetRackLabelCommand _ready(SetRackLabelResult r) =>
    (r as SetRackLabelReady).command;

StructureOrigin _origin(RackDocument doc, Uuid linkId) =>
    doc.links[linkId]!.structureOrigin!;

void main() {
  group('the allocator has not spoken for it', () {
    test('a created drop carries its label UNLOCKED', () {
      final p = _project();
      final origin = _origin(p.doc, p.linkA);
      expect(origin.rackLabel, 'PP1-01');
      expect(
        origin.rackLabelLocked,
        isFalse,
        reason:
            'the drop line allocated that label; locking it would freeze a '
            'derived name onto a cable that is free to move',
      );
    });
  });

  group('typing a label', () {
    test('writes the label AND the lock, and reverts both', () {
      final p = _project();
      final command = _ready(_set(p.doc, p.linkA, 'BY-HAND-7'));

      command.apply(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabel, 'BY-HAND-7');
      expect(_origin(p.doc, p.linkA).rackLabelLocked, isTrue);

      command.revert(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabel, 'PP1-01');
      expect(
        _origin(p.doc, p.linkA).rackLabelLocked,
        isFalse,
        reason:
            'restoring the label alone would leave a re-derivable name '
            'pinned by an assertion the user has just undone',
      );
    });

    test('trims, so a stray space cannot make a second identifier', () {
      final p = _project();
      final command = _ready(_set(p.doc, p.linkA, '  BY-HAND-7 '));
      command.apply(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabel, 'BY-HAND-7');
    });

    test('touches the LINK, because that is what carries the origin', () {
      final p = _project();
      final before = p.doc.links[p.linkA]!.meta.updatedAt;
      _ready(_set(p.doc, p.linkA, 'BY-HAND-7')).apply(p.doc);
      expect(p.doc.links[p.linkA]!.meta.updatedAt, isNot(before));
      expect(p.doc.links[p.linkA]!.meta.updatedBy, 'tester');
    });

    test('the label a link ALREADY holds is still an assertion', () {
      // Adopting the allocator's answer is a decision, and reporting
      // "nothing to do" would silently decline to record it — the call
      // `SetLinkClassCommand` makes one field up for the same reason.
      final p = _project();
      final result = _set(p.doc, p.linkA, 'PP1-01');
      expect(result, isA<SetRackLabelReady>());
      _ready(result).apply(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabel, 'PP1-01');
      expect(_origin(p.doc, p.linkA).rackLabelLocked, isTrue);
    });

    test('re-typing an ALREADY LOCKED label is nothing to do', () {
      final p = _project();
      _ready(_set(p.doc, p.linkA, 'BY-HAND-7')).apply(p.doc);
      expect(
        _set(p.doc, p.linkA, 'BY-HAND-7'),
        isA<SetRackLabelUnchanged>(),
        reason:
            'a fill-down over a column that already says this must not '
            'cost an undo step that changes nothing',
      );
    });
  });

  group('clearing the cell', () {
    test('clears the label AND the lock — no one-way door', () {
      final p = _project();
      _ready(_set(p.doc, p.linkA, 'BY-HAND-7')).apply(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabelLocked, isTrue);

      _ready(_set(p.doc, p.linkA, '')).apply(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabel, isNull);
      expect(
        _origin(p.doc, p.linkA).rackLabelLocked,
        isFalse,
        reason:
            'a locked null says "nobody may ever name this", which no '
            'surface can undo and no person asked for',
      );
    });

    test('whitespace is a blank, not a label', () {
      final p = _project();
      _ready(_set(p.doc, p.linkA, '   ')).apply(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabel, isNull);
      expect(_origin(p.doc, p.linkA).rackLabelLocked, isFalse);
    });

    test('reverting a clear puts the lock back the way it was', () {
      final p = _project();
      _ready(_set(p.doc, p.linkA, 'BY-HAND-7')).apply(p.doc);
      final clear = _ready(_set(p.doc, p.linkA, null));
      clear.apply(p.doc);
      clear.revert(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabel, 'BY-HAND-7');
      expect(_origin(p.doc, p.linkA).rackLabelLocked, isTrue);
    });

    test('clearing an already-blank unlocked label is nothing to do', () {
      final p = _project();
      _ready(_set(p.doc, p.linkA, null)).apply(p.doc);
      expect(_set(p.doc, p.linkA, null), isA<SetRackLabelUnchanged>());
    });
  });

  group('it refuses', () {
    test('a label another drop already holds (CR-113)', () {
      final p = _project();
      final result = _set(p.doc, p.linkA, 'PP1-02');
      expect(result, isA<SetRackLabelRefused>());
      expect(
        (result as SetRackLabelRefused).reason,
        contains('already used at the panel'),
      );
    });

    test('a label a SIBLING EDIT in the same batch has spent', () {
      // The reservation `buildSetStructureOriginProperty` takes for the
      // same reason: a batch planned against one unmutated document would
      // otherwise let two rows agree on a label and never notice.
      final p = _project();
      expect(
        _set(p.doc, p.linkA, 'SHARED-1', alsoUsedRackLabels: {'SHARED-1'}),
        isA<SetRackLabelRefused>(),
      );
    });

    test('a link that is not a home run', () {
      final p = _project();
      p.doc.links[const Uuid('patch-1')] = Link(
        id: const Uuid('patch-1'),
        designator: 'W900',
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a5'),
        meta: _meta(),
      );
      final result = _set(p.doc, const Uuid('patch-1'), 'PP1-09');
      expect(result, isA<SetRackLabelRefused>());
      expect(
        (result as SetRackLabelRefused).reason,
        contains('is not a home run'),
      );
    });

    test('a link that is not in the document', () {
      final p = _project();
      expect(
        _set(p.doc, const Uuid('nope'), 'PP1-09'),
        isA<SetRackLabelRefused>(),
      );
    });

    test('but NOT the drop renaming onto its OWN label', () {
      // The exclusion that makes the feature usable in the other
      // direction: without `exceptLinkId` every rename refuses itself.
      final p = _project();
      expect(_set(p.doc, p.linkA, 'PP1-01'), isA<SetRackLabelReady>());
    });
  });

  group('coalescing', () {
    test('two edits on one cell merge into ONE undo entry', () {
      final p = _project();
      final first = _ready(_set(p.doc, p.linkA, 'BY-HAND-7'));
      first.apply(p.doc);
      final second = _ready(_set(p.doc, p.linkA, 'BY-HAND-8'));

      final merged = first.mergeWith(second);
      expect(merged, isNotNull);
      expect(merged!.mergeKey, first.mergeKey);

      // The merged command carries the FIRST command's captured before,
      // so reverting it lands on the label the person started from rather
      // than on the intermediate one they typed through.
      second.apply(p.doc);
      merged.revert(p.doc);
      expect(_origin(p.doc, p.linkA).rackLabel, 'PP1-01');
      expect(_origin(p.doc, p.linkA).rackLabelLocked, isFalse);
    });

    test('edits on two different drops do NOT merge', () {
      final p = _project();
      final a = _ready(_set(p.doc, p.linkA, 'BY-HAND-7'))..apply(p.doc);
      final b = _ready(_set(p.doc, p.linkB, 'BY-HAND-8'));
      expect(a.mergeWith(b), isNull);
      expect(a.mergeKey, isNot(b.mergeKey));
    });
  });

  test('revert before apply names itself', () {
    final p = _project();
    expect(
      () => _ready(_set(p.doc, p.linkA, 'BY-HAND-7')).revert(p.doc),
      throwsA(isA<StateError>()),
    );
  });
}
