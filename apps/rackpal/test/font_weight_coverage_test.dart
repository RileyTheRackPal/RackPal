// Every font weight the UI asks for must be one the bundle can DRAW.
// DR-090 §11.89.8, board #775.
//
// ═════════════════════════════════════════════════════════════════════
// SYNTHESIS IS SILENT, WHICH IS THE WHOLE PROBLEM
// ═════════════════════════════════════════════════════════════════════
// A `TextStyle` asking for a weight the family does not carry does not
// throw, warn, or render as tofu. Flutter picks the nearest face and
// emboldens it, so the app looks approximately right and nothing in the
// suite can tell. Twenty-eight sites asked for `w700` or `w600` against a
// bundle carrying only Regular, for four milestones, and the tell was a
// specimen sheet rather than a test.
//
// Synthesis is worst on exactly this family: a geometric sans closes its
// counters before it thickens its stems, so `a`, `e` and `o` fill in
// before the text looks heavier.
//
// THIS IS THE SAME SHAPE AS `tools/glyph_coverage_check.py`, one layer
// up. That gate asks whether the bundled font has the CODEPOINT; this
// asks whether it has the WEIGHT. Neither is visible in the display list,
// because both backends emit identical ops and only the rasteriser's
// choice of face differs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Weights declared for ONE family under `flutter: fonts:`.
///
/// PER FAMILY, AND THE FIRST DRAFT WAS NOT. It read every `weight:` in
/// the pubspec into one set, which made this whole test vacuous the
/// moment `RackMono` was bundled: Space Mono ships a Bold, so 700 was in
/// the set, so a `FontWeight.w700` on JOST passed against a weight only
/// the mono family has. Caught by mutation, not by reading.
///
/// READ, NOT RESTATED, for the usual reason: a copy of the list goes
/// stale the first time a cut is bundled and then asserts that the UI
/// matches something nobody maintains.
Set<int> _weightsOf(String family) {
  // LINE BY LINE rather than one multi-line regex. The block is a YAML
  // list whose end is "the next thing at this indent", which a regex can
  // express and nobody can read; this walks to the next `- family:` or to
  // `assets:` and stops.
  final lines = File('pubspec.yaml').readAsStringSync().split('\n');
  final start = lines.indexWhere((l) => l.trim() == '- family: $family');
  if (start < 0) return const <int>{};

  final out = <int>{};
  final weight = RegExp(r'weight:\s*(\d+)');
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.startsWith('- family:') || line.startsWith('assets:')) break;
    final m = weight.firstMatch(line);
    if (m != null) out.add(int.parse(m.group(1)!));
  }
  return out;
}

/// Every `FontWeight.wNNN` written in a lib tree, with where it was.
Map<int, List<String>> _requestedWeights() {
  final out = <int, List<String>>{};
  final pattern = RegExp(r'FontWeight\.w(\d00)\b');
  for (final root in <String>['lib', '../../packages/rackpal_ui/lib']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in pattern.allMatches(src)) {
        out
            .putIfAbsent(int.parse(m.group(1)!), () => <String>[])
            .add(f.path.replaceAll(r'\', '/'));
      }
    }
  }
  return out;
}

void main() {
  test('Jost declares exactly Regular and Medium', () {
    // Guards the assertion below against passing because the parse found
    // nothing, and pins the per-family reading that the first draft got
    // wrong: RackMono's Bold must not satisfy a request made against the
    // text family.
    expect(_weightsOf('Jost'), <int>{400, 500});
    expect(
      _weightsOf('RackMono'),
      contains(700),
      reason: 'and this is the 700 that made the first draft vacuous',
    );
  });

  test('the UI never asks for a weight the bundle cannot draw', () {
    // THE DEFAULT FAMILY, because a bare `FontWeight` inherits it. Every
    // weight request in these trees is on Jost: the two `RackMono` call
    // sites set a family and no weight, so nothing asks for a mono cut.
    final declared = _weightsOf('Jost');
    final requested = _requestedWeights();

    // NOT VACUOUS: the scan has to have found something to check. If this
    // fails the regex broke, not the sources.
    expect(
      requested,
      isNotEmpty,
      reason: 'no FontWeight.wNNN found anywhere, so the scan is broken',
    );

    final unsupported = <String>[];
    for (final entry in requested.entries) {
      if (declared.contains(entry.key)) continue;
      final where = entry.value.toSet().toList()..sort();
      unsupported.add(
        'w${entry.key} at ${where.length} site(s), e.g. ${where.first}',
      );
    }

    expect(
      unsupported,
      isEmpty,
      reason:
          'these weights are not bundled, so Flutter will SYNTHESISE them '
          'and nothing will fail: ${unsupported.join('; ')}. Either bundle '
          'the cut or use kConsoleEmphasis, which names the one real '
          'weight above Regular.',
    );
  });
}
