// `buildSetPathwayDesignator` (M3-E/2, #157), the guard DR-026 §11.25.1's
// "unique where set, project-wide" needs in order to be a rule rather than
// a comment.
//
// EVERY TEST HERE ASSERTS THE OUTCOME A CALLER SEES, not the shape of the
// scan behind it. A test that pinned `usedPathwayDesignators`' contents
// would survive the day somebody drove the field through
// `buildSetEntityProperty` instead, which is the exact failure the guard
// exists to prevent.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 8, 10, 9),
  updatedAt: DateTime.utc(2026, 8, 10, 9),
  updatedBy: 'rriley',
);

final _now = DateTime.utc(2026, 8, 10, 10);
const _actor = 'rriley';

const _idA = Uuid('0190e3c1-0000-7000-8000-0000000000a1');
const _idB = Uuid('0190e3c1-0000-7000-8000-0000000000b2');
const _absent = Uuid('0190e3c1-0000-7000-8000-0000000000ff');

RackDocument _doc({String? aDesignator, String? bDesignator}) {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-00000000dead'),
    appVersion: '0.1.0+build.1',
    createdAt: DateTime.utc(2026, 8, 10, 9),
    modifiedAt: DateTime.utc(2026, 8, 10, 9),
    meta: _meta(),
    info: ProjectInfo(projectName: 'Designator guard'),
  );
  doc.pathways[_idA] = Pathway(
    id: _idA,
    name: 'attic run to the garage',
    order: const FracIndex('a0'),
    meta: _meta(),
    designator: aDesignator,
  );
  doc.pathways[_idB] = Pathway(
    id: _idB,
    name: 'riser to level 2',
    order: const FracIndex('a1'),
    meta: _meta(),
    designator: bDesignator,
  );
  return doc;
}

SetPathwayDesignatorResult _set(
  RackDocument doc,
  Uuid id,
  String? to, {
  Set<String> alsoUsed = const {},
}) => buildSetPathwayDesignator(
  doc: doc,
  pathwayId: id,
  to: to,
  now: _now,
  actor: _actor,
  alsoUsedDesignators: alsoUsed,
);

void main() {
  group('it sets a designator', () {
    test('a free designator produces a command that applies and reverts', () {
      final doc = _doc();
      final result = _set(doc, _idA, 'T1');

      expect(result, isA<SetPathwayDesignatorReady>());
      final command = (result as SetPathwayDesignatorReady).command..apply(doc);
      expect(doc.pathways[_idA]!.designator, 'T1');

      command.revert(doc);
      expect(doc.pathways[_idA]!.designator, isNull);
    });

    test('it trims, because a trailing space is not a different trunk', () {
      final doc = _doc();
      final result = _set(doc, _idA, '  T1  ');
      expect(result, isA<SetPathwayDesignatorReady>());
      (result as SetPathwayDesignatorReady).command.apply(doc);
      expect(doc.pathways[_idA]!.designator, 'T1');
    });
  });

  group('uniqueness where set (DR-026, CR-113 precedent)', () {
    test('a designator another pathway already carries is REFUSED, and the '
        'document is untouched', () {
      final doc = _doc(bDesignator: 'T1');
      final result = _set(doc, _idA, 'T1');

      expect(result, isA<SetPathwayDesignatorRefused>());
      expect(
        (result as SetPathwayDesignatorRefused).reason,
        contains('already used by another pathway'),
      );
      // The refusal is the artifact; so is the absence of a write.
      expect(doc.pathways[_idA]!.designator, isNull);
      expect(doc.pathways[_idB]!.designator, 'T1');
    });

    test('the collision survives whitespace, so " T1 " cannot slip past', () {
      final doc = _doc(bDesignator: 'T1');
      expect(_set(doc, _idA, ' T1 '), isA<SetPathwayDesignatorRefused>());
    });

    test('a pathway does not collide with ITSELF: retyping its own value is '
        'Unchanged, not Refused', () {
      final doc = _doc(aDesignator: 'T1');
      expect(_set(doc, _idA, 'T1'), isA<SetPathwayDesignatorUnchanged>());
    });

    test('alsoUsedDesignators refuses against a pending sibling in the same '
        'transaction', () {
      // A bulk edit builds against ONE unmutated document, so two rows can
      // agree on a designator and neither scan would see the other. Same
      // reason buildAddHomeRunCommand carries alsoUsedLabels.
      final doc = _doc();
      expect(
        _set(doc, _idA, 'T1', alsoUsed: {'T1'}),
        isA<SetPathwayDesignatorRefused>(),
      );
    });
  });

  group('null is unknown and never a collision (G4, CR-114)', () {
    test('two pathways may both carry no designator', () {
      final doc = _doc();
      expect(_set(doc, _idA, null), isA<SetPathwayDesignatorUnchanged>());
      expect(doc.pathways[_idA]!.designator, isNull);
      expect(doc.pathways[_idB]!.designator, isNull);
    });

    test('clearing a designator is always legal, even when another pathway '
        'has one', () {
      final doc = _doc(aDesignator: 'T1', bDesignator: 'T2');
      final result = _set(doc, _idA, null);
      expect(result, isA<SetPathwayDesignatorReady>());
      (result as SetPathwayDesignatorReady).command.apply(doc);
      expect(doc.pathways[_idA]!.designator, isNull);
    });

    test('a BLANK BOX becomes null, never the empty string', () {
      // `''` would be a third state every reader has to guess about, and
      // G4's rule is that unknown is ABSENT, not empty. It is also what
      // keeps clearing legal, since null never collides.
      final doc = _doc(aDesignator: 'T1');
      final result = _set(doc, _idA, '   ');
      expect(result, isA<SetPathwayDesignatorReady>());
      (result as SetPathwayDesignatorReady).command.apply(doc);
      expect(doc.pathways[_idA]!.designator, isNull);
    });

    test('two pathways cleared to blank do not collide on ""', () {
      final doc = _doc(aDesignator: 'T1', bDesignator: 'T2');
      for (final id in [_idA, _idB]) {
        final r = _set(doc, id, '');
        expect(r, isA<SetPathwayDesignatorReady>());
        (r as SetPathwayDesignatorReady).command.apply(doc);
      }
      expect(doc.pathways[_idA]!.designator, isNull);
      expect(doc.pathways[_idB]!.designator, isNull);
    });
  });

  test('a pathway that is not in the project is refused by name, not by a '
      'null dereference three frames deeper', () {
    final doc = _doc();
    final result = _set(doc, _absent, 'T1');
    expect(result, isA<SetPathwayDesignatorRefused>());
    expect(
      (result as SetPathwayDesignatorRefused).reason,
      contains('not in this project'),
    );
  });

  test('THE FIELD TABLE ROW EXISTS AND IS LISTED, so a reader looking for '
      'the designator finds it where the others are', () {
    // The row is deliberately present in `PathwayField.all` even though it
    // must not be driven through `buildSetEntityProperty`; hiding it would
    // trade one trap for another. Its doc comment carries the warning.
    expect(PathwayField.all, contains(PathwayField.designator));
    expect(PathwayField.designator.key, 'designator');
    // `meta` alone, matching `name`: labelling a trunk changes no cable.
    expect(PathwayField.designator.touches, EpochMask.meta);
  });
}
