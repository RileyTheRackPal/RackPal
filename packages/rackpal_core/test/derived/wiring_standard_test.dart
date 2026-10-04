// DR-180 §11.179: a project states a wiring standard and a cable may
// override it, and neither is ever assumed.
//
// THE CASE THIS FILE EXISTS FOR is `a speaker run never gets a standard`.
// A project that states T568B states it once, for the whole site, and the
// obvious implementation reads that value for every cable in the document.
// A 16/4 speaker run to a ceiling pair would then print `T568B` beside a
// binding post, which is a fabricated fact about hardware that has no
// pairs to swap (G4, CR-114) and is precisely what §11.179.3 forbids.
// Every other case here is cheap; that one is the reason.
//
// The second-cheapest case that is not cheap at all is `a shop's own media
// on two patch-panel jacks`. An earlier draft of `wiring_standard.dart`
// read the `Link` alone, so it could see the media and the two
// `StructureOrigin` terminations and nothing else. That draft answers
// false for a run an installer would certainly expect a standard on, and
// it answers false SILENTLY.

import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 9, 16);
EntityMeta _meta() =>
    EntityMeta(createdAt: _at, updatedAt: _at, updatedBy: 'test');

const _rj45 = ConnectorTypeId('conn.rj45');
const _fBarrel = ConnectorTypeId('conn.f');

PortDef _portDef(String key, ConnectorTypeId connector) => PortDef(
  key: PortKey(key),
  label: key,
  connector: connector,
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  order: const FracIndex('m000'),
);

/// One staged device carrying [ports], and a document holding it.
///
/// The device is staged rather than racked because nothing here reads a
/// placement: a wiring standard is a fact about connectors.
RackDocument _doc({List<PortDef> ports = const []}) {
  final doc = RackDocument(
    id: const Uuid('doc-ws'),
    appVersion: 'test',
    createdAt: _at,
    modifiedAt: _at,
    meta: _meta(),
    info: ProjectInfo(projectName: 'wiring'),
    registries: buildSeedRegistries(),
  );
  if (ports.isEmpty) return doc;

  doc.templates['dev@1'] = TemplateSnapshot(
    templateId: const TemplateId('dev'),
    version: 1,
    contentHash: 'unhashed:dev@1',
    body: TemplateBody(
      manufacturer: 'Test',
      model: 'dev',
      displayName: 'dev',
      frontU: 1,
      side: OccupancySide.front,
      ports: ports,
    ),
    capturedAt: _at,
  );
  doc.devices[const Uuid('dev-1')] = DeviceInstance(
    id: const Uuid('dev-1'),
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('dev'),
      version: 1,
      contentHash: 'unhashed:dev@1',
    ),
    designator: 'DEV-1',
    name: 'dev',
    placement: const StagedPlacement(),
    meta: _meta(),
  );
  for (final def in ports) {
    final id = Uuid('port-${def.key.v}');
    doc.ports[id] = Port(
      id: id,
      deviceId: const Uuid('dev-1'),
      designator: def.key.v,
      templatePortKey: def.key,
    );
  }
  return doc;
}

/// A cable, added to [doc] so `wiringStandardExceptions` can see it.
Link _link(
  RackDocument doc, {
  String media = 'media.cat6',
  WiringStandard? standard,
  List<Conductor> conductors = const [],
  StructureOrigin? origin,
  String id = 'lnk',
}) {
  final link = Link(
    id: Uuid(id),
    designator: 'W001',
    media: MediaTypeId(media),
    order: const FracIndex('a0'),
    meta: _meta(),
    wiringStandard: standard,
    conductors: [...conductors],
    structureOrigin: origin,
  );
  doc.links[link.id] = link;
  return link;
}

StructureOrigin _origin({
  TerminationType? field,
  TerminationType? rack,
}) => StructureOrigin(
  structureBodyId: const Uuid('sb-1'),
  outletId: const Uuid('out-1'),
  fieldLabel: 'LR-TV-1A',
  terminationField: field,
  terminationRack: rack,
);

Conductor _toPort(String key) => Conductor(
  from: PortEndpoint(Uuid('port-$key')),
  to: const OpenEndpoint('coil'),
);

void main() {
  group('§11.179.3 — a standard is shown only where it can be true', () {
    test('a Cat6 home run qualifies on its media alone', () {
      final doc = _doc();
      expect(wiringStandardApplies(doc, _link(doc)), isTrue);
    });

    test('ALL FOUR seeded four-pair media qualify, so none is missed by a '
        'typo in the set', () {
      final doc = _doc();
      for (final media in kFourPairMediaIds) {
        expect(
          wiringStandardApplies(doc, _link(doc, media: media, id: media)),
          isTrue,
          reason: media,
        );
      }
    });

    test('a coax run with no RJ45 anywhere does NOT qualify', () {
      final doc = _doc();
      expect(
        wiringStandardApplies(doc, _link(doc, media: 'media.rg6')),
        isFalse,
      );
    });

    test('a speaker run on binding posts does NOT qualify — this is the '
        'fabricated fact the whole rule exists to prevent', () {
      final doc = _doc();
      final speaker = _link(
        doc,
        media: 'media.speaker_16_4',
        origin: _origin(
          field: TerminationType.bindingPost,
          rack: TerminationType.euroblock,
        ),
      );
      expect(wiringStandardApplies(doc, speaker), isFalse);
    });

    test('a punchdown at both ends does NOT qualify — a 66 block carries '
        'two-pair voice as readily as data', () {
      final doc = _doc();
      final voice = _link(
        doc,
        media: 'media.voice_cat3',
        origin: _origin(
          field: TerminationType.punchdown,
          rack: TerminationType.punchdown,
        ),
      );
      expect(wiringStandardApplies(doc, voice), isFalse);
    });

    test('a keystone field end qualifies a cable whose media says nothing', () {
      final doc = _doc();
      final link = _link(
        doc,
        media: 'media.house_brand',
        origin: _origin(field: TerminationType.keystone),
      );
      expect(wiringStandardApplies(doc, link), isTrue);
    });

    test('a crimped RJ45 plug at the RACK end qualifies too, so the two '
        'ends are read symmetrically', () {
      final doc = _doc();
      final link = _link(
        doc,
        media: 'media.house_brand',
        origin: _origin(rack: TerminationType.rj45Plug),
      );
      expect(wiringStandardApplies(doc, link), isTrue);
    });

    test("a shop's own media landing on an RJ45 PORT qualifies — the case a "
        'link-only rule answers false to, silently', () {
      final doc = _doc(ports: [_portDef('lan', _rj45)]);
      final link = _link(
        doc,
        media: 'media.house_brand',
        conductors: [_toPort('lan')],
      );
      expect(wiringStandardApplies(doc, link), isTrue);
    });

    test('an F barrel port does not qualify one', () {
      final doc = _doc(ports: [_portDef('rf', _fBarrel)]);
      final link = _link(
        doc,
        media: 'media.house_brand',
        conductors: [_toPort('rf')],
      );
      expect(wiringStandardApplies(doc, link), isFalse);
    });

    test('a PORT OVERRIDE to RJ45 qualifies a template F barrel, because '
        'the override is what the installer is looking at', () {
      final doc = _doc(ports: [_portDef('rf', _fBarrel)]);
      doc.ports[const Uuid('port-rf')]!.overrides.connector = _rj45;
      final link = _link(
        doc,
        media: 'media.house_brand',
        conductors: [_toPort('rf')],
      );
      expect(wiringStandardApplies(doc, link), isTrue);
    });

    test('a field end INTENDING a keystone qualifies before anything is '
        'landed', () {
      final doc = _doc();
      final link = _link(
        doc,
        media: 'media.house_brand',
        conductors: [
          const Conductor(
            from: PlaceEndpoint(
              description: 'the projector shelf, beam 3',
              intendedTermination: TerminationType.keystone,
            ),
            to: OpenEndpoint('coil'),
          ),
        ],
      );
      expect(wiringStandardApplies(doc, link), isTrue);
    });

    test('an endpoint naming a port this document does not hold answers '
        'FALSE — an unresolvable end is not evidence of an RJ45', () {
      final doc = _doc();
      final link = _link(
        doc,
        media: 'media.house_brand',
        conductors: [_toPort('nothing-here')],
      );
      expect(wiringStandardApplies(doc, link), isFalse);
    });
  });

  group('§11.179.2 — the cable first, then the job, then nothing', () {
    test('a project standard reaches a cable that states none', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      expect(effectiveWiringStandard(doc, _link(doc)), WiringStandard.t568b);
    });

    test("a cable's own word outranks the project's", () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      final link = _link(doc, standard: WiringStandard.t568a);
      expect(effectiveWiringStandard(doc, link), WiringStandard.t568a);
    });

    test('a project nobody has told prints NOTHING, not T568B', () {
      final doc = _doc();
      expect(effectiveWiringStandard(doc, _link(doc)), isNull);
    });

    test('a speaker run gets null even when the project HAS stated one', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      final speaker = _link(doc, media: 'media.speaker_16_4');
      expect(effectiveWiringStandard(doc, speaker), isNull);
    });

    test('a speaker run carrying a stale override still gets null, because '
        'the override does not make it a four-pair cable', () {
      final doc = _doc();
      final speaker = _link(
        doc,
        media: 'media.speaker_16_4',
        standard: WiringStandard.t568a,
      );
      expect(effectiveWiringStandard(doc, speaker), isNull);
    });
  });

  group("§11.179.4 — an exception is T5.01's trigger", () {
    test('a cable agreeing with the project is not an exception', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      final link = _link(doc, standard: WiringStandard.t568b);
      expect(wiringStandardIsException(doc, link), isFalse);
    });

    test('a cable differing from the project IS one', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      final link = _link(doc, standard: WiringStandard.t568a);
      expect(wiringStandardIsException(doc, link), isTrue);
    });

    test('a cable stating a standard in a project that states NONE is not '
        'an exception — there is no default for it to be non-', () {
      final doc = _doc();
      final link = _link(doc, standard: WiringStandard.t568a);
      expect(wiringStandardIsException(doc, link), isFalse);
    });

    test('a cable with no override is never one', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      expect(wiringStandardIsException(doc, _link(doc)), isFalse);
    });

    test('a speaker run with a stale override is not one either', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      final speaker = _link(
        doc,
        media: 'media.speaker_16_4',
        standard: WiringStandard.t568a,
      );
      expect(wiringStandardIsException(doc, speaker), isFalse);
    });

    test('the document-level list holds exactly the cables that differ', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      _link(doc, id: 'agrees', standard: WiringStandard.t568b);
      _link(doc, id: 'silent');
      final odd = _link(doc, id: 'differs', standard: WiringStandard.t568a);
      expect(wiringStandardExceptions(doc), [odd]);
    });

    test('a project with no stated standard has no exceptions at all, '
        'however many cables state one', () {
      final doc = _doc();
      _link(doc, id: 'a', standard: WiringStandard.t568a);
      _link(doc, id: 'b', standard: WiringStandard.t568b);
      expect(wiringStandardExceptions(doc), isEmpty);
    });
  });

  group('what a sheet prints', () {
    test('the two labels are the ones docs/08 §3.3 prints', () {
      expect(wiringStandardLabel(WiringStandard.t568a), 'T568A');
      expect(wiringStandardLabel(WiringStandard.t568b), 'T568B');
    });

    ScheduleEntry rowFor(RackDocument doc, String id) => buildSchedule(
      doc,
    ).rows.firstWhere((r) => r.linkId == Uuid(id));

    test('§3.3 column 11 carries the standard beside the termination, '
        'which is the sentence §11.179.4 rules', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      _link(doc, origin: _origin(field: TerminationType.keystone));
      expect(rowFor(doc, 'lnk').fieldTermCell, 'KEYSTONE T568B');
    });

    test('and a PUNCHDOWN keeps its punch position welded to its type, '
        'with the standard behind both', () {
      // `PUNCHDOWN A03` is one thing an installer reads at the panel.
      // This case is here so a later tidy that "puts the standard beside
      // the type" literally has to change a test rather than a habit.
      //
      // RACK TERM SINCE DR-055 WAS BUILT (`#693`): a punch position is a
      // hole in a panel, so it is the rack end's, and this case was always
      // about the rack end. It read the field end's type beside the rack
      // end's hole while one TERM cell carried both.
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568a;
      final link = _link(doc, origin: _origin(rack: TerminationType.punchdown))
        ..conductors.add(_toPort('lan'));
      expect(link.conductors, hasLength(1));
      expect(rowFor(doc, 'lnk').rackTermCell, startsWith('PUNCHDOWN'));
      expect(rowFor(doc, 'lnk').rackTermCell, endsWith('T568A'));
    });

    test('a EUROBLOCK on a four-pair run prints NO standard, which is '
        '§11.179.3 one end down', () {
      // The cable qualifies (Cat6), so `effectiveWiringStandard` answers.
      // This end still has no pins to order, and `EUROBLOCK T568B` would
      // be the fabrication the ruling exists to stop.
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      _link(doc, origin: _origin(field: TerminationType.euroblock));
      expect(rowFor(doc, 'lnk').fieldTermCell, 'EUROBLOCK');
    });

    test('a project that has stated nothing prints the termination alone', () {
      final doc = _doc();
      _link(doc, origin: _origin(field: TerminationType.keystone));
      expect(rowFor(doc, 'lnk').fieldTermCell, 'KEYSTONE');
    });
  });

  group('the WIRING column shows the OVERRIDE, never the resolved value', () {
    // THE CASE THIS GROUP EXISTS FOR is the first one. A column showing
    // the effective standard would read better and would put a trap in
    // every row: the control writes what it shows, so picking the value
    // already on screen would pin that cable to a standard the project
    // might later be changed away from, silently.

    String cellFor(RackDocument doc, String id) => structureCell(
      doc,
      buildSchedule(doc).rows.firstWhere((r) => r.linkId == Uuid(id)),
      StructureColumnId.wiringStandard,
      units: UnitSystem.imperial,
    );

    test('a cable that states nothing shows the dash even when the job '
        'has stated a standard', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      _link(doc);
      expect(cellFor(doc, 'lnk'), kUnknownCell);
    });

    test('a cable that states one shows ITS value', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      _link(doc, standard: WiringStandard.t568a);
      expect(cellFor(doc, 'lnk'), 'T568A');
    });

    test('a coax run says NO RJ45 rather than a dash, because a dash here '
        'means "follows the job" and invites typing', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      _link(doc, media: 'media.rg6');
      expect(cellFor(doc, 'lnk'), kNoRj45Cell);
    });

    test('the column is optional, editable, and last in the gear menu', () {
      expect(
        kStructureOptionalColumns,
        contains(StructureColumnId.wiringStandard),
      );
      expect(
        kStructureDefaultColumns,
        isNot(contains(StructureColumnId.wiringStandard)),
      );
      expect(
        structureColumnIsEditable(StructureColumnId.wiringStandard),
        isTrue,
      );
      // APPENDED IN ORDER, `values` being the gear menu's history: WIRING
      // was last until DR-231's CROSSOVER joined after it.
      expect(
        StructureColumnId.values.sublist(StructureColumnId.values.length - 2),
        [StructureColumnId.wiringStandard, StructureColumnId.crossover],
      );
    });
  });

  group('the file, which is where G4 is actually testable', () {
    JsonMap treeOf(RackDocument doc) =>
        const JsonDocumentCodec().encodeToJsonTree(doc);

    test('UNSET WRITES NO KEY AT ALL, on either the project or the cable — '
        'an explicit null is the one spelling G4 forbids', () {
      final doc = _doc();
      _link(doc);
      final tree = treeOf(doc);
      final settings = (tree['document']! as JsonMap)['settings']! as JsonMap;
      expect(settings.containsKey('wiringStandard'), isFalse);

      final text = utf8.decode(const JsonDocumentCodec().write(doc));
      expect(text.contains('"wiringStandard"'), isFalse);
    });

    test('both keys survive a round trip when they are set', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      _link(doc, standard: WiringStandard.t568a);

      final bytes = const JsonDocumentCodec().write(doc);
      final read = const JsonDocumentCodec().read(bytes);
      expect(read, isA<Ok<RackDocument>>());
      final back = (read as Ok<RackDocument>).value;

      expect(back.settings.wiringStandard, WiringStandard.t568b);
      expect(
        back.links[const Uuid('lnk')]!.wiringStandard,
        WiringStandard.t568a,
      );
    });

    test('the bytes are stable across a write/read/write cycle (CR-117)', () {
      final doc = _doc()..settings.wiringStandard = WiringStandard.t568b;
      _link(doc, standard: WiringStandard.t568a);

      final first = const JsonDocumentCodec().write(doc);
      final back =
          (const JsonDocumentCodec().read(first) as Ok<RackDocument>).value;
      expect(const JsonDocumentCodec().write(back), first);
    });
  });
}
