// DR-070 §11.69's storage contract: a run with no box writes `outletId`
// as an ABSENT KEY and `boxless` only when true.
//
// THIS FILE IS A FILE-COMPATIBILITY GATE, not an encoder unit test, and
// it is the same gate `link_class_locked_wire_test.dart` opens with. The
// ruling permits both changes without moving `kSchemaVersion`, and that
// permission rests entirely on two properties of the NORMAL case:
//
//   * `outletId` was REQUIRED until `#718`, so every document ever
//     written carries one. Reading yields that id and writing writes it
//     back, and no file on disk moves a byte.
//   * `boxless` is false in every one of those documents, so emitting it
//     would add a key to every home run in the corpus at once. Nothing
//     would throw; every committed golden would simply stop matching.
//
// So the load-bearing tests here are the NEGATIVE ones.
//
// AND ONE THAT IS ABOUT MEANING RATHER THAN BYTES. G4 gives an absent
// value exactly one reading, `unknown`, and a ceiling speaker having no
// box is something a person STATED. The two must survive a round trip as
// two different documents, or the Outlets page cannot count either
// honestly.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

void main() {
  group('a boxless home run on the wire', () {
    const codec = JsonDocumentCodec();
    final when = DateTime.utc(2026, 8, 18);
    EntityMeta meta() =>
        EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'test');

    const linkId = Uuid('lnk-spk');
    const bodyId = Uuid('body-1');
    const outletId = Uuid('outlet-1');

    RackDocument docWith({required bool boxless}) {
      final doc = RackDocument(
        // THE ID MUST NOT CONTAIN THE WORD. `doc-boxless` was the first
        // draft, and the negative assertions below scan the WHOLE
        // document text: the id alone made "no boxless key" fail against
        // an encoder that was doing exactly the right thing.
        id: const Uuid('doc-wire-1'),
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
        structureOrigin: StructureOrigin(
          structureBodyId: bodyId,
          outletId: boxless ? null : outletId,
          boxless: boxless,
          fieldLabel: 'LR-SPK-L',
        ),
      );
      return doc;
    }

    String textOf(RackDocument doc) => String.fromCharCodes(codec.write(doc));

    /// A document through the codec and back. `read` returns an
    /// `Outcome`, and a decode that failed must fail THIS test rather
    /// than be silently skipped past.
    RackDocument roundTrip(RackDocument doc) {
      final decoded = codec.read(codec.write(doc));
      expect(decoded, isA<Ok<RackDocument>>());
      return (decoded as Ok<RackDocument>).value;
    }

    test('a run WITH a box writes outletId and no boxless key', () {
      // The corpus as it stands. Every document on disk is this shape,
      // and this is the assertion that keeps them byte-identical.
      final text = textOf(docWith(boxless: false));
      expect(text, contains('"outletId"'));
      expect(
        text,
        isNot(contains('boxless')),
        reason:
            'emitting it — even as false — rewrites every home run in '
            'every document already saved',
      );
    });

    test('"boxless": false is NEVER emitted', () {
      // The mutation this kills: `json['boxless'] = o.boxless` in place
      // of the `if (o.boxless)` guard. It round-trips perfectly and
      // passes every decode test, and silently invalidates every golden.
      for (final boxless in [true, false]) {
        expect(
          textOf(docWith(boxless: boxless)),
          isNot(contains('"boxless": false')),
        );
      }
    });

    test('a run with NO box omits outletId and says boxless', () {
      final text = textOf(docWith(boxless: true));
      expect(text, isNot(contains('"outletId"')));
      expect(text, contains('"boxless": true'));
    });

    test('BOTH STATES SURVIVE THE ROUND TRIP AS DIFFERENT DOCUMENTS', () {
      // The point of the second field. "Nobody has said which box" and
      // "there is no box" are two facts, and a file that could not tell
      // them apart would leave the Outlets page unable to count either.
      final unknown = docWith(boxless: false);
      unknown.links[linkId]!.structureOrigin = StructureOrigin(
        structureBodyId: bodyId,
        fieldLabel: 'LR-SPK-L',
        // Neither stated: no id, and nobody has said there is no box.
        outletId: null,
      );

      final stated = docWith(boxless: true);
      expect(
        textOf(unknown),
        isNot(textOf(stated)),
        reason: 'an absent id alone must not be able to mean both',
      );

      final backUnknown = roundTrip(unknown);
      final backStated = roundTrip(stated);
      expect(backUnknown.links[linkId]!.structureOrigin!.boxless, isFalse);
      expect(backStated.links[linkId]!.structureOrigin!.boxless, isTrue);
      expect(backUnknown.links[linkId]!.structureOrigin!.outletId, isNull);
      expect(backStated.links[linkId]!.structureOrigin!.outletId, isNull);
    });

    test('and a stored id round-trips unchanged', () {
      final back = roundTrip(docWith(boxless: false));
      expect(back.links[linkId]!.structureOrigin!.outletId, outletId);
      expect(codec.write(back), codec.write(docWith(boxless: false)));
    });
  });
}
