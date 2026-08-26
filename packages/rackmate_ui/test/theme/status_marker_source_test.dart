// The bypass, gated. DR-090 §11.89.6, board #774.
//
// `status_marker_test.dart` proves the five marks differ once the colour
// is deleted. That is only half the rule: it says nothing about a widget
// that reaches past `StatusMarker`, takes `ConsoleStatus.critical.fill`
// and paints a rectangle with it.
//
// THE RULE ITSELF CANNOT BE GATED and this file is where that is said.
// "Carries a second cue" is a claim about a rendered marker, and nothing
// short of rendering every screen and asking a person could check it in
// general. What CAN be gated is the one construction that makes the rule
// true, and whether anything walks around it.
//
// So: `ConsoleStatus.fill` is reachable from exactly one file. Not
// because the colour is precious, but because every OTHER route to it is
// a route with no shape attached.
//
// ITS BLIND SPOT, stated because a gate whose limits are undocumented
// gets trusted past its evidence: this reads source text. A widget that
// obtained the colour indirectly, through a variable passed from
// somewhere else or through `Theme.of(context).colorScheme.error`, is
// invisible here. The `error` slot is the known hole and DR-090 §11.89.6
// accepts it deliberately, which is why the theme comments say a stray
// use is at least the right hue.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where a severity colour is allowed to be turned into a `Color`.
const _permitted = <String>{
  'lib/src/theme/status_marker.dart',
  // Where `fill` is DEFINED. Excluding it would be excluding the subject.
  'lib/src/theme/console_theme.dart',
};

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('ConsoleStatus.fill is reached from one file only', () {
    final offenders = <String>[];
    var scanned = 0;

    for (final file in _dartFiles('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      scanned++;
      if (_permitted.any(path.endsWith)) continue;
      final src = file.readAsStringSync();
      // `.fill` on a `ConsoleStatus`, however it is spelled at the call
      // site: `ConsoleStatus.critical.fill`, or `status.fill` where
      // `status` is one.
      if (RegExp(r'ConsoleStatus\.\w+\.fill|\bstatus\.fill\b').hasMatch(src)) {
        offenders.add(path);
      }
    }

    // NOT VACUOUS: a scan that walked no files would report no offenders
    // and pass. `rackmate_ui` has well over a hundred.
    expect(
      scanned,
      greaterThan(50),
      reason: 'the scan found $scanned files, so it is broken',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'these reach a severity colour without going through '
          'StatusMarker, so nothing guarantees the second cue §11.89.6 '
          'requires: ${offenders.join(', ')}. Use StatusMarker, or add a '
          'reason here and to the ruling.',
    );
  });

  test('and the permitted file actually uses it', () {
    // Guards the list above against becoming a list of files that stopped
    // being relevant, which is how an exemption list rots into cover.
    final marker = File(
      'lib/src/theme/status_marker.dart',
    ).readAsStringSync();
    expect(
      marker,
      contains('status.fill'),
      reason:
          'StatusMarker no longer paints the severity colour, so this '
          'gate is guarding a route nobody takes',
    );
  });
}
