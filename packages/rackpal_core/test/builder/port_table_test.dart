// The port grid's banded rows and its columns (M4-E, #176).
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

TemplateBody _body() =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D');

PortDef _port(
  String key, {
  required String order,
  String? bank,
  String? designatorHint,
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: Face.rear,
  order: FracIndex(order),
  bankKey: bank,
  designatorHint: designatorHint,
);

BankDef _bank(String key, String label) =>
    BankDef(key: key, label: label, abbr: 'AB', order: const FracIndex('a0'));

void main() {
  group('bands', () {
    test('come out in the order their first port appears, not the order '
        'the banks were declared', () {
      final body = _body()
        ..banks.addAll([_bank('b', 'Second'), _bank('a', 'First')])
        ..ports.addAll([
          _port('p1', bank: 'a', order: 'a0000'),
          _port('p2', bank: 'b', order: 'a0001'),
          _port('p3', bank: 'a', order: 'a0002'),
        ]);

      final table = buildPortTable(body);

      expect(table.bands.map((b) => b.title), ['First', 'Second']);
      expect(
        table.bands.first.rows.map((r) => r.port.key.v),
        ['p1', 'p3'],
        reason:
            'a bank is a run of the declared order, so its rows stay in '
            'declared order even when another bank interrupts it',
      );
    });

    test('rows are the declared order and not the list order', () {
      // `order` is a FracIndex compared as a raw string, and the list here
      // is deliberately in the wrong sequence.
      final body = _body()
        ..ports.addAll([
          _port('late', order: 'a0009'),
          _port('early', order: 'a0001'),
        ]);

      expect(
        buildPortTable(body).rows.map((r) => r.port.key.v),
        ['early', 'late'],
      );
    });

    test('ports in no bank get a band that says so', () {
      final body = _body()..ports.add(_port('p1', order: 'a0000'));
      final band = buildPortTable(body).bands.single;

      expect(band.bankKey, isNull);
      expect(band.title, 'Not in a bank');
      expect(band.isUndeclaredBank, isFalse);
    });

    test('a bank key no BankDef declares shows the key rather than hiding '
        'the rows', () {
      final body = _body()..ports.add(_port('p1', bank: 'ghost', order: 'a0'));
      final band = buildPortTable(body).bands.single;

      expect(band.isUndeclaredBank, isTrue);
      expect(
        band.title,
        'ghost',
        reason:
            'the key is the only fact there is, and it is what the user '
            'has to go and fix',
      );
    });

    test('counts what it holds', () {
      final body = _body()
        ..ports.addAll([
          _port('p1', bank: 'a', order: 'a0000'),
          _port('p2', order: 'a0001'),
        ]);
      final table = buildPortTable(body);

      expect(table.portCount, 2);
      expect(table.bands, hasLength(2));
    });
  });

  group('the DESIG column', () {
    test('numbers by declared position, through the project format', () {
      final body = _body()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
        ]);

      expect(
        buildPortTable(body).rows.map((r) => r.designator),
        ['J01', 'J02'],
      );
    });

    test('honours a project that numbers differently', () {
      final body = _body()..ports.add(_port('p1', order: 'a0000'));

      expect(
        buildPortTable(
          body,
          portDesignatorFormat: const IdFormat('P{PORT_SEQ:3}'),
        ).rows.single.designator,
        'P001',
      );
    });

    test('a typed designator pins, and wins over the automatic one', () {
      final body = _body()
        ..ports.add(_port('p1', order: 'a0000', designatorHint: 'HDMI-A'));
      final row = buildPortTable(body).rows.single;

      expect(row.isDesignatorPinned, isTrue);
      expect(row.designator, 'HDMI-A');
      expect(row.autoDesignator, 'J01', reason: 'still known, just not shown');
    });

    test('a cleared cell is not a pinned blank', () {
      final body = _body()
        ..ports.add(_port('p1', order: 'a0000', designatorHint: '   '));
      final row = buildPortTable(body).rows.single;

      expect(
        row.isDesignatorPinned,
        isFalse,
        reason:
            'selecting the cell and deleting what is in it means go back '
            'to automatic, not this port is deliberately unnumbered',
      );
      expect(row.designator, 'J01');
    });

    test('a format the template cannot satisfy reads UNKNOWN, never a '
        'fabricated number', () {
      final body = _body()..ports.add(_port('p1', order: 'a0000'));

      // The commercial preset canon names. `DEV_BLOCK` is a project fact
      // and reserve-block allocation is not implemented anywhere here.
      final row = buildPortTable(
        body,
        portDesignatorFormat: const IdFormat('{DEV_BLOCK}{PORT_SEQ:2}'),
      ).rows.single;

      expect(row.autoDesignator, isNull);
      expect(
        row.designator,
        isNull,
        reason:
            'rendering 01 by pretending the block is zero would put an '
            'invented identifier in front of somebody about to print a '
            'termination schedule (G4)',
      );
    });

    test('a format that renders one string for every port numbers the '
        'first and gives up honestly on the second', () {
      // `"J"` has no PORT_SEQ in it, so the allocator has nothing left to
      // hand the second port. The table allocates across the whole
      // template exactly as one device allocates across its own pins,
      // which is the only reason this is visible at all: allocating each
      // row against an empty set would have printed `J` sixty-eight
      // times and called it a numbering.
      final body = _body()
        ..ports.addAll([
          _port('p1', order: 'a0000'),
          _port('p2', order: 'a0001'),
        ]);

      expect(
        buildPortTable(
          body,
          portDesignatorFormat: const IdFormat('J'),
        ).rows.map((r) => r.autoDesignator),
        ['J', null],
      );
    });
  });

  group('the columns', () {
    test('every one has a header and a usable width', () {
      for (final id in PortColumnId.values) {
        expect(portColumnHeader(id), isNotEmpty);
        expect(portColumnWidth(id), greaterThan(0));
      }
    });

    test('no two headers collide, because a header is what a user reads '
        'the column by', () {
      final headers = [
        for (final id in PortColumnId.values) portColumnHeader(id),
      ];
      expect(headers.toSet(), hasLength(headers.length));
    });

    test('no header cites the corpus at the user', () {
      // The same gate M4-D's form earned the hard way, one package down.
      final citation = RegExp(r'\b(CR-\d|AC-\d|DR-\d|RJ-\d|§)');
      for (final id in PortColumnId.values) {
        expect(citation.hasMatch(portColumnHeader(id)), isFalse);
      }
    });
  });

  group('the CONNECTOR and SIGNAL cells', () {
    final registries = Registries(
      connectorTypes: {
        const ConnectorTypeId('conn.hdmi_a'): const ConnectorTypeDef(
          id: ConnectorTypeId('conn.hdmi_a'),
          displayName: 'HDMI Type A',
        ),
      },
      signalFamilies: {
        const SignalFamilyId('video.hdmi.2_0'): const SignalFamilyDef(
          id: SignalFamilyId('video.hdmi.2_0'),
          displayName: 'HDMI 2.0',
          domain: SignalDomainId('video.digital'),
          defaultConnector: ConnectorTypeId('conn.hdmi_a'),
          defaultDirection: PortDirection.bidirectional,
          defaultTopology: PortTopology.p2p,
        ),
      },
    );

    test('print the trade name and not our id', () {
      expect(
        portConnectorText(registries, const ConnectorTypeId('conn.hdmi_a')),
        'HDMI Type A',
      );
      expect(
        portFamilyText(registries, const SignalFamilyId('video.hdmi.2_0')),
        'HDMI 2.0',
      );
    });

    test('an unset connector is UNKNOWN, not an empty cell', () {
      expect(portConnectorText(registries, const ConnectorTypeId('')), isNull);
      expect(portFamilyText(registries, const SignalFamilyId('   ')), isNull);
    });

    test('an id the registry does not hold prints the id, so the row '
        'stays on screen and the fault stays visible', () {
      expect(
        portConnectorText(registries, const ConnectorTypeId('conn.invented')),
        'conn.invented',
      );
      expect(
        portFamilyText(registries, const SignalFamilyId('video.invented')),
        'video.invented',
      );
    });
  });

  group('the seven packs', () {
    test('every column belongs to exactly one pack, or to none and is '
        'therefore core', () {
      final grouped = <PortColumnId>{
        ...portCoreColumns,
        for (final pack in PortColumnPack.values) ...portColumnsIn(pack),
      };

      expect(
        grouped,
        hasLength(PortColumnId.values.length),
        reason: 'a column in no pack and not core would never be drawn',
      );
    });

    test('the core columns are the ten docs/06 §4.5 lists', () {
      expect(portCoreColumns, hasLength(10));
      expect(portCoreColumns.first, PortColumnId.portKey);
      expect(portCoreColumns.last, PortColumnId.notes);
    });

    test('opening a pack appends its columns after the core ones, '
        'together', () {
      final visible = portVisibleColumns({PortColumnPack.network});

      expect(visible.take(10), portCoreColumns);
      expect(visible.skip(10), portColumnsIn(PortColumnPack.network));
    });

    test('a pack keeps its columns adjacent even with two open', () {
      final visible = portVisibleColumns({
        PortColumnPack.advanced,
        PortColumnPack.electrical,
      });
      final first = visible.indexOf(PortColumnId.impedanceOhms);
      final last = visible.indexOf(PortColumnId.maxCurrentMa);

      expect(
        last - first,
        portColumnsIn(PortColumnPack.electrical).length - 1,
        reason: 'a pack arrives as a block or the gear menu is a lie',
      );
    });

    test('every pack column has a header and a width too', () {
      for (final id in PortColumnId.values) {
        expect(portColumnHeader(id), isNotEmpty);
        expect(portColumnWidth(id), greaterThan(0));
      }
    });
  });

  group('auto-reveal', () {
    final registries = Registries(
      signalFamilies: {
        for (final (id, domain) in [
          ('net.ethernet', 'net'),
          ('audio.analog.line', 'audio.analog'),
          ('control.rs232', 'ctl'),
          ('power.ac_iec', 'pwr'),
          ('video.hdmi.2_0', 'video.digital'),
        ])
          SignalFamilyId(id): SignalFamilyDef(
            id: SignalFamilyId(id),
            displayName: id,
            domain: SignalDomainId(domain),
            defaultConnector: const ConnectorTypeId('conn.rj45'),
            defaultDirection: PortDirection.bidirectional,
            defaultTopology: PortTopology.p2p,
          ),
      },
    );

    PortDef familyPort(String family, String order) => PortDef(
      key: PortKey(order),
      label: '',
      connector: const ConnectorTypeId('conn.rj45'),
      signalFamily: SignalFamilyId(family),
      face: Face.rear,
      order: FracIndex(order),
    );

    test('a switch bank shows the Network pack, which is §4.5 verbatim', () {
      expect(
        autoRevealedPacks([familyPort('net.ethernet', 'a0')], registries),
        {PortColumnPack.network},
      );
    });

    test('control shows Serial AND Bus, because a control bank is both', () {
      expect(
        autoRevealedPacks([familyPort('control.rs232', 'a0')], registries),
        {
          PortColumnPack.serial,
          PortColumnPack.bus,
        },
      );
    });

    test('HDMI reveals nothing, because none of the seven holds a field a '
        'person would fill in for it', () {
      expect(
        autoRevealedPacks([familyPort('video.hdmi.2_0', 'a0')], registries),
        isEmpty,
      );
    });

    test('the DOMINANT family decides, not the first one', () {
      final ports = [
        familyPort('video.hdmi.2_0', 'a0'),
        familyPort('net.ethernet', 'a1'),
        familyPort('net.ethernet', 'a2'),
      ];

      expect(autoRevealedPacks(ports, registries), {PortColumnPack.network});
    });

    test('a tie resolves the same way twice, because sorting here is '
        'total', () {
      final ports = [
        familyPort('net.ethernet', 'a0'),
        familyPort('power.ac_iec', 'a1'),
      ];

      final first = autoRevealedPacks(ports, registries);
      final second = autoRevealedPacks(ports.reversed, registries);
      expect(first, second);
    });

    test('Passthrough follows the DEVICE, never a bank', () {
      // docs/06 §4.6: with `isPassthrough` on, the grid gains the paired
      // column. A patch panel's pairing is a fact about the device.
      expect(
        autoRevealedPacks(
          [familyPort('net.ethernet', 'a0')],
          registries,
          isPassthrough: true,
        ),
        {PortColumnPack.network, PortColumnPack.passthrough},
      );
    });

    test('Advanced is never revealed by itself', () {
      for (final family in [
        'net.ethernet',
        'audio.analog.line',
        'control.rs232',
        'power.ac_iec',
      ]) {
        expect(
          autoRevealedPacks([familyPort(family, 'a0')], registries),
          isNot(contains(PortColumnPack.advanced)),
        );
      }
    });

    test('a family the registries do not hold reveals nothing rather than '
        'guessing', () {
      expect(
        autoRevealedPacks([familyPort('who.knows', 'a0')], registries),
        isEmpty,
      );
    });
  });

  group('GENDER is gated on the connector, not on the value', () {
    final registries = Registries(
      connectorTypes: {
        const ConnectorTypeId('conn.xlr3'): const ConnectorTypeDef(
          id: ConnectorTypeId('conn.xlr3'),
          displayName: 'XLR 3-pin',
          genderApplies: true,
        ),
        const ConnectorTypeId('conn.rj45'): const ConnectorTypeDef(
          id: ConnectorTypeId('conn.rj45'),
          displayName: 'RJ45',
        ),
      },
    );

    test('an XLR has a gender and an RJ45 does not (CR-059)', () {
      expect(
        portGenderApplies(registries, const ConnectorTypeId('conn.xlr3')),
        isTrue,
      );
      expect(
        portGenderApplies(registries, const ConnectorTypeId('conn.rj45')),
        isFalse,
      );
    });

    test('an unknown connector is not licence to record a gender', () {
      expect(
        portGenderApplies(registries, const ConnectorTypeId('conn.invented')),
        isFalse,
      );
    });
  });

  group('the DIRECTION vocabulary', () {
    test('spells five values, and no two the same', () {
      final labels = [
        for (final d in PortDirection.values) portDirectionLabel(d),
      ];

      expect(labels, hasLength(5));
      expect(
        labels.toSet(),
        hasLength(5),
        reason:
            'CR-060 exists because a notation collapsed busNode and '
            'passive into one letter and broke DIR-002, BUS-001 and '
            'BUS-002 across the whole catalog',
      );
    });

    test('says what an installer says, not what the model says', () {
      expect(portDirectionLabel(PortDirection.sink), 'Input');
      expect(portDirectionLabel(PortDirection.source), 'Output');
      expect(portFaceLabel(Face.rear), 'Rear');
    });
  });
}
