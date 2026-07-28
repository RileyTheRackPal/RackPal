// DR-008 §11.8.2's storage contract: `linkClassLocked` is written ONLY
// when true, and its absence means false.
//
// THIS FILE IS A FILE-COMPATIBILITY GATE, not an encoder unit test. The
// ruling permits the second field precisely because it can be added
// without moving `kSchemaVersion`, and that permission rests entirely on
// the key being absent in the normal case. An encoder "tidied" into
// writing it unconditionally — the way `designatorLocked` six lines above
// it in the codec is written — would add a key to every Link in every
// document already on disk. Nothing would throw. Every file's bytes would
// simply differ from the golden that was committed for it, and the
// byte-exactness gate would fail across the corpus at once with no obvious
// cause.
//
// So the load-bearing test here is the NEGATIVE one: `false` never appears
// on the wire. `set-then-clear returns the original bytes` is the same
// claim stated so that a round trip through the commands cannot smuggle a
// key in either.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

void main() {
  group('Link.linkClassLocked on the wire', () {
    const codec = JsonDocumentCodec();
    final when = DateTime.utc(2026, 7, 28);
    EntityMeta meta() =>
        EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'test');

    const linkId = Uuid('lnk-1');

    RackDocument docWith({required bool locked}) {
      final doc = RackDocument(
        id: const Uuid('doc-lcl'),
        appVersion: '0.1.0',
        createdAt: when,
        modifiedAt: when,
        meta: meta(),
      );
      doc.links[linkId] = Link(
        id: linkId,
        designator: 'W001',
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a0'),
        meta: meta(),
        linkClass: LinkClass.jumper,
        linkClassLocked: locked,
      );
      return doc;
    }

    String textOf(RackDocument doc) => String.fromCharCodes(codec.write(doc));

    test('ABSENT when false — this is what lets kSchemaVersion stay put', () {
      expect(
        textOf(docWith(locked: false)),
        isNot(contains('linkClassLocked')),
        reason:
            'the key must not appear at all for a link nobody has hand-set. '
            'Emitting it — even as false — rewrites every Link in every '
            'document already saved, which is exactly what §11.8.2 says '
            'this field must not do',
      );
    });

    test('present and true when a person has set the class', () {
      expect(
        textOf(docWith(locked: true)),
        contains('"linkClassLocked": true'),
      );
    });

    test('"linkClassLocked": false is NEVER emitted', () {
      // The mutation this kills: `json['linkClassLocked'] = l.linkClassLocked`
      // in place of the `if (l.linkClassLocked)` guard. It round-trips
      // perfectly and passes every decode test — and silently invalidates
      // every committed golden.
      for (final locked in [true, false]) {
        expect(
          textOf(docWith(locked: locked)),
          isNot(contains('"linkClassLocked": false')),
        );
      }
    });

    test('set-then-clear returns the ORIGINAL BYTES exactly', () {
      final doc = docWith(locked: false);
      final before = codec.write(doc);

      // Asserting the class it ALREADY has, so the only thing that can
      // move on the wire is the lock key. Setting a different class would
      // make this test pass or fail for two reasons at once, and the one
      // being pinned here is the lock.
      SetLinkClassCommand(
        linkId: linkId,
        linkClass: LinkClass.jumper,
      ).apply(doc);
      expect(
        textOf(doc),
        contains('"linkClassLocked": true'),
        reason: 'guards the assertion below against passing vacuously',
      );

      ClearLinkClassOverrideCommand(linkId: linkId).apply(doc);
      expect(
        codec.write(doc),
        before,
        reason:
            'clearing an override must leave NO residue on disk — a user '
            'who sets a class and changes their mind must not leave the '
            'document permanently different from the one they opened',
      );
    });

    test('absent decodes to false', () {
      final bytes = codec.write(docWith(locked: false));
      final decoded = codec.read(bytes);
      expect(decoded, isA<Ok<RackDocument>>());
      expect(
        (decoded as Ok<RackDocument>).value.links[linkId]!.linkClassLocked,
        isFalse,
      );
    });

    test('true round-trips', () {
      final decoded = codec.read(codec.write(docWith(locked: true)));
      expect(decoded, isA<Ok<RackDocument>>());
      final link = (decoded as Ok<RackDocument>).value.links[linkId]!;
      expect(link.linkClassLocked, isTrue);
      expect(link.linkClass, LinkClass.jumper);
    });
  });
}
