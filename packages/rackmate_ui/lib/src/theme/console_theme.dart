// The console theme. DR-090 (canon §11.89), board #770.
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE DEFINES NO COLOUR
// ═════════════════════════════════════════════════════════════════════
// Every value comes from `console_palette.dart` in `rackmate_core`, where
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
import 'package:rackmate_core/rackmate_core.dart';

Color _c(int argb) => Color(argb);

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
  const scheme = ColorScheme.dark(
    surface: Color(kConsoleCard),
    onSurface: Color(kConsolePrimaryText),
    primary: Color(kConsoleActive),
    onPrimary: Color(kConsoleCanvas),
    secondary: Color(kConsoleNotice),
    onSecondary: Color(kConsoleCanvas),
    // Material insists on an error colour and widgets reach for it. It is
    // Critical's value so a stray use is at least the right hue, but
    // §11.89.6 still applies: anything that MEANS a severity goes through
    // `ConsoleStatus` and carries a second cue.
    error: Color(kConsoleCritical),
    onError: Color(kConsoleControlText),
    outline: Color(kConsoleInactiveSurface),
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
