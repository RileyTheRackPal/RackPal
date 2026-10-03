// DR-004 §11.4.3, held as M6-D4 (`#330`): the interconnect sheets are a
// partition AT EXPORT, and no multi-sheet authoring surface came with them.
//
// WHY A SOURCE SCAN. `T6.01…` puts several sheets in every wired PDF, and
// canon §11.4.3 warns that "N sheets come out of the PDF" is exactly the
// sentence that gets read as evidence multi-sheet exists. The defect this
// guards against is not a wrong drawing; it is a second schematic `Sheet`
// arriving in the DOCUMENT, through a command, a menu or the exporter, and
// no single behavioural test can see every route that could add one. The
// constructor and the copy can be seen, so they are what is held.
//
// Run from apps/rackpal, like the other scans beside it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  return withoutBlocks
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');
}

/// Every `lib/` Dart file this product ships, keyed by a forward-slash path
/// relative to the repository root.
Map<String, String> _libSources() {
  final roots = <String>[
    'lib',
    '../../packages/rackpal_core/lib',
    '../../packages/rackpal_export/lib',
    '../../packages/rackpal_ui/lib',
  ];
  final out = <String, String>{};
  for (final root in roots) {
    final dir = Directory(root);
    expect(dir.existsSync(), isTrue, reason: 'run from apps/rackpal: $root');
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path
          .replaceAll(r'\', '/')
          .replaceFirst('../../', '')
          .replaceFirst(RegExp('^lib/'), 'apps/rackpal/lib/');
      out[path] = _stripComments(entity.readAsStringSync());
    }
  }
  return out;
}

/// A call to the `Sheet` constructor, and not `SheetDef(`, `SheetItem(`,
/// `buildLegendSheet(` or any other name that merely ends in `Sheet`.
final _sheetCtor = RegExp(r'(?<![\w.$])Sheet\s*\(');

/// The places allowed to construct one, and why.
const Map<String, String> _allowed = <String, String>{
  // The model's own declaration.
  'packages/rackpal_core/lib/src/model/sheet.dart': 'the class itself',
  // Reading a file that already holds the sheet (G5: the format never
  // migrates, so the entity is decoded whether or not one is authored).
  'packages/rackpal_core/lib/src/persistence/json_codec.dart': 'the decoder',
  // CR-073's ONE schematic sheet, created by the first pin (§11.185.4)...
  'packages/rackpal_core/lib/src/commands/lock_commands.dart': 'first pin',
  // ...or by the first freeze that stores a position (DR-187).
  'packages/rackpal_core/lib/src/commands/sheet_layout_commands.dart':
      'first stored position',
};

void main() {
  late Map<String, String> sources;
  setUpAll(() => sources = _libSources());

  test('the scan is not vacuous: it read the product and found every '
      'allowed file', () {
    expect(sources.length, greaterThan(300));
    for (final path in _allowed.keys) {
      expect(sources.keys, contains(path));
    }
  });

  test("a Sheet is constructed only where CR-073's ONE schematic sheet is "
      'decoded or created', () {
    final offenders = <String>[
      for (final MapEntry(:key, :value) in sources.entries)
        if (_sheetCtor.hasMatch(value) && !_allowed.containsKey(key)) key,
    ];
    expect(offenders, isEmpty, reason: 'DR-004 §11.4.3');
  });

  test('each command that creates the sheet does so only when there is '
      'none, so neither can make a second', () {
    for (final path in <String>[
      'packages/rackpal_core/lib/src/commands/lock_commands.dart',
      'packages/rackpal_core/lib/src/commands/sheet_layout_commands.dart',
    ]) {
      final src = sources[path]!;
      final ctor = _sheetCtor.firstMatch(src)!.start;
      final guard = src.lastIndexOf('schematicSheetOf(doc)', ctor);
      expect(guard, isNonNegative, reason: path);
      expect(
        src.substring(guard, ctor),
        contains('== null'),
        reason: '$path builds a Sheet without asking for the existing one',
      );
    }
  });

  test('the interconnect partition writes no Sheet: it is a view for one '
      'export (CR-073)', () {
    for (final path in <String>[
      'packages/rackpal_core/lib/src/draw/sheet/interconnect_partition.dart',
      'packages/rackpal_core/lib/src/draw/sheet/interconnect_sheet.dart',
      'packages/rackpal_export/lib/src/document/build_document.dart',
    ]) {
      final src = sources[path]!;
      expect(_sheetCtor.hasMatch(src), isFalse, reason: path);
      expect(
        RegExp(r'\.sheets\s*\[[^\]]*\]\s*=').hasMatch(src),
        isFalse,
        reason: '$path writes into doc.sheets',
      );
    }
  });

  test('no surface offers to author a sheet', () {
    // The words a multi-sheet surface would put in front of a user, from
    // design-ux-schematic.md's own `Layout → Split to Sheets…` onward.
    final offer = RegExp(
      r"""['"][^'"]*\b(new|add|duplicate|rename|delete|split (in)?to) """
      r'(schematic )?sheets?\b',
      caseSensitive: false,
    );
    final offenders = <String>[
      for (final MapEntry(:key, :value) in sources.entries)
        if (key.startsWith('apps/rackpal/lib/') ||
            key.startsWith('packages/rackpal_ui/lib/'))
          for (final m in offer.allMatches(value)) '$key: ${m.group(0)}',
    ];
    expect(offenders, isEmpty, reason: 'DR-004: never built');
  });
}
