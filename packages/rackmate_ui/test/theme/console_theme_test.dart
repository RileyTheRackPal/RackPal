// DR-090 §11.89, board #770. What these defend is a class of bug, not a colour.
//
// `console_palette_test.dart` in core checks that the RULED values are right.
// Nothing checked the roles this project has no opinion about, and that is
// exactly where the damage was: a hand-written `ColorScheme.dark(...)` set the
// nine roles DR-090 rules, the app uses TWENTY-ONE, and the twelve left over
// did not stay neutral. Every `surfaceContainer*` tone collapsed onto
// `surface`, so the schematic filter bar drew its chips in precisely the
// colour of the bar behind them; `outlineVariant` resolved to pure white at
// nine sites; and `onSurfaceVariant`, which 94 sites use for secondary text,
// fell back to `onSurface`.
//
// None of that is visible to a test that asserts the values it set. So these
// assert the RELATIONSHIPS a usable scheme has to have, which a silently
// defaulted role breaks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

double _lum(Color c) => relativeLuminance(c.toARGB32());

double _contrast(Color a, Color b) {
  final la = _lum(a);
  final lb = _lum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final scheme = buildConsoleTheme().colorScheme;

  group('the surface ladder is a ladder', () {
    test('it does not collapse to one tone', () {
      // The filter-bar bug exactly: chips are `surfaceContainerHighest` and
      // the bar is `surfaceContainerLow`. Equal means invisible.
      expect(
        scheme.surfaceContainerHighest,
        isNot(equals(scheme.surfaceContainerLow)),
        reason: 'chips would be drawn in the colour of the bar behind them',
      );
      expect(
        scheme.surfaceContainerLowest,
        isNot(equals(scheme.surfaceContainerHighest)),
      );
    });

    test('it ascends', () {
      final rungs = <Color>[
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ];
      for (var i = 1; i < rungs.length; i++) {
        expect(
          _lum(rungs[i]),
          greaterThanOrEqualTo(_lum(rungs[i - 1])),
          reason: 'rung $i is darker than the one below it',
        );
      }
    });
  });

  group('text hierarchy survives', () {
    test('onSurfaceVariant is dimmer than onSurface, not equal to it', () {
      // 94 sites use this for secondary text. Equal to `onSurface` renders
      // the whole hierarchy at one brightness and nothing fails.
      expect(scheme.onSurfaceVariant, isNot(equals(scheme.onSurface)));
      expect(_lum(scheme.onSurfaceVariant), lessThan(_lum(scheme.onSurface)));
    });

    test('both clear AA on every rung of the ladder', () {
      for (final surface in <Color>[
        scheme.surface,
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ]) {
        expect(_contrast(scheme.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(scheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('no role was left to a default', () {
    test('outlineVariant is a line colour, not white', () {
      // It resolved to #FFFFFF, at nine sites, and looked like a design
      // choice rather than an omission.
      expect(_lum(scheme.outlineVariant), lessThan(0.10));
      expect(_contrast(scheme.outlineVariant, scheme.surface), lessThan(2.0));
    });

    test('the scheme is dark throughout', () {
      // A single light tone from an unset role is the tell. Anything above
      // this on a console surface is a role nobody chose.
      for (final (name, colour) in <(String, Color)>[
        ('surface', scheme.surface),
        ('surfaceContainerLowest', scheme.surfaceContainerLowest),
        ('surfaceContainerLow', scheme.surfaceContainerLow),
        ('surfaceContainer', scheme.surfaceContainer),
        ('surfaceContainerHigh', scheme.surfaceContainerHigh),
        ('surfaceContainerHighest', scheme.surfaceContainerHighest),
        ('outline', scheme.outline),
        ('outlineVariant', scheme.outlineVariant),
      ]) {
        expect(_lum(colour), lessThan(0.20), reason: '$name is too light');
      }
    });
  });

  group('the ruled values reach the theme', () {
    test('the palette is what the scheme carries', () {
      expect(scheme.surface.toARGB32(), kConsoleCard);
      expect(scheme.onSurface.toARGB32(), kConsolePrimaryText);
      expect(scheme.onSurfaceVariant.toARGB32(), kConsoleSecondaryText);
      expect(scheme.error.toARGB32(), kConsoleCritical);
      expect(scheme.outline.toARGB32(), kConsoleInactiveSurface);
    });

    test('ConsoleStatus hands back ink with its fill', () {
      // §11.89.4: only Critical takes light ink, decided by the project's
      // one luminance definition rather than restated here.
      expect(ConsoleStatus.critical.ink.toARGB32(), kConsoleControlText);
      for (final s in <ConsoleStatus>[
        ConsoleStatus.warning,
        ConsoleStatus.caution,
        ConsoleStatus.notice,
        ConsoleStatus.nominal,
      ]) {
        expect(s.ink.toARGB32(), kConsoleCanvas, reason: '$s took light ink');
      }
    });
  });
}
