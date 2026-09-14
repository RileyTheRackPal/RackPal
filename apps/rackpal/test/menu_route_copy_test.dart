// No on-screen string may name a route the application does not have
// (`#888`, `#894`, DR-168).
//
// ═══════════════════════════════════════════════════════════════════════
// A PHRASE REPEATED EIGHTEEN TIMES READS AS VOCABULARY
// ═══════════════════════════════════════════════════════════════════════
// `Project ▸ Locations…` was the route CR-112's ellipsis promised. DR-091
// §11.90 promoted Locations to a tab and deleted the `Project` menu, and
// the phrase stayed in eighteen places across both UI packages and the
// app. **Three of them were on screen**, and each fired exactly when
// somebody had no rooms and needed one:
//
//   * *"This project has no rooms yet. Add one in Project ▸ Locations…"*
//   * *"Rooms are named in Project ▸ Locations…"*
//   * *"also named in Project ▸ Locations…"*
//
// docs/04 §3.4's rule is about a control that silently does nothing. This
// is a step further: an instruction that cannot be followed. It survived
// because the other fifteen sites were comments, so the phrase read as
// established vocabulary and nobody checking one of them doubted it.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THE MENU GLYPH AND NOT A LIST OF ROUTE NAMES
// ═══════════════════════════════════════════════════════════════════════
// `▸` is how this corpus writes a menu path and it appears in no other
// context, so its presence in a STRING is the whole signal. A test that
// enumerated the menus the app has would need updating whenever one was
// added, which is the second copy of a moving fact this repository keeps
// paying for. This one reads the REAL menu bar instead, so it notices a
// menu being removed, which is precisely what happened here.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';

import 'session/session_fakes.dart';

void main() {
  late TextMeasurer measurer;

  setUpAll(() {
    final bytes = File('assets/fonts/Jost-Regular.ttf').readAsBytesSync();
    measurer = PdfFontMeasurer.fromBytes(PdfDocument(), {
      const FontRef('Jost'): bytes,
    });
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  /// Every menu path written into a string in `lib/`, as
  /// `file: whole line`.
  ///
  /// **COMMENTS ARE LEFT ALONE, deliberately.** Fifteen of the eighteen
  /// `Project ▸ Locations…` sites were comments recording why something
  /// is the way it is, and a history that may not name a route it is
  /// about is a history that cannot be written.
  List<({String where, String menu})> menuPathsInCopy() {
    final roots = [
      Directory('lib'),
      Directory('../../packages/rackpal_ui/lib'),
      Directory('../../packages/rackpal_core/lib'),
    ];
    final found = <({String where, String menu})>[];
    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final line in const LineSplitter().convert(
          entity.readAsStringSync(),
        )) {
          if (line.trimLeft().startsWith('//')) continue;
          final at = line.indexOf('▸');
          if (at < 0) continue;
          // The word before the glyph is the menu it names.
          final before = line.substring(0, at).trimRight();
          // The word before the glyph, with quotes and whitespace off it.
          final menu = before
              .replaceAll("'", ' ')
              .replaceAll('"', ' ')
              .trim()
              .split(' ')
              .last;
          found.add((where: '${entity.path}: ${line.trim()}', menu: menu));
        }
      }
    }
    return found;
  }

  testWidgets('EVERY MENU PATH IN ON-SCREEN COPY NAMES A MENU THE APP '
      'ACTUALLY HAS', (tester) async {
    await tester.pumpWidget((await buildTestApp(measurer)).app);

    // THE REAL MENU BAR, not a list kept beside it. A hand-kept list of
    // menu names is the second copy of a moving fact this repository
    // keeps paying for; reading the bar means this case notices a menu
    // being REMOVED, which is exactly what happened when DR-091 §11.90
    // deleted `Project` and left three strings pointing at it.
    final menus = tester
        .widgetList<SubmenuButton>(find.byType(SubmenuButton))
        .expand(
          (b) => b.child is Text ? [(b.child! as Text).data!] : <String>[],
        )
        .toSet();
    expect(
      menus,
      isNotEmpty,
      reason: 'no menu bar was found, so this case would assert nothing',
    );

    final paths = menuPathsInCopy();
    expect(
      paths,
      isNotEmpty,
      reason:
          'no copy names a menu at all, so this case would pass over an '
          'app whose every route had been deleted',
    );

    final dangling = [
      for (final p in paths)
        if (!menus.contains(p.menu)) p.where,
    ];
    expect(
      dangling,
      isEmpty,
      reason:
          'each of these tells a user to go to a menu the bar does not '
          'have. `Project ▸ Locations…` was on screen in three places '
          'after DR-091 deleted that menu, and every one of them fired at '
          'the moment somebody needed the route most',
    );
  });
}
