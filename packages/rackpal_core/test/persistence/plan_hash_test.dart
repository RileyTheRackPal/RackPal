// PLAN-I/1: whether an underlay's stored bytes are the ones its
// `contentHash` was taken over (AC-042, DR-154 §11.153.5).
//
// ═══════════════════════════════════════════════════════════════════════
// THE THIRD STATE IS THE SUBJECT
// ═══════════════════════════════════════════════════════════════════════
// `false` asserts "this was edited". `null` says "there is nothing here
// to check against". `templateHashMatches` settled that distinction for
// the same question about a template, and collapsing the two would put a
// tampering badge on a file nobody touched, which is AC-042's own
// argument arriving from the other side.
//
// `PLN-004` fires on `false` alone, so a case that let a null through
// would ship a warning about a hand-typed string.
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final Uint8List _bytes = Uint8List.fromList([9, 8, 7, 6, 5, 4]);

PlanUnderlay _underlay(String contentHash) => PlanUnderlay(
  id: const Uuid('0190e0dd-0f00-7000-8000-0000000000aa'),
  name: 'Level 1',
  imageMember: 'underlays/a.png',
  format: PlanImageFormat.png,
  pixelWidth: 100,
  pixelHeight: 80,
  contentHash: contentHash,
  order: const FracIndex('a0'),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    updatedBy: 'tester',
  ),
);

void main() {
  group('the hash itself', () {
    test('is the shape importFloorplanBytes writes', () {
      final hash = planUnderlayHash(_bytes);

      expect(hash, startsWith('sha256:'));
      expect(hash.substring(7), hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash.substring(7)), isTrue);
    });

    test('two different byte strings do not collide', () {
      expect(
        planUnderlayHash(_bytes),
        isNot(planUnderlayHash(Uint8List.fromList([9, 8, 7, 6, 5, 3]))),
      );
    });
  });

  group('the three answers', () {
    test('TRUE when the bytes are the ones the hash was taken over', () {
      expect(
        planUnderlayHashMatches(_underlay(planUnderlayHash(_bytes)), _bytes),
        isTrue,
      );
    });

    /// The one `PLN-004` fires on.
    test('FALSE when one byte differs', () {
      final claimed = planUnderlayHash(_bytes);
      final changed = Uint8List.fromList(_bytes)..[0] = 0;
      expect(planUnderlayHashMatches(_underlay(claimed), changed), isFalse);
    });

    test('NULL when the stored hash is not a sha256 at all', () {
      expect(planUnderlayHashMatches(_underlay(''), _bytes), isNull);
      expect(planUnderlayHashMatches(_underlay('unhashed:x'), _bytes), isNull);
      expect(
        planUnderlayHashMatches(_underlay('md5:abc'), _bytes),
        isNull,
      );
    });

    /// The case `template_hash.dart` learned from a seeded catalogue
    /// writing `sha256:seed-catalog_audio.a01`: a prefix over something
    /// that is not 64 hex digits is not a hash either.
    test('NULL when it carries the prefix over something that is not a '
        'digest', () {
      expect(
        planUnderlayHashMatches(_underlay('sha256:not-a-digest'), _bytes),
        isNull,
      );
      expect(
        planUnderlayHashMatches(
          _underlay('sha256:${'g' * 64}'),
          _bytes,
        ),
        isNull,
        reason: 'sixty-four characters that are not hex are not a digest',
      );
    });

    test('and a null is NOT a mismatch, which is the whole distinction', () {
      // Stated as its own case because the two are one keystroke apart in
      // every caller: `!= true` would file a tampering warning on a file
      // this product simply cannot testify about.
      expect(planUnderlayHashMatches(_underlay('x'), _bytes), isNot(isFalse));
    });
  });
}
