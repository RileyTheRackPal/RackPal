// Three SOURCE-LEVEL gates, for properties that a running program cannot
// currently tell apart from their negation. Two are about the drawing
// layer; the third is about these gates themselves.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY SOURCE AND NOT BEHAVIOUR
// ─────────────────────────────────────────────────────────────────────────
// Both are "the code says what it means" properties whose violation is
// invisible TODAY and becomes a wrong sheet LATER:
//
//   1. `Stroke`'s two CR-082 knobs. `scaleWithGeometry` decides whether a
//      width scales with the CTM; `hairlineFloor` decides which print
//      floor applies. Both backends used to branch on `hairlineFloor`
//      ALONE for both decisions, so writing `hairlineFloor: true` and
//      leaving `scaleWithGeometry` at its default silently meant "and do
//      not scale". Splitting them changed the meaning of every such
//      stroke — in this repository, exactly one. A stroke that names one
//      knob and inherits the other is therefore a stroke whose author did
//      not decide, and the next rewrite will decide for them.
//
//   2. `RackSceneOptions.forPrint`. It forces all seven of today's fields,
//      so `copyWith(...)` and `const RackSceneOptions().copyWith(...)`
//      are behaviourally identical and the mutation between them survives
//      every suite. The regression it guards against is a field added to
//      the class LATER and silently discarded on every printed sheet.
//      `scene_builder_test.dart` pins `copyWith`'s completeness; this pins
//      that `forPrint` goes through it, on the receiver.
//
//   3. Every `*_test.dart` a production comment NAMES exists. A
//      source-level gate is only as good as the reader who can find it,
//      and `spec.dart` spent this stage sending that reader to
//      `stroke_flag_pairing_test.dart` — a file that has never existed in
//      this repository. Following it and finding nothing is
//      indistinguishable from finding that the gate was deleted, which is
//      the one failure a gate like this cannot survive. The citation
//      itself therefore has to be checked by something, and the only
//      thing that can check it is a scanner.
//
// Mechanical scanners, like the sibling gates in this package
// (`no_flutter_import_test.dart`, `internal_setter_grep_test.dart`). Each
// asserts it actually found something, so a rename cannot turn it into a
// test that passes by scanning nothing.

import 'dart:io';

import 'package:test/test.dart';

/// Strips `//` and `/* */` comments so prose describing a rule — this
/// file's own header, or a doc comment naming a flag — is never mistaken
/// for a violation.
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

List<File> _dartFilesUnder(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    throw StateError(
      'no $path/ from ${Directory.current.path} — run this suite from the '
      'package root',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// A `Stroke(` constructor call through its balanced closing paren.
///
/// `Stroke` takes no positional arguments and its named arguments are
/// simple expressions in every production site, but `lifecycleStroke`'s
/// `dash: const <double>[4, 2]` nests brackets, so the scan counts depth
/// rather than stopping at the first `)`.
Iterable<String> _strokeCalls(String source) sync* {
  final opener = RegExp(r'(?<![\w$])Stroke\s*\(');
  for (final match in opener.allMatches(source)) {
    var depth = 0;
    for (var i = match.end - 1; i < source.length; i++) {
      final c = source[i];
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') {
        depth--;
        if (depth == 0) {
          yield source.substring(match.start, i + 1);
          break;
        }
      }
    }
  }
}

void main() {
  group('CR-082: the two Stroke knobs are decided together', () {
    test('every production Stroke that names hairlineFloor also names '
        'scaleWithGeometry', () {
      // Scans BOTH backends' packages as well as core: a stroke built in
      // rackmate_ui or rackmate_export is subject to the identical
      // ambiguity, and the whole point of the shared IR is that a stroke
      // means one thing on both.
      final roots = <String>[
        'lib',
        '../rackmate_ui/lib',
        '../rackmate_export/lib',
      ].where((p) => Directory(p).existsSync()).toList();
      expect(roots, contains('lib'));

      var withFloor = 0;
      final offenders = <String>[];
      for (final root in roots) {
        for (final file in _dartFilesUnder(root)) {
          for (final call in _strokeCalls(
            _stripComments(file.readAsStringSync()),
          )) {
            if (!call.contains('hairlineFloor')) continue;
            withFloor++;
            if (!call.contains('scaleWithGeometry')) {
              offenders.add('${file.path}: ${call.replaceAll('\n', ' ')}');
            }
          }
        }
      }

      expect(
        withFloor,
        greaterThanOrEqualTo(2),
        reason:
            'the scanner found almost no Stroke(... hairlineFloor ...) at '
            'all — `sheet_frame.dart`s sheetRule and `symbol_layer.dart`s '
            'header rule are both supposed to be in this set, so the '
            'pattern has stopped matching real code',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'a Stroke that sets hairlineFloor and inherits '
            'scaleWithGeometry has not decided whether its width scales; '
            'that is the ambiguity that flipped the schematic header '
            'rule when the two flags were finally split apart',
      );
    });
  });

  group('RackSceneOptions.forPrint takes the receiver', () {
    test('it is expressed as copyWith on `this`, never as a fresh value',
        () {
      final source = _stripComments(
        File('lib/src/draw/scene/scene_builder.dart').readAsStringSync(),
      );
      final body = RegExp(
        r'RackSceneOptions\s+forPrint\s*\([^)]*\)\s*=>(.*?);',
        dotAll: true,
      ).firstMatch(source);

      expect(
        body,
        isNotNull,
        reason:
            'forPrint was not found in the shape this gate can read — if '
            'it has become a block body, teach the gate that shape rather '
            'than deleting it',
      );
      final expression = body!.group(1)!;
      expect(
        expression.trimLeft(),
        startsWith('copyWith('),
        reason:
            'forPrint must delegate to copyWith on the RECEIVER. Building '
            'a fresh RackSceneOptions here discards every field the '
            'caller set and every field added to the class after today, '
            'and no behavioural test can see it while forPrint happens to '
            'force all of them',
      );
      expect(
        expression,
        isNot(contains('RackSceneOptions(')),
        reason: 'a fresh value inside forPrint is the mutation itself',
      );
    });
  });

  group('every test file a production comment cites actually exists', () {
    test('no source in any package sends its reader to a file that is not '
        'there', () {
      // REPO-WIDE ON PURPOSE. Citations cross package boundaries in both
      // directions already — `rack_load_gutter.dart` (core) names
      // `elevation_omission_line_test.dart` (export), `print_units.dart`
      // names `page_sizes_test.dart` — so a gate that could only see this
      // package would pass by not looking.
      expect(
        Directory('../../packages/rackmate_core').existsSync(),
        isTrue,
        reason:
            'this gate resolves the repository root as ../.. from the '
            'package root — run this suite from packages/rackmate_core',
      );

      // Every `.dart` basename that exists, anywhere the repository keeps
      // source. `build/` and `.dart_tool/` are generated copies; matching
      // against them would let a citation stay "valid" after the file it
      // names was deleted.
      final existing = <String>{};
      final citations = <String, Set<String>>{};
      for (final area in const ['../../packages', '../../apps']) {
        for (final entity in Directory(area).listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final parts = entity.path.split(RegExp(r'[\\/]'));
          if (parts.contains('build') || parts.contains('.dart_tool')) {
            continue;
          }
          existing.add(parts.last);
          // Citations are read out of `lib/` only: a test may legitimately
          // discuss a file that does not exist — this file's own header
          // names the very one that did not.
          if (!parts.contains('lib')) continue;
          for (final m in RegExp(
            r'[A-Za-z0-9_]+_test\.dart',
          ).allMatches(entity.readAsStringSync())) {
            citations
                .putIfAbsent(m.group(0)!, () => <String>{})
                .add(entity.path);
          }
        }
      }

      expect(
        citations.length,
        greaterThanOrEqualTo(20),
        reason:
            'the scanner found almost no citations at all — production '
            'source is dense with them, so the pattern has stopped '
            'matching real code',
      );

      final dangling = {
        for (final entry in citations.entries)
          if (!existing.contains(entry.key)) entry.key: entry.value.toList(),
      };
      expect(
        dangling,
        isEmpty,
        reason:
            'these comments name a test file that does not exist. A reader '
            'following the reference to confirm the rule is still enforced '
            'finds nothing, which reads exactly like the gate having been '
            'deleted',
      );
    });
  });
}
