// THE DEPENDENCY TABLE AND THE PUBSPECS, CHECKED AGAINST EACH OTHER.
//
// ==================================================================
// THE DEFECT THAT PRODUCED IT
// ==================================================================
// `docs/03-architecture.md` §10.1 is titled "The full table" and at
// v0.4.63 it was wrong in BOTH directions:
//
//   * EIGHT packages were named there and installed nowhere:
//     `flutter_riverpod`, `printing`, `desktop_drop`, `logging`, `intl`,
//     `flutter_localizations`, `integration_test`, `benchmark_harness`.
//     `flutter_riverpod` is the load-bearing one — ADR-011 accepted it as
//     the state-management choice, docs/03 §4 spent a numbered section on
//     the provider layer, and FIVE MILESTONES passed without one line of
//     it being written. It was never rejected. It was never reached.
//
//   * TWO packages were installed and named nowhere: `screen_retriever`,
//     a direct app dependency, and `fake_async`, a ui dev dependency.
//     `screen_retriever`'s own pubspec comment CITES "§10.1's
//     `window_manager` row". Somebody read a row out of the table, added
//     a package on the strength of it, and did not add the row.
//
// CARE WAS NOT THE MISSING INGREDIENT. Nothing could fail, because a
// dependency table is prose and no gate read it. Ruled by DR-088
// (canon §11.87, §12.27), which is also where the reasoning lives.
//
// ==================================================================
// WHY A `VERIFY:` MARKER WAS NOT ENOUGH, AND THIS IS
// ==================================================================
// ADR-011 carried `VERIFY: Riverpod 3 API surface BEFORE THE PROVIDER
// LAYER IS WRITTEN`. That condition never came true, so the check never
// fired, and the document went on describing the layer for five
// milestones. A precondition attached to work that does not happen is not
// a tripwire. This file asserts a CLAIM instead of scheduling a look.
//
// ==================================================================
// WHAT IT ASSERTS, IN THREE DIRECTIONS
// ==================================================================
//   (1) every row marked `in use` resolves to a real dependency in some
//       workspace pubspec;
//   (2) every dependency in every workspace pubspec resolves to a row;
//   (3) no row marked `planned` is already installed — the drift that
//       turns a plan into a stale record without anyone editing a word.
//
// Direction (2) is the one that catches `screen_retriever`. Direction (1)
// is the one that catches `flutter_riverpod`. A gate with only one of them
// would have been green through the defect it was written for.
//
// ==================================================================
// NO EXEMPTION LIST, DELIBERATELY
// ==================================================================
// The cheap shape here is a hardcoded `const _knownMissing = [...]`, and
// this repository has already written down why that is a trap: an
// exemption list is where the bug lives. The status lives in a CELL ON THE
// ROW IT DESCRIBES, is read by this file rather than trusted by it, and
// cannot be edited without the diff showing which dependency changed
// state. `planned (unscheduled)` is a real value and a real finding: four
// rows carry it because docs/09 names no milestone for them anywhere, and
// writing a plausible one would have been the confident wrong value G4
// exists to refuse.
//
// ==================================================================
// ITS BLIND SPOTS, STATED
// ==================================================================
//   * IT IS A LINE PARSER, NOT A YAML PARSER. A dependency declared with
//     unusual indentation, or inside a block-scalar, is invisible to it.
//     The workspace's five pubspecs are conventionally formatted and a
//     false negative here is acceptable; a flaky false positive is not.
//   * IT SKIPS A ROW WHOSE NAME IS PARENTHESISED, which today is the
//     vendored pdfium (DR-153). Such a row documents a dependency no
//     pubspec can declare, so "resolves to a declared dependency" is not
//     a question that can be asked of it. What governs that one instead
//     is `pdfium_install_test.dart` and the pin its own test recomputes.
//   * IT DOES NOT READ `pubspec.lock`, so a TRANSITIVE dependency is not
//     required to have a row and is not reported. §10.1 documents direct
//     choices. `flutter_dependency_test.dart` is the file that reasons
//     about the resolved graph, and it is the one to extend if a
//     transitive package ever needs governing.
//   * IT DOES NOT CHECK THE CONSTRAINT. A row saying `^1.16.0` beside a
//     pubspec saying `^2.0.0` passes. Version drift is a different defect
//     with a different remedy (`flutter pub outdated`), and folding it in
//     here would make this gate fail on routine bumps until somebody
//     learned to ignore it.
//   * IT SAYS NOTHING ABOUT WHETHER A `planned` ROW IS STILL A GOOD PLAN.
//     Seven rows are recorded rather than adjudicated on purpose
//     (DR-088 §11.87.8); each is a separate decision owned by a later
//     milestone.
//
// ==================================================================
// IT WAS WATCHED FAILING
// ==================================================================
// A gate that has only ever been green proves nothing. All three
// directions were confirmed to report the offending name before this file
// was trusted: the `flutter_riverpod` row re-added (direction 1), the
// `screen_retriever` row deleted (direction 2), and `printing` flipped to
// `in use` while uninstalled (direction 1 again) and to `planned (M6)`
// while installed (direction 3). The anti-vacuity cases below are what
// keep a renamed heading or a reshaped table from passing silently.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repo root, from `apps/rackpal` where this suite runs.
const String _root = '../..';

/// The section whose table this file governs, and the paragraph that ends
/// it. Both are asserted to exist, so a renamed heading fails loudly
/// rather than yielding zero rows and passing.
const String _sectionHeading = '### 10.1 The full table';
const String _sectionEnd = 'Explicitly **not** used';

/// Every pubspec in the workspace, relative to [_root].
const List<String> _pubspecs = [
  'pubspec.yaml',
  'apps/rackpal/pubspec.yaml',
  'packages/rackpal_core/pubspec.yaml',
  'packages/rackpal_export/pubspec.yaml',
  'packages/rackpal_pdfium/pubspec.yaml',
  'packages/rackpal_text/pubspec.yaml',
  'packages/rackpal_ui/pubspec.yaml',
];

/// The yaml keys whose two-space children are dependency names.
///
/// `flutter:` is deliberately absent: it is BOTH a dependency name and a
/// top-level section holding `assets:` and `fonts:`, and treating the
/// section as a dependency block would report every asset path as a
/// package.
const Set<String> _dependencyBlocks = {
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
};

/// One parsed row of §10.1.
class _Row {
  const _Row(this.package, this.status, this.line);

  /// The package name, unwrapped from its backticks.
  final String package;

  /// The status cell, unwrapped from its backticks: `in use`,
  /// `planned (M6)`, `planned (unscheduled)`, `n/a`.
  final String status;

  /// 1-indexed line in docs/03-architecture.md, for the failure message.
  final int line;

  bool get isInUse => status == 'in use';

  bool get isPlanned => status.startsWith('planned');
}

/// The workspace's own packages. Derived from `packages/`, never listed:
/// they are path dependencies on this repository and §10.1 documents
/// third-party choices. A new package under `packages/` is covered the
/// moment it exists.
Set<String> _workspacePackages() {
  final dir = Directory('$_root/packages');
  return dir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.replaceAll(r'\', '/').split('/').last)
      .toSet();
}

/// §10.1's rows, in document order.
List<_Row> _tableRows() {
  final lines = File(
    '$_root/docs/03-architecture.md',
  ).readAsLinesSync();

  final start = lines.indexWhere((l) => l.startsWith(_sectionHeading));
  expect(
    start,
    isNot(-1),
    reason:
        'docs/03-architecture.md has no line starting "$_sectionHeading". '
        'The heading was renamed or the section removed, and this gate '
        'would otherwise parse zero rows and pass over a table it never '
        'read.',
  );

  final end = lines.indexWhere((l) => l.startsWith(_sectionEnd), start);
  expect(
    end,
    isNot(-1),
    reason:
        'no line starting "$_sectionEnd" after $_sectionHeading. That '
        'paragraph terminates the table; without it this gate cannot tell '
        'where §10.1 stops.',
  );

  // The header must actually carry a Status column, in the position this
  // file reads. Without this check, dropping the column yields rows whose
  // second cell is the constraint, every status compares unequal to
  // `in use`, and the gate goes quietly green.
  final header = lines
      .getRange(start, end)
      .firstWhere(
        (l) => l.startsWith('| Package |'),
        orElse: () => '',
      );
  final headerCells = _cells(header);
  expect(
    headerCells.length > 1 && headerCells[1] == 'Status',
    isTrue,
    reason:
        'the second column of §10.1 is not headed "Status" (header was: '
        '"$header"). DR-088 §11.87.7 puts the status there and this gate '
        'reads it by position.',
  );

  final rows = <_Row>[];
  for (var i = start; i < end; i++) {
    final line = lines[i];
    if (!line.startsWith('|') || line.startsWith('|-')) continue;
    if (line.startsWith('| Package |')) continue;
    final cells = _cells(line);
    if (cells.length < 2) continue;
    final name = _unwrap(cells[0]);
    // The file-dialog row names no package on purpose; it documents the
    // absence of one. It is matched by shape (status `n/a`) rather than
    // by its text, so rewording it does not silently drop it.
    if (_unwrap(cells[1]) == 'n/a') continue;
    // A PARENTHESISED NAME IS A DEPENDENCY THAT IS NOT A PUB PACKAGE, and
    // the vendored pdfium is the first (DR-153 §11.152.3). It is the
    // largest single thing this build depends on, so leaving it out of
    // §10.1 would put the heaviest dependency in the tree in no table at
    // all; but no pubspec can declare it, because CR-100 rules it
    // committed rather than fetched.
    //
    // **THE SHAPE IS THE TEST, NOT THE TEXT**, on the row above's own
    // precedent: a reworded label keeps being skipped and a package name
    // that loses its backticks does not become invisible.
    if (name.startsWith('(') && name.endsWith(')')) continue;
    rows.add(_Row(name, _unwrap(cells[1]), i + 1));
  }
  return rows;
}

/// The cells of a markdown table row, trimmed, without the outer pipes.
List<String> _cells(String line) {
  final inner = line.trim();
  if (!inner.startsWith('|')) return const [];
  final parts = inner.substring(1).split('|');
  if (parts.isNotEmpty && parts.last.trim().isEmpty) parts.removeLast();
  return parts.map((p) => p.trim()).toList();
}

/// Strips one layer of backticks or bold-italic emphasis from a cell.
String _unwrap(String cell) {
  var s = cell;
  for (final marker in const ['**', '*', '`']) {
    while (s.startsWith(marker) && s.endsWith(marker) && s.length > 2) {
      s = s.substring(marker.length, s.length - marker.length).trim();
    }
  }
  return s;
}

/// Every dependency name declared in a workspace pubspec, mapped to the
/// pubspecs that declare it.
Map<String, List<String>> _declaredDependencies() {
  final found = <String, List<String>>{};
  for (final relative in _pubspecs) {
    final file = File('$_root/$relative');
    if (!file.existsSync()) continue;
    var inBlock = false;
    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      // A key at column zero opens or closes a block.
      if (!line.startsWith(' ')) {
        inBlock = _dependencyBlocks.contains(line.split(':').first.trim());
        continue;
      }
      if (!inBlock) continue;
      // Exactly two spaces of indent is a dependency name; deeper is that
      // dependency's own map (`sdk:`, `path:`, `hosted:`).
      final match = RegExp('^  ([A-Za-z_][A-Za-z_0-9]*):').firstMatch(line);
      if (match == null) continue;
      found.putIfAbsent(match.group(1)!, () => <String>[]).add(relative);
    }
  }
  return found;
}

void main() {
  late List<_Row> rows;
  late Map<String, List<String>> declared;
  late Set<String> ours;

  setUpAll(() {
    rows = _tableRows();
    declared = _declaredDependencies();
    ours = _workspacePackages();
  });

  group('anti-vacuity: the inputs are real', () {
    test('§10.1 parses to a plausible number of package rows', () {
      expect(
        rows.length,
        greaterThanOrEqualTo(20),
        reason:
            'only ${rows.length} rows parsed out of §10.1. Either the table '
            'was reshaped or the parser broke; a gate reading two rows '
            'passes just as cheerfully as one reading twenty-three.',
      );
    });

    test('at least fifteen rows are marked `in use`', () {
      final inUse = rows.where((r) => r.isInUse).length;
      expect(
        inUse,
        greaterThanOrEqualTo(15),
        reason:
            'only $inUse rows are `in use`. If the status cells stopped '
            'parsing, every row would look planned and direction (1) would '
            'assert nothing at all.',
      );
    });

    test('the pubspecs parse to a plausible number of dependencies', () {
      final thirdParty = declared.keys.where((d) => !ours.contains(d));
      expect(
        thirdParty.length,
        greaterThanOrEqualTo(15),
        reason:
            'only ${thirdParty.length} third-party dependencies found across '
            '${_pubspecs.length} pubspecs. The block parser has probably '
            'stopped recognising `dependencies:`.',
      );
    });

    test('a known dependency and a known absence are both seen correctly', () {
      expect(
        declared.keys,
        contains('window_manager'),
        reason: 'the parser cannot see a dependency that is plainly there.',
      );
      expect(
        declared.keys,
        isNot(contains('flutter_riverpod')),
        reason:
            'flutter_riverpod is installed. DR-088 rejects it; if it is '
            'wanted again, that is a new ruling and §10.1 needs its row '
            'back with status `in use`.',
      );
    });
  });

  test('(1) every `in use` row resolves to a declared dependency', () {
    final missing = rows
        .where((r) => r.isInUse && !declared.containsKey(r.package))
        .toList();
    expect(
      missing,
      isEmpty,
      reason:
          'docs/03-architecture.md §10.1 marks these `in use`, and no '
          'workspace pubspec declares them:\n'
          '${missing.map((r) => '  line ${r.line}: ${r.package}').join('\n')}'
          '\n\nThis is the shape of the defect DR-088 was written for: a '
          'table describing a dependency the build does not have. Either '
          'install it, or change its status cell to `planned (Mn)`.',
    );
  });

  test('(2) every declared dependency resolves to a row', () {
    final documented = rows.map((r) => r.package).toSet();
    final undocumented =
        declared.keys
            .where((d) => !ours.contains(d) && !documented.contains(d))
            .toList()
          ..sort();
    final named = undocumented
        .map((d) => '  $d (${declared[d]!.join(', ')})')
        .join('\n');
    expect(
      undocumented,
      isEmpty,
      reason:
          'these are declared in a workspace pubspec and have no row in '
          'docs/03-architecture.md §10.1:\n$named'
          '\n\nThis is how screen_retriever sat in the build undocumented: '
          'the table calls itself "the full table" and nothing checked. Add '
          'a row saying what it is for and what happens without it.',
    );
  });

  test('(3) no `planned` row is already installed', () {
    final live = rows
        .where((r) => r.isPlanned && declared.containsKey(r.package))
        .toList();
    final named = live
        .map((r) => '  line ${r.line}: ${r.package} is ${r.status}')
        .join('\n');
    expect(
      live,
      isEmpty,
      reason:
          'these rows say `planned` and the package is already declared:\n'
          '$named'
          '\n\nA plan that shipped and was never marked shipped is a stale '
          'record nobody edited, which is exactly the failure mode this '
          'gate exists for. Flip the status cell to `in use`.',
    );
  });
}
