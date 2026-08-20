// THE EXCEPTION HALF of per-run jacket colour: two stored facts, three
// derived questions, four states, none collapsed.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS FILE IS GUARDING, IN THE USER'S OWN WORDS
// ═════════════════════════════════════════════════════════════════════
// "having a way to differentiate the control wire as being yellow
// instead of blue for that run only, WHILE KEEPING THE KEYSTONES
// FOLLOWING THE NORMAL CONVENTION, would be nice. DOCUMENTATION OF
// IMPERFECTIONS BEATS NO DOCUMENTATION AT ALL."
//
// Two clauses, two separate properties, and the second one is the one a
// refactor will quietly break: `keystoneColorId` must not mention
// `pulledId`. `keystone follows the CONVENTION` below is written so that
// rewriting it to `pulledId ?? conventionId` turns this file red.
//
// ═════════════════════════════════════════════════════════════════════
// THE SELF-REFERENTIAL TRAP THIS FILE AVOIDS
// ═════════════════════════════════════════════════════════════════════
// Every convention map here is a LITERAL written in this file. Nothing
// asserts against `buildDefaultJacketColorConvention()` — that would be
// the constant confirming itself, the same failure mode as the
// frozen-clock timing test and the self-referential catalog assertion
// this project has already shipped. The abbreviations below (`BLU`,
// `YEL`) are deliberately the ones a schedule would print, so a test
// failure reads the way the defect would.
import 'dart:convert';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

const _blue = JacketColorId('jc.blue');
const _yellow = JacketColorId('jc.yellow');
const _grey = JacketColorId('jc.grey');
const _ghost = JacketColorId('jc.deleted_last_year');

/// A two-entry convention, stated as literals. `jc.grey` is stocked and
/// referenced by nothing, which is a state the model permits.
Map<JacketColorId, JacketColorDef> _convention() => {
  _blue: const JacketColorDef(
    displayName: 'Blue',
    abbr: 'BLU',
    color: Rgb(0x1F, 0x5F, 0xA8),
    meaning: 'Control — touchscreen / IR balun / RS-232 balun',
  ),
  _yellow: const JacketColorDef(
    displayName: 'Yellow',
    abbr: 'YEL',
    color: Rgb(0xEF, 0xC8, 0x1E),
    meaning: 'General data drops',
  ),
  _grey: const JacketColorDef(
    displayName: 'Grey',
    abbr: 'GRY',
    color: Rgb(0x9A, 0xA0, 0xA6),
    meaning: 'Wireless access point drops',
  ),
};

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 7, 27, 9),
  updatedAt: DateTime.utc(2026, 7, 27, 9),
  updatedBy: 'rriley',
);

const _linkId = Uuid('0190e3c1-cf80-75bb-96ac-d3b7ef294cab');

Link _link({JacketColorId? convention, JacketColorId? pulled}) => Link(
  id: _linkId,
  designator: 'W001',
  media: const MediaTypeId('media.cat6_utp'),
  order: const FracIndex('a0'),
  meta: _meta(),
  jacket: JacketListing.cmr,
  jacketColorId: convention,
  jacketColorPulledId: pulled,
);

RackDocument _doc({
  JacketColorId? convention,
  JacketColorId? pulled,
  Map<JacketColorId, JacketColorDef>? entries,
}) {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-0000000000ab'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026, 7, 27, 9),
    modifiedAt: DateTime.utc(2026, 7, 27, 9),
    meta: _meta(),
    settings: ProjectSettings(jacketColorConventions: entries ?? _convention()),
  );
  doc.links[_linkId] = _link(convention: convention, pulled: pulled);
  return doc;
}

/// The encoded `links[_linkId]` object — assertions about what reached
/// DISK read this, not the in-memory object that produced it.
Map<String, Object?> _linkJson(RackDocument doc) {
  final root =
      jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
  final document = root['document']! as Map<String, Object?>;
  final links = document['links']! as Map<String, Object?>;
  return links[_linkId.v]! as Map<String, Object?>;
}

RackDocument _reread(RackDocument doc) {
  final decoded = _codec.read(_codec.write(doc));
  expect(decoded, isA<Ok<RackDocument>>());
  return (decoded as Ok<RackDocument>).value;
}

void main() {
  group('QUESTION 3 — the keystone follows the CONVENTION, never the '
      'pull', () {
    // THE SINGLE MOST IMPORTANT PROPERTY IN THE CHANGE, and the one a
    // well-meaning "simplification" removes. MUTATION: rewrite
    // `ResolvedJacketColor.keystoneColorId` to `pulledId ?? conventionId`
    // (i.e. make it agree with `asBuiltColorId`) and every test in this
    // group must fail.
    test('a control run pulled in yellow still takes a BLUE keystone', () {
      final r = resolveJacketColor(
        _link(convention: _blue, pulled: _yellow),
        _convention(),
      );

      expect(
        r.keystoneColorId,
        _blue,
        reason:
            'the keystone is chosen weeks after the pull, out of the same '
            'box as every other control drop’s. It is routinely correct '
            'while the cable is not — that is the whole point of '
            'recording the exception separately.',
      );
      expect(r.keystone?.abbr, 'BLU');
      expect(r.keystone?.displayName, 'Blue');
    });

    test('and the as-built colour of that SAME run is yellow — the two '
        'answers differ, which is what proves they are two questions', () {
      // If `keystoneColorId` and `asBuiltColorId` ever return the same
      // thing for this input, one of them is wrong. Asserting the
      // INEQUALITY directly is what makes the mutation impossible to
      // pass by adjusting one expected literal.
      final r = resolveJacketColor(
        _link(convention: _blue, pulled: _yellow),
        _convention(),
      );

      expect(r.keystoneColorId, isNot(r.asBuiltColorId));
      expect(r.keystoneColorId, _blue);
      expect(r.asBuiltColorId, _yellow);
      expect(r.keystone?.abbr, 'BLU');
      expect(r.asBuilt?.abbr, 'YEL');
    });

    test('the keystone answer is unchanged by SETTING an override on a '
        'run that had none', () {
      final before = resolveJacketColor(
        _link(convention: _blue),
        _convention(),
      );
      final after = resolveJacketColor(
        _link(convention: _blue, pulled: _yellow),
        _convention(),
      );

      expect(after.keystoneColorId, before.keystoneColorId);
      expect(after.keystone?.abbr, before.keystone?.abbr);
    });

    test('a run with an override and NO convention has NO keystone answer '
        '— it is not inferred from the pull', () {
      // Inferring `keystone = yellow` here would assert "this is a
      // general data drop", which nobody has said (G4). Null is the
      // honest answer and a schedule prints `—`.
      final r = resolveJacketColor(_link(pulled: _yellow), _convention());

      expect(r.keystoneColorId, isNull);
      expect(r.keystone, isNull);
      expect(
        r.asBuiltColorId,
        _yellow,
        reason:
            'the observed physical fact is still kept — only the '
            'inference about purpose is refused',
      );
    });
  });

  group('QUESTION 1 — what colour was actually pulled', () {
    test('with no override, the as-built colour IS the convention', () {
      final r = resolveJacketColor(_link(convention: _blue), _convention());
      expect(r.asBuiltColorId, _blue);
      expect(r.asBuilt?.abbr, 'BLU');
    });

    test('with an override, the as-built colour is the OVERRIDE', () {
      // MUTATION: flip `asBuiltColorId` to `conventionId ?? pulledId`
      // and this fails — the takeoff would order blue for a run that
      // consumed yellow off the reel.
      final r = resolveJacketColor(
        _link(convention: _blue, pulled: _yellow),
        _convention(),
      );
      expect(r.asBuiltColorId, _yellow);
      expect(r.asBuilt?.abbr, 'YEL');
    });

    test('with neither, nobody has said — null, not a default', () {
      final r = resolveJacketColor(_link(), _convention());
      expect(r.asBuiltColorId, isNull);
      expect(r.asBuilt, isNull);
      expect(r.keystoneColorId, isNull);
      expect(r.isException, isFalse);
      expect(r.hasUnknownEntry, isFalse);
    });
  });

  group('QUESTION 2 — is this run an exception (BOTH limbs, tested '
      'separately)', () {
    test('LIMB 1, the null check: no override is not an exception', () {
      // MUTATION: drop `pulledId != null` from `isException` and this
      // fails — `null != _blue` is true, so every ordinary run in the
      // job would be reported as an exception.
      expect(
        resolveJacketColor(_link(convention: _blue), _convention()).isException,
        isFalse,
      );
      expect(resolveJacketColor(_link(), _convention()).isException, isFalse);
    });

    test('LIMB 2, the inequality: an override EQUAL to the convention is '
        'not an exception, even arriving from a hand-edited file', () {
      // MUTATION: drop `pulledId != conventionId` from `isException` and
      // this fails. The Command normalises this away on the WRITE path,
      // but this input never passed through a Command — it is what a
      // hand-edited `.rmpj` or a CSV import produces, and an
      // exceptions sheet must not print a `BLU — PULLED BLU` row.
      final r = resolveJacketColor(
        _link(convention: _blue, pulled: _blue),
        _convention(),
      );
      expect(r.isException, isFalse);
      expect(r.asBuiltColorId, _blue);
      expect(r.keystoneColorId, _blue);
    });

    test('differing ids ARE an exception', () {
      expect(
        resolveJacketColor(
          _link(convention: _blue, pulled: _yellow),
          _convention(),
        ).isException,
        isTrue,
      );
    });

    test('an override with no convention is an exception too', () {
      expect(
        resolveJacketColor(_link(pulled: _yellow), _convention()).isException,
        isTrue,
      );
    });

    test('an exception whose override id DANGLES is still an exception', () {
      // The two states overlap, which is exactly why there is no single
      // status enum. Something wrong went in the wall regardless of
      // whether the entry naming it still exists.
      final r = resolveJacketColor(
        _link(convention: _blue, pulled: _ghost),
        _convention(),
      );
      expect(r.isException, isTrue);
      expect(r.hasUnknownEntry, isTrue);
      expect(r.pulled, isNull);
      expect(
        r.pulledId,
        _ghost,
        reason: 'the id survives even though the entry does not',
      );
    });
  });

  group('unknown entries are COUNTED, never guessed (G4)', () {
    test('a dangling CONVENTION id resolves to a null def, not a '
        'substituted one', () {
      final r = resolveJacketColor(_link(convention: _ghost), _convention());
      expect(r.conventionId, _ghost);
      expect(r.convention, isNull);
      expect(r.hasUnknownEntry, isTrue);
      expect(
        r.keystone,
        isNull,
        reason:
            'a keystone colour nobody can name is not the first entry '
            'in the map',
      );
    });

    test('both ids resolving cleanly is NOT flagged unknown', () {
      // Vacuity guard: if `hasUnknownEntry` were `true` unconditionally
      // the assertions above would all pass.
      final r = resolveJacketColor(
        _link(convention: _blue, pulled: _yellow),
        _convention(),
      );
      expect(r.hasUnknownEntry, isFalse);
    });

    test('an EMPTY convention map leaves both ids intact and flags '
        'unknown — deleting the whole convention cannot destroy the '
        'record of what was pulled', () {
      final r = resolveJacketColor(
        _link(convention: _blue, pulled: _yellow),
        const {},
      );
      expect(r.conventionId, _blue);
      expect(r.pulledId, _yellow);
      expect(r.convention, isNull);
      expect(r.pulled, isNull);
      expect(r.hasUnknownEntry, isTrue);
      expect(r.isException, isTrue);
    });
  });

  group('THE FOUR STATES ON DISK — read off the encoded BYTES', () {
    test('state 1, neither set: NO key for either fact', () {
      final json = _linkJson(_doc());
      expect(json.containsKey('jacketColorId'), isFalse);
      expect(json.containsKey('jacketColorPulledId'), isFalse);
    });

    test('state 2, convention only: one key, and no override key at all', () {
      final json = _linkJson(_doc(convention: _blue));
      expect(json['jacketColorId'], 'jc.blue');
      expect(
        json.containsKey('jacketColorPulledId'),
        isFalse,
        reason:
            'NULL IS THE NORMAL CASE and `putIfNotNull` must write '
            'nothing for it — that is what makes every existing document '
            'encode byte-for-byte as it did before this key existed',
      );
    });

    test('state 3, both set and differing: TWO keys', () {
      final json = _linkJson(_doc(convention: _blue, pulled: _yellow));
      expect(json['jacketColorId'], 'jc.blue');
      expect(json['jacketColorPulledId'], 'jc.yellow');
      // NO ORDERING ASSERTION HERE, deliberately. Two `indexOf`
      // comparisons used to sit below, claiming the pair's adjacency in
      // the file was "deliberate". They measured nothing this file owns:
      // `encodeJsonTreeBytes` runs `deepSortKeys` over the whole tree
      // before encoding, so swapping the two `putIfNotNull` calls in
      // `_encodeLink` left them green — they restated that
      // `"jacketColorId" < "jacketColorPulledId" < "lifecycleStatus"` in
      // ASCII, a property of three string literals. The canonical sort
      // is `byte_roundtrip_test.dart`'s to guard; the two key NAMES are
      // guarded by the two assertions above.
    });

    test('state 4, override only: the override key alone, with NO '
        'fabricated convention key beside it', () {
      final json = _linkJson(_doc(pulled: _yellow));
      expect(json['jacketColorPulledId'], 'jc.yellow');
      expect(
        json.containsKey('jacketColorId'),
        isFalse,
        reason:
            'promoting the observed colour into the convention field '
            'would assert what the run is FOR, which nobody has said',
      );
    });

    test('the RATING, the CONVENTION and the PULL are three separate keys '
        'carrying three separate facts', () {
      final json = _linkJson(_doc(convention: _blue, pulled: _yellow));
      expect(json['jacket'], 'cmr');
      expect(json['jacketColorId'], 'jc.blue');
      expect(json['jacketColorPulledId'], 'jc.yellow');
    });

    test('an override never reaches disk as an explicit null', () {
      final text = utf8.decode(_codec.write(_doc(convention: _blue)));
      expect(text, isNot(contains('"jacketColorPulledId": null')));
    });
  });

  group('round trip', () {
    test('all four states survive a write/read cycle unchanged', () {
      final states = <(JacketColorId?, JacketColorId?)>[
        (null, null),
        (_blue, null),
        (_blue, _yellow),
        (null, _yellow),
      ];
      for (final (convention, pulled) in states) {
        final link = _reread(
          _doc(convention: convention, pulled: pulled),
        ).links[_linkId]!;
        expect(
          link.jacketColorId,
          convention,
          reason: 'convention $convention',
        );
        expect(link.jacketColorPulledId, pulled, reason: 'pulled $pulled');
      }
    });

    test('a DANGLING override id decodes INTACT — the one record that a '
        'wrong colour went in the wall outlives the entry naming it', () {
      // NO `containsKey(_ghost), isFalse` HERE. That assertion sat below
      // and could not fail: `_decodeProjectSettings` builds the
      // convention map solely from `json['jacketColorConventions']` and
      // `_decodeLink` never receives it, so the two share no state and no
      // decoder mutation can make a link's id manufacture an entry. The
      // live property is that the ID SURVIVES the entry, which is what
      // the two assertions here actually measure.
      final doc = _doc(convention: _blue, pulled: _ghost);
      final reread = _reread(doc);

      expect(reread.links[_linkId]!.jacketColorPulledId, _ghost);
      expect(
        resolveJacketColor(
          reread.links[_linkId]!,
          reread.settings.jacketColorConventions,
        ).isException,
        isTrue,
      );
    });
  });
}
