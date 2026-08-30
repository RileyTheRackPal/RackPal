// `#244`, DR-104 §11.103.5: search over port signal families, not just
// text.
//
// THE REQUIREMENT IS A NEGATIVE AND THAT IS WHY IT NEEDS A TEST. `#244`
// states it as one: typing `hdbaset` must surface every template with an
// HDBaseT port **EVEN WHEN THE WORD IS ABSENT FROM ITS NAME**. So every
// fixture below whose ports carry a family is deliberately named
// something the query does not appear in; a fixture called
// `HDBaseT Extender` would pass against a matcher that only reads names,
// which is the matcher this replaces.
//
// AND THE CHANGE IS ADDITIVE, WHICH IS ALSO UNDER TEST. The palette's
// search is the subject of an unrun stopwatch drill (`#251`), so no query
// that matched before may stop matching. The `nothing narrows` group
// pins the five original fields.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

TemplateBody _body({
  String name = 'Thing',
  String model = '',
  String category = '',
  String? typePrefix,
  List<String> tags = const [],
  List<PortDef> ports = const [],
}) => TemplateBody(
  manufacturer: 'Generic',
  model: model,
  displayName: name,
  category: category,
  typePrefix: typePrefix,
  tags: tags,
  frontU: 1,
  ports: ports,
);

PortDef _port(String family, {String connector = 'conn.rj45'}) => PortDef(
  key: PortKey('p-$family'),
  label: 'P',
  order: const FracIndex('a0'),
  connector: ConnectorTypeId(connector),
  signalFamily: SignalFamilyId(family),
  direction: PortDirection.sink,
  face: Face.rear,
  position: const PanelPosition(
    ruOffset: 0,
    xTwelfth: 0,
    xFineNm: Len.zero,
    yFineNm: Len.zero,
  ),
  // `topology` and `maxConnections` are LEFT AT THEIR DEFAULTS. Neither
  // is read by the matcher, so naming them would be a value this fixture
  // did not choose and the analyzer would be right to say so.
);

PlaceableTemplate _row(TemplateBody body, {String id = 'tpl.thing'}) =>
    PlaceableTemplate(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'unhashed:$id@1',
      body: body,
      provenance: TemplateProvenance.project,
    );

/// The real seeded registries, so the alias chain under test is the one
/// that ships rather than one this file invented.
final Registries _registries = buildSeedRegistries();

bool _matches(
  String query, {
  required TemplateBody body,
  String id = 'tpl.thing',
  bool withRegistries = true,
}) => buildTemplateSearchEntry(
  _row(body, id: id),
  registries: withRegistries ? _registries : null,
).matches(query);

void main() {
  group('nothing narrows (DR-104 §11.103.5)', () {
    // The five fields the private matcher read. `#251` measures this
    // search with a stopwatch and has not been run, so every one of
    // these must keep working exactly as it did.
    test('the template id still matches', () {
      expect(_matches('v01', body: _body(), id: 'V01'), isTrue);
    });

    test('the display name still matches', () {
      expect(_matches('matrix', body: _body(name: 'HDMI Matrix')), isTrue);
    });

    test('the type prefix still matches', () {
      expect(_matches('mtx', body: _body(typePrefix: 'MTX')), isTrue);
    });

    test('the category still matches', () {
      expect(_matches('audio', body: _body(category: 'Audio')), isTrue);
    });

    test('a tag still matches', () {
      expect(_matches('4k60', body: _body(tags: ['4k60'])), isTrue);
    });

    test('an empty query matches everything', () {
      expect(_matches('', body: _body()), isTrue);
      expect(_matches('   ', body: _body()), isTrue);
    });

    test('a query matching nothing still matches nothing', () {
      expect(_matches('zzzznotathing', body: _body(name: 'Amp')), isFalse);
    });
  });

  group('the model string (#244)', () {
    // `#244` names this outright: "16x16 matches the model string". It
    // was in none of the five fields, so a person typing the number on
    // the front of the box matched nothing.
    test('16x16 matches a model the name does not contain', () {
      expect(
        _matches(
          '16x16',
          body: _body(name: 'Matrix Switcher', model: '16x16'),
        ),
        isTrue,
      );
    });

    test('the manufacturer matches too', () {
      expect(_matches('generic', body: _body()), isTrue);
    });
  });

  group('port signal families (#244, the requirement)', () {
    // NAMED SO THE WORD IS ABSENT. A fixture called `HDBaseT Extender`
    // would pass against the matcher this replaces.
    TemplateBody extender() =>
        _body(name: 'Long Cable Sender', ports: [_port('video.hdbaset')]);

    test('hdbaset finds it through the port, not the name', () {
      expect(_matches('hdbaset', body: extender()), isTrue);
      // The control: the word really is absent from every text field.
      expect(extender().displayName.toLowerCase().contains('hdbaset'), isFalse);
    });

    test('a PREFIX of the family finds it, because a box filters', () {
      // `resolveSignalFamilyToken` is EXACT and would refuse `hdb`;
      // `SignalFamilyCellOption.matches` is substring and must not.
      // A search that only matched what was already spelled correctly is
      // a search for people who do not need one.
      expect(_matches('hdb', body: extender()), isTrue);
    });

    test('hdbt lands, and ONLY through the registry alias', () {
      // DR-060 §11.59.4 authored `hdbt` precisely because it is docs/06
      // §4.1's own spelling and matched no step of the chain. It is not
      // a substring of `video.hdbaset`, so this is the one case that
      // proves the registry is being read at all.
      expect(_matches('hdbt', body: extender()), isTrue);
      expect(
        _matches('hdbt', body: extender(), withRegistries: false),
        isFalse,
        reason: 'without a registry there is no alias chain to walk',
      );
    });

    test('the raw ids work with no registry at all', () {
      expect(
        _matches('hdbaset', body: extender(), withRegistries: false),
        isTrue,
      );
    });

    test('a template with no such port does NOT match', () {
      // The half that makes the others mean something.
      expect(
        _matches('hdbaset', body: _body(ports: [_port('audio.dante')])),
        isFalse,
      );
    });

    test('dante finds a Dante port', () {
      expect(
        _matches('dante', body: _body(ports: [_port('audio.dante')])),
        isTrue,
      );
    });

    test('a connector id matches, so has HDMI is answerable', () {
      expect(
        _matches(
          'hdmi',
          body: _body(
            name: 'Display Sink',
            ports: [_port('video.digital', connector: 'conn.hdmi_a')],
          ),
        ),
        isTrue,
      );
    });

    test('a carried protocol matches', () {
      final body = _body(name: 'Extender', ports: [_port('video.hdbaset')]);
      body.ports.single.carriedProtocols.add(
        const SignalFamilyId('net.ethernet'),
      );
      expect(_matches('ethernet', body: body), isTrue);
    });
  });

  group('the normalisation both sides share', () {
    test('separators are ignored in the query', () {
      final body = _body(name: 'Sender', ports: [_port('video.hdbaset')]);
      for (final q in ['hd-baset', 'hd baset', 'HD_BASET', 'HDBaseT']) {
        expect(_matches(q, body: body), isTrue, reason: q);
      }
    });

    test('a template with no ports has an empty port key and still works', () {
      // The plain half must not be affected by an empty port key: an
      // empty `contains` would match everything.
      final body = _body(name: 'Blank Panel');
      expect(_matches('blank', body: body), isTrue);
      expect(_matches('hdbaset', body: body), isFalse);
    });
  });

  group('searchPlaceableTemplates', () {
    test('it filters and preserves order', () {
      final rows = [
        _row(_body(name: 'Amp'), id: 'A01'),
        _row(
          _body(name: 'Sender', ports: [_port('video.hdbaset')]),
          id: 'V06',
        ),
        _row(_body(name: 'Blank'), id: 'X01'),
      ];
      final hit = searchPlaceableTemplates(
        rows,
        'hdbaset',
        registries: _registries,
      );
      expect(hit.map((r) => r.id), ['V06']);
      expect(
        searchPlaceableTemplates(rows, '', registries: _registries),
        hasLength(3),
      );
    });
  });

  group('against the real seeded catalog', () {
    // The end-to-end claim, on the 48 templates that actually ship.
    test('hdbaset surfaces the seeded extenders through their ports', () {
      final rows = [
        for (final e in buildSeedCatalog().entries)
          PlaceableTemplate(
            templateId: TemplateId(e.key),
            version: 1,
            contentHash: 'sha256:seed-${e.key}',
            body: e.value,
            provenance: TemplateProvenance.seeded,
          ),
      ];
      final hits = searchPlaceableTemplates(
        rows,
        'hdbaset',
        registries: _registries,
      );
      expect(hits, isNotEmpty);
      // AT LEAST ONE HIT MUST BE NAMELESS FOR THE QUERY, or this passes
      // on the old matcher and proves nothing.
      expect(
        hits.any((r) => !r.body.displayName.toLowerCase().contains('hdbaset')),
        isTrue,
        reason: 'a hit found through a PORT rather than through a name',
      );
    });
  });
}
