// PER-RUN JACKET COLOUR — the behavioural half of the model-only stage.
//
// This field has NO user-visible consumer yet: there is no Link-creation
// UI until M2, the Schedule tab is an `UnbuiltView`, and the Pull Sheet's
// optional jacket-colour column (T6.10) does not exist. That is stated
// plainly rather than hedged, and it is exactly why these tests are the
// point: a persisted field with no surface rots unless something pins
// its shape.
//
// ═════════════════════════════════════════════════════════════════════
// THE SELF-REFERENTIAL TRAP THIS FILE IS WRITTEN TO AVOID
// ═════════════════════════════════════════════════════════════════════
// The obvious test of "the seed convention is editable" is to seed a
// document, edit it, and compare the result against
// `buildDefaultJacketColorConvention()`. That test cannot fail in the
// way that matters, because it asks the constant to confirm itself. So
// the assertions below compare against LITERALS WRITTEN HERE, and the
// override test reads its expectation back out of the ENCODED BYTES
// rather than out of the in-memory object it just built.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 7, 27, 9),
  updatedAt: DateTime.utc(2026, 7, 27, 9),
  updatedBy: 'rriley',
);

const _linkId = Uuid('0190e3c1-cf80-75bb-96ac-d3b7ef294cab');

/// A one-Link document. [jacketColorId] absent means the field is not set
/// at all, which is the case the absent-key rule is about.
RackDocument _docWithLink({
  JacketColorId? jacketColorId,
  Map<JacketColorId, JacketColorDef>? convention,
}) {
  final meta = _meta();
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-0000000000ab'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026, 7, 27, 9),
    modifiedAt: DateTime.utc(2026, 7, 27, 9),
    meta: meta,
    settings: ProjectSettings(jacketColorConventions: convention),
  );
  doc.links[_linkId] = Link(
    id: _linkId,
    designator: 'W001',
    media: const MediaTypeId('media.cat6_utp'),
    order: const FracIndex('a0'),
    meta: meta,
    jacket: JacketRating.cmr,
    jacketColorId: jacketColorId,
  );
  return doc;
}

/// The `document` object of an encoded [doc], as a plain JSON tree.
Map<String, Object?> _tree(RackDocument doc) {
  final root =
      jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
  return root['document']! as Map<String, Object?>;
}

Map<String, Object?> _linkJson(RackDocument doc) {
  final links = _tree(doc)['links']! as Map<String, Object?>;
  return links[_linkId.v]! as Map<String, Object?>;
}

Map<String, Object?> _settingsJson(RackDocument doc) =>
    _tree(doc)['settings']! as Map<String, Object?>;

RackDocument _reread(RackDocument doc) {
  final decoded = _codec.read(_codec.write(doc));
  expect(decoded, isA<Ok<RackDocument>>());
  return (decoded as Ok<RackDocument>).value;
}

void main() {
  group('Link.jacketColorId on disk — absent-key-not-null (CR-114, G4)', () {
    test('an unset jacket colour has NO key at all', () {
      final json = _linkJson(_docWithLink());
      expect(json.containsKey('jacketColorId'), isFalse);
      // And specifically not the other spelling of the same idea.
      expect(
        utf8.decode(_codec.write(_docWithLink())),
        isNot(contains('"jacketColorId": null')),
      );
    });

    test('a set jacket colour is written as its bare id string', () {
      final json = _linkJson(
        _docWithLink(jacketColorId: const JacketColorId('jc.blue')),
      );
      expect(json['jacketColorId'], 'jc.blue');
    });

    test('unset survives a round trip as unset, not as a default', () {
      final link = _reread(_docWithLink()).links[_linkId]!;
      expect(link.jacketColorId, isNull);
    });

    test('set survives a round trip with the same id', () {
      final link = _reread(
        _docWithLink(jacketColorId: const JacketColorId('jc.red')),
      ).links[_linkId]!;
      expect(link.jacketColorId?.v, 'jc.red');
    });

    test('the jacket RATING and the jacket COLOUR are two separate keys '
        'carrying two separate facts', () {
      // The confusion this whole field exists to end: `jacket` is the NEC
      // fire rating (CODE-002/NEC 800.154), `jacketColorId` is what
      // colour the sheath was. A codec that ever collapsed them would
      // still round-trip perfectly.
      final json = _linkJson(
        _docWithLink(jacketColorId: const JacketColorId('jc.black')),
      );
      expect(json['jacket'], 'cmr');
      expect(json['jacketColorId'], 'jc.black');
    });
  });

  group('a dangling id is UNKNOWN, never guessed and never dropped (G4)', () {
    test('an id resolving to no convention entry decodes INTACT', () {
      // The colour that was actually pulled is the one record of a
      // physical fact about the building. Dropping it because the entry
      // naming it has since been deleted would destroy that record; the
      // discipline is to keep it and COUNT it as unknown, the way
      // `Rollup.unknownCount` already does.
      final doc = _docWithLink(
        jacketColorId: const JacketColorId('jc.nonexistent'),
        convention: {
          const JacketColorId('jc.blue'): const JacketColorDef(
            displayName: 'Blue',
            abbr: 'BLU',
            color: Rgb(0x1F, 0x5F, 0xA8),
          ),
        },
      );
      final link = _reread(doc).links[_linkId]!;
      expect(link.jacketColorId?.v, 'jc.nonexistent');
      // WHAT IS NOT ASSERTED HERE, AND WHY. Two assertions used to
      // follow: that the reread convention map does not CONTAIN
      // `jc.nonexistent`, and — as a separate test — that the id is
      // `isNot('jc.blue')`, guarding against substitution with the first
      // entry. Neither could fail.
      //
      // `_decodeProjectSettings` builds the convention map solely from
      // `json['jacketColorConventions']`, and `Link _decodeLink(Uuid,
      // JsonMap)` never receives it — the two share no state, so no
      // decoder mutation short of a signature change can make a link's
      // id either manufacture an entry or resolve to one. And
      // `isNot('jc.blue')` is satisfied by NULL, so the substitution
      // test survived the very mutation it was written for (replacing
      // `_decodeLink`'s `jacketColorId:` argument with a literal null),
      // which the exact-equality assertion above kills outright.
      //
      // The live property is the one measured above: the id arrives
      // INTACT. Fabrication risk lives in a future consumer, not here.
    });
  });

  group('ProjectSettings.jacketColorConventions on disk', () {
    test('an empty convention is OMITTED, so documents written before this '
        'feature keep their bytes (CR-117)', () {
      // THIS TEST ASSERTED THE OPPOSITE UNTIL THE GOLDEN CORPUS WAS
      // REPAIRED, and it was green while doing real harm. The reasoning it
      // carried — "non-nullable field, and the three sibling maps all emit
      // `{}` today" — is true of `ruleOverrides`,
      // `familyColorOverrides` and `diversityFactorsByCategory` for a
      // reason that does NOT transfer: those three have emitted `{}` since
      // v1, so that empty object is already in the bytes of every
      // `.rmpj` ever written. `jacketColorConventions` is NEW.
      // Emitting it unconditionally moved the bytes of every stored
      // document the instant it was loaded and saved, which is precisely
      // the property docs/03 §9.1 states as CR-117 and M0's exit criterion
      // names: `write(read(bytes)) == bytes`.
      //
      // It went unnoticed because `byte_roundtrip_test.dart` overwrote its
      // own goldens before comparing (since `b94bd60`, M0), so the corpus
      // could not see a format change to a stored document. All four
      // fixtures were silently rewritten mid-run and the suite stayed
      // green. See that file's history note.
      //
      // An absent key and an empty map are identical to the decoder here
      // (`json['jacketColorConventions'] ?? {}`), so absent is the
      // spelling that is ALSO backward-compatible.
      final json = _settingsJson(_docWithLink());
      expect(
        json.containsKey('jacketColorConventions'),
        isFalse,
        reason: 'an empty convention must not add a key to a stored document',
      );
    });

    test('a NON-empty convention is written', () {
      // The other half, so the omission above cannot be satisfied by
      // never writing the key at all.
      final json = _settingsJson(
        _docWithLink(
          convention: {
            const JacketColorId('jc.blue'): const JacketColorDef(
              displayName: 'Blue',
              abbr: 'BLU',
              color: Rgb(0x1F, 0x5F, 0xA8),
            ),
          },
        ),
      );
      expect(json.containsKey('jacketColorConventions'), isTrue);
      expect(json['jacketColorConventions'], isNotEmpty);
    });

    test('every entry writes all four keys, including an EMPTY meaning', () {
      final json = _settingsJson(
        _docWithLink(
          convention: {
            const JacketColorId('jc.white'): const JacketColorDef(
              displayName: 'White',
              abbr: 'WHT',
              color: Rgb(0xF2, 0xF2, 0xEF),
            ),
          },
        ),
      );
      final entry =
          (json['jacketColorConventions']! as Map<String, Object?>)['jc.white']!
              as Map<String, Object?>;
      expect(entry.keys.toList(), ['abbr', 'color', 'displayName', 'meaning']);
      expect(entry['abbr'], 'WHT');
      expect(entry['displayName'], 'White');
      expect(entry['color'], '#FFF2F2EF');
      expect(
        entry['meaning'],
        '',
        reason:
            'an empty meaning is a VALUE — "the user has not said" — not '
            'an absence. Omitting the key would make it indistinguishable '
            'from a file written before meanings existed.',
      );
    });

    test('a full entry round-trips every field', () {
      final settings = _reread(
        _docWithLink(
          convention: {
            const JacketColorId('jc.grey'): const JacketColorDef(
              displayName: 'Grey',
              abbr: 'GRY',
              color: Rgb(0x9A, 0xA0, 0xA6),
              meaning: 'Wireless access point drops',
            ),
          },
        ),
      ).settings;
      final def =
          settings.jacketColorConventions[const JacketColorId(
            'jc.grey',
          )]!;
      expect(def.displayName, 'Grey');
      expect(def.abbr, 'GRY');
      expect(def.meaning, 'Wireless access point drops');
      expect(def.color, const Rgb(0x9A, 0xA0, 0xA6));
    });
  });

  group('an OLDER file decodes with NO convention — never a fabricated '
      'one (G4)', () {
    test('settings with no jacketColorConventions key decode to EMPTY', () {
      // The `?? const {}` in `_decodeProjectSettings` is what makes this
      // work at all — `asJsonMap(null, …)` throws — and this is the
      // fabrication line `migrateV1ToV2` refuses to cross: an old file's
      // author never chose a convention, so inventing seven entries for
      // them is exactly as much a guess as inventing a measurement.
      final root =
          jsonDecode(utf8.decode(_codec.write(_docWithLink())))
              as Map<String, Object?>;
      final document = root['document']! as Map<String, Object?>;
      (document['settings']! as Map<String, Object?>).remove(
        'jacketColorConventions',
      );

      final decoded = _codec.read(
        Uint8List.fromList(utf8.encode(jsonEncode(root))),
      );
      expect(
        decoded,
        isA<Ok<RackDocument>>(),
        reason:
            'a file written before this field existed must still open. '
            'Drop the `?? const {}` and this is a "damaged file" dialog '
            'for every document ever saved.',
      );
      expect(
        (decoded as Ok<RackDocument>).value.settings.jacketColorConventions,
        isEmpty,
      );
    });

    test('an entry with NO meaning key decodes to the empty meaning, not '
        'a damaged file', () {
      // `meaning` is the ONE field `JacketColorDef` declares optional
      // (`this.meaning = ''`), and the decoder required it: `asStr(null,
      // …)` throws, so a single missing key made a whole document
      // unopenable over a field whose absence and whose empty value are
      // the same fact. A hand-edited `.rmpj` and an importer that
      // knows only a name and a swatch both produce exactly this.
      //
      // MUTATION: put `asStr` back in `_decodeJacketColorDef` and this
      // is a `FormatException` instead of an `Ok`.
      final root =
          jsonDecode(
                utf8.decode(
                  _codec.write(
                    _docWithLink(
                      convention: {
                        const JacketColorId('jc.blue'): const JacketColorDef(
                          displayName: 'Blue',
                          abbr: 'BLU',
                          color: Rgb(0x1F, 0x5F, 0xA8),
                          meaning: 'Control',
                        ),
                      },
                    ),
                  ),
                ),
              )
              as Map<String, Object?>;
      final document = root['document']! as Map<String, Object?>;
      final settings = document['settings']! as Map<String, Object?>;
      final conventions =
          settings['jacketColorConventions']! as Map<String, Object?>;
      final blue = conventions['jc.blue']! as Map<String, Object?>;
      expect(blue.remove('meaning'), 'Control', reason: 'the key was there');

      final decoded = _codec.read(
        Uint8List.fromList(utf8.encode(jsonEncode(root))),
      );
      expect(
        decoded,
        isA<Ok<RackDocument>>(),
        reason:
            'one absent OPTIONAL key must not cost the user the whole '
            'document. Every other field of the entry is intact.',
      );
      final def = (decoded as Ok<RackDocument>)
          .value
          .settings
          .jacketColorConventions[const JacketColorId('jc.blue')]!;
      expect(def.meaning, '');
      expect(def.abbr, 'BLU', reason: 'the rest of the entry survives');
      expect(def.color, const Rgb(0x1F, 0x5F, 0xA8));
    });

    test('a MISSING required key is still a damaged file', () {
      // Vacuity guard on the leniency above: `displayName`, `abbr` and
      // `color` are `required` on the model and must stay strict, or the
      // fix would have quietly turned the whole entry optional and let a
      // half-written convention decode as blanks.
      final root =
          jsonDecode(
                utf8.decode(
                  _codec.write(
                    _docWithLink(
                      convention: {
                        const JacketColorId('jc.blue'): const JacketColorDef(
                          displayName: 'Blue',
                          abbr: 'BLU',
                          color: Rgb(0x1F, 0x5F, 0xA8),
                        ),
                      },
                    ),
                  ),
                ),
              )
              as Map<String, Object?>;
      final blue =
          ((((root['document']! as Map<String, Object?>)['settings']!
                        as Map<String, Object?>)['jacketColorConventions']!
                    as Map<String, Object?>)['jc.blue']!
                as Map<String, Object?>)
            ..remove('abbr');
      expect(blue.containsKey('abbr'), isFalse);

      expect(
        _codec.read(Uint8List.fromList(utf8.encode(jsonEncode(root)))),
        isNot(isA<Ok<RackDocument>>()),
      );
    });

    test('a bare ProjectSettings() carries no convention', () {
      // If the seven were a CONSTRUCTOR default, this would be seven —
      // and so would every decoded old file, because `_decodeProjectSettings`
      // and `RackDocument`s own fallback both go through here.
      expect(ProjectSettings().jacketColorConventions, isEmpty);
    });
  });

  group('the seed is DATA, not behaviour', () {
    test('it is the seven the requesting integrator named, with the '
        'meanings they gave', () {
      // Literals, on purpose. Comparing against the constant would be the
      // constant confirming itself.
      final seed = buildDefaultJacketColorConvention();
      expect(seed.keys.map((k) => k.v).toList(), [
        'jc.yellow',
        'jc.blue',
        'jc.green',
        'jc.grey',
        'jc.white',
        'jc.red',
        'jc.black',
      ]);
      expect(
        {
          for (final e in seed.entries) e.key.v: e.value.meaning,
        },
        {
          'jc.yellow': 'General data drops',
          'jc.blue': 'Control — touchscreen / IR balun / RS-232 balun',
          'jc.green': 'A/V distribution drops',
          'jc.grey': 'Wireless access point drops',
          'jc.white': 'Camera / building bridge / satellite internet',
          'jc.red': 'External feeds, security and fire',
          'jc.black': 'Direct burial and patch cables',
        },
      );
      expect(
        {for (final e in seed.entries) e.key.v: e.value.abbr},
        {
          'jc.yellow': 'YEL',
          'jc.blue': 'BLU',
          'jc.green': 'GRN',
          'jc.grey': 'GRY',
          'jc.white': 'WHT',
          'jc.red': 'RED',
          'jc.black': 'BLK',
        },
      );
    });

    test('each call returns a FRESH map — editing one project cannot '
        'repaint the next', () {
      final a = buildDefaultJacketColorConvention()
        ..clear()
        ..[const JacketColorId('jc.purple')] = const JacketColorDef(
          displayName: 'Purple',
          abbr: 'PUR',
          color: Rgb(0x6B, 0x3F, 0xA0),
        );
      final b = buildDefaultJacketColorConvention();
      expect(a, hasLength(1));
      expect(b, hasLength(7));
    });

    test('a project that deletes all seven and authors its own two KEEPS '
        'exactly those two, read back off the bytes', () {
      // THE TEST OF WHETHER SOMETHING IS REALLY DATA. Nothing may
      // re-seed, re-merge or "restore" the defaults on the way through
      // the codec.
      final doc = _docWithLink(
        jacketColorId: const JacketColorId('jc.orange'),
        convention: buildDefaultJacketColorConvention(),
      );
      doc.settings.jacketColorConventions
        ..clear()
        ..[const JacketColorId('jc.orange')] = const JacketColorDef(
          displayName: 'Orange',
          abbr: 'ORG',
          color: Rgb(0xE0, 0x6C, 0x14),
          meaning: 'Fibre to the head end',
        )
        ..[const JacketColorId('jc.violet')] = const JacketColorDef(
          displayName: 'Violet',
          abbr: 'VIO',
          color: Rgb(0x6B, 0x3F, 0xA0),
        );

      // Off the BYTES, not off the object.
      final settings = _settingsJson(doc);
      final written =
          settings['jacketColorConventions']! as Map<String, Object?>;
      // Set EQUALITY, not a containment pair. A `containsKey('jc.blue'),
      // isFalse` line sat below and could never disagree with this: any
      // state in which blue survived has already failed the equality.
      expect(written.keys.toSet(), {'jc.orange', 'jc.violet'});

      final reread = _reread(doc);
      expect(reread.settings.jacketColorConventions, hasLength(2));
      expect(
        reread
            .settings
            .jacketColorConventions[const JacketColorId(
              'jc.orange',
            )]!
            .meaning,
        'Fibre to the head end',
      );
      expect(reread.links[_linkId]!.jacketColorId?.v, 'jc.orange');
    });

    test('a project may rename and re-colour a seeded entry in place', () {
      final doc = _docWithLink(
        jacketColorId: const JacketColorId('jc.blue'),
        convention: buildDefaultJacketColorConvention(),
      );
      doc.settings.jacketColorConventions[const JacketColorId(
        'jc.blue',
      )] = const JacketColorDef(
        displayName: 'Navy',
        abbr: 'NVY',
        color: Rgb(0x0B, 0x2E, 0x5C),
        meaning: 'Building automation only — this shop, this GC',
      );

      final def = _reread(
        doc,
      ).settings.jacketColorConventions[const JacketColorId('jc.blue')]!;
      expect(def.displayName, 'Navy');
      expect(def.color, const Rgb(0x0B, 0x2E, 0x5C));
      expect(
        def.meaning,
        'Building automation only — this shop, this GC',
        reason:
            'THE SEVEN ARE ONE SHOP’S CONVENTION. Another integrator '
            'means something else by blue, and there is no industry '
            'standard for category-cable jacket colour to appeal to.',
      );
    });

    test('the seed hues are NOT the Okabe-Ito domain palette', () {
      // Reusing the signal-domain hexes would visually assert a
      // relationship between a jacket colour and a signal domain that
      // does not exist and that this design denies. Black is `#1A1A1A`
      // rather than `#000000` for the same reason: the `pwr` domain
      // draws a `#000000` line.
      const okabeIto = {
        '#E69F00',
        '#56B4E9',
        '#009E73',
        '#F0E442',
        '#0072B2',
        '#D55E00',
        '#CC79A7',
        '#000000',
      };
      for (final def in buildDefaultJacketColorConvention().values) {
        expect(
          okabeIto,
          isNot(contains(def.color.toHex())),
          reason: '${def.displayName} reuses a domain-palette hue',
        );
      }
    });
  });
}
