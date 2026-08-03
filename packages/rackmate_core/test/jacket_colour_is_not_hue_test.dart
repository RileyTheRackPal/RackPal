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
// THE TWO HOLES THIS FILE SHIPPED WITH, AND THE THREE GUARDS THAT NOW
// STOP THEM COMING BACK
// ─────────────────────────────────────────────────────────────────────
// It shipped scanning two roots and naming nine names, and BOTH lists
// were wrong in the place it mattered:
//
//  * `packages/rackmate_ui/lib/src/draw` and `.../lib/src/canvas` were
//    not scanned. They are not future work — `flutter_canvas.dart` and
//    the three `CustomPainter`s in `canvas/` are what puts colour on the
//    screen TODAY. A probe file naming all nine banned names was dropped
//    into `lib/src/draw` and the gate stayed green.
//  * `JacketColorId` (the id TYPE) and `asBuiltColorId` (the accessor
//    the comment below already called the most tempting one) were not
//    banned. `Rgb wireHueFor(JacketColorId id, …)` — the exact coupling
//    CR-078 rejects — passed, because the regex is case-sensitive and
//    `jacketColorId` does not match `JacketColorId`.
//
// So the configuration is now itself under test, three ways:
//
//  1. EVERY named root must EXIST. A skipped root is the failure that
//     shipped; a renamed directory must be a red test, not a silent
//     narrowing of the scan. (The old header invited naming a directory
//     that did not exist yet — that permission is withdrawn: add the
//     line when the directory lands.)
//  2. EVERY banned name must be a REAL symbol in `lib/`. A typo — the
//     British `jacketColourId`, a name that outlived its class — makes a
//     ban silently vacuous, which is the same class of defect as an
//     unscanned root.
//  3. THE DETECTOR ITSELF MUST FIRE. `the gate itself can fail` below
//     runs the real matcher over a synthetic drawing source carrying the
//     coupling, in the spirit of `session_layering_test.dart` RULE 15b.
import 'dart:io';

import 'package:test/test.dart';

/// The drawing surfaces jacket colour must never reach. Add a line when
/// a new one appears; see the header. Every entry must exist — a missing
/// root fails this suite rather than being skipped.
const List<String> _roots = [
  'lib/src/draw',
  '../rackmate_export/lib/src/draw',
  // The Flutter side. `draw/` holds the canvas adapter and `canvas/`
  // holds the `CustomPainter`s (`editing_overlay_painter.dart`,
  // `grid_painter.dart`, `render_device_box.dart`) that actually put
  // colour on a screen in this build — which is why omitting them left
  // the gate advertising a protection it did not provide.
  '../rackmate_ui/lib/src/draw',
  '../rackmate_ui/lib/src/canvas',
];

/// The names that would carry the fact into the drawing layer.
///
/// EXTEND THIS WHENEVER THE FEATURE GROWS A NAME. The exception half
/// (`jacketColorPulledId` and the resolver) added four, and leaving them
/// out would have left the gate with a hole exactly where the newest —
/// and therefore least-understood — code is.
///
/// NOT BANNED, DELIBERATELY: the bare words `keystone` and `asBuilt`.
/// Both are ordinary drawing vocabulary — a keystone termination symbol
/// on an elevation, an `AS-BUILT` stamp in a title block — so banning
/// them would produce a false positive on legitimate drawing code, and a
/// gate that cries wolf gets weakened. The `…ColorId` spellings below
/// are the ones that actually carry a colour, and a drawing source can
/// only reach `ResolvedJacketColor.keystone`/`.asBuilt` through a name
/// that IS banned.
const List<String> _bannedNames = [
  'jacketColorId',
  'jacketColorConventions',
  'JacketColorId',
  'JacketColorDef',
  'buildDefaultJacketColorConvention',
  // The exception half. `asBuiltColorId` is the most tempting of these
  // to reach for in a renderer ("just draw the wire the colour it
  // actually is"), and it is exactly the coupling CR-078 rejected.
  'jacketColorPulledId',
  'asBuiltColorId',
  'keystoneColorId',
  'ResolvedJacketColor',
  'resolveJacketColor',
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

/// THE WHOLE DETECTOR, in one function so the suite can run it over a
/// synthetic source as well as over the tree. [source] is raw; comment
/// stripping happens here.
List<String> _offendersIn(String path, String source) {
  final stripped = _stripComments(source);
  return [
    for (final name in _bannedNames)
      if (RegExp('(?<![\\w\$])$name(?![\\w\$])').hasMatch(stripped))
        '$path: names $name',
  ];
}

void main() {
  test('every named drawing root EXISTS and is scanned', () {
    // GUARD 1. The hole that shipped: `../rackmate_ui/lib/src/draw` was
    // simply absent from the list, and the old header licensed absence
    // by saying missing roots are skipped. A root that stops resolving
    // must be loud.
    final missing = _roots.where((p) => !Directory(p).existsSync()).toList();
    expect(
      missing,
      isEmpty,
      reason:
          'a drawing root named here no longer resolves, so it is not '
          'being scanned and this gate has quietly narrowed. Roots are '
          'relative to the package root — run this suite from '
          'packages/rackmate_core — and a directory that has genuinely '
          'moved must be RENAMED in `_roots`, not dropped:\n'
          '${missing.join('\n')}',
    );
  });

  test('every banned name is a real symbol in lib/ (no vacuous ban)', () {
    // GUARD 2. A misspelled ban matches nothing and reads as protection.
    // Scoped to `lib/` of this package because every name in the list is
    // declared here.
    final sources = [
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')))
        f.readAsStringSync(),
    ];
    final undeclared = [
      for (final name in _bannedNames)
        if (!sources.any(
          (s) => RegExp('(?<![\\w\$])$name(?![\\w\$])').hasMatch(s),
        ))
          name,
    ];
    expect(
      undeclared,
      isEmpty,
      reason:
          'these banned names do not exist in rackmate_core/lib, so they '
          'ban nothing. Either the spelling is wrong or the symbol was '
          'deleted and the line should go with it:\n${undeclared.join(', ')}',
    );
  });

  test('the gate itself can fail', () {
    // GUARD 3. RULE 15b's shape: the detector run over the exact source
    // that got past the shipped version. If this ever passes empty, the
    // green result below means nothing.
    const planted = '''
import 'package:rackmate_core/rackmate_core.dart';

// A comment naming jacketColorId is fine and must not be flagged.
Rgb wireHueFor(JacketColorId id, Map<JacketColorId, Rgb> reels) =>
    reels[id] ?? const Rgb(0, 0, 0);

Rgb hueFromResolved(ResolvedJacketColor r, Map<JacketColorId, Rgb> reels) =>
    reels[r.asBuiltColorId!] ?? const Rgb(0, 0, 0);
''';
    expect(
      _offendersIn('probe.dart', planted).map((o) => o.split('names ').last),
      containsAll(<String>[
        'JacketColorId',
        'asBuiltColorId',
        'ResolvedJacketColor',
      ]),
      reason:
          'the two spellings that got past the shipped gate were the id '
          'TYPE and `asBuiltColorId`. If they are not flagged here, the '
          'clean result below is worth nothing.',
    );

    // ...and the comment-stripping half still holds, or the gate would
    // fire on prose explaining the rule.
    expect(
      _offendersIn('probe.dart', '// mentions jacketColorId in prose\n'),
      isEmpty,
    );
  });

  test('no drawing-layer source names jacket colour (CR-078/PAL-1)', () {
    var scanned = 0;
    final offenders = <String>[];
    for (final root in _roots) {
      for (final file
          in Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        scanned++;
        offenders.addAll(_offendersIn(file.path, file.readAsStringSync()));
      }
    }

    // VACUITY GUARD. A rename of `lib/src/draw/` would otherwise turn
    // this into a test that passes by scanning nothing at all.
    expect(
      scanned,
      greaterThan(20),
      reason:
          'the scanner found almost no drawing sources — the four roots '
          'carry the canvas, the IR ops, the scene builders, the sheet '
          'furniture, the PDF canvas and the Flutter painters, so the '
          'walk has stopped finding real code',
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
