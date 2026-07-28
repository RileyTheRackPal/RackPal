// A SOURCE-LEVEL GATE for the one rule in the jacket-colour design that
// is most likely to rot, because today nothing can violate it and in
// eighteen months everything can.
//
// ─────────────────────────────────────────────────────────────────────
// THE RULE
// ─────────────────────────────────────────────────────────────────────
// `Link.jacketColorId` is the colour of the SHEATH THAT WAS PULLED. It
// is a record of a physical fact about the building. It is NOT the hue a
// wire is drawn in: that is the signal domain's, via PAL-1's effective
// hue (docs/05 §6.1-6.4, CR-078). The two are unrelated, and coupling
// them would be worse than useless — a blue control run and a blue A/V
// run would render identically, and a shop that repaints its convention
// would silently repaint its schematic.
//
// It would also break the palette's own accessibility contract. The
// eight domain hues are Okabe-Ito precisely because they survive a
// colour-vision deficiency; a shop's jacket colours are whatever was on
// the reel and carry no such guarantee. Feeding them into the drawing
// layer would substitute an unvalidated palette for a validated one.
//
// ─────────────────────────────────────────────────────────────────────
// WHY A SCANNER, AND WHY IT IS CHEAP TODAY
// ─────────────────────────────────────────────────────────────────────
// This is a "the code says what it means" property: a running program
// cannot currently tell it apart from its negation, because
// `Registries.signalDomains`/`signalFamilies` are EMPTY in every shipped
// document and `pal1_conformance_test.dart` does not exist yet, so there
// is at present no Dart code path that COULD consume a jacket colour as
// a hue. That is exactly why the gate is worth writing now — it is free
// today and it is what stops the coupling being introduced casually when
// the palette is finally ported.
//
// Same family, same shape and same vacuity guard as
// `no_flutter_import_test.dart`, `draw_source_gate_test.dart` and
// `internal_setter_grep_test.dart`.
//
// ─────────────────────────────────────────────────────────────────────
// EXTENDING IT IS ONE LINE
// ─────────────────────────────────────────────────────────────────────
// [_roots] below is the whole configuration. When the domain palette is
// ported and real hues start being drawn, `../rackmate_ui/lib/src/canvas`
// and `../rackmate_export/lib/src/draw` join the list — do that rather
// than concluding the gate has stopped applying. Missing roots are
// skipped, not failed, so the list can name a directory that does not
// exist yet.
import 'dart:io';

import 'package:test/test.dart';

/// The drawing surfaces jacket colour must never reach. Add a line when
/// a new one appears; see the header.
const List<String> _roots = [
  'lib/src/draw',
  '../rackmate_export/lib/src/draw',
];

/// The names that would carry the fact into the drawing layer.
///
/// EXTEND THIS WHENEVER THE FEATURE GROWS A NAME. The exception half
/// (`jacketColorPulledId` and the resolver) added four, and leaving them
/// out would have left the gate with a hole exactly where the newest —
/// and therefore least-understood — code is.
const List<String> _bannedNames = [
  'jacketColorId',
  'jacketColorConventions',
  'JacketColorDef',
  'buildDefaultJacketColorConvention',
  // The exception half. `asBuiltColorId` is the most tempting of these
  // to reach for in a renderer ("just draw the wire the colour it
  // actually is"), and it is exactly the coupling CR-078 rejected.
  'jacketColorPulledId',
  'ResolvedJacketColor',
  'resolveJacketColor',
  'JacketColorRollup',
  'jacketColorRollup',
];

/// Strips `//` and `/* */` comments, so prose DESCRIBING the rule — a
/// doc comment in the drawing layer explaining why it does not read
/// jacket colour — is never mistaken for a violation. Same helper, same
/// reason, as the sibling gates.
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

void main() {
  test('no drawing-layer source names jacket colour (CR-078/PAL-1)', () {
    final present = _roots.where((p) => Directory(p).existsSync()).toList();
    expect(
      present,
      contains('lib/src/draw'),
      reason:
          'this gate resolves its roots relative to the package root — '
          'run this suite from packages/rackmate_core',
    );

    var scanned = 0;
    final offenders = <String>[];
    for (final root in present) {
      for (final file in Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        scanned++;
        final source = _stripComments(file.readAsStringSync());
        for (final name in _bannedNames) {
          if (RegExp('(?<![\\w\$])$name(?![\\w\$])').hasMatch(source)) {
            offenders.add('${file.path}: names $name');
          }
        }
      }
    }

    // VACUITY GUARD. A rename of `lib/src/draw/` would otherwise turn
    // this into a test that passes by scanning nothing at all.
    expect(
      scanned,
      greaterThan(10),
      reason:
          'the scanner found almost no drawing sources — `lib/src/draw/` '
          'carries the canvas, the IR ops, the scene builders and the '
          'sheet furniture, so the walk has stopped finding real code',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'a drawing source naming jacket colour has coupled the colour '
          'of the cable in the wall to the hue of the line on the sheet. '
          "They are unrelated facts: the hue is the signal domain's "
          '(PAL-1 effective hue, docs/05 §6.1), and the domain palette is '
          'Okabe-Ito because it survives a colour-vision deficiency, '
          "which a shop's reel colours do not.",
    );
  });
}
