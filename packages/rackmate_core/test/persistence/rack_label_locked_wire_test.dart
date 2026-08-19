// DR-074 §11.73.2's storage contract: `rackLabelLocked` is written ONLY
// when true, and its absence means false.
//
// THIS FILE IS A FILE-COMPATIBILITY GATE, not an encoder unit test, and it
// is `link_class_locked_wire_test.dart`'s claim made a second time because
// the ruling explicitly borrows that field's shape and explicitly refuses
// `designatorLocked`'s. Every document ever written carries an allocated
// rack label or none, since nothing before this could hand-set one; an
// encoder "tidied" into emitting the key unconditionally would add it to
// every home run in every file on disk. Nothing would throw. The bytes
// would simply differ from every committed golden at once.
//
// So the load-bearing test is the NEGATIVE one: `false` never reaches the
// wire.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

void main() {
  group('StructureOrigin.rackLabelLocked on the wire', () {
    const codec = JsonDocumentCodec();
    final when = DateTime.utc(2026, 8, 18);
    EntityMeta meta() =>
        EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'test');

    const linkId = Uuid('lnk-1');
    const bodyId = Uuid('str-1');
    const outletId = Uuid('out-1');

    RackDocument docWith({required bool locked, String? label = 'PP1-01'}) {
      final doc = RackDocument(
        id: const Uuid('doc-rll'),
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
          outletId: outletId,
          fieldLabel: 'GR-DATA-1',
          rackLabel: label,
          rackLabelLocked: locked,
        ),
      );
      return doc;
    }

    String textOf(RackDocument doc) => String.fromCharCodes(codec.write(doc));

    test('ABSENT when false — this is what lets kSchemaVersion stay put', () {
      expect(
        textOf(docWith(locked: false)),
        isNot(contains('rackLabelLocked')),
        reason:
            'the key must not appear at all for a label the allocator '
            'produced, which is every label in every document written '
            'before DR-074',
      );
    });

    test('present and true when a person typed the label', () {
      expect(
        textOf(docWith(locked: true)),
        contains('"rackLabelLocked": true'),
      );
    });

    test('"rackLabelLocked": false is NEVER emitted', () {
      // The mutation this kills: `json['rackLabelLocked'] =
      // o.rackLabelLocked` in place of the `if` guard. It round-trips
      // perfectly, passes every decode test, and invalidates every
      // committed golden that holds a home run.
      for (final locked in [true, false]) {
        expect(
          textOf(docWith(locked: locked)),
          isNot(contains('"rackLabelLocked": false')),
        );
      }
    });

    test('clearing the cell leaves NO residue of the lock on disk', () {
      // The precedent's "set-then-clear returns the original bytes", in
      // the form this field can take it. There is no unlock command: the
      // way back is a blank cell, which clears the label AND the lock
      // (see `SetRackLabelCommand`). So the document a person leaves
      // behind must be byte-identical to one that was never hand-set,
      // rather than carrying a `"rackLabelLocked": false` fossil.
      //
      // BOTH COMMANDS BELOW WRITE THE FIXTURE'S OWN `now` AND `actor`, so
      // the `EntityMeta` touch every edit makes is not the thing under
      // test. Unlike `SetLinkClassCommand`, this command stamps the link,
      // and a byte comparison that let the stamp move would fail for a
      // reason that has nothing to do with the lock.
      final doc = docWith(locked: false, label: null);
      final never = codec.write(doc);

      SetRackLabelCommand(
        linkId: linkId,
        rackLabel: 'BY-HAND-7',
        now: when,
        actor: 'test',
      ).apply(doc);
      expect(
        textOf(doc),
        contains('"rackLabelLocked": true'),
        reason: 'guards the assertion below against passing vacuously',
      );

      SetRackLabelCommand(
        linkId: linkId,
        rackLabel: null,
        now: when,
        actor: 'test',
      ).apply(doc);
      expect(
        codec.write(doc),
        never,
        reason:
            'a person who typed a name and changed their mind must not '
            'leave the document permanently different from the one they '
            'opened',
      );
    });

    test('absent decodes to false', () {
      final bytes = codec.write(docWith(locked: false));
      final decoded = codec.read(bytes);
      expect(decoded, isA<Ok<RackDocument>>());
      expect(
        (decoded as Ok<RackDocument>)
            .value
            .links[linkId]!
            .structureOrigin!
            .rackLabelLocked,
        isFalse,
      );
    });

    test('true round-trips, and so does the label it qualifies', () {
      final decoded = codec.read(codec.write(docWith(locked: true)));
      expect(decoded, isA<Ok<RackDocument>>());
      final origin =
          (decoded as Ok<RackDocument>).value.links[linkId]!.structureOrigin!;
      expect(origin.rackLabelLocked, isTrue);
      expect(origin.rackLabel, 'PP1-01');
    });
  });
}
