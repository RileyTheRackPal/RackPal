// `#872`. A SOURCE-LEVEL GATE for the defect that has now shipped five
// times: a `Command` that is declared, fully implemented, tested, and
// constructed by no code a person can reach.
//
// ═════════════════════════════════════════════════════════════════════
// THE FIVE, AND WHY EACH WAS FOUND BY A HUMAN RATHER THAN A SUITE
// ═════════════════════════════════════════════════════════════════════
// `DR-143` (the importer with no caller), `#674` (`onRemoveGang` declared
// and invoked by nothing), `PLAN-E/5` (six functions and a dialog with no
// caller), `LEN-A/3` (a derivation whose own absence-of-caller test could
// not see the caller, because the scan walked one package), and `#870`
// (`RemovePlanUnderlayCommand`, shipped at `PLAN-C/6` with a real revert,
// a pin cascade and seven tests, built by nothing in any `lib/` for four
// months).
//
// Every one of them compiles, analyses clean, and has green tests. The
// class is used: its own suite constructs it. Nothing in Dart can require
// that a PERSON can get to it.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THE `#674` GATE CANNOT DO THIS JOB
// ═════════════════════════════════════════════════════════════════════
// `actions_have_callers_test.dart` checks function-typed fields on
// `*Actions` records inside `rackpal_ui/lib`. A `Command` class is
// neither a callback nor in that package. **A gate's scope is part of its
// claim**, and that one's scope is narrower than the shape it is named
// for: it also cannot see `ValidationDrawer`, which takes loose callback
// parameters rather than a record, and which is mounted once in the whole
// product with none of them supplied (`#875`).
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS SCANS, AND WHY IT IS A GRAPH AND NOT A GREP
// ═════════════════════════════════════════════════════════════════════
// Three earlier attempts at this census were wrong, and each was wrong in
// a way the next one could only find by checking a known answer first:
//
//   1. matching `Name(` missed every NAMED constructor and reported
//      `SetRoomEstimateCommand` unreachable when it had six production
//      references, wired the day before;
//   2. counting any MENTION in another lib file let a name in a COMMENT
//      count as reachable, and `RemovePlanUnderlayCommand` fell off the
//      list entirely;
//   3. counting constructions by name reported 24 of 72, which is still
//      wrong: this codebase builds most commands through `buildXCommand`
//      functions, so a command constructed only by its own builder reads
//      as unreachable while the BUILDER is what has callers.
//
// So the question has to be asked transitively. The model:
//
//   * a NODE is a top-level declaration in some `*/lib/**.dart`. Members
//     fold into their enclosing top-level declaration, which is the right
//     grain here: a private method on a live widget is live.
//   * an EDGE D to E exists when D's body mentions E's name as an
//     identifier, outside comments and string literals.
//   * ROOTS are every declaration in a UI package, because that is where
//     a person's gesture enters the product.
//   * a Command is REACHABLE when some declaration that CONSTRUCTS it is
//     reachable from a root.
//
// **THE SPLIT IS A SCAN FOR UNINDENTED LINES**, which `dart format` (a
// gate since DR-017) makes reliable: a top-level declaration starts at
// column 0 and everything inside it is indented. The prototype used a
// regex whose character class contained `\s`, which let an INDENTED
// method match as a top-level function; 439 files produced 18,222
// "top-level" declarations and 49 of 73 commands came back unreachable
// with ZERO construction sites, `MoveDeviceCommand` among them, which the
// rack canvas builds on every drag. **The number is what caught it**,
// which is the whole reason this file counts what it found.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS GATE DOES NOT CATCH, STATED BECAUSE A SCOPE IS PART OF A CLAIM
// ═════════════════════════════════════════════════════════════════════
// **EVERY DECLARATION IN A UI PACKAGE IS A ROOT**, which is an
// over-approximation and a deliberate one: deciding which widget is
// actually mounted needs a build-graph this scan does not have, and a
// gate that guessed would cry wolf. The consequence is precise and worth
// knowing.
//
// A command built by a UI method that nothing calls reads as REACHABLE
// here. So does a command built behind a callback parameter that no mount
// supplies, which is exactly `#875`: `ValidationDrawer` declares
// `onAcknowledge`, `onWithdraw` and `onRemedy`, the product mounts it
// once, and it passes none of them. This gate sees those two commands
// only because nothing constructs them ANYWHERE, not because it
// understood the mount.
//
// That half belongs to `actions_have_callers_test.dart` (`#674`), which
// asks whether a declared callback is ever invoked. **Between them they
// still leave a hole**: that gate reads `*Actions` records in
// `rackpal_ui/lib` only, so a widget taking loose callback parameters is
// outside both. Closing it is `#875`'s second half.
//
// ═════════════════════════════════════════════════════════════════════
// THE EXEMPTION LIST IS THE RISK, SO EVERY ROW NAMES ITS DUE DATE
// ═════════════════════════════════════════════════════════════════════
// `.okf/practices/a-tests-exemption-list-is-where-the-bug-lives.md`. A
// list of names is a place to hide; a list of names each pointing at the
// board item that retires it is a set of due dates. **And a row that
// becomes reachable FAILS this gate too**, so the list cannot rot into a
// record of things that were true once.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where the scan runs, relative to `apps/rackpal`.
const List<String> _libRoots = [
  '../../packages/rackpal_core/lib',
  '../../packages/rackpal_ui/lib',
  '../../packages/rackpal_export/lib',
  '../../packages/rackpal_text/lib',
  '../../packages/rackpal_pdfium/lib',
  'lib',
];

/// The packages a person's gesture enters through.
///
/// `rackpal_export` is deliberately NOT here. It renders; it does not
/// offer anybody a button, and a command reachable only from the PDF
/// backend would be a command no gesture can run.
const List<String> _uiRoots = ['../../packages/rackpal_ui/lib', 'lib'];

/// Commands with no reachable construction site that are ALLOWED to have
/// none for now, each against the board item that retires it.
///
/// **A ROW HERE IS A DEBT WITH A NAME, NOT A DISPENSATION.** Adding one
/// without an item is the failure this map exists to prevent, and the
/// test below refuses a row whose value does not look like one.
const Map<String, String> _exempt = {
  // `#875` CLOSED THESE THREE ROWS, AND THE STALENESS CHECK IS WHAT
  // FOUND THE THIRD. Wiring `ValidationDrawer`'s callbacks made
  // `AcknowledgeFindingCommand` and `UnacknowledgeFindingCommand`
  // reachable, which was the point; it ALSO made
  // `AddZeroUChannelCommand` reachable through PWR-003's remedy, which
  // was exempted against `#876` and which nobody was thinking about.
  // This test went red naming all three.

  // `#876` — AC-044 makes the inspector the only way a person creates a
  // 0U occupant and the inspector has no such surface. Two of the three
  // builders in `zero_u_commands.dart` are still callerless; the third
  // is reached only by `#875`'s remedy, which mints a channel as a
  // remedy rather than as a person's gesture, so AC-044's clause is
  // still owed.
  'RemoveZeroUChannelCommand': '#876',
  'SetZeroUPositionCommand': '#876',

  // `#877` CLOSED ITS ROWS. `RemoveOutletCommand` and
  // `RemoveStructureCommand` shipped at M3-A/1 with real reverts and no
  // caller, so a wrong drop or a wrong panel was permanent past the undo
  // window. DR-160 §11.159 wires both through `structure_removal_txn`:
  // the Outlets rail has a trash icon per plate and the editor header an
  // overflow menu, each behind a confirmation that counts what it takes.

  // `#878` — a pin cannot be cleared (only re-placed) and pages cannot
  // be reordered. `LabelKey.clearPlanPin` exists and carries a comment
  // arguing why it deserves its own value, which is a menu entry for a
  // gesture nobody can perform.
  'ClearPlanPinCommand': '#878',
  'ReorderPlanUnderlayCommand': '#878',

  // `#879` CLOSED ITS ROW. The command, `showRuleSeverityDialog` and
  // `RuleOverride`'s reason/author/date were all built at M5-B3 and
  // nothing opened the dialog. Project settings now has a `Rule
  // severities` section beside `Signal colours`, which is where a
  // standing decision about the whole project belongs.

  // `#880` — the only one of the twelve with NO TESTS EITHER, so the
  // first question is whether it should exist at all. DR-039 made
  // project history a journal first; this may be a sketch that outlived
  // its brief. Deleting it is a legitimate outcome.
  'SnapshotCommand': '#880',

  // `#881` — 21 test constructions, the most of any unreachable command,
  // and the hypothesis is that it is SUPERSEDED rather than missing:
  // connections are made through `buildConnectPortsCommand`, which
  // materialises ports under DR-011.1. If so its tests are fixture
  // convenience that reads as coverage.
  'AddLinkCommand': '#881',
};

/// `class Foo extends Command<Bar>`.
final RegExp _commandClass = RegExp(
  r'(?:final |abstract |base |sealed )*class (\w+) extends Command<',
);

final RegExp _typeDecl = RegExp(
  r'\b(?:class|enum|extension|typedef|mixin)\s+(\w+)',
);

/// A top-level callable or variable: `Foo bar(` or `Foo bar =`, with no
/// newline inside the type, which is what keeps an indented method out.
final RegExp _callable = RegExp(
  r'^(?:[\w<>,\?\[\]\.]+[ \t]+)+(\w+)[ \t]*(?:<[^>]*>)?[ \t]*[\(=]',
);

final RegExp _identifier = RegExp(r'[A-Za-z_]\w*');
final RegExp _lineComment = RegExp(r'^[ \t]*///?[^\n]*$', multiLine: true);
final RegExp _blockComment = RegExp(r'/\*.*?\*/', dotAll: true);
final RegExp _stringLiteral = RegExp(
  '\'\'\'.*?\'\'\'|"""(?:.*?)"""|\'(?:\\\\.|[^\'\\\\\n])*\'|"(?:\\\\.|[^"\\\\\n])*"',
  dotAll: true,
);

/// One top-level declaration.
final class _Decl {
  _Decl(this.path, this.name, this.body);

  final String path;
  final String name;
  final String body;

  String get id => '$path::$name';
}

String _strip(String text) => text
    .replaceAll(_blockComment, ' ')
    .replaceAll(_lineComment, '')
    .replaceAll(_stringLiteral, "''");

List<_Decl> _blocksIn(String path, String text) {
  final lines = text.split('\n');
  final starts = <(int, String)>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty || line.startsWith(' ') || line.startsWith('\t')) continue;
    final first = line[0];
    if (first == '}' || first == ']' || first == ')' || first == '@') continue;
    if (line.startsWith('//') ||
        line.startsWith('/*') ||
        line.startsWith('*')) {
      continue;
    }
    if (RegExp(r'^(import|export|part|library)\b').hasMatch(line)) continue;
    final m = _typeDecl.firstMatch(line) ?? _callable.firstMatch(line);
    final name = m?.group(1);
    if (name != null) starts.add((i, name));
  }
  return [
    for (var k = 0; k < starts.length; k++)
      _Decl(
        path,
        starts[k].$2,
        lines
            .sublist(
              starts[k].$1,
              k + 1 < starts.length ? starts[k + 1].$1 : lines.length,
            )
            .join('\n'),
      ),
  ];
}

void main() {
  group('`#872`: every Command is reachable from a person', () {
    late Map<String, String> commandHome;
    late List<_Decl> decls;
    late Set<String> reachableDecls;
    late Map<String, Set<String>> constructedBy;

    setUpAll(() {
      final raw = <String, String>{};
      for (final root in _libRoots) {
        final dir = Directory(root);
        expect(
          dir.existsSync(),
          isTrue,
          reason:
              'the scan root $root does not exist. Run this suite from '
              'apps/rackpal, and if a package was renamed, FIX THE ROOT '
              'above rather than letting the gate silently scan less than '
              'it claims to.',
        );
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          final path = f.path.replaceAll(r'\', '/');
          if (!path.endsWith('.dart')) continue;
          raw[path] = f.readAsStringSync();
        }
      }

      // 1. every Command class, and where it is declared.
      commandHome = <String, String>{};
      for (final entry in raw.entries) {
        for (final m in _commandClass.allMatches(entry.value)) {
          commandHome[m.group(1)!] = entry.key;
        }
      }

      // 2. every top-level declaration.
      decls = [
        for (final entry in raw.entries)
          ..._blocksIn(entry.key, _strip(entry.value)),
      ];
      final declsByName = <String, List<String>>{};
      for (final d in decls) {
        declsByName.putIfAbsent(d.name, () => []).add(d.id);
      }

      // 3. edges, and construction sites.
      final edges = <String, Set<String>>{};
      constructedBy = <String, Set<String>>{};
      final ctor = <String, RegExp>{
        for (final c in commandHome.keys)
          c: RegExp('\\b${RegExp.escape(c)}(?:\\.\\w+)?\\s*\\('),
      };
      for (final d in decls) {
        final idents = _identifier
            .allMatches(d.body)
            .map((m) => m.group(0)!)
            .toSet();
        final out = <String>{};
        for (final name in idents) {
          if (name == d.name) continue;
          final targets = declsByName[name];
          if (targets != null) out.addAll(targets);
          // A CONSTRUCTION, not a mention. The identifier has to be
          // followed by `(` or `.named(`, which is what attempt 2 above
          // got wrong by counting comments as use.
          final rx = ctor[name];
          if (rx != null && rx.hasMatch(d.body)) {
            constructedBy.putIfAbsent(name, () => {}).add(d.id);
          }
        }
        edges[d.id] = out;
      }

      // 4. reachability from the UI packages.
      final roots = [
        for (final d in decls)
          if (_uiRoots.any(d.path.startsWith)) d.id,
      ];
      reachableDecls = {...roots};
      final stack = [...roots];
      while (stack.isNotEmpty) {
        for (final next in edges[stack.removeLast()] ?? const <String>{}) {
          if (reachableDecls.add(next)) stack.add(next);
        }
      }
    });

    test('the scan found a corpus the size of this repository', () {
      // ANTI-VACUITY, and it earns its keep: the prototype's splitter bug
      // showed up HERE first, as 18,222 declarations across 439 files.
      expect(
        decls.length,
        greaterThan(2000),
        reason:
            'fewer declarations than this repository has. The splitter '
            'stopped matching; fix it rather than lowering this.',
      );
      expect(
        decls.length,
        lessThan(9000),
        reason:
            'more "top-level" declarations than this repository has, '
            'which is what an indented method matching as a top-level '
            'function looks like. Every construction inside a method is '
            'then attributed to a node nothing references.',
      );
      expect(
        commandHome.length,
        greaterThanOrEqualTo(70),
        reason:
            'the Command class regex stopped matching. Fix the regex; '
            'do not lower the expectation.',
      );
    });

    test('the graph answers five known questions correctly', () {
      // THE SELF-CHECK IS NOT CEREMONY. Three earlier versions of this
      // census were confidently wrong, and each was caught by an answer
      // somebody already knew. A census that cannot be checked is a
      // census that measures its own regex.
      bool live(String command) => (constructedBy[command] ?? const <String>{})
          .any(reachableDecls.contains);

      expect(live('AddDeviceCommand'), isTrue, reason: 'the busiest command');
      expect(
        live('MoveDeviceCommand'),
        isTrue,
        reason: 'the rack canvas builds one on every drag',
      );
      expect(
        live('SetRoomEstimateCommand'),
        isTrue,
        reason:
            'attempt 1 reported this unreachable on the day it was '
            'wired, because it matched only `Name(`',
      );
      expect(
        live('RemovePlanUnderlayCommand'),
        isTrue,
        reason:
            '`#870` wired it; before that it was the case this whole '
            'gate exists for',
      );
      expect(
        live('RemoveTemplateCommand'),
        isTrue,
        reason:
            '`#871` wired it through `addTemplateRemoval`, which is a '
            'BUILDER: this is the transitive hop attempt 3 could not make',
      );
    });

    test('every exemption names a board item that retires it', () {
      final malformed = [
        for (final e in _exempt.entries)
          if (!RegExp(r'^#\d+$').hasMatch(e.value)) '${e.key} -> ${e.value}',
      ];
      expect(
        malformed,
        isEmpty,
        reason:
            'an exemption must name the board item that retires it. A '
            'list of names is a place to hide; a list of due dates is a '
            'debt somebody can collect.',
      );
    });

    test('no exemption has gone stale', () {
      // WITHOUT THIS THE LIST ROTS INTO A RECORD OF THINGS THAT WERE TRUE
      // ONCE, and the next person reads it as the current state. A
      // command that has since been wired must LEAVE the list, and the
      // way to make that happen is to fail when it has not.
      final nowReachable = [
        for (final name in _exempt.keys)
          if ((constructedBy[name] ?? const <String>{}).any(
            reachableDecls.contains,
          ))
            '$name (exempted against ${_exempt[name]})',
      ];
      expect(
        nowReachable,
        isEmpty,
        reason:
            'these are reachable now. Delete their rows from _exempt '
            'and close the board items they name.',
      );

      final gone = [
        for (final name in _exempt.keys)
          if (!commandHome.containsKey(name)) name,
      ];
      expect(
        gone,
        isEmpty,
        reason:
            'these commands no longer exist. Delete their rows from '
            '_exempt: an exemption for a deleted class is a line nobody '
            'can act on.',
      );
    });

    test('no Command is declared without a path from a person to it', () {
      final unreachable = <String>[];
      for (final entry in commandHome.entries) {
        final name = entry.key;
        if (_exempt.containsKey(name)) continue;
        final sites = constructedBy[name] ?? const <String>{};
        if (sites.any(reachableDecls.contains)) continue;
        final where = entry.value.split('/lib/').last;
        unreachable.add(
          sites.isEmpty
              ? '$name (constructed NOWHERE in any lib) $where'
              : '$name (${sites.length} construction site(s), none of them '
                    'reachable from a UI package) $where',
        );
      }

      expect(
        unreachable,
        isEmpty,
        reason:
            'these Command classes are declared, and no code a person can '
            'reach ever builds one. That is the shape that shipped as '
            'DR-143, `#674`, `PLAN-E/5`, `LEN-A/3` and `#870`, where a '
            'command with a real revert, a correct cascade and seven '
            'tests was built by nothing in any lib for four months. '
            'Either wire it, or add it to _exempt against the board item '
            'that will.',
      );
    });
  });
}
