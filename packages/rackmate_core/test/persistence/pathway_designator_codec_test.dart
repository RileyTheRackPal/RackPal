// `Pathway.designator` on the wire (DR-026 §11.25.1, confirmed permanent
// by DR-037 §11.36.6).
//
// THIS FILE EXISTS TO REFUTE #157's OWN COST ESTIMATE, which read
// "adding one changes stored state (CR-117's byte gate, kSchemaVersion)".
// It does not. A nullable key written only when present leaves every file
// already on disk re-encoding byte for byte, and the schema version does
// not move. DR-026 said so from a reading of `tia570Grade` (DR-024); this
// asserts it against the encoder.
import 'dart:convert';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 8, 10, 9),
  updatedAt: DateTime.utc(2026, 8, 10, 9),
  updatedBy: 'rriley',
);

/// The encoded map for one pathway.
///
/// Scoped deliberately rather than grepping the whole file for
/// `designator`: `ProjectSettings` carries `designatorBlockSize`,
/// `designatorPad` and `designatorSeparator`, so a whole-document string
/// search answers a different question than the one being asked and
/// answers it wrongly. Assert the artifact.
Map<String, Object?> _encodedPathway(RackDocument doc, String id) {
  final json =
      jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
  // `registries` is nested under `document`; so is everything else.
  final root = (json['document'] as Map<String, Object?>?) ?? json;
  final pathways = root['pathways']! as Map<String, Object?>;
  return pathways[id]! as Map<String, Object?>;
}

RackDocument _docWith(Iterable<Pathway> pathways) {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-00000000dead'),
    appVersion: '0.1.0+build.1',
    createdAt: DateTime.utc(2026, 8, 10, 9),
    modifiedAt: DateTime.utc(2026, 8, 10, 9),
    meta: _meta(),
    info: ProjectInfo(projectName: 'Designator fixture'),
  );
  for (final p in pathways) {
    doc.pathways[p.id] = p;
  }
  return doc;
}

Pathway _pathway({
  required String id,
  required String name,
  String? designator,
  String order = 'a0',
}) => Pathway(
  id: Uuid(id),
  name: name,
  order: FracIndex(order),
  meta: _meta(),
  designator: designator,
);

const _idA = '0190e3c1-0000-7000-8000-0000000000a1';
const _idB = '0190e3c1-0000-7000-8000-0000000000b2';

void main() {
  group('Pathway.designator costs nothing when it is not set', () {
    test('an unset designator emits NO KEY AT ALL, not an explicit null', () {
      final doc = _docWith([_pathway(id: _idA, name: 'attic to garage')]);

      final encoded = _encodedPathway(doc, _idA);

      // G4/CR-114: unknown is an ABSENT KEY, never an explicit null.
      expect(encoded.containsKey('designator'), isFalse);
      expect(encoded['name'], 'attic to garage');
    });

    test('a document with no designators writes the same bytes it did '
        'before the field existed', () {
      // The property that matters is not "it round-trips" but "adding the
      // field moved nothing". Written as a byte comparison between a
      // document whose pathway carries no designator and the same bytes
      // re-read and re-written, which is CR-117 on the path #157 feared.
      final doc = _docWith([
        _pathway(id: _idA, name: 'attic to garage'),
        _pathway(id: _idB, name: 'riser to level 2', order: 'a1'),
      ]);

      final first = _codec.write(doc);
      final reread = _codec.read(first);
      expect(reread, isA<Ok<RackDocument>>());
      final second = _codec.write((reread as Ok<RackDocument>).value);

      expect(second, orderedEquals(first));
      for (final id in [_idA, _idB]) {
        expect(
          _encodedPathway(doc, id).containsKey('designator'),
          isFalse,
          reason: 'neither pathway carries one, so neither may emit the key',
        );
      }
    });
  });

  group('a designator that IS set survives the wire exactly', () {
    test('write -> read -> write is byte-identical with the key present', () {
      final doc = _docWith([
        _pathway(id: _idA, name: 'attic to garage', designator: 'T1'),
        _pathway(id: _idB, name: 'riser to level 2', order: 'a1'),
      ]);

      final first = _codec.write(doc);
      expect(utf8.decode(first), contains('"designator": "T1"'));

      final reread = _codec.read(first);
      expect(reread, isA<Ok<RackDocument>>());
      final back = (reread as Ok<RackDocument>).value;

      expect(back.pathways[const Uuid(_idA)]!.designator, 'T1');
      // The one that never had one still has none. Null did not become ''.
      expect(back.pathways[const Uuid(_idB)]!.designator, isNull);

      expect(_codec.write(back), orderedEquals(first));
    });

    test('a designator and a name are TWO FACTS and neither overwrites the '
        'other', () {
      // DR-026 §11.25.1 refused overloading `name`, on the grounds that a
      // trunk called "attic run to the garage" and one called `PW-LR-1`
      // are two facts. This is that ruling as an assertion: the pair
      // survives a round-trip independently, so no future reader can
      // conclude one is derivable from the other.
      final doc = _docWith([
        _pathway(id: _idA, name: 'attic run to the garage', designator: 'T1'),
      ]);

      final back = (_codec.read(_codec.write(doc)) as Ok<RackDocument>).value;
      final p = back.pathways[const Uuid(_idA)]!;

      expect(p.name, 'attic run to the garage');
      expect(p.designator, 'T1');
    });
  });

  test('an existing document that predates the field reads with a null '
      'designator rather than failing', () {
    // Forward-compat's mirror: an OLD file has no `designator` key, and
    // the decoder must treat the absence as unknown rather than as a
    // malformed pathway.
    final doc = _docWith([_pathway(id: _idA, name: 'attic to garage')]);
    final bytes = _codec.write(doc);
    expect(_encodedPathway(doc, _idA).containsKey('designator'), isFalse);

    final back = (_codec.read(bytes) as Ok<RackDocument>).value;
    expect(back.pathways[const Uuid(_idA)]!.designator, isNull);
  });
}
