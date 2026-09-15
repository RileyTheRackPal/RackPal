// M5-E — the twelve rules beyond the rack pair, each with its AC-051
// fixture pair.
//
// ONE KNOWN-BAD AND ONE KNOWN-GOOD PER RULE, which is M5's exit criterion
// and not a testing convention: *"No rule ships without a known-bad
// fixture and a known-good near-miss"* (docs/05 §8, AC-051). The near-miss
// is the half that costs something to write and the half that pays — M5-D's
// near-miss table found a real defect on the day it shipped, one rule along
// from the one it was written for.
//
// THE NEAR-MISSES HERE ARE MOSTLY ABOUT ABSENCE, because G4 is what these
// twelve are most exposed to. A rule that read an absent figure as zero
// would report a rack as fine, a circuit as comfortable, or a cable as
// compliant, on data nobody has entered. Each such case is a named test.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'fixtures/fixture_docs.dart';

void main() {
  final at = DateTime.utc(2026, 9, 3, 12);
  EntityMeta meta() => EntityMeta(createdAt: at, updatedAt: at, updatedBy: 't');

  late RackDocument doc;
  var seq = 0;

  Uuid nextId() {
    seq++;
    return Uuid('0190e0ee-0000-7000-8000-${seq.toString().padLeft(12, '0')}');
  }

  RackDocument build() => RackDocument(
    id: const Uuid('0190e0ee-0000-7000-8000-000000000000'),
    appVersion: '0.5.32',
    createdAt: at,
    modifiedAt: at,
    meta: meta(),
    info: ProjectInfo(projectName: 'DRC RULES'),
    registries: buildSeedRegistries(),
  );

  setUp(() {
    seq = 0;
    doc = build();
  });

  List<String> ids(String rule) => [
    for (final f in evaluateDocument(doc, only: rule)) f.ruleId,
  ];

  Finding one(String rule) => evaluateDocument(doc, only: rule).single;

  /// A link with [media], optionally a length and a jacket.
  Link wire(
    String designator, {
    required String media,
    required String family,
    Len? terminated,
    JacketListing? jacket,
    Uuid? pathwayId,
  }) {
    final link = Link(
      id: nextId(),
      designator: designator,
      media: MediaTypeId(media),
      order: FracIndex('a$seq'),
      conductors: [
        const Conductor(
          role: 'pair',
          from: OpenEndpoint('a'),
          to: OpenEndpoint('b'),
        ),
      ],
      services: [
        Service(
          id: 'svc-$seq',
          signalFamily: SignalFamilyId(family),
          netId: nextId(),
        ),
      ],
      meta: meta(),
    );
    if (terminated != null) link.terminatedLength = terminated;
    if (jacket != null) link.jacket = jacket;
    if (pathwayId != null) link.pathwayId = pathwayId;
    doc.links[link.id] = link;
    return link;
  }

  Len metres(num m) => Len.fromMillimetres(m * 1000);

  /// An Ethernet home run from a pinned rack to an outlet pinned
  /// [pinAt] metres away, on a plan calibrated at one metre per pixel.
  ///
  /// UNMEASURED BY DEFAULT, which is the state the plan floor is about:
  /// `knownLengthOf` outranks it whenever a length exists, so a fixture
  /// with one would be testing the ladder rather than the floor.
  ///
  /// The medium is `media.cat6`, matching the group's other cases. It
  /// declares its own passive limit, so these documents arm `LEN-002`
  /// too; every assertion here scopes to one rule through [one] and
  /// [ids], exactly as the measured cases above do.
  Link planBoundedEthernet(
    String designator, {
    required int pinAt,
    Len? terminated,
  }) {
    const underlayId = Uuid('ul-drc');
    doc.underlays[underlayId] = PlanUnderlay(
      id: underlayId,
      name: 'Level 1',
      imageMember: 'underlays/level-1.png',
      format: PlanImageFormat.png,
      pixelWidth: 400,
      pixelHeight: 300,
      contentHash: 'sha256:ul',
      order: const FracIndex('a0'),
      meta: meta(),
      // ONE METRE PER PIXEL, so the pin coordinate IS the distance and
      // the arithmetic is not what these cases are about.
      scale: PlanScale(
        a: const PxPt(0, 0),
        b: const PxPt(1, 0),
        distance: metres(1),
      ),
    );

    final rackId = nextId();
    doc.racks[rackId] = Rack(
      id: rackId,
      name: 'Head end',
      designator: 'RK-1',
      heightU: 42,
      order: const FracIndex('a0'),
      meta: meta(),
      planPin: const PlanPin(underlayId: underlayId, at: PxPt(0, 0)),
    );

    final panelId = nextId();
    doc.devices[panelId] = DeviceInstance(
      id: panelId,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('tpl.pp'),
        version: 1,
        contentHash: 'sha256:tpl.pp',
      ),
      designator: 'PP-1',
      name: 'patch panel',
      placement: RailPlacement(rackId: rackId, ruIndex: 1, face: Face.rear),
      meta: meta(),
    );
    final portId = nextId();
    doc.ports[portId] = Port(
      id: portId,
      deviceId: panelId,
      designator: '01',
    );

    final outletId = nextId();
    doc.outlets[outletId] = Outlet(
      id: outletId,
      structureBodyId: const Uuid('structure-drc'),
      designation: 'WP-1',
      order: const FracIndex('a0'),
      meta: meta(),
      planPin: PlanPin(underlayId: underlayId, at: PxPt(pinAt, 0)),
    );

    final link = Link(
      id: nextId(),
      designator: designator,
      media: const MediaTypeId('media.cat6'),
      order: FracIndex('a$seq'),
      conductors: [
        Conductor(
          role: 'pair',
          from: PortEndpoint(portId),
          to: const PlaceEndpoint(description: 'TV wall'),
        ),
      ],
      services: [
        Service(
          id: 'svc-plan',
          signalFamily: const SignalFamilyId('net.ethernet'),
          netId: nextId(),
        ),
      ],
      structureOrigin: StructureOrigin(
        structureBodyId: const Uuid('structure-drc'),
        outletId: outletId,
        fieldLabel: 'GR-TV-1',
      ),
      meta: meta(),
    );
    if (terminated != null) link.terminatedLength = terminated;
    doc.links[link.id] = link;
    return link;
  }

  // ═══════════════════════════════════════════════════════════════════
  group('LEN-001 — the Ethernet channel (#284)', () {
    test('KNOWN BAD: 120 m of Ethernet', () {
      wire(
        'W001',
        media: 'media.cat6',
        family: 'net.ethernet',
        terminated: metres(120),
      );
      expect(one('LEN-001').severity, Severity.error);
      expect(one('LEN-001').message, contains('120.0 m'));
    });

    test('KNOWN GOOD (near miss): 100 m exactly', () {
      // The boundary. `>` and not `>=`: a run AT the limit is a run at
      // the limit, and reporting it would flag every full-length pull.
      wire(
        'W001',
        media: 'media.cat6',
        family: 'net.ethernet',
        terminated: metres(100),
      );
      expect(ids('LEN-001'), isEmpty);
    });

    test('KNOWN GOOD (near miss): 120 m of something that is not Ethernet', () {
      wire(
        'W001',
        media: 'media.rg6',
        family: 'video.composite',
        terminated: metres(120),
      );
      expect(ids('LEN-001'), isEmpty);
    });

    test(
      'AN UNMEASURED RUN IS REPORTED, because silence reads as approval',
      () {
        // docs/02 §5.3 says it in five words. This is the only class of
        // tier-3 rule that fires on an ABSENCE, and it fires at `advisory`
        // so the runs nobody has walked do not bury the runs that are
        // actually too long.
        wire('W001', media: 'media.cat6', family: 'net.ethernet');
        // THE SAME SEVERITY AS THE MEASURED CASE, which is the catalogue's
        // and not the predicate's to choose. The first draft stamped
        // `advisory` here on a nice argument that is not in docs/02 §5.3,
        // and the evaluator overwrote it — `projectSeverity` is the single
        // place severity is decided, so the message is what distinguishes
        // an unverifiable run from a long one.
        expect(one('LEN-001').severity, Severity.error);
        expect(one('LEN-001').message, contains('no measured length'));
        expect(one('LEN-001').message, contains('cannot be verified'));
      },
    );

    // ═════════════════════════════════════════════════════════════════
    // THE PLAN FLOOR, IN THE ONE DIRECTION IT PROVES ANYTHING
    // ═════════════════════════════════════════════════════════════════
    // DR-147 §11.146.5. These two are each other's control: the SAME
    // unmeasured run, on the SAME calibrated plan, with the outlet's pin
    // moved. Over the limit it is a violation; under it, it is still a
    // run nobody has verified. A rule that fed the floor into
    // `knownLengthOf` would report the second as fine, which is the
    // compliance claim a plan may never make.
    test('KNOWN BAD: unmeasured, but the plan floor is already 120 m', () {
      planBoundedEthernet('W001', pinAt: 120);

      final f = one('LEN-001');
      expect(f.severity, Severity.error, reason: 'the catalogue decides');
      expect(f.message, contains('120.0 m'));
      expect(f.message, contains('unmeasured'));
      expect(
        f.message,
        isNot(contains('cannot be verified')),
        reason: 'the plan HAS verified it, in the only direction it can',
      );
    });

    test('KNOWN GOOD (near miss): the same run with an 80 m floor is '
        'still unverified, not passed', () {
      planBoundedEthernet('W001', pinAt: 80);

      final f = one('LEN-001');
      expect(f.message, contains('no measured length'));
      expect(f.message, contains('cannot be verified'));
      expect(
        f.message,
        isNot(contains('80')),
        reason: 'a floor under the limit proves nothing and is not quoted',
      );
    });

    test('a floor EXACTLY at the limit takes the boundary the measured '
        'case takes', () {
      planBoundedEthernet('W001', pinAt: 100);
      expect(one('LEN-001').message, contains('cannot be verified'));
    });

    test('a MEASURED run ignores the plan entirely, however long the '
        'floor is', () {
      // The floor is 120 m and the wall says 40 m. `knownLengthOf` wins
      // and the rule is silent: a measured length is a fact and a floor
      // is a floor, and this is the one case that could confuse them.
      planBoundedEthernet('W001', pinAt: 120, terminated: metres(40));
      expect(ids('LEN-001'), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  group('LEN-002 — the media type declares its own maximum (#763)', () {
    /// A media type that DOES declare a limit, found rather than named.
    ///
    /// DR-020 makes this rule *"generic by construction"*: seven of the
    /// 38 shipped types declare a `maxRunLengthPassive` and the rule is
    /// silent on the other thirty-one. Naming one here would make the
    /// test a statement about that row rather than about the rule.
    MapEntry<MediaTypeId, MediaTypeDef> limited() => doc
        .registries
        .mediaTypes
        .entries
        .firstWhere((e) => e.value.maxRunLengthPassive != null);

    test('KNOWN BAD: a run past its own medium/s limit', () {
      final m = limited();
      wire(
        'W001',
        media: m.key.v,
        family: 'net.ethernet',
        terminated: Len(m.value.maxRunLengthPassive!.nm * 2),
      );
      expect(one('LEN-002').severity, Severity.warning);
      expect(one('LEN-002').message, contains(m.value.displayName));
    });

    test('KNOWN GOOD (near miss): the same run at exactly the limit', () {
      final m = limited();
      wire(
        'W001',
        media: m.key.v,
        family: 'net.ethernet',
        terminated: m.value.maxRunLengthPassive,
      );
      expect(ids('LEN-002'), isEmpty);
    });

    test(
      'KNOWN GOOD (near miss): a medium that declares NO limit is silent',
      () {
        // Thirty-one of the thirty-eight. A rule reading a null limit as
        // zero would report every cable in the project.
        final unlimited = doc.registries.mediaTypes.entries.firstWhere(
          (e) => e.value.maxRunLengthPassive == null,
        );
        wire(
          'W001',
          media: unlimited.key.v,
          family: 'net.ethernet',
          terminated: metres(9999),
        );
        expect(ids('LEN-002'), isEmpty);
      },
    );

    // THE FLOOR LIMB IS SHARED AND THIS IS WHERE THAT IS PROVEN. Both
    // rules call one `_floorViolation`, so a version wired into `LEN-001`
    // alone passes every case in that group and this rule silently keeps
    // reporting a run the plan has already convicted. The medium here
    // declares 100 m of its own, so one fixture arms both; the assertion
    // is that this rule names ITS OWN limit rather than the channel's.
    test('KNOWN BAD: unmeasured, and the plan floor is past the '
        "medium's own rated maximum", () {
      planBoundedEthernet('W001', pinAt: 120);

      final f = one('LEN-002');
      expect(f.severity, Severity.warning, reason: 'unchanged by the floor');
      expect(f.message, contains('120.0 m'));
      expect(f.message, contains('rated maximum'));
      expect(f.message, isNot(contains('cannot be verified')));
    });

    test('KNOWN GOOD (near miss): an 80 m floor leaves this rule '
        'unverified too', () {
      planBoundedEthernet('W001', pinAt: 80);
      expect(one('LEN-002').message, contains('cannot be verified'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  group('LNK-020 — a checklist, not a failure (#292)', () {
    test('KNOWN GOOD: nothing unlanded, nothing said', () {
      expect(ids('LNK-020'), isEmpty);
    });

    test('N unlanded ends are ONE advisory, not N of them', () {
      // The whole point of the row. Fifteen separate advisories for
      // fifteen unpulled drops would be fifteen rows a person dismisses
      // to reach the two that are errors.
      final link = wire('W001', media: 'media.cat6', family: 'net.ethernet')
        ..structureOrigin = StructureOrigin(
          structureBodyId: nextId(),
          outletId: nextId(),
          fieldLabel: 'LR-1',
        );
      link.conductors[0] = const Conductor(
        role: 'pair',
        from: PlaceEndpoint(description: 'wall'),
        to: PlaceEndpoint(description: 'wall'),
      );
      final found = evaluateDocument(doc, only: 'LNK-020');
      expect(found, hasLength(1));
      expect(found.single.severity, Severity.advisory);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  group('CODE-001 and CODE-002 — verify, do not assert (#290, #291)', () {
    Pathway pathway({
      required PathwayKind kind,
      required bool lineVoltage,
    }) {
      final p = Pathway(
        id: nextId(),
        name: 'PW-1',
        kind: kind,
        order: const FracIndex('a0'),
        meta: meta(),
        containsLineVoltage: lineVoltage,
      );
      doc.pathways[p.id] = p;
      return p;
    }

    test('CODE-001 KNOWN BAD: a Class 2 cable shares a line-voltage run', () {
      final p = pathway(kind: PathwayKind.conduit, lineVoltage: true);
      wire(
        'W001',
        media: 'media.cat6',
        family: 'net.ethernet',
        jacket: JacketListing.cl2,
        pathwayId: p.id,
      );
      final f = one('CODE-001');
      expect(f.severity, Severity.warning);
      expect(f.message, contains('725.136'));
      expect(
        f.message,
        contains('Verify'),
        reason:
            'DR-079 §11.78.3: the article permits arrangements this '
            'product does not model, so it asks rather than asserts',
      );
      // NO NAIVE `isNot(contains('violat'))` HERE, and the first draft had
      // one: the sentence ends *"so this is a check rather than a
      // violation"*, so the word appears inside its own denial and the
      // assertion failed on a message that says exactly the right thing.
      // What matters is that it asks, which the positive assertions above
      // check.
      expect(f.message, contains('rather than'));
    });

    test(
      'CODE-001 KNOWN GOOD (near miss): the same cable, no line voltage',
      () {
        final p = pathway(kind: PathwayKind.conduit, lineVoltage: false);
        wire(
          'W001',
          media: 'media.cat6',
          family: 'net.ethernet',
          jacket: JacketListing.cl2,
          pathwayId: p.id,
        );
        expect(ids('CODE-001'), isEmpty);
      },
    );

    test(
      'CODE-001 KNOWN GOOD (near miss): no listing is UNKNOWN and skips',
      () {
        // G4. A cable nobody has specified is not a Class 2 cable in a
        // line-voltage conduit; it is a cable nobody has specified.
        final p = pathway(kind: PathwayKind.conduit, lineVoltage: true);
        wire(
          'W001',
          media: 'media.cat6',
          family: 'net.ethernet',
          pathwayId: p.id,
        );
        expect(ids('CODE-001'), isEmpty);
      },
    );

    test('CODE-002 KNOWN BAD: a non-plenum listing in a plenum space', () {
      final p = pathway(kind: PathwayKind.plenumSpace, lineVoltage: false);
      wire(
        'W001',
        media: 'media.cat6',
        family: 'net.ethernet',
        jacket: JacketListing.cm,
        pathwayId: p.id,
      );
      final f = one('CODE-002');
      expect(f.severity, Severity.warning);
      expect(f.message, contains('800.154'));
      expect(
        f.message,
        contains('300.22(C)'),
        reason: 'the metal-raceway exception this product cannot see',
      );
    });

    test('CODE-002 KNOWN GOOD (near miss): a plenum listing passes', () {
      final p = pathway(kind: PathwayKind.plenumSpace, lineVoltage: false);
      wire(
        'W001',
        media: 'media.cat6',
        family: 'net.ethernet',
        jacket: JacketListing.cmp,
        pathwayId: p.id,
      );
      expect(ids('CODE-002'), isEmpty);
    });

    test('CODE-002 KNOWN GOOD (near miss): a plenum listing from ANOTHER '
        'article still passes', () {
      // `isPlenumRated` judges a listing inside its own article, which is
      // the question this rule actually asks: the cable's own listing
      // names the article it was tested under.
      final p = pathway(kind: PathwayKind.plenumSpace, lineVoltage: false);
      wire(
        'W001',
        media: 'media.cat6',
        family: 'net.ethernet',
        jacket: JacketListing.cl2p,
        pathwayId: p.id,
      );
      expect(ids('CODE-002'), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  group('PWR-001 — a planning estimate that says so (#282)', () {
    Circuit circuit({int amps = 15, int volts = 120}) {
      final c = Circuit(
        id: nextId(),
        designator: 'Panel A / Breaker 1',
        breakerAmps: amps,
        volts: volts,
        meta: meta(),
      );
      doc.circuits[c.id] = c;
      return c;
    }

    /// A device on [circuit] drawing [va], or nothing when [va] is null.
    ///
    /// THROUGH A TEMPLATE, NOT AN OVERRIDE, because `DeviceOverrides`
    /// carries `typicalWatts` and `weight` and no `apparentVA`: the VA
    /// figure lives on the template's `PowerProfile`, and
    /// `device_loads.dart` is explicit that one is never synthesised from
    /// the other (AC-039's neighbour). A fixture that faked it through an
    /// override would be exercising a path the product does not have.
    void load(Circuit circuit, int? va, {String designator = 'AMP-1'}) {
      seq++;
      final id = 'LOAD$seq';
      doc.templates[templateKey(id, 1)] = TemplateSnapshot(
        templateId: TemplateId(id),
        version: 1,
        contentHash: 'sha256:$id',
        body: TemplateBody(
          manufacturer: 'Generic',
          model: id,
          displayName: 'load',
          category: 'Audio',
          frontU: 1,
          rearU: 1,
          side: OccupancySide.both,
          power: PowerProfile(apparentVA: va),
          ports: const [],
          banks: const [],
        ),
        capturedAt: at,
      );
      final device = DeviceInstance(
        id: nextId(),
        kind: DeviceKind.rackDevice,
        templateRef: TemplateRef(
          templateId: TemplateId(id),
          version: 1,
          contentHash: 'sha256:$id',
        ),
        designator: designator,
        name: 'load',
        placement: const OffRackPlacement(),
        meta: meta(),
      );
      doc.devices[device.id] = device;
      final port = Port(
        id: nextId(),
        deviceId: device.id,
        designator: 'P1',
      )..circuitId = circuit.id;
      doc.ports[port.id] = port;
    }

    test('KNOWN BAD: over 80% of the breaker', () {
      final c = circuit();
      // 15 A x 120 V = 1800 VA; the continuous allowance is 12 A = 1440.
      load(c, 1600);
      final f = one('PWR-001');
      expect(f.severity, Severity.warning);
      expect(
        f.message,
        contains('planning estimate'),
        reason:
            'DR-079 §11.78.4: it names the circuit to look at first '
            'and asserts nothing about NEC',
      );
      expect(f.message, contains('rather than treating it as a code'));
    });

    test('KNOWN GOOD (near miss): exactly at the allowance', () {
      final c = circuit();
      load(c, 1440);
      expect(ids('PWR-001'), isEmpty);
    });

    test('AN UNKNOWN DRAW IS NAMED, never summed as zero (G4)', () {
      final c = circuit();
      load(c, 1600);
      load(c, null, designator: 'AMP-2');
      final f = one('PWR-001');
      expect(
        f.message,
        contains('AMP-2'),
        reason:
            'a rollup reports its unknown count rather than '
            'fabricating a total (CR-114)',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  group('PWR-003 — outlets consumed exceed outlets provided (#283)', () {
    test('KNOWN BAD and KNOWN GOOD, from one catalog fact', () {
      // A01 consumes an outlet and provides none; P02 is a PDU. The bad
      // case is the amp alone; the good case is the amp with the PDU.
      final rackId = nextId();
      doc.racks[rackId] = Rack(
        id: rackId,
        name: 'R',
        designator: 'RK-1',
        heightU: 12,
        order: const FracIndex('a0'),
        meta: meta(),
      );
      final catalog = buildSeedCatalog();
      void put(String id, int ru) {
        doc.templates[templateKey(id, 1)] = TemplateSnapshot(
          templateId: TemplateId(id),
          version: 1,
          contentHash: 'sha256:seed-$id',
          body: catalog[id]!,
          capturedAt: at,
        );
        final d = DeviceInstance(
          id: nextId(),
          kind: DeviceKind.rackDevice,
          templateRef: TemplateRef(
            templateId: TemplateId(id),
            version: 1,
            contentHash: 'sha256:seed-$id',
          ),
          designator: '$id-1',
          name: catalog[id]!.displayName,
          placement: RailPlacement(
            rackId: rackId,
            ruIndex: ru,
            face: Face.front,
          ),
          meta: meta(),
        );
        doc.devices[d.id] = d;
      }

      put('A01', 1);
      expect(
        one('PWR-003').severity,
        Severity.error,
        reason:
            'an amplifier with no PDU in the rack consumes an outlet '
            'the rack does not provide',
      );

      // THE NEAR MISS IS THE SAME RACK WITH A PDU IN IT, which is the
      // fix a person would actually make.
      final pdu = catalog.entries.firstWhere(
        (e) => outletPortCount(e.value) > 0,
      );
      put(pdu.key, 8);
      expect(ids('PWR-003'), isEmpty);
    });
  });
  // ═══════════════════════════════════════════════════════════════════
  // RCK-003's THREE BANDS (M5-H2, DR-125)
  // ═══════════════════════════════════════════════════════════════════
  // The AC-051 pair asserts WHICH RULE fires and says nothing about how
  // loudly, so before this the band was the only part of RCK-003 no test
  // held. That is what let the 85% line sit unexamined until a domain
  // reviewer read it.
  group('RCK-003 speaks in three bands', () {
    Severity? severityAt(int kg) {
      final doc = fixtureDoc(weightCapacity: Mass.fromKilograms(100));
      fixturePlaceBody(
        doc,
        fixtureBody(frontU: 2, weight: Mass.fromKilograms(kg)),
        1,
        seq: 1,
        designator: 'AMP-1',
      );
      final found = evaluateDocument(doc).where((f) => f.ruleId == 'RCK-003');
      return found.isEmpty ? null : found.single.severity;
    }

    test('silent below the advisory line', () {
      expect(severityAt(59), isNull);
    });

    test('advisory from 60%, which is the band the review moved', () {
      expect(severityAt(60), Severity.advisory);
      expect(severityAt(84), Severity.advisory);
    });

    test('warning from 85%, which is where it used to start', () {
      expect(severityAt(85), Severity.warning);
      expect(severityAt(100), Severity.warning);
    });

    test('error over capacity, and it still blocks nothing (CR-022)', () {
      expect(severityAt(101), Severity.error);
    });

    test('AN OVERRIDE COLLAPSES THE BAND, which rules_rack promised', () {
      // "A project that demotes RCK-003 demotes all three." An override is
      // the project saying what this rule counts as here, so the band
      // stops applying rather than being clamped into.
      final doc = fixtureDoc(weightCapacity: Mass.fromKilograms(100));
      fixturePlaceBody(
        doc,
        fixtureBody(frontU: 2, weight: Mass.fromKilograms(70)),
        1,
        seq: 1,
        designator: 'AMP-1',
      );
      expect(
        evaluateDocument(
          doc,
        ).singleWhere((f) => f.ruleId == 'RCK-003').severity,
        Severity.advisory,
        reason: '70 of 100 kg is the advisory band',
      );
      doc.settings.ruleOverrides['RCK-003'] = RuleOverride(
        severity: Severity.error,
        reason: 'this shop stacks racks on a mezzanine',
        by: 'reviewer',
        at: at,
      );
      expect(
        evaluateDocument(
          doc,
        ).singleWhere((f) => f.ruleId == 'RCK-003').severity,
        Severity.error,
        reason: 'the override wins over the band it collapses',
      );
    });

    test('an UNBANDED rule still cannot choose its own severity', () {
      // The other direction, and the one M5-E ruled on: LEN-001 declares
      // no band, so whatever its predicate sets is discarded. A test here
      // rather than only on RCK-003, because a change to the evaluator
      // that widened banding to everything would pass every test above.
      expect(kRulesById['LEN-001']!.severityBand, isNull);
      expect(
        kRuleCatalogue
            .where((m) => m.severityBand != null)
            .map((m) => m.ruleId),
        ['RCK-003'],
        reason: 'exactly one banded row today; add deliberately',
      );
    });

    test('the advisory sentence says what to do, not just what is true', () {
      final doc = fixtureDoc(weightCapacity: Mass.fromKilograms(100));
      fixturePlaceBody(
        doc,
        fixtureBody(frontU: 2, weight: Mass.fromKilograms(70)),
        1,
        seq: 1,
        designator: 'AMP-1',
      );
      final f = evaluateDocument(
        doc,
      ).singleWhere((f) => f.ruleId == 'RCK-003');
      // The reviewer's reason for the band is a floor and some casters,
      // so the sentence names them rather than restating the percentage.
      expect(f.message, contains('casters'));
    });
  });
}
