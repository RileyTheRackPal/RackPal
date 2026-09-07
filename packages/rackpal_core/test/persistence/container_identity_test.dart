// PLAN-B/4: a document with no underlay writes bytes IDENTICAL to what
// this build wrote yesterday, proven over the checked-in corpus.
//
// ─────────────────────────────────────────────────────────────────────────
// THIS IS THE CLAUSE THAT MAKES THE CONTAINER ADDITIVE
// ─────────────────────────────────────────────────────────────────────────
// DR-019 §11.18.2(1): *"a document with no underlay writes bytes identical
// to today's."* That sentence is the whole difference between this epic
// being legal under roadmap §2.2 and being a format migration, and
// §11.18.6 leans on it explicitly: the membership criterion forbids a
// migration, and the shape ruled here migrates nothing.
//
// ─────────────────────────────────────────────────────────────────────────
// THE NEGATIVE IS THE HALF THAT ACTUALLY CATCHES SOMETHING
// ─────────────────────────────────────────────────────────────────────────
// A writer that emitted a one-entry zip for EVERY document would pass any
// round-trip test ever written, and would break the byte identity of
// every `.rmpj` in existence. So the tests below assert not only that the
// no-member path reproduces the bytes but that it does not produce a zip
// at all, on real files rather than on a fixture: the four starters are
// checked in, byte-verified by `gitattributes_byte_exactness_test.dart`,
// and are what the app actually opens.

import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const List<String> _starters = [
  'apartment',
  'home_theatre',
  'small_office',
  'whole_house',
];

/// Run from the package directory (CLAUDE.md), which is what makes this
/// relative path the same one `rackpal_export`'s starter tests use.
Uint8List _starterBytes(String name) =>
    File('../../apps/rackpal/assets/starters/$name.rmpj').readAsBytesSync();

void main() {
  group('the corpus this is asserted over is real', () {
    test('all four starters exist and are substantial', () {
      for (final name in _starters) {
        final bytes = _starterBytes(name);
        expect(bytes.length, greaterThan(10000), reason: name);
        // Plain JSON today, which is the premise everything below rests
        // on. If a starter ever becomes a container this test is the
        // first thing that should say so.
        expect(looksLikeZip(bytes), isFalse, reason: name);
      }
    });
  });

  group('no members means the bytes do not move at all', () {
    test('every starter survives read-then-write byte for byte', () {
      for (final name in _starters) {
        final original = _starterBytes(name);
        final parts = readContainerParts(original);
        expect(parts, isA<Ok<ContainerParts>>(), reason: name);

        final value = (parts as Ok<ContainerParts>).value;
        expect(value.hasMembers, isFalse, reason: name);
        expect(value.members, isEmpty, reason: name);

        final rewritten = writeContainerBytes(
          value.documentBytes,
          value.members,
        );
        expect(rewritten, original, reason: name);
      }
    });

    test('the no-member write is an IDENTITY, not a reproduction', () {
      // Stronger than equality and cheaper to hold in the head: the
      // envelope hands the same object straight back, so there is no
      // second encoder that could ever drift from the first.
      final original = _starterBytes('apartment');
      expect(
        identical(writeContainerBytes(original, const {}), original),
        isTrue,
      );
    });

    test('reading a plain file copies nothing either', () {
      final original = _starterBytes('whole_house');
      final parts = (readContainerParts(original) as Ok<ContainerParts>).value;
      expect(identical(parts.documentBytes, original), isTrue);
    });
  });

  group('THE NEGATIVE: nothing writes a zip without a binary member', () {
    test('no starter round-trips into something that sniffs as a zip', () {
      for (final name in _starters) {
        final parts =
            (readContainerParts(_starterBytes(name)) as Ok<ContainerParts>)
                .value;
        final out = writeContainerBytes(parts.documentBytes, parts.members);
        expect(looksLikeZip(out), isFalse, reason: name);
      }
    });

    test('an empty member map writes plain bytes; ONE member writes a zip', () {
      final doc = _starterBytes('small_office');

      expect(looksLikeZip(writeContainerBytes(doc, const {})), isFalse);
      expect(
        looksLikeZip(
          writeContainerBytes(doc, {
            'underlays/a.png': Uint8List.fromList(const [1, 2, 3]),
          }),
        ),
        isTrue,
      );
    });

    test('the boundary is the member COUNT and not the member SIZE', () {
      // A zero-byte member is still a member. A writer that branched on
      // "is there anything worth zipping" instead of "is there a member"
      // would drop an empty underlay silently, and an empty underlay is a
      // corrupt import rather than an absent one.
      final doc = _starterBytes('small_office');
      expect(
        looksLikeZip(
          writeContainerBytes(doc, {'underlays/a.png': Uint8List(0)}),
        ),
        isTrue,
      );
    });
  });

  group('a container built from a starter reopens as that starter', () {
    test('the document half is untouched by the trip through a zip', () {
      for (final name in _starters) {
        final original = _starterBytes(name);
        final zip = writeContainerBytes(original, {
          'underlays/level-1.png': Uint8List.fromList(
            List<int>.generate(2048, (i) => (i * 17 + 5) % 256),
          ),
        });
        expect(looksLikeZip(zip), isTrue, reason: name);

        final parts = (readContainerParts(zip) as Ok<ContainerParts>).value;
        expect(parts.documentBytes, original, reason: name);
        expect(parts.members, hasLength(1), reason: name);
      }
    });
  });
}
