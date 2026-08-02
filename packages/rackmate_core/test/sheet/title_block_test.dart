// draw/sheet/title_block.dart — section 5.2.
//
// Three properties are proved:
//   1. every field RESOLVES from the model — nothing is typed at export
//      time, asserted against the source of that file so a free-text
//      parameter cannot be added quietly;
//   2. empty optional lines COLLAPSE — no blank band, no empty text op, and
//      the surviving lines redistribute;
//   3. the SCALE field prints what the sheet is actually drawn at.

import 'dart:io';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

final DateTime _issued = DateTime.utc(2026, 7, 18);

TitleBlockFields fieldsFor({
  ProjectInfo? info,
  ProjectSettings? settings,
  SheetDef? sheet,
  Rack? rack,
  bool noRack = false,
  List<RevisionEntry> revisions = const <RevisionEntry>[],
  DrawingScale? scale,
  String fileName = 'smith.rmpj',
  DateTime? issuedAt,
}) {
  final set = oneRackSheetSet();
  return TitleBlockFields.resolve(
    info: info ?? fullProjectInfo(),
    settings: settings ?? ProjectSettings(),
    sheet: sheet ?? set.sheets.first,
    rack: noRack ? null : (rack ?? testRack()),
    revisions: revisions,
    scale: scale ?? DrawingScale.standard(8),
    fileName: fileName,
    issuedAt: issuedAt ?? _issued,
  );
}

DBox boxFor({bool compact = false}) => SheetLayout.resolve(
  geometry: SheetGeometry(
    compact ? SheetSize.ansiALandscape : SheetSize.ansiBPortrait,
  ),
  revisionRowCount: 1,
).titleBlockBox;

List<DiagramOp> layerFor(TitleBlockFields fields, {bool compact = false}) =>
    buildTitleBlockLayer(
      box: boxFor(compact: compact),
      fields: fields,
      measurer: FakeMeasurer(),
      compact: compact,
    ).ops;

String? valueOf(TitleBlockFields fields, String label) {
  for (final field in <TitleBlockField>[
    ...fields.gridRowA,
    ...fields.gridRowB,
  ]) {
    if (field.label == label) return field.value;
  }
  return null;
}

void expectInside(List<DiagramOp> ops, DBox box) {
  final ink = inkBoundsOf(ops, measurer: FakeMeasurer())!;
  final allowed = box.inflate(1);
  expect(ink.left, greaterThanOrEqualTo(allowed.left));
  expect(ink.right, lessThanOrEqualTo(allowed.right));
  expect(ink.top, greaterThanOrEqualTo(allowed.top));
  expect(ink.bottom, lessThanOrEqualTo(allowed.bottom));
}

void main() {
  group('nothing is typed at export time', () {
    test('resolve() takes only model-derived parameters', () {
      // THE MECHANISM, not a comment: the parameter list is read out of the
      // source and compared to a whitelist of name AND type. Adding a
      // `String note` or a `String drawingTitle` the export dialog could
      // prompt for turns this red, which forces the decision to be taken
      // rather than drifted into.
      const allowed = <String, String>{
        'info': 'ProjectInfo',
        'settings': 'ProjectSettings',
        'sheet': 'SheetDef',
        'rack': 'Rack?',
        'revisions': 'List<RevisionEntry>',
        'scale': 'DrawingScale',
        'fileName': 'String',
        'issuedAt': 'DateTime',
      };

      final source = File(
        'lib/src/draw/sheet/title_block.dart',
      ).readAsStringSync();
      final signature = RegExp(
        r'factory TitleBlockFields\.resolve\(\{(.*?)\n  \}\)',
        dotAll: true,
      ).firstMatch(source);
      expect(signature, isNotNull, reason: 'resolve() signature not found');

      final params = <String, String>{
        for (final m in RegExp(
          r'^\s*required\s+(\S+)\s+(\w+),\s*$',
          multiLine: true,
        ).allMatches(signature!.group(1)!))
          m.group(2)!: m.group(1)!,
      };

      expect(params, isNotEmpty, reason: 'the regex must actually match');
      expect(params, allowed);
      // And exactly ONE of them is a String — the file name, which is data
      // about the project, not annotation about the drawing.
      expect(
        params.entries.where((e) => e.value == 'String').map((e) => e.key),
        <String>['fileName'],
      );
    });

    test('the only free-form String is the file name of the document', () {
      final fields = fieldsFor(fileName: 'smith-residence.rmpj');
      expect(valueOf(fields, 'FILE'), 'smith-residence.rmpj');
    });
  });

  group('field resolution', () {
    test('the identity lines come from ProjectInfo and Rack', () {
      final fields = fieldsFor();
      expect(fields.projectLine, 'SMITH RESIDENCE — RK-1 MASTER RACK');
      expect(fields.addressLine, '1428 Alder Ct, Portland, OR 97214');
      expect(fields.clientLine, 'CLIENT  J. & M. Smith');
      expect(fields.rackLine, 'RK-1  ·  MASTER RACK  ·  42U');
      expect(fields.sheetTitle, 'RACK ELEVATION — FRONT');
    });

    test('the grid comes from ProjectInfo, the sheet and the clock', () {
      final fields = fieldsFor();
      expect(valueOf(fields, 'DRAWN'), 'J.S.');
      expect(valueOf(fields, "CHK'D"), 'A.B.');
      expect(valueOf(fields, 'PROJ'), '25-1183');
      expect(valueOf(fields, 'SIZE'), 'B');
      expect(valueOf(fields, 'DISC'), 'T');
      expect(valueOf(fields, 'DATE'), '2026-07-18');
    });

    test('the integrator is a TEXT block, joined from three fields', () {
      expect(
        fieldsFor().integratorLine,
        'NBS INTEGRATION LLC · (503) 555-0142 · OR CCB #219884',
      );
    });

    test('an equipment-list sheet has no rack line and no rack in the '
        'title', () {
      final set = oneRackSheetSet();
      final fields = fieldsFor(sheet: set.sheets.last, noRack: true);
      expect(fields.projectLine, 'SMITH RESIDENCE');
      expect(fields.rackLine, isNull);
      expect(valueOf(fields, 'SIZE'), 'A');
      expect(fields.sheetTitle, 'EQUIPMENT LIST AND MATERIALS');
    });

    test('an absent value prints an em dash, never a blank or a zero', () {
      final fields = fieldsFor(info: minimalProjectInfo());
      expect(valueOf(fields, 'DRAWN'), kEmDash);
      expect(valueOf(fields, "CHK'D"), kEmDash);
      expect(valueOf(fields, 'PROJ'), kEmDash);
      expect(valueOf(fields, 'REV'), kEmDash);
    });

    test('REV is the label of the newest RevisionEntry', () {
      final fields = fieldsFor(
        revisions: <RevisionEntry>[
          testRevision('A', 1),
          testRevision('C', 18),
          testRevision('B', 8),
        ],
      );
      expect(valueOf(fields, 'REV'), 'C');
    });

    test('an unnamed rack falls back to its designator', () {
      final fields = fieldsFor(rack: testRack(name: ''));
      expect(fields.projectLine, 'SMITH RESIDENCE — RK-1');
      expect(fields.rackLine, 'RK-1  ·  42U');
    });
  });

  group('the SCALE field (section 5.2)', () {
    test('prints the ratio the sheet is drawn at', () {
      expect(
        valueOf(fieldsFor(scale: DrawingScale.standard(8)), 'SCALE'),
        '1:8',
      );
      expect(
        valueOf(fieldsFor(scale: DrawingScale.standard(1)), 'SCALE'),
        '1:1',
      );
    });

    test('prints NTS rather than a nearby lie', () {
      final dishonest = DrawingScale.fitted(
        sceneFactorForRatio(PhysicalRatio.oneOver(8.34)),
      );
      expect(valueOf(fieldsFor(scale: dishonest), 'SCALE'), 'NTS');
    });
  });

  group('sheet numbering (CR-066)', () {
    test('simple prints SHEET i OF n plus the sheet title', () {
      final fields = fieldsFor(settings: ProjectSettings());
      expect(fields.sheetNumberLine, 'SHEET 1 OF 3 · RACK ELEVATION — FRONT');
      expect(valueOf(fields, 'SHEET'), '1/3');
    });

    test('ncs prints the NCS id', () {
      final fields = fieldsFor(
        settings: ProjectSettings(sheetNumbering: SheetNumbering.ncs),
      );
      expect(fields.sheetNumberLine, 'SHEET T2.01 · RACK ELEVATION — FRONT');
      expect(valueOf(fields, 'SHEET'), 'T2.01');
    });

    test('the NCS id is printed as sheet identity under BOTH schemes', () {
      // Section 2.1: the id is the stable name of the sheet whatever the
      // title block chooses to number it.
      for (final numbering in SheetNumbering.values) {
        final fields = fieldsFor(
          settings: ProjectSettings(sheetNumbering: numbering),
        );
        expect(fields.sheetIdLine, 'SHEET NO.  T2.01');
      }
    });
  });

  group('the legend cross-reference is omitted, not pointed at nothing', () {
    test('no field mentions a symbol legend or T0.01', () {
      // T0.01 is not in this sheet set. Section 5.2 would auto-fill
      // "SYMBOL LEGEND: SEE SHEET …"; pointing at an absent sheet is worse
      // than saying nothing, and CR-023 already forbids it being a gate.
      final texts = textsOf(layerFor(fieldsFor())).join(' ');
      expect(texts, isNot(contains('LEGEND')));
      expect(texts, isNot(contains('T0.01')));
    });
  });

  group('empty optional lines collapse (section 5.2)', () {
    final densities = <String, ProjectInfo>{
      'all fields': fullProjectInfo(),
      'half': halfProjectInfo(),
      'minimum': minimalProjectInfo(),
    };

    test('fewer fields means strictly fewer text ops', () {
      final counts = <int>[
        for (final info in densities.values)
          textOps(layerFor(fieldsFor(info: info))).length,
      ];
      expect(counts[0], greaterThan(counts[1]));
      expect(counts[1], greaterThan(counts[2]));
    });

    densities.forEach((name, info) {
      final ops = layerFor(fieldsFor(info: info));

      test('$name: no empty text op is ever emitted', () {
        expect(textsOf(ops).where((t) => t.trim().isEmpty), isEmpty);
      });

      test('$name: the block is still full — lines redistribute', () {
        // A collapsed line must not leave a gap: the first and last text
        // rows still sit near the edges of the block itself.
        final box = boxFor();
        final ys = textOps(ops).map((o) => o.at.y).toList()..sort();
        expect(ys.first - box.top, lessThan(box.height / 3));
        expect(box.bottom - ys.last, lessThan(box.height / 4));
      });

      test('$name: the identity band has NO blank row — its rows are '
          'evenly pitched', () {
        // THE COLLAPSE RULE, asserted geometrically. "Empty optional lines
        // collapse rather than printing a blank" means an absent client
        // line must not leave a row-shaped hole; the surviving lines close
        // up. A blank row shows as a DOUBLE gap between two drawn rows, so
        // uniform pitch is exactly the property to assert — and it is one
        // an "emitted no empty string" check cannot see, because a blank
        // row emits nothing at all.
        //
        // Only the upper identity/sheet band is pitched this way; the
        // fixed-height grid and footer below it are excluded by taking
        // rows above the first grid label.
        final labelYs = textOps(ops)
            .where((o) => o.style.sizePt == SheetTextSizes.fieldLabel)
            .map((o) => o.at.y);
        expect(labelYs, isNotEmpty, reason: 'the field grid must exist');
        final gridTop = labelYs.reduce((a, b) => a < b ? a : b);

        final bandYs = textOps(
          ops,
        ).map((o) => o.at.y).where((y) => y < gridTop).toSet().toList()..sort();
        expect(bandYs.length, greaterThanOrEqualTo(2));

        final gaps = <double>[
          for (var i = 1; i < bandYs.length; i++) bandYs[i] - bandYs[i - 1],
        ];
        for (final gap in gaps) {
          expect(
            gap,
            closeTo(gaps.first, 0.01),
            reason:
                'row pitch $gaps is uneven — a collapsed line left a '
                'blank row behind',
          );
        }
      });

      test('$name: all ink stays inside the block', () {
        expectInside(ops, boxFor());
      });
    });

    test('a minimal project produces no address or client line at all', () {
      final fields = fieldsFor(info: minimalProjectInfo());
      expect(fields.addressLine, isNull);
      expect(fields.clientLine, isNull);
      expect(fields.integratorLine, isNull);
      expect(fields.optionalLines.whereType<String>(), hasLength(1));
    });

    test('a partly-filled address collapses its missing parts', () {
      expect(
        formatAddress(Address(city: 'Portland', region: 'OR')),
        'Portland, OR',
      );
      expect(formatAddress(Address(line1: '1428 Alder Ct')), '1428 Alder Ct');
      expect(formatAddress(Address()), isNull);
      expect(formatAddress(null), isNull);
    });
  });

  group('overlong values are truncated, never run off the block', () {
    final ops = layerFor(
      fieldsFor(
        info: ProjectInfo(
          projectName: 'A' * 300,
          projectNumber: 'P' * 80,
          drawnBy: 'D' * 60,
        ),
        fileName: 'z' * 200,
      ),
    );

    test('ink still stays inside the block', () {
      expectInside(ops, boxFor());
    });

    test('the truncation is marked, so nobody reads a cut string as '
        'whole', () {
      expect(textsOf(ops).any((t) => t.endsWith(kEllipsis)), isTrue);
    });
  });

  group('the compact ANSI A strip', () {
    test('draws every grid field as one run and stays inside the strip', () {
      final set = oneRackSheetSet();
      final fields = fieldsFor(sheet: set.sheets.last, noRack: true);
      final ops = layerFor(fields, compact: true);

      final joined = textsOf(ops).join(' ');
      for (final label in <String>['DRAWN', 'SCALE', 'SIZE', 'DATE', 'FILE']) {
        expect(joined, contains(label));
      }
      expect(joined, contains('SHEET NO.  T6.30'));

      expectInside(ops, boxFor(compact: true));
    });

    test('emits no empty text op at minimum density either', () {
      final ops = layerFor(
        fieldsFor(info: minimalProjectInfo(), noRack: true),
        compact: true,
      );
      expect(textsOf(ops).where((t) => t.trim().isEmpty), isEmpty);
    });
  });

  group('the injected clock (section 8.4)', () {
    test('two builds with the same date are identical', () {
      final a = describeOps(layerFor(fieldsFor(issuedAt: _issued)));
      final b = describeOps(layerFor(fieldsFor(issuedAt: _issued)));
      expect(a, b);
    });

    test('two builds with different dates differ in EXACTLY one op', () {
      // Not "differ somewhere" — exactly one, and it is the DATE cell.
      // Anything else changing with the clock would be a hidden
      // now()-dependent field.
      final a = describeOps(layerFor(fieldsFor(issuedAt: _issued)));
      final b = describeOps(
        layerFor(fieldsFor(issuedAt: DateTime.utc(2027, 1, 2))),
      );

      expect(a, hasLength(b.length));
      final differing = <int>[
        for (var i = 0; i < a.length; i++)
          if (a[i] != b[i]) i,
      ];
      expect(differing, hasLength(1));
      expect(a[differing.single], contains('2026-07-18'));
      expect(b[differing.single], contains('2027-01-02'));
    });

    test('the date is formatted exactly as handed in, with no timezone '
        'conversion', () {
      expect(formatSheetDate(DateTime.utc(2026, 7, 18)), '2026-07-18');
      expect(formatSheetDate(DateTime.utc(2026)), '2026-01-01');
      expect(formatSheetDate(DateTime.utc(999, 2, 3)), '0999-02-03');
    });
  });
}
