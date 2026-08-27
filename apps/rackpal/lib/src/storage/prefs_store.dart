// Window geometry and the handful of other out-of-document preferences
// (docs/03-architecture.md §9.5).
//
// TWO FILES, NOT ONE. §9.5 is genuinely ambiguous — "Recent files are a
// JSON list... Window size, position, monitor and maximised state persist
// in the same prefs file". That is read here as "the prefs file, also in
// application support", and the two are SPLIT, because:
//   * recents is written on every open and every save; prefs on every
//     window move and resize (debounced). Different cadences.
//   * one torn file would lose both.
// Both go through the same [AtomicWriter] with `keepBackup: false`, so a
// crash mid-write leaves the previous good copy.
//
// A missing or unparseable prefs.json is a WARNING, not an error: the app
// starts with default geometry and logs it.
//
// NO REGISTRY WRITE HAPPENS HERE. Geometry is persisted into a JSON file
// under the data root, by us — not by `window_manager`, which stores
// nothing itself. That is one part of the portable build's "we write only
// into our own folder" claim.
//
// THE PART THAT IS NOT OURS TO CLAIM is the file dialog, which used to
// write every opened project's name and full path into HKCU\…\ComDlg32
// because `file_selector` had no way to set `FOS_DONTADDTORECENT`. The app
// now drives `IFileDialog` itself and sets it, which keeps the FILE NAMES
// off the host: nothing lands in `OpenSavePidlMRU` any more. But the shell
// writes values under ComDlg32 that RackPal does not control — at
// minimum `LastVisitedPidlMRU` (this executable plus the last folder
// browsed) and `CIDSizeMRU` (this executable, written even on a cancelled
// dialog), measured examples rather than an inventory — and no supported
// option prevents them while the common dialog is the dialog. See
// `session/file_picker.dart` for the measurement and for why this is
// stated as a bound.
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal/src/storage/storage_log.dart';

/// The file name inside the data root.
const String kPrefsFileName = 'prefs.json';

/// The on-disk schema version for prefs.json.
const int kPrefsFormatVersion = 1;

/// §9.5: "a rack editor below ~1000 px wide is unusable".
const double kMinWindowWidth = 1000;

/// Chosen here rather than specified: the shell is a tab strip (~48) plus
/// a toolbar (~40) plus a chip strip (~32) plus a status line (~24) plus
/// the canvas, and a 42U rack at a legible zoom needs ~550 px of canvas.
/// Stated so it can be argued with rather than rediscovered.
const double kMinWindowHeight = 720;

/// A rectangle in logical screen pixels.
///
/// Deliberately NOT `dart:ui`'s `Rect`: this file is a pure store, and
/// [validateRestoredBounds] is pure geometry that must be unit-testable
/// with synthetic display rectangles — no real monitors, no window
/// manager, no Flutter binding.
@immutable
final class WindowBounds {
  const WindowBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  /// The area shared with [other]; zero when they do not overlap.
  double intersectionArea(WindowBounds other) {
    final w = _overlap(left, right, other.left, other.right);
    final h = _overlap(top, bottom, other.top, other.bottom);
    return w * h;
  }

  static double _overlap(double aLo, double aHi, double bLo, double bHi) {
    final lo = aLo > bLo ? aLo : bLo;
    final hi = aHi < bHi ? aHi : bHi;
    return hi > lo ? hi - lo : 0;
  }

  WindowBounds copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) => WindowBounds(
    left: left ?? this.left,
    top: top ?? this.top,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'height': height,
    'left': left,
    'top': top,
    'width': width,
  };

  static WindowBounds? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final left = _asDouble(raw['left']);
    final top = _asDouble(raw['top']);
    final width = _asDouble(raw['width']);
    final height = _asDouble(raw['height']);
    if (left == null || top == null || width == null || height == null) {
      return null;
    }
    // A zero or negative extent is not a window. Reject rather than
    // restore something the user cannot see or grab.
    if (width <= 0 || height <= 0) return null;
    return WindowBounds(left: left, top: top, width: width, height: height);
  }

  static double? _asDouble(Object? v) => switch (v) {
    final int i => i.toDouble(),
    final double d => d.isFinite ? d : null,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is WindowBounds &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'WindowBounds($left, $top, $width x $height)';
}

/// Everything persisted in `prefs.json`.
final class AppPrefs {
  const AppPrefs({
    this.window,
    this.maximized = false,
    this.displayId,
    this.lastSaveDirectory,
    this.coachMarksSeen = const <String>{},
    this.portColumnPacks = const <String, Set<String>>{},
  });

  /// Parses `prefs.json`'s decoded root, defaulting anything missing or
  /// unusable rather than failing. A convenience file must never be able
  /// to stop the app starting.
  factory AppPrefs.fromJson(Object? raw) {
    if (raw is! Map) return const AppPrefs();
    final window = raw['window'];
    final lastSaveDirectory = raw['lastSaveDirectory'];
    final lastDir = lastSaveDirectory is String ? lastSaveDirectory : null;
    final seen = _coachMarksFromJson(raw['coachMarksSeen']);
    final packs = _packsFromJson(raw['portColumnPacks']);
    if (window is! Map) {
      return AppPrefs(
        lastSaveDirectory: lastDir,
        coachMarksSeen: seen,
        portColumnPacks: packs,
      );
    }
    final displayId = window['displayId'];
    return AppPrefs(
      window: WindowBounds.fromJson(window),
      maximized: window['maximized'] == true,
      displayId: displayId is String ? displayId : null,
      lastSaveDirectory: lastDir,
      coachMarksSeen: seen,
      portColumnPacks: packs,
    );
  }

  /// UNKNOWN NAMES ARE KEPT, NOT DROPPED. A pack name this build does
  /// not recognise belongs to a newer one, and a user who runs both
  /// should not have the older build quietly forget their choice. The
  /// grid resolves names to packs and ignores what it cannot place.
  static Map<String, Set<String>> _packsFromJson(Object? raw) {
    if (raw is! Map) return const <String, Set<String>>{};
    return <String, Set<String>>{
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is List)
          entry.key! as String: <String>{
            for (final name in entry.value! as List)
              if (name is String && name.isNotEmpty) name,
          },
    };
  }

  static Set<String> _coachMarksFromJson(Object? raw) {
    if (raw is! List) return const <String>{};
    return <String>{
      for (final id in raw)
        if (id is String && id.isNotEmpty) id,
    };
  }

  /// The restore-down rectangle. `null` means "never saved" and the app
  /// centres a default-size window.
  final WindowBounds? window;

  /// Whether the window was maximised when it was last closed. [window]
  /// is still stored in that case — it is the restore-down rect.
  final bool maximized;

  /// The stable display identifier the window was last on, so a
  /// two-monitor user reopens where they left.
  final String? displayId;

  /// Seeds the next Save As dialog.
  final String? lastSaveDirectory;

  /// The one-time coach marks this USER has already been shown —
  /// DR-012.4 (canon §11.12.4).
  ///
  /// ══════════════════════════════════════════════════════════════════
  /// HERE, AND NOT IN THE DOCUMENT
  /// ══════════════════════════════════════════════════════════════════
  /// §11.12.4 rules both alternatives out by name. Document state "would
  /// re-fire for every new file, and it would put UI chrome inside
  /// CR-117's byte-exact surface — the identical objection that decided
  /// §11.11.4 against pinning every symbol". Unpersisted "is a nag, not a
  /// coach mark". Per USER rather than per project is also what "first
  /// time" means to the person reading it: the second project is not the
  /// first time they have seen the app.
  ///
  /// A SET OF IDS RATHER THAN A BOOLEAN, because docs/04:468 names THREE
  /// marks — "one on first placement, one on first finding, and one on
  /// the first rack→schematic switch". One ships (`rackpal_ui`'s
  /// `kCoachMarkSchematicFilter`); the other two cost nothing to store
  /// when they land, and no schema version when they do.
  ///
  /// ADD-ONLY, which is why [copyWith]'s `??` is safe on it: a mark is
  /// never un-seen. `prefs.json` is a convenience file the user may
  /// delete, and deleting it is the (undocumented, unsupported) way to
  /// see the marks again — the same recourse they already have for a
  /// window position on an unplugged monitor.
  final Set<String> coachMarksSeen;

  /// Which port-grid column packs each device CATEGORY was last left
  /// showing (docs/06 §4.5, M4-E3).
  ///
  /// PER USER AND NOT PER PROJECT, for `coachMarksSeen`'s reason: which
  /// columns an installer likes to see when authoring a network switch is
  /// a fact about the installer. It is also UI chrome, which §11.12.4
  /// rules out of the document by name because it would put it inside
  /// CR-117's byte-exact surface.
  ///
  /// STORED AS NAMES rather than as an enum, because this file outlives
  /// the build that wrote it.
  final Map<String, Set<String>> portColumnPacks;

  /// The packs remembered for [category]; empty when none are.
  Set<String> packsFor(String category) =>
      portColumnPacks[category] ?? const <String>{};

  /// This, with [category]'s packs replaced.
  AppPrefs withPacksFor(String category, Set<String> packs) => copyWith(
    portColumnPacks: <String, Set<String>>{
      ...portColumnPacks,
      category: packs,
    },
  );

  /// Whether [id] has already been shown to this user.
  bool hasSeenCoachMark(String id) => coachMarksSeen.contains(id);

  /// This, plus [id] marked as seen.
  AppPrefs withCoachMarkSeen(String id) =>
      copyWith(coachMarksSeen: <String>{...coachMarksSeen, id});

  AppPrefs copyWith({
    WindowBounds? window,
    bool? maximized,
    String? displayId,
    String? lastSaveDirectory,
    Set<String>? coachMarksSeen,
    Map<String, Set<String>>? portColumnPacks,
  }) => AppPrefs(
    window: window ?? this.window,
    maximized: maximized ?? this.maximized,
    displayId: displayId ?? this.displayId,
    lastSaveDirectory: lastSaveDirectory ?? this.lastSaveDirectory,
    coachMarksSeen: coachMarksSeen ?? this.coachMarksSeen,
    portColumnPacks: portColumnPacks ?? this.portColumnPacks,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'version': kPrefsFormatVersion,
    'window': <String, Object?>{
      if (window != null) ...window!.toJson(),
      'maximized': maximized,
      if (displayId != null) 'displayId': displayId,
    },
    if (lastSaveDirectory != null) 'lastSaveDirectory': lastSaveDirectory,
    // SORTED, so two runs that saw the same marks in a different order
    // write the same bytes. `prefs.json` is not under CR-117 and nothing
    // diffs it today, but a file that churns for no reason is a file
    // whose diffs nobody reads.
    if (coachMarksSeen.isNotEmpty)
      'coachMarksSeen': coachMarksSeen.toList()..sort(),
    // SORTED TWICE, keys and values, for the reason above it: a
    // preferences file that churns is one whose diffs nobody reads.
    if (portColumnPacks.isNotEmpty)
      'portColumnPacks': <String, Object?>{
        for (final key in portColumnPacks.keys.toList()..sort())
          key: portColumnPacks[key]!.toList()..sort(),
      },
  };
}

/// Reads and writes `prefs.json`.
final class PrefsStore {
  PrefsStore({
    required this.fs,
    required this.writer,
    required String dataRoot,
    p.Context? context,
  }) : context = context ?? p.context,
       path = (context ?? p.context).join(dataRoot, kPrefsFileName);

  final FileStore fs;
  final AtomicWriter writer;
  final p.Context context;

  /// The full path of `prefs.json`.
  final String path;

  /// THE LIVE PREFERENCES — what [load] last read or [save] last wrote,
  /// whichever happened more recently.
  ///
  /// ==================================================================
  /// WHY THE CACHE LIVES HERE AND NOT ON THE COMPOSITION ROOT
  /// ==================================================================
  /// `prefs.json` has two writers with nothing in common: a Save As
  /// records `lastSaveDirectory`, and a debounced window move records the
  /// geometry. Neither knows the whole file, so both do
  /// load-modify-write — and whichever of them reads a STALE copy silently
  /// reverts the other's field.
  ///
  /// That is not hypothetical: `AppServices.prefs` used to be the
  /// "current prefs" the geometry recorder read, it was assigned exactly
  /// once (at startup) anywhere in `lib/`, and the only re-assignment in
  /// the repository was a line in `window_chrome_test.dart`. So the suite
  /// was green and production reverted `lastSaveDirectory` to its startup
  /// value 500 ms after the user moved the window. A field whose only
  /// writer is in test code is invisible to the suite by construction —
  /// `session_layering_test.dart` RULE 15 now fails on the SHAPE of that
  /// defect rather than on this one instance of it.
  ///
  /// Holding it on the store means the cache cannot diverge from the
  /// file: every path to `prefs.json` in the app goes through these two
  /// methods.
  AppPrefs get current => _current;
  AppPrefs _current = const AppPrefs();

  /// Loads preferences, falling back to defaults for anything missing or
  /// unreadable.
  Future<AppPrefs> load() async {
    try {
      if (!await fs.exists(path)) return _current = const AppPrefs();
      return _current = AppPrefs.fromJson(
        jsonDecode(utf8.decode(await fs.readBytes(path))),
      );
      // Default geometry is always a usable answer; refusing to start
      // over a corrupt preferences file would not be.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logStorageEvent('prefs_unreadable');
      return _current = const AppPrefs();
    }
  }

  /// Persists [prefs] atomically.
  ///
  /// [current] IS UPDATED EVEN IF THE WRITE FAILS, and that is deliberate:
  /// `AtomicWriter.write`'s `Outcome` is discarded here (a preferences
  /// file is a convenience and a failure to store it must never reach the
  /// user), so the only honest in-memory answer to "what are the prefs
  /// now" is what this process last decided them to be. Reverting the
  /// cache on a failed write would resurrect exactly the clobbering this
  /// field exists to stop.
  Future<void> save(AppPrefs prefs) async {
    _current = prefs;
    final json = const JsonEncoder.withIndent('  ').convert(prefs.toJson());
    await writer.write(
      paths: SavePaths.forExactTarget(path, context: context),
      bytes: Uint8List.fromList(utf8.encode(json)),
      keepBackup: false,
    );
  }
}

/// The minimum area of overlap with a display for a restored window to
/// count as reachable — enough of a title bar to grab.
const double kMinVisibleOverlap = 100 * 100;

/// Decides whether a saved window rectangle is still usable, and clamps
/// it if so.
///
/// PURE GEOMETRY, AND THEREFORE PURE-UNIT-TESTABLE — synthetic display
/// rectangles, no real monitors, no window manager, no Flutter binding.
///
/// Returns `null` when [saved] no longer meaningfully intersects ANY
/// display, in which case the caller centres a default window. That case
/// is the whole reason this function exists: a position saved on a
/// monitor that has since been unplugged would otherwise reopen the
/// window at coordinates the user cannot reach, and the only remedy a
/// non-technical user has is to delete a file they do not know about.
///
/// Otherwise the size is clamped UP to the minimum (a rack editor below
/// ~1000 px is unusable) and DOWN to the display it mostly sits on, and
/// the origin is nudged so the whole window lands inside that display.
WindowBounds? validateRestoredBounds(
  WindowBounds saved,
  List<WindowBounds> displays, {
  double minWidth = kMinWindowWidth,
  double minHeight = kMinWindowHeight,
  double minVisibleOverlap = kMinVisibleOverlap,
}) {
  if (displays.isEmpty) return null;

  WindowBounds? best;
  var bestArea = 0.0;
  for (final display in displays) {
    final area = saved.intersectionArea(display);
    if (area > bestArea) {
      bestArea = area;
      best = display;
    }
  }
  if (best == null || bestArea < minVisibleOverlap) return null;

  final display = best;
  // Clamp UP to the minimum first, then DOWN to the display: a display
  // smaller than the minimum window means the window fills it, which is
  // the least-bad answer and is what every other desktop app does.
  var width = saved.width < minWidth ? minWidth : saved.width;
  var height = saved.height < minHeight ? minHeight : saved.height;
  if (width > display.width) width = display.width;
  if (height > display.height) height = display.height;

  var left = saved.left;
  var top = saved.top;
  if (left + width > display.right) left = display.right - width;
  if (top + height > display.bottom) top = display.bottom - height;
  if (left < display.left) left = display.left;
  if (top < display.top) top = display.top;

  return WindowBounds(left: left, top: top, width: width, height: height);
}
