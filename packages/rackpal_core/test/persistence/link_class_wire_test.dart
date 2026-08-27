// Every `LinkClass` value survives the wire, spelled the way the wire
// spells it.
//
// WHY: a repo-wide grep for `LinkClass` finds it in exactly three files —
// `model/link.dart`, `persistence/json_codec.dart`, and the starter
// authoring tool. NO TEST ANYWHERE NAMED IT. The only coverage the enum had
// was a single incidental `"linkClass": "fieldCable"` inside one golden
// fixture, so three of its four values had never once made the round trip.
//
// That matters more than an untested enum usually does, because the decode
// side is a THROWING path (`decodeEnumStrict`): a value this codec cannot
// spell is not a wrong default, it is a file the user cannot open. AC-026
// is about to start writing the other three values.
//
// THE STRING SPELLINGS ARE THE POINT, not just the round trip. These land
// in every saved document, so renaming a constant renames a wire key and
// silently orphans every file already on disk. The literals below are
// therefore written out by hand rather than derived from `.name` — deriving
// them would make this test agree with any rename, which is precisely what
// it must not do.
//
// A NOTE ON THE KEY ITSELF, so the next reader does not "fix" it:
// `docs/canonical-decisions.md` renders AC-026's field as `class`, while
// the codec writes `linkClass` and every saved file contains `linkClass`.
// The code is not changing — `class` is a Dart reserved word and the bytes
// are already shipped. The document is what needs reconciling.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  group('LinkClass on the wire', () {
    const codec = JsonDocumentCodec();
    final when = DateTime.utc(2026, 7, 28);
    EntityMeta meta() =>
        EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'test');

    RackDocument docWith(LinkClass value) {
      final doc = RackDocument(
        id: const Uuid('doc-lc'),
        appVersion: '0.1.0',
        createdAt: when,
        modifiedAt: when,
        meta: meta(),
      );
      doc.links[const Uuid('lnk-1')] = Link(
        id: const Uuid('lnk-1'),
        designator: 'W001',
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a0'),
        meta: meta(),
      )..linkClass = value;
      return doc;
    }

    // The spellings, by hand. See the header for why these are not `.name`.
    const wireNames = <LinkClass, String>{
      LinkClass.fieldCable: 'fieldCable',
      LinkClass.jumper: 'jumper',
      LinkClass.powerCord: 'powerCord',
      LinkClass.internal: 'internal',
    };

    test('the map covers the enum — no value can be added without a '
        'spelling', () {
      expect(
        wireNames.keys.toSet(),
        LinkClass.values.toSet(),
        reason:
            'a LinkClass value with no entry here is a value nothing pins '
            'the wire spelling of, and the decode path throws on an '
            'unknown string — so an unspelled value is an unopenable file',
      );
    });

    for (final entry in wireNames.entries) {
      test('${entry.key.name} round-trips and is written as '
          '"${entry.value}"', () {
        final bytes = codec.write(docWith(entry.key));
        final text = String.fromCharCodes(bytes);

        expect(
          text,
          contains('"linkClass": "${entry.value}"'),
          reason:
              'the emitted spelling changed. Every document already saved '
              'contains the old one, and the decoder throws rather than '
              'defaulting, so this is a file-compatibility break and not a '
              'cosmetic rename',
        );

        final decoded = codec.read(bytes);
        expect(decoded, isA<Ok<RackDocument>>());
        expect(
          (decoded as Ok<RackDocument>)
              .value
              .links[const Uuid('lnk-1')]!
              .linkClass,
          entry.key,
        );
      });
    }
  });
}
