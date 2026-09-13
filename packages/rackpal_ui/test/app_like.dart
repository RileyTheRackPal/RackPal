// Mounting a screen the way the APP mounts it (DR-159 §11.158.3).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS HAD TO EXIST
// ═══════════════════════════════════════════════════════════════════════
// Undo and redo were `KeyScope.rack` rows until DR-159, so a widget test
// that pumped `RackCanvasScreen` under a bare `MaterialApp` got `Ctrl+Z`
// from the screen's own `Shortcuts` and thirty-nine cases passed. Six of
// the seven tabs in the real product were dead the whole time.
//
// The ruling puts the binding at the app root, where the document lives,
// and that is the ONE installation point. So a test that pumps a screen
// alone is pumping a configuration the product does not ship, and the
// honest fix is to give it the root's shortcuts rather than to give the
// screen a second copy of them.
//
// **THIS IS THE FOURTH TIME IN A WEEK A FIXTURE STOOD IN FOR A PROOF.**
// `.okf/practices/a-fixture-default-is-not-a-proof.md` records the
// others, the most recent being `#871`'s browser card, where a null
// `onEdit` meant no double-tap recogniser and every press landed in the
// test while none landed in the shell.
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// The shortcut map `main.dart` installs on `MaterialApp`, verbatim.
///
/// Pass it to any `MaterialApp` in a widget test that expects a GLOBAL
/// key to work: undo, redo, the four file keys, the view switches and
/// the validation keys all live above the root focus scope.
Map<ShortcutActivator, Intent> appGlobalShortcuts() => {
  ...WidgetsApp.defaultShortcuts,
  ...keymapShortcuts(KeyScope.global),
};
