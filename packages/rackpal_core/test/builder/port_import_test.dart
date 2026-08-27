// M4-I3's gate: paste from spreadsheet (`#222`, docs/06 §4.3).
//
// THE ARTIFACT IS THE PORTS. Every assertion is a fact a person reads off
// the grid after clicking Import: how many ports, what they are labelled,
// which bank they landed in, which cells came through and which did not.
// Nothing pins a mapping's internals.
//
// TWO THINGS ARE PROVED ABOUT THE ENGINE RATHER THAN THE FEATURE, because
// `#222`'s own words are "use it, do not fork it": the reader is M3's,
// exercised here through a TAB delimiter, and the synonym table answers
// from its own list or answers null, which is `csv_header_map.dart`'s cap
// inherited rather than re-opened.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

TemplateBody emptyBody() =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D');

void main() {
  final r = buildSeedRegistries();

  /// Reads [text] as a tab sheet, the way the dialog does.
  CsvTable table(String text) {
    final read = readCsv(text, delimiter: CsvDelimiter.tab);
    if (read is CsvReadRefused) fail('refused: ${read.message}');
    return (read as CsvReadOk).table;
  }

  List<List<String>> rowsOf(CsvTable t) => [
    for (final row in t.rows) row.cells,
  ];

  ({TemplateBody body, PortImportPlan plan}) run(
    String text, {
    TemplateBody? into,
    PortImportMapping Function(PortImportMapping)? edit,
  }) {
    final body = into ?? emptyBody();
    final t = table(text);
    var mapping = PortImportMapping.guess(t.headers);
    if (edit != null) mapping = edit(mapping);
    final rows = rowsOf(t);
    final plan = planPortImport(
      registries: r,
      body: body,
      mapping: mapping,
      rows: rows,
    );
    for (final c in buildPortImport(
      registries: r,
      body: body,
      mapping: mapping,
      rows: rows,
    )) {
      c.apply(body);
    }
    return (body: body, plan: plan);
  }

  const sheet =
      'Port\tConnector\tSignal\tDirection\tGroup\n'
      'HDMI IN 1\tHDMI\tHDMI 2.0 (18 Gbps)\tInput\tInputs\n'
      'HDMI IN 2\tHDMI\tHDMI 2.0 (18 Gbps)\tInput\tInputs\n'
      'LAN\tRJ45\tEthernet\tBidirectional\tControl\n';

  group('it reads what a spreadsheet actually puts on a clipboard', () {
    test('a TAB sheet is read rather than refused', () {
      // `readCsv` refuses tabs in comma mode BY DESIGN, and its own
      // comment says the fix has to be "a user-visible choice, not a
      // counter". This is that choice, exercised.
      expect(table(sheet).headers, <String>[
        'Port',
        'Connector',
        'Signal',
        'Direction',
        'Group',
      ]);
    });

    test('a COMMA sheet in tab mode is diagnosed, not sniffed', () {
      final read = readCsv(
        'Port,Connector\nA,B\n',
        delimiter: CsvDelimiter.tab,
      );
      expect(read, isA<CsvReadRefused>());
      expect((read as CsvReadRefused).reason, CsvRefusal.wrongDelimiter);
      expect(read.message, contains('commas'));
      expect(read.message, contains('tab-separated'));
    });

    test('M3 is untouched: the default is still comma', () {
      expect(readCsv('Room,Qty\nAttic,1\n'), isA<CsvReadOk>());
      expect(readCsv('Room\tQty\nAttic\t1\n'), isA<CsvReadRefused>());
    });
  });

  group('the synonym table is capped, as M3-F capped its own', () {
    test('the grid headers match without being listed', () {
      // A round trip through `Copy` needs no synonyms, so the grid's own
      // spellings are derived from the target list rather than written
      // out a second time.
      expect(
        matchPortImportHeader('LABEL'),
        const PortImportColumn(
          PortColumnId.label,
        ),
      );
      expect(
        matchPortImportHeader('conn'),
        const PortImportColumn(
          PortColumnId.connector,
        ),
      );
      expect(
        matchPortImportHeader('PoE STD'),
        const PortImportColumn(
          PortColumnId.poeStandard,
        ),
      );
    });

    test('normalisation is M3s four transforms and no fifth', () {
      for (final spelling in <String>[
        'Signal Family',
        'signal_family',
        'SIGNAL-FAMILY',
        'signalfamily',
      ]) {
        expect(
          matchPortImportHeader(spelling),
          const PortImportColumn(PortColumnId.family),
          reason: spelling,
        );
      }
    });

    test('A HEADER THE TABLE DOES NOT HOLD ANSWERS NULL', () {
      // The gate that IS the feature. No fuzzy match, no edit distance,
      // no stemming: an unmatched column falls through to the manual
      // assign step, exactly as the Structure sheet does.
      for (final unknown in <String>[
        'Connectr',
        'Sig fam',
        'Wire colour',
        'Qty',
        'Cost',
        '',
      ]) {
        expect(matchPortImportHeader(unknown), isNull, reason: unknown);
      }
    });

    test('every synonym answers a target that still exists', () {
      for (final entry in kPortImportSynonyms.entries) {
        expect(
          PortImportTarget.all,
          contains(entry.value),
          reason: entry.key,
        );
      }
    });
  });

  group('importing creates ports, where Ctrl+V refuses to', () {
    test('three rows are three ports', () {
      final out = run(sheet);
      expect(out.body.ports, hasLength(3));
      expect(out.plan.ports, 3);
    });

    test('the labels are the cells, not a pattern expansion', () {
      expect(run(sheet).body.ports.map((p) => p.label).toList(), <String>[
        'HDMI IN 1',
        'HDMI IN 2',
        'LAN',
      ]);
    });

    test('A LABEL THAT LOOKS LIKE A PATTERN IS LEFT ALONE', () {
      // The defect routing a pasted cell through `parseLabelPattern`
      // would produce: `HDMI {n}` silently becomes `HDMI 1`.
      final out = run('Port\nHDMI {n}\nZONE {L,R}\n');
      expect(out.body.ports.map((p) => p.label).toList(), <String>[
        'HDMI {n}',
        'ZONE {L,R}',
      ]);
    });

    test('the key still follows the label', () {
      // Which is why the label is passed to the batch rather than
      // written afterwards: `autoPortKey` derives from it.
      expect(run(sheet).body.ports.first.key.v, 'hdmi.in.1');
    });

    test('the cells resolve through the same resolvers Ctrl+V uses', () {
      final port = run(sheet).body.ports.first;
      expect(port.connector.v, 'conn.hdmi_a');
      expect(port.signalFamily.v, 'video.hdmi.2_0');
      // `Input` AND NOT `Output`, which is the family's own default.
      // The first draft of this sheet said `Source (out)`, a spelling
      // `parsePortCell` refuses, and this line still passed: the
      // direction was arriving from `video.hdmi.2_0.defaultDirection`.
      // A cell asserted against a value the port would have held anyway
      // proves nothing about the cell.
      expect(port.direction, PortDirection.sink);
    });

    test('a direction cell nobody can read falls back and is COUNTED', () {
      final out = run('Port\tSignal\tDirection\nA\tHDMI 2.0 (18 Gbps)\tin\n');
      expect(out.plan.unresolvedCells, 1);
      expect(
        out.body.ports.single.direction,
        PortDirection.source,
        reason: 'the family default, because the cell said nothing usable',
      );
    });

    test('a Group column creates and reuses banks', () {
      final out = run(sheet);
      expect(out.body.banks.map((b) => b.label).toList(), <String>[
        'Inputs',
        'Control',
      ]);
      expect(out.plan.banks, 2);
      final inputs = out.body.banks.first.key;
      expect(
        out.body.ports.take(2).map((p) => p.bankKey).toSet(),
        <String>{inputs},
      );
    });

    test('a second import reuses a bank the body already holds', () {
      final body = emptyBody();
      run(sheet, into: body);
      final second = run(sheet, into: body);
      expect(body.banks, hasLength(2));
      expect(second.plan.banks, 0);
      expect(body.ports, hasLength(6));
      expect(body.ports.map((p) => p.key.v).toSet(), hasLength(6));
    });

    test('with no Group column the ports derive their own bank', () {
      final out = run(
        'Port\tSignal\nHDMI IN 1\tHDMI 2.0 (18 Gbps)\n',
      );
      expect(out.body.banks.single.label, 'HDMI Outputs');
    });

    test('one undo takes the whole import back', () {
      final body = emptyBody();
      final t = table(sheet);
      final mapping = PortImportMapping.guess(t.headers);
      final commands = buildPortImport(
        registries: r,
        body: body,
        mapping: mapping,
        rows: rowsOf(t),
      );
      for (final c in commands) {
        c.apply(body);
      }
      for (var i = commands.length - 1; i >= 0; i--) {
        commands[i].revert(body);
      }
      expect(body.ports, isEmpty);
      expect(body.banks, isEmpty);
    });
  });

  group('the plan says what the import will do, before it does it', () {
    test('a wholly empty row is skipped and counted', () {
      // A trailing run of blank rows is what a spreadsheet always has,
      // and forty phantom ports is worse than a number on screen.
      final out = run('Port\tSignal\nLAN\tEthernet\n\t\n\t\n');
      expect(out.body.ports, hasLength(1));
      expect(out.plan.skippedRows, 2);
    });

    test('an unmapped column is DROPPED AND SAID SO', () {
      // `PortDef` has no `unknown` map, unlike a Structure row, so the
      // column cannot be preserved. A visible discard is not a silent one.
      final out = run('Port\tWire colour\nLAN\tblue\n');
      expect(out.plan.droppedColumns, 1);
      expect(out.body.ports.single.label, 'LAN');
    });

    test('an unresolvable cell writes nothing and is counted', () {
      // Not an error and not a guess: the port arrives with that half
      // unknown and the grid marks it.
      final out = run('Port\tConnector\nLAN\tWidgetCorp WX-9\n');
      expect(out.plan.unresolvedCells, 1);
      expect(out.body.ports.single.connector.v, isEmpty);
    });

    test('the plan and the import never disagree', () {
      for (final text in <String>[
        sheet,
        'Port\tSignal\nA\tEthernet\n\t\n',
        'Port\tGroup\nA\tX\nB\tY\nC\tX\n',
      ]) {
        final body = emptyBody();
        final t = table(text);
        final mapping = PortImportMapping.guess(t.headers);
        final plan = planPortImport(
          registries: r,
          body: body,
          mapping: mapping,
          rows: rowsOf(t),
        );
        final before = body.banks.length;
        for (final c in buildPortImport(
          registries: r,
          body: body,
          mapping: mapping,
          rows: rowsOf(t),
        )) {
          c.apply(body);
        }
        expect(body.ports, hasLength(plan.ports), reason: text);
        expect(body.banks.length - before, plan.banks, reason: text);
      }
    });
  });

  group('the mapping sheet', () {
    test('it guesses every header it can and leaves the rest', () {
      final mapping = PortImportMapping.guess(
        table(
          'Port\tWire colour\tSignal\n',
        ).headers,
      );
      expect(mapping.assignments, <PortImportTarget?>[
        const PortImportColumn(PortColumnId.label),
        null,
        const PortImportColumn(PortColumnId.family),
      ]);
      expect(mapping.unmappedColumns, 1);
    });

    test('ASSIGNING A TARGET RELEASES THE COLUMN THAT HELD IT', () {
      // Two columns both feeding LABEL means the second silently wins
      // and a person looking at the sheet cannot see which.
      final mapping = PortImportMapping.guess(
        table('Port\tName\n').headers,
      ).withAssignment(1, const PortImportColumn(PortColumnId.label));
      expect(mapping.assignments, <PortImportTarget?>[
        null,
        const PortImportColumn(PortColumnId.label),
      ]);
    });

    test('a correction takes effect on the import', () {
      // The manual assign step doing its job: `Wire colour` is nothing
      // the table knows, and a person points it at NOTES.
      final out = run(
        'Port\tWire colour\nLAN\tblue\n',
        edit: (m) =>
            m.withAssignment(1, const PortImportColumn(PortColumnId.notes)),
      );
      expect(out.body.ports.single.notes, 'blue');
      expect(out.plan.droppedColumns, 0);
    });

    test('clearing an assignment is a real state', () {
      final mapping = PortImportMapping.guess(
        table('Port\tSignal\n').headers,
      ).withAssignment(1, null);
      expect(mapping.unmappedColumns, 1);
      expect(mapping.isEmpty, isFalse);
    });

    test('nothing mapped at all is a state the dialog can refuse on', () {
      expect(
        PortImportMapping.guess(table('Cost\tQty\n').headers).isEmpty,
        isTrue,
      );
    });
  });

  group('a pasted sheet and a generator share one allocation', () {
    test('no key collides across the two paths', () {
      // The batch allocator across an archetype AND an import, which is
      // the same object doing the job it exists for.
      final body = emptyBody();
      for (final c in buildArchetype(
        r,
        body,
        planMatrixArchetype(
          r,
          MatrixArchetype(
            inputs: 2,
            inputType: PortType.token(r, 'hdmi'),
            outputs: 2,
            outputType: PortType.token(r, 'hdmi'),
          ),
        ),
      )) {
        c.apply(body);
      }
      run(
        'Port\tSignal\nHDMI IN 01\tHDMI 2.0 (18 Gbps)\n',
        into: body,
      );
      expect(body.ports, hasLength(5));
      expect(body.ports.map((p) => p.key.v).toSet(), hasLength(5));
    });
  });
}
