// Editing and merging a media type (`#247`, RJ-012, DR-107).
//
// ═══════════════════════════════════════════════════════════════════════
// THE MERGE TEST DOES NOT ENUMERATE THE FIELDS, AND THAT IS THE POINT
// ═══════════════════════════════════════════════════════════════════════
// Five fields name a `MediaTypeId`: `Link.media`,
// `OutletTemplate.drops[].media`, `Pathway.pathwayMedia`,
// `ProjectSettings.defaultNetworkMedia` and `CableSpecDef.mediaTypeId`.
// A test that checked those five by hand would pass on the day a sixth
// arrived, and the merge would silently orphan whatever named it.
//
// So the assertion is on the ARTIFACT: serialise the document and require
// that the loser's id appears nowhere in the bytes. A new field fails this
// test the moment somebody adds one, without anybody remembering to come
// back here.
//
// THIS FILE'S OWN FIRST DRAFT IS WHY. It wrote `Outlet.media`, from a grep
// that found `MediaTypeId media;` and assumed the owning class. The field
// is on `OutletDrop`, which hangs off `OutletTemplate.drops` in the
// REGISTRY, and an `Outlet` holds no media id at all. The analyzer caught
// that one; a subtler miss is what this shape is for.
import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _cat6e = MediaTypeId('media.cat6e');
const _typo = MediaTypeId('media.cat_6e_riser');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 8, 31),
  updatedAt: DateTime.utc(2026, 8, 31),
  updatedBy: 'test',
);

MediaTypeDef _def(
  MediaTypeId id,
  String name, {
  List<String> aliases = const [],
}) => MediaTypeDef(id: id, displayName: name, shortTag: 'C6', aliases: aliases);

RackDocument _blank() => RackDocument(
  id: const Uuid('doc-media-merge'),
  appVersion: '0.4.90',
  createdAt: DateTime.utc(2026, 8, 31),
  modifiedAt: DateTime.utc(2026, 8, 31),
  meta: _meta(),
);

/// A document holding the typo'd type in every place one can be held.
RackDocument _doc() {
  final doc = _blank();
  doc.registries.mediaTypes[_cat6e] = _def(_cat6e, 'Cat6e', aliases: ['Cat6e']);
  doc.registries.mediaTypes[_typo] = _def(
    _typo,
    'Cat 6e riser',
    aliases: ['Cat 6e riser'],
  );
  doc.settings.defaultNetworkMedia = _typo;
  doc.registries.cableSpecs['spec1'] = const CableSpecDef(
    id: 'spec1',
    manufacturer: 'Belden',
    partNumber: '10GX32',
    mediaTypeId: _typo,
  );
  doc.registries.outletTemplates['tpl1'] = OutletTemplate(
    id: 'tpl1',
    name: 'Data x2',
    drops: [OutletDrop(media: _typo, service: 'data', count: 2)],
  );
  // A LINK AND A PATHWAY, because without them two of the five fields are
  // never referenced and the "nowhere in the wire" assertion below would
  // pass over a command that ignored both. A guard that only proves the
  // fixture mentions the loser SOMEWHERE is not enough; it has to mention
  // it everywhere one can be mentioned.
  doc.links[const Uuid('link-1')] = Link(
    id: const Uuid('link-1'),
    designator: 'W001',
    media: _typo,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.pathways[const Uuid('path-1')] = Pathway(
    id: const Uuid('path-1'),
    name: 'Riser',
    order: const FracIndex('a0'),
    meta: _meta(),
    pathwayMedia: _typo,
  );
  return doc;
}

/// Every byte the document serialises to, as one string.
///
/// THE WHOLE TREE, deliberately: this is the assertion that a sixth field
/// naming a `MediaTypeId` cannot be missed, so it must not be narrowed to
/// the branches somebody currently believes matter.
String _wire(RackDocument doc) =>
    jsonEncode(const JsonDocumentCodec().encodeToJsonTree(doc));

void main() {
  group('an edit changes the label and never the id', () {
    test('renaming leaves the id alone, so no reference has to move', () {
      final doc = _doc();
      final was = doc.registries.mediaTypes[_typo]!;
      final cmd = EditMediaTypeCommand(
        from: was,
        to: _def(_typo, 'Cat 6e (riser)', aliases: was.aliases),
      )..apply(doc);

      expect(doc.registries.mediaTypes[_typo]!.displayName, 'Cat 6e (riser)');
      expect(
        doc.registries.mediaTypes.containsKey(_typo),
        isTrue,
        reason: 'the key is frozen at creation; only the label moved',
      );
      expect(doc.settings.defaultNetworkMedia, _typo);

      cmd.revert(doc);
      expect(doc.registries.mediaTypes[_typo]!.displayName, 'Cat 6e riser');
    });

    test('an edit that changed the id would be refused in debug, because a '
        'merge is the only thing allowed to move references', () {
      final doc = _doc();
      expect(
        () => EditMediaTypeCommand(
          from: doc.registries.mediaTypes[_typo]!,
          to: _def(_cat6e, 'Cat6e'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('a merge repoints every reference there is', () {
    test('the loser id survives NOWHERE in the serialised document', () {
      final doc = _doc();
      expect(
        _wire(doc),
        contains(_typo.v),
        reason:
            'the fixture must actually reference the loser, or this '
            'test passes by describing an empty document',
      );

      MergeMediaTypesCommand(winner: _cat6e, loser: _typo).apply(doc);

      expect(
        _wire(doc),
        isNot(contains(_typo.v)),
        reason:
            'a field naming the loser was missed; enumerate nothing and '
            'fix the command, not this assertion',
      );
      expect(doc.registries.mediaTypes.containsKey(_typo), isFalse);
    });

    test('and every one of them now names the winner', () {
      final doc = _doc();
      MergeMediaTypesCommand(winner: _cat6e, loser: _typo).apply(doc);
      expect(doc.settings.defaultNetworkMedia, _cat6e);
      expect(doc.registries.cableSpecs['spec1']!.mediaTypeId, _cat6e);
      expect(doc.links[const Uuid('link-1')]!.media, _cat6e);
      expect(doc.pathways[const Uuid('path-1')]!.pathwayMedia, _cat6e);
      expect(
        doc.registries.outletTemplates['tpl1']!.drops.single.media,
        _cat6e,
      );
    });

    test('the loser SPELLINGS move to the winner, so re-importing the sheet '
        'that created it resolves instead of minting it again', () {
      final doc = _doc();
      MergeMediaTypesCommand(winner: _cat6e, loser: _typo).apply(doc);
      final kept = doc.registries.mediaTypes[_cat6e]!;
      expect(kept.aliases, contains('Cat 6e riser'));
      expect(kept.aliases, contains('Cat6e'));
      expect(
        kept.displayName,
        'Cat6e',
        reason: 'the winner keeps its own name; only the spellings merge',
      );
    });

    test(
      'undo restores the loser, its references and the winner untouched',
      () {
        final doc = _doc();
        final before = _wire(doc);
        MergeMediaTypesCommand(winner: _cat6e, loser: _typo)
          ..apply(doc)
          ..revert(doc);
        expect(
          _wire(doc),
          before,
          reason:
              'a merge that cannot be undone byte for byte is a merge '
              'nobody should be offered',
        );
      },
    );

    test('redo after undo lands in the same place, so the command is not '
        'one-shot', () {
      final doc = _doc();
      final cmd = MergeMediaTypesCommand(winner: _cat6e, loser: _typo)
        ..apply(doc);
      final once = _wire(doc);
      cmd
        ..revert(doc)
        ..apply(doc);
      expect(_wire(doc), once);
    });

    test('merging a type into itself is refused rather than emptying the '
        'registry', () {
      expect(
        () => MergeMediaTypesCommand(winner: _cat6e, loser: _cat6e),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a document that never mentions the loser is left alone', () {
      final doc = _blank();
      doc.registries.mediaTypes[_cat6e] = _def(_cat6e, 'Cat6e');
      doc.registries.mediaTypes[_typo] = _def(_typo, 'Cat 6e riser');
      MergeMediaTypesCommand(winner: _cat6e, loser: _typo).apply(doc);
      expect(doc.registries.mediaTypes.keys, [_cat6e]);
    });
  });
}
