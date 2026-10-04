// packages/rackpal_ui/lib/src/network/web_page_scope.dart
// NET-A/4a (`#994`), DR-048 §11.47.7, DR-229 §11.228.3: the seam a
// device's "Open web page" launches through.
//
// ═════════════════════════════════════════════════════════════════════
// INJECTED, BECAUSE OPENING A BROWSER IS THE PLATFORM'S AND NOT OURS
// ═════════════════════════════════════════════════════════════════════
// `rackpal_core` has no Flutter import and no platform code, and this
// package does not reach for a channel either: the app supplies the one
// function that opens a URL, on DR-009's `isWindows` pattern and the
// `FolderRevealer` precedent (`#941`). So a widget test supplies a
// recorder and never opens a browser, and a surface with no scope above
// it offers no button rather than one that cannot work.
//
// AN INHERITED WIDGET RATHER THAN A PARAMETER, because the gesture has two
// hosts (DR-229 §11.228.1), the inspector and the Devices view, a dozen
// constructors apart, and threading a callback through both trees would
// be two wirings of one seam.
import 'package:flutter/widgets.dart';

/// Opens [url] in the system's browser; true when the platform accepted
/// it. A false is the platform refusing, never the user cancelling: the
/// confirmation has already been answered by then.
typedef WebPageLauncher = Future<bool> Function(Uri url);

/// Whether [url] is one "Open web page" may open: `http` or `https` with a
/// host (DR-229 §11.228.3).
///
/// THE FIELD IS EDITABLE, so this is what keeps it from being a launcher
/// for anything else. `file:///C:/Windows/System32/cmd.exe` is a URL too,
/// and the platform's "open" verb would run it.
bool isOpenableWebUrl(Uri url) =>
    (url.scheme == 'http' || url.scheme == 'https') && url.host.isNotEmpty;

/// Carries the app's [WebPageLauncher] to the surfaces that offer "Open
/// web page".
class WebPageScope extends InheritedWidget {
  const WebPageScope({required this.launcher, required super.child, super.key});

  final WebPageLauncher launcher;

  /// The launcher above [context], or null when nothing supplies one, in
  /// which case the surface offers no button.
  static WebPageLauncher? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WebPageScope>()?.launcher;

  @override
  bool updateShouldNotify(WebPageScope oldWidget) =>
      launcher != oldWidget.launcher;
}
