// The console theme. DR-090 (canon §11.89), board #770.
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE DEFINES NO COLOUR
// ═════════════════════════════════════════════════════════════════════
// Every value comes from `console_palette.dart` in `rackpal_core`, where
// `contrast.dart` can check it and `console_palette_test.dart` does. A hex
// literal added here would be a second copy of a fact, which is the shape
// CR-080's font drift, the `family_glyph` measurement and DR-080 §11.79.4
// each warn about in their own register. If a colour is needed and is not
// below, it belongs in the palette first.
//
// ═════════════════════════════════════════════════════════════════════
// STATUS COLOUR IS NOT IN THE ColorScheme, AND THAT IS DELIBERATE
// ═════════════════════════════════════════════════════════════════════
// Material's `error` slot is the only status-shaped thing a `ColorScheme`
// has, and mapping Critical onto it would let any widget pick up a
// severity by accident. §11.89.6 requires that a status marker carry a
// second cue that survives its colour being deleted, and a colour reached
// through `Theme.of(context).colorScheme.error` arrives with no way to
// carry one. Status is therefore reached through [ConsoleStatus], which
// hands back a colour AND the ink that belongs on it, so the two cannot
// be separated by a caller in a hurry.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

Color _c(int argb) => Color(argb);

/// The emphasis weight, and the only heavier one the bundle can draw.
///
/// ═════════════════════════════════════════════════════════════════════
/// A CONSTANT BECAUSE TWENTY-EIGHT LITERALS IS HOW THE LAST ONE DRIFTED
/// ═════════════════════════════════════════════════════════════════════
/// These sites asked for `w700` (22 of them) and `w600` (6) against a
/// bundle that carried only Regular, so Flutter SYNTHESISED both. That
/// made the two-tier emphasis notional: a reader saw one faked weight
/// wherever either was requested, and on a geometric face synthesis
/// closes the counters before it thickens the stems.
///
/// DR-090 §11.89.8 bundled Jost Medium, so there is now exactly one real
/// weight above Regular and this names it. Collapsing `w600` and `w700`
/// onto it loses nothing that was ever drawn.
///
/// WHEN A SECOND REAL WEIGHT ARRIVES, this is the one line that decides
/// what "emphasis" means, and a second constant beside it is how a real
/// two-tier hierarchy would start. A literal at a call site is a decision
/// nobody can find again.
const FontWeight kConsoleEmphasis = FontWeight.w500;

/// The five severities, as the only supported way to reach a status colour.
enum ConsoleStatus {
  critical(kConsoleCritical),
  warning(kConsoleWarning),
  caution(kConsoleCaution),
  notice(kConsoleNotice),
  nominal(kConsoleNominal);

  const ConsoleStatus(this._argb);

  final int _argb;

  /// The severity's colour, for use as a FILL.
  ///
  /// Critical fails AA as text on Card at 2.49:1 and is a fill only
  /// (§11.89.4). The others may be used as ink; that is not enforced here
  /// because the check belongs to whatever draws them.
  Color get fill => _c(_argb);

  /// The ink that belongs on [fill], decided by the project's one
  /// luminance definition rather than restated per call site.
  Color get ink =>
      prefersLightInk(_argb) ? _c(kConsoleControlText) : _c(kConsoleCanvas);
}

/// The surfaces and text tiers, for widgets that need a token the Material
/// `ColorScheme` has no slot for.
abstract final class ConsoleColors {
  static Color get canvas => _c(kConsoleCanvas);
  static Color get base => _c(kConsoleBase);
  static Color get card => _c(kConsoleCard);
  static Color get buttonBase => _c(kConsoleButtonBase);

  static Color get primaryText => _c(kConsolePrimaryText);
  static Color get controlText => _c(kConsoleControlText);
  static Color get active => _c(kConsoleActive);
  static Color get secondaryText => _c(kConsoleSecondaryText);
  static Color get nonCriticalText => _c(kConsoleNonCriticalText);

  /// Tracks, borders, dividers. NOT text: see [inactiveInk].
  static Color get inactiveSurface => _c(kConsoleInactiveSurface);

  /// Disabled labels and icons.
  static Color get inactiveInk => _c(kConsoleInactiveInk);
}

/// The application theme.
///
/// `fontFamily` is Jost (§11.89.8): before it was set the app drew its
/// diagram in Jost and its chrome in the platform default, which on
/// Windows is Segoe UI.
ThemeData buildConsoleTheme() {
  // ═════════════════════════════════════════════════════════════════════
  // GENERATED FIRST, THEN OVERRIDDEN. NOT HAND-WRITTEN.
  // ═════════════════════════════════════════════════════════════════════
  // The first version of this function built a `ColorScheme.dark(...)` by
  // hand with the nine roles DR-090 rules. The app uses TWENTY-ONE, and the
  // twelve left unspecified did not stay neutral: every `surfaceContainer*`
  // tone collapsed onto `surface`, so the schematic filter bar drew its chips
  // in exactly the colour of the bar behind them and became unreadable;
  // `outlineVariant` resolved to PURE WHITE at nine sites; and
  // `onSurfaceVariant`, which 94 sites use for secondary text, fell back to
  // `onSurface` and flattened the hierarchy it exists to create.
  //
  // Seeding generates a coherent value for every role, including the ones
  // this project has no opinion about. The ruled values are then imposed on
  // top. A role must never be left to a default again: the count is checked
  // in `console_theme_test.dart`.
  final seeded = ColorScheme.fromSeed(
    seedColor: _c(kConsoleNotice),
    brightness: Brightness.dark,
  );

  // The surface ladder, mapped onto the four ruled surfaces. Material wants
  // five tones and DR-090 rules four, so `container` doubles with `low` and
  // `highest` with `high`. That is stated rather than hidden, and the pairs
  // are chosen so no widget draws a surface on its own colour: the filter bar
  // puts `highest` chips on a `low` bar, which is Card on Console Base.
  final scheme = seeded.copyWith(
    surface: _c(kConsoleCard),
    onSurface: _c(kConsolePrimaryText),
    onSurfaceVariant: _c(kConsoleSecondaryText),
    surfaceContainerLowest: _c(kConsoleCanvas),
    surfaceContainerLow: _c(kConsoleBase),
    surfaceContainer: _c(kConsoleBase),
    surfaceContainerHigh: _c(kConsoleCard),
    surfaceContainerHighest: _c(kConsoleCard),
    primary: _c(kConsoleActive),
    onPrimary: _c(kConsoleCanvas),
    secondary: _c(kConsoleNotice),
    onSecondary: _c(kConsoleCanvas),
    outline: _c(kConsoleInactiveSurface),
    outlineVariant: _c(kConsoleInactiveSurface),
    // Material insists on an error colour and widgets reach for it. It is
    // Critical's value so a stray use is at least the right hue, but
    // §11.89.6 still applies: anything that MEANS a severity goes through
    // `ConsoleStatus` and carries a second cue.
    error: _c(kConsoleCritical),
    onError: _c(kConsoleControlText),
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Jost',
  );

  return base.copyWith(
    scaffoldBackgroundColor: _c(kConsoleCanvas),
    canvasColor: _c(kConsoleBase),
    dividerColor: _c(kConsoleInactiveSurface),
    dividerTheme: DividerThemeData(color: _c(kConsoleInactiveSurface)),
    cardTheme: base.cardTheme.copyWith(color: _c(kConsoleCard)),
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: _c(kConsoleCard)),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: _c(kConsoleBase),
      foregroundColor: _c(kConsoleControlText),
    ),
    drawerTheme: base.drawerTheme.copyWith(backgroundColor: _c(kConsoleBase)),
    textTheme: base.textTheme.apply(
      bodyColor: _c(kConsolePrimaryText),
      displayColor: _c(kConsolePrimaryText),
    ),
    // Disabled labels get `inactiveInk`, not `inactiveSurface`. The token
    // split in two because a line needs almost no contrast to be found and
    // a label is a shape the eye has to decode (§11.89.7).
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? _c(kConsoleInactiveInk)
              : _c(kConsoleControlText),
        ),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: _c(kConsoleButtonBase),
      hintStyle: TextStyle(color: _c(kConsoleSecondaryText)),
      labelStyle: TextStyle(color: _c(kConsoleSecondaryText)),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? _c(kConsoleActive)
            : _c(kConsoleInactiveSurface),
      ),
    ),
  );
}
