// DR-010 §11.10's two storage contracts, on the wire.
//
// CONTRACT 1 — §11.10.3's three new `SignalFamilyDef` fields are ADDITIVE
// AND OPTIONAL, written only when present. This is the `linkClassLocked`
// contract of §11.8.2 applied again, and it is what lets `kSchemaVersion`
// stay put: a family decoded from a document written before these keys
// existed must re-encode BYTE-FOR-BYTE. An encoder "tidied" into writing
// them unconditionally — the way `designatorLocked` is written — would
// add three keys to every family in every document already on disk.
// Nothing would throw; every golden in the corpus would simply stop
// matching at once, with no obvious cause.
//
// The one wrinkle, and it is the reason `dashOverride` is nullable rather
// than a `const []` default: `[]` IS A REAL VALUE. `audio.line_bal`
// overrides to *solid* inside the dashed `audio.analog` domain, so
// "absent" and "[]" must stay distinguishable across a round trip. An
// encoder that suppressed empty lists as "nothing to say" would silently
// redraw that family with its domain's `6,3` dash on reopen — the
// collision §4.4 moved it off in the first place.
//
// CONTRACT 2 — §11.10.2: the embedded registry subset is written at
// DOCUMENT CREATION and NEVER RECOMPUTED AT SAVE. The reason is CR-117.
// If `write()` recomputed "the subset this document references", then
// reading a document that carries an entry nothing references and writing
// it back would DROP that entry, and `write(read(bytes)) == bytes` is the
// property the whole byte suite rests on. Elision at save turns a
// hand-edited or forward-version file into silent data loss. The tests at
// the bottom are that claim, stated so that adding such a transform later
// fails here rather than in a user's file.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

void main() {
  const codec = JsonDocumentCodec();
  final when = DateTime.utc(2026, 7, 28);
  EntityMeta meta() =>
      EntityMeta(createdAt: when, updatedAt: when, updatedBy: 'test');

  RackDocument emptyDoc() => RackDocument(
    id: const Uuid('doc-reg'),
    appVersion: '0.1.0',
    createdAt: when,
    modifiedAt: when,
    meta: meta(),
  );

  /// A document whose only registry content is [family].
  RackDocument docWithFamily(SignalFamilyDef family) {
    final doc = emptyDoc();
    doc.registries.signalFamilies[family.id] = family;
    return doc;
  }

  /// A new document seeded from the Dart master — what `buildBlankDocument`
  /// and `StarterAuthor.newDocument` both produce.
  RackDocument seededDoc() => emptyDoc()..registries = buildSeedRegistries();

  SignalFamilyDef family({
    String? shortTag,
    List<int>? dashOverride,
    int? lineWeightPermilleOverride,
  }) => SignalFamilyDef(
    id: const SignalFamilyId('audio.line_bal'),
    displayName: 'Line level, balanced',
    domain: const SignalDomainId('audio.analog'),
    defaultConnector: const ConnectorTypeId('conn.xlr3'),
    defaultDirection: PortDirection.source,
    defaultTopology: PortTopology.p2p,
    shortTag: shortTag,
    dashOverride: dashOverride,
    lineWeightPermilleOverride: lineWeightPermilleOverride,
  );

  String textOf(RackDocument doc) => String.fromCharCodes(codec.write(doc));

  RackDocument reread(RackDocument doc) {
    final decoded = codec.read(codec.write(doc));
    expect(decoded, isA<Ok<RackDocument>>());
    return (decoded as Ok<RackDocument>).value;
  }

  group("SignalFamilyDef's three additive fields (§11.10.3)", () {
    test('ALL THREE KEYS ABSENT when unset — this is what lets '
        'kSchemaVersion stay put', () {
      final text = textOf(docWithFamily(family()));
      expect(text, isNot(contains('shortTag')));
      expect(text, isNot(contains('dashOverride')));
      expect(text, isNot(contains('lineWeightPermilleOverride')));
    });

    test('a family with no overrides re-encodes byte-for-byte through a '
        'read', () {
      // The whole compatibility claim in one line: a document written
      // before these fields existed produces IDENTICAL bytes after this
      // change. Any unconditional write breaks this.
      final doc = docWithFamily(family());
      final before = codec.write(doc);
      expect(codec.write(reread(doc)), before);
    });

    test('present values are written and round-trip', () {
      final doc = docWithFamily(
        family(
          shortTag: 'AUDB',
          dashOverride: [18000, 4000],
          lineWeightPermilleOverride: 1250,
        ),
      );
      final text = textOf(doc);
      expect(text, contains('"shortTag": "AUDB"'));
      expect(text, contains('"lineWeightPermilleOverride": 1250'));

      final back = reread(
        doc,
      ).registries.signalFamilies[const SignalFamilyId('audio.line_bal')]!;
      expect(back.shortTag, 'AUDB');
      expect(back.dashOverride, [18000, 4000]);
      expect(back.lineWeightPermilleOverride, 1250);
    });

    test('an EMPTY dashOverride survives — solid is a value, not an '
        'absence', () {
      // THE LOAD-BEARING ONE. The mutation this kills is
      // `if (d.dashOverride?.isNotEmpty ?? false)` in place of
      // `putIfNotNull`: it looks like tidy encoder hygiene, round-trips
      // every other family perfectly, and turns `audio.line_bal` from a
      // solid line back into its domain's `6,3` dash — re-creating the
      // four-way greyscale collision §4.4 moved it off.
      final doc = docWithFamily(family(dashOverride: const []));
      expect(textOf(doc), contains('"dashOverride": []'));

      final back = reread(
        doc,
      ).registries.signalFamilies[const SignalFamilyId('audio.line_bal')]!;
      expect(back.dashOverride, isNotNull);
      expect(back.dashOverride, isEmpty);

      // And it is genuinely distinguishable from "inherit" after the trip.
      final inherited = reread(
        docWithFamily(family()),
      ).registries.signalFamilies[const SignalFamilyId('audio.line_bal')]!;
      expect(inherited.dashOverride, isNull);
    });

    test('the effective-value fallback survives the round trip', () {
      // Storage is only half the contract; what a renderer reads is the
      // other half. PAL-1 is stated over effective values, so a decoded
      // family must resolve to the same dash and weight it was seeded
      // with.
      final domains = buildSeedSignalDomains();
      final seeded = buildSeedRegistries();
      final doc = emptyDoc()..registries = seeded;

      final back = reread(doc).registries.signalFamilies;
      for (final f in seeded.signalFamilies.values) {
        final d = domains[f.domain]!;
        expect(
          back[f.id]!.effectiveDashPattern(d),
          f.effectiveDashPattern(d),
          reason: '${f.id.v} dash moved across a save',
        );
        expect(
          back[f.id]!.effectiveLineWeightPermille(d),
          f.effectiveLineWeightPermille(d),
          reason: '${f.id.v} weight moved across a save',
        );
      }
    });
  });

  group('the seeded registries as stored data (§11.10.2)', () {
    test('a fully seeded document round-trips byte-exactly (CR-117)', () {
      final doc = seededDoc();
      final bytes = codec.write(doc);
      expect(codec.write(reread(doc)), bytes);
    });

    test('all 8 domains, 55 families and every connector come back', () {
      final back = reread(seededDoc()).registries;
      expect(back.signalDomains, hasLength(8));
      expect(back.signalFamilies, hasLength(55));
      expect(
        back.connectorTypes.length,
        buildSeedConnectorFootprints().length,
      );
      // Spot-check the whole domain record, since it is the only place
      // hue, dark hue, dash, weight and both glyphs travel together.
      final ctl = back.signalDomains[const SignalDomainId('ctl')]!;
      expect(ctl.color.toHex(), '#CC79A7');
      expect(ctl.colorDark.toHex(), '#E29CC3');
      expect(ctl.dashPattern, [1500, 3000]);
      expect(ctl.lineWeightPermille, 750);
      expect(ctl.glyph, '✚');
      expect(ctl.glyphAlt, '✳');
    });

    test('AN UNREFERENCED ENTRY IS NOT ELIDED AT SAVE — the write() '
        'transform §11.10.2 forbids', () {
      // A document holding a registry entry that NOTHING in it references
      // — no Service, no Net, no Port. A `write()` that recomputed "the
      // subset this document references" would drop it, and
      // `write(read(bytes)) == bytes` would fail for every hand-edited or
      // forward-version file. Registries are ordinary stored data.
      final doc = emptyDoc();
      doc.registries.signalDomains[const SignalDomainId(
        'zzz.unused',
      )] = SignalDomainDef(
        id: const SignalDomainId('zzz.unused'),
        displayName: 'Referenced By Nothing',
        tagPrefix: 'ZZZ',
        color: Rgb.fromHex('#123456'),
        colorDark: Rgb.fromHex('#654321'),
        dashPattern: const [4000, 4000],
        lineWeightPermille: 1000,
        glyph: '?',
        glyphAlt: '?',
      );
      expect(doc.links, isEmpty);
      expect(doc.nets, isEmpty);

      final bytes = codec.write(doc);
      final back = reread(doc);
      expect(
        back.registries.signalDomains.keys.map((k) => k.v),
        ['zzz.unused'],
        reason:
            'the unreferenced domain was dropped — write() has grown '
            'an elision transform, which is exactly what CR-117 forbids',
      );
      expect(codec.write(back), bytes);
    });

    test('a document whose registries are EMPTY stays empty — existing '
        'files are not migrated', () {
      // DR-010 §11.10.2: "Existing documents are not migrated." A user's
      // saved project must not silently gain 68 registry entries on
      // reopen; every unresolved id degrades to §6.2's `unknown(rawId)`
      // placeholder instead. Seeding belongs to document CREATION, and
      // the codec must have no opinion.
      final doc = emptyDoc();
      final back = reread(doc);
      expect(back.registries.signalDomains, isEmpty);
      expect(back.registries.signalFamilies, isEmpty);
      expect(back.registries.connectorTypes, isEmpty);
    });
  });
}
