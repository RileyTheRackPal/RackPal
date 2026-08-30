// TSV copy and paste for the port grid (M4-F3 #210).
//
// THE ROUND TRIP IS THE TASK'S OWN TEST, in its own words: "copy a bank
// out, paste it back, byte-compare the resulting TemplateBody". It is the
// first group below and everything else exists to say why it passes.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

Registries _registries() => buildSeedRegistries();

PortDef _port(
  String key, {
  required String order,
  String? label,
  String connector = 'conn.rj45',
  String family = 'net.ethernet',
  PortDirection direction = PortDirection.sink,
  Face face = Face.rear,
  String? notes,
  int? impedance,
}) => PortDef(
  key: PortKey(key),
  label: label ?? key.toUpperCase(),
  connector: ConnectorTypeId(connector),
  signalFamily: SignalFamilyId(family),
  face: face,
  order: FracIndex(order),
  direction: direction,
  notes: notes,
  impedanceOhms: impedance,
);

TemplateBody _body(List<PortDef> ports) =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D')
      ..ports.addAll(ports);

/// The core columns, which is what the grid shows before any pack opens.
List<PortColumnId> get _columns => portVisibleColumns(const {});

void _run(TemplateBody body, List<Command<TemplateBody>> commands) {
  for (final command in commands) {
    command.apply(body);
  }
}

void main() {
  group('THE ROUND TRIP, which is what #210 asks for', () {
    test('a bank copied out and pasted back leaves the body identical', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'IN 01', notes: 'first'),
        _port(
          'p2',
          order: 'a1',
          label: 'IN 02',
          direction: PortDirection.source,
        ),
        _port(
          'p3',
          order: 'a2',
          label: 'IN 03',
          connector: 'conn.hdmi_a',
          family: 'video.hdmi.2_0',
          face: Face.front,
        ),
      ]);
      final keys = ['p1', 'p2', 'p3'];
      final registries = _registries();
      final before = const JsonDocumentCodec().write(
        _docWith(_copy(body)),
      );

      final tsv = buildPortTsv(
        body: body,
        columns: _columns,
        portKeys: keys,
        registries: registries,
      );
      final plan = parsePortTsv(
        body: body,
        text: tsv,
        columns: _columns,
        visibleRowKeys: keys,
        anchorKey: 'p1',
        anchorColumn: _columns.first,
        registries: registries,
      );
      _run(body, plan.commands);

      expect(plan.isRefused, isFalse);
      expect(
        plan.commands,
        isEmpty,
        reason:
            'every cell already holds what it was written as, so a true '
            'round trip produces no writes at all',
      );
      expect(
        const JsonDocumentCodec().write(_docWith(body)),
        before,
        reason: 'CR-117 discipline, applied to the clipboard',
      );
    });

    test('it survives Excel: CRLF in, and a trailing blank line', () {
      final body = _body([
        _port('p1', order: 'a0', label: 'IN 01'),
        _port('p2', order: 'a1', label: 'IN 02'),
      ]);
      final registries = _registries();
      final tsv = buildPortTsv(
        body: body,
        columns: _columns,
        portKeys: const ['p1', 'p2'],
        registries: registries,
      );

      final plan = parsePortTsv(
        body: body,
        text: '${tsv.replaceAll('\n', '\r\n')}\r\n',
        columns: _columns,
        visibleRowKeys: const ['p1', 'p2'],
        anchorKey: 'p1',
        anchorColumn: _columns.first,
        registries: registries,
      );

      expect(plan.isRefused, isFalse);
      expect(plan.commands, isEmpty);
    });
  });

  group('what goes on the clipboard', () {
    test('A HEADER LEADS IT, so a paste into Excel is a usable sheet and '
        'not eight anonymous columns', () {
      final body = _body([_port('p1', order: 'a0')]);
      final tsv = buildPortTsv(
        body: body,
        columns: _columns,
        portKeys: const ['p1'],
        registries: _registries(),
      );

      expect(tsv.split('\n').first.split('\t').first, 'KEY');
      expect(tsv.split('\n').first, contains('CONNECTOR'));
      expect(tsv.split('\n'), hasLength(2));
    });

    test('READABLE IN EXCEL: the connector is its trade alias and the '
        'family its display name, never a raw id', () {
      final body = _body([_port('p1', order: 'a0')]);
      final line = buildPortTsv(
        body: body,
        columns: _columns,
        portKeys: const ['p1'],
        registries: _registries(),
      ).split('\n')[1];

      expect(line, contains('RJ45'));
      expect(line, isNot(contains('conn.rj45')));
      expect(line, isNot(contains('net.ethernet')));
    });

    test('AN UNKNOWN IS AN EMPTY CELL AND NEVER THE DASH, because a '
        'spreadsheet cell that nobody has filled in is empty and a '
        'literal — would land in a numeric column', () {
      final body = _body([_port('p1', order: 'a0')]);
      final line = buildPortTsv(
        body: body,
        columns: _columns,
        portKeys: const ['p1'],
        registries: _registries(),
      ).split('\n')[1];

      expect(line, isNot(contains('—')));
      expect(line, contains('\t\t'), reason: 'NOTES and SET are unset');
    });

    test('the enums are the words the grid shows, not enum names', () {
      final body = _body([
        _port('p1', order: 'a0', direction: PortDirection.source),
      ]);
      final line = buildPortTsv(
        body: body,
        columns: _columns,
        portKeys: const ['p1'],
        registries: _registries(),
      ).split('\n')[1];

      expect(line, contains('Output'));
      expect(line, isNot(contains('PortDirection')));
      expect(line, isNot(contains('source')));
    });
  });

  group('the header on the way back', () {
    test('a first line whose EVERY cell is a header is dropped', () {
      final columns = [PortColumnId.label, PortColumnId.notes];
      expect(looksLikePortTsvHeader(const ['LABEL', 'NOTES'], columns), isTrue);
    });

    test('ONE MATCHING CELL IS NOT A HEADER, which is what keeps a port '
        'genuinely called LABEL from being eaten', () {
      final columns = [PortColumnId.label, PortColumnId.notes];
      expect(
        looksLikePortTsvHeader(const ['LABEL', 'first floor'], columns),
        isFalse,
      );
    });

    test('the paste says it dropped one, so nothing silently vanishes', () {
      final body = _body([_port('p1', order: 'a0')]);
      final registries = _registries();
      final tsv = buildPortTsv(
        body: body,
        columns: _columns,
        portKeys: const ['p1'],
        registries: registries,
      );

      final plan = parsePortTsv(
        body: body,
        text: tsv,
        columns: _columns,
        visibleRowKeys: const ['p1'],
        anchorKey: 'p1',
        anchorColumn: _columns.first,
        registries: registries,
      );

      expect(plan.skippedHeader, isTrue);
    });

    test('a paste with no header is data from the first line', () {
      final body = _body([
        _port('p1', order: 'a0'),
        _port('p2', order: 'a1'),
      ]);

      final plan = parsePortTsv(
        body: body,
        text: 'ONE\nTWO',
        columns: const [PortColumnId.label],
        visibleRowKeys: const ['p1', 'p2'],
        anchorKey: 'p1',
        anchorColumn: PortColumnId.label,
        registries: _registries(),
      );
      _run(body, plan.commands);

      expect(plan.skippedHeader, isFalse);
      expect(body.ports.map((p) => p.label), ['ONE', 'TWO']);
    });
  });

  group('A PASTE DOES NOT CREATE PORTS', () {
    test('it refuses and says by how many, rather than inventing keys '
        'nobody chose', () {
      final body = _body([
        _port('p1', order: 'a0'),
        _port('p2', order: 'a1'),
      ]);

      final plan = parsePortTsv(
        body: body,
        text: 'A\nB\nC\nD',
        columns: const [PortColumnId.label],
        visibleRowKeys: const ['p1', 'p2'],
        anchorKey: 'p1',
        anchorColumn: PortColumnId.label,
        registries: _registries(),
      );

      expect(plan.refusal, PortPasteRefusal.tooManyRows);
      expect(plan.overrun, 2);
      expect(body.ports.map((p) => p.label), ['P1', 'P2']);
    });

    test('it counts from the CARET, not from the top', () {
      final body = _body([
        _port('p1', order: 'a0'),
        _port('p2', order: 'a1'),
        _port('p3', order: 'a2'),
      ]);

      final plan = parsePortTsv(
        body: body,
        text: 'A\nB\nC',
        columns: const [PortColumnId.label],
        visibleRowKeys: const ['p1', 'p2', 'p3'],
        anchorKey: 'p2',
        anchorColumn: PortColumnId.label,
        registries: _registries(),
      );

      expect(plan.refusal, PortPasteRefusal.tooManyRows);
      expect(plan.overrun, 1);
    });

    test('too many columns refuses too', () {
      final body = _body([_port('p1', order: 'a0')]);

      final plan = parsePortTsv(
        body: body,
        text: 'A\tB\tC',
        columns: const [PortColumnId.label, PortColumnId.notes],
        visibleRowKeys: const ['p1'],
        anchorKey: 'p1',
        anchorColumn: PortColumnId.label,
        registries: _registries(),
      );

      expect(plan.refusal, PortPasteRefusal.tooManyColumns);
    });

    test('with no caret there is no corner to paste from', () {
      final body = _body([_port('p1', order: 'a0')]);

      expect(
        parsePortTsv(
          body: body,
          text: 'A',
          columns: _columns,
          visibleRowKeys: const ['p1'],
          anchorKey: null,
          anchorColumn: null,
          registries: _registries(),
        ).refusal,
        PortPasteRefusal.needsACell,
      );
    });
  });

  group('one cell at a time', () {
    test('AN EMPTY CELL WRITES AN UNKNOWN, because clearing a column '
        'across a paste is a thing a person means (G4)', () {
      final parsed = parsePortCell(
        PortColumnId.notes,
        '',
        _registries(),
      );
      expect(parsed.ok, isTrue);
      expect(parsed.value, isNull);
    });

    test('AN UNRESOLVABLE CELL WRITES NOTHING, which is a different '
        'answer: a connector nobody can name is not a connector', () {
      final parsed = parsePortCell(
        PortColumnId.connector,
        'not-a-connector',
        _registries(),
      );
      expect(parsed.ok, isFalse);
    });

    test('one bad cell does not cost the other thirty-nine rows', () {
      final body = _body([
        _port('p1', order: 'a0'),
        _port('p2', order: 'a1'),
      ]);

      final plan = parsePortTsv(
        body: body,
        text: 'nonsense\nHDMI',
        columns: const [PortColumnId.connector],
        visibleRowKeys: const ['p1', 'p2'],
        anchorKey: 'p1',
        anchorColumn: PortColumnId.connector,
        registries: _registries(),
      );
      _run(body, plan.commands);

      expect(body.ports.first.connector, const ConnectorTypeId('conn.rj45'));
      expect(body.ports.last.connector.v, startsWith('conn.hdmi'));
    });

    test('a connector resolves from its alias in any case', () {
      for (final spelling in ['RJ45', 'rj45', 'Rj45']) {
        expect(
          parsePortCell(
            PortColumnId.connector,
            spelling,
            _registries(),
          ).value,
          const ConnectorTypeId('conn.rj45'),
          reason: spelling,
        );
      }
    });

    test('EVERY CLOSED COLUMN INVERTS ITS OWN LABEL, which is the one way '
        'the writer and the reader can drift apart', () {
      final registries = _registries();
      for (final column in PortColumnId.values) {
        final options = portColumnOptions(column);
        if (options == null) continue;
        for (final option in options) {
          final text = portValueLabel(column, option, registries);
          expect(
            parsePortCell(column, text, registries).value,
            option,
            reason: '$column did not read back "$text"',
          );
        }
      }
    });
  });
}

/// A document holding [body] as its only template, so the round trip can
/// be byte-compared through the codec CR-117 already defends.
RackDocument _docWith(TemplateBody body) => RackDocument(
  id: const Uuid('0190f000-0000-7000-8000-000000000000'),
  appVersion: 'test',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    updatedBy: 'test',
    localRevision: 1,
  ),
  templates: {
    'tsv@1': TemplateSnapshot(
      templateId: const TemplateId('tsv'),
      version: 1,
      contentHash: 'sha256:tsv',
      capturedAt: DateTime.utc(2026),
      body: body,
    ),
  },
);

TemplateBody _copy(TemplateBody body) => copyTemplateBody(body);
